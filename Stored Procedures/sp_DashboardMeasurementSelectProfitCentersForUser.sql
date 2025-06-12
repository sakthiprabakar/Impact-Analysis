
CREATE PROCEDURE sp_DashboardMeasurementSelectProfitCentersForUser
	@measurement_id int,
	@user_id int
	
/*	
	Description: 
	Returns the associated profit centers for a given measurement AND user

	Revision History:
	??/01/2009	RJG 	Created
	01/25/2010	RJG		Changed Co/Pc access to be filtered only by the groups that give them access to the measurement
	02/02/2010	RJG		Added join to DashboardMeasurementXProfitCenter
*/			
AS
--DECLARE @measurement_id int
--DECLARE @user_id int
DECLARE @user_code varchar(20)
/*
SET @measurement_id = 26
SET @user_id = 925
*/

SELECT @user_code = user_code FROM Users where [user_id] = @user_id

DECLARE @measurement_permission int
SELECT @measurement_permission = permission_id FROM AccessPermission where report_custom_arguments = 'measurement_id=' + CAST(@measurement_id as varchar(20)) and status='A'
	
--SELECT @measurement_permission

	SELECT 
		@measurement_permission as permission_id,
		p.company_id, 
		p.profit_ctr_id,
		p.profit_ctr_name, 
		p.waste_receipt_flag, 
		p.workorder_flag,
		cast(p.company_id as varchar(20)) + '|' + cast(p.profit_ctr_id as varchar(20)) as copc_key,
		RIGHT('00' + CONVERT(VARCHAR,p.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,p.profit_ctr_ID), 2) + ' ' + p.profit_ctr_name as profit_ctr_name_with_key					
	FROM
	SecuredProfitCenter p
	INNER JOIN DashboardMeasurementProfitCenter dpc ON p.company_ID = dpc.company_id
		AND p.profit_ctr_ID = dpc.profit_ctr_id
		AND dpc.measurement_id = @measurement_id
	INNER JOIN DashboardMeasurement dm ON dm.measurement_id = @measurement_id
	where p.user_id = @user_id
	AND p.permission_id = @measurement_permission
	AND dm.status = 'A'
		
	UNION
	
	SELECT DISTINCT 
		@measurement_permission as permission_id,
		p.company_id, 
		p.profit_ctr_id,
		p.profit_ctr_name, 
		p.waste_receipt_flag, 
		p.workorder_flag,
		cast(p.company_id as varchar(20)) + '|' + cast(p.profit_ctr_id as varchar(20)) as copc_key,
		RIGHT('00' + CONVERT(VARCHAR,p.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,p.profit_ctr_ID), 2) + ' ' + p.profit_ctr_name as profit_ctr_name_with_key					
	FROM
	SecuredProfitCenter p
	INNER JOIN DashboardMeasurement dm ON dm.copc_all_flag='T'
		AND dm.measurement_id = @measurement_id
	where p.user_id = @user_id
	AND p.permission_id = @measurement_permission
	AND dm.status = 'A'
	ORDER BY p.company_ID, p.profit_ctr_ID, p.profit_ctr_name	
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectProfitCentersForUser] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectProfitCentersForUser] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardMeasurementSelectProfitCentersForUser] TO [EQAI]
    AS [dbo];

