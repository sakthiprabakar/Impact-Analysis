create procedure sp_ax_invoice_post_get_next
	@last_export_id int = 0
as
/***************************************************************
Loads to:   Plt_AI

Called by AXInvoicePostSvc to retrieve the next new invoice to post

10/09/2018 RWB	Created for GEM:54059

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
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ax_invoice_post_get_next] TO [AX_SERVICE]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ax_invoice_post_get_next] TO [EQAI]
    AS [dbo];
GO

