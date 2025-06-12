
CREATE PROCEDURE sp_rpt_control_check
	@run_date	datetime = null
AS
/* ************************************************
sp_rpt_control_check:

Returns any PLT_RPT tables not populated on a given date

example:
	exec sp_rpt_control_check '2009-05-31'

LOAD TO PLT_AI*

08/06/2009 JPB Created

************************************************ */

declare @check_date datetime
if @run_date is null set @check_date = getdate()

select distinct 
	ctables.table_name, 
	convert(varchar(20), dates.expected_date_start, 101) expected_date, 
	c.date_started, 
	c.date_ended 
from 
	(select distinct company_id, table_name from control where date_started > dateadd(m, -3, @check_date)) ctables
inner join (
		select 
		convert(datetime, convert(varchar(20), @check_date, 101) + ' 00:00:00') as expected_date_start,
		convert(datetime, convert(varchar(20), @check_date, 101) + ' 23:59:59') as expected_date_end
	) dates on 1=1
left outer join 
	control c 
	on ctables.company_id = c.company_id and ctables.table_name = c.table_name
	and c.date_started between dates.expected_date_start and dates.expected_date_end
where 
	(c.date_started is null or c.date_ended is null) 
	and ctables.company_id <> 0 
order by ctables.table_name


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_control_check] TO [EQLog]
    AS [dbo];

