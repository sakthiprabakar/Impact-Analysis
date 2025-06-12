-- 
drop proc if exists sp_packback_order_history
go

create proc sp_packback_order_history (
	@contact_id			int = null			-- EITHER contact_id OR email is required
	, @email			varchar(60) = null	-- otherwise SP returns only 1 matching order.
	
	, @ship_city		varchar(40) = null
	, @ship_state		varchar(max) = null -- csv
	, @ship_attention_name	varchar(40) = null
	, @order_id_list	varchar(max) = null -- csv
	, @tracking_id_list	varchar(max) = null -- csv
	, @status_list		varchar(max) = null -- csv of: 'Pending Shipment', 
	, @order_date_start	datetime = null
	, @order_date_end	datetime = null
	, @page				int = 1
	, @perpage			int = 20
) as
/* *******************************************************************************
sp_packback_order_history

	Returns order history list

History
	7/22/2022 JPB	Created
	8/02/2022 JPB	Contact_id/Email are no longer required, but if not given
					then only 1 order_id will be returned.
					Primarily useful for searching on 1 order_id/tracking #.
					Oh, also added tracking # input.

sp_columns orderheader
select distinct contact_id from orderheader

SELECT  TOP 100 *
FROM    orderheader
ORDER BY order_date desc

select distinct status from orderheader

SELECT  TOP 100 *
FROM    orderitem

sp_packback_order_history @contact_id = 106152, @page=3

sp_packback_order_history @email = 'paul.kalinka@usecology.com', @order_date_start = '1/1/2000', @perpage= 20000
sp_packback_order_history @order_date_start = '1/1/2000', @perpage= 20000

sp_packback_order_history @tracking_id_list = '1Z584Y450346410547'
sp_packback_order_history @order_id_list = '11497'

SELECT  * FROM    orderheader WHERE  order_id = 11508
SELECT  * FROM    orderdetail WHERE  order_id = 11508
SELECT  * FROM    orderitem WHERE  order_id = 11508
SELECT  * FROM    orderheader WHERE  order_id = 11507
SELECT  * FROM    orderdetail WHERE  order_id = 11507
SELECT  * FROM    orderitem WHERE  order_id = 11507

select top 100 * from orderitem ORDER BY order_id desc

******************************************************************************* */

/*
-- debugging:
declare
	@contact_id			int = 106152			-- EITHER contact_id OR email is required
	, @email			varchar(60) = null	-- otherwise SP returns nothing
	
	, @ship_city		varchar(40) = null
	, @ship_state		varchar(max) = null -- csv
	, @ship_attention_name	varchar(40) = null
	, @order_id_list	varchar(max) = null -- csv
	, @status_list		varchar(max) = null -- csv of: 'Pending Shipment', 
	, @order_date_start	datetime = '1/1/2000'
	, @order_date_end	datetime = null
	, @page				int = 1
	, @perpage			int = 2000

-- SELECT  * FROM    contact WHERE email like'%frederick%'
-- 106152 emily.frederick@usecology.com

-- declare @contact_id int = 106152, @email varchar(60) = null
*/
declare
	@i_contact_id			int = isnull(@contact_id, -1111)			-- EITHER contact_id OR email is required
	, @i_email			varchar(60) = isnull(@email, '-1111')	-- otherwise SP returns nothing
	
	, @i_ship_city		varchar(40) = isnull(@ship_city, '')
	, @i_ship_state		varchar(max) = isnull(@ship_state, '')
	, @i_ship_attention_name	varchar(40) = isnull(@ship_attention_name, '')
	, @i_order_id_list	varchar(max) = isnull(@order_id_list, '') -- csv
	, @i_tracking_id_list	varchar(max) = isnull(@tracking_id_list, '') -- csv
	, @i_order_date_start	datetime = isnull(@order_date_start, getdate()-(365 * 3))
	, @i_order_date_end	datetime = isnull(@order_date_end, getdate())
	, @i_page				int = isnull(@page, 1)
	, @i_perpage			int = isnull(@perpage, 20)

Drop Table If Exists #keys
Drop Table If Exists #keys2
Drop Table If Exists #keys3
Drop Table If Exists #status
Drop Table If Exists #output

declare @ship_states table (
	state_name varchar(50)
	, country	varchar(3)
)
if @i_ship_state <> ''
insert @ship_states (state_name, country)
select sa.abbr, sa.country_code
from dbo.fn_SplitXsvText(',', 1, @i_ship_state) x
join stateabbreviation sa
on (
	sa.state_name = x.row and x.row not like '%-%'
	or
	sa.abbr = x.row and x.row not like '%-%'
	or
	sa.abbr + '-' + sa.country_code = x.row and x.row like '%-%'
	or
	sa.country_code  + '-' + sa.abbr= x.row and x.row like '%-%'
)
and sa.country_code = 'USA' -- Packback serves US customers
where row is not null

declare @order_ids table (
	order_id	int
)
if @i_order_id_list <> ''
insert @order_ids (order_id)
select convert(int, row)
from dbo.fn_SplitXsvText(',', 1, @i_order_id_list) x
WHERE row is not null

declare @tracking_ids table (
	tracking_id	varchar(50)
)
if @i_tracking_id_list <> ''
insert @tracking_ids (tracking_id)
select row
from dbo.fn_SplitXsvText(',', 1, @i_tracking_id_list) x
WHERE row is not null

-- #Keys1: Just matches on the 2 critical identifiers: contact_id/email
-- 1.1 only 1 condition was provided
select oh.order_id, 'contact_id match, no email searched' as match_type
into #keys
from orderheader oh
	WHERE oh.contact_id = isnull(@contact_id, -111)
	and @i_email = '-1111'
union
select oh.order_id, 'customer_id match, no email searched' as match_type
from orderheader oh
WHERE oh.customer_id in (
	select customer_id 
	from CORContactXref 
	WHERE type = 'C' 
	and contact_id = isnull(@contact_id, -111)
	)
	and @i_email = '-1111'
union
select oh.order_id, 'email match, no contact_id searched' as match_type
from orderheader oh
	WHERE oh.email = isnull(@email, '-1111')
	and @i_contact_id = -1111
-- 1.2 both conditions were provided
union
select oh.order_id, 'contact_id and email match' as match_type
from orderheader oh
	WHERE oh.contact_id = isnull(@contact_id, -111)
	and oh.email = @i_email
union
select oh.order_id, 'customer_id and email match' as match_type
from orderheader oh
WHERE oh.customer_id in (
	select customer_id 
	from CORContactXref 
	WHERE type = 'C' 
	and contact_id = isnull(@contact_id, -111)
	)
	and oh.email = @i_email
union
select oh.order_id, 'email and contact_id match' as match_type
from orderheader oh
	WHERE oh.email = isnull(@email, '-111')
	and oh.contact_id = @i_contact_id

-- SELECT  * FROM    #keys ORDER BY order_id
	

-- #keys2: order_id/tracking_id
create table #keys2 (order_id int, _row int identity(1,1))
insert #keys2 (order_id)
select oh.order_id
from orderheader oh
where oh.status not in ('V')
and @i_order_id_list <> ''
and (
	oh.order_id in (select order_id from @order_ids)
)
union
select k.order_id
from orderitem k
where 
@i_tracking_id_list <> ''
and (
	k.tracking_barcode_shipped in (select tracking_id from @tracking_ids)
	or
	k.tracking_barcode_returned in (select tracking_id from @tracking_ids)
)

if (select count(*) from #keys) = 0 -- no contact_id or email was given
	if (select count(*) from #keys2) > 0 -- order_id or tracking_id was found
		-- only bring along the top 1 order_id
		insert #keys (order_id, match_type) select top 1 order_id, '#Keys2 match' from #keys2
		

-- Note: Individual ITEMS on an order have their own status, not the whole order
-- or rather, in *addition* to the whole order.	
-- So we'll push a null status column in this #keys3 table
-- and populate it after.

	
-- #keys3: search criteria
select distinct k.order_id, convert(varchar(60), null) as status
into #keys3
from #keys k
join orderheader oh 
	on k.order_id = oh.order_id
WHERE 
oh.status not in ('V') -- not void
and
(
	@i_ship_city = ''
	or
	oh.ship_city like '%' + @i_ship_city + '%'
)
and
(
	@i_ship_state = ''
	or
	exists (select 1 from @ship_states WHERE state_name = oh.ship_state and country = 'USA')
)
and
(
	@i_ship_attention_name = ''
	or
	oh.ship_attention_name like '%' + @i_ship_attention_name + '%'
)
and
(
	isnull(@i_order_id_list,'') + isnull(@i_tracking_id_list,'') = ''
	or
	oh.order_id in (select order_id from #keys2)
)
and
(
	oh.order_date >= @i_order_date_start 
	and
	oh.order_date <= @i_order_date_end
)

-- SELECT  * FROM    #keys3 ORDER BY order_id
-- Drop Table If Exists #status

-- Now populate order status
select k.order_id
	, od.line_id
	, oi.sequence_id
	, od.product_id
	, k.status
	, convert(int, null) as status_order 
into #status
from #keys3 k
join orderdetail od on k.order_id = od.order_id
		and od.status not in ('V')
left join orderitem oi on od.order_id = oi.order_id
	and oi.line_id = od.line_id
	and oi.product_id = od.product_id

-- SELECT  * FROM    #status
	
-- 1. "N"ew orderheader is for a brand new order.
update k set status = 'Pending Shipment', status_order = 1
from #status k
join orderheader oh on k.order_id = oh.order_id
WHERE oh.status = 'N'
and k.status is null

-- Need to process these from last-est status to earliest
update k set status = 'Recycled', status_order = 4
from #status k
	inner join OrderItem oi
		on oi.order_id = k.order_id
		and oi.line_id = k.line_id
		and oi.sequence_id = k.sequence_id
		and oi.product_id = k.product_id
	inner join OrderDetail od 
		on oi.order_id = od.order_id
		and oi.line_id = od.line_id
		and oi.product_id = od.product_id 
		and od.status not in ('V')
	where
		oi.outbound_receipt_id is not null
		and exists (
			select s.image_id 
				from Plt_Image..Scan s 
				inner join Plt_Image..ScanDocumentType sdt 
					on s.type_id = sdt.type_id
					and sdt.document_Type = 'COR' 
				inner join Receipt r
					on s.receipt_id = r.receipt_id
					and s.company_id = r.company_id
					and s.profit_ctr_id = r.profit_ctr_id
					and r.trans_mode = 'O'
				where
					s.receipt_id = oi.outbound_receipt_id
					and s.company_id = od.company_id
					and s.profit_ctr_id = od.profit_ctr_id
					and s.document_source = 'receipt'
					and s.status = 'A'
		)
and k.status is null

update k set status = 'Received', status_order = 3
from #status k
	inner join OrderItem oi
		on oi.order_id = k.order_id
		and oi.line_id = k.line_id
		and oi.sequence_id = k.sequence_id
		and oi.product_id = k.product_id
	inner join OrderDetail od 
		on oi.order_id = od.order_id
		and oi.line_id = od.line_id
		and oi.product_id = od.product_id 
		and od.status not in ('V')
	where
	oi.date_returned is not null
and k.status is null

update k set status = 'Shipped', status_order = 2
from #status k
	inner join OrderItem oi
		on oi.order_id = k.order_id
		and oi.line_id = k.line_id
		and oi.sequence_id = k.sequence_id
		and oi.product_id = k.product_id
	inner join OrderDetail od 
		on oi.order_id = od.order_id
		and oi.line_id = od.line_id
		and oi.product_id = od.product_id 
		and od.status not in ('V')
	where
	oi.date_shipped is not null
and k.status is null


/*
-- If we only wanted to report the "minimum" status per order...

update k set status = d.status
from #keys3 k
join (
	select order_id, min(status_order) status_order
	from #status GROUP BY order_id
) m on k.order_id = m.order_id
join (
	select distinct status_order, status from #status
) d
on m.status_order = d.status_order

*/

select
	convert(varchar(20), oh.order_id) + 
		isnull('-' + convert(varchar(20), od.line_id), '') +
		isnull('-' + convert(varchar(20), oi.sequence_id), '') 
		as display_order_id
	, oh.order_id
	, od.line_id
	, oi.sequence_id
	, oh.customer_id
	, oh.ship_cust_name
	, oh.contact_id
	, oh.email
	, oh.ship_city
	, oh.ship_state
	, oh.ship_attention_name
	, oh.ship_phone
	, oh.contact_first_name
	, oh.contact_last_name
	, oh.order_date
	, p.product_id
	, p.product_code
	, p.description
	, p.ship_width
	, p.ship_height
	, p.ship_weight
	, p.return_length
	, p.return_width
	, p.return_height
	, p.return_weight
	, p.cor_available_flag -- certificate of recycling
	, p.short_description
	, p.return_description
	, p.summary_description
	, p.html_description
	, p.web_image_name_thumb
	, p.web_image_name_full
	, p.return_weight_required_flag
	, rpc.name as category_name
	, rpc.product_category_id
	, rpc.category_order
	, s.status
	, oi.tracking_barcode_shipped
	, oi.date_shipped
	, oi.tracking_barcode_returned
	, oi.date_returned
	/*
	, oh.total_amt_order
	, oh.currency_code
	, (select count(*) from orderdetail od where od.order_id = oh.order_id) as item_count
	*/
	, row_number() over (order by oh.order_id desc, od.line_id, oi.sequence_id) as _row
	, convert(int, null) as _total_rows
into #output
from #keys3 k
join orderheader oh on oh.order_id = k.order_id
join orderdetail od on oh.order_id = od.order_id
join product p on od.product_id = p.product_id and od.company_id = p.company_id and od.profit_ctr_id = p.profit_ctr_id
join RetailProductCategory rpc on rpc.product_category_id = p.product_category_id
join #status s on oh.order_id = s.order_id and od.line_id = s.line_id and od.product_id = s.product_id
left join orderitem oi on od.order_id = oi.order_id and od.line_id = oi.line_id and od.product_id = oi.product_id and oi.sequence_id = s.sequence_id

update #output set _total_rows = @@rowcount

select * 
from #output
where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
order by _row

go

grant execute on sp_packback_order_history to cor_user
go
