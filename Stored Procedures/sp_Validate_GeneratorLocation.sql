
CREATE PROCEDURE  [dbo].[sp_Validate_GeneratorLocation]
	-- Add the parameters for the stored procedure here
	@formid INT,
    @Revision_ID int
AS

/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 11th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_GeneratorLocation]


	Procedure to validate Generator Location Supplement form required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID


Samples:
 EXEC [sp_Validate_GeneratorLocation] @form_id,@revision_ID
 EXEC [sp_Validate_GeneratorLocation] 430235, 1

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	--DECLARE @SectionType NVARCHAR;
	--DECLARE @Revision_ID INTEGER;
	DECLARE @Checking INTEGER;


	DECLARE @EPAIDValue VARCHAR(12);
	DECLARE @GenTypeId INT;
	SET @TotalValidColumn = 20


	SET  @ValidColumnNullCount = (SELECT  (
			(CASE WHEN generator_name IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN generator_city IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN generator_state IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN generator_zip IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN generator_country IS NULL THEN 1 ELSE 0 END)
			  --+ (CASE WHEN generator_phone IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN gen_mail_city IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN gen_mail_state IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN gen_mail_zip IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN gen_mail_country IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN tech_contact_name IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN tech_contact_phone IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN generator_type_ID IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN cust_name IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN cust_city IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN cust_state IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN cust_zip IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN cust_country IS NULL THEN 1 ELSE 0 END)
			  + (CASE WHEN NAICS_code IS NULL THEN 1 ELSE 0 END)

			   + (CASE WHEN cert_physical_matches_profile IS NULL THEN 1 ELSE 0 END)
			    + (CASE WHEN certification_flag IS NULL THEN 1 ELSE 0 END)
			   
		    ) AS sum_of_nulls
			From FormAddGeneratorLocation
			Where 
			form_id = @formid)


			-- EPD ID VALIDATION 

			
		--	SELECT @EPAIDValue=EPA_ID  FROM FormAddGeneratorLocation Where form_id = @formid 

		--	Select generator_type_id from GeneratorType where generator_type IN ('LQG','SQG')

			

			SET @Checking = (SELECT COUNT(*) FROM FormSectionStatus WHERE FORM_ID = @formid AND SECTION = 'GL')

			--IF @Checking = 0 
			-- BEGIN
   --           UPDATE FormWcr SET display_status_uid = (SELECT display_status_uid FROM FormDisplayStatus WHERE display_status = 'Draft') WHERE form_id = @formid
   --          END

--SET @Revision_ID = (SELECT form_version_id FROM Formwcr WHERE form_id =  @formid)

-- SECTION STATUS INSERT

--select @ValidColumnNullCount 
--select @Checking
IF (@ValidColumnNullCount = 0)
    IF @Checking = 0 
		BEGIN
		  INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'GL','Y',getdate(),1,getdate(),1,1)
		END
	ELSE 
	   BEGIN
	     UPDATE FormSectionStatus SET section_status = 'Y' WHERE FORM_ID = @formid AND SECTION = 'GL'
	   END
ELSE IF (@ValidColumnNullCount = @TotalValidColumn)
  IF @Checking = 0 
    BEGIN
	  INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'GL','C',getdate(),1,getdate(),1,1)
	END
  ELSE 
    BEGIN
	  UPDATE FormSectionStatus SET section_status = 'C' WHERE FORM_ID = @formid AND SECTION = 'GL'
    END
ELSE
  IF @Checking = 0 
   BEGIN
	  INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'GL','P',getdate(),1,getdate(),1,1)
   END
  ELSE 
   BEGIN
	  UPDATE FormSectionStatus SET section_status = 'P' WHERE FORM_ID = @formid AND SECTION = 'GL'
   END
END

GO
GRANT EXEC ON [dbo].[sp_Validate_GeneratorLocation] TO COR_USER;