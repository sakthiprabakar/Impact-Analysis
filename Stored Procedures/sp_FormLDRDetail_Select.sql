
--/************************************************************
--Procedure	: sp_FormLDRDetail_Select
--Database	: PLT_AI*
--Created		: 5-10-2004 - Jonathan Broome
--Description	: Selects FormLDRDetail records for the
--			  matching form_id + revision_id.
--************************************************************/
--Create Procedure sp_FormLDRDetail_Select (
--@form_id							int,
--@revision_id						int
--)
--as

--select
--	form_id, revision_id, manifest_line_item, ww_or_nww, subcategory, manage_method, contains_listed, exhibits_characteristic, soil_treatment_standards
--	from FormLDRDetail
--	where
--		form_id = @form_id and revision_id = @revision_id
--	order by
--		manifest_line_item


--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormLDRDetail_Select] TO [EQWEB]
--    AS [dbo];
--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormLDRDetail_Select] TO [COR_USER]
--    AS [dbo];



--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormLDRDetail_Select] TO [EQAI]
--    AS [dbo];

