/***************************************************************************************
returns the customer_id's and names for a company-family

09/15/2003 jpb	created
11/15/2004 JPB  Changed CustomerContact -> Contact

test cmd line: spw_parent_getchildren_select 2222, 845
****************************************************************************************/
create procedure spw_parent_getchildren_select
	@customer_id	int,
	@contact_id	int
as

	if @customer_id <= 0
		select top 1 @customer_id = customer_id from customerxContact where contact_id = @contact_id and status = 'a'

	select customer.customer_id, 
	case when customer.customer_id <= 999999 then
	right('000000' + convert(varchar(8), customer.customer_id),6) + ' - ' + customer.cust_name
	else
	convert(varchar(8), customer.customer_id) + ' - ' + customer.cust_name
	end
	from customer where customer_id in (
	select c1.customer_id from customertree as c1, customertree as c2 where c1.lft between c2.lft and c2.rgt and c2.customer_id = @customer_id)



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_getchildren_select] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_getchildren_select] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_getchildren_select] TO [EQAI]
    AS [dbo];

