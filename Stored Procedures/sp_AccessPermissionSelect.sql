CREATE PROCEDURE [dbo].[sp_AccessPermissionSelect] 
    @permission_id INT = NULL,
	@description varchar(255) = NULL,
	@set_id int = NULL,
	@action_id int = NULL,
	@group_id int = NULL,
	@record_type char(1) = NULL,
	@report_custom_arguments VARCHAR(500) = NULL,
	@report_path VARCHAR(500) = NULL,
	@permission_security_type varchar(15) = NULL
	
	/*	
	Description: 
	Selects permission information given criteria

	Revision History:
	??/01/2009	RJG 	Created
*/		
	
	/*
	 -- Tests
	 sp_AccessPermissionSelect @permission_id=81
	 sp_AccessPermissionSelect @permission_id=40, @description='Rev'
	 sp_AccessPermissionSelect @set_id=22
	 sp_AccessPermissionSelect @action_id=2
	 sp_AccessPermissionSelect @group_id=1000020
	 sp_AccessPermissionSelect @record_type='R'
	 
	 SELECT * FROM AccessPermissionSet
	
	*/
AS 
	SET NOCOUNT ON 
	
	DECLARE @strSQL varchar(max)
	declare @permission_id_varchar varchar(20)
	set @permission_id_varchar = cast(@permission_id as varchar(20))
	
	if @permission_id IS NULL
	BEGIN
		set @permission_id_varchar = 'NULL'
	END
	
	-- select all or a single record

		if object_id('tempdb..#access_result') IS NOT NULL DROP TABLE #access_result
		
		DECLARE @join_permission_group varchar(2000)
		SET @join_permission_group = ''
		
		IF (@group_id IS NOT NULL)
		BEGIN
			SET @join_permission_group = ' INNER JOIN AccessPermissionGroup apg ON ap.permission_id = apg.permission_id AND apg.group_id = ' + CAST(@group_id as varchar(20))
		END		
		
		SET @strSQL =
		'SELECT ap.[permission_id], 
		ap.[customer_delegation_allowed], 
		ap.[dashboard_display], 
		ap.[link_display_on_menu], 
		ap.[link_html_target], 
		ap.[link_text], 
		ap.[link_url], 
		ap.[permission_description], 
		ap.[permission_help_text], 
		ap.[record_type], 
		ap.[report_description], 
		ap.[report_name], 
		ap.[report_path], 
		ap.[report_custom_arguments],
		ap.[report_display_on_menu],
		ap.[report_tier_id],
		aps.set_id,
		aps.set_name,
		ap.[status],
		ap.permission_security_type
		/*
		apa.action_id,
		apa.action_description,
		apa.action_priority
		*/
		INTO #access_result
		FROM   [dbo].[AccessPermission] ap
		INNER JOIN AccessPermissionSet aps ON ap.set_id = aps.set_id	
		/*INNER JOIN AccessAction apa ON ap.action_id = apa.action_id*/
		' + @join_permission_group + ' 
		WHERE 1=1 '
		
		IF (@permission_id IS NULL and @description IS NULL) Or @permission_id IS NOT NULL
		BEGIN			
			SET @strSQL = @strSQL + ' AND
			(
				ap.[permission_id] = ' + @permission_id_varchar + '
				OR ' + @permission_id_varchar + ' IS NULL
			) 	
			AND ap.[status] = ''A''
			'	
		END
		
		IF @description IS NOT NULL AND @permission_id IS NULL
		BEGIN
			SET @strSQL = @strSQL + ' AND (ap.permission_description LIKE ''%' + @description + '%'' OR
											ap.permission_help_text LIKE ''%' + @description + '%'')
				AND ap.[status] = ''A''
			'
		END

		DECLARE 		
			@set_id_varchar varchar(20),
			@action_id_varchar varchar(20),
			@group_id_varchar varchar(20),
			@record_type_varchar varchar(20),
			@report_custom_arguments_varchar VARCHAR(500),
			@report_path_varchar VARCHAR(500),
			@permission_security_type_varchar varchar(15)
			
		SET @set_id_varchar = ISNULL(cast(@set_id as varchar(20)), 'NULL')
		--SET @action_id_varchar = ISNULL(cast(@action_id as varchar(20)), 'NULL')
		SET @group_id_varchar = ISNULL(cast(@group_id as varchar(20)), 'NULL')
		SET @record_type_varchar = ISNULL(cast(@record_type as varchar(20)), 'NULL')
		SET @report_path_varchar = ISNULL(cast(@report_path as varchar(500)), 'NULL')
		SET @report_custom_arguments_varchar = ISNULL(cast(@report_custom_arguments as varchar(500)), 'NULL')
		SET @permission_security_type_varchar = ISNULL(cast(@permission_security_type as varchar(15)), 'NULL')
		
		
		IF LEN(@record_type_varchar) = 1
		BEGIN
			SET @record_type_varchar = '''' + @record_type_varchar + ''''
		END
		
		IF LEN(@report_path_varchar) > 1 AND @report_path_varchar <> 'NULL'
		BEGIN
			SET @report_path_varchar = '''' + @report_path_varchar + ''''
		END
		
		IF LEN(@report_custom_arguments_varchar) > 1 AND @report_custom_arguments_varchar <> 'NULL'
		BEGIN
			SET @report_custom_arguments_varchar = '''' + @report_custom_arguments_varchar + ''''
		END				
		
		IF LEN(@permission_security_type_varchar) > 1 AND @permission_security_type_varchar <> 'NULL'
		BEGIN
			SET @permission_security_type_varchar = '''' + @permission_security_type_varchar + ''''
		END					
	
		
		SET @strSQL = @strSQL + ' AND ap.set_id = COALESCE(' + @set_id_varchar + ', ap.set_id)'
		--SET @strSQL = @strSQL + ' AND ap.action_id = COALESCE(' + @action_id_varchar  + ', ap.action_id)'
		SET @strSQL = @strSQL + ' AND ap.record_type = COALESCE(' + @record_type_varchar  + ', ap.record_type)'
		
		IF (@permission_security_type_varchar <> 'NULL')
		begin
			SET @strSQL = @strSQL + ' AND isnull(ap.permission_security_type,'''') = isnull(' + @permission_security_type_varchar + ','''') '
		end 
		
		IF (@report_custom_arguments_varchar <> 'NULL')
		BEGIN
			SET @strSQL = @strSQL + ' AND ap.report_custom_arguments = COALESCE(' + @report_custom_arguments_varchar  + ', ap.report_custom_arguments)'
		END
		
		IF (@report_path_varchar <> 'NULL')
		BEGIN
			SET @strSQL = @strSQL + ' AND ap.report_path = COALESCE(' + @report_path_varchar  + ', ap.report_path)'
		END
		
		
		SET @strSQL = @strSQL + '
		
			SELECT * FROM #access_result ORDER BY permission_description
			
			SELECT DISTINCT apg.permission_id, ag.* FROM AccessPermissionGroup apg 
			INNER JOIN #access_result ar ON ar.permission_id = apg.permission_id
			INNER JOIN AccessGroup ag ON apg.group_id = ag.group_id	and ag.status = ''A''
			INNER JOIN AccessAction aa ON apg.action_id = aa.action_id
			
			SELECT DISTINCT apg.permission_id, apg.group_id, apg.action_id, aa.action_description FROM AccessPermissionGroup apg
			INNER JOIN #access_result ar ON ar.permission_id = apg.permission_id
			INNER JOIN AccessAction aa ON apg.action_id = aa.action_id
			ORDER BY apg.action_id desc				
		'
		
		--print @strSQL
		exec(@strSQL)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessPermissionSelect] TO [EQAI]
    AS [dbo];

