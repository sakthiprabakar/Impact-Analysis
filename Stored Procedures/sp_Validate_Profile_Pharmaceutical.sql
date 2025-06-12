USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Validate_Profile_Pharmaceutical]    Script Date: 26-11-2021 13:04:35 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE  [dbo].[sp_Validate_Profile_Pharmaceutical]
	-- Add the parameters for the stored procedure here
	@profile_id INT,
	@web_userid nvarchar(200)
AS


/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 9th Jan 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_Pharmaceutical]


	Procedure to validate Pharmaceutical Supplement form required fields and Update the Status of section

inputs 
	
	@profile_id



Samples:
 EXEC [sp_Validate_Profile_Pharmaceutical] @profile_id
 EXEC [sp_Validate_Profile_Pharmaceutical] 902383

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR;

	DECLARE @ProfileStatusFlag VARCHAR(1) = 'Y';
	
	
	SET @SectionType = 'PL'
	SET @TotalValidColumn = 1

	SET  @ValidColumnNullCount = (SELECT  (
		    --        (CASE WHEN wcr.signing_name IS NULL OR wcr.signing_name = '' THEN 1 ELSE  0 END)
				  --+	(CASE WHEN wcr.signing_title IS NULL OR wcr.signing_title = '' THEN 1 ELSE 0 END)
				  --+	(CASE WHEN wcr.signing_date IS NULL OR wcr.signing_date = '' THEN 1 ELSE 0 END)
				  + (CASE WHEN pr.pharmaceutical_flag IS NULL OR pr.pharmaceutical_flag = '' OR pr.pharmaceutical_flag = 'F' THEN 1 ELSE 0 END)	
				    ) AS sum_of_nulls
			From Profile AS pr
			Where 
			pr.profile_id =  @profile_id)	
		
	--	select pharm_certification_flag from FormPharmaceutical where form_id = 459314
	print cast( @ValidColumnNullCount as varchar(10))

	IF 	@ValidColumnNullCount != 0 
	 BEGIN
	  SET @ProfileStatusFlag = 'P'
	 END			
		
    IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE profile_id =@profile_id AND SECTION ='PL'))
		BEGIN
			INSERT INTO ProfileSectionStatus VALUES (@profile_id,'PL',@ProfileStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	 ELSE 
		BEGIN
			UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE profile_id = @profile_id AND SECTION = 'PL'
		END
END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_Pharmaceutical] TO COR_USER;
GO