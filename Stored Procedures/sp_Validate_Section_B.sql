
CREATE PROCEDURE  [dbo].[sp_Validate_Section_B]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@Revision_ID int
AS



/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 9th Jan 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Section_B]


	Procedure to validate Section B required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID



Samples:
 EXEC [sp_Validate_Section_B] @form_id,@revision_ID
 EXEC [sp_Validate_Section_B] 459134, 1

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR;

	DECLARE @SourceCodeNullCount INT;
	DECLARE @RCRACodeCount INT;

	DECLARE @Sourcecode Varchar(10);
	DECLARE @Formcode Varchar(10);
	--DECLARE @Revision_ID INTEGER;

	SET @SectionType = 'SB'
	SET @TotalValidColumn = 2

	SET  @ValidColumnNullCount = (SELECT  (
				(CASE WHEN waste_common_name IS NULL OR waste_common_name = '' THEN 1 ELSE 0 END)
			  + (CASE WHEN gen_process IS NULL OR gen_process = '' THEN 1 ELSE 0 END)			 
		    ) AS sum_of_nulls
			From FormWcr
			Where 
			form_id =  @formid AND revision_id = @Revision_ID )
    
	PRINT 'VALID : ' + CAST(@ValidColumnNullCount AS VARCHAR)

	DECLARE @state_wastecode_none varchar(3)
	DECLARE @rcra_wastecode_none varchar(3)

	SELECT @state_wastecode_none = state_waste_code_flag, @rcra_wastecode_none = RCRA_waste_code_flag FROM FormWCR WHERE form_id =  @formid AND revision_id = @Revision_ID

	SET @RCRACodeCount = (Select COUNT(*) FROM FormXWasteCode where form_id = @formid and revision_id = @Revision_ID AND (specifier = 'rcra_characteristic' OR specifier = 'rcra_listed'))

	--Set @SourceCodeNullCount = (SELECT  COUNT(*) FROM dbo.WasteCode WHERE [status] = 'A' AND waste_code_origin = 'S' 
	--							AND [state] <> 'TX' AND [state] <> 'PA' AND haz_flag <> 'T' AND waste_code_uid  in 
	--							(select waste_code_uid	FROM FormXWasteCode fx where fx.form_id = @formid and fx.revision_id = @Revision_ID AND fx.specifier = 'state'))
   
    IF ((@rcra_wastecode_none <> 'T' AND @RCRACodeCount > 0))
	-- OR (@SourceCodeNullCount > 0 AND @state_wastecode_none <> 'T'))
	 BEGIN 
		SET @TotalValidColumn = @TotalValidColumn + 1
	   
		SELECT @Sourcecode=EPA_source_code , @Formcode=EPA_form_code FROM FormWcr Where form_id =  @formid AND revision_id = @Revision_ID

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


--DECLARE @Checking INTEGER;

--SET @Checking = (SELECT COUNT(*) FROM FormSectionStatus WHERE FORM_ID = @formid AND SECTION = 'SB')

IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE form_id = @formId AND revision_id = @Revision_id AND SECTION = 'SB'))
		BEGIN
		  INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'SB','Y',getdate(),1,getdate(),1,1)
		END
	ELSE 
	   BEGIN
    IF (@ValidColumnNullCount = 0)
    BEGIN
	     UPDATE FormSectionStatus SET section_status = 'Y' WHERE FORM_ID = @formid AND revision_id = @Revision_id AND SECTION = 'SB'
	END
    ELSE IF (@ValidColumnNullCount = @TotalValidColumn) 
    BEGIN
	    UPDATE FormSectionStatus SET section_status = 'C' WHERE FORM_ID = @formid AND revision_id = @Revision_id AND SECTION = 'SB'
    END
ELSE
   BEGIN
	  UPDATE FormSectionStatus SET section_status = 'P' WHERE FORM_ID = @formid AND revision_id = @Revision_id AND SECTION = 'SB'
   END
   END
END

GO
	GRANT EXEC ON [dbo].sp_Validate_Section_B TO COR_USER;
GO
