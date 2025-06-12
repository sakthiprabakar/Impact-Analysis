if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_container_constituents')
	drop procedure sp_rapidtrak_get_container_constituents
go

create procedure sp_rapidtrak_get_container_constituents
	@container varchar(20),
	@sequence_id int
as
/*

Receipt:
exec sp_rapidtrak_get_container_constituents '1406-65332-1-1', 1

Stock container:
exec sp_rapidtrak_get_container_constituents 'DL-2200-057641', 1

*/

declare
	@type char,
	@company_id int,
	@profit_ctr_id int,
	@receipt_id int,
	@line_id int,
	@container_id int

exec dbo.sp_rapidtrak_parse_container @container, @type out, @company_id out, @profit_ctr_id out, @receipt_id out, @line_id out, @container_id out

set transaction isolation level read uncommitted

select cwc.const_id, cwc.UHC, c.const_desc
from ContainerConstituent cwc
join Constituents c
	on cwc.const_id = c.const_id
where cwc.company_id = @company_id
and cwc.profit_ctr_id = @profit_ctr_id
and cwc.receipt_id = @receipt_id
and cwc.line_id = @line_id
and cwc.container_id = @container_id
and cwc.sequence_id = @sequence_id
and cwc.container_type = @type
union
select rwc.const_id, rwc.UHC, c.const_desc
from ReceiptConstituent rwc
join Constituents c
	on rwc.const_id = c.const_id
where rwc.company_id = @company_id
and rwc.profit_ctr_id = @profit_ctr_id
and rwc.receipt_id = @receipt_id
and rwc.line_id = @line_id
and not exists (select 1 from ContainerConstituent
				where company_id = rwc.company_id
				and profit_ctr_id = rwc.profit_ctr_id
				and receipt_id = rwc.receipt_id
				and line_id = rwc.line_id
				and container_id = @container_id
				and sequence_id = @sequence_id
				and container_type = @type)

return 0
go

grant execute on sp_rapidtrak_get_container_constituents to EQAI
go
