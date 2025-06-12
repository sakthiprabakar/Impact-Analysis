
create proc sp_Equipment_Email_Signature_Required (
	@equipment_set_id		int
	, @resend_flag			int = 0			-- 1 = Yes, we're re-sending.
)
as
/* *******************************************************************
sp_Equipment_Email_Signature_Required

	Sends email to the equipment user for a set of equipment
	
History:
	2014-04-25	JPB	Created

sp_Equipment_Email_Signature_Required 1000
******************************************************************* */

declare @htmlMessage varchar(max) = ''
	, @textMessage varchar(max) = ''
	, @htmlHeader varchar(max) = ''
	, @textHeader varchar(max) = ''
	, @htmlFooter varchar(max) = ''
	, @textFooter varchar(max) = ''
	, @htmllist varchar(max) = ''
	, @textlist varchar(max) = ''
	, @subject varchar(100) = 'EQ Equipment Acknowledgment Required'
	, @to varchar(100) = ''
	, @from varchar(100) = ''
	, @link varchar(max) = ''
	, @message_id int
	, @equipment_user_email varchar(100)
	, @equipment_user_name varchar(100)

select top 1
	@equipment_user_email = u.email
	, @equipment_user_name = u.user_name
	from users u
	inner join EquipmentSet es on es.user_code = u.user_code
	where es.equipment_set_id = @equipment_set_id


select @link = url_snippet from EquipmentSet where equipment_set_id = @equipment_set_id

-- Create the lists of equipment to display:

	set @htmllist = '<table border="0" style="margin-left:10px">'

	select @htmllist = COALESCE(@htmllist, '') + 
		'<tr><td>' + equipment_type + ':</td><td><strong>' + equipment_desc + '</strong></td></tr>' 
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
<span style="color: #005395; font-size:28px;">EQ Equipment Sign-Out Required</span>
</div>
'

set @textHeader = '
EQ Equipment Sign-Out Required

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

set @htmlMessage = @htmlHeader +
	CASE @resend_flag WHEN 0 then '
<p>You have recently been assigned the following equipment which requires a confirmation.</p>
' else '<p>This is a reminder that we have not received your acknowledgement for this equipment:</p>'
end + @htmlList + '
<p>When you receive your equipment, please click on the link below to review and electronically acknowledge receipt.</p>
<p style="margin-left:10px">' + @link + '</p>
<p>Use of EQ equipment is confirmation of acceptance of the following terms:</p>
<ul>
<li>
I understand and agree that in the event of my termination from EQ-The Environmental Quality Company, 
I will return to EQ all materials and equipment listed above by the date indicated on the HR 
Termination letter.
</li>
<li>
I further understand and agree that all data and information, such as price lists or other specialized 
or confidential information, contained on disks, hardcopy, external storage devices or in the equipment 
list above, will be returned to EQ at the same time.
</li>
<li>
I agree that I have read and acknowledge that I will follow the rules of use for equipment as stated in 
the EQ Associate Handbook and that I will store all EQ documents and personal documents in the specified 
directories provided.
</li>
<li>
I acknowledge that I have already agreed to maintain the confidentiality of company information as contained 
in the Market & Business Protection Agreements that I have previously signed with the company.
</li>
</ul>
<p>If you have any questions or concerns, please contact EQ IT at (734) 329-8057.</p>
' + @htmlFooter


set @textMessage = @textHeader +
	CASE @resend_flag WHEN 0 then '
You have recently been assigned the following equipment which requires a confirmation.

' else '
This is a reminder that we have not received your acknowledgement for this equipment:

'
end + @textList + '
When you receive your equipment, please click on the link below to review and electronically acknowledge receipt.

' + @link + '

Use of EQ equipment is confirmation of acceptance of the following terms:

* I understand and agree that in the event of my termination from EQ-The Environmental Quality Company, I will return to EQ all materials and equipment listed above by the date indicated on the HR Termination letter.

* I further understand and agree that all data and information, such as price lists or other specialized or confidential information, contained on disks, hardcopy, external storage devices or in the equipment list above, will be returned to EQ at the same time.

* I agree that I have read and acknowledge that I will follow the rules of use for equipment as stated in the EQ Associate Handbook and that I will store all EQ documents and personal documents in the specified directories provided.

* I acknowledge that I have already agreed to maintain the confidentiality of company information as contained in the Market & Business Protection Agreements that I have previously signed with the company.

If you have any questions or concerns, please contact EQ IT at (734) 329-8057.
' + @textFooter


EXEC @message_id = sp_message_insert @subject, @textMessage, @htmlMessage, 'EQIP', 'EQIP Equipment Sign-Out', NULL, NULL

if ISNULL(@equipment_user_email, '') <> ''
	EXEC sp_messageAddress_insert @message_id, 'TO', @equipment_user_email, @equipment_user_name, 'EQ', NULL, NULL, NULL
else 
	EXEC sp_messageAddress_insert @message_id, 'TO', 'IT.Services@eqonline.com', 'IT Services Mailbox', 'EQ', NULL, NULL, NULL

EXEC sp_messageAddress_insert @message_id, 'FROM', 'IT.Services@eqonline.com', 'IT Services Mailbox', 'EQ', NULL, NULL, NULL

insert EquipmentSetXMessage values (@equipment_set_id, @message_id, 'Signature Required', getdate(), convert(varchar(10), SYSTEM_USER))




GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Email_Signature_Required] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Email_Signature_Required] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Email_Signature_Required] TO [EQAI]
    AS [dbo];

