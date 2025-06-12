DROP PROCEDURE IF EXISTS sp_ax_invoice_post_get_status
GO

create procedure sp_ax_invoice_post_get_status
	@invoice_from varchar(12) = null,
	@invoice_to varchar(12) = null,
	@date_from datetime = null,
	@date_to datetime = null,
	@status char(1) = null
as
/***************************************************************
Loads to:   Plt_AI

Query the status of a range of invoices (called by the new Post Status tab)

10/09/2018 RWB	Created for GEM:54059
01/30/2023 Venu Devops 60726 - Added user_name field to display the user full name in invoice screen.
11/29/2023 MPM	DevOps 74980 - Modified WHERE clause as per Rob Briggs. Also removed a stray "\".
01/16/2024 MPM	DevOps 76940 - Corrected the WHERE clause.
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
		e.date_added as create_date,
		dbo.fn_get_user_full_name(e.added_by) as user_name
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
WHERE LEFT(h.ECOLINVOICEID, CASE WHEN CHARINDEX('R', h.ECOLINVOICEID) > 0 THEN CHARINDEX('R', h.ECOLINVOICEID) - 1 ELSE LEN(h.ECOLINVOICEID) END)
	BETWEEN COALESCE(@invoice_from,'100000') AND COALESCE(@invoice_to,'9999999') --this is now 7 digits
AND ISNUMERIC(LEFT(h.ECOLINVOICEID, CASE WHEN CHARINDEX('R', h.ECOLINVOICEID) > 0 THEN CHARINDEX('R', h.ECOLINVOICEID) - 1 ELSE LEN(h.ECOLINVOICEID) END)) > 0
ORDER BY h.ECOLINVOICEID ASC, e.date_added DESC
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ax_invoice_post_get_status] TO [AX_SERVICE];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ax_invoice_post_get_status] TO [EQAI];
GO

