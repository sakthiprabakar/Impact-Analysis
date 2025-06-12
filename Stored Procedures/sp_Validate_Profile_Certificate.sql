USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Validate_Profile_Certificate]    Script Date: 26-11-2021 12:24:52 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE  [dbo].[sp_Validate_Profile_Certificate]
	-- Add the parameters for the stored procedure here
	@profile_id INT,
	@web_userid nvarchar(200)
AS


/* ******************************************************************

	Updated By		: Sathik Ali 
	Updated On		: 05-03-2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_Certificate]


	Procedure to validate Certificate supplement required fields and Update the Status of section

inputs 
	
	@profile_id
	@web_userid
	


Samples:
 EXEC [sp_Validate_Profile_Certificate] @profile_id
 EXEC [sp_Validate_Profile_Certificate] 459548,'nyswyn100'

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR(3);
	
	DECLARE @ProfileStatusFlag varchar(1) = 'Y'
	
	SET @SectionType = 'CN'
	SET @TotalValidColumn =9 
	
	SET  @ValidColumnNullCount = (SELECT  (

						
				    (CASE WHEN g.generator_name IS NULL OR g.generator_name  = '' THEN 1 ELSE 0 END)		
				  +	(CASE WHEN g.generator_address_1 IS NULL OR g.generator_address_1 = '' THEN 1 ELSE 0 END)				 
				  +	(CASE WHEN g.generator_city IS NULL OR g.generator_city = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN g.generator_state IS NULL OR  g.generator_state = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN g.generator_zip_code IS NULL  OR g.generator_zip_code = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pr.wcr_sign_name IS NULL OR pr.wcr_sign_name = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN pr.wcr_sign_name IS NULL OR pr.wcr_sign_name = '' THEN 1 ELSE 0 END)
				 -- +	(CASE WHEN wcr.signing_date IS NULL OR wcr.signing_date = '' THEN 1 ELSE 0 END)
		    ) AS sum_of_nulls
			From Profile AS pr
			LEFT JOIN Generator As g ON pr.generator_id = g.generator_id
			Where 
			pr.profile_id =  @profile_id)

	   IF @ValidColumnNullCount != 0
	    BEGIN
		  SET @ProfileStatusFlag = 'P'
		END

		PRINT 'Gen : ' + @ProfileStatusFlag

		DECLARE @vsqg_cesqg_accept_flag  CHAR (1)
		SELECT @vsqg_cesqg_accept_flag = vsqg_cesqg_accept_flag FROM Profile WHERE profile_id = @profile_id

		IF @vsqg_cesqg_accept_flag IS NULL OR @vsqg_cesqg_accept_flag = '' OR @vsqg_cesqg_accept_flag = 'F'
		 BEGIN
		  SET @ProfileStatusFlag = 'P'
		 END

       PRINT 'AcceptFlag  : ' + @vsqg_cesqg_accept_flag

	-- Validate
	   IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus WHERE profile_id =@profile_id AND SECTION ='CN'))
		BEGIN
			INSERT INTO ProfileSectionStatus VALUES (@profile_id,'CN',@ProfileStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	  ELSE 
		BEGIN
			UPDATE ProfileSectionStatus SET section_status = @ProfileStatusFlag WHERE profile_id = @profile_id AND SECTION = 'CN'
		END
END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_Certificate] TO COR_USER;
GO