CREATE PROCEDURE [dbo].[sp_AccessGroup_SelectAllMembers] 
    @group_id INT = NULL
/*	
	Description: 
	Selects ALL members of a given group_id.  
	This only returns very generic, common data between contacts and users

	Revision History:
	??/01/2009	RJG 	Created
	
	sp_AccessGroup_SelectAllMembers 1002494
*/			
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  

	

	CREATE TABLE #tmp_all_users
	(
		row_num int,
		id int,
		username varchar(100),
		user_code varchar(50),
		email varchar(255),
		user_type char(1)
	)
	
	CREATE TABLE #tmp_group_members
	(
		group_id int,
		group_description varchar (255),
		id int,		
		username varchar(100),
		email varchar(255),
		user_type char(1),
		user_code varchar(10)
	)
	

	
	INSERT INTO #tmp_all_users
		EXEC sp_Access_SearchUsersAndContacts @start_row = 0, @end_row = -1
		
	-- insert matching associates
	INSERT INTO #tmp_group_members (
		group_id, 
		group_description, 
		id, 
		username, 
		email, 
		user_type, 
		user_code)
	SELECT 
		g.group_id, 
		g.group_description, 
		tmp.id,
		tmp.username,
		tmp.email,
		tmp.user_type,
		tmp.user_code FROM AccessGroupSecurity ug
		INNER JOIN #tmp_all_users tmp ON ug.user_id = tmp.id AND tmp.user_type = 'A'
		INNER JOIN AccessGroup g ON ug.group_id = g.group_id
	WHERE (@group_id IS NULL OR ug.group_id = @group_id)
	AND ug.status = 'A'
	AND g.status = 'A'
	--AND g.record_type = 'A'
	
	-- insert matching customers	
		INSERT INTO #tmp_group_members (
		group_id, 
		group_description, 
		id, 
		username, 
		email, 
		user_type, 
		user_code)
	SELECT 
		g.group_id, 
		g.group_description, 
		tmp.id,
		tmp.username,
		tmp.email,
		tmp.user_type,
		tmp.user_code FROM AccessGroup g
		INNER JOIN AccessGroupSecurity ags ON g.group_id = ags.group_id
		INNER JOIN #tmp_all_users tmp ON ags.contact_id = tmp.id 
		AND tmp.user_type = 'C'
		WHERE (@group_id IS NULL OR g.group_id = @group_id)
		--AND g.record_type = 'C'
		AND ags.status = 'A'
		AND g.status = 'A'
	
	--SELECT * FROM #tmp_all_users
	SELECT DISTINCT * FROM #tmp_group_members ORDER BY username
	
	IF object_id('tempdb..#tmp_group_members') IS NOT NULL drop table #tmp_group_members
	IF object_id('tempdb..#tmp_all_users') IS NOT NULL drop table #tmp_all_users
	
	
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroup_SelectAllMembers] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroup_SelectAllMembers] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroup_SelectAllMembers] TO [EQAI]
    AS [dbo];

