CREATE PROC dbo.AUDIT_prc_AddAuditUndoItem
@AUDIT_LOG_TRANSACTION_ID nvarchar(4000),
@AUDIT_LOG_DATA_ID nvarchar(4000) = null
AS
DECLARE @AUDIT_ACTION_ID tinyint
DECLARE @AUDIT_NextAction_Id tinyint
DECLARE @PK_data nvarchar(4000)
DECLARE @COL_NAME sysname
DECLARE @NextMODIFIED_DATE datetime
DECLARE @OLD_VALUE nvarchar(4000)
DECLARE @HOST_NAME nvarchar(25)
DECLARE @APP_NAME nvarchar(100)
DECLARE @MODIFIED_BY nvarchar(30)
DECLARE @MODIFIED_DATE datetime
DECLARE @TabName nvarchar(261)
DECLARE @UndoStatus tinyint
DECLARE @UndoComment nvarchar(4000)
DECLARE @UndoLogId int
DECLARE @SqlString nvarchar(4000)
DECLARE @Message nvarchar(4000)
IF @AUDIT_LOG_DATA_ID is null
BEGIN
  -- For all PKs in the transaction
  DECLARE TransactionData CURSOR FOR
    SELECT t.AUDIT_LOG_TRANSACTION_ID, AUDIT_LOG_DATA_ID 
      FROM dbo.AUDIT_LOG_TRANSACTIONS t
      INNER JOIN dbo.AUDIT_LOG_DATA d ON d.AUDIT_LOG_TRANSACTION_ID=t.AUDIT_LOG_TRANSACTION_ID
      WHERE t.AUDIT_LOG_TRANSACTION_ID = @AUDIT_LOG_TRANSACTION_ID
  OPEN TransactionData
  FETCH NEXT FROM TransactionData INTO @AUDIT_LOG_TRANSACTION_ID, @AUDIT_LOG_DATA_ID
  WHILE @@FETCH_STATUS = 0
  BEGIN
    EXEC dbo.AUDIT_prc_AddAuditUndoItem @AUDIT_LOG_TRANSACTION_ID, @AUDIT_LOG_DATA_ID
    FETCH NEXT FROM TransactionData INTO @AUDIT_LOG_TRANSACTION_ID, @AUDIT_LOG_DATA_ID
  END
  DEALLOCATE TransactionData
  RETURN
END
SELECT @AUDIT_ACTION_ID = AUDIT_ACTION_ID, @COL_NAME = [COL_NAME], @TabName = '['+t.TABLE_SCHEMA+'].['+t.TABLE_NAME+']',
       @OLD_VALUE = OLD_VALUE, @PK_data = PRIMARY_KEY_DATA,
       @HOST_NAME = [HOST_NAME], @APP_NAME = [APP_NAME], @MODIFIED_BY = MODIFIED_BY, @MODIFIED_DATE = MODIFIED_DATE
  FROM dbo.AUDIT_LOG_TRANSACTIONS t 
  INNER JOIN dbo.AUDIT_LOG_DATA d ON d.AUDIT_LOG_TRANSACTION_ID=t.AUDIT_LOG_TRANSACTION_ID
  WHERE t.AUDIT_LOG_TRANSACTION_ID = @AUDIT_LOG_TRANSACTION_ID
  AND AUDIT_LOG_DATA_ID = @AUDIT_LOG_DATA_ID
IF @@ROWCOUNT = 0
BEGIN
  --RAISERROR ('The log record does not exist in the AUDIT_LOG_TRANSACTIONS', 16, 1)
  RETURN -1 -- do nothing, just say error number
END
-- For INSERT
IF @AUDIT_ACTION_ID = 2
BEGIN
  SELECT 1 FROM ##UndoLog WHERE UndoAction = 3 AND TabName = @TabName AND PK_data = @PK_data
  IF @@ROWCOUNT > 0	
  BEGIN
    RETURN 0 -- do nothing, the record for DELETE (undo for INSERT) is already in the ##UndoLog. It's just another column
  END
END
-- For DELETE
ELSE IF @AUDIT_ACTION_ID = 3
BEGIN
  SELECT @UndoLogId = UndoLogId FROM ##UndoLog WHERE UndoAction = 2 AND TabName = @TabName AND PK_data = @PK_data
  IF @@ROWCOUNT > 0
  BEGIN
    IF EXISTS (SELECT * FROM dbo.sysobjects o
               INNER JOIN dbo.syscolumns c ON c.id = o.id
               WHERE o.id = OBJECT_ID(@TabName) AND c.name = @COL_NAME AND (c.xtype = 189 OR c.iscomputed=1))
      SET @OLD_VALUE = null -- timestamp or computed column in INSERT must be null
    IF NOT EXISTS(SELECT * FROM ##UndoColumns 
	  WHERE @UndoLogId=UndoLogId AND @TabName=TabName AND @COL_NAME=ColName)
      INSERT INTO ##UndoColumns (UndoLogId, TabName, ColName, OLD_VALUE)
        VALUES (@UndoLogId, @TabName, @COL_NAME, @OLD_VALUE)
    RETURN 0 -- nothing must be done in the ##UndoLog, the record is already in there. It's just another column
  END
END
ELSE IF @AUDIT_ACTION_ID = 1
BEGIN
  IF EXISTS (SELECT * FROM dbo.sysobjects o
             INNER JOIN dbo.syscolumns c ON c.id = o.id
             WHERE o.id = OBJECT_ID(@TabName) AND c.name = @COL_NAME AND (c.xtype = 189 OR c.iscomputed=1))
  BEGIN
    RETURN -- timestamp or computed column cannot be in SET of an UPDATE statement
  END
END  
INSERT INTO ##UndoLog (UndoAction, TabName, PK_data, ColName, OLD_VALUE,
                       [HOST_NAME], [APP_NAME], MODIFIED_BY, MODIFIED_DATE, UndoStatus, Comment)
  VALUES (CASE @AUDIT_ACTION_ID WHEN 2 THEN 3 WHEN 3 THEN 2 ELSE @AUDIT_ACTION_ID END,
          @TabName, @PK_data, @COL_NAME, @OLD_VALUE, 
          @HOST_NAME, @APP_NAME, @MODIFIED_BY, @MODIFIED_DATE, null, null)
IF @AUDIT_ACTION_ID = 3
BEGIN
  INSERT INTO ##UndoColumns (UndoLogId, TabName, ColName, OLD_VALUE)
    VALUES (@@IDENTITY, @TabName, @COL_NAME, @OLD_VALUE)
END
