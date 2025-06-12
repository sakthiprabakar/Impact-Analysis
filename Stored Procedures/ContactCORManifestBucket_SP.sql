-- USE PLT_AI
-- Manifest Bucket

-- DROP PROCEDURE IF EXISTS dbo.ContactCORManifest_SP
GO

/*

EXEC dbo.ContactCORManifest_SP -- 44s

*/

CREATE PROCEDURE dbo.ContactCORManifest_SP @TruncateBucketTable BIT = 0 AS

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- This is easier than adding WITH (NOLOCK) to every table.
SET NOCOUNT, XACT_ABORT ON
BEGIN TRY 

----------------------------------------------------------------
-- Step 1: Gather the distinct list of keys, helpfuls and manifest #s for receipts and work orders
----------------------------------------------------------------
DROP TABLE IF EXISTS #AllManifest

	select 
		b.contact_id
		, 'Receipt' as source
		, b.receipt_id
		, b.company_id
		, b.profit_ctr_id
		, b.pickup_date as service_date
		, b.receipt_date
		, b.customer_id
		, b.generator_id
		, rm.manifest
	into #AllManifest
	from ContactCORReceiptBucket b
	JOIN Receipt rm
		on b.receipt_id = rm.receipt_id
		and b.company_id = rm.company_id
		and b.profit_ctr_id = rm.profit_ctr_id
		and rm.manifest not like '%manifest%'
		and rm.trans_mode = 'I'
		and rm.trans_type = 'D'
		-- and rm.manifest_flag like '%M%'
		and isnull(rm.manifest, '') <> ''
	WHERE coalesce(b.pickup_date, b.receipt_date) >= dateadd(yyyy, -5, getdate())
	-- Just receipts
	-- 624880 rows; 15s

	union
	
	select 
		b.contact_id
		, 'Work Order' as source
		, b.workorder_id
		, b.company_id
		, b.profit_ctr_id
		, b.service_date
		, b.start_date
		, b.customer_id
		, b.generator_id
		, wd.manifest
	from ContactCORWorkorderHeaderBucket b
	JOIN WorkorderDetail wd
		on b.workorder_id = wd.workorder_id
		and b.company_id = wd.company_id
		and b.profit_ctr_id = wd.profit_ctr_id
		and wd.resource_type = 'D'
	--	and wd.manifest_flag like '%M%'
		and wd.bill_rate > -2
		and wd.manifest not like '%manifest%'
 		and isnull(wd.manifest, '') <> ''
	-- have to join to both WorkorderDetail and this because WorkorderDetail doesn't have a manifest_flag, 
	-- and WorkorderMANIFEST doesn't have (wait for it...) the MANIFEST number.  Sometimes we're stupid.
	--join workordermanifest wm 
	--	on b.workorder_id = wm.workorder_id
	--	and b.company_id = wm.company_id
	--	and b.profit_ctr_id = wm.profit_ctr_id
	--	and wd.manifest = wm.manifest
	--	-- and wm.manifest_flag = 'T'
	--	-- and wm.manifest_state like '%H%'
	WHERE coalesce(b.service_date, b.start_date) >= dateadd(yyyy, -5, getdate())
	-- Just work orders
	-- 333814 rows, 1:13.  Ow.

-- All
-- 4731542, 1:16


---------------------------------------------------------------------------------------------------------------------------
-- Insert, Update, or Delete data for permanent Contact/Manifest Bucket table.
-- If Bucket table has no data (which would only happen on the very first run), insert all temp data into the Bucket table.
-- If Bucket table has data (which happens every time, except the first time), look for records to insert or delete.
-- Inserting or deleting rows in the permanent Bucket table will reduce logging immensely over other methods.
---------------------------------------------------------------------------------------------------------------------------
IF @TruncateBucketTable = 1 OR NOT EXISTS (SELECT 1 FROM dbo.ContactCORManifestBucket) BEGIN
	TRUNCATE TABLE dbo.ContactCORManifestBucket

	INSERT INTO dbo.ContactCORManifestBucket WITH (TABLOCK) ( contact_id, source, receipt_id, company_id, profit_ctr_id, receipt_date, service_date, customer_id, generator_id, manifest ) -- Minimizes logging.
	SELECT contact_id, source, receipt_id, company_id, profit_ctr_id, receipt_date, service_date, customer_id, generator_id, manifest
	FROM #AllManifest
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
		B.ContactCORManifestBucket_UID, -- For Deletes or Updates, this column will have a value.  For Inserts, it will be NULL.
		(CASE 
			WHEN A.receipt_id IS NOT NULL AND B.receipt_id IS NULL THEN 'Insert'
			WHEN A.receipt_id IS NULL AND B.receipt_id IS NOT NULL THEN 'Delete'
			ELSE 'Update' -- Because NULL/NULL is not a valid case for any join, the only remaining case is NOT NULL/NOT NULL.
		END) AS [Action], 
		-- We only store the new/temp table values, as these will be used for Inserts (all values will be inserted) or Updates (a select few columns will be updated).
		A.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, A.source, A.receipt_date, A.service_date, A.customer_id, A.generator_id, A.manifest
	INTO #DMLAction
	FROM #AllManifest A
		FULL OUTER JOIN dbo.ContactCORManifestBucket B ON 
			A.contact_id = B.contact_id AND A.receipt_id = B.receipt_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id AND a.source = b.source AND a.manifest = B.manifest
	-------------------------------------------------------------------------------------------------------------
	-- It's 3 seconds faster to use NOT logic.
	-- In normal logic we want the following:
	-- 1) A.receipt_id IS NULL OR
	-- 2) B.receipt_id IS NULL OR
	-- 3) A.receipt_id IS NOT NULL AND B.receipt_id IS NOT NULL AND 
	--   (A.receipt_date <> B.receipt_date OR A.service_date <> B.service_date OR A.invoice_date <> B.invoice_date)
	-------------------------------------------------------------------------------------------------------------
	WHERE NOT ( A.receipt_id IS NOT NULL AND B.receipt_id IS NOT NULL AND 
				ISNULL(A.receipt_date, '01/01/1776') = ISNULL(B.receipt_date, '01/01/1776') AND 
				ISNULL(A.service_date, '01/01/1776') = ISNULL(B.service_date, '01/01/1776') AND 
				A.customer_id = B.customer_id AND 
				A.generator_id = B.generator_id AND
				A.manifest = B.manifest )
	-- 2s
	
	-- SELECT  * FROM    #DMLAction

	IF (SELECT COUNT(*) FROM #DMLAction) > 0 BEGIN
		INSERT INTO dbo.ContactCORManifestBucket ( contact_id, receipt_id, company_id, profit_ctr_id, source, receipt_date, service_date, customer_id, generator_id, manifest)
		SELECT A.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, A.source, A.receipt_date, A.service_date, A.customer_id, A.generator_id, A.manifest
		FROM #DMLAction A
		WHERE [Action] = 'Insert'

		DELETE FROM A
		-- select a.*
		FROM dbo.ContactCORManifestBucket A
			INNER JOIN #DMLAction B ON A.ContactCORManifestBucket_UID = B.ContactCORManifestBucket_UID
		WHERE B.[Action] = 'Delete'

		UPDATE A -- It's easier/faster to just update all the columns rather than checking which one has changed.
		SET A.receipt_date = B.receipt_date, 
			A.service_date  = B.service_date,
			A.customer_id  = B.customer_id,
			A.generator_id = B.generator_id
		-- select a.*, b.*
		FROM dbo.ContactCORManifestBucket A
			INNER JOIN #DMLAction B ON A.ContactCORManifestBucket_UID = B.ContactCORManifestBucket_UID
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

GRANT EXECUTE ON dbo.ContactCORManifest_SP TO BUCKET_SERVICE
GO

/*
select top 10 * from ContactCORManifestBucket

select * from dbo.receipt where receipt_id = 79205 and company_id = 25 and profit_ctr_id = 0
select * from dbo.ContactCORManifestBucket where receipt_id = 79205 and company_id = 25 and profit_ctr_id = 0 -- 9 rows
-- update dbo.receipt set receipt_status = 'V' where receipt_id = 79205 and company_id = 25 and profit_ctr_id = 0
-- update dbo.receipt set receipt_status = 'A' where receipt_id = 79205 and company_id = 25 and profit_ctr_id = 0

select * from dbo.receipt where receipt_id = 536385 and company_id = 2 and profit_ctr_id = 0
select * from dbo.ContactCORManifestBucket where receipt_id = 536385 and company_id = 2 and profit_ctr_id = 0 -- 8 rows
-- update dbo.receipt set receipt_status = 'V' where receipt_id = 536385 and company_id = 2 and profit_ctr_id = 0
-- update dbo.receipt set receipt_status = 'A' where receipt_id = 536385 and company_id = 2 and profit_ctr_id = 0

select * from dbo.receipt where receipt_id = 43169 and company_id = 27 and profit_ctr_id = 0
select * from dbo.ContactCORManifestBucket where receipt_id = 43169 and company_id = 27 and profit_ctr_id = 0 -- 30 rows
-- update dbo.receipt set receipt_date = '09/29/1972' where receipt_id = 43169 and company_id = 27 and profit_ctr_id = 0
-- update dbo.receipt set receipt_date = '01/20/2011' where receipt_id = 43169 and company_id = 27 and profit_ctr_id = 0
*/

