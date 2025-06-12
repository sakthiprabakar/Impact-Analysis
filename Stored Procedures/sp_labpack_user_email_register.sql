CREATE PROCEDURE [dbo].[sp_labpack_user_email_register] 
	-- Add the parameters for the stored procedure here
	@user_first_name nvarchar(60),
	@user_last_name nvarchar(60),
	@user_email nvarchar(100)	
AS

/*
	Author		:	Senthil Kumar
	CreatedOn	:	July 22, 2020
	Object Name	:	sp_labpack_user_email_register
	
	Exec Stmt	: 	exec [sp_labpack_user_email_register] 'Senthil', 'Kumar', 'senthilkumar.i@optisolbusiness.com'
*/

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	declare @web_userid nvarchar(60) = 'LabPack',
	@subject nvarchar(300) = 'LPx New User Registration'


	declare @contacts table
	(
		first_name nvarchar(60),
		last_name nvarchar(60),
		email nvarchar(100)		
	)
	 
	insert into @contacts values
					('Narayanan', 'B', 'Narayanan.b@optisolbusiness.com'),
					('Reegan', 'Lourduraj', 'Reegan.l@optisolbusiness.com'),
					('Ragavendran', 'S', 'ragavendran.s@optisolbusiness.com'),
					('Senthil', 'kumar', 'senthilkumar.i@optisolbusiness.com')
					

		declare @first_name nvarchar(60),
			@last_name nvarchar(60),
			@email nvarchar(100),
			@body nvarchar(max)='<img src=https://cor2.usecology.com/assets/images/logo-usec.png alt=''logo'' /><BR><BR/><BR/><BR/><BR/>User '+ @user_first_name +' '+ @user_last_name +' with e-mail id '+@user_email+' has registered to use Labpack application.  Please arrange to activate the account, if this is a valid registration. <BR><BR/>Have a great day! <BR><BR/><BR><BR/><img src=https://cor2.usecology.com/assets/images/footer-usec.png alt=''logo'' />'

			

		declare @message_id int 
			exec @message_id = sp_message_insert  @subject, @body , @body, @web_userid, 'USEcology.com', NULL, NULL, NULL
			exec sp_messageAddress_insert @message_id, 'FROM', 'labpack@usecology.com', 'US Ecology LabPack', NULL, NULL, NULL, NULL

		DECLARE user_cursor CURSOR FOR     
			SELECT first_name, last_name, email    
			FROM @contacts  
  
			OPEN user_cursor    
  
			FETCH NEXT FROM user_cursor     
			INTO @first_name, @last_name, @email   
		
			WHILE @@FETCH_STATUS = 0    
			BEGIN    			
				declare @fullname nvarchar(150)	
				set @fullname =  @first_name + ' ' + @last_name									
				exec sp_messageAddress_insert @message_id, 'TO', @email, @fullname, NULL, NULL, NULL, NULL
      
			FETCH NEXT FROM user_cursor     
			INTO @first_name, @last_name, @email 
   
			END     
		CLOSE user_cursor;    
		DEALLOCATE user_cursor;    

		return 0;
	
END

