
/************************************************************
Procedure    : sp_contact_update
Database     : PLT_AI*
Created      : Tue May 16 14:31:39 EDT 2006 - Jonathan Broome
Description  : Inserts or Updates a Contact Record,
	including ContactXref and Note as needed.

6/8/2010 - JPB - Modified the audit section to use the #ColumnList temp table instead of sp_columns
		on a temp table. It was freezing prod.
	
select * from contact where contact_id = 10399
select * from note where contact_id = 10399
sp_contact_update 10399, 'Mr', 'John', 'R', 'Doe', 'Jr', 'Test Subject', 'john@doe.com', '', '1234567890', '123456', '123456', '123456', '', 'EQ - TRAINING ACCOUNT', '36255 MICHIGAN AVENUE', '', '', 'WAYNE', 'MI', '48184', '', 'This is a test contact', 'This is a test contact', 'This is a test contact', '', 'A', 'jonathan', 1;
sp_contact_update 10399, 'Mr', 'John', 'P', 'Doe', 'Jr', 'Test Subject', 'john@doe.com', 'Y', '1234567890', '1234567890', '1234567890', '1234567899', '', 'EQ - TRAINING ACCOUNT', '36255 MICHIGAN AVENUE', '', '', 'WAYNE', 'MI', '48184', '', 'This is a test contact', 'This is a test contact', 'This is a test contact', '', 'A', 'jonathan', 1;

sp_contact_update
@contact_id=N'162120',
	@salutation=N'',
	@first_name=N'Mark',
	@middle_name=N'',
	@last_name=N'Dingee',
	@suffix=N'',
	@title=N'',
	@email=N'paul.kalinka@eqonline.com',
	@email_flag=N'F',
	@phone=N'7343298000',
	@fax=N'7343298135',
	@mobile=N'',
	@pager=N'',
	@contact_type=N'',
	@contact_company=N'',
	@contact_addr1=N'',
	@contact_addr2=N'',
	@contact_addr3=N'',
	@contact_city=N'',
	@contact_state=N'',
	@contact_zip_code=N'',
	@contact_country=N'',
	@comments=N'',
	@contact_personal_info=N'',
	@contact_directions=N'',
	@contact_status=N'A',
	@added_by=N'RICH_G',
	@debug=N'0',
	@customer_list=N''
	
************************************************************/
Create Procedure sp_contact_update (

	@contact_id					int,
	@salutation					varchar(10),
	@first_name					varchar(20),
	@middle_name				varchar(20),
	@last_name					varchar(20),
	@suffix						varchar(25),
	@title						varchar(20),
	@email						varchar(60),
	@email_flag					char(1),
	@phone						varchar(20),
	@fax						varchar(10),
	@mobile						varchar(10),
	@pager						varchar(20),
	@contact_type				varchar(20),
	@contact_company			varchar(40),
	@contact_addr1				varchar(40),
	@contact_addr2				varchar(40),
	@contact_addr3				varchar(40),
	@contact_city				varchar(40),
	@contact_state				varchar( 2),
	@contact_zip_code			varchar(15),
	@contact_country			varchar(40),
	@comments					varchar(255),
	@contact_personal_info		text,
	@contact_directions			text,
	@customer_list				varchar(7000),
	@contact_status				char(1),
	@added_by					char(10),
	@debug						int = 0

)
AS
	set nocount on
	set ansi_warnings off

	if @debug <> 0 print 'sp_contact_update begun'

	declare @contact_found int,
		@note_id int,
		@field varchar(30),
		@result	int,
		@before_value varchar(1000),
		@after_value varchar(1000),
		@existinglist varchar(8000),
		@contact_id_text varchar(20),
		@changelog varchar(8000)


	-- Clean up the input @customer_list variable (fixes order)
	if @debug <> 0 print 'Parsing Customer List into table #ContactCustomers: ' + @customer_list

	create table #ContactCustomers (customer_id int)

	insert #ContactCustomers select convert(int, row) as customer_id from dbo.fn_SplitXsvText(',', 1, @customer_list) where isnull(row, '') <> ''

	select @customer_list = null
	select @customer_list = coalesce(@customer_list + ', ', '') + cast(customer_id as varchar(10)) from #ContactCustomers order by customer_id

	set @customer_list = ltrim(rtrim(@customer_list))

	if len(@customer_list) = 0 set @customer_list = '-1'

	if @debug <> 0 print 'Customer List: ' + @customer_list
	
	if @debug <> 0 
		begin
			declare @cust_count varchar(20)
			SELECT @cust_count = cast((SELECT COUNT(*) FROM #ContactCustomers) as varchar(20))
			print 'Customer List Count: ' + @cust_count
		end 


	-- Need a holder for sp_columns output
	create table #spcolumns (
		TABLE_QUALIFIER varchar(40),
		TABLE_OWNER varchar(40),
		TABLE_NAME varchar(400),
		COLUMN_NAME varchar(60),
		DATA_TYPE smallint,
		TYPE_NAME varchar(60),
		PRECIS int,
		LENGTH int,
		SCALE smallint,
		RADIX smallint,
		NULLABLE smallint,
		REMARKS varchar(254),
		COLUMN_DEF varchar(4000),
		SQL_DATA_TYPE smallint,
		SQL_DATETIME_SUB smallint,
		CHAR_OCTET_LENGTH int,
		ORDINAL_POSITION int,
		IS_NULLABLE varchar(254),
		SS_DATA_TYPE tinyint
	)

	-- Need a handy table to store all the new inputs
	create table #contact_update_input (
		salutation				varchar(10),
		first_name				varchar(20),
		middle_name				varchar(20),
		last_name				varchar(20),
		suffix					varchar(25),
		title					varchar(20),
		email					varchar(60),
		email_flag				char(1),
		phone					varchar(20),
		fax						varchar(10),
		mobile					varchar(10),
		pager					varchar(20),
		contact_type			varchar(20),
		contact_company			varchar(40),
		contact_addr1			varchar(40),
		contact_addr2			varchar(40),
		contact_addr3			varchar(40),
		contact_city			varchar(40),
		contact_state			varchar( 2),
		contact_zip_code		varchar(15),
		contact_country			varchar(40),
		comments				varchar(255),
		contact_personal_info	text,
		contact_directions		text,
		customer_list			varchar(7000),
		contact_status			char(1)
	)

	create table #columnList (column_name varchar(60))

	insert #contact_update_input (salutation,first_name,middle_name,last_name,suffix,title,email,email_flag,phone,fax,mobile,pager,contact_type,contact_company,contact_addr1,contact_addr2,contact_addr3,contact_city,contact_state,contact_zip_code,contact_country,comments,contact_personal_info,contact_directions,customer_list,contact_status)
	values (@salutation,@first_name,@middle_name,@last_name,@suffix,@title,@email,@email_flag,@phone,@fax,@mobile,@pager,@contact_type,@contact_company,@contact_addr1,@contact_addr2,@contact_addr3,@contact_city,@contact_state,@contact_zip_code,@contact_country,@comments,@contact_personal_info,@contact_directions,@customer_list,@contact_status)

	-- Need a temp table to hold the text field we're updating with audit changes
	create table #audit (audit text)
	insert #audit (audit) values ('')
	DECLARE @ptrval binary(16)
	SELECT @ptrval = TEXTPTR(audit) FROM #audit

	/*
	Update this value like this:
	UPDATETEXT #audit.audit @ptrval null null 'more text'
	*/

	-- Need a temp table to hold 1 value at a time for audit-creating.
	create table #pop (v varchar(255))

	-- Test: Is this a new contact or an edit to an existing one?
	if @contact_id is not null and len(@contact_id) > 0
		select @contact_found = 1 from contact where contact_id = @contact_id

	if @contact_found = 1 begin

		begin tran c_update

			set @contact_id_text = convert(varchar(20), @contact_id)

			-- Need a text list of the fields to loop over for creating audits
			insert into #spcolumns execute sp_columns contact
			select column_name as field, 0 as progress into #ufields from #spcolumns where column_name not in ('date_added', 'date_modified') order by ordinal_position
			delete from #spcolumns

			declare @tname varchar(255)
			select @tname = name from tempdb..sysobjects where name like '#contact_update_input%'

			-- Now reload #spcolumns with #contact_update_input
-- This breaks in prod when there are other users online.  Dump it.
-- insert into #spcolumns execute tempdb..sp_columns @tname

			insert into #columnList (column_name)
				select row as column_name from dbo.fn_SplitXsvText(',', 1, 'salutation, first_name, middle_name, last_name, suffix, title, email, email_flag, phone, fax, mobile, pager, contact_type, contact_company, contact_addr1, contact_addr2, contact_addr3, contact_city, contact_state, contact_zip_code, contact_country, comments, contact_personal_info, contact_directions, customer_list, contact_status') where isnull(row, '') <> ''

			-- Create a cursor over the list of fields
			DECLARE field_cursor CURSOR FOR
			SELECT field
			FROM #ufields
			WHERE progress = 0

			OPEN field_cursor

			FETCH NEXT FROM field_cursor
			INTO @field


			-- For every field...
			WHILE @@FETCH_STATUS = 0
			BEGIN

				-- Check to see if this contact field was given as sp input:
				if exists (select column_name FROM #columnList WHERE column_name = @field) begin

					-- Grab the original value into a generic variable
					exec ('insert #pop (v) select convert(varchar(1000), ' + @field + ') from contact where contact_id = ' + @contact_id)
					select @before_value = isnull(nullif(v, ''), '(blank)') from #pop
					delete from #pop

					-- Grab the new value into a generic variable
					exec ('insert #pop (v) select convert(varchar(1000), ' + @field + ') from #contact_update_input')
					select @after_value = isnull(nullif(v, ''), '(blank)') from #pop
					delete from #pop

					-- Call eqsp_CustomerAudit for this field with the before/after values
					set @changelog = null
					if @before_value <> @after_value
						set @changelog = '(FIELD) ' + @field + ' (FROM) ' + @before_value + ' (TO) ' + @after_value + '; '
					UPDATETEXT #audit.audit @ptrval null null @changelog

				end
				-- Reload for the next loop through
			   FETCH NEXT FROM field_cursor
			   INTO @field
			END

			CLOSE field_cursor
			DEALLOCATE field_cursor

			-- Log the existing contactxref customer associations
			select @existinglist = coalesce(@existinglist + ', ', '') + cast(customer_id as varchar(10))
			from contactxref where contact_id = @contact_id and type = 'C' and status = 'A' order by customer_id

			set @existinglist = ltrim(rtrim(isnull(@existinglist, '')))

			if isnull(@existinglist, '') <> isnull(@customer_list, '') and @customer_list <> '-1' begin
				select @before_value = @existinglist, @after_value = @customer_list

				-- Call eqsp_CustomerAudit for this field with the before/after values
				set @changelog = null
				if @before_value <> @after_value
					set @changelog = '(TABLE) contactxref customer associations (FROM) ' + @before_value + ' (TO) ' + @after_value + '; '
				UPDATETEXT #audit.audit @ptrval null null @changelog
			end

			
			if (select datalength(audit) from #audit) > 0
				Begin

					exec @note_id = sp_sequence_next 'Note.Note_ID', 0

					if @debug <> 0 select audit as 'Change Log' from #audit

					-- Put the Audit info into the Note table
					Insert Note (note_id, note_source, note_date, subject, status, note_type, note, contact_id, added_by, date_added, modified_by, date_modified, app_source, rowguid)
					select @note_id, 'Contact', getdate(), 'AUDIT', 'C', 'AUDIT', audit, @contact_id, @added_by, getdate(), @added_by, getdate(), 'WEB', newid()
					from #audit

					-- Update Contact
					Update Contact set
						salutation = @salutation ,
						first_name = @first_name ,
						middle_name = @middle_name ,
						last_name = @last_name ,
						suffix = @suffix ,
						name = replace(ltrim(rtrim(isnull(@salutation, '') + ' ' + isnull(@first_name, '') + ' ' + isnull(@middle_name, '') + ' ' + isnull(@last_name, '') + ' ' + isnull(@suffix, ''))), '  ', ' '),
						title = @title ,
						email = @email ,
						email_flag = @email_flag ,
						phone = @phone ,
						fax = @fax ,
						mobile = @mobile ,
						pager = @pager ,
						contact_type = @contact_type ,
						contact_company = @contact_company ,
						contact_addr1 = @contact_addr1 ,
						contact_addr2 = @contact_addr2 ,
						contact_addr3 = @contact_addr3 ,
						contact_city = @contact_city ,
						contact_state = @contact_state ,
						contact_zip_code = @contact_zip_code ,
						contact_country = @contact_country ,
						comments = @comments ,
						contact_personal_info = @contact_personal_info ,
						contact_directions = @contact_directions ,
						modified_by = @added_by,
						date_modified = getdate()
					where
						contact_id = @contact_id

					select @contact_id as contact_id

					if @debug <> 0 print 'Existing vs Customer List: ' + ISNULL(@existingList,'empty') + ' vs ' + ISNULL(@customer_list,'empty')
					if isnull(@existinglist,'') <> isnull(@customer_list,'') and @customer_list <> '-1'
					Begin

						
						 SELECT 'remove old access',
							status = 'I',
							web_access = 'I',
							primary_contact = 'F',
							modified_by = @added_by,
							date_modified = getdate()
						FROM ContactXRef
						where type = 'C'
							and contact_id = @contact_id
							and customer_id not in (select customer_id from #ContactCustomers)
						
						-- Remove the old ones
						update contactxref set
							status = 'I',
							web_access = 'I',
							primary_contact = 'F',
							modified_by = @added_by,
							date_modified = getdate()
						where type = 'C'
							and contact_id = @contact_id
							and customer_id not in (select customer_id from #ContactCustomers)

						-- Update the existing, still used ones
						update contactxref set
							status = 'A',
							modified_by = @added_by,
							date_modified = getdate()
						where type = 'C'
							and contact_id = @contact_id
							and customer_id in (select customer_id from #ContactCustomers)

						-- Add the new ones
						insert contactxref
						select
							@contact_id as contact_id,
							'C' as type,
							customer_id,
							null as generator_id,
							'I' as web_access,
							'A' as status,
							@added_by as added_by,
							getdate() as date_added,
							@added_by as modified_by,
							getdate() as date_modified,
							'F' as primary_contact,
							newid() as rowguid
						from customer
						where customer_id in (select customer_id from #ContactCustomers)
							and customer_id not in (
								select
									customer_id
								from contactxref
								where status = 'A'
									and type = 'C'
									and contact_id = @contact_id
							)
					End

					-- Contact status changes (where not 'A') occur last, since they use a separate sp
					if @contact_status <> 'A'
						exec sp_contact_disable @contact_id, @added_by, @debug
					else
						update contact set contact_status = 'A' where contact_id = @contact_id

					commit tran c_update

				End
			Else
				Begin
					rollback tran c_update
				End
	End
else
	Begin

		begin tran c_insert

			exec @contact_id = sp_sequence_next 'Contact.contact_id'

			insert Contact (
				contact_ID            ,
				contact_status        ,
				contact_type          ,
				contact_company       ,
				name                  ,
				title                 ,
				phone                 ,
				fax                   ,
				pager                 ,
				mobile                ,
				comments              ,
				email                 ,
				email_flag            ,
				modified_by           ,
				date_added            ,
				date_modified         ,
				web_access_flag       ,
				contact_addr1         ,
				contact_addr2         ,
				contact_addr3         ,
				contact_city          ,
				contact_state         ,
				contact_zip_code      ,
				contact_country       ,
				contact_personal_info ,
				contact_directions    ,
				rowguid               ,
				salutation            ,
				first_name            ,
				middle_name           ,
				last_name             ,
				suffix
			) values (
				@contact_ID            ,
				'A',
				@contact_type          ,
				@contact_company       ,
				replace(ltrim(rtrim(isnull(@salutation, '') + ' ' + isnull(@first_name, '') + ' ' + isnull(@middle_name, '') + ' ' + isnull(@last_name, '') + ' ' + isnull(@suffix, ''))), '  ', ' '),
				@title                 ,
				@phone                 ,
				@fax                   ,
				@pager                 ,
				@mobile                ,
				@comments              ,
				@email                 ,
				@email_flag            ,
				@added_by           ,
				getdate()            ,
				getdate()         ,
				'F',
				@contact_addr1         ,
				@contact_addr2         ,
				@contact_addr3         ,
				@contact_city          ,
				@contact_state         ,
				@contact_zip_code      ,
				@contact_country       ,
				@contact_personal_info ,
				@contact_directions    ,
				newid()               ,
				@salutation            ,
				@first_name            ,
				@middle_name           ,
				@last_name             ,
				@suffix
			)

			if @debug <> 0 and @customer_list <> '-1' print 'Inserting Customer Associations'

			insert contactxref
			select
				@contact_id as contact_id,
				'C' as type,
				customer_id,
				null as generator_id,
				'I' as web_access,
				'A' as status,
				@added_by as added_by,
				getdate() as date_added,
				@added_by as modified_by,
				getdate() as date_modified,
				'F' as primary_contact,
				newid() as rowguid
			from customer
			where customer_id in (select customer_id from #ContactCustomers)

			exec @note_id = sp_sequence_next 'Note.Note_ID'

			if @debug <> 0 print 'Inserting customer association note (' + convert(varchar(10), @note_id) + ')'

			Insert Note (
				note_id,
				note_source,
				note_date,
				subject,
				status,
				note_type,
				note,
				contact_id,
				added_by,
				date_added,
				modified_by,
				date_modified,
				app_source,
				rowguid
			) values (
				@note_id,
				'Contact',
				getdate(),
				'AUDIT',
				'C',
				'AUDIT',
				'Contact added to customers ' + isnull(@customer_list, '(no customers specified)'),
				@contact_id,
				@added_by,
				getdate(),
				@added_by,
				getdate(),
				'WEB',
				newid()
			)

		commit tran c_insert

	End

	set nocount off
	set ansi_warnings on

	select @contact_id as contact_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_contact_update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_contact_update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_contact_update] TO [EQAI]
    AS [dbo];

