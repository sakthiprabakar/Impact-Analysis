CREATE PROCEDURE [dbo].[sp_AccessGroupInsert] 
    @group_description varchar(500),
    @status char(1),
    --@permission_security_type varchar(10),
    @added_by varchar(50)
/*	
	Description: 
	Inserts a new AccessGroup record, returns the newly inserted record

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 

	SET NOCOUNT ON
	
	CREATE TABLE #tmpNextId
	(
		new_id int
	)
	
	declare @group_id int
	INSERT INTO #tmpNextId
		exec sp_sequence_next 'AccessGroupSecurity.group_id', 1
		
	SELECT @group_id = new_id from #tmpNextId
	
	INSERT INTO [dbo].[AccessGroup] (
		[group_id], 
		[group_description], 
		[status],
		--[permission_security_type],
		[added_by],
		[date_added]
	)
	SELECT 
		@group_id, 
		@group_description, 
		@status,
		--@permission_security_type,
		@added_by,
		GETDATE()
	
	-- Begin Return Select <- do not remove
	SELECT *
	FROM   [dbo].[AccessGroup]
	WHERE  [group_id] = @group_id
	-- End Return Select <- do not remove
	
	SET NOCOUNT OFF
 	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupInsert] TO [EQAI]
    AS [dbo];

