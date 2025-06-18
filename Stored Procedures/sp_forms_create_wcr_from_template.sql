CREATE OR ALTER PROCEDURE dbo.sp_forms_create_wcr_from_template (
	  @template_form_id INTEGER
	, @user	VARCHAR(60)
	)
AS
/****************
11/23/2011 CRG Created
Updated by Blair Christensen for Titan 05/27/2025

sp_forms_create_wcr_from_template
Creates a new WCR from a given template
--sp_forms_create_wcr_from_template @template_form_id='221492', @user = 'jonathan'

SELECT  * FROM    FormWCRTemplate
*****************/
BEGIN
	DECLARE @form_id INTEGER
		  , @revision_id INTEGER
		  , @temp_form_id INTEGER
		  , @temp_rev_id INTEGER
		  , @temp_ldr_id INTEGER
		  , @ldr_form_id INTEGER
		  , @ntn_form_id INTEGER
		  , @NewFormWCR_uid INTEGER

	EXEC @form_id = sp_Sequence_Next 'Form.Form_ID';
	EXEC @revision_id = sp_formsequence_next @form_id, 0, @user;

	SELECT TOP(1) @temp_form_id = wcr.form_ID
		 , @temp_rev_id = wcr.revision_id
	  FROM dbo.FormWCR wcr
	       JOIN dbo.FormWCRTemplate t ON t.template_form_id = wcr.form_id
	 WHERE t.template_form_id = @template_form_id
	 ORDER BY wcr.revision_id DESC;

	CREATE TABLE #tempWCR (
		   form_id INTEGER NOT NULL
		 , revision_id INTEGER NOT NULL
		 , form_version_id INTEGER NULL
		 , customer_id_from_form INTEGER NULL
		 , customer_id INTEGER NULL
		 , app_id VARCHAR(20) NULL
		 , tracking_id INTEGER NULL
		 , [status] CHAR(1) NOT NULL
		 , locked CHAR(1) NOT NULL
		 , [source] CHAR(1) NULL
		 , signing_name VARCHAR(40) NULL
		 , signing_company VARCHAR(40) NULL
		 , signing_title VARCHAR(40) NULL
		 , signing_date DATETIME NULL
		 , date_created DATETIME NOT NULL
		 , date_modified DATETIME NOT NULL
		 , created_by VARCHAR(100) NOT NULL
		 , modified_by VARCHAR(100) NOT NULL
		 , comments VARCHAR(20) NULL
		 , sample_id INTEGER NULL
		 , cust_name VARCHAR(75) NULL
		 , cust_addr1 VARCHAR(40) NULL
		 , cust_addr2 VARCHAR(40) NULL
		 , cust_addr3 VARCHAR(40) NULL
		 , cust_addr4 VARCHAR(40) NULL
		 , cust_city VARCHAR(40) NULL
		 , cust_state CHAR(2) NULL
		 , cust_zip VARCHAR(10) NULL
		 , cust_country CHAR(3) NULL
		 , inv_contact_name VARCHAR(40) NULL
		 , inv_contact_phone VARCHAR(20) NULL
		 , inv_contact_fax VARCHAR(10) NULL
		 , tech_contact_name VARCHAR(40) NULL
		 , tech_contact_phone VARCHAR(20) NULL
		 , tech_contact_fax VARCHAR(10) NULL
		 , tech_contact_mobile VARCHAR(10) NULL
		 , tech_contact_pager VARCHAR(10) NULL
		 , tech_cont_email VARCHAR(50) NULL
		 , generator_id INTEGER NULL
		 , EPA_ID VARCHAR(12) NULL
		 , sic_code INTEGER NULL
		 , generator_name VARCHAR(75) NULL
		 , generator_address1 VARCHAR(85) NULL
		 , generator_address2 VARCHAR(40) NULL
		 , generator_address3 VARCHAR(40) NULL
		 , generator_address4 VARCHAR(40) NULL
		 , generator_city VARCHAR(40) NULL
		 , generator_state CHAR(2) NULL
		 , generator_zip VARCHAR(10) NULL
		 , generator_county_id INTEGER NULL
		 , generator_county_name VARCHAR(40) NULL
		 , gen_mail_address1 VARCHAR(85) NULL
		 , gen_mail_address2 VARCHAR(40) NULL
		 , gen_mail_address3 VARCHAR(40) NULL
		 , gen_mail_city VARCHAR(40) NULL
		 , gen_mail_state CHAR(2) NULL
		 , gen_mail_zip VARCHAR(10) NULL
		 , generator_contact VARCHAR(40) NULL
		 , generator_contact_title VARCHAR(20) NULL
		 , generator_phone VARCHAR(20) NULL
		 , generator_fax VARCHAR(10) NULL
		 , waste_common_name VARCHAR(50) NULL
		 , volume VARCHAR(100) NULL
		 , frequency VARCHAR(20) NULL
		 , dot_shipping_name VARCHAR(255) NULL
		 , surcharge_exempt CHAR(1) NULL
		 , pack_bulk_solid_yard CHAR(1) NULL
		 , pack_bulk_solid_ton CHAR(1) NULL
		 , pack_bulk_liquid CHAR(1) NULL
		 , pack_totes CHAR(1) NULL
		 , pack_totes_size VARCHAR(30) NULL
		 , pack_cy_box CHAR(1) NULL
		 , pack_drum CHAR(1) NULL
		 , pack_other CHAR(1) NULL
		 , pack_other_desc VARCHAR(15) NULL
		 , color VARCHAR(25) NULL
		 , odor VARCHAR(25) NULL
		 , poc CHAR(1) NULL
		 , consistency_solid CHAR(1) NULL
		 , consistency_dust CHAR(1) NULL
		 , consistency_liquid CHAR(1) NULL
		 , consistency_sludge CHAR(1) NULL
		 , ph CHAR(10) NULL
		 , ph_lte_2 CHAR(1) NULL
		 , ph_gt_2_lt_5 CHAR(1) NULL
		 , ph_gte_5_lte_10 CHAR(1) NULL
		 , ph_gt_10_lt_12_5 CHAR(1) NULL
		 , ph_gte_12_5 CHAR(1) NULL
		 , ignitability VARCHAR(10) NULL
		 , waste_contains_spec_hand_none CHAR(1) NULL
		 , free_liquids CHAR(1) NULL
		 , oily_residue CHAR(1) NULL
		 , metal_fines CHAR(1) NULL
		 , biodegradable_sorbents CHAR(1) NULL
		 , amines CHAR(1) NULL
		 , ammonia CHAR(1) NULL
		 , dioxins CHAR(1) NULL
		 , furans CHAR(1) NULL
		 , biohazard CHAR(1) NULL
		 , shock_sensitive_waste CHAR(1) NULL
		 , reactive_waste CHAR(1) NULL
		 , radioactive_waste CHAR(1) NULL
		 , explosives CHAR(1) NULL
		 , pyrophoric_waste CHAR(1) NULL
		 , isocyanates CHAR(1) NULL
		 , asbestos_friable CHAR(1) NULL
		 , asbestos_non_friable CHAR(1) NULL
		 , gen_process VARCHAR(MAX) NULL
		 , rcra_listed CHAR(1) NULL
		 , rcra_listed_comment VARCHAR(255) NULL
		 , rcra_characteristic CHAR(1) NULL
		 , rcra_characteristic_comment VARCHAR(1000) NULL
		 , state_waste_code_flag CHAR(1) NULL
		 , state_waste_code_flag_comment VARCHAR(255) NULL
		 , wastewater_treatment CHAR(1) NULL
		 , exceed_ldr_standards CHAR(1) NULL
		 , meets_alt_soil_treatment_stds CHAR(1) NULL
		 , more_than_50_pct_debris CHAR(1) NULL
		 , oxidizer CHAR(1) NULL
		 , react_cyanide CHAR(1) NULL
		 , react_sulfide CHAR(1) NULL
		 , info_basis VARCHAR(10) NULL
		 , D004 CHAR(1) NULL
		 , D005 CHAR(1) NULL, D006 CHAR(1) NULL, D007 CHAR(1) NULL, D008 CHAR(1) NULL, D009 CHAR(1) NULL
		 , D010 CHAR(1) NULL, D011 CHAR(1) NULL, D012 CHAR(1) NULL, D013 CHAR(1) NULL, D014 CHAR(1) NULL
		 , D015 CHAR(1) NULL, D016 CHAR(1) NULL, D017 CHAR(1) NULL, D018 CHAR(1) NULL, D019 CHAR(1) NULL
		 , D020 CHAR(1) NULL, D021 CHAR(1) NULL, D022 CHAR(1) NULL, D023 CHAR(1) NULL, D024 CHAR(1) NULL
		 , D025 CHAR(1) NULL, D026 CHAR(1) NULL, D027 CHAR(1) NULL, D028 CHAR(1) NULL, D029 CHAR(1) NULL
		 , D030 CHAR(1) NULL, D031 CHAR(1) NULL, D032 CHAR(1) NULL, D033 CHAR(1) NULL, D034 CHAR(1) NULL
		 , D035 CHAR(1) NULL, D036 CHAR(1) NULL, D037 CHAR(1) NULL, D038 CHAR(1) NULL, D039 CHAR(1) NULL
		 , D040 CHAR(1) NULL, D041 CHAR(1) NULL, D042 CHAR(1) NULL, D043 CHAR(1) NULL
		 , D004_concentration FLOAT NULL
		 , D005_concentration FLOAT NULL, D006_concentration FLOAT NULL, D007_concentration FLOAT NULL, D008_concentration FLOAT NULL, D009_concentration FLOAT NULL
		 , D010_concentration FLOAT NULL, D011_concentration FLOAT NULL, D012_concentration FLOAT NULL, D013_concentration FLOAT NULL, D014_concentration FLOAT NULL
		 , D015_concentration FLOAT NULL, D016_concentration FLOAT NULL, D017_concentration FLOAT NULL, D018_concentration FLOAT NULL, D019_concentration FLOAT NULL
		 , D020_concentration FLOAT NULL, D021_concentration FLOAT NULL, D022_concentration FLOAT NULL, D023_concentration FLOAT NULL, D024_concentration FLOAT NULL
		 , D025_concentration FLOAT NULL, D026_concentration FLOAT NULL, D027_concentration FLOAT NULL, D028_concentration FLOAT NULL, D029_concentration FLOAT NULL
		 , D030_concentration FLOAT NULL, D031_concentration FLOAT NULL, D032_concentration FLOAT NULL, D033_concentration FLOAT NULL, D034_concentration FLOAT NULL
		 , D035_concentration FLOAT NULL, D036_concentration FLOAT NULL, D037_concentration FLOAT NULL, D038_concentration FLOAT NULL, D039_concentration FLOAT NULL
		 , D040_concentration FLOAT NULL, D041_concentration FLOAT NULL, D042_concentration FLOAT NULL, D043_concentration FLOAT NULL
		 , underlying_haz_constituents CHAR(1) NULL
		 , michigan_non_haz CHAR(1) NULL
		 , michigan_non_haz_comment VARCHAR(255) NULL
		 , universal CHAR(1) NULL
		 , recyclable_commodity CHAR(1) NULL
		 , recoverable_petroleum_product CHAR(1) NULL
		 , used_oil CHAR(1) NULL
		 , pcb_concentration VARCHAR(10) NULL
		 , pcb_source_concentration_gr_50 CHAR(1) NULL
		 , processed_into_non_liquid CHAR(1) NULL
		 , processd_into_nonlqd_prior_pcb VARCHAR(10) NULL
		 , pcb_non_lqd_contaminated_media CHAR(1) NULL
		 , pcb_manufacturer CHAR(1) NULL
		 , pcb_article_decontaminated CHAR(1) NULL
		 , ccvocgr500 CHAR(1) NULL
		 , benzene CHAR(1) NULL
		 , neshap_sic CHAR(1) NULL
		 , tab_gr_10 CHAR(1) NULL
		 , avg_h20_gr_10 CHAR(1) NULL
		 , tab FLOAT NULL
		 , benzene_gr_1 CHAR(1) NULL
		 , benzene_concentration FLOAT NULL
		 , benzene_unit VARCHAR(10) NULL
		 , fuel_blending CHAR(1) NULL
		 , btu_per_lb CHAR(10) NULL
		 , pct_chlorides CHAR(10) NULL
		 , pct_moisture CHAR(10) NULL
		 , pct_solids CHAR(10) NULL
		 , intended_for_reclamation CHAR(1) NULL
		 , pack_drum_size VARCHAR(30) NULL
		 , water_reactive CHAR(1) NULL
		 , aluminum CHAR(1) NULL
		 , subject_to_mact_neshap CHAR(1) NULL
		 , subject_to_mact_neshap_codes VARCHAR(100) NULL
		 , srec_exempt_id INTEGER NULL
		 , ldr_ww_or_nww CHAR(3) NULL
		 , ldr_subcategory VARCHAR(100) NULL
		 , ldr_manage_id INTEGER NULL
		 , wwa_info_basis VARCHAR(10) NULL
		 , wwa_bis_phthalate_flag CHAR(1) NULL
		 , wwa_bis_phthalate_actual FLOAT NULL
		 , wwa_carbazole_flag CHAR(1) NULL
		 , wwa_carbazole_actual FLOAT NULL
		 , wwa_o_cresol_flag CHAR(1) NULL
		 , wwa_o_cresol_actual FLOAT NULL
		 , wwa_p_cresol_flag CHAR(1) NULL
		 , wwa_p_cresol_actual FLOAT NULL
		 , wwa_n_decane_flag CHAR(1) NULL
		 , wwa_n_decane_actual FLOAT NULL
		 , wwa_fluoranthene_flag CHAR(1) NULL
		 , wwa_fluoranthene_actual FLOAT NULL
		 , wwa_n_octadecane_flag CHAR(1) NULL
		 , wwa_n_octadecane_actual FLOAT NULL
		 , wwa_trichlorophenol_246_flag CHAR(1) NULL
		 , wwa_trichlorophenol_246_actual FLOAT NULL
		 , wwa_phosphorus_flag CHAR(1) NULL
		 , wwa_phosphorus_actual FLOAT NULL
		 , wwa_total_chlor_phen_flag CHAR(1) NULL
		 , wwa_total_chlor_phen_actual FLOAT NULL
		 , wwa_total_organic_actual FLOAT NULL
		 , wwa_pcb_flag CHAR(1) NULL
		 , wwa_pcb_actual FLOAT NULL
		 , wwa_acidity_flag CHAR(1) NULL
		 , wwa_acidity_actual FLOAT NULL
		 , wwa_fog_flag CHAR(1) NULL
		 , wwa_fog_actual FLOAT NULL
		 , wwa_tss_flag CHAR(1) NULL
		 , wwa_tss_actual FLOAT NULL
		 , wwa_bod_flag CHAR(1) NULL
		 , wwa_bod_actual FLOAT NULL
		 , wwa_antimony_flag CHAR(1) NULL
		 , wwa_antimony_actual FLOAT NULL
		 , wwa_arsenic_flag CHAR(1) NULL
		 , wwa_arsenic_actual FLOAT NULL
		 , wwa_cadmium_flag CHAR(1) NULL
		 , wwa_cadmium_actual FLOAT NULL
		 , wwa_chromium_flag CHAR(1) NULL
		 , wwa_chromium_actual FLOAT NULL
		 , wwa_cobalt_flag CHAR(1) NULL
		 , wwa_cobalt_actual FLOAT NULL
		 , wwa_copper_flag CHAR(1) NULL
		 , wwa_copper_actual FLOAT NULL
		 , wwa_cyanide_flag CHAR(1) NULL
		 , wwa_cyanide_actual FLOAT NULL
		 , wwa_iron_flag CHAR(1) NULL
		 , wwa_iron_actual FLOAT NULL
		 , wwa_lead_flag CHAR(1) NULL
		 , wwa_lead_actual FLOAT NULL
		 , wwa_mercury_flag CHAR(1) NULL
		 , wwa_mercury_actual FLOAT NULL
		 , wwa_nickel_flag CHAR(1) NULL
		 , wwa_nickel_actual FLOAT NULL
		 , wwa_silver_flag CHAR(1) NULL
		 , wwa_silver_actual FLOAT NULL
		 , wwa_tin_flag CHAR(1) NULL
		 , wwa_tin_actual FLOAT NULL
		 , wwa_titanium_flag CHAR(1) NULL
		 , wwa_titanium_actual FLOAT NULL
		 , wwa_vanadium_flag CHAR(1) NULL
		 , wwa_vanadium_actual FLOAT NULL
		 , wwa_zinc_flag CHAR(1) NULL
		 , wwa_zinc_actual FLOAT NULL
		 , wwa_method_8240 CHAR(1) NULL
		 , wwa_method_8270 CHAR(1) NULL
		 , wwa_method_8080 CHAR(1) NULL
		 , wwa_method_8150 CHAR(1) NULL
		 , wwa_used_oil CHAR(1) NULL
		 , wwa_oil_mixed CHAR(1) NULL
		 , wwa_halogen_gt_1000 CHAR(1) NULL
		 , wwa_halogen_source CHAR(10) NULL
		 , wwa_halogen_source_desc1 VARCHAR(100) NULL
		 , wwa_other_desc_1 VARCHAR(100) NULL
		 , profile_id INTEGER NULL
		 , facility_instruction VARCHAR(1000) NULL
		 , emergency_phone_number VARCHAR(20) NULL
		 , generator_email VARCHAR(60) NULL
		 , frequency_other VARCHAR(20) NULL
		 , hazmat_flag CHAR(1) NULL
		 , hazmat_class VARCHAR(15) NULL
		 , subsidiary_haz_mat_class VARCHAR(15) NULL
		 , package_group CHAR(3) NULL
		 , un_na_flag CHAR(2) NULL
		 , un_na_number INTEGER NULL
		 , erg_number INTEGER NULL
		 , erg_suffix CHAR(2) NULL
		 , dot_shipping_desc VARCHAR(255) NULL
		 , reportable_quantity_flag CHAR(1) NULL
		 , RQ_reason VARCHAR(50) NULL
		 , odor_other_desc VARCHAR(50) NULL
		 , consistency_debris CHAR(1) NULL
		 , consistency_gas_aerosol CHAR(1) NULL
		 , consistency_varies CHAR(1) NULL
		 , pH_NA CHAR(1) NULL
		 , ignitability_lt_90 CHAR(1) NULL
		 , ignitability_90_139 CHAR(1) NULL
		 , ignitability_140_199 CHAR(1) NULL
		 , ignitability_gte_200 CHAR(1) NULL
		 , ignitability_NA CHAR(1) NULL
		 , air_reactive CHAR(1) NULL
		 , temp_ctrl_org_peroxide CHAR(1) NULL
		 , NORM CHAR(1) NULL
		 , TENORM CHAR(1) NULL
		 , handling_issue CHAR(1) NULL
		 , handling_issue_desc VARCHAR(2000) NULL
		 , rcra_exempt_flag CHAR(1) NULL
		 , RCRA_exempt_reason VARCHAR(255) NULL
		 , cyanide_plating CHAR(1) NULL
		 , EPA_source_code VARCHAR(10) NULL
		 , EPA_form_code VARCHAR(10) NULL
		 , waste_water_flag CHAR(1) NULL
		 , debris_dimension_weight VARCHAR(255) NULL
		 , info_basis_knowledge CHAR(1) NULL
		 , info_basis_analysis CHAR(1) NULL
		 , info_basis_msds CHAR(1) NULL
		 , universal_recyclable_commodity CHAR(4) NULL
		 , pcb_concentration_none CHAR(1) NULL
		 , pcb_concentration_0_49 CHAR(1) NULL
		 , pcb_concentration_50_499 CHAR(1) NULL
		 , pcb_concentration_500 CHAR(1) NULL
		 , ddvohapgr500 CHAR(1) NULL
		 , neshap_chem_1 VARCHAR(255) NULL
		 , neshap_chem_2 VARCHAR(255) NULL
		 , neshap_standards_part INTEGER NULL
		 , neshap_subpart VARCHAR(255) NULL
		 , benzene_onsite_mgmt CHAR(1) NULL
		 , benzene_onsite_mgmt_desc VARCHAR(255) NULL
		 , copy_source VARCHAR(10) NULL
		 , source_form_id INTEGER NULL
		 , source_revision_id INTEGER NULL
		 , tech_contact_id INTEGER NULL
		 , generator_contact_id INTEGER NULL
		 , inv_contact_id INTEGER NULL
		 , template_form_id INTEGER NULL
		 , date_last_profile_sync DATETIME NULL
		 , manifest_dot_sp_number VARCHAR(20) NULL
		 , generator_country CHAR(3) NULL
		 , gen_mail_name VARCHAR(40) NULL
		 , gen_mail_address4 VARCHAR(40) NULL
		 , gen_mail_country CHAR(3) NULL
		 , generator_type_ID INTEGER NULL
		 , NAICS_code INTEGER NULL
		 , state_id VARCHAR(40) NULL
		 , po_required CHAR(1) NULL
		 , purchase_order VARCHAR(20) NULL
		 , inv_contact_email VARCHAR(50) NULL
		 , DOT_shipping_desc_additional VARCHAR(255) NULL
		 , DOT_inhalation_haz_flag CHAR(1) NULL
		 , container_type_bulk CHAR(1) NULL
		 , container_type_totes CHAR(1) NULL
		 , container_type_pallet CHAR(1) NULL
		 , container_type_boxes CHAR(1) NULL
		 , container_type_drums CHAR(1) NULL
		 , container_type_cylinder CHAR(1) NULL
		 , container_type_labpack CHAR(1) NULL
		 , container_type_combination CHAR(1) NULL
		 , container_type_combination_desc VARCHAR(100) NULL
		 , container_type_other CHAR(1) NULL
		 , container_type_other_desc VARCHAR(100) NULL
		 , odor_strength CHAR(1) NULL
		 , odor_type_ammonia CHAR(1) NULL
		 , odor_type_amines CHAR(1) NULL
		 , odor_type_mercaptans CHAR(1) NULL
		 , odor_type_sulfur CHAR(1) NULL
		 , odor_type_organic_acid CHAR(1) NULL
		 , odor_type_other CHAR(1) NULL
		 , liquid_phase CHAR(1) NULL
		 , paint_filter_solid_flag CHAR(1) NULL
		 , incidental_liquid_flag CHAR(1) NULL
		 , ignitability_compare_symbol VARCHAR(2) NULL
		 , ignitability_compare_temperature INTEGER NULL
		 , ignitability_does_not_flash CHAR(1) NULL
		 , ignitability_flammable_solid CHAR(1) NULL
		 , texas_waste_material_type CHAR(1) NULL
		 , texas_state_waste_code VARCHAR(8) NULL
		 , PA_residual_waste_flag CHAR(1) NULL
		 , react_sulfide_ppm FLOAT NULL
		 , react_cyanide_ppm FLOAT NULL
		 , radioactive CHAR(1) NULL
		 , reactive_other_description VARCHAR(255) NULL
		 , reactive_other CHAR(1) NULL
		 , contains_pcb CHAR(1) NULL
		 , dioxins_or_furans CHAR(1) NULL
		 , metal_fines_powder_paste CHAR(1) NULL
		 , temp_control CHAR(1) NULL
		 , thermally_unstable CHAR(1) NULL
		 , compressed_gas CHAR(1) NULL
		 , tires CHAR(1) NULL
		 , organic_peroxide CHAR(1) NULL
		 , beryllium_present CHAR(1) NULL
		 , asbestos_flag CHAR(1) NULL
		 , asbestos_friable_flag CHAR(1) NULL
		 , hazardous_secondary_material CHAR(1) NULL
		 , hazardous_secondary_material_cert CHAR(1) NULL
		 , pharma_waste_subject_to_prescription CHAR(1) NULL
		 , waste_treated_after_generation CHAR(1) NULL
		 , waste_treated_after_generation_desc VARCHAR(255) NULL
		 , debris_separated CHAR(1) NULL
		 , debris_not_mixed_or_diluted CHAR(1) NULL
		 , origin_refinery CHAR(1) NULL
		 , specific_technology_requested CHAR(1) NULL
		 , requested_technology VARCHAR(255) NULL
		 , other_restrictions_requested VARCHAR(255) NULL
		 , thermal_process_flag CHAR(1) NULL
		 , DOT_sp_permit_flag CHAR(1) NULL
		 , DOT_sp_permit_text VARCHAR(255) NULL
		 , BTU_lt_gt_5000 CHAR(1) NULL
		 , ammonia_flag CHAR(1) NULL
		 , pcb_concentration_0_9 CHAR(1) NULL
		 , pcb_concentration_10_49 CHAR(1) NULL
		 , pcb_regulated_for_disposal_under_TSCA CHAR(1) NULL
		 , pcb_article_for_TSCA_landfill CHAR(1) NULL
		 , display_status_uid INTEGER NOT NULL
		 , RCRA_waste_code_flag CHAR(1) NULL
		 , RQ_threshold FLOAT NULL
		 , submitted_by VARCHAR(60) NULL
		 , date_submitted DATETIME NULL
		 , DOT_waste_flag CHAR(1) NULL
		 , section_F_none_apply_flag CHAR(1) NULL
		 , routing_facility VARCHAR(10) NULL
		 , waste_meets_ldr_standards CHAR(1) NULL
		 , signed_on_behalf_of CHAR(1) NULL
		 , PFAS_Flag CHAR(1) NULL
		 , approval_code VARCHAR(15) NULL
		 );

		INSERT INTO #tempWCR (form_id, revision_id, form_version_id
		 , customer_id_from_form, customer_id, app_id, tracking_id, [status], locked, [source]
		 , signing_name, signing_company, signing_title, signing_date
		 , date_created, date_modified, created_by, modified_by, comments, sample_id
		 , cust_name, cust_addr1, cust_addr2, cust_addr3, cust_addr4, cust_city, cust_state, cust_zip, cust_country
		 , inv_contact_name, inv_contact_phone, inv_contact_fax
		 , tech_contact_name, tech_contact_phone, tech_contact_fax, tech_contact_mobile, tech_contact_pager, tech_cont_email
		 , generator_id, EPA_ID, sic_code, generator_name
		 , generator_address1, generator_address2, generator_address3, generator_address4
		 , generator_city, generator_state, generator_zip, generator_county_id, generator_county_name
		 , gen_mail_address1, gen_mail_address2, gen_mail_address3, gen_mail_city, gen_mail_state, gen_mail_zip
		 , generator_contact, generator_contact_title, generator_phone, generator_fax
		 , waste_common_name, volume, frequency, dot_shipping_name, surcharge_exempt
		 , pack_bulk_solid_yard, pack_bulk_solid_ton, pack_bulk_liquid, pack_totes
		 , pack_totes_size, pack_cy_box, pack_drum, pack_other, pack_other_desc
		 , color, odor, poc, consistency_solid, consistency_dust, consistency_liquid, consistency_sludge
		 , ph, ph_lte_2, ph_gt_2_lt_5, ph_gte_5_lte_10, ph_gt_10_lt_12_5, ph_gte_12_5
		 , ignitability, waste_contains_spec_hand_none, free_liquids, oily_residue, metal_fines
		 , biodegradable_sorbents, amines, ammonia, dioxins, furans, biohazard
		 , shock_sensitive_waste, reactive_waste, radioactive_waste, explosives, pyrophoric_waste, isocyanates
		 , asbestos_friable, asbestos_non_friable, gen_process
		 , rcra_listed, rcra_listed_comment, rcra_characteristic, rcra_characteristic_comment
		 , state_waste_code_flag, state_waste_code_flag_comment, wastewater_treatment, exceed_ldr_standards
		 , meets_alt_soil_treatment_stds, more_than_50_pct_debris, oxidizer, react_cyanide, react_sulfide, info_basis
		 , D004, D005, D006, D007, D008, D009
		 , D010, D011, D012, D013, D014, D015, D016, D017, D018, D019
		 , D020, D021, D022, D023, D024, D025, D026, D027, D028, D029
		 , D030, D031, D032, D033, D034, D035, D036, D037, D038, D039
		 , D040, D041, D042, D043
		 , D004_concentration
		 , D005_concentration, D006_concentration, D007_concentration, D008_concentration, D009_concentration
		 , D010_concentration, D011_concentration, D012_concentration, D013_concentration, D014_concentration
		 , D015_concentration, D016_concentration, D017_concentration, D018_concentration, D019_concentration
		 , D020_concentration, D021_concentration, D022_concentration, D023_concentration, D024_concentration
		 , D025_concentration, D026_concentration, D027_concentration, D028_concentration, D029_concentration
		 , D030_concentration, D031_concentration, D032_concentration, D033_concentration, D034_concentration
		 , D035_concentration, D036_concentration, D037_concentration, D038_concentration, D039_concentration
		 , D040_concentration, D041_concentration, D042_concentration, D043_concentration
		 , underlying_haz_constituents, michigan_non_haz, michigan_non_haz_comment, universal
		 , recyclable_commodity, recoverable_petroleum_product, used_oil
		 , pcb_concentration, pcb_source_concentration_gr_50, processed_into_non_liquid, processd_into_nonlqd_prior_pcb
		 , pcb_non_lqd_contaminated_media, pcb_manufacturer, pcb_article_decontaminated, ccvocgr500
		 , benzene, neshap_sic, tab_gr_10, avg_h20_gr_10, tab, benzene_gr_1, benzene_concentration, benzene_unit
		 , fuel_blending, btu_per_lb, pct_chlorides, pct_moisture, pct_solids, intended_for_reclamation
		 , pack_drum_size, water_reactive, aluminum, subject_to_mact_neshap, subject_to_mact_neshap_codes
		 , srec_exempt_id, ldr_ww_or_nww, ldr_subcategory, ldr_manage_id
		 , wwa_info_basis, wwa_bis_phthalate_flag, wwa_bis_phthalate_actual, wwa_carbazole_flag, wwa_carbazole_actual
		 , wwa_o_cresol_flag, wwa_o_cresol_actual, wwa_p_cresol_flag, wwa_p_cresol_actual
		 , wwa_n_decane_flag, wwa_n_decane_actual, wwa_fluoranthene_flag, wwa_fluoranthene_actual
		 , wwa_n_octadecane_flag, wwa_n_octadecane_actual, wwa_trichlorophenol_246_flag, wwa_trichlorophenol_246_actual
		 , wwa_phosphorus_flag, wwa_phosphorus_actual, wwa_total_chlor_phen_flag, wwa_total_chlor_phen_actual, wwa_total_organic_actual
		 , wwa_pcb_flag, wwa_pcb_actual, wwa_acidity_flag, wwa_acidity_actual, wwa_fog_flag, wwa_fog_actual
		 , wwa_tss_flag, wwa_tss_actual, wwa_bod_flag, wwa_bod_actual, wwa_antimony_flag, wwa_antimony_actual
		 , wwa_arsenic_flag, wwa_arsenic_actual, wwa_cadmium_flag, wwa_cadmium_actual, wwa_chromium_flag, wwa_chromium_actual
		 , wwa_cobalt_flag, wwa_cobalt_actual, wwa_copper_flag, wwa_copper_actual, wwa_cyanide_flag, wwa_cyanide_actual
		 , wwa_iron_flag, wwa_iron_actual, wwa_lead_flag, wwa_lead_actual, wwa_mercury_flag, wwa_mercury_actual
		 , wwa_nickel_flag, wwa_nickel_actual, wwa_silver_flag, wwa_silver_actual, wwa_tin_flag, wwa_tin_actual
		 , wwa_titanium_flag, wwa_titanium_actual, wwa_vanadium_flag, wwa_vanadium_actual, wwa_zinc_flag, wwa_zinc_actual
		 , wwa_method_8240, wwa_method_8270, wwa_method_8080, wwa_method_8150, wwa_used_oil, wwa_oil_mixed
		 , wwa_halogen_gt_1000, wwa_halogen_source, wwa_halogen_source_desc1, wwa_other_desc_1
		 , profile_id, facility_instruction, emergency_phone_number, generator_email, frequency_other, hazmat_flag, hazmat_class
		 , subsidiary_haz_mat_class, package_group, un_na_flag, un_na_number, erg_number, erg_suffix, dot_shipping_desc
		 , reportable_quantity_flag, RQ_reason, odor_other_desc, consistency_debris, consistency_gas_aerosol, consistency_varies
		 , pH_NA, ignitability_lt_90, ignitability_90_139, ignitability_140_199, ignitability_gte_200, ignitability_NA
		 , air_reactive, temp_ctrl_org_peroxide, NORM, TENORM, handling_issue, handling_issue_desc
		 , rcra_exempt_flag, RCRA_exempt_reason, cyanide_plating, EPA_source_code, EPA_form_code, waste_water_flag
		 , debris_dimension_weight, info_basis_knowledge, info_basis_analysis, info_basis_msds, universal_recyclable_commodity
		 , pcb_concentration_none, pcb_concentration_0_49, pcb_concentration_50_499, pcb_concentration_500
		 , ddvohapgr500, neshap_chem_1, neshap_chem_2, neshap_standards_part, neshap_subpart, benzene_onsite_mgmt, benzene_onsite_mgmt_desc
		 , copy_source, source_form_id, source_revision_id, tech_contact_id, generator_contact_id, inv_contact_id, template_form_id
		 , date_last_profile_sync, manifest_dot_sp_number, generator_country, gen_mail_name, gen_mail_address4, gen_mail_country, generator_type_ID
		 , NAICS_code, state_id, po_required, purchase_order, inv_contact_email, DOT_shipping_desc_additional, DOT_inhalation_haz_flag
		 , container_type_bulk, container_type_totes, container_type_pallet, container_type_boxes, container_type_drums, container_type_cylinder
		 , container_type_labpack, container_type_combination, container_type_combination_desc, container_type_other, container_type_other_desc
		 , odor_strength, odor_type_ammonia, odor_type_amines, odor_type_mercaptans, odor_type_sulfur, odor_type_organic_acid, odor_type_other
		 , liquid_phase, paint_filter_solid_flag, incidental_liquid_flag
		 , ignitability_compare_symbol, ignitability_compare_temperature, ignitability_does_not_flash, ignitability_flammable_solid
		 , texas_waste_material_type, texas_state_waste_code, PA_residual_waste_flag, react_sulfide_ppm, react_cyanide_ppm
		 , radioactive, reactive_other_description, reactive_other, contains_pcb, dioxins_or_furans, metal_fines_powder_paste
		 , temp_control, thermally_unstable, compressed_gas, tires, organic_peroxide, beryllium_present, asbestos_flag, asbestos_friable_flag
		 , hazardous_secondary_material, hazardous_secondary_material_cert, pharma_waste_subject_to_prescription
		 , waste_treated_after_generation, waste_treated_after_generation_desc, debris_separated, debris_not_mixed_or_diluted
		 , origin_refinery, specific_technology_requested, requested_technology, other_restrictions_requested, thermal_process_flag
		 , DOT_sp_permit_flag, DOT_sp_permit_text, BTU_lt_gt_5000, ammonia_flag
		 , pcb_concentration_0_9, pcb_concentration_10_49, pcb_regulated_for_disposal_under_TSCA, pcb_article_for_TSCA_landfill
		 , display_status_uid, RCRA_waste_code_flag, RQ_threshold, submitted_by, date_submitted, DOT_waste_flag
		 , section_F_none_apply_flag, routing_facility, waste_meets_ldr_standards, signed_on_behalf_of, PFAS_Flag, approval_code
		 )
	SELECT TOP(1) form_id, revision_id, form_version_id
		 , customer_id_from_form, customer_id, app_id, tracking_id, [status], locked, [source]
		 , signing_name, signing_company, signing_title, signing_date
		 , date_created, date_modified, created_by, modified_by, comments, sample_id
		 , cust_name, cust_addr1, cust_addr2, cust_addr3, cust_addr4, cust_city, cust_state, cust_zip, cust_country
		 , inv_contact_name, inv_contact_phone, inv_contact_fax
		 , tech_contact_name, tech_contact_phone, tech_contact_fax, tech_contact_mobile, tech_contact_pager, tech_cont_email
		 , generator_id, EPA_ID, sic_code, generator_name
		 , generator_address1, generator_address2, generator_address3, generator_address4
		 , generator_city, generator_state, generator_zip, generator_county_id, generator_county_name
		 , gen_mail_address1, gen_mail_address2, gen_mail_address3, gen_mail_city, gen_mail_state, gen_mail_zip
		 , generator_contact, generator_contact_title, generator_phone, generator_fax
		 , waste_common_name, volume, frequency, dot_shipping_name, surcharge_exempt
		 , pack_bulk_solid_yard, pack_bulk_solid_ton, pack_bulk_liquid, pack_totes
		 , pack_totes_size, pack_cy_box, pack_drum, pack_other, pack_other_desc
		 , color, odor, poc, consistency_solid, consistency_dust, consistency_liquid, consistency_sludge
		 , ph, ph_lte_2, ph_gt_2_lt_5, ph_gte_5_lte_10, ph_gt_10_lt_12_5, ph_gte_12_5
		 , ignitability, waste_contains_spec_hand_none, free_liquids, oily_residue, metal_fines
		 , biodegradable_sorbents, amines, ammonia, dioxins, furans, biohazard
		 , shock_sensitive_waste, reactive_waste, radioactive_waste, explosives, pyrophoric_waste, isocyanates
		 , asbestos_friable, asbestos_non_friable, gen_process
		 , rcra_listed, rcra_listed_comment, rcra_characteristic, rcra_characteristic_comment
		 , state_waste_code_flag, state_waste_code_flag_comment, wastewater_treatment, exceed_ldr_standards
		 , meets_alt_soil_treatment_stds, more_than_50_pct_debris, oxidizer, react_cyanide, react_sulfide, info_basis
		 , D004, D005, D006, D007, D008, D009
		 , D010, D011, D012, D013, D014, D015, D016, D017, D018, D019
		 , D020, D021, D022, D023, D024, D025, D026, D027, D028, D029
		 , D030, D031, D032, D033, D034, D035, D036, D037, D038, D039
		 , D040, D041, D042, D043
		 , D004_concentration
		 , D005_concentration, D006_concentration, D007_concentration, D008_concentration, D009_concentration
		 , D010_concentration, D011_concentration, D012_concentration, D013_concentration, D014_concentration
		 , D015_concentration, D016_concentration, D017_concentration, D018_concentration, D019_concentration
		 , D020_concentration, D021_concentration, D022_concentration, D023_concentration, D024_concentration
		 , D025_concentration, D026_concentration, D027_concentration, D028_concentration, D029_concentration
		 , D030_concentration, D031_concentration, D032_concentration, D033_concentration, D034_concentration
		 , D035_concentration, D036_concentration, D037_concentration, D038_concentration, D039_concentration
		 , D040_concentration, D041_concentration, D042_concentration, D043_concentration
		 , underlying_haz_constituents, michigan_non_haz, michigan_non_haz_comment, universal
		 , recyclable_commodity, recoverable_petroleum_product, used_oil
		 , pcb_concentration, pcb_source_concentration_gr_50, processed_into_non_liquid, processd_into_nonlqd_prior_pcb
		 , pcb_non_lqd_contaminated_media, pcb_manufacturer, pcb_article_decontaminated, ccvocgr500
		 , benzene, neshap_sic, tab_gr_10, avg_h20_gr_10, tab, benzene_gr_1, benzene_concentration, benzene_unit
		 , fuel_blending, btu_per_lb, pct_chlorides, pct_moisture, pct_solids, intended_for_reclamation
		 , pack_drum_size, water_reactive, aluminum, subject_to_mact_neshap, subject_to_mact_neshap_codes
		 , srec_exempt_id, ldr_ww_or_nww, ldr_subcategory, ldr_manage_id
		 , wwa_info_basis, wwa_bis_phthalate_flag, wwa_bis_phthalate_actual, wwa_carbazole_flag, wwa_carbazole_actual
		 , wwa_o_cresol_flag, wwa_o_cresol_actual, wwa_p_cresol_flag, wwa_p_cresol_actual
		 , wwa_n_decane_flag, wwa_n_decane_actual, wwa_fluoranthene_flag, wwa_fluoranthene_actual
		 , wwa_n_octadecane_flag, wwa_n_octadecane_actual, wwa_trichlorophenol_246_flag, wwa_trichlorophenol_246_actual
		 , wwa_phosphorus_flag, wwa_phosphorus_actual, wwa_total_chlor_phen_flag, wwa_total_chlor_phen_actual, wwa_total_organic_actual
		 , wwa_pcb_flag, wwa_pcb_actual, wwa_acidity_flag, wwa_acidity_actual, wwa_fog_flag, wwa_fog_actual
		 , wwa_tss_flag, wwa_tss_actual, wwa_bod_flag, wwa_bod_actual, wwa_antimony_flag, wwa_antimony_actual
		 , wwa_arsenic_flag, wwa_arsenic_actual, wwa_cadmium_flag, wwa_cadmium_actual, wwa_chromium_flag, wwa_chromium_actual
		 , wwa_cobalt_flag, wwa_cobalt_actual, wwa_copper_flag, wwa_copper_actual, wwa_cyanide_flag, wwa_cyanide_actual
		 , wwa_iron_flag, wwa_iron_actual, wwa_lead_flag, wwa_lead_actual, wwa_mercury_flag, wwa_mercury_actual
		 , wwa_nickel_flag, wwa_nickel_actual, wwa_silver_flag, wwa_silver_actual, wwa_tin_flag, wwa_tin_actual
		 , wwa_titanium_flag, wwa_titanium_actual, wwa_vanadium_flag, wwa_vanadium_actual, wwa_zinc_flag, wwa_zinc_actual
		 , wwa_method_8240, wwa_method_8270, wwa_method_8080, wwa_method_8150, wwa_used_oil, wwa_oil_mixed
		 , wwa_halogen_gt_1000, wwa_halogen_source, wwa_halogen_source_desc1, wwa_other_desc_1
		 , profile_id, facility_instruction, emergency_phone_number, generator_email, frequency_other, hazmat_flag, hazmat_class
		 , subsidiary_haz_mat_class, package_group, un_na_flag, un_na_number, erg_number, erg_suffix, dot_shipping_desc
		 , reportable_quantity_flag, RQ_reason, odor_other_desc, consistency_debris, consistency_gas_aerosol, consistency_varies
		 , pH_NA, ignitability_lt_90, ignitability_90_139, ignitability_140_199, ignitability_gte_200, ignitability_NA
		 , air_reactive, temp_ctrl_org_peroxide, NORM, TENORM, handling_issue, handling_issue_desc
		 , rcra_exempt_flag, RCRA_exempt_reason, cyanide_plating, EPA_source_code, EPA_form_code, waste_water_flag
		 , debris_dimension_weight, info_basis_knowledge, info_basis_analysis, info_basis_msds, universal_recyclable_commodity
		 , pcb_concentration_none, pcb_concentration_0_49, pcb_concentration_50_499, pcb_concentration_500
		 , ddvohapgr500, neshap_chem_1, neshap_chem_2, neshap_standards_part, neshap_subpart, benzene_onsite_mgmt, benzene_onsite_mgmt_desc
		 , copy_source, source_form_id, source_revision_id, tech_contact_id, generator_contact_id, inv_contact_id, template_form_id
		 , date_last_profile_sync, manifest_dot_sp_number, generator_country, gen_mail_name, gen_mail_address4, gen_mail_country, generator_type_ID
		 , NAICS_code, state_id, po_required, purchase_order, inv_contact_email, DOT_shipping_desc_additional, DOT_inhalation_haz_flag
		 , container_type_bulk, container_type_totes, container_type_pallet, container_type_boxes, container_type_drums, container_type_cylinder
		 , container_type_labpack, container_type_combination, container_type_combination_desc, container_type_other, container_type_other_desc
		 , odor_strength, odor_type_ammonia, odor_type_amines, odor_type_mercaptans, odor_type_sulfur, odor_type_organic_acid, odor_type_other
		 , liquid_phase, paint_filter_solid_flag, incidental_liquid_flag
		 , ignitability_compare_symbol, ignitability_compare_temperature, ignitability_does_not_flash, ignitability_flammable_solid
		 , texas_waste_material_type, texas_state_waste_code, PA_residual_waste_flag, react_sulfide_ppm, react_cyanide_ppm
		 , radioactive, reactive_other_description, reactive_other, contains_pcb, dioxins_or_furans, metal_fines_powder_paste
		 , temp_control, thermally_unstable, compressed_gas, tires, organic_peroxide, beryllium_present, asbestos_flag, asbestos_friable_flag
		 , hazardous_secondary_material, hazardous_secondary_material_cert, pharma_waste_subject_to_prescription
		 , waste_treated_after_generation, waste_treated_after_generation_desc, debris_separated, debris_not_mixed_or_diluted
		 , origin_refinery, specific_technology_requested, requested_technology, other_restrictions_requested, thermal_process_flag
		 , DOT_sp_permit_flag, DOT_sp_permit_text, BTU_lt_gt_5000, ammonia_flag
		 , pcb_concentration_0_9, pcb_concentration_10_49, pcb_regulated_for_disposal_under_TSCA, pcb_article_for_TSCA_landfill
		 , display_status_uid, RCRA_waste_code_flag, RQ_threshold, submitted_by, date_submitted, DOT_waste_flag
		 , section_F_none_apply_flag, routing_facility, waste_meets_ldr_standards, signed_on_behalf_of, PFAS_Flag, approval_code
	  FROM dbo.FormWCR 
	 WHERE form_id = @temp_form_id
	   AND revision_id = @temp_rev_id;

	UPDATE #tempWCR 
	   SET form_id = @form_id 
		 , revision_id = @revision_id
		 , created_by = @user
		 , modified_by = @user
		 , date_created = GETDATE()
		 , date_modified = GETDATE()
		 , copy_source = 'template'
		 , source_form_id = @temp_form_id
		 , source_revision_id = @temp_rev_id
		 , template_form_id = @temp_form_id

	INSERT INTO dbo.FormWCR (form_id, revision_id, form_version_id
		 , customer_id_from_form, customer_id, app_id, tracking_id, [status], locked, [source]
		 , signing_name, signing_company, signing_title, signing_date
		 , date_created, date_modified, created_by, modified_by, comments, sample_id
		 , cust_name, cust_addr1, cust_addr2, cust_addr3, cust_addr4, cust_city, cust_state, cust_zip, cust_country
		 , inv_contact_name, inv_contact_phone, inv_contact_fax
		 , tech_contact_name, tech_contact_phone, tech_contact_fax, tech_contact_mobile, tech_contact_pager, tech_cont_email
		 , generator_id, EPA_ID, sic_code, generator_name
		 , generator_address1, generator_address2, generator_address3, generator_address4
		 , generator_city, generator_state, generator_zip, generator_county_id, generator_county_name
		 , gen_mail_address1, gen_mail_address2, gen_mail_address3, gen_mail_city, gen_mail_state, gen_mail_zip
		 , generator_contact, generator_contact_title, generator_phone, generator_fax
		 , waste_common_name, volume, frequency, dot_shipping_name, surcharge_exempt
		 , pack_bulk_solid_yard, pack_bulk_solid_ton, pack_bulk_liquid, pack_totes
		 , pack_totes_size, pack_cy_box, pack_drum, pack_other, pack_other_desc
		 , color, odor, poc, consistency_solid, consistency_dust, consistency_liquid, consistency_sludge
		 , ph, ph_lte_2, ph_gt_2_lt_5, ph_gte_5_lte_10, ph_gt_10_lt_12_5, ph_gte_12_5
		 , ignitability, waste_contains_spec_hand_none, free_liquids, oily_residue, metal_fines
		 , biodegradable_sorbents, amines, ammonia, dioxins, furans, biohazard
		 , shock_sensitive_waste, reactive_waste, radioactive_waste, explosives, pyrophoric_waste, isocyanates
		 , asbestos_friable, asbestos_non_friable, gen_process
		 , rcra_listed, rcra_listed_comment, rcra_characteristic, rcra_characteristic_comment
		 , state_waste_code_flag, state_waste_code_flag_comment, wastewater_treatment, exceed_ldr_standards
		 , meets_alt_soil_treatment_stds, more_than_50_pct_debris, oxidizer, react_cyanide, react_sulfide, info_basis
		 , D004, D005, D006, D007, D008, D009
		 , D010, D011, D012, D013, D014, D015, D016, D017, D018, D019
		 , D020, D021, D022, D023, D024, D025, D026, D027, D028, D029
		 , D030, D031, D032, D033, D034, D035, D036, D037, D038, D039
		 , D040, D041, D042, D043
		 , D004_concentration
		 , D005_concentration, D006_concentration, D007_concentration, D008_concentration, D009_concentration
		 , D010_concentration, D011_concentration, D012_concentration, D013_concentration, D014_concentration
		 , D015_concentration, D016_concentration, D017_concentration, D018_concentration, D019_concentration
		 , D020_concentration, D021_concentration, D022_concentration, D023_concentration, D024_concentration
		 , D025_concentration, D026_concentration, D027_concentration, D028_concentration, D029_concentration
		 , D030_concentration, D031_concentration, D032_concentration, D033_concentration, D034_concentration
		 , D035_concentration, D036_concentration, D037_concentration, D038_concentration, D039_concentration
		 , D040_concentration, D041_concentration, D042_concentration, D043_concentration
		 , underlying_haz_constituents, michigan_non_haz, michigan_non_haz_comment, universal
		 , recyclable_commodity, recoverable_petroleum_product, used_oil
		 , pcb_concentration, pcb_source_concentration_gr_50, processed_into_non_liquid, processd_into_nonlqd_prior_pcb
		 , pcb_non_lqd_contaminated_media, pcb_manufacturer, pcb_article_decontaminated, ccvocgr500
		 , benzene, neshap_sic, tab_gr_10, avg_h20_gr_10, tab, benzene_gr_1, benzene_concentration, benzene_unit
		 , fuel_blending, btu_per_lb, pct_chlorides, pct_moisture, pct_solids, intended_for_reclamation
		 , pack_drum_size, water_reactive, aluminum, subject_to_mact_neshap, subject_to_mact_neshap_codes
		 , srec_exempt_id, ldr_ww_or_nww, ldr_subcategory, ldr_manage_id
		 , wwa_info_basis, wwa_bis_phthalate_flag, wwa_bis_phthalate_actual, wwa_carbazole_flag, wwa_carbazole_actual
		 , wwa_o_cresol_flag, wwa_o_cresol_actual, wwa_p_cresol_flag, wwa_p_cresol_actual
		 , wwa_n_decane_flag, wwa_n_decane_actual, wwa_fluoranthene_flag, wwa_fluoranthene_actual
		 , wwa_n_octadecane_flag, wwa_n_octadecane_actual, wwa_trichlorophenol_246_flag, wwa_trichlorophenol_246_actual
		 , wwa_phosphorus_flag, wwa_phosphorus_actual, wwa_total_chlor_phen_flag, wwa_total_chlor_phen_actual, wwa_total_organic_actual
		 , wwa_pcb_flag, wwa_pcb_actual, wwa_acidity_flag, wwa_acidity_actual, wwa_fog_flag, wwa_fog_actual
		 , wwa_tss_flag, wwa_tss_actual, wwa_bod_flag, wwa_bod_actual, wwa_antimony_flag, wwa_antimony_actual
		 , wwa_arsenic_flag, wwa_arsenic_actual, wwa_cadmium_flag, wwa_cadmium_actual, wwa_chromium_flag, wwa_chromium_actual
		 , wwa_cobalt_flag, wwa_cobalt_actual, wwa_copper_flag, wwa_copper_actual, wwa_cyanide_flag, wwa_cyanide_actual
		 , wwa_iron_flag, wwa_iron_actual, wwa_lead_flag, wwa_lead_actual, wwa_mercury_flag, wwa_mercury_actual
		 , wwa_nickel_flag, wwa_nickel_actual, wwa_silver_flag, wwa_silver_actual, wwa_tin_flag, wwa_tin_actual
		 , wwa_titanium_flag, wwa_titanium_actual, wwa_vanadium_flag, wwa_vanadium_actual, wwa_zinc_flag, wwa_zinc_actual
		 , wwa_method_8240, wwa_method_8270, wwa_method_8080, wwa_method_8150, wwa_used_oil, wwa_oil_mixed
		 , wwa_halogen_gt_1000, wwa_halogen_source, wwa_halogen_source_desc1, wwa_other_desc_1
		 , profile_id, facility_instruction, emergency_phone_number, generator_email, frequency_other, hazmat_flag, hazmat_class
		 , subsidiary_haz_mat_class, package_group, un_na_flag, un_na_number, erg_number, erg_suffix, dot_shipping_desc
		 , reportable_quantity_flag, RQ_reason, odor_other_desc, consistency_debris, consistency_gas_aerosol, consistency_varies
		 , pH_NA, ignitability_lt_90, ignitability_90_139, ignitability_140_199, ignitability_gte_200, ignitability_NA
		 , air_reactive, temp_ctrl_org_peroxide, NORM, TENORM, handling_issue, handling_issue_desc
		 , rcra_exempt_flag, RCRA_exempt_reason, cyanide_plating, EPA_source_code, EPA_form_code, waste_water_flag
		 , debris_dimension_weight, info_basis_knowledge, info_basis_analysis, info_basis_msds, universal_recyclable_commodity
		 , pcb_concentration_none, pcb_concentration_0_49, pcb_concentration_50_499, pcb_concentration_500
		 , ddvohapgr500, neshap_chem_1, neshap_chem_2, neshap_standards_part, neshap_subpart, benzene_onsite_mgmt, benzene_onsite_mgmt_desc
		 , copy_source, source_form_id, source_revision_id, tech_contact_id, generator_contact_id, inv_contact_id, template_form_id
		 , date_last_profile_sync, manifest_dot_sp_number, generator_country, gen_mail_name, gen_mail_address4, gen_mail_country, generator_type_ID
		 , NAICS_code, state_id, po_required, purchase_order, inv_contact_email, DOT_shipping_desc_additional, DOT_inhalation_haz_flag
		 , container_type_bulk, container_type_totes, container_type_pallet, container_type_boxes, container_type_drums, container_type_cylinder
		 , container_type_labpack, container_type_combination, container_type_combination_desc, container_type_other, container_type_other_desc
		 , odor_strength, odor_type_ammonia, odor_type_amines, odor_type_mercaptans, odor_type_sulfur, odor_type_organic_acid, odor_type_other
		 , liquid_phase, paint_filter_solid_flag, incidental_liquid_flag
		 , ignitability_compare_symbol, ignitability_compare_temperature, ignitability_does_not_flash, ignitability_flammable_solid
		 , texas_waste_material_type, texas_state_waste_code, PA_residual_waste_flag, react_sulfide_ppm, react_cyanide_ppm
		 , radioactive, reactive_other_description, reactive_other, contains_pcb, dioxins_or_furans, metal_fines_powder_paste
		 , temp_control, thermally_unstable, compressed_gas, tires, organic_peroxide, beryllium_present, asbestos_flag, asbestos_friable_flag
		 , hazardous_secondary_material, hazardous_secondary_material_cert, pharma_waste_subject_to_prescription
		 , waste_treated_after_generation, waste_treated_after_generation_desc, debris_separated, debris_not_mixed_or_diluted
		 , origin_refinery, specific_technology_requested, requested_technology, other_restrictions_requested, thermal_process_flag
		 , DOT_sp_permit_flag, DOT_sp_permit_text, BTU_lt_gt_5000, ammonia_flag
		 , pcb_concentration_0_9, pcb_concentration_10_49, pcb_regulated_for_disposal_under_TSCA, pcb_article_for_TSCA_landfill
		 , display_status_uid, RCRA_waste_code_flag, RQ_threshold, submitted_by, date_submitted, DOT_waste_flag
		 , section_F_none_apply_flag, routing_facility, waste_meets_ldr_standards, signed_on_behalf_of, PFAS_Flag, approval_code
		 )
	SELECT form_id, revision_id, form_version_id
		 , customer_id_from_form, customer_id, app_id, tracking_id, [status], locked, [source]
		 , signing_name, signing_company, signing_title, signing_date
		 , date_created, date_modified, created_by, modified_by, comments, sample_id
		 , cust_name, cust_addr1, cust_addr2, cust_addr3, cust_addr4, cust_city, cust_state, cust_zip, cust_country
		 , inv_contact_name, inv_contact_phone, inv_contact_fax
		 , tech_contact_name, tech_contact_phone, tech_contact_fax, tech_contact_mobile, tech_contact_pager, tech_cont_email
		 , generator_id, EPA_ID, sic_code, generator_name
		 , generator_address1, generator_address2, generator_address3, generator_address4
		 , generator_city, generator_state, generator_zip, generator_county_id, generator_county_name
		 , gen_mail_address1, gen_mail_address2, gen_mail_address3, gen_mail_city, gen_mail_state, gen_mail_zip
		 , generator_contact, generator_contact_title, generator_phone, generator_fax
		 , waste_common_name, volume, frequency, dot_shipping_name, surcharge_exempt
		 , pack_bulk_solid_yard, pack_bulk_solid_ton, pack_bulk_liquid, pack_totes
		 , pack_totes_size, pack_cy_box, pack_drum, pack_other, pack_other_desc
		 , color, odor, poc, consistency_solid, consistency_dust, consistency_liquid, consistency_sludge
		 , ph, ph_lte_2, ph_gt_2_lt_5, ph_gte_5_lte_10, ph_gt_10_lt_12_5, ph_gte_12_5
		 , ignitability, waste_contains_spec_hand_none, free_liquids, oily_residue, metal_fines
		 , biodegradable_sorbents, amines, ammonia, dioxins, furans, biohazard
		 , shock_sensitive_waste, reactive_waste, radioactive_waste, explosives, pyrophoric_waste, isocyanates
		 , asbestos_friable, asbestos_non_friable, gen_process
		 , rcra_listed, rcra_listed_comment, rcra_characteristic, rcra_characteristic_comment
		 , state_waste_code_flag, state_waste_code_flag_comment, wastewater_treatment, exceed_ldr_standards
		 , meets_alt_soil_treatment_stds, more_than_50_pct_debris, oxidizer, react_cyanide, react_sulfide, info_basis
		 , D004, D005, D006, D007, D008, D009
		 , D010, D011, D012, D013, D014, D015, D016, D017, D018, D019
		 , D020, D021, D022, D023, D024, D025, D026, D027, D028, D029
		 , D030, D031, D032, D033, D034, D035, D036, D037, D038, D039
		 , D040, D041, D042, D043
		 , D004_concentration
		 , D005_concentration, D006_concentration, D007_concentration, D008_concentration, D009_concentration
		 , D010_concentration, D011_concentration, D012_concentration, D013_concentration, D014_concentration
		 , D015_concentration, D016_concentration, D017_concentration, D018_concentration, D019_concentration
		 , D020_concentration, D021_concentration, D022_concentration, D023_concentration, D024_concentration
		 , D025_concentration, D026_concentration, D027_concentration, D028_concentration, D029_concentration
		 , D030_concentration, D031_concentration, D032_concentration, D033_concentration, D034_concentration
		 , D035_concentration, D036_concentration, D037_concentration, D038_concentration, D039_concentration
		 , D040_concentration, D041_concentration, D042_concentration, D043_concentration
		 , underlying_haz_constituents, michigan_non_haz, michigan_non_haz_comment, universal
		 , recyclable_commodity, recoverable_petroleum_product, used_oil
		 , pcb_concentration, pcb_source_concentration_gr_50, processed_into_non_liquid, processd_into_nonlqd_prior_pcb
		 , pcb_non_lqd_contaminated_media, pcb_manufacturer, pcb_article_decontaminated, ccvocgr500
		 , benzene, neshap_sic, tab_gr_10, avg_h20_gr_10, tab, benzene_gr_1, benzene_concentration, benzene_unit
		 , fuel_blending, btu_per_lb, pct_chlorides, pct_moisture, pct_solids, intended_for_reclamation
		 , pack_drum_size, water_reactive, aluminum, subject_to_mact_neshap, subject_to_mact_neshap_codes
		 , srec_exempt_id, ldr_ww_or_nww, ldr_subcategory, ldr_manage_id
		 , wwa_info_basis, wwa_bis_phthalate_flag, wwa_bis_phthalate_actual, wwa_carbazole_flag, wwa_carbazole_actual
		 , wwa_o_cresol_flag, wwa_o_cresol_actual, wwa_p_cresol_flag, wwa_p_cresol_actual
		 , wwa_n_decane_flag, wwa_n_decane_actual, wwa_fluoranthene_flag, wwa_fluoranthene_actual
		 , wwa_n_octadecane_flag, wwa_n_octadecane_actual, wwa_trichlorophenol_246_flag, wwa_trichlorophenol_246_actual
		 , wwa_phosphorus_flag, wwa_phosphorus_actual, wwa_total_chlor_phen_flag, wwa_total_chlor_phen_actual, wwa_total_organic_actual
		 , wwa_pcb_flag, wwa_pcb_actual, wwa_acidity_flag, wwa_acidity_actual, wwa_fog_flag, wwa_fog_actual
		 , wwa_tss_flag, wwa_tss_actual, wwa_bod_flag, wwa_bod_actual, wwa_antimony_flag, wwa_antimony_actual
		 , wwa_arsenic_flag, wwa_arsenic_actual, wwa_cadmium_flag, wwa_cadmium_actual, wwa_chromium_flag, wwa_chromium_actual
		 , wwa_cobalt_flag, wwa_cobalt_actual, wwa_copper_flag, wwa_copper_actual, wwa_cyanide_flag, wwa_cyanide_actual
		 , wwa_iron_flag, wwa_iron_actual, wwa_lead_flag, wwa_lead_actual, wwa_mercury_flag, wwa_mercury_actual
		 , wwa_nickel_flag, wwa_nickel_actual, wwa_silver_flag, wwa_silver_actual, wwa_tin_flag, wwa_tin_actual
		 , wwa_titanium_flag, wwa_titanium_actual, wwa_vanadium_flag, wwa_vanadium_actual, wwa_zinc_flag, wwa_zinc_actual
		 , wwa_method_8240, wwa_method_8270, wwa_method_8080, wwa_method_8150, wwa_used_oil, wwa_oil_mixed
		 , wwa_halogen_gt_1000, wwa_halogen_source, wwa_halogen_source_desc1, wwa_other_desc_1
		 , profile_id, facility_instruction, emergency_phone_number, generator_email, frequency_other, hazmat_flag, hazmat_class
		 , subsidiary_haz_mat_class, package_group, un_na_flag, un_na_number, erg_number, erg_suffix, dot_shipping_desc
		 , reportable_quantity_flag, RQ_reason, odor_other_desc, consistency_debris, consistency_gas_aerosol, consistency_varies
		 , pH_NA, ignitability_lt_90, ignitability_90_139, ignitability_140_199, ignitability_gte_200, ignitability_NA
		 , air_reactive, temp_ctrl_org_peroxide, NORM, TENORM, handling_issue, handling_issue_desc
		 , rcra_exempt_flag, RCRA_exempt_reason, cyanide_plating, EPA_source_code, EPA_form_code, waste_water_flag
		 , debris_dimension_weight, info_basis_knowledge, info_basis_analysis, info_basis_msds, universal_recyclable_commodity
		 , pcb_concentration_none, pcb_concentration_0_49, pcb_concentration_50_499, pcb_concentration_500
		 , ddvohapgr500, neshap_chem_1, neshap_chem_2, neshap_standards_part, neshap_subpart, benzene_onsite_mgmt, benzene_onsite_mgmt_desc
		 , copy_source, source_form_id, source_revision_id, tech_contact_id, generator_contact_id, inv_contact_id, template_form_id
		 , date_last_profile_sync, manifest_dot_sp_number, generator_country, gen_mail_name, gen_mail_address4, gen_mail_country, generator_type_ID
		 , NAICS_code, state_id, po_required, purchase_order, inv_contact_email, DOT_shipping_desc_additional, DOT_inhalation_haz_flag
		 , container_type_bulk, container_type_totes, container_type_pallet, container_type_boxes, container_type_drums, container_type_cylinder
		 , container_type_labpack, container_type_combination, container_type_combination_desc, container_type_other, container_type_other_desc
		 , odor_strength, odor_type_ammonia, odor_type_amines, odor_type_mercaptans, odor_type_sulfur, odor_type_organic_acid, odor_type_other
		 , liquid_phase, paint_filter_solid_flag, incidental_liquid_flag
		 , ignitability_compare_symbol, ignitability_compare_temperature, ignitability_does_not_flash, ignitability_flammable_solid
		 , texas_waste_material_type, texas_state_waste_code, PA_residual_waste_flag, react_sulfide_ppm, react_cyanide_ppm
		 , radioactive, reactive_other_description, reactive_other, contains_pcb, dioxins_or_furans, metal_fines_powder_paste
		 , temp_control, thermally_unstable, compressed_gas, tires, organic_peroxide, beryllium_present, asbestos_flag, asbestos_friable_flag
		 , hazardous_secondary_material, hazardous_secondary_material_cert, pharma_waste_subject_to_prescription
		 , waste_treated_after_generation, waste_treated_after_generation_desc, debris_separated, debris_not_mixed_or_diluted
		 , origin_refinery, specific_technology_requested, requested_technology, other_restrictions_requested, thermal_process_flag
		 , DOT_sp_permit_flag, DOT_sp_permit_text, BTU_lt_gt_5000, ammonia_flag
		 , pcb_concentration_0_9, pcb_concentration_10_49, pcb_regulated_for_disposal_under_TSCA, pcb_article_for_TSCA_landfill
		 , display_status_uid, RCRA_waste_code_flag, RQ_threshold, submitted_by, date_submitted, DOT_waste_flag
		 , section_F_none_apply_flag, routing_facility, waste_meets_ldr_standards, signed_on_behalf_of, PFAS_Flag, approval_code
	  FROM #tempWCR;

	SET @NewFormWCR_uid = SCOPE_IDENTITY();
	DROP TABLE #tempWCR;

	--FormXConstituent
	CREATE TABLE #tempFormXConstituent (
		   _order INTEGER NOT NULL
		 , form_id INTEGER NOT NULL
		 , revision_id INTEGER NOT NULL
		 , page_number INTEGER NULL
		 , line_item INTEGER NULL
		 , const_id INTEGER NULL
		 , const_desc VARCHAR(250) NULL
		 , min_concentration FLOAT NULL
		 , concentration FLOAT NULL
		 , unit CHAR(10) NULL
		 , uhc CHAR(1) NULL
		 , specifier VARCHAR(30) NULL
		 , TCLP_or_totals VARCHAR(10) NULL
		 , typical_concentration FLOAT NULL
		 , max_concentration FLOAT NULL
		 , exceeds_LDR CHAR(1) NULL
		 , requiring_treatment_flag CHAR(1) NULL
		 , cor_lock_flag CHAR(1) NULL
		 , added_by VARCHAR(100) NOT NULL
		 , date_added DATETIME NOT NULL
		 , modified_by VARCHAR(100) NOT NULL
		 , date_modified DATETIME NOT NULL
		 );

	INSERT INTO #tempFormXConstituent (
		   _order, form_id, revision_id, page_number, line_item, const_id, const_desc
		 , min_concentration, concentration, unit, uhc, specifier, TCLP_or_totals
		 , typical_concentration, max_concentration, exceeds_LDR, requiring_treatment_flag, cor_lock_flag
		 , added_by, date_added, modified_by, date_modified
		 )
	SELECT _order, form_id, revision_id, page_number, line_item, const_id, const_desc
		 , min_concentration, concentration, unit, uhc, specifier, TCLP_or_totals
		 , typical_concentration, max_concentration, exceeds_LDR, requiring_treatment_flag, cor_lock_flag
		 , SYSTEM_USER as added_by, GETDATE() as date_added, SYSTEM_USER as modified_by, GETDATE() as date_modified
	  FROM dbo.FormXConstituent
	 WHERE form_id = @temp_form_id
	   AND revision_id = @temp_rev_id;
		
	UPDATE #tempFormXConstituent 
	   SET form_id = @form_id 
		 , revision_id = @revision_id;

	INSERT INTO dbo.FormXConstituent (form_id, revision_id, page_number, line_item, const_id, const_desc
		 , min_concentration, concentration, unit, uhc, specifier, TCLP_or_totals
		 , typical_concentration, max_concentration, exceeds_LDR, requiring_treatment_flag, cor_lock_flag
		 , added_by, date_added, modified_by, date_modified
		 )
	SELECT form_id, revision_id, page_number, line_item, const_id, const_desc
		 , min_concentration, concentration, unit, uhc, specifier, TCLP_or_totals
		 , typical_concentration, max_concentration, exceeds_LDR, requiring_treatment_flag, cor_lock_flag
		 , added_by, date_added, modified_by, date_modified
	  FROM #tempFormXConstituent;

	DROP TABLE #tempFormXConstituent;

	--FormXUnit
	CREATE TABLE #tempFormXUnit (
		   form_type CHAR(10) NULL
		 , form_id INTEGER NULL
		 , revision_id INTEGER NULL
		 , bill_unit_code VARCHAR(4) NULL
		 , quantity VARCHAR(255) NULL
		 , added_by VARCHAR(100) NOT NULL
		 , date_added DATETIME NOT NULL
		 , modified_by VARCHAR(100) NOT NULL
		 , date_modified DATETIME NOT NULL
		 );

	INSERT INTO #tempFormXUnit (form_type, form_id, revision_id, bill_unit_code, quantity
		 , added_by, date_added, modified_by, date_modified)
	SELECT form_type, form_id, revision_id, bill_unit_code, quantity
		 , SYSTEM_USER as added_by, GETDATE() as date_added, SYSTEM_USER as modified_by, GETDATE() as date_modified
	  FROM dbo.FormXUnit
	 WHERE form_id = @temp_form_id
	   AND revision_id = @temp_rev_id;
		
	UPDATE #tempFormXUnit
	   SET form_id = @form_id 
		 , revision_id = @revision_id;

	INSERT INTO dbo.FormXUnit (form_type, form_id, revision_id, bill_unit_code, quantity
		 , added_by, date_added, modified_by, date_modified)
	SELECT form_type, form_id, revision_id, bill_unit_code, quantity
		 , added_by, date_added, modified_by, date_modified
	  FROM #tempFormXUnit;

	DROP TABLE #tempFormXUnit;

	--FormXWasteCode
	CREATE TABLE #tempFormXWasteCode (
		   form_id INTEGER NOT NULL
		 , revision_id INTEGER NOT NULL
		 , page_number INTEGER NULL
		 , line_item INTEGER NULL
		 , waste_code_uid INTEGER NOT NULL
		 , waste_code CHAR(4) NOT NULL
		 , specifier VARCHAR(30) NULL
		 , lock_flag CHAR(1) NULL
		 , added_by VARCHAR(100) NOT NULL
		 , date_added DATETIME NOT NULL
		 , modified_by VARCHAR(100) NOT NULL
		 , date_modified DATETIME NOT NULL
		 );

	INSERT INTO #tempFormXWasteCode (form_id, revision_id, page_number, line_item
		 , waste_code_uid, waste_code, specifier, lock_flag
		 , added_by, date_added, modified_by, date_modified)
	SELECT form_id, revision_id, page_number, line_item
		 , waste_code_uid, waste_code, specifier, lock_flag
		 , SYSTEM_USER as added_by, GETDATE() as date_added, SYSTEM_USER as modified_by, GETDATE() as date_modified
	  FROM dbo.FormXWasteCode
	 WHERE form_id = @temp_form_id
	   AND revision_id = @temp_rev_id;
		
	UPDATE #tempFormXWasteCode
	   SET form_id = @form_id 
		 , revision_id = @revision_id;

	INSERT INTO dbo.FormXWasteCode (form_id, revision_id, page_number, line_item
		 , waste_code_uid, waste_code, specifier, lock_flag
		 , added_by, date_added, modified_by, date_modified)
	SELECT form_id, revision_id, page_number, line_item
		 , waste_code_uid, waste_code, specifier, lock_flag
		 , added_by, date_added, modified_by, date_modified
	  FROM #tempFormXWasteCode;

	DROP TABLE #tempFormXWasteCode;


	--FormXWCRComposition
	CREATE TABLE #tempFormXWCRComposition (
		   form_id INTEGER NOT NULL
		 , revision_id INTEGER NOT NULL
		 , comp_description VARCHAR(255) NULL
		 , comp_from_pct FLOAT NULL
		 , comp_to_pct FLOAT NULL
		 , unit VARCHAR(10) NULL
		 , sequence_id INTEGER NULL
		 , comp_typical_pct FLOAT NULL
		 , date_added DATETIME NOT NULL
		 , added_by VARCHAR(100) NOT NULL
		 , date_modified DATETIME NOT NULL
		 , modified_by VARCHAR(100) NOT NULL
		 );

	INSERT INTO #tempFormXWCRComposition (form_id, revision_id
		 , comp_description, comp_from_pct, comp_to_pct, unit, sequence_id, comp_typical_pct
		 , date_added, added_by, date_modified, modified_by)
	SELECT form_id, revision_id
		 , comp_description, comp_from_pct, comp_to_pct, unit, sequence_id, comp_typical_pct
		 , SYSTEM_USER as added_by, GETDATE() as date_added, SYSTEM_USER as modified_by, GETDATE() as date_modified
	  FROM dbo.FormXWCRComposition
	 WHERE form_id = @temp_form_id
	   AND revision_id = @temp_rev_id;
		
	UPDATE #tempFormXWCRComposition
	   SET form_id = @form_id 
		 , revision_id = @revision_id;
		
	INSERT INTO dbo.FormXWCRComposition (form_id, revision_id
		 , comp_description, comp_from_pct, comp_to_pct, unit, sequence_id, comp_typical_pct
		 , date_added, added_by, date_modified, modified_by)
	SELECT form_id, revision_id
		 , comp_description, comp_from_pct, comp_to_pct, unit, sequence_id, comp_typical_pct
		 , date_added, added_by, date_modified, modified_by
	  FROM #tempFormXWCRComposition;

	DROP TABLE #tempFormXWCRComposition;


	--FormLDR
	CREATE TABLE #tempFormLDR (
		   form_id INTEGER NOT NULL
		 , revision_id INTEGER NOT NULL
		 , form_version_id INTEGER NULL
		 , customer_id_from_form INTEGER NULL
		 , customer_id INTEGER NULL
		 , app_id VARCHAR(20) NULL
		 , [status] CHAR(1) NOT NULL
		 , locked CHAR(1) NOT NULL
		 , [source] CHAR(1) NULL
		 , company_id INTEGER NULL
		 , profit_ctr_id INTEGER NULL
		 , signing_name VARCHAR(40) NULL
		 , signing_company VARCHAR(40) NULL
		 , signing_title VARCHAR(40) NULL
		 , signing_date DATETIME NULL
		 , created_by VARCHAR(100) NOT NULL
		 , date_created DATETIME NOT NULL
		 , modified_by VARCHAR(100) NOT NULL
		 , date_modified DATETIME NOT NULL
		 , generator_name VARCHAR(75) NULL
		 , generator_epa_id VARCHAR(12) NULL
		 , generator_address1 VARCHAR(40) NULL
		 , generator_city VARCHAR(40) NULL
		 , generator_state VARCHAR(2) NULL
		 , generator_zip VARCHAR(10) NULL
		 , state_manifest_no VARCHAR(20) NULL
		 , manifest_doc_no VARCHAR(20) NULL
		 , generator_id INTEGER NULL
		 , generator_address2 VARCHAR(40) NULL
		 , generator_address3 VARCHAR(40) NULL
		 , generator_address4 VARCHAR(40) NULL
		 , generator_address5 VARCHAR(40) NULL
		 , profitcenter_epa_id VARCHAR(12) NULL
		 , profitcenter_profit_ctr_name VARCHAR(50) NULL
		 , profitcenter_address_1 VARCHAR(40) NULL
		 , profitcenter_address_2 VARCHAR(40) NULL
		 , profitcenter_address_3 VARCHAR(40) NULL
		 , profitcenter_phone VARCHAR(14) NULL
		 , profitcenter_fax VARCHAR(14) NULL
		 , wcr_id INTEGER NULL
		 , wcr_rev_id INTEGER NULL
		 , ldr_notification_frequency CHAR(1) NULL
		 , waste_managed_id INTEGER NULL
		 );

	INSERT INTO #tempFormLDR (form_id, revision_id, form_version_id
		 , customer_id_from_form, customer_id, app_id, [status], locked, [source]
		 , company_id, profit_ctr_id, signing_name, signing_company, signing_title, signing_date
		 , created_by, date_created, modified_by, date_modified
		 , generator_name, generator_epa_id, generator_address1, generator_city, generator_state, generator_zip, state_manifest_no, manifest_doc_no
		 , generator_id, generator_address2, generator_address3, generator_address4, generator_address5, profitcenter_epa_id
		 , profitcenter_profit_ctr_name, profitcenter_address_1, profitcenter_address_2, profitcenter_address_3, profitcenter_phone, profitcenter_fax
		 , wcr_id, wcr_rev_id, ldr_notification_frequency, waste_managed_id)
	SELECT form_id, revision_id, form_version_id
		 , customer_id_from_form, customer_id, app_id, [status], locked, [source]
		 , company_id, profit_ctr_id, signing_name, signing_company, signing_title, signing_date
		 , SYSTEM_USER as added_by, GETDATE() as date_added, SYSTEM_USER as modified_by, GETDATE() as date_modified
		 , generator_name, generator_epa_id, generator_address1, generator_city, generator_state, generator_zip, state_manifest_no, manifest_doc_no
		 , generator_id, generator_address2, generator_address3, generator_address4, generator_address5, profitcenter_epa_id
		 , profitcenter_profit_ctr_name, profitcenter_address_1, profitcenter_address_2, profitcenter_address_3, profitcenter_phone, profitcenter_fax
		 , wcr_id, wcr_rev_id, ldr_notification_frequency, waste_managed_id
	  FROM dbo.FormLDR
	 WHERE wcr_id = @temp_form_id
	   AND wcr_rev_id = @temp_rev_id;

	IF @@ROWCOUNT > 0
		BEGIN		
			SELECT @temp_ldr_id = form_id
			  FROM dbo.FormLDR
			 WHERE wcr_id = @temp_form_id
			   AND wcr_rev_id = @temp_rev_id;

			EXEC @ldr_form_id = sp_Sequence_Next 'Form.Form_ID';
		
			UPDATE #tempFormLDR
			   SET form_id = @ldr_form_id 
			     , revision_id = @revision_id
			     , wcr_id = @form_id
			     , wcr_rev_id = @revision_id;

			INSERT INTO dbo.FormLDR (form_id, revision_id, form_version_id
				 , customer_id_from_form, customer_id, app_id, [status], locked, [source]
				 , company_id, profit_ctr_id, signing_name, signing_company, signing_title, signing_date
				 , created_by, date_created, modified_by, date_modified
				 , generator_name, generator_epa_id, generator_address1, generator_city, generator_state, generator_zip, state_manifest_no, manifest_doc_no
				 , generator_id, generator_address2, generator_address3, generator_address4, generator_address5, profitcenter_epa_id
				 , profitcenter_profit_ctr_name, profitcenter_address_1, profitcenter_address_2, profitcenter_address_3, profitcenter_phone, profitcenter_fax
				 , wcr_id, wcr_rev_id, ldr_notification_frequency, waste_managed_id)
			SELECT form_id, revision_id, form_version_id
				 , customer_id_from_form, customer_id, app_id, [status], locked, [source]
				 , company_id, profit_ctr_id, signing_name, signing_company, signing_title, signing_date
				 , created_by, date_created, modified_by, date_modified
				 , generator_name, generator_epa_id, generator_address1, generator_city, generator_state, generator_zip, state_manifest_no, manifest_doc_no
				 , generator_id, generator_address2, generator_address3, generator_address4, generator_address5, profitcenter_epa_id
				 , profitcenter_profit_ctr_name, profitcenter_address_1, profitcenter_address_2, profitcenter_address_3, profitcenter_phone, profitcenter_fax
				 , wcr_id, wcr_rev_id, ldr_notification_frequency, waste_managed_id
			  FROM #tempFormLDR;
		END

	DROP TABLE #tempFormLDR;


	--FormLDRDetail
	CREATE TABLE #tempFormLDRDetail (
		   form_id INTEGER NOT NULL
		 , revision_id INTEGER NOT NULL
		 , form_version_id INTEGER NULL
		 , page_number INTEGER NULL
		 , manifest_line_item INTEGER NULL
		 , ww_or_nww CHAR(3) NULL
		 , subcategory VARCHAR(80) NULL
		 , manage_id INTEGER NULL
		 , approval_code VARCHAR(40) NULL
		 , approval_key INTEGER NULL
		 , company_id INTEGER NULL
		 , profit_ctr_id INTEGER NULL
		 , profile_id INTEGER NULL
		 , constituents_requiring_treatment_flag CHAR(1) NULL
		 , added_by VARCHAR(100) NOT NULL
		 , date_added DATETIME NOT NULL
		 , modified_by VARCHAR(100) NOT NULL
		 , date_modified DATETIME NOT NULL
		 );

	INSERT INTO #tempFormLDRDetail (form_id, revision_id, form_version_id, page_number, manifest_line_item
		 , ww_or_nww, subcategory, manage_id, approval_code, approval_key
		 , company_id, profit_ctr_id, profile_id, constituents_requiring_treatment_flag
		 , added_by, date_added, modified_by, date_modified)
	SELECT form_id, revision_id, form_version_id, page_number, manifest_line_item
		 , ww_or_nww, subcategory, manage_id, approval_code, approval_key
		 , company_id, profit_ctr_id, profile_id, constituents_requiring_treatment_flag
		 , SYSTEM_USER as added_by, GETDATE() as date_added, SYSTEM_USER as modified_by, GETDATE() as date_modified
	  FROM dbo.FormLDRDetail
	 WHERE form_id = @temp_ldr_id
	   AND revision_id = @temp_rev_id;
	
	UPDATE #tempFormLDRDetail
	   SET form_id = @ldr_form_id 
		 , revision_id = @revision_id;

	INSERT INTO dbo.FormLDRDetail (form_id, revision_id, form_version_id, page_number, manifest_line_item
		 , ww_or_nww, subcategory, manage_id, approval_code, approval_key
		 , company_id, profit_ctr_id, profile_id, constituents_requiring_treatment_flag
		 , added_by, date_added, modified_by, date_modified)
	SELECT form_id, revision_id, form_version_id, page_number, manifest_line_item
		 , ww_or_nww, subcategory, manage_id, approval_code, approval_key
		 , company_id, profit_ctr_id, profile_id, constituents_requiring_treatment_flag
		 , added_by, date_added, modified_by, date_modified
	  FROM #tempFormLDRDetail;

	DROP TABLE #tempFormLDRDetail


	--FormNORMTENORM
	CREATE TABLE #tempFormNORMTENORM (
		   form_id INTEGER NULL
		 , revision_id INTEGER NULL
		 , version_id INTEGER NULL
		 , [status] CHAR(1) NULL
		 , locked CHAR(1) NULL
		 , [source] CHAR(1) NULL
		 , profit_ctr_id INTEGER NULL
		 , company_id INTEGER NULL
		 , profile_id INTEGER NULL
		 , approval_code VARCHAR(15) NULL
		 , generator_id INTEGER NULL
		 , generator_epa_id VARCHAR(12) NULL
		 , generator_name VARCHAR(75) NULL
		 , generator_address_1 VARCHAR(40) NULL
		 , generator_address_2 VARCHAR(40) NULL
		 , generator_address_3 VARCHAR(40) NULL
		 , generator_address_4 VARCHAR(40) NULL
		 , generator_address_5 VARCHAR(40) NULL
		 , generator_city VARCHAR(40) NULL
		 , generator_state VARCHAR(2) NULL
		 , generator_zip_code VARCHAR(15) NULL
		 , site_name VARCHAR(40) NULL
		 , gen_mail_addr1 VARCHAR(40) NULL
		 , gen_mail_addr2 VARCHAR(40) NULL
		 , gen_mail_addr3 VARCHAR(40) NULL
		 , gen_mail_addr4 VARCHAR(40) NULL
		 , gen_mail_addr5 VARCHAR(40) NULL
		 , gen_mail_city VARCHAR(40) NULL
		 , gen_mail_state VARCHAR(2) NULL
		 , gen_mail_zip VARCHAR(15) NULL
		 , NORM CHAR(1) NULL
		 , TENORM CHAR(1) NULL
		 , disposal_restriction_exempt CHAR(1) NULL
		 , nuclear_reg_state_license CHAR(1) NULL
		 , waste_process VARCHAR(2000) NULL
		 , unit_other VARCHAR(100) NULL
		 , shipping_dates VARCHAR(255) NULL
		 , signing_name VARCHAR(40) NULL
		 , signing_company VARCHAR(40) NULL
		 , signing_title VARCHAR(40) NULL
		 , signing_date DATETIME NULL
		 , date_created DATETIME NOT NULL
		 , date_modified DATETIME NOT NULL
		 , created_by VARCHAR(100) NOT NULL
		 , modified_by VARCHAR(100) NOT NULL
		 , formWCR_uid INTEGER NULL
		 , wcr_id INTEGER NULL
		 , wcr_rev_id INTEGER NULL
		 );

	INSERT INTO #tempFormNORMTENORM (form_id, revision_id, version_id
		 , [status], locked, [source], profit_ctr_id, company_id, profile_id, approval_code
		 , generator_id, generator_epa_id
		 , generator_name, generator_address_1, generator_address_2, generator_address_3, generator_address_4, generator_address_5
		 , generator_city, generator_state, generator_zip_code
		 , site_name, gen_mail_addr1, gen_mail_addr2, gen_mail_addr3, gen_mail_addr4, gen_mail_addr5
		 , gen_mail_city, gen_mail_state, gen_mail_zip
		 , NORM, TENORM, disposal_restriction_exempt, nuclear_reg_state_license, waste_process, unit_other
		 , shipping_dates, signing_name, signing_company, signing_title, signing_date
		 , date_created, date_modified, created_by, modified_by
		 , formWCR_uid, wcr_id, wcr_rev_id)
	SELECT form_id, revision_id, version_id
		 , [status], locked, [source], profit_ctr_id, company_id, profile_id, approval_code
		 , generator_id, generator_epa_id
		 , generator_name, generator_address_1, generator_address_2, generator_address_3, generator_address_4, generator_address_5
		 , generator_city, generator_state, generator_zip_code
		 , site_name, gen_mail_addr1, gen_mail_addr2, gen_mail_addr3, gen_mail_addr4, gen_mail_addr5
		 , gen_mail_city, gen_mail_state, gen_mail_zip
		 , NORM, TENORM, disposal_restriction_exempt, nuclear_reg_state_license, waste_process, unit_other
		 , shipping_dates, signing_name, signing_company, signing_title, signing_date
		 , GETDATE() as date_created, GETDATE() as date_modified, SYSTEM_USER as created_by, SYSTEM_USER as modified_by
		 , formWCR_uid, wcr_id, wcr_rev_id
	  FROM dbo.FormNORMTENORM
	 WHERE wcr_id = @temp_form_id
	   AND wcr_rev_id = @temp_rev_id;

	IF @@ROWCOUNT > 0
		BEGIN
		
			EXEC @ntn_form_id = sp_Sequence_Next 'Form.Form_ID';
		
			UPDATE #tempFormNORMTENORM
			   SET form_id = @ntn_form_id 
				 , revision_id = @revision_id
				 , wcr_id = @form_id
				 , wcr_rev_id = @revision_id
				 , formWCR_uid = @NewFormWCR_uid
				 ;

			INSERT INTO dbo.FormNORMTENORM (form_id, revision_id, version_id
				 , [status], locked, [source], profit_ctr_id, company_id, profile_id, approval_code
				 , generator_id, generator_epa_id
				 , generator_name, generator_address_1, generator_address_2, generator_address_3, generator_address_4, generator_address_5
				 , generator_city, generator_state, generator_zip_code
				 , site_name, gen_mail_addr1, gen_mail_addr2, gen_mail_addr3, gen_mail_addr4, gen_mail_addr5
				 , gen_mail_city, gen_mail_state, gen_mail_zip
				 , NORM, TENORM, disposal_restriction_exempt, nuclear_reg_state_license, waste_process, unit_other
				 , shipping_dates, signing_name, signing_company, signing_title, signing_date
				 , date_created, date_modified, created_by, modified_by
				 , formWCR_uid, wcr_id, wcr_rev_id)
		
			SELECT form_id, revision_id, version_id
				 , [status], locked, [source], profit_ctr_id, company_id, profile_id, approval_code
				 , generator_id, generator_epa_id
				 , generator_name, generator_address_1, generator_address_2, generator_address_3, generator_address_4, generator_address_5
				 , generator_city, generator_state, generator_zip_code
				 , site_name, gen_mail_addr1, gen_mail_addr2, gen_mail_addr3, gen_mail_addr4, gen_mail_addr5
				 , gen_mail_city, gen_mail_state, gen_mail_zip
				 , NORM, TENORM, disposal_restriction_exempt, nuclear_reg_state_license, waste_process, unit_other
				 , shipping_dates, signing_name, signing_company, signing_title, signing_date
				 , date_created, date_modified, created_by, modified_by
				 , formWCR_uid, wcr_id, wcr_rev_id
			  FROM #tempFormNORMTENORM;
		END

	DROP TABLE #tempFormNORMTENORM;

END;
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
GO
