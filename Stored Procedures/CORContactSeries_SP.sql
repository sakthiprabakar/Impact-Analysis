-- USE PLT_AI
-- Populate CORContact, CORContactXRef, and CORContactXRole tables.

--DROP PROCEDURE IF EXISTS dbo.CORContactSeries_SP
GO

/*
EXEC dbo.CORContactSeries_SP

select count(*) from dbo.CORContact
select count(*) from dbo.CORContactXRef
select count(*) from dbo.CORContactXRole
*/

CREATE PROCEDURE dbo.CORContactSeries_SP @TruncateBucketTable BIT = 0 AS

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- This is easier than adding WITH (NOLOCK) to every table.
SET NOCOUNT, XACT_ABORT ON
BEGIN TRY 

----------------------------------------------------------------------------------------------------------
-- #1: CORContact
----------------------------------------------------------------------------------------------------------
IF @TruncateBucketTable = 1 OR NOT EXISTS (SELECT 1 FROM dbo.CORContact) BEGIN
	TRUNCATE TABLE dbo.CORContact 

	INSERT INTO dbo.CORContact WITH (TABLOCK) ( -- Minimizes logging.
		contact_id, contact_status, contact_company, [name], title, phone, email, email_flag, modified_by, date_added, date_modified, 
		contact_addr1, contact_city, contact_state, contact_zip_code, web_access_flag, first_name, last_name, web_userid )
	SELECT 
		contact_id, contact_status, contact_company, [name], title, phone, email, email_flag, modified_by, date_added, date_modified, 
		contact_addr1, contact_city, contact_state, contact_zip_code, web_access_flag, first_name, last_name, web_userid 
	FROM dbo.vwCORContact -- !!! This is a view.
	WHERE contact_status = 'A' AND web_access_flag = 'T' AND ISNULL(web_userid, '') <> ''
END
ELSE BEGIN -- Bucket table has data.
	BEGIN TRAN

	DROP TABLE IF EXISTS #DMLAction1

	SELECT 
		COALESCE(A.contact_Id, B.contact_id) AS contact_id, -- For Inserts, A.contact_id will have a value.  For Deletes or Updates, B.contact_id column will have a value.  
		(CASE 
			WHEN A.contact_id IS NOT NULL AND B.contact_id IS NULL THEN 'Insert'
			WHEN A.contact_id IS NULL AND B.contact_id IS NOT NULL THEN 'Delete'
			ELSE 'Update' -- Because NULL/NULL is not a valid case for any join, the only remaining case is NOT NULL/NOT NULL.
		END) AS [Action], 
		-- We only store the new/temp table values, as these will be used for Inserts (all values will be inserted) or Updates (a select few columns will be updated).
		A.contact_company, A.contact_status, A.[name], A.title, A.phone, A.email, A.email_flag, A.modified_by, A.date_added, A.date_modified, 
		A.contact_addr1, A.contact_city, A.contact_state, A.contact_zip_code, A.web_access_flag, A.first_name, A.last_name, A.web_userid
	INTO #DMLAction1
	FROM (SELECT * FROM dbo.vwCORContact WHERE contact_status = 'A' AND web_access_flag = 'T' AND ISNULL(web_userid, '') <> '') A
		FULL OUTER JOIN dbo.CORContact B ON A.contact_id = B.contact_id 
	WHERE -- It's a bit faster to use NOT logic.
		NOT ( A.contact_id IS NOT NULL AND B.contact_id IS NOT NULL AND 
			  ISNULL(A.contact_company, '') = ISNULL(B.contact_company, '') AND ISNULL(A.contact_status, '') = ISNULL(B.contact_status, '') AND 
			  ISNULL(A.[name], '') = ISNULL(B.[name], '') AND ISNULL(A.title, '') = ISNULL(B.title, '') AND 
			  ISNULL(A.phone, '') = ISNULL(B.phone, '') AND ISNULL(A.email, '') = ISNULL(B.email, '') AND ISNULL(A.email_flag, '') = ISNULL(B.email_flag, '') AND 
			  -- do not compare date_added or date_modified as the view uses GETDATE for the 9999999 all users contact.
			  ISNULL(A.modified_by, '') = ISNULL(B.modified_by, '') AND 
			  ISNULL(A.contact_addr1, '') = ISNULL(B.contact_addr1, '') AND ISNULL(A.contact_city, '') = ISNULL(B.contact_city, '') AND 
			  ISNULL(A.contact_state, '') = ISNULL(B.contact_state, '') AND ISNULL(A.contact_zip_code, '') = ISNULL(B.contact_zip_code, '') AND 
			  ISNULL(A.web_access_flag, '') = ISNULL(B.web_access_flag, '') AND 
			  ISNULL(A.first_name, '') = ISNULL(B.first_name, '') AND ISNULL(A.last_name, '') = ISNULL(B.last_name, '') AND ISNULL(A.web_userid, '') = ISNULL(B.web_userid, '') )

	IF (SELECT COUNT(*) FROM #DMLAction1) > 0 BEGIN

		INSERT INTO dbo.CORContact (
			contact_id, contact_status, contact_company, [name], title, phone, email, email_flag, modified_by, date_added, date_modified, 
			contact_addr1, contact_city, contact_state, contact_zip_code, web_access_flag, first_name, last_name, web_userid )
		SELECT 
			contact_id, contact_status, contact_company, [name], title, phone, email, email_flag, modified_by, date_added, date_modified, 
			contact_addr1, contact_city, contact_state, contact_zip_code, web_access_flag, first_name, last_name, web_userid 
		FROM #DMLAction1
		WHERE [Action] = 'Insert'

		DELETE FROM A
		FROM dbo.CORContact A
			INNER JOIN #DMLAction1 B ON A.contact_id = B.contact_id
		WHERE B.[Action] = 'Delete'

		UPDATE A -- It's easier just to update all columns rather than checking which one has changed.
		SET A.contact_company = B.contact_company, A.contact_status = B.contact_status, A.[name] = B.[name], A.title = B.title, A.phone = B.phone, A.email = B.email, A.email_flag = B.email_flag,
			A.modified_by = B.modified_by, A.date_added = B.date_added, A.date_modified = B.date_modified,
			A.contact_addr1 = B.contact_addr1, A.contact_city = B.contact_city, A.contact_state = B.contact_state, A.contact_zip_code = B.contact_zip_code, 
			A.web_access_flag = B.web_access_flag, A.first_name = B.first_name, A.last_name = B.last_name, A.web_userid = B.web_userid
		FROM dbo.CORContact A
			INNER JOIN #DMLAction1 B ON A.contact_id = B.contact_id
		WHERE B.[Action] = 'Update'
	END

	COMMIT TRAN
END

/*

delete from CORContact where contact_id = 169 -- insert case
update CORContact set name = 'Derek' where contact_id = 199 -- update case
update dbo.Contact set contact_status = 'V' where contact_id = 203 -- delete case
-- update dbo.Contact set contact_status = 'A' where contact_id = 203 -- restore

select * from #DMLAction1
select * from vwCORContact where contact_id in (169, 199, 203)
select * from CORContact where contact_id in (169, 199, 203)

*/

----------------------------------------------------------------------------------------------------------
-- #2: CORContactXRef
----------------------------------------------------------------------------------------------------------
IF @TruncateBucketTable = 1 OR NOT EXISTS (SELECT 1 FROM dbo.CORContactXRef) BEGIN
	TRUNCATE TABLE dbo.CORContactXRef 

	INSERT INTO dbo.CORContactXRef WITH (TABLOCK) ( -- Minimizes logging.
		contact_id, [type], customer_id, generator_id, web_access, [status], added_by, date_added, modified_by, date_modified, primary_contact )
	SELECT contact_id, [type], customer_id, generator_id, web_access, [status], added_by, date_added, modified_by, date_modified, primary_contact
	FROM dbo.vwCORContactXRef -- !!! This is a view.
	WHERE [status] = 'A' AND web_access = 'A'
END
ELSE BEGIN -- Bucket table has data.
	BEGIN TRAN

	DROP TABLE IF EXISTS #DMLAction2

	--------------------------------------
	-- Customer Section of CORContactXRef.
	--------------------------------------
	SELECT 
		COALESCE(A.contact_Id, B.contact_id) AS contact_id, -- For Inserts, A.contact_id will have a value.  For Deletes or Updates, B.contact_id column will have a value.  
		COALESCE(A.customer_id, B.customer_id) AS customer_id,
		(CASE 
			WHEN A.contact_id IS NOT NULL AND B.contact_id IS NULL THEN 'Insert'
			WHEN A.contact_id IS NULL AND B.contact_id IS NOT NULL THEN 'Delete'
			ELSE 'Update' -- Because NULL/NULL is not a valid case for any join, the only remaining case is NOT NULL/NOT NULL.
		END) AS [Action], 
		-- We only store the new/temp table values, as these will be used for Inserts (all values will be inserted) or Updates (a select few columns will be updated).
		A.generator_id, A.web_access, A.[status], A.added_by, A.date_added, A.modified_by, A.date_modified, A.primary_contact 
	INTO #DMLAction2
	FROM 
		( SELECT contact_id, [type], customer_id, generator_id, web_access, [status], added_by, date_added, modified_by, date_modified, primary_contact
		  FROM dbo.vwCORContactXRef -- !!! This is a view.
		  WHERE [status] = 'A' AND web_access = 'A' AND [type] = 'C'
		) A
		FULL OUTER JOIN 
		( SELECT contact_id, [type], customer_id, generator_id, web_access, [status], added_by, date_added, modified_by, date_modified, primary_contact
		  FROM dbo.CORContactXRef WHERE [type] = 'C') B ON 
				A.contact_id = B.contact_id AND A.customer_id = B.customer_id 
	WHERE -- It's a bit faster to use NOT logic.
		NOT ( A.contact_id IS NOT NULL AND B.contact_id IS NOT NULL AND 
			  ISNULL(A.generator_id, -1) = ISNULL(B.generator_id, -1) AND 
			  ISNULL(A.web_access, '') = ISNULL(B.web_access, '') AND ISNULL(A.[status], '') = ISNULL(B.[status], '') AND 
			  -- do not compare date_added or date_modified as the view uses GETDATE for the 9999999 all users contact.
			  ISNULL(A.added_by, '') = ISNULL(B.added_by, '') AND ISNULL(A.modified_by, '') = ISNULL(B.modified_by, '') AND 
			  ISNULL(A.primary_contact, '') = ISNULL(B.primary_contact, '') )

	IF (SELECT COUNT(*) FROM #DMLAction2) > 0 BEGIN
		INSERT INTO dbo.CORContactXRef ( contact_id, [type], customer_id, generator_id, web_access, [status], added_by, date_added, modified_by, date_modified, primary_contact )
		SELECT 
			contact_id, 'C' AS [type], customer_id, generator_id, web_access, [status], added_by, date_added, modified_by, date_modified, primary_contact 
		FROM #DMLAction2
		WHERE [Action] = 'Insert'

		DELETE FROM A
		FROM dbo.CORContactXRef A
			INNER JOIN #DMLAction2 B ON A.contact_id = B.contact_id AND A.customer_id = B.customer_id AND A.[type] = 'C'
		WHERE B.[Action] = 'Delete'

		UPDATE A -- It's easier just to update all columns rather than checking which one has changed.
		SET A.generator_id = B.generator_id, A.web_access = B.web_access, A.[status] = B.[status], A.added_by = B.added_by, A.date_added = B.date_added, 
			A.modified_by = B.modified_by, A.date_modified = B.date_modified, A.primary_contact = B.primary_contact
		FROM dbo.CORContactXRef A
			INNER JOIN #DMLAction2 B ON A.contact_id = B.contact_id AND A.customer_id = B.customer_id AND A.[type] = 'C'
		WHERE B.[Action] = 'Update'
	END

	/*

	select top 12 * from vwCORContactXRef where [status] = 'A' AND web_access = 'A' AND [type] = 'C' and contact_id > 0
	select top 10 * from CORContactXRef where [type] = 'C' and contact_id > 0

	delete from CORContactXRef where contact_id = 57 and [type] = 'C' -- insert case
	update CORContactXRef set primary_contact = 'F' where contact_id = 111 and [type] = 'C' -- update case
	update dbo.ContactXRef set [status] = 'V' where contact_id = 199 and [type] = 'C' -- delete case
	-- update dbo.ContactXRef set [status] = 'A' where contact_id = 199 and [type] = 'C' -- restore

	select * from #DMLAction2
	select * from vwCORContactXRef where contact_id in (57, 111, 199) and [type] = 'C'
	select * from CORContactXRef where contact_id in (57, 111, 199) and [type] = 'C'

	*/

	---------------------------------------
	-- Generator Section of CORContactXRef.
	---------------------------------------
	DROP TABLE IF EXISTS #DMLAction3

	SELECT 
		COALESCE(A.contact_Id, B.contact_id) AS contact_id, -- For Inserts, A.contact_id will have a value.  For Deletes or Updates, B.contact_id column will have a value.  
		COALESCE(A.generator_id, B.generator_id) AS generator_id,
		(CASE 
			WHEN A.contact_id IS NOT NULL AND B.contact_id IS NULL THEN 'Insert'
			WHEN A.contact_id IS NULL AND B.contact_id IS NOT NULL THEN 'Delete'
			ELSE 'Update' -- Because NULL/NULL is not a valid case for any join, the only remaining case is NOT NULL/NOT NULL.
		END) AS [Action], 
		-- We only store the new/temp table values, as these will be used for Inserts (all values will be inserted) or Updates (a select few columns will be updated).
		A.customer_id, A.web_access, A.[status], A.added_by, A.date_added, A.modified_by, A.date_modified, A.primary_contact 
	INTO #DMLAction3
	FROM 
		( SELECT contact_id, [type], customer_id, generator_id, web_access, [status], added_by, date_added, modified_by, date_modified, primary_contact
		  FROM dbo.vwCORContactXRef -- !!! This is a view.
		  WHERE [status] = 'A' AND web_access = 'A' AND [type] = 'G'
		) A
		FULL OUTER JOIN 
		( SELECT contact_id, [type], customer_id, generator_id, web_access, [status], added_by, date_added, modified_by, date_modified, primary_contact
		  FROM dbo.CORContactXRef WHERE [type] = 'G') B ON 
				A.contact_id = B.contact_id AND A.generator_id = B.generator_id 
	WHERE -- It's a bit faster to use NOT logic.
		NOT ( A.contact_id IS NOT NULL AND B.contact_id IS NOT NULL AND 
			  ISNULL(A.customer_id, -1) = ISNULL(B.customer_id, -1) AND 
			  ISNULL(A.web_access, '') = ISNULL(B.web_access, '') AND ISNULL(A.[status], '') = ISNULL(B.[status], '') AND 
			  -- do not compare date_added or date_modified as the view uses GETDATE for the 9999999 all users contact.
			  ISNULL(A.added_by, '') = ISNULL(B.added_by, '') AND ISNULL(A.modified_by, '') = ISNULL(B.modified_by, '') AND
			  ISNULL(A.primary_contact, '') = ISNULL(B.primary_contact, '') )

	IF (SELECT COUNT(*) FROM #DMLAction3) > 0 BEGIN
		INSERT INTO dbo.CORContactXRef ( contact_id, [type], customer_id, generator_id, web_access, [status], added_by, date_added, modified_by, date_modified, primary_contact )
		SELECT 
			contact_id, 'G' AS [type], customer_id, generator_id, web_access, [status], added_by, date_added, modified_by, date_modified, primary_contact 
		FROM #DMLAction3
		WHERE [Action] = 'Insert'

		DELETE FROM A
		FROM dbo.CORContactXRef A
			INNER JOIN #DMLAction3 B ON A.contact_id = B.contact_id AND A.generator_id = B.generator_id AND A.[type] = 'G'
		WHERE B.[Action] = 'Delete'

		UPDATE A -- It's easier just to update all columns rather than checking which one has changed.
		SET A.customer_id = B.customer_id, A.web_access = B.web_access, A.[status] = B.[status], A.added_by = B.added_by, A.date_added = B.date_added, 
			A.modified_by = B.modified_by, A.date_modified = B.date_modified, A.primary_contact = B.primary_contact
		FROM dbo.CORContactXRef A
			INNER JOIN #DMLAction3 B ON A.contact_id = B.contact_id AND A.generator_id = B.generator_id AND A.[type] = 'G'
		WHERE B.[Action] = 'Update'
	END
	
	COMMIT TRAN
END

/*

select top 10 * from vwCORContactXRef where [status] = 'A' AND web_access = 'A' AND [type] = 'G' and contact_id > 0
select top 10 * from CORContactXRef where [type] = 'G' and contact_id > 0

delete from CORContactXRef where contact_id = 57 and [type] = 'G' -- insert case
update CORContactXRef set primary_contact = 'F' where contact_id = 111 and [type] = 'G' -- update case
update dbo.ContactXRef set [status] = 'V' where contact_id = 199 and [type] = 'G' -- delete case
-- update dbo.ContactXRef set [status] = 'A' where contact_id = 199 and [type] = 'G' -- restore

select * from #DMLAction3
select * from vwCORContactXRef where contact_id in (57, 111, 199) and [type] = 'G'
select * from CORContactXRef where contact_id in (57, 111, 199) and [type] = 'G'

*/

----------------------------------------------------------------------------------------------------------
-- #3: CORContactXRole
----------------------------------------------------------------------------------------------------------
IF @TruncateBucketTable = 1 OR NOT EXISTS (SELECT 1 FROM dbo.CORContactXRole) BEGIN
	TRUNCATE TABLE dbo.CORContactXRole 

	INSERT INTO dbo.CORContactXRole WITH (TABLOCK) ( -- Minimizes logging.
		contact_id, RoleId, [status], added_by, date_added, modified_by, date_modified )
	SELECT contact_id, RoleId, [status], added_by, date_added, modified_by, date_modified
	FROM dbo.vwCORContactXRole -- !!! This is a view.
	WHERE [status] = 'A'
END
ELSE BEGIN -- Bucket table has data.
	BEGIN TRAN

	DROP TABLE IF EXISTS #DMLAction4

	SELECT 
		COALESCE(A.contact_Id, B.contact_id) AS contact_id, -- For Inserts, A.contact_id will have a value.  For Deletes or Updates, B.contact_id column will have a value.  
		COALESCE(A.RoleId, B.RoleId) AS RoleId, 
		(CASE 
			WHEN A.contact_id IS NOT NULL AND B.contact_id IS NULL THEN 'Insert'
			WHEN A.contact_id IS NULL AND B.contact_id IS NOT NULL THEN 'Delete'
			ELSE 'Update' -- Because NULL/NULL is not a valid case for any join, the only remaining case is NOT NULL/NOT NULL.
		END) AS [Action], 
		-- We only store the new/temp table values, as these will be used for Inserts (all values will be inserted) or Updates (a select few columns will be updated).
		A.[status], A.added_by, A.date_added, A.modified_by, A.date_modified
	INTO #DMLAction4
	FROM (SELECT contact_id, RoleId, [status], added_by, date_added, modified_by, date_modified
		  FROM dbo.vwCORContactXRole 
		  WHERE [status] = 'A'
		 ) A
		 FULL OUTER JOIN dbo.CORContactXRole B ON A.contact_id = B.contact_id AND A.RoleId = B.RoleId
	WHERE -- It's a bit faster to use NOT logic.
		NOT ( A.contact_id IS NOT NULL AND B.contact_id IS NOT NULL AND 
			  ISNULL(A.[status], '') = ISNULL(B.[status], '') AND ISNULL(A.added_by, '') = ISNULL(B.added_by, '') AND 
			  -- do not compare date_added or date_modified as the view uses GETDATE for the 9999999 all users contact.
			  ISNULL(A.modified_by, '') = ISNULL(B.modified_by, '') )

	IF (SELECT COUNT(*) FROM #DMLAction4) > 0 BEGIN

		INSERT INTO dbo.CORContactXRole ( contact_id, RoleId, [status], added_by, date_added, modified_by, date_modified )
		SELECT 
			contact_id, RoleId, [status], added_by, date_added, modified_by, date_modified
		FROM #DMLAction4
		WHERE [Action] = 'Insert'

		DELETE FROM A
		FROM dbo.CORContactXRole A
			INNER JOIN #DMLAction4 B ON A.contact_id = B.contact_id AND A.RoleId = B.RoleId
		WHERE B.[Action] = 'Delete'

		UPDATE A -- It's easier just to update all columns rather than checking which one has changed.
		SET A.[status] = B.[status], A.added_by = B.added_by, A.date_added = B.date_added, A.modified_by = B.modified_by, A.date_modified = B.date_modified
		FROM dbo.CORContactXRole A
			INNER JOIN #DMLAction4 B ON A.contact_id = B.contact_id AND A.RoleId = B.RoleId
		WHERE B.[Action] = 'Update'
	END

	COMMIT TRAN
END

/*

select top 10 * from vwCORContactXRole order by contact_id, roleid

select count(*) from CORContactXRole
select top 10 * from CORContactXRole

select * from #DMLAction4

delete from CORContactXRole where contact_id = 169 -- insert case
update ContactXRole set status = 'V' where contact_id = 199 -- delete case
-- update ContactXRole set status = 'A' where contact_id = 199 -- insert/restore

update ContactXRole set added_by = 'derek' where contact_id = 199 -- update case
update ContactXRole set added_by = 'SA' where contact_id = 199 -- update/restore case

select * from vwCORContactXRole where status = 'A' and contact_id in (169, 9999999) 
select * from CORContactXRole where contact_id in (169, 9999999) 

*/

END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION
    DECLARE @msg NVARCHAR(2048) = ERROR_MESSAGE()  
    RAISERROR (@msg, 16, 1)
    RETURN -1
END CATCH

GO

GRANT EXECUTE ON dbo.CORContactSeries_SP TO BUCKET_SERVICE
GO


