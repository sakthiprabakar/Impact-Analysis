
CREATE PROCEDURE [dbo].[sp_ldr_select](
	
		 @form_id INT,
		 @revision_id	INT
		
)
AS

/***********************************************************************************

	Author		: SathickAli
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_ldr_select]

	Description	: 
                Procedure to get LDR profile details and status (i.e Clean, partial, completed)
				

	Input		:
				@form_id
				@revision_id
				
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_ldr_select] 569914,1

*************************************************************************************/
BEGIN
	DECLARE @section_status CHAR(1);
	SELECT @section_status =section_status FROM formsectionstatus WHERE form_id=@form_id AND revision_id = @revision_id and section='LR'
    SELECT top 1 ISNULL(ldr.generator_id,'') as  generator_id,
				   COALESCE(ldr.wcr_id,@form_id) as wcr_id,
				   COALESCE(ldr.wcr_rev_id,@revision_id) as wcr_rev_id,
				   ISNULL(ldr.generator_name,'') as  generator_name,
				   ISNULL(ldr.generator_epa_id,'') as  generator_epa_id,
				   ISNULL(ldr.manifest_doc_no,'') as  manifest_doc_no,
				   ISNULL(ldr.ldr_notification_frequency ,'') as  ldr_notification_frequency,
				   ISNULL(ldr.waste_managed_id ,'') as  waste_managed_id,
				   ldr.rowguid as  rowguid,
				   ISNULL(ldr.status ,'') as  status,			
				   ISNULL(ldr.locked ,'') as  locked,
				   ISNULL(ldr.date_created ,'') as  date_created,
				   ISNULL(ldr.date_modified ,'') as  date_modified,
				   ISNULL(ldr.created_by ,'') as  created_by,
				   ISNULL(ldr.modified_by ,'') as  modified_by,
				   ISNULL(fwcr.signing_title ,'') as  signing_title,
				   ISNULL(fwcr.signing_date ,'') as  signing_date,
				   ISNULL(fwcr.waste_water_flag ,'') as  waste_water_flag,
				   ISNULL(fwcr.more_than_50_pct_debris ,'') as  more_than_50_pct_debris,
				   ISNULL(fwcr.signing_name ,'') as  signing_name,
				   --ISNULL(fwcr.signing_date ,'') as  signing_date,
				   ISNULL(ldrD.approval_code,'') as  approval_code,
				   ISNULL(ldrD.manifest_line_item,'') as  manifest_line_item,
				    ISNULL(ldrD.constituents_requiring_treatment_flag,'') as  constituents_requiring_treatment_flag,
				   @section_status AS IsCompleted,
				  (SELECT *
					 FROM FormXWasteCode as WasteCode
					 WHERE  WasteCode.form_id = @form_id and revision_id = @revision_id
					 FOR XML AUTO,TYPE,ROOT ('WasteCode'), ELEMENTS),
				 (SELECT ldr_subcategory_id,(SELECT short_desc FROM LDRSubcategory l where l.subcategory_id = ldr_subcategory_id) as short_desc
				    FROM FormLDRSubcategory as LDRSubcategory
				    WHERE  LDRSubcategory.form_id = @form_id and revision_id = @revision_id
				    FOR XML AUTO,TYPE,ROOT ('LDRSubcategory'), ELEMENTS),
				 (SELECT *
				    FROM FormXConstituent as Constituent
				    WHERE  Constituent.form_id = @form_id AND Constituent.UHC='T' and revision_id = @revision_id
				    FOR XML AUTO,TYPE,ROOT ('Constituent'), ELEMENTS),
					 (SELECT *
				    FROM FormXConstituent as Constituent
				    WHERE  Constituent.form_id = @form_id 
					AND revision_id = @revision_id
					--AND Constituent.Exceeds_LDR='T' 
					AND Constituent.requiring_treatment_flag='T' AND Constituent.Specifier='LDR-WO'
				    FOR XML AUTO,TYPE,ROOT ('ExceedConstituent'), ELEMENTS)


	 FROM FormWCR AS  fwcr

	 JOIN FormLDR AS ldr ON ldr.wcr_id =  fwcr.form_id AND ldr.wcr_rev_id = fwcr.revision_id

	 JOIN FormLDRDetail AS ldrD ON ldrD.form_id = ldr.wcr_id AND ldrD.revision_id = ldr.wcr_rev_id

	Where fwcr.form_id = @form_id  and fwcr.revision_id = @revision_id
	
	FOR XML RAW ('LDR'), ROOT ('ProfileModel'), ELEMENTS

END

GO
	
	GRANT EXEC ON [dbo].[sp_ldr_select] TO COR_USER;

GO

			
			
		

		
		