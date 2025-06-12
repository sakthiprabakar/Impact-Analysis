CREATE PROCEDURE sp_rank_summary
	@user_id	varchar(8)
AS
/********************************************************************************
This procedure runs for "Customer Waste Report ranked by Revenue" report

PB Object(s):	r_customer_by_revenue

01/27/1999 SCC	Removed bill_unit_desc from result set
12/14/2004 JDB	Changed ticket_month to line_month, ticket_year to line_year
01/30/2006 MK	Added parameter user_id to pull only for current user
11/29/2010 SK	used the new table work_WasteSumrpt, Moved to Plt_AI

sp_rank_summary 'SA'
*******************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 
	profit_ctr_id, 
	customer_id, 
	revenue = SUM(gross_price - discount_dollars )
INTO #revenue
FROM work_WasteSumRpt
WHERE user_id = @user_id
GROUP BY profit_ctr_id, customer_id
ORDER BY profit_ctr_id ASC, customer_id

SELECT 
	wsr.company_name,
	wsr.profit_ctr_id,
	wsr.profit_ctr_name,
	wsr.customer_id,
	wsr.customer_name,
	wsr.bill_unit_code,
	wsr.waste_code,
	wsr.quantity,
	wsr.gross_price,
	wsr.discount_dollars,
	wsr.line_month,
	wsr.line_year,
	rev.revenue
FROM work_WasteSumRpt wsr
JOIN #revenue rev
	ON rev.profit_ctr_id = wsr.profit_ctr_id
	AND rev.customer_id = wsr.customer_id
WHERE user_id = @user_id
ORDER BY wsr.profit_ctr_id, rev.revenue DESC, wsr.customer_id ASC, wsr.line_year ASC,
		 wsr.line_month ASC, wsr.waste_code ASC, wsr.bill_unit_code

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rank_summary] TO [EQAI]
    AS [dbo];

