CREATE PROCEDURE sp_rpt_container_inbound_log_detail
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
07/02/2003 JDB	Created
12/28/2003 SCC	Added staging row
12/13/2004 MK	Modified ticket_id, drum references, DrumHeader, and DrumDetail
05/05/2005 MK	Added epa_id to select
09/23/2005 MK	Fixed select to look for status = 'C'
10/27/2010 SK	added Company_id as input arg, added joins to company_id
				Moved to Plt_AI
10/30/2013 RB	This report was originally named sp_rpt_container_inbound_log but was replaced
		by a procedure to retrieve summary information. This was renamed _detail

sp_rpt_container_inbound_log_detail 14, 4, '4/1/05', '4/15/05', 1, 999999, 'ALL', 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT 
	r.receipt_date
,	r.manifest
,   r.receipt_id
,	r.line_id
,	r.generator_id
,	g.generator_name
,	CASE WHEN (IsNull(cd.tracking_num,'') = '' OR IsNull(cd.location,'') = '' OR cd.disposal_date IS NULL) 
				AND cd.status <> 'C' THEN 'N' 
		ELSE 'C' 
	END AS status
,	container_count = 1
,	cd.location
,	c.container_id
,	c.profit_ctr_id
,	c.company_id
,	c.staging_row
,	g.epa_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
,	cd.base_tracking_num
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
	AND c.status <> 'V'
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

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_inbound_log_detail] TO [EQAI]
    AS [dbo];

