CREATE PROCEDURE [dbo].[AUDIT_prc_CreateAuditUndoReport]
AS
SET NOCOUNT ON	--	IE2002-05-10: MUST BE HERE BECAUSE UNDO CLIENT CHOCKES OTHERWISE
DECLARE @UndoLogId int
DECLARE @UndoAction tinyint -- 1-Update, 2-Undelete, 3-Delete
DECLARE @TabName nvarchar(261)
DECLARE @PK_data nvarchar(4000)
DECLARE @ColName nvarchar(128)
DECLARE @MODIFIED_DATE datetime
declare @print nvarchar(4000)
declare @sql nvarchar(4000)
declare @status tinyint
declare @comment nvarchar(4000)
declare @error int
DECLARE UndeleteTables CURSOR LOCAL FOR 
  SELECT UndoLogId, UndoAction, TabName, PK_data, ColName, MODIFIED_DATE 
  FROM ##UndoLog 
-- begin transaction to change to allow tables data
set XACT_ABORT OFF
begin transaction CHANGES
OPEN UndeleteTables
FETCH NEXT FROM UndeleteTables INTO @UndoLogId, @UndoAction, @TabName, @PK_data, @ColName, @MODIFIED_DATE
WHILE @@FETCH_STATUS = 0
BEGIN
exec dbo.AUDIT_prc_UndoGenerateCommand @UndoLogId, 1, @print output, @sql output
exec dbo.[AUDIT_prc_UndoCheck] @UndoLogId, @status output, @comment output
if @status=1
begin
    exec dbo.AUDIT_prc_ExecUndo @sql, @error output
	if @error<>0 or @@ERROR<>0
    begin
      set @status=0
      set @comment='Undoable operation'
    end
    else
      set @comment=''
end
  UPDATE ##UndoLog SET UndoStatus = @status, Comment = @comment
    WHERE CURRENT OF UndeleteTables
  FETCH NEXT FROM UndeleteTables INTO @UndoLogId, @UndoAction, @TabName, @PK_data, @ColName, @MODIFIED_DATE
END
DEALLOCATE UndeleteTables
RETURN @@ERROR
