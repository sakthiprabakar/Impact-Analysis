GO
DROP PROCEDURE IF EXISTS [sp_Validate_Benzene]
GO
CREATE PROCEDURE  [dbo].[sp_Validate_Benzene]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@revision_ID INT,
	@web_userid nvarchar(200)
AS


/* ******************************************************************

	Updated By		: Sathik Ali
	Updated On		: 05-03-2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Benzene]


	Procedure to validate Benzene supplement required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID
	


Samples:
 EXEC [sp_Validate_Benzene] @form_id,@revision_ID
 EXEC [sp_Validate_Benzene] 496604, 1,'nyswyn100'
 EXEC [sp_Validate_Benzene] 600747, 1,'manand84'

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based SELECT Column count
	DECLARE @SectionType VARCHAR(3);
	
	DECLARE @FormStatusFlag varchar(1) = 'Y'
	
	SET @SectionType = 'BZ'
	SET @TotalValidColumn =16
	
	SET  @ValidColumnNullCount = (SELECT  (
				    (CASE WHEN wcr.generator_name IS NULL OR wcr.generator_name = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN wcr.epa_id IS NULL OR wcr.epa_id = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN fbz.originating_generator_name IS NULL OR fbz.originating_generator_name = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN fbz.originating_generator_epa_id IS NULL OR fbz.originating_generator_epa_id = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN wcr.waste_common_name IS NULL OR wcr.waste_common_name  = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN wcr.gen_process IS NULL OR wcr.gen_process = '' THEN 1 ELSE 0 END)	

				  +	(CASE WHEN wcr.signing_name IS NULL THEN 1 ELSE 0 END)
				  +	(CASE WHEN wcr.signing_title IS NULL THEN 1 ELSE 0 END)
				 -- +	(CASE WHEN wcr.signing_date IS NULL THEN 1 ELSE 0 END)
				 
				  +	(CASE WHEN fbz.type_of_facility IS NULL OR fbz.type_of_facility = '' OR fbz.type_of_facility = 'F' THEN 1 ELSE 0 END)

				  +	(CASE WHEN fbz.flow_weighted_annual_average_benzene IS NULL 
						OR CAST(fbz.flow_weighted_annual_average_benzene AS VARCHAR(15)) = '' 
						THEN 1 ELSE 0 END)
				  +	(CASE WHEN fbz.avg_h20_gr_10 <> 'T' AND fbz.avg_h20_gr_10 <> 'F' THEN 1 ELSE 0 END)
				  +	(CASE WHEN fbz.is_process_unit_turnaround IS NULL OR fbz.is_process_unit_turnaround = '' THEN 1 ELSE 0 END)

		    ) AS sum_of_nulls
			FROM FormWcr AS wcr
			INNER JOIN FormBenzene AS fbz ON wcr.form_id = fbz.wcr_id and wcr.revision_id = fbz.wcr_rev_id
			WHERE 
			wcr.form_id =  @formid and wcr.revision_id = @revision_ID)
			
			IF @ValidColumnNullCount != 0 
			 BEGIN
			    SET @FormStatusFlag = 'P'				
			 END

			 PRINT '@ValidColumnNullCount : ' + @FormStatusFlag

			--- Facility Total Annual Benzene Status (TAB):

			DECLARE @FacilityTotalCount INT ;
		   SET @FacilityTotalCount =  (SELECT  (
		            (CASE WHEN tab_lt_1_megagram IS NULL OR tab_lt_1_megagram = '' OR tab_lt_1_megagram = 'F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN tab_gte_1_and_lt_10_megagram IS NULL OR tab_gte_1_and_lt_10_megagram = '' 
						OR tab_gte_1_and_lt_10_megagram = 'F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN tab_gte_10_megagram IS NULL OR tab_gte_10_megagram = '' OR tab_gte_10_megagram = 'F' THEN 0 ELSE 1 END)
				  
            ) AS sum_of_phyStsnulls
			FROM FormBenzene
			WHERE 
			wcr_id =  @formid and wcr_rev_id = @revision_ID)	
           
		   IF @FacilityTotalCount = 0
			   BEGIN
			      SET @FormStatusFlag = 'P'				  
			   END

           PRINT '@FacilityTotalCount : ' + @FormStatusFlag
			--benzene_onsite_mgmt


			DECLARE  @benzene_onsite_mgmt CHAR(1)
			DECLARE  @benzene_range_from FLOAT
			DECLARE  @benzene_range_to FLOAT
			DECLARE  @classified_as_process_wastewater_stream CHAR(1)
			DECLARE  @classified_as_landfill_leachate CHAR(1)
			DECLARE  @classified_as_product_tank_drawdown CHAR(1)

			SELECT 
					@benzene_onsite_mgmt =benzene_onsite_mgmt,
					@benzene_range_from=benzene_range_from,
					@benzene_range_to=benzene_range_to,
					@classified_as_process_wastewater_stream=classified_as_process_wastewater_stream,
					@classified_as_landfill_leachate=classified_as_landfill_leachate,
					@classified_as_product_tank_drawdown= classified_as_product_tank_drawdown 
				FROM FormBenzene  
				WHERE wcr_id = @formid and wcr_rev_id = @revision_ID

			IF @benzene_onsite_mgmt IS NULL OR @benzene_onsite_mgmt = '' 
			 BEGIN
			   SET @FormStatusFlag = 'P'			   
			 END
			ELSE
			 BEGIN 
			   IF @benzene_onsite_mgmt = 'F'
				BEGIN
				    IF (isnumeric(@benzene_range_from) = 0  OR isnumeric(@benzene_range_to) = 0)
					 BEGIN
				         SET @FormStatusFlag = 'P'						 
				     END
				  
				  PRINT '@benzene_onsite_mgmt : ' + @FormStatusFlag

				  --DECLARE @classified_as_process_wastewater_stream CHAR(1)
				  --DECLARE @classified_as_landfill_leachate CHAR(1)
				  --DECLARE @classified_as_product_tank_drawdown CHAR(1)

				  SELECT @classified_as_process_wastewater_stream=classified_as_process_wastewater_stream
				  ,@classified_as_landfill_leachate=classified_as_landfill_leachate
				  ,@classified_as_product_tank_drawdown = classified_as_product_tank_drawdown 
					FROM FormBenzene
					WHERE 
					wcr_id =  @formid and wcr_rev_id = @revision_ID

					IF @classified_as_process_wastewater_stream != 'F' 
							AND @classified_as_landfill_leachate != 'F' 
							AND @classified_as_product_tank_drawdown != 'F'
					 BEGIN
						   DECLARE @benzeneCount int
						   SET @benzeneCount = (SELECT  (			 
							  (CASE WHEN classified_as_process_wastewater_stream IS NULL 
								OR classified_as_process_wastewater_stream = ''  
								THEN 0 ELSE 1 END)
							+ (CASE WHEN classified_as_landfill_leachate IS NULL 
								OR classified_as_landfill_leachate = ''  
								THEN 0 ELSE 1 END)
							+ (CASE WHEN classified_as_product_tank_drawdown IS NULL OR classified_as_product_tank_drawdown = ''  
								THEN 0 ELSE 1 END)		
								) AS sum_of_benzenulls
								FROM FormBenzene
								WHERE wcr_id =  @formid and wcr_rev_id = @revision_ID)	
			     
					   PRINT CAST(@benzeneCount AS VARCHAR(10))

						IF	@benzeneCount =0
						 BEGIN
							 SET @FormStatusFlag = 'P'							 
						  END

					  PRINT '@benzeneCount : ' + @FormStatusFlag
					 END	     			
			   END
			 END

      IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE FORM_ID =@formid AND revision_id = @Revision_ID  AND SECTION ='BZ'))
		BEGIN
			INSERT INTO FormSectionStatus 
			VALUES (@formid,@Revision_ID,'BZ',@FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	  ELSE 
		BEGIN
			UPDATE FormSectionStatus SET section_status = @FormStatusFlag 
			WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'BZ'
		END
END

GO
GRANT EXEC ON [dbo].[sp_Validate_Benzene] TO COR_USER;
GO