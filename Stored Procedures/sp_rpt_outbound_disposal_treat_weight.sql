CREATE PROCEDURE sp_rpt_outbound_disposal_treat_weight
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
PB Object: r_outbound_disposal_treat_weight
08/20/2004 SCC	Created
12/09/2004 MK	Modified ticket_id, drum references, DrumHeader, and DrumDetail
03/15/2005 MK	Fixed tracking_num compare to receipt_id and line_id
09/23/2005 MK	Incorporated more arguments for select
11/01/2010 SK	Added Company_ID as input argument, added joins to company_ID wherever required
				moved to Plt_AI

sp_rpt_outbound_disposal_treat_weight 21, 0, '9/1/2005','9/21/2005', 1, 999999, 625077, 625077, '0', 'ZZZZZZZZ', '0', 'ZZZ'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT 
	Receipt.receipt_date
,	Receipt.manifest
,	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Receipt.tsdf_code
,	Receipt.bulk_flag
,	Receipt.quantity
,	Receipt.bill_unit_code
INTO	#outbound_receipt
FROM	Receipt 
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.trans_mode = 'O'
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.receipt_id BETWEEN @receipt_id_from AND @receipt_id_to
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Receipt.manifest BETWEEN @manifest_from AND @manifest_to
	AND Receipt.tsdf_approval_code BETWEEN @tsdf_approval_from AND @tsdf_approval_to

-- These are the treatments and weights from bulk receipts
SELECT	
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.treatment_id, 
	Receipt.bulk_flag,
	'R' as container_type,
	#outbound_receipt.receipt_id as outbound_receipt_id,
	#outbound_receipt.line_id as outbound_line_id,
	#outbound_receipt.tsdf_code as outbound_tsdf_code,
	IsNull(Receipt.quantity,0) * IsNull(BillUnit.pound_conv,0) as weight
INTO #inbound_receipt
FROM Receipt
JOIN BillUnit
	ON BillUnit.bill_unit_code = Receipt.bill_unit_code
JOIN #outbound_receipt
	ON #outbound_receipt.company_id = Receipt.company_id
	AND #outbound_receipt.profit_ctr_id = Receipt.profit_ctr_id
	AND #outbound_receipt.receipt_id = Receipt.receipt_id
	AND #outbound_receipt.line_id = Receipt.ref_line_id
	AND #outbound_receipt.tsdf_code = Receipt.location
WHERE Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status = 'A' 
	AND Receipt.bulk_flag = 'T'
	
UNION ALL

-- These are the treatments and weights from nonbulk receipts
SELECT	
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	CD.treatment_id, 
	Receipt.bulk_flag,
	CD.container_type,
	#outbound_receipt.receipt_id as outbound_receipt_id,
	#outbound_receipt.line_id as outbound_line_id,
	#outbound_receipt.tsdf_code as outbound_tsdf_code,
	IsNull(Sum(container_weight),0) as weight
FROM Receipt
JOIN ContainerDestination CD
	ON CD.company_id = Receipt.company_id
	AND CD.profit_ctr_id = Receipt.profit_ctr_id
	AND CD.receipt_id = Receipt.receipt_id
	AND CD.line_id = Receipt.line_id
	AND CD.disposal_date IS NOT NULL
	AND CD.treatment_id IS NOT NULL
	AND CD.container_type = 'R'
	AND CD.location_type = 'O'
JOIN Container C
	ON C.company_id = CD.company_id
	AND C.profit_ctr_id = CD.profit_ctr_id
	AND C.receipt_id = CD.receipt_id
	AND C.line_id = CD.line_id
	AND C.container_id = CD.container_id
	AND C.status = 'C'
JOIN #outbound_receipt
	ON #outbound_receipt.company_id = CD.company_id
	AND #outbound_receipt.profit_ctr_id = CD.profit_ctr_id
	AND convert(varchar(10),#outbound_receipt.receipt_id) + '-' + convert(varchar(10),#outbound_receipt.line_id) = CD.tracking_num
	AND #outbound_receipt.tsdf_code = CD.location
WHERE Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status = 'A'
	AND Receipt.bulk_flag = 'F'
GROUP BY 
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	CD.treatment_id, 
	CD.container_type,
	Receipt.bulk_flag,
	#outbound_receipt.receipt_id,
	#outbound_receipt.line_id,
	#outbound_receipt.tsdf_code
	
UNION ALL

SELECT	
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.treatment_id, 
	Receipt.bulk_flag,
	CD.container_type,
	#outbound_receipt.receipt_id as outbound_receipt_id,
	#outbound_receipt.line_id as outbound_line_id,
	#outbound_receipt.tsdf_code as outbound_tsdf_code,
	IsNull(Sum(container_weight),0) as weight
FROM Receipt
JOIN ContainerDestination CD
	ON CD.company_id = Receipt.company_id
	AND CD.profit_ctr_id = Receipt.profit_ctr_id
	AND CD.receipt_id = Receipt.receipt_id
	AND CD.line_id = Receipt.line_id
	AND CD.disposal_date IS NOT NULL
	AND CD.treatment_id IS NULL
	AND CD.container_type = 'R'
	AND CD.location_type = 'O'
JOIN Container C
	ON C.company_id = CD.company_id
	AND C.profit_ctr_id = CD.profit_ctr_id
	AND C.receipt_id = CD.receipt_id
	AND C.line_id = CD.line_id
	AND C.container_id = CD.container_id
	AND C.status = 'C'
JOIN #outbound_receipt
	ON #outbound_receipt.company_id = CD.company_id
	AND #outbound_receipt.profit_ctr_id = CD.profit_ctr_id
	AND convert(varchar(10),#outbound_receipt.receipt_id) + '-' + convert(varchar(10),#outbound_receipt.line_id) = CD.tracking_num
	AND #outbound_receipt.tsdf_code = CD.location
WHERE Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status = 'A'
	AND Receipt.bulk_flag = 'F'
GROUP BY 
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.treatment_id, 
	CD.container_type,
	Receipt.bulk_flag,
	#outbound_receipt.receipt_id,
	#outbound_receipt.line_id,
	#outbound_receipt.tsdf_code

UNION ALL

SELECT	
	C.receipt_id,
	C.line_id,
	C.company_id,
	C.profit_ctr_id,
	CD.treatment_id, 
	'F' as bulk_flag,
	CD.container_type,
	#outbound_receipt.receipt_id as outbound_receipt_id,
	#outbound_receipt.line_id as outbound_line_id,
	#outbound_receipt.tsdf_code as outbound_tsdf_code,
	IsNull(Sum(container_weight),0) as weight
FROM Container C
JOIN ContainerDestination CD
	ON CD.company_id = C.company_id
	AND CD.profit_ctr_id = C.profit_ctr_id
	AND CD.receipt_id = C.receipt_id
	AND CD.line_id = C.line_id
	AND CD.container_id = C.container_id
	AND CD.location_type = 'O'
	AND CD.treatment_id IS NOT NULL
	AND CD.disposal_date IS NOT NULL
	AND CD.container_type = 'S'
JOIN #outbound_receipt
	ON #outbound_receipt.company_id = CD.company_id
	AND #outbound_receipt.profit_ctr_id = CD.profit_ctr_id
	AND #outbound_receipt.tsdf_code = CD.location
	AND convert(varchar(10),#outbound_receipt.receipt_id) + '-' + convert(varchar(10),#outbound_receipt.line_id) = CD.tracking_num
WHERE C.status = 'C'
GROUP BY 
	C.receipt_id,
	C.line_id,
	C.company_id,
	C.profit_ctr_id,
	CD.treatment_id,
	CD.container_type,
	#outbound_receipt.receipt_id,
	#outbound_receipt.line_id,
	#outbound_receipt.tsdf_code

-- Return results
SELECT DISTINCT 
	#outbound_receipt.receipt_date,   
	#outbound_receipt.manifest,   
	#outbound_receipt.receipt_id,   
	#outbound_receipt.line_id, 
	#outbound_receipt.company_id,
	#outbound_receipt.profit_ctr_id,
	#outbound_receipt.tsdf_code, 
	#outbound_receipt.bulk_flag,
	#outbound_receipt.quantity,
	#outbound_receipt.bill_unit_code,
	#inbound_receipt.receipt_id as inbound_receipt_id,
	#inbound_receipt.line_id as inbound_line_id,
	#inbound_receipt.treatment_id as inbound_treatment_id, 
	#inbound_receipt.bulk_flag as inbound_bulk_flag,
	#inbound_receipt.container_type as inbound_container_type,
	#inbound_receipt.weight as inbound_weight,
	Treatment.treatment_desc,
	Company.company_name,
	ProfitCenter.profit_ctr_name
FROM #outbound_receipt
JOIN Company
	ON Company.company_id = #outbound_receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = #outbound_receipt.company_id
	AND ProfitCenter.profit_ctr_ID = #outbound_receipt.profit_ctr_id
JOIN #inbound_receipt
	ON #inbound_receipt.outbound_receipt_id = #outbound_receipt.receipt_id
	AND #inbound_receipt.outbound_line_id =  #outbound_receipt.line_id
	AND #inbound_receipt.outbound_tsdf_code = #outbound_receipt.tsdf_code
	AND #inbound_receipt.company_id = #outbound_receipt.company_id
	AND #inbound_receipt.profit_ctr_id = #outbound_receipt.profit_ctr_id
JOIN Treatment
	ON Treatment.treatment_id = #inbound_receipt.treatment_id
	AND Treatment.company_id = #inbound_receipt.company_id
	AND Treatment.profit_ctr_id = #inbound_receipt.profit_ctr_id
ORDER BY 
	#inbound_receipt.treatment_id, 
	#inbound_receipt.bulk_Flag, 
	#outbound_Receipt.receipt_id, 
	#outbound_Receipt.line_id, 
	#inbound_receipt.receipt_id, 
	#inbound_receipt.line_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_outbound_disposal_treat_weight] TO [EQAI]
    AS [dbo];

