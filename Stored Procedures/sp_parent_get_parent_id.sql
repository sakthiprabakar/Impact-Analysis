
/***************************************************************************************
Returns the parent_id of an input customer_id calculated from customertree

10/1/2003 JPB	Created
Test Cmd Line: sp_parent_get_parent_id 2222
****************************************************************************************/
create procedure sp_parent_get_parent_id
	@customer_id	int
AS
	set nocount on
	declare @TopID	int
	declare @parent_id int
	select @TopID = c.customer_ID
	from CustomerTree c1 join Customer c on c1.customer_id = c.customer_ID, CustomerTree c2
	where c1.lft between c2.lft and c2.rgt
	and c1.customer_ID in 
	(
	select c2.customer_ID from CustomerTree as c1, CustomerTree as c2 where c1.lft between c2.lft and c2.rgt and c1.customer_ID = @customer_ID
	union
	select c1.customer_ID from CustomerTree as c1, CustomerTree as c2 where c1.lft between c2.lft and c2.rgt and c2.customer_ID = @customer_ID
	)
	group by c1.lft, c1.customer_ID, c.customer_id, c.cust_name having count(c2.customer_ID) = 1
	order by c1.lft

	create table #IndentedTree (indentation int, customer_id int, cust_name varchar(40))

	insert into #IndentedTree 
	select count(c2.customer_ID) as indentation, c.customer_ID, c.cust_name
	from CustomerTree c1 join Customer c on c1.customer_id = c.customer_ID, CustomerTree c2
	where c1.lft between c2.lft and c2.rgt
	and c1.customer_ID in 
	(
	select c2.customer_ID from CustomerTree as c1, CustomerTree as c2 where c1.lft between c2.lft and c2.rgt and c1.customer_ID = @TopID
	union
	select c1.customer_ID from CustomerTree as c1, CustomerTree as c2 where c1.lft between c2.lft and c2.rgt and c2.customer_ID = @TopID
	)
	group by c1.lft, c1.customer_ID, c.customer_id, c.cust_name
	order by c1.lft

	select @parent_ID = customer_ID from #IndentedTree
	where indentation = (select indentation -1 from #IndentedTree where customer_ID = @customer_ID)

	set nocount off

	select isnull(@parent_ID, @customer_ID) as cust_parent_id
	return isnull(@parent_ID, @customer_ID)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_parent_get_parent_id] TO [EQAI]
    AS [dbo];

