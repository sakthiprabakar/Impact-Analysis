
create proc sp_eqip_revenue_distribution (
	@customer_id_list			varchar(max) = null
	, @customer_category_list	varchar(max) = null			-- Note, this matches on the Description text, not id.
	, @date_field				varchar(20) = 'Invoice'		-- Or 'Service'
	, @date_from				datetime = null			
	, @date_to					datetime = null		
	, @user_code				varchar(20)
	, @permission_id			int
    , @debug					int = 0            -- 0 or 1 for no debug/debug mode
) AS


/* ***************************************************************************************************
sp_eqip_revenue_distribution:

Info:
    Returns revenue from Billing data grouped by customer, invoice, profit center and distribution.
    Customer Category matches on Description text, not id, because it's easier that way when showing the run-time parameters in SSRS.
    LOAD TO PLT_AI

Fixes:
	Grant select on BillingComment to eqweb
	grant select on CustomerCategory to eqweb

Examples:

sp_eqip_revenue_distribution 
	@customer_id_list			= '10673'
	, @customer_category_list	= null
	, @date_field				= 'Foo'
	, @date_from				= '6/1/2015'		
	, @date_to					= '10/28/2015'		
	, @user_code				= 'RICH_G'
	, @permission_id			= 89
    , @debug					= 0

	-- WM: Invoice date: 98 r   2731213.300000
	-- WM: Service date: 102 r	1932688.500000

SELECT * FROM CustomerCategory

sp_eqip_revenue_distribution 
	@customer_id_list			= null
	, @customer_category_list	= '(Show All - No Filter)'
	, @date_field				= 'Foo'
	, @date_from				= '6/1/2015'		
	, @date_to					= '10/28/2015'		
	, @user_code				= 'RICH_G'
	, @permission_id			= 89
    , @debug					= 0


History:
    08/24/2015 JPB  Created
	

*************************************************************************************************** */

-- Set up row-level permission tables

BEGIN

	SELECT DISTINCT customer_id INTO #Secured_Customer
		FROM SecuredCustomer sc  (nolock) WHERE sc.user_code = @user_code
		and sc.permission_id = @permission_id		
	
	create table #profit_center_filter (
		company_id		int, 
		profit_ctr_id	int
	)	

	INSERT #profit_center_filter
	SELECT DISTINCT
			secured_copc.company_id
		   ,secured_copc.profit_ctr_id
	FROM   SecuredProfitCenter secured_copc (nolock)
	WHERE  secured_copc.permission_id = @permission_id
		   AND secured_copc.user_code = @user_code 

-- Handle list inputs
	create table #customer_id (customer_id	int)

    if datalength((@customer_id_list)) > 0 begin
        Insert #Customer_id
        select convert(int, row)
        from dbo.fn_SplitXsvText(',', 0, @customer_id_list)
        where isnull(row, '') <> ''
    end
	
	create table #customercategory (description varchar(100))
	
    if datalength((@customer_category_list)) > 0 begin
        Insert #customercategory
        select left(row, 100)
        from dbo.fn_SplitXsvText(',', 1, @customer_category_list)
        where isnull(row, '') <> ''
    end
    
    if exists (select 1 from #CustomerCategory where description = '(Show All - No Filter)')
		truncate table #CustomerCategory

-- Handle date inputs
	if datepart(hh, @date_to) = 0 set @date_to = @date_to + 0.99999

-- Yeah, hate on dynamic sql, but the performance is better than 'OR's all built together.

	declare @sql nvarchar(max)
	
	set @sql = N'
	select 
		c.Customer_ID
		, c.Cust_Name
		, c.Cust_Category
		, b.Invoice_Code
		, case b.Status_Code when ''I'' then ''Invoiced'' else ''Submitted, Not Invoiced'' end as Status_Code
		, b.Invoice_Date
		, bd.Company_ID
		, bd.Profit_Ctr_ID
		, bd.Billing_Type
		, p.description as Product_Description
		, case bd.Trans_Source when ''R'' then ''Receipt'' when ''W'' then ''Work Order'' when ''O'' then ''Retail Order'' else bd.trans_source end as Trans_Source
		, bd.Dist_Company_ID
		, bd.Dist_Profit_Ctr_ID
		, SUM(bd.extended_amt) as Billing_Amt 
	from BillingDetail bd (NOLOCK) 
	join Billing b (NOLOCK) 
		on bd.billing_uid = b.billing_uid 
	join #profit_center_filter pc
		on b.company_id = pc.company_id
		and b.profit_ctr_id = pc.profit_ctr_id
	join Customer c (NOLOCK) 
		on b.customer_id = c.customer_ID 
	join #Secured_Customer sc
		on c.customer_id = sc.customer_id
	/* CustomerIDJoin */
	/* CustomerCategoryJoin */
	left join product p (nolock)
		on bd.billing_type = ''Product''
		and bd.product_id = p.product_id 
		and bd.dist_company_id = p.company_id 
		and bd.dist_profit_ctr_id = p.profit_ctr_id
	join BillingComment bc 
		on bc.trans_source = b.trans_source 
		and bc.company_id = b.company_id 
		and bc.profit_ctr_id = b.profit_ctr_id 
		and bc.receipt_id = b.receipt_id
	where 1=1
	/* DateWhere */
	group by 
		c.customer_id
		, c.cust_name
		, c.cust_category
		, b.invoice_code
		, b.status_code
		, b.invoice_date
		, bd.company_id
		, bd.profit_ctr_id
		, bd.billing_type
		, p.description
		, case bd.Trans_Source when ''R'' then ''Receipt'' when ''W'' then ''Work Order'' when ''O'' then ''Retail Order'' else bd.trans_source end
		, bd.dist_company_id
		, bd.dist_profit_ctr_id
	order by 
		c.customer_id
		, bd.company_id
		, bd.profit_ctr_id
		, bd.billing_type
		/* , bd.trans_source */
		, bd.dist_company_id
		, bd.dist_profit_ctr_id
'

-- Customer ID Changes
	if exists (select 1 from #customer_id where customer_id is not null)
		set @sql = replace(@sql, '/* CustomerIDJoin */', ' join #customer_id ci on c.customer_id = ci.customer_id ')

-- Customer Type Changes
	if exists (select 1 from #customercategory where isnull(description, '') <> '')
		set @sql = replace(@sql, '/* CustomerCategoryJoin */', ' join #customercategory ct on c.cust_category = ct.description ')

-- Date Changes
	if @date_field = 'Service'
		begin
			if isnull(@date_to, '1/1/1900') > '1/1/1900' and isnull(@date_from, '1/1/1900')  > '1/1/1900'
				begin
					set @sql = replace(@sql, '/* DateWhere */', ' and bc.service_date between ''' + convert(Varchar(20), @date_from) + ''' and ''' + convert(Varchar(20), @date_to) + ''' ')
				end
		end
	else -- 'Invoice'
		begin
			if isnull(@date_to, '1/1/1900') > '1/1/1900' and isnull(@date_from, '1/1/1900')  > '1/1/1900'
				begin
					set @sql = replace(@sql, '/* DateWhere */', ' and b.invoice_date between ''' + convert(Varchar(20), @date_from) + ''' and ''' + convert(Varchar(20), @date_to) + ''' ')
				end
		end
			
-- Debug:
	if isnull(@debug, 0) = 1
		select @sql as sql_statement

-- Execute:
	exec sp_executesql @sql

END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_revenue_distribution] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_revenue_distribution] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_revenue_distribution] TO [EQAI]
    AS [dbo];

