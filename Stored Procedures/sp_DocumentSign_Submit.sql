
CREATE PROCEDURE [dbo].[sp_DocumentSign_Submit]
	-- Add the parameters for the stored procedure here
	@formId int,
	@revisionId int,
	@web_userid NVARCHAR(150),
	@date_signed nvarchar(100) = null
AS


/***********************************************************************************

	Author		: Dinesh kumar
	Updated On	: Jan 8th, 2019
	Type		: Stored Procedure 
	Object Name	: [dbo].[sp_DocumentSign_Submit]
	Description	: FormWCR Status update as Submitted


	Description	: 
				for updating the Form Status as Submitted after Sign & Submit, Send & Submit and Submit

	Input		:
				@formId,
				@revisionId
				@web_userid

								
	Execution Statement	: 
						EXEC sp_DocumentSign_Submit @formId, @revisionId,@web_userid
						EXEC sp_DocumentSign_Submit 432588,1,'nyswyn100'
	

*************************************************************************************/

BEGIN
	BEGIN TRY
		-- SET NOCOUNT ON added to prevent extra result sets from
		-- interfering with SELECT statements.
		SET NOCOUNT ON;

		DECLARE @i_signed_Date DateTime2 = null
		
		IF(ISNULL(@date_signed, '') = '')
		BEGIN
			SET @i_signed_Date = GETDATE()
		END
		ELSE
		BEGIN
			SET @i_signed_Date = cast(@date_signed as datetime2)
		END

		DECLARE @display_status_uid INT=(SELECT display_status_uid FROM FormDisplayStatus Where display_status = 'Submitted')
		UPDATE [dbo].[FormWCR] SET [display_status_uid]= @display_status_uid,
			signing_date = @i_signed_Date,
			date_modified = GETDATE(),
			--case when @date_signed is null or @date_signed = '' then GETDATE() else  cast(@date_signed as datetime2) end,
			[submitted_by]=@web_userid,[date_submitted]= @i_signed_Date
			--case when @date_signed is null or @date_signed = '' then GETDATE() else  cast(@date_signed as datetime2) end
		WHERE [form_id]=@formId AND [revision_id]=@revisionId

		UPDATE [Plt_AI]..FormSignatureQueue SET date_modified = GETDATE() WHERE [form_id]=@formId AND [revision_id]=@revisionId
	
		-- Track form history status
		 EXEC [sp_FormWCRStatusAudit_Insert] @formId,@revisionId,@display_status_uid ,@web_userid

		 -- EXEC sp_document_insert_update NULL, @formId, @revisionId
	END TRY
	BEGIN CATCH
		INSERT INTO COR_DB.DBO.ErrorLogs(ErrorDescription,[Object_Name],Web_user_id,CreatedDate)
					VALUES('FormID: ' + convert(nvarchar(10), @formId) + '-' + convert(nvarchar(10), @revisionId) 
					+ '--> Signed Date: ' + isnull(@date_signed, '')
					+ '--> Description :: ' + Error_Message(), ERROR_PROCEDURE(),@web_userid,GETDATE())

	declare @recipient nvarchar(60), 
			@first_name nvarchar(60), 
			@last_name nvarchar(60), 
			@full_name nvarchar(100),
			@subject nvarchar(200) = 'COR2 Form Submission Failure - Form ID:' + convert(nvarchar(10), @formId)
 	
	select TOP 1 @recipient = recipient_email, @first_name = recipient_first_name, @last_name = recipient_last_name,
				 @full_name = recipient_first_name + ' ' + recipient_last_name
	 from FormSignatureQueue WHERE [form_id]=@formId AND [revision_id]=@revisionId  order by date_modified desc

	declare @message_id int 
	exec @message_id = sp_message_insert  @subject, 'Oops, something went wrong.  Please locate the form in Forms & Profile - Pending and resubmit.', '', @web_userid, 'COR', NULL, NULL, NULL
	exec sp_messageAddress_insert @message_id, 'FROM', 'Cor@usecology.com', 'US Ecology Customer Service', NULL, NULL, NULL, NULL
	exec sp_messageAddress_insert @message_id, 'TO', @recipient, @full_name, NULL, NULL, NULL, NULL

	declare @profile_id  int = (select profile_id from formwcr where form_id=@formId and revision_id=@revisionId)

	update BulkRenewProfile set status='completed' where status in ('pending', 'validated') and profile_id =  @profile_id

		
	END CATCH

END

GO

	GRANT EXEC ON [dbo].[sp_DocumentSign_Submit] TO COR_USER;

GO


