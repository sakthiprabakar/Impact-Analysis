
CREATE PROCEDURE sp_biennial_validate_allowed_characters
	@biennial_id int
AS

/*
	Usage: sp_biennial_validate_allowed_characters 1510

select * FROM EQ_Extract..BiennialReportSourceData
where generator_state = 'PA'

SELECT * FROM EQ_Extract.dbo.BiennialReportSourceDataValidation where biennial_id = 1510

SELECT * FROM EQ_Extract.dbo.BiennialLog order by biennial_id desc

delete from EQ_Extract.dbo.BiennialReportSourceDataValidation where biennial_id = 1510
and validation_message like 'Illegal Character %'

    INSERT INTO EQ_Extract.dbo.BiennialReportSourceDataValidation     SELECT DISTINCT      'Illegal Character < or > in field: data_source,     src.*    FROM EQ_Extract..BiennialReportSourceData src    WHERE src.biennial_id = 1510    AND (ISNULL(data_source, '') LIKE '%<%'     OR ISNULL(data_source, '') LIKE '%>%')    
    	
*/
BEGIN

	declare @newline varchar(5) = char(13)+char(10), @sql varchar(max)
	
	CREATE TABLE #columns (
		TABLE_QUALIFIER	sysname,
		TABLE_OWNER	sysname,
		TABLE_NAME	sysname,
		COLUMN_NAME	sysname,
		DATA_TYPE	smallint,
		TYPE_NAME	varchar(100),
		PRECISION	int,
		LENGTH	int,
		SCALE	smallint,
		RADIX	smallint,
		NULLABLE	smallint,
		REMARKS	varchar(254),
		COLUMN_DEF	nvarchar(4000),
		SQL_DATA_TYPE	smallint,
		SQL_DATETIME_SUB	smallint,
		CHAR_OCTET_LENGTH	int,
		ORDINAL_POSITION	int,
		IS_NULLABLE	varchar(254),
		SS_DATA_TYPE	tinyint
	)
	
	insert #columns exec EQ_Extract..sp_columns BiennialReportSourceData

	declare @i int
	select @i = min(ordinal_position) from #columns where type_name like '%char%'
	
	WHILE @i <= (select max(ordinal_position) from #columns where type_name like '%char%') BEGIN

		select @sql = '
		INSERT INTO EQ_Extract.dbo.BiennialReportSourceDataValidation
		 SELECT DISTINCT 
			''Illegal Character < or > in field: ' + c.column_name + ''',
			src.*
		FROM EQ_Extract..BiennialReportSourceData src
		WHERE src.biennial_id = ' + convert(varchar(20), @biennial_id ) + '
		AND (ISNULL(' + c.column_name + ', '''') LIKE ''%<%''
			OR ISNULL(' + c.column_name + ', '''') LIKE ''%>%'')
		'
		from #columns c
		where c.ordinal_position = @i
		
--		select @sql as sql

		exec (@sql)
		
		select @i = min(ordinal_position) from #columns where type_name like '%char%' and ordinal_position > @i
	
	END
	
END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_allowed_characters] TO [EQWEB]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_allowed_characters] TO [COR_USER]
    AS [dbo];

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_biennial_validate_allowed_characters] TO [EQAI]
    AS [dbo];
GO
