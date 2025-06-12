-- =============================================
-- Author:		Senthil Kumar
-- Create date: 13-04-2020
-- Description:	Procedure to insert labpack users

--DECLARE @Message nvarchar(100) 
--EXEC sp_labpack_user_registration '5f8f80abeaa4a31ca5d23d6a25dba7eb','835868cb1fdc704f5e827c97aa02b8cb','','','Seth','Whalley','','Manager, National Lab Pack Program - D','National',@Message OUT
--SELECT @Message as message
-- =============================================
CREATE PROCEDURE [dbo].[sp_labpack_user_registration]
	@username [varchar](255),
	@password [varchar](255),
	@phone [varchar](20),
	@role [varchar](20),
	@firstname [varchar](60),
	@lastname [varchar](60),
	@middlename [varchar](60),
	@jobdesciption [varchar](255),
	@location [varchar](255),
	@emailid [varchar](255)=NULL,
	@Message nvarchar(100) Output
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE
	@subject NVARCHAR(300) = 'LPx user registration',
	@body NVARCHAR(max)

	IF NOT EXISTS(SELECT * FROM [LabPackUsers] WHERE username=@username)
	BEGIN
		INSERT INTO [LabPackUsers] VALUES
		(@username,@password,@role,@jobdesciption,@location,@phone,@firstname,@lastname,@middlename,0,GETDATE(),GETDATE())

		
		SET @body='<img src=https://cor2.usecology.com/assets/images/logo-usec.png alt=''logo'' /><BR><BR/><BR/><BR/> <BR/>Dear '+@firstname +' '+ @lastname +','+'<BR/><BR/>Your registration to use Labpack application has been successful. Your account will be made active and notified via e-mail, after the account is activated.<BR><BR/>Have a great day! <BR><BR/><BR><BR/><img src=https://cor2.usecology.com/assets/images/footer-usec.png alt=''logo'' />'
		
		IF(ISNULL(@emailid,'')<>'')
		BEGIN
			EXEC sp_labpack_user_email_register @firstname,@lastname,@emailid
			EXEC [sp_labpack_email_notify] @firstname,@lastname,@emailid,@subject,@body
		END
		SET @Message = 'User registered successfully';
	END
	ELSE
	BEGIN
		SET @Message = 'User alread exist';
	END
	--SELECT @Message as [Message]
    
END

