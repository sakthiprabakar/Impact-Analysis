USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [sp_certification_select]
GO
CREATE PROCEDURE [dbo].[sp_certification_select](
	
		 @form_id INT,
		 @revision_id	INT
		 --@wcr_id  INT,
   --      @wcr_rev_id INT

)
AS



/* ******************************************************************
  Updated By       : Prabhu
  Updated On date  : 2nd Nov 2019
  Decription       : Details for Pending Profile Certification Form 
  Type             : Stored Procedure
  Object Name      : [sp_certification_Select]

  Select Certification Supplementary Form columns Values  (Part of form wcr Select and Edit)
  
  Inputs:
	 Form ID
	 Revision ID 
  Samples:
	 EXEC [dbo].[sp_certification_Select] @form_id,@revision_id
	 EXEC [dbo].[sp_certification_Select] '427709','1'
****************************************************************** */
BEGIN
DECLARE @section_status CHAR(1);
	SELECT @section_status=section_status 
		FROM formsectionstatus 
		WHERE form_id=@form_id AND section='CN'

	SELECT
		COALESCE(WC.wcr_id, @form_id) AS wcr_id,
		COALESCE(WC.wcr_rev_id, @revision_id) AS wcr_rev_id,
		WC.form_id,
		WC.revision_id,
		WC.locked,
		WC.vsqg_cesqg_accept_flag,
		WC.created_by,
		WC.date_created,
		WC.date_modified,
		WC.modified_by,
		WCR.generator_name,
		WCR.generator_address1,
		WCR.generator_address2,
		WCR.generator_address3,
		WCR.generator_address4,
		WCR.generator_city,
		WCR.generator_state,
		WCR.generator_zip,
		WCR.signing_title,
		WCR.signing_name,
		WCR.signing_company,
		WCR.signing_date ,
		@section_status AS IsCompleted
		FROM  FormVSQGCESQG AS WC 
		JOIN  FormWCR AS WCR ON WC.wcr_id = WCR.form_id AND WC.wcr_rev_id = WCR.revision_id
		WHERE WCR.form_id = @form_id AND  WCR.revision_id = @revision_id
		FOR XML RAW ('certification'), ROOT ('ProfileModel'), ELEMENTS

END


GO	    
GRANT EXEC ON [dbo].[sp_certification_Select] TO COR_USER;
GO