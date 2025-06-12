-- drop procedure sp_populate_form_WCR
go

CREATE PROCEDURE sp_populate_form_WCR
	@form_id		int,
	@profile_id		int,
	@company_id		INT,
	@profit_ctr_id	INT,
	@added_by		varchar(60)
AS
/***************************************************************************************
--Description
------------------
--Populates WCR with data from Profile.
--Loads on PLT_AI

--History
------------------
--01/11/2012 SK Created
--04/04/2012 CG Updated Fields
--05/07/2012 RB Replaced some computed fields with new fields added to Profile/ProfileLab
                tables. Also added error checking.
  05/21/2012 SK	Tracking ID for WCR should be Profile ID, added norm, tenorm seperate fields
  05/22/2012 SK	Other value on Shipping volume & unit should go into field "Volume"(Drop new field
				Shipping_volume_unit_other from FormWCR)
  05/29/2012 SK Updated to add linked SREC form
  05/30/2012 SK Source field should be populated with 'A' for all forms created in this sp
  05/31/2012 SK WCR Facilities will be stored in the FormXapproval instead of FormXprofitcenter
  05/31/2012 RB Modified how rcra_haz_flag and underlying_haz_constituents are populated
  06/01/2012 RB Make newly created WCR the primary WCR
  06/04/2012 RB Added waste_contains_spec_hand_none
  06/05/2012 RB CASE statements for odor_ammonia, odor_amines, odor_mercaptans, odor_organic_acid,
                and odor_sulfur where checking odor column instead of odor_desc. Also, other_odor
                was always being set to a selected odor.
  06/05/2012 RB Added handling for new column FormWCR.consistency_varies
  06/06/2012 SK	Used new table ProfileWCRFacility to load the facilities for WCR. 
  06/06/2012 RB Populate Invoicing and Technical Contact fields
  06/11/2012 SK	Corrected the UNION for inserting WCR facilities
  06/12/2012 RB Removed tech_contact_id, replaced with contact_id, added generator_contact_id
  06/22/2012 RB Populated date_last_profile_sync with getdate() to make WCR most current
  06/28/2012 RB Added UNIV_RG_NA column
  06/29/2012 RB Added generator_contact (name) and generator_contact_title
  07/03/2012 RB	Added missing field for Halogen
  07/05/2012 SK	Changed the join to customer & generator to LEFT OUTER
  07/17/2012 RB Increment revision_id if @form_id already exists
  07/31/2012 SK Updated for lot of new/changed/removed fields and table. Also commented the bundled LDR, SREC code
  08/14/2012 SK When generator = 0 EPA ID should be blank, not VAR-I-OUS
  09/11/2012 SK	Updated to use the ProfileContact table
  10/03/2012 SK Updated to get the source & template fields
  11/06/2012 JPB	Removed odor_... fields.  Reverting to just [odor] and [odor_other_desc]
  11/15/2012 SK	Commenting NORM programming for now
  04/17/2013 SK	Added the Waste_code_UID to FORMXwastecode population section.
  08/22/2013 SK Modified the function fn_waste_code_type to take waste_code_uid
  10/02/2013 SK	Changed to copy only active waste codes to the form from profile
  11/05/2013 SK	Addition of new fields:
					FormWCR - manifest_dot_sp_number, rcra_exempt_flag
					FormXWCRComposition - unit, sequence_id
  11/15/2013 SK Renamed Profile.wcr_generator_total_annual_benzene to tab, Form should always get TAB value from generator
  05/08/2014 SK	Added suggested signature information fields
  01/26/2015 AM Added new min_concentration field to FormXConstituent.
  07/03/2019 MPM	Samanage 12526 - Added column list to inserts.

  --sp_populate_form_WCR 59261, 24575, 14, 6, 'SMITA_K'
****************************************************************************************/
DECLARE	
	@approval_key				int,
	@count						TINYINT,
	@customer_id				int,
	@current_form_version_id	int,
	@generator_id				int,
	@form_version_id			INT,
	@ldr_form_id				INT,
	@line_item					TINYINT,
	@locked						char(1),
	@msg						varchar(255),
	@record_ID					int,
	@revision_id				int,
	@source						char(1),
	@status						char(1),
	@surcharge_exempt			CHAR(1)

	
BEGIN TRANSACTION CreateWCR
	
SET NOCOUNT ON

-- rb 07/17/2012 Instead of forcing @revision_id to be 1, increment revision_id if @form_id already exists
-- SET @revision_id = 1
select @revision_id = max(revision_id)
from FormWCR
where form_id = @form_id

if @revision_id is null or @revision_id < 0
	SET @revision_id = 0
SET @revision_id = @revision_id + 1


SET @status = 'A'
SET @locked = 'U'
SET @source = 'A'
SELECT @current_form_version_id = current_form_version FROM FormType WHERE form_type = 'WCR'


SELECT	@generator_id = generator_id,
	@customer_id = customer_id
FROM Profile
WHERE profile_id = @profile_id
AND curr_status_code IN ('A', 'H', 'P')

SELECT @surcharge_exempt = sr_type_code
FROM dbo.ProfileQuoteApproval
WHERE profile_id = @profile_id
AND status = 'A'
AND primary_facility_flag = 'T'

--Create new wcr from profile
INSERT INTO [Plt_AI].[dbo].[FormWCR] (
	[form_id]
	,[revision_id]
	,[form_version_id]
	,[customer_id]
	,[tracking_id]
	,[status]
	,[locked]
	,[source]
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
	,[inv_contact_id]
	,[inv_contact_name]
	,[inv_contact_phone]
	,[inv_contact_fax]
	,[tech_contact_id]
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
	,[generator_phone]
	,[generator_fax]
	,[waste_common_name]
	,[volume]
	,[frequency]
	,[dot_shipping_name]
	,[surcharge_exempt]
	,[color]
	,[odor]
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
	,[ph_NA]
	--,[ignitability]
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
	,[dioxins]
	,[furans]
	,[biohazard]
	,[shock_sensitive_waste]
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
	--,[oxidizer]
	,[react_cyanide]
	,[react_sulfide]
	--,[info_basis]
	,[info_basis_knowledge]
	,[info_basis_analysis]
	,[info_basis_msds]
	,[underlying_haz_constituents]
	,[michigan_non_haz]
	,[michigan_non_haz_comment]
	--,[universal]
	--,[recyclable_commodity]
	--,[UNIV_RG_NA]
	,[universal_recyclable_commodity]
	,[used_oil]
	--,[pcb_concentration]
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
	--,[reportable_quantity]
	,[RQ_reason]
/* - 11/6/12 - JPB, removed these to use older @odor field instead:
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
	,[consistency_varies]
	,[air_reactive]
	,[temp_ctrl_org_peroxide]
	,[Norm]
	,[TeNorm]
	,[handling_issue]
	,[handling_issue_desc]
	,[RCRA_exempt_flag]
	,[RCRA_exempt_reason]
	,[cyanide_plating]
	,[EPA_source_code]
	,[EPA_form_code]
	,[waste_water_flag]
	,[debris_dimension_weight]
	--,[flammable]
	,[ddvohapgr500]
	,[neshap_Chem_1]
	,[neshap_Chem_2]
	--,[Part_61]
	--,[Part_62]
	--,[Part_63]
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
	,[generator_contact_id]
	,[generator_contact]
	,[generator_contact_title]
	,[date_last_profile_sync]
	,[facility_instruction]
	,[template_form_id]
	,[source_form_id]
	,[source_revision_id]
	,[signing_name]
	,[signing_title]
	,[signing_company]
	)
SELECT 
	 @form_id					--form_id
	,@revision_id				--revision_id
	,@current_form_version_id	--form_version_id
	,p.customer_id				--customer_id
	,p.profile_id		--tracking_id
	,'A'			--status
	,'U'			--locked
	,@source			--source
	,GETDATE()		--date_created
	,GETDATE()		--date_modified
	,@added_by		--created_by
	,@added_by		--modified_by
	,NULL			--comments
	,NULL			--sample_id
	,cust_name = COALESCE(c.cust_name, p.pending_customer_name, 'Pending')	--cust_name
	,c.cust_addr1		--cust_addr1
	,c.cust_addr2		--cust_addr2
	,c.cust_addr3		--cust_addr3
	,c.cust_addr4		--cust_addr4
	,c.cust_city  		--cust_city
	,c.cust_state		--cust_state
	,c.cust_zip_code	--cust_zip
	,c.cust_country		--cust_country
	,null	--inv_contact_id
	,pci.contact_name		--inv_contact_name
	,pci.contact_phone		--inv_contact_phone
	,pci.contact_fax			--inv_contact_fax
	,null		--tech_contact_id
	,pct.contact_name		--tech_contact_name
	,pct.contact_phone		--tech_contact_phone
	,pct.contact_fax			--tech_contact_fax
	,pct.contact_mobile		--tech_contact_mobile
	,pct.contact_pager		--tech_contact_pager
	,pct.contact_email		--tech_cont_email
	,g.generator_id			--generator_id
	,CASE g.generator_id WHEN 0 THEN NULL ELSE g.EPA_ID	END AS epa_id			--EPA_ID
	,/*** rb 05/07/2012 g.sic_code				--sic_code ***/
	 pl.neshap_sic	
	,generator_name = COALESCE(g.generator_name, p.pending_generator_name, 'Pending')		--generator_name
	,g.generator_address_1	--generator_address1
	,g.generator_address_2	--generator_address2
	,g.generator_address_3	--generator_address3
	,g.generator_address_4	--generator_address4
	,g.generator_city		--generator_city
	,g.generator_state		--generator_state
	,g.generator_zip_code	--generator_zip
	,g.generator_county		--generator_county_id
	,(SELECT county_name FROM dbo.County WHERE county_code = g.generator_county) --generator_county_name
	,g.gen_mail_addr1		--gen_mail_address1
	,g.gen_mail_addr2		--gen_mail_address2
	,g.gen_mail_addr3		--gen_mail_address3
	,g.gen_mail_city		--gen_mail_city
	,g.gen_mail_state		--gen_mail_state
	,g.gen_mail_zip_code	--gen_mail_zip
	,pcg.contact_phone		--generator_phone
	,pcg.contact_fax		--generator_fax
	,p.approval_desc		--waste_common_name
	,p.shipping_volume_unit_other	-- volume
	,p.shipping_frequency			--frequency
	,p.DOT_shipping_name	--dot_shipping_name
	,CASE @surcharge_exempt
	 WHEN 'E' THEN 'T'
	 WHEN 'P' THEN 'F'
	 WHEN 'H' THEN 'F'
	 ELSE 'U' END AS surcharge_exempt --surcharge_exempt
	,pl.color		--color
	,pl.odor_desc	--odor
	,(CASE WHEN pl.consistency LIKE '%solid%' THEN 'T' ELSE 'F' END)	--consistency_solid
	,(CASE WHEN pl.consistency LIKE '%dust%' THEN 'T' WHEN pl.consistency LIKE '%powder%' THEN 'T' ELSE 'F' END)		--consistency_dust
	,(CASE WHEN pl.consistency LIKE '%liquid%' THEN 'T' ELSE 'F' END)	--consistency_liquid
	,(CASE WHEN pl.consistency LIKE '%sludge%' THEN 'T' ELSE 'F' END)	--consistency_sludge
	, NULL			--ph
	,pl.ph_lte_2	--ph_lte_2
	,pl.ph_gt_2_lt_5	--ph_gt_2_lt_5
	,pl.ph_gte_5_lte_10	--ph_gte_5_lte_10
	,pl.ph_gt_10_lt_12_5	--ph_gt_10_lt_12_5
	,pl.ph_gte_12_5	--ph_gte_12_5
	,pl.ph_na
	--,pl.ignitability	--ignitability
	,pl.ignitability_lt_90
	,pl.ignitability_90_139
	,pl.ignitability_140_199
	,pl.ignitability_gte_200
	,pl.ignitability_NA
	,pl.waste_contains_spec_hand_none /*** rb 06/04/2012 NULL ***/	--waste_contains_spec_hand_none
	,pl.free_liquid				--free_liquids
	,pl.oily_residue			--oily_residue
	,pl.metal_fines				--metal_fines
	,pl.biodegradable_sorbents	--biodegradable_sorbents
	,pl.dioxins					--dioxins
	,pl.furans					--furans
	,pl.biohazard				--biohazard
	,pl.shock_sensitive_waste	--shock_sensitive_waste
	,pl.radioactive_waste		--radioactive_waste
	,pl.explosives				--explosives
	,pl.pyrophoric_waste		--pyrophoric_waste
	,pl.isocyanates				--isocyanates
	,pl.asbestos_friable		--asbestos_friable
	,pl.asbestos_non_friable		--asbestos_no_friable
	,p.gen_process				--gen_process
	,/*** rb 05/07/2012 (CASE   --rcra_listed
		WHEN EXISTS (
			SELECT 1
			FROM ProfileWasteCode
			INNER JOIN wastecode ON wastecode.waste_code_uid = ProfileWasteCode.waste_code_uid
			WHERE profile_id = p.profile_id
				AND haz_flag='T' and (waste_type_code='L' or waste_type_code = 'C') and waste_code_origin = 'F'
		)
		THEN 'T'
		ELSE 'F'
	  END) ***/
	 p.rcra_listed
	,NULL	--rcra_listed_comment
	,/*** rb 05/07/2012 (CASE		--rcra_characteristic
		WHEN EXISTS (
			SELECT 1
			FROM ProfileWasteCode
			INNER JOIN wastecode ON wastecode.waste_code_uid = ProfileWasteCode.waste_code_uid
			WHERE profile_id = p.profile_id
				AND haz_flag='T' and waste_type_code='C' and waste_code_origin = 'F'
		)
		THEN 'T'
		ELSE 'F'
	  END) ***/
	 p.rcra_characteristic
	,NULL	--rcra_characteristic_comment
	,/*** rb 05/07/2012 (CASE		--state_waste_code_flag
		WHEN EXISTS (
			SELECT 1
			FROM ProfileWasteCode
			INNER JOIN wastecode ON wastecode.waste_code_uid = ProfileWasteCode.waste_code_uid
			WHERE profile_id = p.profile_id
				AND haz_flag = 'T'
				AND waste_code_origin = 'S'
		)
		THEN 'T'
		ELSE 'F'
	  END) ***/
	 pl.state_waste_code_flag
	,NULL --state_waste_code_flag_comment
	, P.waste_water_flag --wastewater_treatment
	,exceed_ldr_standards	--exceed_ldr_standards
	,pl.meets_alt_soil_treatment_stds --meets_alt_soil_treatment_stds
	,pl.more_than_50_pct_debris--more_than_50_pct_debris
	--,pl.oxidizer				--oxidizer
	,pl.react_cyanide		--react_cyanide
	,pl.react_sulfide		--react_sulfide
	--,pl.info_basis --info_basis
	,pl.info_basis_knowledge
	,pl.info_basis_analysis
	,pl.info_basis_msds
	,/*** rb 05/31/2012 (CASE		--underlying_haz_constituents
		WHEN EXISTS (
			SELECT 1
			FROM ProfileConstituent
			WHERE profile_id = p.profile_id
				AND  UHC = 'T' AND const_id IS NOT NULL
		)
		THEN 'T'
		ELSE 'F'
	  END) ***/
	pl.underlying_haz_constituents
	,/*** rb 05/07/2012 (CASE		--michigan_non_haz
		WHEN EXISTS (
			SELECT 1
			FROM ProfileWasteCode
			INNER JOIN wastecode ON wastecode.waste_code_uid = ProfileWasteCode.waste_code_uid
			WHERE profile_id = p.profile_id
				AND  haz_flag='F' and waste_code_origin = 'S'
		)
		THEN 'T'
		ELSE 'F'
	  END) ***/
	 pl.michigan_non_haz
	,NULL	--michigan_non_haz_comment
	--,pl.universal	--universal
	--,pl.recyclable_commodity	--recyclable_commodity
	--,pl.UNIV_RG_NA	--UNIV_RG_NA
	,pl.universal_recyclable_commodity -- universal_recyclable_commodity
	,pl.used_oil
	--,pl.pcb_concentration						--pcb_concentration
	,pl.pcb_concentration_none
	,pl.pcb_concentration_0_49
	,pl.pcb_concentration_50_499
	,pl.pcb_concentration_500
	,pl.pcb_source_concentration_gr_50		--pcb_source_concentration_gr_50
	,/*** rb 05/07/2012 CASE WHEN pl.processd_into_nonlqd_prior_pcb > 0 THEN 'T' ELSE 'F' END -- ***/
	 pl.processed_into_non_liquid
	,pl.processd_into_nonlqd_prior_pcb	--processd_into_nonlqd_prior_pcb
	,pl.pcb_non_lqd_contaminated_media	--pcb_non_lqd_contaminated_media
	,pl.pcb_manufacturer				--pcb_manufacturer
	,pl.pcb_article_decontaminated		--pcb_article_decontaminated
	,/*** rb 05/07/2012 (CASE WHEN pl.CCVOC > 500 THEN 'T' ELSE 'F' END)					--ccvocgr500 ***/
	 pl.ccvocgr500
	,/*** rb 05/07/2012 (CASE WHEN pl.benzene IS NOT NULL AND pl.benzene <> 0 THEN 'T' ELSE 'F' END)		--benzene ***/
	 pl.contains_benzene_flag
	,/*** rb 05/07/2012 (CASE WHEN pl.neshap_sic IS NOT NULL AND pl.neshap_sic <> 0 THEN 'T' ELSE 'F' END) --neshap_sic ***/
	 pl.benzene_neshap
	,/*** rb 05/07/2012 (CASE WHEN g.TAB IS NOT NULL AND g.TAB < 10 THEN 'F' ELSE 'T' END)					--tab_gr_10 ***/
	 pl.tab_gr_10
	,pl.avg_h20_gr_10		--avg_h20_gr_10
	,g.TAB	
	 --COALESCE(pl.tab,g.TAB)
	,(CASE WHEN pl.benzene IS NOT NULL AND pl.benzene < 1 THEN 'F' ELSE 'T' END)		--benzene_gr_1
	,pl.benzene				--benzene_concentration
	,/*** rb 05/07/2012  'ppm' --benzene_unit ***/
	 pl.benzene_unit
	,pl.BTU_per_lb			--btu_per_lb
	,pl.pct_chlorides		--pct_chlorides
	,pl.pct_moisture		--pct_moisture
	,pl.pct_solids			--pct_solids
	, NULL --intended_for_reclamation
	, NULL --pack_drum_size
	,pl.water_reactive	--water_reactive (water_react??)
	,aluminum			--aluminum
	,pl.subject_to_mact_neshap	--subject_to_mact_neshap
	,pl.subject_to_mact_neshap	--subject_to_mact_neshap_codes
	, NULL --srec_exempt_id
	,p.waste_water_flag			--ldr_ww_or_nww * profile
	,p.LDR_subcategory			--ldr_subcategory * profile
	,p.waste_managed_id			--ldr_manage_id * profile.waste_managed_id
	,p.profile_id				--profile_id
	,g.emergency_phone_number	--emergency_phone_number
	,pcg.contact_email					--generator_email 
	,p.shipping_frequency_other				--frequency_other
	,p.hazmat						--hazmat_flag
	,p.hazmat_class				--hazmat_class
	,p.subsidiary_haz_mat_class	--subsidiary_haz_mat_class
	,p.package_group			--package_group
	,p.UN_NA_flag				--un_na_flag
	,p.UN_NA_number				--un_na_number
	,p.manifest_dot_sp_number
	,(SELECT dbo.fn_dot_shipping_desc(p.profile_id))	--dot_shipping_desc
	,p.reportable_quantity_flag	--reportable_quantity_flag
	--, NULL --reportable_quantity
	,p.RQ_reason -- RQ_Reason
/* - 11/6/12 - JPB, removed these to use older @odor field instead:
	,(CASE WHEN pl.odor_desc LIKE '%none%' THEN 'T' ELSE 'F' END)				--odor_none
	,(CASE WHEN pl.odor_desc LIKE '%ammonia%' THEN 'T' ELSE 'F' END)				--odor_ammonia
	,(CASE WHEN pl.odor_desc LIKE '%amines%' THEN 'T' ELSE 'F' END)				--odor_amines
	,(CASE WHEN pl.odor_desc LIKE '%mercaptans%' THEN 'T' ELSE 'F' END)			--odor_mercaptans
	,(CASE WHEN pl.odor_desc LIKE '%sulfur%' THEN 'T' ELSE 'F' END)				--odor_sulfur
	,(CASE WHEN pl.odor_desc LIKE '%organic%acid%' THEN 'T' ELSE 'F' END)		--odor_organic_acid
	,(CASE WHEN pl.odor_desc LIKE '%other%' THEN 'T' ELSE 'F' END)				--odor_other
*/	
	,pl.odor_other_desc						--odor_other_desc
	,(CASE WHEN pl.consistency LIKE '%debris%' THEN 'T' ELSE 'F' END)		--consistency_debris
	,(CASE WHEN pl.consistency LIKE '%gas%aerosol%' THEN 'T' ELSE 'F' END)	--consistency_gas_aerosol
	,(CASE WHEN pl.consistency LIKE '%varies%' THEN 'T' ELSE 'F' END)	--consistency_varies
	,pl.air_reactive			--air_reactive
	,pl.temp_ctrl_org_peroxide	--temp_ctrl_org_peroxide
	,pl.Norm					--NORM
	,pl.TeNorm					-- TENORM
	,pl.handling_issue			--handling_issue
	,pl.handling_issue_desc		--handling_issue_desc
	/*** rb 05/31/2012 p.RCRA_haz_flag			--RCRA_haz_flag ***/
	--CASE WHEN p.rcra_haz_flag is null THEN null WHEN p.rcra_haz_flag = 'E' THEN 'T' ELSE 'F' END
	,p.rcra_exempt_flag
	,p.rcra_exempt_reason		--RCRA_exempt_reason
	,pl.cyanide_plating			--cyanide_plating
	,p.EPA_source_code			--EPA_source_code
	,p.EPA_form_code			--EPA_form_code
	,p.waste_water_flag			--waste_water_flag
	,pl.debris_dimension_weight	--debris_dimension_weight
	--,pl.flammable	--flammable
	,/*** rb 05/07/2012 (CASE WHEN pl.DDVOC > 500 THEN 'T' ELSE 'F' END)	--ddvohapgr500 ***/
	 pl.ddvohapgr500
	,pl.neshap_chem_1	--Chem_1
	,pl.neshap_chem_2	--Chem_2
	--,pl.part_61	--Part_61
	--,pl.part_62 --Part_62
	--,pl.part_63 --Part_63
	,pl.neshap_standards_part
	,pl.neshap_subpart	--Subpart
	,/*** rb 05/07/2012 CASE WHEN pl.Benzene_Onsite_Mgmt_desc IS NOT NULL THEN 'T'	ELSE 'F' END		--Benzene_Onsite_Mgmt ***/
	 pl.benzene_onsite_mgmt
	,pl.benzene_onsite_mgmt_desc	--Benzene_Onsite_Mgmt_desc
	,/*** rb 07/03/2012 NULL --wwa_halogen_gt_1000 ***/
	 pl.wwa_halogen_gt_1000
	,pl.halogen_source			--wwa_halogen_source
	,pl.halogen_source_desc		--wwa_halogen_source_desc1
	,pl.halogen_source_other	--wwa_other_desc_1
	,p.ERG_number				--erg_number
	,p.ERG_suffix				--erg_suffix
	,null		--generator_contact_id
	,pcg.contact_name			--generator_contact
	,pcg.contact_title			--generator_contact_title
	,getdate()			--date_last_profile_sync
	,p.facility_instruction	--facility_instruction
	,p.template_form_id
	,p.source_form_id
	,p.source_revision_id
	,p.suggested_signing_name
	,p.suggested_signing_title
	,p.suggested_signing_company
	FROM 
	Profile p
	LEFT OUTER JOIN customer c ON c.customer_ID = p.customer_ID 
	JOIN ProfileLab pl ON pl.profile_id = p.profile_id AND pl.type = 'A'
	LEFT OUTER JOIN  Generator g ON g.generator_id = p.generator_id
	LEFT JOIN ContactXRef cxr ON cxr.primary_contact = 'T' AND p.generator_id = cxr.generator_id
	LEFT JOIN Contact con ON con.contact_id = cxr.contact_id
	LEFT OUTER JOIN ProfileContact PCI on P.Profile_id = PCI.profile_id and PCI.contact_type = 'Invoicing'
	LEFT OUTER JOIN ProfileContact PCG on P.Profile_id = PCG.profile_id and PCG.contact_type = 'Generator'
	LEFT OUTER JOIN ProfileContact PCT on P.Profile_id = PCT.profile_id and PCT.contact_type = 'Technical'
	--LEFT OUTER JOIN Contact ci ON p.inv_contact_id = ci.contact_id
	--LEFT OUTER JOIN Contact ct ON p.contact_id = ct.contact_id
	--LEFT OUTER JOIN Contact cg ON p.generator_contact_id = cg.contact_id
	WHERE  p.profile_id = @profile_id

	if @@error <> 0
	begin
		-- Rollback the transaction
		ROLLBACK TRANSACTION CreateWCR
		
		RAISERROR ('Error inserting into FormWCR', 16, 1)
		return -1
	end

/**** LINKED LDR 
--IF EXISTS( SELECT 1 FROM ProfileQuoteApproval PQA WHERE PQA.profile_id = @profile_id and PQA.status = 'A' AND PQA.LDR_req_flag = 'T')
IF EXISTS( SELECT 1 FROM Profile P WHERE P.profile_id = @profile_id AND 
			(P.LDR_subcategory IS NOT NULL OR P.waste_managed_id > 0 OR P.waste_water_flag IS NOT NULL))
BEGIN
	SET @ldr_form_id = ( SELECT form_id FROM FormLDR WHERE FormLDR.wcr_id = @form_id )
	IF (@ldr_form_id IS NULL)
	BEGIN
		EXEC @ldr_form_id = sp_Sequence_Next 'Form.Form_ID'
	END
	SET @form_version_id = (SELECT current_form_version FROM FormType where form_type = 'ldr')
	SET @line_item = 0

	--INSERT INTO FORMLDR
	INSERT INTO [Plt_AI].[dbo].[FormLDR] (
		[form_id]
		,[revision_id]
		,[form_version_id]
		,[customer_id]
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
	SELECT
		@ldr_form_id
		,@revision_id
		,@form_version_id 
		,@customer_id
		,'A'	--Status
		,'U'	--Locked
		,@source	--Souirce
		,NULL	--co
		,NULL	--pc
		,NULL	--signing_name
		,NULL	--signing_company
		,NULL	--signing_title
		,NULL	--signing_date
		,getdate()	--date_created
		,getdate()	--date_modified
		,@added_by	--created_by
		,@added_by	--modified_by
		,g.generator_name
		,g.EPA_ID
		,g.generator_address_1
		,g.generator_city
		,g.generator_state
		,g.generator_zip_code
		,NULL --manifest doc #
		,NULL --state manifest #
		,g.generator_id
		,g.generator_address_2
		,g.generator_address_3
		,g.generator_address_4
		,g.generator_address_5
		,NULL -- pc epa id
		,NULL --<profitcenter_profit_ctr_name, varchar(50),>
		,NULL --<profitcenter_address_1, varchar(40),>
		,NULL --<profitcenter_address_2, varchar(40),>
		,NULL --<profitcenter_address_3, varchar(40),>
		,NULL --<profitcenter_phone, varchar(14),>
		,NULL --<profitcenter_fax, varchar(14),>
		,newid()
		,@form_id --wcr_id
		,@revision_id --wcr_rev_id
		FROM Profile p
		LEFT OUTER JOIN Generator g ON g.generator_id = P.generator_id
		LEFT OUTER JOIN customer c ON c.customer_ID = p.customer_id
		WHERE p.profile_id = @profile_id

	---- LOOP through all the approvals that require LDR
	--DECLARE @LDR_Approvals TABLE(
	--	record_id		int		identity
	--,	company_ID		int
	--,	Profit_ctr_id	int
	--,	approval_code	varchar(15)
	--,	process_flag	tinyint)
	
	--INSERT INTO @LDR_Approvals
	--SELECT
	--	PQA.company_id
	--,	PQA.profit_ctr_id
	--,	PQA.approval_code
	--,	0 AS process_flag
	--FROM dbo.ProfileQuoteApproval PQA
	--WHERE PQA.profile_id = @profile_id
	--AND PQA.status = 'A'
	--AND PQA.LDR_req_Flag = 'T'
	--SET @count = @@ROWCOUNT
	
	SET @line_item = 0
	
	--IF @count > 0
	--BEGIN
		--SELECT @record_ID = IsNull(MIN(record_id), 0) FROM @LDR_Approvals WHERE process_flag = 0
		--WHILE @record_ID <> 0
		--BEGIN
			SET @line_item = @line_item + 1
			
			INSERT INTO [Plt_AI].[dbo].[FormLDRDetail] (
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
				,[subcategory_id]
				)
			SELECT
				@ldr_form_id
				,@revision_id
				,@form_version_id 
				,1					--[page_number]
				,@line_item -- [manifest_line_item]
				,p.waste_water_flag	--ldr_ww_or_nww
				, NULL --old subcategory column
				,p.waste_managed_id
				,NULL --approval_code
				,NULL --approval_key
				,NULL
				,NULL
				,@profile_id
				,LDS.subcategory_id
			FROM Profile p
			LEFT OUTER JOIN LDRSubcategory LDS ON LDS.short_desc = P.LDR_subcategory
			WHERE p.profile_id = @profile_id
	
			--INSERT LDR Wastecodes
			INSERT INTO FormXWasteCode
			SELECT	
				@ldr_form_id AS form_id,
				@revision_id AS revision_id,
				1 AS page_number,
				@line_item AS line_item,
				PW.waste_code AS waste_code,
				'LDR' AS specifier
			FROM ProfileWasteCode PW
			WHERE PW.profile_id = @profile_id
			AND dbo.fn_waste_code_type(PW.waste_code_uid) is not null

			--INSERT LDR Constituents
			INSERT INTO FormXConstituent
			SELECT	
				@ldr_form_id AS form_id,
				@revision_id AS revision_id,
				1 AS page_number,
				@line_item AS line_item,
				PC.const_id AS const_id,
				Constituents.const_desc AS const_desc,
				PC.concentration AS concentration,
				PC.unit AS unit,
				PC.UHC AS UHC,
				'LDR' AS specifier 
			FROM ProfileConstituent PC, Constituents
			WHERE PC.const_id = Constituents.const_id
			AND PC.profile_id = @profile_id
			AND PC.UHC = 'T' 
		
		--	-- update this record as processed
		--	UPDATE @LDR_Approvals SET process_flag = 1 WHERE record_id = @record_ID
		--	-- move on to next
		--	SELECT @record_ID = IsNull(MIN(record_id), 0) FROM @LDR_Approvals WHERE process_flag = 0
		--END
	--END

END ******/

--Linked NORM/TENORM
/******IF EXISTS (
		SELECT 1 FROM profile INNER JOIN ProfileLab 
		ON profile.profile_id = ProfileLab.profile_id 
		WHERE Profile.profile_id = @profile_id 
		AND (( profilelab.NORM = 'T'	) OR ( profilelab.TENORM = 'T'))
)
BEGIN
	DECLARE @tenorm_id INT

	SET @tenorm_id = (
			SELECT form_id
			FROM FormNORMTENORM
			WHERE FormNORMTENORM.wcr_id = @form_id
			)

	IF (@tenorm_id IS NULL)
	BEGIN
		EXEC @tenorm_id = sp_Sequence_Next 'Form.Form_ID'
	END

	--NORM/TENORM
	INSERT INTO [Plt_AI].[dbo].[FormNORMTENORM] (
		 [form_id]
		,[revision_id]
		,[version_id]
		,[status]
		,[locked]
		,[source]
		,[company_id]
		,[profit_ctr_id]
		,[profile_id]
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
		,[unit_other]
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
	SELECT 
		@tenorm_id
		,@revision_id
		,1		--version_id
		,'A'	--Status
		,'U'	--Locked
		,@source	--Souirce
		,@company_id
		,@profit_ctr_id
		,@profile_id
		,g.generator_id
		,g.EPA_ID
		,g.generator_name
		,g.generator_address_1
		,g.generator_address_2
		,g.generator_address_3
		,g.generator_address_4
		,g.generator_address_5
		,g.generator_city
		,g.generator_state
		,g.generator_zip_code
		,g.gen_mail_addr1
		,g.gen_mail_addr2
		,g.gen_mail_addr3
		,g.gen_mail_addr4
		,g.gen_mail_addr5
		,g.gen_mail_city
		,g.gen_mail_state
		,g.gen_mail_zip_code
		,pl.NORM	--[NORM]
		,pl.TENORM	--[TENORM]
		,p.norm_disposal_restriction_exempt	--[disposal_restriction_exempt]
		,p.norm_nuclear_reg_state_license	--[nuclear_reg_state_license]
		,p.gen_process	--[waste_process]
		,p.shipping_volume_unit_other --[unit_other]
		,p.shipping_dates	--[shipping_dates]
		,NULL	--[signing_name]
		,NULL	--[signing_company]
		,NULL	--[signing_title]
		,NULL	--[signing_date]
		,getdate()
		,getdate()
		,@added_by
		,@added_by
		,@form_id		--wcr
		,@revision_id	--wcr
		FROM Profile p
		LEFT OUTER JOIN Generator g ON g.generator_id = p.generator_id
		LEFT OUTER JOIN customer c ON c.customer_ID = p.customer_id 
		JOIN ProfileLab pl 
			ON pl.profile_id = p.profile_id
			AND pl.type = 'A'
		WHERE p.profile_id = @profile_id
		
		if @@error <> 0
		begin
			-- Rollback the transaction
			ROLLBACK TRANSACTION CreateWCR
			
			RAISERROR ('Error inserting into FormNORMTENORM', 16, 1)
			return -1
		end
			
		--Volumes & units
		INSERT INTO dbo.FormXUnit (
				form_type
			,	form_id
			,	revision_id
			,	bill_unit_code
			,	quantity
			)
		SELECT 'NORMTENORM'
			,@tenorm_id -- form_id - int
			,@revision_id -- revision_id - int
			,psu.bill_unit_code -- bill_unit_code - varchar(4)
			,psu.quantity -- quantity - float
		FROM ProfileShippingUnit psu
		WHERE psu.profile_id = @profile_id
		
		if @@error <> 0
		begin
			-- Rollback the transaction
			ROLLBACK TRANSACTION CreateWCR
			
			RAISERROR ('Error inserting into FormXunit for NORMTENORM', 16, 1)
			return -1
		END
		
		-- ProfitCenters
		INSERT INTO dbo.FormXApproval
		SELECT 
			'NORMTENORM'
		,	@tenorm_id			--<form_id, int,>
		,	@revision_id	--<revision_id, int,>
		,	PQA.company_id		--<company_id, int,>
		,	PQA.profit_ctr_id	--<profit_ctr_id, int,>
		,	@profile_id		-- profile_id - int
		,	NULL	-- approval_code - varchar(15)
		,	PC.profit_ctr_name	-- profit_ctr_name - varchar(50)
		,	PC.EPA_ID	-- profit_ctr_EPA_ID - varchar(12)
		,	NULL	-- insurance_exempt - char(1)
		,	NULL	-- ensr_exempt - char(1)
		,	NULL			-- quotedetail_comment - varchar(max)
		FROM dbo.ProfileQuoteApproval PQA
		JOIN dbo.ProfitCenter PC
			ON PC.company_ID = PQA.company_id
			AND PC.profit_ctr_ID = PQA.profit_ctr_id
		WHERE PQA.profile_id = @profile_id
		AND ((PQA.company_id = 2 AND PQA.profit_ctr_id = 0) OR (PQA.company_id = 3 AND PQA.profit_ctr_id = 0))
		
		if @@error <> 0
		begin
				-- Rollback the transaction
			ROLLBACK TRANSACTION CreateWCR
			
			RAISERROR ('Error inserting into FormXApproval for NORMTENORM', 16, 1)
			return -1
		end
			
	
END ***/

/** Linked SREC( Surcharge Exempt) form
IF @surcharge_exempt = 'E'
BEGIN
	DECLARE @srec_form_id INT
	
	SET @srec_form_id = ( SELECT form_id FROM FormSREC WHERE FormSREC.wcr_id = @form_id )

	IF (@srec_form_id IS NULL)
	BEGIN
		EXEC @srec_form_id = sp_Sequence_Next 'Form.Form_ID'
	END

	--SREC
	INSERT INTO dbo.FormSREC
	        (form_id
	        ,revision_id
	        ,form_version_id
	        ,customer_id_from_form
	        ,customer_id
	        ,app_id
	        ,status
	        ,locked
	        ,source
	        ,approval_code
	        ,approval_key
	        ,company_id
	        ,profit_ctr_id
	        ,signing_name
	        ,signing_company
	        ,signing_title
	        ,signing_date
	        ,date_created
	        ,date_modified
	        ,created_by
	        ,modified_by
	        ,exempt_id
	        ,waste_type
	        ,waste_common_name
	        ,manifest
	        ,cust_name
	        ,generator_name
	        ,EPA_ID
	        ,generator_id
	        ,gen_mail_addr1
	        ,gen_mail_addr2
	        ,gen_mail_addr3
	        ,gen_mail_addr4
	        ,gen_mail_addr5
	        ,gen_mail_city
	        ,gen_mail_state
	        ,gen_mail_zip_code
	        ,profitcenter_epa_id
	        ,profitcenter_profit_ctr_name
	        ,profitcenter_address_1
	        ,profitcenter_address_2
	        ,profitcenter_address_3
	        ,profitcenter_phone
	        ,profitcenter_fax
	        ,rowguid
	        ,profile_id
	        ,qty_units_desc
	        ,disposal_date
	        ,wcr_id
	        ,wcr_rev_id)
    SELECT  @srec_form_id -- form_id - int
    ,       @revision_id -- revision_id - int
    ,       2		--version_id
    ,       P.customer_id	-- customer_id
    ,       P.customer_id	-- customre_id_from
    ,       NULL	-- app_id
    ,       'A'	--Status
    ,       'U'	--Locked
    ,       @source	--Source
    ,       PQA.approval_code  --approval_code - varchar(15)
    ,       @profile_id -- approval_key - int
    ,       PQA.company_id -- company_id - int
    ,       PQA.profit_ctr_id -- profit_ctr_id - int
    ,       NULL	--[signing_name]
    ,       NULL	--[signing_company]
    ,       NULL	--[signing_title]
    ,       NULL	--[signing_date]
    ,       GETDATE() -- date_created - datetime
    ,       GETDATE() -- date_modified - datetime
    ,       @added_by -- created_by - varchar(60)
    ,       @added_by -- modified_by - varchar(60)
    ,       PQA.srec_exempt_id -- exempt_id - int
    ,       NULL -- waste_type - varchar(50)
    ,       P.approval_desc -- waste_common_name - varchar(50)
    ,       NULL -- manifest - varchar(20)
    ,       c.cust_name -- cust_name - varchar(40)
    ,       g.generator_name -- generator_name - varchar(40)
    ,       g.EPA_ID -- EPA_ID - varchar(12)
    ,       g.generator_id
    ,       g.gen_mail_addr1
    ,       g.gen_mail_addr2
    ,       g.gen_mail_addr3
    ,       g.gen_mail_addr4
    ,       g.gen_mail_addr5
    ,       g.gen_mail_city
    ,       g.gen_mail_state
    ,       g.gen_mail_zip_code
    ,       ProfitCenter.EPA_ID
    ,       ProfitCenter.profit_ctr_name
    ,       ProfitCenter.address_1
    ,       ProfitCenter.address_2
    ,       ProfitCenter.address_3
    ,       ProfitCenter.phone
    ,       ProfitCenter.fax
    ,       NEWID()-- rowguid - uniqueidentifier
    ,       P.profile_id -- profile_id - int
    ,       NULL -- qty_units_desc - varchar(255)
    ,       NULL -- disposal_date - varchar(255)
    ,       @form_id	-- wcr_id - int
    ,       @revision_id  -- wcr_rev_id - int
    FROM profile P
    LEFT OUTER JOIN Generator g ON g.generator_id = p.generator_id
    LEFT OUTER JOIN customer c ON c.customer_ID = p.customer_id
    JOIN ProfileLab pl 
		ON pl.profile_id = p.profile_id
		AND pl.type = 'A'
    JOIN dbo.ProfileQuoteApproval PQA 
		ON PQA.profile_id = P.profile_id 
		AND PQA.status = 'A' 
		AND PQA.primary_facility_flag = 'T'
	JOIN ProfitCenter
		ON ProfitCenter.company_ID = PQA.company_id
		AND ProfitCenter.profit_ctr_ID = PQA.profit_ctr_id
    WHERE p.profile_id = @profile_id

	if @@error <> 0
	begin
		RAISERROR ('Error inserting into FormSREC', 16, 1)
		return -1
	end
END ***/

--Composition
INSERT INTO dbo.FormXWCRComposition
( form_id ,
  revision_id ,
  comp_description ,
  comp_from_pct ,
  comp_to_pct ,
  rowguid,
  unit,
  sequence_id
)
SELECT
	@form_id			-- form_id - int
	,@revision_id		-- revision_id - int
	,comp_description	---comp_description
	, comp_from_pct		-- comp_from_pct - float
	, comp_to_pct		-- comp_to_pct - float
	,NEWID()			-- rowguid - uniqueidentifier
	,unit
	,sequence_id
FROM dbo.ProfileComposition
WHERE profile_id = @profile_id

if @@error <> 0
begin
	-- Rollback the transaction
	ROLLBACK TRANSACTION CreateWCR
		
	RAISERROR ('Error inserting into FormXWCRComposition', 16, 1)
	return -1
end

--COPCs into FormXAproval table
INSERT INTO dbo.FormXApproval (
	form_type,
	form_id,
	revision_id,
	company_id,
	profit_ctr_id,
	profile_id,
	approval_code,
	profit_ctr_name,
	profit_ctr_EPA_ID,
	insurance_surcharge_percent,
	ensr_exempt,
	quotedetail_comment
)
SELECT 
	'WCR'
,	@form_id			--<form_id, int,>
,	@revision_id	--<revision_id, int,>
,	PQA.company_id		--<company_id, int,>
,	PQA.profit_ctr_id	--<profit_ctr_id, int,>
,	@profile_id		-- profile_id - int
,	NULL	-- approval_code - varchar(15)
,	PC.profit_ctr_name	-- profit_ctr_name - varchar(50)
,	PC.EPA_ID	-- profit_ctr_EPA_ID - varchar(12)
,	NULL	-- insurance_surcharge_percent
,	NULL	-- ensr_exempt - char(1)
,	NULL			-- quotedetail_comment - varchar(max)
FROM dbo.ProfileQuoteApproval PQA
JOIN dbo.ProfitCenter PC
	ON PC.company_ID = PQA.company_id
	AND PC.profit_ctr_ID = PQA.profit_ctr_id
WHERE PQA.status = 'A'
AND PQA.profile_id = @profile_id

if @@error <> 0
begin
	-- Rollback the transaction
	ROLLBACK TRANSACTION CreateWCR
		
	RAISERROR ('Error inserting into FormXApproval', 16, 1)
	return -1
end

--Volumes 
INSERT INTO dbo.FormXUnit
( form_type,
	form_id ,
  revision_id ,
  bill_unit_code ,
  quantity
)
SELECT 
'WCR'
,@form_id			-- form_id - int
,@revision_id		-- revision_id - int
,psu.bill_unit_code -- bill_unit_code - varchar(4)
,psu.quantity		-- quantity - varchar(max)
FROM ProfileShippingUnit psu WHERE psu.profile_id = @profile_id

if @@error <> 0
begin
	-- Rollback the transaction
	ROLLBACK TRANSACTION CreateWCR
	
	RAISERROR ('Error inserting into FormXUnit', 16, 1)
	return -1
end

-- Populate FormXConstituent
INSERT INTO FormXConstituent (
	form_id,
	revision_id,
	page_number,
	line_item,
	const_id,
	const_desc,
	concentration,
	min_concentration,
	unit,
	uhc,
	specifier
)
SELECT	
	@form_id AS form_id,
	@revision_id AS revision_id,
	NULL AS page_number,
	NULL AS line_item,
	PC.const_id AS const_id,
	Constituents.const_desc AS const_desc,
	PC.concentration AS concentration,
	PC.min_concentration AS min_concentration,
	PC.unit AS unit,
	PC.UHC AS UHC,
	'WCR' AS specifier 
FROM ProfileConstituent PC, Constituents
WHERE PC.const_id = Constituents.const_id
AND PC.profile_id = @profile_id
AND PC.UHC = 'T'

if @@error <> 0
begin
	-- Rollback the transaction
	ROLLBACK TRANSACTION CreateWCR
	
	RAISERROR ('Error inserting into FormXConstituent', 16, 1)
	return -1
end

-- Populate FormXWasteCode
INSERT INTO FormXWasteCode (
	form_id,
	revision_id,
	page_number,
	line_item,
	waste_code_uid,
	waste_code,
	specifier
)
SELECT	
	@form_id AS form_id,
	@revision_id AS revision_id,
	NULL AS page_number,
	NULL AS line_item,
	PW.waste_code_UID,
	PW.waste_code AS waste_code,
	specifier = dbo.fn_waste_code_type(PW.waste_code_uid)
	--PW.waste_code_UID
FROM ProfileWasteCode PW
JOIN WasteCode W ON W.waste_code_uid = PW.waste_code_uid AND W.status = 'A'
WHERE PW.profile_id = @profile_id
-- rb 05/11/2012 optimize later...
AND dbo.fn_waste_code_type(PW.waste_code_uid) is not null

if @@error <> 0
begin
	-- Rollback the transaction
	ROLLBACK TRANSACTION CreateWCR
		
	RAISERROR ('Error inserting into FormXWasteCode', 16, 1)
	return -1
end

-- rb 06/01/2012 Make the newest WCR the primary
update Profile
set form_id_wcr = @form_id
where profile_id = @profile_id

if @@error <> 0
begin
	-- Rollback the transaction
	ROLLBACK TRANSACTION CreateWCR
		
	RAISERROR ('Error updating Profile.form_id_wcr', 16, 1)
	return -1
end

COMMIT TRANSACTION CreateWCR
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_populate_form_WCR] TO [EQAI]


