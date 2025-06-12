if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_current_staging_row')
	drop procedure dbo.sp_rapidtrak_get_current_staging_row
go

create procedure dbo.sp_rapidtrak_get_current_staging_row
	@container varchar(20)
as
--
--Receipt:			exec sp_rapidtrak_get_current_staging_row '1406-65332-1-1'
--Stock Container:	exec sp_rapidtrak_get_current_staging_row 'DL-2200-057641'
--
declare @company_id int,
	@profit_ctr_id int,
	@container_type char,
	@receipt_id int,
	@line_id int,
	@container_id int,
	@type char,
	@staging_row varchar(5),
	@pos int,
	@pos2 int

set transaction isolation level read uncommitted

set @staging_row = null

if substring(@container,1,2) = 'P-'
	set @staging_row = ''
else
	exec dbo.sp_rapidtrak_parse_container @container, @type out, @company_id out, @profit_ctr_id out, @receipt_id out, @line_id out, @container_id out

if @staging_row is null

	SELECT @staging_row = staging_row
	FROM Container
	WHERE company_id = @company_id
	AND profit_ctr_id = @profit_ctr_id
	AND receipt_id = @receipt_id
	AND line_id = @line_id
	AND container_id = @container_id
	AND Container.container_type = @type


select @staging_row as current_staging_row
return 0
go

grant execute on dbo.sp_rapidtrak_get_current_staging_row to EQAI
go
