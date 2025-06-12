drop proc if exists sp_report_criteria_select_one
go
CREATE PROCEDURE sp_report_criteria_select_one
	@report_id	int
AS 
BEGIN

	SELECT DISTINCT
	  rc.report_criteria_id
	  ,rc.report_criteria_label
	  ,rxc.report_criteria_default as report_criteria_default
	  ,rc.report_criteria_data_type
	  ,rxc.report_criteria_type
	  ,rxc.report_criteria_required_flag
	  ,rxc.procedure_param_order
	  ,case when r.report_name like '%CSV' then 'T' else 'F' end as isCSV
		-- isCSV implies the additional RXRC.default_value column is what we actually use
		-- becaue the report_criteria_default column is now used for parameter name.
	  ,rxc.default_value
	FROM  ReportXReportCriteria rxc
		   JOIN ReportCriteria rc
			 ON rxc.report_criteria_id = rc.report_criteria_id 
		   join Report r on rxc.report_id = r.report_id
	WHERE rxc.report_id = @report_id
	ORDER BY rxc.procedure_param_order

END	


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_criteria_select_one] TO [EQWEB]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_criteria_select_one] TO [COR_USER]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_criteria_select_one] TO [EQAI]


