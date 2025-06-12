-- USE PLT_AI
-- Receipt Bucket

-- DROP PROCEDURE IF EXISTS dbo.ContactCORReceipt_SP
GO

/*

EXEC dbo.ContactCORReceipt_SP -- 44s

*/

CREATE PROCEDURE dbo.ContactCORReceipt_SP @TruncateBucketTable BIT = 0 AS

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- This is easier than adding WITH (NOLOCK) to every table.
SET NOCOUNT, XACT_ABORT ON
BEGIN TRY 

--------------------------------------------------------------------------------------------------------------------
-- Step 1: The Receipt data is used by the normal and Kroger receipt sections, so save the data to tempdb for reuse.
--------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #ReceiptDetailRowNum

SELECT receipt_id, company_id, profit_ctr_id, customer_id, generator_id, receipt_date, line_id,
	ROW_NUMBER() OVER (PARTITION BY receipt_id, company_id, profit_ctr_id ORDER BY line_id) AS RowNum
INTO #ReceiptDetailRowNum
FROM dbo.Receipt
WHERE receipt_status NOT IN ('V', 'R') AND trans_mode = 'I' AND trans_type = 'D' AND fingerpr_status = 'A' AND 
	receipt_id IS NOT NULL AND customer_id IS NOT NULL AND generator_id IS NOT NULL
/*
-- Below code was added to hide records that were submitted but not in Billing 
-- ($0, no "print on invoice flag" etc.  Those are just not considered invoiced,
--  so once submitted, they either show up because they're in Billing/Invoiced,
--  or they don't show up anymore - even if they appeared before being submitted
--  This is standard behavior since ever, in EQAI)
-- Discussion with Paul K 9/9/20 - show them after all.
	-- following code commented out.

	AND isnull(submitted_flag, 'F') = 'T'
	AND EXISTS (select 1 from billing where receipt_id = Receipt.receipt_id and company_id = Receipt.company_id and profit_ctr_id = Receipt.profit_ctr_id and trans_source = 'R' and status_code in ('S', 'H', 'I', 'N'))
UNION
SELECT receipt_id, company_id, profit_ctr_id, customer_id, generator_id, receipt_date, line_id,
	ROW_NUMBER() OVER (PARTITION BY receipt_id, company_id, profit_ctr_id ORDER BY line_id) AS RowNum
FROM dbo.Receipt
WHERE receipt_status NOT IN ('V', 'R') AND trans_mode = 'I' AND trans_type = 'D' AND fingerpr_status = 'A' AND 
	receipt_id IS NOT NULL AND customer_id IS NOT NULL AND generator_id IS NOT NULL
	AND isnull(submitted_flag, 'F') = 'F'
	AND NOT EXISTS (select 1 from billing where receipt_id = Receipt.receipt_id and company_id = Receipt.company_id and profit_ctr_id = Receipt.profit_ctr_id and trans_source = 'R' and status_code in ('S', 'H', 'I', 'N'))
*/

CREATE CLUSTERED INDEX Index1 ON #ReceiptDetailRowNum (receipt_id, company_id, profit_ctr_id)
-- 5976112, 11s (6s with index)

-------------------------------------------------------------------------
-- Step 2: Delete receipts that have 2 or more customer/generator combos.
--         This is only .02% of the total and is mostly older data.
-------------------------------------------------------------------------
;WITH BadReceipts AS (
	SELECT receipt_id, company_id, profit_ctr_id, COUNT(*) AS Cnt
	FROM (
		SELECT DISTINCT receipt_id, company_id, profit_ctr_id, customer_id, generator_id
		FROM dbo.#ReceiptDetailRowNum
		--FROM dbo.Receipt -- ??? Connect to Receipt and not #ReceiptDetailRowNum because we want to exclude all bad receipts, not just those in #ReceiptDetailRowNum.
	) X
	GROUP BY receipt_id, company_id, profit_ctr_id
	HAVING COUNT(*) > 1
)
DELETE FROM A
FROM #ReceiptDetailRowNum A
	INNER JOIN BadReceipts B ON A.receipt_id = B.receipt_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id
-- 7340, 5s

------------------------------------------------------------------------------------------------------------
-- Step 3: Because the Receipt Bucket date values are needed by both the normal and Kroger receipt sections, 
--		   save them to tempdb for reuse.
------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #ReceiptManifestSignDate
DROP TABLE IF EXISTS #ReceiptTransporterSignDate
DROP TABLE IF EXISTS #BillingInvoiceDate

SELECT receipt_id, company_id, profit_ctr_id, MIN(generator_sign_date) AS MIN_generator_sign_date
INTO #ReceiptManifestSignDate
FROM dbo.ReceiptManifest
WHERE generator_sign_date IS NOT NULL
GROUP BY receipt_id, company_id, profit_ctr_id
-- 236558, 1s

CREATE CLUSTERED INDEX Index1 ON #ReceiptManifestSignDate (receipt_id, company_id, profit_ctr_id)

SELECT receipt_id, company_id, profit_ctr_id, transporter_sign_date
INTO #ReceiptTransporterSignDate
FROM dbo.ReceiptTransporter
WHERE transporter_sequence_id = 1 AND transporter_sign_date IS NOT NULL
-- 853338, 1s

CREATE CLUSTERED INDEX Index1 ON #ReceiptTransporterSignDate (receipt_id, company_id, profit_ctr_id)

SELECT receipt_id, company_id, profit_ctr_id, MIN(invoice_date) AS MIN_invoice_date
INTO #BillingInvoiceDate
FROM dbo.Billing
WHERE trans_source = 'R' AND status_code = 'I' AND invoice_date IS NOT NULL
GROUP BY receipt_id, company_id, profit_ctr_id
-- 2408808, 1s

CREATE CLUSTERED INDEX Index1 ON #BillingInvoiceDate (receipt_id, company_id, profit_ctr_id)
-- All 3 temp tables with clustered indexes: 4s

----------------------------------------------------------------
-- Step 4: This is the normal (i.e. non-Kroger) receipt section.
----------------------------------------------------------------
DROP TABLE IF EXISTS #MasterList

SELECT A.receipt_id, A.company_id, A.profit_ctr_id, A.customer_id, A.generator_id, 
	A.receipt_date, ISNULL(B.MIN_generator_sign_date, C.transporter_sign_date) AS pickup_date, D.MIN_invoice_date AS invoice_date
INTO #MasterList
FROM #ReceiptDetailRowNum A
	LEFT JOIN #ReceiptManifestSignDate B ON 
		A.receipt_id = B.receipt_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id
	LEFT JOIN #ReceiptTransporterSignDate C ON 
		A.receipt_id = C.receipt_id AND A.company_id = C.company_id AND A.profit_ctr_id = C.profit_ctr_id
	LEFT JOIN #BillingInvoiceDate D ON 
		A.receipt_id = D.receipt_id AND A.company_id = D.company_id AND A.profit_ctr_id = D.profit_ctr_id
WHERE A.RowNum = 1
-- 2295865, 6s, receipt_id/company_id/profit_ctr_id is unique at this point. 

---------------------------------------------
-- Step 5: Look for contacts via customer_id.
---------------------------------------------
DROP TABLE IF EXISTS #ContactReceipts

SELECT B.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, A.receipt_date, A.pickup_date, A.invoice_date, A.customer_id, A.generator_id, CAST(1 AS BIT) prices
INTO #ContactReceipts 
FROM #MasterList A 
	INNER JOIN dbo.ContactCORCustomerBucket B ON A.customer_id = B.customer_id
-- 7805997, 2s

-------------------------------------------------------------------------------------------------------------
-- Step 6: Because the contact/customer combos have prices = 1, and contact/generator combos have prices = 0,
--         we can't do a UNION to join the 2 sets and eliminate duplicates.
-------------------------------------------------------------------------------------------------------------
INSERT INTO #ContactReceipts
SELECT 
	B.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, A.receipt_date, A.pickup_date, A.invoice_date, A.customer_id, A.generator_id, CAST(0 AS BIT) prices
FROM #MasterList A 
	INNER JOIN dbo.ContactCORGeneratorBucket B ON A.generator_id = B.generator_id AND B.direct_flag = 'D'
WHERE NOT EXISTS (
		SELECT 1 FROM #ContactReceipts X
		WHERE X.contact_id = B.contact_id AND X.receipt_id = A.receipt_id AND X.company_id = A.company_id AND X.profit_ctr_id = A.profit_ctr_id
	)
-- 259212, 2s

---------------------------------------------------------------------------------------------------------------------------------
-- Step 7: Kroger receipt section. I was not able to get good performance with this query inside a CTE, so moved to a temp table.
---------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #KrogerContactReceiptDetail

SELECT DISTINCT 
	X.contact_id, RH.receipt_id, RH.company_id, RH.profit_ctr_id, X.customer_id, X.generator_id, R.receipt_date, R.line_id, R.RowNum
INTO #KrogerContactReceiptDetail
FROM dbo.ContactCORWorkorderHeaderBucket X
	INNER JOIN dbo.WorkOrderHeader WOH ON 
		X.workorder_id = WOH.workorder_id AND X.company_id = WOH.company_id AND X.profit_ctr_id = WOH.profit_ctr_id AND WOH.trip_stop_rate_flag = 'T'
	INNER JOIN dbo.ReceiptHeader RH ON 
		WOH.trip_id = RH.trip_id AND WOH.trip_sequence_id = RH.trip_sequence_id AND RH.receipt_status NOT IN ('V', 'R') AND RH.trans_mode = 'I'
	INNER JOIN #ReceiptDetailRowNum R ON 
		RH.receipt_id = R.receipt_id AND RH.company_id = R.company_id AND RH.profit_ctr_id = R.profit_ctr_id AND 
		WOH.generator_id = R.generator_id -- We don't want receipts where the workorder generator is different from the receipt generator.
	INNER JOIN dbo.Customer C ON 
		RH.customer_id = C.customer_id AND C.eq_flag = 'T'
	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Jonathan's Comment:
	-- In this case, the join (to TripStopRate) is just to limit the records being returned by requiring a match in some other table – not necessarily to bring data from it.  
	-- In the bucket case for Kroger we’re not hard coding “Kroger” by name or number – but they are the only customer using the TripStopRate table.  
	-- That table however is optional (i.e. they could have trips that DO use it, and trips that DON’T) – only Trips (TripHeader records) with a specific flag set need to reference it.
	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	INNER JOIN dbo.TripStopRate TSR ON X.customer_id = TSR.customer_id 
	INNER JOIN dbo.TripHeader TH ON WOH.trip_id = TH.trip_id 
-- 1432344, 5s

----------------------------------------
-- Step 8: Kroger contacts and receipts.
----------------------------------------
DROP TABLE IF EXISTS #KrogerContactReceipts

;WITH KrogerMasterList AS ( 
	SELECT DISTINCT 
		A.receipt_id, A.company_id, A.profit_ctr_id, A.customer_id, A.generator_id, A.receipt_date,
		ISNULL(B.MIN_generator_sign_date, C.transporter_sign_date) AS pickup_date, D.MIN_invoice_date AS invoice_date
	FROM #KrogerContactReceiptDetail A
		LEFT JOIN #ReceiptManifestSignDate B ON 
			A.receipt_id = B.receipt_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id
		LEFT JOIN #ReceiptTransporterSignDate C ON 
			A.receipt_id = C.receipt_id AND A.company_id = C.company_id AND A.profit_ctr_id = C.profit_ctr_id
		LEFT JOIN #BillingInvoiceDate D ON 
			A.receipt_id = D.receipt_id AND A.company_id = D.company_id AND A.profit_ctr_id = D.profit_ctr_id
	WHERE A.RowNum = 1
)
SELECT DISTINCT
	B.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, A.receipt_date, A.pickup_date, A.invoice_date, A.customer_id, A.generator_id
INTO #KrogerContactReceipts
FROM KrogerMasterList A 
	INNER JOIN #KrogerContactReceiptDetail B ON 
		A.receipt_id = B.receipt_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id
-- 396492, 4s

---------------------------------------------------------------------------------------
-- Step 9: Selectively combine the normal and Kroger receipts together.
--         Do not combine Kroger receipts that already exist as the normal receipt.
--         For those receipts that only exists as Kroger receipts, give them price = 0.
---------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #AllContactReceipts

SELECT contact_id, receipt_id, company_id, profit_ctr_id, receipt_date, pickup_date, invoice_date, customer_id, generator_id, prices -- prices = 1 for customer contacts and prices = 0 for generator contacts.
INTO #AllContactReceipts
FROM #ContactReceipts
---------
UNION ALL
---------
SELECT contact_id, receipt_id, company_id, profit_ctr_id, receipt_date, pickup_date, invoice_date, customer_id, generator_id, CAST(0 AS BIT) prices
FROM #KrogerContactReceipts A
WHERE NOT EXISTS (
		SELECT 1 FROM #ContactReceipts X
		WHERE X.contact_id = A.contact_id AND X.receipt_id = A.receipt_id AND X.company_id = A.company_id AND X.profit_ctr_id = A.profit_ctr_id
	)
-- 8428640, 3s

---------------------------------------------------------------------
-- Modify the dates for the demo customer: 888880.  Used for testing.
---------------------------------------------------------------------
UPDATE #AllContactReceipts
SET	receipt_date = ( CASE WHEN A.receipt_date IS NOT NULL THEN X.receipt_date ELSE NULL END ), 
	pickup_date  = ( CASE WHEN A.pickup_date  IS NOT NULL THEN X.pickup_date  ELSE NULL END ), 
	invoice_date = ( CASE WHEN A.invoice_date IS NOT NULL THEN X.invoice_date ELSE NULL END )
FROM #AllContactReceipts A
	INNER JOIN (
		SELECT 
			contact_id, receipt_id, company_id, profit_ctr_id,
			DATEADD(M, -1, GETDATE()) - (5 * DENSE_RANK() OVER (ORDER BY receipt_date, receipt_id DESC))     AS receipt_date,
			DATEADD(M, -1, GETDATE()) - (5 * DENSE_RANK() OVER (ORDER BY receipt_date, receipt_id DESC)) - 3 AS pickup_date,
			DATEADD(M, -1, GETDATE()) - (5 * DENSE_RANK() OVER (ORDER BY receipt_date, receipt_id DESC)) + 3 AS invoice_date	
		FROM #AllContactReceipts
		WHERE customer_id = 888880
		) X ON A.contact_id = X.contact_id AND A.receipt_id = X.receipt_id AND A.company_id = X.company_id AND A.profit_ctr_id = X.profit_ctr_id
WHERE A.customer_id = 888880

---------------------------------------------------------------------------------------------------------------------------
-- Insert, Update, or Delete data for permanent Contact/Receipt Bucket table.
-- If Bucket table has no data (which would only happen on the very first run), insert all temp data into the Bucket table.
-- If Bucket table has data (which happens every time, except the first time), look for records to insert or delete.
-- Inserting or deleting rows in the permanent Bucket table will reduce logging immensely over other methods.
---------------------------------------------------------------------------------------------------------------------------
IF @TruncateBucketTable = 1 OR NOT EXISTS (SELECT 1 FROM dbo.ContactCORReceiptBucket) BEGIN
	TRUNCATE TABLE dbo.ContactCORReceiptBucket

	INSERT INTO dbo.ContactCORReceiptBucket WITH (TABLOCK) ( contact_id, receipt_id, company_id, profit_ctr_id, receipt_date, pickup_date, invoice_date, customer_id, generator_id, prices ) -- Minimizes logging.
	SELECT contact_id, receipt_id, company_id, profit_ctr_id, receipt_date, pickup_date, invoice_date, customer_id, generator_id, prices
	FROM #AllContactReceipts
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
		B.ContactCORReceiptBucket_UID, -- For Deletes or Updates, this column will have a value.  For Inserts, it will be NULL.
		(CASE 
			WHEN A.receipt_id IS NOT NULL AND B.receipt_id IS NULL THEN 'Insert'
			WHEN A.receipt_id IS NULL AND B.receipt_id IS NOT NULL THEN 'Delete'
			ELSE 'Update' -- Because NULL/NULL is not a valid case for any join, the only remaining case is NOT NULL/NOT NULL.
		END) AS [Action], 
		-- We only store the new/temp table values, as these will be used for Inserts (all values will be inserted) or Updates (a select few columns will be updated).
		A.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, A.receipt_date, A.pickup_date, A.invoice_date, A.customer_id, A.generator_id, A.prices
	INTO #DMLAction
	FROM #AllContactReceipts A
		FULL OUTER JOIN dbo.ContactCORReceiptBucket B ON 
			A.contact_id = B.contact_id AND A.receipt_id = B.receipt_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id
	-------------------------------------------------------------------------------------------------------------
	-- It's 3 seconds faster to use NOT logic.
	-- In normal logic we want the following:
	-- 1) A.receipt_id IS NULL OR
	-- 2) B.receipt_id IS NULL OR
	-- 3) A.receipt_id IS NOT NULL AND B.receipt_id IS NOT NULL AND 
	--   (A.receipt_date <> B.receipt_date OR A.pickup_date <> B.pickup_date OR A.invoice_date <> B.invoice_date)
	-------------------------------------------------------------------------------------------------------------
	WHERE NOT ( A.receipt_id IS NOT NULL AND B.receipt_id IS NOT NULL AND 
				ISNULL(A.receipt_date, '01/01/1776') = ISNULL(B.receipt_date, '01/01/1776') AND 
				ISNULL(A.pickup_date, '01/01/1776') = ISNULL(B.pickup_date, '01/01/1776') AND 
				ISNULL(A.invoice_date, '01/01/1776') = ISNULL(B.invoice_date, '01/01/1776') AND
				A.customer_id = B.customer_id AND 
				A.generator_id = B.generator_id AND
				A.prices = B.prices )
	-- 7s

	IF (SELECT COUNT(*) FROM #DMLAction) > 0 BEGIN
		INSERT INTO dbo.ContactCORReceiptBucket ( contact_id, receipt_id, company_id, profit_ctr_id, receipt_date, pickup_date, invoice_date, customer_id, generator_id, prices )
		SELECT A.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, A.receipt_date, A.pickup_date, A.invoice_date, A.customer_id, A.generator_id, 1 AS prices
		FROM #DMLAction A
		WHERE [Action] = 'Insert'

		DELETE FROM A
		FROM dbo.ContactCORReceiptBucket A
			INNER JOIN #DMLAction B ON A.ContactCORReceiptBucket_UID = B.ContactCORReceiptBucket_UID
		WHERE B.[Action] = 'Delete'

		UPDATE A -- It's easier/faster to just update all the columns rather than checking which one has changed.
		SET A.receipt_date = B.receipt_date, 
			A.pickup_date  = B.pickup_date,
			A.invoice_date = B.invoice_date,
			A.customer_id  = B.customer_id,
			A.generator_id = B.generator_id,
			A.prices       = B.prices
		FROM dbo.ContactCORReceiptBucket A
			INNER JOIN #DMLAction B ON A.ContactCORReceiptBucket_UID = B.ContactCORReceiptBucket_UID
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

GRANT EXECUTE ON dbo.ContactCORReceipt_SP TO BUCKET_SERVICE
GO

/*
select top 10 * from ContactCORReceiptBucket

select * from dbo.receipt where receipt_id = 79205 and company_id = 25 and profit_ctr_id = 0
select * from dbo.ContactCORReceiptBucket where receipt_id = 79205 and company_id = 25 and profit_ctr_id = 0 -- 9 rows
-- update dbo.receipt set receipt_status = 'V' where receipt_id = 79205 and company_id = 25 and profit_ctr_id = 0
-- update dbo.receipt set receipt_status = 'A' where receipt_id = 79205 and company_id = 25 and profit_ctr_id = 0

select * from dbo.receipt where receipt_id = 536385 and company_id = 2 and profit_ctr_id = 0
select * from dbo.ContactCORReceiptBucket where receipt_id = 536385 and company_id = 2 and profit_ctr_id = 0 -- 8 rows
-- update dbo.receipt set receipt_status = 'V' where receipt_id = 536385 and company_id = 2 and profit_ctr_id = 0
-- update dbo.receipt set receipt_status = 'A' where receipt_id = 536385 and company_id = 2 and profit_ctr_id = 0

select * from dbo.receipt where receipt_id = 43169 and company_id = 27 and profit_ctr_id = 0
select * from dbo.ContactCORReceiptBucket where receipt_id = 43169 and company_id = 27 and profit_ctr_id = 0 -- 30 rows
-- update dbo.receipt set receipt_date = '09/29/1972' where receipt_id = 43169 and company_id = 27 and profit_ctr_id = 0
-- update dbo.receipt set receipt_date = '01/20/2011' where receipt_id = 43169 and company_id = 27 and profit_ctr_id = 0
*/

