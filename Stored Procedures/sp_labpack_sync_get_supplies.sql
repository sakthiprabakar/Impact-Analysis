create procedure [dbo].[sp_labpack_sync_get_supplies]
	@company_id int,
	@profit_ctr_id int
as
set transaction isolation level read uncommitted

select distinct resource_class_code, description
from ResourceClass
where resource_type = 'S'
and status = 'A'
and company_id = @company_id
and profit_ctr_id = @profit_ctr_id
order by resource_class_code