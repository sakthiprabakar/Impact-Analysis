CREATE PROCEDURE [dbo].[sp_labpack_user_activation]
	@encryptedEmailId [varchar](255),
	@emailid [varchar](255),
	@activestatus bit,
	@Message nvarchar(100) Output
AS
-- =============================================
-- Author:		Senthil Kumar
-- Create date: 23-07-2020
-- Description:	Procedure to activate labpack users

--DECLARE @Message nvarchar(100) 
--EXEC sp_labpack_user_activation '8HqLbX9Ay6JogUITYtgq8k+2Qhnvupcbv+7b8wBYNSFCsUW+TQITmcn1L1WAEmrF','senthilkumar.i@optisolbusiness.com',1,@Message OUT
--SELECT @Message as message
-- =============================================
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	DECLARE @first_name varchar(60),
	@last_name varchar(60),
	@subject NVARCHAR(300) = 'LPx account activation',
	@body NVARCHAR(max)
	SET NOCOUNT ON;
	IF EXISTS(SELECT * FROM [LabPackUsers] WHERE username=@encryptedEmailId)
	BEGIN
		SELECT @first_name=firstname,@last_name=lastname FROM [LabPackUsers] WHERE username=@encryptedEmailId

		SET @body='<img src=https://cor2.usecology.com/assets/images/logo-usec.png alt=''logo'' /><BR><BR/><BR/><BR/> <BR/>Dear '+@first_name +' '+ @last_name +','+'<BR/><BR/>Your Labpack account has been activated successfully.  Login with the credentials used at the time of registration, to use the application. <BR><BR/>Have a great day! <BR><BR/><BR><BR/><img src=https://cor2.usecology.com/assets/images/footer-usec.png alt=''logo'' />'
		

		UPDATE [LabPackUsers] SET isactive=@activestatus ,date_modified=GETDATE()WHERE username=@encryptedEmailId
		EXEC [sp_labpack_email_notify] @first_name,@last_name,@emailid,@subject,@body
		SET @Message = 'User activated successfully';
	END
	ELSE
	BEGIN
		SET @Message = 'User doesn''t exist';
	END
	
    
END

