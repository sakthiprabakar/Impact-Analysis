-- drop proc sp_cor_check_webuserid_available
go
create proc sp_cor_check_webuserid_available (
	@requested_web_userid	varchar(100)
)
as
/*
sp_cor_check_webuserid_available

Returns T or F depending on if the input @requested_web_userid is available

Available means does not already exist as a web_userid or users.user_code.

sp_cor_check_webuserid_available 'nyswyn100' -- Should return false (F)
sp_cor_check_webuserid_available 'zachery.wright' -- Should return false (F)

declare @t varchar(40) = convert(varchar(40), getdate(), 121)
select @t
exec sp_cor_check_webuserid_available @t -- Should return true (T)

*/

select
	case when exists (
	select top 1 1 from CORcontact WHERE web_userid = @requested_web_userid
	union
	select top 1 1 from users WHERE user_code = @requested_web_userid
)
then 'F' else 'T' end as web_userid_available_to_use

RETURN 0

go

grant execute on sp_cor_check_webuserid_available to eqai, eqweb, cor_user
go

-- change melissay cor username