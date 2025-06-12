GO
DROP PROCEDURE IF EXISTS [sp_Validate_Profile_Section_F]
GO

CREATE PROCEDURE  [dbo].[sp_Validate_Profile_Section_F]
	-- Add the parameters for the stored procedure here
	@profile_id int

AS



/* ******************************************************************

	Updated By		: Prabhu
	Updated On		: 24th Sep 2021
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_Section_F]


	Procedure to validate Section F required fields and Update the Status of section

inputs 
	
	@profile_id



Samples:
 EXEC [sp_Validate_Profile_Section_F] @profile_id
 EXEC [sp_Validate_Profile_Section_F] 699442

****************************************************************** */

BEGIN
	DECLARE @ProfileStatusFlag varchar(1) = 'Y'

	DECLARE @PartialFlag CHAR(1) = 'P'

	SET @ProfileStatusFlag = 
				(
					SELECT
						CASE 
							WHEN ISNULL(pl.explosives,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.react_sulfide,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.react_sulfide,'')='T' AND ISNULL(pl.react_sulfide_ppm,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.shock_sensitive_waste,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.react_cyanide,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.react_cyanide,'')='T' AND  ISNULL(pl.react_cyanide_ppm,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.radioactive_waste,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.reactive_other,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.reactive_other,'')='T' AND ISNULL(pl.reactive_other_description,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.biohazard,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.contains_pcb,'')=''  THEN @PartialFlag
							WHEN ISNULL(pl.dioxins_or_furans,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.metal_fines,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.pyrophoric_waste,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.temp_ctrl_org_peroxide,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.thermally_unstable,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.biodegradable_sorbents,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.compressed_gas,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.used_oil,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.oxidizer,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.tires,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.organic_peroxide,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.beryllium_present,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.asbestos_flag,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.asbestos_flag,'')='T' AND ISNULL(pl.asbestos_friable_flag,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.PFAS_Flag,'')='' THEN @PartialFlag
							WHEN ISNULL(pl.ammonia_flag,'')='' THEN @PartialFlag
							WHEN ISNULL(p.hazardous_secondary_material,'')='' THEN @PartialFlag
							WHEN ISNULL(p.hazardous_secondary_material,'')='T' AND p.hazardous_secondary_material_cert <>'T' THEN @PartialFlag
							WHEN ISNULL(p.pharmaceutical_flag,'')='' THEN @PartialFlag
							ELSE @ProfileStatusFlag END 					
	FROM [Profile] p 
	JOIN ProfileLab pl ON p.profile_id = pl.profile_id 
	WHERE p.profile_id=@profile_id and pl.type = 'A')
	
	-- Update the form status in FormSectionStatus table
	IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE PROFILE_ID =@profile_id AND SECTION ='SF'))
	BEGIN
		INSERT INTO ProfileSectionStatus VALUES (@profile_id,'SF',@ProfileStatusFlag,getdate(),1,getdate(),1,1)
	END
	ELSE 
	BEGIN
		UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE PROFILE_ID = @profile_id AND SECTION = 'SF'
	END
END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_Section_F] TO COR_USER;
GO