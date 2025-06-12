DROP PROCEDURE IF EXISTS sp_billing_back_to_validate
GO

CREATE PROCEDURE sp_billing_back_to_validate
	@company_id		int,
	@profit_ctr_id	int,
	@source_id		int,
	@trans_source	char(1),
	@user_code		varchar(20)
AS
/***************************************************************************************
Moves Billing Records Accepted for Invoicing Back to Validate

This SP updates the status of accepted billing records.  

Load to PLT_AI

PB Object(s):	None

03/22/2022 MPM	DevOps 23436 - Initial version.

sp_billing_back_to_validate  22, 0, 289215, 'R', 'MARTHA_M'
****************************************************************************************/
SET NOCOUNT ON

DECLARE	@now						DATETIME,
		@count_back_to_validate		INT

SET @now = GETDATE()

-- Update the Billing records 
UPDATE Billing 
	SET status_code = 'S',
		date_modified = @now,
		modified_by = @user_code
WHERE Billing.company_id = @company_id
	AND Billing.profit_ctr_id = @profit_ctr_id
	AND Billing.receipt_id = @source_id
	AND Billing.trans_source = @trans_source
	AND Billing.status_code = 'N'

SELECT @count_back_to_validate = @@ROWCOUNT

IF @count_back_to_validate > 0
UPDATE work_BillingValidate 
	SET status_code = 'S'
WHERE work_BillingValidate.company_id = @company_id
	AND work_BillingValidate.profit_ctr_id = @profit_ctr_id
	AND work_BillingValidate.receipt_id = @source_id
	AND work_BillingValidate.trans_source = @trans_source
	AND work_BillingValidate.status_code = 'N'
	
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_back_to_validate] TO [EQAI]
    AS [dbo];
