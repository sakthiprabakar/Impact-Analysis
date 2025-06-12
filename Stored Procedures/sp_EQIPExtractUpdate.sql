CREATE PROCEDURE [dbo].[sp_EQIPExtractUpdate] 
    @extract_key varchar(50),
    @extract_procedure varchar(100),
    @extract_title varchar(100),
    @status char(1),
    @modified_by varchar(50)
AS 
	SET NOCOUNT ON 
UPDATE [dbo].[EQIPExtract]
SET    [extract_key] = @extract_key,
       [extract_procedure] = @extract_procedure,
       [extract_title] = @extract_title,
       [status] = @status,
       [date_modified] = GETDATE(),
       [modified_by] = @modified_by
WHERE  [extract_key] = @extract_key 

	exec sp_EQIPExtractSelect @extract_key


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EQIPExtractUpdate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EQIPExtractUpdate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EQIPExtractUpdate] TO [EQAI]
    AS [dbo];

