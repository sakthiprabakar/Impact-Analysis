CREATE PROCEDURE [sp_reports_manifest_lookup_prod]
	@debug				int, 					-- 0 or 1 for no debug/debug mode
	@manifest_list	   varchar(max),	        -- Comma Separated Customer ID List - what customers to include
	@approval_code		varchar(max) = null,	-- CSV Approval code list
	@generator_id_list	varchar(max) = null,	-- CSV list of generator id's
	@start_date			datetime = null,
	@end_date			datetime = null,
	@contact_id			varchar(100)			-- Contact_id
AS
/****************************************************************************************************
sp_reports_manifest_lookup:

Returns the data for Manifest Lookups

LOAD TO PLT_AI

05/08/2008 JPB	Created
06/06/2008 JPB Modified to select where document_type = Manifest OR Secondary Manifest
09/23/2009 JPB Modified to use plt_ai, not plt_rpt
03/23/2010 JPB Rewritten for speed, proper multipage return
07/05/2012 JPB	Added @approval_code, @start_date, @end_date, @epa_id inputs
08/30/2012	JPB	Converted to take a string of generator id's instead of an epa_id input
07/16/2014 JPB	Converted ScanDocumentType id lookups from list 'Manifest', 'Secondary Manifest'
				to LIKE '%Manifest%' to handle addition of 'Pickup Manifest' and future.
04/09/2015	JPB	Revised for speed, also fixed a bug in the last workorder select that would eliminate
				workorder results unless they matched an input manifest list - no input list left them all out.  Doh.
01/07/2016	JPB	Addressing a bad data problem: Receipt scans that are input via the EQAI Trip screen don't populate the Scan.Manifest field
				The "mostrecent" part of this SP then fails to match Receipt/Scan data and drops those scans out of results.
				The work order version of that select already knew this - was already using only document_name.
				An EQAI/data fix would be best, but faster to use isnull(manifest,document_name) here.
				

Suggested Missing Index Details
The Query Processor estimates that implementing the following index could improve the query cost by 59.4624%.

use PLT_AI
CREATE NONCLUSTERED INDEX [idx_receipt_trans_mode_date]
ON [dbo].[Receipt] ([trans_mode],[receipt_date])
INCLUDE ([company_id],[profit_ctr_id],[receipt_id],[manifest],[customer_id],[generator_id])

USE [Plt_Image]
CREATE NONCLUSTERED INDEX [idx_scan_source_status]
ON [dbo].[Scan] ([document_source],[status],[view_on_web])
INCLUDE ([company_id],[profit_ctr_id],[image_id],[type_id],[document_name],[manifest],[workorder_id])


Old vs New:

	exec sp_reports_manifest_lookup 1, '', '', '', '3/1/2015', '3/15/2015', '183446'
	-- 1190 rows, 1:35s

	exec sp_reports_manifest_lookup 1, '', '', '', '1/1/2015', '3/15/2015', '100913'
	-- 12039 rows, 1:34 -- no indexes.

****************************************************************************************************/

-- Input setup:

	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
	
	DECLARE
		@custCount 		INT,
		@genCount 		INT,
		@icontact_id	INT,
		@getdate 		DATETIME,
		@timer_start	datetime = getdate(),
		@last_step		datetime = getdate()

	set @manifest_list = replace(isnull(@manifest_list, ''), ' ', '')
	set @approval_code = replace(isnull(@approval_code, ''), ' ', '')
	set @generator_id_list = replace(isnull(@generator_id_list, ''), ' ', '')

-- Set defaults
   IF ISNULL(@contact_id, '') = '' SET @contact_id = '0'
   SELECT @getdate = GETDATE(), @icontact_id = CONVERT(INT, @contact_id)

-- end date fix:
	if @end_date is not null and datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999
	
-- Handle text inputs into temp tables
	CREATE TABLE #Manifest_list (manifest VARCHAR(15))
	CREATE INDEX idx1 ON #Manifest_list (manifest)
	INSERT #Manifest_list SELECT row from dbo.fn_SplitXsvText(',', 1, @manifest_list) WHERE ISNULL(row, '') <> ''

	CREATE TABLE #generator (generator_id int)
	CREATE INDEX idx1 ON #generator (generator_id)
	INSERT #generator SELECT convert(int, row) from dbo.fn_SplitXsvText(',', 1, @generator_id_list) WHERE ISNULL(row, '') <> ''

	CREATE TABLE #ApprovalCode (approval_code varchar(20))
	CREATE INDEX idx1 ON #ApprovalCode (approval_code)
	INSERT #ApprovalCode SELECT row from dbo.fn_SplitXsvText(',', 1, @approval_code) WHERE ISNULL(row, '') <> ''

-- figure out if this user has inherent access to customers
    SELECT @custCount = 0, @genCount = 0
	IF @icontact_id > 0
	BEGIN
		SET @icontact_id = convert(int, @contact_id)
		select @custCount = count(customer_id) 
			from ContactXRef cxr with (nolock)
			Where cxr.contact_id = @icontact_id
			AND cxr.status = 'A' and cxr.web_access = 'A'
			
		select @genCount = (
			select count(generator_id) 
			from ContactXRef cxr with (nolock)
			Where cxr.contact_id = @icontact_id
			AND cxr.status = 'A' and cxr.web_access = 'A' 
			) + ( 
			Select count(cg.generator_id) 
			from ContactXRef cxr with (nolock)
			inner join Customer c with (nolock)
				on cxr.customer_id = c.customer_id
				and cxr.type = 'C'
				and c.generator_flag = 'T'
				AND cxr.status = 'A'
				AND cxr.web_access = 'A'
			inner join CustomerGenerator cg with (nolock)
				on c.customer_id = cg.customer_id
			Where cxr.contact_id = @icontact_id
		)	
	END
	ELSE -- For Associates:
	BEGIN
		set @custCount = 1
		set @genCount = 1
	END

    IF @debug >= 1 PRINT '@custCount:  ' + convert(varchar(20), @custCount)
    IF @debug >= 1 PRINT '@genCount:  ' + convert(varchar(20), @genCount)

-- abort if there's nothing possible to see
	if case when @icontact_id > 0 then @custCount else 0 end + 
		case when @icontact_id > 0 then @genCount else 0 end + 
		(select count(*) from #Manifest_list) +
		(select count(*) from #generator) +
		(select count(*) from #ApprovalCode)
		= 0 RETURN

	IF @icontact_id > 0
		IF @custCount <= 0 and @genCount <= 0
			RETURN

	if @debug >= 1 select datediff(ms, @timer_start, getdate()) as total_elapsed_time, datediff(ms, @last_step, getdate()) as last_step_time, 'Setup' as last_step_desc
	set @last_step = getdate()

-- Setup is finished.  On to work:

	-- #Source table to hold info about the rows that contain the manifest info.
	create table #source (company_id int, profit_ctr_id int, document_source varchar(20), receipt_id int, line_id int, customer_id int, generator_id int, manifest varchar(20))

	declare @sql varchar(max)
	
	set @sql = '
	insert #source (company_id, profit_ctr_id, document_source, receipt_id, line_id, customer_id, generator_id, manifest)
	select distinct r.company_id, r.profit_ctr_id, ''receipt'', r.receipt_id, r.line_id, r.customer_id, r.generator_id, r.manifest
	from receipt r (nolock) 
	where 1=1 and r.trans_mode = ''i''
	'

	if isnull(@start_date, '1/1/1900') <> '1/1/1900' and @start_date > '1/1/1900' set @sql = @sql + ' and r.receipt_date >= ''' + convert(varchar(20), @start_date) + ''' '
	if isnull(@end_date  , '1/1/1900') <> '1/1/1900' and @end_date   > '1/1/1901'  set @sql = @sql + ' and r.receipt_date <= ''' + convert(varchar(20), @end_date) + ''' '
	if (select count(*) from #manifest_list) > 0 set @sql = @sql + ' and manifest in (select manifest from #manifest_list) '
	if (select count(*) from #generator) > 0 set @sql = @sql + ' and r.generator_id in (select generator_id from #generator) '
	if (select count(*) from #ApprovalCode) > 0 set @sql = @sql + ' and r.approval_code in (select approval_code from #ApprovalCode) '
	
	-- 4/9/2015 - Rewrote this to use UNION not OR.  Much faster this way.
	IF @icontact_id > 0 set @sql = @sql + ' and exists (
		select 1 from contactxref cxr (nolock) where cxr.contact_id = ' + @contact_id + ' and cxr.type = ''C'' and cxr.status = ''A'' and cxr.web_access = ''A''
		and cxr.customer_id  = r.customer_id
		union
		select 1 from contactxref cxr (nolock) where cxr.contact_id = ' + @contact_id + ' and cxr.type = ''G'' and cxr.status = ''A'' and cxr.web_access = ''A''
		and cxr.generator_id = r.generator_id 
		union
		select 1 from contactxref cxr (nolock) join customergenerator cg (nolock) on cxr.customer_id = cg.customer_id where cxr.contact_id = ' + @contact_id + ' and cxr.type = ''C'' and cxr.status = ''A'' and cxr.web_access = ''A''
		and cg.generator_id = r.generator_id) 
	'
	

    IF @debug >= 1 select @sql sql
	
	exec(@sql)

	if @debug >= 1 select datediff(ms, @timer_start, getdate()) as total_elapsed_time, datediff(ms, @last_step, getdate()) as last_step_time, 'Receipt #source-ing' as last_step_desc
	set @last_step = getdate()
	
	set @sql = '
	insert #source (company_id, profit_ctr_id, document_source, receipt_id, line_id, customer_id, generator_id, manifest)
	select distinct wom.company_id, wom.profit_ctr_id, ''workorder'', wom.workorder_id, null, woh.customer_id, woh.generator_id, wom.manifest
	from workordermanifest wom (nolock) 
	inner join workorderheader woh (nolock) on wom.workorder_id = woh.workorder_id and wom.company_id = woh.company_id and wom.profit_ctr_id = woh.profit_ctr_id
	inner join workorderdetail wod (nolock) on wod.workorder_id = woh.workorder_id and wod.company_id = woh.company_id and wod.profit_ctr_id = woh.profit_ctr_id and wod.manifest = wom.manifest
	where 1=1
	'
	
	if isnull(@start_date, '1/1/1900') <> '1/1/1900' and @start_date > '1/1/1900' set @sql = @sql + ' and woh.start_date >= ''' + convert(varchar(20), @start_date) + ''' '
	if isnull(@end_date  , '1/1/1900') <> '1/1/1900' and @end_date   > '1/1/1901'  set @sql = @sql + ' and woh.end_date <= ''' + convert(varchar(20), @end_date) + ''' '
	if (select count(*) from #manifest_list) > 0 set @sql = @sql + ' and wom.manifest in (select manifest from #manifest_list) '
	if (select count(*) from #generator) > 0 set @sql = @sql + ' and woh.generator_id in (select generator_id from #generator) '
	if (select count(*) from #ApprovalCode) > 0 set @sql = @sql + ' and wod.tsdf_approval_code in (select approval_code from #ApprovalCode) '

	-- 4/9/2015 - Rewrote this to use UNION not OR.  Much faster this way.
	IF @icontact_id > 0 set @sql = @sql + ' and exists (
		select 1 from contactxref cxr (nolock) where cxr.contact_id = ' + @contact_id + ' and cxr.type = ''C'' and cxr.status = ''A'' and cxr.web_access = ''A''
		and cxr.customer_id  = woh.customer_id
		union
		select 1 from contactxref cxr (nolock) where cxr.contact_id = ' + @contact_id + ' and cxr.type = ''G'' and cxr.status = ''A'' and cxr.web_access = ''A''
		and cxr.generator_id = woh.generator_id 
		union
		select 1 from contactxref cxr (nolock) join customergenerator cg (nolock) on cxr.customer_id = cg.customer_id where cxr.contact_id = ' + @contact_id + ' and cxr.type = ''C'' and cxr.status = ''A'' and cxr.web_access = ''A''
		and cg.generator_id = woh.generator_id) 
	'
	
	IF @debug >= 1 select @sql sql	

	exec(@sql)

	if @debug >= 1 select datediff(ms, @timer_start, getdate()) as total_elapsed_time, datediff(ms, @last_step, getdate()) as last_step_time, 'Work Order #source-ing' as last_step_desc
	set @last_step = getdate()
	
	if (select count(*) from #source) = 0 return

	-- 4/9/2015 Rewrote how #scan works - contains all of #source + image id's now, to eliminate having to join back to big tables for little details later.
	select top 1 *, convert(int, null) as image_id into #scan from #source where 1=0

	-- Gather receipt-based manifest images
	insert #scan
	select src.*, s.image_id
	from #source src
	inner join plt_image..scan s (nolock) 
	on src.document_source = s.document_source
	and src.receipt_id = s.receipt_id
	and src.company_id = s.company_id
	and src.profit_ctr_id = s.profit_ctr_id
	and src.manifest = case when isnull(s.manifest, '') = '' then isnull(s.document_name, '') else isnull(s.manifest, '') end
	and s.type_id in (select type_id from plt_image..ScanDocumentType with (nolock) where document_type like '%Manifest%')
	where src.document_source = 'receipt'
	and s.status = 'A' and s.view_on_web = 'T'

	if @debug >= 1 select datediff(ms, @timer_start, getdate()) as total_elapsed_time, datediff(ms, @last_step, getdate()) as last_step_time, 'Receipt #scan-ing' as last_step_desc
	set @last_step = getdate()
	
	-- Gather work order-based manifest images - exclude any already found by receipt, because the receipt instance is more "official"
	insert #scan
	select src.*, s.image_id
	from #source src
	inner join plt_image..scan s (nolock) 
	on src.document_source = s.document_source
	and src.receipt_id = s.workorder_id
	and src.company_id = s.company_id
	and src.profit_ctr_id = s.profit_ctr_id
	and src.manifest = case when isnull(s.manifest, '') = '' then isnull(s.document_name, '') else isnull(s.manifest, '') end
	and s.type_id in (select type_id from plt_image..ScanDocumentType with (nolock) where document_type like '%Manifest%')
	where src.document_source = 'workorder'
	and s.status = 'A' and s.view_on_web = 'T'
	and not exists (select 1 from #scan where #scan.manifest = src.manifest)

	if @debug >= 1 select datediff(ms, @timer_start, getdate()) as total_elapsed_time, datediff(ms, @last_step, getdate()) as last_step_time, 'Work Order #scan-ing' as last_step_desc
	set @last_step = getdate()

	if @debug >= 10 select '#scan' as table_name, * from #scan
	
	if (select count(*) from #scan) = 0 RETURN

	-- Build a results table from the #scan data	
	create table #results (
		company_id int,
		profit_ctr_id int,
		receipt_id int,
		pickup_date datetime,
		generator_id int,
		customer_id int,
		image_id int,
		file_type varchar(20),
		document_name varchar(50),
		document_source varchar(30),
		manifest varchar(15),
		page_number int
	)

	if exists (select 1 from #source where document_source = 'receipt')
		insert #results
		select distinct
			ts.company_id,
			ts.profit_ctr_id,
			ts.receipt_id,
			dbo.fn_billing_record_service_date(ts.company_id, ts.profit_ctr_id, ts.receipt_id, ts.line_id, 'R') as pickup_date,
			ts.generator_id,
			ts.customer_id,
			ts.image_id, 
			s.file_type, 
			s.document_name, 
			ts.document_source,
			ts.manifest, 
			s.page_number
		from #scan ts
		inner join plt_image.dbo.scan s with (nolock)
			on ts.image_id = s.image_id
		inner join (
			-- Always find the most recently scanned copy of an image.
			select isnull(scan.manifest, scan.document_name) manifest, isnull(scan.page_number, scan.image_id) as page_number, max(scan.date_added) as date_added
			from #scan ts2
			inner join plt_image.dbo.scan scan with (nolock)
				on ts2.image_id = scan.image_id
			inner join receipt r with (nolock)
				on scan.receipt_id = r.receipt_id
				and scan.company_id = r.company_id
				and scan.profit_ctr_id = r.profit_ctr_id
			where scan.type_id in (
				select type_id from plt_image..ScanDocumentType with (nolock)
				where document_type like '%Manifest%'
			)
			and scan.status = 'A'
			and scan.view_on_web = 'T'
			group by isnull(scan.manifest, scan.document_name), isnull(scan.page_number, scan.image_id)
		) mostrecent
			on mostrecent.manifest = isnull(s.manifest, s.document_name)
			and mostrecent.date_added = s.date_added
		where 
			ts.image_id is not null
			and ts.document_source = 'receipt'
			and s.status = 'A'
			and s.view_on_web = 'T'
			-- 4/9/2015 No longer going to funky access functions - they made this really slow.  Plus the #source, then #scan data all originated from data pre-qualified by the contact relationship anyway.

	if @debug >= 1 select datediff(ms, @timer_start, getdate()) as total_elapsed_time, datediff(ms, @last_step, getdate()) as last_step_time, 'Receipt #Results collected' as last_step_desc
	set @last_step = getdate()

	if exists (select 1 from #scan where document_source = 'workorder')
		insert #results
		select distinct
			ts.company_id,
			ts.profit_ctr_id,
			ts.receipt_id workorder_id,
			dbo.fn_billing_record_service_date(ts.company_id, ts.profit_ctr_id, ts.receipt_id, null, 'W') as pickup_date,
			ts.generator_id,
			ts.customer_id,
			ts.image_id, 
			s.file_type, 
			s.document_name, 
			ts.document_source,
			ts.manifest, 
			s.page_number
		from #scan ts
		inner join plt_image.dbo.scan s  with (nolock)
			on ts.image_id = s.image_id
		inner join (
			-- Always find the most recently scanned copy of an image.
			select scan.document_name, isnull(scan.page_number, scan.image_id) as page_number, max(scan.date_added) as date_added
			from #scan ts2 
			inner join plt_image..scan scan with (nolock)
				on ts2.image_id = scan.image_id
			where 
				-- 4/9/2015 - removed a bad clause here that was eliminating query results unnecessarily.
				scan.type_id in (
					select type_id from plt_image..ScanDocumentType with (nolock)
					where document_type like '%Manifest%'
				)
				and scan.status = 'A'
				and scan.view_on_web = 'T'
			group by scan.document_name, isnull(scan.page_number, scan.image_id)
		) mostrecent 
			on mostrecent.document_name = s.document_name 
			and mostrecent.date_added = s.date_added
		where 
			ts.image_id is not null
			and ts.document_source = 'workorder'
			and s.status = 'A'
			and s.view_on_web = 'T'
			-- 4/9/2015 No longer going to funky access functions - they made this really slow.  Plus the #source, then #scan data all originated from data pre-qualified by the contact relationship anyway.
			and not exists (
				select manifest from #results where manifest = s.document_name and document_source = 'receipt'
			)

	if @debug >= 1 select datediff(ms, @timer_start, getdate()) as total_elapsed_time, datediff(ms, @last_step, getdate()) as last_step_time, 'Work Order #Results collected' as last_step_desc
	set @last_step = getdate()

	if @debug >= 10 select '#results' as table_name, * from #results

	set nocount off

	-- output:
	select distinct 
		r.customer_id
		, r.profit_ctr_id
		, r.receipt_id
		, r.pickup_date
		, r.generator_id
		, g.generator_name
		, g.epa_id
		, c.customer_id
		, c.cust_name
		, r.image_id
		, r.file_type
		, r.document_name
		, r.document_source
		, case when isnull(r.manifest, '') = '' then isnull(r.document_name, '') else isnull(r.manifest, '') end as manifest
		, r.page_number
		, isnull(manifest, document_name)
		, (select count(distinct isnull(manifest, document_name)) from #results) as record_cnt 
	from #results r
		left outer join customer c (nolock) on r.customer_id = c.customer_id 
		left outer join generator g (nolock) on r.generator_id = g.generator_id
	order by isnull(manifest, document_name), page_number

	if @debug >= 1 select datediff(ms, @timer_start, getdate()) as total_elapsed_time, datediff(ms, @last_step, getdate()) as last_step_time, 'final output' as last_step_desc
	set @last_step = getdate()
   	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_manifest_lookup_prod] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_manifest_lookup_prod] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_manifest_lookup_prod] TO [EQAI]
    AS [dbo];

