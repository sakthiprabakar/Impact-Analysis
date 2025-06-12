if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_batch')
	drop procedure sp_rapidtrak_get_batch
go

create procedure sp_rapidtrak_get_batch
	@co_pc		varchar(4),
	@location	varchar(15)
as
--
--exec sp_rapidtrak_get_batch '2100', 'OB'
--

declare @company_id int,
	@profit_ctr_id int

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

SELECT tracking_num,   
       cycle  
FROM Batch  
WHERE company_id = @company_id
AND profit_ctr_id = @profit_ctr_id
AND location = @location
AND status = 'O'
go

grant execute on sp_rapidtrak_get_batch to eqai
go
