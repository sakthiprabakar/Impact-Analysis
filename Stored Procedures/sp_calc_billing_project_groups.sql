CREATE PROCEDURE sp_calc_billing_project_groups 
	@customer_id int
AS
/**********************************************************************************
Loads to:  Plt_AI

XX/XX/XXXX XXX	Created.
03/14/2013 JDB	Modified to only retrieve contacts from CustomerBillingXContact
				where the invoice_copy_flag = 'T', because that is the true
				criteria for whether billing projects can be grouped together.
				
EXEC sp_calc_billing_project_groups 10673
***********************************************************************************/
declare @contact_list varchar(4000),
        @customer int,
        @project int

create table #group ( customer_id int null,
                      Customer_name varchar(40) null,
                      run_date datetime null,
                      billing_project_id int null,
                      project_name varchar(40) null,
                      record_type char(1) null,
                      intervention_required char(1) null,
                      invoice_flag char(1) null,
                      mail_to_bill_to_address_flag char(1) null,
                      break_1 char(1)null,
                      break_2 char(1) null,
                      break_3 char(1) null,
                      sort_1 char(1) null,
                      sort_2 char(1) null,
                      sort_3 char(1) null,
                      sort_4 char(1) null,
                      sort_5 char(1) null,
                      distribution_method char(1),
                      contact_list varchar(4000) null)

create table #contacts ( contact_id int null,
                         contact_name varchar(40)null,
                         billing_project_id int null,
                         display varchar(100) null )


-- frist pull the billing records except for the contacts

insert #group
select c.customer_id,
       cm.cust_name,
       getdate(),
       c.billing_project_id,
       c.project_name ,
       c.record_type,
       c.intervention_required_flag,
       c.invoice_flag,
       c.mail_to_bill_to_address_flag,
       c.break_code_1,
       c.break_code_2,
       c.break_code_3,
       c.sort_code_1,
       c.sort_code_2,
       c.sort_code_3,
       c.sort_code_4,
       c.sort_code_5,
       c.distribution_method,
       '' as contact_list
from CustomerBilling c , Customer cm
where c.customer_id = cm.customer_id
and  c.customer_id = @customer_id 
     and c.status = 'A'

-- get the contact info for the report
insert #contacts
select c.contact_id,
       c.name,
       b.billing_project_id,
       c.name + ' (' + convert(varchar(12),c.contact_id) + ')'
from Contact c
JOIN CustomerBillingXContact b ON c.contact_id = b.contact_id
	AND b.invoice_copy_flag = 'T'
where b.customer_id = @customer_id


-- declare cursor 
select @contact_list = ''

declare grp cursor for select
customer_id,
billing_project_id
from #group

open grp

fetch grp into @customer, @project

while @@fetch_status = 0
begin
     select @contact_list = COALESCE( @contact_list + ', ', '') + display  
        from #contacts x 
    	where x.billing_project_id = @project

     update #group
        set contact_list = @contact_list
        where customer_id = @customer
        and billing_project_id = @project

      set @contact_list = ''

      fetch grp into @customer, @project

end

close grp

deallocate grp
 --strip off leading commas
update #group
set contact_list = right(contact_list, (len(contact_list) - 1))
where charindex(',',contact_list) = 1


-- now dump the table ordered for grouping

select customer_id,
	customer_name,
	run_date,
	billing_project_id ,
	project_name ,
	record_type ,
	intervention_required ,
	invoice_flag ,
	mail_to_bill_to_address_flag ,
	break_1,
	break_2 ,
	break_3 ,
	sort_1 ,
	sort_2 ,
	sort_3 ,
	sort_4 ,
	sort_5 ,
	distribution_method ,
	contact_list
from #group
order by intervention_required ,
	invoice_flag,
	mail_to_bill_to_address_flag ,
	break_1,
	break_2,
	break_3,
	sort_1 ,
	sort_2 ,
	sort_3,
	sort_4 ,
	sort_5 ,
	distribution_method ,
	contact_list

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_calc_billing_project_groups] TO [EQAI]
    AS [dbo];

