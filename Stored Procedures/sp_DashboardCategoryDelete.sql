CREATE PROCEDURE [dbo].[sp_DashboardCategoryDelete] 
    @category_id int
/*	
	Description: 
	Deactivates category

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 
	UPDATE DashboardCategory SET status = 'I' WHERE category_id = @category_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardCategoryDelete] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardCategoryDelete] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardCategoryDelete] TO [EQAI]
    AS [dbo];

