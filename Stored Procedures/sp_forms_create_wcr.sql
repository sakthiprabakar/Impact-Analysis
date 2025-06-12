
CREATE PROCEDURE sp_forms_create_wcr (
	@form_id INT = - 1
	,@revision_id INT = 0
	,@form_version_id INT = NULL
	,@customer_id_from_form INT = NULL
	,@customer_id INT = NULL
	,@app_id VARCHAR(20) = NULL
	,@tracking_id INT = NULL
	,@status CHAR(1)
	,@locked CHAR(1)
	,@source CHAR(1) = NULL
	,@signing_name VARCHAR(40) = NULL
	,@signing_company VARCHAR(40) = NULL
	,@signing_title VARCHAR(40) = NULL
	,@signing_date DATETIME = NULL
	,@tmpUser VARCHAR(60)
	,@comments VARCHAR(max) = NULL
	,@sample_id INT = NULL
	,@cust_name VARCHAR(75) = NULL
	,@cust_addr1 VARCHAR(75) = NULL
	,@cust_addr2 VARCHAR(75) = NULL
	,@cust_addr3 VARCHAR(75) = NULL
	,@cust_addr4 VARCHAR(75) = NULL
	,@cust_city VARCHAR(40) = NULL
	,@cust_state CHAR(2) = NULL
	,@cust_zip VARCHAR(10) = NULL
	,@cust_country VARCHAR(50) = NULL
	,@inv_contact_name VARCHAR(40) = NULL
	,@inv_contact_phone VARCHAR(20) = NULL
	,@inv_contact_fax VARCHAR(10) = NULL
	,@tech_contact_name VARCHAR(40) = NULL
	,@tech_contact_phone VARCHAR(20) = NULL
	,@tech_contact_fax VARCHAR(10) = NULL
	,@tech_contact_mobile VARCHAR(10) = NULL
	,@tech_contact_pager VARCHAR(10) = NULL
	,@tech_cont_email VARCHAR(50) = NULL
	,@generator_id INT = NULL
	,@EPA_ID VARCHAR(12) = NULL
	,@sic_code INT = NULL
	,@generator_name VARCHAR(75) = NULL
	,@generator_address1 VARCHAR(75) = NULL
	,@generator_address2 VARCHAR(75) = NULL
	,@generator_address3 VARCHAR(75) = NULL
	,@generator_address4 VARCHAR(75) = NULL
	,@generator_city VARCHAR(40) = NULL
	,@generator_state VARCHAR(40) = NULL
	,@generator_zip VARCHAR(10) = NULL
	,@generator_county_id INT = NULL
	,@generator_county_name VARCHAR(40) = NULL
	,@gen_mail_address1 VARCHAR(75) = NULL
	,@gen_mail_address2 VARCHAR(75) = NULL
	,@gen_mail_address3 VARCHAR(75) = NULL
	,@gen_mail_city VARCHAR(40) = NULL
	,@gen_mail_state CHAR(2) = NULL
	,@gen_mail_zip VARCHAR(10) = NULL
	,@generator_contact VARCHAR(40) = NULL
	,@generator_contact_title VARCHAR(20) = NULL
	,@generator_phone VARCHAR(20) = NULL
	,@generator_fax VARCHAR(10) = NULL
	,@waste_common_name VARCHAR(50) = NULL
	,@volume VARCHAR(100) = NULL
	,@frequency VARCHAR(20) = NULL
	,@dot_shipping_name VARCHAR(130) = NULL
	,@surcharge_exempt CHAR(1) = NULL
	,@pack_bulk_solid_yard CHAR(1) = NULL
	,@pack_bulk_solid_ton CHAR(1) = NULL
	,@pack_bulk_liquid CHAR(1) = NULL
	,@pack_totes CHAR(1) = NULL
	,@pack_totes_size VARCHAR(30) = NULL
	,@pack_cy_box CHAR(1) = NULL
	,@pack_drum CHAR(1) = NULL
	,@pack_other CHAR(1) = NULL
	,@pack_other_desc VARCHAR(15) = NULL
	,@color VARCHAR(25) = NULL
	,@odor VARCHAR(25) = NULL
	,@poc CHAR(1) = NULL
	,@consistency_solid CHAR(1) = NULL
	,@consistency_dust CHAR(1) = NULL
	,@consistency_liquid CHAR(1) = NULL
	,@consistency_sludge CHAR(1) = NULL
	,@consistency_varies CHAR(1) = NULL
	,@ph CHAR(10) = NULL
	,@ph_lte_2 CHAR(1) = NULL
	,@ph_gt_2_lt_5 CHAR(1) = NULL
	,@ph_gte_5_lte_10 CHAR(1) = NULL
	,@ph_gt_10_lt_12_5 CHAR(1) = NULL
	,@ph_gte_12_5 CHAR(1) = NULL
	,@ignitability VARCHAR(10) = NULL
	,@ignitability_lt_90 CHAR(1) = NULL
	,@ignitability_90_139 CHAR(1) = NULL
	,@ignitability_140_199 CHAR(1) = NULL
	,@ignitability_gte_200 CHAR(1) = NULL
	,@ignitability_NA CHAR(1) = NULL
	,@waste_contains_spec_hand_none CHAR(1) = NULL
	,@free_liquids CHAR(1) = NULL
	,@oily_residue CHAR(1) = NULL
	,@metal_fines CHAR(1) = NULL
	,@biodegradable_sorbents CHAR(1) = NULL
	,@amines CHAR(1) = NULL
	,@ammonia CHAR(1) = NULL
	,@dioxins CHAR(1) = NULL
	,@furans CHAR(1) = NULL
	,@biohazard CHAR(1) = NULL
	,@shock_sensitive_waste CHAR(1) = NULL
	,@reactive_waste CHAR(1) = NULL
	,@radioactive_waste CHAR(1) = NULL
	,@explosives CHAR(1) = NULL
	,@pyrophoric_waste CHAR(1) = NULL
	,@isocyanates CHAR(1) = NULL
	,@asbestos_friable CHAR(1) = NULL
	,@asbestos_non_friable CHAR(1) = NULL
	,@gen_process VARCHAR(max) = NULL
	,@rcra_listed CHAR(1) = NULL
	,@rcra_listed_comment VARCHAR(max) = NULL
	,@rcra_characteristic CHAR(1) = NULL
	,@rcra_characteristic_comment VARCHAR(max) = NULL
	,@state_waste_code_flag CHAR(1) = NULL
	,@state_waste_code_flag_comment VARCHAR(max) = NULL
	,@wastewater_treatment CHAR(1) = NULL
	,@exceed_ldr_standards CHAR(1) = NULL
	,@meets_alt_soil_treatment_stds CHAR(1) = NULL
	,@more_than_50_pct_debris CHAR(1) = NULL
	,@oxidizer CHAR(1) = NULL
	,@react_cyanide CHAR(1) = NULL
	,@react_sulfide CHAR(1) = NULL
	,@info_basis_knowledge CHAR(1) = NULL
	,@info_basis_analysis CHAR(1) = NULL
	,@info_basis_msds CHAR(1) = NULL
	,@air_reactive CHAR(1) = NULL
	,@underlying_haz_constituents CHAR(1) = NULL
	,@michigan_non_haz CHAR(1) = NULL
	,@michigan_non_haz_comment VARCHAR(max) = NULL
	,@universal_recyclable_commodity CHAR(4) = NULL
	,@recoverable_petroleum_product CHAR(1) = NULL
	,@used_oil CHAR(1) = NULL
	,@pcb_concentration_none CHAR(1) = NULL
	,@pcb_concentration_0_49 CHAR(1) = NULL
	,@pcb_concentration_50_499 CHAR(1) = NULL
	,@pcb_concentration_500 CHAR(1) = NULL
	,@pcb_source_concentration_gr_50 CHAR(1) = NULL
	,@processed_into_non_liquid CHAR(1) = NULL
	,@processd_into_nonlqd_prior_pcb VARCHAR(10) = NULL
	,@pcb_non_lqd_contaminated_media VARCHAR(1) = NULL
	,@pcb_manufacturer CHAR(1) = NULL
	,@pcb_article_decontaminated CHAR(1) = NULL
	,@ccvocgr500 CHAR(1) = NULL
	,@benzene CHAR(1) = NULL
	,@neshap_sic CHAR(1) = NULL
	,@tab_gr_10 CHAR(1) = NULL
	,@avg_h20_gr_10 CHAR(1) = NULL
	,@tab FLOAT = NULL
	,@benzene_gr_1 CHAR(1) = NULL
	,@benzene_concentration FLOAT = NULL
	,@benzene_unit VARCHAR(10) = NULL
	,@fuel_blending CHAR(1) = NULL
	,@btu_per_lb CHAR(10) = NULL
	,@pct_chlorides CHAR(10) = NULL
	,@pct_moisture CHAR(10) = NULL
	,@pct_solids CHAR(10) = NULL
	,@intended_for_reclamation CHAR(1) = NULL
	,@pack_drum_size VARCHAR(30) = NULL
	,@water_reactive CHAR(1) = NULL
	,@aluminum CHAR(1) = NULL
	,@subject_to_mact_neshap CHAR(1) = NULL
	,@subject_to_mact_neshap_codes VARCHAR(100) = NULL
	,@srec_exempt_id INT = NULL
	,@ldr_ww_or_nww CHAR(3) = NULL
	,@ldr_subcategory VARCHAR(100) = NULL
	,@ldr_manage_id INT = NULL
	,@profile_id INT = NULL
	,@hazmat_flag CHAR(1) = NULL
	,@hazmat_class VARCHAR(15) = NULL
	,@subsidiary_haz_mat_class VARCHAR(15) = NULL
	,@package_group VARCHAR(3) = NULL
	,@un_na_flag CHAR(2) = NULL
	,@un_na_number INT = NULL
	,@manifest_dot_sp_number VARCHAR(20) = NULL
	,@reportable_quantity_flag CHAR(1) = NULL
	,@RQ_reason VARCHAR(50) = NULL
	-- ,@reportable_quantity FLOAT = NULL
	,@EPA_source_code VARCHAR(10) = NULL
	,@EPA_form_code VARCHAR(10) = NULL
	,@handling_issue CHAR(1) = NULL
	,@handling_issue_desc VARCHAR(100) = NULL
	,@emergency_phone_number VARCHAR(10) = NULL
	,@generator_email VARCHAR(60) = NULL
	,@waste_water_flag CHAR(1) = NULL
	,@debris_dimension_weight VARCHAR(max) = NULL
	,@RCRA_exempt_flag CHAR(1) = NULL
	,@RCRA_exempt_reason VARCHAR(255) = NULL
	,@consistency_debris CHAR(1) = NULL
	,@consistency_gas_aerosol CHAR(1) = NULL
	,@temp_ctrl_org_peroxide CHAR(1) = NULL
/* - 11/6/12 - JPB, removed these to use older @odor field instead:
	,@odor_none CHAR(1) = NULL
	,@odor_ammonia CHAR(1) = NULL
	,@odor_amines CHAR(1) = NULL
	,@odor_mercaptans CHAR(1) = NULL
	,@odor_sulfur CHAR(1) = NULL
	,@odor_organic_acid CHAR(1) = NULL
	,@odor_other CHAR(1) = NULL
*/
	,@odor_other_desc VARCHAR(50) = NULL
	,@pH_NA CHAR(1) = NULL
	,@ddvohapgr500 CHAR(1) = NULL
	,@cyanide_plating CHAR(1) = NULL
	,@frequency_other VARCHAR(20) = NULL
	,@dot_shipping_desc VARCHAR(255) = NULL
	,@neshap_Chem_1 VARCHAR(255) = NULL
	,@neshap_Chem_2 VARCHAR(255) = NULL
	,@neshap_standards_part INT = NULL
	,@neshap_Subpart VARCHAR(255) = NULL
	,@Benzene_Onsite_Mgmt CHAR(1) = NULL
	,@Benzene_Onsite_Mgmt_desc VARCHAR(255) = NULL
	-- ,@flammable CHAR(1) = NULL
	,@wwa_halogen_gt_1000 CHAR(1) = NULL
	,@wwa_halogen_source CHAR(10) = NULL
	,@wwa_halogen_source_desc1 VARCHAR(100) = NULL
	,@wwa_other_desc_1 VARCHAR(100) = NULL
	,@erg_code VARCHAR(10) = NULL
	,@erg_number INT = NULL
	,@source_form_id INT = NULL
	,@source_revision_id INT = NULL
	,@template_form_id INT = NULL
	--srec
	,@srec_date_of_disposal varchar(255) = NULL
	,@srec_volume varchar(255) = NULL
	--,@srec_exempt_id int = NULL already existed?
	,@srec_flag char(1) = NULL
	--waste codes
	,@epa_rcra_listed_waste_codes VARCHAR(MAX) = NULL
	,@epa_rcra_characteristic_waste_codes VARCHAR(MAX) = NULL
	,@state_specific_hazardous_waste_codes VARCHAR(MAX) = NULL
	,@state_specific_non_hazardous_waste_codes VARCHAR(MAX) = NULL --NORM/TENORM
	,@epa_rcra_listed_waste_codes_ids VARCHAR(MAX) = NULL
	,@epa_rcra_characteristic_waste_codes_ids VARCHAR(MAX) = NULL
	,@state_specific_hazardous_waste_codes_ids VARCHAR(MAX) = NULL
	,@state_specific_non_hazardous_waste_codes_ids VARCHAR(MAX) = NULL --NORM/TENORM
	,@NORM CHAR(1) = NULL --[NORM]
	,@TENORM CHAR(1) = NULL --[TENORM]
	,@disposal_restriction_exempt CHAR(1) = NULL --[disposal_restriction_exempt]
	,@nuclear_reg_state_license CHAR(1) = NULL
	,@shipping_dates varchar(255) = NULL
	,@inv_contact_id int = NULL
	,@tech_contact_id int = NULL
	,@generator_contact_id int = NULL
	,@facility_instruction varChar(255) = NULL
	)
	
AS
/****************************************************************
-- 11/23/2011 Created
-- sp_forms_create_wcr
-- Called when adding a new WCR or editing an old wcr from the web.



2013-01-31 - JPB - Changed @handling_issue_desc from varchar(max) to varchar(100) to match EQAI
2013-04-08 - JPB - Changed FormWCR.Volume length from 20 to 100
2013-11-06 - JPB - Renamed RCRA_ haz_ flag to RCRA_exempt_flag
11/08/2013	JPB	Added wcr.manifest_dot_sp_number
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

*****************************************************************/

BEGIN TRANSACTION

--If customer id is set, update customer id from form
IF (
		@customer_id_from_form IS NULL
		AND @customer_id IS NOT NULL
		)
BEGIN
	SET @customer_id_from_form = @customer_id
	If @@error <> 0 goto ERR_HANDLER
END

--break erg code into erg # and suffix
DECLARE @TMPerg_number INT = NULL
	,@TMPerg_suffix CHAR(1) = NULL

if @erg_number is not null
	set @TMPerg_number = @erg_number

IF @erg_code IS NOT NULL
BEGIN
	IF LEN(@erg_code) > 3
	BEGIN
		SET @TMPerg_suffix = (
				SELECT RIGHT(@erg_code, 1) AS erg_suffix
			)
		If @@error <> 0 goto ERR_HANDLER
	END

	SET @TMPerg_number = (
			SELECT CAST(CAST(@erg_code AS VARCHAR(3)) AS INT)
		)
	If @@error <> 0 goto ERR_HANDLER
END

--Get form and revision id's
IF @form_id = - 1
BEGIN --get form id (if not a revision)
	EXEC @form_id = sp_Sequence_Next 'Form.Form_ID'
	If @@error <> 0 goto ERR_HANDLER
END
ELSE
BEGIN
	SELECT @form_id AS form_id
	If @@error <> 0 goto ERR_HANDLER
END

EXEC @revision_id = sp_formsequence_next @form_id
	,@revision_id
	,@tmpUser
If @@error <> 0 goto ERR_HANDLER

--If this revision already exists, save the current data and dont delete it until we know this save succeded
IF EXISTS(SELECT * FROM FormWCR where form_id = @form_id AND revision_id = @revision_id)
BEGIN
	DELETE FROM FormWCR WHERE form_id = @form_id AND revision_id = @revision_ID
	DELETE FROM FormNORMTENORM WHERE wcr_id = @form_id AND wcr_rev_id = @revision_ID
	DELETE FROM FormLDR WHERE wcr_id = @form_id AND wcr_rev_id = @revision_ID
	DELETE FROM FormXUnit WHERE form_id = @form_id AND revision_id = @revision_ID
	DELETE FROM FormXConstituent WHERE form_id = @form_id AND revision_id = @revision_ID
	DELETE FROM FormXWCRComposition WHERE form_id = @form_id AND revision_id = @revision_ID
	DELETE FROM FormXWasteCode WHERE form_id = @form_id AND revision_id = @revision_ID
END

INSERT INTO [dbo].[FormWCR] (
	[form_id]
	,[revision_id]
	,[form_version_id]
	,[customer_id_from_form]
	,[customer_id]
	,[app_id]
	,[tracking_id]
	,[status]
	,[locked]
	,[source]
	,[signing_name]
	,[signing_company]
	,[signing_title]
	,[signing_date]
	,[date_created]
	,[date_modified]
	,[created_by]
	,[modified_by]
	,[comments]
	,[sample_id]
	,[cust_name]
	,[cust_addr1]
	,[cust_addr2]
	,[cust_addr3]
	,[cust_addr4]
	,[cust_city]
	,[cust_state]
	,[cust_zip]
	,[cust_country]
	,[inv_contact_name]
	,[inv_contact_phone]
	,[inv_contact_fax]
	,[tech_contact_name]
	,[tech_contact_phone]
	,[tech_contact_fax]
	,[tech_contact_mobile]
	,[tech_contact_pager]
	,[tech_cont_email]
	,[generator_id]
	,[EPA_ID]
	,[sic_code]
	,[generator_name]
	,[generator_address1]
	,[generator_address2]
	,[generator_address3]
	,[generator_address4]
	,[generator_city]
	,[generator_state]
	,[generator_zip]
	,[generator_county_id]
	,[generator_county_name]
	,[gen_mail_address1]
	,[gen_mail_address2]
	,[gen_mail_address3]
	,[gen_mail_city]
	,[gen_mail_state]
	,[gen_mail_zip]
	,[generator_contact]
	,[generator_contact_title]
	,[generator_phone]
	,[generator_fax]
	,[waste_common_name]
	,[volume]
	,[frequency]
	,[dot_shipping_name]
	,[surcharge_exempt]
	,[pack_bulk_solid_yard]
	,[pack_bulk_solid_ton]
	,[pack_bulk_liquid]
	,[pack_totes]
	,[pack_totes_size]
	,[pack_cy_box]
	,[pack_drum]
	,[pack_other]
	,[pack_other_desc]
	,[color]
	,[odor]
	,[poc]
	,[consistency_solid]
	,[consistency_dust]
	,[consistency_liquid]
	,[consistency_sludge]
	,[ph]
	,[ph_lte_2]
	,[ph_gt_2_lt_5]
	,[ph_gte_5_lte_10]
	,[ph_gt_10_lt_12_5]
	,[ph_gte_12_5]
	,[ignitability]
	,[ignitability_lt_90]
	,[ignitability_90_139]
	,[ignitability_140_199]
	,[ignitability_gte_200]
	,[ignitability_NA]
	,[waste_contains_spec_hand_none]
	,[free_liquids]
	,[oily_residue]
	,[metal_fines]
	,[biodegradable_sorbents]
	,[amines]
	,[ammonia]
	,[dioxins]
	,[furans]
	,[biohazard]
	,[shock_sensitive_waste]
	,[reactive_waste]
	,[radioactive_waste]
	,[explosives]
	,[pyrophoric_waste]
	,[isocyanates]
	,[asbestos_friable]
	,[asbestos_non_friable]
	,[gen_process]
	,[rcra_listed]
	,[rcra_listed_comment]
	,[rcra_characteristic]
	,[rcra_characteristic_comment]
	,[state_waste_code_flag]
	,[state_waste_code_flag_comment]
	,[wastewater_treatment]
	,[exceed_ldr_standards]
	,[meets_alt_soil_treatment_stds]
	,[more_than_50_pct_debris]
	,[oxidizer]
	,[react_cyanide]
	,[react_sulfide]
	,[info_basis_knowledge]
	,[info_basis_analysis]
	,[info_basis_msds]
	,[underlying_haz_constituents]
	,[michigan_non_haz]
	,[michigan_non_haz_comment]
	,[universal_recyclable_commodity]
	,[recoverable_petroleum_product]
	,[used_oil]
	,[pcb_concentration_none]
	,[pcb_concentration_0_49]
	,[pcb_concentration_50_499]
	,[pcb_concentration_500]
	,[pcb_source_concentration_gr_50]
	,[processed_into_non_liquid]
	,[processd_into_nonlqd_prior_pcb]
	,[pcb_non_lqd_contaminated_media]
	,[pcb_manufacturer]
	,[pcb_article_decontaminated]
	,[ccvocgr500]
	,[benzene]
	,[neshap_sic]
	,[tab_gr_10]
	,[avg_h20_gr_10]
	,[tab]
	,[benzene_gr_1]
	,[benzene_concentration]
	,[benzene_unit]
	,[fuel_blending]
	,[btu_per_lb]
	,[pct_chlorides]
	,[pct_moisture]
	,[pct_solids]
	,[intended_for_reclamation]
	,[pack_drum_size]
	,[water_reactive]
	,[aluminum]
	,[subject_to_mact_neshap]
	,[subject_to_mact_neshap_codes]
	,[srec_exempt_id]
	,[ldr_ww_or_nww]
	,[ldr_subcategory]
	,[ldr_manage_id]
	,[rowguid]
	,[profile_id]
	,[emergency_phone_number]
	,[generator_email]
	,[frequency_other]
	,[hazmat_flag]
	,[hazmat_class]
	,[subsidiary_haz_mat_class]
	,[package_group]
	,[un_na_flag]
	,[un_na_number]
	,[manifest_dot_sp_number]
	,[dot_shipping_desc]
	,[reportable_quantity_flag]
	,[RQ_reason]
	-- ,[reportable_quantity]
/*	
	,[odor_none]
	,[odor_ammonia]
	,[odor_amines]
	,[odor_mercaptans]
	,[odor_sulfur]
	,[odor_organic_acid]
	,[odor_other]
*/	
	,[odor_other_desc]
	,[consistency_debris]
	,[consistency_gas_aerosol]
	,[pH_NA]
	,[air_reactive]
	,[temp_ctrl_org_peroxide]
	,[handling_issue]
	,[handling_issue_desc]
	,[RCRA_exempt_flag]
	,[RCRA_exempt_reason]
	,[cyanide_plating]
	,[EPA_source_code]
	,[EPA_form_code]
	,[waste_water_flag]
	,[debris_dimension_weight]
	-- ,[flammable]
	,[ddvohapgr500]
	,[neshap_Chem_1]
	,[neshap_Chem_2]
	,[neshap_standards_part]
	,[neshap_Subpart]
	,[Benzene_Onsite_Mgmt]
	,[Benzene_Onsite_Mgmt_desc]
	,[wwa_halogen_gt_1000]
	,[wwa_halogen_source]
	,[wwa_halogen_source_desc1]
	,[wwa_other_desc_1]
	,[erg_number]
	,[erg_suffix]
	,[NORM]
	,[TENORM]
	,[consistency_varies]
	,[inv_contact_id]
	,[tech_contact_id]
	,[generator_contact_id]
	,[facility_instruction]
	,[source_form_id]
	,[source_revision_id]
	,[template_form_id]
	)
VALUES (
	@form_id --[form_id]
	,@revision_id --[revision_id]
	,(SELECT current_form_version FROM dbo.FormType WHERE form_type = 'wcr') --[form_version_id]
	,@customer_id_from_form --[customer_id_from_form]
	,@customer_id --[customer_id]
	,@app_id --[app_id]
	,@tracking_id --[tracking_id]
	,@status --[status]
	,@locked --[locked]
	,@source --[source]
	,NULL --[signing_name]
	,NULL --[signing_company]
	,NULL --[signing_title]
	,NULL --[signing_date]
	,getdate() --[date_created]
	,getdate() --[date_modified]
	,@tmpUser --[created_by]
	,@tmpUser --[modified_by]
	,@comments --[comments]
	,@sample_id --[sample_id]
	,@cust_name --[cust_name]
	,@cust_addr1 --[cust_addr1]
	,@cust_addr2 --[cust_addr2]
	,@cust_addr3 --[cust_addr3]
	,@cust_addr4 --[cust_addr4]
	,@cust_city --[cust_city]
	,@cust_state --[cust_state]
	,@cust_zip --[cust_zip]
	,@cust_country --[cust_country]
	,@inv_contact_name --[inv_contact_name]
	,@inv_contact_phone --[inv_contact_phone]
	,@inv_contact_fax --[inv_contact_fax]
	,@tech_contact_name --[tech_contact_name]
	,@tech_contact_phone --[tech_contact_phone]
	,@tech_contact_fax --[tech_contact_fax]
	,@tech_contact_mobile --[tech_contact_mobile]
	,@tech_contact_pager --[tech_contact_pager]
	,@tech_cont_email --[tech_cont_email]
	,@generator_id --[generator_id]
	,@EPA_ID --[EPA_ID]
	,@sic_code --[sic_code]
	,@generator_name --[generator_name]
	,@generator_address1 --[generator_address1]
	,@generator_address2 --[generator_address2]
	,@generator_address3 --[generator_address3]
	,@generator_address4 --[generator_address4]
	,@generator_city --[generator_city]
	,@generator_state --[generator_state]
	,@generator_zip --[generator_zip]
	,@generator_county_id --[generator_county_id]
	,@generator_county_name --[generator_county_name]
	,@gen_mail_address1 --[gen_mail_address1]
	,@gen_mail_address2 --[gen_mail_address2]
	,@gen_mail_address3 --[gen_mail_address3]
	,@gen_mail_city --[gen_mail_city]
	,@gen_mail_state --[gen_mail_state]
	,@gen_mail_zip --[gen_mail_zip]
	,@generator_contact --[generator_contact]
	,@generator_contact_title --[generator_contact_title]
	,@generator_phone --[generator_phone]
	,@generator_fax --[generator_fax]
	,@waste_common_name --[waste_common_name]
	,@volume --[volume]
	,@frequency --[frequency]
	,@dot_shipping_name --[dot_shipping_name]
	,@surcharge_exempt --[surcharge_exempt]
	,@pack_bulk_solid_yard --[pack_bulk_solid_yard]
	,@pack_bulk_solid_ton --[pack_bulk_solid_ton]
	,@pack_bulk_liquid --[pack_bulk_liquid]
	,@pack_totes --[pack_totes]
	,@pack_totes_size --[pack_totes_size]
	,@pack_cy_box --[pack_cy_box]
	,@pack_drum --[pack_drum]
	,@pack_other --[pack_other]
	,@pack_other_desc --[pack_other_desc]
	,@color --[color]
	,@odor --[odor]
	,@poc --[poc]
	,@consistency_solid --[consistency_solid]
	,@consistency_dust --[consistency_dust]
	,@consistency_liquid --[consistency_liquid]
	,@consistency_sludge --[consistency_sludge]
	,@ph --[ph]
	,@ph_lte_2 --[ph_lte_2]
	,@ph_gt_2_lt_5 --[ph_gt_2_lt_5]
	,@ph_gte_5_lte_10 --[ph_gte_5_lte_10]
	,@ph_gt_10_lt_12_5 --[ph_gt_10_lt_12_5]
	,@ph_gte_12_5 --[ph_gte_12_5]
	,@ignitability --[ignitability]
	,@ignitability_lt_90 --[ignitability_lt_90]      
	,@ignitability_90_139 --[ignitability_90_139]   
	,@ignitability_140_199 --[ignitability_140_199]
	,@ignitability_gte_200 --[ignitability_gte_200]
	,@ignitability_NA --[ignitability_NA]
	,@waste_contains_spec_hand_none --[waste_contains_spec_hand_none]
	,@free_liquids --[free_liquids]
	,@oily_residue --[oily_residue]
	,@metal_fines --[metal_fines]
	,@biodegradable_sorbents --[biodegradable_sorbents]
	,@amines --[amines]
	,@ammonia --[ammonia]
	,@dioxins --[dioxins]
	,@furans --[furans]
	,@biohazard --[biohazard]
	,@shock_sensitive_waste --[shock_sensitive_waste]
	,@reactive_waste --[reactive_waste]
	,@radioactive_waste --[radioactive_waste]
	,@explosives --[explosives]
	,@pyrophoric_waste --[pyrophoric_waste]
	,@isocyanates --[isocyanates]
	,@asbestos_friable --[asbestos_friable]
	,@asbestos_non_friable --[asbestos_non_friable]
	,@gen_process --[gen_process]
	,@rcra_listed --[rcra_listed]
	,@rcra_listed_comment --[rcra_listed_comment]
	,@rcra_characteristic --[rcra_characteristic]
	,@rcra_characteristic_comment --[rcra_characteristic_comment]
	,@state_waste_code_flag --[state_waste_code_flag]
	,@state_waste_code_flag_comment --[state_waste_code_flag_comment]
	,@wastewater_treatment --[wastewater_treatment]
	,@exceed_ldr_standards --[exceed_ldr_standards]
	,@meets_alt_soil_treatment_stds --[meets_alt_soil_treatment_stds]
	,@more_than_50_pct_debris --[more_than_50_pct_debris]
	,@oxidizer --[oxidizer]
	,@react_cyanide --[react_cyanide]
	,@react_sulfide --[react_sulfide]
	,@info_basis_knowledge
	,@info_basis_analysis
	,@info_basis_msds
	,@underlying_haz_constituents --[underlying_haz_constituents]
	,@michigan_non_haz --[michigan_non_haz]
	,@michigan_non_haz_comment --[michigan_non_haz_comment]
	,@universal_recyclable_commodity
	,@recoverable_petroleum_product --[recoverable_petroleum_product]
	,@used_oil --[used_oil]
	,@pcb_concentration_none
	,@pcb_concentration_0_49
	,@pcb_concentration_50_499
	,@pcb_concentration_500
	,@pcb_source_concentration_gr_50 --[pcb_source_concentration_gr_50]
	,@processed_into_non_liquid --[processed_into_non_liquid]
	,@processd_into_nonlqd_prior_pcb --[processd_into_nonlqd_prior_pcb]
	,@pcb_non_lqd_contaminated_media --[pcb_non_lqd_contaminated_media]
	,@pcb_manufacturer --[pcb_manufacturer]
	,@pcb_article_decontaminated --[pcb_article_decontaminated]
	,@ccvocgr500 --[ccvocgr500]
	,@benzene --[benzene]
	,@neshap_sic --[neshap_sic]
	,@tab_gr_10 --[tab_gr_10]
	,@avg_h20_gr_10 --[avg_h20_gr_10]
	,@tab --[tab]
	,@benzene_gr_1 --[benzene_gr_1]
	,@benzene_concentration --[benzene_concentration]
	,@benzene_unit --[benzene_unit]
	,@fuel_blending --[fuel_blending]
	,@btu_per_lb --[btu_per_lb]
	,@pct_chlorides --[pct_chlorides]
	,@pct_moisture --[pct_moisture]
	,@pct_solids --[pct_solids]
	,@intended_for_reclamation --[intended_for_reclamation]
	,@pack_drum_size --[pack_drum_size]
	,@water_reactive --[water_reactive]
	,@aluminum --[aluminum]
	,@subject_to_mact_neshap --[subject_to_mact_neshap]
	,@subject_to_mact_neshap_codes --[subject_to_mact_neshap_codes]
	,@srec_exempt_id --[srec_exempt_id]
	,@ldr_ww_or_nww --[ldr_ww_or_nww]
	,@ldr_subcategory --[ldr_subcategory]
	,@ldr_manage_id --[ldr_manage_id]
	,newid() --[rowguid]
	,@profile_id --[profile_id]
	,@emergency_phone_number --[emergency_phone_number]
	,@generator_email --[generator_email]
	,@frequency_other --[frequency_other]
	,@hazmat_flag --[hazmat_flag]
	,@hazmat_class --[hazmat_class]
	,@subsidiary_haz_mat_class --[subsidiary_haz_mat_class]
	,@package_group --[package_group]
	,@un_na_flag --[un_na_flag]
	,@un_na_number --[un_na_number]
	,@manifest_dot_sp_number
	,@dot_shipping_desc --[dot_shipping_desc]
	,@reportable_quantity_flag --[reportable_quantity_flag]
	,@RQ_reason --[RQ_reason]
	-- ,@reportable_quantity --[reportable_quantity]
/*	
	,@odor_none --[odor_none]
	,@odor_ammonia --[odor_ammonia]
	,@odor_amines --[odor_amines]
	,@odor_mercaptans --[odor_mercaptans]
	,@odor_sulfur --[odor_sulfur]
	,@odor_organic_acid --[odor_orgnaic_acid]
	,@odor_other --[odor_other]
*/	
	,@odor_other_desc --[odor_other_desc]
	,@consistency_debris --[consistency_debris]
	,@consistency_gas_aerosol --[consistency_gas_aerosol]
	,@pH_NA --[pH_NA]
	,@air_reactive --[air_reactive]
	,@temp_ctrl_org_peroxide --[temp_ctrl_org_peroxide]
	,@handling_issue --[handling_issue]
	,@handling_issue_desc --[handling_issue_desc]
	,@RCRA_exempt_flag --[RCRA_exempt_flag]
	,@RCRA_exempt_reason --[RCRA_exempt_reason]
	,@cyanide_plating --[cyanide_plating]
	,@EPA_source_code --[EPA_source_code]
	,@EPA_form_code --[EPA_form_code]
	,@waste_water_flag --[waste_water_flag]
	,@debris_dimension_weight --[debris_dimension_weight]
	-- ,@flammable --[flammable]
	,@ddvohapgr500 --[ddvohapgr500]
	,@neshap_Chem_1 --[Chem_1]
	,@neshap_Chem_2 --[Chem_2]
	,@neshap_standards_part
	,@neshap_Subpart --[Subpart]
	,@Benzene_Onsite_Mgmt --[Benzene_Onsite_Mgmt]
	,@Benzene_Onsite_Mgmt_desc --[Benzene_Onsite_Mgmt_desc]
	,@wwa_halogen_gt_1000 -- [wwa_halogen_gt_1000]
	,@wwa_halogen_source -- [wwa_halogen_source]
	,@wwa_halogen_source_desc1 -- [wwa_halogen_source_desc1]
	,@wwa_other_desc_1 -- [@wwa_other_desc_1]
	,@TMPerg_number
	,@TMPerg_suffix
	,@NORM
	,@TENORM
	,@consistency_varies
	,@inv_contact_id 
	,@tech_contact_id
	,@generator_contact_id 
	,@facility_instruction
	,@source_form_id
	,@source_revision_id
	,@template_form_id
	)
If @@error <> 0 goto ERR_HANDLER

IF (
		@ldr_ww_or_nww IS NOT NULL
		OR @ldr_subcategory IS NOT NULL
		OR @ldr_manage_id IS NOT NULL
	)
BEGIN
	DECLARE @ldr_form_id INT

	SET @ldr_form_id = (
			SELECT TOP 1 form_id
			FROM FormLDR
			WHERE FormLDR.wcr_id = @form_id
			)
	If @@error <> 0 goto ERR_HANDLER
	
	IF (@ldr_form_id IS NULL)
	BEGIN
		EXEC @ldr_form_id = sp_Sequence_Next 'Form.Form_ID'
		If @@error <> 0 goto ERR_HANDLER
	END
	
	--insert into ldr table
	INSERT INTO [dbo].[FormLDR] (
		[form_id]
		,[revision_id]
		,[form_version_id]
		,[customer_id_from_form]
		,[customer_id]
		,[app_id]
		,[status]
		,[locked]
		,[source]
		,[company_id]
		,[profit_ctr_id]
		,[signing_name]
		,[signing_company]
		,[signing_title]
		,[signing_date]
		,[date_created]
		,[date_modified]
		,[created_by]
		,[modified_by]
		,[generator_name]
		,[generator_epa_id]
		,[generator_address1]
		,[generator_city]
		,[generator_state]
		,[generator_zip]
		,[state_manifest_no]
		,[manifest_doc_no]
		,[generator_id]
		,[generator_address2]
		,[generator_address3]
		,[generator_address4]
		,[generator_address5]
		,[profitcenter_epa_id]
		,[profitcenter_profit_ctr_name]
		,[profitcenter_address_1]
		,[profitcenter_address_2]
		,[profitcenter_address_3]
		,[profitcenter_phone]
		,[profitcenter_fax]
		,[rowguid]
		,[wcr_id]
		,[wcr_rev_id]
		)
	VALUES (
		@ldr_form_id
		,@revision_id
		,2 --form version
		,@customer_id_from_form
		,@customer_id
		,@app_id
		,'A'
		,'U'
		,'A'
		,NULL
		,NULL
		,@signing_name
		,@signing_company
		,@signing_title
		,@signing_date
		,getdate()
		,getdate()
		,@tmpUser
		,@tmpUser
		,@generator_name
		,@EPA_ID
		,@generator_address1
		,@generator_city
		,@generator_state
		,@generator_zip
		,NULL
		,NULL
		,@generator_id
		,@generator_address2
		,@generator_address3
		,@generator_address4
		,NULL -- gen address 5
		,NULL -- pc epa id
		,NULL --<profitcenter_profit_ctr_name, varchar(50),>
		,NULL --<profitcenter_address_1, varchar(40),>
		,NULL --<profitcenter_address_2, varchar(40),>
		,NULL --<profitcenter_address_3, varchar(40),>
		,NULL --<profitcenter_phone, varchar(14),>
		,NULL --<profitcenter_fax, varchar(14),>
		,newid()
		,@form_id
		,@revision_id
	)
	If @@error <> 0 goto ERR_HANDLER

	INSERT INTO [dbo].[FormLDRDetail] (
		[form_id]
		,[revision_id]
		,[form_version_id]
		,[page_number]
		,[manifest_line_item]
		,[ww_or_nww]
		,[subcategory]
		,[manage_id]
		,[approval_code]
		,[approval_key]
		,[company_id]
		,[profit_ctr_id]
		,[profile_id]
		)
	VALUES (
		@ldr_form_id
		,@revision_id
		,@form_version_id
		,1
		,1
		,@ldr_ww_or_nww
		,@ldr_subcategory
		,@ldr_manage_id
		,NULL
		,NULL
		,NULL
		,NULL
		,@profile_id
	)
	If @@error <> 0 goto ERR_HANDLER
END

--SREC 
IF(@srec_flag = 'T')
BEGIN
	DECLARE @srec_id INT

	SET @srec_id = (
			SELECT TOP 1 form_id
			FROM FormSREC
			WHERE wcr_id = @form_id
			)
	If @@error <> 0 goto ERR_HANDLER

	IF (@srec_id IS NULL)
	BEGIN
		EXEC @srec_id = sp_Sequence_Next 'Form.Form_ID'
		If @@error <> 0 goto ERR_HANDLER
	END
	
	INSERT INTO [Plt_AI].[dbo].[FormSREC]
           ([form_id]
           ,[revision_id]
           ,[form_version_id]
           ,[customer_id_from_form]
           ,[customer_id]
           ,[app_id]
           ,[status]
           ,[locked]
           ,[source]
           ,[approval_code]
           ,[approval_key]
           ,[company_id]
           ,[profit_ctr_id]
           ,[signing_name]
           ,[signing_company]
           ,[signing_title]
           ,[signing_date]
           ,[date_created]
           ,[date_modified]
           ,[created_by]
           ,[modified_by]
           ,[exempt_id]
           ,[waste_type]
           ,[waste_common_name]
           ,[manifest]
           ,[cust_name]
           ,[generator_name]
           ,[EPA_ID]
           ,[generator_id]
           ,[gen_mail_addr1]
           ,[gen_mail_addr2]
           ,[gen_mail_addr3]
           ,[gen_mail_addr4]
           ,[gen_mail_addr5]
           ,[gen_mail_city]
           ,[gen_mail_state]
           ,[gen_mail_zip_code]
           ,[profitcenter_epa_id]
           ,[profitcenter_profit_ctr_name]
           ,[profitcenter_address_1]
           ,[profitcenter_address_2]
           ,[profitcenter_address_3]
           ,[profitcenter_phone]
           ,[profitcenter_fax]
           ,[rowguid]
           ,[profile_id]
           ,[qty_units_desc]
           ,[disposal_date]
           ,[wcr_id]
           ,[wcr_rev_id])
     VALUES(
           @srec_ID	--(<form_id, int,>
           ,@revision_id	--,<revision_id, int,>
           ,(SELECT current_form_version FROM formtype where form_type = 'srec')	--,<form_version_id, int,>
           ,@customer_id_from_form	--,<customer_id_from_form, int,>
           ,NULL	--,<customer_id, int,>
           ,'W'		--,<app_id, varchar(20),>
           ,'A'	--,<status, char(1),>
           ,'U'	--,<locked, char(1),>
           ,'W'	--,<source, char(1),>
           ,NULL	--,<approval_code, varchar(15),>
           ,@profile_id	--,<approval_key, int,>
           ,NULL	--,<company_id, int,>
           ,NULL	--,<profit_ctr_id, int,>
           ,NULL	--,<signing_name, varchar(40),>
           ,NULL	--,<signing_company, varchar(40),>
           ,NULL	--,<signing_title, varchar(40),>
           ,NULL	--,<signing_date, datetime,>
           ,GETDATE()	--,<date_created, datetime,>
           ,GETDATE()	--,<date_modified, datetime,>
           ,@tmpUser	--,<created_by, varchar(60),>
           ,@tmpUser	--,<modified_by, varchar(60),>
           ,@srec_exempt_id	--,<exempt_id, int,>
           ,NULL	--,<waste_type, varchar(50),>
           ,@waste_common_name	--,<waste_common_name, varchar(50),>
           ,NULL	--,<manifest, varchar(20),>
           ,@cust_name	--,<cust_name, varchar(40),>
           ,@generator_name	--,<generator_name, varchar(40),>
           ,@epa_id	--,<EPA_ID, varchar(12),>
           ,@generator_id	--,<generator_id, int,>
           ,@gen_mail_address1	--,<gen_mail_addr1, varchar(40),>
           ,@gen_mail_address2	--,<gen_mail_addr2, varchar(40),>
           ,@gen_mail_address3	--,<gen_mail_addr3, varchar(40),>
           ,NULL	--,<gen_mail_addr4, varchar(40),>
           ,NULL	--,<gen_mail_addr5, varchar(40),>
           ,@gen_mail_city	--,<gen_mail_city, varchar(40),>
           ,@gen_mail_state	--,<gen_mail_state, varchar(2),>
           ,@gen_mail_zip	--,<gen_mail_zip_code, varchar(15),>
           ,NULL	--,<profitcenter_epa_id, varchar(12),>
           ,NULL	--,<profitcenter_profit_ctr_name, varchar(50),>
           ,NULL	--,<profitcenter_address_1, varchar(40),>
           ,NULL	--,<profitcenter_address_2, varchar(40),>
           ,NULL	--,<profitcenter_address_3, varchar(40),>
           ,NULL	--,<profitcenter_phone, varchar(14),>
           ,NULL	--,<profitcenter_fax, varchar(14),>
           ,NEWID()	--,<rowguid, uniqueidentifier,>
           ,@profile_id	--,<profile_id, int,>
           ,@srec_volume	--,<qty_units_desc, varchar(255),>
           ,@srec_date_of_disposal	--,<disposal_date, varchar(255),>
           ,@form_id	--,<wcr_id, int,>
           ,@revision_id	--,<wcr_rev_id, int,>)
           )
    If @@error <> 0 goto ERR_HANDLER

END

--NORM TENORM CHECK
IF (@NORM IS NOT NULL OR @TENORM IS NOT NULL)
BEGIN
	DECLARE @tenorm_id INT

	SET @tenorm_id = (
			SELECT TOP 1 form_id
			FROM FormNORMTENORM
			WHERE FormNORMTENORM.wcr_id = @form_id
			)
	If @@error <> 0 goto ERR_HANDLER

	IF (@tenorm_id IS NULL)
	BEGIN
		EXEC @tenorm_id = sp_Sequence_Next 'Form.Form_ID'
		If @@error <> 0 goto ERR_HANDLER
	END

	--NORM/TENORM
	INSERT INTO [dbo].[FormNORMTENORM] (
		[form_id]
		,[revision_id]
		,[version_id]
		,[status]
		,[locked]
		,[source]
		,[company_id]
		,[profit_ctr_id]
		,[profile_id]
		,[approval_code]
		,[generator_id]
		,[generator_epa_id]
		,[generator_name]
		,[generator_address_1]
		,[generator_address_2]
		,[generator_address_3]
		,[generator_address_4]
		,[generator_address_5]
		,[generator_city]
		,[generator_state]
		,[generator_zip_code]
		,[site_name]
		,[gen_mail_addr1]
		,[gen_mail_addr2]
		,[gen_mail_addr3]
		,[gen_mail_addr4]
		,[gen_mail_addr5]
		,[gen_mail_city]
		,[gen_mail_state]
		,[gen_mail_zip]
		,[NORM]
		,[TENORM]
		,[disposal_restriction_exempt]
		,[nuclear_reg_state_license]
		,[waste_process]
		,[shipping_dates]
		,[signing_name]
		,[signing_company]
		,[signing_title]
		,[signing_date]
		,[date_created]
		,[date_modified]
		,[created_by]
		,[modified_by]
		,[wcr_id]
		,[wcr_rev_id]
		)
	VALUES (
		@tenorm_id
		,@revision_id
		,1
		,'A'
		,'U'
		,'A'
		,NULL --@company_id
		,NULL
		,@profile_id
		,NULL --approval code
		,@generator_id
		,@EPA_id
		,@generator_name
		,@generator_address1
		,@generator_address2
		,@generator_address3
		,@generator_address4
		,NULL --Gen address 5
		,@generator_city
		,@generator_state
		,@generator_zip
		,NULL --[site name]
		,@gen_mail_address1
		,@gen_mail_address2
		,@gen_mail_address3
		,NULL --@gen_mail_address4
		,NULL --@gen_mail_address5
		,@gen_mail_city
		,@gen_mail_state
		,@gen_mail_zip
		,@NORM --[NORM]
		,@TENORM --[TENORM]
		,@disposal_restriction_exempt --[disposal_restriction_exempt]
		,@nuclear_reg_state_license --[nuclear_reg_state_license]
		,@gen_process --[waste_process]
		,@shipping_dates --[shipping_dates]
		,NULL --[signing_name]
		,NULL --[signing_company]
		,NULL --[signing_title]
		,NULL --[signing_date]
		,getdate()
		,getdate()
		,@tmpUser
		,@tmpUser
		,@form_id
		,@revision_id
		)
		If @@error <> 0 goto ERR_HANDLER
END

--insert waste code values
IF @state_specific_non_hazardous_waste_codes_ids IS NOT NULL
BEGIN
	EXEC sp_forms_add_codes @state_specific_non_hazardous_waste_codes_ids
		,'michigan_non_haz'
		,@form_id
		,@revision_id
	If @@error <> 0 goto ERR_HANDLER
END

IF @state_specific_hazardous_waste_codes_ids IS NOT NULL
BEGIN
	EXEC sp_forms_add_codes @state_specific_hazardous_waste_codes_ids
		,'state'
		,@form_id
		,@revision_id
	If @@error <> 0 goto ERR_HANDLER
END

IF @epa_rcra_characteristic_waste_codes_ids IS NOT NULL
BEGIN
	EXEC sp_forms_add_codes @epa_rcra_characteristic_waste_codes_ids
		,'rcra_characteristic'
		,@form_id
		,@revision_id
	If @@error <> 0 goto ERR_HANDLER
END

IF @epa_rcra_listed_waste_codes_ids IS NOT NULL
BEGIN
	EXEC sp_forms_add_codes @epa_rcra_listed_waste_codes_ids
		,'rcra_listed'
		,@form_id
		,@revision_id
	If @@error <> 0 goto ERR_HANDLER
END --	--set waste code flags
		--SET @michigan_non_haz = CASE
		--    WHEN @state_specific_non_hazardous_waste_codes is not null THEN 'T'
		--    ELSE 'F'
		--    END
		--SET @state_waste_code_flag = CASE
		--    WHEN @state_specific_hazardous_waste_codes is not null THEN 'T'
		--    ELSE 'F'
		--    END
		--SET @rcra_characteristic = CASE
		--    WHEN @epa_rcra_characteristic_waste_codes is not null THEN 'T'
		--    ELSE 'F'
		--    END
		--SET @rcra_listed = CASE
		--    WHEN @epa_rcra_listed_waste_codes is not null THEN 'T'
		--    ELSE 'F'
		--    END
		
COMMIT TRANSACTION
RETURN 0

ERR_HANDLER:
	SELECT 'Unexpected error occurred!'
	ROLLBACK TRANSACTION
	RETURN 1
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_create_wcr] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_create_wcr] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_create_wcr] TO [EQAI]
    AS [dbo];

