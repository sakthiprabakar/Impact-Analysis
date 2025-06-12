CREATE PROCEDURE sp_reports_wm_billing_validation
	@StartDate datetime,
	@EndDate datetime,
	@copc_list varchar(500) = NULL, -- ex: 21|1,14|0,14|1
	@user_code varchar(100) = NULL, -- for associates
	@contact_id int = NULL, -- for customers
	@permission_id int,
	@debug int = 0
AS
	
/* ******************************************************************************
	exec sp_reports_wm_billing_validation 
		@StartDate='2015-08-01 00:00:00',
		@EndDate='2015-10-31 00:00:00',
		@copc_list=N'2|0, 3|0, 3|2, 3|3, 12|0, 12|1, 12|2, 12|3, 12|4, 12|5, 12|7, 14|0, 14|1, 14|2, 14|3, 14|5, 14|6, 14|9, 14|10, 14|11, 14|13, 14|14, 15|0, 15|2, 15|3, 15|4, 15|6, 15|7, 16|0, 18|0, 21|0, 21|1, 21|2, 21|3, 22|0, 22|1, 22|2, 23|0, 24|0, 25|0, 25|4, 26|0, 27|0, 28|0, 29|0, 32|0',
		@user_code=N'JONATHAN',
		@contact_id=-1,
		@permission_id = 179,
		@debug = 0


select convert(varchar(2), company_id) + '|' + convert(varchar(2), profit_ctr_id)
from profitcenter where status = 'A' order by company_id, profit_ctr_id

Approvals on the receipt differ from WO: 22-0:7307500 : WMHW01 in WO, not Receipt, WMHW02L in WO, not Receipt, WMHW02L2 in WO, not Receipt, WMHW02S1 in WO, not Receipt, WMHW02S2 in WO, not Receipt, WMHW02S3 in WO, not Receipt, WMHW02S4 in WO, not Receipt, WMHW03L1 in WO, not Receipt, WMHW03L2 in WO, not Receipt, WMHW03S1 in WO, not Receipt, WMHW03S2 in WO, not Receipt, WMHW04L in WO, not Receipt, WMHW05L in WO, not Receipt, WMHW06L in WO, not Receipt, WMHW06S in WO, not Receipt, WMHW07 in WO, not Receipt, WMHW08 in WO, not Receipt, WMHW09 in WO, not Receipt, WMHW10 in WO, not Receipt, WMHW11 in WO, not Receipt, WMNHW01 in WO, not Receipt, WMNHW02 in WO, not Receipt, WMNHW03 in WO, not Receipt, WMNHW04 in WO, not Receipt, WMNHW05 in WO, not Receipt, WMNHW06 in WO, not Receipt, WMNHW07 in WO, not Receipt, WMNHW08 in WO, not Receipt, WMNHW09 in WO, not Receipt, WMNHW10 in WO, not Receipt, WMNHW11 in WO, not Receipt, WMNHW16 in WO, not Receipt, WMUW01 in WO, not Receipt, WMUW03 in WO, not Receipt, WMUW04 in WO, not Receipt, WMUW05 in WO, not Receipt

-- 779120 Xmatching units.
	
	2010-12-02, JPB - Stole from sp_reports_flash_workorder_receipts
	2010-12-22, JPB - Added a validation for Receipt with missing/0 net_weight (it's now used for WM Disposal extracts)
		Had sent a copy of this to Brie and not gotten feedback.  Going ahead with it.
	2011-01-14, JPB - Tweaked the approval-matchi g and same-invoice conditions to ensure it only compares
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
	2012-05-08 JPB - Brie_M reports the SP times out on EQIP when run for april'12 for all companies.  Can it be faster?
		- Added debug code, made things faster.
		- Found & removed duplicate check of approvals on receipts/workorders
		- Added multiple treatments on 1 receipt check.
	2012-05-30 JPB - Added new validation checks for Receipt & Workorder record conditions that the post-invoice
		Extracts created for Wal-Mart won't know how to classify.
		

****************************************************************************** */

set nocount on

declare @timer datetime = getdate()

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

create table #tmp_flash (
	source			varchar(max),
	company_id		int,
	profit_ctr_id	int,
	receipt_id		int,
	line_id			int,	-- also used for workorderdetail.sequence_id
	workorder_resource_type char(1),
	submitted_flag	char(1),
	source_status	char(1),
	source_alt_status	char(1),
	wm_bill_type	varchar(40),
	linked_workorder_id int,
	linked_company_id int,
	linked_profit_ctr_id int,
	generator_id	int,
	generator_sublocation_id int

)

create table #tmp_validation (
	problem			varchar(max),
	source			varchar(max),
	company_id		int,
	profit_ctr_id	int,
	receipt_id		int,
	line_id			int,
	workorder_resource_type char(1),
	submitted_flag	char(1),
	source_status	char(1),
	source_alt_status	char(1),
	linked_workorder_id int,
	linked_company_id int,
	linked_profit_ctr_id int
)

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, null as row_count, 'Done with var setup' as status

-- Collect the keys for records that need to be checked based on user input
INSERT #tmp_flash (source, company_id, profit_ctr_id, receipt_id, line_id, workorder_resource_type, submitted_flag, source_status, source_alt_status, linked_workorder_id, linked_company_id, linked_profit_ctr_id, generator_id,	generator_sublocation_id)
SELECT  
	'Workorder' as Source, 
	w.company_id, 
	w.profit_ctr_id, 
	w.workorder_id as receipt_id,
	d.sequence_id,
	d.resource_type,
	w.submitted_flag,
	w.workorder_status,
	null as source_alt_status,
	w.workorder_id,
	w.company_id, 
	w.profit_ctr_id, 
	w.generator_id,
	w.generator_sublocation_id
FROM     
	workorderheader w  (nolock)
	INNER JOIN @tbl_profit_center_filter secured_copc ON (secured_copc.company_id = w.company_id and secured_copc.profit_ctr_id = w.profit_ctr_id)
	inner join workorderdetail d (nolock) on w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
	LEFT JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
		and wos.company_id = w.company_id
		and wos.profit_ctr_id = w.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE    
	w.customer_id = 10673
	-- 2/28/2011 - JPB: WAS... AND COALESCE(w.trip_act_departure, w.trip_est_departure, w.end_date) BETWEEN @StartDate AND @EndDate
	AND COALESCE(wos.date_act_depart, wos.date_est_depart, w.end_date) BETWEEN @StartDate AND @EndDate
	AND w.workorder_status NOT IN ('V','X','T') 
	AND d.bill_rate > 0
	AND w.trip_id is not null
	-- per Brie, don't include things already invoiced - 2/28/2011)
	and not exists (select 1 from billing (nolock) where trans_source = 'W' and status_code = 'I' and receipt_id = w.workorder_id and company_id = w.company_id and profit_ctr_id = w.profit_ctr_id)

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Done with 1st #tmp_flash fill from WO' as status

-- Collect the keys for records that need to be checked based on user input
INSERT #tmp_flash (source, company_id, profit_ctr_id, receipt_id, line_id, workorder_resource_type, submitted_flag, source_status, source_alt_status, linked_workorder_id, linked_company_id, linked_profit_ctr_id, generator_id,	generator_sublocation_id)
SELECT  
	'Workorder' as Source, 
	w.company_id, 
	w.profit_ctr_id, 
	w.workorder_id as receipt_id,
	d.sequence_id,
	d.resource_type,
	w.submitted_flag,
	w.workorder_status,
	null as source_alt_status,
	w.workorder_id,
	w.company_id, 
	w.profit_ctr_id, 
	w.generator_id,
	w.generator_sublocation_id
FROM     
	workorderheader w (nolock) 
	INNER JOIN @tbl_profit_center_filter secured_copc ON (secured_copc.company_id = w.company_id and secured_copc.profit_ctr_id = w.profit_ctr_id)
	inner join workorderdetail d (nolock) on w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
	LEFT JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
		and wos.company_id = w.company_id
		and wos.profit_ctr_id = w.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE    
	w.generator_id in (select generator_id from customergenerator (nolock) where customer_id = 10673)
	-- 2/28/2011 - JPB: WAS... AND COALESCE(w.trip_act_departure, w.trip_est_departure, w.end_date) BETWEEN @StartDate AND @EndDate
	AND COALESCE(wos.date_act_depart, wos.date_est_depart, w.end_date) BETWEEN @StartDate AND @EndDate
	AND w.workorder_status NOT IN ('V','X','T') 
	AND w.trip_id is not null
	and d.bill_rate > 0
	-- per Brie, don't include things already invoiced - 2/28/2011)
	and not exists (select 1 from billing (nolock) where trans_source = 'W' and status_code = 'I' and receipt_id = w.workorder_id and company_id = w.company_id and profit_ctr_id = w.profit_ctr_id)

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Done with 2nd #tmp_flash fill from WO' as status
	
INSERT #tmp_flash (source, company_id, profit_ctr_id, receipt_id, line_id, workorder_resource_type, submitted_flag, source_status, source_alt_status, linked_workorder_id, linked_company_id, linked_profit_ctr_id, generator_id,	generator_sublocation_id)
SELECT   
	'Receipt' as Source,
	r.company_id, 
	r.profit_ctr_id, 
	r.receipt_id,
	r.line_id,
	null,
	r.submitted_flag,
	r.receipt_status,
	r.fingerpr_status as source_alt_status,
	w.workorder_id,
	w.company_id, 
	w.profit_ctr_id, 
	w.generator_id,
	w.generator_sublocation_id
FROM     
	receipt r 
	inner join billinglinklookup bll (nolock) on r.receipt_id = bll.receipt_id and r.company_id = bll.company_id and r.profit_ctr_id = bll.profit_ctr_id
	inner join workorderheader w (nolock) on w.workorder_id = bll.source_id and w.company_id = bll.source_company_id and w.profit_ctr_id = bll.source_profit_ctr_id
	INNER JOIN @tbl_profit_center_filter secured_copc ON (secured_copc.company_id = w.company_id and secured_copc.profit_ctr_id = w.profit_ctr_id)
	LEFT JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
		and wos.company_id = w.company_id
		and wos.profit_ctr_id = w.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE    
	w.customer_id = 10673
	-- 2/28/2011 - JPB: WAS... AND COALESCE(w.trip_act_departure, w.trip_est_departure, w.end_date) BETWEEN @StartDate AND @EndDate
	AND COALESCE(wos.date_act_depart, wos.date_est_depart, w.end_date) BETWEEN @StartDate AND @EndDate
	AND r.receipt_status NOT IN ('V') 
	AND w.trip_id is not null
	-- per Brie, don't include things already invoiced - 2/28/2011)
	and not exists (select 1 from billing (nolock) where trans_source = 'R' and status_code = 'I' and receipt_id = r.receipt_id and company_id = r.company_id and profit_ctr_id = r.profit_ctr_id)

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Done with 1st #tmp_flash fill from R' as status

INSERT #tmp_flash (source, company_id, profit_ctr_id, receipt_id, line_id, workorder_resource_type, submitted_flag, source_status, source_alt_status, linked_workorder_id, linked_company_id, linked_profit_ctr_id, generator_id,	generator_sublocation_id)
SELECT   
	'Receipt' as Source,
	r.company_id, 
	r.profit_ctr_id, 
	r.receipt_id,
	r.line_id,
	null,
	r.submitted_flag,
	r.receipt_status,
	r.fingerpr_status as source_alt_status,
	w.workorder_id,
	w.company_id, 
	w.profit_ctr_id, 
	w.generator_id,
	w.generator_sublocation_id
FROM     
	receipt r 
	inner join billinglinklookup bll (nolock) on r.receipt_id = bll.receipt_id and r.company_id = bll.company_id and r.profit_ctr_id = bll.profit_ctr_id
	inner join workorderheader w (nolock) on w.workorder_id = bll.source_id and w.company_id = bll.source_company_id and w.profit_ctr_id = bll.source_profit_ctr_id
	INNER JOIN @tbl_profit_center_filter secured_copc ON (secured_copc.company_id = w.company_id and secured_copc.profit_ctr_id = w.profit_ctr_id)
	LEFT JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
		and wos.company_id = w.company_id
		and wos.profit_ctr_id = w.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE    
	w.generator_id in (select generator_id from customergenerator (nolock) where customer_id = 10673)
	-- 2/28/2011 - JPB: WAS... AND COALESCE(w.trip_act_departure, w.trip_est_departure, w.end_date) BETWEEN @StartDate AND @EndDate
	AND COALESCE(wos.date_act_depart, wos.date_est_depart, w.end_date) BETWEEN @StartDate AND @EndDate
	AND r.receipt_status NOT IN ('V') 
	AND w.trip_id is not null
	-- per Brie, don't include things already invoiced - 2/28/2011)
	and not exists (select 1 from billing (nolock) where trans_source = 'R' and status_code = 'I' and receipt_id = r.receipt_id and company_id = r.company_id and profit_ctr_id = r.profit_ctr_id)

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Done with 2nd #tmp_flash fill from R' as status

INSERT #tmp_flash (source, company_id, profit_ctr_id, receipt_id, line_id, workorder_resource_type, submitted_flag, source_status, source_alt_status)
SELECT   
	'Order' as Source,
	d.company_id, 
	d.profit_ctr_id, 
	r.order_id,
	d.line_id,
	null,
	r.submitted_flag,
	r.status,
	null as source_alt_status
FROM     
	orderheader r 
	inner join orderdetail d 
		ON r.order_id = d.order_id
	INNER JOIN @tbl_profit_center_filter secured_copc ON (secured_copc.company_id = d.company_id and secured_copc.profit_ctr_id = d.profit_ctr_id)
WHERE    
	(r.customer_id = 10673 OR r.generator_id in (select generator_id from customergenerator (nolock) where customer_id = 10673))
	-- 2/28/2011 - JPB: WAS... AND COALESCE(w.trip_act_departure, w.trip_est_departure, w.end_date) BETWEEN @StartDate AND @EndDate
	AND r.order_date BETWEEN @StartDate AND @EndDate
	AND r.status NOT IN ('V') 
	AND NOT EXISTS (
		select 1 
		from billing (nolock) 
		where trans_source = 'O' 
		and status_code = 'I' 
		and receipt_id = r.order_id 
		and company_id = d.company_id 
		and profit_ctr_id = d.profit_ctr_id
	)

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Done with #tmp_flash fill from O' as status
         
-- Validations:

INSERT #tmp_validation
SELECT DISTINCT
	'Approvals on the receipt differ from WO: '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + ' : '
	+ dbo.fn_compare_approvals_wtor(t.receipt_id, t.company_id, t.profit_ctr_id) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
FROM
	#tmp_flash t
WHERE
	t.source = 'Workorder'
	AND dbo.fn_compare_approvals_wtor(t.receipt_id, t.company_id, t.profit_ctr_id) <> ''

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Done with validation: Approvals on the receipt differ from WO: ' as status

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
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
FROM #tmp_flash t
	INNER JOIN workorderdetail wod (nolock) 
		ON t.receipt_id = wod.workorder_id 
		AND t.company_id = wod.company_id 
		AND t.profit_ctr_id = wod.profit_ctr_id 
		AND t.source = 'Workorder'
		AND t.line_id = wod.sequence_id
		and t.workorder_resource_type = wod.resource_type
	INNER JOIN ResourceClass rc (nolock)
		ON wod.company_id = rc.company_id
		AND wod.profit_ctr_id = rc.profit_ctr_id
		AND wod.resource_class_code = rc.resource_class_code
WHERE 
	rc.description like '%demurrage%'
	AND wod.bill_unit_code = 'HOUR'
	AND wod.quantity_used > 1

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Demurrage exceeds 1 hour: W: ' as status

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
			AND line_id = t.line_id
			AND company_id = t.company_id
			AND profit_ctr_id = t.profit_ctr_id
			AND trans_source = 'R'
		) THEN 
			(
				SELECT SUM(total_extended_amt + insr_extended_amt + ensr_extended_amt)
				FROM billing b WHERE b.receipt_id = t.receipt_id
				AND b.line_id = t.line_id
				AND b.company_id = t.company_id
				AND b.profit_ctr_id = t.profit_ctr_id
				AND b.trans_source = 'R'
			)
		ELSE
			(
				SELECT SUM(total_extended_amt)
				FROM receiptprice b WHERE b.receipt_id = t.receipt_id
				AND b.line_id = t.line_id
				AND b.company_id = t.company_id
				AND b.profit_ctr_id = t.profit_ctr_id
			)
		END
	) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
FROM #tmp_flash t
WHERE
	t.source = 'Receipt'
	AND 1000 < (
		CASE WHEN EXISTS (
			SELECT 1 
			FROM BILLING (nolock)
			WHERE receipt_id = t.receipt_id
			AND line_id = t.line_id
			AND company_id = t.company_id
			AND profit_ctr_id = t.profit_ctr_id
			AND trans_source = 'R'
		) THEN 
			(
				SELECT SUM(total_extended_amt + insr_extended_amt + ensr_extended_amt)
				FROM billing b (nolock) WHERE b.receipt_id = t.receipt_id
				AND b.line_id = t.line_id
				AND b.company_id = t.company_id
				AND b.profit_ctr_id = t.profit_ctr_id
				AND b.trans_source = 'R'
			)
		ELSE
			(
				SELECT SUM(total_extended_amt)
				FROM receiptprice b (nolock) WHERE b.receipt_id = t.receipt_id
				AND b.line_id = t.line_id
				AND b.company_id = t.company_id
				AND b.profit_ctr_id = t.profit_ctr_id
			)
		END
	)

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Receipt pricing exceeds $1000: R ' as status

INSERT #tmp_validation
SELECT
	'Container ' + rp.bill_unit_code + ' > ' +
		convert(varchar(20), CASE rp.bill_unit_code WHEN 'DM05' THEN 150 WHEN 'DM30' THEN 450 WHEN 'DM55' THEN 750 END) +
		'lbs: R '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + '-'
	+ convert(varchar(20), t.line_id) + ' = '
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
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
FROM #tmp_flash t
	inner join Receipt r (nolock)
		ON t.receipt_id = r.receipt_id
		AND t.line_id = r.line_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
		and t.source = 'Receipt'
	INNER JOIN ReceiptPrice rp (nolock)
		ON rp.receipt_id = r.receipt_id
		AND rp.line_id = r.line_id
		AND rp.company_id = r.company_id
		AND rp.profit_ctr_id = r.profit_ctr_id
WHERE
	rp.bill_unit_code IN ('DM05', 'DM30', 'DM55')
	AND CASE rp.bill_unit_code WHEN 'DM05' THEN 150 WHEN 'DM30' THEN 450 WHEN 'DM55' THEN 750 END <
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

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Container over ___ lbs' as status

INSERT #tmp_validation
SELECT
	'Receipt With Missing or Zero Line Weight: R '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + '-'
	+ convert(varchar(20), t.line_id) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
FROM #tmp_flash t
	INNER JOIN receipt r (nolock)
		ON r.receipt_id = t.receipt_id
		AND r.line_id = t.line_id
		AND r.company_id = t.company_id
		AND r.profit_ctr_id = t.profit_ctr_id
WHERE
	t.source = 'Receipt'
	AND isnull(r.line_weight, 0) = 0
	AND r.trans_type = 'D'

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Receipt with missing or 0 line weight' as status

INSERT #tmp_validation
SELECT
	'Mixed (non-Cyl) Container Types in single Receipt line: R '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + '-'
	+ convert(varchar(20), t.line_id) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
FROM #tmp_flash t
	INNER JOIN receipt r (nolock)
		ON r.receipt_id = t.receipt_id
		AND r.line_id = t.line_id
		AND r.company_id = t.company_id
		AND r.profit_ctr_id = t.profit_ctr_id
	INNER JOIN ReceiptPrice rp (nolock)
		ON rp.receipt_id = r.receipt_id
		AND rp.line_id = r.line_id
		AND rp.company_id = r.company_id
		AND rp.profit_ctr_id = r.profit_ctr_id
WHERE
	t.source = 'Receipt'
	AND (
		( -- option 1: CY* mixed with another non CY* type.
			EXISTS (select 1 from receiptprice rp2 (nolock)
				where rp2.receipt_id = rp.receipt_id
				AND rp2.line_id = rp.line_id
				AND rp2.company_id = rp.company_id
				AND rp2.profit_ctr_id = rp.profit_ctr_id
				and bill_unit_code like 'CY%'
			)
			AND EXISTS (select 1 from receiptprice rp3 (nolock)
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
			FROM receiptprice rp4 (nolock)
			WHERE rp4.receipt_id = rp.receipt_id
				AND rp4.line_id = rp.line_id
				AND rp4.company_id = rp.company_id
				AND rp4.profit_ctr_id = rp.profit_ctr_id
				AND rp4.bill_unit_code NOT LIKE 'CY%'
			) > 1
		)
	)

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Mixed container types on a receipt line' as status

INSERT #tmp_validation
SELECT
	'Unpriced Receipt: R '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + '-'
	+ convert(varchar(20), t.line_id) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
FROM #tmp_flash t
	INNER JOIN receipt r (nolock)
		ON r.receipt_id = t.receipt_id
		AND r.line_id = t.line_id
		AND r.company_id = t.company_id
		AND r.profit_ctr_id = t.profit_ctr_id
WHERE
	t.source = 'Receipt'
AND NOT EXISTS (
	select 1 from ReceiptPrice  (nolock)
		WHERE receipt_id = r.receipt_id
		AND line_id = r.line_id
		AND company_id = r.company_id
		AND profit_ctr_id = r.profit_ctr_id
		AND price > 0
)	
GROUP BY 
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Unpriced receipt' as status

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
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
FROM
	#tmp_flash t
	inner join billinglinklookup bll (nolock) on t.receipt_id = bll.source_id and t.company_id = bll.source_company_id and t.profit_ctr_id = bll.source_profit_ctr_id and t.source = 'Workorder' AND bll.link_required_flag <> 'E'
	inner join receipt r (nolock) on bll.receipt_id = r.receipt_id and t.line_id = r.line_id and bll.company_id = r.company_id and bll.profit_ctr_id = r.profit_ctr_id
	inner join workorderheader w (nolock) on bll.source_id = w.workorder_id and bll.source_company_id = r.company_id and bll.source_profit_ctr_id = w.profit_ctr_id
	LEFT OUTER JOIN billing WB (nolock) ON t.receipt_id = WB.receipt_id and t.company_id = WB.company_id AND t.profit_ctr_id = WB.profit_ctr_id and t.source = 'Workorder' and WB.status_code = 'I'
	LEFT OUTER JOIN billing RB (nolock) ON bll.receipt_id = RB.receipt_id and bll.company_id = RB.company_id AND bll.profit_ctr_id = RB.profit_ctr_id and RB.status_code = 'I'
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

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Receipt and Work Order not on same invoice' as status


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
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
FROM #tmp_flash t
	INNER JOIN workorderdetail wod  (nolock)
		ON t.receipt_id = wod.workorder_id 
		AND t.line_id = wod.sequence_id
		AND t.workorder_resource_type = wod.resource_type
		AND t.company_id = wod.company_id 
		AND t.profit_ctr_id = wod.profit_ctr_id 
		AND t.source = 'Workorder'
	LEFT JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = wod.workorder_id
		and wos.company_id = wod.company_id
		and wos.profit_ctr_id = wod.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 
	wos.date_act_arrive > wos.date_act_depart

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Arrive date after depart date' as status

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
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
FROM #tmp_flash t
	INNER JOIN workorderdetail wod  (nolock)
		ON t.receipt_id = wod.workorder_id 
		and t.line_id = wod.sequence_id
		and t.workorder_resource_type = wod.resource_type
		AND t.company_id = wod.company_id 
		AND t.profit_ctr_id = wod.profit_ctr_id 
		AND t.source = 'Workorder'
	INNER JOIN workorderheader woh (nolock)
		ON wod.workorder_id = woh.workorder_id
		and wod.company_id = woh.company_id
		and wod.profit_ctr_id = woh.profit_ctr_id
	LEFT JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = wod.workorder_id
		and wos.company_id = wod.company_id
		and wos.profit_ctr_id = wod.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 
	wos.date_act_arrive < woh.start_date

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Arrive date before start date' as status

-- Please add a validation that flags weight that exceeds 1,000 pounds for approval WMHW03S2
INSERT #tmp_validation
SELECT
	'Approval WMHW03S2 with weight > 1000 lbs: R '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) + '-'
	+ convert(varchar(20), t.line_id) + ' = '
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
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
FROM #tmp_flash t
	inner join Receipt r (nolock)
		ON t.receipt_id = r.receipt_id
		AND t.line_id = r.line_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
		and t.source = 'Receipt'
	INNER JOIN ReceiptPrice rp (nolock)
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

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Approval WMHW03S2 > 1000 lbs' as status

-- Please add a validation that will flag if the manifest number does not have 
-- 9 digits and 3 letters. Exclude from the validation the manifest numbers on receipts with approval WMNHW10 
INSERT #tmp_validation
SELECT
	'Invalid Manifest Number: ' + r.manifest as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
FROM #tmp_flash t
	inner join Receipt r (nolock)
		ON t.receipt_id = r.receipt_id
		AND t.line_id = r.line_id
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
	AND r.approval_code <> 'WMNHW10'

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Invalid Manifest Number' as status

-- Check for multiple billing project id's on 1 receipt.
INSERT #tmp_validation
SELECT
	'Multiple Billing Projects on 1 Receipt: '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(20), t.receipt_id) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
FROM #tmp_flash t
	inner join Receipt r (nolock)
		ON t.receipt_id = r.receipt_id
		AND t.line_id = r.line_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
		and t.source = 'Receipt'
GROUP BY 
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
HAVING count(distinct r.billing_project_id) > 1	

if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Multiple Billing Porjects On 1 Receipt' as status

-- Assign wm_bill_type values for records we know how to handle...
update #tmp_flash set wm_bill_type = 'Materials - Disposal'
FROM #tmp_flash t
	left outer join Receipt r (nolock)
		ON t.receipt_id = r.receipt_id
		and t.line_id = r.line_id
		and t.company_id = r.company_id
		and t.profit_ctr_id = r.profit_ctr_id
		and t.source = 'Receipt'
	left outer join workorderdetail wod (nolock)
		ON t.receipt_id = wod.workorder_id 
		and t.line_id = wod.sequence_id
		and t.workorder_resource_type = wod.resource_type
		AND t.company_id = wod.company_id 
		AND t.profit_ctr_id = wod.profit_ctr_id 
		AND t.source = 'Workorder'
	
WHERE 
((t.source = 'Workorder' and t.workorder_resource_type = 'D')
	or (t.source = 'Receipt' and r.trans_type = 'D')
	or (t.source = 'Receipt' and r.trans_type = 'S' and r.waste_code = 'LMIN')
)

update #tmp_flash set wm_bill_type = 'Materials - Supplies'
FROM #tmp_flash t
INNER JOIN workorderdetail wod (nolock)
		ON t.receipt_id = wod.workorder_id 
		and t.line_id = wod.sequence_id
		and t.workorder_resource_type = wod.resource_type
		AND t.company_id = wod.company_id 
		AND t.profit_ctr_id = wod.profit_ctr_id 
		AND t.source = 'Workorder'
where t.source = 'Workorder'
and (t.workorder_resource_type = 'S' 
or wod.resource_class_code = 'MISC'
)

update #tmp_flash set wm_bill_type = 'Materials - Laboratory Analysis'
FROM #tmp_flash t
INNER JOIN workorderdetail wod (nolock)
		ON t.receipt_id = wod.workorder_id 
		and t.line_id = wod.sequence_id
		and t.workorder_resource_type = wod.resource_type
		AND t.company_id = wod.company_id 
		AND t.profit_ctr_id = wod.profit_ctr_id 
		AND t.source = 'Workorder'
where t.source = 'Workorder'
and wod.resource_class_code = 'LABTEST'

update #tmp_flash set wm_bill_type = 'Materials - Fuel Surcharge'
FROM #tmp_flash t
INNER JOIN workorderdetail wod (nolock)
		ON t.receipt_id = wod.workorder_id 
		and t.line_id = wod.sequence_id
		and t.workorder_resource_type = wod.resource_type
		AND t.company_id = wod.company_id 
		AND t.profit_ctr_id = wod.profit_ctr_id 
		AND t.source = 'Workorder'
where t.source = 'Workorder'
and t.workorder_resource_type = 'O'
and wod.resource_class_code = 'FEEGASSR'

update #tmp_flash set wm_bill_type = 'Labor - Stop Fee'
FROM #tmp_flash t
INNER JOIN workorderdetail wod (nolock)
		ON t.receipt_id = wod.workorder_id 
		and t.line_id = wod.sequence_id
		and t.workorder_resource_type = wod.resource_type
		AND t.company_id = wod.company_id 
		AND t.profit_ctr_id = wod.profit_ctr_id 
		AND t.source = 'Workorder'
where t.source = 'Workorder'
and t.workorder_resource_type = 'O'
and wod.resource_class_code = 'STOPFEE'

update #tmp_flash set wm_bill_type = 'Labor - Demurrage'
FROM #tmp_flash t
INNER JOIN workorderdetail wod (nolock)
		ON t.receipt_id = wod.workorder_id 
		and t.line_id = wod.sequence_id
		and t.workorder_resource_type = wod.resource_type
		AND t.company_id = wod.company_id 
		AND t.profit_ctr_id = wod.profit_ctr_id 
		AND t.source = 'Workorder'
where t.source = 'Workorder'
and t.workorder_resource_type = 'O'
and wod.resource_class_code = 'DEMURRAGE'

update #tmp_flash set wm_bill_type = 'Freight - Parcel Services'
FROM #tmp_flash t
INNER JOIN workorderdetail wod (nolock)
		ON t.receipt_id = wod.workorder_id 
		and t.line_id = wod.sequence_id
		and t.workorder_resource_type = wod.resource_type
		AND t.company_id = wod.company_id 
		AND t.profit_ctr_id = wod.profit_ctr_id 
		AND t.source = 'Workorder'
where t.source = 'Workorder'
and wod.resource_class_code IN ('T&DPRODUCT', 'SUBSERVICE', 'FEESHIP')


if @debug > 0
	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Check for record types we don''t know how to handle in the invoice breakdown files: Receipt' as status

-- Check for record types we don't know how to handle in the invoice breakdown files: Workorder
INSERT #tmp_validation
SELECT
	'UnIdentified data (Not sure how to classify it in Invoice Extracts): '
	+ convert(varchar(2), t.company_id) + '-'
	+ convert(varchar(2), t.profit_ctr_id) + ':'
	+ convert(varchar(2), t.source) + ': '
	+ convert(varchar(20), t.receipt_id) + ' Type: '
	+ convert(varchar(1), t.workorder_resource_type) + ' Line: '
	+ convert(varchar(10), t.line_id) as problem,
	t.source,
	t.company_id,
	t.profit_ctr_id,
	t.receipt_id,
	t.line_id,
	t.workorder_resource_type,
	t.submitted_flag,
	t.source_status,
	t.source_alt_status,
	t.linked_workorder_id,
	t.linked_company_id,
	t.linked_profit_ctr_id
FROM #tmp_flash t
WHERE t.wm_bill_type is null

-- if @debug > 0
-- 	select getdate() as time_now, datediff(ms, @timer, getdate()) as elapsed_time, @@rowcount as row_count, 'Check for record types we don''t know how to handle in the invoice breakdown files: Workorder' as status

set nocount off

-- OUTPUT:
SELECT DISTINCT 
	tv.problem,
	tv.source,
	tv.company_id, 
	tv.profit_ctr_id, 
	tv.receipt_id,
--	tv.line_id,
--	tv.workorder_resource_type,
	tv.submitted_flag,
	tv.source_status,
	tv.source_alt_status,
	gsl.code as generator_sublocation_code,
	gsl.description as generator_sublocation_description,
	wh.combined_service_flag,
	wh.offschedule_service_flag,
	osr.reason_desc as offschedule_service_reason_description
FROM 
	#tmp_validation tv
	left join workorderheader wh on tv.linked_workorder_id = wh.workorder_id
		and tv.linked_company_id = wh.company_id
		and tv.linked_profit_ctr_id = wh.profit_ctr_id
	left join GeneratorSubLocation gsl on wh.generator_sublocation_id = gsl.generator_sublocation_id
	left join OffScheduleServiceReason osr on wh.offschedule_service_reason_id = osr.reason_id
WHERE
	isnull(tv.problem, '') <> ''
ORDER BY
	tv.company_id,
	tv.profit_ctr_id,
	tv.source,
	tv.receipt_id

	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_wm_billing_validation] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_wm_billing_validation] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_wm_billing_validation] TO [EQAI]
    AS [dbo];

