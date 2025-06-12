DROP PROCEDURE IF EXISTS sp_new_user
GO

CREATE PROCEDURE sp_new_user
	@user_id 	int, 
	@user_code 	varchar(8), 
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
	@comment	varchar(max),
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
	@employee_id			varchar(20)
AS
/**************************************************************************
Load to plt_ai (not plt_XX_ai)

01/15/1998 SCC	Modified to Remove references to 00 and 01 test databases
10/02/2000 JDB	Modified to use new servers NTSQL1 and NTSQL3.  DO NOT RUN
		this sp on NTSQL2.  Use sp_newuser2.sql for NTSQL2.
10/05/2000 JDB	Modified to not update the next_quote_id or 
		default_profit_ctr_id.  New users get a default of 1 for 
		their next_quote_id.  21, 1, 0, 0 for plt_02_ai, plt_03_ai,
		plt_12_ai, and plt_14_ai respectively.
		Run this on NTSQL1 and NTSQL3.
04/01/2002 JDB	Modified to accomodate the new fields added to the users 
		table for default printers.
05/21/2002 JDB	Modified to accomodate new change_password field in users table
09/21/2002 JDB	Modified to update new printer field (printer_container_label_mini)
		and add users to the new image databases.
03/18/2003 JDB	Modified to update plt_15_ai.  Default profit_ctr_id = 0.
06/02/2003 JDB	Moved plt_02_ai_image and plt_03_ai_image to NTSQL1.
06/20/2003 JDB	Modified to update all test databases.  We use dev databases
		now for development and would like to keep test in sync.
07/03/2003 JDB	Added haz_label and nonhaz_label printer
07/08/2003 JDB	Modified to use a default profit_ctr_id = 1 for 15-EQNE.
		Also added users to DEV databases.
08/04/2003 JDB	Modified to update plt_17_ai.  Default profit_ctr_id = 0.
11/25/2003 JDB	Modified to update company 18, 21, 22, 23, 24.  Default profit_ctr_id = 0.
05/06/2004 JDB	Added continuation printer and default company.
11/19/2004 MK	Added pdf and fax printers
05/11/2005 JDB	Modified to use new Image databases (plt_image, plt_image_XXXX)
12/07/2005 MK	Added @b2b_access and @b2b_remote_access
12/29/2005 JDB	Modified to add users to EQLOGIN role instead of EQAI on plt_ai.
		Modified to not add users to company and image databases.
04/14/2007 JDB	Removed Plt_02_AI and Plt_03_AI from NTSQL3 (now on NTSQL1).
09/12/2007 JDB	Modified to use new servers for Test and Dev.  Databases
		no longer have _TEST and _DEV in the names.  Also added department_id
10/29/2009 JDB	Changed intialization to "password", not "PASSWORD" (SQL 2008)
02/16/2010 JDB	Added new fields for phone list.
05/04/2010 JDB	Added databases 25 through 28 (Envirite companies)
08/06/2010 JDB	Added database 29 (EQ Oklahoma)
04/18/2012 JDB	Added database 32 (EQ Alabama)
06/17/2014 JDB	Replaced the UserCompany table with UserDefaultProfitCenter.
11/12/2015 RWB	Replaced sp_addlogin and sp_adduser with calls to CREATE and sp_addrolemember (for AD Authentication changes)
03/16/2017 MPM	Added companies 41 and 42.
10/09/2017 JDB	Added companies 44 (US Ecology Idaho), 45 (US Ecology Nevada) and 46 (US Ecology Texas).
05/03/2019 MPM	GEM 60714 - Updated to automatically find all companies for inserts into UserDefaultProfitCenter so that we
				no longer have to update this stored procedure each time we add new companies to the database.
01/21/2020 AM   DevOPs:13737  - Added upn.
08/04/2022 RBB	DevOps:42274 - Added employee_id
10/11/2022 MPM	DevOps 49453 - Changed Users.comment to varchar(max).
11/22/2022 AGC  DevOps 49407 - Commented out code that creates user schema, should use dbo schema instead

sp_new_user 931,'TRAINING',1027,'Epicor 7.3.5 Testing','','','','','','','','','','Active','NTSQL1',2,'F','PROD','New 1027 1/19/06 JDB','1/19/2006 17:15:22','SA','1/19/2006 17:15:22','SA',2,'T','T'
sp_new_user 3831,'MPM_TEST',1099,'mpm test','','','','','','','','','','Active','NTSQL1',2,'F','PROD','mpm test',getdate(),'SA',getdate(),'SA',2,'T','T'
**************************************************************************/
DECLARE @user_cnt 	smallint, 
	@user_id_cnt 	smallint, 
	@msg 		varchar(100), 
	@errorcount 	int,
	@new_user_id 	int, 
	@sql			varchar(255),
	@company_id			int,
	@profit_ctr_id		int

SET @msg = ''
SET @errorcount = 0
SET @new_user_id = @user_id

-- Make sure this user doesn't already exist
SELECT @user_cnt = COUNT(*) FROM master..syslogins WHERE name = @user_code
IF @user_cnt = 0 
BEGIN
-- rb 11/12/2015
--    EXEC sp_addlogin @user_code, 'password'
	SET @sql = 'CREATE LOGIN [' + @user_code + '] WITH PASSWORD=''password'', DEFAULT_DATABASE=[master], CHECK_EXPIRATION=OFF, CHECK_POLICY=OFF'
	EXEC(@sql)

    IF @@ERROR <> 0 
    BEGIN
	SELECT @msg = 'Error adding user to Syslogins'
	SELECT @errorcount = 1
	GOTO ExitProc 
    END
END


--------------------------------------------------
-- Add user to the eqlogin role on plt_ai
--------------------------------------------------

    -- Add this user to sysusers
SELECT @user_cnt = COUNT(*) FROM sysusers WHERE name = @user_code
IF @user_cnt = 0 
BEGIN	
--  rb 11/12/2015 User newer syntax options for use with service account
--	EXEC sp_adduser @user_code, @user_code, eqlogin
	SET @sql = 'CREATE USER [' + @user_code + '] FOR LOGIN [' + @user_code + ']'
	EXEC(@sql)
	--DevOps 49407 AGC 11/22/2022 comment out code to create user schema
	--SET @SQL = 'ALTER USER [' + @user_code + '] WITH DEFAULT_SCHEMA=[' + @user_code + ']'
	--EXEC(@sql)
	--SET @sql = 'CREATE SCHEMA [' + @user_code + '] AUTHORIZATION [' + @user_code + ']'
	--EXEC(@sql)
	--DevOps 49407 AGC 11/22/2022 set default schema to dbo
	SET @SQL = 'ALTER USER [' + @user_code + '] WITH DEFAULT_SCHEMA=[dbo]'
	EXEC(@sql)

	EXEC sp_addrolemember 'eqlogin', @user_code

	IF @@ERROR <> 0 
	BEGIN
		SELECT @msg = 'Error adding user to Plt_AI Sysusers'
		SELECT @errorcount = 1
		GOTO ExitProc 
	END
END

BEGIN TRANSACTION NEWUSER

--------------------------------------------------
-- Add user to Users table on plt_ai
--------------------------------------------------

----------------------------
-- plt_ai    
----------------------------
SELECT @user_cnt = COUNT(*) FROM Users WHERE user_code = @user_code
SELECT @user_id_cnt = COUNT(*) FROM Users WHERE user_id = @new_user_id
IF @user_cnt = 0 AND @user_id_cnt = 0
BEGIN
	INSERT INTO Users (
		user_id, 
		user_code, 
		group_id, 
		user_name,
		title, 
		addr1, 
		addr2, 
		addr3, 
		phone, 
		fax, 
		pager, 
		email,
		territory_code, 
		position, 
		change_password, 
		default_company_id, 
		comment,
		date_added, 
		added_by, 
		date_modified, 
		modified_by, 
		printer_pdf, 
		printer_fax,
		b2b_access, 
		b2b_remote_access, 
		department_id,
		first_name,
		last_name,
		cell_phone,
		internal_phone,
		pic_url,
		phone_list_flag,
		phone_list_location_id,
		alias_name,
		upn,
		employee_id)
	VALUES (@new_user_id, 
		@user_code, 
		@group_id, 
		@user_name, 
		@title, 
		@addr1, 
		@addr2, 
		@addr3, 
		@phone, 
		@fax, 
		@pager, 
		@email,
		@territory, 
		@position, 
		@change_password, 
		@company_id_default, 
		@comment,
		@date_added, 
		@added_by, 
		@date_modified, 
		@modified_by, 
		'EQPDF',
		'ActiveFax',
		@b2b_access, 
		@b2b_remote_access, 
		@department_id,
		@first_name,
		@last_name,
		@cell_phone,
		@internal_phone,
		@pic_url,
		@phone_list_flag,
		@phone_list_location_id,
		@alias_name,
		@upn,
		@employee_id)
	IF @@ERROR <> 0 
	BEGIN
	    SELECT @msg = 'Error adding user to Plt_AI Users table'
	    SELECT @errorcount = 1
	    GOTO ExitProc 
END
END
ELSE
BEGIN
	UPDATE Users SET 
		group_id=@group_id, 
		user_name=@user_name,	
		title=@title, 
		addr1=@addr1, 
		addr2=@addr2, 
		addr3=@addr3, 
		phone=@phone, 
		fax=@fax, 
		pager=@pager, 
		email=@email,
		territory_code=@territory, 
		position=@position, 
		change_password = @change_password,
		default_company_id=@company_id_default, 
		comment=@comment, 
		date_modified = @date_modified, 
		modified_by = @modified_by,
		b2b_access = @b2b_access, 
		b2b_remote_access = @b2b_remote_access, 
		department_id = @department_id,
		first_name = @first_name,
		last_name = @last_name,
		cell_phone = @cell_phone,
		internal_phone = @internal_phone,
		pic_url = @pic_url,
		phone_list_flag = @phone_list_flag,
		phone_list_location_id = @phone_list_location_id,
		alias_name = @alias_name,
		upn = @upn,
		employee_id = @employee_id
	WHERE user_id=@user_id
	IF @@ERROR <> 0 
	BEGIN
	    SELECT @msg = 'Error updating user in Plt_AI Users table'
	    SELECT @errorcount = 1
	    GOTO ExitProc 
	END
END

DECLARE company_cursor CURSOR FOR 
SELECT company_id 
FROM Company 
WHERE view_on_web = 'T' 
	
OPEN company_cursor  
FETCH NEXT FROM company_cursor INTO @company_id  

WHILE @@FETCH_STATUS = 0  
BEGIN
	SELECT @user_cnt = COUNT(*) FROM UserDefaultProfitCenter WHERE user_code = @user_code AND company_id = @company_id
	SELECT @user_id_cnt = COUNT(*) FROM UserDefaultProfitCenter WHERE user_id = @new_user_id AND company_id = @company_id
IF @user_cnt = 0 AND @user_id_cnt = 0
BEGIN
		SELECT @profit_ctr_id = MIN(profit_ctr_id) FROM ProfitCenter WHERE company_ID = @company_id 

	INSERT INTO UserDefaultProfitCenter (user_id, user_code, company_id, default_profit_ctr_id, date_added, added_by, date_modified, modified_by)
		VALUES (@new_user_id, @user_code, @company_id, @profit_ctr_id, @date_added, @added_by, @date_modified, @modified_by)
	
	IF @@ERROR <> 0 
	BEGIN
			SELECT @msg = 'Error adding user to UserDefaultProfitCenter table for company ' + right('00' + cast(@company_id as varchar(2)), 2)
		SELECT @errorcount = 1
		GOTO ExitProc 
	END
END

    FETCH NEXT FROM company_cursor INTO @company_id 
END

CLOSE company_cursor  
DEALLOCATE company_cursor

/**********/
ExitProc:
/**********/
IF @errorcount = 0
BEGIN
    SELECT @msg
    COMMIT TRANSACTION NEWUSER
END
ELSE
BEGIN
    SELECT @msg
    ROLLBACK TRANSACTION NEWUSER
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_new_user] TO PUBLIC
    AS [dbo];

