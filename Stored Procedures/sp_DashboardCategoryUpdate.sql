CREATE PROCEDURE [dbo].[sp_DashboardCategoryUpdate] 
    @category_id int,
    @description varchar(500),
    @status char(1),
    @modified_by varchar(50)
/*	
	Description: 
	Updates category association for a measurement

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 

	UPDATE [dbo].[DashboardCategory]
	SET    
	[description] = @description,
	[status] = @status,
	[date_modified] = getdate(),
	[modified_by] = @modified_by       
WHERE  [category_id] = @category_id 
	
	exec sp_DashboardCategorySelect @category_id

	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardCategoryUpdate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardCategoryUpdate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardCategoryUpdate] TO [EQAI]
    AS [dbo];

