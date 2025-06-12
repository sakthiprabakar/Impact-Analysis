-- =============================================
-- Author:		Rob Briggs
-- Create date: 22-04-2020
-- Description:	Procedure to email password to a labpack user

--select * from LabPackUsers
--declare @Message varchar(255) exec sp_labpack_user_email_password 'Rob.Briggs@usecology.com', 'password', @Message OUT print @Message
-- =============================================
CREATE PROCEDURE [dbo].[sp_labpack_user_email_password]
	@emailid  [varchar](255),
	@password [varchar](255),
	@Message  nvarchar(100) Output
AS
BEGIN
	DECLARE @message_id int,
	@subject			VARCHAR(255) = 'LabPack Password'
	,@msg				VARCHAR(MAX)
	,@created_by		VARCHAR(10) = 'LabPack'
	,@message_source	VARCHAR(30) = 'USEcology.com'
	,@date_to_send		DATETIME	= dateadd(minute,1,getdate())
	,@from_address		VARCHAR(20) = 'LabPack@USEcology.com'

	SET NOCOUNT ON

	SET @msg = 'Your current LabPack password is: ' + @password

	exec @message_id = dbo.sp_message_insert @subject, @msg, @msg, @created_by, @message_source, @date_to_send
	IF @@ERROR <> 0
	BEGIN
		SET @Message = 'An error occured calling sp_message_insert'
	END
	ELSE
	BEGIN
		exec dbo.sp_messageAddress_insert @message_id, 'FROM', @from_address, @created_by
		IF @@ERROR <> 0
		BEGIN
			SET @Message = 'An error occured calling sp_messageAddress_insert for FROM address'
		END
		ELSE
		BEGIN
			exec dbo.sp_messageAddress_insert @message_id, 'TO', @emailid, @created_by
			IF @@ERROR <> 0
			BEGIN
				SET @Message = 'An error occured calling sp_messageAddress_insert for TO address'
			END
			ELSE
			BEGIN
				SET @Message = 'Email successfully sent'
			END
		END
	END

	SELECT @Message as [Message]
END