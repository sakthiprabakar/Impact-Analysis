
CREATE PROCEDURE [dbo].[sp_DashboardResultGetFailedThresholdData]
	@user_id int = NULL, -- if NULL, returns all dashboard data
	@start_date datetime,
	@end_date datetime,
	@tier_id int = NULL, -- Tier 1= Corporate, 2 = Company/Profit Center
	@measurement_filter varchar(50) = 'all' -- Possible values...notification: only measurements that are associated to this user by the notification table, all: display all measurements this user can access, 

	/*	
	Description: 
	Gets the Failed Threshold data for a given user / time frame / tier
	If 'all' is passed as the measurement_filter, then all the threshold data (not just ones the user is associated to for notification)
	If 'notification' is passed to the measurement_filter, then only items that the user is associated as a notification user is returned

	Revision History:
	??/01/2009	RJG 	Created

	Test Cases...
	-- get all of 
	exec sp_DashboardResultGetFailedThresholdData 1206, '09/01/2009', '09/01/2009 23:59:9', NULL, 'all'
	exec sp_DashboardResultGetFailedThresholdData 925, '09/01/2009', '09/01/2009', 'notification'
	exec sp_DashboardResultGetFailedThresholdData NULL, '09/01/2009', '09/01/2009'
*/	
AS
BEGIN

	exec sp_DashboardResultEvaluateThreshold
	
	declare @user_code varchar(50)
	select @user_code = user_code from users where user_id = @user_id
	
	if (@user_id IS NOT NULL)
	BEGIN
			
		/* this table is used for holding what measurement_ids are associated to a permission_id */	
		DECLARE @tblCustomAttributes TABLE
		(
			permission_id int,
			theKey varchar(100),
			theValue varchar(100)
		)
				
		
		--DECLARE cur_Attributes CURSOR FOR
		--	SELECT 
		--		permission_id, report_custom_arguments
		--		FROM view_AccessByUser 
		--		where user_id = @user_id AND record_type = 'R' 
		--		AND report_custom_arguments IS NOT NULL	
		--		AND LEN(report_custom_arguments) > 0
		--		AND CHARINDEX('measurement_id=', report_custom_arguments, 0) > 0
				
		--OPEN cur_Attributes
		
		--		DECLARE @tmp_permission_id int, @tmp_arguments varchar(500)

		--		FETCH NEXT FROM cur_Attributes INTO @tmp_permission_id, @tmp_arguments
		--		WHILE (@@FETCH_STATUS = 0) 
		--		BEGIN
		--			--print cast(@tmp_permission_id as varchar(20)) + ' ' + @tmp_arguments

		--			INSERT INTO @tblCustomAttributes (permission_id, theKey, theValue)
		--				SELECT @tmp_permission_id, 
		--				RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('=',row) - 1))) theKey,
		--				RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('=',row) + 1, LEN(row) - (CHARINDEX('=',row)-1)))) theValue
		--				from dbo.fn_SplitXsvText(',', 0, @tmp_arguments) 
		--				where isnull(row, '') <> '' AND 
		--				RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('=',row) - 1))) = 'measurement_id'		
					
		--			FETCH NEXT FROM cur_Attributes INTO @tmp_permission_id, @tmp_arguments
		--		END
			
		--CLOSE cur_Attributes
		--DEALLOCATE cur_Attributes
		
		INSERT INTO @tblCustomAttributes (permission_id, theValue)
			SELECT permission_id, measurement_id FROM SecuredDashboardMeasurement where user_id = @user_id
		
		--SELECT * FROM @tblCustomAttributes a
		--	INNER JOIN AccessPermission b ON a.permission_id = b.permission_id
		
		if (@measurement_filter = 'all')
		begin
					SELECT DISTINCT 
					   dr.company_id,
					   dr.profit_ctr_id,
					   dr.measurement_id,
					   dm.description,
					   dm.tier_id,
					   dt.tier_name,
					   dr.compliance_flag,
					   dr.answer,
					   dr.report_period_end_date,
					   dr.threshold_value,
					   dr.threshold_operator,
					   dr.threshold_pass,
					   p.profit_ctr_name,
					   RIGHT('00' + CONVERT(VARCHAR,p.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,p.profit_ctr_ID), 2) + ' ' + p.profit_ctr_name as profit_ctr_name_with_key    
				FROM   dashboardresult dr
					   INNER JOIN DashboardMeasurement dm ON dr.measurement_id = dm.measurement_id
					   INNER JOIN @tblCustomAttributes secured_measures ON dm.measurement_id = secured_measures.theValue 
					   INNER JOIN SecuredProfitCenter secure_copc
						ON secure_copc.company_ID = dr.company_id
						AND secure_copc.profit_ctr_id = dr.profit_ctr_id
						AND secure_copc.permission_id = secured_measures.permission_id
						AND secure_copc.user_id = @user_id
					   INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
					   LEFT OUTER JOIN ProfitCenter p ON secure_copc.company_id = p.company_id AND secure_copc.profit_ctr_id = p.profit_ctr_id
				WHERE  threshold_pass = 'F'
					   AND dr.report_period_end_date BETWEEN @start_date AND @end_date
					   AND dm.tier_id = COALESCE(@tier_id, dm.tier_id)
					   
		end -- end @measurement_filter 'all' check
		
		if (@measurement_filter = 'notification')
		begin
		
		SELECT DISTINCT 
					   dr.company_id,
					   dr.profit_ctr_id,
					   dr.measurement_id,
					   dm.description,
					   dm.tier_id,
					   dt.tier_name,
					   dr.compliance_flag,
					   dr.answer,
					   dr.report_period_end_date,
					   dr.threshold_value,
					   dr.threshold_operator,
					   dr.threshold_pass,
					   p.profit_ctr_name,
					   RIGHT('00' + CONVERT(VARCHAR,p.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,p.profit_ctr_ID), 2) + ' ' + p.profit_ctr_name as profit_ctr_name_with_key  
				FROM   dashboardresult dr
					   INNER JOIN DashboardMeasurement dm ON dr.measurement_id = dm.measurement_id
					   INNER JOIN dashboardmeasurementnotification dnotify ON dr.measurement_id = dnotify.measurement_id AND dnotify.user_id = @user_id
					   INNER JOIN @tblCustomAttributes secured_measures ON dm.measurement_id = secured_measures.theValue 
						INNER JOIN SecuredProfitCenter secure_copc
							ON secure_copc.company_ID = dr.company_id
							AND secure_copc.profit_ctr_id = dr.profit_ctr_id
							AND secure_copc.permission_id = secured_measures.permission_id
							AND secure_copc.user_id = @user_id					   
					   INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
					   LEFT OUTER JOIN ProfitCenter p ON secure_copc.company_id = p.company_id AND secure_copc.profit_ctr_id = p.profit_ctr_id
				WHERE  threshold_pass = 'F'
					   AND dr.report_period_end_date BETWEEN @start_date AND @end_date
					   AND dm.tier_id = COALESCE(@tier_id, dm.tier_id)
		
		
		end -- end @measurement_filter notification check
		
	END -- end @user_id null check
      
      ELSE -- return everything, no user specified
      BEGIN
		
		SELECT DISTINCT 
		   dr.company_id,
		   dr.profit_ctr_id,
		   dr.measurement_id,
		   dm.description,
		   dm.tier_id,
		   dt.tier_name,
		   dr.compliance_flag,
		   dr.answer,
		   dr.report_period_end_date,
		   dr.threshold_value,
		   dr.threshold_operator,
		   dr.threshold_pass,
		   p.profit_ctr_name,
		   RIGHT('00' + CONVERT(VARCHAR,p.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,p.profit_ctr_ID), 2) + ' ' + p.profit_ctr_name as profit_ctr_name_with_key  
	FROM   dashboardresult dr
		   INNER JOIN DashboardMeasurement dm ON dr.measurement_id = dm.measurement_id
		   LEFT OUTER JOIN profitcenter p
			 ON p.company_id = dr.company_id
				AND p.profit_ctr_id = dr.profit_ctr_id
		   INNER JOIN DashboardTier dt ON dm.tier_id = dt.tier_id
	WHERE  threshold_pass = 'F'
		   AND dr.report_period_end_date BETWEEN @start_date AND @end_date
		   AND dm.tier_id = COALESCE(@tier_id, dm.tier_id)
      END
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultGetFailedThresholdData] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultGetFailedThresholdData] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardResultGetFailedThresholdData] TO [EQAI]
    AS [dbo];

