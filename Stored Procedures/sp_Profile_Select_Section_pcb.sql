
CREATE  PROCEDURE [dbo].[sp_Profile_Select_Section_pcb](
	
		 @profileId INT
		 

)
AS

/***********************************************************************************
 
    Updated By    : Prabhu
    Updated On    : 24-Dec-2018
    Type          : Store Procedure 
    Object Name   : [sp_Profile_Select_Section_pcb]
 
  
     Procedure to get pcb profile details
                   
 
    Input       
	
	@profileid
                                                                
    Execution Statement    
	
	EXEC  [dbo].[sp_Profile_Select_Section_pcb] 893442
 
*************************************************************************************/

SELECT
			--ISNULL(PCB.pcb_concentration_0_9,'') AS pcb_concentration_0_9,
            --ISNULL(PCB.pcb_concentration_10_49, '') AS pcb_concentration_10_49,
			ISNULL(PCB.pcb_concentration_50_499, '') AS pcb_concentration_50_499,
			ISNULL(PCB.pcb_concentration_500, '') AS pcb_concentration_500,
            -- ISNULL(pcb_source_contamination_gr_50,'') AS pcb_source_contamination_gr_50,
            --ISNULL(PCB.pcb_regulated_for_disposal_under_TSCA, '') AS pcb_regulated_for_disposal_under_TSCA,
            ISNULL(PCB.processed_into_non_liquid, '') AS processed_into_non_liquid,
			ISNULL(PCB.processd_into_nonlqd_prior_pcb,'') AS processd_into_nonlqd_prior_pcb,
			ISNULL(PCB.pcb_manufacturer, '') AS pcb_manufacturer,
			--ISNULL(PCB.pcb_article_for_TSCA_landfill,'') AS pcb_article_for_TSCA_landfill,
			ISNULL(PCB.pcb_article_decontaminated, '') AS pcb_article_decontaminated                            

	FROM  ProfileLab  as PCB

	WHERE 

		profile_Id = @profileId 

		 
		FOR XML RAW ('pcb'), ROOT ('ProfileModel'), ELEMENTS

GO

GRANT EXEC ON [dbo].[sp_Profile_Select_Section_pcb]  TO COR_USER;
		
			
			

		 
