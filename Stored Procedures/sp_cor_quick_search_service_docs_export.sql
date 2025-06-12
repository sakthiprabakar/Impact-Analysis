-- drop proc if exists sp_cor_quick_search_service_docs_export
go

create proc sp_cor_quick_search_service_docs_export (
	@web_userid varchar(100) = ''
	, @start_date	datetime = null -- '1/1/2019' -- dateadd(yyyy, -5, getdate())
	, @end_date		datetime = null
	, @generator_id	int = null
	, @manifest		varchar(100) = null
	, @page				bigint = 1
	, @perpage			bigint = 20 
	, @customer_id_list varchar(max)=''
	, @generator_id_list varchar(max)=''
    , @export_images	int = 0 /* 0 (no) or 1 (yes): Export Images option */
	, @scan_type_id_list varchar(max) = ''
	, @image_id_list	varchar(max) = '' -- list of image_ids to export
    , @export_email	varchar(100) = ''
)
as
/* **************************************************************************
sp_cor_quick_search_service_docs_export

development of New Retail Tile "Quick Search Service Documents"
DO:16580

09/21/2021 - DO 19867 - Added upload_date to output

SELECT  * FROM    contact WHERE web_userid like '%amazon%'

Samples...

-- No search criteria = no results...
	sp_cor_quick_search_service_docs_export 
		@web_userid = 'AmazonWaste@Amazon.com'
		, @start_date	= null -- '1/1/2019' -- dateadd(yyyy, -5, getdate())
		, @end_date		= null
		, @generator_id	= null
		, @manifest		= null
		, @customer_id_list =''  
		, @generator_id_list ='' 

-- Will encounter multiple generators, so returns NO scan info, just the list of generators found.
-- The SP will only work when only 1 generator is in the result set.
	sp_cor_quick_search_service_docs_export 
		@web_userid = 'AmazonWaste@Amazon.com'
		, @start_date	= null -- '1/1/2019' -- dateadd(yyyy, -5, getdate())
		, @end_date		= null
		, @generator_id	= null
		, @manifest		= '0123'
		, @customer_id_list =''  
		, @generator_id_list ='' 


-- will encounter just 1 generator, so you get results:
	sp_cor_quick_search_service_docs_export 
		@web_userid = 'AmazonWaste@Amazon.com'
		, @start_date	= null -- '1/1/2019' -- dateadd(yyyy, -5, getdate())
		, @end_date		= null
		, @generator_id	= null
		, @manifest		= null
		, @customer_id_list =''  
		, @generator_id_list ='133799' 

Important Programming Notes!!:
	When there's NO manifest or generator search input, you get no results.  MUST search for something.

	Paging of results isn't implemented, that's on purpose.
	Reason: You can't tell when a page break would occur within the results of 1 service event
	  so a single event could end up on multiple pages and be awkward for users.
	BUT the parameters exist, just commented out.
	
	ScanImage joins are commented in the test version or you'd see nearly no results
	Prod version should join to Scan Image to make sure only available images are in results.
	
	When multiple unique generator_ids are found in the results of a search, the
	SP _does_not_ return scan results.  Per spec in DevOps ticket, the results should
	only show up when there's only 1 generator to show.
	Helper info: generator_count in the results tells you how many unique generator_ids there are
	 AND the generator fields in the results will be populated so a list can be shown for the user
	 to choose 1.
	 
	The Result_count field in results tells you the total result set size, if ever needed.
	
	Manifest Numbers are only searched from the beginning - not middle/end.
	
	SELECT  * FROM    plt_export..EQIPImageExportHeader ORDER BY  export_id desc
	SELECT  * FROM    plt_export..EQIPImageExportDetail where export_id = 1766
	SELECT  distinct filename  FROM    plt_export..EQIPImageExportDetail where export_id = 1766
************************************************************************** */

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- This is easier than adding WITH (NOLOCK) to every table.
SET NOCOUNT ON
/*
-- Debugging:
DECLARE
	@web_userid varchar(100) = 'court_c'
	, @start_date	datetime = '12/9/2015' -- '1/1/2019' -- dateadd(yyyy, -5, getdate())
	, @end_date		datetime = '12/9/2020'
	, @generator_id	int = 200725
	, @manifest		varchar(100) = null
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
	, @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
	, @page				bigint = 1
	, @perpage			bigint = 20 
*/


declare @i_web_userid varchar(100) = isnull(@web_userid, '')
	, @i_start_date datetime = isnull(@start_date, dateadd(yyyy, -5, getdate()))
	, @i_end_date	datetime = isnull(@end_date, getdate())
	, @i_generator_id	int = @generator_id
	, @i_manifest	varchar(100) = isnull(@manifest, '')
	, @i_contact_id	int
	, @i_generator_result_count int = 0
	, @i_page				bigint = @page
	, @i_perpage			bigint = @perpage 
	, @i_customer_id_list varchar(max)= isnull(@customer_id_list, '')
    , @i_generator_id_list varchar(max)=isnull(@generator_id_list, '')
    , @i_export_images		int			= isnull(@export_images, 0)
	, @i_scan_type_id_list varchar(max) = isnull(@scan_type_id_list, '')
	, @i_image_id_list varchar(max) = isnull(@image_id_list, '')
    , @i_export_email	varchar(100) = isnull(@export_email, '')
	, @crlf varchar(2) = char(10) + char(13)

select top 1 @i_contact_id = contact_id from corcontact where web_userid = @i_web_userid
if @i_export_email = '' select top 1 @i_export_email = email from corcontact where web_userid = @i_web_userid
	
declare @imageid table (
	imageid	bigint
)
if @i_image_id_list <> ''
insert @imageid select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_image_id_list)
where row is not null


create table #ScanExport_Scan (
	ContactCORManifestBucket_UID BIGINT
	, image_id	BIGINT				/* scan.image_id */
	, document_source varchar(30)	/* scan.document_source */
	, document_name	varchar(50)		/* scan.document_name */
	, manifest		varchar(15)		/* scan.manifest */
	, type_id		int				/* scan.type_id */
	, document_type	varchar(30)		/* scandocumenttype.document_type */
	, page_number	int				/* scan.page_number */
	, file_type		varchar(10)		/* scan.file_type */
	, relation		varchar(20)		/* input or related */
	, receipt_id	int				/* scan.workorder_id / scan.receipt_id */
	, company_id	int				/* scan.company_id */
	, profit_ctr_id	int				/* scan.profit_ctr_id */
	, image_id_list	varchar(max)	/* scan.image_id in CSV */
	, in_image_id_list bit			/* Is this image_id value present 
			in the image_id_list of another row? 
			if so, this row should probably be hidden from display */
)


create table #ScanExport_Bar (
	ContactCORManifestBucket_UID INT
	, source VARCHAR(20) NOT NULL 
	, contact_id INT NOT NULL
	, matches_receipt_id INT NOT NULL 
	, matches_company_id INT NOT NULL
	, matches_profit_ctr_id INT NOT NULL
	, service_date DATETIME NULL
	, receipt_date DATETIME NULL
	, customer_id INT null
	, generator_id INT null
	, matches_manifest VARCHAR(15) NOT NULL
	, image_id	BIGINT				/* scan.image_id */
	, document_source varchar(30)	/* scan.document_source */
	, document_name	varchar(50)		/* scan.document_name */
	, manifest		varchar(15)		/* scan.manifest */
	, type_id		int				/* scan.type_id */
	, document_type	varchar(30)		/* scandocumenttype.document_type */
	, page_number	int				/* scan.page_number */
	, file_type		varchar(10)		/* scan.file_type */
	, relation		varchar(20)		/* input or related */
	, receipt_id	int				/* scan.workorder_id / scan.receipt_id */
	, company_id	int				/* scan.company_id */
	, profit_ctr_id	int				/* scan.profit_ctr_id */
	, for_combined_display char(1)
	, image_id_file_type_page_number_list varchar(max)
	, _ord bigint
)


exec sp_cor_quick_search_service_docs
	@web_userid = @i_web_userid
	, @start_date = @i_start_date
	, @end_date = @i_end_date
	, @generator_id = @i_generator_id
	, @manifest = @i_manifest
	, @page= -1
	, @perpage = 0
	, @customer_id_list = @i_customer_id_list
	, @generator_id_list = @i_generator_id_list
    , @export_images = 0
	, @scan_type_id_list = @i_scan_type_id_list
	, @image_id_list = ''
    , @export_email	= ''
    

declare @scan table (
	ContactCORManifestBucket_UID BIGINT
	, image_id	BIGINT				/* scan.image_id */
	, document_source varchar(30)	/* scan.document_source */
	, document_name	varchar(50)		/* scan.document_name */
	, manifest		varchar(15)		/* scan.manifest */
	, type_id		int				/* scan.type_id */
	, document_type	varchar(30)		/* scandocumenttype.document_type */
	, page_number	int				/* scan.page_number */
	, file_type		varchar(10)		/* scan.file_type */
	, relation		varchar(20)		/* input or related */
	, receipt_id	int				/* scan.workorder_id / scan.receipt_id */
	, company_id	int				/* scan.company_id */
	, profit_ctr_id	int				/* scan.profit_ctr_id */
	, image_id_list	varchar(max)	/* scan.image_id in CSV */
	, in_image_id_list bit			/* Is this image_id value present 
			in the image_id_list of another row? 
			if so, this row should probably be hidden from display */
)


-- populate @scan with input id results
insert @scan 
select * from #ScanExport_Scan

drop table if exists #bar

select
	ContactCORManifestBucket_UID, 
	---------------------------
	source	,
	contact_id ,
	matches_receipt_id,
	matches_company_id,
	matches_profit_ctr_id,
	---------------------------
	service_date	,
	receipt_date ,
	---------------------------
	customer_id	,
	generator_id ,
	---------------------------
	matches_manifest,

	image_id
	, document_source
	, document_name
	, manifest
	, type_id
	, document_type
	, page_number
	, file_type
	, relation
	, receipt_id
	, company_id
	, profit_ctr_id
	, for_combined_display
	, image_id_file_type_page_number_list
	, _ord
into #bar
from #ScanExport_Bar


-- if @i_export_images = 1 begin
	drop table if exists #scan 
	drop table if exists #export
	drop table if exists #DocTypeOrder
	drop table if exists #ImageExportDetail
	drop table if exists #ImageExportHeader

	select * into #scan from @scan

	declare 
		  @report_id int
		, @report_log_id int
		, @criteria_id int
		, @file_count int
		, @export_id int


	select 
		a.document_type	
		,a.type_id
		, coalesce(g.site_code, g.epa_id, convert(varchar(20), g.generator_id))
			+ isnull(' - ' + left(convert(varchar(10),a.service_date,121),10),'')
			+ isnull(' - ' + replace(a.document_type, ' ', '_'), '')
			+ isnull(' - ' + coalesce(nullif(scan.description, ''), nullif(scan.manifest, ''), nullif(scan.document_name, '')), '')  + ' - ' + convert(varchar(20), a.image_id) as description
		,a.service_date	
		,a.file_type	
		,a.for_combined_display	
		, s.image_id
		, s.page_number
		,a.image_id_file_type_page_number_list	
		, a.image_id as first_image_id
		, g.generator_id
		, g.generator_name
		, g.generator_address_1
		, g.generator_address_2
		, g.generator_address_3
		, g.generator_city
		, g.generator_state
		, g.generator_zip_code
		, g.epa_id
	into #export
	from #bar a
	join generator g 
		on a.generator_id = g.generator_id
	join #scan s
		on s.document_source = a.document_source
		and s.document_name = a.document_name
		and isnull(s.manifest, '') = isnull(a.manifest, '')
		and s.type_id = a.type_id
		and s.document_type = a.document_type
	join plt_image..scan on s.image_id = scan.image_id	
	WHERE a.image_id_file_type_page_number_list not like '%,%'
	union
	
	select
		a.document_type	
		,a.type_id
		, coalesce(g.site_code, g.epa_id, convert(varchar(20), g.generator_id))
			+ isnull(' - ' + left(convert(varchar(10),a.service_date,121),10),'')
			+ isnull(' - ' + replace(a.document_type, ' ', '_'), '')
			+ isnull(' - ' + coalesce(nullif(scan_first.description, ''), nullif(scan_first.manifest, ''), nullif(scan_first.document_name, '')), '')  + ' - ' + convert(varchar(20), a.image_id) as description
		,a.service_date	
		,a.file_type	
		,a.for_combined_display	
		, s.image_id
		, s.page_number
		,a.image_id_file_type_page_number_list	
		, a.image_id as first_image_id
		, g.generator_id
		, g.generator_name
		, g.generator_address_1
		, g.generator_address_2
		, g.generator_address_3
		, g.generator_city
		, g.generator_state
		, g.generator_zip_code
		, g.epa_id
		-- select *
	from #bar a
	join #bar b on a.image_id = b.image_id
	join generator g 
		on a.generator_id = g.generator_id
	join #scan s
		on s.document_source = b.document_source
		and s.document_name = b.document_name
		and isnull(s.manifest, '') = isnull(b.manifest, '')
		and s.type_id = b.type_id
		and s.document_type = b.document_type
	join plt_image..scan on s.image_id = scan.image_id
	join plt_image..scan scan_first on a.image_id = scan_first.image_id

	WHERE a.image_id_file_type_page_number_list like '%,%'
--	and s.image_id <> a.image_id


	-- apply input image_id list filter
	if exists (select 1 from @imageid where imageid is not null)
		delete from #export
		-- select *
		from #export e
		WHERE e.image_id not in (
			select e.image_id
			from #export join @imageid i 
				on e.image_id_file_type_page_number_list like '%' + convert(varchar(20), i.imageid)+ '|%'
		)

	select @file_count = count(distinct description) from #export
	
	-- If we introduced a count option before a full export operation, this would be the place:
	-- if @i_export_images = 1 --- count = 1, full export = 2
	-- begin
	--		select @file_count as file_count
	--		return
	-- end
	
	-- if @i_export_images = 2
	begin -- begin export operation
		-----------------------------------	
		-- Run to a temp table - gives the most flexibility/simpler stepwise queries...
		-----------------------------------

		-- Create temp tables mirroring the permanent tables
		CREATE TABLE #ImageExportHeader (
			-- export_id			int				not null
			added_by			varchar(10)	not null
			, date_added		datetime	not null default getdate()
			, criteria			varchar(max)
			, export_flag		char(1)		not null default 'N'
			, image_count		int			not null default 0
			, file_count		int			not null default 0
			, report_log_id		int
			, export_start_date	datetime
			, export_end_date	datetime
		)

		CREATE TABLE #ImageExportDetail (
			-- export_id			int				not null
			tran_id				int				not null
			, image_id			int				not null
			, filename			varchar(255)	not null
			, page_number		int				not null default 1
		)
		
		create table #DocTypeOrder (
			document_type	varchar(100)
			, page_order	int
		)

		insert #DocTypeOrder
		select distinct
			document_type
			/* Smaller #'s come first */
			, case document_type
				when  'Generator Initial Manifest' then    500
				when  'Manifest' then					  1000
				when  'Secondary Manifest' then			  2000
				when  'Pickup Manifest' then			  3000
				when  'Pick Up Report' then				  4000
				when  'Pick Up Request' then			  5000
				when  'COD' then						 10000
				when  'Receiving Document' then			 20000
				when  'Workorder Document' then			 30000
				when  'Attachment' then					 40000
				else									500000
			end
		-- select * 
		from plt_image.dbo.scandocumenttype (nolock)
		where scan_type in ('receipt', 'workorder') 
		and status = 'A' 
		/* This is the same from-where query used in the list of options for doc types to export */

		-- Headers are easy:
		insert #ImageExportHeader 
		select
			'COR'	as added_by
			, getdate()	as date_added
			, criteria =
			'  web_userid			= ' + isnull(@i_web_userid, '') + @crlf +
			'  email                = ' + isnull(@i_export_email, '') + @crlf +
			'  start_date			= ' + isnull(convert(varchar(40), @i_start_date, 121), '') + @crlf +
			'  end_date				= ' + isnull(convert(varchar(40), @i_end_date, 121), '') + @crlf +
			'  generator_id			= ' + isnull(convert(varchar(20), @i_generator_id), '') + @crlf +
			'  manifest				= ' + isnull(@i_manifest, '') + @crlf +
			'  page					= ' + isnull(convert(varchar(10), @i_page), '1') + @crlf +
			'  perpage				= ' + isnull(convert(varchar(10), @i_perpage), '20') + @crlf +
			'  customer_id_list 	= ' + isnull(@customer_id_list, '') + @crlf +
			'  generator_id_list 	= ' + isnull(@generator_id_list, '') + @crlf +
			'  export_images		= ' + isnull(convert(varchar(10), @i_export_images), '0') + @crlf
			, 'Y'	as export_flag
			, 0		as image_count
			, 0		as file_count
			, null	as report_log_id
			, null	as export_start_date
			, null	as export_end_date
		-- Headers finished


		-- Details are where the magic happens
		insert #ImageExportDetail 
			select 
			row_number() over (order by a.image_id) as tran_id
			, a.image_id 
			, filename = ltrim(rtrim(isnull( a.description, convert(varchar(20), a.image_id )))) 
			, page_number = row_number() over (
				partition by 
					ltrim(rtrim(isnull( a.description, convert(varchar(20), a.image_id ))))
				order by
				isnull(dto.page_order, 5000000) + isnull(a.page_number, 1)
				)
			FROM #export a
			inner join plt_image..scandocumenttype st (nolock) on a.type_id = st.type_id
			left join #DocTypeOrder dto on st.document_type = dto.document_type


			update #ImageExportDetail 
			set filename = replace(
				replace(
					replace(
						replace(
							replace(
								replace(
									replace(
										replace(
											replace(filename, '\', '_')
										, '/', '_')
									, ':', '_')
								, '*', '_')
							, '?', '_')
						, '"', '_') 
					, '>', '_')
				, '<', '_')
			, '__', '_')

--- fix syntax highlight: "

		-- transfer temp table data to real tables: 
		-- Headers:
		insert plt_export..EqipImageExportHeader 
			(added_by, date_added, criteria, export_flag, image_count, file_count, report_log_id, export_start_date, export_end_date)
		select distinct
			 added_by, date_added, criteria, export_flag, (select count(distinct image_id) from #ImageExportDetail) as image_count, (select count(distinct filename) from #ImageExportDetail) as file_count, report_log_id, export_start_date, export_end_date
		from #ImageExportHeader
		
		
		set @export_id = @@IDENTITY

		
		-- Detail:
		insert plt_export..EqipImageExportDetail 
			(export_id, image_id, filename, page_number)
		select distinct
			@export_id, image_id, filename, page_number
		from
			#ImageExportDetail

		select top 1 @report_id = report_id from plt_ai..Report (nolock) where report_name = 'ImageExportConsole.exe' and report_status = 'A'
		select top 1 @criteria_id = report_criteria_id FROM plt_ai..ReportXReportCriteria (nolock) where report_id = @report_id

		EXEC @report_log_id = plt_ai..sp_sequence_next 'ReportLog.report_log_ID', 1

		exec plt_ai..sp_ReportLog_add @report_log_id, @report_id, 'COR'
		exec plt_ai..sp_ReportLogParameter_add @report_log_id, @criteria_id, @export_id
				
	end -- end export operation


-- end

set nocount off

go

grant execute on sp_cor_quick_search_service_docs_export to cor_user
go
