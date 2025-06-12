if exists (select 1 from sysobjects where type = 'P' and name = 'sp_d365_invoice_post_set_status')
	drop procedure dbo.sp_d365_invoice_post_set_status
go

create procedure [dbo].[sp_d365_invoice_post_set_status]
	@invoice_code varchar(20),
	@status char(1),
	@msg varchar(max)
as
/***************************************************************
Loads to:   Plt_AI

Called by D365InvoicePostSvcDragon to update invoice status

09/17/2019 RWB	Created
03/02/2023 RWB	Removed 'C' from the status list where clause

****************************************************************/

update AXInvoiceExport
set status = @status,
	response_text = @msg,
	modified_by = 'AX_SERVICE',
	date_modified = getdate()
from AXInvoiceExport e
join AXInvoiceHeader h
	on h.axinvoiceheader_uid = e.axinvoiceheader_uid
	and h.ECOLINVOICEID = @invoice_code
where e.status in ('I', 'P')
go

grant execute on dbo.sp_d365_invoice_post_set_status to AX_SERVICE, EQAI
go
