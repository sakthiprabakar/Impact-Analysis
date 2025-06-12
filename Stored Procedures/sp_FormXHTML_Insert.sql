
--/************************************************************
--Procedure	: sp_FormXHTML_Insert
--Database	: PLT_AI*
--Created		: 7-2-2004 - Jonathan Broome
--Description	: Inserts HTML data into the FormXHTMLData table
--************************************************************/
--Create Procedure sp_FormXHTML_Insert (
--@form_id						int,
--@revision_id					int,
--@group_id						int,
--@html_data						text = NULL	
--)
--as
--declare @intCount int
--select @intCount = count(*) from FormXHTMLData where ((form_id = @form_id and revision_id = @revision_id) or (group_id = @group_id and @group_id is not null))

--if @intCount = 0
--	insert FormXHTMLData values (@form_id, @revision_id, @group_id, @html_data, newid())
--else
--	update FormXHTMLData set html_data = @html_data  where ((form_id = @form_id and revision_id = @revision_id) or (group_id = @group_id and @group_id is not null))

--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormXHTML_Insert] TO [EQWEB]
--    AS [dbo];
--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormXHTML_Insert] TO [COR_USER]
--    AS [dbo];



--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormXHTML_Insert] TO [EQAI]
--    AS [dbo];

