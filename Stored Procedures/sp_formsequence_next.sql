CREATE OR ALTER PROCEDURE dbo.sp_formsequence_next
	  @form_id	INTEGER
	, @revision_id	INTEGER
	, @modified_by	VARCHAR(60)
	, @SELECT INTEGER = 1
AS
/***************************************************************************************
returns the next revision_id in a form_id's lineage, and increments the sequence
Load:	plt_ai

notes:	this sp will take an optional 2nd parameter, to force no SELECT @result.
	this sp will create a new sequence if the form_id given does not exist in the table yet.

08/29/2005 jpb  created
10/01/2007 WAC	Removed server references in queries.
Updated by Blair Christensen for Titan 05/08/2025

sp_formsequence_next 410, 1, 'jonathan.broome@eqonline.com', 0 -- zero = silent
****************************************************************************************/
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	DECLARE @next_revision_id INTEGER
		  , @error VARCHAR(255)
		  , @last_user VARCHAR(60)
		  , @old_revision INTEGER
		  , @old_user VARCHAR(60)
		  , @signed INTEGER
		  , @check_rev_id INTEGER

	start:
	SET @error = ''

	-- JPB If there's no FormSequence record, populate from max form revision existing:
	IF NOT EXISTS (SELECT 1 FROM dbo.FormSequence WHERE form_id= @form_id)
		BEGIN
			INSERT INTO dbo.FormSequence (form_id, next_revision_id, last_user)
			SELECT TOP 1 form_id, revision_id + 1 as next_revision_id, modified_by as last_user
			  FROM dbo.FormHeader
			 WHERE form_id = @form_id
			 ORDER BY revision_id DESC;
		END
	ELSE
		BEGIN
			-- JPB If there's a FormSequence record already but somehow it's got a lower revision_id
			--     Than exists in formheader, update formsequence to the highest revision info (+1), and same user as formheader
			SELECT TOP 1 @check_rev_id = revision_id + 1
			     , @last_user = modified_by
			  FROM dbo.FormHeader
			 WHERE form_id = @form_id
			ORDER BY revision_id DESC;

			IF (SELECT next_revision_id FROM dbo.FormSequence WHERE form_id = @form_id) < @check_rev_id
			-- e.g. if formsequence.next_revision_id < formheader.revision_id + 1
				BEGIN
					UPDATE dbo.FormSequence
					   SET next_revision_id = @check_rev_id
					     , last_user = @last_user
					 WHERE form_id = @form_id;
				END
		END

	BEGIN TRANSACTION formsequence_next

		SELECT @next_revision_id = next_revision_id
			 , @last_user = last_user
		  FROM dbo.FormSequence
		 WHERE form_id = @form_id;

		IF @next_revision_id IS NULL AND @form_id IS NOT NULL
			BEGIN
				-- Leave the alphabet in this insert, because the next pass compares it to the real modified_by, and updates the revision properly on new records
				INSERT INTO dbo.FormSequence (form_id, next_revision_id, last_user)
					VALUES (@form_id, 1, 'abcdefghijklmnopqrstuvwxyz');

				COMMIT TRANSACTION formsequence_next
				GOTO START
			END
		ELSE IF @next_revision_id IS NULL
			BEGIN
				SET @error = 'NULL form_id submitted, no updates could be made.'
			END
		ELSE
			BEGIN
				SELECT @signed = count(s.form_id) 
				  FROM dbo.FormSignature s 
					   JOIN dbo.FormHeaderDistinct d on s.form_id = d.form_id 
							AND s.revision_id = d.revision_id 
				 WHERE s.form_id = @form_id;

				IF (@last_user <> @modified_by) OR (@signed = 1) OR (@revision_id IS NULL) OR (@revision_id +1 <> @next_revision_id)
					BEGIN
						IF @revision_id +1 > @next_revision_id
							BEGIN
								SET @next_revision_id = @revision_id + 1
							END

						UPDATE dbo.FormSequence
						   SET next_revision_id = (@next_revision_id + 1)
						     , last_user = @modified_by
						 WHERE form_id = @form_id;

						SET @revision_id = @next_revision_id
					END
			END

	IF @error = ''
		BEGIN
			COMMIT TRANSACTION formsequence_next
		END
	ELSE
		BEGIN
			ROLLBACK TRANSACTION formsequence_next
		END

	IF @error = ''
		BEGIN
			SELECT @revision_id as next WHERE @SELECT <> 0
		END
	ELSE
		BEGIN
			SET @revision_id = null
			SELECT @error as next WHERE @SELECT <> 0
		END

	SET NOCOUNT OFF
	SET XACT_ABORT OFF

	IF @revision_id IS NULL
		BEGIN
			SET @revision_id = -1
		END

	RETURN @revision_id
END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_formsequence_next] TO [EQWEB]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_formsequence_next] TO [COR_USER]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_formsequence_next] TO [EQAI]
    AS [dbo];
GO