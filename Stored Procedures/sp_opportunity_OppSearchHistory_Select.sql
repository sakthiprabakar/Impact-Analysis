CREATE PROCEDURE [dbo].[sp_opportunity_OppSearchHistory_Select] 
    @search_id varchar(50) = NULL,
    @user_id int = NULL
AS 
	SET NOCOUNT ON 

	IF @search_id IS NOT NULL
	BEGIN
		SELECT *
		FROM   [dbo].[OppSearchHistory] 
		WHERE  
		(search_id = @search_id OR @search_id IS NULL) 
	END
	ELSE
	BEGIN
	
		SELECT DISTINCT TOP 10 search_id, search_timestamp, procedure_name, user_id
		FROM   [dbo].[OppSearchHistory] op
		WHERE  (user_id = @user_id) 
		ORDER BY op.search_timestamp DESC
		
		
		SELECT * FROM OppSearchHistory
		where search_id IN(
			SELECT DISTINCT TOP 10 search_id 
				FROM   [dbo].[OppSearchHistory] op
				WHERE  (user_id = @user_id) 
		)
		ORDER BY search_timestamp DESC
	END
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppSearchHistory_Select] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppSearchHistory_Select] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppSearchHistory_Select] TO [EQAI]
    AS [dbo];

