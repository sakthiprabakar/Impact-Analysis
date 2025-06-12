if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_container_sequence_id')
	drop procedure dbo.sp_rapidtrak_get_container_sequence_id
go

create procedure dbo.sp_rapidtrak_get_container_sequence_id
	@container varchar(20)
as
--
--Receipt:			exec sp_rapidtrak_get_container_sequence_id '1406-65332-1-1'
--Stock Container:	exec sp_rapidtrak_get_container_sequence_id 'DL-2200-057641'
--
declare @company_id int,
	@profit_ctr_id int,
	@container_type char,
	@receipt_id int,
	@line_id int,
	@container_id int,
	@sequence_id int,
	@pos int,
	@pos2 int

set transaction isolation level read uncommitted

if substring(@container,1,2) = 'P-'
	set @sequence_id = 1
else
	exec dbo.sp_rapidtrak_parse_container @container, @container_type out, @company_id out, @profit_ctr_id out, @receipt_id out, @line_id out, @container_id out

if coalesce(@sequence_id,0) = 0
	select @sequence_id = max(sequence_id)
	from ContainerDestination
	where company_id = @company_id
	and profit_ctr_id = @profit_ctr_id
	and container_type = @container_type
	and receipt_id = @receipt_id
	and line_id = @line_id
	and container_id = @container_id
	and status <> 'C'

if coalesce(@sequence_id,0) = 0
	set @sequence_id = 1

select convert(varchar(10),@sequence_id) as sequence_id
return 0
go

grant execute on dbo.sp_rapidtrak_get_container_sequence_id to EQAI
go
