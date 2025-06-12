CREATE PROCEDURE sp_problem_list 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
,	@territory_code char(2)
AS
/*****************************************************************************************
Problem list 
Lists all workorders that have had a problem identified on them.
PB Object(s):	r_problem_list

07/21/00	LJT Created - copied from flash detail
11/20/00	SCC Added territory argument
01/30/01	JDB Changed profit_ctr_name to varchar(50)
04/06/06	RG  revised to include the company id so it can get the notes
10/31/07	rg  added submitted_flag
12/10/2010	SK	added company_id as input arg and joins to company_id
				moved to Plt_AI
01/12/2012 SK	Changed to use the new WorkOrderTypeHeader.workorder_type_id (GL standardization project)
				
sp_problem_list 0, -1, '01-01-2005','01-31-2005', 1, 999999, '99'
******************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


Declare 
	@wo_id				int, 
	@wo_id_prev			int, 
	@wo_count			int, 
	@base_rate_quote_id int, 
	@project_quote_id	int,
	@customer_quote_id	int, 
	@project_code		varchar(15), 
	@customer_id		int, 
	@detail_count		int, 
	@fixed_price_total	money, 
	@fixed_price_amount money, 
	@fixed_price_count	int, 
	@fixed_price_flag	char(1),
	@debug				varchar(255), 
	@rowcount			int

/* Return the results */
SELECT
	woh.workorder_status
,	woh.company_id
,	woh.profit_ctr_ID
--,	g.account_desc
,	WOTH.account_desc
,	@date_from as date_from
,	@date_to as date_to
,	woh.customer_id
,	woh.workorder_id
,	woh.end_date
,	c.cust_name
,	woh.description
,	p.problem_desc
,	woh.created_by
,	woh.date_added
,	woh.date_modified
,	woh.modified_by
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM workorderheader woh
JOIN Company
	ON Company.company_id = woh.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = woh.company_id
	AND ProfitCenter.profit_ctr_ID = woh.profit_ctr_ID
JOIN WorkorderProblem p
	ON p.problem_id = woh.problem_id
JOIN Customer c
	ON c.customer_id = woh.customer_id 
JOIN CustomerBilling cb
	ON cb.customer_id = c.customer_ID
	AND  cb.billing_project_id = IsNull(woh.billing_project_id,0)
	AND ((@territory_code = '99') OR (cb.territory_code = @territory_code)) 
JOIN WorkOrderTypeHeader WOTH
	ON WOTH.workorder_type_id = woh.workorder_type_id
--JOIN GLAccount g
--	ON g.company_id = woh.company_id
--	AND g.profit_ctr_id = woh.profit_ctr_ID
--	AND g.account_type = woh.workorder_type
--	AND g.account_class = 'O' 
WHERE (@company_id = 0 OR @profit_ctr_id = -1 OR woh.profit_ctr_id = @profit_ctr_id)
	AND (@company_id = 0 OR woh.company_id = @company_id)
	AND woh.workorder_status in ('N','A','P','C','D')
	AND woh.submitted_flag = 'F'
	AND woh.end_date BETWEEN @date_from AND @date_to
GROUP BY 
	woh.workorder_status
,	woh.company_id
,	woh.profit_ctr_ID
,	woth.account_desc	
,	woh.customer_id
,	woh.workorder_id
,	woh.end_date
,	c.cust_name
,	woh.description
,	p.problem_desc
,	woh.created_by
,	woh.date_added
,	woh.date_modified
,	woh.modified_by
,	Company.company_name
,	ProfitCenter.profit_ctr_name

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_problem_list] TO [EQAI]
    AS [dbo];

