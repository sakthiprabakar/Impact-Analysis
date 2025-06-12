CREATE PROCEDURE [dbo].[sp_DashboardTierDelete] 
    @tier_id int,
    @modified_by varchar(50)
/*	
	Description: 
	Deletes the given tier_id

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Added audit info
*/		
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	UPDATE DashboardTier 
		SET [status] = 'I',
		[modified_by] = @modified_by,
		[date_modified] = GETDATE()
	WHERE tier_id = @tier_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTierDelete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTierDelete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTierDelete] TO [EQAI]
    AS [dbo];

