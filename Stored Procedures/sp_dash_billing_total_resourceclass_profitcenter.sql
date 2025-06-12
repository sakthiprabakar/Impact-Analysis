
CREATE PROCEDURE sp_dash_billing_total_resourceclass_profitcenter (
    @StartDate  datetime,
    @EndDate    datetime,
    @user_code  varchar(100) = NULL, -- for associates
    @contact_id int = NULL, -- for customers,
    @copc_list  varchar(max) = NULL, -- ex: 21|1,14|0,14|1
    @permission_id int = NULL
)
AS
/************************************************************
Procedure    : sp_dash_billing_total_resourceclass_profitcenter
Database     : PLT_AI
Created      : Sep 3, 2009 - Jonathan Broome
Description  : Returns the total amount invoiced per resource_class across all companies
    between @StartDate AND @EndDate, grouped by company AND profit_ctr_id

10/1/2009 - JPB Created 
09/20/2010 - JPB Added Tons, Gallons columns to output.
01/18/2011 - SK Data Conversion- Changed to fetch Total from BillingDetail instead of Billing
01/19/2011 - SK  Changed to include insurance & energy amts in the total
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)

sp_dash_billing_total_resourceclass_profitcenter
    @StartDate='2009-09-01 00:00:00',
    @EndDate='2009-09-30 23:59:59',
    @user_code='JONATHAN',
    @contact_id=-1,
    @copc_list='2|21,3|1,12|0,12|1,12|2,12|3,12|4,12|5,12|7,14|0,14|1,14|2,14|3,14|4,14|5,14|6,14|9,14|10,14|11,14|12,15|1,15|2,15|3,15|4,16|0,17|0,18|0,21|0,21|1,21|2,21|3,22|0,22|1,23|0,24|0',
    @permission_id = 155

************************************************************/
Declare @billing_total table(
	company_id			int
,	profit_ctr_id		int
,	receipt_id			int
,	line_id				int
,	price_id			int
,	total				money
)

-- make sure @EndDate is inclusive
set @EndDate = cast(CONVERT(varchar(20), @EndDate, 101) + ' 23:59:59' as datetime)


IF @user_code = ''
    set @user_code = NULL
    
IF @contact_id = -1
    set @contact_id = NULL

declare @tbl_profit_center_filter table (
    [company_id] int, 
    profit_ctr_id int
)
    
INSERT @tbl_profit_center_filter 
    SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
        FROM SecuredProfitCenter secured_copc
        -- REMOVE THIS FROM dbo.fn_SecuredCompanyProfitCenterExpanded(@contact_id, @user_code) secured_copc --
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

select distinct customer_id
into #SecuredCustomer
from SecuredCustomer sc
where sc.user_code = @user_code
and sc.permission_id = @permission_id

create index cui_secured_customer_tmp on #SecuredCustomer(customer_id)

-- fetch Billing total from BillingDetail
INSERT @billing_total
SELECT
	b.company_id
,	b.profit_ctr_id
,	b.receipt_id
,	b.line_id
,	b.price_id
,	SUM(IsNull(bd.extended_amt,0.000)) AS total
FROM Billing b
LEFT JOIN BillingDetail bd
	ON bd.company_id = b.company_id
	AND bd.profit_ctr_id = b.profit_ctr_id
	AND bd.receipt_id = b.receipt_id
	AND bd.line_id = b.line_id
	AND bd.price_id = b.price_id
	AND bd.trans_type = b.trans_type
	AND bd.trans_source = b.trans_source
	--AND bd.billing_type NOT IN ('Insurance', 'Energy')
WHERE b.status_code = 'I'
	AND b.trans_source = 'W'
    -- AND b.trans_type = 'D'
    AND b.invoice_date BETWEEN @StartDate AND @EndDate
    AND b.workorder_resource_type <> 'D'
GROUP BY
	b.company_id
,	b.profit_ctr_id
,	b.receipt_id
,	b.line_id
,	b.price_id

SELECT
    b.company_id,
    b.profit_ctr_id,
    pr.profit_ctr_name,
    DATEPART(YYYY, b.invoice_date) AS invoice_year,
    DATEPART(M, b.invoice_date) AS invoice_month,
    -- ISNULL(tp.treatment_process, 'Undefined') AS treatment_process,
    rt.resource_type_description,
    b.workorder_resource_item as resource_class,
    rc.description,
    sum((b.quantity * bu.pound_conv)) /2000 as tons,
    sum((b.quantity * bu.gal_conv)) as gallons,
    --SUM(total_extended_amt) AS total
    SUM(IsNull(bt.total, 0)) as total
FROM
BILLING b
INNER JOIN @tbl_profit_center_filter secured_copc
    ON b.company_id = secured_copc.company_id
    AND b.profit_ctr_id = secured_copc.profit_ctr_id
INNER JOIN PROFITCENTER pr
    ON b.company_id = pr.company_id
    AND b.profit_ctr_id = pr.profit_ctr_id
INNER JOIN #SecuredCustomer secured_customer
    ON secured_customer.customer_id = b.customer_id
left outer join ResourceClass rc on b.workorder_resource_item = rc.resource_class_code
    and b.workorder_resource_type = rc.resource_type
    AND b.company_id = rc.company_id
    AND b.profit_ctr_id = rc.profit_ctr_id
    AND b.bill_unit_code = rc.bill_unit_code
left outer join ResourceType rt on b.workorder_resource_type = rt.resource_type
    and b.bill_unit_code = rc.bill_unit_code    
    AND b.company_id = rc.company_id
    AND b.profit_ctr_id = rc.profit_ctr_id
left outer join billunit bu 
     on b.bill_unit_code = bu.bill_unit_code
LEFT OUTER JOIN @billing_total bt
	ON bt.company_id = b.company_id
	AND bt.profit_ctr_id = b.profit_ctr_id
	AND bt.receipt_id = b.receipt_id
	AND bt.line_id = b.line_id
	AND bt.price_id = b.price_id     
WHERE
    1=1
    AND pr.status = 'A'
		AND b.status_code = 'I'
		AND b.trans_source = 'W'
    -- AND b.trans_type = 'D'
    AND b.invoice_date BETWEEN @StartDate AND @EndDate
    AND b.workorder_resource_type <> 'D'
GROUP BY
    b.company_id,
    b.profit_ctr_id,
    pr.profit_ctr_name,
    DATEPART(YYYY, b.invoice_date),
    DATEPART(M, b.invoice_date),
    rt.resource_type_description,
    b.workorder_resource_item,
    rc.description
ORDER BY
    b.company_id,
    b.profit_ctr_id,
    pr.profit_ctr_name,
    DATEPART(YYYY, b.invoice_date),
    DATEPART(M, b.invoice_date),
    --SUM(total_extended_amt) desc,
    total desc,
    rt.resource_type_description,
    b.workorder_resource_item


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_billing_total_resourceclass_profitcenter] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_billing_total_resourceclass_profitcenter] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_billing_total_resourceclass_profitcenter] TO [EQAI]
    AS [dbo];

