if exists (select 1 from sysobjects where type = 'P' and name = 'sp_labpack_sync_upload_note_profile')
	drop procedure dbo.sp_labpack_sync_upload_note_profile
go

create procedure sp_labpack_sync_upload_note_profile
	@profile_id int,
	@company_id int,
	@profit_ctr_id int,
	@customer_id int,
	@generator_id int,
	@subject varchar(50),
	@note_segment_1 varchar(8000),
	@note_segment_2 varchar(8000) = null,
	@note_segment_3 varchar(8000) = null,
	@note_segment_4 varchar(8000) = null
as
	declare @note varchar(max),
			@note_id int

	set @note = convert(varchar(max),coalesce(@note_segment_1,''))
			  + coalesce(@note_segment_2,'') + coalesce(@note_segment_3,'') + coalesce(@note_segment_4,'')

	set @note = REPLACE(REPLACE(@note,char(13)+char(10),char(10)),char(10),char(13)+char(10))

	if exists (select 1 from dbo.Note where note_source = 'Profile' and profile_id = @profile_id)
	begin
		update dbo.Note
		set company_id = @company_id,
			profit_ctr_id = @profit_ctr_id,
			customer_id  = @customer_id,
			generator_id = @generator_id,
			subject = @subject,
			note = @note
		where note_source = 'Profile'
		and profile_id = @profile_id

		if @@ERROR <> 0
		begin
			raiserror('Error: An error occurred when updating the Note table',18,-1) with seterror
			return -1
		end
	end
	else
	begin
		exec @note_id = dbo.sp_sequence_silent_next 'Note.note_id'

		insert dbo.Note (note_id, note_source, company_id, profit_ctr_id, note_date, subject, status, note_type, note, customer_id,
						generator_id, profile_id, contact_type, added_by, date_added, modified_by, date_modified, app_source, rowguid)
		values (@note_id, 'Profile', @company_id, @profit_ctr_id, getdate(), coalesce(@subject,''), 'C', 'NOTE', @note,
				@customer_id, @generator_id, @profile_id, 'Note', 'LPx', getdate(), 'LPx', getdate(), 'LabPack', NEWID())

		if @@ERROR <> 0
		begin
			raiserror('Error: An error occurred when inserting into the Note table',18,-1) with seterror
			return -1
		end
	end

	return 0
go

grant execute on dbo.sp_labpack_sync_upload_note_profile to EQAI, LPSERV
go
