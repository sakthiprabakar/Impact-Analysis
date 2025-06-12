-- drop proc if exists sp_cor_linked_transaction_list
go

create proc sp_cor_linked_transaction_list (
	@web_userid varchar(100) = ''
	, @trans_source	char(1) = '' /* "W"orkorder or "R"eceipt */
	, @receipt_id int = null	 /* Workorder_id or Receipt_id */
	, @company_id int = null
	, @profit_ctr_id int = null
)
as
/* ******************************************************************
sp_cor_linked_transaction_list

Returns list of linked work orders/receipts for an input tranaction

	select * from contact WHERE web_userid = 'nyswyn100'
	select bll.*
	from ContactCORReceiptBucket rb (nolock)
	join billinglinklookup bll (nolock)
		on rb.receipt_id= bll.receipt_id
		and rb.company_id = bll.company_id
		and rb.profit_ctr_id = bll.profit_ctr_id
	WHERE rb.contact_id = 11289
	union
	select bll.*
	from ContactCORWorkorderHeaderBucket wb (nolock)
	join billinglinklookup bll (nolock)
		on wb.workorder_id = bll.source_id
		and wb.company_id = bll.source_company_id
		and wb.profit_ctr_id = bll.source_profit_ctr_id
	WHERE wb.contact_id = 11289

History
	02/15/2021	JPB		Created

Sample
	exec sp_cor_linked_transaction_list
		@web_userid = 'nyswyn100'
		, @trans_source	= 'W' /* "W"orkorder or "R"eceipt */
		, @receipt_id = 12517000	 /* Workorder_id or Receipt_id */
		, @company_id = 14
		, @profit_ctr_id = 0

****************************************************************** */

/*
-- debuggery:
declare 
	@web_userid varchar(100) = 'nyswyn100'
	, @trans_source	char(1) = 'W' /* "W"orkorder or "R"eceipt */
	, @receipt_id int = 12517000	 /* Workorder_id or Receipt_id */
	, @company_id int = 14
	, @profit_ctr_id int = 0
*/

declare @i_web_userid		varchar(100) = isnull(@web_userid, '')
	, @i_contact_id			int
	, @i_trans_source		char(1) = isnull(@trans_source, '')
	, @i_receipt_id			int = isnull(@receipt_id, 0)
	, @i_company_id			int = isnull(@company_id, 0)
	, @i_profit_ctr_id		int = isnull(@profit_ctr_id, 0)

select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid

select 'Work Order' as linked_transaction_type
	, bll.source_id as linked_id
	, bll.source_company_id linked_company_id
	, bll.source_profit_ctr_id linked_profit_ctr_id
	, upc.name facility_name
	, coalesce(wb.service_date, wb.start_date) transaction_date
	, wb.generator_id
	, manifest_list = 
			substring((select distinct ', ' + 
			case when wom.manifest_flag = 'T' then 
				-- case when wom.manifest_state = 'H' then 'Haz ' else 'Non-Haz ' end 
			+ 'Manifest ' else 'BOL ' end
			+ wom.manifest
			from workordermanifest wom (nolock)
			where wom.workorder_id = bll.source_id and wom.company_id = bll.source_company_id and wom.profit_ctr_id = bll.source_profit_ctr_id 
			and wom.manifest not like 'manifest__%'
			for xml path, TYPE).value('.[1]','nvarchar(max)'), 2, 20000)
from ContactCORReceiptBucket rb (nolock)
join billinglinklookup bll (nolock)
	on rb.receipt_id= bll.receipt_id
	and rb.company_id = bll.company_id
	and rb.profit_ctr_id = bll.profit_ctr_id
join USE_ProfitCenter upc
	on bll.source_company_id = upc.company_id
	and bll.source_profit_ctr_id = upc.profit_ctr_id
join ContactCORWorkOrderHeaderBucket wb
	on bll.source_id = wb.workorder_id
	and bll.source_company_id = wb.company_id
	and bll.source_profit_ctr_id = wb.profit_ctr_id
	and wb.contact_id = rb.contact_id
WHERE rb.contact_id = @i_contact_id
	and @i_trans_source = 'R'
	and @i_receipt_id = bll.receipt_id
	and @i_company_id = bll.company_id
	and @i_profit_ctr_id = bll.profit_ctr_id
union
select 'Receipt' as linked_transaction_type
	, bll.receipt_id as linked_id
	, bll.company_id as linked_company_id
	, bll.profit_ctr_id as linked_profit_ctr_id
	, upc.name facility_name
	, rb.receipt_date transaction_date
	, rb.generator_id
	, manifest_list = 
		substring((select distinct ', ' + 
		case r.manifest_flag when 'M' then 'Manifest ' else 'BOL ' end
		+ r.manifest
		from receipt r (nolock)
		where r.receipt_id = rb.receipt_id
		and r.company_id = rb.company_id
		and r.profit_ctr_id = rb.profit_ctr_id
		for xml path, TYPE).value('.[1]','nvarchar(max)'), 2, 20000)
from ContactCORWorkorderHeaderBucket wb (nolock)
join billinglinklookup bll (nolock)
	on wb.workorder_id = bll.source_id
	and wb.company_id = bll.source_company_id
	and wb.profit_ctr_id = bll.source_profit_ctr_id
join USE_ProfitCenter upc
	on bll.company_id = upc.company_id
	and bll.profit_ctr_id = upc.profit_ctr_id
join ContactCORReceiptBucket rb
	on bll.receipt_id = rb.receipt_id
	and bll.company_id = rb.company_id
	and bll.profit_ctr_id = rb.profit_ctr_id
	and wb.contact_id = rb.contact_id
WHERE wb.contact_id = @i_contact_id
	and @i_trans_source = 'W'
	and @i_receipt_id = bll.source_id
	and @i_company_id = bll.source_company_id
	and @i_profit_ctr_id = bll.source_profit_ctr_id

go

grant execute on sp_cor_linked_transaction_list to cor_user
go
grant execute on sp_cor_linked_transaction_list to eqweb
go
grant execute on sp_cor_linked_transaction_list to eqai
go

