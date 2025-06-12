
create procedure sp_set_trip_price
	@trip_id int,
	@user_id varchar(10)
as

declare @workorder_id int,
		@company_id int,
		@profit_ctr_id int

set nocount on

declare c_loop cursor read_only forward_only for
select workorder_id, company_id, profit_ctr_id
from WorkOrderHeader
where trip_id = @trip_id
and workorder_status <> 'V'

open c_loop
fetch c_loop into @workorder_id, @company_id, @profit_ctr_id

while @@FETCH_STATUS = 0
begin
	exec sp_set_workorder_price @workorder_id, @company_id, @profit_ctr_id, @user_id

	fetch c_loop into @workorder_id, @company_id, @profit_ctr_id
end

close c_loop
deallocate c_loop

set nocount off

return 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_set_trip_price] TO [EQAI]
    AS [dbo];

