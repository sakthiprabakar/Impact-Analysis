DROP PROCEDURE IF EXISTS [dbo].[sp_rpt_batch_revenue_billing_detail]
GO

CREATE PROCEDURE sp_rpt_batch_revenue_billing_detail
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@location			varchar(15)
,	@tracking_num		varchar(15)
AS
/***************************************************************************************
DevOps 74045
This SP reports the amount of revenue collected for the specified batch.

Filename:	L:\IT Apps\SQL-Deploy\Prod\NTSQL1\Plt_AI\Procedures\sp_rpt_batch_revenue_billing_detail.sql
PB Object(s):	r_batch_revenue_billing_detail

LOAD TO PLT_AI

02/01/2024 Kamendra	Created

sp_rpt_batch_revenue_billing_detail 21, 0, '2019-08-01', '2019-08-31', '701', 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT
	Batch.location
,	Batch.tracking_num
,	ContainerDestination.cycle
,	Receipt.trans_mode
,	ContainerDestination.receipt_id
,	ContainerDestination.line_id
,	ContainerDestination.container_id
,	ContainerDestination.sequence_id
,	Receipt.receipt_date
,	NULL AS TSDF_code
,	COALESCE((SELECT container_size FROM Container, billunit 
				WHERE container_size = bill_unit_code 
					AND container_size <> '' 
					AND receipt.receipt_id = container.receipt_id 
					AND receipt.line_id = container.line_id 
					AND receipt.company_id = container.company_id
					AND receipt.profit_ctr_id = container.profit_ctr_id
					AND container.container_id = containerdestination.container_id 
					AND receipt.receipt_id = containerdestination.receipt_id 
					AND receipt.line_id = containerdestination.line_id 
					AND receipt.profit_ctr_id = containerdestination.profit_ctr_id 
					AND receipt.company_id = containerdestination.company_id), 
			(SELECT bill_unit_code FROM ReceiptPrice 
				WHERE receipt.receipt_id = receiptprice.receipt_id 
					AND receipt.line_id = receiptprice.line_id 
					AND receipt.profit_ctr_id = receiptprice.profit_ctr_id
					AND receipt.company_id = receiptprice.company_id
					AND price_id = (SELECT MIN(price_id) FROM receiptprice 
										WHERE receipt.receipt_id = receiptprice.receipt_id 
											AND receipt.profit_ctr_id = receiptprice.profit_ctr_id
											AND receipt.company_id = receiptprice.company_id
											AND receipt.line_id = receiptprice.line_id)
			)) AS bill_unit_code
,	CASE WHEN Receipt.bulk_flag = 'T' THEN (((ContainerDestination.container_percent * Receipt.quantity) / 100))
									  ELSE ((ContainerDestination.container_percent / 100)) END AS quantity
,	ContainerDestination.treatment_id
,	CASE ContainerDestination.status WHEN 'N' THEN 'Not Complete' ELSE 'Complete' END AS status
,	Treatment.treatment_desc
,	Receipt.approval_code
,	ISNULL(Generator.EPA_ID,'') AS EPA_ID
,	ISNULL(Generator.generator_name,'') AS generator_name
,	Receipt.manifest
,	Receipt.bulk_flag
,	ContainerDestination.container_type
,	CONVERT(money, (select sum(consolidation_value) from dbo.fn_container_consolidation_value(ContainerDestination.company_id, ContainerDestination.profit_ctr_id, ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id) )) as revenue
,	CONVERT(money, 0.0) AS cost_disposal
,	CONVERT(money, 0.0) AS cost_lab
,	CONVERT(money, 0.0) AS cost_process
,	CONVERT(money, 0.0) AS cost_surcharge
,	CONVERT(money, 0.0) AS cost_trans
,	CONVERT(varchar(15), ContainerDestination.receipt_id) + '-' + CONVERT(varchar(15), ContainerDestination.line_id) AS Container
,	Receipt.company_id AS company_id
,	Receipt.profit_ctr_id AS profit_ctr_id
,	(SELECT dbo.fn_receipt_weight_line(ContainerDestination.receipt_id,	ContainerDestination.line_id, @profit_ctr_id, @company_id)) AS total_lbs
,	Receipt.container_count AS total_drums
, 	CAST(0 AS MONEY) AS invoice_amount
, 	CAST(0 AS MONEY) AS surcharge
INTO #tmp
FROM Receipt
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
JOIN Batch
	ON Batch.company_id = Receipt.company_id
	AND Batch.profit_ctr_id = Receipt.profit_ctr_id
	AND Batch.location = ContainerDestination.location
	AND Batch.tracking_num = ContainerDestination.tracking_num
	AND Batch.status <> 'V'
	AND (@location = 'ALL' OR Batch.location = @location)
	AND (@tracking_num = 'ALL' OR Batch.tracking_num = @tracking_num)
	AND Batch.date_opened BETWEEN @date_from AND @date_to
LEFT OUTER JOIN Treatment
	ON Treatment.company_id = Receipt.company_id
	AND Treatment.profit_ctr_id = Receipt.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'

UNION ALL

SELECT DISTINCT
	Batch.location
,	Batch.tracking_num
,	ContainerDestination.cycle
,	'I' AS trans_mode
,	ContainerDestination.receipt_id
,	ContainerDestination.line_id
,	ContainerDestination.container_id
,	ContainerDestination.sequence_id
,	ContainerDestination.date_added AS receipt_date
,	NULL AS TSDF_code
,	'DM55' AS bill_unit_code
,	1 AS quantity
,	ContainerDestination.treatment_id
,	CASE ContainerDestination.status WHEN 'N' THEN 'Not Complete' ELSE 'Complete' END AS status
,	Treatment.treatment_desc
,	'' AS approval_code
,	'' AS EPA_ID
,	'' AS generator_name
,	'' AS manifest
,	'F' AS bulk_flag
,	ContainerDestination.container_type
, convert(money, (select sum(consolidation_value) from dbo.fn_container_consolidation_value(ContainerDestination.company_id, ContainerDestination.profit_ctr_id, ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id) ))
as revenue

,	CONVERT(money, 0.0) AS cost_disposal
,	CONVERT(money, 0.0) AS cost_lab
,	CONVERT(money, 0.0) AS cost_process
,	CONVERT(money, 0.0) AS cost_surcharge
,	CONVERT(money, 0.0) AS cost_trans
,	dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id) AS Container
,	Batch.company_id AS company_id
,	Batch.profit_ctr_id AS profit_ctr_id
, 	CAST(0 AS MONEY) AS total_lbs
,	CAST(0 AS INT) AS total_drums
, 	CAST(0 AS MONEY) AS invoice_amount
, 	CAST(0 AS MONEY) AS surcharge
FROM Batch
JOIN ContainerDestination
	ON ContainerDestination.company_id = Batch.company_id
	AND ContainerDestination.profit_ctr_id = Batch.profit_ctr_id
	AND ContainerDestination.location = Batch.location
	AND ContainerDestination.tracking_num = Batch.tracking_num
	AND ContainerDestination.container_type = 'S'
	AND ContainerDestination.status ='C'
LEFT OUTER JOIN Treatment
	ON Treatment.company_id = Batch.company_id
	AND Treatment.profit_ctr_id = Batch.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
WHERE	(@company_id = 0 OR Batch.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Batch.profit_ctr_id = @profit_ctr_id)
	AND (@location = 'ALL' OR Batch.location = @location)
	AND (@tracking_num = 'ALL' OR Batch.tracking_num = @tracking_num)
	AND Batch.date_opened BETWEEN @date_from AND @date_to
	AND Batch.status <> 'V'

UNION ALL

SELECT DISTINCT
	Batch.location
,	Batch.tracking_num
,	99 AS cycle
,	Receipt.trans_mode
,	Receipt.receipt_id
,	Receipt.line_id
,	NULL AS container_id
,	NULL AS sequence_id
,	Receipt.receipt_date
,	Receipt.TSDF_code AS TSDF_code
,	Receipt.bill_unit_code
,	Receipt.quantity
,	NULL AS treatment_id
,	'Complete' AS status
,	NULL AS treatment_desc
,	COALESCE(Receipt.TSDF_approval_code, Receipt.approval_code) AS approval_code
,	Generator.EPA_ID
,	Generator.generator_name
,	Receipt.manifest
,	Receipt.bulk_flag
,	NULL AS container_type
,	CASE cost_disposal WHEN 0.0 THEN -cost_disposal_est ELSE -cost_disposal END
		+ CASE cost_lab WHEN 0.0 THEN -cost_lab_est ELSE -cost_lab END
		+ CASE cost_process WHEN 0.0 THEN -cost_process_est ELSE -cost_process END
		+ CASE cost_surcharge WHEN 0.0 THEN -cost_surcharge_est ELSE -cost_surcharge END
		+ CASE cost_trans WHEN 0.0 THEN -cost_trans_est ELSE -cost_trans END AS revenue
,	CASE cost_disposal WHEN 0.0 THEN -cost_disposal_est ELSE -cost_disposal END AS cost_disposal
,	CASE cost_lab WHEN 0.0 THEN -cost_lab_est ELSE -cost_lab END AS cost_lab
,	CASE cost_process WHEN 0.0 THEN -cost_process_est ELSE -cost_process END cost_process
,	CASE cost_surcharge WHEN 0.0 THEN -cost_surcharge_est ELSE -cost_surcharge END cost_surcharge
,	CASE cost_trans WHEN 0.0 THEN -cost_trans_est ELSE -cost_trans END cost_trans
,	CONVERT(varchar(15), Receipt.receipt_id) + '-' + CONVERT(varchar(15), Receipt.line_id) AS Container
,	Receipt.company_id AS company_id
,	Receipt.profit_ctr_id AS profit_ctr_id
,	(SELECT dbo.fn_receipt_weight_line(Receipt.receipt_id,	Receipt.line_id, @profit_ctr_id, @company_id)) AS total_lbs
,	Receipt.container_count AS total_drums
, 	CAST(0 AS MONEY) AS invoice_amount
, 	CAST(0 AS MONEY) AS surcharge
FROM Receipt
JOIN Batch
	ON Batch.company_id = Receipt.company_id
	AND Batch.profit_ctr_id = Receipt.profit_ctr_id
	AND Batch.location = Receipt.location
	AND Batch.tracking_num = Receipt.tracking_num
	AND Batch.status <> 'V'
	AND Batch.location = Receipt.location
	AND Batch.tracking_num = Receipt.tracking_num
	AND Batch.date_opened BETWEEN @date_from AND @date_to
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.trans_mode = 'O'
	AND (@location = 'ALL' OR Receipt.location = @location)
	AND (@tracking_num = 'ALL' OR Receipt.tracking_num = @tracking_num)


UPDATE temp
SET temp.invoice_amount = (SELECT SUM(COALESCE(ReceiptPrice.total_extended_amt, CAST(0 AS MONEY))) 
							FROM ReceiptPrice
							WHERE ReceiptPrice.company_id = temp.company_id
							AND ReceiptPrice.profit_ctr_id = temp.profit_ctr_id
							AND ReceiptPrice.receipt_id = temp.receipt_id
							AND ReceiptPrice.line_id = temp.line_id)
FROM #tmp AS temp
	
UPDATE temp
SET temp.surcharge = (SELECT SUM(dbo.fn_ensr_amt_receipt_line(company_id, profit_ctr_id, receipt_id, line_id, price_id))
						FROM billing
						WHERE billing.company_id = temp.company_id
						AND billing.profit_ctr_id = temp.profit_ctr_id
						AND billing.receipt_id = temp.receipt_id
						AND billing.line_id = temp.line_id)	
FROM #tmp AS temp

SELECT 
	location
,	tracking_num
,	cycle
,	trans_mode
,	receipt_id
,	line_id
,	receipt_date
,	TSDF_code
,	bill_unit_code
,	#tmp.status as status
,	treatment_id
,	treatment_desc
,	approval_code
,	#tmp.EPA_ID
,	generator_name
,	manifest
,	bulk_flag
,	container_type
,	SUM(quantity) AS quantity
,	SUM(cost_disposal) AS cost_disposal
,	SUM(cost_lab) AS cost_lab
,	SUM(cost_process) AS cost_process
,	SUM(cost_surcharge) AS cost_surcharge
,	SUM(cost_trans) AS cost_trans
,	SUM(revenue) AS revenue
,	Container
,	#tmp.company_id
,	#tmp.profit_ctr_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
,	COALESCE(total_lbs, CAST(0 AS MONEY)) AS total_lbs
,	COALESCE(total_drums, CAST(0 AS INT)) AS total_drums
,	COALESCE(invoice_amount, CAST(0 AS MONEY)) AS invoice_amount
,	COALESCE(surcharge, CAST(0 AS MONEY)) AS surcharge
FROM #tmp
JOIN Company
	ON Company.company_id = #tmp.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = #tmp.company_id
	AND ProfitCenter.profit_ctr_ID = #tmp.profit_ctr_id
GROUP BY
	location
,	tracking_num
,	cycle
,	trans_mode
,	receipt_id
,	line_id
,	receipt_date
,	TSDF_code
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
,	container
,	#tmp.company_id
,	#tmp.profit_ctr_ID
,	company_name
,	profit_ctr_name
,	total_lbs
,	total_drums
,	invoice_amount
,	surcharge
ORDER BY location, tracking_num, cycle, bulk_flag, line_id ASC
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_batch_revenue_billing_detail] TO [EQAI]
GO	