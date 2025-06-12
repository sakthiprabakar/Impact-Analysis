
CREATE PROCEDURE sp_dash_volume_total_disposalservice_profitcenter (
    @StartDate  datetime,
    @EndDate    datetime,
    @user_code  varchar(100) = NULL, -- for associates
    @contact_id int = NULL, -- for customers,
    @copc_list  varchar(max) = NULL, -- ex: 21|1,14|0,14|1)
    @permission_id int = NULL
) AS
/************************************************************
Procedure    : sp_dash_volume_total_disposalservice_profitcenter
Database     : PLT_AI
Created      : Sep 3, 2009 - Jonathan Broome
Description  : Returns the total volume per disposal service across all companies
    between @StartDate AND @EndDate, grouped by company AND profit_ctr_id

10/1/2009 - JPB Created 
09/20/2010 - JPB Added Tons, Gallons columns to output.
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)

sp_dash_volume_total_disposalservice_profitcenter 
    @StartDate='2009-09-01 00:00:00',
    @EndDate='2009-09-30 23:59:59',
    @user_code='JONATHAN',
    @contact_id=-1,
    @copc_list='2|21,3|1,21|0',
    @permission_id = 85

************************************************************/

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

    SELECT 
        b.company_id, 
        b.profit_ctr_id, 
        pr.profit_ctr_name,
        DATEPART(YYYY, b.invoice_date) AS invoice_year, 
        DATEPART(M, b.invoice_date) AS invoice_month, 
        ISNULL(d.disposal_service_desc, 'Undefined') AS disposal_service, 
        sum((b.quantity * bu.pound_conv)) /2000 as tons,
        sum((b.quantity * bu.gal_conv)) as gallons
    FROM
        BILLING b
        INNER JOIN #SecuredCustomer secured_customer 
            ON secured_customer.customer_id = b.customer_id
        INNER JOIN @tbl_profit_center_filter secured_copc 
            ON b.company_id = secured_copc.company_id 
            AND b.profit_ctr_id = secured_copc.profit_ctr_id
        INNER JOIN PROFITCENTER pr
            ON b.company_id = pr.company_id
            AND b.profit_ctr_id = pr.profit_ctr_id
        INNER JOIN PROFILE p 
            ON b.profile_id = p.profile_id
        INNER JOIN PROFILEQUOTEAPPROVAL pqa 
            ON p.profile_id = pqa.profile_id
            AND b.company_id = pqa.company_id 
            AND b.profit_ctr_id = pqa.profit_ctr_id
        LEFT OUTER JOIN DISPOSALSERVICE d 
            ON pqa.disposal_service_id = d.disposal_service_id
		left outer join billunit bu 
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
        d.disposal_service_desc
    ORDER BY
        b.company_id, 
        b.profit_ctr_id, 
        pr.profit_ctr_name,
        DATEPART(YYYY, b.invoice_date), 
        DATEPART(M, b.invoice_date),
        d.disposal_service_desc


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_volume_total_disposalservice_profitcenter] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_volume_total_disposalservice_profitcenter] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_volume_total_disposalservice_profitcenter] TO [EQAI]
    AS [dbo];

