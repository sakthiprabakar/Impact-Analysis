-- drop proc sp_ContactCOR_AllCust_User_Setup
go
create proc sp_ContactCOR_AllCust_User_Setup
as
/* *************************************************************
sp_ContactCOR_AllCust_User_Setup

SELECT  *  FROM    CORcontact WHERE  web_userid = 'all_customers'
-- 211270
SELECT  *  FROM    CORcontactxref WHERE  contact_id = 211270

SELECT  *  FROM    CORcontactxrole WHERE  contact_id = 211270

SELECT  *  FROM    ContactCORCustomerBucket WHER E contact_id = 211270
SELECT  count(*)  FROM    ContactCORWorkorderHeaderBucket WHERE contact_id = 211270

************************************************************** */
/* NEW CODE... 

We created views
	vwCORContact
	vwCORContactXref
	vwCORContactXRole

And we told important *_Maintain processes to look at them.
 Turns out that's slow, so now we're replacing them with these tables
 so we can index them.
 
*/

if exists (Select 1 from sysobjects where xtype = 'u' and name = 'xCORContact')
	drop table xCORContact

select *
into xCORContact
from vwCORContact

-- Need indexes
create index idx_contact_id on xCORContact (contact_id) include (contact_status)

grant select on xCORContact to eqai
grant select on xCORContact to eqweb
grant select on xCORContact to cor_user


if exists (Select 1 from sysobjects where xtype = 'u' and name = 'CORContact')
	drop table CORContact

exec sp_rename xCORContact, CORContact


	
if exists (Select 1 from sysobjects where xtype = 'u' and name = 'xCORContactXref')
	drop table xCORContactXref

select *
into xCORContactXref
from vwCORContactXref

-- Need indexes
create index idx_contact_id on xCORContactXref (contact_id, customer_id, generator_id) include (web_access, status)

grant select on xCORContactXref to eqai
grant select on xCORContactXref to eqweb
grant select on xCORContactXref to cor_user

if exists (Select 1 from sysobjects where xtype = 'u' and name = 'CORContactXref')
	drop table CORContactXref

exec sp_rename xCORContactXref, CORContactXref



if exists (Select 1 from sysobjects where xtype = 'u' and name = 'xCORContactXRole')
	drop table xCORContactXRole

select *
into xCORContactXRole
from vwCORContactXRole

-- Need indexes
create index idx_contact_id on xCORContactXRole (contact_id)

grant select on xCORContactXRole to eqai
grant select on xCORContactXRole to eqweb
grant select on xCORContactXRole to cor_user


if exists (Select 1 from sysobjects where xtype = 'u' and name = 'CORContactXRole')
	drop table CORContactXRole

exec sp_rename xCORContactXRole, CORContactXRole


/*
OLD CODE...
declare @contact_id int

if not exists (select 1 from contact WHERE web_userid = 'all_customers') begin
	exec @contact_id = sp_sequence_next 'contact.contact_id'
	insert contact (contact_id, contact_status, contact_company, name, title, phone, email, email_flag, modified_by, date_added, date_modified, contact_addr1, contact_city, contact_state, contact_zip_code, web_access_flag, first_name, last_name, web_userid)
	values (@contact_id, 'A', 'US Ecology', 'All Customers Access', '', '8005905220', 'it@usecology.com', 'F', 'SA', getdate(), getdate(), 'US Ecology', 'Boise', 'ID', '83702', 'T', 'All Customers', 'Access', 'all_customers')
end
else
	select top 1 @contact_id = contact_id from contact WHERE web_userid = 'all_customers'

-- Roles
delete from ContactXRole where contact_id = @contact_id

insert ContactXRole (contact_id, roleid, status, added_by, date_added, modified_by, date_modified)
select  @contact_id, CAST( RoleId AS nvarchar(1000)) RoleId ,'A', 'SA', getdate(), 'SA', getdate()
from cor_db.[dbo].[RolesRef]
WHERE isactive = 1 and rolename not like '%Generator%' -- and rolename not like '%internal%'
ORDER BY CAST( RoleId AS nvarchar(1000))


-- Accounts
delete from contactxref WHERE contact_id = @contact_id

insert contactxref (contact_id, type, customer_id, web_access, status, added_by, date_added, modified_by, date_modified, primary_contact)
select @contact_id, 'C', customer_id, 'A', 'A', 'SA', getdate(), 'SA', getdate(), 'F'
from customer

insert contactxref (contact_id, type, generator_id, web_access, status, added_by, date_added, modified_by, date_modified, primary_contact)
select @contact_id, 'G', generator_id, 'A', 'A', 'SA', getdate(), 'SA', getdate(), 'F'
from generator

*/

go

grant execute on sp_ContactCOR_AllCust_User_Setup to eqai, eqweb, cor_user
go

