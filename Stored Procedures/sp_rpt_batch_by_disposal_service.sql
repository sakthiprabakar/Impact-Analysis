CREATE PROCEDURE [dbo].[sp_rpt_batch_by_disposal_service] 
	@company_id				int
,	@profit_ctr_id			int
,	@batch_opened_date_from	datetime
,	@batch_opened_date_to	datetime
,	@TSDF_code				varchar(15)
AS
/*****************************************************************************
Filename:		L:\IT Apps\SQL-Deploy\Prod\NTSQL1\PLT_AI\Procedures\sp_rpt_batch_by_disposal_service
PB Object(s):	r_batch_by_disposal_service, r_batch_by_disposal_service_summary

03/04/2014 JDB	Created
04/04/2014	SM	Modified and add total percentage
07/23/2014 JDB	Copied and renamed from sp_rpt_outbound_receipt_by_disposal_service.
				Changed to run by batch instead of outbound receipt, because
				the numbers on this report will be used to create the outbound receipt.
08/15/2014 JDB	Modified so that it doesn't join directly to ContainerDestination and
				ReceiptPrice in the initial select, because that was calculating the
				quantities incorrectly for receipt lines with multiple containers (as in > 1)
				and especially those with multiple bill units, such	as DM55 and DM30.  
				Also restricted the query to include only completed	containers, 
				and only for inbound disposal receipt lines.
12/04/2014 JDB	Modified to convert all units to TONS, instead of separating out the weight
				units from volume units.  This effectively backs out the changes we built into
				the procedure in the first place, in order to give them what they requested.
				Check Gemini 30583 for more details. (Deployed 1/26/15)

sp_rpt_batch_by_disposal_service 2, 0, '7/1/14', '7/1/14', ''
sp_rpt_batch_by_disposal_service 2, 0, '1/1/13', '1/31/13', NULL
sp_rpt_batch_by_disposal_service 2, 0, '1/1/13', '1/31/13', 'EQWDI'
*****************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- This first query gathers all of the container records that match the user's search criteria.
-- The containers must be in the batches that were opened between the batch open date parameters.
-- We include in this #tmp table, the container_count from the receipt line, as well as the count
-- of containers that were placed into the batch.  The container_count from the receipt line
-- will be used in the calculation below to determine the per-container weight.  The count of 
-- containers in the batch will be used to multiply by the per-container weight, in order to get
-- the total weight.
SELECT b.company_id
	, b.profit_ctr_id
	, pc.profit_ctr_name
	, b.batch_id
	, ISNULL(st.status_desc, '(Unknown)') AS batch_status
	, b.location
	, b.tracking_num
	, b.cycle
	, b.date_opened
	, b.date_closed
	, t.disposal_service_desc
	, ib.receipt_id
	, ib.line_id
	, ib.container_count AS line_container_count
	, COUNT(DISTINCT cd.container_id) AS container_count
	, CONVERT(money, 0) AS ib_quantity
	, CONVERT(varchar(4), NULL) AS ib_bill_unit_code
	, ISNULL(ob.TSDF_code, 'N/A') AS TSDF_code
	, ISNULL(TSDF.TSDF_name, '') AS TSDF_name
INTO #tmp
FROM Batch b (NOLOCK)
JOIN ProfitCenter pc (NOLOCK) ON pc.company_ID = b.company_id
	AND pc.profit_ctr_ID = b.profit_ctr_id
LEFT OUTER JOIN StatusType st (NOLOCK) ON st.status = b.status
	AND st.status_type = 'BATCH'
JOIN ContainerDestination cd (NOLOCK) ON cd.company_id = b.company_id
	AND cd.profit_ctr_id = b.profit_ctr_id
	AND cd.location = b.location
	AND cd.tracking_num = b.tracking_num
	AND cd.cycle = b.cycle
	AND cd.container_type = 'R'
	AND cd.status = 'C'
JOIN Receipt ib (NOLOCK) ON ib.company_id = cd.company_id
	AND ib.profit_ctr_id = cd.profit_ctr_id
	AND ib.receipt_id = cd.receipt_id
	AND ib.line_id = cd.line_id
	AND ib.trans_mode = 'I'
	AND ib.trans_type = 'D'
JOIN ProfileQuoteApproval pqa (NOLOCK) ON pqa.company_id = ib.company_id
	AND pqa.profit_ctr_id = ib.profit_ctr_id
	AND pqa.profile_id = ib.profile_id
JOIN Treatment t (NOLOCK) ON t.company_id = pqa.company_id
	AND t.profit_ctr_id = pqa.profit_ctr_id
	AND t.treatment_id = pqa.treatment_id
LEFT OUTER JOIN Receipt ob (NOLOCK) ON ob.company_id = b.company_id
	AND ob.profit_ctr_id = b.profit_ctr_id
	AND ob.location = b.location
	AND ob.tracking_num = b.tracking_num
	AND ob.cycle = b.cycle
LEFT OUTER JOIN TSDF (NOLOCK) ON (TSDF.TSDF_code = ob.TSDF_code OR @TSDF_code = 'ALL')
WHERE 1=1
AND b.company_id = @company_id
AND b.profit_ctr_id = @profit_ctr_id
AND b.date_opened BETWEEN @batch_opened_date_from AND @batch_opened_date_to
GROUP BY b.company_id
	, b.profit_ctr_id
	, pc.profit_ctr_name
	, b.batch_id
	, ISNULL(st.status_desc, '(Unknown)')
	, b.location
	, b.tracking_num
	, b.cycle
	, b.date_opened
	, b.date_closed
	, t.disposal_service_desc
	, ib.receipt_id
	, ib.line_id
	, ib.container_count
	, ob.TSDF_code
	, TSDF.TSDF_name

--SELECT * FROM #tmp

SELECT rp.company_id
, rp.profit_ctr_id
, rp.receipt_id
, rp.line_id
, #tmp.line_container_count
--, CASE ISNULL(bu.actual_weight_flag, 'F') 
--	WHEN 'T' THEN SUM(rp.bill_quantity * bu.pound_conv) / 2000
--	WHEN 'F' THEN SUM(rp.bill_quantity * bu.yard_conv)
--	END AS ib_quantity
--, (CASE ISNULL(bu.actual_weight_flag, 'F') 
--	WHEN 'T' THEN SUM(rp.bill_quantity * bu.pound_conv) / 2000
--	WHEN 'F' THEN SUM(rp.bill_quantity * bu.yard_conv)
--	END) / #tmp.line_container_count AS ib_quantity_per_container
--, CASE ISNULL(bu.actual_weight_flag, 'F') 
--	WHEN 'T' THEN 'TONS'
--	WHEN 'F' THEN 'YARD'
--	END AS ib_bill_unit_code
, SUM(rp.bill_quantity * bu.pound_conv) / 2000 AS ib_quantity
, (SUM(rp.bill_quantity * bu.pound_conv) / 2000) / #tmp.line_container_count AS ib_quantity_per_container
, 'TONS' AS ib_bill_unit_code
INTO #subtotals
FROM ReceiptPrice rp 
JOIN BillUnit bu ON bu.bill_unit_code = rp.bill_unit_code
JOIN #tmp ON rp.company_id = #tmp.company_id
	AND rp.profit_ctr_id = #tmp.profit_ctr_id
	AND rp.receipt_id = #tmp.receipt_id
	AND rp.line_id = #tmp.line_id
GROUP BY rp.company_id
	, rp.profit_ctr_id
	, rp.receipt_id
	, rp.line_id
	, #tmp.line_container_count
	--, ISNULL(bu.actual_weight_flag, 'F')

--SELECT * FROM #subtotals ORDER BY receipt_id, line_id


UPDATE #tmp SET ib_quantity = #tmp.container_count * #subtotals.ib_quantity_per_container
	, ib_bill_unit_code = #subtotals.ib_bill_unit_code
FROM #tmp
JOIN #subtotals ON #subtotals.company_id = #tmp.company_id
	AND #subtotals.profit_ctr_id = #tmp.profit_ctr_id
	AND #subtotals.receipt_id = #tmp.receipt_id
	AND #subtotals.line_id = #tmp.line_id

--SELECT * FROM #tmp

IF @TSDF_code <> ''
BEGIN
	-- If the user specified a TSDF Code, remove all others from the #tmp table.
	DELETE FROM #tmp WHERE TSDF_code <> @TSDF_code
END

SELECT company_id
	, profit_ctr_id
	, profit_ctr_name
	, batch_id
	, batch_status
	, location
	, tracking_num
	, cycle
	, date_opened
	, date_closed
	, disposal_service_desc
	, SUM(ISNULL(ib_quantity, 0)) AS ib_quantity
	, ib_bill_unit_code
	, TSDF_code
	, TSDF_name
FROM #tmp t
GROUP BY company_id
	, profit_ctr_id
	, profit_ctr_name
	, batch_id
	, batch_status
	, location
	, tracking_num
	, cycle
	, date_opened
	, date_closed
	, disposal_service_desc
	, ib_bill_unit_code
	, TSDF_code
	, TSDF_name
ORDER BY 
	CASE WHEN ISNULL(TSDF_code, '') = 'N/A' THEN 'ZZZZZZZZZZ' ELSE TSDF_code END
	, date_opened
	, location
	, tracking_num
	, disposal_service_desc
	, ib_bill_unit_code

DROP TABLE #tmp
DROP TABLE #subtotals

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_batch_by_disposal_service] TO [EQAI]
    AS [dbo];

