-- drop proc if exists sp_COR_All_CustomerSearch 
go

create proc sp_COR_All_CustomerSearch (
	@web_userid		varchar(100)	-- ignored in this case, we're not limiting to assigned customers.
	, @customer_id	int = null
	, @cust_name		varchar(75) = null
	, @customer_type	varchar(max) = null
	, @sort			varchar(20) = 'cust_name' -- place holder for possible future use, only uses cust_name for now
	, @page			int = 1
	, @perpage		int = 20
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
exec sp_COR_All_CustomerSearch 'manand84', null, 'B', '', '' , 1, 20 

exec sp_COR_All_CustomerSearch 'zachery.wright', null, '', '', '' , 1, 1000 -- none (at the moment)
exec sp_COR_All_CustomerSearch 'nyswyn100', null, '' -- regular customer access case
exec sp_COR_All_CustomerSearch 'ppg_gen', null, '' -- generator. customers they're on profiles with

exec sp_COR_All_CustomerSearch 'jamie.huens@wal-mart.com', null, null
exec sp_COR_All_CustomerSearch 'jamie.huens@wal-mart.com', null, 'wal'

SELECT  contact_id, count(customer_id)  FROM    ContactCORCustomerBucket group by contact_id order by count(customer_id) desc
SELECT  *  FROM    contact WHERE contact_id = 10280

exec sp_COR_All_CustomerSearch 'dave.matteson@wal-mart.com', null, 'dc'
exec sp_COR_All_CustomerSearch 'dave.matteson@wal-mart.com', 11895, 'dc'
exec sp_COR_All_CustomerSearch 'jennifer.chopp', null, null, null
exec sp_COR_All_CustomerSearch 'jennifer.chopp', 10877, null, null
exec sp_COR_All_CustomerSearch 'jennifer.chopp', null, 'timken', null
exec sp_COR_All_CustomerSearch 'jennifer.chopp', null, null, 'general electric'

SELECT  *  FROM    Customer WHERE customer_id = 18459


****************************************************************** */
BEGIN
	-- Avoid query plan caching:
	declare @i_web_userid		varchar(100) = @web_userid
		, @i_customer_id		int = isnull(@customer_id, -1)
		, @i_cust_name		varchar(75) = isnull(@cust_name, '')
		, @i_customer_type	varchar(max) = isnull(@customer_type, '')
		, @i_contact_id		int

	-- select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid
	
	declare @customertype table (
		customer_type	varchar(20)
	)
	if @i_customer_type <> ''
	insert @customertype
	select row from dbo.fn_splitxsvtext(',', 1, @i_customer_type)
	where row is not null


	declare @foo table (customer_id int, _row int identity(1,1))
	declare @total_rows bigint

	insert @foo (customer_id)
	SELECT  
			cust.customer_id
	FROM    Customer cust (nolock) 
	WHERE 1=1
	and (
		@i_customer_id = -1
		or
		(
			@i_customer_id <> -1
			and 
			@i_customer_id = cust.customer_id
		)
	)
	and (
		@i_cust_name = ''
		or 
		(
			len(@i_cust_name) > 1
			and
			cust.cust_name like '%' + replace(@i_cust_name, ' ', '%') + '%'
		)
		or 
		(
			len(@i_cust_name) = 1
			and
			cust.cust_name like @i_cust_name + '%'
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
	order by cust.cust_name
	
	set @total_rows = @@rowcount

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
		, x._row
		, @total_rows as total_rows
	from @foo x
	join Customer c (nolock) on x.customer_id = c.customer_id
	where 
	x._row between ((@page-1) * @perpage ) + 1 and (@page * @perpage) 
	order by _row

	return 0
END
GO

GRANT EXECUTE on sp_COR_All_CustomerSearch to eqweb, eqai, COR_USER
GO

