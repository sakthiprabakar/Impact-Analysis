CREATE PROCEDURE sp_schedule_sum
	@debug int,
	@month int, 
	@day int, 
	@year int,
	@company_id int, 
	@profit_ctr_id int, 
	@load_type char(1),
	@user_code varchar(50)
AS 
/***********************************************************************
Bulk or Non-Bulk Daily Schedule (from Schedule screen)

Filename:	F:\EQAI\SQL\EQAI\sp_schedule_sum.sql
PB Object(s):	d_rpt_schedule_daily_sum

02/10/2004 SCC	Created
07/14/2004 SCC	Joined to Approval on profit ctr ID
10/04/2004 JDB	Replaced "DRUM" with "DM55" as a result of bill unit conversion.
11/11/2004 MK  Changed generator_code to generator_id
03/02/2005 SCC	Modified for bill unit in Schedule and Schedule Approval tables
08/02/2006 SCC	Modified to use Profile tables
11/04/2006 SCC  Removed material_type column reference
11/14/2006 SCC  Include bill unit breakdown of VARIOUS scheduled approvals
11/28/2012 DZ   Added company_id, moved from plt_xx_ai to plt_ai

sp_schedule_sum 1, 10, 20, 2006, 21, 0, 'N', 'SA'
***********************************************************************/

-- Get the info where there is a specific approval code
SELECT DISTINCT 
SUM(Schedule.quantity) AS quantity,   
Schedule.bill_unit_code,
BillUnit.gal_conv
INTO #tmp
FROM Schedule
	JOIN ProfileQuoteApproval ON (Schedule.approval_code = ProfileQuoteApproval.approval_code )
		AND ( Schedule.company_id = ProfileQuoteApproval.company_id  )
		AND ( Schedule.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id  )
	JOIN Profile ON (ProfileQuoteApproval.profile_id = Profile.profile_id)
		AND ( Profile.curr_status_code = 'A' )
	JOIN BillUnit ON ( Schedule.bill_unit_code = billunit.bill_unit_code)
WHERE ( datepart(mm, Schedule.time_scheduled) = @month ) and
( datepart(dd, Schedule.time_scheduled) = @day ) and
( datepart(yy, Schedule.time_scheduled) = @year) and
( Schedule.load_type = @load_type ) AND 
( Schedule.company_id = @company_id ) AND 
( Schedule.profit_ctr_id = @profit_ctr_id ) AND 
( Schedule.end_block_time IS NULL ) and Schedule.status in ('A','P') and
Schedule.material in (SELECT material from ScheduleReport where user_code = @user_code) 
GROUP BY 
Schedule.bill_unit_code,
BillUnit.gal_conv

if @debug = 1 print 'Selecting from #tmp'
if @debug = 1 select * from #tmp

-- Store the specified quantities for the VARIOUS approvals
SELECT DISTINCT 
SUM(ScheduleApproval.quantity) as quantity,
ScheduleApproval.bill_unit_code, 
billUnit.gal_conv
INTO #various
FROM Schedule
	JOIN ScheduleApproval ON (Schedule.confirmation_id = ScheduleApproval.confirmation_id)

		AND Schedule.company_id = ScheduleApproval.company_id
		AND Schedule.profit_ctr_id = ScheduleApproval.profit_ctr_id
	JOIN ProfileQuoteApproval ON (ScheduleApproval.approval_code = ProfileQuoteApproval.approval_code )  
		AND ( ScheduleApproval.company_id = ProfileQuoteApproval.company_id  )  
		AND ( ScheduleApproval.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id  )
	JOIN Profile ON (ProfileQuoteApproval.profile_id = Profile.profile_id)
		AND ( Profile.curr_status_code = 'A' )
	JOIN BillUnit ON ( ScheduleApproval.bill_unit_code = billunit.bill_unit_code)
WHERE ( Schedule.approval_code = 'VARIOUS' ) and 
( datepart(mm, Schedule.time_scheduled) = @month ) and
( datepart(dd, Schedule.time_scheduled) = @day ) and
( datepart(yy, Schedule.time_scheduled) = @year) and
( Schedule.load_type = @load_type ) AND 
( Schedule.company_id = @company_id ) AND 
( Schedule.profit_ctr_id = @profit_ctr_id ) AND 
( Schedule.end_block_time IS NULL ) and Schedule.status in ('A','P') 
AND Schedule.material in (SELECT material from ScheduleReport where user_code = @user_code) 
GROUP BY
ScheduleApproval.bill_unit_code, 
BillUnit.gal_conv

if @debug = 1 print 'Selecting from #various'
if @debug = 1 select * from #various

-- Store the non-specified quantity for VARIOUS approvals as DM55s
SELECT DISTINCT  
SUM(Schedule.quantity) AS quantity,   
BillUnit.bill_unit_code,   
BillUnit.gal_conv
INTO #various_drum
FROM Schedule
	JOIN BillUnit ON BillUnit.bill_unit_code = 'DM55'
WHERE ( Schedule.approval_code = 'VARIOUS' ) and 
( datepart(mm, Schedule.time_scheduled) = @month ) and
( datepart(dd, Schedule.time_scheduled) = @day ) and
( datepart(yy, Schedule.time_scheduled) = @year) and
( Schedule.load_type = @load_type ) AND 
( Schedule.company_id = @company_id ) AND 
( Schedule.profit_ctr_id = @profit_ctr_id ) AND 
( Schedule.end_block_time IS NULL ) and Schedule.status in ('A','P') 
AND Schedule.material in (SELECT material from ScheduleReport where user_code = @user_code) 
GROUP BY 
BillUnit.bill_unit_code,   
BillUnit.gal_conv

if @debug = 1 print 'Selecting from #various_drum'
if @debug = 1 select * from #various_drum

-- Subtract the quantity of specified containers from the default quantity of non-specified containers
UPDATE #various_drum SET 
quantity = quantity - 
IsNull((select SUM(#various.quantity)
FROM #various),0)

if @debug = 1 print 'Selecting from #various_drum'
if @debug = 1 select * from #various_drum

INSERT #tmp
SELECT * FROM #various
UNION ALL
SELECT * FROM #various_drum

-- Return the results
SELECT bill_unit_code, 
SUM(quantity) as quantity, 
(IsNull(SUM(quantity), 0) * IsNull(gal_conv, 1)) as quantity_gallons
FROM #tmp
GROUP BY bill_unit_code, gal_conv
ORDER BY bill_unit_code

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_schedule_sum] TO [EQAI]
    AS [dbo];

