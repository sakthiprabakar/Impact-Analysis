use Plt_ai
go

----------

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_user_login')
	drop procedure sp_rapidtrak_user_login
go

create procedure sp_rapidtrak_user_login
	@UPN	varchar(100),
	@co_pc	varchar(4),
	@device_make varchar(80) = null,
	@device_model varchar(80) = null,
	@OS_version varchar(80) = null,
	@screen_dimensions varchar(80) = null,
	@login_success_flag char = null
as
--
--exec sp_rapidtrak_user_login 'Rob.Briggs@eqonline.com', '2100', 'Zebra', 'TC26AK', 'Android 10', '1280 x 720', 'T'
--exec sp_rapidtrak_user_login 'Rob.Briggs@eqonline.com', '9999', 'Zebra', 'TC26AK', 'Android 10', '1280 x 720', 'F'
--

declare @company_id 	int,
	@profit_ctr_id	int,
	@user_code varchar(10),
	@offline_flag char,
	@container_access char,
	@retail_access char,
	@timeout_in_minutes varchar(10),
	@status varchar(10),
	@msg varchar(255)

set @status = 'OK'
set @msg = 'The Location Code entered is valid.'

--Validate location code
set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

if not exists (select 1
				from ProfitCenter
				where profit_ctr_id = @profit_ctr_id
				and company_id = @company_id
				and status = 'A')
begin
	set @status = 'ERROR'
	set @msg = 'Error: The Location Code you entered is not valid. Please check your facility code and log in.'

	goto RETURN_RESULT
end


select @offline_flag = coalesce(l.offline_flag,'')
from LabPackUser l
join Users u
	on u.user_code = l.user_code
	and u.UPN = @UPN
where l.location_code = @co_pc

select @user_code = u.user_code,
	@container_access = a.container,
	@retail_access = a.retail_processing
from Access a
join Users u
	on u.group_id = a.group_id
	and u.UPN = @UPN
where a.company_id = convert(int,left(@co_pc,2))

select @timeout_in_minutes = config_value
from Configuration
where config_key = 'rapidtrak_timeout_minutes'

if not exists (select 1
		from OrderHeader oh
		join OrderDetail od
			on oh.order_id = od.order_id
			and od.company_id = @company_id
			and od.profit_ctr_id = @profit_ctr_id)
	set @retail_access = 'N'		

--insert login record
if @device_make is not null
	insert RapidTrakLogin (EQAI_user, location_code, device_make, device_model, OS_version, screen_dimensions, login_success_flag, login_date)
	values (@user_code, @co_pc, @device_make, @device_model, @OS_version, @screen_dimensions, @login_success_flag, getdate())


RETURN_RESULT:
select coalesce(@user_code,'') as user_code,
	coalesce(@offline_flag,'') as offline_flag,
	coalesce(@container_access,'') as container_access,
	coalesce(@retail_access,'') as retail_access,
	coalesce(@timeout_in_minutes,'') as timeout_in_minutes,
	@status as status,
	@msg as message
go

grant execute on sp_rapidtrak_user_login to eqai, TRIPSERV
go
