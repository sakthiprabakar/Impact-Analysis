CREATE PROCEDURE sp_rpt_batch_revenue
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@location			varchar(15)
,	@tracking_num		varchar(15)
AS
/************************************************************************************************************
This SP reports the amount of revenue collected for the specified batch.

06/06/2004 SCC	Created
11/11/2004 MK	Changed generator_code to generator_id
12/29/2004 SCC	Changed for new container tracking
03/02/2005 LJT	Changed the revenue calculations to allocate per container.
03/22/2005 LJT	Modified to only include completed containers.
				Removed join on price_id - they didn't match up - was excluding records.
				Modified to use billunit from container or 1st on from receipt price instead of receipt.
				Modified to print 1 line per receipt line and sum the revenue and divide by numer of containers.
09/27/2005 MK	Added batch dates to input parameters and to select statement.
05/05/2006 MK	Modified quantity calculation to multiply * percent before dividing by 100 
				(always got 0 if percent < 100). Also applied to revenue calc.
01/31/2008 JDB	Added third select to the UNION, to include outbound receipts for the batch, in order
				to capture the costs from the outbound receipts.  Now returns new fields trans_mode,
				TSDF_code, and 5 cost fields from the outbound receipt.
10/18/2010 SK	Added Company_ID as input argument, added joins to company
				replaced *= joins with standard ANSI joins, formatted SP
				moved to Plt_AI
05/01/2020 PRK	Modified to use the recursive function (dbo.fn_container_consolidation_value) 
				that gets the revenue for an inbound container	taking into account gathering of consolidations.

sp_rpt_batch_revenue 32, 0, '2018-01-01', '2019-08-31', 'TANKER', '10'
sp_rpt_batch_revenue 32, 0, '2018-01-01', '2019-08-31', 'TANKER', '10'

sp_rpt_batch_revenue 21, 0, '2019-08-01', '2019-08-31', '701', 'ALL'
sp_rpt_batch_revenue 21, 0, '2019-08-01', '2019-08-31', '701', 'ALL'
************************************************************************************************************/
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
--,	CONVERT(money,(CONVERT(money, (((SELECT SUM(ReceiptPrice.waste_extended_amt) FROM receiptprice 
--										WHERE receipt.receipt_id = receiptprice.receipt_id 
--											AND receipt.line_id = receiptprice.line_id 
--											AND receipt.profit_ctr_id = receiptprice.profit_ctr_id
--											AND receipt.company_id = receiptprice.company_id)/Receipt.container_count) * 
--									(ContainerDestination.container_percent)/100)))) AS revenue
--This next line calls the new container inbound revenue function instead of the old method for gathering the inbound revenue that did not do the recursive check
,	CONVERT(money, (select sum(consolidation_value) from dbo.fn_container_consolidation_value(ContainerDestination.company_id, ContainerDestination.profit_ctr_id, ContainerDestination.receipt_id, ContainerDestination.line_id, ContainerDestination.container_id, ContainerDestination.sequence_id) )) as revenue
,	CONVERT(money, 0.0) AS cost_disposal
,	CONVERT(money, 0.0) AS cost_lab
,	CONVERT(money, 0.0) AS cost_process
,	CONVERT(money, 0.0) AS cost_surcharge
,	CONVERT(money, 0.0) AS cost_trans
,	CONVERT(varchar(15), ContainerDestination.receipt_id) + '-' + CONVERT(varchar(15), ContainerDestination.line_id) AS Container
,	Receipt.company_id AS company_id
,	Receipt.profit_ctr_id AS profit_ctr_id
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
--,	CONVERT(money, 0.0) AS revenue
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
ORDER BY location, tracking_num, cycle, bulk_flag, line_id ASC
GO

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_batch_revenue] TO [EQAI]
    AS [dbo];

