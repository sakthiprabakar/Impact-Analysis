CREATE PROCEDURE [dbo].[sp_DashboardTypeInsert] 
    @description varchar(500),
    @status char(1),
    @added_by varchar(50)
/*	
	Description: 
	Creates a new DashboardType record

	Revision History:
	??/01/2009	RJG 	Created
*/		
AS 
	
	INSERT INTO [dbo].[DashboardType]
	           ([description],
	            [status],
	            [added_by],
	            [date_added])
	SELECT @description,
	       @status,
	       @added_by,
	       GETDATE()
	       
	DECLARE  @id INT
	SET @id = Scope_identity()
	
	EXEC sp_dashboardtypeselect @id 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTypeInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTypeInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardTypeInsert] TO [EQAI]
    AS [dbo];

