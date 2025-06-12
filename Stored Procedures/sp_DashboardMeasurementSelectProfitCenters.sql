CREATE PROCEDURE [dbo].[sp_DashboardMeasurementSelectProfitCenters] 
    @measurement_id INT = NULL
/*	
	Description: 
	Selects only the profit centers associated with the measurement

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 
	DECLARE @is_all_copc char(1)
	
	SELECT @is_all_copc = copc_all_flag FROM DashboardMeasurement WHERE measurement_id = @measurement_id
	if @is_all_copc = 'T'
	begin
			SELECT p.company_id, 
			p.profit_ctr_id, 
			p.profit_ctr_name, 
			p.waste_receipt_flag, 
			p.workorder_flag,
			cast(p.company_id as varchar(20)) + '|' + cast(p.profit_ctr_id as varchar(20)) as copc_key,
			RIGHT('00' + CONVERT(VARCHAR,p.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,p.profit_ctr_ID), 2) + ' ' + p.profit_ctr_name as profit_ctr_name_with_key
			FROM  ProfitCenter p 
		WHERE p.status = 'A'	
		ORDER BY p.profit_ctr_name			
	end
	else
	begin
	SELECT 
			p.company_id, 
			p.profit_ctr_id, 
			p.profit_ctr_name, 
			p.waste_receipt_flag, 
			p.workorder_flag,
			cast(p.company_id as varchar(20)) + '|' + cast(p.profit_ctr_id as varchar(20)) as copc_key,
			RIGHT('00' + CONVERT(VARCHAR,p.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,p.profit_ctr_ID), 2) + ' ' + p.profit_ctr_name as profit_ctr_name_with_key
			FROM  DashboardMeasurement dm
		INNER JOIN DashboardMeasurementProfitCenter dmpc ON dm.measurement_id = dmpc.measurement_id
		INNER JOIN ProfitCenter p 
			ON p.company_id = dmpc.company_id
			AND p.profit_ctr_id = dmpc.profit_ctr_id
			and p.status = 'A'	
		WHERE dm.measurement_id = @measurement_id
		ORDER BY p.profit_ctr_name		
	end
	


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectProfitCenters] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectProfitCenters] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectProfitCenters] TO [EQAI]
    AS [dbo];

