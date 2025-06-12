CREATE PROCEDURE sp_rpt_monthly_contractor_activity
	@date_from		datetime,
	@date_to		datetime,
	@customer_type	varchar(10),
	@customer_id	int,
	@user_code		varchar(max) = NULL, -- for associates
	@copc_list		varchar(500) = NULL, -- ex: 21|1,14|0,14|1
    @permission_id	int = NULL
AS
/****************************************************************************************************
This SP captures the labor utilization in the plants for Monthly Contractor Activity Report

10/04/2012 DZ	Created
12/12/2012 DZ	Modified to sum hours by work order. The report will only return records billed in HOURS

sp_rpt_monthly_contractor_activity '08/01/2012', '08/31/2012', '', NULL, 'DANIEL_Z', '14|15', 1
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
****************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

declare @tbl_profit_center_filter table (
    [company_id] int, 
    profit_ctr_id int
)

IF @user_code = ''
    set @user_code = NULL
    
INSERT @tbl_profit_center_filter
    SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
        FROM SecuredProfitCenter secured_copc
        INNER JOIN (
            SELECT 
                RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
                RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
            from dbo.fn_SplitXsvText(',', 0, @copc_list) 
            where isnull(row, '') <> '') selected_copc ON 
                secured_copc.company_id = selected_copc.company_id 
                AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
                AND secured_copc.permission_id = @permission_id
                AND secured_copc.user_code = @user_code

SELECT sc.customer_id, c.cust_name
INTO #SecuredCustomer
FROM SecuredCustomer sc
JOIN customer c
ON sc.customer_ID = c.customer_ID
WHERE sc.user_code = @user_code
AND sc.permission_id = @permission_id
AND (@customer_type = '' OR c.customer_type = @customer_type)
AND (@customer_id IS NULL OR @customer_id = 0 OR c.customer_id = @customer_id)

CREATE INDEX cui_secured_customer_tmp ON #SecuredCustomer(customer_id)

SELECT 
	--dbo.fn_get_assigned_resource_class_code(resource_assigned, wod.bill_unit_code, woh.company_id) as resource_class_code,
	--wod.resource_assigned,
	--wod.resource_class_code,
	--rc.description as resource_desc,
	--r.description,
	woh.workorder_ID,
	woh.customer_ID,
	secured_customer.cust_name,
	woh.start_date,
	woh.end_date,
	woh.purchase_order,
	woh.release_code,
	woh.project_location,
	woh.description as workorder_desc,
	woh.comments,
	cb.project_name,
	--wod.bill_unit_code,
	--wod.bill_rate,
	SUM(quantity_used) AS total_quantity_used,
	--0 as quantity_used_nc,
	--0 as quantity_hours,
	woh.company_id,
	woh.profit_ctr_ID,
	pc.profit_ctr_name
FROM WorkOrderHeader woh
JOIN WorkOrderDetail wod
	ON woh.workorder_id = wod.workorder_id
	AND woh.profit_ctr_id = wod.profit_ctr_id
	AND	woh.company_id = wod.company_id
	AND wod.resource_type = 'L'
	AND wod.bill_unit_code  = 'HOUR'
	AND wod.bill_rate > 0
LEFT OUTER JOIN CustomerBilling cb
	ON woh.customer_ID = cb.customer_id
	AND woh.billing_project_id = cb.billing_project_id
--JOIN ResourceClass rc
--	ON wod.resource_class_code = rc.resource_class_code
--	AND wod.bill_unit_code = rc.bill_unit_code
--	AND	wod.company_id = rc.company_id
--	AND wod.profit_ctr_ID = rc.profit_ctr_id
INNER JOIN #SecuredCustomer secured_customer
    ON secured_customer.customer_id = woh.customer_id
JOIN @tbl_profit_center_filter secured_copc
    ON woh.company_id = secured_copc.company_id
    AND woh.profit_ctr_id = secured_copc.profit_ctr_id
JOIN ProfitCenter pc
	ON secured_copc.company_id = pc.company_ID
	AND secured_copc.profit_ctr_id = pc.profit_ctr_ID
WHERE woh.workorder_status IN ('C', 'A')
	AND woh.start_date BETWEEN @date_from AND @date_to
GROUP BY 
	woh.workorder_ID,
	woh.customer_ID,
	secured_customer.cust_name,
	woh.start_date,
	woh.end_date,
	woh.purchase_order,
	woh.release_code,
	woh.project_location,
	woh.description,
	woh.comments,
	cb.project_name,
	--wod.bill_unit_code,
	--wod.bill_rate,
	woh.company_id,
	woh.profit_ctr_ID,
	pc.profit_ctr_name

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_monthly_contractor_activity] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_monthly_contractor_activity] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_monthly_contractor_activity] TO [EQAI]
    AS [dbo];

