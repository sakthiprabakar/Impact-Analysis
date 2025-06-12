
CREATE PROCEDURE sp_invoice_validate_jde
	@invoice_id int,
	@revision_id int
AS
/***************************************************************
Loads to:	Plt_AI

Checks that an invoice/adjustment is valid for the JDE system.

03/14/2013 RB	Created
03/18/2013 JDB	Modified the current period validation to use 
				the new view JDECompanyConstants_F0010.
01/07/2014 RB	When @gl_sum was 6 figures or higher and the GL and Pay Items were out of balance,
				an error occurred inserting into temp table and no error was returned
01/14/2014 RB	Only validate invoice date against open GL period (no longer check against open AR period)
07/30/2014 RB	When gl_date validation was extracted for a separate proc, this code was not updated to
		call it. The other proc was recently changed to accomodate June 2014 being split into
		2 periods. Modified this proc to call it when validating gl posting dates.

****************************************************************/
DECLARE @account_number varchar(29),
		@account_number_orig varchar(29),
		@account_exists int,
		@account_is_postable int,
		@posting_edit char(1),
		@gl_sum numeric(12,4),
		@gl_date datetime,
		@jde_customer_id int,
		@open_posting_year int,
		@open_posting_period_gl int,
		@gl_period1 varchar(7),
		@gl_period2 varchar(7),
		@inv_rev varchar(15),
		@rc int

create table #errors (
	error_msg varchar(255) null
)

set transaction isolation level read uncommitted

-- set invoice/revision for messages
set @inv_rev = convert(varchar(10),@invoice_id) + '-' + convert(varchar(3),@revision_id)

-- pay items balance with GL
select @gl_sum = round(SUM(isnull(amount_VNAA,0)),4)
from JDEInvoiceGL
where invoice_id = @invoice_id
and revision_id = @revision_id

select @gl_sum = @gl_sum + round(SUM(isnull(gross_amount_VJAG,0)),4)
from JDEInvoicePayItem
where invoice_id = @invoice_id
and revision_id = @revision_id

if @gl_sum <> 0
	insert #errors values ('ERROR: Invoice ' + @inv_rev + ', the GL and Pay Items are out of balance by a difference of $' + isnull(CONVERT(varchar(20),convert(numeric(18,2),round(@gl_sum/100.0,2))),''))

-- customer exists
set rowcount 1
select @jde_customer_id = address_number_VNAN8
from JDEInvoiceGL
where invoice_id = @invoice_id
and revision_id = @revision_id
set rowcount 0

if not exists (select 1 from JDE.EQFinance.dbo.JDECustomer_F03012
				where address_number_AIAN8 = @jde_customer_id)
	insert #errors values ('ERROR: Invoice ' + @inv_rev + ', customer ' + isnull(CONVERT(varchar(10),@jde_customer_id),'') + ' does not exist in JDE.')

-- account exists in GL distribution, and is a postable account
declare c_gl_exists cursor forward_only read_only for
select distinct ltrim(rtrim(replace(isnull(account_number_VNANI,''),'-',''))), isnull(account_number_VNANI,'')
from JDEInvoiceGL
where invoice_id = @invoice_id
and revision_id = @revision_id

open c_gl_exists
fetch c_gl_exists into @account_number, @account_number_orig

while @@FETCH_STATUS = 0
begin
	exec sp_jde_validate_account @account_number, @account_exists output, @account_is_postable output

	if @account_exists = 0
		insert #errors values ('ERROR: Invoice ' + @inv_rev + ', account ' + isnull(@account_number_orig,'') + ' does not exist in JDE.')
	
	else if @account_is_postable = 0
		insert #errors values ('ERROR: Invoice ' + @inv_rev + ', account ' + isnull(@account_number_orig,'') + ' is not a valid account for posting.')

	fetch c_gl_exists into @account_number, @account_number_orig
end

close c_gl_exists
deallocate c_gl_exists

-- gl date not within a closed period
declare c_gldate cursor forward_only read_only for
select distinct gl_date
from JDEInvoiceGL
where invoice_id = @invoice_id
and revision_id = @revision_id

open c_gldate
fetch c_gldate into @gl_date

WHILE @@FETCH_STATUS = 0
BEGIN
	exec @rc = dbo.sp_jde_validate_posting_date @gl_date

	if @rc < 0
		insert #errors values ('ERROR: Invoice ' + @inv_rev + ', posting date ' + CONVERT(varchar(10),@gl_date,101) + ' is not within the currently open period')

	fetch c_gldate into @gl_date
end

close c_gldate
deallocate c_gldate

select error_msg from #errors
drop table #errors
return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_invoice_validate_jde] TO [EQAI]
    AS [dbo];

