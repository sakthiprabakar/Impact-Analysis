
--/************************************************************
--Procedure	: sp_FormXWasteCode_Select
--Database	: PLT_AI*
--Created		: 5-10-2004 - Jonathan Broome
--Description	: Selects FormXWasteCode records for the
--			  matching form_id + revision_id.
--			  matches the codes against the mode specified.
--			  (i.e. michigan non haz, etc)
--************************************************************/
--Create Procedure sp_FormXWasteCode_Select (
--@form_id							int,
--@revision_id						int,
--@group_id							int 		= NULL,
--@line_item							char(1)		= NULL,
--@mode								varchar(20)
--)
--as

--select 
--	f.form_id, f.revision_id, f.group_id, f.line_item, f.waste_code
--	from FormXWasteCode f inner join wastecode w on f.waste_code = w.waste_code
--	where
--		(form_id = @form_id and revision_id = @revision_id and (line_item = @line_item and @line_item is not null))
--		-- or (group_id = @group_id and @group_id is not null)
--		and (
--			1=0
--			or (@mode = 'rcra_listed' and substring(w.waste_code, 1, 1) in ('F', 'K', 'P', 'U'))
--			or (@mode = 'rcra_characteristic' and substring(w.waste_code, 1, 2) = 'D0')
--			or (@mode = 'state' and w.waste_code_origin = 'S')
--			or (@mode = 'Dtypes' and substring(w.waste_code, 1, 2) = 'D0')
--			or (@mode = 'mi_nonhaz' and w.waste_code_origin = 'S' and w.haz_flag = 'F' and w.state = 'MI')
--			or (@mode = 'federal_haz' and w.waste_code_origin = 'F' and w.haz_flag = 'T')
--			or (@mode = 'federal' and w.waste_code_origin = 'F')
--			or (@line_item is not null)
--		)
--	order by
--		w.waste_code


--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormXWasteCode_Select] TO [EQWEB]
--    AS [dbo];
--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormXWasteCode_Select] TO [COR_USER]
--    AS [dbo];



--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormXWasteCode_Select] TO [EQAI]
--    AS [dbo];

