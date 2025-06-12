
CREATE PROCEDURE [dbo].[sp_pharmaceutical_select](
	
		 @form_id INT,
		 @revision_id	INT

)
AS

/* ******************************************************************
  Updated By       : PRABHU
  Updated On date  : 2nd Nov 2019
  Decription       : Details for Pending Profile Pharmaceutical  Form Selection
  Type             : Stored Procedure
  Object Name      : [sp_pharmaceutical_Select]

  Select Pharmaceutical Supplementary Form columns Values  (Part of form wcr Select and Edit)

  Inputs 
	 Form ID
	 Revision ID
 
  Samples:
	 EXEC [dbo].[sp_pharmaceutical_Select] @form_id,@revision_id
	 EXEC [dbo].[sp_pharmaceutical_Select] '465123','1'

****************************************************************** */

BEGIN

DECLARE @section_status CHAR(1);
	SELECT @section_status =section_status FROM formsectionstatus WHERE form_id=@form_id and section='PL'

DECLARE @signing_title NVARCHAR(50), 
		@signing_company NVARCHAR(50), 
		@signing_name NVARCHAR(50),
		@signature VARCHAR(30),
		@signing_date DATETIME

	SELECT @signing_title = WCR.signing_title,
		   @signing_name = WCR.signing_name,
		   @signing_date = WCR.signing_date,
		   @signing_company = WCR.signing_company
	  FROM FormWCR WCR WHERE form_id = @form_id AND revision_id = @revision_id


SELECT
			COALESCE(pharmaceutical.wcr_id, @form_id) AS wcr_id,
			COALESCE(pharmaceutical.wcr_rev_id, @revision_id) AS wcr_rev_id,
			ISNULL(pharmaceutical.form_id,'') AS form_id,
			ISNULL(pharmaceutical.revision_id,'') AS revision_id,
			ISNULL(pharmaceutical.locked,'') AS locked,
			ISNULL(pharmaceutical.pharm_certification_flag,'') AS pharm_certification_flag,
			ISNULL(pharmaceutical.created_by,'') AS created_by,
			ISNULL(pharmaceutical.date_created,'') AS date_created,
			ISNULL(pharmaceutical.date_modified,'') AS date_modified,
			ISNULL(pharmaceutical.modified_by,'') AS modified_by,
			@section_status AS IsCompleted,
			ISNULL(@signing_title, '') as signing_title,
			ISNULL(@signing_name, '') as signing_name,
			ISNULL(@signing_date, '') as signing_date,
			ISNULL(@signing_company, '') as signing_company			

	 FROM  FormPharmaceutical  as pharmaceutical

	WHERE 

		 wcr_id = @form_id and wcr_rev_id = @revision_ID

		FOR XML AUTO, ROOT ('ProfileModel'), ELEMENTS;

END

GO
		GRANT EXEC ON [dbo].[sp_pharmaceutical_select] TO COR_USER;
GO

		


		    
			

		