
CREATE PROCEDURE sp_extract_rpt_receipt_price
	@return_schema_only char(1) = 'F',
	@return_count_only char(1) = 'F',
	@filter_expression varchar(max) = '',
	@start  int = 1,
	@maxct  int = 15,
	@sort   nvarchar(200) = NULL
	AS

SET NOCOUNT ON

/*
exec sp_extract_rpt_receipt_price 'F', 'T', 'receipt_date BETWEEN ''04/01/2009'' AND ''04/30/2009'' ', 0, 9999, null
exec sp_extract_rpt_receipt_price 'F', 'F', 'receipt_date BETWEEN ''04/01/2009'' AND ''04/30/2009'' '
exec sp_extract_rpt_receipt_price @return_schema_only=N'F',@return_count_only=N'F',@filter_expression=N'[generator_id] IN (51726,60306,62245,16751,28945,21978,36400,31607,11483,70965,82918,52159,82409,82571,26823,81198,82408,79280,16954,42802,41989,18908,41891,80590,11279,31389,30118,27927,38359,28793,45145,41154,53693,15808,64930,26847,29387,51688,12826,20064,32233,73394,52705,68280,58453,72838,4843,37619,28067,4811,3244,52783,30251,68052,3815,77725,51686,80715,77531,46760,40865,25953,75506,7887,82204,37402,71746,3242,45082,12729,75619,699,44704,70649,30740,85295,10213,25202,44216,59446,11143,30108,5164,25330,56504,62797,65085,71764,5821,55428,65834,11856,20159,36569,30632,28787,43647,60138,83470,43249,42618,35756,21028,61233,21271,28075,36119,43270,38695,37358,37369,36330,36348,35888,35614,35640,34981,34982,35008,33485,28526,21323,56463,13926,35020,71608,59135,60221,51266,59840,56416,40040,28832,3670,52028,66704,52187,1327,9316,71200,67578,77842,64155,68810,22030,21292,13160,26140,24726,5638,58546,41936,51797,36322,16080,25109,45752,44685,10939,1372) ',@start=0,@maxct=20,@sort=N'workorder_id'
*/

IF @start is null
set @start = 1

--DECLARE @contact_id INT
--SET @contact_id = 101298 -- Contacts should use their contact_id
--SET @contact_id = 0 -- Associates should use 0

declare @stmt varchar(max)
declare @ubound int

IF @sort IS NULL
	set @sort = 'receipt_id desc, company_id, profit_ctr_id'

IF @return_schema_only = 'T'
	set @sort = 'receipt_id desc, company_id, profit_ctr_id'

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
				    * FROM view_extract_rpt_receipt_price
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
    ON OBJECT::[dbo].[sp_extract_rpt_receipt_price] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_extract_rpt_receipt_price] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_extract_rpt_receipt_price] TO [EQAI]
    AS [dbo];

