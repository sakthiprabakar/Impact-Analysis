CREATE PROCEDURE [dbo].[sp_EQIPExtractDelete] 
    @extract_key varchar(50),
    @modified_by varchar(50)    
AS 
	UPDATE [EQIPExtract] 
		SET [status] = 'I',
		[date_modified] = GETDATE(),
		[modified_by] = @modified_by
	WHERE  [extract_key] = @extract_key

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EQIPExtractDelete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EQIPExtractDelete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EQIPExtractDelete] TO [EQAI]
    AS [dbo];

