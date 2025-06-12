USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Validate_Profile_WasteImport]    Script Date: 26-11-2021 13:21:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE  [dbo].[sp_Validate_Profile_WasteImport]
	-- Add the parameters for the stored procedure here
	@profile_id INT,
	@web_user_id NVARCHAR(150)
AS


/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 9th Jan 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_WasteImport]


	Procedure to validate Waste Import Section required fields and Update the Status of section

inputs 
	
	@profile_id
	@web_user_id


Samples:
 EXEC [sp_Validate_Profile_WasteImport] @profile_id,@web_user_id
 EXEC [sp_Validate_Profile_WasteImport] 508789,'brieac1'
 EXEC [sp_Validate_Profile_WasteImport] 616405,'manand84'
****************************************************************** */

BEGIN

	DECLARE @ProfileStatusFlag varchar(1) = 'Y'
	DECLARE @for_ex_mail_code VARCHAR(20);
	DECLARE @for_ex_country VARCHAR(100);

	--SELECT * INTO #tempFormWCR FROM FormWCR WHERE form_id=@formid and revision_id=@Revision_ID 
	SELECT * INTO #tempProfileWasteImport FROM ProfileWasteImport WHERE profile_id=@profile_id 
	
	IF(EXISTS(SELECT * FROM #tempProfileWasteImport))
	BEGIN
	
	 -- 6. Name:
			IF(EXISTS(SELECT * FROM #tempProfileWasteImport WHERE ISNULL(foreign_exporter_name,'')=''))
			BEGIN
				SET @ProfileStatusFlag = 'P'
			END

			--7. Address:
			IF(EXISTS(SELECT * FROM #tempProfileWasteImport WHERE ISNULL(foreign_exporter_address,'')=''))
			BEGIN
				SET @ProfileStatusFlag = 'P'
			END
			
			--City:
			IF(EXISTS(SELECT * FROM #tempProfileWasteImport WHERE ISNULL(foreign_exporter_city,'')=''))
			BEGIN
				SET @ProfileStatusFlag = 'P'
			END

			--Province/Territory:
			IF(EXISTS(SELECT * FROM #tempProfileWasteImport WHERE ISNULL(foreign_exporter_province_territory,'')=''))
			BEGIN
				SET @ProfileStatusFlag = 'P'
			END

			--Mail Code:
			IF(EXISTS(SELECT * FROM #tempProfileWasteImport WHERE ISNULL(foreign_exporter_mail_code,'')=''))
			BEGIN
				SET @ProfileStatusFlag = 'P'
			END

			--Country:
			IF(EXISTS(SELECT * FROM #tempProfileWasteImport WHERE ISNULL(foreign_exporter_country,'')=''))
			BEGIN
				SET @ProfileStatusFlag = 'P'
			END

			-- 8. Contact Name:
			IF(EXISTS(SELECT * FROM #tempProfileWasteImport WHERE ISNULL(foreign_exporter_contact_name,'')=''))
			BEGIN
				SET @ProfileStatusFlag = 'P'
			END		

			-- Phone:
			IF(EXISTS(SELECT * FROM #tempProfileWasteImport WHERE ISNULL(foreign_exporter_phone,'')=''))
			BEGIN
				SET @ProfileStatusFlag = 'P'
			END

			-- Email:
			IF(EXISTS(SELECT * FROM #tempProfileWasteImport WHERE ISNULL(foreign_exporter_email,'')=''))
			BEGIN
				SET @ProfileStatusFlag = 'P'
			END		

			DECLARE @rcra_wastecode_flag nvarchar(1) = (select RCRA_Waste_code_flag from Profile Where profile_id = @profile_id)

			 --EPA Notice ID: 
			IF(EXISTS(SELECT * FROM #tempProfileWasteImport WHERE ISNULL(epa_notice_id,'')='') AND @rcra_wastecode_flag <> 'T')
			BEGIN
				SET @ProfileStatusFlag = 'P'
			END

			SELECT @for_ex_country = foreign_exporter_country,@for_ex_mail_code = foreign_exporter_mail_code FROM #tempProfileWasteImport
			IF(NOT EXISTS(SELECT * FROM #tempProfileWasteImport WHERE ISNULL(foreign_exporter_country,'')=''))
			BEGIN
			    IF (@for_ex_country = 'USA' AND LEN(@for_ex_mail_code) != 5 AND LEN(@for_ex_mail_code) != 9)
				 BEGIN
				   SET @ProfileStatusFlag = 'P'
				END
				IF (@for_ex_country = 'MEX' AND LEN(@for_ex_mail_code) != 5)
				 BEGIN
				   SET @ProfileStatusFlag = 'P'
				END

				IF(LEN(@for_ex_mail_code) != 6 AND (@for_ex_country != 'USA' AND @for_ex_country != 'MEX'))
				 BEGIN
				   SET @ProfileStatusFlag = 'P'
				END
			END

			-- 10. EPA Consent Number: 
			--IF(EXISTS(SELECT * FROM #tempFormWasteImport WHERE ISNULL(epa_consent_number,'')='') AND @rcra_wastecode_flag <> 'T')
			--BEGIN
			--	SET @FormStatusFlag = 'P'
			--END

			---- 11. Effective Date:
			--IF(EXISTS(SELECT * FROM #tempFormWasteImport WHERE ISNULL(effective_date,'')='') AND @rcra_wastecode_flag <> 'T')
			--BEGIN
			--	SET @FormStatusFlag = 'P'
			--END
	
			---- 12. Expiration Date:
			--IF(EXISTS(SELECT * FROM #tempFormWasteImport WHERE ISNULL(expiration_date,'')='') AND @rcra_wastecode_flag <> 'T')
			--BEGIN
			--	SET @FormStatusFlag = 'P'
			--END

			---- 13. Approved Volume:
			--IF(EXISTS(SELECT * FROM #tempFormWasteImport WHERE ISNULL(approved_volume,'')='' AND @rcra_wastecode_flag <> 'T'))
			--BEGIN
			--	SET @FormStatusFlag = 'P'
			--END

			-- Update the profile status in ProfileSectionStatus table
			IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE profile_id =@profile_id AND SECTION ='WI'))
			BEGIN
				INSERT INTO ProfileSectionStatus VALUES (@profile_id,'WI',@ProfileStatusFlag,getdate(),@web_user_id,getdate(),@web_user_id,1)
			END
			ELSE 
			BEGIN
				UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE profile_id = @profile_id AND SECTION = 'WI'
			END

	END

	--DROP TABLE  #tempFormWCR
	DROP TABLE  #tempProfileWasteImport

END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_WasteImport] TO COR_USER;
GO