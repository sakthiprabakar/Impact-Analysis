
/************************************************************
Procedure	: sp_FormXProfitCenter_List
Database	: PLT_AI*
Created		: 5-10-2004 - Jonathan Broome
Description	: Selects FormXProfitCenter records for the
			  matching form_id + revision_id.  Returns results
			  in the 4-character concatenated company+profitcenter format,
			  combined into a single field as a CSV list.
************************************************************/
Create Procedure sp_FormXProfitCenter_List (
@form_id							int,
@revision_id						int
)
as

declare @list varchar(8000)

select @list = coalesce(@list + ',', '') + 

	right('00' + convert(varchar(2), company_id), 2) + 
	right('00' + convert(varchar(2), profit_ctr_id), 2)
	from FormXProfitCenter
	where
		form_id = @form_id
		and revision_id = @revision_id
	order by
		company_id, profit_ctr_id

select @list as selected_companies


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXProfitCenter_List] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXProfitCenter_List] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXProfitCenter_List] TO [EQAI]
    AS [dbo];

