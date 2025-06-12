
CREATE PROCEDURE sp_AccessPermission_GetCompanyProfitCenterAccess
	@user_id       INT = NULL,
	@user_code	   VARCHAR(20) = NULL,	
    @permission_id int = NULL,
    @action_id int = 2 -- default action is 'Read'
  
/*
01-21-2010	RJG		This procedure returns the co/pc access for a given user & permission
					If null permission_id is passed, it returns ALL co/pc access by permission

EXEC sp_AccessPermission_GetCompanyProfitCenterAccess 925, null, null
EXEC sp_AccessPermission_GetCompanyProfitCenterAccess 925, null, 65
EXEC sp_AccessPermission_GetCompanyProfitCenterAccess 925, null, 33

EXEC sp_AccessPermission_GetCompanyProfitCenterAccess 1206
EXEC sp_AccessPermission_GetCompanyProfitCenterAccess 1206, null, 65
EXEC sp_AccessPermission_GetCompanyProfitCenterAccess 1206, null, 33

*/
    
AS

	/*
		get the groups that to with this permission
		get the co/pc that go with the groups
		get the users that go with the groups
		
		this should be a cumulative list
	*/
	IF @user_code IS NULL
	BEGIN
		SELECT @user_code = user_code FROM users WHERE user_id = @user_id
	END
		
	IF @user_id IS NULL
	BEGIN
		SELECT @user_id = user_id FROM users WHERE user_code = @user_code
	END
	
	if (@action_id = '')
		SET @action_id = 2
	
	SELECT DISTINCT
		secured_copc.permission_id,
		secured_copc.company_id, 
		secured_copc.profit_ctr_id,
		secured_copc.profit_ctr_name, 
		secured_copc.waste_receipt_flag, 
		secured_copc.workorder_flag,
		cast(secured_copc.company_id as varchar(20)) + '|' + cast(secured_copc.profit_ctr_id as varchar(20)) as copc_key,
		RIGHT('00' + CONVERT(VARCHAR,secured_copc.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,secured_copc.profit_ctr_ID), 2) + ' ' + secured_copc.profit_ctr_name as profit_ctr_name_with_key				
	FROM SecuredProfitCenterForGroups secured_copc 
		where secured_copc.user_id = @user_id
		and permission_id = @permission_id
		and action_id = @action_id
		
	
	--SELECT DISTINCT 
	--	apg.permission_id,
	--	secured_copc.company_id, 
	--	secured_copc.profit_ctr_id,
	--	p.profit_ctr_name, 
	--	p.waste_receipt_flag, 
	--	p.workorder_flag,
	--	cast(p.company_id as varchar(20)) + '|' + cast(p.profit_ctr_id as varchar(20)) as copc_key,
	--	RIGHT('00' + CONVERT(VARCHAR,p.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,p.profit_ctr_ID), 2) + ' ' + p.profit_ctr_name as profit_ctr_name_with_key				
	--FROM AccessPermissionGroup apg
	--INNER JOIN AccessGroup ag ON apg.group_id = ag.group_id
	--INNER JOIN AccessGroupSecurity ags ON ags.group_id = uxg.group_id 
	--INNER JOIN dbo.fn_SecuredCompanyProfitCenterExpanded(null, @user_code) secured_copc ON 
	--	(ags.company_id = secured_copc.company_id and ags.profit_ctr_id = secured_copc.profit_ctr_id)
	--	OR
	--	(ags.group_id = apg.group_id AND ags.company_id = -9999 AND ags.profit_ctr_id = -9999)
	--INNER JOIN ProfitCenter p ON p.company_ID = secured_copc.company_id AND p.profit_ctr_ID = secured_copc.profit_ctr_id
	--WHERE 1=1
	--AND apg.permission_id = COALESCE(@permission_id, apg.permission_id)
	--AND uxg.user_id = @user_id  
	--AND ags.company_id IS NOT NULL
	--AND ags.profit_ctr_id IS NOT NULL
	--AND ag.status = 'A'
	--AND p.status = 'A'
	--AND ags.record_type = 'A'
	--AND ags.status = 'A'		
			
/*			
		SELECT DISTINCT 
		apg.permission_id,
		secured_copc.company_id, 
		secured_copc.profit_ctr_id,
		p.profit_ctr_name, 
		p.waste_receipt_flag, 
		p.workorder_flag,
		cast(p.company_id as varchar(20)) + '|' + cast(p.profit_ctr_id as varchar(20)) as copc_key,
		RIGHT('00' + CONVERT(VARCHAR,p.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,p.profit_ctr_ID), 2) + ' ' + p.profit_ctr_name as profit_ctr_name_with_key				
	FROM AccessPermissionGroup apg
	INNER JOIN AccessUserXGroup uxg ON apg.group_id = uxg.group_id
	INNER JOIN AccessGroup ag ON apg.group_id = ag.group_id
	INNER JOIN AccessGroupSecurity ags ON ags.group_id = uxg.group_id 
	INNER JOIN dbo.fn_SecuredCompanyProfitCenterExpanded(null, @user_code) secured_copc ON 
		(ags.company_id = secured_copc.company_id and ags.profit_ctr_id = secured_copc.profit_ctr_id)
		OR
		(ags.group_id = apg.group_id AND ags.company_id = -9999 AND ags.profit_ctr_id = -9999)
	INNER JOIN ProfitCenter p ON p.company_ID = secured_copc.company_id AND p.profit_ctr_ID = secured_copc.profit_ctr_id
	WHERE 1=1
	AND apg.permission_id = COALESCE(@permission_id, apg.permission_id)
	AND uxg.user_id = @user_id  
	AND ags.company_id IS NOT NULL
	AND ags.profit_ctr_id IS NOT NULL
	AND ag.status = 'A'
	AND p.status = 'A'
	AND ags.record_type = 'A'
	AND ags.status = 'A'	
*/

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermission_GetCompanyProfitCenterAccess] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermission_GetCompanyProfitCenterAccess] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermission_GetCompanyProfitCenterAccess] TO [EQAI]
    AS [dbo];

