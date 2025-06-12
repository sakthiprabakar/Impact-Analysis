
/***********************************************************************
Project Cost Report
LOAD TO PLT_XX_AI databases

Filename:	F:\EQAI\SQL\EQAI\sp_populate_project_cost_report.sql
PB Object(s):	???
This SP selects the projects, retrieves Epicor Accounts Payable data
and Purchase Ordering amounts to run the project costing report
04/22/2002 SCC	Created
02/01/2003 JDB	Changed NTSQL4 to NTSQL5
03/17/2003 NJE  Added code for new company 15 - NE
11/25/2003 JDB	Added code for new company 17, 18, 21, 22, 23, 24.
12/30/2004 SCC  Changed Ticket to Billing
03/27/2007 RG   changed billing herader references to billing comment
		also changed quoteheader references to workorder quote header
09/27/2007 SCC	Changed to select correct server for Prod/Test/Dev separation. Now executes in SQL variable.
06/23/2014 AM Moved to plt_ai

sp_populate_project_cost_report 1, 14, '8-1-2007','8-31-2007', 0, 999999, 'a', 'zzzzzzz', 'SA'
***********************************************************************/
CREATE PROCEDURE sp_populate_project_cost_report 
	@debug			int, 
	@company_id		int, 
	@date_from		datetime, 
	@date_to		datetime, 
	@cust_id_from		int, 
	@cust_id_to		int, 
	@project_code_from	varchar(15), 
	@project_code_to	varchar(15),
	@user_id		varchar(10)
AS
DECLARE 
	@db_type	varchar(4),
	@project_count	int,
	@finance_db	varchar(3),
	@sql		varchar(8000)

CREATE TABLE #tmp_data (
	project_code varchar (15) NOT NULL ,
	user_id varchar (10) NOT NULL ,
	vendor_code varchar (12) NULL ,
	vendor_name varchar (40) NULL ,
	date_applied int NULL ,
	amt_vouchered money NULL )
 
-- Clear any previously generated records for this user

DELETE FROM ProjectCostAP WHERE user_id = @user_id

-- Get the list of projects
SELECT DISTINCT
convert(varchar(15), BillingComment.project_code) as project_code,
0 as process_flag
INTO #tmp_project 
FROM WorkorderQuoteHeader
	LEFT OUTER JOIN BillingComment
		ON BillingComment.project_code = WorkorderQuoteHeader.project_code
		and BillingComment.project_code between @project_code_from and @project_code_to 
	JOIN Billing
		ON BillingComment.receipt_id = Billing.receipt_id 
		and Billing.status_code = 'I'
		and Billing.customer_id between @cust_id_from  and @cust_id_to 
		and Billing.billing_date between @date_from  and @date_to
WHERE WorkorderQuoteHeader.quote_type = 'P'

if @debug = 1 print 'These are the projects'
if @debug = 1 select * from #tmp_project
-- Did we get any projects?
SELECT @project_count = count(*) FROM #tmp_project
if @project_count > 0
BEGIN
	-- Prepare SQL statement
	IF @company_id < 10
		SET @finance_db = 'e0' + CONVERT(char(1), @company_id)
	ELSE
		SET @finance_db = 'e' + CONVERT(varchar(2), @company_id)
	
	-- Get AP Data, preferred data source
	SET @sql = 'INSERT #tmp_data '
		+ 'SELECT DISTINCT ap.ticket_num as project_code, '
		+ '''' + @user_id + ''''
		+ ', ap.vendor_code, apm.address_name, ap.date_applied, ap.amt_net '
		+ 'FROM '
		+ 'NTSQLFINANCE' + '.' + @finance_db + '.dbo.apvohdr ap, '
		+ 'NTSQLFINANCE' + '.' + @finance_db + '.dbo.apmaster apm '
		+ 'WHERE ap.amt_net > 0 and ap.vendor_code = apm.vendor_code and apm.address_type = 0 '
		+ 'and ap.ticket_num IS NOT NULL and ap.ticket_num in (select project_code FROM #tmp_project) '
	IF @debug = 1 print 'First SQL: ' + @sql
	EXECUTE (@sql)

	-- Removed project codes that have already been resolved
	DELETE FROM #tmp_project WHERE project_code IN (SELECT DISTINCT project_code FROM #tmp_data)

	-- If we couldn't get data from AP, get it from purchase orders
	SET @sql = 'INSERT #tmp_data '
		+ 'SELECT DISTINCT po.reference_code as project_code, '
		+ '''' + @user_id + ''''
		+ ', ap.vendor_code, apm.address_name, ap.date_applied, ap.amt_net '
		+ 'FROM '
		+ 'NTSQLFINANCE' + '.' + @finance_db + '.dbo.apvohdr ap, '
		+ 'NTSQLFINANCE' + '.' + @finance_db + '.dbo.apmaster apm, '
		+ 'NTSQLFINANCE' + '.' + @finance_db + '.dbo.purchase po '
	+ 'WHERE po.po_no = ap.po_ctrl_num and ap.vendor_code = apm.vendor_code and apm.address_type = 0 '
	+ 'and po.reference_code IS NOT NULL and po.reference_code in (select project_code FROM #tmp_project) '
	IF @debug = 1 print 'Second SQL: ' + @sql
	EXECUTE (@sql)

	-- Populate the ProjectCostAP table
	INSERT ProjectCostAP SELECT * FROM #tmp_data
END
if @debug = 1 print 'Selecting from #tmp_data'
if @debug = 1 select * from #tmp_data


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_populate_project_cost_report] TO [EQAI]
    AS [dbo];

