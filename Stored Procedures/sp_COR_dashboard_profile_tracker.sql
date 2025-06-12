-- drop proc sp_COR_dashboard_profile_tracker
go

CREATE PROCEDURE [dbo].[sp_COR_dashboard_profile_tracker]
	@web_userid		varchar(100)
	, @owner			varchar(5) = 'mine' /* 'mine' or 'all' */
	, @period			varchar(2) = null /* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */
	, @customer_id_list varchar(max)=''  /* Added 2019-07-12 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-12 by AA */
AS
/* ****************************************************************
sp_COR_dashboard_profile_tracker


select p.profile_id, p.approval_desc*
from [Contact] c
join [ContactXref] x
	on c.contact_id = x.contact_id
	and x.status = 'A'
	and x.web_access = 'A'
join [Profile] p
	on case x.type 
		when 'C' then 
			case when p.customer_id  = x.customer_id then 1 else 0 end 
		when 'G' then 
			case when p.generator_id = x.generator_id then 1 else 0 end
		else 0 end = 1
where convert(Varchar(20), c.contact_id) = 100913

select * from contact where web_userid = 'nyswyn100'

Samples:

[sp_COR_dashboard_profile_tracker] 
	@web_userid = 'Jamie.Huens@Wal-Mart.com'
	, @owner = 'mine'
	, @period = 'WW'
 
[sp_COR_dashboard_profile_tracker] 
    @web_userid = 'customer.demo@usecology.com'
	, @owner = 'mine'
	, @period = 'WW'

exec sp_COR_dashboard_profile_tracker 
	@web_userid = 'nyswyn100'
	, @owner = 'all'
	, @period = 'yy'
	;
	
	exec [sp_COR_FormWCR_Count] 
		@web_userid = 'nyswyn100', 
		@status_list = 'draft, pending customer response, submitted', 
		@search = '', 
		@adv_search = '', 
		@generator_size		= '',
		@generator_name		= '',
		-- @generator_site_type = 'GE Renewable Energy',
		@form_id			= '',	-- Can take a CSV list
		@waste_common_name	= '',
		@epa_waste_code		= '',	-- Can take a CSV list
		@copy_status = null, 
		@owner = 'all',
		@period = 'yy',
		@page = 1, 
		@perpage = 20000
	;
	exec [sp_COR_Profile_count] 
    @web_userid = 'nyswyn100', 
    @status_list = 'all', 
    @search = '', 
	@adv_search = '' , 
	@generator_name		= '',
	-- @generator_site_type = 'GE Renewable Energy',
	@profile_id			= '',
	@waste_common_name	= '',
	@epa_waste_code		= '',
    @copy_status = null, 
	@page = 1, 
    @perpage = 20000
    , @excel_output = 0
	, @owner = 'all'
	, @period = 'yy'

	

[sp_COR_dashboard_profile_tracker] 
	@web_userid = 'nyswyn100'
	, @owner = 'mine'
	, @period = 'MM'


5/24/2021
DO-20902 - add profile.inactive_flag to output


**************************************************************** */
-- DECLARE   @web_userid        varchar(100)='nyswyn100', @owner varchar(5) = 'all', @period varchar(2)

-- avoid query plan caching:
declare
    @i_web_userid			varchar(100) = @web_userid,
    @i_owner				varchar(5) = isnull(@owner, 'mine'),
    @i_period				varchar(2) = isnull(@period, 'WW'),
    @i_customer_id_list	varchar(max) = isnull(@customer_id_list, ''),
    @i_generator_id_list	varchar(max) = isnull(@generator_id_list, ''),
	@i_contact_id		int,
	@i_email	varchar(100)
	
select top 1 @i_contact_id = isnull(contact_id, -1)
, @i_email = email
from CORcontact WHERE web_userid = @i_web_userid

--select @i_contact_id, @i_email

declare @status table (
	status	varchar(40),
	_ord	int	not null identity(1,1)
)
insert @status values ('Draft'), ('Pending Customer Response'), ('Submitted'), ('Approved')


declare @foowcr table (
	form_id			int,
	revision_id		int,
	profile_id		int,
	approval_code	varchar(max),
	status			char(1),
	display_status	varchar(60),
	waste_common_name	varchar(50),
	generator_id	int,
	generator_name	varchar(75),
	generator_type	varchar(20),
	epa_id			varchar(12),
	site_type		varchar(40),
	customer_id		int,
	cust_name		varchar(75),
	date_modified	datetime,
	created_by		varchar(100),
	modified_by		varchar(100),	
	copy_source		varchar(10),
	tsdf_type		varchar(10),
	edit_allowed	char(1),
	_row			int,
	totalcount		int
)
	
insert @foowcr
exec sp_cor_formwcr_list
	@web_userid		= @i_web_userid,
	@status_list	= 'Draft, Pending Customer Response, Accepted, Submitted',
	@search			= null,
	@adv_search		= null,
	@generator_size		= null,
	@generator_name		= null,
	@generator_site_type	= null,
	@form_id			= null,
	@waste_common_name	= null,
	@epa_waste_code		= null,
	@copy_status	= null,
	@sort			= null,
	@page			= 1,
	@perpage		= 999999999,
	@excel_output	= 0,
	@customer_id_list = @i_customer_id_list,
    @generator_id_list = @i_generator_id_list,
	@owner			= @i_owner,
	@period			= @i_period


declare @fooprofile table (
	profile_id int
	, approval_code_list varchar(max)
	, pro_name varchar(50)
	, generator_id int
	, gen_by varchar(75)
	, Generator_EPA_ID varchar(12)
	, site_type varchar(40)
	, RCRA_status varchar(20)
	, updated_date datetime
	, customer_id int
	, updated_by varchar(75)
	, expired_date datetime
	, profile varchar(100)
	, status varchar(40)
	, reapproval_allowed char(1)
	, inactive_flag char(1)
	, waste_code_list varchar(max)
	, document_update_status char(1)
	, tsdf_type varchar(10)
	, totalcount int
)


insert @fooprofile
exec sp_COR_Profile_List
    @web_userid			= @i_web_userid,
    @status_list		= null,
    @search				= null,
    @adv_search			= null,
	@generator_size		= null,
	@generator_name		= null,
	@generator_site_type = null,
	@profile_id			= null,
	@waste_common_name	= null,
	@epa_waste_code		= null,	-- Can take a CSV list
	@facility_search	= null,
	@facility_id_list	= null,
    @copy_status		= null,
    @sort				= null,
    @page				= 1,
    @perpage			= 999999999,
    @excel_output		= 0, -- or 1
	@customer_id_list 	= @i_customer_id_list,
    @generator_id_list 	= @i_generator_id_list,
	@owner				= @i_owner,
	@period				= @i_period,
	@tsdf_type			= 'USE' -- ignore tsdf approvals


select d.status, isnull(x.status_count, 0) status_count
from @status d
left join (

	select display_status, count(*) status_count
	from @foowcr
	group by display_status
			
			
	union all

	select status, count(*) status_count
	from @fooprofile
	group by status


) x on x.display_status = d.status
order by d._ord
        
RETURN 0

GO

GRANT EXECUTE ON [dbo].[sp_COR_dashboard_profile_tracker] TO COR_USER;

GO
