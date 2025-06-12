-- USE PLT_AI
-- Billing Bucket

--DROP PROCEDURE IF EXISTS dbo.ContactCORBilling_SP
GO

/*
-- DBCC DROPCLEANBUFFERS 
EXEC dbo.ContactCORBilling_SP -- 20-30s

select count(*) from dbo.ContactCORBillingBucket
*/

CREATE PROCEDURE dbo.ContactCORBilling_SP @TruncateBucketTable BIT = 0 AS

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- This is easier than adding WITH (NOLOCK) to every table.
SET NOCOUNT, XACT_ABORT ON
BEGIN TRY 

------------------------------------------------------------------------------------------------------------------------
IF @TruncateBucketTable = 1 OR NOT EXISTS (SELECT 1 FROM dbo.ContactCORBillingBucket) BEGIN
	TRUNCATE TABLE dbo.ContactCORBillingBucket 

	INSERT INTO dbo.ContactCORBillingBucket WITH (TABLOCK) ( contact_id, receipt_id, company_id, profit_ctr_id, trans_source, customer_id, generator_id, status_code ) -- Minimizes logging.
	SELECT DISTINCT 
		B.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, 
		A.trans_source, A.customer_id, A.generator_id, A.status_code 
	FROM dbo.Billing A
		INNER JOIN dbo.ContactCORCustomerBucket B ON A.customer_id = B.customer_id
	-- 10048524, 25-40s
END
ELSE BEGIN -- Bucket table has data.
	BEGIN TRAN

	DROP TABLE IF EXISTS #DMLAction

	;WITH ContactBilling AS (
		SELECT DISTINCT 
			B.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, 
			A.trans_source, A.customer_id, A.generator_id, A.status_code
		FROM dbo.Billing A -- Get all contact/billing combinations for valid COR customers.
			INNER JOIN dbo.ContactCORCustomerBucket B ON A.customer_id = B.customer_id 
	)
	-- For billing there will be no updates, as there are no columns that need updating.
	SELECT 
		B.ContactCorBillingBucket_uid, -- For Deletes or Updates, this column will have a value.  For Inserts, it will be NULL.
		(CASE 
			WHEN A.contact_id IS NOT NULL AND B.contact_id IS NULL THEN 'Insert'
			WHEN A.contact_id IS NULL AND B.contact_id IS NOT NULL THEN 'Delete'
			ELSE 'Update' -- Because NULL/NULL is not a valid case for any join, the only remaining case is NOT NULL/NOT NULL.
		END) AS [Action], 
		-- We only store the new/temp table values, as these will be used for Inserts (all values will be inserted) or Updates (a select few columns will be updated).
		A.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, A.trans_source, A.customer_id, A.generator_id, A.status_code
	INTO #DMLAction
	FROM ContactBilling A
		FULL OUTER JOIN dbo.ContactCORBillingBucket B ON 
			A.contact_id = B.contact_id AND A.receipt_id = B.receipt_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id AND
			A.trans_source = B.trans_source AND ISNULL(A.customer_id, -1) = ISNULL(B.customer_id, -1) AND ISNULL(A.generator_id, -1) = ISNULL(B.generator_id, -1) AND 
			A.status_code = B.status_code
	WHERE -- It's faster to use NOT logic.
		NOT ( A.contact_id IS NOT NULL AND B.contact_id IS NOT NULL );

	IF (SELECT COUNT(*) FROM #DMLAction) > 0 BEGIN
		INSERT INTO dbo.ContactCORBillingBucket ( contact_id, receipt_id, company_id, profit_ctr_id, trans_source, customer_id, generator_id, status_code )
		SELECT 
			A.contact_id, A.receipt_id, A.company_id, A.profit_ctr_id, A.trans_source, A.customer_id, A.generator_id, A.status_code
		FROM #DMLAction A
		WHERE [Action] = 'Insert'

		DELETE FROM A
		FROM dbo.ContactCORBillingBucket A
			INNER JOIN #DMLAction B ON A.ContactCorBillingBucket_uid = B.ContactCorBillingBucket_uid
		WHERE B.[Action] = 'Delete'
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

GRANT EXECUTE ON dbo.ContactCORBilling_SP TO BUCKET_SERVICE
GO

/*

select top 100 * from ContactCORBillingBucket order by contact_id, receipt_id desc, company_id, profit_ctr_id, customer_id

-- update dbo.Billing set customer_id = 0 where receipt_id = 2031517 and company_id = 21 and profit_ctr_id = 0
-- update dbo.Billing set customer_id = 503 where receipt_id = 2031517 and company_id = 21 and profit_ctr_id = 0

select * from #DMLAction
select * from ContactCORBillingBucket where ContactCorBillingBucket_uid IN (select ContactCorBillingBucket_uid from #DMLAction)

select * from Billing where receipt_id = 2031517 and company_id = 21 and profit_ctr_id = 0
select * from ContactCORBillingBucket where receipt_id = 2031517 and company_id = 21 and profit_ctr_id = 0

*/





	





