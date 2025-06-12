create procedure [dbo].[sp_labpack_sync_get_workorderdetailunit]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the WorkOrderDetailUnit details

 loads to Plt_ai
 
 11/04/2019 - rb created
 12/14/2021 - rb potentially pull bill units from ProfileQuoteDetail and TSDFApprovalPrice

exec sp_labpack_sync_get_workorderdetailunit 277670

****************************************************************************************/

declare @trip_id int

set transaction isolation level read uncommitted

create table #m (
workorder_id int not null,
company_id int not null,
profit_ctr_id int not null,
sequence_id int not null,
bill_unit_code varchar(4) not null,
size varchar(4) null,
manifest_flag char(1) null,
billing_flag char(1) null,
date_added datetime null,
date_modified datetime null
)

select @trip_id = trip_id
from TripConnectLog
where trip_connect_log_id = @trip_connect_log_id

-- codes defined in WorkOrderDetailUnit
insert #m
select distinct wodu.workorder_id, wodu.company_id, wodu.profit_ctr_id, wodu.sequence_id,
		wodu.bill_unit_code, wodu.size, isnull(wodu.manifest_flag,'F'), isnull(wodu.billing_flag,'F'), 
		wod.date_added, wod.date_modified
from WorkOrderDetailUnit wodu
join WorkOrderDetail wod
	on wodu.workorder_id = wod.workorder_ID
	and wodu.company_id = wod.company_id
	and wodu.profit_ctr_id = wod.profit_ctr_id
	and wodu.sequence_id = wod.sequence_id
	and wod.resource_type = 'D'
join WorkOrderHeader woh
	on wod.workorder_id = woh.workorder_id
	and wod.company_id = woh.company_id
	and wod.profit_ctr_id = woh.profit_ctr_id
	and woh.workorder_status <> 'V'
	and woh.trip_id = @trip_id

-- codes not defined in WorkOrderDetailUnit (Profile)
insert #m
select distinct wod.workorder_id, wod.company_id, wod.profit_ctr_id, wod.sequence_id,
		pqd.bill_unit_code, pqd.bill_unit_code, 'F', 'T', GETDATE(), GETDATE()
from WorkOrderDetail wod
join TSDF t
	on t.TSDF_code = wod.TSDF_code
	and ISNULL(t.eq_flag, 'F') = 'T'
join ProfileQuoteDetail pqd
	on pqd.profile_id = wod.profile_id
	and pqd.company_id = wod.profile_company_id
	and pqd.profit_ctr_id = wod.profile_profit_ctr_id
	and pqd.record_type = 'D'
	and pqd.status = 'A'
where wod.workorder_id in (select workorder_id from WorkOrderHeader where trip_id = @trip_id and workorder_status <> 'V')
and wod.company_id = (select company_id from TripHeader where trip_id = @trip_id)
and wod.profit_ctr_id = (select profit_ctr_id from TripHeader where trip_id = @trip_id)
and wod.resource_type = 'D'
and not exists (select 1 from #m
				where workorder_id = wod.workorder_ID
				and company_id = wod.company_id
				and profit_ctr_id = wod.profit_ctr_id
				and sequence_id = wod.sequence_ID
				and bill_unit_code = pqd.bill_unit_code)

-- codes not defined in WorkOrderDetailUnit (TSDFApproval)
insert #m
select distinct wod.workorder_id, wod.company_id, wod.profit_ctr_id, wod.sequence_id,
		tap.bill_unit_code, tap.bill_unit_code, 'F', 'T', GETDATE(), GETDATE()
from WorkOrderDetail wod
join TSDF t
	on t.TSDF_code = wod.TSDF_code
	and ISNULL(t.eq_flag, 'F') = 'F'
join TSDFApproval ta
	on ta.tsdf_approval_id = wod.tsdf_approval_id
	and ta.TSDF_approval_status = 'A'
join TSDFApprovalPrice tap
	on tap.tsdf_approval_id = ta.tsdf_approval_id
	and tap.record_type = 'D'
where wod.workorder_id in (select workorder_id from WorkOrderHeader where trip_id = @trip_id and workorder_status <> 'V')
and wod.company_id = (select company_id from TripHeader where trip_id = @trip_id)
and wod.profit_ctr_id = (select profit_ctr_id from TripHeader where trip_id = @trip_id)
and wod.resource_type = 'D'
and not exists (select 1 from #m
				where workorder_id = wod.workorder_ID
				and company_id = wod.company_id
				and profit_ctr_id = wod.profit_ctr_id
				and sequence_id = wod.sequence_ID
				and bill_unit_code = tap.bill_unit_code)

-- Fix for GEM 48441
update #m
set manifest_flag = 'T'
from #m m
where bill_unit_code = 'LBS'
and not exists (select 1 from #m
                        where workorder_id = m.workorder_id
                        and company_id = m.company_id
                        and profit_ctr_id = m.profit_ctr_id
                        and sequence_id = m.sequence_id
                        and manifest_flag = 'T')

select * from #m order by sequence_id, bill_unit_code

/*
select distinct
	wdu.workorder_id,
	wdu.company_id,
	wdu.profit_ctr_id,
	wdu.sequence_id,
	wdu.bill_unit_code,
	wdu.size,
	isnull(wdu.manifest_flag,'F') manifest_flag,
	isnull(wdu.billing_flag,'F') billing_flag, 
	wdu.date_added,
	wdu.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join WorkOrderDetail wd
	on wd.workorder_id = wh.workorder_id
	and wd.company_id = wh.company_id
	and wd.profit_ctr_id = wh.profit_ctr_id
	and wd.resource_type = 'D'
join WorkOrderDetailUnit wdu
	on wdu.workorder_id = wd.workorder_ID
	and wdu.company_id = wd.company_id
	and wdu.profit_ctr_id = wd.profit_ctr_id
	and wdu.sequence_id = wd.sequence_id
where tcl.trip_connect_log_id = @trip_connect_log_id
*/