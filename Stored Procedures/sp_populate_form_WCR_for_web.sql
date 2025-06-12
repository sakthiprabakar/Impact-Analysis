
CREATE PROCEDURE sp_populate_form_WCR_for_web
	@profile_id		int,
	@added_by		varchar(60),
	@form_id		int,
	@revision_id	int,
	@is_copy_command	bit = 0
AS
/* **************************************************************************************
Populates WCR with data from Profile for copying and "editing" on the web
Loads on PLT_AI

History
06/03/2012 CG Created from sp_populate_form_WCR and modified to work for the web 
08/09/2012 JPB	We do NOT want to populate profile_id's into these copies of other data.
	So Every profile_id being inserted just got turned to dust.  or NULL.  Probably NULL.
09/13/2012 JPB Converted to get Contact info from ProfileContact table.
	ALSO Added generator_contact & generator_contact_title fields that weren't coming in.
09/27/2012 JPB	Revised to LEFT join to tables, this will enable this to work for PENDING profiles
	as well as Approved profiles.
11/06/2012 JPB	Removed odor_... fields.  Reverting to just [odor] and [odor_other_desc]
03/05/2013 JPB  Added ignitability_* fields from profilelab table. They were missing.
04/17/2013 SK	Added waste_code_UID to FormXWasteCode from ProfileWasteCode
09/27/2013 JPB	Converted fn_waste_code_type call to send waste_code_uid, not waste_code.
10/07/2013 JPB	Modified so only Active WasteCode records are used
10/12/2013 JPB	Added manifest_dot_sp_number
11/18/2013 JPB	Renamed pl.wcr_generator_total_annual_benzene to pl.tab
01/27/2015 JPB	Added min_constituent field in Constituent section

sp_sequence_next 'Form.form_id'
sp_populate_form_WCR_for_web 422380, 'jonathan', 195625, 1, 0
select * from profile where profile_id = 422380

select * from formwcr where form_id = 195625
SELECT TOP 10 * FROM formwcr where form_id order by form_id desc

*************************************************************************************** */
DECLARE	
--	@approval_key				int,
	@customer_id				int,
	@current_form_version_id	int,
	@generator_id				int,
	@locked						char(1),
--	@msg						varchar(255),
	@source						char(1),
	@status						char(1),
	@surcharge_exempt			CHAR(1)

SET NOCOUNT ON

SET @revision_id = 1
SET @status = 'A'
SET @locked = 'U'
SET @source = 'W'
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

declare -- contact variables from ProfileContact:
	@inv_contact_id		int,
	@inv_contact_name	varchar(40),
	@inv_contact_phone	varchar(20),
	@inv_contact_fax	varchar(10),
	@tech_contact_id	int,
	@tech_contact_name	varchar(40),
	@tech_contact_phone	varchar(20),
	@tech_contact_fax	varchar(10),
	@tech_contact_mobile	varchar(10),
	@tech_contact_pager	varchar(10),
	@tech_contact_email	varchar(50),
	@gen_contact_id		int,
	@generator_contact  varchar(40),
	@generator_contact_title varchar(20)	

select top 1
	@inv_contact_id		= null,
	@inv_contact_name	= contact_name,
	@inv_contact_phone	= contact_phone,
	@inv_contact_fax	= contact_fax
from ProfileContact 
where profile_id = @profile_id
and contact_type = 'Invoicing'

select top 1
	@tech_contact_id	= null,
	@tech_contact_name	= contact_name,
	@tech_contact_phone	= contact_phone,
	@tech_contact_fax	= contact_fax,
	@tech_contact_mobile = contact_mobile,
	@tech_contact_pager	= contact_pager,
	@tech_contact_email	= contact_email
from ProfileContact 
where profile_id = @profile_id
and contact_type = 'Technical'

select top 1
	@gen_contact_id		= null,
	@generator_contact	= contact_name,
	@generator_contact_title = contact_title
from ProfileContact 
where profile_id = @profile_id
and contact_type = 'Generator'

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
	,[generator_contact_id]
	,[generator_contact]
	,[generator_contact_title]
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
	,[manifest_dot_sp_number]
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
	-- ,[oxidizer]
	,[react_cyanide]
	,[react_sulfide]
	-- ,[info_basis]
	,[underlying_haz_constituents]
	,[michigan_non_haz]
	,[michigan_non_haz_comment]
	-- ,[universal]
	-- ,[recyclable_commodity]
	,[universal_recyclable_commodity]
	,[used_oil]
	-- ,[pcb_concentration]
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
	-- ,[profile_id]
	,[emergency_phone_number]
	,[generator_email]
	,[frequency_other]
	,[hazmat_flag]
	,[hazmat_class]
	,[subsidiary_haz_mat_class]
	,[package_group]
	,[un_na_flag]
	,[un_na_number]
	,[dot_shipping_desc]
	,[reportable_quantity_flag]
	-- ,[reportable_quantity]
	,[rq_reason]
/* - 11/6/12 - JPB, removed these to use older @odor field instead:
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
	-- ,[flammable]
	,[ddvohapgr500]
	,[Neshap_Chem_1]
	,[Neshap_Chem_2]
	-- ,[Part_61]
	-- ,[Part_62]
	-- ,[Part_63]
	,[neshap_standards_part]
	,[Neshap_subpart]
	,[Benzene_Onsite_Mgmt]
	,[Benzene_Onsite_Mgmt_desc]
	,[wwa_halogen_gt_1000]
	,[wwa_halogen_source]
	,[wwa_halogen_source_desc1]
	,[wwa_other_desc_1]
	,[erg_number]
	,[erg_suffix]
	)
SELECT 
	 @form_id					--form_id
	,@revision_id				--revision_id
	,@current_form_version_id	--form_version_id
	,p.customer_id				--customer_id
	,(CASE						--tracking_id
		WHEN @is_copy_command = 0
			THEN p.profile_id
		ELSE NULL END)
	,'A'			--status
	,'U'			--locked
	,@source			--source
	,GETDATE()		--date_created
	,GETDATE()		--date_modified
	,@added_by		--created_by
	,@added_by		--modified_by
	,NULL			--comments
	,NULL			--sample_id
	,c.cust_name		--cust_name
	,c.cust_addr1		--cust_addr1
	,c.cust_addr2		--cust_addr2
	,c.cust_addr3		--cust_addr3
	,c.cust_addr4		--cust_addr4
	,c.cust_city  		--cust_city
	,c.cust_state		--cust_state
	,c.cust_zip_code	--cust_zip
	,c.cust_country		--cust_country
	,@inv_contact_id
	,@inv_contact_name
	,@inv_contact_phone
	,@inv_contact_fax
	,@tech_contact_id
	,@tech_contact_name
	,@tech_contact_phone
	,@tech_contact_fax
	,@tech_contact_mobile
	,@tech_contact_pager
	,@tech_contact_email
	,@gen_contact_id
	,@generator_contact
	,@generator_contact_title
	,g.generator_id			--generator_id
	,g.EPA_ID				--EPA_ID
	,/*** rb 05/07/2012 g.sic_code				--sic_code ***/
	 pl.neshap_sic	
	,g.generator_name		--generator_name
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
	,g.generator_phone		--generator_phone
	,g.generator_fax		--generator_fax
	,p.approval_desc		--waste_common_name
	,p.shipping_volume_unit_other	-- volume
	,p.shipping_frequency			--frequency
	,p.DOT_shipping_name	--dot_shipping_name
	,p.manifest_dot_sp_number
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
	,pl.ignitability	--ignitability
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
			INNER JOIN wastecode ON wastecode.waste_code = ProfileWasteCode.waste_code
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
			INNER JOIN wastecode ON wastecode.waste_code = ProfileWasteCode.waste_code
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
			INNER JOIN wastecode ON wastecode.waste_code = ProfileWasteCode.waste_code
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
	-- ,pl.oxidizer				--oxidizer
	,pl.react_cyanide		--react_cyanide
	,pl.react_sulfide		--react_sulfide
	-- ,pl.info_basis --info_basis
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
			INNER JOIN wastecode ON wastecode.waste_code = ProfileWasteCode.waste_code
			WHERE profile_id = p.profile_id
				AND  haz_flag='F' and waste_code_origin = 'S'
		)
		THEN 'T'
		ELSE 'F'
	  END) ***/
	 pl.michigan_non_haz
	,NULL	--michigan_non_haz_comment
	-- ,pl.universal	--universal
	-- ,pl.recyclable_commodity--recyclable_commodity
	, pl.universal_recyclable_commodity
	,pl.used_oil
	-- ,pl.pcb_concentration						--pcb_concentration
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
	,/*** g.TAB					--tab ***/
	 COALESCE(pl.tab,g.TAB)
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
	-- ,p.profile_id				--profile_id
	,g.emergency_phone_number	--emergency_phone_number
	,con.email					--generator_email 
	,p.shipping_frequency_other				--frequency_other
	,p.hazmat						--hazmat_flag
	,p.hazmat_class				--hazmat_class
	,p.subsidiary_haz_mat_class	--subsidiary_haz_mat_class
	,p.package_group			--package_group
	,p.UN_NA_flag				--un_na_flag
	,p.UN_NA_number				--un_na_number
	,p.DOT_shipping_name		--dot_shipping_desc
	,p.reportable_quantity_flag	--reportable_quantity_flag
	-- ,null						-- reportable_quantity
	,p.rq_reason
/* - 11/6/12 - JPB, removed these to use older @odor field instead:
	,(CASE WHEN pl.odor_desc LIKE '%ammonia%' THEN 'T' ELSE 'F' END)				--odor_ammonia
	,(CASE WHEN pl.odor_desc LIKE '%amines%' THEN 'T' ELSE 'F' END)				--odor_amines
	,(CASE WHEN pl.odor_desc LIKE '%mercaptans%' THEN 'T' ELSE 'F' END)			--odor_mercaptans
	,(CASE WHEN pl.odor_desc LIKE '%sulfur%' THEN 'T' ELSE 'F' END)				--odor_sulfur
	,(CASE WHEN pl.odor_desc LIKE '%organic%acid%' THEN 'T' ELSE 'F' END)		--odor_organic_acid
	,(CASE WHEN isnull(ltrim(rtrim(pl.odor_desc)),'') <> ''
		AND pl.odor_desc NOT LIKE '%ammonia%'
		AND pl.odor_desc NOT LIKE '%amines%'
		AND pl.odor_desc NOT LIKE '%mercaptans%'
		AND pl.odor_desc NOT LIKE '%sulfur%'
		AND pl.odor_desc NOT LIKE '%organic%acid%'
		THEN 'T' ELSE 'F' END)			--odor_other
	,(CASE WHEN isnull(ltrim(rtrim(pl.odor_desc)),'') <> ''
		AND pl.odor_desc NOT LIKE '%ammonia%'
		AND pl.odor_desc NOT LIKE '%amines%'
		AND pl.odor_desc NOT LIKE '%mercaptans%'
		AND pl.odor_desc NOT LIKE '%sulfur%'
		AND pl.odor_desc NOT LIKE '%organic%acid%'
		THEN pl.odor_other_desc ELSE null END)			--odor_other_desc
*/		
	, pl.odor_other_desc
	,(CASE WHEN pl.consistency LIKE '%debris%' THEN 'T' ELSE 'F' END)		--consistency_debris
	,(CASE WHEN pl.consistency LIKE '%gas%aerosol%' THEN 'T' ELSE 'F' END)	--consistency_gas_aerosol
	,(CASE WHEN pl.consistency LIKE '%varies%' THEN 'T' ELSE 'F' END)	--consistency_varies
	,pl.air_reactive			--air_reactive
	,pl.temp_ctrl_org_peroxide	--temp_ctrl_org_peroxide
	,pl.Norm					--NORM
	,pl.TeNorm					-- TENORM
	,pl.handling_issue			--handling_issue
	,pl.handling_issue_desc		--handling_issue_desc
	,/*** rb 05/31/2012 p.RCRA_exempt_flag			--RCRA_exempt_flag ***/
	CASE WHEN p.rcra_exempt_flag = 'E' THEN 'T' ELSE 'F' END
	,p.rcra_exempt_reason		--RCRA_exempt_reason
	,pl.cyanide_plating			--cyanide_plating
	,p.EPA_source_code			--EPA_source_code
	,p.EPA_form_code			--EPA_form_code
	,p.waste_water_flag			--waste_water_flag
	,pl.debris_dimension_weight	--debris_dimension_weight
	-- ,pl.flammable	--flammable
	,/*** rb 05/07/2012 (CASE WHEN pl.DDVOC > 500 THEN 'T' ELSE 'F' END)	--ddvohapgr500 ***/
	 pl.ddvohapgr500
	,pl.neshap_chem_1	--Chem_1
	,pl.neshap_chem_2	--Chem_2
	-- ,pl.part_61	--Part_61
	-- ,pl.part_62 --Part_62
	-- ,pl.part_63 --Part_63
	,pl.neshap_standards_part
	,pl.neshap_subpart	--Subpart
	,/*** rb 05/07/2012 CASE WHEN pl.Benzene_Onsite_Mgmt_desc IS NOT NULL THEN 'T'	ELSE 'F' END		--Benzene_Onsite_Mgmt ***/
	 pl.benzene_onsite_mgmt
	,pl.benzene_onsite_mgmt_desc	--Benzene_Onsite_Mgmt_desc
	,pl.wwa_halogen_gt_1000
	,pl.halogen_source			--wwa_halogen_source
	,pl.halogen_source_desc		--wwa_halogen_source_desc1
	,pl.halogen_source_other	--wwa_other_desc_1
	,p.ERG_number				--erg_number
	,p.ERG_suffix				--erg_suffix
	FROM 
	Profile p
	left JOIN customer c ON c.customer_ID = p.customer_ID 
	left JOIN ProfileLab pl ON pl.profile_id = p.profile_id AND pl.type = 'A'
	left JOIN  Generator g ON g.generator_id = p.generator_id
	LEFT JOIN ContactXRef cxr ON cxr.primary_contact = 'T' AND p.generator_id = cxr.generator_id
	LEFT JOIN Contact con ON con.contact_id = cxr.contact_id
	WHERE  p.profile_id = @profile_id

	if @@error <> 0
	begin
		RAISERROR ('Error inserting into FormWCR', 16, 1)
		return -1
	end

		--Linked FormLDR
--IF EXISTS(
--	SELECT 1 FROM profile INNER JOIN ProfileLab ON profile.profile_id = ProfileLab.profile_id WHERE profile.profile_id = @profile_id 
--		AND ( ldrstuff IS NOT NULL )
--)
	--BEGIN
	--	DECLARE @ldr_form_id INT

	--	SET @ldr_form_id = ( SELECT form_id FROM FormLDR WHERE FormLDR.wcr_id = @form_id )

	--	IF (@ldr_form_id IS NULL)
	--	BEGIN
	--		EXEC @ldr_form_id = sp_Sequence_Next 'Form.Form_ID'
	--	END

	--	--insert into ldr table
	--	INSERT INTO [Plt_AI].[dbo].[FormLDR] (
	--		[form_id]
	--		,[revision_id]
	--		,[form_version_id]
	--		,[customer_id]
	--		,[status]
	--		,[locked]
	--		,[source]
	--		,[company_id]
	--		,[profit_ctr_id]
	--		,[signing_name]
	--		,[signing_company]
	--		,[signing_title]
	--		,[signing_date]
	--		,[date_created]
	--		,[date_modified]
	--		,[created_by]
	--		,[modified_by]
	--		,[generator_name]
	--		,[generator_epa_id]
	--		,[generator_address1]
	--		,[generator_city]
	--		,[generator_state]
	--		,[generator_zip]
	--		,[state_manifest_no]
	--		,[manifest_doc_no]
	--		,[generator_id]
	--		,[generator_address2]
	--		,[generator_address3]
	--		,[generator_address4]
	--		,[generator_address5]
	--		,[profitcenter_epa_id]
	--		,[profitcenter_profit_ctr_name]
	--		,[profitcenter_address_1]
	--		,[profitcenter_address_2]
	--		,[profitcenter_address_3]
	--		,[profitcenter_phone]
	--		,[profitcenter_fax]
	--		,[rowguid]
	--		,[wcr_id]
	--		,[wcr_rev_id]
	--		)
	--	SELECT
	--		@ldr_form_id
	--		,@revision_id
	--		,2 --form version
	--		,@customer_id
	--		,'A'	--Status
	--		,'U'	--Locked
	--		,@source	--Souirce
	--		,NULL	--co
	--		,NULL	--pc
	--		,NULL	--signing_name
	--		,NULL	--signing_company
	--		,NULL	--signing_title
	--		,NULL	--signing_date
	--		,getdate()	--date_created
	--		,getdate()	--date_modified
	--		,@added_by	--created_by
	--		,@added_by	--modified_by
	--		,g.generator_name
	--		,g.EPA_ID
	--		,g.generator_address_1
	--		,g.generator_city
	--		,g.generator_state
	--		,g.generator_zip_code
	--		,NULL --manifest doc #
	--		,NULL --state manifest #
	--		,g.generator_id
	--		,g.generator_address_2
	--		,g.generator_address_3
	--		,g.generator_address_4
	--		,g.generator_address_5
	--		,pc.EPA_ID -- pc epa id
	--		,pc.profit_ctr_name --<profitcenter_profit_ctr_name, varchar(50),>
	--		,pc.address_1 --<profitcenter_address_1, varchar(40),>
	--		,pc.address_2 --<profitcenter_address_2, varchar(40),>
	--		,pc.address_3 --<profitcenter_address_3, varchar(40),>
	--		,pc.phone --<profitcenter_phone, varchar(14),>
	--		,pc.fax --<profitcenter_fax, varchar(14),>
	--		,newid()
	--		,@form_id --wcr_id
	--		,@revision_id --wcr_rev_id
	--		FROM 
	--			Profile p, Generator g, ProfitCenter pc
	--			LEFT JOIN customer c ON c.customer_ID = p.customer_id
	--			WHERE pc.profit_ctr_id = @profit_ctr_id
	--			AND g.generator_id = @generator_id
	--			AND p.profile_id = @profile_id

	--	INSERT INTO [Plt_AI].[dbo].[FormLDRDetail] (
	--		[form_id]
	--		,[revision_id]
	--		,[form_version_id]
	--		,[page_number]
	--		,[manifest_line_item]
	--		,[ww_or_nww]
	--		,[subcategory]
	--		,[manage_id]
	--		,[approval_code]
	--		,[approval_key]
	--		,[company_id]
	--		,[profit_ctr_id]
	--		,[profile_id]
	--		)
	--	SELECT
	--		@ldr_form_id
	--		,@revision_id
	--		,(SELECT current_form_version FROM FormType where form_type = 'ldr') --[form_version_id]
	--		,1					--[page_number]
	--		,1					-- [manifest_line_item]
	--		,p.waste_water_flag	--ldr_ww_or_nww
	----,ldr_subcategory
	----,ldr_manage_id
	----,[approval_code]
	----,[approval_key]
	--		,pc.company_ID
	--		,pc.company_ID
	--		,@profile_id
	--		FROM 
	--			Profile p, Generator g, ProfitCenter pc
	--			LEFT JOIN customer c ON c.customer_ID = p.customer_id 
	--			LEFT JOIN ProfileLab pl ON pl.profile_id = p.profile_id
	--			WHERE pc.profit_ctr_id = @profit_ctr_id
	--			AND g.generator_id = @generator_id
	--			AND p.profile_id = @profile_id
	--END


--Linked NORM/TENORM
IF EXISTS (
		SELECT 1 FROM profile INNER JOIN ProfileLab 
		ON profile.profile_id = ProfileLab.profile_id 
		WHERE Profile.profile_id = @profile_id 
		AND ((profilelab.NORM = 'T') OR (profilelab.TENORM = 'T'))
)
BEGIN
	DECLARE @tenorm_id INT

	SET @tenorm_id = (
			SELECT form_id
			FROM FormNORMTENORM
			WHERE FormNORMTENORM.wcr_id = @form_id
			)

	IF (@tenorm_id IS NULL)
		IF @form_id > 0
			EXEC @tenorm_id = sp_Sequence_Next 'Form.Form_ID'
		ELSE
			EXEC @tenorm_id = sp_sequence_neg 'form.temp_form_id'

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
		-- ,[profile_id]
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
		,(SELECT current_form_version FROM FormType WHERE form_type = 'normtenorm')
		,'A'	--Status
		,'U'	--Locked
		,@source	--Souirce
		,NULL
		,NULL
		-- ,@profile_id
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
		left JOIN Generator g ON g.generator_id = p.generator_id
		left JOIN customer c ON c.customer_ID = p.customer_id 
		JOIN ProfileLab pl 
			ON pl.profile_id = p.profile_id
			AND pl.type = 'A'
		WHERE p.profile_id = @profile_id
		
		if @@error <> 0
		begin
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
			RAISERROR ('Error inserting into FormXunit for NORMTENORM', 16, 1)
			return -1
		END
		
		-- ProfitCenters
		INSERT INTO dbo.FormXApproval
		SELECT DISTINCT
			'NORMTENORM'
		,	@tenorm_id			--<form_id, int,>
		,	@revision_id	--<revision_id, int,>
		,	NULL -- PWF.company_id		--<company_id, int,>
		,	NULL -- PWF.profit_ctr_id	--<profit_ctr_id, int,>
		,	NULL -- @profile_id		-- profile_id - int
		,	NULL	-- approval_code - varchar(15)
		,	NULL -- PC.profit_ctr_name	-- profit_ctr_name - varchar(50)
		,	NULL -- PC.EPA_ID	-- profit_ctr_EPA_ID - varchar(12)
		,	NULL	-- insurance_exempt - char(1)
		,	NULL	-- ensr_exempt - char(1)
		,	NULL			-- quotedetail_comment - varchar(max)
		FROM dbo.ProfileQuoteApproval PWF
		JOIN dbo.ProfitCenter PC
			ON PC.company_ID = PWF.company_id
			AND PC.profit_ctr_ID = PWF.profit_ctr_id
		WHERE PWF.profile_id = @profile_id
		AND ((PWF.company_id = 2 AND PWF.profit_ctr_id = 0) OR (PWF.company_id = 3 AND PWF.profit_ctr_id = 0))
		
		if @@error <> 0
		begin
			RAISERROR ('Error inserting into FormXApproval for NORMTENORM', 16, 1)
			return -1
		end
			
	
END

---- Linked SREC( Surcharge Exempt) form
IF @surcharge_exempt = 'E'
BEGIN
	DECLARE @srec_form_id INT
	
	SET @srec_form_id = ( SELECT form_id FROM FormSREC WHERE FormSREC.wcr_id = @form_id )

	IF (@srec_form_id IS NULL)
		IF @form_id > 0
			EXEC @srec_form_id = sp_Sequence_Next 'Form.Form_ID'
		ELSE
			EXEC @srec_form_id = sp_sequence_neg 'form.temp_form_id'
	

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
	        -- ,profile_id
	        ,qty_units_desc
	        ,disposal_date
	        ,wcr_id
	        ,wcr_rev_id)
    SELECT  @srec_form_id -- form_id - int
    ,       @revision_id -- revision_id - int
    ,       (SELECT current_form_version FROM FormType WHERE form_type = 'srec')
    ,       P.customer_id	-- customer_id
    ,       P.customer_id	-- customre_id_from
    ,       NULL	-- app_id
    ,       'A'	--Status
    ,       'U'	--Locked
    ,       @source	--Source
    ,       NULL -- PQA.approval_code  --approval_code - varchar(15)
    ,       NULL -- @profile_id -- approval_key - int
    ,       NULL -- PQA.company_id -- company_id - int
    ,       NULL -- PQA.profit_ctr_id -- profit_ctr_id - int
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
    ,       NULL -- ProfitCenter.EPA_ID
    ,       NULL -- ProfitCenter.profit_ctr_name
    ,       NULL -- ProfitCenter.address_1
    ,       NULL -- ProfitCenter.address_2
    ,       NULL -- ProfitCenter.address_3
    ,       NULL -- ProfitCenter.phone
    ,       NULL -- ProfitCenter.fax
    ,       NEWID()-- rowguid - uniqueidentifier
    -- ,       P.profile_id -- profile_id - int
    ,       NULL -- qty_units_desc - varchar(255)
    ,       NULL -- disposal_date - varchar(255)
    ,       @form_id	-- wcr_id - int
    ,       @revision_id  -- wcr_rev_id - int
    FROM profile P
    left JOIN Generator g ON g.generator_id = p.generator_id
    left JOIN customer c ON c.customer_ID = p.customer_id
    left JOIN ProfileLab pl 
		ON pl.profile_id = p.profile_id
		AND pl.type = 'A'
    left JOIN dbo.ProfileQuoteApproval PQA 
		ON PQA.profile_id = P.profile_id 
		AND PQA.status = 'A' 
		AND PQA.primary_facility_flag = 'T'
	left JOIN ProfitCenter
		ON ProfitCenter.company_ID = PQA.company_id
		AND ProfitCenter.profit_ctr_ID = PQA.profit_ctr_id
    WHERE p.profile_id = @profile_id

	if @@error <> 0
	begin
		RAISERROR ('Error inserting into FormSREC', 16, 1)
		return -1
	end
END

--Composition
INSERT INTO dbo.FormXWCRComposition
( form_id ,
  revision_id ,
  comp_description ,
  comp_from_pct ,
  comp_to_pct ,
  rowguid
)
SELECT
	@form_id			-- form_id - int
	,@revision_id		-- revision_id - int
	,comp_description	---comp_description
	, comp_from_pct		-- comp_from_pct - float
	, comp_to_pct		-- comp_to_pct - float
	,NEWID()			-- rowguid - uniqueidentifier
FROM dbo.ProfileComposition
WHERE profile_id = @profile_id

if @@error <> 0
begin
	RAISERROR ('Error inserting into FormXWCRComposition', 16, 1)
	return -1
end

/*
				This cannot be inserted for a copy of a form. The copy (from web)
				is NOT associated with the same profiles, it's just new.

--COPCs into FormXAproval table
INSERT INTO dbo.FormXApproval
SELECT 
	'WCR'
,	@form_id			--<form_id, int,>
,	@revision_id	--<revision_id, int,>
,	NULL -- PWF.company_id		--<company_id, int,>
,	NULL -- PWF.profit_ctr_id	--<profit_ctr_id, int,>
,	NULL -- @profile_id		-- profile_id - int
,	NULL	-- approval_code - varchar(15)
,	NULL -- PC.profit_ctr_name	-- profit_ctr_name - varchar(50)
,	NULL -- PC.EPA_ID	-- profit_ctr_EPA_ID - varchar(12)
,	NULL	-- insurance_surcharge_percent - int
,	NULL	-- ensr_exempt - char(1)
,	NULL			-- quotedetail_comment - varchar(max)
FROM dbo.ProfileWCRFacility PWF
JOIN dbo.ProfitCenter PC
	ON PC.company_ID = PWF.company_id
	AND PC.profit_ctr_ID = PWF.profit_ctr_id
WHERE PWF.profile_id = @profile_id

UNION

SELECT 
	'WCR'
,	@form_id			--<form_id, int,>
,	@revision_id	--<revision_id, int,>
,	NULL -- PQA.company_id		--<company_id, int,>
,	NULL -- PQA.profit_ctr_id	--<profit_ctr_id, int,>
,	NULL -- @profile_id		-- profile_id - int
,	NULL -- PQA.approval_code	-- approval_code - varchar(15)
,	NULL -- PC.profit_ctr_name	-- profit_ctr_name - varchar(50)
,	NULL -- PC.EPA_ID	-- profit_ctr_EPA_ID - varchar(12)
,	NULL	-- insurance_surcharge_percent - int (only needed for confirmations, and this is a WCR)
,	NULL -- PQA.ensr_exempt	-- ensr_exempt - char(1)
,	NULL			-- quotedetail_comment - varchar(max)
FROM dbo.ProfileQuoteApproval PQA
JOIN dbo.ProfitCenter PC
	ON PC.company_ID = PQA.company_id
	AND PC.profit_ctr_ID = PQA.profit_ctr_id
WHERE PQA.status = 'A'
AND PQA.profile_id = @profile_id

if @@error <> 0
begin
	RAISERROR ('Error inserting into FormXApproval', 16, 1)
	return -1
end

*/

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
,psu.quantity		-- quantity - float
FROM ProfileShippingUnit psu WHERE psu.profile_id = @profile_id

if @@error <> 0
begin
	RAISERROR ('Error inserting into FormXUnit', 16, 1)
	return -1
end

-- Populate FormXConstituent
INSERT INTO FormXConstituent
(
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
)
SELECT	
	@form_id AS form_id,
	@revision_id AS revision_id,
	1 AS page_number,
	1 AS line_item,
	PC.const_id AS const_id,
	Constituents.const_desc AS const_desc,
	PC.min_concentration AS min_concentration,
	PC.concentration AS concentration,
	PC.unit AS unit,
	PC.UHC AS UHC,
	'WCR' AS specifier 
FROM ProfileConstituent PC, Constituents
WHERE PC.const_id = Constituents.const_id
AND PC.profile_id = @profile_id
AND PC.UHC = 'T'

if @@error <> 0
begin
	RAISERROR ('Error inserting into FormXConstituent', 16, 1)
	return -1
end

-- Populate FormXWasteCode
INSERT INTO FormXWasteCode (form_id, revision_id, page_number, line_item, waste_code_uid, waste_code, specifier)
SELECT	
	@form_id AS form_id,
	@revision_id AS revision_id,
	1 AS page_number,
	1 AS line_item,
	PW.waste_code_uid,
	PW.waste_code AS waste_code,
	specifier = dbo.fn_waste_code_type(PW.waste_code_uid)
FROM ProfileWasteCode PW
INNER JOIN WasteCode WC on PW.waste_code_uid = WC.waste_code_uid and WC.status = 'A'
WHERE PW.profile_id = @profile_id
AND dbo.fn_waste_code_type(PW.waste_code_uid) is not null


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_populate_form_WCR_for_web] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_populate_form_WCR_for_web] TO [COR_USER]
    AS [dbo];


