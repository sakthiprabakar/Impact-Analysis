ALTER PROCEDURE dbo.sp_FormWCR_insert_update  
	  @Data XML
	, @formId INTEGER
	, @Revision_id INTEGER
	, @template_form_id INTEGER = NULL
	, @Message VARCHAR(2047) OUTPUT
	, @form_Id INT OUTPUT
	, @rev_id INT OUTPUT
AS  
/* ******************************************************************  
    Updated By       : Pasupathi P
    Updated On       : 1st JUL 2024
    Type             : Stored Procedure
    Ticket           : 89274
    Object Name      : [sp_FormWCR_insert_update]
	--Updated by Blair Christensen for Titan 05/21/2025
  
Updated to the template related changes Requirement 89274: Profile Template > UI Functionality & API Integration
***********************************************************************/  
BEGIN  
	DECLARE @SectionA_data XML
		  , @SectionB_data XML
		  , @SectionC_data XML
		  , @SectionD_data XML
		  , @SectionE_data XML
		  , @SectionF_data XML
		  , @SectionG_data XML
		  , @SectionH_data XML
		  , @PCB_data XML
		  , @LDR_data XML
		  , @Benzene_data XML
		  , @IllinoisDisposal_data XML
		  , @Pharmaceutical_data XML
		  , @UsedOil_data XML
		  , @WasteImport_data XML
		  , @Certification_data XML
		  , @Thermal_data XML
		  , @Document_data XML
		  , @Cylinder_data XML
		  , @Debris_data XML
		  , @Radioactive_data XML
		  , @GeneratorLocation_data XML
		  , @SectionL_data XML
		  , @SectionGK_data XML
		  , @FuelsBlending_data XML;  
  
	DECLARE @i_copy_source VARCHAR(100) = 'new'
		  , @temp_doc_source VARCHAR(2) = 'F';  
  
	DECLARE @web_userid VARCHAR(100) = (SELECT p.v.value('created_by[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel')p(v))
		  , @date_created DATETIME = (SELECT p.v.value('date_created[1]','DATETIME') FROM @Data.nodes('ProfileModel')p(v))  
		  , @date_modified DATETIME = (SELECT p.v.value('date_modified[1]','DATETIME') FROM @Data.nodes('ProfileModel')p(v))  
		  , @modified_by VARCHAR(100) = (SELECT p.v.value('modified_by[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel')p(v))  
		  ;
  
	DECLARE @EditedSectionDetails VARCHAR(150);  
	DECLARE @SectionAedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/SectionA')p(v))
		  , @SectionBedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/SectionB')p(v))
		  , @SectionCedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/SectionC')p(v))
		  , @SectionDedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/SectionD')p(v))
		  , @SectionEedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/SectionE')p(v))
		  , @SectionFedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/SectionF')p(v))
		  , @SectionGedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/SectionG')p(v))
		  , @SectionHedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/SectionH')p(v))
		  , @PCBedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/PCB')p(v))
		  , @LDRedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/LDR')p(v))
		  , @Benzeneedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/Benzene')p(v))
		  , @IllinoisDisposaledited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/IllinoisDisposal')p(v))
		  , @Pharmaceuticaledited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/Pharmaceutical')p(v))
		  , @UsedOiledited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/Usedoil')p(v))
		  , @WasteImportedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/WasteImport')p(v))
		  , @Certificationedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/Certification')p(v))
		  , @Thermaledited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/Thermal')p(v))
		  , @Documentedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/DocumentAttachment')p(v))
		  , @Cylinderedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/Cylinder')p(v))
		  , @Debrisedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/Debris')p(v))
		  , @Radioactiveedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/Radioactive')p(v))
		  , @GeneratorLocation VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/GeneratorLocation')p(v))
		  , @SectionLedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/SectionL')p(v))
		  , @SectionGKedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/GeneratorKnowledge')p(v))
		  , @SectionFBedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') FROM @Data.nodes('ProfileModel/FuelsBlending')p(v))
		  ;  
    
	DECLARE @PCBFlag VARCHAR(2) = (SELECT p.v.value('pcbflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @LDRFlag VARCHAR(2) = (SELECT p.v.value('ldrflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @BZFlag VARCHAR(2) = (SELECT p.v.value('bzflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @IDFlag VARCHAR(2) =(SELECT p.v.value('idflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @PLFlag VARCHAR(2) = (SELECT p.v.value('pharmaflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @WIFlag VARCHAR(2) = (SELECT p.v.value('wasteimportflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @ULFlag VARCHAR(2) = (SELECT p.v.value('usedoilflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @CNFlag VARCHAR(2) = (SELECT p.v.value('certificationflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @TLFlag VARCHAR(2) = (SELECT p.v.value('thermalflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @CRFlag VARCHAR(2) = (SELECT p.v.value('cylinderflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @DSFlag VARCHAR(2) = (SELECT p.v.value('debrisflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @RAFlag VARCHAR(2) = (SELECT p.v.value('radioactiveflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @GLFlag VARCHAR(2) = (SELECT p.v.value('generatorlocationflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @GKFlag VARCHAR(2) = (SELECT p.v.value('generatorknowledgeflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @IsTemplateFlag VARCHAR(2) = (SELECT p.v.value('istemplateflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  , @FBFlag VARCHAR(2) = (SELECT p.v.value('fuelblendingflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v))
		  ;  
    
	 SELECT @SectionA_data = @Data.query('ProfileModel/SectionA')
		  , @SectionB_data = @Data.query('ProfileModel/SectionB')
		  , @SectionC_data = @Data.query('ProfileModel/SectionC')
		  , @SectionD_data = @Data.query('ProfileModel/SectionD')
		  , @SectionE_data = @Data.query('ProfileModel/SectionE')
		  , @SectionF_data = @Data.query('ProfileModel/SectionF')
		  , @SectionG_data = @Data.query('ProfileModel/SectionG')
		  , @SectionH_data = @Data.query('ProfileModel/SectionH')
		  , @PCB_data = @Data.query('ProfileModel/PCB')
		  , @LDR_data = @Data.query('ProfileModel/LDR')
		  , @Benzene_data = @Data.query('ProfileModel/Benzene')
		  , @IllinoisDisposal_data = @Data.query('ProfileModel/IllinoisDisposal')
		  , @Pharmaceutical_data = @Data.query('ProfileModel/Pharmaceutical')
		  , @UsedOil_data = @Data.query('ProfileModel/Usedoil')
		  , @WasteImport_data = @Data.query('ProfileModel/WasteImport')
		  , @Certification_data = @Data.query('ProfileModel/Certification')
		  , @Thermal_data = @Data.query('ProfileModel/Thermal')
		  , @Document_data = @Data.query('ProfileModel/DocumentAttachment')
		  , @Cylinder_data = @Data.query('ProfileModel/Cylinder')
		  , @Debris_data = @Data.query('ProfileModel/Debris')
		  , @Radioactive_data = @Data.query('ProfileModel/Radioactive')
		  , @GeneratorLocation_data = @Data.query('ProfileModel/GeneratorLocation')
		  , @SectionL_data = @Data.query('ProfileModel/SectionL')
		  , @SectionGK_data = @Data.query('ProfileModel/GeneratorKnowledge')
		  , @FuelsBlending_data = @Data.query('ProfileModel/FuelsBlending')
		  ;
  
	DECLARE @CommonName VARCHAR(50) = (SELECT p.v.value('waste_common_name[1]','VARCHAR(50)') FROM @SectionB_data.nodes('SectionB')p(v));  
  
	 IF @template_form_id IS NOT NULL  
		BEGIN  
			SET @i_copy_source = 'Template';  
		END  
  
	SELECT @Documentedited = CASE WHEN COUNT(1) > 0 THEN 'DA' ELSE NULL END
	  FROM @Data.nodes('ProfileModel/DocumentAttachment/DocumentAttachment/DocumentAttachment')p(v)
	 WHERE p.v.value('document_source[1]','VARCHAR(30)') IS NOT NULL;
  
	IF NOT EXISTS (SELECT 1 FROM dbo.FormWCR WHERE form_id = @formId AND revision_id = @Revision_id)  
		BEGIN  
			INSERT INTO dbo.FormWCR (form_id, revision_id
				 --, form_version_id, customer_id_from_form, customer_id, app_id, tracking_id
				 , [status], locked, [source]
				 --, signing_name, signing_company, signing_title, signing_date
				 , date_created, date_modified, created_by, modified_by
				 --, comments, sample_id, cust_name, cust_addr1, cust_addr2, cust_addr3, cust_addr4, cust_city, cust_state, cust_zip, cust_country
				 --, inv_contact_name, inv_contact_phone, inv_contact_fax
				 --, tech_contact_name, tech_contact_phone, tech_contact_fax, tech_contact_mobile, tech_contact_pager, tech_cont_email
				 --, generator_id, EPA_ID, sic_code
				 --, generator_name, generator_address1, generator_address2, generator_address3, generator_address4, generator_city, generator_state, generator_zip, generator_county_id, generator_county_name
				 --, gen_mail_address1 , gen_mail_address2, gen_mail_address3, gen_mail_city, gen_mail_state, gen_mail_zip, generator_contact, generator_contact_title, generator_phone, generator_fax
				 --, waste_common_name, volume, frequency, dot_shipping_name, surcharge_exempt
				 --, pack_bulk_solid_yard, pack_bulk_solid_ton, pack_bulk_liquid, pack_totes, pack_totes_size, pack_cy_box, pack_drum, pack_other, pack_other_desc
				 --, color, odor, poc, consistency_solid, consistency_dust, consistency_liquid, consistency_sludge
				 --, ph, ph_lte_2, ph_gt_2_lt_5, ph_gte_5_lte_10, ph_gt_10_lt_12_5, ph_gte_12_5, ignitability, waste_contains_spec_hand_none
				 --, free_liquids, oily_residue, metal_fines, biodegradable_sorbents, amines, ammonia, dioxins, furans, biohazard
				 --, shock_sensitive_waste, reactive_waste, radioactive_waste, explosives, pyrophoric_waste, isocyanates
				 --, asbestos_friable, asbestos_non_friable, gen_process, rcra_listed, rcra_listed_comment, rcra_characteristic, rcra_characteristic_comment
				 --, state_waste_code_flag, state_waste_code_flag_comment, wastewater_treatment, exceed_ldr_standards, meets_alt_soil_treatment_stds
				 --, more_than_50_pct_debris, oxidizer, react_cyanide, react_sulfide, info_basis
				 --, D004, D005, D006, D007, D008, D009, D010, D011, D012, D013, D014, D015, D016, D017, D018, D019
				 --, D020, D021, D022, D023, D024, D025, D026, D027, D028, D029, D030, D031, D032, D033, D034, D035, D036, D037, D038, D039, D040, D041, D042, D043
				 --, D004_concentration, D005_concentration, D006_concentration, D007_concentration, D008_concentration, D009_concentration
				 --, D010_concentration, D011_concentration, D012_concentration, D013_concentration, D014_concentration
				 --, D015_concentration, D016_concentration, D017_concentration, D018_concentration, D019_concentration
				 --, D020_concentration, D021_concentration, D022_concentration, D023_concentration, D024_concentration
				 --, D025_concentration, D026_concentration, D027_concentration, D028_concentration, D029_concentration
				 --, D030_concentration, D031_concentration, D032_concentration, D033_concentration, D034_concentration
				 --, D035_concentration, D036_concentration, D037_concentration, D038_concentration, D039_concentration
				 --, D040_concentration, D041_concentration, D042_concentration, D043_concentration
				 --, underlying_haz_constituents, michigan_non_haz, michigan_non_haz_comment, universal, recyclable_commodity, recoverable_petroleum_product
				 --, used_oil, pcb_concentration, pcb_source_concentration_gr_50, processed_into_non_liquid, processd_into_nonlqd_prior_pcb
				 --, pcb_non_lqd_contaminated_media, pcb_manufacturer, pcb_article_decontaminated, ccvocgr500, benzene, neshap_sic, tab_gr_10, avg_h20_gr_10
				 --, tab, benzene_gr_1, benzene_concentration, benzene_unit, fuel_blending, btu_per_lb, pct_chlorides, pct_moisture, pct_solids
				 --, intended_for_reclamation, pack_drum_size, water_reactive, aluminum, subject_to_mact_neshap, subject_to_mact_neshap_codes
				 --, srec_exempt_id, ldr_ww_or_nww, ldr_subcategory, ldr_manage_id
				 --, wwa_info_basis, wwa_bis_phthalate_flag, wwa_bis_phthalate_actual, wwa_carbazole_flag, wwa_carbazole_actual
				 --, wwa_o_cresol_flag, wwa_o_cresol_actual, wwa_p_cresol_flag, wwa_p_cresol_actual, wwa_n_decane_flag, wwa_n_decane_actual
				 --, wwa_fluoranthene_flag, wwa_fluoranthene_actual, wwa_n_octadecane_flag, wwa_n_octadecane_actual
				 --, wwa_trichlorophenol_246_flag, wwa_trichlorophenol_246_actual, wwa_phosphorus_flag, wwa_phosphorus_actual
				 --, wwa_total_chlor_phen_flag, wwa_total_chlor_phen_actual, wwa_total_organic_actual, wwa_pcb_flag, wwa_pcb_actual
				 --, wwa_acidity_flag, wwa_acidity_actual, wwa_fog_flag, wwa_fog_actual, wwa_tss_flag, wwa_tss_actual
				 --, wwa_bod_flag, wwa_bod_actual, wwa_antimony_flag, wwa_antimony_actual, wwa_arsenic_flag, wwa_arsenic_actual
				 --, wwa_cadmium_flag, wwa_cadmium_actual, wwa_chromium_flag, wwa_chromium_actual, wwa_cobalt_flag, wwa_cobalt_actual
				 --, wwa_copper_flag, wwa_copper_actual, wwa_cyanide_flag, wwa_cyanide_actual, wwa_iron_flag, wwa_iron_actual
				 --, wwa_lead_flag, wwa_lead_actual, wwa_mercury_flag, wwa_mercury_actual, wwa_nickel_flag, wwa_nickel_actual
				 --, wwa_silver_flag, wwa_silver_actual, wwa_tin_flag, wwa_tin_actual, wwa_titanium_flag, wwa_titanium_actual
				 --, wwa_vanadium_flag, wwa_vanadium_actual, wwa_zinc_flag, wwa_zinc_actual, wwa_method_8240, wwa_method_8270, wwa_method_8080, wwa_method_8150
				 --, wwa_used_oil, wwa_oil_mixed, wwa_halogen_gt_1000, wwa_halogen_source, wwa_halogen_source_desc1, wwa_other_desc_1
				 --, profile_id, facility_instruction, emergency_phone_number, generator_email, frequency_other, hazmat_flag, hazmat_class
				 --, subsidiary_haz_mat_class, package_group, un_na_flag, un_na_number, erg_number, erg_suffix, dot_shipping_desc
				 --, reportable_quantity_flag, RQ_reason, odor_other_desc, consistency_debris, consistency_gas_aerosol, consistency_varies
				 --, pH_NA, ignitability_lt_90, ignitability_90_139, ignitability_140_199, ignitability_gte_200, ignitability_NA
				 --, air_reactive, temp_ctrl_org_peroxide, NORM, TENORM, handling_issue, handling_issue_desc, rcra_exempt_flag, RCRA_exempt_reason
				 --, cyanide_plating, EPA_source_code, EPA_form_code, waste_water_flag, debris_dimension_weight
				 --, info_basis_knowledge, info_basis_analysis, info_basis_msds, universal_recyclable_commodity
				 --, pcb_concentration_none, pcb_concentration_0_49, pcb_concentration_50_499, pcb_concentration_500, ddvohapgr500
				 --, neshap_chem_1, neshap_chem_2, neshap_standards_part, neshap_subpart, benzene_onsite_mgmt, benzene_onsite_mgmt_desc
				 , copy_source
				 --, source_form_id, source_revision_id, tech_contact_id, generator_contact_id, inv_contact_id
				 , template_form_id
				 --, date_last_profile_sync, manifest_dot_sp_number, generator_country, gen_mail_name, gen_mail_address4, gen_mail_country, generator_type_ID
				 --, NAICS_code, state_id, po_required, purchase_order, inv_contact_email, DOT_shipping_desc_additional, DOT_inhalation_haz_flag
				 --, container_type_bulk, container_type_totes, container_type_pallet, container_type_boxes, container_type_drums, container_type_cylinder
				 --, container_type_labpack, container_type_combination, container_type_combination_desc, container_type_other, container_type_other_desc
				 --, odor_strength, odor_type_ammonia, odor_type_amines, odor_type_mercaptans, odor_type_sulfur, odor_type_organic_acid, odor_type_other
				 --, liquid_phase, paint_filter_solid_flag, incidental_liquid_flag
				 --, ignitability_compare_symbol, ignitability_compare_temperature, ignitability_does_not_flash, ignitability_flammable_solid
				 --, texas_waste_material_type, texas_state_waste_code, PA_residual_waste_flag, react_sulfide_ppm, react_cyanide_ppm
				 --, radioactive, reactive_other_description, reactive_other, contains_pcb, dioxins_or_furans, metal_fines_powder_paste
				 --, temp_control, thermally_unstable, compressed_gas, tires, organic_peroxide, beryllium_present, asbestos_flag, asbestos_friable_flag
				 --, hazardous_secondary_material, hazardous_secondary_material_cert, pharma_waste_subject_to_prescription
				 --, waste_treated_after_generation, waste_treated_after_generation_desc, debris_separated, debris_not_mixed_or_diluted
				 --, origin_refinery, specific_technology_requested, requested_technology, other_restrictions_requested, thermal_process_flag
				 --, DOT_sp_permit_flag, DOT_sp_permit_text, BTU_lt_gt_5000, ammonia_flag
				 --, pcb_concentration_0_9, pcb_concentration_10_49, pcb_regulated_for_disposal_under_TSCA, pcb_article_for_TSCA_landfill
				 --, display_status_uid, RCRA_waste_code_flag, RQ_threshold, submitted_by, date_submitted, DOT_waste_flag, section_F_none_apply_flag
				 --, routing_facility, waste_meets_ldr_standards, signed_on_behalf_of, PFAS_Flag, approval_code
				 )
			VALUES (@formId, @Revision_id
				 , 'A', 'U', 'W'
				 , GETDATE(), GETDATE(), @web_userid, @web_userid
				 , @i_copy_source
				 , @template_form_id);
		END   
	ELSE   
		BEGIN  
			DECLARE @signing_name VARCHAR(40)
				  , @signing_title VARCHAR(40)
				  , @signing_company VARCHAR(40)  

			SELECT @signing_name = p.v.value('signing_name[1]','VARCHAR(40)')
				 , @signing_title = p.v.value('signing_title[1]','VARCHAR(40)')
				 , @signing_company = p.v.value('signing_company[1]','VARCHAR(40)')  
			  FROM @SectionH_data.nodes('SectionH')p(v);
  
			UPDATE dbo.FormWCR
			   SET date_modified = GETDATE()
			     , modified_by = @modified_by
				 , signing_name = @signing_name
				 , signing_title = @signing_title
				 , signing_company = @signing_company  
			 WHERE form_id = @formId
			   AND revision_id = @Revision_id;
		END    
     
	IF NOT EXISTS (SELECT 1 FROM dbo.ContactCORFormWCRBucket WHERE form_id = @formId AND revision_id = @Revision_id)  
		BEGIN  
			INSERT INTO dbo.ContactCORFormWCRBucket (contact_id
				 , form_id, revision_id, customer_id, generator_id)
			VALUES( (SELECT TOP 1 contact_ID FROM dbo.Contact WHERE web_userid = @web_userid)
				 , @formId, @Revision_id, NULL, NULL);
		END  
  
		BEGIN TRY     
			IF @SectionAedited = 'A'   
				BEGIN  
					EXEC sp_FormWCR_insert_update_section_A @SectionA_data, @FormId, @Revision_id;  
				END  
			IF @SectionBedited = 'B'   
				BEGIN  
					EXEC sp_FormWCR_insert_update_section_B @SectionB_data, @FormId, @Revision_id;  
				END  
			IF @SectionCedited = 'C'   
				BEGIN  
					EXEC sp_FormWCR_insert_update_section_C @SectionC_data, @FormId, @Revision_id, @web_userid;  
				END  
			IF @SectionDedited = 'D'   
				BEGIN  
					EXEC sp_FormWCR_insert_update_section_D @SectionD_data, @FormId, @Revision_id;  
				END  
			IF @SectionEedited = 'E'   
				BEGIN  
					EXEC sp_FormWCR_insert_update_section_E @SectionE_data, @FormId, @Revision_id;  
				END  
			IF @SectionFedited = 'F'   
			   BEGIN  
					EXEC sp_FormWCR_insert_update_section_F @SectionF_data, @FormId, @Revision_id;  
			   END  
			IF @SectionGedited = 'G'   
				BEGIN  
					EXEC sp_FormWCR_insert_update_section_G  @SectionG_data, @FormId, @Revision_id;  
				END  
			IF @SectionHedited = 'H'   
				BEGIN  
					EXEC sp_FormWCR_insert_update_section_H  @SectionH_data, @FormId, @Revision_id, @web_userid;  
				END  
			IF @SectionLedited = 'SL'   
				BEGIN  
					EXEC sp_FormWCR_insert_update_section_L  @SectionL_data, @FormId, @Revision_id;  
				END  
  
			EXEC sp_COR_Insert_Supplement_Section_Status @FormId, @Revision_id, @modified_by;
  
			IF @PCBFlag = 'T'
				BEGIN  
					SET @PCBedited = 'PB'
					EXEC sp_pcb_insert_update @PCB_data, @FormId, @Revision_id;  
				END  
  
			IF @Documentedited = 'DA'
				BEGIN  
					EXEC sp_document_insert_update @Document_data, @FormId, @Revision_id, @web_userid;  
				END   
  
			IF @LDRFlag = 'T'  
				BEGIN  
					SET @LDRedited = 'LR'
					EXEC sp_ldr_insert_update  @LDR_data,@FormId,@Revision_id,@web_userid;  
				END  
  
			IF @BZFlag = 'T'  
				BEGIN  
					SET @Benzeneedited = 'BZ'
					EXEC sp_benzene_insert_update @Benzene_data, @FormId, @Revision_id, @web_userid;  
				END  
  
			IF @IDFlag = 'T'
				BEGIN  
					SET @IllinoisDisposaledited = 'ID'
					EXEC sp_IllinoisDisposal_insert_update @IllinoisDisposal_data, @FormId, @Revision_id, @web_userid;  
				END  
  
			IF @PLFlag = 'T'
				BEGIN  
					SET @Pharmaceuticaledited = 'PL'
					EXEC sp_pharmaceutical_insert_update @Pharmaceutical_data, @FormId, @Revision_id, @web_userid;  
				END  
  
			IF @WIFlag  = 'T'
				BEGIN
					SET @WasteImportedited = 'WI'
					EXEC sp_wasteImport_insert_update @WasteImport_data, @FormId, @Revision_id, @web_userid;  
				END
  
			IF @ULFlag  = 'T'  
				BEGIN
					SET @UsedOiledited = 'UL'
					EXEC sp_usedOil_insert_update @UsedOil_data, @FormId, @Revision_id;  
				END
  
			IF @CNFlag  = 'T'
				BEGIN
					SET @Certificationedited = 'CN'
					EXEC sp_certification_insert_update @Certification_data, @FormId, @Revision_id, @web_userid;
				END
  
			IF @TLFlag  = 'T'
				BEGIN
					SET @Thermaledited = 'TL'
					EXEC sp_thermal_insert_update @Thermal_data, @FormId, @Revision_id, @web_userid;
				END  
  
			IF @CRFlag = 'T'
				BEGIN
					SET @Cylinderedited = 'CR'
					EXEC sp_cylinder_insert_update @Cylinder_data, @FormId, @Revision_id, @web_userid;
				END
  
			IF @DSFlag = 'T'  
				BEGIN
					SET @Debrisedited = 'DS'
					EXEC sp_Debris_insert_update  @Debris_data, @FormId, @Revision_id, @web_userid;
			END         

			IF @RAFlag = 'T'  
				BEGIN
					SET @Radioactiveedited = 'RA'
					EXEC sp_Radioactive_insert_update @Radioactive_data, @FormId, @Revision_id, @web_userid;
				END

			IF @GLFlag = 'T'
				BEGIN
					SET @GeneratorLocation = 'GL'
					EXEC sp_GeneratorLocation_insert_update @GeneratorLocation_data, @FormId, @Revision_id, @web_userid;
				END  
     
			IF @GKFlag = 'T'
				BEGIN
					SET @SectionGKedited = 'GK'
					EXEC sp_FormGenerator_Knowledge_Insert_Update @FormId, @Revision_id, @SectionGK_data, @web_userid;
			END  
  
			IF @FBFlag = 'T'
				BEGIN
					SET @SectionFBedited = 'FB'
					EXEC sp_FormEcoflo_insert_update @FuelsBlending_data, @FormId, @Revision_id, @web_userid;
				END
  
			IF @IsTemplateFlag = 'T'
				BEGIN
					IF NOT EXISTS(SELECT 1 FROM dbo.FormWCRTemplate WHERE template_form_id = @formId)  
						BEGIN  
							INSERT INTO dbo.FormWCRTemplate (template_form_id, name, description
							     , created_by, date_created, modified_by, date_modified, status)  
							VALUES (@formId, @CommonName, @CommonName
								 , @web_userid, GETDATE(), @web_userid, GETDATE(), 'A')  
						END  
			ELSE   
				BEGIN  
					UPDATE dbo.FormWCRTemplate
					   SET [name] = @CommonName, [description] = @CommonName
					 WHERE template_form_id = @formId;
				END  
			END  
  
			-- Check form is exist in the status tables  
			DECLARE @formid_exist_count INT
			SELECT @formid_exist_count = COUNT(*)
			  FROM dbo.FormWCR
			 WHERE form_id = @FormId
			   AND revision_id = @Revision_id;
  
			EXEC sp_Insert_Section_Status @FormId, @Revision_id, @web_userid;  
        
			SET @EditedSectionDetails = ISNULL(@SectionAedited,0)
			    + ',' + ISNULL(@SectionBedited,0)
				+ ',' + ISNULL(@SectionCedited,0)
				+ ',' + ISNULL(@SectionDedited,0)
				+ ',' + ISNULL(@SectionEedited,0)
				+ ',' + ISNULL(@SectionFedited,0)
				+ ',' + ISNULL(@SectionGedited,0)
				+ ',' + ISNULL(@SectionHedited,0)
				+ ',' + ISNULL(@PCBedited,0)
				+ ',' + ISNULL(@LDRedited,0)
				+ ',' + ISNULL(@Benzeneedited,0)
				+ ',' + ISNULL(@IllinoisDisposaledited,0)
				+ ',' + ISNULL(@Pharmaceuticaledited,0)
				+ ',' + ISNULL(@WasteImportedited,0)
				+ ',' + ISNULL(@UsedOiledited,0)
				+ ',' + ISNULL(@Certificationedited,0)
				+ ',' + ISNULL(@Thermaledited,0)
				+ ',' + ISNULL(@Cylinderedited,0)
				+ ',' + ISNULL(@Debrisedited,0)
				+ ',' + ISNULL(@Documentedited,0)
				+ ',' + ISNULL(@Radioactiveedited,0)
				+ ',' + ISNULL(@GeneratorLocation,0)
				+ ',' + ISNULL(@SectionLedited,0)
				+ ',' + ISNULL(@SectionGKedited, 0)
				+ ',' + ISNULL(@SectionFBedited, 0)
				;  
      
			EXEC sp_Validate_FormWCR @FormId, @Revision_id, @EditedSectionDetails, @web_userid;
  
			EXEC sp_update_FormSectionStatus @FormId, @Revision_id, @PCBFlag, @LDRFlag, @BZFlag
			   , @IDFlag, @PLFlag, @WIFlag, @ULFlag, @CNFlag, @TLFlag, @CRFlag, @DSFlag, @RAFlag ,@GLFlag;
         
			SET @Message = 'Profile saved successfully';  
			SET @form_Id = @formId;
			SET @rev_id = @Revision_id;  
	END TRY

	BEGIN CATCH
		SET @Message = ERROR_MESSAGE();
		SET @form_Id = @formId;
        SET @rev_id = @Revision_id;

		DECLARE @mailTrack_userid VARCHAR(60) = 'COR'  
		DECLARE @procedure VARCHAR(150)   
		SET @procedure = ERROR_PROCEDURE();    
		DECLARE @error VARCHAR(4500) = 'Form ID: ' + CONVERT(VARCHAR(15), @form_Id)
			  + '-' +  CONVERT(VARCHAR(15), @rev_id)
			  + CHAR(13) + 'Error Message: ' + ISNULL(@Message, '')  
              + CHAR(13) + 'Data: ' + CONVERT(VARCHAR(2000), @Data)  
  
		EXEC COR_DB.dbo.sp_COR_Exception_MailTrack @web_userid = @mailTrack_userid, @object = @procedure, @body = @error;

		INSERT INTO COR_DB.dbo.ErrorLogs (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)
		VALUES (@error, ERROR_PROCEDURE(), @mailTrack_userid, GETDATE());
	END CATCH

	SELECT @Message as [Message];
END;  
GO

GRANT EXEC ON [dbo].[sp_FormWCR_insert_update] TO COR_USER
GO 

GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update]  TO EQWEB 
GO 

GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update]  TO EQAI 
GO 