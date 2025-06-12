-- USE PLT_AI
-- Biennial Bucket

--DROP PROCEDURE IF EXISTS dbo.ContactCORBiennial_SP
GO

/*
-- DBCC DROPCLEANBUFFERS 
EXEC dbo.ContactCORBiennial_SP -- 1:00

SELECT count(*) FROM dbo.ContactCORBiennialBucket -- 7423495

*/

CREATE PROCEDURE dbo.ContactCORBiennial_SP @TruncateBucketTable BIT = 0 AS

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- This is easier than adding WITH (NOLOCK) to every table.
SET NOCOUNT, XACT_ABORT ON
BEGIN TRY 

--------------------------------------------------------------------------------------------------------------------------------
-- Must save receipts to a temp table because we have to delete "bad receipts" from this list and then reuse this temp table and
--   we can't do this with a CTE.
--------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #AllValidReceipts

SELECT A.receipt_id, A.company_id, A.profit_ctr_id, A.customer_id, A.generator_id, A.receipt_date, A.profile_id, B.orig_customer_id
INTO #AllValidReceipts
FROM dbo.Receipt A
	INNER JOIN dbo.[Profile] B ON A.profile_id = B.profile_id
WHERE A.receipt_status NOT IN ('V', 'R') AND A.trans_mode = 'I' AND A.trans_type = 'D' AND A.fingerpr_status = 'A' AND 
	A.receipt_id IS NOT NULL AND A.customer_id IS NOT NULL AND A.generator_id IS NOT NULL
-- 5975543

---------------------------------------------------------------------
-- Delete bad receipts that have 2 or more customer/generator combos.
---------------------------------------------------------------------
;WITH BadReceipts AS (
	SELECT receipt_id, company_id, profit_ctr_id, COUNT(*) AS Cnt
	FROM (
		SELECT DISTINCT receipt_id, company_id, profit_ctr_id, customer_id, generator_id 
		FROM #AllValidReceipts
	) X
	GROUP BY receipt_id, company_id, profit_ctr_id
	HAVING COUNT(*) > 1
)
DELETE FROM A
FROM #AllValidReceipts A
	INNER JOIN BadReceipts B ON A.receipt_id = B.receipt_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id
-- 7340, 3s

-------------------------------------------
DROP TABLE IF EXISTS #DistinctReceiptProfiles

;WITH DistinctProfiles AS (
	SELECT DISTINCT profile_id FROM dbo.ContactCORProfileBucket -- It's faster to do the DISTINCT in a CTE and then join later.
)
SELECT DISTINCT -- The DISTINCT eliminates rows with the same profile_id.
	A.receipt_id, A.company_id, A.profit_ctr_id, A.customer_id, A.generator_id, A.receipt_date, A.profile_id
INTO #DistinctReceiptProfiles
FROM #AllValidReceipts A
	INNER JOIN DistinctProfiles B ON A.profile_id = B.profile_id
-- 3140148, 4s

-- select * from #AllValidReceipts where receipt_id = 422249 and company_id = 2 and profit_ctr_id = 0
-- select * from #DistinctReceiptProfiles where receipt_id = 422249 and company_id = 2 and profit_ctr_id = 0

--------------------------------------------------------------------------------------------------------------------------------------------------
-- At this point, the only difference per receipt_id/company_id/profit_ctr_id/customer_id/generator_id/receipt_date is the profile_id and line_id.
--------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #BiennialFinished

;WITH ContactProfiles AS ( 
	SELECT contact_id, profile_id
	FROM dbo.ContactCORProfileBucket 
), 
ReceiptBucketDates AS ( 
	SELECT DISTINCT receipt_id, company_id, profit_ctr_id, pickup_date, invoice_date
	FROM dbo.ContactCORReceiptBucket
),
DistinctReceipts AS (
	-- DISTINCT eliminates the profile_ids.
	SELECT DISTINCT receipt_id, company_id, profit_ctr_id, customer_id, generator_id, receipt_date FROM #DistinctReceiptProfiles
),
DistinctReceiptsWithDates AS ( 
	SELECT A.receipt_id, A.company_id, A.profit_ctr_id, A.customer_id, A.generator_id, A.receipt_date, D.pickup_date, D.invoice_date
	FROM DistinctReceipts A 
		LEFT JOIN ReceiptBucketDates D ON 
			A.receipt_id = D.receipt_id AND A.company_id = D.company_id AND A.profit_ctr_id = D.profit_ctr_id
), 
-------------------------------
AllReceiptsOrigCustomer AS ( 
	SELECT X.receipt_id, X.company_id, X.profit_ctr_id, X.orig_customer_id, 
		( ROW_NUMBER() OVER (PARTITION BY X.receipt_id, X.company_id, X.profit_ctr_id ORDER BY X.orig_customer_id) ) AS RowNbr
	FROM (
		SELECT DISTINCT A.receipt_id, A.company_id, A.profit_ctr_id, A.orig_customer_id
		FROM #AllValidReceipts A -- Must use the (larger) valid receipt list and not the (smaller) receipts with valid profiles list.
		WHERE A.orig_customer_id IS NOT NULL -- We are only interested in building a list of non-null orig_customer_ids.
		) X
), 
AllReceiptsOrigCustomerPivot AS (
	SELECT receipt_id, company_id, profit_ctr_id,
		CAST(
			REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
				CONCAT(',', [1], ',', [2], ',', [3], ',', [4], ',', [5], ',', [6], ',', [7], ',', [8], ',', [9], ',', [10], ','), 
			',,', ','), ',,', ','), ',,', ','), ',,', ','), ',,', ','), ',,', ','), ',,', ','), ',,', ','), ',,', ',') 
		AS VARCHAR(100)) AS orig_customer_id_list
	FROM AllReceiptsOrigCustomer
	PIVOT
	( 
		SUM(orig_customer_id) -- There is no actual summing.  The PIVOT syntax requires an aggregate function.
		FOR RowNbr IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10]) -- These column names must be the same as the RowNbr values.
	) X
) -- 169978, 19s
-------------------------------
SELECT DISTINCT -- DISTINCT eliminates the 1 or more profiles per receipt.
	C.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, A.receipt_date, A.pickup_date, A.invoice_date,
	A.customer_id, D.orig_customer_id_list, A.generator_id
INTO #BiennialFinished -- !!! This is the output of the CTE.
FROM DistinctReceiptsWithDates A
	INNER JOIN #DistinctReceiptProfiles B ON 
		A.receipt_id = B.receipt_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id
	INNER JOIN ContactProfiles C ON 
		B.profile_id = C.profile_id
	LEFT JOIN AllReceiptsOrigCustomerPivot D ON 
		A.receipt_id = D.receipt_id AND A.company_id = D.company_id AND A.profit_ctr_id = D.profit_ctr_id
-- 8853649, 29s

-------------------------------------------------
-- Modify the dates for the demo customer: 888880
-------------------------------------------------
UPDATE #BiennialFinished
SET	receipt_date   = DATEADD(M, -1, GETDATE()),    -- Set receipt_date to 1 month earlier than today.
	pickup_date = DATEADD(M, -1, GETDATE()) - 3,   -- Set pickup_date to 1 month earlier than today - 3 days.
	invoice_date   = DATEADD(M, -1, GETDATE()) + 3 -- Set invoice_date to 1 month earlier than today + 3 days..
WHERE customer_id = 888880

------------------------------------------------------------------------------------------------
IF @TruncateBucketTable = 1 OR NOT EXISTS (SELECT 1 FROM dbo.ContactCORBiennialBucket) BEGIN
	TRUNCATE TABLE dbo.ContactCORBiennialBucket 

	INSERT INTO dbo.ContactCORBiennialBucket WITH (TABLOCK) ( contact_id, receipt_id, company_id, profit_ctr_id, receipt_date, pickup_date, invoice_date, customer_id, orig_customer_id_list, generator_id ) -- Minimizes logging.
	SELECT contact_id, receipt_id, company_id, profit_ctr_id, receipt_date, pickup_date, invoice_date, customer_id, orig_customer_id_list, generator_id 
	FROM #BiennialFinished
	-- 8143570, 60-70s
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
		B.ContactCORBiennialBucket_uid, -- For Deletes or Updates, this column will have a value.  For Inserts, it will be NULL.
		(CASE 
			WHEN A.receipt_id IS NOT NULL AND B.receipt_id IS NULL THEN 'Insert'
			WHEN A.receipt_id IS NULL AND B.receipt_id IS NOT NULL THEN 'Delete'
			ELSE 'Update' -- Because NULL/NULL is not a valid case for any join, the only remaining case is NOT NULL/NOT NULL.
		END) AS [Action], 
		-- We only store the new/temp table values, as these will be used for Inserts (all values will be inserted) or Updates (a select few columns will be updated).
		A.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, A.receipt_date, A.pickup_date, A.invoice_date, 
		A.customer_id, A.orig_customer_id_list, A.generator_id
	INTO #DMLAction
	FROM #BiennialFinished A
		FULL OUTER JOIN dbo.ContactCORBiennialBucket B ON 
			A.contact_id = B.contact_id AND A.receipt_id = B.receipt_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id
	WHERE NOT ( A.receipt_id IS NOT NULL AND B.receipt_id IS NOT NULL AND 
				ISNULL(A.receipt_date, '01/01/1776') = ISNULL(B.receipt_date, '01/01/1776') AND 
				ISNULL(A.pickup_date, '01/01/1776') = ISNULL(B.pickup_date, '01/01/1776') AND 
				ISNULL(A.invoice_date, '01/01/1776') = ISNULL(B.invoice_date, '01/01/1776') AND	
				A.customer_id = B.customer_id AND 
				ISNULL(A.orig_customer_id_list, '') = ISNULL(B.orig_customer_id_list, '') AND
				A.generator_id = B.generator_id )
	-- 7s

	IF (SELECT COUNT(*) FROM #DMLAction) > 0 BEGIN
		INSERT INTO dbo.ContactCORBiennialBucket ( contact_id, receipt_id, company_id, profit_ctr_id, receipt_date, pickup_date, invoice_date, customer_id, orig_customer_id_list, generator_id )
		SELECT A.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, A.receipt_date, A.pickup_date, A.invoice_date, A.customer_id, A.orig_customer_id_list, A.generator_id
		FROM #DMLAction A
		WHERE [Action] = 'Insert'

		DELETE FROM A
		FROM dbo.ContactCORBiennialBucket A
			INNER JOIN #DMLAction B ON A.ContactCORBiennialBucket_uid = B.ContactCORBiennialBucket_uid
		WHERE B.[Action] = 'Delete'

		UPDATE A -- It's easier just to update all columns rather than checking which one has changed.
		SET A.receipt_date = B.receipt_date, 
			A.pickup_date  = B.pickup_date,
			A.invoice_date = B.invoice_date,
			A.customer_id = B.customer_id,
			A.orig_customer_id_list = B.orig_customer_id_list,
			A.generator_id = B.generator_id
		FROM dbo.ContactCORBiennialBucket A
			INNER JOIN #DMLAction B ON A.ContactCORBiennialBucket_uid = B.ContactCORBiennialBucket_uid
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

GRANT EXECUTE ON dbo.ContactCORBiennial_SP TO BUCKET_SERVICE
GO

/*

select top 10 * from ContactCORBiennialBucket where customer_id <> 888880 order by receipt_id desc, company_id, profit_ctr_id, customer_id, generator_id

select * from dbo.Receipt where receipt_id = 2086295 and company_id = 21 and profit_ctr_id = 0
update dbo.Receipt set receipt_status = 'V' where receipt_id = 2086295 and company_id = 21 and profit_ctr_id = 0 -- delete
-- update dbo.Receipt set receipt_status = 'N' where receipt_id = 2086295 and company_id = 21 and profit_ctr_id = 0 -- restore (insert)

-- update ContactCORBiennialBucket set orig_customer_id_list = 'derek' where receipt_id = 2086295 and company_id = 21 and profit_ctr_id = 0 -- update

-------------------------------------------------------------
select * from #BiennialFinished where (receipt_id = 2086295 and company_id = 21 and profit_ctr_id = 0) or (receipt_id = 2086294 and company_id = 21 and profit_ctr_id = 0)
order by receipt_id desc

select * from ContactCORBiennialBucket where (receipt_id = 2086295 and company_id = 21 and profit_ctr_id = 0) or (receipt_id = 2086294 and company_id = 21 and profit_ctr_id = 0)
order by receipt_id desc

select * from #DMLAction order by receipt_id, contact_id

select * from ContactCORBiennialBucket where ContactCORBiennialBucket_uid in ( select ContactCORBiennialBucket_uid from #DMLAction where action = 'delete')
order by receipt_id, contact_id

-------------------------------------------------------------

select * from dbo.Receipt where (receipt_id = 2086295 and company_id = 21 and profit_ctr_id = 0) or (receipt_id = 2086294 and company_id = 21 and profit_ctr_id = 0)
select * from ContactCORBiennialBucket where (receipt_id = 2086295 and company_id = 21 and profit_ctr_id = 0) or (receipt_id = 2086294 and company_id = 21 and profit_ctr_id = 0)

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

DROP TABLE IF EXISTS #oldbiennial

select A.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, A.customer_id, A.generator_id, A.orig_customer_id_list, 
	A.receipt_date, A.pickup_date, A.invoice_date
into #oldbiennial
from dbo.ContactCORBiennialBucket A
	inner join dbo.CORContact C on A.contact_id = C.contact_id

-------------------------
DROP TABLE IF EXISTS #diff

select coalesce(A.contact_id, B.contact_id) AS contact_id, coalesce(A.receipt_id, B.receipt_id) AS receipt_id,  
	coalesce(A.company_id, B.company_id) AS company_id, coalesce(A.profit_ctr_id, B.profit_ctr_id) AS profit_ctr_id, 
	coalesce(A.customer_id, B.customer_id) AS customer_id,  coalesce(A.generator_id, B.generator_id) AS generator_id, 
	A.orig_customer_id_list AS A_orig_customer_id_list, B.orig_customer_id_list AS B_orig_customer_id_list, 
	A.receipt_date AS A_receipt_date, B.receipt_date AS B_receipt_date,
	A.pickup_date AS A_pickup_date, B.pickup_date AS B_pickup_date,
	A.invoice_date AS A_invoice_date, B.invoice_date AS B_invoice_date,
	A.receipt_id AS A_nullcheck, B.receipt_id AS B_nullcheck
into #diff
from #BiennialFinished A
	full outer join #oldbiennial B on 
		A.contact_id = B.contact_id AND A.receipt_id = B.receipt_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id AND 
		ISNULL(A.customer_id, -1) = ISNULL(B.customer_id, -1) AND ISNULL(A.generator_id, -1) = ISNULL(B.generator_id, -1)
where A.contact_id is null or B.contact_id is null
--where A.contact_id is not null and B.contact_id is not null and
--	( ISNULL(A.orig_customer_id_list, '') <> ISNULL(B.orig_customer_id_list, '') OR 
--		ISNULL(A.receipt_date, '01/01/1776') <> ISNULL(B.receipt_date, '01/01/1776') OR
--		ISNULL(A.pickup_date, '01/01/1776') <> ISNULL(B.pickup_date, '01/01/1776') OR
--		ISNULL(A.invoice_date, '01/01/1776') <> ISNULL(B.invoice_date, '01/01/1776') OR
--	)
	
-------------------------
select * from #diff 
where B_nullcheck is null
order by 2, 3, 4, 1

select * from #diff 
where A_nullcheck is null
order by 2, 3, 4, 1

select * from #diff where A_orig_customer_id_list IS NOT NULL and B_orig_customer_id_list IS NULL
select * from #diff where A_orig_customer_id_list IS NULL and B_orig_customer_id_list IS NOT NULL

---------------------------------------------------------------------------------------------------------

select * from #BiennialFinished where receipt_id = 39092 and company_id = 29 and profit_ctr_id = 0 order by 2, 3, 4, 5, 6, 1
select * from #oldbiennial		where receipt_id = 39092 and company_id = 29 and profit_ctr_id = 0 order by 2, 3, 4, 5, 6, 1

select A.receipt_id, A.company_id, A.profit_ctr_id, A.customer_id, A.generator_id, A.profile_id, B.orig_customer_id, A.receipt_date, A.trans_type, A.line_id
from dbo.Receipt A 
	LEFT JOIN dbo.[Profile] B ON A.profile_id = B.profile_id
where A.receipt_status NOT IN ('V', 'R') AND A.trans_mode = 'I' AND --A.trans_type = 'D' AND 
	receipt_id = 39092 and company_id = 29 and profit_ctr_id = 0

select A.profile_id, A.customer_id, B.customer_id AS B_customer_id, A.generator_id, C.generator_id AS C_generator_id, A.orig_customer_id 
from dbo.Profile A
	left join dbo.ContactCORCustomerBucket B On A.customer_id = B.customer_Id
	left join dbo.ContactCORGeneratorBucket C On A.generator_id = C.generator_id
where A.profile_id = 506579

*/








	





