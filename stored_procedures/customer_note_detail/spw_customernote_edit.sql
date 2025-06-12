
/***************************************************************************************
Edits a Customer Note

09/15/2003 JPB	Created
Test Cmd Line: spw_customernote_edit 14350, 2222, 845, 'note text', '9/15/2003 08:45:00.000', 'JONATHAN', 'O', 'subject', 'JONATHAN', '9/14/2003 08:45:00.000', '', ''
****************************************************************************************/
create procedure spw_customernote_edit
	@note_id	int,
	@customer_id	int,
	@contact_id	int,
	@note	text,
	@contact_date	datetime,
	@by	varchar(10),
	@status	char(1),
	@subject	varchar(50),
	@recipient	varchar(255),
	@send_email_date	datetime,
	@cc_list	varchar(255),
	@action_type	varchar(20) = 'None'
as
	
	update customernote set
	contact_id = @contact_id,
	note = @note,
	contact_date = @contact_date,
	modified_by = @by,
	status = @status,
	subject = @subject,
	action_type = @action_type,
	date_modified = getdate(),
	recipient = @recipient,
	send_email_date = @send_email_date,
	cc_list = @cc_list
	where note_id = @note_id
	
	declare @detailid int
	set nocount on
	exec @detailID = sp_sequence_next 'CustomerNoteDetail.Detail_ID'
	set nocount off
	insert into customernotedetail (detail_id, customer_id, note_id, note, date_added, added_by, audit)
	values (@detailid, @customer_id, @note_id,
	'Update:' + char(10) +
	'Contact_Date: ' + isnull(cast(@contact_date as varchar(30)), '') + char(10) +
	'Status: ' + Isnull(@status, '') + char(10) +
	'Contact_ID: ' + Isnull(cast(@contact_id as varchar(10)), '') + char(10) +
	'Recipient: ' + Isnull(@recipient, '') + char(10) +
	'Subject: ' + Isnull(@subject, '') + char(10) +
	'Action Type: ' + Isnull(@action_type, '') + char(10) +
	'Note: ' + Isnull(cast(@note as varchar(8000)), '') + char(10) +
	'Send_Email_Date: ' + isnull(cast(@send_email_date as varchar(30)), '') + char(10) +
	'CC list: ' + Isnull(@cc_list, '') + char(10),
	GETDATE(), Isnull(@By, ''), 'T')


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customernote_edit] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customernote_edit] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customernote_edit] TO [EQAI]
    AS [dbo];

