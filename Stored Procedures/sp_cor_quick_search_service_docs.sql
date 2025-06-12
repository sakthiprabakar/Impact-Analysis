-- drop proc if exists sp_cor_quick_search_service_docs
go

create proc sp_cor_quick_search_service_docs (
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
sp_cor_quick_search_service_docs

development of New Retail Tile "Quick Search Service Documents"
DO:16580

09/21/2021 - DO 19867 - Added upload_date to output

SELECT  * FROM    contact WHERE web_userid like '%amazon%'

Samples...

-- No search criteria = no results...
	sp_cor_quick_search_service_docs 
		@web_userid = 'AmazonWaste@Amazon.com'
		, @start_date	= null -- '1/1/2019' -- dateadd(yyyy, -5, getdate())
		, @end_date		= null
		, @generator_id	= null
		, @manifest		= null
		, @customer_id_list =''  
		, @generator_id_list ='' 

-- Will encounter multiple generators, so returns NO scan info, just the list of generators found.
-- The SP will only work when only 1 generator is in the result set.
	sp_cor_quick_search_service_docs 
		@web_userid = 'AmazonWaste@Amazon.com'
		, @start_date	= null -- '1/1/2019' -- dateadd(yyyy, -5, getdate())
		, @end_date		= null
		, @generator_id	= null
		, @manifest		= '0123'
		, @customer_id_list =''  
		, @generator_id_list ='' 


-- will encounter just 1 generator, so you get results:
	sp_cor_quick_search_service_docs 
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

/*
-- show inputs 
select @web_userid [@web_userid], @start_date [@start_date], @end_date [@end_date]
	, @i_manifest [@i_manifest], @i_generator_id [@i_generator_id]
	, @i_contact_id [@i_contact_id]
*/

declare @manifest_table table (
	manifest varchar(15)
)
insert @manifest_table
select left(row,15)
from dbo.fn_SplitXsvText(',',1,replace(@manifest,' ', ','))
WHERE row is not null

declare @customer table (
	customer_id	int
)
if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator table (
	generator_id	int
)
if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

if @i_generator_id is not null begin
	set @i_generator_id_list = @i_generator_id_list + ',' + convert(varchar(20), @i_generator_id)
	insert @generator values (@i_generator_id)
end

declare @scantype table (
	type_id	int
)
if @i_scan_type_id_list <> ''
insert @scantype select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_scan_type_id_list)
where row is not null

declare @imageid table (
	imageid	bigint
)
if @i_image_id_list <> ''
insert @imageid select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_image_id_list)
where row is not null


/*
Manifest/BOL Search user should be able to set the value using tab or enter 
and be able to remove the value using the x to match the rest of COR2.  
Should search , 

if generator is selected then manifest should be compared 
to the generator selected.  
If a generator is not selected.  
	***if user types in Manifest/BOL only and muli results 
			for same number are found then update generator info to "Multiple".  

***generator name, site address and epa id added to result set.  
If more than one generator record is found using the manifest bol 
then display a pop-up window presenting the user 
a message that indicates multi records found please check the one that 
applies.  

Pop-up should show the various locations and have a radio button 
for the user to select.

Once the selection is made then update result pane.

==

Implies there's auto-completion for manifest #'s, filterable by generator and date range
That's a new bucket table.  Can we generate that?

Several hours later, ContactCORManifestBucket exists.
SELECT  TOP 10 *	FROM    ContactCORManifestBucket 
*/

--SELECT  * FROM    workordermanifest WHERE  workorder_id = 1316100 and company_id = 14 and profit_ctr_id = 17

-- create index idx_bucket_1 on ContactCORManifestBucket (receipt_id, company_id, profit_ctr_id, source, pickup_date, receipt_date) include (customer_id, generator_id, manifest)

-- declare @i_contact_id int = 11289


declare @matches table (
	ContactCORManifestBucket_UID INT, 
	---------------------------
	source	VARCHAR(20) NOT NULL, /* Receipt or Work Order */
	contact_id INT NOT NULL,
	receipt_id INT NOT NULL, /* Receipt_id or Workorder_id */
	company_id INT NOT NULL,
	profit_ctr_id INT NOT NULL,
	---------------------------
	service_date	DATETIME NULL,
	receipt_date DATETIME NULL,
	---------------------------
	customer_id	INT null,
	generator_id INT null,
	---------------------------
	manifest VARCHAR(15) NOT NULL
)

insert @matches (ContactCORManifestBucket_UID, source, contact_id, receipt_id, company_id, profit_ctr_id, service_date, receipt_date, customer_id, generator_id, manifest)
SELECT  m.ContactCORManifestBucket_UID, m.source, m.contact_id, m.receipt_id, m.company_id, m.profit_ctr_id, m.service_date, m.receipt_date, m.customer_id, m.generator_id, m.manifest
FROM    ContactCORManifestBucket m
LEFT JOIN @manifest_table mt
	on m.manifest like mt.manifest + '%'
WHERE m.contact_id = @i_contact_id
-- and isnull(@i_generator_id, m.generator_id) = m.generator_id -- use @generator table instead
and isnull(m.service_date, m.receipt_date) between @i_start_date and @i_end_date
and isnull(m.service_date, m.receipt_date) > dateadd(yyyy, -5, getdate())
and (
	isnull(@i_manifest, '') = '' 
	or
	m.manifest like mt.manifest + '%'
)
and
(
    @i_customer_id_list = ''
    or
    (
		@i_customer_id_list <> ''
		and
		m.customer_id in (select customer_id from @customer)
	)
)
and
(
    @i_generator_id_list = ''
    or
    (
		@i_generator_id_list <> ''
		and
		m.generator_id in (select generator_id from @generator)
	)
)
and not ( -- ONE of these search terms is required
	(SELECT  COUNT(*) FROM @generator) = 0
	and isnull(@i_manifest, '') = ''
	)

select @i_generator_result_count = count(distinct generator_id) from @matches	
-- if @i_generator_result_count > 1 we don't need to plunder for scans because
-- the user is required to pick a specific generator to continue.

-- select count(*) [matches] from @matches
-- select * from @matches

/*
select s.image_id, s.type_id, sdt.document_type, s.document_name, s.file_type, s.page_number
, m.source, m.receipt_id, m.company_id, m.profit_ctr_id
from @matches m
join plt_image..scan s
	on m.receipt_id = case m.source when 'Receipt' then s.receipt_id else s.workorder_id end
	and m.company_id = s.company_id
	and m.profit_ctr_id = s.profit_ctr_id
	-- and s.document_source = case m.source when 'Receipt' then 'receipt' else 'workorder' end
	and s.status = 'A'
--	and s.view_on_web = 'T'
--join plt_image..scanimage si
--	on s.image_id = si.image_id
join plt_image..scandocumenttype sdt
	on s.type_id = sdt.type_id
--	and sdt.view_on_web = 'T'
ORDER BY m.receipt_id, m.company_id, m.profit_ctr_id, m.source

*/
-- set up scandocumenttype filters on like inputs
declare @sdt table (
	type_id	int
	, document_type	varchar(30)
)
insert @sdt (type_id, document_type)
select 
type_id
,document_type
from plt_image..ScanDocumentType t (nolock)
where t.view_on_web = 'T'
and t.status = 'A'

if @i_scan_type_id_list <> ''
delete from @sdt WHERE type_id not in (
	select type_id from @scantype
)


declare @s table (
	ContactCORManifestBucket_UID INT	
	, image_id	int
	, relation	varchar(20)
)

insert @s
select m.ContactCORManifestBucket_UID
	, s.image_id, 'input'
from @matches m
join plt_image..scan s
	on m.source = 'Receipt'
	and m.receipt_id = s.receipt_id
	and m.profit_ctr_id = s.profit_ctr_id
	and m.company_id = s.company_id
	and s.status = 'A'
	and s.type_id in (select type_id from @sdt)	
	and s.view_on_web = 'T'
where @i_generator_result_count = 1
--join plt_image..scanimage si
--	on s.image_id = si.image_id
union
select m.ContactCORManifestBucket_UID
	, s.image_id, 'input'
from @matches m
join plt_image..scan s
	on m.source = 'Work Order'
	and m.receipt_id = s.workorder_id
	and m.profit_ctr_id = s.profit_ctr_id
	and m.company_id = s.company_id
	and s.status = 'A'
	and s.type_id in (select type_id from @sdt)	
	and s.view_on_web = 'T'
where @i_generator_result_count = 1
--join plt_image..scanimage si
--	on s.image_id = si.image_id

-- SELECT  * FROM    @s

-- populate @san with related results if necessary
if exists (select 1 from @matches where source = 'receipt') and @i_generator_result_count = 1
		insert @s
		select m.ContactCORManifestBucket_UID
			, scan.image_id, 'related'
		from @matches m
		join billinglinklookup bll
			on bll.receipt_id = m.receipt_id
			and bll.company_id = m.company_id
			and bll.profit_ctr_id = m.profit_ctr_id
		join plt_image..scan
			on bll.source_id = scan.workorder_id
			and bll.source_company_id = scan.company_id
			and bll.source_profit_ctr_id = scan.profit_ctr_id
		where 
		m.source = 'Receipt'
		and scan.document_source = 'workorder'
		and scan.status = 'A'
		and scan.view_on_web ='T'
		and scan.type_id in (select type_id from @sdt)
		union -- Kroger relation from workorder on trip to receipt
		select m.ContactCORManifestBucket_UID, scan.image_id, 'related'
		from @matches m
		join receiptheader rh
			on rh.receipt_id = m.receipt_id
			and rh.company_id = m.company_id
			and rh.profit_ctr_id = m.profit_ctr_id
		join workorderheader woh
			on woh.trip_id = rh.trip_id
			and woh.trip_sequence_id = rh.trip_sequence_id
			and woh.trip_stop_rate_flag = 'T'
			AND rh.customer_id in (select customer_id from customer where isnull(eq_flag, '') = 'T')
			AND EXISTS (SELECT 1 from Receipt
						WHERE company_id = rh.company_id
						AND profit_ctr_id = rh.profit_ctr_id
						AND receipt_id = rh.receipt_id
						AND receipt_status <> 'V')
		JOIN TripHeader
			ON TripHeader.trip_id = woh.trip_id
			AND isnull(woh.trip_stop_rate_flag,'F') = 'T'
		join plt_image..scan
			on woh.workorder_id = scan.workorder_id
			and woh.company_id = scan.company_id
			and woh.profit_ctr_id = scan.profit_ctr_id
		where 
		m.source = 'receipt'
		and rh.receipt_id is not null and rh.company_id is not null and rh.profit_ctr_id is not null
		and rh.receipt_status not in ('V', 'R')
		and rh.trans_mode = 'I'
		and scan.document_source = 'workorder'
		and scan.status = 'A'
		and scan.view_on_web ='T'
		and scan.type_id in (select type_id from @sdt)

	
-- populate @san with related results if necessary
if exists (select 1 from @matches where source = 'work order') and @i_generator_result_count = 1
		insert @s
		select m.ContactCORManifestBucket_UID, scan.image_id, 'related'
		from @matches m
		join billinglinklookup bll
			on 	bll.source_id = m.receipt_id
			and bll.source_company_id = m.company_id
			and bll.source_profit_ctr_id = m.profit_ctr_id
		join plt_image..scan
			on bll.receipt_id = scan.receipt_id
			and bll.company_id = scan.company_id
			and bll.profit_ctr_id = scan.profit_ctr_id
		where 
		m.source = 'work order'
		and scan.document_source = 'receipt'
		and scan.status = 'A'
		and scan.view_on_web ='T'
		and scan.type_id in (select type_id from @sdt)
		union -- Kroger relation from workorder on trip to receipt
		select m.ContactCORManifestBucket_UID, scan.image_id, 'related'
		from @matches m 
		join workorderheader woh
			on woh.workorder_id = m.receipt_id
			and woh.company_id = m.company_id
			and woh.profit_ctr_id = m.profit_ctr_id			
		join receiptheader rh
			on woh.trip_id = rh.trip_id
			and woh.trip_sequence_id = rh.trip_sequence_id
			and woh.trip_stop_rate_flag = 'T'
			AND rh.customer_id in (select customer_id from customer where isnull(eq_flag, '') = 'T')
			AND EXISTS (SELECT 1 from Receipt
						WHERE company_id = rh.company_id
						AND profit_ctr_id = rh.profit_ctr_id
						AND receipt_id = rh.receipt_id
						AND receipt_status <> 'V')
		JOIN TripHeader
			ON TripHeader.trip_id = woh.trip_id
			AND isnull(woh.trip_stop_rate_flag,'F') = 'T'
		join plt_image..scan
			on rh.receipt_id = scan.receipt_id
			and rh.company_id = scan.company_id
			and rh.profit_ctr_id = scan.profit_ctr_id
		where 
		m.source = 'work order'
		and rh.receipt_id is not null and rh.company_id is not null and rh.profit_ctr_id is not null
		and rh.receipt_status not in ('V', 'R')
		and rh.trans_mode = 'I'
		and scan.document_source = 'receipt'
		and scan.status = 'A'
		and scan.view_on_web ='T'
		and scan.type_id in (select type_id from @sdt)

-- SELECT  * FROM    @matches
-- SELECT  * FROM    @s

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
insert @scan (
	ContactCORManifestBucket_UID
	, image_id
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
)
select distinct
	z.ContactCORManifestBucket_UID
	, s.image_id
	, s.document_source
	, s.document_name
	, s.manifest
	, sdt.type_id
	, sdt.document_type
	, s.page_number
	, s.file_type
	, z.relation
	, case s.document_source
		when 'receipt' then s.receipt_id
		when 'workorder' then s.workorder_id
		when 'customer' then s.customer_id
		when 'generator' then s.generator_id
		when 'form' then s.form_id
		when 'profile' then s.profile_id
		end 
	, case s.document_source
		when 'receipt' then s.company_id
		when 'workorder' then s.company_id
		when 'customer' then null
		when 'generator' then null
		when 'form' then null
		when 'profile' then null
		end 
	, case s.document_source
		when 'receipt' then s.profit_ctr_id
		when 'workorder' then s.profit_ctr_id
		when 'customer' then null
		when 'generator' then null
		when 'form' then null
		when 'profile' then null
		end 
from @s z
	join plt_image..scan s (nolock) on z.image_id = s.image_id
	join @sdt sdt on s.type_id = sdt.type_id
	-- join plt_image..scanimage si (nolock) on s.image_id = si.image_id

-- SELECT  '@scan' as [table], * FROM    @scan

delete from @scan where relation = 'related' and image_id in 
	(select image_id from @scan where relation = 'input')

-- SELECT  '@scan' as [table], * FROM    @scan


update @scan
set	in_image_id_list = 0
	, image_id_list = stuff((
		select ',' + convert(varchar(20), image_id)
	from @scan b
	WHERE 
	b.document_name = a.document_name
	and b.manifest = a.manifest
	and b.type_id = a.type_id
	and b.document_type = a.document_type
	and b.relation = a.relation
	and b.receipt_id = a.receipt_id
	and b.company_id = a.company_id
	and b.profit_ctr_id	= a.profit_ctr_id
	order by b.page_number
	for xml path('')
),1,1,'')
from @scan a


-- select a.image_id, a.page_number, b.min_page, c.value
update @scan set in_image_id_list = 1
from @scan a
join (
	select relation, receipt_id, company_id, profit_ctr_id, type_id, manifest, min(page_number) as min_page
	from @scan b
	GROUP BY relation, receipt_id, company_id, profit_ctr_id, type_id, manifest
) b /* min */
	on a.relation = b.relation
	and a.receipt_id = b.receipt_id
	and a.company_id = b.company_id
	and a.profit_ctr_id = b.profit_ctr_id
	and a.type_id = b.type_id
	and a.manifest = b.manifest
cross apply string_split(image_id_list, ',') c
where a.image_id = c.value 
and a.image_id_list like '%,%'
and a.page_number > b.min_page

drop table if exists #foo

SELECT  
	m.ContactCORManifestBucket_UID, 
	---------------------------
	m.source	,
	m.contact_id ,
	m.receipt_id matches_receipt_id,
	m.company_id matches_company_id,
	m.profit_ctr_id matches_profit_ctr_id,
	---------------------------
	m.service_date	,
	m.receipt_date ,
	---------------------------
	m.customer_id	,
	m.generator_id ,
	---------------------------
	m.manifest matches_manifest,

	s.image_id
	, s.document_source
	, s.document_name
	, s.manifest
	, s.type_id
	, s.document_type
	, s.page_number
	, s.file_type
	, s.relation
	, s.receipt_id
	, s.company_id
	, s.profit_ctr_id
	, case when isnull(page_number, 1) = 1 then 'T' else 'F' end as for_combined_display
	, isnull(( select substring(
	(
		select ', ' + 
		convert(varchar(20), image_id) + '|' + file_type + '|' + convert(varchar(20), page_number)
		FROM @scan b
		where s.document_source = b.document_source
		and s.document_name = b.document_name
		and isnull(s.manifest, '') = isnull(b.manifest, '')
		and s.type_id = b.type_id
		and s.document_type = b.document_type
		order by isnull(b.page_number, 1)
		for xml path, TYPE).value('.[1]','nvarchar(max)'
	),2,20000)	) , '')	as image_id_file_type_page_number_list
	, row_number() over (order by 
		m.contact_id ,
		m.service_date desc,
		m.source	,
		m.receipt_id ,
		m.company_id ,
		m.profit_ctr_id ,
		m.receipt_date ,
		m.customer_id	,
		m.generator_id ,
		m.manifest ,
		s.relation, s.company_id, s.profit_ctr_id, s.receipt_id, s.document_type, s.document_name, isnull(s.page_number, 1), s.image_id
		) as _ord
INTO #foo
FROM    @matches m 
left join @scan s 
	on m.ContactCORManifestBucket_UID = s.ContactCORManifestBucket_UID
WHERE s.image_id is not null
order by 
		m.contact_id ,
		m.service_date desc,
		m.source	,
		m.receipt_id ,
		m.company_id ,
		m.profit_ctr_id ,
		m.receipt_date ,
		m.customer_id	,
		m.generator_id ,
		m.manifest ,
		s.relation, s.company_id, s.profit_ctr_id, s.receipt_id, s.document_type, s.document_name, isnull(s.page_number, 1), s.image_id


-- SELECT  * FROM    #foo

update #foo set page_number = x.new_page_number
-- select x.new_page_number, f.*
from #foo f
join
	(
	-- SELECT  * FROM    #foo
	select source, document_source, document_name, manifest, type_id, document_type, file_type, _ord, 
	row_number() over (partition by source, document_source, document_name, manifest, type_id, document_type, file_type
	order by source, document_source, type_id, document_type, file_type, page_number) as new_page_number
	from #foo
) x
on f.source = x.source
and f.document_source = x.document_source
and f.document_name = x.document_name
and f.manifest = x.manifest
and f.type_id  = x.type_id
and f.document_type = x.document_type
and f.file_type = x.file_type
and f._ord = x._ord

--SELECT  '@scan' as [table], * FROM    @scan
--SELECT  '#foo' as [table], * FROM    #foo

update #foo set for_combined_display = case when isnull(page_number, 1) = 1 then 'T' else 'F' end,
	image_id_file_type_page_number_list = isnull(( select substring(
	(
		select ', ' + 
		convert(varchar(20), image_id) + '|' + file_type + '|' + convert(varchar(20), s.page_number)
		FROM @scan b
		where s.document_source = b.document_source
		and s.document_name = b.document_name
		and isnull(s.manifest, '') = isnull(b.manifest, '')
		and s.type_id = b.type_id
		and s.document_type = b.document_type
		order by isnull(s.page_number, 1)
		for xml path, TYPE).value('.[1]','nvarchar(max)'
	),2,20000)	) , '')
from #foo s

UPDATE #foo set for_combined_display = 'T' where image_id_file_type_page_number_list not like '%,%'

delete #foo where for_combined_display = 'F'

-- SELECT  '#foo' as [table], * FROM    #foo

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
	, row_number() over (order by _ord) as _ord
into #bar
from #foo
where for_combined_display = 'T'


-- SELECT  * FROM    #foo
drop table if exists #out

	SELECT DISTINCT
	@i_generator_result_count as generator_count
	, case when @i_generator_result_count = 1 then (select count(*) from #bar) else @i_generator_result_count end as result_count
	, f.document_type
	, f.document_name
	, case when @i_generator_result_count = 1 then f.service_date else null end service_date
	, f.file_type
	, f.for_combined_display
	, f.image_id
	, f.image_id_file_type_page_number_list
	, g.generator_id
	, g.generator_name
	, g.generator_address_1
	, g.generator_address_2
	, g.generator_address_3
	, g.generator_city
	, g.generator_state
	, g.generator_zip_code
	, g.epa_id
	, convert(datetime, null) upload_date
	-- , case when @i_generator_result_count = 1 then f._ord else null end _row
	-- , f._ord rowno
	into #out
	FROM    #bar f
	join generator g 
		on f.generator_id = g.generator_id

update #out set upload_date = coalesce(s.upload_date, s.date_modified, s.date_added)
from #out o 
join plt_image..scan s
	on o.image_id = s.image_id
	
update #out set result_count =
	case when @i_generator_result_count = 1 then (select count(*) from #out) else @i_generator_result_count end


begin try
	if object_id('tempdb..#ScanExport_Scan') is not null
	insert #ScanExport_Scan
	select * from @scan

	if object_id('tempdb..#ScanExport_Bar') is not null
	insert #ScanExport_Bar
	select * from #bar
end try
begin catch
	-- Nothing
end catch

set nocount off

select *
from
(
	SELECT  * 
	, row_number() over (order by 
		service_date desc,
		document_type,
		document_name
		) as _row
	FROM    #out 
) x
where 
	_row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
order by 
	case when @i_generator_result_count = 1 then _row else null end
	, generator_name

go

grant execute on sp_cor_quick_search_service_docs to cor_user
go
