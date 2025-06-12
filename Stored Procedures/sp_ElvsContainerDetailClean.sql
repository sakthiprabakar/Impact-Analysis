
CREATE PROCEDURE sp_ElvsContainerDetailClean (			
	@container_id		int,
	@valid_detail_ids	varchar(8000)	
)			
AS			
--======================================================
-- Description: Deletes rows FROM a container that aren't in the input list
-- Parameters :
-- Returns    :
-- Requires   : *.PLT_AI.*
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 03/29/2006  Jonathan Broome       Initial Development
-- 08/25/2008  Chris Allen       Formatted
--
--======================================================
BEGIN			
	DECLARE @pos int, @tmp int		
			
	SET nocount on		
	CREATE TABLE #tmplist (detail_id int)		
	SELECT @pos = 0		
	SELECT @valid_detail_ids = REPLACE(@valid_detail_ids, ' ', '')		
	WHILE DATALENGTH(@valid_detail_ids) > 0		
	BEGIN 		
		-- Look for a comma	
		SELECT @pos = CHARINDEX(',', @valid_detail_ids)	
			
		-- If we found a comma, there is a list of databases
		IF @pos > 0	
		BEGIN 	
			SELECT @tmp = SUBSTRING(@valid_detail_ids, 1, @pos - 1)
			SELECT @valid_detail_ids = SUBSTRING(@valid_detail_ids, @pos + 1, DATALENGTH(@valid_detail_ids) - @pos)
		END	
			
		-- If we did not find a comma, there is only one database or we are at the end of the list	
		IF @pos = 0	
		BEGIN 	
			SELECT @tmp = @valid_detail_ids
			SELECT @valid_detail_ids = NULL
		END	
			
		-- Insert into table	
		INSERT #tmplist VALUES (@tmp)	
	END		
			
	DELETE FROM ElvsContainerDetail WHERE container_id = @container_id AND detail_id not in (SELECT detail_id FROM #tmplist)		
	DROP TABLE #tmplist		
END -- CREATE PROCEDURE sp_ElvsContainerDetailClean

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerDetailClean] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerDetailClean] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerDetailClean] TO [EQAI]
    AS [dbo];

