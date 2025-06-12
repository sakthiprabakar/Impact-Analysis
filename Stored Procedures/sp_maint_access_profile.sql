
CREATE PROCEDURE sp_maint_access_profile
	@debug		int,
	@access_id	int,
	@db_type	varchar(10)

AS
/***************************************************************************************************
LOAD TO PLT_AI
Filename:	L:\Apps\SQL\EQAI\PLT_AI\sp_maint_access_profile
PB Object(s):	d_profile_access

This SP retrieves the Profile access values for the Access Maintenance screen.

10/18/2006 SCC	Created
10/01/2007 WAC	Changed tables with EQAI prefix to EQ.  Added db_type to EQDatabase query.
07/03/2014  AM - Removed database_name and added company_id.

sp_maint_access_profile 1, 1099, 'DEV'

select * from ProfileAccess
***************************************************************************************************/
DECLARE @server		varchar(20),
	@database	varchar(20),
	@company_id int,
	@execute_sql	varchar(2000),
	@db_count	int,
	@result_count	int

-- Create a table to return access values
CREATE TABLE #results (
	access_id 	int NOT NULL,
	company_id	int NULL,
	profile_tracking	char(1) NULL,
	approval		char(1) NULL,
	broker			char(1) NULL,
	approval_scan		char(1) NULL
)

-- Insert dummy record to control setting the access
INSERT #results (access_id, company_id, profile_tracking, approval, broker, approval_scan)
VALUES (@access_id, 0, NULL,NULL,NULL,NULL)

-- Get the database references
SELECT C.company_id,0 as process_flag ,D.server_name
INTO #tmp_database
FROM EQConnect C  , EQDatabase D
WHERE C.company_id  = D.company_id
 AND d.database_name = c.db_name_eqai
 AND C.db_type = D.db_type
 AND C.db_type = @db_type
 
SELECT @db_count =   @@rowcount 

-- Set the access for the profile_tracking column
WHILE @db_count > 0
BEGIN
	SET ROWCOUNT 1
	SELECT @server = server_name, @company_id = company_id 
	FROM #tmp_database WHERE process_flag = 0
	SET ROWCOUNT 0

	-- This is Profile Screen access
	SET @execute_sql = 'INSERT #results SELECT '
	+ CONVERT(varchar(10), @access_id)
    + ',' + CONVERT(varchar(10), @company_id)
	+ ' , + Access.profile_tracking, Access.approval, Access.broker, Access.approval_scan '
	+ ' FROM ' +  ' Access '
	+ ' WHERE Access.group_id = ' + CONVERT(varchar(10), @access_id) 
	+ ' AND Access.company_id = ' + CONVERT(varchar(10), @company_id) 

	IF @debug = 1 print  @execute_sql 

	EXECUTE (@execute_sql)
	SELECT @db_count = @db_count - 1

	SET ROWCOUNT 1
	UPDATE #tmp_database SET process_flag = 1 WHERE process_flag = 0
	SET ROWCOUNT 0
END
SET ROWCOUNT 0

-- Add company records if none were inserted from the company databases
-- this is for a new access record
SELECT @result_count = COUNT(*) FROM #results
IF @result_count = 1
INSERT #results SELECT @access_id, #tmp_database.company_id, NULL,NULL,NULL,NULL
FROM #tmp_database ORDER BY company_id

SELECT * FROM #results ORDER BY company_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_maint_access_profile] TO [EQAI]
    AS [dbo];

