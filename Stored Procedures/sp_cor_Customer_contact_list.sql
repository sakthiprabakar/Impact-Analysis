-- drop proc sp_cor_customer_contact_list 
go

create procedure sp_cor_customer_contact_list (
	@web_userid			varchar(100)
	, @customer_id		int
) as

/* *******************************************************************
sp_cor_customer_contact_list

Description
	Provides a listing of all contacts for a customer
	
	Name
	Formatted Phone
	Email
	

SELECT  *  FROM    contact WHERE web_userid = 'nyswyn100'
SELECT  *  FROM    contactxref WHERE contact_id = 185547

SELECT  *  FROM    sysobjects where name like '%format%' and xtype = 'FN'

	2/13/2018	JPB		Created

sp_helptext fn_FormatPhoneNumber

exec sp_cor_customer_contact_list
	@web_userid = 'nyswyn100'
	, @customer_id = 15551


******************************************************************* */
-- Avoid query plan caching:
declare
	@i_web_userid		varchar(100) = @web_userid
	, @i_customer_id	int = @customer_id

declare @foo table (
		customer_id	int NOT NULL
	)
	
insert @foo
SELECT  
		x.customer_id
FROM    ContactCORCustomerBucket x (nolock) 
join CORContact c (nolock) on x.contact_id = c.contact_id and c.web_userid = @i_web_userid
WHERE
	x.customer_id = @i_customer_id

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
	    
return 0
go

grant execute on sp_cor_customer_contact_list to eqai, cor_user
go
