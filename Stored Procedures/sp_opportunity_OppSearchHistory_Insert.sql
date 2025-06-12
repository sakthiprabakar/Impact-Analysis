CREATE PROCEDURE [dbo].[sp_opportunity_OppSearchHistory_Insert] 
    @search_id varchar(50),
    @user_id int,
    @procedure_name varchar(50),
    @param_name varchar(50),
    @param_value varchar(200),
    @search_timestamp datetime
AS 

	INSERT INTO [dbo].[OppSearchHistory] ([search_id], [user_id], [procedure_name], [param_name], [param_value], [search_timestamp])
	SELECT @search_id, @user_id, @procedure_name, @param_name, @param_value, @search_timestamp
	
	exec sp_opportunity_OppSearchHistory_Select @search_id
	---- Begin Return Select <- do not remove
	--SELECT [search_field_id], [search_id], [user_id], [procedure_name], [param_name], [param_value], [search_timestamp]
	--FROM   [dbo].[OppSearchHistory]
	--WHERE  [search_field_id] = SCOPE_IDENTITY()
	---- End Return Select <- do not remove

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppSearchHistory_Insert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppSearchHistory_Insert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_OppSearchHistory_Insert] TO [EQAI]
    AS [dbo];

