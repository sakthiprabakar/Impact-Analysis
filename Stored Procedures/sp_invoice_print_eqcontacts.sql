



create procedure sp_invoice_print_eqcontacts (@invoice_id int, @revision_id int)
as

-- rg051208 modified to remove duplicate contacts. if more than use the main (0 billing_project_id)
-- rb 06/18/2015 set transaction isolation level read uncommitted

set transaction isolation level read uncommitted

-- exec sp_invoice_print_eqcontacts 478968,1

declare @billing_project_id int,
        @customer_id int


create table #inv_projects( invoice_id int null,
		revision_id int null,
		customer_id int null,
		billing_project_id int null)

create Table #inv_contacts 	(billing_project_id int null,
                            	customer_id int null,
				territory_code varchar(8) null,
				contact_id int null,
				usercode varchar(10) null,
				username varchar(40) null,
				userphone varchar(30) null,
				usertype varchar(30) null,
 				sort int null )
				
select @customer_id = customer_id from invoiceheader where invoice_id = @invoice_id and revision_id = @revision_id

insert #inv_projects
select 	d.invoice_id,
	d.revision_id,
	max(h.customer_id),
	d.billing_project_id
from Invoicedetail d 
inner join invoiceheader h on d.invoice_id = h.invoice_id
	and d.revision_id = h.revision_id
where d.invoice_id = @invoice_id 
and   d.revision_id = @revision_id
group by d.invoice_id, d.revision_id, d.billing_project_id

if ( select count(*) from #inv_projects ) > 0 
begin 
    -- use the standard if more than one billing project on the invoice
	select @billing_project_id = 0
end
else if ( select count(*) from #inv_projects ) = 1 
begin 
	select @billing_project_id = billing_project_id
	from #inv_projects
end
else
begin
	-- use the standard if no billing project on the invoice
	select @billing_project_id = 0
end 

-- now insert the aes
insert #inv_contacts
select c.billing_project_id,
	c.customer_id,
	c.territory_code,
	c.salesperson_id,
	u.user_code,
	u.user_name,
	u.phone,
	x.eqcontact_type,
	1
from CustomerBilling c
inner join UsersXEQContact x on c.salesperson_id = x.type_id
	and x.eqcontact_type = 'AE'
inner join Users u on x.user_code = u.user_code
where c.customer_id = @customer_id
	and c.billing_project_id = @billing_project_id


-- now insert the csrs
insert #inv_contacts
select c.billing_project_id,
	c.customer_id,
	c.territory_code,
	c.customer_service_id,
	u.user_code,
	u.user_name,
	u.phone,
	x.eqcontact_type,
	2
from CustomerBilling c
inner join UsersXEQContact x on c.customer_service_id = x.type_id
	and x.eqcontact_type = 'CSR'
inner join Users u on x.user_code = u.user_code
where c.customer_id = @customer_id
	and c.billing_project_id = @billing_project_id



-- now insert the NAM
-- insert #inv_contacts
-- select c.billing_project_id,
-- 	c.customer_id,
-- 	c.territory_id,
-- 	c.NAM_id,
-- 	u.user_code,
-- 	u.user_name,
-- 	u.phone,
-- 	x.eqcontact_type
--      3
-- from CustomerBilling c
-- inner join UsersXEQContact x on c.nam_id = x.eqcontact_id
-- 	and x.eqcontact_type = 'NAM'
-- inner join Users u on x.user_code = u.user_code
-- inner join #inv_projects p on c.customer_id = p.customer_id
-- 	and c.billing_project_id = p.billing_project_id

-- 
-- -- now insert the collections
-- insert #inv_contacts
-- select c.billing_project_id,
-- 	c.customer_id,
-- 	c.territory_id,
-- 	c.collections_id,
-- 	u.user_code,
-- 	u.user_name,
-- 	u.phone,
-- 	x.eqcontact_type,
--      4
-- from CustomerBilling c
-- inner join UsersXEQContact x on c.collections_id = x.eqcontact_id
-- 	and x.eqcontact_type = 'Collections'
-- inner join Users u on x.user_code = u.user_code
-- inner join #inv_projects p on c.customer_id = p.customer_id
-- 	and c.billing_project_id = p.billing_project_id
-- 
-- 

-- now dump out the contacts
-- dont need the billing project anymore so cancel it out so we dont get duplicate names

select distinct @invoice_id as invoice_id,
	@revision_id as revision_id,
	billing_project_id,
        customer_id,
	territory_code ,
	contact_id,
	usercode,
	username,
	userphone,
	usertype,
	sort
from #inv_contacts
order by sort asc,
	billing_project_id desc



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_invoice_print_eqcontacts] TO [EQAI]
    AS [dbo];

