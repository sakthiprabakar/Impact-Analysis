
create procedure sp_report_info_select
	@report_id_list varchar(500)
	
	/*
		Gets report information for a given list of reports
		
		Usage: exec sp_report_info_select '181,190'
	*/
as
begin

	declare @tbl_reports table (report_id int)

	insert @tbl_reports 
	select convert(int, row) from dbo.fn_SplitXsvText(',', 1, @report_id_list) where isnull(row, '') <> ''	
	
	-- get report header info
	SELECT r.* FROM Report r
		INNER JOIN @tbl_reports rpt ON r.report_id = rpt.report_id
	
	-- get report criteria (for these reports)
	SELECT rc.report_criteria_label, rc.report_criteria_data_type, rxc.* FROM ReportXReportCriteria rxc
		INNER JOIN @tbl_reports rpt ON rxc.report_id = rpt.report_id
		INNER JOIN ReportCriteria rc ON rxc.report_criteria_id = rc.report_criteria_id
	order by rxc.report_id, rxc.procedure_param_order
	---- get report criteria properties (for each criteria in report)
	--SELECT rpt.report_id, rc.* FROM ReportXReportCriteria rxc
	--	INNER JOIN @tbl_reports rpt ON rxc.report_id = rpt.report_id
	--	INNER JOIN ReportCriteria rc ON rxc.report_criteria_id = rc.report_criteria_id

end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_info_select] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_info_select] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_info_select] TO [EQAI]
    AS [dbo];

