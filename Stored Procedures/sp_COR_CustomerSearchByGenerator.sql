-- drop proc sp_COR_CustomerSearchByGenerator
go

create proc sp_COR_CustomerSearchByGenerator (
	@web_userid		varchar(100)
	, @generator_id	int = null
)
as
/* ******************************************************************
Customer Name Search by Generator

inputs 
	
	Web User ID
	Customer Name

Returns

	Customer Name
	Customer Address Lines
	City
	State
	Zip
	Country
	Contact?
	Phone?
	Email?

Samples:
exec sp_COR_CustomerSearchByGenerator 'nyswyn100', null, ''
exec sp_COR_CustomerSearchByGenerator 'jamie.huens@wal-mart.com', null, null
exec sp_COR_CustomerSearchByGenerator 'jamie.huens@wal-mart.com', null, 'wal'

SELECT  contact_id, count(customer_id)  FROM    ContactCORCustomerBucket group by contact_id order by count(customer_id) desc
SELECT  *  FROM    contact WHERE contact_id = 10280

exec sp_COR_CustomerSearchByGenerator 'dave.matteson@wal-mart.com', null, 'dc'
exec sp_COR_CustomerSearchByGenerator 'dave.matteson@wal-mart.com', 11895


****************************************************************** */

-- Avoid query plan caching:
declare @i_web_userid		varchar(100) = @web_userid
	, @i_generator_id		int = @generator_id

if @i_generator_id is null set @i_generator_id = -1

declare @foo table (customer_id int)

insert @foo
SELECT  
		x.customer_id
FROM    ContactCORCustomerGeneratorBucket x 
join CORContact c on x.contact_id = c.contact_id and c.web_userid = @i_web_userid
where isnull(@i_generator_id, -1) = x.generator_id

select
	c.customer_id
	, c.cust_name
	, c.cust_addr1
	, c.cust_addr2
	, c.cust_addr3
	, c.cust_addr4
	, c.cust_addr5
	, c.cust_city
	, c.cust_state
	, c.cust_zip_code
	, c.cust_country

--	Contact?
--	Phone?
--	Email?
from @foo x
join Customer c on x.customer_id = c.customer_id
order by c.cust_name

return 0
GO

grant execute on sp_COR_CustomerSearchByGenerator to eqai, eqweb, COR_USER
go
