CREATE PROC [dbo].[AUDIT_prc_ExecUndo]
@SQL nvarchar(4000),
@ERROR int output
AS
DECLARE @SqlString nvarchar(4000)
SELECT @SqlString = 'Set Quoted_identifier on ' + @SQL
exec sp_executesql @SqlString, N'@ERROR int output', @ERROR output
