/***************************************************************************************
retrieves customer and related eq company info

09/15/2003 jpb	created
11/15/2004 JPB  Changed CustomerContact -> Contact

test cmd line: spw_getcustomers_companies_by_contact 1243
****************************************************************************************/
create procedure spw_getcustomers_companies_by_contact
	@contact_ID	int
as
	
	set nocount on
	--create a temporary table
	create table #tempitems
	(
		customer_ID	int
	)
	
	-- insert the rows from the real table into the temp. table
	declare @searchsql varchar(5000)
	select @searchsql = 'insert into #tempitems (customer_ID) select customer.customer_ID 
		from customer 
		right outer join customerxcontact on (customer.customer_ID = customerxcontact.customer_ID and customerxcontact.status = ''A'') 
		inner join contact on (customerxcontact.contact_ID = contact.contact_ID) 
		where contact.contact_ID = ' + convert(varchar(10), @contact_ID)
	
	execute(@searchsql)
	
	-- turn nocount back off
	set nocount off
	
	select
	customer.customer_ID, customerxcompany.customer_ID, customerxcompany.territory_code, customerxcompany.cust_discount, customerxcompany.inv_break_code, customerxcompany.project_inv_break_code, customerxcompany.date_last_invoice, contact.contact_ID, contact.name
	from #tempitems t (nolock), customer 
	left outer join customerxcompany 
		on customer.customer_ID = customerxcompany.customer_ID
	left outer join contact
		on customerxcompany.primary_contact_id = contact.contact_id
	where customer.customer_ID = t.customer_ID
	order by customer.customer_ID, customerxcompany.company_ID
	for xml auto



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_companies_by_contact] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_companies_by_contact] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_companies_by_contact] TO [EQAI]
    AS [dbo];

