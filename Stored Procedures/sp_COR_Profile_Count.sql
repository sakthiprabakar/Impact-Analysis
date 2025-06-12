-- drop proc sp_COR_Profile_Count
go

CREATE PROCEDURE [dbo].[sp_COR_Profile_Count]
	@web_userid		varchar(100),
	@status_list	varchar(max) = 'all',
    @search				varchar(100) = '',
    @adv_search			varchar(max) = '',
	@generator_size		varchar(75) = '',
	@generator_name		varchar(75) = '',
	@generator_site_type	varchar(max) = '',
	@profile_id			varchar(max) = '',	-- Can take a CSV list
	@approval_code		varchar(max) = '',	-- Can take a CSV list
	@waste_common_name	varchar(50) = '',
	@epa_waste_code		varchar(max) = '',	-- Can take a CSV list
   	@facility_search	varchar(max) = '',  -- Seaches/limits any part of facility name, city, state
	@facility_id_list	varchar(max) = '',  -- Seaches/limits by company_id|profit_ctr_id csv input
	@copy_status		varchar(10) = '',
	@sort			varchar(20) = 'Modified Date',
	@page			int = 1,
	@perpage		int = 20,
    @excel_output		int = 0, -- or 1
	@customer_id_list varchar(max)='',  /* Added 2019-07-19 by AA */
    @generator_id_list varchar(max)='',  /* Added 2019-07-19 by AA */
	@owner			varchar(5) = 'all', /* 'mine' or 'all' */
	@period			varchar(4) = '', /* WW, MM, QQ, YY, 30 or 60 days */
	@tsdf_type			varchar(10) = 'All',  /* 'USE' or 'Non-USE' or 'ALL' */
	@haz_filter			varchar(20) = 'All',  /* 'All', 'RCRA', 'Non-RCRA', 'State', 'Non-Reg' */
	@under_review		char(1) = 'N' /* 'N'ot under review, 'U'nder review, 'A'ny  */
AS
/* ****************************************************************
ProfileList COUNT

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

[sp_COR_Profile_COUNT] 
	@web_userid = 'Jamie.Huens@Wal-Mart.com', 
    @status_list = null, 
    @search = '', 
    @adv_search = '', 
	@generator_name		= '',
	@profile_id			= '',
	@waste_common_name	= '',
	@epa_waste_code		= '',
    @copy_status = null, 
    @sort = 'Waste Common Name',
    @page = 7, 
    @perpage = 2000
 
[sp_COR_Profile_List] 
    @web_userid = 'customer.demo@usecology.com', 
	@status_list = '', 
	@search = '', 
	@adv_search= '', 
	@generator_name		= '',
	@profile_id			= '',
	@waste_common_name	= '',
	@epa_waste_code		= '',
    @copy_status = null, 
	@page = 1, 
	@perpage = 200

[sp_COR_Profile_count] 
    @web_userid = 'nyswyn100', 
    @status_list = 'all', 
    @search = '', 
	@adv_search = '' , 
	@generator_name		= '',
	-- @generator_site_type = 'GE Renewable Energy',
	@profile_id			= '',
	@approval_code		= 'sol',
	@waste_common_name	= '',
	@epa_waste_code		= '',
    @copy_status = null, 
	@page = 1, 
    @perpage = 20000
    , @excel_output = 0
	, @owner = 'all'

[sp_COR_Profile_list] 
    @web_userid = 'nyswyn125', 
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


[sp_COR_Profile_Count] 
	@web_userid = 'customer.demo@usecology.com', 
    @status_list = 'draft, approved, expired', 
	@search = '', 
	@adv_search = '' , 
	@generator_name		= '002',
	@profile_id			= '',
	@waste_common_name	= '',
	@epa_waste_code		= 'D001',
    @copy_status = null, 
    @sort = 'foo',
	@page = 1, 
	@perpage = 200

 update profile set ap_expiration_date = '2/12/2018' WHERE profile_id = 347605
 update profile set ap_expiration_date = getdate()+10, display_status_uid = 5 WHERE profile_id = 550448
 
SELECT  *  FROM    contact WHERE web_userid = 'customer.demo@usecology.com'
SELECT  *  FROM    contact WHERE web_userid = 'nyswyn125'

SELECT  *  FROM    ContactCORProfileBucket
WHERE contact_id = 257290



Pending is only forms
Submitted is a status of a form, is not profiles
Approved is only profiles
Expired is only profiles (approved) that have a past date
For Renewal is only profiles that have an expiration date <= 30 days from today


11/8/2018 call notes
 * Status Search Criteria
	Draft: All
	Draft: Draft
	Draft: Submitted
	Draft: Needs Customer Response


* Need to return count of results per status
	May need a separate procedure/service for returning just counts by types

5/24/2021
	DO-20902 - add profile.inactive_flag to output


**************************************************************** */
--DECLARE 
--    @web_userid        varchar(100)='nyswyn100',
--    @status_list    varchar(max) = '',
--    @search            varchar(100)='hf',
--    @adv_search        varchar(max),
--    @copy_status    varchar(10),
--    @sort            varchar(20) = 'Modified Date',
--    @page            int = 1,
--    @perpage        int = 20

-- avoid query plan caching:
declare
    @i_web_userid			varchar(100) = isnull(@web_userid,''),
    @i_status_list		varchar(max) = isnull(@status_list, ''),
    @i_search				varchar(100) = isnull(@search, ''),
    @i_adv_search			varchar(max) = isnull(@adv_search, ''),
	@i_generator_size		varchar(75) = isnull(@generator_size, ''),
	@i_generator_name		varchar(75) = isnull(@generator_name, ''),
	@i_generator_site_type		varchar(max) = isnull(@generator_site_type, ''),
	@i_profile_id			varchar(max) = isnull(@profile_id, ''),	-- Can take a CSV list
	@i_approval_code		varchar(max) = isnull(@approval_code, ''), -- Can take a CSV list
	@i_waste_common_name	varchar(50) = isnull(@waste_common_name, ''),
	@i_epa_waste_code		varchar(max) = isnull(@epa_waste_code, ''),	-- Can take a CSV list
	@i_facility_search		varchar(max) = isnull(@facility_search, ''),
	@i_facility_id_list		varchar(max) = isnull(@facility_id_list, ''),
    @i_copy_status		varchar(10) = isnull(@copy_status, ''),
    @i_sort				varchar(20) = isnull(@sort, ''),
    @i_page				int = isnull(@page, 1),
    @i_perpage			int = isnull(@perpage, 20),
    @i_excel_output	int = isnull(@excel_output, 0),
	@i_totalcount		int,
    @i_owner			varchar(5) = isnull(@owner, 'all'),
    @i_email			varchar(100),
    @i_contact_id		int,
    @i_period				varchar(4) = isnull(@period, ''),
    @i_customer_id_list	varchar(max) = isnull(@customer_id_list, ''),
    @i_generator_id_list	varchar(max) = isnull(@generator_id_list, ''),
    @i_tsdf_type		varchar(10) = isnull(@tsdf_type, 'USE'),
    @i_haz_filter		varchar(20) = isnull(@haz_filter, 'All'),
	@i_under_review		char(1) = isnull(@under_review, 'N')

declare @out table (
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

insert @out
exec sp_COR_Profile_List
    @web_userid			= @i_web_userid,
    @status_list		= @i_status_list,
    @search				= @i_search,
    @adv_search			= @i_adv_search,
	@generator_size		= @i_generator_size,
	@generator_name		= @i_generator_name,
	@generator_site_type = @i_generator_site_type,
	@profile_id			= @i_profile_id,
	@approval_code		= @i_approval_code,
	@waste_common_name	= @i_waste_common_name,
	@epa_waste_code		= @i_epa_waste_code,	-- Can take a CSV list
	@facility_search	= @i_facility_search,
	@facility_id_list	= @i_facility_id_list,
    @copy_status		= @i_copy_status,
    @sort				= @i_sort,
    @page				= @i_page,
    @perpage			= 99999999,
    @excel_output		= @i_excel_output, -- or 1
	@customer_id_list 	= @i_customer_id_list,
    @generator_id_list 	= @i_generator_id_list,
	@owner				= @i_owner,
	@period				= @i_period,
	@tsdf_type			= @i_tsdf_type,
	@haz_filter			= @i_haz_filter,
	@under_review		= @i_under_review

declare @status_options table (
	display_status	varchar(40)
)
insert @status_options
select 'Approved' union select 'For Renewal' union select 'Expired'

select 
	y.display_status, count(x.profile_id) as status_count
from 
(	select display_status from @status_options
) y left join
(
	select 
	*
	from @out
) x
on y.display_status = x.status
GROUP BY y.display_status
order by y.display_status
--where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
--order by _row

 
RETURN 0


GO

GRANT EXECUTE ON [dbo].[sp_COR_Profile_Count] TO COR_USER;

GO
