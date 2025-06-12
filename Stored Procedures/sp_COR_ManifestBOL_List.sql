    
-- drop proc if exists sp_COR_ManifestBOL_List
go

CREATE PROCEDURE sp_COR_ManifestBOL_List (
	@web_userid		varchar(100)
	, @date_start		datetime = null
	, @date_end			datetime = null
	, @customer_search	varchar(max) = null
	, @document_type	varchar(20) = null -- Manifest, BOL, All default = manifest
	, @manifest			varchar(max) = null
	, @generator_name	varchar(max) = null
	, @epa_id			varchar(max) = null -- can take CSV list
	, @store_number		varchar(max) = null -- can take CSV list
	, @site_type		varchar(max) = null -- can take CSV list
	, @generator_district varchar(max) = null -- can take CSV list
	, @generator_region	varchar(max) = null -- can take CSV list
	, @approval_code	varchar(max) = null
	, @sort				varchar(20) = ''
	, @page				bigint = 1
	, @perpage			bigint = 20 
	, @excel_output		int = 0
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @export_images	bit = 0 /* Export Images option */
    
) 
AS
BEGIN
/* **************************************************************
sp_COR_ManifestBOL_List

	Return search results for manifest/bol searches
	
10/14/2019 MPM  DevOps 11576: Added logic to filter the result set
				using optional input parameters @customer_id_list and
				@generator_id_list.

SELECT  * FROM    contact WHERE web_userid = 'court_c'
SELECT  * FROM    contactxref WHERE contact_id = 175531

 sp_COR_ManifestBOL_List 
	@web_userid		= 'court_c'
	, @date_start		 = '1/1/2018'
	, @date_end			 = '12/31/2020'
    , @customer_search	= null
	, @document_type	= 'All' -- Manifest, BOL, All default = manifest
    , @manifest			 = ''
    , @generator_name	 = null
    , @epa_id			 = null -- can take CSV list
    , @store_number		 = null -- can take CSV list
	, @site_type		 = null -- can take CSV list
	, @generator_district  = null -- can take CSV list
    , @generator_region	 = null -- can take CSV list
    , @approval_code	 = null
	, @sort				 = ''
	, @page				= 1
	, @perpage			= 999999 
	, @customer_id_list = '15940'
    , @excel_output		= 0

	
 sp_COR_ManifestBOL_List 
	@web_userid		= 'nyswyn100'
	, @date_start		 = '2/26/2021'
	, @date_end			 = '5/26/2021'
    , @customer_search	= null
	, @document_type	= 'All' -- Manifest, BOL, All default = manifest
    , @manifest			 = ''
    , @generator_name	 = null
    , @epa_id			 = null -- can take CSV list
    , @store_number		 = null -- can take CSV list
	, @site_type		 = null -- can take CSV list
	, @generator_district  = null -- can take CSV list
    , @generator_region	 = null -- can take CSV list
    , @approval_code	 = null
	, @sort				 = ''
	, @page				= 1
	, @perpage			= 999999 
	, @customer_id_list = ''
    , @excel_output		= 0
    , @export_images = 1
    
    
SELECT  TOP 10 *
FROM    plt_export..EQIPImageExportHeader ORDER BY export_id desc

SELECT  TOP 10 *
FROM    plt_ai..reportlog ORDER BY report_log_id desc

SELECT  TOP 10 *
FROM    message ORDER BY message_id desc

SELECT  TOP 10 *
FROM    messageaddress WHERE message_id = 4176958


SELECT  * FROM    plt_Export..EQIPImageExportDetail WHERE export_id = 1790

    
SELECT  * FROM    plt_image..scan WHERE workorder_id = 872600 and company_id = 47
-- service 2020-03-29
-- upload 2020-06-13 17:04:25.500
SELECT  * FROM    contactcorworkorderheaderbucket where contact_id= 175531
	and customer_id = 15940

SELECT  *  FROM    plt_image..scan where image_id = 11384791

 sp_COR_ManifestBOL_List 
	@web_userid		= 'amber'
	, @date_start		 = '1/1/2018'
	, @date_end			 = '7/11/2019'
    , @customer_search	= null
	, @document_type	= '' -- Manifest, BOL, All default = manifest
    , @manifest			 = null
    , @generator_name	 = null
    , @epa_id			 = null -- can take CSV list
    , @store_number		 = null -- can take CSV list
	, @site_type		 = null -- can take CSV list
	, @generator_district  = null -- can take CSV list
    , @generator_region	 = null -- can take CSV list
    , @approval_code	 = null
	, @sort				 = ''
	, @page				= 1
	, @perpage			= 2000 
    , @excel_output		= 0
	, @customer_id_list ='15622'  
    , @generator_id_list ='155581, 155586'  


************************************************************** */
/*
-- DEBUG:
declare 	@web_userid		varchar(100) = 'zachery.wright'
	, @date_start		datetime = '1/1/2018'
	, @date_end			datetime = '7/11/2019'
    , @customer_search	varchar(max) = null
	, @document_type	varchar(20) = 'Manifest' -- Manifest, BOL, All default = manifest
    , @manifest			varchar(max) = null
    , @generator_name	varchar(max) = null
    , @epa_id			varchar(max) = null -- can take CSV list
    , @store_number		varchar(max) = null -- can take CSV list
	, @site_type		varchar(max) = null -- can take CSV list
	, @generator_district varchar(max) = null -- can take CSV list
    , @generator_region	varchar(max) = null -- can take CSV list
    , @approval_code	varchar(max) = null
	, @sort				varchar(20) = ''
	, @page				bigint = 1
	, @perpage			bigint = 10
    , @excel_output		int = 0
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
*/
declare
	@i_web_userid				varchar(100)	= @web_userid
	, @i_date_start				datetime		= convert(date, isnull(@date_start, '1/1/1990'))
	, @i_date_end				datetime		= convert(date, isnull(@date_end, getdate()))
    , @i_customer_search		varchar(max)	= isnull(@customer_search, '')
	, @i_document_type			varchar(20)		= isnull(nullif(@document_type,''), 'manifest')		
    , @i_manifest				varchar(max)	= isnull(@manifest, '')
    , @i_generator_name			varchar(max)	= isnull(@generator_name, '')
    , @i_epa_id					varchar(max)	= isnull(@epa_id, '')
    , @i_store_number			varchar(max)	= isnull(@store_number, '')
	, @i_site_type				varchar(max)	= isnull(@site_type, '')
	, @i_generator_district		varchar(max)	= isnull(@generator_district, '')
    , @i_generator_region		varchar(max)	= isnull(@generator_region, '')
    , @i_approval_code			varchar(max)	= isnull(@approval_code, '')
	, @i_sort					varchar(20)		= isnull(@sort, 'Service Date')
	, @i_page					bigint			= isnull(@page,1)
	, @i_perpage				bigint			= isnull(@perpage,20)
    , @i_excel_output			int				= isnull(@excel_output,0)
	, @contact_id	int
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
    , @i_export_images		bit			= isnull(@export_images, 0)
	, @crlf varchar(2) = char(10) + char(13)

select top 1 @contact_id = contact_id from CORcontact where web_userid = @i_web_userid
    
if isnull(@i_sort, '') not in ('Service Date', 'Customer Name', 'Generator Name', 'Manifest/BOL', 'Transaction Type', 'Transaction Number') set @i_sort = ''
-- if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = dateadd(m, -3, getdate())
if isnull(@i_date_end, '1/1/1999') = '1/1/1999' set @i_date_end = getdate()
if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999

declare @customer table (
	customer_id	bigint
)

if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator table (
	generator_id	bigint
)

if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

declare @tcustomer table (
	customer_id	int
)
if @i_customer_search <> ''
insert @tcustomer
select customer_id from dbo.fn_COR_CustomerID_Search(@i_web_userid, @i_customer_search) 


declare @epaids table (
	epa_id	varchar(20)
)
if @i_epa_id <> ''
insert @epaids (epa_id)
select left(row, 20) from dbo.fn_SplitXsvText(',', 1, @i_epa_id)
where row is not null


declare @tdistrict table (
	generator_district	varchar(50)
)
if @i_generator_district <> ''
insert @tdistrict
select row from dbo.fn_SplitXsvText(',', 1, @i_generator_district)


declare @tstorenumber table (
	site_code	varchar(16),
	idx	int not null
)
if @i_store_number <> ''
insert @tstorenumber (site_code, idx)
select row, idx from dbo.fn_SplitXsvText(',', 1, @i_store_number) where row is not null


declare @tsitetype table (
	site_type	varchar(40)
)
if @i_site_type <> ''
insert @tsitetype (site_type)
select row from dbo.fn_SplitXsvText(',', 1, @i_site_type) where row is not null


declare @tgeneratorregion table (
	generator_region_code	varchar(40)
)
if @i_generator_region <> ''
insert @tgeneratorregion
select row from dbo.fn_SplitXsvText(',', 1, @i_generator_region)


declare @tmanifest table (
	manifest	varchar(20)
)
insert @tmanifest
select row 
from dbo.fn_splitxsvtext(',', 1, @i_manifest) 
where row is not null

declare @ttype table (
	type_id	int
)
insert @ttype
select type_id
from plt_image..scandocumenttype (nolock)
where document_type like '%' + @i_document_type + '%'
union
select type_id
from plt_image..scandocumenttype (nolock)
where @i_document_type = 'all'
and (document_type like '%manifest%'
	or document_type = 'bol'
)

/*
declare @generators table (Generator_id int)

if @i_generator_name + @i_epa_id + @i_store_number + @i_generator_district + @i_generator_region + @i_site_type <> ''
	insert @generators
	SELECT  
			x.Generator_id
	FROM    ContactCORGeneratorBucket x (nolock)
	join Generator d (nolock) on x.Generator_id = d.Generator_id
	left join @tstorenumber s on d.site_code like '%' + s.site_code + '%'
	where 
	x.contact_id = @contact_id
	and 
	(
		@i_generator_name = ''
		or
		(
			@i_generator_name <> ''
			and
			d.generator_name like '%' + replace(@i_generator_name, ' ', '%') + '%'
		)
	)
	and 
	(
		@i_epa_id = ''
		or
		(
			@i_epa_id <> ''
			and
			d.epa_id in (select epa_id from @epaids)
		)
	)
	and 
	(
		@i_generator_region = ''
		or
		(
			@i_generator_region <> ''
			and
			d.generator_region_code in (select generator_region_code from @tgeneratorregion)
		)
	)
	and 
	(
		@i_generator_district = ''
		or
		(
			@i_generator_district <> ''
			and
			d.generator_district in (select generator_district from @tdistrict)
		)
	)
	and 
	(
		@i_store_number = ''
		or
		(
			@i_store_number <> ''
			and
			s.idx is not null
		)
	)
	and 
	(
		@i_site_type = ''
		or
		(
			@i_site_type <> ''
			and
			d.site_type in (select site_type from @tsitetype)
		)
	)
*/

declare @foo table (
	trans_source		char(1)
	, receipt_id		int
	, company_id		int
	, profit_ctr_id		int
	, service_date		datetime
)

declare @bar table (
	trans_source		char(1)
	, receipt_id		int
	, company_id		int
	, profit_ctr_id		int
	, service_date		datetime
	, customer_id		int
	, generator_id		int
	, manifest			varchar(15)
)


insert @foo
SELECT DISTINCT 
	'R' trans_source,
	x.receipt_id,
	x.company_id,
	x.profit_ctr_id,
	isnull(x.pickup_date, x.receipt_date)
FROM    ContactCORReceiptBucket x  (nolock) 
	left join Generator d (nolock) on x.Generator_id = d.Generator_id
	left join @tstorenumber s on d.site_code like '%' + s.site_code + '%'
WHERE x.contact_id = @contact_id
and isnull(x.pickup_date, x.receipt_date) between @i_date_start and @i_date_end
and 
(
	@i_customer_id_list = ''
	or
	(
		@i_customer_id_list <> ''
		and
		x.customer_id in (select customer_id from @customer)
	)
)
and
(
	@i_generator_id_list = ''
	or
	(
		@i_generator_id_list <> ''
		and
		x.generator_id in (select generator_id from @generator)
	)
)
	and 
	(
		@i_generator_name = ''
		or
		(
			@i_generator_name <> ''
			and
			isnull(d.generator_name, '') like '%' + replace(@i_generator_name, ' ', '%') + '%'
		)
	)
	and 
	(
		@i_epa_id = ''
		or
		(
			@i_epa_id <> ''
			and
			isnull(d.epa_id, '') in (select epa_id from @epaids)
		)
	)
	and 
	(
		@i_generator_region = ''
		or
		(
			@i_generator_region <> ''
			and
			isnull(d.generator_region_code, '') in (select generator_region_code from @tgeneratorregion)
		)
	)
	and 
	(
		@i_generator_district = ''
		or
		(
			@i_generator_district <> ''
			and
			isnull(d.generator_district, '') in (select generator_district from @tdistrict)
		)
	)
	and 
	(
		@i_store_number = ''
		or
		(
			@i_store_number <> ''
			and
			s.idx is not null
		)
	)
	and 
	(
		@i_site_type = ''
		or
		(
			@i_site_type <> ''
			and
			isnull(d.site_type, '') in (select site_type from @tsitetype)
		)
	)

union
SELECT
	'W' trans_source,
	x.workorder_id,
	x.company_id,
	x.profit_ctr_id,
	isnull(x.service_date, x.start_date)
FROM    ContactCORWorkOrderHeaderBucket x  (nolock) 
	left join Generator d (nolock) on x.Generator_id = d.Generator_id
	left join @tstorenumber s on d.site_code like '%' + s.site_code + '%'
WHERE x.contact_id = @contact_id
and isnull(x.service_date, x.start_date) between @i_date_start and @i_date_end
and 
(
	@i_customer_id_list = ''
	or
	(
		@i_customer_id_list <> ''
		and
		x.customer_id in (select customer_id from @customer)
	)
)
and
(
	@i_generator_id_list = ''
	or
	(
		@i_generator_id_list <> ''
		and
		x.generator_id in (select generator_id from @generator)
	)
)
and 
(
	@i_generator_name = ''
	or
	(
		@i_generator_name <> ''
		and
		isnull(d.generator_name, '') like '%' + replace(@i_generator_name, ' ', '%') + '%'
	)
)
and 
(
	@i_epa_id = ''
	or
	(
		@i_epa_id <> ''
		and
		isnull(d.epa_id, '') in (select epa_id from @epaids)
	)
)
and 
(
	@i_generator_region = ''
	or
	(
		@i_generator_region <> ''
		and
		isnull(d.generator_region_code, '') in (select generator_region_code from @tgeneratorregion)
	)
)
and 
(
	@i_generator_district = ''
	or
	(
		@i_generator_district <> ''
		and
		isnull(d.generator_district, '') in (select generator_district from @tdistrict)
	)
)
and 
(
	@i_store_number = ''
	or
	(
		@i_store_number <> ''
		and
		s.idx is not null
	)
)
and 
(
	@i_site_type = ''
	or
	(
		@i_site_type <> ''
		and
		isnull(d.site_type, '') in (select site_type from @tsitetype)
	)
)


insert @bar
select distinct z.*, r.customer_id, r.generator_id, r.manifest
from @foo z
join Receipt r (nolock) on r.receipt_id = z.receipt_id and r.company_id = z.company_id and r.profit_ctr_id = z.profit_ctr_id and z.trans_source = 'R'
left join @tcustomer c on r.customer_id = c.customer_id
where 1=1
and (
	(select count(*) from @tcustomer) = 0
	or 
	(r.customer_id = c.customer_id)
)
and ( 
	isnull(@i_manifest, '') = ''
	or 
	(r.manifest in (select manifest from @tmanifest))
)
and (
	isnull(@i_approval_code, '') = ''
	or 
	(r.approval_code like '%' + replace(@i_approval_code, ' ', '%') + '%')
)

insert @bar
select distinct z.*, h.customer_id, h.generator_id, null as manifest
from @foo z
join workorderheader h (nolock)
	on z.receipt_id = h.workorder_id and z.company_id = h.company_id and z.profit_ctr_id = h.profit_ctr_id and z.trans_source = 'W'
left join @tcustomer c on h.customer_id = c.customer_id
where 1=1
and (
	(select count(*) from @tcustomer) = 0
	or 
	(h.customer_id = c.customer_id)
)
and ( 
	isnull(@i_manifest, '') = ''
	or 
	(
		exists (
			select top 1 1 from workordermanifest m (nolock)
			WHERE m.workorder_id = z.receipt_id
			and m.company_id = z.company_id
			and m.profit_ctr_id = z.profit_ctr_id
			and m.manifest in (select manifest from @tmanifest)
			and m.manifest not like '%manifest%'
		)
	)
)
and (
	isnull(@i_approval_code, '') = ''
	or 
	(
		exists (
			select top 1 1 from 
			workorderdetail d (nolock) 
			WHERE 
			d.workorder_id = z.receipt_id
			and d.company_id = z.company_id 
			and d.profit_ctr_id = z.profit_ctr_id
			and d.bill_rate > -2
			and d.tsdf_approval_code like '%' + replace(@i_approval_code, ' ', '%') + '%'
		)
	)
)


--if object_id('tempdb..#foo') is not null drop table #foo
--if object_id('tempdb..#bar') is not null drop table #bar
--if object_id('tempdb..#ttype') is not null drop table #ttype
if object_id('tempdb..#rex') is not null drop table #rex
--SELECT  *  into #foo FROM    @foo
--SELECT  *  into #bar FROM    @bar
--SELECT  *  into #ttype FROM    @ttype

SELECT  b.trans_source	
	, b.receipt_id	
	, b.company_id	
	, b.profit_ctr_id	
	, b.service_date	
	, b.customer_id	
	, b.generator_id	
	, s.image_id
	, s.type_id
	, convert(varchar(255), isnull(nullif(s.manifest, ''), b.manifest)) as description
	, s.file_type
	, isnull(s.page_number, 1) page_number
	, isnull(s.upload_date, s.date_modified) upload_date
into #rex
FROM    @bar b
join plt_image..scan s
on b.receipt_id = s.receipt_id
and b.company_id = s.company_id
and b.profit_ctr_id = s.profit_ctr_id
and s.document_source = 'receipt'
and s.status = 'A'
and s.type_id in (select type_id from @ttype)
and s.view_on_web = 'T'
-- join plt_image..scanimage si on s.image_id = si.image_id
WHERE b.trans_source = 'R'

insert #rex
SELECT  b.trans_source	
	, b.receipt_id	
	, b.company_id	
	, b.profit_ctr_id	
	, b.service_date	
	, b.customer_id	
	, b.generator_id	
	, s.image_id
	, s.type_id
	, coalesce(nullif(s.description, ''), nullif(s.manifest, ''), nullif(s.document_name, '')) as description
	, s.file_type
	, isnull(s.page_number, 1) page_number
	, isnull(s.upload_date, s.date_modified) upload_date
FROM    @bar b
join plt_image..scan s
on b.receipt_id = s.workorder_id
and b.company_id = s.company_id
and b.profit_ctr_id = s.profit_ctr_id
and s.document_source = 'workorder'
and s.status = 'A'
and s.type_id in (select type_id from @ttype)
and s.view_on_web = 'T'
-- join plt_image..scanimage si on s.image_id = si.image_id
WHERE b.trans_source = 'W'
--and not exists (
--	select 1 from #rex r 
--	WHERE left(r.description, 12) = left(coalesce(nullif(s.description,''), nullif( s.manifest,''), nullif( s.document_name,'')), 12)
--)

if @i_export_images > 0 
begin

	declare 
		  @report_id int
		, @report_log_id int
		, @criteria_id int
		, @file_count int
		, @export_id int


	select distinct
		a.trans_source
		, a.receipt_id
		, a.company_id
		, a.profit_ctr_id
		, a.service_date
		, a.customer_id
		, a.generator_id
		, a.type_id
		, sdt.document_type
		, min(a.upload_date) upload_date
		, a.description
		, a.image_id
		, a.file_type
		, a.page_number
	into #export
	from #rex a
		join plt_image..ScanDocumentType sdt
			on a.type_id = sdt.type_id
	GROUP BY 
		a.trans_source
		, a.receipt_id
		, a.company_id
		, a.profit_ctr_id
		, a.service_date
		, a.customer_id
		, a.generator_id
		, a.type_id
		, sdt.document_type
		, a.description
		, a.image_id
		, a.file_type
		, a.page_number


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
			'  date_start			= ' + isnull(convert(varchar(40), @i_date_start, 121), '') + @crlf +
			'  date_end				= ' + isnull(convert(varchar(40), @i_date_end, 121), '') + @crlf +
			'  customer_search		= ' + isnull(@i_customer_search, '') + @crlf + 
			'  document_type		= ' + isnull(@i_document_type, '') + @crlf +
			'  manifest				= ' + isnull(@i_manifest, '') + @crlf +
			'  generator_name		= ' + isnull(@i_generator_name, '') + @crlf +
			'  epa_id				= ' + isnull(@i_epa_id, '') + @crlf +
			'  store_number			= ' + isnull(@i_store_number, '') + @crlf +
			'  site_type			= ' + isnull(@i_site_type, '') + @crlf +
			'  generator_district 	= ' + isnull(@i_generator_district, '') + @crlf +
			'  generator_region		= ' + isnull(@i_generator_region, '') + @crlf +
			'  approval_code		= ' + isnull(@i_approval_code, '') + @crlf +
			'  sort					= ' + isnull(@i_sort, '') + @crlf +
			'  page					= ' + isnull(convert(varchar(10), @i_page), '1') + @crlf +
			'  perpage				= ' + isnull(convert(varchar(10), @i_perpage), '20') + @crlf +
			'  excel_output			= ' + isnull(convert(varchar(10), @i_excel_output), '0') + @crlf +
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

end -- @i_export_images =1
else 
begin  -- NOT @i_export_images =1

	select distinct
		a.trans_source
		, a.receipt_id
		, a.company_id
		, a.profit_ctr_id
		, a.service_date
		, a.customer_id
		, a.generator_id
		, a.type_id
		, sdt.document_type
		, min(a.upload_date) upload_date
		, a.description
		, isnull(( select substring(
			(
				select ', ' + 
				convert(varchar(20), image_id) + '|' + file_type + '|' + convert(varchar(20), page_number)
				FROM #rex b
				where b.receipt_id = a.receipt_id
				and b.trans_source = a.trans_source
				and b.company_id = a.company_id
				and b.profit_ctr_id = a.profit_ctr_id
				and b.service_date = a.service_date
				and b.type_id = a.type_id
				and b.description = a.description
				order by b.page_number
				for xml path, TYPE).value('.[1]','nvarchar(max)'
			),2,20000)	) , '')	as image_id_file_type_page_number_list
	into #newrex
	from #rex a
		join plt_image..ScanDocumentType sdt
			on a.type_id = sdt.type_id
	GROUP BY 
		a.trans_source
		, a.receipt_id
		, a.company_id
		, a.profit_ctr_id
		, a.service_date
		, a.customer_id
		, a.generator_id
		, a.type_id
		, sdt.document_type
		, a.description


	if @i_excel_output = 0 -- Regular output:

		select * from 
		(
			select 
				r.*
				, c.cust_name
				, g.generator_name
				, g.epa_id
				, g.generator_city
				, g.generator_state
				, g.generator_country
				, g.site_code
				, g.site_type
				, g.generator_region_code
				, g.generator_division
				-- , sdt.document_type
				, upc.name
				,_row = row_number() over (order by 
					case when isnull(@i_sort, '') in ('', 'Manifest/BOL') then description end asc,
					case when isnull(@i_sort, '') in ('Service Date') then service_date end desc,
					case when isnull(@i_sort, '') = 'Facility Name' then upc.name end asc,
					case when isnull(@i_sort, '') = 'Customer Name' then cust_name end asc,
					case when isnull(@i_sort, '') = 'Generator Name' then generator_name end asc,
					case when isnull(@i_sort, '') = 'Transaction Number' then receipt_id end desc,
					case when isnull(@i_sort, '') = 'Transaction Type' then trans_source end Asc,
					service_date desc, trans_source, description asc
					)
			from #newrex r
			join customer c (nolock) on r.customer_id = c.customer_id
			join generator g (nolock) on r.generator_id = g.generator_id
			left join USE_ProfitCenter upc (nolock) on r.company_id = upc.company_id and r.profit_ctr_id = upc.profit_ctr_id
			left join plt_image..scandocumenttype sdt (nolock) on r.type_id = sdt.type_id
		) x
		where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
		order by _row
		
	else -- Excel Output:


		select * from 
		(
			select
				r.*
				, c.cust_name
				, g.generator_name
				, g.epa_id
				, g.generator_city
				, g.generator_state
				, g.generator_country
				, g.site_code
				, g.site_type
				, g.generator_region_code
				, g.generator_division
				-- , sdt.document_type
				, upc.name
				,_row = row_number() over (order by 
					case when isnull(@i_sort, '') in ('', 'Manifest/BOL') then description end asc,
					case when isnull(@i_sort, '') in ('Service Date') then service_date end desc,
					case when isnull(@i_sort, '') = 'Facility Name' then upc.name end asc,
					case when isnull(@i_sort, '') = 'Customer Name' then cust_name end asc,
					case when isnull(@i_sort, '') = 'Generator Name' then generator_name end asc,
					case when isnull(@i_sort, '') = 'Transaction Number' then receipt_id end desc,
					case when isnull(@i_sort, '') = 'Transaction Type' then trans_source end Asc,
					service_date desc, trans_source, description asc, page_number asc
					)
			from #newrex r
			join customer c (nolock) on r.customer_id = c.customer_id
			join generator g (nolock) on r.generator_id = g.generator_id
			left join USE_ProfitCenter upc (nolock) on r.company_id = upc.company_id and r.profit_ctr_id = upc.profit_ctr_id
			left join plt_image..scandocumenttype sdt (nolock) on r.type_id = sdt.type_id
		) x
		order by _row


end -- NOT @i_export_images =1

return 0
END

GO

GRANT EXEC ON sp_COR_ManifestBOL_List TO EQAI;
GO
GRANT EXEC ON sp_COR_ManifestBOL_List TO EQWEB;
GO
GRANT EXEC ON sp_COR_ManifestBOL_List TO COR_USER;
GO
