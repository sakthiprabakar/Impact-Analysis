CREATE PROCEDURE sp_rpt_invoice_detail (
	  @customer_id			int
	, @invoice_code_from	varchar(16)
	, @invoice_code_to		varchar(16)
	, @invoice_date_from	datetime
	, @invoice_date_to		datetime
)
AS
/*************************************************************************************************
Loads to : PLT_AI

06/03/2015 SK	Created.  This SP returns data currently requested for the Kroger Invoice format with Stop Fees
				that include a certain amount of disposal in their pricing. Forward looking this would be 
				generic for all retail customers
06/09/2015 SK	Modified - Report correct quantities for every billing detail line				
10/21/2016 JPB	Bug: Descriptions, price and quantity are not correct for unexpected cases where many
				lines use the same resourceclass.  Addressed it by adding Billing to the join for a more
				specific link back to workorderdetail

SELECT * FROM invoiceheader where customer_id = 15940 order by invoice_date desc
SELECT receipt_id, company_id, profit_ctr_id, workorder_resource_item, count(*) FROM Billing where customer_id = 15940 and workorder_resource_item is not null group by receipt_id, company_id, profit_ctr_id, workorder_resource_item having count(*) > 3 

SELECT * FROM billing where receipt_id = 21400900 and company_id = 14 and profit_ctr_id = 0
EXECUTE sp_rpt_invoice_detail 15940, null, null, '3/22/2016', '3/22/2016'
EXECUTE sp_rpt_invoice_detail 15940, null, null, '10/18/2016', '10/18/2016'


SELECT * FROM customer where cust_name like 'kroger%'

EXECUTE sp_rpt_invoice_detail 15940, '144588', '144590', NULL, NULL
*************************************************************************************************/

CREATE TABLE #InvoiceDetail (
	  invoice_id				int
	, revision_id				int
	, invoice_code				varchar(16)
	, invoice_date				datetime
	, due_date					datetime
	, customer_id				int
	, cust_name					varchar(40)
	--, invoice_sequence			int
	, generator_id				int
	, EPA_ID					varchar(12)
	, generator_name			varchar(40)
	, generator_site_type		varchar(40)
	, generator_site_code		varchar(16)
	, generator_region_code		varchar(40)
	, generator_division		varchar(40)
	, generator_city			varchar(40)
	, generator_state			varchar(2)
	, billing_date				datetime
	, service_date				datetime
	, company_id				int
	, profit_ctr_id				int
	, trans_source				char(1)
	, receipt_id				int
	, line_id					int
	, resource_class_code		varchar(15)
	, resource_description_1	varchar(100)
	, resource_description_2	varchar(100)
	, quantity					float
	, resource_unit_price		money
	, stop_fee_price			money
	--, pounds_included			int
	--, overage_units				int
	--, overage_charge			money	
	, extended_amt				money
	, manifest_qty				float
	, manifest_unit				varchar(15)	
	, validation_message		varchar(255)
	)

--CREATE TABLE #InvoiceDetailCalc (
--	  invoice_id				int
--	, revision_id				int
--	, customer_id				int
--	, service_date				datetime
--	, company_id				int
--	, profit_ctr_id				int
--	, receipt_id				int
--	, line_id					int
--	, quantity					float
--	, resource_unit_price		money
--	, stop_fee_price			money
--	)
	
-- Select from Billing 
INSERT INTO #InvoiceDetail
SELECT
	  IH.invoice_id				
	, IH.revision_id			
	, B.invoice_code			
	, B.invoice_date			
	, IH.due_date				
	, IH.customer_id			
	, IH.cust_name	
	, B.generator_id
	, G.EPA_ID
	, G.generator_name
	, G.site_type
	, G.site_code
	, G.generator_region_code
	, G.generator_division
	, G.generator_city
	, G.generator_state
	, B.billing_date
	, NULL AS service_date
	, B.company_id	
	, B.profit_ctr_id
	, B.trans_source
	, B.receipt_id
	, B.line_id
	, CASE bd.billing_type
		WHEN 'Insurance' THEN ''
		WHEN 'Energy' THEN ''
		WHEN 'SalesTax' THEN ''
		WHEN 'State-Haz' THEN ''
		WHEN 'State-Perp' THEN ''
		ELSE b.workorder_resource_item
		END AS resource_class_code
	, NULL AS resource_description_1
	, NULL AS resource_description_2
	, NULL AS quantity
	, NULL AS resource_unit_price
	, NULL AS stop_fee_price
	--, NULL AS pounds_included
	--, NULL AS overage_units
	--, NULL AS overage_charge
	, SUM (BD.extended_amt)
	, manifest_qty = (SELECT Sum(WODU.quantity) FROM WorkOrderDetailUnit WODU 
						JOIN WorkOrderDetail WOD ON WOD.company_id = WODU.company_id
							AND WOD.profit_ctr_id = WODU.profit_ctr_id 
							AND WOD.workorder_id = WODU.workorder_id
							AND WOD.sequence_id = WODU.sequence_id
							AND WOD.resource_type = 'D'
						WHERE WODU.company_id = B.company_id 
							AND WODU.profit_ctr_id = B.profit_ctr_id
							AND WODU.workorder_id = B.receipt_id 
							AND (WODU.bill_unit_code = B.bill_unit_code OR (B.bill_unit_code = 'EACH'))
							AND WODU.bill_unit_code = 'LBS'
							AND B.trans_source = 'W')
						
	, manifest_unit	= (SELECT MIN(WODU.bill_unit_code) FROM WorkOrderDetailUnit WODU 
						JOIN WorkOrderDetail WOD ON WOD.company_id = WODU.company_id
							AND WOD.profit_ctr_id = WODU.profit_ctr_id 
							AND WOD.workorder_id = WODU.workorder_id
							AND WOD.sequence_id = WODU.sequence_id
							AND WOD.resource_type = 'D'
						WHERE WODU.company_id = B.company_id 
							AND WODU.profit_ctr_id = B.profit_ctr_id
							AND WODU.workorder_id = B.receipt_id 
							AND (WODU.bill_unit_code = B.bill_unit_code OR (B.bill_unit_code = 'EACH'))
							AND WODU.bill_unit_code = 'LBS'
							AND B.trans_source = 'W')
	, NULL AS validation_message
FROM Billing B
JOIN BIllingDetail BD
	ON b.billing_uid = bd.billing_uid
JOIN InvoiceHeader IH
	ON IH.invoice_id = B.invoice_id
	AND IH.revision_id = (SELECT MAX(revision_id) FROM InvoiceHeader WHERE invoice_id = B.invoice_id)
	--AND IH.status = 'I'
JOIN Generator G
	ON G.generator_id = B.generator_id
WHERE 
1 = 1 
AND (b.status_code = 'I' OR (b.status_code = 'N' and invoice_preview_flag = 'T'))
AND b.customer_id = @customer_id
AND ((@invoice_code_from IS NULL AND @invoice_code_to IS NULL) OR b.invoice_code BETWEEN @invoice_code_from AND @invoice_code_to)
AND ((@invoice_date_from IS NULL AND @invoice_date_to IS NULL) OR b.invoice_date BETWEEN @invoice_date_from AND @invoice_date_to)
AND CASE bd.billing_type
		WHEN 'Insurance' THEN ''
		WHEN 'Energy' THEN ''
		WHEN 'SalesTax' THEN ''
		WHEN 'State-Haz' THEN ''
		WHEN 'State-Perp' THEN ''
		ELSE isnull(b.workorder_resource_item, '')
		END <> ''
GROUP BY
	IH.invoice_id				
	, IH.revision_id			
	, B.invoice_code			
	, B.invoice_date			
	, IH.due_date				
	, IH.customer_id			
	, IH.cust_name	
	, B.generator_id
	, G.EPA_ID
	, G.generator_name
	, G.site_type
	, G.site_code
	, G.generator_region_code
	, G.generator_division
	, G.generator_city
	, G.generator_state
	, B.billing_date
	, B.company_id	
	, B.profit_ctr_id
	, B.trans_source
	, B.receipt_id
	, B.line_id
	, bd.billing_type
	, B.Workorder_resource_item
	, B.bill_unit_code
		
		
-- update #InvoiceDetail to set the correct service_date per row:
	-- Workorders:
UPDATE #InvoiceDetail	
SET Service_date = Coalesce(WOS.date_act_arrive, wh.start_date)
FROM #InvoiceDetail 
JOIN WorkorderHeader wh 
	ON #InvoiceDetail.receipt_id = wh.workorder_id
	AND #InvoiceDetail.company_id = wh.company_id
	AND #InvoiceDetail.profit_ctr_id = wh.profit_ctr_id
JOIN WorkOrderStop WOS
	ON WOS.workorder_id = wh.workorder_id
	AND WOS.company_id = wh.company_id
	AND WOS.profit_ctr_id = wh.profit_ctr_id
	AND WOS.stop_sequence_id = 1
WHERE #InvoiceDetail.service_date IS NULL
	AND #InvoiceDetail.trans_source = 'W'

-- Get resource class description, quantity, price from WorkOrderDetail
UPDATE #InvoiceDetail
SET resource_description_1 = WOD.description
, resource_description_2 = WOD.description_2
, quantity = WOD.quantity
, resource_unit_price = WOD.price
FROM #InvoiceDetail 
INNER JOIN Billing b
	on #InvoiceDetail.receipt_id = b.receipt_id
	and #InvoiceDetail.line_id = b.line_id
	and #InvoiceDetail.company_id = b.company_id
	and #InvoiceDetail.profit_ctr_id = b.profit_ctr_id
	and #InvoiceDetail.trans_source = b.trans_source
INNER JOIN WorkOrderDetail WOD
	ON b.receipt_id = WOD.workorder_id
	AND b.company_id = WOD.company_id
	AND b.profit_ctr_id = WOD.profit_ctr_id
	and b.workorder_sequence_id = WOD.sequence_id
	AND b.workorder_resource_type = WOD.resource_type
WHERE #InvoiceDetail.trans_source = 'W'
	
---- Update Quantity and Price from WorkOrderDetail
--UPDATE #InvoiceDetail
--SET quantity = WOD.quantity
--, resource_unit_price = WOD.price
--FROM #InvoiceDetail 
--INNER JOIN WorkOrderDetail WOD
--	ON #InvoiceDetail.receipt_id = WOD.workorder_id
--	AND #InvoiceDetail.company_id = WOD.company_id
--	AND #InvoiceDetail.profit_ctr_id = WOD.profit_ctr_id
--	AND #InvoiceDetail.resource_class_code = WOD.resource_class_code
--WHERE #InvoiceDetail.trans_source = 'W'

-- Update Stop Fee pounds included as quantity
UPDATE #InvoiceDetail
SET quantity = TSR.pounds_included
, stop_fee_price = TSR.stop_fee_price
, resource_unit_price = NULL
FROM #InvoiceDetail 
JOIN WorkOrderHeader wh 
	ON #InvoiceDetail.receipt_id = wh.workorder_id
	AND #InvoiceDetail.company_id = wh.company_id
	AND #InvoiceDetail.profit_ctr_id = wh.profit_ctr_id
JOIN TripStopRate TSR
	on #InvoiceDetail.customer_id = TSR.customer_id
	and wh.generator_sublocation_id = TSR.generator_sublocation_id
	and TSR.pricing_group = 'State'
	and #InvoiceDetail.generator_state = TSR.pricing_group_value
	and #InvoiceDetail.resource_class_code = tsr.resource_class_code
WHERE #InvoiceDetail.trans_source = 'W'

/*-- Perform Overage math using TripStopRate

--INSERT INTO #InvoiceDetailCalc
--SELECT
--	#InvoiceDetail.invoice_id
--,	#InvoiceDetail.revision_id
--,	#InvoiceDetail.customer_id
--,	#InvoiceDetail.service_date
--,	#InvoiceDetail.company_id
--,	#InvoiceDetail.profit_ctr_id
--,	#InvoiceDetail.receipt_id
--,	#InvoiceDetail.line_id
--,	quantity = sum(isnull(WODU.quantity,0))
--,	resource_unit_price = TSR.unit_price
--,	stop_fee_price = TSR.stop_fee_price
--,	pounds_included = TSR.pounds_included
--,	overage_units = convert(money, case when sum(isnull(WODU.quantity,0)) > isnull(TSR.pounds_included,0)
--						then sum(isnull(WODU.quantity,0)) - isnull(TSR.pounds_included,0)
--					else 0 end)
--FROM #InvoiceDetail
--JOIN WorkorderHeader wh 
--	ON #InvoiceDetail.receipt_id = wh.workorder_id
--	AND #InvoiceDetail.company_id = wh.company_id
--	AND #InvoiceDetail.profit_ctr_id = wh.profit_ctr_id
--JOIN WorkOrderDetail WOD
--	ON #InvoiceDetail.receipt_id = WOD.workorder_id
--	AND #InvoiceDetail.company_id = WOD.company_id
--	AND #InvoiceDetail.profit_ctr_id = WOD.profit_ctr_id
--	AND WOD.resource_type = 'D'
--	AND WOD.bill_rate > -2
--JOIN WorkOrderDetailUnit WODU
--	ON WOD.workorder_id = WODU.workorder_id
--	AND WOD.company_id = WODU.company_id
--	AND WOD.profit_ctr_id = WODU.profit_ctr_id
--	AND WOD.sequence_id = WODU.sequence_id
--	AND isnull(WODU.quantity,0) > 0
--	AND WODU.bill_unit_code = 'LBS'
--JOIN TripStopRate TSR
--	on #InvoiceDetail.customer_id = TSR.customer_id
--	and wh.generator_sublocation_id = TSR.generator_sublocation_id
--	and TSR.pricing_group = 'State'
--	and #InvoiceDetail.generator_state = TSR.pricing_group_value
--	and #InvoiceDetail.resource_class_code = tsr.resource_class_code
--WHERE #InvoiceDetail.trans_source = 'W'
--GROUP BY 
--		#InvoiceDetail.invoice_id
--,	#InvoiceDetail.revision_id
--,	#InvoiceDetail.customer_id
--,	#InvoiceDetail.service_date
--,	#InvoiceDetail.company_id
--,	#InvoiceDetail.profit_ctr_id
--,	#InvoiceDetail.receipt_id
--,	#InvoiceDetail.line_id
--,	TSR.unit_price
--,	TSR.stop_fee_price
--,	TSR.pounds_included

--UPDATE #InvoiceDetail
-- SET quantity = IDC.quantity
-- ,	resource_unit_price = IDC.resource_unit_price
-- ,  stop_fee_price = IDC.stop_fee_price
-- ,  pounds_included = IDC.pounds_included
-- ,  overage_units = IDC.overage_units
-- FROM #InvoiceDetailCalc IDC
-- JOIN #InvoiceDetail ID
--	ON ID.invoice_id = IDC.invoice_id
--	AND ID.revision_id = IDC.revision_id
--	AND ID.company_id = IDC.company_id
--	AND ID.profit_ctr_id = IDC.profit_ctr_id
--	AND ID.receipt_id = IDC.receipt_id
--	AND ID.line_id = IDC.line_id
  
--UPDATE #InvoiceDetail SET overage_charge = isnull(overage_units,0) * isnull(resource_unit_price,0)

--UPDATE 
-- Update the Validation Msg field where there are errors or math does not add Up */

-- Select the Result Set	
SELECT * FROM #InvoiceDetail
ORDER BY invoice_id, revision_id
--compute sum(extended_amt)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_invoice_detail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_invoice_detail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_invoice_detail] TO [EQAI]
    AS [dbo];

