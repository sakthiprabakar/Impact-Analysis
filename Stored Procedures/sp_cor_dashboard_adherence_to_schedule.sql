--drop proc sp_cor_dashboard_adherence_to_schedule

go

CREATE PROCEDURE sp_cor_dashboard_adherence_to_schedule (
	@web_userid		varchar(100)
	, @date_start		datetime = null
	, @date_end			datetime = null
	, @period			varchar(2) = null /* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */
	, @bulk_flag		char(1) = 'B' /* 'B'ulk or 'N'on-bulk */
	, @customer_id_list varchar(max)=''  /* Added 2019-07-12 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-12 by AA */
) 
AS
BEGIN
/* **************************************************************
sp_cor_dashboard_adherence_to_schedule

10/03/2019 MPM  DevOps 11553: Added logic to filter the result set
				using optional input parameters @customer_id_list and
				@generator_id_list.


Screen Output: Display two progress bar charts to denote percentage 
of work orders that are 
Awaiting Service, 
Outside the timeframe, 
Within timeframe for Scheduled 
and 
Off-Schedule Service

2.2. Assumptions/constraints

2.2.1. For a service to be counted as a Scheduled Service, the 
Work Order should not have the ‘Off Schedule Svc’ flag set.

2.2.2. For a service to be counted as a Off-Scheduled Service, the 
Work Order should have the ‘Off Schedule Svc’ flag set.

2.2.3. For a service to be counted as Within Timeframe, the work 
order’s scheduled date should match the transporter 1 sign date on 
any manifest(s)

2.2.4. For a service to be counted as Outside Timeframe, the work 
order’s scheduled date should NOT match the transporter 1 sign date 
on any manifest(s).

2.2.4.1. Note: This would include pick-ups before the scheduled time 
and after. Early pick-ups are considered outside the timeframe because 
it was off of the schedule from which the customer / generator site 
was expecting the service.

2.2.5. For a service to be counted as Awaiting Service

2.2.5.1. The work order should not have a scheduled date entered

2.2.5.2. OR the work order has a scheduled date and no transporter 1 sign date entered

2.2.5.3. OR the work order does not have any manifests entered.

2.2.6. To be counted as a bulk manifest, the manifest should have 
exactly 1 approval that has a bill rate of not void and has a bulk flag 
set to True on the profile.

2.2.7. To be counted as a non-bulk manifest, any of the approvals on 
the manifest that have a bill rate of not void and has a bulk flag set 
to False on the profile.

2.2.8. To get the percentage, the count for each metric item should be 
divided by the total number of services and then multiplied by 100 and 
rounded to a percentage.

	

 exec sp_cor_dashboard_adherence_to_schedule 
	@web_userid		= 'nyswyn100'
	, @date_start		 = '6/1/2018'
	, @date_end			 = '12/31/2018'
	, @period = 'YY'
	, @bulk_flag = 'B'
;
exec sp_cor_dashboard_adherence_to_schedule 
	@web_userid		= 'zachery.wright'
	, @date_start		 = '6/1/2018'
	, @date_end			 = '12/31/2018'
	, @period = 'YY'
	, @bulk_flag = 'N'
	
sp_cor_dashboard_adherence_to_schedule 
	@web_userid	= 'erindira7'
	, @date_start = '1/1/2018'
	, @date_end	= '10/03/2019'
	, @period = null
	, @bulk_flag = 'B' 
	, @customer_id_list = '15551'  
    , @generator_id_list = '123056, 123057, 123058'

sp_cor_dashboard_adherence_to_schedule 
	@web_userid	= 'erindira7'
	, @date_start = '1/1/2018'
	, @date_end	= '10/03/2019'
	, @period = null
	, @bulk_flag = 'B' 
	, @customer_id_list = ''  
    , @generator_id_list = '123056, 123057, 123058'

sp_cor_dashboard_adherence_to_schedule 
	@web_userid	= 'erindira7'
	, @date_start = '1/1/2018'
	, @date_end	= '10/03/2019'
	, @period = null
	, @bulk_flag = 'B' 
	, @customer_id_list = '15551'  
    , @generator_id_list = ''

************************************************************** */
/*
-- DEBUG:
declare 	@web_userid		varchar(100) = 'zachery.wright'
	, @date_start		datetime = '6/1/2018'
	, @date_end			datetime = '12/31/2018'
*/

declare
	@i_web_userid				varchar(100)	= @web_userid
	, @i_date_start				datetime		= @date_start			
	, @i_date_end				datetime		= @date_end				
	, @i_period					varchar(2)		= @period
	, @contact_id	int
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')

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

select top 1 @contact_id = contact_id from CORcontact where web_userid = @i_web_userid
    
if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = dateadd(d, -7, getdate()) else set @i_date_start = convert(date, @i_date_start)
if isnull(@i_date_end, '1/1/1999') = '1/1/1999' set @i_date_end = getdate() else set @i_date_end = convert(date, @i_date_end)
if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999

if @i_period is not null
	select @i_date_start = dbo.fn_FirstOrLastDateOfPeriod(0, @period, 'adherence_to_schedule')
		, @i_date_end = dbo.fn_FirstOrLastDateOfPeriod(1, @period, 'adherence_to_schedule')


declare @foo table (
	workorder_id	int NOT NULL,
	company_id		int NOT NULL,
	profit_ctr_id	int NOT NULL,
	start_date		datetime NULL,
	service_date	datetime NULL,
	requested_date	datetime NULL,
	scheduled_date	datetime NULL,
	report_status	varchar(20) NULL,
	invoice_date	datetime NULL, 
	scheduled_flag	char(1),
	in_timeframe_flag char(1),
	awaiting_flag	char(1),
	manifest		varchar(15),
	bulk_flag		char(1)
)

insert @foo
select distinct
	ccwhb1.workorder_id
	, ccwhb1.company_id
	, ccwhb1.profit_ctr_id
	, ccwhb1.start_date
	, ccwhb1.service_date
	, ccwhb1.requested_date
	, ccwhb1.scheduled_date
	, ccwhb1.report_status
	, ccwhb1.invoice_date
	, isnull(h.offschedule_service_flag, 'F')
	, in_timeframe_flag = 
		case when convert(date, ccwhb1.scheduled_date) in (
			select convert(date, transporter_sign_date)
			from workordertransporter t
			where ccwhb1.workorder_id = t.workorder_id and ccwhb1.company_id = t.company_id and ccwhb1.profit_ctr_id = t.profit_ctr_id
			and t.transporter_sequence_id = 1 )
		then 'T' else 'F' end
	, awaiting_flag = 
		case when (
			ccwhb1.scheduled_date is null
			or (
				ccwhb1.scheduled_date is not null 
				and 
				not exists (select top 1 1 
					from workordertransporter t
					where ccwhb1.workorder_id = t.workorder_id and ccwhb1.company_id = t.company_id and ccwhb1.profit_ctr_id = t.profit_ctr_id
					and t.transporter_sequence_id = 1
					and t.transporter_sign_date is not null 
					)
			)
			or ( m.workorder_id is null )
		)
		then 'T'
		else 'F'
		end
	, m.manifest
	, bulk_flag = (
		case when 1 = (
			select count(sequence_id)
			from workorderdetail d (nolock)
			left join profile p (nolock) 
				on d.profile_id is not null
				and d.profile_id = p.profile_id 
				and p.bulk_flag = 'T'
			left join tsdfapproval ta (nolock) 
				on d.tsdf_approval_id is not null
				and d.tsdf_approval_id = ta.tsdf_approval_id
				and ta.bulk_flag = 'T'
			where d.workorder_id = ccwhb1.workorder_id
			and d.company_id = ccwhb1.company_id
			and d.profit_ctr_id = ccwhb1.profit_ctr_id
			and d.resource_type = 'D'
			and d.bill_rate > -2
			and (p.profile_id is not null or ta.tsdf_approval_id is not null)
			) then 'T' else 'F' end
		)
from ContactCORWorkorderHeaderBucket ccwhb1 (nolock)
join workorderheader h (nolock)
	on ccwhb1.workorder_id = h.workorder_id and ccwhb1.company_id = h.company_id and ccwhb1.profit_ctr_id = h.profit_ctr_id
join workorderdetail d (nolock)
	on ccwhb1.workorder_id = d.workorder_id and ccwhb1.company_id = d.company_id and ccwhb1.profit_ctr_id = d.profit_ctr_id
	and d.resource_type = 'D' and d.bill_rate > -2
join workordermanifest m (nolock)
	on ccwhb1.workorder_id = m.workorder_id and ccwhb1.company_id = m.company_id and ccwhb1.profit_ctr_id = m.profit_ctr_id
	and d.manifest = m.manifest
	and m.manifest not like '%manifest%'
where ccwhb1.contact_id = @contact_id
and ccwhb1.service_date between @i_date_start and @i_date_end
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

-- if object_id('tempdb..#foo') is not null drop table #foo
-- select * into #foo from @foo

-- SELECT  *  FROM    #foo

select *
, convert(decimal(5,2),case when total_count > 0 then (((in_timeframe_count * 1.00) / total_count) * 100) else 0 end) as in_timeframe_pct
, convert(decimal(5,2),case when total_count > 0 then (((outside_timeframe_count * 1.00) / total_count) * 100) else 0 end) as outside_timeframe_pct
, convert(decimal(5,2),case when total_count > 0 then (((awaiting_count * 1.00) / total_count) * 100) else 0 end) as awaiting_pct
from 
(
	select schedules.scheduled_flag, bulks.bulk_flag
		, total_count = (
			select count(*)
			from @foo
			where bulk_flag = bulks.bulk_flag
			and scheduled_flag = schedules.scheduled_flag
		)
		, in_timeframe_count = (
			select count(*)
			from @foo
			where bulk_flag = bulks.bulk_flag
			and scheduled_flag = schedules.scheduled_flag
			and in_timeframe_flag = 'T'
		)
		, outside_timeframe_count = (
			select count(*)
			from @foo
			where bulk_flag = bulks.bulk_flag
			and scheduled_flag = schedules.scheduled_flag
			and in_timeframe_flag = 'F'
		)
		, awaiting_count = (
			select count(*)
			from @foo
			where bulk_flag = bulks.bulk_flag
			and scheduled_flag = schedules.scheduled_flag
			and awaiting_flag = 'T'
		)
	from
	(
		select 'T' as scheduled_flag
		union
		select 'F' as scheduled_flag
	) schedules
	cross join
	(
		select
			'T' as bulk_flag
		union
		select
			'F' as bulk_flag
	) bulks
) math
where math.bulk_flag = case when @bulk_flag = 'B' then 'T' else 'F' end
order by scheduled_flag, bulk_flag


return 0
END

GO

GRANT EXEC ON sp_cor_dashboard_adherence_to_schedule TO EQAI;
GO
GRANT EXEC ON sp_cor_dashboard_adherence_to_schedule TO EQWEB;
GO
GRANT EXEC ON sp_cor_dashboard_adherence_to_schedule TO COR_USER;
GO


