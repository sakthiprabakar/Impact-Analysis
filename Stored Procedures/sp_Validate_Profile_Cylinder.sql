USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Validate_Profile_Cylinder]    Script Date: 26-11-2021 12:43:41 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE  [dbo].[sp_Validate_Profile_Cylinder]
	-- Add the parameters for the stored procedure here
	@profile_id INT,
	@web_userid nvarchar(200)
AS


/* ******************************************************************

	Updated By		: Sathik Ali
	Updated On		: 05-03-2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_Cylinder]


	Procedure to validate Cylinder supplement required fields and Update the Status of section

inputs 
	
	@profile_id
	@web_userid
	


Samples:
 EXEC [sp_Validate_Profile_Cylinder] @profile_id
 EXEC [sp_Validate_Profile_Cylinder] 465809,'manand84'

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR(2);
	
	DECLARE @ProfileStatusFlag varchar(1) = 'Y'

	SET @SectionType = 'CR'
	SET @TotalValidColumn =13

	SET  @ValidColumnNullCount = (SELECT  (
				    (CASE WHEN cylinder_quantity IS NULL OR CAST(cylinder_quantity AS VARCHAR(15)) = '' THEN 1 ELSE 0 END)		
				  +	(CASE WHEN CGA_number IS NULL OR CGA_number = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN original_label_visible_flag IS NULL OR original_label_visible_flag = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN cylinder_type_id IS NULL OR cylinder_type_id = 0 THEN 1 ELSE 0 END)
				  +	(CASE WHEN external_condition IS NULL OR external_condition = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN cylinder_pressure IS NULL OR cylinder_pressure = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pressure_relief_device IS NULL OR pressure_relief_device = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN protective_cover_flag IS NULL OR protective_cover_flag = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN workable_valve_flag IS NULL OR workable_valve_flag = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN threads_impaired_flag IS NULL OR threads_impaired_flag = '' THEN 1 ELSE 0 END)
				--  +	(CASE WHEN valve_condition IS NULL THEN 1 ELSE 0 END)
		    ) AS sum_of_nulls
			From ProfileCGC
			Where 
			profile_id =  @profile_id)

			IF @ValidColumnNullCount != 0 
			 BEGIN
			  SET @ProfileStatusFlag = 'P'
			 END


			DECLARE @heaviest_gross_weight INT;
			DECLARE @heaviest_gross_weight_unit CHAR(1);

			DECLARE @DOT_shippable_flag CHAR(1);
			DECLARE @DOT_not_shippable_reason VARCHAR(255);

			DECLARE @poisonous_inhalation_flag CHAR(1);
			DECLARE @hazard_zone CHAR(1);

			DECLARE @external_condition CHAR(1)
 
            DECLARE @valve_condition CHAR(1)
			DECLARE @corrosion_color VARCHAR(20)

			SELECT @corrosion_color=corrosion_color,@valve_condition=valve_condition,@external_condition=external_condition,@hazard_zone=hazard_zone,@poisonous_inhalation_flag=poisonous_inhalation_flag,@DOT_not_shippable_reason=DOT_not_shippable_reason,@DOT_shippable_flag=DOT_shippable_flag,@heaviest_gross_weight=heaviest_gross_weight,@heaviest_gross_weight_unit=heaviest_gross_weight_unit FROM ProfileCGC WHERE profile_id = @profile_id

			-- DOT Shippable Flag 
			IF @DOT_shippable_flag IS NULL OR @DOT_shippable_flag = ''
			 BEGIN
			  SET @ProfileStatusFlag = 'P'
			 END
		    ELSE
		     BEGIN			  
			   IF @DOT_shippable_flag = 'F' 
			    BEGIN
				  IF @DOT_not_shippable_reason IS NULL OR @DOT_not_shippable_reason = '' 
				   BEGIN
				     SET @ProfileStatusFlag = 'P'
				   END
				END
			 END
			print @poisonous_inhalation_flag
			print @hazard_zone
			 -- Poisonous Inhalation Hazard:
            IF @poisonous_inhalation_flag IS NULL OR @poisonous_inhalation_flag = ''
			 BEGIN
			  SET @profileStatusFlag = 'P'
			  print 1
			 END
			ELSE
			 BEGIN
			  IF @poisonous_inhalation_flag = 'T' AND (@hazard_zone IS NULL OR @hazard_zone = '')
			   BEGIN
			   print 2
			    SET @ProfileStatusFlag = 'P'
			   END
			 END
			   print @ProfileStatusFlag
			 -- Valve Condition is If corroded, color of corrosion:

		    IF @valve_condition IS NULL OR @valve_condition = ''
			 BEGIN
			  SET @ProfileStatusFlag = 'P'
			 END
			ELSE
			 BEGIN
			   IF @valve_condition = 'C'
			    BEGIN
				  IF @corrosion_color IS NULL OR @corrosion_color = '' 
				   BEGIN
				     SET @ProfileStatusFlag = 'P'
				   END
				END
			 END


			 -- Validate
	       IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE profile_id =@profile_id AND SECTION ='CR'))
		BEGIN
			INSERT INTO ProfileSectionStatus VALUES (@profile_id,'CR',@ProfileStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	  ELSE 
		BEGIN
			UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE profile_id = @profile_id AND SECTION = 'CR'
		END


		 --  IF @heaviest_gross_weight_unit IS NULL 
		 --   BEGIN 
			-- SET @TotalValidColumn = @TotalValidColumn + 1
			-- SET @ValidColumnNullCount = @ValidColumnNullCount + 1
			--END
   --        ELSE
		 --    IF @heaviest_gross_weight_unit = 'P' OR  @heaviest_gross_weight_unit = 'K'
			--   BEGIN 
			--     IF  @heaviest_gross_weight IS NULL OR LEN(@heaviest_gross_weight) = 0
			--	 BEGIN 
			--      SET @TotalValidColumn = @TotalValidColumn + 1
			--      SET @ValidColumnNullCount = @ValidColumnNullCount + 1
			--     END
			--   END
	
END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_Cylinder] TO COR_USER;
GO