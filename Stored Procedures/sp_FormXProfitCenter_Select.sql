
/************************************************************
Procedure	: sp_FormXProfitCenter_Select
Database	: PLT_AI*
Created		: 5-10-2004 - Jonathan Broome
Description	: Selects FormXProfitCenter records for the
			  matching form_id + revision_id.  Returns results
			  in the 4-character concatenated company+profitcenter format
************************************************************/
Create Procedure sp_FormXProfitCenter_Select (
@form_id							int,
@revision_id						int
)
as

select 
	right('00' + convert(varchar(2), company_id), 2) + 
	right('00' + convert(varchar(2), profit_ctr_id), 2)
	as selected_company
	from FormXProfitCenter
	where
		form_id = @form_id
		and revision_id = @revision_id
	order by
		company_id, profit_ctr_id
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXProfitCenter_Select] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXProfitCenter_Select] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXProfitCenter_Select] TO [EQAI]
    AS [dbo];

