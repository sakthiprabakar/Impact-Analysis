CREATE PROCEDURE [dbo].[sp_DashboardTierInsert] 
    @tier_id int,
    @tier_name varchar(50),
    @added_by varchar(50)
/*	
	Description: 
	Inserts a new Tier and returns the newly inserted row

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Added audit info
*/		
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	INSERT INTO [dbo].[DashboardTier] (
		[tier_id], 
		[tier_name],
		[added_by],
		[date_added]
		)
	SELECT 
		@tier_id, 
		@tier_name,
		@added_by,
		GETDATE()
	
	-- Begin Return Select <- do not remove
	SELECT *
	FROM   [dbo].[DashboardTier]
	WHERE  [tier_id] = @tier_id
	-- End Return Select <- do not remove
               

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTierInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTierInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTierInsert] TO [EQAI]
    AS [dbo];

