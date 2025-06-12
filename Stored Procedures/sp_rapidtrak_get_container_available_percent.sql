if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_container_available_percent')
	drop procedure sp_rapidtrak_get_container_available_percent
go

create procedure sp_rapidtrak_get_container_available_percent
	@container varchar(20)
as
--select max(receipt_id) from ContainerDestination where container_percent = 100 and container_type = 'R' and status = 'N' and company_id = 21 and profit_ctr_id = 0
--exec sp_rapidtrak_get_container_available_percent '2100-2153876-1-1'
--
declare
	@type char,
	@company_id int,
	@profit_ctr_id int,
	@receipt_id int,
	@line_id int,
	@container_id int,
	@available_percent int

exec dbo.sp_rapidtrak_parse_container @container, @type out, @company_id out, @profit_ctr_id out, @receipt_id out, @line_id out, @container_id out

set transaction isolation level read uncommitted

select @available_percent = sum(cd.container_percent)
from ContainerDestination cd
join Container c
	on c.company_id = cd.company_id
	and	c.profit_ctr_id = cd.profit_ctr_id
	and	c.container_type = cd.container_type 
	and	c.receipt_id = cd.receipt_id 
	and	c.line_id = cd.line_id
	and	c.container_id = cd.container_id  
	and	c.container_type = cd.container_type
	and c.status not in ('C','V')
where cd.company_id = @company_id
and cd.profit_ctr_id = @profit_ctr_id  
and cd.receipt_id = @receipt_id
and cd.line_id = @line_id
and cd.container_id = @container_id
and cd.container_type = @type
and cd.status <> 'C'

select coalesce(@available_percent,0) as available_percent
return 0
go

grant execute on sp_rapidtrak_get_container_available_percent to EQAI, TRIPSERV
go
