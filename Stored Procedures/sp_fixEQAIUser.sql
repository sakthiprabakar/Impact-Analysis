USE [master]
GO
--DROP PROC IF EXISTS sp_fixEQAIUser
--GO
CREATE PROCEDURE [dbo].[sp_fixEQAIUser]
      @user_code VARCHAR(40)
    , @debug INTEGER
AS
BEGIN

SET NOCOUNT ON;

--Generate an overview by database of User Inclusion
--For use in Debug
--DECLARE @user_code VARCHAR(40) = 'SUSAN_SM', @debug INTEGER = 1;

DECLARE @sql NVARCHAR(1000) = ''
	  --, @errorcount INTEGER = 0
      , @errortxt VARCHAR(250) = ''
	  , @user_code2 VARCHAR(40)
      , @loginct INTEGER = 0
      , @errmsg VARCHAR(255) = ''
;

--Check to see if a basic login exists
SELECT @loginct = COUNT(loginname) FROM master.sys.syslogins WHERE loginname = @user_code;
--PRINT @loginct

--In the case where the login does not exist, throw an error
IF @loginct = 0
BEGIN
    SET @errortxt = 'The Login ' + @user_code + ' does not exist.  It must be created before running this procedure.'
    RAISERROR(@errortxt,0,0)
    RETURN
END

SET @user_code2 = @user_code+'(2)'

--Check to see if a (2) login exists
SELECT @loginct = COUNT(loginname) FROM master.sys.syslogins WHERE loginname = @user_code2;

--In the case where the login does not exist, throw an error
IF @loginct = 0
BEGIN
    SET @errortxt = 'There is no (2) user associated with the Login ' + @user_code + '.  It must be created before running this procedure.'
    RAISERROR(@errortxt,0,0)
    RETURN
END

--Create a temp table to hold the database users and logins for comparison
    DROP TABLE IF EXISTS #UserList;
    CREATE TABLE #UserList (
           ServerName    NVARCHAR(256) NOT NULL
         , DBName        SYSNAME NOT NULL
		 , LoginName     SYSNAME NULL
         , UserName      SYSNAME NULL
         , GroupName     SYSNAME NULL
         )
    ;

	SET @sql = '
        SELECT @@SERVERNAME as ServerName
             , ''?'' as DBName
             , l.name as LoginName
			 , u.name as UserName
             , CASE WHEN (r.principal_id IS NULL) THEN ''public'' ELSE r.name END as GroupName
          FROM [?].sys.database_principals u
          LEFT JOIN ([?].sys.database_role_members m
                         JOIN [?].sys.database_principals r ON m.role_principal_id = r.principal_id)
                    ON m.member_principal_id = u.principal_id
          LEFT JOIN [?].sys.server_principals l ON u.sid = l.sid
         WHERE u.TYPE <> ''R''
           AND (u.name = ''' + @user_code + ''' or u.name = ''' + @user_code2 + ''')';

	 --PRINT @sql;  --For debugging

    INSERT INTO #UserList (ServerName, DBName, LoginName, UserName, GroupName)
    EXEC sp_MSForEachdb @sql;

--Create a temp table to hold the databases for comparison
    DROP TABLE IF EXISTS #DBList;
    CREATE TABLE #DBList (DBName SYSNAME NOT NULL);

    INSERT INTO #DBList (DBName)
    SELECT [name]
      FROM master.sys.databases
     --Exclude system and non-application-related databases
     WHERE [state] = 0
       AND [name] NOT IN ('master','model','msdb','tempdb'		--restricted system db's
	     --production auxiliary db's
		 ,'ARCHIVE','COR2Integration','DataTeamStaging','dba'
		 ,'EQ_Extract','EQ_IT','EQ_TEMP','EQOnlineCMS','External_Edit','Plt_Export','ReportServer','ReportServerTempDB'
		 --Other random db's
		 ,'IdentityService','OpsDashboard','RedGate','COR_DB_preprod','Plt_Image_preprod'
         ,'PLT_AI_oedward_SHADOW','PLT_AI_posttest','PLT_AI_preprod','PLT_AI_preprod_oedward_SHADOW')
    ;

--Set up the various permissions checks to generate
DECLARE @userchk VARCHAR(2000) = 'IF NOT EXISTS (select 1 from sys.database_principals where [name] = ''' + @user_code + ''') CREATE USER ' + QUOTENAME(@user_code) + ' FOR LOGIN ' + QUOTENAME(@user_code) + ' WITH DEFAULT_SCHEMA = dbo' 
	  , @userchk2 VARCHAR(2000) = 'IF NOT EXISTS (select 1 from sys.database_principals where [name] = ''' + @user_code2 + ''') CREATE USER ' + QUOTENAME(@user_code2) + ' FOR LOGIN ' + QUOTENAME(@user_code2) + ' WITH DEFAULT_SCHEMA = dbo' 
;
DECLARE @eqaichk VARCHAR(2000) = 'ALTER ROLE EQAI ADD MEMBER ' + QUOTENAME(@user_code)
	  , @eqaichk2 VARCHAR(2000) = 'ALTER ROLE EQAI ADD MEMBER ' + QUOTENAME(@user_code2)
;
DECLARE @cor_userchk VARCHAR(2000) = 'ALTER ROLE COR_USER ADD MEMBER ' + QUOTENAME(@user_code)
	  , @cor_userchk2 VARCHAR(2000) = 'ALTER ROLE COR_USER ADD MEMBER ' + QUOTENAME(@user_code2)
;
DECLARE @eqloginchk VARCHAR(2000) = 'ALTER ROLE EQLOGIN ADD MEMBER ' + QUOTENAME(@user_code)
	  , @eqloginchk2 VARCHAR(2000) = 'ALTER ROLE EQLOGIN ADD MEMBER ' + QUOTENAME(@user_code2)
;

--Create a temp table to hold the generated permissions
    DROP TABLE IF EXISTS #PermList;
    CREATE TABLE #PermList (
           LineNumber    INTEGER IDENTITY(1,1)
         , GrantText     VARCHAR(2000) NOT NULL
         , RunOrder      INTEGER NOT NULL
         , DBName        SYSNAME NOT NULL
         )
    ;

INSERT INTO #PermList (GrantText, RunOrder, DBName)
--PLT_AI is the primary database where the primary user should have a login
select TOP 1 'USE ' + d.DBName + '; ' + @userchk + ';' as sqltext
     , 1 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'PLT_AI'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @userchk2 + ';' as sqltext
     , 1 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'PLT_AI'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @eqloginchk + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'PLT_AI'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @eqloginchk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'PLT_AI'
 union all
select TOP 1 'USE ' + d.DBName + '; ' + @cor_userchk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'PLT_AI'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @eqaichk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'PLT_AI'

--COR_DB: (2) User should have two roles
union all
select TOP 1 'USE ' + d.DBName + '; ' + @userchk2 + ';' as sqltext
     , 1 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'COR_DB'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @cor_userchk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'COR_DB'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @eqaichk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'COR_DB'

--ECOL_D365Integration: (2) User should have one role
union all
select TOP 1 'USE ' + d.DBName + '; ' + @userchk2 + ';' as sqltext
     , 1 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'ECOL_D365Integration'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @eqaichk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'ECOL_D365Integration'

--EQWeb: (2) User should have one role
union all
select TOP 1 'USE ' + d.DBName + '; ' + @userchk2 + ';' as sqltext
     , 1 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'EQWeb'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @eqaichk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'EQWeb'

--Plt_AI_Audit: (2) User should have two roles
union all
select TOP 1 'USE ' + d.DBName + '; ' + @userchk2 + ';' as sqltext
     , 1 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'Plt_AI_Audit'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @cor_userchk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'Plt_AI_Audit'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @eqaichk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'Plt_AI_Audit'

--Plt_AI_Audit: (2) User should have two roles
union all
select TOP 1 'USE ' + d.DBName + '; ' + @userchk2 + ';' as sqltext
     , 1 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'Plt_Image'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @cor_userchk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'Plt_Image'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @eqaichk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'Plt_Image'

--PLT_Message:  User and (2) User should have one role each
union all
select TOP 1 'USE ' + d.DBName + '; ' + @userchk + ';' as sqltext
     , 1 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'PLT_Message'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @userchk2 + ';' as sqltext
     , 1 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'PLT_Message'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @eqaichk + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'PLT_Message'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @eqaichk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'PLT_Message'

 --Plt_InvoiceImage Databases: (2) User should have two roles
union all
select DISTINCT 'USE ' + d.DBName + '; ' + @userchk2 + ';' as sqltext
     , 1 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName like 'Plt_InvoiceImage_%'
union all
select DISTINCT 'USE ' + d.DBName + '; ' + @cor_userchk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName like 'Plt_InvoiceImage_%'
union all
select DISTINCT 'USE ' + d.DBName + '; ' + @eqaichk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName like 'Plt_InvoiceImage_%'

--Plt_Invoice Databases: (2) User should have two roles
union all
select DISTINCT 'USE ' + d.DBName + '; ' + @userchk2 + ';' as sqltext
     , 1 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName like 'Plt_Image_%'
union all
select DISTINCT 'USE ' + d.DBName + '; ' + @cor_userchk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName like 'Plt_Image_%'
union all
select DISTINCT 'USE ' + d.DBName + '; ' + @eqaichk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName like 'Plt_Image_%'

--SQL_CLR: (2) User should have one role
union all
select TOP 1 'USE ' + d.DBName + '; ' + @userchk2 + ';' as sqltext
     , 1 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'SQL_CLR'
union all
select TOP 1 'USE ' + d.DBName + '; ' + @eqaichk2 + ';' as sqltext
     , 2 as RunOrder
     , d.DBName
  from #DBList d
  LEFT JOIN #UserList u on d.DBName = u.DBName
 WHERE d.DBName = 'SQL_CLR'

 ORDER BY d.DBName, RunOrder
;

--SELECT * FROM #PermList;

DROP TABLE #UserList;
DROP TABLE #DBList;

DECLARE @PermCt INTEGER
      , @PermTxt NVARCHAR(1000)
;

SELECT @PermCt = COUNT(*) FROM #PermList;
DECLARE @i INTEGER
SET @i=1
WHILE ( @i <= @PermCt)
    BEGIN
        SELECT @PermTxt = GrantText FROM #PermList WHERE LineNumber = @i;
        IF @debug = 1 PRINT 'Line Number ' + CONVERT(VARCHAR,@i) + ': ' + @PermTxt;  --For debugging
        EXECUTE sp_executesql @PermTxt
        SET @i = @i + 1
    END

DROP TABLE #PermList;

IF @@ERROR <> 0
    BEGIN
	    SET @errmsg = 'sp_fixEQAIUser encountered an error trying to repair user: ' + @user_code
        SELECT @errmsg
	    RAISERROR(16, 1, @errmsg)
	    RETURN -1
    END

--PRINT @user_code + ' updated successfully.'
SELECT @user_code + ' updated successfully.' as ReturnText
RETURN 0

END


