drop proc if exists sp_ReportLogParameter_add
go

create proc sp_ReportLogParameter_add ( -- find and run the next job waiting
	@report_log_id				int,
	@report_criteria_id			int,
	@report_criteria_value_1	varchar(max),
	@report_criteria_value_2	varchar(max) = NULL
)
as
/* ****************************************************** 
sp_ReportLogParameter_add
	Add a record to ReportLog

sp_ReportLogParameter_add 35567, 49, '7/1/2011'

select * from ReportLogParameter where report_log_id = 35567

select * from ReportXReportCriteria where report_id = 190


****************************************************** */

set nocount on

declare @csvdefault varchar(max)
, @label varchar(50)

select 
	@csvdefault = rxrc.default_value
	, @label = rc.report_criteria_label
from reportxreportcriteria rxrc
join reportlog rl on rxrc.report_id = rl.report_id
join report r on rl.report_id = r.report_id	
	and rxrc.report_id = r.report_id
	and r.report_name like '%csv'
join ReportCriteria rc on rxrc.report_criteria_id = rc.report_criteria_id
WHERE rxrc.report_criteria_id = @report_criteria_id
	and rl.report_log_id = @report_log_id

if len(trim(isnull(@csvdefault, ''))) > 0 
	and isnull(@report_criteria_value_1,'') = ''
	and isnull(@report_criteria_value_2,'') = ''
	set @report_criteria_value_1 = @csvdefault

if len(trim(isnull(@csvdefault, ''))) > 0 
	and isnull(@report_criteria_value_1,'') = @label
	and @label = 'copc'
	set @report_criteria_value_1 = @csvdefault

set nocount off

insert ReportLogParameter (
	report_log_id,
	report_id,
	report_sequence_id,
	report_criteria_id,
	report_criteria_label,
	report_criteria_value_1,
	report_criteria_value_2
)	
select 
	rl.report_log_id,
	rl.report_id,
	1 as report_sequence_id,
	rc.report_criteria_id,
	rc.report_criteria_label,
	@report_criteria_value_1 as report_criteria_value_1,
	@report_criteria_value_2 as report_criteria_value_2
from ReportLog rl
inner join ReportXReportCriteria rxrc on rl.report_id = rxrc.report_id
inner join ReportCriteria rc on rxrc.report_criteria_id = rc.report_criteria_id
where rl.report_log_id = @report_log_id
	and rc.report_criteria_id = @report_criteria_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ReportLogParameter_add] TO [EQWEB]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ReportLogParameter_add] TO [COR_USER]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ReportLogParameter_add] TO [EQAI]

