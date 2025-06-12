DROP PROCEDURE IF EXISTS sp_rpt_daily_injection
GO

CREATE PROCEDURE sp_rpt_daily_injection
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@location           varchar(15)
AS
/***************************************************************************************
PB Object: r_daily_injection_detail, r_daily_injection_summary

03/08/2022 MPM  DevOps 20904 - Initial version.

12/02/2022 Dipankar DevOps #57420/ #57422
           Modified Where Clause for Location Criteria to use BatchEventInjection.destination_batch_location
		   instead of BatchEvent.dest_location.
12/07/2022 Dipankar DevOps #57420/ #57422
           Added join condition BatchEvent.dest_location = BatchEventInjection.destination_batch_location
		   for query to give unique records
sp_rpt_daily_injection 55, 0, '1/1/2021','12/31/2021', 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT BatchEvent.company_id,  
       BatchEvent.profit_ctr_id,   
       BatchEvent.location,   
       BatchEvent.dest_location, 
       BatchEvent.tracking_num,   
       BatchEvent.dest_tracking_num,   
       BatchEvent.cycle,   
       BatchEvent.event_type,   
       BatchEvent.dest_cycle,   
       BatchEvent.quantity,   
       BatchEvent.unit,   
       BatchEvent.event_date,   
       BatchEvent.status,   
       BatchEvent.batch_id,   
       BatchEvent.disposal_date,   
       BatchEvent.disposal_vol,   
       BatchEvent.disposal_vol_bill_unit_code,   
       BatchEvent.injection_date, 
       CASE WHEN LEN(BatchEventInjection.injection_time_start) = 4 THEN CAST(LEFT(BatchEventInjection.injection_time_start, 2) + ':' + RIGHT(BatchEventInjection.injection_time_start, 2) AS TIME) ELSE NULL END AS injection_time_start, 
       CASE WHEN LEN(BatchEventInjection.injection_time_stop) = 4 THEN CAST(LEFT(BatchEventInjection.injection_time_stop, 2) + ':' + RIGHT(BatchEventInjection.injection_time_stop, 2) AS TIME) ELSE NULL END AS injection_time_stop, 
       BatchEvent.specific_gravity, 
       BatchEventInjection.ph, 
       ProcessLocation.final_destination_flag,
       ProcessLocation.deep_well_flag,
       BatchEventInjection.destination_batch_location, 
       BatchEventInjection.destination_batch_tracking_num, 
       BatchEventInjection.source_batch_injected_pct/100.0 as source_batch_injected_pct, 
       BatchEventInjection.gallons_injected, 
       BatchEventInjection.gallons_per_minute_max, 
       BatchEventInjection.gallons_per_minute_avg, 
       BatchEventInjection.annulus_pressure, 
       BatchEventInjection.differential_pressure, 
       BatchEventInjection.injection_pressure_avg, 
       BatchEventInjection.injection_pressure_max, 
	   BatchEventInjection.comment,
	   BatchDailyDeepWell.date_of_injection,
       BatchDailyDeepWell.total_hours_of_injection, 
       BatchDailyDeepWell.minimum_annulus_pressure, 
       BatchDailyDeepWell.minimum_differential_pressure, 
       Company.company_name,
       ProfitCenter.profit_ctr_name 
FROM BatchEvent 
JOIN Company
    ON BatchEvent.company_id = Company.company_id
JOIN ProfitCenter
    ON BatchEvent.company_id = ProfitCenter.company_id 
    AND BatchEvent.profit_ctr_id = ProfitCenter.profit_ctr_id 
JOIN BatchEventInjection
    ON BatchEvent.company_id = BatchEventInjection.company_id 
    AND BatchEvent.profit_ctr_id = BatchEventInjection.profit_ctr_id
    AND BatchEvent.location = BatchEventInjection.location
	AND BatchEvent.dest_location = BatchEventInjection.destination_batch_location 
    AND BatchEvent.tracking_num = BatchEventInjection.tracking_num 
    AND BatchEvent.cycle = BatchEventInjection.cycle 
    AND BatchEvent.event_type = BatchEventInjection.event_type 
    AND BatchEventInjection.source_batch_injected_pct IS NOT NULL
    AND BatchEvent.quantity = BatchEventInjection.gallons_injected 
JOIN BatchDailyDeepWell
    ON BatchEventInjection.company_id = BatchDailyDeepWell.company_id
    AND BatchEventInjection.profit_ctr_id = BatchDailyDeepWell.profit_ctr_id 
    AND BatchEventInjection.destination_batch_location = BatchDailyDeepWell.location 
    AND BatchEventInjection.destination_batch_tracking_num = BatchDailyDeepWell.tracking_num 
JOIN ProcessLocation  
    ON BatchEventInjection.company_id = ProcessLocation.company_id 
    AND BatchEventInjection.profit_ctr_id = ProcessLocation.profit_ctr_id 
    AND BatchEventInjection.destination_batch_location = ProcessLocation.location 
    AND ProcessLocation.final_destination_flag = 'T' 
    AND ProcessLocation.deep_well_flag = 'T' 
 WHERE (BatchEventInjection.destination_batch_location = @location or 'ALL' = @location)
   AND BatchEvent.profit_ctr_id = @profit_ctr_id 
   AND BatchEvent.company_id = @company_id 
   AND BatchEvent.injection_date between @date_from and @date_to
   AND BatchEvent.event_type = 'T' 
   AND ProcessLocation.final_destination_flag = 'T' 
   AND ProcessLocation.deep_well_flag = 'T' 
   AND BatchEventInjection.source_batch_injected_pct IS NOT NULL 
   AND BatchEvent.injection_date = BatchDailyDeepWell.date_of_injection
   AND BatchEvent.quantity = BatchEventInjection.gallons_injected 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_daily_injection] TO [EQAI]
    AS [dbo];
