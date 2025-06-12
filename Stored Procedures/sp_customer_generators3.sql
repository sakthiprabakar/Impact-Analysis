

CREATE PROCEDURE sp_customer_generators3
	@email  varchar(60)
AS

/********************
sp_customer_generators3:

Returns the complete list of generators for a customer.

examples:
	exec sp_customer_generators3 'sreynolds@contactpsc.com'

LOAD TO PLT_AI

02/22/2005 JPB	Created
10/01/2007 WAC	Removed references to NTSQL1.  Changed EQAICONNECT to EQCONNECT.  Removed Server_name from
		curCompanieGL cursor which leaves only EQConnect as part of the cursor.
**********************/

SET NOCOUNT ON

DECLARE @execute_sql varchar(8000),
	@strSnippet1 varchar(8000),
	@strSnippet2 varchar(8000),
	@strSnippet3 varchar(8000),
	@strSnippet4 varchar(8000),
	@strSnippet5 varchar(8000),
	@strSnippet6 varchar(8000),
	@strDBName varchar(8000),
	@intCompany_ID int

SET @strSnippet1 = 'INSERT #GENERATORLIST SELECT DISTINCT G.GENERATOR_NAME,G.epa_id FROM '
SET @strSnippet2 = '.DBO.GENERATOR G INNER JOIN '
SET @strSnippet3 = '.DBO.APPROVAL A ON G.generator_id = A.generator_id WHERE A.CUSTOMER_ID IN (select customer_id from b2bxcontact where contact_id = (select contact_id from contact where email = ''' + @email + ''' and web_password is not null)) AND G.GENERATOR_NAME <> '''' AND A.CURR_STATUS_CODE=''A'' '
SET @strSnippet4 = 'INSERT #GENERATORLIST SELECT DISTINCT G.GENERATOR_NAME,G.epa_id FROM '
SET @strSnippet5 = '.DBO.GENERATOR G INNER JOIN '
SET @strSnippet6 = '.DBO.TSDFAPPROVAL A ON G.generator_id = A.generator_id WHERE A.CUSTOMER_ID IN (select customer_id from b2bxcontact where contact_id = (select contact_id from contact where email = ''' + @email + ''' and web_password is not null)) AND A.TSDF_APPROVAL_STATUS=''A'' AND G.GENERATOR_NAME <> '''' '

CREATE TABLE #GENERATORLIST (GENERATOR_NAME varchar(40), epa_id varchar(12))

--DECLARE curCompaniesGL CURSOR FOR
--SELECT SERVER_NAME + '.' + D.DATABASE_NAME AS DATABASE_NAME, Company_ID
--FROM EQAIDATABASE D INNER JOIN EQAICONNECT C ON C.DB_NAME_EQAI = D.DATABASE_NAME 
--WHERE C.DB_NAME_SHARE = DB_NAME(DB_ID())
---- SHORTCUT:
--AND C.company_id in (2,3,12,14,15,21,22,23,24)

DECLARE curCompaniesGL CURSOR FOR
SELECT db_name_eqai AS DATABASE_NAME, Company_ID
FROM EQCONNECT 
WHERE db_type = 'PROD' AND company_id in (2,3,12,14,15,21,22,23,24)
--  Since DB_TYPE is not passed as a parameter we'll have to assume this is a production query.  At the time of this
--  writing the same database names would be returned for the given list of companies regardless of db_type.  If the
--  database names for a given company vary based on db_type then this query will have to be revisited.

OPEN curCompaniesGL
FETCH NEXT FROM curCompaniesGL
INTO @strDBName, @intCompany_ID
WHILE @@FETCH_STATUS = 0 BEGIN
	IF @intCompany_id <> 14
		SET @execute_sql = @strSnippet1 + @strDBName + @strSnippet2 + @strDBName + @strSnippet3
	ELSE
		SET @execute_sql = @strSnippet4 + @strDBName + @strSnippet5 + @strDBName + @strSnippet6
	EXEC(@execute_sql)
	FETCH NEXT FROM curCompaniesGL
	INTO @strDBName, @intCompany_ID
END
CLOSE curCompaniesGL
DEALLOCATE curCompaniesGL

SET NOCOUNT OFF

SELECT DISTINCT GENERATOR_NAME, epa_id FROM #GENERATORLIST

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_generators3] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_generators3] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_generators3] TO [EQAI]
    AS [dbo];

