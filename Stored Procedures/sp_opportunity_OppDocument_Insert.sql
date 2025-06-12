
CREATE PROCEDURE [dbo].[sp_opportunity_OppDocument_Insert] 
	@opp_id int,
	@document_name varchar(50),
	@scan_file varchar(255),
	@file_type varchar(10),
	@image_blob image,
	@document_source varchar(30) = 'Opportunity',
	@status char(1),
	@added_by varchar(20)	
AS

	CREATE TABLE #tmpNextId ( new_id INT )

	DECLARE @next_id INT

	INSERT INTO #tmpNextId
	EXEC sp_sequence_next 'ScanImage.image_id', 1

	SELECT @next_id = new_id FROM   #tmpNextId


  INSERT INTO [dbo].[OppDocument]
              (
				image_id,
				opp_id,
               document_name,
               scan_file,
               file_type,
               image_blob,
               document_source,
               status,
               added_by,
               date_added,
               modified_by,
               date_modified)
  SELECT @next_id,
		@opp_id,
         @document_name,
         @scan_file,
         @file_type,
         @image_blob,
         @document_source,
         @status,
         @added_by,
         GETDATE(),
         @added_by,
         GETDATE() 

EXEC sp_opportunity_OppDocument_Select @next_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppDocument_Insert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppDocument_Insert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppDocument_Insert] TO [EQAI]
    AS [dbo];

