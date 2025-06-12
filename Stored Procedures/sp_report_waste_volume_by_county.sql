
create proc sp_report_waste_volume_by_county (
	@copc_list			varchar(max) = null
	, @start_date		datetime
	, @end_date			datetime
	, @user_code		varchar(20)
	, @permission_id	int
)
as
/* **************************************************************************
sp_report_waste_volume_by_county

Reports all waste received broken by generator county

History:
2015-11-03	JPB	Created

Sample:
sp_report_waste_volume_by_county 
	@copc_list			= '2|0,3|0,21|0,41|0'
	, @start_date		= '1/1/2015'
	, @end_date			= '7/31/2015'
	, @user_code		= 'JONATHAN'
	, @permission_id	= 329


**************************************************************************  */

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- Make sure End Date is inclusive
if datepart(hh, @end_date) = 0
	set @end_date = @end_date + 0.99999

-- Filter by user choice/permission:
declare @tbl_profit_center_filter table (
	[company_id] int, 
	profit_ctr_id int
)	

if @copc_list <> 'All'
begin
	INSERT @tbl_profit_center_filter 
	SELECT 
	secured_copc.company_id, secured_copc.profit_ctr_id 
	FROM 
		SecuredProfitCenter secured_copc (nolock)
	INNER JOIN (
		SELECT 
			RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
			RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
		from dbo.fn_SplitXsvText(',', 0, @copc_list) 
		where isnull(row, '') <> '') selected_copc 
			ON secured_copc.company_id = selected_copc.company_id 
			AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
			and secured_copc.permission_id = @permission_id
			and secured_copc.user_code = @user_code
end		
else
begin

	INSERT @tbl_profit_center_filter
	SELECT secured_copc.company_id
		   ,secured_copc.profit_ctr_id
	FROM   SecuredProfitCenter secured_copc (nolock)
	WHERE  secured_copc.permission_id = @permission_id
		   AND secured_copc.user_code = @user_code 
end


SELECT   
     G.Generator_Country,
     G.Generator_State,
     C.County_Name,
     R.Treatment_ID,
     Wt.Category,
     Wt.Description,
     Tp.Treatment_Process,
     Ds.Disposal_Service_Desc,
     R.Company_ID,
     R.Profit_Ctr_ID,
     R.Receipt_ID,
     R.Line_ID,
     R.Trans_Mode,
     R.Trans_Type,
     R.Receipt_Status,
     R.Submitted_Flag,
     R.Manifest_Flag,
     R.Manifest,
     R.Customer_ID,
     R.Generator_ID,
     R.Load_Generator_Epa_ID,
     R.Profile_ID,
     R.Approval_Code,
     R.Manifest_Quantity,
     R.Manifest_Unit,
     R.Quantity,
     R.Bill_Unit_Code,
     R.Line_Weight,
     (r.Line_Weight / 2000) As Calculated_Line_Tons,
     R.Container_Count,
     R.Bulk_Flag,
     R.Receipt_Date
FROM     
	receipt r
	INNER JOIN @tbl_profit_center_filter tpcf
		on r.company_id = tpcf.company_id
		and r.profit_ctr_id = tpcf.profit_ctr_id
	INNER JOIN Generator g
		ON r.generator_id = g.generator_id
	INNER JOIN County AS c
		ON g.generator_county = c.county_code
	INNER JOIN treatmentheader AS th
		ON r.treatment_id = th.treatment_id
	INNER JOIN dbo.WasteType AS wt
		ON th.wastetype_id = wt.wastetype_id
	INNER JOIN dbo.DisposalService AS ds
		ON th.disposal_service_id = ds.disposal_service_id
	INNER JOIN dbo.TreatmentProcess AS tp
		ON th.treatment_process_id = tp.treatment_process_id
	INNER JOIN dbo.BillUnit AS bu
		ON r.bill_unit_code = bu.bill_unit_code
WHERE 1=1  
	-- r.company_id = 41 AND r.profit_ctr_id = 0
	AND r.receipt_date between @start_date and @end_date
	AND r.trans_mode = 'I'
	AND r.fingerpr_status <> 'v'
	AND r.receipt_status NOT IN ('V', 'R')
	AND r.trans_type = 'D'
ORDER BY 
	r.company_id, 
	r.profit_ctr_id, 
	r.receipt_id, 
	r.line_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_waste_volume_by_county] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_waste_volume_by_county] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_waste_volume_by_county] TO [EQAI]
    AS [dbo];

