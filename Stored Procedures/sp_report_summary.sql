CREATE PROCEDURE sp_report_summary
	@user_id	varchar(8)
AS
/***********************************************************************
This procedure runs for the Summary Reports.

PB Object(s):	r_customer_summary
				r_waste_summary
				r_waste_summary_w_customers
				r_waste_summary_w_haz_flg

01/27/1999 SCC	Removed bill_unit_desc from result set
08/05/2004 JDB	Added profit_ctr_id join to WasteCode table.
12/14/2004 JDB	Changed ticket_month to line_month, ticket_year to line_year
03/15/2006 RG   removed join to wastecode profit ctr
04/21/2006 MK	Added user_id argument to limit the data to the current user
11/24/2010 SK	used the new table work_WasteSumrpt, Moved to Plt_AI
10/21/2013 AM   Added display_name and waste_code_uid join

sp_report_summary 21, '01/01/2003', '03/01/2003', 'ALL', 1, 999999, 1, 'SMITA_K'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT	
	work_WasteSumRpt.company_name,   
	work_WasteSumRpt.profit_ctr_id,   
	work_WasteSumRpt.profit_ctr_name,   
	work_WasteSumRpt.customer_id,   
	work_WasteSumRpt.customer_name,   
	work_WasteSumRpt.bill_unit_code,   
	--work_WasteSumRpt.waste_code,  
	WasteCode.display_name as waste_code, 
	work_WasteSumRpt.quantity,   
	work_WasteSumRpt.gross_price,   
	work_WasteSumRpt.discount_dollars,
	work_WasteSumRpt.company_id,
	work_WasteSumRpt.line_month,
	work_WasteSumRpt.line_year,
	WasteCode.haz_flag
FROM work_WasteSumRpt
JOIN WasteCode
	ON WasteCode.waste_code_uid = work_WasteSumRpt.waste_code_uid
WHERE work_WasteSumRpt.user_id = @user_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_summary] TO [EQAI]
    AS [dbo];

