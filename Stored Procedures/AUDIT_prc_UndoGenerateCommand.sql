CREATE PROCEDURE [dbo].[AUDIT_prc_UndoGenerateCommand]
@UndoLogId int,
@CheckError bit,
@Print nvarchar(4000) OUTPUT,
@SQL nvarchar(4000) OUTPUT
AS
-- Check if for each Undelete action in ##UndoLog there are all columns in ##UndoColumns. If not, the Undelete
-- cannot be done
BEGIN
DECLARE @Comment varchar(8000)
DECLARE @UndoStatus int
DECLARE @UndoAction tinyint
DECLARE @TabName nvarchar(128)
DECLARE @ColName nvarchar(128)
DECLARE @PK_data nvarchar(4000)
DECLARE @OLD_VALUE nvarchar(4000)
DECLARE @HOST_NAME nvarchar(25)
DECLARE @APP_NAME nvarchar(100)
DECLARE @MODIFIED_BY nvarchar(30)
DECLARE @MODIFIED_DATE datetime
DECLARE @ColumnList nvarchar(4000)
DECLARE @ColumnDataList nvarchar(4000)
DECLARE @xtype int
DECLARE @IdentityCount int
DECLARE @SQL_OUT nvarchar(4000)
SET NOCOUNT OFF
  SELECT @UndoAction=UndoAction, @TabName=TabName, @PK_data=PK_data, @ColName=ColName, @OLD_VALUE=replace(OLD_VALUE,'''',''''''),
         @HOST_NAME=[HOST_NAME], @APP_NAME=[APP_NAME], @MODIFIED_BY=MODIFIED_BY, @MODIFIED_DATE=MODIFIED_DATE,
         @UndoStatus=UndoStatus, @Comment=Comment
    FROM ##UndoLog
    WHERE UndoLogId=@UndoLogId
  SET @Print='********** '+LTRIM(STR(@UndoLogId))+' **********
'
  IF @UndoAction = 1
  BEGIN
    SELECT @xtype = c.xtype 
      FROM dbo.sysobjects o
      JOIN dbo.syscolumns c ON c.id = o.id
      WHERE o.id = OBJECT_ID(@TabName) and c.name = @ColName
    SET @SQL = 'UPDATE '+@TabName+' SET ['+@ColName+']='+ISNULL(
        CASE WHEN @xtype in (40, 41, 42, 43, 175, 239, 231, 167, 61, 58, 98, 240, 241)
              THEN ''''+@OLD_VALUE+'''' 
             WHEN @xtype in (173, 165)
              THEN 'CONVERT(varbinary(8000),'''+@OLD_VALUE+''')'
             WHEN @xtype in (36)
              THEN 'CONVERT(uniqueidentifier,'''+@OLD_VALUE+''')'
             ELSE @OLD_VALUE
         END,'null') + ' WHERE '+@PK_data+'
' + CASE WHEN @CheckError=1
      THEN 'set @ERROR=@@ERROR
'   ELSE ''
    END
    EXEC dbo.AUDIT_prc_UndoAddTriggersCheck @TabName, @UndoAction, @SQL, @SQL_OUT output
	set @SQL = @SQL_OUT
  END
  ELSE IF @UndoAction = 2 -- Undelete
  BEGIN
    SET @ColumnList = ''
    SET @ColumnDataList = ''
    DECLARE ColumnData CURSOR FOR
      SELECT ColName, OLD_VALUE FROM ##UndoColumns WHERE UndoLogId = @UndoLogId
    OPEN ColumnData
    FETCH NEXT FROM ColumnData INTO @ColName, @OLD_VALUE
    WHILE @@FETCH_STATUS = 0
    BEGIN
      SELECT @xtype = c.xtype 
      FROM dbo.sysobjects o
      JOIN dbo.syscolumns c ON c.id = o.id
      WHERE o.id = OBJECT_ID(@TabName) and c.name = @ColName
      IF @ColumnList <> ''
        SET @ColumnList = @ColumnList + ','
      IF @ColumnDataList <> ''
        SET @ColumnDataList = @ColumnDataList + ','
      SET @ColumnList = @ColumnList + '[' + @ColName + ']'
      SET @ColumnDataList = @ColumnDataList +
        CASE WHEN @xtype in (40, 41, 42, 43, 175, 239, 231, 167, 61, 58, 240, 241)
              THEN ''''+replace(@OLD_VALUE, '''', '''''')+'''' 
             WHEN @xtype in (173, 165)
              THEN 'CONVERT(varbinary(8000),'''+@OLD_VALUE+''')'
             WHEN @xtype in (36)
              THEN 'CONVERT(uniqueidentifier,'''+@OLD_VALUE+''')'
             ELSE @OLD_VALUE
         END
      FETCH NEXT FROM ColumnData INTO @ColName, @OLD_VALUE
    END
    DEALLOCATE ColumnData
	set @SQL = ''
    IF OBJECTPROPERTY(object_id(@TabName),'TableHasIdentity')=1
	begin
		select @IdentityCount = Count(*) from sys.identity_columns where object_id=object_id(@TabName) and @ColumnList like '%[' + name +']%'
		if @IdentityCount > 0
  			set @SQL = @SQL + 'SET IDENTITY_INSERT '+@TabName+' ON'
	end
	set @SQL = @SQL + '
INSERT INTO '+@TabName+' ('+@ColumnList+') VALUES ('+@ColumnDataList+')
' + CASE WHEN @CheckError=1
      THEN 'set @ERROR=@@ERROR
'   ELSE ''
    END 
	IF OBJECTPROPERTY(object_id(@TabName),'TableHasIdentity')=1
		if @IdentityCount > 0
  		set @SQL = @SQL + 'SET IDENTITY_INSERT '+@TabName+' OFF'
    EXEC dbo.AUDIT_prc_UndoAddTriggersCheck @TabName, @UndoAction, @SQL, @SQL_OUT output
	set @SQL = @SQL_OUT
  END
  ELSE IF @UndoAction = 3 -- UnInsert
  BEGIN
    SET @SQL = 'DELETE FROM '+@TabName+' WHERE '+@PK_data+'
' + CASE WHEN @CheckError=1
      THEN 'set @ERROR=@@ERROR
'   ELSE ''
    END 
    EXEC dbo.AUDIT_prc_UndoAddTriggersCheck @TabName, @UndoAction, @SQL, @SQL_OUT output
	set @SQL = @SQL_OUT
  END
  SET @Print= @Print + CASE 
  WHEN @UndoAction = 1 
    THEN ISNULL('Undo UPDATE for ' + RTRIM(@TabName)+'.'+RTRIM(@ColName)+', PK:"'+@PK_data+'", done on '+CONVERT(varchar(40),@MODIFIED_DATE,109)+
	 ' by '+ISNULL(@MODIFIED_BY,'Unknown')+', HOST:'+ISNULL(@HOST_NAME,'Unknown')+', App:'+ISNULL(@APP_NAME,'Unknown'),'No Details')
  WHEN @UndoAction = 2
    THEN ISNULL('Undelete for ' + RTRIM(@TabName)+', PK:"'+@PK_data+'", done on '+CONVERT(varchar(40),@MODIFIED_DATE,109)+
	 ' by '+ISNULL(@MODIFIED_BY,'Unknown')+', HOST:'+ISNULL(@HOST_NAME,'Unknown')+', App:'+ISNULL(@APP_NAME,'Unknown'),'No Details')
  WHEN @UndoAction = 3 
    THEN ISNULL('Undo INSERT for ' + RTRIM(@TabName)+', PK:"'+@PK_data+'", done on '+CONVERT(varchar(40),@MODIFIED_DATE,109)+
	 ' by '+ISNULL(@MODIFIED_BY,'Unknown')+', HOST:'+ISNULL(@HOST_NAME,'Unknown')+', App:'+ISNULL(@APP_NAME,'Unknown'),'No Details')
  END
END
