CREATE PROCEDURE sp_access_list 
AS
/****** Object:  Stored Procedure dbo.sp_access_list
This stored procedure produces a list of group IDs and user IDs

11/15/2010 JDB	Updated to use proper join syntax; cleaned up a little.
07/01/2014 AM    Moved to plt_ai 

sp_access_list
***********************************************************************************************/
SELECT 'G' AS sortkey, 
	g.group_id AS access_id, 
	g.group_desc AS access_name, 
	g.group_id, 
	a.group_id AS access_group 
FROM groups g
LEFT OUTER JOIN access a ON g.group_id = a.group_id

UNION

SELECT 'U' AS sortkey, 
	u.user_id AS access_id, 
	u.user_name AS access_name, 
	u.group_id, 
	u.group_id AS access_group 
FROM users u
ORDER BY sortkey, access_name

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_access_list] TO [EQAI]
    AS [dbo];

