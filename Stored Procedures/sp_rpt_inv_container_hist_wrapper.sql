CREATE PROCEDURE [dbo].[sp_rpt_inv_container_hist_wrapper] 
	@run_id INT = 0 OUTPUT, -- ContainerInventoryHistory.run_id is a unique ID per batch or for every time this SP is called.
	@rows_inserted INT = 0 OUTPUT, -- Number of rows inserted into #ContInvTemp.
	@we_have_error INT = 0 OUTPUT, -- 0 = success, 1 = error
	@error_message VARCHAR(400) = '' OUTPUT -- if @we_have_error = 0, then @error_message is blank.
AS

/*
----------------------------------------------------------------------------------------------------------------------------------------
Loads to: PLT_AI database.
01/22/2018 DTW Started work.
05/24/2018 DTW Finally installed in production.
01/18/2019 DTW Modified the temp table and increased the generator_name from VARCHAR(40) to VARCHAR(75).
----------------------------------------------------------------------------------------------------------------------------------------
This SP is called from the SSIS package: Container Inventory History, which is run via a SQL Agent job on a nightly basis.
This SP calls the sp_rpt_inv_container SP for every valid combination of company and profit center and stores the data returned by
	this SP into the ContainerInventoryHistory table.  
The SSIS package takes the data from ContainerInventoryHistory and exports it to Excel files in the 
	L:\Container Inventory\DEV or TEST or PROD folder.
Any changes made to the schema of the sp_rpt_inv_container SP output (e.g. adding or removing a column), must also 
	be made to the temp table creation statement in this SP and the ContainerInventoryHistory table.
It is ***not*** possible to have this SP dynamically adjust to the sp_rpt_inv_container returned table schema.
It is not possible to do the following:	SELECT col1, col2, ... INTO #ContInvTemp EXEC dbo.sp_rpt_inv_container  
	You cannot combine SELECT INTO and EXEC SP.
It is possible to use OPENROWSET() and EXEC SP, but the servername must be hardcoded, and I didn't want to use dynamic SQL.
----------------------------------------------------------------------------------------------------------------------------------------
-- This SP
EXEC dbo.sp_rpt_inv_container_hist_wrapper

-- Original SP
EXEC dbo.sp_rpt_inv_container 2, 0, 1, 999999, 'ALL', 'ALL'

SELECT * FROM ContainerInventoryHistory
-- DELETE FROM ContainerInventoryHistory

SELECT run_id, count(*) from ContainerInventoryHistory group by run_id 
SELECT run_id, company_id, profit_ctr_id, count(*) from ContainerInventoryHistory group by run_id, company_id, profit_ctr_id order by run_id, company_id, profit_ctr_id

SELECT * FROM ContainerInventoryHistory where run_id = 2 and company_id = 2
DELETE FROM ContainerInventoryHistory where run_id = 2 and company_id = 2 and receipt_id not in (566117, 566426)

SELECT * FROM ContainerInventoryHistory where run_id = 2 and company_id = 42
DELETE FROM ContainerInventoryHistory where run_id = 2 and company_id = 42 and receipt_id not in (310468, 310475)

-- This combination of fields should be unique.
SELECT run_id, company_id, profit_ctr_id, receipt_id, line_id, container_id, count(*) 
FROM ContainerInventoryHistory
GROUP BY run_id, company_id, profit_ctr_id, receipt_id, line_id, container_id
ORDER BY COUNT(*) DESC

SELECT * FROM ContainerInventoryHistory
-- update ContainerInventoryHistory set approval_code = '0002' 

SELECT * FROM Sequence where name = 'ContainerInventoryHistory.run_id'
SELECT MAX(run_id) FROM dbo.ContainerInventoryHistory
-- update sequence set next_value = 1 where name = 'ContainerInventoryHistory.run_id'

SELECT * FROM Report where report_id = 2
SELECT * FROM ReportLog where user_code = 'SSIS' order by report_id
-- DELETE FROM dbo.ReportLog where user_code = 'SSIS'
----------------------------------------------------------------------------------------------------------------------------------------
*/

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- Any changes made to this SP will probably have to made to the very similar SP: sp_rpt_inv_container_transfer_hist_wrapper
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SET NOCOUNT ON
SET XACT_ABORT ON -- Setting XACT_ABORT to ON will allow the entire transaction to rollback if unexpected error occurs.

-- In the Excel file name, the run_date and datetime strings are both stored as UTC times.
DECLARE @run_date_UTC DATETIME = GETUTCDATE(), @company_id INT = 0, @profit_ctr_id INT = 0,
		@date_start DATETIME = 0, @date_end DATETIME = 0, @report_log_id INT = 0

-- EXEC dbo.sp_rpt_inv_container_hist_wrapper
DECLARE @ReuseData BIT = 0 -- 1 = true, 0 = false. ???

BEGIN TRAN

---------------------------------------------------------------------------------------
-- SP_SEQUENCE_SILENT_NEXT is a SP that inserts or updates a row in the Sequence table.
---------------------------------------------------------------------------------------
IF @ReuseData = 0 BEGIN
	EXEC @run_id = dbo.SP_SEQUENCE_SILENT_NEXT 'ContainerInventoryHistory.run_id' 
END 
ELSE BEGIN -- testing mode
	SELECT @run_id = MAX(run_id) FROM dbo.ContainerInventoryHistory -- Reuse most recent run_id.
END 

-------------------------------------------------------------------------------------------------
-- Check to make sure next sequence id does not already exist in ContainerInventoryHistory table.
-------------------------------------------------------------------------------------------------
IF @ReuseData = 0 AND EXISTS (SELECT * FROM dbo.ContainerInventoryHistory WHERE run_id = @run_id) BEGIN
	SET @we_have_error = 1

	SET @error_message = 'EXEC SP_SEQUENCE_SILENT_NEXT returned a next_value of: ' + LTRIM(STR(@run_id))
	SET @error_message = @error_message + ', for the row with a name of: ''ContainerInventoryHistory.run_id''.'
	SET @error_message = @error_message + '  This run_id already exists in the table ContainerInventoryHistory and'
	SET @error_message = @error_message + '  run_id must be unique per batch run.'
	SET @error_message = @error_message + '  We cannot delete existing data in ContainerInventoryHistory, so the SP must error out.'

	ROLLBACK TRAN
	RETURN 0
END

IF OBJECT_ID('tempdb..#ContInvTemp') IS NOT NULL 
	DROP TABLE #ContInvTemp 

---------------------------------------------------------------------------------------------------
-- *** This table schema must match the table schema returned from the sp_rpt_inv_container SP. ***
---------------------------------------------------------------------------------------------------
CREATE TABLE #ContInvTemp (
	receipt_id int not null, 
	line_id int not null, 
	profit_ctr_id int not null, 
	container_type char(1) not null, 
	container_id int not null, 
	load_type char(5) not null, 
	manifest varchar(15) null, 
	manifest_page_num int null, 
	manifest_line int null, 
	approval_code varchar(50) null, 
	waste_code varchar(10) null, 
	containers_on_site int null, 
	bill_unit_code varchar(4) null, 
	receipt_date datetime null,
	[location] varchar(15) null, 
	days_on_site int null,
	as_of_date datetime null, 
	tracking_num varchar(15) null, 
	staging_row varchar(5) null, 
	fingerpr_status char(1) null, 
	treatment_id int null, 
	treatment_desc varchar(32) null, 
	container_size varchar(15) null, 
	container_weight decimal(10, 3) null, 
	tsdf_approval_code varchar(40) null, 
	company_id int null,
	outbound_receipt varchar(15) null, 
	outbound_receipt_date datetime null, 
	generator_id int null, 
	generator_name varchar(75) null, 
	company_name varchar(35) null, 
	profit_ctr_name varchar(50) null, 
	truck_code varchar(10) null,
	tracking_number varchar(15) null
)

DECLARE csrA CURSOR FAST_FORWARD FOR
	SELECT company_id, profit_ctr_id
	FROM dbo.ProfitCenter
	WHERE [status] = 'A' AND waste_receipt_flag = 'T'
		-- testing section ???
		--AND company_id IN (2, 42) 
		--AND company_id = 2 
		--AND company_id = 999 -- returns no rows.
	ORDER BY company_id, profit_ctr_id

OPEN csrA 

FETCH NEXT FROM csrA INTO @company_id, @profit_ctr_id

WHILE @@FETCH_STATUS = 0 BEGIN
	IF @ReuseData = 0 BEGIN
		SET @date_start = GETDATE()

		----------------------------------------------------------------------------------------
		-- *** Call the sp_rpt_inv_container SP for every company/profit center combination. ***
		----------------------------------------------------------------------------------------
		INSERT INTO #ContInvTemp 
		EXEC dbo.sp_rpt_inv_container @company_id, @profit_ctr_id, 1, 999999, 'ALL', 'ALL'

		SET @date_end = GETDATE()

		--------------------------------------------
		-- Get next sequence id for ReportLog table.
		--------------------------------------------
		EXEC @report_log_id = dbo.SP_SEQUENCE_SILENT_NEXT 'ReportLog.report_log_ID' 

		---------------------------------------------------------------------
		-- Performance metrics are stored in the ReportLog table.
		--   ReportLog.report_cust_from = @run_id
		--	 ReportLog.user_code = 'SSIS'
		--   ReportLog.report_dataobject = 'Container Inventory Standard'
		---------------------------------------------------------------------
		INSERT INTO dbo.ReportLog
			(company_id, profit_ctr_id, report_type, report_title, report_dataobject, report_date_from, report_date_to, 
			report_cust_from, report_cust_to, user_code, date_added, report_log_id, report_id, 
			date_added_batch, date_started, date_finished, report_duration, report_error, report_log_desc)
		SELECT @company_id, @profit_ctr_id, 'Container', 'Container Inventory (as of today)', 'Container Inventory Standard', NULL, NULL, 
			@run_id, NULL, 'SSIS', NULL, @report_log_id, 2, 
			@date_end, @date_start, @date_end, DATEDIFF(SECOND, @date_start, @date_end), '', ''
	END

	FETCH NEXT FROM csrA INTO @company_id, @profit_ctr_id
END

CLOSE csrA
DEALLOCATE csrA 

----------------------------------------------------------------
-- Move data from the temp table to the permanent history table.
----------------------------------------------------------------
IF @ReuseData = 0 BEGIN
	INSERT INTO dbo.ContainerInventoryHistory
	SELECT 
		@run_id,
		@run_date_UTC, 
		company_id, 
		profit_ctr_id,
		receipt_id, 
		line_id,  
		container_id, 
		container_type, 
		load_type, 
		manifest, 
		manifest_page_num, 
		manifest_line, 
		approval_code, 
		waste_code, 
		containers_on_site, 
		bill_unit_code, 
		receipt_date,
		[location], 
		days_on_site,
		as_of_date, 
		tracking_num, 
		staging_row, 
		fingerpr_status, 
		treatment_id, 
		treatment_desc, 
		container_size, 
		container_weight, 
		tsdf_approval_code, 
		outbound_receipt, 
		outbound_receipt_date, 
		generator_id, 
		generator_name, 
		company_name, 
		profit_ctr_name, 
		truck_code,
		tracking_number
	FROM dbo.#ContInvTemp 
END

-------------------------------------------------------
-- Select the rows inserted count for the SSIS package.
-------------------------------------------------------
SELECT @rows_inserted = COUNT(*) 
FROM dbo.#ContInvTemp 

COMMIT TRAN

GO

--------------------------------------------------------------------------------------------------------------
-- This allows the SSIS package, which connects to the database as CRM_SERVICE, permission to execute this SP.
--------------------------------------------------------------------------------------------------------------
GRANT EXECUTE ON dbo.sp_rpt_inv_container_hist_wrapper TO CRM_SERVICE AS dbo
GO