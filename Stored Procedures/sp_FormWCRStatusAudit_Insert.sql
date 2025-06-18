CREATE OR ALTER PROCEDURE dbo.sp_FormWCRStatusAudit_Insert
	  @formid INTEGER
	, @revision_id INTEGER
	, @display_status_uid INTEGER
	, @web_userid nvarchar(60)
AS
/*******************************************************************
-- Author:		Senthil Kumar
-- Create date: 22/03/19
-- Description:	To Insert a record while status change in Formwcr 
--Updated by Blair Christensen for Titan 05/21/2025

Samples:
 EXEC [sp_FormWCRStatusAudit_Insert] @formid, @revision_id,@display_status_uid,@web_userid
 EXEC [sp_FormWCRStatusAudit_Insert] 89034, 1,1,'nyswyn100'
****************************************************************** */
BEGIN
	SET NOCOUNT ON;

	INSERT INTO dbo.FormWCRStatusAudit (form_id, revision_id, display_status_uid, date_added, added_by)
	VALUES(@formid, @revision_id, @display_status_uid, GETDATE(), @web_userid);
END
GO

GRANT EXECUTE ON [dbo].[sp_FormWCRStatusAudit_Insert] TO COR_USER;

GO