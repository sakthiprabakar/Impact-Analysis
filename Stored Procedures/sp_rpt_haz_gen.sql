
/*******************************************************
** sp_rpt_haz_gen.sql
** 
** GEMINI INFORMATION 
** 	PROJ-20521 - Monthly Hazardous Waste Report
** Each month the facility is required to create a inbound hazardous waste report.
** We have been manually creating this information for the past year. 
** 
** Here is the format of the report.
** RE	Name of Facility	EPA ID Number	Month	Waste Codes	Generator EPA ID #	Transporter EPA ID #	Amount in Pounds	Handling Codes
** Typically I make each line of the manifest a separate entry. 
** The handling codes(different then managment codes) I can apply, but if we could make it show bulk vs non-bulk that would be helpful. 
** The weight could be a difficult one on bulk receipts...Typically I take the manifested gallons and then pull the fingerprint SG and multiply it out. 
** 
** HISTORY
** CRG - 03/28/2012 - Created 
** 
** EXAMPLE
EXEC sp_rpt_haz_gen 
	@user_code=N'COREY_GO',
	@permission_id=244,
	@from_date = '12/01/2011', 
	@to_date = '12/31/2011',
	@copc_list = '29|0'
	
*******************************************************/
CREATE PROCEDURE sp_rpt_haz_gen @from_date DATETIME
	,@to_date DATETIME
	,@user_code VARCHAR(20)
	,@permission_id INT
	,@copc_list VARCHAR(max) = 'All'
AS
--perms
SELECT DISTINCT customer_id
	,cust_name
INTO #Secured_Customer
FROM SecuredCustomer sc
WHERE sc.user_code = @user_code
	AND sc.permission_id = @permission_id

DECLARE @tbl_profit_center_filter TABLE (
	[company_id] INT
	,profit_ctr_id INT
	)

IF @copc_list <> 'All'
BEGIN
	INSERT @tbl_profit_center_filter
	SELECT secured_copc.company_id
		,secured_copc.profit_ctr_id
	FROM SecuredProfitCenter secured_copc
	INNER JOIN (
		SELECT RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|', row) - 1))) company_id
			,RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|', row) + 1, LEN(row) - (CHARINDEX('|', row) - 1)))) profit_ctr_id
		from dbo.fn_SplitXsvText(',', 0, @copc_list)
		WHERE isnull(row, '') <> ''
		) selected_copc ON secured_copc.company_id = selected_copc.company_id
		AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
		AND secured_copc.permission_id = @permission_id
		AND secured_copc.user_code = @user_code
END
ELSE
BEGIN
	INSERT @tbl_profit_center_filter
	SELECT secured_copc.company_id
		,secured_copc.profit_ctr_id
	FROM SecuredProfitCenter secured_copc
	WHERE secured_copc.permission_id = @permission_id
		AND secured_copc.user_code = @user_code
END

SELECT receipt.receipt_id
	,receipt.line_id
	,receipt.receipt_status
	,ProfitCenter.profit_ctr_name --Name of Facility
	,ProfitCenter.EPA_ID --EPA ID Number
	,DATENAME(month, receipt_date) AS 'Month Name' --Month
	,NULLIF(STUFF(PROFILE.waste_code + Coalesce(', ' + NULLIF(dbo.fn_approval_sec_waste_code_list(receipt.profile_id, 'P'), ''), ''), 1, 0, ''), 'NONE') AS 'waste_codes' --WasteCodes
	,generator.EPA_ID AS 'Generator EPA ID' --Generator EPA ID
	,generator.generator_id
	,transporter.transporter_EPA_ID --Transporter EPA ID
	--Handling Codes
	,receipt.manifest_management_code --Management Code
	,receipt.bulk_flag -- bulk
	--weight
	,[Plt_AI].[dbo].[fn_receipt_weight_line] (Receipt.receipt_id, receipt.line_id, receipt.profit_ctr_id, receipt.company_id) as lb_weight 
    --, receipt.*
FROM Receipt
  JOIN Profile ON (Receipt.profile_id = Profile.Profile_id)
LEFT OUTER JOIN wastecode w ON w.waste_code_uid = PROFILE.waste_code_uid
   JOIN Generator ON (Receipt.generator_id = Generator.generator_id)
  JOIN Transporter ON (Receipt.hauler = Transporter.transporter_code)
  JOIN ProfitCenter ON (Receipt.company_id = ProfitCenter.company_id
   AND Receipt.profit_ctr_id = ProfitCenter.profit_ctr_id)
  --make sure company and profit center has permissions
INNER JOIN @tbl_profit_center_filter copc ON receipt.company_id = copc.company_ID
	AND receipt.profit_ctr_id = copc.profit_ctr_ID
WHERE receipt_date BETWEEN @from_date AND @to_date
	AND Trans_type = 'D'
	AND Trans_Mode  = 'I'
	AND fingerpr_status = 'A'
	AND receipt.receipt_status = 'A'
ORDER BY receipt.receipt_id
	,receipt.line_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_haz_gen] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_haz_gen] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_haz_gen] TO [EQAI]
    AS [dbo];

