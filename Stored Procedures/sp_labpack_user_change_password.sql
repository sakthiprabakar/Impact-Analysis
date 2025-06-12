-- =============================================
-- Author:		Rob Briggs
-- Create date: 13-04-2020
-- Description:	Procedure to change labpack user password

--select * from LabPackUsers
--declare @Message varchar(255) exec sp_labpack_user_change_password '751d460df7c69a502358144db487d7aa', 'password', @Message OUT print @Message
--declare @Message varchar(255) exec sp_labpack_user_change_password '751d460df7c69a502358144db487d7aa', 'da0293a14fd075ec2f17770fce3ab3dd', @Message OUT print @Message
-- =============================================
CREATE PROCEDURE [dbo].[sp_labpack_user_change_password]
	@username [varchar](255),
	@password [varchar](255),
	@Message nvarchar(100) Output
AS
BEGIN
	DECLARE @err int, @rc int

	UPDATE [LabPackUsers]
	SET password = @password
	WHERE username = @username

	SELECT @err = @@ERROR, @rc = @@ROWCOUNT

	IF @err <> 0
		SET @Message = 'An error occured when attempting to update password'

	ELSE IF @rc < 1
		SET @Message = 'Username doesn''t exist, password not updated'

	ELSE
		SET @Message = 'Password successfully updated'

	SELECT @Message as [Message]
END