if exists (select 1 from sysobjects where type = 'P' and name = 'sp_set_workorder_price')
	drop procedure [dbo].[sp_set_workorder_price]
go

create procedure [dbo].[sp_set_workorder_price]
	@workorder_id int,
	@company_id int,
	@profit_ctr_id int,
	@user_id varchar(10)
as

declare @workorder_status char(1),
		@fixed_price_flag char(1)

set nocount on

select @workorder_status = isnull(workorder_status,''),
		@fixed_price_flag = isnull(fixed_price_flag,'F')
from WorkOrderHeader
where workorder_ID = @workorder_id
and company_id = @company_id
and profit_ctr_ID = @profit_ctr_id

if @workorder_status = 'V' or @fixed_price_flag = 'T'
	return 0

update WorkOrderDetail
set extended_price = round(isnull(quantity_used,0) * isnull(price,0),2)
where workorder_ID = @workorder_id
and company_id = @company_id
and profit_ctr_ID = @profit_ctr_id
and resource_type <> 'O'
and bill_rate > 0
and priced_flag <> 1

update WorkOrderHeader
set total_price = (select sum(isnull(extended_price,0)) from WorkOrderDetail
					where workorder_ID = @workorder_ID
					and company_id = @company_id
					and profit_ctr_ID = @profit_ctr_ID
					and bill_rate > 0),
	modified_by = @user_id,
	date_modified = getdate()
where workorder_ID = @workorder_id
and company_id = @company_id
and profit_ctr_ID = @profit_ctr_id
and coalesce(total_price,0) <> coalesce((select sum(isnull(extended_price,0)) from WorkOrderDetail
								where workorder_ID = @workorder_ID
								and company_id = @company_id
								and profit_ctr_ID = @profit_ctr_ID
								and bill_rate > 0),0)

set nocount off

return 0
GO

grant execute on [dbo].[sp_set_workorder_price] to EQAI
go
