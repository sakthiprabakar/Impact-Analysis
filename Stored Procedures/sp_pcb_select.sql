
CREATE  PROCEDURE [dbo].[sp_pcb_select](
	
		 @form_id INT,
		 @revision_id	INT
		 --@wcr_id  INT,
         --@wcr_rev_id INT

)
AS
/* ******************************************************************
  Updated By       : PRABHU
  Updated On date  : 2nd Nov 2019
  Decription       : Details for Pending Profile PCB Supplement Form Selection
  Type             : Stored Procedure
  Object Name      : [sp_pcb_Select]

  Select PCB Supplement Form columns Values  (Part of form wcr Select and Edit)

  Inputs 
	 Form ID
	 Revision ID
 
  Samples:
	 EXEC [dbo].[sp_pcb_Select] @form_id,@revision_id
	 EXEC [dbo].[sp_pcb_Select] '427709','1'

****************************************************************** */

BEGIN

DECLARE @section_status CHAR(1);
	SELECT @section_status =section_status FROM formsectionstatus WHERE form_id=@form_id AND revision_id = @revision_id and section='PB'
SELECT
			ISNULL(PCB.form_id,'') AS form_id,
			ISNULL(PCB.revision_id,'') AS revision_id,
			ISNULL(PCB.pcb_concentration_0_9,'') AS pcb_concentration_0_9,
            ISNULL(PCB.pcb_concentration_10_49, '') AS pcb_concentration_10_49,
			ISNULL(PCB.pcb_concentration_50_499, '') AS pcb_concentration_50_499,
			ISNULL(PCB.pcb_concentration_500, '') AS pcb_concentration_500,
            ISNULL(pcb_source_concentration_gr_50,'') AS pcb_source_concentration_gr_50,
            ISNULL(PCB.pcb_regulated_for_disposal_under_TSCA, '') AS pcb_regulated_for_disposal_under_TSCA,
            ISNULL(PCB.processed_into_non_liquid, '') AS processed_into_non_liquid,
			ISNULL(PCB.processd_into_nonlqd_prior_pcb,'') AS processd_into_nonlqd_prior_pcb,
			ISNULL(PCB.pcb_manufacturer, '') AS pcb_manufacturer,
			ISNULL(PCB.pcb_article_for_TSCA_landfill,'') AS pcb_article_for_TSCA_landfill,
			ISNULL(PCB.pcb_article_decontaminated, '') AS pcb_article_decontaminated                            
			,@section_status AS IsCompleted
	FROM  FormWCR  as PCB

	WHERE 

		form_id = @form_id and  revision_id = @revision_id

		 
		FOR XML AUTO, ROOT ('ProfileModel'), ELEMENTS;

END
GO

		GRANT EXEC ON [dbo].[sp_pcb_select] TO COR_USER;

GO




			
			

		 