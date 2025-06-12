USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Profile_Select_Section_G]    Script Date: 10/13/2022 11:59:49 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER  PROCEDURE [dbo].[sp_Profile_Select_Section_G]
     @profileid int

AS

/***********************************************************************************

	Author		: SathickAli
	Updated On	: 5-Jan-2019
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Profile_Select_Section_G]

	Description	: 
                  Procedure to get Section G profile details 

	Input		:
				@profileid
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Profile_Select_Section_G] 638840

*************************************************************************************/
BEGIN


Declare @waste_water_flag char(1), @meets_alt_soil_treatment_stds char(1), @more_than_50_pct_debris char(1), 
		@waste_meets_ldr_standards char(1), @generator_type_ID char(1), @rcraCount int, @exceedsLdrCount int, @rcra_hazardous_none char(1)

	SELECT 
	ISNULL(PL.ccvocgr500,'') AS ccvocgr500 , 
	ISNULL(PL.meets_alt_soil_treatment_stds,'') AS meets_alt_soil_treatment_stds ,
	ISNULL(PL.more_than_50_pct_debris,'') AS more_than_50_pct_debris,
	ISNULL(PL.subject_to_mact_neshap,'') AS subject_to_mact_neshap ,
	ISNULL(PL.neshap_standards_part,'') AS neshap_standards_part ,
    ISNULL(PL.neshap_subpart,'') AS neshap_subpart  ,
	ISNULL(PE.waste_treated_after_generation,'') AS waste_treated_after_generation ,
	ISNULL(PE.waste_treated_after_generation_desc,'') AS waste_treated_after_generation_desc ,
	ISNULL(PE.waste_water_flag,'') AS waste_water_flag , 
	ISNULL(PE.debris_separated,'') AS debris_separated ,
	ISNULL(PE.debris_not_mixed_or_diluted,'') AS debris_not_mixed_or_diluted ,
	CASE 
		WHEN PE.exceed_ldr_standards='T' THEN 'F'
		WHEN PE.exceed_ldr_standards='F' THEN 'T'
		ELSE ISNULL(PE.exceed_ldr_standards,'')
	END	AS exceed_ldr_standards,
	ISNULL(waste_meets_ldr_standards,'') as waste_meets_ldr_standards,
	--ISNULL(PE.exceed_ldr_standards,'') AS exceed_ldr_standards , 
	ISNULL(PE.ldr_subcategory,'') AS ldr_subcategory1 , 
    ISNULL(PE.origin_refinery,'') AS origin_refinery,
	
	(SELECT 
			ISNULL(LDRSubcategory.Profile_id,'') as Profile_id,
			ISNULL(LDRSubcategory.ldr_subcategory_id,'') as ldr_subcategory_id,
			ISNULL((SELECT short_desc FROM LDRSubcategory l where l.subcategory_id = ldr_subcategory_id),'') as short_desc
	FROM 
		plt_ai..ProfileLDRSubcategory LDRSubcategory 
	where profile_id=@profileid
	FOR XML AUTO,TYPE,ROOT ('ldr_subcategory'), ELEMENTS)

    
	 FROM  ProfileLab AS PL

	JOIN  Profile AS PE ON PL.profile_id =PE.profile_id
	
	 where 	 PL.profile_id =  @profileid AND PL.[type] = 'A'
	 
	FOR XML RAW ('SectionG'), ROOT ('ProfileModel'), ELEMENTS
	

--SELECT_SECTIONH

END

GO

	GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_G] TO COR_USER;

GO