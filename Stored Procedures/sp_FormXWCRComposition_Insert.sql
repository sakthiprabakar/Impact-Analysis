
/************************************************************
Procedure	: sp_FormXWCRComposition_Insert
Database	: PLT_AI*
Created		: 5-10-2004 - Jonathan Broome
Description	: Inserts waste information
			  into the FormXWCRComposition table.
************************************************************/
Create Procedure sp_FormXWCRComposition_Insert (
@form_id							int,
@revision_id						int,
@comp_description					varchar(40),
@comp_from_pct						float,
@comp_to_pct						float
)
as

insert FormXWCRComposition (form_id, revision_id, comp_description, comp_from_pct, comp_to_pct,rowguid)
	values (@form_id, @revision_id, @comp_description, @comp_from_pct, @comp_to_pct,newID())


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWCRComposition_Insert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWCRComposition_Insert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWCRComposition_Insert] TO [EQAI]
    AS [dbo];

