-- drop proc sp_ContactCORStats_Maintain

go

create proc sp_ContactCORStats_Maintain (
	@days_back	int = 1095 /* 365 X 3    On 3/10/20, this took 7m to run */
)
as
begin
/* *******************************************************
sp_ContactCORStats_Maintain

Creates a stats table that powers several other dashboard procedures

******************************************************* */

exec sp_ContactCORStatsGeneratorTotal_Maintain
exec sp_ContactCORStatsDispositionTotal_Maintain
exec sp_ContactCORStatsReceiptTons_Maintain
exec sp_ContactCorStatsOnTimeService_Maintain


return 0

end

go

grant execute on sp_ContactCORStats_Maintain to eqweb
go
grant execute on sp_ContactCORStats_Maintain to eqai
go
grant execute on sp_ContactCORStats_Maintain to cor_user
go
