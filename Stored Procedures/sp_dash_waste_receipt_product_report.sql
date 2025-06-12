
create procedure sp_dash_waste_receipt_product_report (
    @StartDate  datetime,
    @EndDate    datetime,
    @user_code  varchar(100) = NULL, -- for associates
    @contact_id int = NULL, -- for customers,
    @copc_list  varchar(max) = NULL, -- ex: 21|1,14|0,14|1)
    @product_code varchar(15) = NULL,
    @permission_id int = NULL
) as
/************************************************************
Procedure    : sp_dash_waste_receipt_product_report
Database     : PLT_AI
Created      : Jul 3, 2009 - Jonathan Broome
Description  : Returns a report from plt_ai on receipts fees across all companies
    between @StartDate AND @EndDate, grouped by company AND profit_ctr_id

7/16/2010 - JPB Created 
8/05/2010 - Revised a lot.
9/23/2010 - JPB Added Permission_id input and revised security queries
8/03/2011 - JPB Added read uncommited toggle
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
sp_dash_waste_receipt_product_report 
    @StartDate='2011-07-01 00:00:00',
    @EndDate='2011-07-31 23:59:59',
    @user_code='JONATHAN',
    @contact_id=-1,
    @copc_list='25|0',
    @product_code='OHTAXHZ',
    @permission_id=156

************************************************************/

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

IF @user_code = ''
    set @user_code = NULL
    
IF @contact_id = -1
    set @contact_id = NULL

declare @tbl_profit_center_filter table (
    [company_id] int, 
    profit_ctr_id int
)

INSERT @tbl_profit_center_filter 
    SELECT DISTINCT secured_copc.company_id, secured_copc.profit_ctr_id 
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


-- First select: Receipts that reference another receipt which has a searched-for Product_Code
select 
    ReferencedReceipt.company_id, 
    ReferencedReceipt.profit_ctr_id, 
    ProfitCenter.profit_ctr_name,
    ReferencedReceipt.receipt_date,
    ReferencedReceipt.receipt_id, 
    ReferencedReceipt.line_id, 
    ReferencedReceipt.customer_id,
    Customer.cust_name,
    Generator.generator_id,
    Generator.generator_name,
    Generator.epa_id,
    Generator.generator_state,
    Generator.generator_county,
    Generator.generator_city,
    ReferencedReceipt.manifest,
    ReferencedReceipt.manifest_line,
    ReferencedReceipt.manifest_unit,
    ReferencedReceipt.manifest_quantity,
    case when exists (
         select 1 
         from ReceiptWasteCode 
         INNER JOIN WasteCode on ReceiptWasteCode.waste_code = WasteCode.waste_code 
         where receipt_id = ReferencedReceipt.receipt_id 
         and line_id = ReferencedReceipt.line_id
         and company_id = ReferencedReceipt.company_id 
         and profit_ctr_id = ReferencedReceipt.profit_ctr_id 
         and WasteCode.haz_flag = 'T'
         ) 
         then 'T' 
         else 'F' 
    end as hazmat,
    dbo.fn_receipt_line_unit_quantity_list(ReferencingReceipt.receipt_id, ReferencingReceipt.line_id, ReferencingReceipt.company_id, ReferencingReceipt.profit_ctr_id) as billed_unit,
    ReferencedReceipt.profile_id,
    ReferencedReceipt.approval_code,
    ReferencingReceipt.receipt_id as product_receipt_id,
    ReferencingReceipt.line_id as product_line_id,
    ReferencingReceipt.product_code,
    ReferencingReceipt.bill_unit_code,
    ReferencingReceipt.quantity,
    sum(ReferencingReceiptPrice.price) as price,
    ReferencingReceipt.quantity * sum(ReferencingReceiptPrice.price) as Line_Total
from receipt ReferencedReceipt
INNER JOIN @tbl_profit_center_filter secured_copc 
    ON ReferencedReceipt.company_id = secured_copc.company_id 
    AND ReferencedReceipt.profit_ctr_id = secured_copc.profit_ctr_id
INNER JOIN #SecuredCustomer secured_customer 
    ON secured_customer.customer_id = ReferencedReceipt.customer_id
INNER JOIN Customer
    on ReferencedReceipt.customer_id = Customer.customer_id
INNER JOIN receipt ReferencingReceipt
    on ReferencedReceipt.receipt_id = ReferencingReceipt.ref_receipt_id
    and ReferencedReceipt.line_id = ReferencingReceipt.ref_line_id
    and ReferencedReceipt.company_id = ReferencingReceipt.company_id
    and ReferencedReceipt.profit_ctr_id = ReferencingReceipt.profit_ctr_id
    and ReferencingReceipt.receipt_status = 'A'
    and ReferencingReceipt.fingerpr_status = 'A'
    and ReferencingReceipt.submitted_flag = 'T'
INNER JOIN Product
    on ReferencingReceipt.product_id = Product.product_id
    and ReferencingReceipt.company_id = Product.company_id
    and ReferencingReceipt.profit_ctr_id = Product.profit_ctr_id
INNER JOIN Generator
    on ReferencedReceipt.generator_id = Generator.generator_id
INNER JOIN receiptprice ReferencingReceiptPrice
    on ReferencingReceipt.receipt_id = ReferencingReceiptPrice.receipt_id
    and ReferencingReceipt.line_id = ReferencingReceiptPrice.line_id
    and ReferencingReceipt.company_id = ReferencingReceiptPrice.company_id
    and ReferencingReceipt.profit_ctr_id = ReferencingReceiptPrice.profit_ctr_id
INNER JOIN ProfitCenter
      on ReferencedReceipt.company_id = ProfitCenter.company_id
      and ReferencedReceipt.profit_ctr_id = ProfitCenter.profit_ctr_id
where ReferencedReceipt.trans_type = 'D'
    and ReferencedReceipt.receipt_date between @StartDate and @EndDate
    and Product.product_code = @product_code
    and ReferencedReceipt.receipt_status = 'A'
    and ReferencedReceipt.fingerpr_status = 'A'
    and ReferencedReceipt.submitted_flag = 'T'
group by 
    ReferencedReceipt.company_id, 
    ReferencedReceipt.profit_ctr_id, 
    ProfitCenter.profit_ctr_name,
    ReferencedReceipt.receipt_date,
    ReferencedReceipt.receipt_id, 
    ReferencedReceipt.line_id,
    ReferencedReceipt.customer_id,
    Customer.cust_name, 
    Generator.generator_id,
    Generator.generator_name,
    Generator.epa_id,
    Generator.generator_state,
    Generator.generator_county,
    Generator.generator_city,
    ReferencedReceipt.manifest,
    ReferencedReceipt.manifest_line,
    ReferencedReceipt.manifest_unit,
    ReferencedReceipt.manifest_quantity,
/*
    case when exists (
         select 1 
         from ReceiptWasteCode 
         INNER JOIN WasteCode on ReceiptWasteCode.waste_code = WasteCode.waste_code 
         where receipt_id = ReferencedReceipt.receipt_id 
         and company_id = ReferencedReceipt.company_id 
         and profit_ctr_id = ReferencedReceipt.profit_ctr_id 
         and WasteCode.haz_flag = 'T'
         ) 
         then 'T' 
         else 'F' 
    end,
*/  
    dbo.fn_receipt_line_unit_quantity_list (ReferencingReceipt.receipt_id, ReferencingReceipt.line_id, ReferencingReceipt.company_id, ReferencingReceipt.profit_ctr_id),
    ReferencedReceipt.profile_id,
    ReferencedReceipt.approval_code,
    ReferencingReceipt.receipt_id,
    ReferencingReceipt.line_id,
    ReferencingReceipt.product_code,
    ReferencingReceipt.bill_unit_code,
    ReferencingReceipt.quantity

union

-- Second select: Receipts that are Service lines not referenced elsewhere which have a searched-for Product_Code
select 
    ServiceLineReceipt.company_id, 
    ServiceLineReceipt.profit_ctr_id, 
    ProfitCenter.profit_ctr_name,
    ServiceLineReceipt.receipt_date,
    ServiceLineReceipt.receipt_id, 
    ServiceLineReceipt.line_id, 
    ServiceLineReceipt.customer_id,
    Customer.cust_name,
    null, --Generator.generator_id,
    null, --Generator.generator_name,
    null, --Generator.epa_id,
    null, --Generator.generator_state,
    null, --Generator.generator_county,
    null, --Generator.generator_city,
    ServiceLineReceipt.manifest,
    ServiceLineReceipt.manifest_line,
    ServiceLineReceipt.manifest_unit,
    ServiceLineReceipt.manifest_quantity,
    null, --p.hazmat,
    dbo.fn_receipt_line_unit_quantity_list (ServiceLineReceipt.receipt_id, ServiceLineReceipt.line_id, ServiceLineReceipt.company_id, ServiceLineReceipt.profit_ctr_id) as billed_unit,
    null, -- ServiceLineReceipt.profile_id,
    null, -- ServiceLineReceipt.,approval_code,
    ServiceLineReceipt.receipt_id as product_receipt_id,
    ServiceLineReceipt.line_id as product_line_id,
    ServiceLineReceipt.product_code,
    ServiceLineReceipt.bill_unit_code,
    ServiceLineReceipt.quantity,
    sum(ServiceLineReceiptp.price) as price,
    ServiceLineReceipt.quantity * sum(ServiceLineReceiptp.price) as Line_Total
from receipt ServiceLineReceipt
INNER JOIN @tbl_profit_center_filter secured_copc 
    ON ServiceLineReceipt.company_id = secured_copc.company_id 
    AND ServiceLineReceipt.profit_ctr_id = secured_copc.profit_ctr_id
INNER JOIN #SecuredCustomer secured_customer 
    ON secured_customer.customer_id = ServiceLineReceipt.customer_id
INNER JOIN Customer
    on ServiceLineReceipt.customer_id = Customer.customer_id
INNER JOIN receiptprice ServiceLineReceiptp
    on ServiceLineReceipt.receipt_id = ServiceLineReceiptp.receipt_id
    and ServiceLineReceipt.line_id = ServiceLineReceiptp.line_id
    and ServiceLineReceipt.company_id = ServiceLineReceiptp.company_id
    and ServiceLineReceipt.profit_ctr_id = ServiceLineReceiptp.profit_ctr_id
INNER JOIN ProfitCenter
    on ServiceLineReceipt.company_id = ProfitCenter.company_id
    and ServiceLineReceipt.profit_ctr_id = ProfitCenter.profit_ctr_id
INNER JOIN Product
    on ServiceLineReceipt.product_id = Product.product_id
    and ServiceLineReceipt.company_id = Product.company_id
    and ServiceLineReceipt.profit_ctr_id = Product.profit_ctr_id
where ServiceLineReceipt.trans_type = 'S'
    and isnull(ServiceLineReceipt.ref_receipt_id, -1) = -1
    and ServiceLineReceipt.receipt_date between @StartDate and @EndDate
    and Product.product_code = @product_code
    and ServiceLineReceipt.receipt_status = 'A'
    and ServiceLineReceipt.fingerpr_status = 'A'
    and ServiceLineReceipt.submitted_flag = 'T'
group by 
    ServiceLineReceipt.company_id, 
    ServiceLineReceipt.profit_ctr_id, 
    ProfitCenter.profit_ctr_name,
    ServiceLineReceipt.receipt_date,
    ServiceLineReceipt.receipt_id, 
    ServiceLineReceipt.line_id, 
    ServiceLineReceipt.customer_id,
    Customer.cust_name,
    ServiceLineReceipt.manifest,
    ServiceLineReceipt.manifest_line,
    ServiceLineReceipt.manifest_unit,
    ServiceLineReceipt.manifest_quantity,
    dbo.fn_receipt_line_unit_quantity_list (ServiceLineReceipt.receipt_id, ServiceLineReceipt.line_id, ServiceLineReceipt.company_id, ServiceLineReceipt.profit_ctr_id),
    ServiceLineReceipt.product_code,
    ServiceLineReceipt.bill_unit_code,
    ServiceLineReceipt.quantity
/*
order by
    company_id,
    profit_ctr_id,
    receipt_id,
    line_id
*/

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_waste_receipt_product_report] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_waste_receipt_product_report] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_waste_receipt_product_report] TO [EQAI]
    AS [dbo];

