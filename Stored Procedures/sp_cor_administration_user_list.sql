USE [PLT_AI]
GO
DROP PROCEDURE IF EXISTS [sp_cor_administration_user_list]
GO

CREATE proc [dbo].[sp_cor_administration_user_list] (
	@web_userid varchar(100)
	, @role		varchar(max) = null
	, @search	varchar(100) = null
	, @sort				varchar(20) = '' -- 'Workorder Number','Store Number','Schedule Type','Service Type','Requested Date','Scheduled Date','Service Date','Manifest Number','Status', 'Contact Company'
	, @page				bigint = 1
	, @perpage			bigint = 20 
	, @customer_id_list varchar(max)=''  /* Added 2019-07-11 by AA */
	, @generator_id_list varchar(max)=''  /* Added 2019-07-11 by AA */
    , @active_flag	char(1) = 'A'	/* 'A'ctive users, 'I'nactive users, 'X' all users.   */
	, @search_type nvarchar(100) = ''
	, @search_contact_id int = 0
	, @search_name nvarchar(200) = ''
	, @search_email nvarchar(150) = ''
	, @search_first_name nvarchar(100) = ''
	, @search_last_name nvarchar(100) = ''
	, @search_title nvarchar(150) = ''
	, @search_phone nvarchar(20) = ''
	, @search_fax nvarchar(20) = ''
	, @search_contact_country nvarchar(100) = ''
	, @search_contact_zip_code nvarchar(100) = ''
	, @search_contact_state nvarchar(100) = ''
	, @search_contact_addr1 nvarchar(100) = ''
	, @search_contact_city nvarchar(100) = ''
	, @search_contact_company nvarchar(150) = ''
	, @search_contact_addr2 nvarchar(100) = ''
	, @search_contact_addr3 nvarchar(100) = ''
	, @search_contact_addr4 nvarchar(100) = ''
	, @search_mobile nvarchar(100) = ''
	, @search_web_userid nvarchar(150) = ''
)
as
/* *****************************************************************
sp_cor_administration_user_list 

List the users that the current @web_userid can admin.

sp_cor_administration_user_list 
	@web_userid = 'iceman'
	, @role = '' -- 'Administration'
	, @search = '' -- 'bram'
	, @sort = 'email'
	, @page = 1
	, @perpage = 99999
	, @active_flag = 'A'
	, @search_first_name = ''
	, @search_last_name = ''
	, @search_contact_zip_code = ''
	
SELECT  * FROM    contact WHERE contact_id in (219933, 219934)
SELECT  * FROM    contactxref WHERE contact_id in (219933, 219934)

SELECT  *  FROM    contact WHERE web_userid = 'jdirt'	
SELECT  *  FROM    contactxref where type = 'C' and contact_id in (211277)	
SELECT  *  FROM    contactxrole WHERE contact_id = 211277
SELECT  *  FROM    customer where customer_id in (6976, 15551, 15622, 18433, 18462, 602372)

select  CAST( RoleId AS nvarchar(1000)) RoleId ,RoleName,IsActive from cor_db.[dbo].[RolesRef]
WHERE roleid in ('177974A7-13D9-4123-8311-97A4C1FDC549', '2A57DB7C-E8A0-470C-8641-7469806A91D4', '42AD9B98-7A38-4607-B3B7-670DA552528E', '45892B8E-FAA5-451F-B2E6-B43DA7C14AEC', '6ED53B5D-5884-43E9-AC7F-A1F00EE6C2CA', '912B5F07-4553-488E-B9F3-C5F822A9DF6A', 'A3A7B60D-EF90-465A-8E10-8C954D003AA2', 'A8A04E15-5338-4B2C-BEDE-FB18EFF3F56E', 'AE18FA46-59AD-46CE-BFAD-420F1268315A', 'E525FE2D-F970-4E89-A5F4-68930C10B290')

delete FROM    contactxrole WHERE contact_id = 211277 and roleid = '6ED53B5D-5884-43E9-AC7F-A1F00EE6C2CA'
	
-- disable one: yhudspeth / 257568
select * from contact where web_userid = 'yhudspeth'
update contact set web_userid = isnull(web_userid, '') + '_' + convert(varchar(20), contact_id) where web_userid = 'yhudspeth' and contact_id <> 257568

sp_cor_administration_user_account_change 
	@web_userid = 'nyswyn100'
	, @target_userid = 'yhudspeth'
	, @operation = 'add'
	, @account_type = 'X'

select * from	contactxref where	 contact_id = 257568

exec [dbo].[sp_contact_account_access_change] @user_code_or_id = 'nyswyn100'	, @target_contact_id	= 257568, @operation	= 'add' , @account_type	= 'C', @account_id	= 6976

sp_cor_administration_user_account_change 
	@web_userid = 'nyswyn100'
	, @target_userid = 'yhudspeth'
	, @operation = 'add'
	, @account_type = 'C'
	, @account_id = 15551
	
	
***************************************************************** */

    
-- Avoid query plan caching and handle nulls
	declare 
	@i_web_userid	varchar(100) = isnull(@web_userid, '')
	, @i_role		varchar(max) = isnull(@role, '')
	, @i_search		varchar(100) = isnull(@search, '')
	, @i_sort		varchar(20) = isnull(@sort, '')
	, @i_page		bigint = isnull(@page, 1 )
	, @i_perpage	bigint = isnull(@perpage, 20)
	, @i_customer_id_list varchar(max) = isnull(@customer_id_list, '')
	, @i_generator_id_list varchar(max) = isnull(@generator_id_list, '')
	, @i_active_flag char(1) = isnull(@active_flag, 'A')
	, @i_am_I_internal int = 0
	, @i_contact_id int = 0

select top 1 @i_contact_id = contact_id from CORcontact WHERE web_userid = @i_web_userid

	
select @i_am_I_internal = 1
from ContactXRole x
join cor_db.[dbo].[RolesRef] r
	on x.RoleId = r.RoleID
join Contact c on x.contact_id = c.contact_id
	and c.web_userid = @i_web_userid
where r.RoleName like '%internal%'


declare @troles table (
	rolename	varchar(150)
)
if @i_role <> ''
insert @troles
select row from dbo.fn_SplitXsvText(',',1,@i_role)
where row is not null

declare @internal_domains table (
	domain		varchar(40)
)
insert @internal_domains (domain)
select '@usecology.com'
union
select '@stablex.com'
union
select '@eqonline.com'
union
select '@nrcc.com'
union
select '@optisolbusiness.com'

declare @contactxref table (
	contact_id		bigint
	, type			char(1)
	, web_access	char(1)
	, type_count	int
)

insert @contactxref
select x.contact_id, min(x.type) type, min(x.web_access) web_access, count(distinct x.type) as type_count
from contactxref x
join contact c on x.contact_id = c.contact_id
LEFT JOIN @internal_domains id 
	on c.email like '%' + id.domain
	and c.email <> 'itcommunications@usecology.com'
WHERE x.status = 'A'
and (	
	(
		isnull(x.customer_id, -999) in (
			select x1.customer_id
			from contactxref x1
			WHERE x1.contact_id = @i_contact_id
			and x1.status = 'A'
			and x1.web_access = 'A'
			-- and this user is in the admin role for this customer
		)
	)
	or
	(
		isnull(x.generator_id, -999) in (
			select x1.generator_id
			from contactxref x1
			WHERE x1.contact_id = @i_contact_id
			and x1.status = 'A'
			and x1.web_access = 'A'
			-- and this user is in the admin role for this customer
		)
	)
)
		and (
			@i_customer_id_list = ''
			or (
				@i_customer_id_list <> ''
				and x.type = 'C'
				and x.customer_id in (select convert(int, row) from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list) where row is not null and isnumeric(row) = 1)
			)
		)
		and (
			@i_generator_id_list = ''
			or (
				@i_generator_id_list <> ''
				and x.type = 'G'
				and x.generator_id in (select convert(int, row) from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list) where row is not null and isnumeric(row) = 1)
			)
		)
		and not exists (
			select top 1 1
			from cor_db..RolesRef rr (nolock) 
			join ContactXRole cxr (nolock) on rr.roleid = cxr.RoleId
			WHERE cxr.contact_id = x.contact_id
			and cxr.status = 'A'
			and rr.RoleName = 'Internal User'
			and @i_am_I_internal = 0
		)
		and id.domain is null
GROUP BY x.contact_id

select * from (
	select x.*
		,_row = row_number() over (order by 
			case when @i_sort in ('', 'name') then x.name end,
			case when @i_sort = 'email' then x.email end,
			case when @i_sort = 'first_name' then x.first_name end,
			case when @i_sort = 'last_name' then x.last_name end,
			case when @i_sort = 'title' then x.title end, 
			case when @i_sort = 'phone' then x.phone end,
			case when @i_sort = 'address' then x.contact_addr1 end, 
			case when @i_sort = 'city' then x.contact_city end, 
			case when @i_sort = 'state' then x.contact_state end,
			case when @i_sort = 'contact_company' then x.contact_company end
		) 
	from (
		select distinct
		case when x.type_count = 2 then 'Both' else case x.type when 'C' then 'Customer' else 'Generator' end end type
		,c.contact_id, c.name, c.email,c.first_name,c.last_name,c.title,c.phone,c.fax,c.contact_country,c.contact_zip_code,c.contact_state,c.contact_addr1,c.contact_city,c.contact_company,
		c.contact_addr2, c.contact_addr3, c.contact_addr4, c.mobile
		, c.web_userid
		, x.web_access as status
		,case when c.email like '%usecology.com%' or c.email like '%republicservices.com%' then 1 else 0 end as IsInternalUser
		from contact c
		join @contactxref x on c.contact_id = x.contact_id
		join contactxref xref on c.contact_id = xref.contact_id
		WHERE x.type = 'C'
		and x.web_access = case @i_active_flag when 'X' then x.web_access else @i_active_flag end 
		and c.contact_status = 'A'		
		and isnull(c.web_userid, '') <> ''
		and (
			@i_role = ''
			or (
				@i_role <> ''
				and
				exists (
					select top 1 1
					from cor_db..RolesRef rr (nolock) 
					join ContactXRole cxr (nolock) on rr.roleid = cxr.RoleId
					join @troles t on rr.rolename = t.rolename
					WHERE cxr.contact_id = c.contact_id
					and cxr.status = case @i_active_flag when 'A' then 'A' else cxr.status end 
				)
			)
		)
		and (
			@i_search = ''
			or (
				@i_search <> ''
				and 
					' ' + isnull(convert(varchar(20),c.contact_id), '') +
					' ' + isnull(c.name, '') +
					' ' + isnull(c.email, '') +
					' ' + isnull(c.first_name, '') +
					' ' + isnull(c.last_name, '') +
					' ' + isnull(c.title, '') +
					' ' + isnull(c.phone, '') +
					' ' + isnull(c.contact_city, '') +
					' ' + isnull(c.contact_company, '') +
					' ' + isnull(c.web_userid, '')
					+ ' '
					like '%' + @i_search + '%'
			)
		)
		and (@search_type = '' or case when x.type_count = 2 then 'Both' else case x.type when 'C' then 'Customer' else 'Generator' end end = @search_type) 
		and (@search_contact_id = 0 or c.contact_id = @search_contact_id)
		and (isnull(c.name, '') like '%' + @search_name + '%')
		and (isnull(c.email, '') like '%' + @search_email + '%')
		and (isnull(c.first_name, '') like '%' + @search_first_name + '%')
		and (isnull(c.last_name, '') like '%' + @search_last_name + '%')
		and (isnull(c.title, '') like '%' + @search_title + '%')
		and (isnull(c.phone, '') like '%' + @search_phone + '%')
		and (isnull(c.fax, '') like '%' + @search_fax + '%')
		and (isnull(c.contact_country, '') like '%' + @search_contact_country + '%')
		and (isnull(c.contact_zip_code, '') like '%' + @search_contact_zip_code + '%')
		and (isnull(c.contact_state, '') like '%' + @search_contact_state + '%')
		and (isnull(c.contact_addr1, '') like '%' + @search_contact_addr1 + '%')
		and (isnull(c.contact_city, '') like '%' + @search_contact_city + '%')
		and (isnull(c.contact_company, '') like '%' + @search_contact_company + '%')
		and (isnull(c.contact_addr2, '') like '%' + @search_contact_addr2 + '%')
		and (isnull(c.contact_addr3, '') like '%' + @search_contact_addr3 + '%')
		and (isnull(c.contact_addr4, '') like '%' + @search_contact_addr4 + '%')
		and (isnull(c.mobile, '') like '%' + @search_mobile + '%')
		and (isnull(c.web_userid, '') like '%' + @search_web_userid + '%')
	) x
) y
where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
order by _row


return 0

go

	grant execute on sp_cor_administration_user_list to eqweb, eqai, COR_USER

go
