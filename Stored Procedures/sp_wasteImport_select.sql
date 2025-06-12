
CREATE PROCEDURE [dbo].[sp_wasteImport_select](
	
		 @form_id INT,
		 @revision_id	INT
	
)
AS

/* ******************************************************************

	Updated By		: PRABHU
	Updated On		: 8th Nov 2018
	Type			: Stored Procedure
	Object Name		: [sp_wasteImport_select]


	Procedure used for getting wasteImport  details for given form id and revision id

inputs 
	
	@formid
	@revision_ID



Samples:
 EXEC [dbo].[sp_wasteImport_select] @form_id,@revision_ID
 EXEC [dbo].[sp_wasteImport_Select] '428898','1'

****************************************************************** */


--SELECT   

--		    ISNULL(WCR.generator_name ,'') AS generator_name,
--			ISNULL(WCR.generator_address1 ,'') AS generator_address1,
--			ISNULL(WCR.generator_address2,'') AS generator_address2,
--			ISNULL(WCR.generator_address3 ,'') AS generator_address3,
--			ISNULL(WCR.generator_address4 ,'') AS generator_address4,
--			ISNULL(WCR.generator_city ,'') AS generator_city,
--			ISNULL(WCR.generator_state ,'') AS generator_state,
--			ISNULL(WCR.gen_mail_zip ,'') AS gen_mail_zip,
--			ISNULL(WCR.gen_mail_country ,'') AS gen_mail_country,
--			ISNULL(WCR.generator_contact ,'') AS generator_contact,
--			ISNULL(WCR.generator_phone ,'') AS generator_phone,
--			ISNULL(WCR.generator_fax ,'') AS generator_fax,
--			ISNULL(WCR.generator_email ,'') AS generator_email,
--			ISNULL(WCR.waste_common_name ,'') AS waste_common_name,
--			ISNULL(WCR.signing_title , '') AS signing_title,
--			ISNULL(WCR.signing_name ,'') AS signing_name,
--			ISNULL(WCR.signing_date,	'') AS signing_date,	
--    (SELECT *
--	 FROM  FormWasteImport 
--	 WHERE  FormWasteImport.form_id = WCR.form_id
--	  FOR XML AUTO,TYPE,ROOT ('WasteImport'), ELEMENTS),
--	 (SELECT *
--	 FROM FormXWasteCode as WasteCode
--	 WHERE  WasteCode.form_id = WCR.form_id
--	 FOR XML AUTO,TYPE,ROOT ('WasteCodeList'), ELEMENTS)

--FROM FormWCR AS WCR

--	Where WCR.form_id = @form_id  and WCR.revision_id = @revision_id 
--	FOR XML RAW ('wasteImport'), ROOT ('ProfileModel'), ELEMENTS
BEGIN	
	DECLARE @section_status CHAR(1);
	SELECT @section_status =section_status FROM formsectionstatus WHERE form_id=@form_id AND revision_id = @revision_id and section='WI'
	
SELECT   
			
		    ISNULL(WCR.generator_name ,'') AS generator_name,
			ISNULL(WCR.generator_address1 ,'') AS generator_address1,
			ISNULL(WCR.generator_address2,'') AS generator_address2,
			ISNULL(WCR.generator_address3 ,'') AS generator_address3,
			ISNULL(WCR.generator_address4 ,'') AS generator_address4,
			ISNULL(WCR.generator_city ,'') AS generator_city,
			ISNULL(WCR.generator_state ,'') AS generator_state,
			ISNULL(WCR.gen_mail_zip ,'') AS gen_mail_zip,
			ISNULL(WCR.gen_mail_country ,'') AS gen_mail_country,
			ISNULL(WCR.tech_contact_name ,'') AS generator_contact,
			ISNULL(WCR.generator_phone ,'') AS generator_phone,
			ISNULL(WCR.generator_fax ,'') AS generator_fax,
			ISNULL(WCR.generator_email ,'') AS generator_email,
			ISNULL(WCR.waste_common_name ,'') AS waste_common_name,
			ISNULL(WCR.signing_title , '') AS signing_title,
			ISNULL(WCR.signing_name ,'') AS signing_name,
			ISNULL(WCR.signing_date,	'') AS signing_date,
			ISNULL(FW.form_id, '') as form_id,
			ISNULL(FW.revision_id, '') as revision_id,
			COALESCE(FW.wcr_id, @form_id) AS wcr_id,
		    COALESCE(FW.wcr_rev_id, @revision_id) AS wcr_rev_id,

			ISNULL(FW.locked, '') as locked,
			case when fw.foreign_exporter_sameas_generator = 'T' then isnull(WCR.generator_name, '') else isnull(fw.foreign_exporter_name,'') end as foreign_exporter_name,
		    case when fw.foreign_exporter_sameas_generator = 'T' then isnull(WCR.generator_address1, '') else isnull(fw.foreign_exporter_address,'') end as foreign_exporter_address,
		    case when fw.foreign_exporter_sameas_generator = 'T' then isnull(WCR.generator_city,'') else isnull(fw.foreign_exporter_city,'') end  as foreign_exporter_city,
			case when fw.foreign_exporter_sameas_generator = 'T' then isnull(WCR.generator_state,'') else isnull(fw.foreign_exporter_province_territory,'') end as foreign_exporter_province_territory,	
			case when fw.foreign_exporter_sameas_generator = 'T' then isnull(WCR.generator_zip,'') else isnull(fw.foreign_exporter_mail_code,'') end as foreign_exporter_mail_code,
			case when fw.foreign_exporter_sameas_generator = 'T' then isnull(WCR.gen_mail_country,'') else isnull(fw.foreign_exporter_country,'') end as foreign_exporter_country,
			--ISNULL(FW.foreign_exporter_name, '') as foreign_exporter_name,
			--ISNULL(FW.foreign_exporter_address, '') as foreign_exporter_address,
			--ISNULL(fw.foreign_exporter_city, '') as foreign_exporter_city,
   --         ISNULL(fw.foreign_exporter_province_territory, '') as foreign_exporter_province_territory,
   --         ISNULL(fw.foreign_exporter_mail_code, '') as foreign_exporter_mail_code,
   --         ISNULL(fw.foreign_exporter_country, '') as foreign_exporter_country,
			ISNULL(FW.foreign_exporter_contact_name, '') as foreign_exporter_contact_name,
			ISNULL(FW.foreign_exporter_phone, '') as foreign_exporter_phone,

			ISNULL(FW.foreign_exporter_fax, '') as foreign_exporter_fax,
			ISNULL(FW.foreign_exporter_email, '') as foreign_exporter_email,
			ISNULL(FW.epa_notice_id, '') as epa_notice_id,
			ISNULL(FW.epa_consent_number, '') as epa_consent_number,

			ISNULL(FW.effective_date, '') as effective_date,
			ISNULL(FW.expiration_date, '') as expiration_date,			
			--CAST(CAST(approved_volume  AS FLOAT) AS bigint)as approved_volume,
			ISNULL(approved_volume, '') as approved_volume,

			ISNULL(fw.approved_volume_unit,'') as approved_volume_unit,
			ISNULL(fw.importing_generator_id, '') as importing_generator_id,

			ISNULL(fw.importing_generator_name,'') as importing_generator_name,
			ISNULL(fw.importing_generator_address, '') as importing_generator_address,

			
			ISNULL(fw.importing_generator_city,'') as importing_generator_city,
			ISNULL(fw.importing_generator_province_territory, '') as importing_generator_province_territory,

			ISNULL(fw.importing_generator_mail_code,'') as importing_generator_mail_code,
			ISNULL(fw.importing_generator_epa_id, '') as importing_generator_epa_id,
			
			ISNULL(fw.tech_contact_id,'') as tech_contact_id,
			ISNULL(fw.tech_contact_name, '') as tech_contact_name,

			ISNULL(fw.tech_contact_phone,'') as tech_contact_phone,
			ISNULL(fw.tech_cont_email, '') as tech_cont_email,

			ISNULL(fw.tech_contact_fax,'') as tech_contact_fax,
			ISNULL(fw.created_by, '') as created_by,

			ISNULL(fw.date_created,'') as date_created,
			ISNULL(fw.modified_by, '') as modified_by,
			ISNULL(fw.date_modified,'') as date_modified,
			@section_status AS IsCompleted,
			ISNULL(fw.foreign_exporter_sameas_generator, '') as foreign_exporter_sameas_generator,
			(SELECT *
				FROM FormXWasteCode as WasteCodes
				WHERE  WasteCodes.form_id = WCR.form_id AND WasteCodes.revision_id = WCR.revision_id
				FOR XML AUTO,TYPE,ROOT ('WasteCodeList'), ELEMENTS)
			
			from formwcr WCR join
			FormWasteImport fw on wcr.form_id = fw.wcr_id AND WCR.revision_id = fw.wcr_rev_id 
			WHERE wcr.form_id = @form_id AND wcr.revision_id = @revision_id

			FOR XML RAW ('wasteImport'), ROOT ('ProfileModel'), ELEMENTS
END

GO

	GRANT EXEC ON [dbo].[sp_wasteImport_select] TO COR_USER;

GO