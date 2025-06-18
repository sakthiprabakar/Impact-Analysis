Use PLT_AI
GO

CREATE OR ALTER PROCEDURE dbo.sp_Approved_Copy
	  @profile_id INT
	, @copysource VARCHAR(10)
	, @web_userid VARCHAR(100)
	, @modified_by_web_user_id VARCHAR(100) = ''
	, @r_form_id VARCHAR(50) = '' OUTPUT
	, @r_revision_id VARCHAR(50) = '' OUTPUT
AS
	/* ******************************************************************
  Author       : Meenachi Sundaram
  Updated By   : Nallaperumal C		14-october-2023		Ticket: 73641
  Updated By   : Sathiyamoorthi M	03-March-2024		Ticket: 79675
  Updated By   : Sathiyamoorthi M	18-July-2024		Ticket: 93216 
  Update BY    : Ashothaman P							Ticket: 99704
  Updated By   : Karuppiah			10th Dec 2024		Ticket: Titan-US134197,US132686,US134198,US127722
  Updated by Blair Christensen for Titan 05/08/2025

  Decription   : This procedure is used to copy FormWCR table i.e. for the Approved profile
 Copy profile information to FormWCR Table for the given profile id  

inputs:	profile_id, copysource, web_userid 
output: MessageResult, Inserted Successfully

Samples:  exec sp_Approved_Copy '652329','copy','nyswyn100'

-- New Copy soure 
exec sp_Approved_Copy '651907','copy','anand_m123'
exec sp_Approved_Copy '699518','copy','manand84'
****************************************************************** */
BEGIN
	SET NOCOUNT ON;

	DECLARE @new_form_id INT
		  , @revision_id INT = 1
		  , @display_status_uid INT = 1
		  , @source_form_id INT
		  , @source_revision_id INT
		  , @NewFormWCR_uid INTEGER

	SET @source_form_id = @profile_id

	DECLARE @print_name VARCHAR(100)
		  , @contact_company VARCHAR(100)
		  , @title VARCHAR(100)

	IF ISNULL(@modified_by_web_user_id, '') = ''
		BEGIN
			SET @modified_by_web_user_id = @web_userid
		END

	---Check the Copy source, if it is null or empty THEN the default value is copy
	IF NOT EXISTS (SELECT 1 FROM FormCopysource WHERE copy_source = @copysource)
		BEGIN
			SET @copysource = 'copy'
		END

	IF (@copysource <> 'csnew')
		BEGIN
			SELECT TOP 1 @print_name = first_name + ' ' + last_name
				 , @title = title
				 , @contact_company = contact_company
			  FROM dbo.Contact
			 WHERE web_userid = @web_userid
				AND web_access_flag = 'T'
				AND contact_status = 'A';
		END

	BEGIN TRY
		IF (@copysource = 'amendment' OR @copysource = 'renewal')
			BEGIN
				SELECT @new_form_id = form_id_wcr
				  FROM dbo.[Profile]
				 WHERE profile_id = @profile_id
				   AND form_id_wcr > 0;

				IF (@new_form_id IS NULL OR @new_form_id = '')
					BEGIN
						EXEC @new_form_id = sp_sequence_next 'form.form_id'
					END
				ELSE
					BEGIN
						SELECT TOP 1 @revision_id = revision_id
						  FROM dbo.FormWCR
						 WHERE form_id = @new_form_id
						 ORDER BY revision_id DESC;

						SET @revision_id = @revision_id + 1
					END
			END
		ELSE
			BEGIN
				EXEC @new_form_id = sp_sequence_next 'form.form_id'
			END

		DECLARE @IsNoneExist BIT = 0
		DECLARE @ValidStateWasteCodesCount INT = 0
		DECLARE @state_waste_code_flag CHAR(1)
		SELECT @state_waste_code_flag = state_waste_code_flag
			FROM dbo.ProfileLab
			WHERE profile_id = @profile_id
			AND [type] = 'A';

		SELECT @ValidStateWasteCodesCount = COUNT(*)
			FROM dbo.ProfileWasteCode P
			WHERE p.profile_id = @profile_id
			AND waste_code <> 'NONE';

		DECLARE @total_waste_code_Count INT
		SELECT @total_waste_code_Count = COUNT(*)
			FROM dbo.ProfileWasteCode P
			WHERE p.profile_id = @profile_id;

		DECLARE @None_waste_code_Count INT
		SELECT @None_waste_code_Count = COUNT(*)
			FROM dbo.ProfileWasteCode P
			WHERE p.profile_id = @profile_id
			AND waste_code = 'NONE';

		IF @None_waste_code_Count = 1 AND @total_waste_code_Count = @None_waste_code_Count
			BEGIN
				SET @IsNoneExist = 1
			END

		BEGIN TRY
			IF NOT EXISTS (SELECT 1 FROM dbo.FormWCR WHERE form_id = @new_form_id AND revision_id = @revision_id)
				BEGIN
				INSERT INTO dbo.FormWCR (form_id, revision_id
					--, form_version_id, customer_id_from_form
					, customer_id
					--, app_id, tracking_id
					, [status], locked, [source]
					--, signing_name, signing_company, signing_title, signing_date
					, date_created, date_modified, created_by, modified_by				--10
					--, comments, sample_id
					, cust_name, cust_addr1, cust_addr2, cust_addr3, cust_addr4, cust_city, cust_state, cust_zip, cust_country
					, inv_contact_name, inv_contact_phone, inv_contact_fax
					, tech_contact_name, tech_contact_phone, tech_contact_fax, tech_contact_mobile, tech_contact_pager, tech_cont_email
					, generator_id, EPA_ID, generator_name, generator_address1, generator_address2, generator_address3, generator_address4		--35
					, generator_city, generator_state, generator_zip
					--, generator_county_id, generator_county_name
					, gen_mail_address1, gen_mail_address2, gen_mail_address3, gen_mail_city, gen_mail_state, gen_mail_zip
					--, generator_contact, generator_contact_title
					, generator_phone, generator_fax, waste_common_name
					--, volume
					, frequency, dot_shipping_name
					--, surcharge_exempt, pack_bulk_solid_yard, pack_bulk_solid_ton, pack_bulk_liquid, pack_totes, pack_totes_size, pack_cy_box, pack_drum, pack_other, pack_other_desc
					, color, odor						--51
					--, poc
					, consistency_solid, consistency_dust, consistency_debris, consistency_sludge, consistency_liquid, consistency_gas_aerosol, consistency_varies
					--, ph
					, ph_lte_2, ph_gt_2_lt_5, ph_gte_5_lte_10, ph_gt_10_lt_12_5, ph_gte_12_5
					--, ignitability, waste_contains_spec_hand_none, free_liquids, oily_residue
					, metal_fines, biodegradable_sorbents				--65
					--, amines, ammonia, dioxins, furans
					, biohazard, shock_sensitive_waste
					--, reactive_waste
					, radioactive_waste, explosives, pyrophoric_waste
					--, isocyanates, asbestos_friable, asbestos_non_friable
					, gen_process
					--, rcra_listed, rcra_listed_comment, rcra_characteristic, rcra_characteristic_comment
					, state_waste_code_flag
					--, state_waste_code_flag_comment, wastewater_treatment
					, waste_meets_ldr_standards, exceed_ldr_standards, meets_alt_soil_treatment_stds, more_than_50_pct_debris, oxidizer, react_cyanide, react_sulfide	--83
					--, info_basis
					--, D004, D005, D006, D007, D008, D009, D010, D011, D012, D013, D014, D015, D016, D017, D018, D019, D020
					--, D021, D022, D023, D024, D025, D026, D027, D028, D029, D030, D031, D032, D033, D034, D035, D036, D037, D038, D039, D040, D041, D042, D043
					--, D004_concentration, D005_concentration, D006_concentration, D007_concentration, D008_concentration, D009_concentration, D010_concentration
					--, D011_concentration, D012_concentration, D013_concentration, D014_concentration, D015_concentration, D016_concentration, D017_concentration, D018_concentration, D019_concentration, D020_concentration
					--, D021_concentration, D022_concentration, D023_concentration, D024_concentration, D025_concentration, D026_concentration, D027_concentration, D028_concentration, D029_concentration, D030_concentration
					--, D031_concentration, D032_concentration, D033_concentration, D034_concentration, D035_concentration, D036_concentration, D037_concentration, D038_concentration, D039_concentration, D040_concentration, D041_concentration, D042_concentration, D043_concentration
					--, underlying_haz_constituents, michigan_non_haz, michigan_non_haz_comment, universal, recyclable_commodity, recoverable_petroleum_product
					, used_oil
					--, pcb_concentration
					, pcb_source_concentration_gr_50, processed_into_non_liquid, processd_into_nonlqd_prior_pcb
					, pcb_non_lqd_contaminated_media, pcb_manufacturer, pcb_article_decontaminated, ccvocgr500
					--, benzene, neshap_sic, tab_gr_10, avg_h20_gr_10, tab, benzene_gr_1, benzene_concentration, benzene_unit, fuel_blending
					, btu_per_lb
					--, pct_chlorides, pct_moisture, pct_solids, intended_for_reclamation, pack_drum_size, water_reactive, aluminum
					, subject_to_mact_neshap
					--, subject_to_mact_neshap_codes, srec_exempt_id, ldr_ww_or_nww
					, ldr_subcategory				--94
					--, ldr_manage_id, wwa_info_basis, wwa_bis_phthalate_flag, wwa_bis_phthalate_actual, wwa_carbazole_flag, wwa_carbazole_actual
					--, wwa_o_cresol_flag, wwa_o_cresol_actual, wwa_p_cresol_flag, wwa_p_cresol_actual, wwa_n_decane_flag, wwa_n_decane_actual, wwa_fluoranthene_flag, wwa_fluoranthene_actual
						--, wwa_n_octadecane_flag, wwa_n_octadecane_actual, wwa_trichlorophenol_246_flag, wwa_trichlorophenol_246_actual, wwa_phosphorus_flag, wwa_phosphorus_actual
						--, wwa_total_chlor_phen_flag, wwa_total_chlor_phen_actual, wwa_total_organic_actual, wwa_pcb_flag, wwa_pcb_actual
						--, wwa_acidity_flag, wwa_acidity_actual, wwa_fog_flag, wwa_fog_actual, wwa_tss_flag, wwa_tss_actual, wwa_bod_flag, wwa_bod_actual
						--, wwa_antimony_flag, wwa_antimony_actual, wwa_arsenic_flag, wwa_arsenic_actual, wwa_cadmium_flag, wwa_cadmium_actual
						--, wwa_chromium_flag, wwa_chromium_actual, wwa_cobalt_flag, wwa_cobalt_actual, wwa_copper_flag, wwa_copper_actual
						--, wwa_cyanide_flag, wwa_cyanide_actual, wwa_iron_flag, wwa_iron_actual, wwa_lead_flag, wwa_lead_actual, wwa_mercury_flag, wwa_mercury_actual
						--, wwa_nickel_flag, wwa_nickel_actual, wwa_silver_flag, wwa_silver_actual, wwa_tin_flag, wwa_tin_actual, wwa_titanium_flag, wwa_titanium_actual
						--, wwa_vanadium_flag, wwa_vanadium_actual, wwa_zinc_flag, wwa_zinc_actual, wwa_method_8240, wwa_method_8270, wwa_method_8080, wwa_method_8150, wwa_used_oil, wwa_oil_mixed
					, wwa_halogen_gt_1000, wwa_halogen_source, wwa_halogen_source_desc1, wwa_other_desc_1
					--, profile_id
					, facility_instruction, emergency_phone_number			--100
					--, generator_email
					, frequency_other, erg_number, erg_suffix, hazmat_flag, hazmat_class, subsidiary_haz_mat_class
					, package_group, un_na_flag, un_na_number
					--, dot_shipping_desc
					, reportable_quantity_flag, RQ_reason, odor_other_desc
					--, consistency_debris, consistency_gas_aerosol, consistency_varies, pH_NA
					, ignitability_lt_90, ignitability_90_139, ignitability_140_199, ignitability_gte_200
					--, ignitability_NA
					, temp_ctrl_org_peroxide
					--, NORM, TENORM
					, handling_issue, handling_issue_desc, rcra_exempt_flag, RCRA_exempt_reason					--121
					, cyanide_plating, EPA_source_code, EPA_form_code, waste_water_flag, debris_dimension_weight
					, info_basis_knowledge, info_basis_analysis, info_basis_msds, universal_recyclable_commodity
					, pcb_concentration_none, pcb_concentration_0_49, pcb_concentration_50_499, pcb_concentration_500
					, ddvohapgr500, neshap_chem_1, neshap_chem_2, neshap_standards_part, neshap_subpart
					, benzene_onsite_mgmt, benzene_onsite_mgmt_desc, copy_source, source_form_id
					--, source_revision_id, tech_contact_id, generator_contact_id
					, inv_contact_id
					--, template_form_id, date_last_profile_sync
					, manifest_dot_sp_number, generator_country, gen_mail_name									--147
					--, gen_mail_address4
					, gen_mail_country, generator_type_ID, NAICS_code, state_id, po_required, purchase_order, inv_contact_email
					, DOT_shipping_desc_additional, DOT_inhalation_haz_flag
					, container_type_bulk, container_type_totes, container_type_pallet, container_type_boxes, container_type_drums, container_type_cylinder
					, container_type_labpack, container_type_combination, container_type_combination_desc, container_type_other, container_type_other_desc
					, odor_strength, odor_type_ammonia, odor_type_amines, odor_type_mercaptans, odor_type_sulfur, odor_type_organic_acid, odor_type_other		--175
					, liquid_phase, paint_filter_solid_flag, incidental_liquid_flag
					, ignitability_compare_symbol, ignitability_compare_temperature, ignitability_does_not_flash, ignitability_flammable_solid
					, texas_waste_material_type, texas_state_waste_code, PA_residual_waste_flag, react_sulfide_ppm, react_cyanide_ppm
					, radioactive, reactive_other_description, reactive_other, contains_pcb, dioxins_or_furans, metal_fines_powder_paste, temp_control
					, thermally_unstable, compressed_gas, tires, organic_peroxide, beryllium_present, asbestos_flag, asbestos_friable_flag
					, PFAS_Flag, hazardous_secondary_material, hazardous_secondary_material_cert, pharma_waste_subject_to_prescription
					, waste_treated_after_generation, waste_treated_after_generation_desc, debris_separated, debris_not_mixed_or_diluted
					, origin_refinery, specific_technology_requested, requested_technology, other_restrictions_requested, thermal_process_flag					--204
					--, DOT_sp_permit_flag
					, DOT_sp_permit_text, BTU_lt_gt_5000, ammonia_flag
					, pcb_concentration_0_9, pcb_concentration_10_49, pcb_regulated_for_disposal_under_TSCA, pcb_article_for_TSCA_landfill, display_status_uid
					--, RCRA_waste_code_flag
					, RQ_threshold
					--, submitted_by
					, DOT_sp_permit_flag, DOT_waste_flag
					--, section_F_none_apply_flag, routing_facility, waste_meets_ldr_standards, signed_on_behalf_of, PFAS_Flag, approval_code
					, profile_id, RCRA_waste_code_flag, signing_date, signing_name, signing_company, signing_title)										--221
				SELECT TOP 1 @new_form_id, @revision_id
					--
					, cn.customer_id
					--
					, 'A', 'U', 'W'
					, GETDATE(), GETDATE(), @web_userid, @modified_by_web_user_id			--10
					--
					, cn.bill_to_cust_name, cn.bill_to_addr1, cn.bill_to_addr2, cn.bill_to_addr3, cn.bill_to_addr4, cn.bill_to_city, cn.bill_to_state, cn.bill_to_zip_code, cn.bill_to_country
					, CASE WHEN pc.contact_type = 'Invoicing' THEN pc.contact_name ELSE NULL END
					, CASE WHEN pc.contact_type = 'Invoicing' THEN pc.contact_phone ELSE NULL END
					, CASE WHEN pc.contact_type = 'Invoicing' THEN pc.contact_fax ELSE NULL END
					, CASE WHEN pt.contact_type = 'Technical' THEN pt.contact_name ELSE NULL END
					, CASE WHEN pt.contact_type = 'Technical' THEN pt.contact_phone ELSE NULL END
					, CASE WHEN pt.contact_type = 'Technical' THEN pt.contact_fax ELSE NULL END
					, CASE WHEN pt.contact_type = 'Technical' THEN pt.contact_mobile ELSE NULL END
					, CASE WHEN pt.contact_type = 'Technical' THEN pt.contact_pager ELSE NULL END
					, CASE WHEN pt.contact_type = 'Technical' THEN pt.contact_email ELSE NULL END
					, p.generator_id, gn.EPA_ID, gn.generator_name, gn.generator_address_1, gn.generator_address_2, gn.generator_address_3, gn.generator_address_4	--35
					, gn.generator_city, gn.generator_state, gn.generator_zip_code
					--
					, gn.gen_mail_addr1, gn.gen_mail_addr2, gn.gen_mail_addr3, gn.gen_mail_city, gn.gen_mail_state, gn.gen_mail_zip_code
					--
					, gn.generator_phone, gn.generator_fax, p.approval_desc	--???waste common name
					--
					, p.shipping_frequency
					, CASE WHEN p.hazmat = 'F' THEN
								CASE WHEN p.DOT_waste_flag = 'T' AND (p.DOT_shipping_name IS NULL OR p.DOT_shipping_name = '')
										THEN 'Waste Material Not Regulated By D.O.T.'
										WHEN p.DOT_waste_flag = 'T' AND (p.DOT_shipping_name IS NOT NULL AND p.DOT_shipping_name <> '')
										THEN 'Waste ' + p.DOT_shipping_name
										WHEN (p.DOT_waste_flag IS NULL OR p.DOT_waste_flag = 'F') AND (p.DOT_shipping_name IS NOT NULL AND p.DOT_shipping_name <> '')
										THEN dot_shipping_name
										ELSE 'Material Not Regulated By D.O.T.'
									END
						    WHEN p.DOT_waste_flag = 'T' THEN
								CASE WHEN p.DOT_shipping_name LIKE 'waste,%'
										THEN REPLACE(p.DOT_shipping_name, 'waste,', 'Waste')
										WHEN p.DOT_shipping_name LIKE 'waste%'
										THEN REPLACE(REPLACE(REPLACE('Waste' + REPLACE(p.DOT_shipping_name, 'waste', ''), ' ', '<>'), '><', ''), '<>', ' ')
										ELSE p.DOT_shipping_name
									END
							ELSE p.DOT_shipping_name
						END
					--
					, La.[color], La.odor_strength								--51
					--
					, CASE WHEN la.consistency LIKE '%SOLID%' THEN 'T' ELSE 'F' END AS consistency_solid
					, CASE WHEN la.consistency LIKE '%DUST/POWDER%' THEN 'T' ELSE 'F' END AS consistency_dust
					, CASE WHEN la.consistency LIKE '%DEBRIS%' THEN 'T' ELSE 'F' END AS consistency_debris
				    , CASE WHEN la.consistency LIKE '%SLUDGE%' THEN 'T' ELSE 'F' END AS consistency_sludge
					, CASE WHEN la.consistency LIKE '%LIQUID%' THEN 'T' ELSE 'F' END AS consistency_liquid
					, CASE WHEN la.consistency LIKE '%GAS/AEROSOL%' THEN 'T' ELSE 'F' END AS consistency_gas_aerosol
					, CASE WHEN la.consistency LIKE '%VARIES%' THEN 'T' ELSE 'F' END AS consistency_varies
					--
					, La.ph_lte_2, La.ph_gt_2_lt_5, La.ph_gte_5_lte_10, La.ph_gt_10_lt_12_5, La.ph_gte_12_5					--63
					--
					, La.metal_fines, La.biodegradable_sorbents						--65
					--
					, La.biohazard, La.shock_sensitive_waste
					--
					, La.radioactive_waste, La.explosives, La.pyrophoric_waste
					--
					, p.gen_process
					--
					, CASE La.state_waste_code_flag
							WHEN 'F' THEN 'T'
							WHEN 'T' THEN 'F'
							ELSE NULL
						END
					--
					, p.waste_meets_ldr_standards, p.waste_meets_ldr_standards	--exceed_ldr_standards
					, La.meets_alt_soil_treatment_stds, La.more_than_50_pct_debris, La.oxidizer, La.react_cyanide, La.react_sulfide	--79
					--
					, La.used_oil
					--
					, La.pcb_source_concentration_gr_50, La.processed_into_non_liquid, La.processd_into_nonlqd_prior_pcb
					, La.pcb_non_lqd_contaminated_media, La.pcb_manufacturer, La.pcb_article_decontaminated, La.ccvocgr500		--87
					--
					, La.btu_per_lb
					--
					, La.subject_to_mact_neshap
					--
					, ldr_subcategory
					--
					, La.wwa_halogen_gt_1000, La.halogen_source, La.halogen_source_desc, La.halogen_source_other
					--
					, p.facility_instruction, p.emergency_phone_number
					--
					, p.shipping_frequency_other --[frequency_other]
					, p.ERG_number, p.ERG_suffix, p.hazmat, p.hazmat_class, p.subsidiary_haz_mat_class
					, p.package_group, CASE WHEN p.UN_NA_flag = 'X' THEN NULL ELSE p.UN_NA_flag END, p.UN_NA_number
					, p.reportable_quantity_flag, p.RQ_reason, La.odor_other_desc
					--
					, La.ignitability_lt_90, La.ignitability_90_139, La.ignitability_140_199, La.ignitability_gte_200
					--
					, La.temp_ctrl_org_peroxide
					--
					, La.handling_issue, La.handling_issue_desc, p.rcra_exempt_flag, p.rcra_exempt_reason
					, La.cyanide_plating, p.EPA_source_code, p.EPA_form_code, p.waste_water_flag, La.debris_dimension_weight
					, La.info_basis_knowledge, La.info_basis_analysis, La.info_basis_msds, La.universal_recyclable_commodity
					, La.pcb_concentration_none, La.pcb_concentration_0_49, La.pcb_concentration_50_499, La.pcb_concentration_500
					, La.ddvohapgr500, La.neshap_chem_1, La.neshap_chem_2, La.neshap_standards_part, La.neshap_subpart
					, La.benzene_onsite_mgmt, La.benzene_onsite_mgmt_desc, @copysource, @source_form_id
					--
					, p.inv_contact_id
					--
					, p.manifest_dot_sp_number, gn.generator_country, gn.gen_mail_name
					--
					, gn.gen_mail_country, gn.generator_type_ID, gn.NAICS_code, gn.state_id, p.po_required_from_form --,[po_required]
					, p.purchase_order_from_form, CASE WHEN pc.contact_type = 'invoicing' THEN pc.contact_email ELSE NULL END
					, p.DOT_shipping_desc_additional, p.DOT_inhalation_haz_flag
					, p.container_type_bulk, p.container_type_totes, p.container_type_pallet, p.container_type_boxes, p.container_type_drums, p.container_type_cylinder
					, p.container_type_labpack, p.container_type_combination, p.container_type_combination_desc, p.container_type_other, p.container_type_other_desc
					, CASE WHEN (La.odor_strength = 'N'
								AND (La.odor_type_ammonia = 'T'
									OR La.odor_type_amines = 'T'
									OR La.odor_type_mercaptans = 'T'
									OR La.odor_type_sulfur = 'T'
									OR La.odor_type_organic_acid = 'T'
									OR La.odor_type_other = 'T')
								) THEN NULL
							ELSE La.odor_strength
						END
					, La.odor_type_ammonia, La.odor_type_amines, La.odor_type_mercaptans, La.odor_type_sulfur, La.odor_type_organic_acid, La.odor_type_other
					, La.liquid_phase
					, CASE WHEN (La.consistency LIKE '%SOLID%' AND La.consistency LIKE '%LIQUID%')
							OR La.paint_filter_solid_flag NOT IN ('T','F') THEN NULL
							ELSE La.paint_filter_solid_flag
						END
					, La.incidental_liquid_flag
					, La.ignitability_compare_symbol, La.ignitability_compare_temperature, La.ignitability_does_not_flash, La.ignitability_flammable_solid
					, p.texas_waste_material_type, p.texas_state_waste_code, p.PA_residual_waste_flag, La.react_sulfide_ppm, La.react_cyanide_ppm
					, La.radioactive_waste, La.reactive_other_description, La.reactive_other, La.contains_pcb, La.dioxins_or_furans, La.metal_fines, La.temp_ctrl_org_peroxide --[temp_control]
					, La.thermally_unstable, La.compressed_gas, La.tires, La.organic_peroxide, La.beryllium_present, La.asbestos_flag, La.asbestos_friable_flag
					, La.PFAS_Flag, p.hazardous_secondary_material, p.hazardous_secondary_material_cert, p.pharmaceutical_flag
					, p.waste_treated_after_generation, p.waste_treated_after_generation_desc, p.debris_separated, p.debris_not_mixed_or_diluted
					, p.origin_refinery, p.specific_technology_requested, p.requested_technology, p.other_restrictions_requested, p.thermal_process_flag
					--
					, p.manifest_dot_sp_number, La.BTU_lt_gt_5000, La.ammonia_flag
					, La.pcb_concentration_0_9, La.pcb_concentration_10_49, La.pcb_regulated_for_disposal_under_TSCA, La.pcb_article_for_TSCA_landfill, @display_status_uid
					--
					, p.RQ_threshold
					--
					, p.DOT_sp_permit_flag, p.DOT_waste_flag
					, CASE WHEN @copysource = 'copy' THEN NULL ELSE p.profile_id END
					, CASE p.RCRA_Waste_Code_Flag
						    WHEN 'F' THEN 'T'
							WHEN 'T' THEN 'F'
							ELSE NULL
						END
					, NULL, @print_name, @contact_company, @title
				FROM dbo.[Profile] p
						JOIN dbo.ProfileLab La ON La.profile_id = p.profile_id
				LEFT JOIN Customer cn ON p.customer_id = cn.customer_id
				LEFT JOIN Generator gn ON p.generator_id = gn.generator_id
				LEFT JOIN ProfileContact pt ON pt.profile_id = p.profile_id
							AND pt.contact_type IN ('Technical')
				LEFT JOIN ProfileContact pc ON pc.profile_id = p.profile_id
							AND pc.contact_type IN ('Invoicing')
				WHERE p.profile_id = @profile_id
					AND La.[type] = 'A';
				
				SET @NewFormWCR_uid = SCOPE_IDENTITY();
			END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON FORMWCR INSERT :: Copy Source: ' + @copysource + ' :: Error Message --> ' + ERROR_MESSAGE()
						, ERROR_PROCEDURE() ,@web_userid, GETDATE());
		END CATCH

		-- Return New form ID
		EXEC dbo.sp_FormWCRStatusAudit_Insert @new_form_id, @revision_id, @display_status_uid, @web_userid;

		DECLARE @FormWcrContact_id INT

		SELECT TOP 1 @FormWcrContact_id = contact_ID
			FROM dbo.Contact
			WHERE web_userid = COALESCE(@modified_by_web_user_id, @web_userid);

		IF (@FormWcrContact_id > 0)
		BEGIN
			INSERT INTO dbo.ContactCORFormWCRBucket (contact_id, form_id, revision_id)
				VALUES (@FormWcrContact_id, @new_form_id, @revision_id);
		END

		DECLARE @WCR_id INT;
		EXEC @WCR_id = sp_sequence_next 'form.form_id'

		--- Benzene
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileBenzene WHERE profile_id = @profile_id)
				BEGIN
					IF NOT EXISTS (SELECT 1 FROM dbo.FormBenzene WHERE wcr_id = @new_form_id AND wcr_rev_id = @revision_id)
						BEGIN
							DECLARE @bz_form_id INT
							DECLARE @bz_rev_id INT = 1

							EXEC @bz_form_id = sp_sequence_next 'form.form_id'

							INSERT INTO dbo.FormBenzene (form_id, revision_id, formWCR_uid			--< New column
									, wcr_id, wcr_rev_id, locked, type_of_facility
								    , tab_lt_1_megagram, tab_gte_1_and_lt_10_megagram, tab_gte_10_megagram, benzene_onsite_mgmt
									, flow_weighted_annual_average_benzene, avg_h20_gr_10, is_process_unit_turnaround
									, benzene_range_from, benzene_range_to, classified_as_process_wastewater_stream
									, classified_as_landfill_leachate, classified_as_product_tank_drawdown
									, originating_generator_name, originating_generator_epa_id
									, created_by, date_created, modified_by, date_modified)
							SELECT @bz_form_id, @bz_rev_id, @NewFormWCR_uid						--< Identity from FormWCR
									, @new_form_id, @revision_id, 'U', type_of_facility
							        , tab_lt_1_megagram, tab_gte_1_and_lt_10_megagram, tab_gte_10_megagram, pl.benzene_onsite_mgmt
									, flow_weighted_annual_average_benzene, pl.avg_h20_gr_10, is_process_unit_turnaround
									, benzene_range_from, benzene_range_to, classified_as_process_wastewater_stream
									, classified_as_landfill_leachate, classified_as_product_tank_drawdown
									, originating_generator_name, originating_generator_epa_id
									, @web_userid, GETDATE(), @modified_by_web_user_id, GETDATE()
								FROM dbo.ProfileBenzene b
									JOIN dbo.ProfileLab pl ON pl.profile_id = b.profile_id
										AND pl.[type] = 'A'
								WHERE b.profile_id = @profile_id;
						END
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON BENZENE INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		--- Benzene End
		-- CERTIFICATION
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.[Profile] WHERE profile_id = @profile_id)
				BEGIN
					DECLARE @vsqg_form_id INT
							, @vsqg_rev_id INT = 1

					EXEC @vsqg_form_id = sp_sequence_next 'form.form_id'

					INSERT INTO dbo.FormVSQGCESQG (form_id, revision_id, formWCR_uid			--< New column
							, wcr_id, wcr_rev_id, locked
							, vsqg_cesqg_accept_flag, created_by, date_created, date_modified, modified_by)
					SELECT @vsqg_form_id, @vsqg_rev_id, @NewFormWCR_uid						--< Identity from FormWCR
							, @new_form_id, @revision_id, 'U'
							, vsqg_cesqg_accept_flag, @web_userid, GETDATE(), GETDATE(), @modified_by_web_user_id
						FROM dbo.[Profile]
						WHERE profile_id = @profile_id;
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON Certification INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		-- CERTIFICATION End
		-- CYLINDER
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileCGC WHERE profile_id = @profile_id)
				BEGIN
					INSERT INTO dbo.FormCGC (form_id, revision_id, cylinder_quantity, CGA_number, original_label_visible_flag
								, manufacturer, markings_warnings_comments, DOT_shippable_flag, DOT_not_shippable_reason
								, poisonous_inhalation_flag, hazard_zone, DOT_ICC_number
								, cylinder_type_id, heaviest_gross_weight
								, heaviest_gross_weight_unit, external_condition, cylinder_pressure, pressure_relief_device
								, protective_cover_flag, workable_valve_flag, threads_impaired_flag, valve_condition
								, corrosion_color, created_by, date_created, modified_by, date_modified)
					SELECT @new_form_id, @revision_id, cylinder_quantity, CGA_number, original_label_visible_flag
							, manufacturer, markings_warnings_comments, DOT_shippable_flag, DOT_not_shippable_reason
							, poisonous_inhalation_flag, hazard_zone, DOT_ICC_number
							, CASE WHEN (SELECT COUNT(cylinder_type_id)
											FROM CylinderType CL
											WHERE CL.cylinder_type_id = ProfileCGC.cylinder_type_id
										) > 0 THEN cylinder_type_id
								ELSE NULL
							END AS cylinder_type_id
							, heaviest_gross_weight, heaviest_gross_weight_unit, external_condition, cylinder_pressure, pressure_relief_device
							, protective_cover_flag, workable_valve_flag, threads_impaired_flag, valve_condition
							, corrosion_color, @web_userid, GETDATE(), @modified_by_web_user_id, GETDATE()
						FROM dbo.ProfileCGC
						WHERE profile_id = @profile_id;
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON Cylinder INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		-- CYLINDER End
		-- Debris 
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.[Profile] WHERE profile_id = @profile_id)
				BEGIN
					DECLARE @DS_form_id INT
							, @DS_rev_id INT = 1

					EXEC @DS_form_id = sp_sequence_next 'form.form_id'

					INSERT INTO dbo.FormDebris (form_id, revision_id, formWCR_uid			--< New column
							, wcr_id, wcr_rev_id, locked
							, debris_certification_flag, created_by, date_created, modified_by, date_modified)
					SELECT @DS_form_id, @DS_rev_id, @NewFormWCR_uid						--< Identity from FormWCR
							, @new_form_id, @revision_id, 'U'
							, debris_certification_flag, @web_userid, GETDATE(), @modified_by_web_user_id, GETDATE()
						FROM [Profile]
						WHERE profile_id = @profile_id;
			END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON Debris INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		-- Debris End
		-- IllinoisDisposal
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileIllinoisDisposal WHERE profile_id = @profile_id)
				BEGIN
					DECLARE @ID_form_id INT
							, @ID_rev_id INT = 1

					EXEC @ID_form_id = sp_sequence_next 'form.form_id'

					INSERT INTO dbo.FormIllinoisDisposal (form_id, revision_id, formWCR_uid		--< New column
								, wcr_id, wcr_rev_id, locked
								, none_apply_flag, incecticides_flag, pesticides_flag, herbicides_flag, household_waste_flag
								, carcinogen_flag, other_flag, other_specify, sulfide_10_250_flag, universal_waste_flag
								, characteristic_sludge_flag, virgin_unused_product_flag, spent_material_flag, cyanide_plating_on_site_flag
								, substitute_commercial_product_flag, by_product_flag, rx_lime_flammable_gas_flag, pollution_control_waste_IL_flag
								, industrial_process_waste_IL_flag, phenol_gt_1000_flag, generator_state_id
								, d004_above_PQL, d005_above_PQL, d006_above_PQL, d007_above_PQL, d008_above_PQL, d009_above_PQL, d010_above_PQL
								, d011_above_PQL, d012_above_PQL, d013_above_PQL, d014_above_PQL, d015_above_PQL, d016_above_PQL, d017_above_PQL, d018_above_PQL, d019_above_PQL, d020_above_PQL
								, d021_above_PQL, d022_above_PQL, d023_above_PQL, d024_above_PQL, d025_above_PQL, d026_above_PQL, d027_above_PQL, d028_above_PQL, d029_above_PQL, d030_above_PQL
								, d031_above_PQL, d032_above_PQL, d033_above_PQL, d034_above_PQL, d035_above_PQL, d036_above_PQL, d037_above_PQL, d038_above_PQL, d039_above_PQL, d040_above_PQL
								, d041_above_PQL, d042_above_PQL, d043_above_PQL
								, created_by, date_created, date_modified, modified_by, generator_certification_flag, certify_flag)
					SELECT @ID_form_id, @ID_rev_id, @NewFormWCR_uid							--< Identity from FormWCR
							, @new_form_id, @revision_id, 'U'
							, none_apply_flag, incecticides_flag, pesticides_flag, herbicides_flag, household_waste_flag
							, carcinogen_flag, other_flag, other_specify, sulfide_10_250_flag, universal_waste_flag
							, characteristic_sludge_flag, virgin_unused_product_flag, spent_material_flag, cyanide_plating_on_site_flag
							, substitute_commercial_product_flag, by_product_flag, rx_lime_flammable_gas_flag, pollution_control_waste_IL_flag
							, industrial_process_waste_IL_flag, phenol_gt_1000_flag, generator_state_id
							, d004_above_PQL, d005_above_PQL, d006_above_PQL, d007_above_PQL, d008_above_PQL, d009_above_PQL, d010_above_PQL
							, d011_above_PQL, d012_above_PQL, d013_above_PQL, d014_above_PQL, d015_above_PQL, d016_above_PQL, d017_above_PQL, d018_above_PQL, d019_above_PQL, d020_above_PQL
							, d021_above_PQL, d022_above_PQL, d023_above_PQL, d024_above_PQL, d025_above_PQL, d026_above_PQL, d027_above_PQL, d028_above_PQL, d029_above_PQL, d030_above_PQL
							, d031_above_PQL, d032_above_PQL, d033_above_PQL, d034_above_PQL, d035_above_PQL, d036_above_PQL, d037_above_PQL, d038_above_PQL, d039_above_PQL, d040_above_PQL
							, d041_above_PQL, d042_above_PQL, d043_above_PQL
							, @web_userid, GETDATE(), GETDATE(), @modified_by_web_user_id, generator_certification_flag, certify_flag
						FROM dbo.ProfileIllinoisDisposal
						WHERE profile_id = @profile_id;
				END
					-- IllinoisDisposal END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON IllinoisDisposal INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		-- IllinoisDisposal End
		-- LDR
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileLab WHERE profile_id = @profile_id)
				BEGIN
					DECLARE @ldr_form_id INT
							, @ldr_rev_id INT = 1

					EXEC @ldr_form_id = sp_sequence_next 'form.form_id'

					INSERT INTO dbo.FormLDR (form_id, revision_id, generator_id, generator_name, generator_epa_id
							, ldr_notification_frequency, waste_managed_id, [status], locked
							, date_created, date_modified, created_by, modified_by, wcr_id, wcr_rev_id)
					SELECT TOP 1 @ldr_form_id, @ldr_rev_id, p.generator_id, gn.generator_name, gn.EPA_ID
							, la.ldr_notification_frequency, waste_managed_id,'A','U'
							, GETDATE(), GETDATE(), @web_userid, @modified_by_web_user_id, @new_form_id, @revision_id
						FROM dbo.[Profile] p
						    JOIN dbo.ProfileLab la ON la.profile_id = p.profile_id
								AND la.[type] = 'A'
						LEFT JOIN dbo.Generator gn ON p.generator_id = gn.generator_id
						WHERE p.profile_id = @profile_id;
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON LDR INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.[Profile] WHERE profile_id = @profile_id)
				BEGIN
					INSERT INTO dbo.FormLDRDetail (form_id, revision_id, p.constituents_requiring_treatment_flag)
					SELECT @new_form_id, @revision_id, p.constituents_requiring_treatment_flag
						FROM dbo.[Profile] p
						WHERE p.profile_id = @profile_id;
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON FormLDRDetail INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		BEGIN TRY
			IF (SELECT COUNT(profile_id) FROM dbo.ProfileWasteCode WHERE profile_id = @profile_id) > 0
				BEGIN
				-- state waste code insert
					INSERT INTO dbo.FormXWasteCode (form_id, revision_id
						    --, page_number, line_item
						    , waste_code_uid, waste_code, specifier
							--, lock_flag, added_by, date_added, modified_by, date_modified
							)
					SELECT @new_form_id, @revision_id, W.waste_code_uid
						    , W.waste_code, 'state'
						FROM dbo.WasteCode W
						WHERE [status] = 'A'
						  AND waste_code_origin = 'S'
						  AND [state] <> 'TX'
						  AND [state] <> 'PA'
						  AND W.waste_code_uid IN (
							SELECT P.waste_code_uid FROM dbo.ProfileWasteCode P WHERE p.profile_id = @profile_id AND P.waste_code <> 'NONE')

					-- and @state_waste_code_flag<> 'F'
					-- Texas waste code insert
					IF (@copysource = 'amendment' OR @copysource = 'renewal')
						BEGIN
							INSERT INTO dbo.FormXWasteCode (form_id, revision_id
								    --, page_number, line_item
									, waste_code_uid, waste_code, specifier, lock_flag
									--, added_by, date_added, modified_by, date_modified
									)
								SELECT @new_form_id, @revision_id
									 , W.waste_code_uid, W.waste_code, 'TX', NULL
								  FROM dbo.WasteCode W
								 WHERE [status] = 'A'
								   AND [state] = 'TX'
								   AND W.waste_code_uid IN (
									SELECT P.waste_code_uid
									  FROM dbo.ProfileWasteCode P
									 WHERE p.profile_id = @profile_id AND P.waste_code <> 'NONE');
						END
					ELSE
						BEGIN
							INSERT INTO dbo.FormXWasteCode (form_id, revision_id
								    --, page_number, line_item
									, waste_code_uid, waste_code, specifier, lock_flag
									--, added_by, date_added, modified_by, date_modified
									)
							SELECT @new_form_id, @revision_id
									, W.waste_code_uid, W.waste_code, 'TX', NULL
								FROM dbo.WasteCode W
								WHERE [status] = 'A'
								AND [state] = 'TX'
								AND W.waste_code_uid IN (
									SELECT P.waste_code_uid FROM dbo.ProfileWasteCode P
										WHERE p.profile_id = @profile_id AND P.waste_code <> 'NONE' AND p.Texas_primary_flag = 'T');
						END
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON TX waste code INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		BEGIN TRY
			IF (SELECT COUNT(profile_id) FROM dbo.ProfileWasteCode WHERE profile_id = @profile_id) > 0
				BEGIN
					INSERT INTO dbo.FormXWasteCode (form_id, revision_id
							--, page_number, line_item
							, waste_code_uid, waste_code, specifier, lock_flag
							--, added_by, date_added, modified_by, date_modified
							)
					SELECT @new_form_id, @revision_id
							, W.waste_code_uid, W.waste_code,'rcra_characteristic'
							, CASE WHEN @copysource = 'amendment' OR @copysource = 'renewal' THEN 'T' ELSE 'F' END
						FROM dbo.WasteCode W
						WHERE [status] = 'A'
						AND waste_code_origin = 'F'
						AND haz_flag = 'T'
						AND waste_type_code IN ('L','C')
						AND W.waste_code_uid IN (
							SELECT P.waste_code_uid FROM dbo.ProfileWasteCode P
								WHERE p.profile_id = @profile_id AND P.waste_code <> 'NONE'
							);
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON rcra INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		BEGIN TRY
			IF (SELECT COUNT(profile_id) FROM dbo.ProfileWasteCode WHERE profile_id = @profile_id) > 0
				BEGIN
					INSERT INTO FormXWasteCode (form_id, revision_id
							--, page_number, line_item
							, waste_code_uid, waste_code, specifier
							--, lock_flag, added_by, date_added, modified_by, date_modified
							)
					SELECT @new_form_id, @revision_id
							, W.waste_code_uid, W.waste_code, 'PA'
						FROM dbo.WasteCode W
						WHERE W.waste_code_uid IN (SELECT P.waste_code_uid FROM dbo.ProfileWasteCode P WHERE p.profile_id = @profile_id)
						AND [status] = 'A'
						AND waste_code_origin = 'S'
						AND [state] = 'PA'
						ORDER BY [state]
						    , display_name;
			END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON PA waste code INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileLDRSubcategory WHERE profile_id = @profile_id)
				BEGIN
					INSERT INTO dbo.FormLDRSubcategory (form_id, revision_id, ldr_subcategory_id)
					SELECT @new_form_id, @revision_id, ldr_subcategory_id
						FROM dbo.ProfileLDRSubcategory
						WHERE profile_id = @profile_id;
			END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON FormLDRSubcategory INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileConstituent WHERE profile_id = @profile_id)
				BEGIN
					INSERT INTO dbo.FormXConstituent (form_id, revision_id
							--, page_number, line_item
							, const_id
							, const_desc
							, max_concentration, min_concentration, concentration, unit
							, uhc
							, specifier
							, TCLP_or_totals
							, typical_concentration
							, exceeds_LDR
							, requiring_treatment_flag
							, cor_lock_flag
							--, added_by, date_added, modified_by, date_modified
							)
					SELECT @new_form_id, @revision_id, P.const_id
						    , (SELECT const_desc FROM dbo.Constituents WHERE const_id = P.const_id) as const_desc
							, P.concentration, P.min_concentration, P.concentration, P.unit
						    , CASE WHEN P.UHC <> 'T' AND P.UHC <> 'F' THEN NULL ELSE P.UHC END as uhc
							, CASE WHEN P.requiring_treatment_flag = 'T' THEN 'LDR-WO' ELSE 'WCR' END as specifier
							, CASE WHEN P.TCLP_flag = 'T' OR LOWER(P.TCLP_flag) = 'tclp' THEN 'TCLP'
								WHEN P.TCLP_flag = 'F' OR LOWER(P.TCLP_flag) = 'totals' THEN 'Totals'
								ELSE NULL
							END as TCLP_or_totals
						    , P.typical_concentration
							, CASE WHEN P.exceeds_LDR <> 'T' AND P.exceeds_LDR <> 'F' THEN NULL ELSE P.exceeds_LDR END as exceeds_LDR
							, P.requiring_treatment_flag
							, CASE WHEN @copysource IN ('amendment','renewal') THEN P.cor_lock_flag ELSE NULL END as cor_lock_flag
						FROM ProfileConstituent P
						WHERE P.profile_id = @profile_id;
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON FormXConstituent INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		-- LDR END
		-- PHARMA
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.[Profile] WHERE profile_id = @profile_id)
				BEGIN
					DECLARE @pharma_form_id INT
							, @pharma_rev_id INT = 1

					EXEC @pharma_form_id = sp_sequence_next 'form.form_id'

					INSERT INTO dbo.FormPharmaceutical (form_id, revision_id, formWCR_uid			--< New Field
							, wcr_id, wcr_rev_id, locked, pharm_certification_flag
						    , created_by, date_created, date_modified, modified_by)
					SELECT @pharma_form_id, @pharma_rev_id, @NewFormWCR_uid						--< Identity from FormWCR
							, @new_form_id, @revision_id, 'U', pharmaceutical_flag
							, @web_userid, GETDATE(), GETDATE(), @modified_by_web_user_id
						FROM dbo.[Profile]
						WHERE profile_id = @profile_id;
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON Pharmaceutical INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		-- PHARMA END
		-- Radioactive Start
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileRadioactive WHERE profile_id = @profile_id)
				BEGIN
					DECLARE @rad_form_id INT
							, @rad_rev_id INT = 1

					EXEC @rad_form_id = sp_sequence_next 'form.form_id'

					INSERT INTO dbo.FormRadioactive (form_id, revision_id, wcr_id, wcr_rev_id, locked
						    , uranium_thorium_flag, uranium_source_material, radium_226_flag, radium_228_flag, lead_210_flag, potassium_40_flag
							, exempt_byproduct_material_flag, special_nuclear_material_flag, accelerator_flag, generated_in_particle_accelerator_flag
							, approved_for_disposal_flag, approved_by_nrc_flag, approved_for_alternate_disposal_flag, nrc_exempted_flag
							, released_from_radiological_control_flag, DOD_non_licensed_disposal_flag, date_created, date_modified, created_by, modified_by
							, uranium_concentration, radium_226_concentration, radium_228_concentration, lead_210_concentration, potassium_40_concentration
							, specifically_exempted_flag, USEI_WAC_table_C1_flag, USEI_WAC_table_C2_flag, USEI_WAC_table_C3_flag, USEI_WAC_table_C4a_flag
							, USEI_WAC_table_C4b_flag, USEI_WAC_table_C4c_flag, waste_type)
					SELECT @rad_form_id, @rad_rev_id, @new_form_id, @revision_id, 'U'
							, uranium_thorium_flag, uranium_source_material, radium_226_flag, radium_228_flag, lead_210_flag, potassium_40_flag
							, exempt_byproduct_material_flag, special_nuclear_material_flag, accelerator_flag, generated_in_particle_accelerator_flag
							, approved_for_disposal_flag, approved_by_nrc_flag, approved_for_alternate_disposal_flag, nrc_exempted_flag
							, released_from_radiological_control_flag, DOD_non_licensed_disposal_flag, GETDATE(), GETDATE(), @web_userid, @modified_by_web_user_id
							, uranium_concentration, radium_226_concentration, radium_228_concentration, lead_210_concentration, potassium_40_concentration
							, specifically_exempted_flag, USEI_WAC_table_C1_flag, USEI_WAC_table_C2_flag, USEI_WAC_table_C3_flag
							, USEI_WAC_table_C4a_flag, USEI_WAC_table_C4b_flag, USEI_WAC_table_C4c_flag, waste_type
						FROM ProfileRadioactive
						WHERE profile_id = @profile_id;

					IF EXISTS (SELECT 1 FROM dbo.ProfileRadioactiveExempt WHERE profile_id = @profile_id)
						BEGIN
							INSERT INTO dbo.FormRadioactiveExempt (form_id, revision_id, line_id, item_name, total_number_in_shipment, radionuclide_contained
									, activity, disposal_site_tsdf_code, cited_regulatory_exemption, created_by, date_created, modified_by, date_modified)
							SELECT @rad_form_id, @rad_rev_id, line_id, item_name, total_number_in_shipment, radionuclide_contained
									, activity, disposal_site_tsdf_code, cited_regulatory_exemption, @web_userid, GETDATE(), @modified_by_web_user_id, GETDATE()
								FROM ProfileRadioactiveExempt
								WHERE profile_id = @profile_id;
						END

					IF EXISTS (SELECT 1 FROM dbo.ProfileRadioactiveUSEI WHERE profile_id = @profile_id)
						BEGIN
							INSERT INTO dbo.FormRadioactiveUSEI (form_id, revision_id, line_id, radionuclide, concentration 
									, date_created, date_modified, created_by, modified_by, const_id
									--, sectionEflag
									)
							SELECT @rad_form_id, @rad_rev_id, line_id, radionuclide, concentration 
									, GETDATE(), GETDATE(), @web_userid, @modified_by_web_user_id, const_id
								FROM dbo.ProfileRadioactiveUSEI
								WHERE profile_id = @profile_id;
						END
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON Radioactive INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		-- Radioactive End
		-- SECTION C
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileContainerSize WHERE profile_id = @profile_id)
				BEGIN
					WITH tmpprofilecontainersize as (
						    SELECT ROW_NUMBER() OVER (PARTITION BY bill_unit_code ORDER BY bill_unit_code) AS _row
							  	, form_id = @new_form_id
							  	, revision_id = @revision_id
							  	, bill_unit_code = bill_unit_code
							  	, is_bill_unit_table_lookup = is_bill_unit_table_lookup
							  	, date_created = GETDATE()
							  	, date_modified = GETDATE()
							  	, created_by = @web_userid
							  	, modified_by = @modified_by_web_user_id
							FROM dbo.ProfileContainerSize
							WHERE profile_id = @profile_id
							)
					INSERT INTO dbo.FormXWCRContainerSize (form_id, revision_id, bill_unit_code, is_bill_unit_table_lookup
						    , date_created, date_modified, created_by, modified_by)
					SELECT form_id, revision_id, bill_unit_code, is_bill_unit_table_lookup
							, date_created, date_modified, created_by, modified_by
						FROM tmpprofilecontainersize
						WHERE _row = 1
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON FormXWCRContainerSize INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileShippingUnit WHERE profile_id = @profile_id)
				BEGIN
					INSERT INTO dbo.FormXUnit (form_type, form_id, revision_id, bill_unit_code, quantity
					--, added_by, date_added, modified_by, date_modified
					)
					SELECT 'WCR', @new_form_id, @revision_id, bill_unit_code, quantity
						FROM dbo.ProfileShippingUnit
						WHERE profile_id = @profile_id;
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON FormXUnit INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		---- SECTION C END
		-- SECTION D
		--- Physical_Description
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileComposition WHERE profile_id = @profile_id)
				BEGIN
					INSERT INTO dbo.FormXWCRComposition (form_id, revision_id, comp_description, comp_from_pct, comp_to_pct, unit, sequence_id, comp_typical_pct)
					SELECT @new_form_id, @revision_id, comp_description, comp_from_pct, comp_to_pct, unit, sequence_id, comp_typical_pct
						FROM dbo.ProfileComposition
						WHERE profile_id = @profile_id;
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
			VALUES ('Exception ON Physical composition INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		-- SECTION D END
		-- SECTION H Start
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileUSEFacility WHERE profile_id = @profile_id)
				BEGIN
					INSERT INTO dbo.FormXUSEFacility (form_id, revision_id, profit_ctr_id, company_id, date_created, date_modified, created_by, modified_by)
					SELECT @new_form_id, @revision_id, profit_ctr_id, company_id, GETDATE(), GETDATE(), @web_userid, @modified_by_web_user_id
						FROM dbo.ProfileUSEFacility
						WHERE profile_id = @profile_id;
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON USE Facility composition INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		-- SECTION H END
		-- SECTION L Start
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileQuoteApproval WHERE primary_facility_flag = 'T' AND [status] = 'A' AND profile_id = @profile_id)
				BEGIN
					DECLARE @routing_facility VARCHAR(10)
					SELECT @routing_facility = CONVERT(VARCHAR(4), company_id) + '|' + CONVERT(VARCHAR(4), profit_ctr_id)
								FROM dbo.ProfileQuoteApproval
								WHERE primary_facility_flag = 'T'
								AND [status] = 'A'
								AND profile_id = @profile_id;

					UPDATE dbo.FormWCR
						SET routing_facility = @routing_facility
						WHERE form_id = @new_form_id
						AND revision_id = @revision_id;
					-- SECTION L END
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON routing_facility update ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		-- SECTION L End
		-- THERMAL SUPPLEMENT Start
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileThermal WHERE profile_id = @profile_id)
				BEGIN
					DECLARE @TL_form_id INT
							, @TL_rev_id INT = 1

					EXEC @TL_form_id = sp_sequence_next 'form.form_id'

					INSERT INTO dbo.FormThermal (form_id, revision_id, formWCR_uid							--<  New Column
							, wcr_id, wcr_rev_id, locked, originating_generator_name, originating_generator_epa_id
						    , same_as_above, oil_bearing_from_refining_flag, rcra_excluded_HSM_flag, oil_constituents_are_fuel_flag
							, petroleum_refining_F037_flag, petroleum_refining_F038_flag
							, petroleum_refining_K048_flag, petroleum_refining_K049_flag
							, petroleum_refining_K050_flag, petroleum_refining_K051_flag, petroleum_refining_K052_flag
							, petroleum_refining_K169_flag
							, petroleum_refining_K170_flag, petroleum_refining_K171_flag, petroleum_refining_K172_flag
							, petroleum_refining_no_waste_code_flag, gen_process, composition_water_percent, composition_solids_percent, composition_organics_oil_TPH_percent
							, heating_value_btu_lb, percent_of_ASH, specific_halogens_ppm, specific_mercury_ppm, specific_SVM_ppm, specific_LVM_ppm
							, specific_organic_chlorine_from_VOCs_ppm, specific_sulfides_ppm, non_friable_debris_gt_2_inch_flag, non_friable_debris_gt_2_inch_ppm
							, self_heating_properties_flag, bitumen_asphalt_tar_flag, bitumen_asphalt_tar_ppm, centrifuge_prior_to_shipment_flag
							, fuel_oxygenates_flag, oxygenates_MTBE_flag, oxygenates_ethanol_flag, oxygenates_other_flag, oxygenates_ppm, surfactants_flag
							, created_by, date_created, date_modified, modified_by)
					SELECT @TL_form_id, @TL_rev_id, @NewFormWCR_uid										--< Identity from FormWCR
							, @new_form_id, @revision_id, 'U', originating_generator_name, originating_generator_epa_id
							, same_as_above, oil_bearing_from_refining_flag, rcra_excluded_HSM_flag, oil_constituents_are_fuel_flag
							, petroleum_refining_F037_flag, petroleum_refining_F038_flag
							, petroleum_refining_K048_flag, petroleum_refining_K049_flag
							, petroleum_refining_K050_flag, petroleum_refining_K051_flag, petroleum_refining_K052_flag
							, petroleum_refining_K169_flag
							, petroleum_refining_K170_flag, petroleum_refining_K171_flag, petroleum_refining_K172_flag
							, petroleum_refining_no_waste_code_flag, gen_process, composition_water_percent, composition_solids_percent, composition_organics_oil_TPH_percent
							, heating_value_btu_lb, percent_of_ASH, specific_halogens_ppm, specific_mercury_ppm, specific_SVM_ppm, specific_LVM_ppm
							, specific_organic_chlorine_from_VOCs_ppm, specific_sulfides_ppm, non_friable_debris_gt_2_inch_flag, non_friable_debris_gt_2_inch_ppm
							, self_heating_properties_flag, bitumen_asphalt_tar_flag, bitumen_asphalt_tar_ppm, centrifuge_prior_to_shipment_flag
							, fuel_oxygenates_flag, oxygenates_MTBE_flag, oxygenates_ethanol_flag, oxygenates_other_flag, oxygenates_ppm, surfactants_flag
							, @web_userid, GETDATE(), GETDATE(), @modified_by_web_user_id
						FROM dbo.ProfileThermal
						WHERE profile_id = @profile_id;
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON Thermal INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		-- THERMAL SUPPLEMENT End
		-- WASTE IMPORT SUPPLEMENT Start
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileWasteImport WHERE profile_id = @profile_id)
				BEGIN
					DECLARE @WI_form_id INT
							, @WI_rev_id INT = 1
							, @profile_generator_id INT

					SELECT TOP 1 @profile_generator_id = generator_id
						FROM dbo.[Profile]
						WHERE profile_id = @profile_id;

					EXEC @WI_form_id = sp_sequence_next 'form.form_id'

					INSERT INTO dbo.FormWasteImport (form_id, revision_id, formWCR_uid						--< New Column
							, wcr_id, wcr_rev_id, locked
						    , foreign_exporter_name
							, foreign_exporter_address
							, foreign_exporter_city					--
							, foreign_exporter_province_territory		--
							, foreign_exporter_mail_code				--
							, foreign_exporter_country					--
							, foreign_exporter_contact_name
							, foreign_exporter_phone
							, foreign_exporter_fax
							, foreign_exporter_email
							, epa_notice_id, epa_consent_number, effective_date, expiration_date, approved_volume, approved_volume_unit
							, importing_generator_id, importing_generator_name, importing_generator_address, importing_generator_city
							, importing_generator_province_territory, importing_generator_mail_code, importing_generator_epa_id
							, tech_contact_id, tech_contact_name, tech_contact_phone, tech_cont_email, tech_contact_fax
							, created_by, date_created, date_modified, modified_by, foreign_exporter_sameas_generator)
					SELECT @WI_form_id, @WI_rev_id, @NewFormWCR_uid										--< Identity from FormWCR
							, @new_form_id, @revision_id, 'U'
							, CASE WHEN foreign_exporter_sameas_generator = 'T' THEN importing_generator_name 
								   ELSE foreign_exporter_name
							   END as foreign_exporter_name
							, CASE WHEN foreign_exporter_sameas_generator = 'T' THEN g.generator_address_1
								   ELSE foreign_exporter_address
							   END as foreign_exporter_address
							, CASE WHEN foreign_exporter_sameas_generator = 'T' THEN g.generator_city
								   ELSE foreign_exporter_city
							   END as foreign_exporter_city
							, CASE WHEN foreign_exporter_sameas_generator = 'T' THEN g.generator_state
								   ELSE foreign_exporter_province_territory
							   END as foreign_exporter_province_territory
							, CASE WHEN foreign_exporter_sameas_generator = 'T' THEN g.generator_zip_code
								   ELSE foreign_exporter_mail_code
							   END as foreign_exporter_mail_code
							, CASE WHEN foreign_exporter_sameas_generator = 'T' THEN g.gen_mail_country
								   ELSE foreign_exporter_country
							   END as foreign_exporter_country
							, CASE WHEN foreign_exporter_sameas_generator = 'T' THEN tech_contact_name
								   ELSE foreign_exporter_contact_name
							   END as foreign_exporter_contact_name
							, CASE WHEN foreign_exporter_sameas_generator = 'T' THEN tech_contact_phone
								   ELSE foreign_exporter_phone
							   END as foreign_exporter_phone
							, CASE WHEN foreign_exporter_sameas_generator = 'T' THEN tech_contact_fax
								   ELSE foreign_exporter_fax
							   END as foreign_exporter_fax
							, CASE WHEN foreign_exporter_sameas_generator = 'T' THEN tech_cont_email
								   ELSE foreign_exporter_email
							   END as foreign_exporter_email
							, epa_notice_id, epa_consent_number, NULL, NULL, approved_volume, approved_volume_unit
							, importing_generator_id, importing_generator_name, importing_generator_address, importing_generator_city
							, importing_generator_province_territory, importing_generator_mail_code, importing_generator_epa_id
							, tech_contact_id, tech_contact_name, tech_contact_phone, tech_cont_email, tech_contact_fax
							, @web_userid, GETDATE(), GETDATE(), @modified_by_web_user_id, foreign_exporter_sameas_generator
						FROM dbo.ProfileWasteImport
					    LEFT JOIN dbo.Generator g ON g.generator_id = @profile_generator_id
						WHERE profile_id = @profile_id;
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception ON Waste import INSERT ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		-- WASTE IMPORT SUPPLEMENT End
		-- GENERATOR KNOWLEDGE SUPPLEMENT INSERT
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileGeneratorKnowledge WHERE profile_id = @profile_id)
				BEGIN
					INSERT INTO dbo.FormGeneratorKnowledge (form_id, revision_id, profile_id, locked, specific_gravity, ppe_code
							, rcra_reg_metals, rcra_reg_vo, rcra_reg_svo, rcra_reg_herb_pest, rcra_reg_cyanide_sulfide, rcra_reg_ph
							, material_cause_flash, material_meet_alc_exempt, analytical_comments, print_name
							,created_by, date_created, modified_by, date_modified)
					SELECT @new_form_id AS form_id, @revision_id AS revision_id, NULL AS profile_id, 'U' AS locked, specific_gravity, ppe_code
							, rcra_reg_metals, rcra_reg_vo, rcra_reg_svo, rcra_reg_herb_pest, rcra_reg_cyanide_sulfide, rcra_reg_ph
							, material_cause_flash, material_meet_alc_exempt, analytical_comments, print_name
							, @web_userid, GETDATE(), @modified_by_web_user_id, GETDATE()
						FROM dbo.ProfileGeneratorKnowledge
						WHERE profile_id = @profile_id;
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception while Coping ProfileGeneratorKnowledge to FormGeneratorKnowledge ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		-- GENERATOR KNOWLEDGE SUPPLEMENT END
		--Fuel Blending Start
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM dbo.ProfileEcoflo WHERE profile_id = @profile_id)
				BEGIN
					DECLARE @FB_form_id INT
							, @FB_rev_id INT = 1

					EXEC @FB_form_id = sp_sequence_next 'form.form_id'

					INSERT INTO dbo.FormEcoflo (form_id, revision_id, formWCR_uid							--< New Column
							, wcr_id, wcr_rev_id, viscosity_value
							, total_solids_low, total_solids_high, total_solids_description, fluorine_low, fluorine_high
							, chlorine_low, chlorine_high, bromine_low, bromine_high, iodine_low, iodine_high
							, created_by, modified_by, date_created, date_modified, total_solids_flag, organic_halogens_flag
							, fluorine_low_flag, fluorine_high_flag, chlorine_low_flag, chlorine_high_flag
							, bromine_low_flag, bromine_high_flag, iodine_low_flag, iodine_high_flag)
					SELECT @FB_form_id, @FB_rev_id, @NewFormWCR_uid										--< Identity from FormWCR
							, @new_form_id, @revision_id, viscosity_value
							, total_solids_low, total_solids_high, total_solids_description, fluorine_low, fluorine_high
							, chlorine_low, chlorine_high, bromine_low, bromine_high, iodine_low, iodine_high
							, added_by, modified_by, GETDATE(), GETDATE(), total_solids_flag, organic_halogens_flag
							, fluorine_low_flag, fluorine_high_flag, chlorine_low_flag, chlorine_high_flag
							, bromine_low_flag, bromine_high_flag, iodine_low_flag, iodine_high_flag
						FROM dbo.ProfileEcoflo
						WHERE profile_id = @profile_id;
				END
		END TRY

		BEGIN CATCH
			INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
				VALUES ('Exception while Coping ProfileEcoflo to FormEcoflo ::' + ERROR_MESSAGE(), ERROR_PROCEDURE(), @web_userid, GETDATE());
		END CATCH

		--Fuel Blending End
		-- VALIDATION
		EXEC sp_Insert_Section_Status @new_form_id, @revision_id, @web_userid;
		EXEC sp_Validate_FormWCR @new_form_id, @revision_id, 'A,B,C,D,E,F,G,H,SL', @web_userid;
		EXEC sp_COR_Insert_Supplement_Section_Status @new_form_id, @revision_id, @web_userid;
		EXEC sp_COR_Validate_Supplementary_Form @new_form_id, @revision_id, @web_userid;

		SET @r_form_id = CONCAT (@new_form_id, '-', @revision_id)
		SET @r_revision_id = @revision_id

		--SELECT CONCAT (@new_form_id, '-', @revision_id) AS form_id, @revision_id AS revision_id

		/* update profile status AS pending after amending the profile */
		IF (@copysource = 'amendment' OR @copysource = 'for renewal' OR @copysource = 'renewal')
			BEGIN
				UPDATE dbo.[Profile]
					SET document_update_status = 'P'
					    , doc_status_reason = CASE WHEN @copysource = 'amendment' THEN 'Amendment in process'
												WHEN @copysource = 'for renewal' OR @copysource = 'renewal' THEN 'Renewal in process'
											END
					WHERE profile_id = @profile_id;
			END
	END TRY

	BEGIN CATCH
		DECLARE @Message VARCHAR(4000);
		SET @Message = ERROR_MESSAGE();

		--SELECT @Message AS MessageResult
		INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
			VALUES ('Profile ID: ' + CONVERT(VARCHAR(10), @profile_id) + 'Form ID: ' + CONVERT(VARCHAR(10), @new_form_id) + 'Revision ID: '
						+ CONVERT(VARCHAR(10), @revision_id) + ' :: Copy Source::  ' + @copysource + ' :  Error Message -->' + ERROR_MESSAGE()
					, ERROR_PROCEDURE(), @web_userid, GETDATE());
	END CATCH
END
GO

GRANT EXEC ON [dbo].[sp_Approved_Copy] TO COR_USER
GO
