CREATE PROCEDURE sp_rpt_po_accumulate
	@debug				int,
	@customer_id_from	int,
	@customer_id_to		int,
	@in_cust_name		varchar(40),
	@in_cust_type		varchar(10),
	@in_territory		varchar(10),
	@in_purchase_order	varchar(20),
	@in_billing_project_id	int,
	@db_type			varchar(4),
	@report_type		int
AS
/***************************************************************************************
Retrieves the list of purchase orders specified for this criteria.  The nested report
retrieves the detail

Filename:		L:\Apps\SQL\EQAI\sp_rpt_po_accumulate.sql
Loads to:		Plt_AI
PB Object(s):	d_rpt_po_accumulate_detail,
				d_rpt_po_accumulate_summary

@report_type	1 = Summary, 2 = Detail

08/21/2007 SCC	Created
10/22/2007 SCC	Updated to send additional info for Detail and Summary versions
09/09/2008 JDB	Added Energy Surcharge.

sp_rpt_po_accumulate 1, 6243, 6243, '%', '%', '%', '%', -1, 'DEV', 2
****************************************************************************************/
DECLARE	
	@sql		varchar(8000),
	@db_count	int,
	@db_ref		varchar(40),
	@results_count	int

CREATE TABLE #results (
	customer_id		int NOT NULL,
	billing_project_id	int NULL,
	purchase_order	varchar(20) NULL,
	status_code		char(1) NULL,
	status			varchar(20) NULL,
	company_id		int NULL,
	profit_ctr_id	int NULL,
	record_source	varchar(15) NULL,
	trans_source	char(1) NULL,
	source_date		datetime NULL,
	source_id		int NULL,
	amount			money NULL,
    insr_amount		money,
    ensr_amount		money,
    total_amount	money,
    invoice_code	varchar(20) NULL,
    invoice_date	datetime NULL,
	sort_order		int NULL
)

CREATE TABLE #po_amt (
	customer_id		int NOT NULL,
	cust_name		varchar(40) NULL,
	billing_project_id	int NULL,
	project_name 	varchar(40) NULL,
	purchase_order	varchar(20) NULL,
	po_amt			money NULL,
	po_sum			money NULL,
    po_insr_amt		money NULL,
    po_ensr_amt		money NULL,
    po_total_amt	money NULL,
	po_remains		money NULL,
	po_percent_used	money NULL,
	warning_percent	money NULL,
	added_by		varchar(10) NULL,
	date_added		datetime NULL,
	start_date		datetime NULL,
	expiration_date	datetime NULL,
	warning_message	varchar(80) NULL
)


CREATE TABLE #po_summary (
	customer_id		int NOT NULL,
	purchase_order	varchar(20) NULL,
	po_amt			money NULL,
	po_sum			money NULL,
    po_insr_amt		money NULL,
    po_total_amt	money NULL,
	po_remains		money NULL,
	po_percent_used	money NULL,
	warning_percent	money NULL,
	expiration_date	datetime NULL,
	warning_message	varchar(80) NULL
)

-- These are the company databases to process
SELECT	DISTINCT
	C.company_id,
	D.database_name + '..' AS db_ref,
	0 AS process_flag
INTO #tmp_db
FROM EQConnect C WITH (nolock),
	EQDatabase D WITH (nolock)
WHERE C.db_name_eqai = D.database_name
	AND C.db_type = D.db_type
	AND C.db_type = @db_type
SET @db_count = @@ROWCOUNT

-- First, get the accumulations from the billing table
INSERT #results
SELECT 
	Billing.customer_id,
	IsNULL(Billing.billing_project_id,0),
	Billing.purchase_order,
	Billing.status_code,
	'' AS billing_status,
	Billing.company_id,
	Billing.profit_ctr_id,
	'Billing' AS record_source,
	Billing.trans_source,
	Billing.billing_date,
	Billing.receipt_id,
	SUM(ISNULL(Billing.total_extended_amt, 0)),
	SUM(ISNULL(Billing.insr_extended_amt, 0)),
	SUM(ISNULL(Billing.ensr_extended_amt, 0)),
	0 AS total_amt,
    MAX(ISNULL(billing.invoice_code, '')),
    MAX(billing.invoice_date),
    0 AS sort_order
FROM Billing
JOIN Customer 
	ON Billing.customer_id = Customer.customer_id
	AND (Customer.customer_id BETWEEN @customer_id_from AND @customer_id_to)
	AND (@in_cust_name = '%' OR Customer.cust_name like @in_cust_name)
	AND (@in_cust_type = '%' OR Customer.customer_type = @in_cust_type)
JOIN CustomerBilling
	ON Billing.customer_id = CustomerBilling.customer_id
	AND Billing.billing_project_id = CustomerBilling.billing_project_id
	AND CustomerBilling.status = 'A'
	AND (@in_billing_project_id = -1 OR CustomerBilling.billing_project_id = @in_billing_project_id)
	AND (@in_territory = '%' OR CustomerBilling.territory_code = @in_territory)
JOIN CustomerBillingPO
	ON Billing.customer_id = CustomerBillingPO.customer_id
	AND Billing.billing_project_id = CustomerBillingPO.billing_project_id
	AND Billing.purchase_order = CustomerBillingPO.purchase_order
	AND CustomerBillingPO.status = 'A'
	AND IsNULL(CustomerBillingPO.po_amt,0) > 0
	AND (@in_billing_project_id = -1 OR CustomerBillingPO.billing_project_id = @in_billing_project_id)
	AND (@in_purchase_order = '%' OR CustomerBillingPO.purchase_order = @in_purchase_order)
WHERE IsNULL(Billing.purchase_order,'') <> ''
	AND Billing.status_code in ('H','S','N','I')
GROUP BY
	Billing.customer_id,
	Billing.billing_project_id,
	Billing.purchase_order,
	Billing.company_id,
	Billing.profit_ctr_id,
	Billing.trans_source,
	Billing.billing_date,
	Billing.receipt_id,
	Billing.status_code

-- update the billing lines for status description and sort order
update #results
set status = case status_code
				WHEN 'I' THEN 'Invoiced'
				WHEN 'N' THEN 'Ready to Invoice'
				WHEN 'S' THEN 'Submitted'
				WHEN 'H' THEN 'Submitted on Hold'
				ELSE 'Unknown Status'
			END,
	sort_order = CASE status_code
					WHEN 'I' THEN 1
					WHEN 'N' THEN 2
					WHEN 'S' THEN 3
					ELSE 4
				END


	
-- Check each company, receipt and workorder
WHILE @db_count > 0
BEGIN
	SET ROWCOUNT 1
	SELECT @db_ref = db_ref FROM #tmp_db WHERE process_flag = 0
	UPDATE #tmp_db SET process_flag = 1 WHERE process_flag = 0
	SET ROWCOUNT 0

	SET @sql = 'INSERT #results '
		+ ' SELECT DISTINCT '
		+ ' Receipt.customer_id, '
		+ ' Receipt.billing_project_id, '
		+ ' Receipt.purchase_order, '
		+ ' Receipt.receipt_status, '
		+ ' ''Unknown'' AS status, '
		+ ' Receipt.company_id, '
		+ ' Receipt.profit_ctr_id, '
		+ ' ''Receipt'', '
		+ ' ''R'', '
		+ ' Receipt.receipt_date, '
		+ ' Receipt.receipt_id, '
		+ ' SUM(ReceiptPrice.total_extended_amt), '
        + ' 0 AS insr_amt, '
        + ' 0 AS ensr_amt, '
        + ' 0 AS total_amt, '
        + ' NULL AS invoice_code, '
        + ' NULL AS invoice_date, '
		+ ' 0 AS sort_order '
		+ ' FROM ' + @db_ref + 'Receipt Receipt ' 
		+ ' JOIN ' + @db_ref + 'ReceiptPrice ReceiptPrice '
		+ ' ON Receipt.company_id = ReceiptPrice.company_id '
		+ ' AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id '
		+ ' AND Receipt.receipt_id = ReceiptPrice.receipt_id '
		+ ' AND Receipt.line_id = ReceiptPrice.line_id '
		+ ' JOIN ' + @db_ref + 'Customer Customer '
		+ ' ON Receipt.customer_id = Customer.customer_id '
		+ ' AND (''' + @in_cust_name + ''' = ''%'' OR Customer.cust_name = ''' + @in_cust_name + ''') '
		+ ' AND (''' + @in_cust_type + ''' = ''%'' OR Customer.customer_type = ''' + @in_cust_type + ''') '
		+ ' JOIN ' + @db_ref + 'CustomerBilling CustomerBilling '
		+ ' ON Receipt.customer_id = CustomerBilling.customer_id '
		+ ' AND Receipt.billing_project_id = CustomerBilling.billing_project_id '
		+ ' AND CustomerBilling.status = ''A'' '
		+ ' AND (''' + @in_territory + ''' = ''%'' OR CustomerBilling.territory_code = ''' + @in_territory + ''') '
		+ ' AND (' + CONVERT(varchar(10), @in_billing_project_id) + ' =  -1 OR CustomerBilling.billing_project_id = ' + CONVERT(varchar(10), @in_billing_project_id) + ') '
		+ ' JOIN ' + @db_ref + 'CustomerBillingPO CustomerBillingPO '
		+ ' ON Receipt.customer_id = CustomerBillingPO.customer_id '
		+ ' AND Receipt.billing_project_id = CustomerBillingPO.billing_project_id '
		+ ' AND Receipt.purchase_order = CustomerBillingPO.purchase_order '
		+ ' AND CustomerBillingPO.status = ''A'' '
		+ ' AND IsNULL(CustomerBillingPO.po_amt,0) > 0 '
		+ ' AND (' + CONVERT(varchar(10), @in_billing_project_id) + ' =  -1 OR CustomerBillingPO.billing_project_id = ' + CONVERT(varchar(10), @in_billing_project_id) + ') '
		+ ' AND (''' + @in_purchase_order + ''' = ''%'' OR CustomerBillingPO.purchase_order = ''' + @in_purchase_order + ''') '
		+ ' WHERE (Receipt.customer_id BETWEEN ' + CONVERT(varchar(10),@customer_id_from) + ' AND ' + CONVERT(varchar(10),@customer_id_to) + ')'
		+ ' AND (' + CONVERT(varchar(10), @in_billing_project_id) + ' =  -1 OR Receipt.billing_project_id = ' + CONVERT(varchar(10), @in_billing_project_id) + ') '
		+ ' AND (''' + @in_purchase_order + ''' = ''%'' OR Receipt.purchase_order = ''' + @in_purchase_order + ''') '
		+ ' AND IsNULL(Receipt.purchase_order,'''') <> '''' '
		+ ' AND Receipt.receipt_status IN (''N'',''L'', ''U'', ''A'') '
		+ ' AND IsNULL(Receipt.submitted_flag,''F'') = ''F'' '
		+ ' GROUP BY '
		+ ' Receipt.customer_id, '
		+ ' Receipt.billing_project_id, '
		+ ' Receipt.purchase_order, '
		+ ' Receipt.company_id, '
		+ ' Receipt.profit_ctr_id, '
		+ ' Receipt.receipt_date, '
		+ ' Receipt.receipt_id, '
		+ ' Receipt.receipt_status '

	IF @debug = 1 print @sql

	EXECUTE (@sql)


        SET @sql = 'INSERT #results '
		+ ' SELECT '
		+ ' WorkOrderHeader.customer_id, '
		+ ' WorkOrderHeader.billing_project_id, '
		+ ' WorkOrderHeader.purchase_order, '
		+ ' IsNULL(WorkOrderHeader.workorder_status, ''N''), '
		+ ' ''Unknown'' AS status, '  
		+ ' ProfitCenter.company_id, '
		+ ' WorkOrderHeader.profit_ctr_id, '
		+ ' ''Work Order'', '
		+ ' ''W'', '
		+ ' WorkOrderHeader.start_date, '
		+ ' WorkOrderHeader.workorder_id, '
		+ ' IsNULL(WorkOrderHeader.total_price, 0), '
        + ' 0 AS insr_amt, '
        + ' 0 AS ensr_amt, '
        + ' 0 AS total_amt, '
        + ' NULL AS invoice_code, '
        + ' NULL AS invoice_date, '
		+ ' 0 AS sort  '
		+ ' FROM ' + @db_ref + 'WorkOrderHeader WorkOrderHeader ' 
		+ ' JOIN ' + @db_ref + 'ProfitCenter ProfitCenter '
		+ ' ON WorkOrderHeader.profit_ctr_id = ProfitCenter.profit_ctr_id '
		+ ' JOIN ' + @db_ref + 'Customer Customer '
		+ ' ON WorkOrderHeader.customer_id = Customer.customer_id '
		+ ' AND (''' + @in_cust_name + ''' = ''%'' OR Customer.cust_name like  ''' + @in_cust_name + ''') '
		+ ' AND (''' + @in_cust_type + ''' = ''%'' OR Customer.customer_type = ''' + @in_cust_type + ''') '
		+ ' JOIN ' + @db_ref + 'CustomerBilling CustomerBilling '
		+ ' ON WorkOrderHeader.customer_id = CustomerBilling.customer_id '
		+ ' AND WorkOrderHeader.billing_project_id = CustomerBilling.billing_project_id '
		+ ' AND CustomerBilling.status = ''A'' '
		+ ' AND (' + CONVERT(varchar(10), @in_billing_project_id) + ' =  -1 OR CustomerBilling.billing_project_id = ' + CONVERT(varchar(10), @in_billing_project_id) + ') '
		+ ' AND (''' + @in_territory + ''' = ''%'' OR CustomerBilling.territory_code = ''' + @in_territory + ''') '
		+ ' JOIN ' + @db_ref + 'CustomerBillingPO CustomerBillingPO '
		+ ' ON WorkOrderHeader.customer_id = CustomerBillingPO.customer_id '
		+ ' AND WorkOrderHeader.billing_project_id = CustomerBillingPO.billing_project_id '
		+ ' AND WorkOrderHeader.purchase_order = CustomerBillingPO.purchase_order '
		+ ' AND CustomerBillingPO.status = ''A'' '
		+ ' AND IsNULL(CustomerBillingPO.po_amt,0) > 0 '
		+ ' AND (' + CONVERT(varchar(10), @in_billing_project_id) + ' =  -1 OR CustomerBillingPO.billing_project_id = ' + CONVERT(varchar(10), @in_billing_project_id) + ') '
		+ ' AND (''' + @in_purchase_order + ''' = ''%'' OR CustomerBillingPO.purchase_order = ''' + @in_purchase_order + ''') '
		+ ' WHERE (WorkOrderHeader.customer_id BETWEEN ' + CONVERT(varchar(10),@customer_id_from) + ' AND ' + CONVERT(varchar(10),@customer_id_to) + ')'
		+ ' AND (' + CONVERT(varchar(10), @in_billing_project_id) + ' = -1 OR WorkOrderHeader.billing_project_id = ' + CONVERT(varchar(10), @in_billing_project_id) + ') '
		+ ' AND (''' + @in_purchase_order + ''' = ''%'' OR WorkOrderHeader.purchase_order = ''' + @in_purchase_order + ''') '
		+ ' AND IsNULL(WorkOrderHeader.purchase_order,'''') <> '''' '
		+ ' AND WorkOrderHeader.workorder_status IN (''N'',''C'',''D'',''A'') '
		+ ' AND IsNULL(WorkOrderHeader.submitted_flag,''F'') = ''F'' '
	

	IF @debug = 1 print @sql

	EXECUTE (@sql)

	SET @db_count = @db_count - 1
END

-- now update the status and sort order for receipt

update #results
set status = CASE status_code 
				WHEN 'N' THEN 'New'
				WHEN 'L' THEN 'Lab'
				WHEN 'U' THEN 'Unloading'
				WHEN 'A' THEN 'Accepted' 
				ELSE 'Unknown Status' 
			END ,
    sort_order = CASE status_code 
					WHEN 'N' THEN 9 
					WHEN 'L' THEN 8 
					WHEN 'U' THEN 6 
					WHEN 'A' THEN 5 
					ELSE 10 
				END
where record_source = 'Receipt'




-- now update the status and sort order for workorder

update #results
set status = CASE status_code 
				WHEN  'N'  THEN  'New' 
				WHEN  'H'  THEN  'Hold' 
				WHEN  'C'  THEN  'Completed' 
				WHEN  'D'  THEN  'Dispatched' 
				WHEN  'P'  THEN  'Priced' 
				WHEN  'A'  THEN  'Accepted'  
				ELSE  'Unknown Status'  
			END,

    sort_order = CASE status_code 
					WHEN  'N'  THEN 9  
					WHEN  'C'  THEN 7  
					WHEN  'D'  THEN 8  
					WHEN  'P'  THEN 6  
					WHEN  'A'  THEN 5 
					ELSE 10 
				END  
where record_source = 'Work Order'

UPDATE #results SET total_amount = amount + insr_amount + ensr_amount




IF @debug = 1 
BEGIN
	SELECT * FROM #results
END

-- IF @debug = 1 print 'Selecting #results'
-- IF @debug = 1 Select * FROM #results

-- Get the PO amounts for the results
INSERT #po_amt
SELECT 
	#results.customer_id,
	'Unknown' AS cust_name,
	#results.billing_project_id,
	'Unknown' AS project_name,
	#results.purchase_order,
	0 AS po_amt,
	SUM(ISNULL(#results.amount,0)) AS po_sum,
    SUM(insr_amount) AS po_insr_amt,
    SUM(ensr_amount) AS po_ensr_amt,
    SUM(total_amount)  AS po_tot_amt,
	CONVERT(money,0) AS po_remains,
	CONVERT(money,0) AS po_percent_used,
	0 AS warning_percent,
	NULL AS added_by,
	NULL AS date_added,
	NULL AS start_date,	NULL AS expiration_date,
	'' AS warning_message
FROM #results
group by customer_id, billing_project_id, purchase_order

-- update for customer name
update #po_amt 
set cust_name = c.cust_name
from #po_amt p, Customer c
where p.customer_id = c.customer_id

-- update billing info
update #po_amt
set project_name = cb.project_name
from #po_amt p, Customerbilling cb
where p.customer_id = cb.customer_id
and   p.billing_project_id = cb.billing_project_id

-- update po info
update #po_amt
set po_amt = cbp.po_amt,	
    warning_percent = cbp.warning_percent,
    added_by = cbp.added_by,
	date_added = cbp.date_added,
	start_date = cbp.start_date,
	expiration_date = cbp.expiration_date
from #po_amt p, customerbillingpo cbp
where p.customer_id = cbp.customer_id
and   p.billing_project_id = cbp.billing_project_id
and   p.purchase_order = cbp.purchase_order


-- insert records for purchase orders with no activities ( no records in results)
INSERT #po_amt
SELECT cbo.customer_id,
	c.cust_name,
	cbo.billing_project_id,
	cb.project_name,
	cbo.purchase_order,
	cbo.po_amt,
	0 AS po_sum,
    0 AS po_insr_amt,
    0 AS po_ensr_amt,
    0 AS po_tot_amt,
	0 AS po_remains,
	0 AS po_percent_used,
	cbo.warning_percent,
	cbo.added_by,
	cbo.date_added,
	cbo.start_date,    cbo.expiration_date,
	'No activity' AS warning_message
from CustomerBillingPO cbo
inner join Customer c on c.customer_id = cbo.customer_id
inner join CustomerBilling cb on cb.customer_id = cbo.customer_id
      and cb.billing_project_id = cbo.billing_project_id
      and cb.status = 'A'
where (c.customer_id BETWEEN @customer_id_from AND @customer_id_to)
	AND (@in_cust_name = '%' OR c.cust_name like @in_cust_name)
	AND (@in_cust_type = '%' OR c.customer_type = @in_cust_type)
AND (@in_billing_project_id = -1 OR cb.billing_project_id = @in_billing_project_id)
	AND (@in_territory = '%' OR cb.territory_code = @in_territory)
AND (@in_billing_project_id = -1 OR cbo.billing_project_id = @in_billing_project_id)
AND (@in_purchase_order = '%' OR cbo.purchase_order = @in_purchase_order) 
and not exists ( select 1 from #results r where cbo.customer_id = r.customer_id
                 and cbo.billing_project_id = r.billing_project_id 
                 and cbo.purchase_order = r.purchase_order )

-- create summary of po information accross billing projects
INSERT #po_summary
SELECT customer_id,
	purchase_order,
	MAX(po_amt),
	SUM(po_sum),
    SUM(po_insr_amt),
    SUM(po_ensr_amt),
    SUM(po_total_amt),
	0 AS po_remains,
	0 AS po_percent_used,
	MAX(warning_percent),
	MAX(expiration_date),
	NULL AS warning_message
FROM #po_amt
GROUP BY customer_id, purchase_order

IF @debug = 1 PRINT 'selecting for PO: CERT OF DISPOSAL1'
IF @debug = 1 SELECT * FROM #results WHERE purchase_order = 'CERT OF DISPOSAL1'
IF @debug = 1 SELECT * FROM #po_amt WHERE purchase_order = 'CERT OF DISPOSAL1'

-- Identify how much is left and the percentage used
UPDATE #po_summary SET 
po_remains = CASE 
	WHEN po_amt = 0 THEN NULL 
	WHEN po_amt >= po_total_amt THEN po_amt - po_total_amt
	WHEN po_total_amt > po_amt THEN NULL
	ELSE po_total_amt - po_amt 
	END ,
po_percent_used = CASE 
	WHEN po_amt = 0 THEN NULL 
	WHEN po_total_amt = 0 THEN 0
	WHEN po_amt >= po_total_amt THEN (po_total_amt * 100) / po_amt
	WHEN po_total_amt> po_amt THEN 100
	ELSE 100 
	END

-- Set the warning message
UPDATE #po_summary 
SET warning_message = CASE
	WHEN po_amt IS NULL OR po_amt = 0 THEN ''
	WHEN po_amt = po_total_amt AND po_amt > 0 THEN '**PO Complete'
	WHEN po_amt < po_total_amt THEN '**PO Exceeded'
	WHEN po_percent_used < 100 AND  warning_percent > 0 and po_percent_used >= warning_percent THEN '**About to Exceed PO Amt'
	ELSE '' END
UPDATE #po_summary 
SET #po_summary.warning_message = CASE
	WHEN #po_summary.expiration_date < getdate() AND #po_summary.warning_message <> '' THEN #po_summary.warning_message + ' and Expired**'
	WHEN #po_summary.expiration_date < getdate() AND #po_summary.warning_message = '' THEN '**Expired**'
	WHEN DATEADD(m, 1, getdate()) >= #po_summary.expiration_date AND #po_summary.warning_message <> '' THEN #po_summary.warning_message + ' and About to Expire**'
 	WHEN DATEADD(m, 1, getdate()) >= #po_summary.expiration_date AND #po_summary.warning_message = '' THEN '**About to Expire**'
	WHEN #po_summary.warning_message <> '' THEN #po_summary.warning_message + '**'
	ELSE #po_summary.warning_message
	END




-- now insert dummy in results so that it will join
insert #results
select p.customer_id,
	p.billing_project_id,
	p.purchase_order,
	'Z' AS status_code,
	'No Activity' AS status,
	NULL AS company_id	,
	NULL AS profit_ctr_id,
	NULL AS record_source,
	NULL AS trans_source,
	NULL AS source_date	,
	NULL AS source_id,
	0 AS amount,
	0 AS insr_amount,
	0 AS ensr_amount,
	0 AS total_amount ,
	NULL AS invoice_code ,
	NULL AS invoice_date ,
	1 AS sort
from #po_amt p
where not exists (  select 1 from #results r where p.customer_id = r.customer_id
                 and p.billing_project_id = r.billing_project_id 
                 and p.purchase_order = r.purchase_order )


       

-- Return results FOR Summary
IF @report_type = 1
SELECT 	a.customer_id,
	a.cust_name,
	a.billing_project_id,
	a.project_name,
	a.purchase_order,
	a.po_amt,
	s.po_sum,
    s.po_insr_amt,
    s.po_ensr_amt,
    s.po_total_amt,
	s.po_remains,
	s.po_percent_used,
	a.warning_percent,
	a.added_by,
	a.date_added,
	a.start_date,
	a.expiration_date,
	s.expiration_date,
	s.warning_message,
	s.warning_percent,
	s.po_amt
FROM  #po_amt a,  #po_summary s
where a.customer_id = s.customer_id
and   a.purchase_order = s.purchase_order

-- Return results for Detail
ELSE
SELECT 	a.customer_id,
	a.cust_name,
	a.billing_project_id,
	a.project_name,
	a.purchase_order,
	a.po_amt,
	s.po_sum,
	s.po_insr_amt,
	s.po_ensr_amt,
	s.po_total_amt,
	s.po_remains,
	s.po_percent_used,
	a.warning_percent,
	a.added_by,
	a.date_added,
	a.start_date,
	a.expiration_date,
	s.expiration_date,
	s.warning_message,
	s.warning_percent,
	s.po_amt,
	r.status_code,
	r.status,
	r.company_id,
	r.profit_ctr_id,
	r.record_source,
	r.trans_source,
	r.source_date,
	r.source_id,
	r.amount,
	r.insr_amount,
	r.ensr_amount,
	r.total_amount,
	r.invoice_code,
	r.invoice_date,
	r.sort_order
FROM #results r, #po_amt a, #po_summary s
where r.customer_id = a.customer_id
  AND r.billing_project_id = a.billing_project_id
  AND r.purchase_order = a.purchase_order
  AND a.customer_id = s.customer_id
  AND a.purchase_order = s.purchase_order

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_po_accumulate] TO [EQAI]
    AS [dbo];

