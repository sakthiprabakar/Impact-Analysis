CREATE PROC [dbo].[AUDIT_prc_RunUndo] 
AS
DECLARE @errors int
DECLARE @UndoLogId int
DECLARE @n int
declare @print nvarchar(4000)
declare @sql nvarchar(4000)
declare @sql_err nvarchar(4000)
declare @status tinyint
declare @comment nvarchar(4000)
declare @error int
SET NOCOUNT OFF
set @errors = 0
SET @n = 0
SET IMPLICIT_TRANSACTIONS ON
DECLARE UndoItems CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
  SELECT UndoLogId FROM ##UndoLog ORDER BY UndoLogId
OPEN UndoItems
FETCH NEXT FROM UndoItems INTO @UndoLogId
WHILE @@FETCH_STATUS = 0
BEGIN
exec dbo.AUDIT_prc_UndoGenerateCommand @UndoLogId, 0, @print output, @sql output
exec dbo.[AUDIT_prc_UndoCheck] @UndoLogId, @status output, @comment output
print @print
exec dbo.AUDIT_prc_UndoGenerateCommand @UndoLogId, 1, @print output, @sql_err output
if(len(@sql_err)<3999)
begin
  if @status=1
  begin
    print @sql
    exec dbo.AUDIT_prc_ExecUndo @sql_err, @error output
	if @error<>0 or @@ERROR<>0
    begin
      print 'Undoable operation'
      set @errors=@errors+1
    end
    else
    begin
      print 'No errors returned'
    end
  end
  else
  begin
    print 'Undoable operation: ' + @comment
    set @errors=@errors+1
  end
end
else
BEGIN
  print 'Error: result query more then 4000 characters length'
  set @errors=@errors+1
END
set @n = @n + 1
FETCH NEXT FROM UndoItems INTO @UndoLogId
END
DEALLOCATE UndoItems
if @errors <> 0
begin
if(@errors = @n)
  RaisError ('All operations with errors or undoable', 16, 1)
end
select @errors
