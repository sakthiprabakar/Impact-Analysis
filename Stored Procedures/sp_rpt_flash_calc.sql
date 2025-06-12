DROP PROCEDURE IF EXISTS [dbo].[sp_rpt_flash_calc]
GO

CREATE PROCEDURE [dbo].[sp_rpt_flash_calc]
	@copc_list				VARCHAR(MAX),
	@date_from				DATETIME = NULL,
	@date_to				DATETIME = NULL,
	@cust_id_from			varchar(max),
	@cust_id_to				varchar(max),
	@cust_type_list			varchar(max) = '',
	@cust_category_list		varchar(max) = '',
	@invoice_flag			VARCHAR(MAX),  /* 'I'nvoiced, 'N'ot invoiced,   or   special subsets of 'N': 'S'ubmitted, 'U'nsubmitted  */
	@source_list			VARCHAR(MAX),  /* 'R'eceipt, 'W'orkorder */
	@copc_search_type		char(1) = 'T', /* 'T'ransaction facility (native, default) or 'D'istribution facility */
	@transaction_type		char(1) = 'A', /* 'A'll, 'N'ative only (or Not split), 'S'plit between facilities only */
	@debug_flag				INT = 0
WITH RECOMPILE
AS
/*********************************************************************************************
sp_rpt_flash_calc

IMPORTANT:
	Changes to sp_billing_submit affect this stored procedure - this has to be updated too!
	Changes to sp_billing_submit_calc_receipt_charges affect this stored procedure - this has to be changed too!
	Changes to sp_billing_submit_calc_surcharges_billingdetail affect this stored procedure - this has to be changed too!
	
	Changes to sp_flash_calc affect sp_report_eqip_flash_detail.
	
	It's a whole big, "Circle of life" thing.

03/23/2011 JPB	Created as a copy of sp_rpt_territory_calc_ai
01/23/2012 JPB	Updated per GL Standardization
01/23/2012 JPB	Added copc_search_type, @transaction_type options.
				Changed WO Pricing to use fn.
01/27/2012 JPB	Per Talk with JDB & LT, changes:
					- You can run for Invoiced OR not invoiced, not both
					- Invoiced runs compare dates against Invoice Date
					- Not Invoiced runs compare dates against transaction date.
01/31/2012 JPB		- Fix to GL's with XX needing 0-padded co/pc.
03/16/2012 JDB	Added the use of sp_billing_submit_calc_surcharges_billingdetail for calculating
				the surcharges/taxes on receipts and work orders.
03/15/2013 JPB	Updated #Billing* temp table field lists to match new schemas used in sp_billing_submit
					that were updated with JDE integration fields
04/08/2013 JDB	Updated the insert into #BillingDetail for work orders to calculate the GL account properly.
04/30/2013 JPB	Updated the Receipt, not in Billing section to properly include both bundled (already there) 
					and unbundled (new) split transactions.
05/07/2013 JPB	Added another section like unbundled splits to catch products on receipts that are NOT
					profile-related. This makes the "A" version match the "E" version.
				Also: 0-Price workorders should appear now.
06/28/2013 SK	Added column service_date to BillingComment declaration. This was added to the Submit procedure to allow invoicing by service date
07/26/2013 RB	Added JDE_BU and JDE_object columns
08/23/2013 SK	Added waste_code_uid to BIlling
03/31/2014 AM   GEM:28202 ( sponsored project 28005 ) - Added station_id to populate for workorders.
06/06/2014 JPB	Added customer_type as an input and output.
08/21/2014 JPB	Added submitted_date and submitted_by fields per GEM:29517
11/18/2014 JDB	Replaced station ID field with reference code.
11/24/2014 JDB	Fixed bug that was causing the report to fail for receipts (just introduced in the last version of this SP).
					The insert into #Billing table had too many columns and was failing.
04/10/2015 RWB	Performance mods
08/04/2015 JPB	Added job_type (Base or Event)

01/08/2016 JPB	Added pickup_date
02/02/2016 JPB	Invoiced Orders section had pickup_date in wrong order. Fixed.
01/17/2017 JPB	Undocumented changes from AX Addition to Billing-related sps in other places made table defintions
					in this sp obsolete.  Updated #BillingDetail definition by adding AX_ fields to adjust.
01/18/2017 JPB	GEM-41123 - Add AX Fields to Flash output (show existing data, don't populate new)
				GEM-41124 - Allow Filtering by Submitted-But-Not-Invoiced
				GEM-38575 - Add First Invoice Date to output
11/30/2017 JPB	GEM-43800 - On the invoiced flash report, we need to show all bundled items as distributed, 
					regardless of distribution company and profit center.  When profiles within Florida have bundled 
					product line items into their disposal, they do not show on the flash as distributed.  These are 
					distributed from the disposal price, thus, need to reflect as distributed.
02/15/2018 MPM	Added currency_code column to #Billing and #BillingDetail.
10/29/2018 JPB	GEM-52500 Added AX Dimension population where missing
01/15/2019 RWB	GEM-57612 Add ability to connect to new MSS 2016 servers (2 raiserror statements were using old syntax)
07/03/2019 JPB	Revert for deploy
07/08/2019 JPB	cust_name and generator_name sizes reverted.  Updated AGAIN 40->75
02/27/2020 AM   DevOps:14516 - modified billing_status_code value.
11/10/2020 MPM	DevOps 17889 - Added Manage Engine WorkOrderHeader.ticket_number to #FlashWork.
12/01/2021 AM  DevOps:29616 - Changed generator_name length from varchar(40) to varchar(75)
01/01/2022 JPB  Devops 30000 - Speed Improvements
01/07/2022 JPB  Devops 30000 - Cache/pre-run Improvements
02/14/2022 JPB	@Customer temp table version
02/16/2023 JPB	DO-52467 - eliminated NULL warning
02/16/2023 JPB	DO-29757 - nullify JDE fields
					-- Added cust_category
					-- Modified debug logging
					-- Added #region comments for code folding
					-- Billed Receipts got some temp table optimizations
				-- WorkOrderDetail is optional in UnInvoiced Equipment/Supplies/Labor queries.
					-- WorkOrderHeader StartDate can be null, which should always be included (Uninvoiced ver)
04/05/2023 JPB	Verbal per PaulK, no specific ticket...
				In Not-In-Billing inclusions from Workorders, he noticed that AX_Dimension_5_part_1 and AX_Dimension_5_part_2
					were being treated differently than they are in the In-Billing sections, owing to legacy logic in this report.
					New instruction:
						"if not in billing just pull from WorkOrderHeader.AX_Dimension_5_Part_1 and WorkOrderHeader.AX_Dimension_5_Part_2"
					So "calcdim5" instances are commented out now because no longer needed (were only added with the "recent" speedtest logic anyway)
08/11/2023 JPB	DO-70660 - Change to first_invoice_date logic to also match on trans_source.
07/08/2024 KS	Rally116985 - Modified service_desc_1 and service_desc_2 datatype to VARCHAR(100) for #Billing table.
07/31/2024 AM	DevOps:94051 - Modified approval_desc datatype 60 to VARCHAR(100) for #Billing table.
08/08/2024 AM   DevOps:94294 - HUB - Un-Invoiced Flash - Unexpected service charge appearing. 

SELECT * FROM workorderheader where company_id = 14 and profit_ctr_id = 4 and total_price = 0 order by date_added desc
-- 8963500

/*
Missing Index Details from sp_rpt_flash_calc.sql - NTSQL1dev.Plt_AI (jonathan (51))
The Query Processor estimates that implementing the following index could improve the query cost by 26.9087%.
*/

/*
USE [Plt_AI]
G O
CREATE NONCLUSTERED INDEX [idx_BillingDetail_trans_source]
ON [dbo].[BillingDetail] ([trans_source])
INCLUDE ([billing_type],[company_id],[profit_ctr_id],[receipt_id],[line_id],[price_id],[dist_company_id],[dist_profit_ctr_id],[extended_amt],[gl_account_code])
G O
*/

-- existing non-clustered billingdetail index: receipt_id, line_id, price_id, trans_source, profit_ctr_id, company_id, billing_type
-- new index:
-- create index idx_receipt_id on BillingDetail (receipt_id, profit_ctr_id, company_id)
-- new index:
-- create index idx_receipt_id on Billing (receipt_id, profit_ctr_id, company_id)


-- DROP TABLE #FlashWork
-- G O
-- DROP TABLE #FlashWorkSplit
-- G O
--

-- truncate table #FlashWork
CREATE TABLE #FlashWork (

	--	Header info:
		company_id					int			NULL,
		profit_ctr_id				int			NULL,
		trans_source				char(2)		NULL,	--	Receipt,	Workorder,	Workorder-Receipt,	etc
		receipt_id					int			NULL,	--	Receipt/Workorder	ID
		trans_type					char(1)		NULL,	--	Receipt	trans	type	(O/I)
		link_flag					char(1)		NULL,	--  if R/WO, is this linked to a WO/R? T/F
		linked_record				varchar(255)	NULL,	-- if R, list of WO's linked to (prob. just 1, but multiple poss.)
		workorder_type				varchar(40)	NULL,	--	WorkOrderType.account_desc
		trans_status				char(1)		NULL,	--	Receipt	or	Workorder	Status
		status_description			varchar(40) NULL,	--  Billing/Transaction Status (Invoiced, Billing Validated, Accepted, etc)
		trans_date					datetime	NULL,	--	Receipt	Date	or	Workorder	End	Date
		pickup_date					datetime	NULL,	--  Receipt Pickup Date or Workorder Pickup Date (transporter 1 sign date either way)
		submitted_flag				char(1)		NULL,	--	Submitted	Flag
		date_submitted				datetime	NULL,	--  Submitted Date
		submitted_by				varchar(10)	NULL,	--  Submitted By
		billing_status_code			char(1)		NULL,	--  Billing Status Code
		territory_code				varchar(8)	NULL,	--	Billing	Project	Territory	code
		billing_project_id			int			NULL,	--	Billing	project	ID
		billing_project_name		varchar(40)	NULL,	--	Billing	Project	Name
		invoice_flag				char(1)		NULL,	--  'T'/'F' (Invoiced/Not Invoiced)
		invoice_code				varchar(16)	NULL,	--	Invoice	Code	(if	invoiced)
		invoice_date				datetime	NULL,	--	Invoice	Date	(if	invoiced)
		invoice_month				int			NULL,	--	Invoice	Date	month
		invoice_year				int			NULL,	--	Invoice	Date	year
		customer_id					int			NULL,	--	Customer	ID	on	Receipt/Workorder
		cust_name					varchar(75)	NULL,	--	Customer	Name
		customer_type				varchar(20)	NULL,	--  Customer Type
		cust_category				varchar(30) NULL,	--	Customer Category

	--	Detail info:
		line_id						int			NULL,	--	Receipt	line	id
		price_id					int			NULL,	--	Receipt	line	price	id
		ref_line_id					int			NULL,	--	Billing	reference	line_id	(which	line	does	this	refer	to?)
		workorder_sequence_id		varchar(15)	NULL,	--	Workorder	sequence	id
		workorder_resource_item		varchar(15)	NULL,	--	Workorder	Resource	Item
		workorder_resource_type		varchar(15)	NULL,	--	Workorder	Resource	Type
		Workorder_resource_category	Varchar(40)	NULL,	--	Workorder	Resource	Category
		quantity					float		NULL,	--	Receipt/Workorder	Quantity
		billing_type				varchar(20)	NULL,	--	'Energy',	'Insurance',	'Salestax'	etc.
		dist_flag					char(1)		NULL,	--	'D', 'N' (Distributed/Not Distributed -- if the dist co/pc is diff from native co/pc, this is D)
		dist_company_id				int			NULL,	--	Distribution	Company	ID	(which	company	receives	the	revenue)
		dist_profit_ctr_id			int			NULL,	--	Distribution	Profit	Ctr	ID	(which	profitcenter	receives	the	revenue)
		gl_account_code				varchar(12)	NULL,	--	GL	Account	for	the	revenue
		gl_native_code				varchar(5)	NULL,	--	GL Native code (first 5 characters)
		gl_dept_code				varchar(3)	NULL,	--	GL Dept (last 3 characters)
		extended_amt				float			NULL,	--	Revenue	amt
		generator_id				int			NULL,	--	Generator	ID
		generator_name				varchar(75)	NULL,	--	Generator	Name
		epa_id						varchar(12)	NULL,	--	Generator	EPA	ID
		treatment_id				int			NULL,	--	Treatment	ID
		treatment_desc				varchar(32)	NULL,	--	Treatment's	treatment_desc
		treatment_process_id		int			NULL,	--	Treatment's	treatment_process_id
		treatment_process			varchar(30)	NULL,	--	Treatment's	treatment_process	(desc)
		disposal_service_id			int			NULL,	--	Treatment's	disposal_service_id
		disposal_service_desc		varchar(20)	NULL,	--	Treatment's	disposal_service_desc
		wastetype_id				int			NULL,	--	Treatment's	wastetype_id
		wastetype_category			varchar(40)	NULL,	--	Treatment's	wastetype	category
		wastetype_description		varchar(60)	NULL,	--	Treatment's	wastetype	description
		bill_unit_code				varchar(4)	NULL,	--	Unit
		waste_code					varchar(4)	NULL,	--	Waste	Code
		profile_id					int			NULL,	--	Profile_id
		quote_id					int			NULL,	--	Quote	ID
		product_id					int			NULL,	--	BillingDetail	product_id,	for	id'ing	fees,	etc.
		product_code				varchar(15)	NULL,	-- Product Code
		approval_code				varchar(40)	NULL,	--	Approval	Code
		approval_desc				varchar(100) NULL,
		TSDF_code					Varchar(15)	NULL,	--	TSDF	Code
		TSDF_EQ_FLAG				Char(1)		NULL,	--	TSDF:	Is	this	an	EQ	tsdf?
		fixed_price_flag			char(1)		NULL,	--	Fixed	Price	Flag
		pricing_method				char(1)		NULL,	--	Calculated,	Actual,	etc.
		quantity_flag				char(1)		NULL,	--	T	=	has	quantities,	F	=	no	quantities,	so	0	used.
		JDE_BU						varchar(7)	NULL,	-- JDE Busines Unite
		JDE_object					varchar(5)	NULL,	-- JDE Object

		AX_MainAccount				varchar(20)	NULL,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
		AX_Dimension_1				varchar(20)	NULL,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
		AX_Dimension_2				varchar(20)	NULL,	-- AX_business_unit
		AX_Dimension_3				varchar(20) NULL,	-- AX_department
		AX_Dimension_4				varchar(20)	NULL,	-- AX_line_of_business
		AX_Dimension_5_Part_1		varchar(20) NULL,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
		AX_Dimension_5_Part_2		varchar(9)	NULL,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
		AX_Dimension_6				varchar(20)	NULL,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
		
		first_invoice_date			datetime	NULL,	-- Date of first invoice
		
		waste_code_uid				int			NULL,
		reference_code              varchar (32) NULL,
		job_type					char(1)		NULL,		-- Base or Event (B/E)
		purchase_order				varchar (20) NULL,
		release_code				varchar (20) NULL,
		ticket_number				int			NULL	-- WorkOrderHeader.ticket_number, for a work order, or for a receipt's linked work order
	)


	
--rb 04/10/2015 Helps when updating very large result sets
create index #idx_FlashWork on #FlashWork (trans_source, company_id, profit_ctr_id, receipt_id)

truncate table #FlashWork

SELECT  *
FROM    #FlashWork
WHERE trans_source = 'R'


SELECT * FROM workorderheader where total_price = 0 and start_date > '4/1/2013' and company_id = 14 and profit_ctr_id = 4
8799100
SELECT * FROM workorderheader where workorder_id = 8799100 and company_id = 14 and profit_ctr_id = 4
SELECT * FROM workorderdetail where workorder_id = 8799100 and company_id = 14 and profit_ctr_id = 4

truncate table #FlashWork

EXEC sp_rpt_flash_calc
	@copc_list			= 'ALL',
	@date_from			= '10/1/2022', --'12/31/2013',
	@date_to			= '12/30/2022', --'10/31/2011',
	@cust_id_from		= '15340',
	@cust_id_to			= 15340,
	@cust_type_list		= '*Any*',
	@invoice_flag		= 'N',
	@source_list		= 'R,W,O',		--'R,W,O',
	@copc_search_type	= 'D', /* 'T'ransaction facility (native, default) or 'D'istribution facility */
	@transaction_type	= 'A', /* 'A'll, 'N'ative only (or Not split), 'S'plit between facilities only */
	@debug_flag			= 0

SELECT  * FROM    #FlashWork WHERE  receipt_id = 23645028

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#keysir populated from billing/detail for receipts' as status
	-- was 564773						


SELECT  *
FROM    #FlashWork

SELECT  *
FROM    #BillingDetail
WHERE trans_source = 'R'

-- U = 73
-- S = 0
-- N = 73
SELECT * FROM #FlashWork 

drop table #invoicestats

select min(ih.invoice_date) first_invoice_date, max(ih.invoice_date) last_invoice_date,
f.company_id, f.profit_ctr_id, f.receipt_id
into #invoicestats
from #FlashWork f
left join InvoiceDetail id
	on f.company_id = id.company_id
	and f.profit_ctr_id = id.profit_ctr_id
	and f.receipt_id = id.receipt_id
left join InvoiceHeader ih
	on id.invoice_id = ih.invoice_id
	and id.revision_id = ih.revision_id
group by 
f.company_id, f.profit_ctr_id, f.receipt_id

SELECT  *
FROM    #invoicestats
where first_invoice_date <> last_invoice_date



where exists (select 1 from adj

SELECT  *
FROM    InvoiceBillingDetail where receipt_id = 230620 and company_id = 22

-- v1: 23:30 to run.  31,704 rows.  and 30,844 of them aren't the ones we want.  What a waste.
-- v2:  3:31 to run.   3,232 rows.

SELECT * FROM #FlashWork where receipt_id = 8799100 and company_id = 14 and profit_ctr_id = 4

SELECT * FROM billing where receipt_id = 992 and company_id = 29
sp_report_eqip_flash_detail '1/21/2012','2/12/2012', 'RICH_G', 89, '22|2', 0,999999,'N','R,W,O', 'E'


*********************************************************************************************/
-- Alternate table instead of #Flashwork, for internal use with additional fields


/*
-- debugging setup:
declare
	@copc_list				VARCHAR(MAX),
	@date_from				DATETIME = NULL,
	@date_to				DATETIME = NULL,
	@cust_id_from			varchar(max),
	@cust_id_to				varchar(max),
	@cust_type_list			varchar(max) = '',
	@cust_category_list		varchar(max) = '',
	@invoice_flag			VARCHAR(MAX),  /* 'I'nvoiced, 'N'ot invoiced,   or   special subsets of 'N': 'S'ubmitted, 'U'nsubmitted  */
	@source_list			VARCHAR(MAX),  /* 'R'eceipt, 'W'orkorder */
	@copc_search_type		char(1) = 'T', /* 'T'ransaction facility (native, default) or 'D'istribution facility */
	@transaction_type		char(1) = 'A', /* 'A'll, 'N'ative only (or Not split), 'S'plit between facilities only */
	@debug_flag				INT = 0

select @copc_list			= 'ALL',
	@date_from				= '10/1/2022',
	@date_to				= '3/31/2023',
	@cust_id_from			= 0,
	@cust_id_to				= 9999999,
	@cust_type_list			= '',
	@cust_category_list		= '',
	@invoice_flag			= 'N',
	@source_list			= 'W',
	@copc_search_type		= 'T',
	@transaction_type		= 'A',
	@debug_flag				= 0

-- end of debugging setup
*/

-- set 	@debug_flag			= 1
declare @debuglog table (
	time_now datetime
	, total_elapsed bigint
	, step_elapsed bigint
	, status varchar(1000)
)

DROP TABLE IF EXISTS #InternalFlashWork
CREATE TABLE #InternalFlashWork (

	--	Header info:
		company_id					int			NULL,
		profit_ctr_id				int			NULL,
		trans_source				char(2)		NULL,	--	Receipt,	Workorder,	Workorder-Receipt,	etc
		receipt_id					int			NULL,	--	Receipt/Workorder	ID
		trans_type					char(1)		NULL,	--	Receipt	trans	type	(O/I)
		link_flag					char(1)		NULL,	--  if R/WO, is this linked to a WO/R? T/F
		linked_record				varchar(255)	NULL,	-- if R, list of WO's linked to (prob. just 1, but multiple poss.)
		workorder_type				varchar(40)	NULL,	--	WorkOrderType.account_desc
		trans_status				char(1)		NULL,	--	Receipt	or	Workorder	Status
		status_description			varchar(40) NULL,	--  Billing/Transaction Status (Invoiced, Billing Validated, Accepted, etc)
		trans_date					datetime	NULL,	--	Receipt	Date	or	Workorder	End	Date
		pickup_date					datetime	NULL,	--  Receipt Pickup Date or Workorder Pickup Date (transporter 1 sign date either way)
		submitted_flag				char(1)		NULL,	--	Submitted	Flag
		date_submitted				datetime	NULL,	--  Submitted Date
		submitted_by				varchar(10)	NULL,	--  Submitted By
		billing_status_code			char(1)		NULL,	--  Billing Status Code
		territory_code				varchar(8)	NULL,	--	Billing	Project	Territory	code
		billing_project_id			int			NULL,	--	Billing	project	ID
		billing_project_name		varchar(40)	NULL,	--	Billing	Project	Name
		invoice_flag				char(1)		NULL,	--  'T'/'F' (Invoiced/Not Invoiced)
		invoice_code				varchar(16)	NULL,	--	Invoice	Code	(if	invoiced)
		invoice_date				datetime	NULL,	--	Invoice	Date	(if	invoiced)
		invoice_month				int			NULL,	--	Invoice	Date	month
		invoice_year				int			NULL,	--	Invoice	Date	year
		customer_id					int			NULL,	--	Customer	ID	on	Receipt/Workorder
		cust_name					varchar(75)	NULL,	--	Customer	Name
		customer_type				varchar(20)	NULL,	--  Customer Type
		cust_category				varchar(30) NULL,	--	Customer Category

	--	Detail info:
		line_id						int			NULL,	--	Receipt	line	id
		price_id					int			NULL,	--	Receipt	line	price	id
		ref_line_id					int			NULL,	--	Billing	reference	line_id	(which	line	does	this	refer	to?)
		workorder_sequence_id		varchar(15)	NULL,	--	Workorder	sequence	id
		workorder_resource_item		varchar(15)	NULL,	--	Workorder	Resource	Item
		workorder_resource_type		varchar(15)	NULL,	--	Workorder	Resource	Type
		Workorder_resource_category	Varchar(40)	NULL,	--	Workorder	Resource	Category
		quantity					float		NULL,	--	Receipt/Workorder	Quantity
		billing_type				varchar(20)	NULL,	--	'Energy',	'Insurance',	'Salestax'	etc.
		dist_flag					char(1)		NULL,	--	'D', 'N' (Distributed/Not Distributed -- if the dist co/pc is diff from native co/pc, this is D)
		dist_company_id				int			NULL,	--	Distribution	Company	ID	(which	company	receives	the	revenue)
		dist_profit_ctr_id			int			NULL,	--	Distribution	Profit	Ctr	ID	(which	profitcenter	receives	the	revenue)
		gl_account_code				varchar(12)	NULL,	--	GL	Account	for	the	revenue
		gl_native_code				varchar(5)	NULL,	--	GL Native code (first 5 characters)
		gl_dept_code				varchar(3)	NULL,	--	GL Dept (last 3 characters)
		extended_amt				float			NULL,	--	Revenue	amt
		generator_id				int			NULL,	--	Generator	ID
		generator_name				varchar(75)	NULL,	--	Generator	Name
		epa_id						varchar(12)	NULL,	--	Generator	EPA	ID
		treatment_id				int			NULL,	--	Treatment	ID
		treatment_desc				varchar(32)	NULL,	--	Treatment's	treatment_desc
		treatment_process_id		int			NULL,	--	Treatment's	treatment_process_id
		treatment_process			varchar(30)	NULL,	--	Treatment's	treatment_process	(desc)
		disposal_service_id			int			NULL,	--	Treatment's	disposal_service_id
		disposal_service_desc		varchar(20)	NULL,	--	Treatment's	disposal_service_desc
		wastetype_id				int			NULL,	--	Treatment's	wastetype_id
		wastetype_category			varchar(40)	NULL,	--	Treatment's	wastetype	category
		wastetype_description		varchar(60)	NULL,	--	Treatment's	wastetype	description
		bill_unit_code				varchar(4)	NULL,	--	Unit
		waste_code					varchar(4)	NULL,	--	Waste	Code
		profile_id					int			NULL,	--	Profile_id
		quote_id					int			NULL,	--	Quote	ID
		product_id					int			NULL,	--	BillingDetail	product_id,	for	id'ing	fees,	etc.
		product_code				varchar(15)	NULL,	-- Product Code
		approval_code				varchar(40)	NULL,	--	Approval	Code
		approval_desc				varchar(100) NULL,
		TSDF_code					Varchar(15)	NULL,	--	TSDF	Code
		TSDF_EQ_FLAG				Char(1)		NULL,	--	TSDF:	Is	this	an	EQ	tsdf?
		fixed_price_flag			char(1)		NULL,	--	Fixed	Price	Flag
		pricing_method				char(1)		NULL,	--	Calculated,	Actual,	etc.
		quantity_flag				char(1)		NULL,	--	T	=	has	quantities,	F	=	no	quantities,	so	0	used.
		JDE_BU						varchar(7)	NULL,	-- JDE Busines Unite
		JDE_object					varchar(5)	NULL,	-- JDE Object

		AX_MainAccount				varchar(20)	NULL,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
		AX_Dimension_1				varchar(20)	NULL,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
		AX_Dimension_2				varchar(20)	NULL,	-- AX_business_unit
		AX_Dimension_3				varchar(20) NULL,	-- AX_department
		AX_Dimension_4				varchar(20)	NULL,	-- AX_line_of_business
		AX_Dimension_5_Part_1		varchar(20) NULL,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
		AX_Dimension_5_Part_2		varchar(9)	NULL,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
		AX_Dimension_6				varchar(20)	NULL,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
		
		first_invoice_date			datetime	NULL,	-- Date of first invoice
		
		waste_code_uid				int			NULL,
		reference_code              varchar (32) NULL,
		job_type					char(1)		NULL,		-- Base or Event (B/E)
		purchase_order				varchar (20) NULL,
		release_code				varchar (20) NULL,
		ticket_number				int			NULL	-- WorkOrderHeader.ticket_number, for a work order, or for a receipt's linked work order

		,billing_uid				bigint NULL
		,billing_date				datetime NULL
		,workorder_startdate		datetime NULL

	)



--rb 04/08/2015
set transaction isolation level read uncommitted

--rb 04/14/2015 Add index here so all calling procs do not have to change
if not exists (select 1 from tempdb..sysindexes
				where id = object_id('tempdb..#InternalFlashWork')
				and name = '#idx_FlashWork')
	create index #idx_FlashWork on #InternalFlashWork (trans_source, company_id, profit_ctr_id, receipt_id)

-- set @debug_flag = 0
declare @timestart datetime = getdate(), @lasttime datetime = getdate()

insert @debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting Proc' as status
set @lasttime = getdate()

-- Setup
--------------------------------------------------------------
-- drop table #tmp_trans_copc

	-- Create & Populate #tmp_trans_copc
	Drop Table If Exists #tmp_trans_copc 
	CREATE TABLE #tmp_trans_copc (
		company_id INT NULL,
		profit_ctr_id INT NULL,
		base_rate_quote_id INT NULL
	)

	-- About this next part...
	-- Normally, we'd just say "If it's ALL, load from profitcenter. Otherwise load from the string they sent."
	-- Everything was a search against the Transaction company.
	-- But upon introducing "search by Transaction company OR Distribution company" (@copc_search_type)...
	-- We can't tell up front where the Distribution company records will come from, so we have to include ALL
	-- No matter what they picked... and filter the results later when those fields are available.
	-- This won't be good for performance.  Oh well.
	-- 1/19/2012 - JPB
	-- On second thought... All split info is contained in ProfileQuoteDetailSplitGroup.  That's handy.  We could
	-- limit the select for Distribution info to receipts containing profiles in that table for the co/pc(s)
	-- sought.  So leave the #tmp_trans_copc table as-was, we'll tweak the #keys section.  Oh, which doesn't exist. Hmm.
	-- 2/6/2012 - JPB
	-- 4/25/2013 - JPB
	-- Shortly after that "shortcut" realization on 2/6/2012, EQAI was updated to allow "unbundled" distributed
	-- revenue by adding products from other companies to profiles, without using ProfileQuoteDetailSplitGroup.  This
	-- results in some splits not being reported at all (unbundled splits, or products from another co/pc.
	-- So we're changing the distributed/split logic to keep the shortcut, but also add a check for unbundled splits.

	IF LTRIM(RTRIM(ISNULL(@copc_list, ''))) = 'ALL' -- OR @copc_search_type = 'D'
		INSERT #tmp_trans_copc
		SELECT Profitcenter.company_id, Profitcenter.profit_ctr_id, Profitcenter.base_rate_quote_id
		FROM ProfitCenter
		WHERE ProfitCenter.status = 'A'
	ELSE
		INSERT #tmp_trans_copc
		SELECT Profitcenter.company_id, Profitcenter.profit_ctr_id, Profitcenter.base_rate_quote_id
		FROM ProfitCenter
		INNER JOIN (
			SELECT
				RTRIM(LTRIM(SUBSTRING(ROW, 1, CHARINDEX('|',ROW) - 1))) company_id,
				RTRIM(LTRIM(SUBSTRING(ROW, CHARINDEX('|',ROW) + 1, LEN(ROW) - (CHARINDEX('|',ROW)-1)))) profit_ctr_id
			FROM dbo.fn_SplitXsvText(',', 0, @copc_list)
			WHERE ISNULL(ROW, '') <> '') selected_copc ON
				ProfitCenter.company_id = selected_copc.company_id
				AND ProfitCenter.profit_ctr_id = selected_copc.profit_ctr_id
		WHERE ProfitCenter.status = 'A'

insert @debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Populated #tmp_trans_copc' as status
set @lasttime = getdate()

	Drop Table If Exists #tmp_source
	CREATE TABLE #tmp_source (
		trans_source				char(1)
	)
	INSERT #tmp_source
	SELECT row
	FROM dbo.fn_SplitXsvText(',', 1, @source_list)
	WHERE isnull(row,'') <> ''
	-- truncate table #tmp_source
	-- insert #tmp_source select 'W' union select 'R'

insert @debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Populated #tmp_source' as status
set @lasttime = getdate()


--Customer Filter
-- declare @cust_type_list varchar(max) = '', @cust_id_from varchar(max) = '1125,3770', @cust_id_to int = 9999999


--rb 04/10/2015
declare @CustomerType table (
	customer_type	varchar(20)
)

--rb 04/10/2015
if ISNULL(@cust_type_list,'') in ('', '*Any*')
begin
	insert @CustomerType
	select customer_type from CustomerType

	insert @CustomerType values ('')
	insert @CustomerType values (null)
end
else
	insert @CustomerType
	select customer_type
	from CustomerType
	where customer_type in (
		select CONVERT(varchar(20), row)
		from dbo.fn_SplitXsvText(',', 1, @cust_type_list)
		where row is not null
	)

-- SELECT  * FROM    @CustomerType

declare @CustomerCategory table (
	cust_category	varchar(30)
)

--jpb 02/14/2022
if ISNULL(@cust_category_list,'') in ('', '*Any*')
begin
	insert @CustomerCategory
	select category from CustomerCategory

	insert @CustomerCategory values ('')
	insert @CustomerCategory values (null)
end
else
	insert @CustomerCategory
	select category
	from CustomerCategory
	where category in (
		select CONVERT(varchar(30), row)
		from dbo.fn_SplitXsvText(',', 1, @cust_category_list)
		where row is not null
	)

-- SELECT  * FROM    @CustomerCategory

declare @customer table (customer_id int, cust_name varchar(75), customer_type varchar(20), cust_category varchar(30))

if len(ltrim(rtrim(@cust_id_from))) = 0 
	set @cust_id_from = '0'
	-- if @cust_id_from is blank, (should never happen) set it to '0' (the beginning of ALL)
	
set @cust_id_from = replace(replace(@cust_id_from, ' ', ','), ',,', ',')
-- replace any spaces in @cust_id_from with commas - to make a CSV list

if len(ltrim(rtrim(@cust_id_to))) = 0 
	set @cust_id_to = '9999999'
	-- if @cust_id_from is blank, (should never happen) set it to '0' (the beginning of ALL)

set @cust_id_to = replace(replace(@cust_id_to, ' ', ','), ',,', ',')
-- replace any spaces in @cust_id_from with commas - to make a CSV list


if @cust_id_from not like '%,%' and @cust_id_from not like '%-%' 
	set @cust_id_from = @cust_id_from + isnull('-' + @cust_id_to, '')
	-- if @cust_id_from has no special handling (ranges, lists), just append "-" + cust_id_to
	-- i.e. make it a range from FROM to TO. parseRanges will handle it.
	
else
	set @cust_id_from = @cust_id_from + ',' + isnull(@cust_id_to, @cust_id_from)
	-- cust_id_from DOES have some special handling (range, csv) already, so just append the value from TO in it



-- fill @customer with Customer table values found in the cust_id_from value now
insert @customer (customer_id, cust_name, customer_type, cust_category)
select c.customer_id, c.cust_name, c.customer_type, c.cust_category
from customer c
join dbo.fn_parseRanges(@cust_id_from) ranges
on c.customer_id between ranges.rangeStart and ranges.rangeEnd
join @CustomerType ct
	on isnull(c.customer_type, '') = ct.customer_type
join @CustomerCategory cc
	on isnull(c.cust_category, '') = cc.cust_category
WHERE @cust_id_from not like '%C%' -- ax customer ID indicator


insert @customer (customer_id, cust_name, customer_type, cust_category)
select c.customer_id, c.cust_name, c.customer_type, c.cust_category
from customer c
join dbo.fn_parseRanges(@cust_id_from) ranges
on c.ax_customer_id between ranges.rangeStart and ranges.rangeEnd
join @CustomerType ct
	on c.customer_type = ct.customer_type
join @CustomerCategory cc
	on c.cust_category = cc.cust_category
WHERE @cust_id_from like '%C%' -- ax customer ID indicator


--------------------------------------------------------------

-- Prepare Billing records
Drop Table If Exists #Billing
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
	generator_name			varchar (75) NULL,
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
	currency_code			char(3) NULL
)
--rb 04/10/2015 Helps when updating very large result sets
create index #idx_Billing on #Billing (trans_source, company_id, profit_ctr_id, receipt_id)
create index #idx_Billing_keys on #Billing (receipt_id, company_id, profit_ctr_id, line_id) include(price_id, trans_source, trans_type, product_id)
create index #idx_Billing_uid on #Billing(billing_uid)
create index #idx_Billing_profile on #Billing(company_id, profit_ctr_id, profile_id)

Drop Table If Exists #BillingComment
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
Drop Table If Exists #BillingDetail
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
	currency_code		char(3)			NULL
)
--rb 04/10/2015 Helps when updating very large result sets
create index #idx_BillingDetail on #BillingDetail (billing_uid) include (billing_type)
create index #idx_BillingDetail_ids on #BillingDetail (company_id, profit_ctr_id, receipt_id) include (line_id, price_id, sequence_id, product_id, billing_type)

-- Prepare SalesTax records
Drop Table If Exists #SalesTax
CREATE TABLE #SalesTax  (
	sales_tax_id		int				NULL
)


insert @debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Created #Billing, #BillingComment, ... #SalesTax tables' as status
set @lasttime = getdate()

-- declare @date_from datetime = '12/1/2015', @date_to datetime = '12/15/2015', @debug_flag int = 0, @cust_id_from int = 0, @cust_id_to int = 9999999, @invoice_flag char(1) = 'U', @cust_type_list varchar(20) = '*Any*', @lasttime datetime

-- Fix/Set @date_to's time.
IF @invoice_flag = 'I' BEGIN -- Dates are required
	if @date_from is null BEGIN
		RAISERROR ('@date_from is required when running against Invoiced records.', 16, 1)
		RETURN
	END
	if @date_to is null BEGIN
		RAISERROR ('@date_to is required when running against Invoiced records.', 16, 1)
		RETURN
	END
END ELSE BEGIN
	if @date_from is null set @date_from = '1/1/1900'
	if @date_to is null set @date_to = dateadd(yyyy, 1, getdate())
END

IF ISNULL(@date_to,'') <> ''
	IF DATEPART(hh, @date_to) = 0 SET @date_to = @date_to + 0.99999

declare @Billing_Status_Code table (
	status_code	char(1)
)


insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '@date var setup finished' as status
set @lasttime = getdate()

-----------------------------------------------------------------------------------
-- INVOICED RECORDS
if isnull(@invoice_flag, '') = 'I'
	insert @billing_status_code select 'I'
ELSE
	insert @billing_status_code select distinct status_code from billing where status_code not in ('I', 'V')

-- Change of plans.  ALL cases run this, because not-invoiced records need this info too.
-----------------------------------------------------------------------------------
	/*

	Population of FlashWork table:

	IN BILLING email content

	If in billing
		Use billing detail -
		Pricing method = 'A'
	*/

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "In Billing (Workorder), Actual #InternalFlashWork" Population' as status
	set @lasttime = getdate()

--#region trans_source W
--rb 04/10/2015 Had to break single select into 4 separates so indexes to make use of indexes on billing_date/invoice_date, and to allow co/pc join to be defined
IF exists (select 1 from #tmp_source where trans_source = 'W')
BEGIN

--#region copc-search-type-T 1
	if @copc_search_type = 'T'
	begin
		if isnull(@invoice_flag,'') = 'I'
			INSERT #InternalFlashWork (
				company_id					,
				profit_ctr_id				,
				trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
				receipt_id					, -- Receipt/Workorder ID
				trans_type					, -- Receipt trans type (O/I)
				link_flag					,
				linked_record				,
				workorder_type				, -- WorkOrderType.account_desc
				trans_status				, -- Receipt or Workorder Status
				status_description			, -- Billing/Transaction status description
				trans_date					, -- Receipt Date or Workorder End Date
				pickup_date					, -- Pickup Date
				submitted_flag				, -- Submitted Flag
				date_submitted				, -- Submitted Date
				submitted_by				, -- Submitted by
				billing_status_code			, -- Billing Status Code
				territory_code				, -- Billing Project Territory code
				billing_project_id			, -- Billing project ID
				billing_project_name		, -- Billing Project Name
				invoice_flag				, -- Invoiced? Flag
				invoice_code				, -- Invoice Code (if invoiced)
				invoice_date				, -- Invoice Date (if invoiced)
				invoice_month				, -- Invoice Date month
				invoice_year				, -- Invoice Date year
				customer_id					, -- Customer ID on Receipt/Workorder
				cust_name					, -- Customer Name
				customer_Type				, -- Customer Type
				cust_category				, -- Customer Category
				line_id						, -- Receipt line id
				price_id					, -- Receipt line price id
				ref_line_id					, -- Billing reference line_id (which line does this refer to?)
				workorder_sequence_id		, -- Workorder sequence id
				workorder_resource_item		, -- Workorder Resource Item
				workorder_resource_type		, -- Workorder Resource Type
				quantity					, -- Receipt/Workorder Quantity
				billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
				dist_flag					, -- Distributed Transaction?
				dist_company_id				, -- Distribution Company ID (which company receives the revenue)
				dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
				gl_account_code				, -- GL Account for the revenue
				extended_amt				, -- Revenue amt
				generator_id				, -- Generator ID
				generator_name				, -- Generator Name
				epa_id						, -- Generator EPA ID
				bill_unit_code				, -- Unit
				waste_code					, -- Waste Code
				profile_id					, -- Profile_id
				quote_id					, -- Quote ID
				approval_code				, -- Approval Code
				approval_desc				,
				fixed_price_flag			, -- Fixed Price Flag
				pricing_method				, -- Calculated, Actual, etc.
				quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
				JDE_BU						,
				JDE_object					,
				AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				AX_Dimension_2				,	-- AX_business_unit
				AX_Dimension_3				,	-- AX_department
				AX_Dimension_4				,	-- AX_line_of_business
				AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				waste_code_uid				,
				reference_code				,
				purchase_order				,
				release_code				,	
				ticket_number					-- WorkOrderHeader.ticket_number
				,billing_uid				
				,billing_date				
				,workorder_startdate		
			)
			SELECT
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.trans_type,
				link_flag = (
				select
				isnull(
					(
					select top 1 case link_required_flag when 'E' then 'E' else 'T' end
					from billinglinklookup (nolock)
					where source_id = b.receipt_id 
					and source_company_id = b.company_id
					and source_profit_ctr_id = b.profit_ctr_id
					ORDER BY isnull(link_required_flag, 'Z')
					)
				, 'F')
				),
				/*
				case when exists (
					select 1 from billinglinklookup (nolock)
					where source_id = b.receipt_id 
					and source_company_id = b.company_id
					and source_profit_ctr_id = b.profit_ctr_id
					and link_required_flag = 'E'
					) then 'E' 
					else 
						case when exists (
							select 1 from billinglinklookup (nolock)
							where source_id = b.receipt_id 
							and source_company_id = b.company_id
							and source_profit_ctr_id = b.profit_ctr_id
							and link_required_flag <> 'E'
						) then 'T' else 'F' 
					end 
				end AS link_flag,
				*/
				null as linked_record, -- Wo's don't list these.  R's do.
				woth.account_desc,
				woh.workorder_status,
				case when b.status_code = 'I' then 'Invoiced' else 
					CASE woh.workorder_status
						WHEN 'A' THEN 'Accepted'
						WHEN 'C' THEN 'Completed'
						WHEN 'N' THEN 'New'
					END
				end as status_description,
				woh.start_date,
				COALESCE(wos.date_act_arrive, woh.start_date) as pickup_date,
				woh.submitted_flag,
				woh.date_submitted,
				woh.submitted_by,
				b.status_code as billing_status_code,
				cb.territory_code,
				cb.billing_project_id,
				cb.project_name,
				case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
				b.invoice_code,
				b.invoice_date,
				MONTH(b.invoice_date),
				YEAR(b.invoice_date),
				c.customer_id,
				c.cust_name,
				c.customer_type,
				c.cust_category,
				b.line_id,
				b.price_id,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				bd.billing_type,
				case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end,
				bd.dist_company_id,
				bd.dist_profit_ctr_id,
				bd.gl_account_code,
				bd.extended_amt,
				g.generator_id,
				g.generator_name,
				g.epa_id,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				woh.quote_id,
				b.approval_code,
				b.service_desc_1,
				woh.fixed_price_flag,
				'A' as pricing_method,
				'T' as quantity_flag,
				NULL as JDE_BU, --bd.JDE_BU,
				NULL as JDE_Object, -- bd.JDE_object,
				
				bd.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				bd.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				bd.AX_Dimension_2				,	-- AX_business_unit
				bd.AX_Dimension_3				,	-- AX_department
				bd.AX_Dimension_4				,	-- AX_line_of_business
				bd.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				
				b.waste_code_uid,
				b.reference_code,
				b.purchase_order,
				b.release_code,
				woh.ticket_number
				, b.billing_uid
				, b.billing_date
				, woh.start_date
			FROM Billing b WITH (INDEX(idx_billing_status_date))
			--rb 04/08/2015
			--INNER JOIN #tmp_source ts
			--	ON ts.trans_source = b.trans_source
			INNER JOIN BillingDetail bd (nolock)
				ON bd.billing_uid = b.billing_uid
			INNER JOIN WorkOrderHeader woh (nolock)
				ON b.receipt_id = woh.workorder_id
				AND b.company_id = woh.company_id
				AND b.profit_ctr_id = woh.profit_ctr_id
			INNER JOIN  WorkOrderTypeHeader woth (nolock)
				ON woh.workorder_type_id = woth.workorder_type_id
			--rb 04/10/2015
			join #tmp_trans_copc copc
				on b.company_id = copc.company_id
				and b.profit_ctr_id = copc.profit_ctr_id
			join @customer c on b.customer_id = c.customer_id
			LEFT OUTER JOIN CustomerBilling cb (nolock)
				ON b.customer_id = cb.customer_id
				AND ISNULL(b.billing_project_id, 0) = cb.billing_project_id
			LEFT OUTER JOIN generator g (nolock)
				ON b.generator_id = g.generator_id
			LEFT JOIN workorderstop wos (nolock)
				ON woh.workorder_id = wos.workorder_id
				and wos.stop_sequence_id = 1
				and woh.company_id = wos.company_id
				and woh.profit_ctr_id = wos.profit_ctr_id
			WHERE 1=1
			-- AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND b.trans_source = 'W'
			AND b.status_code in (select status_code from @billing_status_code)
			-- rb 04/06/2015
			AND b.invoice_date between @date_from and @date_to
		else if isnull(@invoice_flag,'') in ('N', 'S') -- We're pulling from Billing, so it can't be "U"nsubmitted, and this isn't the "I"nvoiced section, so it's N/S
			INSERT #InternalFlashWork (
				company_id					,
				profit_ctr_id				,
				trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
				receipt_id					, -- Receipt/Workorder ID
				trans_type					, -- Receipt trans type (O/I)
				link_flag					,
				linked_record				,
				workorder_type				, -- WorkOrderType.account_desc
				trans_status				, -- Receipt or Workorder Status
				status_description			, -- Billing/Transaction status description
				trans_date					, -- Receipt Date or Workorder End Date
				pickup_date					, -- Pickup Date
				submitted_flag				, -- Submitted Flag
				date_submitted				, -- Submitted Date
				submitted_by				, -- Submitted by
				billing_status_code			, -- Billing Status Code
				territory_code				, -- Billing Project Territory code
				billing_project_id			, -- Billing project ID
				billing_project_name		, -- Billing Project Name
				invoice_flag				, -- Invoiced? Flag
				invoice_code				, -- Invoice Code (if invoiced)
				invoice_date				, -- Invoice Date (if invoiced)
				invoice_month				, -- Invoice Date month
				invoice_year				, -- Invoice Date year
				customer_id					, -- Customer ID on Receipt/Workorder
				cust_name					, -- Customer Name
				customer_Type				, -- Customer Type
				cust_category				, -- Customer Category
				line_id						, -- Receipt line id
				price_id					, -- Receipt line price id
				ref_line_id					, -- Billing reference line_id (which line does this refer to?)
				workorder_sequence_id		, -- Workorder sequence id
				workorder_resource_item		, -- Workorder Resource Item
				workorder_resource_type		, -- Workorder Resource Type
				quantity					, -- Receipt/Workorder Quantity
				billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
				dist_flag					, -- Distributed Transaction?
				dist_company_id				, -- Distribution Company ID (which company receives the revenue)
				dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
				gl_account_code				, -- GL Account for the revenue
				extended_amt				, -- Revenue amt
				generator_id				, -- Generator ID
				generator_name				, -- Generator Name
				epa_id						, -- Generator EPA ID
				bill_unit_code				, -- Unit
				waste_code					, -- Waste Code
				profile_id					, -- Profile_id
				quote_id					, -- Quote ID
				approval_code				, -- Approval Code
				approval_desc				,
				fixed_price_flag			, -- Fixed Price Flag
				pricing_method				, -- Calculated, Actual, etc.
				quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
				JDE_BU						,
				JDE_object					,
				AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				AX_Dimension_2				,	-- AX_business_unit
				AX_Dimension_3				,	-- AX_department
				AX_Dimension_4				,	-- AX_line_of_business
				AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				waste_code_uid				,
				reference_code ,
				purchase_order				,
				release_code				,	
				ticket_number					-- WorkOrderHeader.ticket_number
				,billing_uid				
				,billing_date				
				,workorder_startdate		
			)
			SELECT
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.trans_type,
				link_flag = (
				select
				isnull(
					(
					select top 1 case link_required_flag when 'E' then 'E' else 'T' end
					from billinglinklookup (nolock)
					where source_id = b.receipt_id 
					and source_company_id = b.company_id
					and source_profit_ctr_id = b.profit_ctr_id
					ORDER BY isnull(link_required_flag, 'Z')
					)
				, 'F')
				),
				/*
				case when exists (
					select 1 from billinglinklookup (nolock)
					where source_id = b.receipt_id 
					and source_company_id = b.company_id
					and source_profit_ctr_id = b.profit_ctr_id
					and link_required_flag = 'E'
					) then 'E' 
					else 
						case when exists (
							select 1 from billinglinklookup (nolock)
							where source_id = b.receipt_id 
							and source_company_id = b.company_id
							and source_profit_ctr_id = b.profit_ctr_id
							and link_required_flag <> 'E'
						) then 'T' else 'F' 
					end 
				end AS link_flag,
				*/
				null as linked_record, -- Wo's don't list these.  R's do.
				woth.account_desc,
				woh.workorder_status,
				case when b.status_code = 'I' then 'Invoiced' else 
					CASE woh.workorder_status
						WHEN 'A' THEN 'Accepted'
						WHEN 'C' THEN 'Completed'
						WHEN 'N' THEN 'New'
					END
				end as status_description,
				woh.start_date,
				COALESCE(wos.date_act_arrive, woh.start_date) as pickup_date,
				woh.submitted_flag,
				woh.date_submitted,
				woh.submitted_by,
				b.status_code as billing_status_code,
				cb.territory_code,
				cb.billing_project_id,
				cb.project_name,
				case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
				b.invoice_code,
				b.invoice_date,
				MONTH(b.invoice_date),
				YEAR(b.invoice_date),
				c.customer_id,
				c.cust_name,
				c.customer_type,
				c.cust_category,
				b.line_id,
				b.price_id,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				bd.billing_type,
				case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end,
				bd.dist_company_id,
				bd.dist_profit_ctr_id,
				bd.gl_account_code,
				bd.extended_amt,
				g.generator_id,
				g.generator_name,
				g.epa_id,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				woh.quote_id,
				b.approval_code,
				b.service_desc_1,
				woh.fixed_price_flag,
				'A' as pricing_method,
				'T' as quantity_flag,
				NULL as JDE_BU, --bd.JDE_BU,
				NULL as JDE_Object, -- bd.JDE_object,
				bd.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				bd.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				bd.AX_Dimension_2				,	-- AX_business_unit
				bd.AX_Dimension_3				,	-- AX_department
				bd.AX_Dimension_4				,	-- AX_line_of_business
				bd.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				b.waste_code_uid,
				b.reference_code,
				b.purchase_order,
				b.release_code,
				woh.ticket_number
				, b.billing_uid
				, b.billing_date
				, woh.start_date
			FROM Billing b WITH (INDEX(idx_billing_actual_status_date))
			--rb 04/08/2015
			--INNER JOIN #tmp_source ts
			--	ON ts.trans_source = b.trans_source
			INNER JOIN BillingDetail bd (nolock)
				ON bd.billing_uid = b.billing_uid
			INNER JOIN WorkOrderHeader woh (nolock)
				ON b.receipt_id = woh.workorder_id
				AND b.company_id = woh.company_id
				AND b.profit_ctr_id = woh.profit_ctr_id
			INNER JOIN  WorkOrderTypeHeader woth (nolock)
				ON woh.workorder_type_id = woth.workorder_type_id
			--rb 04/10/2015
			join #tmp_trans_copc copc
				on b.company_id = copc.company_id
				and b.profit_ctr_id = copc.profit_ctr_id
			join @customer c on b.customer_id = c.customer_id
			LEFT OUTER JOIN CustomerBilling cb (nolock)
				ON b.customer_id = cb.customer_id
				AND ISNULL(b.billing_project_id, 0) = cb.billing_project_id
			LEFT OUTER JOIN generator g (nolock)
				ON b.generator_id = g.generator_id
			LEFT JOIN workorderstop wos (nolock)
				ON woh.workorder_id = wos.workorder_id
				and wos.stop_sequence_id = 1
				and woh.company_id = wos.company_id
				and woh.profit_ctr_id = wos.profit_ctr_id
			WHERE 1=1
			-- AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND b.trans_source = 'W'
			AND b.status_code in (select status_code from @billing_status_code)
			-- rb 04/06/2015
			AND b.billing_date between @date_from and @date_to
	end

--#endregion
	else if @copc_search_type = 'D'
	begin
--#region invoice-flag-I 11

		if isnull(@invoice_flag,'') = 'I'
			INSERT #InternalFlashWork (
				company_id					,
				profit_ctr_id				,
				trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
				receipt_id					, -- Receipt/Workorder ID
				trans_type					, -- Receipt trans type (O/I)
				link_flag					,
				linked_record				,
				workorder_type				, -- WorkOrderType.account_desc
				trans_status				, -- Receipt or Workorder Status
				status_description			, -- Billing/Transaction status description
				trans_date					, -- Receipt Date or Workorder End Date
				pickup_date					, -- Pickup Date
				submitted_flag				, -- Submitted Flag
				date_submitted				, -- Submitted Date
				submitted_by				, -- Submitted by
				billing_status_code			, -- Billing Status Code
				territory_code				, -- Billing Project Territory code
				billing_project_id			, -- Billing project ID
				billing_project_name		, -- Billing Project Name
				invoice_flag				, -- Invoiced? Flag
				invoice_code				, -- Invoice Code (if invoiced)
				invoice_date				, -- Invoice Date (if invoiced)
				invoice_month				, -- Invoice Date month
				invoice_year				, -- Invoice Date year
				customer_id					, -- Customer ID on Receipt/Workorder
				cust_name					, -- Customer Name
				customer_Type				, -- Customer Type
				cust_category				, -- Customer Category
				line_id						, -- Receipt line id
				price_id					, -- Receipt line price id
				ref_line_id					, -- Billing reference line_id (which line does this refer to?)
				workorder_sequence_id		, -- Workorder sequence id
				workorder_resource_item		, -- Workorder Resource Item
				workorder_resource_type		, -- Workorder Resource Type
				quantity					, -- Receipt/Workorder Quantity
				billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
				dist_flag					, -- Distributed Transaction?
				dist_company_id				, -- Distribution Company ID (which company receives the revenue)
				dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
				gl_account_code				, -- GL Account for the revenue
				extended_amt				, -- Revenue amt
				generator_id				, -- Generator ID
				generator_name				, -- Generator Name
				epa_id						, -- Generator EPA ID
				bill_unit_code				, -- Unit
				waste_code					, -- Waste Code
				profile_id					, -- Profile_id
				quote_id					, -- Quote ID
				approval_code				, -- Approval Code
				approval_desc				,
				fixed_price_flag			, -- Fixed Price Flag
				pricing_method				, -- Calculated, Actual, etc.
				quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
				JDE_BU						,
				JDE_object					,
				AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				AX_Dimension_2				,	-- AX_business_unit
				AX_Dimension_3				,	-- AX_department
				AX_Dimension_4				,	-- AX_line_of_business
				AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				waste_code_uid				,
				reference_code ,
				purchase_order				,
				release_code				,	
				ticket_number					-- WorkOrderHeader.ticket_number
				,billing_uid				
				,billing_date				
				,workorder_startdate		
			)
			SELECT
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.trans_type,
				link_flag = (
				select
				isnull(
					(
					select top 1 case link_required_flag when 'E' then 'E' else 'T' end
					from billinglinklookup (nolock)
					where source_id = b.receipt_id 
					and source_company_id = b.company_id
					and source_profit_ctr_id = b.profit_ctr_id
					ORDER BY isnull (link_required_flag, 'Z')
					)
				, 'F')
				),
				/*
				case when exists (
					select 1 from billinglinklookup (nolock)
					where source_id = b.receipt_id 
					and source_company_id = b.company_id
					and source_profit_ctr_id = b.profit_ctr_id
					and link_required_flag = 'E'
					) then 'E' 
					else 
						case when exists (
							select 1 from billinglinklookup (nolock)
							where source_id = b.receipt_id 
							and source_company_id = b.company_id
							and source_profit_ctr_id = b.profit_ctr_id
							and link_required_flag <> 'E'
						) then 'T' else 'F' 
					end 
				end AS link_flag,
				*/
				null as linked_record, -- Wo's don't list these.  R's do.
				woth.account_desc,
				woh.workorder_status,
				case when b.status_code = 'I' then 'Invoiced' else 
					CASE woh.workorder_status
						WHEN 'A' THEN 'Accepted'
						WHEN 'C' THEN 'Completed'
						WHEN 'N' THEN 'New'
					END
				end as status_description,
				woh.start_date,
				COALESCE(wos.date_act_arrive, woh.start_date) as pickup_date,
				woh.submitted_flag,
				woh.date_submitted,
				woh.submitted_by,
				b.status_code as billing_status_code,
				cb.territory_code,
				cb.billing_project_id,
				cb.project_name,
				case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
				b.invoice_code,
				b.invoice_date,
				MONTH(b.invoice_date),
				YEAR(b.invoice_date),
				c.customer_id,
				c.cust_name,
				c.customer_type,
				c.cust_category,
				b.line_id,
				b.price_id,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				bd.billing_type,
				case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end,
				bd.dist_company_id,
				bd.dist_profit_ctr_id,
				bd.gl_account_code,
				bd.extended_amt,
				g.generator_id,
				g.generator_name,
				g.epa_id,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				woh.quote_id,
				b.approval_code,
				b.service_desc_1,
				woh.fixed_price_flag,
				'A' as pricing_method,
				'T' as quantity_flag,
				NULL as JDE_BU, --bd.JDE_BU,
				NULL as JDE_Object, -- bd.JDE_object,
				bd.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				bd.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				bd.AX_Dimension_2				,	-- AX_business_unit
				bd.AX_Dimension_3				,	-- AX_department
				bd.AX_Dimension_4				,	-- AX_line_of_business
				bd.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				b.waste_code_uid,
				b.reference_code,
				b.purchase_order,
				b.release_code,
				woh.ticket_number
				, b.billing_uid
				, b.billing_date
				, woh.start_date
			FROM Billing b WITH (INDEX(idx_billing_status_date))
			--rb 04/08/2015
			--INNER JOIN #tmp_source ts
			--	ON ts.trans_source = b.trans_source
			INNER JOIN BillingDetail bd (nolock)
				ON bd.billing_uid = b.billing_uid
			INNER JOIN WorkOrderHeader woh (nolock)
				ON b.receipt_id = woh.workorder_id
				AND b.company_id = woh.company_id
				AND b.profit_ctr_id = woh.profit_ctr_id
			INNER JOIN  WorkOrderTypeHeader woth (nolock)
				ON woh.workorder_type_id = woth.workorder_type_id
			join #tmp_trans_copc copc
				on bd.dist_company_id = copc.company_id
				and bd.dist_profit_ctr_id = copc.profit_ctr_id
			join @customer c on b.customer_id = c.customer_id
			LEFT OUTER JOIN CustomerBilling cb (nolock)
				ON b.customer_id = cb.customer_id
				AND ISNULL(b.billing_project_id, 0) = cb.billing_project_id
			LEFT OUTER JOIN generator g (nolock)
				ON b.generator_id = g.generator_id
			LEFT JOIN workorderstop wos (nolock)
				ON woh.workorder_id = wos.workorder_id
				and wos.stop_sequence_id = 1
				and woh.company_id = wos.company_id
				and woh.profit_ctr_id = wos.profit_ctr_id

			WHERE 1=1
			-- AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND b.trans_source = 'W'
			AND b.status_code in (select status_code from @billing_status_code)
			-- rb 04/06/2015
			AND b.invoice_date between @date_from and @date_to


--#endregion
		else if isnull(@invoice_flag,'') in ('N', 'S') -- We're pulling from Billing, so it can't be "U"nsubmitted, and this isn't the "I"nvoiced section, so it's N/S
			INSERT #InternalFlashWork (
				company_id					,
				profit_ctr_id				,
				trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
				receipt_id					, -- Receipt/Workorder ID
				trans_type					, -- Receipt trans type (O/I)
				link_flag					,
				linked_record				,
				workorder_type				, -- WorkOrderType.account_desc
				trans_status				, -- Receipt or Workorder Status
				status_description			, -- Billing/Transaction status description
				trans_date					, -- Receipt Date or Workorder End Date
				pickup_date					, -- Pickup Date
				submitted_flag				, -- Submitted Flag
				date_submitted				, -- Submitted Date
				submitted_by				, -- Submitted by
				billing_status_code			, -- Billing Status Code
				territory_code				, -- Billing Project Territory code
				billing_project_id			, -- Billing project ID
				billing_project_name		, -- Billing Project Name
				invoice_flag				, -- Invoiced? Flag
				invoice_code				, -- Invoice Code (if invoiced)
				invoice_date				, -- Invoice Date (if invoiced)
				invoice_month				, -- Invoice Date month
				invoice_year				, -- Invoice Date year
				customer_id					, -- Customer ID on Receipt/Workorder
				cust_name					, -- Customer Name
				customer_Type				, -- Customer Type
				cust_category				, -- Customer Category
				line_id						, -- Receipt line id
				price_id					, -- Receipt line price id
				ref_line_id					, -- Billing reference line_id (which line does this refer to?)
				workorder_sequence_id		, -- Workorder sequence id
				workorder_resource_item		, -- Workorder Resource Item
				workorder_resource_type		, -- Workorder Resource Type
				quantity					, -- Receipt/Workorder Quantity
				billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
				dist_flag					, -- Distributed Transaction?
				dist_company_id				, -- Distribution Company ID (which company receives the revenue)
				dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
				gl_account_code				, -- GL Account for the revenue
				extended_amt				, -- Revenue amt
				generator_id				, -- Generator ID
				generator_name				, -- Generator Name
				epa_id						, -- Generator EPA ID
				bill_unit_code				, -- Unit
				waste_code					, -- Waste Code
				profile_id					, -- Profile_id
				quote_id					, -- Quote ID
				approval_code				, -- Approval Code
				approval_desc				,
				fixed_price_flag			, -- Fixed Price Flag
				pricing_method				, -- Calculated, Actual, etc.
				quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
				JDE_BU						,
				JDE_object					,
				AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				AX_Dimension_2				,	-- AX_business_unit
				AX_Dimension_3				,	-- AX_department
				AX_Dimension_4				,	-- AX_line_of_business
				AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				waste_code_uid				,
				reference_code ,
				purchase_order				,
				release_code				,	
				ticket_number					-- WorkOrderHeader.ticket_number
				,billing_uid				
				,billing_date				
				,workorder_startdate		
			)
			SELECT
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.trans_type,
				link_flag = (
				select
				isnull(
					(
					select top 1 case link_required_flag when 'E' then 'E' else 'T' end
					from billinglinklookup (nolock)
					where source_id = b.receipt_id 
					and source_company_id = b.company_id
					and source_profit_ctr_id = b.profit_ctr_id
					ORDER BY isnull(link_required_flag, 'Z')
					)
				, 'F')
				),
				/*
				case when exists (
					select 1 from billinglinklookup (nolock)
					where source_id = b.receipt_id 
					and source_company_id = b.company_id
					and source_profit_ctr_id = b.profit_ctr_id
					and link_required_flag = 'E'
					) then 'E' 
					else 
						case when exists (
							select 1 from billinglinklookup (nolock)
							where source_id = b.receipt_id 
							and source_company_id = b.company_id
							and source_profit_ctr_id = b.profit_ctr_id
							and link_required_flag <> 'E'
						) then 'T' else 'F' 
					end 
				end AS link_flag,
				*/
				null as linked_record, -- Wo's don't list these.  R's do.
				woth.account_desc,
				woh.workorder_status,
				case when b.status_code = 'I' then 'Invoiced' else 
					CASE woh.workorder_status
						WHEN 'A' THEN 'Accepted'
						WHEN 'C' THEN 'Completed'
						WHEN 'N' THEN 'New'
					END
				end as status_description,
				woh.start_date,
				COALESCE(wos.date_act_arrive, woh.start_date) as pickup_date,
				woh.submitted_flag,
				woh.date_submitted,
				woh.submitted_by,
				b.status_code as billing_status_code,
				cb.territory_code,
				cb.billing_project_id,
				cb.project_name,
				case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
				b.invoice_code,
				b.invoice_date,
				MONTH(b.invoice_date),
				YEAR(b.invoice_date),
				c.customer_id,
				c.cust_name,
				c.customer_type,
				c.cust_category,
				b.line_id,
				b.price_id,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				bd.billing_type,
				case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end,
				bd.dist_company_id,
				bd.dist_profit_ctr_id,
				bd.gl_account_code,
				bd.extended_amt,
				g.generator_id,
				g.generator_name,
				g.epa_id,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				woh.quote_id,
				b.approval_code,
				b.service_desc_1,
				woh.fixed_price_flag,
				'A' as pricing_method,
				'T' as quantity_flag,
				NULL as JDE_BU, --bd.JDE_BU,
				NULL as JDE_Object, -- bd.JDE_object,
				bd.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				bd.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				bd.AX_Dimension_2				,	-- AX_business_unit
				bd.AX_Dimension_3				,	-- AX_department
				bd.AX_Dimension_4				,	-- AX_line_of_business
				bd.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				b.waste_code_uid,
				b.reference_code,
				b.purchase_order,
				b.release_code,
				woh.ticket_number
				, b.billing_uid
				, b.billing_date
				, woh.start_date
			FROM Billing b WITH (INDEX(idx_billing_actual_status_date))
			--rb 04/08/2015
			--INNER JOIN #tmp_source ts
			--	ON ts.trans_source = b.trans_source
			INNER JOIN BillingDetail bd (nolock)
				ON bd.billing_uid = b.billing_uid
			INNER JOIN WorkOrderHeader woh (nolock)
				ON b.receipt_id = woh.workorder_id
				AND b.company_id = woh.company_id
				AND b.profit_ctr_id = woh.profit_ctr_id
			INNER JOIN  WorkOrderTypeHeader woth (nolock)
				ON woh.workorder_type_id = woth.workorder_type_id
			--rb 04/10/2015
			join #tmp_trans_copc copc
				on bd.dist_company_id = copc.company_id
				and bd.dist_profit_ctr_id = copc.profit_ctr_id
			join @customer c on b.customer_id = c.customer_id
			LEFT OUTER JOIN CustomerBilling cb (nolock)
				ON b.customer_id = cb.customer_id
				AND ISNULL(b.billing_project_id, 0) = cb.billing_project_id
			LEFT OUTER JOIN generator g (nolock)
				ON b.generator_id = g.generator_id
			LEFT JOIN workorderstop wos (nolock)
				ON woh.workorder_id = wos.workorder_id
				and wos.stop_sequence_id = 1
				and woh.company_id = wos.company_id
				and woh.profit_ctr_id = wos.profit_ctr_id
			WHERE 1=1
			-- AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND b.trans_source = 'W'
			AND b.status_code in (select status_code from @billing_status_code)
			-- rb 04/06/2015
			AND b.billing_date between @date_from and @date_to

	end
END

--#endregion


	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "In Billing (Workorder), Actual #InternalFlashWork" Population' as status
	set @lasttime = getdate()

		
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "In Billing (Receipt), Actual #InternalFlashWork" Population' as status
	set @lasttime = getdate()
--#region trans_source R
	
--rb 04/10/2015 Had to break single select into 4 separates so indexes to make use of indexes on billing_date/invoice_date, and to allow co/pc join to be defined
IF exists (select 1 from #tmp_source where trans_source = 'R')
BEGIN


--#region copc-search-type T 2
	if @copc_search_type = 'T'
	begin
		if isnull(@invoice_flag,'') = 'I' 
		begin
			INSERT #InternalFlashWork (
				company_id					,
				profit_ctr_id				,
				trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
				receipt_id					, -- Receipt/Workorder ID
				trans_type					, -- Receipt trans type (O/I)
				link_flag					,
				linked_record				,
				trans_status				, -- Receipt or Workorder Status
				status_description			, -- Billing/Transaction status description
				trans_date					, -- Receipt Date or Workorder End Date
				pickup_date					, -- Pickup Date
				submitted_flag				, -- Submitted Flag
				date_submitted				, -- Date Submitted
				submitted_by				, -- Submitted By
				billing_status_code			, -- Billing Status Code
				territory_code				, -- Billing Project Territory code
				billing_project_id			, -- Billing project ID
				billing_project_name		, -- Billing Project Name
				invoice_flag				, -- Invoiced? Flag
				invoice_code				, -- Invoice Code (if invoiced)
				invoice_date				, -- Invoice Date (if invoiced)
				invoice_month				, -- Invoice Date month
				invoice_year				, -- Invoice Date year
				customer_id					, -- Customer ID on Receipt/Workorder
				cust_name					, -- Customer Name
				customer_type				, -- Customer Type
				cust_category				, -- Customer Category
				line_id						, -- Receipt line id
				price_id					, -- Receipt line price id
				ref_line_id					, -- Billing reference line_id (which line does this refer to?)
				workorder_sequence_id		, -- Workorder sequence id
				workorder_resource_item		, -- Workorder Resource Item
				workorder_resource_type		, -- Workorder Resource Type
				quantity					, -- Receipt/Workorder Quantity
				billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
				dist_flag					, -- Distributed Transaction?
				dist_company_id				, -- Distribution Company ID (which company receives the revenue)
				dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
				gl_account_code				, -- GL Account for the revenue
				extended_amt				, -- Revenue amt
				generator_id				, -- Generator ID
				generator_name				, -- Generator Name
				epa_id						, -- Generator EPA ID
				treatment_id				, -- Treatment ID
				treatment_desc				, -- Treatment's treatment_desc
				treatment_process_id		, -- Treatment's treatment_process_id
				treatment_process			, -- Treatment's treatment_process (desc)
				disposal_service_id			, -- Treatment's disposal_service_id
				disposal_service_desc		, -- Treatment's disposal_service_desc
				wastetype_id				, -- Treatment's wastetype_id
				wastetype_category			, -- Treatment's wastetype category
				wastetype_description		, -- Treatment's wastetype description
				bill_unit_code				, -- Unit
				waste_code					, -- Waste Code
				profile_id					, -- Profile_id
				quote_id					, -- Quote ID
				product_id					, -- BillingDetail product_id, for id'ing fees, etc.
				product_code				, -- Product Code
				approval_code				, -- Approval Code
				approval_desc				,
				pricing_method				, -- Calculated, Actual, etc.
				quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
				JDE_BU						,
				JDE_object					,
				AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				AX_Dimension_2				,	-- AX_business_unit
				AX_Dimension_3				,	-- AX_department
				AX_Dimension_4				,	-- AX_line_of_business
				AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				waste_code_uid				,
				reference_code,
				purchase_order				,
				release_code				,	
				ticket_number					-- WorkOrderHeader.ticket_number, if there is a linked WO
				,billing_uid				
				,billing_date				
				,workorder_startdate		
			)
			SELECT
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.trans_type,
				link_flag = (
				select
				isnull(
					(
					select top 1 case link_required_flag when 'E' then 'E' else 'T' end
					from billinglinklookup (nolock)
					where receipt_id = b.receipt_id 
					and company_id = b.company_id
					and profit_ctr_id = b.profit_ctr_id
					ORDER BY isnull(link_required_flag, 'Z')
					)
				, 'F')
				),
/*
				case when exists (
					select 1 from billinglinklookup (nolock)
					where receipt_id = b.receipt_id 
					and company_id = b.company_id
					and profit_ctr_id = b.profit_ctr_id
					and link_required_flag = 'E'
					) then 'E' 
					else 
						case when exists (
							select 1 from billinglinklookup (nolock)
							where receipt_id = b.receipt_id 
							and company_id = b.company_id
							and profit_ctr_id = b.profit_ctr_id
							and link_required_flag <> 'E'
						) then 'T' else 'F' 
						end 
					end AS link_flag,
*/					
				null, --rb 04/06/2015 dbo.fn_get_linked_workorders(b.company_id, b.profit_ctr_id, b.receipt_id) as linked_record, -- Wo's don't list these.  R's do.
				r.receipt_status,
				case when b.status_code = 'I' then 'Invoiced' 
				else 
					CASE r.receipt_status
						WHEN 'L' THEN
							CASE r.fingerpr_status
								WHEN 'A' THEN 'Lab, Accepted'
								WHEN 'H' THEN 'Lab, Hold'
								WHEN 'W' THEN 'Lab, Waiting'
								ELSE 'Unknown Lab Status: ' + r.fingerpr_status
							END
						WHEN 'A' THEN 'Accepted'
						WHEN 'M' THEN 'Manual'
						WHEN 'N' THEN 'New'
						WHEN 'U' THEN 'Unloading'
						ELSE NULL
					END
				end as status_description,
				r.receipt_date,
				pickup_date = (
					select top 1 _date from
					--coalesce(rt.transporter_sign_date, wospu.date_act_arrive, wohpu.start_date)
					(
						select rt.transporter_sign_date _date
						FROM ReceiptTransporter RT WITH(nolock) 
						WHERE  RT.receipt_id = b.receipt_id 
						and RT.company_id = b.company_id 
						and RT.profit_ctr_id = b.profit_ctr_id
						and RT.transporter_sequence_id = 1
						union
						select coalesce(wospu.date_act_arrive, wohpu.start_date) _date
						FROM BillingLinkLookup bllpu (nolock) 
						LEFT JOIN WorkOrderHeader wohpu (nolock) 
							ON wohpu.company_id = bllpu.source_company_id
							AND wohpu.profit_ctr_id = bllpu.source_profit_ctr_id
							AND wohpu.workorder_id = bllpu.source_id					
						LEFT JOIN workorderstop wospu (nolock)
							ON wohpu.workorder_id = wospu.workorder_id
							and wospu.stop_sequence_id = 1
							and wohpu.company_id = wospu.company_id
							and wohpu.profit_ctr_id = wospu.profit_ctr_id
						WHERE  bllpu.receipt_id = b.receipt_id
						and bllpu.company_id = b.company_id
						and bllpu.profit_ctr_id = b.profit_ctr_id
					) y
					WHERE _date is not null
					order by _date
				),
				r.submitted_flag,
				r.date_submitted,
				r.submitted_by,
				b.status_code as billing_status_code,
				cb.territory_code,
				cb.billing_project_id,
				cb.project_name,
				case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
				b.invoice_code,
				b.invoice_date,
				MONTH(b.invoice_date),
				YEAR(b.invoice_date),
				c.customer_id,
				c.cust_name,
				c.customer_type,
				c.cust_category,
				b.line_id,
				b.price_id,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				bd.billing_type,
				-- Modify: GEM-43800: If Product, call it Distributed?
				-- case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end,
				case when exists ( select 1 from profilequotedetail pqd WHERE pqd.profile_id = r.profile_id and pqd.company_id = r.company_id and pqd.profit_ctr_id = r.profit_ctr_id and pqd.bill_method = 'B' ) then 'D' else 
					case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end
				end as dist_flag,
				bd.dist_company_id,
				bd.dist_profit_ctr_id,
				bd.gl_account_code,
				bd.extended_amt,
				g.generator_id,
				g.generator_name,
				g.epa_id,
				t.treatment_id,
				t.treatment_desc,
				t.treatment_process_id,
				t.treatment_process_process,
				t.disposal_service_id,
				t.disposal_service_desc,
				t.wastetype_id,
				t.wastetype_category,
				t.wastetype_description,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				pqa.quote_id,
				r.product_id,
				r.product_code,
				b.approval_code,
				b.service_desc_1, 
				'A' as pricing_method,
				'T' as quantity_flag,
				NULL as JDE_BU, --bd.JDE_BU,
				NULL as JDE_Object, -- bd.JDE_object,
				bd.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				bd.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				bd.AX_Dimension_2				,	-- AX_business_unit
				bd.AX_Dimension_3				,	-- AX_department
				bd.AX_Dimension_4				,	-- AX_line_of_business
				bd.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				b.waste_code_uid,
				NULL as reference_code,
				b.purchase_order,
				b.release_code,
				woh.ticket_number
				, b.billing_uid
				, b.billing_date
				, woh.start_date				
			FROM Billing b WITH (INDEX(idx_billing_status_date))
			--rb 04/08/2015
			--INNER JOIN #tmp_source ts
			--	ON ts.trans_source = b.trans_source
			INNER JOIN BillingDetail bd (nolock)
				ON bd.billing_uid = b.billing_uid
			INNER JOIN Receipt r (nolock)
				ON b.receipt_id = r.receipt_id
				AND b.line_id = r.line_id
				AND b.company_id = r.company_id
				AND b.profit_ctr_id = r.profit_ctr_id
			join #tmp_trans_copc copc
				on b.company_id = copc.company_id
				and b.profit_ctr_id = copc.profit_ctr_id
			join @customer c on b.customer_id = c.customer_id
			LEFT OUTER JOIN CustomerBilling cb (nolock)
				ON b.customer_id = cb.customer_id
				AND ISNULL(b.billing_project_id, 0) = cb.billing_project_id
			LEFT OUTER JOIN generator g (nolock)
				ON b.generator_id = g.generator_id
			LEFT OUTER JOIN profilequoteapproval pqa (nolock)
				ON b.profile_id = pqa.profile_id
				AND b.company_id = pqa.company_id
				AND b.profit_ctr_id = pqa.profit_ctr_id
			LEFT OUTER JOIN Treatment t (nolock)
				ON r.treatment_id = t.treatment_id
				AND r.company_id = t.company_id
				AND r.profit_ctr_id = t.profit_ctr_id
			LEFT OUTER JOIN BillingLinkLookup bll (nolock) 
				ON r.receipt_id = bll.receipt_id
				and r.company_id = bll.company_id
				and r.profit_ctr_id = bll.profit_ctr_id
			LEFT JOIN WorkOrderHeader woh (nolock) 
				ON woh.company_id = bll.source_company_id
				AND woh.profit_ctr_id = bll.source_profit_ctr_id
				AND woh.workorder_id = bll.source_id		
			WHERE 1=1
			-- AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND b.trans_source = 'R'
			AND b.status_code in (select status_code from @Billing_Status_Code)
			-- rb 04/06/2015
			AND b.invoice_date between @date_from and @date_to
			
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Inserted to #InternalFlashWork from Billing/Detail for Receipts (ln 2010)' as status
	set @lasttime = getdate()
			
		end
		else if isnull(@invoice_flag,'') in ('N', 'S') -- We're pulling from Billing, so it can't be "U"nsubmitted, and this isn't the "I"nvoiced section, so it's N/S
		begin

			drop table if exists #TempBilling1
			SELECT DISTINCT
				b.billing_uid,
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.line_id,
				b.price_id,
				b.trans_type,
				b.status_code,
				b.customer_id,
				b.billing_project_id,
				b.generator_id,
				b.invoice_code,
				b.invoice_date,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				b.approval_code,
				b.service_desc_1, 
				b.waste_code_uid,
				b.purchase_order,
				b.release_code,
				b.billing_date
			INTO #TempBilling1
			FROM Billing b --WITH (INDEX(idx_billing_actual_status_date))
			join @customer c on b.customer_id = c.customer_id
			join #tmp_trans_copc copc
				on b.company_id = copc.company_id
				and b.profit_ctr_id = copc.profit_ctr_id
			WHERE 1=1
			-- AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND b.trans_source = 'R'
			AND b.status_code in (select status_code from @Billing_Status_Code)
			AND b.billing_date between @date_from and @date_to

			create index idx2 on #TempBilling1 (billing_uid)
			create index idx3 on #TempBilling1 (customer_id, billing_project_id)
			create index idx4 on #TempBilling1 (receipt_id, line_id, company_id, profit_ctr_id)
			create index idx5 on #TempBilling1 (generator_id)
			create index idx6 on #TempBilling1 (profile_id, company_id, profit_ctr_id)

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Inserted to #TempBilling1 from Billing for Receipts' as status
	set @lasttime = getdate()

			INSERT #InternalFlashWork (
				company_id					,
				profit_ctr_id				,
				trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
				receipt_id					, -- Receipt/Workorder ID
				trans_type					, -- Receipt trans type (O/I)
				link_flag					,
				linked_record				,
				trans_status				, -- Receipt or Workorder Status
				status_description			, -- Billing/Transaction status description
				trans_date					, -- Receipt Date or Workorder End Date
				pickup_date					, -- Pickup Date
				submitted_flag				, -- Submitted Flag
				date_submitted				, -- Date Submitted
				submitted_by				, -- Submitted By
				billing_status_code			, -- Billing Status Code
				territory_code				, -- Billing Project Territory code
				billing_project_id			, -- Billing project ID
				billing_project_name		, -- Billing Project Name
				invoice_flag				, -- Invoiced? Flag
				invoice_code				, -- Invoice Code (if invoiced)
				invoice_date				, -- Invoice Date (if invoiced)
				invoice_month				, -- Invoice Date month
				invoice_year				, -- Invoice Date year
				customer_id					, -- Customer ID on Receipt/Workorder
				cust_name					, -- Customer Name
				customer_type				, -- Customer Type
				cust_category				, -- Customer Category
				line_id						, -- Receipt line id
				price_id					, -- Receipt line price id
				ref_line_id					, -- Billing reference line_id (which line does this refer to?)
				workorder_sequence_id		, -- Workorder sequence id
				workorder_resource_item		, -- Workorder Resource Item
				workorder_resource_type		, -- Workorder Resource Type
				quantity					, -- Receipt/Workorder Quantity
				billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
				dist_flag					, -- Distributed Transaction?
				dist_company_id				, -- Distribution Company ID (which company receives the revenue)
				dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
				gl_account_code				, -- GL Account for the revenue
				extended_amt				, -- Revenue amt
				generator_id				, -- Generator ID
				generator_name				, -- Generator Name
				epa_id						, -- Generator EPA ID
				treatment_id				, -- Treatment ID
				treatment_desc				, -- Treatment's treatment_desc
				treatment_process_id		, -- Treatment's treatment_process_id
				treatment_process			, -- Treatment's treatment_process (desc)
				disposal_service_id			, -- Treatment's disposal_service_id
				disposal_service_desc		, -- Treatment's disposal_service_desc
				wastetype_id				, -- Treatment's wastetype_id
				wastetype_category			, -- Treatment's wastetype category
				wastetype_description		, -- Treatment's wastetype description
				bill_unit_code				, -- Unit
				waste_code					, -- Waste Code
				profile_id					, -- Profile_id
				quote_id					, -- Quote ID
				product_id					, -- BillingDetail product_id, for id'ing fees, etc.
				product_code				, -- Product Code
				approval_code				, -- Approval Code
				approval_desc				,
				pricing_method				, -- Calculated, Actual, etc.
				quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
				JDE_BU						,
				JDE_object					,
				AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				AX_Dimension_2				,	-- AX_business_unit
				AX_Dimension_3				,	-- AX_department
				AX_Dimension_4				,	-- AX_line_of_business
				AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				waste_code_uid				,
				reference_code,
				purchase_order				,
				release_code				,	
				ticket_number					-- WorkOrderHeader.ticket_number, if there is a linked WO
				,billing_uid				
				,billing_date				
				,workorder_startdate		
			)
			SELECT
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.trans_type,
				link_flag = (
				select
				isnull(
					(
					select top 1 case link_required_flag when 'E' then 'E' else 'T' end
					from billinglinklookup (nolock)
					where receipt_id = b.receipt_id 
					and company_id = b.company_id
					and profit_ctr_id = b.profit_ctr_id
					ORDER BY isnull(link_required_flag, 'Z')
					)
				, 'F')
				),
				null, --rb 04/06/2015 dbo.fn_get_linked_workorders(b.company_id, b.profit_ctr_id, b.receipt_id) as linked_record, -- Wo's don't list these.  R's do.
				r.receipt_status,
				case when b.status_code = 'I' then 'Invoiced' 
				else 
					CASE r.receipt_status
						WHEN 'L' THEN
							CASE r.fingerpr_status
								WHEN 'A' THEN 'Lab, Accepted'
								WHEN 'H' THEN 'Lab, Hold'
								WHEN 'W' THEN 'Lab, Waiting'
								ELSE 'Unknown Lab Status: ' + r.fingerpr_status
							END
						WHEN 'A' THEN 'Accepted'
						WHEN 'M' THEN 'Manual'
						WHEN 'N' THEN 'New'
						WHEN 'U' THEN 'Unloading'
						ELSE NULL
					END
				end as status_description,
				r.receipt_date,
				pickup_date = (
					select top 1 _date from
					--coalesce(rt.transporter_sign_date, wospu.date_act_arrive, wohpu.start_date)
					(
						select rt.transporter_sign_date _date
						FROM ReceiptTransporter RT WITH(nolock) 
						WHERE  RT.receipt_id = b.receipt_id 
						and RT.company_id = b.company_id 
						and RT.profit_ctr_id = b.profit_ctr_id
						and RT.transporter_sequence_id = 1
						union
						select coalesce(wospu.date_act_arrive, wohpu.start_date) _date
						FROM BillingLinkLookup bllpu (nolock) 
						LEFT JOIN WorkOrderHeader wohpu (nolock) 
							ON wohpu.company_id = bllpu.source_company_id
							AND wohpu.profit_ctr_id = bllpu.source_profit_ctr_id
							AND wohpu.workorder_id = bllpu.source_id					
						LEFT JOIN workorderstop wospu (nolock)
							ON wohpu.workorder_id = wospu.workorder_id
							and wospu.stop_sequence_id = 1
							and wohpu.company_id = wospu.company_id
							and wohpu.profit_ctr_id = wospu.profit_ctr_id
						WHERE  bllpu.receipt_id = b.receipt_id
						and bllpu.company_id = b.company_id
						and bllpu.profit_ctr_id = b.profit_ctr_id
					) y
					WHERE _date is not null
					order by _date
				),
				r.submitted_flag,
				r.date_submitted,
				r.submitted_by,
				b.status_code as billing_status_code,
				cb.territory_code,
				cb.billing_project_id,
				cb.project_name,
				case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
				b.invoice_code,
				b.invoice_date,
				MONTH(b.invoice_date),
				YEAR(b.invoice_date),
				c.customer_id,
				c.cust_name,
				c.customer_type,
				c.cust_category,
				b.line_id,
				b.price_id,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				bd.billing_type,
				-- Modify: GEM-43800: If Product, call it Distributed?
				-- case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end,
				case when exists ( select 1 from profilequotedetail pqd WHERE pqd.profile_id = r.profile_id and pqd.company_id = r.company_id and pqd.profit_ctr_id = r.profit_ctr_id and pqd.bill_method = 'B' ) then 'D' else 
					case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end
				end as dist_flag,
				bd.dist_company_id,
				bd.dist_profit_ctr_id,
				bd.gl_account_code,
				bd.extended_amt,
				g.generator_id,
				g.generator_name,
				g.epa_id,
				t.treatment_id,
				t.treatment_desc,
				t.treatment_process_id,
				t.treatment_process_process,
				t.disposal_service_id,
				t.disposal_service_desc,
				t.wastetype_id,
				t.wastetype_category,
				t.wastetype_description,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				pqa.quote_id,
				r.product_id,
				r.product_code,
				b.approval_code,
				b.service_desc_1, 
				'A' as pricing_method,
				'T' as quantity_flag,
				NULL as JDE_BU, --bd.JDE_BU,
				NULL as JDE_Object, -- bd.JDE_object,
				bd.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				bd.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				bd.AX_Dimension_2				,	-- AX_business_unit
				bd.AX_Dimension_3				,	-- AX_department
				bd.AX_Dimension_4				,	-- AX_line_of_business
				bd.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				b.waste_code_uid,
				NULL as reference_code,
				b.purchase_order,
				b.release_code,
				woh.ticket_number
				, b.billing_uid
				, b.billing_date
				, woh.start_date
			FROM #TempBilling1 b -- WITH (INDEX(idx_billing_actual_status_date))
			join #tmp_trans_copc copc
				on b.company_id = copc.company_id
				and b.profit_ctr_id = copc.profit_ctr_id
			join @customer c on b.customer_id = c.customer_id
			--rb 04/08/2015
			--INNER JOIN #tmp_source ts
			--	ON ts.trans_source = b.trans_source
			INNER JOIN BillingDetail bd (nolock)
				ON bd.billing_uid = b.billing_uid
			INNER JOIN Receipt r (nolock)
				ON b.receipt_id = r.receipt_id
				AND b.line_id = r.line_id
				AND b.company_id = r.company_id
				AND b.profit_ctr_id = r.profit_ctr_id
			LEFT OUTER JOIN CustomerBilling cb (nolock)
				ON b.customer_id = cb.customer_id
				AND ISNULL(b.billing_project_id, 0) = cb.billing_project_id
			LEFT OUTER JOIN generator g (nolock)
				ON b.generator_id = g.generator_id
			LEFT OUTER JOIN profilequoteapproval pqa (nolock)
				ON b.profile_id = pqa.profile_id
				AND b.company_id = pqa.company_id
				AND b.profit_ctr_id = pqa.profit_ctr_id
			LEFT OUTER JOIN Treatment t (nolock)
				ON r.treatment_id = t.treatment_id
				AND r.company_id = t.company_id
				AND r.profit_ctr_id = t.profit_ctr_id
		--rb 04/10/2015
			LEFT OUTER JOIN BillingLinkLookup bll (nolock) 
				ON r.receipt_id = bll.receipt_id
				and r.company_id = bll.company_id
				and r.profit_ctr_id = bll.profit_ctr_id
			LEFT JOIN WorkOrderHeader woh (nolock) 
				ON woh.company_id = bll.source_company_id
				AND woh.profit_ctr_id = bll.source_profit_ctr_id
				AND woh.workorder_id = bll.source_id		
			WHERE 1=1
			-- AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND b.trans_source = 'R'
			AND b.status_code in (select status_code from @Billing_Status_Code)
			-- rb 04/06/2015
			AND b.billing_date between @date_from and @date_to
			
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Inserted to #InternalFlashWork from #TempBilling1 for Receipts' as status
	set @lasttime = getdate()
			
		end -- else if isnull(@invoice_flag,'') in ('N', 'S') -- We're pulling from Billing, so it can't be "U"nsubmitted, and this isn't the "I"nvoiced section, so it's N/S
		
	end
--#endregion
	else if @copc_search_type = 'D'
	begin

--#region invoice-flag I 2	
		if isnull(@invoice_flag,'') = 'I' begin
		
			drop table if exists #keysir
			
			select b.billing_uid, 
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.customer_id,
				b.billing_project_id,
				b.generator_id,
				b.trans_type,
				b.status_code,
				b.invoice_code,
				b.invoice_date,
				b.line_id,
				b.price_id,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				bd.billing_type,
				bd.dist_company_id,
				bd.dist_profit_ctr_id,
				bd.gl_account_code,
				bd.extended_amt,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				b.approval_code,
				b.service_desc_1, 
				NULL as JDE_BU, --bd.JDE_BU,
				NULL as JDE_Object, -- bd.JDE_object,
				bd.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				bd.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				bd.AX_Dimension_2				,	-- AX_business_unit
				bd.AX_Dimension_3				,	-- AX_department
				bd.AX_Dimension_4				,	-- AX_line_of_business
				bd.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				b.waste_code_uid,
				b.purchase_order,
				b.release_code
				, b.billing_date
				, c.cust_name
				, c.customer_type
				, c.cust_category
			into #keysir
			FROM Billing b WITH (INDEX(idx_billing_status_date))
			INNER JOIN BillingDetail bd (nolock)
				ON bd.billing_uid = b.billing_uid
			join @customer c on b.customer_id = c.customer_id
			join #tmp_trans_copc copc
				on bd.dist_company_id = copc.company_id
				and bd.dist_profit_ctr_id = copc.profit_ctr_id
			WHERE 1=1
			-- AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND b.trans_source = 'R'
			AND b.status_code in (select status_code from @Billing_Status_Code)
			-- rb 04/06/2015
			AND b.invoice_date between @date_from and @date_to

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#keysir populated from billing/detail for receipts' as status
	set @lasttime = getdate()
		
			INSERT #InternalFlashWork (
				company_id					,
				profit_ctr_id				,
				trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
				receipt_id					, -- Receipt/Workorder ID
				trans_type					, -- Receipt trans type (O/I)
				link_flag					,
				linked_record				,
				trans_status				, -- Receipt or Workorder Status
				status_description			, -- Billing/Transaction status description
				trans_date					, -- Receipt Date or Workorder End Date
				pickup_date					, -- Pickup Date
				submitted_flag				, -- Submitted Flag
				date_submitted				, -- Date Submitted
				submitted_by				, -- Submitted By
				billing_status_code			, -- Billing Status Code
				territory_code				, -- Billing Project Territory code
				billing_project_id			, -- Billing project ID
				billing_project_name		, -- Billing Project Name
				invoice_flag				, -- Invoiced? Flag
				invoice_code				, -- Invoice Code (if invoiced)
				invoice_date				, -- Invoice Date (if invoiced)
				invoice_month				, -- Invoice Date month
				invoice_year				, -- Invoice Date year
				customer_id					, -- Customer ID on Receipt/Workorder
				cust_name					, -- Customer Name
				customer_type				, -- Customer Type
				cust_category				, -- Customer Category
				line_id						, -- Receipt line id
				price_id					, -- Receipt line price id
				ref_line_id					, -- Billing reference line_id (which line does this refer to?)
				workorder_sequence_id		, -- Workorder sequence id
				workorder_resource_item		, -- Workorder Resource Item
				workorder_resource_type		, -- Workorder Resource Type
				quantity					, -- Receipt/Workorder Quantity
				billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
				dist_flag					, -- Distributed Transaction?
				dist_company_id				, -- Distribution Company ID (which company receives the revenue)
				dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
				gl_account_code				, -- GL Account for the revenue
				extended_amt				, -- Revenue amt
				generator_id				, -- Generator ID
				generator_name				, -- Generator Name
				epa_id						, -- Generator EPA ID
				treatment_id				, -- Treatment ID
				treatment_desc				, -- Treatment's treatment_desc
				treatment_process_id		, -- Treatment's treatment_process_id
				treatment_process			, -- Treatment's treatment_process (desc)
				disposal_service_id			, -- Treatment's disposal_service_id
				disposal_service_desc		, -- Treatment's disposal_service_desc
				wastetype_id				, -- Treatment's wastetype_id
				wastetype_category			, -- Treatment's wastetype category
				wastetype_description		, -- Treatment's wastetype description
				bill_unit_code				, -- Unit
				waste_code					, -- Waste Code
				profile_id					, -- Profile_id
				quote_id					, -- Quote ID
				product_id					, -- BillingDetail product_id, for id'ing fees, etc.
				product_code				, -- Product Code
				approval_code				, -- Approval Code
				approval_desc				,
				pricing_method				, -- Calculated, Actual, etc.
				quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
				JDE_BU						,
				JDE_object					,
				AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				AX_Dimension_2				,	-- AX_business_unit
				AX_Dimension_3				,	-- AX_department
				AX_Dimension_4				,	-- AX_line_of_business
				AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				waste_code_uid				,
				reference_code,
				purchase_order				,
				release_code				,	
				ticket_number					-- WorkOrderHeader.ticket_number, if there is a linked WO
				,billing_uid				
				,billing_date				
				,workorder_startdate		
			)
			SELECT
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.trans_type,
				link_flag = (
				select
				isnull(
					(
					select top 1 case link_required_flag when 'E' then 'E' else 'T' end
					from billinglinklookup (nolock)
					where receipt_id = b.receipt_id 
					and company_id = b.company_id
					and profit_ctr_id = b.profit_ctr_id
					ORDER BY isnull(link_required_flag, 'Z')
					)
				, 'F')
				),
				/*
				case when exists (
					select 1 from billinglinklookup (nolock)
					where receipt_id = b.receipt_id 
					and company_id = b.company_id
					and profit_ctr_id = b.profit_ctr_id
					and link_required_flag = 'E'
					) then 'E' 
					else 
						case when exists (
							select 1 from billinglinklookup (nolock)
							where receipt_id = b.receipt_id 
							and company_id = b.company_id
							and profit_ctr_id = b.profit_ctr_id
							and link_required_flag <> 'E'
						) then 'T' else 'F' 
						end 
					end AS link_flag,
				*/
				null, --rb 04/06/2015 dbo.fn_get_linked_workorders(b.company_id, b.profit_ctr_id, b.receipt_id) as linked_record, -- Wo's don't list these.  R's do.
				r.receipt_status,
				case when b.status_code = 'I' then 'Invoiced' 
				else 
					CASE r.receipt_status
						WHEN 'L' THEN
							CASE r.fingerpr_status
								WHEN 'A' THEN 'Lab, Accepted'
								WHEN 'H' THEN 'Lab, Hold'
								WHEN 'W' THEN 'Lab, Waiting'
								ELSE 'Unknown Lab Status: ' + r.fingerpr_status
							END
						WHEN 'A' THEN 'Accepted'
						WHEN 'M' THEN 'Manual'
						WHEN 'N' THEN 'New'
						WHEN 'U' THEN 'Unloading'
						ELSE NULL
					END
				end as status_description,
				r.receipt_date,
				pickup_date = (
					select top 1 _date from
					--coalesce(rt.transporter_sign_date, wospu.date_act_arrive, wohpu.start_date)
					(
						select rt.transporter_sign_date _date
						FROM ReceiptTransporter RT WITH(nolock) 
						WHERE  RT.receipt_id = b.receipt_id 
						and RT.company_id = b.company_id 
						and RT.profit_ctr_id = b.profit_ctr_id
						and RT.transporter_sequence_id = 1
						union
						select coalesce(wospu.date_act_arrive, wohpu.start_date) _date
						FROM BillingLinkLookup bllpu (nolock) 
						LEFT JOIN WorkOrderHeader wohpu (nolock) 
							ON wohpu.company_id = bllpu.source_company_id
							AND wohpu.profit_ctr_id = bllpu.source_profit_ctr_id
							AND wohpu.workorder_id = bllpu.source_id					
						LEFT JOIN workorderstop wospu (nolock)
							ON wohpu.workorder_id = wospu.workorder_id
							and wospu.stop_sequence_id = 1
							and wohpu.company_id = wospu.company_id
							and wohpu.profit_ctr_id = wospu.profit_ctr_id
						WHERE  bllpu.receipt_id = b.receipt_id
						and bllpu.company_id = b.company_id
						and bllpu.profit_ctr_id = b.profit_ctr_id
					) y
					WHERE _date is not null
					order by _date
				),
/*
				pickup_date = (
					select top 1 coalesce(rt.transporter_sign_date, wospu.date_act_arrive, wohpu.start_date)
					FROM Receipt rpu (nolock)
					LEFT OUTER JOIN ReceiptTransporter RT WITH(nolock) 
						ON RT.receipt_id = rpu.receipt_id 
						and RT.company_id = rpu.company_id 
						and RT.profit_ctr_id = rpu.profit_ctr_id
						and RT.transporter_sequence_id = 1
					LEFT OUTER JOIN BillingLinkLookup bllpu (nolock) 
						ON rpu.receipt_id = bllpu.receipt_id
						and rpu.company_id = bllpu.company_id
						and rpu.profit_ctr_id = bllpu.profit_ctr_id
					LEFT JOIN WorkOrderHeader wohpu (nolock) 
						ON wohpu.company_id = bllpu.source_company_id
						AND wohpu.profit_ctr_id = bllpu.source_profit_ctr_id
						AND wohpu.workorder_id = bllpu.source_id					
					LEFT JOIN workorderstop wospu (nolock)
						ON wohpu.workorder_id = wospu.workorder_id
						and wospu.stop_sequence_id = 1
						and wohpu.company_id = wospu.company_id
						and wohpu.profit_ctr_id = wospu.profit_ctr_id
					WHERE
						rpu.receipt_id = b.receipt_id
						and rpu.company_id = b.company_id
						and rpu.profit_ctr_id = b.profit_ctr_id
				),
*/				
				r.submitted_flag,
				r.date_submitted,
				r.submitted_by,
				b.status_code as billing_status_code,
				cb.territory_code,
				cb.billing_project_id,
				cb.project_name,
				case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
				b.invoice_code,
				b.invoice_date,
				MONTH(b.invoice_date),
				YEAR(b.invoice_date),
				b.customer_id,
				b.cust_name,
				b.customer_type,
				b.cust_category,
				b.line_id,
				b.price_id,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				b.billing_type,
				-- Modify: GEM-43800: If Product, call it Distributed?
				-- case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end,
				case when exists ( select 1 from profilequotedetail pqd WHERE pqd.profile_id = r.profile_id and pqd.company_id = r.company_id and pqd.profit_ctr_id = r.profit_ctr_id and pqd.bill_method = 'B' ) then 'D' else 
					case when b.dist_company_id <> b.company_id or b.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end
				end as dist_flag,
				b.dist_company_id,
				b.dist_profit_ctr_id,
				b.gl_account_code,
				b.extended_amt,
				g.generator_id,
				g.generator_name,
				g.epa_id,
				t.treatment_id,
				t.treatment_desc,
				t.treatment_process_id,
				t.treatment_process_process,
				t.disposal_service_id,
				t.disposal_service_desc,
				t.wastetype_id,
				t.wastetype_category,
				t.wastetype_description,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				pqa.quote_id,
				r.product_id,
				r.product_code,
				b.approval_code,
				b.service_desc_1, 
				'A' as pricing_method,
				'T' as quantity_flag,
				NULL as JDE_BU, --b.JDE_BU,
				NULL as JDE_Object, -- b.JDE_object,
				b.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				b.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				b.AX_Dimension_2				,	-- AX_business_unit
				b.AX_Dimension_3				,	-- AX_department
				b.AX_Dimension_4				,	-- AX_line_of_business
				b.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				b.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				b.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				b.waste_code_uid,
				NULL as reference_code,
				b.purchase_order,
				b.release_code,
				woh.ticket_number
				, b.billing_uid
				, b.billing_date
				, woh.start_date
			FROM #keysir b -- WITH (INDEX(idx_billing_status_date))
			INNER JOIN Receipt r (nolock)
				ON b.receipt_id = r.receipt_id
				AND b.line_id = r.line_id
				AND b.company_id = r.company_id
				AND b.profit_ctr_id = r.profit_ctr_id
			LEFT OUTER JOIN CustomerBilling cb (nolock)
				ON b.customer_id = cb.customer_id
				AND ISNULL(b.billing_project_id, 0) = cb.billing_project_id
			LEFT OUTER JOIN generator g (nolock)
				ON b.generator_id = g.generator_id
			LEFT OUTER JOIN profilequoteapproval pqa (nolock)
				ON b.profile_id = pqa.profile_id
				AND b.company_id = pqa.company_id
				AND b.profit_ctr_id = pqa.profit_ctr_id
			LEFT OUTER JOIN Treatment t (nolock)
				ON r.treatment_id = t.treatment_id
				AND r.company_id = t.company_id
				AND r.profit_ctr_id = t.profit_ctr_id
			LEFT OUTER JOIN BillingLinkLookup bll (nolock) 
				ON r.receipt_id = bll.receipt_id
				and r.company_id = bll.company_id
				and r.profit_ctr_id = bll.profit_ctr_id
			LEFT JOIN WorkOrderHeader woh (nolock) 
				ON woh.company_id = bll.source_company_id
				AND woh.profit_ctr_id = bll.source_profit_ctr_id
				AND woh.workorder_id = bll.source_id		
			
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Inserted to #InternalFlashWork from Billing/Detail for Receipts (ln 2707)' as status
	set @lasttime = getdate()
--#endregion
			
		end
		else if isnull(@invoice_flag,'') in ('N', 'S') -- We're pulling from Billing, so it can't be "U"nsubmitted, and this isn't the "I"nvoiced section, so it's N/S
		begin

			drop table if exists #TempBilling2
			SELECT DISTINCT
				b.billing_uid,
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.line_id,
				b.price_id,
				b.trans_type,
				b.status_code,
				b.customer_id,
				b.billing_project_id,
				b.generator_id,
				b.invoice_code,
				b.invoice_date,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				b.approval_code,
				b.service_desc_1, 
				b.waste_code_uid,
				b.purchase_order,
				b.release_code,
				b.billing_date
			INTO #TempBilling2
			FROM Billing b WITH (INDEX(idx_billing_actual_status_date))
			INNER JOIN BillingDetail bd (nolock)
				ON bd.billing_uid = b.billing_uid
			join #tmp_trans_copc copc
				on bd.dist_company_id = copc.company_id
				and bd.dist_profit_ctr_id = copc.profit_ctr_id
			join @customer c on b.customer_id = c.customer_id
			WHERE 1=1
			-- AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND b.trans_source = 'R'
			AND b.status_code in (select status_code from @Billing_Status_Code)
			AND b.billing_date between @date_from and @date_to
		
			create index idx2 on #TempBilling2 (billing_uid)
			create index idx3 on #TempBilling2 (customer_id, billing_project_id)
			create index idx4 on #TempBilling2 (receipt_id, line_id, company_id, profit_ctr_id)
			create index idx5 on #TempBilling2 (generator_id)
			create index idx6 on #TempBilling2 (profile_id, company_id, profit_ctr_id)
		
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Inserted to #TempBilling2 from Billing for Receipts' as status
	set @lasttime = getdate()
		
			INSERT #InternalFlashWork (
				company_id					,
				profit_ctr_id				,
				trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
				receipt_id					, -- Receipt/Workorder ID
				trans_type					, -- Receipt trans type (O/I)
				link_flag					,
				linked_record				,
				trans_status				, -- Receipt or Workorder Status
				status_description			, -- Billing/Transaction status description
				trans_date					, -- Receipt Date or Workorder End Date
				pickup_date					, -- Pickup Date
				submitted_flag				, -- Submitted Flag
				date_submitted				, -- Date Submitted
				submitted_by				, -- Submitted By
				billing_status_code			, -- Billing Status Code
				territory_code				, -- Billing Project Territory code
				billing_project_id			, -- Billing project ID
				billing_project_name		, -- Billing Project Name
				invoice_flag				, -- Invoiced? Flag
				invoice_code				, -- Invoice Code (if invoiced)
				invoice_date				, -- Invoice Date (if invoiced)
				invoice_month				, -- Invoice Date month
				invoice_year				, -- Invoice Date year
				customer_id					, -- Customer ID on Receipt/Workorder
				cust_name					, -- Customer Name
				customer_type				, -- Customer Type
				cust_category				, -- Customer Category
				line_id						, -- Receipt line id
				price_id					, -- Receipt line price id
				ref_line_id					, -- Billing reference line_id (which line does this refer to?)
				workorder_sequence_id		, -- Workorder sequence id
				workorder_resource_item		, -- Workorder Resource Item
				workorder_resource_type		, -- Workorder Resource Type
				quantity					, -- Receipt/Workorder Quantity
				billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
				dist_flag					, -- Distributed Transaction?
				dist_company_id				, -- Distribution Company ID (which company receives the revenue)
				dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
				gl_account_code				, -- GL Account for the revenue
				extended_amt				, -- Revenue amt
				generator_id				, -- Generator ID
				generator_name				, -- Generator Name
				epa_id						, -- Generator EPA ID
				treatment_id				, -- Treatment ID
				treatment_desc				, -- Treatment's treatment_desc
				treatment_process_id		, -- Treatment's treatment_process_id
				treatment_process			, -- Treatment's treatment_process (desc)
				disposal_service_id			, -- Treatment's disposal_service_id
				disposal_service_desc		, -- Treatment's disposal_service_desc
				wastetype_id				, -- Treatment's wastetype_id
				wastetype_category			, -- Treatment's wastetype category
				wastetype_description		, -- Treatment's wastetype description
				bill_unit_code				, -- Unit
				waste_code					, -- Waste Code
				profile_id					, -- Profile_id
				quote_id					, -- Quote ID
				product_id					, -- BillingDetail product_id, for id'ing fees, etc.
				product_code				, -- Product Code
				approval_code				, -- Approval Code
				approval_desc				,
				pricing_method				, -- Calculated, Actual, etc.
				quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
				JDE_BU						,
				JDE_object					,
				AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				AX_Dimension_2				,	-- AX_business_unit
				AX_Dimension_3				,	-- AX_department
				AX_Dimension_4				,	-- AX_line_of_business
				AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				waste_code_uid				,
				reference_code,
				purchase_order				,
				release_code				,	
				ticket_number					-- WorkOrderHeader.ticket_number, if there is a linked WO
				,billing_uid				
				,billing_date				
				,workorder_startdate		
			)
			SELECT
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.trans_type,
				link_flag = (
				select
				isnull(
					(
					select top 1 case link_required_flag when 'E' then 'E' else 'T' end
					from billinglinklookup (nolock)
					where receipt_id = b.receipt_id 
					and company_id = b.company_id
					and profit_ctr_id = b.profit_ctr_id
					ORDER BY isnull(link_required_flag, 'Z')
					)
				, 'F')
				),
				/*
				case when exists (
					select 1 from billinglinklookup (nolock)
					where receipt_id = b.receipt_id 
					and company_id = b.company_id
					and profit_ctr_id = b.profit_ctr_id
					and link_required_flag = 'E'
					) then 'E' 
					else 
						case when exists (
							select 1 from billinglinklookup (nolock)
							where receipt_id = b.receipt_id 
							and company_id = b.company_id
							and profit_ctr_id = b.profit_ctr_id
							and link_required_flag <> 'E'
						) then 'T' else 'F' 
						end 
					end AS link_flag,
				*/
				null, --rb 04/06/2015 dbo.fn_get_linked_workorders(b.company_id, b.profit_ctr_id, b.receipt_id) as linked_record, -- Wo's don't list these.  R's do.
				r.receipt_status,
				case when b.status_code = 'I' then 'Invoiced' 
				else 
					CASE r.receipt_status
						WHEN 'L' THEN
							CASE r.fingerpr_status
								WHEN 'A' THEN 'Lab, Accepted'
								WHEN 'H' THEN 'Lab, Hold'
								WHEN 'W' THEN 'Lab, Waiting'
								ELSE 'Unknown Lab Status: ' + r.fingerpr_status
							END
						WHEN 'A' THEN 'Accepted'
						WHEN 'M' THEN 'Manual'
						WHEN 'N' THEN 'New'
						WHEN 'U' THEN 'Unloading'
						ELSE NULL
					END
				end as status_description,
				r.receipt_date,
				pickup_date = (
					select top 1 _date from
					--coalesce(rt.transporter_sign_date, wospu.date_act_arrive, wohpu.start_date)
					(
						select rt.transporter_sign_date _date
						FROM ReceiptTransporter RT WITH(nolock) 
						WHERE  RT.receipt_id = b.receipt_id 
						and RT.company_id = b.company_id 
						and RT.profit_ctr_id = b.profit_ctr_id
						and RT.transporter_sequence_id = 1
						union
						select coalesce(wospu.date_act_arrive, wohpu.start_date) _date
						FROM BillingLinkLookup bllpu (nolock) 
						LEFT JOIN WorkOrderHeader wohpu (nolock) 
							ON wohpu.company_id = bllpu.source_company_id
							AND wohpu.profit_ctr_id = bllpu.source_profit_ctr_id
							AND wohpu.workorder_id = bllpu.source_id					
						LEFT JOIN workorderstop wospu (nolock)
							ON wohpu.workorder_id = wospu.workorder_id
							and wospu.stop_sequence_id = 1
							and wohpu.company_id = wospu.company_id
							and wohpu.profit_ctr_id = wospu.profit_ctr_id
						WHERE  bllpu.receipt_id = b.receipt_id
						and bllpu.company_id = b.company_id
						and bllpu.profit_ctr_id = b.profit_ctr_id
					) y
					WHERE _date is not null
					order by _date
				),
/*
				pickup_date = (
					select top 1 coalesce(rt.transporter_sign_date, wospu.date_act_arrive, wohpu.start_date)
					FROM Receipt rpu (nolock)
					LEFT OUTER JOIN ReceiptTransporter RT WITH(nolock) 
						ON RT.receipt_id = rpu.receipt_id 
						and RT.company_id = rpu.company_id 
						and RT.profit_ctr_id = rpu.profit_ctr_id
						and RT.transporter_sequence_id = 1
					LEFT OUTER JOIN BillingLinkLookup bllpu (nolock) 
						ON rpu.receipt_id = bllpu.receipt_id
						and rpu.company_id = bllpu.company_id
						and rpu.profit_ctr_id = bllpu.profit_ctr_id
					LEFT JOIN WorkOrderHeader wohpu (nolock) 
						ON wohpu.company_id = bllpu.source_company_id
						AND wohpu.profit_ctr_id = bllpu.source_profit_ctr_id
						AND wohpu.workorder_id = bllpu.source_id					
					LEFT JOIN workorderstop wospu (nolock)
						ON wohpu.workorder_id = wospu.workorder_id
						and wospu.stop_sequence_id = 1
						and wohpu.company_id = wospu.company_id
						and wohpu.profit_ctr_id = wospu.profit_ctr_id
					WHERE
						rpu.receipt_id = b.receipt_id
						and rpu.company_id = b.company_id
						and rpu.profit_ctr_id = b.profit_ctr_id
				),
*/				
				r.submitted_flag,
				r.date_submitted,
				r.submitted_by,
				b.status_code as billing_status_code,
				cb.territory_code,
				cb.billing_project_id,
				cb.project_name,
				case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
				b.invoice_code,
				b.invoice_date,
				MONTH(b.invoice_date) invoice_month,
				YEAR(b.invoice_date) invoice_year,
				c.customer_id,
				c.cust_name,
				c.customer_type,
				c.cust_category,
				b.line_id,
				b.price_id,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				bd.billing_type,
				-- Modify: GEM-43800: If Product, call it Distributed?
				-- case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end,
				case when exists ( select 1 from profilequotedetail pqd WHERE pqd.profile_id = r.profile_id and pqd.company_id = r.company_id and pqd.profit_ctr_id = r.profit_ctr_id and pqd.bill_method = 'B' ) then 'D' else 
					case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end
				end as dist_flag,
				bd.dist_company_id,
				bd.dist_profit_ctr_id,
				bd.gl_account_code,
				bd.extended_amt,
				g.generator_id,
				g.generator_name,
				g.epa_id,
				t.treatment_id,
				t.treatment_desc,
				t.treatment_process_id,
				t.treatment_process_process,
				t.disposal_service_id,
				t.disposal_service_desc,
				t.wastetype_id,
				t.wastetype_category,
				t.wastetype_description,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				pqa.quote_id,
				r.product_id,
				r.product_code,
				b.approval_code,
				b.service_desc_1, 
				'A' as pricing_method,
				'T' as quantity_flag,
				NULL as JDE_BU, --bd.JDE_BU,
				NULL as JDE_Object, -- bd.JDE_object,
				bd.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				bd.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				bd.AX_Dimension_2				,	-- AX_business_unit
				bd.AX_Dimension_3				,	-- AX_department
				bd.AX_Dimension_4				,	-- AX_line_of_business
				bd.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				b.waste_code_uid,
				NULL as reference_code,
				b.purchase_order,
				b.release_code,
				woh.ticket_number
				, b.billing_uid
				, b.billing_date
				, woh.start_date
			FROM #TempBilling2 b 
			--WITH (INDEX(idx_billing_actual_status_date))
			join @customer c on b.customer_id = c.customer_id
			INNER JOIN BillingDetail bd (nolock)
				ON bd.billing_uid = b.billing_uid
			INNER JOIN Receipt r (nolock)
				ON b.receipt_id = r.receipt_id
				AND b.line_id = r.line_id
				AND b.company_id = r.company_id
				AND b.profit_ctr_id = r.profit_ctr_id
				and b.trans_source = 'R'
			join #tmp_trans_copc copc
				on bd.dist_company_id = copc.company_id
				and bd.dist_profit_ctr_id = copc.profit_ctr_id
			LEFT OUTER JOIN CustomerBilling cb (nolock)
				ON b.customer_id = cb.customer_id
				AND ISNULL(b.billing_project_id, 0) = cb.billing_project_id
			LEFT OUTER JOIN generator g (nolock)
				ON b.generator_id = g.generator_id
			LEFT OUTER JOIN profilequoteapproval pqa (nolock)
				ON b.profile_id = pqa.profile_id
				AND b.company_id = pqa.company_id
				AND b.profit_ctr_id = pqa.profit_ctr_id
			LEFT OUTER JOIN Treatment t (nolock)
				ON r.treatment_id = t.treatment_id
				AND r.company_id = t.company_id
				AND r.profit_ctr_id = t.profit_ctr_id
			--rb 04/10/2015
			LEFT OUTER JOIN BillingLinkLookup bll (nolock) 
				ON r.receipt_id = bll.receipt_id
				and r.company_id = bll.company_id
				and r.profit_ctr_id = bll.profit_ctr_id
			LEFT JOIN WorkOrderHeader woh (nolock) 
				ON woh.company_id = bll.source_company_id
				AND woh.profit_ctr_id = bll.source_profit_ctr_id
				AND woh.workorder_id = bll.source_id		
			
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Inserted to #InternalFlashWork from #TempBilling2 for Receipts' as status
	set @lasttime = getdate()
			
		end
	end

	--rb 04/06/2015 Pulled this function out of insert statement(s) because we've seen better performance with an update on large data sets

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting linked_record update' as status
	set @lasttime = getdate()

	update #InternalFlashWork
	set linked_record = dbo.fn_get_linked_workorders(company_id, profit_ctr_id, receipt_id)
	where trans_source = 'R'

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished linked_record update' as status
	set @lasttime = getdate()

END
		
--#endregion		
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "In Billing (Receipt), Actual #InternalFlashWork" Population' as status
	set @lasttime = getdate()
	
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "In Billing (Orders), Actual #InternalFlashWork" Population' as status
	set @lasttime = getdate()


--#region trans_source O

--rb 04/10/2015 Had to break single select into 4 separates so indexes to make use of indexes on billing_date/invoice_date, and to allow co/pc join to be defined
IF exists (select 1 from #tmp_source where trans_source = 'O')
BEGIN
	if @copc_search_type = 'T'
	begin
		if ISNULL(@invoice_flag,'') = 'I' begin
			INSERT #InternalFlashWork (
				company_id					,
				profit_ctr_id				,
				trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
				receipt_id					, -- Receipt/Workorder ID
				trans_type					, -- Receipt trans type (O/I)
				trans_status				, -- Receipt or Workorder Status
				status_description			, -- Billing/Transaction status description
				trans_date					, -- Receipt Date or Workorder End Date
				pickup_date					, -- Pickup Date
				submitted_flag				, -- Submitted Flag
				date_submitted				, -- Submitted Date
				submitted_by				, -- Submitted by
				billing_status_code			, -- Billing Status Code
				territory_code				, -- Billing Project Territory code
				billing_project_id			, -- Billing project ID
				billing_project_name		, -- Billing Project Name
				invoice_flag				, -- Invoiced? Flag
				invoice_code				, -- Invoice Code (if invoiced)
				invoice_date				, -- Invoice Date (if invoiced)
				invoice_month				, -- Invoice Date month
				invoice_year				, -- Invoice Date year
				customer_id					, -- Customer ID on Receipt/Workorder
				cust_name					, -- Customer Name
				customer_type				, -- Customer Type
				cust_category				, -- Customer Category
				line_id						, -- Receipt line id
				price_id					, -- Receipt line price id
				ref_line_id					, -- Billing reference line_id (which line does this refer to?)
				workorder_sequence_id		, -- Workorder sequence id
				workorder_resource_item		, -- Workorder Resource Item
				workorder_resource_type		, -- Workorder Resource Type
				quantity					, -- Receipt/Workorder Quantity
				billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
				dist_flag					, -- Distributed Transaction?
				dist_company_id				, -- Distribution Company ID (which company receives the revenue)
				dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
				gl_account_code				, -- GL Account for the revenue
				extended_amt				, -- Revenue amt
				generator_id				, -- Generator ID
				generator_name				, -- Generator Name
				epa_id						, -- Generator EPA ID
				bill_unit_code				, -- Unit
				waste_code					, -- Waste Code
				profile_id					, -- Profile_id
				quote_id					, -- Quote ID
				product_id					, -- BillingDetail product_id, for id'ing fees, etc.
				product_code				, -- Product Code
				approval_code				, -- Approval Code
				approval_desc				,
				pricing_method				, -- Calculated, Actual, etc.
				quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
				JDE_BU						,
				JDE_object					,
				AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				AX_Dimension_2				,	-- AX_business_unit
				AX_Dimension_3				,	-- AX_department
				AX_Dimension_4				,	-- AX_line_of_business
				AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				waste_code_uid				,
				reference_code,
				purchase_order				,
				release_code
				,billing_uid				
				,billing_date				
			)
			SELECT
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.trans_type,
				oh.status,
				case when b.status_code = 'I' then 'Invoiced' 
				else 
					case oh.status
						WHEN 'P' then 'Processed'
						WHEN 'V' then 'Void'
						WHEN 'N' then 'New'
					end
				end as status_description,
				oh.order_date,
				NULL as pickup_date,	-- None here.
				oh.submitted_flag,
				oh.date_submitted,
				oh.submitted_by,
				b.status_code as billing_status_code,
				cb.territory_code,
				cb.billing_project_id,
				cb.project_name,
				case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
				b.invoice_code,
				b.invoice_date,
				MONTH(b.invoice_date),
				YEAR(b.invoice_date),
				c.customer_id,
				c.cust_name,
				c.customer_type,
				c.cust_category,
				b.line_id,
				b.price_id,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				bd.billing_type,
				case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end,
				bd.dist_company_id,
				bd.dist_profit_ctr_id,
				bd.gl_account_code,
				bd.extended_amt,
				g.generator_id,
				g.generator_name,
				g.epa_id,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				pqa.quote_id,
				od.product_id,
				prod.product_code,
				b.approval_code,
				b.service_desc_1, 
				'A' as pricing_method,
				'T' as quantity_flag,
				NULL as JDE_BU, --bd.JDE_BU,
				NULL as JDE_Object, -- bd.JDE_object,
				bd.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				bd.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				bd.AX_Dimension_2				,	-- AX_business_unit
				bd.AX_Dimension_3				,	-- AX_department
				bd.AX_Dimension_4				,	-- AX_line_of_business
				bd.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				b.waste_code_uid,
				NULL as reference_code,
				b.purchase_order,
				b.release_code
				, b.billing_uid
				, b.billing_date
			FROM Billing b WITH (INDEX(idx_billing_status_date))
			--rb 04/08/2015
			--INNER JOIN #tmp_source ts
			--	ON ts.trans_source = b.trans_source
			INNER JOIN BillingDetail bd (nolock)
				ON bd.billing_uid = b.billing_uid
			INNER JOIN OrderHeader oh (nolock)
				ON b.receipt_id = oh.order_id
			INNER JOIN OrderDetail od (nolock)
				on oh.order_id = od.order_id
				and b.company_id = od.company_id
				and b.profit_ctr_id = od.profit_ctr_id
				and b.line_id = od.line_id
			INNER JOIN product prod (nolock)
				on od.product_id = prod.product_id
				and od.company_id = prod.company_id
				and od.profit_ctr_id = prod.profit_ctr_id
			join @customer c on b.customer_id = c.customer_id
			left outer JOIN  generator g (nolock)
				ON b.generator_id = g.generator_id
			left outer JOIN CustomerBilling cb (nolock)
				ON b.customer_id = cb.customer_id
				AND ISNULL(b.billing_project_id, 0) = cb.billing_project_id
			LEFT OUTER JOIN profilequoteapproval pqa (nolock)
				ON b.profile_id = pqa.profile_id
				AND b.company_id = pqa.company_id
				AND b.profit_ctr_id = pqa.profit_ctr_id
			join #tmp_trans_copc copc
				on b.company_id = copc.company_id
				and b.profit_ctr_id = copc.profit_ctr_id
			WHERE 1=1
			-- AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND b.trans_source = 'O'
			AND b.status_code in (select status_code from @Billing_Status_Code)
			-- rb 04/06/2015
			AND b.invoice_date between @date_from and @date_to
			
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Inserted to #InternalFlashWork from Billing for OrderHeaders' as status
	set @lasttime = getdate()
			
			end
		else if isnull(@invoice_flag,'') in ('N', 'S') -- We're pulling from Billing, so it can't be "U"nsubmitted, and this isn't the "I"nvoiced section, so it's N/S
			INSERT #InternalFlashWork (
				company_id					,
				profit_ctr_id				,
				trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
				receipt_id					, -- Receipt/Workorder ID
				trans_type					, -- Receipt trans type (O/I)
				trans_status				, -- Receipt or Workorder Status
				status_description			, -- Billing/Transaction status description
				trans_date					, -- Receipt Date or Workorder End Date
				pickup_date					, -- Pickup Date
				submitted_flag				, -- Submitted Flag
				date_submitted				, -- Submitted Date
				submitted_by				, -- Submitted by
				billing_status_code			, -- Billing Status Code
				territory_code				, -- Billing Project Territory code
				billing_project_id			, -- Billing project ID
				billing_project_name		, -- Billing Project Name
				invoice_flag				, -- Invoiced? Flag
				invoice_code				, -- Invoice Code (if invoiced)
				invoice_date				, -- Invoice Date (if invoiced)
				invoice_month				, -- Invoice Date month
				invoice_year				, -- Invoice Date year
				customer_id					, -- Customer ID on Receipt/Workorder
				cust_name					, -- Customer Name
				customer_type				, -- Customer Type
				cust_category				, -- Customer Category
				line_id						, -- Receipt line id
				price_id					, -- Receipt line price id
				ref_line_id					, -- Billing reference line_id (which line does this refer to?)
				workorder_sequence_id		, -- Workorder sequence id
				workorder_resource_item		, -- Workorder Resource Item
				workorder_resource_type		, -- Workorder Resource Type
				quantity					, -- Receipt/Workorder Quantity
				billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
				dist_flag					, -- Distributed Transaction?
				dist_company_id				, -- Distribution Company ID (which company receives the revenue)
				dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
				gl_account_code				, -- GL Account for the revenue
				extended_amt				, -- Revenue amt
				generator_id				, -- Generator ID
				generator_name				, -- Generator Name
				epa_id						, -- Generator EPA ID
				bill_unit_code				, -- Unit
				waste_code					, -- Waste Code
				profile_id					, -- Profile_id
				quote_id					, -- Quote ID
				product_id					, -- BillingDetail product_id, for id'ing fees, etc.
				product_code				, -- Product Code
				approval_code				, -- Approval Code
				approval_desc				,
				pricing_method				, -- Calculated, Actual, etc.
				quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
				JDE_BU						,
				JDE_object					,
				AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				AX_Dimension_2				,	-- AX_business_unit
				AX_Dimension_3				,	-- AX_department
				AX_Dimension_4				,	-- AX_line_of_business
				AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				waste_code_uid				,
				reference_code,
				purchase_order				,
				release_code
				,billing_uid				
				,billing_date				
			)
			SELECT
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.trans_type,
				oh.status,
				case when b.status_code = 'I' then 'Invoiced' 
				else 
					case oh.status
						WHEN 'P' then 'Processed'
						WHEN 'V' then 'Void'
						WHEN 'N' then 'New'
					end
				end as status_description,
				oh.order_date,
				NULL as pickup_date, -- None here
				oh.submitted_flag,
				oh.date_submitted,
				oh.submitted_by,
				b.status_code as billing_status_code,
				cb.territory_code,
				cb.billing_project_id,
				cb.project_name,
				case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
				b.invoice_code,
				b.invoice_date,
				MONTH(b.invoice_date),
				YEAR(b.invoice_date),
				c.customer_id,
				c.cust_name,
				c.customer_type,
				c.cust_category,
				b.line_id,
				b.price_id,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				bd.billing_type,
				case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end,
				bd.dist_company_id,
				bd.dist_profit_ctr_id,
				bd.gl_account_code,
				bd.extended_amt,
				g.generator_id,
				g.generator_name,
				g.epa_id,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				pqa.quote_id,
				od.product_id,
				prod.product_code,
				b.approval_code,
				b.service_desc_1, 
				'A' as pricing_method,
				'T' as quantity_flag,
				NULL as JDE_BU, --bd.JDE_BU,
				NULL as JDE_Object, -- bd.JDE_object,
				bd.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				bd.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				bd.AX_Dimension_2				,	-- AX_business_unit
				bd.AX_Dimension_3				,	-- AX_department
				bd.AX_Dimension_4				,	-- AX_line_of_business
				bd.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				b.waste_code_uid,
				NULL as reference_code,
				b.purchase_order,
				b.release_code
				, b.billing_uid
				, b.billing_date
			FROM Billing b WITH (INDEX(idx_billing_actual_status_date))
			--rb 04/08/2015
			--INNER JOIN #tmp_source ts
			--	ON ts.trans_source = b.trans_source
			INNER JOIN BillingDetail bd (nolock)
				ON bd.billing_uid = b.billing_uid
			INNER JOIN OrderHeader oh (nolock)
				ON b.receipt_id = oh.order_id
			INNER JOIN OrderDetail od (nolock)
				on oh.order_id = od.order_id
				and b.company_id = od.company_id
				and b.profit_ctr_id = od.profit_ctr_id
				and b.line_id = od.line_id
			INNER JOIN product prod (nolock)
				on od.product_id = prod.product_id
				and od.company_id = prod.company_id
				and od.profit_ctr_id = prod.profit_ctr_id
			join @customer c on b.customer_id = c.customer_id
			join #tmp_trans_copc copc
				on b.company_id = copc.company_id
				and b.profit_ctr_id = copc.profit_ctr_id
			left outer JOIN  generator g (nolock)
				ON b.generator_id = g.generator_id
			left outer JOIN CustomerBilling cb (nolock)
				ON b.customer_id = cb.customer_id
				AND ISNULL(b.billing_project_id, 0) = cb.billing_project_id
			LEFT OUTER JOIN profilequoteapproval pqa (nolock)
				ON b.profile_id = pqa.profile_id
				AND b.company_id = pqa.company_id
				AND b.profit_ctr_id = pqa.profit_ctr_id
			WHERE 1=1
			-- AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND b.trans_source = 'O'
			AND b.status_code in (select status_code from @Billing_Status_Code)
			-- rb 04/06/2015
			AND b.billing_date between @date_from and @date_to

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Inserted to #InternalFlashWork from Billing for OrderHeaders' as status
	set @lasttime = getdate()

	end

	else if @copc_search_type = 'D'
	begin
		if ISNULL(@invoice_flag,'') = 'I' begin
			INSERT #InternalFlashWork (
				company_id					,
				profit_ctr_id				,
				trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
				receipt_id					, -- Receipt/Workorder ID
				trans_type					, -- Receipt trans type (O/I)
				trans_status				, -- Receipt or Workorder Status
				status_description			, -- Billing/Transaction status description
				trans_date					, -- Receipt Date or Workorder End Date
				pickup_date					, -- Pickup Date
				submitted_flag				, -- Submitted Flag
				date_submitted				, -- Submitted Date
				submitted_by				, -- Submitted by
				billing_status_code			, -- Billing Status Code
				territory_code				, -- Billing Project Territory code
				billing_project_id			, -- Billing project ID
				billing_project_name		, -- Billing Project Name
				invoice_flag				, -- Invoiced? Flag
				invoice_code				, -- Invoice Code (if invoiced)
				invoice_date				, -- Invoice Date (if invoiced)
				invoice_month				, -- Invoice Date month
				invoice_year				, -- Invoice Date year
				customer_id					, -- Customer ID on Receipt/Workorder
				cust_name					, -- Customer Name
				customer_type				, -- Customer Type
				cust_category				, -- Customer Category
				line_id						, -- Receipt line id
				price_id					, -- Receipt line price id
				ref_line_id					, -- Billing reference line_id (which line does this refer to?)
				workorder_sequence_id		, -- Workorder sequence id
				workorder_resource_item		, -- Workorder Resource Item
				workorder_resource_type		, -- Workorder Resource Type
				quantity					, -- Receipt/Workorder Quantity
				billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
				dist_flag					, -- Distributed Transaction?
				dist_company_id				, -- Distribution Company ID (which company receives the revenue)
				dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
				gl_account_code				, -- GL Account for the revenue
				extended_amt				, -- Revenue amt
				generator_id				, -- Generator ID
				generator_name				, -- Generator Name
				epa_id						, -- Generator EPA ID
				bill_unit_code				, -- Unit
				waste_code					, -- Waste Code
				profile_id					, -- Profile_id
				quote_id					, -- Quote ID
				product_id					, -- BillingDetail product_id, for id'ing fees, etc.
				product_code				, -- Product Code
				approval_code				, -- Approval Code
				approval_desc				,
				pricing_method				, -- Calculated, Actual, etc.
				quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
				JDE_BU						,
				JDE_object					,
				AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				AX_Dimension_2				,	-- AX_business_unit
				AX_Dimension_3				,	-- AX_department
				AX_Dimension_4				,	-- AX_line_of_business
				AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				waste_code_uid				,
				reference_code,
				purchase_order				,
				release_code
				,billing_uid				
				,billing_date				
			)
			SELECT
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.trans_type,
				oh.status,
				case when b.status_code = 'I' then 'Invoiced' 
				else 
					case oh.status
						WHEN 'P' then 'Processed'
						WHEN 'V' then 'Void'
						WHEN 'N' then 'New'
					end
				end as status_description,
				oh.order_date,
				NULL as pickup_date, -- None here
				oh.submitted_flag,
				oh.date_submitted,
				oh.submitted_by,
				b.status_code as billing_status_code,
				cb.territory_code,
				cb.billing_project_id,
				cb.project_name,
				case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
				b.invoice_code,
				b.invoice_date,
				MONTH(b.invoice_date),
				YEAR(b.invoice_date),
				c.customer_id,
				c.cust_name,
				c.customer_type,
				c.cust_category,
				b.line_id,
				b.price_id,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				bd.billing_type,
				case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end,
				bd.dist_company_id,
				bd.dist_profit_ctr_id,
				bd.gl_account_code,
				bd.extended_amt,
				g.generator_id,
				g.generator_name,
				g.epa_id,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				pqa.quote_id,
				od.product_id,
				prod.product_code,
				b.approval_code,
				b.service_desc_1, 
				'A' as pricing_method,
				'T' as quantity_flag,
				NULL as JDE_BU, --bd.JDE_BU,
				NULL as JDE_Object, -- bd.JDE_object,
				bd.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				bd.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				bd.AX_Dimension_2				,	-- AX_business_unit
				bd.AX_Dimension_3				,	-- AX_department
				bd.AX_Dimension_4				,	-- AX_line_of_business
				bd.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				b.waste_code_uid,
				NULL as reference_code,
				b.purchase_order,
				b.release_code
				, b.billing_uid
				, b.billing_date				
			FROM Billing b WITH (INDEX(idx_billing_status_date))
			--rb 04/08/2015
			--INNER JOIN #tmp_source ts
			--	ON ts.trans_source = b.trans_source
			INNER JOIN BillingDetail bd (nolock)
				ON bd.billing_uid = b.billing_uid
			INNER JOIN OrderHeader oh (nolock)
				ON b.receipt_id = oh.order_id
			INNER JOIN OrderDetail od (nolock)
				on oh.order_id = od.order_id
				and b.company_id = od.company_id
				and b.profit_ctr_id = od.profit_ctr_id
				and b.line_id = od.line_id
			INNER JOIN product prod (nolock)
				on od.product_id = prod.product_id
				and od.company_id = prod.company_id
				and od.profit_ctr_id = prod.profit_ctr_id
			join @customer c on b.customer_id = c.customer_id
			join #tmp_trans_copc copc
				on bd.dist_company_id = copc.company_id
				and bd.dist_profit_ctr_id = copc.profit_ctr_id
			left outer JOIN  generator g (nolock)
				ON b.generator_id = g.generator_id
			left outer JOIN CustomerBilling cb (nolock)
				ON b.customer_id = cb.customer_id
				AND ISNULL(b.billing_project_id, 0) = cb.billing_project_id
			LEFT OUTER JOIN profilequoteapproval pqa (nolock)
				ON b.profile_id = pqa.profile_id
				AND b.company_id = pqa.company_id
				AND b.profit_ctr_id = pqa.profit_ctr_id

			WHERE 1=1
			-- AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND b.trans_source = 'O'
			AND b.status_code in (select status_code from @Billing_Status_Code)
			-- rb 04/06/2015
			AND b.invoice_date between @date_from and @date_to

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Inserted to #InternalFlashWork from Billing for OrderHeaders' as status
	set @lasttime = getdate()
			
			end
		else if isnull(@invoice_flag,'') in ('N', 'S') -- We're pulling from Billing, so it can't be "U"nsubmitted, and this isn't the "I"nvoiced section, so it's N/S
			INSERT #InternalFlashWork (
				company_id					,
				profit_ctr_id				,
				trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
				receipt_id					, -- Receipt/Workorder ID
				trans_type					, -- Receipt trans type (O/I)
				trans_status				, -- Receipt or Workorder Status
				status_description			, -- Billing/Transaction status description
				trans_date					, -- Receipt Date or Workorder End Date
				pickup_date					, -- Pickup Date
				submitted_flag				, -- Submitted Flag
				date_submitted				, -- Submitted Date
				submitted_by				, -- Submitted by
				billing_status_code			, -- Billing Status Code
				territory_code				, -- Billing Project Territory code
				billing_project_id			, -- Billing project ID
				billing_project_name		, -- Billing Project Name
				invoice_flag				, -- Invoiced? Flag
				invoice_code				, -- Invoice Code (if invoiced)
				invoice_date				, -- Invoice Date (if invoiced)
				invoice_month				, -- Invoice Date month
				invoice_year				, -- Invoice Date year
				customer_id					, -- Customer ID on Receipt/Workorder
				cust_name					, -- Customer Name
				customer_type				, -- Customer Type
				cust_category				, -- Customer Category
				line_id						, -- Receipt line id
				price_id					, -- Receipt line price id
				ref_line_id					, -- Billing reference line_id (which line does this refer to?)
				workorder_sequence_id		, -- Workorder sequence id
				workorder_resource_item		, -- Workorder Resource Item
				workorder_resource_type		, -- Workorder Resource Type
				quantity					, -- Receipt/Workorder Quantity
				billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
				dist_flag					, -- Distributed Transaction?
				dist_company_id				, -- Distribution Company ID (which company receives the revenue)
				dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
				gl_account_code				, -- GL Account for the revenue
				extended_amt				, -- Revenue amt
				generator_id				, -- Generator ID
				generator_name				, -- Generator Name
				epa_id						, -- Generator EPA ID
				bill_unit_code				, -- Unit
				waste_code					, -- Waste Code
				profile_id					, -- Profile_id
				quote_id					, -- Quote ID
				product_id					, -- BillingDetail product_id, for id'ing fees, etc.
				product_code				, -- Product Code
				approval_code				, -- Approval Code
				approval_desc				,
				pricing_method				, -- Calculated, Actual, etc.
				quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
				JDE_BU						,
				JDE_object					,
				AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				AX_Dimension_2				,	-- AX_business_unit
				AX_Dimension_3				,	-- AX_department
				AX_Dimension_4				,	-- AX_line_of_business
				AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				waste_code_uid				,
				reference_code,
				purchase_order				,
				release_code
				, billing_uid
				, billing_date
			)
			SELECT
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.trans_type,
				oh.status,
				case when b.status_code = 'I' then 'Invoiced' 
				else 
					case oh.status
						WHEN 'P' then 'Processed'
						WHEN 'V' then 'Void'
						WHEN 'N' then 'New'
					end
				end as status_description,
				oh.order_date,
				NULL as pickup_date, -- None here
				oh.submitted_flag,
				oh.date_submitted,
				oh.submitted_by,
				b.status_code as billing_status_code,
				cb.territory_code,
				cb.billing_project_id,
				cb.project_name,
				case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
				b.invoice_code,
				b.invoice_date,
				MONTH(b.invoice_date),
				YEAR(b.invoice_date),
				c.customer_id,
				c.cust_name,
				c.customer_type,
				c.cust_category,
				b.line_id,
				b.price_id,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				bd.billing_type,
				case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end,
				bd.dist_company_id,
				bd.dist_profit_ctr_id,
				bd.gl_account_code,
				bd.extended_amt,
				g.generator_id,
				g.generator_name,
				g.epa_id,
				b.bill_unit_code,
				b.waste_code,
				b.profile_id,
				pqa.quote_id,
				od.product_id,
				prod.product_code,
				b.approval_code,
				b.service_desc_1, 
				'A' as pricing_method,
				'T' as quantity_flag,
				NULL as JDE_BU, --bd.JDE_BU,
				NULL as JDE_Object, -- bd.JDE_object,
				bd.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				bd.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				bd.AX_Dimension_2				,	-- AX_business_unit
				bd.AX_Dimension_3				,	-- AX_department
				bd.AX_Dimension_4				,	-- AX_line_of_business
				bd.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				bd.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				b.waste_code_uid,
				NULL as reference_code,
				b.purchase_order,
				b.release_code
				, b.billing_uid
				, b.billing_date
			FROM Billing b WITH (INDEX(idx_billing_actual_status_date))
			--rb 04/08/2015
			--INNER JOIN #tmp_source ts
			--	ON ts.trans_source = b.trans_source
			INNER JOIN BillingDetail bd (nolock)
				ON bd.billing_uid = b.billing_uid
			INNER JOIN OrderHeader oh (nolock)
				ON b.receipt_id = oh.order_id
			INNER JOIN OrderDetail od (nolock)
				on oh.order_id = od.order_id
				and b.company_id = od.company_id
				and b.profit_ctr_id = od.profit_ctr_id
				and b.line_id = od.line_id
			INNER JOIN product prod (nolock)
				on od.product_id = prod.product_id
				and od.company_id = prod.company_id
				and od.profit_ctr_id = prod.profit_ctr_id
			join @customer c on b.customer_id = c.customer_id
			join #tmp_trans_copc copc
				on bd.dist_company_id = copc.company_id
				and bd.dist_profit_ctr_id = copc.profit_ctr_id
			left outer JOIN  generator g (nolock)
				ON b.generator_id = g.generator_id
			left outer JOIN CustomerBilling cb (nolock)
				ON b.customer_id = cb.customer_id
				AND ISNULL(b.billing_project_id, 0) = cb.billing_project_id
			LEFT OUTER JOIN profilequoteapproval pqa (nolock)
				ON b.profile_id = pqa.profile_id
				AND b.company_id = pqa.company_id
				AND b.profit_ctr_id = pqa.profit_ctr_id
			WHERE 1=1
			-- AND b.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND b.trans_source = 'O'
			AND b.status_code in (select status_code from @Billing_Status_Code)
			-- rb 04/06/2015
			AND b.billing_date between @date_from and @date_to

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Inserted to #InternalFlashWork from Billing for OrderHeaders' as status
	set @lasttime = getdate()

	end
END

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "In Billing (Orders), Actual #InternalFlashWork" Population' as status
	set @lasttime = getdate()
	
-- This concludes the IN BILLING email content.


--#endregion



-----------------------------------------------------------------------------------
-- NOT INVOICED RECORDS
--END ELSE BEGIN
-----------------------------------------------------------------------------------

/*
	"NOT IN BILLING" EMail content

	If not in billing
					If Workorder
								If not fixed price
									Select from workorder
										If not priced - *** You know, the query below doesn't actually specify this. Hmm.
											Select Project, customer, base


	*/
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "Not In Billing, Workorder (NON Disposal), Not Fixed price, Not Priced" Population' as status
	set @lasttime = getdate()
--#region non-disposal work order, not invoiced
	
	-- First, the NON Disposal WO records

	IF exists (select 1 from #tmp_source where trans_source = 'W')
	--rb 04/08/2015 Originally had "AND @invoice_flag = 'N'" in the where clause, which the optimizer ignored before starting work (most likely the subselect in where clause)
		AND @invoice_flag IN ('N', 'U') -- Non-Billing source, and submitted_flag = 'F' below, so this is Not invoiced or Unsubmitted
		begin

			drop table if exists #woh

			select woh.workorder_id
				, woh.company_id
				, woh.profit_ctr_id
				, woh.workorder_type_id
				, woh.customer_id
				, woh.billing_project_id
				, woh.generator_id
				, woh.workorder_status
				, woh.start_date
				, woh.end_date
				, woh.submitted_flag
				, woh.date_submitted
				, woh.submitted_by
				, woh.fixed_price_flag
				, woh.quote_ID
				, woh.project_code
				, woh.reference_code
				, woh.purchase_order
				, woh.release_code
				, woh.ticket_number		
				, woh.AX_dimension_5_part_1
				, woh.AX_dimension_5_part_2
			into #woh
			From Workorderheader woh
			join @customer custfilter on woh.customer_id = custfilter.customer_id
				WHERE 1=1
					AND (
						woh.submitted_flag = 'F' 
					)
					AND isnull(woh.fixed_price_flag, 'F') = 'F'
					AND isnull(woh.start_date, @date_from + 0.0001) BETWEEN @date_from AND @date_to -- ??? start_date or end_date?
					-- AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
					AND woh.workorder_status NOT IN ('V','X','T')
					AND NOT EXISTS (
						SELECT 1
						FROM WorkorderQuoteHeader (nolock)
						WHERE project_code = woh.project_code
						AND quote_type = 'P'
						AND company_id = woh.company_id
						AND fixed_price_flag = 'T'
					)

			create index idx6 on #woh (workorder_id, company_id, profit_ctr_id)
			create index idx7 on #woh (customer_id, billing_project_id)
			create index idx8 on #woh (generator_id)


	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#woh key table created/populated' as status
	set @lasttime = getdate()

		drop table if exists #keys
			select distinct
				woh.company_id
				, woh.profit_ctr_id
				, woh.workorder_id
				, wod.resource_type
				, wod.sequence_id
				, wod.bill_rate
				, wod.resource_class_code
				, wod.bill_unit_code
				, wod.tsdf_code
				, wod.tsdf_approval_id
				, wod.quantity_used
				, wod.quantity
				, woh.workorder_status
				, woh.start_date
				, woh.end_date
				, woh.submitted_flag
				, woh.date_submitted
				, woh.submitted_by
				, woh.fixed_price_flag
				, woh.quote_ID
				, woh.workorder_type_id
				, woh.customer_id
				, woh.billing_project_id
				, woh.project_code
				, woh.generator_id
				, woh.reference_code
				, woh.purchase_order
				, woh.release_code
				, woh.ticket_number		
				, woh.AX_dimension_5_part_1
				, woh.AX_dimension_5_part_2
				INTO #keys
				FROM #woh woh (nolock)
				INNER JOIN #tmp_trans_copc copc
					ON woh.company_id = copc.company_id
					AND woh.profit_ctr_id = copc.profit_ctr_id
				JOIN ProfitCenter ON ProfitCenter.profit_ctr_id = woh.profit_ctr_id
					AND ProfitCenter.company_id = woh.company_id
				LEFT JOIN WorkOrderDetail wod (nolock)
					ON woh.workorder_id = wod.workorder_id
					AND woh.company_id = wod.company_id
					AND woh.profit_ctr_id = wod.profit_ctr_id
					AND wod.resource_type <> 'D'
					AND wod.bill_rate > 0
					AND NOT(wod.resource_type IN ('E','L','S')
					AND RTRIM(ISNULL(wod.group_code, '')) <> '')

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#keys table created/populated' as status
	set @lasttime = getdate()


				INSERT #InternalFlashWork (
					company_id					,
					profit_ctr_id				,
					trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
					receipt_id					, -- Receipt/Workorder ID
					trans_type					, 
					workorder_type				, -- WorkOrderType.account_desc
					trans_status				, -- Receipt or Workorder Status
					link_flag					,
					linked_record				,
					status_description			, -- Billing/Transaction status description
					trans_date					, -- Receipt Date or Workorder End Date
					pickup_date					, -- Pickup Date
					submitted_flag				, -- Submitted Flag
					date_submitted				, -- Submitted Date
					submitted_by				, -- Submitted by
					territory_code				, -- Billing Project Territory code
					billing_project_id			, -- Billing project ID
					billing_project_name		, -- Billing Project Name
					customer_id					, -- Customer ID on Receipt/Workorder
					cust_name					, -- Customer Name
					customer_type				, -- Customer Type
					cust_category				, -- Customer Category
					line_id						,
					price_id					,
					workorder_sequence_id		, -- Workorder sequence id
					workorder_resource_item		, -- Workorder Resource Item
					workorder_resource_type		, -- Workorder Resource Type
					Workorder_resource_category , -- Workorder Resource Category
					quantity					, -- Receipt/Workorder Quantity
					dist_flag,
					dist_company_id				, -- Distribution Company ID (which company receives the revenue)
					dist_profit_ctr_id			, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
					gl_account_code				, -- GL Account for the revenue
					extended_amt				, -- Revenue amt
					generator_id				, -- Generator ID
					generator_name				, -- Generator Name
					epa_id						, -- Generator EPA ID
					bill_unit_code				, -- Unit
					quote_id					, -- Quote ID
					TSDF_code					, -- TSDF Code
					TSDF_EQ_FLAG				, -- TSDF: Is this an EQ tsdf?
					fixed_price_flag			, -- Fixed Price Flag
					pricing_method				, -- Calculated, Actual, etc.
					approval_desc,
					quantity_flag,				  -- T = has quantities, F = no quantities, so 0 used.
					billing_type				,
					JDE_BU						,
					JDE_object					,
					AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
					AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
					AX_Dimension_2				,	-- AX_business_unit
					AX_Dimension_3				,	-- AX_department
					AX_Dimension_4				,	-- AX_line_of_business
					AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
					AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
					AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
					reference_code,
					purchase_order				,
					release_code				,	
					ticket_number					-- WorkOrderHeader.ticket_number
					,workorder_startdate		
				)
				SELECT
					woh.company_id,
					woh.profit_ctr_id,
					'W' as trans_source,
					woh.workorder_id as receipt_id,
					'O' AS trans_type,
					woth.account_desc,
					woh.workorder_status AS trans_status,
						link_flag = (
						select
						isnull(
							(
							select top 1 case link_required_flag when 'E' then 'E' else 'T' end
							from billinglinklookup (nolock)
							where source_id = woh.workorder_id
							and source_company_id = woh.company_id
							and source_profit_ctr_id = woh.profit_ctr_id
							--and link_required_flag = 'E'
							ORDER BY isnull(link_required_flag , 'z')
							)
						, 'F')
						),
					/*
					case when exists (
						select 1 from billinglinklookup (nolock)
						where source_id = woh.workorder_id 
						and source_company_id = woh.company_id
						and source_profit_ctr_id = woh.profit_ctr_id
						and link_required_flag = 'E'
						) then 'E' 
						else 
							case when exists (
								select 1 from billinglinklookup (nolock)
								where source_id = woh.workorder_id 
								and source_company_id = woh.company_id
								and source_profit_ctr_id = woh.profit_ctr_id
								and link_required_flag <> 'E'
							) then 'T' else 'F' 
							end 
						end AS link_flag,
					*/
					null as linked_record, -- Wo's don't list these.  R's do.
					CASE woh.workorder_status
						WHEN 'A' THEN 'Accepted'
						WHEN 'C' THEN 'Completed'
						WHEN 'N' THEN 'New'
					END as status_description,
					woh.end_date AS trans_date,
					COALESCE(wos.date_act_arrive, woh.start_date) as pickup_date,
					woh.submitted_flag,
					woh.date_submitted,
					woh.submitted_by,
					CustomerBilling.territory_code,
					CustomerBilling.billing_project_id,
					CustomerBilling.project_name,
					Customer.customer_id,
					Customer.cust_name,
					Customer.customer_type,
					Customer.cust_category,
					woh.sequence_id AS line_id,
					1 AS price_id,
					woh.sequence_id,
					woh.resource_class_code,
					woh.resource_type,
					NULL AS Workorder_resource_category,
					sum(coalesce(woh.quantity_used, woh.quantity, 0)) quantity,
					'N' as dist_flag,		
					woh.company_id dist_company_id,
					woh.profit_ctr_id dist_profit_ctr_id,
					--COALESCE(rc.gl_account_code, 
					--	wort.gl_seg_1 + RIGHT('00' + CONVERT(VARCHAR(2),woh.company_id), 2) 
					--	+ RIGHT('00' + CONVERT(VARCHAR(2),woh.profit_ctr_ID), 2) + woth.gl_seg_4),
					gl_account_code = null, -- dbo.fn_get_workorder_glaccount(woh.company_id, woh.profit_ctr_id, woh.workorder_id, woh.resource_type, woh.sequence_id),
					dbo.fn_workorder_line_price (woh.company_id, woh.profit_ctr_id, woh.workorder_id, woh.resource_type, woh.bill_unit_code, woh.sequence_id) as extended_amt,
					Generator.generator_id,
					Generator.generator_name,
					Generator.epa_id,
					woh.bill_unit_code,
					woh.quote_ID,
					TSDF.TSDF_code,
					TSDF.EQ_FLAG AS TSDF_EQ_FLAG,
					woh.fixed_price_flag,
					'C' AS pricing_method,
					tsdfa.waste_desc,
					CASE WHEN ISNULL(woh.quantity_used, 0) <> 0 THEN 'T' ELSE 'F' END AS quantity_flag,
					'WorkOrder' as billing_type,
					JDE_BU = null, -- dbo.fn_get_workorder_JDE_glaccount_business_unit (woh.company_id, woh.profit_ctr_id, woh.workorder_id, woh.resource_type, woh.sequence_id),
					JDE_object = null, -- dbo.fn_get_workorder_JDE_glaccount_object (woh.company_id, woh.profit_ctr_id, woh.workorder_id, woh.resource_type, woh.sequence_id),
		 			AX_MainAccount = dbo.fn_get_workorder_AX_main_account(woh.workorder_type_id,woh.company_id, woh.profit_ctr_id,'O', woh.workorder_ID),
					AX_Dimension_1 = ProfitCenter.AX_Dimension_1,
					--AX_Dimension_2 = case when ProfitCenter.wo_bu_configuration_flag = 'T' 
					--					then COALESCE(NULLIF(WorkOrderTypeDetail.AX_Dimension_2, ''), WorkOrderTypeDetail.AX_Dimension_2) 
					--				  else ProfitCenter.AX_Dimension_2 end ,
					AX_Dimension_2 = case when ProfitCenter.wo_bu_configuration_flag = 'T' then 
								  COALESCE( case when WorkOrderTypedetail.AX_Dimension_2 =  '' then ProfitCenter.AX_Dimension_2 
											else   WorkOrderTypedetail.AX_Dimension_2 end, WorkOrderTypedetail.AX_Dimension_2) 
									else ProfitCenter.AX_Dimension_2 end,	
					AX_Dimension_3 = WorkOrderTypeDetail.AX_Dimension_3,
					AX_Dimension_4 = dbo.fn_get_workorder_AX_dim4_LOB(woh.company_id, woh.profit_ctr_id,woh.workorder_id),
					/*  JPB
						Paul K says on 4/5/2023...
						"if not in billing just pull from WorkOrderHeader.AX_Dimension_5_Part_1 and WorkOrderHeader.AX_Dimension_5_Part_2"

						old:
						AX_Dimension_5_part_1 = dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id),
						AX_Dimension_5_part_2 = 'calcdim5', -- 'calcdim5' is a placeholder to indicate this row needs its AX 5 1/2 values formatted, without re-calling the same function 10x
					*/
					AX_Dimension_5_part_1 = isnull(woh.AX_Dimension_5_part_1, ''),
					AX_Dimension_5_part_2 = isnull(woh.AX_Dimension_5_part_2, ''),

					AX_Dimension_6 = WorkOrderTypeDetail.AX_Dimension_6, --NULLIF(WorkOrderTypeDetail.AX_Dimension_6,' '),
					woh.reference_code,
					ISNULL(REPLACE(woh.purchase_order,'''', ''),'') AS purchase_order,
					ISNULL(REPLACE(woh.release_code,'''', ''),'') AS release_code,
					woh.ticket_number
					, woh.start_date
				FROM #keys woh (nolock)
				JOIN ProfitCenter ON ProfitCenter.profit_ctr_id = woh.profit_ctr_id
					AND ProfitCenter.company_id = woh.company_id
				INNER JOIN WorkOrderTypeHeader woth (nolock)
					ON woth.workorder_type_id = woh.workorder_type_id	
				join @customer Customer on woh.customer_id = Customer.customer_id
				LEFT OUTER JOIN CustomerBilling (nolock)
					ON woh.customer_id = CustomerBilling.customer_id
					AND ISNULL(woh.billing_project_id, 0) = CustomerBilling.billing_project_id
				LEFT OUTER JOIN Generator (nolock)
					ON woh.generator_id = Generator.generator_id
				LEFT OUTER JOIN TSDF (nolock)
					ON woh.tsdf_code = TSDF.tsdf_code
				--LEFT OUTER JOIN ResourceClass rc (nolock)
				--	ON woh.resource_class_code = rc.resource_class_code
				--	AND woh.resource_type = rc.resource_type
				--	AND woh.company_id = rc.company_id
				--	AND woh.profit_ctr_id = rc.profit_ctr_id
				--	and woh.bill_unit_code = rc.bill_unit_code
				LEFT OUTER JOIN TSDFApproval tsdfa (nolock)
					ON woh.tsdf_approval_id = tsdfa.tsdf_approval_id
				LEFT JOIN WorkorderStop wos (nolock)
					ON woh.workorder_id = wos.workorder_id
					and wos.stop_sequence_id = 1
					and woh.company_id = wos.company_id
					and woh.profit_ctr_id = wos.profit_ctr_id
				LEFT OUTER JOIN ( SELECT DISTINCT 
										  workorder_type_id
										  , company_id
										  , profit_ctr_id
										  , customer_id
										  , AX_MainAccount_Part_1 AS AX_MainAccount_Part_1
										  , AX_Dimension_3 AS AX_Dimension_3
										  , AX_Dimension_4_Base AS AX_Dimension_4_Base
										  , AX_Dimension_4_Event AS AX_Dimension_4_Event
										  , AX_Dimension_5_Part_1 AS AX_Dimension_5_Part_1
										  , AX_Dimension_5_Part_2 AS AX_Dimension_5_Part_2
										  , AX_Dimension_6 AS AX_Dimension_6
										  , AX_Project_Required_Flag
										  , AX_Dimension_2
								   FROM WorkOrderTypeDetail
								   WHERE 1=1
					  ) WorkOrderTypeDetail ON WorkOrderTypeDetail.workorder_type_id = woh.workorder_type_id 
							 AND WorkOrderTypeDetail.company_id = woh.company_id
							 AND WorkOrderTypeDetail.profit_ctr_id = woh.profit_ctr_id
							 AND (WorkOrderTypeDetail.customer_id IS NULL OR woh.customer_id = WorkOrderTypeDetail.customer_id )

			GROUP BY
					woh.company_id,
					woh.profit_ctr_id,
					woh.workorder_id,
					woth.account_desc,
					woh.workorder_status,
					CASE woh.workorder_status
						WHEN 'A' THEN 'Accepted'
						WHEN 'C' THEN 'Completed'
						WHEN 'N' THEN 'New'
					END,
					woh.end_date,
					COALESCE(wos.date_act_arrive, woh.start_date),
					woh.submitted_flag,
					woh.date_submitted,
					woh.submitted_by,
					CustomerBilling.territory_code,
					CustomerBilling.billing_project_id,
					CustomerBilling.project_name,
					Customer.customer_id,
					Customer.cust_name,
					Customer.customer_type,
					Customer.cust_category,
					woh.sequence_id,
					woh.resource_class_code,
					woh.bill_rate,
					woh.resource_type,
					--rc.gl_account_code, 
					--wort.gl_seg_1,
					woh.company_id, 
					woh.profit_ctr_ID,
					--woth.gl_seg_4,
					Generator.generator_id,
					Generator.generator_name,
					Generator.epa_id,
					woh.bill_unit_code,
					woh.quote_ID,
					TSDF.TSDF_code,
					TSDF.EQ_FLAG,
					woh.fixed_price_flag,
					tsdfa.waste_desc,
					CASE WHEN ISNULL(woh.quantity_used, 0) <> 0 THEN 'T' ELSE 'F' END,
					woh.workorder_type_id,
					ProfitCenter.AX_Dimension_1,
					ProfitCenter.wo_bu_configuration_flag,
					WorkOrderTypeDetail.AX_Dimension_2,
					ProfitCenter.AX_Dimension_2,
					WorkOrderTypeDetail.AX_Dimension_3,
					woh.AX_Dimension_5_part_1,
					woh.AX_Dimension_5_part_2,
					WorkOrderTypeDetail.AX_Dimension_6,
					woh.reference_code,
					ISNULL(REPLACE(woh.purchase_order,'''', ''),''),
					ISNULL(REPLACE(woh.release_code,'''', ''),''),
					woh.ticket_number
					, woh.start_date

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#InternalFlashWork populated from #keys' as status
	set @lasttime = getdate()

		end			

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "Not In Billing, Workorder (NON Disposal), Not Fixed price, Not Priced" Population' as status
	set @lasttime = getdate()
	
	
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting AX Dim 5 Update' as status
	set @lasttime = getdate()

/*
On 4/5/2023 per PaulK, no longer using this logic -just pulling part1/part2 values from WorkorderHeader.

		update #InternalFlashWork set
			AX_Dimension_5_part_2 = isnull(
				case when AX_Dimension_5_part_1 like '%.%'
				then
					substring(AX_Dimension_5_part_1, 
					charindex('.',AX_Dimension_5_part_1)+1,
					len(AX_Dimension_5_part_1))
				else null
				end, ''),
			AX_Dimension_5_part_1 = isnull(
				case when AX_Dimension_5_part_1 <> '' 
				then 
					substring(AX_Dimension_5_part_1, 1, charindex('.',AX_Dimension_5_part_1+'.')-1 ) 
				end, '')
		WHERE AX_Dimension_5_part_2 = 'calcdim5'

		And before that...
			was...
				AX_Dimension_5_part_1 = ISNull( case when dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id) <> '' 
                    then substring(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id), 1, 
                    case when charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id))=0
                    then len(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id)) 
                    else charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id))-1 
                    end) end  , '' ),
                   --  else 'X' end,
                   
				AX_Dimension_5_part_2 = ISNULL ( case when charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id)) = 0
				    then null 
					else substring(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id), 
					charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id))+1,
					len(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id)))end, '' ),
					
*/


	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Done with AX Dim 5 Update' as status
	set @lasttime = getdate()
	
--#endregion	


--#region wo disposal
	
	-- Now, the Disposal WO records
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "Not In Billing, Workorder (Disposal), Not Fixed price, Not Priced" Population' as status

	set @lasttime = getdate()
	
	IF exists (select 1 from #tmp_source where trans_source = 'W')
	--rb 04/08/2015 Originally had "AND @invoice_flag IN ('N', 'S', 'U')" in the where clause, which the optimizer ignored before starting work (most likely the subselect in where clause)
		AND @invoice_flag IN ('N', 'U') -- Non-Billing source, and submitted_flag = 'F' below, so this is Not invoiced or Unsubmitted

		INSERT #InternalFlashWork (
			company_id					,
			profit_ctr_id				,
			trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
			receipt_id					, -- Receipt/Workorder ID
			trans_type					,
			workorder_type				, -- WorkOrderType.account_desc
			trans_status				, -- Receipt or Workorder Status
			link_flag,
			linked_record,
			status_description			, -- Billing/Transaction status description
			trans_date					, -- Receipt Date or Workorder End Date
			pickup_date					, -- Pickup Date
			submitted_flag				, -- Submitted Flag
			date_submitted				, -- Submitted Date
			submitted_by				, -- Submitted by
			territory_code				, -- Billing Project Territory code
			billing_project_id			, -- Billing project ID
			billing_project_name		, -- Billing Project Name
			customer_id					, -- Customer ID on Receipt/Workorder
			cust_name					, -- Customer Name
			customer_type				, -- Customer Type
			cust_category				, -- Customer Category
			line_id						,
			price_id					,
			workorder_sequence_id		, -- Workorder sequence id
			workorder_resource_item		, -- Workorder Resource Item
			workorder_resource_type		, -- Workorder Resource Type
			Workorder_resource_category , -- Workorder Resource Category
			quantity					, -- Receipt/Workorder Quantity
			dist_flag,
			dist_company_id				, -- Distribution Company ID (which company receives the revenue)
			dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
			gl_account_code				, -- GL Account for the revenue
			extended_amt				, -- Revenue amt
			generator_id				, -- Generator ID
			generator_name				, -- Generator Name
			epa_id						, -- Generator EPA ID
			bill_unit_code				, -- Unit
			quote_id					, -- Quote ID
			TSDF_code					, -- TSDF Code
			TSDF_EQ_FLAG				, -- TSDF: Is this an EQ tsdf?
			fixed_price_flag			, -- Fixed Price Flag
			pricing_method				, -- Calculated, Actual, etc.
			approval_desc,
			quantity_flag,					-- T = has quantities, F = no quantities, so 0 used.
			billing_type				,
			JDE_BU						,
			JDE_object					,
			AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
			AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
			AX_Dimension_2				,	-- AX_business_unit
			AX_Dimension_3				,	-- AX_department
			AX_Dimension_4				,	-- AX_line_of_business
			AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
			AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
			AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
			reference_code,
			purchase_order				,
			release_code				,	
			ticket_number					-- WorkOrderHeader.ticket_number
			,workorder_startdate		
		)
		SELECT
			woh.company_id,
			woh.profit_ctr_id,
			'W',
			woh.workorder_id,
			'O' AS trans_type,
			woth.account_desc,
			woh.workorder_status AS trans_status,
			link_flag = (
			select
			isnull(
				(
				select top 1 case link_required_flag when 'E' then 'E' else 'T' end
				from billinglinklookup (nolock)
				where source_id = woh.workorder_id 
				and source_company_id = woh.company_id
				and source_profit_ctr_id = woh.profit_ctr_id
				ORDER BY isnull(link_required_flag, 'Z')
				)
			, 'F')
			),
			/*
			case when exists (
				select 1 from billinglinklookup (nolock)
				where source_id = woh.workorder_id 
				and source_company_id = woh.company_id
				and source_profit_ctr_id = woh.profit_ctr_id
				and link_required_flag = 'E'
				) then 'E' 
				else 
					case when exists (
						select 1 from billinglinklookup (nolock)
						where source_id = woh.workorder_id 
						and source_company_id = woh.company_id
						and source_profit_ctr_id = woh.profit_ctr_id
						and link_required_flag <> 'E'
					) then 'T' else 'F' 
					end 
				end AS link_flag,
			*/
			null as linked_record, -- Wo's don't list these.  R's do.
			CASE woh.workorder_status
				WHEN 'A' THEN 'Accepted'
				WHEN 'C' THEN 'Completed'
				WHEN 'N' THEN 'New'
			END as status_description,
			woh.end_date AS trans_date,
			COALESCE(wos.date_act_arrive, woh.start_date) as pickup_date,
			woh.submitted_flag,
			woh.date_submitted,
			woh.submitted_by,
			CustomerBilling.territory_code,
			CustomerBilling.billing_project_id,
			CustomerBilling.project_name,
			Customer.customer_id,
			Customer.cust_name,
			Customer.customer_type,
			Customer.cust_category,
			wod.sequence_id AS line_id,
			
			--1 AS price_id,
			price_id = ROW_NUMBER() 
				OVER(PARTITION BY woh.company_id,
					woh.profit_ctr_id,
					woh.workorder_id,
					wod.resource_type,
					wod.billing_sequence_id
				ORDER BY woh.company_id,
					woh.profit_ctr_id,
					woh.workorder_id,
					wod.resource_type,
					wod.billing_sequence_id),
					
			wod.sequence_id,
			wod.resource_class_code,
			wod.resource_type,
			NULL AS Workorder_resource_category,
			wodu.quantity,
			'N' as dist_flag,		
			woh.company_id, -- BillingDetail.dist_company_id,
			woh.profit_ctr_id, -- BillingDetail.dist_profit_ctr_id,
			--COALESCE(rc.gl_account_code, 
			--	wort.gl_seg_1 + RIGHT('00' + CONVERT(VARCHAR(2),woh.company_id), 2) 
			--	+ RIGHT('00' + CONVERT(VARCHAR(2),woh.profit_ctr_ID), 2) + woth.gl_seg_4),
			gl_account_code = null, -- dbo.fn_get_workorder_glaccount(woh.company_id, woh.profit_ctr_id, woh.workorder_id, wod.resource_type, wod.sequence_id),
--rb			SUM(dbo.fn_workorder_line_price (woh.company_id, woh.profit_ctr_id, woh.workorder_id, wod.resource_type, wod.bill_unit_code, wod.sequence_id)) as extended_amt,
			SUM(isnull(dbo.fn_workorder_line_price (woh.company_id, woh.profit_ctr_id, woh.workorder_id, wod.resource_type, wodu.bill_unit_code, wod.sequence_id),0)) as extended_amt,
			Generator.generator_id,
			Generator.generator_name,
			Generator.epa_id,
			wodu.bill_unit_code,
			woh.quote_ID,
			TSDF.TSDF_code,
			TSDF.EQ_FLAG AS TSDF_EQ_FLAG,
			woh.fixed_price_flag,
			'C' AS pricing_method,
			tsdfa.waste_desc,
			CASE WHEN ISNULL(wodu.quantity, 0) <> 0 THEN 'T' ELSE 'F' END AS quantity_flag,
			'WorkOrder' as billing_type,	
			JDE_BU = null, -- dbo.fn_get_workorder_JDE_glaccount_business_unit (woh.company_id, woh.profit_ctr_id, woh.workorder_id, wod.resource_type, wod.sequence_id),
			JDE_object = null, -- dbo.fn_get_workorder_JDE_glaccount_object (woh.company_id, woh.profit_ctr_id, woh.workorder_id, wod.resource_type, wod.sequence_id),
		 	AX_MainAccount = dbo.fn_get_workorder_AX_main_account(woh.workorder_type_id,woh.company_id, woh.profit_ctr_id,'O', woh.workorder_ID),
			AX_Dimension_1 = ProfitCenter.AX_Dimension_1,
			--AX_Dimension_2 = case when ProfitCenter.wo_bu_configuration_flag = 'T' 
			--					then COALESCE(NULLIF(WorkOrderTypeDetail.AX_Dimension_2, ''), WorkOrderTypeDetail.AX_Dimension_2) 
			--				  else ProfitCenter.AX_Dimension_2 end ,
		    AX_Dimension_2 = case when ProfitCenter.wo_bu_configuration_flag = 'T' then 
                          COALESCE( case when WorkOrderTypedetail.AX_Dimension_2 =  '' then ProfitCenter.AX_Dimension_2 
                                    else   WorkOrderTypedetail.AX_Dimension_2 end, WorkOrderTypedetail.AX_Dimension_2) 
                            else ProfitCenter.AX_Dimension_2 end,	
			AX_Dimension_3 = WorkOrderTypeDetail.AX_Dimension_3,
			AX_Dimension_4 = dbo.fn_get_workorder_AX_dim4_LOB(woh.company_id, woh.profit_ctr_id,woh.workorder_id),

			/*  JPB
				Paul K says on 4/5/2023...
				"if not in billing just pull from WorkOrderHeader.AX_Dimension_5_Part_1 and WorkOrderHeader.AX_Dimension_5_Part_2"

				old:
				AX_Dimension_5_part_1 = dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id),
				AX_Dimension_5_part_2 = 'calcdim5',
			*/
			AX_Dimension_5_part_1 = isnull(woh.AX_Dimension_5_part_1, ''),
			AX_Dimension_5_part_2 = isnull(woh.AX_Dimension_5_part_2, ''),

			AX_Dimension_6 = WorkOrderTypeDetail.AX_Dimension_6, --NULLIF(WorkOrderTypeDetail.AX_Dimension_6,' '),
			woh.reference_code,
			ISNULL(REPLACE(woh.purchase_order,'''', ''),'') AS purchase_order,
			ISNULL(REPLACE(woh.release_code,'''', ''),'') AS release_code,
			woh.ticket_number
			, woh.start_date
		FROM WorkOrderHeader woh (nolock)
--rb
--		INNER JOIN #tmp_source ts
--			ON 'W' = ts.trans_source
		join @customer Customer on woh.customer_id = Customer.customer_id
		JOIN ProfitCenter ON ProfitCenter.profit_ctr_id = woh.profit_ctr_id
			AND ProfitCenter.company_id = woh.company_id
		INNER JOIN WorkOrderDetail wod (nolock)
			ON woh.workorder_id = wod.workorder_id
			AND woh.company_id = wod.company_id
			AND woh.profit_ctr_id = wod.profit_ctr_id
			AND wod.resource_type = 'D'
			AND NOT EXISTS (
				SELECT 1
				FROM WorkorderQuoteHeader (nolock)
				WHERE project_code = woh.project_code
				AND quote_type = 'P'
				AND company_id = woh.company_id
				AND fixed_price_flag = 'T'
			)
			AND wod.bill_rate > 0
--rb 04/06/2015 Uncommented
		INNER JOIN #tmp_trans_copc copc
			ON woh.company_id = copc.company_id
			AND woh.profit_ctr_id = copc.profit_ctr_id
			
		LEFT JOIN WorkOrderDetailUnit wodu (nolock)
			ON wod.workorder_id = wodu.workorder_id
			AND wod.company_id = wodu.company_id
			AND wod.profit_ctr_id = wodu.profit_ctr_id
			AND wod.sequence_id = wodu.sequence_id
			and wodu.billing_flag = 'T'
		--inner join WorkorderResourceType wort (nolock)
		--	ON wort.resource_type = wod.resource_type
		INNER JOIN WorkOrderTypeHeader woth (nolock)
			ON woth.workorder_type_id = woh.workorder_type_id	
	   LEFT OUTER JOIN CustomerBilling (nolock)
			ON woh.customer_id = CustomerBilling.customer_id
			AND ISNULL(woh.billing_project_id, 0) = CustomerBilling.billing_project_id
		LEFT OUTER JOIN Generator (nolock)
			ON woh.generator_id = Generator.generator_id
		LEFT OUTER JOIN TSDF (nolock)
			ON wod.tsdf_code = TSDF.tsdf_code
		LEFT JOIN WorkorderStop wos (nolock)
			ON woh.workorder_id = wos.workorder_id
			and wos.stop_sequence_id = 1
			and woh.company_id = wos.company_id
			and woh.profit_ctr_id = wos.profit_ctr_id
		--LEFT OUTER JOIN ResourceClass rc (nolock)
		--	ON wod.resource_class_code = rc.resource_class_code
		--	AND wod.resource_type = rc.resource_type
		--	AND wod.company_id = rc.company_id
		--	AND wod.profit_ctr_id = rc.profit_ctr_id
		--	and wod.bill_unit_code = rc.bill_unit_code
		LEFT OUTER JOIN TSDFApproval tsdfa (nolock)
			ON wod.tsdf_approval_id = tsdfa.tsdf_approval_id
	--rb 04/10/2015
		LEFT OUTER JOIN ( SELECT DISTINCT 
								  workorder_type_id
								  , company_id
								  , profit_ctr_id
								  , customer_id
								  , AX_MainAccount_Part_1 AS AX_MainAccount_Part_1
								  , AX_Dimension_3 AS AX_Dimension_3
								  , AX_Dimension_4_Base AS AX_Dimension_4_Base
								  , AX_Dimension_4_Event AS AX_Dimension_4_Event
								  , AX_Dimension_5_Part_1 AS AX_Dimension_5_Part_1
								  , AX_Dimension_5_Part_2 AS AX_Dimension_5_Part_2
								  , AX_Dimension_6 AS AX_Dimension_6
								  , AX_Project_Required_Flag
								  , AX_Dimension_2
						   FROM WorkOrderTypeDetail
						   WHERE 1=1
			  ) WorkOrderTypeDetail ON WorkOrderTypeDetail.workorder_type_id = woh.workorder_type_id 
					 AND WorkOrderTypeDetail.company_id = woh.company_id
					 AND WorkOrderTypeDetail.profit_ctr_id = woh.profit_ctr_id
					 AND (WorkOrderTypeDetail.customer_id IS NULL OR woh.customer_id = WorkOrderTypeDetail.customer_id )

		WHERE 1=1
			AND (woh.submitted_flag = 'F' 
			/* OR (woh.submitted_flag = 'T' and not exists (select 1 from billing where receipt_id = woh.workorder_id and company_id = woh.company_id and profit_ctr_id = woh.profit_ctr_id and trans_source = 'W' and status_code = 'I')) */
			)
			AND isnull(woh.fixed_price_flag, 'F') = 'F'
			-- AND coalesce(wos.date_act_arrive, woh.start_date) BETWEEN @date_from AND @date_to -- ??? start_date or end_date?
			AND isnull(woh.start_date, @date_from + 0.0001) BETWEEN @date_from AND @date_to -- ??? start_date or end_date?
			-- AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND woh.workorder_status NOT IN ('V','X','T')
--rb 04/08/2015			AND @invoice_flag IN ('N', 'S', 'U')
--rb 04/06/2015		and 1 = case when exists (select 1 from #tmp_trans_copc where company_id = woh.company_id and profit_ctr_id = woh.profit_ctr_id) then 1 else 0 end
	GROUP BY
			woh.company_id,
			woh.profit_ctr_id,
			woh.workorder_id,
			woth.account_desc,
			woh.workorder_status,
			CASE woh.workorder_status
				WHEN 'A' THEN 'Accepted'
				WHEN 'C' THEN 'Completed'
				WHEN 'N' THEN 'New'
			END,
			woh.end_date,
			COALESCE(wos.date_act_arrive, woh.start_date),
			woh.submitted_flag,
			woh.date_submitted,
			woh.submitted_by,
			CustomerBilling.territory_code,
			CustomerBilling.billing_project_id,
			CustomerBilling.project_name,
			Customer.customer_id,
			Customer.cust_name,
			Customer.customer_type,
			Customer.cust_category,
			wod.sequence_id,
			wod.resource_class_code,
			wod.resource_type,
			wodu.quantity,
			wod.bill_rate,
			--rc.gl_account_code, 
			--wort.gl_seg_1,
			woh.company_id, 
			woh.profit_ctr_ID,
			--woth.gl_seg_4,
			Generator.generator_id,
			Generator.generator_name,
			Generator.epa_id,
			wodu.bill_unit_code,
			woh.quote_ID,
			TSDF.TSDF_code,
			TSDF.EQ_FLAG,
			woh.fixed_price_flag,
			tsdfa.waste_desc,
			CASE WHEN ISNULL(wodu.quantity, 0) <> 0 THEN 'T' ELSE 'F' END,
			wod.billing_sequence_id,
			woh.workorder_type_id,
			ProfitCenter.AX_Dimension_1,
			ProfitCenter.wo_bu_configuration_flag,
			WorkOrderTypeDetail.AX_Dimension_2,
			ProfitCenter.AX_Dimension_2,
			WorkOrderTypeDetail.AX_Dimension_3,
			woh.AX_Dimension_5_part_1,
			woh.AX_Dimension_5_part_2,
			WorkOrderTypeDetail.AX_Dimension_6,
			woh.reference_code,
			ISNULL(REPLACE(woh.purchase_order,'''', ''),''),
			ISNULL(REPLACE(woh.release_code,'''', ''),''),
			woh.ticket_number
			, woh.start_date
	
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "Not In Billing, Workorder (Disposal), Not Fixed price, Not Priced" Population' as status
	set @lasttime = getdate()


	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting AX Dim 5 Update' as status
	set @lasttime = getdate()

/*
On 4/5/2023 per PaulK, no longer using this logic -just pulling part1/part2 values from WorkorderHeader.

		update #InternalFlashWork set
			AX_Dimension_5_part_2 = isnull(
				case when AX_Dimension_5_part_1 like '%.%'
				then
					substring(AX_Dimension_5_part_1, 
					charindex('.',AX_Dimension_5_part_1)+1,
					len(AX_Dimension_5_part_1))
				else null
				end, ''),
			AX_Dimension_5_part_1 = isnull(
				case when AX_Dimension_5_part_1 <> '' 
				then 
					substring(AX_Dimension_5_part_1, 1, charindex('.',AX_Dimension_5_part_1+'.')-1 ) 
				end, '')
		WHERE AX_Dimension_5_part_2 = 'calcdim5'

		And before that...			
			was...
				AX_Dimension_5_part_1 = ISNull( case when dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id) <> '' 
                    then substring(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id), 1, 
                    case when charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id))=0
                    then len(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id)) 
                    else charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id))-1 
                    end) end  , '' ),
                   --  else 'X' end,
                   
				AX_Dimension_5_part_2 = ISNULL ( case when charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id)) = 0
				    then null 
					else substring(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id), 
					charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id))+1,
					len(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id)))end, '' ),
					
*/


	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Done with AX Dim 5 Update' as status
	set @lasttime = getdate()
		
	
--#endregion	


--#region fixed price wo
	/*

	If not in billing
					If Workorder
								If fixed price JUST USE PRICE ON HEADER

	*/

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "Not In Billing, Workorder, Fixed price" Population' as status
	set @lasttime = getdate()
	
	IF exists (select 1 from #tmp_source where trans_source = 'W')
	--rb 04/08/2015 Originally had "AND @invoice_flag IN ('N', 'S', 'U')" in the where clause, which the optimizer ignored before starting work (most likely the subselect in where clause)
		AND @invoice_flag IN ('N', 'U') -- Non-Billing source, and submitted_flag = 'F' below, so this is Not invoiced or Unsubmitted

		INSERT #InternalFlashWork (
			company_id					,
			profit_ctr_id				,
			trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
			receipt_id					, -- Receipt/Workorder ID
			trans_type					,
			workorder_type				, -- WorkOrderType.account_desc
			trans_status				, -- Receipt or Workorder Status
			link_flag,
			linked_record,
			status_description			, -- Billing/Transaction status description
			trans_date					, -- Receipt Date or Workorder End Date
			pickup_date					, -- Pickup Date
			submitted_flag				, -- Submitted Flag
			date_submitted				, -- Submitted Date
			submitted_by				, -- Submitted by
			territory_code				, -- Billing Project Territory code
			billing_project_id			, -- Billing project ID
			billing_project_name		, -- Billing Project Name
			customer_id					, -- Customer ID on Receipt/Workorder
			cust_name					, -- Customer Name
			customer_type				, -- Customer Type
			cust_category				, -- Customer Category
			line_id						,
			price_id					,
			workorder_sequence_id		, -- Workorder sequence id
			-- workorder_resource_item		, -- Workorder Resource Item
			workorder_resource_type		, -- Workorder Resource Type
			Workorder_resource_category , -- Workorder Resource Category
			quantity					, -- Receipt/Workorder Quantity
			dist_flag,
			dist_company_id				, -- Distribution Company ID (which company receives the revenue)
			dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
			gl_account_code				, -- GL Account for the revenue
			extended_amt				, -- Revenue amt
			generator_id				, -- Generator ID
			generator_name				, -- Generator Name
			epa_id						, -- Generator EPA ID
			bill_unit_code				, -- Unit
			quote_id					, -- Quote ID
			TSDF_code					, -- TSDF Code
			TSDF_EQ_FLAG				, -- TSDF: Is this an EQ tsdf?
			fixed_price_flag			, -- Fixed Price Flag
			pricing_method				, -- Calculated, Actual, etc.
			quantity_flag,					-- T = has quantities, F = no quantities, so 0 used.
			billing_type				,
			JDE_BU						,
			JDE_object					,
			AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
			AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
			AX_Dimension_2				,	-- AX_business_unit
			AX_Dimension_3				,	-- AX_department
			AX_Dimension_4				,	-- AX_line_of_business
			AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
			AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
			AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
			reference_code,
			purchase_order				,
			release_code				,	
			ticket_number					-- WorkOrderHeader.ticket_number
			,workorder_startdate		
		)
		SELECT
			woh.company_id,
			woh.profit_ctr_id,
			'W',
			woh.workorder_id,
			'O' AS trans_type,
			woth.account_desc,
			woh.workorder_status AS trans_status,
			link_flag = (
			select
			isnull(
				(
				select top 1 case link_required_flag when 'E' then 'E' else 'T' end
				from billinglinklookup (nolock)
				where source_id = woh.workorder_id
				and source_company_id = woh.company_id
				and source_profit_ctr_id = woh.profit_ctr_id
				ORDER BY isnull(link_required_flag, 'Z')
				)
			, 'F')
			),
			/*
			case when exists (
				select 1 from billinglinklookup (nolock)
				where source_id = woh.workorder_id 
				and source_company_id = woh.company_id
				and source_profit_ctr_id = woh.profit_ctr_id
				and link_required_flag = 'E'
				) then 'E' 
				else 
					case when exists (
						select 1 from billinglinklookup (nolock)
						where source_id = woh.workorder_id 
						and source_company_id = woh.company_id
						and source_profit_ctr_id = woh.profit_ctr_id
						and link_required_flag <> 'E'
					) then 'T' else 'F' 
					end 
				end AS link_flag,
			*/
			null as linked_record, -- Wo's don't list these.  R's do.
			CASE woh.workorder_status
				WHEN 'A' THEN 'Accepted'
				WHEN 'C' THEN 'Completed'
				WHEN 'N' THEN 'New'
			END as status_description,
			woh.end_date AS trans_date,
			COALESCE(wos.date_act_arrive, woh.start_date) as pickup_date,
			woh.submitted_flag,
			woh.date_submitted,
			woh.submitted_by,
			CustomerBilling.territory_code,
			CustomerBilling.billing_project_id,
			CustomerBilling.project_name,
			Customer.customer_id,
			Customer.cust_name,
			Customer.customer_type,
			Customer.cust_category,
			1 AS line_id,
			1 AS price_id,
			1 AS workorder_sequence_id,
			-- wod.workorder_resource_item,
			NULL AS workorder_resource_type,
			NULL AS Workorder_resource_category,
			NULL AS quantity, --wod.quantity_used,
			'N' as dist_flag,
			woh.company_id as dist_company_id,
			woh.profit_ctr_id as dist_profit_ctr_id,
			--gl.account_code, --varchar(12)
			--wort.gl_seg_1 + RIGHT('00' + CONVERT(VARCHAR(2),woh.company_id),2 ) + RIGHT('00' + CONVERT(VARCHAR(2),woh.profit_ctr_ID), 2) + woth.gl_seg_4,
			gl_account_code = null, -- dbo.fn_get_workorder_glaccount(woh.company_id, woh.profit_ctr_id, woh.workorder_id, 'O', 0),
			woh.total_price,
			Generator.generator_id,
			Generator.generator_name,
			Generator.epa_id,
			NULL as bill_unit_code,
			woh.quote_ID,
			NULL as TSDF_code,
			NULL as TSDF_EQ_FLAG,
			woh.fixed_price_flag,
			'A' AS pricing_method,
			NULL as quantity_flag, -- CASE WHEN isnull(wod.quantity_used, 0) <> 0 THEN 'T' ELSE 'F' END AS quantity_flag,
			'WorkOrder' as billing_type,	
			JDE_BU = null, -- dbo.fn_get_workorder_JDE_glaccount_business_unit (woh.company_id, woh.profit_ctr_id, woh.workorder_id, 'O', 0),
			JDE_object = null, -- dbo.fn_get_workorder_JDE_glaccount_object (woh.company_id, woh.profit_ctr_id, woh.workorder_id, 'O', 0),
		 	AX_MainAccount = dbo.fn_get_workorder_AX_main_account(woh.workorder_type_id,woh.company_id, woh.profit_ctr_id,'O', woh.workorder_ID),
			AX_Dimension_1 = ProfitCenter.AX_Dimension_1,
			--AX_Dimension_2 = case when ProfitCenter.wo_bu_configuration_flag = 'T' 
			--					then COALESCE(NULLIF(WorkOrderTypeDetail.AX_Dimension_2, ''), WorkOrderTypeDetail.AX_Dimension_2) 
			--				  else ProfitCenter.AX_Dimension_2 end ,
		    AX_Dimension_2 = case when ProfitCenter.wo_bu_configuration_flag = 'T' then 
                          COALESCE( case when WorkOrderTypedetail.AX_Dimension_2 =  '' then ProfitCenter.AX_Dimension_2 
                                    else   WorkOrderTypedetail.AX_Dimension_2 end, WorkOrderTypedetail.AX_Dimension_2) 
                            else ProfitCenter.AX_Dimension_2 end,	
			AX_Dimension_3 = WorkOrderTypeDetail.AX_Dimension_3,
			AX_Dimension_4 = dbo.fn_get_workorder_AX_dim4_LOB(woh.company_id, woh.profit_ctr_id,woh.workorder_id),

			/*  JPB
				Paul K says on 4/5/2023...
				"if not in billing just pull from WorkOrderHeader.AX_Dimension_5_Part_1 and WorkOrderHeader.AX_Dimension_5_Part_2"

				old:
				AX_Dimension_5_part_1 = dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id),
				AX_Dimension_5_part_2 = 'calcdim5',
			*/
			AX_Dimension_5_part_1 = isnull(woh.AX_Dimension_5_part_1, ''),
			AX_Dimension_5_part_2 = isnull(woh.AX_Dimension_5_part_2, ''),
			AX_Dimension_6 = WorkOrderTypeDetail.AX_Dimension_6, --NULLIF(WorkOrderTypeDetail.AX_Dimension_6,' '),
			woh.reference_code,
			ISNULL(REPLACE(woh.purchase_order,'''', ''),'') AS purchase_order,
			ISNULL(REPLACE(woh.release_code,'''', ''),'') AS release_code,
			woh.ticket_number
			, woh.start_date

-- declare @customer table (customer_id int);insert @customer values (609719);declare @date_from datetime = '10/1/2022', @date_to datetime = '3/31/2023'; select * 
		FROM WorkOrderHeader woh (nolock)
--rb
--		INNER JOIN #tmp_source ts
--			ON 'W' = ts.trans_source

		join @customer Customer on woh.customer_id = Customer.customer_id

--rb 04/06/2015 Uncommented		
		JOIN ProfitCenter ON ProfitCenter.profit_ctr_id = woh.profit_ctr_id
			AND ProfitCenter.company_id = woh.company_id
		INNER JOIN #tmp_trans_copc copc
			ON woh.company_id = copc.company_id
			AND woh.profit_ctr_id = copc.profit_ctr_id
			
		INNER JOIN WorkOrderTypeHeader woth (nolock)
			ON woth.workorder_type_id = woh.workorder_type_id	
		--inner join WorkorderResourceType wort (nolock)
		--	ON wort.resource_type = 'O'
		LEFT OUTER JOIN CustomerBilling (nolock)
			ON woh.customer_id = CustomerBilling.customer_id
			AND ISNULL(woh.billing_project_id, 0) = CustomerBilling.billing_project_id
		LEFT OUTER JOIN Generator (nolock)
			ON woh.generator_id = Generator.generator_id
		LEFT JOIN WorkorderStop wos (nolock)
			ON woh.workorder_id = wos.workorder_id
			and wos.stop_sequence_id = 1
			and woh.company_id = wos.company_id
			and woh.profit_ctr_id = wos.profit_ctr_id
		LEFT OUTER JOIN ( SELECT DISTINCT 
								  workorder_type_id
								  , company_id
								  , profit_ctr_id
								  , customer_id
								  , AX_MainAccount_Part_1 AS AX_MainAccount_Part_1
								  , AX_Dimension_3 AS AX_Dimension_3
								  , AX_Dimension_4_Base AS AX_Dimension_4_Base
								  , AX_Dimension_4_Event AS AX_Dimension_4_Event
								  , AX_Dimension_5_Part_1 AS AX_Dimension_5_Part_1
								  , AX_Dimension_5_Part_2 AS AX_Dimension_5_Part_2
								  , AX_Dimension_6 AS AX_Dimension_6
								  , AX_Project_Required_Flag
								  , AX_Dimension_2
						   FROM WorkOrderTypeDetail
						   WHERE 1=1
			  ) WorkOrderTypeDetail ON WorkOrderTypeDetail.workorder_type_id = woh.workorder_type_id 
					 AND WorkOrderTypeDetail.company_id = woh.company_id
					 AND WorkOrderTypeDetail.profit_ctr_id = woh.profit_ctr_id
					 AND (WorkOrderTypeDetail.customer_id IS NULL OR woh.customer_id = WorkOrderTypeDetail.customer_id )

		WHERE 1=1
			AND (woh.submitted_flag = 'F' 
			/* OR (woh.submitted_flag = 'T' and not exists (select 1 from billing where receipt_id = woh.workorder_id and company_id = woh.company_id and profit_ctr_id = woh.profit_ctr_id and trans_source = 'W' and status_code = 'I')) */
			)
			AND isnull(woh.fixed_price_flag, 'F') = 'T'
			-- AND coalesce(wos.date_act_arrive, woh.start_date) BETWEEN @date_from AND @date_to -- ??? start_date or end_date?
			AND isnull(woh.start_date, @date_from + 0.0001) BETWEEN @date_from AND @date_to -- ??? start_date or end_date?
			-- AND woh.customer_id BETWEEN @cust_id_from AND @cust_id_to
			AND woh.workorder_status NOT IN ('V','X','T')
--rb 04/08/2015			AND @invoice_flag IN ('N', 'S', 'U')
--rb 04/06/2015		and 1 = case when exists (select 1 from #tmp_trans_copc where company_id = woh.company_id and profit_ctr_id = woh.profit_ctr_id) then 1 else 0 end
	
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "Not In Billing, Workorder, Fixed price" Population' as status
	set @lasttime = getdate()

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting AX Dim 5 Update' as status
	set @lasttime = getdate()

/*
On 4/5/2023 per PaulK, no longer using this logic -just pulling part1/part2 values from WorkorderHeader.

		update #InternalFlashWork set
			AX_Dimension_5_part_2 = isnull(
				case when AX_Dimension_5_part_1 like '%.%'
				then
					substring(AX_Dimension_5_part_1, 
					charindex('.',AX_Dimension_5_part_1)+1,
					len(AX_Dimension_5_part_1))
				else null
				end, ''),
			AX_Dimension_5_part_1 = isnull(
				case when AX_Dimension_5_part_1 <> '' 
				then 
					substring(AX_Dimension_5_part_1, 1, charindex('.',AX_Dimension_5_part_1+'.')-1 ) 
				end, '')
		WHERE AX_Dimension_5_part_2 = 'calcdim5'
		
		And before that...	
			was...
				AX_Dimension_5_part_1 = ISNull( case when dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id) <> '' 
                    then substring(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id), 1, 
                    case when charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id))=0
                    then len(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id)) 
                    else charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id))-1 
                    end) end  , '' ),
                   --  else 'X' end,
                   
				AX_Dimension_5_part_2 = ISNULL ( case when charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id)) = 0
				    then null 
					else substring(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id), 
					charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id))+1,
					len(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id)))end, '' ),
					
*/


	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Done with AX Dim 5 Update' as status
	set @lasttime = getdate()
	
	
--#endregion	


--#region wo-faux-billing
--JDB - populate #Billing from FlashWork for work orders
	-- Populate
	IF exists (select 1 from #tmp_source where trans_source = 'W')
		AND @invoice_flag IN ('N', 'U') -- Non-Billing source, and submitted_flag = 'F' below, so this is Not invoiced or Unsubmitted
	INSERT #Billing (
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
			bundled_tran_bill_qty_flag	,
			bundled_tran_price		,
			bundled_tran_extended_amt	,
			--bundled_tran_gl_account_code	,
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
		fw.company_id,
		fw.profit_ctr_id,
		'W' AS trans_source,
		fw.receipt_id,
		workorder_sequence_id AS line_id,
		1 AS price_id,
		fw.trans_status,
		WorkOrderHeader.start_date AS billing_date,
		fw.customer_id,
		fw.waste_code,
		fw.bill_unit_code,
		'' AS vehicle_code,
		fw.generator_id,
		fw.generator_name,
		'' AS approval_code,
		WorkorderHeader.start_date AS time_in,
		WorkorderHeader.end_date AS time_out,
		4 AS tender_type,
		'' AS tender_comment,
		fw.quantity,
		0 AS price,
		0 AS add_charge_amt,
		fw.extended_amt,
		0 AS discount_percent,
		-- fw.gl_account_code,
		-- '' AS gl_sr_account_code,
		NULL AS gl_account_type,		-- no longer used
		'' AS sr_type,
		'E' AS sr_type_code,
		0 AS sr_price,
		fw.extended_amt AS waste_extended_amt,
		0 AS sr_extended_amt,
		fw.extended_amt AS total_extended_amt,
		0 AS cash_received,
		NULL AS manifest,
		NULL AS shipper,
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
		fw.workorder_resource_item,
		'' AS workorder_invoice_break_value,
		fw.workorder_resource_type,
		fw.workorder_sequence_id,
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
		GETDATE() AS date_added,
		GETDATE() AS date_modified,
		'SA' AS added_by,
		'SA' AS modified_by,
		fw.trans_type,
		0 AS ref_line_id,
			approval_desc AS service_desc_1,
		'' AS service_desc_2,
		0 AS cost,
		NULL AS secondary_manifest,
		0 AS insr_percent,
		0 AS insr_extended_amt,
		0 AS ensr_percent,
		0 AS ensr_extended_amt,
		NULL AS bundled_tran_bill_qty_flag,
		NULL AS bundled_tran_price,
		NULL AS bundled_tran_extended_amt,
		-- NULL AS bundled_tran_gl_account_code,
		NULL AS product_id,
		ISNULL(fw.billing_project_id,0),
		WorkorderHeader.po_sequence_id,
		'F' AS invoice_preview_flag,
		'F' AS COD_sent_flag,
		'F' AS COR_sent_flag,
		'F' AS invoice_hold_flag,
		fw.profile_id,
		'' AS reference_code,
		NULL AS tsdf_approval_id,
		WorkorderHeader.billing_link_id,
		NULL AS hold_reason,
		NULL AS hold_userid,
		NULL AS hold_date,
		NULL,
		NULL,
		NULL,
		NULL AS date_delivered,
		0,
		0,
		NULL AS quote_sequence_id,
		0 AS count_bundled,
		fw.waste_code_uid,
		WorkOrderHeader.currency_code
	FROM
		#InternalFlashWork fw
		JOIN WorkOrderHeader
			ON WorkOrderHeader.company_id = fw.company_id
			AND WorkOrderHeader.profit_ctr_id = fw.profit_ctr_id
			AND WorkOrderHeader.workorder_id = fw.receipt_id
	WHERE 1=1 
		--rb 04/10/2015 make use of new index
		AND fw.trans_source = 'W'
		
		AND ISNULL(WorkOrderHeader.submitted_flag, 'F') = 'F'
		AND NOT EXISTS (SELECT 1 FROM Billing (nolock) 
			WHERE fw.company_id = Billing.company_id
			AND fw.profit_ctr_id = Billing.profit_ctr_id
			AND fw.receipt_id = Billing.receipt_id
			AND Billing.trans_source = 'W')

--#endregion
			
--#region wo-faux-billingdetail
	IF exists (select 1 from #tmp_source where trans_source = 'W')
	INSERT #BillingDetail
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
		b.total_extended_amt AS extended_amt,
		/*
		CASE b.workorder_resource_type 
			WHEN 'H' 
				-- Fixed price:
				THEN null -- dbo.fn_get_workorder_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, 'O', 0)
			ELSE 
				-- Not fixed price:
				null -- dbo.fn_get_workorder_glaccount(b.company_id, b.profit_ctr_id, b.receipt_id, b.workorder_resource_type, b.workorder_sequence_id)
			END 
		*/
		NULL AS gl_account_code,
		NULL AS sequence_id,
		JDE_BU = null, -- dbo.fn_get_workorder_JDE_glaccount_business_unit (b.company_id, b.profit_ctr_id, b.receipt_id, b.workorder_resource_type, b.workorder_sequence_id),
		JDE_object = null, -- dbo.fn_get_workorder_JDE_glaccount_object (b.company_id, b.profit_ctr_id, b.receipt_id, b.workorder_resource_type, b.workorder_sequence_id),
		 	AX_MainAccount = dbo.fn_get_workorder_AX_main_account(woh.workorder_type_id,woh.company_id, woh.profit_ctr_id,'O', woh.workorder_ID),
			AX_Dimension_1 = ProfitCenter.AX_Dimension_1,
			--AX_Dimension_2 = case when ProfitCenter.wo_bu_configuration_flag = 'T' 
			--					then COALESCE(NULLIF(WorkOrderTypeDetail.AX_Dimension_2, ''), WorkOrderTypeDetail.AX_Dimension_2) 
			--				  else ProfitCenter.AX_Dimension_2 end ,
		    AX_Dimension_2 = case when ProfitCenter.wo_bu_configuration_flag = 'T' then 
                          COALESCE( case when WorkOrderTypedetail.AX_Dimension_2 =  '' then ProfitCenter.AX_Dimension_2 
                                    else   WorkOrderTypedetail.AX_Dimension_2 end, WorkOrderTypedetail.AX_Dimension_2) 
                            else ProfitCenter.AX_Dimension_2 end,	
			AX_Dimension_3 = WorkOrderTypeDetail.AX_Dimension_3,
			AX_Dimension_4 = dbo.fn_get_workorder_AX_dim4_LOB(woh.company_id, woh.profit_ctr_id,woh.workorder_id),
			/*  JPB
				Paul K says on 4/5/2023...
				"if not in billing just pull from WorkOrderHeader.AX_Dimension_5_Part_1 and WorkOrderHeader.AX_Dimension_5_Part_2"

				old:
				AX_Dimension_5_part_1 = dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id),
				AX_Dimension_5_part_2 = 'calcdim5',
			*/
			AX_Dimension_5_part_1 = isnull(woh.AX_Dimension_5_part_1, ''),
			AX_Dimension_5_part_2 = isnull(woh.AX_Dimension_5_part_2, ''),

			AX_Dimension_6 = WorkOrderTypeDetail.AX_Dimension_6, --NULLIF(WorkOrderTypeDetail.AX_Dimension_6,' '),
		NULL as AX_Project_Required_Flag,
		NULL as disc_amount,
		b.currency_code
	FROM #Billing b
	JOIN BillingType bt ON bt.billing_type = 'WorkOrder'
		JOIN ProfitCenter ON ProfitCenter.profit_ctr_id = b.profit_ctr_id
			AND ProfitCenter.company_id = b.company_id
		JOIN WorkOrderHeader woh
			ON woh.company_id = b.company_id
			AND woh.profit_ctr_id = b.profit_ctr_id
			AND woh.workorder_id = b.receipt_id
		INNER JOIN WorkOrderTypeHeader woth (nolock)
			ON woth.workorder_type_id = woh.workorder_type_id	
		LEFT OUTER JOIN ( SELECT DISTINCT 
								  workorder_type_id
								  , company_id
								  , profit_ctr_id
								  , customer_id
								  , AX_MainAccount_Part_1 AS AX_MainAccount_Part_1
								  , AX_Dimension_3 AS AX_Dimension_3
								  , AX_Dimension_4_Base AS AX_Dimension_4_Base
								  , AX_Dimension_4_Event AS AX_Dimension_4_Event
								  , AX_Dimension_5_Part_1 AS AX_Dimension_5_Part_1
								  , AX_Dimension_5_Part_2 AS AX_Dimension_5_Part_2
								  , AX_Dimension_6 AS AX_Dimension_6
								  , AX_Project_Required_Flag
								  , AX_Dimension_2
						   FROM WorkOrderTypeDetail
						   WHERE 1=1
			  ) WorkOrderTypeDetail ON WorkOrderTypeDetail.workorder_type_id = woh.workorder_type_id 
					 AND WorkOrderTypeDetail.company_id = woh.company_id
					 AND WorkOrderTypeDetail.profit_ctr_id = woh.profit_ctr_id
					 AND (WorkOrderTypeDetail.customer_id IS NULL OR woh.customer_id = WorkOrderTypeDetail.customer_id )


		insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting AX Dim 5 Update' as status
		set @lasttime = getdate()

/*
On 4/5/2023 per PaulK, no longer using this logic -just pulling part1/part2 values from WorkorderHeader.

			update #BillingDetail set
				AX_Dimension_5_part_2 = isnull(
					case when AX_Dimension_5_part_1 like '%.%'
					then
						substring(AX_Dimension_5_part_1, 
						charindex('.',AX_Dimension_5_part_1)+1,
						len(AX_Dimension_5_part_1))
					else null
					end, ''),
				AX_Dimension_5_part_1 = isnull(
					case when AX_Dimension_5_part_1 <> '' 
					then 
						substring(AX_Dimension_5_part_1, 1, charindex('.',AX_Dimension_5_part_1+'.')-1 ) 
					end, '')
			WHERE AX_Dimension_5_part_2 = 'calcdim5'
			
			And before that...			
				was...
					AX_Dimension_5_part_1 = ISNull( case when dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id) <> '' 
						then substring(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id), 1, 
						case when charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id))=0
						then len(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id)) 
						else charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id))-1 
						end) end  , '' ),
					   --  else 'X' end,
	                   
					AX_Dimension_5_part_2 = ISNULL ( case when charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id)) = 0
						then null 
						else substring(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id), 
						charindex('.',dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id))+1,
						len(dbo.fn_get_workorder_AX_dim5_project (woh.company_id, woh.profit_ctr_id,woh.workorder_id)))end, '' ),
						
*/


		insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Done with AX Dim 5 Update' as status
		set @lasttime = getdate()
					
--#endregion					

	/*
	If not in Billing
					If Receipt
								Take from receipt price
								... later... Addition of product records from profile that are not optional and not exempt
								Pricing method = 'C'

	*/

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "Not In Billing, Receipt, Actual Pricing" Population' as status
	set @lasttime = getdate()
	

	
--#region receipt-not-in-billing
	IF exists (select 1 from #tmp_source where trans_source = 'R')
	--rb 04/08/2015 Originally had "AND @invoice_flag IN ('N', 'S', 'U')" in the where clause, which the optimizer ignored before starting work (most likely the subselect in where clause)
		AND @invoice_flag IN ('N', 'U') -- Non-Billing source, and submitted_flag = 'F' below, so this is Not invoiced or Unsubmitted
	BEGIN
	
	
--#region receipt copc-search-type-T
		if @copc_search_type = 'T'
		begin
			INSERT #InternalFlashWork (
				company_id					,
				profit_ctr_id				,
				trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
				receipt_id					, -- Receipt/Workorder ID
				trans_type					, -- Receipt trans type (O/I)
				link_flag					,
				linked_record				,
				workorder_type				, -- WorkOrderType.account_desc
				trans_status				, -- Receipt or Workorder Status
				status_description			, -- Billing/Transaction status description
				trans_date					, -- Receipt Date or Workorder End Date
				pickup_date					, -- Pickup Date
				submitted_flag				, -- Submitted Flag
				date_submitted				, -- Submitted Date
				submitted_by				, -- Submitted by
				billing_status_code			, -- Billing Status Code
				territory_code				, -- Billing Project Territory code
				billing_project_id			, -- Billing project ID
				billing_project_name		, -- Billing Project Name
				invoice_flag				, -- Invoiced? Flag
				invoice_code				, -- Invoice Code (if invoiced)
				invoice_date				, -- Invoice Date (if invoiced)
				invoice_month				, -- Invoice Date month
				invoice_year				, -- Invoice Date year
				customer_id					, -- Customer ID on Receipt/Workorder
				cust_name					, -- Customer Name
				customer_Type				, -- Customer Type
				cust_category				, -- Customer Category
				line_id						, -- Receipt line id
				price_id					, -- Receipt line price id
				ref_line_id					, -- Billing reference line_id (which line does this refer to?)
				workorder_sequence_id		, -- Workorder sequence id
				workorder_resource_item		, -- Workorder Resource Item
				workorder_resource_type		, -- Workorder Resource Type
				Workorder_resource_category ,
				quantity					, -- Receipt/Workorder Quantity
				billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
				dist_flag					, -- Distributed Transaction?
				dist_company_id				, -- Distribution Company ID (which company receives the revenue)
				dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
				gl_account_code				, -- GL Account for the revenue
				gl_native_code				,
				gl_dept_code				,
				extended_amt				, -- Revenue amt
				generator_id				, -- Generator ID
				generator_name				, -- Generator Name
				epa_id						, -- Generator EPA ID
				treatment_id				,	--	Treatment	ID
				treatment_desc				,	--	Treatment's	treatment_desc
				treatment_process_id		,	--	Treatment's	treatment_process_id
				treatment_process			,	--	Treatment's	treatment_process	(desc)
				disposal_service_id			,	--	Treatment's	disposal_service_id
				disposal_service_desc		,	--	Treatment's	disposal_service_desc
				wastetype_id				,	--	Treatment's	wastetype_id
				wastetype_category			,	--	Treatment's	wastetype	category
				wastetype_description		,	--	Treatment's	wastetype	description
				bill_unit_code				, -- Unit
				waste_code					, -- Waste Code
				profile_id					, -- Profile_id
				quote_id					, -- Quote ID
				product_id					,	--	BillingDetail	product_id,	for	id'ing	fees,	etc.
				product_code				,	-- Product Code
				approval_code				, -- Approval Code
				approval_desc				,
				tsdf_code					,
				tsdf_eq_flag				,
				fixed_price_flag			, -- Fixed Price Flag
				pricing_method				, -- Calculated, Actual, etc.
				quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
				JDE_BU						,
				JDE_object					,
				AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				AX_Dimension_2				,	-- AX_business_unit
				AX_Dimension_3				,	-- AX_department
				AX_Dimension_4				,	-- AX_line_of_business
				AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				waste_code_uid				,
				reference_code,
				purchase_order				,
				release_code				,	
				ticket_number					-- WorkOrderHeader.ticket_number, if there is a linked WO
				,workorder_startdate		
			)
			SELECT DISTINCT
				Receipt.company_id,
				Receipt.profit_ctr_id,
				'R' AS trans_source,
				Receipt.receipt_id,
				Receipt.trans_type,
				link_flag = (
				select
				isnull(
					(
					select top 1 case link_required_flag when 'E' then 'E' else 'T' end
					from billinglinklookup (nolock)
					where receipt_id = Receipt.receipt_id 
					and company_id = Receipt.company_id
					and profit_ctr_id = Receipt.profit_ctr_id
					ORDER BY isnull(link_required_flag, 'Z')
					)
				, 'F')
				),
				/*
				case when exists (
					select 1 from billinglinklookup (nolock)
					where receipt_id = Receipt.receipt_id 
					and company_id = Receipt.company_id
					and profit_ctr_id = Receipt.profit_ctr_id
					and link_required_flag = 'E'
					) then 'E' 
					else 
						case when exists (
							select 1 from billinglinklookup (nolock)
							where receipt_id = Receipt.receipt_id 
							and company_id = Receipt.company_id
							and profit_ctr_id = Receipt.profit_ctr_id
							and link_required_flag <> 'E'
						) then 'T' else 'F' 
						end 
					end AS link_flag,
				*/
				NULL /* rb 04/13/2015 dbo.fn_get_linked_workorders(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id)*/ as linked_record, -- Wo's don't list these.  R's do.
				NULL AS workorder_type,
				Receipt.receipt_status AS trans_status,
				CASE Receipt.receipt_status
					WHEN 'L' THEN
						CASE Receipt.fingerpr_status
							WHEN 'A' THEN 'Lab, Accepted'
							WHEN 'H' THEN 'Lab, Hold'
							WHEN 'W' THEN 'Lab, Waiting'
							ELSE 'Unknown Lab Status: ' + Receipt.fingerpr_status
						END
					WHEN 'A' THEN 'Accepted'
					WHEN 'M' THEN 'Manual'
					WHEN 'N' THEN 'New'
					WHEN 'U' THEN 
						CASE Receipt.waste_accepted_flag
							WHEN 'T' THEN 'Waste Accepted'
							ELSE 'Unloading'
						END
					ELSE NULL
				END	status_description,
				Receipt.receipt_date AS trans_date,
				pickup_date = (
					select top 1 _date from
					--coalesce(rt.transporter_sign_date, wospu.date_act_arrive, wohpu.start_date)
					(
						select rt.transporter_sign_date _date
						FROM ReceiptTransporter RT WITH(nolock) 
						WHERE  RT.receipt_id = Receipt.receipt_id 
						and RT.company_id = Receipt.company_id 
						and RT.profit_ctr_id = Receipt.profit_ctr_id
						and RT.transporter_sequence_id = 1
						union
						select coalesce(wospu.date_act_arrive, wohpu.start_date) _date
						FROM BillingLinkLookup bllpu (nolock) 
						LEFT JOIN WorkOrderHeader wohpu (nolock) 
							ON wohpu.company_id = bllpu.source_company_id
							AND wohpu.profit_ctr_id = bllpu.source_profit_ctr_id
							AND wohpu.workorder_id = bllpu.source_id					
						LEFT JOIN workorderstop wospu (nolock)
							ON wohpu.workorder_id = wospu.workorder_id
							and wospu.stop_sequence_id = 1
							and wohpu.company_id = wospu.company_id
							and wohpu.profit_ctr_id = wospu.profit_ctr_id
						WHERE  bllpu.receipt_id = Receipt.receipt_id
						and bllpu.company_id = Receipt.company_id
						and bllpu.profit_ctr_id = Receipt.profit_ctr_id
					) y
					WHERE _date is not null
					order by _date
				),
/*
				pickup_date = (
					select top 1 coalesce(rt.transporter_sign_date, wospu.date_act_arrive, wohpu.start_date)
					FROM Receipt rpu (nolock)
					LEFT OUTER JOIN ReceiptTransporter RT WITH(nolock) 
						ON RT.receipt_id = rpu.receipt_id 
						and RT.company_id = rpu.company_id 
						and RT.profit_ctr_id = rpu.profit_ctr_id
						and RT.transporter_sequence_id = 1
					LEFT OUTER JOIN BillingLinkLookup bllpu (nolock) 
						ON rpu.receipt_id = bllpu.receipt_id
						and rpu.company_id = bllpu.company_id
						and rpu.profit_ctr_id = bllpu.profit_ctr_id
					LEFT JOIN WorkOrderHeader wohpu (nolock) 
						ON wohpu.company_id = bllpu.source_company_id
						AND wohpu.profit_ctr_id = bllpu.source_profit_ctr_id
						AND wohpu.workorder_id = bllpu.source_id					
					LEFT JOIN workorderstop wospu (nolock)
						ON wohpu.workorder_id = wospu.workorder_id
						and wospu.stop_sequence_id = 1
						and wohpu.company_id = wospu.company_id
						and wohpu.profit_ctr_id = wospu.profit_ctr_id
					WHERE
						rpu.receipt_id = Receipt.receipt_id
						and rpu.company_id = Receipt.company_id
						and rpu.profit_ctr_id = Receipt.profit_ctr_id
				),
*/
				Receipt.submitted_flag,
				Receipt.date_submitted,
				Receipt.submitted_by,
				NULL as billing_status_code,
				CustomerBilling.territory_code,
				CustomerBilling.billing_project_id,
				CustomerBilling.project_name,
				'F' as invoice_flag,
				NULL as invoice_code,
				NULL as invoice_date,
				NULL as invoice_month,
				NULL as invoice_year,
				Customer.customer_id,
				Customer.cust_name,
				Customer.customer_type,
				Customer.cust_category,
				Receipt.line_id,
				ReceiptPrice.price_id,
				NULL as ref_line_id,
				NULL AS workorder_sequence_id,
				NULL AS workorder_resource_item,
				NULL AS workorder_resource_type,
				NULL AS Workorder_resource_category,
				ReceiptPrice.bill_quantity,
				case Receipt.trans_type
					WHEN 'D' then 'Disposal'
					WHEN 'S' then 'Product'
					WHEN 'W' then 'Wash'
				end AS billing_type,
				-- Modify: GEM-43800: If Product, call it Distributed?
				-- 'N', -- Not Split, since there's no billing record to split it
				case when exists ( select 1 from profilequotedetail pqd WHERE pqd.profile_id = receipt.profile_id and pqd.company_id = receipt.company_id and pqd.profit_ctr_id = receipt.profit_ctr_id and pqd.bill_method = 'B' ) then 'D' else 
					'N'
				end as dist_flag,
				receipt.company_id,
				receipt.profit_ctr_id,
				null, -- dbo.fn_get_receipt_glaccount(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id),
				null as gl_native_code,
				null as gl_dept_code,
				ReceiptPrice.total_extended_amt,
				Generator.generator_id,
				Generator.generator_name,
				Generator.epa_id,
				Receipt.treatment_id,
				Treatment.treatment_desc,
				Treatment.treatment_process_id,
				Treatment.treatment_process_process,
				Treatment.disposal_service_id,
				Treatment.disposal_service_desc,
				Treatment.wastetype_id,
				Treatment.wastetype_category,
				Treatment.wastetype_description,
				ReceiptPrice.bill_unit_code,
				Receipt.waste_code,
				Receipt.profile_id,
				pqd1.quote_id,
				Receipt.product_id,
				Receipt.product_code,
				Receipt.approval_code,
				prfl.approval_desc,
				NULL as tsdf_code,
				NULL as tsdf_eq_flag,
				NULL AS fixed_price_flag,
				'A' AS pricing_method, --CASE WHEN Billing.receipt_id is not null then 'A' ELSE null END as pricing_method,
				CASE WHEN ISNULL(ReceiptPrice.bill_quantity, 0) <> 0 THEN 'T' ELSE 'F' END AS quantity_flag,
--rb 04/13/2015 Test performance, update after
				
				null, -- dbo.fn_get_receipt_JDE_glaccount_business_unit(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id) AS JDE_BU,
				null, -- dbo.fn_get_receipt_JDE_glaccount_object(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id) AS JDE_object,
				dbo.fn_get_receipt_AX_gl_account(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id,'MAIN') AS AX_MainAccount,
				dbo.fn_get_receipt_AX_gl_account(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id,'DIM1') AS AX_Dimension_1, 
				dbo.fn_get_receipt_AX_gl_account(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id,'DIM2') AS AX_Dimension_2,  
				dbo.fn_get_receipt_AX_gl_account(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id,'DIM3') AS AX_Dimension_3,  
				dbo.fn_get_receipt_AX_gl_account(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id,'DIM4') AS AX_Dimension_4,
				dbo.fn_get_receipt_AX_gl_account(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id,'DIM5') AS AX_Dimension_5_part_1,
				dbo.fn_get_receipt_AX_gl_account(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id,'DI52') AS AX_Dimension_5_part_2,
				dbo.fn_get_receipt_AX_gl_account(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id,'DIM6') AS AX_Dimension_6,
				
				Receipt.waste_code_uid,
				NULL as reference_code,
				ISNULL(REPLACE(receipt.purchase_order,'''', ''),'') AS purchase_order,
				ISNULL(REPLACE(receipt.release,'''', ''),'') AS release_code,
				woh.ticket_number
				, woh.start_date
			FROM Receipt (nolock)
--rb 04/10/2015
--			INNER JOIN #tmp_source ts
--				ON 'R' = ts.trans_source

			-- rb 04/10/2015 uncommented
			INNER JOIN #tmp_trans_copc copc
				ON Receipt.company_id = copc.company_id
				AND Receipt.profit_ctr_id = copc.profit_ctr_id
			
			INNER JOIN ReceiptPrice (nolock)
				ON Receipt.company_id = ReceiptPrice.company_id
				AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
				AND Receipt.receipt_id = ReceiptPrice.receipt_id
				AND Receipt.line_id = ReceiptPrice.line_id
				AND ReceiptPrice.print_on_invoice_flag = 'T'
			INNER JOIN Company (nolock)
				ON Company.company_id = Receipt.company_id
			INNER JOIN ProfitCenter (nolock)
				ON ProfitCenter.company_ID = Receipt.company_id
				AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
			join @customer Customer on receipt.customer_id = Customer.customer_id
			LEFT OUTER JOIN CustomerBilling (nolock)
				ON Receipt.customer_id = CustomerBilling.customer_id
				AND ISNULL(Receipt.billing_project_id, 0) = CustomerBilling.billing_project_id
			LEFT OUTER JOIN Generator (nolock)
				ON Receipt.generator_id = Generator.generator_id
			LEFT OUTER JOIN ProfileQuoteDetail pqd1 (nolock)
				ON Receipt.profile_id = pqd1.profile_id
				AND ReceiptPrice.company_id = pqd1.company_id
				AND ReceiptPrice.profit_ctr_id = pqd1.profit_ctr_id
				AND ReceiptPrice.bill_unit_code = pqd1.bill_unit_code
				AND pqd1.record_type = 'D'
			LEFT OUTER JOIN Treatment (nolock)
				ON Receipt.treatment_id = Treatment.treatment_id
				AND Receipt.company_id = Treatment.company_id
				AND Receipt.profit_ctr_id = Treatment.profit_ctr_id
			LEFT OUTER JOIN Profile prfl (nolock)
				ON Receipt.profile_id = prfl.profile_id
			LEFT OUTER JOIN BillingLinkLookup bll (nolock) 
				ON Receipt.receipt_id = bll.receipt_id
				and Receipt.company_id = bll.company_id
				and Receipt.profit_ctr_id = bll.profit_ctr_id
			LEFT JOIN WorkOrderHeader woh (nolock) 
				ON woh.company_id = bll.source_company_id
				AND woh.profit_ctr_id = bll.source_profit_ctr_id
				AND woh.workorder_id = bll.source_id		

			WHERE
				(Receipt.submitted_flag = 'F' 
				/* OR (Receipt.submitted_flag = 'T' and not exists (select 1 from billing where receipt_id = Receipt.receipt_id and company_id = Receipt.company_id and profit_ctr_id = Receipt.profit_ctr_id and trans_source = 'R' and status_code = 'I'))
				*/
				)
				-- AND Receipt.customer_id BETWEEN @cust_id_from AND @cust_id_to
				-- AND COALESCE(wos.date_act_arrive, woh.start_date, receipt.receipt_date) BETWEEN @date_from AND @date_to
				AND receipt.receipt_date BETWEEN @date_from AND @date_to
				AND Receipt.fingerpr_status IN ('W', 'H', 'A')		/* Wait, Hold, Accepted */
				AND Receipt.receipt_status NOT IN ('V','R','T','X')
	--rb 04/08/2015			AND @invoice_flag IN ('N', 'S', 'U')
/* rb 04/10/2015
				and 1 = case @copc_search_type
					when 'T' then case when exists (select 1 from #tmp_trans_copc where company_id = Receipt.company_id and profit_ctr_id = Receipt.profit_ctr_id) then 1 else 0 end
					when 'D' then case when exists (
						-- bundled splits
						select 1 from ProfileQuoteDetailSplitGroup sg (nolock)
						INNER JOIN ProfileQuoteDetail pqd (nolock) on sg.quote_id = pqd.quote_id and sg.company_id = pqd.company_id and sg.profit_ctr_id = pqd.profit_ctr_id
						inner join #tmp_trans_copc cp on pqd.dist_company_id = cp.company_id and pqd.dist_profit_ctr_id = cp.profit_ctr_id
						where pqd.profile_id = receipt.profile_id and pqd.company_id = receipt.company_id and pqd.profit_ctr_id = receipt.profit_ctr_id
						UNION
						-- unbundled splits
						select 1 from ProfileQuoteDetail pqd (nolock)
						inner join #tmp_trans_copc cp on isnull(pqd.dist_company_id, pqd.company_id) = cp.company_id and isnull(pqd.dist_profit_ctr_id, pqd.profit_ctr_id) = cp.profit_ctr_id
						where pqd.profile_id = receipt.profile_id and pqd.company_id = receipt.company_id and pqd.profit_ctr_id = receipt.profit_ctr_id

						UNION
						-- misc. products without profiles (see receipt 513714 line 6) splits
						select 1 from Product (nolock)
						inner join #tmp_trans_copc cp on product.company_id = cp.company_id and product.profit_ctr_id = cp.profit_ctr_id
						where product.product_id = receipt.product_id -- and product.company_id = receipt.company_id and pqd.profit_ctr_id = receipt.profit_ctr_id
					
						 ) then 1 else 0 end
					else 0
				end
*/
		end

--#endregion



--#region receipt-copc-search-type-D
		else if @copc_search_type = 'D' 
		begin
			 -- Non-Billing source, and submitted_flag = 'F' below, so this is Not invoiced or Unsubmitted
			INSERT #InternalFlashWork (
				company_id					,
				profit_ctr_id				,
				trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
				receipt_id					, -- Receipt/Workorder ID
				trans_type					, -- Receipt trans type (O/I)
				link_flag					,
				linked_record				,
				workorder_type				, -- WorkOrderType.account_desc
				trans_status				, -- Receipt or Workorder Status
				status_description			, -- Billing/Transaction status description
				trans_date					, -- Receipt Date or Workorder End Date
				pickup_date					, -- Pickup Date
				submitted_flag				, -- Submitted Flag
				date_submitted				, -- Submitted Date
				submitted_by				, -- Submitted by
				billing_status_code			, -- Billing Status Code
				territory_code				, -- Billing Project Territory code
				billing_project_id			, -- Billing project ID
				billing_project_name		, -- Billing Project Name
				invoice_flag				, -- Invoiced? Flag
				invoice_code				, -- Invoice Code (if invoiced)
				invoice_date				, -- Invoice Date (if invoiced)
				invoice_month				, -- Invoice Date month
				invoice_year				, -- Invoice Date year
				customer_id					, -- Customer ID on Receipt/Workorder
				cust_name					, -- Customer Name
				customer_Type				, -- Customer Type
				cust_category				, -- Customer Category
				line_id						, -- Receipt line id
				price_id					, -- Receipt line price id
				ref_line_id					, -- Billing reference line_id (which line does this refer to?)
				workorder_sequence_id		, -- Workorder sequence id
				workorder_resource_item		, -- Workorder Resource Item
				workorder_resource_type		, -- Workorder Resource Type
				Workorder_resource_category ,
				quantity					, -- Receipt/Workorder Quantity
				billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
				dist_flag					, -- Distributed Transaction?
				dist_company_id				, -- Distribution Company ID (which company receives the revenue)
				dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
				gl_account_code				, -- GL Account for the revenue
				gl_native_code				,
				gl_dept_code				,
				extended_amt				, -- Revenue amt
				generator_id				, -- Generator ID
				generator_name				, -- Generator Name
				epa_id						, -- Generator EPA ID
				treatment_id				,	--	Treatment	ID
				treatment_desc				,	--	Treatment's	treatment_desc
				treatment_process_id		,	--	Treatment's	treatment_process_id
				treatment_process			,	--	Treatment's	treatment_process	(desc)
				disposal_service_id			,	--	Treatment's	disposal_service_id
				disposal_service_desc		,	--	Treatment's	disposal_service_desc
				wastetype_id				,	--	Treatment's	wastetype_id
				wastetype_category			,	--	Treatment's	wastetype	category
				wastetype_description		,	--	Treatment's	wastetype	description
				bill_unit_code				, -- Unit
				waste_code					, -- Waste Code
				profile_id					, -- Profile_id
				quote_id					, -- Quote ID
				product_id					,	--	BillingDetail	product_id,	for	id'ing	fees,	etc.
				product_code				,	-- Product Code
				approval_code				, -- Approval Code
				approval_desc				,
				tsdf_code					,
				tsdf_eq_flag				,
				fixed_price_flag			, -- Fixed Price Flag
				pricing_method				, -- Calculated, Actual, etc.
				quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
				JDE_BU						,
				JDE_object					,
				AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				AX_Dimension_2				,	-- AX_business_unit
				AX_Dimension_3				,	-- AX_department
				AX_Dimension_4				,	-- AX_line_of_business
				AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				waste_code_uid				,
				reference_code,
				purchase_order				,
				release_code				,	
				ticket_number					-- WorkOrderHeader.ticket_number, if there is a linked WO
				,workorder_startdate		
			)
			SELECT DISTINCT
				Receipt.company_id,
				Receipt.profit_ctr_id,
				'R' AS trans_source,
				Receipt.receipt_id,
				Receipt.trans_type,
				link_flag = (
				select
				isnull(
					(
					select top 1 case link_required_flag when 'E' then 'E' else 'T' end
					from billinglinklookup (nolock)
					where receipt_id = Receipt.receipt_id 
					and company_id = Receipt.company_id
					and profit_ctr_id = Receipt.profit_ctr_id
					ORDER BY isnull(link_required_flag, 'Z')
					)
				, 'F')
				),
				/*
				case when exists (
					select 1 from billinglinklookup (nolock)
					where receipt_id = Receipt.receipt_id 
					and company_id = Receipt.company_id
					and profit_ctr_id = Receipt.profit_ctr_id
					and link_required_flag = 'E'
					) then 'E' 
					else 
						case when exists (
							select 1 from billinglinklookup (nolock)
							where receipt_id = Receipt.receipt_id 
							and company_id = Receipt.company_id
							and profit_ctr_id = Receipt.profit_ctr_id
							and link_required_flag <> 'E'
						) then 'T' else 'F' 
						end 
					end AS link_flag,
				*/
				NULL /* rb 04/13/2015 dbo.fn_get_linked_workorders(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id)*/ as linked_record, -- Wo's don't list these.  R's do.
				NULL AS workorder_type,
				Receipt.receipt_status AS trans_status,
				CASE Receipt.receipt_status
					WHEN 'L' THEN
						CASE Receipt.fingerpr_status
							WHEN 'A' THEN 'Lab, Accepted'
							WHEN 'H' THEN 'Lab, Hold'
							WHEN 'W' THEN 'Lab, Waiting'
							ELSE 'Unknown Lab Status: ' + Receipt.fingerpr_status
						END
					WHEN 'A' THEN 'Accepted'
					WHEN 'M' THEN 'Manual'
					WHEN 'N' THEN 'New'
					WHEN 'U' THEN 
						CASE Receipt.waste_accepted_flag
							WHEN 'T' THEN 'Waste Accepted'
							ELSE 'Unloading'
						END
					ELSE NULL
				END	status_description,
				Receipt.receipt_date AS trans_date,
				pickup_date = (
					select top 1 _date from
					--coalesce(rt.transporter_sign_date, wospu.date_act_arrive, wohpu.start_date)
					(
						select rt.transporter_sign_date _date
						FROM ReceiptTransporter RT WITH(nolock) 
						WHERE  RT.receipt_id = Receipt.receipt_id 
						and RT.company_id = Receipt.company_id 
						and RT.profit_ctr_id = Receipt.profit_ctr_id
						and RT.transporter_sequence_id = 1
						union
						select coalesce(wospu.date_act_arrive, wohpu.start_date) _date
						FROM BillingLinkLookup bllpu (nolock) 
						LEFT JOIN WorkOrderHeader wohpu (nolock) 
							ON wohpu.company_id = bllpu.source_company_id
							AND wohpu.profit_ctr_id = bllpu.source_profit_ctr_id
							AND wohpu.workorder_id = bllpu.source_id					
						LEFT JOIN workorderstop wospu (nolock)
							ON wohpu.workorder_id = wospu.workorder_id
							and wospu.stop_sequence_id = 1
							and wohpu.company_id = wospu.company_id
							and wohpu.profit_ctr_id = wospu.profit_ctr_id
						WHERE  bllpu.receipt_id = Receipt.receipt_id
						and bllpu.company_id = Receipt.company_id
						and bllpu.profit_ctr_id = Receipt.profit_ctr_id
					) y
					WHERE _date is not null
					order by _date
				),
/*
				pickup_date = (
					select top 1 coalesce(rt.transporter_sign_date, wospu.date_act_arrive, wohpu.start_date)
					FROM Receipt rpu (nolock)
					LEFT OUTER JOIN ReceiptTransporter RT WITH(nolock) 
						ON RT.receipt_id = rpu.receipt_id 
						and RT.company_id = rpu.company_id 
						and RT.profit_ctr_id = rpu.profit_ctr_id
						and RT.transporter_sequence_id = 1
					LEFT OUTER JOIN BillingLinkLookup bllpu (nolock) 
						ON rpu.receipt_id = bllpu.receipt_id
						and rpu.company_id = bllpu.company_id
						and rpu.profit_ctr_id = bllpu.profit_ctr_id
					LEFT JOIN WorkOrderHeader wohpu (nolock) 
						ON wohpu.company_id = bllpu.source_company_id
						AND wohpu.profit_ctr_id = bllpu.source_profit_ctr_id
						AND wohpu.workorder_id = bllpu.source_id					
					LEFT JOIN workorderstop wospu (nolock)
						ON wohpu.workorder_id = wospu.workorder_id
						and wospu.stop_sequence_id = 1
						and wohpu.company_id = wospu.company_id
						and wohpu.profit_ctr_id = wospu.profit_ctr_id
					WHERE
						rpu.receipt_id = Receipt.receipt_id
						and rpu.company_id = Receipt.company_id
						and rpu.profit_ctr_id = Receipt.profit_ctr_id
				),
*/
				Receipt.submitted_flag,
				Receipt.date_submitted,
				Receipt.submitted_by,
				NULL as billing_status_code,
				CustomerBilling.territory_code,
				CustomerBilling.billing_project_id,
				CustomerBilling.project_name,
				'F' as invoice_flag,
				NULL as invoice_code,
				NULL as invoice_date,
				NULL as invoice_month,
				NULL as invoice_year,
				Customer.customer_id,
				Customer.cust_name,
				Customer.customer_type,
				Customer.cust_category,
				Receipt.line_id,
				ReceiptPrice.price_id,
				NULL as ref_line_id,
				NULL AS workorder_sequence_id,
				NULL AS workorder_resource_item,
				NULL AS workorder_resource_type,
				NULL AS Workorder_resource_category,
				ReceiptPrice.bill_quantity,
				case Receipt.trans_type
					WHEN 'D' then 'Disposal'
					WHEN 'S' then 'Product'
					WHEN 'W' then 'Wash'
				end AS billing_type,
				-- Modify: GEM-43800: If Product, call it Distributed?
				-- 'N', -- Not Split, since there's no billing record to split it
				case when exists ( select 1 from profilequotedetail pqd WHERE pqd.profile_id = receipt.profile_id and pqd.company_id = receipt.company_id and pqd.profit_ctr_id = receipt.profit_ctr_id and pqd.bill_method = 'B' ) then 'D' else 
					'N'
				end as dist_flag,
				receipt.company_id,
				receipt.profit_ctr_id,
				null, -- dbo.fn_get_receipt_glaccount(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id),
				null as gl_native_code,
				null as gl_dept_code,
				ReceiptPrice.total_extended_amt,
				Generator.generator_id,
				Generator.generator_name,
				Generator.epa_id,
				Receipt.treatment_id,
				Treatment.treatment_desc,
				Treatment.treatment_process_id,
				Treatment.treatment_process_process,
				Treatment.disposal_service_id,
				Treatment.disposal_service_desc,
				Treatment.wastetype_id,
				Treatment.wastetype_category,
				Treatment.wastetype_description,
				ReceiptPrice.bill_unit_code,
				Receipt.waste_code,
				Receipt.profile_id,
				pqd1.quote_id,
				Receipt.product_id,
				Receipt.product_code,
				Receipt.approval_code,
				prfl.approval_desc,
				NULL as tsdf_code,
				NULL as tsdf_eq_flag,
				NULL AS fixed_price_flag,
				'A' AS pricing_method, --CASE WHEN Billing.receipt_id is not null then 'A' ELSE null END as pricing_method,
				CASE WHEN ISNULL(ReceiptPrice.bill_quantity, 0) <> 0 THEN 'T' ELSE 'F' END AS quantity_flag,
--rb 04/13/2015 experiment, see if updating after insert increases performance
				JDE_BU = null, --dbo.fn_get_receipt_JDE_glaccount_business_unit (receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id),
				JDE_object = null, --dbo.fn_get_receipt_JDE_glaccount_object (receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id),
				'' AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				'' AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				'' AX_Dimension_2				,	-- AX_business_unit
				'' AX_Dimension_3				,	-- AX_department
				'' AX_Dimension_4				,	-- AX_line_of_business
				'' AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				'' AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				'' AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
				Receipt.waste_code_uid,
				NULL as reference_code,
				ISNULL(REPLACE(receipt.purchase_order,'''', ''),'') AS purchase_order,
				ISNULL(REPLACE(receipt.release,'''', ''),'') AS release_code,
				woh.ticket_number
				, woh.start_date
			FROM Receipt (nolock)
	--rb 
	--		INNER JOIN #tmp_source ts
	--			ON 'R' = ts.trans_source
/*
			INNER JOIN #tmp_trans_copc copc
				ON Receipt.company_id = copc.company_id
				AND Receipt.profit_ctr_id = copc.profit_ctr_id
*/			
			INNER JOIN ReceiptPrice (nolock)
				ON Receipt.company_id = ReceiptPrice.company_id
				AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
				AND Receipt.receipt_id = ReceiptPrice.receipt_id
				AND Receipt.line_id = ReceiptPrice.line_id
				AND ReceiptPrice.print_on_invoice_flag = 'T'
			INNER JOIN Company (nolock)
				ON Company.company_id = Receipt.company_id
			INNER JOIN ProfitCenter (nolock)
				ON ProfitCenter.company_ID = Receipt.company_id
				AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
			join @customer Customer on Receipt.customer_id = Customer.customer_id
			LEFT OUTER JOIN CustomerBilling (nolock)
				ON Receipt.customer_id = CustomerBilling.customer_id
				AND ISNULL(Receipt.billing_project_id, 0) = CustomerBilling.billing_project_id
			LEFT OUTER JOIN Generator (nolock)
				ON Receipt.generator_id = Generator.generator_id
			LEFT OUTER JOIN ProfileQuoteDetail pqd1 (nolock)
				ON Receipt.profile_id = pqd1.profile_id
				AND ReceiptPrice.company_id = pqd1.company_id
				AND ReceiptPrice.profit_ctr_id = pqd1.profit_ctr_id
				AND ReceiptPrice.bill_unit_code = pqd1.bill_unit_code
				AND pqd1.record_type = 'D'
			LEFT OUTER JOIN Treatment (nolock)
				ON Receipt.treatment_id = Treatment.treatment_id
				AND Receipt.company_id = Treatment.company_id
				AND Receipt.profit_ctr_id = Treatment.profit_ctr_id
			LEFT OUTER JOIN Profile prfl (nolock)
				ON Receipt.profile_id = prfl.profile_id
			LEFT OUTER JOIN BillingLinkLookup bll (nolock) 
				ON Receipt.receipt_id = bll.receipt_id
				and Receipt.company_id = bll.company_id
				and Receipt.profit_ctr_id = bll.profit_ctr_id
			LEFT JOIN WorkOrderHeader woh (nolock) 
				ON woh.company_id = bll.source_company_id
				AND woh.profit_ctr_id = bll.source_profit_ctr_id
				AND woh.workorder_id = bll.source_id		

			WHERE
				(Receipt.submitted_flag = 'F' 
				/* OR (Receipt.submitted_flag = 'T' and not exists (select 1 from billing where receipt_id = Receipt.receipt_id and company_id = Receipt.company_id and profit_ctr_id = Receipt.profit_ctr_id and trans_source = 'R' and status_code = 'I'))
				*/
				)
				-- AND Receipt.customer_id BETWEEN @cust_id_from AND @cust_id_to
				-- AND COALESCE(wos.date_act_arrive, woh.start_date, receipt.receipt_date) BETWEEN @date_from AND @date_to
				AND receipt.receipt_date BETWEEN @date_from AND @date_to
				AND Receipt.fingerpr_status IN ('W', 'H', 'A')		/* Wait, Hold, Accepted */
				AND Receipt.receipt_status NOT IN ('V','R','T','X')
	--rb 04/08/2015			AND @invoice_flag IN ('N', 'S', 'U')
				AND exists (
					-- bundled splits
					select 1 from ProfileQuoteDetailSplitGroup sg (nolock)
					INNER JOIN ProfileQuoteDetail pqd (nolock) on sg.quote_id = pqd.quote_id and sg.company_id = pqd.company_id and sg.profit_ctr_id = pqd.profit_ctr_id
					inner join #tmp_trans_copc cp on pqd.dist_company_id = cp.company_id and pqd.dist_profit_ctr_id = cp.profit_ctr_id
					where pqd.profile_id = receipt.profile_id and pqd.company_id = receipt.company_id and pqd.profit_ctr_id = receipt.profit_ctr_id
					UNION
					-- unbundled splits
					select 1 from ProfileQuoteDetail pqd (nolock)
					inner join #tmp_trans_copc cp on isnull(pqd.dist_company_id, pqd.company_id) = cp.company_id and isnull(pqd.dist_profit_ctr_id, pqd.profit_ctr_id) = cp.profit_ctr_id
					where pqd.profile_id = receipt.profile_id and pqd.company_id = receipt.company_id and pqd.profit_ctr_id = receipt.profit_ctr_id

					UNION
					-- misc. products without profiles (see receipt 513714 line 6) splits
					select 1 from Product (nolock)
					inner join #tmp_trans_copc cp on product.company_id = cp.company_id and product.profit_ctr_id = cp.profit_ctr_id
					where product.product_id = receipt.product_id -- and product.company_id = receipt.company_id and pqd.profit_ctr_id = receipt.profit_ctr_id
				)

		end
		
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "Not In Billing, Receipt, Actual Pricing" Population' as status
	set @lasttime = getdate()

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "Not In Billing, Receipt, Actual Pricing" JDE Field Updates' as status
	set @lasttime = getdate()

		-- rb 04/13/2015 moved out of insert statements
		update #InternalFlashWork
		set	linked_record = dbo.fn_get_linked_workorders (company_id, profit_ctr_id, receipt_id)
		where trans_source = 'R'
		and link_flag <> 'F'
		and linked_record is null

		-- rb 04/13/2015 moved out of insert statements
		update #InternalFlashWork set
			AX_MainAccount = dbo.fn_get_receipt_AX_gl_account(company_id, profit_ctr_id, receipt_id, line_id,'MAIN'),
			AX_Dimension_1 = dbo.fn_get_receipt_AX_gl_account(company_id, profit_ctr_id, receipt_id, line_id,'DIM1'), 
			AX_Dimension_2 = dbo.fn_get_receipt_AX_gl_account(company_id, profit_ctr_id, receipt_id, line_id,'DIM2'),  
			AX_Dimension_3 = dbo.fn_get_receipt_AX_gl_account(company_id, profit_ctr_id, receipt_id, line_id,'DIM3'),  
			AX_Dimension_4 = dbo.fn_get_receipt_AX_gl_account(company_id, profit_ctr_id, receipt_id, line_id,'DIM4'),
			AX_Dimension_5_part_1 = dbo.fn_get_receipt_AX_gl_account(company_id, profit_ctr_id, receipt_id, line_id,'DIM5'),
			AX_Dimension_5_part_2 = dbo.fn_get_receipt_AX_gl_account(company_id, profit_ctr_id, receipt_id, line_id,'DI52'),
			AX_Dimension_6 = dbo.fn_get_receipt_AX_gl_account(company_id, profit_ctr_id, receipt_id, line_id,'DIM6')
		where trans_source = 'R'
		and AX_MainAccount = ''
		and AX_Dimension_1				= ''
		and AX_Dimension_2				= ''
		and AX_Dimension_3				= ''
		and AX_Dimension_4				= ''
		and AX_Dimension_5_Part_1		= ''
		and AX_Dimension_5_Part_2		= ''
		and AX_Dimension_6				= ''


	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "Not In Billing, Receipt, Actual Pricing" JDE Field Updates' as status
	set @lasttime = getdate()

--#endregion		

	END

--#endregion
	
	
	/*
	If not in Billing
					If Receipt
								Take from receipt price
								... now... Addition of product records from profile that are not optional and not exempt
								Pricing method = 'C'
	*/

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "Not In Billing, Receipt, Calculated Pricing" Population' as status
	set @lasttime = getdate()
	
--#region receipt rows + non-optional additions from profiles
	IF exists (select 1 from #tmp_source where trans_source = 'R')
	--rb 04/08/2015 Originally had "AND @invoice_flag IN ('N', 'S', 'U')" in the where clause, which the optimizer ignored before starting work (most likely the subselect in where clause)
		AND @invoice_flag IN ('N', 'S', 'U')

		INSERT #InternalFlashWork (
			company_id					,
			profit_ctr_id				,
			trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
			receipt_id					, -- Receipt/Workorder ID
			trans_type					, -- Receipt trans type (O/I)
			link_flag					,
			linked_record				,
			workorder_type				, -- WorkOrderType.account_desc
			trans_status				, -- Receipt or Workorder Status
			status_description			, -- Billing/Transaction status description
			trans_date					, -- Receipt Date or Workorder End Date
			pickup_date					, -- Pickup Date
			submitted_flag				, -- Submitted Flag
			date_submitted				, -- Submitted Date
			submitted_by				, -- Submitted by
			billing_status_code			, -- Billing Status Code
			territory_code				, -- Billing Project Territory code
			billing_project_id			, -- Billing project ID
			billing_project_name		, -- Billing Project Name
			invoice_flag				, -- Invoiced? Flag
			invoice_code				, -- Invoice Code (if invoiced)
			invoice_date				, -- Invoice Date (if invoiced)
			invoice_month				, -- Invoice Date month
			invoice_year				, -- Invoice Date year
			customer_id					, -- Customer ID on Receipt/Workorder
			cust_name					, -- Customer Name
			customer_Type				, -- Customer Type
			cust_category				, -- Customer Category
			line_id						, -- Receipt line id
			price_id					, -- Receipt line price id
			ref_line_id					, -- Billing reference line_id (which line does this refer to?)
			workorder_sequence_id		, -- Workorder sequence id
			workorder_resource_item		, -- Workorder Resource Item
			workorder_resource_type		, -- Workorder Resource Type
			Workorder_resource_category ,
			quantity					, -- Receipt/Workorder Quantity
			billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
			dist_flag					, -- Distributed Transaction?
			dist_company_id				, -- Distribution Company ID (which company receives the revenue)
			dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
			gl_account_code				, -- GL Account for the revenue
			gl_native_code				,
			gl_dept_code				,
			extended_amt				, -- Revenue amt
			generator_id				, -- Generator ID
			generator_name				, -- Generator Name
			epa_id						, -- Generator EPA ID
			treatment_id				,	--	Treatment	ID
			treatment_desc				,	--	Treatment's	treatment_desc
			treatment_process_id		,	--	Treatment's	treatment_process_id
			treatment_process			,	--	Treatment's	treatment_process	(desc)
			disposal_service_id			,	--	Treatment's	disposal_service_id
			disposal_service_desc		,	--	Treatment's	disposal_service_desc
			wastetype_id				,	--	Treatment's	wastetype_id
			wastetype_category			,	--	Treatment's	wastetype	category
			wastetype_description		,	--	Treatment's	wastetype	description
			bill_unit_code				, -- Unit
			waste_code					, -- Waste Code
			profile_id					, -- Profile_id
			quote_id					, -- Quote ID
			product_id					,	--	BillingDetail	product_id,	for	id'ing	fees,	etc.
			product_code				,	-- Product Code
			approval_code				, -- Approval Code
			approval_desc				,
			tsdf_code					,
			tsdf_eq_flag				,
			fixed_price_flag			, -- Fixed Price Flag
			pricing_method				, -- Calculated, Actual, etc.
			quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
			JDE_BU						,
			JDE_object					,
			AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
			AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
			AX_Dimension_2				,	-- AX_business_unit
			AX_Dimension_3				,	-- AX_department
			AX_Dimension_4				,	-- AX_line_of_business
			AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
			AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
			AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
			waste_code_uid				,
			reference_code,
			purchase_order				,
			release_code				,	
			ticket_number					-- WorkOrderHeader.ticket_number, if there is a linked WO
			,workorder_startdate		
		)
		SELECT DISTINCT
			k.company_id					,
			k.profit_ctr_id				,
			k.trans_source 					, -- Receipt, Workorder, Workorder-Receipt, etc
			k.receipt_id					, -- Receipt/Workorder ID
			k.trans_type					, -- Receipt trans type (O/I)
			k.link_flag,
			k.linked_record,
			k.workorder_type				, -- WorkOrderType.account_desc
			k.trans_status				, -- Receipt or Workorder Status
			k.status_description			, -- Billing/Transaction status description
			k.trans_date					, -- Receipt Date or Workorder End Date
			k.pickup_date					, -- Pickup Date
			k.submitted_flag				, -- Submitted Flag
			k.date_submitted,
			k.submitted_by,
			k.billing_status_code			, -- Billing Status Code
			k.territory_code				, -- Billing Project Territory code
			k.billing_project_id			, -- Billing project ID
			k.billing_project_name		, -- Billing Project Name
			k.invoice_flag				, -- Invoiced? Flag
			k.invoice_code				, -- Invoice Code (if invoiced)
			k.invoice_date				, -- Invoice Date (if invoiced)
			k.invoice_month				, -- Invoice Date month
			k.invoice_year				, -- Invoice Date year
			k.customer_id					, -- Customer ID on Receipt/Workorder
			k.cust_name					, -- Customer Name
			k.customer_type				, -- Customer Type
			k.cust_category			, -- Customer Category
			k.line_id						, -- Receipt line id
			k.price_id					, -- Receipt line price id
			k.ref_line_id					, -- Billing reference line_id (which line does this refer to?)
			k.workorder_sequence_id		, -- Workorder sequence id
			k.workorder_resource_item		, -- Workorder Resource Item
			k.workorder_resource_type		, -- Workorder Resource Type
			k.Workorder_resource_category , -- Workorder Resource Category
			k.quantity					, -- Receipt/Workorder Quantity
			'Product'					, -- (billing_type) 'Energy', 'Insurance', 'Salestax' etc.
			-- Modify: GEM-43800: If Product, call it Distributed? Not here, it already specifies these are 'U'nbundled billing types
			case when pqd2.dist_company_id <> k.company_id or pqd2.dist_profit_ctr_id <> k.profit_ctr_id then 'D' else 'N' end,
			ISNULL(pqd2.dist_company_id, k.company_id),
			ISNULL(pqd2.dist_profit_ctr_id, k.profit_ctr_id),
			--prod.gl_account_code				, -- GL Account for the revenue
			null, -- dbo.fn_get_receipt_glaccount(k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id), -- GL Account for the revenue
			null as gl_native_code,
			null as gl_dept_code,
			pqd2.price * k.quantity, -- Revenue amt
			k.generator_id				, -- Generator ID
			k.generator_name				, -- Generator Name
			k.epa_id						, -- Generator EPA ID
			k.treatment_id				, -- Treatment ID
			k.treatment_desc				, -- Treatment's treatment_desc
			k.treatment_process_id		, -- Treatment's treatment_process_id
			k.treatment_process			, -- Treatment's treatment_process (desc)
			k.disposal_service_id			, -- Treatment's disposal_service_id
			k.disposal_service_desc		, -- Treatment's disposal_service_desc
			k.wastetype_id				, -- Treatment's wastetype_id
			k.wastetype_category			, -- Treatment's wastetype category
			k.wastetype_description		, -- Treatment's wastetype description
			k.bill_unit_code				, -- Unit
			k.waste_code					, -- Waste Code
			k.profile_id					, -- Profile_id
			k.quote_id					, -- Quote ID
			pqd2.product_id					, -- BillingDetail product_id, for id'ing fees, etc.
			pqd2.product_code,
			k.approval_code				, -- Approval Code
			k.approval_desc,
			k.TSDF_code					, -- TSDF Code
			k.TSDF_EQ_FLAG				, -- TSDF: Is this an EQ tsdf?
			k.fixed_price_flag			, -- Fixed Price Flag
			'C', -- Calculated, Actual, etc.
			k.quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
			JDE_BU = null, -- dbo.fn_get_receipt_JDE_glaccount_business_unit (k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id),
			JDE_object = null, -- dbo.fn_get_receipt_JDE_glaccount_object (k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id),

			dbo.fn_get_receipt_AX_gl_account(k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id,'MAIN') AS AX_MainAccount,
			dbo.fn_get_receipt_AX_gl_account(k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id,'DIM1') AS AX_Dimension_1, 
			dbo.fn_get_receipt_AX_gl_account(k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id,'DIM2') AS AX_Dimension_2,  
			dbo.fn_get_receipt_AX_gl_account(k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id,'DIM3') AS AX_Dimension_3,  
			dbo.fn_get_receipt_AX_gl_account(k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id,'DIM4') AS AX_Dimension_4,
			dbo.fn_get_receipt_AX_gl_account(k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id,'DIM5') AS AX_Dimension_5_part_1,
			dbo.fn_get_receipt_AX_gl_account(k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id,'DI52') AS AX_Dimension_5_part_2,
			dbo.fn_get_receipt_AX_gl_account(k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id,'DIM6') AS AX_Dimension_6,

			k.waste_code_uid,
			k.reference_code,
			k.purchase_order,
			k.release_code,
			woh.ticket_number
			, woh.start_date
		FROM #InternalFlashWork k
		INNER JOIN ProfileQuoteDetail pqd1 (nolock)
			ON k.profile_id = pqd1.profile_id
			AND k.company_id = pqd1.company_id
			AND k.profit_ctr_id = pqd1.profit_ctr_id
			AND k.bill_unit_code = pqd1.bill_unit_code
			AND pqd1.record_type = 'D'
			AND pqd1.profile_id > 0 -- DevOps:94294 
		INNER JOIN ProfileQuoteDetail pqd2 (nolock)
			ON pqd2.quote_id = pqd1.quote_id
			AND pqd2.company_id = pqd1.company_id
			AND pqd2.profit_ctr_id = pqd1.profit_ctr_id
			AND (pqd2.ref_sequence_id = pqd1.sequence_id OR pqd2.ref_sequence_id = 0)
			AND pqd2.record_type IN ('S', 'T')
			AND pqd2.optional_flag = 'F'
			AND pqd2.fee_exempt_flag = 'F'
			AND pqd2.bill_method = 'U'
			AND pqd2.bill_quantity_flag = 'U'
			AND pqd1.profile_id > 0 -- DevOps:94294 
		--INNER JOIN Product prod (nolock)
		--	ON pqd2.product_id = prod.product_id
		--	AND pqd2.company_id = prod.company_id
		--	AND pqd2.profit_ctr_id = prod.profit_ctr_id
		--	AND pqd2.bill_unit_code = prod.bill_unit_code
		LEFT OUTER JOIN BillingLinkLookup bll (nolock) 
			ON k.receipt_id = bll.receipt_id
			and k.company_id = bll.company_id
			and k.profit_ctr_id = bll.profit_ctr_id
		LEFT JOIN WorkOrderHeader woh (nolock) 
			ON woh.company_id = bll.source_company_id
			AND woh.profit_ctr_id = bll.source_profit_ctr_id
			AND woh.workorder_id = bll.source_id		
	WHERE k.trans_source = 'R'
		AND NOT EXISTS (
			SELECT 1 FROM Receipt r (nolock)
			WHERE r.receipt_id = k.receipt_id
			AND r.company_id = k.company_id
			AND r.profit_ctr_id = k.profit_ctr_id
			AND r.line_id = k.line_id
			AND (
				r.receipt_status = 'A' -- accepted
				OR (
					r.receipt_status = 'U'			-- waste
					AND r.waste_accepted_flag = 'T'		-- accepted
				
				)
			)
		)
--rb 04/08/2015		AND @invoice_flag IN ('N', 'S', 'U')

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "Not In Billing, Receipt, Calculated Pricing" Population' as status
	set @lasttime = getdate()

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting fake submit to get bundled lines, Receipt Population' as status
	set @lasttime = getdate()
				
--#endregion

		

		
/*
	Perform faux Billing Submit to get other charges & splits in here.
	1. create @tables
	2. Load tables for records in #InternalFlashWork
	3. Run Submit bundled charges logic (all? 1 at a time?)
	4. Get data back from #tables into #InternalFlashWork
*/


--#region receipt-faux-billing
	-- Populate
	IF exists (select 1 from #tmp_source where trans_source = 'R')
	--rb 04/13/2015
		AND @invoice_flag IN ('N', 'U') -- Non-Billing source, and submitted_flag = 'F' below, so this is Not invoiced or Unsubmitted

	INSERT #Billing 
	SELECT	receipt.company_id,
		receipt.profit_ctr_id,
		'R' AS trans_source,
		receipt.receipt_id,
		receipt.line_id,
		receiptPrice.price_id AS price_id,
		CASE WHEN receipt.billing_link_id > 0
		  THEN 'H'
		  ELSE CASE WHEN NULL IS NOT NULL THEN NULL
			ELSE CASE WHEN ISNULL(receipt.submit_on_hold_flag,'F') = 'T' THEN 'H' ELSE 'S' END 
			END 
		END AS status_code,
		receipt.receipt_date AS billing_date,
		ISNULL(receipt.customer_id, 0) AS customer_id,
		ISNULL(REPLACE(receipt.waste_code,'''', ''), '') AS waste_code,
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
		CASE WHEN (
			SELECT ISNULL(discount_flag,'F') FROM profitcenter  (nolock)
			WHERE company_id = fw.company_id AND profit_ctr_id = fw.profit_ctr_id
		) = 'T' THEN ISNULL(CustomerBilling.cust_discount,0) ELSE 0 END AS discount_percent,
		--ISNULL(receipt.gl_account_code,'') AS gl_account_code,
		-- dbo.fn_get_receipt_glaccount(Receipt.company_id, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id) AS gl_account_code,
--rb	CASE WHEN receiptPrice.sr_type = 'E' THEN '' ELSE ISNULL((SELECT gl.account_code FROM glaccount gl WHERE gl.account_type = receiptPrice.sr_type AND gl.account_class = 'S' AND gl.profit_ctr_id = @profit_ctr_id),'') END AS gl_sr_account_code,
		--CASE WHEN receiptPrice.sr_type = 'E' THEN ''
		--	ELSE ISNULL((SELECT REPLACE(gl_account_code,'XXX',RIGHT(dbo.fn_get_receipt_glaccount(Receipt.company_id, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id), 3))
		--				FROM Product (nolock)
		--				WHERE product_code = (CASE receiptPrice.sr_type WHEN 'H' THEN 'MITAXHAZ' WHEN 'P' THEN 'MITAXPERP' END)
		--				AND product_type = 'X' 
		--				AND status = 'A' 
		--				AND company_id = receipt.company_id 
		--				AND profit_ctr_id = receipt.profit_ctr_id),'') 
		--	END AS gl_sr_account_code,
		gl_account_type = ISNULL((SELECT waste_type_code FROM wastecode (nolock) WHERE waste_code_uid = receipt.waste_code_uid ),''),
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
		getdate() AS date_added,
		getdate() AS date_modified,
		'SA' AS added_by,
		'SA' AS modified_by,
		ISNULL(receipt.trans_type,''),
		ISNULL(receipt.ref_line_id,0),
		CASE WHEN receipt.trans_type = 'S' 
			 THEN ISNULL(REPLACE(receipt.service_desc,'''', ''),'') 
			 ELSE SUBSTRING(ISNULL(REPLACE(receipt.approval_code,'''', ''),'') + ' ' + ISNULL(REPLACE(Profile.approval_desc,'''', ''),''), 1, 60) 
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
		-- ISNULL(receiptPrice.bundled_tran_gl_account_code,''),
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
			 WHEN NULL IS NOT NULL
			THEN 'Submitted on Hold with no supporting reason.'
		END AS hold_reason,
		CASE WHEN receipt.billing_link_id > 0 OR NULL IS NOT NULL OR ISNULL(receipt.submit_on_hold_flag,'F') = 'T'
			THEN 'SA'
			ELSE NULL
		END AS hold_userid,
		CASE WHEN receipt.billing_link_id > 0 OR NULL IS NOT NULL OR ISNULL(receipt.submit_on_hold_flag,'F') = 'T'
			THEN getdate()
			ELSE NULL
		END AS hold_date,
		NULL,
		NULL,
		NULL,
		receipt.receipt_date AS date_delivered,
		0,
		0,
		receiptPrice.quote_sequence_id,
		(SELECT COUNT(*) FROM ProfileQuoteDetail pqd  (nolock)
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
	FROM
		#InternalFlashWork fw
		INNER JOIN Receipt (nolock)
--rb 04/07/2015 moved to where clause			ON fw.trans_source = 'R' and fw.invoice_flag = 'F' and fw.submitted_flag = 'F'
			on fw.receipt_id = Receipt.receipt_id
			and fw.company_id = Receipt.company_id
			and fw.profit_ctr_id = Receipt.profit_ctr_id
			and fw.line_id = Receipt.line_id
		JOIN ReceiptPrice (nolock) 
			ON receipt.company_id = receiptPrice.company_id
			AND receipt.profit_ctr_id = receiptPrice.profit_ctr_id
			AND receipt.receipt_id = receiptPrice.receipt_id
			AND receipt.line_id = receiptPrice.line_id
			and fw.price_id = receiptPrice.price_id
			AND ISNULL(receiptPrice.print_on_invoice_flag,'F') = 'T'
		JOIN Company  (nolock)
			ON Company.company_id = Receipt.company_id
		LEFT OUTER JOIN CustomerBilling  (nolock)
			ON receipt.customer_id = CustomerBilling.customer_id
			AND receipt.billing_project_id = CustomerBilling.billing_project_id
		LEFT OUTER JOIN Generator  (nolock)
			ON receipt.generator_id = Generator.generator_id
		LEFT OUTER JOIN Profile  (nolock)
			ON receipt.profile_id = Profile.profile_id
	WHERE 1=1 
--rb 04/07/2015
		and fw.trans_source = 'R' 
		and fw.invoice_flag = 'F' 
		and fw.submitted_flag = 'F'
		AND ISNULL(receipt.submitted_flag,'F') = 'F'
		AND (ISNULL(receipt.optional_flag, 'F') = 'F' 
			OR receipt.optional_flag = 'T' AND receipt.apply_charge_flag = 'T')
		AND NOT EXISTS (SELECT 1 FROM Billing (nolock) 
			WHERE receiptPrice.company_id = Billing.company_id
			AND receiptPrice.profit_ctr_id = Billing.profit_ctr_id
			AND receiptPrice.receipt_id = Billing.receipt_id
			AND receiptPrice.line_id = Billing.line_id
			AND receiptPrice.price_id = Billing.price_id
			AND Billing.trans_source = 'R')
				
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting fake submit to get bundled lines, Receipt Population, #Billing done' as status
	set @lasttime = getdate()
	
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting fake submit to get bundled lines, Receipt Population, #BillingDetail done' as status
	set @lasttime = getdate()
	
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting fake submit to get bundled lines, Receipt Population, sp_billing_submit_calc_receipt_charges starting' as status
	set @lasttime = getdate()

	
--#endregion	

--#region receipt billing sp calls
	if isnull(@invoice_flag, '') IN ('N', 'S', 'U')
		EXEC sp_billing_submit_calc_receipt_charges 0 -- @debug_flag
	
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting fake submit to get bundled lines, Receipt Population, sp_billing_submit_calc_receipt_charges done' as status
	set @lasttime = getdate()


	--------------------------------------------------------------------------------------------------------------------
	-- Call out-placed surcharges code 
	-- (Handles insurance surcharge, energy surcharge, and sales tax for Receipts and Work Orders)
	--------------------------------------------------------------------------------------------------------------------
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting fake submit to get surcharge/tax lines for Receipts and Work Orders, sp_billing_submit_calc_surcharges_billingdetail starting' as status
	set @lasttime = getdate()
	
	if isnull(@invoice_flag, '') IN ('N', 'S', 'U')
		EXEC sp_billing_submit_calc_surcharges_billingdetail 0 --@debug_flag
	
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting fake submit to get surcharge/tax lines for Receipts and Work Orders, sp_billing_submit_calc_surcharges_billingdetail done' as status
	set @lasttime = getdate()
	

	-------------------------------------------------------------------------------------------------------------------
	-- Back-populate the insr_extended_amt and ensr_extended_amt fields in Billing for backward compatibility 
	-- until we can remove these fields altogether, and just use BillingDetail.
	-------------------------------------------------------------------------------------------------------------------
	if isnull(@invoice_flag, '') IN ('N', 'S', 'U')
	UPDATE #Billing 
		SET insr_extended_amt = (SELECT SUM(isnull(extended_amt, 0)) 
								FROM #BillingDetail bd 
								WHERE bd.billing_uid = #Billing.billing_uid 
								AND bd.billing_type = 'Insurance'),
			insr_percent = (SELECT MAX(applied_percent)
							FROM #BillingDetail bd 
							WHERE bd.billing_uid = #Billing.billing_uid 
							AND bd.billing_type = 'Insurance')
	
	if isnull(@invoice_flag, '') IN ('N', 'S', 'U')
	UPDATE #Billing 
		SET ensr_extended_amt = (SELECT SUM(isnull(extended_amt,0)) 
								FROM #BillingDetail bd
								WHERE bd.billing_uid = #Billing.billing_uid	
								AND bd.billing_type = 'Energy'),
			ensr_percent = (SELECT MAX(applied_percent)
							FROM #BillingDetail bd 
							WHERE bd.billing_uid = #Billing.billing_uid 
							AND bd.billing_type = 'Energy')
	
		--#endregion	


--#region receipt-billing-clean before insert

		-- Now have to get receipt data back into #InternalFlashWork
	IF exists (select 1 from #tmp_source where trans_source = 'R')
		delete from #InternalFlashWork from #InternalFlashWork fw
		inner join #Billing b
			on fw.receipt_id = b.receipt_id
			and fw.company_id = b.company_id
			and fw.profit_ctr_id = b.profit_ctr_id
			and fw.line_id = b.line_id
			and fw.price_id = b.price_id
			AND fw.trans_source = b.trans_source
		where fw.trans_source = 'R'

--#endregion

--#region receipt billing result insert
	IF exists (select 1 from #tmp_source where trans_source = 'R')
	BEGIN
	
		INSERT #InternalFlashWork (
			company_id					,
			profit_ctr_id				,
			trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
			receipt_id					, -- Receipt/Workorder ID
			trans_type					, -- Receipt trans type (O/I)
			link_flag					,
			linked_record				,
			trans_status				, -- Receipt or Workorder Status
			status_description			, -- Billing/Transaction status description
			trans_date					, -- Receipt Date or Workorder End Date
			pickup_date					, -- Pickup Date
			submitted_flag				, -- Submitted Flag
			date_submitted				, -- Submitted Date
			submitted_by				, -- Submitted by
			billing_status_code			, -- Billing Status Code
			territory_code				, -- Billing Project Territory code
			billing_project_id			, -- Billing project ID
			billing_project_name		, -- Billing Project Name
			invoice_flag				, -- Invoiced? Flag
			invoice_code				, -- Invoice Code (if invoiced)
			invoice_date				, -- Invoice Date (if invoiced)
			invoice_month				, -- Invoice Date month
			invoice_year				, -- Invoice Date year
			customer_id					, -- Customer ID on Receipt/Workorder
			cust_name					, -- Customer Name
			customer_type				, -- Customer Type
			cust_category				, -- Customer Category
			line_id						, -- Receipt line id
			price_id					, -- Receipt line price id
			ref_line_id					, -- Billing reference line_id (which line does this refer to?)
			workorder_sequence_id		, -- Workorder sequence id
			workorder_resource_item		, -- Workorder Resource Item
			workorder_resource_type		, -- Workorder Resource Type
			quantity					, -- Receipt/Workorder Quantity
			billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
			dist_flag					, -- Distributed Transaction?
			dist_company_id				, -- Distribution Company ID (which company receives the revenue)
			dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
			gl_account_code				, -- GL Account for the revenue
			extended_amt				, -- Revenue amt
			generator_id				, -- Generator ID
			generator_name				, -- Generator Name
			epa_id						, -- Generator EPA ID
			treatment_id				, -- Treatment ID
			treatment_desc				, -- Treatment's treatment_desc
			treatment_process_id		, -- Treatment's treatment_process_id
			treatment_process			, -- Treatment's treatment_process (desc)
			disposal_service_id			, -- Treatment's disposal_service_id
			disposal_service_desc		, -- Treatment's disposal_service_desc
			wastetype_id				, -- Treatment's wastetype_id
			wastetype_category			, -- Treatment's wastetype category
			wastetype_description		, -- Treatment's wastetype description
			bill_unit_code				, -- Unit
			waste_code					, -- Waste Code
			profile_id					, -- Profile_id
			quote_id					, -- Quote ID
			product_id					, -- BillingDetail product_id, for id'ing fees, etc.
			product_code				, -- Product Code
			approval_code				, -- Approval Code
			approval_desc				,
			pricing_method				, -- Calculated, Actual, etc.
			quantity_flag				,	-- T = has quantities, F = no quantities, so 0 used.
			JDE_BU						,
			JDE_object					,
			AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
			AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
			AX_Dimension_2				,	-- AX_business_unit
			AX_Dimension_3				,	-- AX_department
			AX_Dimension_4				,	-- AX_line_of_business
			AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
			AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
			AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
			waste_code_uid				,
			reference_code,
			purchase_order				,
			release_code				,	
			ticket_number					-- WorkOrderHeader.ticket_number, if there is a linked WO
			,workorder_startdate		
		)
		SELECT
			b.company_id,
			b.profit_ctr_id,
			b.trans_source,
			b.receipt_id,
			b.trans_type,
			link_flag = (
			select
			isnull(
				(
				select top 1 case link_required_flag when 'E' then 'E' else 'T' end
				from billinglinklookup (nolock)
				where receipt_id = b.receipt_id 
				and company_id = b.company_id
				and profit_ctr_id = b.profit_ctr_id
				ORDER BY isnull(link_required_flag, 'Z')
				)
			, 'F')
			),
			/*
			case when exists (
				select 1 from billinglinklookup (nolock)
				where receipt_id = b.receipt_id 
				and company_id = b.company_id
				and profit_ctr_id = b.profit_ctr_id
				and link_required_flag = 'E'
				) then 'E' 
				else 
					case when exists (
						select 1 from billinglinklookup (nolock)
						where receipt_id = b.receipt_id 
						and company_id = b.company_id
						and profit_ctr_id = b.profit_ctr_id
						and link_required_flag <> 'E'
					) then 'T' else 'F' 
					end 
				end AS link_flag,
			*/
			NULL /* rb 04/13/2015 dbo.fn_get_linked_workorders(b.company_id, b.profit_ctr_id, b.receipt_id)*/ as linked_record, -- Wo's don't list these.  R's do.
			r.receipt_status,
			case when b.status_code = 'I' then 'Invoiced' 
			else 
				CASE r.receipt_status
					WHEN 'L' THEN
						CASE r.fingerpr_status
							WHEN 'A' THEN 'Lab, Accepted'
							WHEN 'H' THEN 'Lab, Hold'
							WHEN 'W' THEN 'Lab, Waiting'
							ELSE 'Unknown Lab Status: ' + r.fingerpr_status
						END
					WHEN 'A' THEN 'Accepted'
					WHEN 'M' THEN 'Manual'
					WHEN 'N' THEN 'New'
					WHEN 'U' THEN 
						CASE r.waste_accepted_flag
							WHEN 'T' THEN 'Waste Accepted'
							ELSE 'Unloading'
						END
					ELSE NULL
				END
			end as status_description,
			r.receipt_date,
				pickup_date = (
					select top 1 _date from
					--coalesce(rt.transporter_sign_date, wospu.date_act_arrive, wohpu.start_date)
					(
						select rt.transporter_sign_date _date
						FROM ReceiptTransporter RT WITH(nolock) 
						WHERE  RT.receipt_id = b.receipt_id 
						and RT.company_id = b.company_id 
						and RT.profit_ctr_id = b.profit_ctr_id
						and RT.transporter_sequence_id = 1
						union
						select coalesce(wospu.date_act_arrive, wohpu.start_date) _date
						FROM BillingLinkLookup bllpu (nolock) 
						LEFT JOIN WorkOrderHeader wohpu (nolock) 
							ON wohpu.company_id = bllpu.source_company_id
							AND wohpu.profit_ctr_id = bllpu.source_profit_ctr_id
							AND wohpu.workorder_id = bllpu.source_id					
						LEFT JOIN workorderstop wospu (nolock)
							ON wohpu.workorder_id = wospu.workorder_id
							and wospu.stop_sequence_id = 1
							and wohpu.company_id = wospu.company_id
							and wohpu.profit_ctr_id = wospu.profit_ctr_id
						WHERE  bllpu.receipt_id = b.receipt_id
						and bllpu.company_id = b.company_id
						and bllpu.profit_ctr_id = b.profit_ctr_id
					) y
					WHERE _date is not null
					order by _date
				),
/*
			pickup_date = (
				select top 1 coalesce(rt.transporter_sign_date, wospu.date_act_arrive, wohpu.start_date)
				FROM Receipt rpu (nolock)
				LEFT OUTER JOIN ReceiptTransporter RT WITH(nolock) 
					ON RT.receipt_id = rpu.receipt_id 
					and RT.company_id = rpu.company_id 
					and RT.profit_ctr_id = rpu.profit_ctr_id
					and RT.transporter_sequence_id = 1
				LEFT OUTER JOIN BillingLinkLookup bllpu (nolock) 
					ON rpu.receipt_id = bllpu.receipt_id
					and rpu.company_id = bllpu.company_id
					and rpu.profit_ctr_id = bllpu.profit_ctr_id
				LEFT JOIN WorkOrderHeader wohpu (nolock) 
					ON wohpu.company_id = bllpu.source_company_id
					AND wohpu.profit_ctr_id = bllpu.source_profit_ctr_id
					AND wohpu.workorder_id = bllpu.source_id					
				LEFT JOIN workorderstop wospu (nolock)
					ON wohpu.workorder_id = wospu.workorder_id
					and wospu.stop_sequence_id = 1
					and wohpu.company_id = wospu.company_id
					and wohpu.profit_ctr_id = wospu.profit_ctr_id
				WHERE
					rpu.receipt_id = b.receipt_id
					and rpu.company_id = b.company_id
					and rpu.profit_ctr_id = b.profit_ctr_id
			),
*/
			r.submitted_flag,
			r.date_submitted,
			r.submitted_by,
			-- DEvOps:14516 - If receipt.submitted_flag is F then set billing status code is null
			case when r.submitted_flag = 'F' then null else b.status_code end as billing_status_code,
			cb.territory_code,
			cb.billing_project_id,
			cb.project_name,
			case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
			b.invoice_code,
			b.invoice_date,
			MONTH(b.invoice_date),
			YEAR(b.invoice_date),
			c.customer_id,
			c.cust_name,
			c.customer_type,
			c.cust_category,
			b.line_id,
			b.price_id,
			b.ref_line_id,
			b.workorder_sequence_id,
			b.workorder_resource_item,
			b.workorder_resource_type,
			b.quantity,
			bd.billing_type,
			-- Modify: GEM-43800: If Product, call it Distributed?
			-- case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end,
			case when exists ( select 1 from profilequotedetail pqd WHERE pqd.profile_id = r.profile_id and pqd.company_id = r.company_id and pqd.profit_ctr_id = r.profit_ctr_id and pqd.bill_method = 'B' ) then 'D' else 
				case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end
			end as dist_flag,
			bd.dist_company_id,
			bd.dist_profit_ctr_id,
			bd.gl_account_code,
			bd.extended_amt,
			g.generator_id,
			g.generator_name,
			g.epa_id,
			t.treatment_id,
			t.treatment_desc,
			t.treatment_process_id,
			t.treatment_process_process,
			t.disposal_service_id,
			t.disposal_service_desc,
			t.wastetype_id,
			t.wastetype_category,
			t.wastetype_description,
			b.bill_unit_code,
			b.waste_code,
			b.profile_id,
			pqa.quote_id,
			r.product_id,
			r.product_code,
			b.approval_code,
			b.service_desc_1, 
			'A' as pricing_method,
			'T' as quantity_flag,
			NULL as JDE_BU, --bd.JDE_BU,
			NULL as JDE_Object, -- bd.JDE_object,
			bd.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
			bd.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
			bd.AX_Dimension_2				,	-- AX_business_unit
			bd.AX_Dimension_3				,	-- AX_department
			bd.AX_Dimension_4				,	-- AX_line_of_business
			bd.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
			bd.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
			bd.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
			b.waste_code_uid,
			NULL as reference_code,
			b.purchase_order				,
			b.release_code					,
			woh.ticket_number
			, woh.start_date
		FROM #Billing b
		INNER JOIN #BillingDetail bd
			ON b.billing_uid = bd.billing_uid
		INNER JOIN Receipt r (nolock)
			ON b.receipt_id = r.receipt_id
			AND b.line_id = r.line_id
			AND b.company_id = r.company_id
			AND b.profit_ctr_id = r.profit_ctr_id
		join @customer c on b.customer_id = c.customer_id
		LEFT OUTER JOIN CustomerBilling cb (nolock)
			ON b.customer_id = cb.customer_id
			AND ISNULL(b.billing_project_id, 0) = cb.billing_project_id
		LEFT OUTER JOIN generator g (nolock)
			ON b.generator_id = g.generator_id
		LEFT OUTER JOIN profilequoteapproval pqa (nolock)
			ON b.profile_id = pqa.profile_id
			AND b.company_id = pqa.company_id
			AND b.profit_ctr_id = pqa.profit_ctr_id
		LEFT OUTER JOIN Treatment t (nolock)
			ON r.treatment_id = t.treatment_id
			AND r.company_id = t.company_id
			AND r.profit_ctr_id = t.profit_ctr_id
		LEFT OUTER JOIN BillingLinkLookup bll (nolock) 
			ON r.receipt_id = bll.receipt_id
			and r.company_id = bll.company_id
			and r.profit_ctr_id = bll.profit_ctr_id
		LEFT JOIN WorkOrderHeader woh (nolock) 
			ON woh.company_id = bll.source_company_id
			AND woh.profit_ctr_id = bll.source_profit_ctr_id
			AND woh.workorder_id = bll.source_id		
		WHERE b.trans_source = 'R'

		-- rb 04/13/2015 moved out of insert statements
--#region receipt linked record update
		update #InternalFlashWork
		set	linked_record = dbo.fn_get_linked_workorders (company_id, profit_ctr_id, receipt_id)
		where trans_source = 'R'
--#endregion

	END
--#endregion
			
	IF @debug_flag > 1 PRINT 'SELECT * FROM #InternalFlashWork'
	IF @debug_flag > 1 SELECT * FROM #InternalFlashWork
	
		-- Don't think we need to delete from this table; all we need to do is add the insurance/energy surcharges back in from #Billing
		---- Now have to get work order data back into #InternalFlashWork
		--DELETE FROM #InternalFlashWork FROM #InternalFlashWork fw
		--INNER JOIN #Billing b
		--	ON fw.receipt_id = b.receipt_id
		--	AND fw.company_id = b.company_id
		--	AND fw.profit_ctr_id = b.profit_ctr_id
		--	AND fw.line_id = b.line_id
		--	AND fw.trans_source = b.trans_source
		--WHERE fw.trans_source = 'W'
		--AND fw.billing_type <> 'WorkOrder'

--#region workorder billing result insert
	IF exists (select 1 from #tmp_source where trans_source = 'W')
		INSERT #InternalFlashWork (
			company_id					,
			profit_ctr_id				,
			trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
			receipt_id					, -- Receipt/Workorder ID
			trans_type					, -- Receipt trans type (O/I)
			link_flag					,
			linked_record				,
			workorder_type				, -- WorkOrderType.account_desc
			trans_status				, -- Receipt or Workorder Status
			status_description			, -- Billing/Transaction status description
			trans_date					, -- Receipt Date or Workorder End Date
			pickup_date					, -- Pickup Date
			submitted_flag				, -- Submitted Flag
			date_submitted				, -- Submitted Date
			submitted_by				, -- Submitted by
			billing_status_code			, -- Billing Status Code
			territory_code				, -- Billing Project Territory code
			billing_project_id			, -- Billing project ID
			billing_project_name		, -- Billing Project Name
			invoice_flag				, -- Invoiced? Flag
			invoice_code				, -- Invoice Code (if invoiced)
			invoice_date				, -- Invoice Date (if invoiced)
			invoice_month				, -- Invoice Date month
			invoice_year				, -- Invoice Date year
			customer_id					, -- Customer ID on Receipt/Workorder
			cust_name					, -- Customer Name
			customer_type				, -- Customer TYpe
			cust_category				, -- Customer Category
			line_id						, -- Receipt line id
			price_id					, -- Receipt line price id
			ref_line_id					, -- Billing reference line_id (which line does this refer to?)
			workorder_sequence_id		, -- Workorder sequence id
			workorder_resource_item		, -- Workorder Resource Item
			workorder_resource_type		, -- Workorder Resource Type
			quantity					, -- Receipt/Workorder Quantity
			billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
			dist_flag					, -- Distributed Transaction?
			dist_company_id				, -- Distribution Company ID (which company receives the revenue)
			dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
			gl_account_code				, -- GL Account for the revenue
			extended_amt				, -- Revenue amt
			generator_id				, -- Generator ID
			generator_name				, -- Generator Name
			epa_id						, -- Generator EPA ID
			treatment_id				, -- Treatment ID
			treatment_desc				, -- Treatment's treatment_desc
			treatment_process_id		, -- Treatment's treatment_process_id
			treatment_process			, -- Treatment's treatment_process (desc)
			disposal_service_id			, -- Treatment's disposal_service_id
			disposal_service_desc		, -- Treatment's disposal_service_desc
			wastetype_id				, -- Treatment's wastetype_id
			wastetype_category			, -- Treatment's wastetype category
			wastetype_description		, -- Treatment's wastetype description
			bill_unit_code				, -- Unit
			waste_code					, -- Waste Code
			profile_id					, -- Profile_id
			quote_id					, -- Quote ID
			product_id					, -- BillingDetail product_id, for id'ing fees, etc.
			product_code				, -- Product Code
			approval_code				, -- Approval Code
			approval_desc				,
			fixed_price_flag			, --	Fixed	Price	Flag
			pricing_method				, -- Calculated, Actual, etc.
			quantity_flag				, -- T = has quantities, F = no quantities, so 0 used.
			JDE_BU						,
			JDE_object					,
			AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
			AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
			AX_Dimension_2				,	-- AX_business_unit
			AX_Dimension_3				,	-- AX_department
			AX_Dimension_4				,	-- AX_line_of_business
			AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
			AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
			AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
			waste_code_uid				,
			reference_code ,
			purchase_order				,
			release_code				,	
			ticket_number					-- WorkOrderHeader.ticket_number
			,workorder_startdate		
		)
		SELECT
			b.company_id,
			b.profit_ctr_id,
			b.trans_source,
			b.receipt_id,
			b.trans_type,
			link_flag = (
			select
			isnull(
				(
				select top 1 case link_required_flag when 'E' then 'E' else 'T' end
				from billinglinklookup (nolock)
				where receipt_id = b.receipt_id 
				and company_id = b.company_id
				and profit_ctr_id = b.profit_ctr_id
				ORDER BY isnull(link_required_flag, 'Z')
				)
			, 'F')
			),
			/*
			case when exists (
				select 1 from billinglinklookup (nolock)
				where source_id = b.receipt_id 
				and source_company_id = b.company_id
				and source_profit_ctr_id = b.profit_ctr_id
				and link_required_flag = 'E'
				) then 'E' 
				else 
					case when exists (
						select 1 from billinglinklookup (nolock)
						where source_id = b.receipt_id 
						and source_company_id = b.company_id
						and source_profit_ctr_id = b.profit_ctr_id
						and link_required_flag <> 'E'
					) then 'T' else 'F' 
					end 
				end AS link_flag,
			*/
			NULL as linked_record, -- Wo's don't list these.  R's do.
			woth.account_desc,
			woh.workorder_status AS trans_status,
			CASE woh.workorder_status
				WHEN 'A' THEN 'Accepted'
				WHEN 'C' THEN 'Completed'
				WHEN 'N' THEN 'New'
			END as status_description,
			woh.end_date AS trans_date,
			COALESCE(wos.date_act_arrive, woh.start_date) as pickup_date,
			woh.submitted_flag,
			woh.date_submitted,
			woh.submitted_by,
			b.status_code as billing_status_code,
			cb.territory_code,
			cb.billing_project_id,
			cb.project_name,
			case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
			b.invoice_code,
			b.invoice_date,
			MONTH(b.invoice_date),
			YEAR(b.invoice_date),
			c.customer_id,
			c.cust_name,
			c.customer_type,
			c.cust_category,
			b.line_id,
			b.price_id,
			b.ref_line_id,
			b.workorder_sequence_id,
			b.workorder_resource_item,
			b.workorder_resource_type,
			b.quantity,
			bd.billing_type,
			case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end,
			bd.dist_company_id,
			bd.dist_profit_ctr_id,
			bd.gl_account_code,
			bd.extended_amt,
			g.generator_id,
			g.generator_name,
			g.epa_id,
			NULL AS treatment_id,
			NULL AS treatment_desc,
			NULL AS treatment_process_id,
			NULL AS treatment_process_process,
			NULL AS disposal_service_id,
			NULL AS disposal_service_desc,
			NULL AS wastetype_id,
			NULL AS wastetype_category,
			NULL AS wastetype_description,
			b.bill_unit_code,
			b.waste_code,
			b.profile_id,
			NULL AS quote_id,
			bd.product_id,
			p.product_code,
			b.approval_code,
			b.service_desc_1, 
			fw.fixed_price_flag,
			'C' as pricing_method,
			fw.quantity_flag as quantity_flag,
			NULL as JDE_BU, --bd.JDE_BU,
			NULL as JDE_Object, -- bd.JDE_object,
			bd.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
			bd.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
			bd.AX_Dimension_2				,	-- AX_business_unit
			bd.AX_Dimension_3				,	-- AX_department
			bd.AX_Dimension_4				,	-- AX_line_of_business
			bd.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
			bd.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
			bd.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
			b.waste_code_uid,
			fw.reference_code,
			b.purchase_order,
			b.release_code,
			woh.ticket_number
			, woh.start_date
		FROM #Billing b (NOLOCK)
		INNER JOIN #BillingDetail bd (NOLOCK)
			ON b.billing_uid = bd.billing_uid
			AND bd.billing_type IN ('Insurance', 'Energy')
		LEFT OUTER JOIN #InternalFlashWork fw (NOLOCK)
			ON fw.company_id = b.company_id
			AND fw.profit_ctr_id = b.profit_ctr_id
			AND fw.trans_source = b.trans_source
			AND fw.receipt_id = b.receipt_id
			AND fw.line_id = b.line_id
		join @customer c on b.customer_id = c.customer_id
		INNER JOIN WorkOrderHeader woh (NOLOCK)
			ON woh.company_id = b.company_id
			AND woh.profit_ctr_id = b.profit_ctr_id
			AND woh.workorder_id = b.receipt_id
		INNER JOIN WorkOrderTypeHeader woth (NOLOCK)
			ON woth.workorder_type_id = woh.workorder_type_id
		LEFT OUTER JOIN CustomerBilling cb (nolock)
			ON b.customer_id = cb.customer_id
			AND ISNULL(b.billing_project_id, 0) = cb.billing_project_id
		LEFT OUTER JOIN generator g (nolock)
			ON b.generator_id = g.generator_id
		LEFT OUTER JOIN Product p (NOLOCK)
			ON p.product_id = bd.product_id
		LEFT JOIN WorkorderStop wos (nolock)
			ON woh.workorder_id = wos.workorder_id
			and wos.stop_sequence_id = 1
			and woh.company_id = wos.company_id
			and woh.profit_ctr_id = wos.profit_ctr_id
		WHERE b.trans_source = 'W'
			
	IF @debug_flag > 1 PRINT 'SELECT * FROM #InternalFlashWork'
	IF @debug_flag > 1 SELECT * FROM #InternalFlashWork

		
--#endregion


--#region commented billingdetail insurance inserts
	/*
	If not in billing
			(Receipt/Workorder work the same way, so they're combined below)
			ENSR
				If not ENSR Exempt on this billing project
					Select ENSR rate for the correct data and multiply it by the billing detail total
					Pricing method = 'C'
			INSR
				If not INSR Exempt on this billing project
					Select INSR rate from company table and multiply it by the billing detail total
					Pricing method = 'C'

	*/

-- These sections below were commented out because the sp_billing_submit_calc_surcharges_billingdetail procedure
-- calculates these insurance and energy surcharges for both receipts and work orders now.
/*
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "Not In Billing, Receipt, ENSR" Population' as status
	set @lasttime = getdate()
	
	-- These only apply to WO records, since the Receipt records got done in an external SP

		INSERT #InternalFlashWork (
			company_id,
			profit_ctr_id,
			trans_source,
			receipt_id,
			line_id,
			price_id,
			trans_type,
			link_flag,
			linked_record,
			trans_status,
			status_description			, -- Billing/Transaction status description
			trans_date,
			pickup_date,
			submitted_flag,
			date_submitted,
			submitted_by,
			territory_code,
			billing_project_id,
			billing_project_name,
			invoice_flag,
			invoice_code,
			invoice_date,
			invoice_month,
			invoice_year,
			customer_id,
			cust_name,
			billing_type,
			dist_flag,
			dist_company_id,
			dist_profit_ctr_id,
			gl_account_code,
			extended_amt,
			generator_id,
			generator_name,
			epa_id,
			product_id,
			product_code,
			fixed_price_flag,
			pricing_method
		)
		SELECT DISTINCT
			f.company_id					,
			f.profit_ctr_id				,
			f.trans_source				,
			f.receipt_id					,
			f.line_id,
			f.price_id,
			f.trans_type					,
			f.link_flag,
			f.linked_record,
			f.trans_status				,
			f.status_description			, -- Billing/Transaction status description
			f.trans_date					,
			f.pickup_date						,
			f.submitted_flag				,
			f.date_submitted,
			f.submitted_by,
			f.territory_code				,
			f.billing_project_id			,
			f.billing_project_name		,
			f.invoice_flag				,
			f.invoice_code				,
			f.invoice_date				,
			f.invoice_month				,
			f.invoice_year				,
			f.customer_id					,
			f.cust_name					,
			'Energy', -- f.billing_type					,
			f.dist_flag,
			f.dist_company_id				,
			f.dist_profit_ctr_id				,
			left(prod.gl_account_code, 9) + right(f.gl_account_code, 3),
	--		prod.gl_account_code				,
			case f.trans_source
				when 'R' then dbo.fn_ensr_amt_receipt_line(f.company_id, f.profit_ctr_id, f.receipt_id, f.line_id, f.price_id)
				when 'W' then
					case when f.workorder_resource_type = 'D' then
						dbo.fn_ensr_amt_wo_line(f.company_id, f.profit_ctr_id, f.receipt_id, f.workorder_resource_type, f.workorder_sequence_id, f.bill_unit_code)
					else 
						0
					end
				else
					0
			end  as extended_amt,		
			f.generator_id,
			f.generator_name,
			f.epa_id,
			prod.product_id,
			prod.product_code,
			f.fixed_price_flag			,
			'C' AS pricing_method
		FROM #InternalFlashWork f
		INNER JOIN Product prod (nolock)
			ON prod.product_type = 'X'
			AND prod.product_code = 'ENSR'
			AND prod.company_id = f.company_id
			AND prod.profit_ctr_id = f.profit_ctr_id
		LEFT OUTER JOIN CustomerBilling (nolock)
			ON f.customer_id = CustomerBilling.customer_id
			AND ISNULL(f.billing_project_id, 0) = CustomerBilling.billing_project_id
		WHERE	
			isnull(f.billing_type, '') NOT IN ('Insurance', 'Energy')
			AND f.invoice_flag = 'F'
			AND (f.submitted_flag = 'F' 
			/*OR (f.submitted_flag = 'T' and not exists (select 1 from billing where receipt_id = f.receipt_id and company_id = f.company_id and profit_ctr_id = f.profit_ctr_id and trans_source = f.trans_source and status_code = 'I'))*/
			)
			AND @invoice_flag IN ('N', 'S', 'U')
			AND f.trans_source <> 'R'
		GROUP BY
			f.company_id					,
			f.profit_ctr_id				,
			f.trans_source				,
			f.receipt_id					,
			f.line_id,
			f.price_id,
			f.trans_type					,
			f.link_flag,
			f.linked_record,
			f.workorder_type				,
			f.trans_status				,
			f.status_description			, -- Billing/Transaction status description
			f.trans_date					,
			f.pickup_date					,
			f.submitted_flag				,
			f.date_submitted,
			f.submitted_by,
			f.billing_status_code			,
			f.territory_code				,
			f.billing_project_id			,
			f.billing_project_name		,
			f.invoice_flag				,
			f.invoice_code				,
			f.invoice_date				,
			f.invoice_month				,
			f.invoice_year				,
			f.customer_id					,
			f.cust_name					,
			f.dist_flag,
			f.dist_company_id				,
			f.dist_profit_ctr_id				,
			left(prod.gl_account_code, 9) + right(f.gl_account_code, 3)				,
			case f.trans_source
				when 'R' then dbo.fn_ensr_amt_receipt_line(f.company_id, f.profit_ctr_id, f.receipt_id, f.line_id, f.price_id)
				when 'W' then
					case when f.workorder_resource_type = 'D' then
						dbo.fn_ensr_amt_wo_line(f.company_id, f.profit_ctr_id, f.receipt_id, f.workorder_resource_type, f.workorder_sequence_id, f.bill_unit_code)
					else 
						0
					end
				else
					0
			end,
			f.generator_id,
			f.generator_name,
			f.epa_id,
			prod.product_id,
			prod.product_code,
			f.fixed_price_flag			
		HAVING 			case f.trans_source
				when 'R' then dbo.fn_ensr_amt_receipt_line(f.company_id, f.profit_ctr_id, f.receipt_id, f.line_id, f.price_id)
				when 'W' then
					case when f.workorder_resource_type = 'D' then
						dbo.fn_ensr_amt_wo_line(f.company_id, f.profit_ctr_id, f.receipt_id, f.workorder_resource_type, f.workorder_sequence_id, f.bill_unit_code)
					else 
						0
					end
				else
					0
			end
		 > 0

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "Not In Billing, Receipt, ENSR" Population' as status
	set @lasttime = getdate()
	
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "Not In Billing, Receipt, INSR" Population' as status
	set @lasttime = getdate()
	
	-- These only apply to WO records, since the Receipt records got done in an external SP

		INSERT #InternalFlashWork (
			company_id,
			profit_ctr_id,
			trans_source,
			receipt_id,
			line_id,
			price_id,
			trans_type,
			link_flag,
			linked_record,
			trans_status,
			status_description			, -- Billing/Transaction status description
			trans_date,
			pickup_date,
			submitted_flag,
			date_submitted,
			submitted_by,
			territory_code,
			billing_project_id,
			billing_project_name,
			invoice_flag,
			invoice_code,
			invoice_date,
			invoice_month,
			invoice_year,
			customer_id,
			cust_name,
			billing_type,
			dist_flag,
			dist_company_id,
			dist_profit_ctr_id,
			gl_account_code,
			extended_amt,
			generator_id,
			generator_name,
			epa_id,
			product_id,
			product_code,
			fixed_price_flag,
			pricing_method
		)
		SELECT DISTINCT
			f.company_id					,
			f.profit_ctr_id				,
			f.trans_source				,
			f.receipt_id					,
			f.line_id,
			f.price_id,
			f.trans_type					,
			f.link_flag,
			f.linked_record,
			f.trans_status				,
			f.status_description			, -- Billing/Transaction status description
			f.trans_date					,
			f.pickup_date					,
			f.submitted_flag				,
			f.date_submitted,
			f.submitted_by,
			f.territory_code				,
			f.billing_project_id			,
			f.billing_project_name		,
			f.invoice_flag,
			f.invoice_code				,
			f.invoice_date				,
			f.invoice_month				,
			f.invoice_year				,
			f.customer_id					,
			f.cust_name					,
			'Insurance', -- f.billing_type					,
			f.dist_flag,
			f.dist_company_id				,
			f.dist_profit_ctr_id				,
			left(prod.gl_account_code, 9) + right(f.gl_account_code, 3)	,
			case f.trans_source
				when 'R' then dbo.fn_insr_amt_receipt_line(f.company_id, f.profit_ctr_id, f.receipt_id, f.line_id, f.price_id)
				when 'W' then
					case when f.fixed_price_flag = 'T' then
						dbo.fn_insr_amt_wo(f.receipt_id, f.company_id, f.profit_ctr_id)
					else
						case when f.workorder_resource_type = 'D' then
							dbo.fn_insr_amt_wo_line(f.company_id, f.profit_ctr_id, f.receipt_id, f.workorder_resource_type, f.workorder_sequence_id, f.bill_unit_code)
						else 
							0
						end
					end
				else
					0
			end  as extended_amt,		
			f.generator_id,
			f.generator_name,
			f.epa_id,
			prod.product_id,
			prod.product_code,
			f.fixed_price_flag			,
			'C' AS pricing_method
		FROM #InternalFlashWork f
		INNER JOIN Company c (nolock)
			ON f.company_id = c.company_id
		INNER JOIN Product prod (nolock)
			ON prod.product_type = 'X'
			AND prod.product_code = 'INSR'
			AND prod.company_id = f.company_id
			AND prod.profit_ctr_id = f.profit_ctr_id
		LEFT OUTER JOIN CustomerBilling (nolock)
			ON f.customer_id = CustomerBilling.customer_id
			AND ISNULL(f.billing_project_id, 0) = CustomerBilling.billing_project_id
		WHERE	
			isnull(f.billing_type, '') NOT IN ('Insurance', 'Energy')
			AND f.invoice_flag = 'F'
			AND (f.submitted_flag = 'F' /* OR (f.submitted_flag = 'T' and not exists (select 1 from billing where receipt_id = f.receipt_id and company_id = f.company_id and profit_ctr_id = f.profit_ctr_id and trans_source = f.trans_source and status_code = 'I'))
 */ )
			AND @invoice_flag IN ('N', 'S', 'U')
			AND f.trans_source <> 'R'
		GROUP BY
			f.company_id					,
			f.profit_ctr_id				,
			f.trans_source				,
			f.receipt_id					,
			f.line_id,
			f.price_id,
			f.trans_type					,
			f.link_flag,
			f.linked_record,
			f.workorder_type				,
			f.trans_status				,
			f.status_description			, -- Billing/Transaction status description
			f.trans_date					,
			f.pickup_date					,
			f.submitted_flag				,
			f.date_submitted,
			f.submitted_by,
			f.billing_status_code			,
			f.territory_code				,
			f.billing_project_id			,
			f.billing_project_name		,
			f.invoice_flag,
			f.invoice_code				,
			f.invoice_date				,
			f.invoice_month				,
			f.invoice_year				,
			f.customer_id					,
			f.cust_name					,
			f.dist_flag,
			f.dist_company_id				,
			f.dist_profit_ctr_id				,
			left(prod.gl_account_code, 9) + right(f.gl_account_code, 3)	,
			case f.trans_source
				when 'R' then dbo.fn_insr_amt_receipt_line(f.company_id, f.profit_ctr_id, f.receipt_id, f.line_id, f.price_id)
				when 'W' then
					case when f.fixed_price_flag = 'T' then
						dbo.fn_insr_amt_wo(f.receipt_id, f.company_id, f.profit_ctr_id)
					else
						case when f.workorder_resource_type = 'D' then
							dbo.fn_insr_amt_wo_line(f.company_id, f.profit_ctr_id, f.receipt_id, f.workorder_resource_type, f.workorder_sequence_id, f.bill_unit_code)
						else 
							0
						end
					end
				else
					0
			end,
 			f.generator_id,
			f.generator_name,
			f.epa_id,
			prod.product_id,
			prod.product_code,
			f.fixed_price_flag			
		HAVING			case f.trans_source
				when 'R' then dbo.fn_insr_amt_receipt_line(f.company_id, f.profit_ctr_id, f.receipt_id, f.line_id, f.price_id)
				when 'W' then
					case when f.fixed_price_flag = 'T' then
						dbo.fn_insr_amt_wo(f.receipt_id, f.company_id, f.profit_ctr_id)
					else
						case when f.workorder_resource_type = 'D' then
							dbo.fn_insr_amt_wo_line(f.company_id, f.profit_ctr_id, f.receipt_id, f.workorder_resource_type, f.workorder_sequence_id, f.bill_unit_code)
						else 
							0
						end
					end
				else
					0
			end > 0
			
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "Not In Billing, Receipt, INSR" Population' as status
	set @lasttime = getdate()
	
*/

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "Not In Billing, Orders" Population' as status
	set @lasttime = getdate()
	
--#endregion	
	
--#region order non-invoiced insert
	-- Orders
	IF exists (select 1 from #tmp_source where trans_source = 'O')
		AND @invoice_flag IN ('N', 'U') -- Non-Billing source, and submitted_flag = 'F' below, so this is Not invoiced or Unsubmitted
	INSERT #InternalFlashWork (
		company_id					,
		profit_ctr_id				,
		trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
		receipt_id					, -- Receipt/Workorder ID
		trans_type					, -- Receipt trans type (O/I)
		trans_status				, -- Receipt or Workorder Status
		status_description			, -- Billing/Transaction status description
		trans_date					, -- Receipt Date or Workorder End Date
		pickup_date					, -- Pickup Date
		submitted_flag				, -- Submitted Flag
		date_submitted				, -- Submitted Date
		submitted_by				, -- Submitted by
		billing_status_code			, -- Billing Status Code
		territory_code				, -- Billing Project Territory code
		billing_project_id			, -- Billing project ID
		billing_project_name		, -- Billing Project Name
		invoice_flag				, -- Invoiced? Flag
		invoice_code				, -- Invoice Code (if invoiced)
		invoice_date				, -- Invoice Date (if invoiced)
		invoice_month				, -- Invoice Date month
		invoice_year				, -- Invoice Date year
		customer_id					, -- Customer ID on Receipt/Workorder
		cust_name					, -- Customer Name
		customer_type				, -- Customer Type
		cust_category				, -- Customer Category
		line_id						, -- Receipt line id
		price_id					, -- Receipt line price id
		ref_line_id					, -- Billing reference line_id (which line does this refer to?)
		workorder_sequence_id		, -- Workorder sequence id
		workorder_resource_item		, -- Workorder Resource Item
		workorder_resource_type		, -- Workorder Resource Type
		quantity					, -- Receipt/Workorder Quantity
		billing_type					, -- 'Energy', 'Insurance', 'Salestax' etc.
		dist_flag					, -- Distributed Transaction?
		dist_company_id				, -- Distribution Company ID (which company receives the revenue)
		dist_profit_ctr_id				, -- Distribution Profit Ctr ID (which profitcenter receives the revenue)
		gl_account_code				, -- GL Account for the revenue
		extended_amt				, -- Revenue amt
		generator_id				, -- Generator ID
		generator_name				, -- Generator Name
		epa_id						, -- Generator EPA ID
		bill_unit_code				, -- Unit
		waste_code					, -- Waste Code
		profile_id					, -- Profile_id
		quote_id					, -- Quote ID
		product_id					, -- BillingDetail product_id, for id'ing fees, etc.
		product_code				, -- Product Code
		approval_code				, -- Approval Code
		approval_desc				,
		pricing_method				, -- Calculated, Actual, etc.
		quantity_flag				,	-- T = has quantities, F = no quantities, so 0 used.
		JDE_BU						,
		JDE_object					,
		AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
		AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
		AX_Dimension_2				,	-- AX_business_unit
		AX_Dimension_3				,	-- AX_department
		AX_Dimension_4				,	-- AX_line_of_business
		AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
		AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
		AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
		waste_code_uid				,
		reference_code,
		purchase_order				,
		release_code
	)
	SELECT
		od.company_id,
		od.profit_ctr_id,
		'O',
		oh.order_id,
		NULL,
		oh.status,
		case oh.status
			WHEN 'P' then 'Processed'
			WHEN 'V' then 'Void'
			WHEN 'N' then 'New'
		end as status_description,
		oh.order_date,
		NULL as pickup_date,
		oh.submitted_flag,
		oh.date_submitted,
		oh.submitted_by,
		NULL, -- billing_status_code,
		cb.territory_code,
		cb.billing_project_id,
		cb.project_name,
		'F' as invoice_flag,
		NULL as invoice_code,
		NULL as invoice_date,
		NULL, -- MONTH(b.invoice_date),
		NULL, -- YEAR(b.invoice_date),
		c.customer_id,
		c.cust_name,
		c.customer_type,
		c.cust_category,
		od.line_id,
		NULL, -- b.price_id,
		NULL, -- b.ref_line_id,
		NULL, -- b.workorder_sequence_id,
		NULL, -- b.workorder_resource_item,
		NULL, -- b.workorder_resource_type,
		od.quantity,
		'Product' as billing_type,
		'N' as dist_flag,
		od.company_id,
		od.profit_ctr_id,
		prod.gl_account_code,
		od.extended_amt,
		g.generator_id,
		g.generator_name,
		g.epa_id,
		NULL, -- b.bill_unit_code,
		NULL, -- b.waste_code,
		NULL, -- b.profile_id,
		NULL, -- pqa.quote_id,
		od.product_id,
		prod.product_code,
		NULL, -- b.approval_code,
		NULL, -- b.service_desc_1, 
		'A' as pricing_method,
		'T' as quantity_flag,
		NULL as JDE_BU, --prod.JDE_BU,
		NULL as JDE_Object, -- prod.JDE_object,
		prod.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
		prod.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
		prod.AX_Dimension_2				,	-- AX_business_unit
		prod.AX_Dimension_3				,	-- AX_department
		prod.AX_Dimension_4				,	-- AX_line_of_business
		prod.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
		prod.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
		prod.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
		NULL as waste_code_uid,
		NULL as reference_code,
		oh.purchase_order				,
		oh.release_code
	FROM OrderHeader oh (nolock)
	join @customer c on oh.customer_id = c.customer_id
	INNER JOIN OrderDetail od (nolock)
		on oh.order_id = od.order_id
	--rb 04/08/2015
	--INNER JOIN #tmp_source ts
	--	ON 'O' = ts.trans_source
	INNER JOIN #tmp_trans_copc copc
		ON od.company_id = copc.company_id
		AND od.profit_ctr_id = copc.profit_ctr_id
	INNER JOIN product prod (nolock)
		on od.product_id = prod.product_id
		and od.company_id = prod.company_id
		and od.profit_ctr_id = prod.profit_ctr_id
	left outer JOIN  generator g (nolock)
		ON oh.generator_id = g.generator_id
	left outer JOIN CustomerBilling cb (nolock)
		ON oh.customer_id = cb.customer_id
		AND ISNULL(oh.billing_project_id, 0) = cb.billing_project_id
	WHERE 1=1
		AND (
		oh.submitted_flag = 'F' 
		/* OR (oh.submitted_flag = 'T' and not exists (select 1 from billing where receipt_id = oh.order_id and company_id = od.company_id and profit_ctr_id = od.profit_ctr_id and trans_source = 'O' and status_code = 'I')) */ 
		)
		and oh.status <> 'V'
		AND oh.order_date BETWEEN @date_from AND @date_to -- ??? start_date or end_date?
		-- AND oh.customer_id BETWEEN @cust_id_from AND @cust_id_to
		AND @invoice_flag IN ('N', 'S', 'U')
		
		
	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "Not In Billing, Orders" Population' as status
	set @lasttime = getdate()
	
--#endregion	


-- END -- end of invoiced vs not-invoiced 
--#region flag and misc updates

update #InternalFlashWork set quantity_flag = 'F' where quantity_flag is null
update #InternalFlashWork set link_flag = 'F' where link_flag is null
update #InternalFlashWork 
	set gl_native_code = left(gl_account_code, 5), 
		gl_dept_code = right(gl_account_code, 3) 
where gl_account_code is not null

update #InternalFlashWork set invoice_flag = 'F' where invoice_code is null

---------------------------------------------------------
-- Assign Job Type: Base/Event.
update #InternalFlashWork set job_type = 'B' -- Default	

/* Update Job type to Event on event jobs.  defaulted to "B" since there were so many
null and blank values, retail stays Base */
update #InternalFlashWork set
	job_type = 'E'
from #InternalFlashWork
INNER JOIN profilequoteheader pqh
	ON #InternalFlashWork.quote_id = pqh.quote_id
where pqh.job_type  = 'E' 
and #InternalFlashWork.trans_source = 'R'

update #InternalFlashWork set
	job_type = 'E'
from #InternalFlashWork tw
inner join workorderquoteheader qh
	on tw.quote_id = qh.quote_id
	and tw.company_id = qh.company_id
	and qh.job_type  = 'E' 
where 1=1
And tw.trans_type = 'O'
and tw.trans_source = 'W'

--#endregion

--#region filter for un/submitted search
	-- Handle filter types of Submitted or Unsubmitted:
		IF @invoice_flag = 'U'
		DELETE #InternalFlashWork where isnull(submitted_flag, 'F') = 'T'

		IF @invoice_flag = 'S'
		DELETE #InternalFlashWork where isnull(submitted_flag, 'F') = 'F'
--#endregion

--#region native transactionfilter

		-- Handle @transaction_type before @copc_search_type
		-- Oh, according to LT: Show just the split lines, not the whole receipt for a split line.
		IF @transaction_type = 'N' BEGIN
			insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '@transaction_type = N: Removing records with split lines.' as status
			set @lasttime = getdate()
			
			-- explained: delete from #InternalFlashWork where dist & company_id don't match each other.
			-- What's left are only rows where dist & company DO match.
			DELETE FROM #InternalFlashWork
			FROM #InternalFlashWork f
			where not(
				isnull(dist_company_id, company_id) = company_id
				and isnull(dist_profit_ctr_id, profit_ctr_id) = profit_ctr_id
			)
			insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished @transaction_type = N: Removing records with split lines.' as status
			set @lasttime = getdate()
			
		END

--#endregion

--#region split transaction filter
		IF @transaction_type = 'S' BEGIN
			insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '@transaction_type = S: Removing records without split lines.' as status
			set @lasttime = getdate()
			
			DELETE FROM #InternalFlashWork
			FROM #InternalFlashWork f
			where (
				isnull(dist_company_id, company_id) = company_id
				and isnull(dist_profit_ctr_id, profit_ctr_id) = profit_ctr_id
			)
			insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished @transaction_type = S: Removing records without split lines.' as status
			set @lasttime = getdate()
			
		END
	
--#endregion	

--#region filter on dist co/pc logic
		-- if user specified to search copc's among Distribution fields, it's time to filter that.
		IF @copc_search_type = 'D' BEGIN
			insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '@copc_search_type = D: filtering on split facilities after populating with all facilities.' as status
			set @lasttime = getdate()
			
			-- If the @copc_list input was 'ALL', well that's what we already have from above. Nothing to do here.
			IF LTRIM(RTRIM(ISNULL(@copc_list, ''))) <> 'ALL' BEGIN
				-- But if it was a specific list, we have to reset #tmp_trans_copc to handle it.
				Truncate table #tmp_trans_copc -- clear out the old list.

				INSERT #tmp_trans_copc -- refill it.
				SELECT Profitcenter.company_id, Profitcenter.profit_ctr_id, Profitcenter.base_rate_quote_id
				FROM ProfitCenter (nolock)
				INNER JOIN (
					SELECT
						RTRIM(LTRIM(SUBSTRING(ROW, 1, CHARINDEX('|',ROW) - 1))) company_id,
						RTRIM(LTRIM(SUBSTRING(ROW, CHARINDEX('|',ROW) + 1, LEN(ROW) - (CHARINDEX('|',ROW)-1)))) profit_ctr_id
					FROM dbo.fn_SplitXsvText(',', 0, @copc_list)
					WHERE ISNULL(ROW, '') <> '') selected_copc ON
						ProfitCenter.company_id = selected_copc.company_id
						AND ProfitCenter.profit_ctr_id = selected_copc.profit_ctr_id
				WHERE ProfitCenter.status = 'A'

			insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#tmp_trans_copc repopulated' as status
			set @lasttime = getdate()

			END
			-- Now #tmp_trans_copc is ready to use again.  Apply it to the dist_company_id and dist_profit_ctr_id fields in #InternalFlashWork
/*
			delete from #InternalFlashWork where not exists (
				select 1 from #tmp_trans_copc where company_id = #InternalFlashWork.dist_company_id and profit_ctr_id = #InternalFlashWork.dist_profit_ctr_id
			)
			insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished @copc_search_type = D: filtering on split facilities after populating with all facilities.' as status
			set @lasttime = getdate()
			
*/
		END

--#endregion

--#region set first invoice date field
-- Set first_invoice_date
	drop table if exists #invoicestats

	select min(ih.invoice_date) first_invoice_date, max(ih.invoice_date) last_invoice_date,
	f.company_id, f.profit_ctr_id, f.receipt_id
	into #invoicestats
	from #InternalFlashWork f
	join InvoiceDetail id
		on f.company_id = id.company_id
		and f.profit_ctr_id = id.profit_ctr_id
		and f.receipt_id = id.receipt_id
		and f.trans_source = id.trans_source
	join InvoiceHeader ih
		on id.invoice_id = ih.invoice_id
		and id.revision_id = ih.revision_id
		and ih.status in ('I', 'O', 'V') -- Invoiced, Obsolete or Void only
	group by 
	f.company_id, f.profit_ctr_id, f.receipt_id

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#invoicestats populated' as status
	set @lasttime = getdate()

	update #InternalFlashWork
	set first_invoice_date = invs.first_invoice_date
	from #InternalFlashWork fw
	inner join #invoicestats invs
		on fw.receipt_id = invs.receipt_id
		and fw.company_id = invs.company_id
		and fw.profit_ctr_id = invs.profit_ctr_id

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#internalFlashwork table updated from #internalFlashWork and #Invoicestats' as status
	set @lasttime = getdate()

--#endregion
--#region station filter, deprecated
	------------------------------------------------------------------------------------
	-- 11/18/2014 JDB
	-- We don't need to do this any longer, since we are not using station ID to hold
	-- the reference code (job code).
	------------------------------------------------------------------------------------
	---- We stuffed station_id above with wos stop sequence 1. There may be more. Those need to use the function for station_id list.
	--if exists (
	--	select 1 from #InternalFlashWork f
	--	inner join (
	--		select workorder_id, company_id, profit_ctr_id, COUNT(stop_sequence_id) stop_count
	--		from WorkorderStop
	--		group by workorder_id, company_id, profit_ctr_id
	--		having COUNT(stop_sequence_id) > 1
	--	) x on f.receipt_id = x.workorder_id
	--		and f.company_id = x.company_id
	--		and f.profit_ctr_id = x.profit_ctr_id
	--		and f.trans_source = 'W'
	--) begin
	--	update #InternalFlashWork
	--		set station_id = dbo.fn_get_workorder_station_id_list(f.company_id, f.profit_ctr_id, f.receipt_id, 'W')
	--	from #InternalFlashWork f
	--	inner join (
	--		select workorder_id, company_id, profit_ctr_id, COUNT(stop_sequence_id) stop_count
	--		from WorkorderStop
	--		group by workorder_id, company_id, profit_ctr_id
	--		having COUNT(stop_sequence_id) > 1
	--	) x on f.receipt_id = x.workorder_id
	--		and f.company_id = x.company_id
	--		and f.profit_ctr_id = x.profit_ctr_id
	--		and f.trans_source = 'W'
	--end
--#endregion

SP_End:

SET NOCOUNT OFF

-- Now put #InternalFlashWork into #Flashwork

Insert #FlashWork (

	--	Header info:
		company_id					
		,profit_ctr_id				
		,trans_source				
		,receipt_id					
		,trans_type					
		,link_flag					
		,linked_record				
		,workorder_type				
		,trans_status				
		,status_description			
		,trans_date					
		,pickup_date					
		,submitted_flag				
		,date_submitted				
		,submitted_by				
		,billing_status_code			
		,territory_code				
		,billing_project_id			
		,billing_project_name		
		,invoice_flag				
		,invoice_code				
		,invoice_date				
		,invoice_month				
		,invoice_year				
		,customer_id					
		,cust_name					
		,customer_type				
		, cust_category

	--	Detail info:
		,line_id						
		,price_id					
		,ref_line_id					
		,workorder_sequence_id		
		,workorder_resource_item		
		,workorder_resource_type		
		,Workorder_resource_category	
		,quantity					
		,billing_type				
		,dist_flag					
		,dist_company_id				
		,dist_profit_ctr_id			
		,gl_account_code				
		,gl_native_code				
		,gl_dept_code				
		,extended_amt				
		,generator_id				
		,generator_name				
		,epa_id						
		,treatment_id				
		,treatment_desc				
		,treatment_process_id		
		,treatment_process			
		,disposal_service_id			
		,disposal_service_desc		
		,wastetype_id				
		,wastetype_category			
		,wastetype_description		
		,bill_unit_code				
		,waste_code					
		,profile_id					
		,quote_id					
		,product_id					
		,product_code				
		,approval_code				
		,approval_desc				
		,TSDF_code					
		,TSDF_EQ_FLAG				
		,fixed_price_flag			
		,pricing_method				
		,quantity_flag				
		,JDE_BU						
		,JDE_object					

		,AX_MainAccount				
		,AX_Dimension_1				
		,AX_Dimension_2				
		,AX_Dimension_3				
		,AX_Dimension_4				
		,AX_Dimension_5_Part_1		
		,AX_Dimension_5_Part_2		
		,AX_Dimension_6				
		
		,first_invoice_date			
		
		,waste_code_uid				
		,reference_code              
		,job_type					
		,purchase_order				
		,release_code				
		,ticket_number				
	)
	SELECT
	--	Header info:
		company_id					
		,profit_ctr_id				
		,trans_source				
		,receipt_id					
		,trans_type					
		,link_flag					
		,linked_record				
		,workorder_type				
		,trans_status				
		,status_description			
		,trans_date					
		,pickup_date					
		,submitted_flag				
		,date_submitted				
		,submitted_by				
		,billing_status_code			
		,territory_code				
		,billing_project_id			
		,billing_project_name		
		,invoice_flag				
		,invoice_code				
		,invoice_date				
		,invoice_month				
		,invoice_year				
		,customer_id					
		,cust_name					
		,customer_type				
		, cust_category

	--	Detail info:
		,line_id						
		,price_id					
		,ref_line_id					
		,workorder_sequence_id		
		,workorder_resource_item		
		,workorder_resource_type		
		,Workorder_resource_category	
		,quantity					
		,billing_type				
		,dist_flag					
		,dist_company_id				
		,dist_profit_ctr_id			
		,gl_account_code				
		,gl_native_code				
		,gl_dept_code				
		,extended_amt				
		,generator_id				
		,generator_name				
		,epa_id						
		,treatment_id				
		,treatment_desc				
		,treatment_process_id		
		,treatment_process			
		,disposal_service_id			
		,disposal_service_desc		
		,wastetype_id				
		,wastetype_category			
		,wastetype_description		
		,bill_unit_code				
		,waste_code					
		,profile_id					
		,quote_id					
		,product_id					
		,product_code				
		,approval_code				
		,approval_desc				
		,TSDF_code					
		,TSDF_EQ_FLAG				
		,fixed_price_flag			
		,pricing_method				
		,quantity_flag				
		,JDE_BU						
		,JDE_object					

		,AX_MainAccount				
		,AX_Dimension_1				
		,AX_Dimension_2				
		,AX_Dimension_3				
		,AX_Dimension_4				
		,AX_Dimension_5_Part_1		
		,AX_Dimension_5_Part_2		
		,AX_Dimension_6				
		
		,first_invoice_date			
		
		,waste_code_uid				
		,reference_code              
		,job_type					
		,purchase_order				
		,release_code				
		,ticket_number				
FROM #InternalFlashWork		

insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#flashwork populated' as status
set @lasttime = getdate()

--  Now populate ExtendedFlashWork, if it exists
if object_id('tempdb..#ExtendedFlashWork') is not null begin

	Insert #ExtendedFlashWork (

		--	Header info:
			company_id					
			,profit_ctr_id				
			,trans_source				
			,receipt_id					
			,trans_type					
			,link_flag					
			,linked_record				
			,workorder_type				
			,trans_status				
			,status_description			
			,trans_date					
			,pickup_date					
			,submitted_flag				
			,date_submitted				
			,submitted_by				
			,billing_status_code			
			,territory_code				
			,billing_project_id			
			,billing_project_name		
			,invoice_flag				
			,invoice_code				
			,invoice_date				
			,invoice_month				
			,invoice_year				
			,customer_id					
			,cust_name					
			,customer_type				
			, cust_category

		--	Detail info:
			,line_id						
			,price_id					
			,ref_line_id					
			,workorder_sequence_id		
			,workorder_resource_item		
			,workorder_resource_type		
			,Workorder_resource_category	
			,quantity					
			,billing_type				
			,dist_flag					
			,dist_company_id				
			,dist_profit_ctr_id			
			,gl_account_code				
			,gl_native_code				
			,gl_dept_code				
			,extended_amt				
			,generator_id				
			,generator_name				
			,epa_id						
			,treatment_id				
			,treatment_desc				
			,treatment_process_id		
			,treatment_process			
			,disposal_service_id			
			,disposal_service_desc		
			,wastetype_id				
			,wastetype_category			
			,wastetype_description		
			,bill_unit_code				
			,waste_code					
			,profile_id					
			,quote_id					
			,product_id					
			,product_code				
			,approval_code				
			,approval_desc				
			,TSDF_code					
			,TSDF_EQ_FLAG				
			,fixed_price_flag			
			,pricing_method				
			,quantity_flag				
			,JDE_BU						
			,JDE_object					

			,AX_MainAccount				
			,AX_Dimension_1				
			,AX_Dimension_2				
			,AX_Dimension_3				
			,AX_Dimension_4				
			,AX_Dimension_5_Part_1		
			,AX_Dimension_5_Part_2		
			,AX_Dimension_6				
			
			,first_invoice_date			
			
			,waste_code_uid				
			,reference_code              
			,job_type					
			,purchase_order				
			,release_code				
			,ticket_number				
			,billing_uid
			,billing_date
			,workorder_startdate
		)
		SELECT
		--	Header info:
			company_id					
			,profit_ctr_id				
			,trans_source				
			,receipt_id					
			,trans_type					
			,link_flag					
			,linked_record				
			,workorder_type				
			,trans_status				
			,status_description			
			,trans_date					
			,pickup_date					
			,submitted_flag				
			,date_submitted				
			,submitted_by				
			,billing_status_code			
			,territory_code				
			,billing_project_id			
			,billing_project_name		
			,invoice_flag				
			,invoice_code				
			,invoice_date				
			,invoice_month				
			,invoice_year				
			,customer_id					
			,cust_name					
			,customer_type				
			, cust_category

		--	Detail info:
			,line_id						
			,price_id					
			,ref_line_id					
			,workorder_sequence_id		
			,workorder_resource_item		
			,workorder_resource_type		
			,Workorder_resource_category	
			,quantity					
			,billing_type				
			,dist_flag					
			,dist_company_id				
			,dist_profit_ctr_id			
			,gl_account_code				
			,gl_native_code				
			,gl_dept_code				
			,extended_amt				
			,generator_id				
			,generator_name				
			,epa_id						
			,treatment_id				
			,treatment_desc				
			,treatment_process_id		
			,treatment_process			
			,disposal_service_id			
			,disposal_service_desc		
			,wastetype_id				
			,wastetype_category			
			,wastetype_description		
			,bill_unit_code				
			,waste_code					
			,profile_id					
			,quote_id					
			,product_id					
			,product_code				
			,approval_code				
			,approval_desc				
			,TSDF_code					
			,TSDF_EQ_FLAG				
			,fixed_price_flag			
			,pricing_method				
			,quantity_flag				
			,JDE_BU						
			,JDE_object					

			,AX_MainAccount				
			,AX_Dimension_1				
			,AX_Dimension_2				
			,AX_Dimension_3				
			,AX_Dimension_4				
			,AX_Dimension_5_Part_1		
			,AX_Dimension_5_Part_2		
			,AX_Dimension_6				
			
			,first_invoice_date			
			
			,waste_code_uid				
			,reference_code              
			,job_type					
			,purchase_order				
			,release_code				
			,ticket_number				
			,billing_uid
			,billing_date
			,workorder_startdate
	FROM #InternalFlashWork		

	insert @debuglog  select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#ExtendedFlashwork populated' as status
	set @lasttime = getdate()

end

if @debug_flag > 0 select '[sp_rpt_flash_calc]' as SP, * from @debuglog order by time_now

	


GO
GRANT Execute on sp_rpt_flash_calc to EQWEB, COR_USER


GRANT EXECUTE
    ON [sp_rpt_flash_calc] TO [EQWEB]
GO
GRANT EXECUTE
    ON [sp_rpt_flash_calc] TO [COR_USER]
GO
GRANT EXECUTE
    ON [sp_rpt_flash_calc] TO [EQAI]

