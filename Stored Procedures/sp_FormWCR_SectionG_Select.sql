USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_FormWCR_SectionG_Select]    Script Date: 10/12/2022 2:48:54 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_FormWCR_SectionG_Select]
     @formId int = 0,
	 @revisionId INT
AS



/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 25th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_FormWCR_SectionG_Select]


	Procedure to select Section G related fields 

inputs 
	
	@formId
	@revisionId
	


Samples:
 EXEC [sp_FormWCR_SectionG_Select] @formId,@revisionId
 EXEC [sp_FormWCR_SectionG_Select] 600115, 1

***********************************************************************/

BEGIN

DECLARE @section_status CHAR(1);

SELECT @section_status= section_status FROM formsectionstatus WHERE form_id=@formId AND revision_id = @revisionId AND  section='SG' 

Declare @waste_water_flag char(1), @meets_alt_soil_treatment_stds char(1), @more_than_50_pct_debris char(1), 
		@waste_meets_ldr_standards char(1), @generator_type_ID char(1), @rcraCount int, @exceedsLdrCount int, @rcra_hazardous_none char(1)

SELECT ISNULL(ccvocgr500,'') AS ccvocgr500 , 
ISNULL(waste_treated_after_generation,'') AS waste_treated_after_generation ,
ISNULL(waste_treated_after_generation_desc,'') AS waste_treated_after_generation_desc ,
ISNULL(waste_water_flag,'') AS waste_water_flag , 
ISNULL(meets_alt_soil_treatment_stds,'') AS meets_alt_soil_treatment_stds ,
ISNULL(more_than_50_pct_debris,'') AS more_than_50_pct_debris,
ISNULL(debris_separated,'') AS debris_separated , 
ISNULL(debris_not_mixed_or_diluted,'') AS debris_not_mixed_or_diluted ,
ISNULL(exceed_ldr_standards,'') AS exceed_ldr_standards , 
ISNULL(waste_meets_ldr_standards,'') AS waste_meets_ldr_standards , 
--ISNULL(ldr_subcategory,'') AS ldr_subcategory , 
ISNULL(subject_to_mact_neshap,'') AS subject_to_mact_neshap , 
neshap_standards_part,
--ISNULL(neshap_standards_part,'') AS neshap_standards_part ,
ISNULL(neshap_subpart,'') AS neshap_subpart  , 
ISNULL(origin_refinery,'') AS origin_refinery ,
@section_status AS IsCompleted,

	(SELECT LDRSubcategory.form_id,LDRSubcategory.revision_id,LDRSubcategory.page_number,LDRSubcategory.manifest_line_item,LDRSubcategory.ldr_subcategory_id,
	(SELECT short_desc FROM LDRSubcategory l where l.subcategory_id = ldr_subcategory_id) as short_desc
	 FROM FormLDRSubcategory as LDRSubcategory
	 WHERE form_id = @formId and revision_id = @revisionId
	 FOR XML AUTO,TYPE,ROOT ('ldr_subcategory'), ELEMENTS)
  from FormWCR 
    where form_id = @formId and revision_id = @revisionId
	FOR XML RAW ('SectionG'), ROOT ('ProfileModel'), ELEMENTS

--SELECT_SECTIONH

END

GO

	GRANT EXEC ON [dbo].[sp_FormWCR_SectionG_Select] TO COR_USER;

GO
