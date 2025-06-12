CREATE PROCEDURE sp_fix_column_order
	@table sysname
AS
DECLARE @SQLState varchar(2000)
--Configure server to allow ad hoc updates to system tables 
EXEC master.dbo.sp_configure 'allow updates', '1' RECONFIGURE WITH OVERRIDE 
/*Build string to update object, the only reason I build a string is the allow updates exec does not allow straight SQL to occurr.*/
SET @SQLState = 'UPDATE syscolumns
SET colid = TruePos,
colorder = TruePos
	
FROM syscolumns
INNER JOIN
(SELECT [name],
	[id], 
	colorder, 
	(SELECT COUNT(*) + 1 FROM syscolumns ic WHERE ic.colorder < c.colorder AND ic.[id] = c.[id]) AS TruePos
FROM syscolumns c 
WHERE [id] = OBJECT_ID(''' + @table + ''')) 
	AS CalcVals ON syscolumns.[name] = CalcVals.[name] 
	AND syscolumns.[id] = CalcVals.[id] 
	AND syscolumns.colorder = CalcVals.colorder' 
EXEC (@SQLState)
--Configure server to disallow ad hoc updates to system tables 
EXEC master.dbo.sp_configure 'allow updates', '0' RECONFIGURE WITH OVERRIDE 
