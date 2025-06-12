
CREATE PROCEDURE [dbo].[sp_FormWCR_attachment_delete]
	-- Add the parameters for the stored procedure here
	@form_id int ,
	@revision_id int,
	@documentId int
AS

/* ******************************************************************
Delete image by image ID from Scan image on dynamic selected DB, plti_image.scancommnet and plt_image.scan
inputs 
	
	Form ID
	Revision ID
	Document ID ; i.e.. Image ID

****************************************************************** */

/* ******************************************************************
Delete image by image ID from Scan image on dynamic selected DB, plti_image.scancommnet and plt_image.scan
inputs 
	
	Form ID
	Revision ID
	Document ID ; i.e.. Image ID

	Sample:
	 EXEC sp_FormWCR_attachment_delete 428841,1,10963435
****************************************************************** */
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	DECLARE @dbName NVARCHAR(50),
	@sql NVARCHAR(MAX)
	SELECT @dbName=[scan_database] FROM plt_image.dbo.scanxdatabase WHERE  image_id=@documentId
	print @dbName


    
	Set @sql = 'DELETE FROM ' + @dbName +'.dbo.scanimage WHERE image_id='+CONVERT(nvarchar(50),@documentId)
	exec (@sql)
	DELETE FROM plt_image..scancomment WHERE image_id=@documentId 
	DELETE FROM plt_image..scan WHERE form_id =@form_id AND revision_id=@revision_id AND image_id=@documentId

END

GO
 GRANT EXEC ON [dbo].[sp_FormWCR_attachment_delete] TO COR_USER;

 GO
