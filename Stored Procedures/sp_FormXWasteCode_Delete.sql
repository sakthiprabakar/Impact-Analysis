
/************************************************************
Procedure	: sp_FormXWasteCode_Delete
Database	: PLT_AI*
Created		: 5-10-2004 - Jonathan Broome
Description	: Deletes any FormXWasteCode records for the
			  matching form_id + revision_id.
			  Should be called before any FormXWasteCode_Inserts
************************************************************/
Create Procedure sp_FormXWasteCode_Delete (
@form_id							int,
@revision_id						int,
@group_id							int			= NULL
)
as

set nocount on

delete from FormXWasteCode
where
(form_id = @form_id and revision_id = @revision_id)
-- or (group_id = @group_id and @group_id is not null)

set nocount off


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWasteCode_Delete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWasteCode_Delete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWasteCode_Delete] TO [EQAI]
    AS [dbo];

