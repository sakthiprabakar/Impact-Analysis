
CREATE PROCEDURE [dbo].[sp_opportunity_OppDocument_Update]
	@image_id int,
	@opp_id int,
	@document_name varchar(50),
	@scan_file varchar(255),
	@file_type varchar(10),
	@image_blob image,
	@document_source varchar(30),
	@status char(1),
	@modified_by varchar(20)	
AS
  SET NOCOUNT ON

  UPDATE [dbo].[OppDocument]
  SET  
	opp_id = @opp_id,
	document_name = @document_name,
	scan_file = @scan_file,
	file_type = @file_type,
	image_blob = @image_blob,
	document_source = @document_source,
	status = @status,
	modified_by = @modified_by,
	date_modified = GETDATE()	
  WHERE  [image_id] = @image_id

  EXEC sp_opportunity_OppDocument_Select @image_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppDocument_Update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppDocument_Update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppDocument_Update] TO [EQAI]
    AS [dbo];

