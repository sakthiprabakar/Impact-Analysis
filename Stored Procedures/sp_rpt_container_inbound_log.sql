
CREATE PROCEDURE sp_rpt_container_inbound_log
	@company_id		int
,	@profit_ctr_id 	int
,	@date_from 		datetime
,	@date_to 		datetime
,	@customer_from 	int
,	@customer_to 	int
,	@location		varchar(15)
,	@staging_rows	varchar(max)
AS
/***************************************************************************************
07/02/2003 JDB	Created
12/28/2003 SCC	Added staging row
12/13/2004 MK	Modified ticket_id, drum references, DrumHeader, and DrumDetail
05/05/2005 MK	Added epa_id to select
09/23/2005 MK	Fixed select to look for status = 'C'
10/27/2010 SK	added Company_id as input arg, added joins to company_id
				Moved to Plt_AI
10/30/2013 RB	Modified report to retrieve a summary of inbound containers. The original
				report has been renamed sp_rpt_container_inbound_log_detail
02/28/2017 MPM	Replaced the staging row input parameter with a staging row list input parameter.

sp_rpt_container_inbound_log 14, 4, '4/1/05', '4/15/05', 1, 999999, 'ALL', 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

if @staging_rows is null
	set @staging_rows = 'ALL'
	
CREATE TABLE #tmp_staging_rows (staging_row	varchar(5) NULL)

if datalength((@staging_rows)) > 0 and @staging_rows <> 'ALL'
	EXEC sp_list 0, @staging_rows, 'STRING', '#tmp_staging_rows'

SELECT DISTINCT 
	r.receipt_date
,	CASE WHEN (IsNull(cd.tracking_num,'') = '' OR IsNull(cd.location,'') = '' OR cd.disposal_date IS NULL) 
				AND cd.status <> 'C' THEN 'N' 
		ELSE 'C' 
	END AS status
,	container_count = 1
,	cd.location
,	c.profit_ctr_id
,	c.company_id
,	c.staging_row
,	Company.company_name
,	ProfitCenter.profit_ctr_name
--beg
,	rh.trip_id
,	'R'
,	CONVERT(varchar(15),right('0' + convert(varchar(2),r.company_id),2) + '-' + right('0' + convert(varchar(2),r.profit_ctr_id),2) + '-' + CONVERT(varchar(10),r.receipt_id) + '-' + CONVERT(varchar(4),r.line_id))
--end
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
	AND (@staging_rows = 'ALL' OR ISNULL(c.staging_row, '') in (select staging_row from #tmp_staging_rows))
	AND c.status <> 'V'
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
--beg
JOIN ReceiptHeader rh
	ON r.company_id = rh.company_id
	AND r.profit_ctr_id = rh.profit_ctr_id
	AND r.receipt_id = rh.receipt_id
LEFT OUTER JOIN BillingLinkLookup bll
	ON r.company_id = bll.company_id
	AND r.profit_ctr_id = bll.profit_ctr_id
	AND r.receipt_id = bll.receipt_id
LEFT OUTER JOIN WorkOrderDetail wd
	ON bll.source_id = wd.workorder_id
	AND bll.source_company_id = wd.company_id
	AND bll.source_profit_ctr_id = wd.profit_ctr_id
	AND wd.resource_type = 'D'
	AND r.manifest = wd.manifest
	AND r.manifest_line = wd.manifest_line
--end
WHERE	( @company_id = 0 OR r.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id )
	AND r.trans_mode = 'I'
	AND r.trans_type = 'D'
	AND r.bulk_flag = 'F'
	AND r.receipt_date BETWEEN @date_from AND @date_to
	AND r.customer_id BETWEEN @customer_from AND @customer_to
AND NOT EXISTS (select 1 from ContainerDestination
		where company_id = c.company_id
		and profit_ctr_id = c.profit_ctr_id
		and receipt_id = c.receipt_id
		and line_id = c.line_id
		and container_type = c.container_type
		and container_type = 'R'
		and isnull(base_tracking_num,'') <> '')
union
SELECT DISTINCT 
	r.receipt_date
,	CASE WHEN (IsNull(cd.tracking_num,'') = '' OR IsNull(cd.location,'') = '' OR cd.disposal_date IS NULL) 
				AND cd.status <> 'C' THEN 'N' 
		ELSE 'C' 
	END AS status
,	container_count = 1
,	cd.location
,	c.profit_ctr_id
,	c.company_id
,	c2.staging_row
,	Company.company_name
,	ProfitCenter.profit_ctr_name
--beg
,	rh.trip_id
,	'S'
,	cd.base_tracking_num
--end
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
	AND (@staging_rows = 'ALL' OR ISNULL(c.staging_row, '') in (select staging_row from #tmp_staging_rows))
	AND c.status <> 'V'
JOIN ContainerDestination cd
	ON cd.company_id = c.company_id
	AND cd.profit_ctr_id = c.profit_ctr_id
	AND cd.receipt_id = c.receipt_id
	AND cd.line_id = c.line_id
	AND cd.container_id	= c.container_id
	AND cd.container_type = c.container_type
	AND (@location = 'ALL' OR cd.location = @location)
	AND ISNULL(cd.base_tracking_num,'') LIKE 'DL-%'
JOIN Container c2
	ON cd.company_id = c2.company_id
	AND cd.profit_ctr_id = c2.profit_ctr_id
	AND c2.container_type = 'S'
	AND cd.base_container_id = c2.container_id
LEFT OUTER JOIN Generator g
	ON g.generator_id = r.generator_id
--beg
JOIN ReceiptHeader rh
	ON r.company_id = rh.company_id
	AND r.profit_ctr_id = rh.profit_ctr_id
	AND r.receipt_id = rh.receipt_id
LEFT OUTER JOIN BillingLinkLookup bll
	ON r.company_id = bll.company_id
	AND r.profit_ctr_id = bll.profit_ctr_id
	AND r.receipt_id = bll.receipt_id
LEFT OUTER JOIN WorkOrderDetail wd
	ON bll.source_id = wd.workorder_id
	AND bll.source_company_id = wd.company_id
	AND bll.source_profit_ctr_id = wd.profit_ctr_id
	AND wd.resource_type = 'D'
	AND r.manifest = wd.manifest
	AND r.manifest_line = wd.manifest_line
--end
WHERE	( @company_id = 0 OR r.company_id = @company_id )
	AND ( @company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id )
	AND r.trans_mode = 'I'
	AND r.trans_type = 'D'
	AND r.bulk_flag = 'F'
	AND r.receipt_date BETWEEN @date_from AND @date_to
	AND r.customer_id BETWEEN @customer_from AND @customer_to


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_inbound_log] TO [EQAI]
    AS [dbo];

