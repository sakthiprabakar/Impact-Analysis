USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [sp_Documents_Select]
GO
CREATE PROCEDURE [dbo].[sp_Documents_Select](
   @form_id INT,      
   @revision_id INT    
)      
AS      
      
/***********************************************************************************      
      
 Author  : SathickAli      
 Updated On : 20-Dec-2018      
 Type  : Store Procedure       
 Object Name : [dbo].[sp_Documents_Select]      
      
 Description :       
                Procedure to get profile Documents details       
          
      
 Input  :      
    @form_id      
    @revision_id      
          
                      
 Execution Statement : EXEC [plt_ai].[dbo].[sp_Documents_Select] 559352,3      
      
*************************************************************************************/      
      
BEGIN      
      
	  DECLARE @profile_id int ,@copy_source VARCHAR(20)
	  (SELECT TOP 1 @profile_id=profile_id,@copy_source=copy_source 
		FROM plt_ai..formwcr 
		WHERE form_id = @form_id and revision_id = @revision_id)

	SELECT (      
		SELECT      
			CASE WHEN sdt.type_id = DocumentAttachment.type_id THEN sdt.type_code ELSE '' END AS document_source,        
			-- ISNULL(DocumentAttachment.document_source,'') AS document_source,      
			ISNULL( DocumentAttachment.file_type,'') AS document_type,      
			--CASE WHEN DocumentAttachment.document_source = 'CORDOC' OR DocumentAttachment.document_source ='APPRFORM'  then      
			--'Signed Document V'+convert(nvarchar(10),  row_number() over (partition by DocumentAttachment.document_source order by  DocumentAttachment.image_id))      
			--ELSE      
			ISNULL( DocumentAttachment.document_name,'') as document_name,         
			'' AS [db_name],      
			ISNULL( sdt.document_type, '') as scan_document_type,      
			ISNULL( DocumentAttachment.form_id,'') AS form_id,      
			ISNULL( DocumentAttachment.revision_id,'') AS revision_id,      
			ISNULL((SELECT TOP 1 comment 
					FROM plt_image..scancomment comments 
					WHERE comments.image_id=DocumentAttachment.image_id),'') AS comment,      
			ISNULL( DocumentAttachment.added_by,'') AS added_by,      
			ISNULL( DocumentAttachment.date_added,'') AS date_created,      
			ISNULL( DocumentAttachment.modified_by,'') AS modified_by,      
			ISNULL( DocumentAttachment.date_modified,'') AS date_modified,      
			ISNULL( DocumentAttachment.image_id,'') AS document_id,      
			ISNULL((SELECT TOP 1 DATALENGTH(image_blob) 
					FROM plt_image..scanimage scanimage 
					WHERE scanimage.image_id=DocumentAttachment.image_id),'') AS document_size,    
			CASE WHEN ISNULL(DocumentAttachment.Profile_Id,'') <>'' AND @copy_source in ('renewal','amendment') THEN  'F'ELSE 'T'END AS is_doc_editable     
			--FROM  COR_DB.dbo.FormWCRDocument as DocumentAttachment   
			FROM plt_image..Scan DocumentAttachment      
			JOIN plt_image..ScanDocumentType sdt ON DocumentAttachment.type_id = sdt.type_id AND sdt.view_on_web = 'T'      
			 -- OUTER APPLY(select top 1 * from plt_image..scancomment comments WHERE comments.image_id=DocumentAttachment.image_id) scanComment      
			WHERE       
			(  
			(DocumentAttachment.form_id = @form_id AND DocumentAttachment.revision_id = @revision_id)  
												   OR    
			(	
				ISNULL(@profile_id, '') <> '' AND @profile_id <> 0 
				AND DocumentAttachment.Profile_Id <> 0 AND isnull(DocumentAttachment.Profile_Id, '') <> ''
				AND DocumentAttachment.Profile_Id in (@profile_id) 
				AND DocumentAttachment.[type_id] in (Select [type_id] from Plt_Image..ScanDocumentType where type_code in
				('CORSDS','CORLABANAL')))  
			)
			AND DocumentAttachment.view_on_web = 'T'      
			AND DocumentAttachment.status = 'A'  
		FOR XML RAW ('DocumentAttachment'),TYPE,ROOT ('DocumentAttachment'), ELEMENTS)  
	FOR XML RAW (''), ROOT ('ProfileModel'), ELEMENTS      
      
END 

GO
GRANT EXECUTE ON [dbo].[sp_Documents_Select] TO COR_USER;
GO