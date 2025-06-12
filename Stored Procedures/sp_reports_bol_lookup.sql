CREATE PROCEDURE [dbo].[sp_reports_bol_lookup]
	@debug				int, 					-- 0 or 1 for no debug/debug mode
	@bol_list	   varchar(max),	        -- Comma Separated Customer ID List - what customers to include
	@approval_code		varchar(max) = null,	-- CSV Approval code list
	@generator_id_list	varchar(max) = null,	-- CSV list of generator id's
	@start_date			datetime = null,
	@end_date			datetime = null,
	@contact_id			varchar(100)			-- Contact_id
AS
/****************************************************************************************************
sp_reports_bol_lookup:

Returns the data for bol Lookups

sp_reports_bol_lookup 0, '020107, 051707-397', null, null, null, null, '0'
sp_reports_bol_lookup 2, '004021631JJK', '', '', '', '', '0' 
sp_reports_bol_lookup 0, '', 'D118098MDI', null, null, null, '0'
sp_reports_bol_lookup 0, '', 'D118098MDI', null, null, '9/1/2011', '0'
sp_reports_bol_lookup 0, '', 'D118098MDI', null, '9/1/2011', null, '0'
sp_reports_bol_lookup 2, '', 'ACIDLIQ', null, null, null, '10913'
sp_reports_bol_lookup 0, '', '', '', '9/1/2011', '9/10/2011', '0'
sp_reports_bol_lookup 0, '', '', '', '', 'MIK773817382', '0'
sp_reports_bol_lookup 0, '', '', 'MIK773817382', '', '', '10913'
sp_reports_bol_lookup 0, '', '', 'MIK773817382', '', '', '100913'



LOAD TO PLT_AI*

11/09/2012 JPB	Created from copy of sp_reports_bol_lookup

****************************************************************************************************/

	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF
	
	DECLARE
		@custCount 		INT,
		@genCount 		INT,
		@icontact_id	INT,
		@getdate 		DATETIME
		

	set @bol_list = replace(isnull(@bol_list, ''), ' ', '')
	set @approval_code = replace(isnull(@approval_code, ''), ' ', '')
	set @generator_id_list = replace(isnull(@generator_id_list, ''), ' ', '')

-- Set defaults
   IF ISNULL(@contact_id, '') = '' SET @contact_id = '0'
   SELECT @getdate = GETDATE(), @icontact_id = CONVERT(INT, @contact_id)

-- Handle text inputs into temp tables
	CREATE TABLE #bol_list (bol VARCHAR(15))
	CREATE INDEX idx1 ON #bol_list (bol)
	INSERT #bol_list SELECT row from dbo.fn_SplitXsvText(',', 1, @bol_list) WHERE ISNULL(row, '') <> ''

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
	if @custCount + 
		@genCount + 
		(select count(*) from #bol_list) +
		(select count(*) from #generator) +
		(select count(*) from #ApprovalCode)
		= 0 RETURN

	IF @icontact_id > 0
		IF @custCount <= 0 and @genCount <= 0
			RETURN

	create table #source (image_id int, document_source varchar(20), bol varchar(20), receipt_id int, company_id int, profit_ctr_id int)

	declare @sql varchar(max)
	
	set @sql = '
	insert #source 
	select s.image_id, s.document_source, s.manifest, s.receipt_id, s.company_id, s.profit_ctr_id
	from plt_image..scan s inner join receipt r on s.receipt_id = r.receipt_id and s.company_id = r.company_id and s.profit_ctr_id = r.profit_ctr_id
	where s.document_source = ''receipt''
	'
	if isnull(@start_date, '1/1/1900') <> '1/1/1900' and @start_date > '1/1/1900' set @sql = @sql + ' and r.receipt_date >= ''' + convert(varchar(20), @start_date) + ''' '
	if isnull(@end_date  , '1/1/1900') <> '1/1/1900' and @end_date   > '1/1/1901'  set @sql = @sql + ' and r.receipt_date <= ''' + convert(varchar(20), @end_date) + ''' '
	if (select count(*) from #bol_list) > 0 set @sql = @sql + ' and s.manifest in (select bol from #bol_list) '
	if (select count(*) from #generator) > 0 set @sql = @sql + ' and s.generator_id in (select generator_id from #generator) '
	if (select count(*) from #ApprovalCode) > 0 set @sql = @sql + ' and r.approval_code in (select approval_code from #ApprovalCode) '
	IF @icontact_id > 0 set @sql = @sql + ' and exists (select 1 from contactxref cxr left outer join customergenerator cg on cxr.customer_id = cg.customer_id and cxr.type = ''C'' where cxr.contact_id = ' + @contact_id + ' and (cxr.customer_id  = r.customer_id or cxr.generator_id = s.generator_id or cg.generator_id = s.generator_id)) '

	set @sql = @sql + '
	and s.type_id in (select type_id from plt_image..ScanDocumentType with (nolock) where document_type IN (''BOL''))
	and s.status = ''A'' and s.view_on_web = ''T''
	'

     IF @debug >= 1 select @sql sql
	
	exec(@sql)
	
	set @sql = '
	insert #source 
	select s.image_id, s.document_source, s.manifest, s.workorder_id, s.company_id, s.profit_ctr_id
	from plt_image..scan s inner join workorderheader woh on s.workorder_id = woh.workorder_id and s.company_id = woh.company_id and s.profit_ctr_id = woh.profit_ctr_id
	inner join workorderdetail wod on wod.workorder_id = woh.workorder_id and wod.company_id = woh.company_id and wod.profit_ctr_id = woh.profit_ctr_id
	where 1=1
	'
	if isnull(@start_date, '1/1/1900') <> '1/1/1900' and @start_date > '1/1/1900' set @sql = @sql + ' and woh.start_date >= ''' + convert(varchar(20), @start_date) + ''' '
	if isnull(@end_date  , '1/1/1900') <> '1/1/1900' and @end_date   > '1/1/1901'  set @sql = @sql + ' and woh.end_date <= ''' + convert(varchar(20), @end_date) + ''' '
	if (select count(*) from #bol_list) > 0 set @sql = @sql + ' and s.manifest in (select bol from #bol_list) '
	if (select count(*) from #generator) > 0 set @sql = @sql + ' and s.generator_id in (select generator_id from #generator) '
	if (select count(*) from #ApprovalCode) > 0 set @sql = @sql + ' and wod.tsdf_approval_code in (select approval_code from #ApprovalCode) '
	IF @icontact_id > 0 set @sql = @sql + ' and exists (select 1 from contactxref cxr left outer join customergenerator cg on cxr.customer_id = cg.customer_id and cxr.type = ''C'' where cxr.contact_id = ' + @contact_id + ' and (cxr.customer_id  = s.customer_id or cxr.generator_id = s.generator_id or cg.generator_id = s.generator_id)) '

	set @sql = @sql + '
	and s.type_id in (select type_id from plt_image..ScanDocumentType with (nolock) where document_type IN (''BOL''))
	and s.status = ''A'' and s.view_on_web = ''T''
	'

	 IF @debug >= 1 select @sql sql	

	exec(@sql)


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
		bol varchar(15),
		page_number int
	)

	if exists (select 1 from #source where document_source = 'receipt')
		insert #results
		select distinct
			s.company_id,
			s.profit_ctr_id,
			s.receipt_id,
			dbo.fn_billing_record_service_date(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id, 'R') as pickup_date,
			s.generator_id,
			s.customer_id,
			s.image_id, 
			s.file_type, 
			s.document_name, 
			s.document_source,
			s.manifest, 
			s.page_number
		from #source ts
		inner join plt_image.dbo.scan s with (nolock)
			on ts.image_id = s.image_id
		inner join receipt r with (nolock)
			on s.receipt_id = r.receipt_id
			and s.company_id = r.company_id
			and s.profit_ctr_id = r.profit_ctr_id
			and s.document_source = 'receipt'
		inner join (
			select scan.manifest, isnull(scan.page_number, scan.image_id) as page_number, max(scan.date_added) as date_added
			from #source ts2
			inner join plt_image.dbo.scan scan with (nolock)
				on ts2.image_id = scan.image_id
			inner join receipt r with (nolock)
				on scan.receipt_id = r.receipt_id
				and scan.company_id = r.company_id
				and scan.profit_ctr_id = r.profit_ctr_id
			where scan.type_id in (
				select type_id from plt_image..ScanDocumentType with (nolock)
				where document_type IN ('BOL')
			)
			and scan.status = 'A'
			and scan.view_on_web = 'T'
			group by scan.manifest, isnull(scan.page_number, scan.image_id)
		) mostrecent
			on mostrecent.manifest = s.manifest 
			and mostrecent.date_added = s.date_added
		where 
			s.status = 'A'
			and s.view_on_web = 'T'
			and (
				@icontact_id = 0 
				OR 
				(
					@icontact_id <> 0 
					AND dbo.fn_web_receipt_accesscheck(@icontact_id, r.company_id, r.profit_ctr_id, r.receipt_id) <> 'X'
				)
			)

	if exists (select 1 from #source where document_source = 'workorder')
		insert #results
		select distinct
			s.company_id,
			s.profit_ctr_id,
			s.workorder_id,
			dbo.fn_billing_record_service_date(s.company_id, s.profit_ctr_id, s.workorder_id, null, 'W') as pickup_date,
			s.generator_id,
			s.customer_id,
			s.image_id, 
			s.file_type, 
			s.document_name, 
			s.document_source,
			s.manifest, 
			s.page_number
		from #source ts
		inner join plt_image.dbo.scan s  with (nolock)
			on ts.image_id = s.image_id
		inner join workorderheader w with (nolock)
			on s.workorder_id = w.workorder_id
			and s.company_id = w.company_id
			and s.profit_ctr_id = w.profit_ctr_id
		inner join (
			select scan.document_name, isnull(scan.page_number, scan.image_id) as page_number, max(scan.date_added) as date_added
			from #source ts2 
			inner join plt_image..scan scan with (nolock)
				on ts2.image_id = scan.image_id
			inner join workorderheader w with (nolock)
				on scan.workorder_id = w.workorder_id
				and scan.company_id = w.company_id
				and scan.profit_ctr_id = w.profit_ctr_id
			where 
				scan.document_name in (select bol from #bol_list)
				and scan.type_id in (
					select type_id from plt_image..ScanDocumentType with (nolock)
					where document_type IN ('BOL')
				)
				and scan.status = 'A'
				and scan.view_on_web = 'T'
			group by scan.document_name, isnull(scan.page_number, scan.image_id)
		) mostrecent 
			on mostrecent.document_name = s.document_name 
			and mostrecent.date_added = s.date_added
		where 
			s.status = 'A'
			and s.view_on_web = 'T'
			and (
				@icontact_id = 0 
				OR 
				(
					@icontact_id <> 0 
					AND dbo.fn_web_workorder_accesscheck(@icontact_id, w.company_id, w.profit_ctr_id, w.workorder_id) <> 'X'
				)
			)
			and not exists (
				select bol from #results where bol = s.document_name and document_source = 'receipt'
			)

	if @debug >= 10 select '#results' as table_name, * from #results

	set nocount off

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
		, r.bol
		, r.page_number
		, isnull(bol, document_name)
		, (select count(distinct isnull(bol, document_name)) from #results) as record_cnt 
	from #results r
		left outer join customer c on r.customer_id = c.customer_id 
		left outer join generator g on r.generator_id = g.generator_id
	order by isnull(bol, document_name), page_number
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_bol_lookup] TO [EQAI]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_bol_lookup] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_bol_lookup] TO [COR_USER]
    AS [dbo];

GO

