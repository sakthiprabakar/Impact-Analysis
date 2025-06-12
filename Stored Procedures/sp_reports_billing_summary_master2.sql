
CREATE PROCEDURE sp_reports_billing_summary_master2
 @debug    int,    -- 0 or 1 for no debug/debug mode  
 @database_list  varchar(max), -- Comma Separated Company List  
 @customer_id_list varchar(max), -- Comma Separated Customer ID List - what customers to include  
 @generator_id_list varchar(max), -- Comma Separated Generator ID List - what generators to include  
 @approval_code  varchar(max), -- Approval Code  
 @invoice_code_list varchar(max), -- Invoice Code  
 @manifest   varchar(max), -- Manfiest Code  
 @start_date   varchar(20),  -- Start Date  
 @end_date   varchar(20),  -- Start Date  
 @description varchar(100), -- Description search field
 @po_release varchar(100), -- PO, Release search field
 @detail_level  char(1),   -- Summary or Detail?  
 @contact_id   int = 0,   -- Contact ID or -1 for Associates.  
 @session_key		varchar(100) = '',	-- unique identifier key to a previously run query's results
 @row_from			int = 1,			-- when accessing a previously run query's results, what row should the return set start at?
 @row_to				int = 20			-- when accessing a previously run query's results, what row should the return set end at (-1 = all)?
  
/* *******************  
sp_reports_billing_summary_master2:  
  
Returns the data for Billing Summary.  
This SP can return prices - so it's not for generator access.  Contacts must be limited to their own accounts.  
  
  
LOAD TO PLT_AI * on NTSQL1  

Testing/examples:

-- Summary:
	declare @debug int, @database_list varchar(8000), @customer_id_list varchar(8000), @generator_id_list varchar(8000), @approval_code varchar(8000), @invoice_code_list varchar(8000), @manifest varchar(8000), @start_date varchar(20), @end_date varchar(20), @description varchar(100), @po_release varchar(100), @detail_level char(1), @contact_id int, @session_key varchar(100), @row_from int, @row_to int
	select @debug = 0, @database_list = '2|21, 3|1, 12|0, 14|0, 15|1, 21|0, 22|0, 23|0, 24|0', @customer_id_list = '', @generator_id_list = '', @approval_code = '', @invoice_code_list = '', @manifest = '', @start_date = '', @end_date = '', @description = '', @po_release = '',  @detail_level = 'D', @contact_id = -1, @session_key = '', @row_from = 1, @row_to = 20
	select @debug = 0,
		@customer_id_list 	= '12068',
		@start_date   		= '1/1/2009', 
		@end_date   		= '1/15/2009'

	exec sp_reports_billing_summary_master2 @debug, @database_list, @customer_id_list, @generator_id_list, @approval_code, @invoice_code_list, @manifest, @start_date, @end_date, @description, @po_release, @detail_level, @contact_id, @session_key, @row_from, @row_to
select top 30 approval_code, profile_id, tsdf_approval_id, * from billing where status_code = 'I' and approval_code = '' order by billing_date desc

select approval_code, profile_id, tsdf_approval_id, * from billing where receipt_id = 1474905
select * from workorderdetail where workorder_id = 1474905 and sequence_id = 1

-- Detail: (change session_key to value returned in summary)
	declare @debug int, @database_list varchar(8000), @customer_id_list varchar(8000), @generator_id_list varchar(8000), @approval_code varchar(8000), @invoice_code_list varchar(8000), @manifest varchar(8000), @start_date varchar(20), @end_date varchar(20), @description varchar(100), @po_release varchar(100), @detail_level char(1), @contact_id int, @session_key varchar(100), @row_from int, @row_to int
	select @debug = 0, @database_list = '2|21, 3|1, 12|0, 14|0, 15|1, 21|0, 22|0, 23|0, 24|0', @customer_id_list = '', @generator_id_list = '', @approval_code = '', @invoice_code_list = '', @manifest = '', @start_date = '', @end_date = '', @description = '', @po_release = '',  @detail_level = 'S', @contact_id = -1, @session_key = '', @row_from = 1, @row_to = 20
	select
		 @debug    			= 1,
		 @customer_id_list 	= '12068',
		 @start_date   		= '1/1/2009', 
		 @end_date   		= '1/15/2009',
		 @detail_level 		= 'D',
		 @session_key 		= 'F7F2E93C-A873-4432-9132-76E0F8A3A0FF'

	exec sp_reports_billing_summary_master2 @debug, @database_list, @customer_id_list, @generator_id_list, @approval_code, @invoice_code_list, @manifest, @start_date, @end_date, @description, @po_release, @detail_level, @contact_id, @session_key, @row_from, @row_to

	
-- Summary:
	declare @debug int, @database_list varchar(8000), @customer_id_list varchar(8000), @generator_id_list varchar(8000), @approval_code varchar(8000), @invoice_code_list varchar(8000), @manifest varchar(8000), @start_date varchar(20), @end_date varchar(20), @description varchar(100), @po_release varchar(100), @detail_level char(1), @contact_id int, @session_key varchar(100), @row_from int, @row_to int
	select @debug = 0, @database_list = '2|21, 3|1, 12|0, 14|0, 15|1, 21|0, 22|0, 23|0, 24|0', @customer_id_list = '', @generator_id_list = '', @approval_code = '', @invoice_code_list = '', @manifest = '', @start_date = '', @end_date = '', @description = '', @po_release = '',  @detail_level = 'S', @contact_id = -1, @session_key = '', @row_from = 1, @row_to = 20
	select 
		@customer_id_list 	= '12068',
		@start_date   		= '1/1/2009', 
		@end_date   		= '1/15/2009',
		@description		= 'wet batteries, pail'

	exec sp_reports_billing_summary_master2 @debug, @database_list, @customer_id_list, @generator_id_list, @approval_code, @invoice_code_list, @manifest, @start_date, @end_date, @description, @po_release, @detail_level, @contact_id, @session_key, @row_from, @row_to

-- Detail: (change session_key to value returned in summary)
	declare @debug int, @database_list varchar(8000), @customer_id_list varchar(8000), @generator_id_list varchar(8000), @approval_code varchar(8000), @invoice_code_list varchar(8000), @manifest varchar(8000), @start_date varchar(20), @end_date varchar(20), @description varchar(100), @po_release varchar(100), @detail_level char(1), @contact_id int, @session_key varchar(100), @row_from int, @row_to int
	select @debug = 0, @database_list = '2|21, 3|1, 12|0, 14|0, 15|1, 21|0, 22|0, 23|0, 24|0', @customer_id_list = '', @generator_id_list = '', @approval_code = '', @invoice_code_list = '', @manifest = '', @start_date = '', @end_date = '', @description = '', @po_release = '',  @detail_level = 'S', @contact_id = -1, @session_key = '', @row_from = 1, @row_to = 20
	select
		 @customer_id_list 	= '12068',
		 @start_date   		= '1/1/2009', 
		 @end_date   		= '1/15/2009',
		 @description		= 'wet batteries, pail',
		 @po_release		= 'NP4116200',
		 @detail_level 		= 'D',
		 @session_key 		= '0FDC0888-6A6A-446E-9D45-ED792852C2ED'

	exec sp_reports_billing_summary_master2 @debug, @database_list, @customer_id_list, @generator_id_list, @approval_code, @invoice_code_list, @manifest, @start_date, @end_date, @description, @po_release, @detail_level, @contact_id, @session_key, @row_from, @row_to
	
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
07/26/2012	JPB
	- Fixed join between billing & invoicedetail that did not include invoice_id. This would produce duplicate rows when a receipt appeared in multiple invoice revisions

********************* */  
  
AS  
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
  
DECLARE @access_filter_sql varchar(8000) ,
	@starttime datetime ,
	@start_of_results int ,
	@end_of_results int ,
	@detail_sql varchar(8000) ,
	@detail_query varchar(8000) ,
	@detail_join varchar(8000),
	@this_desc varchar(100),
	@detail_where varchar(8000),
	@detail_order varchar(8000)

SET @starttime = getdate()

SELECT @detail_sql = '
	 /* QUERY */
	 FROM billing b  
	  INNER JOIN invoicedetail i ON b.company_id = i.company_id 
		AND b.profit_ctr_id = i.profit_ctr_id 
		AND b.trans_source = i.trans_source 
		AND b.receipt_id = i.receipt_id 
		AND b.line_id = i.line_id 
		AND b.price_id = i.price_id 
		AND b.billing_project_id = i.billing_project_id   
		AND b.invoice_id = i.invoice_id
	  INNER JOIN invoiceheader ih on i.invoice_id = ih.invoice_id and i.revision_id = ih.revision_id and ih.status = ''I'' and i.invoice_id = b.invoice_id
	  INNER JOIN customer c on b.customer_id = c.customer_id  
	  LEFT OUTER JOIN generator g on b.generator_id = g.generator_id  
	  INNER JOIN profitcenter p ON b.company_id = p.company_id AND b.profit_ctr_id = p.profit_ctr_id
	  INNER JOIN BillUnit bu ON i.bill_unit_code = bu.bill_unit_code
	  INNER JOIN CustomerBilling cb ON b.customer_id = cb.customer_id 
		AND b.billing_project_id = cb.billing_project_id
	  LEFT OUTER JOIN TSDFApproval ta on b.tsdf_approval_id = ta.tsdf_approval_id 
	  /* JOIN */
	  WHERE 1=1 /* WHERE */
	  ',
	@detail_where = '',
	@detail_order = '
	ORDER BY 
		c.cust_name,
		b.customer_id, 
		b.invoice_date,
		b.invoice_code,
		b.company_id, 
		b.profit_ctr_id 
	'

-- Housekeeping.  Gets rid of old paging records.
DECLARE @eightHoursAgo as DateTime
SET @eightHoursAgo = DateAdd(hh, -8, getdate())
DELETE FROM Work_BillingSummaryDetailResult WHERE session_added < @eightHoursAgo
DELETE FROM Work_BillingSummaryListResult WHERE session_added < @eightHoursAgo


if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Housekeeping' as description

-- Check to see if there's a @session_key provided with this query, and if that key is valid.
if datalength(@session_key) > 0 
begin
	if not exists(select distinct session_key from Work_BillingSummaryListResult where session_key = @session_key)
		-- AND (not exists(select distinct session_key from Work_BillingSummaryDetailResult where session_key = @session_key))
	begin
		set @session_key = ''
		set @row_from = 1
		set @row_to = 20
	end
end

  
-- Create temp tables for data storage/validation  
CREATE TABLE #customer_id_list (customer_id int)  
CREATE INDEX idx1 ON #customer_id_list (customer_id)  
INSERT #Customer_id_list 
	select convert(int, row) 
	from dbo.fn_SplitXsvText(',', 0, @customer_id_list) 
	where isnull(row, '') <> ''  
  
CREATE TABLE #generator_id_list (generator_id int)  
CREATE INDEX idx2 ON #generator_id_list (generator_id)  
INSERT #generator_id_list 
	select convert(int, row) 
	from dbo.fn_SplitXsvText(',', 0, @generator_id_list) 
	where isnull(row, '') <> ''  
    
CREATE TABLE #invoice_code_list (invoice_code varchar(16))  
CREATE INDEX idx3 ON #invoice_code_list (invoice_code)  
INSERT #invoice_code_list 
	select row 
	from dbo.fn_SplitXsvText(',', 1, @invoice_code_list) 
	where isnull(row, '') <> ''  
  
CREATE TABLE #Approval (approval_code varchar(15))  
CREATE INDEX idx4 ON #Approval (approval_code)  
INSERT #Approval 
	select row 
	from dbo.fn_SplitXsvText(',', 1, @approval_code) 
	where isnull(row, '') <> ''  
   
CREATE TABLE #Manifest (manifest varchar(15))  
CREATE INDEX idx5 ON #Manifest (manifest)  
INSERT #Manifest 
	select row 
	from dbo.fn_SplitXsvText(',', 1, @manifest) 
	where isnull(row, '') <> ''  
  
CREATE TABLE #Description (term varchar(100), process_flag int)  
INSERT #Description
	select row, 0
	from dbo.fn_SplitXsvText(',', 1, @description) 
	where isnull(row, '') <> ''  

IF (select count(*) from #description) > 0  BEGIN
	SET @detail_where = @detail_where + ' 
	AND ( 1=0 
	'
	WHILE ((select count(*) from #description where process_flag = 0) > 0) BEGIN
		select top 1 @this_desc = term from #description where process_flag = 0
		SET @detail_where = @detail_where + '    OR isnull(b.service_desc_1, '''') + '' '' + isnull(b.service_desc_2, '''') like ''%' + replace(@this_desc, ' ', '%') + '%''
		'
		update #description set process_flag = 1 where term = @this_desc
	END
	SET @detail_where = @detail_where + ' ) 
	'
	UPDATE #description set process_flag = 0
END
	
CREATE TABLE #POR (term varchar(100), process_flag int)  
INSERT #POR
	select row, 0
	from dbo.fn_SplitXsvText(',', 1, @po_release) 
	where isnull(row, '') <> ''  

IF (select count(*) from #por) > 0  BEGIN
	SET @detail_where = @detail_where + ' 
	AND ( 1=0 
	'
	WHILE ((select count(*) from #por where process_flag = 0) > 0) BEGIN
		select top 1 @this_desc = term from #por where process_flag = 0
		SET @detail_where = @detail_where + '    OR isnull(b.purchase_order, '''') + '' '' + isnull(b.release_code, '''') like ''%' + replace(@this_desc, ' ', '%') + '%''
		'
		update #por set process_flag = 1 where term = @this_desc
	END
	SET @detail_where = @detail_where + ' ) 
	'
	UPDATE #por set process_flag = 0
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
IF datalength(@session_key) > 0 goto returnresults 

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Before Var setup' as description

set @session_key = newid()
  
-- abort if there's nothing possible to see  
 if LEN(@database_list) +   
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
if @debug > 0 select * from #tmp_database  
  
-- Set defaults for empty data lists  
IF @generator_id_list IS NULL OR LEN(@generator_id_list) = 0  
SET @generator_id_list = '-1'  
  
IF @invoice_code_list IS NULL OR LEN(@invoice_code_list) = 0  
SET @invoice_code_list = '-1'  

SET @access_filter_sql = 'INSERT INTO #access_filter
	(
		customer_id,
		company_id ,
		profit_ctr_id ,
		trans_source ,
		receipt_id ,
		line_id ,
		price_id ,
		billing_project_id,
		generator_id 
	)
	SELECT DISTINCT
		b.customer_id,
		b.company_id,
		b.profit_ctr_id,
		b.trans_source,
		b.receipt_id,
		b.line_id,
		b.price_id, 
		b.billing_project_id,
		b.generator_id
	FROM billing b 
	INNER JOIN #tmp_database td on b.company_id = td.company_id 
	left outer join tsdfapproval ta on b.tsdf_approval_id = ta.tsdf_approval_id 
	/*ApprovalJOIN*/
	WHERE 1=1 '

-- Most specific criteria first:  
IF (select count(*) from #invoice_code_list) > 0  
	SET @access_filter_sql = @access_filter_sql + ' AND b.invoice_code like (select ''%'' + invoice_code + ''%'' from #invoice_code_list) '  
  
IF (select count(*) from #manifest) > 0  
	SET @access_filter_sql = @access_filter_sql + ' AND b.manifest like (select ''%'' + manifest + ''%'' from #manifest) '  
    
IF (select count(*) from #approval) > 0  
	SET @access_filter_sql = replace(@access_filter_sql, '/*ApprovalJOIN*/', 'INNER JOIN #Approval on coalesce(nullif(b.approval_code,''''), ta.tsdf_approval_code, '''') like ''%'' + #Approval.approval_code + ''%'' /*ApprovalJOIN*/ ')
  
IF @start_date <> ''   
	SET @access_filter_sql = @access_filter_sql + ' AND b.invoice_date >= ''' + @start_date + ''' '  
   
IF @end_date <> ''  
	SET @access_filter_sql = @access_filter_sql + ' AND b.invoice_date <= ''' + @end_date + ''' '  
   
IF (select count(*) from #Customer_id_list) > 0  
	SET @access_filter_sql = @access_filter_sql + ' AND b.customer_id IN (select customer_id from #Customer_id_list) '  
  
IF (select count(*) from #generator_id_list) > 0  
	SET @access_filter_sql = @access_filter_sql + ' AND b.generator_id IN (select generator_id from #generator_id_list) '  
  
IF @contact_id > -1  
	SET @access_filter_sql = @access_filter_sql + ' AND b.customer_id IN (  
	   SELECT DISTINCT customer_id   
	   FROM ContactXRef   
	   WHERE type = ''C'' and web_access = ''A''   
	   and status = ''A'' AND contact_id = ' + convert(varchar(20), @contact_id) + ') '  
  
 -- If Associate running this, and NOT "all customers", also find records for direct-generators of the customers chosen.  
if @contact_id = -1  AND (select count(*) from #Customer_id_list) > 0  
	SET @access_filter_sql = @access_filter_sql + '  
    AND (1=1 OR exists (  
		Select cg.generator_id from CustomerGenerator cg, Customer c  
		Where cg.generator_id = b.generator_id  
		AND cg.customer_id IN (select customer_id from #customer_id_list)   
		AND cg.customer_id = c.customer_id  
		AND c.generator_flag = ''T''  
    ) ) '  

-- add @detail_where to @access_filter_sql
SET @access_filter_sql = @access_filter_sql + @detail_where

-- Least specific criteria last-est:    
set @access_filter_sql = @access_filter_sql + 'AND b.status_code = ''I'' ' 

if (@debug > 0) print @access_filter_sql

EXEC(@access_filter_sql)

-- #access_filter is created & populated now.
-- At this point we're only exporting summary data, or else we'd have
-- been given a valid session_id and not be in this branch of logic...
-- So populate the List table:

select @detail_query = '
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
		 getdate()
	',
	@detail_join = '
	INNER JOIN #tmp_database td on b.company_id = td.company_id  
	INNER JOIN #access_filter af ON af.company_id = b.company_id 
		AND af.profit_ctr_id = b.profit_ctr_id 
		AND af.trans_source = b.trans_source 
		AND af.receipt_id = b.receipt_id 
		AND af.line_id = b.line_id 
		AND af.price_id = b.price_id 
		AND af.billing_project_id = b.billing_project_id   
	'	

SET @access_filter_sql = replace(replace(replace(@detail_sql, '/* QUERY */', @detail_query), '/* JOIN */', @detail_join), '/* WHERE */', @detail_where)
if (@debug > 0) print @access_filter_sql
EXEC (@access_filter_sql)

-- Now we can return the results...
-- Or if this was a 'D'etail query, execute the sql
-- that returns detailed info for records already in the list table.

-------------------------------------------
------------- RETURN RESULTS --------------
-------------------------------------------
returnresults:

	if @detail_level = 'S' 
	begin

		-- get paging records
		SELECT  @start_of_results = min(row_num)-1, 
				@end_of_results = max(row_num) 
		FROM Work_BillingSummaryListResult
		WHERE session_key = @session_key 


		-- get summary records
		SELECT *,
			@end_of_results - @start_of_results as record_count
		 FROM Work_BillingSummaryListResult
		WHERE row_num >= @start_of_results + @row_from
		and row_num <= 
		case 
			when @row_to = -1 
			then @end_of_results 
			else @start_of_results + @row_to 
		END
		AND session_key = @session_key
		ORDER BY 
			cust_name,
			customer_id, 
			invoice_date, 
			invoice_code, 
			company_id, 
			profit_ctr_id
	end




	if @detail_level = 'D'
	BEGIN

		-- No paging details here - it always returns the full set to excel.
		
		select @detail_query = '
			SELECT 
			b.company_id,  
			b.profit_ctr_id,  
			p.profit_ctr_name,  
			CASE 
				WHEN b.trans_source = ''R'' THEN ''Receipt''
				WHEN b.trans_source = ''O'' THEN ''Retail''
				WHEN b.trans_source = ''W'' THEN ''Work Order''
				ELSE b.trans_source
			END	AS trans_source,
			b.receipt_id,  
			b.line_id,  
			b.price_id,  
			b.status_code,  
			b.billing_date,  
			b.invoice_code,  
			b.invoice_date,  
			b.customer_id,  
			c.cust_name,  
			i.bill_unit_code,  
			b.generator_id,  
			b.generator_name,  
			g.epa_id,  
			coalesce(nullif(b.approval_code,''''), ta.tsdf_approval_code, '''') as approval_code,  
			i.location_code,  
			i.qty_ordered as quantity,  
			i.unit_price as extended_amt,  
			b.manifest,  
			b.purchase_order,  
			b.release_code,  
			CASE 
				WHEN b.trans_type = ''S'' THEN ''Service''
				WHEN b.trans_type = ''W'' THEN ''Wash''
				WHEN b.trans_type = ''O'' THEN ''Work Order''
				WHEN b.trans_type = ''R'' THEN ''Retail''
				WHEN b.trans_type = ''D'' THEN ''Disposal''				
				ELSE b.trans_type
			END	AS trans_type,
			i.line_desc_1,  
			i.line_desc_2,
			isnull(b.service_desc_1, b.service_desc_2) as description,
			cb.billing_project_id,
			bu.bill_unit_desc bill_unit_description,
			cb.project_name billing_project_name,
			wl.session_key,
			wl.session_added,
			dbo.fn_get_pickup_date(b.receipt_id, b.company_id, b.profit_ctr_id, b.invoice_code, b.line_id, b.trans_source) as pickup_date
			, g.site_code
			',
			@detail_join = '
			INNER JOIN [Work_BillingSummaryListResult] wl on
				wl.company_id = b.company_id
				and wl.profit_ctr_id = b.profit_ctr_id
				and wl.invoice_code = b.invoice_code
				and wl.invoice_date = b.invoice_date
				and wl.customer_id = b.customer_id
				and wl.session_key = ''' + @session_key + '''
			',
			@detail_order = '
			ORDER BY 
				c.cust_name,
				b.customer_id, 
				b.invoice_date,
				b.invoice_code,
				b.company_id, 
				b.profit_ctr_id,
				b.receipt_id,  
				b.line_id,  
				b.price_id
			'

		SET @access_filter_sql = replace(replace(replace(@detail_sql, '/* QUERY */', @detail_query), '/* JOIN */', @detail_join), '/* WHERE */', @detail_where) + @detail_order
		if (@debug > 0) print @access_filter_sql
		EXEC (@access_filter_sql)
		

	END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_billing_summary_master2] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_billing_summary_master2] TO [COR_USER]
    AS [dbo];


