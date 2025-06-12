
create procedure sp_process_receipt_line_weight
	@debug int = 0
as

/*
>>> Rich Grenwick 10/8/2010 1:20 PM >>>

Here is what I understand for the line_weight calculation (in order of precidence).  This will be used to supplement container_weight where it isnt filled in (which is most places).
 
/* 1) if it is a trip -> line_weight is net_weight */
/*2) if manifest_unit is LBS, TONS, Metric TONS, KG -> line_weight is the converted value of net_weight */
/*3) if it is a bulk and only 1 line -> line_weight is net_weight */
/*4) if ReceiptPrice.BillUnit is LBS, TONS, Metric TONS, KG -> line_weight is the converted value of net_weight */
/*5) if bulk and more than 1 line ->  
         if net_weight is the same on all lines -> line_weight is net_weight
         if net_weight is different on lines -> line_weight is SUM(net_weight) */
/*6) if non-bulk and no container weights, no net_weight, etc... calculate the value externally, this will not be populated by the nightly stored procedure  */
 
We will create a new table called TaskRunLog (or somesuch) that will have an id, date, and description so we know when the job was last run to fill in the line_weights.  
*/

create table #weight_table
(
	company_id int,
	profit_ctr_id int,
	receipt_id int,
	line_id int,
	line_weight float,
	calc_method varchar(100),
	conversion_factor float
)

/* 1) if it is a trip -> line_weight is net_weight */
INSERT INTO #weight_table (company_id, profit_ctr_id, receipt_id, line_id, calc_method, line_weight, conversion_factor)
SELECT r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, 'trip_weight_calc', net_weight, 1 FROM Receipt r 
	INNER JOIN BillingLinkLookup bll ON r.receipt_id = bll.receipt_id
		AND r.company_id = bll.company_id
		AND r.profit_ctr_id = bll.profit_ctr_id
	INNER JOIN WorkOrderHeader woh ON bll.source_id = woh.workorder_ID
		AND bll.source_company_id = woh.company_id
		AND bll.source_profit_ctr_id = woh.profit_ctr_ID
		AND woh.trip_id IS NOT NULL
		
/*2) if manifest_unit is LBS, TONS, Metric TONS, KG -> line_weight is the converted value of net_weight */		
/* UPDATE: net_weight is already converted to lbs. */
INSERT INTO #weight_table (company_id, profit_ctr_id, receipt_id, line_id, calc_method, line_weight, conversion_factor)
SELECT r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, 'manifest_lbs_convert', net_weight, bu.pound_conv FROM Receipt r 
	INNER JOIN BillUnit bu ON r.manifest_unit = bu.manifest_unit
WHERE r.manifest_unit IN ('K','M','P','T')
AND NOT EXISTS (
	SELECT 1 FROM #weight_table wt
		WHERE r.receipt_id = wt.receipt_id
		AND r.company_id = wt.company_id
		AND r.profit_ctr_id = wt.profit_ctr_id
		AND r.line_id = wt.line_id
)


/*3) if it is a bulk and only 1 line -> line_weight is net_weight */
INSERT INTO #weight_table (company_id, profit_ctr_id, receipt_id, line_id, calc_method, line_weight, conversion_factor)
SELECT r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, 'one_bulk_line', net_weight, 1 FROM Receipt r 
WHERE r.bulk_flag = 'T' 
AND 1 = (
	SELECT COUNT(*) FROM Receipt r2
		WHERE r.receipt_id = r2.receipt_id
		AND r.company_id = r2.company_id
		AND r.profit_ctr_id = r2.profit_ctr_id
	
)
AND NOT EXISTS (
	SELECT 1 FROM #weight_table wt
		WHERE r.receipt_id = wt.receipt_id
		AND r.company_id = wt.company_id
		AND r.profit_ctr_id = wt.profit_ctr_id
		AND r.line_id = wt.line_id
)

/*4) if ReceiptPrice.BillUnit is LBS, TONS, Metric TONS, KG -> line_weight is the converted value of net_weight 
UPDATE: net_weight is already converted to lbs.
*/
INSERT INTO #weight_table (company_id, profit_ctr_id, receipt_id, line_id, calc_method, line_weight, conversion_factor)
SELECT r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, 'ReceiptPrice.bill_unit convertable', net_weight, bu.pound_conv FROM Receipt r 
	INNER JOIN BillUnit bu ON r.bill_unit_code = bu.bill_unit_code
INNER JOIN ReceiptPrice rp ON
	r.receipt_id = rp.receipt_id
	AND r.company_id = rp.company_id
	AND r.profit_ctr_id = rp.profit_ctr_id
	AND r.line_id = rp.line_id
	AND r.bill_unit_code IN ('KG', 'LBS', 'MTON', 'TONS')
	

/*5) if bulk and more than 1 line ->  
         if net_weight is the same on all lines -> line_weight is net_weight
         if net_weight is different on lines -> line_weight is SUM(net_weight) */
INSERT INTO #weight_table (company_id, profit_ctr_id, receipt_id, line_id, calc_method, line_weight, conversion_factor)
SELECT r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, 'many_bulk_line_same_value', net_weight, 1 FROM Receipt r 
WHERE r.bulk_flag = 'T' 
AND 1 < (
	SELECT COUNT(*) FROM Receipt r2
		WHERE r.receipt_id = r2.receipt_id
		AND r.company_id = r2.company_id
		AND r.profit_ctr_id = r2.profit_ctr_id
)
AND 1 = (
	SELECT COUNT(DISTINCT net_weight) FROM Receipt r2
		WHERE r.receipt_id = r2.receipt_id
		AND r.company_id = r2.company_id
		AND r.profit_ctr_id = r2.profit_ctr_id	
)

/*5) if bulk and more than 1 line ->  
         if net_weight is the same on all lines -> line_weight is net_weight
         if net_weight is different on lines -> line_weight is SUM(net_weight) */
INSERT INTO #weight_table (company_id, profit_ctr_id, receipt_id, line_id, calc_method)
SELECT r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, 'many_bulk_line_different_value' FROM Receipt r 
WHERE r.bulk_flag = 'T' 
AND 1 < (
	SELECT COUNT(*) FROM Receipt r2
		WHERE r.receipt_id = r2.receipt_id
		AND r.company_id = r2.company_id
		AND r.profit_ctr_id = r2.profit_ctr_id
)
AND 1 < (
	SELECT COUNT(DISTINCT net_weight) FROM Receipt r2
		WHERE r.receipt_id = r2.receipt_id
		AND r.company_id = r2.company_id
		AND r.profit_ctr_id = r2.profit_ctr_id	
)

/*
manifest_lbs_convert
trip_weight_calc
one_bulk_line
many_bulk_line_different_value
many_bulk_line_same_value
ReceiptPrice.bill_unit convertable 
*/

UPDATE #weight_table SET line_weight = net_weight
	FROM Receipt r
	WHERE r.receipt_id = #weight_table.receipt_id
		AND r.company_id = #weight_table.company_id
		AND r.profit_ctr_id = #weight_table.profit_ctr_id
		AND r.line_id = #weight_table.line_id
	AND #weight_table.calc_method IN (
		'many_bulk_line_same_value',
		'trip_weight_calc')


SELECT	wt.receipt_id,
		wt.company_id,
		wt.profit_ctr_id,
		count(wt.receipt_id) as total_lines
INTO #receipt_line_totals	
 FROM #weight_table wt WHERE
	wt.calc_method = 'many_bulk_line_different_value'
GROUP BY
wt.receipt_id,
		wt.company_id,
		wt.profit_ctr_id
	
	
UPDATE #weight_table SET line_weight = avg_weight
	FROM (
		SELECT SUM(r.net_weight) / total_lines as avg_weight,
		r.receipt_id,
		r.company_id,
		r.profit_ctr_id
		FROM Receipt r
		INNER JOIN #receipt_line_totals rt
			ON r.receipt_id = rt.receipt_id
			and r.company_id = rt.company_id
			and r.profit_ctr_id = rt.profit_ctr_id
		GROUP BY
			r.receipt_id,
			r.company_id,
			r.profit_ctr_id,
			total_lines
	) tbl
	INNER JOIN #weight_table wt ON tbl.receipt_id = wt.receipt_id
	AND tbl.company_id = wt.company_id
	AND tbl.profit_ctr_id = wt.profit_ctr_id
	AND wt.calc_method IN ('many_bulk_line_different_value')
	
	

UPDATE #weight_table SET line_weight = r.quantity * bu.pound_conv,
		calc_method = 'one_bulk_line - no weights, but unit and quantity'
		FROM Receipt r
		INNER JOIN #weight_table wt
			ON r.receipt_id = wt.receipt_id
			and r.company_id = wt.company_id
			and r.profit_ctr_id = wt.profit_ctr_id
			AND r.line_id = wt.line_id
		INNER JOIN BillUnit bu ON r.bill_unit_code = bu.bill_unit_code
		WHERE 
		wt.calc_method IN ('one_bulk_line')
		AND r.net_weight IS NULL
		AND r.quantity IS NOT NULL
		AND r.bill_unit_code IN ('KG', 'LBS', 'MTON', 'TONS')


declare @yesterday as datetime = DATEADD(d,-1, cast(convert(varchar(20), getdate(), 101) as datetime))
declare @last_run_date datetime
SELECT @last_run_date = MAX(run_date) from TaskRunLog WHERE task_run_name = 'process_receipt_line_weight'

SET @last_run_date = COALESCE(@last_run_date, @yesterday)

UPDATE Receipt SET line_weight = wt.line_weight
	FROM #weight_table wt
	WHERE Receipt.receipt_id = wt.receipt_id
			and Receipt.company_id = wt.company_id
			and Receipt.profit_ctr_id = wt.profit_ctr_id
			AND Receipt.line_id = wt.line_id
			AND wt.line_weight IS NOT NULL
			AND (Receipt.line_weight IS NULL OR Receipt.date_modified >= @last_run_date)

INSERT INTO TaskRunLog(run_date, task_run_name) VALUES (getdate(), 'process_receipt_line_weight')

--SELECT * FROM TaskRunLog
--SELECT * FROM 	Receipt where line_weight is not null


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_process_receipt_line_weight] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_process_receipt_line_weight] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_process_receipt_line_weight] TO [EQAI]
    AS [dbo];

