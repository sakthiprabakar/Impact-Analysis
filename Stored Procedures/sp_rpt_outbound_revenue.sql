CREATE PROCEDURE sp_rpt_outbound_revenue
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@cust_id_from		int
,	@cust_id_to			int
,	@ob_receipt_from	int
,	@ob_receipt_to		int
,	@manifest_from		varchar(15)
,	@manifest_to		varchar(15)
,	@tsdf_approval_code_from	varchar(40)
,	@tsdf_approval_code_to		varchar(40) 
AS
/****************
This SP reports the amount of revenue collected for the specified outbound receipt

08/30/2005 MK  Created from sp_rpt_batch_revenue
10/20/2010 SK  Modified to run on Plt_AI, replaced *= joins with standard ANSI joins
			   Moved on Plt_AI
06/06/2011 SK  Set Read Uncommitted to resolve the blocking issue, Added company_id joins where missing
10/20/2015 AM  Do not include voided status receipts.
05/01/2020 PRK	Modified to use the recursive function (dbo.fn_container_consolidation_value) that gets the revenue for an inbound container	
				taking into account gathering of consolidations.
						   
sp_rpt_outbound_revenue 21, 0, '9/1/2005','9/21/2005', 1, 999999, 625077, 625077, '0', 'ZZZZZZZZ', '0', 'ZZZ'
sp_rpt_outbound_revenue 21, 0, '9/1/2005','9/1/2005', 1, 999999, 1, 999999, '0', 'ZZZZZZZZ', '0', 'ZZZ'

sp_rpt_outbound_revenue 21, 0, '4/16/2020','4/16/2020', 1, 999999, 2092612, 2092612, '0', 'ZZZZZZZZ', '0', 'ZZZ'
sp_rpt_outbound_revenue 21, 0, '1/1/2020','4/16/2020', 1, 999999, 2080452, 2080452, '0', 'ZZZZZZZZ', '0', 'ZZZ'
sp_rpt_outbound_revenue 32, 0, '1/1/2018','1/1/2019', 1, 999999, 48924, 48924, '0', 'ZZZZZZZZ', '0', 'ZZZ'



******************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@company	varchar(35)
,	@profit_ctr	varchar(50)

SELECT @company = company_name
, @profit_ctr = profit_ctr_name
FROM Company 
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Company.company_id
	AND ProfitCenter.profit_ctr_ID = @profit_ctr_id
WHERE Company.company_id = @company_id


SELECT DISTINCT
	OBR.Receipt_id as OB_receipt_id
,	OBR.Line_id as OB_line_id
,	OBR.manifest as OB_manifest
,	OBR.TSDF_code
,	OBR.Tsdf_approval_code
,	ContainerDestination.receipt_id
,	ContainerDestination.line_id
,	ContainerDestination.container_id
,	ContainerDestination.sequence_id
,	Receipt.receipt_date
,	COALESCE((select container_size from Container,billunit 
				where container_size = bill_unit_code 
					and container_size <> '' 
					and receipt.receipt_id = container.receipt_id 
					and receipt.line_id = container.line_id 
					and receipt.profit_ctr_id = container.profit_ctr_id
					and receipt.company_id = container.company_id
					and container.container_id = containerdestination.container_id 
					and receipt.receipt_id = containerdestination.receipt_id 
					and receipt.line_id = containerdestination.line_id 
					and receipt.profit_ctr_id = containerdestination.profit_ctr_id 
					and receipt.company_id = containerdestination.company_id), 
			(select bill_unit_code from ReceiptPrice 
				where receipt.receipt_id = receiptprice.receipt_id 
					and receipt.line_id = receiptprice.line_id 
					and receipt.profit_ctr_id = receiptprice.profit_ctr_id 
					and receipt.company_id = receiptprice.company_id
					and price_id = (select min(price_id) from receiptprice 
										where receipt.receipt_id = receiptprice.receipt_id 
											and receipt.profit_ctr_id = receiptprice.profit_ctr_id 
											and receipt.company_id = receiptprice.company_id
											and receipt.line_id = receiptprice.line_id))) 
	as bill_unit_code
,	CASE WHEN Receipt.bulk_flag = 'T' THEN (((ContainerDestination.container_percent/100) * Receipt.quantity))
									  ELSE ((ContainerDestination.container_percent/100)) END as quantity
,	ContainerDestination.treatment_id
,	CASE ContainerDestination.status WHEN 'N' THEN 'Not Complete' ELSE 'Complete' END as status
,	Treatment.treatment_desc
,	Receipt.approval_code
,	IsNull(Generator.EPA_ID,'') AS EPA_ID
,	IsNull(Generator.generator_name,'') AS generator_name
,	Receipt.manifest
,	Receipt.bulk_flag
,	ContainerDestination.container_type

--,	CONVERT(money,(CONVERT(money, (((select sum(IsNull(ReceiptPrice.waste_extended_amt, 0)) from receiptprice 
--										where receipt.receipt_id = receiptprice.receipt_id 
--											and receipt.line_id = receiptprice.line_id 
--											and receipt.company_id = receiptprice.company_id
--											and receipt.profit_ctr_id = receiptprice.profit_ctr_id)/Receipt.container_count) * 
--									(ContainerDestination.container_percent/100))))) 
--	as revenue
,

--This next line calls the new container inbound revenue function instead of the old method for gathering the inbound revenue that did not do the recursive check
--(select sum(value) from dbo.fn_container_inbound_revenue(ContainerDestination.company_id, ContainerDestination.profit_ctr_id, ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id) ) as revenue
(select sum(consolidation_value) from dbo.fn_container_consolidation_value(ContainerDestination.company_id, ContainerDestination.profit_ctr_id, ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id) ) as revenue
,	CONVERT(varchar(15), ContainerDestination.receipt_id) + '-' + CONVERT(varchar(15), ContainerDestination.line_id) as Container
,	OBR.tracking_num
,	OBR.location
,	OBR.cycle
--,	Receipt.company_id AS company_id
--,	Receipt.profit_ctr_id AS profit_ctr_id
INTO #tmp
FROM Receipt
JOIN Receipt OBR
	ON OBR.company_id = Receipt.company_id
	AND OBR.profit_ctr_id = Receipt.profit_ctr_id
	AND OBR.receipt_date BETWEEN @date_from AND @date_to
	AND OBR.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND OBR.manifest BETWEEN @manifest_from AND @manifest_to
	AND OBR.tsdf_approval_code BETWEEN @tsdf_approval_code_from AND @tsdf_approval_code_to
	AND OBR.receipt_id BETWEEN @ob_receipt_from AND @ob_receipt_to
JOIN Container
	ON Container.company_id = Receipt.company_id
	AND Container.profit_ctr_id = Receipt.profit_ctr_id
	AND Container.receipt_id = Receipt.receipt_id
	AND Container.line_id = Receipt.line_id
JOIN ContainerDestination
	ON ContainerDestination.company_id = Receipt.company_id
	AND ContainerDestination.profit_ctr_id = Receipt.profit_ctr_id
	AND ContainerDestination.receipt_id = Receipt.receipt_id
	AND ContainerDestination.line_id = Receipt.line_id
	AND ContainerDestination.container_type = Container.container_type
	AND ContainerDestination.status = 'C'
	AND ContainerDestination.container_type = 'R'
	AND ContainerDestination.tracking_num = CONVERT(varchar(15), OBR.receipt_id) + '-' + Convert(varchar(15), OBR.line_id)
LEFT OUTER JOIN Treatment
	ON Treatment.company_id = Receipt.company_id
	AND Treatment.profit_ctr_id = Receipt.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
WHERE Receipt.company_id = @company_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'

UNION ALL

SELECT DISTINCT
	OBR.Receipt_id as OB_receipt_id
,	OBR.Line_id as OB_line_id
,	OBR.manifest as OB_manifest
,	OBR.TSDF_code
,	OBR.Tsdf_approval_code
,	ContainerDestination.receipt_id
,	ContainerDestination.line_id
,	ContainerDestination.container_id
,	ContainerDestination.sequence_id
,	ContainerDestination.date_added as receipt_date
,	'DM55' as bill_unit_code
,	1 as quantity
,	ContainerDestination.treatment_id
,	CASE ContainerDestination.status WHEN 'N' THEN 'Not Complete' ELSE 'Complete' END as status
,	Treatment.treatment_desc
,	'' AS approval_code
,	'' AS EPA_ID
,	'' AS generator_name
,	'' AS manifest
,	'F' as bulk_flag
,	ContainerDestination.container_type
--This next line calls the new container inbound revenue function instead of the old method for gathering the inbound revenue that did not do the recursive check
--,	(select sum(value) from dbo.fn_container_inbound_revenue(ContainerDestination.company_id, ContainerDestination.profit_ctr_id, ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id) ) as revenue --CONVERT(money, 0) AS revenue
, (select sum(consolidation_value) from dbo.fn_container_consolidation_value(ContainerDestination.company_id, ContainerDestination.profit_ctr_id, ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id) ) as revenue
,	dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id) as Container
,	tracking_num = null
,	location = null
,	cycle = null
--,	OBR.company_id AS company_id
--,	OBR.profit_ctr_id AS profit_ctr_id
FROM Receipt OBR
JOIN ContainerDestination
	ON ContainerDestination.company_id = OBR.company_id
	AND ContainerDestination.profit_ctr_id = OBR.profit_ctr_id
	AND ContainerDestination.status = 'C'
	AND ContainerDestination.container_type = 'S'
	AND ContainerDestination.tracking_num = CONVERT(varchar(15), OBR.receipt_id) + '-' + Convert(varchar(15), OBR.line_id)
LEFT OUTER JOIN Treatment
	ON Treatment.company_id = OBR.company_id
	AND Treatment.profit_ctr_id = OBR.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
WHERE	OBR.company_id = @company_id
	AND OBR.profit_ctr_id = @profit_ctr_id
	AND OBR.receipt_date BETWEEN @date_from AND @date_to
	AND OBR.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND OBR.manifest BETWEEN @manifest_from AND @manifest_to
	AND OBR.tsdf_approval_code BETWEEN @tsdf_approval_code_from AND @tsdf_approval_code_to
	AND OBR.receipt_id BETWEEN @ob_receipt_from AND @ob_receipt_to
    
UNION ALL

SELECT DISTINCT
	OBR.Receipt_id as OB_receipt_id
,	OBR.Line_id as OB_line_id
,	OBR.manifest as OB_manifest
,	OBR.TSDF_code
,	OBR.Tsdf_approval_code
,	OBR.receipt_id
,	OBR.line_id
,	container_id = null
,	sequence_id = null
,	OBR.receipt_date
,	OBR.bill_unit_code
,	OBR.quantity
,	OBR.treatment_id
,	OBR.receipt_status
,	Treatment.treatment_desc
,	'' AS approval_code
,	'' AS EPA_ID
,	'' AS generator_name
,	'' AS manifest
,	'F' as bulk_flag
,	container_type = null
,	CONVERT(money, 0) AS revenue
,	Container = null
,	OBR.tracking_num
,	OBR.location
,	OBR.cycle
--,	OBR.company_id AS company_id
--,	OBR.profit_ctr_id AS profit_ctr_id
FROM Receipt OBR
LEFT OUTER JOIN Treatment
	ON Treatment.company_id = OBR.company_id
	AND Treatment.profit_ctr_id = OBR.profit_ctr_id
	AND Treatment.treatment_id = OBR.treatment_id
WHERE OBR.company_id = @company_id
	AND OBR.profit_ctr_id = @profit_ctr_id
	AND OBR.receipt_date BETWEEN @date_from AND @date_to
	AND OBR.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND OBR.manifest BETWEEN @manifest_from AND @manifest_to
	AND OBR.tsdf_approval_code BETWEEN @tsdf_approval_code_from AND @tsdf_approval_code_to
	AND OBR.receipt_id BETWEEN @ob_receipt_from AND @ob_receipt_to
	AND OBR.location is not null
	AND OBR.tracking_num is not null
	AND OBR.cycle is not null
    AND OBR.receipt_status <> 'V'
SELECT
	OB_receipt_id
,	OB_line_id
,	OB_manifest
,	TSDF_code
,	Tsdf_approval_code
,	receipt_id
,	line_id
,	receipt_date
,	bill_unit_code
,	#tmp.status
,	treatment_id
,	treatment_desc
,	approval_code
,	#tmp.EPA_ID
,	generator_name
,	manifest
,	bulk_flag
,	container_type
,	sum(IsNull(quantity, 0)) as quantity
,	SUM(IsNUll(revenue, 0)) as revenue
,	Container
,	tracking_num
,	location
,	cycle
,	@company_id AS company_id
,	@profit_ctr_id AS profit_ctr_id
,	@company AS company_name
,	@profit_ctr AS profit_ctr_name
FROM #tmp
GROUP BY
	OB_receipt_id
,	OB_line_id
,	OB_manifest
,	TSDF_code
,	Tsdf_approval_code
,	receipt_id
,	line_id
,	receipt_date
,	bill_unit_code
,	#tmp.status
,	treatment_id
,	treatment_desc
,	approval_code
,	#tmp.EPA_ID
,	generator_name
,	manifest
,	bulk_flag
,	container_type
,	Container
,	tracking_num
,	location
,	cycle
ORDER BY OB_receipt_id, OB_line_id, bulk_flag, receipt_id, line_id ASC
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_outbound_revenue] TO [EQAI]
    AS [dbo];

