
CREATE PROCEDURE  [dbo].[sp_Validate_Debris]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@revision_ID INT,
	@web_userid nvarchar(200)
AS


/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 11th Feb 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Debris]


	Procedure to validate Debris supplement required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID
	


Samples:
 EXEC [sp_Validate_Debris] @form_id,@revision_ID
 EXEC [sp_Validate_Debris] 430235, 1

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR(3);
	
	DECLARE @FormStatusFlag varchar(1) = 'Y'
	
	SET @SectionType = 'DS'


	SET  @ValidColumnNullCount = (SELECT  (

		            (CASE WHEN wcr.signing_name IS NULL OR wcr.signing_name = '' THEN 1 ELSE  0 END)
				  +	(CASE WHEN wcr.signing_title IS NULL OR wcr.signing_title = '' THEN 1 ELSE 0 END)
				  -- +	(CASE WHEN wcr.signing_date IS NULL OR wcr.signing_date = '' THEN 1 ELSE 0 END)
				   --+ (CASE WHEN fpl.debris_certification_flag IS NULL OR fpl.debris_certification_flag = '' OR fpl.debris_certification_flag = 'F' THEN 1 ELSE 0 END)	
				    ) AS sum_of_nulls
			
			From FormWcr AS wcr
			INNER JOIN FormDebris as fpl on wcr.form_id = fpl.wcr_id AND wcr.revision_id = fpl.wcr_rev_id
			Where 
			wcr.form_id =  @formid and wcr.revision_id = @revision_ID)	
						
print cast(@ValidColumnNullCount as varchar(10))
IF 	@ValidColumnNullCount != 0 
	 BEGIN
	  SET @FormStatusFlag = 'P'
	 END			
		
    IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE FORM_ID =@formid AND revision_id = @Revision_ID  AND SECTION ='DS'))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'DS',@FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	 ELSE 
		BEGIN
			UPDATE FormSectionStatus SET section_status = @FormStatusFlag,date_modified=getdate(),modified_by=@web_userid WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'DS'
		END
END

GO
GRANT EXEC ON [dbo].[sp_Validate_Debris] TO COR_USER;

GO