-- USE PLT_AI
-- Profile Bucket

--DROP PROCEDURE IF EXISTS dbo.ContactCORProfile_SP
GO

/*
-- DBCC DROPCLEANBUFFERS 
EXEC dbo.ContactCORProfile_SP -- 8-10s

SELECT count(*) FROM dbo.ContactCORProfileBucket
*/

CREATE PROCEDURE dbo.ContactCORProfile_SP @TruncateBucketTable BIT = 0 AS

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- This is easier than adding WITH (NOLOCK) to every table.
SET NOCOUNT, XACT_ABORT ON
BEGIN TRY 

------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #ContactProfiles

----------------------------------------------------------------
-- The profile table is used multiple times, so store in memory.
----------------------------------------------------------------
;WITH AllProfiles AS (
	SELECT A.profile_id, A.customer_id, A.generator_id, A.orig_customer_id, A.ap_expiration_date, A.curr_status_code
	FROM dbo.[Profile] A
	WHERE curr_status_code not in ('V')
),
T_DirectCustomer AS ( 
	------------------------------------------------------------------------------------------------------------------------------
	-- Direct Customer: The direct customer is the profile's customer_id.
	--					Join to the contact/customer bucket table to verify that the customer is active and has good credit terms.
	--					The name of the CTE temp table starts with the prices letter.  T in this case.
	--					Each of these CTE temp tables is independent of the others.  
	--					We slowly build a collection of resultsets that is FULL OUTER JOINed in the last step.
	------------------------------------------------------------------------------------------------------------------------------
	SELECT B.contact_id, A.profile_id, A.customer_id, A.generator_id, A.ap_expiration_date, A.curr_status_code, 'T' AS prices
	FROM AllProfiles A 
		INNER JOIN dbo.ContactCORCustomerBucket B ON A.customer_id = B.customer_id
), 
O_OriginalCustomer AS ( 
	---------------------------------------------------------------------------------------------------------------
	-- Original Customer: The original customer is the profile's orig_customer_id.
	--					  The original customer and direct customer must both be active and have good credit terms.
	---------------------------------------------------------------------------------------------------------------
	SELECT B.contact_id, A.profile_id, A.customer_id, A.generator_id, A.ap_expiration_date, A.curr_status_code, 'O' AS prices
	FROM AllProfiles A 
		INNER JOIN dbo.ContactCORCustomerBucket B ON A.orig_customer_id = B.customer_id
		INNER JOIN (SELECT DISTINCT customer_id FROM dbo.ContactCORCustomerBucket) C ON A.customer_id = C.customer_id

	--SELECT B.contact_id, A.profile_id, A.customer_id, A.generator_id, A.ap_expiration_date, A.curr_status_code, 'O' AS prices
	--FROM AllProfiles A
	--	INNER JOIN dbo.CORContactXRef B ON A.orig_customer_id = B.customer_id AND B.[status] = 'A' and B.web_access = 'A' and B.[type] = 'C'
	--	INNER JOIN dbo.CORContact C ON B.contact_id = c.contact_id AND 
	--		C.contact_status = 'A' AND C.web_access_flag = 'T' 
	--		-- AND ISNULL(C.web_userid, '') <> '' -- old code does not include web_userid. 
	--	INNER JOIN dbo.Customer C1 ON A.customer_id = C1.customer_id AND C1.cust_status = 'A' AND C1.terms_code <> 'NOADMIT'
	--	INNER JOIN dbo.Customer C2 ON A.orig_customer_id = C2.customer_id AND C2.cust_status = 'A' AND C2.terms_code <> 'NOADMIT'
), 
F_Generators AS ( 
	------------------------------------------------------------------------------------------------
	-- Direct Generator: A generator need not have an active/good-terms direct or original customer.
	------------------------------------------------------------------------------------------------
	SELECT B.contact_id, A.profile_id, A.customer_id, A.generator_id, A.ap_expiration_date, A.curr_status_code, 'F' AS prices
	FROM AllProfiles A
		INNER JOIN dbo.ContactCORGeneratorBucket B ON A.generator_id = B.generator_id AND B.direct_flag = 'D'
	-----
	UNION 
	--------------------------------------------------------------------------------------------
	-- Various Generator 1: Find contact/profile combos via a customer's CustomerGenerator list.
	--------------------------------------------------------------------------------------------
	SELECT C.contact_id, A.profile_id, A.customer_id, A.generator_id, A.ap_expiration_date, A.curr_status_code, 'F' AS prices
	FROM AllProfiles A
		INNER JOIN dbo.CustomerGenerator B ON A.customer_id = B.customer_id
		INNER JOIN dbo.ContactCORGeneratorBucket C ON B.generator_id = C.generator_id AND C.direct_flag = 'D'
	WHERE A.generator_id = 0 
	-----
	UNION 
	-------------------------------------------------------------------------------
	-- Various Generator 2: Find contact/profile combos via a customer's site_type.
	-------------------------------------------------------------------------------
	SELECT D.contact_id, A.profile_id, A.customer_id, A.generator_id, A.ap_expiration_date, A.curr_status_code, 'F' AS prices
	FROM AllProfiles A 
		INNER JOIN dbo.ProfileGeneratorSiteType B ON A.profile_id = B.profile_id
		INNER JOIN dbo.Generator C ON B.site_type = C.site_type
		INNER JOIN dbo.ContactCORGeneratorBucket D ON C.generator_id = D.generator_id AND D.direct_flag = 'D'
	WHERE A.generator_id = 0 
)
------------------------------------------------------------------------------------------------------------
-- Use FULL OUTER JOIN and COALESCE in a tricky manner to replicate a UNION join between 3 result sets.
-- This is faster than having each step above check to see if a contact/profile exists from a previous step.
------------------------------------------------------------------------------------------------------------
-- The tables are joined in a very important and specific order: 
--		1) DirectCustomer (prices = T)
--		2) OriginalCustomer (prices = O)
--		3) Generators (prices = F)
-- Because of this order, the COALESCE function will always pick T before O, and T before F, and O before F.
-- This (T then O then F) precedence is the correct business requirement order.
------------------------------------------------------------------------------------------------------------
SELECT 
	COALESCE(A.contact_id, B.contact_id, C.contact_id) AS contact_id, 
	COALESCE(A.profile_id, B.profile_id, C.profile_id) AS profile_id, 
	COALESCE(A.customer_id, B.customer_id, C.customer_id) AS customer_id, 
	COALESCE(A.generator_id, B.generator_id, C.generator_id) AS generator_id, 
	COALESCE(A.ap_expiration_date, B.ap_expiration_date, C.ap_expiration_date) AS ap_expiration_date, 
	COALESCE(A.curr_status_code, B.curr_status_code, C.curr_status_code) AS curr_status_code,
	COALESCE(A.prices, B.prices, C.prices) AS prices
INTO #ContactProfiles -- !!! This is the output of the CTE.
FROM T_DirectCustomer A
	FULL OUTER JOIN O_OriginalCustomer B ON A.contact_id = B.contact_id AND A.profile_id = B.profile_id
	-- !!! Must join on ISNULL(A, B) = C to catch a B = C match, otherwise a A = B and A = C join won't catch a B = C join.
	FULL OUTER JOIN F_Generators C ON ISNULL(A.contact_id, B.contact_id) = C.contact_id AND ISNULL(A.profile_id, B.profile_id) = C.profile_id
-- 2056758, 8-10s

------------------------------------------------------------------------------------------------------------------------
IF @TruncateBucketTable = 1 OR NOT EXISTS (SELECT 1 FROM dbo.ContactCORProfileBucket) BEGIN
	TRUNCATE TABLE dbo.ContactCORProfileBucket 

	INSERT INTO dbo.ContactCORProfileBucket WITH (TABLOCK) ( contact_id, profile_id, customer_id, generator_id, ap_expiration_date, curr_status_code, prices ) -- Minimizes logging.
	SELECT contact_id, profile_id, customer_id, generator_id, ap_expiration_date, curr_status_code, prices 
	FROM #ContactProfiles
	-- 2056656, 2s
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
		B.ContactCorProfileBucket_uid, -- For Deletes or Updates, this column will have a value.  For Inserts, it will be NULL.
		(CASE 
			WHEN A.profile_id IS NOT NULL AND B.profile_id IS NULL THEN 'Insert'
			WHEN A.profile_id IS NULL AND B.profile_id IS NOT NULL THEN 'Delete'
			ELSE 'Update' -- Because NULL/NULL is not a valid case for any join, the only remaining case is NOT NULL/NOT NULL.
		END) AS [Action], 
		-- We only store the new/temp table values, as these will be used for Inserts (all values will be inserted) or Updates (a select few columns will be updated).
		A.contact_id, A.profile_id, A.customer_id, A.generator_id, A.ap_expiration_date, A.curr_status_code, A.prices
	INTO #DMLAction
	FROM #ContactProfiles A
		FULL OUTER JOIN dbo.ContactCORProfileBucket B ON A.contact_id = B.contact_id AND A.profile_id = B.profile_id 
	WHERE -- It's faster to use NOT logic.
		NOT ( A.profile_id IS NOT NULL AND B.profile_id IS NOT NULL AND 
				ISNULL(A.customer_id, -1) = ISNULL(B.customer_id, -1) AND ISNULL(A.generator_id, -1) = ISNULL(B.generator_id, -1) AND 
				ISNULL(A.ap_expiration_date, '01/01/1776') = ISNULL(B.ap_expiration_date, '01/01/1776') AND 
				ISNULL(A.curr_status_code, '') = ISNULL(B.curr_status_code, '') AND ISNULL(A.prices, 0) = ISNULL(B.prices, 0) )

	IF (SELECT COUNT(*) FROM #DMLAction) > 0 BEGIN
		INSERT INTO dbo.ContactCORProfileBucket ( contact_id, profile_id, customer_id, generator_id, ap_expiration_date, curr_status_code, prices )
		SELECT A.contact_id, A.profile_id, A.customer_id, A.generator_id, A.ap_expiration_date, A.curr_status_code, A.prices
		FROM #DMLAction A
		WHERE [Action] = 'Insert'

		DELETE FROM A
		FROM dbo.ContactCORProfileBucket A
			INNER JOIN #DMLAction B ON A.ContactCorProfileBucket_uid = B.ContactCorProfileBucket_uid
		WHERE B.[Action] = 'Delete'

		UPDATE A -- It's easier just to update all columns rather than checking which one has changed.
		SET A.customer_id = B.customer_id, 
			A.generator_id = B.generator_id,  
			A.ap_expiration_date = B.ap_expiration_date, 
			A.curr_status_code  = B.curr_status_code,
			A.prices = B.prices
		FROM dbo.ContactCORProfileBucket A
			INNER JOIN #DMLAction B ON A.ContactCorProfileBucket_uid = B.ContactCorProfileBucket_uid
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

GRANT EXECUTE ON dbo.ContactCORProfile_SP TO BUCKET_SERVICE
GO

/*
select top 10 * from ContactCORProfileBucket order by contact_id, profile_id

select * from dbo.ContactCORProfileBucket where profile_id = 371 -- 3 rows
update dbo.profile set customer_id = 0 where profile_id = 371 -- delete from bucket
-- update dbo.profile set customer_id = 503 where profile_id = 371 -- restore

select * from dbo.ContactCORProfileBucket where profile_id = 2871 -- 3 rows
update dbo.profile set ap_expiration_date = '09/29/1972' where profile_id = 2871 -- update bucket
-- update dbo.profile set ap_expiration_date = '1994-03-12' where profile_id = 2871 -- restore

-------------------------------------------------------------
select * from #ContactProfiles where profile_id in ( 371, 2871, 3216 ) order by profile_id, contact_id
select * from ContactCORProfileBucket where profile_id in ( 371, 2871, 3216 ) order by profile_id, contact_id

select * from #DMLAction order by profile_id, contact_id
select * from ContactCORProfileBucket where ContactCorProfileBucket_uid in ( select ContactCorProfileBucket_uid from #DMLAction where action = 'delete')
order by profile_id, contact_id

-------------------------------------------------------------

select * from dbo.profile where profile_id in ( 371, 2871, 3216 )
select * from ContactCORProfileBucket where profile_id in ( 371, 2871, 3216 ) order by profile_id, contact_id

*/





	





