
create procedure dbo.AUDIT_prc_ReportingAddFilterValue
@index nvarchar(100),
@value nvarchar(4000)
as
begin
if not exists (select [value] from ##Filter where [index]=@index and [value] like Replace(@value collate database_default, '[', '[[]'))
	insert into ##Filter([index], [value]) values(@index, @value)
end
