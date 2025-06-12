-- 
drop proc if exists sp_cor_billing_summary_lpx
go

CREATE PROCEDURE [dbo].[sp_cor_billing_summary_lpx]
	@web_userid			varchar(100) = '',
	@debug				int = 0,    -- 0 or 1 for no debug/debug mode  
	@customer_id_list	varchar(max) = '', -- Comma Separated Customer ID List - what customers to include  
	@generator_id_list	varchar(max) = '', -- Comma Separated Generator ID List - what generators to include  
	@approval_code		varchar(max) = '', -- Approval Code  
	@invoice_code_list	varchar(max) = '', -- Invoice Code  
	@manifest			varchar(max) = '', -- Manfiest Code  
	@start_date			varchar(20) = '',
	@end_date			varchar(20) = '',
	@description		varchar(100) = '', -- Description search field
	@po_release			varchar(100)= '' -- PO, Release search field
    , @lpx_rollup_override int = 3
AS  
/* *******************  
sp_cor_billing_summary_lpx:  
  
Returns the data for Billing Summary.  
This SP can return prices - so it's not for generator access.  Contacts must be limited to their own accounts.  
  
  
LOAD TO PLT_AI * on NTSQL1  

Testing/examples:

SELECT  * FROM    contact WHERE  web_userid = 'court_c'
-- 175531
SELECT  * FROM    contactcorcustomerbucket where contact_id = 175531
SELECT  TOP 10 *
FROM   contactcorcustomerbucket

sp_cor_billing_summary_lpx
	@web_userid			= 'all_customers'
	,@debug				= 0    -- 0 or 1 for no debug/debug mode  
	,@customer_id_list	= '601839' -- Comma Separated Customer ID List - what customers to include  
	,@generator_id_list	= '' -- Comma Separated Generator ID List - what generators to include  
	,@approval_code		= '' -- Approval Code  
	,@invoice_code_list	= '' -- Invoice Code  
	,@manifest			= '' -- Manfiest Code  
	,@start_date		= '1/1/2015'
	,@end_date			= '12/31/2020'
	,@description		= '' -- Description search field
	,@po_release			= ''

    , @lpx_rollup_override  = 2

	
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
12/02/2019 JPB - Copied to sp_cor_billing_summary_lpx from sp_reports_billing_summary_master and customized

********************* */  

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

declare
	@i_web_userid			varchar(100) = isnull(@web_userid, ''),
	@i_debug				int = isnull(@debug, 0),    -- 0 or 1 for no debug/debug mode  
	@i_customer_id_list	varchar(max) = isnull(@customer_id_list, ''), -- Comma Separated Customer ID List - what customers to include  
	@i_generator_id_list	varchar(max) = isnull(@generator_id_list, ''), -- Comma Separated Generator ID List - what generators to include  
	@i_approval_code		varchar(max) = isnull(@approval_code, ''), -- Approval Code  
	@i_invoice_code_list	varchar(max) = isnull(@invoice_code_list, ''), -- Invoice Code  
	@i_manifest				varchar(max) = isnull(@manifest, ''), -- Manfiest Code  
	@i_default_start_date	varchar(20) = convert(date, dateadd(m, -6, getdate())),
	@i_default_end_date		varchar(20) = convert(date, getdate()),  -- End Date  
	@i_start_date			varchar(20) = isnull(@start_date, ''),
	@i_end_date				varchar(20) = isnull(@end_date, ''),
	@i_description		varchar(100) = isnull(@description, ''), -- Description search field
	@i_po_release			varchar(100) = isnull(@po_release,''), -- PO, Release search field
	@i_contact_id		int
	, @i_starttime	datetime = getdate()
	, @i_lasttime	datetime = getdate()
    , @ilpx_rollup_override int = isnull(@lpx_rollup_override,3)
	

select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid

if @i_start_date = '' set @i_start_date = @i_default_start_date else set @i_start_date = convert(date, @i_start_date)
if @i_end_date = '' set @i_end_date = @i_default_end_date else set @i_end_date = convert(date, @i_end_date)

if datepart(hh, @i_end_date) = 0 set @i_end_date = convert(datetime, @i_end_date) + 0.99999

 
-- Create temp tables for data storage/validation  
CREATE TABLE #customer_id_list (customer_id int)  
CREATE INDEX idx1 ON #customer_id_list (customer_id)  
INSERT #Customer_id_list 
	SELECT convert(int, row) 
	from dbo.fn_SplitXsvText(',', 0, @i_customer_id_list) 
	WHERE ISNULL(row, '') <> ''  
  
CREATE TABLE #generator_id_list (generator_id int)  
CREATE INDEX idx2 ON #generator_id_list (generator_id)  
INSERT #generator_id_list 
	SELECT convert(int, row) 
	from dbo.fn_SplitXsvText(',', 0, @i_generator_id_list) 
	WHERE ISNULL(row, '') <> ''  
    
CREATE TABLE #invoice_code_list (invoice_code varchar(16))  
CREATE INDEX idx3 ON #invoice_code_list (invoice_code)  
INSERT #invoice_code_list 
	SELECT row 
	from dbo.fn_SplitXsvText(',', 1, @i_invoice_code_list) 
	WHERE ISNULL(row, '') <> ''  
  
CREATE TABLE #Approval (approval_code varchar(15))  
CREATE INDEX idx4 ON #Approval (approval_code)  
INSERT #Approval 
	SELECT row 
	from dbo.fn_SplitXsvText(',', 1, @i_approval_code) 
	WHERE ISNULL(row, '') <> ''  
   
CREATE TABLE #Manifest (manifest varchar(15))  
CREATE INDEX idx5 ON #Manifest (manifest)  
INSERT #Manifest 
	SELECT row 
	from dbo.fn_SplitXsvText(',', 1, @i_manifest) 
	WHERE ISNULL(row, '') <> ''  

CREATE TABLE #Description (term varchar(100), process_flag int)  
INSERT #Description
	SELECT row, 0
	from dbo.fn_SplitXsvText(',', 1, @i_description) 
	WHERE ISNULL(row, '') <> ''  

			
CREATE TABLE #POR (term varchar(100), process_flag int)  
INSERT #POR
	SELECT row, 0
	from dbo.fn_SplitXsvText(',', 1, @i_po_release) 
	WHERE ISNULL(row, '') <> ''  


declare @foo table (
	receipt_id	int
	, company_id	int
	, profit_ctr_id	int
	, trans_source	char(1)
)
insert @foo
select receipt_id, company_id, profit_ctr_id, trans_source
from ContactCORBillingBucket
WHERE contact_id = @i_contact_id
and status_code = 'I'
and (
	@i_customer_id_list = ''
	or
	customer_id in (select customer_id from #customer_id_list)
)	
and (
	@i_generator_id_list = ''
	or
	generator_id in (select generator_id from #generator_id_list)
)	

if @i_debug > 0 select '@foo populated with ' + convert(varchar(20), count(*)) + ' rows', datediff(ms, @i_lasttime, getdate()) as step_ms, datediff(ms, @i_starttime, getdate()) as total_ms from @foo
set @i_lasttime = getdate()

declare @bar table (
	billing_uid	int
	, approval_code varchar(40)
)

insert @bar
select distinct b.billing_uid, isnull(b.approval_code, ta.TSDF_approval_code)
from @foo f
join billing b
	on f.receipt_id = b.receipt_id
	and b.line_id = b.line_id
	and b.price_id = b.price_id
	and f.trans_source = b.trans_source
	and f.profit_ctr_id = b.profit_ctr_id
	and f.company_id = b.company_id
	and b.status_code = 'I'
LEFT JOIN TSDFApproval ta ON ta.tsdf_approval_id = b.tsdf_approval_id 
--left join #Approval 
--	on COALESCE(NULLIF(b.approval_code,''), ta.tsdf_approval_code, '') LIKE '%' + #Approval.approval_code + '%'
where 1=1
and b.invoice_date >= @i_start_date
and b.invoice_date <= @i_end_date
and (
	@i_invoice_code_list = ''
	or
	b.invoice_code in (select invoice_code from #invoice_code_list)
)
and (
	@i_manifest = ''
	or
	b.manifest in (select manifest from #manifest)
)
--and (
--	@i_approval_code = ''
--	or
--	#approval.approval_code is not null
--)

if @i_debug > 0 select '@bar populated with ' + convert(varchar(20), count(*)) + ' rows', datediff(ms, @i_lasttime, getdate()) as step_ms, datediff(ms, @i_starttime, getdate()) as total_ms from @bar
set @i_lasttime = getdate()



declare @rex table (
	billing_uid int
	, approval_code varchar(40)
)
if @i_description <> '' begin
	insert @rex
	select x.billing_uid, x.approval_code
	from @bar x
	join billing b on x.billing_uid = b.billing_uid
	join #description y
		on ISNULL(b.service_desc_1, '') + ' ' + ISNULL(b.service_desc_2, '') LIKE '%' + REPLACE(y.term, ' ', '%') + '%'
		
	delete from @bar
	insert @bar 
	select distinct billing_uid, Approval_code
	from @rex
	delete from @rex
end

if @i_debug > 0 select '@rex/bar populated (description search) with ' + convert(varchar(20), count(*)) + ' rows', datediff(ms, @i_lasttime, getdate()) as step_ms, datediff(ms, @i_starttime, getdate()) as total_ms from @bar
set @i_lasttime = getdate()


if @i_po_release <> '' begin
	insert @rex
	select x.billing_uid, x.approval_code
	from @bar x
	join billing b on x.billing_uid = b.billing_uid
	join #por y
		on ISNULL(b.purchase_order, '') + ' ' + ISNULL(b.release_code, '') LIKE '%' + replace(y.term, ' ', '%') + '%'
		
	delete from @bar
	insert @bar 
	select distinct billing_uid , approval_code
	from @rex
	delete from @rex
end

if @i_debug > 0 select '@rex/bar populated (PO/Release search) with ' + convert(varchar(20), count(*)) + ' rows', datediff(ms, @i_lasttime, getdate()) as step_ms, datediff(ms, @i_starttime, getdate()) as total_ms from @bar
set @i_lasttime = getdate()

update @bar
set approval_code = b.approval_code
from @bar x
join billing b on x.billing_uid = b.billing_uid
where	isnull(x.approval_code, '') = ''
and isnull(b.approval_code, '') <> ''

update @bar
set approval_code = ta.tsdf_approval_code
from @bar x
join billing b on x.billing_uid = b.billing_uid
LEFT JOIN TSDFApproval ta ON ta.tsdf_approval_id = b.tsdf_approval_id 
where	isnull(x.approval_code, '') = ''
and isnull(ta.tsdf_approval_code, '') <> ''

update @bar
set approval_code = r.approval_code
from @bar x
join billing b on x.billing_uid = b.billing_uid
LEFT JOIN Receipt r ON b.receipt_id = r.receipt_id and b.company_id = r.company_id
	and b.profit_ctr_id = r.profit_ctr_id and b.line_id = r.line_id
	and b.trans_source = 'R'
where	isnull(x.approval_code, '') = ''
and isnull(r.approval_code, '') <> ''
   
update @bar
set approval_code = d.tsdf_approval_code
from @bar x
join billing b on x.billing_uid = b.billing_uid
LEFT JOIN WorkorderDetail d ON b.receipt_id = d.workorder_id and b.company_id = d.company_id
	and b.profit_ctr_id = d.profit_ctr_id and b.workorder_sequence_id = d.sequence_id
	and b.workorder_resource_type = 'D' and b.trans_source = 'W'
where	isnull(x.approval_code, '') = ''
and isnull(d.tsdf_approval_code, '') <> ''

if @i_approval_code <> '' begin
	insert @rex
	select x.billing_uid, x.approval_code
	from @bar x
	join #Approval a
		on isnull(x.approval_code,'') LIKE '%' + a.approval_code + '%'		
	
	delete from @bar
	insert @bar 
	select distinct billing_uid , approval_code
	from @rex
	delete from @rex
end
   

-- IF @detail_level = 'D'
BEGIN

	-- No paging details here - it always returns the full set to excel.
	
	----------------------------------------------------------------------------------
	-- First, select all of the regular disposal, service and work order charges,
	-- without MI surcharges, insurance, energy and sales tax.
	----------------------------------------------------------------------------------
	select *
	, _row = convert(float, row_number() over (
		ORDER BY 
		cust_name
		, customer_id
		, invoice_date
		, invoice_code
		, company_id
		, profit_ctr_id
		, receipt_id
		, line_id
		, price_id
		, record_type
		, description
	))
	into #lpxdata
	from 
	(
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
	, isnull(g.generator_address_1, '') + isnull(' ' + g.generator_address_2, '') + isnull(' ' + g.generator_address_3, '') + isnull(' ' + g.generator_address_4, '') + isnull(' ' + g.generator_address_5, '') as generator_address
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
		WHEN b.trans_type = 'S' THEN 'Service'
		WHEN b.trans_type = 'W' THEN 'Wash'
		WHEN b.trans_type = 'O' THEN 'Work Order'
		WHEN b.trans_type = 'R' THEN 'Retail'
		WHEN b.trans_type = 'D' THEN 'Disposal'
		ELSE b.trans_type
		END	AS trans_type
	, CASE 
		WHEN b.trans_source = 'R' THEN 'Receipt'
		WHEN b.trans_source = 'O' THEN 'Retail'
		WHEN b.trans_source = 'W' THEN 'Work Order'
		ELSE b.trans_source
		END	AS trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.line_id
	, b.price_id
	, COALESCE(NULLIF(b.approval_code,''), ta.tsdf_approval_code, bar.approval_code, '') AS approval_code
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
		AND bd.billing_type NOT IN ('Insurance', 'Energy', 'SalesTax', 'State-Haz', 'State-Perp')
		)
	, 1 AS record_type
	, 1 AS surcharge_tax_type

	, convert(varchar(2), b.company_id) + '-' +
	  convert(varchar(2), b.profit_ctr_id) + ' ' + left(b.trans_source, 1) + ':' +
	  convert(varchar(10), b.receipt_id) + '-' + convert(varchar(10), b.line_id) + '-' + convert(varchar(10), b.price_id) as reference_id

	, resource_type = convert(varchar(60), null)
	, _labpack_quote_flag = convert(char(1), null)
	, _labpack_pricing_rollup = convert(char(1), null)
				
	FROM @bar bar
	JOIN Billing b  
		on bar.billing_uid = b.billing_uid
	LEFT JOIN BillingComment bc ON b.trans_source = bc.trans_source
		AND b.receipt_id = bc.receipt_id
		AND b.company_id = bc.company_id
		and b.profit_ctr_id = bc.profit_ctr_id
	INNER JOIN InvoiceHeader ih ON ih.invoice_id = b.invoice_id
		AND ih.status = 'I' 
	INNER JOIN Customer c ON c.customer_id = b.customer_id  
	INNER JOIN BillUnit bu ON bu.bill_unit_code = b.bill_unit_code
	INNER JOIN ProfitCenter p ON p.company_id = b.company_id
		AND p.profit_ctr_id = b.profit_ctr_id
	INNER JOIN CustomerBilling cb ON cb.customer_id = b.customer_id 
		AND cb.billing_project_id = b.billing_project_id
	LEFT OUTER JOIN Generator g ON g.generator_id = b.generator_id  
	LEFT OUTER JOIN TSDFApproval ta ON ta.tsdf_approval_id = b.tsdf_approval_id 
	WHERE 1=1 

	UNION	

	----------------------------------------------------------------------------------
	-- Second, include the MI surcharges on their own lines.
	----------------------------------------------------------------------------------
	
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
	, isnull(g.generator_address_1, '') + isnull(' ' + g.generator_address_2, '') + isnull(' ' + g.generator_address_3, '') + isnull(' ' + g.generator_address_4, '') + isnull(' ' + g.generator_address_5, '') as generator_address
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
		WHEN b.trans_type = 'S' THEN 'Service'
		WHEN b.trans_type = 'W' THEN 'Wash'
		WHEN b.trans_type = 'O' THEN 'Work Order'
		WHEN b.trans_type = 'R' THEN 'Retail'
		WHEN b.trans_type = 'D' THEN 'Disposal'
		ELSE b.trans_type
		END	AS trans_type
	, CASE 
		WHEN b.trans_source = 'R' THEN 'Receipt'
		WHEN b.trans_source = 'O' THEN 'Retail'
		WHEN b.trans_source = 'W' THEN 'Work Order'
		ELSE b.trans_source
		END	AS trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.line_id
	, b.price_id
	, COALESCE(NULLIF(b.approval_code,''), ta.tsdf_approval_code,  bar.approval_code, '') AS approval_code
	, b.manifest
	, b.purchase_order
	, b.release_code
	, COALESCE(s.surcharge_desc, b.service_desc_1, b.service_desc_2) AS description
	, b.quantity
	, b.bill_unit_code
	, bu.bill_unit_desc AS bill_unit_description
	, b.sr_price AS price
	, extended_amt = SUM(bd.extended_amt) 
	, 2 AS record_type
	, 1 AS surcharge_tax_type

	, convert(varchar(2), b.company_id) + '-' +
	  convert(varchar(2), b.profit_ctr_id) + ' ' + left(b.trans_source, 1) + ':' +
	  convert(varchar(10), b.receipt_id) + '-' + convert(varchar(10), b.line_id) + '-' + convert(varchar(10), b.price_id) as reference_id

	, resource_type = convert(varchar(60), null)
	, _labpack_quote_flag = convert(char(1), null)
	, _labpack_pricing_rollup = convert(char(1), null)

	FROM @bar bar
	JOIN Billing b  
		on bar.billing_uid = b.billing_uid
	INNER JOIN BillingDetail bd ON b.billing_uid = bd.billing_uid 
		AND bd.billing_type IN ('State-Haz', 'State-Perp')
	INNER JOIN Surcharge s ON s.company_id = b.company_id
		AND s.profit_ctr_id = b.profit_ctr_id
		AND s.sr_type_code = b.sr_type_code
		AND s.bill_unit_code = b.bill_unit_code
		AND s.curr_status_code = 'A'
	LEFT JOIN BillingComment bc ON b.trans_source = bc.trans_source
		AND b.receipt_id = bc.receipt_id
		AND b.company_id = bc.company_id
		and b.profit_ctr_id = bc.profit_ctr_id
	INNER JOIN InvoiceHeader ih ON ih.invoice_id = b.invoice_id
		AND ih.status = 'I' 
	INNER JOIN Customer c ON c.customer_id = b.customer_id  
	INNER JOIN BillUnit bu ON bu.bill_unit_code = b.bill_unit_code
	INNER JOIN ProfitCenter p ON p.company_id = b.company_id
		AND p.profit_ctr_id = b.profit_ctr_id
	INNER JOIN CustomerBilling cb ON cb.customer_id = b.customer_id 
		AND cb.billing_project_id = b.billing_project_id
	LEFT OUTER JOIN Generator g ON g.generator_id = b.generator_id  
	LEFT OUTER JOIN TSDFApproval ta ON ta.tsdf_approval_id = b.tsdf_approval_id 
	WHERE 1=1 
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
	, isnull(g.generator_address_1, '') + isnull(' ' + g.generator_address_2, '') + isnull(' ' + g.generator_address_3, '') + isnull(' ' + g.generator_address_4, '') + isnull(' ' + g.generator_address_5, '')
	, g.generator_city
	, g.generator_state
	, g.generator_zip_code
	, g.generator_division
	, g.generator_region_code
	, bc.service_date
	, COALESCE(NULLIF(b.approval_code,''), ta.tsdf_approval_code, bar.approval_code, '')
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
	, convert(varchar(2), b.company_id) + '-' +
	  convert(varchar(2), b.profit_ctr_id) + ' ' + left(b.trans_source, 1) + ':' +
	  convert(varchar(10), b.receipt_id) + '-' + convert(varchar(10), b.line_id) + '-' + convert(varchar(10), b.price_id) --as reference_id

	UNION	
	----------------------------------------------------------------------------------
	-- Third, include insurance/energy surcharges and salest taxes on their own lines.
	----------------------------------------------------------------------------------
	
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
	, isnull(g.generator_address_1, '') + isnull(' ' + g.generator_address_2, '') + isnull(' ' + g.generator_address_3, '') + isnull(' ' + g.generator_address_4, '') + isnull(' ' + g.generator_address_5, '') as generator_address
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
	, CASE bd.billing_type
		WHEN 'Insurance' THEN 'Surcharge'
		WHEN 'Energy' THEN 'Surcharge'
		WHEN 'SalesTax' THEN 'Sales Tax'
		ELSE NULL
		END	AS trans_type
	, CASE 
		WHEN b.trans_source = 'R' THEN 'Receipt'
		WHEN b.trans_source = 'O' THEN 'Retail'
		WHEN b.trans_source = 'W' THEN 'Work Order'
		ELSE b.trans_source
		END	AS trans_source
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.line_id
	, b.price_id
	, COALESCE(NULLIF(b.approval_code,''), ta.tsdf_approval_code, bar.approval_code, '') AS approval_code
	, b.manifest
	, b.purchase_order
	, b.release_code
	, CASE bd.billing_type
		WHEN 'Insurance' THEN 'Insurance Surcharge'
		WHEN 'Energy' THEN 'Energy Surcharge'
		WHEN 'SalesTax' THEN st.tax_description
		ELSE NULL
		END	AS description
	, 1 AS quantity
	, bu.bill_unit_code
	, bu.bill_unit_desc AS bill_unit_description
	, price = SUM(bd.extended_amt) 
	, extended_amt = SUM(bd.extended_amt) 
	, 3 AS record_type
	, CASE bd.billing_type
		WHEN 'Insurance' THEN 10
		WHEN 'Energy' THEN 20
		WHEN 'SalesTax' THEN 30
		ELSE 100
		END	AS surcharge_tax_type
	, convert(varchar(2), b.company_id) + '-' +
	  convert(varchar(2), b.profit_ctr_id) + ' ' + left(b.trans_source, 1) + ':' +
	  convert(varchar(10), b.receipt_id) + '-' + convert(varchar(10), b.line_id) + '-' + convert(varchar(10), b.price_id) as reference_id

	, resource_type = convert(varchar(60), null)
	, _labpack_quote_flag = convert(char(1), null)
	, _labpack_pricing_rollup = convert(char(1), null)

	FROM @bar bar
	JOIN Billing b  
		on bar.billing_uid = b.billing_uid
	INNER JOIN BillingDetail bd ON b.billing_uid = bd.billing_uid 
		AND bd.billing_type IN ('Insurance', 'Energy', 'SalesTax')
	LEFT OUTER JOIN SalesTax st ON st.sales_tax_id = bd.sales_tax_id
	LEFT JOIN BillingComment bc ON b.trans_source = bc.trans_source
		AND b.receipt_id = bc.receipt_id
		AND b.company_id = bc.company_id
		and b.profit_ctr_id = bc.profit_ctr_id
	INNER JOIN InvoiceHeader ih ON ih.invoice_id = b.invoice_id
		AND ih.status = 'I' 
	INNER JOIN Customer c ON b.customer_id = c.customer_id  
	INNER JOIN BillUnit bu ON bu.bill_unit_code = 'EACH'
	INNER JOIN ProfitCenter p ON p.company_id = b.company_id
		AND p.profit_ctr_id = b.profit_ctr_id
	INNER JOIN CustomerBilling cb ON cb.customer_id = b.customer_id 
		AND cb.billing_project_id = b.billing_project_id
	LEFT OUTER JOIN Generator g ON g.generator_id = b.generator_id  
	LEFT OUTER JOIN TSDFApproval ta ON ta.tsdf_approval_id = b.tsdf_approval_id 
	WHERE 1=1
	GROUP BY 
	c.cust_name
	, b.customer_id
	, b.invoice_code
	, b.invoice_date
	, p.profit_ctr_name
	, cb.billing_project_id
	, cb.project_name
	, b.generator_name
	, b.generator_id
	, g.epa_id
	, g.site_type
	, isnull(g.generator_address_1, '') + isnull(' ' + g.generator_address_2, '') + isnull(' ' + g.generator_address_3, '') + isnull(' ' + g.generator_address_4, '') + isnull(' ' + g.generator_address_5, '')
	, g.generator_city
	, g.generator_state
	, g.generator_zip_code
	, g.generator_division
	, g.generator_region_code
	, CASE
		WHEN bc.service_date is null THEN
			dbo.fn_get_service_date(b.company_id, b.profit_ctr_id, b.receipt_id, b.trans_source)
		ELSE bc.service_date
		END
	, CASE bd.billing_type
		WHEN 'Insurance' THEN 'Surcharge'
		WHEN 'Energy' THEN 'Surcharge'
		WHEN 'SalesTax' THEN 'Sales Tax'
		ELSE NULL
		END
	, CASE 
		WHEN b.trans_source = 'R' THEN 'Receipt'
		WHEN b.trans_source = 'O' THEN 'Retail'
		WHEN b.trans_source = 'W' THEN 'Work Order'
		ELSE b.trans_source
		END
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.line_id
	, b.price_id
	, COALESCE(NULLIF(b.approval_code,''), ta.tsdf_approval_code, bar.approval_code, '')
	, b.manifest
	, b.purchase_order
	, b.release_code
	, CASE bd.billing_type
		WHEN 'Insurance' THEN 'Insurance Surcharge'
		WHEN 'Energy' THEN 'Energy Surcharge'
		WHEN 'SalesTax' THEN st.tax_description
		ELSE NULL
		END
	, bu.bill_unit_code
	, bu.bill_unit_desc
	, CASE bd.billing_type
		WHEN 'Insurance' THEN 10
		WHEN 'Energy' THEN 20
		WHEN 'SalesTax' THEN 30
		ELSE 100
		END
	, convert(varchar(2), b.company_id) + '-' +
	  convert(varchar(2), b.profit_ctr_id) + ' ' + left(b.trans_source, 1) + ':' +
	  convert(varchar(10), b.receipt_id) + '-' + convert(varchar(10), b.line_id) + '-' + convert(varchar(10), b.price_id)
	) src

	update #lpxdata
	set _labpack_quote_flag = s.labpack_quote_flag
	, _labpack_pricing_rollup = s.labpack_pricing_rollup
	, resource_type = s.resource_type
	from 
	#lpxdata l
	join (
	  select isnull(qh.labpack_quote_flag, 'F') as 'labpack_quote_flag', qh.labpack_pricing_rollup
	  , d.receipt_id, d.line_id, d.price_id, d.company_id, d.profit_ctr_id, d.trans_source
	  , case wod.resource_type
		when 'D' then 'Disposal'
		when 'E' then 'Equipment'
		when 'L' then 'Labor'
		when 'O' then 'Other'
		when 'S' then 'Supplies'
		else null
		end as resource_type
	  from workorderheader h
	  join billing b
		on h.workorder_id = b.receipt_id
		and h.company_id = b.company_id
		and h.profit_ctr_id = b.profit_ctr_id
	  join workorderdetail wod
		on wod.workorder_id = b.receipt_id
		and wod.company_id = b.company_id
		and wod.profit_ctr_id = b.profit_ctr_id
	  join #lpxdata d
		on h.workorder_ID = d.receipt_id
		and b.line_id = d.line_id
		and b.price_id = d.price_id
		and h.company_id = d.company_id
		and h.profit_ctr_ID = d.profit_ctr_id
		and d.trans_source in ('Work Order', 'workorder')
		and wod.resource_type = b.workorder_resource_type
		and wod.sequence_id = b.workorder_sequence_id
	  left join workorderquoteheader  qh 
		on h.quote_id = qh.quote_id
		and h.company_id = qh.company_id
		and h.profit_ctr_id = qh.profit_ctr_id
	  union
	  select isnull(qh.labpack_quote_flag, 'F') as 'labpack_quote_flag', qh.labpack_pricing_rollup
	  , d.receipt_id, d.line_id, d.price_id, d.company_id, d.profit_ctr_id, d.trans_source
	  , case r.trans_type
		when 'D' then 'Disposal'
		when 'S' then 'Service'
		when 'W' then 'Wash'
		else null
		end as resource_type
	  from BillingLinkLookup bll
	  join #lpxdata d
		on bll.receipt_id = d.receipt_id
		and bll.company_id = d.company_id
		and bll.profit_ctr_ID = d.profit_ctr_id
		and d.trans_source in ('receipt')
	  join receipt r
		on d.receipt_id = r.receipt_id
		and d.company_id = r.company_id
		and d.profit_ctr_id = r.profit_ctr_id
		and d.line_id = r.line_id
	  join workorderheader h
		on bll.source_id = h.workorder_ID
		and bll.source_company_id = h.company_id
		and bll.source_profit_ctr_id = h.profit_ctr_ID
	  left join workorderquoteheader  qh 
		on h.quote_id = qh.quote_id
		and h.company_id = qh.company_id
		and h.profit_ctr_id = qh.profit_ctr_id
	  ) s
		on l.receipt_id = s.receipt_id
		and l.company_id = s.company_id
		and l.line_id = s.line_id
		and l.price_id = s.price_id
		and l.profit_ctr_id = s.profit_ctr_id
		and l.trans_source = s.trans_source
	
		update #lpxdata set _labpack_pricing_rollup = convert(char(1),@ilpx_rollup_override)
		where isnull(@ilpx_rollup_override, '3') <> isnull(_labpack_pricing_rollup, '3') 

		-- region Calculate LPX Subtotals
		drop table if exists #lpxdatasubtotal
		select 
		invoice_code
		, invoice_date
		, trans_source, receipt_id, company_id, profit_ctr_id
		, _labpack_pricing_rollup
		, resource_type + ' Subtotal' as resource_type
		, sum(extended_amt) as subtotal
		, max(_row) + 0.5 as _row
		into #lpxdatasubtotal
		from #lpxdata
		where isnull(_labpack_pricing_rollup, '3') in ('1', '2')
		group by 
		invoice_code
		, invoice_date
		, trans_source, receipt_id, company_id, profit_ctr_id
		, _labpack_pricing_rollup
		, resource_type

		update #lpxdata set price = null, extended_amt = null where isnull(_labpack_pricing_rollup, '3') in ('1', '2')

	SELECT 
	cust_name
	, customer_id
	, invoice_code
	, invoice_date
	, profit_ctr_name
	, billing_project_id
	, billing_project_name
	, generator_name
	, generator_id
	, epa_id
	, site_type
	, generator_address
	, generator_city
	, generator_state
	, generator_zip_code
	, generator_division
	, generator_region_code
	, service_date
	, trans_type
	, trans_source
	, company_id
	, profit_ctr_id
	, receipt_id
	, line_id
	, price_id
	, approval_code
	, manifest
	, purchase_order
	, release_code
	, description
	, quantity
	, bill_unit_code
	, bill_unit_description
	, price
	, extended_amt
	, record_type
	, surcharge_tax_type

	, reference_id

	, resource_type
	, null as subtotal
	, _labpack_pricing_rollup
	, _row

	from #lpxdata
	union all
	SELECT 
	null as cust_name
	, null as customer_id
	, invoice_code
	, invoice_date
	, null as profit_ctr_name
	, null as billing_project_id
	, null as billing_project_name
	, null as generator_name
	, null as generator_id
	, null as epa_id
	, null as site_type
	, null as generator_address
	, null as generator_city
	, null as generator_state
	, null as generator_zip_code
	, null as generator_division
	, null as generator_region_code
	, null as service_date
	, null as trans_type
	, null as trans_source
	, null as company_id
	, null as profit_ctr_id
	, null as receipt_id
	, null as line_id
	, null as price_id
	, null as approval_code
	, null as manifest
	, null as purchase_order
	, null as release_code
	, null as description
	, null as quantity
	, null as bill_unit_code
	, null as bill_unit_description
	, null as price
	, null as extended_amt
	, null as record_type
	, null as surcharge_tax_type

	, null as reference_id

	, resource_type
	, subtotal
	, _labpack_pricing_rollup
	, _row
	from #lpxdatasubtotal
	order by _row

if @i_debug > 0 select 'Completed', datediff(ms, @i_lasttime, getdate()) as step_ms, datediff(ms, @i_starttime, getdate()) as total_ms 
set @i_lasttime = getdate()


END

GO

Grant execute on sp_cor_billing_summary_lpx to EQAI
go
Grant execute on sp_cor_billing_summary_lpx to EQWEB
go
Grant execute on sp_cor_billing_summary_lpx to COR_USER
go

