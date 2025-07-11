﻿
CREATE PROCEDURE sp_extract_rpt_outbound
	@return_schema_only CHAR(1) = 'F',
	@return_count_only  CHAR(1) = 'F',
	@filter_expression  VARCHAR(MAX) = '',
	@start              INT = 1,
	@maxct              INT = 15,
	@sort               NVARCHAR(200) = NULL
AS
  SET nocount ON
IF @start is null
set @start = 1

--DECLARE @contact_id INT
--SET @contact_id = 101298 -- Contacts should use their contact_id
--SET @contact_id = 0 -- Associates should use 0

declare @stmt varchar(max)
declare @ubound int

IF @sort IS NULL
	set @sort = 'receipt_id desc'

IF @return_schema_only = 'T'
	set @sort = 'receipt_id desc'

IF @filter_expression IS NULL OR LEN(@filter_expression) = 0
	set @filter_expression = '1=1'

-- replace single quote with escaped quote
set @filter_expression = REPLACE(@filter_expression, '''''', '''')

IF @start < 1 SET @start = 1
  IF @maxct < 1 SET @maxct = 1
  SET @ubound = @start + @maxct

	declare @main_sql varchar(max) = ''

	SET @main_sql = 'SELECT
					row_number() over(order by ' + @sort + ') as ROWID,
				    * FROM view_extract_rpt_outbound
			WHERE 1=1
				AND ' + @filter_expression


set @main_sql = @main_sql +
			' AND 1 = CASE
						WHEN ''' + @return_schema_only + ''' = ''T'' THEN 0
						ELSE 1
			 END'


--print @main_sql
IF @return_count_only = 'F'
BEGIN
  SET @STMT = ' SELECT *
                FROM (' + @main_sql +' ) AS tbl
                WHERE  ROWID >= ' + CONVERT(varchar(9), @start) + ' AND
                       ROWID <  ' + CONVERT(varchar(9), @ubound)
  --PRINT @stmt
	EXEC (@STMT) -- return slice
END

ELSE

BEGIN
SET @STMT = ' SELECT COUNT(*) record_count
                FROM (' + @main_sql +' ) AS tbl'
	EXEC (@STMT)
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_extract_rpt_outbound] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_extract_rpt_outbound] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_extract_rpt_outbound] TO [EQAI]
    AS [dbo];

