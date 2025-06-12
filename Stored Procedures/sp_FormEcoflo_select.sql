DROP PROCEDURE IF EXISTS [sp_FormEcoflo_select]
	
GO
	

CREATE PROCEDURE [dbo].[sp_FormEcoflo_select](
	
		 @form_id INT,
		 @revision_id	INT

)
AS
/***********************************************************************************
 
    Updated By    : Nallaperumal C
    Updated On    : 15-october-2023
    Type          : Store Procedure 
    Object Name   : [sp_FormEcoflo_select]
	Ticket		  : 73641
                                                    
    Execution Statement    
	
	EXEC  [dbo].[sp_FormEcoflo_select] @form_id, @revision_id
 
*************************************************************************************/

	BEGIN
		DECLARE @section_status CHAR(1);
		SELECT @section_status =section_status FROM formsectionstatus WHERE form_id=@form_id AND revision_id = @revision_id and section='FB'

			SELECT 
				EF.form_id ,
				EF.revision_id ,
				EF.wcr_id ,
				EF.wcr_rev_id ,
				EF.viscosity_value ,
				EF.total_solids_low ,
				EF.total_solids_high,
				EF.total_solids_description ,
				EF.fluorine_low ,
				EF.fluorine_high ,
				EF.chlorine_low ,
				EF.chlorine_high ,
				EF.bromine_low ,
				EF.bromine_high ,
				EF.iodine_low ,
				EF.iodine_high ,
				EF.created_by ,
				EF.modified_by ,
				EF.date_created ,
				EF.date_modified ,
				EF.total_solids_flag ,
				EF.organic_halogens_flag ,
				EF.fluorine_low_flag ,
				EF.fluorine_high_flag ,
				EF.chlorine_low_flag ,
				EF.chlorine_high_flag ,
				EF.bromine_low_flag ,
				EF.bromine_high_flag ,
				EF.iodine_low_flag ,
				EF.iodine_high_flag 
				FROM  FormEcoflo AS EF
				JOIN  FormWCR AS WCR ON EF.wcr_id =WCR.form_id AND EF.wcr_rev_id = WCR.revision_id
				WHERE 
					WCR.form_id = @form_id  and  WCR.revision_id = @revision_id

					FOR XML RAW ('FuelsBlending'), ROOT ('ProfileModel'), ELEMENTS XSINIL

	END
	
	GO
	GRANT EXEC ON [dbo].[sp_FormEcoflo_select] TO COR_USER;
	GO
	
