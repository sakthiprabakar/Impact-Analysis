if exists (select 1 from sysobjects where type = 'P' and name = 'sp_rapidtrak_get_treatment')
	drop procedure sp_rapidtrak_get_treatment
go

create procedure sp_rapidtrak_get_treatment
	@co_pc			varchar(4),
	@location		varchar(15),
	@batch_tracking_num	varchar(15)
as
--
--exec sp_rapidtrak_get_treatment '2100', 'OB', '03072005MDI'
--

declare @company_id int,
	@profit_ctr_id int

set @company_id = convert(int,left(@co_pc,2))
set @profit_ctr_id = convert(int,right(@co_pc,2))

SELECT DISTINCT bt.treatment_id, t.treatment_desc
FROM BatchTreatment bt
JOIN Treatment t
	on t.treatment_id = bt.treatment_id
WHERE bt.profit_ctr_id = @profit_ctr_id
AND bt.location = @location
AND bt.tracking_num = @batch_tracking_num
AND bt.company_id = @company_id
go

grant execute on sp_rapidtrak_get_treatment to eqai
go
