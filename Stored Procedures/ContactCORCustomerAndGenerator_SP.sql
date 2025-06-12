-- USE PLT_AI
-- Customer and Generator Buckets

--DROP PROCEDURE IF EXISTS dbo.ContactCORCustomerAndGenerator_SP
GO

/*
EXEC dbo.ContactCORCustomerAndGenerator_SP

select count(*) from dbo.ContactCORCustomerBucket
select count(*) from dbo.ContactCORGeneratorBucket -- 360050
*/

CREATE PROCEDURE dbo.ContactCORCustomerAndGenerator_SP @TruncateBucketTable BIT = 0 AS

----------------------------------------------------------------------------------
-- This SP combines the Customer and Generator logic into a single SP.
-- This was done because the Generator logic can re-use one of the Customer steps.
----------------------------------------------------------------------------------

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- This is easier than adding WITH (NOLOCK) to every table.
SET NOCOUNT, XACT_ABORT ON
BEGIN TRY 

---------------------------------------------------------------------------------------
-- Note: CORContact and CORContactXRef only contain active and web accessible contacts.
--		 All bucket tables are derived from active and web accessible contacts only.
---------------------------------------------------------------------------------------

-------------------------------------------
-- Customer #1: Contacts and all Customers.
-------------------------------------------
DROP TABLE IF EXISTS #ContactCustomerAll

SELECT A.contact_id, B.customer_id
INTO #ContactCustomerAll
FROM dbo.CORContact A 
	INNER JOIN dbo.CORContactXRef B ON A.contact_id = B.contact_id 
WHERE B.[type] = 'C' -- !!! Customer type

-------------------------------------------------------------------------------------------------------------------------------
-- Customer #2: Contacts and active Customers.  
--				All and active customers are separated into 2 temp tables, because Indirect Generators come from All Customers.
-------------------------------------------------------------------------------------------------------------------------------
DROP TABLE IF EXISTS #ContactCustomerAllActive

SELECT A.contact_id, B.customer_id
INTO #ContactCustomerAllActive
FROM #ContactCustomerAll A
	INNER JOIN dbo.Customer B ON A.customer_id = B.customer_id
WHERE B.cust_status = 'A' AND B.terms_code <> 'NOADMIT'

---------------------------------------------------
-- Customer #3: Insert all or Insert/Delete deltas.
---------------------------------------------------
IF @TruncateBucketTable = 1 OR NOT EXISTS (SELECT 1 FROM dbo.ContactCORCustomerBucket) BEGIN
	TRUNCATE TABLE dbo.ContactCORCustomerBucket 

	INSERT INTO dbo.ContactCORCustomerBucket WITH (TABLOCK) ( contact_id, customer_id ) -- Minimizes logging.
	SELECT contact_id, customer_id 
	FROM #ContactCustomerAllActive
END
ELSE BEGIN -- Bucket table has data.
	BEGIN TRAN

	---------------------
	-- Insert new records
	---------------------
	INSERT INTO dbo.ContactCORCustomerBucket ( contact_id, customer_id )
	SELECT A.contact_id, A.customer_id
	FROM #ContactCustomerAllActive A
		LEFT JOIN dbo.ContactCORCustomerBucket B ON A.contact_id = B.contact_id AND A.customer_id = B.customer_id
	WHERE B.contact_id IS NULL

	-------------------------
	-- Delete missing records
	-------------------------
	DELETE FROM A
	FROM dbo.ContactCORCustomerBucket A
		LEFT JOIN #ContactCustomerAllActive B ON A.contact_id = B.contact_id AND A.customer_id = B.customer_id
	WHERE B.contact_id IS NULL

	COMMIT TRAN
END

/*
select top 10 * from #ContactCustomerAllActive where contact_id <> 9999999
select top 10 * from ContactCORCustomerBucket where contact_id = 503

update dbo.customer set cust_status = 'I' where customer_id = 503
update dbo.customer set cust_status = 'A' where customer_id = 503
select cust_status from dbo.customer where customer_id = 503
*/

------------------------------------------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------
-- Generator #1: Contact and Direct + Indirect Generators.
----------------------------------------------------------
DROP TABLE IF EXISTS #ContactGeneratorDirect

SELECT A.contact_id, B.generator_id -- Do not need DISTINCT, as contact_id/generator_id is unique in CORContactXRef.
INTO #ContactGeneratorDirect
FROM dbo.CORContact A 
	INNER JOIN dbo.CORContactXRef B ON A.contact_id = B.contact_id 
WHERE B.[type] = 'G' -- !!! Generator type

DROP TABLE IF EXISTS #ContactGeneratorIndirect

SELECT DISTINCT A.contact_id, B.generator_id -- Must use DISTINCT, as a contact_id/generator_id can be assigned to multiple customer_ids.
INTO #ContactGeneratorIndirect
FROM #ContactCustomerAll A -- !!! The indirect generator list comes from the contact/customer table, which means a generator can be found through a customer that is not active.
	INNER JOIN dbo.CustomerGenerator B ON A.customer_id = B.customer_id

----------------------------------------------------
-- Generator #2: Insert all or Insert/Delete deltas.
----------------------------------------------------
IF @TruncateBucketTable = 1 OR NOT EXISTS (SELECT 1 FROM dbo.ContactCORGeneratorBucket) BEGIN
	TRUNCATE TABLE dbo.ContactCORGeneratorBucket 

	INSERT INTO dbo.ContactCORGeneratorBucket WITH (TABLOCK) ( contact_id, generator_id, direct_flag ) -- Minimizes logging.
	SELECT contact_id, generator_id, 'D' AS direct_flag FROM #ContactGeneratorDirect

	INSERT INTO dbo.ContactCORGeneratorBucket WITH (TABLOCK) ( contact_id, generator_id, direct_flag ) -- Minimizes logging.
	SELECT contact_id, generator_id, 'I' AS direct_flag FROM #ContactGeneratorIndirect

	-- select count(*) from ContactCORGeneratorBucket -- 515369
END
ELSE BEGIN -- Bucket table has data.
	BEGIN TRAN

	---------------------
	-- Insert new records
	---------------------
	INSERT INTO dbo.ContactCORGeneratorBucket ( contact_id, generator_id, direct_flag )
	SELECT A.contact_id, A.generator_id, 'D' AS direct_flag
	FROM #ContactGeneratorDirect A 
		LEFT JOIN (SELECT * FROM dbo.ContactCORGeneratorBucket WHERE direct_flag = 'D') B ON 
			A.contact_id = B.contact_id AND A.generator_id = B.generator_id
	WHERE B.contact_id IS NULL

	INSERT INTO dbo.ContactCORGeneratorBucket ( contact_id, generator_id, direct_flag )
	SELECT A.contact_id, A.generator_id, 'I' AS direct_flag
	FROM #ContactGeneratorIndirect A 
		LEFT JOIN (SELECT * FROM dbo.ContactCORGeneratorBucket WHERE direct_flag = 'I') B ON 
			A.contact_id = B.contact_id AND A.generator_id = B.generator_id
	WHERE B.contact_id IS NULL

	-------------------------
	-- Delete missing records
	-------------------------
	DELETE FROM A
	FROM dbo.ContactCORGeneratorBucket A
		LEFT JOIN #ContactGeneratorDirect B ON A.contact_id = B.contact_id AND A.generator_id = B.generator_id 
	WHERE A.direct_flag = 'D' AND B.contact_id IS NULL

	DELETE FROM A
	FROM dbo.ContactCORGeneratorBucket A
		LEFT JOIN #ContactGeneratorIndirect B ON A.contact_id = B.contact_id AND A.generator_id = B.generator_id 
	WHERE A.direct_flag = 'I' AND B.contact_id IS NULL

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
select * from ContactCORGeneratorBucket where contact_id = 11289 and direct_flag = 'D'
select * from contact where contact_id = 11289
select * from CORContact where contact_id = 11289
-- update dbo.contact set contact_status = 'I' where contact_id = 11289
-- update dbo.contact set contact_status = 'A' where contact_id = 11289

select * from ContactCORGeneratorBucket where contact_id = 208729 and direct_flag = 'I'
select * from contact where contact_id = 208729
select * from CORContact where contact_id = 208729
-- update dbo.contact set contact_status = 'I' where contact_id = 208729
-- update dbo.contact set contact_status = 'A' where contact_id = 208729

--------------------------------------------------------
select count(*) from dbo.CORContact -- 1481
select count(*) from dbo.CORContactXRef -- 255099

select * from contact where contact_id IN (11289, 208729)

select * from dbo.CORContact where contact_id IN (11289, 208729)
select * from dbo.CORContactXRef where contact_id IN (11289, 208729)

--------------------------------------------------------

select count(*) from dbo.ContactCORCustomerBucket -- 4568
select count(*) from dbo.ContactCORGeneratorBucket -- 329740

*/

