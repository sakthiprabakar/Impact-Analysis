-- drop proc if exists sp_rpt_container_billing_status
go

CREATE PROC sp_rpt_container_billing_status (
	@Report_Type		char(2)		= 'BU'	-- Or 'UD'.  This is an amalgam of these individual script parameters...
	, @start_date		datetime
	, @end_date			datetime
	, @user_code		varchar(10)
	, @permission_id	int
	, @report_log_id	int		-- Report Log ID for export purposes
)
AS
/* *****************************************************************************************************

sp_rpt_container_billing_status

	Born from 6/2014 USEcology/EQ Accrual & Deferral reporting process.
	Narrowed to 2 specialized output types: 
		Containers Invoiced but not Disposed (Deferral)
		Containers Disposed but not Invoiced (Accrual)

	Runs reports to excel for:
		Detail
		GL Summary
		Inventory Summary by company/profitctr
		Inventory Reference 
		Billed Inventory

	Overall Logic/Steps:
		1. Collect an initial set of containers into #WContainers (either open or closed-to-final-disposition
		2. Find all ancestors of the containers, add them into the same #WContainer table
		3. IF looking for Disposed containers only,
				join #WContainer against ContainerDestination - any open containers in ContainerDestination
				mean the whole #WContainer history is considered open
		4. Join #WContainer to Receipt, and LOJ to Billing, BillingDetail
		5. Searches for Unbilled records count if
				there's no billing record OR there is, but the invoice date is > @end_date
		   Searches for Billed records count if
				there's a billing record invoiced between @start_date and @end_date
		6. Searches for Unbilled records must also call BillingCalc to get calculated future billing amounts
		7. Select output fields based in inputs, date ranges, etc.	

History
	7/30/2014	JPB	Created
	8/18/2014	JPB	Corrected an error where un-invoiced flash lines could be left out if they were in preview status.
					(an insert to #Billing from Receipt omitted them because they already existed in BILLING, but it was
					not checking the status_code = 'I' condition, thus omitting receipts on Preview Invoices inadvertently.)
	02/02/2015	JPB	Sarah M. reported a condition in late 2014 where certain receipts did not appear on the unbilled/disposed
					report and asked why, when they WERE disposed, and were not on an invoice at that time.
					Answer was a gap in selects - Invoiced + not-submitted was leaving out submitted but not yet inoviced.
					Fixed.	
	09/10/2015	JPB Sarah M requests new search options & output fields:
					Additions to Output:
						Add Customer NAICS
						Add Customer Type
						Add Generator ID
						Add Generator Name
						Add Generator EPA ID
						Add Generator NAICS
						Add Job Type
						For Ultimate_Disposal_Date and Invoice_date, if the field doesnÆt have a value, instead of 1/1/1900, leave this field blank.
	02/06/2017	RWB	Added AX-related columns to #BillingDetail, so execution of stored procs that populate it succeed 	
	06/21/2017 JPB	GEM-44108 - Fix for new field in #BillingDetail: disc_amount	
	10/04/2017	MPM	Changed how the #ContainerInventory table gets created, so that this proc doesn't choke when columns are added to ContainerDestination.			
	02/15/2018 MPM	Added currency_code column to #BillingDetail
	03/09/2018	JPB	currency_code also required on #Billing, #Flashwork.  Also needed new export templates with currency_code included.
	06/11/2018	RWB	Add AX dimensions to #FlashWork table and populate
	07/08/2019	JPB	Cust_name: 40->75
	11/23/2020  JPB DO:17579 remove JDE columns, add AX columns
	05/05/2021  JPB Bug converting super small float to numeric it the pct_open field.  Defined it as a more capable type.
	03/31/2023	JPB	Modified to quit using plt_export..sp_export_to_excel.
					Now just selects results out, then an additional recordset with names of the previous recordsets
					for the SQL-CSV export logic.
	07/08/2024 KS	Rally116985 - Modified service_desc_1 datatype to VARCHAR(100) for #Billing table and modified SUBSTR to 100 for this column.

Sample

-- sp_sequence_next 'reportlog.report_log_id'

	sp_rpt_container_billing_status 
		@Report_Type		= 'BU'	-- Or 'UD'.  This is an amalgam of these individual script parameters...
		, @start_date		= '7/1/2014'
		, @end_date			= '7/31/2014'
		, @report_log_id	= 271714

sp_rpt_container_billing_status_bu '07/1/2015', '7/5/2015', 'JONATHAN', 307, 337371
sp_rpt_container_billing_status_ud '01/1/2018', '1/15/2018', 'JONATHAN', 307, 337371

	
-- SELECT * FROM plt_export..export where report_log_id = 271714

***************************************************************************************************** */
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- declare @Report_Type		varchar(2) = 'BU' , @start_date	datetime	= '7/1/2014'	, @end_date	datetime		= '7/31/2014'


-- If the @@end_date's hour value is 0, it's been given as just a date.  Extended it through end-of-day on that date.
if datepart(hh, @end_date ) = 0 set @end_date = @end_date + 0.99999

declare 
	@billed_flag		char(1)		= 'U'	-- 'B'illed or 'U'nbilled (Billed = Invoiced)	IMPORTANT!!  'B'illed + 'D'isposed would be a horrible thing to do.
	, @disposed_flag	char(1)		= 'D'	-- 'D'isposed or 'U'ndisposed									Don't run it.
	, @report_name		varchar(30) = ''
	, @report_user		varchar(10) = ''
	, @debug			int			= 0
	, @timerstart		datetime	= getdate()

set @billed_flag = left(@Report_Type, 1)
set @disposed_flag = right(@Report_Type, 1)

if @Report_Type = 'BU' set @Report_Name = 'Billed-Undisposed'
if @Report_Type = 'UD' set @Report_Name = 'Unbilled-Disposed'

if @report_log_id is not null
	select @report_user = user_code from reportlog where report_log_id = @report_log_id

if @report_user is null
	select @report_user = system_user

drop table if exists #debug_messages
create table #debug_messages (
	debug_id		int		not null		identity(1,1)
	, debug_time	datetime	not null
	, debug_message	varchar(200)
)

if @debug > 0 begin
	insert #debug_messages values (getdate(), 'Report User = ' + @Report_user)
	select * from #debug_messages where debug_id = @@identity
end

-- Create ContainerInventory table:
/*
	CREATE TABLE #ContainerInventory (
		
		-- Meta info fields about the disposition of a container's history/tree:

			generation					int				-- The recursive generation in which this record was found.
														--  Remember, this works backwards... 0 is the LAST (most current) record.
			, ultimate_disposal_status	varchar(10)		-- If the last record for this container's tree is open/closed, they ALL are the same.
			, ultimate_disposal_date	datetime		-- Disposal date of the last record for this container's tree
			, inventory_receipt_id		int				-- The receipt_id that appears(or appeared) on inventory at the as_of_date
														--  that was the last record for this container's tree.
			, inventory_line_id			int				-- Related to the inventory_receipt_id, obviously.
			, inventory_container_id	int				-- Related to the inventory_ receipt & line id's
			, inventory_sequence_id		int				-- Related to the inventory_container_id
		
		-- Now all fields from ContainerDestination:
		--	sp_columns ContainerDestination

			, profit_ctr_id				int
			, container_type			char(1)
			, receipt_id				int
			, line_id					int
			, container_id				int
			, sequence_id				int
			, container_percent			int
			, treatment_id				int
			, location_type				char(1)
			, location					varchar(15)
			, tracking_num				varchar(15)
			, cycle						int
			, disposal_date				datetime
			, tsdf_approval_code		varchar(40)
			, waste_stream				varchar(10)
			, base_tracking_num			varchar(15)
			, base_container_id			int
			, waste_flag				char(1)
			, const_flag				char(1)
			, status					char(1)
			, date_added				datetime
			, date_modified				datetime
			, created_by				varchar(8)
			, modified_by				varchar(8)
			, modified_from				varchar(2)
			, TSDF_approval_bill_unit_code	varchar(4)
			, company_id				int
			, OB_profile_ID				int
			, OB_profile_company_ID		int
			, OB_profile_profit_ctr_id	int
			, TSDF_approval_id			int
			, base_sequence_id			int
	)
*/

	SELECT TOP 0
		 CAST(NULL AS INT) generation
		 , CAST(NULL AS VARCHAR(10)) ultimate_disposal_status
		 , CAST(NULL AS DATETIME) ultimate_disposal_date
		 , CAST(NULL AS INT) inventory_receipt_id
		 , CAST(NULL AS INT) inventory_line_id
		 , CAST(NULL AS INT) inventory_container_id
		 , CAST(NULL AS INT) inventory_sequence_id
		 , *
	INTO #ContainerInventory
	FROM ContainerDestination 
	WHERE 1=0

	-- and index...
	create index idx_tmp on #ContainerInventory (
		company_id
		, profit_ctr_id
		, receipt_id
		, line_id
		, container_id
		, sequence_id
		, container_type
		, generation
	)

-- Populate the table:
exec sp_container_inventory_Calc
	NULL -- @copc_list			-- Optional list of companies/profitcenters to limit by
	, @disposed_flag			-- 'D'isposed or 'U'ndisposed
	, @end_date					-- Billing records are run AS OF @as_of_date. Defaults to current date.
	-- , @report_log_id

if @debug > 0 begin
	insert #debug_messages values (getdate(), 'sp_container_inventory_Calc Finished')
	select * from #debug_messages where debug_id = @@identity
end


drop table if exists #output
drop table if exists #FlashWork
drop table if exists #SalesTax
drop table if exists #Receipt
drop table if exists #tmp_trans_copc
drop table if exists #tmp_source
drop table if exists #Billing
drop table if exists #BillingComment
drop table if exists #BillingDetail
drop table if exists #Result


-- Create a table of key fields for Receipts
create table #Receipt (
	company_id			int
	, profit_ctr_id		int
	, receipt_id		int
	, line_id			int
	, manifest			varchar(20)
	, manifest_line		int
	, container_count	int
	, ultimate_disposal_date datetime
)

if @disposed_flag = 'D'	-- 'D'isposed is in #ContainerInventory (Disposed). Join that to Receipt

	insert #Receipt
	select distinct
		r.company_id		
		, r.profit_ctr_id	
		, r.receipt_id	
		, r.line_id		
		, r.manifest		
		, r.manifest_line	
		, r.container_count
		, MAX(c.ultimate_disposal_date) as ultimate_disposal_date
	from Receipt r	 (nolock) 
	inner join #ContainerInventory c 
		on r.receipt_id = c.receipt_id
		and r.line_id = c.line_id
		and r.company_id = c.company_id
		and r.profit_ctr_id = c.profit_ctr_id
		and c.ultimate_disposal_status = 'Disposed'
	where c.status = 'C'
	group by
		r.company_id		
		, r.profit_ctr_id	
		, r.receipt_id	
		, r.line_id		
		, r.manifest		
		, r.manifest_line	
		, r.container_count
		
ELSE -- Open Containers are in... #ContainerInventory (Undisposed).

	insert #Receipt
	select distinct
		r.company_id		
		, r.profit_ctr_id	
		, r.receipt_id	
		, r.line_id		
		, r.manifest		
		, r.manifest_line	
		, r.container_count
		, MAX(c.ultimate_disposal_date) as ultimate_disposal_date
	from Receipt r	 (nolock) 
	inner join #ContainerInventory c 
		on r.receipt_id = c.receipt_id
		and r.line_id = c.line_id
		and r.company_id = c.company_id
		and r.profit_ctr_id = c.profit_ctr_id
		and c.ultimate_disposal_status = 'Undisposed'
	group by
		r.company_id		
		, r.profit_ctr_id	
		, r.receipt_id	
		, r.line_id		
		, r.manifest		
		, r.manifest_line	
		, r.container_count

if @debug > 0 begin
	insert #debug_messages values (getdate(), '#Receipt populated')
	select * from #debug_messages where debug_id = @@identity
end

-- Re-create Flash functionality to get billing & unbilled pricing data, but limit the work to #Receipt records.
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
				submitted_flag				char(1)		NULL,	--	Submitted	Flag
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
				JDE_BU					varchar(7)	NULL,
				JDE_object				varchar(5),
				waste_code_uid				int	NULL,
				station_id              varchar (max) NULL
				, job_type					char(1) NULL		-- Base or Event (B/E)
				, ultimate_disposal_date	datetime null
				, currency_code				char(3) NULL

				, AX_MainAccount		varchar(20)	NULL	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
				, AX_Dimension_1		varchar(20)	NULL	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
				, AX_Dimension_2		varchar(20)	NULL	-- AX_business_unit
				, AX_Dimension_3		varchar(20)	NULL	-- AX_department
				, AX_Dimension_4		varchar(20)	NULL	-- AX_line_of_business
				, AX_Dimension_5_Part_1		varchar(20)	NULL	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
				, AX_Dimension_5_Part_2		varchar(9)	NULL	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
				, AX_Dimension_6		varchar(20)	NULL	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
		)

		-- Create & Populate #tmp_trans_copc
		CREATE TABLE #tmp_trans_copc (
			company_id INT NULL,
			profit_ctr_id INT NULL,
			base_rate_quote_id INT NULL
		)

		INSERT #tmp_trans_copc
		SELECT Profitcenter.company_id, Profitcenter.profit_ctr_id, Profitcenter.base_rate_quote_id
		FROM ProfitCenter (nolock) 
		WHERE ProfitCenter.status = 'A'

		CREATE TABLE #tmp_source (
			trans_source				char(1)
		)
		INSERT #tmp_source
		SELECT 'R'

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
			station_id				varchar (max)
			, ultimate_disposal_date			datetime null
			, currency_code		char(3)			NULL

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
			disc_amount			decimal(18,6)	NULL,
			currency_code		char(3)			NULL
		)

		-- Prepare SalesTax records
		CREATE TABLE #SalesTax  (
			sales_tax_id		int				NULL
		)

			INSERT #FlashWork (
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
				submitted_flag				, -- Submitted Flag
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
				waste_code_uid				,
				station_id
				, job_type
				, ultimate_disposal_date
				, currency_code
				, AX_MainAccount
				, AX_Dimension_1
				, AX_Dimension_2
				, AX_Dimension_3
				, AX_Dimension_4
				, AX_Dimension_5_Part_1
				, AX_Dimension_5_Part_2
				, AX_Dimension_6
			)
			SELECT
				b.company_id,
				b.profit_ctr_id,
				b.trans_source,
				b.receipt_id,
				b.trans_type,
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
				dbo.fn_get_linked_workorders(b.company_id, b.profit_ctr_id, b.receipt_id) as linked_record, -- Wo's don't list these.  R's do.
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
				r.submitted_flag,
				b.status_code as billing_status_code,
				cb.territory_code,
				cb.billing_project_id,
				cb.project_name,
				case when b.status_code = 'I' then 'T' else 'F' end as invoice_flag,
				b.invoice_code,
				b.invoice_date,
				MONTH(b.invoice_date) as invoice_month,
				YEAR(b.invoice_date) as invoice_year,
				c.customer_id,
				c.cust_name,
				b.line_id,
				b.price_id,
				b.ref_line_id,
				b.workorder_sequence_id,
				b.workorder_resource_item,
				b.workorder_resource_type,
				b.quantity,
				bd.billing_type,
				case when bd.dist_company_id <> b.company_id or bd.dist_profit_ctr_id <> b.profit_ctr_id then 'D' else 'N' end as dist_flag,
				bd.dist_company_id,
				bd.dist_profit_ctr_id,
				replace(bd.gl_account_code, '-', '') as gl_account_code,
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
				bd.JDE_BU,
				bd.JDE_object,
				b.waste_code_uid,
				NULL as station_id
				, NULL as job_type
				, rtemp.ultimate_disposal_date
				, b.currency_code
				, bd.AX_MainAccount
				, bd.AX_Dimension_1
				, bd.AX_Dimension_2
				, bd.AX_Dimension_3
				, bd.AX_Dimension_4
				, bd.AX_Dimension_5_Part_1
				, bd.AX_Dimension_5_Part_2
				, bd.AX_Dimension_6
			FROM Billing b (nolock)
			INNER JOIN #Receipt rtemp
				ON b.receipt_id = rtemp.receipt_id
				and b.line_id = rtemp.line_id
				and b.company_id = rtemp.company_id
				and b.profit_ctr_id = rtemp.profit_ctr_id
			INNER JOIN #tmp_source ts
				ON ts.trans_source = b.trans_source
			INNER JOIN BillingDetail bd (nolock)
				ON bd.billing_uid = b.billing_uid
			INNER JOIN Receipt r (nolock)
				ON b.receipt_id = r.receipt_id
				AND b.line_id = r.line_id
				AND b.company_id = r.company_id
				AND b.profit_ctr_id = r.profit_ctr_id
			INNER JOIN customer c (nolock)
				ON b.customer_id = c.customer_id
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
			WHERE 1=1
				AND b.trans_source = 'R'
			/* 2/2/2015 - JPB: 
				This line: 
					AND b.status_code = 'I'
				Was leaving out submitted but not-yet invoiced records, which already have prices calculated.
				Fix is to not limit to Invoiced records only.
			*/
				

if @debug > 0 begin
	insert #debug_messages values (getdate(), '#Flashwork Invoiced insert finished')
	select * from #debug_messages where debug_id = @@identity
end


		INSERT #FlashWork
		SELECT DISTINCT
			Receipt.company_id,
			Receipt.profit_ctr_id,
			'R' AS trans_source,
			Receipt.receipt_id,
			Receipt.trans_type,
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
			dbo.fn_get_linked_workorders(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id) as linked_record, -- Wo's don't list these.  R's do.
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
			Receipt.submitted_flag,
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
			'N', -- Not Split, since there's no billing record to split it
			receipt.company_id,
			receipt.profit_ctr_id,
			dbo.fn_get_receipt_glaccount(receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id),
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
			JDE_BU = dbo.fn_get_receipt_JDE_glaccount_business_unit (receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id),
			JDE_object = dbo.fn_get_receipt_JDE_glaccount_object (receipt.company_id, receipt.profit_ctr_id, receipt.receipt_id, receipt.line_id),
			Receipt.waste_code_uid,
			NULL
			, NULL as job_type
			, rtemp.ultimate_disposal_date
			, ReceiptPrice.currency_code
			, dbo.fn_get_receipt_AX_gl_account (Receipt.company_id, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id, 'MAIN')
			, dbo.fn_get_receipt_AX_gl_account (Receipt.company_id, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id, 'DIM1')
			, dbo.fn_get_receipt_AX_gl_account (Receipt.company_id, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id, 'DIM2')
			, dbo.fn_get_receipt_AX_gl_account (Receipt.company_id, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id, 'DIM3')
			, dbo.fn_get_receipt_AX_gl_account (Receipt.company_id, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id, 'DIM4')
			, dbo.fn_get_receipt_AX_gl_account (Receipt.company_id, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id, 'DIM5')
			, dbo.fn_get_receipt_AX_gl_account (Receipt.company_id, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id, 'DI52')
			, dbo.fn_get_receipt_AX_gl_account (Receipt.company_id, Receipt.profit_ctr_id, Receipt.receipt_id, Receipt.line_id, 'DIM6')
			FROM Receipt (nolock)
		INNER JOIN #Receipt rtemp
			ON Receipt.receipt_id = rtemp.receipt_id
			AND Receipt.line_id = rtemp.line_id
			AND Receipt.company_id = rtemp.company_id
			AND Receipt.profit_ctr_id = rtemp.profit_ctr_id
		INNER JOIN #tmp_source ts
			ON 'R' = ts.trans_source
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
			And ProfitCenter.status = 'A'
		LEFT OUTER JOIN CustomerBilling (nolock)
			ON Receipt.customer_id = CustomerBilling.customer_id
			AND ISNULL(Receipt.billing_project_id, 0) = CustomerBilling.billing_project_id
		LEFT OUTER JOIN Generator (nolock)
			ON Receipt.generator_id = Generator.generator_id
		LEFT OUTER JOIN Customer (nolock)
			ON Receipt.customer_id = Customer.customer_id
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
		WHERE 1=1
			/* 2/2/2015 - JPB: 
				This line: 
			(Receipt.submitted_flag = 'F')
				Was filtering out submitted lines, but screwed up cases where submitted != invoiced.
				The previous insert got Invoiced items - completly Invoiced. But not submitted + hold, new, etc.
				Then this statement only got the not-submitted records.
				In sum, they left out submitted but not yet invoiced, AND they trust the submitted flag
				too much, which we frequently have to correct when an item continues to appear on flash
				after it's been submitted because 2 users had it open and the 2nd save wiped out the 1st submit flag.
				
				Better version of this intended logic:
				(and not exists (select 1 from billing ...join...))
			*/
			AND NOT EXISTS (select 1 from Billing br
				where br.receipt_id = rtemp.receipt_id
				and br.line_id = rtemp.line_id
				and br.company_id = rtemp.company_id
				and br.profit_ctr_id = rtemp.profit_ctr_id
			)
			-- AND COALESCE(wos.date_act_arrive, woh.start_date, receipt.receipt_date) BETWEEN @date_from AND @date_to
			AND Receipt.fingerpr_status IN ('W', 'H', 'A')		/* Wait, Hold, Accepted */
			AND Receipt.receipt_status NOT IN ('V','R','T','X')

if @debug > 0 begin
	insert #debug_messages values (getdate(), '#Flashwork unsubmitted insert Finished')
	select * from #debug_messages where debug_id = @@identity
end

		INSERT #FlashWork
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
			k.submitted_flag				, -- Submitted Flag
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
			k.line_id						, -- Receipt line id
			k.price_id					, -- Receipt line price id
			k.ref_line_id					, -- Billing reference line_id (which line does this refer to?)
			k.workorder_sequence_id		, -- Workorder sequence id
			k.workorder_resource_item		, -- Workorder Resource Item
			k.workorder_resource_type		, -- Workorder Resource Type
			k.Workorder_resource_category , -- Workorder Resource Category
			k.quantity					, -- Receipt/Workorder Quantity
			'Product'					, -- (billing_type) 'Energy', 'Insurance', 'Salestax' etc.
			case when pqd2.dist_company_id <> k.company_id or pqd2.dist_profit_ctr_id <> k.profit_ctr_id then 'D' else 'N' end,
			ISNULL(pqd2.dist_company_id, k.company_id),
			ISNULL(pqd2.dist_profit_ctr_id, k.profit_ctr_id),
			--prod.gl_account_code				, -- GL Account for the revenue
			dbo.fn_get_receipt_glaccount(k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id), -- GL Account for the revenue
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
			JDE_BU = dbo.fn_get_receipt_JDE_glaccount_business_unit (k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id),
			JDE_object = dbo.fn_get_receipt_JDE_glaccount_object (k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id),
			k.waste_code_uid,
			k.station_id
			, k.job_type
			, k.ultimate_disposal_date
			, k.currency_code
			, dbo.fn_get_receipt_AX_gl_account (k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id, 'MAIN')
			, dbo.fn_get_receipt_AX_gl_account (k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id, 'DIM1')
			, dbo.fn_get_receipt_AX_gl_account (k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id, 'DIM2')
			, dbo.fn_get_receipt_AX_gl_account (k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id, 'DIM3')
			, dbo.fn_get_receipt_AX_gl_account (k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id, 'DIM4')
			, dbo.fn_get_receipt_AX_gl_account (k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id, 'DIM5')
			, dbo.fn_get_receipt_AX_gl_account (k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id, 'DI52')
			, dbo.fn_get_receipt_AX_gl_account (k.company_id, k.profit_ctr_id, k.receipt_id, k.line_id, 'DIM6')
		FROM #FlashWork k
		INNER JOIN ProfileQuoteDetail pqd1 (nolock)
			ON k.profile_id = pqd1.profile_id
			AND k.company_id = pqd1.company_id
			AND k.profit_ctr_id = pqd1.profit_ctr_id
			AND k.bill_unit_code = pqd1.bill_unit_code
			AND pqd1.record_type = 'D'
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

if @debug > 0 begin
	insert #debug_messages values (getdate(), '#Flashwork Product insert Finished')
	select * from #debug_messages where debug_id = @@identity
end

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
		fw.station_id
		, fw.ultimate_disposal_date
		, ReceiptPrice.currency_code
	FROM
		#FlashWork fw
		INNER JOIN Receipt (nolock)
			ON fw.trans_source = 'R' and fw.invoice_flag = 'F' and fw.submitted_flag = 'F'
			and fw.receipt_id = Receipt.receipt_id
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
		AND ISNULL(receipt.submitted_flag,'F') = 'F'
		AND (ISNULL(receipt.optional_flag, 'F') = 'F' 
			OR receipt.optional_flag = 'T' AND receipt.apply_charge_flag = 'T')
		AND NOT EXISTS (SELECT 1 FROM Billing (nolock) 
			WHERE receiptPrice.company_id = Billing.company_id
			AND receiptPrice.profit_ctr_id = Billing.profit_ctr_id
			AND receiptPrice.receipt_id = Billing.receipt_id
			AND receiptPrice.line_id = Billing.line_id
			AND receiptPrice.price_id = Billing.price_id
			AND Billing.trans_source = 'R'
			AND Billing.status_code = 'I' -- 2014/08/18
			)

if @debug > 0 begin
	insert #debug_messages values (getdate(), '#Billing insert finished')
	select * from #debug_messages where debug_id = @@identity
end

		EXEC sp_billing_submit_calc_receipt_charges
		EXEC sp_billing_submit_calc_surcharges_billingdetail 0

if @debug > 0 begin
	insert #debug_messages values (getdate(), 'sp_billing_submit_calc* Finished')
	select * from #debug_messages where debug_id = @@identity
end
		
	UPDATE #Billing 
		SET insr_extended_amt = (SELECT SUM(extended_amt) 
								FROM #BillingDetail bd  (nolock) 
								WHERE bd.billing_uid = #Billing.billing_uid 
								AND bd.billing_type = 'Insurance'),
			insr_percent = (SELECT MAX(applied_percent)
							FROM #BillingDetail bd  (nolock) 
							WHERE bd.billing_uid = #Billing.billing_uid 
							AND bd.billing_type = 'Insurance')

	UPDATE #Billing 
		SET ensr_extended_amt = (SELECT SUM(extended_amt) 
								FROM #BillingDetail bd (nolock) 
								WHERE bd.billing_uid = #Billing.billing_uid	
								AND bd.billing_type = 'Energy'),
			ensr_percent = (SELECT MAX(applied_percent)
							FROM #BillingDetail bd  (nolock) 
							WHERE bd.billing_uid = #Billing.billing_uid 
							AND bd.billing_type = 'Energy')
	
if @debug > 0 begin
	insert #debug_messages values (getdate(), '#Billing Updates Finished')
	select * from #debug_messages where debug_id = @@identity
end
	
		-- Now have to get receipt data back into #FlashWork
		delete from #FlashWork from #Flashwork fw
		inner join #Billing b
			on fw.receipt_id = b.receipt_id
			and fw.company_id = b.company_id
			and fw.profit_ctr_id = b.profit_ctr_id
			and fw.line_id = b.line_id
			and fw.price_id = b.price_id
			AND fw.trans_source = b.trans_source
		where fw.trans_source = 'R'

		INSERT #FlashWork (
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
			submitted_flag				, -- Submitted Flag
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
			waste_code_uid				,
			station_id
			, job_type
			, ultimate_disposal_date
			, currency_code
			, AX_MainAccount
			, AX_Dimension_1
			, AX_Dimension_2
			, AX_Dimension_3
			, AX_Dimension_4
			, AX_Dimension_5_Part_1
			, AX_Dimension_5_Part_2
			, AX_Dimension_6
		)
		SELECT
			b.company_id,
			b.profit_ctr_id,
			b.trans_source,
			b.receipt_id,
			b.trans_type,
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
			dbo.fn_get_linked_workorders(b.company_id, b.profit_ctr_id, b.receipt_id) as linked_record, -- Wo's don't list these.  R's do.
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
			r.submitted_flag,
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
			bd.JDE_BU,
			bd.JDE_object,
			b.waste_code_uid,
			NULL as station_id
			, NULL as job_type
			, b.ultimate_disposal_date
			, b.currency_code
			, bd.AX_MainAccount
			, bd.AX_Dimension_1
			, bd.AX_Dimension_2
			, bd.AX_Dimension_3
			, bd.AX_Dimension_4
			, bd.AX_Dimension_5_Part_1
			, bd.AX_Dimension_5_Part_2
			, bd.AX_Dimension_6
		FROM #Billing b
		INNER JOIN #BillingDetail bd
			ON b.billing_uid = bd.billing_uid
		INNER JOIN Receipt r (nolock)
			ON b.receipt_id = r.receipt_id
			AND b.line_id = r.line_id
			AND b.company_id = r.company_id
			AND b.profit_ctr_id = r.profit_ctr_id
		INNER JOIN customer c (nolock)
			ON b.customer_id = c.customer_id
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
		WHERE b.trans_source = 'R'

if @debug > 0 begin
	insert #debug_messages values (getdate(), '#Flashwork insert from #Billing Finished')
	select * from #debug_messages where debug_id = @@identity
end


-- set job_types as in flash: 
-- Assign Job Type: Base/Event.
update #FlashWork set job_type = 'B' -- Default	

/* Update Job type to Event on event jobs.  defaulted to "B" since there were so many
null and blank values, retail stays Base */
update #FlashWork set
	job_type = 'E'
from #FlashWork
INNER JOIN profilequoteheader pqh
	ON #FlashWork.quote_id = pqh.quote_id
where pqh.job_type  = 'E' 
and #FlashWork.trans_source = 'R'

/*
-- This version of flash doesn't handle work orders - receipts with container/disposal only.
update #FlashWork set
	job_type = 'E'
from #FlashWork tw
inner join workorderquoteheader qh
	on tw.quote_id = qh.quote_id
	and tw.company_id = qh.company_id
	and qh.job_type  = 'E' 
where 1=1
And tw.trans_type = 'O'
and tw.trans_source = 'W'
*/

-- Set default values for otherwise null fields.
update #FlashWork set quantity_flag = 'F' where quantity_flag is null
update #FlashWork set link_flag = 'F' where link_flag is null
update #FlashWork 
	set gl_native_code = left(gl_account_code, 5), 
		gl_dept_code = right(gl_account_code, 3) 
where gl_account_code is not null

update #FlashWork set invoice_flag = 'F' where invoice_code is null


-- drop table #result


SELECT 
case when exists ( 
		select 1 from #ContainerInventory o 
		where f.receipt_id = o.receipt_id 
		AND f.line_id = o.line_id 
		and f.company_id = o.company_id 
		and f.profit_ctr_id = o.profit_ctr_id 
		and o.ultimate_disposal_status = 'Undisposed'
	) then 'Open'
else
	case when exists ( 
			select 1 from #ContainerInventory o 
			where f.receipt_id = o.receipt_id 
			AND f.line_id = o.line_id 
			and f.company_id = o.company_id 
			and f.profit_ctr_id = o.profit_ctr_id 
			and o.ultimate_disposal_status = 'Disposed'
			and o.status = 'C'
		) then 'Closed'
	else
		'Unknown'
	end
end as Container_Status
, case when (f.invoice_flag = 'F' or ( f.invoice_flag = 'T' and f.invoice_date > @end_date ) ) then 'UnBilled'
	else
		case when (f.invoice_flag = 'T' and ( f.invoice_date between @start_date and @end_date ) ) then 'Became Billed'
			else 
				case when (f.invoice_flag = 'T' and ( f.invoice_date< @start_date ) ) then 'Already Billed'
					else
						'Unknown'
				end
		end
end as PeriodBillingStatus
, f.*
into #Result 
FROM #FlashWork f
WHERE f.billing_type = 'Disposal'

if @debug > 0 begin
	insert #debug_messages values (getdate(), '#Result Finished')
	select * from #debug_messages where debug_id = @@identity
end


select 
b.company_id
, b.profit_ctr_id
, b.trans_date
, b.customer_id
, b.cust_name
, b.generator_id
, b.generator_name
, b.epa_id
, b.receipt_id
, b.line_id
, convert(varchar(20), null) as manifest
, convert(varchar(20), null) as manifest_line
, b.approval_desc -- service_desc_1
, b.invoice_code
, b.invoice_date
, b.ultimate_disposal_date
, 0 /* isnull(r.container_count, 0) */ as total_containers
, isnull(c.open_container_count , 0) as open_containers
, sum(isnull(b.extended_amt /*bd.extended_amt*/, 0)) as total_amount
, convert(numeric(20,15), 100.00) /* isnull(round(case WHEN isnull(r.container_count, 0) > 0 THEN ((c.open_container_count) / convert(float,r.container_count)) * 100.00 else NULL end, 1), 0) */ as pct_open
, convert(money, null) /* isnull(case WHEN isnull(r.container_count, 0) > 0 THEN sum(b.extended_amt /*bd.extended_amt*/) * ((c.open_container_count * 1.00) / (r.container_count * 1.00))  ELSE NULL END, 0) */ as open_amount
, convert(money, null) /* isnull(case WHEN isnull(r.container_count, 0) > 0 THEN sum(b.extended_amt /*bd.extended_amt*/) - (sum(b.extended_amt /*bd.extended_amt*/) * ((c.open_container_count * 1.00) / (r.container_count * 1.00)))  ELSE NULL END, 0) */ as completed_amount
, b.dist_company_id /*bd.dist_company_id*/
, b.dist_profit_ctr_id /*bd.dist_profit_ctr_id*/
, b.billing_type /*bd.billing_type*/
, b.JDE_BU /*bd.JDE_BU*/
, b.JDE_object /*bd.JDE_object*/
, ISNULL(b.JDE_BU /*bd.JDE_BU*/, '') + '-' + ISNULL(b.JDE_object /*bd.JDE_object*/, '') as JDE_BU_object
, b.job_type
, b.currency_code
, b.AX_MainAccount
, b.AX_Dimension_1
, b.AX_Dimension_2
, b.AX_Dimension_3
, b.AX_Dimension_4
, b.AX_Dimension_5_Part_1
, b.AX_Dimension_5_Part_2
, b.AX_Dimension_6
, dbo.fn_convert_AX_gl_account_to_D365(
	-- '60145-142-2350-172-5000-120-'
		isnull ( b.AX_MainAccount, '' ) + '-' 
		+ isnull( b.AX_Dimension_1,'') + '-' 
		+ isnull( b.AX_Dimension_2,'') + '-' 
		+ isnull( b.AX_Dimension_3,'') + '-' 
		+ isnull( b.AX_Dimension_4,'') + '-' 
		+ isnull( b.AX_Dimension_6,'') + '-' 
		+ isnull( b.AX_Dimension_5_part_1,'')
        + case when COALESCE( b.AX_Dimension_5_part_2,'') <> ''
         then '.' + isnull( b.AX_Dimension_5_part_2,'')
		 else ''
		 end
 	)
	as AX_Account
into #output
from 
#Result a
/* 
inner join Receipt r (nolock) 
	on a.receipt_id = r.receipt_id
	and a.line_id = r.line_id
	and a.company_id = r.company_id
	and a.profit_ctr_id = r.profit_ctr_id
*/
inner join #FlashWork b 
	on a.receipt_id = b.receipt_id 
	and a.line_id = b.line_id 
	and a.price_id = b.price_id
	and a.company_id = b.company_id 
	and a.profit_ctr_id = b.profit_ctr_id
	and b.trans_source = 'R'
	and b.billing_type = 'Disposal'
-- left join BillingDetail bd on b.billing_uid = bd.billing_uid
-- 	and bd.billing_type in ('Disposal')
	-- This is including surcharges, and that's wrong. Should only be the disposal charges, not product, surcharge, tax, trans, etc. FIX.		
left join (
	select 
		receipt_id
		, line_id
		, company_id
		, profit_ctr_id
		, count(distinct c.container_id) as open_container_count
	from
	#ContainerInventory c 
	where c.ultimate_disposal_status = 'Undisposed'
	group by
		receipt_id
		, line_id
		, company_id
		, profit_ctr_id
) c	
		on a.receipt_id = c.receipt_id
		and a.line_id = c.line_id
		and a.company_id = c.company_id
		and a.profit_ctr_id = c.profit_ctr_id
		
where exists (select 1 from Receipt r (nolock) 
	where a.receipt_id = r.receipt_id
	and a.line_id = r.line_id
	and a.company_id = r.company_id
	and a.profit_ctr_id = r.profit_ctr_id
	and r.trans_mode = 'I' and r.trans_type = 'D'
)
and 1 = case @billed_flag
	when 'B' then 
		case when a.PeriodBillingStatus in ('Already Billed', 'Became Billed') then 1 else 0 end
	when 'U' then 
		case when a.PeriodBillingStatus = 'UnBilled' then 1 else 0 end
	else 0
end
/*
and 1 = case @disposed_flag
	when 'D' then 
		case when a.Container_Status = 'Closed' then 1 else 0 end
	when 'U' then 
		case when a.Container_Status = 'Open' then 1 else 0 end
	else 0
end
*/
-- regarding date period inclusion/exclusion...
-- Unbilled + Disposed means the disposal date was within the date range
--		That's already handled by the #WContainer logic.  So if it's here, it was there, all good.
-- Billed + UnDisposed means the invoice date was within the date range
--		That's handled above by saying the @billed_flag B value must have a PeriodBillingStatus of 'Became Billed', meaning invoiced within period.  Good.
-- Unbilled + Undisposed means the receipt date was within the date range.
--		That's not handled anywhere yet.  SO...
and 1 = case  -- special case for Unbilled, Undisposed - where receipt date must be within period...
	when @disposed_flag = 'U' and @billed_flag = 'U'
	then 
		case when b.trans_date <= @end_date then 1 else 0 end
	else 1
end
-- and a.receipt_id = 1000030
group by 
b.company_id
, b.profit_ctr_id
, b.trans_date
, b.customer_id
, b.cust_name
, b.generator_id
, b.generator_name
, b.epa_id
, b.receipt_id
, b.line_id 
--, r.manifest
--, r.manifest_line
, c.open_container_count
, b.approval_desc /*service_desc_1*/
, b.invoice_code
, b.invoice_date
, b.ultimate_disposal_date
--, r.container_count
, b.dist_company_id /*bd.dist_company_id*/
, b.dist_profit_ctr_id /*bd.dist_profit_ctr_id*/
, b.billing_type /*bd.billing_type*/
, b.JDE_BU /*bd.JDE_BU*/
, b.JDE_object /*bd.JDE_object*/
, ISNULL(b.JDE_BU /*bd.JDE_BU*/, '') + '-' + ISNULL(b.JDE_object /*bd.JDE_object*/, '')
, b.job_type
, b.currency_code
, b.AX_MainAccount
, b.AX_Dimension_1
, b.AX_Dimension_2
, b.AX_Dimension_3
, b.AX_Dimension_4
, b.AX_Dimension_5_Part_1
, b.AX_Dimension_5_Part_2
, b.AX_Dimension_6

if @debug > 0 begin
	insert #debug_messages values (getdate(), '#output creation Finished')
	select * from #debug_messages where debug_id = @@identity
end

-- SELECT * FROM #output

-- Now update slug fields in #output from Receipt
update #Output set
 manifest = r.manifest
, manifest_line = r.manifest_line
, total_containers = isnull(r.container_count, 0) 
, pct_open = isnull(round(case WHEN isnull(r.container_count, 0) > 0 THEN ((a.open_containers) / convert(float,r.container_count)) * 100.00 else NULL end, 1), 0)
, open_amount = isnull(case WHEN isnull(r.container_count, 0) > 0 THEN a.total_amount * ((a.open_containers * 1.00) / (r.container_count * 1.00))  ELSE NULL END, 0)
, completed_amount = isnull(case WHEN isnull(r.container_count, 0) > 0 THEN (a.total_amount) - ((a.total_amount ) * ((a.open_containers * 1.00) / (r.container_count * 1.00)))  ELSE NULL END, 0) 
from #output a
inner join Receipt r (nolock) 
	on a.receipt_id = r.receipt_id
	and a.line_id = r.line_id
	and a.company_id = r.company_id
	and a.profit_ctr_id = r.profit_ctr_id

if @debug > 0 begin
	insert #debug_messages values (getdate(), '#output update Finished')
	select * from #debug_messages where debug_id = @@identity
end

/*
select
	case @billed_flag
		when 'B' then 'Billed'
		when 'U' then 'Unbilled'
		else 'Unknown'
	end
	+ ' '
	+ case @disposed_flag
		when 'U' then 'Undisposed'
		when 'D' then 'Disposed'
		else 'Unknown'
	end
	+ ' '
	+ 'Through ' + replace(CONVERT(varchar(12), @end_date, 101), '/', '-')
*/

-- Above generates temp tables.

-- Below generates output tables


-- !!! Cannot find any samples of creating a spreadsheet with multiple worksheets.
-- !!! So create separate files of output.

declare @unique_table varchar(60), @sql varchar(max), @filename varchar(100)
set @unique_table = replace(replace(replace(replace(convert(varchar(60), getdate(), 121), ' ', '_'), ':', '_'), '-', '_'), '.', '_') + '_' + @report_user

DECLARE @export_id int, @source varchar(100), @gen_name varchar(100), @this_name varchar(100), @template varchar(100), @template_Short_name varchar(100)
select @gen_name = 'Container Billing Status (' + @Report_Name + ', ' + convert(varchar(12), @start_date, 101) + ' - ' + convert(varchar(12), @end_date, 101) + ') '

declare @recordsetname table (
	recordsetnumber	int identity(1,1),
	recordsetname varchar(30)
)

-- Detail:
set @template_Short_name = 'Detail'
set @template = 'container_billing_status_template_detail_v5'
set @source = '##' + @template + '_' + @unique_table
set @filename = @Report_Name + '-' + convert(varchar(12), @start_date, 101) + '--' + convert(varchar(12), @end_date, 101) + '-' + @template_Short_name + '-' + @unique_table
set @filename = replace(replace(@filename, ' ', '-'), '/', '-') + '.xlsx'
set @sql = '
	SELECT 
		o.company_id
		, o.profit_ctr_id
		, o.trans_date
		, o.customer_id
		, o.cust_name
		, c.cust_naics_code
		, c.customer_type
		, o.generator_id
		, o.generator_name
		, o.epa_id
		, g.naics_code as generator_naics_code
		, o.job_type
		, o.receipt_id
		, o.line_id
		, convert(varchar(20), null) as manifest
		, convert(varchar(20), null) as manifest_line
		, o.approval_desc -- service_desc_1
		, o.invoice_code
		, o.invoice_date
		, coalesce(convert(varchar(10), o.ultimate_disposal_date, 101), '''') as ultimate_disposal_date
		, o.total_containers
		, o.open_containers
		, o.total_amount
		, o.pct_open
		, o.open_amount
		, o.completed_amount
		, o.dist_company_id
		, o.dist_profit_ctr_id
		, o.billing_type
		, o.currency_code
		, o.AX_MainAccount
		, o.AX_Dimension_1
		, o.AX_Dimension_2
		, o.AX_Dimension_3
		, o.AX_Dimension_4
		, o.AX_Dimension_5_Part_1
		, o.AX_Dimension_5_Part_2
		, o.AX_Dimension_6
		, o.AX_Account
	/* INTO ' + @source + ' */
	FROM #output o
	inner join profitcenter p 
		on o.company_id = p.company_id 
		and o.profit_ctr_id = p.profit_ctr_id 
		and p.status = ''A''
	left join customer c on o.customer_id = c.customer_id
	left join generator g on o.generator_id = g.generator_id
	order by 
		o.company_id, o.profit_ctr_id, o.receipt_id, o.line_id
'
exec(@sql)
insert @recordsetname (recordsetname) values (@template_short_name)

--set @sql = 'select * from ' + @source
--exec(@sql)
		
select @this_name = @gen_name + @template_short_name

EXEC @export_id = plt_export..sp_export_to_excel @source, @template, @filename, @report_user, @this_name, @report_log_id, @debug

if @debug > 0 begin
	insert #debug_messages values (getdate(), 'Excel Output: Detail Finished')
	select * from #debug_messages where debug_id = @@identity
end

/*
-- GL Summary
set @template_Short_name = 'GL Summary'
set @template = 'container_billing_status_template_gl_summary_v2'
set @source = '##' + @template + '_' + @unique_table
set @filename = @Report_Name + '-' + convert(varchar(12), @start_date, 101) + '--' + convert(varchar(12), @end_date, 101) + '-' + @template_Short_name + '-' + @unique_table
set @filename = replace(replace(@filename, ' ', '-'), '/', '-') + '.xlsx'
set @sql = '
	select 
		jde_bu as [JDE BU], jde_object as [JDE Object], jde_bu_object as [JDE BU-Object], currency_code as [CurrencyCode], sum(open_amount) as [Total] 
	INTO ' + @source + '
	from #output
	group by 
		jde_bu, jde_object, jde_bu_object, currency_code
	order by 
		jde_bu, jde_object, jde_bu_object
'
exec(@sql)
		
select @this_name = @gen_name + @template_short_name
EXEC @export_id = plt_export..sp_export_to_excel @source, @template, @filename, @report_user, @this_name, @report_log_id, @debug

if @debug > 0 begin
	insert #debug_messages values (getdate(), 'Excel Output: GL Summary Finished')
	select * from #debug_messages where debug_id = @@identity
end
*/

-- Inventory Summary:
set @template_Short_name = 'Inventory Summary'
set @template = 'container_billing_status_template_inventory_summary'
set @source = '##' + @template + '_' + @unique_table
set @filename = @Report_Name + '-' + convert(varchar(12), @start_date, 101) + '--' + convert(varchar(12), @end_date, 101) + '-' + @template_Short_name + '-' + @unique_table
set @filename = replace(replace(@filename, ' ', '-'), '/', '-') + '.xlsx'
set @sql = '
	select 
		company_id, profit_ctr_id, count(*) as [Undisposed Count]
	/* INTO ' + @source + ' */
	from (
		select distinct 
			company_id, profit_ctr_id, inventory_receipt_id, inventory_line_id, inventory_container_id, inventory_sequence_id 
			from #ContainerInventory
			where ultimate_disposal_status = ''Undisposed''
	) x 
	group by company_id, profit_ctr_id order by company_id, profit_ctr_id 
'
exec(@sql)
insert @recordsetname (recordsetname) values (@template_short_name)
		
select @this_name = @gen_name + @template_short_name
-- EXEC @export_id = plt_export..sp_export_to_excel @source, @template, @filename, @report_user, @this_name, @report_log_id, @debug

if @debug > 0 begin
	insert #debug_messages values (getdate(), 'Excel Output: Inventory Summary Finished')
	select * from #debug_messages where debug_id = @@identity
end

-- Inventory Reference:
set @template_Short_name = 'Inventory Reference'
set @template = 'container_billing_status_template_inventory_reference'
set @source = '##' + @template + '_' + @unique_table
set @filename = @Report_Name + '-' + convert(varchar(12), @start_date, 101) + '--' + convert(varchar(12), @end_date, 101) + '-' + @template_Short_name + '-' + @unique_table
set @filename = replace(replace(@filename, ' ', '-'), '/', '-') + '.xlsx'
set @sql = '
	select distinct 
		container_type, company_id, profit_ctr_id, receipt_id, line_id, container_id, sequence_id
		, inventory_receipt_id, inventory_line_id, inventory_container_id , inventory_sequence_id
	/* INTO ' + @source + ' */
	from #ContainerInventory
	where ultimate_disposal_status = ''Undisposed''
	order by 
		inventory_receipt_id, inventory_line_id, inventory_container_id , inventory_sequence_id
'
exec(@sql)
insert @recordsetname (recordsetname) values (@template_short_name)
		
select @this_name = @gen_name + @template_short_name
-- EXEC @export_id = plt_export..sp_export_to_excel @source, @template, @filename, @report_user, @this_name, @report_log_id, @debug

if @debug > 0 begin
	insert #debug_messages values (getdate(), 'Excel Output: Inventory Reference Finished')
	select * from #debug_messages where debug_id = @@identity
end

-- Distinct Inventory Lines
set @template_Short_name = 'Distinct Inventory'
set @template = 'container_billing_status_template_distinct_inventory'
set @source = '##' + @template + '_' + @unique_table
set @filename = @Report_Name + '-' + convert(varchar(12), @start_date, 101) + '--' + convert(varchar(12), @end_date, 101) + '-' + @template_Short_name + '-' + @unique_table
set @filename = replace(replace(@filename, ' ', '-'), '/', '-') + '.xlsx'
set @sql = '
	select distinct 
		company_id, profit_ctr_id
		, inventory_receipt_id, inventory_line_id, inventory_container_id , inventory_sequence_id
	/* INTO ' + @source + ' */
	from #ContainerInventory
	where ultimate_disposal_status = ''Undisposed''
	order by 
		inventory_receipt_id, inventory_line_id, inventory_container_id , inventory_sequence_id
'
exec(@sql)
insert @recordsetname (recordsetname) values (@template_short_name)
		
select @this_name = @gen_name + @template_short_name
-- EXEC @export_id = plt_export..sp_export_to_excel @source, @template, @filename, @report_user, @this_name, @report_log_id, @debug

if @debug > 0 begin
	insert #debug_messages values (getdate(), 'Excel Output: Distinct Inventory Lines Finished')
	select * from #debug_messages where debug_id = @@identity
end

-- Billed Inventory
set @template_Short_name = 'Inventory On Detail'
set @template = 'container_billing_status_template_inventory_on_detail'
set @source = '##' + @template + '_' + @unique_table
set @filename = @Report_Name + '-' + convert(varchar(12), @start_date, 101) + '--' + convert(varchar(12), @end_date, 101) + '-' + @template_Short_name + '-' + @unique_table
set @filename = replace(replace(@filename, ' ', '-'), '/', '-') + '.xlsx'
set @sql = '
	select distinct 
		company_id, profit_ctr_id
		, inventory_receipt_id, inventory_line_id, inventory_container_id , inventory_sequence_id
	/* INTO ' + @source + ' */
	from #ContainerInventory c
	where ultimate_disposal_status = ''Undisposed''
	and
	exists (
		select 1 from #output o
		where o.receipt_id = c.receipt_id
		and o.line_id = c.line_id
		and o.company_id = c.company_id
		and o.profit_ctr_id = c.profit_ctr_id
	)
	order by 
		company_id, profit_ctr_id
		, inventory_receipt_id, inventory_line_id, inventory_container_id , inventory_sequence_id
'
exec(@sql)
insert @recordsetname (recordsetname) values (@template_short_name)
		
select @this_name = @gen_name + @template_short_name
-- EXEC @export_id = plt_export..sp_export_to_excel @source, @template, @filename, @report_user, @this_name, @report_log_id, @debug

if @debug > 0 begin
	insert #debug_messages values (getdate(), 'Excel Output: Billed Inventory Finished')
	select * from #debug_messages where debug_id = @@identity
end

SELECT  * FROM    @recordsetname

if @debug > 0 begin
	select * from #debug_messages
end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_billing_status] TO [EQWEB]
--    AS [dbo];

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_billing_status] TO [COR_USER]
--    AS [dbo];

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_billing_status] TO [EQAI]
--    AS [dbo];


