
/************************************************************
Procedure	: sp_FormXWCRComposition_Select
Database	: PLT_AI*
Created		: 5-10-2004 - Jonathan Broome
Description	: Selects FormXWCRComposition records for the
			  matching form_id + revision_id.
			  matches the codes against the mode specified.
			  (i.e. michigan non haz, etc)
************************************************************/
Create Procedure sp_FormXWCRComposition_Select (
@form_id							int,
@revision_id						int
)
as

select
	form_id, revision_id, comp_description, comp_from_pct, comp_to_pct
	from FormXWCRComposition
	where
		form_id = @form_id and revision_id = @revision_id
	order by
		comp_from_pct + comp_to_pct desc


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWCRComposition_Select] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWCRComposition_Select] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWCRComposition_Select] TO [EQAI]
    AS [dbo];

