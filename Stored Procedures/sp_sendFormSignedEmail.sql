
CREATE PROCEDURE sp_sendFormSignedEmail
	 @form_ID		INT
	,@revision_ID	INT
	,@image_id		INT
	,@source		VARCHAR(30) = 'USEcology.com'
AS
/**************************************************************************
sp_sendFormSignedEmail 

10/08/2012 TMO	Created
02/01/2013 JPB	Added CC of EQ Employees who were cited on links to this form or profile_id that was signed.
04/04/2013 JPB	Revised "Link" logic to only get the 1 most recent EQ employee.  Also added profile_id to the EQ email header when it's available
05/30/2013 JPB	Added Profile.approval_desc to the subjects per GEM:24830
01/14/2016 JPB	Converted from EQ to US Ecology

Example Call:
sp_sendFormSignedEmail form_id , revision_id, image_id

**************************************************************************/

--SET UP VARIABLES FOR STORAGE AND DISPLAY USE LATER
DECLARE  @newMsgId	INT
		,@short_name	VARCHAR(30)
		,@form_name		VARCHAR(60)
		,@document_name	VARCHAR(60)
		,@signer_name	VARCHAR(40)
		,@signer_co		VARCHAR(40)
		,@signer_title	VARCHAR(20)
		,@signer_email	VARCHAR(60)
		,@signer_phone	VARCHAR(20)
		,@signer_fax	VARCHAR(20)
		,@signer_addr	VARCHAR(255)
		,@signer_city	VARCHAR(40)
		,@signer_state	VARCHAR(2)
		,@signer_zip	VARCHAR(15)
		,@customer_id		INT
		,@company_id		INT
		,@profile_id		INT
		,@approval_desc		VARCHAR(50)
		,@profit_center_id	INT
		,@approval_code	 VARCHAR(15)
		,@territory_code VARCHAR(12)
		,@file_name		 VARCHAR(255)
		
--INITIALIZE VARIABLES FOR DISPLAY USE LATER		
SELECT @short_name = FT.short_name,
	   @document_name = FHD.doc_name, 
	   @form_name = FT.form_name 
FROM dbo.FormHeaderDistinct FHD
JOIN dbo.FormType FT ON 
	FHD.type = FT.form_type AND
	FHD.form_version_id = FT.current_form_version
WHERE form_id = @form_id AND revision_id = @revision_ID

SELECT 
	 @signer_name	= sign_name
	,@signer_co		= sign_company
	,@signer_title	= sign_title
	,@signer_email	= sign_email
	,@signer_phone	= sign_phone
	,@signer_fax	= sign_fax
	,@signer_addr	= sign_address
	,@signer_city	= sign_city
	,@signer_state	= sign_state
	,@signer_zip	= sign_zip_code
FROM dbo.FormSignature 
where form_id = @form_id and 
	  revision_id = @revision_id 

SELECT 
	 @customer_id		= customer_id
	,@company_id		= company_id
	,@profile_id		= profile_id
	,@profit_center_id	= profit_ctr_id
	,@approval_code		= approval_code
FROM dbo.formheader
WHERE form_id = @form_id AND
	  revision_id = @revision_id
	  
select @file_name = document_name from plt_image..scan where image_id = @image_id	  

select @approval_desc = approval_desc from profile where profile_id = @profile_id and @profile_id is not null

--if @customer_id is null, set territory code = '??'
IF @customer_id IS NULL 
	SET @territory_code ='????'
	
--if any of the other 4 variables are null, use this smaller query
ELSE IF (@company_id IS NULL OR
		 @profile_id IS NULL OR
		 @profit_center_id IS NULL OR
		 @approval_code IS NULL)

	SELECT 
		@territory_code = dbo.fn_customer_territory_list(@customer_id)

ELSE

	SELECT 
		@territory_code = dbo.fn_customer_territory_list(@customer_id)



-- CREATE THE EMAIL TEXT
DECLARE  @newLine		VARCHAR(4) = CHAR(13) + CHAR(10)
		,@CustPlainBody	VARCHAR(MAX)
		,@CustHtmlBody	VARCHAR(MAX)
			
SET @CustHtmlBody =
'<html><style>body {font-family: verdana,sans-serif; font-size: 14px; background-color: #f9f8f3}</style>
<body style="font-family: verdana,sans-serif; font-size: 14px; background-color: #f9f8f3;">
<div style="font-family: LeagueGothicRegular, Helvetica, Geneva, sans-serif; border: solid 1px #000; width: 716px; font-size: 14px; padding: 5px;">
<div style="border-bottom:3px dotted #005395;">
<img src="https://www.usecology.com/usecobrand/images/us-ecology-logo.png" height="73" width="145">
<span style="color: #005395; font-size:28px;">Electronic Signature Confirmation</span>
</div>
<p>You have just electronically signed:</p>' + 
ISNULL(@form_name, '') + ': ' + ISNULL(@document_name, '') + ' (Form ID: ' + ISNULL(CAST(@form_id AS VARCHAR), '') + ', Revision ' + ISNULL(CAST(@revision_ID AS VARCHAR), '') + ')<br/><br/>
Thank you for doing business electronically with US Ecology. If you have any
questions or problems, feel free to contact Customer Service at (800) 592-5489.<br/><br/>
This is an automated message.  Please do not reply.<br/><br/>
US Ecology.<br/>
http://www.USEcology.com
</div></body></html>'

SET @CustPlainBody = 
'You have just electronically signed:'+ @newLine +
ISNULL(@form_name, '') + ': ' + ISNULL(@document_name, '') + ' (Form ID: ' + ISNULL(CAST(@form_id AS VARCHAR), '') + ', Revision ' + ISNULL(CAST(@revision_ID AS VARCHAR), '') + ')' + @newLine + @newLine +
'Thank you for doing business electronically with US Ecology. If you have any'+
'questions or problems, feel free to contact Customer Service at (800) 592-5489.' + @newLine + @newLine +
'This is an automated message.  Please do not reply.'+ @newLine + @newLine +
'US Ecology.'+ @newLine +
'http://www.USEcology.com'+ @newLine
			

-- SEND THE CUSTOMER EMAIL
BEGIN TRANSACTION CustomerEmail

DECLARE @dateToSend DATETIME = DATEADD( n, 5, GETDATE())

--SET UP THE MESSAGE ITSELF
EXEC 
@newMsgId = dbo.sp_message_insert
				@subject = 'US Ecology Electronic Signature Confirmation', -- varchar(255)
				@message = @CustPlainBody,
				@html = @CustHtmlBody, -- varchar(max)
				@created_by = 'FormSign', -- varchar(10)
				@message_source = @source, -- varchar(30)
				@date_to_send = @dateToSend

--ADD ALL RECIPIENTS AND SENDERS
EXEC sp_messageAddress_insert
	 @message_id	= @newMsgId
	,@address_type	= 'TO'
	,@email			= @signer_email
	,@name			= @signer_name    
    
 
EXEC sp_messageAddress_insert
	 @message_id	= @newMsgId
	,@address_type	= 'From'
	,@email			= 'Customer.Service@usecology.com'
	,@name			= 'US Ecology Customer Service'
	
--ADD ATTACHMENT	
EXEC sp_messageAttachment_insert
	 @message_id		= @newMsgId
	,@attachment_type	= 'Image'
	,@source			= 'ScanImage'
	,@image_id			= @image_id
	,@filename			= @file_name
	,@attachment_id		= 1
	  
COMMIT TRANSACTION CustomerEmail




-- CREATE THE CUSTOMER SERVICE EMAIL TEXT
DECLARE	 @CustSvcSubject	VARCHAR(255)
		,@CustSvcHtmlBody	VARCHAR(MAX)
		,@CustSvcPlainBody	VARCHAR(MAX)

SET @CustSvcSubject = 'Terr: ' + ISNULL(@territory_code, '') + ', Acct: ' + ISNULL(CONVERT(varchar(20), @customer_id), '') +
					  CASE WHEN @profile_id is null then '' else ', Profile: ' + convert(varchar(20), @profile_id) + isnull(' - ' + @approval_desc, '') end +
					  ', Form(s): ' + ISNULL(@short_name + ' ', '') + ISNULL(@document_name + ': Form ID ', '') + ISNULL(CAST(@form_ID AS VARCHAR), '') + ', Revision ' + ISNULL(CAST(@revision_ID AS VARCHAR), '')

SET @CustSvcHtmlBody =
'<html><style>body {font-family: verdana,sans-serif; font-size: 14px; background-color: #f9f8f3}</style>
<body style="font-family: verdana,sans-serif; font-size: 14px; background-color: #f9f8f3;">
<div style="font-family: LeagueGothicRegular, Helvetica, Geneva, sans-serif; border: solid 1px #000; width: 716px; font-size: 14px; padding: 5px;">
<div style="border-bottom:3px dotted #005395;">
<img src="https://www.usecology.com/usecobrand/images/us-ecology-logo.png" height="73" width="145">
<span style="color: #005395; font-size:28px;">Electronic Signature Confirmation</span>
</div>
' + ISNULL(@signer_name, '') + ' has electronically signed:<Br /><Br />' +
ISNULL(@CustSvcSubject, '') + '<Br /><Br />
The following information was used as the signature:<Br />
 Company: ' + ISNULL(@signer_co, '')		+ '<Br />
 Name: '	+ ISNULL(@signer_name, '')	+ '<Br />
 Title: '	+ ISNULL(@signer_title, '')	+ '<Br />
 Email: '	+ ISNULL(@signer_email, '')	+ '<Br />
 Phone: '	+ ISNULL(@signer_phone, '')	+ '<Br />
 Fax: '		+ ISNULL(@signer_fax, '')	+ '<Br />
 Address: ' + ISNULL(@signer_addr, '')	+ '<Br />
 City, State, Zip: ' + ISNULL(@signer_city, '') + ', ' + ISNULL(@signer_state, '') + ', ' + ISNULL(@signer_zip, '') + '<Br /><Br />
A confirmation email was sent to ' + ISNULL(@signer_email, '') + '<Br /><Br />
This is an automated message.  Please do not reply.<br/><br/>
US Ecology.<br/>
http://www.USEcology.com
</div></body></html>'

SET @CustSvcPlainBody = 
ISNULL(@signer_name, '') + ' has electronically signed:' + @newline + @newline + 
ISNULL(@CustSvcSubject, '') + @newline + @newline +
'The following information was used as the signature:' + @newline +
' Company: '	+ ISNULL(@signer_co, '')	+ @newline + 
' Name: '		+ ISNULL(@signer_name, '')	+ @newline + 
' Title: '		+ ISNULL(@signer_title, '')	+ @newline + 
' Email: '		+ ISNULL(@signer_email, '')	+ @newline + 
' Phone: '		+ ISNULL(@signer_phone, '')	+ @newline + 
' Fax: '		+ ISNULL(@signer_fax, '')	+ @newline +
' Address: '	+ ISNULL(@signer_addr, '')	+ @newline + 
' City, State, Zip: '+ ISNULL(@signer_city, '') + ', ' + ISNULL(@signer_state, '') + ', ' + ISNULL(@signer_zip, '') + @newline + @newline +
' A confirmation email was sent to ' + ISNULL(@signer_email, '') + @newline + @newline +
' This is an automated message.  Please do not reply.' + @newline + @newline +
' US Ecology.' + @newline +
' http://www.USEcology.com' + @newline



--SEND THE CUSTOMER SERVICE EMAIL	   
BEGIN TRANSACTION CustSvcEmail

set @dateToSend = DATEADD( n, 5, GETDATE())

--SET UP THE MESSAGE ITSELF
EXEC 
@newMsgId = dbo.sp_message_insert
				@subject = @CustSvcSubject, -- varchar(255)
				@message = @CustSvcPlainBody,
				@html = @CustSvcHtmlBody, -- varchar(max)
				@created_by = 'FormSign', -- varchar(10)
				@message_source = @source, -- varchar(30)
				@date_to_send = @dateToSend

EXEC sp_messageAddress_insert
	 @message_id	= @newMsgId
	,@address_type	= 'TO'
	,@email			= 'Customer.Service@usecology.com'
	,@name			= 'US Ecology Customer Service'  

-- CC any Employees who sent a link to this form and should get notified it's signed.
	INSERT MessageAddress (message_id, address_type, name, company, email)
	SELECT DISTINCT @newMsgId, 'CC', u.user_name, 'US Ecology', u.email
	FROM Users u
	INNER JOIN Link l on (u.user_code = l.added_by or u.email = l.added_by)
	INNER JOIN FormHeader f on (
		(l.form_id = f.form_id and l.link_type = f.type)
		or 
		(l.profile_id = f.profile_id and l.link_type = f.type)
		)
	WHERE f.form_id = @form_ID
	AND f.revision_id = @revision_ID
	AND f.locked = 'L'
	and u.group_id <> 0
	AND u.user_code = (
		SELECT top 1 l1.added_by 
		FROM link l1
		inner join users u1 on l1.added_by = u1.user_code
		where l1.form_id = f.form_id
		order by l1.date_added desc
	)

-- ADD FROM 
EXEC sp_messageAddress_insert
	 @message_id	= @newMsgId
	,@address_type	= 'From'
	,@email			= 'Customer.Service@usecology.com'
	,@name			= 'US Ecology Customer Service'
	
--ADD ATTACHMENT	
EXEC sp_messageAttachment_insert
	 @message_id		= @newMsgId
	,@attachment_type	= 'Image'
	,@source			= 'ScanImage'
	,@image_id			= @image_id
	,@filename			= @file_name
	,@attachment_id		= 1
	  
COMMIT TRANSACTION CustSvcEmail


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sendFormSignedEmail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sendFormSignedEmail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sendFormSignedEmail] TO [EQAI]
    AS [dbo];

