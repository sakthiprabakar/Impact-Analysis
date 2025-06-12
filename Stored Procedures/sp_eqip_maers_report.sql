DROP PROCEDURE IF EXISTS [dbo].[sp_eqip_maers_report]
GO
create proc sp_eqip_maers_report (
    @start_date    datetime,
    @end_date      datetime,
    @copc_list     varchar(max) = NULL, -- ex: 21|1,14|0,14|1)
    @user_code     varchar(100) = NULL, -- for associates
    @contact_id    int = NULL, -- for customers,
    @permission_id int,
    @report_log_id int = null,
    @debug         int = 0
) as 
/****************************************************************

sp_eqip_maers_report
	Returns MAERS report info in a set of facilities, inside of a daterange.

	05/16/2012 JPB - Converted to EQIP report.
	06/28/2022 GDE - DevOps 42734; EQAI VOC Container Info - Report update
sp_eqip_maers_report '1/1/2011', '12/31/2011', '2|0', 'JONATHAN', NULL, 79
sp_eqip_maers_report '1/1/2011', '12/31/2011', '21|0', 'JONATHAN', NULL, 79
sp_eqip_maers_report '1/1/2011', '12/31/2011', '29|0', 'JONATHAN', NULL, 79, 100555

****************************************************************/

if DATEPART(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

if @contact_id = -1 set @contact_id = null

declare @tbl_profit_center_filter table (
    [company_id] int,
    profit_ctr_id int
)
    
INSERT @tbl_profit_center_filter
	SELECT secured_copc.company_id, secured_copc.profit_ctr_id
		FROM SecuredProfitCenter secured_copc
		INNER JOIN (
			SELECT
				RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
				RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
			from dbo.fn_SplitXsvText(',', 0, @copc_list)
			where isnull(row, '') <> '') selected_copc 
			ON secured_copc.company_id = selected_copc.company_id 
			AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
			AND secured_copc.user_code = @user_code
			AND secured_copc.permission_id = @permission_id    
			
	SELECT DISTINCT customer_id, cust_name INTO #Secured_Customer
		FROM SecuredCustomer sc WHERE sc.user_code = @user_code
		and sc.permission_id = @permission_id						


-- 1-25-12 copied from last year, changed dates - LJT
-- 3-17-2011 ran for OK - 29

declare @run_id int
select @run_id = isnull(max(run_id), 0) + 1 from EQ_TEMP..sp_eqip_maers_report_table

delete from EQ_TEMP..sp_eqip_maers_report_table where added_by = @user_code

insert EQ_TEMP..sp_eqip_maers_report_table
SELECT 
	@run_id as run_id,
	@user_code as added_by,
	getdate() as date_added,	
	r.company_id,
	r.profit_ctr_id,
	r.approval_code, 
	r.ddvoc, 
	rp.bill_unit_code, 
	SUM(rp.bill_quantity), 
	r.container_count, 
	r.receipt_id, 
	r.receipt_date, 
	r.bulk_flag 
FROM receipt r
inner join @tbl_profit_center_filter t
	on r.company_id = t.company_id
	AND r.profit_ctr_id = t.profit_ctr_id
inner join #Secured_Customer sc
	on r.customer_id = sc.customer_id
inner join receiptprice rp
	on r.receipt_id = rp.receipt_id
	and r.line_id = rp.line_id
	and r.company_id = rp.company_id
	and r.profit_ctr_id = rp.profit_ctr_id
WHERE r.fingerpr_status = 'A'  
AND  r.receipt_status not in ('R', 'V') 
AND trans_type = 'D'
AND trans_mode = 'I'
AND r.receipt_id = rp.receipt_id
AND r.line_id = rp.line_id
AND receipt_date BETWEEN @start_date AND @end_date
GROUP BY 
	r.company_id,
	r.profit_ctr_id,
	r.receipt_id, 
	r.line_id, 
	rp.bill_unit_code, 
	r.approval_code, 
	r.ddvoc, 
	r.receipt_date, 
	r.container_count, 
	r.bulk_flag

-- perform excel export from EQ_TEMP..sp_eqip_maers_report_table here
	declare @fn varchar(100), @d varchar(100), @q varchar(max)
	select @fn = 'MAERS-Report ' +
		convert(varchar(20), @start_date, 110) + ' - ' +
		convert(varchar(20), @end_date, 110) +
		'.xlsx',
	@d = 'MAERS Report, ' +
		convert(varchar(20), @start_date, 110) + ' - ' +
		convert(varchar(20), @end_date, 110),
	@q = 'select company_id, profit_ctr_id, approval_code, ddvoc, bill_unit_code, sum_quantity, container_count, receipt_id, receipt_date, bulk_flag from EQ_TEMP..sp_eqip_maers_report_table where run_id = ' + convert(varchar(20), @run_id)

	exec (@q)

	/*
	exec plt_export..sp_export_QUERY_to_excel
	@table_name		= @q,
	@template		= 'sp_eqip_maers_report.1',
	@filename		= @fn,
	@added_by		= @user_code,
	@export_desc	= @d,
	@report_log_id	= @report_log_id,
	@debug			= 1
	*/


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_maers_report] TO [EQWEB]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_maers_report] TO [COR_USER]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_maers_report] TO [EQAI]

