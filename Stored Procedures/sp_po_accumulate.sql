DROP PROCEDURE IF EXISTS [dbo].[sp_po_accumulate]
GO

CREATE PROCEDURE [dbo].[sp_po_accumulate]
	@debug				int,
	@customer_id		int,
	@billing_project_id	int,
	@purchase_order		varchar(20),
	@db_type			varchar(4),
	@release_code       varchar(20) = null
AS
/***************************************************************************************
Displays list of billed and expected-to-bill amounts for this purchase order

Filename:		L:\Apps\SQL\EQAI\sp_po_accumulate.sql
Loads to:		PLT_AI
PB Object(s):	d_po_accumulate

06/08/2007 SCC	Created
01/02/2008 RG	Modified for speed enhancements and for insurance surcharge.
09/09/2008 JDB	Added Energy Surcharge.
05/14/2009 KAM  Updated to not loop through the company DB's and fixed error with missing fields in insert statement
01/27/2017 MPM	Updated the Receipt query to exclude voided and rejected fingerprint lines on receipts.
05/22/2018 EQAI-50534 - AM - Added "SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED" not to block other users.
04/11/2023 AM - DevOps:41901 - PO History Report is Missing Sales Tax. Added sales TAX from billingdetail.
04/14/2023 PM - DevOps:41970 - Added Release code argument and modified queries to fetch considering release code. 
05/09/2023 PM - DevOps:65088 - Modified WHERE clause for Release code Parameter.
07/05/2023 Dipankar - DevOps 65981 - Code modified to avoid GOTO Statement, Date Comparison bein done on Date Values instead of DateTime
02/19/2024 MPM	DevOps 78698 - Added EEC fee amount.
03/08/2024 MPM	DevOps 78698 - Correction for EEC fee amount.
03/12/2024 MPM	DevOps 78698 - Reverted the changes previously made under DevOps 78698.
03/14/2024 MPM	DevOps 81061 - Made changes to correctly calculate the PO Amount, EEC Fee, Sales Tax etc. against billing records. 
                             - trans_source width increased from 10 to 50, sort_order made to float
sp_po_accumulate 1, 10673, 24, '15100304', 'DEV'
execute dbo.sp_po_accumulate 1, 601082, 21145, '57-245-21', 'DEV'
****************************************************************************************/

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE	
	@sql			varchar(4000),
	@db_count		int,
	@db_ref			varchar(40),
	@expiration_date datetime,
	@results_count	int,
	@po_amt			money,
   @po_insr_amt    money,
   @po_ensr_amt    money,
	@po_sum			money,
	@po_remains		money,
	@warning_amt	money,
	@warning_percent money,
	@warning_message varchar(80),
	@warning_level	char(1),
	@nothing_accumulated tinyint

BEGIN
	CREATE TABLE #results (
	   status_code		char(1) null,
		status			varchar(20) null,
		company_id		int null,
		profit_ctr_id	int null,
		trans_source	varchar(50) null,
		source_id		int null,
		amount			money null,
		sort_order		float null,
	   insr_amount     money null,
	   ensr_amount     money null,
	   total_amount    money null,
		invoice_code	varchar(16) null,
		invoice_date	datetime null,
		transaction_date datetime null
	)

	SET @nothing_accumulated = 0

	-- test for null arguments
	if @customer_id is null 
	begin
		SET @po_amt = 0
		SET @po_sum = 0
		SET @po_remains = 0
		SET @warning_message = ''
	--	INSERT #results VALUES ('X', 'Nothing Accumulated', 0, 0, '', 0, 0.0, 1,0,null,null, null )
	--  goto return_results
		SET @nothing_accumulated = 1
	end 

	if @purchase_order is null or @purchase_order = '' 
	begin
		SET @po_amt = 0
		SET @po_sum = 0
		SET @po_remains = 0
		SET @warning_message = ''
	--	INSERT #results VALUES ('X', 'Nothing Accumulated', 0, 0, '', 0, 0.0, 1,0,null,null, null )
	--  goto return_results
		SET @nothing_accumulated = 1
	end 

	IF @nothing_accumulated = 0
	BEGIN
		-- check the po against any billing project for th ecustomer.  if any billing project accumulates then use this value
		-- if the accumualtevalidation is nulll set it to z meaning no level
		SELECT 
 			@po_amt = MAX(po_amt), 
 			@warning_percent = MAX(IsNull(warning_percent, 90)),
 			@expiration_date = MAX(expiration_date),
			@warning_level = min(isnull(accumulate_validation,'Z'))
		 FROM CustomerBillingPO
		 WHERE customer_id = @customer_id
		-- AND billing_project_id = @billing_project_id
		 AND purchase_order = @purchase_order
		 AND (@release_code IS NULL OR release = @release_code)
		
		-- Added for #81061
		INSERT #results
		SELECT	Billing.status_code,
				NULL AS status,
				Billing.company_id, 
				Billing.profit_ctr_id,	
				'Billing-' + BillingType.billing_type_desc AS trans_source, 
				Billing.receipt_id, 
				SUM(BillingDetail.extended_amt),
				(BillingType.sort_order/ 1000) AS sort_order,
				0 AS insr_amount,
			    0 AS ensr_amount,
				0 AS total_amount,
				Billing.invoice_code,
				Billing.invoice_date, 
				Billing.billing_date
		FROM	Billing
		JOIN	BillingDetail 
		ON		Billing.receipt_id = BillingDetail.receipt_id
		AND		Billing.company_id = BillingDetail.company_id
		AND		Billing.profit_ctr_id = BillingDetail.profit_ctr_id
		AND		Billing.trans_source = BillingDetail.trans_source
		AND		Billing.billing_uid = BillingDetail.billing_uid 
		JOIN	BillingType
		ON		BillingDetail.billingtype_uid = BillingType.billingtype_uid
		WHERE   Billing.customer_id = @customer_id
		AND		Billing.purchase_order = @purchase_order
		AND		Billing.status_code in ('H','S','N','I')
		AND		(@release_code IS NULL OR Billing.release_code = @release_code)
		GROUP BY
				Billing.company_id,
				Billing.profit_ctr_id,
				Billing.trans_source,
				Billing.receipt_id,
				Billing.status_code,				
				Billing.invoice_code,
				Billing.invoice_date, 
				Billing.billing_date,
				BillingType.billing_type_desc,
				BillingType.sort_order
 
       /* -- Commented for #81061
		-- First, get all of the amounts from the billing table
		INSERT #results
		SELECT MAX(Billing.status_code),
		   NULL AS status, 
			Billing.company_id,
			Billing.profit_ctr_id,
			'Billing',
			Billing.receipt_id,
			SUM(Billing.total_extended_amt),
			4 AS sort_order,
			SUM(ISNULL(insr_extended_amt,0)),
			SUM(ISNULL(ensr_extended_amt,0)),
			0 AS total_amount,
			MAX(billing.invoice_code),
			MAX(billing.invoice_date),
			MAX(billing.billing_date)
		FROM Billing
		WHERE Billing.customer_id = @customer_id
		AND Billing.purchase_order = @purchase_order
		AND Billing.status_code in ('H','S','N','I')
		--AND Billing.release_code = isnull(@release_code,Billing.release_code)
		AND (@release_code IS NULL OR Billing.release_code = @release_code)
		GROUP BY
			Billing.company_id,
			Billing.profit_ctr_id,
			Billing.trans_source,
			Billing.receipt_id,
			Billing.status_code

		-- Get all of the amounts from the billingdetail for NY sales tax
		INSERT #results
		SELECT b.status_code,
			b.status,
			bd.company_id as company_id,
			bd.profit_ctr_id as profit_ctr_id,
			'Billing' as trans_source,
			bd.receipt_id as source_id,
			sum(bd.extended_amt) as amount ,
			4 AS sort_order,
			SUM(ISNULL(b.insr_amount,0)),
			SUM(ISNULL(b.ensr_amount,0)),
			0 AS total_amount,
			b.invoice_code, 
			b.invoice_date, 
			b.transaction_date  
		FROM BillingDetail bd 
		JOIN #results b ON  b.company_id = bd.company_id and b.source_id  = bd.receipt_id  and b.profit_ctr_id = bd.profit_ctr_id 
		WHERE  bd.sales_tax_id = (select sales_tax_id from SalesTax where sales_tax_state = 'NY' and bd.sales_tax_id = SalesTax.sales_tax_id)
		GROUP BY
			b.status_code,
			b.status,
			bd.company_id,
			bd.profit_ctr_id,
			bd.receipt_id,
			b.invoice_code,
			b.invoice_date,
			b.transaction_date 
		*/

		UPDATE #results
		SET status = CASE status_code
						WHEN 'I' THEN 'Invoiced'
						WHEN 'N' THEN 'Ready to Invoice'
						WHEN 'S' THEN 'Submitted'
						WHEN 'H' THEN 'Submitted on Hold'
						ELSE 'Unknown Status'
					END,
			sort_order = (CASE status_code
							WHEN 'I' THEN 1
							WHEN 'N' THEN 2
							WHEN 'S' THEN 3
							ELSE 4
						END ) + sort_order

		INSERT #results 
			SELECT 
				max(Receipt.receipt_status), 
				null as status, 
				Receipt.company_id, 
				Receipt.profit_ctr_id, 
				'Receipt', 
				Receipt.receipt_id,
				SUM(ReceiptPrice.total_extended_amt),
				10 as sort_order ,
			   0, 
			   0,
				0 as total_amount, 
				null as invoice_code, 
				null as invoice_date, 
				null as transaction_date  
			FROM  Receipt,
				 ReceiptPrice 
			WHERE Receipt.company_id = ReceiptPrice.company_id
				AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
				AND Receipt.receipt_id = ReceiptPrice.receipt_id
				AND Receipt.line_id = ReceiptPrice.line_id 
				AND Receipt.customer_id =  CONVERT(varchar(6), @customer_id)
				AND Receipt.purchase_order = @purchase_order 
				AND Receipt.receipt_status IN ('N','L','U','A','M') 
				AND IsNull(Receipt.submitted_flag,'F') = 'F' 
				AND Receipt.fingerpr_status NOT IN ('V','R')
				AND (@release_code IS NULL OR Receipt.release = @release_code)
			GROUP BY 
			Receipt.company_id, 
			Receipt.profit_ctr_id, 
			Receipt.receipt_id 
		
	
		--        now get workorders 
		insert #results 
			SELECT 
				isnull(WorkOrderHeader.workorder_status,'N'), 
				null as status, 
				ProfitCenter.company_id,
				WorkOrderHeader.profit_ctr_id, 
				'Work Order', 
				WorkOrderHeader.workorder_id, 
				IsNull(WorkOrderHeader.total_price,0), 
				10 as sort_order, 
			   0, 
			   0,
				0 as total_amount,
				null as invoice_code,  
				null as invoice_date, 
				null as transaction_date  
			FROM WorkOrderHeader , 
				ProfitCenter 
			WHERE WorkOrderHeader.company_id = ProfitCenter.company_id 
				AND WorkOrderHeader.profit_ctr_id = ProfitCenter.profit_ctr_id 
				AND WorkOrderHeader.customer_id = CONVERT(varchar(6), @customer_id)
			   AND WorkOrderHeader.purchase_order = @purchase_order 
				AND WorkOrderHeader.workorder_status IN ('N','C','D','A') 
				AND IsNull(WorkOrderHeader.submitted_flag,'F') = 'F'
				AND (@release_code IS NULL OR WorkOrderHeader.release_code = @release_code)
		-- now update the status and sort order for receipt

		update #results
		set status = CASE status_code 
						WHEN 'N' THEN 'New'
						WHEN 'L' THEN 'Lab'
						WHEN 'U' THEN 'Unloading'
						WHEN 'A' THEN 'Accepted' 
						WHEN 'M' THEN 'Manual'
						ELSE 'Unknown Status' 
					END ,
			sort_order = CASE status_code 
							WHEN 'N' THEN 9 
							WHEN 'L' THEN 8 
							WHEN 'U' THEN 6 
							WHEN 'A' THEN 5 
							ELSE 10 
						END
		where trans_source = 'Receipt'

		-- now update the status and sort order for workorder

		update #results
		set status = CASE status_code 
						WHEN  'N'  THEN  'New' 
						WHEN  'H'  THEN  'Hold' 
						WHEN  'C'  THEN  'Completed' 
						WHEN  'D'  THEN  'Dispatched' 
						WHEN  'P'  THEN  'Priced' 
						WHEN  'A'  THEN  'Accepted'  
						ELSE  'Unknown Status'  
					END,

			sort_order = CASE status_code 
							WHEN  'N'  THEN 9  
							WHEN  'C'  THEN 7  
							WHEN  'D'  THEN 8  
							WHEN  'P'  THEN 6  
							WHEN  'A'  THEN 5 
							ELSE 10 
						END  
		WHERE trans_source = 'Work Order'

		IF @debug = 1 
		BEGIN
			SELECT * FROM #results
		END

		-- update total amount
		UPDATE #results SET total_amount = amount + insr_amount + ensr_amount


		-- Insert a dummy record if there are no results
		SELECT @results_count = count(*) FROM #results
		IF @results_count = 0
			INSERT #results VALUES ('X', 'Nothing Accumulated', 0, 0, '', 0, 0.0, 1,0,0,0,null,null, null )

		 IF @debug = 1 print 'Selecting #results'
		 IF @debug = 1 Select * FROM #results


		-- Get the PO sum
		SELECT @po_sum = SUM(ISNULL(amount,0)),
			   @po_insr_amt = SUM(ISNULL(insr_amount, 0 )),
			   @po_ensr_amt = SUM(ISNULL(ensr_amount, 0 ))
		FROM #results


		SELECT @po_sum = @po_sum + @po_insr_amt + @po_ensr_amt

		-- Show amount remaining on the PO
		SET @warning_message = ''

		IF @po_amt = 0
		BEGIN
			SET @po_amt = NULL
			SET @po_remains = NULL
		END

		ELSE IF @po_amt = @po_sum
		BEGIN
			SET @po_remains = 0
			SET @warning_message = 'PO Complete'
		END

		ELSE IF @po_amt > @po_sum 
		BEGIN
			SET @po_remains = @po_amt - @po_sum
			SET @warning_amt = @po_amt * (@warning_percent/100)
			IF @po_sum >= @warning_amt 
				SET @warning_message = 'About to Exceed PO Amount'
		END

		ELSE IF @po_amt < @po_sum
		BEGIN
			SET @po_remains = NULL
			SET @warning_message = 'PO Amount Exceeded'
		END

		ELSE
		BEGIN
			SET @po_remains = 0
		END 

		-- Check for expiration
		IF @debug = 1 print '@expiration_date: ' + CONVERT(varchar(30), @expiration_date)
		IF @expiration_date IS NOT NULL 
		BEGIN
			IF CAST(@expiration_date as DATE) <= CAST(getdate() as DATE)
				IF @warning_message = ''
					SET @warning_message = 'PO is expired'
				ELSE
					SET @warning_message = @warning_message + ' and PO is expired'
			ELSE IF DATEADD(m, 1, CAST(getdate() as DATE)) >= CAST(@expiration_date as DATE)
				IF @warning_message = ''
					SET @warning_message = 'PO is about to expire (' + CONVERT(varchar(10),@expiration_date,101) + ')'
				ELSE
					SET @warning_message = @warning_message + ' and PO is about to expire (' + CONVERT(varchar(10),@expiration_date,101) + ')'
		END
		IF @warning_message <> ''
			SET @warning_message = '**' + @warning_message + '**'
	END -- IF @nothing_accumulated = FALSE
	-- return_results:

	SELECT status,
		company_id,
		profit_ctr_id,
		trans_source,
		source_id,
		amount,
		sort_order, 
		@po_amt as po_amt,
		@po_sum as po_sum,
		@po_remains as po_remains,
		@warning_message AS warning_message,
		invoice_code,
		invoice_date,
		transaction_date,
	   total_amount
	FROM #results
	order by sort_order, transaction_date
END

GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_po_accumulate] TO [EQAI];

