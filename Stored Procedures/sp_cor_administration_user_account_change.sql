-- drop proc sp_cor_administration_user_account_change 
go

CREATE proc [dbo].[sp_cor_administration_user_account_change] (
	@web_userid varchar(100)		/* administrator's web_userid */
	, @target_userid	varchar(100) /* target user's web_userid */
	, @operation	varchar(20) = null		/* add/remove account on target user */
	, @account_type	char(1) = 'X'		/* 'C'ustomer or 'G'enerator or 'X' = ALL */
	, @account_id	bigint = null		/* Customer.customer_id or Generator.generator_id.  Null if using 'X' above. */  
	, @change_list	varchar(max) = ''   /* Operation|AccountType|AccountID CSV List */
	, @debug int = 0
)
as
/* *****************************************************************
sp_cor_administration_user_account_change 

A call to the database to Add or Remove access to a customer or generator

to-do: add claims to COR_DB records when creating access

SELECT  *  FROM    contact WHERE web_userid = 'nyswyn100'
SELECT  *  FROM    contact WHERE web_userid = 'nyswyn102'
update contact set web_userid = 'nyswyn102' where contact_id = 308697
SELECT  *  FROM    contactxref WHERE contact_id = 185547

select * from cor_db..RolesRef where rolename = 'Administration'
SELECT  *  FROM    ContactXRole WHERE roleid = '2A57DB7C-E8A0-470C-8641-7469806A91D4'
	and contact_id = 185547

insert contactxrole (contact_id, roleid, status, added_by, date_added, modified_by, date_modified)
values (185547, '2A57DB7C-E8A0-470C-8641-7469806A91D4', 'A', 'SA', getdate(), 'SA', getdate())



update ContactXRole set status = 'A' WHERE roleid = '2A57DB7C-E8A0-470C-8641-7469806A91D4'
	and contact_id = 185547
	
		select *
		from cor_db..RolesRef rr (nolock) 
		join ContactXRole cxr (nolock) on rr.roleid = cxr.RoleId
		WHERE cxr.contact_id = 185547
		and cxr.status = 'A'
		and rr.rolename = 'Administration'


SELECT  *  FROM    contact WHERE web_userid = 'nyswyn100'
SELECT  *  FROM    contactxref WHERE contact_id = 11289
SELECT  *  FROM    cor_db..RolesRef WHERE isactive =1
SELECT  *  FROM    ContactXRole WHERE contact_id = 11289
SELECT  *  FROM    note WHERE contact_id = 11289 ORDER BY note_date desc


SELECT  *  FROM    contact WHERE web_userid = 'zachery.wright'
SELECT  *  FROM    contactxref WHERE contact_id = 11290

sp_cor_administration_user_account_change 
	@web_userid = 'nyswyn100'
	, @target_userid = 'zachery.wright'
	, @operation = 'remove'
	, @account_type = 'C'
	, @account_id = 15551


exec sp_cor_administration_user_account_change 
	@web_userid = 'nyswyn100'
	, @target_userid = 'zachery.wright'
	, @operation = null
	, @account_type = null
	, @account_id = null
	, @change_list = 'remove|C|13022,remove|c|15622,add|C|15940'
	, @debug = 1

SELECT  *  FROM    contactxref where contact_id= 11290
SELECT  *  FROM    contactcorcustomerbucket where contact_id= 11290

sp_ContactCORallBucket_Maintain 11290


exec [dbo].[sp_contact_account_access_change] 
	@user_code_or_id = 'nyswyn100'
	, @target_contact_id	= @i_target_userid
	, @operation	= @i_operation
	, @account_type	= @i_account_type
	, @account_id	= @i_account_id
	
***************************************************************** */

/* debug
	declare
	@web_userid varchar(100)		= 'nyswyn100'
	, @target_userid	varchar(100) = 'zachary.woods@ge.com'
	, @operation	varchar(20)		= 'add'
	, @account_type	char(1)			= 'g'
	, @account_id	bigint			= 123967
	, @debug int = 1
 */

 
-- Avoid query plan caching and handle nulls
	declare 
	@i_web_userid		varchar(100) = isnull(@web_userid, '')
	, @i_contact_id		int
	, @i_target_userid	varchar(100) = isnull(@target_userid, '')
	, @i_target_contact_id int
	, @i_operation		varchar(20) = isnull(@operation, '')
	, @i_account_type	char(1) = isnull(@account_type, 'X')
	, @i_account_id		bigint = isnull(@account_id, 0 )
	, @i_change_list	varchar(max) = isnull(@change_list, '')
	, @i_roleid			nvarchar(100)
	, @audit			varchar(max) = ''
	, @note_id			bigint
	, @i_debug			int = isnull(@debug, 0)
	, @i_customer_id bigint
	, @i_generator_id bigint
	, @i_id	int
	
-- Find the contact id's.
select @i_contact_id = contact_id from CORContact (nolock) where web_userid = @i_web_userid
select @i_target_contact_id = contact_id from CORContact (nolock) where web_userid = @i_target_userid

if @i_debug > 0 select @i_contact_id i_contact_id, @i_target_contact_id i_target_contact_id, @i_operation operation

-- Abort if not found
if (@i_contact_id is null or @i_target_contact_id is null ) and @i_debug > 0 select 'Aborting because contact or target not found'
if (@i_contact_id is null or @i_target_contact_id is null ) and @i_debug = 0 return 0

-- set up todo table...
declare @todo table (
	_id	int not null identity(1,1),
	operation varchar(20),
	type	char(1),
	customer_id	bigint,
	generator_id bigint,
	done_flag bit
)


-- set up to loop, handle change_list
declare @cycles table (
	operation	varchar(20)
	, account_type	char(1)
	, account_id	bigint
	, complete_flag	bit
)	

if @i_change_list = ''
begin
	if @i_operation is not null 
		and @i_account_type is not null 
		and @i_account_id is not null
		insert @cycles (operation, account_type, account_id, complete_flag)
			values (@i_operation, @i_account_type, @i_account_id, 0)
end
else
begin
	-- insert @i_change_list to @cycles

	declare @handler table (
		content varchar(max)
		,complete_flag bit
	)
	declare @this varchar(max)

	insert @handler (content, complete_flag) select value, 0 from string_split(@i_change_list, ',')

	while exists (select 1 from @handler where complete_flag = 0) begin

	select top 1 @this = content from @handler where complete_flag = 0

	begin try
		select @i_operation = null, @i_account_type = null, @i_account_id = null
		select 
			@i_operation = case when idx = 1 then row else isnull(@i_operation, null) end
			, @i_account_type = case when idx = 2 then row else isnull(@i_account_type, null) end
			, @i_account_id = case when idx = 3 then row else isnull(@i_account_id, null) end
		from dbo.fn_splitxsvtext('|', 1, @this)

		insert @cycles (operation, account_type, account_id, complete_flag)
			values (@i_operation, @i_account_type, @i_account_id, 0)
	end try
	begin catch
		if @i_debug > 0 select 'Aborting because split of @change_list failed'
		if @i_debug = 0 return 0
	end catch

	update @handler set complete_flag = 1 where content = @this

	end

end

-- Abort if operation is unrecognized
if exists (select 1 from @cycles where operation not in ('add', 'remove')) 
	and @i_debug > 0 select 'Aborting because operation not add/remove'

if exists (select 1 from @cycles where operation not in ('add', 'remove'))
	return 0

while exists (select 1 from @cycles where complete_flag = 0)
begin

	select top 1
		@i_operation = operation
		, @i_account_type = account_type
		, @i_account_id = account_id
	from @cycles
	where complete_flag = 0


	if @i_debug > 0 select @i_contact_id i_contact_id
		, @i_account_id i_account_id
		, @i_account_type i_account_type
 
	-- Verify the @web_userid making this request is authorized
	if not exists (
		select 1 
		from contactxref c
		where 1=1
		and c.contact_id = @i_contact_id
		--and c.type = @i_account_type
		and 1 = case @i_account_type
			when 'C' then case when c.customer_id = @i_account_id then 1 else 0 end
			when 'G' then case when (
					c.generator_id = @i_account_id
					OR 
					exists (
						select cb.contact_id, cb.customer_id, cg.generator_id
						from ContactCORCustomerBucket cb
						join CustomerGenerator cg 
							on cb.customer_id = cg.customer_id   and 1=0 -- disable customergenerator access, but don't screw up existing code too much.
						WHERE cb.contact_id = @i_contact_id
						and cg.generator_id = @i_account_id
					)
				) then 1 else 0 end
			when 'X' then 1
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
			if @i_debug > 0 select 'returning 0: @web_userid making this request is not authorized'
			if @i_debug = 0 return 0
		end

	-- If everything is ok to here, add to the TODO table of changes to execute

	insert @todo (type, operation, customer_id, generator_id, done_flag)
	select type, @i_operation, customer_id, generator_id, 0
	from contactxref cxr (nolock)
	WHERE contact_id = @i_contact_id
	and status = 'A' 
	and @i_account_type = 'X'
	union
	select @i_account_type, @i_operation, @i_account_id, null, 0
	from contactxref cxr (nolock)
	WHERE contact_id = @i_contact_id
	and status = 'A' 
	and @i_account_type = 'C'
	and customer_id = @i_account_id 
	union
	select @i_account_type, @i_operation, null, @i_account_id, 0
	from contactxref cxr (nolock)
	WHERE contact_id = @i_contact_id
	and status = 'A' 
	and @i_account_type = 'G'
	and generator_id = @i_account_id 
	union
	select @i_account_type, @i_operation, null, @i_account_id, 0
	WHERE 
	@i_account_type = 'G'
	and exists (
		select cb.contact_id, cb.customer_id, cg.generator_id
		from ContactCORCustomerBucket cb
		join CustomerGenerator cg 
			on cb.customer_id = cg.customer_id   and 1=0 -- disable customergenerator access, but don't screw up existing code too much.
		WHERE cb.contact_id = @i_contact_id
		and cg.generator_id = @i_account_id
	)

	update @cycles set complete_flag = 1 where 
		operation = @i_operation
		and account_type = @i_account_type
		and account_id = @i_account_id

end -- while @cycles has incomplete rows

if @i_debug > 0
select '@todo' as tablename, * from @todo

while exists (select 1 from @todo where done_flag=0) begin

	select top 1 
		@i_id = _id
		, @i_account_type	= type
		, @i_operation	= operation
		, @i_customer_id		= customer_id
		, @i_generator_id = generator_id
		from @todo where done_flag = 0
	
	if @i_account_type = 'C' set @i_account_id = @i_customer_id
	if @i_account_type = 'G' set @i_account_id = @i_generator_id

	select @i_web_userid, @i_target_contact_id, @i_operation, @i_account_type, @i_account_id

	print '	exec [dbo].[sp_contact_account_access_change] @user_code_or_id = ' + @i_web_userid + '	, @target_contact_id	= ' + convert(varchar(20), @i_target_contact_id) + ', @operation	= ' + @i_operation + ' , @account_type	= ' + @i_account_type + ', @account_id	= ' + convert(varchar(20), @i_account_id)

	exec [dbo].[sp_contact_account_access_change] 
		@user_code_or_id = @i_web_userid
		, @target_contact_id	= @i_target_contact_id
		, @operation	= @i_operation
		, @account_type	= @i_account_type
		, @account_id	= @i_account_id

		update @todo set done_flag = 1
		where _id = @i_id

	if @i_debug > 0
	select '@todo' as tablename, * from @todo


end

-- refresh bucket tables

if @i_debug > 0 select 'exec sp_ContactCORAllBucket_Maintain ' + convert(varchar(20), @i_target_contact_id)

-- exec sp_ContactCORAllBucket_Maintain @i_target_contact_id 


return 0

go


grant execute on sp_cor_administration_user_account_change to cor_user, eqweb
go

