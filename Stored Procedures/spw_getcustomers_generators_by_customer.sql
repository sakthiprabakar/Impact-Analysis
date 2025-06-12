
/***************************************************************************************
retrieves customer and related generator info

09/15/2003 jpb	created
test cmd line: spw_getcustomers_generators_by_customer 1243
****************************************************************************************/
create procedure spw_getcustomers_generators_by_customer
	@Customer_ID	int
As

	select customergenerator.customer_ID, generator.generator_id, generator.epa_id, generator.generator_name, generator.generator_city, generator.generator_state
	from customer
	left outer join customergenerator on customer.customer_id = customergenerator.customer_id
	left outer join generator on customergenerator.generator_id = generator.generator_id
	where customer.customer_id = @Customer_ID
	order by customer.customer_id, generator.generator_name
	for xml auto


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_generators_by_customer] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_generators_by_customer] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_getcustomers_generators_by_customer] TO [EQAI]
    AS [dbo];

