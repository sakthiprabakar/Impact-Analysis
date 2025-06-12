-- drop proc if exists sp_cor_login_check_allowed
go
create proc sp_cor_login_check_allowed (
	@web_userid	varchar(100) = ''
)
as
/* ***********************************************************************************
sp_cor_login_check_allowed

Returns 1 (true) or 0 (false) if @web_userid is allowed to log in (checks their accounts
to see if any are active & allowed to log in)

sp_cor_login_check_allowed 'maverick' -- pass
sp_cor_login_check_allowed 'foop' -- fail
sp_cor_login_check_allowed 'neal.jonny@cleanharbors.com' -- fail
sp_cor_login_check_allowed 'all_customers' -- pass
sp_cor_login_check_allowed 'karent' -- pass

SELECT  * FROM    contact WHERE isnull(web_userid, '')> '' and contact_status = 'A'
	and not exists (select 1 from contactxref where contact_id= contact.contact_id and status = 'A')
*********************************************************************************** */

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED -- This is easier than adding WITH (NOLOCK) to every table.
SET NOCOUNT, XACT_ABORT ON

declare @i_web_userid varchar(100) = isnull(@web_userid, '')
	, @i_contact_id int
	declare @fail_reason table (reason varchar(100))
	
select top 1 @i_contact_id = contact_id from corcontact where web_userid = @i_web_userid

if 0 = (select count(*) from corcontact where contact_id = @i_contact_id and contact_status = 'A')
	insert @fail_reason values ('No active Contact record')
	if (select count(*) from @fail_reason) > 0 goto fail

if 0 = (select count(*) from corcontact where contact_id = @i_contact_id and web_access_flag = 'T')
	insert @fail_reason values ('No Contact web access authorized')
	if (select count(*) from @fail_reason) > 0 goto fail

if 0 = (select count(*) from corcontactxref where contact_id = @i_contact_id and status = 'A' and web_access = 'A')
	insert @fail_reason values ('No active Contact Access to Customers or Generators')
	if (select count(*) from @fail_reason) > 0 goto fail

if 0 = (select count(*) from corcontactxrole where contact_id = @i_contact_id and status = 'A')
	insert @fail_reason values ('No active Contact roles')
	if (select count(*) from @fail_reason) > 0 goto fail

if 0 = (select count(*) from contactcorcustomerbucket where contact_id = @i_contact_id) 
		+ 
		(select count(*) from contactcorgeneratorbucket where contact_id = @i_contact_id)
	insert @fail_reason values ('No active Contact Access to Customers or Generators')
	if (select count(*) from @fail_reason) > 0 goto fail

--if 0 = (select count(*) from contactxref x join customer c on x.customer_id = c.customer_id and x.type = 'C'
--	where x.contact_id = @i_contact_id and c.cust_status = 'A' and c.terms_code not in ('NOADMIT') and x.status = 'A' and x.web_access = 'A')
--	insert @fail_reason values ('No active Customers assigned to Contact')
--	if (select count(*) from @fail_reason) > 0 goto fail

--if 0 = (select count(*) from contactxref x join generator g on x.generator_id = g.generator_id and x.type = 'G'
--	where x.contact_id = @i_contact_id) --and g.generator_status = 'A' -- inactive generators are ok.
--	insert @fail_reason values ('No active Generators assigned to Contact')
--	if (select count(*) from @fail_reason) > 0 goto fail
	
pass:
	select 1, 'Allowed' as reason
	return

fail:
	select 0, reason from @fail_reason
	return

go

grant execute on sp_cor_login_check_allowed to cor_user
go
grant execute on sp_cor_login_check_allowed to eqai
go
grant execute on sp_cor_login_check_allowed to eqweb
go
