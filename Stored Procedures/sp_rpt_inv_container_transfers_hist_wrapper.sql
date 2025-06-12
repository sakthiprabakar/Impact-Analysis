CREATE PROCEDURE [dbo].[sp_rpt_inv_container_transfers_hist_wrapper] 
	@run_id INT = 0 OUTPUT, -- ContainerInventoryTransfersHistory.run_id is a unique ID per batch or for every time this SP is called.
	@rows_inserted INT = 0 OUTPUT, -- Number of rows inserted into #ContInvTransferTemp.
	@we_have_error INT = 0 OUTPUT, -- 0 = success, 1 = error
	@error_message VARCHAR(400) = '' OUTPUT -- if @we_have_error = 0, then @error_message is blank.
AS

/*
--------------------------------------------------------------------------------------------------------------------------------------------
Loads to: PLT_AI database.
05/23/2018 DTW Started work on the transfer version of the Container Inventory report. 
05/24/2018 DTW Installed in production for the first time with the standard report.
--------------------------------------------------------------------------------------------------------------------------------------------
This SP is called from the SSIS package: Container Inventory History, which is run via a SQL Agent job on a nightly basis.
This SP calls the sp_rpt_inv_container_transfers SP for every valid combination of company and profit center and stores the data returned by
	this SP into the ContainerInventoryTransfersHistory table.  
The SSIS package takes the data from ContainerInventoryTransfersHistory and exports it to Excel files in the 
	L:\Container Inventory\DEV or TEST or PROD folder.
Any changes made to the schema of the sp_rpt_inv_container_transfers SP output (e.g. adding or removing a column), must also 
	be made to the temp table creation statement in this SP and the ContainerInventoryTransfersHistory table.
It is ***not*** possible to have this SP dynamically adjust to the sp_rpt_inv_container_transfers returned table schema.
It is not possible to do the following:	SELECT col1, col2, ... INTO #ContInvTransferTemp EXEC dbo.sp_rpt_inv_container_transfers  
	You cannot combine SELECT INTO and EXEC SP.
It is possible to use OPENROWSET() and EXEC SP, but the servername must be hardcoded, and I didn't want to use dynamic SQL.
--------------------------------------------------------------------------------------------------------------------------------------------
-- This SP
EXEC dbo.sp_rpt_inv_container_transfers_hist_wrapper

-- Original SP
EXEC dbo.sp_rpt_inv_container_transfers 14, 4, 'ALL', 'ALL'
EXEC dbo.sp_rpt_inv_container_transfers 21, 1, 'ALL', 'ALL'
EXEC dbo.sp_rpt_inv_container_transfers 47, 0, 'ALL', 'ALL'

SELECT * FROM ContainerInventoryTransfersHistory
-- DELETE FROM ContainerInventoryTransfersHistory

SELECT run_id, count(*) from ContainerInventoryTransfersHistory group by run_id 
SELECT run_id, company_id, profit_ctr_id, count(*) AS Cnt from ContainerInventoryTransfersHistory group by run_id, company_id, profit_ctr_id order by run_id, company_id, profit_ctr_id
 
SELECT * FROM ContainerInventoryTransfersHistory where run_id = 0 and company_id = 47
SELECT sum(containers_on_site) FROM ContainerInventoryTransfersHistory where run_id = 0 and company_id = 47

-- This combination of fields should be unique.
SELECT run_id, company_id, profit_ctr_id, receipt_id, line_id, container_id, count(*) 
FROM ContainerInventoryTransfersHistory
GROUP BY run_id, company_id, profit_ctr_id, receipt_id, line_id, container_id
ORDER BY COUNT(*) DESC

SELECT * FROM ContainerInventoryTransfersHistory
-- update ContainerInventoryTransfersHistory set approval_code = '0002' 

SELECT * FROM Sequence where name like '%containerhistory%'

SELECT * FROM Sequence where name = 'ContainerInventoryTransfersHistory.run_id'
SELECT MAX(run_id) FROM dbo.ContainerInventoryTransfersHistory
-- update sequence set next_value = 1 where name = 'ContainerInventoryTransfersHistory.run_id'

SELECT * FROM Report where report_id = 2
SELECT * FROM ReportLog where user_code = 'SSIS' order by report_id
-- DELETE FROM dbo.ReportLog where user_code = 'SSIS'
--------------------------------------------------------------------------------------------------------------------------------------------
*/

-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-- Any changes made to this SP will probably have to made to a very similar SP: sp_rpt_inv_container_hist_wrapper
-- %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

SET NOCOUNT ON
SET XACT_ABORT ON -- Setting XACT_ABORT to ON will allow the entire transaction to rollback if an unexpected error occurs.

-- In the Excel file name, the run_date and datetime strings are both stored as UTC times.
DECLARE @run_date_UTC DATETIME = GETUTCDATE(), @company_id INT = 0, @profit_ctr_id INT = 0,
		@date_start DATETIME = 0, @date_end DATETIME = 0, @report_log_id INT = 0

DECLARE @ReuseData BIT = 0 -- 1 = true, 0 = false. (For production @ReuseDate = 0).  ???

BEGIN TRAN

---------------------------------------------------------------------------------------
-- SP_SEQUENCE_SILENT_NEXT is a SP that inserts or updates a row in the Sequence table.
---------------------------------------------------------------------------------------
IF @ReuseData = 0 BEGIN
	EXEC @run_id = dbo.SP_SEQUENCE_SILENT_NEXT 'ContainerInventoryTransfersHistory.run_id' 
END 
ELSE BEGIN -- testing mode
	SELECT @run_id = MAX(run_id) FROM dbo.ContainerInventoryTransfersHistory -- Reuse most recent run_id.
END 

----------------------------------------------------------------------------------------------------------
-- Check to make sure next sequence id does not already exist in ContainerInventoryTransfersHistory table.
----------------------------------------------------------------------------------------------------------
IF @ReuseData = 0 AND EXISTS (SELECT * FROM dbo.ContainerInventoryTransfersHistory WHERE run_id = @run_id) BEGIN
	SET @we_have_error = 1

	SET @error_message = 'EXEC SP_SEQUENCE_SILENT_NEXT returned a next_value of: ' + LTRIM(STR(@run_id))
	SET @error_message = @error_message + ', for the row with a name of: ''ContainerInventoryTransfersHistory.run_id''.'
	SET @error_message = @error_message + '  This run_id already exists in the table ContainerInventoryTransfersHistory and'
	SET @error_message = @error_message + '  run_id must be unique per batch run.'
	SET @error_message = @error_message + '  We cannot delete existing data in ContainerInventoryTransfersHistory, so the SP must error out.'

	ROLLBACK TRAN
	RETURN 0
END

IF OBJECT_ID('tempdb..#ContInvTransferTemp') IS NOT NULL 
	DROP TABLE #ContInvTransferTemp 

---------------------------------------------------------------------------------------------------
-- *** This table schema must match the table schema returned from the sp_rpt_inv_container_transfers SP. ***
---------------------------------------------------------------------------------------------------
CREATE TABLE #ContInvTransferTemp (
	receipt_id int NOT NULL, 
	line_id int NOT NULL,  
	profit_ctr_id int NOT NULL, -- Profit Center
	container_type char(1) NULL, 
	manifest varchar(15) NULL, 
	manifest_container varchar(15) NULL,
	manifest_hazmat_class varchar(15) NULL,
	approval_code varchar(50) NULL, 
	containers_on_site int NULL, 
	bill_unit_code varchar(4) NULL, 
	receipt_date datetime NULL,
	[location] varchar(15) NULL, 
	days_on_site int NULL,
	as_of_date datetime NULL, 
	tracking_num varchar(15) NULL, 
	staging_row varchar(5) NULL, 
	container_size varchar(15) NULL, 
	container_weight decimal(10, 3) NULL, 
	company_id int NOT NULL, -- Company ID
	approval_company_id int NULL,
	approval_profit_ctr_id int NULL,
	outbound_receipt varchar(15) NULL, 
	outbound_receipt_date datetime NULL,
	company_name varchar(35) NULL,
	profit_ctr_name varchar(50) NULL
)

DECLARE csrA CURSOR FAST_FORWARD FOR
	SELECT company_id, profit_ctr_id
	FROM dbo.ProfitCenter
	WHERE [status] = 'A' AND waste_receipt_flag = 'T'
		-- testing section ???
		--AND (company_id = 14 and profit_ctr_id = 4 OR
		--	 company_id = 21 and profit_ctr_id = 1 OR
		--	 company_id = 47 and profit_ctr_id = 0)
	ORDER BY company_id, profit_ctr_id

OPEN csrA 

FETCH NEXT FROM csrA INTO @company_id, @profit_ctr_id

WHILE @@FETCH_STATUS = 0 BEGIN
	IF @ReuseData = 0 BEGIN
		SET @date_start = GETDATE()

		--------------------------------------------------------------------------------------------------
		-- *** Call the sp_rpt_inv_container_transfers SP for every company/profit center combination. ***
		--------------------------------------------------------------------------------------------------
		INSERT INTO #ContInvTransferTemp 
		EXEC dbo.sp_rpt_inv_container_transfers @company_id, @profit_ctr_id, 'ALL', 'ALL'

		SET @date_end = GETDATE()

		--------------------------------------------
		-- Get next sequence id for ReportLog table.
		--------------------------------------------
		EXEC @report_log_id = dbo.SP_SEQUENCE_SILENT_NEXT 'ReportLog.report_log_ID' 

		---------------------------------------------------------------------
		-- Performance metrics are stored in the ReportLog table.
		--   ReportLog.report_cust_from = @run_id
		--	 ReportLog.user_code = 'SSIS'
		--   ReportLog.report_dataobject = 'Container Inventory Transfer'
		---------------------------------------------------------------------
		INSERT INTO dbo.ReportLog
			(company_id, profit_ctr_id, report_type, report_title, report_dataobject, report_date_from, report_date_to, 
			report_cust_from, report_cust_to, user_code, date_added, report_log_id, report_id, 
			date_added_batch, date_started, date_finished, report_duration, report_error, report_log_desc)
		SELECT @company_id, @profit_ctr_id, 'Container', 'Container Inventory (as of today) Transfer Only', 'Container Inventory Transfer', NULL, NULL, 
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
	INSERT INTO dbo.ContainerInventoryTransfersHistory
	SELECT 
		@run_id,
		@run_date_UTC, 
		--------------------------
		receipt_id, 
		line_id,  
		profit_ctr_id, 
		container_type, 
		manifest, 
		manifest_container,
		manifest_hazmat_class,
		approval_code, 
		containers_on_site, 
		bill_unit_code, 
		receipt_date,
		[location], 
		days_on_site,
		as_of_date, 
		tracking_num, 
		staging_row, 
		container_size, 
		container_weight, 
		company_id, 
		approval_company_id,
		approval_profit_ctr_id,
		outbound_receipt, 
		outbound_receipt_date,
		company_name,
		profit_ctr_name
	FROM dbo.#ContInvTransferTemp 
END

-------------------------------------------------------
-- Select the rows inserted count for the SSIS package.
-------------------------------------------------------
SELECT @rows_inserted = COUNT(*) 
FROM dbo.#ContInvTransferTemp 

COMMIT TRAN


GO

--------------------------------------------------------------------------------------------------------------
-- This allows the SSIS package, which connects to the database as CRM_SERVICE, permission to execute this SP.
--------------------------------------------------------------------------------------------------------------
GRANT EXECUTE ON [dbo].[sp_rpt_inv_container_transfers_hist_wrapper] TO CRM_SERVICE AS dbo
GO