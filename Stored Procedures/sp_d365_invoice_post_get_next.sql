if exists (select 1 from sysobjects where type = 'P' and name = 'sp_d365_invoice_post_get_next')
	drop procedure dbo.sp_d365_invoice_post_get_next
go

create procedure [dbo].[sp_d365_invoice_post_get_next]
	@last_export_id int = 0
as
/***************************************************************
Loads to:   Plt_AI

Called by D365InvoicePostSvcDragon to retrieve the next invoice to post

09/17/2019 RWB	Created

****************************************************************/

declare @next_id int,
	@invoice_code varchar(12)

set transaction isolation level read uncommitted

select @next_id = min(x.axinvoiceexport_uid)
from AXInvoiceExport x
where x.axinvoiceexport_uid > @last_export_id
and x.status = 'I'
and not exists (select 1 from AXInvoiceExport 
				where axinvoiceexport_uid > x.axinvoiceexport_uid
				and axinvoiceheader_uid = x.axinvoiceheader_uid
				and status = 'C')

if @next_id > 0
	select @invoice_code = h.ECOLINVOICEID
	from AXInvoiceExport x
	join AXInvoiceHeader h
		on h.axinvoiceheader_uid = x.axinvoiceheader_uid
	where x.axinvoiceexport_uid = @next_id

select coalesce(@next_id,0) as next_id,
	coalesce(@invoice_code,'') as invoice_code
go

grant execute on dbo.sp_d365_invoice_post_get_next to AX_SERVICE
go
