-- drop proc sp_COR_received_load_report_list 
go

create proc sp_COR_received_load_report_list (
	@web_userid		varchar(100)
	, @start_date	datetime
	, @end_date		datetime
	, @search		varchar(max)
	, @adv_search	varchar(max)
	, @sort			varchar(20) = ''
	, @page			bigint = 1
	, @perpage		bigint = 20
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
)
as
/* ******************************************************************
Received Load Report
-- drop proc sp_COR_received_load_report_list

10/09/2019	DevOps:11595 - AM 	Added customer_id and generator_id temp tables and added receipt join.

inputs 
	
	Receipt Date From
	Receipt Date To
	Search-by (Generator Name, EPA ID, Receipt Number, Manifest, Approval Code, Waste Name)
	Contact ID

Paging info

select
	Receipt Date
	Generator Name
	EPA ID
	Receipt Number
	Manifest Reference
		Manifest
		Manifest Page
		Manifest Line
	Approval Code
	Waste Name
	Manifest Quantity
		Manifest Quantity
		Manifest Unit
		
	Attachment Name & Image ID pairs

order by?


select avg(_ct) from (
select contact_id, count(*) _ct from contactxref WHERE status = 'A' and web_access = 'A' group by contact_id
) x

select contact_id, count(*) _ct from contactxref WHERE status = 'A' and web_access = 'A' group by contact_id
having count(*) = 11

SELECT  *  FROM    contact where first_name = 'jamie' and email 

select p.profile_id, p.approval_desc*
from [Contact] c
join [ContactXref] x
	on c.contact_id = x.contact_id
	and x.status = 'A'
	and x.web_access = 'A'
join [Profile] p
	on case x.type 
		when 'C' then 
			case when p.customer_id  = x.customer_id then 1 else 0 end 
		when 'G' then 
			case when p.generator_id = x.generator_id then 1 else 0 end
		else 0 end = 1
where convert(Varchar(20), c.contact_id) = 100913

select email from contact where last_name = 'huens'
select email from contact where contact_id = 3682

SELECT  *  FROM    ContactReceiptBucket WHERE contact_id = 3682
SELECT  r.receipt_id, r.company_id, r.profit_ctr_id, r.line_id  FROM    Receipt r join ContactReceiptBucket x on r.receipt_id = x.receipt_id and r.company_id = x.company_id and r.profit_ctr_id = x.profit_ctr_id 
WHERE x.contact_id = 3682
and r.receipt_date between '1/1/2001' and '1/1/2002'
	and r.trans_mode = 'I' and r.trans_type = 'D'
	and r.receipt_status = 'A' and r.fingerpr_status = 'A'


Samples:

[sp_COR_received_load_report_list] 
	@web_userid = 'Jamie.Huens@Wal-Mart.com', 
	@start_date = '1/1/2010', 
	@end_date = '12/31/2010', 
	@search = '', 
	@adv_search = '',
	@sort = null, 
	@page = 1, 
	@perpage = 200
	
[sp_COR_received_load_report_list] 
	@web_userid = 'customer.demo@usecology.com', 
	@start_date = '1/1/2000', 
	@end_date = '12/31/2010', 
	@search = '', 
	@adv_search = '',
	@sort = null, 
	@page = 1, 
	@perpage = 200

[sp_COR_received_load_report_list] 
	@web_userid = 'amoser@capitolenv.com', 
	@start_date = '1/1/2015', 
	@end_date = '12/31/2018', 
	@search = '', 
	@adv_search = '',
	@sort = null, 
	@page = 1, 
	@perpage = 20,
	@customer_id_list = '5247,6886',
	@generator_id_list = '12967,130179,20998,13238'
	
****************************************************************** */

-- 	declare	@web_userid		varchar(100) = 'Jamie.Huens@wal-mart.com'		-- declare	@web_userid		varchar(100) = 'customer.demo@usecology.com'		-- declare	@web_userid		varchar(100) = 'amoser@capitolenv.com'	, @start_date	datetime = '1/1/2000'		, @end_date		datetime -- = '12/1/2016'		, @search		varchar(max) = 'med'		, @sort			varchar(20) = 'Generator Name'		, @page			bigint = 1	, @perpage		bigint = 20

-- Avoid query plan caching:
declare @i_web_userid		varchar(100) = @web_userid
	, @i_start_date	datetime = @start_date
	, @i_end_date		datetime = convert(date, @end_date)
	, @i_search		varchar(max) = convert(date, @search)
	, @i_adv_search	varchar(max) = @adv_search
	, @i_sort			varchar(20) = @sort
	, @i_page			bigint = @page
	, @i_perpage		bigint = @perpage
	, @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')

if isnull(@i_sort, '') not in ('Receipt Date', 'Generator Name', 'EPA ID', 'Receipt Number', 'Manifest Reference', 'Approval Code', 'Waste Name') set @i_sort = ''
if isnull(@i_start_date, '1/1/1999') = '1/1/1999' set @i_start_date = dateadd(m, -3, getdate())
if isnull(@i_end_date, '1/1/1999') = '1/1/1999' set @i_end_date = getdate()
if datepart(hh, @i_end_date) = 0 set @i_end_date = @i_end_date + 0.99999

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

declare @foo table (company_id int, profit_ctr_id int, receipt_id int, receipt_date datetime)

insert @foo
SELECT  
		x.company_id
		, x.profit_ctr_id
		, x.receipt_id
		, isnull(x.pickup_date, x.receipt_date)
FROM    ContactCORReceiptBucket x (nolock) 
join CORcontact c (nolock) on x.contact_id = c.contact_id and c.web_userid = @i_web_userid
WHERE isnull(x.pickup_date, x.receipt_date) between @i_start_date and @i_end_date

-- SELECT  *  FROM    #foo

declare @v_search varchar(8000)
set @v_search = convert(varchar(8000), replace(isnull(@i_search, ''), ' ', '%'))

select * from (
	select
		r.company_id
		, r.profit_ctr_id
		, r.receipt_id
		, r.receipt_date
		, r.line_id
		, g.generator_name
		, g.epa_id
		, r.manifest + isnull('-' + convert(varchar(3), r.manifest_page_num), '') + isnull('-' + convert(varchar(3), r.manifest_line), '') as manifest_reference
		, r.approval_code
		, r.manifest_dot_shipping_name as waste_desc
		, r.manifest_quantity
		, r.manifest_unit
		,_row = row_number() over (order by 
			case when isnull(@i_sort, '') in ('', 'Receipt Date') then r.receipt_date end desc,
			case when isnull(@i_sort, '') = 'Generator Name' then g.generator_name end asc,
			case when isnull(@i_sort, '') = 'EPA ID' then g.epa_id end asc,
			case when isnull(@i_sort, '') = 'Receipt Number' then r.receipt_id end desc,
			case when isnull(@i_sort, '') = 'Manifest Reference' then r.manifest end asc,
			case when isnull(@i_sort, '') = 'Approval Code' then r.approval_code end asc,
			case when isnull(@i_sort, '') = 'Waste Name' then convert(varchar(max), r.manifest_dot_shipping_name) end asc
			, r.receipt_id asc, r.line_id asc
		) 
	from @foo x
	join receipt r (nolock) on x.receipt_id = r.receipt_id and x.company_id = r.company_id and x.profit_ctr_id = r.profit_ctr_id
		and r.trans_mode = 'I' and r.trans_type = 'D'
		and r.receipt_status = 'A' and r.fingerpr_status = 'A'
	join generator g (nolock) on r.generator_id = g.generator_id
	where 1=1
	and 
	  (
        @i_customer_id_list = ''
        or
         (
			@i_customer_id_list <> ''
			and
			r.customer_id in (select customer_id from @customer)
		 )
	   )
    and
	 (
        @i_generator_id_list = ''
        or
        (
			@i_generator_id_list <> ''
			and
			r.generator_id in (select generator_id from @generator)
		)
	  )

	and 
	(
		@v_search = ''
		or
		(
		@v_search <> ''
		and 
		g.generator_name + ' ' +
		g.epa_id + ' ' + 
		convert(varchar(20), r.receipt_id) + ' ' +
		r.manifest + ' ' +
		r.approval_code + ' ' +
		convert(varchar(max), r.manifest_dot_shipping_name)
		like '%' + @v_search + '%'
		)
	)

) y
inner join billunit b (nolock) on y.manifest_unit = b.manifest_unit
where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
order by _row


RETURN 0


GO

GRANT EXECUTE ON [dbo].[sp_COR_received_load_report_list] TO COR_USER;

GO