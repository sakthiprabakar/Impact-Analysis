-- =============================================
-- Author:		Senthil Kumar
-- Create date: 13-04-2020
-- Description:	Procedure to validate labpack users
/*
 DECLARE @Message nvarchar(100) 
 EXEC sp_labpack_validate_user 'UesR/nz6BxIho4OHvKOPtuuvuziaTMGjyk3aum53b20=','uSIjm5aTSMb2sMbxntafgg==' ,@Message OUT
 SELECT @Message 
  */
-- =============================================
CREATE PROCEDURE [dbo].[sp_labpack_validate_user]
	-- Add the parameters for the stored procedure here
		@username [varchar](255),
		@password [varchar](255),
		@Message nvarchar(100) Output
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	 IF NOT EXISTS(SELECT * FROM [LabPackUsers] WHERE username=@username)
	BEGIN
		SET @Message = 'User doesn''t exist';
		
	END
    ELSE IF EXISTS(SELECT * FROM [LabPackUsers] WHERE username=@username AND [password]=@password AND isActive=0)
	BEGIN
		SET @Message = 'Sorry, your account is inactive';
		
	END
	ELSE IF EXISTS(SELECT * FROM [LabPackUsers] WHERE username=@username AND [password]=@password AND isActive=1)
	BEGIN
		SET @Message = 'User validated successfully';
		SELECT * FROM [LabPackUsers] WHERE username=@username AND [password]=@password
	END
	ELSE
	BEGIN
		SET @Message = 'Invalid Username/Password';
	END

END
