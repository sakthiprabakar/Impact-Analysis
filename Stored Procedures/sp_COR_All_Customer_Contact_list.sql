--drop proc if exists sp_COR_All_Customer_Contact_list 
go

create proc sp_COR_All_Customer_Contact_list (
	@web_userid		varchar(100)	-- ignored in this case, we're not limiting to assigned customers.
	, @customer_id	int
)
as
/* ******************************************************************
All Customer Contact List


sp_COR_All_Customer_Contact_list @web_userid = '', @customer_id = 10673

****************************************************************** */
BEGIN

	declare @foo table (
			customer_id	int NOT NULL
		)
		
	insert @foo
	SELECT  
			x.customer_id
	FROM    Customer x (nolock) 
	WHERE
		x.customer_id = @customer_id

	select
		c.contact_id
		, c.name
		, c.title
		, c.phone
		-- , dbo.fn_FormatPhoneNumber(c.phone)
		, c.email
	from @foo z 
	join ContactXref x on z.customer_id = x.customer_id and x.type = 'C' and x.status = 'A'
	join Contact c on x.contact_id = c.contact_id and c.contact_status = 'A'
	order by c.name


END
GO

GRANT EXECUTE on sp_COR_All_Customer_Contact_list to eqweb, eqai, COR_USER
GO
