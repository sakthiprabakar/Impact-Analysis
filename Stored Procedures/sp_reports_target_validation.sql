CREATE PROCEDURE sp_reports_target_validation
	@StartDate		datetime
,	@EndDate		datetime
,	@user_code		varchar(100)
,	@permission_id	int
,	@report_log_id	int
,	@debug			int = 0
AS
	
/* ******************************************************************************
Procedure    : sp_reports_target_validation
Database     : PLT_AI, EQ_EXTRACT
Created      : FEB 20, 2012 - Smita K
Description  : Validation for Target

Examples: exec sp_reports_target_validation '2012-01-01 00:00:00', '2012-01-10 00:00:00', 'SMITA_K', 179
Examples: exec sp_reports_target_validation '2013-01-21 00:00:00', '2013-05-31 23:59:00', 'SMITA_K', 179, 0, 0

****************************************************************************** */
DECLARE 
	@tmp_filename	varchar(255)
,	@tmp_desc		varchar(255)

CREATE TABLE #tmp_results (
	row_id				int			identity(1,1)
,	po_number			varchar(20)
,	location_number		varchar(8)
,	service_date		datetime
,	manifest			varchar(20)
,	vendor_name			varchar(20)
,	vendor_number		varchar(20)
,	eq_purchase_order	varchar(20)
,	image_id			int
,	trans_source		char(1)
,	receipt_id			int			-- or workorderdetail.workorder_id
,	company_id			int
,	profit_ctr_id		int
,	scan_status			char(1)
,	scan_manifest		varchar(20)
,	scan_page_number	int
,	date_added			datetime
,	added_by			varchar(20)
,	from_date			datetime
,	to_date				datetime
,	billing_status		char(1)
)

CREATE TABLE #tmp_validation (
	problem				varchar(max)
,	source				varchar(max)
,	company_id			int
,	profit_ctr_id		int
,	receipt_id			int
,	manifest			varchar(20)
,	max_manifest_page	int
,	count_image_id		int
)

/*** RESULT SET ************************************************************/

INSERT #tmp_results
-- WO (no EQ disposal) info
SELECT DISTINCT
CASE WHEN CHARINDEX('BP', woh.purchase_order) <= 0 THEN 
	CASE WHEN IsNumeric(woh.purchase_order) = 1 THEN
		'BP' + woh.purchase_order 
	ELSE
		woh.purchase_order
	END
ELSE 
	woh.purchase_order 
END AS PO_Number
, isnull(g.site_code, '') AS Location_Number
, convert(varchar(20), coalesce(wos.date_act_arrive, woh.start_date), 101) as Service_Date
, wod.manifest AS manifest
, 'EQ' as Vendor_Name
, '10183741' AS Vendor_Number
, woh.purchase_order
, s.image_id
, 'W'
, woh.workorder_id
, woh.company_id
, woh.profit_ctr_id
, s.status
, s.manifest
, s.page_number
, getdate()
, @user_code
, @StartDate
, @EndDate
, b.status_code
FROM WorkOrderHeader woh (nolock)
INNER JOIN WorkorderDetail wod (nolock)
	ON woh.workorder_id = wod.workorder_id
	AND woh.company_id = wod.company_id
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND wod.bill_rate > 0
INNER JOIN Generator g (nolock)
	ON woh.generator_id = g.generator_id
INNER JOIN CustomerBilling cb (nolock)
	ON woh.customer_id = cb.customer_id
	AND woh.billing_project_id = cb.billing_project_id
LEFT OUTER JOIN Billing b (nolock)
	ON woh.workorder_id = b.receipt_id
	AND wod.resource_type = b.workorder_resource_type
	AND wod.sequence_id = b.workorder_sequence_id
	AND wod.company_id = b.company_id
	AND wod.profit_ctr_id = b.profit_ctr_id
	AND b.status_code = 'I'
	AND b.trans_source = 'W'
LEFT OUTER JOIN WorkOrderStop wos (nolock) 
	ON wos.workorder_id = woh.workorder_id
	AND wos.company_id = woh.company_id
	AND wos.profit_ctr_id = woh.profit_ctr_id
	AND wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
INNER JOIN plt_image..scan s (nolock)
	ON woh.workorder_id = s.workorder_id
	AND woh.company_id = s.company_id
	AND woh.profit_ctr_id = s.profit_ctr_id
	AND s.status = 'A'
	AND s.type_id in (1, 4, 28)
LEFT OUTER JOIN TSDF t2  (nolock) 
	ON wod.tsdf_code = t2.tsdf_code
WHERE woh.customer_id = 12113
	AND coalesce(wos.date_act_arrive, woh.start_date) BETWEEN @StartDate AND @Enddate
	AND wod.resource_type = 'D'
	AND woh.workorder_status IN ('A','C','D','N','P' /*,'X' */)
	AND wod.bill_rate > 0

UNION

-- Receipt Info:
SELECT DISTINCT
CASE WHEN CHARINDEX('BP', r.purchase_order) <= 0 THEN 
	CASE WHEN IsNumeric(r.purchase_order) = 1 THEN
		'BP' + r.purchase_order 
	ELSE
		r.purchase_order
	END
ELSE 
	r.purchase_order 
END AS PO_Number
, isnull(g.site_code, '') AS Location_Number
, convert(varchar(20), coalesce(rt1.transporter_sign_date, wos.date_act_arrive, woh.start_date, r.receipt_date), 101) as Service_Date
, r.manifest AS manifest
, 'EQ' as Vendor_Name
, '10183741' AS Vendor_Number
, r.purchase_order
, s.image_id
, 'R'
, r.receipt_id
, r.company_id
, r.profit_ctr_id
, s.status
, s.manifest
, s.page_number
, getdate()
, @user_code
, @StartDate
, @EndDate
, b.status_code
FROM Receipt r (nolock)
INNER JOIN receiptprice rp (nolock)
	ON r.receipt_id = rp.receipt_id
	AND r.line_id = rp.line_id
	AND r.company_id = rp.company_id
	AND r.profit_ctr_id = rp.profit_ctr_id
LEFT OUTER JOIN ReceiptTransporter rt1 (nolock)
	ON r.receipt_id = rt1.receipt_id
	AND r.company_id = rt1.company_id
	AND r.profit_ctr_id = rt1.profit_ctr_id
	AND rt1.transporter_sequence_id = 1
INNER JOIN generator g (nolock)
	ON r.generator_id = g.generator_id
INNER JOIN CustomerBilling cb (nolock)
	ON r.customer_id = cb.customer_id
	AND r.billing_project_id = cb.billing_project_id
LEFT OUTER JOIN billing b (nolock)
	ON r.receipt_id = b.receipt_id
	AND r.line_id = b.line_id
	AND rp.price_id = b.price_id
	AND r.company_id = b.company_id
	AND r.profit_ctr_id = b.profit_ctr_id
	AND b.status_code = 'I'
	AND b.trans_source = 'R'
LEFT OUTER JOIN billinglinklookup bll (nolock)
	ON r.receipt_id = bll.receipt_id
	AND r.company_id = bll.company_id
	AND r.profit_ctr_id = bll.profit_ctr_id
LEFT OUTER JOIN WorkOrderHeader woh (nolock)
	ON bll.source_id = woh.workorder_id
	AND bll.source_company_id = woh.company_id
	AND bll.source_profit_ctr_id = woh.profit_ctr_id		
LEFT OUTER JOIN WorkOrderStop wos (nolock) 
	ON wos.workorder_id = woh.workorder_id
	AND wos.company_id = woh.company_id
	AND wos.profit_ctr_id = woh.profit_ctr_id
	AND wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
INNER JOIN plt_image..scan s (nolock)
	ON r.receipt_id = s.receipt_id
	AND r.company_id = s.company_id
	AND r.profit_ctr_id = s.profit_ctr_id
	AND s.status = 'A'
	AND s.type_id in (1, 4, 28)
WHERE r.customer_id = 12113
	AND coalesce(rt1.transporter_sign_date, wos.date_act_arrive, woh.start_date, r.receipt_date) BETWEEN @StartDate AND @Enddate
	AND r.receipt_status = 'A'
	AND r.fingerpr_status = 'A'


/*** Target-requested PO Number Reformat *************************************/
--  After the BP should be 12 digits, 0-padded from left.
-- 1. Trim. Some start with spaces
	update #tmp_results set po_number = ltrim(rtrim(po_number))

-- 2. Update those that start with BP and are numeric afterward	
	update #tmp_results set po_number = 'BP' + right('000000000000' + right(po_number, len(po_number)-2), 10)
	where left(po_number,2) = 'BP' and isnumeric(right(po_number, len(po_number)-2)) = 1

-- 3. If there's no PO, use BP9999999999
	update #tmp_results set po_number = 'BP9999999999' where ISNULL(po_number, '') = ''


/*** VALIDATIONS ***********************************************************/

-- Is this a valid manifest number? (look for things less than 12 or not 9-3)
INSERT #tmp_validation
SELECT 
	'Invalid Manifest Number?' AS problem, 
	w.trans_source, w.company_id, w.profit_ctr_id, w.receipt_id, w.manifest
	, convert(int, null) AS max_manifest_page
	, convert(int, null) AS count_image_id
FROM #tmp_results w (nolock)
WHERE (	len(w.manifest) < 12
		OR ( len(w.manifest) = 12 AND (isnumeric(left(w.manifest, 9)) = 0 OR isnumeric(right(w.manifest, 3)) = 1) )
		OR len(w.manifest) > 12
	  )

UNION

SELECT 
	'Not Invoiced' AS problem, 
	w.trans_source, w.company_id, w.profit_ctr_id, w.receipt_id, w.manifest
	, convert(int, null) AS max_manifest_page
	, convert(int, null) AS count_image_id
FROM #tmp_results w (nolock)
WHERE isnull(billing_status, '') <> 'I'

UNION

SELECT 
	'Invalid PO? ' + po_number AS problem, 
	w.trans_source, w.company_id, w.profit_ctr_id, w.receipt_id, w.manifest
	, convert(int, null) AS max_manifest_page
	, convert(int, null) AS count_image_id
FROM #tmp_results w (nolock)
WHERE ( LEN(po_number) <> 12 OR LEFT(po_number, 2) <> 'BP' )

UNION 

-- list of locations on workorders without receipts
SELECT 'Location on Work Order but no Receipt' AS problem, 
	w.trans_source, w.company_id, w.profit_ctr_id, w.receipt_id, w.manifest
	, convert(int, null) AS max_manifest_page
	, convert(int, null) AS count_image_id
FROM #tmp_results w (nolock)
WHERE w.trans_source = 'W'
	AND NOT EXISTS ( select 1 from #tmp_results r (nolock) WHERE r.trans_source = 'R' AND r.location_number = w.location_number )

UNION

-- Find missing scans:
SELECT 
	'Missing scan? (No scan or incomplete scan)' AS problem, 
	w.trans_source, w.company_id, w.profit_ctr_id, w.receipt_id, w.manifest, max(isnull(s.max_manifest_page_num, 0)) AS max_manifest_page
	, count(distinct image_id) AS count_image_id
FROM #tmp_results w (nolock)
INNER JOIN 
	(select e.trans_source, r.receipt_id, r.company_id, r.profit_ctr_id, r.manifest, max(r.manifest_page_num) AS max_manifest_page_num
	FROM receipt r (nolock) INNER JOIN #tmp_results e (nolock) ON e.trans_source = 'r' AND e.receipt_id = r.receipt_id 
	and e.company_id = r.company_id and e.profit_ctr_id = r.profit_ctr_id AND e.manifest = r.manifest
	group by e.trans_source, r.receipt_id, r.company_id, r.profit_ctr_id, r.manifest
	union all
	select e.trans_source, w.workorder_id, w.company_id, w.profit_ctr_id, w.manifest, max(w.manifest_page_num) AS max_manifest_page_num
	FROM workorderdetail w (nolock) INNER JOIN #tmp_results e (nolock) ON e.trans_source = 'w' AND e.receipt_id = w.workorder_id 
	and e.company_id = w.company_id and e.profit_ctr_id = w.profit_ctr_id AND e.manifest = w.manifest
	group by e.trans_source, w.workorder_id, w.company_id, w.profit_ctr_id, w.manifest
	) s ON w.trans_source = s.trans_source and w.receipt_id = s.receipt_id and s.company_id = w.company_id and s.profit_ctr_id = w.profit_ctr_id and s.manifest = w.manifest
WHERE isnull(scan_status, '') <> 'A'
GROUP BY w.trans_source, w.company_id, w.profit_ctr_id, w.receipt_id, w.manifest

UNION

-- Find where there's more/less pages than there appears should be:
SELECT 
	'Wrong Number of Scans? (page vs image_id count comparison)',
	w.trans_source, w.company_id, w.profit_ctr_id, w.receipt_id, w.manifest, max(s.max_manifest_page_num) AS max_manifest_page
	, count(distinct image_id) AS count_image_id
FROM #tmp_results w (nolock)
INNER JOIN 
	(select e.trans_source, r.receipt_id, r.company_id, r.profit_ctr_id, r.manifest, max(r.manifest_page_num) AS max_manifest_page_num
	FROM receipt r (nolock) INNER JOIN #tmp_results e (nolock) ON e.trans_source = 'r' AND e.receipt_id = r.receipt_id 
	and e.company_id = r.company_id and e.profit_ctr_id = r.profit_ctr_id AND e.manifest = r.manifest
	group by e.trans_source, r.receipt_id, r.company_id, r.profit_ctr_id, r.manifest
	union all
	select e.trans_source, w.workorder_id, w.company_id, w.profit_ctr_id, w.manifest, max(w.manifest_page_num) AS max_manifest_page_num
	FROM workorderdetail w (nolock) INNER JOIN #tmp_results e (nolock)
	ON e.trans_source = 'w' AND e.receipt_id = w.workorder_id and e.company_id = w.company_id and e.profit_ctr_id = w.profit_ctr_id 
	AND e.manifest = w.manifest
	group by e.trans_source, w.workorder_id, w.company_id, w.profit_ctr_id, w.manifest
	) s ON w.trans_source = s.trans_source and w.receipt_id = s.receipt_id and s.company_id = w.company_id and s.profit_ctr_id = w.profit_ctr_id and s.manifest = w.manifest
WHERE isnull(scan_status, '') = 'A'
GROUP BY w.trans_source, w.company_id, w.profit_ctr_id, w.receipt_id, w.manifest
HAVING max(s.max_manifest_page_num) <> count(distinct image_id)

UNION 

-- Find where there's more/less pages than there appears should be:
SELECT 
	'Wrong Number of Scans? (this scan size vs avg scan size comparison)',
	w.trans_source, w.company_id, w.profit_ctr_id, w.receipt_id, w.manifest
	, max(s.max_manifest_page_num) AS max_manifest_page, count(distinct w.image_id) AS count_image_id
FROM #tmp_results w (nolock)
INNER JOIN 
	(select e.trans_source, r.receipt_id, r.company_id, r.profit_ctr_id, r.manifest, max(r.manifest_page_num) AS max_manifest_page_num
	FROM receipt r (nolock) INNER JOIN #tmp_results e (nolock) ON e.trans_source = 'r' AND e.receipt_id = r.receipt_id 
	and e.company_id = r.company_id and e.profit_ctr_id = r.profit_ctr_id AND e.manifest = r.manifest
	group by e.trans_source, r.receipt_id, r.company_id, r.profit_ctr_id, r.manifest
	union all
	select e.trans_source, w.workorder_id, w.company_id, w.profit_ctr_id, w.manifest, max(w.manifest_page_num) AS max_manifest_page_num
	FROM workorderdetail w (nolock) INNER JOIN #tmp_results e (nolock) ON e.trans_source = 'w' AND e.receipt_id = w.workorder_id 
	and e.company_id = w.company_id and e.profit_ctr_id = w.profit_ctr_id AND e.manifest = w.manifest
	group by e.trans_source, w.workorder_id, w.company_id, w.profit_ctr_id, w.manifest
	) s ON w.trans_source = s.trans_source and w.receipt_id = s.receipt_id and s.company_id = w.company_id and s.profit_ctr_id = w.profit_ctr_id and s.manifest = w.manifest
INNER JOIN plt_image..scanimage si on si.image_id = w.image_id
WHERE isnull(scan_status, '') = 'A'
GROUP BY w.trans_source, w.company_id, w.profit_ctr_id, w.receipt_id, w.manifest
HAVING sum(datalength(image_blob)) / ( SELECT avg(datalength(image_blob)) * 1.05
										FROM plt_image..scanimage scanimage (nolock)
										inner join plt_image..scan scan on scanimage.image_id = scan.image_id 
										where scan.image_id in ( select TOP 100 image_id from plt_image..scan (nolock) 
																where file_type = 'bmp' ORDER BY date_added desc 
																) 
										and scan.status = 'A'
										AND scan.type_id IN (1, 4, 28)
									  )
> max(s.max_manifest_page_num)
and count(distinct w.image_id) <= max(s.max_manifest_page_num)

UNION

SELECT 
	'Duplicated Manifest + Line: ' + s.manifest + '-' + convert(Varchar(20), s.manifest_line) as problem,
	-- , w.trans_source, w.company_id, w.profit_ctr_id, w.receipt_id, w.manifest
	NULL, NULL, NULL, NULL, NULL, NULL, NULL
FROM #tmp_results w (nolock)
INNER JOIN 
	(select e.trans_source, r.receipt_id, r.company_id, r.profit_ctr_id, r.manifest, r.manifest_line
	FROM receipt r (nolock) INNER JOIN #tmp_results e (nolock) ON e.trans_source = 'r' AND e.receipt_id = r.receipt_id 
	and e.company_id = r.company_id and e.profit_ctr_id = r.profit_ctr_id AND e.manifest = r.manifest
	union all
	select e.trans_source, w.workorder_id, w.company_id, w.profit_ctr_id, w.manifest, w.manifest_line
	FROM workorderdetail w (nolock) INNER JOIN #tmp_results e (nolock)
	ON e.trans_source = 'w' AND e.receipt_id = w.workorder_id and e.company_id = w.company_id and e.profit_ctr_id = w.profit_ctr_id 
	AND e.manifest = w.manifest
	) s ON w.trans_source = s.trans_source and w.receipt_id = s.receipt_id and s.company_id = w.company_id and s.profit_ctr_id = w.profit_ctr_id and s.manifest = w.manifest
WHERE isnull(scan_status, '') = 'A'
GROUP BY -- w.trans_source, w.company_id, w.profit_ctr_id, w.receipt_id, w.manifest, 
s.manifest, s.manifest_line
HAVING count(distinct s.manifest + '-' + convert(Varchar(20), s.manifest_line)) > 1

-- OUTPUT:
TRUNCATE TABLE eq_temp..sp_reports_target_validation	

INSERT eq_temp..sp_reports_target_validation	
SELECT DISTINCT 
	problem
,	source
,	company_id
,	profit_ctr_id
,	receipt_id
,	manifest
,	max_manifest_page
,	count_image_id
FROM 
	#tmp_validation
ORDER BY
	company_id,
	profit_ctr_id,
	source,
	receipt_id

/********	EXPORT RESULTS TO Excel: ***********************************************/
SELECT @tmp_filename = 'Target Validation - .xls',
   	@tmp_desc = 'Target Validation Export: ' + convert(varchar(10), @StartDate, 110) + ' - ' + convert(varchar(12), @Enddate, 110)


EXEC plt_export.dbo.sp_export_to_excel
	@table_name	     = 'eq_temp..sp_reports_target_validation',
	@template	     = 'sp_reports_target_validation.Validation',
	@filename	     = @tmp_filename,
	@added_by	     = @user_code,
	@export_desc     = @tmp_desc,
	@report_log_id   = @report_log_id,
	@debug = 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_target_validation] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_target_validation] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_target_validation] TO [EQAI]
    AS [dbo];

