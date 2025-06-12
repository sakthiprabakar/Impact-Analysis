
CREATE PROCEDURE sp_rpt_time_on_site
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
AS 
/****************************************************************************
Time on Site Report 
(r_time_on_site)

PB Object(s):	r_time_on_site
				w_report_center

10/15/2010 SK	Created (Moved the query from Datawindow into a stored procedure)
				Moved to Plt_AI
02/22/2011 SK	Fixed the Bad Join to Receipt_Problem, was missing 'company_id' clause
05/08/2017 MPM	Modified to exclude In-Transit receipts.

sp_rpt_time_on_site 2, 21, '2/21/2011', '2/21/2011', 1, 999999
****************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 
	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.customer_id
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Customer.cust_name
,	Receipt.generator_id
,	Generator.generator_name
,	Receipt.time_in
,	Receipt.time_out
,	Receipt.receipt_date
,	Receipt.approval_code
,	Receipt.bill_unit_code
,	Receipt.manifest_comment
,	Receipt.date_scheduled
,	Receipt.problem_id
,	Receipt_problem.problem_desc
,	Receipt_problem.problem_cause
,	Receipt.bulk_flag
,	Generator.epa_id 
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
	AND ProfitCenter.company_ID = Receipt.company_id
JOIN Customer
	ON Customer.customer_id = Receipt.customer_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
LEFT OUTER JOIN Receipt_problem
	ON Receipt_problem.problem_id = Receipt.problem_id
	AND Receipt_Problem.company_id = Receipt.company_id
WHERE ( @company_id = 0 OR Receipt.company_id = @company_id )
  AND ( @company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id )
  AND Receipt.receipt_status NOT IN ('T','V')
  AND Receipt.receipt_date BETWEEN @date_from AND @date_to
  AND Receipt.trans_type = 'D'
  AND Receipt.customer_id BETWEEN @cust_id_from AND @cust_id_to
  AND Receipt.trans_mode = 'I' 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_time_on_site] TO [EQAI]
    AS [dbo];

