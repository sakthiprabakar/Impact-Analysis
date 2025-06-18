USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Validate_Profile_LDR]    Script Date: 26-11-2021 12:55:42 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE  [dbo].[sp_Validate_Profile_LDR]
	-- Add the parameters for the stored procedure here
	@profile_id INT,
	@web_userid nvarchar(200)
AS


/* ******************************************************************

	 Updated By			: Divya Bharathi R  
	 Updated On			: 25th Feb 2025  
	 Type				: Stored Procedure  
	 Object Name		: [sp_Validate_Profile_LDR]  
	 Last Change		: Removed the validation for exceeds_LDR
	 Reference Ticket	: DE37954: UAT Bug: Express Renewal > Express Renewal Window is Not Retrieving Valid Candidates for Renewal
	 Purpose			: Procedure to validate LDR Supplement form required fields and Update the Status of section

Inputs:  
	
	@profile_id
	@web_userid

Samples:
 EXEC [sp_Validate_Profile_LDR] @profile_id,@web_userid
 EXEC [sp_Validate_Profile_LDR] 569914,'manand84'

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR(3);

	DECLARE @ProfileStatusFlag varchar(1) = 'Y'

	SET @SectionType = 'LR'
	SET @TotalValidColumn = 11

	
	SET  @ValidColumnNullCount = (SELECT top 1  (
				  	
				--  +	(CASE WHEN wcr.waste_water_flag IS NULL THEN 1 ELSE 0 END)
				--  +	(CASE WHEN wcr.more_than_50_pct_debris IS NULL THEN 1 ELSE 0 END)
				 	
				   (CASE WHEN pqa.LDR_req_flag <> 'T'and pqa.LDR_req_flag <> 'F' THEN 1 ELSE 0 END)
				  + (CASE WHEN (pr.waste_managed_id IS NULL OR pr.waste_managed_id =0)  THEN 1 ELSE 0 END)
				  				--  + (CASE WHEN (SELECT TOP 1 waste_code_uid FROM FormXWasteCode WHERE FORM_ID = @formid and revision_id =  @revision_ID ) IS NULL THEN 1 ELSE 0 END)
		    ) AS sum_of_nulls
			From ProfileQuoteApproval as pqa
			LEFT JOIN Profile as pr ON pqa.quote_id = pr.profile_id
			Where 
			pqa.quote_id = @profile_id)

			IF @ValidColumnNullCount >0
			 BEGIN
			  SET @ProfileStatusFlag = 'P'
			 END

		SELECT top 1 * INTO #tempProfile FROM Profile  WHERE profile_id=@profile_id 
		-- 2. State Waste Codes:
		IF(EXISTS(SELECT * FROM #tempProfile WHERE  ISNULL(constituents_requiring_treatment_flag,'')=''))
		BEGIN
			SET @ProfileStatusFlag = 'P'
		END

		IF(EXISTS(SELECT * FROM #tempProfile WHERE  ISNULL(constituents_requiring_treatment_flag,'')='T'))
		BEGIN
			IF(NOT EXISTS(SELECT * FROM ProfileConstituent WHERE requiring_treatment_flag='T' and profile_id=@profile_id)) 
			--AND Specifier='LDR-WO' AND exceeds_LDR='T'
			BEGIN
				SET @ProfileStatusFlag = 'P'
			END
		END

			 print @ProfileStatusFlag

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
	   IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE profile_id =@profile_id AND SECTION ='LR'))
		BEGIN
			INSERT INTO ProfileSectionStatus VALUES (@profile_id,'LR',@ProfileStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	  ELSE 
		BEGIN
			UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE profile_id = @profile_id AND SECTION = 'LR'
		END
END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_LDR] TO COR_USER;
GO
