USE [PLT_AI]
GO


DROP PROCEDURE IF EXISTS [dbo].[sp_FormWCR_insert_update] 
GO 

CREATE PROCEDURE [dbo].[sp_FormWCR_insert_update]
@Data XML,
@formId int,
@Revision_id int,
@template_form_id int = null,
@Message nvarchar(MAX) Output,
@form_Id INT OUTPUT,
@rev_id int output
AS

/* ******************************************************************
    Updated By       : Pasupathi P
    Updated On       : 1st JUL 2024
    Type             : Stored Procedure
    Ticket           : 89274
    Object Name      : [sp_FormWCR_insert_update]

Updated to the template related changes Requirement 89274: Profile Template > UI Functionality & API Integration
    ***********************************************************************/

BEGIN
 
DECLARE @SectionA_data XML,
@SectionB_data XML,
@SectionC_data XML,
@SectionD_data XML,
@SectionE_data XML,
@SectionF_data XML,
@SectionG_data XML,
@SectionH_data XML,
@PCB_data XML,
@LDR_data XML,
@Benzene_data XML,
@IllinoisDisposal_data XML,
@Pharmaceutical_data XML,
@UsedOil_data XML,
@WasteImport_data XML,
@Certification_data XML,
@Thermal_data XML,
@Document_data XML,
@Cylinder_data XML,
@Debris_data XML,
@Radioactive_data XML,
@GeneratorLocation_data XML,
@SectionL_data XML,
@SectionGK_data XML,
@FuelsBlending_data XML;

Declare @i_copy_source NVARCHAR(100) = 'new';
Declare @temp_doc_source VARCHAR(2) = 'F';

Declare @web_userid NVARCHAR(200) = (SELECT p.v.value('created_by[1]','VARCHAR(50)') from @Data.nodes('ProfileModel')p(v))
Declare @date_created DATETIME = (SELECT p.v.value('date_created[1]','DATETIME') from @Data.nodes('ProfileModel')p(v))
Declare @date_modified DATETIME = (SELECT p.v.value('date_modified[1]','DATETIME') from @Data.nodes('ProfileModel')p(v))
Declare @modified_by NVARCHAR(200) = (SELECT p.v.value('modified_by[1]','VARCHAR(50)') from @Data.nodes('ProfileModel')p(v))
--select @web_userid

DECLARE @EditedSectionDetails VARCHAR(150);
DECLARE @SectionAedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/SectionA')p(v)),
        @SectionBedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/SectionB')p(v)),
        @SectionCedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/SectionC')p(v)),
        @SectionDedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/SectionD')p(v)),
	    @SectionEedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/SectionE')p(v)),
        @SectionFedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/SectionF')p(v)),
        @SectionGedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/SectionG')p(v)),
        @SectionHedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/SectionH')p(v)),
        @PCBedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/PCB')p(v)),
        @LDRedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/LDR')p(v)),
        @Benzeneedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/Benzene')p(v)),
        @IllinoisDisposaledited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/IllinoisDisposal')p(v)),
	    @Pharmaceuticaledited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/Pharmaceutical')p(v)),
        @UsedOiledited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/Usedoil')p(v)),
        @WasteImportedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/WasteImport')p(v)),
        @Certificationedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/Certification')p(v)),
		@Thermaledited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/Thermal')p(v)),
		@Documentedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/DocumentAttachment')p(v)),
		@Cylinderedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/Cylinder')p(v)),
		@Debrisedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/Debris')p(v)),
		@Radioactiveedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/Radioactive')p(v)),
		@GeneratorLocation VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/GeneratorLocation')p(v)),
		@SectionLedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/SectionL')p(v)),
		@SectionGKedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/GeneratorKnowledge')p(v)),
		@SectionFBedited VARCHAR(50) = (SELECT p.v.value('IsEdited[1]','VARCHAR(50)') from @Data.nodes('ProfileModel/FuelsBlending')p(v));
		
		
DECLARE @PCBFlag varchar(2) = (SELECT p.v.value('pcbflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)),
        @LDRFlag varchar(2) = (SELECT p.v.value('ldrflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)),
		@BZFlag varchar(2) = (SELECT p.v.value('bzflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)),
		@IDFlag varchar(2) =(SELECT p.v.value('idflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)),
		@PLFlag varchar(2) = (SELECT p.v.value('pharmaflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)),
		@WIFlag varchar(2) = (SELECT p.v.value('wasteimportflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)), 
		@ULFlag varchar(2) = (SELECT p.v.value('usedoilflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)),  
		@CNFlag varchar(2) = (SELECT p.v.value('certificationflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)),  
		@TLFlag varchar(2) = (SELECT p.v.value('thermalflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)),
		@CRFlag varchar(2) = (SELECT p.v.value('cylinderflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)),
		@DSFlag varchar(2) = (SELECT p.v.value('debrisflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)),
		@RAFlag varchar(2) = (SELECT p.v.value('radioactiveflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)),
		@GLFlag varchar(2) = (SELECT p.v.value('generatorlocationflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)),
		@GKFlag varchar(2) = (SELECT p.v.value('generatorknowledgeflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)),
		@IsTemplateFlag varchar(2) = (SELECT p.v.value('istemplateflag[1]','VARCHAR(2)')FROM @Data.nodes('ProfileModel')p(v)),
		@FBFlag varchar(2) = (SELECT p.v.value('fuelblendingflag[1]','VARCHAR(2)') FROM @Data.nodes('ProfileModel')p(v));

		--select @GeneratorLocation
		--select @GLFlag
		
 SELECT @SectionA_data= @Data.query('ProfileModel/SectionA'),@SectionB_data=@Data.query('ProfileModel/SectionB')
	,@SectionC_data=@Data.query('ProfileModel/SectionC'),@SectionD_data=@Data.query('ProfileModel/SectionD')
	,@SectionE_data=@Data.query('ProfileModel/SectionE'),@SectionF_data=@Data.query('ProfileModel/SectionF')
	,@SectionG_data=@Data.query('ProfileModel/SectionG'),@SectionH_data=@Data.query('ProfileModel/SectionH')
	,@PCB_data =@Data.query('ProfileModel/PCB')
	,@LDR_data=@Data.query('ProfileModel/LDR')
	,@Benzene_data=@Data.query('ProfileModel/Benzene')
	,@IllinoisDisposal_data=@Data.query('ProfileModel/IllinoisDisposal')
	,@Pharmaceutical_data=@Data.query('ProfileModel/Pharmaceutical')
	,@UsedOil_data =@Data.query('ProfileModel/Usedoil')
	,@WasteImport_data =@Data.query('ProfileModel/WasteImport')
	,@Certification_data =@Data.query('ProfileModel/Certification')
	,@Thermal_data=@Data.query('ProfileModel/Thermal')
	,@Document_data =@Data.query('ProfileModel/DocumentAttachment')
	,@Cylinder_data=@Data.query('ProfileModel/Cylinder')
	,@Debris_data=@Data.query('ProfileModel/Debris')
	,@Radioactive_data=@Data.query('ProfileModel/Radioactive')
	,@GeneratorLocation_data=@Data.query('ProfileModel/GeneratorLocation')
	,@SectionL_data=@Data.query('ProfileModel/SectionL')
	,@SectionGK_data=@Data.query('ProfileModel/GeneratorKnowledge')
	,@FuelsBlending_data=@Data.query('ProfileModel/FuelsBlending')


DECLARE @CommonName VARCHAR(50) = (SELECT p.v.value('waste_common_name[1]','varchar(50)')FROM @SectionB_data.nodes('SectionB')p(v));

DECLARE @doc_count INT = (SELECT COUNT(*)
							FROM @Data.nodes('ProfileModel/DocumentAttachment/DocumentAttachment/DocumentAttachment')p(v)
							WHERE p.v.value('document_id[1]','int')>0)

 IF @template_form_id IS NOT NULL
  BEGIN
    SET @i_copy_source = 'Template';
  END

 SET @Documentedited = (SELECT 
								case
								WHEN (@IsTemplateFlag = 'T' OR @temp_doc_source = 'T') THEN 'DA'
								when	ISNULL(p.v.value('info_basis_analysis[1]','char(1)'), '') = '' AND  
											ISNULL(p.v.value('info_basis_msds[1]','char(1)'), '') = '' AND 
											ISNULL(p.v.value('info_basis_knowledge[1]','char(1)'), '') = '' AND @doc_count = 0 THEN NULL ELSE 'DA' END
											from @Data.nodes('ProfileModel/SectionE')p(v))


	IF(NOT EXISTS(SELECT * FROM FormWCR WHERE form_id = @formId AND revision_id = @Revision_id))
	BEGIN
		INSERT INTO FormWCR (form_id,revision_id,[status],locked,[source],date_created,date_modified,created_by,modified_by, copy_source, template_form_id)
			VALUES(@formId,
				 @Revision_id,
				 'A',
				 'U',
				 'W',
				 GETDATE(),
				 GETDATE(),
				 @web_userid,
				 @web_userid,
				 @i_copy_source, @template_form_id)
	END	
	ELSE 
	BEGIN

		DECLARE @signing_name NVARCHAR(100), 
				@signing_title NVARCHAR(150),
				@signing_company VARCHAR(40)
		select 
				@signing_name = p.v.value('signing_name[1]','VARCHAR(40)'),
				@signing_title = p.v.value('signing_title[1]','VARCHAR(40)'),
				@signing_company = p.v.value('signing_company[1]','VARCHAR(40)')
        FROM		
        @SectionH_data.nodes('SectionH')p(v) 

		UPDATE FormWCR 
		SET 
			date_modified = GETDATE(),  
			modified_by = @modified_by,
			signing_name = @signing_name,
			signing_title = @signing_title,
			signing_company = @signing_company
			WHERE form_id = @formId AND revision_id = @Revision_id
	END	 
			
	IF(NOT EXISTS(SELECT *FROM ContactCORFormWCRBucket WHERE form_id = @formId AND revision_id = @Revision_id))
	BEGIN
		INSERT INTO ContactCORFormWCRBucket (contact_id,form_id,revision_id) Values(
		(SELECT TOP 1 contact_ID FROM Contact WHERE web_userid = @web_userid),
		@formId,
		@Revision_id)
	END

	 BEGIN TRY   
			--BEGIN TRANSACTION;
			
			
		IF @SectionAedited = 'A' 
			BEGIN
				
			EXEC sp_FormWCR_insert_update_section_A  @SectionA_data,@FormId,@Revision_id;
			--print 'A'
			END
        IF @SectionBedited = 'B' 
			BEGIN
				
			EXEC sp_FormWCR_insert_update_section_B  @SectionB_data,@FormId,@Revision_id;
			--print 'B'
			END
        IF @SectionCedited = 'C' 
			BEGIN
				
			EXEC sp_FormWCR_insert_update_section_C  @SectionC_data,@FormId,@Revision_id,@web_userid;
			--print 'C'						
			END
		IF @SectionDedited = 'D' 
			BEGIN
				
			EXEC sp_FormWCR_insert_update_section_D  @SectionD_data,@FormId,@Revision_id;
			--print 'D'
			END
        IF @SectionEedited = 'E' 
			BEGIN
			
			EXEC sp_FormWCR_insert_update_section_E  @SectionE_data,@FormId,@Revision_id;
			--print 'E'
			END
        IF @SectionFedited = 'F' 
			BEGIN
				
			EXEC sp_FormWCR_insert_update_section_F  @SectionF_data,@FormId,@Revision_id;
			--print 'F'
			END
		IF @SectionGedited = 'G' 
			BEGIN
					
			EXEC sp_FormWCR_insert_update_section_G  @SectionG_data,@FormId,@Revision_id;
			--print 'G'
			END
		IF @SectionHedited = 'H' 
			BEGIN
				
			EXEC sp_FormWCR_insert_update_section_H  @SectionH_data,@FormId,@Revision_id, @web_userid;
			--print 'H'
			END

			IF @SectionLedited = 'SL' 
			--AND @SectionHedited<>'H'
			BEGIN
				
			EXEC sp_FormWCR_insert_update_section_L  @SectionL_data,@FormId,@Revision_id;
			--print 'SL'
			END
			-- ELSE
			-- BEGIN
			--EXEC sp_Validate_Section_L @FormId,@Revision_id
			-- END


			EXEC sp_COR_Insert_Supplement_Section_Status @FormId,@Revision_id, @modified_by

		IF  @PCBFlag = 'T'
					  
			BEGIN
			SET @PCBedited = 'PB'
            IF @PCBedited = 'PB' 
			BEGIN	
						
				EXEC sp_pcb_insert_update @PCB_data,@FormId,@Revision_id;
			END
        END

		-- IF @DocFlag = 'T'
		--BEGIN
		IF @Documentedited = 'DA' 
			BEGIN		
				IF @template_form_id IS NULL AND @i_copy_source = 'new' AND @IsTemplateFlag = 'T'
				BEGIN 
				    EXEC sp_document_insert_update @Document_data, @FormId, @Revision_id, @web_userid, @IsTemplateFlag;	
				END
				ELSE
				BEGIN
					EXEC sp_document_insert_update @Document_data, @FormId, @Revision_id, @web_userid, @temp_doc_source;
				END
			END
		-- END

		IF @LDRFlag = 'T'
		BEGIN
			SET @LDRedited = 'LR'
			IF @LDRedited = 'LR' 
			BEGIN		
				
			EXEC sp_ldr_insert_update  @LDR_data,@FormId,@Revision_id,@web_userid;
			END
		END

		IF @BZFlag  = 'T'
		BEGIN
		SET @Benzeneedited = 'BZ'
		IF @Benzeneedited = 'BZ' 
			BEGIN		
			
			EXEC sp_benzene_insert_update @Benzene_data,@FormId,@Revision_id,@web_userid;
			END
		END

		IF @IDFlag  = 'T'
		BEGIN
		SET @IllinoisDisposaledited = 'ID'
		IF @IllinoisDisposaledited = 'ID' 
			BEGIN	
			
			EXEC sp_IllinoisDisposal_insert_update  @IllinoisDisposal_data,@FormId,@Revision_id,@web_userid;
			END
		END

		IF @PLFlag  = 'T'
		BEGIN
		SET @Pharmaceuticaledited = 'PL'
			IF @Pharmaceuticaledited = 'PL' 
			BEGIN	
		
			EXEC sp_pharmaceutical_insert_update @Pharmaceutical_data,@FormId,@Revision_id,@web_userid;
			END
		END

		IF @WIFlag  = 'T'
		BEGIN
		SET @WasteImportedited = 'WI'
			IF @WasteImportedited = 'WI' 
			BEGIN	
			
			EXEC sp_wasteImport_insert_update @WasteImport_data,@FormId,@Revision_id,@web_userid;
			END
		END

		IF @ULFlag  = 'T'
		BEGIN
		SET @UsedOiledited = 'UL'
		IF @UsedOiledited = 'UL' 
			BEGIN				
			EXEC sp_usedOil_insert_update @UsedOil_data,@FormId,@Revision_id;
			END
		END

		IF @CNFlag  = 'T'
		BEGIN
		SET @Certificationedited = 'CN'
			IF @Certificationedited = 'CN' 
			BEGIN				
			EXEC sp_certification_insert_update  @Certification_data,@FormId,@Revision_id,@web_userid;
			END
		END

		IF @TLFlag  = 'T'
		BEGIN
		SET @Thermaledited = 'TL'
			IF @Thermaledited = 'TL' 
			BEGIN				
			EXEC sp_thermal_insert_update @Thermal_data,@FormId,@Revision_id,@web_userid;
			END

		END


		IF  @CRFlag = 'T'
					  
			BEGIN
			SET @Cylinderedited = 'CR'
            IF @Cylinderedited = 'CR' 
			BEGIN	

				EXEC sp_cylinder_insert_update @Cylinder_data,@FormId,@Revision_id,@web_userid;
			END
        END

			IF  @DSFlag = 'T'
					  
			BEGIN
			SET @Debrisedited = 'DS' 
            IF @Debrisedited = 'DS' 
			BEGIN	
				EXEC sp_Debris_insert_update  @Debris_data,@FormId,@Revision_id,@web_userid;
			END
        END				   
				   
		IF  @RAFlag = 'T'
					  
			BEGIN
			SET @Radioactiveedited = 'RA' 
            IF @Radioactiveedited = 'RA' 
			BEGIN	
				EXEC sp_Radioactive_insert_update  @Radioactive_data,@FormId,@Revision_id,@web_userid;
			END
        END
			IF  @GLFlag = 'T'
					  
			BEGIN
			SET @GeneratorLocation = 'GL' 
            IF @GeneratorLocation = 'GL' 
			BEGIN	
						
				EXEC sp_GeneratorLocation_insert_update @GeneratorLocation_data,@FormId,@Revision_id,@web_userid;
			END
        END
			
		IF @GKFlag = 'T'
		BEGIN
			SET @SectionGKedited = 'GK'
			IF @SectionGKedited = 'GK' 
			BEGIN							
				EXEC sp_FormGenerator_Knowledge_Insert_Update  @FormId, @Revision_id, @SectionGK_data,@web_userid;
			END
		END

		IF @FBFlag = 'T'
		BEGIN
			SET @SectionFBedited = 'FB'
			IF @SectionFBedited = 'FB'
			BEGIN
				EXEC sp_FormEcoflo_insert_update  @FuelsBlending_data, @FormId, @Revision_id,@web_userid
			END
		END

			IF  @IsTemplateFlag = 'T'
			BEGIN
				IF(NOT EXISTS(SELECT *FROM FormWCRTemplate WHERE template_form_id = @formId))
				BEGIN
					INSERT INTO FormWCRTemplate (template_form_id,name,description,created_by,date_created,modified_by,date_modified,status)
													Values(@formId,@CommonName,@CommonName,@web_userid,GETDATE(),@web_userid,GETDATE(),'A')
				END
				ELSE 
				BEGIN
					UPDATE FormWCRTemplate SET name = @CommonName,description = @CommonName WHERE template_form_id = @formId
				END
			END

			-- Check form is exist in the status tables
			DECLARE @formid_exist_count INT
			SELECT @formid_exist_count = COUNT(*) FROM FormWCR where form_id=@FormId and revision_id=@Revision_id

			EXEC sp_Insert_Section_Status @FormId,@Revision_id,@web_userid;
				
					  
					 
			SET @EditedSectionDetails = ISNULL(@SectionAedited,0) + ','+ ISNULL(@SectionBedited,0) + ',' + isnull(@SectionCedited,0) + ','+ isnull(@SectionDedited,0) + ','+isnull( @SectionEedited,0) + ','+ ISNULL(@SectionFedited,0) + ','+ ISNULL(@SectionGedited,0) + ','+ ISNULL(@SectionHedited,0)+ ','
					                    + ISNULL(@PCBedited,0) + ','+ ISNULL(@LDRedited,0) + ',' + ISNULL(@Benzeneedited,0) + ','+ ISNULL(@IllinoisDisposaledited,0)+ ','
										+ ISNULL(@Pharmaceuticaledited,0) + ','+ ISNULL(@WasteImportedited,0) + ',' + ISNULL(@UsedOiledited,0) + ','+ ISNULL(@Certificationedited,0) + ','
										+ ISNULL(@Thermaledited,0) + ','+ ISNULL(@Cylinderedited,0)  + ','+ ISNULL(@Debrisedited,0) + ','+ ISNULL(@Documentedited,0) + ','+ ISNULL(@Radioactiveedited,0)+ ','+ ISNULL(@GeneratorLocation,0)+','+ ISNULL(@SectionLedited,0) + ','+ ISNULL(@SectionGKedited, 0)+ ','+ ISNULL(@SectionFBedited, 0);
												   
				
				
			EXEC sp_Validate_FormWCR @FormId,@Revision_id,@EditedSectionDetails,@web_userid;

			EXEC sp_update_FormSectionStatus @FormId,@Revision_id,@PCBFlag,@LDRFlag,
				@BZFlag,@IDFlag,@PLFlag,@WIFlag,@ULFlag,@CNFlag,@TLFlag,@CRFlag,@DSFlag,@RAFlag,@GLFlag
					  
				SET @Message = 'Profile saved successfully';
				SET @form_Id = @formId;
                SET @rev_id = @Revision_id;

				SELECT @Message AS [Message]
			     --UPDATE @Result SET Message='Profile Insert Successfully'
			     --SELECT * FROM @Result
			  --END
			 --COMMIT TRANSACTION;
			    END TRY
			  BEGIN CATCH
				--IF @@TRANCOUNT > 0
				--ROLLBACK TRANSACTION;
				SET @Message = Error_Message();
				SET @form_Id = @formId;
                set @rev_id = @Revision_id;
				declare @mailTrack_userid nvarchar(60) = 'COR'
				DECLARE @procedure nvarchar(150) 
				SET @procedure = ERROR_PROCEDURE()				
				declare @error nvarchar(max) = 'Form ID: ' + convert(nvarchar(15), @form_Id) + '-' +  convert(nvarchar(15), @rev_id) 
															+ CHAR(13) + 
															+ CHAR(13) + 
														   'Error Message: ' + isnull(@Message, '')
														   + CHAR(13) + 
														   + CHAR(13) + 
														   'Data:  ' + convert(nvarchar(max),@Data)

														   
				EXEC [COR_DB].[DBO].sp_COR_Exception_MailTrack
						@web_userid = @mailTrack_userid, 
						@object = @procedure,
						@body = @error


				
				SELECT @Message AS [Message]
			    DECLARE @error_description VARCHAR(MAX)
				SET @error_description=CONVERT(VARCHAR(20), @formId)+' - '+CONVERT(VARCHAR(10),@Revision_id)
					+ ' ErrorMessage: '+Error_Message()+'\n XML: '+CONVERT(VARCHAR(MAX),@Data)
				INSERT INTO COR_DB.[dbo].[ErrorLogs] (ErrorDescription,[Object_Name],Web_user_id,CreatedDate)
		                               VALUES(@error_description,ERROR_PROCEDURE(),@mailTrack_userid,GETDATE())
										
									
  END CATCH		
END;
GO

GRANT EXEC ON [dbo].[sp_FormWCR_insert_update] TO COR_USER
GO 

GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update]  TO EQWEB 
GO 

GRANT EXECUTE ON [dbo].[sp_FormWCR_insert_update]  TO EQAI 
GO 