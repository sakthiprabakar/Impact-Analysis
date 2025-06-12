
--EXEC sp_Select_Section_B  432217 ,1
CREATE  PROCEDURE [dbo].[sp_FormWCR_SectionB_Select]
	@formId int = 0,
	@revision_Id INT
AS
/* ******************************************************************

	Type			: Stored Procedure
	Object Name		: [sp_FormWCR_SectionB_Select]


	Procedure to select Section B related fields 

inputs 
	
	@formId
	@revisionId
	


Samples:
 EXEC [sp_FormWCR_SectionB_Select] @formId,@revisionId
 EXEC [sp_FormWCR_SectionB_Select] 430235, 1

****************************************************************** */
BEGIN
DECLARE @section_status CHAR(1);

SELECT @section_status= section_status FROM formsectionstatus WHERE form_id=@formId AND revision_id =@revision_Id AND section='SB'

	SELECT ISNULL(waste_common_name,'') as waste_common_name,ISNULL(gen_process,'') as gen_process,ISNULL(EPA_source_code,'') as EPA_source_code ,ISNULL(EPA_form_code,'') AS EPA_form_code ,@section_status AS IsCompleted  from FormWCR  
	 where form_id = @formId AND revision_id =  @revision_Id
	FOR XML RAW ('SectionB'), ROOT ('ProfileModel'), ELEMENTS
END
	GO




	GRANT EXEC ON [dbo].[sp_FormWCR_SectionB_Select] TO COR_USER;
	GO


--select top 1 
--waste_common_name,
--gen_process,
--EPA_source_code,
--EPA_form_code 
--from formwcr


