
CREATE PROCEDURE sp_rpt_extract_walmart_finance_ol (
	@start_date				datetime,
	@end_date				datetime,
	@output_mode			varchar(20)		-- one of: 'validation', 'wm-extract', 'eq-extract'
)
AS
/* ***********************************************************
Procedure    : sp_rpt_extract_walmart_finance_ol
Database     : PLT_AI
Created      : Jan 25 2008 - Jonathan Broome
Description  : Creates a Wal-Mart Financial Extract

Examples:
	sp_rpt_extract_walmart_finance_ol '7/1/2008 00:00', '7/31/2008 23:59', 'validation'
	sp_rpt_extract_walmart_finance_ol '2/26/2012 00:00', '3/31/2012 23:59', 'wm-extract'
	
	select * from eq_extract..WalmartFinancialExtract where date_added > '2009-03-16 15:00'
	select * from eq_extract..WalmartFinancialValidation where date_added > '2009-03-16 15:00'
	select * into eq_extract..Walmart_F_Extract_Compare_sp_200807 from eq_extract..WalmartFinancialExtract where date_added > '2009-03-16 15:00'

Notes:
	IMPORTANT: This script is only valid from 2007/03 and later.
	2007-01 and 2007-02 need to exclude company-14, profit-ctr-4 data.
	2007-01 needs to INCLUDE 14/4 data from the state of TN.

History:
	3/12/2008 - JDB - Beautified comments.  Changed the select
		for site_type to be from Generator directly. Added
		validation for missing site_type, and validation list
		of generators not associated with customer 10673.

	6/9/2008 - JPB - Changed the vendor number variable per Brie.
		Changed item_desc from (billing.service_desc_1 + 2) to
			(tsdf_approval_code / workorderdetail.resource class) + waste_desc
		Changed service_type: When 14-5 & billing project 99, it's ER (emergency response).
			otherwise, it's Routine work.
		Changed dot_description: TSDF approvals use the dot_shipping_name from the approval
			(because it's been entered as they prefer to see it)
			Receipts (EQ approvals) use the new fn_manifest_dot_description function.
			And if a row is neither a TSDF nor has a profile, then the field is ''
		Added validation for missing DOT_description values (that aren't service fee records)
		Added validation for missing waste description values (that aren't service fee records)

	6/20/2008 - JPB - Changes based on Disposal Extract:
		Changed #WRT logic to closer match to Disposal extract, but with extra ReceiptPrice
			and Billing joins as required by Financial

	8/14/2008 - JPB - Changes to Prod Validation:
		Validation was omitting Voided records.  Now it does in both the
			WorkOrderHeader and Receipt sections

	9/17/2008 - JPB - Changed plt_ai extract table locations to eq_extract locations
		Removed @create_summary input
		Converted @create_images input to @export (@create_images was not used)
		Added Export section to end of SP
		Replaced approval_code with replace(r.approval_code, ''WM'' + right(''0000'' + r.generator_site_code, 4), ''WM'')
			to remove generator site codes from approval codes in the extract. - did not address TSDF approval codes.

	10/14/2008 - JPB - Per Brie M: Limited results to Billing Projects 24 and 99

	01/08/2009 - JPB
			Revised from sp_walmart_monthly_financial_extract
			Only returns 1 output per run now (instead of several tables)
			Only returns recordset - no excel output
			Runs from central (plt_ai) locations - subst. plt_21_ai while plt_ai locations don't exist yet.
			
	01/13/2009 - JPB
		Converted for use on plt_ai, and plt_ai only.
	
	03/10/2009 - JPB
		Added 264, 493 to list of billing projects to include (list is now 24,99,364,493)
		Added check for billing_project_id exclusions to receipts that are included in the
			RWT fix select and Receipt selects where they could previously have allowed such
			receipts into the extract if the related workorder were not in the excluded billing
			project list. (closes a loophole also found in the waste extract)

	03/17/2009 - JPB
		Receipt.Load_Generator_EPA_ID vs Generator.EPA_ID: Decided via conf. call internally
			to always use isnull(Receipt.Load_Generator_EPA_ID, Generator.EPA_ID) to be consistent
			with what the Disposal extract uses.
		Commented out the billing project 145 logic (per the disposal extract) but that will probably
			have no effect, given the 24,99,364,493 logic already in place.
			
	04/03/2009 - JPB
		Modified validation tables to hold 7500 chars of problem ids, instead of 1000.
		Modified @list var to accomodate 7500.
		No other changes.

	04/22/2009 - JPB
		Added Extract Logging so we can see in the future what args we called an extract run with

	05/27/2009 - JPB
		Modified date selections to use service date per email from Lorraine:
			> Brie is going to request the Financial extract by service date.  Isn't that the way the Disposal extract is run.  
			> Can you change them to be both on service date for the next export. 
		- Disposal extract already uses service date (workorder start_date)
		
	09/28/2009 - JPB
		Modified per Brie to also explicitly include billing projects 1048, 1049, 1625.


    07/13/2010 - JPB
        Consistent with changes to sp_rpt_extract_walmart_disposal, excepting those changes not applicable in this extract.
       1. Where Load_Generator_EPA_ID was used in favor of generator epa_id, we were re-using bad data
            that had since been fixed in the Generator table, so I reverted this code to just use the
            generator.epa_id field again.

	5/5/2011 - JPB
		Updated to be consistent with latest changes from Disposal Extract
		
		
   8/11/2011 - JPB
      Billing Project ID's for specific extract runs were not correct according to the IT Request spec.
      Commented & Changed herein...
      Added an extra clause "and d.resource_type = 'D'" to the weight lookup in workorders, to prevent non diposal lines from reporting disposal line weights by accident.

   8/31/2011 - JPB
      one-off copy for DC version of finance extracts
		
   2/2/2012 - JPB
		commented off 'and pricd_flag = 1' on wodu join. Broke on DC run
		
	2/13/2012 - JPB
		Copy & modify DC extract customer # for optical labs.
	
	6/14/2012 - SK
		Fixed the bug on LOG run information storing the word DC instead of 'OL'	
*********************************************************** */
-- Fix/Set EndDate's time.
	if isnull(@end_date,'') <> ''
		if datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

-- Define Walmart specific extract values:
DECLARE
	@customer_id			int,
	@extract_datetime		datetime,
	@usr					nvarchar(256),
	@vendor_number			varchar(20),
	@sp_name_args			varchar(1000)

SELECT
	@customer_id			= 12650,
	@extract_datetime		= GETDATE(),
	@usr 					= UPPER(SUSER_SNAME()),
	@vendor_number 			= '257170/368172',
	@sp_name_args			= object_name(@@PROCID) + ' ''' + convert(varchar(20), @start_date) + ''', ''' + convert(varchar(20), @end_date) + ''', ''' + @output_mode + ''''


-- Define other variables used internally:
DECLARE
	@list 					varchar(7500)

IF RIGHT(@usr, 3) = '(2)'
	SELECT @usr = LEFT(@usr,(LEN(@usr)-3))

-- Log Run information
	INSERT EQ_Extract..ExtractLog (
		extract,
		extract_command,
		start_date,
		end_date,
		extract_table,
		record_count,
		date_added,
		added_by
	) VALUES (
		'Walmart Financial OL',
		@sp_name_args,
		GETDATE(),
		null,
		null,
		null,
		@extract_datetime,
		@usr
	)

Create Table #Customer (
	customer_id	int
)
-- INSERT #Customer select convert(int, row) from dbo.fn_SplitXsvText(',', 1, '10673, 13031, 12650')
-- Finance Extract run 8/9/2011:
INSERT #Customer select convert(int, row) from dbo.fn_SplitXsvText(',', 1, '13031')

CREATE TABLE #BillingProject (
	customer_id			int,
	billing_project_id	int
)
INSERT #BillingProject
SELECT cb.customer_id, cb.billing_project_id
FROM CustomerBilling cb
INNER JOIN #Customer c
	ON cb.customer_id = c.customer_id
WHERE cb.billing_project_id IN (
688, 714, 725, 736, 748, 758, 768, 778, 788, 801, 3231, 1776,
689, 715, 726, 737, 749, 759, 769, 779, 789, 811, 1635, 1778,
690, 716, 727, 739, 750, 760, 770, 780, 790, 813, 1650, 742,
691, 717, 728, 740, 751, 761, 771, 781, 793, 818, 1684, 1779,
698, 718, 729, 741, 752, 762, 772, 782, 794, 824, 1772, 1780,
701, 719, 730, 743, 753, 763, 773, 783, 795, 835, 1823, 
704, 720, 731, 744, 754, 764, 774, 784, 796, 840, 1826, 
706, 721, 732, 745, 755, 765, 775, 785, 797, 1050, 1834, 
707, 723, 733, 746, 756, 766, 776, 786, 798, 1053, 1858, 
710, 724, 734, 747, 757, 767, 777, 787, 799, 1622, 1893)

/*	
WHERE cb.billing_project_id IN (
	SELECT convert(int, row) from dbo.fn_SplitXsvText(' ', 1, '24') where @start_date between '1/1/2010' and '12/31/2010 23:59' and len(ltrim(isnull(row, ''))) > 0 -- Bucket Program 2010
	union all
	SELECT convert(int, row) from dbo.fn_SplitXsvText(' ', 1, '3996 3997') where @start_date between '1/1/2011' and '12/31/2011 23:59' and len(ltrim(isnull(row, ''))) > 0 -- Bucket Program 2011
)
*/
	
-- Create #Extract for inserts later:
CREATE TABLE #Extract (
	-- Walmart Fields:
	site_code 					varchar(16) NULL,	-- Facility Number
	site_type_abbr 				varchar(10) NULL,	-- Facility Type
	generator_city 				varchar(40) NULL,	-- City
	generator_state 			varchar(2) NULL,	-- State
	service_date 				datetime NULL,		-- Shipment Date
	epa_id 						varchar(12) NULL,	-- Haz Waste Generator EPA ID
	manifest 					varchar(15) NULL,	-- Manifest Number
	manifest_line 				int NULL,			-- Manifest Line
	pounds 						float NULL,			-- Weight
	bill_unit_desc 				varchar(40) NULL,	-- Container Type
	quantity 					float NULL,			-- Container Quantity
	billing_quantity 			float NULL,			-- Billing Quantity
	item_desc 					varchar(150) NULL,	-- Item Description
	waste_desc 					varchar(50) NULL,	-- Waste Description
	approval_or_resource 		varchar(60) NULL,	-- Waste Profile Number
	dot_description				varchar(255) NULL,	-- DOT Description
	service_type 				varchar(150) NULL,	-- Service Type
	vendor_number				varchar(20) NULL,	-- Vendor Number
	invoice_number 				varchar(150) NULL,	-- Invoice Number
	po_number 					varchar(150) NULL,	-- PO Number
	receipt_id 					int NULL,			-- Workorder Number
	unit_price 					money NULL,			-- Unit Price
	tax							float NULL,			-- Tax
	extended_cost				money NULL,			-- Extended Tax

	-- EQ Fields:
	company_id 					smallint NULL,
	profit_ctr_id	 			smallint NULL,
	line_sequence_id			int NULL,
	generator_id 				int NULL,
	site_type	 				varchar(40) NULL,
	manifest_page 				int NULL,
	item_type 					varchar(9) NULL,
	tsdf_approval_id 			int NULL,
	profile_id 					int NULL,
	source_table 				varchar(20) NULL,
	receipt_date				datetime NULL,
	receipt_workorder_id		int NULL,
	workorder_start_date		datetime NULL,
	customer_id					int NULL
)

-- Create table to store validation info
CREATE TABLE #validation (
	v_id 			int,
	reason 			varchar(200),
	problem_ids 	varchar(7500) null,
	prod_value 		float null,
	extract_value 	float null
)


/* *************************************************************

Build Phase...
	Insert records to #Extract from
	1. TSDF (3rd party) disposal
	2. Receipt (EQ) disposal
	3. No-Waste Pickup Workorders

	Each step also has a #NotSubmitted copy - to trap for records
	that would have been included, if only they were submitted for
	billing already.  This info is for validation purposes.

	Before Receipts can be inseted into #Extract, a separate
	pre-condition query has to be run to build #ReceiptTransporter
	with info needed by the Receipt insert.

************************************************************** */

-- Work Orders using TSDFApprovals (where customer = @customer_id)
INSERT #Extract
SELECT DISTINCT
	-- Walmart Fields:
	g.site_code,
	gst.generator_site_type_abbr AS site_type_abbr,
	g.generator_city,
	g.generator_state,
   	coalesce(wos.date_act_arrive, w.start_date) as service_date,
	g.epa_id AS epa_id,
	d.manifest,
	CASE WHEN isnull(d.manifest_line, '') <> '' THEN
		CASE WHEN IsNumeric(d.manifest_line) <> 1 THEN
			dbo.fn_convert_manifest_line(d.manifest_line, d.manifest_page_num)
		ELSE
			d.manifest_line
		END
	ELSE
		NULL
	END AS manifest_line,
    -- ISNULL(d.pounds, 0) AS pounds,
	ISNULL(
		(
			SELECT 
				quantity
				FROM WorkOrderDetailUnit a
				WHERE a.workorder_id = d.workorder_id
				AND a.company_id = d.company_id
				AND a.profit_ctr_id = d.profit_ctr_id
				AND a.sequence_id = d.sequence_id
				AND a.bill_unit_code = 'LBS'
				and d.resource_type = 'D'
		) 
	, 0) as pounds, -- workorder detail pounds
	-- null, -- b.bill_unit_desc,
	b.bill_unit_desc,
    -- ISNULL(d.quantity, 0) AS quantity,
	/*    
    ISNULL( 
        CASE
                WHEN u.quantity IS NULL
                THEN IsNull(d.quantity,0)
                ELSE u.quantity
        END
    , 0) AS quantity,
    */
  	ISNULL(d.container_count, 0) AS quantity, -- It's CONTAINER quantity.
  	/* Kept above instead of matching to Disposal extract because in2 places this extract
  	is very specific about it being CONTAINER quantity to use */
	ISNULL(Billing.quantity, 0) AS billing_quantity,
	CONVERT(varchar(60), COALESCE(d.tsdf_approval_code, d.resource_class_code)) + ' ' + isnull(t.waste_desc, '') AS item_desc,
	t.waste_desc AS waste_desc,
    CASE WHEN ISNULL(d.tsdf_approval_code, '') = '' THEN
        d.resource_class_code
    ELSE
        d.tsdf_approval_code
    END AS approval_or_resource,
	NULL as dot_description,		-- Populated later
	CASE WHEN (w.company_id = 14 and w.profit_ctr_id = 5 and w.billing_project_id = 99) THEN 'ER' ELSE 'Routine' END as service_type,
	@vendor_number as vendor_number,
	Billing.invoice_code AS invoice_number,
	Billing.purchase_order AS po_number,
	d.workorder_id as receipt_id,
	ISNULL(Billing.price, 0) AS unit_price,
	0 as tax,
	(
		select sum(isnull(bd.extended_amt, 0))
		from billingdetail bd
		where 	bd.receipt_id = Billing.receipt_id
			and bd.line_id = Billing.line_id
			and bd.price_id = Billing.price_id
			and bd.trans_source = Billing.trans_source
			AND bd.company_id = Billing.company_id
			and bd.profit_ctr_id = Billing.profit_ctr_id
	) AS extended_cost,

	-- EQ Fields:
	w.company_id,
	w.profit_ctr_id,
	d.sequence_id as line_sequence_id,
	g.generator_id,
	g.site_type,
	d.manifest_page_num,
	d.resource_type AS item_type,
	t.tsdf_approval_id,
	NULL AS profile_id,
	'Workorder' AS source_table,
	NULL AS receipt_date,
	NULL AS receipt_workorder_id,
	w.start_date AS workorder_start_date,
	w.customer_id AS customer_id
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN Generator g  (nolock) ON w.generator_id = g.generator_id
LEFT OUTER JOIN workorderdetailunit u (nolock) on d.workorder_id = u.workorder_id and d.sequence_id = u.sequence_id and d.company_id = u.company_id and d.profit_ctr_id = u.profit_ctr_id and u.billing_flag = 'T' --and u.priced_flag = 1
INNER JOIN BillUnit b  (nolock) ON isnull(u.bill_unit_code, d.bill_unit_code) = b.bill_unit_code
-- INNER JOIN BillUnit b  (nolock) ON d.bill_unit_code = b.bill_unit_code
LEFT OUTER JOIN TSDFApproval t  (nolock) ON d.tsdf_approval_id = t.tsdf_approval_id
	AND d.company_id = t.company_id
	AND d.profit_ctr_id = t.profit_ctr_id
LEFT OUTER JOIN TSDF t2  (nolock) ON d.tsdf_code = t2.tsdf_code
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
INNER JOIN Billing Billing  (nolock) ON
	d.workorder_id = Billing.receipt_id
	AND d.company_id = Billing.company_id
	AND d.profit_ctr_id = Billing.profit_ctr_id
	AND d.resource_type = Billing.workorder_resource_type
	AND d.sequence_id = Billing.workorder_sequence_id
	AND Billing.trans_source = 'W'
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
	and wos.company_id = w.company_id
	and wos.profit_ctr_id = w.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 1=1
AND w.customer_id in (select customer_id from #customer)
-- AND Billing.invoice_date BETWEEN @start_date and @end_date
-- 2009-05-27: Above changed to following:
AND w.start_date BETWEEN @start_date AND @end_date
AND ISNULL(t2.eq_flag, 'F') = 'F'
AND w.submitted_flag = 'T'
AND Billing.status_code = 'I'
-- AND billing.bill_unit_code = u.bill_unit_code
-- AND (isnull(w.billing_project_id, 0) <> 145 OR (isnull(w.billing_project_id, 0) = 145 and w.customer_id <> 10673))
-- AND isnull(w.billing_project_id, 0) IN (24,99,364,493,1048,1049,1625)
AND isnull(w.billing_project_id, 0) in (select billing_project_id from #BillingProject)




--	PRINT 'Receipt/Transporter Fix'
/*
This query has 3 union'd components:
first component: workorder inner join to billinglinklookup and receipt
second component: receipt inner join to WMReceiptWorkorderTransporter and workorder
third component: receipt not linked to either BLL or WMRWT
*/
select distinct
	r.receipt_id,
	r.line_id,
	rp.price_id,
	r.company_id,
	r.profit_ctr_id,
	wo.workorder_id as receipt_workorder_id,
	wo.company_id as workorder_company_id,
	wo.profit_ctr_id as workorder_profit_ctr_id,
	-- wo.start_date as service_date,
	-- 2009-05-27: Above changed to following:
	isnull(rt1.transporter_sign_date, wo.start_date) as service_date,
	r.receipt_date,
	'F' as calc_recent_wo_flag
INTO #WMReceiptTransporter
from workorderheader wo (nolock) 
inner join billinglinklookup bll  (nolock) on
	wo.company_id = bll.source_company_id
	and wo.profit_ctr_id = bll.source_profit_ctr_id
	and wo.workorder_id = bll.source_id
inner join receipt r  (nolock) on bll.company_id = r.company_id
	and bll.profit_ctr_id = r.profit_ctr_id
	and bll.receipt_id = r.receipt_id
INNER JOIN ReceiptPrice rp  (nolock) ON
	R.receipt_id = rp.receipt_id
	and r.company_id = rp.company_id
	and r.profit_ctr_id = rp.profit_ctr_id
	and r.line_id = rp.line_id
INNER JOIN Billing Billing  (nolock) ON
	r.receipt_id = Billing.receipt_id
	AND r.company_id = Billing.company_id
	AND r.profit_ctr_id = Billing.profit_ctr_id
	AND r.line_id = Billing.line_id
	and rp.price_id = Billing.price_id
	AND Billing.trans_source = 'R'
-- 2009-05-27: Added following join to allow selection by receipttransporter.sign_date in "service_date" field
left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id
	and rt1.profit_ctr_id = r.profit_ctr_id
	and rt1.company_id = r.company_id
	and rt1.transporter_sequence_id = 1
WHERE 1=1
	AND r.customer_id in (select customer_id from #customer)
	-- AND Billing.invoice_date BETWEEN @start_date and @end_date
	-- 2009-05-27: Above changed to following:
	AND wo.start_date BETWEEN @start_date AND @end_date
	AND r.submitted_flag = 'T'
	AND Billing.status_code = 'I'
	-- AND (isnull(wo.billing_project_id, 0) <> 145 OR (isnull(wo.billing_project_id, 0) = 145 and wo.customer_id <> 10673))
	-- AND (isnull(r.billing_project_id, 0) <> 145 OR (isnull(r.billing_project_id, 0) = 145 and r.customer_id <> 10673))
--	AND isnull(wo.billing_project_id, 0) IN (24,99,364,493,1048,1049,1625)
--	AND isnull(r.billing_project_id, 0) IN (24,99,364,493,1048,1049,1625)
	AND isnull(wo.billing_project_id, 0) in (select billing_project_id from #BillingProject)
	AND isnull(r.billing_project_id, 0) in (select billing_project_id from #BillingProject)
/*
union
select distinct
	r.receipt_id,
	r.line_id,
	rp.price_id,
	r.company_id,
	r.profit_ctr_id,
	rwt.workorder_id as receipt_workorder_id,
	rwt.workorder_company_id,
	rwt.workorder_profit_ctr_id,
	-- wo.start_date as service_date,
	-- 2009-05-27: Above changed to following:
	isnull(rt1.transporter_sign_date, wo.start_date) as service_date,
	r.receipt_date,
	rwt.calc_recent_wo_flag
from receipt r (nolock) 
inner join WMReceiptWorkorderTransporter rwt  (nolock) on
	rwt.receipt_company_id = r.company_id
	and rwt.receipt_profit_ctr_id = r.profit_ctr_id
	and rwt.receipt_id = r.receipt_id
	and rwt.workorder_id is not null
	-- and calc_recent_wo_flag = 'F'
inner join workorderheader wo  (nolock) on
	rwt.workorder_id = wo.workorder_id
	and rwt.workorder_profit_ctr_id = wo.profit_ctr_id
	and rwt.workorder_company_id = wo.company_id
INNER JOIN ReceiptPrice rp  (nolock) ON
	R.receipt_id = rp.receipt_id
	and r.company_id = rp.company_id
	and r.profit_ctr_id = rp.profit_ctr_id
	and r.line_id = rp.line_id
INNER JOIN Billing Billing  (nolock) ON
	r.receipt_id = Billing.receipt_id
	AND r.company_id = Billing.company_id
	AND r.profit_ctr_id = Billing.profit_ctr_id
	AND r.line_id = Billing.line_id
	and rp.price_id = Billing.price_id
	AND Billing.trans_source = 'R'
-- 2009-05-27: Added following join to allow selection by receipttransporter.sign_date in "service_date" field
left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id
	and rt1.profit_ctr_id = r.profit_ctr_id
	and rt1.company_id = r.company_id
	and rt1.transporter_sequence_id = 1
WHERE 1=1
	AND r.customer_id = @customer_id
	-- AND Billing.invoice_date BETWEEN @start_date and @end_date
	-- 2009-05-27: Above changed to following:
	AND wo.start_date BETWEEN @start_date AND @end_date
	AND r.submitted_flag = 'T'
	AND Billing.status_code = 'I'
	-- AND (isnull(wo.billing_project_id, 0) <> 145 OR (isnull(wo.billing_project_id, 0) = 145 and wo.customer_id <> 10673))
	-- AND (isnull(r.billing_project_id, 0) <> 145 OR (isnull(r.billing_project_id, 0) = 145 and r.customer_id <> 10673))
	AND isnull(wo.billing_project_id, 0) IN (24,99,364,493,1048,1049,1625)
	AND isnull(r.billing_project_id, 0) IN (24,99,364,493,1048,1049,1625)
	and not exists (
		select
		ri.receipt_id
		from workorderheader wo (nolock) 
		inner join billinglinklookup bll  (nolock) on
			wo.company_id = bll.source_company_id
			and wo.profit_ctr_id = bll.source_profit_ctr_id
			and wo.workorder_id = bll.source_id
		inner join receipt ri  (nolock) on bll.company_id = ri.company_id
			and bll.profit_ctr_id = ri.profit_ctr_id
			and bll.receipt_id = ri.receipt_id
		INNER JOIN ReceiptPrice rp  (nolock) ON
			R.receipt_id = rp.receipt_id
			and r.company_id = rp.company_id
			and r.profit_ctr_id = rp.profit_ctr_id
			and r.line_id = rp.line_id
		where
		wo.start_date between @start_date AND @end_date
		-- 2009-05-27: Above line did not change - already referenced wo.start_date
		and (1=0
			or wo.customer_id = @customer_id
			or wo.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
			-- OR wo.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN ('Amigo', 'Neighborhood Market', 'Sams Club', 'Sams DC', 'Supercenter', 'Wal-Mart', 'Wal-Mart DC', 'Optical Lab'))
			or r.customer_id = @customer_id
			or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
			-- OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN ('Amigo', 'Neighborhood Market', 'Sams Club', 'Sams DC', 'Supercenter', 'Wal-Mart', 'Wal-Mart DC', 'Optical Lab'))
		)
		-- AND (isnull(wo.billing_project_id, 0) <> 145 OR (isnull(wo.billing_project_id, 0) = 145 and wo.customer_id <> 10673))
		-- AND (isnull(ri.billing_project_id, 0) <> 145 OR (isnull(ri.billing_project_id, 0) = 145 and ri.customer_id <> 10673))
		AND isnull(wo.billing_project_id, 0) IN (24,99,364,493,1048,1049,1625)
		AND isnull(r.billing_project_id, 0) IN (24,99,364,493,1048,1049,1625)
		and ri.receipt_id = r.receipt_id and ri.company_id = r.company_id and ri.profit_ctr_id = r.profit_ctr_id
	)
*/	
union
select distinct
	r.receipt_id,
	r.line_id,
	rp.price_id,
	r.company_id,
	r.profit_ctr_id,
	null as receipt_workorder_id,
	null as workorder_company_id,
	null as workorder_profit_ctr_id,
	-- null as service_date,
	-- 2009-05-27: Above changed to following:
	rt1.transporter_sign_date as service_date,
	r.receipt_date,
	'F' as calc_recent_wo_flag
FROM Receipt r (nolock) 
INNER JOIN ReceiptPrice rp  (nolock) ON
	R.receipt_id = rp.receipt_id
	and r.company_id = rp.company_id
	and r.profit_ctr_id = rp.profit_ctr_id
	and r.line_id = rp.line_id
INNER JOIN Billing Billing  (nolock) ON
	r.receipt_id = Billing.receipt_id
	AND r.company_id = Billing.company_id
	AND r.profit_ctr_id = Billing.profit_ctr_id
	AND r.line_id = Billing.line_id
	and rp.price_id = Billing.price_id
	AND Billing.trans_source = 'R'
-- 2009-05-27: Added following join to allow selection by receipttransporter.sign_date in "service_date" field
left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id
	and rt1.profit_ctr_id = r.profit_ctr_id
	and rt1.company_id = r.company_id
	and rt1.transporter_sequence_id = 1
WHERE 1=1
	AND r.customer_id in (select customer_id from #customer)
	-- AND Billing.invoice_date BETWEEN @start_date and @end_date
	-- 2009-05-27: Above changed to following:
	AND r.receipt_date BETWEEN @start_date AND @end_date
	AND r.submitted_flag = 'T'
	AND Billing.status_code = 'I'
	-- AND (isnull(r.billing_project_id, 0) <> 145 OR (isnull(r.billing_project_id, 0) = 145 and r.customer_id <> 10673))
	-- AND isnull(r.billing_project_id, 0) IN (24,99,364,493,1048,1049,1625)
	AND isnull(r.billing_project_id, 0) in (select billing_project_id from #BillingProject)	
	and not exists (
		select receipt_id from billinglinklookup bll (nolock) 
		where bll.company_id = r.company_id
		and bll.profit_ctr_id = r.profit_ctr_id
		and bll.receipt_id = r.receipt_id
		union all
		select receipt_id from WMReceiptWorkorderTransporter rwt (nolock) 
		where rwt.receipt_company_id = r.company_id
		and rwt.receipt_profit_ctr_id = r.profit_ctr_id
		and rwt.receipt_id = r.receipt_id
		and rwt.workorder_id is not null
	)


-- Receipts
INSERT #Extract
SELECT DISTINCT
		-- Walmart Fields:
		g.site_code,
		gst.generator_site_type_abbr AS site_type_abbr,
		g.generator_city,
		g.generator_state,
		wrt.service_date,
		-- coalesce(r.Load_Generator_EPA_ID, g.epa_id, '') AS epa_id,
		g.epa_id,
		r.manifest,
		CASE WHEN ISNULL(r.manifest_line, '') <> '' THEN
			CASE WHEN IsNumeric(r.manifest_line) <> 1 THEN
				dbo.fn_convert_manifest_line(r.manifest_line, r.manifest_page_num)
			ELSE
				r.manifest_line
			END
		ELSE
			NULL
		END AS manifest_line,
/*		
		round( 
		 ISNULL(
		  ISNULL((SELECT (isnull(rp.bill_quantity, 0) / isnull(r.quantity, 0)) * ISNULL( SUM(container_weight), 0) 
		   FROM container con (nolock)
		   WHERE con.company_id = R.company_id
			AND con.profit_ctr_id = R.profit_ctr_id
			AND con.receipt_id = R.receipt_id
			AND con.line_id = R.line_id
			AND con.container_type = 'R'
			AND con.status <> 'V')
		  , r.net_weight)
		 , 0)
		, 0) as pounds,
*/
		r.line_weight as pounds, -- pull in NULL for now, we'll update it from Receipt.Net_weight later - 12/20/2010
		
		b.bill_unit_desc,
		-- ISNULL(rp.bill_quantity, 0) AS quantity,
		ISNULL(r.container_count, 0) AS quantity, -- It's CONTAINER quantity
		ISNULL(Billing.quantity, 0) AS billing_quantity,
		ISNULL(Billing.service_desc_1,'') + ' ' + ISNULL(NULLIF(Billing.service_desc_2, Billing.service_desc_1), '') AS item_desc,
		p.Approval_desc AS waste_desc,
		COALESCE(replace(r.approval_code, 'WM' + right('0000' + g.site_code, 4), 'WM'), r.service_desc) AS approval_or_resource,
		NULL as dot_description,
		CASE WHEN (r.company_id = 14 and r.profit_ctr_id = 5 and r.billing_project_id = 99) THEN 'ER' ELSE 'Routine' END as service_type,
		@vendor_number as vendor_number,
		Billing.invoice_code AS invoice_number,
		Billing.purchase_order AS po_number,
		wrt.receipt_id,
		ISNULL(Billing.price, 0) AS unit_price,
		0 as tax,
		(
			select sum(isnull(bd.extended_amt, 0))
			from billingdetail bd
			where 	bd.receipt_id = Billing.receipt_id
				and bd.line_id = Billing.line_id
				and bd.price_id = Billing.price_id
				and bd.trans_source = Billing.trans_source
				AND bd.company_id = Billing.company_id
				and bd.profit_ctr_id = Billing.profit_ctr_id
		) AS extended_cost,

		-- EQ Fields:
		wrt.company_id,
		wrt.profit_ctr_id,
		r.line_id,
		r.generator_id,
		g.site_type,
		r.manifest_page_num AS manifest_page,
		r.trans_type AS item_type,
		NULL AS tsdf_approval_id,
		r.profile_id,
		'Receipt' AS source_table,
		r.receipt_date,
		wrt.receipt_workorder_id,
		wrt.service_date AS workorder_start_date,
		r.customer_id

	FROM Receipt r (nolock) 
	INNER JOIN ReceiptPrice rp  (nolock) ON
		/* r.link_Receipt_ReceiptPrice = rp.link_Receipt_ReceiptPrice */
		R.receipt_id = rp.receipt_id
		and r.company_id = rp.company_id
		and r.profit_ctr_id = rp.profit_ctr_id
		and r.line_id = rp.line_id
	INNER JOIN Generator g  (nolock) ON r.generator_id = g.generator_id
	INNER JOIN BillUnit b  (nolock) ON rp.bill_unit_code = b.bill_unit_code
	INNER JOIN #WMReceiptTransporter wrt ON
		r.company_id = wrt.company_id
		and r.profit_ctr_id = wrt.profit_ctr_id
		and r.receipt_id = wrt.receipt_id
		and r.line_id = wrt.line_id
		and rp.price_id = wrt.price_id
	INNER JOIN Billing Billing  (nolock) ON
		r.receipt_id = Billing.receipt_id
		AND r.company_id = Billing.company_id
		AND r.profit_ctr_id = Billing.profit_ctr_id
		AND r.line_id = Billing.line_id
		and rp.price_id = Billing.price_id
		AND Billing.trans_source = 'R'
	LEFT OUTER JOIN Profile p  (nolock) on r.profile_id = p.profile_id
	LEFT OUTER JOIN Treatment tr  (nolock) ON r.treatment_id = tr.treatment_id
	LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
	WHERE 1=1
	AND r.customer_id in (select customer_id from #customer)
	-- AND Billing.invoice_date BETWEEN @start_date and @end_date
	-- 2009-05-27: Above removed because the inner-joined table #WMReceiptTransporter can only contain records
	--  where the "service_date" (wo.start_date or r.receipt_date, etc) is within the range @start_date to @end_date.
	--  There should be no need to filter again here (in fact, the disposal extract also does not filter on date at this point)
	AND r.submitted_flag = 'T'
	AND Billing.status_code = 'I'
--	AND isnull(r.billing_project_id, 0) IN (24,99,364,493,1048,1049,1625)
	AND isnull(r.billing_project_id, 0) in (select billing_project_id from #BillingProject)
/*
GROUP BY
	g.site_code,
	gst.generator_site_type_abbr,
	g.generator_city,
	g.generator_state,
	wrt.service_date,
	-- r.load_generator_EPA_ID,
	g.EPA_ID,
	r.manifest,
	r.manifest_page_num,
	r.manifest_line,
	r.line_weight,
	b.bill_unit_desc,
	rp.bill_quantity,
	r.quantity,
	r.container_count,
	Billing.quantity,
	Billing.service_desc_1,
	Billing.service_desc_2,
	p.approval_desc,
	g.site_code,
	r.approval_code,
	r.service_desc,
	r.company_id,
	r.profit_ctr_id,
	r.billing_project_id,
	Billing.invoice_code,
	Billing.purchase_order,
	wrt.receipt_id,
	Billing.price,
	Billing.total_extended_amt,
	wrt.company_id,
	wrt.profit_ctr_id,
	r.receipt_id,
	r.line_id,
	r.generator_id,
	g.site_type,
	r.manifest_page_num,
	r.trans_type,
	r.profile_id,
	r.receipt_date,
	wrt.receipt_workorder_id,
	wrt.service_date,
	r.customer_id
*/

-- Update fields left null in #Extract
UPDATE #Extract set
	dot_description =
		CASE WHEN #Extract.tsdf_approval_id IS NOT NULL THEN
			(SELECT DOT_shipping_name FROM tsdfapproval  (nolock) WHERE tsdf_approval_id = #Extract.tsdf_approval_id)
		ELSE
			CASE WHEN #Extract.profile_id IS NOT NULL THEN
				left(dbo.fn_manifest_dot_description('P', #Extract.profile_id), 255)
			ELSE
				''
			END
		END


-- #Extract is finished now.


/* *************************************************************

Validate Phase...

	Run the Validation every time, but may not be exported below...

	Create list of missing Weights
	Create list of missing service dates
	Create list of missing site codes
	Create list of missing site types
	Create list of missing dot descriptions
	Create list of missing item_desc
	Create count of receipt records
	Create count of workorder records

************************************************************** */

-- Create list of missing Weights
	set @list = null
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	from #Extract where pounds = 0
	AND waste_desc <> 'No waste picked up'
	AND item_type in ('Approval', 'Disposal')
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT #validation SELECT 3, 'Missing Weights:' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of missing service dates
	set @list = null
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	from #Extract where ISNULL(service_date, '') = ''
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT #validation SELECT 4, 'Missing Shipment Date:' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of missing site codes
	set @list = null
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	from #Extract where ISNULL(site_code, '') = ''
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT #validation SELECT 5, 'Missing Generator Site Code:' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of missing site types
	SET @list = null
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	FROM #Extract where ISNULL(site_type, '') = ''
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT #validation SELECT 9, 'Missing Generator Site Type:' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of missing dot descriptions
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' :' + CONVERT(varchar(20), receipt_id)
	FROM #Extract where
		ISNULL(
			CASE WHEN #Extract.tsdf_approval_id IS NOT NULL THEN
				dbo.fn_manifest_dot_description('T', #Extract.tsdf_approval_id)
			ELSE
				CASE WHEN #Extract.profile_id IS NOT NULL THEN
					dbo.fn_manifest_dot_description('P', #Extract.profile_id)
				ELSE
					''
				END
			END
		, '') = ''
	AND item_type in ('Approval', 'Disposal')
	and approval_or_resource not in ('STOPFEE', 'GASSUR%')
	and item_desc not in ('STOPFEE', 'GASSUR%')
	and waste_desc <> 'No waste picked up'
	GROUP BY company_id, profit_ctr_id, receipt_id ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT #validation SELECT 11, 'Missing DOT Description: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null where LEN(LTRIM(ISNULL(@list, '')))> 0


-- Create list of missing item_desc
	SET @list = null
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	FROM #Extract where isnull(item_desc, '') = ''
	and isnull(nullif(approval_or_resource, ''), item_desc) not in ('STOPFEE', 'GASSUR%')
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT #validation SELECT 11, 'Missing Waste Description:' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create count of receipt records
	INSERT #validation SELECT 100, 'Count of Receipt-based records in Extract:',
		CONVERT(varchar(20), count(*)), null, null
		from #Extract
		WHERE source_table = 'Receipt'

-- Create count of workorder records
	INSERT #validation SELECT 101, 'Count of Workorder-based records in Extract:',
	CONVERT(varchar(20), count(*)), null, null
		from #Extract
		WHERE source_table = 'Workorder'


/* *************************************************************

Export Phase...

	Only export 1 kind of output per SP run

************************************************************** */

IF @output_mode = 'validation' BEGIN
	
	INSERT EQ_Extract.dbo.WalmartFinancialValidation
		SELECT
			v_id,
			reason,
			problem_ids,
			prod_value,
			extract_value,
			@usr,
			@extract_datetime
		FROM #validation

-- Update Run information
	UPDATE EQ_Extract..ExtractLog SET
		end_date = GETDATE(),
		extract_table = 'EQ_Extract.dbo.WalmartFinancialValidation',
		record_count = @@rowcount
	WHERE
		extract_command = @sp_name_args
		AND date_added = @extract_datetime
		AND added_by = @usr		

		SELECT
			v_id,
			reason,
			problem_ids,
			prod_value,
			extract_value
		FROM EQ_Extract.dbo.WalmartFinancialValidation
		WHERE
			added_by = @usr
			AND date_added = @extract_datetime
			AND (
				problem_ids is not null
				OR
				prod_value <> extract_value
			)
		ORDER BY
			v_id
END

IF @output_mode = 'wm-extract' BEGIN

	INSERT EQ_Extract.dbo.WalmartFinancialExtract
	SELECT
	-- Walmart Fields:
		site_code,
		site_type_abbr,
		generator_city,
		generator_state,
		service_date,
		epa_id,
		manifest,
		manifest_line,
		pounds,
		bill_unit_desc,
		quantity,
		billing_quantity,
		item_desc,
		waste_desc,
		approval_or_resource,
		dot_description,
		service_type,
		vendor_number,
		invoice_number,
		po_number,
		receipt_id,
		unit_price,
		tax,
		extended_cost,

		-- EQ Fields:
		company_id,
		profit_ctr_id,
		line_sequence_id,
		generator_id,
		site_type,
		manifest_page,
		item_type,
		tsdf_approval_id,
		profile_id,
		source_table,
		receipt_date,
		receipt_workorder_id,
		workorder_start_date,
		customer_id,
		@usr,
		@extract_datetime
	FROM #Extract

-- Update Run information
	UPDATE EQ_Extract..ExtractLog SET
		end_date = GETDATE(),
		extract_table = 'EQ_Extract.dbo.WalmartFinancialExtract',
		record_count = @@rowcount
	WHERE
		extract_command = @sp_name_args
		AND date_added = @extract_datetime
		AND added_by = @usr		

	SELECT
		-- Walmart Fields:
		ISNULL(site_code 				, '') as 'Facility Number',
		ISNULL(site_type_abbr 			, '') as 'Facility Type',
		ISNULL(generator_city 			, '') as 'City',
		ISNULL(generator_state 			, '') as 'State',
		ISNULL(CONVERT(varchar(20), service_date, 101), '') AS 'Shipment Date',
		ISNULL(epa_id 					, '') as 'Haz Waste Generator EPA ID',
		ISNULL(manifest 				, '') as 'Manifest Number',
		ISNULL(NULLIF(manifest_line, 0), '') AS 'Manifest Line',
		ISNULL(pounds 					, '') as 'Weight',
		ISNULL(bill_unit_desc 			, '') as 'Container Type',
		ISNULL(quantity 				, '') as 'Container Quantity',
		ISNULL(billing_quantity 		, '') as 'Billing Quantity',
		ISNULL(item_desc 				, '') as 'Item Description',
		ISNULL(waste_desc 				, '') as 'Waste Description',
		ISNULL(approval_or_resource 	, '') as 'Waste Profile Number',
		ISNULL(dot_description			, '') as 'DOT Description',
		ISNULL(service_type 			, '') as 'Service Type',
		ISNULL(vendor_number			, '') as 'Vendor Number',
		ISNULL(invoice_number 			, '') as 'Invoice Number',
		ISNULL(po_number 				, '') as 'PO Number',
		ISNULL(receipt_id 				, '') as 'Workorder Number',
		ISNULL(unit_price 				, 0) as 'Unit Price',
		ISNULL(tax						, 0) as 'Tax',
		ISNULL(extended_cost			, 0) as 'Extended Tax'
	FROM EQ_Extract.dbo.WalmartFinancialExtract
	WHERE
		added_by = @usr
		AND date_added = @extract_datetime
	ORDER BY
		generator_state,
		generator_city,
		site_code,
		service_date,
		receipt_id
END

IF @output_mode = 'eq-extract' BEGIN
		
		INSERT EQ_Extract.dbo.WalmartFinancialExtract
		SELECT
			*,
			@usr,
			@extract_datetime
		FROM #Extract

-- Update Run information
	UPDATE EQ_Extract..ExtractLog SET
		end_date = GETDATE(),
		extract_table = 'EQ_Extract.dbo.WalmartFinancialExtract',
		record_count = @@rowcount
	WHERE
		extract_command = @sp_name_args
		AND date_added = @extract_datetime
		AND added_by = @usr		

		SELECT
			*
		FROM EQ_Extract.dbo.WalmartFinancialExtract
		WHERE
			added_by = @usr
			AND date_added = @extract_datetime
		ORDER BY
			generator_state,
			generator_city,
			site_code,
			service_date,
			receipt_id
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_walmart_finance_ol] TO [EQAI]
    AS [dbo];

