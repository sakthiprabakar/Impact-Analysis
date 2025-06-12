USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [sp_Validate_Certificate]
GO
CREATE PROCEDURE  [dbo].[sp_Validate_Certificate]
	-- Add the parameters for the stored procedure here
	@formid INT,
	@revision_ID INT,
	@web_userid nvarchar(200)
AS


/* ******************************************************************

	Updated By		: Sathik Ali 
	Updated On		: 05-03-2019
	Type			: Stored Procedure
	Object Name		: [sp_Validate_Certificate]


	Procedure to validate Certificate supplement required fields and Update the Status of section

inputs 
	
	@formid
	@revision_ID
	


Samples:
 EXEC [sp_Validate_Certificate] @form_id,@revision_ID
 EXEC [sp_Validate_Certificate] 711303, 1 , 'manand84'

****************************************************************** */

BEGIN
	DECLARE @ValidColumnNullCount INTEGER;	
	
	DECLARE @FormStatusFlag VARCHAR(1) = 'Y'
	
	DECLARE @vsqg_cesqg_accept_flag  CHAR (1)
	SELECT @vsqg_cesqg_accept_flag = vsqg_cesqg_accept_flag 
		FROM FormVSQGCESQG 
		WHERE wcr_id = @formid AND wcr_rev_id = @revision_ID

	
	SET  @ValidColumnNullCount = (SELECT  (
				    (CASE WHEN ISNULL(wcr.generator_name,'')= '' THEN 1 ELSE 0 END)		
				  +	(CASE WHEN ISNULL(wcr.generator_address1,'')= '' THEN 1 ELSE 0 END)				 
				  +	(CASE WHEN ISNULL(wcr.generator_city,'')= '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN ISNULL(wcr.generator_state,'')= '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN ISNULL(wcr.generator_zip,'')= '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN @vsqg_cesqg_accept_flag = 'T' AND ISNULL(wcr.signing_name,'') = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN @vsqg_cesqg_accept_flag = 'T' AND ISNULL(wcr.signing_title, '') = '' THEN 1 ELSE 0 END)
				  +	(CASE WHEN @vsqg_cesqg_accept_flag = 'T' AND ISNULL(wcr.signing_company, '') = '' THEN 1 ELSE 0 END)
		    ) AS sum_of_nulls
			FROM FormWcr AS wcr	
			WHERE wcr.form_id =  @formid and wcr.revision_id = @revision_ID)

		IF (@ValidColumnNullCount > 0)
			BEGIN
				SET @FormStatusFlag = 'P'
			END
		ELSE IF (ISNULL(@vsqg_cesqg_accept_flag,'')= '' OR @vsqg_cesqg_accept_flag = 'F')
			 BEGIN
				SET @FormStatusFlag = 'P'
			 END

	-- Validate
	   IF(NOT EXISTS(SELECT * FROM FormSectionStatus WHERE FORM_ID =@formid AND revision_id = @Revision_ID  AND SECTION ='CN'))
		BEGIN
			INSERT INTO FormSectionStatus VALUES (@formid,@Revision_ID,'CN',@FormStatusFlag,getdate(),@web_userid,getdate(),@web_userid,1)
		END
		ELSE 
		BEGIN
			UPDATE FormSectionStatus SET section_status = @FormStatusFlag WHERE FORM_ID = @formid AND revision_id = @Revision_ID AND SECTION = 'CN'
		END
END


GO
GRANT EXEC ON [dbo].[sp_Validate_Certificate] TO COR_USER;
GO