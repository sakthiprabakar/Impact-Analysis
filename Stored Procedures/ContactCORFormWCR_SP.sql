-- USE PLT_AI
-- FormWCR Bucket

--DROP PROCEDURE IF EXISTS dbo.ContactCORFormWCR_SP
GO

/*
-- DBCC DROPCLEANBUFFERS 
EXEC dbo.ContactCORFormWCR_SP -- 5-6s

select count(*) from dbo.ContactCORFormWCRBucket
*/

CREATE PROCEDURE dbo.ContactCORFormWCR_SP @TruncateBucketTable BIT = 0 AS

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- This is easier than adding WITH (NOLOCK) to every table.
SET NOCOUNT, XACT_ABORT ON
BEGIN TRY 

DECLARE @goLiveDate datetime = '6/19/2020'

------------------------------------------------------------------------------------------------------------------------
IF @TruncateBucketTable = 1 OR NOT EXISTS (SELECT 1 FROM dbo.ContactCORFormWCRBucket) BEGIN
	TRUNCATE TABLE dbo.ContactCORFormWCRBucket 

	------------------------------------------------------------
	INSERT INTO dbo.ContactCORFormWCRBucket WITH (TABLOCK) ( contact_id, form_id, revision_id, customer_id, generator_id ) -- Minimizes logging. No need for a CTE when inserting the first time.
	SELECT A.contact_id, B.form_id, B.revision_id, B.customer_id, B.generator_id -- Distinct count: 1088586
	FROM dbo.ContactCORCustomerBucket A
		INNER JOIN dbo.FormWCR B ON A.customer_id = B.customer_id
	WHERE B.date_created >= @goLiveDate
	-----
	UNION
	-----
	SELECT A.contact_id, B.form_id, B.revision_id, B.customer_id, B.generator_id -- Distinct count: 39060
	FROM dbo.ContactCORGeneratorBucket A
		INNER JOIN dbo.FormWCR B ON A.generator_id = B.generator_id AND A.direct_flag = 'D'
	WHERE B.date_created >= @goLiveDate
	-----
	UNION
	-----
	SELECT A.contact_id, B.form_id, B.revision_id, B.customer_id, B.generator_id -- Distinct count:20
	FROM dbo.CORContact A
		INNER JOIN dbo.FormWCR B on A.email = B.created_by
	WHERE B.date_created >= @goLiveDate
	------------------------------------------------------------
	-- 1106933, 2s
END
ELSE BEGIN -- Bucket table has data.
	BEGIN TRAN

	DROP TABLE IF EXISTS #ContactsAndFormWCR

	----------------------
	;WITH CTEFormWCR AS (
		SELECT form_id, revision_id, customer_id, generator_id, created_by
		FROM dbo.FormWCR
		WHERE date_created >= @goLiveDate
	)
	SELECT A.contact_id, B.form_id, B.revision_id, B.customer_id, B.generator_id -- Distinct count: 1088586
	INTO #ContactsAndFormWCR -- !!! This is the output of the CTE.
	FROM dbo.ContactCORCustomerBucket A
		INNER JOIN CTEFormWCR B ON A.customer_id = B.customer_id
	-----
	UNION
	-----
	SELECT A.contact_id, B.form_id, B.revision_id, B.customer_id, B.generator_id -- Distinct count: 39060
	FROM dbo.ContactCORGeneratorBucket A
		INNER JOIN CTEFormWCR B ON A.generator_id = B.generator_id AND A.direct_flag = 'D'
	-----
	UNION
	-----
	SELECT A.contact_id, B.form_id, B.revision_id, B.customer_id, B.generator_id -- Distinct count:20
	FROM dbo.CORcontact A
		INNER JOIN CTEFormWCR B on A.email = B.created_by
	-- 1106933, 1s
	----------------------

	INSERT INTO dbo.ContactCORFormWCRBucket WITH (TABLOCK) ( contact_id, form_id, revision_id, customer_id, generator_id ) -- Minimizes logging.
	SELECT A.contact_id, A.form_id, A.revision_id, A.customer_id, A.generator_id
	FROM #ContactsAndFormWCR A
	WHERE NOT EXISTS -- NOT EXISTS is the same or faster than LEFT JOIN.
		(
		SELECT * FROM dbo.ContactCORFormWCRBucket B 
		WHERE A.contact_id = B.contact_id AND A.form_id = B.form_id AND A.revision_id = B.revision_id AND 
			ISNULL(A.customer_id, -1) = ISNULL(B.customer_id, -1) AND ISNULL(A.generator_id, -1) = ISNULL(B.generator_id, -1)
		)
	-- 1s
	
	DELETE FROM A
	FROM dbo.ContactCORFormWCRBucket A
	WHERE NOT EXISTS -- NOT EXISTS is the same or faster than LEFT JOIN.
		(
		SELECT * FROM #ContactsAndFormWCR B 
		WHERE A.contact_id = B.contact_id AND A.form_id = B.form_id AND A.revision_id = B.revision_id AND 
			ISNULL(A.customer_id, -1) = ISNULL(B.customer_id, -1) AND ISNULL(A.generator_id, -1) = ISNULL(B.generator_id, -1)
		)
	-- 1s
	-- All: 6s

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

GRANT EXECUTE ON dbo.ContactCORFormWCR_SP TO BUCKET_SERVICE
GO

/*

select top 10 * from ContactCORFormWCRBucket
select count(*) from ContactCORFormWCRBucket -- 10045945

select receipt_id, company_id, profit_ctr_id, customer_id
from dbo.FormWCR
where receipt_id = 394 and company_id = 14 and profit_ctr_id = 6

-- update dbo.FormWCR set customer_id = 0 where receipt_id = 394 and company_id = 14 and profit_ctr_id = 6
-- update dbo.FormWCR set customer_id = 503 where receipt_id = 394 and company_id = 14 and profit_ctr_id = 6

*/





	





