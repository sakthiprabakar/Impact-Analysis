CREATE PROCEDURE sp_post_validate_billing_links (
	@customer_check	int, 
	@status_check	char(1), 
	@inv_date		datetime 	)
AS
/***************************************************************************************
This stored procedure reports link errors on the invoice processing window.

Filename:	L:\Apps\SQL\EQAI\sp_post_validate_billing_links.sql
Loads to:	PLT_AI

07/08/2008 RG	Created
07/17/2008 JDB	Removed source fields from Billing table

sp_post_validate_billing_links 0, 'N','06/12/2008'
sp_post_validate_billing_links 0, 'N',null
****************************************************************************************/
DECLARE @trans_source varchar(1),
	@company_id int ,
	@profit_ctr_id int ,
	@receipt_id int ,
	@line_id int ,
    @billing_link_id int ,
	@source_type char(1) ,
	@source_company_id int ,
	@source_profit_ctr_id int ,
	@source_id int ,
	@source_line_id int,
    @submitted_flag char(1),
    @submitted_date datetime
 
CREATE TABLE #BillingLink (trans_source varchar(1) NULL,
	company_id int NULL,
	profit_ctr_id int NULL,
	receipt_id int NULL,
	line_id int NULL,
	receipt_date datetime NULL,
	approval_code varchar(40) null,
	invoice_code varchar(20) null,
	customer_id int null,
	billing_project_id int null,
	linked_required_flag char(1) null,
	linked_required_validation char(1) null,
	billing_link_id int NULL,
	source_type char(1) null,
	source_company_id int NULL,
	source_profit_ctr_id int NULL,
	source_id int NULL,
	source_line_id int NULL,
	added_by varchar(10)  NULL,
	date_added datetime NULL,
	modified_by varchar(10)  NULL,
	date_modified datetime NULL,
    submitted_date datetime null,
    link_status char(1) null,
    link_invoice_code varchar(20) null,
    link_print_on_invoice char(1) null,
    link_error_message varchar(255) null,
    set_back char(1) null	)

-- prime up the table for receipts

-- special processing for walmart receipts only
-- walmart receipts should be paired with a workorder.  if no  billing link exists or the link is null then that is an error
--if @customer_check = 0 or @customer_check = 10673
--begin
-- receipts with no link and link is required
insert #billinglink
	select b.trans_source,
		b.company_id ,
		b.profit_ctr_id ,
		b.receipt_id ,
		b.line_id ,
		b.billing_date,
        b.approval_code,
        b.invoice_code, 
		b.customer_id,
        b.billing_project_id,
        isnull(cb.link_required_flag, 'F'),
        cb.link_required_validation,
		b.billing_link_id, 
		'R' ,
		bl.source_company_id ,
		bl.source_profit_ctr_id ,
		bl.source_id ,
		bl.source_line_id ,
		bl.added_by ,
		bl.date_added ,
		bl.modified_by, 
		bl.date_modified,
	   null as submitted_date,
	   null as link_status,
	   null as link_invoice_code,
       null as link_print_on_invoice,
       null as link_error_message,
       null as set_back	   
	from billing b
	left outer join billinglinklookup bl on b.receipt_id = bl.receipt_id
                                       and   b.profit_ctr_id = bl.profit_ctr_id
                                       and   b.company_id = bl.company_id
                                      and  bl.trans_source in ('I', 'O')
                                      and  bl.billing_link_id = b.billing_link_id
    inner join CustomerBilling cb on b.customer_id = cb.customer_id
                              and isnull(b.billing_project_id,0) = cb.billing_project_id
	where 1 = 1
	and   isnull(cb.link_required_flag,'F' ) = 'T'
	and   b.status_code = @status_check
	and   b.trans_source = 'R'
	and   b.billing_link_id is null
        and   b.status_code = @status_check
        and  ( (@inv_date is not null and b.invoice_date = @inv_date) or
              (@inv_date is null) )
--end 
-- workorders with no links and link is required
insert #billinglink
	select bl.trans_source,
		bl.company_id ,
		bl.profit_ctr_id ,
		bl.receipt_id ,
		bl.line_id ,
		b.billing_date,
	    null as approval_code,
        b.invoice_code, 
		b.customer_id,
        b.billing_project_id,
        isnull(cb.link_required_flag, 'F'),
        cb.link_required_validation,
		b.billing_link_id, 

--		b.source_type ,
		bl.source_type ,

		bl.company_id ,
		bl.profit_ctr_id ,
		bl.receipt_id ,
		bl.line_id ,
		bl.added_by ,
		bl.date_added ,
		bl.modified_by, 
		bl.date_modified,
	   null as submitted_date,
	   null as link_status,
	   null as link_invoice_code,
       null as link_print_on_invoice,
       null as link_error_message,
       null as set_back	   
	from billing b
	left outer join billinglinklookup bl on b.receipt_id = bl.source_id
                                       and   b.profit_ctr_id = bl.source_profit_ctr_id
                                       and   b.company_id = bl.source_company_id
                                      and  bl.trans_source in ('I', 'O')
                                      and  b.billing_link_id = bl.billing_link_id
    inner join CustomerBilling cb on b.customer_id = cb.customer_id
                              and isnull(b.billing_project_id,0) = cb.billing_project_id
	where 1 = 1
	and   isnull(cb.link_required_flag,'F' ) = 'T'
	and   b.status_code = @status_check
	and   b.trans_source = 'W'
	and   b.billing_link_id is null
        and   b.status_code = @status_check
      and  ( (@inv_date is not null and b.invoice_date = @inv_date) or
              (@inv_date is null) )




insert #billinglink
select b.trans_source,
	b.company_id ,
	b.profit_ctr_id ,
	b.receipt_id ,
	b.line_id ,
	b.billing_date,
        b.approval_code,
        b.invoice_code, 
		b.customer_id,
	b.billing_project_id,
        isnull(cb.link_required_flag, 'F'),
        cb.link_required_validation,
	b.billing_link_id, 
	bl.source_type ,
	bl.source_company_id ,
	bl.source_profit_ctr_id ,
	bl.source_id ,
	bl.source_line_id ,
	bl.added_by ,
	bl.date_added ,
	bl.modified_by, 
	bl.date_modified,
   null as submitted_date,
   null as link_status,
   null as link_invoice_code,
       null as link_print_on_invoice,
       null as link_error_message,
       null as set_back	   	 
from billing b
inner join billinglinklookup bl on b.receipt_id = bl.receipt_id
                                       and   b.profit_ctr_id = bl.profit_ctr_id
                                       and   b.company_id = bl.company_id
                                      and  bl.trans_source in ('I', 'O')
inner join CustomerBilling cb on b.customer_id = cb.customer_id
                              and isnull(b.billing_project_id,0) = cb.billing_project_id

where b.billing_link_id = 0
and  ( b.customer_id = @customer_check or @customer_check = 0 )
and   b.status_code = @status_check
and   b.trans_source = 'R'
and  ( (@inv_date is not null and b.invoice_date = @inv_date) or
              (@inv_date is null) )



-- update linked counter part with billing status, date_submitted, invoice_code 
update #billinglink
set submitted_date = bs.billing_date,
    link_status = bs.status_code,
    link_invoice_code = bs.invoice_code
from #billinglink bl, billing bs
where  bl.trans_source = 'R'
and    bl.billing_link_id is not null
and  bl.source_id = bs.receipt_id
    and   bl.source_profit_ctr_id = bs.profit_ctr_id
    and   bl.source_company_id = bs.company_id
    and   bl.source_type = bs.trans_source





-- prime up the table for workorders


insert #billinglink
select b.trans_source,
	b.company_id ,
	b.profit_ctr_id ,
	b.receipt_id ,
	b.line_id ,
	b.billing_date,
        b.approval_code,
        b.invoice_code,
        b.customer_id,
        b.billing_project_id,
        isnull(cb.link_required_flag, 'F'),
        cb.link_required_validation,		
	b.billing_link_id, 
	'R' ,
	bl.company_id ,
	bl.profit_ctr_id ,
	bl.receipt_id ,
	bl.line_id ,
	bl.added_by ,
	bl.date_added ,
	bl.modified_by, 
	bl.date_modified,
   null as submitted_date,
   null as link_status,
   null as link_invoice_code,
   null as link_print_on_invoice,
   null as link_error_message,
       null as set_back	   	 
   
      
from billing b
inner join billinglinklookup bl on b.receipt_id = bl.source_id
                                       and   b.profit_ctr_id = bl.source_profit_ctr_id
                                       and   b.company_id = bl.source_company_id
                                      and  bl.source_type = 'W'
inner join CustomerBilling cb on b.customer_id = cb.customer_id
                              and isnull(b.billing_project_id,0) = cb.billing_project_id

where b.billing_link_id = 0
and ( b.customer_id = @customer_check or @customer_check = 0 )
and   b.status_code = @status_check
and   b.trans_source = 'W'
and   b.invoice_date = coalesce(@inv_date,b.invoice_date)




update #billinglink
set submitted_date = bs.billing_date,
    link_status = bs.status_code,
    link_invoice_code = bs.invoice_code
from #billinglink bl, billing bs
where  bl.trans_source = 'W'
and    bl.billing_link_id is not null
and  bl.source_id = bs.receipt_id
    and   bl.source_profit_ctr_id = bs.profit_ctr_id
    and   bl.source_company_id = bs.company_id
    and   bl.source_type = bs.trans_source
	
	
	
	
-- now compute error messages

-- frist set print_on_invoice_flag which is T if billing_link = 0 or F if billing_link is null
update #billinglink
set link_print_on_invoice = case when date_modified is not null and billing_link_id = 0 then 'T'
                            when date_modified is not null and billing_link_id is null then 'F'
							else null end
from #billinglink




--if walmart and no link
update #billinglink
set link_error_message = 'No billing link entered',
    set_back  = 'T'
from #billinglink
where date_modified is null and trans_source in ('I','O')
and linked_required_flag = 'T' and isnull(linked_required_validation,'W') = 'E'


--if walmart and no link
update #billinglink
set link_error_message = 'No billing link entered'
from #billinglink
where date_modified is null and trans_source in ('I','O')
and linked_required_flag = 'T' and isnull(linked_required_validation,'W') = 'W'



--if walmart and link but print on invoice not set
update #billinglink
set link_error_message = 'Billing link not set to Invoice Together',
    set_back = 'T'
from #billinglink
where date_modified is not null and trans_source in ('I','O')
and link_print_on_invoice = 'F'
and linked_required_flag = 'T' and isnull(linked_required_validation,'W') = 'E'
and link_status <> 'I'


--if walmart and link but print on invoice not set
update #billinglink
set link_error_message = 'Billing link not set to Invoice Together'
from #billinglink
where date_modified is not null and trans_source in ('I','O')
and link_print_on_invoice = 'F'
and linked_required_flag = 'T' and isnull(linked_required_validation,'W') = 'W'
and link_status <> 'I'



-- both must be in same status unless counter is invoiced already
update #billinglink
set link_error_message = 'Linked transaction not same status',
    set_back = 'T'
from #billinglink
where link_status is not null and link_status <> @status_check
and link_status <> 'I' and @status_check <> 'I'



-- both must be in same status except if counter is invoiced already
update #billinglink
set link_error_message = 'Linked transaction already invoiced',
    set_back = 'T'
from #billinglink
where link_status is not null and link_status <> @status_check
and link_status = 'I' and @status_check <> 'I'


-- both must be in same status
update #billinglink
set link_error_message = 'Linked transactions on separate invoices',
    set_back = 'T'
from #billinglink
where invoice_code is not null and link_invoice_code is not null
and invoice_code <> link_invoice_code 




-- if the billing source is receipt and then the corresponding workorder submitted date must be populated
-- this indicates that the receipt and workorder are both in the billing table and ready

-- if the billing source is workorder and all the corresponding receipt submitted dates must be populated
-- this indicates that the receipt and workorder are both in the billing table and ready

-- if no error message then do'nt return

select bl.trans_source,
	bl.company_id,
	bl.profit_ctr_id,
	bl.receipt_id,
	bl.line_id,
	bl.receipt_date,
    bl.approval_code,
    bl.invoice_code,
	bl.customer_id,
	bl.billing_link_id,
	bl.source_type,
	bl.source_company_id,
	bl.source_profit_ctr_id,
	bl.source_id,
	bl.source_line_id,
	bl.added_by,
	bl.date_added,
	bl.modified_by,
	bl.date_modified,
    bl.submitted_date,
    bl.link_status,
    bl.link_invoice_code,
    bl.link_print_on_invoice,
    bl.link_error_message,
     c.cust_name
	from #billinglink bl, Customer c
	where bl.customer_id = c.customer_id
    and link_error_message is not null

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_post_validate_billing_links] TO [EQAI]
    AS [dbo];

