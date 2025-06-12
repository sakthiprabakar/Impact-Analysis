USE [PLT_AI]
GO

CREATE PROCEDURE [dbo].[sp_FormWCR_SubmitProfile]
	-- Add the parameters for the stored procedure here
	@formId int, 
	@revisionId int,
	@web_userid NVARCHAR(150)
AS

/* ******************************************************************

	Updated By		: Sathick
	Updated On		: 10th Jan 2018
	Type			: Stored Procedure
	Object Name		: [sp_FormWCR_SubmitProfile]


	Procedure used for get status of the SubmitProfile  for given form id and revision id

inputs 
	
	@formid
	@revision_ID
	@web_userid


Samples:
 EXEC sp_FormWCR_SubmitProfile @form_id,@revision_ID,web_userid
 EXEC sp_FormWCR_SubmitProfile 484641,1,'nyswyn100'

****************************************************************** */

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	Declare @image_id INT,

	@db_name NVARCHAR(50),
	@copy_source NVARCHAR(10),	
	@submited_display_statusId INT,
	@NotSubmitted_display_statusId INT

	SELECT @copy_source = copy_source FROM FormWCR WHERE form_id=@formId AND revision_Id=@revisionId

	SELECT @submited_display_statusId=display_status_uid FROM Formdisplaystatus WHERE display_status='Submitted'
	SELECT @NotSubmitted_display_statusId=display_status_uid FROM Formdisplaystatus WHERE display_status='Ready For Submission'

    IF(EXISTS(SELECT * FROM plt_ai.[dbo].[FormWCR] WHERE form_id=@formId AND revision_Id=@revisionId AND [display_status_uid]=@submited_display_statusId)) -- Already submitted profiles
	BEGIN	
		SELECT 'Already submitted' AS [Message]
	RETURN 
	END
	ELSE IF(EXISTS(SELECT * FROM plt_ai.[dbo].[FormWCR] WHERE form_id=@formId AND revision_Id=@revisionId AND [display_status_uid]=@NotSubmitted_display_statusId)) -- Not Submitted profiles
	BEGIN
		IF(EXISTS(SELECT * from plt_image..Scan WHERE form_id=@formId AND revision_Id=@revisionId AND (document_source='CORDOC' OR document_source = 'APPRFORM' OR (@copy_source = 'renewal' AND document_source = 'APPRRECERT'))))
		BEGIN
			SELECT TOP 1 @image_id=image_id FROM plt_image..Scan  WHERE form_id=@formId AND revision_Id=@revisionId AND (document_source='CORDOC'  OR document_source = 'APPRFORM' OR (@copy_source = 'renewal' AND document_source = 'APPRRECERT'))
			SELECT @db_name =[scan_database] FROM plt_image.dbo.scanxdatabase WHERE  image_id=@image_id
			IF(EXISTS(SELECT * FROM plt_image..Scan WHERE image_id=@image_id AND (document_source='CORDOC' OR document_source = 'APPRFORM' OR (@copy_source = 'renewal' AND document_source = 'APPRRECERT'))))
			BEGIN
			
				DECLARE @sql NVARCHAR(MAX),
				@isExistImage INT=0
				DECLARE @tempImage AS TABLE (image_id int) 
				Set @sql = N'SELECT image_id FROM ' + @db_name +'.dbo.scanimage WHERE Image_Id='+CONVERT(varchar(20),@image_id)
				--print @sql
				INSERT into @tempImage EXECUTE  sp_executesql @sql
			   
				IF(EXISTS(SELECT * FROM @tempImage))
				BEGIN
				
					EXEC [sp_DocumentSign_Submit] @formId,@revisionId,@web_userid
					--UPDATE  plt_ai.[dbo].[FormWCR] SET [display_status_uid]=3 WHERE form_id=@formId AND revision_Id=@revisionId
					SELECT 'Profile submitted successfully' AS [Message]
					RETURN
				END

			END
		END
		ELSE
		BEGIN
			SELECT 'Signed document not yet uploaded' AS [Message]
			RETURN 
		END
	END
	ELSE
	BEGIN
		SELECT 'Profile not yet submitted' AS [Message]
	RETURN 
	END
END

GO
GRANT EXEC ON [dbo].[sp_FormWCR_SubmitProfile] TO COR_USER;
GO