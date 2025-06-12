
/***************************************************************************************
Responds to a Customer Note

09/15/2003 JPB	Created
Test Cmd Line: spw_customernote_respond 2222, 14350, 'response' 'JONATHAN'
****************************************************************************************/
create procedure spw_customernote_respond
	@customer_id	int,
	@note_id	int,
	@note	text,
	@by	varchar(10)
as
	declare @detailid int
	set nocount on
	exec @detailID = sp_sequence_next 'CustomerNoteDetail.Detail_ID'
	set nocount off
	insert into customernotedetail (detail_id, customer_id, note_id, note, date_added, added_by, audit)
	values (@detailid, @customer_id, @note_id, @note, getdate(), @by, 'F')
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customernote_respond] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customernote_respond] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customernote_respond] TO [EQAI]
    AS [dbo];

