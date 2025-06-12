CREATE PROCEDURE sp_billing_submit_order
	@debug			int,
	@trans_source	char(1),
	@order_id		int,
	@submit_date	datetime,
	@submit_status	char(1),
	@user_code		varchar(20)
AS
/***************************************************************************************
Submit Retail Orders to the Billing table

Filename:	L:\Apps\SQL\EQAI\sp_billing_submit.sql
Loads to:		PLT_AI
trans_source: <R>eceipt, <W>orkorder, Retail <O>rder  (Only 'O' applies for this procedure)

03/25/2008 WAC	Copied from sp_billing_submit then incorporated retail order processing.
04/16/2008 WAC	All orders are now submitted with a price_id = 1 even though price_id
		is not applicable.
05/16/2008 KAM	Updated to correct an issue where all retail order were being submitted as paid in full.
06/17/2008 KAM  Updated to update the modified User Time and date on the Order header when submitting to billing
07/17/2008 JDB	Removed source fields from Billing table
09/05/2008 KAM	Update the procedure to set the trans_type column to an 'R' instead of an empty string
09/09/2008 JDB	Added new Energy Surcharge fields to Billing table
05/20/2009 JDB	Changed to populate Billing.cash_received with OrderDetail.extended_amt instead
				of OrderHeader.total_amt_payment.  This showed up as a problem because retail order
				1528 actually had two lines, and was paid using a credit card.
10/29/2010 JDB	Added code to populate new BillingDetail table.
03/16/2012 JDB	Added support for new identity columns on Billing and BillingDetail tables.
				Removed Billing.gl_insr_account_code and Billing.gl_ensr_account_code fields.
03/27/2012 SK	Fixed the Select query to #BillingDetail, columns date_added thru date_modified not declared in the temp table
03/29/2012 SK	Added a SQL transaction to the procedure so that records aren't added to Billing but not BillingDetail.
				Fixed error when inserting into BillingDetail.
				Commented out code for BillingComment since the table is not necessary for retail orders.
04/12/2012 JDB	Updated the CREATE statement for #BillingDetail so that the sales_tax_id field is nullable.
04/01/2013 JDB	Added the population of the new billingtype_uid field in BillingDetail.
04/22/2013 JDB	Modified to populate new JDE GL fields and replaced the use of Billing GL fields with those of BillingDetail.
05/09/2013 RB   04/22/2013 modification broke the population of #BillingDetail, orders were not being submitted
06/03/2013 JDB	Modified to populate OrderAudit table with invalid JDE GL Accounts.
06/27/2013 SK	Added logic to insert into BillingComment, so that service_date can be populated for retail order billing records.
08/23/2013 SK	Waste_code and Waste_code_uid should really be NULL for retail, earlier used to insert 'EQRO" which does not
				exist into the WasteCode table and is not used by anything.
08/11/2014 SK	Added Ship TO fields on the Invoice Comment				
07/27/2016 AM   Added code for AX GL account
02/15/2018 MPM	Added currency_code column to #Billing and #BillingDetail.
08/04/2021 MPM	DevOps 19760 - Commented out the check for a valid Product.gl_account_code, since that column is no longer used.
12/01/2021 AM  DevOps:29616 - Changed generator_name length from varchar(40) to varchar(75)
07/04/2024 KS	Rally116983 - Modified service_desc_1 and service_desc_2 datatype to VARCHAR(100) for #Billing table.

EXEC sp_billing_unsubmit_order 1, 5069, 'O', 'JASON_B'
EXEC sp_billing_submit_order 1, 'O', 6595, '07-31-2013 15:30', NULL, 'SMITA_K'

EXEC sp_billing_submit_order 1, 'O', 8087, '2015-11-23', NULL, 'ANITHA_M'
EXEC sp_billing_submit_order 1, 'O', 8544, '2016-11-14', NULL, 'ANITHA_M'
****************************************************************************************/
SET NOCOUNT ON

DECLARE
	@order_count		int,
	@billing_count		int,
	@sync_invoice_jde	tinyint,
	@sync_invoice_ax	tinyint,
	@sync_ax_Service	tinyint,
	@invalid_gl_count	int,
	@error_msg			varchar(8000),
	@error_value		int,
	@AX_Project_Required_Flag char(1),
	@AX_Project_Required_Flag_count int,
	@invalid_ax_count	int,
	@result varchar (max),
	@ax_web_service varchar(max)
-- Prepare Billing records
CREATE TABLE #Billing  (
	billing_uid				int NOT NULL IDENTITY (1,1),
	company_id			smallint NOT NULL,
	profit_ctr_id			smallint NOT NULL,
	trans_source			char (1) NULL,
	receipt_id			int NULL,
	line_id				int NULL,
	price_id			int NULL,
	status_code			char (1) NULL,
	billing_date			datetime NULL,
	customer_id			int NULL,
	waste_code			varchar (4) NULL,
	bill_unit_code			varchar (4) NULL,
	vehicle_code			varchar (10) NULL,
	generator_id			int NULL,
	generator_name			varchar (75) NULL,
	approval_code			varchar (15) NULL,
	time_in				datetime NULL,
	time_out			datetime NULL,
	tender_type 			char (1) NULL,
	tender_comment			varchar (60) NULL,
	quantity			float NULL,
	price				money NULL,
	add_charge_amt			money NULL,
	orig_extended_amt		money NULL,
	discount_percent		float NULL,
	--gl_account_code			varchar (32) NULL,
	--gl_sr_account_code		varchar (32) NULL,
	gl_account_type			char (1) NULL,
	gl_sr_account_type		char (1) NULL,
	sr_type_code			char (1) NULL,
	sr_price			money NULL,
	waste_extended_amt		money NULL,
	sr_extended_amt			money NULL,
	total_extended_amt		money NULL,
	cash_received			money NULL,
	manifest			varchar (15) NULL,
	shipper				varchar (15) NULL,
	hauler				varchar (20) NULL,
	source				varchar (15) NULL,
	truck_code			varchar (10) NULL,
	source_desc			varchar (25) NULL,
	gross_weight			int NULL,
	tare_weight			int NULL,
	net_weight			int NULL,
	cell_location			varchar (15) NULL,
	manual_weight_flag		char (1) NULL,
	manual_price_flag		char (1) NULL,
	price_level			char (1) NULL,
	comment				varchar (60) NULL,
	operator			varchar (10) NULL,
	workorder_resource_item		varchar (15) NULL,
	workorder_invoice_break_value	varchar (15) NULL,
	workorder_resource_type		varchar (15) NULL,
	workorder_sequence_id		varchar (15) NULL,
	purchase_order			varchar (20) NULL,
	release_code			varchar (20) NULL,
	cust_serv_auth			varchar (15) NULL,
	taxable_mat_flag		char (1) NULL,
	license				varchar (10) NULL,
	payment_code			varchar (13) NULL,
	bank_app_code			varchar (13) NULL,
	number_reprints			smallint NULL,
	void_status			char (1) NULL,
	void_reason			varchar (60) NULL,
	void_date			datetime NULL,
	void_operator			varchar (8) NULL,
	date_added			datetime NULL,
	date_modified			datetime NULL,
	added_by			varchar (10) NULL,
	modified_by			varchar (10) NULL,
	trans_type			char (1) NULL,
	ref_line_id			int NULL,
	service_desc_1			varchar (100) NULL,
	service_desc_2			varchar (100) NULL,
	cost				money NULL,
	secondary_manifest		varchar (15) NULL,
	insr_percent			money NULL,
	insr_extended_amt		money NULL,
	--gl_insr_account_code		varchar (32) NULL,
	ensr_percent			money NULL,
	ensr_extended_amt		money NULL,
	--gl_ensr_account_code		varchar (32) NULL,
	bundled_tran_bill_qty_flag	varchar (4) NULL,
	bundled_tran_price		money NULL,
	bundled_tran_extended_amt	money NULL,
	--bundled_tran_gl_account_code	varchar (32) NULL,
	product_id			int NULL,
	billing_project_id		int NULL,
	po_sequence_id			int NULL,
	invoice_preview_flag		char (1) NULL,
	COD_sent_flag			char (1) NULL,
	COR_sent_flag			char (1) NULL,
	invoice_hold_flag		char (1) NULL,
	profile_id			int NULL,
	reference_code			varchar(32) NULL,
	tsdf_approval_id		int NULL,
	billing_link_id			int NULL,
	hold_reason			varchar(255) NULL,
	hold_userid			varchar(10) NULL,
	hold_date			datetime NULL,
	invoice_id			int NULL,
	invoice_code			varchar(16) NULL,
	invoice_date			datetime NULL,
	date_delivered			datetime NULL,
	waste_code_uid		int	NULL,
	currency_code		char(3)	NULL
)

CREATE TABLE #BillingComment (
	company_id			smallint NOT NULL,
	profit_ctr_id		smallint NOT NULL,
	trans_source		char (1) NULL,
	receipt_id			int NULL,
	receipt_status		char (1) NULL,
	project_code		varchar (15) NULL,
	project_name		varchar (60) NULL,
	comment_1			varchar (80) NULL,
	comment_2			varchar (80) NULL,
	comment_3			varchar (80) NULL,
	comment_4			varchar (80) NULL,
	comment_5			varchar (80) NULL,
	added_by			varchar (8) NULL,
	date_added			datetime NULL,
	modified_by			varchar (8) NULL,
	date_modified		datetime NULL,
	service_date		datetime NULL
)

-- Prepare BillingDetail records
CREATE TABLE #BillingDetail (
	billingdetail_uid	int				NOT NULL IDENTITY (1,1),
	billing_uid			int				NOT NULL,
	ref_billingdetail_uid	int			NULL,
	billingtype_uid		int				NULL,
	billing_type		varchar(10)		NULL,
	company_id			int				NULL,
	profit_ctr_id		int				NULL,
	receipt_id			int				NULL,
	line_id				int				NULL,
	price_id			int				NULL,
	trans_source		char(1)			NULL,
	trans_type			char(1)			NULL,
	product_id			int				NULL,
	dist_company_id		int				NULL,
	dist_profit_ctr_id	int				NULL,
	sales_tax_id		int				NULL,
	applied_percent		decimal(18,6)	NULL,
	extended_amt		decimal(18,6)	NULL,
	gl_account_code		varchar(32)		NULL,
	sequence_id			int				NULL,
	JDE_BU				varchar(7)		NULL,
	JDE_object			varchar(5)		NULL,
	AX_MainAccount		varchar(20),
	AX_Dimension_1		varchar(20),
	AX_Dimension_2		varchar(20),
	AX_Dimension_3		varchar(20),
	AX_Dimension_4		varchar(20),
	AX_Dimension_5_part_1 varchar(20),
	AX_Dimension_5_part_2 varchar(9),
	AX_Dimension_6	    varchar(20)	,
	AX_Project_Required_Flag char(1),
	currency_code		char(3)	NULL

)

---------------------------------------------------------------
-- Do we export invoices/adjustments to JDE?
---------------------------------------------------------------
SELECT @sync_invoice_jde = sync
FROM FinanceSyncControl
WHERE module = 'Invoice'
AND financial_system = 'JDE'

SELECT @sync_invoice_ax = sync
FROM FinanceSyncControl
WHERE module = 'Invoice'
AND financial_system = 'AX'

SELECT  @sync_ax_Service = sync
FROM FinanceSyncControl
WHERE module = 'Dimension Service Validation'
AND financial_system = 'AX'

SELECT @ax_web_service = config_value
FROM Configuration
where config_key =  'ax_web_service'

--	trans_source = 'O' is the only transaction that this procedure knows how to process
IF @trans_source = 'O'
BEGIN
--------------------------
-- Submit Retail Order
--------------------------
	INSERT #Billing 
	SELECT
		OrderDetail.company_id,
		OrderDetail.profit_ctr_id,
		'O' AS trans_source,
		OrderDetail.order_id AS receipt_id,
		OrderDetail.line_id,
		1 AS price_id,
		'S' AS status_code,
		OrderHeader.order_date AS billing_date,
		OrderHeader.customer_id AS customer_id,
		--'EQRO' AS waste_code,		-- ???? WO = 'EQWO'
		NULL AS waste_code,
		ISNULL(Product.bill_unit_code,'') AS bill_unit_code,
		NULL AS vehicle_code,
		OrderHeader.generator_id AS generator_id,
		'' AS generator_name,
		'' AS approval_code,
		NULL AS time_in,		-- ????
		NULL AS time_out,		-- ????
		Case when OrderHeader.Order_type = 'C' Then '3' ELSE '4' END AS tender_type,		
		'' AS tender_comment,
		ISNULL(OrderDetail.quantity,0) AS quantity,
		ISNULL(OrderDetail.price,0) AS price,
		0 AS add_charge_amt,
		ISNULL(OrderDetail.extended_amt,0) AS orig_extended_amt,
		-- discounts in the billing table could really mess up a paid order.  Should we assume 
		-- that discount doesn't apply to a paid order??
		CASE WHEN IsNull(ProfitCenter.discount_flag,'F') = 'T' AND IsNull(OrderHeader.total_amt_payment,0) = 0 
			THEN ISNULL(CustomerBilling.cust_discount,0) ELSE 0 END AS discount_percent, --??
		--ISNULL(Product.gl_account_code,'') AS gl_account_code,	-- ????
		--'' AS gl_sr_account_code,	-- ????
		'' AS gl_account_type,		-- ????
		'' AS sr_type,			-- ????
		'E' AS sr_type_code,		-- ????
		0 AS sr_price,
		ISNULL(OrderDetail.extended_amt,0) AS waste_extended_amt,
		0 AS sr_extended_amt,
		ISNULL(OrderDetail.extended_amt,0) AS total_extended_amt,
		-- Don't have a payment amount field in the detail record, but we do have payment amount
		-- in the header.  For now assume that if there is any payment at all for this order (by credit card)
		-- that the whole order has been paid in full and that the extended amount of this line
		-- item is the payment amount for the line item
		CASE WHEN OrderHeader.Order_type = 'C' THEN OrderDetail.extended_amt 
			ELSE 0.00
			END AS cash_received,
		'' AS manifest,
		'' AS shipper,
		'' AS hauler,
		'' AS source,
		'' AS truck_code,
		'' AS source_desc,
		0 AS gross_weight,
		0 AS tare_weight,
		0 AS net_weight,
		'' AS cell_location,
		'' AS manual_weight_flag,
		'' AS manual_price_flag,
		'' AS price_level,
		'' AS comment,
		'' AS operator,
		'' AS workorder_resource_item,
		'' AS workorder_invoice_break_value,
		'' AS workorder_resource_type,
		'' AS workorder_sequence_id,
		ISNULL(REPLACE(OrderHeader.purchase_order,'''', ''),'') AS purchase_order,
		ISNULL(REPLACE(OrderHeader.release_code,'''', ''),'') AS release_code,
		'' AS cust_serv_auth,
		'' AS taxable_mat_flag,
		'' AS license,
		'' AS payment_code,
		'' AS bank_app_code,
		0 AS number_reprints,
		'F' AS void_status,
		'' AS void_reason,
		NULL AS void_date,
		'' AS void_operator,
		@submit_date AS date_added,
		@submit_date AS date_modified,
		@user_code AS added_by,
		@user_code AS modified_by,
		'R' AS trans_type,
		NULL AS ref_line_id,
		Product.description AS service_desc_1,
		'' AS service_desc_2,
		0 AS cost,
		'' AS secondary_manifest,
		0 AS insr_percent,
		0 AS insr_extended_amt,
		--NULL AS gl_insr_account_code,
		0 AS ensr_percent,
		0 AS ensr_extended_amt,
		--NULL AS gl_ensr_account_code,
		0 AS bundled_tran_bill_qty_flag,
		0 AS bundled_tran_price,
		0 AS bundled_tran_extended_amt,
		--'' AS bundled_tran_gl_account_code,
		OrderDetail.product_id,
		OrderHeader.billing_project_id AS billing_project_id,
		0 AS po_sequence_id,
		'F' AS invoice_preview_flag,
		'F' AS COD_sent_flag,
		'F' AS COR_sent_flag,
		'F' AS invoice_hold_flag,
		NULL AS profile_id,
		ISNULL(CustomerBilling.reference_code,'') AS reference_code,
		CONVERT(int, NULL) AS tsdf_approval_id,
		NULL AS billing_link_id,
		'' AS hold_reason,
		NULL AS hold_userid,
		NULL AS hold_date,
		NULL AS invoice_id,
		NULL AS invoice_code,
		NULL AS invoice_date,
		NULL AS date_delivered,
		NULL AS waste_code_uid,
		OrderDetail.currency_code
	FROM OrderHeader
	JOIN OrderDetail ON OrderDetail.order_id = OrderHeader.order_id
	LEFT OUTER JOIN CustomerBilling ON CustomerBilling.customer_id = OrderHeader.customer_id
		AND CustomerBilling.billing_project_id = OrderHeader.billing_project_id
	LEFT OUTER JOIN Product ON Product.product_id = OrderDetail.product_id
		AND Product.company_id = OrderDetail.company_id
		AND Product.profit_ctr_id = OrderDetail.profit_ctr_id
	LEFT OUTER JOIN ProfitCenter ON ProfitCenter.company_id = OrderDetail.company_id 
		AND ProfitCenter.profit_ctr_id = OrderDetail.profit_ctr_id
	WHERE  OrderDetail.order_id = @order_id
		AND OrderDetail.status = 'P'	-- processed, not new, void
		AND OrderHeader.status = 'P'	-- processed, not new, hold, void
		AND ISNULL(OrderHeader.submitted_flag,'F') = 'F'
		AND NOT EXISTS (SELECT 1 FROM Billing 
			WHERE Billing.company_id = OrderDetail.company_id
			AND Billing.profit_ctr_id = OrderDetail.profit_ctr_id
			AND Billing.receipt_id = OrderDetail.order_id
			AND Billing.line_id = OrderDetail.line_id
			AND Billing.price_id = 1
			AND Billing.receipt_id = @order_id
			AND Billing.trans_source = @trans_source)
	SELECT @order_count = @@ROWCOUNT
	
	IF @debug = 1 print 'Selecting Retail Order billing records:'
	IF @debug = 1 SELECT * FROM #Billing
	
			INSERT #BillingDetail
			SELECT 
				b.billing_uid AS billing_uid,
				NULL AS ref_billingdetail_uid,
				bt.billingtype_uid,
				bt.billing_type,
				b.company_id,
				b.profit_ctr_id,
				b.receipt_id,
				b.line_id,
				b.price_id,
				b.trans_source,
				b.trans_type,
				b.product_id, 
				b.company_id AS dist_company_id,
				b.profit_ctr_id AS dist_profit_ctr_id,
				NULL AS sales_tax_id,
				NULL AS applied_percent,
				b.waste_extended_amt AS extended_amt,
				--b.gl_account_code,
				ISNULL(Product.gl_account_code, 'XXXXXXXXXXXX') AS gl_account_code,
				NULL AS Sequence_ID,
				ISNULL(Product.JDE_BU, 'XXXXXXX') AS JDE_BU,
				ISNULL(Product.JDE_object, 'XXXXX') AS JDE_object,
				Product.AX_MainAccount AS AX_MainAccount,
				Product.AX_Dimension_1 AS AX_Dimension_1,
				Product.AX_Dimension_2 AS AX_Dimension_2,
				Product.AX_Dimension_3 AS AX_Dimension_3,
				Product.AX_Dimension_4 AS AX_Dimension_4,
				Product.AX_Dimension_5_part_1 AS AX_Dimension_5_part_1,
				Product.AX_Dimension_5_part_2 AS AX_Dimension_5_part_2,
				Product.AX_Dimension_6 AS AX_Dimension_6,
				Null AS AX_Project_Required_Flag,
				b.currency_code
			FROM #Billing b
			LEFT OUTER JOIN Product ON Product.product_id = b.product_id
				AND Product.company_id = b.company_id
				AND Product.profit_ctr_id = b.profit_ctr_id
			JOIN BillingType bt ON bt.billing_type = 'Retail'
			WHERE 1=1
			AND b.receipt_id = @order_id
			AND b.trans_source = 'O'
			AND b.trans_type = 'R'
			AND b.waste_extended_amt > 0	
			 		
	IF @debug = 1 print 'Selecting Retail Order billing detail:'
	--SELECT * FROM #BillingDetail

	-- Get Billing Comments 
	INSERT INTO #BillingComment
	SELECT DISTINCT
		b.company_id,
		b.profit_ctr_id,
		b.trans_source,
		b.receipt_id,
		'A' AS receipt_status,
		'' AS project_code,
		'' AS project_name,
		OrderHeader.ship_addr1 AS invoice_comment_1,
		CASE WHEN IsNull(OrderHeader.ship_addr2, '') = '' 
				THEN CASE WHEN IsNull(OrderHeader.ship_addr3, '') = ''
						THEN CASE WHEN IsNull(OrderHeader.ship_addr4, '') = ''
								THEN OrderHeader.ship_city + ', ' + OrderHeader.ship_state + '  ' + OrderHeader.ship_zip_code
								ELSE OrderHeader.ship_addr4 END
						ELSE OrderHeader.ship_addr3 END
				ELSE OrderHeader.ship_addr2 END AS invoice_comment_2,
		CASE WHEN IsNull(OrderHeader.ship_addr3, '') = ''
			 THEN CASE WHEN IsNull(OrderHeader.ship_addr4, '') = ''
					   THEN CASE WHEN IsNull(OrderHeader.ship_addr2, '') = '' 
								THEN ''
								ELSE OrderHeader.ship_city + ', ' + OrderHeader.ship_state + '  ' + OrderHeader.ship_zip_code END
						ELSE OrderHeader.ship_addr4 END
			ELSE OrderHeader.ship_addr3 END AS invoice_comment_3,
		CASE WHEN IsNull(OrderHeader.ship_addr4, '') = ''
			 THEN CASE WHEN IsNull(OrderHeader.ship_addr3, '') = '' THEN '' 
						ELSE CASE WHEN IsNull(OrderHeader.ship_addr2, '') = '' THEN ''
								ELSE OrderHeader.ship_city + ', ' + OrderHeader.ship_state + '  ' + OrderHeader.ship_zip_code
								END END
			ELSE OrderHeader.ship_addr4 END AS invoice_comment_4,
		CASE WHEN (OrderHeader.ship_addr4 > '' AND OrderHeader.ship_addr3 > '' AND OrderHeader.ship_addr2 > '') THEN OrderHeader.ship_city + ', ' + OrderHeader.ship_state + '  ' + OrderHeader.ship_zip_code 
		ELSE '' END AS invoice_comment_5,
		@user_code AS added_by,
		@submit_date AS date_added,
		@user_code AS modified_by,
		@submit_date AS date_modified,
		b.billing_date AS service_date
	FROM #Billing b
	JOIN OrderHeader 
		ON OrderHeader.order_id = b.receipt_id 
	JOIN OrderDetail
		ON OrderDetail.order_id = b.receipt_id
		AND OrderDetail.line_id = b.line_id
		AND OrderDetail.company_id = b.company_id
		AND OrderDetail.profit_ctr_id = b.profit_ctr_id
	LEFT OUTER JOIN Product ON Product.product_id = b.product_id
		AND Product.company_id = b.company_id
		AND Product.profit_ctr_id = b.profit_ctr_id
	JOIN BillingType bt ON bt.billing_type = 'Retail'
	WHERE 1=1
	AND b.receipt_id = @order_id
	AND b.trans_source = 'O'
	AND b.trans_type = 'R'
	AND b.waste_extended_amt > 0
		
END

-------------------------------------------------------------------------------------
-- Check for gl accounts with "X" or "Z" in them, and don't submit if we find any
-------------------------------------------------------------------------------------
SET @invalid_gl_count = 0
SET @invalid_ax_count = 0
SET @AX_Project_Required_Flag_count = 0
SET @error_value = 0

SELECT @AX_Project_Required_Flag_count = @AX_Project_Required_Flag_count + COUNT(*) FROM #BillingDetail WHERE (AX_Project_Required_Flag = 'T' )
 -- Below for Receipt
 IF @sync_invoice_ax = 1 AND @trans_source = 'O'
BEGIN
 IF @AX_Project_Required_Flag_count > 0
  BEGIN
	SELECT @invalid_ax_count = @invalid_ax_count + COUNT(*) FROM #BillingDetail WHERE (AX_Dimension_5_part_1 = '' OR AX_Dimension_5_part_2 = '' )

    IF  @invalid_ax_count > 0 
    BEGIN
	--	------------------------------------
	--	-- Then, for Receipts:
	--	------------------------------------
	 IF @sync_ax_Service = 1 
	   BEGIN
	  	select distinct bd.AX_MainAccount,bd.AX_Dimension_1,bd.AX_Dimension_2,bd.AX_Dimension_3,bd.AX_Dimension_4,bd.AX_Dimension_6,
                      bd.AX_Dimension_5_part_1,bd.AX_Dimension_5_part_2, convert(varchar(max),null) as status
		into #acc
		FROM #BillingDetail bd
		WHERE 1=1
		AND bd.trans_source = 'O'
		
		update #acc
	    set status = dbo.fnValidateFinancialDimension (@ax_web_service,AX_MainAccount,AX_Dimension_1,AX_Dimension_2,AX_Dimension_3,AX_Dimension_4,AX_Dimension_6,
                           AX_Dimension_5_part_1,AX_Dimension_5_part_2 )
                           
        IF @debug = 1 PRINT '@result = ' + CONVERT(varchar(4), @result)   
                                                        
				INSERT INTO  OrderAudit (order_id, line_id, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
				SELECT DISTINCT bd.receipt_id, bd.line_id, NULL, '', '', bd.billing_type AS before_value, 
				bd.AX_MainAccount + '-' + bd.AX_Dimension_1 + '-' + bd.AX_Dimension_2 + '-' + bd.AX_Dimension_3 + '-' + bd.AX_Dimension_4 + '-' + ISNULL(bd.AX_Dimension_6, '') + '-' + ISNULL(bd.AX_Dimension_5_part_1, '') + CASE WHEN ISNULL(bd.AX_Dimension_5_part_2, '') <> '' THEN '.' + bd.AX_Dimension_5_part_2 ELSE '' END  + 
					LEFT ( dbo.fnValidateFinancialDimension(@ax_web_service,bd.AX_MainAccount, bd.AX_Dimension_1, bd.AX_Dimension_2, bd.AX_Dimension_3, bd.AX_Dimension_4, bd.AX_Dimension_6, bd.AX_Dimension_5_part_1, bd.AX_Dimension_5_part_2 ), 255)  AS after_value,
					'Submit to Billing Failed. AX Dimension 5 (Project - Subproject) missing.' AS audit_reference, @user_code, 'BS SP', @submit_date
				FROM #BillingDetail bd
			    JOIN #acc a on bd.AX_MainAccount = a.AX_MainAccount and bd.AX_Dimension_1 = a.AX_Dimension_1 and bd.AX_Dimension_2 = a.AX_Dimension_2
				   AND bd.AX_Dimension_3 = a.AX_Dimension_3 and  bd.AX_Dimension_4 = a.AX_Dimension_4
				   AND bd.AX_Dimension_6 = a.AX_Dimension_6 and  bd.AX_Dimension_5_Part_1 = a.AX_Dimension_5_Part_1 and bd.AX_Dimension_5_Part_2 = a.AX_Dimension_5_Part_2
				WHERE 1=1
				AND bd.trans_source = 'O'
			   AND UPPER (a.status ) <> 'VALID'
			--AND ( dbo.fnValidateFinancialDimension (bd.AX_MainAccount,bd.AX_Dimension_1,bd.AX_Dimension_2,bd.AX_Dimension_3,bd.AX_Dimension_4,bd.AX_Dimension_6,
			--						  bd.AX_Dimension_5_part_1,bd.AX_Dimension_5_part_2 ) ) <> 'Valid'
				
			SELECT @invalid_ax_count =  @@ROWCOUNT, @error_value = @@ERROR  
		END 
	 ELSE
	   BEGIN
	 	INSERT INTO  OrderAudit (order_id, line_id, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
		SELECT DISTINCT bd.receipt_id, bd.line_id, NULL, '', '', bd.billing_type AS before_value, 
		bd.AX_MainAccount + '-' + bd.AX_Dimension_1 + '-' + bd.AX_Dimension_2 + '-' + bd.AX_Dimension_3 + '-' + bd.AX_Dimension_4 + '-' + ISNULL(bd.AX_Dimension_6, '') + '-' + ISNULL(bd.AX_Dimension_5_part_1, '') + CASE WHEN ISNULL(bd.AX_Dimension_5_part_2, '') <> '' THEN '.' + bd.AX_Dimension_5_part_2 ELSE '' END  AS after_value,
		'Submit to Billing Failed. AX fields are missing.' AS audit_reference, @user_code, 'BS SP', @submit_date
		FROM #BillingDetail bd
		WHERE 1=1
		AND bd.trans_source = 'O'
			
		SELECT @invalid_ax_count =  @@ROWCOUNT, @error_value = @@ERROR
	   END
	END          
	  IF @error_value <> 0
	    BEGIN		
			-- Set message for RAISEERROR and go to the end
			SET @error_msg = 'Error inserting record into Audit tables for invalid/missing AX account(s).'
			GOTO END_OF_PROC
		END  
	  --IF @debug = 1 PRINT '@invalid_ax_count = ' + CONVERT(varchar(4), @invalid_ax_count)
  END

  --SELECT @invalid_ax_count = @invalid_ax_count + COUNT(*) FROM #BillingDetail 
  --  WHERE ( AX_MainAccount = 'X' OR AX_Dimension_1 = 'X' OR AX_Dimension_2 = 'X' OR AX_Dimension_3 = 'X' OR AX_Dimension_4 = 'X' OR AX_Dimension_6 = 'X')
    
    --IF @debug = 1 PRINT 'Receipt anitha @invalid_ax_count = ' + CONVERT(varchar(4), @invalid_ax_count)
	
 --IF @invalid_ax_count > 0
 -- BEGIN 
    BEGIN
	--	------------------------------------
	--	-- Then, for Receipts:
	--	------------------------------------
	IF @sync_ax_Service = 1 
	  BEGIN
	  	select distinct bd.AX_MainAccount,bd.AX_Dimension_1,bd.AX_Dimension_2,bd.AX_Dimension_3,bd.AX_Dimension_4,bd.AX_Dimension_6,
                      bd.AX_Dimension_5_part_1,bd.AX_Dimension_5_part_2, convert(varchar(max),null) as status
		into #accountnumber
		FROM #BillingDetail bd
		WHERE 1=1
		AND bd.trans_source = 'O'
		
		update #accountnumber
	    set status = dbo.fnValidateFinancialDimension (@ax_web_service,AX_MainAccount,AX_Dimension_1,AX_Dimension_2,AX_Dimension_3,AX_Dimension_4,AX_Dimension_6,
                           AX_Dimension_5_part_1,AX_Dimension_5_part_2 )
                           
        IF @debug = 1 PRINT '@result = ' + CONVERT(varchar(4), @result)                                                   
		--select @result = fnValidateFinancialDimension(bd.AX_MainAccount, bd.AX_Dimension_1, bd.AX_Dimension_2, bd.AX_Dimension_3, bd.AX_Dimension_4, bd.AX_Dimension_6, bd.AX_Dimension_5_part_1, bd.AX_Dimension_5_part_2 )
		 -- FROM #BillingDetail bd
			--JOIN #Billing b ON b.billing_uid = bd.billing_uid
			--WHERE 1=1
			--AND bd.trans_source = 'O			
			INSERT INTO  OrderAudit (order_id, line_id, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
			SELECT DISTINCT bd.receipt_id, bd.line_id, NULL, '', '', bd.billing_type AS before_value,
			bd.AX_MainAccount + '-' + bd.AX_Dimension_1 + '-' + bd.AX_Dimension_2 + '-' + bd.AX_Dimension_3 + '-' + bd.AX_Dimension_4  + '-' + ISNULL(bd.AX_Dimension_6, '') + '-' + ISNULL(bd.AX_Dimension_5_part_1, '') + CASE WHEN ISNULL(bd.AX_Dimension_5_part_2, '') <> '' THEN '.' + bd.AX_Dimension_5_part_2 ELSE '' END  + 
			LEFT (dbo.fnValidateFinancialDimension(@ax_web_service,bd.AX_MainAccount, bd.AX_Dimension_1, bd.AX_Dimension_2, bd.AX_Dimension_3, bd.AX_Dimension_4, bd.AX_Dimension_6, bd.AX_Dimension_5_part_1, bd.AX_Dimension_5_part_2 ), 255) AS after_value
			,'Submit to Billing Failed. AX fields are missing.  '  AS audit_reference, @user_code, 'BS SP', @submit_date
			FROM #BillingDetail bd
			 JOIN #accountnumber a on bd.AX_MainAccount = a.AX_MainAccount and bd.AX_Dimension_1 = a.AX_Dimension_1 and bd.AX_Dimension_2 = a.AX_Dimension_2
			   AND bd.AX_Dimension_3 = a.AX_Dimension_3 and  bd.AX_Dimension_4 = a.AX_Dimension_4
			   AND bd.AX_Dimension_6 = a.AX_Dimension_6 and  bd.AX_Dimension_5_Part_1 = a.AX_Dimension_5_Part_1 and bd.AX_Dimension_5_Part_2 = a.AX_Dimension_5_Part_2
			WHERE 1=1
			AND bd.trans_source = 'O'
			AND UPPER (a.status ) <> 'VALID' 
			--AND ( dbo.fnValidateFinancialDimension (bd.AX_MainAccount,bd.AX_Dimension_1,bd.AX_Dimension_2,bd.AX_Dimension_3,bd.AX_Dimension_4,bd.AX_Dimension_6,
			--						  bd.AX_Dimension_5_part_1,bd.AX_Dimension_5_part_2 ) ) <> 'Valid'
				
			SELECT @invalid_ax_count =  @@ROWCOUNT, @error_value = @@ERROR  
		END 
	   ELSE
	     BEGIN
	     	INSERT INTO  OrderAudit (order_id, line_id, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
			SELECT DISTINCT bd.receipt_id, bd.line_id, NULL, '', '', bd.billing_type AS before_value, 
			bd.AX_MainAccount + '-' + bd.AX_Dimension_1 + '-' + bd.AX_Dimension_2 + '-' + bd.AX_Dimension_3 + '-' + bd.AX_Dimension_4 + '-' + ISNULL(bd.AX_Dimension_6, '') + '-' + ISNULL(bd.AX_Dimension_5_part_1, '') + CASE WHEN ISNULL(bd.AX_Dimension_5_part_2, '') <> '' THEN '.' + bd.AX_Dimension_5_part_2 ELSE '' END   AS after_value
			,'Submit to Billing Failed. AX fields are missing.  '  AS audit_reference, @user_code, 'BS SP', @submit_date
			FROM #BillingDetail bd
			WHERE 1=1
			AND bd.trans_source = 'O'   
		END
	 END	   
	  IF @error_value <> 0
	    BEGIN		
			-- Set message for RAISEERROR and go to the end
			SET @error_msg = 'Error inserting record into Audit tables for invalid/missing AX account(s).'
			GOTO END_OF_PROC
		END 
  END 
 --END
 IF @debug = 1 PRINT 'Receipt @invalid_ax_count = ' + CONVERT(varchar(4), @invalid_ax_count)
 -- END of Receipt AX - 07/21/2016

-- MPM - 8/4/2021 - DevOps 19760 - Product.gl_account_code is no longer used 
--SELECT @invalid_gl_count = @invalid_gl_count + COUNT(*) FROM #BillingDetail WHERE (gl_account_code LIKE '%X%' OR gl_account_code LIKE '%Z%')
-- IF JDE flags are off no need to stop Billing submit
IF @sync_invoice_jde = 1 
BEGIN
	SELECT @invalid_gl_count = @invalid_gl_count + COUNT(*) FROM #BillingDetail WHERE (JDE_BU LIKE '%X%' OR JDE_BU LIKE '%Z%')
	SELECT @invalid_gl_count = @invalid_gl_count + COUNT(*) FROM #BillingDetail WHERE (JDE_object LIKE '%X%' OR JDE_object LIKE '%Z%')
	
	---------------------------------------------------------------------------------------------------------------------
	-- Store the list of GL accounts that are not set up in JDE, so that we can display an error message to the user.
	---------------------------------------------------------------------------------------------------------------------
	
	------------------------------------
	-- Retail Orders:
	------------------------------------	
	INSERT INTO OrderAudit (order_id, line_id, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
	SELECT DISTINCT bd.receipt_id, bd.line_id, NULL, '', '', bd.billing_type AS before_value, bd.JDE_BU + '-' + bd.JDE_object AS after_value, 'Submit to Billing Failed.  Invalid JDE GL Account' AS audit_reference, @user_code, 'BS SP', @submit_date
	FROM #BillingDetail bd
	WHERE 1=1
	AND bd.trans_source = 'O'
	AND 
		NOT 
		EXISTS (SELECT 1 FROM JDE.EQFinance.dbo.JDEGLAccountMaster_F0901
			WHERE (business_unit_GMMCU COLLATE SQL_Latin1_General_CP1_CI_AS) = RIGHT('            ' + bd.JDE_BU, 12)
			AND (object_account_GMOBJ COLLATE SQL_Latin1_General_CP1_CI_AS) = bd.JDE_object
			AND subsidiary_GMSUB = ''
			AND posting_edit_GMPEC IN (' ','M')
		)
	--ORDER BY bd.company_id, bd.profit_ctr_id, bd.receipt_id, b.workorder_resource_type, b.workorder_sequence_id, bd.billing_type, bd.JDE_BU, bd.JDE_object
	SELECT @invalid_gl_count = @invalid_gl_count + @@ROWCOUNT, @error_value = @@ERROR
	
	IF @error_value <> 0
	BEGIN		
		-- Set message for RAISEERROR and go to the end
		SET @error_msg = 'Error inserting record into OrderAudit for invalid/missing JDE GL account(s).'
		GOTO END_OF_PROC
	END
	
END
IF @debug = 1 PRINT '@invalid_gl_count = ' + CONVERT(varchar(4), @invalid_gl_count)


---------------------------------------------------------------------------------------------
-- Now take the billing table records just created in a variable and insert them into Billing
---------------------------------------------------------------------------------------------
BEGIN TRANSACTION SubmitToBilling

IF @order_count > 0 AND @invalid_gl_count = 0 AND @invalid_ax_count = 0
BEGIN	
	-- Insert records into the Billing table
	INSERT INTO Billing (
		company_id,
		profit_ctr_id, 
		trans_source, 
		receipt_id, 
		line_id, 
		price_id, 
		status_code, 
		billing_date, 
		customer_id, 
		waste_code, 
		bill_unit_code, 
		vehicle_code, 
		generator_id, 
		generator_name, 
		approval_code, 
		time_in, 
		time_out, 
		tender_type, 
		tender_comment, 
		quantity, 
		price, 
		add_charge_amt, 
		orig_extended_amt, 
		discount_percent, 
		-- JDB 4/22/13 gl_account_code, 
		-- JDB 4/22/13 gl_sr_account_code, 
		gl_account_type, 
		gl_sr_account_type, 
		sr_type_code, 
		sr_price, 
		waste_extended_amt, 
		sr_extended_amt, 
		total_extended_amt, 
		cash_received, 
		manifest, 
		shipper, 
		hauler, 
		source, 
		truck_code, 
		source_desc, 
		gross_weight, 
		tare_weight, 
		net_weight, 
		cell_location, 
		manual_weight_flag, 
		manual_price_flag, 
		price_level, 
		comment, 
		operator, 
		workorder_resource_item, 
		workorder_invoice_break_value, 
		workorder_resource_type, 
		workorder_sequence_id, 
		purchase_order, 
		release_code, 
		cust_serv_auth, 
		taxable_mat_flag, 
		license, 
		payment_code, 
		bank_app_code, 
		number_reprints, 
		void_status, 
		void_reason, 
		void_date, 
		void_operator, 
		date_added, 
		date_modified, 
		added_by,
		modified_by, 
		trans_type, 
		ref_line_id, 
		service_desc_1, 
		service_desc_2, 
		cost, 
		secondary_manifest, 
		insr_percent, 
		insr_extended_amt, 
		--gl_insr_account_code, 
		ensr_percent, 
		ensr_extended_amt, 
		--gl_ensr_account_code, 
		bundled_tran_bill_qty_flag, 
		bundled_tran_price, 
		bundled_tran_extended_amt, 
		-- JDB 4/22/13 bundled_tran_gl_account_code, 
		product_id,
		billing_project_id, 
		po_sequence_id, 
		invoice_preview_flag, 
		COD_sent_flag, 
		COR_sent_flag, 
		invoice_hold_flag,
		profile_id,
		reference_code,
		tsdf_approval_id,
		billing_link_id,
		hold_reason,
		hold_userid,
		hold_date,
		invoice_id,
		invoice_code,
		invoice_date,
		date_delivered,
		waste_code_uid,
		currency_code		
		)
	SELECT 
		company_id,
		profit_ctr_id, 
		trans_source, 
		receipt_id, 
		line_id, 
		price_id, 
		status_code, 
		billing_date, 
		customer_id, 
		waste_code, 
		bill_unit_code, 
		vehicle_code, 
		generator_id, 
		generator_name, 
		approval_code, 
		time_in, 
		time_out, 
		tender_type, 
		tender_comment, 
		quantity, 
		price, 
		add_charge_amt, 
		orig_extended_amt, 
		discount_percent, 
		-- JDB 4/22/13 gl_account_code, 
		-- JDB 4/22/13 gl_sr_account_code, 
		gl_account_type, 
		gl_sr_account_type, 
		sr_type_code, 
		sr_price, 
		waste_extended_amt, 
		sr_extended_amt, 
		total_extended_amt, 
		cash_received, 
		manifest, 
		shipper, 
		hauler, 
		source, 
		truck_code, 
		source_desc, 
		gross_weight, 
		tare_weight, 
		net_weight, 
		cell_location, 
		manual_weight_flag, 
		manual_price_flag, 
		price_level, 
		comment, 
		operator, 
		workorder_resource_item, 
		workorder_invoice_break_value, 
		workorder_resource_type, 
		workorder_sequence_id, 
		purchase_order, 
		release_code, 
		cust_serv_auth, 
		taxable_mat_flag, 
		license, 
		payment_code, 
		bank_app_code, 
		number_reprints, 
		void_status, 
		void_reason, 
		void_date, 
		void_operator, 
		date_added, 
		date_modified, 
		added_by,
		modified_by, 
		trans_type, 
		ref_line_id, 
		service_desc_1, 
		service_desc_2, 
		cost, 
		secondary_manifest, 
		insr_percent, 
		insr_extended_amt, 
		--gl_insr_account_code, 
		ensr_percent, 
		ensr_extended_amt, 
		--gl_ensr_account_code, 
		bundled_tran_bill_qty_flag, 
		bundled_tran_price, 
		bundled_tran_extended_amt, 
		-- JDB 4/22/13 bundled_tran_gl_account_code, 
		product_id,
		billing_project_id, 
		po_sequence_id, 
		invoice_preview_flag, 
		COD_sent_flag, 
		COR_sent_flag, 
		invoice_hold_flag,
		profile_id,
		reference_code,
		tsdf_approval_id,
		billing_link_id,
		hold_reason,
		hold_userid,
		hold_date,
		invoice_id,
		invoice_code,
		invoice_date,
		date_delivered,
		waste_code_uid,
		currency_code
	FROM #Billing
	SELECT @error_value = @@ERROR
	
	IF @error_value <> 0
	BEGIN		
		-- Set message for RAISEERROR and go to the end
		SET @error_msg = 'Error inserting record into Billing'
		GOTO END_OF_PROC
	END

	-----------------------------------------------------
	---- Retail
	----------------------------------------------------


	INSERT INTO BillingDetail (
		billing_uid,
		ref_billingdetail_uid,
		billingtype_uid,
		billing_type,
		company_id,
		profit_ctr_id,
		receipt_id,
		line_id,
		price_id,
		trans_source,
		trans_type,
		product_id,
		dist_company_id,
		dist_profit_ctr_id,
		sales_tax_id,
		applied_percent,
		extended_amt,
		gl_account_code,
		added_by,
		date_added,
		modified_by,
		date_modified,
		JDE_BU,
		JDE_object,
	    AX_MainAccount,
		AX_Dimension_1,
		AX_Dimension_2,
		AX_Dimension_3,
		AX_Dimension_4,
	    AX_Dimension_5_part_1,
		AX_Dimension_5_part_2,
		AX_Dimension_6,
		currency_code)
	SELECT 
		b.billing_uid,
		bd.ref_billingdetail_uid,
		bd.billingtype_uid,
		bd.billing_type,
		bd.company_id,
		bd.profit_ctr_id,
		bd.receipt_id,
		bd.line_id,
		bd.price_id,
		bd.trans_source,
		bd.trans_type,
		bd.product_id, 
		bd.dist_company_id,
		bd.dist_profit_ctr_id,
		bd.sales_tax_id,
		bd.applied_percent,
		bd.extended_amt,
		bd.gl_account_code,
		@user_code AS added_by,
		@submit_date AS date_added,
		@user_code AS modified_by,
		@submit_date AS date_modified,
		bd.JDE_BU,
		bd.JDE_object,
		bd.AX_MainAccount,
		bd.AX_Dimension_1,
		bd.AX_Dimension_2,
		bd.AX_Dimension_3,
		bd.AX_Dimension_4,
	    bd.AX_Dimension_5_part_1,
		bd.AX_Dimension_5_part_2,
		bd.AX_Dimension_6,
		bd.currency_code
	FROM #BillingDetail bd
	JOIN Billing b ON b.company_id = bd.company_id
		AND b.profit_ctr_id = bd.profit_ctr_id
		AND b.trans_source = bd.trans_source
		AND b.receipt_id = bd.receipt_id
		AND b.line_id = bd.line_id
		AND b.price_id = bd.price_id
	SELECT @error_value = @@ERROR
	
	IF @error_value <> 0
	BEGIN		
		-- Set message for RAISEERROR and go to the end
		SET @error_msg = 'Error inserting records into BillingDetail'
		GOTO END_OF_PROC
	END
	
	INSERT INTO BillingComment (
		company_id,
		profit_ctr_id,
		trans_source,
		receipt_id ,
		receipt_status,
		project_code,
		project_name,
		comment_1,		
		comment_2,
		comment_3,
		comment_4,	
		comment_5,
		added_by,
		date_added,
		modified_by,
		date_modified,
		service_date )
	SELECT * FROM #BillingComment
	SELECT @error_value = @@ERROR
			
	IF @error_value <> 0
	BEGIN		
		-- Set message for RAISEERROR and go to the end
		SET @error_msg = 'Error inserting records into BillingComment'
		GOTO END_OF_PROC
	END
END

-- Verify counts
SELECT @billing_count = COUNT(*) FROM Billing 
	WHERE 1=1
	AND receipt_id = @order_id
	AND trans_source = @trans_source
	AND date_added = @submit_date

IF @debug = 1 print '@order_count: ' + CONVERT(varchar(10), @order_count) + ' @billing_count: ' + CONVERT(varchar(10), @billing_count)

IF @order_count = @billing_count AND @order_count > 0
BEGIN
	IF @trans_source = 'O'  
	BEGIN
		-- Show retail order AS submitted
		UPDATE OrderHeader SET submitted_flag = 'T',
			date_submitted = @submit_date,
			submitted_by = @user_code,
			modified_by = @user_code,
			date_modified = @submit_date
		WHERE OrderHeader.order_id = @order_id
		SELECT @error_value = @@ERROR
		
		IF @error_value <> 0
		BEGIN		
			-- Set message for RAISEERROR and go to the end
			SET @error_msg = 'Error updating submitted_flag on OrderHeader'
			GOTO END_OF_PROC
		END

		-- Write an audit record
		INSERT OrderAudit(order_id, line_id, 
				table_name, column_name, before_value, after_value, audit_reference, 
				modified_by, modified_from, date_modified)
		VALUES (@order_id, 0,
				'OrderHeader', 'submitted_flag', 'F', 'T', 'Submitted to Billing',
				@user_code, 'SB', @submit_date)
		SELECT @error_value = @@ERROR
		
		IF @error_value <> 0
		BEGIN		
			-- Set message for RAISEERROR and go to the end
			SET @error_msg = 'Error inserting record into OrderAudit'
			GOTO END_OF_PROC
		END
	END
END

-----------------------------------------------------------------
-- Commit or Rollback here
-----------------------------------------------------------------
END_OF_PROC:

IF @error_value <> 0
BEGIN
	-- Rollback the transaction
	ROLLBACK TRANSACTION SubmitToBilling

	-- Raise an error and return
	RAISERROR (@error_msg, 16, 1)
END
ELSE
BEGIN
	COMMIT TRANSACTION SubmitToBilling
END

-- We still need to write the audit to indicate there were invalid JDE GL accounts, so do that now:
IF @sync_invoice_jde = 1 AND @invalid_gl_count > 0
BEGIN
	INSERT INTO OrderAudit (order_id, line_id, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
		SELECT DISTINCT bd.receipt_id, bd.line_id, NULL, '', '', bd.billing_type AS before_value, bd.JDE_BU + '-' + bd.JDE_object AS after_value, 'Submit to Billing Failed.  Invalid JDE GL Account' AS audit_reference, @user_code, 'BS SP', @submit_date
		FROM #BillingDetail bd
		WHERE 1=1
		AND bd.trans_source = 'O'
		AND 
			NOT 
			EXISTS (SELECT 1 FROM JDE.EQFinance.dbo.JDEGLAccountMaster_F0901
				WHERE (business_unit_GMMCU COLLATE SQL_Latin1_General_CP1_CI_AS) = RIGHT('            ' + bd.JDE_BU, 12)
				AND (object_account_GMOBJ COLLATE SQL_Latin1_General_CP1_CI_AS) = bd.JDE_object
				AND subsidiary_GMSUB = ''
				AND posting_edit_GMPEC IN (' ','M')
			)
END
IF @sync_invoice_ax = 1  AND @invalid_ax_count > 0
 BEGIN
    IF  @sync_ax_Service = 1 
      BEGIN 
       select distinct bd.AX_MainAccount,bd.AX_Dimension_1,bd.AX_Dimension_2,bd.AX_Dimension_3,bd.AX_Dimension_4,bd.AX_Dimension_6,
                      bd.AX_Dimension_5_part_1,bd.AX_Dimension_5_part_2, convert(varchar(max),null) as status
		into #accountnumber1
		FROM #BillingDetail bd
		WHERE 1=1
		AND bd.trans_source = 'O'
		
		update #accountnumber1
	    set status = dbo.fnValidateFinancialDimension (@ax_web_service,AX_MainAccount,AX_Dimension_1,AX_Dimension_2,AX_Dimension_3,AX_Dimension_4,AX_Dimension_6,
                           AX_Dimension_5_part_1,AX_Dimension_5_part_2 )
                           
       INSERT INTO  OrderAudit (order_id, line_id, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
		SELECT DISTINCT bd.receipt_id, bd.line_id, NULL, '', '', bd.billing_type AS before_value,
			bd.AX_MainAccount + '-' + bd.AX_Dimension_1 + '-' + bd.AX_Dimension_2 + '-' + bd.AX_Dimension_3 + '-' + bd.AX_Dimension_4 + '-' + ISNULL(bd.AX_Dimension_6, '') + '-' + ISNULL(bd.AX_Dimension_5_part_1, '') + CASE WHEN ISNULL(bd.AX_Dimension_5_part_2, '') <> '' THEN '.' + bd.AX_Dimension_5_part_2 ELSE '' END  + 
			LEFT ( dbo.fnValidateFinancialDimension(@ax_web_service,bd.AX_MainAccount, bd.AX_Dimension_1, bd.AX_Dimension_2, bd.AX_Dimension_3, bd.AX_Dimension_4, bd.AX_Dimension_6, bd.AX_Dimension_5_part_1, bd.AX_Dimension_5_part_2 ), 255)  AS after_value
			,'Submit to Billing Failed. AX fields are missing.  '  AS audit_reference,@user_code, 'BS SP', @submit_date
		FROM #BillingDetail bd
		 JOIN #accountnumber1 a on bd.AX_MainAccount = a.AX_MainAccount and bd.AX_Dimension_1 = a.AX_Dimension_1 and bd.AX_Dimension_2 = a.AX_Dimension_2
           AND bd.AX_Dimension_3 = a.AX_Dimension_3 and  bd.AX_Dimension_4 = a.AX_Dimension_4
		   AND bd.AX_Dimension_6 = a.AX_Dimension_6 and  bd.AX_Dimension_5_Part_1 = a.AX_Dimension_5_Part_1 and bd.AX_Dimension_5_Part_2 = a.AX_Dimension_5_Part_2
		WHERE 1=1
		AND bd.trans_source = 'O'
		 AND UPPER (a.status ) <> 'VALID'
	    --AND ( dbo.fnValidateFinancialDimension (bd.AX_MainAccount,bd.AX_Dimension_1,bd.AX_Dimension_2,bd.AX_Dimension_3,bd.AX_Dimension_4,bd.AX_Dimension_6,
		   --                       bd.AX_Dimension_5_part_1,bd.AX_Dimension_5_part_2 ) ) <> 'Valid'
	  END
	 ELSE
	  BEGIN
	   INSERT INTO  OrderAudit (order_id, line_id, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
		SELECT DISTINCT bd.receipt_id, bd.line_id, NULL, '', '', bd.billing_type AS before_value,
		bd.AX_MainAccount + '-' + bd.AX_Dimension_1 + '-' + bd.AX_Dimension_2 + '-' + bd.AX_Dimension_3 + '-' + bd.AX_Dimension_4 + '-' + ISNULL(bd.AX_Dimension_6, '') + '-' + ISNULL(bd.AX_Dimension_5_part_1, '') + CASE WHEN ISNULL(bd.AX_Dimension_5_part_2, '') <> '' THEN '.' + bd.AX_Dimension_5_part_2 ELSE '' END   AS after_value
		,'Submit to Billing Failed. AX fields are missing.  '  AS audit_reference,@user_code, 'BS SP', @submit_date
		FROM #BillingDetail bd
		WHERE 1=1
		AND bd.trans_source = 'O'
	 END
 END

RETURN ISNULL(@error_value, 0)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_submit_order] TO [EQAI]
    AS [dbo];

