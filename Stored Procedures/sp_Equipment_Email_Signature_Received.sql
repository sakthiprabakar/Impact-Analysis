
create proc sp_Equipment_Email_Signature_Received (
	@equipment_set_id			int
)
as
/* *******************************************************************
sp_Equipment_Email_Signature_Received

	Sends email notifying a signature has been received
	
History:
	2014-04-28	JPB	Created

sp_Equipment_Email_Signature_Received 1074
******************************************************************* */

declare @htmlMessage varchar(max) = ''
	, @textMessage varchar(max) = ''
	, @htmlHeader varchar(max) = ''
	, @textHeader varchar(max) = ''
	, @htmlFooter varchar(max) = ''
	, @textFooter varchar(max) = ''
	, @htmllist varchar(max) = ''
	, @textlist varchar(max) = ''
	, @subject varchar(100)
	, @to varchar(100) = ''
	, @from varchar(100) = ''
	, @link varchar(max) = ''
	, @message_id int
	, @equipment_user_email varchar(100)
	, @equipment_user_name varchar(100)
	, @sign_user_code varchar(20)
	, @sign_name		varchar(60)
	, @sign_title		varchar(60)
	, @sign_email		varchar(60)
	, @sign_phone		varchar(20)
	, @sign_fax		varchar(20)
	, @sign_address	varchar(60)
	, @sign_city		varchar(20)
	, @sign_state		varchar(20)
	, @sign_zip_code	varchar(20)
	, @sign_agree		varchar(1)
	, @sign_ip			varchar(60)
	, @sign_date		datetime
	, @proxy_sign_flag	char(1)
	, @date_added		datetime
	, @added_by		varchar(10)
	, @date_modified	datetime
	, @modified_by		varchar(10)

	select top 1
	@sign_user_code		= sign_user_code
	, @sign_name		= sign_name
	, @sign_title		= sign_title
	, @sign_email		= sign_email
	, @sign_phone		= sign_phone
	, @sign_fax			= sign_fax
	, @sign_address		= sign_address
	, @sign_city		= sign_city
	, @sign_state		= sign_state
	, @sign_zip_code	= sign_zip_code
	, @sign_agree		= sign_agree
	, @sign_ip			= sign_ip
	, @sign_date		= sign_date
	, @proxy_sign_flag	= proxy_sign_flag
	, @date_added		= date_added
	, @added_by			= added_by
	, @date_modified	= date_modified
	, @modified_by		= modified_by
	from EquipmentSignature es
	join EquipmentSetXEquipmentSignature exes on es.signature_id = exes.signature_id
	where exes.equipment_set_id = @equipment_set_id
	
	
select top 1
	@equipment_user_email = es.sign_email
	, @equipment_user_name = es.sign_name
	from EquipmentSignature es
	join EquipmentSetXEquipmentSignature exes on es.signature_id = exes.signature_id
	where exes.equipment_set_id = @equipment_set_id

	set @subject = 'EQ Equipment Sign-Out Confirmation: ' + @equipment_user_name

-- Create the lists of equipment to display:

	set @htmllist = '<table border="0" style="margin-left:10px">'

	select @htmllist = COALESCE(@htmllist, '') + 
		'<tr><td>' + equipment_type + ': </td><td><strong>' + equipment_desc + '</strong></td></tr>' 
	FROM Equipment e
	join EquipmentXEquipmentSet exes on e.equipment_id = exes.equipment_id
	where exes.equipment_set_id = @equipment_set_id
	set @htmllist = @htmllist + '</table>'
	
	select @textlist = COALESCE(@textlist, '') + 
		'* ' + equipment_type + ': ' + equipment_desc + '
' 
	FROM Equipment e
	join EquipmentXEquipmentSet exes on e.equipment_id = exes.equipment_id
	where exes.equipment_set_id = @equipment_set_id


set @htmlHeader = '
<html><style>body {font-family: verdana,sans-serif; font-size: 14px; background-color: #f9f8f3}</style>
<body style="font-family: verdana,sans-serif; font-size: 14px; background-color: #f9f8f3;">
<div style="font-family: LeagueGothicRegular, Helvetica, Geneva, sans-serif; border: solid 1px #000; width: 716px; font-size: 14px; padding: 5px;">
<div style="border-bottom:3px dotted #005395;">
<img src="https://eqonline.com/images/EQC_logo.jpg" height="89" width="88">
<span style="color: #005395; font-size:28px;">EQ Equipment Sign-Out Completed</span>
</div>
'

set @textHeader = '
EQ Equipment Sign-Out Completed

'

set @htmlFooter = '
This is an automated message.  Please do not reply.<br/><br/>
Information Technology Services<br/>
EQ - The Environmental Quality Company.<br/>
http://www.EQOnline.com
</div></body></html>;
'

set @textFooter = '

This is an automated message.  Please do not reply.

Information Technology Services
EQ - The Environmental Quality Company
http://www.EQOnline.com

'

set @htmlMessage = @htmlHeader + '
<p>The following equipment has been electronically signed for:</p>' + @htmlList + '
<p><strong>Signature Information:</strong></p>
<table border="0" style="margin-left:10px">
<tr><td>Date Signed</td><td><strong> ' + CONVERT(varchar(20), @sign_date, 101) + '</strong></td></tr>
<tr><td>Associate Name</td><td><strong> ' + @sign_name + '</strong></td></tr>
<tr><td>Title</td><td><strong> ' + @sign_title + '</strong></td></tr>
<tr><td>Email</td><td><strong> ' + @sign_email + '</strong></td></tr>
<tr><td>Phone</td><td><strong> ' + @sign_phone + '</strong></td></tr>
<tr><td>Address</td><td><strong> ' + @sign_address + '</strong></td></tr>
<tr><td>City</td><td><strong> ' + @sign_city + '</strong></td></tr>
<tr><td>State</td><td><strong> ' + @sign_state + '</strong></td></tr>
<tr><td>Zip Code</td><td><strong> ' + @sign_zip_code + '</strong></td></tr>
<tr><td>IP Address</td><td><strong> ' + @sign_ip + '</strong></td></tr>
</table><br/><br/>

' + @htmlFooter

set @textMessage = @textHeader + '
The following equipment has been electronically signed for:

' + @textList + '


Signature Information:

Date Signed: ' + CONVERT(varchar(20), @sign_date, 101) + '
Associate Name:  ' + @sign_name + '
Title: ' + @sign_title + '
Email: ' + @sign_email + '
Phone: ' + @sign_phone + '
Address: ' + @sign_address + '
City: ' + @sign_city + '
State: ' + @sign_state + '
Zip Code: ' + @sign_zip_code + '
IP Address: ' + @sign_ip + '

' + @textFooter

EXEC @message_id = sp_message_insert @subject, @textMessage, @htmlMessage, 'EQIP', 'EQIP Equipment Sign-Out', NULL, NULL

if ISNULL(@equipment_user_email, '') <> '' BEGIN
	EXEC sp_messageAddress_insert @message_id, 'TO', @equipment_user_email, @equipment_user_name, 'EQ', NULL, NULL, NULL
	EXEC sp_messageAddress_insert @message_id, 'CC', 'IT.Services@eqonline.com', 'IT Services Mailbox', 'EQ', NULL, NULL, NULL
END else 
	EXEC sp_messageAddress_insert @message_id, 'TO', 'IT.Services@eqonline.com', 'IT Services Mailbox', 'EQ', NULL, NULL, NULL

EXEC sp_messageAddress_insert @message_id, 'FROM', 'IT.Services@eqonline.com', 'IT Services Mailbox', 'EQ', NULL, NULL, NULL

insert EquipmentSetXMessage values (@equipment_set_id, @message_id, 'Signature Received', getdate(), convert(varchar(10), SYSTEM_USER))


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Email_Signature_Received] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Email_Signature_Received] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Email_Signature_Received] TO [EQAI]
    AS [dbo];

