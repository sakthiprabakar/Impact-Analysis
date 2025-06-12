USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS sp_COR_Profile_List

GO

CREATE  PROCEDURE [dbo].[sp_COR_Profile_List]
    @web_userid			varchar(100),
    @status_list		varchar(max) = 'all',
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
    @sort				varchar(20) = '',
    @page				int = 1,
    @perpage			int = 20,
    @excel_output		int = 0, -- or 1
	@customer_id_list	varchar(max)='',  /* Added 2019-07-19 by AA */
    @generator_id_list	varchar(max)='',  /* Added 2019-07-19 by AA */
	@owner				varchar(5) = 'all', /* 'mine' or 'all' */
	@period				varchar(4) = '', /* WW, MM, QQ, YY, 30 or 60 days */
	@tsdf_type			varchar(10) = 'All',  /* 'USE' or 'Non-USE' or 'ALL' */
	@haz_filter			varchar(20) = 'All',  /* 'All', 'RCRA', 'Non-RCRA', 'State', 'Non-Reg' */
	@under_review		char(1) = 'N' /* 'N'ot under review, 'U'nder review, 'A'ny  */
	
AS
/* ****************************************************************
ProfileList
 
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
 
[sp_COR_Profile_List] 
    @web_userid = 'Jamie.Huens@Wal-Mart.com', 
    @status_list = null, 
    @search = '', 
    @adv_search = '', 
	@generator_name		= '',
	@profile_id			= '',
	@approval_code		= '',
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
	@profile_id			= 'solid',
	@approval_code		= '',
	@waste_common_name	= '',
	@epa_waste_code		= '',
    @copy_status = null, 
    @page = 1, 
    @perpage = 200
 
[sp_COR_Profile_List] 
-- [sp_COR_Profile_Count] 
    @web_userid = 'nyswyn100', 
    -- @status_list = 'expired', 
    --@status_list = 'approved,for renewal', 
    @search = '', 
    @adv_search = '' , 
	@generator_name		= '',
	-- @generator_site_type = 'GE Renewable Energy',
	-- @profile_id			= '77884466 ',
	@approval_code		= '',
	@waste_common_name	= '',
	@epa_waste_code		= '',
	-- @facility_search = 'detroit',
    @copy_status = null, 
    -- @tsdf_type = 'non-USE',
    -- @customer_id_list = '10877',
    -- @haz_filter = 'non-rcra',
    @page = 1, 
    @perpage = 20000
    , @under_review = 'N'

    , @excel_output = 0
	, @owner = 'all'
	, @period = '30'

[sp_COR_Profile_List] 
    @web_userid = 'customer.demo@usecology.com', 
    @status_list = 'draft, approved, expired', 
    @search = '', 
    @adv_search = '', 
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

--------------------------- 
18801-18812
	Please add the following logic to support viewing of 3rd 
		party profiles (TSDF Approvals) to the Approved Profiles List Page:

	Include the list of TSDF Approvals for the user’s access

[x]	On the Filter level, add a filter for TSDF Type and 
		include “All Profiles”, “USE Profiles” and “Non-USE Profiles”.
[x]	When the page is loaded, Default to “All Profiles”

[x]	Profiles should appear in the appropriate sub tab for the 
		Profile Status using the TSDF Approval current approval 
		status field [TSDFApproval.current_approval_status]
		
[x]	If there is no TSDF Current Approval Status assigned, the profile 
		should not be shown on COR2, should not be displayed in the ALL tab.
		
	In the Save to Excel file export, use the same existing format, 
		but put the TSDF Approval data in the following columns:

x	()
		Form ID = Leave Blank

x	(status)
		Status = TSDF Approval Status [TSDFApproval.current_approval_status] 

x	(pro_name)
		Profile Name = TSDF Approval Description [TSDFApproval.waste_desc]

x	(profile_id)		
		Profile ID = TSDF Approval ID [TSDFApproval.TSDF_approval_id] 
		
x	(approval_code_list)		
		Facility Code List = TSDF Name
		Approval Code = TSDF Approval Code [TSDFApproval.TSDF_approval_code]
		
x	(status)
		Display Status = TSDF Approval Current Approval Status [TSDFApproval.current_approval_status]
	
x	(expired_date)
		Expiration Date = TSDF Approval expiration date [TSDFApproval.TSDF_approval_expire_date]
	
x	(reapproval_allowed)
		Re-Approval Allowed = Leave Blank (we don’t store this for TSDF Approvals)
	
x	(pro_name)
		Waste Common Name = TSDF Approval’s approval description [TSDFApproval.waste_desc]
		
x	(waste_code_list)
		Waste Code List = TSDF Approval waste codes [TSDFApprovalWasteCode table]
---------------------------

DO-14458
	Add the four new filter types shown below.  These filter types should 
	be added to the current "Filter By:" drop down in the 
		"Forms & Profiles - Pending" 
		and 
		"Forms & Profiles - Approved" 
	sections.  
	
	The "Forms & Profiles - Expired" section does not currently have a "Filter By:" 
		option so one will need to be added.
		
	New Filter Type:
	"RCRA Regulated" 
		- Contains one or more federal waste codes (D, F, K P, or U).  
		Profiles may also include state waste codes.
	"Non-RCRA Regulated" 
		- Does not contain a federal waste code.  
		Profiles may include state waste codes.
	"State Regulated" 
		- Contains one or more state waste codes but 
		does not contain any federal waste codes.
	"Non-Regulated" 
		- Does not contain any federal or state waste codes.

5/24/2021
DO-20902 - add profile.inactive_flag to output
DO-18120 - add 'Data Update' exception to Docs Pending Status allowable records

6/13/2022 - DO-41782 - remove 2 month exclusion condition on formwcr's when listing expired profiles

**************************************************************** */


/*
---- Debug Info:
drop table #tmp
drop table #tmp2

DECLARE 
    @web_userid			varchar(100)='nyswyn100',
    @status_list		varchar(max) = 'expired',
    @search				varchar(100) = '',
    @adv_search			varchar(max) = '',
	@generator_size		varchar(75) = '',
	@generator_name		varchar(75) = '',
	@generator_site_type	varchar(max) = '',
	@profile_id			varchar(max) = '',	-- Can take a CSV list
	@approval_code		varchar(max) = '', -- Can take a CSV list
	@waste_common_name	varchar(50) = '',
	@epa_waste_code		varchar(max) = '',	-- Can take a CSV list
	@facility_search	varchar(max) = '',  -- Seaches/limits any part of facility name, city, state
	@facility_id_list	varchar(max) = '',  -- Seaches/limits by company_id|profit_ctr_id csv input
    @copy_status		varchar(10) = '',
    @sort				varchar(20) = 'Modified Date',
    @page				int = 1,
    @perpage			int = 10,
    @excel_output		int = 0, -- or 1
	@customer_id_list varchar(max)='',  /* Added 2019-07-19 by AA */
    @generator_id_list varchar(max)='',  /* Added 2019-07-19 by AA */
	@owner			varchar(5) = 'all', /* 'mine' or 'all' */
	@period			varchar(4) = '60' /* WW, MM, QQ, YY, 30 or 60 days */
	, @tsdf_type	= varchar(10)
	, @haz_filter   = varchar(20)
*/

-- avoid query plan caching:

drop table if exists #tmp

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
	@i_totalcount		int,
    @i_owner			varchar(5) = isnull(@owner, 'all'),
    @i_email			varchar(100),
    @i_contact_id		int,
    @i_period				varchar(4) = isnull(@period, ''),
    @i_period_int			int = 0,
    @i_customer_id_list	varchar(max) = isnull(@customer_id_list, ''),
    @i_generator_id_list	varchar(max) = isnull(@generator_id_list, ''),
    @i_tsdf_type		varchar(10) = isnull(@tsdf_type, 'USE'),
    @i_haz_filter		varchar(20) = isnull(@haz_filter, 'All'),
	@i_under_review		char(1) = isnull(@under_review, 'N')

select top 1 
	@i_contact_id = contact_id
	, @i_email = email
from CORcontact c 
WHERE web_userid = @i_web_userid
and web_userid <> ''

select @i_period_int =
	case @i_period
		when 'WW' then datediff(dd, dateadd(ww, -1, getdate()) , getdate())
		when 'QQ' then datediff(dd, dateadd(qq, -1, getdate()) , getdate())
		when 'MM' then datediff(dd, dateadd(mm, -1, getdate()) , getdate())
		when 'YY' then datediff(dd, dateadd(yyyy, -1, getdate()) , getdate())
		when '30' then 30
		when '60' then 60
		else ''
	end
	


if @i_status_list = '' set @i_status_list = 'all'
 
if @i_sort not in ('Generator Name', 'Profile Number', 'Waste Common Name', 'RCRA Status', 'Modified Date', 'Expiration Date') set @i_sort = ''
if @i_sort = '' and @i_status_list = 'Expired' set @i_sort = 'Expiration Date'
if @i_sort = '' set @i_sort = 'Modified Date'

declare @generatorsize table (
	generator_type	varchar(20)
)
if @i_generator_size <> ''
insert @generatorsize
select left(row, 20)
from dbo.fn_SplitXsvText(',', 1, @i_generator_size)
-- test output: select * from @generatorsize

-- test values: declare @i_profile_id varchar(50) = '1324,abc,1.001,9999999999999'
declare @profile_ids table (
	profile_id	bigint
)
if @i_profile_id <> ''
insert @profile_ids
select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, replace(@i_profile_id, ' ', ','))
where isnumeric(row) = 1
and row not like '%.%'
-- test output: select * from @profile_ids

-- test values: declare @i_approval_code varchar(50) = '1324,abc,1.001,9999999999999'
declare @approval_codes table (
	idx int,
	approval_code varchar(20)
)
if @i_approval_code <> ''
insert @approval_codes
select idx, replace('%' + replace(left(row, 20), '*', '%') + '%', '%%', '%')
from dbo.fn_SplitXsvText(',', 1, @i_approval_code)
where isnull(row,'') > ''
-- test output: select * from @approval_codes

-- DO:18422 - they want to combine approval codes with profile id's in search, via the @profile_id field.
-- This is easy if we treat @profile_id input as simply additional @approval_code input.
if @i_profile_id <> ''
insert @approval_codes (idx, approval_code)
select idx, case when isnumeric(row) = 1 then row else replace('%' + replace(left(row, 20), '*', '%') + '%', '%%', '%') end
from dbo.fn_SplitXsvText(',', 1, replace(@i_profile_id, ' ', ','))
where isnull(row,'') > ''
and not exists (select 1 from @approval_codes where approval_code = replace('%' + replace(left(row, 20), '*', '%') + '%', '%%', '%'))
-- This means we can't rely on @i_profile_id <> '' anymore to mean there were profile_id search inputs.
-- Because now it could be in @approval_codes instead. So we need a new flag to indicate that a search
-- should happen against integer profile_id's.
declare @search_profile_id bit = 0
select @search_profile_id = 1 where exists (select 1 from @profile_ids)

-- test values: declare @i_profile_id varchar(50) = '1324,abc,1.001,9999999999999'
declare @wastecodes table (
	waste_code	varchar(10)
)
if @i_epa_waste_code <> ''
insert @wastecodes
select left(row, 10)
from dbo.fn_SplitXsvText(',', 1, @i_epa_waste_code)
-- test output: select * from @profile_ids


declare @status table (
	i_status	varchar(40)
)
if isnull(@i_status_list, 'all') <> 'all'
insert @status
select left(row,40)
from dbo.fn_SplitXsvText(',', 1, @i_status_list)
where row is not null

if ltrim(rtrim(@i_status_list)) = 'all'
insert @status
select 'Approved' union all select 'For Renewal' -- union all select 'Expired'

declare @customer table (
	customer_id	int
)
if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator table (
	generator_id	int
)
if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

declare @generatorsitetype table (
	site_type	varchar(40)
)
if @i_generator_site_type <> ''
insert @generatorsitetype select left(row, 40)
from dbo.fn_SplitXsvText(',', 1, @i_generator_site_type)
where row is not null

declare @facility table (
	company_id	int,
	profit_ctr_id	int
)
if @i_facility_search <> ''
insert @facility 
select distinct company_id, profit_ctr_id
from USE_Profitcenter upc
join (
	select row
	from dbo.fn_SplitXsvText(' ', 1, replace(@i_facility_search, ',', ' '))
	where row is not null
) x
on isnull(upc.name, '') + ' ' +
	isnull(upc.address_1, '') + ' ' +
	isnull(upc.address_2, '') + ' ' +
	isnull(upc.address_3, '')
	like '%' + x.row + '%'

declare @tsdf table (
	tsdf_code	varchar(15)
)
if @i_facility_search <> ''
insert @tsdf 
select distinct tsdf_code
from TSDF
join (
	select row
	from dbo.fn_SplitXsvText(' ', 1, replace(@i_facility_search, ',', ' '))
	where row is not null
) x
on isnull(tsdf.tsdf_name, '') + ' ' +
	isnull(tsdf.tsdf_addr1, '') + ' ' +
	isnull(tsdf.tsdf_addr2, '') + ' ' +
	isnull(tsdf.tsdf_addr3, '') + ' ' +
	isnull(tsdf.tsdf_city, '') + ' ' +
	isnull(tsdf.tsdf_state, '') + ' '
	like '%' + x.row + '%'
where tsdf_status = 'A' and isnull(eq_flag, 'F') = 'F'

declare @facility_id table (
	company_id	int,
	profit_ctr_id	int
)
if @i_facility_id_list <> ''
insert @facility_id 
select distinct company_id, profit_ctr_id
from USE_Profitcenter upc
join (
	select row
	from dbo.fn_SplitXsvText(' ', 1, replace(@i_facility_id_list, ',', ' '))
	where row is not null
) x
on isnull(convert(varchar(2),upc.company_id), '') + '|' + isnull(convert(varchar(2),upc.profit_ctr_id), '') = row


if isnull(@i_period_int, 0) <=1
	and exists (select 1 from @status where i_status like '%renewal 60%')
	set @i_period_int = 60

if isnull(@i_period_int, 0) <=1
	and exists (select 1 from @status where i_status like '%renewal%')
	set @i_period_int = 30

--#region USE Profile Search
 
select 
    profile_id,
	-- STUFF(REPLACE(approval_code_list, '&amp;', '&'),1,1, '') approval_code_list,
	approval_code_list,
    approval_desc,
    generator_id,
    generator_name,
    site_type,
    generator_type,
    epa_id,
    customer_id,
    cust_name,
    curr_status_code,
    ap_expiration_date,
    prices,
    date_modified,
	reapproval_allowed,
	inactive_flag,
    display_status,
    copy_source,
    -- 0 AS total_profile_list,
	waste_code_list,
	document_update_status,
	convert(varchar(10),'USE') as tsdf_type,
	under_review = x.under_review,
    _row
    INTO #TMP
from (
    select 
        p.profile_id,
        
		( select substring(
			(
				select '<br/>' + 
				isnull(pqa.approval_code, '')
				+ ' : ' +
				isnull(convert(varchar(2),use_pc.company_id), '') + '|' + isnull(convert(varchar(2), use_pc.profit_ctr_id), '')
				+ ' : ' +
				isnull(use_pc.name, '') + isnull(' ('+ use_pc.epa_id+') ','')
				+ ' : ' +
				isnull(use_pc.address_1, '')
				+ ' : ' +
				isnull(use_pc.address_2, '')
				+ ' : ' +
				isnull(use_pc.address_3, '')
				
			FROM profilequoteapproval pqa (nolock)
			join USE_ProfitCenter use_pc (nolock)
				on pqa.company_id = use_pc.company_id
				and pqa.profit_ctr_id = use_pc.profit_ctr_id
			where pqa.profile_id = p.profile_id
			and pqa.status = 'A'
			order by use_pc.name
			for xml path, TYPE).value('.[1]','nvarchar(max)'),6,20000)
		)  approval_code_list,

        p.approval_desc,
        p.generator_id,
        gn.generator_name,
        gn.site_type,
        gn.epa_id,
        gt.generator_type,
        p.customer_id,
        cn.cust_name,
        p.curr_status_code,
        p.ap_expiration_date,
        b.prices,
        p.date_modified,
		p.reapproval_allowed,
		p.inactive_flag,
        display_status = 
		case when 
				exists (select 1 from @status where i_status like 'For Renewal%')
				and p.ap_expiration_date > getdate() and p.ap_expiration_date <= getdate()+@i_period_int then 'For Renewal' else
				case when 
					p.ap_expiration_date < getdate() then 'Expired' else
					case when p.ap_expiration_date > getdate() then 'Approved' else
						''
					end
				end
			end
			,
        null as copy_source,
		dbo.fn_profile_waste_code_list (p.profile_id, 'X')  as waste_code_list,
		p.document_update_status,
		case when	
				(
					p.document_update_status <> 'P'
					OR
					p.document_update_status = 'P' AND p.doc_status_reason in (
						'Rejection in Process', 
						'Amendment in Process', 
						'Renewal in Process',
						'Profile Sync Required',
						'Data Update')
				)
		then 'N' else 'U' end as under_review,		
        _row = row_number() over (order by 
            case when @i_sort = 'Generator Name' then gn.generator_name end asc,
            case when @i_sort = 'Site Type' then gn.site_type end asc,
            case when @i_sort = 'Profile Number' then p.profile_id end asc,
            case when @i_sort = 'Waste Common Name' then p.approval_desc end asc,
            case when @i_sort = 'RCRA Status' then gt.generator_type end asc,
            case when @i_sort in ('', 'Modified Date') then p.date_modified end desc,
			case when @i_sort = 'Expiration Date' then p.ap_expiration_date end desc
			, p.profile_id
        ) 
    --from ContactProfileBucket b
    from ContactCORProfileBucket b
    join [Profile] p
        on b.profile_id = p.profile_id
    join Customer cn on p.customer_id = cn.customer_id
    join Generator gn on p.generator_id = gn.generator_id
    left join generatortype gt on gn.generator_type_id = gt.generator_type_id
	where b.contact_id = @i_contact_id
	and @i_tsdf_type in ('USE', 'ALL')
	and p.curr_status_code = 'A'
	--- 3/22/2020 (RE enabled this, it was previously removed)
	-- disabled (again 8/25 for under_review functionality)
	--AND (
	--	p.document_update_status <> 'P'
	--	OR
	--	p.document_update_status = 'P' AND p.doc_status_reason in (
	--		'Rejection in Process', 
	--		'Amendment in Process', 
	--		'Renewal in Process',
	--		'Profile Sync Required',
	--		'Data Update')
	--)
	and p.ap_expiration_date > dateadd(yyyy, -2, getdate())
    and 1 = 
		case 
			when @i_owner = 'mine' 
			and (@i_email in (p.added_by /*, p.modified_by */)  or @i_web_userid in (p.added_by /*, p.modified_by */))
			then 1 else 
			case when exists (
				select top 1 1
				from formwcr
				where form_id = p.form_id_wcr
				and (
					@i_email in (formwcr.created_by /*, formwcr.modified_by */)
					or 
					@i_web_userid in (formwcr.created_by /*, formwcr.modified_by */)
				)
				) then 1 else 
					case when @i_owner = 'all' then 1 else 0 end
				end
			end
    and 1 = case when 
				exists (select 1 from @status where i_status like 'For Renewal%')
				and p.ap_expiration_date > getdate() and p.ap_expiration_date <= getdate()+@i_period_int then 1 else
				case when 
					exists (select 1 from @status where i_status = 'Expired')
					and p.ap_expiration_date < getdate() 
/* -- 6/13/2022, DO-41782
					and not exists (
						select 1 from formWCR fw where fw.profile_id = p.profile_id 
						and isnull(fw.signing_date, getdate()+2) between dateadd(mm, -2, getdate()) and getdate()
					)
*/					
					then 1 else				
						case when 
							exists (select 1 from @status where i_status = 'Approved')
							and p.ap_expiration_date > getdate() 
							and not (p.ap_expiration_date > getdate() and p.ap_expiration_date <= getdate()+30)
							then 1 else 0
						end
					end
				end
    and 
    (
        @i_search = ''
        or
        (
			@i_search <> ''
			and 
			convert(varchar(20), p.profile_id) + ' ' +
			p.approval_desc + ' ' + 
			gn.generator_name + ' ' +
			gn.epa_id + ' ' +
			cn.cust_name + ' ' +
			isnull(( select substring(
				(
					select ', ' + 
					isnull(pqa.approval_code, '')
				FROM profilequoteapproval pqa (nolock)
				where pqa.profile_id = p.profile_id
				and pqa.status = 'A'
				for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
			) , '')	
			like '%' + replace(@i_search, ' ', '%') + '%'
        )
    )
    and 
    (
        @i_generator_size = ''
        or
        (
			@i_generator_size <> ''
			and
			gt.generator_type in (select generator_type from @generatorsize)
		)
	)
    and 
    (
        @i_generator_name = ''
        or
        (
			@i_generator_name <> ''
			and
			gn.generator_name like '%' + replace(@i_generator_name, ' ', '%') + '%'
		)
	)
/*	
    and 
    (
        @search_profile_id = 0
        or
        (
			@search_profile_id = 1
			and
			p.profile_id in (select profile_id from @profile_ids)
		)
	)
*/	
    and 
    (
        @i_waste_common_name = ''
        or
        (
			@i_waste_common_name <> ''
			and
			p.approval_desc like '%' + replace(@i_waste_common_name, ' ', '%') + '%'
		)
	)
    and 
    (
        @i_epa_waste_code = ''
        or
        (
			@i_epa_waste_code <> ''
			and
			exists(
				select top 1 1 from profilewastecode pwc (nolock)
				join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid and wc.display_name in (select waste_code from @wastecodes)
				where pwc.profile_id = p.profile_id 
			)
		)
	)  
	and
/*
	New Filter Type:
	"RCRA Regulated" 
		- Contains one or more federal waste codes (D, F, K P, or U).  
		Profiles may also include state waste codes.
	"Non-RCRA Regulated" 
		- Does not contain a federal waste code.  
		Profiles may include state waste codes.
	"State Regulated" 
		- Contains one or more state waste codes but 
		does not contain any federal waste codes.
	"Non-Regulated" 
		- Does not contain any federal or state waste codes.
*/		
	
	(
		@i_haz_filter in ('All', '')
		or
		(
			@i_haz_filter in ('rcra')
			and
			exists (
				select top 1 1 from profilewastecode pwc (nolock)
				join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
					and wc.waste_code_origin = 'F'
					and left(wc.display_name, 1) in ('D', 'F', 'K', 'P', 'U')
				where pwc.profile_id = p.profile_id 
			)
		)
		or
		(
			@i_haz_filter in ('non-rcra')
			and
			not exists (
				select top 1 1 from profilewastecode pwc (nolock)
				join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
					and wc.waste_code_origin = 'F'
					and left(wc.display_name, 1) in ('D', 'F', 'K', 'P', 'U')
				where pwc.profile_id = p.profile_id 
			)
		)
		or
		(
			@i_haz_filter in ('state')
			and
			exists (
				select top 1 1 from profilewastecode pwc (nolock)
				join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
					and wc.waste_code_origin = 'S'
				where pwc.profile_id = p.profile_id 
			)
			and
			not exists (
				select top 1 1 from profilewastecode pwc (nolock)
				join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
					and wc.waste_code_origin = 'F'
					and left(wc.display_name, 1) in ('D', 'F', 'K', 'P', 'U')
				where pwc.profile_id = p.profile_id 
			)
		)
		or
		(
			@i_haz_filter in ('non-regulated', 'non', 'Non-Reg')
			and
			not exists (
				select top 1 1 from profilewastecode pwc (nolock)
				join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
					and wc.waste_code_origin in ('S', 'F')
				where pwc.profile_id = p.profile_id 
			)
		)
	)
	and
    (
        @i_customer_id_list = ''
        or
        (
			@i_customer_id_list <> ''
			and
			(
				p.customer_id in (select customer_id from @customer)
				or
				p.orig_customer_id in (select customer_id from @customer)
			)
		)
	)
	and
    (
        @i_generator_id_list = ''
        or
        (
			@i_generator_id_list <> ''
			and
			p.generator_id in (select generator_id from @generator)
		)
	)
	and
    (
        @i_generator_site_type = ''
        or
        (
			@i_generator_site_type <> ''
			and
			gn.site_type in (select site_type from @generatorsitetype)
		)
	)
	and
    (
        @i_facility_search = ''
        or
        (
			@i_facility_search <> ''
			and
			exists (
				select 1 from ProfileQuoteApproval pqaf
				join @facility fac on pqaf.company_id = fac.company_id
					and pqaf.profit_ctr_id = fac.profit_ctr_id
				where pqaf.profile_id = p.profile_id
				and pqaf.status = 'A'
			)
		)
	)	
	and
    (
        @i_facility_id_list = ''
        or
        (
			@i_facility_id_list <> ''
			and
			exists (
				select 1 from ProfileQuoteApproval pqaf
				join @facility_id fac on pqaf.company_id = fac.company_id
					and pqaf.profit_ctr_id = fac.profit_ctr_id
				where pqaf.profile_id = p.profile_id
				and pqaf.status = 'A'
			)
		)
	)	
	/*
	and
	(
		@i_period = ''
		or
		(
			@i_period <> ''
			and
			exists
				(
				select profile_id
				FROM    ProfileTracking pt
				where pt.profile_id = p.profile_id
				and pt.profile_curr_status_code = p.curr_status_code
				and pt.tracking_status = 'COMP'
				and isnull(pt.time_out, pt.time_in) > 
					case @i_period 
						when 'WW' then dateadd(ww, -1, getdate()) 
						when 'MM' then dateadd(m, -1, getdate()) 
						when 'QQ' then dateadd(qq, -1, getdate()) 
						when 'YY' then dateadd(yyyy, -1, getdate()) 
						when '30' then dateadd(dd, (-1 * @i_period_int), getdate())
						when '60' then dateadd(dd, (-1 * @i_period_int), getdate())
						else getdate()+1 
					end
				) 
		)
	)
	*/

) x
--where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
--order by _row
--#endregion


--#region tsdf approval search
/* tsdf approval search here */
insert #tmp
select 
    profile_id,
	approval_code_list,
    approval_desc,
    generator_id,
    generator_name,
    site_type,
    generator_type,
    epa_id,
    customer_id,
    cust_name,
    curr_status_code,
    ap_expiration_date,
    prices,
    date_modified,
	reapproval_allowed,
	inactive_flag,
    display_status,
    copy_source,
    -- 0 AS total_profile_list,
	waste_code_list,
	document_update_status,
	'Non-USE' as tsdf_type,
	'N' as under_review,
    _row
    -- INTO #TMP
from (
    select 
        ta.tsdf_approval_id profile_id,
        
		isnull(ta.tsdf_approval_code, '')
		+ ' : ' +
		isnull(tsdf.tsdf_name,'') + isnull(' ('+ tsdf.TSDF_EPA_ID+') ', '')
		+' : ' 
		+isnull(tsdf.TSDF_addr1, '')
		+' : ' 
		+isnull(tsdf.TSDF_city, '')
		+' : ' 
		+isnull(tsdf.TSDF_state, '')
		+' : ' 
		+isnull(tsdf.TSDF_zip_code, '')
		+' : ' 
		+isnull(tsdf.TSDF_country_code, '')
			approval_code_list,

        ta.waste_desc approval_desc,
        ta.generator_id,
        gn.generator_name,
        gn.site_type,
        gn.epa_id,
        gt.generator_type,
        ta.customer_id,
        cn.cust_name,
        ta.TSDF_approval_status curr_status_code,
        ta.TSDF_approval_expire_date ap_expiration_date,
        'F' prices,
        ta.date_modified,
		'' reapproval_allowed,
		null as inactive_flag,
        display_status = 
		case when 
			ta.TSDF_approval_expire_date < getdate() then 'Expired' else
			case when ta.TSDF_approval_expire_date > getdate() then 'Approved' else
				''
			end
		end
		,
        null as copy_source,
		dbo.fn_profile_waste_code_list (ta.tsdf_approval_id, 'U')  as waste_code_list,
		'' document_update_status,
        _row = (select isnull(max(_row),0)+1 from #tmp) + row_number() over (order by 
            case when @i_sort = 'Generator Name' then gn.generator_name end asc,
            case when @i_sort = 'Site Type' then gn.site_type end asc,
            case when @i_sort = 'Profile Number' then ta.tsdf_approval_id end asc,
            case when @i_sort = 'Waste Common Name' then ta.waste_desc end asc,
            case when @i_sort = 'RCRA Status' then gt.generator_type end asc,
            case when @i_sort in ('', 'Modified Date') then ta.date_modified end desc,
			case when @i_sort = 'Expiration Date' then ta.TSDF_approval_expire_date  end desc
			, ta.tsdf_approval_id
        ) 
    from tsdfapproval ta  (nolock)
    join tsdf (nolock)
		on ta.tsdf_code = tsdf.tsdf_code
		and tsdf.tsdf_status = 'A'
		and isnull(tsdf.eq_flag, 'F') = 'F'
    join Customer cn on ta.customer_id = cn.customer_id
    join Generator gn on ta.generator_id = gn.generator_id
    left join generatortype gt on gn.generator_type_id = gt.generator_type_id
	where 
	-- b.contact_id = @i_contact_id
	(
		ta.customer_id in (select customer_id from ContactCORCustomerBucket where contact_id = @i_contact_id)
		or
		ta.generator_id in (select generator_id from ContactCORGeneratorBucket where contact_id = @i_contact_id and direct_flag = 'D')
	)
	and @i_tsdf_type in ('Non-USE', 'ALL')
	and ta.current_approval_status = 'COMP'
	and ta.TSDF_approval_status = 'A'
	and ta.TSDF_approval_expire_date > dateadd(yyyy, -2, getdate())
    and 1 = case when 
				exists (select 1 from @status where i_status = 'Expired')
				and ta.TSDF_approval_expire_date < getdate() 
				then 1 else				
					case when 
						exists (select 1 from @status where i_status = 'Approved')
						and ta.TSDF_approval_expire_date > getdate() 
						then 1 else 0
					end
				end
    and 
    (
        @i_search = ''
        or
        (
			@i_search <> ''
			and 
			convert(varchar(20), ta.tsdf_approval_id) + ' ' +
			ta.waste_desc + ' ' + 
			gn.generator_name + ' ' +
			gn.epa_id + ' ' +
			cn.cust_name + ' ' +
			isnull(ta.tsdf_approval_code, '')
			like '%' + replace(@i_search, ' ', '%') + '%'
        )
    )
    and 
    (
        @i_generator_size = ''
        or
        (
			@i_generator_size <> ''
			and
			gt.generator_type in (select generator_type from @generatorsize)
		)
	)
    and 
    (
        @i_generator_name = ''
        or
        (
			@i_generator_name <> ''
			and
			gn.generator_name like '%' + replace(@i_generator_name, ' ', '%') + '%'
		)
	)
/*	
    and 
    (
        @search_profile_id = 0
        or
        (
			@search_profile_id = 1
			and
			p.profile_id in (select profile_id from @profile_ids)
		)
	)
*/	
    and 
    (
        @i_waste_common_name = ''
        or
        (
			@i_waste_common_name <> ''
			and
			ta.waste_desc like '%' + replace(@i_waste_common_name, ' ', '%') + '%'
		)
	)
    and 
    (
        @i_epa_waste_code = ''
        or
        (
			@i_epa_waste_code <> ''
			and
			exists(
				select top 1 1 from tsdfapprovalwastecode pwc (nolock)
				join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid and wc.display_name in (select waste_code from @wastecodes)
				where pwc.TSDF_approval_id = ta.TSDF_approval_id
				and pwc.company_id = ta.company_id and pwc.profit_ctr_id = ta.profit_ctr_id 
			)
		)
	)    

	and
/*
	New Filter Type:
	"RCRA Regulated" 
		- Contains one or more federal waste codes (D, F, K P, or U).  
		Profiles may also include state waste codes.
	"Non-RCRA Regulated" 
		- Does not contain a federal waste code.  
		Profiles may include state waste codes.
	"State Regulated" 
		- Contains one or more state waste codes but 
		does not contain any federal waste codes.
	"Non-Regulated" 
		- Does not contain any federal or state waste codes.
*/		
	(
		@i_haz_filter in ('All', '')
		or
		(
			@i_haz_filter in ('rcra')
			and
			exists (
				select top 1 1 from tsdfapprovalwastecode pwc (nolock)
				join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
					and wc.waste_code_origin = 'F'
					and left(wc.display_name, 1) in ('D', 'F', 'K', 'P', 'U')
				where pwc.TSDF_approval_id = ta.TSDF_approval_id
				and pwc.company_id = ta.company_id and pwc.profit_ctr_id = ta.profit_ctr_id 
			)
		)
		or
		(
			@i_haz_filter in ('non-rcra')
			and
			not exists (
				select top 1 1 from tsdfapprovalwastecode pwc (nolock)
				join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
					and wc.waste_code_origin = 'F'
					and left(wc.display_name, 1) in ('D', 'F', 'K', 'P', 'U')
				where pwc.TSDF_approval_id = ta.TSDF_approval_id
				and pwc.company_id = ta.company_id and pwc.profit_ctr_id = ta.profit_ctr_id 
			)
		)
		or
		(
			@i_haz_filter in ('state')
			and
			exists (
				select top 1 1 from tsdfapprovalwastecode pwc (nolock)
				join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
					and wc.waste_code_origin = 'S'
				where pwc.TSDF_approval_id = ta.TSDF_approval_id
				and pwc.company_id = ta.company_id and pwc.profit_ctr_id = ta.profit_ctr_id 
			)
			and
			not exists (
				select top 1 1 from tsdfapprovalwastecode pwc (nolock)
				join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
					and wc.waste_code_origin = 'F'
					and left(wc.display_name, 1) in ('D', 'F', 'K', 'P', 'U')
				where pwc.TSDF_approval_id = ta.TSDF_approval_id
				and pwc.company_id = ta.company_id and pwc.profit_ctr_id = ta.profit_ctr_id 
			)
		)
		or
		(
			@i_haz_filter in ('non-regulated', 'non', 'Non-Reg')
			and
			not exists (
				select top 1 1 from tsdfapprovalwastecode pwc (nolock)
				join wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
					and wc.waste_code_origin in ('S', 'F')
				where pwc.TSDF_approval_id = ta.TSDF_approval_id
				and pwc.company_id = ta.company_id and pwc.profit_ctr_id = ta.profit_ctr_id 
			)
		)
	)
	and
    (
        @i_customer_id_list = ''
        or
        (
			@i_customer_id_list <> ''
			and
			(
				ta.customer_id in (select customer_id from @customer)
			)
		)
	)
	and
    (
        @i_generator_id_list = ''
        or
        (
			@i_generator_id_list <> ''
			and
			ta.generator_id in (select generator_id from @generator)
		)
	)
	and
    (
        @i_generator_site_type = ''
        or
        (
			@i_generator_site_type <> ''
			and
			gn.site_type in (select site_type from @generatorsitetype)
		)
	)
	and
    (
        @i_facility_search = ''
        or
        (
			@i_facility_search <> ''
			and
			exists (
				select 1 from @tsdf where tsdf_code = ta.tsdf_code
			)
		)
	)	
	and
    (
        @i_facility_id_list = ''
        or
        (
			@i_facility_id_list <> ''
			and
			exists (
				select 1 from tsdfapproval pqaf join tsdf pqaft on pqaf.tsdf_code = pqaft.tsdf_code
				join @facility_id fac on pqaf.company_id = fac.company_id
					and pqaf.profit_ctr_id = fac.profit_ctr_id
				where pqaf.tsdf_approval_id = ta.tsdf_approval_id
				and pqaf.TSDF_approval_status = 'A'
				and isnull(pqaft.eq_flag, 'F') = 'F'
			)
		)
	)	
	/*
	and
	(
		@i_period = ''
		or
		(
			@i_period <> ''
			and
			exists
				(
				select profile_id
				FROM    ProfileTracking pt
				where pt.profile_id = p.profile_id
				and pt.profile_curr_status_code = p.curr_status_code
				and pt.tracking_status = 'COMP'
				and isnull(pt.time_out, pt.time_in) > 
					case @i_period 
						when 'WW' then dateadd(ww, -1, getdate()) 
						when 'MM' then dateadd(m, -1, getdate()) 
						when 'QQ' then dateadd(qq, -1, getdate()) 
						when 'YY' then dateadd(yyyy, -1, getdate()) 
						when '30' then dateadd(dd, (-1 * @i_period_int), getdate())
						when '60' then dateadd(dd, (-1 * @i_period_int), getdate())
						else getdate()+1 
					end
				) 
		)
	)
	*/

) x
--where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
--order by _row

--#endregion

/* end of tsdf approval search */

-- Under Review (@i_under_review:  'N'ot under review, 'U'nder review, 'A'ny):

	drop table if exists #tmp_ur
	
	select distinct
		t.profile_id,
		t.approval_code_list,
		t.approval_desc,
		t.generator_id,
		t.generator_name,
		t.site_type,
		t.generator_type,
		t.epa_id,
		t.customer_id,
		t.cust_name,
		t.curr_status_code,
		t.ap_expiration_date,
		t.prices,
		t.date_modified,
		t.reapproval_allowed,
		t.inactive_flag,
		t.display_status,
		t.copy_source,
		t.waste_code_list,
		t.document_update_status,
		t.tsdf_type,
		t.under_review,
		_row -- = row_number() over (order by _row)
	into #tmp_ur
	from #tmp t
	where under_review = case @i_under_review
		when 'A' then under_review
		else @i_under_review
	end



	-- drop table if exists #tmp
	truncate table #tmp
	insert #tmp
	select 
	distinct
		t.profile_id,
		t.approval_code_list,
		t.approval_desc,
		t.generator_id,
		t.generator_name,
		t.site_type,
		t.generator_type,
		t.epa_id,
		t.customer_id,
		t.cust_name,
		t.curr_status_code,
		t.ap_expiration_date,
		t.prices,
		t.date_modified,
		t.reapproval_allowed,
		t.inactive_flag,
		t.display_status,
		t.copy_source,
		t.waste_code_list,
		t.document_update_status,
		t.tsdf_type,
		t.under_review,
		_row = row_number() over (order by _row)
		from #tmp_ur t
-- end of under_review logic


if exists (select 1 from @approval_codes) begin

	drop table if exists #tmpac

	select distinct
		t.profile_id,
		t.approval_code_list,
		t.approval_desc,
		t.generator_id,
		t.generator_name,
		t.site_type,
		t.generator_type,
		t.epa_id,
		t.customer_id,
		t.cust_name,
		t.curr_status_code,
		t.ap_expiration_date,
		t.prices,
		t.date_modified,
		t.reapproval_allowed,
		t.inactive_flag,
		t.display_status,
		t.copy_source,
		t.waste_code_list,
		t.document_update_status,
		t.tsdf_type,
		t.under_review,
		_row -- = row_number() over (order by _row)
	into #tmpac
	from #tmp t
	left JOIN profilequoteapproval pqa (nolock)
		on t.profile_id = pqa.profile_id
		and pqa.status = 'A'
		and t.tsdf_type = 'USE'
	left join tsdfapproval ta (nolock)
		on t.profile_id = ta.tsdf_approval_id
		and t.tsdf_type = 'Non-USE'
	left join @approval_codes ac
		on (
			(t.tsdf_type = 'USE' and (pqa.approval_code like ac.approval_code	 or convert(varchar(20),pqa.profile_id) = ac.approval_code))
			or
			(t.tsdf_type = 'Non-USE' and (ta.tsdf_approval_code like ac.approval_code or convert(varchar(20), ta.tsdf_approval_id) = ac.approval_code))
		)
	WHERE 
	(
		(t.tsdf_type = 'USE'
			and (
				pqa.approval_code like ac.approval_code	
				or
				(isnumeric(ac.approval_code) = 1 and convert(varchar(20), t.profile_id) = ac.approval_code)
			)
		)
		OR
		(tsdf_type = 'Non-USE'
			and (
				ta.tsdf_approval_code like ac.approval_code
				or
				(isnumeric(ac.approval_code) = 1 and convert(varchar(20), t.profile_id) = ac.approval_code)
			)
		)
	)
		
	truncate table #tmp
	insert #tmp
	select 
	distinct
		t.profile_id,
		t.approval_code_list,
		t.approval_desc,
		t.generator_id,
		t.generator_name,
		t.site_type,
		t.generator_type,
		t.epa_id,
		t.customer_id,
		t.cust_name,
		t.curr_status_code,
		t.ap_expiration_date,
		t.prices,
		t.date_modified,
		t.reapproval_allowed,
		t.inactive_flag,
		t.display_status,
		t.copy_source,
		t.waste_code_list,
		t.document_update_status,
		t.tsdf_type,
		t.under_review,
		_row = row_number() over (order by tsdf_type desc, _row)
		from #tmpac t

end


if @i_period <> '' begin

	select 
		profile_id,
		approval_code_list,
		approval_desc,
		generator_id,
		generator_name,
		site_type,
		generator_type,
		epa_id,
		customer_id,
		cust_name,
		curr_status_code,
		ap_expiration_date,
		prices,
		date_modified,
		reapproval_allowed,
		inactive_flag,
		display_status,
		copy_source,
		waste_code_list,
		document_update_status,
		tsdf_type,
		under_review,
		_row = row_number() over (order by _row)
	into #tmp2
	from #tmp
	where 1 =
		case when display_status = 'Approved' and isnull(ap_expiration_date , getdate()+3) > getdate()
		then 1 
		else
			case when display_status = 'Expired' and isnull(ap_expiration_date , getdate()+3) < getdate() and isnull(ap_expiration_date , getdate()+3) > dateadd(dd, (@i_period_int * -1), getdate())
			then 1
			else
				case when tsdf_type <> 'Non-USE' and display_status = 'For Renewal' and isnull(ap_expiration_date , getdate()+3) > getdate() and isnull(ap_expiration_date , getdate()+3) < dateadd(dd, @i_period_int, getdate())
				then 1
				else 0
				end
			end
		end
		
	truncate table #tmp
	insert #tmp select * from #tmp2

end



select @i_totalcount = count(*) from #tmp

	SELECT    
		profile_id
		, approval_code_list
		,approval_desc AS pro_name
		,generator_id
		,generator_name AS gen_by
		,epa_id as Generator_EPA_ID
		,site_type
		,generator_type AS RCRA_status
		,date_modified AS updated_date
		,customer_id
		,cust_name AS updated_by
		,ap_expiration_date AS expired_date
		,copy_source AS profile
		,display_status as status
		,reapproval_allowed
		,inactive_flag
		,waste_code_list
		,document_update_status
		,tsdf_type
		,@i_totalcount AS totalcount 
	FROM #TMP 
	where @excel_output = 1 or (@excel_output = 0 and _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage) )
	order by _row

RETURN 0


 
GO

GRANT EXECUTE ON [dbo].[sp_COR_Profile_List] TO COR_USER;

GO
