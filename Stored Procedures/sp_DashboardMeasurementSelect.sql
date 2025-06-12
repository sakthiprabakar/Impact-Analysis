CREATE PROCEDURE [dbo].[sp_DashboardMeasurementSelect] 
    @measurement_id INT = NULL,
    @description varchar(500) = NULL,
    @source varchar(50) = NULL,
    @time_period varchar(50) = NULL,
    @status varchar(50) = 'A',
    @tier_id int = NULL,
    @notification_flag char(1) = NULL,
    @category_id int = NULL
    
/*	
	Description: 
	If measurement_id is specified, returns the requested measurement
	If search criteria is specified, returns all search results

	Revision History:
	??/01/2009	RJG 	Created
	01/11/2010	RJG		Added category_id filter
*/			
AS 

	IF (@measurement_id IS NULL AND @description IS NULL) OR @measurement_id IS NOT NULL
	BEGIN
		SELECT measure.[measurement_id],
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
		WHERE  (@measurement_id IS NULL OR [measurement_id] = @measurement_id) 
		AND measure.status = COALESCE(@status, measure.status)
		AND measure.source = COALESCE(@source, measure.source)
		AND measure.time_period = COALESCE(@time_period, measure.time_period)
		AND measure.tier_id = COALESCE(@tier_id, measure.tier_id)	
		AND measure.notification_flag = COALESCE(@notification_flag, measure.notification_flag)		
		AND EXISTS( SELECT TOP 1 category_id FROM DashboardCategoryXMeasurement dcat WHERE dcat.category_id = COALESCE(@category_id, dcat.category_id) AND dcat.measurement_id = measure.measurement_id)
		
	ORDER BY measure.[Description] ASC	

	
	END
	
	IF @description IS NOT NULL
	BEGIN
		SELECT measure.[measurement_id],
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
			   measure.copc_all_flag,
			   source_stored_procedure_type
		FROM   [dbo].[DashboardMeasurement] measure
			INNER JOIN DashboardTier tier ON measure.tier_id = tier.tier_id
			INNER JOIN DashboardType dash_type ON dash_type.dashboard_type_id = measure.dashboard_type_id
		WHERE  measure.[description] LIKE '%' + @description + '%'
		AND measure.status = COALESCE(@status, measure.status)
		AND measure.source = COALESCE(@source, measure.source)
		AND measure.time_period = COALESCE(@time_period, measure.time_period)
		AND measure.tier_id = COALESCE(@tier_id, measure.tier_id)	
		AND measure.notification_flag = COALESCE(@notification_flag, measure.notification_flag)
		AND EXISTS( SELECT TOP 1 category_id FROM DashboardCategoryXMeasurement dcat WHERE dcat.category_id = COALESCE(@category_id, dcat.category_id) AND dcat.measurement_id = measure.measurement_id)
	ORDER BY measure.[Description] ASC	
	END
	
	
		
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelect] TO [EQAI]
    AS [dbo];

