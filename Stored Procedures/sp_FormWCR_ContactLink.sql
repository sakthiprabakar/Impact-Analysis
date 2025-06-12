
-- =============================================
-- Author:		Dineshkumar
-- Create date: 14-Dec-2018
-- Description:	This procedure is used for linking Form with contact

-- =============================================
CREATE PROCEDURE [dbo].[sp_FormWCR_ContactLink]
	-- Add the parameters for the stored procedure here
	@web_userid NVARCHAR(200)	
AS

/* ******************************************************************

procedure to link the contactid with Formid when creating a new Form and it returns newly created formId and revision_id

inputs 
	
	@web_userid

Returns

	form_id
	revision_id

Samples:
 EXEC sp_FormWCR_ContactLink 'mab31@dcx.com'

****************************************************************** */

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
		DECLARE @FormId INT
		EXEC @FormId = sp_sequence_next 'form.form_id'
		DECLARE @RevisionId INT = 1		

		--INSERT INTO FormWCR (form_id,revision_id,[status],locked,[source],date_created,date_modified,created_by,modified_by, copy_source)
		--VALUES(@FormId,
		--	 @RevisionId,
		--	 'A',
		--	 'U',
		--	 'W',
		--	 GETDATE(),
		--	 GETDATE(),
		--	 @web_userid,
		--	 @web_userid,
		--	 'new')			 
		
		--IF(NOT EXISTS(SELECT *FROM ContactFormWCRBucket WHERE form_id = @FormId AND revision_id = @RevisionId))
		--BEGIN
		--	INSERT INTO ContactFormWCRBucket (contact_id,form_id,revision_id) Values(
		--	(SELECT contact_ID FROM Contact WHERE web_userid = @web_userid),
		--	@FormId,
		--	@RevisionId
		--	)
		--END

		SELECT @FormId as FormId, @RevisionId as RevisionId
		
END

GO
GRANT EXEC ON [dbo].[sp_FormWCR_ContactLink] TO COR_USER;
GO
