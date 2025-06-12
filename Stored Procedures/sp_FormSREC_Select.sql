
--/************************************************************
--Procedure	: sp_FormSREC_Select
--Database	: PLT_AI*
--Created		: 5-10-2004 - Jonathan Broome
--Description	: Selects FormSREC records for the
--			  matching form_id + revision_id.
--************************************************************/
--Create Procedure sp_FormSREC_Select (
--@form_id							int,
--@revision_id						int,
--@group_id							int = NULL,
--@customer_id_from_form				int	= NULL,
--@customer_id						int	= NULL
--)
--as

--set nocount on

--declare
--	@selected_companies varchar(8000),
--	@tmpform_id int,
--	@tmprevision_id int

--set @tmpform_id = @form_id
--set @tmprevision_id = @revision_id

--if datalength(@form_id) = 0
--begin
--	set rowcount 1
--	select
--		@tmpform_id = form_id,
--		@tmprevision_id = revision_id
--		from FormLDR
--		where
--			(form_id = @form_id and revision_id = @revision_id)
--			or (group_id = @group_id and @group_id is not null)
--		order by form_id desc
--	set rowcount 0
--end

--select @selected_companies = coalesce(@selected_companies + ',', '') +

--	right('00' + convert(varchar(2), company_id), 2) +
--	right('00' + convert(varchar(2), profit_ctr_id), 2)
--	from FormXProfitCenter
--	where
--		form_id = @tmpform_id
--		and revision_id = @tmprevision_id
--	order by
--		company_id, profit_ctr_id

--set nocount off

--select
--	form_id,
--	revision_id,
--	group_id,
--	customer_id_from_form,
--	customer_id,
--	@selected_companies as selected_companies,
--	form_version,
--	app_id,
--	status,
--	locked,
--	signed_pin,
--	signing_name,
--	signing_company,
--	signing_title,
--	signing_date,
--	date_created,
--	date_modified,
--	created_by,
--	modified_by,
--	exempt_reason,
--	waste_type,
--	waste_common_name,
--	qty_units,
--	manifest,
--	approval
--from FormSREC
--where
--	(customer_id_from_form = @customer_id_from_form or customer_id = @customer_id)
--	and
--	(
--	(form_id = @form_id and revision_id = @revision_id)
--	or 
--	(group_id = @group_id and @group_id is not null)
--	)

--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormSREC_Select] TO [EQWEB]
--    AS [dbo];
--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormSREC_Select] TO [COR_USER]
--    AS [dbo];



--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormSREC_Select] TO [EQAI]
--    AS [dbo];

