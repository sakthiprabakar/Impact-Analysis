-- drop proc if exists sp_cor_manifest_list
go

create proc sp_cor_manifest_list (
	@web_userid varchar(100) = ''
	, @start_date	datetime = null -- '1/1/2019' -- dateadd(yyyy, -5, getdate())
	, @end_date		datetime = null
	, @generator_id	int = null
	, @manifest		varchar(100) = null
	, @sort			varchar(20) = 'manifest' -- or 'service_date'
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
	, @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
)
as
/* **************************************************************************
sp_cor_manifest_list

development of New Retail Tile "Quick Search Service Documents"
DO:16580
-- this SP only returns matches to manifest and service dates, as if you were building auto-complete.

SELECT  * FROM    contact WHERE web_userid like '%amazon%'

Samples...

-- No search criteria = no results...
	sp_cor_manifest_list 
		@web_userid = 'AmazonWaste@Amazon.com'
		, @start_date	= null -- '1/1/2019' -- dateadd(yyyy, -5, getdate())
		, @end_date		= null
		, @generator_id	= null
		, @manifest		= null
		, @sort = null -- 'service_date'
		, @customer_id_list =''  
		, @generator_id_list ='' 

-- Will encounter multiple generators, so returns NO scan info, just the list of generators found.
-- The SP will only work when only 1 generator is in the result set.
	sp_cor_manifest_list 
		@web_userid = 'AmazonWaste@Amazon.com'
		, @start_date	= null -- '1/1/2019' -- dateadd(yyyy, -5, getdate())
		, @end_date		= null
		, @generator_id	= null
		, @manifest		= '0123132'
		, @sort = null
		, @customer_id_list =''  
		, @generator_id_list ='' 


-- will encounter just 1 generator, so you get results:
	sp_cor_manifest_list 
		@web_userid = 'AmazonWaste@Amazon.com'
		, @start_date	= null -- '1/1/2019' -- dateadd(yyyy, -5, getdate())
		, @end_date		= null
		, @generator_id	= 133799
		, @manifest		= null
		, @sort = 'service_date'
		, @customer_id_list =''  
		, @generator_id_list ='' 

Important Programming Notes!!:

	The Result_count field in results tells you the total result set size, if ever needed.
	
	Manifest Numbers are only searched from the beginning - not middle/end.
	
************************************************************************** */

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- This is easier than adding WITH (NOLOCK) to every table.

/*
-- Debugging:
DECLARE
	@web_userid varchar(100) = 'AmazonWaste@Amazon.com'
	, @start_date	datetime = null -- '1/1/2019' -- dateadd(yyyy, -5, getdate())
	, @end_date		datetime = null
	, @generator_id	int = 133799
	, @manifest		varchar(100) = null
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
	, @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */

*/

declare @i_web_userid varchar(100) = isnull(@web_userid, '')
	, @i_start_date datetime = isnull(@start_date, dateadd(yyyy, -5, getdate()))
	, @i_end_date	datetime = isnull(@end_date, getdate())
	, @i_generator_id	int = @generator_id
	, @i_manifest	varchar(100) = isnull(@manifest, '')
	, @i_sort	varchar(20) = isnull(@sort, 'manifest')
	, @i_contact_id	int
	, @i_generator_result_count int = 0
	, @i_customer_id_list varchar(max)= isnull(@customer_id_list, '')
    , @i_generator_id_list varchar(max)=isnull(@generator_id_list, '')
	
select top 1 @i_contact_id = contact_id from corcontact where web_userid = @i_web_userid

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
and isnull(@i_generator_id, m.generator_id) = m.generator_id
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
--and not ( -- ONE of these search terms is required
--	@i_generator_id is null
--	and isnull(@i_manifest, '') = ''
--	)

select * from (
	select
		(select count(*) from @matches) as result_count
		, manifest
		, service_date
		,_row = row_number() over (order by 

			case when isnull(@i_sort, '') in ('', 'manifest') then manifest end,
			case when isnull(@i_sort, '') = 'service_date' then service_date end desc,
			manifest asc
		) 
	from @matches
)x
order by _row

go

grant execute on sp_cor_manifest_list to eqai
go
grant execute on sp_cor_manifest_list to eqweb
go
grant execute on sp_cor_manifest_list to cor_user
go

