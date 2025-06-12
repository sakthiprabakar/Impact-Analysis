CREATE PROCEDURE sp_login_update_master
	@user_code 	varchar(20), 
	@password	varchar(20),
	@role		varchar(30),
	@db_type	varchar(10),
	@debug		int
AS
/**************************************************************************
Filename:	L:\Apps\SQL\Plt_AI\sp_login_update_master.sql
Load to plt_ai

12/20/2005 JDB	Created
06/06/2007 JDB	Removed references to NTSQL3.
09/12/2007 JDB	Modified to use new servers for Test and Dev.  Databases
		no longer have _TEST and _DEV in the names.  Also added
		new @db_type parameter used to update only that type.
11/12/2007 JDB	Modified to use NTSQLFINANCE instead of the server name
		from EQServer because NTSQL5 is not linked any more.
10/29/2009 JDB	Fixed bug where the loop through servers wasn't getting
		processed correctly because the @server variable gets set
		to NTSQLFINANCE for the Epicor server.
11/24/2009 JDB	Fixed another bug where @server_name variable was used
		as the parameter into sp_login_update instead of @server.
		Also changed @server_name to @server_alias to be clearer.

sp_login_update_master 'SHARYN_L', 'taylor116', 'EQAI', 'PROD', 1
**************************************************************************/
DECLARE @return		int, 
	@server_count 	int,	
	@server		varchar(40),
	@server_alias	varchar(40),
	@server_avail	varchar(20),
	@server_type	varchar(20),
	@execute_sql	varchar(1000),
	@database	varchar(30),
	@database_epicor varchar(30),
	@user_code_new	varchar(30),
	@password_new	varchar(128)

SET NOCOUNT ON
SET @password = LOWER(@password)
SET @user_code_new = @user_code + '(2)'
SELECT @password_new = master.dbo.fn_encode(@password)

IF @debug = 1
BEGIN
	PRINT '@user_code_new = ' + @user_code_new
	PRINT '@password_new =  ' + @password_new
END

-- Create a temp table to hold the databases
SELECT	server_name,
	server_avail,
	server_type,
	server_primary,
	0 AS process_flag
INTO #tmp_server
FROM EQServer
WHERE server_type LIKE '%' + @db_type+ '%'
AND server_type NOT LIKE 'EQWeb%'

IF @debug = 1 SELECT * FROM #tmp_server

/************************************************************/
-- Process each server in the list

-- Call sp_login_update on NTSQLX
SELECT @server_count = COUNT(*) FROM #tmp_server
WHILE @server_count > 0
BEGIN
	-- Get the server
	SET rowcount 1
	SELECT	@server = server_name,
		@server_alias = server_name,
		@server_avail = server_avail,
		@server_type = server_type
	FROM #tmp_server
	WHERE process_flag = 0
	SET rowcount 0
	
	-- Run the login update
	IF @server_avail = 'yes'
	BEGIN
		IF LEFT(@server_type, 4) = 'EQAI' SET @database = 'plt_ai'
		IF LEFT(@server_type, 6) = 'Epicor' 
		BEGIN
			SET @database = 'emaster'
			SET @server_alias = 'NTSQLFINANCE'
		END

		SET @execute_sql =  @server_alias + '.' + @database + '.dbo.sp_login_update '

		IF @debug = 1 PRINT @execute_sql
		EXECUTE @execute_sql @user_code_new, @password_new, @server, @role, @debug
		IF @debug = 1 PRINT 'After running ' + @execute_sql + ' ' + @user_code_new + ', ' + @password_new + ', ' + @server + ', ' + @role + ', ' + CONVERT(varchar(4), @debug)
	END

	-- Update to process the next server
	SET rowcount 1
	UPDATE #tmp_server SET process_flag = 1 WHERE server_name = @server AND process_flag = 0
	SET rowcount 0
	SELECT @server_count = @server_count - 1
END


-- Update Users table
IF @debug = 1 PRINT 'Updating Users table'
UPDATE Users SET login_updated = 'T' WHERE user_code = @user_code
IF @debug = 1 SELECT login_updated, * FROM Users WHERE user_code = @user_code

SET NOCOUNT OFF
-- Return 0 (failure) or 1 (success)
SET @return = 1

/**********/
ExitProc:
/**********/
SELECT @return

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_login_update_master] TO [EQAI]
    AS [dbo];

