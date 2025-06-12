
create procedure sp_trip_sync_generate_deletes
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure returns any delete statements that may need to be issues before inserts

 loads to Plt_ai
 
 06/19/2009 - rb created
****************************************************************************************/

select 'if exists (select 1 from WorkOrderStop where date_act_arrive is not null'
+ ' and workorder_id = ' + convert(varchar(10),wodcc.workorder_id)
+ ' and company_id = ' + convert(varchar(10),wodcc.company_id)
+ ' and profit_ctr_id = ' + convert(varchar(10),wodcc.profit_ctr_id)
+ ') exec sp_inform_already_arrived '
+ convert(varchar(10),woh.trip_id) + ', '
+ convert(varchar(10),woh.trip_sequence_id)
+ ', null else delete from WorkOrderDetailCC'
+ ' where workorder_id = ' + convert(varchar(10),wodcc.workorder_id)
+ ' and company_id = ' + convert(varchar(10),wodcc.company_id)
+ ' and profit_ctr_id = ' + convert(varchar(10),wodcc.profit_ctr_id)
+ ' and sequence_id = ' + convert(varchar(10),wodcc.sequence_id)
from WorkOrderDetailCC wodcc, WorkOrderDetail wod, WorkOrderHeader woh, TripConnectLog tcl
where wodcc.workorder_id = wod.workorder_id
and wodcc.company_id = wod.company_id
and wodcc.profit_ctr_id = wod.profit_ctr_id
and wodcc.sequence_id = wod.sequence_id
and wod.workorder_id = woh.workorder_id
and wod.company_id = woh.company_id
and wod.profit_ctr_id = woh.profit_ctr_id
and wod.resource_type = 'D'
and woh.trip_id = tcl.trip_id
and tcl.trip_connect_log_id = @trip_connect_log_id
and (woh.field_requested_action in ('D','R') or
	 wod.field_requested_action = 'D')
union
select 'if exists (select 1 from WorkOrderStop where date_act_arrive is not null'
+ ' and workorder_id = ' + convert(varchar(10),wod.workorder_id)
+ ' and company_id = ' + convert(varchar(10),wod.company_id)
+ ' and profit_ctr_id = ' + convert(varchar(10),wod.profit_ctr_id)
+ ') exec sp_inform_already_arrived '
+ convert(varchar(10),woh.trip_id) + ', '
+ convert(varchar(10),woh.trip_sequence_id)
+ ', null else delete from WorkOrderDetail'
+ ' where workorder_id = ' + convert(varchar(10),wod.workorder_id)
+ ' and company_id = ' + convert(varchar(10),wod.company_id)
+ ' and profit_ctr_id = ' + convert(varchar(10),wod.profit_ctr_id)
+ ' and sequence_id = ' + convert(varchar(10),wod.sequence_id)
+ ' and resource_type = ''' + wod.resource_type + ''''
from WorkOrderDetail wod, WorkOrderHeader woh, TripConnectLog tcl
where wod.workorder_id = woh.workorder_id
and wod.company_id = woh.company_id
and wod.profit_ctr_id = woh.profit_ctr_id
and wod.resource_type = 'D'
and woh.trip_id = tcl.trip_id
and tcl.trip_connect_log_id = @trip_connect_log_id
and (woh.field_requested_action in ('D','R') or
	 wod.field_requested_action = 'D')
union
select 'if exists (select 1 from WorkOrderStop where date_act_arrive is not null'
+ ' and workorder_id = ' + convert(varchar(10),wom.workorder_id)
+ ' and company_id = ' + convert(varchar(10),wom.company_id)
+ ' and profit_ctr_id = ' + convert(varchar(10),wom.profit_ctr_id)
+ ') exec sp_inform_already_arrived '
+ convert(varchar(10),woh.trip_id) + ', '
+ convert(varchar(10),woh.trip_sequence_id)
+ ', null else delete from WorkOrderManifest'
+ ' where workorder_id = ' + convert(varchar(10),wom.workorder_id)
+ ' and company_id = ' + convert(varchar(10),wom.company_id)
+ ' and profit_ctr_id = ' + convert(varchar(10),wom.profit_ctr_id)
from WorkOrderManifest wom, WorkOrderHeader woh, TripConnectLog tcl
where wom.workorder_id = woh.workorder_id
and wom.company_id = woh.company_id
and wom.profit_ctr_id = woh.profit_ctr_id
and woh.trip_id = tcl.trip_id
and tcl.trip_connect_log_id = @trip_connect_log_id
and woh.field_requested_action in ('D','R')
union
select 'if exists (select 1 from WorkOrderStop where date_act_arrive is not null'
+ ' and workorder_id = ' + convert(varchar(10),woh.workorder_id)
+ ' and company_id = ' + convert(varchar(10),woh.company_id)
+ ' and profit_ctr_id = ' + convert(varchar(10),woh.profit_ctr_id)
+ ') exec sp_inform_already_arrived '
+ convert(varchar(10),woh.trip_id) + ', '
+ convert(varchar(10),woh.trip_sequence_id)
+ ', null else delete from WorkOrderHeader'
+ ' where workorder_id = ' + convert(varchar(10),woh.workorder_id)
+ ' and company_id = ' + convert(varchar(10),woh.company_id)
+ ' and profit_ctr_id = ' + convert(varchar(10),woh.profit_ctr_id)
from WorkOrderHeader woh, TripConnectLog tcl
where woh.trip_id = tcl.trip_id
and tcl.trip_connect_log_id = @trip_connect_log_id
and woh.field_requested_action in ('D','R')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_generate_deletes] TO [EQAI]
    AS [dbo];

