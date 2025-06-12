
CREATE PROCEDURE [dbo].[sp_flash_report_outstanding]  
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime 
,	@cust_id_from	int 
,	@cust_id_to		int
,	@territory_code	char(2)
,	@debug_flag		int = 0
AS
/****************************************************************************************************
This SP summarizes the revenue from all stages of work orders.  Work Orders that have not yet
been priced are calculated as if they have been priced

Filename:	L:\Apps\SQL\EQAI\sp_flash_report_outstanding.sql
PB Object(s):	d_rpt_flash_report_outstanding

11/27/2000 SCC	Created - Copied from Flash Detail after improvements
01/30/2001 JDB	Changed profit_ctr_name to varchar(50)
12/30/2004 SCC	Changed Ticket to Billing
04/16/2007 SCC	Changed to use workorderheader.submitted_flag and CustomerBilling.territory_code
05/10/2007 JDB	Changed to use Billing.status_code
11/09/2007  rg  changed to exclude submitted and invoiced workorders
11/13/2007 RG   changed to add back invoiced and submitted 
01/15/2008 LJT  Updated to display adjustments separately on the report. 
                Uncommented the selection of those that are submitted but not invoiced.
01/22/2008 LJT  Added check of Date_submitted to identify adjustments.
02/21/2008 RG   removed submitted and invoiced and no invoice 0$ categories
09/24/2010 SK	Moved to run on Plt_AI, added input arg Company_ID
				Changed the joins to join to the selected company 
10/01/2010 SK	Modified the report to run for:
				1. All Companies- all profit centers
				2. selected company- all profit centers
				3. a facility : selected company-selected profit center	
01/12/2012 SK	Changed to use the new WorkOrderTypeHeader.workorder_type_id (GL standardization project)

sp_flash_report_outstanding 14, -1, '10/01/2007 00:00','10/31/2007 23:59', 1, 999999, '99', 1
****************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@profit_ctr_name	varchar(50)
,	@processcount		int
,	@record_ID			int

DECLARE @company_profit_ctr TABLE(
	record_id		int		identity
,	company_ID		int
,	Profit_ctr_id	int
,	process_flag	tinyint)

-- Create the revenue results table; child SP depends on this table
CREATE TABLE #tmp_revenue (
	revenue				money		NULL
,	workorder_status	char(1)		NULL
,	billing_status		char(1)		NULL
,	account_desc		varchar(40) NULL
,	customer_id			int			NULL
,	workorder_id		int			NULL
,	end_date			datetime	NULL
,	invoice_date		datetime	NULL
,	pricing_method		char(1)		NULL
,	fixed_price			char(1)		NULL
,	company_id			int			NULL
,	profit_ctr_id		int			NULL
)

-- Insert the already priced workorders

-- only priced and aaccepted workorders only based on precenteral invoice version rg 111307 
INSERT #tmp_revenue (
	revenue,
	workorder_status,
	billing_status,
	account_desc,
	customer_id,
	workorder_id,
	end_date,
	pricing_method, 
	fixed_price,
	company_id,
	profit_ctr_id )
SELECT SUM(woh.total_price) AS revenue, 
	CASE WHEN ISNULL(woh.submitted_flag, 'F') = 'T' 
		THEN 'X'
		ELSE woh.workorder_status
		END AS workorder_status,
	null as billing_status ,
	--gl.account_desc, 
	woth.account_desc,
	woh.customer_id, 
	woh.workorder_id, 
	woh.end_date,
	'A',
	woh.fixed_price_flag,
	woh.company_id,
	woh.profit_ctr_ID
FROM WorkOrderHeader woh
INNER JOIN WorkOrderTypeHeader WOTH
	ON WOTH.workorder_type_id = woh.workorder_type_id
--INNER JOIN GLAccount gl 
--	ON gl.account_type = woh.workorder_type
--	AND gl.account_class = 'O'
--	AND gl.company_id = woh.company_id
--	AND gl.profit_ctr_id = woh.profit_ctr_ID
INNER JOIN CustomerBilling cb 
	ON cb.customer_id = woh.customer_id
	AND cb.billing_project_id = ISNULL(woh.billing_project_id, 0)
	AND (@territory_code = '99' OR cb.territory_code = @territory_code)
WHERE (@company_id = 0 OR woh.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
	AND woh.workorder_status IN ('A', 'P')
	AND ISNULL(woh.submitted_flag, 'F') = 'F' 
	AND woh.end_date BETWEEN @date_from AND @date_to
	AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
	--AND gl.account_class = 'O' 
	--AND gl.profit_ctr_id = @profit_ctr_id
	--AND (@territory_code = '99' OR cb.territory_code = @territory_code)
GROUP BY CASE WHEN ISNULL(woh.submitted_flag, 'F') = 'T' 
		THEN 'X'
		ELSE woh.workorder_status
		END, 
	woth.account_desc, 
	woh.company_id,
	woh.profit_ctr_ID,
	woh.customer_id, 
	woh.workorder_id,
	woh.end_date,
	woh.fixed_price_flag
	
 union

SELECT SUM(woh.total_price) AS revenue, 
	CASE WHEN ISNULL(woh.submitted_flag, 'F') = 'T' 
		THEN 'X'
		ELSE woh.workorder_status
		END AS workorder_status,
	billing_status = (SELECT MIN(status_code) 
						FROM Billing 
						WHERE Billing.company_id = woh.company_id
						AND Billing.profit_ctr_id = woh.profit_ctr_ID
						AND Billing.receipt_id = woh.workorder_ID
						AND Billing.trans_source = 'W'),
	--gl.account_desc,
	woth.account_desc, 
	woh.customer_id, 
	woh.workorder_id, 
	woh.end_date,
	'A',
	woh.fixed_price_flag,
	woh.company_id,
	woh.profit_ctr_ID
FROM WorkOrderHeader woh
INNER JOIN WorkOrderTypeHeader WOTH
	ON WOTH.workorder_type_id = woh.workorder_type_id
--INNER JOIN GLAccount gl 
--	ON gl.account_type = woh.workorder_type
--	AND gl.account_class = 'O'
--	AND gl.company_id = woh.company_id
--	AND gl.profit_ctr_id = woh.profit_ctr_ID
INNER JOIN CustomerBilling cb 
	ON cb.customer_id = woh.customer_id
	AND cb.billing_project_id = ISNULL(woh.billing_project_id, 0)
	AND (@territory_code = '99' OR cb.territory_code = @territory_code)
WHERE (@company_id = 0 OR woh.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
	AND woh.workorder_status IN ('A', 'P')
	AND ISNULL(woh.submitted_flag, 'F') = 'T' 
	AND woh.end_date BETWEEN @date_from AND @date_to
	AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
	--AND gl.account_class = 'O' 
	--AND gl.profit_ctr_id = @profit_ctr_id
	--AND (@territory_code = '99' OR cb.territory_code = @territory_code)
	AND NOT EXISTS ( select 1 from Billing b where woh.workorder_id = b.receipt_id
	                         and woh.company_id = b.company_id
	                         and woh.profit_ctr_id = b.profit_ctr_id
							 and b.trans_source = 'W'
							 and b.status_code = 'I' )
GROUP BY CASE WHEN ISNULL(woh.submitted_flag, 'F') = 'T' 
		THEN 'X'
		ELSE woh.workorder_status
		END, 
	woth.account_desc, 
	woh.company_id,
	woh.profit_ctr_ID,
	woh.customer_id, 
	woh.workorder_id,
	woh.end_date,
	woh.fixed_price_flag

-- Update the invoice date
UPDATE #tmp_revenue SET #tmp_revenue.invoice_date = Billing.invoice_date
FROM Billing
WHERE #tmp_revenue.workorder_id = Billing.receipt_id
AND Billing.company_id = #tmp_revenue.company_id
AND Billing.profit_ctr_id = #tmp_revenue.profit_ctr_id
AND Billing.trans_source = 'W'

IF @debug_flag = 1 SELECT * FROM #tmp_revenue

-- Calculate the forecasted amount
IF @company_id > 0 AND @profit_ctr_id > -1
	-- Calculate the forecasted amount for selected company-selected profit center
	EXEC sp_flash_report_forecast 
		@company_id,
		@profit_ctr_id,
		@date_from,
		@date_to,
		@cust_id_from,
		@cust_id_to, 
		@territory_code,
		@debug_flag
ELSE
BEGIN
	IF @company_id > 0 AND @profit_ctr_id = -1
	BEGIN
		-- Calculate the forecasted amount for selected company-all profit centers
		INSERT INTO @company_profit_ctr
		SELECT 
			company_id
		,	profit_ctr_id
		,	0
		FROM ProfitCenter
		WHERE ProfitCenter.status = 'A'
		AND ProfitCenter.company_ID = @company_id
		ORDER BY company_id, profit_ctr_id asc
		SET @processcount = @@ROWCOUNT
	END
	ELSE
	BEGIN
		-- calculate the forecasted amount for each company/ each profit_ctr(all active ones)
		INSERT INTO @company_profit_ctr
		SELECT 
			company_id
		,	profit_ctr_id
		,	0
		FROM ProfitCenter
		WHERE ProfitCenter.status = 'A'
		ORDER BY company_id, profit_ctr_id asc
		SET @processcount = @@ROWCOUNT
	END
	
	IF @debug_flag = 1 
	BEGIN
		PRINT 'Selecting from @company_profit_ctr'
		SELECT * FROM @company_profit_ctr
	END
	
	IF @processcount > 0
	BEGIN
		SELECT @record_ID = IsNull(MIN(record_id), 0) FROM @company_profit_ctr WHERE process_flag = 0
		WHILE @record_ID <> 0
		BEGIN
			SELECT
				@company_id = company_id
			,	@profit_ctr_id = profit_ctr_id
			FROM @company_profit_ctr WHERE record_id = @record_ID
			
			-- exec the child sp
			EXEC sp_flash_report_forecast @company_id, @profit_ctr_id, @date_from, @date_to, @cust_id_from, @cust_id_to, @territory_code, @debug_flag
			
			-- update this record as processed
			UPDATE @company_profit_ctr SET process_flag = 1 WHERE record_id = @record_ID
			-- move on to next
			SELECT @record_ID = IsNull(MIN(record_id), 0) FROM @company_profit_ctr WHERE process_flag = 0
		END
	END
END

---- Overwrite the workorder status to 'J' for adjustments
update #tmp_revenue set workorder_status = 'J' 
from #tmp_revenue t, workorderheader wh 
where t.workorder_id = wh.workorder_id 
and t.company_id = wh.company_id
and t.profit_ctr_id = wh.profit_ctr_id
and date_submitted is not null
and t.workorder_status <> 'X'
and 0 < (select count(*) from AdjustmentDetail AD  
		   where ad.receipt_id = t.workorder_id 
		   and ad.company_id = t.company_id
		   and ad.profit_ctr_id = t.profit_ctr_id
		   and ad.trans_source = 'W'
		   and invoice_id is not null)

----Update Billing Status to be 'Z' for Submitted not to be invoiced $0 workorders
update #tmp_revenue set billing_status = 'Z' 
from #tmp_revenue t
Where workorder_status = 'X'
and revenue = 0
and 1 > (select count(*) from billing b  
		   where b.receipt_id = t.workorder_id 
		   and b.company_id = t.company_id
		   and b.profit_ctr_id = t.profit_ctr_id
		   and b.trans_source = 'W')

-- Return the results
SELECT SUM(t.revenue) AS revenue, 
	t.workorder_status, 
	t.billing_status, 
	t.account_desc, 
	t.customer_id, 
	t.workorder_id, 
	t.end_date, 
	t.invoice_date, 
	t.pricing_method, 
	t.fixed_price,
	t.company_id,
	t.profit_ctr_id, 
	PC.profit_ctr_name AS profit_ctr_name,
	Company.company_name AS Company_name
FROM #tmp_revenue t
JOIN ProfitCenter PC
	ON PC.company_ID = t.company_id
	AND PC.profit_ctr_ID = t.profit_ctr_id
JOIN Company
	ON Company.company_id = t.company_id
WHERE t.billing_status is null or t.billing_status not in ( 'I','Z')
GROUP BY 
	t.workorder_status, 
	t.billing_status,
	t.account_desc,
	t.customer_id,
	t.workorder_id,
	t.end_date, 
	t.invoice_date,
	t.pricing_method,
	t.fixed_price,
	t.company_id, 
	t.profit_ctr_id, 
	PC.profit_ctr_name, 
	Company.company_name
	


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_flash_report_outstanding] TO [EQAI]
    AS [dbo];

