
/***************************************************************************************
Adds a new Customer Note

09/15/2003 JPB	Created
Test Cmd Line: spw_customernote_add 2222, 845, 'note text', '9/15/2003 08:45:00.000', 'actionitem', 2, 'JONATHAN', 'O', 'subject', '', 'JONATHAN', '9/14/2003 08:45:00.000', '', 0
****************************************************************************************/
create procedure spw_customernote_add
	@customer_id	int,
	@contact_id	int,
	@note	text,
	@contact_date	datetime,
	@note_type	varchar(15),
	@added_from_company	int,
	@by	varchar(10),
	@status	char(1),
	@subject	varchar(50),
	@action_type	varchar(20) = 'None',
	@recipient	varchar(255),
	@send_email_date	datetime,
	@cc_list	varchar(255),
	@note_group_id	int
as
	declare @noteid int
	set nocount on
	exec @noteID = sp_sequence_next 'CustomerNote.Note_ID'
	set nocount off
	insert into customernote (customer_id, note_id, note, contact_date, note_type, added_from_company, modified_by, date_added, date_modified, contact_id, status, added_by, subject, action_type, recipient, send_email_date, cc_list, note_group_id) values (@customer_id, @noteid, @note, @contact_date, @note_type, @added_from_company, @by, getdate(), getdate(), @contact_id, @status, @by, @subject, @action_type, @recipient, @send_email_date, @cc_list, @note_group_id)
	
	declare @detailid int
	set nocount on
	exec @detailID = sp_sequence_next 'CustomerNoteDetail.Detail_ID'
	set nocount off
	insert into customernotedetail (detail_id, customer_id, note_id, note, date_added, added_by, audit)
	values (@detailid, @customer_id, @noteid,
	'Insert:' + char(10) +
	'Contact_Date: ' + isnull(cast(@contact_date as varchar(30)), '') + char(10) +
	'Status: ' + Isnull(@status, '') + char(10) +
	'Contact_ID: ' + Isnull(cast(@contact_id as varchar(10)), '') + char(10) +
	'Recipient: ' + Isnull(@recipient, '') + char(10) +
	'Subject: ' + Isnull(@subject, '') + char(10) +
	'Action Type: ' + Isnull(@Action_Type, '') + char(10) +
	'Note: ' + Isnull(cast(@note as varchar(8000)), '') + char(10) +
	'Send_Email_Date: ' + isnull(cast(@send_email_date as varchar(30)), '') + char(10) +
	'CC list: ' + Isnull(@cc_list, '') + char(10) + 
	'Note Group ID: ' + isnull(cast(@note_group_id as varchar(10)), ''),
	GETDATE(), @By, 'T')


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customernote_add] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customernote_add] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_customernote_add] TO [EQAI]
    AS [dbo];

