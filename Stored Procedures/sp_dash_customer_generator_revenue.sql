

Create procedure sp_dash_customer_generator_revenue (
	@customer_id_list	varchar(max) = NULL,
    @start_date    datetime,
    @end_date      datetime,
    @copc_list     varchar(max) = NULL, -- ex: 21|1,14|0,14|1)
    @state_list    varchar(max) = '',
    @report_type   char(1) = 'S', -- 'S'ummary or s'T'ate or 'C'ity or 'G'enerator or 'A'ccount (Customer) or 'I'nvoice or 'R'eceipt (Receipt/Workorder)
    @user_code     varchar(100) = NULL, -- for associates
    @contact_id    int = NULL, -- for customers,
    @permission_id int,
    @debug         int = 0
    
)
AS
/* *****************************************************************************
sp_dash_customer_generator_revenue

Returns a report of revenue from generators per summary, state or city

-- Run the first part, then run the second two parts
-- and save as separte tabs in an excel sheet.
-- 08-12-2008 LJT added city
-- 01-14-2009 LJT ran for 2008 for Ryan
-- 01-22-2009 LJT ran for 2008 for Ryan again.
-- 02-19-2010 JDB ran for 2009 for Ryan

select convert(varchar(2),company_id) + '|' + convert(varchar(2), profit_ctr_id) from profitcenter where status = 'A' order by company_id, profit_ctr_id 

06/10/2010 - JPB - Created
09/14/2010 - JPB - Added Generator as output type
11/22/2010 - JPB - Added Customer info to output per GEM-16270
05/11/2012 - JPB - Added 'R'eceipt (below Invoice detail) option.
09/04/2012 - RWB - Added invoice_date to result set
01/09/2013 - JPB - Copied sp_dash_generator_revenue, added customer param per LT
	for a one-off run.
06/06/2016 - JPB - StateAbbreviation joins updated to include country
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

sp_dash_customer_generator_revenue '1125', '2009-01-01', '2009-12-31', 'ALL', '', 'R', 'JONATHAN', NULL, 0
sp_dash_customer_generator_revenue '1125', '2009-01-01', '2009-12-31', '2|21,3|1,12|0,12|1,12|3,12|4,12|5,14|0,14|1,14|2,14|3,14|4,14|5,14|6,14|7,14|8,14|9,14|10,14|11,14|12,15|0,15|1,15|2,15|3,17|0,18|0,21|0,21|1,21|2,22|0,23|0,24|0', '', 'S', 'JONATHAN', NULL, 0
sp_dash_customer_generator_revenue '1125', '2009-01-01', '2009-12-31', '', '', 'C', 'JONATHAN', NULL, 0

sp_dash_customer_generator_revenue '1125', '2009-01-01', '2009-12-31', '2|21,3|1,12|0,12|1,12|2,12|3,12|4,12|5,12|7,14|0,14|1,14|2,14|3,14|4,14|5,14|6,14|9,14|10,14|11,14|12,15|1,15|2,15|3,15|4,16|0,17|0,18|0,21|0,21|1,21|2,21|3,22|0,22|1,23|0,24|0', 'MI, OH, KY, PA', 'S'
, 'JONATHAN', -1, 0
sp_dash_customer_generator_revenue '1125', '2009-01-01', '2009-12-31', '2|21,3|1,12|0,12|1,12|2,12|3,12|4,12|5,12|7,14|0,14|1,14|2,14|3,14|4,14|5,14|6,14|9,14|10,14|11,14|12,15|1,15|2,15|3,15|4,16|0,17|0,18|0,21|0,21|1,21|2,21|3,22|0,22|1,23|0,24|0', 'MI, OH, KY, PA', 'T'
, 'JONATHAN', NULL, 0
sp_dash_customer_generator_revenue '1125', '2009-01-01', '2009-12-31', '2|21,3|1,12|0,12|1,12|2,12|3,12|4,12|5,12|7,14|0,14|1,14|2,14|3,14|4,14|5,14|6,14|9,14|10,14|11,14|12,15|1,15|2,15|3,15|4,16|0,17|0,18|0,21|0,21|1,21|2,21|3,22|0,22|1,23|0,24|0', 'MI, OH, KY, PA', 'C'
, 'JONATHAN', NULL, 0

sp_dash_customer_generator_revenue '2010-01-01', '2010-06-01', '2|21,3|1,12|0,12|1,12|2,12|3,12|4,12|5,12|7,14|0', 'MI, OH, KY, PA', 'S', 'JONATHAN',-1, 0

sp_dash_customer_generator_revenue '1125', '2009-01-01', '2009-12-31', 'ALL', '', 'R', 'JONATHAN',-1, 154, 0
sp_dash_customer_generator_revenue '1125', '2009-01-01', '2009-12-31', 'ALL', '', 'G', 'JONATHAN',-1, 154, 0

sp_dash_customer_generator_revenue '1125', '2010-01-01', '2010-12-31', 'ALL', '', 'R', 'JONATHAN',-1, 154, 0
sp_dash_customer_generator_revenue '1125', '2010-01-01', '2010-12-31', 'ALL', '', 'G', 'JONATHAN',-1, 154, 0

sp_dash_customer_generator_revenue '1125', '2011-01-01', '2011-12-31', 'ALL', '', 'R', 'JONATHAN',-1, 154, 0
sp_dash_customer_generator_revenue '1125', '2011-01-01', '2011-12-31', 'ALL', '', 'G', 'JONATHAN',-1, 154, 0

sp_dash_customer_generator_revenue '1125', '2010-07-01', '2010-10-01', '27|0', 'NY', 'T', 'JONATHAN',-1, 154, 0
sp_dash_customer_generator_revenue '1125', '2010-07-01', '2010-10-01', '27|0', 'NY', 'C', 'JONATHAN',-1, 154, 0
sp_dash_customer_generator_revenue '1125', '2010-07-01', '2010-10-01', '27|0', 'NY', 'G', 'JONATHAN',-1, 154, 0
sp_dash_customer_generator_revenue '1125', '2010-07-01', '2010-10-01', '27|0', 'NY, PA', 'A', 'JONATHAN',-1, 154, 0
sp_dash_customer_generator_revenue '1125', '2010-07-01', '2010-10-01', '27|0', 'NY, PA', 'I', 'JONATHAN',-1, 154, 0
sp_dash_customer_generator_revenue '1125', '2010-07-01', '2010-10-01', '21|0', 'ON, QE', 'I', 'JONATHAN',-1, 154, 0 -- 67 r
sp_dash_customer_generator_revenue '1125', '2010-07-01', '2010-10-01', '21|0', 'ON, QE', 'R', 'JONATHAN',-1, 154, 0 -- 86 r

sp_help sp_dash_customer_generator_revenue

    @start_date    datetime,
    @end_date      datetime,
    @copc_list     varchar(500) = NULL, -- ex: 21|1,14|0,14|1)
    @state_list    varchar(150) = '',
    @report_type   char(1) = 'S', -- 'S'ummary or s'T'ate or 'C'ity
    @user_code     varchar(100) = NULL, -- for associates
    @contact_id    int = NULL, -- for customers,
    @debug         int = 0

***************************************************************************** */

set nocount on

create table #state (state varchar(2))
insert #state select row from dbo.fn_SplitXsvText(',', 1, @state_list) where isnull(row, '') <> ''
if (select count(*) from #state) = 0
   insert #state select '*' union all select abbr from StateAbbreviation

if DATEPART(hh, @end_date) = 0 and DATEPART(n, @end_date) = 0
   set @end_date = DATEADD(s, (((23 * 60 * 60) + (59 * 60)) + 59), @end_date)

if @contact_id = -1 set @contact_id = null

declare @tbl_profit_center_filter table (
    [company_id] int,
    profit_ctr_id int
)
    
    
if isnull(@copc_list, '') <> 'ALL' begin
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
end else begin
	INSERT @tbl_profit_center_filter
	SELECT DISTINCT company_id, profit_ctr_id
		FROM SecuredProfitCenter secured_copc
		WHERE 
			secured_copc.user_code = @user_code
			AND secured_copc.permission_id = @permission_id    
end
			
	SELECT DISTINCT customer_id, cust_name INTO #Secured_Customer
		FROM SecuredCustomer sc WHERE sc.user_code = @user_code
		and sc.permission_id = @permission_id						
    
    -- Run for a specific customer, or list of them
    IF isnull(@customer_id_list, '') <> ''
		delete from #Secured_Customer where customer_id not in (
			select customer_id from customer c
			inner join  dbo.fn_SplitXsvText(',', 1, @customer_id_list) x on convert(int, x.row) = c.customer_id
			where x.row is not null
		)
		
--INSERT @tbl_profit_center_filter
--    SELECT secured_copc.company_id, secured_copc.profit_ctr_id
--        FROM dbo.fn_SecuredCompanyProfitCenterExpanded(@contact_id, @user_code) secured_copc
--        INNER JOIN (
--            SELECT
--                RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
--                RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
--            from dbo.fn_SplitXsvText(',', 0, @copc_list)
--            where isnull(row, '') <> '') selected_copc ON secured_copc.company_id = selected_copc.company_id AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id

/*
if @debug > 0 begin
    select @start_date as start_date, @end_date as end_date, @debug as debug
    select * from #state
    select * from @tbl_profit_center_filter
end
*/

SELECT
    --company_id, profit_ctr_id,
    isnull(CASE WHEN ISNULL(billing.generator_id,0) <> 0  THEN
         (select ISNULL(state_name,'* Unknown') from Generator g inner join stateabbreviation sa on g.generator_state = sa.abbr and g.generator_country = sa.country_code where g.generator_id = billing.generator_id)
    ELSE
        (select ISNULL(state_name,'* Unknown') from Customer c inner join stateabbreviation sa on c.cust_state = sa.abbr and c.cust_country = sa.country_code where c.customer_id = billing.customer_id)
    END, '* Unknown') as state_name,
    CASE WHEN ISNULL(billing.generator_id,0) <> 0  THEN
         (select ISNULL(generator_city,'* Unknown') from Generator g where g.generator_id = billing.generator_id)
    ELSE
        (select ISNULL(cust_city,'* Unknown') from Customer c where c.customer_id = billing.customer_id)
    END as city_name,
    CASE WHEN billing.trans_source = 'R' and billing.trans_type in ('D','W') THEN
        isnull(waste_extended_amt, 0)
    ELSE
        0
    END as Disposal_amount,
    CASE WHEN billing.trans_source = 'R' and billing.trans_type not in ('D','W') THEN
        isnull(waste_extended_amt, 0)
    ELSE
        0
    END as Service_amount,
    CASE WHEN billing.trans_source = 'R'  THEN
        isnull(sr_extended_amt, 0)
    ELSE
        0
    END as SR_amount,
    CASE WHEN billing.trans_source <> 'R' THEN
        isnull(total_extended_amt, 0)
    ELSE
        0
    END as Other_amount,
    isnull(insr_extended_amt, 0) as insr_amount,
    isnull(ensr_extended_amt, 0) as ensr_amount,
    isnull(total_extended_amt, 0) as total_amount,
    isnull((
        select sum(bd.extended_amt) 
        from BillingDetail bd 
        where billing.company_id = bd.company_id
        and billing.profit_ctr_id = bd.profit_ctr_id
        and billing.receipt_id = bd.receipt_id
        and billing.line_id = bd.line_id
        and billing.price_id = bd.price_id
        and billing.trans_source = bd.trans_source
        and bd.billing_type = 'SalesTax'
    ), 0) as sales_tax_amount,
    billing.*,
    g.epa_id,
    g.generator_name as gen_generator_name
INTO #report_temp
FROM billing
INNER JOIN @tbl_profit_center_filter secured_copc
    ON billing.company_id = secured_copc.company_id
    AND billing.profit_ctr_id = secured_copc.profit_ctr_id
inner join #state on 
    isnull(CASE WHEN ISNULL(billing.generator_id,0) <> 0  THEN
         (select ISNULL(sa.abbr,'*') from Generator g inner join stateabbreviation sa on g.generator_state = sa.abbr and g.generator_country = sa.country_code where g.generator_id = billing.generator_id)
    ELSE
        (select ISNULL(sa.abbr,'*') from Customer c inner join stateabbreviation sa on c.cust_state = sa.abbr and c.cust_country_code = sa.country_code where c.customer_id = billing.customer_id)
    END, '*') = #state.state    
INNER JOIN #Secured_Customer secured_customer ON (secured_customer.customer_id = billing.customer_id)    
LEFT OUTER JOIN Generator g on billing.generator_id = g.generator_id
where 1=1
    --Trans_source = 'R'
    AND billing.status_code = 'I'
    AND billing.void_status = 'F'
    AND billing.invoice_date BETWEEN @start_date and @end_date


create table #output (
	company_id		int,
	profit_ctr_id	int,
    Facility		varchar(10),
    State			varchar(40),
    City			varchar(40),
    [Generator ID]	int,
    Generator		varchar(75),
    [Generator EPA ID]	varchar(20),
    [Disposal Amount]	float,
    [Service Amount]	float,
    [SR Amount]		float,
    [WO Amount]		float,
    [Total Ins Surch]	float,
    [Total Energy Surch]	float,
    [Total Sales Tax]	float,
    [Total Amount]	float,
    customer_id	int,
    cust_name	varchar(75),
    cust_city	varchar(40),
    cust_state	varchar(40),
    invoice		varchar(40),
    trans_source	char(1),
    receipt_id	int,
    invoice_date	datetime
)

if @report_type = 'S' BEGIN -- Summary
    -----------------------------------------------
    --2
    -----------------------------------------------
    insert #output
    select --company_name as 'Company',
    --profit_ctr_name as 'Profit Center',
	rt.company_id,
	rt.profit_ctr_id,
    Convert(varchar(2),rt.company_id)+'-'+convert(varchar(2),rt.profit_ctr_id) AS 'Facility',
    'All' as 'State',
    'All' as 'City',
    NULL as 'Generator ID',
    'All' as 'Generator',
    'All' as 'Generator EPA ID',
    sum(service_amount) as 'Service Amount',
    sum(disposal_amount) as 'Disposal Amount',
    -- sum(service_amount + disposal_amount) as 'Disp&Svc Amount',
    sum(sr_amount) as 'SR Amount',
    sum(other_amount) as 'WO Amount',
    sum(insr_amount) as 'Total Ins Surch',
    sum(ensr_amount) as 'Total Energy Surch',
    sum(sales_tax_amount) as 'Total Sales Tax',
    sum(total_amount+insr_amount+ensr_amount+sales_tax_amount) as 'Total Amount'
    ,Null as customer_id
    ,'All' as cust_name
    ,'All' as cust_city
    ,'All' as cust_state
    ,'Various' as invoice
    , NULL
    , NULL
    , NULL
    from #report_temp rt
    inner join company c on rt.company_id = c.company_id
    inner join profitcenter pc on rt.company_id = pc.company_id and rt.profit_ctr_id = pc.profit_ctr_id
    group by rt.company_id, rt.profit_ctr_id,company_name, profit_ctr_name
    order by rt.company_id, rt.profit_ctr_id
END


if @report_type = 'T' BEGIN -- State
    -----------------------------------------------
    --1
    -----------------------------------------------
    insert #output
    select --company_name as 'Company',
    --profit_ctr_name as 'Profit Center',
	rt.company_id,
	rt.profit_ctr_id,
    Convert(varchar(2),rt.company_id)+'-'+convert(varchar(2),rt.profit_ctr_id) as 'Facility',
    ISNull(state_name,'* Unknown') as 'State',
    'All' as 'City',
    NULL as 'Generator ID',
    'All' as 'Generator',
    'All' as 'Generator EPA ID',
    sum(disposal_amount) as 'Disposal Amount',
    sum(service_amount) as 'Service Amount',
    sum(sr_amount) as 'SR Amount',
    sum(other_amount) as 'WO Amount',
    sum(insr_amount) as 'Total Ins Surch',
    sum(ensr_amount) as 'Total Energy Surch',
    sum(sales_tax_amount) as 'Total Sales Tax',
    sum(total_amount+insr_amount+ensr_amount+sales_tax_amount) as 'Total Amount'
    ,Null as customer_id
    ,'All' as cust_name
    ,'All' as cust_city
    ,'All' as cust_state
    ,'Various' as invoice
    , NULL
    , NULL
    , NULL
    from #report_temp rt
    inner join company c on rt.company_id = c.company_id
    inner join profitcenter pc on rt.company_id = pc.company_id and rt.profit_ctr_id = pc.profit_ctr_id
    group by rt.company_id, rt.profit_ctr_id,company_name, profit_ctr_name, state_name
    order by rt.company_id, rt.profit_ctr_id, rt.State_name
END



if @report_type = 'C' BEGIN -- City
    -----------------------------------------------
    --3
    -----------------------------------------------
    -- MI only with city
    insert #output
    select --company_name as 'Company',
    --profit_ctr_name as 'Profit Center',
	rt.company_id,
	rt.profit_ctr_id,
    Convert(varchar(2),rt.company_id)+'-'+convert(varchar(2),rt.profit_ctr_id) as 'Facility',
    ISNull(state_name,'* Unknown') as 'State', 
    ISNull(city_name,'* Unknown') as 'City',
    NULL as 'Generator ID',
    'All' as 'Generator',
    'All' as 'Generator EPA ID',
    sum(disposal_amount) as 'Disposal Amount', 
    sum(service_amount) as 'Service Amount', 
    sum(sr_amount) as 'SR Amount',
    sum(other_amount) as 'WO Amount',
    sum(insr_amount) as 'Total Ins Surch',
    sum(ensr_amount) as 'Total Energy Surch',
    sum(sales_tax_amount) as 'Total Sales Tax',
    sum(total_amount+insr_amount+ensr_amount+sales_tax_amount) as 'Total Amount'
    ,Null as customer_id
    ,'All' as cust_name
    ,'All' as cust_city
    ,'All' as cust_state
    ,'Various' as invoice
    , NULL
    , NULL
    , NULL
    from #report_temp rt
    inner join company c on rt.company_id = c.company_id
    inner join profitcenter pc on rt.company_id = pc.company_id and rt.profit_ctr_id = pc.profit_ctr_id
    -- where State_name = 'Michigan'
    group by rt.company_id, rt.profit_ctr_id,company_name, profit_ctr_name, state_name,city_name
    order by rt.company_id, rt.profit_ctr_id, rt.State_name,rt.city_name
END


if @report_type = 'G' BEGIN -- Generator
    -----------------------------------------------
    --3
    -----------------------------------------------
    -- MI only with city
    insert #output
    select --company_name as 'Company',
    --profit_ctr_name as 'Profit Center',
	rt.company_id,
	rt.profit_ctr_id,
    Convert(varchar(2),rt.company_id)+'-'+convert(varchar(2),rt.profit_ctr_id) as 'Facility',
    ISNull(state_name,'* Unknown') as 'State', 
    ISNull(city_name,'* Unknown') as 'City',
    generator_id as 'Generator ID',
    ISNull(rt.gen_generator_name, '* Unknown') as 'Generator',
    ISNull(rt.epa_id, '* Unknown') as 'Generator EPA ID',
    sum(disposal_amount) as 'Disposal Amount', 
    sum(service_amount) as 'Service Amount', 
    sum(sr_amount) as 'SR Amount',
    sum(other_amount) as 'WO Amount',
    sum(insr_amount) as 'Total Ins Surch',
    sum(ensr_amount) as 'Total Energy Surch',
    sum(sales_tax_amount) as 'Total Sales Tax',
    sum(total_amount+insr_amount+ensr_amount+sales_tax_amount) as 'Total Amount'
    ,Null as customer_id
    ,'All' as cust_name
    ,'All' as cust_city
    ,'All' as cust_state
    ,'Various' as invoice
    , NULL
    , NULL
    , NULL
    from #report_temp rt
    inner join company c on rt.company_id = c.company_id
    inner join profitcenter pc on rt.company_id = pc.company_id and rt.profit_ctr_id = pc.profit_ctr_id
    -- where State_name = 'Michigan'
    group by rt.company_id, rt.profit_ctr_id,company_name, profit_ctr_name, state_name,city_name, generator_id, rt.gen_generator_name, rt.epa_id
    order by rt.company_id, rt.profit_ctr_id, rt.State_name,rt.city_name
END


if @report_type = 'A' BEGIN -- Account
    -----------------------------------------------
    --4
    -----------------------------------------------
    insert #output
    select
	rt.company_id,
	rt.profit_ctr_id,
    Convert(varchar(2),rt.company_id)+'-'+convert(varchar(2),rt.profit_ctr_id) as 'Facility',
    ISNull(state_name,'* Unknown') as 'State', 
    ISNull(city_name,'* Unknown') as 'City',
    generator_id as 'Generator ID',
    ISNull(rt.gen_generator_name, '* Unknown') as 'Generator',
    ISNull(rt.epa_id, '* Unknown') as 'Generator EPA ID',
    sum(disposal_amount) as 'Disposal Amount', 
    sum(service_amount) as 'Service Amount', 
    sum(sr_amount) as 'SR Amount',
    sum(other_amount) as 'WO Amount',
    sum(insr_amount) as 'Total Ins Surch',
    sum(ensr_amount) as 'Total Energy Surch',
    sum(sales_tax_amount) as 'Total Sales Tax',
    sum(total_amount+insr_amount+ensr_amount+sales_tax_amount) as 'Total Amount'
    ,cust.customer_id
    ,cust.cust_name
    ,cust.cust_city
    ,cust.cust_state
    ,'Various' as invoice
    , NULL
    , NULL
    , NULL
    from #report_temp rt
    inner join company c on rt.company_id = c.company_id
    inner join profitcenter pc on rt.company_id = pc.company_id and rt.profit_ctr_id = pc.profit_ctr_id
    inner join customer cust on rt.customer_id = cust.customer_id
    -- where State_name = 'Michigan'
    group by 	rt.company_id,
	rt.profit_ctr_id,
	rt.company_id, rt.profit_ctr_id,company_name, profit_ctr_name, state_name,city_name, generator_id, rt.gen_generator_name, rt.epa_id
    ,cust.customer_id
    ,cust.cust_name
    ,cust.cust_city
    ,cust.cust_state
    order by rt.company_id, rt.profit_ctr_id, rt.State_name,rt.city_name    
   
END

if @report_type = 'I' BEGIN -- Detail (Invoice)
    -----------------------------------------------
    --5
    -----------------------------------------------
    insert #output
    select
	rt.company_id,
	rt.profit_ctr_id,
    Convert(varchar(2),rt.company_id)+'-'+convert(varchar(2),rt.profit_ctr_id) as 'Facility',
    ISNull(state_name,'* Unknown') as 'State', 
    ISNull(city_name,'* Unknown') as 'City',
    generator_id as 'Generator ID',
    ISNull(rt.gen_generator_name, '* Unknown') as 'Generator',
    ISNull(rt.epa_id, '* Unknown') as 'Generator EPA ID',
    sum(disposal_amount) as 'Disposal Amount', 
    sum(service_amount) as 'Service Amount', 
    sum(sr_amount) as 'SR Amount',
    sum(other_amount) as 'WO Amount',
    sum(insr_amount) as 'Total Ins Surch',
    sum(ensr_amount) as 'Total Energy Surch',
    sum(sales_tax_amount) as 'Total Sales Tax',
    sum(total_amount+insr_amount+ensr_amount+sales_tax_amount) as 'Total Amount'
    ,cust.customer_id
    ,cust.cust_name
    ,cust.cust_city
    ,cust.cust_state
    ,invoice_code as invoice_code
    , NULL
    , NULL
    , rt.invoice_date
    from #report_temp rt
    inner join company c on rt.company_id = c.company_id
    inner join profitcenter pc on rt.company_id = pc.company_id and rt.profit_ctr_id = pc.profit_ctr_id
    inner join customer cust on rt.customer_id = cust.customer_id
    -- where State_name = 'Michigan'
    group by 	rt.company_id,
	rt.profit_ctr_id,
	rt.company_id, rt.profit_ctr_id,company_name, profit_ctr_name, state_name,city_name, generator_id, rt.gen_generator_name, rt.epa_id
    ,cust.customer_id
    ,cust.cust_name
    ,cust.cust_city
    ,cust.cust_state
    ,rt.invoice_code
    ,rt.invoice_date
    order by rt.company_id, rt.profit_ctr_id, rt.State_name,rt.city_name,rt.invoice_code  
END

if @report_type = 'R' BEGIN -- Raw (No Sum, No Group.)
    -----------------------------------------------
    --6
    -----------------------------------------------
    insert #output
    select
	rt.company_id,
	rt.profit_ctr_id,
    Convert(varchar(2),rt.company_id)+'-'+convert(varchar(2),rt.profit_ctr_id) as 'Facility',
    ISNull(state_name,'* Unknown') as 'State', 
    ISNull(city_name,'* Unknown') as 'City',
    generator_id as 'Generator ID',
    ISNull(rt.gen_generator_name, '* Unknown') as 'Generator',
    ISNull(rt.epa_id, '* Unknown') as 'Generator EPA ID',
    sum(disposal_amount) as 'Disposal Amount', 
    sum(service_amount) as 'Service Amount', 
    sum(sr_amount) as 'SR Amount',
    sum(other_amount) as 'WO Amount',
    sum(insr_amount) as 'Total Ins Surch',
    sum(ensr_amount) as 'Total Energy Surch',
    sum(sales_tax_amount) as 'Total Sales Tax',
    sum(total_amount+insr_amount+ensr_amount+sales_tax_amount) as 'Total Amount'
    ,cust.customer_id
    ,cust.cust_name
    ,cust.cust_city
    ,cust.cust_state
    ,invoice_code as invoice_code
    , trans_source
    , receipt_id
    , rt.invoice_date
    from #report_temp rt
    inner join company c on rt.company_id = c.company_id
    inner join profitcenter pc on rt.company_id = pc.company_id and rt.profit_ctr_id = pc.profit_ctr_id
    inner join customer cust on rt.customer_id = cust.customer_id
    -- where State_name = 'Michigan'
    group by 	rt.company_id,
	rt.profit_ctr_id,
	rt.company_id, rt.profit_ctr_id,company_name, profit_ctr_name, state_name,city_name, generator_id, rt.gen_generator_name, rt.epa_id
    ,cust.customer_id
    ,cust.cust_name
    ,cust.cust_city
    ,cust.cust_state
    ,rt.invoice_code
    ,rt.trans_source
    , rt.receipt_id
    , rt.invoice_date
    order by rt.company_id, rt.profit_ctr_id, rt.State_name,rt.city_name,rt.invoice_code  
END

set nocount off
select 
company_id,
profit_ctr_id,
Facility,
State,
City,
[Generator ID],
Generator,
[Generator EPA ID]	,
[Disposal Amount]	,
[Service Amount]	,
[SR Amount]		,
[WO Amount]		,
[Total Ins Surch],	
[Total Energy Surch],
[Total Sales Tax]	,
[Total Amount]	,
customer_id	,
cust_name	,
cust_city	,
cust_state	,
invoice		
    , case trans_source
		when 'R' then 'Receipt'
		when 'W' then 'Work Order'
		when 'O' then 'Retail Order'
		else trans_source
	end as trans_source
, receipt_id
, invoice_date
from #output order by company_id, profit_ctr_id, state, city    


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_customer_generator_revenue] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_customer_generator_revenue] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_customer_generator_revenue] TO [EQAI]
    AS [dbo];

