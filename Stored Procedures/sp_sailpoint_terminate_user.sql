CREATE OR ALTER PROCEDURE [dbo].[sp_sailpoint_terminate_user]
   @user_id INT, 
   @status INT OUTPUT  

AS  
/**************************************************************************
Load to plt_ai 

02/10/2025 AM	Initial creation

**************************************************************************/
BEGIN  
   SET NOCOUNT ON;  
   DECLARE @group_id INT,
           @audit_reference VARCHAR(100) = 'SailPoint - user termination',
           @modified_by VARCHAR(100) = 'ISC', --SUSER_NAME(),  
           @modified_from VARCHAR(100) = 'SailPoint',
		   @user_code VARCHAR(100),
		   @request_status varchar(10),
		   @request_error varchar(500);

	BEGIN TRY  
        BEGIN TRANSACTION;  

   -- Retrieve the current group_id before updating  
   SELECT @group_id = group_id, @user_code = user_code
   FROM dbo.users  
   WHERE user_id = @user_id;  

   -- Ensure the user exists before proceeding  
   IF @group_id IS NOT NULL  
   BEGIN  
       -- Update the user group_id to 0  
       UPDATE dbo.users  
       SET group_id = 0, modified_by = 'ISC', date_modified = GetDate(), comment = LEFT(comment + char(10) + 'M ' + CAST(@group_id AS CHAR) + ' to 0 ' + CONVERT(CHAR(10), GetDate(), 101),255)
       WHERE user_id = @user_id;  

	   if @@rowcount = 1
	   begin
       -- Insert audit record  
       INSERT INTO dbo.UsersAudit  
           (user_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)  
       VALUES  
           (@user_id, 'Users', 'group_id', @group_id, 0, @audit_reference, @modified_by, @modified_from, GETDATE());  

		COMMIT TRANSACTION;  
        SET @status = 0;  -- Success  
	SET @request_status = 'Success'
		end
		else
		begin
		SET @status = 1;
		SET @request_status = 'Fail'
		SET @request_error = 'Users table was not modified.';
		end
   END  
   ELSE  
   BEGIN  
       PRINT 'No user found with the given user_id';  
	     ROLLBACK TRANSACTION;  
        SET @status = 1;  -- Failure
	SET @request_status = 'Fail'
		set @request_error = 'No user found with the given user_id';

   END  

    END TRY  
    BEGIN CATCH  
        ROLLBACK TRANSACTION;  
        SET @status = 1;  -- Failure  
	SET @request_status = 'Fail'
		set @request_error = substring(error_message(),1,500);

    END CATCH  

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
  ,'sp_sailpoint_terminate_user'
  ,@request_status
  ,@request_error
  ,'ISC'
  ,GetDate()
  ,'ISC'
  ,GetDate())

END;  
GO


GRANT EXECUTE ON dbo.sp_sailpoint_terminate_user TO sailpoint_service
GO