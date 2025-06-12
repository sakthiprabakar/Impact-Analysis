CREATE PROCEDURE [dbo].[sp_opportunity_OppSearchHistory_Delete] 
    @search_id	varchar(50)
AS 
	DELETE
	FROM   [dbo].[OppSearchHistory]
	WHERE  search_id = @search_id
