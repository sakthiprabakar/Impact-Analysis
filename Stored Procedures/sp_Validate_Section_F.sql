GO
DROP PROCEDURE IF EXISTS [sp_Validate_Section_F]
GO

CREATE PROCEDURE  [dbo].[sp_Validate_Section_F]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@Revision_ID int
AS



/* ******************************************************************

	Updated By		: SenthilKumar
	Updated On		: 04th Mar 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Section_F]


	Procedure to validate Section F required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID



Samples:
 EXEC [sp_Validate_Section_F] @form_id,@revision_ID
 EXEC [sp_Validate_Section_F] 902383, 1

****************************************************************** */

BEGIN
	DECLARE @FormStatusFlag varchar(1) = 'Y'

	DECLARE @PartialFlag CHAR(1) = 'P'

	set @FormStatusFlag = (
				 SELECT CASE WHEN ISNULL(explosives,'')='' THEN @PartialFlag
							WHEN ISNULL(react_sulfide,'') = '' THEN @PartialFlag
							WHEN ISNULL(react_sulfide,'') = 'T' AND ISNULL(react_sulfide_ppm,'') = '' THEN @PartialFlag
							WHEN ISNULL(shock_sensitive_waste,'') = '' THEN @PartialFlag
							WHEN ISNULL(react_cyanide,'') = '' THEN @PartialFlag
							WHEN ISNULL(react_cyanide,'') = 'T' AND  ISNULL(react_cyanide_ppm,'') ='' THEN @PartialFlag
							WHEN ISNULL(radioactive,'')='' THEN @PartialFlag
							WHEN ISNULL(reactive_other,'')='' THEN @PartialFlag
							WHEN ISNULL(reactive_other,'') = 'T' AND ISNULL(reactive_other_description,'') = '' THEN @PartialFlag
							WHEN ISNULL(biohazard,'') = '' THEN @PartialFlag
							WHEN ISNULL(contains_pcb,'') = '' THEN @PartialFlag
							WHEN ISNULL(dioxins_or_furans,'') = '' THEN @PartialFlag
							WHEN ISNULL(metal_fines_powder_paste,'')='' THEN @PartialFlag
							WHEN ISNULL(pyrophoric_waste,'')='' THEN @PartialFlag
							WHEN ISNULL(temp_control,'')='' THEN @PartialFlag
							WHEN ISNULL(thermally_unstable,'')='' THEN @PartialFlag
							WHEN ISNULL(biodegradable_sorbents,'')=''  THEN @PartialFlag
							WHEN ISNULL(compressed_gas,'')=''  THEN @PartialFlag
							WHEN ISNULL(used_oil,'')='' THEN @PartialFlag
							WHEN ISNULL(oxidizer,'')='' THEN @PartialFlag
							WHEN ISNULL(tires,'')='' THEN @PartialFlag
							WHEN ISNULL(organic_peroxide,'')='' THEN @PartialFlag
							WHEN ISNULL(beryllium_present,'')='' THEN @PartialFlag
							WHEN ISNULL(asbestos_flag,'')='' THEN @PartialFlag
							WHEN ISNULL(asbestos_flag,'')='T' AND ISNULL(asbestos_friable_flag,'')='' THEN @PartialFlag
							WHEN ISNULL(PFAS_Flag,'')='' THEN @PartialFlag
							WHEN ISNULL(ammonia_flag,'')='' THEN @PartialFlag
							WHEN ISNULL(hazardous_secondary_material,'')='' THEN @PartialFlag
							WHEN ISNULL(hazardous_secondary_material,'')='T' 
									AND hazardous_secondary_material_cert <> 'T' THEN @PartialFlag
							WHEN ISNULL(pharma_waste_subject_to_prescription,'')='' THEN @PartialFlag
							ELSE @FormStatusFlag END
				 FROM FormWCR WHERE form_id=@formid and revision_id=@Revision_ID)


	-- Update the form status in FormSectionStatus table
	IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE FORM_ID =@formid AND SECTION ='SF'))
	BEGIN
		INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'SF',@FormStatusFlag,getdate(),1,getdate(),1,1)
	END
	ELSE 
	BEGIN
		UPDATE FormSectionStatus SET section_status = @FormStatusFlag WHERE FORM_ID = @formid AND SECTION = 'SF'
	END	
END

GO

GRANT EXEC ON [dbo].[sp_Validate_Section_F] TO COR_USER;

GO