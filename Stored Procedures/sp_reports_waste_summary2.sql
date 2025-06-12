CREATE PROCEDURE [dbo].[sp_reports_waste_summary2]
	@debug				int, 			-- 0 or 1 for no debug/debug mode
	@database_list		varchar(8000),	-- Comma Separated Company List
	@customer_id_list	text,			-- Comma Separated Customer ID List - what customers to include
	@generator_id_list	text,			-- Comma Separated Generator ID List - what generators to include
	@approval_code_list	text,			-- Comma Separated Approval Code List - what approvals to include
	@start_date			varchar(20),	-- Start Date
	@end_date			varchar(20),	-- End Date
	@report_type		char(1),		-- Group report by 'A'pproval or 'G'enerator
	@contact_id			varchar(100),	-- Contact_id
	@include_brokered	char(1),		-- 'Y' or 'N' for including waste where customer_id is not one of mine
	@level				char(1) = 'S',	-- 'S'ummary or 'D'etail
	@session_key		varchar(100) = '',	-- unique identifier key to a previously run query's results
	@row_from			int = 1,			-- when accessing a previously run query's results, what row should the return set start at?
	@row_to				int = 20			-- when accessing a previously run query's results, what row should the return set end at (-1 = all)?
AS
/****************************************************************************************************
sp_reports_waste_summary2:

Returns the data for Waste Summary.

LOAD TO PLT_AI*

sp_reports_waste_summary2 1, '', '888888', NULL, NULL, '', '', 'G', '', 'Y'
sp_reports_waste_summary2 1, '', '', '', NULL, '', '', 'A', '101296', 'Y'

sp_reports_waste_summary2 1, '', '', NULL, 'NC63056LP', '9/1/2006', '11/15/2006', 'A', '100913', 'Y'
sp_reports_waste_summary2 1, '', '', NULL, 'NC63056LP', '9/1/2006', '11/15/2006', 'G', '101296', 'Y', 'D'

sp_reports_waste_summary2 1, '', '001125', NULL, NULL, '1/1/2005', '8/31/2005', 'A', NULL, 'N', 'D'
sp_reports_waste_summary2 1, '', '001125', NULL, NULL, '1/1/2005', '3/31/2005', 'G', NULL, 'N'
sp_reports_waste_summary2 1, '', '', '44900', '', '', '', 'A', '', 'N'

-- all walmart by contact
sp_reports_waste_summary2 1, '', '', '', NULL, '10/1/2006', '11/1/2006', 'A', '100913', 'Y', 'D'
sp_reports_waste_summary2 1, '', '', '', NULL, '10/1/2006', '11/1/2006', 'G', '100913', 'Y';
sp_reports_waste_summary2 1, '', '', '', NULL, '', '', 'A', '101295', 'Y';
sp_reports_waste_summary2 0, '', '', '', NULL, '', '', 'G', '101296', 'Y';
sp_reports_waste_summary2 0, '', '', '', NULL, '7/1/2006', '7/14/2006', 'G', '101295', 'Y';

sp_reports_waste_summary2 0, '', '', '', NULL, '', '', 'A', '101296', 'Y';
sp_reports_waste_summary2 1, '', '', '', NULL, '', '', 'G', '10036', 'Y';

-- one generator from walmart by contact, by Approval
sp_reports_waste_summary2 0, '', '', '62879', NULL, '10/1/2006', '11/1/2006', 'A', '100913', 'Y';
-- one generator from walmart by contact, by Approval with Detail
sp_reports_waste_summary2 1, '', '', '62879', NULL, '10/1/2006', '11/1/2006', 'A', '100913', 'Y', 'D';
-- one generator from walmart by contact, by Generator
sp_reports_waste_summary2 1, '', '', '62879', NULL, '10/1/2006', '11/1/2006', 'G', '100913', 'Y';
-- one generator from walmart by contact, by Generator with Detail
	sp_reports_waste_summary2 0, '', '', '62879', NULL, '10/1/2006', '11/1/2006', 'G', '100913', 'Y', 'D'

sp_reports_waste_summary2 0, '', '10673', '', '', '10/1/2006', '11/1/2006', 'A', '', 'Y', 'D'
sp_reports_waste_summary2 0, '', '10673', '', '', '10/1/2006', '11/1/2006', 'G', '', 'Y', 'D'


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
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75


****************************************************************************************************/
SET NOCOUNT ON
SET ANSI_WARNINGS OFF

DECLARE	@execute_sql		varchar(8000),
	@execute_group 			varchar(8000),
	@execute_order 			varchar(8000),
	@generator_login_list	varchar(8000),
	@intCount 				int,
	@count_cust				int,
	@genCount				int,
	@custCount				int,
	@where					varchar(8000),
	@starttime				datetime

set @starttime = getdate()
declare @start_of_results int
declare @end_of_results int
declare @zero_based_index_offset int

IF @contact_id IS NULL SET @contact_id = ''


-- Housekeeping.  Gets rid of old paging records.
DECLARE @eightHoursAgo as DateTime
set @eightHoursAgo = DateAdd(hh, -8, getdate())
delete from Work_WasteReceivedSummaryDetailResultGroups where session_added < @eightHoursAgo
delete from Work_WasteReceivedSummaryDetailResultItems where session_added < @eightHoursAgo
delete from Work_WasteReceivedSummaryListResult where session_added < @eightHoursAgo

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Housekeeping' as description

-- Check to see if there's a @session_key provided with this query, and if that key is valid.
if datalength(@session_key) > 0 begin
	if (not exists(select distinct session_key from Work_WasteReceivedSummaryDetailResultGroups where session_key = @session_key)
		AND (NOT EXISTS (SELECT DISTINCT session_key FROM Work_WasteReceivedSummaryDetailResultItems where session_key = @session_key))
		AND (NOT EXISTS (SELECT DISTINCT session_key FROM Work_WasteReceivedSummaryListResult where session_key = @session_key)))  begin
		set @session_key = ''
		set @row_from = 1
		set @row_to = 20
	end
end

-- If there's still a populated @session key, skip the query - just get the results.
IF datalength(@session_key) > 0 goto returnresults 


if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Before Var setup' as description

set @session_key = newid()

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

	IF LEN(@contact_id) > 0
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
		INSERT INTO #customer
		SELECT id from #customer_id_list
		DELETE FROM #customer where customer_id is null
		IF @debug >= 1 PRINT 'SELECT FROM #customer'
		IF @debug >= 1 SELECT * FROM #customer

		INSERT INTO #generator
		SELECT id from #generator_id_list
		DELETE FROM #generator where generator_id is null
		IF @debug >= 1 PRINT 'SELECT FROM #generator'
		IF @debug >= 1 SELECT * FROM #generator
	END

	-- Time saver?
	-- Eliminate #customer/#generator records that won't be found when @customer_id_list
	-- or @generator_id_list are specified:
	set @execute_sql = ''
	IF (select count(*) from #customer_id_list) > 0
		set @execute_sql = 'DELETE from #customer where customer_id not in (select id from #customer_id_list);'
	IF (select count(*) from #generator_id_list) > 0
		set @execute_sql = 'DELETE from #generator where generator_id not in (select id from #generator_id_list);'

	select @custCount = count(*) from #customer
	select @genCount = count(*) from #generator	

    IF @debug >= 1 PRINT '@custCount:  ' + convert(varchar(20), @custCount)
    IF @debug >= 1 PRINT '@genCount:  ' + convert(varchar(20), @genCount)
	if @debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'


	if @debug >= 1 BEGIN
		SELECT '#customer', * FROM #customer
		SELECT '#generator', * FROM #generator
	END



	-- abort if there's nothing possible to see
	if @custCount + 
		@genCount + 
		len(ltrim(rtrim(isnull(@start_date, '')))) +
		len(ltrim(rtrim(isnull(@end_date, '')))) +
		(select count(*) from #approval_code_list)
		= 0 RETURN

-----------------------------------------
------- INBOUND (EQ) WASTE DATA: --------
-----------------------------------------
	-- Create #access_filter table to hold subset of fields (quicker to run queries this way?)
		CREATE TABLE #access_filter (
			company_id				int, 
			profit_ctr_id			int, 
			receipt_id				int,
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
	
		IF LEN(@start_date) > 0 OR LEN(@end_date) > 0
		BEGIN
			SET @where = @where + ' AND (r.receipt_date BETWEEN COALESCE(NULLIF(''' + @start_date + ''',''''), r.receipt_date) AND COALESCE(NULLIF(''' + @end_date + ''',''''), r.receipt_date)) '
		END

		SET @where = @where + ' AND r.submitted_flag = ''T'' AND r.trans_type = ''D'' AND r.receipt_status = ''A'' AND pfc.status = ''A'' AND pfc.view_on_web IN (''P'', ''C'') AND pfc.view_waste_summary_on_web = ''T'' AND cpy.view_on_web = ''T'' '

	    IF @debug >= 1 PRINT '@where:  ' + @where


		-- intermediate step: build a #access_filter table of the calculated columns:
	IF (select count(*) from #customer where customer_id <> -1) > 0 BEGIN
		SET @execute_sql = ' INSERT #access_filter SELECT 
			r.company_id,
			r.profit_ctr_id,
			r.receipt_id,
			''C'' as source
			FROM Receipt r
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
			''G'' as source
			FROM Receipt r
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

	IF @debug >= 1 
	BEGIN
		SELECT '#customer_id_list', * FROM #customer_id_list 	
		SELECT '#access_filter', * FROM #access_filter
	END

	-- Group Option Specific Code:		
	IF @report_type = 'A'
	BEGIN	-- Group by Approval
		-- final step: build query to populate Work_WasteReceivedSummaryListResult from #access_filter 
		SET @execute_sql = ' INSERT Work_WasteReceivedSummaryListResult 
			(company_id, 
				profit_ctr_id, 
				facility, 
				customer_id, 
				cust_name, 
				approval_code, 
				waste_code, 
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
				quantity, 
				pound_conv, 
				container_weight, 
				mode, 
				transaction_id, 
				receipt_date, 
				session_key, 
session_added)
		SELECT 
			t.company_id,
			t.profit_ctr_id AS profit_ctr_id,
			dbo.fn_web_profitctr_display_name(t.company_id, t.profit_ctr_id) as facility,
			r.customer_id,
			cust.cust_name AS cust_name,
			r.approval_code,
			r.waste_code,
			(
				select 
					convert(varchar(150), ltrim(rtrim(isnull(p.approval_desc, '''')))) 
				from profile p
				where p.profile_id = r.profile_id
			) as waste_description,
			wc.haz_flag,
			r.generator_id,
			g.epa_id AS epa_id,
			g.generator_name,
			g.generator_state,
			g.generator_city,
			g.site_code,
			rp.bill_unit_code,
			b.bill_unit_desc,
			isnull(rp.bill_quantity, 0) AS quantity,
			b.pound_conv AS pound_conv, 
			ISNULL(
			   ISNULL((SELECT (isnull(rp.bill_quantity, 0) / isnull(r.quantity, 0)) * ISNULL( SUM(container_weight), 0) 
				FROM container con (nolock)
				WHERE con.company_id = t.company_id
			  AND con.profit_ctr_id = t.profit_ctr_id
			  AND con.receipt_id = t.receipt_id
			  AND con.line_id = R.line_id
			  AND con.container_type = ''R''
			  AND con.status <> ''V'')
			   , r.net_weight)
			, 0) as container_weight,
			''Inbound'' as mode,
			''R'' + convert(varchar(15), t.receipt_id) as transaction_id,
			r.receipt_date,
			''' + @session_key + ''',
			getdate()			
			'

	
		-- Group by Approval
		SET @execute_group = '
		GROUP BY t.company_id,
			t.profit_ctr_id,
			r.customer_id,
			cust.cust_name,
			r.approval_code,
			r.waste_code,
			r.profile_id,
			-- p.approval_desc,
			wc.haz_flag,
			r.generator_id,
			g.epa_id,
			g.generator_name,
			g.generator_state,
			g.generator_city,
			g.site_code,
			r.receipt_date,
			t.receipt_id,
			rp.bill_unit_code,
			b.bill_unit_desc,
			isnull(rp.bill_quantity, 0),
			b.pound_conv,
			rp.bill_quantity,
			r.net_weight,
			r.quantity,
			r.line_id
'
			
	END	-- Group by Approval

ELSE

	BEGIN	-- Group by Generator, Approval
		-- final step: build query to populate Work_WasteReceivedSummaryListResult from #access_filter 
		SET @execute_sql = ' 
	INSERT Work_WasteReceivedSummaryListResult 
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
		quantity, 
		pound_conv, 
		container_weight, 
		mode, 
		transaction_id, 
		receipt_date, 
		session_key, 
		session_added)
			
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
			/* ltrim(rtrim(convert(varchar(150), ltrim(rtrim(r.approval_code)) + '' : '' + ltrim(rtrim(isnull(p.approval_desc, '''')))))) as waste_description, */
			wc.haz_flag,
			rp.bill_unit_code,
			b.bill_unit_desc,
			isnull(rp.bill_quantity, 0) AS quantity,
			b.pound_conv, 
			ISNULL(
			   ISNULL((SELECT (isnull(rp.bill_quantity, 0) / isnull(r.quantity, 0)) * ISNULL( SUM(container_weight), 0) 
				FROM container con (nolock)
				WHERE con.company_id = t.company_id
			  AND con.profit_ctr_id = t.profit_ctr_id
			  AND con.receipt_id = t.receipt_id
			  AND con.line_id = R.line_id
			  AND con.container_type = ''R''
			  AND con.status <> ''V'')
			   , r.net_weight)
			, 0) as container_weight,
			''Inbound'' as mode,
			''R'' + convert(varchar(15), t.receipt_id) as transaction_id,
			r.receipt_date,
			''' + @session_key + ''',
			getdate()
		'
	
		-- Group by Generator
		SET @execute_group = '
			GROUP BY t.company_id,
				t.profit_ctr_id,
				r.customer_id,
				cust.cust_name,
				r.generator_id,
				g.epa_id,
				g.generator_name,
				g.generator_state,
				g.generator_city,
				g.site_code,
				r.approval_code,
				r.profile_id,
				-- p.approval_desc,
				wc.haz_flag,
				rp.bill_unit_code,
				b.bill_unit_desc,
				isnull(rp.bill_quantity, 0),
				b.pound_conv,
				t.profit_ctr_id,
				t.receipt_id,
				r.receipt_date, 
				rp.bill_quantity,
				r.quantity,
				r.line_id,
				r.net_weight '
	END	-- Group by Generator


-- Add FROM clause and the beginning of the WHERE clause (that's common to both report types)
SET @execute_sql = @execute_sql + '
	FROM #access_filter t
	inner join Receipt r on 
		t.receipt_id = r.receipt_id 
		and t.company_id = r.company_id 
		and t.profit_ctr_id = r.profit_ctr_id
	INNER JOIN ReceiptPrice rp ON 
		R.receipt_id = rp.receipt_id
		AND R.company_id = rp.company_id
		AND R.profit_ctr_id = rp.profit_ctr_id
		AND R.line_id = rp.line_id
	INNER JOIN Company cpy ON r.company_id = cpy.company_id
	INNER JOIN ProfitCenter pfc ON 
		r.company_id = pfc.company_id 
		and r.profit_ctr_id = pfc.profit_ctr_id
	INNER JOIN Customer cust ON r.customer_id = cust.customer_id
	INNER JOIN Billing bill ON
		r.receipt_id = bill.receipt_id
		AND r.company_id = bill.company_id
		AND r.profit_ctr_id = bill.profit_ctr_id
		AND r.line_id = bill.line_id
		AND bill.trans_source = ''R''
		AND bill.status_code = ''I''
	-- INNER JOIN Profile p ON 
	--	pqa.profile_id = p.profile_id
	LEFT OUTER JOIN Billunit b ON rp.bill_unit_code = b.bill_unit_code
	LEFT OUTER JOIN Generator g on r.generator_id = g.generator_id
	LEFT OUTER JOIN wastecode wc on r.waste_code = wc.waste_code 
'

	set @execute_sql = @execute_sql + @where + @execute_group

-- -- -- -- -- -- --
-- debugging: Control whether this part of the SP runs
IF 1=1 BEGIN
-- -- -- -- -- -- --

if @debug between 5 and 10
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
	SELECT 'WasteSummary' as table_name, * from Work_WasteReceivedSummaryListResult
	
-- -- -- -- -- -- --
END
-- -- -- -- -- -- --




-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------
-- OUTBOUND (TSDF) WASTE DATA: --------------------------------------

	-- Create #workorder_access_filter table to hold subset of fields (quicker to run queries this way?)
IF object_id('tempdb..#workorder_access_filter') is not null drop table #workorder_access_filter

		CREATE TABLE #workorder_access_filter (
			company_id				int, 
			profit_ctr_id			int, 
			workorder_id			int
		)

		declare @workorder_access_filter varchar(8000)
		set @workorder_access_filter = ' INSERT INTO #workorder_access_filter(
			company_id, 
			profit_ctr_id, 
			workorder_id)
				SELECT DISTINCT
					w.company_id, 
					w.profit_ctr_id, 
					w.workorder_id
				FROM WorkOrderHeader w
			INNER JOIN WorkorderDetail d on 
				w.workorder_id = d.workorder_id
				AND w.company_id = d.company_id
				AND w.profit_ctr_id = d.profit_ctr_id
			INNER JOIN tsdfapproval t ON t.tsdf_approval_id = d.TSDF_Approval_ID
			INNER JOIN tsdf on t.tsdf_code = tsdf.tsdf_code
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

		IF LEN(@start_date) > 0 OR LEN(@end_date) > 0
			SET @workorder_access_filter = @workorder_access_filter + ' AND (w.end_date BETWEEN COALESCE(NULLIF(''' + @start_date + ''',''''), w.end_date) AND COALESCE(NULLIF(''' + @end_date + ''',''''), w.end_date)) '

		SET @workorder_access_filter = @workorder_access_filter + '
			AND tsdf.eq_flag = ''F''
			AND w.submitted_flag = ''T''
			AND pfc.status = ''A''
			AND pfc.view_on_web IN (''P'', ''C'')
			AND pfc.view_workorders_on_web = ''T''
			AND cpy.VIEW_ON_WEB = ''T''
		'
		


IF @debug >= 1
BEGIN
	
	PRINT @workorder_access_filter
	SELECT '#workorder_access_filter' as table_name, * from #workorder_access_filter
	PRINT ''
END

	EXEC(@workorder_access_filter)




	

--		IF @report_type = 'A' AND (select count(*) from #approval_code_list) > 0
--			SET @execute_sql = @execute_sql + ' AND t.tsdf_approval_code IN (select approval_code from #approval_code_list) '
--
--		IF LEN(@start_date) > 0 OR LEN(@end_date) > 0
--			SET @execute_sql = @execute_sql + ' AND (w.end_date BETWEEN COALESCE(NULLIF(''' + @start_date + ''',''''), w.end_date) AND COALESCE(NULLIF(''' + @end_date + ''',''''), w.end_date)) '
--
--		SET @execute_sql = @execute_sql + '
--			AND tsdf.eq_flag = ''F''
--			AND w.submitted_flag = ''T''
--			AND pfc.status = ''A''
--			AND pfc.view_on_web IN (''P'', ''C'')
--			AND pfc.view_workorders_on_web = ''T''
--			AND cpy.VIEW_ON_WEB = ''T''
--		'





select @intCount = count(customer_id) from WorkorderHeader where customer_id in (select customer_id from #customer_id_list)

if @intCount = 0 
	select @intCount = count(generator_id) from WorkorderHeader where generator_id in (select generator_id from #generator_id_list)

if @intCount > 0 
BEGIN

if @debug >= 1 print '(Starting Outbound logic) Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'



	IF @report_type = 'A'
	BEGIN	-- Group by Approval

		SET @execute_sql = '
		INSERT Work_WasteReceivedSummaryListResult (company_id, profit_ctr_id, facility, customer_id, cust_name, approval_code, waste_code, waste_description, haz_flag, generator_id, epa_id, generator_name, generator_state, generator_city, site_code, bill_unit_code, bill_unit_desc, quantity, pound_conv, container_weight, mode, transaction_id, receipt_date, session_key, session_added)
		SELECT DISTINCT
			99 as company_id,
			99 AS profit_ctr_id,
			tsdf.tsdf_name as facility,
			w.customer_id,
			cust.cust_name AS cust_name,
			t.tsdf_approval_code as approval_code,
			twc.waste_code as waste_code,
			convert(varchar(150), ltrim(rtrim(isnull(t.waste_desc, '''')))) as waste_description,
			/* ltrim(rtrim(convert(varchar(150), ltrim(rtrim(d.tsdf_approval_code)) + '' : '' + ltrim(rtrim(isnull(t.waste_desc, '''')))))) as waste_description, */
			t.hazmat as haz_flag,
			w.generator_id,
			g.epa_id AS epa_id,
			g.generator_name,
			g.generator_state,
			g.generator_city,
			g.site_code,
			d.bill_unit_code,
			b.bill_unit_desc,
			d.quantity,
			b.pound_conv AS pound_conv,
			isnull(d.pounds,0) AS container_weight,
			''Outbound'' as mode,
			''W'' + convert(varchar(15), w.workorder_id) as transaction_id,
			w.start_date as receipt_date,
			''' + @session_key + ''',
			getdate()'
	END	-- Group by Approval
	ELSE
	BEGIN	-- Group by Generator, Approval

		SET @execute_sql = '
		INSERT Work_WasteReceivedSummaryListResult (company_id, profit_ctr_id, facility, customer_id, cust_name, generator_id, epa_id, generator_name, generator_state, generator_city, site_code, waste_description, haz_flag, bill_unit_code, bill_unit_desc, quantity, pound_conv, container_weight, mode, transaction_id, receipt_date, session_key, session_added)
		SELECT DISTINCT
			99 as company_id,
			99 AS profit_ctr_id,
			tsdf.tsdf_name as facility,
			w.customer_id,
			cust.cust_name AS cust_name,
			w.generator_id,
			g.epa_id AS epa_id,
			g.generator_name,
			g.generator_state,
			g.generator_city,
			g.site_code,
			convert(varchar(150), ltrim(rtrim(isnull(t.waste_desc, '''')))) as waste_description,
			/* ltrim(rtrim(convert(varchar(150), ltrim(rtrim(d.tsdf_approval_code)) + '' : '' + ltrim(rtrim(isnull(t.waste_desc, '''')))))) as waste_description, */
			t.hazmat as haz_flag,
			d.bill_unit_code,
			b.bill_unit_desc,
			d.quantity,
			b.pound_conv AS pound_conv,
			isnull(d.pounds,0) AS container_weight,
			''Outbound'' as mode,
			''W'' + convert(varchar(15), w.workorder_id) as transaction_id,
			w.start_date as receipt_date,
			''' + @session_key + ''',
			getdate()'

	END	-- Group by Generator, Approval




	-- Add FROM clause and the beginning of the WHERE clause (that's common to both report types)
	SET @execute_sql = @execute_sql + '
		FROM #workorder_access_filter waf
			INNER JOIN WorkorderHeader w ON
				waf.workorder_id = w.workorder_id
				AND waf.company_id = w.company_id
				AND waf.profit_ctr_id = w.profit_ctr_id
			INNER JOIN WorkorderDetail d on 
				w.workorder_id = d.workorder_id
				AND w.company_id = d.company_id
				AND w.profit_ctr_id = d.profit_ctr_id
			INNER JOIN tsdfapproval t ON t.tsdf_approval_id = d.TSDF_Approval_ID
			INNER JOIN tsdf on t.tsdf_code = tsdf.tsdf_code
			INNER JOIN Company cpy ON w.company_id = cpy.company_id
			INNER JOIN ProfitCenter pfc ON w.company_id = pfc.company_id and w.profit_ctr_id = pfc.profit_ctr_id
			INNER JOIN Customer cust ON w.customer_id = cust.customer_id
			INNER JOIN Billing bill ON bill.company_id = w.company_id
				AND bill.profit_ctr_id = w.profit_ctr_id
				AND bill.receipt_id = w.workorder_id 
				AND bill.trans_source = ''W''
			LEFT OUTER JOIN Billunit b ON d.bill_unit_code = b.bill_unit_code
			LEFT OUTER JOIN Generator g ON w.generator_id = g.generator_id
			LEFT OUTER JOIN tsdfapprovalwastecode twc on t.tsdf_approval_id = twc.tsdf_approval_id and t.company_id = twc.company_id and t.profit_ctr_id = twc.profit_ctr_id and twc.primary_flag = ''T'' 
		WHERE 1=1 '
--
--		-- this section only applies to contacts
--		IF LEN(@contact_id) > 0
--		BEGIN
--			SET @execute_sql = @execute_sql + '
--			AND ( 1=0 '
--		
--			IF @custCount > 0
--				SET @execute_sql = @execute_sql + '
--					or exists (
--						Select customer_id from #customer cxr
--						Where cxr.customer_id = w.customer_id 
--					)
--					'
--			IF @genCount > 0
--			BEGIN
--				SET @execute_sql = @execute_sql + '
--					or exists ( 
--						Select generator_id from #generator cxr
--						Where cxr.generator_id = w.generator_id 
--					)
--					'
--				END
--					
--			SET @execute_sql = @execute_sql + '
--			) '
--		END
--		ELSE -- For Associates:
--			IF (select count(*) from #customer_id_list) > 0
--				SET @execute_sql = @execute_sql + '
--					AND (1=1) '
--		
--	
--		IF (select count(*) from #customer_id_list) > 0
--			SET @execute_sql = @execute_sql + '	AND ( w.customer_id IN (select id from #customer_id_list) ) '
--
--		IF (select count(*) from #generator_id_list) > 0
--			SET @execute_sql = @execute_sql + ' AND ( w.generator_id IN (select id from #generator_id_list) ) '
--		
--		IF @report_type = 'A' AND (select count(*) from #approval_code_list) > 0
--			SET @execute_sql = @execute_sql + ' AND t.tsdf_approval_code IN (select approval_code from #approval_code_list) '
--
--		IF LEN(@start_date) > 0 OR LEN(@end_date) > 0
--			SET @execute_sql = @execute_sql + ' AND (w.end_date BETWEEN COALESCE(NULLIF(''' + @start_date + ''',''''), w.end_date) AND COALESCE(NULLIF(''' + @end_date + ''',''''), w.end_date)) '
--
		SET @execute_sql = @execute_sql + '
			AND tsdf.eq_flag = ''F''
			AND w.submitted_flag = ''T''
			AND pfc.status = ''A''
			AND pfc.view_on_web IN (''P'', ''C'')
			AND pfc.view_workorders_on_web = ''T''
			AND cpy.VIEW_ON_WEB = ''T''
		'

		--print @execute_sql

	-- -- -- -- -- -- --
	-- debugging: Control whether this part of the SP runs
	IF 1=1 BEGIN
	-- -- -- -- -- -- --

	IF @debug >= 1
	BEGIN
		PRINT @execute_sql
		PRINT ''
	END

	if @debug < 10
		EXEC(@execute_sql)
	if @debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'

	-- -- -- -- -- -- --
	END
	-- -- -- -- -- -- --

ELSE
if @debug >= 1 print '(Skipping Outbound logic) Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'
END


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
			waste_code varchar(50),
			waste_description varchar(50),
			haz_flag varchar(50),
			bill_unit_code varchar(50),
			bill_unit_desc varchar(50),
			quantity float,
			lbs_waste float,
			total_weight_method float,
			mode varchar(50), 
			session_key uniqueidentifier
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
			waste_code,
			waste_description,
			haz_flag,
			bill_unit_code,
			bill_unit_desc,
			SUM(isnull(quantity, 0)) as quantity,
			SUM(
				CASE 
				WHEN IsNull(container_weight, 0) = 0
					THEN (isnull(quantity, 0) * isnull(pound_conv, 0))
				ELSE IsNull(container_weight, 0)
				END				
			) AS lbs_waste,
			CASE WHEN (IsNull(container_weight, 0)) = 0
				THEN 1 -- 'Calculated'
				ELSE 0 -- 'Actual'
			END as weight_method,
			mode, @session_key
		FROM Work_WasteReceivedSummaryListResult
		WHERE session_key = @session_key
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
			waste_code,
			waste_description,
			haz_flag,
			bill_unit_code,
			bill_unit_desc,
			container_weight,
			mode
		ORDER BY -- approval/summary order by
			company_id,
			profit_ctr_id,
			facility,
			generator_name,
			epa_id,
			approval_code,
			cust_name,
			bill_unit_code
			
	
		INSERT Work_WasteReceivedSummaryDetailResultGroups
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
			waste_code ,
			waste_description ,
			haz_flag ,
			bill_unit_code ,
			bill_unit_desc ,
			quantity ,
			lbs_waste ,
			total_weight_method ,
			mode , 
			session_key 
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
			waste_code,
			waste_description,
			haz_flag,
			bill_unit_code,
			bill_unit_desc,
			SUM(isnull(quantity, 0)) as quantity,
			SUM(lbs_waste) as lbs_waste,
			SUM(total_weight_method) ,
			mode, @session_key
		FROM #s_a_paging
		WHERE session_key = @session_key
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
			waste_code,
			waste_description,
			haz_flag,
			bill_unit_code,
			bill_unit_desc,
			mode, session_key
		ORDER BY 
			company_id,
			profit_ctr_id,
			facility,
			generator_name,
			epa_id,
			approval_code,
			cust_name,
			bill_unit_code


		
	END
	ELSE
	BEGIN -- Group by Generator, Approval
--
--
--		select  @start_of_results = min(row_num)-1, 
--				@end_of_results = max(row_num) 
--			from Work_WasteReceivedSummaryDetailResultGroups where session_key = @session_key
--		
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
			haz_lbs_waste float,
			nonhaz_lbs_waste float,
			total_weight_method float,
			mode varchar(50),
			session_key uniqueidentifier
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
				THEN
					CASE 
					WHEN IsNull(container_weight, 0) = 0
						THEN (isnull(quantity, 0) * isnull(pound_conv, 0))
					ELSE IsNull(container_weight, 0)
					END			
				ELSE 0
				END
			) AS haz_lbs_waste,
			SUM(
				CASE WHEN haz_flag <> 'T'
					THEN 
						CASE 
						WHEN IsNull(container_weight, 0) = 0
							THEN (isnull(quantity, 0) * isnull(pound_conv, 0))
						ELSE IsNull(container_weight, 0)
						END
					ELSE 0
				END
			) AS nonhaz_lbs_waste,
			CASE WHEN (IsNull(container_weight, 0)) = 0
				THEN 1 -- 'Calculated'
				ELSE 0 -- 'Actual'
			END as weight_method,
			mode, @session_key
		FROM Work_WasteReceivedSummaryListResult
		WHERE session_key = @session_key
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
			container_weight,
			mode, session_key
		ORDER BY 
			company_id,
			profit_ctr_id,
			facility,
			cust_name,
			generator_name,
			epa_id




		INSERT Work_WasteReceivedSummaryDetailResultGroups 
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
			haz_lbs_waste,
			nonhaz_lbs_waste,
			total_weight_method,
			mode,
			session_key
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
			SUM(haz_lbs_waste) as haz_lbs_waste,
			SUM(nonhaz_lbs_waste) as nonhaz_lbs_waste,
			--CASE WHEN SUM(weight_method) > 0 THEN 'Calculated' ELSE 'Actual' END as weight_method,
			SUM(total_weight_method) as total_weight_method,
			mode,
			@session_key
		FROM #s_g_paging
		where session_key = @session_key
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
			session_key
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

-- selects below come straight from Work_WasteReceivedSummaryListResult.  That doesn't help. Need them to come from a table with a row id for sorting help.
-- If header is a superset of detail, then populate the detail info into a tmp table, and output from there.

	IF @report_type = 'A' -- Group by Approval
	BEGIN

		INSERT Work_WasteReceivedSummaryDetailResultItems (
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
			waste_code,
			waste_description,
			haz_flag,
			receipt_date,
			transaction_id,
			bill_unit_code,
			bill_unit_desc,
			quantity,
			lbs_waste,
			weight_method,
			mode,
			session_key
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
			waste_code,
			waste_description,
			haz_flag,
			receipt_date,
			transaction_id,
			bill_unit_code,
			bill_unit_desc,
			SUM(isnull(quantity, 0)) as quantity,
			SUM(
				CASE 
				WHEN IsNull(container_weight, 0) = 0
					THEN (isnull(quantity, 0) * isnull(pound_conv, 0))
				ELSE IsNull(container_weight, 0)
				END
			) AS lbs_waste,
			CASE WHEN SUM(IsNull(container_weight, 0)) = 0
				THEN 1 -- 'Calculated'
				ELSE 0 -- 'Actual'
			END as weight_method,
			mode,
			@session_key
		FROM Work_WasteReceivedSummaryListResult
		where session_key = @session_key
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
			waste_code,
			waste_description,
			haz_flag,
			receipt_date,
			transaction_id,
			bill_unit_code,
			bill_unit_desc,
			mode,
			session_key
		ORDER BY 
			company_id,
			profit_ctr_id,
			facility,
			generator_name,
			epa_id,
			approval_code,
			receipt_date,
			transaction_id,
			cust_name,
			bill_unit_code

	
	END
	ELSE -- Group by Generator, Approval
	BEGIN
	
		INSERT Work_WasteReceivedSummaryDetailResultItems (
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
			transaction_id,
			bill_unit_code,
			bill_unit_desc,
			haz_quantity,
			nonhaz_quantity,
			haz_lbs_waste,
			nonhaz_lbs_waste,
			weight_method,
			mode, session_key
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
			transaction_id,
			bill_unit_code,
			bill_unit_desc,
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
					THEN 
						CASE 
						WHEN IsNull(container_weight, 0) = 0
							THEN (isnull(quantity, 0) * isnull(pound_conv, 0))
						ELSE IsNull(container_weight, 0)
						END
					ELSE 0
				END
			) AS haz_lbs_waste,
			SUM(
				CASE WHEN haz_flag <> 'T'
					THEN 
						CASE 
						WHEN IsNull(container_weight, 0) = 0
							THEN (isnull(quantity, 0) * isnull(pound_conv, 0))
						ELSE IsNull(container_weight, 0)
						END
					ELSE 0
				END
			) AS nonhaz_lbs_waste,
			
			CASE WHEN SUM((IsNull(container_weight, 0))) = 0
				THEN 1 -- 'Calculated'
				ELSE 0 -- 'Actual'
			END as weight_method,
			mode, @session_key
		FROM Work_WasteReceivedSummaryListResult
			WHERE session_key = @session_key
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
			transaction_id,
			haz_flag,
			bill_unit_code,
			bill_unit_desc,
			mode
		ORDER BY 
			company_id,
			profit_ctr_id,
			facility,
			cust_name,
			generator_name,
			epa_id,
			receipt_date, 
			transaction_id,
			haz_flag,
			bill_unit_code 
	END
END

---------------------------------------------------------------
----------------------- RETURN RESULTS ------------------------
---------------------------------------------------------------

returnresults:
	

IF @level = 'S' BEGIN

	-- Select from the Work_WasteReceivedSummaryListResult data (not detail version) to create the report:
	IF @report_type = 'A' BEGIN -- Group by Approval

		-- MIN(rowid) here will equal the first record (for the page range requested), 
		-- but we want to start at the record 0, so subtract 1
		set @zero_based_index_offset = 1
		select  @start_of_results = min(row_num) - @zero_based_index_offset,
				@end_of_results = max(row_num) 
		from Work_WasteReceivedSummaryDetailResultGroups where session_key = @session_key	

--		select  @start_of_results = min(row_num), --, test: -1, 
--				@end_of_results = max(row_num) 
--			from Work_WasteReceivedSummaryDetailResultGroups where session_key = @session_key

		if @debug > 0
				select  'returnresults, Summary (by Approval), @start_of_results' = @start_of_results,
				'returnresults, Summary (by Approval), @end_of_results ' = @end_of_results

		SELECT company_id,
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
				waste_code,
				waste_description,
				haz_flag,
				bill_unit_code,
				bill_unit_desc,
				quantity,
				lbs_waste,
			CASE 
				WHEN total_weight_method > 0 
					THEN 'Calculated'
					ELSE 'Actual'
				END as weight_method,
			mode,
			@end_of_results - @start_of_results as record_count,
			session_key
			FROM Work_WasteReceivedSummaryDetailResultGroups
		WHERE session_key = @session_key
		AND row_num >= @start_of_results + @row_from
		and row_num <= 
			case 
				when @row_to = -1 
				then @end_of_results 
				else @start_of_results + @row_to 
			END


	END
	ELSE
	BEGIN -- Generator Group

		-- MIN(rowid) here will equal the first record (for the page range requested), 
		-- but we want to start at the record 0, so subtract 1
		set @zero_based_index_offset = 1
		select  @start_of_results = min(row_num) - @zero_based_index_offset,
				@end_of_results = max(row_num) 
		from Work_WasteReceivedSummaryDetailResultGroups where session_key = @session_key	

--		select  @start_of_results = min(row_num), --test, -1, 
--				@end_of_results = max(row_num) 
--			from Work_WasteReceivedSummaryDetailResultGroups 
--			where session_key = @session_key

		SELECT *,
			CASE 
				WHEN total_weight_method > 0 
					THEN 'Calculated'
					ELSE 'Actual'
				END as weight_method,
			@end_of_results - @start_of_results as record_count
			FROM Work_WasteReceivedSummaryDetailResultGroups
		WHERE 
		session_key = @session_key
		and row_num >= @start_of_results + @row_from
		and row_num <= 
			case 
				when @row_to = -1 
				then @end_of_results 
				else @start_of_results + @row_to 
			END
	END
END
ELSE 
BEGIN -- report is Detail





	IF @report_type = 'A' BEGIN -- Group by Approval
-- Select out Header query (Approval mode)

			-- This paging table is used to store the actual results that
			-- will be returned to the user (summed, grouped).  This is required
			-- to properly return the specific slice/page of data returned to the user
			create table #d_a_paging
			(
				rowid int identity,
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
				site_code varchar(50),
				approval_code varchar(50),
				waste_code varchar(50),
				waste_description varchar(50),
				mind_id int,
				maxd_id int,
				session_key uniqueidentifier
			)	

		INSERT #d_a_paging
		SELECT DISTINCT
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
			waste_code,
			waste_description,
			min(row_num) as mind_id,
			max(row_num) as maxd_id,
			session_key
		FROM Work_WasteReceivedSummaryDetailResultItems
		WHERE session_key = @session_key
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
			waste_code,
			waste_description,
			session_key
		ORDER BY 
			company_id,
			profit_ctr_id,
			facility,
			generator_name,
			epa_id,
			approval_code,
			cust_name


		-- MIN(rowid) here will equal 1 (for the first page), 
		-- but we want to start at the record 0, so subtract 1
		set @zero_based_index_offset = 1
		select  @start_of_results = min(rowid) - @zero_based_index_offset,
				@end_of_results = max(rowid) 
			from #d_a_paging 

		if @debug > 0
			select 'start_of_results' = @start_of_results, 'end_of_results' = @end_of_results

		SELECT *,
			@end_of_results - @start_of_results as record_count
			 FROM #d_a_paging
			WHERE rowid >= @start_of_results + @row_from
		and rowid <= 
			case 
				when @row_to = -1 
				then @end_of_results 
				else @start_of_results + @row_to 
			END

		-- Select out Detail query (Approval mode)
		SELECT DISTINCT
			item.company_id,
			item.profit_ctr_id,
			item.facility,
			item.customer_id,
			item.cust_name,
			item.generator_id,
			item.epa_id,
			item.generator_name,
			item.generator_state,
			item.generator_city,
			item.site_code,
			item.approval_code,
			item.waste_code,
			item.waste_description,
			item.haz_flag,
			item.receipt_date,
			item.transaction_id,
			item.bill_unit_code,
			item.bill_unit_desc,
			item.quantity,
			item.lbs_waste,
			CASE WHEN item.weight_method > 0 THEN 'Calculated' ELSE 'Actual' END as weight_method,
			item.mode,
			item.session_key
			--item.row_num,
			--paging.rowid
		FROM Work_WasteReceivedSummaryDetailResultItems item,
			(SELECT *,
				@end_of_results - @start_of_results as record_count
			 FROM #d_a_paging
			WHERE rowid >= @start_of_results + @row_from
			and rowid <= 
			case 
				when @row_to = -1 
				then @end_of_results 
				else @start_of_results + @row_to 
			END) paging
			WHERE item.row_num BETWEEN paging.mind_id AND paging.maxd_id
			--ORDER BY item.row_num
			ORDER BY
		   item.company_id,    
		   item.profit_ctr_id,    
		   item.facility,    
		   item.generator_name,    
		   item.epa_id,    
		   item.approval_code,    
		   item.cust_name,    
		   item.bill_unit_code    

	END
	ELSE
	BEGIN 
		-- Generator Group




		-- This paging table is used to store the actual results that
		-- will be returned to the user (summed, grouped).  This is required
		-- to properly return the specific slice/page of data returned to the user
		create table #d_g_paging
		(
			rowid int identity,
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
			site_code varchar(50),
			mind_id int,
			maxd_id int,
			session_key uniqueidentifier
		)

-- Select out Header query (Generator mode)
	
		INSERT #d_g_paging
		SELECT DISTINCT
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
			min(row_num) as mind_id,
			max(row_num) as maxd_id,
			session_key
		FROM Work_WasteReceivedSummaryDetailResultItems
			WHERE Session_key = @session_key
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
			session_key
		ORDER BY 
			company_id,
			profit_ctr_id,
			facility,
			cust_name,
			generator_name,
			epa_id


		-- MIN(rowid) here will equal the first record (for the page range requested), 
		-- but we want to start at the record 0, so subtract 1
		set @zero_based_index_offset = 1
		select  @start_of_results = min(rowid) - @zero_based_index_offset,
				@end_of_results = max(rowid) 
		from #d_g_paging 

		SELECT *,
			@end_of_results - @start_of_results as record_count
		 FROM #d_g_paging
		WHERE rowid >= @start_of_results + @row_from
		and rowid <= 
		case 
			when @row_to = -1 
			then @end_of_results 
			else @start_of_results + @row_to 
		END

		-- Select out Detail query (Generator mode)
		SELECT 
			item.company_id,
			item.profit_ctr_id,
			item.facility,
			item.customer_id,
			item.cust_name,
			item.generator_id,
			item.epa_id,
			item.generator_name,
			item.generator_state,
			item.generator_city,
			item.site_code,
			item.haz_flag,
			item.receipt_date,
			item.transaction_id,
			item.bill_unit_code,
			item.bill_unit_desc,
			item.haz_quantity,
			item.nonhaz_quantity,
			item.haz_lbs_waste,
			item.nonhaz_lbs_waste,
			CASE WHEN item.weight_method > 0 THEN 'Calculated' ELSE 'Actual' END as weight_method,
			item.mode,
			item.session_key,
			item.row_num,
			paging.rowid
		FROM Work_WasteReceivedSummaryDetailResultItems item
			INNER JOIN -- this inline table is used to only select detail records that are selected for the selected page of data
				(SELECT *,
					@end_of_results - @start_of_results as record_count
				 FROM #d_g_paging
				WHERE rowid >= @start_of_results + @row_from
				and rowid <= 
				case 
					when @row_to = -1 
					then @end_of_results 
					else @start_of_results + @row_to 
				END) paging 
			ON item.row_num BETWEEN paging.mind_id AND paging.maxd_id
			WHERE item.session_key = @session_key
			ORDER BY item.row_num

	END
END


if @debug >= 1 print 'Elapsed time: ' + convert(varchar(20), datediff(ms, @starttime, getdate())) + 'ms'


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_waste_summary2] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_waste_summary2] TO [COR_USER]
    AS [dbo];


