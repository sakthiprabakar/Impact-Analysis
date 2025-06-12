USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Validate_Profile_Benzene]    Script Date: 26-11-2021 12:09:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE  [dbo].[sp_Validate_Profile_Benzene]
	-- Add the parameters for the stored procedure here
	@profile_id INT,
	@web_userid nvarchar(200)
AS


/* ******************************************************************

	Updated By		: Sathik Ali
	Updated On		: 05-03-2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_Benzene]


	Procedure to validate Benzene supplement required fields and Update the Status of section

inputs 
	
	@profile_id
	@web_userid
	


Samples:
 EXEC [sp_Validate_Profile_Benzene] @profile_id,@web_userid
 EXEC [sp_Validate_Profile_Benzene] 496604,'nyswyn100'
 --exec sp_Validate_Profile_Benzene 699442,'manand84'

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR(3);
	
	DECLARE @ProfileStatusFlag varchar(1) = 'Y'
	
	SET @SectionType = 'BZ'
	SET @TotalValidColumn =16
	
	SET  @ValidColumnNullCount = (SELECT  (
				    (CASE WHEN g.generator_name IS NULL OR g.generator_name = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN g.EPA_ID IS NULL OR g.EPA_ID = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pbz.originating_generator_name IS NULL OR pbz.originating_generator_name = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pbz.originating_generator_epa_id IS NULL OR pbz.originating_generator_epa_id = '' THEN 1 ELSE 0 END)
				 -- +	(CASE WHEN pr.waste_common_name IS NULL OR pr.waste_common_name  = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pr.gen_process IS NULL OR pr.gen_process = '' THEN 1 ELSE 0 END)	

				  +	(CASE WHEN pr.wcr_sign_name IS NULL THEN 1 ELSE 0 END)
				  +	(CASE WHEN pr.wcr_sign_title IS NULL THEN 1 ELSE 0 END)
				 -- +	(CASE WHEN wcr.signing_date IS NULL THEN 1 ELSE 0 END)
				 
				  +	(CASE WHEN pbz.type_of_facility IS NULL OR pbz.type_of_facility = '' OR pbz.type_of_facility = 'F' THEN 1 ELSE 0 END)

				  +	(CASE WHEN pbz.flow_weighted_annual_average_benzene IS NULL OR CAST(pbz.flow_weighted_annual_average_benzene AS VARCHAR(15)) = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pl.avg_h20_gr_10 <> 'T' AND pl.avg_h20_gr_10 <> 'F' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pbz.is_process_unit_turnaround IS NULL OR pbz.is_process_unit_turnaround = '' THEN 1 ELSE 0 END)

		    ) AS sum_of_nulls
			FROM  Profile AS pr
           LEFT JOIN Generator AS g ON pr.generator_id = g.generator_id
           LEFT JOIN ProfileBenzene AS pbz ON pr.profile_id=pbz.profile_id
           LEFT JOIN ProfileLab AS pl ON pbz.profile_Id =pl.profile_Id
          WHERE  
	     pr.profile_id = @profile_id and  pl.type = 'A')
			
			IF @ValidColumnNullCount != 0 
			 BEGIN
			    SET @ProfileStatusFlag = 'P'
			 END

			 PRINT '@ValidColumnNullCount : ' + @ProfileStatusFlag

			--- Facility Total Annual Benzene Status (TAB):

			DECLARE @FacilityTotalCount INT ;
		   SET @FacilityTotalCount =  (SELECT  (
		            (CASE WHEN tab_lt_1_megagram IS NULL OR tab_lt_1_megagram = '' OR tab_lt_1_megagram = 'F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN tab_gte_1_and_lt_10_megagram IS NULL OR tab_gte_1_and_lt_10_megagram = '' OR tab_gte_1_and_lt_10_megagram = 'F' THEN 0 ELSE 1 END)
				  +	(CASE WHEN tab_gte_10_megagram IS NULL OR tab_gte_10_megagram = '' OR tab_gte_10_megagram = 'F' THEN 0 ELSE 1 END)
				  
            ) AS sum_of_phyStsnulls
			From ProfileBenzene
			Where 
			profile_id =  @profile_id)	
           
		   IF @FacilityTotalCount = 0
			   BEGIN
			      SET @ProfileStatusFlag = 'P'
			   END

           PRINT '@FacilityTotalCount : ' + @ProfileStatusFlag
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
					@classified_as_product_tank_drawdown=classified_as_product_tank_drawdown 
				from ProfileBenzene As pbz
				LEFT JOIN ProfileLab as pl on pbz.profile_id = pl.profile_id
				WHERE pl.profile_id = @profile_id and pl.type = 'A'

			IF @benzene_onsite_mgmt IS NULL OR @benzene_onsite_mgmt = '' 
			 BEGIN
			   SET @ProfileStatusFlag = 'P'
			 END
			ELSE
			 BEGIN 
			   IF @benzene_onsite_mgmt = 'F'
				BEGIN
				    IF (@benzene_range_from IS NULL OR CAST(@benzene_range_from AS varchar(15)) = '' OR @benzene_range_from =0 ) AND ( @benzene_range_to IS NULL OR CAST( @benzene_range_to AS varchar(15)) = '' OR @benzene_range_to =0 )
					 BEGIN
				         SET @ProfileStatusFlag = 'P'
				     END
				  
				  PRINT '@benzene_onsite_mgmt : ' + @ProfileStatusFlag

				  --DECLARE @classified_as_process_wastewater_stream CHAR(1)
				  --DECLARE @classified_as_landfill_leachate CHAR(1)
				  --DECLARE @classified_as_product_tank_drawdown CHAR(1)

				  SELECT @classified_as_process_wastewater_stream=classified_as_process_wastewater_stream,@classified_as_landfill_leachate=classified_as_landfill_leachate,@classified_as_product_tank_drawdown = classified_as_product_tank_drawdown From ProfileBenzene
					Where 
					profile_id =  @profile_id

					IF @classified_as_process_wastewater_stream != 'F' AND @classified_as_landfill_leachate != 'F' AND @classified_as_product_tank_drawdown != 'F'
					 BEGIN
						   DECLARE @benzeneCount int
						   SET @benzeneCount = (SELECT  (			 
							  (CASE WHEN classified_as_process_wastewater_stream IS NULL OR classified_as_process_wastewater_stream = ''  THEN 0 ELSE 1 END)
							+ (CASE WHEN classified_as_landfill_leachate IS NULL OR classified_as_landfill_leachate = ''  THEN 0 ELSE 1 END)
							+ (CASE WHEN classified_as_product_tank_drawdown IS NULL OR classified_as_product_tank_drawdown = ''  THEN 0 ELSE 1 END)							
														) AS sum_of_benzenulls
														From ProfileBenzene
														Where 
														profile_id =  @profile_id)	
			     
					   PRINT CAST(@benzeneCount AS VARCHAR(10))

						IF	@benzeneCount =0
						 BEGIN
							 SET @ProfileStatusFlag = 'P'
						  END

					  PRINT '@benzeneCount : ' + @ProfileStatusFlag
					 END

	     			
			   END
			 END

	        



      IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE profile_id =@profile_id AND SECTION ='BZ'))
		BEGIN
			INSERT INTO ProfileSectionStatus VALUES (@profile_id,'BZ',@ProfileStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	  ELSE 
		BEGIN
			UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE profile_id = @profile_id AND SECTION = 'BZ'
		END
END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_Benzene] TO COR_USER;
GO