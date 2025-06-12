
CREATE PROCEDURE sp_rpt_waste_received_treat_weight
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
AS
/***************************************************************************
08/19/2004 SCC	Created
12/06/2004 MK	Replaced ticket_id with receipt_id, line_id 
				and DrumDetail with Container
11/03/2010 SK	Added company_id as input arg, added joins to company_id
				moved to Plt_AI
				
sp_rpt_waste_received_treat_weight 21, 0, '8-1-2004', '8-19-2004'
***************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT	
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.treatment_id, 
	Receipt.bulk_flag,
	IsNull(Receipt.quantity,0) * IsNull(BillUnit.pound_conv,0) as weight
INTO #tmp
FROM Receipt
JOIN BillUnit
	ON BillUnit.bill_unit_code = Receipt.bill_unit_code
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status = 'A' 
	AND Receipt.bulk_flag = 'T'
	AND Receipt.receipt_date between @date_from and @date_to
	
UNION ALL

SELECT	
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	CD.treatment_id, 
	Receipt.bulk_flag,
	Sum(container_weight) as weight
FROM Receipt
JOIN Container
	ON Container.company_id = Receipt.company_id
	AND Container.profit_ctr_id = Receipt.profit_ctr_id
	AND Container.receipt_id = Receipt.receipt_id
	AND Container.line_id =Receipt.line_id
	AND Container.container_type = 'R'
JOIN ContainerDestination CD
	ON CD.receipt_id = Container.receipt_id
	AND CD.line_id = Container.line_id
	AND CD.profit_ctr_id = Container.profit_ctr_id
	AND CD.company_id = Container.company_id
	AND CD.treatment_id IS NOT NULL
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status = 'A'
	AND Receipt.bulk_flag = 'F'
	AND Receipt.receipt_date between @date_from and @date_to
GROUP BY 
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	CD.treatment_id, 
	Receipt.bulk_flag
	
UNION ALL

SELECT	
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.treatment_id, 
	Receipt.bulk_flag,
	Sum(container_weight) as weight
FROM Receipt
JOIN Container
	ON Container.company_id = Receipt.company_id
	AND Container.profit_ctr_id = Receipt.profit_ctr_id
	AND Container.receipt_id = Receipt.receipt_id
	AND Container.line_id =Receipt.line_id
	AND Container.container_type = 'R'
JOIN ContainerDestination CD
	ON CD.receipt_id = Container.receipt_id
	AND CD.line_id = Container.line_id
	AND CD.profit_ctr_id = Container.profit_ctr_id
	AND CD.company_id = Container.company_id
	AND CD.treatment_id IS NULL
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.trans_mode = 'I' 
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status = 'A'
	AND Receipt.bulk_flag = 'F'
	AND Receipt.receipt_date between @date_from and @date_to
GROUP BY 
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.company_id,
	Receipt.profit_ctr_id,
	Receipt.treatment_id, 
	Receipt.bulk_flag
	
SELECT 
	#tmp.treatment_id,
	Treatment.treatment_desc,
	#tmp.bulk_flag,
	#tmp.receipt_id,
	#tmp.line_id,
	#tmp.weight,
	#tmp.company_id,
	#tmp.profit_ctr_id,
	Company.company_name,
	ProfitCenter.profit_ctr_name
FROM #tmp
JOIN Company
	ON Company.company_id = #tmp.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = #tmp.company_id
	AND ProfitCenter.profit_ctr_ID = #tmp.profit_ctr_id
LEFT OUTER JOIN Treatment
	ON Treatment.company_id = #tmp.company_id
	AND Treatment.profit_ctr_id = #tmp.profit_ctr_id
	AND Treatment.treatment_id = #tmp.treatment_id
ORDER BY
	#tmp.company_id,
	#tmp.profit_ctr_id, 
	#tmp.treatment_id,
	Treatment.treatment_desc,
	#tmp.bulk_flag,
	#tmp.receipt_id,
	#tmp.line_id,
	#tmp.weight

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_waste_received_treat_weight] TO [EQAI]
    AS [dbo];

