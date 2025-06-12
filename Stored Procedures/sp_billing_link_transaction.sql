
/***************************************************************************************
Displays list of pending Receipts and Work Orders with this Billing Link

Filename:	F:\EQAI\SQL\EQAI\sp_billing_link_transaction.sql

-- Load to PLT_AI

06/08/07 SCC	Created
sp_billing_link_transaction 1, 1


****************************************************************************************/
CREATE PROCEDURE sp_billing_link_transaction
	@debug			int,
	@billing_link_id	int
AS

DECLARE	
	@results_count	int

CREATE TABLE #results (
	company_id	int NULL,
	profit_ctr_id	int NULL,
	trans_source	char(1) NULL,
	source_id	int NULL,
	source_date	datetime NULL,
	source_status	varchar(20) NULL,
	submitted_flag	char(1) NULL
)

-- Insert Billing Records
INSERT #results SELECT DISTINCT
	Billing.company_id,
	Billing.profit_ctr_id,
	Billing.trans_source,
	Billing.receipt_id,
	Billing.billing_date,
	CASE Billing.status_code WHEN 'H' THEN 'Submitted on Hold' WHEN 'S' THEN 'Submitted'
		WHEN 'N' THEN 'Ready to Invoice' WHEN 'I' THEN 'Invoiced' ELSE 'Unknown Status' END,
	'T' as submitted_flag
FROM Billing
WHERE Billing.billing_link_id = @billing_link_id

INSERT #results 
SELECT DISTINCT BillingLinkLookup.company_id,
	BillingLinkLookup.profit_ctr_id,
	BillingLinkLookup.trans_source,
	BillingLinkLookup.receipt_id,
	BillingLinkLookup.receipt_date,
	CASE BillingLinkLookup.receipt_status WHEN 'N' THEN 'New' WHEN 'L' THEN 'In the Lab'
		WHEN 'U' THEN 'Unloading' WHEN 'A' THEN 'Accepted' WHEN 'D' THEN 'Dispatched'
		WHEN 'C' THEN 'Completed' WHEN 'P' THEN 'Priced' ELSE 'Unknown Status' END,
	'F' as submitted_flag
FROM BillingLinkLookup
WHERE BillingLinkLookup.billing_link_id = @billing_link_id
	AND NOT EXISTS (SELECT 1 FROM #results WHERE
		#results.company_id = BillingLinkLookup.company_id
		AND #results.profit_ctr_id = BillingLinkLookup.profit_ctr_id
		AND #results.source_id = BillingLinkLookup.receipt_id
		AND #results.submitted_flag = 'T'
		AND ((#results.trans_source = 'R' AND BillingLinkLookup.trans_source IN ('I','O'))
		    OR (#results.trans_source = BillingLinkLookup.trans_source)))

SELECT @results_count = Count(*) FROM #results
IF @results_count = 0
	INSERT #results VALUES (NULL, NULL, NULL, NULL, NULL, 'No Transactions', 'T')

SELECT * FROM #results


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_link_transaction] TO [EQAI]
    AS [dbo];

