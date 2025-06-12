DROP PROCEDURE sp_trip_sync_get_workorderdetailunit
GO

create procedure sp_trip_sync_get_workorderdetailunit
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure synchronizes the WorkOrderDetailUnit table

 loads to Plt_ai
 
 04/22/2009 - rb created
 12/01/2009 - rb pull directly from TSDFApprovalPrice and ProfileQuoteApproval tables
 02/25/2010 - rb 12/01/2009 change should only happen for stops not modified yet
 01/19/2011 - rb Column changes to all Workorder-related tables
 02/21/2011 - rb BillUnit table was in From clause of 2nd SQL, unused - removed
 07/13/2011 - rb Added WorkOrderDetail.date_added > last_download_date to where clause
 08/22/2012 - rb Modified for change where billing_flag can be changed in EQAI
 09/27/2012 - rb There was a bug in the update statements that prevented it from 
                 setting the manifest_flag if there was not one set in WorkOrderDetailUnit
 10/25/2012 - rb Fixed bug with last revision, trips with approvals that did not have
                 manifested unit in the Price tab were setting manifest_flag on wrong units
 03/12/2013 - rb Fixed bug...pulling for TSDFApprovals was checking wrong eq_flag value, 'T'
 08/05/2015 - rb Modify join from manifest_wt_vol_unit to BillUnit an outer join
 06/13/2016 - rb GEM:37924 - Now that validation ensures manifest unit set on workorder,
                 remove the section of sql that pulls Profile manifest_wt_vol_unit
 04/05/2018 - mm GEM 48441:  Added an update of manifest_flag to correct
				 the issue.

04/05/2018 -  oe Do:17173:  locking issue sp_trip_sync_get_workorderdetailunit , added sql hint for performance issue 
				 the issue.
****************************************************************************************/

declare @workorder_id int,
	@company_id int,
	@profit_ctr_id int,
	@manifest_unit varchar(15)

set transaction isolation level read uncommitted

set nocount on

create table #m (
workorder_id int not null,
company_id int not null,
profit_ctr_id int not null,
sequence_id int not null,
bill_unit_code varchar(4) not null,
manifest_flag char(1) null,
billing_flag char(1) null,
added_by varchar(10) null,
date_added datetime null,
modified_by varchar(10) null,
date_modified datetime null
)

-- codes defined in WorkOrderDetailUnit
insert #m
select distinct wodu.workorder_id, wodu.company_id, wodu.profit_ctr_id, wodu.sequence_id,
		wodu.size, isnull(wodu.manifest_flag,'F'), isnull(wodu.billing_flag,'F'), 
		wod.added_by, wod.date_added, wod.modified_by, wod.date_modified
from WorkOrderDetailUnit wodu (nolock)
join WorkOrderDetail wod (nolock)
	on wodu.workorder_id = wod.workorder_ID
	and wodu.company_id = wod.company_id
	and wodu.profit_ctr_id = wod.profit_ctr_id
	and wodu.sequence_id = wod.sequence_id
	and wod.resource_type = 'D'
join WorkOrderHeader woh with (index(idx_trip_id)) 
	on wod.workorder_id = woh.workorder_id
	and wod.company_id = woh.company_id
	and wod.profit_ctr_id = woh.profit_ctr_id
	and woh.workorder_status <> 'V'
join TripConnectLog tcl (nolock)
	on woh.trip_id = tcl.trip_id
	and tcl.trip_connect_log_id = @trip_connect_log_id
where (woh.field_upload_date is null or tcl.last_download_date is null)
and isnull(wod.field_requested_action,'') <> 'D'
and isnull(woh.field_requested_action,'') <> 'D'
and (woh.date_added > isnull(tcl.last_download_date,'01/01/1900') or
	wod.date_added > isnull(tcl.last_download_date,'01/01/1900') or
	wodu.date_modified > isnull(tcl.last_download_date,'01/01/1900') or
	woh.field_requested_action = 'R')

-- codes not defined in WorkOrderDetailUnit (Profile)
-- rb 06/13/2016 WorkOrderDetailUnit now contains manifest unit for certain...these manifest_flags should now always be 'F'
insert #m
select distinct wod.workorder_id, wod.company_id, wod.profit_ctr_id, wod.sequence_id,
		pqd.bill_unit_code, 'F', 'T', 'SA', GETDATE(), 'SA', GETDATE()
from ProfileQuoteDetail pqd (nolock)
join Profile p (nolock)
	on pqd.profile_id = p.profile_id
join WorkOrderDetail wod (nolock)
	on pqd.profile_id = wod.profile_id
	and pqd.company_id = wod.profile_company_id
	and pqd.profit_ctr_id = wod.profile_profit_ctr_id
	and wod.resource_type = 'D'
join TSDF t (nolock)
	on wod.TSDF_code = t.TSDF_code
	and ISNULL(t.eq_flag, 'F') = 'T'
join WorkOrderHeader woh with (index(idx_trip_id))
	on wod.workorder_id = woh.workorder_id
	and wod.company_id = woh.company_id
	and wod.profit_ctr_id = woh.profit_ctr_id
	and woh.workorder_status <> 'V'
join TripConnectLog tcl (nolock)
	on woh.trip_id = tcl.trip_id
	and tcl.trip_connect_log_id = @trip_connect_log_id
where pqd.record_type = 'D'
and pqd.status = 'A'
and (woh.field_upload_date is null or tcl.last_download_date is null)
and isnull(wod.field_requested_action,'') <> 'D'
and isnull(woh.field_requested_action,'') <> 'D'
and (woh.date_added > isnull(tcl.last_download_date,'01/01/1900') or
	wod.date_added > isnull(tcl.last_download_date,'01/01/1900') or
	pqd.date_modified > isnull(tcl.last_download_date,'01/01/1900') or
	woh.field_requested_action = 'R')
and not exists (select 1 from #m
				where workorder_id = wod.workorder_ID
				and company_id = wod.company_id
				and profit_ctr_id = wod.profit_ctr_id
				and sequence_id = wod.sequence_ID
				and bill_unit_code = pqd.bill_unit_code)


-- codes not defined in WorkOrderDetailUnit (TSDFApproval)
-- rb 06/13/2016 WorkOrderDetailUnit now contains manifest unit for certain...these manifest_flags should now always be 'F'
insert #m
select distinct wod.workorder_id, wod.company_id, wod.profit_ctr_id, wod.sequence_id,
		tap.bill_unit_code, 'F', 'T', 'SA', GETDATE(), 'SA', GETDATE()
from TSDFApprovalPrice tap (nolock)
join TSDFApproval ta (nolock)
	on tap.tsdf_approval_id = ta.tsdf_approval_id
	and ta.TSDF_approval_status = 'A'
join WorkOrderDetail wod (NOLOCK)
	on ta.TSDF_approval_id = wod.TSDF_approval_id
	and wod.resource_type = 'D'
join TSDF t (nolock)
	on wod.TSDF_code = t.TSDF_code
	and ISNULL(t.eq_flag, 'F') = 'F'
join WorkOrderHeader woh with (index(idx_trip_id))
	on wod.workorder_id = woh.workorder_id
	and wod.company_id = woh.company_id
	and wod.profit_ctr_id = woh.profit_ctr_id
	and woh.workorder_status <> 'V'
join TripConnectLog tcl (nolock)
	on woh.trip_id = tcl.trip_id
	and tcl.trip_connect_log_id = @trip_connect_log_id
where tap.record_type = 'D'
and (woh.field_upload_date is null or tcl.last_download_date is null)
and isnull(wod.field_requested_action,'') <> 'D'
and isnull(woh.field_requested_action,'') <> 'D'
and (woh.date_added > isnull(tcl.last_download_date,'01/01/1900') or
	wod.date_added > isnull(tcl.last_download_date,'01/01/1900') or
	tap.date_modified > isnull(tcl.last_download_date,'01/01/1900') or
	woh.field_requested_action = 'R')
and not exists (select 1 from #m
				where workorder_id = wod.workorder_ID
				and company_id = wod.company_id
				and profit_ctr_id = wod.profit_ctr_id
				and sequence_id = wod.sequence_ID
				and bill_unit_code = tap.bill_unit_code)

-- MPM - 4/5/2018 - Fix for GEM 48441
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

set nocount off

select 'if exists (select 1 from WorkOrderDetailUnit where workorder_id=' + convert(varchar(20),#m.workorder_id) + ' and company_id=' + convert(varchar(20),#m.company_id) + ' and profit_ctr_id=' + convert(varchar(20),#m.profit_ctr_id) + ' and sequence_id=' + convert(varchar(20),#m.sequence_id) + ' and size=''' + #m.bill_unit_code + ''''
+ ') update WorkOrderDetailUnit set billing_flag=''' + #m.billing_flag + ''','
+ 'manifest_flag=''' + #m.manifest_flag + ''''
+ ' where workorder_id=' + convert(varchar(20),#m.workorder_id)
+ ' and company_id=' + convert(varchar(20),#m.company_id)
+ ' and profit_ctr_id=' + convert(varchar(20),#m.profit_ctr_id)
+ ' and sequence_id=' + convert(varchar(20),#m.sequence_id)
+ ' and size=''' + #m.bill_unit_code + ''''
+ ' else insert WorkOrderDetailUnit values ('
+ convert(varchar(20),#m.workorder_id) + ','
+ convert(varchar(20),#m.company_id) + ','
+ convert(varchar(20),#m.profit_ctr_id) + ','
+ convert(varchar(20),#m.sequence_id) + ','
+ '''' + replace(#m.bill_unit_code, '''', '''''') + '''' + ','
+ '''' + replace(#m.bill_unit_code, '''', '''''') + '''' + ','
+ 'null' + ','
+ 'null' + ','
+ 'null' + ','
+ 'null' + ','
+ 'null' + ','
+ 'null' + ','
+ 'null' + ','
+ '''' + replace(#m.manifest_flag, '''', '''''') + '''' + ','
+ '''' + replace(#m.billing_flag, '''', '''''') + '''' + ','
+ 'null' + ','
+ 'null' + ','
+ isnull('''' + replace(#m.added_by, '''', '''''') + '''','null') + ','
+ '''' + convert(varchar(20),dateadd(yy,-2,#m.date_added),120) + '''' + ','
+ '''' + replace(#m.modified_by, '''', '''''') + '''' + ','
+ '''' + convert(varchar(20),dateadd(yy,-2,#m.date_modified),120) + '''' + ')' as sql
from #m

drop table #m

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_sync_get_workorderdetailunit] TO [EQAI]
    AS [dbo];

