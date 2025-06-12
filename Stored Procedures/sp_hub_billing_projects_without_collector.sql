-- drop proc if exists sp_hub_billing_projects_without_collector
go

create proc sp_hub_billing_projects_without_collector
as
/* ****************************************************************
sp_hub_billing_projects_without_collector

DO-1720 - Reporting billing projects without a collector

**************************************************************** */

select 
	cb.collections_id
	, u.user_code
	, u.user_name
	, c.cust_name
	, c.customer_id
	, cb.billing_project_id
	, c.cust_status [customer status]
	, cb.status [customerbilling status]
	, c.terms_code [customer terms_code]
from customerbilling cb
join customer c
	on c.customer_id = cb.customer_id
left outer join UsersXEQContact ux
	on cb.collections_id = ux.type_id
left outer join users u 
	on u.user_code = ux.user_code
	and ux.EQcontact_type = 'Collections'
where 1=1
-- and c.cust_status = 'A'
and c.cust_prospect_flag = 'C'
and cb.collections_id is null

go

grant execute on sp_hub_billing_projects_without_collector to eqai
go
grant execute on sp_hub_billing_projects_without_collector to eqweb
go
grant execute on sp_hub_billing_projects_without_collector to crm_service
go

