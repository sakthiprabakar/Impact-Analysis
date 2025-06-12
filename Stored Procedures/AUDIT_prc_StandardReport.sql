CREATE PROCEDURE [dbo].[AUDIT_prc_StandardReport]
  (	@DATE_FROM 			nvarchar(50)	= NULL,
	@DATE_TO 			nvarchar(50)	= NULL,
    @OLD_VALUE			varchar(8000)    = NULL,    
    @NEW_VALUE			varchar(8000)    = NULL,    
    @WHERE				nvarchar(4000)   = NULL,
    @ROW_COUNT			int              = NULL)
AS
declare 
@strSql nvarchar(4000),
@ver7 bit,
@ver2000 bit,
@WhereSql nvarchar(4000),
@cmptlvl int
Select @cmptlvl = t1.cmptlevel 
from master.dbo.sysdatabases t1
where t1.[name]=DB_NAME()
set @ver7 = 0
IF @cmptlvl < 80 set @ver7 = 1
set @ver2000 = 0
IF @cmptlvl < 90 set @ver2000 = 1
set nocount on
/* Set replacement values for filter parameter */
if (select count(*) from ##Filter where [index]='DATABASE') = 0
	insert into ##Filter([index], [value]) values('DATABASE', '%')
if (select count(*) from ##Filter where [index]='TABLE_OWNER') = 0
	insert into ##Filter([index], [value]) values('TABLE_OWNER', '%')
if (select count(*) from ##Filter where [index]='TABLE_NAME') = 0
	insert into ##Filter([index], [value]) values('TABLE_NAME', '%')
if (select count(*) from ##Filter where [index]='FIELD_NAME') = 0
	insert into ##Filter([index], [value]) values('FIELD_NAME', '%')
if (select count(*) from ##Filter where [index]='USER_NAME') = 0
	insert into ##Filter([index], [value]) values('USER_NAME', '%')
if (select count(*) from ##Filter where [index]='ACTION_ID') = 0
	insert into ##Filter([index], [value]) values('ACTION_ID', '%')
if (select count(*) from ##Filter where [index]='HOST_NAME') = 0
	insert into ##Filter([index], [value]) values('HOST_NAME', '%')
if (select count(*) from ##Filter where [index]='APP_NAME') = 0
	insert into ##Filter([index], [value]) values('APP_NAME', '%')
IF @DATE_FROM IS NULL
   SET @DATE_FROM= '1/1/1900'
IF @DATE_TO IS NULL
   SET @DATE_TO = '1/1/3900'
IF @OLD_VALUE IS NULL
   SET @OLD_VALUE = '%'
IF @NEW_VALUE IS NULL
   SET @NEW_VALUE = '%'
IF @ROW_COUNT IS NULL
   SET @ROW_COUNT = 99999
/* Get Object ID */
--SELECT @obj_id = object_id(@full_table_name)
set @strSql = '
declare
@DATE_FROM      datetime,
@DATE_TO        datetime,
@OLD_VALUE      varchar(8000),
@NEW_VALUE      varchar(8000),
@ROW_COUNT      int
set @DATE_FROM = '''+convert(nvarchar(100), @DATE_FROM, 120)+'''
set @DATE_TO = '''+convert(nvarchar(100), @DATE_TO, 120)+'''
set @OLD_VALUE = '''+@OLD_VALUE+'''
set @NEW_VALUE = '''+@NEW_VALUE+'''
set @ROW_COUNT = '+cast(@ROW_COUNT as nvarchar(100))+'
select top '+cast(@ROW_COUNT as nvarchar(100))+' * from (
   SELECT  t.[DATABASE] ''Database'',
		   t.TABLE_NAME ''Table Name'',
		   t.TABLE_SCHEMA ''' +
	CASE @ver2000 WHEN 1 THEN 'Owner' ELSE 'Table Schema' END +''',
           CASE    t.AUDIT_ACTION_ID
               WHEN 2 then ''Insert''
               WHEN 1 then ''Update''
               WHEN 3 then ''Delete''
           END         ''Action'',
           KEY1 as ''Key 1'',
           KEY2 as ''Key 2'',
           KEY3 as ''Key 3'',
           KEY4 as ''Key 4'',
		   KEY5 as ''Key 5'',
		   KEY6 as ''Key 6'',
		   KEY7 as ''Key 7'',
		   KEY8 as ''Key 8'',
		   KEY9 as ''Key 9'',
		   KEY10 as ''Key 10'',
		   KEY11 as ''Key 11'',
		   KEY12 as ''Key 12'',
           d.COL_NAME ''Column Name'',
           d.OLD_VALUE ''Old Value'',
           d.NEW_VALUE ''New Value'',
           t.MODIFIED_BY ''Modified By'',
           t.MODIFIED_DATE ''Modified Date'',
           t.HOST_NAME ''Computer'',
           t.APP_NAME ''Application''
    FROM dbo.AUDIT_LOG_TRANSACTIONS t
    JOIN dbo.AUDIT_LOG_DATA d ON d.AUDIT_LOG_TRANSACTION_ID = t.AUDIT_LOG_TRANSACTION_ID,
	(select [value] from ##Filter where [index]=''DATABASE'') t_db,-- database
	(select [value] from ##Filter where [index]=''TABLE_OWNER'') t_owners,-- owners
	(select [value] from ##Filter where [index]=''TABLE_NAME'') t_tables,-- tables
	(select [value] from ##Filter where [index]=''FIELD_NAME'') t_columns,-- columns
	(select [value] from ##Filter where [index]=''USER_NAME'') t_users,-- users
	(select [value] from ##Filter where [index]=''ACTION_ID'') t_actions,-- actions
	(select [value] from ##Filter where [index]=''HOST_NAME'') t_hosts,-- hosts
	(select [value] from ##Filter where [index]=''APP_NAME'') t_apps -- applications
    WHERE  
	t.[DATABASE] like Replace(t_db.[value] ' +
	case @ver7 when 0 then ' collate database_default'
		else '' end +
		', ''['', ''[[]'') 
	  AND t.TABLE_SCHEMA like Replace(t_owners.[value] ' +
	case @ver7 when 0 then ' collate database_default'
		else '' end +
		', ''['', ''[[]'') 
	  AND t.TABLE_NAME like Replace(t_tables.[value] ' +
	case @ver7 when 0 then ' collate database_default'
		else '' end +
		', ''['', ''[[]'') 
      AND d.COL_NAME like Replace(t_columns.[value] 
	' +
	case @ver7 when 0 then ' collate database_default'
		else '' end +
		', ''['', ''[[]'')
      AND t.MODIFIED_BY like Replace(t_users.[value] ' +
	case @ver7 when 0 then ' collate database_default'
		else '' end +
		', ''['', ''[[]'')
      AND t.MODIFIED_DATE >= @DATE_FROM
      AND t.MODIFIED_DATE < @DATE_TO
      AND Cast(t.AUDIT_ACTION_ID as char(1)) like Replace(t_actions.[value] ' +
	case @ver7 when 0 then ' collate database_default'
		else '' end +
		', ''['', ''[[]'')
      AND ((d.OLD_VALUE IS NULL AND @OLD_VALUE = ''%'') OR (d.OLD_VALUE LIKE @OLD_VALUE))
      AND ((d.NEW_VALUE IS NULL AND @NEW_VALUE = ''%'') OR (d.NEW_VALUE LIKE @NEW_VALUE))
      AND t.HOST_NAME like Replace(t_hosts.[value] ' +
	case @ver7 when 0 then ' collate database_default'
		else '' end +
		', ''['', ''[[]'')
      AND t.APP_NAME like Replace(t_apps.[value] ' +
	case @ver7 when 0 then ' collate database_default'
		else '' end +
		', ''['', ''[[]'')
) [table]'
if @WHERE IS NOT NULL
begin
	set @WhereSql = @strSql+' where '+@WHERE
	exec sp_executesql @WhereSql
end
else
	exec sp_executesql @strSql
RETURN @@ERROR
