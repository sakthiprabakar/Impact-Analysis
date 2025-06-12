
/************************************************************
Procedure	: sp_FormXWCRComposition_Delete
Database	: PLT_AI*
Created		: 5-10-2004 - Jonathan Broome
Description	: Deletes any FormXWCRComposition records for the
			  matching form_id + revision_id.
			  Should be called before any FormXWCRComposition_Inserts
************************************************************/
Create Procedure sp_FormXWCRComposition_Delete (
@form_id							int,
@revision_id						int
)
as

set nocount on

delete from FormXWCRComposition
where
form_id = @form_id and revision_id = @revision_id

set nocount off


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWCRComposition_Delete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWCRComposition_Delete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWCRComposition_Delete] TO [EQAI]
    AS [dbo];

