if exists (select 1 from sysobjects where type = 'P' and name = 'sp_ss_get_trip_transporters')
	drop procedure sp_ss_get_trip_transporters
go

create procedure sp_ss_get_trip_transporters
	@trip_id int,
	@trip_sequence_id int = 0
as
set transaction isolation level read uncommitted

select distinct wh.workorder_ID,
		wh.company_id,
		wh.profit_ctr_ID,
		wd.manifest,
		wt.transporter_sequence_id,
		coalesce(wt.transporter_code,'') transporter_code,
		t.transporter_name,
		coalesce(t.transporter_EPA_ID,'') transporter_EPAID,
		coalesce(t.transporter_phone,'') transporter_phone
from WorkOrderHeader wh
join WorkOrderDetail wd
	on wd.workorder_id = wh.workorder_ID
	and wd.company_id = wh.company_id
	and wd.profit_ctr_id = wh.profit_ctr_ID
	and wd.resource_type = 'D'
join WorkorderTransporter wt
	on wt.workorder_id = wd.workorder_ID
	and wt.company_id = wd.company_id
	and wt.profit_ctr_id = wd.profit_ctr_ID
	and wt.manifest = wd.manifest
join Transporter t
	on t.transporter_code = wt.transporter_code
where wh.trip_id = @trip_id
--and wh.workorder_status <> 'V'
and (@trip_sequence_id = 0 or wh.trip_sequence_id = @trip_sequence_id)
order by wh.workorder_id, wt.transporter_sequence_id
go

grant execute on sp_ss_get_trip_transporters to EQAI, TRIPSERV
go
