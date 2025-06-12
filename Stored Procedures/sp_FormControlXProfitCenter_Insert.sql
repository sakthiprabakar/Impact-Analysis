/************************************************************
Procedure	: sp_FormControlXProfitCenter_Insert
Database	: PLT_AI*
Created		: 5-10-2004 - Jonathan Broome
Description	: Inserts company/profit center information
			  into the FormControlXProfitCenter table.
************************************************************/
Create Procedure sp_FormControlXProfitCenter_Insert (
@form_id							int,
@revision_id						int,
@company_id							int,
@profit_ctr_id						int,
@status								char(1),
@preappr_key						int,
@username							char(10)
)
as

insert FormControlXProfitCenter (form_id, revision_id, company_id, profit_ctr_id, status, preappr_key, created_by, modified_by, date_added, date_modified, rowguid)
		values (@form_id, @revision_id, @company_id, @profit_ctr_id, @status, @preappr_key, @username, @username, GETDATE(), GETDATE(), newID())
set nocount off


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormControlXProfitCenter_Insert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormControlXProfitCenter_Insert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormControlXProfitCenter_Insert] TO [EQAI]
    AS [dbo];

