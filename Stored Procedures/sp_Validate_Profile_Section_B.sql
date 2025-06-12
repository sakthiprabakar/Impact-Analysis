USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_Validate_Profile_Section_B]    Script Date: 25-11-2021 20:15:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE  [dbo].[sp_Validate_Profile_Section_B]
	-- Add the parameters for the stored procedure here
	@profile_id INT
	
AS



/* ******************************************************************

	Updated By		: Prabhu
	Updated On		: 17th Sep 2021
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Profile_Section_B]


	Procedure to validate Section B required fields and Update the Status of section

inputs 
	
	@profile_id
	


Samples:
 EXEC [sp_Validate_Profile_Section_B] @profile_id
 EXEC [sp_Validate_Profile_Section_B] 459134

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR;

	DECLARE @SourceCodeNullCount INT;
	DECLARE @RCRACodeCount INT;

	DECLARE @Sourcecode Varchar(10);
	DECLARE @Formcode Varchar(10);
	

	SET @SectionType = 'SB'
	SET @TotalValidColumn = 2

	SET  @ValidColumnNullCount = (SELECT  (
				(CASE WHEN approval_desc IS NULL  OR approval_desc = ''  THEN 1 ELSE 0 END)
			  +(CASE WHEN gen_process IS NULL OR gen_process = '' THEN 1 ELSE 0 END)			 
		    ) AS sum_of_nulls
			From Profile
			Where 
			profile_id =  @profile_id)
    
	PRINT 'VALID : ' + CAST(@ValidColumnNullCount AS VARCHAR)

	DECLARE @state_wastecode_none varchar(3)
	DECLARE @rcra_wastecode_none varchar(3)

	SELECT @state_wastecode_none = state_waste_code_flag FROM profilelab WHERE profile_id =@profile_id
	SELECT @rcra_wastecode_none =  RCRA_waste_code_flag FROM profile WHERE profile_id =@profile_id

	--SET @RCRACodeCount = (Select COUNT(*) FROM ProfileWasteCode where profile_id =@profile_id AND (specifier = 'rcra_characteristic' OR specifier = 'rcra_listed'))

     SET @RCRACodeCount =  (select COUNT('RCRA') as specifier from ProfileWasteCode as pw inner join WasteCode as w
     on pw.waste_code_uid = w.waste_code_uid
     where profile_id=@profile_id and [status] = 'A' AND waste_code_origin = 'F' AND haz_flag = 'T' AND waste_type_code IN ('L', 'C'))

    IF ((@rcra_wastecode_none <> 'T' AND @RCRACodeCount > 0))
	 BEGIN 
		SET @TotalValidColumn = @TotalValidColumn + 1
	   
		SELECT @Sourcecode=EPA_source_code , @Formcode=EPA_form_code FROM Profile Where profile_id = @profile_id 

		IF (@Sourcecode = '' or @Sourcecode is null) OR (@Formcode = '' or @Formcode is null)
	    BEGIN
		 SET @ValidColumnNullCount = @ValidColumnNullCount + 1
		END
		ELSE
	    BEGIN 
		 SET @ValidColumnNullCount = @ValidColumnNullCount + 0
		END	  
	 END 
  
     print 'TotalCount' + CAST(@TotalValidColumn AS VARCHAR)
	 print 'ValidCount' + CAST(@ValidColumnNullCount AS VARCHAR)




  IF(NOT EXISTS(SELECT * FROM ProfileSectionStatus  WHERE PROFILE_ID = @profile_id AND SECTION = 'SB'))
		BEGIN
		  INSERT INTO ProfileSectionStatus VALUES (@profile_id,'SB','Y',getdate(),1,getdate(),1,1)
		END
	ELSE 
	   BEGIN
    IF (@ValidColumnNullCount = 0)
    BEGIN
	     UPDATE ProfileSectionStatus SET section_status = 'Y' WHERE PROFILE_ID = @profile_id AND SECTION = 'SB'
	END
    ELSE IF (@ValidColumnNullCount = @TotalValidColumn) 
    BEGIN
	    UPDATE ProfileSectionStatus SET section_status = 'C' WHERE PROFILE_ID = @profile_id AND SECTION = 'SB'
    END
ELSE
   BEGIN
	  UPDATE ProfileSectionStatus SET section_status = 'P' WHERE PROFILE_ID = @profile_id AND SECTION = 'SB'
   END
   END
  END

GO
	GRANT EXEC ON [dbo].[sp_Validate_Profile_Section_B] TO COR_USER;
GO
