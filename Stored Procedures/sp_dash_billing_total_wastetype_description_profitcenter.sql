
CREATE PROCEDURE sp_dash_billing_total_wastetype_description_profitcenter (
    @StartDate  datetime,
    @EndDate    datetime,
    @user_code  varchar(100) = NULL, -- for associates
    @contact_id int = NULL, -- for customers,
    @copc_list  varchar(max) = NULL, -- ex: 21|1,14|0,14|1
    @permission_id int = NULL
)
AS
/************************************************************
Procedure    : sp_dash_billing_total_wastetype_description_profitcenter
Database     : PLT_AI
Created      : Sep 3, 2009 - Jonathan Broome
Description  : Returns the total amount invoiced per disposal service across all companies
    between @StartDate AND @EndDate, grouped by company AND profit_ctr_id

10/1/2009 - JPB Created 
09/20/2010 - JPB Added Tons, Gallons columns to output.
01/18/2011 - SK	 Data Conversion- Changed to fetch Total from BillingDetail instead of Billing
01/19/2011 - SK  Changed to include the insurance & energy amts in total
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)

sp_dash_billing_total_wastetype_description_profitcenter 
    @StartDate='2009-09-01 00:00:00',
    @EndDate='2009-09-30 23:59:59',
    @user_code='JONATHAN',
    @contact_id=-1,
    @copc_list='2|21,3|1,21|0',
    @permission_id = 91
    
 sp_helptext sp_dash_billing_total_wastetype_description_profitcenter
************************************************************/
Declare @billing_total table(
	company_id			int
,	profit_ctr_id		int
,	receipt_id			int
,	line_id				int
,	price_id			int
,	total				money
)

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

create index cui_secured_customer_tmp on #securedcustomer(customer_id)

 
    DECLARE @container_details ContainerWeightCalculationTable

INSERT INTO @container_details 
SELECT  
	DISTINCT
	r.receipt_id,
	r.company_id,
	r.profit_ctr_id,
	r.line_id,
	c.container_id,
	cd.sequence_id,
	@EndDate, 
	cd.disposal_date,
	c.container_type,
	c.container_size,
	ISNULL(c.container_weight, 0),
	cd.container_percent,
	r.line_weight,
	r.quantity,
	r.bulk_flag
FROM
        BILLING b WITH(NOLOCK) 
        INNER JOIN Receipt r WITH(NOLOCK) ON b.receipt_id = r.receipt_id
		AND b.company_id = r.company_id
		AND b.profit_ctr_id = r.profit_ctr_id
		AND b.line_id = r.line_id
		INNER JOIN Container c ON
			r.receipt_id = c.receipt_id
			AND r.company_id = c.company_id
			AND r.profit_ctr_id = c.profit_ctr_id
			AND r.line_id = c.line_id
		INNER JOIN ContainerDestination cd WITH(NOLOCK) 
			ON cd.receipt_id = c.receipt_id
			AND cd.company_id = c.company_id
			AND cd.profit_ctr_id = c.profit_ctr_id
			AND cd.container_id = c.container_id
			AND cd.line_id = c.line_id
         INNER JOIN #SecuredCustomer sc
            on b.customer_id = sc.customer_id
        INNER JOIN @tbl_profit_center_filter secured_copc 
            ON b.company_id = secured_copc.company_id 
            AND b.profit_ctr_id = secured_copc.profit_ctr_id
        INNER JOIN PROFITCENTER pr
            ON b.company_id = pr.company_id
            AND b.profit_ctr_id = pr.profit_ctr_id
        INNER JOIN PROFILE p 
            ON b.profile_id = p.profile_id
        LEFT OUTER JOIN WASTETYPE WT
            ON p.wastetype_id = wt.wastetype_id
        --LEFT OUTER JOIN BillUnit bu 
        --    on b.bill_unit_code = bu.bill_unit_code
    WHERE 
        b.status_code = 'I' 
        AND pr.status = 'A'
        AND b.trans_source = 'R' 
        AND b.trans_type = 'D'
        AND b.invoice_date BETWEEN @StartDate AND @EndDate
   
    
DECLARE @weight_results ContainerWeightCalculationOutput
INSERT @weight_results exec sp_calculate_container_weight @container_details, 'invoice', @StartDate



-- pre-sum the weight totals
SELECT cd.receipt_id,
       cd.company_id,
       cd.profit_ctr_id,
       cd.line_id,
       Sum(cd.container_weight_pounds)    AS total_pounds,
       Sum(cd.container_weight_gallons) total_gallons
INTO   #weight_totals
FROM   @weight_results cd
GROUP BY cd.receipt_id,
       cd.company_id,
       cd.profit_ctr_id,
       cd.line_id

--IF @debug > 0
--	SELECT 'after #weight_total insert', DATEDIFF(millisecond, @TimeStart, getdate())

-- pre-sum the Billing total from BillingDetail
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
WHERE  b.status_code = 'I' 
    AND b.trans_source = 'R' 
    AND b.trans_type = 'D'
    AND b.invoice_date BETWEEN @StartDate AND @EndDate
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
        ISNULL(wt.category+' - '+wt.description, 'Undefined') AS description, 
        SUM(details.total_pounds) as pounds,
        SUM(details.total_pounds) / 2000 as tons,
        SUM(details.total_gallons) as gallons,
        --SUM(total_extended_amt) AS total 
        SUM(ISNULL(bt.total, 0)) AS total
    FROM
       BILLING b
        INNER JOIN Receipt r ON b.receipt_id = r.receipt_id
        and b.company_id = r.company_id
        and b.profit_ctr_id = r.profit_ctr_id
        and b.line_id = r.line_id
        LEFT JOIN #weight_totals details  WITH(NOLOCK) ON
			details.receipt_id = r.receipt_id
			and details.company_id = r.company_id
			and details.profit_ctr_id  = r.profit_ctr_id
			and details.line_id = r.line_id
        INNER JOIN #SecuredCustomer sc
            on b.customer_id = sc.customer_id
        INNER JOIN @tbl_profit_center_filter secured_copc 
            ON b.company_id = secured_copc.company_id 
            AND b.profit_ctr_id = secured_copc.profit_ctr_id
        INNER JOIN PROFITCENTER pr
            ON b.company_id = pr.company_id
            AND b.profit_ctr_id = pr.profit_ctr_id
        INNER JOIN PROFILE p 
            ON b.profile_id = p.profile_id
        LEFT OUTER JOIN WASTETYPE WT
            ON p.wastetype_id = wt.wastetype_id
        --LEFT OUTER JOIN BillUnit bu 
        --    on b.bill_unit_code = bu.bill_unit_code
        LEFT OUTER JOIN @billing_total bt
			ON bt.company_id = b.company_id
			AND bt.profit_ctr_id = b.profit_ctr_id
			AND bt.receipt_id = b.receipt_id
			AND bt.line_id = b.line_id
			AND bt.price_id = b.price_id			
WHERE 
        b.status_code = 'I' 
        AND pr.status = 'A'
        AND b.trans_source = 'R' 
        AND b.trans_type = 'D'
        AND b.invoice_date BETWEEN @StartDate AND @EndDate
    GROUP BY 
        b.company_id,
        b.profit_ctr_id,
        pr.profit_ctr_name,
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date), 
        wt.category+' - '+wt.description
    ORDER BY
        b.company_id,
        b.profit_ctr_id,
        pr.profit_ctr_name,
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date), 
        --SUM(total_extended_amt) desc,
        total desc,
        wt.category+' - '+wt.description			
			
/*
    SELECT 
        b.company_id,
        b.profit_ctr_id,
        pr.profit_ctr_name,
        DATEPART(YYYY, b.invoice_date) AS invoice_year, 
        DATEPART(M, b.invoice_date) AS invoice_month, 
        ISNULL(wt.category+' - '+wt.description, 'Undefined') AS description, 
        sum((b.quantity * bu.pound_conv)) /2000 as tons,
        sum((b.quantity * bu.gal_conv)) as gallons,
        SUM(total_extended_amt) AS total 
	FROM Receipt r	
			INNER JOIN BILLING b ON r.receipt_id = b.receipt_id
			AND r.company_id = b.company_id
			AND r.profit_ctr_id = b.profit_ctr_id
			AND r.line_id = b.line_id
		INNER JOIN ContainerDestination cd ON cd.receipt_id = r.receipt_id
			AND r.company_id = cd.company_id
			AND r.profit_ctr_id = cd.profit_ctr_id
			AND r.line_id = cd.line_id		
		INNER JOIN @container_details details ON
			cd.receipt_id = details.receipt_id
			AND cd.company_id = details.company_id
			AND cd.profit_ctr_id = details.profit_ctr_id
			AND cd.line_id = details.line_id
			AND cd.sequence_id = details.sequence_id    
        INNER JOIN #SecuredCustomer sc
            on b.customer_id = sc.customer_id
        INNER JOIN @tbl_profit_center_filter secured_copc 
            ON b.company_id = secured_copc.company_id 
            AND b.profit_ctr_id = secured_copc.profit_ctr_id
        INNER JOIN PROFITCENTER pr
            ON b.company_id = pr.company_id
            AND b.profit_ctr_id = pr.profit_ctr_id
        INNER JOIN PROFILE p 
            ON b.profile_id = p.profile_id
        LEFT OUTER JOIN WASTETYPE WT
            ON p.wastetype_id = wt.wastetype_id
        LEFT OUTER JOIN BillUnit bu 
            on b.bill_unit_code = bu.bill_unit_code
    WHERE 
        b.status_code = 'I' 
        AND pr.status = 'A'
        AND b.trans_source = 'R' 
        AND b.trans_type = 'D'
        AND b.invoice_date BETWEEN @StartDate AND @EndDate
    GROUP BY 
        b.company_id,
        b.profit_ctr_id,
        pr.profit_ctr_name,
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date), 
        wt.category+' - '+wt.description
    ORDER BY
        b.company_id,
        b.profit_ctr_id,
        pr.profit_ctr_name,
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date), 
        SUM(total_extended_amt) desc,
        wt.category+' - '+wt.description
*/

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_billing_total_wastetype_description_profitcenter] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_billing_total_wastetype_description_profitcenter] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_billing_total_wastetype_description_profitcenter] TO [EQAI]
    AS [dbo];

