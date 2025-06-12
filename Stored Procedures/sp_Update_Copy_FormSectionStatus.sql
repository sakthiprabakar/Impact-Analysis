CREATE PROCEDURE [dbo].[sp_Update_Copy_FormSectionStatus]
	-- Add the parameters for the stored procedure here
	@source_form_id int,
	@source_rev_id int,
	@new_form_id int,
	@new_rev_id int
AS

/* ******************************************************************
  Author       : Senthil Kumar
  Created date : 13-May-2019
  Decription   : This procedure is used to update the FormSectionStatus table active status while copy 


inputs 
	
	@source_form_id 
	@source_rev_id 
	@new_form_id 
	@new_rev_id

output

   MessageResult
	Inserted Successfully

Samples:

exec sp_Update_Copy_FormSectionStatus 458159,1,458196,1
****************************************************************** */

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	
	SET NOCOUNT ON;
	UPDATE newForm SET IsActive=sourcesForm.IsActive
		FROM FormSectionStatus sourcesForm
		JOIN FormSectionStatus  newForm
		ON sourcesForm.section = newForm.section
		WHERE	sourcesForm.form_id=@source_form_id and sourcesForm.revision_id= @source_rev_id 
			AND 
			sourcesForm.form_id=@source_form_id and newForm.revision_id= @source_rev_id 
	
END

GO

GRANT EXECUTE ON [dbo].[sp_Update_Copy_FormSectionStatus] TO COR_USER;

GO