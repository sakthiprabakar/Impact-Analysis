--drop proc sp_COR_CustomerSearch 
go

create proc sp_COR_CustomerSearch (
	@web_userid		varchar(100)
	, @customer_id	int = null
	, @cust_name		varchar(75)
	, @customer_type	varchar(max) = ''
)
as
/* ******************************************************************
Customer Name Search

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
exec sp_COR_CustomerSearch 'zachery.wright', null, '' -- none (at the moment)
exec sp_COR_CustomerSearch 'nyswyn100', null, '' -- regular customer access case
exec sp_COR_CustomerSearch 'ppg_gen', null, '' -- generator. customers they're on profiles with

exec sp_COR_CustomerSearch 'jamie.huens@wal-mart.com', null, null
exec sp_COR_CustomerSearch 'jamie.huens@wal-mart.com', null, 'wal'

SELECT  contact_id, count(customer_id)  FROM    ContactCORCustomerBucket group by contact_id order by count(customer_id) desc
SELECT  *  FROM    contact WHERE contact_id = 10280

exec sp_COR_CustomerSearch 'dave.matteson@wal-mart.com', null, 'dc'
exec sp_COR_CustomerSearch 'dave.matteson@wal-mart.com', 11895, 'dc'
exec sp_COR_CustomerSearch 'jennifer.chopp', null, null, null
exec sp_COR_CustomerSearch 'jennifer.chopp', 10877, null, null
exec sp_COR_CustomerSearch 'jennifer.chopp', null, 'timken', null
exec sp_COR_CustomerSearch 'jennifer.chopp', null, null, 'general electric'

SELECT  *  FROM    Customer WHERE customer_id = 18459


****************************************************************** */
BEGIN
	-- Avoid query plan caching:
	declare @i_web_userid		varchar(100) = @web_userid
		, @i_customer_id		int = isnull(@customer_id, -1)
		, @i_cust_name		varchar(75) = isnull(@cust_name, '')
		, @i_customer_type	varchar(max) = isnull(@customer_type, '')
		, @i_contact_id		int

	select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid
	
	declare @customertype table (
		customer_type	varchar(20)
	)
	if @i_customer_type <> ''
	insert @customertype
	select row from dbo.fn_splitxsvtext(',', 1, @i_customer_type)
	where row is not null


	declare @foo table (customer_id int)
	declare @bar table (customer_id int)

	insert @bar
	SELECT  
			x.customer_id
	FROM    ContactCORCustomerBucket x (nolock) 
	WHERE x.contact_id = @i_contact_id

	if not exists (select top 1 1 from ContactCORCustomerBucket where contact_id = @i_contact_id)
		and exists (select top 1 1 from ContactCORGeneratorBucket where contact_id = @i_contact_id)
		-- This is a Generator access user, but not Customers
		-- per discussion 3/13/20 we'll return the customers they've been seen with before:
		insert @bar
		SELECT  distinct customer_id
		FROM    ContactCORProfileBucket x (nolock) 
		WHERE x.contact_id = @i_contact_id
		and curr_status_code = 'A'

	insert @foo
	SELECT  
			x.customer_id
	FROM    @bar x
	join Customer cust (nolock) on x.customer_id = cust.customer_id
	WHERE 1=1
	and (
		@i_customer_id = -1
		or
		(
			@i_customer_id <> -1
			and 
			@i_customer_id = x.customer_id
		)
	)
	and (
		@i_cust_name = ''
		or 
		(
			@i_cust_name <> ''
			and
			cust.cust_name like '%' + replace(@i_cust_name, ' ', '%') + '%'
		)
	)
	and (
		@i_customer_type = ''
		or
		(
			@i_customer_type <> ''
			and
			cust.customer_type in (select customer_type from @customertype)
		)
	)

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
		, c.customer_type
		, c.bill_to_cust_name
		, c.bill_to_addr1
		, c.bill_to_addr2
		, c.bill_to_addr3
		, c.bill_to_addr4
		, c.bill_to_addr5
		, c.bill_to_city
		, c.bill_to_state
		, c.bill_to_zip_code
		, c.bill_to_country

	--	Contact?
	--	Phone?
	--	Email?
	from @foo x
	join Customer c (nolock) on x.customer_id = c.customer_id
	order by c.cust_name

	return 0
END
GO

GRANT EXECUTE on sp_COR_CustomerSearch to eqweb, eqai, COR_USER
GO
