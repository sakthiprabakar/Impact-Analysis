--  drop PROCEDURE sp_COR_reports_invoices_data_list_lpx
go

CREATE PROCEDURE sp_COR_reports_invoices_data_list_lpx
	@web_userid		varchar(100) = ''
	, @start_date	datetime = null
	, @end_date		datetime = null
	, @search		varchar(max) = ''
	, @invoice_code		varchar(max)= ''	-- Invoice ID
	, @purchase_order	varchar(max) = ''
	, @adv_search	varchar(max) = ''
	, @manifest		varchar(max) = ''	-- Manifest list
	, @generator	varchar(max) = '' -- Generator Name/Store Number Search
	, @generator_site_code	varchar(max) = '' -- Generator Site Code / Store Number
	, @sort			varchar(20) = ''
	, @page			bigint = 1
	, @perpage		bigint = 20
	, @excel_output	int = 0
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
	, @headers_only	bit = 0	-- returns only distinct rows for only header info, not detail
    , @lpx_rollup_override int = 3
AS
/* ***************************************************************************************************
sp_COR_reports_invoices_data_list_lpx:

Returns the data for Invoices.

LOAD TO PLT_AI* on NTSQL1

12/17/2018	JPB	Copy of sp_reports_invoices, modified for COR
07/31/2019	JPB	Added @generator input for searching by generator name/store number, also returning generator name/store num or "multiple" if more than 1 on a record.
10/10/2019	DevOps:11597 - AM - Added customer_id and generator_id temp tables and added receipt join.

exec [sp_COR_reports_invoices_data_list_lpx]
	@web_userid		= 'nyswyn100'
	, @start_date	= '1/1/2000'
	, @end_date		= '12/31/2022'
	, @search		= ''
	, @purchase_order = ''
	, @invoice_code = ''
	, @generator = ''
	, @adv_search	= ''
	, @sort			= ''
	, @page			= 1
	, @perpage		= 2000
	
	, @headers_only = 1

exec [sp_COR_reports_invoices_data_list_lpx]
	@web_userid		= 'pk_test1'
	, @start_date	= '1/1/2000'
	, @end_date		= '12/31/2020'
	, @search		= ''
	, @purchase_order = ''
	, @invoice_code = '531771'
	, @generator = ''
	, @adv_search	= ''
	, @sort			= ''
	, @page			= 1
	, @perpage		= 2000
	, @customer_id_list = '' -- '15551'
	, @generator_id_list  = '' -- '122838,166653,173557,168778'
	, @headers_only = 1

22276
select * from invoiceheader where customer_id in (select customer_id from contactxref where contact_id =3682)

select * from invoicedetail where invoice_id = 464987

sp_help invoicedetail
SELECT  *  FROM    invoicedetail where manifest = 'MI8282919'


*************************************************************************************************** */

-- 	declare	@web_userid		varchar(100) = 'Jamie.Huens@wal-mart.com'		
-- declare	@web_userid		varchar(100) = 'customer.demo@usecology.com'		
-- declare	@web_userid		varchar(100) = 'amoser@capitolenv.com'	, @start_date	datetime = '1/1/2000'		, @end_date		datetime = '12/1/2016'		, @search		varchar(max) = 'med'		, @sort			varchar(20) = 'Generator Name'		, @page			bigint = 1	, @perpage		bigint = 20, @purchase_order varchar(max) = '', @invoice_code varchar(max) = '120039664, 120051282', @adv_search varchar(max) = ''

-- Avoid query plan caching:
declare @i_web_userid		varchar(100) = isnull(@web_userid, '')
	, @i_start_date	datetime = convert(date, isnull(@start_date, '1/1/1990'))
	, @i_end_date		datetime = convert(date, isnull(@end_date, getdate()))
	, @i_search		varchar(max) = isnull(@search, '')
	, @i_purchase_order	varchar(max) = isnull(@purchase_order, '')
	, @i_invoice_code varchar(max) = isnull(@invoice_code, '')
	, @i_adv_search	varchar(max) = isnull(@adv_search, '')
	, @i_manifest varchar(max) = isnull(@manifest, '')
	, @i_generator varchar(max) = isnull(@generator, '')
	, @i_generator_site_code varchar(max) = isnull(@generator_site_code, '')
	, @i_sort			varchar(20) = isnull(@sort, 'Invoice Number')
	, @i_page			bigint = isnull(@page, 1)
	, @i_perpage		bigint = isnull(@perpage, 20)
	, @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
	, @i_contact_id	int
	, @i_headers_only bit = isnull(@headers_only, 0)
    , @ilpx_rollup_override int = isnull(@lpx_rollup_override,3)

declare @out table (
	invoice_code	varchar(16),
	invoice_date	datetime,
	customer_id		int,
	cust_name		varchar(75),
	invoice_id		int,
	revision_id		int,
	invoice_image_id	int,
	attachment_image_id	int,
	total_amt_due	money,
	due_date		datetime,
	customer_po		varchar(20),
	customer_release	varchar(20),
	attention_name	varchar(40),
	generator_name	varchar(75),
	generator_site_code varchar(75),
	manifest		varchar(20),
	manifest_list	varchar(max),
	generator_name_list	varchar(max),
	generator_site_code_list varchar(max),
	currency_code char(3),
	manifest_image_list varchar(max),
	_row			bigint
)

insert @out
exec sp_cor_reports_invoices_list
	@web_userid		= @i_web_userid
	, @start_date	= @i_start_date
	, @end_date		= @i_end_date
	, @search		= @i_search
	, @invoice_code		= @i_invoice_code
	, @purchase_order	= @i_purchase_order
	, @adv_search	= @i_adv_search
	, @manifest		= @i_manifest
	, @generator	= @i_generator
	, @generator_site_code	= @i_generator_site_code
	, @sort			= @i_sort
	, @page			= 1
	, @perpage		= 999999999
	, @excel_output	= 0
	, @customer_id_list = @i_customer_id_list
    , @generator_id_list = @i_generator_id_list


declare @foo table (invoice_id int, revision_id int, generator_id int)
insert @foo
select invoice_id, revision_id, null from @out

update @foo set generator_id =
	case when 1 < (select count(distinct generator_id) from invoicedetail id
		where id.invoice_id = ih.invoice_id and id.revision_id = ih.revision_id
		and id.generator_id is not null
		) then -100 -- Multiple
		else 
		(
			select top 1 id.generator_id
			from invoicedetail id 
			where id.invoice_id = ih.invoice_id and id.revision_id = ih.revision_id
			and id.generator_id is not null
		)
	end
from @foo ih



-- assumption that there's only 1 use for this: excel output
-- if isnull(@excel_output, 0) = 0 

	if @i_headers_only = 1 begin
		select * from (
			select
				invoice_code
				, invoice_date
				, customer_id
				, cust_name
				, invoice_id
				, revision_id
				, invoice_image_id
				, attachment_image_id
				, total_amt_due
				, due_date
				, customer_po
				, customer_release
				, attention_name
				, generator_name
				, generator_site_code
				, manifest
				, manifest_list
				, generator_name_list
				, generator_site_code_list
				, currency_code
				, manifest_image_list
				,_row 
			from @out
		) y
	
	-- assumption that there's only 1 use for this: excel output
	--	where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
		order by _row

	end
	else
	begin
		select * 
		into #lpxdata
		from (
			select
				ih.invoice_code
				, ih.invoice_date
				, ih.customer_id
				, ih.cust_name
				, ih.invoice_id
				, ih.revision_id
				, ih.invoice_image_id
				, ih.attachment_image_id
				, ih.total_amt_due
				, ih.due_date
				, ih.customer_po
				, ih.customer_release
				, ih.attention_name
				, bc.service_date
				, upc.name
				, id.billing_project_id
				, cb.project_name
				, g.generator_name
				, g.generator_address_1
				, g.generator_address_2
				, g.generator_address_3
				, g.generator_city
				, g.generator_state
				, g.generator_zip_code
				, g.generator_country
				, g.generator_id
				, g.epa_id
				, g.site_type
				, g.site_code
				, g.generator_region_code
				, g.generator_division
				, case id.trans_source
					when 'R' then 'Receipt'
					when 'W' then 'Work Order'
					when 'O' then 'Order'
					else id.trans_source
					end trans_source
				, id.trans_source + CONVERT(varchar(10), id.receipt_id) + '-' + CONVERT(varchar(4),id.line_id ) + '-' + CONVERT(varchar(4), id.price_id) reference_id
				, id.approval_code
				, id.manifest
				, id.purchase_order
				, id.release_code
				, isnull(id.line_desc_1 + ' ', '') + isnull(id.line_desc_2, '') description			
				, id.qty_ordered quantity
				, id.bill_unit_code
				, bu.bill_unit_desc
				, id.unit_price price
				, id.extended_amt ext_price
				, id.currency_code
				, _row = convert(float, row_number() over (order by 
					case when isnull(@i_sort, '') in ('', 'Invoice Number') then ih.invoice_code end ,
					case when isnull(@i_sort, '') = 'Invoice Date' then ih.invoice_date end ,
					case when isnull(@i_sort, '') = 'Due Date' then ih.due_date end ,
					case when isnull(@i_sort, '') = 'Invoice Total' then ih.total_amt_due end ,
					case when isnull(@i_sort, '') = 'Attention' then ih.attention_name end asc,
					ih.invoice_code asc
					--, id.sequence_id asc
				)) 
				, id.company_id _company_id
				, id.profit_ctr_id _profit_ctr_id
				, id.receipt_id _receipt_id
				, id.line_id _line_id
				, id.price_id _price_id
				, id.sequence_id _sequence_id
				, resource_type = convert(varchar(60), null)
				, _labpack_quote_flag = convert(char(1), null)
				, _labpack_pricing_rollup = convert(char(1), null)
			from @foo x
				join InvoiceHeader ih (nolock) on x.invoice_id = ih.invoice_id and x.revision_id = ih.revision_id
				join invoicedetail id (nolock) on x.invoice_id = id.invoice_id and x.revision_id = id.revision_id
				join USE_ProfitCenter upc on id.company_id = upc.company_id and id.profit_ctr_id = upc.profit_ctr_id
				left join billingcomment bc (nolock) on --x.invoice_id = bc.invoice_id and 
					id.receipt_id = bc.receipt_id
					and id.company_id = bc.company_id 
					and id.profit_ctr_id = bc.profit_ctr_id
					and id.trans_source = bc.trans_source
				left join customerbilling cb (nolock) on ih.customer_id = cb.customer_id and id.billing_project_id = cb.billing_project_id
				left join generator g (nolock) on id.generator_id = g.generator_id
				left join billunit bu (nolock) on id.bill_unit_code = bu.bill_unit_code
			
			where 1=1
		) y
	
	
	update #lpxdata
	set _labpack_quote_flag = s.labpack_quote_flag
	, _labpack_pricing_rollup = s.labpack_pricing_rollup
	, resource_type = s.resource_type
	from 
	#lpxdata l
	join (
	  select isnull(qh.labpack_quote_flag, 'F') as 'labpack_quote_flag', qh.labpack_pricing_rollup
	  , d._receipt_id, d._line_id, d._price_id, d._company_id, d._profit_ctr_id, d.trans_source
	  , case wod.resource_type
		when 'D' then 'Disposal'
		when 'E' then 'Equipment'
		when 'L' then 'Labor'
		when 'O' then 'Other'
		when 'S' then 'Supplies'
		else null
		end as resource_type
	  from workorderheader h
	  join billing b
		on h.workorder_id = b.receipt_id
		and h.company_id = b.company_id
		and h.profit_ctr_id = b.profit_ctr_id
	  join workorderdetail wod
		on wod.workorder_id = b.receipt_id
		and wod.company_id = b.company_id
		and wod.profit_ctr_id = b.profit_ctr_id
	  join #lpxdata d
		on h.workorder_ID = d._receipt_id
		and b.line_id = d._line_id
		and b.price_id = d._price_id
		and h.company_id = d._company_id
		and h.profit_ctr_ID = d._profit_ctr_id
		and d.trans_source in ('Work Order', 'workorder')
		and wod.resource_type = b.workorder_resource_type
		and wod.sequence_id = b.workorder_sequence_id
	  left join workorderquoteheader  qh 
		on h.quote_id = qh.quote_id
		and h.company_id = qh.company_id
		and h.profit_ctr_id = qh.profit_ctr_id
	  union
	  select isnull(qh.labpack_quote_flag, 'F') as 'labpack_quote_flag', qh.labpack_pricing_rollup
	  , d._receipt_id, d._line_id, d._price_id, d._company_id, d._profit_ctr_id, d.trans_source
	  , case r.trans_type
		when 'D' then 'Disposal'
		when 'S' then 'Service'
		when 'W' then 'Wash'
		else null
		end as resource_type
	  from BillingLinkLookup bll
	  join #lpxdata d
		on bll.receipt_id = d._receipt_id
		and bll.company_id = d._company_id
		and bll.profit_ctr_ID = d._profit_ctr_id
		and d.trans_source in ('receipt')
	  join receipt r
		on d._receipt_id = r.receipt_id
		and d._company_id = r.company_id
		and d._profit_ctr_id = r.profit_ctr_id
		and d._line_id = r.line_id
	  join workorderheader h
		on bll.source_id = h.workorder_ID
		and bll.source_company_id = h.company_id
		and bll.source_profit_ctr_id = h.profit_ctr_ID
	  left join workorderquoteheader  qh 
		on h.quote_id = qh.quote_id
		and h.company_id = qh.company_id
		and h.profit_ctr_id = qh.profit_ctr_id
	  ) s
		on l._receipt_id = s._receipt_id
		and l._company_id = s._company_id
		and l._line_id = s._line_id
		and l._price_id = s._price_id
		and l._profit_ctr_id = s._profit_ctr_id
		and l.trans_source = s.trans_source
	
		update #lpxdata set _labpack_pricing_rollup = convert(char(1),@ilpx_rollup_override)
		where isnull(@ilpx_rollup_override, '3') <> isnull(_labpack_pricing_rollup, '3') 
	
	
		-- region Calculate LPX Subtotals
		drop table if exists #lpxdatasubtotal
		select 
		invoice_id
		, revision_id
		, invoice_code
		, invoice_date
		, trans_source, _receipt_id, _company_id, _profit_ctr_id
		, _labpack_pricing_rollup
		, resource_type + ' Subtotal' as resource_type, currency_code
		, sum(ext_price) as subtotal
		, max(_row) + 0.5 as _row
		into #lpxdatasubtotal
		from #lpxdata
		where isnull(_labpack_pricing_rollup, '3') in ('1', '2')
		group by invoice_id, revision_id
		, invoice_code
		, invoice_date
		, trans_source, _receipt_id, _company_id, _profit_ctr_id
		, _labpack_pricing_rollup
		, resource_type, currency_code

		update #lpxdata set price = null, ext_price = null where isnull(_labpack_pricing_rollup, '3') in ('1', '2')

		select
		invoice_code
		, invoice_date
		, customer_id
		, cust_name
		, invoice_id
		, revision_id
		, invoice_image_id
		, attachment_image_id
		, total_amt_due
		, due_date
		, customer_po
		, customer_release
		, attention_name
		, service_date
		, name
		, billing_project_id
		, project_name
		, generator_name
		, generator_address_1
		, generator_address_2
		, generator_address_3
		, generator_city
		, generator_state
		, generator_zip_code
		, generator_country
		, generator_id
		, epa_id
		, site_type
		, site_code
		, generator_region_code
		, generator_division
		, trans_source
		, reference_id
		, approval_code
		, manifest
		, purchase_order
		, release_code
		, description
		, quantity
		, bill_unit_code
		, bill_unit_desc
		, price
		, ext_price
		, currency_code
		, _row
		, _sequence_id
		from #lpxdata
    union all
	select
		invoice_code
		, invoice_date
		, null as customer_id
		, null as cust_name
		, null as invoice_id
		, null as revision_id
		, null as invoice_image_id
		, null as attachment_image_id
		, null as total_amt_due
		, null as due_date
		, null as customer_po
		, null as customer_release
		, null as attention_name
		, null as service_date
		, null as name
		, null as billing_project_id
		, null as project_name
		, null as generator_name
		, null as generator_address_1
		, null as generator_address_2
		, null as generator_address_3
		, null as generator_city
		, null as generator_state
		, null as generator_zip_code
		, null as generator_country
		, null as generator_id
		, null as epa_id
		, null as site_type
		, null as site_code
		, null as generator_region_code
		, null as generator_division
		, null as trans_source
		, null as reference_id
		, null as approval_code
		, null as manifest
		, null as purchase_order
		, null as release_code
		, resource_type as description
		, null as quantity
		, null as bill_unit_code
		, null as bill_unit_desc
		, null as price
		, subtotal as ext_price
		, currency_code
		, _row
		, null as _sequence_id
		from #lpxdatasubtotal
		order by _row, _sequence_id

end

RETURN 0

GO

GRANT EXECUTE ON sp_COR_reports_invoices_data_list_lpx TO EQAI, EQWEB, COR_USER
GO
