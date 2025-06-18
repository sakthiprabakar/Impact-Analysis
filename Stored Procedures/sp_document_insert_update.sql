  
CREATE PROCEDURE [dbo].[sp_document_insert_update]
(  
    @Data XML,            
    @form_id INT,            
    @revision_id INT,            
    @web_userid VARCHAR(100)                    
)  
AS  
/* ****************************************************************************************************************             
              
 Updated By  : Divya Bharathi R      
 Updated On  : 26th Mar 2025      
 Type   : Stored Procedure      
 Object Name : sp_document_insert_update      
 Purpose  : Procedure to create/update document             
 Ticket   : DE38402: UATReg Bug: Templates > EQAI > Form Management & Profile Tracking > Attachments    
 Ticket Details : Attachments not being reflected properly in COR2 Application    

 Updated by: Pooja sri
 Ticket:DE39288: COR2 - INC1559307 - Attachments in COR2 not transferring to EQAI
               
              
EXEC [sp_document_insert_update] '<DocumentAttachment><IsEdited>DA</IsEdited><DocumentAttachment><DocumentAttachment><form_id /><revision_id>1</revision_id><document_id>12812564</document_id><document_source>COROTHER</document_source><document_type>pdf</d
  
    
ocument_type><document_name>Approval letter.pdf</document_name><db_name>plt_image_0109</db_name><created_by>nyswyn100</created_by><document_comment>TEst Comment</document_comment></DocumentAttachment>              
</DocumentAttachment></DocumentAttachment>',523911,1         
      
EXEC [sp_document_insert_update]      
'<DocumentAttachment xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">    
    <IsEdited>DA</IsEdited>    
    <DocumentAttachment>    
      <DocumentAttachment>    
        <form_id>1034414</form_id>    
        <revision_id>1</revision_id>    
        <document_id>20489634</document_id>    
        <document_source>CORSDS</document_source>    
        <document_type>docx</document_type>    
        <document_name>MIGRATING A COR1 USER TO A COR2 USER.docx</document_name>    
        <db_name>PLT_IMAGE_0145</db_name>    
        <created_by>dramesh@republicservices.com</created_by>    
        <document_comment>Test SDS Attachment</document_comment>    
        <profile_id xsi:nil="true" />    
      </DocumentAttachment>    
    </DocumentAttachment>    
  </DocumentAttachment>',1034414,1,vinolin24      
      
              
***************************************************************************************************** */      
BEGIN          
    BEGIN TRY            
   
  DECLARE @rowId int;  
  
  -- Temp table for new records (document_id IS NULL or 0)  
        DROP TABLE IF EXISTS #new_records_to_insert;  
  
  SELECT    
   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS rno,  
   p.v.value('document_source[1]', 'VARCHAR(30)') AS document_source,            
   p.v.value('document_name[1]', 'VARCHAR(50)') AS document_name,            
   p.v.value('document_comment[1]', 'NVARCHAR(255)') AS [description],            
   p.v.value('document_comment[1]', 'NVARCHAR(2000)') AS document_comment,  
   p.v.value('document_type[1]', 'VARCHAR(10)') AS document_type,  
   ISNULL(p.v.value('document_id[1]', 'INT'), 0) AS document_id  
  INTO #new_records_to_insert  
  FROM @Data.nodes('DocumentAttachment/DocumentAttachment/DocumentAttachment') p(v)  
  WHERE   
   ISNULL(p.v.value('document_id[1]', 'INT'), 0) = 0 AND  
   NULLIF(LTRIM(RTRIM(p.v.value('document_source[1]', 'VARCHAR(30)'))), '') IS NOT NULL;  
  
  select * from #new_records_to_insert   
  IF EXISTS (SELECT 1 FROM #new_records_to_insert)  
        BEGIN  
  
  DECLARE generate_image_id_cursor CURSOR FOR  
  SELECT rno  
            FROM #new_records_to_insert  
  OPEN generate_image_id_cursor  
  FETCH NEXT FROM generate_image_id_cursor INTO @rowId  
  WHILE @@FETCH_STATUS = 0  
  BEGIN  
  
   declare @imageid int  
   exec @imageid = SP_SEQUENCE_SILENT_NEXT 'scanImage.image_id'    
   update #new_records_to_insert set document_id = @imageid where rno = @rowId  
   
  
   FETCH NEXT FROM generate_image_id_cursor INTO @rowId  
  END  
  CLOSE generate_image_id_cursor  
  DEALLOCATE generate_image_id_cursor  
  
  --Insert into Scan table  
  INSERT INTO Plt_Image..Scan (  
   image_id, document_source, type_id, status,  
   document_name, date_added, date_modified,  
   added_by, modified_by, description,  
   form_id, revision_id,view_on_web,  
   app_source, upload_date  
  )  
  SELECT   
   n.document_id,  
   n.document_source,  
   dt.type_id,  
   'A',  
   n.document_name,  
   GETDATE(),  
   GETDATE(),  
   @web_userid,  
   @web_userid,  
   n.description,  
   @form_id,  
   @revision_id,  
   'T',  
   'COR',  
   GETDATE()  
  FROM #new_records_to_insert n  
  LEFT JOIN ScanDocumentType dt ON dt.type_code = n.document_source;  
  
  --Insert into Scan Comments table  
  Insert into plt_image..scanComment(  
  image_id, comment, added_by, date_added, modified_by, date_modified  
  )  
  select  
  document_id,  
  document_comment,  
  @web_userid,  
  GETDATE(),  
  @web_userid,  
  GETDATE()  
  FROM #new_records_to_insert  
 END  
   ELSE            
   BEGIN            
    --Update SCAN table based on signed document source    
   DECLARE @signed_documentSource TABLE (document_source VARCHAR(15));            
    INSERT INTO @signed_documentSource VALUES ('APPRRECERT'), ('APPRFORM'), ('CORDOC'), ('APPRRAPC');            
  
   UPDATE [plt_Image].[dbo].SCAN            
   SET             
    document_source = CASE             
     WHEN  p.v.value('document_source[1]', 'VARCHAR(100)') in ('APPRRECERT', 'APPRFORM', 'CORDOC', 'APPRRAPC')  
     --EXISTS (SELECT * FROM @signed_documentSource s WHERE s.document_source = p.v.value('document_source[1]', 'VARCHAR(100)'))            
     THEN 'CORDOC'             
     ELSE p.v.value('document_source[1]', 'VARCHAR(100)')             
    END,  
    [Description] = p.v.value('document_comment[1]', 'NVARCHAR(2000)')            
   FROM [plt_Image].[dbo].SCAN sc            
   JOIN @Data.nodes('DocumentAttachment/DocumentAttachment/DocumentAttachment') p(v)            
   ON p.v.value('document_id[1]', 'int') = sc.image_id            
   WHERE sc.form_id = @form_id             
     AND sc.revision_id = @revision_id;            
   
   -- Update document names for signed documents            
   WITH cte_scan AS (            
    SELECT             
     image_id,            
     CASE             
      WHEN EXISTS(SELECT 1 FROM @signed_documentSource sc WHERE sc.document_source = da.document_source)            
    THEN 'Signed Document_' + FORMAT(GETDATE(), 'MM_dd_yyyy_hh_mm_ss')            
      ELSE da.document_name             
     END AS document_name            
    FROM plt_image..Scan da (NOLOCK)            
    WHERE da.document_source IN (SELECT sv.document_source FROM @signed_documentSource sv)            
      AND da.form_id = @form_id              
      AND da.revision_id = @revision_id            
   )            
   UPDATE plt_image..Scan             
   SET document_name = cte.document_name             
   FROM plt_image..Scan s             
   JOIN cte_scan cte ON s.image_id = cte.image_id;            
   
   -- Handle scan comments            
   DELETE FROM plt_image..scancomment             
   WHERE image_id IN (SELECT p.v.value('document_id[1]', 'int')             
       FROM @Data.nodes('DocumentAttachment/DocumentAttachment/DocumentAttachment') p(v));            
   
   -- Insert new scan comments            
   INSERT INTO plt_image..scancomment             
   SELECT       p.v.value('document_id[1]', 'int'),            
    ISNULL(p.v.value('document_comment[1]', 'NVARCHAR(2000)'), ''),            
    @web_userid,            
    GETDATE(),            
    @web_userid,            
    GETDATE()            
   FROM @Data.nodes('DocumentAttachment/DocumentAttachment/DocumentAttachment') p(v)            
   WHERE p.v.value('document_id[1]', 'int') > 0;            
 END   
    END TRY            
    BEGIN CATCH            
        -- Log errors            
        DECLARE @mailTrack_userid NVARCHAR(60) = 'COR';            
        DECLARE @error_description VARCHAR(2000);            
        SET @error_description = CONVERT(VARCHAR(20), @form_id) + ' - ' + CONVERT(VARCHAR(10), @revision_id) + ' ErrorMessage: ' + ERROR_MESSAGE();            
            
        INSERT INTO COR_DB.[dbo].[ErrorLogs]             
        (ErrorDescription, [Object_Name], Web_user_id, CreatedDate)            
        VALUES            
        (@error_description, ERROR_PROCEDURE(), @mailTrack_userid, GETDATE());            
    END CATCH            
END 

GO

GRANT EXECUTE ON [dbo].[sp_document_insert_update] TO COR_USER;

GO