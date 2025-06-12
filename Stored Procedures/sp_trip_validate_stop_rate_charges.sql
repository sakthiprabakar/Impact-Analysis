
create procedure sp_trip_validate_stop_rate_charges
	@source_type char(1),
	@source_id int,
	@company_id int,
	@profit_ctr_id int,
	@user_id varchar(10),
	@operation char(1)
with recompile
as
/********************************
 *
 * Load to Plt_ai
 *
 * 09/28/2015 rb Created
 * 05/18/2018 AM GEM:50919  - Include customer_id in join to GeneratorSubLocation
 
 * Insert resource classes and overages on completion of trips utilizing the TripStopRate table.
 * Delete those records when such trips are uncompleted.
 *
 * @source_type:	'T' @source_id is trip_id
 *					'W' @source id is workorder_id
 *
 * @operation:		'D' delete stop fee resource classes and overage records from WorkOrderDetail
 *					'V' validate that records do not already exist in WorkOrderDetail...return workorders that do
 
 * sp_trip_validate_stop_rate_charges 'T' ,47833,0,0,'ANITHA_M','V'
 ********************************/
declare @initial_tran_count int,
		@err int,
		@msg varchar(1024)

set transaction isolation level read uncommitted

--record initial tran count
set @initial_tran_count = @@trancount

--work table
create table #w (
	workorder_id int not null,
	company_id int not null,
	profit_ctr_id int not null
)

--results table
create table #r (
	workorder_id int not null,
	company_id int not null,
	profit_ctr_id int not null,
	resource_class_code varchar(10)
)
	
if isnull(@source_type,'') = 'T'
	insert #w
	select workorder_id, company_id, profit_ctr_id
	from WorkorderHeader
	where trip_id = @source_id
	and isnull(workorder_status,'') <> 'V'
	and isnull(trip_stop_rate_flag,'') = 'T'

else if isnull(@source_type,'') = 'W'
	insert #w
	select workorder_id, company_id, profit_ctr_id
	from WorkorderHeader
	where workorder_ID = @source_id
	and company_id = @company_id
	and profit_ctr_ID = @profit_ctr_id
	and isnull(workorder_status,'') <> 'V'
	and isnull(trip_stop_rate_flag,'') = 'T'

-- if no trip_stop_rate_flag is set, don't do anything
if not exists (select 1 from #w)
	goto ON_SUCCESS

-- begin tran
set nocount on
begin transaction

-- compute total disposal weights
select wh.workorder_id,
		wh.company_id,
		wh.profit_ctr_ID,
		wh.customer_id,
		wh.generator_sublocation_ID,
		isnull(g.generator_state,'') as state,
		upper(gsl.code) as sub_location,
		case isnull(wh.offschedule_service_flag,'') when 'T' then 'O' else 'S' end as service_schedule,
		case when isnull(wh.combined_service_flag,'') = 'T' then
					case when sum(isnull(case when wd.bill_rate = -2 then 0 else wdu.quantity end,0)) = 0 then 'CNW' else 'CS' end
			 else
					case when sum(isnull(case when wd.bill_rate = -2 then 0 else wdu.quantity end,0)) = 0 then 'NW' else 'NCW' end
		end as additional_service,
		convert(varchar(15),null) as resource_class_code,
		sum(isnull(wdu.quantity,0)) as total_units,
		convert(money,0) as pounds_included,
		convert(money,0) as stop_fee_price,
		convert(money,0) as unit_price,
		convert(money,0) as extra_units,
		convert(money,0) as extra_units_charge
into #sf_calc
from WorkOrderHeader wh
join #w
	on wh.workorder_ID = #w.workorder_id
	and wh.company_id = #w.company_id
	and wh.profit_ctr_ID = #w.profit_ctr_id
join Generator g
	on wh.generator_id = g.generator_id
join GeneratorSubLocation gsl
	on wh.generator_sublocation_ID = gsl.generator_sublocation_ID
	and wh.customer_id = gsl.customer_id
	--and gsl.code in ('DC','RX','ST')
join WorkorderDetail wd
	on wh.workorder_ID = wd.workorder_ID
	and wh.company_id = wd.company_id
	and wh.profit_ctr_ID = wd.profit_ctr_ID
	and isnull(wd.resource_type,'') = 'D'
join WorkOrderDetailUnit wdu
	on wd.workorder_ID = wdu.workorder_id
	and wd.company_id = wdu.company_id
	and wd.profit_ctr_ID = wdu.profit_ctr_id
	and wd.sequence_ID = wdu.sequence_id
	and wdu.bill_unit_code = 'LBS'
group by wh.workorder_id,
		wh.company_id,
		wh.profit_ctr_ID,
		wh.customer_id,
		wh.generator_sublocation_ID,
		isnull(g.generator_state,''),
		upper(gsl.code),
		case isnull(wh.offschedule_service_flag,'') when 'T' then 'O' else 'S' end,
		wh.combined_service_flag

set @err = @@error
if @err <> 0
begin
	set @msg = 'ERROR: Attempt to create temp table #sf_calc raised error #' + convert(varchar(10),@err)
	goto ON_ERROR
end

-- determine which resource class
update #sf_calc
set resource_class_code = rcd.resource_class_code
from #sf_calc sf
join ResourceClassDetail rcd
	on sf.company_id = rcd.company_id
	and sf.profit_ctr_ID = rcd.profit_ctr_id
	and sf.state = isnull(rcd.state,'')
	and sf.sub_location = isnull(rcd.sub_location,'')
	and sf.service_schedule = isnull(rcd.service_schedule,'')
	and sf.additional_service = isnull(rcd.additional_service,'')
	and isnull(rcd.status,'') = 'A'

set @err = @@error
if @err <> 0
begin
	set @msg = 'ERROR: Attempt to update #sf_calc resource class code raised error #' + convert(varchar(10),@err)
	goto ON_ERROR
end

-- lookup values for resource class in trip stop rate table
update #sf_calc
set pounds_included = isnull(tsr.pounds_included,0),
	stop_fee_price = isnull(tsr.stop_fee_price,0),
	unit_price = isnull(tsr.unit_price,0),
	extra_units = convert(money, case when sf.total_units > isnull(tsr.pounds_included,0)
										then sf.total_units - isnull(tsr.pounds_included,0)
										else 0 end)
from #sf_calc sf
join TripStopRate tsr
	on sf.customer_id = tsr.customer_id
	and sf.generator_sublocation_id = tsr.generator_sublocation_id
	and tsr.pricing_group = 'State'
	and sf.state = tsr.pricing_group_value
	and sf.resource_class_code = tsr.resource_class_code
	and tsr.effective_date = (select max(effective_date)
								from TripStopRate
								where customer_id = tsr.customer_id
								and generator_sublocation_id = tsr.generator_sublocation_id
								and pricing_group = tsr.pricing_group
								and pricing_group_value = tsr.pricing_group_value
								and resource_class_code = tsr.resource_class_code
								and status = 'A'
								and effective_date < getdate())

set @err = @@error
if @err <> 0
begin
	set @msg = 'ERROR: Attempt to update temp table #sf_calc from TripStopRate raised error #' + convert(varchar(10),@err)
	goto ON_ERROR
end

-- compute extra charges and adjusted stop fee price
update #sf_calc
set extra_units_charge = isnull(extra_units,0) * isnull(unit_price,0)

set @err = @@error
if @err <> 0
begin
	set @msg = 'ERROR: Attempt to update #sf_calc overages raised error #' + convert(varchar(10),@err)
	goto ON_ERROR
end

-- on Delete, delete records from WorkOrderDetail
if isnull(@operation,'') = 'D'
begin
	-- append overages
	insert #sf_calc
	select sf.workorder_id,
		sf.company_id,
		sf.profit_ctr_ID,
		sf.customer_id,
		sf.generator_sublocation_ID,
		sf.state,
		sf.sub_location,
		sf.service_schedule,
		sf.additional_service,
		rcd.resource_class_code,
		CONVERT(money,0) as total_units,
		convert(money,0) as pounds_included,
		convert(money,0) as stop_fee_price,
		convert(money,0) as unit_price,
		convert(money,0) as extra_units,
		convert(money,0) as extra_units_charge
	from #sf_calc sf
	join ResourceClassDetail rcd
		on sf.company_id = rcd.company_id
		and sf.profit_ctr_ID = rcd.profit_ctr_id
		and sf.sub_location = rcd.sub_location
		and isnull(rcd.additional_service,'') = 'OVR'
		and isnull(rcd.status,'') = 'A'
	join ResourceClassHeader rch
		on rcd.resource_class_code = rch.resource_class_code
	where isnull(sf.extra_units_charge,0) > 0

	set @err = @@error
	if @err <> 0
	begin
		set @msg = 'ERROR: Attempt to append overages into #sf_calc raised error #' + convert(varchar(10),@err)
		goto ON_ERROR
	end
	
	-- record records deleted
	insert #r
	select sf.workorder_id, sf.company_id, sf.profit_ctr_id, sf.resource_class_code
	from WorkOrderDetail wd
	join #sf_calc sf
		on wd.workorder_ID = sf.workorder_id
		and wd.company_id = sf.company_id
		and wd.profit_ctr_ID = sf.profit_ctr_id
		and isnull(wd.resource_class_code,'') = sf.resource_class_code
	where wd.resource_type = 'O'

	-- delete resource classes
	delete WorkOrderDetail
	from WorkOrderDetail wd
	join #sf_calc sf
		on wd.workorder_ID = sf.workorder_id
		and wd.company_id = sf.company_id
		and wd.profit_ctr_ID = sf.profit_ctr_id
		and isnull(wd.resource_class_code,'') = sf.resource_class_code
	where wd.resource_type = 'O'

	set @err = @@error
	if @err <> 0
	begin
		set @msg = 'ERROR: Attempt to delete resource classes from WorkOrderDetail raised error #' + convert(varchar(10),@err)
		goto ON_ERROR
	end
end

-- on Validate, return matching resource class records that already exist in WorkOrderDetail
else if isnull(@operation,'') = 'V'
begin
	insert #r
	select sf.workorder_id, sf.company_id, sf.profit_ctr_id, sf.resource_class_code
	from #sf_calc sf
	where exists (select 1 from WorkorderDetail
					where workorder_ID = sf.workorder_id
					and company_id = sf.company_id
					and profit_ctr_ID = sf.profit_ctr_id
					and resource_class_code = sf.resource_class_code)

	-- append overages
	insert #r
	select sf.workorder_id, sf.company_id, sf.profit_ctr_id, rcd.resource_class_code
	from #sf_calc sf
	join ResourceClassDetail rcd
		on sf.company_id = rcd.company_id
		and sf.profit_ctr_ID = rcd.profit_ctr_id
		and sf.sub_location = rcd.sub_location
		and isnull(rcd.additional_service,'') = 'OVR'
		and isnull(rcd.status,'') = 'A'
	join ResourceClassHeader rch
		on rcd.resource_class_code = rch.resource_class_code
	where isnull(sf.extra_units_charge,0) > 0
	and exists (select 1 from WorkorderDetail
				where workorder_ID = sf.workorder_id
				and company_id = sf.company_id
				and profit_ctr_ID = sf.profit_ctr_id
				and resource_class_code = rcd.resource_class_code)
end


-- SUCCESS
ON_SUCCESS:
set nocount off
if @@trancount > @initial_tran_count
	commit transaction
select workorder_id, company_id, profit_ctr_id, resource_class_code from #r
return 0

-- ERROR
ON_ERROR:
set nocount off
if @@trancount > @initial_tran_count
	rollback transaction

raiserror(@msg,18,-1) with seterror
return -1

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_validate_stop_rate_charges] TO [EQAI]
    AS [dbo];

