/***********************************************************************
Bulk or Non-Bulk Daily Schedule (from Schedule screen)

Filename:	F:\EQAI\SQL\EQAI\sp_schedule_detail.sql
PB Object(s):	d_rpt_schedule_daily_detail
		d_rpt_schedule_daily_lab_detail

02/10/2004 SCC	Created
10/04/2004 JDB	Replaced "DRUM" with "DM55" as a result of bill unit conversion.
11/11/2004 MK  Changed generator_code to generator_id
08/02/2006 SCC	Modified to use Profile tables
11/04/2006 SCC  Removed material_type column reference
11/23/2012 DZ   Added company_id, moved from plt_xx_ai to plt_ai
09/19/2018 MPM	Added field for sampling frequency tracking for bulk waste shipments to result set.

sp_schedule_detail 0, 8, 2, 2006, 21, 0, 'B', 0, 'SHEILA_C'
***********************************************************************/
CREATE PROCEDURE sp_schedule_detail
	@debug int,
	@month int, 
	@day int, 
	@year int,
	@company_id int,
	@profit_ctr_id int, 
	@load_type char(1),
	@print_various int,
	@user_code varchar(50)
AS 

DECLARE @bulk_load_sampling_frequency_required_flag char(1)

-- Get the info where there is a specific approval code
SELECT DISTINCT 
Schedule.confirmation_ID,
Schedule.profit_ctr_ID, 
Schedule.time_scheduled,   
Schedule.material,   
Schedule.quantity,   
Schedule.sched_quantity,
billUnit.gal_conv
INTO #tmp
FROM Schedule
	JOIN ProfitCenter ON Schedule.profit_ctr_id = ProfitCenter.profit_ctr_id
		AND Schedule.company_id = ProfitCenter.company_id
	JOIN ProfileQuoteApproval ON (Schedule.approval_code = ProfileQuoteApproval.approval_code )
		AND ( Schedule.company_id = ProfileQuoteApproval.company_id  )
		AND ( Schedule.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id  )
	JOIN Profile ON (ProfileQuoteApproval.profile_id = Profile.profile_id)
		AND ( Profile.curr_status_code = 'A' )
	JOIN Generator ON ( Profile.generator_id = Generator.generator_id )
	JOIN Customer ON ( Profile.customer_id = Customer.customer_id )
	JOIN Treatment ON (ProfileQuoteApproval.treatment_id = Treatment.treatment_id )
		AND ( ProfileQuoteApproval.company_id = Treatment.company_id )
		AND ( ProfileQuoteApproval.profit_ctr_id = Treatment.profit_ctr_id )
	LEFT OUTER JOIN BillUnit ON ( Schedule.bill_unit_code = billunit.bill_unit_code)
WHERE
( datepart(mm, Schedule.time_scheduled) = @month ) and
( datepart(dd, Schedule.time_scheduled) = @day ) and
( datepart(yy, Schedule.time_scheduled) = @year) and
( Schedule.load_type = @load_type ) AND 
( Schedule.company_id = @company_id ) AND
( Schedule.profit_ctr_id = @profit_ctr_id ) AND 
( Schedule.end_block_time IS NULL ) and Schedule.status in ('A','P') and
Schedule.material in (SELECT material from ScheduleReport where user_code = @user_code) 

if @debug = 1 print 'Selecting from #tmp'
if @debug = 1 select * from #tmp

-- Store the specified quantities for the VARIOUS approvals
SELECT DISTINCT 
Schedule.confirmation_ID,   
Schedule.profit_ctr_ID,   
Schedule.time_scheduled,   
Schedule.material,   
ScheduleApproval.bill_unit_code, 
SUM(ScheduleApproval.quantity) as quantity,
SUM(ScheduleApproval.sched_quantity) as sched_quantity,
billUnit.gal_conv
INTO #various
FROM Schedule
	JOIN ProfitCenter ON Schedule.profit_ctr_id = ProfitCenter.profit_ctr_id
		AND Schedule.company_id = ProfitCenter.company_id
	JOIN ScheduleApproval ON (Schedule.confirmation_id = ScheduleApproval.confirmation_id)
		AND Schedule.company_id = ScheduleApproval.company_id
		AND Schedule.profit_ctr_id = ScheduleApproval.profit_ctr_id
	JOIN ProfileQuoteApproval ON (ScheduleApproval.approval_code = ProfileQuoteApproval.approval_code )  
		AND ( ScheduleApproval.company_id = ProfileQuoteApproval.company_id  )  
		AND ( ScheduleApproval.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id  )
	JOIN Profile ON (ProfileQuoteApproval.profile_id = Profile.profile_id)
		AND ( Profile.curr_status_code = 'A' )
	LEFT OUTER JOIN BillUnit ON ( Schedule.bill_unit_code = billunit.bill_unit_code)
WHERE ( Schedule.approval_code = 'VARIOUS' )  
AND ( datepart(mm, Schedule.time_scheduled) = @month ) 
AND ( datepart(dd, Schedule.time_scheduled) = @day ) 
AND ( datepart(yy, Schedule.time_scheduled) = @year) 
AND ( Schedule.load_type = @load_type )  
AND ( Schedule.company_id = @company_id )
AND ( Schedule.profit_ctr_id = @profit_ctr_id )  
AND ( Schedule.end_block_time IS NULL ) 
AND Schedule.status in ('A','P') 
AND Schedule.material in (SELECT material from ScheduleReport where user_code = @user_code) 
GROUP BY
Schedule.confirmation_ID,   
Schedule.profit_ctr_ID,   
Schedule.time_scheduled,   
Schedule.material,   
ScheduleApproval.bill_unit_code, 
BillUnit.gal_conv

if @debug = 1 print 'Selecting from #various'
if @debug = 1 select * from #various

-- Store the non-specified quantity for VARIOUS approvals as DM55s
SELECT DISTINCT Schedule.confirmation_ID,   
Schedule.profit_ctr_id,   
Schedule.time_scheduled,   
Schedule.material,   
Schedule.quantity,   
Schedule.sched_quantity,   
'DM55' as bill_unit_code,   
55 as gal_conv
INTO #various_drum
FROM Schedule
	JOIN ProfitCenter ON Schedule.profit_ctr_id = ProfitCenter.profit_ctr_id
		AND Schedule.company_id = ProfitCenter.company_id
WHERE ( Schedule.approval_code = 'VARIOUS' )  
AND ( datepart(mm, Schedule.time_scheduled) = @month ) 
AND ( datepart(dd, Schedule.time_scheduled) = @day ) 
AND ( datepart(yy, Schedule.time_scheduled) = @year) 
AND ( Schedule.load_type = @load_type )  
AND ( Schedule.company_id = @company_id )
AND ( Schedule.profit_ctr_id = @profit_ctr_id )  
AND ( Schedule.end_block_time IS NULL ) 
AND Schedule.status in ('A','P') 
AND Schedule.material in (SELECT material from ScheduleReport where user_code = @user_code) 


if @debug = 1 print 'Selecting from #various_drum'
if @debug = 1 select * from #various_drum

-- Subtract the quantity of specified containers from the default quantity of non-specified containers
UPDATE #various_drum SET 
quantity = quantity - 
IsNull((select SUM(#various.quantity)
FROM #various
WHERE #various_drum.confirmation_id = #various.confirmation_id
GROUP BY
#various.confirmation_id), 0),
sched_quantity = sched_quantity - 
IsNull((select SUM(#various.sched_quantity)
FROM #various
WHERE #various_drum.confirmation_id = #various.confirmation_id
GROUP BY
#various.confirmation_id), 0)

if @debug = 1 print 'Selecting from #various_drum'
if @debug = 1 select * from #various_drum

-- Combine the like containers for the same confirmation ID
UPDATE #various SET
#various.quantity = #various.quantity + #various_drum.quantity,
#various.sched_quantity = #various.sched_quantity + #various_drum.sched_quantity
FROM #various_drum
WHERE #various.confirmation_id = #various_drum.confirmation_ID
AND #various.bill_unit_code = #various_drum.bill_unit_code

-- Remove the combined quantity records to report the non-specified drums
DELETE FROM #various_drum
FROM #various
WHERE #various.confirmation_id = #various_drum.confirmation_ID
AND #various.bill_unit_code = #various_drum.bill_unit_code

-- Return the results
SELECT confirmation_ID, profit_ctr_ID, time_scheduled, material, quantity, sched_quantity, 
(IsNull(quantity, 0) * IsNull(gal_conv, 1)) as quantity_gallons
INTO #tmp_results
FROM #tmp
UNION ALL
SELECT confirmation_ID, profit_ctr_ID, time_scheduled, material, quantity, sched_quantity, 
(IsNull(quantity, 0) * IsNull(gal_conv, 1)) as quantity_gallons
FROM #various
UNION ALL
SELECT confirmation_ID, profit_ctr_ID, time_scheduled, material, quantity, sched_quantity, 
(IsNull(quantity, 0) * IsNull(gal_conv, 1)) as quantity_gallons
FROM #various_drum

-- Get bulk_load_sampling_frequency_required_flag for the profit center and return with the result set
SELECT @bulk_load_sampling_frequency_required_flag = IsNull(bulk_load_sampling_frequency_required_flag, 'F')
FROM ProfitCenter
WHERE company_ID = @company_id
AND profit_ctr_ID = @profit_ctr_id

SELECT confirmation_ID, profit_ctr_ID, time_scheduled, material,  
SUM(quantity) as quantity, 
SUM(sched_quantity) as sched_quantity, 
SUM(quantity_gallons) as quantity_gallons,
@bulk_load_sampling_frequency_required_flag
FROM #tmp_results
GROUP BY confirmation_ID, profit_ctr_ID, time_scheduled, material 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_schedule_detail] TO [EQAI]
    AS [dbo];

