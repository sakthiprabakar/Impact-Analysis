
CREATE PROCEDURE sp_login_update_each_db
	@user_code varchar(24),
	@role varchar(30)
as
--
-- 11/12/2015 rb	Created
--
-- core functionality extracted from sp_login_update, to be loaded to every database and called from sp_login_update
--
declare @user_cnt int,
		@sql varchar(255)

SELECT @user_cnt = COUNT(*) FROM sysusers WHERE name = @user_code
IF @user_cnt = 0 
BEGIN	
--	EXEC sp_adduser @user_code, @user_code, @role
	SET @sql = 'CREATE USER [' + @user_code + '] FOR LOGIN [' + @user_code + ']'
	EXEC(@sql)

	SET @sql = 'ALTER USER [' + @user_code + '] WITH DEFAULT_SCHEMA=[' + @user_code + ']'
	EXEC(@sql)

	SET @sql = 'CREATE SCHEMA [' + @user_code + '] AUTHORIZATION [' + @user_code + ']'
	EXEC(@sql)

	IF ISNULL(RTRIM(@role),'') <> ''
	BEGIN
		SET @sql = 'EXEC sp_addrolemember ''' + @role + ''', ''' + @user_code + ''''
		EXEC(@sql)
	END
	
	IF @@ERROR <> 0
	BEGIN
		RAISERROR('could not add user',16,1)
		RETURN -1
	END 
END

RETURN 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_login_update_each_db] TO PUBLIC
    AS [dbo];

