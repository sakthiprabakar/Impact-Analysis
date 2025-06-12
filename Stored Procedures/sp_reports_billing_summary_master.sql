-- drop proc sp_reports_billing_summary_master
go

CREATE PROCEDURE sp_reports_billing_summary_master
	@debug				int,    -- 0 or 1 for no debug/debug mode  
	@database_list		varchar(max), -- Comma Separated Company List  
	@customer_id_list	varchar(max), -- Comma Separated Customer ID List - what customers to include  
	@generator_id_list	varchar(max), -- Comma Separated Generator ID List - what generators to include  
	@approval_code		varchar(max), -- Approval Code  
	@invoice_code_list	varchar(max), -- Invoice Code  
	@manifest			varchar(max), -- Manfiest Code  
	@start_date			varchar(20),  -- Start Date  
	@end_date			varchar(20),  -- Start Date  
	@description		varchar(100), -- Description search field
	@po_release			varchar(100), -- PO, Release search field
	@detail_level		char(1),	-- Summary or Detail?  
	@contact_id			int = 0,	-- Contact ID or -1 for Associates.  
	@session_key		varchar(100) = '',	-- unique identifier key to a previously run query's results
	@row_from			int = 1,			-- when accessing a previously run query's results, what row should the return set start at?
	@row_to				int = 20			-- when accessing a previously run query's results, what row should the return set end at (-1 = all)?
AS  
/* *******************  
sp_reports_billing_summary_master:  
  
Returns the data for Billing Summary.  
This SP can return prices - so it's not for generator access.  Contacts must be limited to their own accounts.  
  
  
LOAD TO PLT_AI * on NTSQL1  

Testing/examples:

-- Summary:
	DECLARE @debug int, @database_list varchar(8000), @customer_id_list varchar(8000), @generator_id_list varchar(8000), @approval_code varchar(8000), @invoice_code_list varchar(8000), @manifest varchar(8000), @start_date varchar(20), @end_date varchar(20), @description varchar(100), @po_release varchar(100), @detail_level char(1), @contact_id int, @session_key varchar(100), @row_from int, @row_to int
	SELECT @debug = 0, @database_list = '2|21, 3|1, 12|0, 14|0, 15|1, 21|0, 22|0, 23|0, 24|0', @customer_id_list = '', @generator_id_list = '', @approval_code = '', @invoice_code_list = '', @manifest = '', @start_date = '', @end_date = '', @description = '', @po_release = '',  @detail_level = 'D', @contact_id = -1, @session_key = '', @row_from = 1, @row_to = 20
	SELECT @debug = 0,
		@customer_id_list 	= '12068',
		@start_date   		= '1/1/2009', 
		@end_date   		= '1/15/2009'

	exec sp_reports_billing_summary_master @debug, @database_list, @customer_id_list, @generator_id_list, @approval_code, @invoice_code_list, @manifest, @start_date, @end_date, @description, @po_release, @detail_level, @contact_id, @session_key, @row_from, @row_to
SELECT top 30 approval_code, profile_id, tsdf_approval_id, * from billing where status_code = 'I' and approval_code = '' order by billing_date desc

SELECT approval_code, profile_id, tsdf_approval_id, * from billing where receipt_id = 1474905
SELECT * from workorderdetail where workorder_id = 1474905 and sequence_id = 1

-- Detail: (change session_key to value returned in summary)
	DECLARE @debug int, @database_list varchar(8000), @customer_id_list varchar(8000), @generator_id_list varchar(8000), @approval_code varchar(8000), @invoice_code_list varchar(8000), @manifest varchar(8000), @start_date varchar(20), @end_date varchar(20), @description varchar(100), @po_release varchar(100), @detail_level char(1), @contact_id int, @session_key varchar(100), @row_from int, @row_to int
	SELECT @debug = 1, @database_list = '2|0, 3|0, 12|0, 14|0, 15|1, 21|0, 22|0, 23|0, 24|0, 27|0', @customer_id_list = '', @generator_id_list = '', @approval_code = '', @invoice_code_list = '', @manifest = '', @start_date = '', @end_date = '', @description = '', @po_release = '',  @detail_level = 'S', @contact_id = -1, @session_key = '', @row_from = 1, @row_to = 81
	SELECT
		 @debug    			= 0,
		 @customer_id_list 	= '888880',
		 @invoice_code_list = '',
		 @start_date   		= '1/1/2007', 
		 @end_date   		= '11/30/2014',
		 @detail_level 		= 'D',
		 @session_key 		= ''

	EXEC sp_reports_billing_summary_master @debug, @database_list, @customer_id_list, @generator_id_list, @approval_code, @invoice_code_list, @manifest, @start_date, @end_date, @description, @po_release, @detail_level, @contact_id, @session_key, @row_from, @row_to


-- Detail: (change session_key to value returned in summary)
	DECLARE @debug int, @database_list varchar(8000), @customer_id_list varchar(8000), @generator_id_list varchar(8000), @approval_code varchar(8000), @invoice_code_list varchar(8000), @manifest varchar(8000), @start_date varchar(20), @end_date varchar(20), @description varchar(100), @po_release varchar(100), @detail_level char(1), @contact_id int, @session_key varchar(100), @row_from int, @row_to int
	SELECT @debug = 1, @database_list = '2|0, 3|0, 12|0, 14|0, 15|1, 21|0, 22|0, 23|0, 24|0, 27|0', @customer_id_list = '', @generator_id_list = '', @approval_code = '', @invoice_code_list = '', @manifest = '', @start_date = '', @end_date = '', @description = '', @po_release = '',  @detail_level = 'S', @contact_id = -1, @session_key = '', @row_from = 1, @row_to = 20
	SELECT
		 @debug    			= 0,
		 @customer_id_list 	= '12469',
		 @invoice_code_list = '40443703',
		 @start_date   		= '1/1/2013', 
		 @end_date   		= '3/31/2013',
		 @detail_level 		= 'D',
		 @session_key 		= ''

	EXEC sp_reports_billing_summary_master @debug, @database_list, @customer_id_list, @generator_id_list, @approval_code, @invoice_code_list, @manifest, @start_date, @end_date, @description, @po_release, @detail_level, @contact_id, @session_key, @row_from, @row_to


History:  
05/26/2005 JPB Created  
12/11/2006 JPB Took out a redundant creation of tblToolsStringParserCounter  
	Removed customer/generator validation routines so they're only called in the slave SPs  
	Revised database selection option - only runs once per company now.  
01/17/2007 JPB Removed Group by Approval, Added Group by Invoice Number, Removed Waste Code input, added Invoice Number List input.  
02/13/2007 JPB Removed grouping entirely - if you want grouping, use excel.  
	Added Summary vs Detail mode to cut down on rows returned if not necessary.  

Central Invoicing:  
	JPB Converted to Central-Invoicing version: Billing, Invoice tables move to plt_ai. No longer needs 'slave' sp to run.  
	JPB Converted input lists to temp tables more efficiently  

02/05/2009 RJG  Added #access_filter pattern to proc.
				Added record paging / report snapshot insertion to proc (Work_BillingSummaryDetailResult and Work_BillingSummaryListResult tables)
  
08/04/2009 JPB
	GEM:12925 - Added line_desc_2 to output
	GEM:13151 - Queries were returning invoicedetail lines that were not the current 'I'nvoiced lines.
		Noticed that the Detail table wasn't being populated before it was called,
		leading to detail queries to be empty.

09/11/2009 JPB
	GEM:13336 - Add ability to search by description
	GEM:13305 - Added ability to search by po/release

04/12/2012	JPB
	GEM:20911 - Added TSDF Approval Code to output when billing.approval_code is blank and there's a tsdf_approval_id present.
04/13/2012	JPB
	- Removed the ProfileQuoteApproval join, because it may show bad info. Need to rewrite this report
04/30/2012	JPB
	- Revised the TSDF/Approval filtering, since multiple values broke the join it used.
03/26/2013	JDB
	- Removed join to InvoiceDetail, and replaced it with information from BillingDetail in order to get the proper
		insurance surcharge, energy surcharge and sales tax amounts (which will be summarized to one line per invoice).
	- Changed join to the #access_filter table to utilize the billing_uid field from Billing.

04/03/2013 JPB
	Revised the invoice_id and manifest subquery lookups so they don't fail on multiple record cases.
10/13/2015 JPB
	Added a status_code <> 'V' check in the billing select because if you do an adjustment the wrong way it does this.
12/01/2017 JPB
	GEM-41934 - Add fields to detail output
05/22/2018 EQAI-50534 - AM - Added "SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED" not to block other users.
12/2/2019 SAM:16407 - add Generator.generator_division and generator_region_code to output
********************* */  

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
  
DECLARE @access_filter_sql	varchar(MAX) ,
		@starttime			datetime ,
		@start_of_results	int,
		@end_of_results		int,
		@count_invoice		int,
		@detail_sql			varchar(MAX) ,
		@detail_query		varchar(MAX) ,
		@detail_join		varchar(MAX),
		@this_desc			varchar(100),
		@detail_where		varchar(MAX),
		@detail_order		varchar(MAX),
		@detail_group		varchar(MAX),
		@regular_sql		varchar(MAX),
		@mi_sr_sql			varchar(MAX),
		@surcharge_sql		varchar(MAX),
		@results_sql		varchar(MAX)

SET @starttime = GETDATE()

SELECT @detail_sql = '
	/* QUERY */
	FROM Billing b  
	LEFT JOIN BillingComment bc ON b.trans_source = bc.trans_source
		AND b.receipt_id = bc.receipt_id
		AND b.company_id = bc.company_id
		and b.profit_ctr_id = bc.profit_ctr_id
	INNER JOIN InvoiceHeader ih ON ih.invoice_id = b.invoice_id
		AND ih.status = ''I'' 
	INNER JOIN Customer c ON c.customer_id = b.customer_id  
	INNER JOIN BillUnit bu ON bu.bill_unit_code = b.bill_unit_code
	INNER JOIN ProfitCenter p ON p.company_id = b.company_id
		AND p.profit_ctr_id = b.profit_ctr_id
	INNER JOIN CustomerBilling cb ON cb.customer_id = b.customer_id 
		AND cb.billing_project_id = b.billing_project_id
	LEFT OUTER JOIN Generator g ON g.generator_id = b.generator_id  
	LEFT OUTER JOIN TSDFApproval ta ON ta.tsdf_approval_id = b.tsdf_approval_id 
	/* JOIN */
	WHERE 1=1 and b.status_code <> ''V'' /* WHERE */
	',
	@detail_where = '',
	@detail_order = ''

-- Housekeeping.  Gets rid of old paging records.
DECLARE @eightHoursAgo AS DateTime
SET @eightHoursAgo = DATEADD(hh, -8, GETDATE())
DELETE FROM Work_BillingSummaryDetailResult WHERE session_added < @eightHoursAgo
DELETE FROM Work_BillingSummaryListResult WHERE session_added < @eightHoursAgo


IF @debug > 3 SELECT DATEDIFF(ms, @starttime, GETDATE()) AS timer, 'After Housekeeping' AS description

-- Check to see if there's a @session_key provided with this query, and if that key is valid.
IF DATALENGTH(@session_key) > 0 
BEGIN
	IF NOT EXISTS(SELECT DISTINCT session_key FROM Work_BillingSummaryListResult WHERE session_key = @session_key)
		-- AND (NOT EXISTS(SELECT DISTINCT session_key FROM Work_BillingSummaryDetailResult WHERE session_key = @session_key))
	BEGIN
		SET @session_key = ''
		SET @row_from = 1
		SET @row_to = 20
	END
END

  
-- Create temp tables for data storage/validation  
CREATE TABLE #customer_id_list (customer_id int)  
CREATE INDEX idx1 ON #customer_id_list (customer_id)  
INSERT #Customer_id_list 
	SELECT convert(int, row) 
	from dbo.fn_SplitXsvText(',', 0, @customer_id_list) 
	WHERE ISNULL(row, '') <> ''  
  
CREATE TABLE #generator_id_list (generator_id int)  
CREATE INDEX idx2 ON #generator_id_list (generator_id)  
INSERT #generator_id_list 
	SELECT convert(int, row) 
	from dbo.fn_SplitXsvText(',', 0, @generator_id_list) 
	WHERE ISNULL(row, '') <> ''  
    
CREATE TABLE #invoice_code_list (invoice_code varchar(16))  
CREATE INDEX idx3 ON #invoice_code_list (invoice_code)  
INSERT #invoice_code_list 
	SELECT row 
	from dbo.fn_SplitXsvText(',', 1, @invoice_code_list) 
	WHERE ISNULL(row, '') <> ''  
  
CREATE TABLE #Approval (approval_code varchar(15))  
CREATE INDEX idx4 ON #Approval (approval_code)  
INSERT #Approval 
	SELECT row 
	from dbo.fn_SplitXsvText(',', 1, @approval_code) 
	WHERE ISNULL(row, '') <> ''  
   
CREATE TABLE #Manifest (manifest varchar(15))  
CREATE INDEX idx5 ON #Manifest (manifest)  
INSERT #Manifest 
	SELECT row 
	from dbo.fn_SplitXsvText(',', 1, @manifest) 
	WHERE ISNULL(row, '') <> ''  
  
CREATE TABLE #Description (term varchar(100), process_flag int)  
INSERT #Description
	SELECT row, 0
	from dbo.fn_SplitXsvText(',', 1, @description) 
	WHERE ISNULL(row, '') <> ''  

IF (SELECT COUNT(*) FROM #description) > 0
BEGIN
	SET @detail_where = @detail_where + ' 
	AND ( 1=0 
	'
	WHILE ((SELECT COUNT(*) FROM #description WHERE process_flag = 0) > 0)
	BEGIN
		SELECT TOP 1 @this_desc = term FROM #description WHERE process_flag = 0
		SET @detail_where = @detail_where + '    OR ISNULL(b.service_desc_1, '''') + '' '' + ISNULL(b.service_desc_2, '''') LIKE ''%' + REPLACE(@this_desc, ' ', '%') + '%''
		'
		UPDATE #description SET process_flag = 1 WHERE term = @this_desc
	END
	SET @detail_where = @detail_where + ' ) 
	'
	UPDATE #description SET process_flag = 0
END
	
CREATE TABLE #POR (term varchar(100), process_flag int)  
INSERT #POR
	SELECT row, 0
	from dbo.fn_SplitXsvText(',', 1, @po_release) 
	WHERE ISNULL(row, '') <> ''  

IF (SELECT COUNT(*) FROM #por) > 0
BEGIN
	SET @detail_where = @detail_where + ' 
	AND ( 1=0 
	'
	WHILE ((SELECT COUNT(*) FROM #por WHERE process_flag = 0) > 0)
	BEGIN
		SELECT TOP 1 @this_desc = term FROM #por WHERE process_flag = 0
		SET @detail_where = @detail_where + '    OR ISNULL(b.purchase_order, '''') + '' '' + ISNULL(b.release_code, '''') LIKE ''%' + replace(@this_desc, ' ', '%') + '%''
		'
		UPDATE #por SET process_flag = 1 WHERE term = @this_desc
	END
	SET @detail_where = @detail_where + ' ) 
	'
	UPDATE #por SET process_flag = 0
END
	
	
-- Create a temp table to hold the database list to query  
CREATE TABLE #tmp_database (  
	database_name varchar(60),  
	company_id  int,  
	profit_ctr_id int,  
	process_flag int )  

-- access filter table is used to pre-filter all of the data so that the major selection
-- not as expensive
CREATE TABLE #access_filter
(
	customer_id int,
	billing_uid int,
	company_id int,
	profit_ctr_id int,
	trans_source varchar(10),
	receipt_id int,
	line_id int,
	price_id int,
	billing_project_id int,
	generator_id int
)

-- If there's still a populated @session key, skip the query - just get the results.
IF DATALENGTH(@session_key) > 0 goto returnresults 

IF @debug > 3 SELECT DATEDIFF(ms, @starttime, GETDATE()) AS timer, 'Before Var setup' AS description

SET @session_key = NEWID()
  
-- abort if there's nothing possible to see  
 IF LEN(@database_list) +   
  LEN(@customer_id_list) +    
  LEN(@generator_id_list) +    
  LEN(@approval_code) +  
  LEN(@start_date)  +
  LEN(@end_date)  +
  LEN(@invoice_code_list)  +
  LEN(@manifest)
  = 0 RETURN  
    
-- Load #tmp_database from the sp input    
EXEC sp_reports_list_database @debug, @database_list  
--IF @debug > 0 SELECT * FROM #tmp_database  
  
-- Set defaults for empty data lists  
IF @generator_id_list IS NULL OR LEN(@generator_id_list) = 0  
SET @generator_id_list = '-1'  
  
IF @invoice_code_list IS NULL OR LEN(@invoice_code_list) = 0  
SET @invoice_code_list = '-1'  

--SET @access_filter_sql = 'INSERT INTO #access_filter
--	(
--		customer_id,
--		billing_uid,
--		company_id ,
--		profit_ctr_id ,
--		trans_source ,
--		receipt_id ,
--		line_id ,
--		price_id ,
--		billing_project_id,
--		generator_id 
--	)
--	SELECT DISTINCT
--		b.customer_id,
--		b.billing_uid,
--		b.company_id,
--		b.profit_ctr_id,
--		b.trans_source,
--		b.receipt_id,
--		b.line_id,
--		b.price_id, 
--		b.billing_project_id,
--		b.generator_id
--	FROM Billing b 
--	INNER JOIN #tmp_database td on b.company_id = td.company_id 
--	LEFT OUTER JOIN TSDFApproval ta on b.tsdf_approval_id = ta.tsdf_approval_id 
--	/*ApprovalJOIN*/
--	WHERE 1=1 '
	
SET @access_filter_sql = 'INSERT INTO #access_filter
	( billing_uid )
	SELECT DISTINCT
		b.billing_uid
	FROM Billing b 
	INNER JOIN #tmp_database td ON b.company_id = td.company_id 
	LEFT OUTER JOIN TSDFApproval ta ON b.tsdf_approval_id = ta.tsdf_approval_id 
	/*ApprovalJOIN*/
	WHERE 1=1 '

-- Most specific criteria first:  
IF (SELECT COUNT(*) FROM #invoice_code_list) > 0  
	SET @access_filter_sql = @access_filter_sql + '
	AND b.invoice_code IN (SELECT invoice_code FROM #invoice_code_list) '  
  
IF (SELECT COUNT(*) FROM #manifest) > 0  
	SET @access_filter_sql = @access_filter_sql + '
	AND b.manifest IN  (SELECT manifest FROM #manifest) '  
    
IF (SELECT COUNT(*) FROM #approval) > 0  
	SET @access_filter_sql = REPLACE(@access_filter_sql, '/*ApprovalJOIN*/', 'INNER JOIN #Approval ON COALESCE(NULLIF(b.approval_code,''''), ta.tsdf_approval_code, '''') LIKE ''%'' + #Approval.approval_code + ''%'' /*ApprovalJOIN*/ ')
  
IF @start_date <> ''   
	SET @access_filter_sql = @access_filter_sql + '
	AND b.invoice_date >= ''' + @start_date + ''' '  
   
IF @end_date <> ''  
	SET @access_filter_sql = @access_filter_sql + '
	AND b.invoice_date <= ''' + @end_date + ''' '  
   
IF (SELECT COUNT(*) FROM #Customer_id_list) > 0  
	SET @access_filter_sql = @access_filter_sql + '
	AND b.customer_id IN (SELECT customer_id FROM #Customer_id_list) '  
  
IF (SELECT COUNT(*) FROM #generator_id_list) > 0  
	SET @access_filter_sql = @access_filter_sql + '
	AND b.generator_id IN (SELECT generator_id FROM #generator_id_list) '  
  
IF @contact_id > -1  
	SET @access_filter_sql = @access_filter_sql + '
	AND b.customer_id IN (  
	   SELECT DISTINCT customer_id   
	   FROM ContactXRef   
	   WHERE type = ''C'' AND web_access = ''A''   
	   AND status = ''A'' AND contact_id = ' + convert(varchar(20), @contact_id) + ') '  
  
 -- If Associate running this, and NOT "all customers", also find records for direct-generators of the customers chosen.  
IF @contact_id = -1  AND (SELECT COUNT(*) FROM #Customer_id_list) > 0  
	SET @access_filter_sql = @access_filter_sql + '  
    AND (1=1 OR EXISTS (  
		SELECT cg.generator_id 
		FROM CustomerGenerator cg, Customer c  
		WHERE cg.generator_id = b.generator_id  
		AND cg.customer_id IN (SELECT customer_id FROM #customer_id_list)   
		AND cg.customer_id = c.customer_id  
		AND c.generator_flag = ''T''  
    ) ) '  

-- add @detail_where to @access_filter_sql
SET @access_filter_sql = @access_filter_sql + @detail_where

-- Least specific criteria last-est:    
SET @access_filter_sql = @access_filter_sql + '
	AND b.status_code = ''I'' ' 

IF (@debug > 0) PRINT @access_filter_sql

EXEC(@access_filter_sql)

-- #access_filter is created & populated now.
-- At this point we're only exporting summary data, or else we'd have
-- been given a valid session_id and not be in this branch of logic...
-- So populate the List table:

SELECT @detail_query = '
	INSERT Work_BillingSummaryListResult
	SELECT DISTINCT  
		 b.company_id,  
		 b.profit_ctr_id,  
		 p.profit_ctr_name, 
		 b.invoice_code,  
		 b.invoice_date,  
		 b.customer_id,   
		 c.cust_name,
		 '''  + @session_key + ''',
		 GETDATE()
	',
	@detail_join = '
	INNER JOIN #tmp_database td on b.company_id = td.company_id  
	INNER JOIN #access_filter af ON af.billing_uid = b.billing_uid 
	'	

SET @results_sql = REPLACE(REPLACE(REPLACE(@detail_sql, '/* QUERY */', @detail_query), '/* JOIN */', @detail_join), '/* WHERE */', @detail_where)
IF (@debug > 0) PRINT @results_sql
EXEC (@results_sql)

-- Now we can return the results...
-- Or if this was a 'D'etail query, execute the sql
-- that returns detailed info for records already in the list table.

-------------------------------------------
------------- RETURN RESULTS --------------
-------------------------------------------
returnresults:

IF @detail_level = 'S' 
BEGIN

	-- get paging records
	SELECT  @start_of_results = MIN(row_num)-1, 
			@end_of_results = MAX(row_num),
			@count_invoice = COUNT(DISTINCT invoice_code) 
	FROM Work_BillingSummaryListResult
	WHERE session_key = @session_key 

	-- get summary records
	SELECT DISTINCT -1 AS row_num, 
		-1 AS company_id,  
		-1 AS profit_ctr_id,  
		'' AS profit_ctr_name, 
		invoice_code,  
		invoice_date,  
		customer_id,   
		cust_name,
		session_key,
		session_added,
		--@end_of_results - @start_of_results AS record_count
		@count_invoice AS record_count
	FROM Work_BillingSummaryListResult
	WHERE row_num >= @start_of_results + @row_from
	AND row_num <= 
	CASE 
		WHEN @row_to = -1 
		THEN @end_of_results 
		ELSE @start_of_results + @row_to 
	END
	AND session_key = @session_key
	ORDER BY 
		cust_name,
		customer_id, 
		invoice_date, 
		invoice_code, 
		company_id, 
		profit_ctr_id
END




IF @detail_level = 'D'
BEGIN

	-- No paging details here - it always returns the full set to excel.
	
	----------------------------------------------------------------------------------
	-- First, select all of the regular disposal, service and work order charges,
	-- without MI surcharges, insurance, energy and sales tax.
	----------------------------------------------------------------------------------
	SELECT @detail_query = '
	SELECT 
	c.cust_name
	, b.customer_id
	, b.invoice_code
	, b.invoice_date
	, p.profit_ctr_name
	, cb.billing_project_id
	, cb.project_name AS billing_project_name
	, b.generator_name
	, b.generator_id
	, g.epa_id
	, g.site_type
	, isnull(g.generator_address_1, '''') + isnull('' '' + g.generator_address_2, '''') + isnull('' '' + g.generator_address_3, '''') + isnull('' '' + g.generator_address_4, '''') + isnull('' '' + g.generator_address_5, '''') as generator_address
	, g.generator_city
	, g.generator_state
	, g.generator_zip_code
	, g.generator_division
	, g.generator_region_code
	, CASE
		WHEN bc.service_date is null THEN
			dbo.fn_get_service_date(b.company_id, b.profit_ctr_id, b.receipt_id, b.trans_source)
		ELSE bc.service_date
		END as service_date
	, CASE 
		WHEN b.trans_type = ''S'' THEN ''Service''
		WHEN b.trans_type = ''W'' THEN ''Wash''
		WHEN b.trans_type = ''O'' THEN ''Work Order''
		WHEN b.trans_type = ''R'' THEN ''Retail''
		WHEN b.trans_type = ''D'' THEN ''Disposal''				
		ELSE b.trans_type
		END	AS trans_type
	, CASE 
		WHEN b.trans_source = ''R'' THEN ''Receipt''
		WHEN b.trans_source = ''O'' THEN ''Retail''
		WHEN b.trans_source = ''W'' THEN ''Work Order''
		ELSE b.trans_source
		END	AS trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.line_id
	, b.price_id
	, COALESCE(NULLIF(b.approval_code,''''), ta.tsdf_approval_code, '''') AS approval_code
	, b.manifest
	, b.purchase_order
	, b.release_code
	, ISNULL(b.service_desc_1, b.service_desc_2) AS description
	, b.quantity
	, b.bill_unit_code
	, bu.bill_unit_desc AS bill_unit_description
	, b.price
	, extended_amt = (SELECT SUM(bd.extended_amt) 
		FROM BillingDetail bd
		WHERE bd.billing_uid = b.billing_uid
		AND bd.billing_type NOT IN (''Insurance'', ''Energy'', ''SalesTax'', ''State-Haz'', ''State-Perp'')
		)
	, wl.session_key
	, wl.session_added
	--, dbo.fn_get_pickup_date(b.receipt_id, b.company_id, b.profit_ctr_id, b.invoice_code, b.line_id, b.trans_source) AS pickup_date
	--, g.site_code
	--, b.status_code
	--, b.billing_date
	, 1 AS record_type
	, 1 AS surcharge_tax_type
	',
	@detail_join = '
	INNER JOIN Work_BillingSummaryListResult wl ON wl.company_id = b.company_id
		AND wl.profit_ctr_id = b.profit_ctr_id
		AND wl.invoice_code = b.invoice_code
		AND wl.invoice_date = b.invoice_date
		AND wl.customer_id = b.customer_id
		AND wl.session_key = ''' + @session_key + '''
	'
	
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'
	IF (@debug > 0) PRINT '@detail_sql:  ' + @detail_sql
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'
	IF (@debug > 0) PRINT '@detail_query:  ' + @detail_query
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'
	IF (@debug > 0) PRINT '@detail_join:  ' + @detail_join
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'

	SET @regular_sql = REPLACE(REPLACE(REPLACE(@detail_sql, '/* QUERY */', @detail_query), '/* JOIN */', @detail_join), '/* WHERE */', @detail_where)
	
	IF (@debug > 0) PRINT '@regular_sql:  ' + @regular_sql
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'
	

	
	
	----------------------------------------------------------------------------------
	-- Second, include the MI surcharges on their own lines.
	----------------------------------------------------------------------------------
	SELECT @detail_query = 'UNION
	
	SELECT 
	c.cust_name
	, b.customer_id
	, b.invoice_code
	, b.invoice_date
	, p.profit_ctr_name
	, cb.billing_project_id
	, cb.project_name AS billing_project_name
	, b.generator_name
	, b.generator_id
	, g.epa_id
	, g.site_type
	, isnull(g.generator_address_1, '''') + isnull('' '' + g.generator_address_2, '''') + isnull('' '' + g.generator_address_3, '''') + isnull('' '' + g.generator_address_4, '''') + isnull('' '' + g.generator_address_5, '''') as generator_address
	, g.generator_city
	, g.generator_state
	, g.generator_zip_code
	, g.generator_division
	, g.generator_region_code
	, CASE
		WHEN bc.service_date is null THEN
			dbo.fn_get_service_date(b.company_id, b.profit_ctr_id, b.receipt_id, b.trans_source)
		ELSE bc.service_date
		END as service_date
	, CASE 
		WHEN b.trans_type = ''S'' THEN ''Service''
		WHEN b.trans_type = ''W'' THEN ''Wash''
		WHEN b.trans_type = ''O'' THEN ''Work Order''
		WHEN b.trans_type = ''R'' THEN ''Retail''
		WHEN b.trans_type = ''D'' THEN ''Disposal''				
		ELSE b.trans_type
		END	AS trans_type
	, CASE 
		WHEN b.trans_source = ''R'' THEN ''Receipt''
		WHEN b.trans_source = ''O'' THEN ''Retail''
		WHEN b.trans_source = ''W'' THEN ''Work Order''
		ELSE b.trans_source
		END	AS trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.line_id
	, b.price_id
	, COALESCE(NULLIF(b.approval_code,''''), ta.tsdf_approval_code, '''') AS approval_code
	, b.manifest
	, b.purchase_order
	, b.release_code
	, COALESCE(s.surcharge_desc, b.service_desc_1, b.service_desc_2) AS description
	, b.quantity
	, b.bill_unit_code
	, bu.bill_unit_desc AS bill_unit_description
	, b.sr_price AS price
	, extended_amt = SUM(bd.extended_amt) 
	, wl.session_key
	, wl.session_added
	--, dbo.fn_get_pickup_date(b.receipt_id, b.company_id, b.profit_ctr_id, b.invoice_code, b.line_id, b.trans_source) AS pickup_date
	--, g.site_code
	--, b.status_code
	--, b.billing_date
	, 2 AS record_type
	, 1 AS surcharge_tax_type
	',
	@detail_join = '
	INNER JOIN Work_BillingSummaryListResult wl ON wl.company_id = b.company_id
		AND wl.profit_ctr_id = b.profit_ctr_id
		AND wl.invoice_code = b.invoice_code
		AND wl.invoice_date = b.invoice_date
		AND wl.customer_id = b.customer_id
		AND wl.session_key = ''' + @session_key + '''
	INNER JOIN BillingDetail bd ON b.billing_uid = bd.billing_uid 
		AND bd.billing_type IN (''State-Haz'', ''State-Perp'')
	INNER JOIN Surcharge s ON s.company_id = b.company_id
		AND s.profit_ctr_id = b.profit_ctr_id
		AND s.sr_type_code = b.sr_type_code
		AND s.bill_unit_code = b.bill_unit_code
		AND s.curr_status_code = ''A''
	',
	@detail_group = '
	GROUP BY 
	b.company_id
	, b.profit_ctr_id
	, p.profit_ctr_name
	, b.trans_source
	, b.receipt_id
	, b.line_id
	, b.price_id
	, b.invoice_code
	, b.invoice_date
	, b.customer_id
	, c.cust_name
	, b.bill_unit_code
	, b.generator_id
	, b.generator_name
	, g.epa_id
	, g.site_type
	, isnull(g.generator_address_1, '''') + isnull('' '' + g.generator_address_2, '''') + isnull('' '' + g.generator_address_3, '''') + isnull('' '' + g.generator_address_4, '''') + isnull('' '' + g.generator_address_5, '''')
	, g.generator_city
	, g.generator_state
	, g.generator_zip_code
	, g.generator_division
	, g.generator_region_code
	, bc.service_date
	, COALESCE(NULLIF(b.approval_code,''''), ta.tsdf_approval_code, '''')
	, b.quantity
	, b.sr_price
	, b.manifest
	, b.purchase_order
	, b.release_code
	, b.trans_type
	, COALESCE(s.surcharge_desc, b.service_desc_1, b.service_desc_2)
	, cb.billing_project_id
	, s.surcharge_desc
	, bu.bill_unit_desc 
	, cb.project_name
	, wl.session_key
	, wl.session_added
	--, g.site_code
	--, b.status_code
	--, b.billing_date
	'
	
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'
	IF (@debug > 0) PRINT '@detail_sql:  ' + @detail_sql
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'
	IF (@debug > 0) PRINT '@detail_query:  ' + @detail_query
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'
	IF (@debug > 0) PRINT '@detail_join:  ' + @detail_join
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'

	SET @mi_sr_sql = REPLACE(REPLACE(REPLACE(@detail_sql, '/* QUERY */', @detail_query), '/* JOIN */', @detail_join), '/* WHERE */', @detail_where) + @detail_group
	
	IF (@debug > 0) PRINT '@mi_sr_sql:  ' + @mi_sr_sql
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'
	
	----------------------------------------------------------------------------------
	-- Third, include insurance/energy surcharges and salest taxes on their own lines.
	----------------------------------------------------------------------------------
	SELECT @detail_query = 'UNION
	
	SELECT 
	c.cust_name
	, b.customer_id
	, b.invoice_code
	, b.invoice_date
	, NULL AS profit_ctr_name
	, NULL AS billing_project_id
	, NULL AS billing_project_name
	, NULL AS generator_name
	, NULL AS generator_id
	, NULL AS epa_id
	, NULL as site_type
	, NULL as generator_address
	, NULL generator_city
	, NULL generator_state
	, NULL generator_zip_code
	, NULL generator_division
	, NULL generator_region_code
	, NULL service_date
	, CASE bd.billing_type
		WHEN ''Insurance'' THEN ''Surcharge''
		WHEN ''Energy'' THEN ''Surcharge''
		WHEN ''SalesTax'' THEN ''Sales Tax''
		ELSE NULL
		END	AS trans_type
	, NULL AS trans_source
	, NULL AS company_id
	, NULL AS profit_ctr_id
	, NULL AS receipt_id
	, NULL AS line_id
	, NULL AS price_id
	, NULL AS approval_code
	, NULL AS manifest
	, NULL AS purchase_order
	, NULL AS release_code
	, CASE bd.billing_type
		WHEN ''Insurance'' THEN ''Insurance Surcharge''
		WHEN ''Energy'' THEN ''Energy Surcharge''
		WHEN ''SalesTax'' THEN st.tax_description
		ELSE NULL
		END	AS description
	, 1 AS quantity
	, bu.bill_unit_code
	, bu.bill_unit_desc AS bill_unit_description
	, price = SUM(bd.extended_amt) 
	, extended_amt = SUM(bd.extended_amt) 
	, wl.session_key
	, wl.session_added
	--, NULL AS pickup_date
	--, NULL AS site_code
	--, NULL AS status_code
	--, NULL AS billing_date
	, 3 AS record_type
	, CASE bd.billing_type
		WHEN ''Insurance'' THEN 10
		WHEN ''Energy'' THEN 20
		WHEN ''SalesTax'' THEN 30
		ELSE 100
		END	AS surcharge_tax_type
	',
	-- This time the @detail_sql needs to be updated because we can't have all those joins for the summarized surcharges/sales taxes
	@detail_sql = '
	/* QUERY */
	FROM Billing b  
	LEFT JOIN BillingComment bc ON b.trans_source = bc.trans_source
		AND b.receipt_id = bc.receipt_id
		AND b.company_id = bc.company_id
		and b.profit_ctr_id = bc.profit_ctr_id
	INNER JOIN InvoiceHeader ih ON ih.invoice_id = b.invoice_id
		AND ih.status = ''I'' 
	INNER JOIN Customer c ON b.customer_id = c.customer_id  
	INNER JOIN BillUnit bu ON bu.bill_unit_code = ''EACH''
	/* JOIN */
	WHERE 1=1 /* WHERE */
	',
	@detail_join = '
	INNER JOIN Work_BillingSummaryListResult wl ON wl.company_id = b.company_id
		AND wl.profit_ctr_id = b.profit_ctr_id
		AND wl.invoice_code = b.invoice_code
		AND wl.invoice_date = b.invoice_date
		AND wl.customer_id = b.customer_id
		AND wl.session_key = ''' + @session_key + '''
	INNER JOIN BillingDetail bd ON b.billing_uid = bd.billing_uid 
		AND bd.billing_type IN (''Insurance'', ''Energy'', ''SalesTax'')
	LEFT OUTER JOIN SalesTax st ON st.sales_tax_id = bd.sales_tax_id
	',
	@detail_group = '
	GROUP BY 
	b.invoice_code
	, b.invoice_date
	, b.customer_id
	, c.cust_name
	, bu.bill_unit_code
	, bd.billing_type
	, st.tax_description
	, bu.bill_unit_desc 
	, wl.session_key
	, wl.session_added
	',
	-- Add the order by clause here
	@detail_order = '
	ORDER BY 
	c.cust_name
	, b.customer_id
	, b.invoice_date
	, b.invoice_code
	, surcharge_tax_type
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.line_id
	, b.price_id
	, record_type
	, description
	'
	
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'
	IF (@debug > 0) PRINT '@detail_sql:  ' + @detail_sql
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'
	IF (@debug > 0) PRINT '@detail_query:  ' + @detail_query
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'
	IF (@debug > 0) PRINT '@detail_join:  ' + @detail_join
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'
	--IF (@debug > 0) PRINT '@detail_order:  ' + @detail_order
	--IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'

	SET @surcharge_sql = REPLACE(REPLACE(REPLACE(@detail_sql, '/* QUERY */', @detail_query), '/* JOIN */', @detail_join), '/* WHERE */', @detail_where) + @detail_group
	
	IF (@debug > 0) PRINT '@surcharge_sql:  ' + @surcharge_sql
	IF (@debug > 0) PRINT '----------------------------------------------------------------------------------------------------------------------------------------------------'

	
	
	
	----------------------------------------------------------------------------------
	-- Final SQL select is the UNION of all three queries
	----------------------------------------------------------------------------------
	SET @results_sql = @regular_sql + @mi_sr_sql + @surcharge_sql + @detail_order
	IF (@debug > 0) PRINT 'Final SELECT (Detail)'
	IF (@debug > 0) SELECT @results_sql
	EXEC (@results_sql)
	

END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_billing_summary_master] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_billing_summary_master] TO [COR_USER]
    AS [dbo];


