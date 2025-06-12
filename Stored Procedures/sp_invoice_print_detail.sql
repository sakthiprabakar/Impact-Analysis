DROP PROCEDURE IF EXISTS sp_invoice_print_detail
GO

CREATE PROCEDURE sp_invoice_print_detail
	@invoice_id		int,
	@revision_id	int
AS
/**************************************************************************************
Filename:		L:\Apps\SQL\EQAI\Plt_AI\Procedures\sp_invoice_print_detail.sql
PB Object(s):	d_invoice_print_detail

01/09/2007 RG	Created to support new invoice process
08/13/2007 SCC	Changed to use line_desc_1
09/09/2008 JDB	Removed the select and return of InvoiceHeader.total_amt_insurance;
				Added select of InvoiceDetail.ensr_applied_flag
09/16/2011 JDB	Changed to exclude sales tax records.
06/18/2015 RB   set transaction isolation level read uncommitted
10/12/2015 SK	Join to company & profit ctr was missing on Invoice Comment. Added the same
09/26/2016 AM   Added Billing and WorkOrderDetail table joins to get manifest_line information. 
01/19/2017 MPM	Added manifest_flag.
08/21/2017 AM   Added ref_line_id field.
09/14/2017 AM   Added trans_type field.
06/04/2018 - AM - GEM:47960 - Invoice Print - Added currency code to printed document.
05/20/2019 MPM	DevOps task 10389/GEM 59165 - Added ProfitCenter.legal_entity_name to the result set. 
11/01/2021 - AM - DevOps:21600 - Added workorder_resource_type,line_total_amt and labpack_rollup_option 
10/11/2022 - AGC - DevOps 49381 - Added price code
12/29/2022 - GDE - DevOps 58328 - Printed Invoice - Addition of new service date, when entered
01/24/2024 - AM - DevOps:74638 - Added site address fields.
01/24/2024 MPM	DevOps 42984 - Added columns to the result set for receipt price adjustment 
				description and reason, which will be populated from the ReceiptPriceAdjustment table
				if ReceiptPriceAdjustment.print_on_invoice_flag = 'T'.
02/21/2024 AM   DevOps:74642 - Added resource_type_desc column.
04/16/2024 AM   DevOps:80418 - Added invoice_summary_output_flag
05/10/2024 KS	DevOps:87211 - Added ISNULL to handle invoice_summary_output_flag column's NULL values. 
05/27/2024 SG	Devops:74130 -- Added Case condition for date_service

sp_invoice_print_detail 1129844, 1
sp_invoice_print_detail 1153777, 1
sp_invoice_print_detail 1155157, 1
sp_invoice_print_detail 1148836 , 1
sp_invoice_print_detail 1014060 , 1 

***************************************************************************************/

set transaction isolation level read uncommitted

SELECT InvoiceHeader.cust_name, 
	InvoiceHeader.addr1, 
	InvoiceHeader.addr2, 
	InvoiceHeader.addr3, 
	InvoiceHeader.addr4, 
	InvoiceHeader.addr5, 
	InvoiceHeader.invoice_code, 
	InvoiceDetail.profit_ctr_id, 
	InvoiceHeader.customer_id, 
	InvoiceHeader.invoice_date, 
	InvoiceHeader.total_amt_gross, 
	InvoiceHeader.total_amt_discount, 
	InvoiceHeader.total_amt_due, 
	InvoiceHeader.days_due, 
	InvoiceHeader.total_amt_payment, 
	InvoiceHeader.customer_po, 
	InvoiceHeader.customer_release, 
	InvoiceHeader.csr_name, 
	'',
	InvoiceHeader.attention_name, 
	InvoiceDetail.billing_date, 
	InvoiceDetail.approval_code, 
	InvoiceDetail.waste_code_desc, 
	InvoiceDetail.generator_name, 
	InvoiceDetail.shipper, 
	InvoiceDetail.manifest, 
	InvoiceDetail.purchase_order, 
	InvoiceDetail.release_code, 
	InvoiceDetail.bill_unit_code, 
	InvoiceDetail.unit_code, 
	InvoiceDetail.waste_code,
	InvoiceDetail.receipt_id, 
	InvoiceDetail.line_id,
	InvoiceDetail.price_id,
	CONVERT(varchar(10), InvoiceDetail.receipt_id) + '-' + CONVERT(varchar(4),InvoiceDetail.line_id ) + '-' + CONVERT(varchar(4), InvoiceDetail.price_id), 
	InvoiceDetail.date_added, 
	InvoiceDetail.qty_ordered, 
	InvoiceDetail.unit_price, 
	InvoiceDetail.disc_prc_flag, 
	InvoiceDetail.discount_amt, 
	InvoiceDetail.line_desc_1,
	InvoiceDetail.line_desc_2,
	InvoiceDetail.sr_type_code,
	InvoiceDetail.location_code,
	InvoiceDetail.hauler,
	InvoiceDetail.gross_weight,
	InvoiceDetail.tare_weight,
	InvoiceDetail.net_weight,
	InvoiceDetail.time_in,
	InvoiceDetail.time_out,
	InvoiceDetail.sequence_id,
	InvoiceDetail.secondary_manifest,
	InvoiceDetail.profit_ctr_id,
	InvoiceDetail.company_id,
	InvoiceDetail.trans_source,
	InvoiceDetail.ensr_applied_flag,
	ISNULL(InvoiceComment.comment_1,''),
	ISNULL(InvoiceComment.comment_2,''),
	ISNULL(InvoiceComment.comment_3,''),
	ISNULL(InvoiceComment.comment_4,''),
	ISNULL(InvoiceComment.comment_5,''),
	ProfitCenter.short_name,
	InvoiceDetail.generator_id,
	InvoiceDetail.generator_epa_id,
	ProfitCenter.profit_ctr_name,
	case InvoiceDetail.trans_source when 'W' then WorkOrderDetail.manifest_line when 'R' then Receipt.manifest_line else '' end as manifest_line,
	WorkOrderManifest.manifest_flag as WorkOrderManifest_manifest_flag,
	ISNULL (Receipt.manifest_flag, '') as Receipt_manifest_flag,
	Receipt.ref_line_id,
	ISNULL ( Receipt.trans_type,''),
	InvoiceHeader.currency_code,
	ProfitCenter.legal_entity_name,
	Billing.workorder_resource_type,
   ( InvoiceDetail.unit_price * InvoiceDetail.qty_ordered) as line_total_amt,
   ( SELECT dbo.fn_get_rollup_option (invoicedetail.receipt_id,invoicedetail.trans_source,invoicedetail.company_id,invoicedetail.profit_ctr_id) )as labpack_rollup_option,
	ProfileQuoteApproval.price_code_uid,
	Customer.price_code_required_flag,
	PriceCode.price_code,
	--WorkorderDetail.date_service,
	(CASE WHEN WorkorderDetail.resource_type = 'D' AND WorkorderDetail.date_service IS NULL THEN WorkorderManifest.date_delivered ELSE WorkorderDetail.date_service END) AS date_service,
	IsNull(Generator.generator_address_1,''),
	IsNull(Generator.generator_address_2,''),
	IsNull(Generator.generator_address_3,''),
	IsNull(Generator.generator_city,''),
	IsNull(Generator.generator_state,''),
	IsNull(Generator.generator_zip_code,''),
	ReceiptPriceAdjustment.price_desc,
	ReceiptPriceAdjustment.reason,
	case CustomerBilling.print_resource_class_type_flag when 'T' then 
	(case Billing.workorder_resource_type  when 'D' then 'Disposal' when 'E' then 'Equipment' when 'L' then 'Labor' when 'S' then 'Supplies' when 'O' then 'Other' when 'G' then 'Groups' else '' end )
	else '' end as resource_type_desc,
	ISNULL(CustomerBilling.invoice_summary_output_flag, 'F') AS invoice_summary_output_flag
FROM InvoiceDetail
JOIN InvoiceHeader ON (InvoiceDetail.invoice_id = InvoiceHeader.invoice_id
	AND InvoiceDetail.revision_id = InvoiceHeader.revision_id)
LEFT OUTER JOIN InvoiceComment ON InvoiceDetail.invoice_id = InvoiceComment.invoice_id
	AND InvoiceDetail.revision_id = InvoiceComment.revision_id
	AND InvoiceDetail.receipt_id = InvoiceComment.receipt_id
	AND InvoiceDetail.company_id = InvoiceComment.company_id
	AND InvoiceDetail.profit_ctr_id = InvoiceComment.profit_ctr_id	
INNER JOIN ProfitCenter ON (ProfitCenter.company_id = InvoiceDetail.company_id
	AND ProfitCenter.profit_ctr_id = InvoiceDetail.profit_ctr_id)
JOIN Billing ON Billing.trans_source = InvoiceDetail.trans_source
      AND Billing.company_id = InvoiceDetail.company_id
      AND Billing.profit_ctr_id = InvoiceDetail.profit_ctr_id
      AND Billing.receipt_id = InvoiceDetail.receipt_id
      AND Billing.line_id = InvoiceDetail.line_id
      AND Billing.price_id = InvoiceDetail.price_id
LEFT OUTER JOIN WorkOrderDetail ON WorkOrderDetail.workorder_ID = Billing.receipt_id
      AND WorkOrderDetail.company_id = Billing.company_id
      AND WorkOrderDetail.profit_ctr_ID = Billing.profit_ctr_id
      AND WorkOrderDetail.resource_type = Billing.workorder_resource_type
      AND WorkOrderDetail.sequence_ID = Billing.workorder_sequence_id
LEFT OUTER JOIN Receipt ON Receipt.receipt_ID = Billing.receipt_id
      AND Receipt.company_id = Billing.company_id
      AND Receipt.profit_ctr_ID = Billing.profit_ctr_id
      AND Receipt.line_id = Billing.line_id
LEFT OUTER JOIN ReceiptPriceAdjustment 
	ON ReceiptPriceAdjustment.receipt_ID = Receipt.receipt_id
      AND ReceiptPriceAdjustment.company_id = Receipt.company_id
      AND ReceiptPriceAdjustment.profit_ctr_ID = Receipt.profit_ctr_id
      AND ReceiptPriceAdjustment.line_id = Receipt.line_id
	  AND ReceiptPriceAdjustment.print_on_invoice_flag = 'T'
	AND ReceiptPriceAdjustment.sequence_id = (SELECT MAX(rpa.sequence_id)
												FROM ReceiptPriceAdjustment rpa
												WHERE rpa.company_id = ReceiptPriceAdjustment.company_id
												AND rpa.profit_ctr_id = ReceiptPriceAdjustment.profit_ctr_id
												AND rpa.receipt_id = ReceiptPriceAdjustment.receipt_id
												AND rpa.line_id = ReceiptPriceAdjustment.line_id)LEFT OUTER JOIN Customer ON Receipt.customer_id = Customer.customer_id
LEFT OUTER JOIN Generator ON Generator.generator_id = InvoiceDetail.generator_id
LEFT OUTER JOIN ProfileQuoteApproval ON Receipt.company_id = ProfileQuoteApproval.company_id
	AND Receipt.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id
	AND Receipt.approval_code = ProfileQuoteApproval.approval_code
LEFT OUTER JOIN PriceCode ON ProfileQuoteApproval.price_code_uid = PriceCode.price_code_uid
LEFT OUTER JOIN WorkorderManifest ON WorkorderDetail.profit_ctr_id = WorkorderManifest.profit_ctr_id
	AND WorkorderDetail.company_id = WorkorderManifest.company_id
	AND WorkorderDetail.workorder_id = WorkorderManifest.workorder_id
	AND WorkorderDetail.manifest = WorkorderManifest.manifest
LEFT OUTER JOIN  CustomerBilling ON CustomerBilling.customer_id = Billing.customer_id 
    AND CustomerBilling.billing_project_id = Billing.billing_project_id
WHERE InvoiceDetail.invoice_id = @invoice_id
AND InvoiceDetail.revision_id = @revision_id
AND InvoiceDetail.location_code <> 'EQAI-TAX'		-- Exclude the sales tax records
ORDER BY InvoiceDetail.sequence_id

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_invoice_print_detail] TO [EQAI]
GO

