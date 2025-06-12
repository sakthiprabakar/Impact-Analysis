CREATE PROCEDURE [dbo].[sp_labpack_email_notify] 
	-- Add the parameters for the stored procedure here
	@user_first_name NVARCHAR(60),
	@user_last_name NVARCHAR(60),
	@user_email NVARCHAR(100),	
	@subject NVARCHAR(300),
	@body NVARCHAR(max)
AS

/*
	Author		:	Senthil Kumar
	CreatedOn	:	July 22, 2020
	Object Name	:	sp_labpack_email_notify
	
	Exec Stmt	: 	exec [sp_labpack_email_notify] 'Senthil', 'Kumar', 'senthilkumar.i@optisolbusiness.com'
*/

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @web_userid NVARCHAR(60) = 'LabPack',
	@user_full_name NVARCHAR(120)=@user_first_name+' '+@user_last_name,
	@message_id INT 

			EXEC @message_id = sp_message_insert  @subject, @body , @body, @web_userid, 'USEcology.com', NULL, NULL, NULL
			EXEC sp_messageAddress_insert @message_id, 'FROM', 'labpack@usecology.com', 'US Ecology LabPack', NULL, NULL, NULL, NULL
			EXEC sp_messageAddress_insert @message_id, 'TO', @user_email, @user_full_name, NULL, NULL, NULL, NULL
	 
		return 0;
END

