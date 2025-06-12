--CREATE PROCEDURE [dbo].[sp_AccessGroup_SelectForContact] 
--    @contact_id INT
--/*	
--	Description: 
--	Selects all of the group's that the contact_id belongs to

--	Revision History:
--	??/01/2009	RJG 	Created
--*/			
--AS 
--	SET NOCOUNT ON 
--	SET XACT_ABORT ON  

--	BEGIN TRAN

--	SELECT * FROM AccessGroup WHERE contact_id = @contact_id
--	ORDER BY group_description
	
--	COMMIT

--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_AccessGroup_SelectForContact] TO [EQWEB]
--    AS [dbo];
--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_AccessGroup_SelectForContact] TO [COR_USER]
--    AS [dbo];



--GO
--GRANT EXECUTE
--    ON OBJECT::[dbo].[sp_AccessGroup_SelectForContact] TO [EQAI]
--    AS [dbo];

