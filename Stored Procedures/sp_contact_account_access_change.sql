-- 
drop proc sp_contact_account_access_change
go
CREATE proc [dbo].[sp_contact_account_access_change] (
	@user_code_or_id varchar(100)		/* administrator's user_code or web_userid */
	, @target_contact_id	int /* target user's contact_id */
	, @operation	varchar(20)		/* add/remove account on target user */
	, @account_type	char(1)			/* 'C'ustomer or 'G'enerator */
	, @account_id	bigint			/* Customer.customer_id or Generator.generator_id */  
)
as
/* *****************************************************************
sp_contact_account_access_change 

A call to the database to Add or Remove access to a customer or generator

SELECT  *  FROM    contact WHERE web_userid = 'maverick'
SELECT  *  FROM    contactxref WHERE contact_id = 11289

select * from cor_db..RolesRef where rolename = 'Administration'
SELECT  *  FROM    ContactXRole WHERE roleid = '2A57DB7C-E8A0-470C-8641-7469806A91D4'
	and contact_id = 213896

update ContactXRole set status = 'A' WHERE roleid = '2A57DB7C-E8A0-470C-8641-7469806A91D4'
	and contact_id = 213896
	
		select *
		from cor_db..RolesRef rr (nolock) 
		join ContactXRole cxr (nolock) on rr.roleid = cxr.RoleId
		WHERE cxr.contact_id = 185547
		and cxr.status = 'A'
		and rr.rolename = 'Administration'


SELECT  *  FROM    contact WHERE web_userid = 'zachery.wright'
SELECT  *  FROM    contactxref WHERE contact_id = 213896
SELECT  *  FROM    contactxrole WHERE contact_id = 213896
SELECT  *  FROM    contactaudit WHERE contact_id = 213896 order by date_modified desc

SELECT  *  FROM    note WHERE contact_id = 213896 ORDER BY note_date desc
delete contactxref WHERE contact_id = 213896 and customer_id = 15551

sp_contact_account_access_change 
	@user_code_or_id = 'nyswyn100'
	, @target_contact_id = '213896'
	, @operation = 'add'
	, @account_type = 'C'
	, @account_id = 15551

SELECT  TOP 100 *
FROM    contactaudit order by date_modified desc

sp_contact_account_access_change 
	@web_userid = 'nyswyn100'
	, @target_userid = 'zachery.wright'
	, @operation = 'add'
	, @account_type = 'G'
	, @account_id = 123456

	
***************************************************************** */

/* debug
	declare
	@web_userid varchar(100)		= 'nyswyn100'
	, @target_userid	varchar(100) = 'zachery.wright'
	, @operation	varchar(20)		= 'add'
	, @account_type	char(1)			= 'C'
	, @account_id	bigint			= 15551

	@user_code_or_id varchar(100)		/* administrator's user_code or web_userid */
	, @target_contact_id	int /* target user's contact_id */
	, @operation	varchar(20)		/* add/remove account on target user */
	, @account_type	char(1)			/* 'C'ustomer or 'G'enerator */
	, @account_id	bigint			/* Customer.customer_id or Generator.generator_id */  

 */
 
-- Avoid query plan caching and handle nulls
	declare 
	@i_user_code_or_id		varchar(100) = isnull(@user_code_or_id, '')
	, @i_target_contact_id	int = @target_contact_id
	, @i_operation		varchar(20) = isnull(@operation, '')
	, @i_account_type	char(1) = isnull(@account_type, '')
	, @i_account_id		bigint = isnull(@account_id, 1 )
	, @i_roleid			nvarchar(100)
	, @audit			varchar(max) = ''
	, @note_id			bigint
	, @debug			int = 0
	, @contactxref_count	int = 0
	, @i_contact_id		int
	, @i_contact_id_string		varchar(10) = ''


	select top 1 @i_contact_id = contact_id from contact where web_userid = @i_user_code_or_id
	if @i_contact_id is not null
		select @i_contact_id_string = convert(varchar(10), @i_contact_id)

if @debug > 0 select @i_target_contact_id i_target_contact_id, @i_operation operation

-- Abort if not found
 if @i_target_contact_id is null return 0

-- Abort if operation is unrecognized
 if @i_operation not in ('add', 'remove') return 0

/*
-- Don't need this in the EQAI version. The COR version should do this before calling it 
-- Verify the @web_userid making this request is authorized
if not exists (
	select 1 
	from contactxref c
	where 1=1
	and c.contact_id = @i_contact_id
	and c.type = @i_account_type
	and 1 = case @i_account_type
		when 'C' then case when c.customer_id = @i_account_id then 1 else 0 end
		when 'G' then case when c.generator_id = @i_account_id then 1 else 0 end
		else 0
		end
	and
	exists (
		select top 1 1
		from cor_db..RolesRef rr (nolock) 
		join ContactXRole cxr (nolock) on rr.roleid = cxr.RoleId
		WHERE cxr.contact_id = c.contact_id
		and cxr.status = 'A'
		and rr.rolename = 'Administration'
	)
)
	begin
		if @debug > 0 select 'returning 0: @web_userid making this request is not authorized'
		return 0
	end
*/

drop table if exists #contactaudit
create table #contactaudit (
	 contact_id			int
	,table_name			varchar(40)
	,column_name			varchar(40)
	,before_value		varchar(255)
	,after_value			varchar(255)
	,audit_reference		varchar(255)
	,modified_by			varchar(10)
	,modified_from		varchar(10)
	,date_modified		datetime
	,rowguid				uniqueidentifier
)

-- See if the ContactXref record already exists for this access combination
if exists (
	select 1 from contactxref c
	where 1=1
	and c.contact_id = @i_target_contact_id
	and c.type = @i_account_type
	and 1 = case @i_account_type
		when 'C' then case when c.customer_id = @i_account_id then 1 else 0 end
		when 'G' then case when c.generator_id = @i_account_id then 1 else 0 end
		else 0
		end
) begin
	-- exists: do an update
	if @debug > 0 select 'target contactxref record exists: update'

	-- build the audit string (update version)	
	select @audit = @audit + 'UPDATE: (FIELD) web_access (FROM) ' + c.web_access + ' (TO) '
		+ case when @i_operation = 'add' then 'A' else 'I' end + ' (WHERE) '
		+ case when @i_account_type = 'C' then 'Customer_ID = ' else 'Generator_ID' end
		+ convert(varchar(20), @i_account_id)
		+ ' ( PERFORMED BY ' + @i_user_code_or_id + ' - contact_id: ' + isnull(@i_contact_id_string, '') + ')'
	from contactxref c
	where 1=1
	and c.contact_id = @i_target_contact_id
	and c.type = @i_account_type
	and 1 = case @i_account_type
		when 'C' then case when c.customer_id = @i_account_id then 1 else 0 end
		when 'G' then case when c.generator_id = @i_account_id then 1 else 0 end
		else 0
		end

	if @debug > 0 select @audit as audit
	
	insert #contactaudit (
		contact_id,
		table_name,
		column_name,
		before_value,
		after_value,
		audit_reference,
		modified_by,
		modified_from,
		date_modified,
		rowguid
		)
	select 
		@i_target_contact_id contact_id,
		'ContactXref' table_name,
		'web_access' column_name,
		c.web_access before_value,
		case when @i_operation = 'add' then 'A' else 'I' end after_value,
		case when @i_account_type = 'C' then 'Customer_ID: ' else 'Generator_ID: ' end + convert(varchar(20), @i_account_id) audit_reference,
		@i_user_code_or_id modified_by,
		null as modified_from,
		getdate() date_modified,
		newid() rowguid
	from contactxref c
	where 1=1
	and c.contact_id = @i_target_contact_id
	and c.type = @i_account_type
	and 1 = case @i_account_type
		when 'C' then case when c.customer_id = @i_account_id then 1 else 0 end
		when 'G' then case when c.generator_id = @i_account_id then 1 else 0 end
		else 0
		end
	
	update contactxref set web_access = case when @i_operation = 'add' then 'A' else 'I' end,
	modified_by = @i_contact_id_string, date_modified = getdate()
	where 1=1
	and contact_id = @i_target_contact_id
	and type = @i_account_type
	and 1 = case @i_account_type
		when 'C' then case when customer_id = @i_account_id then 1 else 0 end
		when 'G' then case when generator_id = @i_account_id then 1 else 0 end
		else 0
		end
	
	if @@rowcount = 0 return 0
	
end
else
begin

	if @i_operation = 'add' begin -- we don't insert a row for a removal

		if @debug > 0 select 'target contactxref record does not exist: insert'
	
		-- build the audit string (insert version)	
		select @audit = @audit + 'INSERT: (FIELD) contact_id = ' + convert(varchar(20), @i_target_contact_id)
			+ ' (FIELD) type = ' + @i_account_type
			+ ' (FIELD) customer_id = ' + case when @i_account_type = 'C' then convert(varchar(20), @i_account_id) else 'null' end
			+ ' (FIELD) generator_id = ' + case when @i_account_type = 'G' then convert(varchar(20), @i_account_id) else 'null' end
			+ ' (FIELD) web_access = A'
			+ ' (FIELD) status = A'
			+ ' (FIELD) primary_contact = F'
			+ ' ( PERFORMED BY ' + @i_user_code_or_id + ' - contact_id: ' + isnull(@i_contact_id_string, '') + ')'
		from contactxref c
		where 1=1
		and c.contact_id = @i_target_contact_id
		and c.type = @i_account_type
		and 1 = case @i_account_type
			when 'C' then case when c.customer_id = @i_account_id then 1 else 0 end
			when 'G' then case when c.generator_id = @i_account_id then 1 else 0 end
			else 0
			end

		if @debug > 0 select @audit as audit

	insert #contactaudit (
		contact_id,
		table_name,
		column_name,
		before_value,
		after_value,
		audit_reference,
		modified_by,
		modified_from,
		date_modified,
		rowguid
		)
	select 
		@i_target_contact_id contact_id,
		'ContactXref' table_name,
		'type' field_name,
		null before_value,
		@i_account_type after_value,
		null audit_reference, @i_user_code_or_id modified_by, null as modified_from, getdate() date_modified, newid() rowguid 
	union
	select 
		@i_target_contact_id contact_id,
		'ContactXref' table_name,
		'customer_id' field_name,
		null before_value,
		case when @i_account_type = 'C' then convert(varchar(20), @i_account_id) else 'null' end after_value,
		null audit_reference, @i_user_code_or_id modified_by, null as modified_from, getdate() date_modified, newid() rowguid
	union
	select 
		@i_target_contact_id contact_id,
		'ContactXref' table_name,
		'generator_id' field_name,
		null before_value,
		case when @i_account_type = 'G' then convert(varchar(20), @i_account_id) else 'null' end after_value,
		null audit_reference, @i_user_code_or_id modified_by, null as modified_from, getdate() date_modified, newid() rowguid
	union
	select 
		@i_target_contact_id contact_id,
		'ContactXref' table_name,
		'web_access' field_name,
		null before_value,
		'A' after_value,
		null audit_reference, @i_user_code_or_id modified_by, null as modified_from, getdate() date_modified, newid() rowguid
	union
	select 
		@i_target_contact_id contact_id,
		'ContactXref' table_name,
		'status' field_name,
		null before_value,
		'A' after_value,
		null audit_reference, @i_user_code_or_id modified_by, null as modified_from, getdate() date_modified, newid() rowguid
	union
	select 
		@i_target_contact_id contact_id,
		'ContactXref' table_name,
		'primary_contact' field_name,
		null before_value,
		'F' after_value,
		null audit_reference, @i_user_code_or_id modified_by, null as modified_from, getdate() date_modified, newid() rowguid

		-- does not exist: insert
		insert contactxref (
			contact_id
			, type
			, customer_id
			, generator_id
			, web_access
			, status
			, added_by
			, date_added
			, modified_by
			, date_modified
			, primary_contact
			, rowguid
		)
		select 
			@i_target_contact_id as contact_id
			, @i_account_type	as type
			, case when @i_account_type = 'C' then @i_account_id else null end as customer_id
			, case when @i_account_type = 'G' then @i_account_id else null end as generator_id
			, 'A' as web_access
			, 'A' as status
			, @i_contact_id_string as added_by
			, getdate() as date_added
			, @i_contact_id_string as modified_by
			, getdate() as date_modified
			, 'F' as primary_contact
			, newid() as rowguid

		if @@rowcount = 0 return 0
	end
end

select @contactxref_count = count(*)
	from contactxref c
	where 1=1
	and c.contact_id = @i_target_contact_id
	and status = 'A'
	and web_access = 'A'

-- See if the ContactXRole record already exists for this access combination
-- We only want to add/remove role info if they don't already exist
-- OR if we just removed the last contactxref record for this contact.
if (
	(@contactxref_count = 1 and @i_operation = 'add')
	or
	(@contactxref_count = 0 and @i_operation = 'remove')
	)
begin
	if exists (
		select 1 from ContactXRole c
		left join cor_db..RolesRef rc on rc.rolename = 'Customer Access Read only'
		left join cor_db..RolesRef rg on rg.rolename = 'Generator Access Read only'
		where 1=1
		and c.contact_id = @i_target_contact_id
		and c.roleid = case @i_account_type
			when 'C' then rc.roleid
			when 'G' then rg.roleid
			else 'none'
			end
	) begin
		-- exists: do an update
		if @debug > 0 select 'target contactxrole record exists: update'

		-- build the audit string (update version)	
		select @audit = @audit + 'UPDATE: (FIELD) status (FROM) ' + cx.status + ' (TO) '
			+ case when @i_operation = 'add' then 'A' else 'I' end + ' (WHERE) RoleId = '
			+ case when @i_account_type = 'C' then isnull(convert(varchar(100), rc.roleid), 'MISSING Customer role') else isnull(convert(varchar(100), rg.RoleId), 'MISSING Generator role') end
			+ convert(varchar(20), @i_account_id)
			+ ' ( PERFORMED BY ' + @i_user_code_or_id + ' - contact_id: ' + isnull(@i_contact_id_string, '') + ')'
		from Contact c
			left join ContactXRole cx on c.contact_id = cx.contact_id
			left join cor_db..RolesRef rc on rc.rolename = 'Customer Access Read Only' and @i_account_type = 'C'
			left join cor_db..RolesRef rg on rg.rolename = 'Generator Access Read Only' and @i_account_type = 'G'
			where 1=1
			and c.contact_id = @i_target_contact_id

		if @debug > 0 select @audit as audit

		insert #contactaudit (
			contact_id,
			table_name,
			column_name,
			before_value,
			after_value,
			audit_reference,
			modified_by,
			modified_from,
			date_modified,
			rowguid
			)
		select 
			@i_target_contact_id contact_id,
			'ContactXrole' table_name,
			'status' field_name,
			cx.status before_value,
			case when @i_operation = 'add' then 'A' else 'I' end after_value,
			'RoleId = '
				+ case when @i_account_type = 'C' then isnull(convert(varchar(100), rc.roleid), 'MISSING Customer role') else isnull(convert(varchar(100), rg.RoleId), 'MISSING Generator role') end audit_reference
			, @i_user_code_or_id modified_by, null as modified_from, getdate() date_modified, newid() rowguid 
		from Contact c
			left join ContactXRole cx on c.contact_id = cx.contact_id
			left join cor_db..RolesRef rc on rc.rolename = 'Customer Access Read Only' and @i_account_type = 'C'
			left join cor_db..RolesRef rg on rg.rolename = 'Generator Access Read Only' and @i_account_type = 'G'
			where 1=1
			and c.contact_id = @i_target_contact_id

		
		update ContactXRole set status = case when @i_operation = 'add' then 'A' else 'I' end,
		modified_by = @i_user_code_or_id, date_modified = getdate()
		from ContactXRole c
		left join cor_db..RolesRef rc on rc.rolename = 'Customer Access Read Only'
		left join cor_db..RolesRef rg on rg.rolename = 'Generator Access Read Only'
		where 1=1
		and c.contact_id = @i_target_contact_id
		and c.roleid = case @i_account_type
			when 'C' then rc.roleid
			when 'G' then rg.roleid
			else 'none'
			end
		
		if @@rowcount = 0 return 0
		
	end
	else
	begin
	
		if @i_operation = 'add' begin -- we don't insert a row for a removal

			if @debug > 0 select 'target contactxrole record does not exist: insert'
		
			-- build the audit string (insert version)	
			select top 1 @audit = @audit + 'INSERT: (FIELD) contact_id = ' + convert(varchar(20), @i_target_contact_id)
				+ ' (FIELD) Roleid = ' + case when @i_account_type = 'C' then isnull(convert(varchar(100), rc.roleid), 'MISSING Customer Role') else isnull(convert(varchar(100), rg.RoleId), 'MISSING Generator Role') end
				+ ' (FIELD) status = A'
				+ ' (FIELD) added_by = ' + @i_user_code_or_id
				+ ' (FIELD) date_added = ' + convert(varchar(20), getdate())
				+ ' (FIELD) modified_by = ' + @i_user_code_or_id
				+ ' (FIELD) date_modified = ' + convert(varchar(20), getdate())
			, @i_roleid = case when @i_account_type = 'C' then rc.roleid else rg.roleid end
			-- declare @i_target_contact_id int = 257568, @i_account_type char(1) = 'C'; select c.*
			from Contact c
			left join ContactXRole cx on c.contact_id = cx.contact_id
			left join cor_db..RolesRef rc on rc.rolename = 'Customer Access Read only' and @i_account_type = 'C'
			left join cor_db..RolesRef rg on rg.rolename = 'Generator Access Read only' and @i_account_type = 'G'
			where 1=1
			and c.contact_id = @i_target_contact_id

			if @debug > 0 select @i_account_type i_account_type, @i_target_contact_id i_target_contact_id, @i_roleid i_roleid, @i_user_code_or_id i_user_code_or_id, @audit audit

		insert #contactaudit (
			contact_id,
			table_name,
			column_name,
			before_value,
			after_value,
			audit_reference,
			modified_by,
			modified_from,
			date_modified,
			rowguid
			)
		select 
			@i_target_contact_id contact_id,
			'ContactXrole' table_name,
			'Roleid' field_name,
			null before_value,
			case when @i_account_type = 'C' then isnull(convert(varchar(100), rc.roleid), 'MISSING Customer Role') else isnull(convert(varchar(100), rg.RoleId), 'MISSING Generator Role') end after_value,
			null audit_reference
			, @i_user_code_or_id modified_by, null as modified_from, getdate() date_modified, newid() rowguid 
			from Contact c left join ContactXRole cx on c.contact_id = cx.contact_id left join cor_db..RolesRef rc on rc.rolename = 'Customer Access Read only' and @i_account_type = 'C' left join cor_db..RolesRef rg on rg.rolename = 'Generator Access Read only' and @i_account_type = 'G' where 1=1 and c.contact_id = @i_target_contact_id
		union
		select 
			@i_target_contact_id contact_id,
			'ContactXrole' table_name,
			'Status' field_name,
			null before_value,
			'A' after_value,
			null audit_reference
			, @i_user_code_or_id modified_by, null as modified_from, getdate() date_modified, newid() rowguid 
			from Contact c left join ContactXRole cx on c.contact_id = cx.contact_id left join cor_db..RolesRef rc on rc.rolename = 'Customer Access Read only' and @i_account_type = 'C' left join cor_db..RolesRef rg on rg.rolename = 'Generator Access Read only' and @i_account_type = 'G' where 1=1 and c.contact_id = @i_target_contact_id
		
			-- does not exist: insert
			insert contactxrole (
				contact_id
				, RoleId
				, status
				, added_by
				, date_added
				, modified_by
				, date_modified
			)
			select 
				@i_target_contact_id as contact_id
				, @i_roleid as roleid
				, 'A' as status
				, @i_user_code_or_id as added_by
				, getdate() as date_added
				, @i_user_code_or_id as modified_by
				, getdate() as date_modified

			if @@rowcount = 0 return 0
		end -- operation = 'add'
	end -- contacxrole row did not already exist
end -- adding first or removing last association



-- insert audit

if @audit <> '' begin
	exec @note_id = sp_sequence_next 'Note.Note_ID'

	insert Note (
		note_id
		, note_source
		, note_date
		, subject
		, status
		, note_type
		, note
		, contact_id
		, contact_type
		, added_by
		, date_added
		, modified_by
		, date_modified
		, app_source
		, rowguid
	)
	select
		@note_id
		, 'ContactXref via COR'
		, getdate()
		, 'AUDIT'
		, 'C'
		, 'AUDIT'
		, @audit
		, @i_target_contact_id
		, 'Note'
		, 'COR' as added_by
		, getdate() as date_added
		, @i_contact_id_string as modified_by
		, getdate() as date_modified
		, @i_contact_id_string as app_source
		, newid() as rowguid
end



insert contactaudit
select * from #contactaudit

return 0

go


grant execute on sp_contact_account_access_change to cor_user, eqweb
go

