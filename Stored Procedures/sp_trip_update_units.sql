--DROP PROCEDURE sp_trip_update_units
--GO

CREATE PROCEDURE sp_trip_update_units (
	@trip_id			int, 
	@company_id			int, 
	@profit_ctr_id		int,
	@user_code			varchar(10) 
) 
WITH RECOMPILE 
AS
/*******************************************************************************************
12/14/2010 KAM	Created
03/23/2011 RWB	Modified billing_flag population to 'T' if pricing records exist
02/23/2018 MPM	Modified to populate new column currency_code.
11/06/2020 MPM	DevOps 17932 - Modified by adding "with recompile” and “set transaction 
				isolation level read uncommitted” to prevent DB blocking.

sp_trip_update_units 2107,14,0,'KAM'

*******************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

Delete from workorderdetailunit 
from workorderdetailunit 
join workorderheader on workorderdetailunit.company_id = workorderheader.company_id
					and workorderdetailunit.profit_ctr_id = workorderheader.profit_ctr_id
					and workorderdetailunit.workorder_id = workorderheader.workorder_id
Where WorkorderHeader.company_id = @company_id
and WorkorderHeader.profit_ctr_id = @profit_ctr_id
and WorkorderHeader.trip_id = @trip_id



Insert into WorkOrderDetailUnit 
(workorder_id, 
company_id, 
profit_ctr_id, 
sequence_id, 
size, 
bill_unit_code,
quantity,
manifest_flag,
billing_flag,
added_by,
date_added,
modified_by,
date_modified,
currency_code)
Select wod.workorder_id,
wod.company_id,
wod.profit_ctr_id,
wod.sequence_id,
billunit.bill_unit_code,
billunit.bill_unit_code,
0,
'T',
-- rb 03/23/2011 billing_flag
case when exists (select 1 from ProfileQuoteDetail pqd
					where pqd.profile_id = Profile.profile_id
					and pqd.company_id = wod.profile_company_id
					and pqd.profit_ctr_id = wod.profile_profit_ctr_id
					and pqd.status = 'A'
					and pqd.record_type = 'D'
					and pqd.bill_unit_code = BillUnit.bill_unit_code) then 'T'
	else 'F' end,
@user_code,
GETDATE(),
@user_code,
GetDate(),
wod.currency_code
From Workorderdetail wod join WorkOrderheader on wod.company_id = workorderheader.company_id
					and wod.profit_ctr_id = workorderheader.profit_ctr_id
					and wod.workorder_id = workorderheader.workorder_id
	Join profile on profile.Profile_id = wod.profile_id
	join BillUnit on profile.manifest_wt_vol_unit = BillUnit.manifest_unit
	Join TSDF on tsdf.tsdf_code = wod.tsdf_code
	Where wod.resource_type = 'D'
	and workorderheader.trip_id = @trip_id
	and IsNull(tsdf.eq_flag,'F') = 'T'
	
Union
Select wod.workorder_id,
wod.company_id,
wod.profit_ctr_id,
wod.sequence_id,
billunit.bill_unit_code,
billunit.bill_unit_code,
0,
'T',
-- rb 03/23/2011 billing_flag
case when exists (select 1 from TSDFApprovalPrice tap
					where tap.TSDF_approval_id = TSDFApproval.tsdf_approval_id
					and tap.company_id = TSDFApproval.company_id
					and tap.profit_ctr_id = TSDFApproval.profit_ctr_id
					and tap.status = 'A'
					and tap.record_type = 'D'
					and tap.bill_unit_code = BillUnit.bill_unit_code) then 'T'
	else 'F' end,
@user_code,
GETDATE(),
@user_code,
GetDate(),
wod.currency_code
From Workorderdetail wod join WorkOrderheader on wod.company_id = workorderheader.company_id
					and wod.profit_ctr_id = workorderheader.profit_ctr_id
					and wod.workorder_id = workorderheader.workorder_id
	Join TSDFApproval on TSDFApproval.tsdf_approval_id = wod.tsdf_approval_id
	join BillUnit on TSDFApproval.manifest_wt_vol_unit = BillUnit.manifest_unit
	Join TSDF on tsdf.tsdf_code = wod.tsdf_code
	Where wod.resource_type = 'D'
	and workorderheader.trip_id = @trip_id
	and IsNull(tsdf.eq_flag,'F') = 'F'
						
					

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_trip_update_units] TO [EQAI]
    AS [dbo];

