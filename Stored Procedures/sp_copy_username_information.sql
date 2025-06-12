USE PLT_AI
GO

CREATE OR ALTER PROCEDURE dbo.sp_copy_username_information
@user_id Int
AS 

/************************************************************************************************************************
Returns User information text to User Copy user information screen

Filename:		L:\Apps\SQL-Deploy\Prod\NTSQL1\PLT_AI\Procedures\sp_copy_username_information.sql
Loads to:		Plt_AI
PB Object(s):	d_copy_user_information
				

07/02/2024 SG	Created - Rally# US116917 - Maintenance > Users Screen - Add "Copy username information" Toolbar Option
**************************************************************************************************************************/
SET NOCOUNT ON
BEGIN

	DECLARE 
		@return_text	VARCHAR(1000),	
		@count			INT,
		@first_name		VARCHAR(100),
		@last_name		VARCHAR(100),
		@employee_id	VARCHAR(100),
		@user_code		VARCHAR(100),
		@group_id		VARCHAR(100),
		@group_desc		VARCHAR(100),
		@upn			VARCHAR(250)

	SELECT 
		u.user_code
		, u.user_id
		, u.first_name
		, u.last_name
		, u.email
		, u.group_id
		, g.group_desc
		, u.employee_id
		, u.upn
	INTO #temp_user_info
	FROM Users u WITH (NOLOCK)
	JOIN Groups g 
		ON u.group_id = g.group_id
	WHERE u.user_id = @user_id

	SET @count = @@ROWCOUNT
	IF @count > 1
		SET @return_text = 'ERROR - More than 1 user found'

	IF @count = 0
		SET @return_text = 'No User Found'

	IF @count = 1
	BEGIN

		SELECT  @first_name = first_name,
				@last_name = last_name,
				@employee_id = employee_id,
				@user_code = user_code,
				@group_id = group_id,
				@group_desc = group_desc,
				@upn = upn
		FROM #temp_user_info

		IF (@group_id = 0)
			SET @return_text = 'EQAI User Account for ' 
				+ ISNULL(@first_name, '[No first name entered]') + ' ' + ISNULL(@last_name, '[No last name entered]') 
				+ ' User Code: ' + @user_code + ' (User ID: ' + CONVERT(varchar(10), @user_id) + ') is disabled.'
			
				IF (@employee_id <> '') AND (@employee_id is not null)
					SET @return_text = @return_text + ' Employee ID: ' + @employee_id
		
		IF (@group_id <> 0)
			SET @return_text = 'EQAI user account is configured for logins using either ' 
				+ LEFT(@upn, CHARINDEX('@', @upn) - 1) + ' or ' + @user_code + '.'
				+ ' The password will match what is used to log in to the Citrix MyStore.'
				+ ' If you have any questions or issues connecting, please contact with a support ticket so that we can assist you further.'
				+ ' Access Group: ' + @group_desc + ' (Group ID: ' + @group_id + ').'

	END

	SELECT @return_text
END
GO

GRANT EXECUTE ON dbo.sp_copy_username_information TO EQAI
GO