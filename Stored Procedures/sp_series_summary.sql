CREATE PROCEDURE sp_series_summary
	@user_id	varchar(8)
AS
/***********************************************************************
This procedure runs for the Waste Series Summary Report.

PB Object(s):	r_series_summary
				
01/27/1999 SCC	Removed bill_unit_desc result var
08/05/2004 JDB	Added profit_ctr_id join to WasteCode table.
12/14/2004 JDB	Changed ticket_month to line_month, ticket_year to line_year
03/15/2006 RG	removed join to wastecode on profit ctr
04/21/2006 MK	Added user_id argument to limit the data to the current user
11/29/2010 SK	used the new table work_WasteSumrpt, Moved to Plt_AI

sp_series_summary
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT	
	work_WasteSumRpt.company_name,   
	work_WasteSumRpt.profit_ctr_id,   
	work_WasteSumRpt.profit_ctr_name,   
	work_WasteSumRpt.customer_id,   
	work_WasteSumRpt.customer_name,   
	work_WasteSumRpt.bill_unit_code,   
	work_WasteSumRpt.waste_code,   
	work_WasteSumRpt.quantity,   
	work_WasteSumRpt.gross_price,   
	work_WasteSumRpt.discount_dollars,
	work_WasteSumRpt.company_id,
	work_WasteSumRpt.line_month,
	work_WasteSumRpt.line_year,
	WasteCode.haz_flag,
	SeriesIndicator = SUBSTRING(work_WasteSumRpt.waste_code, 1, 1)
FROM work_WasteSumRpt
JOIN WasteCode
	ON WasteCode.waste_code = work_WasteSumRpt.waste_code
WHERE work_WasteSumRpt.user_id = @user_id
	AND SUBSTRING(work_WasteSumRpt.waste_code,2,1) IN ('0','1','2','3','4','5','6','7','8','9')
	AND SUBSTRING(work_WasteSumRpt.waste_code,3,1) IN ('0','1','2','3','4','5','6','7','8','9')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_series_summary] TO [EQAI]
    AS [dbo];

