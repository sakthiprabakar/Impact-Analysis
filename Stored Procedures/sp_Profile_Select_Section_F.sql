CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_F]
     @profileid int
AS

/***********************************************************************************

	Author		: SathickAli
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Profile_Select_Section_F]

	Description	: 
                  Procedure to get Section F profile details 

	Input		:
				@profileid
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Profile_Select_Section_F] 643665

*************************************************************************************/
BEGIN
--SELECT(
	SELECT 
	ISNULL(LA.explosives,'') AS explosives , 
	CAST(CAST(LA.react_sulfide_ppm  AS FLOAT) AS bigint)as react_sulfide_ppm,	
	ISNULL(LA.react_sulfide,'') AS react_sulfide,
	ISNULL(LA.shock_sensitive_waste,'') AS shock_sensitive_waste,
	CAST(CAST(LA.react_cyanide_ppm  AS FLOAT) AS bigint)as react_cyanide_ppm,	
	ISNULL(LA.react_cyanide,'') AS react_cyanide,
	ISNULL(LA.radioactive_waste,'') AS radioactive,
	ISNULL(LA.reactive_other_description,'') AS reactive_other_description,
	ISNULL(LA.reactive_other,'') AS reactive_other , 
	ISNULL(LA.biohazard,'') AS biohazard,
	ISNULL(LA.contains_pcb,'') AS contains_pcb,
	ISNULL(LA.dioxins_or_furans, '') AS dioxins_or_furans,
	ISNULL(LA.dioxins, '') AS dioxins,
	ISNULL(LA.furans, '') AS furans,
	ISNULL(LA.metal_fines,'') AS metal_fines_powder_paste,
	ISNULL(LA.pyrophoric_waste,'') AS pyrophoric_waste,
	ISNULL(LA.temp_ctrl_org_peroxide,'') AS temp_control,
	ISNULL(LA.thermally_unstable,'') AS thermally_unstable,
	ISNULL(LA.biodegradable_sorbents,'') AS biodegradable_sorbents,
	ISNULL(LA.compressed_gas,'') AS compressed_gas,
	ISNULL(LA.used_oil,'') AS used_oil,
	ISNULL(LA.oxidizer,'') AS oxidizer,
	ISNULL(LA.tires,'') AS tires ,
	ISNULL(LA.organic_peroxide,'') AS organic_peroxide,
	ISNULL(LA.beryllium_present,'') AS beryllium_present,
	ISNULL(LA.ammonia_flag,'') AS ammonia_flag,
	ISNULL(LA.asbestos_flag,'') AS asbestos_flag,
	ISNULL(LA.asbestos_friable_flag,'') AS asbestos_friable_flag,
	ISNULL(LA.PFAS_Flag,'') AS PFAS_Flag,
	ISNULL(PE.hazardous_secondary_material,'') AS hazardous_secondary_material,
	ISNULL(PE.hazardous_secondary_material_cert,'') AS hazardous_secondary_material_cert,
	ISNULL(PE.pharmaceutical_flag,'') AS pharma_waste_subject_to_prescription
	FROM  ProfileLab AS LA
	JOIN  Profile AS PE ON LA.profile_id =PE.profile_id
	 where 	 PE.profile_id =  @profileid AND LA.[type] = 'A'	 
	 FOR XML RAW ('SectionF'), ROOT ('ProfileModel'), ELEMENTS

END
	
GO

	GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_F] TO COR_USER;

GO