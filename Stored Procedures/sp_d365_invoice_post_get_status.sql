if exists (select 1 from sysobjects where type = 'P' and name = 'sp_d365_invoice_post_get_status')
	drop procedure dbo.sp_d365_invoice_post_get_status
go

create procedure [dbo].[sp_d365_invoice_post_get_status]
	@invoice_from varchar(12) = null,
	@invoice_to varchar(12) = null,
	@date_from datetime = null,
	@date_to datetime = null,
	@status char(1) = null
as
/***************************************************************
Loads to:   Plt_AI

Query the status of a range of invoices (called by the new Post Status tab)

09/17/2019 RWB	Created

****************************************************************/

set transaction isolation level read uncommitted

if coalesce(@invoice_to,'') = ''
	set @invoice_to = @invoice_from

select h.ECOLINVOICEID as invoice_code,
		case e.status
			when 'C' then 'Complete'
			when 'E' then 'Error'
			when 'I' then 'In Process'
		end as status,
		e.response_text as error_message,
		e.added_by as created_by,
		e.date_added as create_date
from AXInvoiceHeader h
join AXInvoiceExport e
	on e.axinvoiceheader_uid = h.axinvoiceheader_uid
	and (coalesce(@status,'A') = 'A' or e.status = @status)
	and (coalesce(@status,'') <> 'E' or
		not exists (select 1 from AXInvoiceExport
					where axinvoiceexport_uid > e.axinvoiceexport_uid
					and axinvoiceheader_uid = e.axinvoiceheader_uid
					and status in ('I','C'))
		)
	and (coalesce(@status,'') <> 'I' or
		not exists (select 1 from AXInvoiceExport
					where axinvoiceexport_uid > e.axinvoiceexport_uid
					and axinvoiceheader_uid = e.axinvoiceheader_uid
					and status in ('C'))
		)
	and e.date_added >= coalesce(@date_from,'04/01/2018')
	and e.date_added < coalesce(dateadd(dd,1,coalesce(@date_to,@date_from)),'01/01/2999')
where LEFT(h.ECOLINVOICEID,6) between coalesce(@invoice_from,'100000') and coalesce(@invoice_to,'999999')
order by h.ECOLINVOICEID asc, e.date_added desc
go

grant execute on dbo.sp_d365_invoice_post_get_status to AX_SERVICE, EQAI
go
