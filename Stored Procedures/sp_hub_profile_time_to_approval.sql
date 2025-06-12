-- drop proc if exists sp_hub_profile_time_to_approval
go

create proc sp_hub_profile_time_to_approval (
	@date_form_created_from		datetime = null,
	@date_form_created_to		datetime = null,
	@primary_approval_facility_list	varchar(max) = null,
	@customer_service_contact_list	varchar(max) = null,
	@customer_id_list			varchar(max) = null
	, @user_code		varchar(20)
	, @permission_id	int
	, @debug_code			int = 0	
)
as
/* *******************************************************************
sp_hub_profile_time_to_approval

Please create a new report in the Hub using the attached SQL query as 
requested and reviewed by @Jeannie Franklin @Marie McMonigle and @Cory McMann 

Report Name:  Profile Time to Approval
Report Description:  Displays relevant timing details regarding profiles from 
	start to approval, regardless if they started in COR or EQAI. 

Please add the ability to run the report by the following criteria:

	Date Range – Date form created
		@date_form_created_from		datetime = null,
		@date_form_created_to		datetime = null,
	Approval Primary Facility
		@primary_approval_facility_list	varchar(max) = null,
	Customer Service Contact
		@customer_service_contact_list	varchar(max) = null,
	Customer
		@customer_id_list			varchar(max) = null

SELECT  * FROM    users WHERE user_code like 'audre%'

sp_hub_profile_time_to_approval 
	@date_form_created_from		= '4/1/2021',
	@date_form_created_to	= '4/30/2021',
	-- @primary_approval_facility_list	= '21|0',
	@customer_service_contact_list	= 'ALL',
	-- @customer_id_list			= '18123, 9775', 
	@user_code		= 'jonathan',
	@permission_id	= 289,
	@debug_code		= 0	

******************************************************************* */

/*
-- debug:
declare
	@date_form_created_from		datetime = '5/1/2021',
	@date_form_created_to		datetime = null,
	@primary_approval_facility_list	varchar(max) = null,
	@customer_service_contact_list	varchar(max) = null,
	@customer_id_list			varchar(max) = null
	, @user_code		varchar(20) = 'jonathan'
	, @permission_id	int = 289
	, @debug_code			int = 0	
*/

-- avoid query plan caching:
declare
	@i_date_form_created_from			datetime = isnull(@date_form_created_from, null),
	@i_date_form_created_to				datetime = isnull(@date_form_created_to, null),
	@i_primary_approval_facility_list	varchar(max) = isnull(@primary_approval_facility_list, ''),
	@i_customer_service_contact_list	varchar(max) = isnull(@customer_service_contact_list, ''),
	@i_customer_id_list					varchar(max) = isnull(@customer_id_list, ''),
	@i_user_code						varchar(20)	= isnull(@user_code, ''),
	@i_permission_id					int	= isnull(@permission_id, -1),
	@date_created						datetime = getdate()
	
IF datepart(hh, @i_date_form_created_to) = 0 set @i_date_form_created_to = @i_date_form_created_to + 0.99999

drop table if exists #Secured_COPC
	
SELECT secured_copc.company_id
       ,secured_copc.profit_ctr_id
INTO   #Secured_COPC
FROM   SecuredProfitCenter secured_copc (nolock)
WHERE  secured_copc.permission_id = @i_permission_id
       AND secured_copc.user_code = @i_user_code 

declare @customer table (
	customer_id	int
)
if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @copc table (
	company_id int
	, profit_ctr_id int
)
IF LTRIM(RTRIM(ISNULL(@i_primary_approval_facility_list, ''))) in ('', 'ALL')
	INSERT @copc
	SELECT Profitcenter.company_id, Profitcenter.profit_ctr_id
	FROM ProfitCenter (nolock) 
	WHERE ProfitCenter.status = 'A'
ELSE
	INSERT @copc
	SELECT Profitcenter.company_id, Profitcenter.profit_ctr_id
	FROM ProfitCenter (nolock) 
	INNER JOIN (
		SELECT
			RTRIM(LTRIM(SUBSTRING(ROW, 1, CHARINDEX('|',ROW) - 1))) company_id,
			RTRIM(LTRIM(SUBSTRING(ROW, CHARINDEX('|',ROW) + 1, LEN(ROW) - (CHARINDEX('|',ROW)-1)))) profit_ctr_id
		from dbo.fn_SplitXsvText(',', 0, @i_primary_approval_facility_list)
		WHERE ISNULL(ROW, '') <> '') selected_copc ON
			ProfitCenter.company_id = selected_copc.company_id
			AND ProfitCenter.profit_ctr_id = selected_copc.profit_ctr_id
	WHERE ProfitCenter.status = 'A'

declare @all_users table (user_code varchar(12), user_name varchar(40))
insert @all_users (user_code, user_name)
select user_code, user_name
from users
union
select 'Not assigned', 'Not assigned'

declare @user table (
	user_code	varchar(12)
)
if @i_customer_service_contact_list not in ('', 'ALL')
	insert @user select row
	from dbo.fn_SplitXsvText(',',1,@i_customer_service_contact_list) x
	join users u on x.row = u.user_code
	where row is not null
else
	insert @user select user_code from @all_users

/*
-- debug
select '@user' _table, * from @user
select '@all_users' _table, * from @all_users
select '@copc' _table, * from @copc
select '@customer' _table, * from @customer
select '#Secured_COPC' _table, * from #Secured_COPC
*/
	
select 
	case when f.form_id is not null then 'COR2' else 'EQAI' end as origin,
--(select count(*) from profilequoteapproval where profile_id = f.profile_id and status = 'A'),
	pc.legal_entity_name as [Approval Primary Facility],
	pqa.approval_code as [Primary Facility Approval Code],
	u.user_name as [Approval Created By],--	pqa.added_by 
	case when u_csr.user_name is not null then u_csr.user_code 
	 when u_csr.user_name is null and pqa.billing_project_id is not null then --'TACO' 
	isnull((
		select ux.user_code from users ux 
		join usersxeqcontact uxec on ux.user_code = uxec.user_code
			and uxec.EQcontact_type = 'CSR'
			and uxec.type_id = (select customer_service_id from customerbilling 
			where customer_id = p.customer_id
			and billing_project_id = pqa.billing_project_id
			)
		), 'Not assigned')
	 when u_csr.user_name is null and pqa.billing_project_id is null then --'TACO' 
	isnull((
		select ux.user_code from users ux 
		join usersxeqcontact uxec on ux.user_code = uxec.user_code
			and uxec.EQcontact_type = 'CSR'
			and uxec.type_id = (select customer_service_id from customerbilling 
			where customer_id = p.customer_id
			and billing_project_id = 0
			)
		), 'Not assigned')
	
	end as csc,
	f.created_by as [Form Created By], 
	f.submitted_by as [Form Submitted By],
	f.date_created as [Date COR2 Form Created], 
	f.date_submitted as [Date COR2 Form Submitted], 
	p.date_added as [Date Profile Created],
	(select min(time_in) from profiletracking (nolock) where tracking_status = 'COMP' and profile_id = p.profile_id) as [Date First Approved],
	p.ap_start_date as [Approval Start Date], 
	p.ap_expiration_date as [Approval Expiration Date], 
	(select dbo.fn_business_days(coalesce(f.date_submitted, p.date_added), (select min(time_in) from profiletracking (nolock) where tracking_status = 'COMP' and profile_id = p.profile_id))) as [Business Days],-- = 1
	(select dbo.fn_business_minutes(coalesce(f.date_submitted, p.date_added), (select min(time_in) from profiletracking (nolock) where tracking_status = 'COMP' and profile_id = p.profile_id))) as [Business Minutes], -- = 20
	p.curr_status_code as [Profile Status],
	p.profile_id as [Profile ID],
	p.approval_desc as [Profile Waste Description], 
	p.customer_id as [Customer ID],
	c.cust_name as [Customer Name]
--approved date and time, approved facility(s), time calc of how many business days between submittal and approved date, tim calc
	, isnull(ab.user_name, p.added_by) as [Profile Added By]
	, row_number() over (order by 	(select dbo.fn_business_minutes(coalesce(f.date_submitted, p.date_added), (select min(time_in) from profiletracking (nolock) where tracking_status = 'COMP' and profile_id = p.profile_id))) desc ) _row

into #out
from profile p (nolock)
left join formwcr f (nolock)
	on f.profile_id = p.profile_id
	and p.date_added >= f.date_created
	and f.date_submitted is not null
join customer c (nolock)
	on p.customer_id = c.customer_id
--left outer 
join ProfileQuoteApproval pqa (nolock)
	on p.profile_id = pqa.profile_id
	and pqa.status = 'A'
	and primary_facility_flag = 'T'
join #secured_COPC copc
	on pqa.company_id = copc.company_id
	and pqa.profit_ctr_id = copc.profit_ctr_id
join @copc copc_i
	on pqa.company_id = copc_i.company_id
	and pqa.profit_ctr_id = copc_i.profit_ctr_id
join profitcenter pc (nolock)
	on pqa.company_id = pc.company_id
	and pqa.profit_ctr_id = pc.profit_ctr_ID
left outer join users u (nolock)
	on pqa.added_by = u.user_code
left outer join users u_csr (nolock)
	on p.EQ_contact = u_csr.user_code
left outer join users ab (nolock) /* added by */
	on p.added_by = ab.user_code


where 
	p.curr_status_code = 'A'

	and
	(
		@i_date_form_created_from is null
		or 
		(@i_date_form_created_from is not null and isnull(f.date_created, p.date_added) > @i_date_form_created_from)
	)
	and
	(
		@i_date_form_created_to is null
		or 
		(@i_date_form_created_to is not null and isnull(f.date_created, p.date_added) <= @i_date_form_created_to)
	)

	and
	(
		@i_customer_id_list = ''
		or
		(@i_customer_id_list <> '' and c.customer_id in (select customer_id from @customer))
	)
 --order by 
	--(select dbo.fn_business_minutes(f.date_submitted, (select min(time_in) from profiletracking (nolock) where tracking_status = 'COMP' and profile_id = p.profile_id))) desc


select 
	Origin,
	[Approval Primary Facility],
	[Primary Facility Approval Code],
	[Approval Created By],--	pqa.added_by 
	[Profile Added By], -- profile.added_by
	x.csc,
	u.user_name as [Customer Service Contact],
	[Form Created By], 
	[Form Submitted By],
	[Date COR2 Form Created], 
	[Date COR2 Form Submitted], 
	[Date Profile Created],
	[Date First Approved],
	[Approval Start Date], 
	[Approval Expiration Date], 
	[Business Days],-- = 1
	[Business Minutes], -- = 20
	[Profile Status],
	[Profile ID],
	[Profile Waste Description], 
	[Customer ID],
	[Customer Name]
FROM    #out x
join @all_users u on x.csc = u.user_code
left join @user iu on u.user_code = iu.user_code or iu.user_code = 'ALL'
order by _row

go

grant execute on sp_hub_profile_time_to_approval to eqai, eqweb, cor_user
go

