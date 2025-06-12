
CREATE PROCEDURE sp_rpt_inbound_receipt_detail_for_outbound_receipts
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@cust_id_from		int
,	@cust_id_to			int
,	@receipt_from		int
,	@receipt_to			int
,	@manifest_from		varchar(15)
,	@manifest_to		varchar(15)
,	@tsdf_approval_code_from	varchar(40)
,	@tsdf_approval_code_to		varchar(40) 
AS
/****************
11/03/2010 SK  Created on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name
06/18/2015 AM   Added container join to get container_weight.
02/19/2018 AM   changed manifest_line_id to manifest_line
04/18/2022 AM   DevOps:38523 - Added ContainerDestination.container_id,ContainerDestination.sequence_id
     ,ContainerDestination.container_percent,Container.staging_row fields
	   
sp_rpt_inbound_receipt_detail_for_outbound_receipts 21, 0, '9/1/2005','9/21/2005', 1, 999999, 625077, 625077, '0', 'ZZZZZZZZ', '0', 'ZZZ'
sp_rpt_inbound_receipt_detail_for_outbound_receipts 21, 0, '1/1/2017','1/15/2017', 1, 999999, 1, 99999999, '0', 'ZZZZZZZZ', '0', 'ZZZ'
******************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT 
	Receipt_OB.company_id
,	Receipt_OB.profit_ctr_id
,	ContainerDestination.tracking_num
,	Receipt_IB.receipt_id
,	Receipt_IB.line_id
,	dbo.fn_container_receipt(Receipt_IB.receipt_id, Receipt_IB.line_id) as receipt_line
,	Receipt_IB.manifest
,	Generator.EPA_ID + '  ' + Generator.generator_name as generator
,	COUNT(ContainerDestination.container_id) AS container_count
,	Receipt_IB.bulk_flag
,	ContainerDestination.location
,	Receipt_IB.receipt_date
,	Receipt_IB.approval_code
,	w.display_name as waste_code
,	Receipt_OB.manifest as outbound_manifest
,	Receipt_OB.manifest_line_id as outbound_manifest_line_id
,	Receipt_OB.tsdf_approval_code
,	ContainerDestination.treatment_id
,	Treatment.treatment_desc
,	Company.company_name
,	ProfitCenter.profit_ctr_name
,   Container.container_weight as container_weight
,	Receipt_OB.manifest_line as outbound_manifest_line
,	ContainerDestination.container_id
,	ContainerDestination.sequence_id
,   ContainerDestination.container_percent
,	Container.staging_row
FROM Receipt Receipt_OB
LEFT OUTER JOIN wastecode w
	ON w.waste_code_uid = Receipt_OB.waste_code_uid
JOIN Company
	ON Company.company_id = Receipt_OB.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt_OB.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt_OB.profit_ctr_id
JOIN Receipt Receipt_IB
	ON 	Receipt_IB.company_id = Receipt_OB.company_id
	AND Receipt_IB.profit_ctr_ID = Receipt_OB.profit_ctr_id
	AND Receipt_IB.trans_mode = 'I'
	AND Receipt_IB.trans_type IN ('D','X')
JOIN ContainerDestination
	ON ContainerDestination.company_id = Receipt_OB.company_id
	AND ContainerDestination.profit_ctr_id = Receipt_OB.profit_ctr_id
	AND ContainerDestination.receipt_id = Receipt_IB.receipt_id
	AND ContainerDestination.line_id = Receipt_IB.line_id
	AND ContainerDestination.tracking_num = dbo.fn_container_receipt(Receipt_OB.receipt_id, Receipt_OB.line_id)
	AND ContainerDestination.container_type = 'R'
LEFT OUTER JOIN Container 
	ON ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.company_id = Container.company_id
    AND ContainerDestination.container_id = Container.container_id
    AND Container.container_type = 'R'
    AND ContainerDestination.receipt_id = Container.receipt_id
    AND ContainerDestination.line_id = Container.line_id
LEFT OUTER JOIN Treatment
	ON Treatment.company_id = ContainerDestination.company_id
	AND Treatment.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt_IB.generator_id
WHERE	(@company_id = 0 OR Receipt_OB.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt_OB.profit_ctr_id = @profit_ctr_id)
	AND Receipt_OB.trans_mode = 'O'
	AND Receipt_OB.trans_type IN ('D','X')
	AND Receipt_OB.receipt_id BETWEEN @receipt_from AND @receipt_to
	AND Receipt_OB.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt_OB.manifest BETWEEN @manifest_from AND @manifest_to
	AND ((Receipt_OB.manifest_flag = 'X' AND Receipt_OB.customer_id IS NULL) OR Receipt_OB.customer_id BETWEEN @cust_id_from AND @cust_id_to)
	AND ((Receipt_OB.manifest_flag = 'X' AND Receipt_OB.tsdf_approval_code IS NULL) OR Receipt_OB.tsdf_approval_code BETWEEN @tsdf_approval_code_from AND @tsdf_approval_code_to)
GROUP BY 
	Receipt_OB.company_id
,	Receipt_OB.profit_ctr_id
,	ContainerDestination.tracking_num
,	Receipt_IB.receipt_id
,	Receipt_IB.line_id
,	Receipt_IB.manifest
,	Generator.EPA_ID
,	Generator.generator_name
,	Receipt_IB.bulk_flag
,	ContainerDestination.location
,	Receipt_IB.receipt_date
,	Receipt_IB.approval_code
,	w.display_name
,	Receipt_OB.manifest
,	Receipt_OB.manifest_line_id
,	Receipt_OB.tsdf_approval_code
,	ContainerDestination.treatment_id
,	Treatment.treatment_desc
,	Company.company_name
,	ProfitCenter.profit_ctr_name
,   Container.container_weight
,	Receipt_OB.manifest_line
,	ContainerDestination.container_id
,	ContainerDestination.sequence_id
,   ContainerDestination.container_percent
,	Container.staging_row
UNION ALL

SELECT DISTINCT 
	Receipt_OB.company_id
,	Receipt_OB.profit_ctr_id
,	ContainerDestination.tracking_num
,	ContainerDestination.receipt_id
,	ContainerDestination.line_id
,	receipt_line = dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id)
,	'' AS manifest
,	'' AS generator
,	1 as container_count
,	'F' AS bulk_flag
,	ContainerDestination.location
,	NULL AS receipt_date
,	'' AS approval_code
,	'' AS waste_code
,	Receipt_OB.manifest as outbound_manifest
,	Receipt_OB.manifest_line_id as outbound_manifest_line_id
,	Receipt_OB.tsdf_approval_code
,	ContainerDestination.treatment_id
,	Treatment.treatment_desc
,	Company.company_name
,	ProfitCenter.profit_ctr_name
,   Container.container_weight  as container_weight
,	Receipt_OB.manifest_line as outbound_manifest_line
,	0 as container_id
,	0 as sequence_id
,   ContainerDestination.container_percent
,	Container.staging_row
FROM Receipt Receipt_OB
JOIN Company
	ON Company.company_id = Receipt_OB.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt_OB.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt_OB.profit_ctr_id
JOIN ContainerDestination
	ON ContainerDestination.company_id = Receipt_OB.company_id
	AND ContainerDestination.profit_ctr_id = Receipt_OB.profit_ctr_id
	AND ContainerDestination.tracking_num = dbo.fn_container_receipt(Receipt_OB.receipt_id, Receipt_OB.line_id)
	AND ContainerDestination.container_type = 'S'
LEFT OUTER JOIN Container 
	ON ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.company_id = Container.company_id
    AND ContainerDestination.container_id = Container.container_id
    AND Container.container_type = 'S'
    AND ContainerDestination.receipt_id = Container.receipt_id
    AND ContainerDestination.line_id = Container.line_id
LEFT OUTER JOIN Treatment
	ON Treatment.company_id = ContainerDestination.company_id
	AND Treatment.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
WHERE	(@company_id = 0 OR Receipt_OB.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt_OB.profit_ctr_id = @profit_ctr_id)
	AND Receipt_OB.trans_mode = 'O'
	AND Receipt_OB.trans_type IN ('D','X')
	AND Receipt_OB.receipt_id BETWEEN @receipt_from AND @receipt_to
	AND Receipt_OB.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt_OB.manifest BETWEEN @manifest_from AND @manifest_to
	AND ((Receipt_OB.manifest_flag = 'X' AND Receipt_OB.customer_id IS NULL) OR Receipt_OB.customer_id BETWEEN @cust_id_from AND @cust_id_to)
	AND ((Receipt_OB.manifest_flag = 'X' AND Receipt_OB.tsdf_approval_code IS NULL) OR Receipt_OB.tsdf_approval_code BETWEEN @tsdf_approval_code_from AND @tsdf_approval_code_to)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_inbound_receipt_detail_for_outbound_receipts] TO [EQAI]
    AS [dbo];

