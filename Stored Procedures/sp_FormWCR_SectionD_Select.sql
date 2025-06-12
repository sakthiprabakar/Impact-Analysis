
CREATE PROCEDURE [dbo].[sp_FormWCR_SectionD_Select]
     @formId int = 0,
	 @revision_Id INT
AS


/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 11th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_FormWCR_SectionD_Select]


	Procedure to select Section D related fields 

inputs 
	
	@formId
	@revisionId
	


Samples:
 EXEC [sp_FormWCR_SectionD_Select] @formId,@revisionId
 EXEC [sp_FormWCR_SectionD_Select] 498750, 1
 select ignitability_compare_temperature, * from formwcr where form_id=468074
****************************************************************** */

--declare  @formId int = 424875,
--	 @revision_Id INT=1

BEGIN
DECLARE @section_status CHAR(1);

SELECT @section_status= section_status FROM formsectionstatus WHERE form_id=@formId AND section='SD' 

	SELECT   ISNULL(SectionD.odor_strength,' ') AS odor_strength ,ISNULL(SectionD.odor_type_ammonia,' ') AS odor_type_ammonia ,
			ISNULL(SectionD.odor_type_amines,'') AS odor_type_amines ,ISNULL(SectionD.odor_type_mercaptans,'') AS odor_type_mercaptans , 
			ISNULL(SectionD.odor_type_sulfur,'') AS odor_type_sulfur ,ISNULL(SectionD.odor_type_organic_acid,'') AS odor_type_organic_acid ,
			ISNULL(SectionD.odor_type_other,'') AS odor_type_other ,ISNULL(SectionD.consistency_solid,'') AS consistency_solid ,ISNULL(SectionD.consistency_dust,'') AS consistency_dust ,ISNULL(SectionD.consistency_debris,'') AS consistency_debris ,ISNULL(SectionD.consistency_sludge,'') AS consistency_sludge ,ISNULL(SectionD.consistency_liquid,'') AS consistency_liquid ,ISNULL(SectionD.consistency_gas_aerosol,'') AS consistency_gas_aerosol ,ISNULL(SectionD.consistency_varies,'') AS consistency_varies 
			,ISNULL(SectionD.color,'') AS color ,
			CASE WHEN SectionD.color IS NULL THEN '' WHEN SectionD.color LIKE '%:%' THEN LEFT(SectionD.color, CHARINDEX(':', SectionD.color) - 1)  ELSE SectionD.color  END AS PrimaryColor,
			CASE WHEN SectionD.color IS NULL THEN '' WHEN SectionD.color LIKE '%:%' THEN RIGHT(ISNULL(SectionD.color,''),LEN(ISNULL(SectionD.color,''))-CHARINDEX(':',ISNULL(SectionD.color,'')))  ELSE ''  END AS SecondaryColor,
	 
			isnull(SectionD.liquid_phase,'') as liquid_phase ,isnull(SectionD.paint_filter_solid_flag,'') as paint_filter_solid_flag ,isnull(SectionD.incidental_liquid_flag,'') as incidental_liquid_flag ,ISNULL(SectionD.ph_lte_2,'') AS ph_lte_2 ,ISNULL(SectionD.ph_gt_2_lt_5,0) AS ph_gt_2_lt_5 ,ISNULL(SectionD.ph_gte_5_lte_10,0) AS ph_gte_5_lte_10 ,ISNULL(SectionD.ph_gt_10_lt_12_5,0) AS ph_gt_10_lt_12_5 ,ISNULL(SectionD.ph_gte_12_5,'') AS ph_gte_12_5,ISNULL(SectionD.ignitability_compare_symbol,'') AS ignitability_compare_symbol ,
			--ISNULL(SectionD.ignitability_compare_temperature,'') AS 
			SectionD.ignitability_compare_temperature , ISNULL(SectionD.ignitability_lt_90,0) AS ignitability_lt_90 ,ISNULL(SectionD.ignitability_90_139,0) AS ignitability_90_139 ,ISNULL(SectionD.ignitability_140_199,0) AS ignitability_140_199 ,ISNULL(SectionD.ignitability_gte_200,0) AS ignitability_gte_200,
			ISNULL(SectionD.ignitability_does_not_flash,'') AS ignitability_does_not_flash , 
			ISNULL(SectionD.ignitability_flammable_solid,'') AS ignitability_flammable_solid ,
			ISNULL(SectionD.BTU_lt_gt_5000,'') AS BTU_lt_gt_5000,
			ISNULL(LTRIM(RTRIM((SectionD.BTU_per_lb))),'') AS BTU_per_lb,
			ISNULL(SectionD.odor_other_desc,'') AS odor_other_desc,
			ISNULL(SectionD.handling_issue,'') AS handling_issue ,ISNULL(SectionD.handling_issue_desc,'') AS handling_issue_desc ,
			@section_status AS IsCompleted,
	(SELECT form_id, revision_id, ISNULL(comp_description,'') as comp_description, 

	cast(comp_from_pct as varchar) as comp_from_pct,
	cast(comp_to_pct as varchar) as comp_to_pct,
	cast(comp_typical_pct as varchar) as comp_typical_pct,

	--CAST(CAST(comp_from_pct  AS FLOAT) AS bigint)as comp_from_pct,
	--CAST(CAST(comp_to_pct  AS FLOAT) AS bigint)as comp_to_pct,
	--CAST(CAST(comp_typical_pct  AS FLOAT) AS bigint)as comp_typical_pct	
	rowguid, ISNULL(unit,''), sequence_id	
	
	 FROM FormXWCRComposition as Composition
	 WHERE  Composition.form_id = SectionD.form_id AND Composition.revision_id = SectionD.revision_id
	 order by sequence_id
	 FOR XML AUTO,TYPE,ROOT ('Physical_Description'), ELEMENTS)
    FROM FormWCR  AS SectionD
    WHERE SectionD.form_id =  @formId and revision_id = @revision_Id
    FOR XML AUTO, ROOT ('ProfileModel'), ELEMENTS; 

END

GO
	GRANT EXEC ON [dbo].[sp_FormWCR_SectionD_Select] TO COR_USER;
GO
