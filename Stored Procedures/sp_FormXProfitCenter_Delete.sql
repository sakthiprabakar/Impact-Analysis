
/************************************************************
Procedure	: sp_FormXProfitCenter_Delete
Database	: PLT_AI*
Created		: 5-10-2004 - Jonathan Broome
Description	: Deletes any FormXProfitCenter records for the
			  matching form_id + revision_id.
			  Should be called before any FormXProfitCenter_Inserts
************************************************************/
Create Procedure sp_FormXProfitCenter_Delete (
@form_id							int,
@revision_id						int
)
as

set nocount on

delete from FormXProfitCenter where form_id = @form_id and revision_id = @revision_id
set nocount off


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXProfitCenter_Delete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXProfitCenter_Delete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXProfitCenter_Delete] TO [EQAI]
    AS [dbo];

