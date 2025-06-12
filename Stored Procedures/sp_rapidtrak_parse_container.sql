if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_parse_container')
	drop procedure sp_rapidtrak_parse_container
go

create procedure sp_rapidtrak_parse_container
	@container varchar(20),
	@type char(1) out,
	@company_id int out,
	@profit_ctr_id int out,
	@receipt_id int out,
	@line_id int out,
	@container_id int out
as
/*

Receipt:
declare @company_id int, @profit_ctr_id int, @type char(1), @receipt_id int, @line_id int, @container_id int
exec sp_rapidtrak_parse_container '2100-2154489-1-1', @type out, @company_id out, @profit_ctr_id out, @receipt_id out, @line_id out, @container_id out
select @type type, @company_id company_id, @profit_ctr_id profit_ctr_id, @receipt_id receipt_id, @line_id line_id, @container_id container_id

Stock container:
declare @company_id int, @profit_ctr_id int, @type char(1), @receipt_id int, @line_id int, @container_id int
exec sp_rapidtrak_parse_container 'DL-2200-057641', @type out, @company_id out, @profit_ctr_id out, @receipt_id out, @line_id out, @container_id out
select @type type, @company_id company_id, @profit_ctr_id profit_ctr_id, @receipt_id receipt_id, @line_id line_id, @container_id container_id

Error:
declare @company_id int, @profit_ctr_id int, @type char(1), @receipt_id int, @line_id int, @container_id int
exec sp_rapidtrak_parse_container 'P-2200', @type out, @company_id out, @profit_ctr_id out, @receipt_id out, @line_id out, @container_id out
*/

declare @pos int,
		@pos2 int,
		@msg varchar(255)


if substring(@container,1,3) = 'DL-' 
begin
	set @type = 'S'
	set @company_id = convert(int, substring(@container, 4, 2))
	set @profit_ctr_id = convert(int, substring(@container, 6, 2))
	set @receipt_id = 0
	set @line_id = convert(int, substring(@container, 9, 6))
	set @container_id = @line_id
end
else if isnumeric(substring(@container,1,4)) > 0 and substring(@container,5,1) = '-'
begin
	set @type = 'R'
	set @company_id = convert(int, substring(@container, 1, 2))
	set @profit_ctr_id = convert(int, substring(@container, 3, 2))

	set @pos = charindex('-', @container, 6)
	if @pos < 1
	begin
		set @msg = 'Container ''' + isnull(@container,'') + ''' is not a valid container'
		raiserror(@msg,16,1)
		return -1
	end

	set @receipt_id = convert(int, substring(@container, 6, @pos - 6))
	
	set @pos2 = charindex('-', @container, @pos + 1)
	if @pos2 < 1
	begin
		set @msg = 'Container ''' + isnull(@container,'') + ''' is not a valid container'
		raiserror(@msg,16,1)
		return -1
	end

	set @line_id = convert(int, substring(@container, @pos + 1, @pos2 - @pos - 1))
	set @container_id = convert(int, substring(@container, @pos2 + 1, len(@container)-@pos2))
end
else
begin
	set @msg = 'Container ''' + isnull(@container,'') + ''' is not a valid container'
	raiserror(@msg,16,1)
	return -1
end

return 0
go

grant execute on sp_rapidtrak_parse_container to EQAI
go
