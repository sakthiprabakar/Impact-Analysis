﻿/***************************************************************************************
Returns the work-table version of the indented hierarchy view of a customer (by customer or contact)

10/1/2003 JPB	Created
11/15/2004 JPB  Changed CustomerContact -> Contact

Test Cmd Line: spw_parent_getworkhierarchy 2222, 0
****************************************************************************************/
create procedure spw_parent_getworkhierarchy
	@customer_ID	int,
	@contact_ID	int
As

	declare @TopID	int

	if @customer_ID <= 0
		select top 1 @customer_ID = customer_ID from CustomerXContact where contact_id = @contact_ID and status = 'A'


	select @TopID = c.customer_ID
	from CustomerTreeWork c1 join Customer c on c1.customer_id = c.customer_ID, CustomerTreeWork c2
	where c1.lft between c2.lft and c2.rgt
	and c1.customer_ID in 
	(
	select c2.customer_ID from CustomerTreeWork as c1, CustomerTreeWork as c2 where c1.lft between c2.lft and c2.rgt and c1.customer_ID = @customer_ID
	union
	select c1.customer_ID from CustomerTreeWork as c1, CustomerTreeWork as c2 where c1.lft between c2.lft and c2.rgt and c2.customer_ID = @customer_ID
	)
	group by c1.lft, c1.customer_ID, c.customer_id, c.cust_name having count(c2.customer_ID) = 1

	order by c1.lft

	select count(c2.customer_ID) as indentation, c.customer_ID, c.cust_name
	from CustomerTreeWork c1 join Customer c on c1.customer_id = c.customer_ID, CustomerTreeWork c2
	where c1.lft between c2.lft and c2.rgt
	and c1.customer_ID in 
	(
	select c2.customer_ID from CustomerTreeWork as c1, CustomerTreeWork as c2 where c1.lft between c2.lft and c2.rgt and c1.customer_ID = @TopID
	union
	select c1.customer_ID from CustomerTreeWork as c1, CustomerTreeWork as c2 where c1.lft between c2.lft and c2.rgt and c2.customer_ID = @TopID
	)
	group by c1.lft, c1.customer_ID, c.customer_id, c.cust_name
	order by c1.lft



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_getworkhierarchy] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_getworkhierarchy] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[spw_parent_getworkhierarchy] TO [EQAI]
    AS [dbo];

