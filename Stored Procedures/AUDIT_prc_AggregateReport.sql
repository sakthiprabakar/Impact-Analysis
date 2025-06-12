CREATE PROCEDURE [dbo].[AUDIT_prc_AggregateReport]
	@DATE_FROM 			nvarchar(50)	= NULL,
	@DATE_TO 			nvarchar(50)	= NULL,
    @WHERE				nvarchar(4000)	= NULL,
	@ROW_COUNT 			int 			= NULL,
	@GroupByDate 		tinyint 		= 1,
	@GroupByTableName 	bit 			= 0,
	@GroupByMODIFIED_BY bit 			= 0,
	@GroupByACTION 		bit 			= 0,
	@GroupByAPPLICATION bit 			= 0,
	@GroupByCOMPUTER 	bit 			= 0
AS
DECLARE	@sqlstr nvarchar(4000)
DECLARE	@DateExpression varchar(8000)
DECLARE	@DateFieldName varchar(20)
DECLARE @SearcheableName nvarchar(261)
declare @len int
declare @ver7 bit
declare @ver2000 bit
declare @WhereSql nvarchar(4000)
declare @cmptlvl int
Select @cmptlvl = t1.cmptlevel 
from master.dbo.sysdatabases t1
where t1.[name]=DB_NAME()
set @ver7 = 0
IF @cmptlvl < 80 set @ver7 = 1
set @ver2000 = 0
IF @cmptlvl < 90 set @ver2000 = 1
IF @GroupByDate not in (0,1,2,3,4) 
BEGIN
  RAISERROR ('@GroupByDate must be one of: 0,1,2,3,4',16,1)
  RETURN -1
END
if (select count(*) from ##Filter where [index]='DATABASE') = 0
	insert into ##Filter([index], [value]) values('DATABASE', '%')
if (select count(*) from ##Filter where [index]='TABLE_NAME') = 0
	insert into ##Filter([index], [value]) values('TABLE_NAME', '%')
if (select count(*) from ##Filter where [index]='TABLE_OWNER') = 0
	insert into ##Filter([index], [value]) values('TABLE_OWNER', '%')
if (select count(*) from ##Filter where [index]='USER_NAME') = 0
	insert into ##Filter([index], [value]) values('USER_NAME', '%')
if (select count(*) from ##Filter where [index]='ACTION_ID') = 0
	insert into ##Filter([index], [value]) values('ACTION_ID', '%')
if (select count(*) from ##Filter where [index]='HOST_NAME') = 0
	insert into ##Filter([index], [value]) values('HOST_NAME', '%')
if (select count(*) from ##Filter where [index]='APP_NAME') = 0
	insert into ##Filter([index], [value]) values('APP_NAME', '%')
SET @DateExpression = 
  CASE
   WHEN @GroupByDate = 0 
    THEN ''
   WHEN @GroupByDate = 1 
    THEN 'LEFT(CONVERT(varchar(20), convert(datetime,MODIFIED_DATE), 100),14) + RIGHT(CONVERT(varchar(20), convert(datetime,MODIFIED_DATE), 100),2) '
   WHEN @GroupByDate = 2
    THEN 'CONVERT(varchar(20), CONVERT(datetime,MODIFIED_DATE), 107) '
   WHEN @GroupByDate = 3 
    THEN 'LEFT(CONVERT(varchar(20), CONVERT(datetime,MODIFIED_DATE), 107),4)+RIGHT(CONVERT(varchar(20), CONVERT(datetime,MODIFIED_DATE), 107),4) '
   WHEN @GroupByDate = 4
    THEN 'RIGHT(CONVERT(varchar(20), CONVERT(datetime,MODIFIED_DATE), 107),4) '
  END  
SET @DateFieldName = 
  CASE
   WHEN @GroupByDate = 0 
    THEN ''
   WHEN @GroupByDate = 1 
    THEN ' AS ''Hour'''
   WHEN @GroupByDate = 2
    THEN ' AS ''Date'''
   WHEN @GroupByDate = 3 
    THEN ' AS ''Month'''
   WHEN @GroupByDate = 4
    THEN ' AS ''Year'''
  END  
SET @sqlstr = '
select TOP'+STR(CASE WHEN @ROW_COUNT is null THEN 99999 ELSE @ROW_COUNT END)+' * from (
SELECT sum(DATA_COUNT) AS [#], t.[DATABASE] as ''Database'''+
 CASE
  WHEN @GroupByTableName = 0 THEN ''
  ELSE ', TABLE_NAME as [Table Name], TABLE_SCHEMA as [' +
	CASE @ver2000 WHEN 1 THEN 'Owner' ELSE 'Table Schema' END +']'
 END +
 CASE
  WHEN @GroupByMODIFIED_BY = 0 THEN ''
  ELSE ', MODIFIED_BY as [Modified By]'
 END +
 CASE
  WHEN @GroupByACTION = 0 THEN ''
  ELSE ', CASE t.AUDIT_ACTION_ID 
              WHEN 1 THEN ''Update'' 
              WHEN 2 THEN ''Insert'' 
              WHEN 3 THEN ''Delete'' 
          END AS [Action]'
 END +
 CASE
  WHEN @GroupByAPPLICATION = 0 THEN ''
  ELSE ', APPLICATION as [Application]'
 END +
 CASE
  WHEN @GroupByCOMPUTER = 0 THEN ''
  ELSE ', COMPUTER as [Computer]'
 END +
 CASE
  WHEN @DateExpression <> '' 
  THEN ', '
  ELSE ''
 END +
@DateExpression+
@DateFieldName
set @sqlstr = @sqlstr +
 ' FROM (
		SELECT 
			  [DATABASE],
			  TABLE_NAME,
			  TABLE_SCHEMA,
			  AUDIT_ACTION_ID, 
			  MODIFIED_BY, 
			  CONVERT(varchar(20), MODIFIED_DATE, 113) AS MODIFIED_DATE,
			  HOST_NAME AS COMPUTER,
			  APP_NAME as APPLICATION,
   			  count(distinct convert(nvarchar(100), t.AUDIT_LOG_TRANSACTION_ID)) [DATA_COUNT]
		from dbo.AUDIT_LOG_TRANSACTIONS t 
			inner join dbo.AUDIT_LOG_DATA d
			on t.AUDIT_LOG_TRANSACTION_ID=d.AUDIT_LOG_TRANSACTION_ID
		group by 
			[DATABASE] ,
			[TABLE_NAME] ,
			[TABLE_SCHEMA] ,
			[AUDIT_ACTION_ID] ,
			[HOST_NAME] ,
			[APP_NAME] ,
			[MODIFIED_BY] ,
			[MODIFIED_DATE] 
	) t
	inner join ##Filter f1 on f1.[index]=''TABLE_NAME'' and t.TABLE_NAME like Replace(f1.[value]' + case @ver7 when 0 then ' collate database_default' else '' end + ', ''['', ''[[]'')
	inner join ##Filter f2 on f2.[index]=''TABLE_OWNER'' and t.TABLE_SCHEMA like Replace(f2.[value]' + case @ver7 when 0 then ' collate database_default' else '' end + ', ''['', ''[[]'')
	inner join ##Filter f3 on f3.[index]=''APP_NAME'' and t.APPLICATION like Replace(f3.[value]' + case @ver7 when 0 then ' collate database_default' else '' end + ', ''['', ''[[]'')
	inner join ##Filter f4 on f4.[index]=''HOST_NAME'' and t.COMPUTER like Replace(f4.[value]' + case @ver7 when 0 then ' collate database_default' else '' end + ', ''['', ''[[]'')
	inner join ##Filter f5 on f5.[index]=''USER_NAME'' and t.MODIFIED_BY like Replace(f5.[value]' + case @ver7 when 0 then ' collate database_default' else '' end + ', ''['', ''[[]'')
	inner join ##Filter f6 on f6.[index]=''ACTION_ID'' and Cast(t.AUDIT_ACTION_ID as char(1)) like Replace(f6.[value]' + case @ver7 when 0 then ' collate database_default' else '' end + ', ''['', ''[[]'')
	inner join ##Filter f7 on f7.[index]=''DATABASE'' and t.[DATABASE] like Replace(f7.[value]' + case @ver7 when 0 then ' collate database_default' else '' end + ', ''['', ''[[]'')
	where [DATA_COUNT]=[DATA_COUNT]
' +
 CASE
  WHEN @DATE_FROM is NULL THEN ''
  ELSE ' AND CONVERT(DATETIME,MODIFIED_DATE) >= '''+CONVERT(varchar(20),@DATE_FROM,120)+''''
 END +
 CASE
  WHEN @DATE_TO is NULL THEN ''
  ELSE ' AND CONVERT(DATETIME,MODIFIED_DATE) < '''+CONVERT(varchar(20),@DATE_TO,120)+''''
 END +
CASE
  WHEN @DateExpression = ''  THEN ' GROUP BY '
  ELSE ' GROUP BY ' + @DateExpression + ','
 END
 + '[DATABASE], ' +
 CASE WHEN @GroupByTableName 	= 1 	THEN ' TABLE_SCHEMA, TABLE_NAME,' 	ELSE '' END +
 CASE WHEN @GroupByMODIFIED_BY 	= 1 	THEN ' MODIFIED_BY,' 	ELSE '' END +
 CASE WHEN @GroupByACTION 	= 1 	THEN ' AUDIT_ACTION_ID,' 	ELSE '' END +
 CASE WHEN @GroupByAPPLICATION 	= 1 	THEN ' APPLICATION,' 	ELSE '' END +
 CASE WHEN @GroupByCOMPUTER 	= 1 	THEN ' COMPUTER,' 	ELSE '' END
set @len = len(@sqlstr)
if substring(@sqlstr, @len, 1) = ','
begin
	set @sqlstr = substring(@sqlstr,1,@len-1)
end
set @sqlstr = @sqlstr + ') [table]'
if @WHERE IS NOT NULL
begin
	set @WhereSql = @sqlstr+' where '+@WHERE
	exec sp_executesql @WhereSql
end
else
begin
	exec sp_executesql @sqlstr
end
RETURN @@ERROR
