CREATE PROCEDURE [dbo].[sp_AccessPermissionInsert] 
    @permission_description varchar(255), -- description/title of permission
    @permission_help_text varchar(1000), -- help text associated
    @record_type char(1), -- (R)eport or (U)rl type of permission
    @customer_delegation_allowed char(1),-- can this permission be delegated out?
    @dashboard_display char(1),-- will this display on the front page?
    @link_display_on_menu char(1) = NULL, -- Url permission only: display on side menu?
    @link_html_target varchar(20) = NULL,-- Url permission only: open in same or new window?
    @link_text varchar(500) = NULL, -- Url permission only: the link text
    @link_url varchar(500) = NULL, -- Url permission only: the link url
    @report_description varchar(1000) = NULL,--Report permission only: report description
    @report_name varchar(500) = NULL,--Report permission only: report name
    @report_path varchar(500) = NULL,--Report permission only:  path to SSRS report (relative)
    @report_custom_arguments varchar(500) = NULL,--Report permission only: custom arguments to be passed to report (i.e. measurement_id
    @report_display_on_menu char(1) = NULL, --Report permission only: display on side menu?
    @report_tier_id int = NULL, --Report permission only: 1 = corporate, 2 = co/pc
    @set_id int, -- permission set associated to this permission
    @status char(1), -- Active or Inactive
    @permission_security_type varchar(10),
    @action_id int, -- what level of access (deny, read, write, admin)
    @added_by varchar(50)
/*	
	Description: 
	Inserts an AccessPermission. See above for field info

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Added audit info
*/	
	
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	
	BEGIN TRAN
	
	declare @permission_id int
	SELECT @permission_id = COALESCE(MAX(permission_id), 1) FROM AccessPermission
	SET @permission_id = @permission_id + 1
	
	INSERT INTO [dbo].[AccessPermission]
           ([permission_id],
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
            [set_id],
            [status],
            [permission_security_type],
            action_id, 
            added_by,
            date_added)
SELECT @permission_id,
       @customer_delegation_allowed,
       @dashboard_display,
       @link_display_on_menu,
       @link_html_target,
       @link_text,
       @link_url,
       @permission_description,
       @permission_help_text,
       @record_type,
       @report_description,
       @report_name,
       @report_path,
       @report_custom_arguments,
       @report_display_on_menu,
       @report_tier_id,
       @set_id,
       @status,
       @permission_security_type,
       @action_id,
       @added_by,
       GETDATE()
	
	exec sp_AccessPermissionSelect @permission_id
	
               
	COMMIT

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionInsert] TO [EQAI]
    AS [dbo];

