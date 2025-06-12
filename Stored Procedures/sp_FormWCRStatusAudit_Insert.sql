CREATE PROCEDURE sp_FormWCRStatusAudit_Insert
		@formid INT,
		@revision_id INT,
		@display_status_uid INT,
		@web_userid nvarchar(60)
AS

/*******************************************************************

procedure to track form status history .

		To Insert a record while status change in Formwcr 

inputs 
	
	@web_userid


	-- =============================================
-- Author:		Senthil Kumar
-- Create date: 22/03/19
-- Description:	To Insert a record while status change in Formwcr 
-- =============================================

Samples:
 EXEC [sp_FormWCRStatusAudit_Insert] @formid, @revision_id,@display_status_uid,@web_userid

 EXEC [sp_FormWCRStatusAudit_Insert] 89034, 1,1,'nyswyn100'

****************************************************************** */
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	--IF(NOT EXISTS(SELECT TOP 1 * FROM FormWCRStatusAudit WHERE form_id=@formid AND revision_id= @revision_id AND display_status_uid=@display_status_uid ORDER BY FormWCRStatusAudit_uid DESC))
	--BEGIN
		INSERT INTO FormWCRStatusAudit VALUES(@formid,@revision_id,@display_status_uid,GETDATE(),@web_userid)
	--END
END

GO

GRANT EXECUTE ON [dbo].[sp_FormWCRStatusAudit_Insert] TO COR_USER;

GO