-- USE PLT_AI
-- Invoice Bucket

--DROP PROCEDURE IF EXISTS dbo.ContactCORInvoice_SP
GO

/*

EXEC dbo.ContactCORInvoice_SP -- 10-12s

select count(*) from dbo.ContactCORInvoiceBucket
*/

CREATE PROCEDURE dbo.ContactCORInvoice_SP @TruncateBucketTable BIT = 0 AS

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- This is easier than adding WITH (NOLOCK) to every table.
SET NOCOUNT, XACT_ABORT ON
BEGIN TRY 

------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #ContactInvoices

SELECT DISTINCT 
	A.contact_id, B.invoice_id, B.revision_id, B.invoice_date
INTO #ContactInvoices
FROM dbo.ContactCORCustomerBucket A
	INNER JOIN dbo.InvoiceHeader B ON A.customer_id = B.customer_id
WHERE B.[status] = 'I' 
-- 3629485, 6s

---------------------------------------------------------------------
-- Modify the dates for the demo customer: 888880.  Used for testing.
---------------------------------------------------------------------
UPDATE A
SET	invoice_date = DATEADD(M, -1, GETDATE()) + 3 -- Set invoice_date to 1 month earlier than today + 3 days.
FROM #ContactInvoices A
	INNER JOIN dbo.InvoiceHeader B ON A.invoice_id = B.invoice_id AND A.revision_id = B.revision_id 
WHERE B.customer_id = 888880

------------------------------------------------------------------------------------------------------------------------
IF @TruncateBucketTable = 1 OR NOT EXISTS (SELECT 1 FROM dbo.ContactCORInvoiceBucket) BEGIN
	TRUNCATE TABLE dbo.ContactCORInvoiceBucket 

	INSERT INTO dbo.ContactCORInvoiceBucket WITH (TABLOCK) ( contact_id, invoice_id, revision_id, invoice_date ) -- Minimizes logging.
	SELECT contact_id, invoice_id, revision_id, invoice_date FROM #ContactInvoices
END
ELSE BEGIN -- Bucket table has data.
	BEGIN TRAN

	DROP TABLE IF EXISTS #DMLAction

	SELECT 
		B.ContactCorInvoiceBucket_uid, -- For Deletes or Updates, this column will have a value.  For Inserts, it will be NULL.
		(CASE 
			WHEN A.contact_id IS NOT NULL AND B.contact_id IS NULL THEN 'Insert'
			WHEN A.contact_id IS NULL AND B.contact_id IS NOT NULL THEN 'Delete'
			ELSE 'Update' -- Because NULL/NULL is not a valid case for any join, the only remaining case is NOT NULL/NOT NULL.
		END) AS [Action], 
		-- We only store the new/temp table values, as these will be used for Inserts (all values will be inserted) or Updates (a select few columns will be updated).
		A.contact_id, A.invoice_id, A.revision_id, A.invoice_date
	INTO #DMLAction
	FROM #ContactInvoices A
		FULL OUTER JOIN dbo.ContactCORInvoiceBucket B ON A.contact_id = B.contact_id AND A.invoice_id = B.invoice_id AND A.revision_id = B.revision_id 
	WHERE -- It's faster to use NOT logic.
		NOT ( A.contact_id IS NOT NULL AND B.contact_id IS NOT NULL AND ISNULL(A.invoice_date, '01/01/1776') = ISNULL(B.invoice_date, '01/01/1776') )

	IF (SELECT COUNT(*) FROM #DMLAction) > 0 BEGIN
		INSERT INTO dbo.ContactCORInvoiceBucket 
		SELECT A.contact_id, A.invoice_id, A.revision_id, A.invoice_date
		FROM #DMLAction A
		WHERE [Action] = 'Insert'

		DELETE FROM A
		FROM dbo.ContactCORInvoiceBucket A
			INNER JOIN #DMLAction B ON A.ContactCorInvoiceBucket_uid = B.ContactCorInvoiceBucket_uid
		WHERE B.[Action] = 'Delete'

		UPDATE A 
		SET A.invoice_date = B.invoice_date
		FROM dbo.ContactCORInvoiceBucket A
			INNER JOIN #DMLAction B ON A.ContactCorInvoiceBucket_uid = B.ContactCorInvoiceBucket_uid
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

GRANT EXECUTE ON dbo.ContactCORInvoice_SP TO BUCKET_SERVICE
GO


/*
select top 10 * from ContactCORInvoiceBucket order by contact_id, invoice_id, revision_id

delete from ContactCORInvoiceBucket where contact_id = 169 and invoice_id = 1533 and revision_id = 1 -- insert case
update ContactCORInvoiceBucket set invoice_date = '09/29/1972' where contact_id = 169 and invoice_id = 1867 and revision_id = 1 -- update case
update dbo.InvoiceHeader set status = 'V' where invoice_id = 2342 and revision_id = 1 -- delete case
-- update dbo.InvoiceHeader set status = 'I' where invoice_id = 2342 and revision_id = 1 -- restore

select * from #DMLAction

select * from InvoiceHeader 
where (invoice_id = 1533 and revision_id = 1) OR
		(invoice_id = 1867 and revision_id = 1) OR
		(invoice_id = 2342 and revision_id = 1)

select * from ContactCORInvoiceBucket 
where (contact_id = 169 and invoice_id = 1533 and revision_id = 1) OR
		(contact_id = 169 and invoice_id = 1867 and revision_id = 1) OR
		(contact_id = 169 and invoice_id = 2342 and revision_id = 1)
*/




