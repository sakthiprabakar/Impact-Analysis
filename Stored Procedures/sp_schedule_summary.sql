CREATE PROCEDURE sp_schedule_summary
	@debug int,
	@date_from datetime,
	@date_to datetime,
	@company_id int,
	@profit_ctr_id int 
AS 
/***********************************************************************
Schedule Summary (from Schedule screen)

Filename:	F:\EQAI\SQL\EQAI\sp_schedule_summary.sql
PB Object(s):	d_rpt_schedule_summary

08-16-2000 LJT	changed sched_quantity to quantity
08-25-2000 LJT	Fixed accumulations and reporting values
10-09-2000 SCC	Added support for profit center
01-30-2001 JDB	Changed profit_ctr_name to varchar(50)
11-25-2003 JDB	Moved company name from parameter to variable.
02-10-2004 SCC	Changed to correctly report the quantity per bill unit when specific approval quantities are provided 
		and report any remaining quantities as CONTAINER quantities for VARIOUS approvals
07-14-2004 SCC	Fixed material count to be the number of materials times the number of bill unit/load type combinations
08-17-2004 JPB	Added nocount set/unset for web use.
10/04/2004 JDB	Replaced "DRUM" with "DM55" as a result of bill unit conversion.
08/02/2006 SCC	Modified to use Profile tables
11/04/2006 SCC	Returns materials and quantities for List format summary report
11/14/2006 SCC  Include bill unit breakdown of VARIOUS scheduled approvals
11/29/2012 DZ   Added company_id, moved from plt_xx_ai to plt_ai
12/31/2012 JDB	Added company_id to the WHERE clause in the SELECT from Company.

sp_schedule_summary 1, '12-31-12 00:00:00', '12-31-12 23:59:59', 21, 0
***********************************************************************/

SET NOCOUNT ON

DECLARE
@bill_unit_code varchar(4),
@insert_count int,
@material_count int,
@load_type char(1),
@profit_ctr_name varchar(50),
@total_quantity decimal(10,3),
@total_quantity_int int,
@total_quantity_varchar varchar(10),
@gallon_convert decimal(10,3),
@sched_month int,
@sched_day int, 
@sched_year int,
@company_name varchar(80),
@company_EPA_ID varchar(12)

-- Get the company name
SELECT @company_name = company_name, @company_EPA_ID = EPA_ID FROM Company WHERE company_id = @company_id
IF Len(@company_EPA_ID) > 0
	SET @company_name = @company_name + ' (' + @company_EPA_ID + ')'

-- Get just the materials
select Distinct
material,
0 as process_flag 
INTO #tmp_material
FROM ScheduleMaterialXProfitCenter
where profit_ctr_id = @profit_ctr_id  
and company_id = @company_id

if @debug = 1 print 'Selecting from #tmp_material'
if @debug = 1 select * from #tmp_material

-- Get the scheduled material and quantities where there is a specific approval code
select 
Schedule.load_type,
Schedule.material,
Schedule.bill_unit_code,
datepart(mm, Schedule.time_scheduled) as sched_month,
datepart(dd, Schedule.time_scheduled) as sched_day, 
datepart(yy, Schedule.time_scheduled) as sched_year, 
sum(Schedule.quantity) as total_quantity, 
IsNull(BillUnit.gal_conv, 1) as gallon_convert
INTO #tmp
FROM Schedule
	JOIN ProfileQuoteApproval ON (Schedule.approval_code = ProfileQuoteApproval.approval_code )
		AND ( Schedule.company_id = ProfileQuoteApproval.company_id  )
		AND ( Schedule.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id  )
	JOIN Profile ON (ProfileQuoteApproval.profile_id = Profile.profile_id)
		AND ( Profile.curr_status_code = 'A' )
	JOIN BillUnit ON ( Schedule.bill_unit_code = billunit.bill_unit_code)
WHERE
Schedule.profit_ctr_id = @profit_ctr_id  
and Schedule.company_id = @company_id
and Schedule.status in ('A', 'P') 
and Schedule.time_scheduled between @date_from and @date_to
and Schedule.end_block_time IS NULL
Group by 
Schedule.load_type,
Schedule.material,
Schedule.bill_unit_code, 
BillUnit.gal_conv,
datepart(yy, Schedule.time_scheduled),
datepart(mm, Schedule.time_scheduled),
datepart(dd, Schedule.time_scheduled)

if @debug = 1 print 'Selecting from #tmp'
if @debug = 1 select * from #tmp

-- Store the VARIOUS approval quantities where the approval was identified
SELECT
Schedule.load_type,
Schedule.material,
ScheduleApproval.bill_unit_code,
datepart(mm, Schedule.time_scheduled) as sched_month,
datepart(dd, Schedule.time_scheduled) as sched_day, 
datepart(yy, Schedule.time_scheduled) as sched_year, 
sum(ScheduleApproval.quantity) as approval_quantity, 
IsNull(BillUnit.gal_conv, 1) as gallon_convert
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
where schedule.approval_code = 'VARIOUS'
and Schedule.status in ('A', 'P') 
and Schedule.profit_ctr_id = @profit_ctr_id 
and Schedule.company_id = @company_id 
and Schedule.time_scheduled between @date_from and @date_to
and Schedule.end_block_time IS NULL
Group by 
Schedule.load_type,
Schedule.material,
ScheduleApproval.bill_unit_code,
BillUnit.gal_conv,
datepart(yy, Schedule.time_scheduled), 
datepart(mm, Schedule.time_scheduled),
datepart(dd, Schedule.time_scheduled)

if @debug = 1 print 'Selecting from #various'
if @debug = 1 select * from #various

-- Store ALL the VARIOUS approval quantities as DM55s when there is no approval specified.
-- The quantities from the VARIOUS approvals with an approval identified will be subtracted to get the real value
SELECT
Schedule.load_type,
Schedule.material,
BillUnit.bill_unit_code,
datepart(mm, Schedule.time_scheduled) as sched_month,
datepart(dd, Schedule.time_scheduled) as sched_day, 
datepart(yy, Schedule.time_scheduled) as sched_year, 
sum(Schedule.quantity) as schedule_quantity, 
convert(decimal(8,3),0) as remainder_quantity, 
IsNull(BillUnit.gal_conv, 1) as gallon_convert
INTO #various_container
FROM Schedule, BillUnit
where schedule.approval_code = 'VARIOUS'
AND BillUnit.bill_unit_code = 'DM55'
and Schedule.status in ('A', 'P') 
and Schedule.profit_ctr_id = @profit_ctr_id 
and Schedule.company_id = @company_id 
and Schedule.time_scheduled between @date_from and @date_to
and Schedule.end_block_time IS NULL
Group by 
Schedule.load_type,
Schedule.material,
BillUnit.bill_unit_code,
BillUnit.gal_conv,
datepart(yy, Schedule.time_scheduled), 
datepart(mm, Schedule.time_scheduled),
datepart(dd, Schedule.time_scheduled)

if @debug = 1 print 'Selecting from #various_container'
if @debug = 1 select * from #various_container

-- Subtract the actual quantities for VARIOUS approvals with an approval specified from the
-- Total quantities to get the true unspecified DM55S quantity
UPDATE #various_container SET remainder_quantity = schedule_quantity - 
	IsNull((select SUM(#various.approval_quantity)
	FROM #various
	WHERE #various_container.load_type = #various.load_type
	AND #various_container.material = #various.material
	AND #various_container.sched_month = #various.sched_month
	AND #various_container.sched_day = #various.sched_day
	AND #various_container.sched_year = #various.sched_year
	GROUP BY
	#various.load_type,
	#various.material,
	#various.sched_year,
	#various.sched_month,
	#various.sched_day), 0)

if @debug = 1 print 'Selecting from #various_container'
if @debug = 1 select * from #various_container

-- INSERT NON-DRUM UNITS INTO #tmp
INSERT #tmp
SELECT 
load_type,
material,
bill_unit_code,
sched_month,
sched_day, 
sched_year, 
approval_quantity,
gallon_convert
FROM #various
--WHERE #various.bill_unit_code <> 'DM55'
UNION ALL
-- INSERT DRUM UNITS INTO #tmp
SELECT 
#various_container.load_type,
#various_container.material,
#various_container.bill_unit_code,
#various_container.sched_month,
#various_container.sched_day,
#various_container.sched_year,
IsNull(#various_container.remainder_quantity,0),
#various_container.gallon_convert
FROM #various_container

if @debug = 1 print 'Selecting from #tmp'
if @debug = 1 select * from #tmp

-- SUMMARIZE THE DATA
SELECT
load_type,
material,
bill_unit_code,
sched_month,
sched_day, 
sched_year, 
IsNull(SUM(total_quantity), 0) as total_quantity,
gallon_convert
INTO #tmp_sum
FROM #tmp
GROUP BY
load_type,
material,
bill_unit_code, 
gallon_convert, 
sched_year, 
sched_month,
sched_day

if @debug = 1 print 'Selecting from #tmp_sum'
if @debug = 1 select * from #tmp_sum

-- Get the profit center to send back
select @profit_ctr_name = profit_ctr_name from ProfitCenter where profit_ctr_id = @profit_ctr_id
and company_ID = @company_id
SET NOCOUNT OFF

-- Return the results
SELECT
@company_name as company_name,
@profit_ctr_name as profit_ctr_name,
@date_from as date_from,
@date_to as date_to,
#tmp_sum.*
FROM #tmp_sum

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_schedule_summary] TO [EQAI]
    AS [dbo];

