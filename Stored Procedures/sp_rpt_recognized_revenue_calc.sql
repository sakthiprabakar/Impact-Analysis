
CREATE PROCEDURE sp_rpt_recognized_revenue_calc
	@copc_list				VARCHAR(MAX),
	@date_from				DATETIME = NULL,
	@date_to				DATETIME = NULL,
	@cust_id_from			INT,
	@cust_id_to				INT,
--	@cust_type_list			varchar(max) = '',
--	@invoice_flag			VARCHAR(MAX),  /* 'I'nvoiced, 'N'ot invoiced. */
--	@source_list			VARCHAR(MAX),  /* 'R'eceipt, 'W'orkorder */
--	@copc_search_type		char(1) = 'T', /* 'T'ransaction facility (native, default) or 'D'istribution facility */
--	@transaction_type		char(1) = 'A', /* 'A'll, 'N'ative only (or Not split), 'S'plit between facilities only */
	@debug_flag				INT = 0
AS
/*********************************************************************************************
sp_rpt_recognized_revenue_calc

IMPORTANT:
	Changes to sp_billing_submit affect this stored procedure - this has to be updated too!
	Changes to sp_billing_submit_calc_receipt_charges affect this stored procedure - this has to be changed too!
	Changes to sp_billing_submit_calc_surcharges_billingdetail affect this stored procedure - this has to be changed too!
	
	Changes to sp_flash_calc affect sp_report_eqip_flash_detail.
	
	It's a whole big, "Circle of life" thing.

History:
	03/11/2015 JPB	Created as a copy of sp_rpt_flash_calc
	07/14/2017 JPB	Added Discount Amount field to #BillingDetail
	02/15/2018 MPM	Added currency_code column to #Billing and #BillingDetail
	07/08/2024 KS	Rally116985 - Modified service_desc_1 and service_desc_2 datatype to VARCHAR(100) for #Billing table.


--# Required Input/Output temp table #RevenueWork

DROP TABLE #RevenueWork
CREATE TABLE #RevenueWork (

	--	Header info:
		company_id					int			NULL,
		profit_ctr_id				int			NULL,
		trans_source				char(2)		NULL,	--	Receipt,	Workorder,	Workorder-Receipt,	etc
		receipt_id					int			NULL,	--	Receipt/Workorder	ID
		trans_type					char(1)		NULL,	--	Receipt	trans	type	(O/I)
		billing_project_id			int			NULL,	--	Billing	project	ID
		customer_id					int			NULL,	--	Customer	ID	on	Receipt/Workorder

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
		extended_amt				float			NULL,	--	Revenue	amt
		generator_id				int			NULL,	--	Generator	ID
		treatment_id				int			NULL,	--	Treatment	ID
		bill_unit_code				varchar(4)	NULL,	--	Unit
		profile_id					int			NULL,	--	Profile_id
		quote_id					int			NULL,	--	Quote	ID
		product_id					int			NULL,	--	BillingDetail	product_id,	for	id'ing	fees,	etc.

        job_type                    char(1)     NULL,	--  Job type - base or event.
		servicecategory_uid			int NULL,					-- 3/11/2015 - Adding service category & business segment.
		service_category_description	varchar(50) NULL,
		service_category_code		char(1) NULL,
		businesssegment_uid			int NULL,
		business_segment_code		varchar(10) NULL,
		pounds						float NULL,
		revenue_recognized_date				datetime NULL
	)

create index idx_tmp on #RevenueWork (trans_source			,company_id				,profit_ctr_id			,receipt_id				,line_id					,workorder_resource_type	,workorder_sequence_id	)

truncate table #RevenueWork

--#end

EXEC sp_rpt_recognized_revenue_calc
	@copc_list			= '21|0',
	@date_from			= '12/1/2013', --'12/31/2013',
	@date_to			= '12/15/2013', --'10/31/2011',
	@cust_id_from		= 0,
	@cust_id_to			= 999999,
-- 	@cust_type_list		= '*Any*',
--	@invoice_flag		= 'I',
--	@source_list		= 'R,W,O',		--'R,W,O',
--	@copc_search_type	= 'D', /* 'T'ransaction facility (native, default) or 'D'istribution facility */
--	@transaction_type	= 'A', /* 'A'll, 'N'ative only (or Not split), 'S'plit between facilities only */
	@debug_flag			= 0

SELECT * FROM #RevenueWork 
where reference_code is not null

*********************************************************************************************/

-- Dev work:
--		DECLARE 	@copc_list varchar(max) = 'ALL', @date_from				DATETIME = '11/1/2014',	@date_to				DATETIME = '11/30/2014', 	@cust_id_from			INT = 0,	@cust_id_to				INT = 9999999,	@cust_type_list			varchar(max) = '',	@debug_flag				INT = 1

set transaction isolation level read uncommitted

Truncate Table #RevenueWork

declare @copc_search_type char(1) = 'D' -- hard code to distributed revenue data.

declare @timestart datetime = getdate(), @lasttime datetime = getdate()

if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting Proc' as status
set @lasttime = getdate()

--# Setup

	-- Create & Populate #tmp_trans_copc
	if object_id('tempdb..#tmp_trans_copc') is not null drop table #tmp_trans_copc
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

	IF LTRIM(RTRIM(ISNULL(@copc_list, ''))) = 'ALL' OR LTRIM(RTRIM(ISNULL(@copc_list, ''))) = ''
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
			from dbo.fn_SplitXsvText(',', 0, @copc_list)
			WHERE ISNULL(ROW, '') <> '') selected_copc ON
				ProfitCenter.company_id = selected_copc.company_id
				AND ProfitCenter.profit_ctr_id = selected_copc.profit_ctr_id
		WHERE ProfitCenter.status = 'A'


if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Populated #tmp_trans_copc' as status
set @lasttime = getdate()

	-- Difference from Flash - always all sources.
	
/*
	CREATE TABLE #tmp_source (
		trans_source				char(1)
	)
	INSERT #tmp_source VALUES ('O'), ('R'), ('W')
*/
	
if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Populated #tmp_source' as status
set @lasttime = getdate()

-- declare @date_from datetime = '10/1/2011', @date_to datetime = '10/31/2011', @debug_flag int = 1, @cust_id_from int = 0, @cust_id_to int = 9999999

-- Fix/Set @date_to's time.
if @date_from is null BEGIN
	--RAISERROR 50001 '@date_from is required when running against Invoiced records.'
	RAISERROR (50001, 10, 1, '@date_from is required when running against Invoiced records.')
	RETURN
END
if @date_to is null BEGIN
	--RAISERROR 50001 '@date_to is required when running against Invoiced records.'
	RAISERROR (50001, 10, 1, '@date_to is required when running against Invoiced records.')
	RETURN
END


IF ISNULL(@date_to,'') <> ''
	IF DATEPART(hh, @date_to) = 0 SET @date_to = @date_to + 0.99999


--------------------------------------------------------------

if object_id('tempdb..#Billing') is not null drop table #Billing

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
	workorder_invoice_break_value	varchar (20) NULL,
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
	currency_code		char(3)			NULL
)

if object_id('tempdb..#SalesTax') is not null drop table #SalesTax

-- Prepare SalesTax records
CREATE TABLE #SalesTax  (
	sales_tax_id		int				NULL
)

if object_id('tempdb..#RevenueWorkService') is not null drop table #RevenueWorkService


create table #RevenueWorkService (
	trans_source			char(1),
	company_id				int,
	profit_ctr_id			int,
	receipt_id				int,
	line_id					int,
	workorder_resource_type	char(1),
	workorder_sequence_id	int,
	status_code				char(1)
)

create index idx_tmp on #RevenueWorkService (trans_source			,company_id				,profit_ctr_id			,receipt_id				,line_id					,workorder_resource_type	,workorder_sequence_id	)


if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '@date var setup finished' as status
set @lasttime = getdate()

--#end


-- Populate #RevenueWorkService with matches
insert #RevenueWorkService
select
	'W'
	, w.company_id
	, w.profit_ctr_id
	, w.workorder_id as receipt_id
	, NULL -- b.line_id
	, d.resource_type
	, d.sequence_id
	, null
from workorderheader w 
	join workorderdetail d
	on d.workorder_id = w.workorder_id
	and d.company_id = w.company_id
	and d.profit_ctr_id = w.profit_ctr_id
--	join customer c on w.customer_id = c.customer_id
where
w.end_date between @date_from and @date_to
AND w.customer_id BETWEEN @cust_id_from AND @cust_id_to
AND w.workorder_status not in ('V', 'X', 'N')
and isnull(w.fixed_price_flag, 'F') = 'F'
union
select
	'W'
	, w.company_id
	, w.profit_ctr_id
	, w.workorder_id as receipt_id
	, NULL -- b.line_id
	, NULL -- d.resource_type
	, NULL -- d.sequence_id
	, null
from workorderheader w 
where
w.end_date between @date_from and @date_to
AND w.customer_id BETWEEN @cust_id_from AND @cust_id_to
AND w.workorder_status not in ('V', 'X', 'N')
and isnull(w.fixed_price_flag, 'F') = 'T'
union
select
	'O'
	, d.company_id
	, d.profit_ctr_id
	, o.order_id
	, d.line_id
	, NULL
	, NULL
	, NULL
from orderheader o 
join orderdetail d
on o.order_id = d.order_id
where
o.order_date between @date_from and @date_to
AND o.customer_id BETWEEN @cust_id_from AND @cust_id_to
AND o.status not in ('V')
AND d.status not in ('V')
union
select
	'R'
	, r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	, r.line_id
	, NULL
	, NULL
	, NULL
from receipt r 
where
r.receipt_date between @date_from and @date_to
AND r.customer_id BETWEEN @cust_id_from AND @cust_id_to
and r.receipt_status not in ('N', 'V', 'R', 'T', 'X')
and r.fingerpr_status not in ('V', 'R')

if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#RevenueWorkService Populated' as status
set @lasttime = getdate()


-----------------------------------------------------------------------------------
-- INVOICED RECORDS
-----------------------------------------------------------------------------------
	/*

	Population of FlashWork table:

--# In Billing: Work Order records
	IN BILLING email content

	If in billing
		Use billing detail -
		Pricing method = 'A'
	*/

	if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "In Billing (Workorder), Actual #RevenueWork" Population' as status
	set @lasttime = getdate()

-- 	IF exists (select 1 from #tmp_source where trans_source = 'W')
	INSERT #RevenueWork (
		company_id					,
		profit_ctr_id				,
		trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
		receipt_id					, -- Receipt/Workorder ID
		trans_type					, -- Receipt trans type (O/I)
		billing_project_id			, -- Billing project ID
		customer_id					, -- Customer ID on Receipt/Workorder
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
		extended_amt				, -- Revenue amt
		generator_id				, -- Generator ID
		bill_unit_code				, -- Unit
		profile_id					, -- Profile_id
		quote_id					 -- Quote ID
		, product_id
		, revenue_recognized_date
	)
	SELECT DISTINCT
		b.company_id,
		b.profit_ctr_id,
		b.trans_source,
		b.receipt_id,
		b.trans_type,
		b.billing_project_id,
		b.customer_id,
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
		bd.extended_amt,
		b.generator_id,
		b.bill_unit_code,
		b.profile_id,
		woh.quote_id
		, bd.product_id	
		, coalesce(woh.end_date, woh.start_date, woh.date_submitted, woh.date_modified)
	FROM #RevenueWorkService rws
	inner join 	Billing b (nolock)
		on b.trans_source	= rws.trans_source
		and b.company_id	= rws.company_id
		and b.profit_ctr_id	= rws.profit_ctr_id
		and b.receipt_id	= rws.receipt_id
		and b.workorder_resource_type = rws.workorder_resource_type
		and b.workorder_sequence_id = rws.workorder_sequence_id	
	INNER JOIN BillingDetail bd (nolock)
		ON bd.billing_uid = b.billing_uid
	INNER JOIN WorkOrderHeader woh (nolock)
		ON b.receipt_id = woh.workorder_id
		AND b.company_id = woh.company_id
		AND b.profit_ctr_id = woh.profit_ctr_id
	WHERE 1=1
		AND b.trans_source = 'W'
		AND b.status_code <> 'V'
		AND woh.workorder_status not in ('V', 'X', 'N')
		and isnull(woh.fixed_price_flag, 'F') = 'F'
UNION
	SELECT DISTINCT
		b.company_id,
		b.profit_ctr_id,
		b.trans_source,
		b.receipt_id,
		b.trans_type,
		b.billing_project_id,
		b.customer_id,
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
		bd.extended_amt,
		b.generator_id,
		b.bill_unit_code,
		b.profile_id,
		woh.quote_id
		, bd.product_id	
		, coalesce(woh.end_date, woh.start_date, woh.date_submitted, woh.date_modified)
	FROM #RevenueWorkService rws
	inner join 	Billing b (nolock)
		on b.trans_source	= rws.trans_source
		and b.company_id	= rws.company_id
		and b.profit_ctr_id	= rws.profit_ctr_id
		and b.receipt_id	= rws.receipt_id
		--and b.workorder_resource_type = rws.workorder_resource_type
		--and b.workorder_sequence_id = rws.workorder_sequence_id	
	INNER JOIN BillingDetail bd (nolock)
		ON bd.billing_uid = b.billing_uid
	INNER JOIN WorkOrderHeader woh (nolock)
		ON b.receipt_id = woh.workorder_id
		AND b.company_id = woh.company_id
		AND b.profit_ctr_id = woh.profit_ctr_id
	WHERE 1=1
		AND b.trans_source = 'W'
		AND b.status_code <> 'V'
		AND woh.workorder_status not in ('V', 'X', 'N')
		and isnull(woh.fixed_price_flag, 'F') = 'T'
				


	if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "In Billing (Workorder), Actual #RevenueWork" Population' as status
	set @lasttime = getdate()

--#end
		
--# In Billing: Receipt Records
	if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "In Billing (Receipt), Actual #RevenueWork" Population' as status
	set @lasttime = getdate()
	
-- 	IF exists (select 1 from #tmp_source where trans_source = 'R')
	INSERT #RevenueWork (
		company_id					,
		profit_ctr_id				,
		trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
		receipt_id					, -- Receipt/Workorder ID
		trans_type					, -- Receipt trans type (O/I)
		billing_project_id			, -- Billing project ID
		customer_id					, -- Customer ID on Receipt/Workorder
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
		extended_amt				, -- Revenue amt
		generator_id				, -- Generator ID
		treatment_id				, -- Treatment ID
		bill_unit_code				, -- Unit
		profile_id					, -- Profile_id
		quote_id					, -- Quote ID
		product_id					 -- BillingDetail product_id, for id'ing fees, etc.
		, revenue_recognized_date	
	)
	SELECT DISTINCT
		b.company_id,
		b.profit_ctr_id,
		b.trans_source,
		b.receipt_id,
		b.trans_type,
		b.billing_project_id,
		b.customer_id,
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
		bd.extended_amt,
		b.generator_id,
		t.treatment_id,
		b.bill_unit_code,
		b.profile_id,
		pqa.quote_id,
		bd.product_id
		, r.receipt_date
	FROM #RevenueWorkService rws
	INNER JOIN Billing b (nolock)
		on b.trans_source	= rws.trans_source
		and b.receipt_id	= rws.receipt_id
		and b.line_id		= rws.line_id
		and b.company_id	= rws.company_id
		and b.profit_ctr_id	= rws.profit_ctr_id
	INNER JOIN BillingDetail bd (nolock)
		ON bd.billing_uid = b.billing_uid
	INNER JOIN Receipt r (nolock)
		ON b.receipt_id = r.receipt_id
		AND b.line_id = r.line_id
		AND b.company_id = r.company_id
		AND b.profit_ctr_id = r.profit_ctr_id
	LEFT OUTER JOIN profilequoteapproval pqa (nolock)
		ON b.profile_id = pqa.profile_id
		AND b.company_id = pqa.company_id
		AND b.profit_ctr_id = pqa.profit_ctr_id
	LEFT OUTER JOIN Treatment t (nolock)
		ON r.treatment_id = t.treatment_id
		AND r.company_id = t.company_id
		AND r.profit_ctr_id = t.profit_ctr_id
	WHERE 1=1
		AND b.trans_source = 'R'
		AND b.status_code <> 'V'
		and r.receipt_status not in ('N', 'V', 'R', 'T', 'X')
		and r.fingerpr_status not in ('V', 'R')

	if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "In Billing (Receipt), Actual #RevenueWork" Population' as status
	set @lasttime = getdate()

--#end	

--# In Billing: (Retail) Order Records
	if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "In Billing (Orders), Actual #RevenueWork" Population' as status
	set @lasttime = getdate()
	
--	IF exists (select 1 from #tmp_source where trans_source = 'O')
	INSERT #RevenueWork (
		company_id					,
		profit_ctr_id				,
		trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
		receipt_id					, -- Receipt/Workorder ID
		trans_type					, -- Receipt trans type (O/I)
		billing_project_id			, -- Billing project ID
		customer_id					, -- Customer ID on Receipt/Workorder
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
		extended_amt				, -- Revenue amt
		generator_id				, -- Generator ID
		bill_unit_code				, -- Unit
		profile_id					, -- Profile_id
		quote_id					, -- Quote ID
		product_id					 -- BillingDetail product_id, for id'ing fees, etc.
		, revenue_recognized_date	
	)
	SELECT
		b.company_id,
		b.profit_ctr_id,
		b.trans_source,
		b.receipt_id,
		b.trans_type,
		b.billing_project_id,
		b.customer_id,
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
		bd.extended_amt,
		b.generator_id,
		b.bill_unit_code,
		b.profile_id,
		pqa.quote_id,
		bd.product_id
		, oh.order_date
	FROM #RevenueWorkService rws
	JOIN 	Billing b (nolock)
				on b.trans_source	= rws.trans_source
				and b.company_id	= rws.company_id
				and b.profit_ctr_id	= rws.profit_ctr_id
				and b.receipt_id	= rws.receipt_id
				and b.line_id		= rws.line_id
	INNER JOIN BillingDetail bd (nolock)
		ON bd.billing_uid = b.billing_uid
	INNER JOIN OrderHeader oh (nolock)
		on b.receipt_id = oh.order_id
	INNER JOIN OrderDetail od (nolock)
		on b.receipt_id = od.order_id
		and b.company_id = od.company_id
		and b.profit_ctr_id = od.profit_ctr_id
		and b.line_id = od.line_id
	LEFT OUTER JOIN profilequoteapproval pqa (nolock)
		ON b.profile_id = pqa.profile_id
		AND b.company_id = pqa.company_id
		AND b.profit_ctr_id = pqa.profit_ctr_id
	WHERE 1=1
		AND b.trans_source = 'O'
		AND b.status_code <> 'V'
		AND oh.status not in ('V')
		and od.status not in ('V')

	if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "In Billing (Orders), Actual #RevenueWork" Population' as status
	set @lasttime = getdate()

-- Anything now in #RevenueWork that started as a transaction in #RevenueWorkService
-- has now made it into RW because they were billed.  We'll set the status_code
-- in RWS to 'B' so those get ignored in the ToSubmit process below.
	update #RevenueWorkService set status_code = 'B'
	from #RevenueWorkService rws
	join #RevenueWork rw	on rws.trans_source = rw.trans_source
		and rws.receipt_id = rw.receipt_id
		and rws.company_id = rw.company_id
		and rws.profit_ctr_id = rw.profit_ctr_id

	if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Billed records in RevenueWorkService updated' as status
	set @lasttime = getdate()

--#end	
-- This concludes the IN BILLING email content.


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
	
--# Not In Billing: Work Order


-- 3/19/2015 - debug run
--		DECLARE 	@copc_list varchar(max) = 'ALL', @date_from				DATETIME = '11/1/2014',	@date_to				DATETIME = '11/30/2014', 	@cust_id_from			INT = 0,	@cust_id_to				INT = 9999999,	@cust_type_list			varchar(max) = '',	@debug_flag				INT = 1, @timestart datetime = getdate(), @lasttime datetime = getdate()
-- run time to this point: 01:57

if object_id('tempdb..#ToSubmit') is not null drop table #ToSubmit

select distinct company_id, profit_ctr_id, receipt_id, trans_source, 0 as progress into #ToSubmit from #RevenueWorkService where status_code is null
-- update #RevenueWorkService set status_code = null where status_code = 'S'

-- 3/19/2015 - debug run
-- 1573 rows in #ToSubmit

declare @this_receipt_id int
	, @this_company_id	int
	, @this_profit_ctr_id int
	, @this_trans_source char(1)
	, @this_date datetime = getdate()

	if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Records to faux-submit identified.  Submits starting' as status
	set @lasttime = getdate()

/*
while exists (select 1 from #ToSubmit where progress = 0) begin

	select top 1 @this_trans_source = trans_source
	, @this_company_id = company_id
	, @this_profit_ctr_id = profit_ctr_id
	, @this_receipt_id = receipt_id
	from #ToSubmit rws
	where progress = 0
*/
declare c_tosubmit cursor forward_only read_only for
select trans_source, company_id, profit_ctr_id, receipt_id
from #ToSubmit rws

open c_tosubmit
fetch c_tosubmit into @this_trans_source, @this_company_id, @this_profit_ctr_id, @this_receipt_id

while @@fetch_status = 0
begin

	TRUNCATE TABLE #Billing
	TRUNCATE TABLE #BillingDetail
	TRUNCATE TABLE #BillingComment

	IF @this_trans_source in ('R', 'W')
		exec sp_billing_submit_calc
			@debug				= 0,
			@company_id			= @this_company_id,
			@profit_ctr_id		= @this_profit_ctr_id,
			@trans_source		= @this_trans_source,
			@receipt_id			= @this_receipt_id,
			@submit_date		= @this_date,
			@submit_status		= NULL,
			@user_code			= 'SA',
			@sales_tax_id_list	= NULL,
			@update_prod		= 'F'	-- 'T'rue = update real tables.  'F' = no real table updates, just faux submitting.

	IF @this_trans_source in ('O')
	exec sp_billing_submit_order_calc
		@debug				= 0,
		@trans_source		= @this_trans_source,
		@order_id			= @this_receipt_id,
		@submit_date		= @this_date,
		@submit_status		= NULL,
		@user_code			= 'SA',
		@update_prod		= 'F'	-- 'T'rue = update real tables.  'F' = no real table updates, just faux submitting.


	-- insert to #RevenueWork table
	
	if @this_trans_source = 'W'
	INSERT #RevenueWork (
		company_id					,
		profit_ctr_id				,
		trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
		receipt_id					, -- Receipt/Workorder ID
		trans_type					, -- Receipt trans type (O/I)
		billing_project_id			, -- Billing project ID
		customer_id					, -- Customer ID on Receipt/Workorder
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
		extended_amt				, -- Revenue amt
		generator_id				, -- Generator ID
		bill_unit_code				, -- Unit
		profile_id					, -- Profile_id
		quote_id					 -- Quote ID
		, product_id
		, revenue_recognized_date	
	)
	SELECT DISTINCT
		b.company_id,
		b.profit_ctr_id,
		b.trans_source,
		b.receipt_id,
		b.trans_type,
		b.billing_project_id,
		b.customer_id,
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
		bd.extended_amt,
		b.generator_id,
		b.bill_unit_code,
		b.profile_id,
		woh.quote_id	
		, bd.product_id
		, coalesce(woh.end_date, woh.start_date, woh.date_submitted, woh.date_modified)
	FROM #RevenueWorkService rws
	inner join 	#Billing b (nolock)
		on b.trans_source	= rws.trans_source
		and b.company_id	= rws.company_id
		and b.profit_ctr_id	= rws.profit_ctr_id
		and b.receipt_id	= rws.receipt_id
		and b.workorder_resource_type = rws.workorder_resource_type
		and b.workorder_sequence_id = rws.workorder_sequence_id	
	INNER JOIN #BillingDetail bd (nolock)
		ON bd.billing_uid = b.billing_uid
	INNER JOIN WorkOrderHeader woh (nolock)
		ON b.receipt_id = woh.workorder_id
		AND b.company_id = woh.company_id
		AND b.profit_ctr_id = woh.profit_ctr_id
	WHERE 1=1
		AND b.trans_source = 'W'
		AND b.status_code <> 'V'
		AND woh.workorder_status not in ('V', 'X', 'N')
		and isnull(woh.fixed_price_flag, 'F') = 'F'
UNION
	SELECT DISTINCT
		b.company_id,
		b.profit_ctr_id,
		b.trans_source,
		b.receipt_id,
		b.trans_type,
		b.billing_project_id,
		b.customer_id,
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
		bd.extended_amt,
		b.generator_id,
		b.bill_unit_code,
		b.profile_id,
		woh.quote_id	
		, bd.product_id
		, coalesce(woh.end_date, woh.start_date, woh.date_submitted, woh.date_modified)
	FROM #RevenueWorkService rws
	inner join 	#Billing b (nolock)
		on b.trans_source	= rws.trans_source
		and b.company_id	= rws.company_id
		and b.profit_ctr_id	= rws.profit_ctr_id
		and b.receipt_id	= rws.receipt_id
		--and b.workorder_resource_type = rws.workorder_resource_type
		--and b.workorder_sequence_id = rws.workorder_sequence_id	
	INNER JOIN #BillingDetail bd (nolock)
		ON bd.billing_uid = b.billing_uid
	INNER JOIN WorkOrderHeader woh (nolock)
		ON b.receipt_id = woh.workorder_id
		AND b.company_id = woh.company_id
		AND b.profit_ctr_id = woh.profit_ctr_id
	WHERE 1=1
		AND b.trans_source = 'W'
		AND b.status_code <> 'V'
		AND woh.workorder_status not in ('V', 'X', 'N')
		and isnull(woh.fixed_price_flag, 'F') = 'T'	
		
			
	if @this_trans_source = 'R'
	INSERT #RevenueWork (
		company_id					,
		profit_ctr_id				,
		trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
		receipt_id					, -- Receipt/Workorder ID
		trans_type					, -- Receipt trans type (O/I)
		billing_project_id			, -- Billing project ID
		customer_id					, -- Customer ID on Receipt/Workorder
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
		extended_amt				, -- Revenue amt
		generator_id				, -- Generator ID
		treatment_id				, -- Treatment ID
		bill_unit_code				, -- Unit
		profile_id					, -- Profile_id
		quote_id					, -- Quote ID
		product_id					 -- BillingDetail product_id, for id'ing fees, etc.
		, revenue_recognized_date			
	)
	SELECT DISTINCT
		b.company_id,
		b.profit_ctr_id,
		b.trans_source,
		b.receipt_id,
		b.trans_type,
		b.billing_project_id,
		b.customer_id,
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
		bd.extended_amt,
		b.generator_id,
		t.treatment_id,
		b.bill_unit_code,
		b.profile_id,
		pqa.quote_id,
		bd.product_id
		, r.receipt_date
	FROM #RevenueWorkService rws
	INNER JOIN #Billing b (nolock)
		on b.trans_source	= rws.trans_source
		and b.receipt_id	= rws.receipt_id
		and b.line_id		= rws.line_id
		and b.company_id	= rws.company_id
		and b.profit_ctr_id	= rws.profit_ctr_id
	INNER JOIN #BillingDetail bd (nolock)
		ON bd.billing_uid = b.billing_uid
	INNER JOIN Receipt r (nolock)
		ON b.receipt_id = r.receipt_id
		AND b.line_id = r.line_id
		AND b.company_id = r.company_id
		AND b.profit_ctr_id = r.profit_ctr_id
	LEFT OUTER JOIN profilequoteapproval pqa (nolock)
		ON b.profile_id = pqa.profile_id
		AND b.company_id = pqa.company_id
		AND b.profit_ctr_id = pqa.profit_ctr_id
	LEFT OUTER JOIN Treatment t (nolock)
		ON r.treatment_id = t.treatment_id
		AND r.company_id = t.company_id
		AND r.profit_ctr_id = t.profit_ctr_id
	WHERE 1=1
		AND b.trans_source = 'R'
		AND b.status_code <> 'V'
		and r.receipt_status not in ('N', 'V', 'R', 'T', 'X')
		and r.fingerpr_status not in ('V', 'R')

	if @this_trans_source = 'O'
	INSERT #RevenueWork (
		company_id					,
		profit_ctr_id				,
		trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
		receipt_id					, -- Receipt/Workorder ID
		trans_type					, -- Receipt trans type (O/I)
		billing_project_id			, -- Billing project ID
		customer_id					, -- Customer ID on Receipt/Workorder
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
		extended_amt				, -- Revenue amt
		generator_id				, -- Generator ID
		bill_unit_code				, -- Unit
		profile_id					, -- Profile_id
		quote_id					, -- Quote ID
		product_id					 -- BillingDetail product_id, for id'ing fees, etc.
		, revenue_recognized_date	
	)
	SELECT
		b.company_id,
		b.profit_ctr_id,
		b.trans_source,
		b.receipt_id,
		b.trans_type,
		b.billing_project_id,
		b.customer_id,
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
		bd.extended_amt,
		b.generator_id,
		b.bill_unit_code,
		b.profile_id,
		pqa.quote_id,
		bd.product_id
		, oh.order_date
	FROM #RevenueWorkService rws
	JOIN 	#Billing b (nolock)
				on b.trans_source	= rws.trans_source
				and b.company_id	= rws.company_id
				and b.profit_ctr_id	= rws.profit_ctr_id
				and b.receipt_id	= rws.receipt_id
				and b.line_id		= rws.line_id
	INNER JOIN #BillingDetail bd (nolock)
		ON bd.billing_uid = b.billing_uid
	INNER JOIN OrderHeader oh (nolock)
		on b.receipt_id = oh.order_id
	INNER JOIN OrderDetail od (nolock)
		on b.receipt_id = od.order_id
		and b.company_id = od.company_id
		and b.profit_ctr_id = od.profit_ctr_id
		and b.line_id = od.line_id
	LEFT OUTER JOIN profilequoteapproval pqa (nolock)
		ON b.profile_id = pqa.profile_id
		AND b.company_id = pqa.company_id
		AND b.profit_ctr_id = pqa.profit_ctr_id
	WHERE 1=1
		AND b.trans_source = 'O'
		AND b.status_code <> 'V'
		and oh.status not in ('V')
		and od.status not in ('V')
/*
	update #ToSubmit set progress = 1
	where trans_source = @this_trans_source
	and receipt_id = @this_receipt_id
	and company_id = @this_company_id
	and profit_ctr_id = @this_profit_ctr_id
*/
	fetch c_tosubmit into @this_trans_source, @this_company_id, @this_profit_ctr_id, @this_receipt_id
end

	if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Faux-submits finished' as status
	set @lasttime = getdate()

-- 3/19/2015 - debug run
-- 1573 rows in #ToSubmit
-- 3:31

--# Work Order Group Fix - Adding individual members in place of group summaries.

-- GROUP FIX
-- Solution to 'G'roup problem:
-- Insert the component records of the group from workorderdetail, calculate their prices.  Then remove the group record.
-- THEN do the surcharge/tax calc... so this actually gets inserted way above here.
-- FYI there are no 'D'isposal wod records with a group_code, so this is a copy/mod of the E/S/L query above

-- 	IF exists (select 1 from #tmp_source where trans_source = 'W')
		INSERT #RevenueWork (
			company_id					,
			profit_ctr_id				,
			trans_source				, -- Receipt, Workorder, Workorder-Receipt, etc
			receipt_id					, -- Receipt/Workorder ID
			trans_type					, 
			billing_project_id			, -- Billing project ID
			customer_id					, -- Customer ID on Receipt/Workorder
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
			extended_amt				, -- Revenue amt
			generator_id				, -- Generator ID
			bill_unit_code				, -- Unit
			quote_id					 -- Quote ID
			, revenue_recognized_date	
		)
		SELECT
			woh.company_id,
			woh.profit_ctr_id,
			'W' as trans_source,
			woh.workorder_id as receipt_id,
			'O' AS trans_type,
			woh.billing_project_id,
			woh.customer_id,
			wod.sequence_id AS line_id,
			1 AS price_id,
			wod.sequence_id,
			wod.resource_class_code, -- workorder_resource_item
			wod.resource_type, -- workorder_resource_type
			NULL AS Workorder_resource_category,
			coalesce(wod.quantity_used, 0) qty,
			'N' as dist_flag,		
			woh.company_id dist_company_id,
			woh.profit_ctr_id dist_profit_ctr_id,
			-- Via experiment, found correct-est version of this is group-member's price X group line's quantity.  Odd but true.
			round(wod.price * coalesce( wodSource.quantity_used, 0),2) as extended_amt,
			woh.generator_id,
			wod.bill_unit_code,
			woh.quote_ID
			, coalesce(woh.end_date, woh.start_date, woh.date_submitted, woh.date_modified)
		FROM WorkOrderHeader woh (nolock)
		INNER JOIN WorkorderDetail wodSource (nolock) -- Necessary since #RevenueWork doesn't store group_code/instance.
			ON woh.workorder_id = wodSource.workorder_id
			AND woh.company_id = wodSource.company_id
			AND woh.profit_ctr_id = wodSource.profit_ctr_id
			AND wodSource.resource_type = 'G'
			AND wodSource.bill_rate > 0
			AND wodSource.extended_price > 0
		INNER JOIN WorkOrderDetail wod (nolock)
			ON woh.workorder_id = wod.workorder_id
			AND woh.company_id = wod.company_id
			AND woh.profit_ctr_id = wod.profit_ctr_id
			and wod.group_code = wodSource.group_code
			and wod.group_instance_id = wodSource.group_instance_id
			AND wod.resource_type <> 'G'
			AND wod.bill_rate > 0
		WHERE 1=1
			and EXISTS (
				SELECT 1
				FROM #RevenueWork rw
					where rw.trans_source = 'W'
					and rw.receipt_id = woh.workorder_id
					and rw.company_id = woh.company_id
					and rw.profit_ctr_id = woh.profit_ctr_id
					and rw.workorder_resource_type = 'G'
					and rw.extended_amt > 0
			)
			AND isnull(woh.fixed_price_flag, 'F') = 'F'
			AND woh.workorder_status not in ('V', 'X', 'N')

	if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Work Order Group record components added' as status
	set @lasttime = getdate()

	-- The individual components of workorder groups have been added now.  Remove the actual group records
	update #RevenueWork set trans_source = 'G' where workorder_resource_type = 'G' and trans_source = 'W' and billing_type = 'Workorder'

	if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Work Order Group records removed' as status
	set @lasttime = getdate()

-- 7:35
--#end			

	
--# Put Work Order records into #RevenueWOrk from #Billing & #BillingDetail (Insurance/Energy only)
		-- Don't think we need to delete from this table; all we need to do is add the insurance/energy surcharges back in from #Billing
		---- Now have to get work order data back into #RevenueWork
		--DELETE FROM #RevenueWork FROM #RevenueWork fw
		--INNER JOIN #Billing b
		--	ON fw.receipt_id = b.receipt_id
		--	AND fw.company_id = b.company_id
		--	AND fw.profit_ctr_id = b.profit_ctr_id
		--	AND fw.line_id = b.line_id
		--	AND fw.trans_source = b.trans_source
		--WHERE fw.trans_source = 'W'
		--AND fw.billing_type <> 'WorkOrder'


-- END -- end of invoiced vs not-invoiced 



-- Remove Disposal records (we'll move them to an unrecognized trans source)
update #RevenueWork set trans_source = 'D' 
-- select * from #RevenueWork -- 149314 
where trans_source = 'R' and trans_type = 'D' -- 106750
and billing_type = 'Disposal' -- 45243


--		DECLARE 	@copc_list varchar(max) = 'ALL', @date_from				DATETIME = '11/1/2014',	@date_to				DATETIME = '11/30/2014', 	@cust_id_from			INT = 0,	@cust_id_to				INT = 9999999,	@cust_type_list			varchar(max) = '',	@debug_flag				INT = 1

insert #RevenueWork  (

	--	Header info:
		company_id					, -- int			NULL,
		profit_ctr_id				, -- int			NULL,
		trans_source				, -- char(2)		NULL,	--	Receipt,	Workorder,	Workorder-Receipt,	etc
		receipt_id					, -- int			NULL,	--	Receipt/Workorder	ID
		trans_type					, -- char(1)		NULL,	--	Receipt	trans	type	(O/I)
		billing_project_id			, -- int			NULL,	--	Billing	project	ID
		customer_id					, -- int			NULL,	--	Customer	ID	on	Receipt/Workorder

	--	Detail info:
		line_id						, -- int			NULL,	--	Receipt	line	id
		price_id					, -- int			NULL,	--	Receipt	line	price	id
		ref_line_id					, -- int			NULL,	--	Billing	reference	line_id	(which	line	does	this	refer	to?)
		quantity					, -- float		NULL,	--	Receipt/Workorder	Quantity
		billing_type				, -- varchar(20)	NULL,	--	'Energy',	'Insurance',	'Salestax'	etc.
		dist_flag					, -- char(1)		NULL,	--	'D', 'N' (Distributed/Not Distributed -- if the dist co/pc is diff from native co/pc, this is D)
		dist_company_id				, -- int			NULL,	--	Distribution	Company	ID	(which	company	receives	the	revenue)
		dist_profit_ctr_id			, -- int			NULL,	--	Distribution	Profit	Ctr	ID	(which	profitcenter	receives	the	revenue)
		extended_amt				, -- float			NULL,	--	Revenue	amt
		generator_id				, -- int			NULL,	--	Generator	ID
		treatment_id				, -- int			NULL,	--	Treatment	ID
		bill_unit_code				, -- varchar(4)	NULL,	--	Unit
		profile_id					, -- int			NULL,	--	Profile_id
		quote_id					, -- int			NULL,	--	Quote	ID
		product_id					, -- int			NULL,	--	BillingDetail	product_id,	for	id'ing	fees,	etc.

		pounds						, -- float NULL,
		revenue_recognized_date		 -- datetime NULL
	)
select
	r.company_id
	, r.profit_ctr_id
	, 'R' as trans_source
	, r.receipt_id
	, r.trans_type
	, r.billing_project_id
	, r.customer_id
	, r.line_id
	, null as price_id
	, null as ref_line_id
	, count(cds.container_id) as quantity
	, 'Disposal' as billing_type
	, 'N' as dist_flag -- because this is a disposal receipt
	, r.company_id as dist_company_id
	, r.profit_ctr_id as dist_profit_ctr_id
	, sum(cds.disposal_revenue_amt) as extended_amt
	, r.generator_id
	, r.treatment_id
	, NULL as bill_unit_code	-- Container bill units are muddled.
	, r.profile_id
	, pqa.quote_id
	, null as product_id
	, sum(cds.pounds) as pounds
	, max(cds.final_disposal_date) as revenue_recognized_date
from
	receipt r (nolock)
	inner join #tmp_trans_copc copc
		on r.company_id = copc.company_id
		and r.profit_ctr_id = copc.profit_ctr_id
	inner join ContainerDisposalStatus cds (nolock)
		on r.receipt_id = cds.receipt_id
		and r.line_id = cds.line_id
		and r.company_id = cds.company_id
		and r.profit_ctr_id = cds.profit_ctr_id
		and cds.container_type = 'R'
		and cds.final_disposal_status = 'C'
	LEFT OUTER JOIN profilequoteapproval pqa (nolock)
		ON r.profile_id = pqa.profile_id
		AND r.company_id = pqa.company_id
		AND r.profit_ctr_id = pqa.profit_ctr_id
where
	cds.final_disposal_date between @date_from and @date_to
	and r.customer_id between @cust_id_from AND @cust_id_to
	and r.receipt_status not in ('N', 'V', 'R', 'T', 'X')
	and r.fingerpr_status not in ('V', 'R')
group by
	r.company_id
	, r.profit_ctr_id
	, r.receipt_id
	, r.trans_type
	, r.billing_project_id
	, r.customer_id
	, r.line_id
	, r.generator_id
	, r.treatment_id
	, r.profile_id
	, pqa.quote_id


--# Filtering on transaction type & copc search logic
/*
		-- Handle @transaction_type before @copc_search_type
		-- Oh, according to LT: Show just the split lines, not the whole receipt for a split line.
		IF @transaction_type = 'N' BEGIN
			if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '@transaction_type = N: Removing records with split lines.' as status
			set @lasttime = getdate()
			
			-- explained: delete from #RevenueWork where dist & company_id don't match each other.
			-- What's left are only rows where dist & company DO match.
			DELETE FROM #RevenueWork
			FROM #RevenueWork f
			where not(
				isnull(dist_company_id, company_id) = company_id
				and isnull(dist_profit_ctr_id, profit_ctr_id) = profit_ctr_id
			)
			if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished @transaction_type = N: Removing records with split lines.' as status
			set @lasttime = getdate()
			
		END

		IF @transaction_type = 'S' BEGIN
			if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '@transaction_type = S: Removing records without split lines.' as status
			set @lasttime = getdate()
			
			DELETE FROM #RevenueWork
			FROM #RevenueWork f
			where (
				isnull(dist_company_id, company_id) = company_id
				and isnull(dist_profit_ctr_id, profit_ctr_id) = profit_ctr_id
			)
			if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished @transaction_type = S: Removing records without split lines.' as status
			set @lasttime = getdate()
			
		END
*/	



-- DELETE from #RevenueWork where the trans_source is not one of our explicitly allowed.
DELETE from #RevenueWork where trans_source not in ('W', 'R', 'O')


		-- if user specified to search copc's among Distribution fields, it's time to filter that.

--		DECLARE 	@copc_list varchar(max) = 'ALL', @date_from				DATETIME = '11/1/2014',	@date_to				DATETIME = '11/30/2014', 	@cust_id_from			INT = 0,	@cust_id_to				INT = 9999999,	@cust_type_list			varchar(max) = '',	@debug_flag				INT = 1, @timestart datetime = getdate(), @lasttime datetime = getdate(), @copc_search_type char(1) = 'D'
			
		IF @copc_search_type = 'D' BEGIN
			if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '@copc_search_type = D: filtering on split facilities after populating with all facilities.' as status
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
					from dbo.fn_SplitXsvText(',', 0, @copc_list)
					WHERE ISNULL(ROW, '') <> '') selected_copc ON
						ProfitCenter.company_id = selected_copc.company_id
						AND ProfitCenter.profit_ctr_id = selected_copc.profit_ctr_id
				WHERE ProfitCenter.status = 'A'
			END
			-- Now #tmp_trans_copc is ready to use again.  Apply it to the dist_company_id and dist_profit_ctr_id fields in #RevenueWork

			delete from #RevenueWork where not exists (
				select 1 from #tmp_trans_copc where company_id = #RevenueWork.dist_company_id and profit_ctr_id = #RevenueWork.dist_profit_ctr_id
			)
			if @debug_flag > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished @copc_search_type = D: filtering on split facilities after populating with all facilities.' as status
			set @lasttime = getdate()
			
		END


--#end



--# Assign Job Type: Base/Event.
	-- Set job_types.
	update #RevenueWork set job_type = 'B' -- Default	

    /* Update Job type to Event on event jobs.  defaulted to "B" since there were so many
    null and blank values, retail stays Base */
    update #RevenueWork set
		job_type = 'E'
    from #RevenueWork
    INNER JOIN profilequoteheader pqh
		ON #RevenueWork.quote_id = pqh.quote_id
    where pqh.job_type  = 'E' 
    and #RevenueWork.trans_source = 'R'
    
    -- All job type values for each receipt line should match. Since they all default to Base, we set any that have an Event, to all Event.
    update #RevenueWork set
		job_type = 'E'
    from #RevenueWork r
	where r.trans_source = 'R'
	and r.job_type = 'B'
	and exists (
		select 1 from #Revenuework r2
		where r2.receipt_id = r.receipt_id
		and r2.line_id = r.line_id
		and r2.company_id = r.company_id
		and r2.profit_ctr_id = r.profit_ctr_id
		and r2.job_type = 'E'
	)

    update #RevenueWork set
		job_type = 'E'
    where quote_id in (
		select quote_id 
		from workorderquoteheader 
		where job_type  = 'E' 
		And trans_type = 'O'
	)
    and #RevenueWork.trans_source = 'W'

    -- All job type values for each work order should match. Since they all default to Base, we set any that have an Event, to all Event.
    update #RevenueWork set
		job_type = 'E'
    from #RevenueWork r
	where r.trans_source = 'W'
	and r.job_type = 'B'
	and exists (
		select 1 from #Revenuework r2
		where r2.receipt_id = r.receipt_id
		and r2.company_id = r.company_id
		and r2.profit_ctr_id = r.profit_ctr_id
		and r2.job_type = 'E'
	)

--#end

--SELECT  *
--FROM    #RevenueWork -- 147813
--where servicecategory_uid is null -- 147813

--# Assign Service Category & Business Segment values
-- Update the Service Categories & Business Segments from Products
update #RevenueWork set
	servicecategory_uid = p.servicecategory_uid
	, service_category_description = s.service_category_description
	, service_category_code = s.service_category_code
	, businesssegment_uid = p.businesssegment_uid
	, business_segment_code = b.business_segment_code
from #RevenueWork r
inner join product p
	on r.product_id = p.product_id
	-- No company matching. That's deliberate.
	and p.servicecategory_uid is not null
inner join servicecategory s
	on p.servicecategory_uid = s.servicecategory_uid
inner join businesssegment b
	on p.businesssegment_uid = b.businesssegment_uid
	
-- Update the Service Categories from ResourceClasses
update #RevenueWork set
	servicecategory_uid = rcd.servicecategory_uid
	, service_category_description = s.service_category_description
	, service_category_code = s.service_category_code
	, businesssegment_uid = rcd.businesssegment_uid
	, business_segment_code = b.business_segment_code
from #RevenueWork r
inner join ResourceClassDetail rcd
	on ltrim(rtrim(r.workorder_resource_item)) = ltrim(rtrim(rcd.resource_class_code))
	and r.company_id = rcd.company_id
	and r.profit_ctr_id = rcd.profit_ctr_id
	and rcd.servicecategory_uid is not null
inner join servicecategory s
	on rcd.servicecategory_uid = s.servicecategory_uid
inner join businesssegment b
	on rcd.businesssegment_uid = b.businesssegment_uid
where 1=1
and r.servicecategory_uid is null

--SELECT  *
--FROM    #RevenueWork -- 147813
--where servicecategory_uid is null -- 50978

-- Update the Service Categories from Workorder Disposal
update #RevenueWork set 
	servicecategory_uid = dbo.fn_get_disposal_servicecategory_uid( trans_source, company_id, profit_ctr_id, receipt_id, workorder_resource_type, workorder_sequence_id, billing_type),
	businesssegment_uid = dbo.fn_get_disposal_businesssegment_uid( trans_source, company_id, profit_ctr_id, receipt_id, workorder_resource_type, workorder_sequence_id)
where
	trans_source = 'W' 
	and trans_type = 'O' 
	and workorder_resource_type = 'D' 

-- Update the Service Categories from Receipt Disposal
update #RevenueWork set 
	servicecategory_uid = dbo.fn_get_disposal_servicecategory_uid( trans_source, company_id, profit_ctr_id, receipt_id, workorder_resource_type, line_id, billing_type),
	businesssegment_uid = dbo.fn_get_disposal_businesssegment_uid( trans_source, company_id, profit_ctr_id, receipt_id, workorder_resource_type, line_id)
where
	trans_source = 'R' 
	and trans_type = 'D' 
	and product_id is null

update #RevenueWork set
	service_category_description = s.service_category_description
	, service_category_code = s.service_category_code
from #RevenueWork r
inner join ServiceCategory s
	on r.servicecategory_uid = s.servicecategory_uid
where r.service_category_description is null


update #RevenueWork set
	business_segment_code = b.business_segment_code
from #RevenueWork r
inner join BusinessSegment b
	on r.businesssegment_uid = b.businesssegment_uid
where r.business_segment_code is null

--#end



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_recognized_revenue_calc] TO [EQAI]
    AS [dbo];

