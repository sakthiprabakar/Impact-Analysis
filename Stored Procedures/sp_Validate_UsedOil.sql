
-- =============================================
-- Author:		<Author,,Sathick>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE  [dbo].[sp_Validate_UsedOil]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@revision_ID INT,
	@web_userid nvarchar(200)
AS
	

/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 9th Jan 2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_UsedOil]


	Procedure to validate Used Oil Section required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID


Samples:
 EXEC [sp_Validate_UsedOil] @form_id,@revision_ID
 EXEC [sp_Validate_UsedOil] 523932, 1, 'anand_m123'

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count
	DECLARE @SectionType VARCHAR(3);
	
	DECLARE @FormStatusFlag varchar(1) = 'Y'

	declare @wwa_halogen_list table
	(
		description nvarchar(50)
	)

	insert into @wwa_halogen_list values('Metalwork'),('Halogen'),('Chloroflu'),('Other')
	
	DECLARE @wwa_halogen_gt_1000 CHAR(1),
			@wwa_halogen_source  VARCHAR(10),
			@wwa_halogen_source_desc1 VARCHAR(100),
			@wwa_other_desc VARCHAR(100) 

		SELECT @wwa_halogen_gt_1000=wwa_halogen_gt_1000,@wwa_halogen_source=wwa_halogen_source,@wwa_halogen_source_desc1=wwa_halogen_source_desc1,@wwa_other_desc=wwa_other_desc_1 FROM FormWCR WHERE form_id = @formid AND revision_id = @revision_ID
			

	   IF (@wwa_halogen_gt_1000 IS NULL OR @wwa_halogen_gt_1000 = '')
        BEGIN
		  SET @FormStatusFlag = 'P'
		END
       ELSE
	    BEGIN
		  IF @wwa_halogen_gt_1000 = 'T'
		  BEGIN
		   IF (NOT EXISTS(select * from  @wwa_halogen_list where description in (@wwa_halogen_source))) -- IS NULL  OR @wwa_halogen_source = '' OR @wwa_halogen_source = 'F')
		    BEGIN 
			 SET @FormStatusFlag = 'P'
			END
           ELSE
		    BEGIN
				 IF @wwa_halogen_source = 'Halogen'
				   BEGIN 
				    print 'Halogen '
					 IF (@wwa_halogen_source_desc1 IS NULL OR @wwa_halogen_source_desc1 = '')
					 BEGIN 
					   print 'Halogen source '
					   SET @FormStatusFlag = 'P'
					 END
				   END

				IF @wwa_halogen_source = 'Other'
				   BEGIN 
				    print 'Other'
					 IF (@wwa_other_desc IS NULL OR @wwa_other_desc = '')
					 BEGIN 
					   print 'Other desc'
					   SET @FormStatusFlag = 'P'
					 END
				   END
            END
		 END
		END
	    
	   
    IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE FORM_ID =@formid AND revision_id = @Revision_ID  AND SECTION ='UL'))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'UL',@FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
	 ELSE 
		BEGIN
			UPDATE FormSectionStatus SET section_status = @FormStatusFlag,date_modified=getdate(),modified_by=@web_userid WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'UL'
		END

END


GO

GRANT EXEC ON [dbo].[sp_Validate_UsedOil] TO COR_USER;

GO