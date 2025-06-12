drop PROCEDURE if exists sp_billing_submit_calc_receipt_charges
go
CREATE PROCEDURE sp_billing_submit_calc_receipt_charges (
	@debug	int = 0
)
AS
/* ***********************************************************************************
sp_billing_submit_calc_receipt_charges
	- Encapsulates sp_billing_submit's handling of all BillingDetail records for receipts.
	- Split into a separate sp so it can run for both sp_billing_submit AND sp_rpt_flash_calc

ASSUMES:
	- Whatever called it created a #Billing table so this proc knows what to work on.	
	- Whatever called it created a #BillingDetail table for this proc to modify/add rows.
	
History:	
02/02/2012 JPB	Created
02/02/2012 JDB	Fixed typo in join in the Bundled section that was using profile_id twice instead of using profit_ctr_id.
02/03/2012 JDB	Added DISTINCT to the c_billing cursor in the Bundled section so that receipts using the same profile
				on multiple lines would not get the bundled pricing applied multiple times.
02/03/2012 JPB	Renamed to sp_billing_submit_calc_receipt_charges, brought
				in more of the receipt side from sp_billing_submit, worked on speeeeed.
02/07/2012 JDB	Modified the way that we store the BillingDetail information for unbundled products.
				We are going to allow users to select an unbundled product from a company/profit center 
				that doesn't match the approval's company/profit center.  For instance, an approval into
				03-00 WDI may have an unbundled product from 03-03 WDI Rail.  We need to store the product's
				company and profit center in the dist_company_id and dist_profit_ctr_id fields, just like we
				do for bundled products.
02/14/2012 JDB	Fixed typo in the Energy Surcharge section (it was using Insurance Surcharge information for 
				distribution company and profit center.)
03/16/2012 JDB	Added support for new identity columns on Billing and BillingDetail tables.
02/01/2013 JDB	Modified the code that gets the GL account for bundled products.  If there are X's in their GL accounts,
				we need to take the appropriate account information from the line it's bundled with.  Prior to this change,
				receipts with bundled products that had X's in their GL accounts would fail to submit. (This only came up
				because of the ability to bundle the new Wayne Host Community Agreement (WHCA) fees.  For all companies
				except for 03-WDI, they have X's in their GL accounts.)
02/20/2013 SK	Modified - gl_sr_account_code will no longer be stored in the Billing table. It belongs here in the Billingdetail as a seperate
				row here. So the logic from Billing.gl_sr_account_code moved to Billingdetail.gl_account_code for Surcharge
				Added new JDE_BU & JDE_object fields to all Inserts to BillingDetail
02/28/2013 JDB	Added the population of the new billingtype_uid field in BillingDetail.
04/22/2013 JDB	Updated the procedure to get the correct JDE business unit when the length of the business unit is only
				4 digits (like it is for the balance sheet accounts like taxes/fees).
06/05/2017 MPM	Modified to work with new disc_amount column in the BillingDetail table.
07/14/2017 JPB	Added explicit #BillingDetail column lists for inserts
02/15/2018 MPM	Added population of #BillingDetail.currency_code.
05/08/2018 RJB  Add logic supporting Bundled Tax Code and using only one tax code applicable product that best matches
07/09/2018 MPM	Added logic for e-Manifest overage charges.
08/07/2019 AM   devops:11519 - Added new received_rail_flag logic to AX_Dimension_3
11/07/2024 KS	Rally DE36149 - Handled NULL values for AX_Dimension_3 logic

12/29/2022 JPB  TODO:
					These fields are likely deprecated, don't need to spend time
					populating them - maybe just comment out their function calls
					and return NULL instead (it would save time):
						gl_account_code
						JDE_BU
						JDE_object
*********************************************************************************** */

-- Define variables used herein...
DECLARE	
	@bund_company_id	int,
	@bund_profit_ctr_id	int,
	@bund_receipt_id	int,
	@bund_line_id		int,
	@bund_price_id		int,
	@bund_trans_source	char(1),
	@bund_billingtype_uid	int,
	@bund_billing_type	varchar(10),
	@bund_product_id	int,
	@bund_dist_company_id	int,
	@bund_dist_profit_ctr_id	int,
	@bund_gl_account_code	varchar(32),
	@bund_jde_bu		varchar(7),
	@bund_jde_object	varchar(5),
	@bund_sequence_id	int,
	@bund_quote_sequence_id	int,
	@extended_amt		float,
	@ref_extended_amt	float,
	-- rb for bundled cursors
	@b_receipt_id int,
	@b_line_id int,
	@b_price_id int,
	@b_profile_id int,
	@b_company_id smallint,
	@b_profit_ctr_id smallint,
	@b_sequence_id int,
	@b_hauler varchar(15),
	@b_gen_site_type_id int,
	@pqdsg_price_group_id int,
	@pqdsg_transporter_code varchar(15),
	@pqdsg_gen_site_type_id int,
	@billing_uid int,
	@billingdetail_uid int,
    @AX_MainAccount varchar(20),
	@AX_Dimension_1 varchar(20),
	@AX_Dimension_2 varchar(20),
	@AX_Dimension_3 varchar(20),
	@AX_Dimension_4 varchar(20),
	@AX_Dimension_5_part_1 varchar(20),
	@AX_Dimension_5_part_2 varchar(9),
	@AX_Dimension_6 varchar(20),
	@currency_code char(3),
	@product_id int,
	@overage_amt float,
	@company_id int,
	@profit_ctr_id int,
	@receipt_id int,
	@emanifest_submission_type_uid	int,
	@manifest varchar(15),
	@return_value int,
	@line_id int

-- Create work tables used herein...
DECLARE @tmp_bundled TABLE (
	company_id smallint not null,
	profit_ctr_id smallint not null,
	receipt_id int null,
	line_id int null,
	price_id int null,
	trans_source char(1) null,
	billingtype_uid	int null,
	billing_type varchar(10) null,
	profile_id int null,
	approval_code varchar(15) null,
	quote_sequence_id int null,
	waste_extended_amt money null,
	quantity float null,
	line_total_amt money null,
	sequence_id int null,
	record_type char(1),
	bill_method char(1) null,
	bill_quantity_flag char(1) null,
	price float null,
	dist_percent tinyint null,
	dist_company_id int null,
	dist_profit_ctr_id int null,
	product_id int null,
	gl_account_code varchar(32) null,
	jde_bu	varchar(7) null,
	jde_object varchar(5) null,
	extended_amt money null,
	processed_flag int null,
	AX_MainAccount varchar(20) null,
	AX_Dimension_1 varchar(20) null,
	AX_Dimension_2 varchar(20) null,
	AX_Dimension_3 varchar(20) null,
	AX_Dimension_4 varchar(20) null,
	AX_Dimension_5_part_1 varchar(20) null,
	AX_Dimension_5_part_2 varchar(9) null,
	AX_Dimension_6 varchar(20) null,
	currency_code char(3) null
)
-- Here begins the code copied from sp_billing_submit...
-----------------------------------------------------
---- Regular disposal
-----------------------------------------------------
		INSERT INTO #BillingDetail
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
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
		SELECT b.billing_uid,
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
			NULL AS product_id, 
			b.company_id AS dist_company_id,
			b.profit_ctr_id AS dist_profit_ctr_id,
			NULL AS sales_tax_id,
			NULL AS applied_percent,
			b.waste_extended_amt,
			-- SK 02/20 b.gl_account_code,
			dbo.fn_get_receipt_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id) AS gl_account_code,
			b.quote_sequence_id,
			dbo.fn_get_receipt_JDE_glaccount_business_unit(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id) AS JDE_BU,
			dbo.fn_get_receipt_JDE_glaccount_object(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id) AS JDE_object,
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'MAIN') AS AX_MainAccount,
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM1') AS AX_Dimension_1, 
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM2') AS AX_Dimension_2,  
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM3') AS AX_Dimension_3,  
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM4') AS AX_Dimension_4,
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM5') AS AX_Dimension_5_part_1,
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DI52') AS AX_Dimension_5_part_2,
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM6') AS AX_Dimension_6,
			NULL AS AX_Project_Required_Flag,
			NULL AS disc_amount,
			b.currency_code
		FROM #Billing b
		JOIN BillingType bt ON bt.billing_type = 'Disposal'
		WHERE 1=1 
		AND b.trans_source = 'R'
		AND b.trans_type = 'D'

		--AND b.waste_extended_amt > 0		-- We want to enter a record, even if $0


		-----------------------------------------------------
		---- Wash
		-----------------------------------------------------
		INSERT INTO #BillingDetail
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
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)		
		SELECT b.billing_uid,
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
			NULL AS product_id, 
			b.company_id AS dist_company_id,
			b.profit_ctr_id AS dist_profit_ctr_id,
			NULL AS sales_tax_id,
			NULL AS applied_percent,
			b.waste_extended_amt,
			-- SK 02/20 b.gl_account_code,
			dbo.fn_get_receipt_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id) AS gl_account_code,
			b.quote_sequence_id,
			dbo.fn_get_receipt_JDE_glaccount_business_unit(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id) AS JDE_BU,
			dbo.fn_get_receipt_JDE_glaccount_object(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id) AS JDE_object,
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'MAIN') AS AX_MainAccount,
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM1') AS AX_Dimension_1, 
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM2') AS AX_Dimension_2,  
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM3') AS AX_Dimension_3,  
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM4') AS AX_Dimension_4,
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM5') AS AX_Dimension_5_part_1,
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DI52') AS AX_Dimension_5_part_2,
			dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM6') AS AX_Dimension_6,
			Null AS AX_Project_Required_Flag,
			NULL AS disc_amount,
			b.currency_code
		FROM #Billing b
		JOIN BillingType bt ON bt.billing_type = 'Wash'
		WHERE 1=1 
		AND b.trans_source = 'R'
		AND b.trans_type = 'W'
		--AND b.waste_extended_amt > 0		-- We want to enter a record, even if $0


		-----------------------------------------------------
		---- Product line (Service, Transportation)
		-----------------------------------------------------
		INSERT INTO #BillingDetail
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
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
		SELECT b.billing_uid,
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
			COALESCE(p.company_id, b.company_id) AS dist_company_id,
			COALESCE(p.profit_ctr_id, b.profit_ctr_id) AS dist_profit_ctr_id,
			NULL AS sales_tax_id,
			NULL AS applied_percent,
			b.waste_extended_amt,
			-- SK 02/20 b.gl_account_code,
			dbo.fn_get_receipt_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id) AS gl_account_code,
			b.quote_sequence_id,
			dbo.fn_get_receipt_JDE_glaccount_business_unit(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id) AS JDE_BU,
			dbo.fn_get_receipt_JDE_glaccount_object(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id) AS JDE_object,
			--CASE LEN(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id))
			--	WHEN  9 THEN LEFT(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 4)
			--	WHEN 12 THEN LEFT(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 7) 
			--	END AS JDE_BU,
			--CASE LEN(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id))
			--	WHEN  9 THEN RIGHT(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 5)
			--	WHEN 12 THEN RIGHT(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 5)
			--	END AS JDE_object
			--LEFT(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 7) AS jde_bu,
			--RIGHT(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 5) AS jde_object
			AX_MainAccount =  REPLACE( p.AX_MainAccount,'XXXXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'MAIN') ),
			AX_Dimension_1 =  REPLACE( p.AX_Dimension_1,'XXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM1')),
			AX_Dimension_2 =  REPLACE( p.AX_Dimension_2,'XXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM2')),  
			--AX_Dimension_3 =  REPLACE( p.AX_Dimension_3,'XXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM3')),   
			AX_Dimension_3 =  IsNull( case when patindex('%PPP%', p.AX_Dimension_3) > 0 
                  then  REPLACE ( p.AX_Dimension_3,'PPP', case IsNull(( Select r.received_rail_flag from Receipt r where b.company_id = r.company_id 
                    and  b.profit_ctr_id = r.profit_ctr_id and b.receipt_id = r.receipt_id and r.line_id = b.line_id  ), 'F') when 'T'
                       then IsNull(( select ProfitCenter.default_rail_ax_dept from ProfitCenter 
                            where b.company_id = ProfitCenter.company_id and ProfitCenter.profit_ctr_ID = b.profit_ctr_id ), 'PPP')
                        else 
                         IsNull(( select ProfitCenter.default_highway_ax_dept from ProfitCenter 
                         where b.company_id = ProfitCenter.company_id and ProfitCenter.profit_ctr_ID = b.profit_ctr_id ), 'PPP')
                        end 
                                 )
                      when patindex('%XXX%', p.AX_Dimension_3) > 0 -- same we do for the string 'XXX'
                       then REPLACE ( p.AX_Dimension_3,'XXX',
                        REPLACE( dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM3'), 'PPP',  
                       case IsNull((  Select r.received_rail_flag from Receipt r where b.company_id = r.company_id 
                        and  b.profit_ctr_id = r.profit_ctr_id and b.receipt_id = r.receipt_id and r.line_id = b.line_id  ), 'F') when 'T'
                           then IsNull(( select ProfitCenter.default_rail_ax_dept from ProfitCenter 
                           where b.company_id = ProfitCenter.company_id and ProfitCenter.profit_ctr_ID = b.profit_ctr_id ), 'PPP')
                            else 
                         IsNull(( select ProfitCenter.default_highway_ax_dept from ProfitCenter 
                        where b.company_id = ProfitCenter.company_id and ProfitCenter.profit_ctr_ID = b.profit_ctr_id ), 'PPP')
                          end 
                      ) 
                    )
               else p.AX_Dimension_3 
               end  ,'')  ,
		    AX_Dimension_4 =  REPLACE( p.AX_Dimension_4,'XXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM4')), 
			AX_Dimension_5_part_1 = REPLACE( p.AX_Dimension_5_part_1,'XXXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM5')), 
			AX_Dimension_5_part_2 = REPLACE( p.AX_Dimension_5_part_2,'XXXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DI52')), 
			AX_Dimension_6 = REPLACE( p.AX_Dimension_6,'XXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM6')),
			Null AS AX_Project_Required_Flag,
			NULL AS disc_amount,
			b.currency_code
		FROM #Billing b
		JOIN BillingType bt ON bt.billing_type = 'Product'
		JOIN Product p (nolock)
			ON p.product_ID = b.product_id
		WHERE 1=1 
		AND b.trans_source = 'R'
		AND b.trans_type IN ('S', 'T')
		--AND b.waste_extended_amt > 0		-- We want to enter a record, even if $0

		/**********************************************************************************************************************************************************
		
		MPM - If the receipt has a line item for the "e-Manifest Submission Fee" product code (i.e., if @emanifest_submission_type_uid > 0):
		1.If the price on the main product code = federal charge (i.e., the call to fn_tbl_receipt_emanifest_fee below returns 0), 
			donÆt bundle anything (no extra programming steps). Just insert the product code into Billing, as normal.
		2.If the price on the main product code > federal charge (i.e., the call to fn_tbl_receipt_emanifest_fee below returns > 0), 
			bundle in the e-Manifest Overage charge in the amount of the difference.
			1.Example 1: If the "e-Manifest Submission Fee" is set to $10, the $10 should be separated into two BillingDetail entries. One for the "e-Manifest 
				Submission Fee" at $6.50 and one for the "e-Manifest Overage" at $3.50.
			2.Example 2: If the "e-Manifest Submission Fee" is set to $15, the $15 should be separated into two BillingDetail entries. One for the "e-Manifest 
				Submission Fee" at $6.50 and one for the "e-Manifest Overage" at $8.50.

		**********************************************************************************************************************************************************/
		
		-- Get receipt info
		select top 1 @company_id = company_id, @profit_ctr_id = profit_ctr_id, @receipt_id = receipt_id, @manifest = manifest 
		from #Billing
		
		if @debug = 1
			print '@company_id = ' + CAST(@company_id as varchar(2)) + ', @profit_ctr_id = ' + CAST(@profit_ctr_id as varchar(2)) + ', @receipt_id = ' + CAST(@receipt_id as varchar(10)) + ', @manifest = ' + @manifest
		
		-- Get the emanifest submission type
		SELECT @emanifest_submission_type_uid = dbo.fn_IsEmanifestRequired(@company_id, @profit_ctr_id, 'receipt', @receipt_id, @manifest)
		
		IF @emanifest_submission_type_uid > 0
		BEGIN
			-- e-manifest is required
			-- Get product ID, product code and overage amount
			select @return_value = return_value, @product_id = product_id, @overage_amt = amount
			from dbo.fn_tbl_receipt_emanifest_fee(@company_id, @profit_ctr_id, @receipt_id, 'T', @emanifest_submission_type_uid)

			if @debug = 1
				select '@return_value = ' + cast(@return_value as varchar(2)) + ', @emanifest_submission_type_uid = ' + CAST(@emanifest_submission_type_uid as varchar(3)) 
			
			if @return_value > 0
			begin
				-- This means that we have an overage amount, product id and product code, so we need to insert a row with these values into #BillingDetail. 
				-- We also need to subtract out the overage amount from the extended amount in the row in the #BillingDetail table that was inserted as a service line
				-- for the e-manifest submission fee.
				
				select @line_id = line_id
				from #billingdetail
				where company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				and receipt_id = @receipt_id
				and product_id in (select product_id 
				                     from Product 
				                    where company_id = @company_id
									  and profit_ctr_id = @profit_ctr_id
									  and product_type = 'X' 
				                      and emanifest_submission_type_uid = @emanifest_submission_type_uid)
				
				if @debug = 1
					select '@line_id = ' + cast(@line_id as varchar(3)) 

				update #billingdetail
				set extended_amt = extended_amt - @overage_amt
				where trans_type = 'S'
				and company_id = @company_id
				and profit_ctr_id = @profit_ctr_id
				and receipt_id = @receipt_id
				and line_id = @line_id
				
				INSERT INTO #BillingDetail
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
					AX_MainAccount		,
					AX_Dimension_1		,
					AX_Dimension_2		,
					AX_Dimension_3		,
					AX_Dimension_4		,
					AX_Dimension_5_Part_1		,
					AX_Dimension_5_Part_2		,
					AX_Dimension_6		,
					AX_Project_Required_Flag ,
					disc_amount,
					currency_code
				)
						SELECT b.billing_uid,
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
							@product_id, 
							COALESCE(p.company_id, b.company_id) AS dist_company_id,
							COALESCE(p.profit_ctr_id, b.profit_ctr_id) AS dist_profit_ctr_id,
							NULL AS sales_tax_id,
							NULL AS applied_percent,
							@overage_amt,
							-- SK 02/20 b.gl_account_code,
							dbo.fn_get_receipt_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id) AS gl_account_code,
							b.quote_sequence_id,
							dbo.fn_get_receipt_JDE_glaccount_business_unit(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id) AS JDE_BU,
							dbo.fn_get_receipt_JDE_glaccount_object(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id) AS JDE_object,
							--CASE LEN(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id))
							--	WHEN  9 THEN LEFT(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 4)
							--	WHEN 12 THEN LEFT(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 7) 
							--	END AS JDE_BU,
							--CASE LEN(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id))
							--	WHEN  9 THEN RIGHT(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 5)
							--	WHEN 12 THEN RIGHT(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 5)
							--	END AS JDE_object
							--LEFT(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 7) AS jde_bu,
							--RIGHT(dbo.fn_get_receipt_JDE_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 5) AS jde_object
							AX_MainAccount = REPLACE( p.AX_MainAccount,'XXXXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'MAIN') ),
							AX_Dimension_1 = REPLACE( p.AX_Dimension_1,'XXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM1')),
							AX_Dimension_2 = REPLACE( p.AX_Dimension_2,'XXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM2')),  
							AX_Dimension_3 = REPLACE( p.AX_Dimension_3,'XXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM3')),   
							AX_Dimension_4 = REPLACE( p.AX_Dimension_4,'XXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM4')), 
							AX_Dimension_5_part_1 = REPLACE( p.AX_Dimension_5_part_1,'XXXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM5')), 
							AX_Dimension_5_part_2 = REPLACE( p.AX_Dimension_5_part_2,'XXXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DI52')), 
							AX_Dimension_6 = REPLACE( p.AX_Dimension_6,'XXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM6')),
							Null AS AX_Project_Required_Flag,
							NULL AS disc_amount,
							b.currency_code
						FROM #Billing b
						JOIN BillingType bt ON bt.billing_type = 'Product'
						JOIN Product p (nolock)
							ON p.product_ID = @product_id
						WHERE 1=1 
						and b.company_id = @company_id
						and b.profit_ctr_id = @profit_ctr_id
						and b.receipt_id = @receipt_id
						and b.line_id = @line_id
						AND b.trans_source = 'R'
						AND b.trans_type = 'S'
							
				if @debug = 1
					select * from #billingdetail
								
			end
			
		END
		
		-----------------------------------------------------
		---- MI State Haz Surcharge
		-----------------------------------------------------
		INSERT INTO #BillingDetail
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
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
		SELECT b.billing_uid,
			bd.billingdetail_uid AS ref_billingdetail_uid,
			bt.billingtype_uid,
			bt.billing_type,
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
			b.sr_extended_amt,
			-- SK 02/20 b.gl_sr_account_code,
			ISNULL((SELECT REPLACE(gl_account_code,'XXX',RIGHT(dbo.fn_get_receipt_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 3))
							FROM Product
							WHERE product_code = 'MITAXHAZ'
							AND product_type = 'X' 
							AND status = 'A' 
							AND company_id = b.company_id 
							AND profit_ctr_id = b.profit_ctr_id), 'XXXXXXXXXXXX') 
			AS gl_account_code,
			NULL AS sequence_id,
			
			ISNULL((SELECT REPLACE(JDE_BU, 'XXX', RIGHT(dbo.fn_get_receipt_JDE_glaccount_business_unit(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 3))
							FROM Product
							WHERE product_code = 'MITAXHAZ'
							AND product_type = 'X' 
							AND status = 'A' 
							AND company_id = b.company_id 
							AND profit_ctr_id = b.profit_ctr_id), 'XXXXXXX') 
			AS JDE_BU,
			
			ISNULL((SELECT REPLACE(JDE_object, 'XXXXX', dbo.fn_get_receipt_JDE_glaccount_object(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id))
							FROM Product
							WHERE product_code = 'MITAXHAZ'
							AND product_type = 'X' 
							AND status = 'A' 
							AND company_id = b.company_id 
							AND profit_ctr_id = b.profit_ctr_id), 'XXXXX') 
			AS JDE_object,
		   ( SELECT REPLACE (AX_MainAccount,'XXXXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'MAIN') )
			   FROM Product
			   WHERE product_code = 'MITAXHAZ'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id)  AS AX_MainAccount,
		   ( SELECT REPLACE (AX_Dimension_1,'XXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM1') ) 
			   FROM Product
			   WHERE product_code = 'MITAXHAZ'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id) AS AX_Dimension_1,
		  ( SELECT REPLACE (AX_Dimension_2,'XXXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM2') ) 
			   FROM Product
			   WHERE product_code = 'MITAXHAZ'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id) AS AX_Dimension_2,
		  ( SELECT REPLACE (AX_Dimension_3,'XXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM3') ) 
			   FROM Product
			   WHERE product_code = 'MITAXHAZ'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id) AS AX_Dimension_3,
		  ( SELECT REPLACE (AX_Dimension_4,'XXXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM4') ) 
			   FROM Product
			   WHERE product_code = 'MITAXHAZ'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id) AS AX_Dimension_4,
		 ( SELECT REPLACE (AX_Dimension_5_Part_1,'XXXXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM5') ) 
			   FROM Product
			   WHERE product_code = 'MITAXHAZ'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id) AS AX_Dimension_5_part_1,
		( SELECT REPLACE (AX_Dimension_5_Part_2,'XXXXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DI52') ) 
			   FROM Product
			   WHERE product_code = 'MITAXHAZ'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id) AS AX_Dimension_5_part_2,
		( SELECT REPLACE (AX_Dimension_6,'XXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM6') )
			   FROM Product
			   WHERE product_code = 'MITAXHAZ'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id) AS AX_Dimension_6,
			Null AS AX_Project_Required_Flag,
			NULL AS disc_amount,
			b.currency_code   
		FROM #Billing b
		JOIN BillingType bt ON bt.billing_type = 'State-Haz'
		JOIN #BillingDetail bd ON bd.billing_uid = b.billing_uid	-- We can join on billing_uid now
			AND bd.billing_type = 'Disposal'						-- State-Haz only (and always) applies to the disposal line
		WHERE 1=1 
		AND b.trans_source = 'R'
		AND b.trans_type = 'D'
		AND b.sr_extended_amt > 0
		AND b.sr_type_code = 'H'

		-----------------------------------------------------
		---- MI State Perp Care Surcharge
		-----------------------------------------------------
		INSERT INTO #BillingDetail
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
	AX_MainAccount		,
	AX_Dimension_1		,
	AX_Dimension_2		,
	AX_Dimension_3		,
	AX_Dimension_4		,
	AX_Dimension_5_Part_1		,
	AX_Dimension_5_Part_2		,
	AX_Dimension_6		,
	AX_Project_Required_Flag ,
	disc_amount,
	currency_code
)
		SELECT b.billing_uid,
			bd.billingdetail_uid AS ref_billingdetail_uid,
			bt.billingtype_uid,
			bt.billing_type,
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
			b.sr_extended_amt,
			-- SK 02/20 b.gl_sr_account_code,
			ISNULL((SELECT REPLACE(gl_account_code,'XXX',RIGHT(dbo.fn_get_receipt_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 3))
							FROM Product
							WHERE product_code = 'MITAXPERP'
							AND product_type = 'X' 
							AND status = 'A' 
							AND company_id = b.company_id 
							AND profit_ctr_id = b.profit_ctr_id), 'XXXXXXXXXXXX') 
			AS gl_account_code,
			NULL AS sequence_id,
			
			ISNULL((SELECT REPLACE(JDE_BU, 'XXX', RIGHT(dbo.fn_get_receipt_JDE_glaccount_business_unit(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 3))
							FROM Product
							WHERE product_code = 'MITAXPERP'
							AND product_type = 'X' 
							AND status = 'A' 
							AND company_id = b.company_id 
							AND profit_ctr_id = b.profit_ctr_id), 'XXXXXXX') 
			AS JDE_BU,
			
			ISNULL((SELECT REPLACE(JDE_object, 'XXXXX', dbo.fn_get_receipt_JDE_glaccount_object(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id))
							FROM Product
							WHERE product_code = 'MITAXPERP'
							AND product_type = 'X' 
							AND status = 'A' 
							AND company_id = b.company_id 
							AND profit_ctr_id = b.profit_ctr_id), 'XXXXX') 
			AS JDE_object,
		  	   ( SELECT REPLACE (AX_MainAccount,'XXXXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'MAIN') )
			   FROM Product
			   WHERE product_code = 'MITAXPERP'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id ) AS AX_MainAccount,
		   ( SELECT REPLACE ( AX_Dimension_1 ,'XXX',dbo.fn_get_receipt_AX_gl_account (b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM1'))
			   FROM Product
			   WHERE product_code = 'MITAXPERP'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id)  AS AX_Dimension_1,
			( SELECT REPLACE (AX_Dimension_2,'XXXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM2'))
			   FROM Product
			   WHERE product_code = 'MITAXPERP'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id)  AS AX_Dimension_2,
			( SELECT REPLACE (AX_Dimension_3,'XXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM3'))
			   FROM Product
			   WHERE product_code = 'MITAXPERP'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id)  AS AX_Dimension_3,
			( SELECT REPLACE (AX_Dimension_4,'XXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM4'))
			   FROM Product
			   WHERE product_code = 'MITAXPERP'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id)  AS AX_Dimension_4,
			( SELECT REPLACE (AX_Dimension_5_part_1, 'XXXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM5'))
			   FROM Product
			   WHERE product_code = 'MITAXPERP'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id) AS AX_Dimension_5_part_1,
			( SELECT REPLACE (AX_Dimension_5_part_2,'XXXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DI52'))
			   FROM Product
			   WHERE product_code = 'MITAXPERP'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id)  AS AX_Dimension_5_part_2,
			( SELECT REPLACE (AX_Dimension_6, 'XXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM6'))
			   FROM Product
			   WHERE product_code = 'MITAXPERP'
			   AND product_type = 'X' 
			   AND status = 'A' 
			   AND company_id = b.company_id  
			   AND profit_ctr_id =  b.profit_ctr_id)  AS AX_Dimension_6,
			Null AS AX_Project_Required_Flag,
			NULL AS disc_amount,
			b.currency_code   	
		FROM #Billing b
		JOIN BillingType bt ON bt.billing_type = 'State-Perp'
		JOIN #BillingDetail bd ON bd.billing_uid = b.billing_uid	-- We can join on billing_uid now
			AND bd.billing_type = 'Disposal'						-- State-Haz only (and always) applies to the disposal line
		WHERE 1=1 
		AND b.trans_source = 'R'
		AND b.trans_type = 'D'
		AND b.sr_extended_amt > 0
		AND b.sr_type_code = 'P'

		-----------------------------------------------------
		---- Bundled charges 
		-----------------------------------------------------
		-- Get all bundled price records that apply to billing lines in this submit procedure
		-- rb Split Groups - loop through in order to find first match on transporter/generator site type
		DECLARE c_billing CURSOR FOR
		SELECT DISTINCT 
			b.receipt_id,
			b.line_id,
			b.price_id,
			b.profile_id, 
			b.company_id, 
			b.profit_ctr_id, 
			b.quote_sequence_id, 
			-- 1/24/12 JDB Replaced this from just getting the hauler from the Billing line, to getting the first transporter from the ReceiptTransporter table
			--isnull(b.hauler,'NONE'), 
			COALESCE((SELECT transporter_code 
					FROM ReceiptTransporter rt  (NOLOCK)
					WHERE rt.company_id = b.company_id
					AND rt.profit_ctr_id = b.profit_ctr_id
					AND rt.receipt_id = b.receipt_id
					AND rt.transporter_sequence_id = 1), 
				b.hauler,
				'NONE'),
			-- If nothing turns up in the first transporter from ReceiptTransporter, use b.hauler, then return NONE

			ISNULL(gst.generator_site_type_id,0)
		FROM #Billing b
		JOIN Generator g  (NOLOCK)
			ON g.generator_id = b.generator_id
		LEFT OUTER JOIN GeneratorSiteType gst  (NOLOCK)
			ON gst.generator_site_type = g.site_type
		WHERE b.count_bundled > 0
		FOR READ ONLY

		OPEN c_billing
		FETCH c_billing
		INTO @b_receipt_id, @b_line_id, @b_price_id, @b_profile_id, @b_company_id, @b_profit_ctr_id, @b_sequence_id, @b_hauler, @b_gen_site_type_id

		WHILE (@@FETCH_STATUS = 0)
		BEGIN
			DECLARE c_bundled CURSOR FOR
			SELECT price_group_id, ISNULL(transporter_code,'All'), ISNULL(generator_site_type_id,0)
			FROM ProfileQuoteDetailSplitGroup (NOLOCK)
			WHERE profile_id = @b_profile_id
			AND company_id = @b_company_id
			AND profit_ctr_id = @b_profit_ctr_id
			ORDER BY price_group_sort_id ASC
			FOR READ ONLY

			OPEN c_bundled
			FETCH c_bundled
			INTO @pqdsg_price_group_id, @pqdsg_transporter_code, @pqdsg_gen_site_type_id

			WHILE (@@FETCH_STATUS = 0)
			BEGIN
				-- if there's a match, insert records
				IF (@pqdsg_transporter_code = 'All' OR @pqdsg_transporter_code = @b_hauler) AND
					(@pqdsg_gen_site_type_id = 0 OR @pqdsg_gen_site_type_id = @b_gen_site_type_id)
				BEGIN
					-- First SELECT gets bundled charges by Load
					INSERT @tmp_bundled
					SELECT b.company_id,
						b.profit_ctr_id,
						b.receipt_id,
						b.line_id,
						b.price_id,
						b.trans_source,
						bt.billingtype_uid,
						bt.billing_type,
						b.profile_id,
						b.approval_code,
						b.quote_sequence_id,
						b.waste_extended_amt,
						b.quantity,
						(SELECT SUM(waste_extended_amt) FROM #Billing WHERE company_id = b.company_id
							AND profit_ctr_id = b.profit_ctr_id
							AND receipt_id = b.receipt_id
							AND line_id = b.line_id)
							AS line_total_amt,
						pqd.sequence_id,
						pqd.record_type,
						pqd.bill_method,
						pqd.bill_quantity_flag,
						pqd.price,
						pqd.dist_percent,
						pqd.dist_company_id,
						pqd.dist_profit_ctr_id,
						pqd.product_id,
						--p.gl_account_code,
						-- For bundled products that might have X's in their GL account, we need to take the appropriate account information from the line it's bundled with.
						CASE WHEN p.gl_account_code LIKE '%X%' THEN
								REPLACE(LEFT(p.gl_account_code, 5), 'XXXXX', LEFT(dbo.fn_get_receipt_glaccount(@b_company_id, @b_profit_ctr_id, @b_receipt_id, @b_line_id), 5))
								+ SUBSTRING(p.gl_account_code, 6, 2)
								+ SUBSTRING(p.gl_account_code, 8, 2)
								+ REPLACE(RIGHT(p.gl_account_code, 3), 'XXX', RIGHT(dbo.fn_get_receipt_glaccount(@b_company_id, @b_profit_ctr_id, @b_receipt_id, @b_line_id), 3))
							ELSE 
								p.gl_account_code
							END AS gl_account_code,
							
						--ISNULL(CASE WHEN p.JDE_BU LIKE '%X%' THEN
						--		-- Take the first 4 digits from Product, then replace 3 X's with values from line this Product is bundled with.
						--		REPLACE(p.JDE_BU, 'XXX', RIGHT(dbo.fn_get_receipt_JDE_glaccount_business_unit(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 3))
						--		--LEFT(p.JDE_BU, 4) + REPLACE(RIGHT(p.JDE_BU, 3), 'XXX', SUBSTRING(dbo.fn_get_receipt_JDE_glaccount(@b_company_id, @b_profit_ctr_id, @b_receipt_id, @b_line_id), 5, 3))
						--	ELSE 
						--		-- Use full GL account from Product
						--		p.JDE_BU
						--	END, 'XXXXXXX') AS JDE_BU,
						ISNULL(REPLACE(p.JDE_BU, 'XXX', RIGHT(dbo.fn_get_receipt_JDE_glaccount_business_unit(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 3)), 'XXXXXXX') AS JDE_BU,
							
						--ISNULL(CASE WHEN p.JDE_object LIKE '%X%' THEN
						--		REPLACE(p.JDE_object, 'XXXXX', dbo.fn_get_receipt_JDE_glaccount_object(@b_company_id, @b_profit_ctr_id, @b_receipt_id, @b_line_id))
						--	ELSE 
						--		p.JDE_object
						--	END, 'XXXXX') AS JDE_object,
						ISNULL(REPLACE(p.JDE_object, 'XXXXX', dbo.fn_get_receipt_JDE_glaccount_object(@b_company_id, @b_profit_ctr_id, @b_receipt_id, @b_line_id)), 'XXXXX') AS JDE_object,
							
						CONVERT(money, NULL) AS extended_amt,
						CONVERT(int, 0) AS processed_flag,
						AX_MainAccount = 	REPLACE( p.AX_MainAccount,'XXXXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'MAIN') ),
						AX_Dimension_1 = 	REPLACE( p.AX_Dimension_1,'XXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM1')),
						AX_Dimension_2 = 	REPLACE( p.AX_Dimension_2,'XXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM2')),  
						AX_Dimension_3 = 	REPLACE( p.AX_Dimension_3,'XXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM3')),   
						AX_Dimension_4 = 	REPLACE( p.AX_Dimension_4,'XXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM4')), 
						AX_Dimension_5_part_1 = 	REPLACE( p.AX_Dimension_5_part_1,'XXXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM5')), 
						AX_Dimension_5_part_2 = 	REPLACE( p.AX_Dimension_5_part_2,'XXXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DI52')), 
						AX_Dimension_6 = 	REPLACE( p.AX_Dimension_6,'XXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM6')),
						b.currency_code
					FROM #Billing b
					JOIN BillingType bt ON bt.billing_type = 'Product'
					JOIN ProfileQuoteDetailSplitGroup pqdsg  (nolock)
						ON pqdsg.company_id = b.company_id
						AND pqdsg.profit_ctr_id = b.profit_ctr_id
						AND pqdsg.profile_id = b.profile_id
						AND pqdsg.price_group_id = @pqdsg_price_group_id
					JOIN ProfileQuoteDetail pqd  (nolock)
						ON pqd.company_id = b.company_id 
						AND pqd.profit_ctr_id = b.profit_ctr_id
						AND pqd.profile_id = b.profile_id
						AND ((b.trans_type = 'D' AND pqd.ref_sequence_id = 0)
							OR (b.trans_type = 'S' AND pqd.ref_sequence_id = b.quote_sequence_id))
						AND pqd.bill_method = 'B'			-- Bundled lines
						AND pqd.bill_quantity_flag = 'L'	-- Load
						AND pqd.price_group_id = pqdsg.price_group_id
					JOIN Product p  (nolock)
						ON p.product_id = pqd.product_id
					WHERE b.receipt_id = @b_receipt_id
						AND b.line_id = @b_line_id
						AND b.price_id = @b_price_id
						AND b.profile_id = @b_profile_id
						AND b.company_id = @b_company_id
						AND b.profit_ctr_id = @b_profit_ctr_id
						AND b.quote_sequence_id = @b_sequence_id
						AND (@pqdsg_transporter_code = 'All' OR @pqdsg_transporter_code = @b_hauler) AND
						(@pqdsg_gen_site_type_id = 0 OR @pqdsg_gen_site_type_id = @b_gen_site_type_id)

					UNION

					-- Second SELECT gets bundled charges by Unit or Percent
					SELECT b.company_id,
						b.profit_ctr_id,
						b.receipt_id,
						b.line_id,
						b.price_id,
						b.trans_source,
						bt.billingtype_uid,
						bt.billing_type,
						b.profile_id,
						b.approval_code,
						b.quote_sequence_id,
						b.waste_extended_amt,
						b.quantity,
						(SELECT SUM(waste_extended_amt) FROM #Billing WHERE company_id = b.company_id
							AND profit_ctr_id = b.profit_ctr_id
							AND receipt_id = b.receipt_id
							AND line_id = b.line_id)
							AS line_total_amt,
						pqd.sequence_id,
						pqd.record_type,
						pqd.bill_method,
						pqd.bill_quantity_flag,
						pqd.price,
						pqd.dist_percent,
						pqd.dist_company_id,
						pqd.dist_profit_ctr_id,
						pqd.product_id,
						--p.gl_account_code,
						-- For bundled products that might have X's in their GL account, we need to take the appropriate account information from the line it's bundled with.
						CASE WHEN p.gl_account_code LIKE '%X%' THEN
								REPLACE(LEFT(p.gl_account_code, 5), 'XXXXX', LEFT(dbo.fn_get_receipt_glaccount(@b_company_id, @b_profit_ctr_id, @b_receipt_id, @b_line_id), 5))
								+ SUBSTRING(p.gl_account_code, 6, 2)
								+ SUBSTRING(p.gl_account_code, 8, 2)
								+ REPLACE(RIGHT(p.gl_account_code, 3), 'XXX', RIGHT(dbo.fn_get_receipt_glaccount(@b_company_id, @b_profit_ctr_id, @b_receipt_id, @b_line_id), 3))
							ELSE 
								p.gl_account_code
							END AS gl_account_code,
							
						--ISNULL(CASE WHEN p.JDE_BU LIKE '%X%' THEN
						--		-- Take the first 4 digits from Product, then replace 3 X's with values from line this Product is bundled with.
						--		LEFT(p.JDE_BU, 4) + REPLACE(RIGHT(p.JDE_BU, 3), 'XXX', SUBSTRING(dbo.fn_get_receipt_JDE_glaccount(@b_company_id, @b_profit_ctr_id, @b_receipt_id, @b_line_id), 5, 3))
						--	ELSE 
						--		-- Use full GL account from Product
						--		p.JDE_BU
						--	END, 'XXXXXXX') AS JDE_BU,
						ISNULL(REPLACE(p.JDE_BU, 'XXX', RIGHT(dbo.fn_get_receipt_JDE_glaccount_business_unit(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 3)), 'XXXXXXX') AS JDE_BU,
						
						--ISNULL(CASE WHEN p.JDE_object LIKE '%X%' THEN
						--		REPLACE(p.JDE_object, 'XXXXX', RIGHT(dbo.fn_get_receipt_JDE_glaccount(@b_company_id, @b_profit_ctr_id, @b_receipt_id, @b_line_id), 5))
						--	ELSE 
						--		p.JDE_object
						--	END, 'XXXXX') AS JDE_object,
						ISNULL(REPLACE(p.JDE_object, 'XXXXX', dbo.fn_get_receipt_JDE_glaccount_object(@b_company_id, @b_profit_ctr_id, @b_receipt_id, @b_line_id)), 'XXXXX') AS JDE_object,
						
						CONVERT(money, NULL) AS extended_amt,
						CONVERT(int, 0) AS processed_flag,
						AX_MainAccount = 	REPLACE( p.AX_MainAccount,'XXXXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'MAIN') ),
						AX_Dimension_1 = 	REPLACE( p.AX_Dimension_1,'XXX', dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM1')),
						AX_Dimension_2 = 	REPLACE( p.AX_Dimension_2,'XXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM2')),  
						AX_Dimension_3 = 	REPLACE( p.AX_Dimension_3,'XXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM3')),   
						AX_Dimension_4 = 	REPLACE( p.AX_Dimension_4,'XXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM4')), 
						AX_Dimension_5_part_1 = 	REPLACE( p.AX_Dimension_5_part_1,'XXXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM5')), 
						AX_Dimension_5_part_2 = 	REPLACE( p.AX_Dimension_5_part_2,'XXXXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DI52')), 
						AX_Dimension_6 = 	REPLACE( p.AX_Dimension_6,'XXX',dbo.fn_get_receipt_AX_gl_account(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id,'DIM6')),
						b.currency_code
					FROM #Billing b
					JOIN BillingType bt ON bt.billing_type = 'Product'
					JOIN ProfileQuoteDetailSplitGroup pqdsg  (nolock)
						ON pqdsg.company_id = b.company_id
						AND pqdsg.profit_ctr_id = b.profit_ctr_id
						AND pqdsg.profile_id = b.profile_id
						AND pqdsg.price_group_id = @pqdsg_price_group_id
					JOIN ProfileQuoteDetail pqd  (nolock)
						ON pqd.company_id = b.company_id 
						AND pqd.profit_ctr_id = b.profit_ctr_id
						AND pqd.profile_id = b.profile_id
						AND pqd.ref_sequence_id = b.quote_sequence_id
						AND pqd.price_group_id = pqdsg.price_group_id
						AND pqd.bill_method = 'B'					-- Bundled lines
						AND pqd.bill_quantity_flag IN ('P', 'U')	-- Percent, Unit
					JOIN Product p  (nolock)
						ON p.product_id = pqd.product_id
					WHERE b.receipt_id = @b_receipt_id
						AND b.line_id = @b_line_id
						AND b.price_id = @b_price_id
						AND b.profile_id = @b_profile_id
						AND b.company_id = @b_company_id
						AND b.profit_ctr_id = @b_profit_ctr_id
						AND b.quote_sequence_id = @b_sequence_id
						AND (@pqdsg_transporter_code = 'All' or @pqdsg_transporter_code = @b_hauler) and
						(@pqdsg_gen_site_type_id = 0 or @pqdsg_gen_site_type_id = @b_gen_site_type_id)
						AND (
							 p.tax_code_uid is null		-- Gem 50338 R.Bianco Non Tax Specific 
								OR 
							 p.tax_code_uid = (			-- Gem 50338 R.Bianco Tax Specific With Exact Tax Code Match
								-- This order by encapsulates all tests needed for instate outstate logic
								SELECT Top 1 IsNull(pp.tax_code_uid,0)
								FROM Receipt AS rr 
								INNER JOIN ProfileQuoteDetail AS pq ON rr.company_id = pq.company_id
									AND rr.profit_ctr_id = pq.profit_ctr_id
									AND rr.profile_id = pq.profile_id
									AND pq.record_type = 'S'
									AND pq.bill_method = 'B'
								INNER JOIN Generator AS gg ON rr.generator_id = gg.generator_id
								INNER JOIN Product AS pp ON pq.product_id = pp.product_id 
									 AND Isnull(pq.dist_company_id, pq.company_id) = pp.company_id 
									 AND Isnull(pq.dist_profit_ctr_id, pq.profit_ctr_id) = pp.profit_ctr_id 
									 AND pp.tax_code_uid is not null
								WHERE rr.receipt_id = @b_receipt_id
								AND rr.line_id = @b_line_id
								AND rr.company_id = @b_company_id
								AND rr.profit_ctr_id = @b_profit_ctr_id
								ORDER BY
									CASE WHEN ISNULL(pp.generator_state_applicable,'U') = ISNULL(gg.generator_state,'U') THEN 1 ELSE 2 END,
									CASE WHEN ISNULL(pp.generator_state_applicable,gg.generator_state) = ISNULL(gg.generator_state,'U') THEN 1 ELSE 2 END
								)
							)
					ORDER BY b.company_id,		--This ORDER BY clause dictates which order we apply the bundled charges
						b.profit_ctr_id,			--We take off the bill_quantity_flag = 'L' (Load) charges first,
						b.receipt_id,				--followed by 'P' (Percent) and 'U' (Unit)
						b.line_id,					--Within those, we apply the highest price first.
						b.price_id,
						pqd.bill_quantity_flag,
						pqd.bill_method,
						pqd.price DESC,
						pqd.sequence_id

					-- records were inserted, go to the next billing record
					BREAK
				END

				FETCH c_bundled
				INTO @pqdsg_price_group_id, @pqdsg_transporter_code, @pqdsg_gen_site_type_id
			END
			CLOSE c_bundled
			DEALLOCATE c_bundled

			FETCH c_billing
			INTO @b_receipt_id, @b_line_id, @b_price_id, @b_profile_id, @b_company_id, @b_profit_ctr_id, @b_sequence_id, @b_hauler, @b_gen_site_type_id
		END
		CLOSE c_billing
		DEALLOCATE c_billing
		-- rb Split Groups - end loop

		UPDATE @tmp_bundled SET extended_amt = ROUND(((price * waste_extended_amt) / line_total_amt), 2)
		WHERE bill_quantity_flag = 'L'					-- Load
		and price * waste_extended_amt > 0 and line_total_amt > 0

		UPDATE @tmp_bundled SET extended_amt = ROUND((quantity * price), 2)
		WHERE bill_quantity_flag IN ( 'U', 'P' )		-- Unit, Percent

		IF @debug = 1
		BEGIN
			PRINT ' Selecting @tmp_bundled records:'
			SELECT * FROM @tmp_bundled
		END

		--------------------------------------------------------------------------------------------
		--------------------------------------------------------------------------------------------
		DECLARE c_tmp_bundled CURSOR FOR
		SELECT company_id,
			profit_ctr_id,
			receipt_id,
			line_id,
			price_id,
			trans_source,
			billingtype_uid,
			billing_type,
			product_id,
			dist_company_id,
			dist_profit_ctr_id,
			gl_account_code,
			JDE_BU,
			JDE_object,
			quote_sequence_id,
			sequence_id,
			extended_amt,
			AX_MainAccount,
			AX_Dimension_1, 
			AX_Dimension_2,  
			AX_Dimension_3,  
			AX_Dimension_4,
			AX_Dimension_5_part_1,
			AX_Dimension_5_part_2,
			AX_Dimension_6,
			currency_code
		FROM @tmp_bundled
		WHERE processed_flag = 0

		OPEN c_tmp_bundled

		FETCH c_tmp_bundled
		INTO @bund_company_id,
			@bund_profit_ctr_id,
			@bund_receipt_id,
			@bund_line_id,
			@bund_price_id,
			@bund_trans_source,
			@bund_billingtype_uid,
			@bund_billing_type,
			@bund_product_id,
			@bund_dist_company_id,
			@bund_dist_profit_ctr_id,
			@bund_gl_account_code,
			@bund_jde_bu,
			@bund_jde_object,
			@bund_quote_sequence_id,
			@bund_sequence_id,
			@extended_amt,
			@AX_MainAccount,
			@AX_Dimension_1, 
			@AX_Dimension_2,  
			@AX_Dimension_3,  
			@AX_Dimension_4,
			@AX_Dimension_5_part_1,
			@AX_Dimension_5_part_2,
			@AX_Dimension_6,
			@currency_code

		WHILE @@FETCH_STATUS = 0
		BEGIN
		-- rb end replacement cursor declaration

			-- Get extended_amt from the line that is referenced, to see if we have enough money
			SELECT @ref_extended_amt = extended_amt,
				@billing_uid = billing_uid,
				@billingdetail_uid = billingdetail_uid
			FROM #BillingDetail
			WHERE company_id = @bund_company_id
			AND profit_ctr_id = @bund_profit_ctr_id
			AND receipt_id = @bund_receipt_id
			AND line_id = @bund_line_id
			AND price_id = @bund_price_id
			AND sequence_id = @bund_quote_sequence_id
			AND billing_type IN ('Disposal', 'Product')

			IF @ref_extended_amt > 0
			BEGIN
			
				IF @ref_extended_amt <= @extended_amt SET @extended_amt = @ref_extended_amt

				-----------------------------------------------------
				-- Bundled line
				-----------------------------------------------------
				-- rb replace insert source from table selection with fetched variables
				INSERT INTO #BillingDetail (
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
					sequence_id,
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
					AX_Project_Required_Flag,
					disc_amount,
					currency_code
					)
				VALUES (
					@billing_uid,
					@billingdetail_uid,
					@bund_billingtype_uid,
					@bund_billing_type,
					@bund_company_id, 
					@bund_profit_ctr_id, 
					@bund_receipt_id, 
					@bund_line_id,
					@bund_price_id, 
					@bund_trans_source, 
					'S', 
					@bund_product_id, 
					@bund_dist_company_id,
					@bund_dist_profit_ctr_id, 
					NULL, 
					NULL, 
					ROUND(@extended_amt, 2), 
					@bund_gl_account_code, 
					NULL,
					@bund_jde_bu,
					@bund_jde_object,
					@AX_MainAccount,
					@AX_Dimension_1, 
					@AX_Dimension_2,  
					@AX_Dimension_3,  
					@AX_Dimension_4,
					@AX_Dimension_5_part_1,
					@AX_Dimension_5_part_2,
					@AX_Dimension_6,
					NULL,
					NULL,
					@currency_code)

				-- Update price on BillingDetail record that this one refers to
				UPDATE #BillingDetail SET extended_amt = extended_amt - @extended_amt
				FROM #BillingDetail
				WHERE company_id = @bund_company_id
				AND profit_ctr_id = @bund_profit_ctr_id
				AND receipt_id = @bund_receipt_id
				AND line_id = @bund_line_id
				AND price_id = @bund_price_id
				AND sequence_id = @bund_quote_sequence_id
				AND billing_type IN ('Disposal', 'Product')

			END

			-- rb instead of updating processed_flag in temp table, fetch from cursor
			FETCH c_tmp_bundled
			INTO @bund_company_id,
				@bund_profit_ctr_id,
				@bund_receipt_id,
				@bund_line_id,
				@bund_price_id,
				@bund_trans_source,
				@bund_billingtype_uid,
				@bund_billing_type,
				@bund_product_id,
				@bund_dist_company_id,
				@bund_dist_profit_ctr_id,
				@bund_gl_account_code,
				@bund_jde_bu,
				@bund_jde_object,
				@bund_quote_sequence_id,
				@bund_sequence_id,
				@extended_amt,
				@AX_MainAccount,
				@AX_Dimension_1, 
				@AX_Dimension_2,  
				@AX_Dimension_3,  
				@AX_Dimension_4,
				@AX_Dimension_5_part_1,
				@AX_Dimension_5_part_2,
				@AX_Dimension_6,
				@currency_code
		END

		CLOSE c_tmp_bundled
		DEALLOCATE c_tmp_bundled

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_submit_calc_receipt_charges] TO [EQWEB]
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_submit_calc_receipt_charges] TO [COR_USER]
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_submit_calc_receipt_charges] TO [EQAI]
GO