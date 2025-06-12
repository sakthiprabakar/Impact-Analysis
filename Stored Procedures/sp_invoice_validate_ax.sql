CREATE PROCEDURE [dbo].[sp_invoice_validate_ax]
      @invoice_id int,
      @revision_id int,
      @validate_dimensions char(1) = 'N'
AS
/***************************************************************
Loads to:   Plt_AI

Checks that an invoice/adjustment is valid for the AX system.

11/15/2016 AM     Created
06/21/2017 AM     Increased @account_number length from 29 to 100
10/08/2018 RB     GEM:54059 Added optional argument to specify validation of dimensions
                  (EQAI was validating them here, but the error report displayed to the user was validated in PowerBuilder code later)
01/06/2025 Abul   Rally#US133521-Configuration.config_value from a VARCHAR(MAX) to 500 characters

Long term plan will be to check the actual AX table (CUSTTABLE).  I'd say for now, 
just make sure they're not blank, and leave a stub to check AX later (when we have that part set up.)

exec sp_invoice_validate_ax 1195474,1 

execute dbo.sp_invoice_validate_ax 1195400,1
execute dbo.sp_invoice_validate_ax 1220904,2
****************************************************************/
DECLARE @account_number varchar(100),
            @account_exists varchar(4096),
            @ax_customer_id varchar(20),
            @ax_invoice_customer_id varchar(20),
            @ax_adjustment_id varchar(10),
            @ax_original_invoice_id varchar(20),
            @ax_invoice_proj_id varchar(20),
            @ax_invoice_proj_category_id varchar(30),
            @ax_main_account varchar(20),
            @ax_dimension_1 varchar(20),
            @ax_dimension_2   varchar(20),
            @ax_dimension_3 varchar(20),
            @ax_dimension_4 varchar(20),
            @ax_dimension_5_part_1 varchar(20),
            @ax_dimension_5_part_2 varchar(9),
            @ax_dimension_5 varchar(20),
            @ax_dimension_6 varchar(20),
            @ax_dimension_5_count int,
            @inv_rev varchar(15),
            @ax_web_service varchar(500)          

create table #errors (
      error_msg varchar(4096) null
)

set transaction isolation level read uncommitted

-- set invoice/revision for messages
set @inv_rev = convert(varchar(10),@invoice_id) + '-' + convert(varchar(3),@revision_id)

SELECT @ax_web_service = config_value
FROM Configuration
where config_key =  'ax_web_service'
	
-- customer exists
declare c_loop cursor read_only forward_only for
select distinct axh.ORDERACCOUNT,
       axh.INVOICEACCOUNT,
       axl.ACCOUNTINGDISTRIBUTION_LEDGERDIMENSION,
       axh.ECOLADJUSTMENTID,
         axh.ECOLORIGINALINVOICEID,
         axl.CUSTINVOICELINE_PROJID,
         axl.CUSTINVOICELINE_PROJCATEGORYID
from AXInvoiceHeader axh
inner join AXInvoiceLine axl on axl.axinvoiceheader_uid = axh.axinvoiceheader_uid
where axh.invoice_id = @invoice_id
and axh.revision_id = @revision_id

open c_loop
fetch c_loop into
      @ax_customer_id,
    @ax_invoice_customer_id,
    @account_number,
    @ax_adjustment_id,
      @ax_original_invoice_id,
      @ax_invoice_proj_id,
      @ax_invoice_proj_category_id

while @@FETCH_STATUS = 0
begin

      if @ax_customer_id = null or @ax_customer_id = '' or @ax_invoice_customer_id = null or @ax_invoice_customer_id = ''
        insert #errors values ('ERROR: Invoice ' + @inv_rev + ', customer ' + isnull(CONVERT(varchar(10),@ax_customer_id),'') + isnull(CONVERT(varchar(10),@ax_invoice_customer_id),'') + ' does not exist.')

      --if not exists (select 1 from customer
      --                      where ax_customer_id = @ax_customer_id 
      --                      AND ax_invoice_customer_id = @ax_invoice_customer_id )
      --    insert #errors values ('ERROR: Invoice ' + @inv_rev + ', customer ' + isnull(CONVERT(varchar(10),@ax_customer_id),'') + isnull(CONVERT(varchar(10),@ax_invoice_customer_id),'') + ' does not exist.')

      -- account exists in GL distribution, and is a postable account

      select @ax_main_account = row from dbo.fn_SplitXsvText('-', 1,@account_number )where idx = 1
      select @ax_dimension_1 = row from dbo.fn_SplitXsvText('-', 1, @account_number )where idx = 2
      select @ax_dimension_2 = row from dbo.fn_SplitXsvText('-', 1, @account_number )where idx = 3
      select @ax_dimension_3 = row from dbo.fn_SplitXsvText('-', 1, @account_number )where idx = 4
      select @ax_dimension_4 = row from dbo.fn_SplitXsvText('-', 1, @account_number )where idx = 5
      select @ax_dimension_6 = row from dbo.fn_SplitXsvText('-', 1, @account_number )where idx = 6
      select @ax_dimension_5 = row from dbo.fn_SplitXsvText('-', 1, @account_number )where idx = 7

      --if @ax_dimension_6 = '' 
      --   set @ax_dimension_6 = '-'

      select @ax_dimension_5_count = COUNT(*) from dbo.fn_SplitXsvText('.', 1, @ax_dimension_5)

      if @ax_dimension_5_count > 1 
      begin
         select @ax_dimension_5_part_1 = row from dbo.fn_SplitXsvText('.', 1, @ax_dimension_5) where idx = 1 
         select @ax_dimension_5_part_2 = row from dbo.fn_SplitXsvText('.', 1, @ax_dimension_5) where idx = 2
    end
      if @ax_dimension_5_count = 1
      begin
         select @ax_dimension_5_part_1 = row from dbo.fn_SplitXsvText('.', 1, @ax_dimension_5) where idx = 1 
         set @ax_dimension_5_part_2 = ''
      end
      
      --if @ax_dimension_5_count = 0 
      --   set @ax_dimension_5_part_1 = '-' 
      --   set @ax_dimension_5_part_2 = '-'
  
-- rb 10/08/2018
      if @validate_dimensions = 'N'
          set @account_exists = 'Valid'
      else
          select @account_exists = dbo.fnValidateFinancialDimension (@ax_web_service,@ax_main_account,@ax_dimension_1,@ax_dimension_2,@ax_dimension_3,@ax_dimension_4,@ax_dimension_6,@ax_dimension_5_part_1,@ax_dimension_5_part_2 )

      if @account_exists <> 'Valid'
            insert #errors (error_msg) values (@account_exists)
            --insert #errors values ('ERROR: Invoice ' + @inv_rev + ', account ' + isnull(@account_number,'') + ' is not a valid.')

      -- adjustments
      IF @revision_id > 1 
        begin

            if @ax_adjustment_id = '' OR @ax_adjustment_id = null 
            
                   insert #errors (error_msg) values ('ERROR: Invoice ' + @inv_rev + ', adjustment id ' + @ax_adjustment_id + ' does not exist in AX.')
            
            if @ax_original_invoice_id = '' OR @ax_original_invoice_id = null 
            
                   insert #errors (error_msg) values ('ERROR: Invoice ' + @inv_rev + ', original invoice id ' + @ax_original_invoice_id + ' does not exist in AX.')
        end       
      -- invoice line project category id 
            
            if @ax_invoice_proj_id <> null OR @ax_invoice_proj_id <> ''
               IF @ax_invoice_proj_category_id <> 'FTI Import'
               
                   insert #errors (error_msg) values ('ERROR: Invoice ' + @inv_rev + ', proj category id ' + @ax_invoice_proj_category_id + ' is not "FTI Import" for project id '+ @ax_invoice_proj_id + '.')

      fetch c_loop into
            @ax_customer_id,
            @ax_invoice_customer_id,
            @account_number,
            @ax_adjustment_id,
            @ax_original_invoice_id,
            @ax_invoice_proj_id,
            @ax_invoice_proj_category_id
end

close c_loop
deallocate c_loop

select distinct error_msg from #errors
drop table #errors
return 0
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_invoice_validate_ax] TO [EQAI]
    AS [dbo];
GO

