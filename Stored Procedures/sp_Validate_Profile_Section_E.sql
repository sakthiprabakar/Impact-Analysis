USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_Validate_Profile_Section_E]
GO
CREATE PROCEDURE  [dbo].[sp_Validate_Profile_Section_E]
		-- Add the parameters for the stored procedure here
		@profile_id INT
	AS



	/* ******************************************************************

		Updated By		: Monish V
		Updated On		: 30th Nov 2022
		Type			: Stored Procedure
		Object Name		: [sp_Validate_Profile_Section_E]


		Procedure to validate Section E required fields and Update the Status of section

	inputs 
	
		@profile_id



	Samples:
	 EXEC [sp_Validate_Profile_Section_E] @profile_id
	 EXEC [sp_Validate_Profile_Section_E] 699442
	 --exec sp_Validate_Profile_Section_E 699456
	****************************************************************** */
	BEGIN
		DECLARE @ValidColumnNullCount INTEGER;
		DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
		DECLARE @SectionType VARCHAR;
		--DECLARE @Revision_ID INTEGER;
		DECLARE @ProfileStatusFlag VARCHAR(1) = 'Y'

		DECLARE @texas_waste_material_type CHAR(1),
				@PA_residual_waste_flag CHAR(1),
				@RCRA_waste_code_flag CHAR(1),				
				@rcra_exempt_flag CHAR(1),
				@rcra_exempt_reason NVARCHAR(300);

		SELECT @texas_waste_material_type = texas_waste_material_type,
			   @PA_residual_waste_flag = PA_residual_waste_flag,
			   @RCRA_waste_code_flag =  RCRA_waste_code_flag, 
			   @rcra_exempt_flag = rcra_exempt_flag,
			   @rcra_exempt_reason = rcra_exempt_reason 
			   FROM [Profile] WHERE profile_id=@profile_id 

		DECLARE @state_waste_codes_exist BIT, 
		        @rcra_codes_exist BIT,
				@tx_waste_codes_exist BIT,
				@PA_Waste_codes_exist BIT,
				@rcra_F006toF019_exist BIT;

		SELECT @PA_Waste_codes_exist = case when [status] = 'A' AND waste_code_origin = 'S' AND [state] = 'PA' then 1 else 0 end,
		       @tx_waste_codes_exist = case when [state] ='TX' then 1 else 0 end,
			   @state_waste_codes_exist = case when waste_code_origin = 'S' AND [state] <> 'TX' AND [state] <> 'PA' then 1 else 0 end,
			   @rcra_codes_exist = case when [status] = 'A' AND waste_code_origin = 'F' AND haz_flag = 'T' AND waste_type_code IN ('L', 'C') then 1 else 0 end,
			   @rcra_F006toF019_exist = case when pw.waste_code_uid in (w.waste_code_uid) AND w.waste_code IN('F006','F007','F008','F009','F012','F019') then 1 else 0 end
			FROM ProfileWasteCode pw
		    INNER JOIN WasteCode as w
			ON  pw.waste_code_uid = w.waste_code_uid 
			WHERE profile_id=@profile_id; 


		DECLARE @state_waste_code_flag CHAR(1);
		DECLARE @cyanide_plating CHAR(1);
		DECLARE @info_basis_knowledge CHAR(1);
		DECLARE @info_basis_analysis CHAR(1);
		DECLARE @info_basis_msds CHAR(1);

		SELECT @state_waste_code_flag = state_waste_code_flag, 
		@cyanide_plating =cyanide_plating,
		@info_basis_knowledge = info_basis_knowledge,
		@info_basis_analysis = info_basis_analysis,
		@info_basis_msds = info_basis_msds
		FROM ProfileLab 			 
			WHERE profile_id = @profile_id AND [type] = 'A'

		--Check the Pennsylvania Residual Waste is checked 'T' and the PA state code is avaialble
		
		IF (@PA_residual_waste_flag = 'T' AND @PA_Waste_codes_exist = 0)
		BEGIN
			SET @ProfileStatusFlag = 'P'
		END

		-- 1. Texas State Waste Code:
		IF(
			(( @tx_waste_codes_exist = 0 AND @texas_waste_material_type IN ('I','N','U'))
				OR
			( @tx_waste_codes_exist = 1 AND @texas_waste_material_type NOT IN ('I','N','U')))

			OR(ISNULL(@PA_residual_waste_flag,'')= '')
			OR((@RCRA_waste_code_flag = 'F') AND ((ISNULL(@rcra_exempt_flag,'') = '') OR (@rcra_exempt_flag='T' AND ISNULL(@rcra_exempt_reason,'')='')))
			OR (@state_waste_code_flag<> 'F' AND @state_waste_codes_exist=0)
			OR(@RCRA_waste_code_flag<>'F' AND @rcra_codes_exist=0)
			OR (@rcra_F006toF019_exist = 1 AND ISNULL(@cyanide_plating,'')='')
			OR(@info_basis_knowledge <>'T' AND @info_basis_analysis <>'T' AND @info_basis_msds <>'T')
		  )
			BEGIN		
				SET @ProfileStatusFlag = 'P'
			END

		ELSE IF (EXISTS(select * from ProfileConstituent where profile_id=@profile_id 
			AND cor_lock_flag<>'T'
			AND
				(
					Isnull(tclp_flag, '') ='' OR
					Isnull(unit, '') =''	  							
					OR ((min_concentration is null OR concentration is null) AND typical_concentration is null)
					OR (concentration = 0 AND typical_concentration = 0)
					OR (min_concentration > concentration)
				)
			))
			BEGIN			
				SET @ProfileStatusFlag = 'P'
			END
		-- Update the form status in FormSectionStatus table
		IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE PROFILE_ID=@profile_id AND SECTION ='SE'))
		BEGIN
			INSERT INTO ProfileSectionStatus VALUES (@profile_id,'SE',@ProfileStatusFlag,getdate(),1,getdate(),1,1)
		END
		ELSE 
		BEGIN
			UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE PROFILE_ID=@profile_id AND SECTION = 'SE'
		END			
	
END



GO
GRANT EXEC ON [dbo].[sp_Validate_Profile_Section_E] TO COR_USER;
GO