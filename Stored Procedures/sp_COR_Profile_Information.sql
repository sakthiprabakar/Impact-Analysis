--  DROP PROCEDURE [dbo].[sp_COR_Profile_Information]
go

CREATE PROCEDURE [dbo].[sp_COR_Profile_Information]
	@web_userid		varchar(100)
	, @owner			varchar(5) = 'mine' /* 'mine' or 'all' */
	, @period			varchar(4) = '30' /* 30 or 60 days */
	, @customer_id_list varchar(max)=''  /* Added 2019-07-16 by AA */
	, @generator_id_list varchar(max)=''  /* Added 2019-07-16 by AA */
AS
/* ****************************************************************
sp_COR_Profile_Information

History:

	10/15/2019	MPM	DevOps 11586: Added logic to filter the result set
					using optional input parameters @customer_id_list and
					@generator_id_list.

5/24/2021
	DO-20902 - add profile.inactive_flag to output
6/9/2021
	DO-18801 - change tsdf_type flag from USE to ALL

Samples:

sp_COR_Profile_Information 
	@web_userid				= 'wastetech435'
	, @owner				= null
	, @period				= null
	, @customer_id_list		= '583'
    , @generator_id_list	= '170110, 175880'  
 
exec [sp_COR_Profile_Information] 
    @web_userid = 'nyswyn100', 
    @owner = 'all', 
    @period = '30'

exec [sp_COR_Profile_Information]
	@web_userid = 'nyswyn125', 
    @owner = 'all', 
    @period = 'yy'

exec [sp_COR_Profile_Information] 
	@web_userid = 'nyswyn100', 
    @owner = 'all', 
    @period = '60'

exec [sp_COR_Profile_Information] 
	@web_userid = 'nyswyn100', 
    @owner = 'all', 
    @period = '30'
    
sp_cor_profile_list    
	@web_userid = 'nyswyn100', 
    @page				= 1,
    @perpage			= 999999999,
    @owner = 'all'

-- Tweak a couple profiles to put data in visible categories for the demo user

SELECT  *  FROM    ContactCORProfileBucket WHERE contact_id = 185547

SELECT  *  FROM    profile WHERE profile_id in (470481, 470497, 470520, 470521, 470953) and curr_status_code = 'A'
update profile set ap_expiration_date = getdate() + 15  WHERE profile_id in (470481, 470497, 470520, 470521, 470953) and curr_status_code = 'A'

SELECT  *  FROM    profile WHERE profile_id in (555781, 568023, 568585, 576447) and curr_status_code = 'A'
update profile set ap_expiration_date = getdate() - 15  WHERE profile_id in (555781, 568023, 568585, 576447) and curr_status_code = 'A'

SELECT  *  FROM    profile WHERE profile_id in (343472, 468846, 468868, 468906) and curr_status_code = 'A'
update profile set ap_expiration_date = getdate() - 45  WHERE profile_id in (343472, 468846, 468868, 468906) and curr_status_code = 'A'



**************************************************************** */
--DECLARE @web_userid        varchar(100)='nyswyn100',  @owner varchar(5) = 'all',   @period int = 30
-- approval_count	15		expired_count	72		expiring_count	10

--DECLARE @web_userid        varchar(100)='nyswyn100',  @owner varchar(5) = 'all',   @period int = 60
-- approval_count	15		expired_count	72		expiring_count	10


-- avoid query plan caching:
declare
    @i_web_userid			varchar(100) = @web_userid,
    @i_owner				varchar(5) = isnull(@owner, 'mine'),
    @i_period				varchar(4) = convert(varchar(2), isnull(@period, '30')),
    @i_period_int			int = 30,
	@i_contact_id			int,
	@i_email				varchar(100),
	@i_approval_count		int = 0,
	@i_expired_count		int = 0,
	@i_expiring_count		int = 0, 
	@i_customer_id_list		varchar(max)	= isnull(@customer_id_list, ''),
	@i_generator_id_list	varchar(max)	= isnull(@generator_id_list, '')

select @i_period_int =
	case @i_period
		when 'WW' then datediff(dd, dateadd(ww, -1, getdate()) , getdate())
		when 'QQ' then datediff(dd, dateadd(qq, -1, getdate()) , getdate())
		when 'MM' then datediff(dd, dateadd(mm, -1, getdate()) , getdate())
		when 'YY' then datediff(dd, dateadd(yyyy, -1, getdate()) , getdate())
		when '30' then 30
		when '60' then 60
	end
	
if isnumeric(@i_period) = 1
	set @i_period_int = convert(int, @i_period)


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
    @status_list		= 'Approved, Expired, For Renewal',
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
	@period				= '',
	@tsdf_type			= 'ALL'


select 
	@i_approval_count = count(profile_id)
from @fooprofile b
where status = 'Approved'
and isnull(expired_date , getdate()+3) > getdate()

select 
	@i_expired_count = count(profile_id)
from @fooprofile b
where status = 'Expired'
and isnull(expired_date , getdate()+3) < getdate()
	and isnull(expired_date , getdate()+3) > dateadd(dd, (@i_period_int * -1), getdate())


select 
	@i_expiring_count = count(profile_id)
from @fooprofile b
where 1=1
-- and status = 'For Renewal'
and isnull(expired_date , getdate()+3) > getdate()
	and isnull(expired_date , getdate()+3) < dateadd(dd, @i_period_int, getdate())


select @i_approval_count approval_count, @i_expired_count expired_count, @i_expiring_count	expiring_count
 
RETURN 0


GO

GRANT EXECUTE ON [dbo].[sp_COR_Profile_Information] TO COR_USER;
GO

