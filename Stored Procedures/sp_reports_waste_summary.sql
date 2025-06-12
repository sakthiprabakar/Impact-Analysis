CREATE PROCEDURE [dbo].[sp_reports_waste_summary]
	@debug				int, 			-- 0 or 1 for no debug/debug mode
	@database_list		varchar(max),	-- Comma Separated Company List
	@customer_id_list	varchar(max),	-- Comma Separated Customer ID List - what customers to include
	@generator_id_list	varchar(max),	-- Comma Separated Generator ID List - what generators to include
	@approval_code_list	varchar(max),	-- Comma Separated Approval Code List - what approvals to include
	@trans_start_date	varchar(40),	-- Transaction Start Date
	@trans_end_date		varchar(40),	-- Transaction End Date
	@serv_start_date	varchar(40),	-- Service Start Date
	@serv_end_date		varchar(40),	-- Service End Date
	@report_type		char(1),		-- Group report by 'A'pproval or 'G'enerator
	@contact_id			varchar(100),	-- Contact_id
	@level				char(1) = 'S'	-- 'S'ummary or 'D'etail
AS
/****************************************************************************************************
sp_reports_waste_summary:

Returns the data for Waste Summary.

LOAD TO PLT_AI*

sp_reports_waste_summary 1, '', '17721', '', '', '01/01/2017', '12/31/2017', '', '', 'A', '-1', 'D'


sp_reports_waste_summary 0, '', '13729', '', 'H088133DET', '1/1/2013', '12/31/2013', 'A', '', 'D'
sp_reports_waste_summary 0, '', '13729', '74624', 'H088133DET', '1/1/2013', '12/31/2013', 'A', '', 'D'


sp_reports_waste_summary 0, '', '10877', NULL, NULL, '', '', '1/1/2012', '3/1/2012', 'A', '', 'D'
sp_reports_waste_summary 0, '', '888880', NULL, 'ACIDS', '', '', '1/1/1990', '12/31/2013', 'A', '', 'S'
sp_reports_waste_summary 0, '', '888880', NULL, '', '1/1/1990', '12/31/2013', 'A', '', 'S'
sp_reports_waste_summary 0, '', '888880', NULL, NULL, '1/1/1990', '12/31/2013', 'A', '', 'D'
sp_reports_waste_summary 9, '', '', NULL, 'ACIDS', '1/1/1990', '12/31/2013', 'A', '', 'D'


sp_reports_waste_summary 0, '', '888888', NULL, NULL, '', '', 'G', '', 'Y', 'D', '', 1, 5000

SELECT * FROM receiptwastecode where receipt_id = 10573 and company_id = 14 and profit_ctr_id = 6

sp_reports_waste_summary 0, '', '', '', 'ACIDLIQ', '6/1/2000', '7/1/2012', 'A', '10913', 'Y', 'S', '', 1, 5000
sp_reports_waste_summary 0, '', '10673', '', 'ACIDLIQ', '6/1/2000', '7/1/2012', 'A', null, 'Y', 'S', '', 1, 5000
sp_reports_waste_summary 6, '', '888888', '', 'ACIDLIQ', '6/1/2000', '7/1/2012', 'A', '', 'Y', 'S', '', 1, 5000

sp_reports_waste_summary 1, '', '', NULL, 'NC63056LP', '9/1/2006', '11/15/2006', 'A', '100913', '', 'Y', '', 1, 5000
sp_reports_waste_summary 1, '', '', NULL, 'NC63056LP', '9/1/2006', '11/15/2006', 'G', '101296', '', 'Y', 'D', '', 1, 5000

sp_reports_waste_summary 1, '', '001125', NULL, NULL, '1/1/2005', '8/31/2005', 'A', NULL, 'N', 'D'
sp_reports_waste_summary 0, '', '001125', NULL, NULL, '1/1/2005', '3/31/2005', 'G', NULL, 'N', 'D'
sp_reports_waste_summary 1, '', '', '44900', '', '', '', 'A', '', 'N'

-- all walmart by contact
sp_reports_waste_summary 1, '', '', '', NULL, '10/1/2006', '11/1/2006', 'A', '100913', 'Y', 'D'
sp_reports_waste_summary 1, '', '', '', NULL, '10/1/2006', '11/1/2006', 'G', '100913', 'Y';
sp_reports_waste_summary 1, '', '', '', NULL, '', '', 'A', '101295', 'Y';
sp_reports_waste_summary 0, '', '', '', NULL, '', '', 'G', '101296', 'Y';
sp_reports_waste_summary 0, '', '', '', NULL, '7/1/2006', '7/14/2006', 'G', '101295', 'Y';

sp_reports_waste_summary 0, '', '', '', NULL, '', '', 'A', '101296', 'Y';
sp_reports_waste_summary 1, '', '', '', NULL, '', '', 'G', '10036', 'Y';

-- one generator from walmart by contact, by Approval
sp_reports_waste_summary 0, '', '', '62879', NULL, '10/1/2006', '11/1/2006', 'A', '100913', 'Y';
-- one generator from walmart by contact, by Approval with Detail
sp_reports_waste_summary 1, '', '', '62879', NULL, '10/1/2006', '11/1/2006', 'A', '100913', 'Y', 'D';
-- one generator from walmart by contact, by Generator
sp_reports_waste_summary 1, '', '', '62879', NULL, '10/1/2006', '11/1/2006', 'G', '100913', 'Y';
-- one generator from walmart by contact, by Generator with Detail
	sp_reports_waste_summary 0, '', '', '62879', NULL, '10/1/2006', '11/1/2006', 'G', '100913', 'Y', 'D'

sp_reports_waste_summary 0, '', '10673', '', '', '10/1/2006', '11/1/2006', 'A', '', 'Y', 'D'
sp_reports_waste_summary 0, '', '10877, 12723, 10908', '', '', '1/1/2014', '12/31/2014', 'A', '', 'D'
	@debug				int, 			-- 0 or 1 for no debug/debug mode
	@database_list		varchar(max),	-- Comma Separated Company List
	@customer_id_list	varchar(max),			-- Comma Separated Customer ID List - what customers to include
	@generator_id_list	varchar(max),			-- Comma Separated Generator ID List - what generators to include
	@approval_code_list	varchar(max),			-- Comma Separated Approval Code List - what approvals to include
	@trans_start_date			varchar(40),	-- Start Date
	@trans_end_date			varchar(40),	-- End Date
	@report_type		char(1),		-- Group report by 'A'pproval or 'G'enerator
	@contact_id			varchar(100),	-- Contact_id
	@level				char(1) = 'S'	-- 'S'ummary or 'D'etail


suggested indexes:
plt_rpt.receipt:
create index Receipt_receipt_wsr on receipt (customer_id, generator_id, transaction_type, status, receipt_date)
plt_rpt.container:
create index Container_wsr on Container (link_Container_Receipt, container_weight, percent_of_container)

05/24/2005 JPB	Created
01/09/2006 JDB	Modified to use plt_rpt database
05/06/06   RG   modifed for contactxref 
08/10/2006 JPB  Modified so the generator filtering clause was outside of any requirement for customer list.
11/20/2006 JDB	Added "AND r.status = ''Accepted''" to the WHERE clause of this report.
		Also changed "AND EXISTS (SELECT COUNT(*) FROM ' + @report_server + '.plt_rpt' + @server_mode + '.dbo.InvoiceDetail id"
			to   "AND EXISTS (SELECT source_id FROM ' + @report_server + '.plt_rpt' + @server_mode + '.dbo.InvoiceDetail id"
11/24/2006 JDB	Modified to remove join to Container table and the calculation for lbs_waste as follows:
		CASE WHEN (SELECT SUM(IsNull(c.container_weight, 0) * (IsNull(c.percent_of_container, 0) / 100.000))
			FROM NTSQL1.plt_rpt.dbo.Container c
			WHERE c.link_Container_Receipt = r.link_Container_Receipt) = 0
			THEN (SUM(isnull(rp.quantity, 0) * isnull(b.pound_conv, 0)))
			ELSE (SELECT SUM(IsNull(c.container_weight, 0) * (IsNull(c.percent_of_container, 0) / 100.000))
			FROM NTSQL1.plt_rpt.dbo.Container c
			WHERE c.link_Container_Receipt = r.link_Container_Receipt)
			END AS lbs_waste
12/04/2006 JPB	Modified to combine inbound/outbound reporting in every query via temp table.
		Database_list is no longer used.
01/18/2007 JPB	Modified to retrieve waste_desc field instead of waste_stream for Approval Report.
01/22/2007 JPB  Modified to retrieve min/max row id in header for more precise detail scrolling
05/31/2007 JPB Modified from varchar(8000) inputs to Text inputs
10/09/2007 JPB Modified for Prod/Test/Dev, removed servermode stuff, ntsql1, etc.

02/05/2009 RJG  Modified to use the #access_filter pattern to pre-filter appropriate records before
				major query.
				There are 4 cases / types of recordsets that can be returned
				Summary by Approval
				Summary by Generator

				Detail by Approval
				Detail by Generator

				Each of these has a specific query / grouping that needs to be done
				The detail records return two result sets. The first is the master group
				list and the second is the detailed grouping information.
				
Central Invoicing:
	Changed w.status = ''Submitted'' to w.submitted_flag = ''Submitted''

03/10/2009 RJG 
		Detail by Approval - Modified detail results query to return distinct records
		Summary by Generator - Changed bad grouping logic in resulting query (was returning more records in some cases)

3/12/2009 RJG
		Removed NOT EXISTS section from the #access_filter insert
		Replaced it with SELECT DISTINCT

3/18/2009 RJG
		Removed join on InvoiceDetail and replaced with Billing

04/07/2009 RJG
		Removed joins to Container and ContainerDestination because they mess up
		how the quantity comes out.  The weight is now calculated and the container_percent is
		NOT needed anymore

04/07/2009 RJG
		Added generator city to output
		
04/13/2009 RJG	
		Implemented Jonathans changes RE: code review
		
04/14/2009 RJG	
		Implemented workorder access filter, minor refactorings & cleaning up

03/22/2010 JPB
		Removed joins to ProfileQuoteApproval and Profile for faster performance.
		(approval_desc now comes from a subquery, not a big join)
		
07/10/2012 JPB
	Modified for running without specifying a customer (Associates) during /secured/ index rewrite.

09/11/2012 JPB
	Still in /secured/index rewrite (part of Forms 2012 project):
	Convert weight calculations to those from the Biennial process.  They define "accurate" at this point.
	Add Management_Code, EPA_Form_Code, EPA_Source_Code to output

12/12/2012 DZ  Set Transaction Isolation Level to Read Uncommitted to avoid lock	

01/31/2013 JPB Fixed order of returned results bug between header/detail result sets.

03/28/2013 JPB	Handling for empty search sets. Shouldn't just run forever.
	Also converted text fields to varchar(max)

08/01/2013 JPB	Modified for TX Waste Codes

01/29/2014	JPB	Adding fields from Nisource Yearly reporting request:
					Dipsosal Facility EPA
					Transporter (1st transporter) Name, EPA
					All Waste Codes as string
					Weight Calc Update from recent CS Biennial logic.
					Also, added end-of-day logic to @trans_end_date

02/21/2014 JPB	Added a new clause to the #access_filter WHERE: "AND NOT EXISTS (...)" to avoid putting duplicates into #access_filter
				Which then creates duplication/multiplication in the result sets.

01/19/2015 JPB	Fixing bad join to WorkorderTransporter - did not contain manifest clause.

01/22/2016 JPB	Added service_date to results, converted @start_date and @end_date to @trans_* and added @serv_*date for service date searches
12/08/2017 JPB	GEM-44773 - Changed INNER joins on Work Order section to TSDF to LEFT OUTER joins, and removed requirement that they NOT be EQ tsdfs
05/25/2023 JPB  DO:30174 - Modified code to get MANAGEMENT_CODE from Treatment View instead of TreatmentHeader (Comments added by Dipankar)

****************************************************************************************************/
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE	@execute_sql		varchar(max),
	@execute_group 			varchar(max),
	@execute_order 			varchar(max),
	@generator_login_list	varchar(max),
	@intCount 				int,
	@count_cust				int,
	@genCount				int,
	@custCount				int,
	@where					varchar(max),
	@starttime				datetime,
	@session_added			datetime = getdate()
	

set @starttime = getdate()

IF @contact_id IS NULL SET @contact_id = ''

if isnull(@trans_end_date, '') <> ''
	if datepart(hh, @trans_end_date) = 0
		set @trans_end_date = convert(varchar(40), convert(datetime, @trans_end_date) + 0.99999, 121)

if isnull(@serv_end_date, '') <> ''
	if datepart(hh, @serv_end_date) = 0
		set @serv_end_date = convert(varchar(40), convert(datetime, @serv_end_date) + 0.99999, 121)

if @debug > 1 select @trans_end_date trans_end_date, @serv_end_date serv_end_date		

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Before Var setup' as description

-- Handle text inputs into temp tables
	CREATE TABLE #Customer_id_list (ID int)
	CREATE INDEX idx1 ON #Customer_id_list (ID)
	Insert #Customer_id_list select convert(int, row) from dbo.fn_SplitXsvText(',', 0, @customer_id_list) where isnull(row, '') <> ''

	CREATE TABLE #generator_id_list (ID int)
	CREATE INDEX idx2 ON #generator_id_list (ID)
	Insert #generator_id_list select convert(int, row) from dbo.fn_SplitXsvText(',', 0, @generator_id_list) where isnull(row, '') <> ''

	CREATE TABLE #approval_code_list (approval_code varchar(20))
	CREATE INDEX idx3 ON #approval_code_list (approval_code)
	Insert #approval_code_list select row from dbo.fn_SplitXsvText(',', 1, @approval_code_list) where isnull(row, '') <> ''

if @debug >= 1 print 'figure out if this user has inherent access to customers'
-- figure out if this user has inherent access to customers
    SELECT @custCount = 0, @genCount = 0
	create table #customer (customer_id int)
	create table #generator(generator_id int)
	create clustered index idx_tmp on #customer(customer_id)
	create clustered index idx_tmp on #generator(generator_id)

	IF LEN(@contact_id) > 0 and @contact_id not in ('0', '-1', '')
	BEGIN
		insert #customer (customer_id)
		select customer_id from ContactXRef cxr
			Where cxr.contact_id = convert(int, @contact_id)
			AND cxr.customer_id is not null
			AND cxr.type = 'C' AND cxr.status = 'A' and cxr.web_access = 'A'
			
		insert #generator (generator_id)
		select generator_id from ContactXRef cxr
			Where cxr.contact_id = convert(int, @contact_id)
			AND cxr.generator_id is not null
			AND cxr.type = 'G' AND cxr.status = 'A' and cxr.web_access = 'A' 
		union

		Select cg.generator_id from CustomerGenerator cg
			INNER JOIN ContactXRef cxr ON cxr.customer_id = cg.customer_id
				AND cxr.customer_id is not null
				AND cxr.type = 'C'
				AND cxr.status = 'A'
				AND cxr.web_access = 'A'
			INNER JOIN Customer c ON c.customer_ID = cg.customer_id
			WHERE cxr.contact_id = convert(int, @contact_id)
			AND c.generator_flag = 'T'
--		Select cg.generator_id from CustomerGenerator cg, ContactXRef cxr, Customer c
--			Where cxr.contact_id = convert(int, @contact_id)
--			AND cg.customer_id = cxr.customer_id
--			AND cxr.customer_id is not null
--			AND cxr.type = 'C'
--			AND cxr.status = 'A'
--			AND cxr.web_access = 'A'
--			AND cg.customer_id = c.customer_id
--			AND c.generator_flag = 'T'
	END
	ELSE -- For Associates:
	BEGIN
	
		if exists (select id from #customer_id_list where id is not null)
			INSERT INTO #customer select id from #customer_id_list where id is not null
			
		IF @debug >= 1 PRINT 'SELECT FROM #customer'
		IF @debug >= 1 SELECT * FROM #customer


		if exists (select id from #generator_id_list where id is not null)
			INSERT INTO #generator select id from #generator_id_list where id is not null
			
		IF @debug >= 1 PRINT 'SELECT FROM #generator'
		IF @debug >= 1 SELECT * FROM #generator
	END

	select @custCount = count(*) from #customer
	select @genCount = count(*) from #generator	

    IF @debug >= 1 PRINT '@custCount:  ' + convert(varchar(20), @custCount)
    IF @debug >= 1 PRINT '@genCount:  ' + convert(varchar(20), @genCount)
	if @debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'


	if @debug >= 1 BEGIN
		SELECT '#customer', * FROM #customer
		SELECT '#generator', * FROM #generator
	END

	if @debug >= 1 BEGIN
		SELECT 
			@custCount + 
			@genCount + 
			len(ltrim(rtrim(isnull(@trans_start_date, '')))) +
			len(ltrim(rtrim(isnull(@trans_end_date, '')))) +
			len(ltrim(rtrim(isnull(@serv_start_date, '')))) +
			len(ltrim(rtrim(isnull(@serv_end_date, '')))) +
			(select count(*) from #approval_code_list) as normal_abort_count,
			len(isnull(@contact_id, '')) +
			(select count(*) from #approval_code_list) +
			(select count(*) from #customer_id_list where id is not null) +
			(select count(*) from #generator_id_list where id is not null) as associate_abort_count
	END

	-- abort if there's nothing possible to see
	if @custCount + 
		@genCount + 
		len(ltrim(rtrim(isnull(@trans_start_date, '')))) +
		len(ltrim(rtrim(isnull(@trans_end_date, '')))) +
		len(ltrim(rtrim(isnull(@serv_start_date, '')))) +
		len(ltrim(rtrim(isnull(@serv_end_date, '')))) +
		(select count(*) from #approval_code_list)
		= 0 RETURN
		
	-- Extra checks for associates: You can't run without decent criteria
	if len(isnull(@contact_id, '')) +
		(select count(*) from #approval_code_list) +
		(select count(*) from #customer_id_list where id is not null) +
		(select count(*) from #generator_id_list where id is not null)
		= 0 return 

	CREATE TABLE #Work_WasteReceivedSummaryListResult (
		[company_id] [int] NULL,
		[profit_ctr_id] [int] NULL,
		[facility] [varchar](50) NULL,
		[customer_id] [int] NULL,
		[cust_name] [varchar](75) NULL,
		[approval_code] [varchar](40) NULL,
		[profile_id] [int] NULL,
		[waste_description] [varchar](150) NULL,
		[haz_flag] [char](1) NULL,
		[generator_id] [int] NULL,
		[epa_id] [varchar](12) NULL,
		[generator_name] [varchar](75) NULL,
		[generator_state] [varchar](2) NULL,
		[generator_city] [varchar](40) NULL,
		[site_code] [varchar](16) NULL,
		[bill_unit_code] [varchar](4) NULL,
		[bill_unit_desc] [varchar](40) NULL,
		[management_code] [varchar](4) NULL,
		[epa_form_code] [varchar](4) NULL,
		[epa_source_code] [varchar](3) NULL,
		[quantity] [float] NULL,
		[pound_conv] [float] NULL,
		[total_pounds] [float] NULL,
		[percent_of_container] [float] NULL,
		[mode] [varchar](20) NULL,
		[transaction_id] [varchar](20) NULL,
		[receipt_date] [datetime] NULL,
		[service_date] [datetime] NULL,
		[row_num] [int] IDENTITY(1,1) NOT NULL,
		[facility_epa_id] [varchar](20) NULL,
		[pcb_flag] [char](1) NULL,
		[transporter_code] [varchar](20) NULL,
		[transporter_name] [varchar](60) NULL,
		[transporter_epa_id] [varchar](20) NULL,
		[waste_code_list] [varchar](max) NULL,
		[weight_method] [varchar](40) NULL,
		[manifest] [varchar](20) NULL,
		[manifest_line] [int] NULL
	)

	CREATE TABLE #Work_WasteReceivedSummaryDetailResultGroups(
		[company_id] [int] NULL,
		[profit_ctr_id] [int] NULL,
		[facility] [varchar](50) NULL,
		[customer_id] [int] NULL,
		[cust_name] [varchar](75) NULL,
		[approval_code] [varchar](40) NULL,
		[profile_id] [int] NULL,
		[waste_description] [varchar](150) NULL,
		[haz_flag] [char](1) NULL,
		[generator_id] [int] NULL,
		[epa_id] [varchar](12) NULL,
		[generator_name] [varchar](75) NULL,
		[generator_state] [varchar](2) NULL,
		[generator_city] [varchar](40) NULL,
		[site_code] [varchar](16) NULL,
		[bill_unit_code] [varchar](4) NULL,
		[bill_unit_desc] [varchar](40) NULL,
		[management_code] [varchar](4) NULL,
		[epa_form_code] [varchar](4) NULL,
		[epa_source_code] [varchar](3) NULL,
		[quantity] [float] NULL,
		[haz_total_pounds] [float] NULL,
		[nonhaz_total_pounds] [float] NULL,
		[total_pounds] [float] NULL,
		[mode] [varchar](20) NULL,
		[row_num] [int] IDENTITY(1,1) NOT NULL,
		[facility_epa_id] [varchar](20) NULL,
		[pcb_flag] [char](1) NULL,
		[transporter_code] [varchar](20) NULL,
		[transporter_name] [varchar](60) NULL,
		[transporter_epa_id] [varchar](20) NULL,
		[waste_code_list] [varchar](max) NULL,
		[weight_method] [varchar](40) NULL,
		[manifest] [varchar](20) NULL,
		[manifest_line] [int] NULL
	)

	CREATE TABLE #Work_WasteReceivedSummaryDetailResultItems(
		[company_id] [int] NULL,
		[profit_ctr_id] [int] NULL,
		[facility] [varchar](50) NULL,
		[customer_id] [int] NULL,
		[cust_name] [varchar](75) NULL,
		[approval_code] [varchar](40) NULL,
		[profile_id] [int] NULL,
		[waste_description] [varchar](150) NULL,
		[haz_flag] [char](1) NULL,
		[generator_id] [int] NULL,
		[epa_id] [varchar](12) NULL,
		[generator_name] [varchar](75) NULL,
		[generator_state] [varchar](2) NULL,
		[generator_city] [varchar](40) NULL,
		[site_code] [varchar](16) NULL,
		[receipt_date] [datetime] NULL,
		[service_date] [datetime] NULL,
		[transaction_id] [varchar](20) NULL,
		[bill_unit_code] [varchar](4) NULL,
		[bill_unit_desc] [varchar](40) NULL,
		[management_code] [varchar](4) NULL,
		[epa_form_code] [varchar](4) NULL,
		[epa_source_code] [varchar](3) NULL,
		[quantity] [float] NULL,
		[haz_quantity] [float] NULL,
		[nonhaz_quantity] [float] NULL,
		[total_pounds] [float] NULL,
		[haz_total_pounds] [float] NULL,
		[nonhaz_total_pounds] [float] NULL,
		[mode] [varchar](20) NULL,
		[row_num] [int] IDENTITY(1,1) NOT NULL,
		[facility_epa_id] [varchar](20) NULL,
		[pcb_flag] [char](1) NULL,
		[transporter_code] [varchar](20) NULL,
		[transporter_name] [varchar](60) NULL,
		[transporter_epa_id] [varchar](20) NULL,
		[waste_code_list] [varchar](max) NULL,
		[manifest] [varchar](20) NULL,
		[manifest_line] [int] NULL,
		[weight_method] [varchar](40) NULL
	) 


-----------------------------------------
------- INBOUND (EQ) WASTE DATA: --------
-----------------------------------------
	-- Create #access_filter table to hold subset of fields (quicker to run queries this way?)
		CREATE TABLE #access_filter (
			company_id				int, 
			profit_ctr_id			int, 
			receipt_id				int,
			line_id					int,
			source					char(1)
		)
	
	-- Create Where clause to be used on Inbound waste queries:
		SET @where = ' WHERE 1=1 '
		DECLARE @date_where varchar(1000)
	
		-- For everyone:
		IF (select count(*) from #customer_id_list) > 0
			SET @where = @where + ' AND ( r.customer_id IN (select id from #customer_id_list) ) '

		IF (select count(*) from #generator_id_list) > 0
			SET @where = @where + ' AND ( r.generator_id IN (select id from #generator_id_list) ) '
	
		IF (select count(*) from #approval_code_list ) > 0  -- AND @report_type = 'A'
			SET @where = @where + ' AND r.approval_code IN (select approval_code from #approval_code_list) '
	
		IF LEN(@trans_start_date) > 0 OR LEN(@trans_end_date) > 0
		BEGIN
			SET @where = @where + ' AND (r.receipt_date BETWEEN COALESCE(NULLIF(''' + @trans_start_date + ''',''''), r.receipt_date) AND COALESCE(NULLIF(''' + @trans_end_date + ''',''''), r.receipt_date)) '
		END

	-- service date
		IF LEN(@serv_start_date) > 0 OR LEN(@serv_end_date) > 0
		BEGIN
		-- This is lousy.
			SET @where = @where + ' AND ( dbo.fn_get_service_date(r.company_id, r.profit_ctr_id, r.receipt_id, ''R'') BETWEEN COALESCE(NULLIF(''' + @serv_start_date + ''',''''), r.receipt_date) AND COALESCE(NULLIF(''' + @serv_end_date + ''',''''), r.receipt_date) ) '
		END

		SET @where = @where + ' AND r.submitted_flag = ''T'' AND r.trans_type = ''D'' AND r.receipt_status = ''A'' AND pfc.status = ''A'' AND pfc.view_on_web IN (''P'', ''C'') AND pfc.view_waste_summary_on_web = ''T'' AND cpy.view_on_web = ''T'' '

		SET @where = @where + ' AND NOT EXISTS (select 1 from #access_filter where receipt_id = r.receipt_id and line_id = r.line_id and company_id = r.company_id and profit_ctr_id = r.profit_ctr_id) '

	    IF @debug >= 1 PRINT '@where:  ' + @where


		-- intermediate step: build a #access_filter table of the calculated columns:
	IF (select count(*) from #customer where customer_id <> -1) > 0 BEGIN
		SET @execute_sql = ' INSERT #access_filter SELECT DISTINCT 
			r.company_id,
			r.profit_ctr_id,
			r.receipt_id,
			r.line_id,
			''C'' as source
			FROM Receipt r
			INNER JOIN Billing bill ON
				r.receipt_id = bill.receipt_id
				AND r.company_id = bill.company_id
				AND r.profit_ctr_id = bill.profit_ctr_id
				AND r.line_id = bill.line_id
				AND bill.trans_source = ''R''
				AND bill.status_code = ''I''
			INNER JOIN Company cpy ON r.company_id = cpy.company_id
			INNER JOIN ProfitCenter pfc ON 
				r.company_id = pfc.company_id 
				and r.profit_ctr_id = pfc.profit_ctr_id
			INNER JOIN #customer customer_list ON customer_list.customer_id = r.customer_id
			' + @where
		
		IF @debug >= 1
		BEGIN
			PRINT @execute_sql
			
			PRINT ''
		END
		
		if @debug < 10
			EXEC(@execute_sql)
	END
	
	if @debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'

	IF (select count(*) from #generator where generator_id <> -1) > 0 BEGIN
		SET @execute_sql = ' INSERT #access_filter SELECT 
			DISTINCT
			r.company_id,
			r.profit_ctr_id,
			r.receipt_id,
			r.line_id,
			''G'' as source
			FROM Receipt r
			INNER JOIN Billing bill ON
				r.receipt_id = bill.receipt_id
				AND r.company_id = bill.company_id
				AND r.profit_ctr_id = bill.profit_ctr_id
				AND r.line_id = bill.line_id
				AND bill.trans_source = ''R''
				AND bill.status_code = ''I''
			INNER JOIN Company cpy ON r.company_id = cpy.company_id
			INNER JOIN ProfitCenter pfc ON 
				r.company_id = pfc.company_id 
				and r.profit_ctr_id = pfc.profit_ctr_id
			INNER JOIN #generator gen ON gen.generator_id = r.generator_id
			' + @where + ''

		IF @debug >= 1
		BEGIN
			PRINT @execute_sql
			PRINT ''
		END
		
		if @debug < 10
			EXEC(@execute_sql)

	END

	if @debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'



	create index idx_temp on #access_filter(company_id, profit_ctr_id, receipt_id)

	IF @debug >= 1 and 1000 > (select count(*) from #access_filter)
	BEGIN
		SELECT '#customer_id_list', * FROM #customer_id_list 	
		SELECT '#access_filter', * FROM #access_filter
	END

	if (select count(*) from #access_filter) > 0 begin

		-- Group Option Specific Code:		
		IF @report_type = 'A'
		BEGIN	-- Group by Approval
			-- final step: build query to populate Work_WasteReceivedSummaryListResult from #access_filter 
			SET @execute_sql = ' INSERT #Work_WasteReceivedSummaryListResult 
				(company_id, 
					profit_ctr_id, 
					facility, 
					customer_id, 
					cust_name, 
					approval_code, 
					profile_id,
					waste_description, 
					haz_flag, 
					generator_id, 
					epa_id, 
					generator_name, 
					generator_state, 
					generator_city,
					site_code, 
					bill_unit_code, 
					bill_unit_desc, 
					management_code,
					epa_form_code,
					epa_source_code,
					quantity, 
					pound_conv, 
					total_pounds, 
					weight_method,
					mode, 
					transaction_id, 
					receipt_date, 
					service_date,
					facility_epa_id,
					waste_code_list,
					transporter_code,
					transporter_name,
					transporter_epa_id,
					manifest,
					manifest_line)
			SELECT 
				t.company_id,
				t.profit_ctr_id AS profit_ctr_id,
				dbo.fn_web_profitctr_display_name(t.company_id, t.profit_ctr_id) as facility,
				r.customer_id,
				cust.cust_name AS cust_name,
				r.approval_code,
				r.profile_id,
				(
					select 
						convert(varchar(150), ltrim(rtrim(isnull(p.approval_desc, '''')))) 
					from profile p
					where p.profile_id = r.profile_id
				) as waste_description,
				haz_flag = case when exists (
					select 1 
					from wastecode wc 
					inner join receiptwastecode rwc 
						on wc.waste_code_uid = rwc.waste_code_uid
					where rwc.receipt_id = t.receipt_id 
					and rwc.line_id = r.line_id 
					and rwc.company_id = t.company_id 
					and rwc.profit_ctr_id = t.profit_ctr_id 
					AND wc.waste_code_origin = ''F''
					AND IsNull(wc.haz_flag,''F'') = ''T''
				) then ''T'' else ''F'' end,
				r.generator_id,
				g.epa_id AS epa_id,
				g.generator_name,
				g.generator_state,
				g.generator_city,
				g.site_code,
				rp.bill_unit_code,
				b.bill_unit_desc,
				treatment.management_code,
				profile.epa_form_code,
				profile.epa_source_code,
				isnull(rp.bill_quantity, 0) AS quantity,
				b.pound_conv AS pound_conv, 
				isnull(dbo.fn_receipt_weight_line (t.receipt_id, r.line_id, t.profit_ctr_id, t.company_id), 0) as total_pounds, 
				dbo.fn_receipt_weight_line_description (t.receipt_id, r.line_id, t.profit_ctr_id, t.company_id, 0) as weight_method,
				''Inbound'' as mode,
				''R'' + convert(varchar(15), t.receipt_id) as transaction_id,
				r.receipt_date,
				dbo.fn_get_service_date(t.company_id, t.profit_ctr_id, t.receipt_id, ''R'') as service_date,
				dbo.fn_web_profitctr_display_epa_id(t.company_id, t.profit_ctr_id) as facility_epa_id,
				dbo.fn_receipt_waste_code_list_long(t.company_id, t.profit_ctr_id, t.receipt_id, r.line_id) as waste_code_list,
				rt1.transporter_code,
				trans.transporter_name,
				trans.transporter_epa_id,
				r.manifest,
				r.manifest_line
				'
					
			END	-- Group by Approval

		ELSE

			BEGIN	-- Group by Generator, Approval
				-- final step: build query to populate Work_WasteReceivedSummaryListResult from #access_filter 
				SET @execute_sql = ' 
			INSERT #Work_WasteReceivedSummaryListResult 
				(company_id, 
				profit_ctr_id, 
				facility, 
				customer_id, 
				cust_name, 
				generator_id, 
				epa_id, 
				generator_name, 
				generator_state, 
				generator_city,
				site_code, 
				waste_description, 
				haz_flag, 
				bill_unit_code, 
				bill_unit_desc, 
				management_code,
				epa_form_code,
				epa_source_code,
				quantity, 
				pound_conv, 
				total_pounds, 
				weight_method,
				mode, 
				transaction_id, 
				receipt_date, 
				service_date,
				facility_epa_id,
				waste_code_list,
				transporter_code,
				transporter_name,
				transporter_epa_id,
				manifest,
				manifest_line)
					
				SELECT
					t.company_id,
					t.profit_ctr_id AS profit_ctr_id,
					dbo.fn_web_profitctr_display_name(t.company_id, t.profit_ctr_id) as facility,
					r.customer_id,
					cust.cust_name AS cust_name,
					r.generator_id,
					g.epa_id AS epa_id,
					g.generator_name,
					g.generator_state,
					g.generator_city,
					g.site_code,
					(
						select 
							convert(varchar(150), ltrim(rtrim(isnull(p.approval_desc, '''')))) 
						from profile p where p.profile_id = r.profile_id
					) as waste_description,
					haz_flag = case when exists (
						select 1 
						from wastecode wc 
						inner join receiptwastecode rwc 
							on wc.waste_code_uid = rwc.waste_code_uid
						where rwc.receipt_id = t.receipt_id 
						and rwc.line_id = r.line_id 
						and rwc.company_id = t.company_id 
						and rwc.profit_ctr_id = t.profit_ctr_id 
						AND wc.waste_code_origin = ''F''
						AND IsNull(wc.haz_flag,''F'') = ''T''
					) then ''T'' else ''F'' end,
					rp.bill_unit_code,
					b.bill_unit_desc,
					treatment.management_code,
					profile.epa_form_code,
					profile.epa_source_code,
					isnull(rp.bill_quantity, 0) AS quantity,
					b.pound_conv, 
					isnull(dbo.fn_receipt_weight_line (t.receipt_id, r.line_id, t.profit_ctr_id, t.company_id), 0) as total_pounds, 
					dbo.fn_receipt_weight_line_description (t.receipt_id, r.line_id, t.profit_ctr_id, t.company_id, 0) as weight_method,
					''Inbound'' as mode,
					''R'' + convert(varchar(15), t.receipt_id) as transaction_id,
					r.receipt_date,
					dbo.fn_get_service_date(t.company_id, t.profit_ctr_id, t.receipt_id, ''R'') as service_date,
					dbo.fn_web_profitctr_display_epa_id(t.company_id, t.profit_ctr_id) as facility_epa_id,
					dbo.fn_receipt_waste_code_list_long(t.company_id, t.profit_ctr_id, t.receipt_id, r.line_id) as waste_code_list,
					rt1.transporter_code,
					trans.transporter_name,
					trans.transporter_epa_id,
					r.manifest,
					r.manifest_line
				'
			END	-- Group by Generator


		-- Add FROM clause and the beginning of the WHERE clause (that's common to both report types)
		SET @execute_sql = @execute_sql + '
			FROM #access_filter t
			inner join Receipt r on 
				t.receipt_id = r.receipt_id 
				and t.line_id = r.line_id
				and t.company_id = r.company_id 
				and t.profit_ctr_id = r.profit_ctr_id
			INNER JOIN ReceiptPrice rp ON 
				R.receipt_id = rp.receipt_id
				AND R.company_id = rp.company_id
				AND R.profit_ctr_id = rp.profit_ctr_id
				AND R.line_id = rp.line_id
			INNER JOIN Customer cust ON r.customer_id = cust.customer_id
			LEFT OUTER JOIN Billunit b ON rp.bill_unit_code = b.bill_unit_code
			LEFT OUTER JOIN Generator g on r.generator_id = g.generator_id
			INNER JOIN Profile  WITH(NOLOCK) ON (r.profile_id = Profile.Profile_id)
			INNER JOIN ProfileQuoteApproval PQA ON (r.approval_code = PQA.approval_code
				AND r.profit_ctr_id = PQA.profit_ctr_id
				AND r.company_id = PQA.company_id)
			INNER JOIN Treatment WITH(NOLOCK)  ON (
				CASE WHEN ISnull(r.treatment_id,0) <> 0 
					THEN ISnull(r.treatment_id,0) 
					ELSE
						isnull(PQA.Treatment_ID, 0)
				END = Treatment.treatment_id )
				AND r.company_id = Treatment.company_id
				and r.profit_ctr_id = Treatment.profit_ctr_id
			LEFT JOIN ReceiptTransporter rt1 
				ON r.receipt_id = rt1.receipt_id 
				AND r.company_id = rt1.company_id 
				AND r.profit_ctr_id = rt1.profit_ctr_id 
				AND rt1.transporter_sequence_id = 1
			LEFT JOIN Transporter trans
				ON rt1.transporter_code = trans.transporter_code
		'

		-- -- -- -- -- -- --
		-- debugging: Control whether this part of the SP runs
		IF 1=1 BEGIN
		-- -- -- -- -- -- --

		if @debug between 5 and 10 and 1000 > (select count(*) from #access_filter)
			SELECT 'access_filter' as table_name, * from #access_filter

		IF @debug >= 1
		BEGIN
			PRINT @execute_sql
			PRINT ''
		END

		if @debug < 10
			EXEC(@execute_sql)
		if @debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'


		if @debug between 5 and 10
			SELECT 'WasteSummary' as table_name, * from #Work_WasteReceivedSummaryListResult
			
		-- -- -- -- -- -- --
		END
		-- -- -- -- -- -- --


	end

-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------  Hey, might THIS line be redundant?
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------

	-- Create #workorder_access_filter table to hold subset of fields (quicker to run queries this way?)
IF object_id('tempdb..#workorder_access_filter') is not null drop table #workorder_access_filter

		CREATE TABLE #workorder_access_filter (
			company_id				int, 
			profit_ctr_id			int, 
			workorder_id			int,
			resource_type			char(1),
			sequence_id				int
		)

		declare @workorder_access_filter varchar(max)
		set @workorder_access_filter = ' INSERT INTO #workorder_access_filter(
			company_id, 
			profit_ctr_id, 
			workorder_id,
			resource_type,
			sequence_id)
				SELECT DISTINCT
					w.company_id, 
					w.profit_ctr_id, 
					w.workorder_id,
					d.resource_type,
					d.sequence_id
				FROM WorkOrderHeader w
			INNER JOIN WorkorderDetail d on 
				w.workorder_id = d.workorder_id
				AND w.company_id = d.company_id
				AND w.profit_ctr_id = d.profit_ctr_id
				AND d.resource_type = ''D''
			LEFT JOIN tsdfapproval t ON t.tsdf_approval_id = d.TSDF_Approval_ID
			LEFT JOIN tsdf on t.tsdf_code = tsdf.tsdf_code
			INNER JOIN Company cpy ON w.company_id = cpy.company_id
			INNER JOIN ProfitCenter pfc ON w.company_id = pfc.company_id 
				AND w.profit_ctr_id = pfc.profit_ctr_id
				WHERE 1=1 '

		IF (select count(*) from #customer_id_list) > 0
			SET @workorder_access_filter = @workorder_access_filter + ' AND ( w.customer_id IN (select id from #customer_id_list) ) '

		IF (select count(*) from #generator_id_list) > 0
			SET @workorder_access_filter = @workorder_access_filter + ' AND ( w.generator_id IN (select id from #generator_id_list) ) '

		IF @report_type = 'A' AND (select count(*) from #approval_code_list) > 0
			SET @workorder_access_filter = @workorder_access_filter + ' AND t.tsdf_approval_code IN (select approval_code from #approval_code_list) '

		IF LEN(@trans_start_date) > 0 OR LEN(@trans_end_date) > 0
			SET @workorder_access_filter = @workorder_access_filter + ' AND (w.end_date BETWEEN COALESCE(NULLIF(''' + @trans_start_date + ''',''''), w.end_date) AND COALESCE(NULLIF(''' + @trans_end_date + ''',''''), w.end_date)) '

		IF LEN(@serv_start_date) > 0 OR LEN(@serv_end_date) > 0
			SET @workorder_access_filter = @workorder_access_filter + ' AND ( dbo.fn_get_service_date(w.company_id, w.profit_ctr_id, w.workorder_id, ''W'') BETWEEN COALESCE(NULLIF(''' + @serv_start_date + ''',''''), w.end_date) AND COALESCE(NULLIF(''' + @serv_end_date + ''',''''), w.end_date)) '

		SET @workorder_access_filter = @workorder_access_filter + '
			/* AND tsdf.eq_flag = ''F'' */
			AND w.submitted_flag = ''T''
			AND pfc.status = ''A''
			AND pfc.view_on_web IN (''P'', ''C'')
			AND pfc.view_workorders_on_web = ''T''
			AND cpy.VIEW_ON_WEB = ''T''
		'

	EXEC(@workorder_access_filter)

	IF @debug >= 1
	BEGIN
		
		PRINT @workorder_access_filter
		SELECT '#workorder_access_filter' as table_name, * from #workorder_access_filter
		PRINT ''
	END

	if (select count(*) from #workorder_access_filter) > 0 begin

			select @intCount = count(customer_id) from WorkorderHeader where customer_id in (select customer_id from #customer_id_list)

			if @intCount = 0 
				select @intCount = count(generator_id) from WorkorderHeader where generator_id in (select generator_id from #generator_id_list)

			if @intCount > 0 
			BEGIN

			if @debug >= 1 print '(Starting Outbound logic) Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'



			IF @report_type = 'A'
			BEGIN	-- Group by Approval

				--declare @execute_sql varchar(max)
				SET @execute_sql = '
				INSERT #Work_WasteReceivedSummaryListResult (
					company_id, 
					profit_ctr_id, 
					facility, 
					customer_id, 
					cust_name, 
					approval_code, 
					profile_id,
					waste_description, 
					haz_flag, 
					generator_id, 
					epa_id, 
					generator_name, 
					generator_state, 
					generator_city, 
					site_code, 
					bill_unit_code, 
					bill_unit_desc, 
					management_code,
					epa_form_code,
					epa_source_code,
					quantity, 
					pound_conv, 
					total_pounds, 
					weight_method,
					mode, 
					transaction_id, 
					receipt_date, 
					service_date,
					facility_epa_id,
					waste_code_list,
					transporter_code,
					transporter_name,
					transporter_epa_id,
					manifest,
					manifest_line
				)
				SELECT DISTINCT
					99 as company_id,
					99 AS profit_ctr_id,
					coalesce(tsdf.tsdf_name, ppc.profit_ctr_name) as facility,
					w.customer_id,
					cust.cust_name AS cust_name,
					d.tsdf_approval_code as approval_code,
					null as profile_id,
					convert(varchar(150), ltrim(rtrim(coalesce(t.waste_desc, p.approval_desc, '''')))) as waste_description,
					haz_flag = case when exists (
						select 1 
						from wastecode wc 
						inner join tsdfapprovalwastecode twc 
							on wc.waste_code_uid = twc.waste_code_uid
						where t.tsdf_approval_id = twc.tsdf_approval_id 
						and t.company_id = twc.company_id 
						and t.profit_ctr_id = twc.profit_ctr_id 
						AND wc.waste_code_origin = ''F''
						AND IsNull(wc.haz_flag,''F'') = ''T''
						union
						select 1 
						from wastecode wc 
						inner join profilewastecode pwc 
							on wc.waste_code_uid = pwc.waste_code_uid
						where d.profile_id = pwc.profile_id 
						AND wc.waste_code_origin = ''F''
						AND IsNull(wc.haz_flag,''F'') = ''T''
					) then ''T'' else ''F'' end,
					w.generator_id,
					g.epa_id AS epa_id,
					g.generator_name,
					g.generator_state,
					g.generator_city,
					g.site_code,
					wodu.bill_unit_code,
					b.bill_unit_desc,
					isnull(d.management_code, t.management_code),
					coalesce(t.epa_form_code, p.epa_form_code) epa_form_code,
					coalesce(t.epa_source_code, p.epa_source_code) epa_source_code,
					isnull(wodu.quantity, d.quantity) as quantity,
					b.pound_conv AS pound_conv,
					dbo.fn_workorder_weight_line (w.workorder_id, d.sequence_id, w.profit_ctr_id, w.company_id) as total_pounds,
					dbo.fn_workorder_weight_line_description (w.workorder_id, d.sequence_id, w.profit_ctr_id, w.company_id) as weight_method,
					''Outbound'' as mode,
					''W'' + convert(varchar(15), w.workorder_id) as transaction_id,
					w.start_date as receipt_date,
					dbo.fn_get_service_date(w.company_id, w.profit_ctr_id, w.workorder_id, ''W'') as service_date,
					coalesce(tsdf.TSDF_EPA_ID, ppc.epa_id) as facility_epa_id,
					dbo.fn_workorder_waste_code_list_no_state(w.workorder_id, w.company_id, w.profit_ctr_id, d.sequence_id) as waste_code_list,
					wt1.transporter_code,
					trans.transporter_name,
					trans.transporter_epa_id,
					d.manifest,
					d.manifest_line
					'				
											
			END	-- Group by Approval
			ELSE
			BEGIN	-- Group by Generator, Approval

				SET @execute_sql = '
				INSERT #Work_WasteReceivedSummaryListResult (
					company_id, 
					profit_ctr_id, 
					facility, 
					customer_id, 
					cust_name, 
					generator_id, 
					epa_id, 
					generator_name, 
					generator_state, 
					generator_city, 
					site_code, 
					waste_description, 
					haz_flag, 
					bill_unit_code, 
					bill_unit_desc, 
					management_code,
					epa_form_code,
					epa_source_code,
					quantity, 
					pound_conv, 
					total_pounds, 
					weight_method,
					mode, 
					transaction_id, 
					receipt_date, 
					service_date,
					facility_epa_id,
					waste_code_list,
					transporter_code,
					transporter_name,
					transporter_epa_id,
					manifest,
					manifest_line
				)
				SELECT DISTINCT
					99 as company_id,
					99 AS profit_ctr_id,
					coalesce(tsdf.tsdf_name, ppc.profit_ctr_name) as facility,
					w.customer_id,
					cust.cust_name AS cust_name,
					w.generator_id,
					g.epa_id AS epa_id,
					g.generator_name,
					g.generator_state,
					g.generator_city,
					g.site_code,
					convert(varchar(150), ltrim(rtrim(isnull(t.waste_desc, '''')))) as waste_description,
					haz_flag = case when exists (
						select 1 
						from wastecode wc 
						inner join tsdfapprovalwastecode twc 
							on wc.waste_code_uid = twc.waste_code_uid 
						where t.tsdf_approval_id = twc.tsdf_approval_id 
						and t.company_id = twc.company_id 
						and t.profit_ctr_id = twc.profit_ctr_id 
						AND wc.waste_code_origin = ''F''
						AND IsNull(wc.haz_flag,''F'') = ''T''
						union
						select 1 
						from wastecode wc 
						inner join profilewastecode pwc 
							on wc.waste_code_uid = pwc.waste_code_uid 
						where d.profile_id = pwc.profile_id
						AND wc.waste_code_origin = ''F''
						AND IsNull(wc.haz_flag,''F'') = ''T''
					) then ''T'' else ''F'' end,
					wodu.bill_unit_code,
					b.bill_unit_desc,
					isnull(d.management_code, t.management_code),
					coalesce(t.epa_form_code, p.epa_form_code) epa_form_code,
					coalesce(t.epa_source_code, p.epa_source_code) epa_source_code,
					ISNULL(wodu.quantity, d.quantity),
					b.pound_conv AS pound_conv,
					dbo.fn_workorder_weight_line (w.workorder_id, d.sequence_id, w.profit_ctr_id, w.company_id) as total_pounds,
					dbo.fn_workorder_weight_line_description (w.workorder_id, d.sequence_id, w.profit_ctr_id, w.company_id) as weight_method,
					''Outbound'' as mode,
					''W'' + convert(varchar(15), w.workorder_id) as transaction_id,
					w.start_date as receipt_date,
					dbo.fn_get_service_date(w.company_id, w.profit_ctr_id, w.workorder_id, ''W'') as service_date,
					tsdf.TSDF_EPA_ID as facility_epa_id,
					dbo.fn_workorder_waste_code_list_no_state(w.workorder_id, w.company_id, w.profit_ctr_id, d.sequence_id) as waste_code_list,
					wt1.transporter_code,
					trans.transporter_name,
					trans.transporter_epa_id,
					d.manifest,
					d.manifest_line
					'

			END	-- Group by Generator, Approval

			declare @sql_wo_disposal_join varchar(max)
			declare @sql_wo_service_join varchar(max)
			
			-- Add FROM clause and the beginning of the WHERE clause (that's common to both report types)
			SET @sql_wo_service_join = @execute_sql + '
				FROM #workorder_access_filter waf
					INNER JOIN WorkorderHeader w ON
						waf.workorder_id = w.workorder_id
						AND waf.company_id = w.company_id
						AND waf.profit_ctr_id = w.profit_ctr_id
					INNER JOIN WorkorderDetail d on 
						w.workorder_id = d.workorder_id
						AND w.company_id = d.company_id
						AND w.profit_ctr_id = d.profit_ctr_id
						and waf.resource_type = d.resource_type
						and waf.sequence_id = d.sequence_id
						AND d.resource_type <> ''D''
					INNER JOIN WorkOrderDetailUnit wodu ON
						wodu.workorder_id = d.workorder_id
						AND wodu.company_id = d.company_id
						AND wodu.profit_ctr_id = d.profit_ctr_id
						AND wodu.sequence_id = d.sequence_id
						AND wodu.billing_flag = ''T''
					INNER JOIN tsdfapproval t ON t.tsdf_approval_id = d.TSDF_Approval_ID
					INNER JOIN tsdf on t.tsdf_code = tsdf.tsdf_code
					left join profile p on d.profile_id = p.profile_id and d.tsdf_approval_id is null
					left join ProfitCenter ppc on d.profile_company_id = ppc.company_id and d.profile_profit_ctr_id = ppc.profit_ctr_id
					INNER JOIN Customer cust ON w.customer_id = cust.customer_id
					INNER JOIN Billing bill ON bill.company_id = w.company_id
						AND bill.profit_ctr_id = w.profit_ctr_id
						AND bill.receipt_id = w.workorder_id 
						AND bill.trans_source = ''W''
						AND bill.workorder_resource_type = d.resource_type
						AND bill.workorder_sequence_id = d.sequence_id
					LEFT OUTER JOIN Billunit b ON wodu.bill_unit_code = b.bill_unit_code
					LEFT OUTER JOIN Generator g ON w.generator_id = g.generator_id
					LEFT OUTER JOIN tsdfapprovalwastecode twc on t.tsdf_approval_id = twc.tsdf_approval_id and t.company_id = twc.company_id and t.profit_ctr_id = twc.profit_ctr_id and twc.primary_flag = ''T'' 
					LEFT JOIN workordertransporter wt1 ON w.workorder_id = wt1.workorder_id and w.company_id = wt1.company_id and w.profit_ctr_id = wt1.profit_ctr_id and wt1.transporter_sequence_id = 1 and wt1.manifest = d.manifest
					LEFT JOIN transporter trans ON wt1.transporter_code = trans.transporter_code
				WHERE 1=1 '

			
				SET @sql_wo_disposal_join = @execute_sql + '
					FROM #workorder_access_filter waf
					INNER JOIN WorkorderHeader w ON
						waf.workorder_id = w.workorder_id
						AND waf.company_id = w.company_id
						AND waf.profit_ctr_id = w.profit_ctr_id
					INNER JOIN WorkorderDetail d on 
						w.workorder_id = d.workorder_id
						AND w.company_id = d.company_id
						AND w.profit_ctr_id = d.profit_ctr_id
						and waf.resource_type = d.resource_type
						and waf.sequence_id = d.sequence_id
						AND d.resource_type = ''D''
					INNER JOIN WorkOrderDetailUnit wodu ON
						wodu.workorder_id = d.workorder_id
						AND wodu.company_id = d.company_id
						AND wodu.profit_ctr_id = d.profit_ctr_id
						AND wodu.sequence_id = d.sequence_id
						AND wodu.billing_flag = ''T''
					LEFT JOIN tsdfapproval t ON t.tsdf_approval_id = d.TSDF_Approval_ID
					LEFT JOIN tsdf on t.tsdf_code = tsdf.tsdf_code
					LEFT JOIN profile p ON d.profile_id = p.profile_id and d.tsdf_approval_id is null
					LEFT JOIN profitcenter ppc ON d.profile_company_id = ppc.company_id and d.profile_profit_ctr_id = ppc.profit_ctr_id and d.tsdf_approval_id is null
					INNER JOIN Customer cust ON w.customer_id = cust.customer_id
					INNER JOIN Billing bill ON bill.company_id = w.company_id
						AND bill.profit_ctr_id = w.profit_ctr_id
						AND bill.receipt_id = w.workorder_id 
						AND bill.trans_source = ''W''
						AND bill.workorder_sequence_id = d.sequence_id
						AND bill.workorder_resource_type = d.resource_type
					LEFT OUTER JOIN Billunit b ON wodu.bill_unit_code = b.bill_unit_code
					LEFT OUTER JOIN Generator g ON w.generator_id = g.generator_id
					LEFT OUTER JOIN tsdfapprovalwastecode twc on t.tsdf_approval_id = twc.tsdf_approval_id and t.company_id = twc.company_id and t.profit_ctr_id = twc.profit_ctr_id and twc.primary_flag = ''T'' 
					LEFT JOIN workordertransporter wt1 ON w.workorder_id = wt1.workorder_id and w.company_id = wt1.company_id and w.profit_ctr_id = wt1.profit_ctr_id and wt1.transporter_sequence_id = 1 and wt1.manifest = d.manifest
					LEFT JOIN transporter trans ON wt1.transporter_code = trans.transporter_code
				WHERE 1=1 '	
				
			
				SET @sql_wo_disposal_join = @sql_wo_disposal_join + '
					/* AND tsdf.eq_flag = ''F'' */
					AND w.submitted_flag = ''T'' '
					
				SET @sql_wo_service_join = @sql_wo_service_join + '
					/* AND tsdf.eq_flag = ''F''  */
					AND w.submitted_flag = ''T'' '
				

				--print @execute_sql

			-- -- -- -- -- -- --
			-- debugging: Control whether this part of the SP runs
			IF 1=1 BEGIN
			-- -- -- -- -- -- --

			IF @debug >= 1
			BEGIN
				PRINT 'svc join ' + @sql_wo_service_join
				PRINT ''
			END

			if @debug < 10
				EXEC(@sql_wo_service_join)
			if @debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'

			IF @debug >= 1
			BEGIN
				PRINT 'disposal join ' + @sql_wo_disposal_join
				PRINT ''
			END

			if @debug < 10
				EXEC(@sql_wo_disposal_join)
				
			if @debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'

			-- -- -- -- -- -- --
			END
			-- -- -- -- -- -- --

		ELSE
		if @debug >= 1 print '(Skipping Outbound logic) Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'
		END
	end

IF @level = 'S' BEGIN
	-- Select from the Work_WasteReceivedSummaryListResult data (not detail version) to create the report:
	IF @report_type = 'A' BEGIN -- Group by Approval

	-- The paging table is used to store the intermediate set of results
	-- so that the actual table can store the actual results that will be 
	-- displayed to the user (grouped, sorted, etc..)
	CREATE TABLE #s_a_paging
	(
			company_id int,
			profit_ctr_id int,
			facility varchar(50),
			customer_id int,
			cust_name varchar(75),
			generator_id int,
			epa_id varchar(50),
			generator_name varchar(75),
			generator_state varchar(2),
			generator_city varchar(50),
			site_code varchar(16),
			approval_code varchar(50),
			profile_id	int,
			waste_code_list varchar(max),
			waste_description varchar(50),
			haz_flag varchar(50),
			bill_unit_code varchar(50),
			bill_unit_desc varchar(50),
			management_code varchar(4),
			epa_form_code varchar(4),
			epa_source_code varchar(3),
			quantity float,
			total_pounds float,
			weight_method varchar(20),
			mode varchar(50),
			facility_epa_id varchar(20)
	)

	INSERT #s_a_paging 
		SELECT
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			approval_code,
			profile_id,
			waste_code_list,
			waste_description,
			haz_flag,
			bill_unit_code,
			bill_unit_desc,
			management_code,
			epa_form_code,
			epa_source_code,
			SUM(isnull(quantity, 0)) as quantity,
			SUM(IsNull(total_pounds, 0)) AS total_pounds,
			weight_method,
			mode,
			facility_epa_id
		FROM #Work_WasteReceivedSummaryListResult
		GROUP BY 
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			approval_code,
			profile_id,
			waste_code_list,
			waste_description,
			haz_flag,
			bill_unit_code,
			bill_unit_desc,
			management_code,
			epa_form_code,
			epa_source_code,
			weight_method,
			mode,
			facility_epa_id
		ORDER BY -- approval/summary order by
			company_id,
			profit_ctr_id,
			facility,
			generator_name,
			epa_id,
			approval_code,
			profile_id,
			cust_name,
			bill_unit_code
			
	
		INSERT #Work_WasteReceivedSummaryDetailResultGroups
		(
			company_id,
			profit_ctr_id ,
			facility ,
			customer_id ,
			cust_name ,
			generator_id ,
			epa_id ,
			generator_name ,
			generator_state ,
			generator_city,
			site_code ,
			approval_code ,
			profile_id,
			waste_code_list ,
			waste_description ,
			haz_flag ,
			bill_unit_code ,
			bill_unit_desc ,
			management_code,
			epa_form_code,
			epa_source_code,
			quantity ,
			total_pounds ,
			weight_method ,
			mode,
			facility_epa_id
		)
		SELECT
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			approval_code,
			profile_id,
			waste_code_list,
			waste_description,
			haz_flag,
			bill_unit_code,
			bill_unit_desc,
			management_code,
			epa_form_code,
			epa_source_code,
			SUM(isnull(quantity, 0)) as quantity,
			SUM(isnull(total_pounds, 0)) as total_pounds,
			weight_method ,
			mode,
			facility_epa_id
		FROM #s_a_paging
		GROUP BY 
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			approval_code,
			profile_id,
			waste_code_list,
			waste_description,
			haz_flag,
			bill_unit_code,
			bill_unit_desc,
			management_code,
			epa_form_code,
			epa_source_code,
			weight_method,
			mode,
			facility_epa_id
		ORDER BY 
			company_id,
			profit_ctr_id,
			facility,
			generator_name,
			epa_id,
			approval_code,
			profile_id,
			cust_name,
			bill_unit_code
		
	END
	ELSE
	BEGIN -- Summary, Group by Generator

		-- The paging table is used to store the intermediate set of results
		-- so that the actual table can store the actual results that will be 
		-- displayed to the user (grouped, sorted, etc..)
		create table #s_g_paging
		(
			company_id int,
			profit_ctr_id int,
			facility varchar(50),
			customer_id int,
			cust_name varchar(50),
			generator_id int,
			epa_id varchar(50),
			generator_name varchar(75),
			generator_state varchar(50),
			generator_city varchar(50),
			site_code varchar(50),
			haz_total_pounds float,
			nonhaz_total_pounds float,
			total_pounds float,
			weight_method varchar(20),
			mode varchar(50),
			facility_epa_id varchar(20)
		)

		INSERT #s_g_paging
		SELECT 
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			SUM(
				CASE WHEN haz_flag = 'T'
				THEN isnull(total_pounds, 0)
				ELSE 0
				END
			) AS haz_total_pounds,
			SUM(
				CASE WHEN haz_flag <> 'T'
					THEN isnull(total_pounds, 0)
					ELSE 0
				END
			) AS nonhaz_total_pounds,
			SUM(isnull(total_pounds, 0)) as total_pounds,
			weight_method,
			mode,
			facility_epa_id
		FROM #Work_WasteReceivedSummaryListResult
		GROUP BY 
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			weight_method,
			mode,
			facility_epa_id
		ORDER BY 
			company_id,
			profit_ctr_id,
			facility,
			cust_name,
			generator_name,
			epa_id

		INSERT #Work_WasteReceivedSummaryDetailResultGroups 
		(
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			haz_total_pounds,
			nonhaz_total_pounds,
			total_pounds,
			weight_method,
			mode,
			facility_epa_id
		)
		SELECT
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			SUM(isnull(haz_total_pounds, 0)) as haz_total_pounds,
			SUM(isnull(nonhaz_total_pounds, 0)) as nonhaz_total_pounds,
			SUM(isnull(total_pounds, 0)) as total_pounds,
			weight_method,
			mode,
			facility_epa_id
		FROM #s_g_paging
		GROUP BY 
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			mode,
			weight_method,
			facility_epa_id
		ORDER BY 
			company_id,
			profit_ctr_id,
			facility,
			cust_name,
			generator_name,
			epa_id
	END
END
ELSE
BEGIN
-- Detail version of execution:

-- selects below come straight from #Work_WasteReceivedSummaryListResult.  That doesn't help. Need them to come from a table with a row id for sorting help.
-- If header is a superset of detail, then populate the detail info into a tmp table, and output from there.

	IF @report_type = 'A' -- Group by Approval
	BEGIN

		INSERT #Work_WasteReceivedSummaryDetailResultItems (
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			approval_code,
			profile_id,
			waste_description,
			haz_flag,
			receipt_date,
			service_date,
			transaction_id,
			bill_unit_code,
			bill_unit_desc,
			management_code,
			epa_form_code,
			epa_source_code,
			quantity,
			total_pounds,
			weight_method,
			mode,
			facility_epa_id,
			waste_code_list,
			transporter_code,
			transporter_name,
			transporter_epa_id,
			manifest,
			manifest_line
		)
		SELECT
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			approval_code,
			profile_id,
			waste_description,
			haz_flag,
			receipt_date,
			service_date,
			transaction_id,
			bill_unit_code,
			bill_unit_desc,
			management_code,
			epa_form_code,
			epa_source_code,
			SUM(isnull(quantity, 0)) as quantity,
			SUM(isnull(total_pounds, 0)) AS total_pounds,
			weight_method,
			mode,
			facility_epa_id,
			waste_code_list,
			transporter_code,
			transporter_name,
			transporter_epa_id,
			manifest,
			manifest_line
		FROM #Work_WasteReceivedSummaryListResult
		GROUP BY 
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			approval_code,
			profile_id,
			waste_description,
			haz_flag,
			receipt_date,
			service_date,
			transaction_id,
			bill_unit_code,
			bill_unit_desc,
			management_code,
			epa_form_code,
			weight_method,
			epa_source_code,
			mode,
			facility_epa_id,
			waste_code_list,
			transporter_code,
			transporter_name,
			transporter_epa_id,
			manifest,
			manifest_line
		ORDER BY 
			company_id,
			profit_ctr_id,
			facility,
			generator_name,
			epa_id,
			approval_code,
			profile_id,
			receipt_date,
			service_date,
			transaction_id,
			cust_name,
			bill_unit_code
	
	END
	ELSE -- Group by Generator
	BEGIN
	
		INSERT #Work_WasteReceivedSummaryDetailResultItems (
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			haz_flag,
			receipt_date,
			service_date,
			transaction_id,
			bill_unit_code,
			bill_unit_desc,
			management_code,
			epa_form_code,
			epa_source_code,
			quantity,
			haz_quantity,
			nonhaz_quantity,
			haz_total_pounds,
			nonhaz_total_pounds,
			total_pounds,
			weight_method,
			mode,
			facility_epa_id,
			waste_code_list,
			transporter_code,
			transporter_name,
			transporter_epa_id,
			manifest,
			manifest_line
		)
		SELECT
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			haz_flag,
			receipt_date,
			service_date,
			transaction_id,
			bill_unit_code,
			bill_unit_desc,
			management_code,
			epa_form_code,
			epa_source_code,
			SUM(isnull(quantity, 0)) as quantity,
			SUM(
				CASE WHEN haz_flag = 'T'
					THEN isnull(quantity, 0)
					ELSE 0
				END
			) AS haz_quantity,
			SUM(
				CASE WHEN haz_flag <> 'T'
					THEN isnull(quantity, 0)
					ELSE 0
				END
			) AS nonhaz_quantity,
			SUM(
				CASE WHEN haz_flag = 'T'
					THEN isnull(total_pounds, 0)
					ELSE 0
				END
			) AS haz_total_pounds,
			SUM(
				CASE WHEN haz_flag <> 'T'
					THEN isnull(total_pounds, 0)
					ELSE 0
				END
			) AS nonhaz_total_pounds,
			sum(isnull(total_pounds, 0)) as total_pounds,
			weight_method,
			mode,
			facility_epa_id,
			waste_code_list,
			transporter_code,
			transporter_name,
			transporter_epa_id,
			manifest,
			manifest_line
		FROM #Work_WasteReceivedSummaryListResult
		GROUP BY 
			company_id,
			profit_ctr_id,
			facility,
			customer_id,
			cust_name,
			generator_id,
			epa_id,
			generator_name,
			generator_state,
			generator_city,
			site_code,
			receipt_date,
			service_date,
			transaction_id,
			haz_flag,
			bill_unit_code,
			bill_unit_desc,
			management_code,
			epa_form_code,
			epa_source_code,
			weight_method,
			mode,
			facility_epa_id,
			waste_code_list,
			transporter_code,
			transporter_name,
			transporter_epa_id,
			manifest,
			manifest_line
		ORDER BY 
			company_id,
			profit_ctr_id,
			facility,
			cust_name,
			generator_name,
			epa_id,
			receipt_date, 
			service_date,
			transaction_id,
			haz_flag,
			bill_unit_code 
			
	END
END

---------------------------------------------------------------
----------------------- RETURN RESULTS ------------------------
---------------------------------------------------------------

returnresults:

SET NOCOUNT OFF

IF @level = 'S' BEGIN

	-- Select from the #Work_WasteReceivedSummaryListResult data (not detail version) to create the report:
	IF @report_type = 'A' BEGIN -- Group by Approval


		SELECT 
--			company_id,
--			profit_ctr_id,
			Facility,
			Facility_EPA_ID,

			cust_name as Customer_Name,
			customer_id as Customer_ID,

			Generator_Name,
			EPA_ID,
			Generator_State,
			Generator_City,
			site_code as Generator_Site_Code,
			
			Approval_code as Approval,
			Waste_Description,
			case haz_flag when 'T' then 'Hazardous' else 'Non-Hazardous' end as [Hazardous?],
			Waste_Code_List,

			Management_Code,
			EPA_Form_Code,
			EPA_Source_Code,

			bill_unit_desc as Container,
			Weight_Method,
			Quantity,
			total_pounds as Total_Pounds,
			
			profile_id
		FROM #Work_WasteReceivedSummaryDetailResultGroups
		ORDER BY 
			facility,
			cust_name,
			generator_name,
			epa_id,
			approval_code,
			bill_unit_code

	END
	ELSE
	BEGIN -- Summary, Group by Generator

		SELECT 
			Facility,
			Facility_EPA_ID,
			cust_name as Customer_Name,
			Customer_ID,
			Generator_Name,
			EPA_ID,
			Generator_State,
			Generator_City,
			Site_Code as Generator_Site_Code,
			Weight_Method,
			[nonhaz_total_pounds] as [Non-Hazardous_Quantity],
			[haz_total_pounds] as [Hazardous_Quantity],
			Total_Pounds
		FROM #Work_WasteReceivedSummaryDetailResultGroups
		ORDER BY
			Facility,
			Generator_Name,
			EPA_ID
			
	END
END
ELSE 
BEGIN -- report is Detail

	IF @report_type = 'A' BEGIN -- Detail, Group by Approval
-- Select out Header query (Approval mode)

		-- Select out Detail query (Approval mode)
		SELECT DISTINCT
			Facility,
			Facility_EPA_ID,
			cust_name as Customer_Name,
			customer_id as Customer_ID,
			Generator_Name,
			EPA_ID,
			Generator_State,
			Generator_City,
			site_code as Generator_Site_Code,

			Transporter_Name,
			Transporter_EPA_ID,

			approval_code as Approval,
			Waste_Description,
			case haz_flag when 'T' then 'Hazardous' else 'Non-Hazardous' end as [Hazardous?],
			Waste_Code_List,
			
			Management_Code,
			EPA_Form_Code,
			EPA_Source_Code,
			transaction_id as [Transaction],
			receipt_date as [Transaction Date],
			service_date as [Service Date],
			Manifest,
			Manifest_Line,

			bill_unit_desc as Container,
			Weight_Method,
			Quantity,
			Total_Pounds,
			
			profile_id
			
		FROM #Work_WasteReceivedSummaryDetailResultItems
		ORDER BY 
			facility,
			approval_code,
			generator_name,
			epa_id,
			cust_name,
			receipt_date,
			service_date

	END
	ELSE
	BEGIN 
		-- Generator Group

		-- Select out Detail query (Generator mode)
		SELECT 
			Facility,
			Facility_EPA_ID,
			
			cust_name as Customer_Name,
			customer_id as Customer_ID,

			Generator_Name,
			EPA_ID,
			Generator_State,
			Generator_City,
			site_code as Generator_Site_Code,
			
			Transporter_Name,
			Transporter_EPA_ID,

			case haz_flag when 'T' then 'Hazardous' else 'Non-Hazardous' end as [Hazardous?],

--			Waste_Code_List,

			Management_Code,
			EPA_Form_Code,
			EPA_Source_Code,

			transaction_id as [Transaction],
			receipt_date as [Transaction Date],
			service_date as [Service Date],
			
			Manifest,
			Manifest_Line,

			bill_unit_desc as Container,

			Weight_Method,
			Quantity,
			Total_Pounds

		FROM #Work_WasteReceivedSummaryDetailResultItems item
		ORDER BY 
			cust_name,
			generator_name,
			epa_id,
			facility,
			receipt_date, 
			service_date,
			transaction_id,
			haz_flag,
			bill_unit_code,
			row_num

	END
END


if @debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_waste_summary] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_waste_summary] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_waste_summary] TO [EQAI]
    AS [dbo];

