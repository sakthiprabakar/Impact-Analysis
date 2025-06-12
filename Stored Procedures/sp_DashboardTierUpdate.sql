CREATE PROCEDURE [dbo].[sp_DashboardTierUpdate] 
    @tier_id int,
    @tier_name varchar(50),
    @status char(1),
    @modified_by varchar(50)
/*	
	Description: 
	Updates given DashboardTier record and returns the newly updated row

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Added audit info
*/		
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	UPDATE [dbo].[DashboardTier]
		SET    [tier_id] = @tier_id, 
		[status] = @status,
		[tier_name] = @tier_name,
		[modified_by] = @modified_by,
		[date_modified] = GETDATE()
	WHERE  [tier_id] = @tier_id
	
	-- Begin Return Select <- do not remove
	SELECT *
	FROM   [dbo].[DashboardTier]
	WHERE  [tier_id] = @tier_id	
	-- End Return Select <- do not remove

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTierUpdate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTierUpdate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTierUpdate] TO [EQAI]
    AS [dbo];

