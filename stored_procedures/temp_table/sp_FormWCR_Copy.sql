
USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS sp_FormWCR_Copy 
GO
	CREATE PROCEDURE [dbo].[sp_FormWCR_Copy] 
		@form_id INT
		,@revision_id INT
		,
		--@copysource nvarchar(10),
		@web_user_id VARCHAR(100)
		,@modified_by_web_user_id VARCHAR(100) = ''
		,@Message VARCHAR(100) OUTPUT
		,@formId INT OUTPUT
		,@rev_id INT OUTPUT
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


	This procedure is used to copy FormWCR table i.e. for the pending profile

inputs 
	
	@formid
	@revision_ID
	@web_user_id



Samples:
 EXEC sp_FormWCR_SubmitProfile @form_id,@revision_ID,@web_user_id
 DECLARE @Message nvarchar(1000),@formId int,@rev_id int
 EXEC sp_FormWCR_Copy 786742, 1,'manand84',@Message,@formId,@rev_id
 select @Message, @formId

****************************************************************** */
BEGIN  
  SET NOCOUNT ON;  
  
  -- Generate new Form ID and dfault revision ID = 1  
  DECLARE @new_form_id INT  
   ,@revisonid INT = 1  
   ,@display_status_uid INT = 1  
   ,@source_form_id INT  
   ,@source_revision_id INT  
   ,@radioactiveUSEI_form_id INT  
   ,@radioactiveUSEI_revision_id INT  
   ,@radioactiveUSEI_new_form_id INT  
   ,@print_name NVARCHAR(100)  
   ,@contact_company NVARCHAR(100)  
   ,@title NVARCHAR(100)  
   ,@state_waste_code_flag CHAR(1)  
   ,@template_form_id INT
  
  SET @source_form_id = @form_id  
  SET @source_revision_id = @revision_id  
  
  SELECT TOP 1 @print_name = first_name + ' ' + last_name  
   ,@title = title  
   ,@contact_company = contact_company  
  FROM Contact  
  WHERE web_userid = @web_user_id  
   AND web_access_flag = 'T'  
   AND contact_status = 'A'  
  
  IF ISNULL(@modified_by_web_user_id, '') = ''  
   SET @modified_by_web_user_id = @web_user_id  

   SET @template_form_id = (SELECT TOP 1 template_form_id FROM plt_ai..formwcr WHERE form_id = @form_id);

IF @template_form_id IS NOT NULL AND EXISTS (SELECT 1 FROM formwcrtemplate WHERE template_form_id = @template_form_id )
BEGIN
 SET @template_form_id = null;
END

  
  --print 'Generator name' + @generator_name  
  EXEC @new_form_id = sp_sequence_next 'form.form_id'  
  
  BEGIN TRY  
   -- BEGIN TRANSACTION;  
   BEGIN TRY  
    INSERT INTO FormWCR (  
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
     ,[DOT_waste_flag]  
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
     ,[waste_meets_ldr_standards]  
     --,[exceed_ldr_standards]  
     ,[meets_alt_soil_treatment_stds]  
     ,[more_than_50_pct_debris]  
     ,[oxidizer]  
     ,[react_cyanide]  
     ,[react_sulfide]  
     ,[info_basis]  
     ,[D004]  
     ,[D005]  
     ,[D006]  
     ,[D007]  
     ,[D008]  
     ,[D009]  
     ,[D010]  
     ,[D011]  
     ,[D012]  
     ,[D013]  
     ,[D014]  
     ,[D015]  
     ,[D016]  
     ,[D017]  
     ,[D018]  
     ,[D019]  
     ,[D020]  
     ,[D021]  
     ,[D022]  
     ,[D023]  
     ,[D024]  
     ,[D025]  
     ,[D026]  
     ,[D027]  
     ,[D028]  
     ,[D029]  
     ,[D030]  
     ,[D031]  
     ,[D032]  
     ,[D033]  
     ,[D034]  
     ,[D035]  
     ,[D036]  
     ,[D037]  
     ,[D038]  
     ,[D039]  
     ,[D040]  
     ,[D041]  
     ,[D042]  
     ,[D043]  
     ,[D004_concentration]  
     ,[D005_concentration]  
     ,[D006_concentration]  
     ,[D007_concentration]  
     ,[D008_concentration]  
     ,[D009_concentration]  
     ,[D010_concentration]  
     ,[D011_concentration]  
     ,[D012_concentration]  
     ,[D013_concentration]  
     ,[D014_concentration]  
     ,[D015_concentration]  
     ,[D016_concentration]  
     ,[D017_concentration]  
     ,[D018_concentration]  
     ,[D019_concentration]  
     ,[D020_concentration]  
     ,[D021_concentration]  
     ,[D022_concentration]  
     ,[D023_concentration]  
     ,[D024_concentration]  
     ,[D025_concentration]  
     ,[D026_concentration]  
     ,[D027_concentration]  
     ,[D028_concentration]  
     ,[D029_concentration]  
     ,[D030_concentration]  
     ,[D031_concentration]  
     ,[D032_concentration]  
     ,[D033_concentration]  
     ,[D034_concentration]  
     ,[D035_concentration]  
     ,[D036_concentration]  
     ,[D037_concentration]  
     ,[D038_concentration]  
     ,[D039_concentration]  
     ,[D040_concentration]  
     ,[D041_concentration]  
     ,[D042_concentration]  
     ,[D043_concentration]  
     ,[underlying_haz_constituents]  
     ,[michigan_non_haz]  
     ,[michigan_non_haz_comment]  
     ,[universal]  
     ,[recyclable_commodity]  
     ,[recoverable_petroleum_product]  
     ,[used_oil]  
     ,[pcb_concentration]  
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
     ,[wwa_info_basis]  
     ,[wwa_bis_phthalate_flag]  
     ,[wwa_bis_phthalate_actual]  
     ,[wwa_carbazole_flag]  
     ,[wwa_carbazole_actual]  
     ,[wwa_o_cresol_flag]  
     ,[wwa_o_cresol_actual]  
     ,[wwa_p_cresol_flag]  
     ,[wwa_p_cresol_actual]  
     ,[wwa_n_decane_flag]  
     ,[wwa_n_decane_actual]  
     ,[wwa_fluoranthene_flag]  
     ,[wwa_fluoranthene_actual]  
     ,[wwa_n_octadecane_flag]  
     ,[wwa_n_octadecane_actual]  
     ,[wwa_trichlorophenol_246_flag]  
     ,[wwa_trichlorophenol_246_actual]  
     ,[wwa_phosphorus_flag]  
     ,[wwa_phosphorus_actual]  
     ,[wwa_total_chlor_phen_flag]  
     ,[wwa_total_chlor_phen_actual]  
     ,[wwa_total_organic_actual]  
     ,[wwa_pcb_flag]  
     ,[wwa_pcb_actual]  
     ,[wwa_acidity_flag]  
     ,[wwa_acidity_actual]  
     ,[wwa_fog_flag]  
     ,[wwa_fog_actual]  
     ,[wwa_tss_flag]  
     ,[wwa_tss_actual]  
     ,[wwa_bod_flag]  
     ,[wwa_bod_actual]  
     ,[wwa_antimony_flag]  
     ,[wwa_antimony_actual]  
     ,[wwa_arsenic_flag]  
     ,[wwa_arsenic_actual]  
     ,[wwa_cadmium_flag]  
     ,[wwa_cadmium_actual]  
     ,[wwa_chromium_flag]  
     ,[wwa_chromium_actual]  
     ,[wwa_cobalt_flag]  
     ,[wwa_cobalt_actual]  
     ,[wwa_copper_flag]  
     ,[wwa_copper_actual]  
     ,[wwa_cyanide_flag]  
     ,[wwa_cyanide_actual]  
     ,[wwa_iron_flag]  
     ,[wwa_iron_actual]  
     ,[wwa_lead_flag]  
     ,[wwa_lead_actual]  
     ,[wwa_mercury_flag]  
     ,[wwa_mercury_actual]  
     ,[wwa_nickel_flag]  
     ,[wwa_nickel_actual]  
     ,[wwa_silver_flag]  
     ,[wwa_silver_actual]  
     ,[wwa_tin_flag]  
     ,[wwa_tin_actual]  
     ,[wwa_titanium_flag]  
     ,[wwa_titanium_actual]  
     ,[wwa_vanadium_flag]  
     ,[wwa_vanadium_actual]  
     ,[wwa_zinc_flag]  
     ,[wwa_zinc_actual]  
     ,[wwa_method_8240]  
     ,[wwa_method_8270]  
     ,[wwa_method_8080]  
     ,[wwa_method_8150]  
     ,[wwa_used_oil]  
     ,[wwa_oil_mixed]  
     ,[wwa_halogen_gt_1000]  
     ,[wwa_halogen_source]  
     ,[wwa_halogen_source_desc1]  
     ,[wwa_other_desc_1]  
     ,[rowguid]  
     ,[profile_id]  
     ,[facility_instruction]  
     ,[emergency_phone_number]  
     ,[generator_email]  
     ,[frequency_other]  
     ,[hazmat_flag]  
     ,[hazmat_class]  
     ,[subsidiary_haz_mat_class]  
     ,[package_group]  
     ,[un_na_flag]  
     ,[un_na_number]  
     ,[erg_number]  
     ,[erg_suffix]  
     ,[dot_shipping_desc]  
     ,[reportable_quantity_flag]  
     ,[RQ_reason]  
     ,[odor_other_desc]  
     ,[consistency_debris]  
     ,[consistency_gas_aerosol]  
     ,[consistency_varies]  
     ,[pH_NA]  
     ,[ignitability_lt_90]  
     ,[ignitability_90_139]  
     ,[ignitability_140_199]  
     ,[ignitability_gte_200]  
     ,[ignitability_NA]  
     ,[air_reactive]  
     ,[temp_ctrl_org_peroxide]  
     ,[NORM]  
     ,[TENORM]  
     ,[handling_issue]  
     ,[handling_issue_desc]  
     ,[rcra_exempt_flag]  
     ,[RCRA_exempt_reason]  
     ,[cyanide_plating]  
     ,[EPA_source_code]  
     ,[EPA_form_code]  
     ,[waste_water_flag]  
     ,[debris_dimension_weight]  
     ,[info_basis_knowledge]  
     ,[info_basis_analysis]  
     ,[info_basis_msds]  
     ,[universal_recyclable_commodity]  
     ,[pcb_concentration_none]  
     ,[pcb_concentration_0_49]  
     ,[pcb_concentration_50_499]  
     ,[pcb_concentration_500]  
     ,[ddvohapgr500]  
     ,[neshap_chem_1]  
     ,[neshap_chem_2]  
     ,[neshap_standards_part]  
     ,[neshap_subpart]  
     ,[benzene_onsite_mgmt]  
     ,[benzene_onsite_mgmt_desc]  
     ,[copy_source]  
     ,[source_form_id]  
     ,[source_revision_id]  
     ,[tech_contact_id]  
     ,[generator_contact_id]  
     ,[inv_contact_id]  
     ,[template_form_id]  
     ,[date_last_profile_sync]  
     ,[manifest_dot_sp_number]  
     ,[generator_country]  
     ,[gen_mail_name]  
     ,[gen_mail_address4]  
     ,[gen_mail_country]  
     ,[generator_type_ID]  
     ,[NAICS_code]  
     ,[state_id]  
     ,[po_required]  
     ,[purchase_order]  
     ,[inv_contact_email]  
     ,[DOT_shipping_desc_additional]  
     ,[DOT_inhalation_haz_flag]  
     ,[container_type_bulk]  
     ,[container_type_totes]  
     ,[container_type_pallet]  
     ,[container_type_boxes]  
     ,[container_type_drums]  
     ,[container_type_cylinder]  
     ,[container_type_labpack]  
     ,[container_type_combination]  
     ,[container_type_combination_desc]  
     ,[container_type_other]  
     ,[container_type_other_desc]  
     ,[odor_strength]  
     ,[odor_type_ammonia]  
     ,[odor_type_amines]  
     ,[odor_type_mercaptans]  
     ,[odor_type_sulfur]  
     ,[odor_type_organic_acid]  
     ,[odor_type_other]  
     ,[liquid_phase]  
     ,[paint_filter_solid_flag]  
     ,[incidental_liquid_flag]  
     ,[ignitability_compare_symbol]  
     ,[ignitability_compare_temperature]  
     ,[ignitability_does_not_flash]  
     ,[ignitability_flammable_solid]  
     ,[texas_waste_material_type]  
     ,[texas_state_waste_code]  
     ,[PA_residual_waste_flag]  
     ,[react_sulfide_ppm]  
     ,[react_cyanide_ppm]  
     ,[radioactive]  
     ,[reactive_other_description]  
     ,[reactive_other]  
     ,[contains_pcb]  
     ,[dioxins_or_furans]  
     ,[metal_fines_powder_paste]  
     ,[temp_control]  
     ,[thermally_unstable]  
     ,[compressed_gas]  
     ,[tires]  
     ,[organic_peroxide]  
     ,[beryllium_present]  
     ,[asbestos_flag]  
     ,[asbestos_friable_flag]  
     ,[PFAS_Flag]  
     ,[hazardous_secondary_material]  
     ,[hazardous_secondary_material_cert]  
     ,[pharma_waste_subject_to_prescription]  
     ,[waste_treated_after_generation]  
     ,[waste_treated_after_generation_desc]  
     ,[debris_separated]  
     ,[debris_not_mixed_or_diluted]  
     ,[origin_refinery]  
     ,[specific_technology_requested]  
     ,[requested_technology]  
     ,[other_restrictions_requested]  
     ,[thermal_process_flag]  
     ,[DOT_sp_permit_text]  
     ,[BTU_lt_gt_5000]  
     ,[ammonia_flag]  
     ,[pcb_concentration_0_9]  
     ,[pcb_concentration_10_49]  
     ,[pcb_regulated_for_disposal_under_TSCA]  
     ,[pcb_article_for_TSCA_landfill]  
     ,[display_status_uid]  
     ,section_F_none_apply_flag  
     ,DOT_sp_permit_flag  
     ,RQ_threshold  
     ,RCRA_waste_code_flag  
     ,routing_facility  
     ,signed_on_behalf_of  
     ,approval_code  
     )  
    SELECT @new_form_id  
     ,@revisonid  
     ,[form_version_id]  
     ,[customer_id_from_form]  
     ,[customer_id]  
     ,[app_id]  
     ,[tracking_id]  
     ,FW.[status]  
     ,[locked]  
     ,FW.[source]  
     ,COALESCE(NULLIF([signing_name], ''), @print_name)  
     ,COALESCE(NULLIF([signing_company], ''), @contact_company)  
     ,COALESCE(NULLIF([signing_title], ''), @title)  
     ,NULL  
     --,GETDATE()  
     ,GETDATE()  
     ,GETDATE()  
     ,@web_user_id  
     ,@modified_by_web_user_id  
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
     ,FW.[generator_id]  
     ,FW.[EPA_ID]  
     ,FW.[sic_code]  
     ,ISNULL(G.generator_name, FW.generator_name) --[generator_name]  
     ,ISNULL(G.generator_address_1, FW.generator_address1) --[generator_address1]  
     ,ISNULL(G.generator_address_2, FW.generator_address2) --[generator_address2]  
     ,ISNULL(G.generator_address_3, FW.generator_address3) --[generator_address3]  
     ,ISNULL(G.generator_address_4, FW.generator_address4) --[generator_address4]  
     ,ISNULL(G.generator_city, FW.generator_city) --[generator_city]  
     ,ISNULL(G.generator_state, FW.generator_state) --[generator_state]  
     ,ISNULL(G.generator_zip_code, FW.generator_zip) --[generator_zip]  
     ,[generator_county_id]  
     ,[generator_county_name]  
     ,ISNULL(G.gen_mail_addr1, FW.gen_mail_address1) --[gen_mail_address1]  
     ,ISNULL(G.gen_mail_addr2, FW.gen_mail_address2) --[gen_mail_address2]  
     ,ISNULL(G.gen_mail_addr3, FW.gen_mail_address3) --[gen_mail_address3]  
     ,ISNULL(G.gen_mail_city, FW.gen_mail_city) --[gen_mail_city]  
     ,ISNULL(G.gen_mail_state, FW.gen_mail_state) --[gen_mail_state]  
     ,ISNULL(G.gen_mail_zip_code, FW.gen_mail_zip) --[gen_mail_zip]  
     ,[generator_contact]  
     ,[generator_contact_title]  
     ,ISNULL(G.generator_phone, FW.generator_phone) --[generator_phone]  
     ,ISNULL(G.generator_fax, FW.generator_fax) --[generator_fax]  
     ,[waste_common_name]  
     ,[volume]  
     ,[frequency]  
     ,[DOT_waste_flag]  
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
     ,[waste_meets_ldr_standards]  
     --,[exceed_ldr_standards]  
     ,[meets_alt_soil_treatment_stds]  
     ,[more_than_50_pct_debris]  
     ,[oxidizer]  
     ,[react_cyanide]  
     ,[react_sulfide]  
     ,[info_basis]  
     ,[D004]  
     ,[D005]  
     ,[D006]  
     ,[D007]  
     ,[D008]  
     ,[D009]  
     ,[D010]  
     ,[D011]  
     ,[D012]  
     ,[D013]  
     ,[D014]  
     ,[D015]  
     ,[D016]  
     ,[D017]  
     ,[D018]  
     ,[D019]  
     ,[D020]  
     ,[D021]  
     ,[D022]  
     ,[D023]  
     ,[D024]  
     ,[D025]  
     ,[D026]  
     ,[D027]  
     ,[D028]  
     ,[D029]  
     ,[D030]  
     ,[D031]  
     ,[D032]  
     ,[D033]  
     ,[D034]  
     ,[D035]  
     ,[D036]  
     ,[D037]  
     ,[D038]  
     ,[D039]  
     ,[D040]  
     ,[D041]  
     ,[D042]  
     ,[D043]  
     ,[D004_concentration]  
     ,[D005_concentration]  
     ,[D006_concentration]  
     ,[D007_concentration]  
     ,[D008_concentration]  
     ,[D009_concentration]  
     ,[D010_concentration]  
     ,[D011_concentration]  
     ,[D012_concentration]  
     ,[D013_concentration]  
     ,[D014_concentration]  
     ,[D015_concentration]  
     ,[D016_concentration]  
     ,[D017_concentration]  
     ,[D018_concentration]  
     ,[D019_concentration]  
     ,[D020_concentration]  
     ,[D021_concentration]  
     ,[D022_concentration]  
     ,[D023_concentration]  
     ,[D024_concentration]  
     ,[D025_concentration]  
     ,[D026_concentration]  
     ,[D027_concentration]  
     ,[D028_concentration]  
     ,[D029_concentration]  
     ,[D030_concentration]  
     ,[D031_concentration]  
     ,[D032_concentration]  
     ,[D033_concentration]  
     ,[D034_concentration]  
     ,[D035_concentration]  
     ,[D036_concentration]  
     ,[D037_concentration]  
     ,[D038_concentration]  
     ,[D039_concentration]  
     ,[D040_concentration]  
     ,[D041_concentration]  
     ,[D042_concentration]  
     ,[D043_concentration]  
     ,[underlying_haz_constituents]  
     ,[michigan_non_haz]  
     ,[michigan_non_haz_comment]  
     ,[universal]  
     ,[recyclable_commodity]  
     ,[recoverable_petroleum_product]  
     ,[used_oil]  
     ,[pcb_concentration]  
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
     ,FW.[tab]  
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
     ,[wwa_info_basis]  
     ,[wwa_bis_phthalate_flag]  
     ,[wwa_bis_phthalate_actual]  
     ,[wwa_carbazole_flag]  
     ,[wwa_carbazole_actual]  
     ,[wwa_o_cresol_flag]  
     ,[wwa_o_cresol_actual]  
     ,[wwa_p_cresol_flag]  
     ,[wwa_p_cresol_actual]  
     ,[wwa_n_decane_flag]  
     ,[wwa_n_decane_actual]  
     ,[wwa_fluoranthene_flag]  
     ,[wwa_fluoranthene_actual]  
     ,[wwa_n_octadecane_flag]  
     ,[wwa_n_octadecane_actual]  
     ,[wwa_trichlorophenol_246_flag]  
     ,[wwa_trichlorophenol_246_actual]  
     ,[wwa_phosphorus_flag]  
     ,[wwa_phosphorus_actual]  
     ,[wwa_total_chlor_phen_flag]  
     ,[wwa_total_chlor_phen_actual]  
     ,[wwa_total_organic_actual]  
     ,[wwa_pcb_flag]  
     ,[wwa_pcb_actual]  
     ,[wwa_acidity_flag]  
     ,[wwa_acidity_actual]  
     ,[wwa_fog_flag]  
     ,[wwa_fog_actual]  
     ,[wwa_tss_flag]  
     ,[wwa_tss_actual]  
     ,[wwa_bod_flag]  
     ,[wwa_bod_actual]  
     ,[wwa_antimony_flag]  
     ,[wwa_antimony_actual]  
     ,[wwa_arsenic_flag]  
     ,[wwa_arsenic_actual]  
     ,[wwa_cadmium_flag]  
     ,[wwa_cadmium_actual]  
     ,[wwa_chromium_flag]  
     ,[wwa_chromium_actual]  
     ,[wwa_cobalt_flag]  
     ,[wwa_cobalt_actual]  
     ,[wwa_copper_flag]  
     ,[wwa_copper_actual]  
     ,[wwa_cyanide_flag]  
     ,[wwa_cyanide_actual]  
     ,[wwa_iron_flag]  
     ,[wwa_iron_actual]  
     ,[wwa_lead_flag]  
     ,[wwa_lead_actual]  
     ,[wwa_mercury_flag]  
     ,[wwa_mercury_actual]  
     ,[wwa_nickel_flag]  
     ,[wwa_nickel_actual]  
     ,[wwa_silver_flag]  
     ,[wwa_silver_actual]  
     ,[wwa_tin_flag]  
     ,[wwa_tin_actual]  
     ,[wwa_titanium_flag]  
     ,[wwa_titanium_actual]  
     ,[wwa_vanadium_flag]  
     ,[wwa_vanadium_actual]  
     ,[wwa_zinc_flag]  
     ,[wwa_zinc_actual]  
     ,[wwa_method_8240]  
     ,[wwa_method_8270]  
     ,[wwa_method_8080]  
     ,[wwa_method_8150]  
     ,[wwa_used_oil]  
     ,[wwa_oil_mixed]  
     ,[wwa_halogen_gt_1000]  
     ,[wwa_halogen_source]  
     ,[wwa_halogen_source_desc1]  
     ,[wwa_other_desc_1]  
     ,[rowguid]  
     ,NULL  
     --,[profile_id]  
     ,[facility_instruction]  
     ,FW.[emergency_phone_number]  
     ,[generator_email]  
     ,[frequency_other]  
     ,[hazmat_flag]  
     ,[hazmat_class]  
     ,[subsidiary_haz_mat_class]  
     ,[package_group]  
     ,[un_na_flag]  
     ,[un_na_number]  
     ,[erg_number]  
     ,[erg_suffix]  
     ,[dot_shipping_desc]  
     ,[reportable_quantity_flag]  
     ,[RQ_reason]  
     ,[odor_other_desc]  
     ,[consistency_debris]  
     ,[consistency_gas_aerosol]  
     ,[consistency_varies]  
     ,[pH_NA]  
     ,[ignitability_lt_90]  
     ,[ignitability_90_139]  
     ,[ignitability_140_199]  
     ,[ignitability_gte_200]  
     ,[ignitability_NA]  
     ,[air_reactive]  
     ,[temp_ctrl_org_peroxide]  
     ,[NORM]  
     ,[TENORM]  
     ,[handling_issue]  
     ,[handling_issue_desc]  
     ,[rcra_exempt_flag]  
     ,[RCRA_exempt_reason]  
     ,[cyanide_plating]  
     ,[EPA_source_code]  
     ,[EPA_form_code]  
     ,[waste_water_flag]  
     ,[debris_dimension_weight]  
     ,[info_basis_knowledge]  
     ,[info_basis_analysis]  
     ,[info_basis_msds]  
     ,[universal_recyclable_commodity]  
     ,[pcb_concentration_none]  
     ,[pcb_concentration_0_49]  
     ,[pcb_concentration_50_499]  
     ,[pcb_concentration_500]  
     ,[ddvohapgr500]  
     ,[neshap_chem_1]  
     ,[neshap_chem_2]  
     ,[neshap_standards_part]  
     ,[neshap_subpart]  
     ,[benzene_onsite_mgmt]  
     ,[benzene_onsite_mgmt_desc]  
     ,'Copy'  
     ,@source_form_id  
     ,@source_revision_id  
     ,[tech_contact_id]  
     ,[generator_contact_id]  
     ,[inv_contact_id]  
     ,@template_form_id 
     ,[date_last_profile_sync]  
     ,[manifest_dot_sp_number]  
     ,FW.[generator_country]  
     ,COALESCE(FW.gen_mail_name, (  
       SELECT TOP 1 gen_mail_name  
       FROM Generator  
       WHERE generator_id IN (generator_id)  
       ))  
     ,[gen_mail_address4]  
     ,FW.[gen_mail_country]  
     ,FW.[generator_type_ID]  
     ,ISNULL(G.NAICS_code, FW.NAICS_code) --[NAICS_code]  
     ,FW.[state_id]  
     ,[po_required]  
     ,[purchase_order]  
     ,[inv_contact_email]  
     ,[DOT_shipping_desc_additional]  
     ,[DOT_inhalation_haz_flag]  
     ,[container_type_bulk]  
     ,[container_type_totes]  
     ,[container_type_pallet]  
     ,[container_type_boxes]  
     ,[container_type_drums]  
     ,[container_type_cylinder]  
     ,[container_type_labpack]  
     ,[container_type_combination]  
     ,[container_type_combination_desc]  
     ,[container_type_other]  
     ,[container_type_other_desc]  
     ,CASE   
      WHEN (  
        odor_strength = 'N'  
        AND (  
         odor_type_ammonia = 'T'  
         OR odor_type_amines = 'T'  
         OR odor_type_mercaptans = 'T'  
         OR odor_type_sulfur = 'T'  
         OR odor_type_organic_acid = 'T'  
         OR odor_type_other = 'T'  
         )  
        )  
       THEN NULL  
      ELSE odor_strength  
      END  
     ,[odor_type_ammonia]  
     ,[odor_type_amines]  
     ,[odor_type_mercaptans]  
     ,[odor_type_sulfur]  
     ,[odor_type_organic_acid]  
     ,[odor_type_other]  
     ,[liquid_phase]  
     ,[paint_filter_solid_flag]  
     ,[incidental_liquid_flag]  
     ,[ignitability_compare_symbol]  
     ,[ignitability_compare_temperature]  
     ,[ignitability_does_not_flash]  
     ,[ignitability_flammable_solid]  
     ,[texas_waste_material_type]  
     ,[texas_state_waste_code]  
     ,[PA_residual_waste_flag]  
     ,[react_sulfide_ppm]  
     ,[react_cyanide_ppm]  
     ,[radioactive]  
     ,[reactive_other_description]  
     ,[reactive_other]  
     ,[contains_pcb]  
     ,[dioxins_or_furans]  
     ,[metal_fines_powder_paste]  
     ,[temp_control]  
     ,[thermally_unstable]  
     ,[compressed_gas]  
     ,[tires]  
     ,[organic_peroxide]  
     ,[beryllium_present]  
     ,[asbestos_flag]  
     ,[asbestos_friable_flag]  
     ,[PFAS_Flag]  
     ,[hazardous_secondary_material]  
     ,[hazardous_secondary_material_cert]  
     ,[pharma_waste_subject_to_prescription]  
     ,[waste_treated_after_generation]  
     ,[waste_treated_after_generation_desc]  
     ,[debris_separated]  
     ,[debris_not_mixed_or_diluted]  
     ,[origin_refinery]  
     ,[specific_technology_requested]  
     ,[requested_technology]  
     ,[other_restrictions_requested]  
     ,[thermal_process_flag]  
     ,[DOT_sp_permit_text]  
     ,[BTU_lt_gt_5000]  
     ,[ammonia_flag]  
     ,[pcb_concentration_0_9]  
     ,[pcb_concentration_10_49]  
     ,[pcb_regulated_for_disposal_under_TSCA]  
     ,[pcb_article_for_TSCA_landfill]  
     ,@display_status_uid  
     ,section_F_none_apply_flag  
     ,DOT_sp_permit_flag  
     ,RQ_threshold  
     ,RCRA_waste_code_flag  
     ,routing_facility  
     ,signed_on_behalf_of  
     ,approval_code  
    FROM FormWCR FW  
    LEFT JOIN Generator G ON FW.[generator_id] = G.[generator_id]  
    WHERE Form_id = @form_id  
     AND revision_id = @revision_id  
   END TRY  
  
   BEGIN CATCH  
    SELECT Error_message()  
   END CATCH  
  
   -- Track form history status  
   EXEC [sp_FormWCRStatusAudit_Insert] @new_form_id  
    ,@revisonid  
    ,@display_status_uid  
    ,@web_user_id  
  
   --INSERT INTO ContactCORFormWCRBucket (contact_id,form_id,revision_id) Values(  
   -- (SELECT TOP 1 contact_ID FROM Contact WHERE web_userid = @web_user_id   
   --  AND web_access_flag = 'T' AND contact_status = 'A'),  
   -- @new_form_id,  
   -- @revision_id)  
   --- Benzene  
   BEGIN TRY  
    IF (  
      EXISTS (  
       SELECT 1  
       FROM FormBenzene WITH (NOLOCK)  
       WHERE wcr_id = @form_id  
        AND wcr_rev_id = @revision_id  
       )  
      )  
    BEGIN  
     DECLARE @new_Benzene_form_id INT  
      ,@new_Benzene_Rev_id INT = 1  
  
     EXEC @new_Benzene_form_id = sp_sequence_next 'form.form_id'  
  
     INSERT INTO FormBenzene (  
      form_id  
      ,revision_id  
      ,wcr_id  
      ,wcr_rev_id  
      ,locked  
      ,type_of_facility  
      ,tab_lt_1_megagram  
      ,tab_gte_1_and_lt_10_megagram  
      ,tab_gte_10_megagram  
      ,benzene_onsite_mgmt  
      ,flow_weighted_annual_average_benzene  
      ,avg_h20_gr_10  
      ,is_process_unit_turnaround  
      ,benzene_range_from  
      ,benzene_range_to  
      ,classified_as_process_wastewater_stream  
      ,classified_as_landfill_leachate  
      ,classified_as_product_tank_drawdown  
      ,originating_generator_name  
      ,originating_generator_epa_id  
      ,created_by  
      ,date_created  
      ,modified_by  
      ,date_modified  
      )  
     SELECT @new_Benzene_form_id  
      ,@new_Benzene_Rev_id  
      ,@new_form_id  
      ,@revisonid  
      ,  
      --wcr_id,  
      --wcr_rev_id,  
      locked  
      ,type_of_facility  
      ,tab_lt_1_megagram  
      ,tab_gte_1_and_lt_10_megagram  
      ,tab_gte_10_megagram  
      ,benzene_onsite_mgmt  
      ,flow_weighted_annual_average_benzene  
      ,avg_h20_gr_10  
      ,is_process_unit_turnaround  
      ,benzene_range_from  
      ,benzene_range_to  
      ,classified_as_process_wastewater_stream  
      ,classified_as_landfill_leachate  
      ,classified_as_product_tank_drawdown  
      ,originating_generator_name  
      ,originating_generator_epa_id  
      ,@web_user_id  
      ,GETDATE()  
      ,@modified_by_web_user_id  
      ,GETDATE()  
     FROM FormBenzene  
     WHERE wcr_id = @form_id  
      AND wcr_rev_id = @revision_id  
    END  
   END TRY  
  
   BEGIN CATCH  
    PRINT 'bz catch'  
  
    SELECT error_message()  
   END CATCH  
  
   --- benzene end  
   -- CERTIFICATION  
   IF (  
     EXISTS (  
      SELECT 1  
      FROM FormVSQGCESQG WITH (NOLOCK)  
      WHERE wcr_id = @form_id  
       AND wcr_rev_id = @revision_id  
      )  
     )  
   BEGIN  
    DECLARE @new_VSQGCESQG_form_id INT  
     ,@new_VSQGCESQG_Rev_id INT = 1  
  
    EXEC @new_VSQGCESQG_form_id = sp_sequence_next 'form.form_id'  
  
    INSERT INTO FormVSQGCESQG (  
     form_id  
     ,revision_id  
     ,wcr_id  
     ,wcr_rev_id  
     ,locked  
     ,vsqg_cesqg_accept_flag  
     ,created_by  
     ,date_created  
     ,date_modified  
     ,modified_by  
     )  
    SELECT @new_VSQGCESQG_form_id  
     ,@new_VSQGCESQG_Rev_id  
     ,@new_form_id  
     ,@revisonid  
     ,  
     --wcr_id,  
     --wcr_rev_id,  
     locked  
     ,vsqg_cesqg_accept_flag  
     ,@web_user_id  
     ,GETDATE()  
     ,GETDATE()  
     ,@modified_by_web_user_id  
    FROM FormVSQGCESQG  
    WHERE wcr_id = @form_id  
     AND wcr_rev_id = @revision_id  
   END  
  
   -- CERTIFICATION END  
   -- CYLINDER  
   BEGIN TRY  
    IF (  
      EXISTS (  
       SELECT 1  
       FROM FormCGC WITH (NOLOCK)  
       WHERE form_id = @form_id  
        AND revision_id = @revision_id  
       )  
      )  
    BEGIN  
     INSERT INTO FormCGC (  
      form_id  
      ,revision_id  
      ,cylinder_quantity  
      ,CGA_number  
      ,original_label_visible_flag  
      ,manufacturer  
      ,markings_warnings_comments  
      ,DOT_shippable_flag  
      ,DOT_not_shippable_reason  
      ,poisonous_inhalation_flag  
      ,hazard_zone  
      ,DOT_ICC_number  
      ,cylinder_type_id  
      ,heaviest_gross_weight  
      ,heaviest_gross_weight_unit  
      ,external_condition  
      ,cylinder_pressure  
      ,pressure_relief_device  
      ,protective_cover_flag  
      ,workable_valve_flag  
      ,threads_impaired_flag  
      ,valve_condition  
      ,corrosion_color  
      ,created_by  
      ,date_created  
      ,modified_by  
      ,date_modified  
      )  
     SELECT @new_form_id  
      ,@revisonid  
      ,cylinder_quantity  
      ,CGA_number  
      ,original_label_visible_flag  
      ,manufacturer  
      ,markings_warnings_comments  
      ,DOT_shippable_flag  
      ,DOT_not_shippable_reason  
      ,poisonous_inhalation_flag  
      ,hazard_zone  
      ,DOT_ICC_number  
      ,cylinder_type_id  
      ,heaviest_gross_weight  
      ,heaviest_gross_weight_unit  
      ,external_condition  
      ,cylinder_pressure  
      ,pressure_relief_device  
      ,protective_cover_flag  
      ,workable_valve_flag  
      ,threads_impaired_flag  
      ,valve_condition  
      ,corrosion_color  
      ,@web_user_id  
      ,GETDATE()  
      ,@modified_by_web_user_id  
      ,GETDATE()  
     FROM FormCGC  
     WHERE form_id = @form_id  
      AND revision_id = @revision_id  
    END  
   END TRY  
  
   BEGIN CATCH  
    PRINT 'cylinder catch'  
  
    SELECT error_message()  
   END CATCH  
  
   -- CYLINDER END  
   -- Debris  
   BEGIN TRY  
    IF (  
      EXISTS (  
       SELECT 1  
       FROM FormDebris WITH (NOLOCK)  
       WHERE wcr_id = @form_id  
        AND wcr_rev_id = @revision_id  
       )  
      )  
    BEGIN  
     DECLARE @new_Debris_form_id INT  
      ,@new_Debris_Rev_id INT = 1  
  
     EXEC @new_Debris_form_id = sp_sequence_next 'form.form_id'  
  
     INSERT INTO FormDebris (  
      form_id  
      ,revision_id  
      ,wcr_id  
      ,wcr_rev_id  
      ,locked  
      ,debris_certification_flag  
      ,created_by  
      ,date_created  
      ,modified_by  
      ,date_modified  
      )  
     SELECT @new_Debris_form_id  
      ,@new_Debris_Rev_id  
      ,@new_form_id  
      ,@revisonid  
      ,  
      --wcr_id,  
      --wcr_rev_id,  
      locked  
      ,debris_certification_flag  
      ,@web_user_id  
      ,GETDATE()  
      ,@modified_by_web_user_id  
      ,GETDATE()  
     FROM FormDebris  
     WHERE wcr_id = @form_id  
      AND wcr_rev_id = @revision_id  
    END  
   END TRY  
  
   BEGIN CATCH  
    PRINT 'deb catch'  
  
    SELECT error_message()  
   END CATCH  
  
   -- IllinoisDisposal  
   BEGIN TRY  
    IF (  
      EXISTS (  
       SELECT 1 
       FROM FormIllinoisDisposal WITH (NOLOCK)  
       WHERE wcr_id = @form_id  
        AND wcr_rev_id = @revision_id  
       )  
      )  
    BEGIN  
     DECLARE @new_ID_form_id INT  
      ,@new_ID_Rev_id INT = 1  
  
     EXEC @new_ID_form_id = sp_sequence_next 'form.form_id'  
  
     INSERT INTO FormIllinoisDisposal (  
      form_id  
      ,revision_id  
      ,wcr_id  
      ,wcr_rev_id  
      ,locked  
      ,none_apply_flag  
      ,incecticides_flag  
      ,pesticides_flag  
      ,herbicides_flag  
      ,household_waste_flag  
      ,carcinogen_flag  
      ,other_flag  
      ,other_specify  
      ,sulfide_10_250_flag  
      ,universal_waste_flag  
      ,characteristic_sludge_flag  
      ,virgin_unused_product_flag  
      ,spent_material_flag  
      ,cyanide_plating_on_site_flag  
      ,substitute_commercial_product_flag  
      ,by_product_flag  
      ,rx_lime_flammable_gas_flag  
      ,pollution_control_waste_IL_flag  
      ,industrial_process_waste_IL_flag  
      ,phenol_gt_1000_flag  
      ,generator_state_id  
      ,d004_above_PQL  
      ,d005_above_PQL  
      ,d006_above_PQL  
      ,d007_above_PQL  
      ,d008_above_PQL  
      ,d009_above_PQL  
      ,d010_above_PQL  
      ,d011_above_PQL  
      ,d012_above_PQL  
      ,d013_above_PQL  
      ,d014_above_PQL  
      ,d015_above_PQL  
      ,d016_above_PQL  
      ,d017_above_PQL  
      ,d018_above_PQL  
      ,d019_above_PQL  
      ,d020_above_PQL  
      ,d021_above_PQL  
      ,d022_above_PQL  
      ,d023_above_PQL  
      ,d024_above_PQL  
      ,d025_above_PQL  
      ,d026_above_PQL  
      ,d027_above_PQL  
      ,d028_above_PQL  
      ,d029_above_PQL  
      ,d030_above_PQL  
      ,d031_above_PQL  
      ,d032_above_PQL  
      ,d033_above_PQL  
      ,d034_above_PQL  
      ,d035_above_PQL  
      ,d036_above_PQL  
      ,d037_above_PQL  
      ,d038_above_PQL  
      ,d039_above_PQL  
      ,d040_above_PQL  
      ,d041_above_PQL  
      ,d042_above_PQL  
      ,d043_above_PQL  
      ,created_by  
      ,date_created  
      ,date_modified  
      ,modified_by        ,generator_certification_flag  
      ,certify_flag  
      )  
     SELECT @new_ID_form_id  
      ,@new_ID_Rev_id  
      ,@new_form_id  
      ,@revisonid  
      ,  
      --wcr_id,  
      --wcr_rev_id,  
      locked  
      ,none_apply_flag  
      ,incecticides_flag  
      ,pesticides_flag  
      ,herbicides_flag  
      ,household_waste_flag  
      ,carcinogen_flag  
      ,other_flag  
      ,other_specify  
      ,sulfide_10_250_flag  
      ,universal_waste_flag  
      ,characteristic_sludge_flag  
      ,virgin_unused_product_flag  
      ,spent_material_flag  
      ,cyanide_plating_on_site_flag  
      ,substitute_commercial_product_flag  
      ,by_product_flag  
      ,rx_lime_flammable_gas_flag  
      ,pollution_control_waste_IL_flag  
      ,industrial_process_waste_IL_flag  
      ,phenol_gt_1000_flag  
      ,generator_state_id  
      ,d004_above_PQL  
      ,d005_above_PQL  
      ,d006_above_PQL  
      ,d007_above_PQL  
      ,d008_above_PQL  
      ,d009_above_PQL  
      ,d010_above_PQL  
      ,d011_above_PQL  
      ,d012_above_PQL  
      ,d013_above_PQL  
      ,d014_above_PQL  
      ,d015_above_PQL  
      ,d016_above_PQL  
      ,d017_above_PQL  
      ,d018_above_PQL  
      ,d019_above_PQL  
      ,d020_above_PQL  
      ,d021_above_PQL  
      ,d022_above_PQL  
      ,d023_above_PQL  
      ,d024_above_PQL  
      ,d025_above_PQL  
      ,d026_above_PQL  
      ,d027_above_PQL  
      ,d028_above_PQL  
      ,d029_above_PQL  
      ,d030_above_PQL  
      ,d031_above_PQL  
      ,d032_above_PQL  
      ,d033_above_PQL  
      ,d034_above_PQL  
      ,d035_above_PQL  
      ,d036_above_PQL  
      ,d037_above_PQL  
      ,d038_above_PQL  
      ,d039_above_PQL  
      ,d040_above_PQL  
      ,d041_above_PQL  
      ,d042_above_PQL  
      ,d043_above_PQL  
      ,@web_user_id  
      ,getdate()  
      ,getdate()  
      ,@modified_by_web_user_id  
      ,generator_certification_flag  
      ,certify_flag  
     FROM FormIllinoisDisposal  
     WHERE wcr_id = @form_id  
      AND wcr_rev_id = @revision_id  
    END  
   END TRY  
  
   BEGIN CATCH  
    PRINT 'ID catch'  
  
    SELECT error_message()  
   END CATCH  
  
   -- IllinoisDisposal END  
   -- LDR  
   BEGIN TRY  
    IF (  
      EXISTS (  
       SELECT 1  
       FROM FormLDR WITH (NOLOCK)  
       WHERE wcr_id = @form_id  
        AND wcr_rev_id = @revision_id  
       )  
      )  
    BEGIN  
     DECLARE @new_LDR_form_id INT  
      ,@new_LDR_Rev_id INT = 1  
  
     EXEC @new_LDR_form_id = sp_sequence_next 'form.form_id'  
  
     INSERT INTO FormLDR (  
      form_id  
      ,revision_id  
      ,wcr_id  
      ,wcr_rev_id  
      ,generator_id  
      ,generator_name  
      ,generator_epa_id  
      ,manifest_doc_no  
      ,ldr_notification_frequency  
      ,waste_managed_id  
      ,rowguid  
      ,STATUS  
      ,locked  
      ,date_created  
      ,date_modified  
      ,created_by  
      ,modified_by  
      )  
     SELECT @new_LDR_form_id  
      ,@new_LDR_Rev_id  
      ,@new_form_id  
      ,@revisonid  
      ,generator_id  
      ,generator_name  
      ,generator_epa_id  
      ,manifest_doc_no  
      ,ldr_notification_frequency  
      ,waste_managed_id  
      ,rowguid  
      ,STATUS  
      ,locked  
      ,GETDATE()  
      ,GETDATE()  
      ,@web_user_id  
      ,@modified_by_web_user_id  
     FROM FormLDR  
     WHERE wcr_id = @form_id  
      AND wcr_rev_id = @revision_id  
    END  
   END TRY  
  
   BEGIN CATCH  
    PRINT 'ldr catch'  
  
    SELECT error_message()  
   END CATCH  
  
   IF (  
     EXISTS (  
      SELECT 1  
      FROM FormLDRDetail WITH (NOLOCK)  
      WHERE form_id = @form_id  
       AND revision_id = @revision_id  
      )  
     )  
   BEGIN  
    INSERT INTO FormLDRDetail (  
     form_id  
     ,revision_id  
     ,form_version_id  
     ,page_number  
     ,manifest_line_item  
     ,ww_or_nww  
     ,subcategory  
     ,manage_id  
     ,approval_code  
     ,approval_key  
     ,company_id  
     ,profit_ctr_id  
     ,profile_id  
     ,constituents_requiring_treatment_flag  
     )  
    SELECT @new_form_id  
     ,@revisonid  
     ,form_version_id  
     ,page_number  
     ,manifest_line_item  
     ,ww_or_nww  
     ,subcategory  
     ,manage_id  
     ,approval_code  
     ,approval_key  
     ,company_id  
     ,profit_ctr_id  
     ,NULL  
     ,constituents_requiring_treatment_flag  
    FROM FormLDRDetail  
    WHERE form_id = @form_id  
     AND revision_id = @revision_id  
   END  
  
   IF (  
     EXISTS (  
      SELECT 1  
      FROM FormXWasteCode WITH (NOLOCK)  
      WHERE form_id = @form_id  
       AND revision_id = @revision_id  
      )  
     )  
   BEGIN  
    INSERT INTO FormXWasteCode (  
     form_id  
     ,revision_id  
     ,waste_code_uid  
     ,waste_code  
     ,specifier  
     )  
    SELECT @new_form_id  
     ,@revisonid  
     ,waste_code_uid  
     ,waste_code  
     ,specifier  
    FROM FormXWasteCode  
    WHERE form_id = @form_id  
     AND revision_id = @revision_id  
     --AND ((@state_waste_code_flag <> 'T' AND specifier = 'state')   
     -- OR (specifier <> 'state'))  
   END  
  
   IF (  
     EXISTS (  
      SELECT 1  
      FROM FormLDRSubcategory WITH (NOLOCK)  
      WHERE form_id = @form_id  
       AND revision_id = @revision_id  
      )  
     )  
   BEGIN  
    INSERT INTO FormLDRSubcategory (  
     form_id  
     ,revision_id  
     ,page_number  
     ,manifest_line_item  
     ,ldr_subcategory_id  
     )  
    SELECT @new_form_id  
     ,@revisonid  
     ,page_number  
     ,manifest_line_item  
     ,ldr_subcategory_id  
    FROM FormLDRSubcategory  
    WHERE form_id = @form_id  
     AND revision_id = @revision_id  
   END  
  
   IF (  
     EXISTS (  
      SELECT 1  
      FROM FormXConstituent WITH (NOLOCK)  
      WHERE form_id = @form_id  
       AND revision_id = @revision_id  
      )  
     )  
   BEGIN  
    INSERT INTO FormXConstituent (  
     form_id  
     ,revision_id  
     ,page_number  
     ,line_item  
     ,const_id  
     ,const_desc  
     ,min_concentration  
     ,concentration  
     ,unit  
     ,uhc  
     ,specifier  
     ,TCLP_or_totals  
     ,typical_concentration  
     ,max_concentration  
     ,exceeds_LDR  
     ,requiring_treatment_flag  
     ,cor_lock_flag  
     )  
    SELECT @new_form_id  
     ,@revisonid  
     ,page_number  
     ,line_item  
     ,const_id  
     ,const_desc  
     ,min_concentration  
     ,concentration  
     ,unit  
     ,CASE   
      WHEN uhc = 'T'  
       THEN 'T'  
      ELSE 'F'  
      END  
     ,specifier  
     ,TCLP_or_totals  
     ,typical_concentration  
     ,max_concentration  
     ,CASE   
      WHEN exceeds_LDR = 'T'  
       THEN 'T'  
      ELSE 'F'  
      END  
     ,requiring_treatment_flag  
     ,NULL  
    FROM FormXConstituent  
    WHERE form_id = @form_id  
     AND revision_id = @revision_id  
   END  
  
   -- LDR END  
   -- PHARMA  
   IF (  
     EXISTS (  
      SELECT 1  
      FROM FormPharmaceutical  
      WHERE wcr_id = @form_id  
       AND wcr_rev_id = @revision_id  
      )  
     )  
   BEGIN  
    DECLARE @new_PHARMA_form_id INT  
     ,@new_PHARMA_Rev_id INT = 1  
  
    EXEC @new_PHARMA_form_id = sp_sequence_next 'form.form_id'  
  
    INSERT INTO FormPharmaceutical (  
     form_id  
     ,revision_id  
     ,wcr_id  
     ,wcr_rev_id  
     ,locked  
     ,pharm_certification_flag  
     ,created_by  
     ,date_created  
     ,date_modified  
     ,modified_by  
     )  
    SELECT @new_PHARMA_form_id  
     ,@new_PHARMA_Rev_id  
     ,@new_form_id  
     ,@revisonid  
     ,  
     --wcr_id,  
     --wcr_rev_id,  
     locked  
     ,pharm_certification_flag  
     ,@web_user_id  
     ,GETDATE()  
     ,GETDATE()  
     ,@modified_by_web_user_id  
    FROM FormPharmaceutical  
    WHERE wcr_id = @form_id  
     AND wcr_rev_id = @revision_id  
   END  
  
   -- PHARMA END  
   -- Radioactive  
   IF (  
     EXISTS (  
      SELECT 1 
      FROM FormRadioactive WITH (NOLOCK)  
      WHERE wcr_id = @form_id  
       AND wcr_rev_id = @revision_id  
      )  
     )  
   BEGIN  
    DECLARE @new_Radioactive_form_id INT  
     ,@new_Radioactive_Rev_id INT = 1  
  
    EXEC @new_Radioactive_form_id = sp_sequence_next 'form.form_id'  
  
    INSERT INTO FormRadioactive (  
     form_id  
     ,revision_id  
     ,wcr_id  
     ,wcr_rev_id  
     ,locked  
     ,uranium_thorium_flag  
     ,uranium_source_material  
     ,radium_226_flag  
     ,radium_228_flag  
     ,lead_210_flag  
     ,potassium_40_flag  
     ,exempt_byproduct_material_flag  
     ,special_nuclear_material_flag  
     ,accelerator_flag  
     ,generated_in_particle_accelerator_flag  
     ,approved_for_disposal_flag  
     ,approved_by_nrc_flag  
     ,approved_for_alternate_disposal_flag  
     ,nrc_exempted_flag  
     ,released_from_radiological_control_flag  
     ,DOD_non_licensed_disposal_flag  
     ,byproduct_sum_of_all_isotopes  
     ,source_sof_calculations  
     ,special_nuclear_sum_of_all_isotopes  
     ,date_created  
     ,date_modified  
     ,created_by  
     ,modified_by  
     ,uranium_concentration  
     ,radium_226_concentration  
     ,radium_228_concentration  
     ,lead_210_concentration  
     ,potassium_40_concentration  
     ,additional_inventory_flag  
     ,specifically_exempted_flag  
     ,USEI_WAC_table_C1_flag  
     ,USEI_WAC_table_C2_flag  
     ,USEI_WAC_table_C3_flag  
     ,USEI_WAC_table_C4a_flag  
     ,USEI_WAC_table_C4b_flag  
     ,USEI_WAC_table_C4c_flag  
     ,waste_type  
     )  
    SELECT @new_Radioactive_form_id  
     ,@new_Radioactive_Rev_id  
     ,@new_form_id  
     ,@revisonid  
     ,  
     --wcr_id,  
     --wcr_rev_id,  
     locked  
     ,uranium_thorium_flag  
     ,uranium_source_material  
     ,radium_226_flag  
     ,radium_228_flag  
     ,lead_210_flag  
     ,potassium_40_flag  
     ,exempt_byproduct_material_flag  
     ,special_nuclear_material_flag  
     ,accelerator_flag  
     ,generated_in_particle_accelerator_flag  
     ,approved_for_disposal_flag  
     ,approved_by_nrc_flag  
     ,approved_for_alternate_disposal_flag  
     ,nrc_exempted_flag  
     ,released_from_radiological_control_flag  
     ,DOD_non_licensed_disposal_flag  
     ,byproduct_sum_of_all_isotopes  
     ,source_sof_calculations  
     ,special_nuclear_sum_of_all_isotopes  
     ,GETDATE()  
     ,GETDATE()  
     ,@web_user_id  
     ,@modified_by_web_user_id  
     ,uranium_concentration  
     ,radium_226_concentration  
     ,radium_228_concentration  
     ,lead_210_concentration  
     ,potassium_40_concentration  
     ,additional_inventory_flag  
     ,specifically_exempted_flag  
     ,USEI_WAC_table_C1_flag  
     ,USEI_WAC_table_C2_flag  
     ,USEI_WAC_table_C3_flag  
     ,USEI_WAC_table_C4a_flag  
     ,USEI_WAC_table_C4b_flag  
     ,USEI_WAC_table_C4c_flag  
     ,waste_type  
    FROM FormRadioactive  
    WHERE wcr_id = @form_id  
     AND wcr_rev_id = @revision_id  
  
    --RadioActiveExempt  
    SELECT TOP 1 @radioactiveUSEI_form_id = [form_id]  
     ,@radioactiveUSEI_revision_id = [revision_id]  
    FROM FormRadioactive WITH (NOLOCK)  
    WHERE wcr_id = @form_id  
     AND wcr_rev_id = @revision_id  
  
    SELECT TOP 1 @radioactiveUSEI_new_form_id = [form_id]  
    FROM FormRadioactive WITH (NOLOCK)  
    WHERE wcr_id = @new_form_id  
     AND wcr_rev_id = @revision_id  
  
    IF (  
      @radioactiveUSEI_form_id IS NOT NULL  
      AND @radioactiveUSEI_form_id <> ''  
      AND @radioactiveUSEI_revision_id IS NOT NULL  
      AND @radioactiveUSEI_revision_id <> ''  
      AND @radioactiveUSEI_new_form_id IS NOT NULL  
      AND @radioactiveUSEI_new_form_id <> ''  
      )  
    BEGIN  
     IF (  
       EXISTS (  
        SELECT 1  
        FROM FormRadioactiveExempt WITH (NOLOCK)  
        WHERE form_id = @radioactiveUSEI_form_id  
         AND revision_id = @radioactiveUSEI_revision_id  
        )  
       )  
     BEGIN  
      INSERT INTO FormRadioactiveExempt (  
       form_id  
       ,revision_id  
       ,line_id  
       ,item_name  
       ,total_number_in_shipment  
       ,radionuclide_contained  
       ,activity  
       ,disposal_site_tsdf_code  
       ,  
       --disposal_site_tsdf_id,  
       cited_regulatory_exemption  
       ,created_by  
       ,date_created  
       ,modified_by  
       ,date_modified  
       )  
      SELECT @radioactiveUSEI_new_form_id  
       ,@revisonid  
       ,line_id  
       ,item_name  
       ,total_number_in_shipment  
       ,radionuclide_contained  
       ,activity  
       ,disposal_site_tsdf_code  
       ,  
       --disposal_site_tsdf_id,  
       cited_regulatory_exemption  
       ,@web_user_id  
       ,GETDATE()  
       ,@modified_by_web_user_id  
       ,GETDATE()  
      FROM FormRadioactiveExempt  
      WHERE form_id = @radioactiveUSEI_form_id  
       AND revision_id = @radioactiveUSEI_revision_id  
     END  
    END  
  
    IF (  
      @radioactiveUSEI_form_id IS NOT NULL  
      AND @radioactiveUSEI_form_id <> ''  
      AND @radioactiveUSEI_revision_id IS NOT NULL  
      AND @radioactiveUSEI_revision_id <> ''  
      AND @radioactiveUSEI_new_form_id IS NOT NULL  
      AND @radioactiveUSEI_new_form_id <> ''  
      )  
    BEGIN  
     -- RadioactiveUSEI  
     IF (  
       EXISTS (  
        SELECT 1  
        FROM FormRadioactiveUSEI WITH (NOLOCK)  
        WHERE form_id = @radioactiveUSEI_form_id  
         AND revision_id = @radioactiveUSEI_revision_id  
        )  
       )  
     BEGIN  
      INSERT INTO FormRadioactiveUSEI (  
       form_id  
       ,revision_id  
       ,line_id  
       ,radionuclide  
       ,concentration  
	   ,const_id
       ,date_created  
       ,date_modified  
       ,created_by  
       ,modified_by  
       )  
      SELECT @radioactiveUSEI_new_form_id  
       ,@revisonid  
       ,line_id  
       ,radionuclide  
       ,concentration  
	   ,const_id
       ,GETDATE()  
       ,GETDATE()  
       ,@web_user_id  
       ,@web_user_id  
      FROM FormRadioactiveUSEI  
      WHERE form_id = @radioactiveUSEI_form_id  
       AND revision_id = @radioactiveUSEI_revision_id  
     END  
    END  
      -- Radioactive End  
   END  
  
   -- SECTION C  
   IF (  
     EXISTS (  
      SELECT 1  
      FROM FormXWCRContainerSize  
      WHERE form_id = @form_id  
       AND revision_id = @revision_id  
      )  
     )  
   BEGIN  
    SELECT row_number() OVER (  
      PARTITION BY bill_unit_code ORDER BY bill_unit_code  
      ) AS _row  
     ,form_id = @new_form_id  
     ,revision_id = @revisonid  
     ,bill_unit_code = bill_unit_code  
     ,is_bill_unit_table_lookup = is_bill_unit_table_lookup  
     ,date_created = GETDATE()  
     ,date_modified = GETDATE()  
     ,created_by = created_by  
     ,modified_by = modified_by  
    INTO #tmpwcrcontainersize  
    FROM FormXWCRContainerSize  
    WHERE form_id = @form_id  
     AND revision_id = @revision_id  
  
    INSERT INTO FormXWCRContainerSize (  
     form_id  
     ,revision_id  
     ,bill_unit_code  
     ,is_bill_unit_table_lookup  
     ,date_created  
     ,date_modified  
     ,created_by  
     ,modified_by  
     )  
    SELECT form_id  
     ,revision_id  
     ,bill_unit_code  
     ,is_bill_unit_table_lookup  
     ,date_created  
     ,date_modified  
     ,created_by  
     ,modified_by  
    FROM #tmpwcrcontainersize  
    WHERE _row = 1  
   END  
  
   IF (  
     EXISTS (  
      SELECT 1  
      FROM FormXUnit  
      WHERE form_id = @form_id  
       AND revision_id = @revision_id  
      )  
     )  
   BEGIN  
    INSERT INTO FormXUnit (  
     form_id  
     ,form_type  
     ,revision_id  
     ,bill_unit_code  
     ,quantity  
     )  
    SELECT @new_form_id  
     ,form_type  
     ,@revisonid  
     ,bill_unit_code  
     ,quantity  
    FROM FormXUnit  
    WHERE form_id = @form_id  
     AND revision_id = @revision_id  
   END  
  
   ---- SECTION C END  
   -- SECTION D  
   --- Physical_Description  
   IF (  
     EXISTS (  
      SELECT form_id  
      FROM FormXWCRComposition  
      WHERE form_id = @form_id  
       AND revision_id = @revision_id  
      )  
     )  
   BEGIN  
    INSERT INTO FormXWCRComposition (  
     form_id  
     ,revision_id  
     ,comp_description  
     ,comp_from_pct  
     ,comp_to_pct  
     ,rowguid  
     ,unit  
     ,sequence_id  
     ,comp_typical_pct  
     )  
    SELECT @new_form_id  
     ,@revisonid  
     ,comp_description  
     ,comp_from_pct  
     ,comp_to_pct  
     ,rowguid  
     ,unit  
     ,isnull(sequence_id, row_number() OVER (  
       ORDER BY (  
         SELECT NULL  
         ) ASC  
       ))  
     ,comp_typical_pct  
    FROM FormXWCRComposition  
    WHERE form_id = @form_id  
     AND revision_id = @revision_id  
   END  
  
   -- SECTION D END  
   -- SECTION H  
   IF (  
     EXISTS (  
      SELECT form_id  
      FROM FormXUSEFacility  
      WHERE form_id = @form_id  
       AND revision_id = @revision_id  
      )  
     )  
   BEGIN  
    INSERT INTO FormXUSEFacility (  
     form_id  
     ,revision_id  
     ,company_id  
     ,profit_ctr_id  
     ,date_created  
     ,date_modified  
     ,created_by  
     ,modified_by  
     )  
    SELECT @new_form_id  
     ,@revisonid  
     ,company_id  
     ,profit_ctr_id  
     ,GETDATE()  
     ,GETDATE()  
     ,created_by  
     ,modified_by  
    FROM FormXUSEFacility  
    WHERE form_id = @form_id  
     AND revision_id = @revision_id  
   END  
  
   -- SECTION H END  
   -- THERMAL  
   IF (  
     EXISTS (  
      SELECT 1  
      FROM FormThermal  
      WHERE wcr_id = @form_id  
       AND wcr_rev_id = @revision_id  
      )  
     )  
   BEGIN  
    DECLARE @new_THERMAL_form_id INT  
     ,@new_THERMAL_Rev_id INT = 1  
  
    EXEC @new_THERMAL_form_id = sp_sequence_next 'form.form_id'  
  
    INSERT INTO FormThermal (  
     form_id  
     ,revision_id  
     ,wcr_id  
     ,wcr_rev_id  
     ,locked  
     ,originating_generator_name  
     ,originating_generator_epa_id  
     ,same_as_above  
     ,oil_bearing_from_refining_flag  
     ,rcra_excluded_HSM_flag  
     ,oil_constituents_are_fuel_flag  
     ,petroleum_refining_F037_flag  
     ,petroleum_refining_F038_flag  
     ,petroleum_refining_K048_flag  
     ,petroleum_refining_K049_flag  
     ,petroleum_refining_K050_flag  
     ,petroleum_refining_K051_flag  
     ,petroleum_refining_K052_flag  
     ,petroleum_refining_K169_flag  
     ,petroleum_refining_K170_flag  
     ,petroleum_refining_K171_flag  
     ,petroleum_refining_K172_flag  
     ,petroleum_refining_no_waste_code_flag  
     ,gen_process  
     ,composition_water_percent  
     ,composition_solids_percent  
     ,composition_organics_oil_TPH_percent  
     ,heating_value_btu_lb  
     ,percent_of_ASH  
     ,specific_halogens_ppm  
     ,specific_mercury_ppm  
     ,specific_SVM_ppm  
     ,specific_LVM_ppm  
     ,specific_organic_chlorine_from_VOCs_ppm  
     ,specific_sulfides_ppm  
     ,non_friable_debris_gt_2_inch_flag  
     ,non_friable_debris_gt_2_inch_ppm  
     ,self_heating_properties_flag  
     ,bitumen_asphalt_tar_flag  
     ,bitumen_asphalt_tar_ppm  
     ,centrifuge_prior_to_shipment_flag  
     ,fuel_oxygenates_flag  
     ,oxygenates_MTBE_flag  
     ,oxygenates_ethanol_flag  
     ,oxygenates_other_flag  
     ,oxygenates_ppm  
     ,surfactants_flag  
     ,created_by  
     ,date_created  
     ,date_modified  
     ,modified_by  
     )  
    SELECT @new_THERMAL_form_id  
     ,@new_THERMAL_Rev_id  
     ,@new_form_id  
     ,@revisonid  
     ,  
     --wcr_id,  
     --wcr_rev_id,  
     locked  
     ,originating_generator_name  
     ,originating_generator_epa_id  
     ,same_as_above  
     ,oil_bearing_from_refining_flag  
     ,rcra_excluded_HSM_flag  
     ,oil_constituents_are_fuel_flag  
     ,petroleum_refining_F037_flag  
     ,petroleum_refining_F038_flag  
     ,petroleum_refining_K048_flag  
     ,petroleum_refining_K049_flag  
     ,petroleum_refining_K050_flag  
     ,petroleum_refining_K051_flag  
     ,petroleum_refining_K052_flag  
     ,petroleum_refining_K169_flag  
     ,petroleum_refining_K170_flag  
     ,petroleum_refining_K171_flag  
     ,petroleum_refining_K172_flag  
     ,petroleum_refining_no_waste_code_flag  
     ,gen_process  
     ,composition_water_percent  
     ,composition_solids_percent  
     ,composition_organics_oil_TPH_percent  
     ,heating_value_btu_lb  
     ,percent_of_ASH  
     ,specific_halogens_ppm  
     ,specific_mercury_ppm  
     ,specific_SVM_ppm  
     ,specific_LVM_ppm  
     ,specific_organic_chlorine_from_VOCs_ppm  
     ,specific_sulfides_ppm  
     ,non_friable_debris_gt_2_inch_flag  
     ,non_friable_debris_gt_2_inch_ppm  
     ,self_heating_properties_flag  
     ,bitumen_asphalt_tar_flag  
     ,bitumen_asphalt_tar_ppm  
     ,centrifuge_prior_to_shipment_flag  
     ,fuel_oxygenates_flag  
     ,oxygenates_MTBE_flag  
     ,oxygenates_ethanol_flag  
     ,oxygenates_other_flag  
     ,oxygenates_ppm  
     ,surfactants_flag  
     ,@web_user_id  
     ,GETDATE()  
     ,GETDATE()  
     ,@modified_by_web_user_id  
    FROM FormThermal  
    WHERE wcr_id = @form_id  
     AND wcr_rev_id = @revision_id  
   END  
  
   -- THERMAL END  
   -- WASTE IMPORT  
   BEGIN TRY  
    IF (  
      EXISTS (  
       SELECT 1  
       FROM FormWasteImport  
       WHERE wcr_id = @form_id  
        AND wcr_rev_id = @revision_id  
       )  
      )  
    BEGIN  
     DECLARE @new_WI_form_id INT  
      ,@new_WI_Rev_id INT = 1  
  
     EXEC @new_WI_form_id = sp_sequence_next 'form.form_id'  
  
     INSERT INTO FormWasteImport (  
      form_id  
      ,revision_id  
      ,wcr_id  
      ,wcr_rev_id  
      ,locked  
      ,foreign_exporter_name  
      ,foreign_exporter_address  
      ,foreign_exporter_city  
      ,foreign_exporter_province_territory  
      ,foreign_exporter_mail_code  
      ,foreign_exporter_country  
      ,foreign_exporter_contact_name  
      ,foreign_exporter_phone  
      ,foreign_exporter_fax  
      ,foreign_exporter_email  
      ,epa_notice_id  
      ,epa_consent_number  
      ,effective_date  
      ,expiration_date  
      ,approved_volume  
      ,approved_volume_unit  
      ,importing_generator_id  
      ,importing_generator_name  
      ,importing_generator_address  
      ,importing_generator_city  
      ,importing_generator_province_territory  
      ,importing_generator_mail_code  
      ,importing_generator_epa_id  
      ,tech_contact_id  
      ,tech_contact_name  
      ,tech_contact_phone  
      ,tech_cont_email  
      ,tech_contact_fax  
      ,created_by  
      ,date_created  
      ,date_modified  
      ,modified_by  
      ,foreign_exporter_sameas_generator  
      )  
     SELECT @new_WI_form_id  
      ,@new_WI_Rev_id  
      ,@new_form_id  
      ,@revisonid  
      ,  
      --wcr_id,  
      --wcr_rev_id,  
      fw.locked  
      ,CASE   
       WHEN fw.foreign_exporter_sameas_generator = 'T'  
        THEN wcr.generator_name  
       ELSE fw.foreign_exporter_name  
       END  
      ,  
      --case when fw.foreign_exporter_sameas_generator = 'T'   
      -- then RTRIM(LTRIM(wcr.generator_address1 + ' ' + wcr.generator_city + ' ' + wcr.generator_state + ' ' + wcr.generator_country + ' ' + wcr.generator_zip))  
      -- else fw.foreign_exporter_address   
      --end,  
      CASE   
       WHEN fw.foreign_exporter_sameas_generator = 'T'  
        THEN wcr.generator_address1  
       ELSE fw.foreign_exporter_address  
       END  
      ,CASE   
       WHEN fw.foreign_exporter_sameas_generator = 'T'  
        THEN wcr.generator_city  
       ELSE fw.foreign_exporter_city  
       END  
      ,CASE   
       WHEN fw.foreign_exporter_sameas_generator = 'T'  
        THEN wcr.generator_state  
       ELSE fw.foreign_exporter_province_territory  
       END  
      ,CASE   
       WHEN fw.foreign_exporter_sameas_generator = 'T'  
        THEN wcr.generator_zip  
       ELSE fw.foreign_exporter_mail_code  
       END  
      ,CASE   
       WHEN fw.foreign_exporter_sameas_generator = 'T'  
        THEN wcr.gen_mail_country  
       ELSE fw.foreign_exporter_country  
       END  
      ,CASE   
       WHEN fw.foreign_exporter_sameas_generator = 'T'  
        THEN wcr.tech_contact_name  
       ELSE fw.foreign_exporter_contact_name  
       END  
      ,CASE   
       WHEN fw.foreign_exporter_sameas_generator = 'T'  
        THEN wcr.tech_contact_phone  
       ELSE fw.foreign_exporter_phone  
       END  
      ,CASE   
       WHEN fw.foreign_exporter_sameas_generator = 'T'  
        THEN wcr.tech_contact_fax  
       ELSE fw.foreign_exporter_fax  
       END  
      ,CASE   
       WHEN fw.foreign_exporter_sameas_generator = 'T'  
        THEN wcr.tech_cont_email  
       ELSE fw.foreign_exporter_email  
       END  
      ,fw.epa_notice_id  
      ,fw.epa_consent_number  
      ,NULL  
      ,NULL  
      ,  
      --effective_date,  
      --expiration_date,  
      fw.approved_volume  
      ,fw.approved_volume_unit  
      ,fw.importing_generator_id  
      ,fw.importing_generator_name  
      ,fw.importing_generator_address  
      ,fw.importing_generator_city  
      ,fw.importing_generator_province_territory  
      ,fw.importing_generator_mail_code  
      ,fw.importing_generator_epa_id  
      ,fw.tech_contact_id  
      ,fw.tech_contact_name  
      ,fw.tech_contact_phone  
      ,fw.tech_cont_email  
      ,fw.tech_contact_fax  
      ,@web_user_id  
      ,GETDATE()  
      ,GETDATE()  
      ,@modified_by_web_user_id  
      ,fw.foreign_exporter_sameas_generator  
     FROM FormWasteImport fw  
     INNER JOIN FormWCR wcr ON wcr.form_id = wcr_id  
      AND wcr.revision_id = wcr_rev_id  
     WHERE wcr_id = @form_id  
      AND wcr_rev_id = @revision_id  
    END  
   END TRY  
  
   BEGIN CATCH  
    PRINT 'waste import catch'  
  
    SELECT error_message()  
   END CATCH  
  
   -- Generator Knowledge supplement form    
   EXEC [sp_COR_GeneratorKnowledge_Copy] @source_form_id  
    ,@source_revision_id  
    ,@new_form_id  
    ,@revisonid  
    ,@web_user_id  
  
   -- Signature   
   IF (  
     EXISTS (  
      SELECT form_id  
      FROM FormSignature  
      WHERE form_id = @form_id  
       AND revision_id = @revision_id  
      )  
     )  
   BEGIN  
    INSERT INTO FormSignature (  
     form_id  
     ,revision_id  
     ,form_signature_type_id  
     ,form_version_id  
     ,sign_company  
     ,sign_name  
     ,sign_title  
     ,sign_email  
     ,sign_phone  
     ,sign_fax  
     ,sign_address  
     ,sign_city  
     ,sign_state  
     ,sign_zip_code  
     ,date_added  
     ,sign_comment_internal  
     ,rowguid  
     ,logon  
     ,contact_id  
     ,e_signature_type_id  
     ,  
     -- e_signature_id ,  
     e_signature_url  
     )  
    SELECT @new_form_id  
     ,@revisonid  
     ,form_signature_type_id  
     ,form_version_id  
     ,sign_company  
     ,sign_name  
     ,sign_title  
     ,sign_email  
     ,sign_phone  
     ,sign_fax  
     ,sign_address  
     ,sign_city  
     ,sign_state  
     ,sign_zip_code  
     ,date_added  
     ,sign_comment_internal  
     ,rowguid  
     ,logon  
     ,contact_id  
     ,e_signature_type_id  
     ,  
     -- e_signature_id ,  
     e_signature_url  
    FROM FormSignature  
    WHERE form_id = @form_id  
     AND revision_id = @revision_id  
   END  
  
   -- Signture End  
   -- FuelBlending  
   IF (  
     EXISTS (  
      SELECT form_id  
      FROM FormEcoflo  
      WHERE wcr_id = @form_id  
       AND wcr_rev_id = @revision_id  
      )  
     )  
   BEGIN  
    DECLARE @new_FB_form_id INT  
     ,@new_FB_Rev_id INT = 1  
  
    EXEC @new_FB_form_id = sp_sequence_next 'form.form_id'  
  
    INSERT INTO FormEcoflo (  
     form_id  
     ,revision_id  
     ,wcr_id  
     ,wcr_rev_id  
     ,viscosity_value  
     ,total_solids_low  
     ,total_solids_high  
     ,total_solids_description  
     ,fluorine_low  
     ,fluorine_high  
     ,chlorine_low  
     ,chlorine_high  
     ,bromine_low  
     ,bromine_high  
     ,iodine_low  
     ,iodine_high  
     ,created_by  
     ,modified_by  
     ,date_created  
     ,date_modified  
     ,total_solids_flag  
     ,organic_halogens_flag  
     ,fluorine_low_flag  
     ,fluorine_high_flag  
     ,chlorine_low_flag  
     ,chlorine_high_flag  
     ,bromine_low_flag  
     ,bromine_high_flag  
     ,iodine_low_flag  
     ,iodine_high_flag  
     )  
    SELECT @new_FB_form_id  
     ,@new_FB_Rev_id  
     ,@new_form_id  
     ,@revisonid  
     ,viscosity_value  
     ,total_solids_low  
     ,total_solids_high  
     ,total_solids_description  
     ,fluorine_low  
     ,fluorine_high  
     ,chlorine_low  
     ,chlorine_high  
     ,bromine_low  
     ,bromine_high  
     ,iodine_low  
     ,iodine_high  
     ,@web_user_id  
     ,@modified_by_web_user_id  
     ,GETDATE()  
     ,GETDATE()  
     ,total_solids_flag  
     ,organic_halogens_flag  
     ,fluorine_low_flag  
     ,fluorine_high_flag  
     ,chlorine_low_flag  
     ,chlorine_high_flag  
     ,bromine_low_flag  
     ,bromine_high_flag  
     ,iodine_low_flag  
     ,iodine_high_flag  
    FROM FormEcoflo  
    WHERE wcr_id = @form_id  
     AND wcr_rev_id = @revision_id  
   END  
  
   -- FuelBlending  
   -- VALIDATION  
   EXEC sp_Insert_Section_Status @new_form_id  
    ,@revisonid  
    ,@web_user_id;  
  
   EXEC sp_COR_Insert_Supplement_Section_Status @new_form_id  
    ,@revisonid  
    ,@web_user_id;  
  
   DECLARE @Counter INT  
  
   SET @Counter = 1  
  
   DECLARE @Data VARCHAR(3)  
  
   SELECT section  
   FROM FormSectionStatus  
   WHERE form_id = @form_id  
    AND revision_id = @revision_id  
  
   --DECLARE THE CURSOR FOR A QUERY.  
   --DECLARE FormsectionCursor CURSOR READ_ONLY  
   --FOR  
   --SELECT section  
   --FROM FormSectionStatus where form_id = @form_id  and revision_id=  @revision_id  
   --OPEN CURSOR.  
   --OPEN FormsectionCursor  
   --FETCH NEXT FROM FormsectionCursor INTO  
   -- @Data  
   --WHILE @@FETCH_STATUS = 0  
   -- BEGIN          
   -- IF @Counter = 1  
   --IF (@Data = 'SA')  
   -- BEGIN      
   --print 'validate_SA'  
   EXEC sp_Validate_Section_A @new_form_id  
    ,@revisonid  
  
   -- END  
   --IF (@Data = 'SB')  
   -- BEGIN  
   EXEC sp_Validate_Section_B @new_form_id  
    ,@revisonid  
  
   --END  
   --IF (@Data = 'SC')  
   -- BEGIN        
   EXEC sp_Validate_Section_C @new_form_id  
    ,@revisonid  
  
   --END  
   --IF (@Data = 'SD')  
   -- BEGIN  
   EXEC sp_Validate_Section_D @new_form_id  
    ,@revisonid  
  
   -- END  
   --IF (@Data = 'SE')  
   -- BEGIN  
   EXEC sp_Validate_Section_E @new_form_id  
    ,@revisonid  
  
   -- END  
   --IF (@Data = 'SF')  
   --  BEGIN  
   EXEC sp_Validate_Section_F @new_form_id  
    ,@revisonid  
  
   -- END  
   --IF (@Data = 'SG')  
   -- BEGIN     
   EXEC sp_Validate_Section_G @new_form_id  
    ,@revisonid  
  
   -- END  
   --IF (@Data = 'SH')  
   -- BEGIN  
   EXEC sp_Validate_Section_H @new_form_id  
    ,@revisonid  
  
   --END  
   -- IF (@Data = 'SL')  
   --BEGIN  
   EXEC sp_Validate_Section_L @new_form_id  
    ,@revisonid  
  
   --END  
   -- IF (@Data = 'DA')  
   --BEGIN  
   EXEC sp_Validate_Section_Document @new_form_id  
    ,@revisonid  
  
   --END  
   --IF (@Data = 'PB')  
   --BEGIN  
   -- EXEC sp_Validate_PCB @new_form_id , @revisonid, @web_user_id  
   --END  
   -- IF (@Data = 'LR')  
   --BEGIN  
   -- EXEC sp_Validate_LDR @new_form_id ,@revisonid, @web_user_id  
   --END  
   -- IF (@Data = 'BZ')  
   --BEGIN  
   -- EXEC sp_Validate_Benzene @new_form_id, @revisonid, @web_user_id  
   --END  
   -- IF (@Data = 'CN')  
   --BEGIN  
   -- EXEC sp_Validate_Certificate @new_form_id, @revisonid, @web_user_id  
   --END  
   -- IF (@Data = 'PL')  
   --BEGIN  
   -- EXEC sp_Validate_Pharmaceutical @new_form_id,@revisonid, @web_user_id  
   --END  
   -- IF (@Data = 'ID')  
   --BEGIN  
   -- EXEC sp_Validate_IllinoisDisposal @new_form_id,@revisonid, @web_user_id  
   --END  
   -- IF (@Data = 'TL')  
   --BEGIN  
   -- EXEC sp_Validate_Thermal @new_form_id, @revisonid, @web_user_id  
   --END  
   --IF (@Data = 'UL')  
   --BEGIN  
   -- EXEC sp_Validate_UsedOil @new_form_id, @revisonid, @web_user_id  
   --END  
   -- IF (@Data = 'WI')  
   --BEGIN  
   -- EXEC sp_Validate_WasteImport @new_form_id,@revisonid, @web_user_id  
   --END  
   --IF (@Data = 'CR')  
   --BEGIN  
   -- EXEC sp_Validate_Cylinder @new_form_id,@revisonid, @web_user_id  
   --END  
   --IF (@Data = 'DS')  
   --BEGIN  
   -- EXEC sp_Validate_Debris @new_form_id,@revisonid, @web_user_id  
   --END  
   --IF (@Data = 'RA')  
   --BEGIN  
   -- EXEC sp_Validate_RadioActive @new_form_id,@revisonid, @web_user_id  
   --END  
   --      SET @Counter = @Counter + 1  
   --FETCH NEXT FROM FormsectionCursor INTO  
   --     @Data   
   --  print @Data    
   --END  
   -- CLOSE FormsectionCursor  
   -- DEALLOCATE FormsectionCursor  
   -- print '234'  
   EXEC sp_COR_Validate_Supplementary_Form @new_form_id  
    ,@revisonid  
    ,@web_user_id  
  
   --EXEC sp_Update_Copy_FormSectionStatus @form_id,@revision_id,@new_form_id,@revisonid  
   EXEC sp_Validate_Status_Update @new_form_id  
    ,@revisonid  
  
   SET @Message = 'Profile Copied Successfully';  
   SET @formId = @new_form_id;  
   SET @rev_id = @revisonid;  
  
   DECLARE @i_contact_id INT  
    ,@i_customer_id INT  
    ,@i_generator_id INT  
  
   SELECT TOP 1 @i_contact_id = contact_id  
   FROM contact  
   WHERE web_userid = @web_user_id  
    AND web_access_flag = 'T'  
    AND contact_status = 'A'  
  
   SELECT TOP 1 @i_customer_id = customer_id  
    ,@i_generator_id = generator_id  
   FROM formwcr  
   WHERE form_id = @formId  
    AND revision_id = @rev_id  
  
   INSERT ContactCorFormWCRBucket (  
    contact_id  
    ,form_id  
    ,revision_id  
    ,customer_id  
    ,generator_id  
    )  
   VALUES (  
    @i_contact_id  
    ,@formId  
    ,@rev_id  
    ,@i_customer_id  
    ,@i_generator_id  
    )  
  
   --SELECT @formId as form_id, @rev_id as revision_id  
   SELECT CONCAT (  
     @formId  
     ,'-'  
     ,@rev_id  
     ) AS form_id  
    ,@rev_id AS revision_id  
    -- COMMIT TRANSACTION;  
  END TRY  
  
  BEGIN CATCH  
   --IF @@TRANCOUNT > 0  
   --SET @Message = Error_Message();  
   --SET @form_Id = @formId;  
   --      set @rev_id = @Revision_id;  
   IF @@TRANCOUNT > 0  
   BEGIN  
    PRINT 'rollback'  
  
    SET @Message = Error_Message();  
  
    SELECT @Message AS MessageResult  
     --ROLLBACK TRANSACTION;  
   END  
  
   INSERT INTO COR_DB.[dbo].[ErrorLogs] (  
    ErrorDescription  
    ,[Object_Name]  
    ,Web_user_id  
    ,CreatedDate  
    )  
   VALUES (  
    CONCAT (  
     Error_Message()  
     ,':  Form Id '  
     ,@formId  
     ,'   : revision id: '  
     ,@Revision_id  
     )  
    ,ERROR_PROCEDURE()  
    ,@web_user_id  
    ,GETDATE()  
    );  
  END CATCH  
 END  
GO

GRANT EXECUTE
	ON [dbo].[sp_FormWCR_Copy]
	TO COR_USER;
GO
