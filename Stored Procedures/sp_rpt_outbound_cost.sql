CREATE PROCEDURE sp_rpt_outbound_cost 
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@receipt_id_from	int
,	@receipt_id_to		int
,	@manifest_from		varchar(15)
,	@manifest_to		varchar(15)
,	@tsdf_approval_from	varchar(40)
,	@tsdf_approval_to	varchar(40) 
AS
/***************************************************************************************
PB Object(s):	r_outbound_cost

04/04/2003 LJT	Created
11/11/2004 MK	Changed generator_code to generator_id
11/29/2004 JDB	Changed ticket_id to line_id
05/05/2005 MK	Added epa_id and generator_name to select
09/23/2005 MK	Incorporated more arguments for select
03/15/2006 RG   added logic for new estimate cost fields 
11/08/2010 SK	Modified to run on Plt_AI, replaced *= joins with standard ANSI joins
				Moved on Plt_AI

sp_rpt_outbound_cost 21, 0, '9/1/2005','9/21/2005', 1, 999999, 625077, 625077, '0', 'ZZZZZZZZ', '0', 'ZZZ'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT	
	r.receipt_id
,	r.line_id
,	r.manifest
,	r.receipt_date
,	r.receipt_status
,	r.TSDF_code
,	r.waste_stream
,	r.tsdf_approval_code
,	r.hauler
,	r.quantity
,	r.bill_unit_code
,	CASE WHEN r.cost_flag = 'E' THEN IsNull(r.cost_disposal_est,0) ELSE IsNull(r.cost_disposal,0) END as cost_disposal
,	CASE WHEN r.cost_flag = 'E' THEN IsNull(r.cost_lab_est,0) ELSE IsNull(r.cost_lab,0) END as cost_lab 
,	CASE WHEN r.cost_flag = 'E' THEN IsNull(r.cost_process_est,0) ELSE IsNull(r.cost_process,0) END as cost_process  
,	CASE WHEN r.cost_flag = 'E' THEN IsNull(r.cost_surcharge_est,0) ELSE IsNull(r.cost_surcharge,0) END as cost_surcharge
,	CASE WHEN r.cost_flag = 'E' THEN IsNull(r.cost_trans_est,0) ELSE IsNull(r.cost_trans,0) END as cost_trans
,	r.cost_flag
,	r.customer_id
,	c.cust_name
,	r.generator_id
,	r.company_id
,	r.profit_ctr_id
,	g.epa_id
,	g.generator_name
,	co.company_name
,	pc.profit_ctr_name
FROM receipt r
JOIN Company co
	ON co.company_id = r.company_id
JOIN ProfitCenter pc
	ON pc.company_ID = r.company_id
	AND pc.profit_ctr_ID = r.profit_ctr_id
JOIN Customer c
	ON c.customer_id = r.customer_id
JOIN Generator g
	ON g.generator_id = r.generator_id
WHERE	(@company_id = 0 OR r.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id)
	AND r.trans_mode = 'O'
	AND r.trans_type = 'D'
	AND r.receipt_status NOT IN ('T', 'V', 'R')
	AND r.receipt_date BETWEEN @date_from AND @date_to
	AND r.receipt_id BETWEEN @receipt_id_from AND @receipt_id_to
	AND r.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND r.manifest BETWEEN @manifest_from AND @manifest_to
	AND r.tsdf_approval_code BETWEEN @tsdf_approval_from AND @tsdf_approval_to

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_outbound_cost] TO [EQAI]
    AS [dbo];

