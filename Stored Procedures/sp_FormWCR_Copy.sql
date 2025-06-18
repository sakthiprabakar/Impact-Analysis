ALTER PROCEDURE dbo.sp_FormWCR_Copy 
	  @form_id INTEGER
	, @revision_id INTEGER
	, @web_user_id VARCHAR(100)
	, @modified_by_web_user_id VARCHAR(100) = ''
	, @Message VARCHAR(100) OUTPUT
	, @formId INTEGER OUTPUT
	, @rev_id INTEGER OUTPUT
AS
/* ******************************************************************
    Updated By    : Nallaperumal C
    Updated On    : 14-october-2023
    Type          : Store Procedure 
    Object Name	  : [sp_FormWCR_Copy]
	Ticket        : 73641
	Updated By   : Sathiyamoorthi M
	Updated On   : 03-March-2024
	Ticket       : 79675
	Updated By   : Ashothaman P
	Updated On   : 09/12/2024
	Ticket       : 100049
	--Updated by Blair Christensen for Titan 05/21/2025

This procedure is used to copy FormWCR table i.e. for the pending profile

inputs: @formid, @revision_ID, @web_user_id

Samples:
 EXEC sp_FormWCR_SubmitProfile @form_id,@revision_ID,@web_user_id
 DECLARE @Message nvarchar(1000),@formId int,@rev_id int
 EXEC sp_FormWCR_Copy 786742, 1,'manand84',@Message,@formId,@rev_id
 select @Message, @formId

****************************************************************** */
BEGIN
	SET NOCOUNT ON;

	-- Generate new Form ID and dfault revision ID = 1
	DECLARE @new_form_id INTEGER
		  , @revisonid INTEGER = 1
		  , @display_status_uid INTEGER = 1
		  , @source_form_id INTEGER
		  , @source_revision_id INTEGER
		  , @radioactiveUSEI_form_id INTEGER
		  , @radioactiveUSEI_revision_id INTEGER
		  , @radioactiveUSEI_new_form_id INTEGER
		  , @print_name VARCHAR(41)
		  , @contact_company VARCHAR(75)
		  , @title VARCHAR(35)
		  , @template_form_id INTEGER
		  , @FormWCR_uid INTEGER;

	SET @source_form_id = @form_id
	SET @source_revision_id = @revision_id

	SELECT TOP 1 @print_name = first_name + ' ' + last_name
		 , @title = title
		 , @contact_company = contact_company
	  FROM dbo.Contact
	 WHERE web_userid = @web_user_id
	   AND web_access_flag = 'T'
	   AND contact_status = 'A';

	IF ISNULL(@modified_by_web_user_id, '') = ''
		BEGIN
			SET @modified_by_web_user_id = @web_user_id
		END

	SET @template_form_id = (SELECT TOP 1 template_form_id FROM dbo.FormWCR WHERE form_id = @form_id);

	IF @template_form_id IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.FormWCRTemplate WHERE template_form_id = @template_form_id)
		BEGIN
			SET @template_form_id = NULL;
		END

	EXEC @new_form_id = sp_sequence_next 'form.form_id';
  
	BEGIN TRY  
		INSERT INTO dbo.FormWCR (form_id, revision_id
			, form_version_id, customer_id_from_form, customer_id, app_id, tracking_id
			, [status], locked, [source]																	--10
			, signing_name, signing_company, signing_title, signing_date
			, date_created, date_modified, created_by, modified_by
			, comments, sample_id, cust_name, cust_addr1, cust_addr2, cust_addr3, cust_addr4, cust_city, cust_state, cust_zip, cust_country		--29
			, inv_contact_name, inv_contact_phone, inv_contact_fax
			, tech_contact_name, tech_contact_phone, tech_contact_fax, tech_contact_mobile, tech_contact_pager, tech_cont_email
			, generator_id, EPA_ID, sic_code
			, generator_name, generator_address1, generator_address2, generator_address3, generator_address4
			, generator_city, generator_state, generator_zip, generator_county_id, generator_county_name					--51
			, gen_mail_address1 , gen_mail_address2, gen_mail_address3, gen_mail_city, gen_mail_state, gen_mail_zip, generator_contact, generator_contact_title, generator_phone, generator_fax
			, waste_common_name, volume, frequency, dot_shipping_name, surcharge_exempt
			, pack_bulk_solid_yard, pack_bulk_solid_ton, pack_bulk_liquid, pack_totes, pack_totes_size, pack_cy_box, pack_drum, pack_other, pack_other_desc		--75
			, color, odor, poc, consistency_solid, consistency_dust, consistency_liquid, consistency_sludge
			, ph, ph_lte_2, ph_gt_2_lt_5, ph_gte_5_lte_10, ph_gt_10_lt_12_5, ph_gte_12_5, ignitability, waste_contains_spec_hand_none
			, free_liquids, oily_residue, metal_fines, biodegradable_sorbents, amines, ammonia, dioxins, furans, biohazard						--99
			, shock_sensitive_waste, reactive_waste, radioactive_waste, explosives, pyrophoric_waste, isocyanates
			, asbestos_friable, asbestos_non_friable, gen_process, rcra_listed, rcra_listed_comment, rcra_characteristic, rcra_characteristic_comment
			, state_waste_code_flag, state_waste_code_flag_comment, wastewater_treatment, exceed_ldr_standards, meets_alt_soil_treatment_stds
			, more_than_50_pct_debris, oxidizer, react_cyanide, react_sulfide, info_basis														--122
			, D004, D005, D006, D007, D008, D009, D010, D011, D012, D013, D014, D015, D016, D017, D018, D019
			, D020, D021, D022, D023, D024, D025, D026, D027, D028, D029, D030, D031, D032, D033, D034, D035, D036, D037, D038, D039, D040, D041, D042, D043	--162
			, D004_concentration, D005_concentration, D006_concentration, D007_concentration, D008_concentration, D009_concentration
			, D010_concentration, D011_concentration, D012_concentration, D013_concentration, D014_concentration
			, D015_concentration, D016_concentration, D017_concentration, D018_concentration, D019_concentration
			, D020_concentration, D021_concentration, D022_concentration, D023_concentration, D024_concentration
			, D025_concentration, D026_concentration, D027_concentration, D028_concentration, D029_concentration
			, D030_concentration, D031_concentration, D032_concentration, D033_concentration, D034_concentration
			, D035_concentration, D036_concentration, D037_concentration, D038_concentration, D039_concentration
			, D040_concentration, D041_concentration, D042_concentration, D043_concentration									--202
			, underlying_haz_constituents, michigan_non_haz, michigan_non_haz_comment, universal, recyclable_commodity, recoverable_petroleum_product
			, used_oil, pcb_concentration, pcb_source_concentration_gr_50, processed_into_non_liquid, processd_into_nonlqd_prior_pcb
			, pcb_non_lqd_contaminated_media, pcb_manufacturer, pcb_article_decontaminated, ccvocgr500, benzene, neshap_sic, tab_gr_10, avg_h20_gr_10	--221
			, tab, benzene_gr_1, benzene_concentration, benzene_unit, fuel_blending, btu_per_lb, pct_chlorides, pct_moisture, pct_solids
			, intended_for_reclamation, pack_drum_size, water_reactive, aluminum, subject_to_mact_neshap, subject_to_mact_neshap_codes
			, srec_exempt_id, ldr_ww_or_nww, ldr_subcategory, ldr_manage_id
			, wwa_info_basis, wwa_bis_phthalate_flag, wwa_bis_phthalate_actual, wwa_carbazole_flag, wwa_carbazole_actual
			, wwa_o_cresol_flag, wwa_o_cresol_actual, wwa_p_cresol_flag, wwa_p_cresol_actual, wwa_n_decane_flag, wwa_n_decane_actual			--250
			, wwa_fluoranthene_flag, wwa_fluoranthene_actual, wwa_n_octadecane_flag, wwa_n_octadecane_actual
			, wwa_trichlorophenol_246_flag, wwa_trichlorophenol_246_actual, wwa_phosphorus_flag, wwa_phosphorus_actual
			, wwa_total_chlor_phen_flag, wwa_total_chlor_phen_actual, wwa_total_organic_actual, wwa_pcb_flag, wwa_pcb_actual
			, wwa_acidity_flag, wwa_acidity_actual, wwa_fog_flag, wwa_fog_actual, wwa_tss_flag, wwa_tss_actual
			, wwa_bod_flag, wwa_bod_actual, wwa_antimony_flag, wwa_antimony_actual, wwa_arsenic_flag, wwa_arsenic_actual
			, wwa_cadmium_flag, wwa_cadmium_actual, wwa_chromium_flag, wwa_chromium_actual, wwa_cobalt_flag, wwa_cobalt_actual
			, wwa_copper_flag, wwa_copper_actual, wwa_cyanide_flag, wwa_cyanide_actual, wwa_iron_flag, wwa_iron_actual
			, wwa_lead_flag, wwa_lead_actual, wwa_mercury_flag, wwa_mercury_actual, wwa_nickel_flag, wwa_nickel_actual
			, wwa_silver_flag, wwa_silver_actual, wwa_tin_flag, wwa_tin_actual, wwa_titanium_flag, wwa_titanium_actual
			, wwa_vanadium_flag, wwa_vanadium_actual, wwa_zinc_flag, wwa_zinc_actual, wwa_method_8240, wwa_method_8270, wwa_method_8080, wwa_method_8150	--306
			, wwa_used_oil, wwa_oil_mixed, wwa_halogen_gt_1000, wwa_halogen_source, wwa_halogen_source_desc1, wwa_other_desc_1
			, profile_id, facility_instruction, emergency_phone_number, generator_email, frequency_other, hazmat_flag, hazmat_class
			, subsidiary_haz_mat_class, package_group, un_na_flag, un_na_number, erg_number, erg_suffix, dot_shipping_desc
			, reportable_quantity_flag, RQ_reason, odor_other_desc, consistency_debris, consistency_gas_aerosol, consistency_varies
			, pH_NA, ignitability_lt_90, ignitability_90_139, ignitability_140_199, ignitability_gte_200, ignitability_NA
			, air_reactive, temp_ctrl_org_peroxide, NORM, TENORM, handling_issue, handling_issue_desc, rcra_exempt_flag, RCRA_exempt_reason					--346
			, cyanide_plating, EPA_source_code, EPA_form_code, waste_water_flag, debris_dimension_weight
			, info_basis_knowledge, info_basis_analysis, info_basis_msds, universal_recyclable_commodity
			, pcb_concentration_none, pcb_concentration_0_49, pcb_concentration_50_499, pcb_concentration_500, ddvohapgr500									--360
			, neshap_chem_1, neshap_chem_2, neshap_standards_part, neshap_subpart, benzene_onsite_mgmt, benzene_onsite_mgmt_desc
			, copy_source, source_form_id, source_revision_id
			, tech_contact_id, generator_contact_id, inv_contact_id, template_form_id
			, date_last_profile_sync, manifest_dot_sp_number, generator_country
			, gen_mail_name, gen_mail_address4, gen_mail_country, generator_type_ID										--380
			, NAICS_code, state_id, po_required, purchase_order, inv_contact_email
			, DOT_shipping_desc_additional, DOT_inhalation_haz_flag
			, container_type_bulk, container_type_totes, container_type_pallet, container_type_boxes, container_type_drums, container_type_cylinder
			, container_type_labpack, container_type_combination, container_type_combination_desc, container_type_other, container_type_other_desc
			, odor_strength
			, odor_type_ammonia, odor_type_amines, odor_type_mercaptans, odor_type_sulfur, odor_type_organic_acid, odor_type_other				--405
			, liquid_phase, paint_filter_solid_flag, incidental_liquid_flag
			, ignitability_compare_symbol, ignitability_compare_temperature, ignitability_does_not_flash, ignitability_flammable_solid
			, texas_waste_material_type, texas_state_waste_code, PA_residual_waste_flag, react_sulfide_ppm, react_cyanide_ppm
			, radioactive, reactive_other_description, reactive_other, contains_pcb, dioxins_or_furans, metal_fines_powder_paste
			, temp_control, thermally_unstable, compressed_gas, tires, organic_peroxide, beryllium_present, asbestos_flag, asbestos_friable_flag
			, hazardous_secondary_material, hazardous_secondary_material_cert, pharma_waste_subject_to_prescription
			, waste_treated_after_generation, waste_treated_after_generation_desc, debris_separated, debris_not_mixed_or_diluted
			, origin_refinery, specific_technology_requested, requested_technology, other_restrictions_requested, thermal_process_flag				--443
			, DOT_sp_permit_flag, DOT_sp_permit_text, BTU_lt_gt_5000, ammonia_flag
			, pcb_concentration_0_9, pcb_concentration_10_49, pcb_regulated_for_disposal_under_TSCA, pcb_article_for_TSCA_landfill
			, display_status_uid, RCRA_waste_code_flag, RQ_threshold
			, submitted_by, date_submitted, DOT_waste_flag
			, section_F_none_apply_flag, routing_facility, waste_meets_ldr_standards
			, signed_on_behalf_of, PFAS_Flag, approval_code											--464
			)
		SELECT @new_form_id as form_id, @revisonid as revision_id 
			 , f.form_version_id, f.customer_id_from_form, f.customer_id, f.app_id, f.tracking_id  
			 , f.[status], f.locked, f.[source]														--10
			 , COALESCE(NULLIF(f.signing_name, ''), @print_name) as signing_name
			 , COALESCE(NULLIF(f.signing_company, ''), @contact_company) as signing_company
			 , COALESCE(NULLIF(f.signing_title, ''), @title) as signing_title
			 , NULL as signing_date
			 , GETDATE() as date_created, GETDATE() as date_modified, @web_user_id as created_by, @modified_by_web_user_id as modified_by			--18
			 , f.comments, f.sample_id, f.cust_name, f.cust_addr1, f.cust_addr2, f.cust_addr3, f.cust_addr4, f.cust_city, f.cust_state, f.cust_zip, f.cust_country		--29
			 , f.inv_contact_name, f.inv_contact_phone, f.inv_contact_fax
			 ,  f.tech_contact_name,  f.tech_contact_phone,  f.tech_contact_fax, f.tech_contact_mobile, f.tech_contact_pager, f.tech_cont_email			--38
			 , f.generator_id, f.EPA_ID, f.sic_code				--41
			 , ISNULL(g.generator_name, f.generator_name) as generator_name
			 , ISNULL(g.generator_address_1, f.generator_address1) as generator_address1
			 , ISNULL(g.generator_address_2, f.generator_address2) as generator_address2
			 , ISNULL(g.generator_address_3, f.generator_address3) as generator_address3
			 , ISNULL(g.generator_address_4, f.generator_address4) as generator_address4
			 , ISNULL(g.generator_city, f.generator_city) as generator_city
			 , ISNULL(g.generator_state, f.generator_state) as generator_state
			 , ISNULL(g.generator_zip_code, f.generator_zip) as  generator_zip
			 , f.generator_county_id								--50
			 , f.generator_county_name  
			 , ISNULL(g.gen_mail_addr1, f.gen_mail_address1) as gen_mail_address1
			 , ISNULL(g.gen_mail_addr2, f.gen_mail_address2) as gen_mail_address2
			 , ISNULL(g.gen_mail_addr3, f.gen_mail_address3) as gen_mail_address3
			 , ISNULL(g.gen_mail_city, f.gen_mail_city) as gen_mail_city
			 , ISNULL(g.gen_mail_state, f.gen_mail_state) as gen_mail_state
			 , ISNULL(g.gen_mail_zip_code, f.gen_mail_zip) as gen_mail_zip
			 , f.generator_contact  
			 , f.generator_contact_title  
			 , ISNULL(g.generator_phone, f.generator_phone) as generator_phone						--60
			 , ISNULL(g.generator_fax, f.generator_fax) as generator_fax
			 , f.waste_common_name, f.volume, f.frequency, f.dot_shipping_name, f.surcharge_exempt				--66
			 , f.pack_bulk_solid_yard, f.pack_bulk_solid_ton, f.pack_bulk_liquid, f.pack_totes, f.pack_totes_size
			 , f.pack_cy_box, f.pack_drum, f.pack_other, f.pack_other_desc						--75
			 , f.color, f.odor, f.poc, f.consistency_solid, f.consistency_dust, f.consistency_liquid, f.consistency_sludge				--82
			 , f.ph, f.ph_lte_2, f.ph_gt_2_lt_5, f.ph_gte_5_lte_10, f.ph_gt_10_lt_12_5, f.ph_gte_12_5, f.ignitability, f.waste_contains_spec_hand_none		--90
			 , f.free_liquids, f.oily_residue, f.metal_fines, f.biodegradable_sorbents, f.amines, f.ammonia, f.dioxins, f.furans, f.biohazard				--99

			 , f.shock_sensitive_waste, f.reactive_waste, f.radioactive_waste, f.explosives, f.pyrophoric_waste, f.isocyanates
			 , f.asbestos_friable, f.asbestos_non_friable, f.gen_process, f.rcra_listed, f.rcra_listed_comment, f.rcra_characteristic, f.rcra_characteristic_comment	--112
			 , f.state_waste_code_flag, f.state_waste_code_flag_comment, f.wastewater_treatment, f.exceed_ldr_standards, f.meets_alt_soil_treatment_stds
			 , f.more_than_50_pct_debris, f.oxidizer, f.react_cyanide, f.react_sulfide, f.info_basis							--122
			 , f.D004, f.D005, f.D006, f.D007, f.D008, f.D009, f.D010, f.D011, f.D012, f.D013, f.D014, f.D015, f.D016, f.D017, f.D018, f.D019			--138
			 , f.D020, f.D021, f.D022, f.D023, f.D024, f.D025, f.D026, f.D027, f.D028, f.D029								--148
			 , f.D030, f.D031, f.D032, f.D033, f.D034, f.D035, f.D036, f.D037, f.D038, f.D039, f.D040, f.D041, f.D042, f.D043		--162
			 , f.D004_concentration, f.D005_concentration, f.D006_concentration, f.D007_concentration, f.D008_concentration, f.D009_concentration
			 , f.D010_concentration, f.D011_concentration, f.D012_concentration, f.D013_concentration, f.D014_concentration
			 , f.D015_concentration, f.D016_concentration, f.D017_concentration, f.D018_concentration, f.D019_concentration
			 , f.D020_concentration, f.D021_concentration, f.D022_concentration, f.D023_concentration, f.D024_concentration
			 , f.D025_concentration, f.D026_concentration, f.D027_concentration, f.D028_concentration, f.D029_concentration
			 , f.D030_concentration, f.D031_concentration, f.D032_concentration, f.D033_concentration, f.D034_concentration
			 , f.D035_concentration, f.D036_concentration, f.D037_concentration, f.D038_concentration, f.D039_concentration
			 , f.D040_concentration, f.D041_concentration, f.D042_concentration, f.D043_concentration								--202

			 , f.underlying_haz_constituents, f.michigan_non_haz, f.michigan_non_haz_comment, f.universal, f.recyclable_commodity, f.recoverable_petroleum_product
			 , f.used_oil, f.pcb_concentration, f.pcb_source_concentration_gr_50, f.processed_into_non_liquid, f.processd_into_nonlqd_prior_pcb			--213
			 , f.pcb_non_lqd_contaminated_media, f.pcb_manufacturer, f.pcb_article_decontaminated, f.ccvocgr500, f.benzene, f.neshap_sic, f.tab_gr_10, f.avg_h20_gr_10		--221
			 , f.tab, f.benzene_gr_1, f.benzene_concentration, f.benzene_unit, f.fuel_blending, f.btu_per_lb, f.pct_chlorides, f.pct_moisture, f.pct_solids			--230
			 , f.intended_for_reclamation, f.pack_drum_size, f.water_reactive, f.aluminum, f.subject_to_mact_neshap, f.subject_to_mact_neshap_codes					--236
			 , f.srec_exempt_id, f.ldr_ww_or_nww, f.ldr_subcategory, f.ldr_manage_id												--240
			 , f.wwa_info_basis, f.wwa_bis_phthalate_flag, f.wwa_bis_phthalate_actual, f.wwa_carbazole_flag, f.wwa_carbazole_actual
			 , f.wwa_o_cresol_flag, f.wwa_o_cresol_actual, f.wwa_p_cresol_flag, f.wwa_p_cresol_actual, f.wwa_n_decane_flag, f.wwa_n_decane_actual		--251
			 , f.wwa_fluoranthene_flag, f.wwa_fluoranthene_actual, f.wwa_n_octadecane_flag, f.wwa_n_octadecane_actual				--255
			 , f.wwa_trichlorophenol_246_flag, f.wwa_trichlorophenol_246_actual, f.wwa_phosphorus_flag, f.wwa_phosphorus_actual
			 , f.wwa_total_chlor_phen_flag, f.wwa_total_chlor_phen_actual, f.wwa_total_organic_actual, f.wwa_pcb_flag, f.wwa_pcb_actual
			 , f.wwa_acidity_flag, f.wwa_acidity_actual, f.wwa_fog_flag, f.wwa_fog_actual, f.wwa_tss_flag, f.wwa_tss_actual					--270
			 , f.wwa_bod_flag, f.wwa_bod_actual, f.wwa_antimony_flag, f.wwa_antimony_actual, f.wwa_arsenic_flag, f.wwa_arsenic_actual
			 , f.wwa_cadmium_flag, f.wwa_cadmium_actual, f.wwa_chromium_flag, f.wwa_chromium_actual, f.wwa_cobalt_flag, f.wwa_cobalt_actual
			 , f.wwa_copper_flag, f.wwa_copper_actual, f.wwa_cyanide_flag, f.wwa_cyanide_actual, f.wwa_iron_flag, f.wwa_iron_actual
			 , f.wwa_lead_flag, f.wwa_lead_actual, f.wwa_mercury_flag, f.wwa_mercury_actual, f.wwa_nickel_flag, f.wwa_nickel_actual
			 , f.wwa_silver_flag, f.wwa_silver_actual, f.wwa_tin_flag, f.wwa_tin_actual, f.wwa_titanium_flag, f.wwa_titanium_actual			--300

			 , f.wwa_vanadium_flag, f.wwa_vanadium_actual, f.wwa_zinc_flag, f.wwa_zinc_actual, f.wwa_method_8240, f.wwa_method_8270, f.wwa_method_8080, f.wwa_method_8150
			 , f.wwa_used_oil, f.wwa_oil_mixed, f.wwa_halogen_gt_1000, f.wwa_halogen_source, f.wwa_halogen_source_desc1, f.wwa_other_desc_1
			 , NULL as profile_id, f.facility_instruction, f.emergency_phone_number, f.generator_email, f.frequency_other, f.hazmat_flag, f.hazmat_class			--321
			 , f.subsidiary_haz_mat_class, f.package_group, f.un_na_flag, f.un_na_number, f.erg_number, f.erg_suffix, f.dot_shipping_desc
			 , f.reportable_quantity_flag, f.RQ_reason, f.odor_other_desc, f.consistency_debris, f.consistency_gas_aerosol, f.consistency_varies
			 , f.pH_NA, f.ignitability_lt_90, f.ignitability_90_139, f.ignitability_140_199, f.ignitability_gte_200, f.ignitability_NA							--340
			 , f.air_reactive, f.temp_ctrl_org_peroxide, f.NORM, f.TENORM, f.handling_issue, f.handling_issue_desc, f.rcra_exempt_flag, f.RCRA_exempt_reason
			 , f.cyanide_plating, f.EPA_source_code, f.EPA_form_code, f.waste_water_flag, f.debris_dimension_weight
			 , f.info_basis_knowledge, f.info_basis_analysis, f.info_basis_msds, f.universal_recyclable_commodity								--357
			 , f.pcb_concentration_none, f.pcb_concentration_0_49, f.pcb_concentration_50_499, f.pcb_concentration_500, f.ddvohapgr500
			 , f.neshap_chem_1, f.neshap_chem_2, f.neshap_standards_part, f.neshap_subpart, f.benzene_onsite_mgmt, f.benzene_onsite_mgmt_desc
			 , 'Copy' as copy_source, @source_form_id as source_form_id, @source_revision_id as source_revision_id
			 , f.tech_contact_id, f.generator_contact_id, f.inv_contact_id, @template_form_id									--375
			 , f.date_last_profile_sync, f.manifest_dot_sp_number, f.generator_country
			 , COALESCE(f.gen_mail_name, g.gen_mail_name) as gen_mail_name, f.gen_mail_address4, f.gen_mail_country, f.generator_type_ID
			 , ISNULL(g.NAICS_code, f.NAICS_code) as NAICS_code, f.state_id, f.po_required, f.purchase_order, f.inv_contact_email
			 , f.DOT_shipping_desc_additional, f.DOT_inhalation_haz_flag							--389
			 , f.container_type_bulk, f.container_type_totes, f.container_type_pallet, f.container_type_boxes, f.container_type_drums, f.container_type_cylinder
			 , f.container_type_labpack, f.container_type_combination, f.container_type_combination_desc, f.container_type_other, f.container_type_other_desc			--400

			 , CASE WHEN (f.odor_strength = 'N' AND 
							(f.odor_type_ammonia = 'T'
								OR f.odor_type_amines = 'T'
								OR f.odor_type_mercaptans = 'T'
								OR f.odor_type_sulfur = 'T'
								OR f.odor_type_organic_acid = 'T'
								OR f.odor_type_other = 'T'
							)
						) THEN NULL
				    ELSE f.odor_strength
				END as odor_strength
			 , f.odor_type_ammonia, f.odor_type_amines, f.odor_type_mercaptans, f.odor_type_sulfur, f.odor_type_organic_acid, f.odor_type_other
			 , f.liquid_phase, f.paint_filter_solid_flag, f.incidental_liquid_flag
			 , f.ignitability_compare_symbol, f.ignitability_compare_temperature, f.ignitability_does_not_flash, f.ignitability_flammable_solid
			 , f.texas_waste_material_type, f.texas_state_waste_code, f.PA_residual_waste_flag, f.react_sulfide_ppm, f.react_cyanide_ppm				--419
			 , f.radioactive, f.reactive_other_description, f.reactive_other, f.contains_pcb, f.dioxins_or_furans, f.metal_fines_powder_paste
			 , f.temp_control, f.thermally_unstable, f.compressed_gas, f.tires, f.organic_peroxide, f.beryllium_present, f.asbestos_flag, f.asbestos_friable_flag
			 , f.hazardous_secondary_material, f.hazardous_secondary_material_cert, f.pharma_waste_subject_to_prescription
			 , f.waste_treated_after_generation, f.waste_treated_after_generation_desc, f.debris_separated, f.debris_not_mixed_or_diluted				--440
			 , f.origin_refinery, f.specific_technology_requested, f.requested_technology, f.other_restrictions_requested, f.thermal_process_flag
			 , f.DOT_sp_permit_flag, f.DOT_sp_permit_text, f.BTU_lt_gt_5000, f.ammonia_flag
			 , f.pcb_concentration_0_9, f.pcb_concentration_10_49, f.pcb_regulated_for_disposal_under_TSCA, f.pcb_article_for_TSCA_landfill
			 , @display_status_uid, f.RCRA_waste_code_flag, f.RQ_threshold											--456
			 , SYSTEM_USER as submitted_by, GETDATE() as date_submitted, f.DOT_waste_flag
			 , f.section_F_none_apply_flag, f.routing_facility, f.waste_meets_ldr_standards
			 , f.signed_on_behalf_of, f.PFAS_Flag, f.approval_code													--465
		  FROM dbo.FormWCR f
		  LEFT JOIN dbo.Generator g ON f.generator_id = g.generator_id
		 WHERE f.Form_id = @form_id
		   AND f.revision_id = @revision_id;

		SET @FormWCR_uid = SCOPE_IDENTITY();
	END TRY  
  
	BEGIN CATCH
		SELECT ERROR_MESSAGE();
	END CATCH
  
	-- Track form history status
	EXEC sp_FormWCRStatusAudit_Insert @new_form_id, @revisonid, @display_status_uid, @web_user_id;
   
	BEGIN TRY
		IF EXISTS (SELECT 1 FROM dbo.FormBenzene WHERE wcr_id = @form_id AND wcr_rev_id = @revision_id)
			BEGIN
				DECLARE @new_Benzene_form_id INTEGER
					  , @new_Benzene_Rev_id INT = 1
  
				EXEC @new_Benzene_form_id = sp_sequence_next 'form.form_id'  
  
				INSERT INTO dbo.FormBenzene (form_id, revision_id, formWCR_uid
					 , wcr_id, wcr_rev_id, locked
					 , type_of_facility, tab_lt_1_megagram, tab_gte_1_and_lt_10_megagram, tab_gte_10_megagram
					 , benzene_onsite_mgmt, flow_weighted_annual_average_benzene, avg_h20_gr_10
					 , is_process_unit_turnaround, benzene_range_from, benzene_range_to
					 , classified_as_process_wastewater_stream, classified_as_landfill_leachate, classified_as_product_tank_drawdown
					 , originating_generator_name, originating_generator_epa_id
					 , created_by, date_created, modified_by, date_modified
					 )
				SELECT @new_Benzene_form_id as form_id, @new_Benzene_Rev_id as revision_id, @FormWCR_uid as formWCR_uid
					 , @new_form_id as wcr_id, @revisonid as wcr_rev_id, locked, type_of_facility
					 , tab_lt_1_megagram, tab_gte_1_and_lt_10_megagram, tab_gte_10_megagram
					 , benzene_onsite_mgmt, flow_weighted_annual_average_benzene, avg_h20_gr_10
					 , is_process_unit_turnaround, benzene_range_from, benzene_range_to
					 , classified_as_process_wastewater_stream, classified_as_landfill_leachate, classified_as_product_tank_drawdown
					 , originating_generator_name, originating_generator_epa_id
					 , @web_user_id as created_by, GETDATE() as date_created, @modified_by_web_user_id as modified_by, GETDATE() as date_modified
				  FROM dbo.FormBenzene
				 WHERE wcr_id = @form_id
				  AND wcr_rev_id = @revision_id;
			END
	END TRY
  
	BEGIN CATCH
		SELECT ERROR_MESSAGE();
	END CATCH
  
	IF EXISTS (SELECT 1 FROM dbo.FormVSQGCESQG WHERE wcr_id = @form_id AND wcr_rev_id = @revision_id)
		BEGIN
			DECLARE @new_VSQGCESQG_form_id INTEGER
				  , @new_VSQGCESQG_Rev_id INTEGER = 1
  
			EXEC @new_VSQGCESQG_form_id = sp_sequence_next 'form.form_id';
  
			INSERT INTO dbo.FormVSQGCESQG (form_id, revision_id, formWCR_uid
				 , wcr_id, wcr_rev_id, locked, vsqg_cesqg_accept_flag
				 , created_by, date_created, modified_by, date_modified
				 , printname, company, title
				 )  
			SELECT @new_VSQGCESQG_form_id as form_id, @new_VSQGCESQG_Rev_id as revision_id, @FormWCR_uid as formWCR_uid
				 , @new_form_id as wcr_id, @revisonid as wcr_rev_id, locked, vsqg_cesqg_accept_flag
				 , @web_user_id as created_by, GETDATE() as date_created, @modified_by_web_user_id as modified_by, GETDATE() as date_modified
				 , NULL as printname, NULL as company, NULL as title
			  FROM dbo.FormVSQGCESQG
			 WHERE wcr_id = @form_id
			   AND wcr_rev_id = @revision_id;
		END  
  
	BEGIN TRY  
		IF EXISTS (SELECT 1 FROM dbo.FormCGC WHERE form_id = @form_id AND revision_id = @revision_id)  
			BEGIN  
				INSERT INTO dbo.FormCGC (form_id, revision_id, cylinder_quantity, CGA_number
					 , original_label_visible_flag, manufacturer, markings_warnings_comments
					 , DOT_shippable_flag, DOT_not_shippable_reason, poisonous_inhalation_flag
					 , hazard_zone, DOT_ICC_number, cylinder_type_id, heaviest_gross_weight, heaviest_gross_weight_unit
					 , external_condition, cylinder_pressure, pressure_relief_device, protective_cover_flag
					 , workable_valve_flag, threads_impaired_flag, valve_condition, corrosion_color
					 , created_by, date_created, modified_by, date_modified)  
				SELECT @new_form_id as form_id, @revisonid as revision_id, cylinder_quantity, CGA_number
					 , original_label_visible_flag, manufacturer, markings_warnings_comments
					 , DOT_shippable_flag, DOT_not_shippable_reason, poisonous_inhalation_flag
					 , hazard_zone, DOT_ICC_number, cylinder_type_id, heaviest_gross_weight, heaviest_gross_weight_unit
					 , external_condition, cylinder_pressure, pressure_relief_device, protective_cover_flag
					 , workable_valve_flag, threads_impaired_flag, valve_condition, corrosion_color
					 , @web_user_id as created_by, GETDATE() as date_created, @modified_by_web_user_id as modified_by, GETDATE() as date_modified
				  FROM dbo.FormCGC  
				 WHERE form_id = @form_id  
				   AND revision_id = @revision_id;
			END  
	END TRY  
  
	BEGIN CATCH
		SELECT ERROR_MESSAGE();
	END CATCH
  
	BEGIN TRY
		IF EXISTS (SELECT 1 FROM dbo.FormDebris WHERE wcr_id = @form_id AND wcr_rev_id = @revision_id)
			BEGIN
				DECLARE @new_Debris_form_id INTEGER
					  , @new_Debris_Rev_id INTEGER = 1
  
				EXEC @new_Debris_form_id = sp_sequence_next 'form.form_id';
  
				INSERT INTO dbo.FormDebris (form_id, revision_id, formWCR_uid
					 , wcr_id, wcr_rev_id, locked, debris_certification_flag
					 , created_by, date_created, modified_by, date_modified)
				SELECT @new_Debris_form_id as form_id, @new_Debris_Rev_id as revision_id, @FormWCR_uid as formWCR_uid
					 , @new_form_id as wcr_id, @revisonid as wcr_rev_id, locked, debris_certification_flag  
					 , @web_user_id as created_by, GETDATE() as date_created, @modified_by_web_user_id as modified_by, GETDATE() as date_modified
				  FROM dbo.FormDebris
				 WHERE wcr_id = @form_id
				   AND wcr_rev_id = @revision_id;
			END
	END TRY
  
	BEGIN CATCH
		SELECT ERROR_MESSAGE();
	END CATCH
  
	-- IllinoisDisposal  
	BEGIN TRY  
		IF EXISTS (SELECT 1 FROM dbo.FormIllinoisDisposal WHERE wcr_id = @form_id AND wcr_rev_id = @revision_id)  
			BEGIN  
				DECLARE @new_ID_form_id INTEGER  
					  , @new_ID_Rev_id INTEGER = 1  
  
				EXEC @new_ID_form_id = sp_sequence_next 'form.form_id';  
  
				INSERT INTO dbo.FormIllinoisDisposal (form_id, revision_id, formWCR_uid
				 , wcr_id, wcr_rev_id, locked
				 , none_apply_flag, incecticides_flag, pesticides_flag, herbicides_flag, household_waste_flag, carcinogen_flag
				 , other_flag, other_specify, sulfide_10_250_flag, universal_waste_flag, characteristic_sludge_flag
				 , virgin_unused_product_flag, spent_material_flag, cyanide_plating_on_site_flag, substitute_commercial_product_flag
				 , by_product_flag, rx_lime_flammable_gas_flag, pollution_control_waste_IL_flag, industrial_process_waste_IL_flag
				 , phenol_gt_1000_flag, generator_state_id
				 , d004_above_PQL, d005_above_PQL, d006_above_PQL, d007_above_PQL, d008_above_PQL, d009_above_PQL
				 , d010_above_PQL, d011_above_PQL, d012_above_PQL, d013_above_PQL, d014_above_PQL
				 , d015_above_PQL, d016_above_PQL, d017_above_PQL, d018_above_PQL, d019_above_PQL
				 , d020_above_PQL, d021_above_PQL, d022_above_PQL, d023_above_PQL, d024_above_PQL
				 , d025_above_PQL, d026_above_PQL, d027_above_PQL, d028_above_PQL, d029_above_PQL
				 , d030_above_PQL, d031_above_PQL, d032_above_PQL, d033_above_PQL, d034_above_PQL
				 , d035_above_PQL, d036_above_PQL, d037_above_PQL, d038_above_PQL, d039_above_PQL
				 , d040_above_PQL, d041_above_PQL, d042_above_PQL, d043_above_PQL
				 , created_by, date_created, date_modified, modified_by
				 , generator_certification_flag, certify_flag
				 )
			SELECT @new_ID_form_id as form_id, @new_ID_Rev_id as revision_id, @FormWCR_uid as formWCR_uid
				 , @new_form_id as wcr_id, @revisonid as wcr_rev_id, locked
				 , none_apply_flag, incecticides_flag, pesticides_flag, herbicides_flag, household_waste_flag, carcinogen_flag
				 , other_flag, other_specify, sulfide_10_250_flag, universal_waste_flag, characteristic_sludge_flag
				 , virgin_unused_product_flag, spent_material_flag, cyanide_plating_on_site_flag, substitute_commercial_product_flag
				 , by_product_flag, rx_lime_flammable_gas_flag, pollution_control_waste_IL_flag, industrial_process_waste_IL_flag
				 , phenol_gt_1000_flag, generator_state_id
				 , d004_above_PQL, d005_above_PQL, d006_above_PQL, d007_above_PQL, d008_above_PQL, d009_above_PQL
				 , d010_above_PQL, d011_above_PQL, d012_above_PQL, d013_above_PQL, d014_above_PQL
				 , d015_above_PQL, d016_above_PQL, d017_above_PQL, d018_above_PQL, d019_above_PQL
				 , d020_above_PQL, d021_above_PQL, d022_above_PQL, d023_above_PQL, d024_above_PQL
				 , d025_above_PQL, d026_above_PQL, d027_above_PQL, d028_above_PQL, d029_above_PQL
				 , d030_above_PQL, d031_above_PQL, d032_above_PQL, d033_above_PQL, d034_above_PQL
				 , d035_above_PQL, d036_above_PQL, d037_above_PQL, d038_above_PQL, d039_above_PQL
				 , d040_above_PQL, d041_above_PQL, d042_above_PQL, d043_above_PQL
				 , @web_user_id as created_by, GETDATE() as date_created, GETDATE() as date_modified, @modified_by_web_user_id as modified_by
				 , generator_certification_flag, certify_flag
			  FROM dbo.FormIllinoisDisposal
			 WHERE wcr_id = @form_id
			   AND wcr_rev_id = @revision_id;
		END
	END TRY
  
	BEGIN CATCH
		SELECT ERROR_MESSAGE();
	END CATCH
  
	BEGIN TRY  
		IF EXISTS (SELECT 1 FROM dbo.FormLDR WHERE wcr_id = @form_id AND wcr_rev_id = @revision_id)  
			BEGIN  
				DECLARE @new_LDR_form_id INTEGER
				      , @new_LDR_Rev_id INTEGER = 1  
  
				EXEC @new_LDR_form_id = sp_sequence_next 'form.form_id';
  
				INSERT INTO dbo.FormLDR (form_id, revision_id
					 --, form_version_id, customer_id_from_form, customer_id, app_id
					 , [status], locked
					 --, [source], company_id, profit_ctr_id, signing_name, signing_company, signing_title, signing_date
					 , date_created, date_modified, created_by, modified_by
					 , generator_name, generator_epa_id
					 --, generator_address1, generator_city, generator_state, generator_zip, state_manifest_no
					 , manifest_doc_no, generator_id
					 --, generator_address2, generator_address3, generator_address4, generator_address5
					 --, profitcenter_epa_id, profitcenter_profit_ctr_name, profitcenter_address_1, profitcenter_address_2
					 --, profitcenter_address_3, profitcenter_phone, profitcenter_fax
					 --, formWCR_uid
					 , wcr_id, wcr_rev_id, ldr_notification_frequency, waste_managed_id)
				SELECT @new_LDR_form_id as form_id, @new_LDR_Rev_id as revision_id
					 , [status], locked
					 , GETDATE() as date_created, GETDATE() as date_modified, @web_user_id as created_by, @modified_by_web_user_id as modified_by
					 , generator_name, generator_epa_id
					 , manifest_doc_no, generator_id
					 , @new_form_id as wcr_id, @revisonid as wcr_rev_id, ldr_notification_frequency, waste_managed_id
				  FROM dbo.FormLDR
				 WHERE wcr_id = @form_id
				   AND wcr_rev_id = @revision_id;
			END
	END TRY

	BEGIN CATCH
		SELECT ERROR_MESSAGE();
	END CATCH

	IF EXISTS (SELECT 1 FROM dbo.FormLDRDetail WHERE form_id = @form_id AND revision_id = @revision_id)
		BEGIN
			INSERT INTO dbo.FormLDRDetail (form_id, revision_id, form_version_id, page_number
				 , manifest_line_item, ww_or_nww, subcategory, manage_id, approval_code, approval_key
				 , company_id, profit_ctr_id, profile_id, constituents_requiring_treatment_flag
				 --, added_by, date_added, modified_by, date_modified
				 )
			SELECT @new_form_id as form_id, @revisonid as revision_id, form_version_id, page_number
				 , manifest_line_item, ww_or_nww, subcategory, manage_id, approval_code, approval_key
				 , company_id, profit_ctr_id, NULL as profile_id, constituents_requiring_treatment_flag
			  FROM dbo.FormLDRDetail
			 WHERE form_id = @form_id
			   AND revision_id = @revision_id;
		END  
  
	IF EXISTS (SELECT 1 FROM dbo.FormXWasteCode WHERE form_id = @form_id AND revision_id = @revision_id)
		BEGIN
			INSERT INTO dbo.FormXWasteCode (form_id, revision_id
				 --, page_number, line_item
				 , waste_code_uid, waste_code, specifier, lock_flag
				 , added_by, date_added, modified_by, date_modified
				 )
			SELECT @new_form_id as form_id, @revisonid as revision_id
				 , waste_code_uid, waste_code, specifier, NULL as lock_flag
				 , @web_user_id as added_by, GETDATE() as date_added, @modified_by_web_user_id as modified_by, GETDATE() as date_modified
			  FROM dbo.FormXWasteCode
			 WHERE form_id = @form_id
			   AND revision_id = @revision_id;
		END  
  
	IF EXISTS (SELECT 1 FROM FormLDRSubcategory WHERE form_id = @form_id AND revision_id = @revision_id)
		BEGIN  
			INSERT INTO FormLDRSubcategory (form_id, revision_id, page_number, manifest_line_item, ldr_subcategory_id
				 --, added_by, date_added, modified_by, date_modified
				 )  
			SELECT @new_form_id as form_id, @revisonid as revision_id, page_number, manifest_line_item, ldr_subcategory_id
			  FROM dbo.FormLDRSubcategory
			 WHERE form_id = @form_id
			   AND revision_id = @revision_id;
		END  
  
	IF EXISTS (SELECT 1 FROM dbo.FormXConstituent WHERE form_id = @form_id AND revision_id = @revision_id)
		BEGIN
			INSERT INTO dbo.FormXConstituent (form_id, revision_id, page_number, line_item, const_id, const_desc
				 , min_concentration, concentration, unit, uhc
				 , specifier, TCLP_or_totals, typical_concentration, max_concentration
				 , exceeds_LDR, requiring_treatment_flag, cor_lock_flag
				 --, added_by, date_added, modified_by, date_modified
				 )
			SELECT @new_form_id as form_id, @revisonid as revision_id, page_number, line_item, const_id, const_desc
				 , min_concentration, concentration, unit, CASE WHEN uhc = 'T' THEN 'T' ELSE 'F' END as uhc
				 , specifier, TCLP_or_totals, typical_concentration, max_concentration
				 , CASE WHEN exceeds_LDR = 'T' THEN 'T' ELSE 'F' END as exceeds_LDR
				 , requiring_treatment_flag, NULL as cor_lock_flag
			  FROM dbo.FormXConstituent
			 WHERE form_id = @form_id
			   AND revision_id = @revision_id;
		END  
  
	IF EXISTS (SELECT 1 FROM dbo.FormPharmaceutical WHERE wcr_id = @form_id AND wcr_rev_id = @revision_id)
		BEGIN
			DECLARE @new_PHARMA_form_id INTEGER
				  , @new_PHARMA_Rev_id INTEGER = 1
  
			EXEC @new_PHARMA_form_id = sp_sequence_next 'form.form_id';
  
			INSERT INTO FormPharmaceutical (form_id, revision_id, formWCR_uid
				 , wcr_id, wcr_rev_id, locked, pharm_certification_flag
				 , created_by, date_created, date_modified, modified_by
				 )
			SELECT @new_PHARMA_form_id as form_id, @new_PHARMA_Rev_id as revision_id, @FormWCR_uid as formWCR_uid
				 , @new_form_id as wcr_id, @revisonid as wcr_rev_id, locked, pharm_certification_flag
				 , @web_user_id as created_by, GETDATE() as date_created, GETDATE() as date_modified, @modified_by_web_user_id as modified_by
			  FROM dbo.FormPharmaceutical
			 WHERE wcr_id = @form_id
			   AND wcr_rev_id = @revision_id;
		END
  
	IF EXISTS (SELECT 1 FROM dbo.FormRadioactive WHERE wcr_id = @form_id AND wcr_rev_id = @revision_id)
		BEGIN  
			DECLARE @new_Radioactive_form_id INTEGER
				  , @new_Radioactive_Rev_id INTEGER = 1
  
			EXEC @new_Radioactive_form_id = sp_sequence_next 'form.form_id';
  
			INSERT INTO dbo.FormRadioactive (form_id, revision_id, wcr_id, wcr_rev_id, locked
			     , uranium_thorium_flag, uranium_source_material, uranium_concentration
				 , radium_226_flag, radium_226_concentration, radium_228_flag, radium_228_concentration
				 , lead_210_flag, lead_210_concentration, potassium_40_flag, potassium_40_concentration
				 , exempt_byproduct_material_flag, special_nuclear_material_flag, accelerator_flag, generated_in_particle_accelerator_flag 
				 
				 , approved_for_disposal_flag, approved_by_nrc_flag, approved_for_alternate_disposal_flag, nrc_exempted_flag  
				 , released_from_radiological_control_flag, DOD_non_licensed_disposal_flag, byproduct_sum_of_all_isotopes  
				 , source_sof_calculations, special_nuclear_sum_of_all_isotopes, additional_inventory_flag
				 , created_by, date_created, modified_by, date_modified
				 , specifically_exempted_flag, USEI_WAC_table_C1_flag, USEI_WAC_table_C2_flag, USEI_WAC_table_C3_flag
				 , USEI_WAC_table_C4a_flag, USEI_WAC_table_C4b_flag, USEI_WAC_table_C4c_flag, waste_type)
			SELECT @new_Radioactive_form_id as form_id, @new_Radioactive_Rev_id as revision_id
				 , @new_form_id as wcr_id, @revisonid as wcr_rev_id, locked
				 , uranium_thorium_flag, uranium_source_material, uranium_concentration
				 , radium_226_flag, radium_226_concentration, radium_228_flag, radium_228_concentration
				 , lead_210_flag, lead_210_concentration, potassium_40_flag, potassium_40_concentration
				 , exempt_byproduct_material_flag, special_nuclear_material_flag, accelerator_flag, generated_in_particle_accelerator_flag
				 , approved_for_disposal_flag, approved_by_nrc_flag, approved_for_alternate_disposal_flag, nrc_exempted_flag
				 , released_from_radiological_control_flag, DOD_non_licensed_disposal_flag, byproduct_sum_of_all_isotopes
				 , source_sof_calculations, special_nuclear_sum_of_all_isotopes, additional_inventory_flag
				 , @web_user_id as created_by, GETDATE() as date_created, @modified_by_web_user_id as modified_by, GETDATE() as date_modified
				 , specifically_exempted_flag, USEI_WAC_table_C1_flag, USEI_WAC_table_C2_flag, USEI_WAC_table_C3_flag
				 , USEI_WAC_table_C4a_flag, USEI_WAC_table_C4b_flag, USEI_WAC_table_C4c_flag, waste_type
			  FROM dbo.FormRadioactive  
			 WHERE wcr_id = @form_id  
			   AND wcr_rev_id = @revision_id;
  
			SELECT TOP 1 @radioactiveUSEI_form_id = form_id  
				 , @radioactiveUSEI_revision_id = revision_id  
			  FROM dbo.FormRadioactive
		     WHERE wcr_id = @form_id  
			   AND wcr_rev_id = @revision_id;

			SELECT @radioactiveUSEI_new_form_id = form_id  
			  FROM dbo.FormRadioactive
			 WHERE wcr_id = @new_form_id  
			   AND wcr_rev_id = @revision_id;
  
			IF (@radioactiveUSEI_form_id IS NOT NULL AND @radioactiveUSEI_form_id <> ''  
				AND @radioactiveUSEI_revision_id IS NOT NULL AND @radioactiveUSEI_revision_id <> ''  
				AND @radioactiveUSEI_new_form_id IS NOT NULL AND @radioactiveUSEI_new_form_id <> ''  
				)
				BEGIN
					IF EXISTS (SELECT 1 FROM dbo.FormRadioactiveExempt
								WHERE form_id = @radioactiveUSEI_form_id AND revision_id = @radioactiveUSEI_revision_id)
						BEGIN
							INSERT INTO dbo.FormRadioactiveExempt (form_id, revision_id, line_id
								 , item_name, total_number_in_shipment, radionuclide_contained, activity
								 , disposal_site_tsdf_code, cited_regulatory_exemption
								 , created_by, date_created
								 , modified_by, date_modified
								 )
							SELECT @radioactiveUSEI_new_form_id as form_id, @revisonid as revision_id, line_id
								 , item_name, total_number_in_shipment, radionuclide_contained, activity
								 , disposal_site_tsdf_code, cited_regulatory_exemption
								 , @web_user_id as created_by, GETDATE() as date_created
								 , @modified_by_web_user_id as modified_by, GETDATE() as date_created
							  FROM dbo.FormRadioactiveExempt
							 WHERE form_id = @radioactiveUSEI_form_id
							   AND revision_id = @radioactiveUSEI_revision_id;
						END
 
					IF EXISTS (SELECT 1 FROM dbo.FormRadioactiveUSEI
								WHERE form_id = @radioactiveUSEI_form_id AND revision_id = @radioactiveUSEI_revision_id)
						BEGIN
							INSERT INTO dbo.FormRadioactiveUSEI (form_id, revision_id, line_id
								 , radionuclide, concentration
								 , created_by, date_created, modified_by, date_modified
								 , const_id, sectionEflag)  
							SELECT @radioactiveUSEI_new_form_id as form_id, @revisonid as revision_id, line_id
								 , radionuclide, concentration
								 , @web_user_id as created_by, GETDATE() as date_created, @web_user_id as modified_by, GETDATE() as date_modified
								 , const_id, sectionEflag
							  FROM dbo.FormRadioactiveUSEI
							 WHERE form_id = @radioactiveUSEI_form_id
							   AND revision_id = @radioactiveUSEI_revision_id;
						END
				END
		END

	-- SECTION C
	IF EXISTS (SELECT 1 FROM dbo.FormXWCRContainerSize WHERE form_id = @form_id AND revision_id = @revision_id)
		BEGIN
			WITH sub as (
				SELECT ROW_NUMBER() OVER (PARTITION BY bill_unit_code ORDER BY bill_unit_code) AS _row  
					 , @new_form_id as form_id, @revisonid as revision_id, bill_unit_code, is_bill_unit_table_lookup
					 , GETDATE() as date_created, created_by, GETDATE() as date_modified, modified_by
				  FROM dbo.FormXWCRContainerSize  
				 WHERE form_id = @form_id  
				   AND revision_id = @revision_id)
			INSERT INTO FormXWCRContainerSize (form_id, revision_id, bill_unit_code, is_bill_unit_table_lookup
				 , date_created, date_modified, created_by, modified_by)
			SELECT form_id, revision_id, bill_unit_code, is_bill_unit_table_lookup
				 , date_created, date_modified, created_by, modified_by  
			  FROM sub
			 WHERE _row = 1;
		END
  
	IF EXISTS (SELECT 1 FROM dbo.FormXUnit WHERE form_id = @form_id AND revision_id = @revision_id)
		BEGIN
			INSERT INTO dbo.FormXUnit (form_type, form_id, revision_id, bill_unit_code, quantity
				 , added_by, date_added, modified_by, date_modified)  
			SELECT form_type, @new_form_id as form_id, @revisonid as revision_id, bill_unit_code, quantity
				 , @web_user_id as added_by, GETDATE() as date_added, @web_user_id as modified_by, GETDATE() as date_modified
			  FROM dbo.FormXUnit
			 WHERE form_id = @form_id
			   AND revision_id = @revision_id;
		END

	-- SECTION D
	IF EXISTS (SELECT form_id FROM dbo.FormXWCRComposition WHERE form_id = @form_id AND revision_id = @revision_id)
		BEGIN  
			INSERT INTO dbo.FormXWCRComposition (form_id, revision_id
				 , comp_description, comp_from_pct, comp_to_pct, unit
				 , sequence_id
				 , comp_typical_pct
				 --, date_added, added_by, date_modified, modified_by
				 )  
			SELECT @new_form_id as form_id, @revisonid as revision_id
				 , comp_description, comp_from_pct, comp_to_pct, unit
				 , ISNULL(sequence_id, ROW_NUMBER() OVER (ORDER BY form_id, revision_id)) as sequence_id
				 , comp_typical_pct
				 --, GETDATE() as date_added, @web_user_id as added_by, GETDATE() as date_modified, @web_user_id as modified_by
			  FROM dbo.FormXWCRComposition
			 WHERE form_id = @form_id
			   AND revision_id = @revision_id;
		END  
  
	-- SECTION H
	IF EXISTS (SELECT form_id FROM dbo.FormXUSEFacility WHERE form_id = @form_id AND revision_id = @revision_id)
		BEGIN
			INSERT INTO dbo.FormXUSEFacility (form_id, revision_id, profit_ctr_id, company_id
				 , date_created, date_modified, created_by, modified_by)
			SELECT @new_form_id as form_id, @revisonid as revision_id, profit_ctr_id, company_id
				 , GETDATE() as date_created, GETDATE() as date_modified, created_by, modified_by
			  FROM dbo.FormXUSEFacility
			 WHERE form_id = @form_id
			   AND revision_id = @revision_id;
		END
  
	-- THERMAL
	IF EXISTS (SELECT 1 FROM dbo.FormThermal WHERE wcr_id = @form_id AND wcr_rev_id = @revision_id)
		BEGIN
			DECLARE @new_THERMAL_form_id INTEGER
				  , @new_THERMAL_Rev_id INTEGER = 1

			EXEC @new_THERMAL_form_id = sp_sequence_next 'form.form_id';
  
			INSERT INTO dbo.FormThermal (form_id, revision_id, formWCR_uid
				 , wcr_id, wcr_rev_id, locked, originating_generator_name, originating_generator_epa_id
				 , oil_bearing_from_refining_flag, rcra_excluded_HSM_flag, oil_constituents_are_fuel_flag
				 , petroleum_refining_F037_flag, petroleum_refining_F038_flag, petroleum_refining_K048_flag, petroleum_refining_K049_flag
				 , petroleum_refining_K050_flag, petroleum_refining_K051_flag, petroleum_refining_K052_flag
				 , petroleum_refining_K169_flag, petroleum_refining_K170_flag, petroleum_refining_K171_flag, petroleum_refining_K172_flag
				 , petroleum_refining_no_waste_code_flag, gen_process
				 , composition_water_percent, composition_solids_percent, composition_organics_oil_TPH_percent
				 , heating_value_btu_lb, percent_of_ASH, specific_halogens_ppm, specific_mercury_ppm
				 , specific_SVM_ppm, specific_LVM_ppm, specific_organic_chlorine_from_VOCs_ppm, specific_sulfides_ppm
				 , non_friable_debris_gt_2_inch_flag, non_friable_debris_gt_2_inch_ppm, self_heating_properties_flag
				 , bitumen_asphalt_tar_flag, bitumen_asphalt_tar_ppm, centrifuge_prior_to_shipment_flag, fuel_oxygenates_flag
				 , oxygenates_MTBE_flag, oxygenates_ethanol_flag, oxygenates_other_flag, oxygenates_ppm, surfactants_flag
				 , created_by, date_created, date_modified, modified_by, same_as_above
				 )  
			SELECT @new_THERMAL_form_id as form_id, @new_THERMAL_Rev_id as revision_id, @FormWCR_uid as formWCR_uid
				 , @new_form_id as wcr_id, @revisonid as wcr_rev_id, locked, originating_generator_name, originating_generator_epa_id
				 , oil_bearing_from_refining_flag, rcra_excluded_HSM_flag, oil_constituents_are_fuel_flag
				 , petroleum_refining_F037_flag, petroleum_refining_F038_flag, petroleum_refining_K048_flag, petroleum_refining_K049_flag
				 , petroleum_refining_K050_flag, petroleum_refining_K051_flag, petroleum_refining_K052_flag
				 , petroleum_refining_K169_flag, petroleum_refining_K170_flag, petroleum_refining_K171_flag, petroleum_refining_K172_flag
				 , petroleum_refining_no_waste_code_flag, gen_process
				 , composition_water_percent, composition_solids_percent, composition_organics_oil_TPH_percent
				 , heating_value_btu_lb, percent_of_ASH, specific_halogens_ppm, specific_mercury_ppm
				 , specific_SVM_ppm, specific_LVM_ppm, specific_organic_chlorine_from_VOCs_ppm, specific_sulfides_ppm
				 , non_friable_debris_gt_2_inch_flag, non_friable_debris_gt_2_inch_ppm, self_heating_properties_flag
				 , bitumen_asphalt_tar_flag, bitumen_asphalt_tar_ppm, centrifuge_prior_to_shipment_flag, fuel_oxygenates_flag
				 , oxygenates_MTBE_flag, oxygenates_ethanol_flag, oxygenates_other_flag, oxygenates_ppm, surfactants_flag
				 , @web_user_id as created_by, GETDATE() as date_created, GETDATE() as date_modified, @modified_by_web_user_id, same_as_above
			  FROM dbo.FormThermal
			 WHERE wcr_id = @form_id
			   AND wcr_rev_id = @revision_id;
		END  
  
	-- WASTE IMPORT  
	BEGIN TRY  
		IF EXISTS (SELECT 1 FROM dbo.FormWasteImport WHERE wcr_id = @form_id AND wcr_rev_id = @revision_id)
			BEGIN  
				DECLARE @new_WI_form_id INTEGER
					  , @new_WI_Rev_id INTEGER = 1
  
				EXEC @new_WI_form_id = sp_sequence_next 'form.form_id';
  
				INSERT INTO dbo.FormWasteImport (form_id, revision_id, formWCR_uid
					 , wcr_id, wcr_rev_id, locked
					 , foreign_exporter_name, foreign_exporter_address, foreign_exporter_contact_name, foreign_exporter_phone
					 , foreign_exporter_fax, foreign_exporter_email, epa_notice_id, epa_consent_number
					 , effective_date, expiration_date, approved_volume, approved_volume_unit
					 , importing_generator_id, importing_generator_name, importing_generator_address, importing_generator_city
					 , importing_generator_province_territory, importing_generator_mail_code, importing_generator_epa_id
					 , tech_contact_id, tech_contact_name, tech_contact_phone, tech_cont_email, tech_contact_fax
					 , created_by, date_created, modified_by, date_modified
					 , foreign_exporter_sameas_generator, foreign_exporter_city, foreign_exporter_province_territory
					 , foreign_exporter_mail_code, foreign_exporter_country
					 )  
				SELECT @new_WI_form_id as form_id, @new_WI_Rev_id as revision_id, @FormWCR_uid as formWCR_uid
					 , @new_form_id as wcr_id, @revisonid as wcr_rev_id, fw.locked
					 , CASE WHEN fw.foreign_exporter_sameas_generator = 'T' THEN wcr.generator_name
						    ELSE fw.foreign_exporter_name
						END as foreign_exporter_name
					 , CASE WHEN fw.foreign_exporter_sameas_generator = 'T' THEN wcr.generator_address1
						    ELSE fw.foreign_exporter_address
					    END as foreign_exporter_address
					 , CASE WHEN fw.foreign_exporter_sameas_generator = 'T' THEN wcr.tech_contact_name
							ELSE fw.foreign_exporter_contact_name
					    END as foreign_exporter_contact_name
					 , CASE WHEN fw.foreign_exporter_sameas_generator = 'T' THEN wcr.tech_contact_phone
							ELSE fw.foreign_exporter_phone
						END as foreign_exporter_phone
					 
					 , CASE WHEN fw.foreign_exporter_sameas_generator = 'T' THEN wcr.tech_contact_fax  
							ELSE fw.foreign_exporter_fax  
						END as foreign_exporter_fax
					 , CASE WHEN fw.foreign_exporter_sameas_generator = 'T' THEN wcr.tech_cont_email  
							ELSE fw.foreign_exporter_email  
					    END as foreign_exporter_email
					 , fw.epa_notice_id, fw.epa_consent_number
					 , NULL as effective_date, NULL as expiration_date, fw.approved_volume, fw.approved_volume_unit
					 , fw.importing_generator_id, fw.importing_generator_name, fw.importing_generator_address, fw.importing_generator_city
					 , fw.importing_generator_province_territory, fw.importing_generator_mail_code, fw.importing_generator_epa_id
					 , fw.tech_contact_id, fw.tech_contact_name, fw.tech_contact_phone, fw.tech_cont_email, fw.tech_contact_fax
					 , @web_user_id as created_by, GETDATE() as date_created, @modified_by_web_user_id as modified_by, GETDATE() as date_modified
					 , fw.foreign_exporter_sameas_generator
					 , CASE WHEN fw.foreign_exporter_sameas_generator = 'T' THEN wcr.generator_city 
						    ELSE fw.foreign_exporter_city
						END as foreign_exporter_city
					 , CASE WHEN fw.foreign_exporter_sameas_generator = 'T' THEN wcr.generator_state  
							ELSE fw.foreign_exporter_province_territory  
						END as foreign_exporter_province_territory
					 , CASE WHEN fw.foreign_exporter_sameas_generator = 'T' THEN wcr.generator_zip
						    ELSE fw.foreign_exporter_mail_code
						END as foreign_exporter_mail_code
					 , CASE WHEN fw.foreign_exporter_sameas_generator = 'T' THEN wcr.gen_mail_country
							ELSE fw.foreign_exporter_country
						END as foreign_exporter_country
				  FROM dbo.FormWasteImport fw  
					   JOIN dbo.FormWCR wcr ON wcr.form_id = wcr_id  
						    AND wcr.revision_id = wcr_rev_id  
				 WHERE wcr_id = @form_id  
				   AND wcr_rev_id = @revision_id;
			END  
	END TRY  
  
	BEGIN CATCH  
		SELECT ERROR_MESSAGE();
	END CATCH  
  
	-- Generator Knowledge supplement form    
	EXEC sp_COR_GeneratorKnowledge_Copy @source_form_id, @source_revision_id, @new_form_id, @revisonid, @web_user_id  
  
	-- Signature   
	IF EXISTS (SELECT form_id FROM dbo.FormSignature WHERE form_id = @form_id AND revision_id = @revision_id)
		BEGIN  
			INSERT INTO dbo.FormSignature (form_id, revision_id, form_signature_type_id, form_version_id
				 , sign_company, sign_name, sign_title, sign_email, sign_phone, sign_fax, sign_address, sign_city, sign_state, sign_zip_code
				 , date_added, sign_comment_internal, logon, contact_id
				 , e_signature_type_id, e_signature_envelope_id, e_signature_url, e_signature_status
				 , web_userid, created_by, date_created
				 , modified_by, date_modified
				 )  
			SELECT @new_form_id as form_id, @revisonid as revision_id, form_signature_type_id, form_version_id
				 , sign_company, sign_name, sign_title, sign_email, sign_phone, sign_fax, sign_address, sign_city, sign_state, sign_zip_code
				 , date_added, sign_comment_internal, logon, contact_id
				 , e_signature_type_id, NULL as e_signature_envelope_id, e_signature_url, NULL as e_signature_status
				 , @web_user_id as web_userid, @web_user_id as created_by, GETDATE() as date_created
				 , @modified_by_web_user_id as modified_by, GETDATE() as date_modified
			  FROM dbo.FormSignature
			 WHERE form_id = @form_id
			   AND revision_id = @revision_id;
		END  
  
	-- FuelBlending  
	IF EXISTS (SELECT form_id FROM dbo.FormEcoflo WHERE wcr_id = @form_id AND wcr_rev_id = @revision_id)
		BEGIN  
			DECLARE @new_FB_form_id INTEGER
				  , @new_FB_Rev_id INTEGER = 1
  
			EXEC @new_FB_form_id = sp_sequence_next 'form.form_id';
  
			INSERT INTO dbo.FormEcoflo (form_id, revision_id, formWCR_uid
				 , wcr_id, wcr_rev_id, viscosity_value
				 , total_solids_low, total_solids_high, total_solids_description
				 , fluorine_low, fluorine_high, chlorine_low, chlorine_high
				 , bromine_low, bromine_high, iodine_low, iodine_high
				 , created_by, modified_by
				 , date_created, date_modified
				 , total_solids_flag, organic_halogens_flag
				 , fluorine_low_flag, fluorine_high_flag, chlorine_low_flag, chlorine_high_flag
				 , bromine_low_flag, bromine_high_flag, iodine_low_flag, iodine_high_flag)  
			SELECT @new_FB_form_id as form_id, @new_FB_Rev_id as revision_id, @FormWCR_uid as formWCR_uid
				 , @new_form_id as wcr_id, @revisonid as wcr_rev_id, viscosity_value
				 , total_solids_low, total_solids_high, total_solids_description
				 , fluorine_low, fluorine_high, chlorine_low, chlorine_high
				 , bromine_low, bromine_high, iodine_low, iodine_high
				 , @web_user_id as created_by, @modified_by_web_user_id as modified_by
				 , GETDATE() as date_created, GETDATE() as date_modified
				 , total_solids_flag, organic_halogens_flag
				 , fluorine_low_flag, fluorine_high_flag, chlorine_low_flag, chlorine_high_flag
				 , bromine_low_flag, bromine_high_flag, iodine_low_flag, iodine_high_flag
			  FROM dbo.FormEcoflo
			 WHERE wcr_id = @form_id
			   AND wcr_rev_id = @revision_id;
		END  
  
	-- VALIDATION  
	EXEC sp_Insert_Section_Status @new_form_id, @revisonid, @web_user_id;
	EXEC sp_COR_Insert_Supplement_Section_Status @new_form_id, @revisonid, @web_user_id;  
  
	DECLARE @Counter INT = 1  
		  , @Data VARCHAR(3)  
  
	--SELECT section
	--  FROM dbo.FormSectionStatus
	-- WHERE form_id = @form_id
	--   AND revision_id = @revision_id;
   
	EXEC sp_Validate_Section_A @new_form_id, @revisonid;
	EXEC sp_Validate_Section_B @new_form_id, @revisonid;
	EXEC sp_Validate_Section_C @new_form_id, @revisonid;
	EXEC sp_Validate_Section_D @new_form_id, @revisonid;
	EXEC sp_Validate_Section_E @new_form_id, @revisonid;
	EXEC sp_Validate_Section_F @new_form_id, @revisonid;
	EXEC sp_Validate_Section_G @new_form_id, @revisonid;
	EXEC sp_Validate_Section_H @new_form_id, @revisonid;
	EXEC sp_Validate_Section_L @new_form_id, @revisonid;
	EXEC sp_Validate_Section_Document @new_form_id, @revisonid;
	EXEC sp_COR_Validate_Supplementary_Form @new_form_id, @revisonid, @web_user_id;
	EXEC sp_Validate_Status_Update @new_form_id, @revisonid;
  
	SET @Message = 'Profile Copied Successfully';  
	SET @formId = @new_form_id;  
	SET @rev_id = @revisonid;  
  
	DECLARE @i_contact_id INTEGER
		  , @i_customer_id INTEGER
		  , @i_generator_id INTEGER
  
	SELECT TOP 1 @i_contact_id = contact_id
      FROM dbo.Contact
     WHERE web_userid = @web_user_id
       AND web_access_flag = 'T'
       AND contact_status = 'A';
  
	SELECT TOP 1 @i_customer_id = customer_id
		 , @i_generator_id = generator_id
	  FROM dbo.FormWCR
     WHERE form_id = @formId
       AND revision_id = @rev_id;
  
	BEGIN TRY
		INSERT INTO dbo.ContactCORFormWCRBucket (contact_id, form_id, revision_id, customer_id, generator_id)
		VALUES (@i_contact_id, @formId, @rev_id, @i_customer_id, @i_generator_id);
	END TRY
  
	BEGIN CATCH  
		IF @@TRANCOUNT > 0  
			BEGIN  
				SET @Message = ERROR_MESSAGE();  
			END  
  
		INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription
			 , [Object_Name], Web_user_id, CreatedDate)
		VALUES (CONCAT (ERROR_MESSAGE(), ': Form Id ', @formId, ' : revision id: ', @Revision_id)
			 , ERROR_PROCEDURE(), LEFT(@web_user_id,50), GETDATE());  
	END CATCH  
END  
GO

GRANT EXECUTE
	ON [dbo].[sp_FormWCR_Copy]
	TO COR_USER;
GO
