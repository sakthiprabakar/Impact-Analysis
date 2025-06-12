/************************************************************
Procedure	: sp_FormControlXProfitCenter_Update
Database	: PLT_AI*
Created		: 5-10-2004 - Jonathan Broome
Description	: Updates company/profit center control information
************************************************************/
Create Procedure sp_FormControlXProfitCenter_Update (
@form_id							int,
@revision_id						int,
@company_id							int,
@profit_ctr_id						int,
@status								char(1),
@preappr_key						int,
@username							char(10)
)
as
Update FormControlXProfitCenter set
	status			= @status,
	preappr_key		= @preappr_key,
	modified_by		= @username,
	date_modified	= GETDATE()
Where
	form_id = @form_id
	and revision_id = @revision_id
	and company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
set nocount off


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormControlXProfitCenter_Update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormControlXProfitCenter_Update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_FormControlXProfitCenter_Update] TO [EQAI]
    AS [dbo];

