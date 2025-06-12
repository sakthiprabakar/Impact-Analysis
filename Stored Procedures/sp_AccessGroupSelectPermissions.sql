CREATE PROCEDURE [dbo].[sp_AccessGroupSelectPermissions] 
    @group_id INT = NULL
/*	
	Description: 
	Select permissions for a given group

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  

	SELECT AccessPermission.[permission_id], 
		[customer_delegation_allowed], 
		[dashboard_display], 
		[link_display_on_menu], 
		[link_html_target], 
		[link_text], 
		[link_url], 
		[permission_description], 
		[permission_help_text], 
		[record_type], 
		[report_description], 
		[report_name], 
		[report_path],
		[report_custom_arguments], 
		[report_display_on_menu],
		[report_tier_id],
		aps.set_id,
		aps.set_name,
		AccessPermission.[status],
		apa.action_id,
		apa.action_description,
		apa.action_priority,
		AccessPermission.permission_security_type
		FROM   [dbo].[AccessPermission] 
		INNER JOIN AccessPermissionSet aps ON [AccessPermission].set_id = aps.set_id
		INNER JOIN AccessPermissionGroup apg ON AccessPermission.permission_id = apg.permission_id
		INNER JOIN AccessAction apa ON apg.action_id = apa.action_id
		
		AND apg.group_id = @group_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSelectPermissions] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSelectPermissions] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSelectPermissions] TO [EQAI]
    AS [dbo];

