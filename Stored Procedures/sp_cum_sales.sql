
CREATE PROCEDURE sp_cum_sales 
	@company_id	int
,	@year		int 
AS

/***********************************************************************
 EQAI object:  r_cum_sales				
	This stored procedure is used for the Cumulative Sales Report	
	net_sum_crosstaCompany.  First, data is generated in summary form     
	and inserted into #net_sum table.  Then data is broken by month
	and inserted into net_sum_crosstab table. The data is grouped by
	customer iCustomer.    

Written by Olga Dubin, February 1996.  
07-02-99	JDB		Replaced all instances of "ticket_date" with 
					"invoice_date"		
01-30-01	JDB		changed profit_ctr_name to varchar(50)	
02-03-05	SCC		changed ticket references	
12-02-05	SCC		Changed to sum quantity * price instead of waste_extended_amt
12/03/2010	SK		Modified to run for selected/all companies, modified to use table
					work_cum_sales_crosstab
					Moved to Plt_AI
03/11/2011	SK		Wrapped IsNull around monthly totals

sp_cum_sales 14	, 2010
**********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


CREATE TABLE #cum_sales (
	month			int			NULL,
	revenue			money		NULL,
	quantity		int			NULL,
	company_id		int			NULL,
	profit_ctr_id	int			NULL,
	customer_id		int			NULL,
	customer_name	varchar(40)	NULL
	)

INSERT INTO #cum_sales
-- Inbound receipts
SELECT 	
	month_number	= DATEPART(month, Billing.invoice_date),
	revenue			= SUM(IsNull((Convert(money, Billing.quantity) * Convert(money, Billing.price)), 0.00)),
	quantity		= SUM(IsNull(Billing.quantity, 0.00)),
	Billing.company_id,
	Billing.profit_ctr_id,
	IsNull(Billing.customer_id, -1),
	IsNull(Customer.cust_name, 'Unknown')
FROM Billing
JOIN Customer
	ON Customer.customer_id = Billing.customer_id
WHERE DATEPART(year,Billing.invoice_date) = @year
	AND ( @company_id = 0 OR Billing.company_id = @company_id )
	AND Billing.status_code = 'I'
	AND Billing.void_status = 'F'
GROUP BY DATEPART(month, Billing.invoice_date),
	Billing.company_id,
	Billing.profit_ctr_id,
	Billing.customer_id,
	Customer.cust_name
ORDER BY Billing.company_id,Billing.profit_ctr_id, Billing.customer_id

DELETE FROM work_cum_sales_crosstab

INSERT INTO work_cum_sales_crosstab (
	company_id,
	profit_ctr_id,
	customer_id,
	customer_name,
	January,
	January_q)
SELECT company_id,
	profit_ctr_id,
	customer_id,
	customer_name,
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
	customer_id,
	customer_name,
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
	customer_id,
	customer_name,
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
	customer_id,
	customer_name,
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
	customer_id,
	customer_name,
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
	customer_id,
	customer_name,
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
	customer_id,
	customer_name,
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
	customer_id,
	customer_name,
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
	customer_id,
	customer_name,
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
	customer_id,
	customer_name,
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
	customer_id,
	customer_name,
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
	customer_id,
	customer_name,
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
    ON OBJECT::[dbo].[sp_cum_sales] TO [EQAI]
    AS [dbo];

