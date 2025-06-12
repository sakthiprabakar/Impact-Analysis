USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Validate_Profile_Debris]    Script Date: 26-11-2021 12:46:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE  [dbo].[sp_Validate_Profile_Debris]
	-- Add the parameters for the stored procedure here
	@profile_id INT,
	@web_userid nvarchar(200)
AS


/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 11th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_Debris]


	Procedure to validate Debris supplement required fields and Update the Status of section

inputs 
	
	@profile_id
	@web_userid
	


Samples:
 EXEC [sp_Validate_Profile_Debris] @profile_id
 EXEC [sp_Validate_Profile_Debris] 517469,'manand84'

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR(3);
	
	DECLARE @ProfileStatusFlag varchar(1) = 'Y'
	
	SET @SectionType = 'DS'


	SET  @ValidColumnNullCount = (SELECT  (

		            (CASE WHEN pr.wcr_sign_name IS NULL OR pr.wcr_sign_name = '' THEN 1 ELSE  0 END)
				  +	(CASE WHEN pr.wcr_sign_title IS NULL OR pr.wcr_sign_title = '' THEN 1 ELSE 0 END)
				  -- +	(CASE WHEN wcr.signing_date IS NULL OR wcr.signing_date = '' THEN 1 ELSE 0 END)
				   --+ (CASE WHEN fpl.debris_certification_flag IS NULL OR fpl.debris_certification_flag = '' OR fpl.debris_certification_flag = 'F' THEN 1 ELSE 0 END)	
				    ) AS sum_of_nulls
			
			From Profile AS pr
			--INNER JOIN FormDebris as fpl on wcr.form_id = fpl.wcr_id AND wcr.revision_id = fpl.wcr_rev_id
			Where 
			pr.profile_id =  @profile_id)	
						
print cast(@ValidColumnNullCount as varchar(10))
	IF 	@ValidColumnNullCount > 0 
		BEGIN
		SET @ProfileStatusFlag = 'P'
	END			
		
    IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE profile_id =@profile_id AND SECTION ='DS'))
		BEGIN
			INSERT INTO ProfileSectionStatus VALUES (@profile_id,'DS',@ProfileStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	 ELSE 
		BEGIN
			UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE profile_id = @profile_id AND SECTION = 'DS'
		END
END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_Debris] TO COR_USER;
GO