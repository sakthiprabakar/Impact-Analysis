
CREATE  PROCEDURE [dbo].[sp_Debris_select](
	
		 @form_id INT,
		 @revision_id	INT
		

)
AS



/* ******************************************************************
  Updated By       : PRABHU
  Updated On date  : 2nd Nov 2019
  Decription       : Details for Pending Profile Debris Waste Streams for Microencapsulation Form Selection
  Type             : Stored Procedure
  Object Name      : [sp_Debris_Select]

  Select Debris Waste Streams for Microencapsulation Supplementary Form columns Values  (Part of form wcr Select and Edit)

  Inputs 
	 Form ID
	 Revision ID
 
  Samples:
	 EXEC [dbo].[sp_Debris_Select] @form_id,@revision_id
	 EXEC [dbo].[sp_Debris_Select] '427534','1'

****************************************************************** */
BEGIN
DECLARE @section_status CHAR(1);
	SELECT @section_status=section_status FROM formsectionstatus WHERE form_id=@form_id and section='DS'
SELECT
			
          COALESCE(Debris.wcr_id, @form_id) as wcr_id,
		  COALESCE(Debris.wcr_rev_id, @revision_id) as wcr_rev_id,
		  ISNULL( WCR.signing_name,'') AS signing_name,
		  ISNULL( WCR.signing_title,'') AS signing_title,
		  ISNULL( WCR.signing_date,'') AS signing_date,
		  ISNULL( Debris.form_id,'') AS form_id,
		  ISNULL( Debris.revision_id,'') AS revision_id,
		  --ISNULL( Debris.wcr_id,'') AS wcr_id,
		  --ISNULL( Debris.wcr_rev_id,'') AS wcr_rev_id,
		  ISNULL( Debris.locked,'') AS locked,
		  ISNULL( Debris.debris_certification_flag,'') AS debris_certification_flag,
		  ISNULL( Debris.created_by,'') AS created_by,
		  ISNULL( Debris.date_created,'') AS date_created,
		  ISNULL( Debris.modified_by,'') AS modified_by,
		  ISNULL( Debris.date_modified,'') AS date_modified
		  ,@section_status AS IsCompleted
		   
		FROM  FormDebris AS Debris 
	 JOIN  FormWCR AS WCR ON Debris.wcr_id = WCR.form_id AND Debris.wcr_rev_id = WCR.revision_id

	WHERE 
          WCR.form_id = @form_id   and  WCR.revision_id = @revision_id
		

	FOR XML RAW ('Debris'), ROOT ('ProfileModel'), ELEMENTS

END

GO

	GRANT EXEC ON [dbo].[sp_Debris_Select] TO COR_USER;

GO
			

		

		
		