-- drop proc sp_cor_dashboard_service_status
go

create proc sp_cor_dashboard_service_status (
	@web_userid	varchar(100)
	, @start_date	datetime = null
	, @end_date		datetime = null
	, @period			varchar(2) = null /* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */
	, @customer_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-15 by AA */
)
as
/* ***********************************************************
sp_cor_dashboard_service_status 

10/02/2019 MPM  DevOps 11559: Added logic to filter the result set
				using optional input parameters @customer_id_list and
				@generator_id_list.

2.2. Assumptions/constraints

2.2.1. The count of “Service Request” is a count of all work orders 
that are not voided and not a template for the customer’s access where 
the work order start date is within the period of time for the metric.

2.2.2. The count of “Service Scheduled” is a count of all work orders 
that are not voided and not a template for the customer’s access where 
the work order has a scheduled service date entered that is within the 
date range of the metric. To qualify, the work order should not have a 
status of completed and it should also not be submitted.

2.2.3. The count of “Service Pending” is a count of all work orders that 
are not voided and not a template for the customer’s access where the 
work order start date is within the period of time for the metric and 
the work order does not have a scheduled service date entered.



sp_cor_dashboard_service_status 'nyswyn100'

sp_cor_dashboard_service_status
	@web_userid = 'zachery.wright'
	, @start_date = '10/1/2018'
	, @end_date = '12/31/2018'

exec sp_cor_dashboard_service_status
	@web_userid = 'erindira7'
	, @start_date = '1/1/2018'
	, @end_date = '10/03/2019'
	, @period = null
	, @customer_id_list = '15551'
	, @generator_id_list = '123056, 123057, 123058'
		
*********************************************************** */

/*
declare
	@web_userid varchar(100) = 'zachery.wright'
	, @start_date datetime = '1/1/2017'
	, @end_date datetime = '12/31/2018'
*/

declare
	@i_web_userid	varchar(100) = @web_userid
	, @i_start_date	datetime = convert(date, @start_date)
	, @i_end_date	datetime = convert(date, @end_date)
	, @i_period					varchar(2)		= @period
	, @contact_id	int
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')

select top 1 @contact_id = contact_id from CORcontact where web_userid = @i_web_userid

declare @customer table (
	customer_id	bigint
)

if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator table (
	generator_id	bigint
)

if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

if @i_end_date is null begin
	set @i_end_date = convert(date, getdate())
	set @i_start_date = convert(date, @i_end_date-7)
end
else 
	if @i_start_date is null 
		set @i_start_date = convert(date, @i_end_date-7)

if datepart(hh, @i_end_date) = 0
	set @i_end_date = @i_end_date + 0.99999

if @i_period is not null
	select @i_start_date = dbo.fn_FirstOrLastDateOfPeriod(0, @period, 'service_status')
		, @i_end_date = dbo.fn_FirstOrLastDateOfPeriod(1, @period, 'service_status')


select 
	service_date = (	
/*
2.2.1. The count of “Service Request” is a count of all work orders 
that are not voided and not a template for the customer’s access where 
the work order start date is within the period of time for the metric.
*/	
		select count(*)
		from ContactCorWorkOrderHeaderBucket b (nolock)
		join WorkOrderHeader woh (nolock)
			on woh.company_id = b.company_id
			and woh.profit_ctr_id = b.profit_ctr_id
			and woh.workorder_ID = b.workorder_id
		WHERE b.contact_id = @contact_id
		and b.start_date between @i_start_date and @i_end_date
		and woh.generator_id is not null
		and 
		(
			@i_customer_id_list = ''
			or
			(
				@i_customer_id_list <> ''
				and
				woh.customer_id in (select customer_id from @customer)
			)
		)
		and
		(
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
				woh.generator_id in (select generator_id from @generator)
			)
		)
	),
	
	service_scheduled = (
/*
2.2.2. The count of “Service Scheduled” is a count of all work orders 
that are not voided and not a template for the customer’s access where 
the work order has a scheduled service date entered that is within the 
date range of the metric. To qualify, the work order should not have a 
status of completed and it should also not be submitted.
*/	
		select count(b.workorder_id)
		from ContactCorWorkOrderHeaderBucket b (nolock)
		join workorderheader h (nolock)
			on b.workorder_id = h.workorder_id
			and b.company_id = h.company_id
			and b.profit_ctr_id = h.profit_ctr_id
		WHERE b.contact_id = @contact_id
		and b.scheduled_date between @i_start_date and @i_end_date
		and b.report_status <> 'Completed'
		and isnull(h.submitted_flag, 'F') = 'F'
		and h.generator_id is not null
		and 
		(
			@i_customer_id_list = ''
			or
			(
				@i_customer_id_list <> ''
				and
				h.customer_id in (select customer_id from @customer)
			)
		)
		and
		(
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
				h.generator_id in (select generator_id from @generator)
			)
		)
	),

	service_pending = (
/*
2.2.3. The count of “Service Pending” is a count of all work orders that 
are not voided and not a template for the customer’s access where the 
work order start date is within the period of time for the metric and 
the work order does not have a scheduled service date entered.
*/	
		select count(b.workorder_id)
		from ContactCorWorkOrderHeaderBucket b (nolock)
		join WorkOrderHeader woh (nolock)
			on woh.company_id = b.company_id
			and woh.profit_ctr_id = b.profit_ctr_id
			and woh.workorder_ID = b.workorder_id
		WHERE b.contact_id = @contact_id
		and b.start_date between @i_start_date and @i_end_date
		and b.scheduled_date is null
		and woh.generator_id is not null
		and 
		(
			@i_customer_id_list = ''
			or
			(
				@i_customer_id_list <> ''
				and
				woh.customer_id in (select customer_id from @customer)
			)
		)
		and
		(
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
				woh.generator_id in (select generator_id from @generator)
			)
		)	)
 
return 0

go

grant execute on sp_cor_dashboard_service_status to eqai, eqweb, cor_user
go
