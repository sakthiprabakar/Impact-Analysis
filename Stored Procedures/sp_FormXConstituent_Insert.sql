Create Procedure sp_FormXConstituent_Insert (
@form_id							int,
@revision_id						int,
@group_id							int			= NULL,
@line_item							int		= NULL,
@const_id							int 		= NULL,
@const_desc							varchar(50) = NULL,
@concentration						float 		= NULL,
@unit								char(10) 	= NULL,
@uhc								char(1) 	= NULL
)
as
/************************************************************
Procedure	: sp_FormXConstituent_Insert
Database	: PLT_AI*
Created		: 5-10-2004 - Jonathan Broome
Description	: Inserts constituent information
			  into the FormXConstituent table.

03/16/2011  rb  Modified @line_item argument to be number, removed rowguid column
                Removed reference to group_id because not in table
************************************************************/


insert FormXConstituent (form_id, revision_id, /*group_id,*/ line_item, const_id, const_desc, concentration, unit, uhc)
	values (@form_id, @revision_id, /*@group_id,*/ @line_item, @const_id, @const_desc, @concentration, @unit, @uhc)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXConstituent_Insert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXConstituent_Insert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXConstituent_Insert] TO [EQAI]
    AS [dbo];

