
CREATE PROCEDURE  [dbo].[sp_Validate_LDR]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@revision_ID INT,
	@web_userid nvarchar(200)
AS


/* ******************************************************************

	Updated By		: Sathik Ali
	Updated On		: 05-03-19
	Type			: Stored Procedure
	Object Name		: [sp_Validate_LDR]


	Procedure to validate LDR Supplement form required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID



Samples:
 EXEC [sp_Validate_LDR] @form_id,@revision_ID
 EXEC [sp_Validate_LDR] 569914, 1 , 'manand84'

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR(3);

	DECLARE @FormStatusFlag varchar(1) = 'Y'

	SET @SectionType = 'LR'
	SET @TotalValidColumn = 11

	
	SET  @ValidColumnNullCount = (SELECT top 1  (
				  	
				--  +	(CASE WHEN wcr.waste_water_flag IS NULL THEN 1 ELSE 0 END)
				--  +	(CASE WHEN wcr.more_than_50_pct_debris IS NULL THEN 1 ELSE 0 END)
				 	
				   (CASE WHEN flr.ldr_notification_frequency <> 'T'and flr.ldr_notification_frequency <> 'F' THEN 1 ELSE 0 END)
				  + (CASE WHEN (flr.waste_managed_id IS NULL OR flr.waste_managed_id =0)  THEN 1 ELSE 0 END)
				  				--  + (CASE WHEN (SELECT TOP 1 waste_code_uid FROM FormXWasteCode WHERE FORM_ID = @formid and revision_id =  @revision_ID ) IS NULL THEN 1 ELSE 0 END)
		    ) AS sum_of_nulls
			From FormLDR as flr
						Where 
			flr.wcr_id =  @formid and flr.wcr_rev_id = @revision_ID)

			IF @ValidColumnNullCount >0
			 BEGIN
			  SET @FormStatusFlag = 'P'
			 END

		SELECT top 1 * INTO #tempFormLDRDetail FROM FormLDRDetail  WHERE form_id=@formid and revision_id=@Revision_ID 
		-- 2. State Waste Codes:
		IF(EXISTS(SELECT * FROM #tempFormLDRDetail WHERE  ISNULL(constituents_requiring_treatment_flag,'')=''))
		BEGIN
			SET @FormStatusFlag = 'P'
		END

		IF(EXISTS(SELECT * FROM #tempFormLDRDetail WHERE  ISNULL(constituents_requiring_treatment_flag,'')='T'))
		BEGIN
			IF(NOT EXISTS(SELECT * FROM FormXConstituent WHERE Exceeds_LDR='T' AND requiring_treatment_flag='T' AND Specifier='LDR-WO' and form_id=@formid and revision_id=@Revision_ID))
			BEGIN
				SET @FormStatusFlag = 'P'
			END
		END

			 print @FormStatusFlag

			 --DECLARE @waste_water_flag  CHAR (1)
			 --DECLARE @more_than_50_pct_debris CHAR(1)
			 --SELECT @waste_water_flag = waste_water_flag , @more_than_50_pct_debris = more_than_50_pct_debris FROM FormWcr WHERE form_id = @formid AND revision_id = @revision_ID

			 ----  Waste is a:
			 --IF ( @waste_water_flag IS NULL OR @waste_water_flag = '' ) OR (@more_than_50_pct_debris IS NULL OR @more_than_50_pct_debris = '')
			 -- BEGIN
				--SET @FormStatusFlag = 'P'
			 -- END
	 
	         -- Shipment EPA Waste Codes
			 --DECLARE @wasteCode INT
    --         SET @wasteCode =  (SELECT Count(*)  FROM FormXWasteCode WHERE FORM_ID = @formid and revision_id =  @revision_ID)

			 --IF @wasteCode = 0
			 -- BEGIN
			 --  SET @FormStatusFlag = 'P'
			 -- END
			    

	 
	  
-- Validate
	   IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE FORM_ID =@formid AND revision_id = @Revision_ID  AND SECTION ='LR'))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'LR',@FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	  ELSE 
		BEGIN
			UPDATE FormSectionStatus SET section_status = @FormStatusFlag,date_modified=getdate(),modified_by=@web_userid WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'LR'
		END
END

GO

	GRANT EXEC ON [dbo].[sp_Validate_LDR] TO COR_USER;

GO

