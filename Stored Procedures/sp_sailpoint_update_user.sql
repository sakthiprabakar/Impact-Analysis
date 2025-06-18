CREATE OR ALTER PROCEDURE [dbo].[sp_sailpoint_update_user]
    @user_id INT,
    @user_code VARCHAR(100),
    @group_id INT,
    @user_name VARCHAR(40) = NULL,
	@first_name varchar(20) = NULL,
	@last_name varchar(20) = NULL,
    @title VARCHAR(100) = NULL,
    @addr1 VARCHAR(40) = NULL,
    @addr2 VARCHAR(40) = NULL,
    @addr3 VARCHAR(40) = NULL,
    @email VARCHAR(80) = NULL,
	@upn varchar(100),
	@employee_id varchar(20),
    @modified_by VARCHAR(8),
	@status INT OUTPUT  
AS
/**************************************************************************
Load to plt_ai 

02/10/2025 AM	Initial creation - Created for sailpoint to update below requested columns.

sp_sailpoint_update_user 38313,'ANI_TEST',1099,'anitha test','','','','','','','','','','SA',''

**************************************************************************/
DECLARE 	@old_group_id  INT,
			@old_user_name  VARCHAR(40),
			@old_first_name VARCHAR(20),
			@old_last_name VARCHAR(20),
			@old_title VARCHAR(100),
			@old_addr1 VARCHAR(40),
			@old_addr2 VARCHAR(40),
			@old_addr3 VARCHAR(40),
			@old_email VARCHAR(80),
			@old_comment VARCHAR(800),
			@old_upn varchar(100),
	        @old_employee_id varchar(20),
			@old_modified_by VARCHAR(8),
			@request_status varchar(10),
			@request_error varchar(500);

BEGIN

    SET NOCOUNT ON;

	--BEGIN TRY  
    BEGIN TRANSACTION;  

	  select @old_group_id = group_id,
             @old_user_name = user_name,
			 @old_first_name = first_name,
			 @old_last_name = last_name,
	         @old_title = title,
	         @old_addr1 = addr1,
	         @old_addr2 = addr2,
	         @old_addr3 = addr3,
			 @old_email = email,
			 @old_upn = UPN,
			 @old_employee_id = employee_id,
			 @old_modified_by = modified_by,
			 @old_comment = comment
	 from users where user_id =  @user_id

  if @first_name is not null or @last_name is not null
  begin
  SET @user_name = IsNull(@first_name,@old_first_name) + ' ' + IsNull(@last_name,@old_last_name)
  end

  UPDATE dbo.users
    SET group_id = CASE WHEN @group_id IS NOT NULL THEN @group_id ELSE group_id END,
        user_name = CASE WHEN @user_name IS NOT NULL THEN @user_name ELSE user_name END,
		first_name = CASE WHEN @first_name IS NOT NULL THEN @first_name ELSE first_name END,
		last_name = CASE WHEN @last_name IS NOT NULL THEN @last_name ELSE last_name END,
        title = CASE WHEN @title IS NOT NULL THEN @title ELSE title END,
        addr1 =  CASE WHEN @addr1 IS NOT NULL THEN @addr1 ELSE addr1 END,
        addr2 = CASE WHEN @addr2 IS NOT NULL THEN @addr2 ELSE addr2 END,
        addr3 = CASE WHEN @addr3 IS NOT NULL THEN @addr3 ELSE addr3 END,
        email = CASE WHEN @email IS NOT NULL THEN @email ELSE email END,
		UPN = CASE WHEN @upn IS NOT NULL THEN @upn ELSE UPN END,
	    employee_id  = CASE WHEN @employee_id IS NOT NULL THEN @employee_id ELSE employee_id END,
        comment = @old_comment + char(10) + ' Updated by sailpoint' + 'M ' + (CAST(@old_group_id AS CHAR) ) + 'to ' + (CAST(group_id AS CHAR) ) + '' + CONVERT(CHAR(10), GETDATE(), 101),
        date_modified = GETDATE(),
        modified_by = IsNull(@modified_by, 'ISC') /* CASE WHEN @modified_by IS NOT NULL THEN @modified_by ELSE modified_by END */
    WHERE user_id = @user_id;

	if @@rowcount = 1
	begin

	DROP TABLE IF EXISTS #UsersAudit
	CREATE TABLE #UsersAudit (
		user_id int NOT NULL,
		table_name varchar(40) NULL,
		column_name varchar(40) NULL,
		before_value varchar(400) NULL,
		after_value varchar(4) NULL,
		audit_reference varchar(255) NULL,
		modified_by varchar(100) NULL,
		modified_from varchar(40) NULL,
		date_modified datetime NULL
		)

	IF @old_group_id <> @group_id 
	  begin
       INSERT INTO #UsersAudit
           ([user_id]
           ,[table_name]
           ,[column_name]
           ,[before_value]
           ,[after_value]
           ,[audit_reference]
           ,[modified_by]
           ,[modified_from]
           ,[date_modified])
		 VALUES
			   (@user_id
			   ,'Users'
			   ,'group_id'
			   ,@old_group_id
			   ,@group_id
			   ,'SailPoint - group_id update'
			   , 'ISC'
			   ,'SailPoint'
			   ,GETDATE()
			   )
	   end 
   
    IF @old_user_name <> @user_name 
	  begin
       INSERT INTO [#UsersAudit]
           ([user_id]
           ,[table_name]
           ,[column_name]
           ,[before_value]
           ,[after_value]
           ,[audit_reference]
           ,[modified_by]
           ,[modified_from]
           ,[date_modified])
		 VALUES
			   (@user_id
			   ,'Users'
			   ,'user_name'
			   ,@old_user_name
			   ,@user_name
			   ,'SailPoint - user_name update'
			   , 'ISC'
			   ,'SailPoint'
			   ,GETDATE()
			   )
	   end 
 
     IF @old_first_name <> @first_name 
	  begin
       INSERT INTO [#UsersAudit]
           ([user_id]
           ,[table_name]
           ,[column_name]
           ,[before_value]
           ,[after_value]
           ,[audit_reference]
           ,[modified_by]
           ,[modified_from]
           ,[date_modified])
		 VALUES
			   (@user_id
			   ,'Users'
			   ,'first_name'
			   ,@old_first_name
			   ,@first_name
			   ,'SailPoint - first_name update'
			   , 'ISC'
			   ,'SailPoint'
			   ,GETDATE()
			   )
	   end 

     IF @old_last_name <> @last_name 
	  begin
       INSERT INTO [#UsersAudit]
           ([user_id]
           ,[table_name]
           ,[column_name]
           ,[before_value]
           ,[after_value]
           ,[audit_reference]
           ,[modified_by]
           ,[modified_from]
           ,[date_modified])
		 VALUES
			   (@user_id
			   ,'Users'
			   ,'last_name'
			   ,@old_last_name
			   ,@last_name
			   ,'SailPoint - last_name update'
			   , 'ISC'
			   ,'SailPoint'
			   ,GETDATE()
			   )
	   end 

   IF @old_title <> @title 
	  begin
       INSERT INTO [#UsersAudit]
           ([user_id]
           ,[table_name]
           ,[column_name]
           ,[before_value]
           ,[after_value]
           ,[audit_reference]
           ,[modified_by]
           ,[modified_from]
           ,[date_modified])
		 VALUES
			   (@user_id
			   ,'Users'
			   ,'title'
			   ,@old_title
			   ,@title
			   ,'SailPoint - title update'
			   , 'ISC'
			   ,'SailPoint'
			   ,GETDATE()
			   )
	   end 

	IF @old_addr1 <> @addr1 
	  begin
       INSERT INTO [#UsersAudit]
           ([user_id]
           ,[table_name]
           ,[column_name]
           ,[before_value]
           ,[after_value]
           ,[audit_reference]
           ,[modified_by]
           ,[modified_from]
           ,[date_modified])
		 VALUES
			   (@user_id
			   ,'Users'
			   ,'addr1'
			   ,@old_addr1
			   ,@addr1
			   ,'SailPoint - addr1 update'
			   , 'ISC'
			   ,'SailPoint'
			   ,GETDATE()
			   )
	   end 

    IF @old_addr2 <> @addr2
	  begin
       INSERT INTO [#UsersAudit]
           ([user_id]
           ,[table_name]
           ,[column_name]
           ,[before_value]
           ,[after_value]
           ,[audit_reference]
           ,[modified_by]
           ,[modified_from]
           ,[date_modified])
		 VALUES
			   (@user_id
			   ,'Users'
			   ,'addr2'
			   ,@old_addr2
			   ,@addr2
			   ,'SailPoint - addr2 update'
			   , 'ISC'
			   ,'SailPoint'
			   ,GETDATE()
			   )
	   end 

    IF @old_addr3 <> @addr3
	  begin
       INSERT INTO [#UsersAudit]
           ([user_id]
           ,[table_name]
           ,[column_name]
           ,[before_value]
           ,[after_value]
           ,[audit_reference]
           ,[modified_by]
           ,[modified_from]
           ,[date_modified])
		 VALUES
			   (@user_id
			   ,'Users'
			   ,'addr3'
			   ,@old_addr3
			   ,@addr3
			   ,'SailPoint - addr3 update'
			   , 'ISC'
			   ,'SailPoint'
			   ,GETDATE()
			   )
	   end 

    IF @old_email <> @email
	  begin
       INSERT INTO [#UsersAudit]
           ([user_id]
           ,[table_name]
           ,[column_name]
           ,[before_value]
           ,[after_value]
           ,[audit_reference]
           ,[modified_by]
           ,[modified_from]
           ,[date_modified])
		 VALUES
			   (@user_id
			   ,'Users'
			   ,'email'
			   ,@old_email
			   ,@email
			   ,'SailPoint - email update'
			   , 'ISC'
			   ,'SailPoint'
			   ,GETDATE()
			   )
	   end 
	
	 IF @old_employee_id <> @employee_id
	  begin
       INSERT INTO [#UsersAudit]
           ([user_id]
           ,[table_name]
           ,[column_name]
           ,[before_value]
           ,[after_value]
           ,[audit_reference]
           ,[modified_by]
           ,[modified_from]
           ,[date_modified])
		 VALUES
			   (@user_id
			   ,'Users'
			   ,'employee_id'
			   ,@old_employee_id
			   ,@employee_id
			   ,'SailPoint - employee_id update'
			   , 'ISC'
			   ,'SailPoint'
			   ,GETDATE()
			   )
	   end 

   IF @old_upn <> @upn
	  begin
       INSERT INTO [#UsersAudit]
           ([user_id]
           ,[table_name]
           ,[column_name]
           ,[before_value]
           ,[after_value]
           ,[audit_reference]
           ,[modified_by]
           ,[modified_from]
           ,[date_modified])
		 VALUES
			   (@user_id
			   ,'Users'
			   ,'UPN'
			   ,@old_upn
			   ,@upn
			   ,'SailPoint - UPN update'
			   , 'ISC'
			   ,'SailPoint'
			   ,GETDATE()
			   )
	   end 

	IF @old_modified_by <> IsNull(@modified_by, 'ISC')
	  begin
       INSERT INTO [#UsersAudit]
           ([user_id]
           ,[table_name]
           ,[column_name]
           ,[before_value]
           ,[after_value]
           ,[audit_reference]
           ,[modified_by]
           ,[modified_from]
           ,[date_modified])
		 VALUES
			   (@user_id
			   ,'Users'
			   ,'modified_by'
			   ,@old_modified_by
			   ,IsNull(@modified_by, 'ISC')
			   ,'SailPoint - modified_by update'
			   , 'ISC'
			   ,'SailPoint'
			   ,GETDATE()
			   )
	   end 

	INSERT INTO plt_ai.dbo.UsersAudit
           ([user_id]
           ,[table_name]
           ,[column_name]
           ,[before_value]
           ,[after_value]
           ,[audit_reference]
           ,[modified_by]
           ,[modified_from]
           ,[date_modified])
	SELECT [user_id]
           ,[table_name]
           ,[column_name]
           ,[before_value]
           ,[after_value]
           ,[audit_reference]
           ,[modified_by]
           ,[modified_from]
           ,[date_modified]
	FROM #UsersAudit	

	DROP TABLE IF EXISTS #UsersAudit

	COMMIT TRANSACTION;  
        SET @status = 0;  -- Success  
	SET @request_status = 'Success'
	end
	else
	begin
		SET @status = 1;  -- Failure
		SET @request_status = 'Fail'
		SET @request_error = 'Users table was not modified.';
	end
		         -- Insert audit sp 
insert into dbo.UsersSailPointRequestLog
  (request_ID
  ,request_stored_proc
  ,request_status
  ,request_error
  ,added_by
  ,date_added
  ,modified_by
  ,date_modified)
values
  (@user_code
  ,'sp_sailpoint_update_user'
  ,@request_status
  ,@request_error
  ,'ISC'
  ,GetDate()
  ,'ISC'
  ,GetDate())
   -- END TRY  

	--BEGIN CATCH  
 --       ROLLBACK TRANSACTION;  
 --       SET @status = 1;  -- Failure  
 --   END CATCH  

END;

SELECT @status

GO


GRANT EXECUTE ON dbo.sp_sailpoint_update_user TO sailpoint_service
GO