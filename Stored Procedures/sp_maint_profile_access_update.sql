
CREATE PROCEDURE sp_maint_profile_access_update
	@debug		int,
	@access_id	int,
	@company_id	int,
	@profile_tracking	char(1),
	@approval	char(1),
	@broker		char(1),
	@scan		char(1),
	@db_type	varchar(10)

AS
/***************************************************************************************************
LOAD TO PLT_AI
Filename:	L:\Apps\SQL\EQAI\PLT_AI\sp_maint_profile_access_update
PB Object(s):	d_profile_access

This SP updates the Profile access changes from the Access Maintenace screen to a company database.

10/18/2006 SCC	Created
10/02/2007 WAC	Changed tables with EQAI prefix to EQ.  Added db_type to EQDatabase query.
07/03/2014  AM - Commented code.

sp_maint_profile_access_update 1, 1099, 21, 'S', 'S', 'N', 'A', 'DEV'

select * from ProfileAccess 
***************************************************************************************************/
DECLARE @server		varchar(20),
	@database	varchar(20),
	@execute_sql	varchar(2000)

-- Get the database references
-- AM  - Commented code since we are not using company db anymore.
-- SELECT	@server = D.server_name, 
--	@database = D.database_name
-- FROM EQConnect C, EQDatabase D
-- WHERE C.db_name_eqai = D.database_name
-- AND C.db_type = D.db_type
-- AND C.db_type = @db_type
-- AND C.company_id = @company_id

-- Set the access values for the Profile columns
SET @execute_sql = 'UPDATE Access SET '
	+ ' profile_tracking = ''' + @profile_tracking + ''''
	+ ' , approval = ''' + @approval + ''''
	+ ' , broker = ''' + @broker + ''''
	+ ' , approval_scan = ''' + @scan + ''''
	+ ' FROM ' + 'Company, ' + ' Access '
	+ ' WHERE Access.group_id = ' + CONVERT(varchar(10), @access_id) 
	+ ' AND Company.company_id = ' + CONVERT(varchar(10), @company_id) 
     
IF @debug = 1 print @execute_sql

EXECUTE (@execute_sql)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_maint_profile_access_update] TO [EQAI]
    AS [dbo];

