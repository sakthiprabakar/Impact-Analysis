-- drop proc sp_cor_get_customer_logo
go

create proc sp_cor_get_customer_logo (
	@web_userid	varchar(100)
)
as
/* **************************************************************
sp_cor_get_customer_logo

If the current @web_userid value has exactly 1 entry in eqweb..CustomerLogo
we return the path to that image.  Otherwise return no results.

sample

sp_cor_get_customer_logo @web_userid = 'zachery.wright'

sp_cor_get_customer_logo @web_userid = 'nyswyn100'

************************************************************** */

declare 
	@i_web_userid	varchar(max) = isnull(@web_userid, '')
	, @i_contact_id	int
	
declare @logos table (
	customer_id		int
	, logo_url		varchar(max)
)


select top 1 @i_contact_id = contact_id
from CORcontact where web_userid = @i_web_userid

insert @logos
select distinct cl.customer_id, cl.logo_url
from eqweb..CustomerLogo cl
join ContactCORCustomerBucket b
	on cl.customer_id = b.customer_id
where b.contact_id = @i_contact_id

if (select count(*) from @logos) = 1
	select customer_id, logo_url from @logos

return 0
go

grant execute on sp_cor_get_customer_logo to eqweb, cor_user
go


