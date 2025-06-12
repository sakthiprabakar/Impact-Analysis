if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_container_consolidations')
	drop procedure sp_rapidtrak_get_container_consolidations
go

create procedure sp_rapidtrak_get_container_consolidations
	@container varchar(20),
	@sequence_id int
as
/*

Receipt:
exec sp_rapidtrak_get_container_consolidations '1406-65332-1-1', 1

Stock container:
exec sp_rapidtrak_get_container_consolidations 'DL-2200-057641', 1

*/

declare
	@type char,
	@company_id int,
	@profit_ctr_id int,
	@receipt_id int,
	@line_id int,
	@container_id int,
	@co_pc varchar(4)

exec dbo.sp_rapidtrak_parse_container @container, @type out, @company_id out, @profit_ctr_id out, @receipt_id out, @line_id out, @container_id out

set @co_pc = right('0' + convert(varchar(2),@company_id),2) + right('0' + convert(varchar(2),@profit_ctr_id),2)

set transaction isolation level read uncommitted

SELECT case when source_receipt_id = 0 then 'DL' else @co_pc end + '-' +
		case when source_receipt_id = 0 then @co_pc else convert(varchar(10),source_receipt_id) end + '-' +
		case when source_receipt_id = 0 then right('00000' + convert(varchar(10),source_container_id),6) else convert(varchar(10),source_line_id) + '-' end +
		case when source_receipt_id = 0 then '' else convert(varchar(10),source_container_id) end consolidated_container
FROM ContainerWasteCode  
WHERE company_id = @company_id 
AND	profit_ctr_id = @profit_ctr_id
AND receipt_id = @receipt_id
AND line_id = @line_id
AND container_id = @container_id
AND container_type = @type
UNION   
SELECT case when source_receipt_id = 0 then 'DL' else @co_pc end + '-' +
		case when source_receipt_id = 0 then @co_pc else convert(varchar(10),source_receipt_id) end + '-' +
		case when source_receipt_id = 0 then right('00000' + convert(varchar(10),source_container_id),6) else convert(varchar(10),source_line_id) + '-' end +
		case when source_receipt_id = 0 then '' else convert(varchar(10),source_container_id) end consolidated_container
FROM ContainerConstituent  
WHERE company_id = @company_id 
AND	profit_ctr_id = @profit_ctr_id
AND receipt_id = @receipt_id
AND line_id = @line_id
AND container_id = @container_id
AND container_type = @type

return 0
go

grant execute on sp_rapidtrak_get_container_consolidations to EQAI
go
