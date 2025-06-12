
CREATE PROCEDURE sp_DashboardMeasurementSelectForUser
	@user_id int,
	@tier_id int = NULL,
	@time_period varchar(50) = NULL,
	@action_id int = NULL
/*	
	Description: 
	Selects measurements that a user has access to

	Revision History:
	??/01/2009	RJG 	Created
	01/21/2010	RJG		Modified to filter out any measurements that the user may have access to but does not have acess to any of their related co/pcs
	
	
	
--exec sp_DashboardMeasurementSelectForUser 1206, null, null, 2
--exec sp_DashboardMeasurementSelectForUser 1207
--exec sp_DashboardMeasurementSelectForUser 1206
--exec sp_DashboardMeasurementSelectForUser 1206
--exec sp_DashboardMeasurementSelectForUser 925
	
*/			
AS
BEGIN		
		
	declare @attribute_list varchar(100)

	DECLARE @tblCustomAttributes TABLE
	(
		permission_id int,
		theKey varchar(100),
		theValue varchar(100)
	)
	
	DECLARE cur_Attributes CURSOR FOR
		SELECT 
			permission_id, report_custom_arguments
			FROM view_AccessByUser 
			where user_id = @user_id AND record_type = 'R' 
			AND report_custom_arguments IS NOT NULL	
			AND LEN(report_custom_arguments) > 0
			AND CHARINDEX('measurement_id=', report_custom_arguments, 0) > 0
			
	OPEN cur_Attributes
	
			DECLARE @tmp_permission_id int, @tmp_arguments varchar(500)

			FETCH NEXT FROM cur_Attributes INTO @tmp_permission_id, @tmp_arguments
			WHILE (@@FETCH_STATUS = 0) 
			BEGIN
				--print cast(@tmp_permission_id as varchar(20)) + ' ' + @tmp_arguments

				INSERT INTO @tblCustomAttributes (permission_id, theKey, theValue)
					SELECT @tmp_permission_id, 
					RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('=',row) - 1))) theKey,
					RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('=',row) + 1, LEN(row) - (CHARINDEX('=',row)-1)))) theValue
					from dbo.fn_SplitXsvText(',', 0, @tmp_arguments) 
					where isnull(row, '') <> '' AND 
					RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('=',row) - 1))) = 'measurement_id'		
				
				FETCH NEXT FROM cur_Attributes INTO @tmp_permission_id, @tmp_arguments
			END
			
	
CLOSE cur_Attributes
	DEALLOCATE cur_Attributes	
	
	
	
	/* this section will create a temp table that will be used to filter out
			measurements that the user has access to but the MEASUREMENT is not associated with
		*/
		declare @user_code varchar(20)
		SELECT @user_code = user_code FROM Users where [user_id] = @user_id
		
		--SELECT '@tblCustomAttributes', * FROM @tblCustomAttributes
		
		
		/* handle co/pc measurements */
		SELECT DISTINCT 
			user_measurements.permission_id, 
			m.measurement_id,
			dash_pc.company_id,
			dash_pc.profit_ctr_id
		INTO #measure_copc_temp
		FROM   DashboardMeasurement m
			INNER JOIN DashboardMeasurementProfitCenter dash_pc ON m.measurement_id = dash_pc.measurement_id
			INNER JOIN @tblCustomAttributes user_measurements ON user_measurements.theValue = m.measurement_id				 
			INNER JOIN SecuredProfitCenter secured_copc
				ON dash_pc.company_ID = secured_copc.company_ID
				AND dash_pc.profit_ctr_ID = secured_copc.profit_ctr_ID
				AND secured_copc.user_id = @user_id
				AND secured_copc.permission_id = user_measurements.permission_id
		WHERE  m.copc_all_flag = 'F'
			   AND m.status = 'A'
			   AND m.tier_id = 2 	
			   
			   

	/* Handle corporate measurements */
		INSERT INTO #measure_copc_temp (permission_id, measurement_id, company_id, profit_ctr_id)
		SELECT DISTINCT 
			user_measurements.permission_id,
			m.measurement_id,
			secured_copc.company_id,
			secured_copc.profit_ctr_id
		FROM   dashboardmeasurement m
			   INNER JOIN @tblCustomAttributes user_measurements ON user_measurements.theValue = m.measurement_id
			   INNER JOIN SecuredProfitCenter secured_copc ON user_measurements.permission_id = secured_copc.permission_id
				AND secured_copc.user_id = @user_id
		WHERE  (m.copc_all_flag = 'T' or m.tier_id = 1) -- all copc or coprorate tier
			   AND m.status = 'A'		
			   
			   --SELECT * FROM #measure_copc_temp
			   
	SELECT DISTINCT measure.measurement_id,
			   measure.[added_by],
			   measure.[compliance_flag],
			   measure.[dashboard_type_id],
			   measure.[date_added],
			   measure.[date_modified],
			   measure.[description],
			   measure.[display_format],
			   measure.[editable],
			   measure.[modified_by],
			   measure.[threshold_operator],
			   measure.[notification_flag],
			   measure.[threshold_value],
			   measure.threshold_type,
			   measure.[sort_order],
			   measure.[source],
			   measure.[status],
			   measure.[time_period],
			   measure.source_stored_procedure,
			   measure.source_stored_procedure_type,
			   tier.[tier_id],
			   tier.tier_name,
			   dash_type.description as dashboard_type_description,
			   measure.copc_waste_receipt_flag,
			   measure.copc_workorder_flag,
			   measure.copc_all_flag
		FROM   [dbo].[DashboardMeasurement] measure
			INNER JOIN DashboardTier tier ON measure.tier_id = tier.tier_id
			INNER JOIN DashboardType dash_type ON dash_type.dashboard_type_id = measure.dashboard_type_id
			INNER JOIN @tblCustomAttributes user_measurements ON user_measurements.theValue = measure.measurement_id
			INNER JOIN AccessPermissionGroup apg ON apg.permission_id = user_measurements.permission_id
				AND apg.action_id = COALESCE(@action_id, apg.action_id)	
		WHERE  measure.status = 'A'
		AND measure.time_period = COALESCE(@time_period, measure.time_period)
		AND measure.tier_id = COALESCE(@tier_id, measure.tier_id)	
		AND EXISTS ( SELECT 1 FROM SecuredProfitCenterForGroups spg
			where spg.action_id = COALESCE(@action_id, spg.action_id)	
			AND spg.permission_id = user_measurements.permission_id
			AND spg.permission_id = apg.permission_id
			AND spg.group_id = apg.group_id
			AND spg.user_id = @user_id
			)
			
		--AND EXISTS (
		--	SELECT 1 FROM AccessPermissionGroup apg
		--		INNER JOIN AccessGroup ag ON apg.group_id = ag.group_id and ag.status = 'A'
		--		INNER JOIN @tblCustomAttributes secured_measurements ON secured_measurements.permission_id = apg.permission_id
		--		INNER JOIN AccessGroupSecurity ags ON ag.group_id = ags.group_id
		--		AND ags.user_id = @user_id
		--		AND ags.status = 'A'
		--		INNER JOIN SecuredProfitCenterForGroups secured_copc
  --                   ON 
  --                     ((ags.profit_ctr_id = secured_copc.profit_ctr_id AND ags.company_id = secured_copc.company_id)
  --                     /* handle the magic number 'all facility' access */
  --                     OR (ags.company_id = -9999 and ags.profit_ctr_id = -9999))
  --                     AND secured_copc.permission_id = secured_measurements.permission_id
  --                     AND ags.group_id = secured_copc.group_id
		--				AND secured_copc.action_id = COALESCE(@action_id, secured_copc.action_id)	
		--			INNER JOIN #measure_copc_temp
  --                   ON #measure_copc_temp.permission_id = apg.permission_id
  --                      AND secured_copc.company_id = #measure_copc_temp.company_id
  --                      AND secured_copc.profit_ctr_id = #measure_copc_temp.profit_ctr_id
  --                      AND secured_copc.permission_id = #measure_copc_temp.permission_id									
		--)
		/*AND EXISTS (
			/* this query filters out any Measurements that a user has access to but does NOT
			have access to any of their co/pcs that the measure is associated with */

			/* check "normal" co/pc assignments */
			SELECT 1
            FROM   AccessPermissionGroup apg
                    INNER JOIN AccessGroup ag
                     ON apg.group_id = ag.group_id
				    INNER JOIN AccessGroupSecurity ags ON
						ags.user_id = @user_id
					INNER JOIN SecuredProfitCenterForGroups secured_copc
                     ON 
                       ((ags.profit_ctr_id = secured_copc.profit_ctr_id AND ags.company_id = secured_copc.company_id)
                       /* handle the magic number 'all facility' access */
                       OR (ags.company_id = -9999 and ags.profit_ctr_id = -9999))
                       AND ags.group_id = secured_copc.group_id
						AND secured_copc.action_id = COALESCE(@action_id, secured_copc.action_id)
                   INNER JOIN #measure_copc_temp
                     ON #measure_copc_temp.permission_id = apg.permission_id
                        AND secured_copc.company_id = #measure_copc_temp.company_id
                        AND secured_copc.profit_ctr_id = #measure_copc_temp.profit_ctr_id
                        AND secured_copc.permission_id = #measure_copc_temp.permission_id
            WHERE  1 = 1
                   AND secured_copc.user_id = @user_id
                   AND ag.status = 'A'
                   AND apg.permission_id = user_measurements.permission_id 
		)*/
		
		ORDER BY measure.[Description] ASC			   	   			
	

--SELECT 'temp', * FROM #measure_copc_temp
/*
	SELECT DISTINCT measure.measurement_id,
			   measure.[added_by],
			   measure.[compliance_flag],
			   measure.[dashboard_type_id],
			   measure.[date_added],
			   measure.[date_modified],
			   measure.[description],
			   measure.[display_format],
			   measure.[editable],
			   measure.[modified_by],
			   measure.[threshold_operator],
			   measure.[notification_flag],
			   measure.[threshold_value],
			   measure.threshold_type,
			   measure.[sort_order],
			   measure.[source],
			   measure.[status],
			   measure.[time_period],
			   measure.source_stored_procedure,
			   measure.source_stored_procedure_type,
			   tier.[tier_id],
			   tier.tier_name,
			   dash_type.description as dashboard_type_description,
			   measure.copc_waste_receipt_flag,
			   measure.copc_workorder_flag,
			   measure.copc_all_flag
		FROM   [dbo].[DashboardMeasurement] measure
			INNER JOIN DashboardTier tier ON measure.tier_id = tier.tier_id
			INNER JOIN DashboardType dash_type ON dash_type.dashboard_type_id = measure.dashboard_type_id
			INNER JOIN @tblCustomAttributes user_measurements ON user_measurements.theValue = measure.measurement_id
		WHERE  measure.status = 'A'
		AND measure.time_period = COALESCE(@time_period, measure.time_period)
		AND measure.tier_id = COALESCE(@tier_id, measure.tier_id)	
		AND EXISTS (
			/* this query filters out any Measurements that a user has access to but does NOT
			have access to any of their co/pcs that the measure is associated with */

			/* check "normal" co/pc assignments */
			SELECT 1
            FROM   AccessPermissionGroup apg
                    INNER JOIN AccessGroup ag
                     ON apg.group_id = ag.group_id
				    INNER JOIN AccessGroupSecurity ags ON
						ags.user_id = @user_id
					INNER JOIN SecuredProfitCenterForGroups secured_copc
                     ON 
                       ((ags.profit_ctr_id = secured_copc.profit_ctr_id AND ags.company_id = secured_copc.company_id)
                       /* handle the magic number 'all facility' access */
                       OR (ags.company_id = -9999 and ags.profit_ctr_id = -9999))
                       AND ags.group_id = secured_copc.group_id
						AND secured_copc.action_id = COALESCE(@action_id, secured_copc.action_id)
                   INNER JOIN #measure_copc_temp
                     ON #measure_copc_temp.permission_id = apg.permission_id
                        AND secured_copc.company_id = #measure_copc_temp.company_id
                        AND secured_copc.profit_ctr_id = #measure_copc_temp.profit_ctr_id
                        AND secured_copc.permission_id = #measure_copc_temp.permission_id
            WHERE  1 = 1
                   AND secured_copc.user_id = @user_id
                   AND ag.status = 'A'
                   AND apg.permission_id = user_measurements.permission_id 
		)
		
		ORDER BY measure.[Description] ASC		

*/		          
END			
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectForUser] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectForUser] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectForUser] TO [EQAI]
    AS [dbo];

