/* ------------------------------------------------------------
   PROCEDURE:     AUDIT_prc_Purge_AUDIT_LOG
   AUTHOR:        ApexSQL 
   UPDATED:	  	  19 Apr 2004
   CHANGES:       Version 2.10
		  		  Added @DELETE_ALL Parameter which will delete ALL Audit 
		  		  Log data regardless of what other parameters were specifiec
		  		  Fixed some problems where data in AUDIT_LOG_DATA was not being deleted only AUDIT_LOG_TRANSACTIONS
------------------------------------------------------------ */
CREATE PROCEDURE dbo.AUDIT_prc_Purge_AUDIT_LOG
(
	@DELETE_ALL BIT,			--	This will delete all data
	@OLDER_THAN INT = NULL,			--	pass NULL to skip this check
	@OLDER_THAN_TYPE TINYINT = NULL,	-- 	1 - DAY, 2 - WEEK, 3 - MONTH; if @older_than is NULL, this parameter is not important
	@MAX_ROWS INT = NULL			--	pass NULL to skip this check
)
AS
BEGIN
	If @DELETE_ALL = 1 
	BEGIN
		DELETE FROM dbo.AUDIT_LOG_DATA
		DELETE FROM dbo.AUDIT_LOG_TRANSACTIONS
	END
	IF @OLDER_THAN IS NOT NULL
	BEGIN
		-- Get the cut off date and time
		DECLARE @CUTOFF_DATETIME DATETIME
		SET @CUTOFF_DATETIME =
			CASE @OLDER_THAN_TYPE
				WHEN 1 THEN DATEADD(DAY, -@OLDER_THAN, GETDATE())
				WHEN 2 THEN DATEADD(WEEK,-@OLDER_THAN, GETDATE())
				WHEN 3 THEN DATEADD(MONTH, -@OLDER_THAN, GETDATE())
			END
		-- Delete all rows from maindb.dbo.AUDIT_LOG_TRANSACTIONS that are older than 1 day(s)
		PRINT CONVERT(VARCHAR,@CUTOFF_DATETIME)
		DELETE
		FROM dbo.AUDIT_LOG_DATA
		WHERE AUDIT_LOG_TRANSACTION_ID IN
		(SELECT AUDIT_LOG_TRANSACTION_ID FROM dbo.AUDIT_LOG_TRANSACTIONS
		WHERE	MODIFIED_DATE < @CUTOFF_DATETIME)
		DELETE
		FROM dbo.AUDIT_LOG_TRANSACTIONS
		WHERE
			MODIFIED_DATE < @CUTOFF_DATETIME
	END
    -- Check if we should check for max number of rows
	IF @MAX_ROWS IS NOT NULL
	BEGIN
		-- Get AUDIT_LOG_TRANSACTIONS row count
		DECLARE @ROW_COUNT INT
		SELECT @ROW_COUNT = COUNT(*)
		FROM dbo.AUDIT_LOG_TRANSACTIONS
		-- Check if there are more than 1 rows in the database
		IF @ROW_COUNT > @MAX_ROWS
		BEGIN
			-- Create temporary table to hold ids of records to be purged
			CREATE TABLE #AUDIT_LOG_PURGE_PROCESS_TEMP_TABLE (AUDIT_LOG_TRANSACTION_ID nvarchar(100))
			-- Create dynamic query to fill the temporary table
			DECLARE @SQL NVARCHAR(4000)
			SET @SQL ='
			INSERT
			INTO #AUDIT_LOG_PURGE_PROCESS_TEMP_TABLE
			SELECT TOP ' + CAST((@ROW_COUNT - @MAX_ROWS) AS varchar(10)) + ' AUDIT_LOG_TRANSACTION_ID
			FROM dbo.AUDIT_LOG_TRANSACTIONS
			ORDER BY MODIFIED_DATE'
			--PRINT @SQL
			-- Fill temporary table
			EXEC sp_executesql @SQL
			-- Delete records from AUDIT_LOG_TRANSACTIONS
			DELETE
			FROM dbo.AUDIT_LOG_DATA
			WHERE AUDIT_LOG_TRANSACTION_ID IN
				    (SELECT AUDIT_LOG_TRANSACTION_ID
					 FROM #AUDIT_LOG_PURGE_PROCESS_TEMP_TABLE)
			DELETE
			FROM dbo.AUDIT_LOG_TRANSACTIONS
			WHERE AUDIT_LOG_TRANSACTION_ID IN
				(SELECT AUDIT_LOG_TRANSACTION_ID
				 FROM #AUDIT_LOG_PURGE_PROCESS_TEMP_TABLE)
			-- Drop temporary table
			DROP TABLE #AUDIT_LOG_PURGE_PROCESS_TEMP_TABLE
		END
	END
END
