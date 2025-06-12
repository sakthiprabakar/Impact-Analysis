CREATE PROCEDURE [dbo].[AUDIT_prc_UndoCheck]
@UndoLogId int,
@UndoStatus tinyint OUTPUT,
@UndoComment nvarchar(4000) OUTPUT
AS
BEGIN
DECLARE @UndoAction tinyint -- 1-Update, 2-Undelete, 3-Delete
DECLARE @TabName sysname
DECLARE @PK_data nvarchar(4000)
DECLARE @ColName sysname
DECLARE @MODIFIED_DATE datetime
DECLARE @NextMODIFIED_DATE datetime	
DECLARE @ROWEXISTS bit
DECLARE @SqlString nvarchar(4000)
  SELECT @UndoAction=UndoAction, @TabName=TabName, @PK_data=PK_data, @ColName=ColName, @MODIFIED_DATE=MODIFIED_DATE 
    FROM ##UndoLog 
    WHERE @UndoLogId=UndoLogId
  -- For UPDATE
  IF @UndoAction = 1
  BEGIN
    SET @SqlString = 'SET @ROWEXISTS = CASE WHEN EXISTS(SELECT * FROM '+@TabName+' WHERE '+@PK_data+') THEN 1 ELSE 0 END'
    EXEC sp_executesql @SqlString, N'@ROWEXISTS bit OUTPUT', @ROWEXISTS OUTPUT
    IF @ROWEXISTS = 0
    BEGIN
      SET @UndoStatus = 0
      SET @UndoComment = 'The row does not exist anymore'    
      GOTO ReturnLabel
    END
    -- If there was an action against the Tab/PK/Col afterward
    SELECT TOP 1 @NextMODIFIED_DATE = MODIFIED_DATE
      FROM dbo.AUDIT_LOG_TRANSACTIONS t
      INNER JOIN dbo.AUDIT_LOG_DATA d ON d.AUDIT_LOG_TRANSACTION_ID = t.AUDIT_LOG_TRANSACTION_ID
      WHERE MODIFIED_DATE > @MODIFIED_DATE
        AND TABLE_NAME = @TabName
        AND PRIMARY_KEY_DATA = @PK_data
        AND AUDIT_ACTION_ID = 3
    IF @@ROWCOUNT > 0
    BEGIN
      SET @UndoStatus = 1
      SET @UndoComment = 'The row was deleted after the update. Date: '+CONVERT(varchar(40),@NextMODIFIED_DATE,109)
      GOTO ReturnLabel
    END
    SELECT TOP 1 @NextMODIFIED_DATE = MODIFIED_DATE
      FROM dbo.AUDIT_LOG_TRANSACTIONS t 
      INNER JOIN dbo.AUDIT_LOG_DATA d ON d.AUDIT_LOG_TRANSACTION_ID = t.AUDIT_LOG_TRANSACTION_ID
      WHERE MODIFIED_DATE > @MODIFIED_DATE
        AND TABLE_NAME = @TabName
        AND PRIMARY_KEY_DATA = @PK_data
        AND AUDIT_ACTION_ID = 1
        AND [COL_NAME] = @ColName
    IF @@ROWCOUNT > 0
    BEGIN      
      SET @UndoStatus = 1
      SET @UndoComment = 'The value for the column in a row with the PK was updated later. Date: '+CONVERT(varchar(40),@NextMODIFIED_DATE,109)
      GOTO ReturnLabel
    END
    -- The Tab/PK/Col wasn't toughed
    SET @UndoStatus = 1
    SET @UndoComment = ''
    GOTO ReturnLabel
  END
  -- For Un-Delete
  ELSE IF @UndoAction = 2
  BEGIN
    -- Check if the Tab/PK row is still in the table
    SET @SqlString = 'SET @ROWEXISTS = CASE WHEN EXISTS(SELECT * FROM '+@TabName+' WHERE '+@PK_data+') THEN 1 ELSE 0 END'
    EXEC sp_executesql @SqlString, N'@ROWEXISTS bit OUTPUT', @ROWEXISTS OUTPUT
    IF @ROWEXISTS = 1
    BEGIN
      SET @UndoStatus = 0
      SET @UndoComment = 'The row with the PK already exists'    
      GOTO ReturnLabel
    END
    -- Check if all column values are available
    -- If there was an action against the Tab/PK/Col afterward
    SELECT TOP 1 @NextMODIFIED_DATE = MODIFIED_DATE
      FROM dbo.AUDIT_LOG_TRANSACTIONS t 
      INNER JOIN dbo.AUDIT_LOG_DATA d ON d.AUDIT_LOG_TRANSACTION_ID = t.AUDIT_LOG_TRANSACTION_ID
      WHERE MODIFIED_DATE > @MODIFIED_DATE
        AND TABLE_NAME = @TabName
        AND PRIMARY_KEY_DATA = @PK_data
    IF @@ROWCOUNT > 0
    BEGIN      
      SET @UndoStatus = 1
      SET @UndoComment = 'There were actions against the Tab/PK after the deletion. Date: '+CONVERT(varchar(40),@NextMODIFIED_DATE,109)
      GOTO ReturnLabel
    END
    -- The Tab/PK wasn't toughed
    SET @UndoStatus = 1
    SET @UndoComment = ''
    GOTO ReturnLabel
  END
  -- For Un-Insert
  ELSE IF @UndoAction = 3
  BEGIN
    -- Check if the Tab/PK row is still in the table
    SET @SqlString = 'SELECT ['+@ColName+'] INTO #tmp FROM '+@TabName+' WHERE '+@PK_data
    EXEC (@SqlString)
    IF @@ROWCOUNT = 0
    BEGIN
      SET @UndoStatus = 0
      SET @UndoComment = 'The row does not exist anymore'    
      GOTO ReturnLabel
    END
    -- If there was an action against the Tab/PK/Col afterward
    SELECT TOP 1 @NextMODIFIED_DATE = MODIFIED_DATE
      FROM dbo.AUDIT_LOG_TRANSACTIONS t 
      INNER JOIN dbo.AUDIT_LOG_DATA d ON d.AUDIT_LOG_TRANSACTION_ID = t.AUDIT_LOG_TRANSACTION_ID
      WHERE MODIFIED_DATE > @MODIFIED_DATE
        AND TABLE_NAME = @TabName
        AND PRIMARY_KEY_DATA = @PK_data
        AND AUDIT_ACTION_ID = 3
    IF @@ROWCOUNT > 0
    BEGIN
      SET @UndoStatus = 1
      SET @UndoComment = 'The row was deleted after the insertion. Date: '+CONVERT(varchar(40),@NextMODIFIED_DATE,109)
      GOTO ReturnLabel
    END
    SELECT TOP 1 @NextMODIFIED_DATE = MODIFIED_DATE
      FROM dbo.AUDIT_LOG_TRANSACTIONS t 
      INNER JOIN dbo.AUDIT_LOG_DATA d ON d.AUDIT_LOG_TRANSACTION_ID = t.AUDIT_LOG_TRANSACTION_ID
      WHERE MODIFIED_DATE > @MODIFIED_DATE
        AND TABLE_NAME = @TabName
        AND PRIMARY_KEY_DATA = @PK_data
    IF @@ROWCOUNT > 0
    BEGIN
      SET @UndoStatus = 1
      SET @UndoComment = 'There were actions against the Tab/PK after the insertion. Date: '+CONVERT(varchar(40),@NextMODIFIED_DATE,109)
      GOTO ReturnLabel
    END
    -- There is no records fot the Tab/PK in AUDIT_LOG_TRANSACTIONS
    SET @UndoStatus = 1
    SET @UndoComment = ''
    GOTO ReturnLabel
  END
ReturnLabel:
END
