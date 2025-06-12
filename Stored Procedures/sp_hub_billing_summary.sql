-- drop proc [dbo].[sp_hub_billing_summary]
CREATE PROCEDURE [dbo].[sp_hub_billing_summary]
	@customer_id_list	varchar(max) = '', -- Comma Separated Customer ID List - what customers to include  
	@generator_id_list	varchar(max) = '', -- Comma Separated Generator ID List - what generators to include  
	@customer_type_list	varchar(max) = '', -- Customer Type List
	@approval_code		varchar(max) = '', -- Approval Code  
	@invoice_code_list	varchar(max) = '', -- Invoice Code  
	@manifest			varchar(max) = '', -- Manfiest Code  
	@invoice_start_date			varchar(20) = '',
	@invoice_end_date			varchar(20) = '',
	@description		varchar(100) = '', -- Description search field
	@po_release			varchar(100)= '', -- PO, Release search field
	@user_code			varchar(20),
	@permission_id		int,
    @debug              int = 0            -- 0 or 1 for no debug/debug mode
AS  
/* *******************  
sp_hub_billing_summary:  
  
Returns the data for Billing Summary, migrated to Hub for additional input options.
  
  
LOAD TO PLT_AI * on NTSQL1  

Testing/examples:


sp_hub_billing_summary
	@customer_id_list	= '601839' -- Comma Separated Customer ID List - what customers to include  
	,@generator_id_list	= '' -- Comma Separated Generator ID List - what generators to include  
	,@approval_code		= '' -- Approval Code  
	,@invoice_code_list	= '' -- Invoice Code  
	,@manifest			= '' -- Manfiest Code  
	,@invoice_start_date		= '1/1/2015'
	,@invoice_end_date			= '12/31/2020'
	,@description		= '' -- Description search field
	,@po_release			= ''
	,@user_code = 'jonathan'
	,@permission_id=199

	
History:  
07/02/2021 JPB - Copied to sp_hub_billing_summary from sp_cor_billing_summary and customized

********************* */  


SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

/*
-- debugging
declare
	@customer_id_list	varchar(max) = '',
	@generator_id_list	varchar(max) = '',
	@approval_code		varchar(max) = '',
	@invoice_code_list	varchar(max) = '',
	@manifest				varchar(max) = '',
	@invoice_start_date			varchar(20) = '1/1/2021',
	@invoice_end_date				varchar(20) = '8/1/2021',
	@description		varchar(100) = '',
	@po_release			varchar(100) = '',
	@customer_type_list varchar(max) = ''
	, @user_code		varchar(20) = 'jonathan'
	, @permission_id int	= 199
	, @debug int = 1

*/

drop table if exists #Secured_Customer
drop table if exists #profit_center_filter
drop table if exists #customer_id_list
drop table if exists #generator_id_list
drop table if exists #invoice_code_list
drop table if exists #Approval
drop table if exists #Manifest
drop table if exists #Description
drop table if exists #POR


declare
	@i_customer_id_list	varchar(max) = isnull(@customer_id_list, ''), -- Comma Separated Customer ID List - what customers to include  
	@i_generator_id_list	varchar(max) = isnull(@generator_id_list, ''), -- Comma Separated Generator ID List - what generators to include  
	@i_approval_code		varchar(max) = isnull(@approval_code, ''), -- Approval Code  
	@i_invoice_code_list	varchar(max) = isnull(@invoice_code_list, ''), -- Invoice Code  
	@i_manifest				varchar(max) = isnull(@manifest, ''), -- Manfiest Code  
	@i_default_start_date	varchar(20) = convert(date, dateadd(m, -6, getdate())),
	@i_default_end_date		varchar(20) = convert(date, getdate()),  -- End Date  
	@i_start_date			varchar(20) = isnull(@invoice_start_date, ''),
	@i_end_date				varchar(20) = isnull(@invoice_end_date, ''),
	@i_description		varchar(100) = isnull(@description, ''), -- Description search field
	@i_po_release			varchar(100) = isnull(@po_release,'') -- PO, Release search field
	, @i_starttime	datetime = getdate()
	, @i_lasttime	datetime = getdate()
	, @i_customer_type_list varchar(max) = isnull(@customer_type_list, '')
	, @i_debug		int = isnull(@debug, 0)
	
SELECT DISTINCT customer_id INTO #Secured_Customer
	FROM SecuredCustomer sc  (nolock) WHERE sc.user_code = @user_code
	and sc.permission_id = @permission_id		
	
create table #profit_center_filter (
	company_id		int, 
	profit_ctr_id	int
)	

INSERT #profit_center_filter
SELECT DISTINCT
		secured_copc.company_id
       ,secured_copc.profit_ctr_id
FROM   SecuredProfitCenter secured_copc (nolock)
WHERE  secured_copc.permission_id = @permission_id
       AND secured_copc.user_code = @user_code 

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


	declare @customertype table (
		customer_type	varchar(20)
	)
	if @customer_type_list <> ''
	insert @customertype
	select row from dbo.fn_splitxsvtext(',', 1, @customer_type_list)
	where row is not null


-- HUB conversion of sp_cor_billing_summary: 
-- Can't use ContactCOR* tables
-- must integrate #Secured_Customer and #profit_center_filter views


declare @foo table (
	receipt_id	int
	, company_id	int
	, profit_ctr_id	int
	, trans_source	char(1)
)
insert @foo
select b.receipt_id, b.company_id, b.profit_ctr_id, b.trans_source
from Billing b (nolock)
join #Secured_Customer sc on b.customer_id = sc.customer_id
join #profit_center_filter pcf on b.company_id = pcf.company_id and b.profit_ctr_id = pcf.profit_ctr_id
WHERE 1=1
and b.invoice_date >= @i_start_date
and b.invoice_date <= @i_end_date
and b.status_code = 'I'
and (
	@i_customer_id_list = ''
	or
	b.customer_id in (select customer_id from #customer_id_list)
)	
and (
	@i_generator_id_list = ''
	or
	b.generator_id in (select generator_id from #generator_id_list)
)	
and (
	@i_customer_type_list = ''
	or
	b.customer_id in (select customer_id from customer cust (nolock) join @customertype ct on cust.customer_type = ct.customer_type)
)

-- Just univar, no date range, 2:09, 140,152
-- All, 2021 YTD: 513,353... 1s.


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
	SELECT 
	c.cust_name
	, b.customer_id
	, c.customer_type
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
	, c.customer_type
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
	, c.customer_type
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
	, c.customer_type
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
	, c.customer_type
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


	ORDER BY 
	c.cust_name
	, b.customer_id
	, b.invoice_date
	, b.invoice_code
	-- , surcharge_tax_type
	, b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.line_id
	, b.price_id
	, record_type
	, description

if @i_debug > 0 select 'Completed', datediff(ms, @i_lasttime, getdate()) as step_ms, datediff(ms, @i_starttime, getdate()) as total_ms 
set @i_lasttime = getdate()


END

GO

Grant execute on sp_hub_billing_summary to eqweb
go
Grant execute on sp_hub_billing_summary to eqai
go
