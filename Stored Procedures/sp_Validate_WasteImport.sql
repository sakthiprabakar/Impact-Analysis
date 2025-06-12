USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [sp_Validate_WasteImport]
GO
CREATE PROCEDURE  [dbo].[sp_Validate_WasteImport]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@revision_ID INT,
	@web_user_id NVARCHAR(150)
AS


/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 9th Jan 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_WasteImport]


	Procedure to validate Waste Import Section required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID
	@web_user_id


Samples:
 EXEC sp_Validate_WasteImport @form_id,@revision_ID, @web_user_id
 EXEC sp_Validate_WasteImport 508789, 1, 'brieac1'

****************************************************************** */

BEGIN

		DECLARE @FormStatusFlag CHAR(1) = 'Y'	
		DECLARE @failedCount INT = 0;

		SET @failedCount = 
					(SELECT 
						CASE WHEN ISNULL(WI.foreign_exporter_name,'')='' OR
							 		ISNULL(WI.foreign_exporter_address,'')= '' OR
									ISNULL(WI.foreign_exporter_city,'')= '' OR
									ISNULL(WI.foreign_exporter_province_territory,'')= '' OR
									ISNULL(WI.foreign_exporter_mail_code,'')= '' OR
									ISNULL(WI.foreign_exporter_country,'')= '' OR
									ISNULL(WI.foreign_exporter_contact_name,'')= '' OR
									ISNULL(WI.foreign_exporter_phone,'')= '' OR
									ISNULL(WI.foreign_exporter_email,'')= ''
								THEN 1 ELSE 0 END 
					+ CASE WHEN wcr.RCRA_Waste_code_flag <> 'T' AND ISNULL(WI.epa_notice_id,'')='' THEN 1 else 0 end
					+ CASE WHEN WI.foreign_exporter_country = 'USA' AND LEN(WI.foreign_exporter_mail_code) != 5 
							AND LEN(WI.foreign_exporter_mail_code) != 9 THEN 1 ELSE 0 END
					+ CASE WHEN WI.foreign_exporter_country = 'MEX' AND LEN(WI.foreign_exporter_mail_code) != 5 THEN 1 ELSE 0 END
					+ CASE WHEN LEN(WI.foreign_exporter_mail_code) != 6 AND (WI.foreign_exporter_country NOT IN ('USA','MEX')) THEN 1 ELSE 0 END
															
				FROM FormWasteImport AS WI
				JOIN FormWCR AS wcr ON WI.wcr_id=wcr.form_id AND WI.wcr_rev_id=wcr.revision_id 
				WHERE WI.wcr_id=@formid AND WI.wcr_rev_id=@revision_ID 
		)

		IF(@failedCount > 0 )
		BEGIN
			SET @FormStatusFlag = 'P'
		END
			
		IF(NOT EXISTS(SELECT FORM_ID FROM FormSectionStatus WHERE FORM_ID =@formid AND revision_id = @revision_ID AND SECTION ='WI'))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@formid,@revision_ID,'WI',@FormStatusFlag,GETDATE(),@web_user_id,GETDATE(),@web_user_id,1)
		END
		ELSE 
		BEGIN
			UPDATE FormSectionStatus SET section_status = @FormStatusFlag WHERE FORM_ID = @formid and revision_id = @revision_ID AND SECTION = 'WI'
		END
END

GO
GRANT EXEC ON [dbo].[sp_Validate_WasteImport] TO COR_USER;
GO