-- drop proc sp_cor_schedule_service_status_list
go

create procedure sp_cor_schedule_service_status_list
as

/* *******************************************************************
sp_cor_schedule_service_status_list
This is a hard-coded list.
	
******************************************************************* */

select status from (
select 'Requested' as status, 1 as status_order
union
select 'Scheduled', 2
union
select 'Completed', 3
union 
select 'Invoiced', 4
) y
order by status_order

return 0
go

grant execute on sp_cor_schedule_service_status_list to eqai, eqweb, COR_USER
go
