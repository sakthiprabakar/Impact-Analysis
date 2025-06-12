

CREATE OR ALTER PROCEDURE [dbo].[sp_billing_submit_calc]
	@debug				int,
	@company_id			int,
	@profit_ctr_id		int,
	@trans_source		char(1),
	@receipt_id			int,
	@submit_date		datetime,
	@submit_status		char(1),
	@user_code			varchar(20),
	@sales_tax_id_list	varchar(8000),
	@update_prod		char(1)	= 'F'	-- 'T'rue = update real tables.  'F' = no real table updates, just faux submitting.
AS
/***************************************************************************************
Submit receipt and Work Orders to the Billing table

Filename:		L:\Apps\SQL-Deploy\Prod\NTSQL1\PLT_AI\Procedures\sp_billing_submit_calc.sql
Loads to:		Plt_AI
PB Object(s):	w_popup_billing_submit
				w_receipt
				w_workorder

02/28/2007 SCC	Created
03/08/2007 SCC	Submit Billing Comments, too
05/20/2007 SCC	Allow the submit status to be set by user.
11/14/2007 JDB	Modified to use the left 60 characters of manifest_comment because the
		data was being truncated when inserting into Billing.
11/26/2007 WAC	Corrected BillingComment table update which did not have a where clause when
		the user was resubmitting a work order that had been previously invoiced and
		unsubmitted (invoice_id IS NOT NULL) to allow for user corrections.  The absence
		of the where clause caused the update to set ALL BillingComment records
		with the comments of the resbumitted workorder.  Oops
12/11/2007 WAC	Modified workorder non-fixed price select to ignore workorderdetail equipment, 
		labor and supply records that are part of a group.  In addition the price that
		is inserted into the billing table will now be zero when the extended_price is 
		0.  This fixes the issue with invoice printing that likes to extend qty x price
		to print and sum an extended amount.  This of course will mess up totaling if we
		don't zero the price to make the invoice print compute a 0 extended amount.
01/18/2008 WAC	Two new fields were added to the Receipt and WorkOrderHeader tables - 
		date_submitted and submitted by.  When this SP updates the submitted_flag
		these fields will be updated at the same time.
02/14/08 WAC	Receipts and workorders that have a billing_link_id = 0 are no longer inserted into the 
		Billing table with a status_code = 'H'.  This allows the billing department to select
		these linked billing records for validation without having to check the Hold checkbox as
		part of their selection criteria.  The validation process will still ensure that when the
		billing_link_id IS NOT NULL that the linked transaction has the appropriate status to be 
		invoiced.  However, when the billing_link is > 0 then the status_code will still be 
		set to "H"old because that indicates that this is a real billing link that could be 
		linking multiple transactions together, not a transaction link which would be linking
		a particular workorder or Receipt.
07/17/2008 JDB	Removed source fields from Billing table
09/09/2008 JDB	Added new Energy Surcharge fields to Billing table
05/27/2009 KAM  Updated the Receipt Audit for 3 separate rows (Flag, By whom and date)
04/20/2010 KAM  updated to join on company for use in plt_ai
06/29/2010 JDB  Removed unnecessary join between WorkOrderHeader and ProfitCenter
07/22/2010 KAM  Updated to allow for multiple billing units on a workorder
10/12/2010 JDB	Added code to populate new BillingDetail table
				For work orders, we can now get different GL accounts for each resource class,
					with the default GL account being the work order type
				For Receipts, we have new bundled transactions (to possibly multiple facilities)
12/14/2010 RWB	Integrated ProfileQuoteDetailSplitGroup table into computation of bundled charges
12/15/2010 JDB	Added code to bypass submitting optional charges that are not applied.
12/23/2010 RWB	Converted processing loop to a cursor
03/01/2011 JDB	Fixed typo in the WHERE clause of the State-Perp charges that was causing
				the State-Haz amount to be inserted twice into BillingDetail, and the 
				State-Perp amount not to be inserted at all.
03/03/2011 JDB	Added bill_rate > 0 to the WHERE clause for work order lines.
07/11/2011 SK	Changed above where clause to bill rate >= 0 to include No charge disposal lines w print on invoice
08/22/2011 SK	Fixed the issue with N/C lines being invoiced when price > 0
08/31/2011 JDB	Modified to calculate the Insurance Surcharge, Energy Surcharge and Sales Tax amounts when submitting,
				instead of waiting until the preview invoice is created.
10/28/2011 JDB	Modified to create BillingDetail records for Disposal, Product and Wash even if the waste_extended_amt = 0.
11/02/2011 JDB	Modified to exclude adding the CT sales tax on transactions before 7/1/2011.
11/03/2011 JDB	Removed the check in the WorkOrder section about the work order not existing in Billing already for 
				line_id = 1 and price_id = 1.
11/11/2011 JDB Added price_id as a parameter into fn_ensr_amt_receipt_line and fn_insr_amt_receipt_line
				because receipt lines that were split into two prices were not getting calculated properly.
01/11/2012 JDB	Added logic so that billing records with GL accounts with "X" in them would fail to work.
				(This is for end-of-year 2011 work orders that should not be submitted until 2012 after the
				GL standardization project is ready.)
01/11/2012 RWB	Added logic to calculate GL Accounts using the new 2012 standardized lists.  Work Orders now
				use the natural portion from the resource type (work order tab), and the department from the work order type.
01/16/2012 JDB	Fixed up one part for sales tax - it was not including the department from the waste it went with.  It was
				still just retrieving the whole GL account from the product.
01/24/2012 JDB	Modified to calculate the Receipt's GL account, rather than get what's already in the Receipt table.
				This SP will now update the Receipt's GL account before populating the Billing and BillingDetail tables.
				For inbound disposal/wash records, use the treatment's GL account.
				For product records (inbound or outbound), use the product's GL account.
				For LMIN records (inbound), use the GL account that goes with the disposal line the LMIN refers to.
01/24/2012 JDB	Modified to use the first transporter from the ReceiptTransporter table instead of the Billing.hauler
				field to calculate the Bundled charges.
02/02/2012 JDB	Fixed typo in join in the Bundled section that was using profile_id twice instead of using profit_ctr_id.
02/03/2012 JDB	Added DISTINCT to the c_billing cursor in the Bundled section so that receipts using the same profile
				on multiple lines would not get the bundled pricing applied multiple times.
02/03/2012 JPB  Broke out receipt charges into separate SP so they can be called from other routines.
03/06/2012 JDB	Added new function fn_get_workorder_glaccount to get the GL account for a work order.
				Modified the way that the receipt and work order calculate their GL accounts so that exceptions can be
				taken into account, using either the TreatmentDetail table (accessible through the Treatment view) or
				the WorkOrderTypeDetail table (new gl_seg_4 column added).
03/16/2012 JDB	Modified to stop populating the INSR and ENSR fields on the Billing table for receipts.
				Changed the calculation for sales tax to apply to the BillingDetail lines directly, rather than Billing.
				Added support for new identity columns on Billing and BillingDetail tables.
				Removed Billing.gl_insr_account_code and Billing.gl_ensr_account_code fields.
04/01/2012 JDB	Added a SQL transaction to the procedure so that records aren't added to Billing but not BillingDetail.
04/26/2012 JDB	Added logic so that billing records with GL accounts with "Z" in them would fail to work.
11/07/2012 JDB	Fixed bug in the update of BillingDetail.ref_billingdetail_uid field.
12/27/2012 JDB	Modified to use the updated fn_get_receipt_glaccount properly.
02/20/2013 SK	Modified to populate new JDE GL fields and replaced the use of Billing GL fields with those of BillingDetail.
02/28/2013 JDB	Added the population of the new billingtype_uid field in BillingDetail.
04/22/2013 JDB	Changed to use new functions fn_get_workorder_JDE_glaccount_business_unit and
				fn_get_workorder_JDE_glaccount_object to get the JDE GL account information.
06/03/2013 JDB	Modified to populate ReceiptAudit, WorkOrderAudit tables with invalid JDE GL Accounts.
06/19/2013 SK	Changed for the population of service_date in BillingComment
07/02/2013 SK	Changed the join on receiptcomment to Left Outer Join, so that a Billing Comment record is always created for
				a Billing record per receipt
08/23/2013 SK	Added insert to Billing.waste_code_uid
09/10/2013 JDB	Modified so that it doesn't populate the Billing.waste_code field with dummy values like 'EQWO'.
03/07/2014 JDB	Commented out a line that was checking for invalid Epicor GL accounts.  We don't need this any longer.
03/28/2014 AM   Modified code to call fn_get_service_date_no_time to get service_date.
11/20/2014 JDB	For work orders, modified to retrieve the reference_code field from WorkOrderHeader (new field) instead of from CustomerBilling.
03/16/2015 JPB	Copy of sp_billing_submit made to take a flag that indicates whether live tables should be updated.
				Also assumes an input #Billing & #BillingDetail etc exist, and returns those tables with populated data.
05/25/2017 MPM	Replaced the COMPUTE clause with SQL Server 2014-compatible code.
07/14/2017 JPB	Added explicit #BillingDetail column lists for inserts
02/15/2018 MPM	Added currency_code column to #Billing and #BillingDetail.
07/04/2024 KS	Rally116983 - Modified service_desc_1 and service_desc_2 values to be upto 100 chars.
10/24/2024 Prakash Rally US126675 - Commented out the code refrencing ResourceClassGLAccount Table.


sp_billing_submit_calc 1, 21, 0, 'R', 773356, '10-28-2010 16:02', NULL, 'JASON_B', ''
sp_billing_submit_calc 1, 14, 0, 'W', 11180200, '2/15/11 15:43', NULL, 'JASON_B', ''
sp_billing_submit_calc 1, 27, 0, 'W', 83700, '10-15-10 14:25', NULL, 'JASON_B', '1'
sp_billing_submit_calc 1, 14, 6, 'W', 4912700, '6/24/13 14:02', NULL, 'SMITA_K', ''

SELECT $IDENTITY, * FROM Billing
SELECT $IDENTITY, * FROM BillingDetail
SELECT IDENT_CURRENT ('Billing')
SELECT IDENT_CURRENT ('BillingDetail')

EXEC sp_billing_unsubmit 1, 3, 0, 1213591, 'R', 'JASON_B'
--EXEC sp_billing_submit_calc 1, 3, 0, 'R', 1213591, '02-17-12 14:45', NULL, 'JASON_B', ''
EXEC sp_billing_submit_calc 1, 3, 0, 'R', 1213591, '02-17-12 14:45', NULL, 'JASON_B', '63'

EXEC sp_billing_unsubmit 1, 3, 0, 1213616, 'R', 'JASON_B'
--EXEC sp_billing_submit_calc 1, 3, 0, 'R', 1213616, '02-17-12 16:50', NULL, 'JASON_B', ''
EXEC sp_billing_submit_calc 1, 3, 0, 'R', 1213616, '02-17-12 16:50', NULL, 'JASON_B', '63'

EXEC sp_billing_unsubmit 1, 21, 0, 1164500, 'W', 'JASON_B'
EXEC sp_billing_submit_calc 1, 21, 0, 'W', 1164500, '02-20-12 16:00', NULL, 'JASON_B', ''

EXEC sp_billing_unsubmit 1, 25, 0, 50151, 'R', 'JASON_B'
EXEC sp_billing_submit_calc 1, 25, 0, 'R', 50151, '02-22-12 11:00', NULL, 'JASON_B', ''

EXEC sp_billing_unsubmit 1, 21, 0, 919114, 'R', 'JASON_B'
EXEC sp_billing_submit_calc 1, 21, 0, 'R', 919114, '05-31-13 8:33', NULL, 'JASON_B', ''

EXEC sp_billing_submit_calc 1, 14, 9, 'W', 3439900, '04-4-14 8:39', NULL, 'JASON_B', ''

EXEC sp_billing_unsubmit 1, 27, 0, 123108, 'R', 'MARTHA_M'
EXEC sp_billing_submit_calc_mpm 1, 27, 0, 'R', 123108, '5/25/2017', NULL, 'MARTHA_M', '', 'T'

****************************************************************************************/
SET NOCOUNT ON

DECLARE	@discount_flag	char(1),
	@fixed_price_flag	char(1),
	@receipt_count		int,
	@billing_count		int,
	@incr_line_id		int,
	@invoice_id			int,
	@invoice_code		varchar(16),
	@invoice_date		datetime,
	@billing_status		char(1),
	@rowcount_bundled	int,
	@bund_company_id	int,
	@bund_profit_ctr_id	int,
	@bund_receipt_id	int,
	@bund_line_id		int,
	@bund_price_id		int,
	@bund_trans_source	char(1),
	@bund_product_id	int,
	@bund_dist_company_id	int,
	@bund_dist_profit_ctr_id	int,
	@bund_gl_account_code	varchar(32),
	@bund_sequence_id	int,
	@bund_quote_sequence_id	int,
	@extended_amt		float,
	@ref_extended_amt	float,
	-- rb for bundled cursors
	@b_profile_id int,
	@b_company_id smallint,
	@b_profit_ctr_id smallint,
	@b_sequence_id int,
	@b_hauler varchar(15),
	@b_gen_site_type_id int,
	@pqdsg_price_group_id int,
	@pqdsg_transporter_code varchar(15),
	@pqdsg_gen_site_type_id int,
	
	@invalid_gl_count	int,
	@max_billing_uid	int,
	@max_billingdetail_uid	int,
	@bd_identity		int,
	@bd_rowcount		int,
	@sync_invoice_jde	tinyint,
	@error_msg			varchar(8000),
	@error_value		int


IF @update_prod = 'T'
	BEGIN TRANSACTION SubmitToBilling

SELECT @discount_flag = ISNULL(discount_flag,'F') FROM profitcenter 
	WHERE company_id = @company_id AND profit_ctr_id = @profit_ctr_id

SET @invoice_id	= NULL
SET @invoice_code = NULL
SET @invoice_date = NULL
SET @billing_status = @submit_status
IF @sales_tax_id_list = 'Exempt' SET @sales_tax_id_list = ''

/*

-- Prepare Billing records
CREATE TABLE #Billing  (
	billing_uid				int NOT NULL IDENTITY (1,1),
	company_id				smallint NOT NULL,
	profit_ctr_id			smallint NOT NULL,
	trans_source			char (1) NULL,
	receipt_id				int NULL,
	line_id					int NULL,
	price_id				int NULL,
	status_code				char (1) NULL,
	billing_date			datetime NULL,
	customer_id				int NULL,
	waste_code				varchar (4) NULL,
	bill_unit_code			varchar (4) NULL,
	vehicle_code			varchar (10) NULL,
	generator_id			int NULL,
	generator_name			varchar (40) NULL,
	approval_code			varchar (15) NULL,
	time_in					datetime NULL,
	time_out				datetime NULL,
	tender_type 			char (1) NULL,
	tender_comment			varchar (60) NULL,
	quantity				float NULL,
	price					money NULL,
	add_charge_amt			money NULL,
	orig_extended_amt		money NULL,
	discount_percent		float NULL,
	--gl_account_code			varchar (32) NULL,
	--gl_sr_account_code		varchar (32) NULL,
	gl_account_type			char (1) NULL,
	gl_sr_account_type		char (1) NULL,
	sr_type_code			char (1) NULL,
	sr_price				money NULL,
	waste_extended_amt		money NULL,
	sr_extended_amt			money NULL,
	total_extended_amt		money NULL,
	cash_received			money NULL,
	manifest				varchar (15) NULL,
	shipper					varchar (15) NULL,
	hauler					varchar (20) NULL,
	source					varchar (15) NULL,
	truck_code				varchar (10) NULL,
	source_desc				varchar (25) NULL,
	gross_weight			int NULL,
	tare_weight				int NULL,
	net_weight				int NULL,
	cell_location			varchar (15) NULL,
	manual_weight_flag		char (1) NULL,
	manual_price_flag		char (1) NULL,
	price_level				char (1) NULL,
	comment					varchar (60) NULL,
	operator				varchar (10) NULL,
	workorder_resource_item	varchar (15) NULL,
	workorder_invoice_break_value	varchar (15) NULL,
	workorder_resource_type	varchar (15) NULL,
	workorder_sequence_id	varchar (15) NULL,
	purchase_order			varchar (20) NULL,
	release_code			varchar (20) NULL,
	cust_serv_auth			varchar (15) NULL,
	taxable_mat_flag		char (1) NULL,
	license					varchar (10) NULL,
	payment_code			varchar (13) NULL,
	bank_app_code			varchar (13) NULL,
	number_reprints			smallint NULL,
	void_status				char (1) NULL,
	void_reason				varchar (60) NULL,
	void_date				datetime NULL,
	void_operator			varchar (8) NULL,
	date_added				datetime NULL,
	date_modified			datetime NULL,
	added_by				varchar (10) NULL,
	modified_by				varchar (10) NULL,
	trans_type				char (1) NULL,
	ref_line_id				int NULL,
	service_desc_1			varchar (100) NULL,
	service_desc_2			varchar (100) NULL,
	cost					money NULL,
	secondary_manifest		varchar (15) NULL,
	insr_percent			money NULL,
	insr_extended_amt		money NULL,
	--gl_insr_account_code	varchar(32),
	ensr_percent			money NULL,
	ensr_extended_amt		money NULL,
	--gl_ensr_account_code	varchar(32),
	bundled_tran_bill_qty_flag	varchar (4) NULL,
	bundled_tran_price		money NULL,
	bundled_tran_extended_amt	money NULL,
	--bundled_tran_gl_account_code	varchar (32) NULL,
	product_id				int NULL,
	billing_project_id		int NULL,
	po_sequence_id			int NULL,
	invoice_preview_flag	char (1) NULL,
	COD_sent_flag			char (1) NULL,
	COR_sent_flag			char (1) NULL,
	invoice_hold_flag		char (1) NULL,
	profile_id				int NULL,
	reference_code			varchar(32) NULL,
	tsdf_approval_id		int NULL,
	billing_link_id			int NULL,
	hold_reason				varchar(255) NULL,
	hold_userid				varchar(10) NULL,
	hold_date				datetime NULL,
	invoice_id				int NULL,
	invoice_code			varchar(16) NULL,
	invoice_date			datetime NULL,
	date_delivered			datetime NULL,
	resource_sort			int	NULL,
	bill_sequence			int	NULL,
	quote_sequence_id		int	NULL,
	count_bundled			int	NULL,
	waste_code_uid			int	NULL,
	currency_code			char(3)	NULL
)

--rb 04/10/2015 Helps when updating very large result sets
create index #idx_Billing on #Billing (trans_source, company_id, profit_ctr_id, receipt_id)

if object_id('tempdb..#BillingComment') is not null drop table #BillingComment

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

if object_id('tempdb..#BillingDetail') is not null drop table #BillingDetail

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
	AX_MainAccount		varchar(20)		NULL,
	AX_Dimension_1		varchar(20)		NULL,
	AX_Dimension_2		varchar(20)		NULL,
	AX_Dimension_3		varchar(20)		NULL,
	AX_Dimension_4		varchar(20)		NULL,
	AX_Dimension_5_Part_1		varchar(20)		NULL,
	AX_Dimension_5_Part_2		varchar(9)		NULL,
	AX_Dimension_6		varchar(20)		NULL,
	AX_Project_Required_Flag varchar(20) NULL,
	disc_amount			decimal(18,6)	NULL,
	currency_code			char(3)	NULL
)

--rb 04/10/2015 Helps when updating very large result sets
create index #idx_BillingDetail on #BillingDetail (billing_uid)

if object_id('tempdb..#SalesTax') is not null drop table #SalesTax

-- Prepare SalesTax records
CREATE TABLE #SalesTax  (
	sales_tax_id		int				NULL
)


*/

TRUNCATE TABLE #Billing
TRUNCATE TABLE #BillingDetail
TRUNCATE TABLE #BillingComment



-- Prepare SalesTax records
CREATE TABLE #SalesTax  (
	sales_tax_id		int				NULL
)

-- Populate sales tax table
IF @sales_tax_id_list <> ''
BEGIN
	INSERT #SalesTax (sales_tax_id)
	SELECT DISTINCT CONVERT(int, row) AS sales_tax_id
	FROM dbo.fn_SplitXsvText(',', 1, @sales_tax_id_list) 
	WHERE ISNULL(row, '') <> ''
	
	IF @debug = 1 SELECT * FROM #SalesTax
END

---------------------------------------------------------------
-- Do we export invoices/adjustments to JDE?
---------------------------------------------------------------
IF @update_prod = 'T'
	SELECT @sync_invoice_jde = sync
	FROM FinanceSyncControl
	WHERE module = 'Invoice'
	AND financial_system = 'JDE'

-- Retrieve the receipt to be submitted
IF @trans_source = 'R' 
BEGIN
	----------------------------------------------------------------------------------------------------
	-- 1/24/12 JDB
	-- First we need to calculate the gl_account_code for the receipt lines.
	-- We used to store/use the GL account from the Receipt table, but now we want to calculate
	-- it here, and back-populate the Receipt with these values.  Then the procedure can
	-- finish by using what's in Receipt.
	-- Eventually we won't have the Receipt.gl_account_code field, and can just calculate
	-- the GL account right here for the Billing table (similar to the work order logic below).
	----------------------------------------------------------------------------------------------------

	if @update_prod = 'T' BEGIN
		------------------------------------------------------
		-- Update Inbound Disposal/Wash records first
		------------------------------------------------------
		INSERT INTO ReceiptAudit
		SELECT r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, 0, 'Receipt', 'gl_account_code', r.gl_account_code, dbo.fn_get_receipt_glaccount(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 'Updated from sp_billing_submit_calc (from Treatment)', @user_code, 'BS', @submit_date
		FROM Receipt r
		JOIN Treatment t ON t.company_ID = r.company_id
			AND t.profit_ctr_ID = r.profit_ctr_id
			AND t.treatment_id = r.treatment_id
		WHERE r.company_id = @company_id
		AND r.profit_ctr_id = @profit_ctr_id
		AND r.receipt_id = @receipt_id
		AND r.trans_mode = 'I'
		AND r.trans_type IN ('D', 'W')
		AND r.gl_account_code <> t.gl_account_code
		SELECT @error_value = @@ERROR
		
		IF @error_value <> 0
		BEGIN		
			-- Set message for RAISEERROR and go to the end
			SET @error_msg = 'Error inserting ReceiptAudit record for GL Account update (Disposal).'
			GOTO END_OF_PROC
		END
		
		UPDATE Receipt SET gl_account_code = dbo.fn_get_receipt_glaccount(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id)
		FROM Receipt r
		JOIN Treatment t ON t.company_ID = r.company_id
			AND t.profit_ctr_ID = r.profit_ctr_id
			AND t.treatment_id = r.treatment_id
		WHERE r.company_id = @company_id
		AND r.profit_ctr_id = @profit_ctr_id
		AND r.receipt_id = @receipt_id
		AND r.trans_mode = 'I'						-- Only Inbound receipts use treatments
		AND r.trans_type IN ('D', 'W')				-- Get GL account from treatment for Disposal and Wash lines
		AND r.gl_account_code <> t.gl_account_code	-- SK 02/20 this was missing before, 'where' clause should be exactly same as one for receiptaudit above
		SELECT @error_value = @@ERROR
		
		IF @error_value <> 0
		BEGIN		
			-- Set message for RAISEERROR and go to the end
			SET @error_msg = 'Error updating Receipt record for GL Account update (Disposal).'
			GOTO END_OF_PROC
		END

		------------------------------------------------------
		-- Update Product records
		------------------------------------------------------
		INSERT INTO ReceiptAudit
		SELECT r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, 0, 'Receipt', 'gl_account_code', r.gl_account_code, dbo.fn_get_receipt_glaccount(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id), 'Updated from sp_billing_submit_calc (from Product)', @user_code, 'BS', @submit_date
		FROM Receipt r
		WHERE r.company_id = @company_id
		AND r.profit_ctr_id = @profit_ctr_id
		AND r.receipt_id = @receipt_id
		AND r.trans_mode = 'I'
		AND r.trans_type IN ('S')
		AND r.gl_account_code <> dbo.fn_get_receipt_glaccount(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id)
		SELECT @error_value = @@ERROR
		
		IF @error_value <> 0
		BEGIN		
			-- Set message for RAISEERROR and go to the end
			SET @error_msg = 'Error inserting ReceiptAudit record for GL Account update (Service).'
			GOTO END_OF_PROC
		END
		
		UPDATE Receipt SET gl_account_code = dbo.fn_get_receipt_glaccount(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id)
		FROM Receipt r
		WHERE r.company_id = @company_id
		AND r.profit_ctr_id = @profit_ctr_id
		AND r.receipt_id = @receipt_id
		AND r.trans_mode = 'I'	
		AND r.trans_type IN ('S')					-- Only get GL account from products for Service lines
		AND r.gl_account_code <> dbo.fn_get_receipt_glaccount(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id)
		SELECT @error_value = @@ERROR
		
		IF @error_value <> 0
		BEGIN		
			-- Set message for RAISEERROR and go to the end
			SET @error_msg = 'Error updating Receipt record for GL Account update (Service).'
			GOTO END_OF_PROC
		END

	END -- if @update_prod = 'T'
	

	------------------------------------------------------
	-- Insert into #Billing table
	------------------------------------------------------
	INSERT #Billing 
  (
	-- billing_uid				
	company_id				,
	profit_ctr_id			,
	trans_source			,
	receipt_id				,
	line_id					,
	price_id				,
	status_code				,
	billing_date			,
	customer_id				,
	waste_code				,
	bill_unit_code			,
	vehicle_code			,
	generator_id			,
	generator_name			,
	approval_code			,
	time_in					,
	time_out				,
	tender_type 			,
	tender_comment			,
	quantity				,
	price					,
	add_charge_amt			,
	orig_extended_amt		,
	discount_percent		,
	--gl_account_code		,
	--gl_sr_account_code	,
	gl_account_type			,
	gl_sr_account_type		,
	sr_type_code			,
	sr_price				,
	waste_extended_amt		,
	sr_extended_amt			,
	total_extended_amt		,
	cash_received			,
	manifest				,
	shipper					,
	hauler					,
	source					,
	truck_code				,
	source_desc				,
	gross_weight			,
	tare_weight				,
	net_weight				,
	cell_location			,
	manual_weight_flag		,
	manual_price_flag		,
	price_level				,
	comment					,
	operator				,
	workorder_resource_item	,
	workorder_invoice_break_value	,
	workorder_resource_type	,
	workorder_sequence_id	,
	purchase_order			,
	release_code			,
	cust_serv_auth			,
	taxable_mat_flag		,
	license					,
	payment_code			,
	bank_app_code			,
	number_reprints			,
	void_status				,
	void_reason				,
	void_date				,
	void_operator			,
	date_added				,
	date_modified			,
	added_by				,
	modified_by				,
	trans_type				,
	ref_line_id				,
	service_desc_1			,
	service_desc_2			,
	cost					,
	secondary_manifest		,
	insr_percent			,
	insr_extended_amt		,
	--gl_insr_account_code	,
	ensr_percent			,
	ensr_extended_amt		,
	--gl_ensr_account_code	,
	bundled_tran_bill_qty_flag,	
	bundled_tran_price		,	
	bundled_tran_extended_amt,	
	--bundled_tran_gl_account_code	varchar (32) NULL,
	product_id				,
	billing_project_id		,
	po_sequence_id			,
	invoice_preview_flag	,
	COD_sent_flag			,
	COR_sent_flag			,
	invoice_hold_flag		,
	profile_id				,
	reference_code			,
	tsdf_approval_id		,
	billing_link_id			,
	hold_reason				,
	hold_userid				,
	hold_date				,
	invoice_id				,
	invoice_code			,
	invoice_date			,
	date_delivered			,
	resource_sort			,
	bill_sequence			,
	quote_sequence_id		,
	count_bundled			,
	waste_code_uid			,
	currency_code		
)	
	SELECT	
		receipt.company_id,
		receipt.profit_ctr_id,
		'R' AS trans_source,
		receipt.receipt_id,
		receipt.line_id,
		receiptPrice.price_id AS price_id,
		CASE WHEN receipt.billing_link_id > 0
		  THEN 'H'
		  ELSE CASE WHEN @billing_status IS NOT NULL THEN @billing_status 
			ELSE CASE WHEN ISNULL(receipt.submit_on_hold_flag,'F') = 'T' THEN 'H' ELSE 'S' END 
			END   
		END AS status_code,
		receipt.receipt_date AS billing_date,
		ISNULL(receipt.customer_id, 0) AS customer_id,
		ISNULL(REPLACE(Receipt.waste_code,'''', ''), '') AS waste_code,
		ISNULL(receiptPrice.bill_unit_code,'') AS bill_unit_code,
		NULL AS vehicle_code,
		receipt.generator_id,
		ISNULL(REPLACE(Generator.generator_name,'''', ''),'') AS generator_name,
		ISNULL(REPLACE(receipt.approval_code,'''', ''),'') AS approval_code,
		ISNULL(receipt.time_in, receipt.receipt_date) AS time_in,
		ISNULL(receipt.time_out, receipt.receipt_date) AS time_out,
		ISNULL(receipt.tender_type,'') AS tender_type,
		'' AS tender_comment,
		ISNULL(receiptPrice.bill_quantity,0) AS quantity,
		ISNULL(receiptPrice.price,0) AS price,
		0 AS add_charge_amt,
		ISNULL(receiptPrice.total_extended_amt,0) AS orig_extended_amt,
		CASE WHEN @discount_flag = 'T' THEN ISNULL(CustomerBilling.cust_discount,0) ELSE 0 END AS discount_percent,
		-- SK 02/20 dbo.fn_get_receipt_glaccount(Receipt.company_id, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id) AS gl_account_code,
--rb	CASE WHEN receiptPrice.sr_type = 'E' THEN '' ELSE ISNULL((SELECT gl.account_code FROM glaccount gl WHERE gl.account_type = receiptPrice.sr_type AND gl.account_class = 'S' AND gl.profit_ctr_id = @profit_ctr_id),'') END AS gl_sr_account_code,
-- SK 02/20		--CASE WHEN receiptPrice.sr_type = 'E' THEN ''
		--	ELSE ISNULL((SELECT REPLACE(gl_account_code,'XXX',RIGHT(dbo.fn_get_receipt_glaccount(Receipt.company_id, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id), 3))
		--				FROM Product
		--				WHERE product_code = (CASE receiptPrice.sr_type WHEN 'H' THEN 'MITAXHAZ' WHEN 'P' THEN 'MITAXPERP' END)
		--				AND product_type = 'X' 
		--				AND status = 'A' 
		--				AND company_id = receipt.company_id 
		--				AND profit_ctr_id = receipt.profit_ctr_id),'') 
		--	END AS gl_sr_account_code,
		gl_account_type = ISNULL((SELECT waste_type_code FROM WasteCode wc WHERE wc.waste_code_uid = Receipt.waste_code_uid),''),
		ISNULL(receiptPrice.sr_type,''),
		ISNULL(receiptPrice.sr_type,'') AS sr_type_code,
		ISNULL(receiptPrice.sr_price,0) AS sr_price,
		ISNULL(receiptPrice.waste_extended_amt,0) AS waste_extended_amt,
		ISNULL(receiptPrice.sr_extended_amt,0) AS sr_extended_amt,
		ISNULL(receiptPrice.total_extended_amt,0) AS total_extended_amt,
		ISNULL(receipt.cash_received,0) AS cash_received,
		ISNULL(REPLACE(receipt.manifest,'''', ''),''),
		CASE WHEN receipt.manifest_flag = 'M' THEN  NULL ELSE ISNULL(REPLACE(receipt.manifest,'''', ''),'') END AS shipper,
		ISNULL(REPLACE(receipt.hauler,'''', ''),''),
		'' AS source,
		'' AS truck_code,
		'' AS source_desc,
		ISNULL(receipt.gross_weight,0),
		ISNULL(receipt.tare_weight,0),
		ISNULL(receipt.net_weight,0),
		ISNULL(REPLACE(receipt.location,'''', ''),'') AS cell_location,
		'' AS manual_weight_flag,
		'' AS manual_price_flag,
		'' AS price_level,
		LEFT(ISNULL(REPLACE(receipt.manifest_comment,'''', ''),''), 60) AS comment,
		'' AS operator,
		'' AS workorder_resource_item,
		'' AS workorder_invoice_break_value,
		'' AS workorder_resource_type,
		'' AS workorder_sequence_id,
		ISNULL(REPLACE(receipt.purchase_order,'''', ''),'') AS purchase_order,
		ISNULL(REPLACE(receipt.release,'''', ''),'') AS release_code,
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
		ISNULL(receipt.trans_type,''),
		ISNULL(receipt.ref_line_id,0),
		CASE WHEN receipt.trans_type = 'S' 
		     THEN ISNULL(REPLACE(receipt.service_desc,'''', ''),'') 
		     ELSE SUBSTRING(ISNULL(REPLACE(receipt.approval_code,'''', ''),'') + ' ' + ISNULL(REPLACE(Profile.approval_desc,'''', ''),''), 1, 100) 
		     END AS service_desc_1,
		'' AS service_desc_2,
		0 AS cost,
		'' AS secondary_manifest,
		
		0 AS insr_percent,
		0 AS insr_extended_amt,
		--NULL AS gl_insr_account_code,
		0 AS ensr_percent,
		0 AS ensr_extended_amt,
		--NULL AS gl_ensr_account_code,
		
		ISNULL(receiptPrice.bundled_tran_bill_qty_flag,0),
		ISNULL(receiptPrice.bundled_tran_price,0),
		ISNULL(receiptPrice.bundled_tran_extended_amt,0),
		-- SK 02/20 ISNULL(receiptPrice.bundled_tran_gl_account_code,''),
		ISNULL(receipt.product_id,0),
		ISNULL(receipt.billing_project_id,0),
		ISNULL(receipt.po_sequence_id,0),
		'F' AS invoice_preview_flag,
		'F' AS COD_sent_flag,
		'F' AS COR_sent_flag,
		'F' AS invoice_hold_flag,
		ISNULL(receipt.profile_id,0),
		ISNULL(CustomerBilling.reference_code,''),
		CONVERT(int, NULL) AS tsdf_approval_id,
		receipt.billing_link_id,
		CASE WHEN receipt.billing_link_id IS NOT NULL AND receipt.billing_link_id = 0 AND receipt.submit_on_hold_reason IS NULL
			THEN NULL
		     WHEN receipt.billing_link_id IS NOT NULL AND receipt.billing_link_id > 0 AND receipt.submit_on_hold_reason IS NULL
			THEN 'receipt is member of Billing Link ' + Convert(varchar(10), receipt.billing_link_id)
		     WHEN ISNULL(receipt.submit_on_hold_flag,'F') = 'T' AND receipt.submit_on_hold_reason IS NULL
			THEN 'Submitted on Hold with no supporting reason.'
		     WHEN ISNULL(receipt.submit_on_hold_flag,'F') = 'T' AND receipt.submit_on_hold_reason IS NOT NULL
			THEN receipt.submit_on_hold_reason
		     WHEN @submit_status IS NOT NULL
			THEN 'Submitted on Hold with no supporting reason.'
		END AS hold_reason,
		CASE WHEN receipt.billing_link_id > 0 OR @submit_status IS NOT NULL OR ISNULL(receipt.submit_on_hold_flag,'F') = 'T'
			THEN @user_code
			ELSE NULL
		END AS hold_userid,
		CASE WHEN receipt.billing_link_id > 0 OR @submit_status IS NOT NULL OR ISNULL(receipt.submit_on_hold_flag,'F') = 'T'
			THEN @submit_date
			ELSE NULL
		END AS hold_date,
		@invoice_id,
		@invoice_code,
		@invoice_date,
		receipt.receipt_date AS date_delivered,
		0,
		0,
		receiptPrice.quote_sequence_id,
		(SELECT COUNT(*) FROM ProfileQuoteDetail pqd 
			WHERE pqd.company_id = receipt.company_id 
			AND pqd.profit_ctr_id = receipt.profit_ctr_id
			AND pqd.profile_id = receipt.profile_id
			AND pqd.quote_id = receiptPrice.quote_id
			--AND pqd.ref_sequence_id = receiptPrice.quote_sequence_id
			AND (pqd.ref_sequence_id = 0 OR pqd.ref_sequence_id = receiptPrice.quote_sequence_id)
			AND pqd.bill_method = 'B'		--Bundled lines
			)
		AS count_bundled,
		Receipt.waste_code_uid,
		ReceiptPrice.currency_code
	FROM Receipt
		JOIN ReceiptPrice ON receipt.company_id = receiptPrice.company_id
			AND receipt.profit_ctr_id = receiptPrice.profit_ctr_id
			AND receipt.receipt_id = receiptPrice.receipt_id
			AND receipt.line_id = receiptPrice.line_id
			AND ISNULL(receiptPrice.print_on_invoice_flag,'F') = 'T'
		JOIN Company ON Company.company_id = Receipt.company_id
		LEFT OUTER JOIN CustomerBilling ON receipt.customer_id = CustomerBilling.customer_id
			AND receipt.billing_project_id = CustomerBilling.billing_project_id
		LEFT OUTER JOIN Generator ON receipt.generator_id = Generator.generator_id
		LEFT OUTER JOIN Profile ON receipt.profile_id = Profile.profile_id
	WHERE receipt.company_id = @company_id
		AND receipt.profit_ctr_id = @profit_ctr_id
		AND receipt.receipt_id = @receipt_id
		AND receipt.receipt_status = 'A'
		AND receipt.fingerpr_status = 'A'
		AND ISNULL(receipt.submitted_flag,'F') = 'F'
		AND (ISNULL(receipt.optional_flag, 'F') = 'F' 
			OR receipt.optional_flag = 'T' AND receipt.apply_charge_flag = 'T')
		AND NOT EXISTS (SELECT 1 FROM Billing 
			WHERE receiptPrice.company_id = Billing.company_id
			AND receiptPrice.profit_ctr_id = Billing.profit_ctr_id
			AND receiptPrice.receipt_id = Billing.receipt_id
			AND receiptPrice.line_id = Billing.line_id
			AND receiptPrice.price_id = Billing.price_id
			AND Billing.company_id = @company_id
			AND Billing.profit_ctr_id = @profit_ctr_id
			AND Billing.receipt_id = @receipt_id
			AND Billing.trans_source = 'R')
	SELECT @receipt_count = @@ROWCOUNT
	
	IF @debug = 1 print 'Selecting billing records:'
	IF @debug = 1 SELECT * FROM #Billing
	
	IF @receipt_count > 0
	BEGIN
		-- Get Billing Comments 
		INSERT INTO #BillingComment(company_id, profit_ctr_id, trans_source, receipt_id, 
			receipt_status, project_code, project_name,
			comment_1, comment_2, comment_3, comment_4, comment_5,
			date_added, date_modified, added_by, modified_by, service_date)
		SELECT DISTINCT Receipt.company_id,
			Receipt.profit_ctr_id,
			'R' AS trans_source,
			Receipt.receipt_id,
			'A' AS receipt_status,
			CONVERT(varchar(15), NULL) AS project_code,
			CONVERT(varchar(60), NULL) AS project_name,
			ISNULL(REPLACE(receiptComment.invoice_comment_1,'''', ''),'') AS invoice_comment_1,
			ISNULL(REPLACE(receiptComment.invoice_comment_2,'''', ''),'') AS invoice_comment_2,
			ISNULL(REPLACE(receiptComment.invoice_comment_3,'''', ''),'') AS invoice_comment_3,
			ISNULL(REPLACE(receiptComment.invoice_comment_4,'''', ''),'') AS invoice_comment_4,
			ISNULL(REPLACE(receiptComment.invoice_comment_5,'''', ''),'') AS invoice_comment_5,
			@submit_date AS date_added,
			@submit_date AS date_modified,
			@user_code AS added_by,
			@user_code AS modified_by,
			--coalesce(wos.date_act_arrive, WOH.start_date, rt1.transporter_sign_date, receipt.receipt_date) as service_date
			service_date = dbo.fn_get_service_date_no_time ( @company_id,@profit_ctr_id,@receipt_id, @trans_source  )  
		FROM receipt
		LEFT OUTER JOIN receiptComment
			ON receiptComment.company_id = receipt.company_id
			AND receiptComment.profit_ctr_id = receipt.profit_ctr_id
			AND receiptComment.receipt_id = receipt.receipt_id
			AND NOT (ISNULL(receiptComment.invoice_comment_1,'') = '' 
				AND  ISNULL(receiptComment.invoice_comment_2,'') = '' 
				AND  ISNULL(receiptComment.invoice_comment_3,'') = '' 
				AND  ISNULL(receiptComment.invoice_comment_4,'') = '' 
				AND  ISNULL(receiptComment.invoice_comment_5,'') = '' )
		LEFT OUTER JOIN ReceiptTransporter rt1  (nolock) 
			ON rt1.receipt_id = receipt.receipt_id
			AND rt1.profit_ctr_id = receipt.profit_ctr_id
			AND rt1.company_id = receipt.company_id
			AND rt1.transporter_sequence_id = 1
		LEFT OUTER JOIN BillingLinkLookup bll (nolock) 
			ON bll.receipt_id = receipt.receipt_id
			AND bll.profit_ctr_id = receipt.profit_ctr_id
			AND bll.company_id = receipt.company_id	
		LEFT OUTER JOIN WorkOrderHeader WOH
			ON WOH.company_id = bll.source_company_id
			AND WOH.profit_ctr_id = bll.source_profit_ctr_id
			AND WOH.workorder_id = bll.source_id		
		LEFT OUTER JOIN WorkOrderStop wos (nolock) 
			ON wos.workorder_id = WOH.workorder_id
			and wos.company_id = WOH.company_id
			and wos.profit_ctr_id = WOH.profit_ctr_id
			and wos.stop_sequence_id = 1 
		WHERE receipt.company_id = @company_id
			AND receipt.profit_ctr_id = @profit_ctr_id
			AND receipt.receipt_id = @receipt_id
			AND receipt.receipt_status = 'A'
			AND receipt.fingerpr_status = 'A'
			AND ISNULL(receipt.submitted_flag,'F') = 'F'
			AND NOT EXISTS (SELECT 1 FROM BillingComment 
				WHERE receipt.company_id = BillingComment.company_id
				AND receipt.profit_ctr_id = BillingComment.profit_ctr_id
				AND receipt.receipt_id = BillingComment.receipt_id
				AND BillingComment.company_id = @company_id
				AND BillingComment.profit_ctr_id = @profit_ctr_id
				AND BillingComment.receipt_id = @receipt_id
				AND BillingComment.trans_source = 'R')
		
		--------------------------------------------------------------------------------------------------------------------
		-- Call out-placed bundled charges code
		--------------------------------------------------------------------------------------------------------------------
		EXEC sp_billing_submit_calc_receipt_charges @debug
		--------------------------------------------------------------------------------------------------------------------
	
		
	END		--IF @receipt_count > 0
END		--IF @trans_source = 'R'

--------------------------
-- Submit Work Order
--------------------------
ELSE
BEGIN
	SELECT @fixed_price_flag = ISNULL(WorkorderHeader.fixed_price_flag,'F')
	FROM WorkorderHeader
	JOIN ProfitCenter
		ON WorkorderHeader.profit_ctr_id = ProfitCenter.profit_ctr_id
		AND ProfitCenter.company_id = @company_id
	WHERE WorkorderHeader.profit_ctr_id = @profit_ctr_id
		AND WorkorderHeader.company_id = @company_id
		AND WorkorderHeader.workorder_id = @receipt_id
		AND WorkorderHeader.workorder_status = 'A'
	IF @debug = 1 print 'Fixed Price Flag: ' + ISNULL(@fixed_price_flag, 'No value')

	-- IF a BillingComment record already exists for this workorder, populate
	-- All the Billing records with the Invoice information.  It means that
	-- This workorder has already been invoiced and is being resubmitted because
	-- of an adjustment
	SELECT @invoice_id = invoice_id, @invoice_code = invoice_code, @invoice_date = invoice_date 
	FROM BillingComment
	WHERE BillingComment.company_id = @company_id
		AND BillingComment.profit_ctr_id = @profit_ctr_id
		AND BillingComment.receipt_id = @receipt_id
	IF @debug = 1 print 'BillingComment:' 
				+ ' invoice_id: ' + Convert(varchar(15), ISNULL(@invoice_id, 0))
				+ ' invoice_code: ' + Convert(varchar(15), ISNULL(@invoice_code, 'No value'))

	-- Fixed price workorder, only one billing record
	IF @fixed_price_flag = 'T'
	BEGIN
		INSERT #Billing 
		SELECT 
			WorkorderHeader.company_id,
			WorkorderHeader.profit_ctr_id,
			'W' AS trans_source,
			WorkorderHeader.workorder_id,
			1 AS line_id,
			1 AS price_id,
			CASE WHEN WorkorderHeader.billing_link_id > 0
			  THEN 'H'
			  ELSE CASE WHEN @billing_status IS NOT NULL THEN @billing_status 
				ELSE CASE WHEN ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T' THEN 'H' ELSE 'S' END 
				END 
			END AS status_code,
			WorkOrderHeader.start_date AS billing_date,
			ISNULL(WorkorderHeader.customer_id, 0) AS customer_id,
			
--	Don't populate waste_code with dummy values.  9/10/13 JDB
--			'EQWO' AS waste_code,
			NULL AS waste_code,
			
			'EACH' AS bill_unit_code,
			'' AS vehicle_code,
			WorkorderHeader.generator_id,
			ISNULL(REPLACE(Generator.generator_name,'''', ''),'') AS generator_name,
			'' AS approval_code,
			WorkorderHeader.start_date AS time_in,
			WorkorderHeader.end_date AS time_out,
			4 AS tender_type,
			'' AS tender_comment,
			1 AS quantity,
			WorkorderHeader.total_price AS price,
			0 AS add_charge_amt,
			WorkorderHeader.total_price,
			CASE WHEN @discount_flag = 'T' THEN ISNULL(CustomerBilling.cust_discount,0) ELSE 0 END AS discount_percent,
--rb		gl_account_code = GLAccount.account_code,
--JDB		gl_account_code = WorkOrderResourceType.gl_seg_1 
--					+ RIGHT('00' + CONVERT(varchar(2),WorkOrderHeader.company_id),2)
--					+ RIGHT('00' + CONVERT(varchar(2),WorkOrderHeader.profit_ctr_id),2) 
--					+ WorkOrderTypeHeader.gl_seg_4,
			-- SK 02/20 gl_account_code = dbo.fn_get_workorder_glaccount(WorkOrderHeader.company_id, WorkOrderHeader.profit_ctr_id, WorkOrderHeader.workorder_id, 'O', 0),
			-- SK 02/20 '' AS gl_sr_account_code,
			WorkorderHeader.workorder_type AS gl_account_type,
			'' AS sr_type,
			'E' AS sr_type_code,
			0 AS sr_price,
			WorkorderHeader.total_price AS waste_extended_amt,
			0 AS sr_extended_amt,
			WorkorderHeader.total_price AS total_extended_amt,
			0 AS cash_received,
			'' AS manifest,
			'' AS manifest_flag,
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
			ISNULL(WorkorderHeader.invoice_break_value,'') AS workorder_invoice_break_value,
			'H' AS workorder_resource_type,
			'0' AS workorder_sequence_id,
			ISNULL(REPLACE(WorkorderHeader.purchase_order,'''', ''),'') AS purchase_order,
			ISNULL(REPLACE(WorkorderHeader.release_code,'''', ''),'') AS release_code,
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
			'O' AS trans_type,
			0 AS ref_line_id,
			SUBSTRING(LTRIM(RTRIM(ISNULL(WorkorderHeader.project_code,'') + ' ' + ISNULL(WorkorderHeader.project_name,''))), 1, 100) AS service_desc_1,
			'' AS service_desc_2,
			ISNULL(WorkorderHeader.total_cost,0) AS cost,
			NULL AS secondary_manifest,

			0.00 AS insr_percent,
			0.00 AS insr_extended_amt,
			--NULL AS gl_insr_account_code,

			0.00 AS ensr_percent,
			0.00 AS ensr_extended_amt,
			--NULL AS gl_ensr_account_code,
			
			NULL AS bundled_tran_bill_qty_flag,
			NULL AS bundled_tran_price,
			NULL AS bundled_tran_extended_amt,
			-- SK 02/20 NULL AS bundled_tran_gl_account_code,
			NULL AS product_id,
			ISNULL(WorkorderHeader.billing_project_id,0),
			WorkorderHeader.po_sequence_id,
			'F' AS invoice_preview_flag,
			'F' AS COD_sent_flag,
			'F' AS COR_sent_flag,
			'F' AS invoice_hold_flag,
			NULL AS profile_id,
			WorkOrderHeader.reference_code,
			NULL AS tsdf_approval_id,
			WorkorderHeader.billing_link_id,
			CASE WHEN WorkorderHeader.billing_link_id IS NOT NULL AND WorkorderHeader.billing_link_id = 0 AND WorkorderHeader.submit_on_hold_reason IS NULL
				THEN NULL
			     WHEN WorkorderHeader.billing_link_id IS NOT NULL AND WorkorderHeader.billing_link_id > 0 AND WorkorderHeader.submit_on_hold_reason IS NULL
				THEN 'WorkorderHeader is member of Billing Link ' + Convert(varchar(10), WorkorderHeader.billing_link_id)
			     WHEN ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T' AND WorkorderHeader.submit_on_hold_reason IS NULL
				THEN 'Submitted on Hold with no supporting reason.'
			     WHEN ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T' AND WorkorderHeader.submit_on_hold_reason IS NOT NULL
				THEN WorkorderHeader.submit_on_hold_reason
			     WHEN @submit_status IS NOT NULL
				THEN 'Submitted on Hold with no supporting reason.'
			END AS hold_reason,
			CASE WHEN WorkorderHeader.billing_link_id > 0 OR @submit_status IS NOT NULL OR ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T'
				THEN @user_code
				ELSE NULL
			END AS hold_userid,
			CASE WHEN WorkorderHeader.billing_link_id > 0 OR @submit_status IS NOT NULL OR ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T'
				THEN @submit_date
				ELSE NULL
			END AS hold_date,
			@invoice_id,
			@invoice_code,
			@invoice_date,
			NULL AS date_delivered,
			0,
			0,
			NULL,
			0 AS count_bundled,
			NULL AS waste_code_uid,
			WorkOrderHeader.currency_code
		FROM WorkOrderHeader
		JOIN Company ON Company.company_id = WorkOrderHeader.company_id
		JOIN WorkOrderTypeHeader ON WorkOrderHeader.workorder_type_id = WorkOrderTypeHeader.workorder_type_id
		JOIN WorkorderResourceType ON WorkOrderResourceType.resource_type = 'O'
		LEFT OUTER JOIN CustomerBilling ON WorkorderHeader.customer_id = CustomerBilling.customer_id
			AND WorkorderHeader.billing_project_id = CustomerBilling.billing_project_id
		LEFT OUTER JOIN Generator ON WorkorderHeader.generator_id = Generator.generator_id
		WHERE ISNULL(WorkorderHeader.fixed_price_flag,'F') = 'T'
			AND ISNULL(WorkorderHeader.total_price,0) > 0
			AND WorkorderHeader.company_id = @company_id
			AND WorkorderHeader.profit_ctr_id = @profit_ctr_id
			AND WorkorderHeader.workorder_id = @receipt_id
			AND WorkorderHeader.workorder_status = 'A'
			AND ISNULL(WorkorderHeader.submitted_flag,'F') = 'F'
			AND NOT EXISTS (SELECT 1 FROM Billing 
				WHERE WorkorderHeader.company_id = Billing.company_id
				AND WorkorderHeader.profit_ctr_id = Billing.profit_ctr_id
				AND WorkorderHeader.workorder_id = Billing.receipt_id
				AND 1 = Billing.line_id
				AND 1 = Billing.price_id
				AND Billing.company_id = @company_id
				AND Billing.profit_ctr_id = @profit_ctr_id
				AND Billing.receipt_id = @receipt_id
				AND Billing.trans_source = 'W')
		SELECT @receipt_count = @@ROWCOUNT
		IF @debug = 1 print 'Insert Fixed Price WO count: ' + STR(@receipt_count)
		
		-----------------------------------------------------------------------------
		-- New insert added 10/12/10 for new BillingDetail table
		-----------------------------------------------------------------------------
		INSERT #BillingDetail
 (
	billing_uid			,
	ref_billingdetail_uid	,
	billingtype_uid		,
	billing_type		,
	company_id			,
	profit_ctr_id		,
	receipt_id			,
	line_id				,
	price_id			,
	trans_source		,
	trans_type			,
	product_id			,
	dist_company_id		,
	dist_profit_ctr_id	,
	sales_tax_id		,
	applied_percent		,
	extended_amt		,
	gl_account_code		,
	sequence_id			,
	JDE_BU				,
	JDE_object			,
	currency_code			
)
		
		SELECT 1 AS billing_uid,
			NULL AS ref_billingdetail_uid,
			BillingType.billingtype_uid,
			BillingType.billing_type,
			WorkorderHeader.company_id,
			WorkorderHeader.profit_ctr_id,
			WorkorderHeader.workorder_id,
			1 AS line_id,
			1 AS price_id,
			'W' AS trans_source,
			'O' AS trans_type,
			NULL AS product_id,
			WorkorderHeader.company_id AS dist_company_id,
			WorkorderHeader.profit_ctr_id AS dist_profit_ctr_id,
			NULL AS sales_tax_id,
			NULL AS applied_percent,
			WorkorderHeader.total_price AS extended_amt,
			--WorkOrderResourceType.gl_seg_1 
			--	+ RIGHT('00' + CONVERT(varchar(2),WorkOrderHeader.company_id),2)
			--	+ RIGHT('00' + CONVERT(varchar(2),WorkOrderHeader.profit_ctr_id),2)
			--	+ WorkOrderTypeHeader.gl_seg_4,
			gl_account_code = dbo.fn_get_workorder_glaccount(WorkOrderHeader.company_id, WorkOrderHeader.profit_ctr_id, WorkOrderHeader.workorder_id, 'O', 0),
			NULL AS sequence_id,
			JDE_BU = dbo.fn_get_workorder_JDE_glaccount_business_unit(WorkOrderHeader.company_id, WorkOrderHeader.profit_ctr_id, WorkOrderHeader.workorder_id, 'O', 0),
			JDE_object = dbo.fn_get_workorder_JDE_glaccount_object(WorkOrderHeader.company_id, WorkOrderHeader.profit_ctr_id, WorkOrderHeader.workorder_id, 'O', 0),
			WorkOrderHeader.currency_code
		FROM WorkorderHeader
		JOIN WorkOrderTypeHeader ON WorkOrderHeader.workorder_type_id = WorkOrderTypeHeader.workorder_type_id
		JOIN WorkorderResourceType ON WorkOrderResourceType.resource_type = 'O'
		JOIN BillingType ON BillingType.billing_type = 'WorkOrder'
		LEFT OUTER JOIN CustomerBilling ON WorkorderHeader.customer_id = CustomerBilling.customer_id
			AND WorkorderHeader.billing_project_id = CustomerBilling.billing_project_id
		LEFT OUTER JOIN Generator ON WorkorderHeader.generator_id = Generator.generator_id
		WHERE ISNULL(WorkorderHeader.fixed_price_flag, 'F') = 'T'
			AND ISNULL(WorkorderHeader.total_price, 0) > 0
			AND WorkorderHeader.company_id = @company_id
			AND WorkorderHeader.profit_ctr_id = @profit_ctr_id
			AND WorkorderHeader.workorder_id = @receipt_id
			AND WorkorderHeader.workorder_status = 'A'
			AND ISNULL(WorkorderHeader.submitted_flag, 'F') = 'F'
			AND NOT EXISTS (SELECT 1 FROM Billing 
				WHERE WorkorderHeader.company_id = Billing.company_id
				AND WorkorderHeader.profit_ctr_id = Billing.profit_ctr_id
				AND WorkorderHeader.workorder_id = Billing.receipt_id
				AND 1 = Billing.line_id
				AND 1 = Billing.price_id
				AND Billing.company_id = @company_id
				AND Billing.profit_ctr_id = @profit_ctr_id
				AND Billing.receipt_id = @receipt_id
				AND Billing.trans_source = 'W')
				
	END		-- IF @fixed_price_flag = 'T'
	ELSE
	BEGIN
		IF @debug = 1 print 'Not a fixed price workorder'
		-- Not a fixed price workorder
		INSERT #Billing 
		SELECT  --  All BUT disposal lines
			WorkorderHeader.company_id,
			WorkorderHeader.profit_ctr_id,
			'W' AS trans_source,
			WorkorderHeader.workorder_id,
			0 AS line_id,
			1 AS price_id,
			CASE WHEN WorkorderHeader.billing_link_id > 0
			  THEN 'H'
			  ELSE CASE WHEN @billing_status IS NOT NULL THEN @billing_status 
				ELSE CASE WHEN ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T' THEN 'H' ELSE 'S' END 
				END 
			END AS status_code,
			WorkOrderHeader.start_date AS billing_date,
			ISNULL(WorkorderHeader.customer_id, 0) AS customer_id,

--	Don't populate waste_code with dummy values.  9/10/13 JDB
--			'EQWO' AS waste_code,
			NULL AS waste_code,
			
			WorkorderDetail.bill_unit_code,
			'' AS vehicle_code,
			WorkorderHeader.generator_id,
			ISNULL(REPLACE(Generator.generator_name,'''', ''),'') AS generator_name,
			'' AS approval_code,
			WorkorderHeader.start_date AS time_in,
			WorkorderHeader.end_date AS time_out,
			4 AS tender_type,
			'' AS tender_comment,
			WorkorderDetail.quantity_used AS quantity,
			CASE WHEN WorkorderDetail.extended_price = 0 THEN 0 ELSE WorkorderDetail.price END AS price,
			0 AS add_charge_amt,
			WorkorderDetail.extended_price AS orig_extended_amt,
			CASE WHEN @discount_flag = 'T' THEN ISNULL(CustomerBilling.cust_discount,0) ELSE 0 END AS discount_percent,
			--gl_account_code = CASE WHEN ISNUMERIC(REPLACE(LEFT(ResourceClassGLAccount.gl_account_code,5),' ','X')) > 0 OR LEFT(ResourceClassGLAccount.gl_account_code,5) = '00000'
			--		THEN LEFT(ResourceClassGLAccount.gl_account_code,5)
			--		ELSE WorkOrderResourceType.gl_seg_1 END
			--	+ RIGHT('00' + CONVERT(varchar(2),WorkorderHeader.company_id),2)
			--	+ RIGHT('00' + CONVERT(varchar(2),WorkorderHeader.profit_ctr_id),2)
			--	+ CASE WHEN ISNUMERIC(REPLACE(SUBSTRING(ResourceClassGLAccount.gl_account_code,10,3),' ','X')) > 0 OR SUBSTRING(ResourceClassGLAccount.gl_account_code,10,3) = '000'
			--			THEN SUBSTRING(ResourceClassGLAccount.gl_account_code,10,3)
			--			ELSE WorkOrderTypeHeader.gl_seg_4 
			--END,
			-- SK 02/20 gl_account_code = dbo.fn_get_workorder_glaccount(WorkOrderHeader.company_id, WorkOrderHeader.profit_ctr_id, WorkOrderHeader.workorder_id, WorkorderDetail.resource_type, WorkorderDetail.sequence_id),
			-- SK 02/20 '' AS gl_sr_account_code,

			WorkorderHeader.workorder_type AS gl_account_type,
			'' AS sr_type,
			'E' AS sr_type_code,
			0 AS sr_price,
			WorkorderDetail.extended_price AS waste_extended_amt,
			0 AS sr_extended_amt,
			WorkorderDetail.extended_price AS total_extended_amt,
			0 AS cash_received,
			ISNULL(WorkorderDetail.manifest,'') AS manifest,
			manifest_flag = CASE WHEN WorkorderDetail.manifest IS NULL THEN '' ELSE 'M' END,
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
			WorkorderDetail.resource_class_code AS workorder_resource_item,
			ISNULL(WorkorderHeader.invoice_break_value,'') AS workorder_invoice_break_value,
			WorkorderDetail.resource_type AS workorder_resource_type,
			CONVERT(varchar(10), WorkorderDetail.sequence_id) AS workorder_sequence_id,
			ISNULL(REPLACE(WorkorderHeader.purchase_order,'''', ''),'') AS purchase_order,
			ISNULL(REPLACE(WorkorderHeader.release_code,'''', ''),'') AS release_code,
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
			'O' AS trans_type,
			0 AS ref_line_id,
			service_desc_1 = CASE WHEN WorkorderDetail.resource_type = 'G' OR WorkorderDetail.resource_type = 'L'
				THEN SUBSTRING(LTRIM(RTRIM(ISNULL(WorkorderDetail.description,''))), 1, 96) + 
					CASE WorkorderDetail.bill_rate
					WHEN 1 THEN '(ST)'
					WHEN 1.5 THEN '(OT)'
					WHEN 2 THEN '(DT)'
					ELSE ''
					END
				ELSE SUBSTRING(LTRIM(RTRIM(ISNULL(WorkorderDetail.description,''))), 1, 100) 
				END,
			service_desc_2 = CASE WHEN WorkorderDetail.resource_type = 'D'
				THEN SUBSTRING('Disposal: ' + ISNULL(WorkorderDetail.TSDF_code,'') + '/' + ISNULL(WorkorderDetail.TSDF_approval_code,'') + ' Man/BOL:' + ISNULL(WorkorderDetail.manifest,''), 1, 100)
				ELSE SUBSTRING(ISNULL(WorkorderDetail.description_2,''), 1, 100)
				END,	
			ISNULL(WorkorderDetail.extended_cost,0) AS cost,
			NULL AS secondary_manifest,
			
			0.00 AS insr_percent,
			0.00 AS insr_extended_amt,
			--NULL AS gl_insr_account_code,
			
			0.00 AS ensr_percent,
			0.00 AS ensr_extended_amt,
			--NULL AS gl_ensr_account_code,
			
			NULL AS bundled_tran_bill_qty_flag,
			NULL AS bundled_tran_price,
			NULL AS bundled_tran_extended_amt,
			-- SK 02/20 NULL AS bundled_tran_gl_account_code,
			NULL AS product_id,
			ISNULL(WorkorderHeader.billing_project_id,0),
			WorkorderHeader.po_sequence_id,
			'F' AS invoice_preview_flag,
			'F' AS COD_sent_flag,
			'F' AS COR_sent_flag,
			'F' AS invoice_hold_flag,
			WorkorderDetail.profile_id,
			WorkOrderHeader.reference_code,
			WorkorderDetail.tsdf_approval_id,
			WorkorderHeader.billing_link_id,
			CASE WHEN WorkorderHeader.billing_link_id IS NOT NULL AND WorkorderHeader.billing_link_id = 0 AND WorkorderHeader.submit_on_hold_reason IS NULL
				THEN NULL
			     WHEN WorkorderHeader.billing_link_id IS NOT NULL AND WorkorderHeader.billing_link_id > 0 AND WorkorderHeader.submit_on_hold_reason IS NULL
				THEN 'WorkorderHeader is member of Billing Link ' + Convert(varchar(10), WorkorderHeader.billing_link_id)
			     WHEN ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T' AND WorkorderHeader.submit_on_hold_reason IS NULL
				THEN 'Submitted on Hold with no supporting reason.'
			     WHEN ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T' AND WorkorderHeader.submit_on_hold_reason IS NOT NULL
				THEN WorkorderHeader.submit_on_hold_reason
			     WHEN @submit_status IS NOT NULL
				THEN 'Submitted on Hold with no supporting reason.'
			END AS hold_reason,
			CASE WHEN WorkorderHeader.billing_link_id > 0 OR @submit_status IS NOT NULL OR ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T'
				THEN @user_code
				ELSE NULL
			END AS hold_userid,
			CASE WHEN WorkorderHeader.billing_link_id > 0 OR @submit_status IS NOT NULL OR ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T'
				THEN @submit_date
				ELSE NULL
			END AS hold_date,
			@invoice_id,
			@invoice_code,
			@invoice_date,
			WorkOrderManifest.date_delivered,
			CASE WorkorderDetail.resource_type
				WHEN 'G' THEN 1
				WHEN 'E' THEN 2
				WHEN 'L' THEN 3
				WHEN 'D' THEN 4
				WHEN 'O' THEN 5
				WHEN 'S' THEN 6
			END AS resource_sort,
			WorkorderDetail.billing_sequence_id AS bill_sequence,
			NULL,
			0 AS count_bundled,
			NULL AS waste_code_uid,
			WorkOrderDetail.currency_code
		FROM WorkOrderHeader
		JOIN Company ON Company.company_id = WorkOrderHeader.company_id
		JOIN WorkorderDetail ON WorkorderHeader.company_id = WorkorderDetail.company_id
			AND WorkorderHeader.profit_ctr_id = WorkorderDetail.profit_ctr_id
			AND WorkorderHeader.workorder_id = WorkorderDetail.workorder_id
			AND ISNULL(WorkorderDetail.print_on_invoice_flag, 'F') = 'T'
			--AND WorkorderDetail.bill_rate > 0
			-- SK Also Include No charge Print on Invoice lines
			AND WorkorderDetail.bill_rate >= 0
			AND NOT(WorkorderDetail.resource_type IN ('E','L','S')
				AND RTRIM(ISNULL(WorkorderDetail.group_code, '')) <> '')
		JOIN WorkOrderTypeHeader ON WorkOrderHeader.workorder_type_id = WorkOrderTypeHeader.workorder_type_id
		JOIN WorkorderResourceType ON WorkOrderDetail.resource_type = WorkOrderResourceType.resource_type
		--LEFT OUTER JOIN ResourceClassGLAccount ON ResourceClassGLAccount.company_id = WorkOrderDetail.company_id
			--AND ResourceClassGLAccount.profit_ctr_id = WorkOrderDetail.profit_ctr_id
			--AND ResourceClassGLAccount.resource_class_code = WorkOrderDetail.resource_class_code
		LEFT OUTER JOIN WorkorderManifest ON WorkorderDetail.profit_ctr_id = WorkorderManifest.profit_ctr_id
			AND WorkorderDetail.company_id = WorkorderManifest.company_id
			AND WorkorderDetail.workorder_id = WorkorderManifest.workorder_id
			AND WorkorderDetail.manifest = WorkorderManifest.manifest
		LEFT OUTER JOIN CustomerBilling ON WorkorderHeader.customer_id = CustomerBilling.customer_id
			AND WorkorderHeader.billing_project_id = CustomerBilling.billing_project_id
		LEFT OUTER JOIN Generator ON WorkorderHeader.generator_id = Generator.generator_id
		WHERE ISNULL(WorkorderHeader.fixed_price_flag,'F') = 'F'
			AND WorkorderHeader.company_id = @company_id
			AND WorkorderHeader.profit_ctr_id = @profit_ctr_id
			AND WorkorderHeader.workorder_id = @receipt_id
			AND WorkorderHeader.workorder_status = 'A'
			AND ISNULL(WorkorderHeader.submitted_flag,'F') = 'F'
			AND WorkorderDetail.resource_type <> 'D'
			AND NOT EXISTS (SELECT 1 FROM Billing 
				WHERE WorkorderHeader.company_id = Billing.company_id
				AND WorkorderHeader.profit_ctr_id = Billing.profit_ctr_id
				AND WorkorderHeader.workorder_id = Billing.receipt_id
				--AND 1 = Billing.line_id
				--AND 1 = Billing.price_id
				AND Billing.company_id = @company_id
				AND Billing.profit_ctr_id = @profit_ctr_id
				AND Billing.receipt_id = @receipt_id
				AND Billing.trans_source = 'W')
				
	--  New Stuff for WorkorderDetailUnit
	UNION
	
			SELECT  -- Disposal lines Only
			WorkorderHeader.company_id,
			WorkorderHeader.profit_ctr_id,
			'W' AS trans_source,
			WorkorderHeader.workorder_id,
			0 AS line_id,
			--1 AS price_id,
			price_id = ROW_NUMBER() 
				OVER(PARTITION BY WorkorderHeader.company_id,
					WorkorderHeader.profit_ctr_id,
					WorkorderHeader.workorder_id,
					WorkorderDetail.resource_type,
					WorkorderDetail.billing_sequence_id
				ORDER BY WorkorderHeader.company_id,
					WorkorderHeader.profit_ctr_id,
					WorkorderHeader.workorder_id,
					WorkorderDetail.resource_type,
					WorkorderDetail.billing_sequence_id),
			CASE WHEN WorkorderHeader.billing_link_id > 0
			  THEN 'H'
			  ELSE CASE WHEN @billing_status IS NOT NULL THEN @billing_status 
				ELSE CASE WHEN ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T' THEN 'H' ELSE 'S' END 
				END 
			END AS status_code,
			WorkOrderHeader.start_date AS billing_date,
			ISNULL(WorkorderHeader.customer_id, 0) AS customer_id,
			
--	Don't populate waste_code with dummy values.  9/10/13 JDB
--			'EQWO' AS waste_code,
			NULL AS waste_code,
			
			WorkorderDetailUnit.bill_unit_code,
			'' AS vehicle_code,
			WorkorderHeader.generator_id,
			ISNULL(REPLACE(Generator.generator_name,'''', ''),'') AS generator_name,
			'' AS approval_code,
			WorkorderHeader.start_date AS time_in,
			WorkorderHeader.end_date AS time_out,
			4 AS tender_type,
			'' AS tender_comment,
			WorkorderDetailUnit.quantity AS quantity,
			CASE WHEN WorkorderDetailunit.extended_price = 0 THEN 0 ELSE WorkorderDetailunit.price END AS price,
			0 AS add_charge_amt,
			WorkorderDetailunit.extended_price AS orig_extended_amt,
			CASE WHEN @discount_flag = 'T' THEN ISNULL(CustomerBilling.cust_discount,0) ELSE 0 END AS discount_percent,
			--gl_account_code = WorkOrderResourceType.gl_seg_1 
			--	+ RIGHT('00' + CONVERT(varchar(2),WorkOrderHeader.company_id),2)
			--	+ RIGHT('00' + CONVERT(varchar(2),WorkOrderHeader.profit_ctr_id),2) 
			--	+ WorkOrderTypeHeader.gl_seg_4,
			-- SK 02/20 gl_account_code = dbo.fn_get_workorder_glaccount(WorkOrderHeader.company_id, WorkOrderHeader.profit_ctr_id, WorkOrderHeader.workorder_id, WorkorderDetail.resource_type, WorkorderDetail.sequence_id),
			-- SK 02/20 '' AS gl_sr_account_code,
			WorkorderHeader.workorder_type AS gl_account_type,
			'' AS sr_type,
			'E' AS sr_type_code,
			0 AS sr_price,
			WorkorderDetailunit.extended_price AS waste_extended_amt,
			0 AS sr_extended_amt,
			WorkorderDetailunit.extended_price AS total_extended_amt,
			0 AS cash_received,
			ISNULL(WorkorderDetail.manifest,'') AS manifest,
			manifest_flag = CASE WHEN WorkorderDetail.manifest IS NULL THEN '' ELSE 'M' END,
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
			WorkorderDetail.resource_class_code AS workorder_resource_item,
			ISNULL(WorkorderHeader.invoice_break_value,'') AS workorder_invoice_break_value,
			WorkorderDetail.resource_type AS workorder_resource_type,
			CONVERT(varchar(10), WorkorderDetail.sequence_id) AS workorder_sequence_id,
			ISNULL(REPLACE(WorkorderHeader.purchase_order,'''', ''),'') AS purchase_order,
			ISNULL(REPLACE(WorkorderHeader.release_code,'''', ''),'') AS release_code,
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
			'O' AS trans_type,
			0 AS ref_line_id,
			service_desc_1 = CASE WHEN WorkorderDetail.resource_type = 'G' OR WorkorderDetail.resource_type = 'L'
				THEN SUBSTRING(LTRIM(RTRIM(ISNULL(WorkorderDetail.description,''))), 1, 96) + 
					CASE WorkorderDetail.bill_rate
					WHEN 1 THEN '(ST)'
					WHEN 1.5 THEN '(OT)'
					WHEN 2 THEN '(DT)'
					ELSE ''
					END
				ELSE SUBSTRING(LTRIM(RTRIM(ISNULL(WorkorderDetail.description,''))), 1, 100) 
				END,
			service_desc_2 = CASE WHEN WorkorderDetail.resource_type = 'D'
				THEN SUBSTRING('Disposal: ' + ISNULL(WorkorderDetail.TSDF_code,'') + '/' + ISNULL(WorkorderDetail.TSDF_approval_code,'') + ' Man/BOL:' + ISNULL(WorkorderDetail.manifest,''), 1, 100)
				ELSE SUBSTRING(ISNULL(WorkorderDetail.description_2,''), 1, 100)
				END,	
			ISNULL(WorkorderDetailunit.extended_cost,0) AS cost,
			NULL AS secondary_manifest,
			
			0.00 AS insr_percent,
			0.00 AS insr_extended_amt,
			--gl_insr_account_code,
			
			0.00 AS ensr_percent,
			0.00 AS ensr_extended_amt,
			--gl_ensr_account_code,
		
			NULL AS bundled_tran_bill_qty_flag,
			NULL AS bundled_tran_price,
			NULL AS bundled_tran_extended_amt,
			-- SK 02/20 NULL AS bundled_tran_gl_account_code,
			NULL AS product_id,
			ISNULL(WorkorderHeader.billing_project_id,0),
			WorkorderHeader.po_sequence_id,
			'F' AS invoice_preview_flag,
			'F' AS COD_sent_flag,
			'F' AS COR_sent_flag,
			'F' AS invoice_hold_flag,
			WorkorderDetail.profile_id,
			WorkOrderHeader.reference_code,
			WorkorderDetail.tsdf_approval_id,
			WorkorderHeader.billing_link_id,
			CASE WHEN WorkorderHeader.billing_link_id IS NOT NULL AND WorkorderHeader.billing_link_id = 0 AND WorkorderHeader.submit_on_hold_reason IS NULL
				THEN NULL
			     WHEN WorkorderHeader.billing_link_id IS NOT NULL AND WorkorderHeader.billing_link_id > 0 AND WorkorderHeader.submit_on_hold_reason IS NULL
				THEN 'WorkorderHeader is member of Billing Link ' + Convert(varchar(10), WorkorderHeader.billing_link_id)
			     WHEN ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T' AND WorkorderHeader.submit_on_hold_reason IS NULL
				THEN 'Submitted on Hold with no supporting reason.'
			     WHEN ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T' AND WorkorderHeader.submit_on_hold_reason IS NOT NULL
				THEN WorkorderHeader.submit_on_hold_reason
			     WHEN @submit_status IS NOT NULL
				THEN 'Submitted on Hold with no supporting reason.'
			END AS hold_reason,
			CASE WHEN WorkorderHeader.billing_link_id > 0 OR @submit_status IS NOT NULL OR ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T'
				THEN @user_code
				ELSE NULL
			END AS hold_userid,
			CASE WHEN WorkorderHeader.billing_link_id > 0 OR @submit_status IS NOT NULL OR ISNULL(WorkorderHeader.submit_on_hold_flag,'F') = 'T'
				THEN @submit_date
				ELSE NULL
			END AS hold_date,
			@invoice_id,
			@invoice_code,
			@invoice_date,
			WorkOrderManifest.date_delivered,
			CASE WorkorderDetail.resource_type
				WHEN 'G' THEN 1
				WHEN 'E' THEN 2
				WHEN 'L' THEN 3
				WHEN 'D' THEN 4
				WHEN 'O' THEN 5
				WHEN 'S' THEN 6
			END AS resource_sort,
			WorkorderDetail.billing_sequence_id AS bill_sequence,
			NULL,
			0 AS count_bundled,
			NULL AS waste_code_uid,
			WorkOrderDetail.currency_code
		FROM WorkorderHeader
		JOIN Company ON Company.company_id = WorkOrderHeader.company_id
		JOIN WorkorderDetail ON WorkorderHeader.company_id = WorkorderDetail.company_id
			AND WorkorderHeader.profit_ctr_id = WorkorderDetail.profit_ctr_id
			AND WorkorderHeader.workorder_id = WorkorderDetail.workorder_id
			AND WorkorderDetail.resource_type = 'D'
			-- None of below is correct - 08/22/2011
			 --AND WorkorderDetail.bill_rate > 0
			-- SK Also Include No charge Print on Invoice lines
			--AND WorkorderDetail.bill_rate >= 0
		LEFT OUTER JOIN WorkorderManifest ON WorkorderDetail.profit_ctr_id = WorkorderManifest.profit_ctr_id
			AND WorkorderDetail.company_id = WorkorderManifest.company_id
			AND WorkorderDetail.workorder_id = WorkorderManifest.workorder_id
			AND WorkorderDetail.manifest = WorkorderManifest.manifest
			-- 08222011 SK - changed below from 'left outer' to 'join'
		JOIN WorkOrderDetailUnit ON WorkorderDetail.company_id = WorkOrderDetailUnit.company_id
			AND WorkorderDetail.profit_ctr_id = WorkOrderDetailUnit.profit_ctr_id
			AND WorkorderDetail.workorder_id = WorkOrderDetailUnit.workorder_id
			AND WorkorderDetail.sequence_id = WorkOrderDetailUnit.sequence_id
			-- 08/22/2011 when price > 0 only include if billrate > 0, 
			--            when price = 0 include if marked print on invoice & not void billrate >= 0
			AND ((WorkOrderDetailUnit.extended_price > 0 AND WorkorderDetail.bill_rate > 0)
				OR (WorkOrderDetailUnit.extended_price = 0 AND ISNULL(WorkorderDetail.print_on_invoice_flag, 'F') = 'T' AND WorkorderDetail.bill_rate >= 0))
		JOIN WorkOrderTypeHeader ON WorkOrderHeader.workorder_type_id = WorkOrderTypeHeader.workorder_type_id
		JOIN WorkorderResourceType ON WorkOrderDetail.resource_type = WorkOrderResourceType.resource_type
		LEFT OUTER JOIN CustomerBilling ON WorkorderHeader.customer_id = CustomerBilling.customer_id
			AND WorkorderHeader.billing_project_id = CustomerBilling.billing_project_id
		LEFT OUTER JOIN Generator ON WorkorderHeader.generator_id = Generator.generator_id
		WHERE ISNULL(WorkorderHeader.fixed_price_flag,'F') = 'F'
			AND WorkorderDetail.resource_type = 'D'
			AND WorkOrderDetailUnit.billing_flag = 'T'
			AND ISNULL(WorkOrderDetailUnit.quantity,0) > 0
			AND WorkorderHeader.company_id = @company_id
			AND WorkorderHeader.profit_ctr_id = @profit_ctr_id
			AND WorkorderHeader.workorder_id = @receipt_id
			AND WorkorderHeader.workorder_status = 'A'
			AND ISNULL(WorkorderHeader.submitted_flag,'F') = 'F'
			AND NOT EXISTS (SELECT 1 FROM Billing 
				WHERE WorkorderHeader.company_id = Billing.company_id
				AND WorkorderHeader.profit_ctr_id = Billing.profit_ctr_id
				AND WorkorderHeader.workorder_id = Billing.receipt_id
				--AND 1 = Billing.line_id
				--AND 1 = Billing.price_id
				AND Billing.company_id = @company_id
				AND Billing.profit_ctr_id = @profit_ctr_id
				AND Billing.receipt_id = @receipt_id
				AND Billing.trans_source = 'W')
		ORDER BY 
			CASE WorkorderDetail.resource_type
				WHEN 'G' THEN 1
				WHEN 'E' THEN 2
				WHEN 'L' THEN 3
				WHEN 'D' THEN 4
				WHEN 'O' THEN 5
				WHEN 'S' THEN 6
			END,
			WorkorderDetail.billing_sequence_id
		SELECT @receipt_count = @@ROWCOUNT

		-- Create temp table used to calculate line_id
		SELECT DISTINCT
			company_id,
			profit_ctr_id,
			receipt_id,
			resource_sort,
			bill_sequence,
			line_id
		INTO #tmp_line_id
		FROM #Billing
		ORDER BY company_id,
			profit_ctr_id,
			receipt_id,
			resource_sort,
			bill_sequence
		
		-- Update the line IDs in #tmp_line_id table
		SELECT @incr_line_id = 0
		UPDATE #tmp_line_id SET	@incr_line_id = line_id = @incr_line_id + 1

		-- Update #Billing table
		UPDATE #Billing SET	line_id = #tmp_line_id.line_id
		FROM #Billing b
		JOIN #tmp_line_id ON #tmp_line_id.company_id = b.company_id
			AND #tmp_line_id.profit_ctr_id = b.profit_ctr_id
			AND #tmp_line_id.receipt_id = b.receipt_id
			AND #tmp_line_id.resource_sort = b.resource_sort
			AND #tmp_line_id.bill_sequence = b.bill_sequence
		
		IF @debug = 1 SELECT * FROM #Billing
			
			
		INSERT #BillingDetail
			(
				billing_uid			,
				ref_billingdetail_uid,
				billingtype_uid		,
				billing_type		,
				company_id			,
				profit_ctr_id		,
				receipt_id			,
				line_id				,
				price_id			,
				trans_source		,
				trans_type			,
				product_id			,
				dist_company_id		,
				dist_profit_ctr_id	,
				sales_tax_id		,
				applied_percent		,
				extended_amt		,
				gl_account_code		,
				sequence_id			,
				JDE_BU				,
				JDE_object			,
				currency_code			
/*
				AX_MainAccount		varchar(20)		NULL,
				AX_Dimension_1		varchar(20)		NULL,
				AX_Dimension_2		varchar(20)		NULL,
				AX_Dimension_3		varchar(20)		NULL,
				AX_Dimension_4		varchar(20)		NULL,
				AX_Dimension_5_Part_1		varchar(20)		NULL,
				AX_Dimension_5_Part_2		varchar(9)		NULL,
				AX_Dimension_6		varchar(20)		NULL,
				AX_Project_Required_Flag varchar(20) NULL
*/
			)
		SELECT b.billing_uid,
			NULL AS ref_billingdetail_uid,
			BillingType.billingtype_uid,
			BillingType.billing_type,
			b.company_id,
			b.profit_ctr_id,
			b.receipt_id,
			b.line_id,
			b.price_id,
			b.trans_source,
			b.trans_type,
			NULL AS product_id,
			b.company_id AS dist_company_id,
			b.profit_ctr_id AS dist_profit_ctr_id,
			NULL AS sales_tax_id,
			NULL AS applied_percent,
			b.total_extended_amt AS extended_amt,
			-- SK 02/20 b.gl_account_code,
			gl_account_code = dbo.fn_get_workorder_glaccount(WorkOrderHeader.company_id, WorkOrderHeader.profit_ctr_id, WorkOrderHeader.workorder_id, WorkorderDetail.resource_type, WorkorderDetail.sequence_id),
			NULL AS sequence_id,
			JDE_BU = dbo.fn_get_workorder_JDE_glaccount_business_unit(WorkOrderHeader.company_id, WorkOrderHeader.profit_ctr_id, WorkOrderHeader.workorder_id, WorkorderDetail.resource_type, WorkorderDetail.sequence_id),
			JDE_object = dbo.fn_get_workorder_JDE_glaccount_object(WorkOrderHeader.company_id, WorkOrderHeader.profit_ctr_id, WorkOrderHeader.workorder_id, WorkorderDetail.resource_type, WorkorderDetail.sequence_id),
			b.currency_code
		FROM WorkOrderHeader
		JOIN BillingType ON BillingType.billing_type = 'WorkOrder'
		JOIN #Billing b ON WorkOrderHeader.company_id = b.company_id
			AND WorkOrderHeader.profit_ctr_ID = b.profit_ctr_id
			AND WorkOrderHeader.workorder_ID = b.receipt_id
			AND b.trans_source = 'W'
		JOIN WorkorderDetail ON WorkorderDetail.company_id = WorkOrderHeader.company_id
			AND WorkorderDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
			AND WorkorderDetail.workorder_id = WorkOrderHeader.workorder_id
			AND WorkorderDetail.resource_type = b.workorder_resource_type
			AND WorkorderDetail.billing_sequence_id = b.bill_sequence
		LEFT OUTER JOIN ResourceClass ON ResourceClass.company_id = WorkOrderDetail.company_id
			AND ResourceClass.profit_ctr_ID = WorkOrderDetail.profit_ctr_id
			AND ResourceClass.resource_type = WorkOrderDetail.resource_type
			AND ResourceClass.resource_class_code = WorkorderDetail.resource_class_code
			AND ResourceClass.bill_unit_code = WorkOrderDetail.bill_unit_code
		WHERE ISNULL(WorkorderHeader.fixed_price_flag, 'F') = 'F'
			AND WorkorderHeader.workorder_status = 'A'
			AND ISNULL(WorkorderHeader.submitted_flag, 'F') = 'F'
			AND WorkorderHeader.company_id = @company_id
			AND WorkorderHeader.profit_ctr_id = @profit_ctr_id
			AND WorkorderHeader.workorder_id = @receipt_id
			AND NOT EXISTS (SELECT 1 FROM Billing 
				WHERE WorkorderHeader.company_id = Billing.company_id
				AND WorkorderHeader.profit_ctr_id = Billing.profit_ctr_id
				AND WorkorderHeader.workorder_id = Billing.receipt_id
				--AND 1 = Billing.line_id
				--AND 1 = Billing.price_id
				AND Billing.company_id = @company_id
				AND Billing.profit_ctr_id = @profit_ctr_id
				AND Billing.receipt_id = @receipt_id
				AND Billing.trans_source = 'W')

	END
	

	-- Insert Billing Comments
	IF @receipt_count > 0 
	BEGIN
		-- Get Billing Comments 
		INSERT INTO #BillingComment(company_id, profit_ctr_id, trans_source, receipt_id, 
			receipt_status, project_code, project_name,
			comment_1, comment_2, comment_3, comment_4, comment_5,
			date_added, date_modified, added_by, modified_by, service_date)
		SELECT DISTINCT WorkorderHeader.company_id,
			WorkorderHeader.profit_ctr_id,
			'W' AS trans_source,
			WorkorderHeader.workorder_id,
			'A' AS receipt_status,
			WorkorderHeader.project_code,
			WorkorderHeader.project_name,
			ISNULL(REPLACE(WorkorderHeader.invoice_comment_1,'''', ''),'') AS invoice_comment_1,
			ISNULL(REPLACE(WorkorderHeader.invoice_comment_2,'''', ''),'') AS invoice_comment_2,
			ISNULL(REPLACE(WorkorderHeader.invoice_comment_3,'''', ''),'') AS invoice_comment_3,
			ISNULL(REPLACE(WorkorderHeader.invoice_comment_4,'''', ''),'') AS invoice_comment_4,
			ISNULL(REPLACE(WorkorderHeader.invoice_comment_5,'''', ''),'') AS invoice_comment_5,
			@submit_date AS date_added,
			@submit_date AS date_modified,
			@user_code AS added_by,
			@user_code AS modified_by,
			--coalesce(wos.date_act_arrive, WorkorderHeader.start_date)
			service_date = dbo.fn_get_service_date_no_time ( @company_id,@profit_ctr_id,@receipt_id, @trans_source  )  
		FROM WorkorderHeader
		LEFT OUTER JOIN WorkOrderStop wos (nolock) 
			ON wos.workorder_id = WorkorderHeader.workorder_id
			and wos.company_id = WorkorderHeader.company_id
			and wos.profit_ctr_id = WorkorderHeader.profit_ctr_id
			and wos.stop_sequence_id = 1 
		WHERE WorkorderHeader.company_id = @company_id
			AND WorkorderHeader.profit_ctr_id = @profit_ctr_id
			AND WorkorderHeader.workorder_id = @receipt_id
			AND WorkorderHeader.workorder_status = 'A'
			AND ISNULL(WorkorderHeader.submitted_flag,'F') = 'F'
	END
END		--This is the ELSE part of (IF @trans_source = 'R')


--------------------------------------------------------------------------------------------------------------------
-- Call out-placed surcharges code 
-- (Handles insurance surcharge, energy surcharge, and sales tax for Receipts and Work Orders)
--------------------------------------------------------------------------------------------------------------------
EXEC sp_billing_submit_calc_surcharges_billingdetail @debug
		

-------------------------------------------------------------------------------------------------------------------
-- Back-populate the insr_extended_amt and ensr_extended_amt fields in Billing for backward compatibility 
-- until we can remove these fields altogether, and just use BillingDetail.
-------------------------------------------------------------------------------------------------------------------
UPDATE #Billing 
	SET insr_extended_amt = (SELECT SUM(extended_amt) 
							FROM #BillingDetail bd 
							WHERE bd.billing_uid = #Billing.billing_uid 
							AND bd.billing_type = 'Insurance'),
		insr_percent = (SELECT MAX(applied_percent)
						FROM #BillingDetail bd 
						WHERE bd.billing_uid = #Billing.billing_uid 
						AND bd.billing_type = 'Insurance')

UPDATE #Billing 
	SET ensr_extended_amt = (SELECT SUM(extended_amt) 
							FROM #BillingDetail bd
							WHERE bd.billing_uid = #Billing.billing_uid	
							AND bd.billing_type = 'Energy'),
		ensr_percent = (SELECT MAX(applied_percent)
						FROM #BillingDetail bd 
						WHERE bd.billing_uid = #Billing.billing_uid 
						AND bd.billing_type = 'Energy')
	
	
if @update_prod = 'T' BEGIN
	--These only happen if this is an actual submit.

	-------------------------------------------------------------------------------------
	-- Check for gl accounts with "X" or "Z" in them, and don't submit if we find any
	-------------------------------------------------------------------------------------
	SET @invalid_gl_count = 0
	SET @error_value = 0

	-- 3/7/14 JDB Don't need to check for bad Epicor GL accounts any longer (don't know how this stayed in there so long without someone noticing!)
	--SELECT @invalid_gl_count = @invalid_gl_count + COUNT(*) FROM #BillingDetail WHERE (gl_account_code LIKE '%X%' OR gl_account_code LIKE '%Z%')

	-- IF JDE flags are off no need to stop Billing submit
	IF @sync_invoice_jde = 1 
	BEGIN
		SELECT @invalid_gl_count = @invalid_gl_count + COUNT(*) FROM #BillingDetail WHERE (JDE_BU LIKE '%X%' OR JDE_BU LIKE '%Z%')
		SELECT @invalid_gl_count = @invalid_gl_count + COUNT(*) FROM #BillingDetail WHERE (JDE_object LIKE '%X%' OR JDE_object LIKE '%Z%')
		
		---------------------------------------------------------------------------------------------------------------------
		-- Audit the list of GL accounts that are not set up in JDE, so that we can display an error message to the user.
		---------------------------------------------------------------------------------------------------------------------
		
		IF @trans_source = 'R'
		BEGIN
			------------------------------------
			-- First, for Receipts:
			------------------------------------	
			INSERT INTO ReceiptAudit (company_id, profit_ctr_id, receipt_id, line_id, price_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
			SELECT DISTINCT bd.company_id, bd.profit_ctr_id, bd.receipt_id, bd.line_id, bd.price_id, '', '', bd.billing_type AS before_value, bd.JDE_BU + '-' + bd.JDE_object AS after_value, 'Submit to Billing Failed.  Invalid JDE GL Account.' AS audit_reference, @user_code, 'BS SP', @submit_date
			FROM #BillingDetail bd
			WHERE 1=1
			AND bd.trans_source = 'R'
			AND 
				NOT 
				EXISTS (SELECT 1 FROM JDE.EQFinance.dbo.JDEGLAccountMaster_F0901
					WHERE (business_unit_GMMCU COLLATE SQL_Latin1_General_CP1_CI_AS) = RIGHT('            ' + bd.JDE_BU, 12)
					AND (object_account_GMOBJ COLLATE SQL_Latin1_General_CP1_CI_AS) = bd.JDE_object
					AND subsidiary_GMSUB = ''
					AND posting_edit_GMPEC IN (' ','M')
				)
			SELECT @invalid_gl_count = @invalid_gl_count + @@ROWCOUNT, @error_value = @@ERROR
		END
		ELSE 
		IF @trans_source = 'W' 
		BEGIN
			------------------------------------
			-- Then, for Work Orders:
			------------------------------------
			INSERT INTO WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
			SELECT DISTINCT bd.company_id, bd.profit_ctr_id, bd.receipt_id, b.workorder_resource_type, b.workorder_sequence_id, '', '', bd.billing_type AS before_value, bd.JDE_BU + '-' + bd.JDE_object AS after_value, 'Submit to Billing Failed.  Invalid JDE GL Account.' AS audit_reference, @user_code, @submit_date
			FROM #BillingDetail bd
			JOIN #Billing b ON b.billing_uid = bd.billing_uid
			WHERE 1=1
			AND bd.trans_source = 'W'
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
		END
		
		IF @error_value <> 0
		BEGIN		
			-- Set message for RAISEERROR and go to the end
			SET @error_msg = 'Error inserting record into Audit tables for invalid/missing JDE GL account(s).'
			GOTO END_OF_PROC
		END
	END
	IF @debug = 1 PRINT '@invalid_gl_count = ' + CONVERT(varchar(4), @invalid_gl_count)

	IF @receipt_count > 0 AND @invalid_gl_count = 0
	BEGIN
		
		-- Get the max billing_uid from Billing, then add it to the existing values in #Billing before inserting into Billing
		--SELECT @max_billing_uid = IDENT_CURRENT ('Billing')							-- Gets current identity
		--SET IDENTITY_INSERT Billing ON
		-- SUBMIT to Billing
		INSERT INTO Billing (
			--billing_uid,
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
			-- SK 02/20/13 gl_account_code, 
			-- SK 02/20/13 gl_sr_account_code, 
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
			-- SK 02/20/13 bundled_tran_gl_account_code, 
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
			--billing_uid + @max_billing_uid,
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
			-- SK 02/20/13 gl_account_code, 
			-- SK 02/20.13 gl_sr_account_code, 
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
			-- SK 02/20/13 bundled_tran_gl_account_code, 
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
		--SET IDENTITY_INSERT Billing OFF
		SELECT @error_value = @@ERROR
		
		IF @error_value <> 0
		BEGIN		
			-- Set message for RAISEERROR and go to the end
			SET @error_msg = 'Error inserting into Billing.'
			GOTO END_OF_PROC
		END
		 
		-- Get the max billingdetail_uid from BillingDetail, then add it to the existing values in #BillingDetail before inserting into BillingDetail
		--SELECT @max_billingdetail_uid = IDENT_CURRENT ('BillingDetail')
		--SET IDENTITY_INSERT BillingDetail ON
		-- SUBMIT to BillingDetail
		INSERT INTO BillingDetail (
			--billingdetail_uid,
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
			currency_code)
		SELECT 
			--billingdetail_uid + @max_billingdetail_uid,
			b.billing_uid,
			--billing_uid + @max_billing_uid,
			bd.ref_billingdetail_uid,
			--ref_billingdetail_uid + @max_billingdetail_uid,
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
			bd.currency_code
		FROM #BillingDetail bd
		JOIN Billing b ON b.company_id = bd.company_id
			AND b.profit_ctr_id = bd.profit_ctr_id
			AND b.trans_source = bd.trans_source
			AND b.receipt_id = bd.receipt_id
			AND b.line_id = bd.line_id
			AND b.price_id = bd.price_id
		--SET IDENTITY_INSERT BillingDetail OFF
		SELECT @error_value = @@ERROR, @bd_identity = @@IDENTITY, @bd_rowcount = @@ROWCOUNT
		
		IF @debug = 1
		BEGIN
			PRINT '@bd_identity = ' + CONVERT(varchar(10), @bd_identity)
			PRINT '@bd_rowcount = ' + CONVERT(varchar(10), @bd_rowcount)
		END
		
		IF @error_value <> 0
		BEGIN		
			-- Set message for RAISEERROR and go to the end
			SET @error_msg = 'Error inserting into BillingDetail.'
			GOTO END_OF_PROC
		END
		
		
		-- This UPDATE statement was failing to assign the correct ref_billingdetail_uid because the @@ROWCOUNT variable was 0 (zero) by
		-- the time it got here, even though it is correct right after the insert into the BillingDetail table.  I changed this to get
		-- the proper @@ROWCOUNT value into the @bd_rowcount local variable so that it works.  I suspect it has to do with the check
		-- of @@ERROR right above here.  11/6/2012  JDB
		--UPDATE BillingDetail SET BillingDetail.ref_billingdetail_uid = BillingDetail.ref_billingdetail_uid + - @@ROWCOUNT + @@IDENTITY
		UPDATE BillingDetail SET BillingDetail.ref_billingdetail_uid = BillingDetail.ref_billingdetail_uid - @bd_rowcount + @bd_identity
		FROM BillingDetail
		JOIN #BillingDetail temp ON temp.company_id = BillingDetail.company_id
			AND temp.profit_ctr_id = BillingDetail.profit_ctr_id
			AND temp.trans_source = BillingDetail.trans_source
			AND temp.receipt_id = BillingDetail.receipt_id
			AND temp.line_id = BillingDetail.line_id
			AND temp.price_id = BillingDetail.price_id
		SELECT @error_value = @@ERROR
		
		IF @error_value <> 0
		BEGIN		
			-- Set message for RAISEERROR and go to the end
			SET @error_msg = 'Error updating BillingDetail.ref_billingdetail_uid.'
			GOTO END_OF_PROC
		END
		
		IF @debug = 1
		BEGIN
			SELECT extended_amt, * FROM BillingDetail
			WHERE company_id = @company_id 
			AND profit_ctr_id = @profit_ctr_id
			AND receipt_id = @receipt_id
			ORDER BY billing_uid, billingdetail_uid, line_id, price_id, billing_type

			SELECT SUM(extended_amt) as sum FROM BillingDetail
			WHERE company_id = @company_id 
			AND profit_ctr_id = @profit_ctr_id
			AND receipt_id = @receipt_id
		END

		-- No Billing Comment record, just insert a new one
		IF @invoice_id IS NULL
		BEGIN
			INSERT BillingComment(
				company_id, 
				profit_ctr_id, 
				trans_source, 
				receipt_id, 
				receipt_status,
				project_code, 
				project_name,
				comment_1, comment_2, comment_3, comment_4, comment_5,
				added_by, date_added, modified_by, date_modified, service_date)
			SELECT * FROM #BillingComment
			SELECT @error_value = @@ERROR
			
			IF @error_value <> 0
			BEGIN		
				-- Set message for RAISEERROR and go to the end
				SET @error_msg = 'Error inserting into BillingComment.'
				GOTO END_OF_PROC
			END
		END
		ELSE
		BEGIN
			UPDATE BillingComment SET
				receipt_status = #BillingComment.receipt_status,
				project_code = #BillingComment.project_code, 
				project_name = #BillingComment.project_name,
				comment_1 = #BillingComment.comment_1,
				comment_2 = #BillingComment.comment_2,
				comment_3 = #BillingComment.comment_3,
				comment_4 = #BillingComment.comment_4,
				comment_5 = #BillingComment.comment_5,
				added_by = #BillingComment.added_by,
				date_added = #BillingComment.date_added,
				modified_by = #BillingComment.modified_by,
				date_modified = #BillingComment.date_modified,
				service_date = #BillingComment.service_date
			FROM BillingComment
			JOIN #BillingComment ON BillingComment.company_id = #BillingComment.company_id
			AND BillingComment.profit_ctr_id = #BillingComment.profit_ctr_id
			AND BillingComment.trans_source = #BillingComment.trans_source
			AND BillingComment.receipt_id = #BillingComment.receipt_id
			SELECT @error_value = @@ERROR
			
			IF @error_value <> 0
			BEGIN		
				-- Set message for RAISEERROR and go to the end
				SET @error_msg = 'Error updating BillingComment.'
				GOTO END_OF_PROC
			END
		END

	END

	-- Verify counts
	SELECT @billing_count = COUNT(*) FROM Billing 
		WHERE company_id = @company_id
		AND profit_ctr_id = @profit_ctr_id
		AND receipt_id = @receipt_id
		AND trans_source = @trans_source
		AND date_added = @submit_date

	IF @debug = 1 print '@receipt_count: ' + convert(varchar(10), @receipt_count) + ' @billing_count: ' + convert(varchar(10), @billing_count)

	IF @receipt_count = @billing_count
	BEGIN
		IF @trans_source = 'R'  
		BEGIN
			-- Show all receipt lines AS submitted, even if some
			-- weren't due to being Voided or no print on invoice 
			UPDATE receipt SET submitted_flag = 'T', date_submitted = @submit_date, submitted_by = @user_code
			FROM Billing 
			WHERE receipt.company_id = Billing.company_id
			AND receipt.profit_ctr_id = Billing.profit_ctr_id
			AND receipt.receipt_id = Billing.receipt_id
			AND Billing.company_id = @company_id
			AND Billing.profit_ctr_id = @profit_ctr_id
			AND Billing.trans_source = @trans_source
			AND Billing.receipt_id = @receipt_id
			AND Billing.date_added = @submit_date
			SELECT @error_value = @@ERROR
			
			IF @error_value <> 0
			BEGIN		
				-- Set message for RAISEERROR and go to the end
				SET @error_msg = 'Error updating Receipt for submitted_flag, date_submitted, submitted_by.'
				GOTO END_OF_PROC
			END

			-- Write an audit record
			INSERT ReceiptAudit (company_id, profit_ctr_id, receipt_id, line_id, price_id, 
					table_name, column_name, before_value, after_value, audit_reference, 
					modified_by, modified_from, date_modified)
			VALUES (@company_id, @profit_ctr_id, @receipt_id, 0, 0,
					'Receipt', 'submitted_flag', 'F', 'T', 'Submitted to Billing',
					@user_code, 'SB', @submit_date)
			SELECT @error_value = @@ERROR
			
			IF @error_value <> 0
			BEGIN		
				-- Set message for RAISEERROR and go to the end
				SET @error_msg = 'Error inserting ReceiptAudit record for submitted_flag update.'
				GOTO END_OF_PROC
			END

			INSERT ReceiptAudit (company_id, profit_ctr_id, receipt_id, line_id, price_id, 
					table_name, column_name, before_value, after_value, audit_reference, 
					modified_by, modified_from, date_modified)
			VALUES (@company_id, @profit_ctr_id, @receipt_id, 0, 0,
					'Receipt', 'date_submitted', '(blank)', CONVERT(varchar, @submit_date,109), 'Submitted to Billing',
					@user_code, 'SB', @submit_date)
			SELECT @error_value = @@ERROR
			
			IF @error_value <> 0
			BEGIN		
				-- Set message for RAISEERROR and go to the end
				SET @error_msg = 'Error inserting ReceiptAudit record for date_submitted update.'
				GOTO END_OF_PROC
			END

			INSERT ReceiptAudit (company_id, profit_ctr_id, receipt_id, line_id, price_id, 
					table_name, column_name, before_value, after_value, audit_reference, 
					modified_by, modified_from, date_modified)
			VALUES (@company_id, @profit_ctr_id, @receipt_id, 0, 0,
					'Receipt', 'submitted_by', '(blank)', @user_code, 'Submitted to Billing',
					@user_code, 'SB', @submit_date)
			SELECT @error_value = @@ERROR
			
			IF @error_value <> 0
			BEGIN		
				-- Set message for RAISEERROR and go to the end
				SET @error_msg = 'Error inserting ReceiptAudit record for submitted_by update.'
				GOTO END_OF_PROC
			END


		END		--IF @trans_source = 'R'  
		
		ELSE
		IF @trans_source = 'W' 
		BEGIN
			UPDATE WorkOrderHeader 
				SET submitted_flag = 'T',
				date_submitted = @submit_date, 
				submitted_by = @user_code,
				problem_id = CASE WHEN problem_id = 15 THEN NULL ELSE problem_id END
			FROM Billing
			WHERE WorkorderHeader.company_id = Billing.company_id
			AND WorkOrderHeader.profit_ctr_id = Billing.profit_ctr_id
			AND WorkOrderHeader.workorder_id = Billing.receipt_id
			AND Billing.company_id = @company_id
			AND Billing.profit_ctr_id = @profit_ctr_id
			AND Billing.trans_source = @trans_source
			AND Billing.receipt_id = @receipt_id
			AND Billing.date_added = @submit_date
			SELECT @error_value = @@ERROR
			
			IF @error_value <> 0
			BEGIN		
				-- Set message for RAISEERROR and go to the end
				SET @error_msg = 'Error updating WorkOrderHeader for submitted_flag, date_submitted, submitted_by.'
				GOTO END_OF_PROC
			END

			-- Write an audit record
			INSERT WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, 
					table_name, column_name, before_value, after_value, audit_reference, 
					modified_by, date_modified)
			VALUES (@company_id, @profit_ctr_id, @receipt_id, '', 0,
					'WorkOrderHeader', 'submitted_flag', 'F', 'T', 'Submitted to Billing',
					@user_code, @submit_date)
			SELECT @error_value = @@ERROR
			
			IF @error_value <> 0
			BEGIN		
				-- Set message for RAISEERROR and go to the end
				SET @error_msg = 'Error inserting WorkOrderAudit record for submitted_flag update.'
				GOTO END_OF_PROC
			END

			INSERT WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, 
					table_name, column_name, before_value, after_value, audit_reference, 
					modified_by, date_modified)
			VALUES (@company_id, @profit_ctr_id, @receipt_id, '', 0,
					'WorkOrderHeader', 'date_submitted', '(blank)', CONVERT(varchar, @submit_date,109), 'Submitted to Billing',
					@user_code, @submit_date)
			SELECT @error_value = @@ERROR
			
			IF @error_value <> 0
			BEGIN		
				-- Set message for RAISEERROR and go to the end
				SET @error_msg = 'Error inserting WorkOrderAudit record for date_submitted update.'
				GOTO END_OF_PROC
			END

			INSERT WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, 
					table_name, column_name, before_value, after_value, audit_reference, 
					modified_by, date_modified)
			VALUES (@company_id, @profit_ctr_id, @receipt_id, '', 0,
					'WorkOrderHeader', 'submitted_by', '(blank)', @user_code, 'Submitted to Billing',
					@user_code, @submit_date)
			SELECT @error_value = @@ERROR
			
			IF @error_value <> 0
			BEGIN		
				-- Set message for RAISEERROR and go to the end
				SET @error_msg = 'Error inserting WorkOrderAudit record for submitted_by update.'
				GOTO END_OF_PROC
			END
		END		--IF @trans_source = 'W' 
	END		--IF @receipt_count = @billing_count

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

END -- if @update_prod = 'T'


IF @update_prod = 'T' BEGIN

	-- We still need to write the audit to indicate there were invalid JDE GL accounts, so do that now:
	IF @error_value <> 0 AND @sync_invoice_jde = 1 AND @invalid_gl_count > 0
	BEGIN
		------------------------------------
		-- First, for Receipts:
		------------------------------------	
		IF @trans_source = 'R'
		BEGIN
			INSERT INTO ReceiptAudit (company_id, profit_ctr_id, receipt_id, line_id, price_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, modified_from, date_modified)
			SELECT DISTINCT bd.company_id, bd.profit_ctr_id, bd.receipt_id, bd.line_id, bd.price_id, '', '', bd.billing_type AS before_value, bd.JDE_BU + '-' + bd.JDE_object AS after_value, 'Submit to Billing Failed.  Invalid JDE GL Account.' AS audit_reference, @user_code, 'BS SP', @submit_date
			--INTO #ReceiptAudit
			FROM #BillingDetail bd
			WHERE 1=1
			AND bd.trans_source = 'R'
			AND 
				NOT 
				EXISTS (SELECT 1 FROM JDE.EQFinance.dbo.JDEGLAccountMaster_F0901
					WHERE (business_unit_GMMCU COLLATE SQL_Latin1_General_CP1_CI_AS) = RIGHT('            ' + bd.JDE_BU, 12)
					AND (object_account_GMOBJ COLLATE SQL_Latin1_General_CP1_CI_AS) = bd.JDE_object
					AND subsidiary_GMSUB = ''
					AND posting_edit_GMPEC IN (' ','M')
				)
			SELECT @invalid_gl_count = @invalid_gl_count + @@ROWCOUNT, @error_value = @@ERROR
		END
		ELSE 
		IF @trans_source = 'W' 
		BEGIN
			------------------------------------
			-- Then, for Work Orders:
			------------------------------------
			INSERT INTO WorkOrderAudit (company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, table_name, column_name, before_value, after_value, audit_reference, modified_by, date_modified)
			SELECT DISTINCT bd.company_id, bd.profit_ctr_id, bd.receipt_id, b.workorder_resource_type, b.workorder_sequence_id, '', '', bd.billing_type AS before_value, bd.JDE_BU + '-' + bd.JDE_object AS after_value, 'Submit to Billing Failed.  Invalid JDE GL Account.' AS audit_reference, @user_code, @submit_date
			FROM #BillingDetail bd
			JOIN #Billing b ON b.billing_uid = bd.billing_uid
			WHERE 1=1
			AND bd.trans_source = 'W'
			AND 
				NOT 
				EXISTS (SELECT 1 FROM JDE.EQFinance.dbo.JDEGLAccountMaster_F0901
					WHERE (business_unit_GMMCU COLLATE SQL_Latin1_General_CP1_CI_AS) = RIGHT('            ' + bd.JDE_BU, 12)
					AND (object_account_GMOBJ COLLATE SQL_Latin1_General_CP1_CI_AS) = bd.JDE_object
					AND subsidiary_GMSUB = ''
					AND posting_edit_GMPEC IN (' ','M')
				)
			SELECT @invalid_gl_count = @invalid_gl_count + @@ROWCOUNT, @error_value = @@ERROR
		END
	END
END -- if @update_prod = 'T'

RETURN ISNULL(@error_value, 0)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_submit_calc] TO [EQWEB];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_submit_calc] TO [COR_USER];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_submit_calc] TO [EQAI];

GO

