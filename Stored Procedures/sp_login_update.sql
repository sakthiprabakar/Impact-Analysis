--drop procedure sp_login_update
--go
CREATE PROCEDURE sp_login_update
       @user_code    varchar(24), 
       @password     varchar(128), 
       @server             varchar(20),
       @role        varchar(30),
       @debug       int
AS
/**************************************************************************
Filename:     L:\IT Apps\SourceCode\Control\SQL\Prod\NTSQL1\PLT_AI\Procedures\sp_login_update.sql
Load to plt_ai (NTSQL1)
Load to emaster (NTSQL5)

12/20/2005 JDB      Created
01/16/2006 JDB      Added databases plt_image_0011 to plt_image_0015
04/09/2007 JDB      Added databases plt_image_0016 to plt_image_0020
04/14/2007 JDB      Modified to use company 2 and 3 on NTSQL1.
06/06/2007 JDB      Removed references to NTSQL3.
09/12/2007 JDB      Modified to use new servers for Test and Dev.  Databases
             no longer have _TEST and _DEV in the names.
             Added databases Plt_InvoiceImage_0001 to Plt_InvoiceImage_0020
11/02/2007 JDB      Added database EQFinance
05/07/2008 JPB      Added database plt_rpt
01/02/2009 KAM      Added database EQ_Extract
06/24/2009 JPB      Added database EQ_Temp
08/16/2009 JDB      Added databases Plt_Image_0031 to Plt_Image_0035
11/24/2009 JDB      Added database e01
05/04/2010 JDB      Added databases 25 through 28
06/09/2010 JDB      Added databases Plt_Image_0036 to Plt_Image_0045
08/20/2010 KAM  Uncommented plt_29_ace and reloaded to NTSQL1 and NTSQL5
08/23/2011 JDB      Added databases Plt_Image_0046 to Plt_Image_0060
01/23/2013 JDB      Removed database Plt_RPT because we don't use it any longer.
02/18/2013 JDB      Added database 32 (don't know how we missed it for so long!)
04/30/2013 JDB      Added databases Plt_Image_0061 to Plt_Image_0075
07/10/2014 JDB      Removed the references to the Plt_XX_AI databases, since
                           we removed them from Production.
02/06/2015 JDB      Added databases Plt_Image_0076 to Plt_Image_0090
11/12/2015 RWB      Replaced sp_addlogin and sp_adduser with newer syntax (for AD Authentication)
                           Had to be loaded as a stored procecdure to each database (eqpicor now excluded)
09/28/2017 JPB      3-digits of image databases now.  Small change to code: 90 -> 100
                           GEM-45962
03/30/2018 RWB      GEM-49335 Added database SQL_CLR
02/28/2019 GSO      Added databases Plt_Image_0101 to Plt_Image_0110
06/18/2019 RWB      GEM-62394 Removed check to only execute if left 6 characters of @@servername is NTSQL1
09/28/2020 AM DevOps:17152 -Addition of server COR DB and ECOL_D365Integration for new users
03/03/2023 AM   DevOps:62493 - Added PLT_Message server 
03/03/2023 AM   DevOps:62493 - Added version to choose the syslogins data 
04/10/2023 AM   Service ticket#162973 - Refine the code per DBA
04/27/2023 AM   DevOPs:64777 - new user could not login to eqai
08/18/2023 AM   DevOps:71763 - Refine the code per DBA to fix image database blockage.

select master.dbo.fn_encode('password')
SELECT * FROM Users WHERE user_code = 'lacey_w'
sp_login_update 'LARRY_BA(2)', '08426411429429433425428414', 'NTSQL5', 'EQAI', 1

select 'sp_login_update ''' + UPPER(sysusers.name) + ''', '''', ''NTSQL1TEST'', ''EQAI'', 1' + CHAR(10) + 'GO'
from sysusers, users
where name like '%(2)%'
and LEFT(sysusers.name, LEN(sysusers.name) - 3) = users.user_code
and users.group_id > 0
order by name
**************************************************************************/
--DECLARE @user_code    varchar(24) = 'D_HARRIS(2)'
--      , @password     varchar(128) = ''
--      , @server       varchar(20) = 'PRDEQAISQLHAL.internal.ecol.com'
--      , @role         varchar(30) = 'EQAI'
--      , @debug        int = 1

DECLARE @version    varchar(30)
      , @user_cnt   smallint
      , @user_code2 VARCHAR(40)
      , @msg        varchar(100)
	  , @errorcount int
      , @sql        nvarchar(1024)
;

select @version = Right ( Left( @@VERSION , 25) , 4);

IF @version  = '2019'  
 BEGIN
  -- Make sure this user doesn't already exist
       SELECT @user_cnt = COUNT(*) FROM master.sys.syslogins WHERE loginname = @user_code;
	   IF @debug = 1 PRINT 'Logins matching input: ' + CAST(@user_cnt as VARCHAR) + '!'
       IF @user_cnt = 0 
       BEGIN
             SET @sql = 'CREATE LOGIN [' + @user_code + '] WITH PASSWORD=''' + @password + ''', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF'
             IF @debug = 1 PRINT 'Creating Login...'
			 EXECUTE sp_executesql @sql

             IF @@ERROR <> 0 
             BEGIN
                    SET @errorcount = 1;
					SET @msg = 'The Login ' + @user_code + ' does not exist.  It must be created before running this procedure.'
					RAISERROR(@msg,0,0)
					RETURN
             END

            SET @user_code2 = @user_code
            SET @user_code = LEFT(@user_code, LEN(@user_code) - 3);

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
                 WHERE [name] NOT IN ('master','model','msdb','tempdb'		--restricted system db's
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

            --Plt_Image: (2) User should have two roles
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

            --Plt_Image Databases: (2) User should have two roles
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

            IF @debug = 1 PRINT @user_code + ' updated successfully.'

            SET NOCOUNT OFF;

        END
    END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_login_update] TO LOGIN_MGMT_SERVICE 
    --AS [dbo];

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_login_update] TO [EQWEB]
    --AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_login_update] TO [COR_USER]
    --AS [dbo];

GO