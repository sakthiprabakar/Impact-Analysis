
create procedure sp_rpt_trip_stop_weight_rate
	@trip_id int
as
/***********************************************************************************************
 *
 * use Plt_ai
 *
 * 04/21/2015 RWB	Created
 * 04/27/2015 RWB	Initially created with join between TripStopRate and ResourceClass including
 *			bill_unit_code. It was determined that this should not be included.
 * 12/14/2015 RWB	Now that these records can be auto-generated, this report should now inform
 *			of missing records
 ***********************************************************************************************/
declare @err int,
		@msg varchar(255)
		
--work table
create table #w (
	workorder_id int not null,
	company_id int not null,
	profit_ctr_id int not null
)

set transaction isolation level read uncommitted

--valid workorders for trip
insert #w
select workorder_id, company_id, profit_ctr_id
from WorkorderHeader
where trip_id = @trip_id
and isnull(workorder_status,'') <> 'V'
and isnull(trip_stop_rate_flag,'') = 'T'

-- compute total disposal weights
select wh.workorder_id,
		wh.company_id,
		wh.profit_ctr_ID,
		wh.trip_sequence_id,
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
	and gsl.code in ('DC','RX','ST')
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
		wh.trip_sequence_id,
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

--missing trip stop rate resource classes
select sf.trip_sequence_id,
	sf.workorder_id,
	sf.customer_id,
	wh.workorder_status,
	wh.submitted_flag,
	g.epa_id,
	gsl.description as generator_sublocation,
	ws.date_act_arrive,
	sf.stop_fee_price,
	sf.unit_price,
	sf.pounds_included,
	sf.total_units,
	sf.extra_units,
	sf.extra_units_charge,
	'Resource class ' + sf.resource_class_code + ' is not assigned.' as error_msg
from #sf_calc sf
join WorkOrderHeader wh
	on sf.workorder_ID = wh.workorder_ID
	and sf.company_id = wh.company_id
	and sf.profit_ctr_ID = wh.profit_ctr_ID
join Generator g
	on wh.generator_id = g.generator_id
join GeneratorSubLocation gsl
	on wh.generator_sublocation_ID = gsl.generator_sublocation_ID
left outer join WorkorderStop ws
	on wh.workorder_ID = ws.workorder_id
	and wh.company_id = ws.company_id
	and wh.profit_ctr_ID = ws.profit_ctr_id
	and ws.stop_sequence_id = 1
where not exists (select 1 from WorkOrderDetail
					where workorder_ID = sf.workorder_ID
					and company_id = sf.company_id
					and profit_ctr_id = sf.profit_ctr_ID
					and resource_class_code = sf.resource_class_code)
union
--missing overage resource classes
select sf.trip_sequence_id,
	sf.workorder_id,
	sf.customer_id,
	wh.workorder_status,
	wh.submitted_flag,
	g.epa_id,
	gsl.description as generator_sublocation,
	ws.date_act_arrive,
	sf.stop_fee_price,
	sf.unit_price,
	sf.pounds_included,
	sf.total_units,
	sf.extra_units,
	sf.extra_units_charge,
	'Stop has overage, but resource class ' + rcd.resource_class_code + ' is not assigned.'
from #sf_calc sf
join WorkOrderHeader wh
	on sf.workorder_ID = wh.workorder_ID
	and sf.company_id = wh.company_id
	and sf.profit_ctr_ID = wh.profit_ctr_ID
join Generator g
	on wh.generator_id = g.generator_id
join GeneratorSubLocation gsl
	on wh.generator_sublocation_ID = gsl.generator_sublocation_ID
left outer join WorkorderStop ws
	on wh.workorder_ID = ws.workorder_id
	and wh.company_id = ws.company_id
	and wh.profit_ctr_ID = ws.profit_ctr_id
	and ws.stop_sequence_id = 1
join ResourceClassDetail rcd
	on sf.company_id = rcd.company_id
	and sf.profit_ctr_ID = rcd.profit_ctr_id
	and sf.sub_location = rcd.sub_location
	and isnull(rcd.additional_service,'') = 'OVR'
	and isnull(rcd.status,'') = 'A'
join ResourceClassHeader rch
	on rcd.resource_class_code = rch.resource_class_code
where isnull(sf.extra_units_charge,0) > 0
and not exists (select 1 from WorkOrderDetail
				where workorder_ID = sf.workorder_ID
				and company_id = sf.company_id
				and profit_ctr_id = sf.profit_ctr_ID
				and resource_class_code = rcd.resource_class_code)
return 0

ON_ERROR:
raiserror(16,1,@msg)
return -1

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_trip_stop_weight_rate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_trip_stop_weight_rate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_trip_stop_weight_rate] TO [EQAI]
    AS [dbo];

