CREATE PROCEDURE sp_reports_wm_validation
	@StartDate datetime,
	@EndDate datetime,
	@copc_list varchar(max) = NULL, -- ex: 21|1,14|0,14|1
	@user_code varchar(100) = NULL, -- for associates
	@contact_id int = NULL, -- for customers
	@permission_id int,
	@report_log_id int,
	@debug int = 0
AS

/* ******************************************************************************
sp_reports_wm_validation
- Performs all the distinct and far flung validations done for WM, in one shot, on 1 range, no extract records generated.

	sp_sequence_next 'reportlog.report_log_id'

	exec sp_reports_wm_validation 
		@StartDate = '5/1/2015',
		@EndDate = '5/31/2015',
		@copc_list  = '2|21,3|1,12|0,12|1,12|2,12|3,12|4,12|5,12|7,14|0,14|1,14|2,14|3,14|4,14|5,14|6,14|9,14|10,14|11,15|1,15|2,15|3,15|4,16|0,17|0,18|0,21|0,21|1,21|2,21|3,22|0,22|1,23|0,24|0,25|0,25|4,26|0,27|0,28|0,29|0',
		@user_code  = 'jonathan', -- for associates
		@contact_id = NULL, -- for customers
		@permission_id = 179,
		@report_log_id =332695,
		@debug = 1

	select top 3 * from plt_export..export order by date_added desc

Approvals on the receipt differ from WO: 22-0:7307500 : WMHW01 in WO, not Receipt, WMHW02L in WO, not Receipt, WMHW02L2 in WO, not Receipt, WMHW02S1 in WO, not Receipt, WMHW02S2 in WO, not Receipt, WMHW02S3 in WO, not Receipt, WMHW02S4 in WO, not Receipt, WMHW03L1 in WO, not Receipt, WMHW03L2 in WO, not Receipt, WMHW03S1 in WO, not Receipt, WMHW03S2 in WO, not Receipt, WMHW04L in WO, not Receipt, WMHW05L in WO, not Receipt, WMHW06L in WO, not Receipt, WMHW06S in WO, not Receipt, WMHW07 in WO, not Receipt, WMHW08 in WO, not Receipt, WMHW09 in WO, not Receipt, WMHW10 in WO, not Receipt, WMHW11 in WO, not Receipt, WMNHW01 in WO, not Receipt, WMNHW02 in WO, not Receipt, WMNHW03 in WO, not Receipt, WMNHW04 in WO, not Receipt, WMNHW05 in WO, not Receipt, WMNHW06 in WO, not Receipt, WMNHW07 in WO, not Receipt, WMNHW08 in WO, not Receipt, WMNHW09 in WO, not Receipt, WMNHW10 in WO, not Receipt, WMNHW11 in WO, not Receipt, WMNHW16 in WO, not Receipt, WMUW01 in WO, not Receipt, WMUW03 in WO, not Receipt, WMUW04 in WO, not Receipt, WMUW05 in WO, not Receipt

-- 779120 Xmatching units.
	
	2010-12-02, JPB - Stole from sp_reports_flash_workorder_receipts
	2010-12-22, JPB - Added a validation for Receipt with missing/0 net_weight (it's now used for WM Disposal extracts)
		Had sent a copy of this to Brie and not gotten feedback.  Going ahead with it.
	2011-01-14, JPB - Tweaked the approval-matching and same-invoice conditions to ensure it only compares
		when the receipt actually exists, or when both workorder and receipt are in submitted.
	2011-02-28, JPB - Updated to use new WorkOrder schema files (trip_act_depart etc moved)
		Also per Brie, don't include things already invoiced.
		Also updated to use line_weight not net_weight
		Also updated the "Receipt and Workorder not billed on same invoice" logic to only report when one or the other
			IS invoiced... not if they're both NOT invoiced.
	2011-03-08 JPB - Got Divide by 0 error for 1/1/2011 - 3/4/2011, updated subselect to only / where isnull(r.quantity, 0) > 0
	2011-05-31 JPB - Added 2 new checks for dates that are out of order.
	2011-06-03 JPB - GEM:17825 new validation checks:
		Please add a validation that flags weight that exceeds 1,000 pounds for approval WMHW03S2
		Please add a validation that will flag if the manifest number does not have 9 digits and 3 letters. Exclude from the validation the manifest numbers on receipts with approval WMNHW10 
	2011-07-06 JPB - GEM:????
	  Combine existing validation from sp_reports_wm_billing_validation with validation from sp_rpt_extract_walmart_disposal
	     to create a single new validation report for all things WM. 
	  Add invoiced_flag to output.
	  Fix SSRS columns to avoid merged columns, etc.
	  Remove validation logic (comment) from sp_rpt_extract_walmart_disposal
	 2014-08-22 JPB	- GEM:-29706 - Modify Validations: ___ Not-Submitted only true if > $0
	 06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max) 

****************************************************************************** */


set transaction isolation level read uncommitted
set nocount on

create table #debug (
	row_id		int	not null identity(1,1),
	status		varchar(100),
	date_added	datetime default getdate(),
	elapsed_time	float default null
)

insert #debug (status) values ('Setup')

IF @user_code = ''
	set @user_code = NULL
	
-- Fix/Set EndDate's time.
	if isnull(@EndDate,'') <> ''
		if datepart(hh, @EndDate) = 0 set @EndDate = @EndDate + 0.99999
	
declare @tbl_profit_center_filter table (
	[company_id] int, 
	profit_ctr_id int
)
	
INSERT @tbl_profit_center_filter 
	SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
		FROM 
			SecuredProfitCenter secured_copc
		INNER JOIN (
			SELECT 
				RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
				RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
			from dbo.fn_SplitXsvText(',', 0, @copc_list) 
			where isnull(row, '') <> '') selected_copc ON secured_copc.company_id = selected_copc.company_id AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
			and secured_copc.permission_id = @permission_id
			and secured_copc.user_code = @user_code

create table #tmp_records (
	source			varchar(100),
	company_id		int,
	profit_ctr_id	int,
	receipt_id		int,
	submitted_flag	char(1),
	invoiced_flag  char(1),
	source_status	char(1),
	source_alt_status	char(1),
	generator_site_type	varchar(40)
)

create index idx_tmp on #tmp_Records (receipt_id, company_id, profit_ctr_id, source)

create table #tmp_validation (
	problem			varchar(max),
	source			varchar(max),
	company_id		int,
	profit_ctr_id	int,
	receipt_id		int,
	submitted_flag	char(1),
	invoiced_flag  char(1),
	source_status	char(1),
	source_alt_status	char(1),
	generator_site_type	varchar(40)
)

CREATE TABLE #ApprovalNoWorkorder (
	-- These approval_codes should never have a workorder related to them
	-- So use this table during validation so we do not complain about
	-- receipts missing workorders for these.
	approval_code	varchar(20)
)
insert #ApprovalNoWorkorder values ('WMNHW10')


TRUNCATE TABLE #tmp_records
TRUNCATE TABLE #tmp_validation

insert #debug (status) values ('Collect Keys (W)')

-- Collect the keys for records that need to be checked based on user input
INSERT #tmp_records
SELECT  
	'Workorder' as Source, 
	w.company_id, 
	w.profit_ctr_id, 
	w.workorder_id as receipt_id,
	w.submitted_flag,
	case when exists (select 1 from billing where receipt_id = w.workorder_id and company_id = w.company_id and profit_ctr_id = w.profit_ctr_id and trans_source = 'W' and status_code = 'I') then 'T' else 'F' END AS invoiced_flag,
	w.workorder_status,
	null as source_alt_status,
	g.site_type
FROM     
	workorderheader w (nolock) 
	INNER JOIN @tbl_profit_center_filter secured_copc ON (secured_copc.company_id = w.company_id and secured_copc.profit_ctr_id = w.profit_ctr_id)
	left join Generator g (nolock) on w.generator_id = g.generator_id
	LEFT JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
		and wos.company_id = w.company_id
		and wos.profit_ctr_id = w.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE    
	(w.customer_id = 10673 or w.generator_id in (select generator_id from customergenerator where customer_id = 10673))
	AND w.workorder_status NOT IN ('V','X','T') 
	-- 2/28/2011 - JPB: WAS... AND COALESCE(w.trip_act_departure, w.trip_est_departure, w.end_date) BETWEEN @StartDate AND @EndDate
	AND COALESCE(wos.date_act_depart, wos.date_est_depart, w.end_date) BETWEEN @StartDate AND @EndDate
	-- AND w.trip_id is not null

insert #debug (status) values ('Collect Keys (R)')

INSERT #tmp_records
SELECT   
	'Receipt' as Source,
	r.company_id, 
	r.profit_ctr_id, 
	r.receipt_id,
	r.submitted_flag,
	case when exists (select 1 from billing where receipt_id = w.workorder_id and company_id = w.company_id and profit_ctr_id = w.profit_ctr_id and trans_source = 'R' and status_code = 'I') then 'T' else 'F' end,
	r.receipt_status,
	r.fingerpr_status as source_alt_status,
	g.site_type
FROM     
	@tbl_profit_center_filter secured_copc 
	INNER JOIN workorderheader w (nolock) ON (secured_copc.company_id = w.company_id and secured_copc.profit_ctr_id = w.profit_ctr_id)
	inner join billinglinklookup bll (nolock) on w.workorder_id = bll.source_id and w.company_id = bll.source_company_id and w.profit_ctr_id = bll.source_profit_ctr_id
	inner join receipt r (nolock) on r.receipt_id = bll.receipt_id and r.company_id = bll.company_id and r.profit_ctr_id = bll.profit_ctr_id
	LEFT JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
		and wos.company_id = w.company_id
		and wos.profit_ctr_id = w.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
	left join generator g (nolock) on w.generator_id = g.generator_id
WHERE    
	(w.customer_id = 10673 or w.generator_id in (select generator_id from customergenerator where customer_id = 10673))
	AND r.receipt_status NOT IN ('V') 
	-- 2/28/2011 - JPB: WAS... AND COALESCE(w.trip_act_departure, w.trip_est_departure, w.end_date) BETWEEN @StartDate AND @EndDate
	AND COALESCE(wos.date_act_depart, wos.date_est_depart, w.end_date) BETWEEN @StartDate AND @EndDate
	-- AND w.trip_id is not null

insert #debug (status) values ('Setup pt 2')

--SELECT * FROM #tmp_records

--TRUNCATE TABLE #tmp_validation

DECLARE @ApprovalNoWorkorder varchar(max)
SELECT @ApprovalNoWorkorder = coalesce(@ApprovalNoWorkorder + ', ', '') + approval_code FROM #ApprovalNoWorkorder

-- Validations:
/*
INSERT #tmp_validation
SELECT
	'Billing Qty on the receipt differs from data captured on the MIM: R'
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + '-'
	+ convert(varchar(20), r.line_id) + ' = '
	+ convert(varchar(20), sum(rp.bill_quantity)) + ' vs W '
	+ convert(varchar(2), wod.company_id) + '-'
	+ convert(varchar(2), wod.profit_ctr_id) + ':'
	+ convert(varchar(20), wod.workorder_id) + '-'
	+ convert(varchar(20), wod.sequence_id) + ' = '
	+ convert(varchar(20), wod.quantity_used) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status
FROM
	#tmp_records t
	inner join billinglinklookup bll on t.receipt_id = bll.receipt_id and t.company_id = bll.company_id and t.profit_ctr_id = bll.profit_ctr_id
	inner join workorderdetail wod on bll.source_id = wod.workorder_id and bll.source_company_id = wod.company_id and bll.source_profit_ctr_id = wod.profit_ctr_id AND wod.bill_rate NOT IN (-2, 0)
	INNER JOIN receipt r ON t.receipt_id = r.receipt_id and t.company_id = r.company_id and t.profit_ctr_id = r.profit_ctr_id
	inner join receiptprice rp on r.receipt_id = rp.receipt_id and r.company_id = rp.company_id and r.profit_ctr_id = rp.profit_ctr_id AND r.line_id = rp.line_id
WHERE
	t.source = 'Receipt'
	AND r.manifest = wod.manifest
	AND r.manifest_page_num = wod.manifest_page_num
	AND r.manifest_line = wod.manifest_line
GROUP BY
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	r.line_id,
	r.approval_code,
	-- rp.bill_unit_code,
	wod.workorder_id,
	wod.company_id,
	wod.profit_ctr_id,
	wod.sequence_id,
	wod.price_source,
	wod.quantity_used,
	wod.bill_unit_code
HAVING
	sum(rp.bill_quantity) <> wod.quantity_used
*/

/*
INSERT #tmp_validation
SELECT
	'Unit on the receipt differs from data captured on the MIM: R'
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + '-'
	+ convert(varchar(20), r.line_id) + ' = '
	+ rp.bill_unit_code + ' vs W '
	+ convert(varchar(2), wod.company_id) + '-'
	+ convert(varchar(2), wod.profit_ctr_id) + ':'
	+ convert(varchar(20), wod.workorder_id) + '-'
	+ convert(varchar(20), wod.sequence_id) + ' = '
	+ convert(varchar(20), wod.bill_unit_code) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status
FROM
	#tmp_records t
	inner join billinglinklookup bll on t.receipt_id = bll.receipt_id and t.company_id = bll.company_id and t.profit_ctr_id = bll.profit_ctr_id
	inner join workorderdetail wod on bll.source_id = wod.workorder_id and bll.source_company_id = wod.company_id and bll.source_profit_ctr_id = wod.profit_ctr_id AND wod.bill_rate NOT IN (-2, 0)
	INNER JOIN receipt r ON t.receipt_id = r.receipt_id and t.company_id = r.company_id and t.profit_ctr_id = r.profit_ctr_id
	inner join receiptprice rp on r.receipt_id = rp.receipt_id and r.company_id = rp.company_id and r.profit_ctr_id = rp.profit_ctr_id AND r.line_id = rp.line_id
WHERE
	t.source = 'Receipt'
	AND r.manifest = wod.manifest
	AND r.manifest_page_num = wod.manifest_page_num
	AND r.manifest_line = wod.manifest_line
	AND r.manifest_unit = wod.manifest_unit --
	AND rp.bill_unit_code <> wod.bill_unit_code
	AND NOT (rp.bill_unit_code LIKE 'CY%' AND wod.bill_unit_code LIKE 'CY%')
*/

insert #debug (status) values ('Approvals on receipt dif. from WO')

INSERT #tmp_validation
SELECT DISTINCT
	'Approvals on the receipt differ from WO: '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + ' : '
	+ dbo.fn_compare_approvals_wtor_excluding(t.receipt_id, t.company_id, t.profit_ctr_id, @ApprovalNoWorkorder) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.invoiced_flag,
	t.source_status,
	t.source_alt_status,
	t.generator_site_type
FROM
	#tmp_records t
	inner join billinglinklookup bll on t.receipt_id = bll.source_id and t.company_id = bll.source_company_id and t.profit_ctr_id = bll.source_profit_ctr_id and t.source = 'Workorder' AND bll.link_required_flag <> 'E'
	inner join receipt r on bll.receipt_id = r.receipt_id and bll.company_id = r.company_id and bll.profit_ctr_id = r.profit_ctr_id
	inner join workorderheader w on bll.source_id = w.workorder_id and bll.source_company_id = r.company_id and bll.source_profit_ctr_id = w.profit_ctr_id
WHERE
	t.source = 'Workorder'
	AND dbo.fn_compare_approvals_wtor_excluding(t.receipt_id, t.company_id, t.profit_ctr_id, @ApprovalNoWorkorder) <> ''

insert #debug (status) values ('Demurrage > 1h (W)')

INSERT #tmp_validation
SELECT
	'Demurrage exceeds 1 hour: W '
	+ convert(varchar(2), wod.company_id) + '-'
	+ convert(varchar(2), wod.profit_ctr_id) + ':'
	+ convert(varchar(20), wod.workorder_id) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.invoiced_flag,
	t.source_status,
	t.source_alt_status,
	t.generator_site_type
FROM #tmp_records t
	INNER JOIN workorderdetail wod 
		ON t.receipt_id = wod.workorder_id 
		AND t.company_id = wod.company_id 
		AND t.profit_ctr_id = wod.profit_ctr_id 
		AND t.source = 'Workorder'
	INNER JOIN ResourceClass rc
		ON wod.company_id = rc.company_id
		AND wod.profit_ctr_id = rc.profit_ctr_id
		AND wod.resource_class_code = rc.resource_class_code
WHERE 
	rc.description like '%demurrage%'
	AND wod.bill_unit_code = 'HOUR'
	AND wod.quantity_used > 1

insert #debug (status) values ('Receipt > $1k')

INSERT #tmp_validation
SELECT
	'Receipt pricing exceeds $1000: R '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + ' = '
	+ convert(varchar(20), 
		CASE WHEN EXISTS (
			SELECT 1 
			FROM BILLING
			WHERE receipt_id = t.receipt_id
			AND company_id = t.company_id
			AND profit_ctr_id = t.profit_ctr_id
			AND trans_source = 'R'
		) THEN 
			(
				SELECT SUM(total_extended_amt + insr_extended_amt + ensr_extended_amt)
				FROM billing b WHERE b.receipt_id = t.receipt_id
				AND b.company_id = t.company_id
				AND b.profit_ctr_id = t.profit_ctr_id
				AND b.trans_source = 'R'
			)
		ELSE
			(
				SELECT SUM(total_extended_amt)
				FROM receiptprice b WHERE b.receipt_id = t.receipt_id
				AND b.company_id = t.company_id
				AND b.profit_ctr_id = t.profit_ctr_id
			)
		END
	) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.invoiced_flag,
	t.source_status,
	t.source_alt_status,
	t.generator_site_type
FROM #tmp_records t
WHERE
	t.source = 'Receipt'
	AND 1000 < (
		CASE WHEN EXISTS (
			SELECT 1 
			FROM BILLING
			WHERE receipt_id = t.receipt_id
			AND company_id = t.company_id
			AND profit_ctr_id = t.profit_ctr_id
			AND trans_source = 'R'
		) THEN 
			(
				SELECT SUM(total_extended_amt + insr_extended_amt + ensr_extended_amt)
				FROM billing b WHERE b.receipt_id = t.receipt_id
				AND b.company_id = t.company_id
				AND b.profit_ctr_id = t.profit_ctr_id
				AND b.trans_source = 'R'
			)
		ELSE
			(
				SELECT SUM(total_extended_amt)
				FROM receiptprice b WHERE b.receipt_id = t.receipt_id
				AND b.company_id = t.company_id
				AND b.profit_ctr_id = t.profit_ctr_id
			)
		END
	)

insert #debug (status) values ('Receipt missing line weight')

INSERT #tmp_validation
SELECT
	'Receipt With Missing or Zero Line Weight: R '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + '-'
	+ convert(varchar(20), r.line_id) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.invoiced_flag,
	t.source_status,
	t.source_alt_status,
	t.generator_site_type
FROM #tmp_records t
	INNER JOIN receipt r
		ON r.receipt_id = t.receipt_id
		AND r.company_id = t.company_id
		AND r.profit_ctr_id = t.profit_ctr_id
WHERE
	t.source = 'Receipt'
	AND isnull(r.line_weight, 0) = 0
	and r.trans_type = 'D'

insert #debug (status) values ('Mixed non-cyl types on receipt line')

INSERT #tmp_validation
SELECT
	'Mixed (non-Cyl) Container Types in single Receipt line: R '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + '-'
	+ convert(varchar(20), r.line_id) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.invoiced_flag,
	t.source_status,
	t.source_alt_status,
	t.generator_site_type
FROM #tmp_records t
	INNER JOIN receipt r
		ON r.receipt_id = t.receipt_id
		AND r.company_id = t.company_id
		AND r.profit_ctr_id = t.profit_ctr_id
	INNER JOIN ReceiptPrice rp
		ON rp.receipt_id = r.receipt_id
		AND rp.line_id = r.line_id
		AND rp.company_id = r.company_id
		AND rp.profit_ctr_id = r.profit_ctr_id
WHERE
	t.source = 'Receipt'
	AND (
		( -- option 1: CY* mixed with another non CY* type.
			EXISTS (select 1 from receiptprice rp2
				where rp2.receipt_id = rp.receipt_id
				AND rp2.line_id = rp.line_id
				AND rp2.company_id = rp.company_id
				AND rp2.profit_ctr_id = rp.profit_ctr_id
				and bill_unit_code like 'CY%'
			)
			AND EXISTS (select 1 from receiptprice rp3
				where rp3.receipt_id = rp.receipt_id
				AND rp3.line_id = rp.line_id
				AND rp3.company_id = rp.company_id
				AND rp3.profit_ctr_id = rp.profit_ctr_id
				and bill_unit_code NOT like 'CY%'
			)
		)
		OR
		( -- option 2: 2 non CY* types mixed
			(
			SELECT count(distinct bill_unit_code)
			FROM receiptprice rp4
			WHERE rp4.receipt_id = rp.receipt_id
				AND rp4.line_id = rp.line_id
				AND rp4.company_id = rp.company_id
				AND rp4.profit_ctr_id = rp.profit_ctr_id
				AND rp4.bill_unit_code NOT LIKE 'CY%'
			) > 1
		)
	)

insert #debug (status) values ('Unpriced Receipt')

INSERT #tmp_validation
SELECT
	'Unpriced Receipt: R '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + '-'
	+ convert(varchar(20), r.line_id) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.invoiced_flag,
	t.source_status,
	t.source_alt_status,
	t.generator_site_type
FROM #tmp_records t
	INNER JOIN receipt r
		ON r.receipt_id = t.receipt_id
		AND r.company_id = t.company_id
		AND r.profit_ctr_id = t.profit_ctr_id
	LEFT OUTER JOIN ReceiptPrice rp
		ON rp.receipt_id = r.receipt_id
		AND rp.line_id = r.line_id
		AND rp.company_id = r.company_id
		AND rp.profit_ctr_id = r.profit_ctr_id
WHERE
	t.source = 'Receipt'
GROUP BY 
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	r.line_id,
	t.submitted_flag,
	t.invoiced_flag,
	t.source_status,
	t.source_alt_status,
	t.generator_site_type
having sum (rp.price) = 0

insert #debug (status) values ('Receipt + Workorder not on same invoice')

INSERT #tmp_validation
SELECT
	'Receipt and Workorder not billed on same invoice: R'
	+ isnull(convert(varchar(2), bll.company_id), 0) + '-'
	+ isnull(convert(varchar(2), bll.profit_ctr_id), 0) + ':'
	+ isnull(convert(varchar(20), bll.receipt_id), 0) + ' vs W '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.invoiced_flag,
	t.source_status,
	t.source_alt_status,
	t.generator_site_type
FROM
	#tmp_records t
	inner join billinglinklookup bll on t.receipt_id = bll.source_id and t.company_id = bll.source_company_id and t.profit_ctr_id = bll.source_profit_ctr_id and t.source = 'Workorder' AND bll.link_required_flag <> 'E'
	inner join receipt r on bll.receipt_id = r.receipt_id and bll.company_id = r.company_id and bll.profit_ctr_id = r.profit_ctr_id
	inner join workorderheader w on bll.source_id = w.workorder_id and bll.source_company_id = r.company_id and bll.source_profit_ctr_id = w.profit_ctr_id
	LEFT OUTER JOIN billing WB ON t.receipt_id = WB.receipt_id and t.company_id = WB.company_id AND t.profit_ctr_id = WB.profit_ctr_id and t.source = 'Workorder' and WB.status_code = 'I'
	LEFT OUTER JOIN billing RB ON bll.receipt_id = RB.receipt_id and bll.company_id = RB.company_id AND bll.profit_ctr_id = RB.profit_ctr_id and RB.status_code = 'I'
WHERE
	(
		(WB.invoice_id is not null OR RB.invoice_id is not null)
		AND
		(NOT (WB.invoice_id is null AND RB.invoice_id is null))
	)
	AND (
		isnull(WB.invoice_id, 0) <> isnull(RB.invoice_id, 1)
--		OR (wb.status_code <> rb.status_code)
	)

insert #debug (status) values ('Receipt + Workorder not on same invoice')

/*
INSERT #tmp_validation
SELECT
	'Linked Receipt or Workorder submitted without the other: R'
	+ isnull(convert(varchar(2), bll.company_id), 0) + '-'
	+ isnull(convert(varchar(2), bll.profit_ctr_id), 0) + ':'
	+ isnull(convert(varchar(20), bll.receipt_id), 0) + ' vs W '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.invoiced_flag,
	t.source_status,
	t.source_alt_status
FROM
	#tmp_records t
	inner join billinglinklookup bll on t.receipt_id = bll.source_id and t.company_id = bll.source_company_id and t.profit_ctr_id = bll.source_profit_ctr_id and t.source = 'Workorder' AND bll.link_required_flag <> 'E'
	inner join receipt r on bll.receipt_id = r.receipt_id and bll.company_id = r.company_id and bll.profit_ctr_id = r.profit_ctr_id
	inner join workorderheader w on bll.source_id = w.workorder_id and bll.source_company_id = r.company_id and bll.source_profit_ctr_id = w.profit_ctr_id
WHERE
	(r.submitted_flag <> w.submitted_flag)
*/

insert #debug (status) values ('Arrive date after Depart date')

INSERT #tmp_validation
SELECT distinct
	'Arrive Date after Depart Date: '
	+ convert(varchar(2), wod.company_id) + '-'
	+ convert(varchar(2), wod.profit_ctr_id) + ':'
	+ convert(varchar(20), wod.workorder_id) + ' : arr = '
	+ convert(varchar(20), wos.date_act_arrive) + ' vs dep = '
	+ convert(varchar(20), wos.date_act_depart) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.invoiced_flag,
	t.source_status,
	t.source_alt_status,
	t.generator_site_type
FROM #tmp_records t
	INNER JOIN workorderdetail wod 
		ON t.receipt_id = wod.workorder_id 
		AND t.company_id = wod.company_id 
		AND t.profit_ctr_id = wod.profit_ctr_id 
		AND t.source = 'Workorder'
	LEFT JOIN WorkOrderStop wos ON wos.workorder_id = wod.workorder_id
		and wos.company_id = wod.company_id
		and wos.profit_ctr_id = wod.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 
	wos.date_act_arrive > wos.date_act_depart


insert #debug (status) values ('Arrive date before Start date')

INSERT #tmp_validation
SELECT distinct
	'Arrive Date before Workorder Start Date: '
	+ convert(varchar(2), wod.company_id) + '-'
	+ convert(varchar(2), wod.profit_ctr_id) + ':'
	+ convert(varchar(20), wod.workorder_id) + ' : arr = '
	+ convert(varchar(20), wos.date_act_arrive) + ' vs start = '
	+ convert(varchar(20), woh.start_date) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.invoiced_flag,
	t.source_status,
	t.source_alt_status,
	t.generator_site_type
FROM #tmp_records t
	INNER JOIN workorderdetail wod 
		ON t.receipt_id = wod.workorder_id 
		AND t.company_id = wod.company_id 
		AND t.profit_ctr_id = wod.profit_ctr_id 
		AND t.source = 'Workorder'
	INNER JOIN workorderheader woh
		ON wod.workorder_id = woh.workorder_id
		and wod.company_id = woh.company_id
		and wod.profit_ctr_id = woh.profit_ctr_id
	LEFT JOIN WorkOrderStop wos ON wos.workorder_id = wod.workorder_id
		and wos.company_id = wod.company_id
		and wos.profit_ctr_id = wod.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 
	wos.date_act_arrive < woh.start_date

/*
-- Please add a validation that flags weight that exceeds 1,000 pounds for approval WMHW03S2
INSERT #tmp_validation
SELECT
	'Approval WMHW03S2 with weight > 1000 lbs: R '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + '-'
	+ convert(varchar(20), r.line_id) + ' = '
	+ convert(varchar(20), 
		round( 
			ISNULL(
				CASE WHEN isnull(r.quantity, 0) > 0 THEN (
					SELECT 
						ISNULL((SELECT (isnull(rp.bill_quantity, 0) / isnull(r.quantity, 0)) * ISNULL( SUM(container_weight), 0) 
							FROM container con (nolock)
							WHERE con.company_id = R.company_id
								AND con.profit_ctr_id = R.profit_ctr_id
								AND con.receipt_id = R.receipt_id
								AND con.line_id = R.line_id
								AND con.container_type = 'R'
								AND con.status <> 'V'
								)
						, r.line_weight)
				) ELSE NULL END
			, 0)
		, 0)
	)
	+ ' lbs' as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.invoiced_flag,
	t.source_status,
	t.source_alt_status
FROM #tmp_records t
	inner join Receipt r
		ON t.receipt_id = r.receipt_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
		and t.source = 'Receipt'
	INNER JOIN ReceiptPrice rp
		ON rp.receipt_id = r.receipt_id
		AND rp.line_id = r.line_id
		AND rp.company_id = r.company_id
		AND rp.profit_ctr_id = r.profit_ctr_id
WHERE
	r.approval_code = 'WMHW03S2'
	AND 1000 <
		round( 
			ISNULL(
				CASE WHEN isnull(r.quantity, 0) > 0 THEN (
					SELECT
						ISNULL((SELECT (isnull(rp.bill_quantity, 0) / isnull(r.quantity, 0)) * ISNULL( SUM(container_weight), 0) 
							FROM container con (nolock)
							WHERE con.company_id = R.company_id
								AND con.profit_ctr_id = R.profit_ctr_id
								AND con.receipt_id = R.receipt_id
								AND con.line_id = R.line_id
								AND con.container_type = 'R'
								AND con.status <> 'V'
								)
						, r.line_weight)
					) ELSE NULL END
			, 0)
		, 0)
*/


-- Please add a validation that will flag if the manifest number does not have 
-- 9 digits and 3 letters. Exclude from the validation the manifest numbers on receipts with approval WMNHW10 

insert #debug (status) values ('Invalid Manifest Num')

INSERT #tmp_validation
SELECT
	'Invalid Manifest Number: ' + r.manifest as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.invoiced_flag,
	t.source_status,
	t.source_alt_status,
	t.generator_site_type
FROM #tmp_records t
	inner join Receipt r
		ON t.receipt_id = r.receipt_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
		and t.source = 'Receipt'
WHERE
	(
		len(r.manifest) <> 12
		or
		isnumeric(left(r.manifest, 9)) = 0
		or
		isnumeric(right(r.manifest, 3)) = 1
	)
	AND r.approval_code not in (select approval_code from #ApprovalNoWorkorder)

insert #debug (status) values ('Overweight Unit')

-- revised... 
-- Flag where non-container bill_unit has weight > gal_conv * 10, or if no gal_conv then 1000.
INSERT #tmp_validation
SELECT
	'Overweight ' + rp.bill_unit_code + ': ' + 
	+ convert(varchar(20), 
		round( 
			ISNULL(
				CASE WHEN isnull(r.quantity, 0) > 0 THEN (
					SELECT 
						ISNULL((SELECT (isnull(rp.bill_quantity, 0) / isnull(r.quantity, 0)) * ISNULL( SUM(container_weight), 0) 
							FROM container con (nolock)
							WHERE con.company_id = R.company_id
								AND con.profit_ctr_id = R.profit_ctr_id
								AND con.receipt_id = R.receipt_id
								AND con.line_id = R.line_id
								AND con.container_type = 'R'
								AND con.status <> 'V'
								)
						, r.line_weight)
				) ELSE NULL END
			, 0)
		, 0)
	) + ' lbs > ' +
		'(' + 
		CASE WHEN bu.gal_conv IS NULL OR isnull(bu.container_flag, 'F') = 'F' THEN 
			'Default max wt=1000' 
		ELSE
			convert(varchar(20), convert(int,rp.bill_quantity)) + 'x' + bu.bill_unit_code +  '=' + convert(varchar(10), CASE WHEN bu.gal_conv IS NULL OR isnull(bu.container_flag, 'F') = 'F' THEN 1000 ELSE (rp.bill_quantity * (bu.gal_conv * 10)) END) 
		END +
		') lbs: R '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + '-'
	+ convert(varchar(20), r.line_id) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.submitted_flag,
	t.invoiced_flag,
	t.source_status,
	t.source_alt_status,
	t.generator_site_type
FROM #tmp_records t
	inner join Receipt r
		ON t.receipt_id = r.receipt_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
		and t.source = 'Receipt'
	INNER JOIN ReceiptPrice rp
		ON rp.receipt_id = r.receipt_id
		AND rp.line_id = r.line_id
		AND rp.company_id = r.company_id
		AND rp.profit_ctr_id = r.profit_ctr_id
	INNER JOIN BillUnit bu ON rp.bill_unit_code = bu.bill_unit_code
WHERE
	1=1
	-- rp.bill_unit_code IN ('DM05', 'DM30', 'DM55')
	AND CASE WHEN bu.gal_conv IS NULL OR isnull(bu.container_flag, 'F') = 'F' THEN 1000 ELSE (rp.bill_quantity * (bu.gal_conv * 10)) END <
		round( 
			ISNULL(
				CASE WHEN isnull(r.quantity, 0) > 0 THEN (
					SELECT
						ISNULL((SELECT (isnull(rp.bill_quantity, 0) / isnull(r.quantity, 0)) * ISNULL( SUM(container_weight), 0) 
							FROM container con (nolock)
							WHERE con.company_id = R.company_id
								AND con.profit_ctr_id = R.profit_ctr_id
								AND con.receipt_id = R.receipt_id
								AND con.line_id = R.line_id
								AND con.container_type = 'R'
								AND con.status <> 'V'
								)
						, r.line_weight)
					) ELSE NULL END
			, 0)
		, 0)


-- SELECT * FROM #tmp_validation

/* *************************************************************

Validate Phase from Disposal Extract...

    Run the Validation every time, but may not be exported below...

    Look for blank transporter info
    Look for missing waste codes
    Look for 0 weight lines
    Look for blank service_date
    Look for blank Facility Number
    Look for blank Facility Type
    Look for un-submitted records that would've been included if they were submitted
    Look for count of D_ images
    Look for duplicate manifest/line combinations
    Look for missing dot descriptions
    Look for missing waste descriptions

************************************************************** */


insert #debug (status) values ('Missing Transporter')

-- Create list of missing transporter info

	INSERT #tmp_validation
	SELECT
		'Missing Transporter Info' as Problem,
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
	INNER JOIN WorkOrderHeader w  (nolock) ON t.receipt_id = w.workorder_id and t.company_id = w.company_id and t.profit_ctr_id = w.profit_ctr_id
	INNER JOIN WorkOrderDetail d  (nolock) ON t.receipt_id = d.workorder_id and t.company_id = d.company_id and t.profit_ctr_id = d.profit_ctr_id
	INNER JOIN TSDF tsdf ON d.tsdf_code = tsdf.TSDF_code AND ISNULL(tsdf.eq_flag, 'F') = 'F'
      LEFT OUTER JOIN WorkOrderTransporter wot1 (nolock) ON t.receipt_id = wot1.workorder_id and t.company_id = wot1.company_id and t.profit_ctr_id = wot1.profit_ctr_id and d.manifest = wot1.manifest and wot1.transporter_sequence_id = 1 
      LEFT OUTER JOIN WorkOrderStop wos (nolock) ON t.receipt_id = wos.workorder_id and t.company_id = wos.company_id and t.profit_ctr_id = wos.profit_ctr_id and wos.stop_sequence_id = 1
    WHERE 
      t.source = 'Workorder'
      AND d.manifest IS NOT null
    	AND ISNULL((select transporter_name from transporter (nolock) where transporter_code = wot1.transporter_code), '') = ''
	   AND NOT ( 1=1
      	AND d.bill_rate NOT IN (-2)
      	AND d.resource_class_code = 'STOPFEE'
      	AND wos.decline_id > 1
      	AND (
      	    (isnull(w.billing_project_id, 0) = 24 and w.customer_id = 10673)
      	    OR
      	    (wos.waste_flag = 'F')
      	)    
      )
   UNION ALL
   SELECT
   	'Missing Transporter Info' as Problem,
   	t.source,
   	t.company_id,
   	t.profit_ctr_id,
   	t.receipt_id,
   	t.submitted_flag,
   	t.invoiced_flag,
   	t.source_status,
   	t.source_alt_status,
	t.generator_site_type
   FROM #tmp_records t
    INNER JOIN Receipt r (nolock) on r.receipt_id = t.receipt_id
        and r.profit_ctr_id = t.profit_ctr_id
        and r.company_id = t.company_id
    left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = t.receipt_id
        and rt1.profit_ctr_id = t.profit_ctr_id
        and rt1.company_id = t.company_id
        and rt1.transporter_sequence_id = 1
    WHERE 
      t.source = 'Receipt'
    	AND ISNULL((select transporter_name from transporter (nolock) where transporter_code = 
        CASE WHEN rt1.transporter_code IS NULL THEN
            r.hauler
        ELSE
            rt1.transporter_code 
        END
    	), '') = ''

insert #debug (status) values ('Missing Weight')

-- Create list of missing Weights

	INSERT #tmp_validation
	SELECT
		'Missing Weight: line ' + convert(varchar(10), d.sequence_id) as Problem,
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
	INNER JOIN WorkOrderHeader w  (nolock) ON t.receipt_id = w.workorder_id and t.company_id = w.company_id and t.profit_ctr_id = w.profit_ctr_id
	INNER JOIN WorkOrderDetail d  (nolock) ON t.receipt_id = d.workorder_id and t.company_id = d.company_id and t.profit_ctr_id = d.profit_ctr_id
      LEFT OUTER JOIN WorkOrderStop wos (nolock) ON t.receipt_id = wos.workorder_id and t.company_id = wos.company_id and t.profit_ctr_id = wos.profit_ctr_id and wos.stop_sequence_id = 1
    WHERE 
		t.source = 'Workorder'
		AND d.manifest IS NOT NULL
		AND d.resource_type in ('A', 'D')
		AND d.bill_rate > -2
		AND NOT ( 1=1
			AND d.bill_rate NOT IN (-2)
			AND d.resource_class_code = 'STOPFEE'
			AND wos.decline_id > 1
			AND (
				(isnull(w.billing_project_id, 0) = 24 and w.customer_id = 10673)
				OR
				(wos.waste_flag = 'F')
			)    
		)
		AND ISNULL(
			(
				SELECT 
					quantity
					FROM WorkOrderDetailUnit a
					WHERE a.workorder_id = d.workorder_id
					AND a.company_id = d.company_id
					AND a.profit_ctr_id = d.profit_ctr_id
					AND a.sequence_id = d.sequence_id
					AND a.bill_unit_code = 'LBS'
			) 
		, 0) = 0
	UNION ALL
   SELECT
		'Missing Weight: line ' + convert(varchar(10), r.line_id) as Problem,
	   	t.source,
	   	t.company_id,
	   	t.profit_ctr_id,
	   	t.receipt_id,
	   	t.submitted_flag,
	   	t.invoiced_flag,
	   	t.source_status,
	   	t.source_alt_status,
		t.generator_site_type
   FROM #tmp_records t
    INNER JOIN Receipt r (nolock) on r.receipt_id = t.receipt_id
        and r.profit_ctr_id = t.profit_ctr_id
        and r.company_id = t.company_id
	WHERE
		r.line_weight = 0
		and r.trans_type = 'D'
			    

insert #debug (status) values ('Missing Service Date')

-- Create list of missing Service Dates

    INSERT #tmp_validation
    SELECT
    	'Missing Service Date',
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
	INNER JOIN WorkOrderHeader w  (nolock) ON t.receipt_id = w.workorder_id and t.company_id = w.company_id and t.profit_ctr_id = w.profit_ctr_id
	INNER JOIN WorkOrderDetail d  (nolock) ON t.receipt_id = d.workorder_id and t.company_id = d.company_id and t.profit_ctr_id = d.profit_ctr_id
    LEFT OUTER JOIN WorkOrderStop wos (nolock) ON t.receipt_id = wos.workorder_id and t.company_id = wos.company_id and t.profit_ctr_id = wos.profit_ctr_id and wos.stop_sequence_id = 1
    WHERE 
		t.source = 'Workorder'
		AND d.manifest IS NOT NULL
		AND d.resource_type in ('A', 'D')
		AND NOT ( 1=1
			AND d.bill_rate NOT IN (-2)
			AND d.resource_class_code = 'STOPFEE'
			AND wos.decline_id > 1
			AND (
				(isnull(w.billing_project_id, 0) = 24 and w.customer_id = 10673)
				OR
				(wos.waste_flag = 'F')
			)    
		)
    AND	isnull(coalesce(wos.date_act_arrive, w.start_date), '') = ''
	UNION
   SELECT
    	'Missing Service Date',
	   	t.source,
	   	t.company_id,
	   	t.profit_ctr_id,
	   	t.receipt_id,
	   	t.submitted_flag,
	   	t.invoiced_flag,
	   	t.source_status,
	   	t.source_alt_status,
		t.generator_site_type
   FROM #tmp_records t
	INNER JOIN WorkOrderHeader w  (nolock) ON t.receipt_id = w.workorder_id and t.company_id = w.company_id and t.profit_ctr_id = w.profit_ctr_id
    inner join billinglinklookup bll  (nolock) ON w.company_id = bll.source_company_id and w.profit_ctr_id = bll.source_profit_ctr_id and w.workorder_id = bll.source_id
    inner join receipt r  (nolock) on bll.receipt_id = r.receipt_id and bll.profit_ctr_id = r.profit_ctr_id and bll.company_id = r.company_id
    left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id and rt1.profit_ctr_id = r.profit_ctr_id and rt1.company_id = r.company_id and rt1.transporter_sequence_id = 1
	WHERE coalesce(rt1.transporter_sign_date, w.start_date, '') = ''
	UNION 
   SELECT
    	'Missing Service Date',
	   	t.source,
	   	t.company_id,
	   	t.profit_ctr_id,
	   	t.receipt_id,
	   	t.submitted_flag,
	   	t.invoiced_flag,
	   	t.source_status,
	   	t.source_alt_status,
		t.generator_site_type
   FROM #tmp_records t
   INNER JOIN Receipt r (nolock) on r.receipt_id = t.receipt_id and r.profit_ctr_id = t.profit_ctr_id and r.company_id = t.company_id
   left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id and rt1.profit_ctr_id = r.profit_ctr_id and rt1.company_id = r.company_id and rt1.transporter_sequence_id = 1
	WHERE coalesce(rt1.transporter_sign_date, '') = ''
    AND r.approval_code not in (
    	select approval_code from #ApprovalNoWorkorder
    )
    AND NOT EXISTS (
		SELECT 1 FROM workorderheader wo
		INNER JOIN billinglinklookup bl on wo.workorder_id = bl.source_id and wo.company_id = bl.source_company_id and wo.profit_ctr_id = bl.source_profit_ctr_id
		WHERE bl.receipt_id = t.receipt_id
		and bl.company_id = t.company_id
		and bl.profit_ctr_id = t.profit_ctr_id
    )


insert #debug (status) values ('Receipt without Workorder')

-- Create list of receipts missing workorders

    INSERT #tmp_validation
    SELECT DISTINCT
    	'Receipt missing Workorder',
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
    INNER JOIN Receipt r (nolock) on r.receipt_id = t.receipt_id and r.profit_ctr_id = t.profit_ctr_id and r.company_id = t.company_id
    WHERE
		t.source = 'receipt'
		AND NOT EXISTS (
			SELECT 1 FROM workorderheader wo
			INNER JOIN billinglinklookup bl on wo.workorder_id = bl.source_id and wo.company_id = bl.source_company_id and wo.profit_ctr_id = bl.source_profit_ctr_id
			WHERE bl.receipt_id = t.receipt_id
			and bl.company_id = t.company_id
			and bl.profit_ctr_id = t.profit_ctr_id
		)
		AND r.approval_code not in (
    		select approval_code from #ApprovalNoWorkorder
		)
	    

insert #debug (status) values ('Missing Gen. Site Code')

-- Create list of missing site codes
	    
    INSERT #tmp_validation
    SELECT DISTINCT
    	'Missing Generator Site Code',
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
	LEFT OUTER JOIN WorkOrderHeader w (nolock) ON t.receipt_id = w.workorder_id and t.company_id = w.company_id and t.profit_ctr_id = w.profit_ctr_id AND t.source = 'Workorder'
	LEFT OUTER JOIN Generator gw on w.generator_id = gw.generator_id
   LEFT OUTER JOIN Receipt r (nolock) on r.receipt_id = t.receipt_id and r.profit_ctr_id = t.profit_ctr_id and r.company_id = t.company_id AND t.source = 'Receipt'
	LEFT OUTER JOIN Generator gr on r.generator_id = gr.generator_id
	WHERE
		coalesce(gw.site_code, gr.site_code, '') = ''
		and coalesce(gw.generator_id, gr.generator_id, -1) > -1

-- print 'Validation: Missing Site Codes, Finished'
-- print 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
-- print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
-- set @steptimer = getdate()

-- Create list of missing site type

insert #debug (status) values ('Missing Gen. Site Type')

    INSERT #tmp_validation
    SELECT DISTINCT
    	'Missing Generator Site Type',
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
	LEFT OUTER JOIN WorkOrderHeader w (nolock) ON t.receipt_id = w.workorder_id and t.company_id = w.company_id and t.profit_ctr_id = w.profit_ctr_id AND t.source = 'Workorder'
	LEFT OUTER JOIN Generator gw on w.generator_id = gw.generator_id
   LEFT OUTER JOIN Receipt r (nolock) on r.receipt_id = t.receipt_id and r.profit_ctr_id = t.profit_ctr_id and r.company_id = t.company_id AND t.source = 'Receipt'
	LEFT OUTER JOIN Generator gr on r.generator_id = gr.generator_id
	WHERE
		coalesce(gw.site_type, gr.site_type, '') = ''
		and coalesce(gw.generator_id, gr.generator_id, -1) > -1
	    
insert #debug (status) values ('Receipt not Submitted')

-- Create list of unsubmitted receipts

    INSERT #tmp_validation
    SELECT DISTINCT
    	'Receipt Not Submitted',
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
    INNER JOIN Receipt r (nolock) on r.receipt_id = t.receipt_id and r.profit_ctr_id = t.profit_ctr_id and r.company_id = t.company_id AND t.source = 'Receipt'
	WHERE r.submitted_flag = 'F'
	    and 0 < (
			select sum(
				case when isnull(rp.total_extended_amt, 0) > 0 
					then isnull(rp.total_extended_amt, 0)
					else 
						case when isnull(rp.total_extended_amt, 0) = 0 and rp.print_on_invoice_flag = 'T' 
							then 1 
							else isnull(rp.total_extended_amt, 0)
						end 
				end
			)
			from receiptprice rp (nolock)
			where rp.receipt_id = t.receipt_id
			and rp.company_id = t.company_id
			and rp.profit_ctr_id = t.profit_ctr_id
	    )
	
insert #debug (status) values ('Workorder not Submitted')

-- Create list of unsubmitted workorders

    INSERT #tmp_validation
    SELECT DISTINCT
    	'Work Order Not Submitted',
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
	INNER JOIN WorkOrderHeader w (nolock) ON t.receipt_id = w.workorder_id and t.company_id = w.company_id and t.profit_ctr_id = w.profit_ctr_id AND t.source = 'Workorder'
	WHERE w.submitted_flag = 'F'
	    and 0 < (
			select sum(isnull(wh.total_price, 0))
			from workorderheader wh (nolock)
			where wh.workorder_id = t.receipt_id
			and wh.company_id = t.company_id
			and wh.profit_ctr_id = t.profit_ctr_id
	    )

insert #debug (status) values ('Missing Scan')

-- Create list of records missing scans

    INSERT #tmp_validation
    SELECT DISTINCT
    	'Missing Scan',
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
	INNER JOIN WorkOrderHeader w  (nolock) ON t.receipt_id = w.workorder_id and t.company_id = w.company_id and t.profit_ctr_id = w.profit_ctr_id
	INNER JOIN WorkOrderDetail d  (nolock) ON t.receipt_id = d.workorder_id and t.company_id = d.company_id and t.profit_ctr_id = d.profit_ctr_id
	INNER JOIN TSDF tsdf ON d.tsdf_code = tsdf.TSDF_code AND ISNULL(tsdf.eq_flag, 'F') = 'F'
	WHERE 
	NOT EXISTS (
		SELECT 1 FROM plt_image..Scan ws (nolock) 
		WHERE t.receipt_id = ws.workorder_id 
		and t.company_id = ws.company_id 
		and t.profit_ctr_id = ws.profit_ctr_id 
		and t.source = 'Workorder'
		and ws.document_source = 'Workorder'
		AND ws.status = 'A'
		AND ws.type_id IN (select type_id FROM plt_image..ScanDocumentType where document_type in ('manifest', 'secondary manifest', 'bol'))
		AND d.manifest = ws.document_name
	)
	AND d.resource_type IN ('D', 'A')
	AND w.submitted_flag = 'T'
	UNION ALL	
    SELECT DISTINCT
    	'Missing Scan',
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
	INNER JOIN receipt r ON t.receipt_id = r.receipt_id and t.company_id = r.company_id and t.profit_ctr_id = r.profit_ctr_id
	WHERE 
	NOT EXISTS (
		SELECT 1 FROM plt_image..Scan rs (nolock) 
		WHERE t.receipt_id = rs.receipt_id 
		and t.company_id = rs.company_id 
		and t.profit_ctr_id = rs.profit_ctr_id 
		and t.source = 'Receipt'
		and rs.document_source = 'Receipt'
		AND rs.status = 'A'
		AND rs.type_id IN (select type_id FROM plt_image..ScanDocumentType where document_type in ('manifest', 'secondary manifest', 'bol'))
		AND r.manifest = rs.document_name
	)
	AND r.submitted_flag = 'T'


/*
-- Create count of receipt-based records in extract
    INSERT #tmp_validation
     SELECT
    	'Count of Receipt-based records: ' + convert(varchar(20), count(*)),
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL
	FROM #tmp_records t
	WHERE source ='Receipt'

-- print 'Validation: Receipt Record Count, Finished'
-- print 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
-- print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
-- set @steptimer = getdate()

-- Create count of workorder -based records in extract
    INSERT #tmp_validation
     SELECT
    	'Count of Receipt-based records: ' + convert(varchar(20), count(*)),
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL,
		NULL
	FROM #tmp_records t
	INNER JOIN WorkOrderHeader w  (nolock) ON t.receipt_id = w.workorder_id and t.company_id = w.company_id and t.profit_ctr_id = w.profit_ctr_id
	INNER JOIN WorkOrderDetail d  (nolock) ON t.receipt_id = d.workorder_id and t.company_id = d.company_id and t.profit_ctr_id = d.profit_ctr_id
	LEFT OUTER JOIN WorkOrderStop wos (nolock) ON t.receipt_id = wos.workorder_id and t.company_id = wos.company_id and t.profit_ctr_id = wos.profit_ctr_id and wos.stop_sequence_id = 1
	WHERE source ='Workorder'
	   AND NOT ( 1=1
      	AND d.bill_rate NOT IN (-2)
      	AND d.resource_class_code = 'STOPFEE'
      	AND wos.decline_id > 1
      	AND (
      	    (isnull(w.billing_project_id, 0) = 24 and w.customer_id = 10673)
      	    OR
      	    (wos.waste_flag = 'F')
      	)    
      )

-- print 'Validation: Workorder Record Count, Finished'
-- print 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
-- print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
-- set @steptimer = getdate()

-- Create count of NWP -based records in extract
    INSERT EQ_Extract..WMDisposalValidation
     SELECT 
    	' Count of No Waste Pickup records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*)),
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		source_table ='Workorder'
    	AND waste_desc = 'No waste picked up'
	    
-- print 'Validation: No Waste Pickup Record Count, Finished'
-- print 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
-- print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
-- set @steptimer = getdate()

-- Create list of unusually high number of manifest names
    INSERT EQ_Extract..WMDisposalValidation
     SELECT
    	'High Number of same manifest-line',
    	null,
    	null,
    	null,
    	null,
    	CONVERT(varchar(20), count(*)) + ' times: ' + isnull(manifest, '') + ' line ' + isnull(CONVERT(varchar(10), Manifest_Line), ''),
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	waste_desc <> 'No waste picked up'
    	AND bill_unit_desc not like '%cylinder%'
	group by manifest, manifest_line
	having count(*) > 2

-- print 'Validation: Count high # of Manifest-Line combo, Finished'
-- print 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
-- print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
-- set @steptimer = getdate()

*/	    

insert #debug (status) values ('Missing DOT Description')

-- Create list of missing dot descriptions

    INSERT #tmp_validation
    SELECT DISTINCT
    	'Missing DOT Description',
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
	LEFT OUTER JOIN WorkOrderHeader w  (nolock) ON t.receipt_id = w.workorder_id and t.company_id = w.company_id and t.profit_ctr_id = w.profit_ctr_id
	LEFT OUTER JOIN WorkOrderDetail d  (nolock) ON t.receipt_id = d.workorder_id and t.company_id = d.company_id and t.profit_ctr_id = d.profit_ctr_id
	LEFT OUTER JOIN WorkOrderStop wos (nolock) ON t.receipt_id = wos.workorder_id and t.company_id = wos.company_id and t.profit_ctr_id = wos.profit_ctr_id and wos.stop_sequence_id = 1
	LEFT OUTER JOIN TSDF tsdf ON d.tsdf_code = tsdf.TSDF_code AND ISNULL(tsdf.eq_flag, 'F') = 'F'
	LEFT OUTER JOIN receipt r (nolock) ON t.receipt_id = r.receipt_id and t.company_id = r.company_id and t.profit_ctr_id = r.profit_ctr_id
	LEFT OUTER JOIN Generator g (nolock) ON r.generator_id = g.generator_id
	WHERE coalesce(w.submitted_flag, r.submitted_flag, 'F') = 'T'
	AND CASE WHEN t.source = 'Workorder' THEN
		tsdf.tsdf_code
	ELSE
		'1'
	END IS NOT NULL
    AND ISNULL(
        CASE WHEN d.tsdf_approval_id IS NOT NULL THEN
            dbo.fn_manifest_dot_description('T', d.tsdf_approval_id)
        ELSE
            CASE WHEN r.profile_id IS NOT NULL THEN
                dbo.fn_manifest_dot_description('P', r.profile_id)
            ELSE
                ''
            END
        END
    , '') = ''
	AND CASE WHEN t.source = 'Workorder' THEN
		CASE WHEN ISNULL(d.tsdf_approval_code, '') = '' THEN
			d.resource_class_code
		ELSE
			d.tsdf_approval_code
		END 
	ELSE
		COALESCE(replace(r.approval_code, 'WM' + right('0000' + g.site_code, 4), 'WM'), r.service_desc)
	END not in ('STOPFEE', 'GASSUR%')
	AND NOT ( t.source = 'Workorder'
  		AND d.bill_rate NOT IN (-2)
  		AND d.resource_class_code = 'STOPFEE'
  		AND wos.decline_id > 1
  		AND (
	  	    (isnull(w.billing_project_id, 0) = 24 and w.customer_id = 10673)
  			OR
  			(wos.waste_flag = 'F')
  		)    
	)

insert #debug (status) values ('Missing Bill Unit')

-- Create list of missing bill units in extract

    INSERT #tmp_validation
    SELECT DISTINCT
    	'Missing Bill Unit',
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
	LEFT OUTER JOIN WorkOrderHeader w  (nolock) ON t.receipt_id = w.workorder_id and t.company_id = w.company_id and t.profit_ctr_id = w.profit_ctr_id
	LEFT OUTER JOIN WorkOrderDetail d  (nolock) ON t.receipt_id = d.workorder_id and t.company_id = d.company_id and t.profit_ctr_id = d.profit_ctr_id AND d.resource_type = 'D' AND d.bill_rate NOT IN (-2)
	LEFT OUTER JOIN TSDF tsdf ON d.tsdf_code = tsdf.TSDF_code AND ISNULL(tsdf.eq_flag, 'F') = 'F'
	LEFT OUTER JOIN workorderdetailunit u (nolock) on d.workorder_id = u.workorder_id and d.sequence_id = u.sequence_id and d.company_id = u.company_id and d.profit_ctr_id = u.profit_ctr_id and u.billing_flag = 'T'
	LEFT JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id and wos.company_id = w.company_id and wos.profit_ctr_id = w.profit_ctr_id and wos.stop_sequence_id = 1
	LEFT OUTER JOIN BillUnit wb  (nolock) ON isnull(u.bill_unit_code, d.bill_unit_code) = wb.bill_unit_code
	LEFT OUTER JOIN receipt r (nolock) ON t.receipt_id = r.receipt_id and t.company_id = r.company_id and t.profit_ctr_id = r.profit_ctr_id
	LEFT OUTER JOIN ReceiptPrice rp  (nolock) ON R.receipt_id = rp.receipt_id and r.line_id = rp.line_id and r.company_id = rp.company_id and r.profit_ctr_id = rp.profit_ctr_id
	LEFT OUTER JOIN BillUnit rb  (nolock) ON rp.bill_unit_code = rb.bill_unit_code
	WHERE CASE WHEN t.source = 'Workorder' THEN
		isnull(wb.bill_unit_desc, '')
	ELSE
		isnull(rb.bill_unit_desc, '')
	END = ''
	AND CASE WHEN t.source = 'Workorder' THEN
		tsdf.tsdf_code
	ELSE
		'1'
	END IS NOT NULL
	AND NOT ( t.source = 'Workorder'
  		AND d.bill_rate NOT IN (-2)
  		AND d.resource_class_code = 'STOPFEE'
  		AND wos.decline_id > 1
  		AND (
	  	    (isnull(w.billing_project_id, 0) = 24 and w.customer_id = 10673)
  			OR
  			(wos.waste_flag = 'F')
  		)    
	)

insert #debug (status) values ('Missing Waste Description (R)')

-- Create list of missing waste descriptions

    INSERT #tmp_validation
    SELECT DISTINCT
    	'Missing Waste Description',
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
	INNER JOIN receipt r (nolock) ON t.receipt_id = r.receipt_id and t.company_id = r.company_id and t.profit_ctr_id = r.profit_ctr_id and t.source = 'Receipt'
	INNER JOIN Generator g (nolock) ON r.generator_id = g.generator_id
	INNER JOIN ReceiptPrice rp  (nolock) ON R.receipt_id = rp.receipt_id and r.line_id = rp.line_id and r.company_id = rp.company_id and r.profit_ctr_id = rp.profit_ctr_id
	INNER JOIN BillUnit rb  (nolock) ON rp.bill_unit_code = rb.bill_unit_code
	INNER JOIN Profile p  (nolock) ON r.profile_id = p.profile_id
	WHERE isnull(rb.bill_unit_desc, '') = ''
	AND p.Approval_desc = ''

insert #debug (status) values ('Missing Waste Description (W)')

-- Create list of missing waste descriptions

    INSERT #tmp_validation
    SELECT DISTINCT
    	'Missing Waste Description',
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
	INNER JOIN WorkOrderHeader w  (nolock) ON t.receipt_id = w.workorder_id and t.company_id = w.company_id and t.profit_ctr_id = w.profit_ctr_id and t.source = 'Workorder'
	INNER JOIN WorkOrderDetail d  (nolock) ON t.receipt_id = d.workorder_id and t.company_id = d.company_id and t.profit_ctr_id = d.profit_ctr_id AND d.resource_type = 'D' AND d.bill_rate NOT IN (-2)
	INNER JOIN TSDF tsdf ON d.tsdf_code = tsdf.TSDF_code AND ISNULL(tsdf.eq_flag, 'F') = 'F'
	INNER JOIN TSDFApproval ta  (nolock) ON d.tsdf_approval_id = ta.tsdf_approval_id AND d.company_id = ta.company_id AND d.profit_ctr_id = ta.profit_ctr_id
	INNER JOIN workorderdetailunit u (nolock) on d.workorder_id = u.workorder_id and d.sequence_id = u.sequence_id and d.company_id = u.company_id and d.profit_ctr_id = u.profit_ctr_id and u.billing_flag = 'T'
	INNER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id and wos.company_id = w.company_id and wos.profit_ctr_id = w.profit_ctr_id and wos.stop_sequence_id = 1
	INNER JOIN BillUnit wb  (nolock) ON isnull(u.bill_unit_code, d.bill_unit_code) = wb.bill_unit_code
	WHERE isnull(wb.bill_unit_desc, '') = ''
	AND tsdf.tsdf_code IS NOT NULL
	AND ta.waste_desc = ''
	AND CASE WHEN ISNULL(d.tsdf_approval_code, '') = '' THEN
		d.resource_class_code
	ELSE
		d.tsdf_approval_code
	END not in ('STOPFEE', 'GASSUR%')
	AND NOT ( t.source = 'Workorder'
  		AND d.bill_rate NOT IN (-2)
  		AND d.resource_class_code = 'STOPFEE'
  		AND wos.decline_id > 1
  		AND (
	  	    (isnull(w.billing_project_id, 0) = 24 and w.customer_id = 10673)
  			OR
  			(wos.waste_flag = 'F')
  		)    
	)

insert #debug (status) values ('Blank Waste Code 1')

-- Create list of blank waste code 1's
    INSERT #tmp_validation
    SELECT DISTINCT
    	'Blank Waste Code 1',
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
	INNER JOIN receipt r (nolock) ON t.receipt_id = r.receipt_id and t.company_id = r.company_id and t.profit_ctr_id = r.profit_ctr_id and t.source = 'Receipt'
	INNER JOIN ReceiptWasteCode RWC1 (nolock) on t.source = 'Receipt' and r.receipt_id = rwc1.receipt_id and r.line_id = rwc1.line_id and r.company_id = rwc1.company_id and r.profit_ctr_id = rwc1.profit_ctr_id and isnull(rwc1.primary_flag, 'F') = 'T'
	INNER JOIN WasteCode wc (nolock) ON wc.waste_code_uid = RWC1.waste_code_uid and wc.waste_code_origin in ('F', 'S')
	WHERE wc.display_name NOT IN ('NONE', '.', 'UNIV')
	AND coalesce(rwc1.primary_flag, 'F') = 'T'
	AND ltrim(rtrim(isnull(wc.display_name, ''))) = ''
	AND EXISTS (select 1 from ReceiptWasteCode RWC2 (nolock) where RWC2.receipt_id = rwc1.receipt_id and rwc2.line_id = rwc1.line_id and rwc2.company_id = rwc1.company_id and rwc2.profit_ctr_id = rwc1.profit_ctr_id and isnull(rwc2.primary_flag, 'F') = 'F')
	UNION
    SELECT DISTINCT
    	'Blank Waste Code 1',
		t.source,
		t.company_id,
		t.profit_ctr_id,
		t.receipt_id,
		t.submitted_flag,
		t.invoiced_flag,
		t.source_status,
		t.source_alt_status,
		t.generator_site_type
	FROM #tmp_records t
	INNER JOIN WorkOrderHeader w  (nolock) ON t.receipt_id = w.workorder_id and t.company_id = w.company_id and t.profit_ctr_id = w.profit_ctr_id and t.source = 'Workorder'
	INNER JOIN WorkOrderDetail d  (nolock) ON t.receipt_id = d.workorder_id and t.company_id = d.company_id and t.profit_ctr_id = d.profit_ctr_id AND d.resource_type = 'D' AND d.bill_rate NOT IN (-2)
	INNER JOIN TSDFApprovalWasteCode WWC1 (nolock) on t.source = 'Workorder' and d.tsdf_approval_id = WWC1.tsdf_approval_id and isnull(WWC1.primary_flag, 'F') = 'T'
	INNER JOIN WasteCode wc (nolock) ON wc.waste_code_uid = WWC1.waste_code_uid and wc.waste_code_origin in ('F', 'S')
	WHERE wc.display_name NOT IN ('NONE', '.', 'UNIV')
	AND coalesce(wwc1.primary_flag, 'F') = 'T'
	AND ltrim(rtrim(isnull(wc.display_name, ''))) = ''
	AND EXISTS (select 1 FROM TSDFApprovalWasteCode WWC2 (nolock) WHERE WWC2.tsdf_approval_id = WWC1.tsdf_approval_id and isnull(WWC2.primary_flag, 'F') = 'F')

-- print 'Validation: Blank Waste Code 1, Finished'
-- print 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
-- print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
-- set @steptimer = getdate()

insert #debug (status) values ('Output')

if @debug > 0 begin
	update #debug set elapsed_time = datediff(ms, #debug.date_added, d2.date_added)
	from #debug left outer join #debug d2 on #debug.row_id = d2.row_id -1
	select * from #debug order by row_id
end

set nocount off

-- OUTPUT:

if object_id('tempdb..##sp_reports_wm_validation') is not null drop table ##sp_reports_wm_validation

SELECT DISTINCT 
	problem,
	source,
	company_id, 
	profit_ctr_id, 
	receipt_id,
	submitted_flag,
	invoiced_flag,
	source_status,
	source_alt_status,
	generator_site_type
into ##sp_reports_wm_validation
FROM 
	#tmp_validation
ORDER BY
	company_id,
	profit_ctr_id,
	source,
	receipt_id

declare @tmp_filename varchar(100) = 'WM-Validation-' +
		convert(varchar(4), datepart(yyyy, @StartDate)) 
		+ '-'
		+ right('00' + convert(varchar(2), datepart(mm, @StartDate)),2)
		+ '-'
		+ right('00' + convert(varchar(2), datepart(dd, @StartDate)),2)
		+ '-to-'
		+ convert(varchar(4), datepart(yyyy, @EndDate)) 
		+ '-'
		+ right('00' + convert(varchar(2), datepart(mm, @EndDate)),2)
		+ '-'
		+ right('00' + convert(varchar(2), datepart(dd, @EndDate)),2)
		+ '.xls',
	@tmp_desc varchar(255) = 'WM Validation Export: ' + convert(varchar(10), @StartDate, 110) + ' - ' + convert(varchar(12), @EndDate, 110)

declare @tmp_debug int
set @tmp_debug = @debug

/*

SELECT  *
FROM    plt_export..template where template_name = 'sp_reports_wm_validation.1'

insert plt_export..template
	select
		'sp_reports_wm_validation.2',
		'Walmart Validation',
		'sp_reports_wm_validation.2.xls',
		'JONATHAN',
		GETDATE(),
		BulkColumn 
	FROM OPENROWSET(BULK N'f:\scripts\exporttemplates\sp_reports_wm_validation.2.xls', SINGLE_BLOB) as i

*/

/*	Write to Excel: */
exec plt_export.dbo.sp_export_to_excel
	@table_name	= '##sp_reports_wm_validation',
	@template	= 'sp_reports_wm_validation.2',
	@filename	= @tmp_filename,
	@added_by	= @user_code,
	@export_desc = @tmp_desc,
	@report_log_id = @report_log_id,
	@debug = @tmp_debug


--set @tmp_filename = replace(@tmp_filename, '.xls','.txt')

------ Write to Text
--exec plt_export.dbo.sp_export_to_text
--	@table_name	= '##sp_reports_wm_validation',
--	@template	= 'sp_reports_wm_validation.1.txt',
--	@filename	= @tmp_filename,
--	@header_lines_to_remove = 2,
--	@added_by	= @user_code,
--	@export_desc = @tmp_desc,
--	@report_log_id = @report_log_id
	


-- Remove temp tables.
drop table ##sp_reports_wm_validation
drop table #tmp_validation

--SELECT * FROM ##sp_reports_wm_validation

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_wm_validation] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_wm_validation] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_wm_validation] TO [EQAI]
    AS [dbo];

