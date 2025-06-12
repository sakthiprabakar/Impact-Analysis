-- drop proc if exists [sp_cor_webcustomer_access]
go

create proc [dbo].[sp_cor_webcustomer_access]
(
	@web_userid	varchar(100)
)
as
/* *****************************************************************************
sp_cor_webcustomer_access

Takes an input @web_userid and returns the folder name and display name
of any web-customer folders they should be able to access

[sp_cor_webcustomer_access] 'nyswyn100'
[sp_cor_webcustomer_access] 'AMAVI@LEAR.COM'
[sp_cor_webcustomer_access] 'all_customers'

***************************************************************************** */

-- declare @web_userid varchar(100) = 'AMAVI@LEAR.COM'

declare @i_contact_id int	

select @i_contact_id = contact_id from contact where web_userid = @web_userid
-- SELECT  @i_contact_id

select 
-- x.contact_id, 
cdp.display_name
, cdp.folder_name foldername
from EQWeb..CORDocumentPermission cdp (nolock)
join PLT_AI..contactcorcustomerbucket b (nolock)
	on cdp.customer_id = b.customer_id
join PLT_AI..ContactXRole cxr (nolock)
	on cxr.contact_id = b.contact_id and isnull(cxr.status, 'I') = 'A'
join COR_DB..RolesRef rr  (nolock)
	on cxr.roleid = rr.roleid
WHERE b.contact_id = @i_contact_id
and rr.rolename = 'Documents'
and cdp.status = 'A'
ORDER BY cdp.display_name


return 0
go

grant execute on sp_cor_webcustomer_access to eqweb, cor_user, svc_corappuser

go

