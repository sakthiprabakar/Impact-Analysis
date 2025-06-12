/************************************************************
Procedure    : sp_note_update
Database     : PLT_AI*
Created      : Wed Jun 07 13:18:18 EDT 2006 - Jonathan Broome
Description  : Inserts or Updates a Note Record


sp_note_update NULL, 888888, 10001, 'Note', 'C', '6/6/2006', 'Test Note', 'This is a test note.', 'Jonathan'
sp_note_update 115000, 888888, 10001, 'Note', 'C', '6/6/2006', 'Test Note', 'This is a test note, revised.', 'Jonathan'

select max(note_id) from note
select * from sequence where name = 'note.note_id'
select * from note where note_id >= 115000

************************************************************/
Create Procedure sp_note_update (

	@note_id		int,
	@customer_id	varchar(8000), -- Big Assumption: Adding can have a list, editing will be a single id
	@contact_id		varchar(8000), -- Big Assumption: Adding can have a list, editing will be a single id
	@contact_type	varchar(15),
	@status			char(1),
	@note_date		datetime,
	@subject		varchar(50),
	@note			text,
	@added_by		varchar(60),
	@note_type		varchar(15) = 'NOTE'

)
AS
	set nocount on

	declare @old_added_by char(10)

	if (@note_id is not null)
		select @old_added_by = modified_by from note where note_id = @note_id

	if (@note_id is not null) and (@old_added_by = @added_by) and (@old_added_by is not null)
		Begin
			Update Note set
				note_date = @note_date,
				subject = @subject,
				note = @note,
				status = @status,
				contact_type = @contact_type,
				customer_id = convert(int, @customer_id),
				contact_id = convert(int, @contact_id),
				modified_by = @added_by,
				date_modified = getdate()
			where
				note_id = @note_id

			select @note_id as note_id
		End
	else
		Begin
		
			declare	@intcount int, @list_id int, @i int, @list2_id int
			
			CREATE TABLE #1 ( list_id int ) -- customer id's
			CREATE TABLE #2 ( list_id int ) -- contact id's
			CREATE TABLE #3 ( list_id int ) -- contact id's for this customer id

			/* Check To See If The Number Parser Table Exists, Create If Necessary */
			Select @intcount = Count(*) From Syscolumns C Inner Join Sysobjects O On O.id = C.id And O.name = 'TblToolsStringParserCounter' And C.name = 'id'
			If @intcount = 0
			Begin
				Create Table TblToolsStringParserCounter (
					Id	Int	)
		
				Select  @i = 1
		
				While (@i <= 8000)
				Begin
					Insert Into TblToolsStringParserCounter Select @i
					Select @i = @i + 1
				End
			End
			
		-- put customers in #1
			If charindex(',', @customer_id) > 0
			Begin
				/* Insert The customer_id Data Into A Temp Table For Use Later */
				Insert Into #1
				Select  Nullif(substring(',' + @customer_id + ',' , Id ,
					Charindex(',' , ',' + @customer_id + ',' , Id) - Id) , '') As list_id
				From Tbltoolsstringparsercounter
				Where Id <= Len(',' + @customer_id + ',') And Substring(',' + @customer_id + ',' , Id - 1, 1) = ','
				And Charindex(',' , ',' + @customer_id + ',' , Id) - Id > 0
			End
			Else
				if len(@customer_id) > 0
					Insert into #1 values (@customer_id)

		-- put contacts in #2
			If charindex(',', @contact_id) > 0
			Begin
				/* Insert The contact_id Data Into A Temp Table For Use Later */
				Insert Into #2
				Select  Nullif(substring(',' + @contact_id + ',' , Id ,
					Charindex(',' , ',' + @contact_id + ',' , Id) - Id) , '') As list_id
				From Tbltoolsstringparsercounter
				Where Id <= Len(',' + @contact_id + ',') And Substring(',' + @contact_id + ',' , Id - 1, 1) = ','
				And Charindex(',' , ',' + @contact_id + ',' , Id) - Id > 0
			End
			Else
				if len(@contact_id) > 0
					Insert into #2 values (@contact_id)
					
					
			declare Customers cursor
			for select distinct list_id from #1
			open Customers
		
			fetch next from Customers into @list_id

			-- For each customer id in #1...
			while @@Fetch_Status = 0
			begin

				-- Empty out #3
				delete from #3
				
				-- select all contact id's from #2 that belong to this customer, into #3
				insert into #3
				select list_id from #2 inner join contactxref x on #2.list_id = x.contact_id
				where x.customer_id = @list_id
				and x.status = 'A'

				-- If #3 has rows...				
				if 0 < (select count(*) from #3)
				begin

					declare Contacts cursor
					for select distinct list_id from #3
					open Contacts
				
					fetch next from Contacts into @list2_id
				
					-- For each contact id in #3, insert a note with customer id and contact id
					while @@Fetch_Status = 0
					begin
						exec @note_id = sp_sequence_next 'Note.note_id'
						insert Note (
							note_id,
							note_source,
							note_date,
							subject,
							status,
							note_type,
							note,
							customer_id,
							contact_id,
							contact_type,
							added_by,
							date_added,
							modified_by,
							date_modified,
							app_source,
							rowguid
						) values (
							@note_id,
							'Customer',
							@note_date,
							@subject,
							@status,
							@note_type,
							@note,
							@list_id,
							@list2_id,
							@contact_type,
							@added_by,
							getdate(),
							@added_by,
							getdate(),
							'WEB',
							newid()
						)
						
						-- remove this contact from #2, it's already been handled.
						delete from #2 where list_id = @list2_id
						
						fetch next from Contacts into @list2_id
					end
					
					close Contacts
					deallocate Contacts
				end
				else -- There were no contacts for this customer (#3 is empty)
				begin
					-- insert a note with just this customer id
					exec @note_id = sp_sequence_next 'Note.note_id'
					insert Note (
						note_id,
						note_source,
						note_date,
						subject,
						status,
						note_type,
						note,
						customer_id,
						contact_id,
						contact_type,
						added_by,
						date_added,
						modified_by,
						date_modified,
						app_source,
						rowguid
					) values (
						@note_id,
						'Customer',
						@note_date,
						@subject,
						@status,
						@note_type,
						@note,
						@list_id,
						NULL,
						@contact_type,
						@added_by,
						getdate(),
						@added_by,
						getdate(),
						'WEB',
						newid()
					)
				end
					
				-- Next customer id...
				fetch next from Customers into @list_id
			end
		
			close Customers
			deallocate Customers
					
			-- Check for any contacts still in #2					
			declare Contacts cursor
			for select distinct list_id from #2
			open Contacts
		
			fetch next from Contacts into @list2_id
		
			-- for each contact left
			while @@Fetch_Status = 0
			begin
				-- insert a note with contact id but no customer id
				exec @note_id = sp_sequence_next 'Note.note_id'
				insert Note (
					note_id,
					note_source,
					note_date,
					subject,
					status,
					note_type,
					note,
					customer_id,
					contact_id,
					contact_type,
					added_by,
					date_added,
					modified_by,
					date_modified,
					app_source,
					rowguid
				) values (
					@note_id,
					'Customer',
					@note_date,
					@subject,
					@status,
					@note_type,
					@note,
					NULL,
					@list2_id,
					@contact_type,
					@added_by,
					getdate(),
					@added_by,
					getdate(),
					'WEB',
					newid()
				)
				
				fetch next from Contacts into @list2_id
			end
					
			close Contacts
			deallocate Contacts
		
		End
	set nocount off

	select @note_id as note_id
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_note_update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_note_update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_note_update] TO [EQAI]
    AS [dbo];

