USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_Validate_Profile_Section_E]
GO
CREATE PROCEDURE  [dbo].[sp_Validate_Profile_Section_E]
		@profile_id INT
	AS
	BEGIN    

	/* ******************************************************************
	
		Updated By			: Senthilkumar I
		Updated On			: 28th Feb 2025
		Ticket				: DE38160
		Change				: texas_waste_material_type condition U to A changed		
		Inputs				: @profile_id					
		Execution Statement	: EXEC [plt_ai].[dbo].[sp_Validate_Profile_Section_E] 652046

	****************************************************************** */
		DECLARE @ProfileStatusFlag CHAR(1) = 'Y',
                @texas_waste_material_type CHAR(1),
				@PA_residual_waste_flag CHAR(1),
				@RCRA_waste_code_flag CHAR(1),				
				@rcra_exempt_flag CHAR(1),
				@rcra_exempt_reason NVARCHAR(255);

		SELECT TOP 1
               @texas_waste_material_type = texas_waste_material_type,
			   @PA_residual_waste_flag = PA_residual_waste_flag,
			   @RCRA_waste_code_flag =  RCRA_waste_code_flag, 
			   @rcra_exempt_flag = rcra_exempt_flag,
			   @rcra_exempt_reason = rcra_exempt_reason 
			   FROM [Profile] WHERE profile_id=@profile_id;

		DECLARE @state_waste_codes_exist BIT, 
		        @rcra_codes_exist BIT,
				@tx_waste_codes_exist BIT,
				@PA_Waste_codes_exist BIT,
				@rcra_F006toF019_exist BIT;

		SELECT @PA_Waste_codes_exist = CASE WHEN [status] = 'A' AND waste_code_origin = 'S' AND [state] = 'PA' THEN 1 ELSE 0 END,  
			   @tx_waste_codes_exist = CASE WHEN [state] = 'TX' THEN 1 ELSE 0 END,  
			   @state_waste_codes_exist = CASE WHEN waste_code_origin = 'S' AND [state] NOT IN ('TX', 'PA') THEN 1 ELSE 0 END,  
			   @rcra_codes_exist = CASE WHEN [status] = 'A' AND waste_code_origin = 'F' AND haz_flag = 'T' AND waste_type_code IN ('L', 'C') THEN 1 ELSE 0 END,  
			   @rcra_F006toF019_exist = CASE WHEN w.waste_code IN ('F006','F007','F008','F009','F012','F019') THEN 1 ELSE 0 END
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
			WHERE profile_id = @profile_id AND [type] = 'A';

		--Check the Pennsylvania Residual Waste is checked 'T' and the PA state code is avaialble
		
		IF (@PA_residual_waste_flag = 'T' AND @PA_Waste_codes_exist = 0)
		BEGIN
			SET @ProfileStatusFlag = 'P';
		END

		-- 1. Texas State Waste Code:
		IF(
			(( @tx_waste_codes_exist = 0 AND @texas_waste_material_type IN ('I','N','A'))
				OR
			( @tx_waste_codes_exist = 1 AND @texas_waste_material_type NOT IN ('I','N','A')))

			OR(@PA_residual_waste_flag IS NULL OR @PA_residual_waste_flag = '')
			OR((@RCRA_waste_code_flag = 'F') AND ((@rcra_exempt_flag IS NULL OR @rcra_exempt_flag = '') OR (@rcra_exempt_flag='T' AND (@rcra_exempt_reason IS NULL OR @rcra_exempt_reason = ''))))
			OR (@state_waste_code_flag<> 'F' AND @state_waste_codes_exist=0)
			OR(@RCRA_waste_code_flag<>'F' AND @rcra_codes_exist=0)
			OR (@rcra_F006toF019_exist = 1 AND (@cyanide_plating IS NULL OR @cyanide_plating = ''))
			OR(@info_basis_knowledge <>'T' AND @info_basis_analysis <>'T' AND @info_basis_msds <>'T')
		  )
			BEGIN		
				SET @ProfileStatusFlag = 'P';
			END

		ELSE IF (EXISTS(select 1 from ProfileConstituent where profile_id=@profile_id 
			AND cor_lock_flag<>'T'
			AND
				(
					(tclp_flag IS NULL OR tclp_flag = '') OR
					(unit IS NULL OR unit = '')	  							
					OR ((min_concentration is null OR concentration is null) AND typical_concentration is null)
					OR (concentration = 0 AND typical_concentration = 0)
					OR (min_concentration > concentration)
				)
			))
			BEGIN			
				SET @ProfileStatusFlag = 'P';
			END
		-- Update the form status in FormSectionStatus table
		IF(NOT EXISTS(SELECT 1 FROM ProfileSectionStatus WHERE PROFILE_ID=@profile_id AND SECTION ='SE'))
		BEGIN
			INSERT INTO ProfileSectionStatus (profile_id,section,section_status,date_created,created_by,date_modified,modified_by,isActive)
            VALUES (@profile_id,'SE',@ProfileStatusFlag,getdate(),1,getdate(),1,1);
		END
		ELSE 
		BEGIN
			UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE PROFILE_ID=@profile_id AND SECTION = 'SE';
		END			
	
END

GO
GRANT EXEC ON [dbo].[sp_Validate_Profile_Section_E] TO COR_USER;
GO