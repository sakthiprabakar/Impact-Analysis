-- drop proc sp_COR_FormWCR_Count
go
CREATE PROCEDURE [dbo].[sp_COR_FormWCR_Count]
	@web_userid		varchar(100),
	@status_list	varchar(max) = 'all',
	@search			varchar(100) = '',
	@adv_search		varchar(max) = '',
	@generator_size		varchar(75) = '',
	@generator_name		varchar(75) = '',
	@generator_site_type	varchar(max) = '',
	@form_id			varchar(max) = '',	-- Can take a CSV list
	@waste_common_name	varchar(50) = '',
	@epa_waste_code		varchar(max) = '',	-- Can take a CSV list
	@copy_status	varchar(10) = '',
	@sort			varchar(20) = 'Modified Date',
	@page			int = 1,
	@perpage		int = 20,
	@excel_output	int = 0,
	@customer_id_list varchar(max)='',  /* Added 2019-07-19 by AA */
    @generator_id_list varchar(max)='',  /* Added 2019-07-19 by AA */
	@owner			varchar(5) = 'all', /* 'mine' or 'all' */
	@period				varchar(4) = '', /* WW, MM, QQ, YY, 30 or 60 days */
	@tsdf_type			varchar(10) = 'All',  /* 'USE' or 'Non-USE' or 'ALL' */
	@haz_filter			varchar(20) = 'All'  /* 'All', 'RCRA', 'Non-RCRA', 'State', 'Non-Reg' */

AS
/* ****************************************************************
FormWCR COUNT

select avg(_ct) from (
select contact_id, count(*) _ct from contactxref WHERE status = 'A' and web_access = 'A' group by contact_id
) x

select contact_id, count(*) _ct from contactxref WHERE status = 'A' and web_access = 'A' group by contact_id
having count(*) = 12

SELECT  *  FROM    contact where first_name = 'jamie' and email 

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

select email from contact where last_name = 'huens'

Samples:

[sp_COR_FormWCR_Count] 
	@web_userid = 'Jamie.Huens@Wal-Mart.com', 
	@status_list = null, 
	@search = 'wmnhw28a', 
	@adv_search = '', 
	@copy_status = null, 
	@page = 1, 
	@perpage = 200

[sp_COR_FormWCR_Count] 
	@web_userid = 'customer.demo@usecology.com', 
	@status_list = '', 
	@search = '', 
	@adv_search = '', 
	@copy_status = null, 
	@page = 1, 
	@perpage = 200

[sp_COR_FormWCR_Count] 
	@web_userid = 'customer.demo@usecology.com', 
	@status_list = 'draft', 
	@search = '', 
	@adv_search = '', 
	@copy_status = null, 
	@page = 1, 
	@perpage = 200

[sp_COR_FormWCR_Count] 
	@web_userid = 'nyswyn100', 
	@status_list = '', 
	@search = '', 
	@adv_search = '', 
	@generator_size		= '',
	@generator_name		= '',
	-- @generator_site_type = 'GE Renewable Energy',
	@form_id			= '',	-- Can take a CSV list
	@waste_common_name	= '',
	@epa_waste_code		= '',	-- Can take a CSV list
	@copy_status = null, 
	@page = 1, 
	@perpage = 20000



Pending is only forms
Submitted is a status of a form, is not profiles
Approved is only profiles
Expired is only profiles (approved) that have a past date


11/8/2018 call notes
 * Status Search Criteria
	Draft: All
	Draft: Draft
	Draft: Submitted
	Draft: Needs Customer Response


* Need to return count of results per status
	May need a separate procedure/service for returning just counts by types


**************************************************************** */

-- avoid query plan caching:
declare
    @i_web_userid			varchar(100) = isnull(@web_userid, ''),
    @i_status_list		varchar(max) = isnull(@status_list, ''),
    @i_search				varchar(100) = isnull(@search, ''),
    @i_adv_search			varchar(max) = isnull(@adv_search, ''),
	@i_generator_size		varchar(75) = isnull(@generator_size, ''),
	@i_generator_name		varchar(75) = isnull(@generator_name, ''),
	@i_generator_site_type		varchar(max) = isnull(@generator_site_type, ''),
	@i_form_id			varchar(max) = isnull(@form_id, ''),	-- Can take a CSV list
	@i_waste_common_name	varchar(50) = isnull(@waste_common_name, ''),
	@i_epa_waste_code		varchar(max) = isnull(@epa_waste_code, ''),	-- Can take a CSV list
    @i_copy_status		varchar(10) = isnull(@copy_status, ''),
    @i_sort				varchar(20) = isnull(@sort, ''),
    @i_page				int = isnull(@page, 1),
    @i_perpage			int = isnull(@perpage, 20),
	@i_totalcount		int,
    @i_owner				varchar(5) = isnull(@owner, 'all'),
	@i_contact_id		int,
    @i_period				varchar(4) = isnull(@period, ''),
    @i_customer_id_list	varchar(max) = isnull(@customer_id_list, ''),
    @i_generator_id_list	varchar(max) = isnull(@generator_id_list, ''),
	@i_email	varchar(100),
    @i_tsdf_type		varchar(10) = isnull(@tsdf_type, 'USE'),
    @i_haz_filter		varchar(20) = isnull(@haz_filter, 'All')




declare @foo table (
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
	
insert @foo
exec sp_cor_formwcr_list
	@web_userid		= @i_web_userid,
	@status_list	= @i_status_list,
	@search			= @i_search,
	@adv_search		= @i_adv_search,
	@generator_size		= @i_generator_size,
	@generator_name		= @i_generator_name,
	@generator_site_type	= @i_generator_site_type,
	@form_id			= @i_form_id,
	@waste_common_name	= @i_waste_common_name,
	@epa_waste_code		= @i_epa_waste_code,
	@copy_status	= @i_copy_status,
	@sort			= @i_sort,
	@page			= 1,
	@perpage		= 999999999,
	@excel_output	= 0,
	@customer_id_list = @i_customer_id_list,
    @generator_id_list = @i_generator_id_list,
	@owner			= @i_owner,
	@period			= @i_period,
	@tsdf_type		= @i_tsdf_type,
	@haz_filter		= @i_haz_filter

select count(*) from @foo


RETURN 0

GO

GRANT EXECUTE ON [dbo].[sp_COR_FormWCR_Count] TO COR_USER;

GO

