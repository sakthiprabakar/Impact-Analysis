CREATE PROCEDURE  [dbo].[sp_Validate_PCB]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@revision_ID INT,
	@web_userid nvarchar(200)
AS


/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 9th Jan 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_PCB]


	Procedure to validate PCB Supplement form required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID


Samples:
 EXEC [sp_Validate_PCB] @form_id,@revision_ID
 EXEC [sp_Validate_PCB] 902383, 1

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR(3);
	
	DECLARE @FormStatusFlag varchar(1) = 'Y'
	
	SET @SectionType = 'PB'
	SET @TotalValidColumn =2

	          -- concentration of PCBs in the waste 

	        DECLARE @pcbCount INT

			SET @pcbCount = (SELECT  (			 
				  (CASE WHEN pcb_concentration_0_9 IS NULL OR pcb_concentration_0_9 = ''  OR pcb_concentration_0_9 ='F' THEN 0 ELSE 1 END)
				+ (CASE WHEN pcb_concentration_10_49 IS NULL OR pcb_concentration_10_49 = '' OR pcb_concentration_10_49 ='F' THEN 0 ELSE 1 END)
				+ (CASE WHEN pcb_concentration_50_499 IS NULL OR pcb_concentration_50_499 = '' OR pcb_concentration_50_499 = 'F' THEN 0 ELSE 1 END)
				+ (CASE WHEN pcb_concentration_500 IS NULL OR pcb_concentration_500 = '' OR pcb_concentration_500 = 'F' THEN 0 ELSE 1 END)
		    ) AS sum_of_odernulls
			From FormWcr
			Where 
			form_id =  @formid AND revision_id = @revision_ID)

			

			print CAST(@pcbCount AS VARCHAR(10))

			IF @pcbCount = 0 
			  BEGIN
			   SET @FormStatusFlag = 'P'
			  END
			  
            print '@pcbCount' + @FormStatusFlag
			  

	        SET  @ValidColumnNullCount = (SELECT  (			  
				  	(CASE WHEN pcb_regulated_for_disposal_under_TSCA IS NULL OR pcb_regulated_for_disposal_under_TSCA = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pcb_source_concentration_gr_50 IS NULL OR pcb_source_concentration_gr_50 = '' OR pcb_source_concentration_gr_50 = 'U' THEN 1 ELSE 0 END)
		    ) AS sum_of_nulls
			From FormWcr
			Where 
			form_id =  @formid and revision_id = @revision_ID)

			IF @ValidColumnNullCount !=0 
			 BEGIN
			  SET @FormStatusFlag = 'P'
			 END

			 print '@ValidColumnNullCount' + @FormStatusFlag

			DECLARE @processed_into_non_liquid  CHAR(1);
			DECLARE @processd_into_nonlqd_prior_pcb VARCHAR(255);
			DECLARE @pcb_article_for_TSCA_landfill CHAR(1);
			DECLARE @pcb_article_decontaminated CHAR(1);
			DECLARE @pcb_source_concentration_gr_50 CHAR(1);

			DECLARE @pcb_concentration_50_499 CHAR(1);
			DECLARE @pcb_concentration_500 CHAR(1);
			DECLARE @pcb_manufacturer CHAR(1);

			SELECT @pcb_manufacturer=pcb_manufacturer,@pcb_concentration_500 = pcb_concentration_500,@pcb_concentration_50_499=pcb_concentration_50_499, @processed_into_non_liquid=processed_into_non_liquid,@processd_into_nonlqd_prior_pcb=processd_into_nonlqd_prior_pcb,@pcb_article_for_TSCA_landfill=pcb_article_for_TSCA_landfill,@pcb_article_decontaminated=pcb_article_decontaminated,@pcb_source_concentration_gr_50=pcb_source_concentration_gr_50 FROM FormWCR WHERE form_id = @formid
			
			-- Has this waste been processed into a non-liquid form?
			IF @processed_into_non_liquid = '' OR @processed_into_non_liquid IS NULL 
			 BEGIN
			    SET @FormStatusFlag = 'P'
			 END
			ELSE
			 BEGIN 
			  IF @processed_into_non_liquid = 'T'
				BEGIN
				    IF @processd_into_nonlqd_prior_pcb IS NULL OR @processd_into_nonlqd_prior_pcb = '' 
					 BEGIN
				       SET @FormStatusFlag = 'P'
				     END
				END
			 END  

			 Print 'liquid form ' +   @FormStatusFlag

			 --- pcb_concentration_500 OR pcb_concentration_50_499

			 --IF @pcb_concentration_500 = 'T'  OR @pcb_concentration_50_499 = 'T'
			 -- BEGIN

			 --  PRINT  '@pcb_manufacturer ' + @FormStatusFlag

			 --   IF (@pcb_concentration_50_499 = 'T' OR @pcb_concentration_500 = 'T' OR @pcb_source_concentration_gr_50 = 'T' OR @pcb_source_concentration_gr_50 = 'W') AND @pcb_manufacturer IS NULL OR @pcb_manufacturer = ''
				-- BEGIN
				--  SET @FormStatusFlag = 'P'
				-- END

				--IF (@pcb_concentration_50_499 = 'T' OR @pcb_concentration_500 = 'T' OR @pcb_source_concentration_gr_50 = 'T' OR @pcb_source_concentration_gr_50 = 'W') AND @pcb_article_for_TSCA_landfill IS NULL OR @pcb_article_for_TSCA_landfill = ''
				-- BEGIN
				--   SET @FormStatusFlag = 'P'
				-- END
				--ELSE
				-- BEGIN
				--   IF @pcb_article_for_TSCA_landfill = 'T'
				--    BEGIN
				--	 IF @pcb_article_decontaminated IS NULL OR @pcb_article_decontaminated = ''
				--	  BEGIN
				--	     SET @FormStatusFlag = 'P'
				--	  END
				--	END
				-- END

				-- PRINT @FormStatusFlag
			  --END
			    PRINT  '@pcb_manufacturer ' + @FormStatusFlag			   

				  IF(@pcb_concentration_50_499 = 'T' OR @pcb_concentration_500 = 'T' OR @pcb_source_concentration_gr_50 = 'T' OR @pcb_source_concentration_gr_50 = 'W')
				 BEGIN
					IF((ISNULL(@pcb_manufacturer, '') = ''))
					BEGIN
						SET @FormStatusFlag = 'P'
					END
					IF((ISNULL(@pcb_article_for_TSCA_landfill, '') = ''))
					BEGIN
						SET @FormStatusFlag = 'P'
					END
					ELSE IF(@pcb_article_for_TSCA_landfill = 'T' AND ISNULL(@pcb_article_decontaminated,'')='')
					BEGIN
					 SET @FormStatusFlag = 'P'
					END
				 END				

				 PRINT @FormStatusFlag
			  --END
             
			-- Validate
	   IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE FORM_ID =@formid AND revision_id = @Revision_ID  AND SECTION ='PB'))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'PB',@FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	  ELSE 
		BEGIN
			UPDATE FormSectionStatus SET section_status = @FormStatusFlag,date_modified=getdate(),modified_by=@web_userid WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'PB'
		END

END

GO
GRANT EXEC ON [dbo].[sp_Validate_PCB] TO COR_USER;

GO


--ALTER TABLE FormSectionStatus
--ADD isActive bit;

--SELECT TOP 1 isActive FROM FormSectionStatus

--UPDATE FormSectionStatus SET isActive = 1

--SELECT * FROM FormSectionStatus

