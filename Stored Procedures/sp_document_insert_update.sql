USE [PLT_AI]
GO


DROP PROCEDURE IF EXISTS [dbo].[sp_document_insert_update]
GO

CREATE PROCEDURE [dbo].[sp_document_insert_update]
(
    @Data XML,
    @form_id INT,
    @revision_id INT,
    @web_userid VARCHAR(100),
    @IsTemplateFlag VARCHAR(2)
)
AS

/* ******************************************************************

	Updated By		: Pasupathi P
	Updated On		: 8th Jul 2024
	Type			: Stored Procedure
	Object Name		: [sp_document_insert_update]

	
Description:

	Updated the profile template related changes Requirement 86599: Profile Template > "PCB Remediation Debris" Template
	

EXEC [sp_document_insert_update] '<DocumentAttachment><IsEdited>DA</IsEdited><DocumentAttachment><DocumentAttachment><form_id /><revision_id>1</revision_id><document_id>12812564</document_id><document_source>COROTHER</document_source><document_type>pdf</document_type><document_name>Approval letter.pdf</document_name><db_name>plt_image_0109</db_name><created_by>nyswyn100</created_by><document_comment>TEst Comment</document_comment></DocumentAttachment>
</DocumentAttachment></DocumentAttachment>',523911,1

****************************************************************** */

BEGIN
    BEGIN TRY
        -- Declare variables
        DECLARE @copy_source NVARCHAR(10);
        DECLARE @template_id INT;
        DECLARE @image_id INT;
        DECLARE @document_source VARCHAR(30),
                @document_name VARCHAR(50),
                @description NVARCHAR(255),
                @comment NVARCHAR(2000);
        DECLARE @currentRow INT = 1, @totalRows INT;

        -- Retrieve copy_source and template_id
        SELECT @copy_source = copy_source, 
               @template_id = template_form_id 
        FROM plt_ai..FormWCR 
        WHERE form_id = @form_id 
          AND revision_id = @revision_id;

        -- Declare table to capture output of sp_COR_Scan_Insert
        DECLARE @scaninserttemp TABLE
        (
            image_id INT,
            db_name NVARCHAR(50),
            document_name NVARCHAR(255),
            file_type NVARCHAR(10),
            document_size INT,
            date_created DATETIME,
            date_modified DATETIME
        );

        -- If template flag is 'T', process the document data
        IF @IsTemplateFlag = 'T'
        BEGIN
            -- Declare table to store document data
            DECLARE @DocumentTable TABLE
            (
                document_id INT IDENTITY(1,1),
                document_source VARCHAR(30),
                document_name VARCHAR(50),
                description NVARCHAR(255),
                comment NVARCHAR(2000)
            );

            -- Insert document data into @DocumentTable
            INSERT INTO @DocumentTable (document_source, document_name, description, comment)
            SELECT 
                p.v.value('document_source[1]', 'VARCHAR(30)'),
                p.v.value('document_name[1]', 'VARCHAR(50)'),
                p.v.value('document_comment[1]', 'NVARCHAR(255)'),
                p.v.value('document_comment[1]', 'NVARCHAR(2000)')
            FROM @Data.nodes('DocumentAttachment/DocumentAttachment/DocumentAttachment') p(v);

            -- Check if form_id exists in plt_image..scan and delete related records
            IF EXISTS (SELECT 1 FROM plt_image..scan WHERE form_id = @form_id)
            BEGIN
                -- Temporary table for storing image IDs
                DECLARE @TempImageIds TABLE (image_id INT);

                -- Insert image IDs into @TempImageIds
                INSERT INTO @TempImageIds
                SELECT image_id 
                FROM plt_image..scan 
                WHERE form_id = @form_id;

                -- Delete scancomment records related to the image IDs
                DELETE FROM plt_image..scancomment 
                WHERE image_id IN (SELECT image_id FROM @TempImageIds);

                -- Delete scan records related to form_id
                DELETE FROM plt_image..scan 
                WHERE form_id = @form_id;
            END

            -- Get total rows in @DocumentTable
            SELECT @totalRows = COUNT(*) FROM @DocumentTable;

            -- Loop through each row in @DocumentTable
            WHILE @currentRow <= @totalRows
            BEGIN
                -- Fetch data for the current row
                SELECT @document_source = document_source,
                       @document_name = document_name,
                       @description = description,
                       @comment = comment
                FROM @DocumentTable
                WHERE document_id = @currentRow;

                -- Insert document data using sp_COR_Scan_Insert
                INSERT INTO @scaninserttemp
                EXEC [Plt_Image].[dbo].[sp_COR_Scan_Insert]
                    @document_source = @document_source,
                    @document_name = @document_name,
                    @added_by = @web_userid,
                    @description = @description,
                    @comment = @comment,
                    @form_id = @form_id,
                    @revision_id = @revision_id;

                -- Increment row counter
                SET @currentRow = @currentRow + 1;
            END
        END

        -- Update records in SCAN table if new scan data is inserted
        IF EXISTS (SELECT 1 FROM @scaninserttemp)
			BEGIN
				-- Update SCAN table with new document names and descriptions
				UPDATE [plt_Image].[dbo].SCAN
				SET 
					document_name = COALESCE(s.document_name, sc.document_name),
					[Description] = sc.[Description]
				FROM [plt_Image].[dbo].SCAN sc
				JOIN @scaninserttemp s ON sc.image_id = s.image_id
				WHERE sc.form_id = @form_id 
				  AND sc.revision_id = @revision_id;

				-- Get top image ID from @scaninserttemp
				SELECT TOP 1 @image_id = image_id FROM @scaninserttemp;

				-- Insert scan comment
				INSERT INTO plt_image..scancomment 
				VALUES (@image_id, @comment, @web_userid, GETDATE(), @web_userid, GETDATE());
			END
        ELSE
			BEGIN
				-- Update SCAN table based on signed document source
				DECLARE @signed_documentSource TABLE (document_source VARCHAR(15));
				INSERT INTO @signed_documentSource VALUES ('APPRRECERT'), ('APPRFORM'), ('CORDOC'), ('APPRRAPC');

				UPDATE [plt_Image].[dbo].SCAN
				SET 
					document_source = CASE 
						WHEN EXISTS (SELECT * FROM @signed_documentSource s WHERE s.document_source = p.v.value('document_source[1]', 'VARCHAR(100)'))
						THEN 'CORDOC' 
						ELSE p.v.value('document_source[1]', 'VARCHAR(100)') 
					END,
					[Description] = p.v.value('document_comment[1]', 'NVARCHAR(2000)')
				FROM [plt_Image].[dbo].SCAN sc
				JOIN @Data.nodes('DocumentAttachment/DocumentAttachment/DocumentAttachment') p(v)
				ON p.v.value('document_id[1]', 'int') = sc.image_id
				WHERE sc.form_id = @form_id 
				  AND sc.revision_id = @revision_id;

				-- Update document names for signed documents
				WITH cte_scan AS (
					SELECT 
						image_id,
						CASE 
							WHEN EXISTS(SELECT 1 FROM @signed_documentSource sc WHERE sc.document_source = da.document_source)
							THEN 'Signed Document_' + FORMAT(GETDATE(), 'MM_dd_yyyy_hh_mm_ss')
							ELSE da.document_name 
						END AS document_name
					FROM plt_image..Scan da (NOLOCK)
					WHERE da.document_source IN (SELECT sv.document_source FROM @signed_documentSource sv)
					  AND da.form_id = @form_id  
					  AND da.revision_id = @revision_id
				)
				UPDATE plt_image..Scan 
				SET document_name = cte.document_name 
				FROM plt_image..Scan s 
				JOIN cte_scan cte ON s.image_id = cte.image_id;

				-- Handle scan comments
				DELETE FROM plt_image..scancomment 
				WHERE image_id IN (SELECT p.v.value('document_id[1]', 'int') 
								   FROM @Data.nodes('DocumentAttachment/DocumentAttachment/DocumentAttachment') p(v));

				-- Insert new scan comments
				INSERT INTO plt_image..scancomment 
				SELECT
					p.v.value('document_id[1]', 'int'),
					ISNULL(p.v.value('document_comment[1]', 'NVARCHAR(2000)'), ''),
					@web_userid,
					GETDATE(),
					@web_userid,
					GETDATE()
				FROM @Data.nodes('DocumentAttachment/DocumentAttachment/DocumentAttachment') p(v)
				WHERE p.v.value('document_id[1]', 'int') > 0;
			END
    END TRY
    BEGIN CATCH
        -- Log errors
        DECLARE @mailTrack_userid NVARCHAR(60) = 'COR';
        DECLARE @error_description VARCHAR(2000);
        SET @error_description = CONVERT(VARCHAR(20), @form_id) + ' - ' + CONVERT(VARCHAR(10), @revision_id) + ' ErrorMessage: ' + ERROR_MESSAGE();

        INSERT INTO COR_DB.[dbo].[ErrorLogs] 
        (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
        VALUES
        (@error_description, ERROR_PROCEDURE(), @mailTrack_userid, GETDATE());
    END CATCH
END
GO

-- Grant execution permissions to users
GRANT EXEC ON [dbo].[sp_document_insert_update] TO COR_USER
GO

GRANT EXECUTE ON [dbo].[sp_document_insert_update] TO EQWEB
GO

GRANT EXECUTE ON [dbo].[sp_document_insert_update] TO EQAI
GO