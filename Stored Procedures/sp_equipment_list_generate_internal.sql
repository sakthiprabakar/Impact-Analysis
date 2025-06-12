/*

-- Commented 6/25/2019 - JPB - error deploying to misousqldev01, seems like deprecated code.

create proc sp_equipment_list_generate_internal (
	@user_id_list			varchar(max)	-- Only matching id's will get emailed. Null = all.  0 = IT.
	, @display_or_email		char(1) = 'D'	-- 'D'isplay fields only, or 'E'mail results?
)
as
/-* *********************************
sp_equipment_list_generate_internal

	Generates internal equipment list distribution report fields
	Can either return them (Display option) or Email them to the General Managers
	for the sites found in the results.

History:
10/17/2014	JPB	Created as copy of similar sp_phone_bill_generate_internal

Sample:
sp_equipment_list_generate_internal
	@user_id_list = '658'
	, @display_or_email = 'E'
	
********************************* *-/

SET NOCOUNT ON
SET ANSI_NULLS ON
SET ANSI_WARNINGS ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
-- 'jonathan.broome@eqonline.com' -- for testing.
declare @it_email varchar(100) = 'jonathan.broome@eqonline.com' -- for testing.
-- declare @it_email varchar(100) = 'itdept@eqonline.com' -- for reals.

declare @this_user varchar(10) = system_user

create table #users (
	user_id	int
)

create table #DisplayOutput (
	o_id						int not null identity(1,1)
	, record_set				int
	, bill_recipient_user_id	int
	, bill_recipient_name	varchar(40)
	, bill_recipient_email		varchar(80)
	, location_name				varchar(100)
	, device_name				varchar(100)
	, service_tag				varchar(100)
	, date_assigned				datetime
	, dummy_for_check_box		int
)

if isnull(@user_id_list, '') <> ''
	insert #users
	select convert(int, row)
	from dbo.fn_splitxsvtext(',', 1, @user_id_list)
	where row is not null


-- Gather device info
	select
		SDOrganization.name as location_name
		, CI.CIName
		, SystemInfo.ServiceTag
		, min(convert(date, DATEADD(second, convert(bigint, left(convert(varchar(50), starttime),10)),{d '1970-01-01'}))) as date_assigned
		, isnull(u.user_id, 0) as user_id
		, isnull(u.user_name, 'IT Dept (for ' + SDOrganization.name + ')') as user_name
		, isnull(u.email, 'itdept@eqonline.com') as email
	into #data
	from
		assetexplorer.assetexplorer.dbo.CI CI (nolock)
	LEFT JOIN assetexplorer.assetexplorer.dbo.CIRelationships CIRelationships  (nolock)
		on (CI.CIID = CIRelationships.CIID OR CI.CIID = CIRelationships.CIID2) 
	left outer join assetexplorer.assetexplorer.dbo.SDUser SDUser (nolock)
		on (CIRelationships.CIID = SDUser.CIID)
	left outer join assetexplorer.assetexplorer.dbo.AAALogin AAALogin  (nolock)
		on SDUser.USERID = AAALogin.USER_ID
	left outer join assetexplorer.assetexplorer.dbo.CIType CIType (nolock)
		on CI.CITYPEID = CIType.TYPEID
	left outer join assetexplorer.assetexplorer.dbo.Resources Resources (nolock)
		on (CIRelationships.CIID = Resources.CIID OR CIRelationships.CIID2 = Resources.CIID)
	left join assetexplorer.assetexplorer.dbo.SystemInfo SystemInfo (nolock)
		on Resources.RESOURCEID = SystemInfo.WORKSTATIONID
	left join assetexplorer.assetexplorer.dbo.ResourceOwner ResourceOwner (nolock)
		on Resources.RESOURCEID = ResourceOwner.RESOURCEID
	left join assetexplorer.assetexplorer.dbo.AaaUser AaaUser (nolock)
		on ResourceOwner.USERID = AaaUser.USER_ID
	left join assetexplorer.assetexplorer.dbo.DepartmentDefinition DepartmentDefinition (nolock)
		on ResourceOwner.DEPTID = DepartmentDefinition.DEPTID
	left join assetexplorer.assetexplorer.dbo.ResourceLocation ResourceLocation (nolock)
		on Resources.RESOURCEID = ResourceLocation.RESOURCEID
	left join assetexplorer.assetexplorer.dbo.SiteDefinition SiteDefinition (nolock)
		on ResourceLocation.SITEID = SiteDefinition.SITEID
	left join assetexplorer.assetexplorer.dbo.SDOrganization SDOrganization (nolock)
		on SiteDefinition.SITEID = SDOrganization.ORG_ID
	LEFT JOIN assetexplorer.assetexplorer.dbo.ComponentDefinition ComponentDefinition  (nolock)
		ON Resources.COMPONENTID=ComponentDefinition.COMPONENTID 
	LEFT JOIN assetexplorer.assetexplorer.dbo.ResourceStateHistory History (nolock)
		ON History.resourceid = Resources.ResourceID and History.resourcestateid = 2
	left join UsersData ud (nolock)
		on ud.record_purpose = 'Asset Assignment' and ud.match_value = SDOrganization.name
	left join Users u (nolock)
		on ud.user_id = u.user_id
	where 1=1
		and CI.CIName like 'MIM%'
	group by 
		SDOrganization.name
		, CI.CIName
		, SystemInfo.ServiceTag
		, u.user_id
		, u.user_name
		, u.email

update #data set ciname = upper(left(ciname, charindex('.', ciname)-1))
where ciname like '%.%'

-- Setup for display or email, filtering by user_id_list

select distinct 
	location_name
	, user_id
	, user_name
	, email
	, 0 as process_flag
into #recipient
from #data d

if isnull(@user_id_list, '') <> ''
	-- Only matching id's will get emailed. Null = all.  0 = IT.
	delete from #recipient where user_id not in (
		select user_id from #users
	)
	

declare 
	@report_header varchar(max) = '<div style="width:90%; margin:2px">'
	, @report_footer varchar(max) = '</div>'
	, @table_header varchar(max) = '<table cellspacing="0" cellpadding="4" width="100%" style="border:solid 1px #000; font-size:8pt; font-family:Arial, sans-serif">'
	, @table_title_header varchar(max) = '<tr><th colspan="4">'
	, @table_title_footer varchar(max) = '</th></tr>'
	, @table_spacer varchar(max) = '<tr><td colspan="4">&nbsp;</td></tr>'
	, @table_row_header varchar(max) = '<tr><th align=left width=40%>Location</th><th align=left width=15%>Device</th><th align=left width=15%>Service Tag</th><th align=left width=30%>Date Assigned</th></tr>'
	, @row_header varchar(max) = '<tr><td>'
	, @column_sep varchar(max) = '</td><td>'
	, @column_sep_right varchar(max) = '</td><td align="right">'
	, @row_footer varchar(max) = '</td></tr>'
	, @table_footer varchar(max) = '</table><br/></br>'

create table #EmailLines (
	overall_row	int
	, bill_recipient_name	varchar(100)
	, bill_recipient_email	varchar(100)
	, subject varchar(255)
	, email_body varchar(max)
)

create table #EmailQueue (
	email_id		int not null identity(1,1)
	, email_name		varchar(100)
	, email_address	varchar(100)
	, subject		varchar(255)
	, email_body	varchar(max)
)

declare @this_recipient_user_id int
	, @this_recipient_name varchar(100)
	, @this_recipient_email varchar(100)


while exists (select 1 from #recipient where process_flag = 0 and user_id is not null) begin

	select top 1 
		@this_recipient_user_id = user_id
		, @this_recipient_name = user_name
		, @this_recipient_email = email
	from #recipient
	where process_flag = 0
	and user_id is not null
	
	-- truncate table #DisplayOutput -- Don't do this.
	
	-- Used by Display OR Email:
		insert #DisplayOutput
		select * from (
			select 
				1 as record_set
				, r.user_id as bill_recipient_user_id
				, r.user_name as bill_recipient_name
				, r.email as bill_recipient_email
				, isnull(d.location_name, '(unassigned)') as location_name
				, d.ciname
				, d.servicetag
				, d.date_assigned
				, 0 as dummy_for_check_box
			from #data d
			inner join #recipient r 
				on (
					isnull(d.location_name, '(unassigned)') = isnull(r.location_name, '(unassigned)')
					and r.user_id = @this_recipient_user_id
				)

		) x
		order by 
			bill_recipient_name
			, bill_recipient_email
			, location_name
			, case when record_set = 1 then ciname else 'zzzzzzzz' end
			, case when record_set = 1 then servicetag else 'zzzzzzzz' end
			, date_assigned
			, record_set
	
	
	-- Send email
	if isnull(@display_or_email, 'D') = 'E' begin 
	
		if object_id('tempdb..#EmailBuild') is not null
			drop table #EmailBuild
	
			truncate table #EmailLines
	
	-- #EmailBuild = #DisplayOutput
		select distinct
			row_number() over (
				partition by 
					d.bill_recipient_user_id
					, d.bill_recipient_name
					, d.bill_recipient_email
				order by 
					d.o_id
			  ) record_set_row
			, d.*
		into #EmailBuild
		from #DisplayOutput d
		where bill_recipient_user_id = @this_recipient_user_id
		order by 
			d.o_id

		insert #EmailLines
		select
			o_id as overall_row
			, bill_recipient_name
			, bill_recipient_email
			, 'Assigned MIMs' as subject
			, case when record_set = 1 and record_set_row = 1 and row_number() over (
				order by 
					bill_recipient_name
					, bill_recipient_email
					, case when record_set = 3 then 'zzzzzz' else isnull(location_name, '(Unassigned)') end
					, record_set
			  ) > 1 then 
				@table_spacer 
					+ @table_footer
					+ @table_header 
					+ @table_title_header 
					+ isnull(bill_recipient_name, 'IT Dept')
					+ ': Assigned MIMs' 
					+ @table_title_footer 
					+ @table_spacer
					+ @table_row_header
				else '' end
			+ case when record_set = 1 and record_set_row = 1 and row_number() over (
				order by 
					bill_recipient_name
					, bill_recipient_email
					, case when record_set = 3 then 'zzzzzz' else isnull(location_name, '(Unassigned)') end
					, record_set
			  ) = 1 then 
				@report_header
					+ @table_header 
					+ @table_title_header 
					+ isnull(bill_recipient_name, 'IT Dept')
				+ ': Assigned MIMs' 
				+ @table_title_footer 
				+ @table_spacer
				+ @table_row_header
				else '' end
			+ case when record_set = 3 then @table_spacer else '' end
			+ @row_header
			+ isnull(location_name, '(Unassigned)')
			+ @column_sep
			+ isnull(device_name, '')
			+ @column_sep
			+ isnull(service_tag, '')
			+ @column_sep
			+ case when record_set = 3 then '' else isnull(convert(varchar(10), date_assigned, 121), 'n/a') end
			+ @row_footer
			+ case when record_set = 3 then @table_footer + @report_footer else '' end
			as email_body
			from #EmailBuild
			order by 
			o_id

			insert #EmailLines
			select top 1 
				(select max(o_id) + 1 from #EmailBuild) as overall_row
				, bill_recipient_name
				, bill_recipient_email
				, 'Assigned MIMs' as subject
				, @table_footer + @report_footer
			from #EmailBuild


		declare @email_body varchar(max) = '', @email_subject varchar(255)
		
		select top 1 @email_subject = 'Equipment Assignments for ' + isnull(bill_recipient_name, '(Unassigned)')
		from #EmailBuild

		set @email_body = ''
		
		select @email_body = coalesce(@email_body, '') + email_body
		FROM #EmailLines
		order by 
		overall_row
 
		insert #EmailQueue
		select
			@this_recipient_name
			, @this_recipient_email
			, @email_subject
			, @email_body

		declare @out_message_id int
		
		exec @out_message_id = sp_message_insert
			 @subject			= @email_subject
			,@message			= @email_body
			,@html				= @email_body
			,@created_by		= @this_user
			,@message_source	= 'Equipment Assignment SP'
			,@date_to_send		= NULL
			,@message_type_id	= NULL
			
		exec sp_messageAddress_insert
			 @message_id	= @out_message_id
			,@address_type	= 'TO'
			,@email			= @it_email -- @this_recipient_email
			,@name			= @this_recipient_name
			,@company		= 'EQ'
			,@department	= NULL
			,@fax			= NULL
			,@phone			= NULL

		exec sp_messageAddress_insert
			 @message_id	= @out_message_id
			,@address_type	= 'FROM'
			,@email			= 'itdept@eqonline.com'
			,@name			= 'IT Department'
			,@company		= 'EQ'
			,@department	= NULL
			,@fax			= NULL
			,@phone			= NULL

		set @email_body = ''
		
	end

	update #recipient set process_flag = 1 where user_id = @this_recipient_user_id

end

-- select datalength(email_body), * from #EmailQueue order by email_id

-- Display mode: Return records
if isnull(@display_or_email, 'D') = 'D'
	SELECT 
		bill_recipient_user_id, 
		isnull(bill_recipient_name, '(IT Dept)') as bill_recipient_name, 
		location_name, 
		device_name,
		service_tag, 
		date_assigned 
	FROM #DisplayOutput 
	order by 
		o_id


-- If we sent emails, recap- send the whole body of all, combined, to IT.
if isnull(@display_or_email, 'D') = 'E' begin 

	declare @allemail varchar(max)
		, @createdby varchar(10) = system_user

	select @allemail = coalesce(@allemail, '') + email_body
	FROM #EmailQueue
	order by email_id
		
	exec @out_message_id = sp_message_insert
		 @subject			= 'Equipment Assignment Report'
		,@message			= ''
		,@html				= @allemail
		,@created_by		= @createdby
		,@message_source	= 'Equipment Assignment SP'
		,@date_to_send		= NULL
		,@message_type_id	= NULL
		
	exec sp_messageAddress_insert
		 @message_id	= @out_message_id
		,@address_type	= 'TO'
		,@email			= @it_email
		,@name			= 'IT Dept'
		,@company		= 'EQ'
		,@department	= NULL
		,@fax			= NULL
		,@phone			= NULL

	exec sp_messageAddress_insert
		 @message_id	= @out_message_id
		,@address_type	= 'FROM'
		,@email			= 'itdept@eqonline.com'
		,@name			= 'IT Department'
		,@company		= 'EQ'
		,@department	= NULL
		,@fax			= NULL
		,@phone			= NULL

end



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_equipment_list_generate_internal] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_equipment_list_generate_internal] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_equipment_list_generate_internal] TO [EQAI]
    AS [dbo];

*/
