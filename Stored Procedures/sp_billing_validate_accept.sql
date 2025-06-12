CREATE PROCEDURE sp_billing_validate_accept
	@validate_date		datetime,
	@user_code		varchar(20),
	@count_accepted		int		OUTPUT
AS
/***************************************************************************************
Validates Billing Records for Invoicing

This SP updates the status of validated billing records.  It also ensures that
the billing project matches what was validated.  If the original billing project
was no longer active, the standard customer billing project is used for validation
so that change is updated in this SP.

Load to PLT_AI

Filename:	L:\Apps\SQL\EQAI\sp_billing_validate_accept.sql
PB Object(s):	None

03/18/2007 SCC	Created
12/02/2024 KS	Rally US131329 - Updated the logic to update Billing.status_code for Receipt.

sp_billing_validate_accept '2007-10-16 16:17:52.500', 'sheila_c', 0
****************************************************************************************/
SET NOCOUNT ON

-- Update the Billing records - Work Orders.  If the record was already invoiced, set the status to I
-- If this record was put on hold for billing, the hold reason, user, and date are no longer valid
UPDATE Billing SET 
	status_code = CASE WHEN IsNull(Billing.invoice_id,0) > 0 THEN 'I' ELSE 'N' END,
	billing_project_id = work_BillingValidate.billing_project_id,
	date_modified = @validate_date,
	modified_by = @user_code,
	hold_reason = NULL,
	hold_userid = NULL,
	hold_date = NULL
FROM work_BillingValidate
WHERE Billing.company_id = work_BillingValidate.company_id
	AND Billing.profit_ctr_id = work_BillingValidate.profit_ctr_id
	AND Billing.trans_source = work_BillingValidate.trans_source
	AND Billing.receipt_id = work_BillingValidate.receipt_id
	AND Billing.status_code IN ('S','H')
	AND work_BillingValidate.item_checked = 2
	AND work_BillingValidate.record_id IS NOT NULL
	AND work_BillingValidate.validate_date = @validate_date
	AND work_billingValidate.trans_source = 'W'
SELECT @count_accepted = @@ROWCOUNT

-- Update Billing records - Receipts
UPDATE Billing SET 
	status_code = CASE WHEN IsNull(Billing.invoice_id,0) > 0 AND work_billingValidate.trans_source = 'R' THEN 'I' ELSE 'N' END,
	billing_project_id = work_BillingValidate.billing_project_id,
	date_modified = @validate_date,
	modified_by = @user_code,
	hold_reason = NULL,
	hold_userid = NULL,
	hold_date = NULL
FROM work_BillingValidate
WHERE Billing.company_id = work_BillingValidate.company_id
	AND Billing.profit_ctr_id = work_BillingValidate.profit_ctr_id
	AND Billing.trans_source = work_BillingValidate.trans_source
	AND Billing.receipt_id = work_BillingValidate.receipt_id
	AND Billing.line_id = work_BillingValidate.line_id
	AND Billing.price_id = work_BillingValidate.price_id
	AND work_BillingValidate.item_checked = 2
	AND work_BillingValidate.record_id IS NOT NULL
	AND work_BillingValidate.validate_date = @validate_date
--WAC cheat
-- Added to support the Retail Order (O) records
--	AND work_billingValidate.trans_source = 'R'
	AND work_billingValidate.trans_source IN ('R','O')
	AND Billing.status_code IN ('S','H')

SELECT @count_accepted = @count_accepted + @@ROWCOUNT

IF @count_accepted > 0
UPDATE work_BillingValidate SET status_code = Billing.status_code
FROM Billing
WHERE Billing.company_id = work_BillingValidate.company_id
	AND Billing.profit_ctr_id = work_BillingValidate.profit_ctr_id
	AND Billing.trans_source = work_BillingValidate.trans_source
	AND Billing.receipt_id = work_BillingValidate.receipt_id
	AND Billing.line_id = work_BillingValidate.line_id
	AND Billing.price_id = work_BillingValidate.price_id
	AND work_BillingValidate.item_checked = 2
	AND work_BillingValidate.record_id IS NOT NULL
	AND work_BillingValidate.validate_date = @validate_date

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_validate_accept] TO [EQAI]
    AS [dbo];

