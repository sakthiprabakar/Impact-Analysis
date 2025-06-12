
CREATE PROCEDURE sp_forms_load_wcr (
	@form_id INT
	,@revision_id INT
	)
AS
/****************
sp_forms_load_wcr

2/23/2011 Created
11/06/2013  JPB	Changed RCRA_ haz_ flag to RCRA_exempt_flag
11/08/2013	JPB	Added wcr.manifest_dot_sp_number

sp_forms_load_wcr @form_id=217346, @revision_id=4
*****************/

SELECT TOP 1 wcr.form_id
	,wcr.revision_id
	,wcr.form_version_id
	,wcr.customer_id_from_form
	,wcr.customer_id
	,wcr.app_id
	,wcr.tracking_id
	,wcr.STATUS
	,wcr.locked
	,wcr.source
	,wcr.signing_name
	,wcr.signing_company
	,wcr.signing_title
	,wcr.signing_date
	,wcr.date_created
	,wcr.date_modified
	,wcr.created_by
	,wcr.modified_by
	,wcr.comments
	,wcr.sample_id
	,wcr.cust_name
	,wcr.cust_addr1
	,wcr.cust_addr2
	,wcr.cust_addr3
	,wcr.cust_addr4
	,wcr.cust_city
	,wcr.cust_state
	,wcr.cust_zip
	,wcr.cust_country
	,wcr.inv_contact_name
	,wcr.inv_contact_phone
	,wcr.inv_contact_fax
	,wcr.tech_contact_name
	,wcr.tech_contact_phone
	,wcr.tech_contact_fax
	,wcr.tech_contact_mobile
	,wcr.tech_contact_pager
	,wcr.tech_cont_email
	,wcr.generator_id
	,wcr.EPA_ID
	,wcr.sic_code
	,wcr.generator_name
	,wcr.generator_address1
	,wcr.generator_address2
	,wcr.generator_address3
	,wcr.generator_address4
	,wcr.generator_city
	,wcr.generator_state
	,wcr.generator_zip
	,wcr.generator_county_id
	,wcr.generator_county_name
	,wcr.gen_mail_address1
	,wcr.gen_mail_address2
	,wcr.gen_mail_address3
	,wcr.gen_mail_city
	,wcr.gen_mail_state
	,wcr.gen_mail_zip
	,wcr.generator_contact
	,wcr.generator_contact_title
	,wcr.generator_phone
	,wcr.generator_fax
	,wcr.waste_common_name
	,wcr.volume
	,wcr.frequency
	,wcr.dot_shipping_name
	,wcr.surcharge_exempt
	,wcr.pack_bulk_solid_yard
	,wcr.pack_bulk_solid_ton
	,wcr.pack_bulk_liquid
	,wcr.pack_totes
	,wcr.pack_totes_size
	,wcr.pack_cy_box
	,wcr.pack_drum
	,wcr.pack_other
	,wcr.pack_other_desc
	,wcr.color
	,wcr.odor
	,wcr.poc
	,wcr.consistency_solid
	,wcr.consistency_dust
	,wcr.consistency_liquid
	,wcr.consistency_sludge
	,wcr.ph
	,wcr.ph_lte_2
	,wcr.ph_gt_2_lt_5
	,wcr.ph_gte_5_lte_10
	,wcr.ph_gt_10_lt_12_5
	,wcr.ph_gte_12_5
	,wcr.ignitability
	,wcr.ignitability_lt_90
	,wcr.ignitability_90_139
	,wcr.ignitability_140_199
	,wcr.ignitability_gte_200
	,wcr.ignitability_NA
	,wcr.waste_contains_spec_hand_none
	,wcr.free_liquids
	,wcr.oily_residue
	,wcr.metal_fines
	,wcr.biodegradable_sorbents
	,wcr.amines
	,wcr.ammonia
	,wcr.dioxins
	,wcr.furans
	,wcr.biohazard
	,wcr.shock_sensitive_waste
	,wcr.reactive_waste
	,wcr.radioactive_waste
	,wcr.explosives
	,wcr.pyrophoric_waste
	,wcr.isocyanates
	,wcr.asbestos_friable
	,wcr.asbestos_non_friable
	,wcr.gen_process
	,wcr.rcra_listed
	,wcr.rcra_listed_comment
	,wcr.rcra_characteristic
	,wcr.rcra_characteristic_comment
	,wcr.state_waste_code_flag
	,wcr.state_waste_code_flag_comment
	,wcr.wastewater_treatment
	,wcr.exceed_ldr_standards
	,wcr.meets_alt_soil_treatment_stds
	,wcr.more_than_50_pct_debris
	,wcr.oxidizer
	,wcr.react_cyanide
	,wcr.react_sulfide
	,wcr.info_basis_knowledge
	,wcr.info_basis_analysis
	,wcr.info_basis_msds
	,wcr.underlying_haz_constituents
	,wcr.michigan_non_haz
	,wcr.michigan_non_haz_comment
	,wcr.universal_recyclable_commodity
	,wcr.recoverable_petroleum_product
	,wcr.used_oil
	,wcr.pcb_concentration_none
    ,wcr.pcb_concentration_0_49
    ,wcr.pcb_concentration_50_499
    ,wcr.pcb_concentration_500
	,wcr.pcb_source_concentration_gr_50
	,wcr.processed_into_non_liquid
	,wcr.processd_into_nonlqd_prior_pcb
	,wcr.pcb_non_lqd_contaminated_media
	,wcr.pcb_manufacturer
	,wcr.pcb_article_decontaminated
	,wcr.ccvocgr500
	,wcr.benzene
	,wcr.neshap_sic
	,wcr.tab_gr_10
	,wcr.avg_h20_gr_10
	,wcr.tab
	,wcr.benzene_gr_1
	,wcr.benzene_concentration
	,wcr.benzene_unit
	,wcr.fuel_blending
	,wcr.btu_per_lb
	,wcr.pct_chlorides
	,wcr.pct_moisture
	,wcr.pct_solids
	,wcr.intended_for_reclamation
	,wcr.pack_drum_size
	,wcr.water_reactive
	,wcr.aluminum
	,wcr.subject_to_mact_neshap
	,wcr.subject_to_mact_neshap_codes
	--,wcr.srec_exempt_id
	,wcr.profile_id
/* - 11/6/12 - JPB, removed these to use older @odor field instead:
	,wcr.odor_none
	,wcr.odor_ammonia
	,wcr.odor_amines
	,wcr.odor_mercaptans
	,wcr.odor_sulfur
	,wcr.odor_organic_acid
	,wcr.odor_other
*/	
	,wcr.odor_other_desc
	,wcr.consistency_debris
	,wcr.consistency_gas_aerosol
	,wcr.pH_NA
	,wcr.air_reactive
	,wcr.temp_ctrl_org_peroxide
	,wcr.handling_issue
	,wcr.handling_issue_desc
	,wcr.RCRA_exempt_flag
	,wcr.RCRA_exempt_reason
	,wcr.cyanide_plating
	,wcr.EPA_source_code
	,wcr.EPA_form_code
	,wcr.waste_water_flag
	,wcr.debris_dimension_weight
	,wcr.ddvohapgr500
	,wcr.neshap_Chem_1
	,wcr.neshap_Chem_2
	,wcr.neshap_standards_part
	,wcr.neshap_Subpart
	,wcr.Benzene_Onsite_Mgmt
	,wcr.Benzene_Onsite_Mgmt_desc
	,wcr.emergency_phone_number
	,wcr.generator_email
	,wcr.frequency_other
	,wcr.hazmat_flag
	,wcr.hazmat_class
	,wcr.subsidiary_haz_mat_class
	,wcr.package_group
	,wcr.un_na_flag
	,wcr.un_na_number
	,wcr.erg_number
	, convert(varchar(10), wcr.erg_number) + isnull(wcr.erg_suffix, '') as erg_code
	,wcr.manifest_dot_sp_number
	,wcr.dot_shipping_desc
	,wcr.reportable_quantity_flag
	,wcr.RQ_reason
	-- ,wcr.reportable_quantity
	-- ,wcr.flammable
	,wcr.consistency_varies
	,wcr.inv_contact_id
	,wcr.tech_contact_id
	,wcr.generator_contact_id
	,wcr.facility_instruction
	,wcr.source_form_id
	,wcr.source_revision_id
	,wcr.template_form_id
	,ldrd.ww_or_nww AS 'ldr_ww_or_nww'
	,ldrd.manage_id AS 'ldr_manage_id'
	,ldrd.subcategory AS 'ldr_subcategory'
	,ntn.NORM
	,ntn.TENORM
	,ntn.disposal_restriction_exempt
	,ntn.nuclear_reg_state_license
	,ntn.shipping_dates
	,wcr.wwa_halogen_source
	,wcr.wwa_halogen_gt_1000
	,wcr.wwa_other_desc_1
	,wcr.wwa_halogen_source_desc1
	,srec.disposal_date [srec_date_of_disposal]
	,srec.qty_units_desc [srec_volume]
	,srec.exempt_id [srec_exempt_id]
	,(CASE WHEN srec.disposal_date IS NOT NULL OR srec.qty_units_desc IS NOT NULL OR srec.exempt_id  IS NOT NULL THEN 'T' ELSE NULL END)  [srec_flag]
FROM formWCR wcr
	LEFT JOIN FormLDR ldr ON ldr.wcr_id = wcr.form_id and ldr.wcr_rev_id = wcr.revision_id
	LEFT JOIN FormLDRDetail ldrd ON ldr.form_id = ldrd.form_id
	AND ldr.revision_id = ldrd.revision_id 
	LEFT JOIN FormSREC srec ON srec.wcr_id = wcr.form_id AND srec.wcr_rev_id = wcr.revision_id
	LEFT JOIN FormNORMTENORM ntn ON ntn.wcr_id = wcr.form_id AND ntn.wcr_rev_id = wcr.revision_id
WHERE wcr.form_id = @form_id
	AND wcr.revision_id = @revision_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_load_wcr] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_load_wcr] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_load_wcr] TO [EQAI]
    AS [dbo];

