
--/************************************************************
--Procedure	: sp_FormXConstituent_Select
--Database	: PLT_AI*
--Created		: 5-10-2004 - Jonathan Broome
--Description	: Selects FormXConstituent records for the
--			  matching form_id + revision_id.
--************************************************************/
--Create Procedure sp_FormXConstituent_Select (
--@form_id							int,
--@revision_id						int,
--@group_id							int 		= NULL,
--@line_item							char(1)		= NULL
--)
--as

--select 
--	form_id, revision_id, group_id, line_item, const_id, const_desc, concentration, unit, uhc
--	from FormXConstituent
--	where
--		(form_id = @form_id and revision_id = @revision_id and (line_item = @line_item and @line_item is not null))
--		-- or (group_id = @group_id and @group_id is not null)
--	order by
--		const_desc, const_id


--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormXConstituent_Select] TO [EQWEB]
--    AS [dbo];
--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormXConstituent_Select] TO [COR_USER]
--    AS [dbo];



--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormXConstituent_Select] TO [EQAI]
--    AS [dbo];

