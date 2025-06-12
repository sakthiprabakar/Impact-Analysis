/***************************************************************************************
retrieves customer and related generator info

09/15/2003 jpb	created
11/15/2004 JPB  Changed CustomerContact -> Contact

test cmd line: spw_getcustomers_generators_by_contact 1243
****************************************************************************************/
create procedure spw_getcustomers_generators_by_contact
	@contact_ID	int
as

	set nocount on
	--create a temporary table
	create table #tempitems
	(
		customer_ID	int,
	)
	
	-- insert the rows from the real table into the temp. table
	declare @searchsql varchar(5000)
	select @searchsql = 'insert into #tempitems (customer_ID) select customer.customer_ID 
		from customer 
		right outer join customerxcontact on (customer.customer_ID = customerxcontact.customer_ID) 
		inner join contact on (customerxcontact.contact_ID = contact.contact_ID) 
		where contact.contact_ID = ' + convert(varchar(10), @contact_ID)
	
	execute(@searchsql)
	
	-- turn nocount back off
	set nocount off
	
		select customergenerator.customer_ID, generator.generator_id, generator.epa_id, generator.generator_name, generator.generator_city, generator.generator_state
		from customer 
		left outer join customergenerator on customer.customer_ID = customergenerator.customer_ID
		left outer join generator on customergenerator.generator_id = generator.generator_id
		where customer.customer_ID in (select customer_ID from #tempitems)
		order by customer.customer_ID, generator.generator_name
		for xml auto
	


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_generators_by_contact] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_generators_by_contact] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_generators_by_contact] TO [EQAI]
    AS [dbo];

