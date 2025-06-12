
CREATE PROCEDURE sp_forms_wcr_sendlink
	@linkID varchar(255),
	@toAddress varchar(255),
	@name varchar(255) = NULL,
	@server varchar(30) = NULL
AS
/*********************************************************************************
sp_forms_wcr_sendlink '460738134247056','jonathan.broome@eqonline.com','testname','dev'
select * from link where form_id = 217533

	SELECT TOP 1 
		isnull(FormWCR.waste_common_name, ''),
		isnull(FormWCR.form_id, 0),
		isnull(convert(varchar(20), FormWCR.form_id), ''),
		isnull(FormWCR.revision_id, 0),
		isnull(FormWCR.gen_process, ''),
		isnull(convert(varchar(20), FormWCR.tracking_id), ''),
		isnull(FormWCR.generator_name, ''),
		isnull(dbo.fn_format_epa_id(FormWCR.epa_id), ''),
		isnull(FormWCR.generator_city, ''),
		isnull(FormWCR.generator_state, '')
	FROM dbo.FormWCR 
	INNER JOIN dbo.Link ON link.form_id = formwcr.form_id 
	WHERE link.url_id = '460738134247056' 
	ORDER BY revision_id DESC

SELECT top 10 l.url_id, w.* FROM FormWCR w
inner join Link l on w.form_id = l.form_id where isnull(generator_name, '') <> '' 
and not exists (select 1 from formwcr where form_id = w.form_id and revision_id > w.revision_id)
order by w.form_id desc

SELECT  * FROM Link where url_id = '148523040481449'
SELECT  * FROM FormWCR where form_id = 217346


*********************************************************************************/

-- Define message content, subject - with slugs for replacing with detail:
	DECLARE @htmlbody varchar(max), @textbody varchar(max), @subject varchar(100)
	
	-- Don't indent the *body fields, or the emails will look bad.
	select 
		@subject = 'Waste Profile Link ([WASTENAME])',
@htmlbody = '
<html><style>body {font-family: verdana,sans-serif; font-size: 14px; background-color: #f9f8f3}</style><body style="font-family: verdana,sans-serif; font-size: 14px; background-color: #f9f8f3;">
<div style="font-family: LeagueGothicRegular, Helvetica, Geneva, sans-serif; border: solid 1px #000; width: 716px; font-size: 14px; padding: 5px;">
<div style="border-bottom:3px dotted #005395;">
<img src="http://eqonline.com/images/EQC_logo.jpg" height="89" width="88">
<span style="color: #005395; font-size:28px;">Waste Profile Link</span>
</div>

<p>Your profile was just saved to EQ''s website.</p>
[DETAILTABLEHTML]
<p>To view or edit the profile, please use the link below.</p>

<p><a href="[LINKURL]">[LINKTEXT]</a></p>

<p>If you have any questions or problem using this link or the EQOnline Forms system contact EQ''s IT staff for help at <a href="mailto:webmaster@eqonline.com">webmaster@eqonline.com</a>.</p>

</div>
</body></html>
'
,
@textbody = '
Your profile was just saved to EQ''s website.
[DETAILTABLETEXT]
To view or edit the profile, please use the link below.

[LINKURL]

If you have any questions or problem using this link or the EQOnline Forms system contact EQ''s IT staff for help at webmaster@eqonline.com .

'

-- set slug and other variable values:
	IF(@name is null)
		SET @name = @toAddress

	IF(@server IS NULL OR @server = 'prod' OR @server = 'production')
		SET @server = ''
	ELSE
		SET @server = @server + '.'

	IF (isnull(@server,'') IN ('', '.')) BEGIN
		SET @server = replace(@@servername, 'NTSQL1', '') + '.'
		IF @server = '.' set @server = 'www.'
	END		
		
	DECLARE
		@revision_id		int,
		@form_id			int,
		@wastename			varchar(100) = '',
		@generator_name		varchar(100) = '',
		@epa_id				varchar(20) = '',
		@generator_city		varchar(100) = '',
		@generator_state	varchar(100) = '',
		@generating_process varchar(max) = '',
		@form_id_text		varchar(20) = '',
		@tracking_id		varchar(20) = '',
		@linkurl			varchar(200) = '',
		@linktext			varchar(100) = '',
		@detailtablehtml	varchar(max) = '',
		@detailtablehead	varchar(max) = '<table border="0">',
		@detailtablefoot	varchar(max) = '</table>',
		@detailtabletext	varchar(max) = '',
		@crlf				varchar(5) = CHAR(13) + CHAR(10)

	SELECT TOP 1 
		@wastename			= rtrim(ltrim(isnull(FormWCR.waste_common_name, ''))),
		@form_id			= isnull(FormWCR.form_id, 0),
		@form_id_text		= rtrim(ltrim(isnull(convert(varchar(20), FormWCR.form_id), ''))),
		@revision_id		= isnull(FormWCR.revision_id, 0),
		@generating_process	= rtrim(ltrim(isnull(convert(varchar(max), FormWCR.gen_process), ''))),
		@tracking_id		= rtrim(ltrim(isnull(convert(varchar(20), FormWCR.tracking_id), ''))),
		@generator_name		= rtrim(ltrim(isnull(FormWCR.generator_name, ''))),
		@epa_id				= rtrim(ltrim(isnull(dbo.fn_format_epa_id(FormWCR.epa_id), ''))),
		@generator_city		= rtrim(ltrim(isnull(FormWCR.generator_city, ''))),
		@generator_state	= rtrim(ltrim(isnull(FormWCR.generator_state, '')))
	FROM dbo.FormWCR 
	INNER JOIN dbo.Link ON link.form_id = formwcr.form_id 
	WHERE link.url_id = @linkID 
	ORDER BY revision_id DESC
	
	SET @linkurl = 'http://'+@server+'eqonline.com/f/?'+ CAST(@linkID as varchar)
	
	SET @linktext = @linkurl
	
	if isnull(@form_id_text, '') <> ''
		SELECT 
			@detailtablehtml = @detailtablehtml + 	
				'<tr><th style="text-align:right">Form ID: </th><td>'  + @form_id_text + '</td></tr>',
			@detailtabletext = @detailtabletext +
				'Form ID        : ' + @form_id_text + @crlf

	if isnull(@wastename, '') <> ''
		SELECT 
			@detailtablehtml = @detailtablehtml + 	
				'<tr><th style="text-align:right">Waste Name: </th><td>'  + @wastename + '</td></tr>',
			@detailtabletext = @detailtabletext +
				'Waste Name     : ' + @wastename + @crlf

	if isnull(@generating_process, '') <> ''
		SELECT 
			@detailtablehtml = @detailtablehtml + 	
				'<tr><th style="text-align:right">Gen. Process: </th><td>'  + @generating_process + '</td></tr>',
			@detailtabletext = @detailtabletext +
				'Gen. Process   : ' + @generating_process + @crlf


	if isnull(@tracking_id, '') <> ''
		SELECT 
			@detailtablehtml = @detailtablehtml + 	
				'<tr><th style="text-align:right">Tracking ID: </th><td>'  + @tracking_id + '</td></tr>',
			@detailtabletext = @detailtabletext +
				'Tracking ID    : ' + @tracking_id + @crlf

	if isnull(@generator_name, '') <> ''
		SELECT 
			@detailtablehtml = @detailtablehtml + 	
				'<tr><th style="text-align:right">Generator: </th><td>'  + @generator_name + '</td></tr>',
			@detailtabletext = @detailtabletext +
				'Generator      : ' + @generator_name + @crlf

	if isnull(@epa_id, '') <> ''
		SELECT 
			@detailtablehtml = @detailtablehtml + 	
				'<tr><th style="text-align:right">EPA ID: </th><td>'  + @epa_id + '</td></tr>',
			@detailtabletext = @detailtabletext +
				'EPA ID         : ' + @epa_id + @crlf

	if isnull(@generator_city, '') <> ''
		SELECT 
			@detailtablehtml = @detailtablehtml + 	
				'<tr><th style="text-align:right">Generator City: </th><td>'  + @generator_city + '</td></tr>',
			@detailtabletext = @detailtabletext +
				'Generator City : ' + @generator_city + @crlf

	if isnull(@generator_state, '') <> ''
		SELECT 
			@detailtablehtml = @detailtablehtml + 	
				'<tr><th style="text-align:right">Generator ST: </th><td>'  + @generator_state + '</td></tr>',
			@detailtabletext = @detailtabletext +
				'Generator ST   : ' + @generator_state + @crlf

	if @detailtablehtml <> '' set @detailtablehtml = @detailtablehead + @detailtablehtml + @detailtablefoot

-- Replace slug values in the subject, content	
	-- [WASTENAME] = @wastename
	select 
		@subject = replace(@subject, '[WASTENAME]', @wastename),
		@htmlbody = replace(@htmlbody, '[WASTENAME]', @wastename),
		@textbody = replace(@textbody, '[WASTENAME]', @wastename)

	-- [LINKURL] = @linkurl
	select 
		@subject = replace(@subject, '[LINKURL]', @linkurl),
		@htmlbody = replace(@htmlbody, '[LINKURL]', @linkurl),
		@textbody = replace(@textbody, '[LINKURL]', @linkurl)

	-- [LINKTEXT] = @linktext
	select 
		@subject = replace(@subject, '[LINKTEXT]', @linktext),
		@htmlbody = replace(@htmlbody, '[LINKTEXT]', @linktext),
		@textbody = replace(@textbody, '[LINKTEXT]', @linktext)

	-- [DETAILTABLETEXT] = @detailtabletext
	select 
		@subject = replace(@subject, '[DETAILTABLETEXT]', @detailtabletext),
		@htmlbody = replace(@htmlbody, '[DETAILTABLETEXT]', @detailtabletext),
		@textbody = replace(@textbody, '[DETAILTABLETEXT]', @detailtabletext)

	-- [DETAILTABLEHTML] = @detailtablehtml
	select 
		@subject = replace(@subject, '[DETAILTABLEHTML]', @detailtablehtml),
		@htmlbody = replace(@htmlbody, '[DETAILTABLEHTML]', @detailtablehtml),
		@textbody = replace(@textbody, '[DETAILTABLEHTML]', @detailtablehtml)

DECLARE @message_id int
execute @message_id = sp_sequence_next 'message.message_id'

	INSERT INTO [dbo].[Message]
           ([message_id]
           ,[status]
           ,[message_type]
           ,[message_source]
           ,[subject]
           ,[message]
           ,[added_by]
           ,[date_added]
           ,[modified_by]
           ,[date_modified]
           ,[date_to_send]
           ,[date_delivered]
           ,[error_description]
           ,[html])
     VALUES
           (@message_id
           ,'N'
           ,'E'
           ,'EQOnline'
           ,@subject
           ,@textbody
           ,'SYS'
           ,getdate()
           ,'SYS'
           ,getdate()
           ,NULL
           ,NULL
           ,NULL
           ,@htmlbody
			)
 
    INSERT INTO [dbo].[MessageAddress]
           ([message_id]
           ,[address_type]
           ,[name]
           ,[company]
           ,[department]
           ,[email]
           ,[fax]
           ,[phone])
     VALUES
           (@message_id
           ,'FROM'
           ,'EQ Online'
           ,'EQ - The Environmental Quality Company'
           ,NULL
           ,'webmaster@eqonline.com'
           ,NULL
           ,NULL)
           
    INSERT INTO [dbo].[MessageAddress]
           ([message_id]
           ,[address_type]
           ,[name]
           ,[company]
           ,[department]
           ,[email]
           ,[fax]
           ,[phone])
     VALUES
           (@message_id
           ,'TO'
           ,@name
           ,NULL
           ,NULL
           ,@toAddress
           ,NULL
           ,NULL)
           
           INSERT INTO dbo.LinkTo
                   ( url_id, email, name, rowguid )
           VALUES  ( @linkID, -- url_id - varchar(15)
                     @toAddress, -- email - varchar(60)
                     NULL, -- name - varchar(40)
                     NEWID()  -- rowguid - uniqueidentifier
                     )

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_sendlink] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_sendlink] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_wcr_sendlink] TO [EQAI]
    AS [dbo];

