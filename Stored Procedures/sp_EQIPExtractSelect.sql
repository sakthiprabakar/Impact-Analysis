CREATE PROCEDURE [dbo].[sp_EQIPExtractSelect] 
    @extract_key VARCHAR(50)
AS 
	SET NOCOUNT ON 

	SELECT [extract_key], [extract_procedure], [extract_title], [status], [date_modified], [modified_by], [date_added], [added_by] 
	FROM   [dbo].[EQIPExtract] 
	WHERE  ([extract_key] = @extract_key OR @extract_key IS NULL) 
	AND [status] = 'A'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EQIPExtractSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EQIPExtractSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EQIPExtractSelect] TO [EQAI]
    AS [dbo];

