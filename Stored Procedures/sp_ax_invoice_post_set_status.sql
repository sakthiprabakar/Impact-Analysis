create procedure sp_ax_invoice_post_set_status
	@export_id int,
	@status char(1),
	@msg varchar(max)
as
/***************************************************************
Loads to:   Plt_AI

Called by the AXInvoicePostSvc to update the status in the AXInvoiceExport table

10/09/2018 RWB	Created for GEM:54059

****************************************************************/

update AXInvoiceExport
set status = @status,
	response_text = @msg,
	modified_by = 'AX_SERVICE',
	date_modified = getdate()
where axinvoiceexport_uid = @export_id
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ax_invoice_post_set_status] TO [AX_SERVICE]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ax_invoice_post_set_status] TO [EQAI]
    AS [dbo];
GO

