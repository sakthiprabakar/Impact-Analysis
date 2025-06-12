
create procedure sp_trip_generate_stop_rate_validate
	@source_type char(1),
	@source_id int,
	@company_id int,
	@profit_ctr_id int
as
/********************************
 *
 * Load to Plt_ai
 *
 * 09/28/2015 rb Created
 * 05/18/2018 rb GEM:50733 - Include customer_id in join to GeneratorSubLocation
 * 05/31/2018 AM - EQAI-50919 - Added @sub_location to result set.
 
 * Insert resource classes and overages on completion of trips utilizing the TripStopRate table.
 * Delete those records when such trips are uncompleted.
 *
 * @source_type:	'T' @source_id is trip_id
 *					'W' @source id is workorder_id
 *
 ********************************/
declare @workorder_id int,
		@msg varchar(1024),
		@sub_location varchar(3)
		
set transaction isolation level read uncommitted

--work table
create table #w (
	workorder_id int not null,
	company_id int not null,
	profit_ctr_id int not null
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
		convert(varchar(15),null) as resource_class_code
into #sf_calc
from WorkOrderHeader wh
join #w
	on wh.workorder_ID = #w.workorder_id
	and wh.company_id = #w.company_id
	and wh.profit_ctr_ID = #w.profit_ctr_id
join Generator g
	on wh.generator_id = g.generator_id
join GeneratorSubLocation gsl
	on wh.customer_id = gsl.customer_id
	and wh.generator_sublocation_ID = gsl.generator_sublocation_ID
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

-- verify that any having the flag set have a generator and generator sub-location set
declare c_validate cursor forward_only read_only for
select workorder_id , sub_location
from #sf_calc
where isnull(ltrim(resource_class_code),'') = ''
order by workorder_id

open c_validate
fetch c_validate into @workorder_id , @sub_location

while @@FETCH_STATUS = 0
begin
	if isnull(@msg,'') = ''
		set @msg = 'The following Work Orders are configured to generate Trip Stop Rates, but no charges could be determined:' + char(13) + char(10)
	
	set @msg = @msg + char(13) + char(10) + right('0' + convert(varchar(2),@company_id),2) + '-' + right('0' + convert(varchar(2),@profit_ctr_id),2) + '-' + convert(varchar(10),@workorder_id )  + ' (' + convert(varchar(3),@sub_location + ')' )

	fetch c_validate into @workorder_id,@sub_location
end

close c_validate
deallocate c_validate

if isnull(@msg,'') <> ''
	set @msg = @msg + char(13) + char(10) + char(13) + char(10)  -- + 'Please contact IT.'

select isnull(@msg,'') as msg
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_generate_stop_rate_validate] TO [EQAI]
    AS [dbo];

