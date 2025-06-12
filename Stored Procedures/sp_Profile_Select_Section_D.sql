CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_D]
     @profileId int 
AS

-- 

/***********************************************************************************

	Author		: SathickAli
	Updated On	: 20-Dec-2018
	Type		: Store Procedure 
	Object Name	: [dbo].[sp_Profile_Select_Section_D]

	Description	: 
                  Procedure to get Section D profile details 

	Input		:
				@profileid
																
	Execution Statement	: EXEC [plt_ai].[dbo].[sp_Profile_Select_Section_D] 643665

*************************************************************************************/
BEGIN
	
	DECLARE @consistency_solid nvarchar(1),
	@consistency_dust nvarchar(1), 
	@consistency_debris nvarchar(1), 
	@consistency_sludge nvarchar(1), 
	@consistency_liquid nvarchar(1), 
	@consistency_gas_aerosol nvarchar(1), 
	@consistency_varies nvarchar(1)

	Select @consistency_solid=(CASE WHEN count(*) > 0 THEN 'T' ELSE 'E' END) from ProfileLab where  profile_id=@profileId and type='A' and consistency like '%SOLID%'
	Select @consistency_dust=(CASE WHEN count(*) > 0 THEN 'T' ELSE 'E' END) from ProfileLab where  profile_id=@profileId and type='A' and consistency like '%DUST/POWDER%'
	Select @consistency_debris=(CASE WHEN count(*) > 0 THEN 'T' ELSE 'E' END) from ProfileLab where  profile_id=@profileId and type='A' and consistency like '%DEBRIS%'
	Select @consistency_sludge=(CASE WHEN count(*) > 0 THEN 'T' ELSE 'E' END) from ProfileLab where  profile_id=@profileId and type='A' and consistency like '%SLUDGE%'
	Select @consistency_liquid=(CASE WHEN count(*) > 0 THEN 'T' ELSE 'E' END) from ProfileLab where  profile_id=@profileId and type='A' and consistency like '%LIQUID%'
	Select @consistency_gas_aerosol=(CASE WHEN count(*) > 0 THEN 'T' ELSE 'E' END) from ProfileLab where  profile_id=@profileId and type='A' and consistency like '%GAS/AEROSOL%'
	Select @consistency_varies=(CASE WHEN count(*) > 0 THEN 'T' ELSE 'E' END) from ProfileLab where  profile_id=@profileId and type='A' and consistency like '%VARIES%'



--SELECT(
	SELECT  
    ISNULL(SectionD.odor_strength,' ') AS odor_strength ,
	ISNULL(SectionD.odor_type_ammonia,' ') AS odor_type_ammonia ,
	ISNULL(SectionD.odor_type_amines,'') AS odor_type_amines ,
	ISNULL(SectionD.odor_type_mercaptans,'') AS odor_type_mercaptans ,
	 ISNULL(SectionD.odor_type_sulfur,'') AS odor_type_sulfur ,
	 ISNULL(SectionD.odor_type_organic_acid,'') AS odor_type_organic_acid ,
	 ISNULL(SectionD.odor_type_other,'') AS odor_type_other ,
	 ISNULL(SectionD.odor_other_desc,'') AS odor_other_desc ,
	 ISNULL(@consistency_solid ,'') AS consistency_solid  ,
	 ISNULL(@consistency_dust ,'') AS consistency_dust  ,
	 ISNULL(@consistency_debris ,'') AS consistency_debris  ,
	 ISNULL(@consistency_sludge ,'') AS consistency_sludge  ,
	 ISNULL(@consistency_liquid ,'') AS consistency_liquid  ,
	 ISNULL(@consistency_gas_aerosol ,'') AS consistency_gas_aerosol  ,
	 ISNULL(@consistency_varies ,'') AS consistency_varies  ,
	 --ISNULL(SectionD.consistency,'') AS consistency_solid,--ISNULL(SectionD.consistency_solid,'') AS consistency_solid ,
	 --ISNULL(SectionD.consistency_dust,'') AS consistency_dust ,
	 --ISNULL(SectionD.consistency_debris,'') AS consistency_debris ,
	 --ISNULL(SectionD.consistency_sludge,'') AS consistency_sludge ,
	 --ISNULL(SectionD.consistency_liquid,'') AS consistency_liquid ,
	 --ISNULL(SectionD.consistency_gas_aerosol,'') AS consistency_gas_aerosol ,
	 --ISNULL(SectionD.consistency_varies,'') AS consistency_varies ,
	 ISNULL(SectionD.color,'') AS color ,
	 ISNULL((select VALUE from fn_StringSplit (SectionD.color, ':') WHERE id = 1), '') as PrimaryColor,
	 ISNULL((select VALUE from fn_StringSplit (SectionD.color, ':') WHERE id = 2), '') as SecondaryColor, 
	 isnull(SectionD.liquid_phase,'') as liquid_phase ,
	 isnull(SectionD.paint_filter_solid_flag,'') as paint_filter_solid_flag ,
	 isnull(SectionD.incidental_liquid_flag,'') as incidental_liquid_flag ,
	 ISNULL(SectionD.ph_lte_2,'') AS ph_lte_2 ,
	 ISNULL(SectionD.ph_gt_2_lt_5,0) AS ph_gt_2_lt_5 ,
	 ISNULL(SectionD.ph_gte_5_lte_10,0) AS ph_gte_5_lte_10 ,
	 ISNULL(SectionD.ph_gt_10_lt_12_5,0) AS ph_gt_10_lt_12_5 ,
	 ISNULL(SectionD.ph_gte_12_5,'') AS ph_gte_12_5,
	 ISNULL(SectionD.ignitability_compare_symbol,'') AS ignitability_compare_symbol ,
	 ISNULL(SectionD.ignitability_compare_temperature,'') AS ignitability_compare_temperature ,
	 ISNULL(SectionD.ignitability_lt_90,0) AS ignitability_lt_90 ,
	 ISNULL(SectionD.ignitability_90_139,0) AS ignitability_90_139 ,
	 ISNULL(SectionD.ignitability_140_199,0) AS ignitability_140_199 ,
	 ISNULL(SectionD.ignitability_gte_200,0) AS ignitability_gte_200,
	 ISNULL(SectionD.ignitability_does_not_flash,'') AS ignitability_does_not_flash ,
	ISNULL(SectionD.ignitability_flammable_solid,'') AS ignitability_flammable_solid ,
	ISNULL(SectionD.handling_issue,'') AS handling_issue ,
	ISNULL(SectionD.handling_issue_desc,'') AS handling_issue_desc ,
	ISNULL(SectionD.BTU_lt_gt_5000,'') AS BTU_lt_gt_5000 ,
	ISNULL(convert(nvarchar(10),SectionD.BTU_per_lb),'') AS BTU_per_lb ,
	(SELECT  ISNULL(comp_description,'') as comp_description, 
	CAST(CAST(comp_from_pct  AS FLOAT) AS bigint)as comp_from_pct,
	CAST(CAST(comp_to_pct  AS FLOAT) AS bigint)as comp_to_pct,
	 ISNULL(unit,''), sequence_id,
	CAST(CAST(comp_typical_pct  AS FLOAT) AS bigint)as comp_typical_pct	
	 FROM ProfileComposition as Composition
	 WHERE  Composition.profile_id = SectionD.profile_id
	 FOR XML AUTO,TYPE,ROOT ('Physical_Description'), ELEMENTS)
    FROM ProfileLab  AS SectionD
    WHERE SectionD.profile_id =  @profileId AND SectionD.[type] = 'A'
    FOR XML AUTO, ROOT ('ProfileModel'), ELEMENTS


END
	 
GO

	GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_D] TO COR_USER;

GO


