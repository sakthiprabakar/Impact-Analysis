
CREATE PROCEDURE sp_reports_manifest_lookup2
	@debug				int, 			   -- 0 or 1 for no debug/debug mode
	@manifest_list	   text,	         -- Comma Separated Customer ID List - what customers to include
	@contact_id			varchar(100)	-- Contact_id
AS
/****************************************************************************************************
sp_reports_manifest_lookup2:

Returns the data for Manifest Lookups

sp_reports_manifest_lookup2 0, '004021631JJK', '0'
sp_reports_manifest_lookup2 0, '002854921JJK', '0'
sp_reports_manifest_lookup2 0, '003788882JJK', '0'
sp_reports_manifest_lookup2 0, '000550580JJK,001669218FLE', '100762'


-- Returns 1 if only viewing Manifest scans.
-- Returns 2 if viewing Manifest AND secondary manifest
sp_reports_manifest_lookup2 0, '000384562GBF', 100913
sp_reports_manifest_lookup2 0, '000384562GBF', 100913

sp_reports_manifest_lookup2 0, '004021793JJK, 004021793JJK, 004021631JJK', '0'

sp_reports_manifest_lookup2 0, '004021793JJK', '0'
sp_reports_manifest_lookup2 0, '004021631JJK', '100913'
sp_reports_manifest_lookup2 0, '004021631JJK', '10913'
sp_reports_manifest_lookup2 0, '004021699JJK', '0'
sp_reports_manifest_lookup2 0, '000037404UIS', '0'
sp_reports_manifest_lookup2 0, '004021706JJK', '0'

sp_reports_manifest_lookup2 0, '004787847JJK', '0'



LOAD TO PLT_AI*

05/08/2008 JPB	Created
06/06/2008 JPB Modified to select where document_type = Manifest OR Secondary Manifest
09/23/2009 JPB Modified to use plt_ai, not plt_rpt

****************************************************************************************************/

	SET NOCOUNT ON
	SET ANSI_WARNINGS OFF
	
	DECLARE
		@custCount 		INT,
		@genCount 		INT,
		@icontact_id	INT,
		@getdate 		DATETIME

-- Set defaults
   IF ISNULL(@contact_id, '') = '' SET @contact_id = '0'
   SELECT @getdate = GETDATE(), @icontact_id = CONVERT(INT, @contact_id)

-- Handle text inputs into temp tables
	CREATE TABLE #Manifest_list (manifest VARCHAR(15))
	CREATE INDEX idx1 ON #Manifest_list (manifest)
	INSERT #Manifest_list SELECT row from dbo.fn_SplitXsvText(',', 0, @manifest_list) WHERE ISNULL(row, '') <> ''

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
		(select count(*) from #Manifest_list)
		= 0 RETURN


	IF @icontact_id > 0
		IF @custCount <= 0 and @genCount <= 0
			RETURN

	create table #scan(
		image_id int,
		document_source varchar(30)
	)

	insert #scan
	select image_id, document_source
	from #manifest_list ml
	inner join plt_image.dbo.scan s with (nolock)
		on ml.manifest = case document_source 
			when 'workorder' then s.document_name
			when 'receipt' then s.manifest
			end

	if @debug >= 10 select '#scan' as table_name, * from #scan
	
	if (select count(*) from #scan) = 0 RETURN
	
	create table #results (
		company_id int,
		profit_ctr_id int,
		receipt_id int,
		image_id int,
		file_type varchar(20),
		document_name varchar(50),
		document_source varchar(30),
		manifest varchar(15),
		page_number int
	)

	if exists (select 1 from #scan where document_source = 'receipt')
		insert #results
		select distinct
			s.company_id,
			s.profit_ctr_id,
			s.receipt_id,
			s.image_id, 
			s.file_type, 
			s.document_name, 
			s.document_source,
			s.manifest, 
			s.page_number
		from #scan ts
		inner join plt_image.dbo.scan s with (nolock)
			on ts.image_id = s.image_id
		inner join receipt r with (nolock)
			on s.receipt_id = r.receipt_id
			and s.company_id = r.company_id
			and s.profit_ctr_id = r.profit_ctr_id
			and s.document_source = 'receipt'
		inner join (
			select scan.manifest, isnull(scan.page_number, scan.image_id) as page_number, max(scan.date_added) as date_added
			from #scan ts2
			inner join plt_image.dbo.scan scan with (nolock)
				on ts2.image_id = scan.image_id
			inner join receipt r with (nolock)
				on scan.receipt_id = r.receipt_id
				and scan.company_id = r.company_id
				and scan.profit_ctr_id = r.profit_ctr_id
			where scan.type_id in (
				select type_id from plt_image..ScanDocumentType with (nolock)
				where document_type IN ('Manifest', 'Secondary Manifest')
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

	if exists (select 1 from #scan where document_source = 'workorder')
		insert #results
		select distinct
			s.company_id,
			s.profit_ctr_id,
			s.workorder_id,
			s.image_id, 
			s.file_type, 
			s.document_name, 
			s.document_source,
			s.manifest, 
			s.page_number
		from #scan ts
		inner join plt_image.dbo.scan s  with (nolock)
			on ts.image_id = s.image_id
		inner join workorderheader w with (nolock)
			on s.workorder_id = w.workorder_id
			and s.company_id = w.company_id
			and s.profit_ctr_id = w.profit_ctr_id
		inner join (
			select scan.document_name, isnull(scan.page_number, scan.image_id) as page_number, max(scan.date_added) as date_added
			from #scan ts2 
			inner join plt_image..scan scan with (nolock)
				on ts2.image_id = scan.image_id
			inner join workorderheader w with (nolock)
				on scan.workorder_id = w.workorder_id
				and scan.company_id = w.company_id
				and scan.profit_ctr_id = w.profit_ctr_id
			where 
				scan.document_name in (select manifest from #manifest_list)
				and scan.type_id in (
					select type_id from plt_image..ScanDocumentType with (nolock)
					where document_type IN ('Manifest', 'Secondary Manifest')
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
				select manifest from #results where manifest = s.document_name and document_source = 'receipt'
			)

	if @debug >= 10 select '#results' as table_name, * from #results

	set nocount off

	select distinct 
		*, 
		isnull(manifest, document_name), 
		(select count(distinct isnull(manifest, document_name)) from #results) as record_count 
	from #results 
	order by isnull(manifest, document_name), page_number
   	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_manifest_lookup2] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_manifest_lookup2] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_manifest_lookup2] TO [EQAI]
    AS [dbo];

