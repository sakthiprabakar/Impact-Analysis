-- drop PROCEDURE sp_COR_reports_invoices_list
go

CREATE PROCEDURE [dbo].[sp_COR_reports_invoices_list]
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
AS
/* ***************************************************************************************************
sp_COR_reports_invoices_list:

Returns the data for Invoices.

LOAD TO PLT_AI* on NTSQL1

12/17/2018	JPB	Copy of sp_reports_invoices, modified for COR
07/31/2019	JPB	Added @generator input for searching by generator name/store number, also returning generator name/store num or "multiple" if more than 1 on a record.
10/10/2019	DevOps:11598 - AM - Added customer_id and generator_id temp tables and added receipt join.

exec [sp_COR_reports_invoices_list]
	@web_userid		= 'meltes29'
	, @start_date	= '2019-11-25T05:00:00.000Z'
	, @end_date		= '2019-11-26T05:00:00.000Z'
	, @search		= '554376'
	, @purchase_order = ''
	, @invoice_code = ''
	, @generator = ''
	, @generator_site_code = ''
	, @adv_search	= ''
	, @sort			= 'All'
	, @page			= 1
	, @perpage		= 10
	, @customer_id_list = ''
	, @generator_id_list = '' -- '122838,166653,173557,168778'

   
 SELECT  *  FROM    plt_image..scan WHERE image_id in (12722230, 12722243, 12722252, 12731650, 12731653, 12731675, 12759685, 12759686, 12759700, 12759701)
 
select * from invoiceheader where customer_id in (select customer_id from contactxref where contact_id =3682)

select * from invoicedetail where invoice_id = 1266040

1266039
1266040

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

declare @timer datetime = getdate()

select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid


if isnull(@i_sort, '') not in ('Invoice Number', 'Invoice Date', 'Due Date', 'Invoice Total', 'Attention','Customer Name') set @i_sort = ''
if isnull(@i_start_date, '1/1/1990') = '1/1/1990' set @i_start_date = '1/1/1990' else set @i_start_date = convert(date, @i_start_date)
if isnull(@i_end_date, '1/1/1999') = '1/1/1999' set @i_end_date = getdate() else set @i_end_date = convert(date, @i_end_date)
if datepart(hh, @i_end_date) = 0 set @i_end_date = @i_end_date + 0.99999

declare @invoicecode table (
	invoice_code	varchar(16)
)

insert @invoicecode
select left(row, 16) from dbo.fn_splitxsvtext(',', 1, @i_invoice_code)
where row is not null

declare @manifests table (
	manifest	varchar(15)
)

insert @manifests
select left(row, 15) from dbo.fn_splitxsvtext(',', 1, @i_manifest)
where row is not null


declare @po table (
	purchase_order	varchar(20)
)
insert @po
select left(row, 20) from dbo.fn_splitxsvtext(',', 1, @i_purchase_order)
where row is not null


declare @customer_ids table (
	customer_id	int
)
insert @customer_ids
select convert(int, row) from dbo.fn_splitxsvtext(',', 1, @i_customer_id_list)
where row is not null

declare @generator_ids table (
	generator_id	int
)
insert @generator_ids
select convert(int, row) from dbo.fn_splitxsvtext(',', 1, @i_generator_id_list)
where row is not null

declare @generator_tbl table (
	generator	varchar(75)
)

insert @generator_tbl
select left(row, 75) from dbo.fn_splitxsvtext(',', 1, @i_generator)
where row is not null

declare @generator_site_code_tbl table (
	site_code	varchar(16)
)

insert @generator_site_code_tbl
select left(row, 16) from dbo.fn_splitxsvtext(',', 1, @i_generator_site_code)
where row is not null


declare @foo table (invoice_id int, revision_id int, generator_id int, manifest varchar(20))
declare @bar table (invoice_id int, revision_id int, generator_id int, manifest varchar(20))

insert @foo
SELECT  
		x.invoice_id
		, x.revision_id
		, null
		, null
FROM    ContactCORInvoiceBucket x (nolock) 
WHERE x.contact_id = @i_contact_id
and x.invoice_date between @i_start_date and @i_end_date


if (select count(*) from @invoicecode) > 0 begin
	insert @bar
	select * 
	from @foo f
	where exists (
		select 1 from invoiceheader d
		where d.invoice_id = f.invoice_id and d.revision_id = f.revision_id
		and isnull(d.invoice_code, '') in (select invoice_code from @invoicecode)
	)
	delete from @foo
	insert @foo select * from @bar
	delete from @bar
end	

if (select count(*) from @manifests) > 0 begin
	insert @bar
	select * 
	from @foo f
	where exists (
		select 1 from invoicedetail d
		where d.invoice_id = f.invoice_id and d.revision_id = f.revision_id
		and isnull(d.manifest, '') in (select manifest from @manifests)
	)
	delete from @foo
	insert @foo select * from @bar
	delete from @bar
end	

if (select count(*) from @generator_tbl) > 0 begin
	insert @bar
	select * 
	from @foo f
	where exists (
		select 1 from invoicedetail d
		where d.invoice_id = f.invoice_id and d.revision_id = f.revision_id
		and d.generator_id in (
			select g.generator_id 
			from generator g
			join @generator_tbl x
			on g.generator_name like '%' + x.generator + '%'
			union
			select g.generator_id 
			from generator g
			join @generator_tbl x 
			on g.site_code like '%' + x.generator + '%'
		)
	)
	delete from @foo
	insert @foo select * from @bar
	delete from @bar
end	

if (select count(*) from @generator_site_code_tbl) > 0 begin
	insert @bar
	select * 
	from @foo f
	where exists (
		select 1 from invoicedetail d
		where d.invoice_id = f.invoice_id and d.revision_id = f.revision_id
		and d.generator_id in (
			select g.generator_id 
			from generator g
			join @generator_site_code_tbl x
			on g.site_code like '%' + x.site_code + '%'
		)
	)
	delete from @foo
	insert @foo select * from @bar
	delete from @bar
end	

if (select count(*) from @generator_ids) > 0 begin
	insert @bar
	select * 
	from @foo f
	where exists (
		select 1 from invoicedetail d
		where d.invoice_id = f.invoice_id and d.revision_id = f.revision_id
		and d.generator_id in (select generator_id from @generator_ids)
	)
	delete from @foo
	insert @foo select * from @bar
	delete from @bar
end	

if (select count(*) from @customer_ids) > 0 begin
	insert @bar
	select * 
	from @foo f
	where exists (
		select 1 from invoiceheader d
		where d.invoice_id = f.invoice_id and d.revision_id = f.revision_id
		and d.customer_id in (select customer_id from @customer_ids)
	)
	delete from @foo
	insert @foo select * from @bar
	delete from @bar
end	


if (select count(*) from @po) > 0 begin
	insert @bar
	select * 
	from @foo f
	where exists (
		select 1 from invoicedetail d
		where d.invoice_id = f.invoice_id and d.revision_id = f.revision_id
		and isnull(d.purchase_order, '') in (select purchase_order from @po)
	)
	delete from @foo
	insert @foo select * from @bar
end	


declare @v_search varchar(max) = ''
set @v_search = convert(varchar(max), replace(isnull(@i_search, ''), ' ', '%'))

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

update @foo set manifest =
	case when 1 < (select count(distinct manifest) from invoicedetail id
	where id.invoice_id = ih.invoice_id and id.revision_id = ih.revision_id
	and id.manifest is not null
	) then '(Multiple Manifests)'
	else
	(
		select top 1 id.manifest
		from invoicedetail id
			where id.invoice_id = ih.invoice_id and id.revision_id = ih.revision_id
			and id.manifest is not null
	)
	end
from @foo ih

--select datediff(ms, @timer, getdate()) as time_before_images
--select @timer  = getdate()

-- perform image searching here

	declare @ttype table (
		type_id	int
	)
	insert @ttype
	select type_id
	from plt_image..scandocumenttype (nolock)
	where document_type like '%manifest%'
	and view_on_web = 'T'

	declare @images table (
		invoice_id	int
		,revision_id	int
	, manifest			varchar(15)
	, image_id int
	, document_source		varchar(30)
	)

	declare @images2 table (image_id int
	, document_source		varchar(30)
		, manifest			varchar(15)
		, invoice_id		int
		, revision_id		int
		, file_type			varchar(10)
		, page_number		int
	)
	
	declare @rex table (
		invoice_id	int
		,revision_id	int
		,receipt_id	int
		,company_id	int
		,profit_ctr_id	int
		,trans_source	char(1)
		, manifest varchar(15)
	)
	
	insert @rex
	select distinct
		id.invoice_id
		, id.revision_id
		, id.receipt_id
		, id.company_id
		, id.profit_ctr_id
		, id.trans_source
		, id.manifest
	from @foo x
	join invoicedetail id (nolock) on x.invoice_id = id.invoice_id and x.revision_id = id.revision_id

--select datediff(ms, @timer, getdate()) as time_for_rex
--select @timer  = getdate()

	insert @images
	select id.invoice_id, id.revision_id, id.manifest, s.image_id, s.document_source
	from @rex id
	join plt_image..scan s (nolock)
		on id.receipt_id = s.receipt_id
		and id.profit_ctr_id = s.profit_ctr_id
		and id.company_id = s.company_id
	WHERE id.trans_source = 'R'
	union
	select id.invoice_id, id.revision_id, id.manifest, s.image_id, s.document_source
	from @rex id
	join plt_image..scan s (nolock)
		on id.receipt_id = s.workorder_id
		and id.profit_ctr_id = s.profit_ctr_id
		and id.company_id = s.company_id
	WHERE id.trans_source = 'W'

--select datediff(ms, @timer, getdate()) as time_for_images
--select @timer  = getdate()

	insert @images2
		select distinct
		b.image_id
		, b.document_source	--	varchar(30)
		, b.manifest		--	varchar(15)
		, b.invoice_id		--int
		, b.revision_id		--int
			, s.file_type
			, s.page_number
		from @images b
		join plt_image..scan s (nolock)
			on b.image_id = s.image_id
			and s.status = 'A'
			and s.type_id in (select type_id from @ttype)
			and s.document_source = 'receipt'
			and b.document_source = 'receipt'
			and s.view_on_web = 'T'
			and isnull(b.manifest, '') <> ''
		and isnull(s.document_name, '') + isnull(s.manifest, '') + isnull(s.scan_file, '') + isnull(s.description, '') like '%' + b.manifest + '%'
			
		insert @images2
		select distinct
		b.image_id
		, b.document_source	--	varchar(30)
		, b.manifest		--	varchar(15)
		, b.invoice_id		--int
		, b.revision_id		--int
			, s.file_type
			, s.page_number
		from @images b
		join plt_image..scan s (nolock)
			on b.image_id = s.image_id
			and s.status = 'A'
			and s.type_id in (select type_id from @ttype)
			and s.document_source = 'workorder'
			and b.document_source = 'workorder'
			and s.view_on_web = 'T'
			and isnull(b.manifest, '') <> ''
		and isnull(s.document_name, '') + isnull(s.manifest, '') + isnull(s.scan_file, '') + isnull(s.description, '') like '%' + b.manifest + '%'

--select datediff(ms, @timer, getdate()) as time_for_images2
--select @timer  = getdate()

-- both versions do this, then select from #rex as needed
	select * into #rex from (
		select
			ih.invoice_code,
			ih.invoice_date,
			ih.customer_id,
			ih.cust_name,
			ih.invoice_id,
			ih.revision_id,
			ih.invoice_image_id,
			ih.attachment_image_id,
			ih.total_amt_due,
			ih.due_date,
			ih.customer_po,
			ih.customer_release,
			ih.attention_name
			, generator_name = 
				case when x.generator_id = -100 then '(Multiple Generators)'
					else 
					g.generator_name
				end
			, generator_site_code = 
				case when x.generator_id = -100 then '(Multiple Generators)'
					else 
					g.site_code
				end
			, x.manifest
			, (
				select substring(
				(
					select distinct '| ' + id.manifest
					from InvoiceDetail id (nolock)
					where id.invoice_id = ih.invoice_id and id.revision_id = ih.revision_id
					and id.manifest is not null
					for xml path, TYPE).value('.[1]','nvarchar(max)'
				),2,20000)
			) as manifest_list
			, (
				select substring(
				(
					select distinct '| ' + g.generator_name
					from InvoiceDetail id (nolock)
					join generator g on id.generator_id = g.generator_id
					where id.invoice_id = ih.invoice_id and id.revision_id = ih.revision_id
					and id.generator_id is not null
					for xml path, TYPE).value('.[1]','nvarchar(max)'
				),2,20000)
			) as generator_name_list
			, (
				select substring(
				(
					select distinct '| ' + g.site_code
					from InvoiceDetail id (nolock)
					join generator g on id.generator_id = g.generator_id
					where id.invoice_id = ih.invoice_id and id.revision_id = ih.revision_id
					and g.site_code is not null
					for xml path, TYPE).value('.[1]','nvarchar(max)'
				),2,20000)
			) as generator_site_code_list
			, ih.currency_code
			, convert(varchar(max), null) manifest_image_list
			--, (select substring(
			--	(
			--select ', ' + i2.manifest + '|' + convert(varchar(20), i2.image_id) + '|' + i2.file_type + '|' + convert(varchar(20), isnull(i2.page_number,1))
			--	from @images2 i2 
			--	where i2.invoice_id = ih.invoice_id and i2.revision_id = ih.revision_id
			--		and i2.manifest is not null
			--	order by i2.manifest, i2.file_type, i2.page_number, i2.image_id
			--		for xml path, TYPE).value('.[1]','nvarchar(max)'
			--	),2,20000)
			--) as manifest_image_list
			,_row = row_number() over (order by 
				case when isnull(@i_sort, '') in ('', 'Invoice Number') then ih.invoice_code end desc,
				case when isnull(@i_sort, '') = 'Invoice Date' then ih.invoice_date end desc ,
				case when isnull(@i_sort, '') = 'Due Date' then ih.due_date end desc ,
				case when isnull(@i_sort, '') = 'Invoice Total' then ih.total_amt_due end ,
				case when isnull(@i_sort, '') = 'Attention' then ih.attention_name end asc,
				case when isnull(@i_sort, '') = 'Customer Name' then ih.cust_name end asc,
				ih.invoice_code asc
			) 

		from @foo x
			join InvoiceHeader ih (nolock) on x.invoice_id = ih.invoice_id and x.revision_id = ih.revision_id
			left join generator g (nolock) on isnull(x.generator_id, -100) <> -100 and x.generator_id = g.generator_id
		where 1=1
		-- and invoice_date > getdate()-(3*365)
			and 
		  (
			@v_search = ''
			or
			(
				@v_search <> ''
				and (
					(
						isnull(ih.cust_name, '') + ' ' + 
						isnull(ih.invoice_code, '') + ' ' +
						isnull(ih.attention_name, '') + ' ' +
						isnull(ih.customer_po, '') + ' '
						like '%' + @v_search + '%'
					)
					or
					(
						exists (select 1 from invoicedetail id (nolock) where id.invoice_id = ih.invoice_id and id.revision_id = ih.revision_id
								and isnull(id.manifest, '') like '%' + @v_search + '%'
								union
								select 1 from invoicedetail id (nolock) where id.invoice_id = ih.invoice_id and id.revision_id = ih.revision_id
								and isnull(id.purchase_order, '') like '%' + @v_search + '%'
								union
								select 1 from invoicedetail id (nolock) join generator gid (nolock) on id.generator_id = gid.generator_id 
								where id.invoice_id = ih.invoice_id and id.revision_id = ih.revision_id
								and isnull(gid.generator_name, '') like '%' + @v_search + '%'
								union
								select 1 from invoicedetail id (nolock) join generator gid (nolock) on id.generator_id = gid.generator_id 
								where id.invoice_id = ih.invoice_id and id.revision_id = ih.revision_id
								and isnull(gid.site_code, '') like '%' + @v_search + '%'
						)
					)
				)
			)
		)
	) y
--	where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
--	order by _row



if isnull(@excel_output, 0) = 0

SELECT  
	invoice_code,
	invoice_date,
	customer_id,
	cust_name,
	invoice_id,
	revision_id,
	invoice_image_id,
	attachment_image_id,
	total_amt_due,
	due_date,
	customer_po,
	customer_release,
	attention_name
	, generator_name 
	, generator_site_code 
	, manifest
	, manifest_list
	, generator_name_list
	, generator_site_code_list
	, currency_code
	, (select substring(
				(
			select ', ' + i2.manifest + '|' + convert(varchar(20), i2.image_id) + '|' + i2.file_type + '|' + convert(varchar(20), isnull(i2.page_number,1))
				from @images2 i2 
				where i2.invoice_id = #rex.invoice_id and i2.revision_id = #rex.revision_id
					and i2.manifest is not null
				order by i2.manifest, i2.file_type, i2.page_number, i2.image_id
					for xml path, TYPE).value('.[1]','nvarchar(max)'
				),2,20000)
			) as manifest_image_list
	, _row
FROM    #rex
	where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)
	order by _row

else
	-- Excel output...

	select * from #rex
	order by _row
	

RETURN 0

GO

GRANT EXECUTE ON sp_COR_reports_invoices_list TO EQAI, EQWEB, COR_USER
GO
