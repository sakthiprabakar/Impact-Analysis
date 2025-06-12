


create procedure sp_get_invoice_customer_info (@invoice_id int, @revision_id int) as
-- sp_get_invoice_customer_info 431282, 1

declare @cor_flag char(1),
        @copd_flag char(1),
        @weight_ticket_flag char(1),
        @customer_id int, 
        @cust_name varchar(255), 
        @invoice_date datetime



select @customer_id = customer_id, 
       @cust_name = cust_name, 
       @invoice_date = invoice_date
from InvoiceHeader
where invoice_id = @invoice_id
and   revision_id = @revision_id


select @cor_flag = max(isnull(cor_required_flag,'F')), 
      @copd_flag = max (isnull(copd_required_flag,'F')), 
      @weight_ticket_flag = max(isnull(weight_ticket_required_flag,'T')) 
from customerbilling 
where customer_id = @customer_id
and billing_project_id in ( select billing_project_id 
                              from invoicedetail 
                              where invoice_id = @invoice_id 
                               and revision_id = @revision_id)


--



-- now return all

select @cor_flag as 'cor_flag',
        @copd_flag as 'copd_flag',
        @weight_ticket_flag as 'weight_ticket flag',
        @customer_id as 'customer_id', 
        @cust_name as 'customer_name', 
        @invoice_date as 'invoice_date'


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_invoice_customer_info] TO [EQAI]
    AS [dbo];

