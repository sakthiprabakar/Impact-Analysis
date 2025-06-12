CREATE PROCEDURE sp_net_rev_sum
	@company_id	int
,	@year		int 
AS
/****************************************************************************************
This stored procedure is used for YDT Net Revenue Summary Report

PB Object(s):	r_net_rev_summary

It uses one temp table #net_sum and one permanent table
net_sum_crosstab.  First, data is generated in summary form
and inserted into #net_sum table.  Then data is broken by month
and inserted into net_sum_crosstab table. The data is grouped by
waste type and bill unit.

02/xx/1996	Written by Olga Dubin
01/27/1999 SCC	Changed bill_unit_desc char(30) result var to
				bill_unit_code char(4)
07/02/1999 JDB	Replaced all instances of "ticket_date" with "invoice_date"
01/30/2001 JDB	Changed profit_ctr_name to varchar(50)
08/05/2004 JDB	Added profit_ctr_id join to WasteCode table
12/30/2004 SCC  Changed Ticket to Billing
12/02/2005 SCC	Changed to sum quantity * price instead of waste_extended_amt
03/15/2006 RG	removed join to wastecode on profit ctr
03/10/2008 rg   changed name for table wastetype to wastecodetype
12/03/2010 SK	Modified to run for selected/all companies, modified to use table
				work_net_sum_crosstab
				Moved to Plt_AI
9/30/2013  SM	Modified to add waste_code_uid condition
10/3/2013  SM   Modified to include seperate update of waste_type


sp_net_rev_sum 21, 2013
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

CREATE TABLE #net_sum (
	month			int			NULL,
	revenue			money		NULL,
	quantity		int			NULL,
	company_id		int			NULL,
	profit_ctr_id	int			NULL,
	bill_unit_code	varchar(4)	NULL,
	waste_code_uid		int		NULL,
	waste_type		varchar(30)	NULL
	)
	
INSERT INTO #net_sum 
SELECT	
	month_number	= DATEPART(month,Billing.invoice_date),
	revenue			= SUM(Convert(money, Billing.quantity) * Convert(money, Billing.price)),
	quantity		= SUM(Billing.quantity),
	Billing.company_id,
	Billing.profit_ctr_id,
	Billing.bill_unit_code,
	Billing.waste_code_uid,
	NULL as waste_type
FROM Billing
WHERE ( @company_id = 0 OR Billing.company_id = @company_id )
	AND DATEPART(year, Billing.invoice_date) = @year
	AND Billing.status_code = 'I'
	AND Billing.void_status = 'F'
GROUP BY DATEPART(month,Billing.invoice_date),
	Billing.company_id,
	Billing.profit_ctr_id,
	Billing.bill_unit_code, Billing.waste_code_uid
ORDER BY Billing.company_id, Billing.profit_ctr_id, Billing.bill_unit_code

Update #net_sum set waste_type = isnull( ( select waste_type_desc from wastecodetype join wastecode on wastecodetype.waste_type_code = wastecode.waste_type_code and wastecode.waste_code_uid = #net_sum.waste_code_uid),'Undetermined')

DELETE FROM work_net_sum_crosstab

INSERT INTO work_net_sum_crosstab (
	company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	January,
	January_q)
SELECT company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	revenue,
	quantity
FROM #net_sum WHERE month = 1

INSERT INTO work_net_sum_crosstab (
	company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	February,
	February_q)
SELECT company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	revenue,
	quantity
FROM #net_sum WHERE month = 2

INSERT INTO work_net_sum_crosstab (
	company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	March,
	March_q)
SELECT company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	revenue,
	quantity
FROM #net_sum WHERE month = 3

INSERT INTO work_net_sum_crosstab (
	company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	April,
	April_q)
SELECT company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	revenue,
	quantity
FROM #net_sum WHERE month = 4

INSERT INTO work_net_sum_crosstab (
	company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	May,
	May_q)
SELECT company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	revenue,
	quantity
FROM #net_sum WHERE month = 5

INSERT INTO work_net_sum_crosstab (
	company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	June,
	June_q)
SELECT company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	revenue,
	quantity
FROM #net_sum WHERE month = 6

INSERT INTO work_net_sum_crosstab (
	company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	July,
	July_q)
SELECT company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	revenue,
	quantity
FROM #net_sum WHERE month = 7

INSERT INTO work_net_sum_crosstab (
	company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	August,
	August_q)
SELECT company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	revenue,
	quantity
FROM #net_sum WHERE month = 8

INSERT INTO work_net_sum_crosstab (
	company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	September,
	September_q)
SELECT company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	revenue,
	quantity
FROM #net_sum WHERE month = 9

INSERT INTO work_net_sum_crosstab (
	company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	October,
	October_q)
SELECT company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	revenue,
	quantity
FROM #net_sum WHERE month = 10

INSERT INTO work_net_sum_crosstab (
	company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	November,
	November_q)
SELECT company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	revenue,
	quantity
FROM #net_sum WHERE month = 11

INSERT INTO work_net_sum_crosstab (
	company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	December,
	December_q)
SELECT company_id,
	profit_ctr_id,
	bill_unit_code,
	waste_type,
	revenue,
	quantity
FROM #net_sum WHERE month = 12


SELECT	
	work_net_sum_crosstab.company_id,
	work_net_sum_crosstab.profit_ctr_id,
	Company.company_name,
	ProfitCenter.profit_ctr_name,
	waste_type,
	bill_unit_code,
	January		= isnull(SUM(January),0),
	February	= isnull(SUM(February),0),
	March		= isnull(SUM(March),0),
	April		= isnull(SUM(April),0),
	May		= isnull(SUM(May),0),
	June		= isnull(SUM(June),0),
	July		= isnull(SUM(July),0),
	August		= isnull(SUM(August),0),
	September	= isnull(SUM(September),0),
	October		= isnull(SUM(October),0),
	November	= isnull(SUM(November),0),
	December	= isnull(SUM(December),0),
	Jan_q		= isnull(SUM(January_q),0),
	Feb_q		= isnull(SUM(February_q),0),
	March_q		= isnull(SUM(March_q),0),
	Apr_q		= isnull(SUM(April_q),0),
	May_q		= isnull(SUM(May_q),0),
	June_q		= isnull(SUM(June_q),0),
	July_q		= isnull(SUM(July_q),0),
	Aug_q		= isnull(SUM(August_q),0),
	Sep_q		= isnull(SUM(September_q),0),
	Oct_q		= isnull(SUM(October_q),0),
	Nov_q		= isnull(SUM(November_q),0),
	Dec_q		= isnull(SUM(December_q),0)
FROM work_net_sum_crosstab
JOIN Company
	ON Company.company_id = work_net_sum_crosstab.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = work_net_sum_crosstab.company_id
	AND ProfitCenter.profit_ctr_ID = work_net_sum_crosstab.profit_ctr_id
GROUP BY 
	work_net_sum_crosstab.company_id,
	work_net_sum_crosstab.profit_ctr_id,
	Company.company_name,
	ProfitCenter.profit_ctr_name,
	waste_type,
	bill_unit_code
ORDER BY work_net_sum_crosstab.company_id, work_net_sum_crosstab.profit_ctr_id, waste_type, bill_unit_code

DROP TABLE #net_sum


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_net_rev_sum] TO [EQAI]
    AS [dbo];

