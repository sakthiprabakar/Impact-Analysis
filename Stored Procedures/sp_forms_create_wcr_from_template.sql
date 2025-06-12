-- drop proc sp_forms_create_wcr_from_template
go
CREATE PROCEDURE sp_forms_create_wcr_from_template(
	 @template_form_id			int,
	 @user	varchar(60)
)
AS
/****************
11/23/2011 CRG Created
sp_forms_create_wcr_from_template
Creates a new WCR from a given template
--sp_forms_create_wcr_from_template @template_form_id='221492', @user = 'jonathan'

SELECT  * FROM    FormWCRTemplate
*****************/
DECLARE @form_id int, @revision_id INT, @temp_form_id INT, @temp_rev_id INT, @temp_ldr_id INT, @ldr_form_id INT, @ntn_form_id INT

EXEC @form_id = sp_Sequence_Next 'Form.Form_ID'

EXEC @revision_id = sp_formsequence_next @form_id
	,0
	,@user
	

SELECT TOP (1) 
	@temp_form_id = form_ID
	,@temp_rev_id = revision_id
	FROM dbo.FormWCR wcr
	INNER JOIN dbo.FormWCRTemplate wcrt ON wcrt.template_form_id = wcr.form_id
	WHERE wcrt.template_form_id = @template_form_id
	ORDER BY wcr.revision_id desc

SELECT TOP(1) *
	INTO #tempWCR
	FROM dbo.FormWCR wcr
	WHERE wcr.form_id = @temp_form_id
		AND wcr.revision_id = @temp_rev_id

-- sp_columns formwcr

UPDATE #tempWCR 
	SET  form_id = @form_id 
		,revision_id = @revision_id
		,created_by = @user
		,modified_by = @user
		,date_created = GETDATE()
		,date_modified = GETDATE()
		,rowguid = NEWID()
		,copy_source = 'template'
		,source_form_id = @temp_form_id
		,source_revision_id = @temp_rev_id
		,template_form_id = @temp_form_id


	INSERT INTO FormWCR
	SELECT *
	FROM #tempWCR

DROP TABLE #tempWCR

--FormXConstituent
---------------------------

SELECT *
	INTO #tempFormXConstituent
FROM dbo.FormXConstituent
	WHERE form_id = @temp_form_id
		AND revision_id = @temp_rev_id
		
UPDATE #tempFormXConstituent 
	SET  form_id = @form_id 
		,revision_id = @revision_id

	INSERT INTO FormXConstituent
	(form_id
	, revision_id
	, page_number
	, line_item
	, const_id
	, const_desc
	, min_concentration
	, concentration
	, unit
	, uhc
	, specifier
	, TCLP_or_totals
	, typical_concentration
	, max_concentration
	, exceeds_LDR
	, requiring_treatment_flag
	)
	SELECT
		form_id
		, revision_id
		, page_number
		, line_item
		, const_id
		, const_desc
		, min_concentration
		, concentration
		, unit
		, uhc
		, specifier
		, TCLP_or_totals
		, typical_concentration
		, max_concentration
		, exceeds_LDR
		, requiring_treatment_flag
	FROM #tempFormXConstituent

DROP TABLE #tempFormXConstituent

--FormXUnit
---------------------------

SELECT *
	INTO #tempFormXUnit
FROM dbo.FormXUnit
	WHERE form_id = @temp_form_id
		AND revision_id = @temp_rev_id
		
UPDATE #tempFormXUnit
	SET  form_id = @form_id 
		,revision_id = @revision_id


	INSERT INTO FormXUnit
	(form_type
	, form_id
	, revision_id
	, bill_unit_code
	, quantity)
	SELECT 
	form_type
	, form_id
	, revision_id
	, bill_unit_code
	, quantity
	FROM #tempFormXUnit

DROP TABLE #tempFormXUnit

--FormXWasteCode
---------------------------
SELECT *
	INTO #tempFormXWasteCode
FROM dbo.FormXWasteCode
	WHERE form_id = @temp_form_id
		AND revision_id = @temp_rev_id
		
UPDATE #tempFormXWasteCode
	SET  form_id = @form_id 
		,revision_id = @revision_id

	INSERT INTO FormXWasteCode
	(form_id
	, revision_id
	, page_number
	, line_item
	, waste_code_uid
	, waste_code
	, specifier
	, lock_flag)
	SELECT 
	form_id
	, revision_id
	, page_number
	, line_item
	, waste_code_uid
	, waste_code
	, specifier
	, lock_flag
	FROM #tempFormXWasteCode

DROP TABLE #tempFormXWasteCode

--FormXWCRComposition
---------------------------
SELECT *
	INTO #tempFormXWCRComposition
FROM dbo.FormXWCRComposition
	WHERE form_id = @temp_form_id
		AND revision_id = @temp_rev_id
		
UPDATE #tempFormXWCRComposition
	SET  form_id = @form_id 
		,revision_id = @revision_id
		,rowguid = newID()
		
	INSERT INTO FormXWCRComposition
	(form_id
	, revision_id
	, comp_description
	, comp_from_pct
	, comp_to_pct
	, rowguid
	, unit
	, sequence_id
	, comp_typical_pct)
	SELECT 
	form_id
	, revision_id
	, comp_description
	, comp_from_pct
	, comp_to_pct
	, rowguid
	, unit
	, sequence_id
	, comp_typical_pct
	FROM #tempFormXWCRComposition

DROP TABLE #tempFormXWCRComposition

--FormLDR
---------------------------
SELECT *
	INTO #tempFormLDR
FROM dbo.FormLDR
	WHERE wcr_id = @temp_form_id
		AND wcr_rev_id = @temp_rev_id

if @@rowcount > 0 begin		
	SELECT @temp_ldr_id = form_id
	FROM dbo.FormLDR
		WHERE wcr_id = @temp_form_id
			AND wcr_rev_id = @temp_rev_id

	EXEC @ldr_form_id = sp_Sequence_Next 'Form.Form_ID'
		
	UPDATE #tempFormLDR
		SET  form_id = @ldr_form_id 
			,revision_id = @revision_id
			,wcr_id = @form_id
			,wcr_rev_id = @revision_id
			,rowguid = newID()


	INSERT INTO FormLDR
	(form_id
	, revision_id
	, form_version_id
	, customer_id_from_form
	, customer_id
	, app_id
	, status
	, locked
	, source
	, company_id
	, profit_ctr_id
	, signing_name
	, signing_company
	, signing_title
	, signing_date
	, date_created
	, date_modified
	, created_by
	, modified_by
	, generator_name
	, generator_epa_id
	, generator_address1
	, generator_city
	, generator_state
	, generator_zip
	, state_manifest_no
	, manifest_doc_no
	, generator_id
	, generator_address2
	, generator_address3
	, generator_address4
	, generator_address5
	, profitcenter_epa_id
	, profitcenter_profit_ctr_name
	, profitcenter_address_1
	, profitcenter_address_2
	, profitcenter_address_3
	, profitcenter_phone
	, profitcenter_fax
	, rowguid
	, wcr_id
	, wcr_rev_id
	, ldr_notification_frequency
	, waste_managed_id)
		SELECT 
		form_id
		, revision_id
		, form_version_id
		, customer_id_from_form
		, customer_id
		, app_id
		, status
		, locked
		, source
		, company_id
		, profit_ctr_id
		, signing_name
		, signing_company
		, signing_title
		, signing_date
		, date_created
		, date_modified
		, created_by
		, modified_by
		, generator_name
		, generator_epa_id
		, generator_address1
		, generator_city
		, generator_state
		, generator_zip
		, state_manifest_no
		, manifest_doc_no
		, generator_id
		, generator_address2
		, generator_address3
		, generator_address4
		, generator_address5
		, profitcenter_epa_id
		, profitcenter_profit_ctr_name
		, profitcenter_address_1
		, profitcenter_address_2
		, profitcenter_address_3
		, profitcenter_phone
		, profitcenter_fax
		, rowguid
		, wcr_id
		, wcr_rev_id
		, ldr_notification_frequency
		, waste_managed_id
		FROM #tempFormLDR
end

DROP TABLE #tempFormLDR

--FormLDRDetail
---------------------------
SELECT *
	INTO #tempFormLDRDetail
FROM dbo.FormLDRDetail
	WHERE form_id = @temp_ldr_id
		AND revision_id = @temp_rev_id
	
UPDATE #tempFormLDRDetail
	SET  form_id = @ldr_form_id 
		,revision_id = @revision_id

	INSERT INTO FormLDRDetail
	(form_id
	, revision_id
	, form_version_id
	, page_number
	, manifest_line_item
	, ww_or_nww
	, subcategory
	, manage_id
	, approval_code
	, approval_key
	, company_id
	, profit_ctr_id
	, profile_id
	, constituents_requiring_treatment_flag)
	SELECT 
	form_id
	, revision_id
	, form_version_id
	, page_number
	, manifest_line_item
	, ww_or_nww
	, subcategory
	, manage_id
	, approval_code
	, approval_key
	, company_id
	, profit_ctr_id
	, profile_id
	, constituents_requiring_treatment_flag
	FROM #tempFormLDRDetail

DROP TABLE #tempFormLDRDetail

--FormNTN
---------------------------

SELECT *
	INTO #tempFormNORMTENORM
FROM dbo.FormNORMTENORM
	WHERE wcr_id = @temp_form_id
		AND wcr_rev_id = @temp_rev_id

if @@rowcount > 0 begin

	EXEC @ntn_form_id = sp_Sequence_Next 'Form.Form_ID'
		
	UPDATE #tempFormNORMTENORM
		SET  form_id = @ntn_form_id 
			,revision_id = @revision_id
			,wcr_id = @form_id
			,wcr_rev_id = @revision_id

		INSERT INTO FormNORMTENORM
		(form_id
		, revision_id
		, version_id
		, status
		, locked
		, source
		, company_id
		, profit_ctr_id
		, profile_id
		, approval_code
		, generator_id
		, generator_epa_id
		, generator_name
		, generator_address_1
		, generator_address_2
		, generator_address_3
		, generator_address_4
		, generator_address_5
		, generator_city
		, generator_state
		, generator_zip_code
		, site_name
		, gen_mail_addr1
		, gen_mail_addr2
		, gen_mail_addr3
		, gen_mail_addr4
		, gen_mail_addr5
		, gen_mail_city
		, gen_mail_state
		, gen_mail_zip
		, NORM
		, TENORM
		, disposal_restriction_exempt
		, nuclear_reg_state_license
		, waste_process
		, unit_other
		, shipping_dates
		, signing_name
		, signing_company
		, signing_title
		, signing_date
		, date_created
		, date_modified
		, created_by
		, modified_by
		, wcr_id
		, wcr_rev_id)
		SELECT 
		form_id
		, revision_id
		, version_id
		, status
		, locked
		, source
		, company_id
		, profit_ctr_id
		, profile_id
		, approval_code
		, generator_id
		, generator_epa_id
		, generator_name
		, generator_address_1
		, generator_address_2
		, generator_address_3
		, generator_address_4
		, generator_address_5
		, generator_city
		, generator_state
		, generator_zip_code
		, site_name
		, gen_mail_addr1
		, gen_mail_addr2
		, gen_mail_addr3
		, gen_mail_addr4
		, gen_mail_addr5
		, gen_mail_city
		, gen_mail_state
		, gen_mail_zip
		, NORM
		, TENORM
		, disposal_restriction_exempt
		, nuclear_reg_state_license
		, waste_process
		, unit_other
		, shipping_dates
		, signing_name
		, signing_company
		, signing_title
		, signing_date
		, date_created
		, date_modified
		, created_by
		, modified_by
		, wcr_id
		, wcr_rev_id
		FROM #tempFormNORMTENORM
end

DROP TABLE #tempFormNORMTENORM
  

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_create_wcr_from_template] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_create_wcr_from_template] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_create_wcr_from_template] TO [EQAI]
    AS [dbo];

