
Create Procedure sp_FormXWasteCode_Insert (
@form_id							int,
@revision_id						int,
@group_id							int			= NULL,
@line_item							int		= NULL,
@waste_code							char(4)
)
as
/************************************************************
Procedure	: sp_FormXWasteCode_Insert
Database	: PLT_AI*
Created		: 5-10-2004 - Jonathan Broome
Description	: Inserts waste information
			  into the FormXWasteCode table.

03/16/2011  rb  Modified @line_item argument to be number, removed rowguid column
                Removed reference to group_id because not in table
************************************************************/


insert FormXWasteCode (form_id, revision_id, /*group_id,*/ line_item, waste_code)
	values (@form_id, @revision_id, /*@group_id,*/ @line_item, @waste_code)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWasteCode_Insert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWasteCode_Insert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXWasteCode_Insert] TO [EQAI]
    AS [dbo];

