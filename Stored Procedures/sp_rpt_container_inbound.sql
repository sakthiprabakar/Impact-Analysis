CREATE PROCEDURE sp_rpt_container_inbound
	@company_id		int
,	@profit_ctr_id 	int
,	@date_from 		datetime
,	@date_to 		datetime
,	@customer_from 	int
,	@customer_to 	int
,	@location		varchar(15)
,	@staging_row	varchar(5)
AS

/***************************************************************************************
02/20/2004 SCC	Created
12/13/2004 MK	Modified ticket_id, drum references, DrumHeader, and DrumDetail
10/28/2010 SK	added Company_id as input arg, added joins to company_id
				Moved to Plt_AI
11/16/2015 AM - Don't include void receipts to result set.

sp_rpt_container_inbound 14, 4, '2-01-04', '2-20-04', 1, 999999, 'WMLIVEOAK', 'ALL'
sp_rpt_container_inbound 21, 0, '2-27-2014', '2-27-2014', 50013, 50013, 'ALL', 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT 
	r.receipt_date
,	r.manifest
,	r.receipt_id
,	r.line_id
,	r.generator_id
,	g.generator_name
,	c.status
,	container_count = 1
,	cd.location
,	c.container_id
,	c.company_id
,	c.profit_ctr_id
,	c.staging_row
,	IsNull(c.container_size,'') as container_size
,	COALESCE(cd.treatment_id, r.treatment_id) as treatment_ID
,	treatment_desc = IsNull((SELECT treatment_desc FROM Treatment WHERE profit_ctr_id = c.profit_ctr_id 
								AND company_id = c.company_id AND treatment_id = COALESCE(cd.treatment_id, r.treatment_id)),'')
,	IsNull(c.container_weight,0) as container_weight
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt r
JOIN Company
	ON Company.company_id = r.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = r.company_id
	AND ProfitCenter.profit_ctr_id = r.profit_ctr_id
JOIN Container c
	ON c.company_id = r.company_id
	AND c.profit_ctr_id = r.profit_ctr_id
	AND c.receipt_id = r.receipt_id
	AND c.line_id = r.line_id
	AND c.container_type = 'R'
	AND (@staging_row = 'ALL' OR c.staging_row = @staging_row)
JOIN ContainerDestination cd
	ON cd.company_id = c.company_id
	AND cd.profit_ctr_id = c.profit_ctr_id
	AND cd.receipt_id = c.receipt_id
	AND cd.line_id = c.line_id
	AND cd.container_id	= c.container_id
	AND cd.container_type = c.container_type
	AND (@location = 'ALL' OR cd.location = @location)
LEFT OUTER JOIN Generator g
	ON g.generator_id = r.generator_id
WHERE	( @company_id = 0 OR r.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id )
	AND r.trans_mode = 'I'
	AND r.trans_type = 'D'
	AND r.bulk_flag = 'F'
	AND r.receipt_date BETWEEN @date_from AND @date_to
	AND r.customer_id BETWEEN @customer_from AND @customer_to
	AND r.receipt_status <> 'V'
ORDER BY treatment_id, container_size


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_inbound] TO [EQAI]
    AS [dbo];

