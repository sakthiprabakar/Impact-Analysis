CREATE PROCEDURE [dbo].[sp_rpt_outbound_receipt_by_disposal_service] 
	@company_id			int
,	@profit_ctr_id		int
,	@receipt_date_from	datetime
,	@receipt_date_to	datetime
,	@TSDF_code			varchar(15)
AS
/*****************************************************************************
Filename:		L:\IT Apps\SQL-Deploy\Prod\NTSQL1\PLT_AI\Procedures
PB Object(s):	r_

03/04/2014 JDB	Created
04/04/2014	SM	Modified and add total percentage



sp_rpt_outbound_receipt_by_disposal_service 2, 0, '1/1/13', '1/31/13', ''
sp_rpt_outbound_receipt_by_disposal_service 2, 0, '1/1/13', '1/31/13', NULL
sp_rpt_outbound_receipt_by_disposal_service 2, 0, '1/1/13', '1/31/13', 'EQWDI'
*****************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
--SET NOCOUNT ON

SELECT ob.company_id
	, ob.profit_ctr_id
	, ob.TSDF_code
	, ob.receipt_id AS ob_receipt_id
	, ob.line_id AS ob_line_id
	, ob.receipt_date AS ob_receipt_date
	, CASE ob.manifest_flag 
		WHEN 'M' THEN 'Manifest' 
		WHEN 'B' THEN 'BOL' 
		WHEN 'C' THEN 'Commingled'
		WHEN 'X' THEN 'Transfer'  
		ELSE '?' 
		END AS manifest_type
	, ob.manifest
	, ob.location
	, ob.tracking_num
	, ob.cycle
	--, t.treatment_id AS treatment_id
	, t.disposal_service_desc
	, ob.quantity
	, ob.bill_unit_code
	, CASE cd.container_type 
		WHEN 'R' THEN 'Receipt'
		WHEN 'S' THEN 'Stock'
		END AS container_type
	--, ib.receipt_id AS ib_receipt_id
	--, ib.line_id AS ib_line_id
	--, dbo.fn_container_receipt(ib.receipt_id, ib.line_id) AS receipt_container_line
	, COUNT( cd.container_id) AS container_count
	, 1 AS ob_receipt_count
	, SUM(dbo.fn_receipt_weight_container(ib.receipt_id, ib.line_id, ib.profit_ctr_id, ib.company_id, cd.container_id, cd.sequence_id)) AS container_weight_lbs
	, (SUM(dbo.fn_receipt_weight_container(ib.receipt_id, ib.line_id, ib.profit_ctr_id, ib.company_id, cd.container_id, cd.sequence_id))) / 2000.00 AS container_weight_yard
	,CONVERT(MONEY, 0.00) AS total_ib_weight,
	CONVERT(MONEY, 0.00) AS perc_of_ib_receipt,
	CONVERT(MONEY, 0.00) AS perc_of_ob_receipt
INTO #tmp
FROM Receipt ob
JOIN ContainerDestination cd ON cd.company_id = ob.company_id
	AND cd.profit_ctr_id = ob.profit_ctr_id
	AND cd.location = ob.location
	AND cd.tracking_num = ob.tracking_num
	AND cd.cycle = ob.cycle
	AND cd.container_type = 'R'
JOIN Receipt ib ON ib.company_id = cd.company_id
	AND ib.profit_ctr_id = cd.profit_ctr_id
	AND ib.receipt_id = cd.receipt_id
	AND ib.line_id = cd.line_id
JOIN ProfileQuoteApproval pqa ON pqa.company_id = ib.company_id
	AND pqa.profit_ctr_id = ib.profit_ctr_id
	AND pqa.profile_id = ib.profile_id
JOIN Treatment t ON t.company_id = pqa.company_id
	AND t.profit_ctr_id = pqa.profit_ctr_id
	AND t.treatment_id = pqa.treatment_id
WHERE ob.receipt_status = 'A'
AND ob.fingerpr_status = 'A'
AND ob.trans_mode = 'O'
AND ob.company_id = @company_id
AND ob.profit_ctr_id = @profit_ctr_id
AND (ISNULL(@TSDF_code, '') = '' OR ob.TSDF_code = @TSDF_code)
AND ob.receipt_date BETWEEN @receipt_date_from AND @receipt_date_to
--AND ob.location = 'G'
--AND ob.tracking_num IN ('34711')
--AND ob.location = 'F'
--AND ob.tracking_num IN ('34468')
--AND ob.location = 'A'
--AND ob.tracking_num IN ('34690')
GROUP BY ob.company_id
	, ob.profit_ctr_id
	, ob.receipt_id
	, ob.line_id
	, ob.receipt_date
	, ob.TSDF_code
	, ob.manifest_flag
	, ob.manifest
	, ob.location
	, ob.tracking_num
	, ob.cycle
	--, t.treatment_id 
	, t.disposal_service_desc
	, ob.quantity
	, ob.bill_unit_code
	, cd.container_type
	, ib.company_id
	, ib.profit_ctr_id
	--, ib.receipt_id
	--, ib.line_id

UNION

SELECT ob.company_id
	, ob.profit_ctr_id
	, ob.TSDF_code
	, ob.receipt_id AS ob_receipt_id
	, ob.line_id AS ob_line_id
	, ob.receipt_date AS ob_receipt_date
	, CASE ob.manifest_flag 
		WHEN 'M' THEN 'Manifest' 
		WHEN 'B' THEN 'BOL' 
		WHEN 'C' THEN 'Commingled'
		WHEN 'X' THEN 'Transfer'  
		ELSE '?' 
		END AS manifest_type
	, ob.manifest
	, ob.location
	, ob.tracking_num
	, ob.cycle
	--, t.treatment_id AS treatment_id
	, t.disposal_service_desc
	, ob.quantity
	, ob.bill_unit_code
	, CASE cd.container_type 
		WHEN 'R' THEN 'Receipt'
		WHEN 'S' THEN 'Stock'
		END AS container_type
	--, 0 AS ib_receipt_id
	--, cd.line_id AS ib_line_id
	--, dbo.fn_container_stock(cd.line_id, cd.company_id, cd.profit_ctr_id) AS receipt_container_line
	, 1 AS container_count
	, 1 AS ob_receipt_count
	, SUM(dbo.fn_receipt_weight_container(cd.receipt_id, cd.line_id, cd.profit_ctr_id, cd.company_id, cd.container_id, cd.sequence_id)) AS container_weight_lbs
	, (SUM(dbo.fn_receipt_weight_container(cd.receipt_id, cd.line_id, cd.profit_ctr_id, cd.company_id, cd.container_id, cd.sequence_id))) / 2000.00 AS container_weight_yard,
	0.000000,
	0.000000,
	0.000000
FROM Receipt ob
JOIN ContainerDestination cd ON cd.company_id = ob.company_id
	AND cd.profit_ctr_id = ob.profit_ctr_id
	AND cd.location = ob.location
	AND cd.tracking_num = ob.tracking_num
	AND cd.cycle = ob.cycle
	AND cd.container_type = 'S'
JOIN Treatment t ON t.company_id = cd.company_id
	AND t.profit_ctr_id = cd.profit_ctr_id
	AND t.treatment_id = cd.treatment_id
WHERE ob.receipt_status = 'A'
AND ob.fingerpr_status = 'A'
AND ob.trans_mode = 'O'
AND ob.company_id = @company_id
AND ob.profit_ctr_id = @profit_ctr_id
AND (ISNULL(@TSDF_code, '') = '' OR ob.TSDF_code = @TSDF_code)
AND ob.receipt_date BETWEEN @receipt_date_from AND @receipt_date_to
GROUP BY ob.company_id
	, ob.profit_ctr_id
	, ob.receipt_id
	, ob.line_id
	, ob.receipt_date
	, ob.TSDF_code
	, ob.manifest_flag
	, ob.manifest
	, ob.location
	, ob.tracking_num
	, ob.cycle
	--, t.treatment_id 
	, t.disposal_service_desc
	, ob.quantity
	, ob.bill_unit_code
	, cd.container_type
	, cd.company_id
	, cd.profit_ctr_id
	--, cd.line_id
ORDER BY 
	 ob.TSDF_code
	, ob.receipt_date
	, ob.location
	, ob.tracking_num
	, ob.cycle
	, ob.receipt_id
	, ob.line_id
	, t.disposal_service_desc
	--, ib.receipt_id
	--, ib.line_id


-- Because some batches are outbounded on multiple receipts, we need to find out where this occurs, and divide the container
-- quantities by the number of outbound receipts that the batch went out on.
SELECT t.location, t.tracking_num, t.cycle, COUNT(DISTINCT CONVERT(varchar(10), ob_receipt_id) + '-' + CONVERT(varchar(10), ob_line_id)) AS ob_receipt_count
INTO #tmp2
FROM #tmp t
GROUP BY t.location, t.tracking_num, t.cycle

UPDATE #tmp SET ob_receipt_count = ISNULL((SELECT #tmp2.ob_receipt_count
	FROM #tmp2
	WHERE #tmp.location = #tmp2.location
	AND #tmp.tracking_num = #tmp2.tracking_num
	AND #tmp.cycle = #tmp2.cycle
	AND #tmp2.ob_receipt_count > 1
	), 1)

UPDATE #tmp SET container_weight_lbs = (container_weight_lbs / ob_receipt_count), container_weight_yard = (container_weight_yard / ob_receipt_count)
WHERE ob_receipt_count > 1

UPDATE #tmp SET total_ib_weight = (SELECT SUM(b.container_weight_yard)
	FROM #tmp b
	WHERE #tmp.location = b.location
	AND #tmp.tracking_num = b.tracking_num
	AND #tmp.cycle = b.cycle
	AND #tmp.ob_receipt_id = b.ob_receipt_id
	AND #tmp.ob_line_id = b.ob_line_id
	GROUP BY b.location,b.tracking_num , b.cycle, b.ob_receipt_id, b.ob_line_id)
	
UPDATE #tmp SET perc_of_ib_receipt = ( container_weight_yard / total_ib_weight )

UPDATE #tmp SET perc_of_ob_receipt = ( quantity * perc_of_ib_receipt ) 

SELECT t.*,p.profit_ctr_name  FROM #tmp t, dbo.ProfitCenter p
WHERE t.profit_ctr_ID = p.profit_ctr_ID
AND t.company_id = p.company_id

DROP TABLE #tmp
DROP TABLE #tmp2

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_outbound_receipt_by_disposal_service] TO [EQAI]
    AS [dbo];

