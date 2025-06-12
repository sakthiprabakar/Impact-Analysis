
CREATE PROCEDURE sp_rpt_missing_manifest_qty_unit
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
AS 
/****************************************************************************
Missing Manifest Quantity/Unit Report (d_rpt_missing_manifest_qty_unit)
Lists invoiced lines that are missing manifest_quantity or manifest_unit.

Filename:	F:\EQAI\SQL\EQAI\sp_rpt_missing_manifest_qty_unit.sql
PB Object(s):	d_rpt_missing_manifest_qty_unit
		w_report_master_hz_surcharge, w_report_master_receiving

06/15/2004 JDB	Created
11/11/2004 MK	Changed generator_code to generator_id
11/19/2004 JDB	Changed Ticket to Billing, ticket_id to line_id, excluded
		BOLs from list.
05/05/2005 MK	Added epa_id to select list
02/15/2006 rg	Added profit center name to query and restricted where clause
09/29/2010 SK	Modified the report to take company ID as input argument.
				moved to Plt_AI
10/01/2010 SK	Modified the report to run for:
				1. All Companies- all profit centers
				2. selected company- all profit centers
				3. a facility : selected company-selected profit center	
08/21/2013 SM	Added wastecode table and displaying Display name


sp_rpt_missing_manifest_qty_unit 21, -1, '10/01/2005', '11/01/2005'
****************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT	
	Billing.receipt_id,
	Billing.line_id,
	Billing.billing_date,
	Billing.customer_id,
	Customer.cust_name,
	Billing.generator_id,
	Billing.generator_name,
	Billing.approval_code,
	wastecode.display_name as waste_code,
	Billing.bill_unit_code,
	Billing.quantity,
	Billing.manifest,
	Receipt.manifest_quantity,
	Receipt.manifest_unit,
	Receipt.trans_mode,
	Generator.epa_id,
	Company.company_id,   
	Company.company_name,   
	PC.profit_ctr_id,
	PC.profit_ctr_name,
	PC.address_1 AS address_1,
	PC.address_2 AS address_2,
	PC.address_3 AS address_3,
	PC.EPA_ID AS profit_ctr_epa_ID
FROM Billing
JOIN Company
	ON Company.company_id = Billing.company_id
JOIN ProfitCenter PC
	ON PC.company_ID = Billing.company_id
	AND PC.profit_ctr_ID = Billing.profit_ctr_id
	AND PC.status = 'A'
LEFT OUTER JOIN WasteCode 
	ON wastecode.waste_code_uid = Billing.Waste_code_uid
INNER JOIN Customer 
	ON Customer.customer_id = Billing.customer_id
INNER JOIN Receipt 
	ON Receipt.receipt_id = Billing.receipt_id
	AND Receipt.line_id = Billing.line_id
	AND Receipt.company_id = Billing.company_id
	AND Receipt.profit_ctr_id = Billing.profit_ctr_id
	AND Receipt.manifest_flag <> 'B'
	AND (Receipt.manifest_quantity IS NULL OR Receipt.manifest_quantity = 0 
		OR Receipt.manifest_unit IS NULL OR Receipt.manifest_unit = '')
INNER JOIN Generator 
	ON Generator.generator_id = Billing.generator_id
WHERE ( @company_id = 0 OR Billing.company_id = @company_id )
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Billing.profit_ctr_id = @profit_ctr_id )
	AND Billing.status_code = 'I'
	AND Billing.void_status = 'F'
	AND Billing.trans_type = 'D'
	AND Billing.billing_date BETWEEN @date_from AND @date_to
	AND (Billing.sr_type_code = 'H' OR Billing.sr_type_code = 'E')
	--AND Receipt.manifest_flag <> 'B'
	--AND (Receipt.manifest_quantity IS NULL OR Receipt.manifest_quantity = 0 
	--	OR Receipt.manifest_unit IS NULL OR Receipt.manifest_unit = '')
ORDER BY 
	Billing.billing_date ASC,
	Billing.receipt_id ASC,
	Billing.line_id ASC

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_missing_manifest_qty_unit] TO [EQAI]
    AS [dbo];

