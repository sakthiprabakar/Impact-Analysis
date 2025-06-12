CREATE PROCEDURE sp_cum_treatment_sales
	@company_id	int
,	@year		int 
AS

/****************************************************************************
Cumulative Sales by Treatment Report (r_cum_treatment_sales)

This stored procedure is used for YDT Net Revenue Summary Report
It uses one temp table #net_sum and one permanent table
net_sum_crosstab.  First, data is generated in summary form
and inserted into #net_sum table.  Then data is broken by month
and inserted into net_sum_crosstab table. The data is grouped by
customer id.
Loaded to PLT_AI

PB Object(s):	r_cum_treatment_sales
				w_report_master_finance_ytd

02-??-1996	Olga	Created
01-30-2001	JDB		Changed profit_ctr_name to varchar(50)
09-25-2002	JDB		Modified to use the profit_ctr_id field in the
04-28-2003	LJT		Added outer join to receipt to pick up  treatment id still 
					need wo from ticket treatment table
07-15-2004	JDB		Added update statement to get correct treatment description
					based on the treatment from the receipt table.
12-14-2004	JDB		Changed Ticket to Billing
12-02-2005	SCC		Changed to sum quantity * price instead of waste_extended_amt
07/27/07	rg		revised for quoteheader quotedetail tsdfapproval changes
12/03/2010	SK		Modified to run for selected/all companies, modified to use table
					work_cum_sales_crosstab
					Moved to Plt_AI
03/11/2011	SK		Wrapped IsNull around monthly totals

sp_cum_treatment_sales 14, 2010
****************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


CREATE TABLE #cum_sales (
	month			int			NULL,
	revenue			money		NULL,
	quantity		int			NULL,
	company_id		int			NULL,
	profit_ctr_id	int			NULL,
	treatment_id	int			NULL,
	treatment_desc	varchar(40)	NULL
	)

INSERT INTO #cum_sales
SELECT	
	month_number	= DATEPART(month, b.invoice_date),
	revenue			= SUM(IsNull((Convert(money, b.quantity) * Convert(money, b.price)), 0.00)),
	quantity		= SUM(IsNull(b.quantity, 0.00)),
	b.company_id,
	b.profit_ctr_id,
	IsNull(r.treatment_id, -1),
	IsNull(tr.treatment_desc, 'Unknown')
FROM Billing b 
inner join company c 
	on (b.company_id = c.company_id)  
inner join profitcenter pc 
	on b.profit_ctr_id = pc.profit_ctr_id
	and b.company_id = pc.company_id
inner join profilequoteapproval a 
	on (a.approval_code = b.approval_code
    and a.company_id = b.company_id
    and a.profit_ctr_id = b.profit_ctr_id)
inner join profile p 
	on p.profile_id = a.profile_id
	AND p.curr_status_code = 'A' 
inner join treatment tr 
	on (a.treatment_id = tr.treatment_id
    AND a.company_id = tr.company_id
	AND a.profit_ctr_id = tr.profit_ctr_id )  	
left outer join receipt r 
	on (b.profit_ctr_id = r.profit_ctr_id
	and b.receipt_id = r.receipt_id
	and b.company_id = r.company_id
	and b.line_id = r.line_id )
WHERE DATEPART(year, b.invoice_date) = @year
	AND ( @company_id = 0 OR b.company_id = @company_id )
	AND b.status_code = 'I'
	AND b.void_status = 'F'
	AND b.trans_type = 'D'
GROUP BY DATEPART(month, b.invoice_date),
	b.company_id,
	b.profit_ctr_id,
	r.treatment_id,
	tr.treatment_desc
ORDER BY b.company_id, b.profit_ctr_id, r.treatment_id

-- Fix treatment description (it needs a straight join to receipt table, but can't in the select above) 7/15/04 JDB
UPDATE #cum_sales 
SET treatment_desc = IsNull(tr.treatment_desc, 'Unknown')
FROM Treatment tr 
WHERE #cum_sales.treatment_id = tr.treatment_id
AND #cum_sales.company_id = tr.company_id
AND #cum_sales.profit_ctr_id = tr.profit_ctr_id

DELETE FROM work_cum_sales_crosstab
/*  uses customer_id and name instead of treatment_id and desc  */

INSERT INTO work_cum_sales_crosstab (
	company_id,
	profit_ctr_id,
	customer_id,
	customer_name,
	January,
	January_q)
SELECT company_id,
	profit_ctr_id,
	treatment_id,
	treatment_desc,
	revenue,
	quantity
FROM #cum_sales WHERE month = 1

INSERT INTO work_cum_sales_crosstab (
	company_id,
	profit_ctr_id,
	customer_id,
	customer_name,
	February,
	February_q)
SELECT company_id,
	profit_ctr_id,
	treatment_id,
	treatment_desc,
	revenue,
	quantity
FROM #cum_sales WHERE month = 2

INSERT INTO work_cum_sales_crosstab (
	company_id,
	profit_ctr_id,
	customer_id,
	customer_name,
	March,
	March_q)
SELECT company_id,
	profit_ctr_id,
	treatment_id,
	treatment_desc,
	revenue,
	quantity
FROM #cum_sales WHERE month = 3

INSERT INTO work_cum_sales_crosstab (
	company_id,
	profit_ctr_id,
	customer_id,
	customer_name,
	April,
	April_q)
SELECT company_id,
	profit_ctr_id,
	treatment_id,
	treatment_desc,
	revenue,
	quantity
FROM #cum_sales WHERE month = 4

INSERT INTO work_cum_sales_crosstab (
	company_id,
	profit_ctr_id,
	customer_id,
	customer_name,
	May,
	May_q)
SELECT company_id,
	profit_ctr_id,
	treatment_id,
	treatment_desc,
	revenue,
	quantity
FROM #cum_sales WHERE month = 5

INSERT INTO work_cum_sales_crosstab (
	company_id,
	profit_ctr_id,
	customer_id,
	customer_name,
	June,
	June_q)
SELECT company_id,
	profit_ctr_id,
	treatment_id,
	treatment_desc,
	revenue,
	quantity
FROM #cum_sales WHERE month = 6

INSERT INTO work_cum_sales_crosstab (
	company_id,
	profit_ctr_id,
	customer_id,
	customer_name,
	July,
	July_q)
SELECT company_id,
	profit_ctr_id,
	treatment_id,
	treatment_desc,
	revenue,
	quantity
FROM #cum_sales WHERE month = 7

INSERT INTO work_cum_sales_crosstab (
	company_id,
	profit_ctr_id,
	customer_id,
	customer_name,
	August,
	August_q)
SELECT company_id,
	profit_ctr_id,
	treatment_id,
	treatment_desc,
	revenue,
	quantity
FROM #cum_sales WHERE month = 8

INSERT INTO work_cum_sales_crosstab (
	company_id,
	profit_ctr_id,
	customer_id,
	customer_name,
	September,
	September_q)
SELECT company_id,
	profit_ctr_id,
	treatment_id,
	treatment_desc,
	revenue,
	quantity
FROM #cum_sales WHERE month = 9

INSERT INTO work_cum_sales_crosstab (
	company_id,
	profit_ctr_id,
	customer_id,
	customer_name,
	October,
	October_q)
SELECT company_id,
	profit_ctr_id,
	treatment_id,
	treatment_desc,
	revenue,
	quantity
FROM #cum_sales WHERE month = 10

INSERT INTO work_cum_sales_crosstab (
	company_id,
	profit_ctr_id,
	customer_id,
	customer_name,
	November,
	November_q)
SELECT company_id,
	profit_ctr_id,
	treatment_id,
	treatment_desc,
	revenue,
	quantity
FROM #cum_sales WHERE month = 11

INSERT INTO work_cum_sales_crosstab (
	company_id,
	profit_ctr_id,
	customer_id,
	customer_name,
	December,
	December_q)
SELECT company_id,
	profit_ctr_id,
	treatment_id,
	treatment_desc,
	revenue,
	quantity
FROM #cum_sales WHERE month = 12


SELECT	
	work_cum_sales_crosstab.company_id,
	work_cum_sales_crosstab.profit_ctr_id,
	Company.company_name,
	ProfitCenter.profit_ctr_name,
	customer_id,
	customer_name,
	January		= SUM(IsNull(January, 0.00)),
	February	= SUM(IsNull(February, 0.00)),
	March		= SUM(IsNull(March, 0.00)),
	April		= SUM(IsNull(April, 0.00)),
	May			= SUM(IsNull(May, 0.00)),
	June		= SUM(IsNull(June, 0.00)),
	July		= SUM(IsNull(July, 0.00)),
	August		= SUM(IsNull(August, 0.00)),
	September	= SUM(IsNull(September, 0.00)),
	October		= SUM(IsNull(October, 0.00)),
	November	= SUM(IsNull(November, 0.00)),
	December	= SUM(IsNull(December, 0.00)),
	Jan_q		= SUM(IsNull(January_q, 0)),
	Feb_q		= SUM(IsNull(February_q, 0)),
	March_q		= SUM(IsNull(March_q, 0)),
	Apr_q		= SUM(IsNull(April_q, 0)),
	May_q		= SUM(IsNull(May_q, 0)),
	June_q		= SUM(IsNull(June_q, 0)),
	July_q		= SUM(IsNull(July_q, 0)),
	Aug_q		= SUM(IsNull(August_q, 0)),
	Sep_q		= SUM(IsNull(September_q, 0)),
	Oct_q		= SUM(IsNull(October_q, 0)),
	Nov_q		= SUM(IsNull(November_q, 0)),
	Dec_q		= SUM(IsNull(December_q, 0))
FROM work_cum_sales_crosstab
JOIN Company
	ON Company.company_id = work_cum_sales_crosstab.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = work_cum_sales_crosstab.company_id
	AND ProfitCenter.profit_ctr_ID = work_cum_sales_crosstab.profit_ctr_id
GROUP BY 
	work_cum_sales_crosstab.company_id,
	work_cum_sales_crosstab.profit_ctr_id,
	Company.company_name,
	ProfitCenter.profit_ctr_name,
	customer_id,
	customer_name
ORDER BY work_cum_sales_crosstab.company_id, work_cum_sales_crosstab.profit_ctr_id, customer_name

DROP TABLE #cum_sales

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_cum_treatment_sales] TO [EQAI]
    AS [dbo];

