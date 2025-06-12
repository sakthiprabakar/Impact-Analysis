
/***************************************************************************************
Drops any rowguids in the input table

10/02/2003 JPB	Created
****************************************************************************************/
CREATE PROCEDURE sp_drop_rowguid
	@tablename	sysname
AS
	DECLARE @indexname sysname
	DECLARE @constraintname sysname

	SET NOCOUNT ON
	CREATE TABLE #temp_index (index_name sysname, index_description sysname, index_keys sysname )
	CREATE TABLE #temp_constraint (constraint_type sysname, constraint_name sysname, delete_action nvarchar(20), update_action nvarchar(20), status_enabled nvarchar(20), status_for_replication nvarchar(20), constraint_keys sysname)
	
	INSERT INTO #temp_index EXEC('sp_helpindex ' + @tablename)
	INSERT INTO #temp_constraint EXEC('sp_helpconstraint ' + @tablename + ', @nomsg=''nomsg''')

	DECLARE indexcursor CURSOR FOR
	select index_name from #temp_index where index_keys = 'rowguid'
	OPEN indexcursor
	FETCH NEXT FROM indexcursor INTO @indexname
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		-- PRINT 'DROP INDEX ' + @tablename + '.' + @indexname
		EXEC('DROP INDEX ' + @tablename + '.' + @indexname)
		FETCH NEXT FROM indexcursor INTO @indexname
	END
	CLOSE indexcursor
	DEALLOCATE indexcursor

	DECLARE constraintcursor CURSOR FOR
	select constraint_name from #temp_constraint where constraint_type = 'DEFAULT on column rowguid'
	OPEN constraintcursor
	FETCH NEXT FROM constraintcursor INTO @constraintname
	WHILE @@FETCH_STATUS = 0 
	BEGIN
		-- PRINT 'ALTER TABLE ' + @tablename + ' DROP CONSTRAINT ' + @constraintname
		EXEC('ALTER TABLE ' + @tablename + ' DROP CONSTRAINT ' + @constraintname)
		FETCH NEXT FROM constraintcursor INTO @constraintname
	END
	CLOSE constraintcursor
	DEALLOCATE constraintcursor

	SET NOCOUNT OFF
	-- PRINT 'ALTER TABLE ' + @tablename + ' DROP COLUMN rowguid'
	EXEC('ALTER TABLE ' + @tablename + ' DROP COLUMN rowguid')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_drop_rowguid] TO [EQAI]
    AS [dbo];

