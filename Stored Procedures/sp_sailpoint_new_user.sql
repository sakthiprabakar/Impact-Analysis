CREATE OR ALTER PROCEDURE [dbo].[sp_sailpoint_new_user]

	@user_id 	int, 
	@user_code 	varchar(100), 
	@group_id 	int, 
	@user_name 	varchar(40), 
	@title	 	varchar(100), 
	@addr1 		varchar(40), 
	@addr2 		varchar(40),
	@addr3 		varchar(40), 
	@phone 		varchar(20), 
	@fax 		varchar(20), 
	@pager 		varchar(20),
	@email 		varchar(80),
	@territory 	varchar(8),
	@position	varchar(8),
	@server		varchar(10),
	@company_id_default	int,
	@change_password	varchar(1),
	@comment	varchar(800),
	@date_added	datetime,
	@added_by	varchar(8),
	@date_modified	datetime,
	@modified_by	varchar(8),
	@b2b_access	char(1), 
	@b2b_remote_access	char(1),
	@department_id	tinyint,
	@first_name 			varchar(20),
	@last_name 				varchar(20),
	@cell_phone 			varchar(20),
	@internal_phone			varchar(10),
	@pic_url				varchar(300),
	@phone_list_flag		char(1),
	@phone_list_location_id	int,
	@alias_name				varchar(40),
	@upn					varchar(100),
	@employee_id			varchar(20),
	@status         INT OUTPUT  
AS
/**************************************************************************
Load to plt_ai 

02/10/2025 AM Initial creation - This is a wrapper function to sp_new_user.

sp_sailpoint_new_user 38313,'ANI_TEST',1099,'anitha test','','','','','','','','','','Active','MI001EQAISQLDEV',2,'F','TEST','02/06/2025',
'SA','02/06/2025','SA',2,'T',1,'T','t','','','','',1,'','','',''
select * from users where user_id = 38313
select * from UsersAudit where user_id = 38313
**********************************************************************************************************************************************************************/

DECLARE @RC int
DECLARE @request_status varchar(10)
DECLARE @request_error varchar(500)

-- TODO: Set parameter values here.

SET @phone = null
SET @fax =  null
SET @pager = null
SET @territory = null
SET @position = 'A'
SET @company_id_default = null
SET @change_password = 'F'
SET @date_added = GetDate()
SET @added_by = 'ISC'
SET @date_modified = GetDate()
SET @modified_by = 'ISC'
SET @b2b_access = 'T'
SET @b2b_remote_access = 'T'
SET @department_id = '78'
SET @cell_phone = null
SET @internal_phone = null
SET @pic_url = null
SET @phone_list_flag = 'F'
SET @phone_list_location_id = null
SET @alias_name = null
SET @user_name = @first_name + ' ' + @last_name

begin try
EXECUTE @RC = [dbo].[sp_new_user] 
   @user_id
  ,@user_code
  ,@group_id
  ,@user_name
  ,@title
  ,@addr1
  ,@addr2
  ,@addr3
  ,@phone
  ,@fax
  ,@pager
  ,@email
  ,@territory
  ,@position
  ,@server
  ,@company_id_default
  ,@change_password
  ,@comment
  ,@date_added
  ,@added_by
  ,@date_modified
  ,@modified_by
  ,@b2b_access
  ,@b2b_remote_access
  ,@department_id
  ,@first_name
  ,@last_name
  ,@cell_phone
  ,@internal_phone
  ,@pic_url
  ,@phone_list_flag
  ,@phone_list_location_id
  ,@alias_name
  ,@upn
  ,@employee_id
end try
begin catch
  set @request_error = substring(error_message(),1,500)
end catch

select @RC

IF @RC = ''
	begin
	 set @status = 0 -- Success
	 set @request_status = 'Success'
	 INSERT INTO [dbo].[UsersAudit]
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
           ,'ALL'
           ,''
           ,'(New User Inserted)'
           ,'SailPoint - New user creation'
           ,'ISC'
           ,'SailPoint'
           ,GETDATE()
		   )
	end
ELSE
	begin
	 set @status = 1 -- Failure
	 set @request_status = 'Fail'
	end 

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
  ,'sp_sailpoint_new_user'
  ,@request_status
  ,@request_error
  ,'ISC'
  ,GetDate()
  ,'ISC'
  ,GetDate())

GO

GRANT EXECUTE ON dbo.sp_sailpoint_new_user TO sailpoint_service
GO