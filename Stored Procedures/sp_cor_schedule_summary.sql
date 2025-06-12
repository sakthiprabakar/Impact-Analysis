-- 
drop PROCEDURE sp_cor_schedule_summary
go

CREATE PROCEDURE sp_cor_schedule_summary
	@web_userid				varchar(100)
	, @start_date				varchar(20) = ''	-- Start Date
	, @end_date				varchar(20) = ''	-- End Date
	, @customer_id_list	varchar(max) = ''
    , @generator_id_list	varchar(max) = ''  /* Added 2019-07-16 by AA */

AS

/********************
sp_cor_schedule_summary:

Returns summarised count of inbound schedule events for a contact

Schedule entries don't have customer or generator. They MAY have profile though.
So we use that or contact_id to make things visible.

sp_cor_schedule_summary
	'nyswyn100'
	, '3/21/2021'
	, '5/1/2021'


SELECT  * FROM    ContactCORProfileBucket where contact_id = 11289

SELECT  top 100 * FROM    Schedule WHERE status = 'A' and convert(date, time_scheduled) between '3/21/2021' and '5/1/2021'

-- Fakin records.
insert Schedule
SELECT  top 100 
confirmation_ID + 100000000
,company_id
,profit_ctr_ID
,approval_code
,time_scheduled
,end_block_time
,status
,load_type
,material
,quantity
,sched_quantity
,special_instructions
,contact
,contact_company
,contact_phone
,contact_fax
,void_date
,voided_by
,void_reason
,date_added
,date_modified
,added_by
,modified_by
,bill_unit_code
,group_id
,schedule_type
,TSDF_code
,profile_id
,SPOC_flag
,EQ_contact
,11289 as contact_id
,received_flag
,contact_email
,purchase_order
,release_code
,group_interval
,billing_project_id
,po_sequence_id
,washout_required_flag
 FROM    Schedule WHERE status = 'A' and convert(date, time_scheduled) between '3/21/2021' and '5/1/2021'
	
**********************/

-- DECLARE   @web_userid        varchar(100)='nyswyn100', @start_date varchar(20) = '7/1/2019', @end_date varchar(20) = '', @customer_id_list varchar(max) = '', @generator_id_list varchar(max) = ''

-- avoid query plan caching:
declare
    @i_web_userid			varchar(100) = @web_userid,
    @i_start_date			varchar(20) = convert(date, isnull(@start_date, '')),
    @i_end_date				varchar(20) = convert(date, isnull(@end_date, '')),
	@i_contact_id			int,
	@i_customer_id_list		varchar(max) = isnull(@customer_id_list, ''),
    @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')

select top 1 @i_contact_id = isnull(contact_id, -1)
from CORcontact WHERE web_userid = @i_web_userid

-- debugging - a better contact to test with:
-- set @i_contact_id = 160890

if @i_start_date = '' 
	set @i_start_date = convert(varchar(2), datepart(m, getdate())) + '/1/' + convert(varchar(4), datepart(yyyy, getdate()))
	
if @i_end_date = '' 
	set @i_end_date = convert(varchar(20), dateadd(m, 1, @i_start_date) - 0.0001)
	
if datepart(hh, @i_end_date	) = 0 set @i_end_date = convert(datetime, @i_end_date) + 0.99999

declare @dates table (
	schedule_date datetime
)

insert @dates
SELECT  DATEADD(DAY, nbr - 1, @i_start_date)
FROM    ( SELECT    ROW_NUMBER() OVER ( ORDER BY c.object_id ) AS Nbr
          FROM      sys.columns c
        ) nbrs
WHERE   nbr - 1 <= DATEDIFF(DAY, @i_start_date, @i_end_date)


declare @customers table (
	customer_id	int
)

if @i_customer_id_list <> ''
	insert @customers select convert(int, row)
	from  dbo.fn_SplitXsvText(',', 1, @i_customer_id_list) where isnull(row, '') <> ''

declare @generators table (
	generator_id	int
)

if @i_generator_id_list <> ''
	insert @generators select convert(int, row)
	from  dbo.fn_SplitXsvText(',', 1, @i_generator_id_list) where isnull(row, '') <> ''

-- select @i_contact_id, @i_start_date, @i_end_date

declare @profiles table (
	profile_id	int
)

insert @profiles
SELECT  b.profile_id
FROM    ContactCORProfileBucket b
JOIN profile p on b.profile_id = p.profile_id
WHERE b.contact_id = @i_contact_id
    and 
    (
        isnull(@i_customer_id_list, '') = ''
        or
        (
			isnull(@i_customer_id_list, '') <> ''
			and
			p.customer_id in (select customer_id from @customers)
		)
	)
    and 
    (
        isnull(@i_generator_id_list, '') = ''
        or
        (
			isnull(@i_generator_id_list, '') <> ''
			and
			p.generator_id in (select generator_id from @generators)
		)
	)
and p.curr_status_code = 'A'

declare @schedules table (
	confirmation_id	int
	, date_scheduled	datetime
	, company_id	int
	, profit_ctr_id	int
)

insert @schedules
select confirmation_id, time_scheduled as date_scheduled, company_id, profit_ctr_id
from schedule
WHERE profile_id in (select profile_id from @profiles)
and time_scheduled between @i_start_date and @i_end_date
and status = 'A'
union
select confirmation_id, time_scheduled as date_scheduled, company_id, profit_ctr_id
from schedule
WHERE contact_id = @i_contact_id
and time_scheduled between @i_start_date and @i_end_date
and status = 'A'

 

SELECT  d.schedule_date
, count_this_day = (select count(*) from @schedules WHERE convert(date, date_scheduled) = convert(date, s.date_scheduled))
, s.company_id, s.profit_ctr_id
, p.name
, confirmation_id
FROM    @schedules s
join USE_ProfitCenter p on s.company_id = p.company_id
and s.profit_ctr_id = p.profit_ctr_id
right join @dates d on convert(date,s.date_scheduled) = d.schedule_date
ORDER BY d.schedule_date, convert(date,s.date_scheduled), p.name

return 0


GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_cor_schedule_summary TO PUBLIC
    AS [dbo];


GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_cor_schedule_summary TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_cor_schedule_summary TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_cor_schedule_summary TO [EQAI]
    AS [dbo];

