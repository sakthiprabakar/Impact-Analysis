-- Drop Proc If Exists sp_packback_user_account_list
go

create proc sp_packback_user_account_list (
	@contact_id int
) as
/* *****************************************************************
sp_packback_user_account_list

	Lists the accounts (if any) available for "charge to account" use
	in packback to a user.
	
	USE Employee users will return "-1" as customer_id, indicating ANY active customer
	can be used.
	
	TODO: I thought there was a role for "Internal" users but as of 7/28/22 it's disabled.
	Would've been nice to tie "Any Customer" functionality to known internal users
	short of imprecise matching on Contact.email = Users.email
	
	SELECT  * FROM    contact WHERE  web_userid = 'nyswyn100'
	SELECT  * FROM    contact WHERE  contact_id = 172888
	SELECT  * FROM    contact WHERE  name like '%ryan%rush%' -- 162773
	SELECT  * FROM    contact WHERE  web_userid is not null ORDER BY date_modified desc
	
	sp_packback_user_account_list 214155 -- iceman
	sp_packback_user_account_list 11289 -- nyswyn100
	sp_packback_user_account_list 218672 -- random external user

	SELECT  * FROM    cor_db..rolesref WHERE  rolename like '%internal%'
	select r.rolename from cor_db..rolesref r
	inner join plt_ai..ContactXRole cxr on r.roleid = cxr.roleid
	inner join plt_ai..Contact c on cxr.contact_id = c.contact_id
	WHERE  c.web_userid = 'iceman'
	
	
***************************************************************** */

declare
	@i_contact_id int = isnull(@contact_id, -12345)
	
if exists ( -- If this contact_ID matches a USER record and has AccountUser access...

-- declare	@i_contact_id int = 214155
	select 1 from users u
	join contact c
	on u.email = c.email
	join contactxrole cxr
	on c.contact_id = cxr.contact_id
	join cor_db..rolesref r
	on cxr.roleid = r.roleid
	WHERE c.contact_id = @i_contact_id
	and c.web_userid is not null
	and r.rolename = 'PackBack-AccountUser'
	
) begin
	select -1 as customer_id, 'Any Active Customer' as customer_id
	return
end

-- declare	@i_contact_id int = 172888
	select cust.customer_id, cust.cust_name 
	from contact c
	join contactxrole cxr
	on c.contact_id = cxr.contact_id
	join cor_db..rolesref r
	on cxr.roleid = r.roleid
	join ContactCORCustomerBucket b
	on c.contact_id = b.contact_id
	join customer cust
	on b.customer_id = cust.customer_id
	WHERE c.contact_id = @i_contact_id
	and c.web_userid is not null
	and r.rolename = 'PackBack-AccountUser'
	order by cust.cust_name
	
go

grant execute on sp_packback_user_account_list to cor_user
go
