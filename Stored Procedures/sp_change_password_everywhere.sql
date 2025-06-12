/*
-- Commented 6/25/2019 - JPB - error deploying to misousqldev01, seems like deprecated code.

CREATE PROCEDURE sp_change_password_everywhere
	@oldpass	sysname,
	@newpass	sysname,
	@username	sysname
AS
/-********************
sp_change_password_everywhere:

Runs sp_password on each db in our system, and sets the
	server.db.users.change_password flag to False.

Returns:
	'success' or a message stating which db's failed.

example:
	exec sp_change_password_everywhere 'OldPassword', 'NewPassword', 'Username'
	exec sp_change_password_everywhere 'password', 'fresh', 'Jonathan'
	exec sp_change_password_everywhere 'fresh', 'password', 'Jonathan'

LOAD TO PLT_AI

1/7/2004 JPB Created
12/20/2005 JPB	Modified to run once per server and to update the encrypted user, too.
10/01/2007 WAC	Removed references to a database server since the procedure will be executed on the 
		server that it resides on.  Renamed tables with EQAI prefix to EQ prefix.  Added db_type
		to curCompanies cursor.  Removed updates to plt_ai_dev and plt_ai_test.
**********************-/

	SET NOCOUNT ON

	DECLARE @execute_sql varchar(8000),
		@strDBName varchar(8000),
		@strServer varchar(8000),
		@intReturn int,
		@outcome	varchar(1000),
		@lastDB	varchar(1000),
		@tmpcount int,
		@OldPassE sysname,
		@NewPassE sysname,
		@usernameE sysname

	set @OldPassE = master.dbo.fn_encode(ltrim(rtrim(@OldPass)))
	set @NewPassE = master.dbo.fn_encode(ltrim(rtrim(@newpass)))
	set @usernameE = ltrim(rtrim(@username)) + '(2)'

	CREATE TABLE #outcome (outcome varchar(1000))
	SET @lastDB = ''

	DECLARE curCompanies CURSOR FOR
	SELECT distinct D.SERVER_NAME + '.Master' AS DATABASE_NAME, D.SERVER_NAME
	FROM EQDATABASE D INNER JOIN EQCONNECT C ON C.DB_NAME_EQAI = D.DATABASE_NAME AND C.DB_TYPE = D.DB_TYPE
	UNION
	select distinct d.server_name + '.Master' as Database_name, d.server_name
	from eqdatabase d inner join eqserver s on d.server_name = s.server_name and s.server_avail = 'yes'
	ORDER BY D.SERVER_NAME, D.DATABASE_NAME

	OPEN curCompanies
	FETCH NEXT FROM curCompanies
	INTO @strDBName, @strServer
	WHILE @@FETCH_STATUS = 0 BEGIN
		if @strServer <> @lastDB
			BEGIN
				SET @execute_sql = @strDBName + '..sp_password'
--				PRINT @execute_sql
				execute @intReturn = @execute_sql @OldPass, @NewPass, @Username
				if @intReturn <> 0
				BEGIN
					insert #outcome values ('Failed to set password on ' + @strServer + '.')
					BREAK
				END
				execute @intReturn = @execute_sql @OldPassE, @NewPassE, @UsernameE
				if @intReturn <> 0
				BEGIN
					insert #outcome values ('Failed to set encrypted password on ' + @strServer + '.')
					BREAK
				END
				SET @lastDB = @strServer
			END
		FETCH NEXT FROM curCompanies
		INTO @strDBName, @strServer
	END
	Close curCompanies
	Deallocate curCompanies

	select @tmpcount = count(*) from #outcome
	if @tmpcount = 0
		begin
			update users set change_password = 'F' where user_code = @UserName and change_password = 'T'
--			update plt_ai_test.dbo.users set change_password = 'F' where user_code = @UserName and change_password = 'T'
--			update plt_ai_dev.dbo.users set change_password = 'F' where user_code = @UserName and change_password = 'T'
			insert #outcome values ('success')
		end
	SET NOCOUNT OFF

	-- SELECT top 1 outcome from #outcome
	SELECT * from #outcome


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_change_password_everywhere] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_change_password_everywhere] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_change_password_everywhere] TO [EQAI]
    AS [dbo];

*/
