
/***************************************************************************************
Displays list of Receipts related to this Work Order

Filename:	F:\EQAI\SQL\EQAI\sp_billing_receipt_wo.sql

-- Load to PLT_AI

07/17/2007 SCC	Created
01/10/2008 WAC	Just because a billinglink exists doesn't mean that readonly should be returned
		as 1.  Per Lorraine we will allow the user to change properties of the link
		when they wish.
06/18/2008 KAM  Took out the union to the billing table as the billinglinklooklup will now be
                the controling table

sp_billing_receipt_wo 1, 21, 0, 2000, 'DEV'


****************************************************************************************/
CREATE PROCEDURE sp_billing_receipt_wo
	@debug			int,
	@wo_company_id		int,
	@wo_profit_ctr_id	int,
	@workorder_id		int
AS

DECLARE	
	@results_count	int

CREATE TABLE #results (
	company_id	int NULL,
	profit_ctr_id	int NULL,
	receipt_id	int NULL,
	billing_link_id	int NULL
)

-- Populate results table with any billing records
INSERT #results

SELECT BillingLinkLookup.company_id,
	BillingLinkLookup.profit_ctr_id,
	BillingLinkLookup.receipt_id,
	BillingLinkLookup.billing_link_id
FROM BillingLinkLookup
WHERE BillingLinkLookup.source_company_id = @wo_company_id
	AND BillingLinkLookup.source_profit_ctr_id = @wo_profit_ctr_id
	AND BillingLinkLookup.source_id = @workorder_id
	AND BillingLinkLookup.source_type = 'W'

SELECT DISTINCT #results.*, 
	BillingLink.link_desc, 
	CASE WHEN #results.billing_link_id IS NOT NULL THEN 1 ELSE 0 END AS same_invoice,
	0 AS readonly
FROM #results
LEFT OUTER JOIN BillingLink
	ON #results.billing_link_id = BillingLink.link_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_receipt_wo] TO [EQAI]
    AS [dbo];

