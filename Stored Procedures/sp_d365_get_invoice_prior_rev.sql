if exists (select 1 from sysobjects where type = 'P' and name = 'sp_d365_get_invoice_prior_rev')
    drop procedure sp_d365_get_invoice_prior_rev
go

create procedure sp_d365_get_invoice_prior_rev
    @invoice_code varchar(12)
as
/****************************
 *
 * 09/09/2024 - rwb - created
 *
 * exec sp_d365_get_invoice_prior_rev '1075941R03'
 *
 *****************************/
declare @idx int,
        @prior varchar(12),
        @revision_id int

set @idx = charindex('R',@invoice_code,1)
if coalesce(@idx,0) < 1
begin
    set @prior = ''
    goto END_OF_PROC
end

set @prior = substring(@invoice_code,1,len(@invoice_code)-3)

if right(@invoice_code,2) <> '02'
begin
    select @revision_id = max(revision_id)
    from InvoiceHeader ih
    where invoice_id = (select invoice_id from AXInvoiceHeader where ECOLINVOICEID = @invoice_code)
    and revision_id < convert(int,right(@invoice_code,2))
    and coalesce(non_monetary_adj_flag,'F') <> 'T'

    if coalesce(@revision_id,0) > 1
        set @prior = @prior + 'R' + right('0' + convert(varchar(2),@revision_id),2)
end

END_OF_PROC:
select coalesce(@prior,'') as prior_invoice_rev
return 0
go

grant execute on sp_d365_get_invoice_prior_rev to EQAI, AX_SERVICE
go
