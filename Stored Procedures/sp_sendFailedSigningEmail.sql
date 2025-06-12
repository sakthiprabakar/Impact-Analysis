
CREATE PROCEDURE sp_sendFailedSigningEmail
	 @form_ID		INT
	,@revision_ID	INT
	,@image_id		INT
	,@source		VARCHAR(30) = 'USEcology.com'
AS
/**************************************************************************
sp_sendFailedSigningEmail 

10/11/2012 TMO	Created

Example Call:
sp_sendFailedSigningEmail form_id , revision_id, image_id
**************************************************************************/

--SET UP VARIABLES FOR STORAGE AND DISPLAY USE LATER
DECLARE  @newMsgId			INT
		,@signer_name		VARCHAR(40)
		,@signer_co			VARCHAR(40)
		,@signer_email		VARCHAR(60)
		,@profile_id		INT
		,@profit_center_id	INT
		,@approval_code		VARCHAR(15)
		,@form_type			VARCHAR(10)
		,@form_version_id	INT
		
--INITIALIZE VARIABLES FOR DISPLAY USE LATER		

SELECT 
	 @signer_name	= sign_name
	,@signer_co		= sign_company
	,@signer_email	= sign_email
FROM dbo.FormSignature 
where form_id = @form_id and 
	  revision_id = @revision_id 

SELECT 
	 @profile_id		= profile_id
	,@profit_center_id	= profit_ctr_id
	,@approval_code		= approval_code
	,@form_type			= type
	,@form_version_id	= form_version_id
FROM dbo.formheader
WHERE form_id = @form_id AND
	  revision_id = @revision_id

-- CREATE THE CUSTOMER SERVICE EMAIL TEXT
DECLARE	 @newLine			VARCHAR(4) = CHAR(13) + CHAR(10)
		,@CustSvcHtmlBody	VARCHAR(MAX)
		,@CustSvcPlainBody	VARCHAR(MAX)


SET @CustSvcHtmlBody =
'<html><style>body {font-family: verdana,sans-serif; font-size: 14px; background-color: #f9f8f3}</style>
<body style="font-family: verdana,sans-serif; font-size: 14px; background-color: #f9f8f3;">
<div style="font-family: LeagueGothicRegular, Helvetica, Geneva, sans-serif; border: solid 1px #000; width: 716px; font-size: 14px; padding: 5px;">
<div style="border-bottom:3px dotted #005395;">
<img src="https://www.usecology.com/usecobrand/images/us-ecology-logo.png" height="73" width="145">
<span style="color: #005395; font-size:28px;">US Ecology Electronic Signature Confirmation</span>
</div>
A requested electronic form failed to display.  Details: <br/><br/>
Date/Time: ' + CAST(GETDATE() AS VARCHAR) + '<br/>
Form Type: ' + ISNULL(@form_type, '') + '<br/>
Company  : ' + ISNULL(@signer_co, '') + '<br/>
ProfitCtr: ' + ISNULL(CAST(@profit_center_id AS VARCHAR), '') + '<br/>
Form ID  : ' + ISNULL(CAST(@form_ID AS VARCHAR), '') + '<br/>
Rev. ID  : ' + ISNULL(CAST(@revision_ID AS VARCHAR), '') + '<br/>
FormVer. : ' + ISNULL(CAST(@form_version_id AS VARCHAR), '') + '<br/>
Approval : ' + ISNULL(@approval_code, '') + '<br/>
Profile  : ' + ISNULL(CAST(@profile_id AS VARCHAR), '') + '<br/>
Image ID : ' + ISNULL(CAST(@image_id AS VARCHAR), '') + '<br/>
User     : ' + ISNULL(@signer_name, '') + '<br/>
Email    : ' + ISNULL(@signer_email, '') + '<br/><br/>
This is an automated message.  Please do not reply.<br/><br/>
US Ecology.<br/>
http://www.USEcology.com
</div></body></html>'

SET @CustSvcPlainBody = 
'A requested electronic form failed to display.  Details:' + @newline + @newline +
'Date/Time:' + CAST(GETDATE() AS VARCHAR) + @newline +
'Form Type:' + ISNULL(@form_type, '') + @newline +
'Company  :' + ISNULL(@signer_co, '') + @newline +
'ProfitCtr:' + ISNULL(CAST(@profit_center_id AS VARCHAR), '') + @newline +
'Form ID  :' + ISNULL(CAST(@form_ID AS VARCHAR), '') + @newline +
'Rev. ID  :' + ISNULL(CAST(@revision_ID AS VARCHAR), '') + @newline +
'FormVer. :' + ISNULL(CAST(@form_version_id AS VARCHAR), '') + @newline +
'Approval :' + ISNULL(@approval_code, '') + @newline +
'Profile  :' + ISNULL(CAST(@profile_id AS VARCHAR), '') + @newline +
'Image ID :' + ISNULL(CAST(@image_id AS VARCHAR), '') + @newline +
'User     :' + ISNULL(@signer_name, '') + @newline +
'Email    :' + ISNULL(@signer_email, '') + @newline + @newline +
'This is an automated message.  Please do not reply.' + @newline + @newline +
'US Ecology.' + @newline +
'http://www.USEcology.com' + @newline



--SEND THE CUSTOMER SERVICE EMAIL	   
BEGIN TRANSACTION CustSvcEmail

DECLARE @dateToSend DATETIME = DATEADD( n, 5, GETDATE())

--SET UP THE MESSAGE ITSELF
EXEC 
@newMsgId = dbo.sp_message_insert
				@subject = 'Electronic form failed to display', -- varchar(255)
				@message = @CustSvcPlainBody,
				@html = @CustSvcHtmlBody, -- varchar(max)
				@created_by = 'FormSign', -- varchar(10)
				@message_source = @source, -- varchar(30)
				@date_to_send = @dateToSend

EXEC sp_messageAddress_insert
	 @message_id	= @newMsgId
	,@address_type	= 'TO'
	,@email			= 'webmaster@usecology.com'
	,@name			= 'US Ecology Customer Service'  
     
EXEC sp_messageAddress_insert
	 @message_id	= @newMsgId
	,@address_type	= 'From'
	,@email			= 'webmaster@usecology.com'
	,@name			= 'webmaster@usecology.com'
	  
COMMIT TRANSACTION CustSvcEmail

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sendFailedSigningEmail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sendFailedSigningEmail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sendFailedSigningEmail] TO [EQAI]
    AS [dbo];

