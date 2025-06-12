CREATE PROC dbo.AUDIT_prc_CheckAuditUndo
AS
IF EXISTS (SELECT 1 FROM tempdb.dbo.sysobjects WHERE name like '##UndoLog')
BEGIN
  RAISERROR ('AuditUndo function is currently running (##UndoLog exists). A second instance connot be submitted', 16,1)
  RETURN -1
END
CREATE TABLE ##UndoLog (
  UndoLogId int IDENTITY (1,1),
  UndoAction tinyint, -- 1-Update, 2-Undelete, 3-Delete
  TabName nvarchar(261),
  PK_data nvarchar(4000),
  ColName sysname null,
  OLD_VALUE nvarchar(4000) null,
  [HOST_NAME] [nvarchar] (25) NULL,
  [APP_NAME] [nvarchar] (100) NULL,
  [MODIFIED_BY][nvarchar] (30) NOT NULL,
  [MODIFIED_DATE] [datetime] NOT NULL,
  UndoStatus tinyint null, -- 0-NotDoable, 1-Doable
  Comment nvarchar(4000) null)
CREATE TABLE ##UndoColumns (
  UndoLogId int,
  TabName sysname,
  ColName sysname,
  OLD_VALUE nvarchar(4000))
SELECT backup_finish_date, user_name FROM msdb..backupset 
  WHERE database_name = db_name()
    AND backup_finish_date = (SELECT MAX(backup_finish_date) FROM msdb..backupset WHERE database_name = db_name())
RETURN @@ERROR
