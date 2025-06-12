CREATE PROCEDURE sp_ax_insert_axinvoiceexport
	@axinvoiceheader_uid int
AS 

--exec sp_ax_insert_axinvoiceexport 8
 
declare @rc int

insert AXInvoiceExport (axinvoiceheader_uid)
values (@axinvoiceheader_uid)

if @@ERROR <> 0
      set @rc = -1
else
      select @rc = SCOPE_IDENTITY()

--return @rc

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ax_insert_axinvoiceexport] TO [EQAI]
    AS [dbo];

