CREATE PROCEDURE sp_unit_totals
AS
/***********************************************************************
This procedure runs for the Unit Summary Report in Waste Summaries.

PB Object(s):	r_unit_totals

01/27/1999 SCC	Removed bill_unit_desc result var				
11/29/2010 SK	used the new table work_WasteSumrpt, Moved to Plt_AI

sp_unit_totals
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 	
	wsr.profit_ctr_id,
	wsr.profit_ctr_name,
	wsr.bill_unit_code,   
	wsr.company_id,
	c.company_name,      
	SUM(wsr.quantity),   
	SUM(wsr.gross_price),   
	SUM(wsr.discount_dollars)
FROM work_WasteSumRpt wsr
JOIN Company c
	ON c.company_id = wsr.company_id
GROUP BY  
	wsr.profit_ctr_id,
	wsr.profit_ctr_name,
	wsr.bill_unit_code,  
	wsr.company_id, 
	c.company_name
ORDER BY wsr.profit_ctr_id, wsr.bill_unit_code, c.company_name

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_unit_totals] TO [EQAI]
    AS [dbo];

