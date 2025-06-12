CREATE PROCEDURE sp_billing_unsubmit_order
	@debug			int,
	@order_id		int,
	@trans_source	char(1),
	@user_code		varchar(20),
	@from_adjustment	char(1) = 'F'
AS
/***************************************************************************************
UnSubmit a Retail Order from the Billing table

Filename:	L:\Apps\SQL\EQAI\sp_billing_unsubmit_order.sql

LOAD TO PLT_AI database

03/25/2008 WAC	Created from sp_billing_unsubmit then modified to unsubmit a retail order.
06/17/2008 KAM  Modified to update the OrderHeader Modified User time and date when unsubmitted from Billing
11/04/2010 JDB	Added code to delete from new BillingDetail table
06/08/2016 RWB	Added @from_adjustment argument, to update OrderHeader record regardless of Billing record existence

sp_billing_unsubmit_order 1, 3331, 'O', 'JASON_B'
****************************************************************************************/
SET NOCOUNT ON

DECLARE	@update_count	int,
		@billing_count	int,
		@today			datetime,
		@audit_id		int,
		@company_id		int,
		@profit_ctr_id	int

SET @update_count = 0
SET @billing_count = 0
SELECT @today = getdate()

IF @trans_source = 'O'
BEGIN
	SELECT @company_id = od.company_id,
		@profit_ctr_id = od.profit_ctr_id
	FROM OrderDetail od
	WHERE order_id = @order_id


	-- In a second associated billing records (if any) will be deleted.  The sub-query of this
	-- update will ensure that if in some rare case a billing record remains the submitted_flag 
	-- would not be unset.
	if isnull(@from_adjustment,'F') = 'T'
		UPDATE OrderHeader SET 
			submitted_flag = 'F',date_modified = @today, modified_by = @user_code
		WHERE Orderheader.order_id = @order_id
	else
		UPDATE OrderHeader SET 
			submitted_flag = 'F',date_modified = @today, modified_by = @user_code
		WHERE Orderheader.order_id = @order_id
		AND NOT EXISTS (SELECT 1 FROM Billing
				WHERE Billing.receipt_id = @order_id
				AND Billing.trans_source = @trans_source
				AND Billing.status_code NOT IN ('H','S','N','V'))

	SET @update_count = @@rowcount
	IF @update_count > 0
	BEGIN
		INSERT OrderAudit(order_id, line_id, 
				table_name, column_name, before_value, after_value, audit_reference, 
				modified_by, modified_from, date_modified)
		VALUES (@order_id, 0,
				'OrderHeader', 'submitted_flag', 'T', 'F', 'Unsubmitted from Billing',
				@user_code, 'SB', @today)
	END
END

IF @update_count > 0
BEGIN
	-- Remove Billing Comments.  
	if isnull(@from_adjustment,'F') = 'T'
		DELETE FROM BillingComment
			FROM Billing 
		WHERE Billing.receipt_id = @order_id
			AND Billing.trans_source = @trans_source
			AND Billing.company_id = BillingComment.company_id
			AND Billing.profit_ctr_id = BillingComment.profit_ctr_id
			AND Billing.receipt_id = BillingComment.receipt_id
			AND Billing.trans_source = @trans_source 
	else
		DELETE FROM BillingComment
			FROM Billing 
		WHERE Billing.receipt_id = @order_id
			AND Billing.trans_source = @trans_source
			AND Billing.company_id = BillingComment.company_id
			AND Billing.profit_ctr_id = BillingComment.profit_ctr_id
			AND Billing.receipt_id = BillingComment.receipt_id
			AND Billing.trans_source = @trans_source 
			AND Billing.status_code IN ('H','S','N','V')

	SET @billing_count = @@ROWCOUNT

	IF @billing_count > 0
	BEGIN
		SELECT @audit_id = ISNULL(MAX(audit_id),0) + 1 FROM BillingAudit
		INSERT BillingAudit (audit_id, company_id, profit_ctr_id, trans_source, receipt_id, 
			line_id, price_id, billing_summary_id, transaction_code, 
			table_name, column_name, before_value, after_value, 
			date_modified, modified_by, audit_reference )
		VALUES (@audit_id, NULL, NULL, @trans_source, @order_id,
			0, 0, 0, 'X', 'BillingComment', 'All Lines', '', '',
			@today, @user_code, 'Unsubmitted from Billing')
	END

	
	-- Remove BillingDetail records
	if isnull(@from_adjustment,'F') = 'T'
		DELETE BillingDetail
		FROM BillingDetail
		JOIN Billing ON Billing.company_id = BillingDetail.company_id
			AND Billing.profit_ctr_id = BillingDetail.profit_ctr_id
			AND Billing.receipt_id = BillingDetail.receipt_id
		WHERE Billing.receipt_id = @order_id
		AND Billing.trans_source = @trans_source
	else
		DELETE BillingDetail
		FROM BillingDetail
		JOIN Billing ON Billing.company_id = BillingDetail.company_id
			AND Billing.profit_ctr_id = BillingDetail.profit_ctr_id
			AND Billing.receipt_id = BillingDetail.receipt_id
		WHERE Billing.receipt_id = @order_id
		AND Billing.trans_source = @trans_source
		AND Billing.status_code IN ('H','S','N','V')

	SET @billing_count = @@ROWCOUNT
	IF @billing_count > 0
	BEGIN
		SELECT @audit_id = ISNULL(MAX(audit_id),0) + 1 FROM BillingAudit
		INSERT BillingAudit (audit_id, company_id, profit_ctr_id, trans_source, receipt_id, 
			line_id, price_id, billing_summary_id, transaction_code, 
			table_name, column_name, before_value, after_value, 
			date_modified, modified_by, audit_reference )
		VALUES (@audit_id, @company_id, @profit_ctr_id, @trans_source, @order_id,
			0, 0, 0, 'X', 'BillingDetail', 'All Lines', '', '',
			@today, @user_code, 'Unsubmitted from Billing')
	END
	

	-- Remove Billing records.  Billing lines are removed for lines on Hold, Submitted, or New.
	if isnull(@from_adjustment,'F') = 'T'
		DELETE FROM Billing
		WHERE Billing.receipt_id = @order_id
			AND Billing.trans_source = @trans_source
	else
		DELETE FROM Billing
		WHERE Billing.receipt_id = @order_id
			AND Billing.trans_source = @trans_source
			AND Billing.status_code IN ('H','S','N','V')

	SET @billing_count = @@ROWCOUNT

	IF @billing_count > 0 OR @update_count > 0
	BEGIN
		-- Either we just deleted some billing records or updated a retail order header record
		-- in any case we need to write an audit
		SELECT @audit_id = ISNULL(MAX(audit_id),0) + 1 FROM BillingAudit
		INSERT BillingAudit (audit_id, company_id, profit_ctr_id, trans_source, receipt_id, 
			line_id, price_id, billing_summary_id, transaction_code, 
			table_name, column_name, before_value, after_value, 
			date_modified, modified_by, audit_reference )
		VALUES (@audit_id, NULL, NULL, @trans_source, @order_id,
			0, 0, 0, 'X', 'Billing', 'All Lines', '', '',
			@today, @user_code, 'Unsubmitted from Billing')
	END
END 

IF @debug = 1 print 'update_count: ' + str(@update_count) + ' and billing_count: ' + str(@billing_count)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_unsubmit_order] TO [EQAI]
    AS [dbo];

