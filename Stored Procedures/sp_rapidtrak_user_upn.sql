if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_user_upn')
	drop procedure sp_rapidtrak_user_upn
go

create procedure sp_rapidtrak_user_upn
	@user_id	varchar(100)
as
declare @upn varchar(100)
--
--exec sp_rapidtrak_user_upn 'rob.briggs'
--exec sp_rapidtrak_user_upn 'ROB_B'
--select email, upn, * from Users where user_code = 'ROB_B'
--select * from Users where email like 'rob.briggs' + '@%'
/*
select email, user_code, group_id
from Users
where email in (
select distinct email from Users where len(email) > 0 and group_id <> 0 group by email having count(*) > 1
)
order by email, user_code
*/

select @upn = UPN
from Users
where user_code = @user_id

if @upn is null
	select @upn = UPN
	from Users
	where email like @user_id + '@%'
	and group_id > 0

select @upn as UPN
go

grant execute on sp_rapidtrak_user_upn to eqai, TRIPSERV
go
