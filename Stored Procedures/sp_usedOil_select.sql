
CREATE  PROCEDURE [dbo].[sp_usedOil_select](
	
		 @form_id INT,
		 @revision_id	INT
)
AS
/* ******************************************************************

	Updated By		: PRABHU
	Updated On		: 8th Nov 2018
	Type			: Stored Procedure
	Object Name		: [sp_usedOil_select]


	Procedure used for getting usedOil details for given form id and revision id

inputs 
	
	@formid
	@revision_ID



Samples:
 EXEC [dbo].[sp_usedOil_select] @form_id,@revision_ID
 EXEC  [dbo].[sp_usedOil_select] '-891077','1'

****************************************************************** */
BEGIN	
	DECLARE @section_status CHAR(1);
	SELECT @section_status =section_status FROM formsectionstatus WHERE form_id=@form_id AND revision_id = @revision_id and section='UL'
  SELECT 
		ISNULL(UsedOil.form_id,'') AS form_id,
	    ISNULL(UsedOil.revision_id,'') AS revision_id, 
		ISNULL(UsedOil.wwa_halogen_gt_1000,'') AS wwa_halogen_gt_1000, 
		ISNULL(RTRIM(LTRIM(UsedOil.wwa_halogen_source)),'') AS wwa_halogen_source, 
		ISNULL(UsedOil.wwa_halogen_source_desc1,'') AS wwa_halogen_source_desc1,
		ISNULL(UsedOil.wwa_other_desc_1,'') AS wwa_other_desc_1
		,@section_status AS IsCompleted
	FROM FormWCR as UsedOil

	Where form_id = @form_id and revision_id = @revision_id

	FOR XML AUTO, ROOT ('ProfileModel'), ELEMENTS;
END

GO		

GRANT EXEC ON [dbo].[sp_usedOil_select] TO COR_USER;

GO