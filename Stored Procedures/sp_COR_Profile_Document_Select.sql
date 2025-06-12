-- drop proc sp_COR_Profile_Document_Select
go

CREATE PROCEDURE [dbo].[sp_COR_Profile_Document_Select]  
 -- Add the parameters for the stored procedure here  
 @profile_id int,
 @TSDFType varchar(10)=''
AS  
/*  
 Author  : Dineshkumar.K  
 Create date: 27th Feb 2020  
 Description: Select Documents of profile  
  
 EXEC Stmt: EXEC sp_COR_Profile_Document_Select @profile_id  
   EXEC sp_COR_Profile_Document_Select 631565  
     
SELECT  *  FROM    plt_image..scan WHERE profile_id = 631565  
 and view_on_web = 'T'  
  
*/  
  
BEGIN  
 -- SET NOCOUNT ON added to prevent extra result sets from  
 -- interfering with SELECT statements.  
 SELECT (  
SELECT  
          
   ISNULL( DocumentAttachment.document_source,'') AS document_source,  
    ISNULL( DocumentAttachment.file_type,'') AS document_type,  
   --CASE WHEN DocumentAttachment.document_source = 'CORDOC' OR DocumentAttachment.document_source ='APPRFORM'  then  
   --'Signed Document V'+convert(nvarchar(10),  row_number() over (partition by DocumentAttachment.document_source order by  DocumentAttachment.image_id))  
   -- ELSE  
   --ISNULL( DocumentAttachment.document_name,'') END document_name,  
    ISNULL( DocumentAttachment.document_name,'') as document_name,   
    '' AS [db_name],  
    isnull( sdt.document_type, '') as scan_document_type,  
    ISNULL( DocumentAttachment.form_id,'') AS form_id,  
    ISNULL( DocumentAttachment.revision_id,'') AS revision_id,  
    ISNULL( DocumentAttachment.profile_id,'') AS profile_id,  
    ISNULL((select comments.comment from plt_image..scancomment comments WHERE comments.image_id=DocumentAttachment.image_id), '') AS comment,  
    ISNULL( DocumentAttachment.added_by,'') AS added_by,  
    ISNULL( DocumentAttachment.date_added,'') AS date_created,  
    ISNULL( DocumentAttachment.modified_by,'') AS modified_by,  
    ISNULL( DocumentAttachment.date_modified,'') AS date_modified,  
    ISNULL( DocumentAttachment.image_id,'') AS document_id  
    
 FROM plt_image..Scan (nolock) DocumentAttachment  
 join plt_image..ScanDocumentType sdt on sdt.[type_id] = DocumentAttachment.[type_id] and sdt.view_on_web = 'T'  
 -- OUTER APPLY(select top 1 * from plt_image..scancomment comments WHERE comments.image_id=DocumentAttachment.image_id) scanComment  
 WHERE   
 ((@TSDFType='Non-USE' and DocumentAttachment.tsdf_approval_id = @profile_id)
        or  DocumentAttachment.profile_id = @profile_id)  
    and DocumentAttachment.view_on_web = 'T'  
	and (isnull(@TSDFType, '' ) <> 'Non-USE' or (@TSDFType='Non-USE' and (sdt.document_type = 'Profile' OR sdt.document_type = 'WCR' OR sdt.document_type = 'Generator Notification')))
    and DocumentAttachment.status = 'A'  
	
  
 FOR XML RAW ('DocumentAttachment'),TYPE,ROOT ('DocumentAttachment'), ELEMENTS)  
  
  FOR XML RAW (''), ROOT ('ProfileModel'), ELEMENTS  
END  
      

GO

	GRANT EXECUTE ON [dbo].[sp_COR_Profile_Document_Select] TO COR_USER;

GO
