
/************************************************************
Procedure    : sp_opp_note_update
Database     : PLT_AI*
Created      : Wed Jun 07 13:18:18 EDT 2006 - Jonathan Broome
Description  : Inserts or Updates a Note Record


copied from sp_note_update

sp_opp_note_update NULL, 888888, 10001, 'Note', 'C', '6/6/2006', 'Test Note', 'This is a test note.', 'Jonathan'
sp_opp_note_update 115000, 888888, 10001, 'Note', 'C', '6/6/2006', 'Test Note', 'This is a test note, revised.', 'Jonathan'

select max(note_id) from note
select * from sequence where name = 'note.note_id'
select * from note where note_id >= 115000

************************************************************/
Create Procedure sp_opp_note_update (

	@note_id		int,
	@customer_id	varchar(8000), -- Big Assumption: Adding can have a list, editing will be a single id
	@contact_id		varchar(8000), -- Big Assumption: Adding can have a list, editing will be a single id
	@eq_contact_list varchar(max) = NULL, -- this is the list of people who may have attended the sales call, mainly app
	@opp_id			int = NULL,
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
	set transaction isolation level read uncommitted
	declare @debug int =0
	
	declare @tbl_eqcontact table (user_code varchar(20))
	declare @tbl_notes_affected table (note_id int, customer_id int, opp_id int)
	
	INSERT @tbl_eqcontact 
	SELECT row from dbo.fn_SplitXsvText(',', 0, @eq_contact_list) 
	where isnull(row, '') <> ''		
	
	IF @opp_id = 0
		 set @opp_id = null

	if @note_id is not null
	begin		 
	INSERT INTO @tbl_notes_affected (customer_id, note_id, opp_id)
				SELECT @customer_id, @note_id, @opp_id		 
				
	DELETE FROM OppNoteXEQContact WHERE
		note_id = @note_id
		AND ISNULL(@customer_id,0) = ISNULL(OppNoteXEQContact.customer_id,0)
		AND ISNULL(@opp_id,0) = ISNULL(OppNoteXEQContact.opp_id,0)
		--AND ISNULL(@contact_id,0) = ISNULL(OppNoteXEQContact.contact_id,0)		 
	end
	

	declare @old_added_by char(10)

	if (@note_id is not null)
		select @old_added_by = modified_by from note where note_id = @note_id

	if (@note_id is not null) and (@old_added_by = @added_by) and (@old_added_by is not null)
		Begin
			declare @note_src varchar(20)
			SELECT @note_src = note.note_source FROM Note where note_id = @note_id
			
			-- UPDATE the OppNote
			IF EXISTS(SELECT 1 FROM OppNote where note_id = @note_id AND note_source = 'Opportunity')
			BEGIN
				Update OppNote set
				note_date = @note_date,
				subject = @subject,
				note = @note,
				status = @status,
				contact_type = @contact_type,
				customer_id = convert(int, @customer_id),
				contact_id = convert(int, @contact_id),
				opp_id = @opp_id,
				modified_by = @added_by,
				date_modified = getdate()
			where
				note_id = @note_id
			END
			
			-- UPDATE Note
			IF EXISTS(SELECT 1 FROM Note where note_id = @note_id AND note_source <> 'Opportunity')
			BEGIN
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
			END
			
		

				
			--INSERT INTO OppNoteXEQContact

			select @note_id as note_id
		End
	else
		Begin
		if @debug > 0 print 'inserting data...'
			declare	@intcount int, @list_id int, @i int, @list2_id int
			
			CREATE TABLE #1 ( list_id int ) -- customer id's
			CREATE TABLE #2 ( list_id int ) -- contact id's
			CREATE TABLE #3 ( list_id int ) -- contact id's for this customer id
			CREATE TABLE #4 ( list_id int ) -- opp_ids
			
			


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
			
				if @debug > 0 print 'inserting data...customers loop'

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
						
					--IF NOT EXISTS( SELECT 1 FROM @tbl_notes_affected a WHERE customer_id = @list_id)
						INSERT INTO @tbl_notes_affected (note_id, customer_id, opp_id)
						SELECT @note_id, @list_id, @opp_id
						
					/* NOTE THAT THIS INSERT IS TO A DIFFERENT TABLE 'OppNote' */
					/* This will be here until the Note table can be merged with OppNote */
					/* OppNote still uses Note.note_id as a sequence so that merging later
					will be easier
					*/
					if @opp_id is not null
					BEGIN	
					if @debug > 0 print 'inserting data...opp loop'
					-- insert an opportunity note
								exec @note_id = sp_sequence_next 'Note.note_id'
								insert OppNote (
									note_id,
									note_source,
									note_date,
									subject,
									status,
									note_type,
									note,
									opp_id,
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
									'Opportunity',
									@note_date,
									@subject,
									@status,
									@note_type,
									@note,
									@opp_id,
									@list_id, -- customer
									@list2_id, -- contact
									@contact_type,
									@added_by,
									getdate(),
									@added_by,
									getdate(),
									'WEB',
									newid()
								)

								--IF NOT EXISTS( SELECT 1 FROM @tbl_notes_affected a WHERE customer_id = @list_id)
									INSERT INTO @tbl_notes_affected (note_id, customer_id, opp_id)
									SELECT @note_id, @list_id, @opp_id
								

					END
						
						
					
						
						-- remove this contact from #2, it's already been handled.
						delete from #2 where list_id = @list2_id
						
						fetch next from Contacts into @list2_id
					end
					
					close Contacts
					deallocate Contacts
				end
				else -- There were no contacts for this customer (#3 is empty)
				begin
					if @debug > 0 print 'inserting data...no contacts for customer loop'
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
					
					--IF NOT EXISTS( SELECT 1 FROM @tbl_notes_affected a WHERE customer_id = @list_id)
						INSERT INTO @tbl_notes_affected (note_id, customer_id, opp_id)
						SELECT @note_id, @list_id, @opp_id
						
						
					/* NOTE THAT THIS INSERT IS TO A DIFFERENT TABLE 'OppNote' */
					/* This will be here until the Note table can be merged with OppNote */
					/* OppNote still uses Note.note_id as a sequence so that merging later
					will be easier
					*/
					if @opp_id is not null
					BEGIN	
					if @debug > 0 print 'inserting data...opp no contacts for customer loop'
					-- insert an opportunity note
								exec @note_id = sp_sequence_next 'Note.note_id'
								insert OppNote (
									note_id,
									note_source,
									note_date,
									subject,
									status,
									note_type,
									note,
									opp_id,
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
									'Opportunity',
									@note_date,
									@subject,
									@status,
									@note_type,
									@note,
									@opp_id,
									@list_id, -- customer
									NULL, -- contact
									@contact_type,
									@added_by,
									getdate(),
									@added_by,
									getdate(),
									'WEB',
									newid()
								)

								--IF NOT EXISTS( SELECT 1 FROM @tbl_notes_affected a WHERE customer_id = @list_id)
									INSERT INTO @tbl_notes_affected (note_id, customer_id, opp_id)
									SELECT @note_id, @list_id, @opp_id
								

					END
					
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
		
	if @customer_id is null and @contact_id is null and @opp_id is not null

			
		/* NOTE THAT THIS INSERT IS TO A DIFFERENT TABLE 'OppNote' */
		/* This will be here until the Note table can be merged with OppNote */
		/* OppNote still uses Note.note_id as a sequence so that merging later
		will be easier
		*/
		BEGIN	
		if @debug > 0 print 'inserting data...opp no contacts for customer loop'
		-- insert an opportunity note
					exec @note_id = sp_sequence_next 'Note.note_id'
					insert OppNote (
						note_id,
						note_source,
						note_date,
						subject,
						status,
						note_type,
						note,
						opp_id,
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
						'Opportunity',
						@note_date,
						@subject,
						@status,
						@note_type,
						@note,
						@opp_id,
						NULL, -- customer
						NULL, -- contact
						@contact_type,
						@added_by,
						getdate(),
						@added_by,
						getdate(),
						'WEB',
						newid()
					)

					--IF NOT EXISTS( SELECT 1 FROM @tbl_notes_affected a WHERE customer_id = @list_id)
						INSERT INTO @tbl_notes_affected (note_id, customer_id, opp_id)
						SELECT @note_id, @list_id, @opp_id
					

		END
		
	
	-- add eqcontacts if any
	INSERT INTO OppNoteXEQContact (opp_id, customer_id, billing_project_id, note_id, user_code)
	SELECT t.opp_id, t.customer_id, 0, t.note_id, eq.user_code FROM @tbl_notes_affected t
		JOIN @tbl_eqcontact eq ON 1=1
		--WHERE t.opp_id is not null
		AND NOT EXISTS(SELECT 1 FROM OppNoteXEQContact tmp
			where eq.user_code = tmp.user_code
			and t.opp_id = tmp.opp_id
			and t.note_id = tmp.note_id
			and t.customer_id = tmp.customer_id
			and tmp.billing_project_id = 0)
			
	set nocount off
	select @note_id as note_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opp_note_update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opp_note_update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opp_note_update] TO [EQAI]
    AS [dbo];

