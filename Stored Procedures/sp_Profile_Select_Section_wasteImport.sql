USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Profile_Select_Section_wasteImport]    Script Date: 08-12-2021 10:20:41 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_Profile_Select_Section_wasteImport](
	
		@profileId INT

)
AS

/***********************************************************************************
 
    Updated By    : Prabhu
    Updated On    : 24-Dec-2018
    Type          : Store Procedure 
    Object Name   : [sp_Profile_Select_Section_wasteImport]
 
    Description    :  Procedure to get wasteImport profile details
                   
 
    Input       
	
	@profileid
                                                                
    Execution Statement    
	
	EXEC  [dbo].[sp_Profile_Select_Section_wasteImport] 893442
    EXEC  [dbo].[sp_Profile_Select_Section_wasteImport] 699518
*************************************************************************************/
BEGIN
Declare @profile_id int



SELECT
                case when PWI.foreign_exporter_sameas_generator = 'T' then isnull(g.generator_name, '') else isnull(foreign_exporter_name,'') end as foreign_exporter_name,
				case when PWI.foreign_exporter_sameas_generator = 'T' then isnull(g.generator_address_1, '') else isnull(foreign_exporter_address,'') end as foreign_exporter_address,
				case when PWI.foreign_exporter_sameas_generator = 'T' then isnull(g.generator_city,'') else isnull(foreign_exporter_city,'') end  as foreign_exporter_city,
				case when PWI.foreign_exporter_sameas_generator = 'T' then isnull(g.generator_state,'') else isnull(foreign_exporter_province_territory,'') end as foreign_exporter_province_territory,	
				case when PWI.foreign_exporter_sameas_generator = 'T' then isnull(g.generator_zip_code,'') else isnull(foreign_exporter_mail_code,'') end as foreign_exporter_mail_code,
				case when PWI.foreign_exporter_sameas_generator = 'T' then isnull(g.gen_mail_country,'') else isnull(foreign_exporter_country,'') end as foreign_exporter_country,
				--ISNULL( PWI.foreign_exporter_name,'') AS foreign_exporter_name,
			 --   ISNULL( PWI.foreign_exporter_address,'') AS foreign_exporter_address,
				--ISNULL(PWI.foreign_exporter_city, '') as foreign_exporter_city,
    --            ISNULL(PWI.foreign_exporter_province_territory, '') as foreign_exporter_province_territory,
    --            ISNULL(PWI.foreign_exporter_mail_code, '') as foreign_exporter_mail_code,
    --            ISNULL(PWI.foreign_exporter_country, '') as foreign_exporter_country,
				ISNULL( PWI.foreign_exporter_contact_name,'') AS foreign_exporter_contact_name,
				ISNULL( PWI.foreign_exporter_phone,'') AS foreign_exporter_phone,
				ISNULL( PWI.foreign_exporter_fax,'') AS foreign_exporter_fax,
				ISNULL( PWI.foreign_exporter_email,'') AS foreign_exporter_email,
				ISNULL( PWI.epa_notice_id,'') AS epa_notice_id,
				ISNULL( PWI.epa_consent_number,'') AS epa_consent_number,
				ISNULL( PWI.effective_date,'') AS effective_date,
				ISNULL( PWI.expiration_date,'') AS expiration_date,
				ISNULL( PWI.approved_volume,'') AS approved_volume,
				ISNULL( PWI.approved_volume_unit,'') AS approved_volume_unit,
				ISNULL( PWI.importing_generator_id,'') AS importing_generator_id,
				ISNULL( PWI.importing_generator_name,'') AS importing_generator_name,
				ISNULL( PWI.importing_generator_address,'') AS importing_generator_address,
			    ISNULL( PWI.importing_generator_city,'') AS importing_generator_city,
				ISNULL( PWI.importing_generator_province_territory,'') AS importing_generator_province_territory,
				ISNULL( PWI.importing_generator_mail_code,'') AS importing_generator_mail_code,
				ISNULL( PWI.importing_generator_epa_id,'') AS importing_generator_epa_id,
				ISNULL( PWI.tech_contact_id,'') AS tech_contact_id,
				ISNULL( PWI.tech_contact_name,'') AS tech_contact_name,
				ISNULL( PWI.tech_contact_phone,'') AS tech_contact_phone,
				ISNULL( PWI.tech_cont_email,'') AS tech_cont_email,
				ISNULL( PWI.tech_contact_fax,'') AS tech_contact_fax,
				ISNULL( PWI.created_by,'') AS created_by,
				ISNULL( PWI.date_created,'') AS date_created,
				ISNULL( PWI.modified_by,'') AS modified_by,
				ISNULL( PWI.date_modified,'') AS date_modified,
				ISNULL(PWI.foreign_exporter_sameas_generator,'') AS foreign_exporter_sameas_generator,(SELECT *
				FROM ProfileWasteCode as WasteCodes
				WHERE  WasteCodes.profile_Id = PWI.profile_Id
				FOR XML AUTO,TYPE,ROOT ('WasteCodeList'), ELEMENTS)
  		
	FROM  ProfileWasteImport AS PWI 
	join profile p on p.profile_id = pwi.profile_id
	JOIN generator g on g.generator_id = p.generator_id
	WHERE 
		pwi.profile_Id = @profileId 
	    FOR XML RAW ('wasteImport'), ROOT ('ProfileModel'), ELEMENTS
END

GO



GRANT EXECUTE ON [dbo].[sp_Profile_Select_Section_wasteImport] TO COR_USER;



GO