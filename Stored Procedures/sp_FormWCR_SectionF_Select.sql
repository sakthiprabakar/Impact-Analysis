
CREATE PROCEDURE [dbo].[sp_FormWCR_SectionF_Select]
     @formId int = 0,
	 @revision_Id int
AS


/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 25th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_FormWCR_SectionF_Select]


	Procedure to select Section F related fields 

inputs 
	
	@formId
	@revisionId
	


Samples:
 EXEC [sp_FormWCR_SectionF_Select] @formId,@revisionId
 EXEC [sp_FormWCR_SectionF_Select] 502253, 1

****************************************************************** */

BEGIN


DECLARE @section_status CHAR(1);

SELECT @section_status= section_status FROM formsectionstatus WHERE form_id=@formId AND section='SF' 
	SELECT 
	ISNULL(explosives,'') AS explosives , 
	ISNULL(convert(nvarchar(30), react_sulfide_ppm),'') AS react_sulfide_ppm,
	ISNULL(react_sulfide,'') AS react_sulfide,
	ISNULL(shock_sensitive_waste,'') AS shock_sensitive_waste,
	ISNULL(convert(nvarchar(30), react_cyanide_ppm),'') AS react_cyanide_ppm,	
	ISNULL(react_cyanide,'') AS react_cyanide,
	ISNULL(radioactive,'') AS radioactive,
	ISNULL(reactive_other_description,'') AS reactive_other_description,
	ISNULL(reactive_other,'') AS reactive_other , 
	ISNULL(biohazard,'') AS biohazard,
	ISNULL(contains_pcb,'') AS contains_pcb,
	ISNULL(dioxins_or_furans, '') AS dioxins_or_furans,
	ISNULL(metal_fines_powder_paste,'') AS metal_fines_powder_paste,
	ISNULL(pyrophoric_waste,'') AS pyrophoric_waste,
	ISNULL(temp_control,'') AS temp_control,
	ISNULL(thermally_unstable,'') AS thermally_unstable,
	ISNULL(biodegradable_sorbents,'') AS biodegradable_sorbents,
	ISNULL(compressed_gas,'') AS compressed_gas,
	ISNULL(used_oil,'') AS used_oil,
	ISNULL(oxidizer,'') AS oxidizer,
	ISNULL(tires,'') AS tires ,
	ISNULL(organic_peroxide,'') AS organic_peroxide,
	ISNULL(beryllium_present,'') AS beryllium_present,
	ISNULL(asbestos_flag,'') AS asbestos_flag,
	ISNULL(asbestos_friable_flag,'') AS asbestos_friable_flag,
	ISNULL(hazardous_secondary_material,'') AS hazardous_secondary_material,
	ISNULL(hazardous_secondary_material_cert,'') AS hazardous_secondary_material_cert,
	ISNULL(pharma_waste_subject_to_prescription,'') AS pharma_waste_subject_to_prescription,
	ISNULL(ammonia_flag,'') as ammonia_flag,
	ISNULL(section_F_none_apply_flag, '') as section_F_none_apply_flag,
	ISNULL(PFAS_Flag, '') as PFAS_Flag,
	@section_status AS IsCompleted
	 from FormWCR 
	 where form_id = @formId AND revision_id = @revision_Id
	 FOR XML RAW ('SectionF'), ROOT ('ProfileModel'), ELEMENTS

END


GO

	GRANT EXEC ON [dbo].[sp_FormWCR_SectionF_Select] TO COR_USER;

GO