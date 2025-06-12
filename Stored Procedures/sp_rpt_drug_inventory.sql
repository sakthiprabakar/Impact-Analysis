
CREATE PROCEDURE sp_rpt_drug_inventory
	@start_date datetime
	, @end_date datetime
	, @customer_id_list	varchar(max) = NULL
	, @state_code varchar(max) = NULL
	, @approval_codes varchar(max) = NULL
	, @user_code	varchar(20)
	, @permission_id int
	, @copc_list  varchar(max) = 'All'
AS

/*********************************************************************************
sp_rpt_drug_inventory

History
	03/13/2012	CG
		REQUEST FROM LESLIE BRUNET FOR A NEW EQIP REPORT:
		GEM-20451
		Generator Name/Number, Address, EPA ID, Service Date, Drug name, NDC number (in 5-4-2 format if possible),
		DEA schedule, quantity/# containers, contents/# pills, notes that the driver has entered (if any),
		workorder, manifest, and receipt numbers.
		I would like to be able to search by state, service date range, and/or approval number(s) please.

		PHONE CONFIRMATION FOR WHAT LESLIE NEEDED TODAY:
		For Thursday's deadline, Leslie request a report for all Generators in NY for the month of Feb 2012
		for '02/01/2012 00:00:00' and '2/29/2012 23:59:59'

	03/11/2014	JPB - Add Customer ID search option	& results
	
Sample:
	exec sp_rpt_drug_inventory 
		@start_date = '01/01/2012 00:00:00'
		, @end_date = '2/29/2012 23:59:59'
		, @state_code = 'NY'
		, @user_code = 'COREY_GO'
		, @permission_id = 244
		
	exec sp_rpt_drug_inventory
		@start_date = '12/01/2011 00:00:00'
		, @end_date = '1/1/2012 23:59:59'
		, @customer_id_list = '10673'
		, @user_code = 'PAUL_K'
		, @permission_id = 244
*********************************************************************************/

if datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

create table #tempapprovals (
	approval varchar(100)
)
	
insert #tempapprovals
select row
from dbo.fn_SplitXsvText(',', 1, @approval_codes)


create table #statecodes (
	statecode varchar(2)
)

insert #statecodes
select row
from dbo.fn_SplitXsvText(',', 1, @state_code)

create table #customer (
	customer_id int
)
create table #cust_Input (
	customer_id int
)
insert #cust_Input 
select row 
from dbo.fn_SplitXsvText(',', 1, @customer_id_list) 
where row is not null

--permissions

SELECT DISTINCT customer_id, cust_name INTO #Secured_Customer
	FROM SecuredCustomer sc  (nolock) WHERE sc.user_code = @user_code
	and sc.permission_id = @permission_id		
	
declare @tbl_profit_center_filter table (
	[company_id] int, 
	profit_ctr_id int
)	

if @copc_list <> 'All'
begin
	INSERT @tbl_profit_center_filter 
	SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
		FROM 
			SecuredProfitCenter secured_copc (nolock)
		INNER JOIN (
			SELECT 
				RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
				RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
			from dbo.fn_SplitXsvText(',', 1, @copc_list) 
			where isnull(row, '') <> '') selected_copc ON secured_copc.company_id = selected_copc.company_id AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
			and secured_copc.permission_id = @permission_id
			and secured_copc.user_code = @user_code
end		
else
begin

	INSERT @tbl_profit_center_filter
	SELECT secured_copc.company_id
		   ,secured_copc.profit_ctr_id
	FROM   SecuredProfitCenter secured_copc (nolock)
	WHERE  secured_copc.permission_id = @permission_id
		   AND secured_copc.user_code = @user_code 
end

if exists (select 1 from #cust_Input)
	insert #customer
	select i.customer_id
	from #cust_Input i
	inner join SecuredCustomer sc on i.customer_id = sc.customer_id
	where sc.user_code = @user_code and sc.permission_id = @permission_id
else
	insert #customer
	select sc.customer_id
	from SecuredCustomer sc
	where sc.user_code = @user_code and sc.permission_id = @permission_id

SELECT DISTINCT 
	c.customer_id
	, c.cust_name
	, g.generator_id AS 'Generator ID'
	, g.generator_name AS 'Generator'
	, g.generator_address_1 AS 'Address 1'
	, g.generator_city AS 'City'
	, g.generator_state AS 'State'
	, g.generator_zip_code AS 'Zip Code'
	, g.EPA_ID AS 'EPA ID'
	, isnull(convert(VARCHAR(10), coalesce(ws.date_act_arrive, wh.start_date), 101), '') AS 'Service Date'
	, wdi.manual_entry_desc AS 'Drug Name'
	, replace(isnull(mc.merchandise_code, wdi.merchandise_code), 'EMPTY', '') AS 'NDC Code'
	, CASE 
		WHEN wdi.dea_schedule IN ('2','3','4','5')
			THEN '0' + wdi.DEA_schedule
		ELSE isnull(wdi.DEA_schedule, '')
		END AS 'DEA Schedule'
	, wdi.merchandise_quantity AS 'Quantity'
	, wdi.contents AS 'Contents'
	, wdi.note AS 'Note'
	, isnull(wdi.dea_form_222_number, '') AS 'DEA 222 Form #'
	, RIGHT('0' + convert(VARCHAR(2), wdi.company_id), 2) + '-' + RIGHT('0' + convert(VARCHAR(2), wdi.profit_ctr_id), 2) AS 'Workorder PC'
	, wdi.workorder_id AS 'Workorder ID'
	, wd.manifest AS 'Manifest'
	, wd.tsdf_approval_code AS 'Approval Code'
	, RIGHT('0' + convert(VARCHAR(2), bll.company_id), 2) + '-' + RIGHT('0' + convert(VARCHAR(2), bll.profit_ctr_id), 2) AS 'Receipt PC'
	, bll.receipt_id AS 'Receipt ID'
FROM WorkorderHeader wh(NOLOCK)
join Customer c (nolock) on wh.customer_id = c.customer_id
JOIN Generator g (NOLOCK) ON wh.generator_id = g.generator_id
JOIN WorkorderStop ws (NOLOCK) ON wh.workorder_ID = ws.workorder_id
	AND wh.company_id = ws.company_id
	AND wh.profit_ctr_ID = ws.profit_ctr_id
	AND ws.stop_sequence_id = 1
JOIN WorkOrderDetail wd (NOLOCK) ON wh.workorder_ID = wd.workorder_ID
	AND wh.company_id = wd.company_id
	AND wh.profit_ctr_ID = wd.profit_ctr_ID
	AND wd.resource_type = 'D'
	AND wd.bill_rate > - 2
JOIN WorkOrderDetailItem wdi (NOLOCK) ON wd.workorder_ID = wdi.workorder_id
	AND wd.company_id = wdi.company_id
	AND wd.profit_ctr_ID = wdi.profit_ctr_id
	AND wd.sequence_ID = wdi.sequence_id
	AND wdi.item_type_ind = 'ME'
LEFT OUTER JOIN MerchandiseCode mc (NOLOCK) ON wdi.merchandise_id = mc.merchandise_id
	AND mc.code_type = '1'
LEFT OUTER JOIN BillingLinkLookup bll (NOLOCK) ON wdi.workorder_id = bll.source_id
	AND wdi.company_id = bll.source_company_id
	AND wdi.profit_ctr_id = bll.source_profit_ctr_id
	AND bll.source_type = 'W'
INNER JOIN @tbl_profit_center_filter copc --make sure company and profit center has permissions
         ON wh.company_id = copc.company_ID
            AND wh.profit_ctr_id = copc.profit_ctr_ID
inner join #customer cp
	ON cp.customer_id = wh.customer_id
WHERE 
	(1 =  CASE WHEN @state_code IS NULL THEN 1 ELSE 
		(CASE WHEN EXISTS (select statecode from #statecodes where statecode = g.generator_state) THEN 1 ELSE 0 END)
	END)
	AND (ws.date_act_arrive BETWEEN @start_date AND @end_date)  
	AND (1 = CASE WHEN @approval_codes is NULL THEN 1 ELSE 
		(CASE WHEN wd.tsdf_approval_code IN (select approval from #tempapprovals) THEN 1 ELSE 0 END) 
	END)
ORDER BY 
	c.customer_id
	, g.generator_id ASC
	, isnull(convert(VARCHAR(10)
	, coalesce(ws.date_act_arrive
	, wh.start_date), 101), '') ASC
	, wdi.manual_entry_desc ASC
	
DROP TABLE #tempapprovals
DROP TABLE #statecodes


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_drug_inventory] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_drug_inventory] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_drug_inventory] TO [EQAI]
    AS [dbo];

