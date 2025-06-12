
--create procedure sp_jdesync_customer_note
--	@jde_activity_id int,
--	@customer_id int,
--	@jde_note_date datetime,
--	@jde_subject varchar(33),
--	@note_text varchar(max),
--	@user varchar(10)
--as
--/***************************************************************
--Loads to:	Plt_ai

--Update or insert a note, called from EQFinance when a note is updated or added in JDE

--03/22/2013 RB	Created

--****************************************************************/

--declare @note_id int,
--	@max_changelog_id int

---- look for note_id in xref table
--select @note_id = eqai_note_id
--from CustomerNoteXJDECustomerActivityLog
--where jde_activity_id = @jde_activity_id

---- if ID is already x-ref'd, UPDATE
--if ISNULL(@note_id,0) > 0
--begin
--	begin transaction

--	update Note
--	set note_date = @jde_note_date,
--		subject = @jde_subject,
--		note = @note_text,
--		modified_by = @user,
--		date_modified = GETDATE()
--	where note_id = @note_id

--	if @@ERROR <> 0
--	begin
--		rollback transaction
--		raiserror('ERROR: updating Plt_ai.Note',16,1)
--		return -1
--	end

--	select @max_changelog_id = max(JDEChangeLog_uid)
--	from JDEChangeLog
--	where customer_id = @customer_id

--	if exists (select 1 from JDEChangeLog
--			where JDEChangeLog_uid = @max_changelog_id
--			and type = 'CN'
--			and status = 'P')
--	begin
--		delete JDEChangeLog
--		where JDEChangeLog_uid = @max_changelog_id

--		if @@ERROR <> 0
--		begin
--			rollback transaction
--			raiserror('ERROR: Deleting unwanted JDEChangeLog record for JDE->EQAI customer note sync',16,1)
--			return -1
--		end
--	end

--	commit transaction
--end

---- else, INSERT
--else
--begin
--	-- generate a new note_id outside of transaction
--	exec @note_id = sp_sequence_next 'Note.note_id', 0
	
--	if @@ERROR <> 0
--	begin
--		raiserror('ERROR: calling Plt_ai.sp_sequence_next ''Note.note_id''',16,1)
--		return -1
--	end
	
--	-- BEGIN TRANSACTION
--	begin transaction

--	insert Note (note_id, note_source, note_date, subject, status, note_type, note,
--				customer_id, contact_type, added_by, date_added, modified_by, date_modified)
--	values (@note_id, 'Customer', @jde_note_date, @jde_subject, 'C', 'NOTE', @note_text,
--			@customer_id, 'Note', @user, GETDATE(), @user, GETDATE())

--	if @@ERROR <> 0
--	begin
--		rollback transaction
--		raiserror('ERROR: insert into Plt_ai.Note',16,1)
--		return -1
--	end

--	insert CustomerNoteXJDECustomerActivityLog
--			(eqai_note_id, jde_activity_id, customer_id, added_by, date_added, modified_by, date_modified)
--	values	(@note_id, @jde_activity_id, @customer_id, @user, GETDATE(), @user, GETDATE())
	
--	if @@ERROR <> 0
--	begin
--		rollback transaction
--		raiserror('ERROR: insert into Plt_ai.CustomerNoteXJDECustomerActivityLog',16,1)
--		return -1
--	end

--	commit transaction
--end

--return 0

--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_jdesync_customer_note] TO [EQAI_LINKED_SERVER]
--    AS [dbo];

