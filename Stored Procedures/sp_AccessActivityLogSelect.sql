CREATE PROCEDURE [dbo].[sp_AccessActivityLogSelect] 
    @access_activity_id INT
/*	
	Description: 
	Selects an actvity log record

	Revision History:
	??/01/2009	RJG 	Created
*/	
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  

	SELECT *
	FROM   [dbo].[AccessActivityLog] 
	WHERE  ([access_activity_id] = @access_activity_id) 

	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessActivityLogSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessActivityLogSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessActivityLogSelect] TO [EQAI]
    AS [dbo];

