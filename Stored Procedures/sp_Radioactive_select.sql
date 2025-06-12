CREATE PROCEDURE [dbo].[sp_Radioactive_select](
	
		 @form_id INT,
		 @revision_id INT

)
AS

/* ******************************************************************
  Updated By       : PRABHU
  Updated On date  : 2nd Nov 2019
  Decription       : Details for Pending Profile Radioactive Form Selection
  Type             : Stored Procedure
  Object Name      : [sp_Radioactive_Select]

  Select Radioactive Supplementary Form columns Values  (Part of form wcr Select and Edit)

  Inputs 
	 Form ID
	 Revision ID
 
  Samples:
	 EXEC [dbo].[sp_Radioactive_Select] @form_id,@revision_id
	 EXEC [dbo].[sp_Radioactive_Select] '503468','1'


	Updated By		: Karuppiah
	Updated On		: 10th Dec 2024
	Type			: Stored Procedure
	Ticket   		: Titan-US134197,US132686,US134198,US127722
	Change			: Const_id added.

****************************************************************** */

BEGIN

DECLARE @section_status CHAR(1);
	SELECT @section_status =section_status FROM formsectionstatus WHERE form_id=@form_id AND revision_id = @revision_id and section='RA'
		SELECT
		ISNULL(RE.form_id,'') AS form_id,
		ISNULL(RE.revision_id,'') AS revision_id,
		COALESCE(RE.wcr_id, @form_id) AS wcr_id,
		COALESCE(RE.wcr_rev_id, @revision_id) AS wcr_rev_id,
		ISNULL(RE.locked,'') AS locked,
		ISNULL(RE.uranium_thorium_flag,'') AS uranium_thorium_flag,
		ISNULL(RE.uranium_source_material,'') AS uranium_source_material,
		ISNULL(RE.radium_226_flag,'') AS radium_226_flag,
		ISNULL(RE.radium_228_flag,'') AS radium_228_flag,
		ISNULL(RE.lead_210_flag,'') AS lead_210_flag,
		ISNULL(RE.potassium_40_flag,'') AS potassium_40_flag,
		ISNULL(RE.exempt_byproduct_material_flag,'') AS exempt_byproduct_material_flag,
		ISNULL(RE.special_nuclear_material_flag,'') AS special_nuclear_material_flag,
		ISNULL(RE.accelerator_flag,'') AS accelerator_flag,
		ISNULL(RE.generated_in_particle_accelerator_flag,'') AS generated_in_particle_accelerator_flag,
		ISNULL(RE.approved_for_disposal_flag,'') AS approved_for_disposal_flag,
		ISNULL(RE.approved_by_nrc_flag,'') AS approved_by_nrc_flag,
		ISNULL(RE.approved_for_alternate_disposal_flag,'') AS approved_for_alternate_disposal_flag,
		ISNULL(RE.nrc_exempted_flag,'') AS nrc_exempted_flag,
		ISNULL(RE.released_from_radiological_control_flag,'') AS released_from_radiological_control_flag,
		ISNULL(RE.DOD_non_licensed_disposal_flag,'') AS DOD_non_licensed_disposal_flag,
		ISNULL(RE.created_by,'') AS created_by,
		ISNULL(RE.date_created,'') AS date_created,
		ISNULL(RE.modified_by,'') AS modified_by,
		ISNULL(RE.date_modified,'') AS date_modified,
		ISNULL(WCR.generator_name,'') AS generator_name,
		ISNULL(WCR.epa_id,'') AS epa_id,
		ISNULL(WCR.epa_id,'') AS generator_epa_id,
		ISNULL(WCR.generator_address1,'') AS generator_address1,
		IIF(ISNULL(generator_address1, '') <> '', (generator_address1 + ', '), '') +
		IIF(ISNULL(generator_address2, '') <> '', (generator_address2 + ', '), '') +
        IIF(ISNULL(generator_city, '') <> '', (generator_city + ', '), '') +
        IIF(ISNULL(generator_state, '') <> '', (generator_state + ', '), '') +
        IIF(ISNULL(gen_mail_zip, '') <> '', (gen_mail_zip ), '') AS generator_SiteAddress,
		ISNULL(WCR.generator_city,'') AS generator_city,
		ISNULL(WCR.generator_state,'') AS generator_state,
		ISNULL(WCR.gen_mail_zip,'') AS gen_mail_zip,
		ISNULL(WCR.signing_name,'') AS signing_name,
		-- REPLACE(ISNULL(CONVERT(datetime2, WCR.signing_date), ''), '1900-01-01', '') as signing_date,
		 ISNULL(WCR.signing_date,'') AS signing_date,
		ISNULL(WCR.signing_title,'') AS signing_title,
		ISNULL(WCR.signing_company,'') AS signing_company,
		ISNULL(uranium_concentration,'') as uranium_concentration,
		ISNULL(convert(varchar(10),radium_226_concentration),'') AS radium_226_concentration,
		ISNULL(convert(varchar(10),radium_228_concentration),'') AS radium_228_concentration,
		ISNULL(convert(varchar(10),lead_210_concentration),'') AS lead_210_concentration,
		ISNULL(convert(varchar(10),potassium_40_concentration),'') AS potassium_40_concentration,
		ISNULL(additional_inventory_flag,'') AS additional_inventory_flag,	
		ISNULL(RE.byproduct_sum_of_all_isotopes,'') AS byproduct_sum_of_all_isotopes,	
		ISNULL(RE.source_sof_calculations,'') AS source_sof_calculations,	
		ISNULL(RE.special_nuclear_sum_of_all_isotopes,'') AS special_nuclear_sum_of_all_isotopes,		
		@section_status AS IsCompleted,
		ISNULL(RE.specifically_exempted_flag, '') as specifically_exempted_flag,
		ISNULL(RE.USEI_WAC_table_C1_flag,'') as USEI_WAC_table_C1_flag, 
		ISNULL(RE.USEI_WAC_table_C2_flag,'') as USEI_WAC_table_C2_flag, 
		ISNULL(RE.USEI_WAC_table_C3_flag,'') as USEI_WAC_table_C3_flag, 
		ISNULL(RE.USEI_WAC_table_C4a_flag,'') as USEI_WAC_table_C4a_flag, 
		ISNULL(RE.USEI_WAC_table_C4b_flag,'') as USEI_WAC_table_C4b_flag, 
		ISNULL(RE.USEI_WAC_table_C4c_flag,'') as USEI_WAC_table_C4c_flag,
		ISNULL(RE.waste_type,'') as waste_type,
	   (SELECT form_id, revision_id, line_id, item_name, total_number_in_shipment, radionuclide_contained, 
	   --disposal_site_tsdf_id
	   ISNULL(convert(varchar(10),activity),'') AS activity, disposal_site_tsdf_code, 
					 (Select TOP 1  tsdF_name FROM TSDF WHERE  tsdF_code = disposal_site_tsdf_code) as tsdF_name,
					 cited_regulatory_exemption, created_by, date_created, modified_by, date_modified
					 FROM FormRadioactiveExempt as RadioactiveExempt
					 WHERE  RadioactiveExempt.form_id = RE.form_id and RadioactiveExempt.revision_id = @revision_id
					 FOR XML AUTO,TYPE,ROOT ('RadioactiveExempt'), ELEMENTS),
       (SELECT form_id, revision_id, line_id, radionuclide,  ISNULL(convert(varchar(10),concentration),'') AS concentration, const_id, sectionEflag, created_by, date_created, modified_by, date_modified
					 FROM FormRadioactiveUSEI as RadioactiveUSEI
					 WHERE  RadioactiveUSEI.form_id = RE.form_id and RadioactiveUSEI.revision_id = @revision_id
					 FOR XML AUTO,TYPE,ROOT ('RadioactiveUSEI'), ELEMENTS)
		--RE.byproduct_material,
		--RE.WAC_limit,
		--RE.source_material
		--RE.special_nuclear_material,
		--RE.sum_of_all_isotopes,
			
			
			
	FROM  FormRadioactive AS RE 	
	JOIN  FormWCR AS WCR ON RE.wcr_id =WCR.form_id AND RE.wcr_rev_id = WCR.revision_id
	WHERE 
		WCR.form_id = @form_id  and  WCR.revision_id = @revision_id 
		FOR XML RAW ('Radioactive'), ROOT ('ProfileModel'), ELEMENTS
END

GO			
	GRANT EXEC ON [dbo].[sp_Radioactive_Select] TO COR_USER;
GO
	
	



	