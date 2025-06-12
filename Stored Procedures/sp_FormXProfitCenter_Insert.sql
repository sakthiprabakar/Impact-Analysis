
/************************************************************
Procedure	: sp_FormXProfitCenter_Insert
Database	: PLT_AI*
Created		: 5-10-2004 - Jonathan Broome
Description	: Inserts company/profit center information
			  into the FormXProfitCenter table.
************************************************************/
Create Procedure sp_FormXProfitCenter_Insert (
@form_id							int,
@revision_id						int,
@company_profitcenter			char(10)
)
as
declare @company_id int
declare @profit_ctr_id int

set nocount on
if len(rtrim(ltrim(@company_profitcenter))) <> 4
	return

set @company_id = convert(int, substring(@company_profitcenter, 1, 2))
set @profit_ctr_id = convert(int, substring(@company_profitcenter, 3, 2))

insert FormXProfitCenter (form_id, revision_id, company_id, profit_ctr_id, rowguid)
		values (@form_id, @revision_id, @company_id, @profit_ctr_id, newID())
set nocount off


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXProfitCenter_Insert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXProfitCenter_Insert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormXProfitCenter_Insert] TO [EQAI]
    AS [dbo];

