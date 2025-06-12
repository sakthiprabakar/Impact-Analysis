
/***************************************************************************************
Deletes (sets status = Void) a Customer Note

09/15/2003 JPB	Created
Test Cmd Line: spw_customernote_delete 2222, 14350, 'JONATHAN'
****************************************************************************************/
create procedure spw_customernote_delete
	@customer_id	int,
	@note_id	int,
	@by	varchar(10)
as
	update customernote set status = 'V' where customer_id = @customer_id and note_id = @note_id
	
	declare @detailid int
	set nocount on
	exec @detailID = sp_sequence_next 'CustomerNoteDetail.Detail_ID'
	set nocount off
	insert into customernotedetail (detail_id, customer_id, note_id, note, date_added, added_by, audit)
	values (@detailid, @customer_id, @note_id,
	'Delete: status set to Void',
	GETDATE(), @By, 'T')


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customernote_delete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customernote_delete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customernote_delete] TO [EQAI]
    AS [dbo];

