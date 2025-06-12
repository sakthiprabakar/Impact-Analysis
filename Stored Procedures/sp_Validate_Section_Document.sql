USE PLT_AI
GO
DROP PROC IF EXISTS sp_Validate_Section_Document
GO
CREATE PROCEDURE  [dbo].[sp_Validate_Section_Document]
	-- Add the parameters for the stored procedure here
	@form_id INT,
    @revision_id int
AS



/* ******************************************************************

	Updated By		: Dineshkumar
	Updated On		: 11th Feb 2019
  	Decription       : Validation for document attachment in profile creation
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Section_Document]
	Updated By		: Sathiyamoorthi M
	Updated On		: 28th Nov 2024
	Ticket: 99741

	
Description:

	Validating document rows
	

inputs 
	
	@form_id
	@revision_id
	


Samples:
 EXEC [sp_Validate_Section_Document] 
						@form_id,
						@revision_id

	 EXEC [dbo].[sp_Validate_Section_Document] '484646','1'


****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;
	DECLARE @TotalValidColumn INTEGER; -- Based Select Column count

	DECLARE @Checking INTEGER;
	DECLARE @CheckStatus Char(1);

	DECLARE @LabAnalysis CHAR(1);
	DECLARE @Msds CHAR(1);
	declare @profile_id int;
	SET @TotalValidColumn = 18
	DECLARE @section_status CHAR(1)='Y'

	        IF(NOT EXISTS(SELECT * FROM  FormSectionStatus WHERE form_id = @form_id AND revision_id=@revision_id AND SECTION = 'DA'))
	        BEGIN		
				INSERT INTO FormSectionStatus VALUES (@form_id,@revision_id,'DA','Y',getdate(),1,getdate(),1,1)
			END
			
			SELECT @profile_id = profile_id, @LabAnalysis=info_basis_analysis,@Msds=info_basis_msds FROM FORMWCR Where form_id = @form_id AND revision_id = @revision_id

		    IF @LabAnalysis = 'T'
			  BEGIN  
			      -- Condition Check
				  DECLARE @LDR_TypeCode NVARCHAR(50) = (SELECT [type_code] FROM plt_Image..[ScanDocumentType] 
				  where scan_type = 'approval' AND document_type = 'COR Lab Analysis')
				 
				  DECLARE @LDR_image_id INT = (SELECT Top 1 image_id FROM Plt_Image..Scan 
							WHERE	
							(
								(form_id = @form_id and revision_id=@revision_id)
								or (profile_id = @profile_id and @profile_id is not null)
							)
							 AND document_source = @LDR_TypeCode)
				 
				 IF (@LDR_image_id IS NULL OR @LDR_image_id = '')
			     BEGIN
				     SET @section_status='P'
				 END			 
			  END
			
		   IF @Msds = 'T'
			  BEGIN
			    -- Condition Check

				  DECLARE @MSDS_TypeCode NVARCHAR(50) = (SELECT [type_code] FROM plt_Image..[ScanDocumentType] 
				  where scan_type = 'approval' AND document_type = 'COR SDS')

				  DECLARE @MSDS_image_id INT = (SELECT Top 1 image_id FROM Plt_Image..Scan 
				  WHERE	
					(
						(form_id = @form_id and revision_id=@revision_id)
						or (profile_id = @profile_id and @profile_id is not null)
					)
				  AND document_source = @MSDS_TypeCode)

				  IF (@MSDS_image_id IS NULL OR @MSDS_image_id = '')
			      BEGIN
				     SET @section_status='P'
				  END
			  END
			    
			UPDATE FormSectionStatus SET section_status = @section_status WHERE form_id = @form_id and revision_id=@revision_id AND SECTION = 'DA'	  
END


GO

GRANT EXEC ON [dbo].[sp_Validate_Section_Document] TO COR_USER;

GO