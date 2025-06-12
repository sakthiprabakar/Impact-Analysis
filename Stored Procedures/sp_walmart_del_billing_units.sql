
create procedure sp_walmart_del_billing_units
	@workorder_id int,
	@company_id int,
	@profit_ctr_id int
as
/***
 * 01/10/2012 Created by rb, to delete (with audit) billing units for specific walmart approvals
 *
 * Change log:
 * -----------
 * 01/18/2012 rb Some trips weren't being processed, customer_type='WALMARTDC' should be included
 *
 ***/

declare @status char(1),
		@submitted char(1)

-- ignore if not a Walmart customer
if not exists (select 1
				from Customer c
				join WorkorderHeader wh
					on wh.workorder_ID = @workorder_id
					and wh.company_id = @company_id
					and wh.profit_ctr_ID = @profit_ctr_id
					and wh.customer_ID = c.customer_id
				where customer_type in ('WALMART','WALMARTDC'))
	return 0

set nocount on

-- check status, submitted - don't process void or submitted workorders
select @status = ISNULL(workorder_status,'N'),
		@submitted = ISNULL(submitted_flag,'F')
from WorkorderHeader
where workorder_id = @workorder_id
and company_id = @company_id
and profit_ctr_ID = @profit_ctr_id

if @status = 'V' or @submitted = 'T'
	return 0

-- generate audit records for deleted bill units
insert WorkorderAudit
select wodu.company_id, wodu.profit_ctr_id, wodu.workorder_id, wod.resource_type, wodu.sequence_id,
		'WorkOrderDetailUnit', 'bill_unit_code', wodu.size, '(deleted)',
		'Deleted for WalMart, quantity was: ' + isnull(CONVERT(varchar(20),wodu.quantity),'null'),
		'SA', GETDATE()
from WorkOrderDetailUnit wodu
join WorkorderDetail wod
	on wodu.workorder_id = wod.workorder_id
	and wodu.company_id = wod.company_id
	and wodu.profit_ctr_id = wod.profit_ctr_id
	and wodu.sequence_id = wod.sequence_id
	and wod.resource_type = 'D'
join WalmartPricingConversionApprovals a
	on wod.TSDF_approval_code = a.approval_code
where wodu.workorder_id = @workorder_id
and wodu.company_id = @company_id
and wodu.profit_ctr_id = @profit_ctr_id
and ISNULL(wodu.billing_flag,'F') = 'T'
and ISNULL(wodu.manifest_flag,'F') = 'F'
and wodu.size <> 'LBS'

-- generate audit records for updated pound units
insert WorkorderAudit
select wodu.company_id, wodu.profit_ctr_id, wodu.workorder_id, wod.resource_type, wodu.sequence_id,
		'WorkOrderDetailUnit', 'billing_flag', 'F', 'T',
		'LBS updated to T for WalMart pricing change to pounds',
		'SA', GETDATE()
from WorkOrderDetailUnit wodu
join WorkorderDetail wod
	on wodu.workorder_id = wod.workorder_id
	and wodu.company_id = wod.company_id
	and wodu.profit_ctr_id = wod.profit_ctr_id
	and wodu.sequence_id = wod.sequence_id
	and wod.resource_type = 'D'
join WalmartPricingConversionApprovals a
	on wod.TSDF_approval_code = a.approval_code
where wodu.workorder_id = @workorder_id
and wodu.company_id = @company_id
and wodu.profit_ctr_id = @profit_ctr_id
and ISNULL(wodu.billing_flag,'F') = 'F'
and wodu.size = 'LBS'

-- delete billing units
delete WorkOrderDetailUnit
from WorkOrderDetailUnit wodu
join WorkorderDetail wod
	on wodu.workorder_id = wod.workorder_id
	and wodu.company_id = wod.company_id
	and wodu.profit_ctr_id = wod.profit_ctr_id
	and wodu.sequence_id = wod.sequence_id
	and wod.resource_type = 'D'
join WalmartPricingConversionApprovals a
	on wod.TSDF_approval_code = a.approval_code
where wodu.workorder_id = @workorder_id
and wodu.company_id = @company_id
and wodu.profit_ctr_id = @profit_ctr_id
and ISNULL(wodu.billing_flag,'F') = 'T'
and ISNULL(wodu.manifest_flag,'F') = 'F'
and wodu.size <> 'LBS'

-- update pounds billing_unit
update WorkOrderDetailUnit set billing_flag = 'T'
from WorkOrderDetailUnit wodu
join WorkorderDetail wod
	on wodu.workorder_id = wod.workorder_id
	and wodu.company_id = wod.company_id
	and wodu.profit_ctr_id = wod.profit_ctr_id
	and wodu.sequence_id = wod.sequence_id
	and wod.resource_type = 'D'
join WalmartPricingConversionApprovals a
	on wod.TSDF_approval_code = a.approval_code
where wodu.workorder_id = @workorder_id
and wodu.company_id = @company_id
and wodu.profit_ctr_id = @profit_ctr_id
and ISNULL(wodu.billing_flag,'F') = 'F'
and wodu.size = 'LBS'

set nocount off

return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_walmart_del_billing_units] TO [EQAI]
    AS [dbo];

