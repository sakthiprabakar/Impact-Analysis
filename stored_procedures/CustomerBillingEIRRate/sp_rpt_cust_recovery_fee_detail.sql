USE [PLT_AI]
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_rpt_cust_recovery_fee_detail]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_rpt_cust_recovery_fee_detail] (@customer_id INT, @billing_project_id INT)
AS
/*************************************************************************************************
PB Object : r_rpt_customer_recovery_fee_details

7/10/2024 Prakash US116969 Initial version.   
*************************************************************************************************/
BEGIN
	DECLARE @today DATETIME = CAST(GETDATE() AS DATETIME)
	
	DROP TABLE IF EXISTS #temp
	CREATE TABLE #temp (customer_id INT NOT NULL,
						billing_project_id INT NOT NULL,
						eec_date_effective DATETIME NULL,
						eec_apply_fee_flag CHAR(1) NULL,
						use_corporate_rate CHAR(1) NULL,
						eir_rate MONEY NULL,
						eir_date_effective DATETIME NULL,
						eir_apply_fee_flag CHAR(1) NULL)
 
	INSERT INTO #temp (customer_id, billing_project_id)
	SELECT @customer_id, @billing_project_id;

	WITH eec_info AS (SELECT TOP 1 date_effective, apply_fee_flag
					FROM dbo.CustomerBillingFRFRate
					WHERE customer_id = @customer_id
					AND	billing_project_id = @billing_project_id
					AND CAST(date_effective AS DATETIME) <= @today
					ORDER BY date_effective DESC)

	UPDATE #temp
	SET #temp.eec_date_effective = eec_info.date_effective,
		#temp.eec_apply_fee_flag = eec_info.apply_fee_flag
	FROM #temp, eec_info;
 
	WITH eir_info AS (SELECT TOP 1 use_corporate_rate, dbo.fn_geteirrate (date_effective ) AS eir_rate, date_effective, apply_fee_flag
					FROM dbo.CustomerBillingEIRRate
					WHERE customer_id = @customer_id
					AND	billing_project_id = @billing_project_id
					AND date_effective <= @today
					ORDER BY date_effective DESC)

	UPDATE #temp
	SET #temp.use_corporate_rate = eir_info.use_corporate_rate,
		#temp.eir_rate = eir_info.eir_rate,
		#temp.eir_date_effective = eir_info.date_effective,
		#temp.eir_apply_fee_flag = eir_info.apply_fee_flag
	FROM #temp, eir_info 
 
	SELECT eec_date_effective,
		eec_apply_fee_flag,
		use_corporate_rate,
		eir_rate,
		eir_date_effective,
		eir_apply_fee_flag
	FROM #temp
	WHERE eec_date_effective IS NOT NULL
		OR eir_date_effective IS NOT NULL

	DROP TABLE #temp
END 
GO

GRANT EXECUTE on [dbo].[sp_rpt_cust_recovery_fee_detail] TO EQAI
GO
