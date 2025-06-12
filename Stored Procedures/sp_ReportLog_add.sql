create proc sp_ReportLog_add ( -- find and run the next job waiting
	@report_log_id		int,
	@report_id			int,
	@user_code			varchar(10)
)
as
/* ****************************************************** 
sp_ReportLog_add
	Add a record to ReportLog

****************************************************** */

insert ReportLog (
	company_id,
	profit_ctr_id,
	report_type,
	report_title,
	user_code,
	date_added,
	date_finished,
	report_log_id,
	report_id
)	
select 
	0 as company_id,
	0 as profit_ctr_id,
	c.Report_Category as report_type,
	r.Report_Name as report_title,
	@user_code as user_code,
	getdate() as date_added,
	getdate() as date_finished,
	@report_log_id as report_log_id,
	@report_id as report_id
from report r
inner join ReportCategory c on r.report_category_id = c.report_category_id
	where r.report_id = @report_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ReportLog_add] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ReportLog_add] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ReportLog_add] TO [EQAI]
    AS [dbo];

