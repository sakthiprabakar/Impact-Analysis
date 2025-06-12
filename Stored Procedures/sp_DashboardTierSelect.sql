CREATE PROCEDURE [dbo].[sp_DashboardTierSelect] 
    @tier_id INT = NULL
/*	
	Description: 
	Selects the given tier (or all tiers if no id specified)

	Revision History:
	??/01/2009	RJG 	Created
*/		
AS 
	SELECT *
	FROM   [dbo].[DashboardTier] 
	WHERE  ([tier_id] = @tier_id OR @tier_id IS NULL) 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTierSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTierSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTierSelect] TO [EQAI]
    AS [dbo];

