
CREATE PROCEDURE [dbo].[sp_opportunity_OppDocument_Delete] @image_id INT
AS
	UPDATE OppDocument SET status = 'I'
    WHERE  [image_id] = @image_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppDocument_Delete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppDocument_Delete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppDocument_Delete] TO [EQAI]
    AS [dbo];

