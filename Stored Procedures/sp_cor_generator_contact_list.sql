-- drop proc sp_cor_generator_contact_list 
go

create procedure sp_cor_generator_contact_list (
	@web_userid			varchar(100)
	, @generator_id		int
	, @customer_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
) as

/* *******************************************************************
sp_cor_generator_contact_list

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

SELECT  *  FROM    ContactCORGeneratorBucket x WHERE contact_id = 185547
and exists (select 1 from contactxref WHERE generator_id = x.generator_id and status = 'A')

exec sp_cor_generator_contact_list
	@web_userid = 'nyswyn100'
	, @generator_id = 136295


******************************************************************* */
-- Avoid query plan caching:
declare
	@i_web_userid		varchar(100) = @web_userid
	, @i_generator_id	int = @generator_id

declare @foo table (
		generator_id	int NOT NULL
	)
	
insert @foo
SELECT  
		x.generator_id
FROM    ContactCORGeneratorBucket x (nolock) 
join CORContact c (nolock) on x.contact_id = c.contact_id and c.web_userid = @i_web_userid
WHERE
	x.generator_id = @i_generator_id

	select
		c.contact_id
		, c.name
		, c.title
		, c.phone
		-- , dbo.fn_FormatPhoneNumber(c.phone)
		, c.email
	from @foo z 
	join ContactXref x on z.generator_id = x.generator_id and x.type = 'G' and x.status = 'A'
	join Contact c on x.contact_id = c.contact_id and c.contact_status = 'A'
	order by c.name
	    
return 0
go

grant execute on sp_cor_generator_contact_list to eqai, cor_user
go
