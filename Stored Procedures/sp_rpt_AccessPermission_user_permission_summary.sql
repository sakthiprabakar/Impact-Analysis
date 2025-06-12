
CREATE PROCEDURE sp_rpt_AccessPermission_user_permission_summary
	@display_mode varchar(20) = 'SUMMARY', /* SUMMARY or DETAIL */
	@permission_id int = NULL
	
/*

The SUMMARY view of this procedure outlines all of the permissions and the number of people assigned to each
The DETAIL view takes a single permission and displays all of the people who can access it.
The DETAIL view does NOT list out which facilities that the person has for the permission

07-09-2010	-	RJG		Created


exec sp_rpt_AccessPermission_user_permission_summary 'SUMMARY', 122
exec sp_rpt_AccessPermission_user_permission_summary 'DETAIL', 122
exec sp_rpt_AccessPermission_user_permission_summary 'DETAIL', 79
*/	
AS
BEGIN


IF @display_mode = 'SUMMARY' 
BEGIN
	SELECT 
		ap.permission_id, 
		ap.record_type, 
		ap.permission_description,
		'users_with_access' = (SELECT COUNT (DISTINCT user_id) FROM AccessPermissionGroup apg 
					INNER JOIN AccessUserXGroup uxg ON uxg.group_id = apg.group_id
					WHERE apg.permission_id = ap.permission_id
					)
	FROM AccessPermission ap
	INNER JOIN AccessPermissionSet aps ON ap.set_id = aps.set_id
	WHERE ap.status = 'A'
	AND aps.status = 'A'
	AND ap.permission_id = COALESCE(@permission_id, ap.permission_id)
	ORDER BY ap.permission_description
	

END

IF @display_mode = 'DETAIL'
BEGIN

	SELECT 
	    au.permission_id,
	    au.permission_description,
	    CASE 
			WHEN au.record_type = 'U' THEN 'URL'
			WHEN au.record_type = 'R' THEN 'Report'
			ELSE 'N/A'
	    END as record_type,
	    CASE 
			WHEN au.record_type = 'U' THEN au.link_url
			WHEN au.record_type = 'R' THEN au.report_path
			ELSE 'N/A'
	    END as access_item,
		u.user_id, 
		u.user_code, 
		u.user_name, 
		u.first_name, 
		u.last_name 
	FROM view_AccessByUser au
	INNER JOIN Users u ON au.user_id = u.user_id
	where permission_id = @permission_id
	order by u.user_code, 
		u.last_name,
		u.first_name 
		
END

END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_AccessPermission_user_permission_summary] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_AccessPermission_user_permission_summary] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_AccessPermission_user_permission_summary] TO [EQAI]
    AS [dbo];

