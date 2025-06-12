CREATE PROCEDURE sp_rpt_receipt_margin
	@company_id			int
,	@profit_ctr_id		int
,	@date_from 			datetime
,	@date_to 			datetime
,	@customer_id_from	int
,	@customer_id_to		int
AS
/***************************************************************************************
PB Object(s):	r_waste_revenue_margin

08/21/2004 SCC	Created
12/07/2004 MK	Modified ticket_id, drum references, DrumHeader, and DrumDetail
04/14/2005 JDB	Added bill_unit_code for TSDFApproval
03/20/2006 RG   added logic for new cost fields to use estimate vs actual
                based on cost flag.  removed container table from the 'from' clause
11/22/2010 SK	Modified to run on Plt_AI, added company_id as input arg, use tsdfapprovalprice table
				added joins to company_id, replaced *= joins with standard ansi joins

sp_rpt_receipt_margin 14, 4, '03/07/2005', '03/9/2005', 1, 999999
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @debug	int =0

-- These are the inbound bulk receipts
SELECT	
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.receipt_date,
	Receipt.bulk_flag,
	Receipt.bill_unit_code,
	IsNull(Receipt.quantity,0) as quantity,
	IsNull(ReceiptPrice.waste_extended_amt,0.0000) as amount,
	IsNull(BillUnit.gal_conv,1) as gal_conv,
	process_cost_per_gallon = IsNull((SELECT cost_per_gallon FROM ProcessLocation 
										WHERE Receipt.location = ProcessLocation.location 
										AND Receipt.company_id = ProcessLocation.company_id
										AND Receipt.profit_ctr_id = ProcessLocation.profit_ctr_id
										AND IsNull(Receipt.location_type,'U') = 'P'),0.000),
	Receipt.location_type,
	Receipt.location,
	Receipt.tracking_num,
	IsNull(Receipt.ref_line_id,0) as ref_line_id
INTO #inbound
FROM Receipt
JOIN ReceiptPrice
	ON ReceiptPrice.receipt_id = Receipt.receipt_id
	AND ReceiptPrice.line_id = Receipt.line_id
	AND ReceiptPrice.company_id = Receipt.company_id
	AND ReceiptPrice.profit_ctr_id = Receipt.profit_ctr_id
JOIN BillUnit
	ON BillUnit.bill_unit_code = Receipt.bill_unit_code
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.trans_mode = 'I' 
	AND Receipt.receipt_status = 'A' 
	AND Receipt.bulk_flag = 'T'
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_date between @date_from and @date_to
	AND Receipt.customer_id between @customer_id_from and @customer_id_to

UNION ALL

-- These are the inbound nonbulk receipts
SELECT	
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.receipt_date,
	Receipt.bulk_flag,
	Receipt.bill_unit_code,
	count(CD.container_id) as quantity,
	IsNull(ReceiptPrice.waste_extended_amt,0.0000) as amount,
	IsNull(BillUnit.gal_conv,1) as gal_conv,
	process_cost_per_gallon = IsNull((SELECT cost_per_gallon FROM ProcessLocation 
										WHERE Receipt.location = ProcessLocation.location
										AND Receipt.company_id = ProcessLocation.company_id
										AND Receipt.profit_ctr_id = ProcessLocation.profit_ctr_id
										AND IsNull(Receipt.location_type,'U') = 'P'),0),
	Receipt.location_type,
	CD.location,
	CD.tracking_num,
	IsNull(Receipt.ref_line_id,0) as ref_line_id
FROM Receipt
JOIN ReceiptPrice
	ON ReceiptPrice.receipt_id = Receipt.receipt_id
	AND ReceiptPrice.line_id = Receipt.line_id
	AND ReceiptPrice.company_id = Receipt.company_id
	AND ReceiptPrice.profit_ctr_id = Receipt.profit_ctr_id
JOIN BillUnit
	ON BillUnit.bill_unit_code = Receipt.bill_unit_code
JOIN ContainerDestination CD
	ON CD.receipt_id = Receipt.receipt_id
	AND CD.line_id = Receipt.line_id
	AND CD.company_id = Receipt.company_id
	AND CD.profit_ctr_id = Receipt.profit_ctr_id

WHERE (@company_id = 0 OR Receipt.company_id = @company_id)
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status = 'A' 
	AND Receipt.bulk_flag = 'F'
	AND Receipt.receipt_date between @date_from and @date_to
	AND Receipt.customer_id between @customer_id_from and @customer_id_to
GROUP BY 
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.receipt_date,
	Receipt.bulk_flag,
	Receipt.bill_unit_code,
	ReceiptPrice.waste_extended_amt,
	BillUnit.gal_conv,
	CD.profit_ctr_id,
	Receipt.location_type,
	Receipt.location,
	CD.location,
	CD.tracking_num,
	Receipt.ref_line_id

-- Get the outbound costs

IF @debug = 1
BEGIN
    print 'inbound table'
    select * from #inbound order by receipt_id
END 

SELECT 
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.tsdf_code,
	Receipt.tsdf_approval_code,
	Receipt.waste_stream,
	Receipt.bulk_flag,
	Receipt.bill_unit_code,
	Billunit.gal_conv,
	Receipt.quantity,
	Receipt.container_count,
	case when cost_flag = 'E' then IsNull((Receipt.cost_disposal_est * Receipt.quantity) / (IsNull(Receipt.quantity,1) * IsNull(BillUnit.gal_conv,1)), 0.000)
		 else IsNull((Receipt.cost_disposal * Receipt.quantity) / (IsNull(Receipt.quantity,1) * IsNull(BillUnit.gal_conv,1)), 0.000) 
		 end as cost_disposal_per_gallon,
	case when cost_flag = 'E' then IsNull((Receipt.cost_lab_est * Receipt.quantity) / (IsNull(Receipt.quantity,1) * IsNull(BillUnit.gal_conv,1)), 0.000)
		 else IsNull((Receipt.cost_lab * Receipt.quantity) / (IsNull(Receipt.quantity,1) * IsNull(BillUnit.gal_conv,1)), 0.000) 
		 end as cost_lab_per_gallon,
	case when cost_flag = 'E' then IsNull((Receipt.cost_process_est * Receipt.quantity) / (IsNull(Receipt.quantity,1) * IsNull(BillUnit.gal_conv,1)), 0.000)
		 else IsNull((Receipt.cost_process * Receipt.quantity) / (IsNull(Receipt.quantity,1) * IsNull(BillUnit.gal_conv,1)), 0.000) 
		 end as cost_process_per_gallon,
	case when cost_flag = 'E' then IsNull((Receipt.cost_surcharge_est * Receipt.quantity) / (IsNull(Receipt.quantity,1) * IsNull(BillUnit.gal_conv,1)), 0.000)
		  else IsNull((Receipt.cost_surcharge * Receipt.quantity) / (IsNull(Receipt.quantity,1) * IsNull(BillUnit.gal_conv,1)), 0.000) 
		  end as cost_surcharge_per_gallon,
	case when cost_flag = 'E' then IsNull((Receipt.cost_trans_est * Receipt.quantity) / (IsNull(Receipt.quantity,1) * IsNull(BillUnit.gal_conv,1)), 0.000)
		  else IsNull((Receipt.cost_trans * Receipt.quantity) / (IsNull(Receipt.quantity,1) * IsNull(BillUnit.gal_conv,1)), 0.000) 
		  end as cost_trans_per_gallon,
	tsdf_price_per_gallon = IsNull((TSDFApprovalPrice.price * Receipt.quantity) / (IsNull(Receipt.quantity,1) * IsNull(BillUnit.gal_conv,1)), 0.000),
	#inbound.receipt_id as inbound_receipt_id,
	#inbound.Line_id as inbound_line_id
INTO #outbound
FROM #inbound
JOIN Receipt
	ON Receipt.company_id = #inbound.company_id
	AND Receipt.profit_ctr_id = #inbound.profit_ctr_id
	AND Receipt.receipt_id = #inbound.receipt_id
	AND CONVERT(varchar(5), Receipt.line_id) = #inbound.ref_line_id
	AND Receipt.trans_mode = 'O'
	AND Receipt.receipt_status = 'A'
JOIN BillUnit
	ON BillUnit.bill_unit_code = Receipt.bill_unit_code
JOIN TSDFApproval
	ON TSDFApproval.tsdf_code = Receipt.tsdf_code
	AND TSDFApproval.TSDF_approval_code = Receipt.tsdf_approval_code
	AND TSDFApproval.waste_stream = Receipt.waste_stream
	AND TSDFApproval.bill_unit_code = Receipt.tsdf_approval_bill_unit_code
	AND TSDFApproval.company_id = Receipt.company_id
	AND TSDFApproval.profit_ctr_id = Receipt.profit_ctr_id 
	AND TSDFApproval.TSDF_approval_status = 'A'
JOIN TSDFApprovalPrice
	ON TSDFApprovalPrice.company_id = TSDFApproval.company_id
	AND TSDFApprovalPrice.profit_ctr_id = TSDFApproval.profit_ctr_id
	AND TSDFApprovalPrice.TSDF_approval_id = TSDFApproval.TSDF_approval_id
WHERE #inbound.bulk_flag = 'T'

UNION ALL

SELECT 
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.tsdf_code,
	Receipt.tsdf_approval_code,
	Receipt.waste_stream,
	Receipt.bulk_flag,
	Receipt.bill_unit_code,
	BillUnit.gal_conv,
	Receipt.quantity,
	Receipt.container_count,
	case when cost_flag = 'E' then IsNull((Receipt.cost_disposal_est * Receipt.container_count) / (IsNull(Receipt.container_count,1) * IsNull(BillUnit.gal_conv,1)), 0.000)
		 else IsNull((Receipt.cost_disposal * Receipt.container_count) / (IsNull(Receipt.container_count,1) * IsNull(BillUnit.gal_conv,1)), 0.000) 
		 end as cost_disposal_per_gallon,
	case when cost_flag = 'E' then IsNull((Receipt.cost_lab_est * Receipt.container_count) / (IsNull(Receipt.container_count,1) * IsNull(BillUnit.gal_conv,1)), 0.000)
		 else IsNull((Receipt.cost_lab * Receipt.container_count) / (IsNull(Receipt.container_count,1) * IsNull(BillUnit.gal_conv,1)), 0.000) 
		 end as cost_lab_per_gallon,
	case when cost_flag = 'E' then IsNull((Receipt.cost_process_est * Receipt.container_count) / (IsNull(Receipt.container_count,1) * IsNull(BillUnit.gal_conv,1)), 0.000)
		  else IsNull((Receipt.cost_process * Receipt.container_count) / (IsNull(Receipt.container_count,1) * IsNull(BillUnit.gal_conv,1)), 0.000) 
		  end as cost_process_per_gallon,
	case when cost_flag = 'E' then IsNull((Receipt.cost_surcharge_est * Receipt.container_count) / (IsNull(Receipt.container_count,1) * IsNull(BillUnit.gal_conv,1)), 0.000)
		  else IsNull((Receipt.cost_surcharge * Receipt.container_count) / (IsNull(Receipt.container_count,1) * IsNull(BillUnit.gal_conv,1)), 0.000) 
		  end as cost_surcharge_per_gallon,
	case when cost_flag = 'E' then IsNull((Receipt.cost_trans_est * Receipt.container_count) / (IsNull(Receipt.container_count,1) * IsNull(BillUnit.gal_conv,1)), 0.000)
		   else IsNull((Receipt.cost_trans * Receipt.container_count) / (IsNull(Receipt.container_count,1) * IsNull(BillUnit.gal_conv,1)), 0.000) 
		   end as cost_trans_per_gallon,
	tsdf_price_per_gallon = IsNull((TSDFApprovalPrice.price * Receipt.container_count) / (IsNull(Receipt.container_count,1) * IsNull(BillUnit.gal_conv,1)), 0.000),
	#inbound.receipt_id as inbound_receipt_id,
	#inbound.Line_id as inbound_line_id
FROM #inbound
JOIN Receipt
	ON Receipt.company_id = #inbound.company_id
	AND Receipt.profit_ctr_id = #inbound.profit_ctr_id
	AND CONVERT(varchar(15),Receipt.receipt_id) + '-' + CONVERT(varchar(5),Receipt.line_id) = #inbound.tracking_num
	AND Receipt.TSDF_code = #inbound.location
	AND Receipt.trans_mode = 'O'
	AND Receipt.receipt_status = 'A'
JOIN BillUnit
	ON BillUnit.bill_unit_code = Receipt.bill_unit_code
JOIN TSDFApproval
	ON TSDFApproval.tsdf_code = Receipt.tsdf_code
	AND TSDFApproval.TSDF_approval_code = Receipt.tsdf_approval_code
	AND TSDFApproval.waste_stream = Receipt.waste_stream
	AND TSDFApproval.bill_unit_code = Receipt.tsdf_approval_bill_unit_code
	AND TSDFApproval.company_id = Receipt.company_id
	AND TSDFApproval.profit_ctr_id = Receipt.profit_ctr_id 
	AND TSDFApproval.TSDF_approval_status = 'A'
JOIN TSDFApprovalPrice
	ON TSDFApprovalPrice.company_id = TSDFApproval.company_id
	AND TSDFApprovalPrice.profit_ctr_id = TSDFApproval.profit_ctr_id
	AND TSDFApprovalPrice.TSDF_approval_id = TSDFApproval.TSDF_approval_id
WHERE #inbound.bulk_flag = 'F'

IF @debug = 1
BEGIN
    print 'outbound table'
    select * from #outbound order by receipt_id
END 

-- Return Results
SELECT DISTINCT
	#inbound.receipt_id,
	#inbound.line_id,
	#inbound.company_id,
	#inbound.profit_ctr_id,
	#inbound.receipt_date,
	#inbound.bulk_flag,
	#inbound.location_type,
	#inbound.bill_unit_code,
	#inbound.quantity,
	#inbound.amount,
	cost_disposal	= IsNull((#inbound.quantity * #inbound.gal_conv) * #outbound.cost_disposal_per_gallon, 0.000),
	cost_lab		= IsNull((#inbound.quantity * #inbound.gal_conv) * #outbound.cost_lab_per_gallon, 0.000),
	cost_process	= IsNull((#inbound.quantity * #inbound.gal_conv) * #outbound.cost_process_per_gallon, 0.000),
	cost_surcharge	= IsNull((#inbound.quantity * #inbound.gal_conv) * #outbound.cost_surcharge_per_gallon, 0.000),
	cost_trans		= IsNull((#inbound.quantity * #inbound.gal_conv) * #outbound.cost_trans_per_gallon, 0.000),
	cost_tsdf		= IsNull((#inbound.quantity * #inbound.gal_conv) * #outbound.tsdf_price_per_gallon, 0.000),
	cost_process_estimate = IsNull((#inbound.quantity * #inbound.gal_conv) * #inbound.process_cost_per_gallon, 0.000),
	Company.company_name,
	ProfitCenter.profit_ctr_name 
FROM #inbound
JOIN Company
	ON Company.company_id = #inbound.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = #inbound.company_id
	AND ProfitCenter.profit_ctr_ID = #inbound.profit_ctr_id
LEFT OUTER JOIN #outbound
	ON #outbound.inbound_receipt_id = #inbound.receipt_id
	AND CONVERT(varchar(15), #outbound.line_id) = #inbound.ref_line_id
	AND #outbound.profit_ctr_id = #inbound.profit_ctr_id
	AND #outbound.company_id = #inbound.company_id
WHERE #inbound.bulk_flag = 'T'

UNION ALL

SELECT DISTINCT
	#inbound.receipt_id,
	#inbound.line_id,
	#inbound.company_id,
	#inbound.profit_ctr_id,
	#inbound.receipt_date,
	#inbound.bulk_flag,
	#inbound.location_type,
	#inbound.bill_unit_code,
	#inbound.quantity,
	#inbound.amount,
	cost_disposal	= IsNull((#inbound.quantity * #inbound.gal_conv) * #outbound.cost_disposal_per_gallon, 0.000),
	cost_lab		= IsNull((#inbound.quantity * #inbound.gal_conv) * #outbound.cost_lab_per_gallon, 0.000),
	cost_process	= IsNull((#inbound.quantity * #inbound.gal_conv) * #outbound.cost_process_per_gallon, 0.000),
	cost_surcharge	= IsNull((#inbound.quantity * #inbound.gal_conv) * #outbound.cost_surcharge_per_gallon, 0.000),
	cost_trans		= IsNull((#inbound.quantity * #inbound.gal_conv) * #outbound.cost_trans_per_gallon, 0.000),
	cost_tsdf		= IsNull((#inbound.quantity * #inbound.gal_conv) * #outbound.tsdf_price_per_gallon, 0.000),
	cost_process_estimate = IsNull((#inbound.quantity * #inbound.gal_conv) * #inbound.process_cost_per_gallon, 0.000),
	Company.company_name,
	ProfitCenter.profit_ctr_name 
FROM #inbound
JOIN Company
	ON Company.company_id = #inbound.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = #inbound.company_id
	AND ProfitCenter.profit_ctr_ID = #inbound.profit_ctr_id
LEFT OUTER JOIN #outbound
	ON #outbound.inbound_receipt_id = #inbound.receipt_id
	AND CONVERT(varchar(15), #outbound.receipt_id) + '-' + CONVERT(varchar(5),#outbound.line_id) = #inbound.tracking_num
	AND #outbound.tsdf_code = #inbound.location
	AND #outbound.profit_ctr_id = #inbound.profit_ctr_id
	AND #outbound.company_id = #inbound.company_id
WHERE #inbound.bulk_flag = 'F'
ORDER BY #inbound.bulk_flag, #inbound.location_type

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_receipt_margin] TO [EQAI]
    AS [dbo];

