CREATE PROCEDURE sp_eqip_retail_stop_notes
    @customer_id_list   varchar(max),           -- Comma Separated Customer ID List - what customers to include
    @service_date_from  datetime,    -- Beginning Start Date
    @service_date_to	datetime,    -- Ending Start Date
    @trip_id_list		varchar(max),
    @status_criteria    varchar(200) = NULL,
	@user_code			varchar(20),
	@permission_id		int,
    @debug              int = 0            -- 0 or 1 for no debug/debug mode
AS
/* ***************************************************************************************************
sp_eqip_retail_stop_notes:

Info:
    Returns the data for Trip Question Notes.  Copied & Modified from sp_reports_workorders.
    LOAD TO PLT_AI

Examples:

	sp_eqip_retail_stop_notes
		@customer_id_list   = '12113',
		@service_date_from  = '1/1/2010',    -- Beginning Start Date
		@service_date_to	= '5/1/2013',    -- Ending Start Date
		@trip_id_list		= '5604, asdf',
		@status_criteria    = NULL,
		@user_code			= 'JONATHAN',
		@permission_id		= 189,
		@debug              = 0            -- 0 or 1 for no debug/debug mode
	
    
History:
    08/14/2015 JPB  Created
	09/03/2015 JPB	Added Generator columns

*************************************************************************************************** */

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



IF LEN(@status_criteria) = 0 Or @status_criteria IS NULL 
BEGIN
    set @status_criteria = 'Invoiced,Declined,Complete,In Process,Scheduled/Confirmed,Scheduled,Unavailable'
END

declare @starttime datetime
set @starttime = getdate()
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Start' as description

if @service_date_to >  '1/1/1900' set @service_date_to = @service_date_to + 0.99999

-- Customer IDs:
    create table #Customer_id_list (customer_id int)
    if datalength((@customer_id_list)) > 0 begin
        Insert #Customer_id_list
        select convert(int, row)
        from dbo.fn_SplitXsvText(',', 0, @customer_id_list)
        where isnull(row, '') <> ''
    end


-- Status Criteria Filter
    create table #status_filter (status_filter varchar(50))
    if datalength((@status_criteria)) > 0 begin
        Insert #status_filter
        select rtrim(left(row, 50))
        from dbo.fn_SplitXsvText(',', 1, @status_criteria)
        where isnull(row, '') <> ''
    end
    

-- Trip IDs:
	set @trip_id_list = replace(@trip_id_list, ' ', ',')
    create table #trip_id_list (trip_id int)
    if datalength((isnull(@trip_id_list, ''))) > 0 begin
        Insert #trip_id_list
        select convert(int, row)
        from dbo.fn_SplitXsvText(',', 0, @trip_id_list)
        where isnull(row, '') <> ''
        and isnumeric(row) = 1
    end

    
create table #access_filter (
    company_id int, 
    profit_ctr_id int, 
    workorder_id int, 
    billing_status_info varchar(20)
)

declare @sql varchar(max) = '', @where varchar(max) = ''

set @sql = '
    insert #access_filter
        SELECT w2.company_id, 
        w2.profit_ctr_id, 
        w2.workorder_id, 
        NULL
    from workorderheader w2
    join #profit_center_filter pcf
		on w2.company_id = pcf.company_id
		and w2.profit_ctr_id = pcf.profit_ctr_id
    join #Secured_Customer sc
		on w2.customer_id = sc.customer_id
    left join WorkOrderStop wos
		on w2.workorder_id = wos.workorder_id
		and w2.company_id = wos.company_id 
		and w2.profit_ctr_id = wos.profit_ctr_id
		and wos.stop_sequence_id = 1
    '

    -- Only include inner joins to these tables if they have data (= a restriction) to add to the query...
    if (select count(*) from #customer_id_list) > 0
    begin
        set @sql = @sql + ' inner join #customer_id_list cil on w2.customer_id = cil.customer_id '
    end

    -- Only include inner joins to these tables if they have data (= a restriction) to add to the query...
    if (select count(*) from #trip_id_list) > 0
    begin
        set @sql = @sql + ' inner join #trip_id_list til on w2.trip_id = til.trip_id '
    end


    -- These conditions apply to both versions (associate/non-associate) of the query:
    
    set @where = @where + '
        WHERE 1=1 /* where-slug */
        AND w2.workorder_status NOT IN (''V'')
    '
    
    if @service_date_from >  '1/1/1900'
        set @where = replace(@where, '/* where-slug */', ' AND coalesce(wos.date_act_arrive, wos.date_act_depart, w2.start_date) >= ''' + convert(varchar(20), @service_date_from) + ''' /* where-slug */')

    if @service_date_to >  '1/1/1900'
        set @where = replace(@where, '/* where-slug */', ' AND coalesce(wos.date_act_arrive, wos.date_act_depart, w2.start_date) <= ''' + convert(varchar(20), @service_date_to) + ''' /* where-slug */')

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Before filling #accessfilter' as description

    -- Execute the sql that popoulates the #access_filter table.
    if @debug > 0 select @sql + @where

    exec(@sql + @where)
    
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After filling #accessfilter' as description

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Before Updating #accessfilter' as description
    -- set the workorder status for the selected items
    UPDATE f SET f.billing_status_info = CASE 
        WHEN b.status_code = 'I' THEN 'Invoiced'
        WHEN wos.decline_id IN (2,3) THEN 'Declined'
        WHEN (getdate() > wos.date_act_arrive) or (getdate() > h.end_date) THEN 'Complete'
        WHEN getdate() BETWEEN h.start_date and h.end_date THEN 'In Process'
        WHEN getdate() < h.start_date AND wos.confirmation_date IS NOT NULL THEN 'Scheduled/Confirmed'
        WHEN getdate() < h.start_date THEN 'Scheduled'
        ELSE 'Unavailable'
    END  
        FROM #access_filter f
        INNER JOIN workorderheader h 
                on h.workorder_id = f.workorder_id 
                and h.company_id = f.company_id 
                and h.profit_ctr_id = f.profit_ctr_id
        INNER JOIN WorkOrderStop wos ON 
			h.company_id = wos.company_id
			AND h.profit_ctr_id = wos.profit_ctr_id
			AND h.workorder_id = wos.workorder_id
			--AND wos.stop_sequence_id = 1
        LEFT OUTER join billing b 
            on b.receipt_id = h.workorder_id 
            and b.company_id = h.company_id 
            and b.profit_ctr_id = h.profit_ctr_id 
            and b.trans_source = 'W'


if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Updating #accessfilter' as description
    
exec('create index af_idx on #access_filter (workorder_id, company_id, profit_ctr_id)')

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After #accessfilter index' as description



SELECT DISTINCT
	h.company_id, 
	h.profit_ctr_id,
	h.workorder_id,
    af.billing_status_info as status,
    dbo.fn_web_profitctr_display_name(h.company_id, h.profit_ctr_id) as profit_ctr_name,
    h.trip_id,
	h.customer_id,
    c.cust_name,
    g.generator_name,
    g.epa_id,
    g.site_code,
    g.generator_state,
    g.generator_city,
	g.generator_pickup_schedule_type,
	g.generator_facility_size,
	g.generator_facility_date_opened,
	g.generator_facility_date_closed,
	g.generator_market_code,
	g.generator_region_code,
	g.generator_annual_sales,
	g.generator_business_unit,
	g.generator_division,
    th.driver_name,
    h.release_code,
    h.purchase_order,
    wos.pickup_contact,
    wos.pickup_contact_title,
    CASE 
        WHEN wos.date_act_arrive IS NULL AND af.billing_status_info IN('Complete','Invoiced') THEN h.end_date
        ELSE wos.date_act_arrive
    END as trip_act_arrive,
    CASE 
        WHEN qc.category_desc IS NULL THEN 'Uncategorized'
        ELSE qc.category_desc
    END AS category_name,
    tq.question_text,
    tq.answer_text
FROM
    #access_filter af
    inner join #status_filter sf ON af.billing_status_info = sf.status_filter -- this is ok, it always has values.
    inner join workorderheader h on h.workorder_id = af.workorder_id and h.company_id = af.company_id and h.profit_ctr_id = af.profit_ctr_id
    INNER JOIN WorkOrderStop wos ON h.workorder_ID = wos.workorder_id
		AND h.company_id = wos.company_id
		AND h.profit_ctr_ID = wos.profit_ctr_id
    INNER JOIN TripHeader th ON th.trip_id = h.trip_id and h.company_id = th.company_id AND h.profit_ctr_id = th.profit_ctr_id
    INNER JOIN TripQuestion tq ON tq.workorder_id = h.workorder_ID
        AND tq.company_id = h.company_id
        AND tq.profit_ctr_id = h.profit_ctr_id
        AND tq.view_on_web_flag = 'T'
    LEFT OUTER JOIN QuestionCategory qc ON tq.question_category_id = qc.question_category_id
    inner join customer c on h.customer_id = c.customer_id
    LEFT OUTER JOIN generator g on h.generator_id = g.generator_id
WHERE 
    h.workorder_status NOT IN ('V')
ORDER BY h.company_id, h.profit_ctr_id, h.customer_id, h.workorder_id desc


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_retail_stop_notes] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_retail_stop_notes] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_retail_stop_notes] TO [EQAI]
    AS [dbo];

