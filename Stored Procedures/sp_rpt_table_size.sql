create proc sp_rpt_table_size AS
/* **************************************************************
Generates a report of the top tables in the current database by size

************************************************************** */

	CREATE TABLE #temp (
	table_name sysname ,
	row_count INT,
	reserved_size VARCHAR(50),
	data_size VARCHAR(50),
	index_size VARCHAR(50),
	unused_size VARCHAR(50))
	SET NOCOUNT ON
	INSERT #temp
	EXEC sp_msforeachtable 'sp_spaceused ''?'''

	SELECT a.table_name,
	(select crdate from sysobjects where name = a.table_name and xtype in ('U', 'S')) as date_created,
	a.row_count,
	COUNT(*) AS col_count,
	case when round(convert(float, replace(a.data_size, ' KB', '')) / 1024, 2) >= 1024 then
		convert(varchar(10), round(convert(float, replace(a.data_size, ' KB', '')) / 1024 / 1024, 2)) + ' GB'
		else
			case when round(convert(float, replace(a.data_size, ' KB', '')) / 1024, 2) >= 1 then
				convert(varchar(10), round(convert(float, replace(a.data_size, ' KB', '')) / 1024, 2)) + ' MB'
			else
				convert(varchar(10), round(convert(float, replace(a.data_size, ' KB', '')), 2)) + ' KB'
			end
	end as size
	-- , convert(float, replace(a.data_size, ' KB', '')) / 1024 / 1024 + ' GB'
	FROM #temp a
	INNER JOIN information_schema.columns b
	ON a.table_name collate database_default
	= b.table_name collate database_default
	GROUP BY a.table_name, a.row_count, a.data_size
	ORDER BY CAST(REPLACE(a.data_size, ' KB', '') AS integer) DESC

	DROP TABLE #temp


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_table_size] TO [EQAI]
    AS [dbo];

