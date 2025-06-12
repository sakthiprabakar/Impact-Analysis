CREATE PROCEDURE [dbo].[sp_EQIPExtractInsert] 
    @extract_key varchar(50),
    @extract_procedure varchar(100),
    @extract_title varchar(100),
    @status char(1),
    @added_by varchar(50)
AS 

INSERT INTO [dbo].[EQIPExtract]
            ([extract_key],
             [extract_procedure],
             [extract_title],
             [status],
             [date_added],
             [added_by])
SELECT @extract_key,
       @extract_procedure,
       @extract_title,
       @status,
       GETDATE(),
       @added_by 

	
	exec sp_EQIPExtractSelect @extract_key
               

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EQIPExtractInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EQIPExtractInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EQIPExtractInsert] TO [EQAI]
    AS [dbo];

