
--/************************************************************
--Procedure	: sp_FormGWA_Select
--Database	: PLT_AI*
--Created		: 5-10-2004 - Jonathan Broome
--Description	: Selects FormGWA records for the
--			  matching form_id + revision_id.
--12/16/2004 JPB Modified to return Generator_id and EPA_ID
--************************************************************/
--Create Procedure sp_FormGWA_Select (
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
--		from FormGWA
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
--	approval,
--	generator_name,
--	epa_id,
--	generator_id,
--	generator_address1,
--	cust_name,
--	cust_addr1,
--	inv_contact_name,
--	inv_contact_phone,
--	inv_contact_fax,
--	tech_contact_name,
--	tech_contact_phone,
--	tech_contact_fax,
--	waste_common_name,
--	waste_code_comment,
--	amendment
--from FormGWA
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
--    ON OBJECT::[dbo].[sp_FormGWA_Select] TO [EQWEB]
--    AS [dbo];
--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormGWA_Select] TO [COR_USER]
--    AS [dbo];



--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_FormGWA_Select] TO [EQAI]
--    AS [dbo];

