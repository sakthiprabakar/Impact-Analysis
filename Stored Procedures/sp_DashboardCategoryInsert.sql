CREATE PROCEDURE [dbo].[sp_DashboardCategoryInsert] 
    @description varchar(500),
    @status char(1),
    @added_by varchar(50)
/*	
	Description: 
	Creates a new DashboardCategory record

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 
	
	INSERT INTO [dbo].[DashboardCategory]
           ([added_by],
            [date_added],
            [date_modified],
            [description],
            [modified_by],
            [status])
	SELECT @added_by,
		   getdate(),
		   getdate(),
		   @description,
		   @added_by,
		   @status 
       
	declare @id int
	set @id = scope_identity()
	
	exec sp_DashboardCategorySelect @id
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardCategoryInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardCategoryInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardCategoryInsert] TO [EQAI]
    AS [dbo];

