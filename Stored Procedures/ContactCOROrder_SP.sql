-- USE PLT_AI
-- Order Bucket

--DROP PROCEDURE IF EXISTS dbo.ContactCOROrder_SP
GO

/*
-- DBCC DROPCLEANBUFFERS 
EXEC dbo.ContactCOROrder_SP -- 3-6s

SELECT count(*) FROM dbo.ContactCOROrderBucket
*/

CREATE PROCEDURE dbo.ContactCOROrder_SP @TruncateBucketTable BIT = 0 AS

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- This is easier than adding WITH (NOLOCK) to every table.
SET NOCOUNT, XACT_ABORT ON
BEGIN TRY 

------------------------------------------------------------------------------------------------------------------------ 
DROP TABLE IF EXISTS #ContactOrders

;WITH TempBilling AS (
	SELECT receipt_id, company_id, profit_ctr_id, MIN(invoice_date) AS MIN_invoice_date
	FROM dbo.Billing
	WHERE trans_source = 'O' AND status_code = 'I'
	GROUP BY receipt_id, company_id, profit_ctr_id
),
ContactCustomer AS (
	SELECT DISTINCT -- 41371
		B.contact_id, OH.order_id, OD.company_id, OD.profit_ctr_id, OH.order_date, MIN_invoice_date AS invoice_date, 1 AS prices
	FROM 
		dbo.ContactCORCustomerBucket B
		INNER JOIN dbo.OrderHeader OH ON B.customer_id = OH.customer_id
		INNER JOIN dbo.OrderDetail OD ON OH.order_id = OD.order_id
		LEFT JOIN TempBilling X ON OH.order_id = X.receipt_id AND OD.company_id = X.company_id AND OD.profit_ctr_id = X.profit_ctr_id

	-- Old code
	--SELECT DISTINCT -- 41371
	--	B.contact_id, OH.order_id, OD.company_id, OD.profit_ctr_id, OH.order_date, MIN_invoice_date AS invoice_date, 1 AS prices
	--FROM 
	--	dbo.CORContact A -- In a future step join to ContactCORCustomerBucket instead of CORContact/CORContactXRef/Customer.
	--	INNER JOIN dbo.CORContactXRef B ON A.contact_id = B.contact_id 
	--	INNER JOIN dbo.Customer C ON B.customer_id = C.customer_id
	--	INNER JOIN dbo.OrderHeader OH ON B.customer_id = OH.customer_id
	--	INNER JOIN dbo.OrderDetail OD ON OH.order_id = OD.order_id
	--	LEFT JOIN TempBilling X ON OH.order_id = X.receipt_id AND OD.company_id = X.company_id AND OD.profit_ctr_id = X.profit_ctr_id
	--WHERE 
	--	A.contact_status = 'A' AND A.web_access_flag = 'T' 
	--		--AND ISNULL(A.web_userid, '') <> '' -- old code does not include web_userid. 
	--	AND B.[status] = 'A' AND B.web_access = 'A'	AND B.[type] = 'C' AND -- !!! Customer type
	--	C.cust_status = 'A' AND C.terms_code <> 'NOADMIT'
),
ContactGenerator AS (
	SELECT DISTINCT -- 177
		B.contact_id, OH.order_id, OD.company_id, OD.profit_ctr_id, OH.order_date, MIN_invoice_date AS invoice_date, 0 AS prices
	FROM 
		dbo.ContactCORGeneratorBucket B 
		INNER JOIN dbo.OrderHeader OH ON B.generator_id = OH.generator_id AND B.direct_flag = 'D' 
		INNER JOIN dbo.OrderDetail OD ON OH.order_id = OD.order_id
		LEFT JOIN TempBilling X ON OH.order_id = X.receipt_id AND OD.company_id = X.company_id AND OD.profit_ctr_id = X.profit_ctr_id

	-- Old code
	--SELECT DISTINCT -- 177
	--	B.contact_id, OH.order_id, OD.company_id, OD.profit_ctr_id, 
	--	OH.order_date, MIN_invoice_date AS invoice_date, 0 AS prices
	--FROM 
	--	dbo.CORContact A -- In a future step join to ContactCORCustomerBucket instead of CORContact/CORContactXRef/Customer.
	--	INNER JOIN dbo.CORContactXRef B ON A.contact_id = B.contact_id 
	--	INNER JOIN dbo.OrderHeader OH ON B.generator_id = OH.generator_id
	--	INNER JOIN dbo.OrderDetail OD ON OH.order_id = OD.order_id
	--	LEFT JOIN TempBilling X ON OH.order_id = X.receipt_id AND OD.company_id = X.company_id AND OD.profit_ctr_id = X.profit_ctr_id
	--WHERE 
	--	A.contact_status = 'A' AND A.web_access_flag = 'T' 
	--		--AND ISNULL(A.web_userid, '') <> '' -- old code does not include web_userid.  
	--	AND B.[status] = 'A' AND B.web_access = 'A'	AND B.[type] = 'G' -- !!! Generator type
)
SELECT 
	COALESCE(A.contact_id, B.contact_id) AS contact_id, 
	COALESCE(A.order_id, B.order_id) AS order_id, 
	COALESCE(A.company_id, B.company_id) AS company_id, 
	COALESCE(A.profit_ctr_id, B.profit_ctr_id) AS profit_ctr_id, 
	COALESCE(A.order_date, B.order_date) AS order_date, 
	COALESCE(A.invoice_date, B.invoice_date) AS invoice_date,
	COALESCE(A.prices, B.prices) AS prices
INTO #ContactOrders -- !!! This is the output of the CTE.
FROM ContactCustomer A
	FULL OUTER JOIN ContactGenerator B ON A.contact_id = B.contact_id AND A.order_id = B.order_id AND A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id
-- 37091, 1-3s

-------------------------------------------------
-- Modify the dates for the demo customer: 888880
-------------------------------------------------
UPDATE A
SET	order_date   = DATEADD(M, -1, GETDATE()),    -- Set order_date to 1 month earlier than today.
	invoice_date = DATEADD(M, -1, GETDATE()) + 3 -- Set invoice_date to 1 month earlier than today + 3 days.
FROM #ContactOrders A
	INNER JOIN dbo.OrderHeader B ON A.order_id = B.order_id 
WHERE B.customer_id = 888880

------------------------------------------------------------------------------------------------------------------------
IF @TruncateBucketTable = 1 OR NOT EXISTS (SELECT 1 FROM dbo.ContactCOROrderBucket) BEGIN
	TRUNCATE TABLE dbo.ContactCOROrderBucket

	INSERT INTO dbo.ContactCOROrderBucket WITH (TABLOCK) ( contact_id, order_id, company_id, profit_ctr_id, order_date, invoice_date, prices ) -- Minimizes logging.
	SELECT contact_id, order_id, company_id, profit_ctr_id, order_date, invoice_date, prices 
	FROM #ContactOrders
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
		B.ContactCorOrderBucket_uid, -- For Deletes or Updates, this column will have a value.  For Inserts, it will be NULL.
		(CASE 
			WHEN A.order_id IS NOT NULL AND B.order_id IS NULL THEN 'Insert'
			WHEN A.order_id IS NULL AND B.order_id IS NOT NULL THEN 'Delete'
			ELSE 'Update' -- Because NULL/NULL is not a valid case for any join, the only remaining case is NOT NULL/NOT NULL.
		END) AS [Action], 
		-- We only store the new/temp table values, as these will be used for Inserts (all values will be inserted) or Updates (a select few columns will be updated).
		A.contact_id, A.order_id, A.company_id, A.profit_ctr_id, A.order_date, A.invoice_date, A.prices
	INTO #DMLAction
	FROM #ContactOrders A
		FULL OUTER JOIN dbo.ContactCOROrderBucket B ON A.contact_id = B.contact_id AND A.order_id = B.order_id 
	WHERE -- It's faster to use NOT logic.
		NOT ( A.order_id IS NOT NULL AND B.order_id IS NOT NULL AND  
			  A.company_id = B.company_id AND A.profit_ctr_id = B.profit_ctr_id AND -- While order_id is unique.  Check company and profit just in case.
			  ISNULL(A.order_date, '01/01/1776') = ISNULL(B.order_date, '01/01/1776') AND ISNULL(A.invoice_date, '01/01/1776') = ISNULL(B.invoice_date, '01/01/1776') AND 
			  ISNULL(A.prices, 0) = ISNULL(B.prices, 0) )

	IF (SELECT COUNT(*) FROM #DMLAction) > 0 BEGIN
		INSERT INTO dbo.ContactCOROrderBucket ( contact_id, order_id, company_id, profit_ctr_id, order_date, invoice_date, prices )
		SELECT A.contact_id, A.order_id, A.company_id, A.profit_ctr_id, A.order_date, A.invoice_date, A.prices
		FROM #DMLAction A
		WHERE [Action] = 'Insert'

		DELETE FROM A
		FROM dbo.ContactCOROrderBucket A
			INNER JOIN #DMLAction B ON A.ContactCorOrderBucket_uid = B.ContactCorOrderBucket_uid
		WHERE B.[Action] = 'Delete'

		UPDATE A -- It's easier just to update all columns rather than checking which one has changed.
		SET A.company_id = B.company_id, A.profit_ctr_id = B.profit_ctr_id, A.order_date = B.order_date, A.invoice_date  = B.invoice_date, A.prices = B.prices
		FROM dbo.ContactCOROrderBucket A
			INNER JOIN #DMLAction B ON A.ContactCorOrderBucket_uid = B.ContactCorOrderBucket_uid
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

GRANT EXECUTE ON dbo.ContactCOROrder_SP TO BUCKET_SERVICE
GO

/*

select top 10 * from ContactCOROrderBucket order by contact_id, order_id

select * from dbo.OrderHeader where order_id = 1555
update dbo.OrderHeader set customer_id = 0 where order_id = 1555 -- delete
-- update dbo.OrderHeader set customer_id = 583 where order_id = 1555 -- restore (insert)

select * from dbo.OrderHeader where order_id = 2288
update dbo.OrderHeader set order_date = '09/29/1972' where order_id = 2288 -- update
-- update dbo.OrderHeader set order_date = '2009-09-18' where order_id = 2288 -- restore (update)

-------------------------------------------------------------
select * from #ContactOrders where order_id in ( 1555, 2288 ) order by order_id, contact_id
select * from ContactCOROrderBucket where order_id in ( 1555, 2288 ) order by order_id, contact_id

select * from #DMLAction order by order_id, contact_id
select * from ContactCOROrderBucket where ContactCorOrderBucket_uid in ( select ContactCorOrderBucket_uid from #DMLAction where action = 'delete')
  order by order_id, contact_id

-------------------------------------------------------------

select * from dbo.OrderHeader where order_id in ( 1555, 2288 )
select * from ContactCOROrderBucket where order_id in ( 1555, 2288 ) order by order_id, contact_id

*/





	





