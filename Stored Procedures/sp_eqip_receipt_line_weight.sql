
create proc sp_eqip_receipt_line_weight (
	@date_from   datetime,
	@date_to   datetime,
	@copc_list  varchar(max) =  '2|0, 3|0, 3|2, 3|3, 12|0, 12|1, 12|2, 12|3, 12|4, 12|5, 12|7, 14|0, 14|1, 14|2, 14|3, 14|5, 14|6, 14|9, 14|10, 14|11, 14|13, 14|14, 15|0, 15|2, 15|3, 15|4, 15|6, 15|7, 16|0, 18|0, 21|0, 21|1, 21|2, 21|3, 22|0, 22|1, 22|2, 23|0, 24|0, 25|0, 25|4, 26|0, 27|0, 28|0, 29|0, 32|0',
/*
	@cust_from  int = 0,
	@cust_to  int = 999999999,
*/	
	@user_code	varchar(20),
	@permission_id int,
	@report_log_id int = NULL
)
as
/* ****************************************************************************	
sp_eqip_receipt_line_weight

	2012-05-08 - JPB - Created, from a request of Mike Stephens for an air Emissions report
		Then it became an SP (this).
		
	sp_eqip_receipt_line_weight 
		@date_from = '2011-01-01', 
		@date_to = '2011-12-31', 
		@copc_list = '29|0', 
		@cust_from = null, 
		@cust_to = null, 
		@user_code = 'jonathan', 
		@permission_id = 79,
		@report_log_id = null

PLT_Export..Template Setup:
	insert plt_export..template  (template_name, worksheet_name, default_filename, added_by, date_added, content)
	select 'sp_eqip_receipt_line_weight.1', 'Sheet1', 'Receipt-Line-Weight {mm}-{dd}-{yyyy}.xlsx', 'JONATHAN', getdate(), bulkcolumn
	FROM OPENROWSET(BULK N'f:\scripts\exporttemplates\sp_eqip_receipt_line_weight.1.xlsx', SINGLE_BLOB) as i

	select * from plt_export..template where template_name = 'sp_eqip_receipt_line_weight.1'
	
Report Setup:
	declare @report_id int
	select @report_id = max(report_id)+ 1 from report
	insert Report (report_id,report_category_id,report_status,report_name,report_desc,report_sp,available_EQAI,available_web,available_multicompany,sample_report_image_id,web_results_page,available_eqip)
	select @report_id, 19, 'A', 'Receipt Line Weight Report', 'Lists weight per Receipt line over a range of dates, customers', 'sp_eqip_receipt_line_weight', 'F', 'F', 'T', 0, NULL, 'T'
	insert ReportXReportCriteria (report_id,report_criteria_id,report_criteria_type,report_criteria_required_flag,report_criteria_default,procedure_param_order,display_order)
	select @report_id, 71, 'Single Value', 'T', 'Previous Month', 1, 1 union
	select @report_id, 49, 'Single Value', 'T', 'Previous Month', 2, 2 union
	select @report_id, 39, 'Multiselect', 'T', '{ALL_COPC}', 3, 3 union
	select @report_id, 4, 'Range', 'T', '1-999999', 4, 4 union
	-- CUST TO: select @report_id, 4, 'Range', 'T', '1-999999', 4, 4 union
	select @report_id, 82, 'Hidden', 'T', '{USER_IDENTIFIER}', 6, 6 union
	select @report_id, 83, 'Hidden', 'T', '{PERMISSION_ID}', 7, 7 union
	select @report_id, 81, 'Hidden', 'T', '{REPORT_LOG_ID}', 8, 8

	delete from ReportXReportCriteria where report_id = 208 and report_criteria_id in (4, 88, 89)
	
	insert ReportCriteria (report_criteria_id, report_criteria_label, report_criteria_data_type, is_facility_specific)
	select (select max(report_criteria_id) + 1 from reportcriteria) as report_criteria_id, 'Customer ID (from)', 'Int', 'F' union
	select (select max(report_criteria_id) + 1 from reportcriteria) as report_criteria_id, 'Customer ID (to)', 'Int', 'F'

	insert ReportXReportCriteria (report_id,report_criteria_id,report_criteria_type,report_criteria_required_flag,report_criteria_default,procedure_param_order,display_order)
	select 208, 88, 'Single Value', 'T', '1-999999', 4, 4 union
	select 208, 89, 'Single Value', 'T', '1-999999', 5, 5 

select * from reportcriteria where report_criteria_label like '%cust%'
sp_help ReportCriteria

select * from reportxreportcriteria x
inner join report r on x.report_id = r.report_id
where x.report_criteria_id = 39
and r.available_eqip = 'T'

update report set report_sp = 'sp_eqip_receipt_line_weight' where report_id = 208
	
	sp_help ReportXReportCriteria
	select * from Report where available_eqip = 'T'
	select * from ReportXReportCriteria where report_id = 207
	
	select top 10 * from reportlog order by report_log_id desc
	
Error occured.  Report failed.  Detail: Executed as user: dbo. Job command: sp_eqip_receipt_line_weight '01/01/2011', '12/31/2011', '29|0', 'JONATHAN', 249, 100550 [SQLSTATE 01000] (Message 0)  Could not find stored procedure 'sp_eqip_receipt_line_weight'. [SQLSTATE 42000] (Error 2812).  The step failed.
Error occured.  Report failed.  Detail: Executed as user: dbo. Job command: sp_eqip_receipt_line_weight '01/01/2011', '12/31/2011', '29|0', 'JONATHAN', 249, 100552 [SQLSTATE 01000] (Message 0)  Column name or number of supplied values does not match table definition. [SQLSTATE 21S01] (Error 213)  BCP Exec String:  /C bcp "SELECT content FROM plt_export..template where template_name = 'sp_eqip_receipt_line_weight.1'" QUERYOUT "F:\Scripts\Exports\receipt-line-weight 01-01-2011 - 12-31-2011.100552-038.645222.xlsx" -T -fF:\Scripts\Exports\export.content.fmt -S NTSQL1 > bcp-output.txt [SQLSTATE 01000] (Error 0)  Current Windows Identity: NTSQL1\SQLDB [SQLSTATE 01000] (Error 0)  Current SQL Identity: NTSQL1\SQLDB [SQLSTATE 01000] (Error 0)  Starting copy...    1 rows copied.  Network packet size (bytes): 4096  Clock Time (ms.) Total     : 15     Average : (66.67 rows per sec.) [SQLSTATE 01000] (Error 0)   [SQLSTATE 01000] (Error 0).  The step failed.	
**************************************************************************** */

SELECT DISTINCT customer_id, cust_name INTO #Secured_Customer
	FROM SecuredCustomer sc  (nolock) WHERE sc.user_code = @user_code
	and sc.permission_id = @permission_id		
	
declare @tbl_profit_center_filter table (
	[company_id] int, 
	profit_ctr_id int
)	

if @copc_list <> 'All' begin

	INSERT @tbl_profit_center_filter 
	SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
	FROM 
		SecuredProfitCenter secured_copc (nolock)
	INNER JOIN (
		SELECT 
			RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
			RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
		from dbo.fn_SplitXsvText(',', 0, @copc_list) 
		where isnull(row, '') <> '') selected_copc ON secured_copc.company_id = selected_copc.company_id AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
		and secured_copc.permission_id = @permission_id
		and secured_copc.user_code = @user_code
		
end	else begin

	INSERT @tbl_profit_center_filter
	SELECT secured_copc.company_id
		   ,secured_copc.profit_ctr_id
	FROM   SecuredProfitCenter secured_copc (nolock)
	WHERE  secured_copc.permission_id = @permission_id
		   AND secured_copc.user_code = @user_code 
end

if datepart(hh, @date_to) = 0 set @date_to = @date_to + 0.99999

declare @run_id int

delete from eq_temp..sp_eqip_receipt_line_weight_table where user_code = @user_code

select @run_id = isnull(max(run_id), 0) + 1 from eq_temp..sp_eqip_receipt_line_weight_table

insert eq_temp..sp_eqip_receipt_line_weight_table (
	[run_id]		,
	[user_code]		,
	[company_id]	,
	[profit_ctr_id] ,
	[receipt_id]	,
	[line_id]		,
	[receipt_date]	,
	[customer_id]	,
	[cust_name]		,
	[generator_id]	,
	[epa_id]		,
	[generator_name],
	[manifest]		,
	[manifest_line] ,
	[approval_code] ,
	[line_weight]	
)
select 
	@run_id as run_id,
	@user_code as user_code,
	r.company_id,
	r.profit_ctr_id,
	r.receipt_id, 
	r.line_id, 
	r.receipt_date, 
	r.customer_id,
	c.cust_name,
	r.generator_id,
	g.epa_id,
	g.generator_name,
	r.manifest,
	r.manifest_line,
	r.approval_code,
	dbo.fn_receipt_weight_line(r.receipt_id, r.line_id, r.profit_ctr_id, r.company_id) as line_weight
from receipt r
	inner join @tbl_profit_center_filter t
		on r.company_id = t.company_id
		and r.profit_ctr_id = t.profit_ctr_id
	inner join #Secured_Customer sc		
		on r.customer_id = sc.customer_id
	inner join customer c on r.customer_id = c.customer_id
	inner join generator g on r.generator_id = g.generator_id

WHERE 1=1 

-- date range:
and r.receipt_date between @date_from and @date_to

-- customer range:
-- and r.customer_id between @cust_from and @cust_to

-- generator range, someday:... Or probably a picklist, not a range
-- and r.generator_id between @gen_from and @gen_to 

-- stolen from WM disposal export...
AND r.receipt_status = 'A'
AND r.fingerpr_status = 'A'
AND ISNULL(r.trans_type, '') = 'D'
AND r.trans_mode = 'I'

order by r.company_id, r.profit_ctr_id, r.receipt_date, r.receipt_id, r.line_id

	declare @fn varchar(100), @d varchar(100), @q varchar(max)
	select @fn = 'Receipt-Line-Weight ' +
		convert(varchar(20), @date_from, 110) + ' - ' +
		convert(varchar(20), @date_to, 110) +
		'.xlsx',
	@d = 'Receipt Line Weight Report, ' +
		convert(varchar(20), @date_from, 110) + ' - ' +
		convert(varchar(20), @date_to, 110),
	@q = 'select company_id ,profit_ctr_id ,receipt_id ,line_id ,receipt_date ,customer_id ,cust_name ,generator_id ,epa_id ,generator_name,manifest ,manifest_line ,approval_code ,line_weight from eq_temp..sp_eqip_receipt_line_weight_table where run_id = ' + convert(varchar(20), @run_id) + ' order by row_id'

	exec plt_export..sp_export_QUERY_to_excel
	@table_name		= @q,
	@template		= 'sp_eqip_receipt_line_weight.1',
	@filename		= @fn,
	@added_by		= @user_code,
	@export_desc	= @d,
	@report_log_id	= @report_log_id,
	@debug			= 0


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_receipt_line_weight] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_receipt_line_weight] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_receipt_line_weight] TO [EQAI]
    AS [dbo];

