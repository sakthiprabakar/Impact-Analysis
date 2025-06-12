-- USE PLT_AI
-- WorkOrderHeader Bucket

--DROP PROCEDURE IF EXISTS dbo.ContactCORWorkOrder_SP
GO

/*
EXEC dbo.ContactCORWorkOrder_SP -- 20-25s

select count(*) from dbo.ContactCORWorkOrderHeaderBucket
*/

CREATE PROCEDURE dbo.ContactCORWorkOrder_SP @TruncateBucketTable BIT = 0 AS

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- This is easier than adding WITH (NOLOCK) to every table.
SET NOCOUNT, XACT_ABORT ON
BEGIN TRY 

-------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #ValidWorkOrdersMoreDates

;WITH ValidWorkOrders AS ( 
	SELECT A.workorder_id, A.company_id, A.profit_ctr_id, A.customer_id, A.generator_id, 
		ISNULL(A.[start_date], A.date_added) AS [start_date], A.end_date, A.date_added,	A.[start_date] AS pure_start_date
	FROM dbo.WorkOrderHeader A
		INNER JOIN dbo.ContactCORCustomerBucket B ON A.customer_id = B.customer_id
	WHERE A.WorkOrder_status NOT IN ('V','X','T')
	-----
	UNION
	-----
	SELECT A.workorder_id, A.company_id, A.profit_ctr_id, A.customer_id, A.generator_id, 
		ISNULL(A.[start_date], A.date_added) AS [start_date], A.end_date, A.date_added,	A.[start_date] AS pure_start_date
	FROM dbo.WorkOrderHeader A
		INNER JOIN dbo.ContactCORGeneratorBucket B ON A.generator_id = B.generator_id AND B.direct_flag = 'D'
	WHERE A.WorkOrder_status NOT IN ('V','X','T')
),
Billing_Min_Invoice_Date AS ( 
	SELECT A.receipt_id, A.company_id, A.profit_ctr_id, MIN(A.invoice_date) AS MIN_invoice_date
	FROM dbo.Billing A 
	WHERE A.trans_source = 'W' AND A.status_code = 'I' AND A.invoice_date IS NOT NULL
	GROUP BY A.receipt_id, A.company_id, A.profit_ctr_id
),
ValidWorkOrdersMoreDates AS ( 
	SELECT A.workorder_id, A.company_id, A.profit_ctr_id, A.customer_id, A.generator_id, 
		A.[start_date], 
		C.service_date,
		B.date_request_initiated AS requested_date,
		B.date_est_arrive AS scheduled_date, 
		D.MIN_invoice_date AS invoice_date,
		----------------------
		CAST(NULL AS VARCHAR(20)) AS report_status,
		CAST(1 AS BIT) AS prices, 
		----------------------
		A.pure_start_date AS _start_date, 
		A.end_date AS _end_date, 
		B.date_act_arrive AS _date_act_arrive 
	FROM ValidWorkOrders A 
		LEFT JOIN dbo.WorkOrderStop B ON 
			A.workorder_id = B.workorder_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id AND B.stop_sequence_id = 1 AND 
			B.date_request_initiated IS NOT NULL
		LEFT JOIN dbo.BillingComment C ON 
			A.workorder_id = C.receipt_id AND A.company_id = C.company_id AND A.profit_ctr_id = C.profit_ctr_id AND 
			C.trans_source = 'W' AND C.service_date IS NOT NULL
		LEFT JOIN Billing_Min_Invoice_Date D ON
			A.WorkOrder_id = D.receipt_id AND A.company_id = D.company_id AND A.profit_ctr_id = D.profit_ctr_id 
)
SELECT A.workorder_id, A.company_id, A.profit_ctr_id, A.customer_id, A.generator_id, 
	A.[start_date], 
	------------------
	(CASE WHEN A.service_date IS NULL THEN ISNULL(B.date_act_arrive, A.[start_date]) ELSE A.service_date END) AS service_date, 
	------------------
	A.requested_date, A.scheduled_date, A.invoice_date, 
	------------------
	(CASE 
		WHEN (	A.requested_date IS NOT NULL AND A.scheduled_date IS NULL AND 
				NOT ISNULL(A._end_date, GETDATE() + 1) <= GETDATE() AND 
				A.invoice_date IS NULL ) 
				OR 
				(	A.requested_date IS NULL AND A.scheduled_date IS NULL AND A._start_date IS NULL AND A._end_date IS NULL AND A.scheduled_date IS NULL )				
		THEN 'Requested'
		WHEN A.scheduled_date IS NOT NULL AND NOT ISNULL(A._end_date, GETDATE() + 1) <= GETDATE() AND A.invoice_date IS NULL THEN 'Scheduled'
		WHEN ISNULL(A._date_act_arrive, GETDATE() + 1) <= GETDATE() AND A.invoice_date IS NULL THEN 'Completed'
		WHEN A.invoice_date IS NOT NULL THEN 'Invoiced'
		ELSE 'Unknown'
	END) AS report_status,
	------------------
	A.prices, A._start_date, A._end_date, A._date_act_arrive
INTO #ValidWorkOrdersMoreDates -- !!! This is the output of the CTE.
FROM ValidWorkOrdersMoreDates A
	LEFT JOIN dbo.WorkOrderStop B ON A.workorder_id = B.workorder_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id AND B.stop_sequence_id = 1 
-- 724524, 15s

--------------------------------------------------------------------------
DROP TABLE IF EXISTS #ContactWorkOrders

SELECT 
	B.contact_id, A.workorder_id, A.company_id, A.profit_ctr_id, A.customer_id, A.generator_id,	
	A.[start_date],	A.service_date,	A.requested_date, A.scheduled_date, A.invoice_date,	A.report_status, 1 AS prices
INTO #ContactWorkOrders
FROM #ValidWorkOrdersMoreDates A
	INNER JOIN dbo.ContactCORCustomerBucket B ON A.customer_id = B.customer_id
-- 3292374, 4s

--------------------------------------------------------------------------------------------------------------------------------------------------
-- Because the contact/customer combos have prices = 1, and contact/generator combos have prices = 0, we can't do a UNION to eliminate duplicates.
--------------------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO #ContactWorkOrders
SELECT 
	B.contact_id, A.workorder_id, A.company_id, A.profit_ctr_id, A.customer_id, A.generator_id,	
	A.[start_date],	A.service_date,	A.requested_date, A.scheduled_date, A.invoice_date,	A.report_status, 0 AS prices
FROM #ValidWorkOrdersMoreDates A
	INNER JOIN dbo.ContactCORGeneratorBucket B ON A.generator_id = B.generator_id AND B.direct_flag = 'D'
	LEFT JOIN #ContactWorkOrders C ON 
		B.contact_id = C.contact_id AND A.workorder_id = C.workorder_id AND A.company_id = C.company_id AND A.profit_ctr_id = C.profit_ctr_id
WHERE C.contact_id IS NULL
-- 37265, 4s

---------------------------------------------------------------------
-- Modify the dates for the demo customer: 888880.  Used for testing.
---------------------------------------------------------------------
UPDATE #ContactWorkOrders
SET	
	[start_date] = DATEADD(M, -1, GETDATE()),    -- Set start_date to 1 month earlier.
	service_date = DATEADD(M, -1, GETDATE()),    -- Set service_date to 1 month earlier.
	invoice_date = DATEADD(M, -1, GETDATE()) + 3 -- Set invoice_date to 1 month earlier than today + 3 days.
WHERE customer_id = 888880

------------------------------------------------------------------------------------------------------------------------
IF @TruncateBucketTable = 1 OR NOT EXISTS (SELECT 1 FROM dbo.ContactCORWorkOrderHeaderBucket) BEGIN
	TRUNCATE TABLE dbo.ContactCORWorkOrderHeaderBucket 

	INSERT INTO dbo.ContactCORWorkOrderHeaderBucket WITH (TABLOCK) ( -- Minimizes logging.
		contact_id,	workorder_id, company_id, profit_ctr_id, 
		[start_date], service_date, requested_date, scheduled_date,	report_status, invoice_date,
		customer_id, generator_id, prices )
	SELECT 
		contact_id,	workorder_id, company_id, profit_ctr_id, 
		[start_date], service_date, requested_date, scheduled_date,	report_status, invoice_date,
		customer_id, generator_id, prices
	FROM #ContactWorkOrders
END
ELSE BEGIN -- Bucket table has data.
	BEGIN TRAN

	DROP TABLE IF EXISTS #DMLAction

	------------------------------------------------------------------------------------------------------------------------------------------------
	-- It is faster to build a DML Action table that covers the 3 scenarios, rather than have 3 separate INSERT/UPDATE/DELETE checks or use a MERGE:
	--		1) Insert a row into the bucket table.  This occurs when a row does not exist in the bucket table.
	--		2) Delete a row from the bucket table.  This occurs when a row does not exist in the new/temp table.
	--		3) Update a row in the bucket table.  This occurs when we do have a match, but one of the columns is different.
	-- When Deleting or Updating a row, it's important to have the IDENTITY column from the bucket table.
	-- Obviously, when Inserting a row, the IDENTITY column is needed.
	------------------------------------------------------------------------------------------------------------------------------------------------
	SELECT 
		B.ContactCorWorkOrderHeaderBucket_uid, -- For Deletes or Updates, this column will have a value.  For Inserts, it will be NULL.
		(CASE 
			WHEN A.workorder_id IS NOT NULL AND B.workorder_id IS NULL THEN 'Insert'
			WHEN A.workorder_id IS NULL AND B.workorder_id IS NOT NULL THEN 'Delete'
			ELSE 'Update' -- Because NULL/NULL is not a valid case for any join, the only remaining case is NOT NULL/NOT NULL.
		END) AS [Action], 
		-- We only store the new/temp table values, as these will be used for Inserts (all values will be inserted) or Updates (a select few columns will be updated).
		A.contact_id, A.workorder_id, A.company_id, A.profit_ctr_id, A.customer_id, A.generator_id, 
		A.[start_date], A.service_date, A.requested_date, A.scheduled_date, A.invoice_date, A.report_status, A.prices
	INTO #DMLAction
	FROM #ContactWorkOrders A
		FULL OUTER JOIN dbo.ContactCORWorkOrderHeaderBucket B ON 
			A.contact_id = B.contact_id AND A.workorder_id = B.workorder_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id 
	WHERE -- It's faster to use NOT logic.
		NOT ( A.workorder_id IS NOT NULL AND B.workorder_id IS NOT NULL AND 
			  ISNULL(A.customer_id, -1) = ISNULL(B.customer_id, -1) AND ISNULL(A.generator_id, -1) = ISNULL(B.generator_id, -1) AND 
			  ISNULL(A.[start_date], '01/01/1776') = ISNULL(B.[start_date], '01/01/1776') AND ISNULL(A.service_date, '01/01/1776') = ISNULL(B.service_date, '01/01/1776') AND 
			  ISNULL(A.requested_date, '01/01/1776') = ISNULL(B.requested_date, '01/01/1776') AND ISNULL(A.scheduled_date, '01/01/1776') = ISNULL(B.scheduled_date, '01/01/1776') AND 
			  ISNULL(A.invoice_date, '01/01/1776') = ISNULL(B.invoice_date, '01/01/1776') AND
			  ISNULL(A.report_status, '') = ISNULL(B.report_status, '') AND ISNULL(A.prices, 0) = ISNULL(B.prices, 0) )

	IF (SELECT COUNT(*) FROM #DMLAction) > 0 BEGIN
		INSERT INTO dbo.ContactCORWorkOrderHeaderBucket (
			contact_id,	workorder_id, company_id, profit_ctr_id, 
			[start_date], service_date, requested_date, scheduled_date,	report_status, invoice_date,
			customer_id, generator_id, prices )
		SELECT
			contact_id,	workorder_id, company_id, profit_ctr_id, 
			[start_date], service_date, requested_date, scheduled_date,	report_status, invoice_date,
			customer_id, generator_id, prices
		FROM #DMLAction
		WHERE [Action] = 'Insert'

		DELETE FROM A
		FROM dbo.ContactCORWorkOrderHeaderBucket A
			INNER JOIN #DMLAction B ON A.ContactCorWorkOrderHeaderBucket_uid = B.ContactCorWorkOrderHeaderBucket_uid
		WHERE B.[Action] = 'Delete'

		UPDATE A -- It's easier just to update all columns rather than checking which one has changed.
		SET A.customer_id = B.customer_id, A.generator_id = B.generator_id, 
			A.[start_date] = B.[start_date], A.service_date  = B.service_date, A.requested_date = B.requested_date,
			A.scheduled_date = B.scheduled_date, A.invoice_date = B.invoice_date,
			A.report_status = B.report_status, A.prices = B.prices
		FROM dbo.ContactCORWorkOrderHeaderBucket A
			INNER JOIN #DMLAction B ON A.ContactCorWorkOrderHeaderBucket_uid = B.ContactCorWorkOrderHeaderBucket_uid
		WHERE B.[Action] = 'Update'
	END

	COMMIT TRAN
END

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @msg NVARCHAR(2048) = ERROR_MESSAGE()  
    RAISERROR (@msg, 16, 1)
    RETURN -1
END CATCH

GO

GRANT EXECUTE ON dbo.ContactCORWorkOrder_SP TO BUCKET_SERVICE
GO

/*
select top 10 * from ContactCORWorkOrderHeaderBucket order by contact_id, workorder_id

select * from dbo.WorkOrderHeader where workorder_id = 340000 AND company_id = 14 AND profit_ctr_id = 17
update dbo.WorkOrderHeader set WorkOrder_status = 'V' where workorder_id = 340000 AND company_id = 14 AND profit_ctr_id = 17 -- delete
-- update dbo.WorkOrderHeader set WorkOrder_status = 'A' where workorder_id = 340000 AND company_id = 14 AND profit_ctr_id = 17 -- restore (insert)

select * from dbo.WorkOrderHeader where workorder_id = 1171700 AND company_id = 14 AND profit_ctr_id = 5
update dbo.WorkOrderHeader set customer_id = 0 where workorder_id = 1171700 AND company_id = 14 AND profit_ctr_id = 5 -- update
-- update dbo.WorkOrderHeader set customer_id = 503 where workorder_id = 1171700 AND company_id = 14 AND profit_ctr_id = 5 -- restore (update)

-------------------------------------------------------------
select * from #ContactWorkOrders where workorder_id in ( 340000, 1171700 ) order by workorder_id, contact_id
select * from ContactCORWorkOrderHeaderBucket where workorder_id in ( 340000, 1171700 ) order by workorder_id, contact_id

select * from #DMLAction order by workorder_id, contact_id
select * from ContactCORWorkOrderHeaderBucket where ContactCorWorkOrderHeaderBucket_uid in ( select ContactCorWorkOrderHeaderBucket_uid from #DMLAction where action = 'delete')
  order by workorder_id, contact_id

-------------------------------------------------------------

select * from dbo.WorkOrderHeader where (workorder_id = 340000 AND company_id = 14 AND profit_ctr_id = 17) OR (workorder_id = 1171700 AND company_id = 14 AND profit_ctr_id = 5)

select * from ContactCORWorkOrderHeaderBucket 
where (workorder_id = 340000 AND company_id = 14 AND profit_ctr_id = 17) OR (workorder_id = 1171700 AND company_id = 14 AND profit_ctr_id = 5)
order by workorder_id, contact_id

*/

