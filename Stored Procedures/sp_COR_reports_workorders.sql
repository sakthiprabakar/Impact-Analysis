--    DROP PROCEDURE sp_COR_reports_workorders
GO

CREATE PROCEDURE sp_COR_reports_workorders
	@web_userid			varchar(100) = ''
	, @customer_id_list	varchar(max) = ''	-- Comma Separated Customer ID List - what customers to include
	, @generator_id_list	varchar(max) = ''	-- Comma Separated Generator ID List - what generators to include
    , @service_start_date   datetime    -- Beginning Start Date
    , @service_end_date     datetime    -- Beginning End Date

AS
/* ***************************************************************************************************
sp_COR_reports_workorders:

Info:
    Returns the data for Work Orders.  The same SP is used for the list and details, just different params
    LOAD TO PLT_AI

Examples:
    
History:
    
Sample:
EXEC sp_COR_reports_workorders
	@web_userid			= 'court_c'
	, @customer_id_list	= '18433'	-- Comma Separated Customer ID List - what customers to include
	, @generator_id_list	= ''	-- Comma Separated Generator ID List - what generators to include
    , @service_start_date   = '1/1/2019'
    , @service_end_date     = '12/31/2019'
    

*************************************************************************************************** */

/*
-- Debugging:
declare
	@web_userid			varchar(100) = 'maverick'
	, @customer_id_list	varchar(max) = '15622'	-- Comma Separated Customer ID List - what customers to include
	, @generator_id_list varchar(max)	= ''	-- Comma Separated Generator ID List - what generators to include
    , @service_start_date datetime  = '1/1/2019'
    , @service_end_date   datetime  = '12/31/2019'
*/

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

declare @1yago datetime
set @1yago = dateadd(yyyy, -1, getdate())

declare 
	@i_web_userid			varchar(100) = isnull(@web_userid, '')
	, @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
	, @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
    , @i_service_start_date   datetime    = isnull(@service_start_date, @1yago)
    , @i_service_end_date     datetime    = isnull(@service_end_date, getdate())
    , @i_contact_id int
    , @status_criteria varchar(max)
    , @debug int = 0

select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid
	
IF LEN(@status_criteria) = 0 Or @status_criteria IS NULL 
BEGIN
    set @status_criteria = 'Invoiced,Declined,Complete,In Process,Scheduled/Confirmed,Scheduled,Unavailable'
END

if datepart(hh, @i_service_end_date) = 0 set @i_service_end_date =@i_service_end_date + 0.99999

declare @starttime datetime
set @starttime = getdate()
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Start' as description

-- Customer IDs:
    declare @customer_id_table table (customer_id int)
    if datalength((@customer_id_list)) > 0 begin
        Insert @customer_id_table
        select convert(int, row)
        from dbo.fn_SplitXsvText(',', 0, @customer_id_list)
        where isnull(row, '') <> ''
    end

-- Generator IDs:
    declare @generator_id_table table (generator_id int)
    if datalength((@generator_id_list)) > 0 begin
        Insert @generator_id_table
        select convert(int, row)
        from dbo.fn_SplitXsvText(',', 0, @generator_id_list)
        where isnull(row, '') <> ''
    end

    -- Status Criteria Filter
    declare @status_filter table (status_filter varchar(50))
    if datalength((@status_criteria)) > 0 begin
        Insert @status_filter
        select rtrim(left(row, 50))
        from dbo.fn_SplitXsvText(',', 1, @status_criteria)
        where isnull(row, '') <> ''
    end

declare @foo table (
	contact_id		int,
	workorder_id	int,
	company_id		int,
	profit_ctr_id	int,
	start_date		datetime,
	service_date	datetime,
	requested_date	datetime,
	scheduled_date	datetime,
	report_status	varchar(20),
	invoice_date	datetime,
	customer_id		int,
	generator_id	int,
	prices			bit,
	billing_status_info varchar(20),
	trip_id			int,
	trip_sequence_id int
)

insert @foo
(
	contact_id
	, workorder_id
	, company_id
	, profit_ctr_id
	, start_date
	, service_date
	, requested_date
	, scheduled_date
	, report_status
	, invoice_date
	, customer_id
	, generator_id
	, prices
)
select 
	b.contact_id
	, b.workorder_id
	, b.company_id
	, b.profit_ctr_id
	, b.start_date
	, b.service_date
	, b.requested_date
	, b.scheduled_date
	, b.report_status
	, b.invoice_date
	, b.customer_id
	, b.generator_id
	, b.prices
from ContactCORWorkorderHeaderBucket b
inner join company co on b.company_id = co.company_id
inner join profitcenter p on b.company_id = p.company_id and b.profit_ctr_id = p.profit_ctr_id
WHERE contact_id = @i_contact_id
and b.service_date between @i_service_start_date and @i_service_end_date
and (
	@i_customer_id_list = ''
	or
	b.customer_id in (select customer_id from @customer_id_table)
)
and (
	@i_generator_id_list = ''
	or
	b.generator_id in (select generator_id from @generator_id_table)
)
AND co.view_on_web = 'T' 
AND p.status = 'A' 
AND p.view_on_web IN ('C', 'P') 
AND p.view_workorders_on_web = 'T' 


-- set the workorder status for the selected items
UPDATE @foo
SET f.billing_status_info = CASE 
	WHEN h.workorder_status = 'V' then 'Void'
    WHEN f.invoice_date is not null THEN 'Invoiced'
    WHEN wos.decline_id IN (2,3) THEN 'Declined'
    WHEN (getdate() > wos.date_act_arrive) or (getdate() > h.end_date) THEN 'Complete'
    WHEN getdate() BETWEEN h.start_date and h.end_date THEN 'In Process'
    WHEN getdate() < h.start_date AND wos.confirmation_date IS NOT NULL THEN 'Scheduled/Confirmed'
    WHEN getdate() < h.start_date THEN 'Scheduled'
    ELSE 'Unavailable'
END  
	, trip_id = h.trip_id
	, trip_sequence_id = h.trip_sequence_id

    FROM @foo f
    INNER JOIN workorderheader h 
            on h.workorder_id = f.workorder_id 
            and h.company_id = f.company_id 
            and h.profit_ctr_id = f.profit_ctr_id
    INNER JOIN WorkOrderStop wos ON 
		h.company_id = wos.company_id
		AND h.profit_ctr_id = wos.profit_ctr_id
		AND h.workorder_id = wos.workorder_id

-- SELECT  *  FROM    @foo
--1s or less to here with 23k rows.  Nice.

if object_id('tempdb..#access_filter') is not null drop table #access_filter
if object_id('tempdb..#Work_WorkorderListResult') is not null drop table #Work_WorkorderListResult
if object_id('tempdb..#detail_selection') is not null drop table #detail_selection
if object_id('tempdb..#detail_filter') is not null drop table #detail_filter
if object_id('tempdb..#Work_WorkorderDetailResult') is not null drop table #Work_WorkorderDetailResult


-- Query (gets real WorkroderHeader data, inner joined to #access_filter to limit the rows the user is allowed to see):
    --INSERT #Work_WorkorderListResult (
    --    customer_id,
    --    cust_name,
    --    workorder_id,
    --    company_id,
    --    profit_ctr_id,
    --    project_code,
    --    project_name,
    --    comment_1,
    --    comment_2,
    --    comment_3,
    --    comment_4,
    --    comment_5,
    --    generator_id,
    --    generator_name,
    --    epa_id,
    --    status,
    --    profit_ctr_name,
    --    show_prices,
    --    submitted_flag,
    --    invoice_code,
    --    invoice_date,
    --    start_date,
    --    end_date,
    --    generator_site_code,
    --    generator_state,
    --    generator_city,
    --    release_code,
    --    purchase_order,
    --    is_billed,
    --    trip_est_arrive,
    --    trip_act_arrive,
    --    confirmation_date,
    --    schedule_contact,
    --    schedule_contact_title,
    --    pickup_contact_title,
    --    pickup_contact,
    --    decline_id,
    --    waste_flag,
    --    driver_name,
    --    session_key,
    --    session_added,
    --    has_notes
    --)
    SELECT DISTINCT
        af.customer_id,
        c.cust_name,
        af.workorder_id,
        af.company_id,
        af.profit_ctr_id,
        h.project_code,
        h.project_name,
        h.invoice_comment_1 as comment_1,
        h.invoice_comment_2 as comment_2,
        h.invoice_comment_3 as comment_3,
        h.invoice_comment_4 as comment_4,
        h.invoice_comment_5 as comment_5,
        af.generator_id,
        g.generator_name,
        g.epa_id,
        af.billing_status_info as status,
        dbo.fn_web_profitctr_display_name(af.company_id, af.profit_ctr_id) as profit_ctr_name,
        case af.prices when 1 then 'T' else 'F' end as show_prices,
        h.submitted_flag,
        b.invoice_code,
        b.invoice_date,
        h.start_date,
        h.end_date,
        g.site_code,
        g.generator_state,
        g.generator_city,
        h.release_code,
        h.purchase_order,
        case when isnull(b.status_code, 'X') = 'I' then 'T' else 'F' end as is_billed,
        CASE 
            WHEN wos.date_est_arrive IS NULL THEN h.start_date
            ELSE wos.date_est_arrive
        END as trip_est_arrive,
        CASE 
            WHEN wos.date_act_arrive IS NULL AND af.billing_status_info IN('Complete','Invoiced') THEN h.end_date
            ELSE wos.date_act_arrive
        END as trip_act_arrive,
        wos.confirmation_date,
        wos.schedule_contact,
        wos.schedule_contact_title,
        wos.pickup_contact_title,
        wos.pickup_contact,
        wos.decline_id,
        wos.waste_flag,
        th.driver_name,
        --@session_key as session_key,
        getdate() as session_added,
        has_notes = CASE   
            WHEN h.workorder_ID = tq.workorder_id AND h.company_id = tq.company_id AND h.profit_ctr_id = tq.profit_ctr_id THEN 'T'  
            ELSE 'F'  
        END  
	INTO #Work_WorkorderListResult
    FROM
        @foo af
        inner join workorderheader h on h.workorder_id = af.workorder_id and h.company_id = af.company_id and h.profit_ctr_id = af.profit_ctr_id
        INNER JOIN WorkOrderStop wos ON wos.workorder_ID = af.workorder_id
			AND wos.company_id = af.company_id
			AND wos.profit_ctr_ID = af.profit_ctr_id
        inner join customer c on c.customer_id = af.customer_id
        LEFT OUTER JOIN generator g on g.generator_id = af.generator_id
        LEFT OUTER join billing b on b.receipt_id = af.workorder_id and b.company_id = af.company_id and b.profit_ctr_id = af.profit_ctr_id and b.trans_source = 'W'
        LEFT OUTER JOIN TripHeader th ON th.trip_id = h.trip_id and th.company_id = af.company_id AND th.profit_ctr_id = af.profit_ctr_id
        LEFT OUTER JOIN TripQuestion tq ON tq.workorder_id = af.workorder_ID
			AND tq.company_id = af.company_id
			AND tq.profit_ctr_id = af.profit_ctr_ID
			AND tq.view_on_web_flag = 'T'

-- 4s here.  3s for that last bit.  Useful?

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Work_WorkorderListResult insert' as description


        /* 
            Work Order On Trip Info:
        */
				SELECT 
					af.company_id,
					af.profit_ctr_id,
					af.workorder_id,
					d.resource_type,
					d.sequence_id
					, 1 as query_type
				into #detail_selection
				from
					@foo af
					INNER JOIN workorderdetail d on d.workorder_id = af.workorder_id and d.company_id = af.company_id and d.profit_ctr_id = af.profit_ctr_id and d.resource_type = 'D'
					INNER JOIN WorkOrderDetailUnit wodu ON d.workorder_id = wodu.workorder_id AND d.company_id = wodu.company_id AND d.profit_ctr_id = wodu.profit_ctr_id AND d.sequence_id = wodu.sequence_id AND wodu.billing_flag = 'T'		                
					INNER JOIN TripHeader th on th.trip_id = af.trip_id and th.trip_status NOT IN ( 'V')
					INNER JOIN TSDF tsdf on d.TSDF_code = tsdf.TSDF_code and tsdf.TSDF_status = 'A' and tsdf.eq_flag = 'T'
				WHERE ISNULL(af.trip_id, 0) > 0
					AND ISNULL(af.trip_sequence_id, 0) > 0
					AND d.bill_rate = -1
					AND ISNULL(wodu.quantity, 0) > 0

				UNION
        /* 
            Un-invoiced Workorders not in the "Q4" Trip select above:
            (should report status only, no details)
            And has no trip (8/24/2016)
        */          
				SELECT
					af.company_id,
					af.profit_ctr_id,
					af.workorder_id,
					NULL as resource_type,
					NULL as sequence_id
					, 2 as query_type
				from
					@foo af
				WHERE af.invoice_date is null
					AND Not exists (
						select af.workorder_id
						from
							@foo af2
							INNER JOIN workorderdetail d2 on d2.workorder_id = af2.workorder_id and d2.company_id = af2.company_id and d2.profit_ctr_id = af2.profit_ctr_id
								AND d2.resource_type = 'D'
							INNER JOIN WorkOrderDetailUnit wodu2 ON	d2.workorder_id = wodu2.workorder_id AND d2.company_id = wodu2.company_id AND d2.profit_ctr_id = wodu2.profit_ctr_id AND d2.sequence_id = wodu2.sequence_id AND wodu2.billing_flag = 'T'		                
							INNER JOIN TripHeader th2 on th2.trip_id = af2.trip_id AND th2.trip_status NOT IN ('C', 'V')
							INNER JOIN TSDF tsdf2 on d2.TSDF_code = tsdf2.TSDF_code and tsdf2.TSDF_status = 'A' and tsdf2.eq_flag = 'T'
						WHERE 1=1 -- af.session_key = @session_key
							AND ISNULL(af2.trip_id, 0) > 0
							AND ISNULL(af2.trip_sequence_id, 0) > 0
							AND d2.bill_rate = -1
							AND ISNULL(wodu2.quantity, 0) > 0
							AND af2.workorder_id = af.workorder_id
							and af2.company_id = af.company_id
							and af2.profit_ctr_id = af.profit_ctr_id
					)
					AND ISNULL(af.trip_id, 0) = 0


		        UNION
        /* 
            EQ BillingLink-ed (Billed Receipt) records: 
        */
				SELECT 
					af.company_id,
					af.profit_ctr_id,
					af.workorder_id,
					d.resource_type,
					d.sequence_id
					, 4 as query_type
				from
					@foo af
					INNER JOIN workorderdetail d on d.workorder_id = af.workorder_id and d.company_id = af.company_id and d.profit_ctr_id = af.profit_ctr_id
						AND d.resource_type = 'D'
					INNER JOIN BillingLinkLookup bl on bl.source_id = af.workorder_id and bl.source_company_id = af.company_id and bl.source_profit_ctr_id = af.profit_ctr_ID
					--INNER JOIN Receipt r on r.receipt_id = bl.receipt_id and r.company_id = bl.company_id and r.profit_ctr_id = bl.profit_ctr_id
					--	and r.company_id = d.profile_company_id
					--	and r.profit_ctr_id = d.profile_profit_ctr_id
					--	and r.approval_code = d.tsdf_approval_code
				WHERE 
					af.invoice_date is not null

				UNION
        /* 
            EQ BillingLink-ed (UnBilled Receipt) records: 
        */
				SELECT

					af.company_id,
					af.profit_ctr_id,
					af.workorder_id,
					null as resource_type,
					null as sequence_id
					, 3 as query_yype
				from
					@foo af
					INNER JOIN BillingLinkLookup bl on bl.source_id = af.workorder_id and bl.source_company_id = af.company_id and bl.source_profit_ctr_id = af.profit_ctr_ID
					INNER JOIN ContactCORReceiptBucket crb on crb.contact_id = @i_contact_id and crb.receipt_id = bl.receipt_id and bl.company_id = bl.company_id and crb.profit_ctr_id = bl.profit_ctr_id
				WHERE af.invoice_date is not null
					AND crb.invoice_date IS null

				UNION 
        /*
            Inserts all WorkOrderDetail items for an INVOICED work order in the list -- DISPOSAL LINES
        */ 
				SELECT
					af.company_id,
					af.profit_ctr_id,
					af.workorder_id,
					d.resource_type,
					d.sequence_id
					, 5 as query_type
				from
					@foo af
					INNER JOIN workorderdetail d on d.workorder_id = af.workorder_id and d.company_id = af.company_id and d.profit_ctr_id = af.profit_ctr_id
						AND d.resource_type = 'D'
					INNER JOIN WorkOrderDetailUnit wodu ON
						d.workorder_id = wodu.workorder_id
						AND d.company_id = wodu.company_id
						AND d.profit_ctr_id = wodu.profit_ctr_id
						AND d.sequence_id = wodu.sequence_id
						AND wodu.billing_flag = 'T'		    
				WHERE af.invoice_date is not null
				UNION
        /*
            Inserts all WorkOrderDetail items for an INVOICED work order in the list -- SERVICE LINES
        */
				SELECT
					af.company_id,
					af.profit_ctr_id,
					af.workorder_id,
					d.resource_type,
					d.sequence_id
					, 5 as query_type
				from
					@foo af
					INNER JOIN workorderdetail d on d.workorder_id = af.workorder_id and d.company_id = af.company_id and d.profit_ctr_id = af.profit_ctr_id
						AND d.resource_type <> 'D'
				WHERE af.invoice_date is not null

select company_id, profit_ctr_id, workorder_id, resource_type, sequence_id, max(query_type) query_type
into #detail_filter
from #detail_selection
group by company_id, profit_ctr_id, workorder_id, resource_type, sequence_id


if @debug > 3 select '#detail_filter', * from #detail_filter

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After #Detail_Selection insert' as description


        --INSERT Work_WorkorderDetailResult (
        --    company_id,
        --    profit_ctr_id,
        --    receipt_id,
        --    resource_type,
        --    sequence_id,
        --    tsdf_code,
        --    approval_code,
        --    approval_id,
        --    approval_company_id,
        --    approval_profit_ctr_id,
        --    manifest,
        --    manifest_line,
        --    bill_unit_code,
        --    bill_unit_desc,
        --    invoice_code,
        --    invoice_date,
        --    quantity,
        --    price,
        --    total_extended_amt,
        --    workorder_resource_item,
        --    purchase_order,
        --    is_billed,
        --    release_code,
        --    service_desc_1,
        --    service_desc_2,
        --    show_prices,
        --    generator_site_code,
        --    session_key,
        --    session_added,
        --    query_type
        --)
        /* 
            Work Order On Trip Info:
        */
        SELECT DISTINCT
            af.company_id,
            af.profit_ctr_id,
            af.workorder_id,
            d.resource_type,
            d.sequence_id,
            d.tsdf_code,
            d.tsdf_approval_code,
            coalesce(d.profile_id, d.tsdf_approval_id) approval_id,
            coalesce(d.profile_company_id, af.company_id) approval_company_id,
            coalesce(d.profile_profit_ctr_id, af.profit_ctr_id) approval_profit_ctr_id,
            d.manifest,
            d.manifest_line,
			(
				SELECT 
					bill_unit_code
					FROM WorkOrderDetailUnit a
					WHERE a.workorder_id = wodu.workorder_id
					AND a.company_id = wodu.company_id
					AND a.profit_ctr_id = wodu.profit_ctr_id
					AND a.sequence_id = wodu.sequence_id
					AND a.manifest_flag = 'T'
			) as bill_unit_code,
			(
				SELECT 
					bill_unit_desc
					FROM WorkOrderDetailUnit a
					JOIN BillUnit bu on a.bill_unit_code = bu.bill_unit_code
					WHERE a.workorder_id = wodu.workorder_id
					AND a.company_id = wodu.company_id
					AND a.profit_ctr_id = wodu.profit_ctr_id
					AND a.sequence_id = wodu.sequence_id
					AND a.manifest_flag = 'T'
			) as bill_unit_desc,
            convert(varchar(20), null) as invoice_code,
            convert(datetime, null) as invoice_date,
            --d.pounds,
            --0 as pounds,
			(
				SELECT 
					quantity
					FROM WorkOrderDetailUnit a
					WHERE a.workorder_id = wodu.workorder_id
					AND a.company_id = wodu.company_id
					AND a.profit_ctr_id = wodu.profit_ctr_id
					AND a.sequence_id = wodu.sequence_id
					AND a.manifest_flag = 'T'
			) as pounds, -- workorder detail pounds
            convert(money, null) as price,
            convert(money, null) as total_extended_amt,
            d.resource_class_code,
            af.purchase_order,
            af.is_billed,
            af.release_code,
            d.description as service_desc_1,
            d.description_2 as service_desc_2,
            'F' as show_prices,
            g.site_code,
--            @session_key as session_key,
--            GETDATE() as session_added,
			convert(varchar(255), 'Workorder-On Trip') as query_type
        INTO #Work_WorkorderDetailResult
        from
            #Work_WorkorderListResult af
			INNER JOIN #detail_filter ds on af.workorder_id = ds.workorder_id and af.company_id = ds.company_id and af.profit_ctr_id = ds.profit_ctr_id and ds.query_type = 1
            INNER JOIN WorkorderHeader h on h.workorder_id = af.workorder_id and h.company_id = af.company_id and h.profit_ctr_id = af.profit_ctr_id
            INNER JOIN workorderdetail d on d.workorder_id = af.workorder_id and d.company_id = af.company_id and d.profit_ctr_id = af.profit_ctr_id
				and d.resource_type = ds.resource_type and d.sequence_id = ds.sequence_id
			INNER JOIN WorkOrderDetailUnit wodu ON d.workorder_id = wodu.workorder_id AND d.company_id = wodu.company_id AND d.profit_ctr_id = wodu.profit_ctr_id AND d.sequence_id = wodu.sequence_id AND wodu.billing_flag = 'T'		                
            INNER JOIN TripHeader th on h.trip_id = th.trip_id
            INNER JOIN TSDF tsdf on d.TSDF_code = tsdf.TSDF_code and tsdf.TSDF_status = 'A' and tsdf.eq_flag = 'T'
            INNER JOIN  billunit u on wodu.bill_unit_code = u.bill_unit_code
            LEFT JOIN Generator g on af.generator_id = g.generator_id
        WHERE 1=1 -- af.session_key = @session_key
            AND ISNULL(h.trip_id, 0) > 0
            AND ISNULL(h.trip_sequence_id, 0) > 0
			-- AND th.trip_status NOT IN ('C', 'V')
			AND th.trip_status NOT IN ( 'V') -- 8/24/2016
            AND d.bill_rate = -1
            AND ISNULL(wodu.quantity, 0) > 0
        UNION 
        /* 
            Un-invoiced Workorders not in the "Q4" Trip select above:
            (should report status only, no details)
        */          
        SELECT
            af.company_id,
            af.profit_ctr_id,
            af.workorder_id,
            NULL as resource_type,
            NULL as sequence_id, 
            null as tsdf_code,
            null as approval_code,
            null as approval_id,
            null as approval_company_id,
            null as approval_profit_ctr_id,
            null as manifest,
            null as manifest_line,
            NULL as bill_unit_code,
            NULL as bill_unit_desc,
            NULL as invoice_code,
            NULL as invoice_date,
            NULL as quantity,
            NULL as price,
            NULL as total_extended_amt,
            NULL as workorder_resource_item,
            af.purchase_order,
            af.is_billed,
            af.release_code,
            NULL as service_desc_1,
            NULL as service_desc_2,
            af.show_prices,
            g.site_code as site_code,
            -- @session_key as session_key,
            -- GETDATE() as session_added,
            'Unbilled Workorder-Non Trip' as query_type
        from
            #Work_WorkorderListResult af
			INNER JOIN #detail_filter ds on af.workorder_id = ds.workorder_id and af.company_id = ds.company_id and af.profit_ctr_id = ds.profit_ctr_id and ds.query_type = 2
			INNER JOIN WorkorderHeader h on h.workorder_id = af.workorder_id and h.company_id = af.company_id and h.profit_ctr_id = af.profit_ctr_id
			LEFT JOIN Generator g on af.generator_id = g.generator_id
            WHERE 1=1 -- af.session_key = @session_key
                AND af.is_billed = 'F'
                AND Not exists (
                    select af.workorder_id
                    from
                        #Work_WorkorderListResult af2
                        INNER JOIN WorkorderHeader h2 on h2.workorder_id = af2.workorder_id and h2.company_id = af2.company_id and h2.profit_ctr_id = af2.profit_ctr_id
                        INNER JOIN workorderdetail d2 on d2.workorder_id = af2.workorder_id and d2.company_id = af2.company_id and d2.profit_ctr_id = af2.profit_ctr_id
						INNER JOIN WorkOrderDetailUnit wodu2 ON	d2.workorder_id = wodu2.workorder_id AND d2.company_id = wodu2.company_id AND d2.profit_ctr_id = wodu2.profit_ctr_id AND d2.sequence_id = wodu2.sequence_id AND wodu2.billing_flag = 'T'		                
                        INNER JOIN TripHeader th2 on h2.trip_id = th2.trip_id
                        INNER JOIN TSDF tsdf2 on d2.TSDF_code = tsdf2.TSDF_code and tsdf2.TSDF_status = 'A' and tsdf2.eq_flag = 'T'
                        INNER JOIN  billunit u2 on wodu2.bill_unit_code = u2.bill_unit_code
                    WHERE 1=1 -- af.session_key = @session_key
                        AND ISNULL(h2.trip_id, 0) > 0
                        AND ISNULL(h2.trip_sequence_id, 0) > 0
                        AND th2.trip_status NOT IN ('C', 'V')
                        AND d2.bill_rate = -1
                        AND ISNULL(wodu2.quantity, 0) > 0
                        AND af2.workorder_id = af.workorder_id
                        and af2.company_id = af.company_id
                        and af2.profit_ctr_id = af.profit_ctr_id
                )
				AND ISNULL(h.trip_id, 0) = 0
        UNION 
        /* 
            EQ BillingLink-ed (Billed Receipt) records: 
        */
        SELECT DISTINCT
            af.company_id,
            af.profit_ctr_id,
            af.workorder_id,
            'R' as resource_type,
            r.line_id as sequence_id,
            (select tsdf_code from tsdf where eq_company = r.company_id and eq_profit_ctr = r.profit_ctr_id and tsdf_status = 'A') as tsdf_code,
            r.approval_code,
            r.profile_id as approval_id,
            r.company_id as approval_company_id,
            r.profit_ctr_id as approval_profit_ctr_id,
            r.manifest,
            r.manifest_line,
            br.bill_unit_code,
            u.bill_unit_desc,
            iw.invoice_code,
            iw.invoice_date,
            br.quantity,
            br.price,
            br.total_extended_amt,
            NULL as workorder_resource_item,
            af.purchase_order,
            af.is_billed,
            af.release_code,
            isnull(br.service_desc_1, convert(varchar(max), r.manifest_dot_shipping_name)) as service_desc_1,
            isnull(br.service_desc_2, '') as service_desc_2,
            af.show_prices,
            g.site_code,
            -- @session_key as session_key,
            -- GETDATE() as session_added,
            'Billed Workorder - Billed Receipt' as query_type
        from
            #Work_WorkorderListResult af
			INNER JOIN #detail_filter ds on af.workorder_id = ds.workorder_id and af.company_id = ds.company_id and af.profit_ctr_id = ds.profit_ctr_id and ds.query_type = 4
			INNER JOIN workorderdetail d on d.workorder_id = af.workorder_id and d.company_id = af.company_id and d.profit_ctr_id = af.profit_ctr_id
				and d.resource_type = ds.resource_type and d.sequence_id = ds.sequence_id
            INNER JOIN BillingLinkLookup bl on bl.source_id = af.workorder_id and bl.source_company_id = af.company_id and bl.source_profit_ctr_id = af.profit_ctr_ID
            INNER JOIN Receipt r on bl.receipt_id = r.receipt_id and bl.company_id = r.company_id and bl.profit_ctr_id = r.profit_ctr_id and r.receipt_status <> 'V'
            INNER JOIN  billing bw on bw.receipt_id = af.workorder_id and bw.company_id = af.company_id and bw.profit_ctr_id = af.profit_ctr_id and bw.trans_source = 'W'
            INNER JOIN  invoiceheader iw on iw.invoice_code = bw.invoice_code and iw.status = 'I'
            LEFT OUTER JOIN  generator g ON g.generator_id = r.generator_id
            INNER JOIN  billing br on br.receipt_id = r.receipt_id and br.company_id = r.company_id and br.profit_ctr_id = r.profit_ctr_id and br.line_id = r.line_id
            INNER JOIN  invoiceheader ir on ir.invoice_code = br.invoice_code and ir.status = 'I'
            INNER JOIN  billunit u on br.bill_unit_code = u.bill_unit_code
        WHERE 1=1 -- af.session_key = @session_key
        UNION 
        /* 
            EQ BillingLink-ed (UnBilled Receipt) records: 
        */
        SELECT
            af.company_id,
            af.profit_ctr_id,
            af.workorder_id,
            null as resource_type,
            null as sequence_id,
            (select tsdf_code from tsdf where eq_company = r.company_id and eq_profit_ctr = r.profit_ctr_id and tsdf_status = 'A') as tsdf_code,
            r.approval_code,
            r.profile_id as approval_id,
            r.company_id as approval_company_id,
            r.profit_ctr_id as approval_profit_ctr_id,
            r.manifest,
            r.manifest_line,
            'LBS' as bill_unit_code,
            'Pounds' as bill_unit_desc,
            iw.invoice_code,
            iw.invoice_date,
            r.net_weight as quantity, -- pounds
            NULL as price,
            NULL as total_extended_amt,
            NULL as workorder_resource_item,
            af.purchase_order,
            af.is_billed,
            af.release_code,
            coalesce(convert(varchar(max), r.manifest_dot_shipping_name), p.approval_desc, '') as service_desc_1,
            '' as service_desc_2,
            'F' as show_prices,
            g.site_code,
            -- @session_key as session_key,
            -- GETDATE() as session_added,
            'Billed Workorder - Unbilled Receipt' as query_type
        from
            #Work_WorkorderListResult af
			INNER JOIN #detail_filter ds on af.workorder_id = ds.workorder_id and af.company_id = ds.company_id and af.profit_ctr_id = ds.profit_ctr_id and ds.query_type = 3
            INNER JOIN BillingLinkLookup bl on bl.source_id = af.workorder_id and bl.source_company_id = af.company_id and bl.source_profit_ctr_id = af.profit_ctr_ID
            INNER JOIN Receipt r on bl.receipt_id = r.receipt_id and bl.company_id = r.company_id and bl.profit_ctr_id = r.profit_ctr_id and r.receipt_status <> 'V' and r.fingerpr_status <> 'V'
            INNER JOIN Profile p on r.profile_id = p.profile_id
            INNER JOIN  billing bw on bw.receipt_id = af.workorder_id and bw.company_id = af.company_id and bw.profit_ctr_id = af.profit_ctr_id and bw.trans_source = 'W'
            INNER JOIN  invoiceheader iw on iw.invoice_code = bw.invoice_code and iw.status = 'I'
            LEFT OUTER JOIN  generator g ON g.generator_id = r.generator_id
            INNER JOIN  billunit u on r.bill_unit_code = u.bill_unit_code
        WHERE 1=1 -- af.session_key = @session_key
            AND NOT EXISTS(select receipt_id from Billing where receipt_id = r.receipt_id and company_id = r.company_id and profit_ctr_id = r.profit_ctr_id and line_id = r.line_id)
        UNION
        /*
            Inserts all WorkOrderDetail items for an INVOICED work order in the list -- DISPOSAL LINES
        */ 
        SELECT
            af.company_id,
            af.profit_ctr_id,
            af.workorder_id,
            d.resource_type,
            d.sequence_id,
            d.tsdf_code,
            d.tsdf_approval_code,
            coalesce(d.tsdf_approval_id, d.profile_id) as approval_id,
            coalesce(d.profile_company_id, d.company_id) as approval_company_id,
            coalesce(d.profile_profit_ctr_id, d.profit_ctr_id) as approval_profit_ctr_id,
            d.manifest,
            d.manifest_line,
            wodu.bill_unit_code,
            u.bill_unit_desc,
            i.invoice_code,
            i.invoice_date,
            wodu.quantity,
            case when af.show_prices = 'T' then b.price else null end as price,
            case when af.show_prices = 'T' then b.total_extended_amt else null end as total_extended_amt,
            b.workorder_resource_item,
            af.purchase_order,
            af.is_billed,
            af.release_code,
            isnull(b.service_desc_1, d.description) as service_desc_1,
            isnull(b.service_desc_2, d.description_2) as service_desc_2,
            af.show_prices,
            g.site_code,
            -- @session_key as session_key,
            -- GETDATE() as session_added,
            'Billed Workorder1' as query_type
        from
            #Work_WorkorderListResult af
			INNER JOIN #detail_filter ds on af.workorder_id = ds.workorder_id and af.company_id = ds.company_id and af.profit_ctr_id = ds.profit_ctr_id and ds.query_type = 5
            LEFT JOIN workorderdetail d on d.workorder_id = af.workorder_id and d.company_id = af.company_id and d.profit_ctr_id = af.profit_ctr_id
				and d.resource_type = ds.resource_type and d.sequence_id = ds.sequence_id and d.resource_type = 'D' and d.bill_rate > -2
            LEFT JOIN WorkOrderDetailUnit wodu ON
				d.workorder_id = wodu.workorder_id
				AND d.company_id = wodu.company_id
				AND d.profit_ctr_id = wodu.profit_ctr_id
				AND d.sequence_id = wodu.sequence_id
				AND wodu.billing_flag = 'T'		    
				AND d.resource_type = 'D'
            LEFT JOIN  billunit u on wodu.bill_unit_code = u.bill_unit_code
            LEFT JOIN  billing b on b.receipt_id = af.workorder_id and b.company_id = af.company_id and b.profit_ctr_id = af.profit_ctr_id and b.workorder_resource_type = d.resource_type and b.workorder_sequence_id = d.sequence_id and b.bill_unit_code = wodu.bill_unit_code
            LEFT JOIN  invoiceheader i on i.invoice_code = b.invoice_code and i.status = 'I'
            LEFT OUTER JOIN  generator g ON g.generator_id = b.generator_id
        WHERE 1=1 -- af.session_key = @session_key
            AND af.workorder_id = CASE 
				WHEN af.submitted_flag = 'T' THEN b.receipt_id 
                ELSE af.workorder_id 
            END
			AND 1 = 
				CASE WHEN isnull(d.workorder_id, 0) > 0
					and isnull(wodu.workorder_id, 0) > 0
					and isnull(u.bill_unit_code, '') > ''
					and isnull(b.billing_uid, 0) > 0
					and isnull(i.invoice_id, 0) > 0 
					AND af.is_billed = 'T'
					THEN 1 ELSE 0 
			END
	        
	UNION
        /*
            Inserts all WorkOrderDetail items for an INVOICED work order in the list -- SERVICE LINES
        */
        SELECT
            af.company_id,
            af.profit_ctr_id,
            af.workorder_id,
            d.resource_type,
            d.sequence_id,
            d.tsdf_code,
            d.tsdf_approval_code,
            d.tsdf_approval_id as approval_id,
            d.company_id as approval_company_id,
            d.profit_ctr_id as approval_profit_ctr_id,
            d.manifest,
            d.manifest_line,
            d.bill_unit_code,
            u.bill_unit_desc,
            i.invoice_code,
            i.invoice_date,
            d.quantity_used,
            case when af.show_prices = 'T' then b.price else null end as price,
            case when af.show_prices = 'T' then b.total_extended_amt else null end as total_extended_amt,
            b.workorder_resource_item,
            af.purchase_order,
            af.is_billed,
            af.release_code,
            isnull(b.service_desc_1, d.description) as service_desc_1,
            isnull(b.service_desc_2, d.description_2) as service_desc_2,
            af.show_prices,
            g.site_code,
            -- @session_key as session_key,
            -- GETDATE() as session_added,
            'Billed Workorder2' as query_type
        from
        
            #Work_WorkorderListResult af
			INNER JOIN #detail_filter ds on af.workorder_id = ds.workorder_id and af.company_id = ds.company_id and af.profit_ctr_id = ds.profit_ctr_id and ds.query_type = 5
            INNER JOIN workorderdetail d on d.workorder_id = af.workorder_id and d.company_id = af.company_id and d.profit_ctr_id = af.profit_ctr_id
				AND d.resource_type <> 'D'
				and d.resource_type = ds.resource_type
				and d.sequence_id = ds.sequence_id
			--INNER JOIN WorkOrderDetailUnit wodu ON d.workorder_id = wodu.workorder_id AND d.company_id = wodu.company_id AND d.profit_ctr_id = wodu.profit_ctr_id AND d.sequence_id = wodu.sequence_id AND wodu.billing_flag = 'T'
            INNER JOIN  billunit u on d.bill_unit_code = u.bill_unit_code
            INNER JOIN  billing b on b.receipt_id = af.workorder_id and b.company_id = af.company_id and b.profit_ctr_id = af.profit_ctr_id and b.workorder_resource_type = d.resource_type and b.workorder_sequence_id = d.sequence_id and b.bill_unit_code = d.bill_unit_code
            INNER JOIN  invoiceheader i on i.invoice_code = b.invoice_code and i.status = 'I'
            LEFT JOIN  generator g ON g.generator_id = b.generator_id
        WHERE 1=1 -- af.session_key = @session_key
            AND af.workorder_id = CASE 
                WHEN af.submitted_flag = 'T' THEN b.receipt_id 
                ELSE af.workorder_id 
            END
			AND af.is_billed = 'T'


-- SELECT  COUNT(*)  FROM    #Work_WorkorderDetailResult

  
/*        
        /* insert notes (if applicable) */
        /* insert notes (if applicable) */
        /* insert notes (if applicable) */

        --INSERT Work_WorkOrderNoteListResult
        --    (   
        --        workorder_id, 
        --        company_id, 
        --        profit_ctr_id, 
        --        question_category_name, 
        --        question_text, 
        --        answer_text, 
        --        question_sequence,
        --        session_key, 
        --        session_added
        --    )
        SELECT 
            af.workorder_id,
            af.company_id,
            af.profit_ctr_id,
            CASE 
                WHEN qc.category_desc IS NULL THEN 'Uncategorized'
                ELSE qc.category_desc
            END AS category_name,
            tq.question_text,
            tq.answer_text,
            tq.question_sequence_id
            -- @session_key as session_key,
            -- GETDATE() as session_added
        INTO #Work_WorkOrderNoteListResult
        FROM
            #Work_WorkorderListResult af
            INNER JOIN workorderheader h on h.workorder_id = af.workorder_id 
                and h.company_id = af.company_id 
                and h.profit_ctr_id = af.profit_ctr_id
            INNER JOIN TripHeader th ON th.trip_id = h.trip_id 
                and h.company_id = th.company_id 
                AND h.profit_ctr_id = th.profit_ctr_id
            INNER JOIN TripQuestion tq ON tq.workorder_id = h.workorder_ID
                AND tq.company_id = h.company_id
                AND tq.profit_ctr_id = h.profit_ctr_id
                AND tq.view_on_web_flag = 'T'
            LEFT OUTER JOIN QuestionCategory qc ON tq.question_category_id = qc.question_category_id
        WHERE 1=1 -- af.session_key = @session_key
*/

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Work_WorkorderDetailResult insert' as description




/*
    if datalength(@session_key) > 0 begin
        declare @start_of_results int, @end_of_results int
        select @start_of_results = min(row_num)-1, @end_of_results = max(row_num) from #Work_WorkorderListResult where session_key = @session_key
        set nocount off

            SELECT  l.customer_id, 
                    l.cust_name, 
                    l.workorder_id, 
					woh.fixed_price_flag,
					woh.total_price,
					woh.workorder_status,
                    l.company_id, 
                    l.profit_ctr_id, 
                    l.project_code, 
                    l.project_name, 
                    l.comment_1, 
                    l.comment_2, 
                    l.comment_3, 
                    l.comment_4, 
                    l.comment_5, 
                    l.generator_name, 
					g.generator_address_1,
					g.generator_address_2,
					g.generator_address_3,
					g.generator_address_4,
					g.generator_address_5,
                    l.generator_state,
                    l.generator_city,
                    g.generator_zip_code,
                    g.gen_mail_name
					, g.gen_mail_addr1
					, g.gen_mail_addr2
					, g.gen_mail_addr3
					, g.gen_mail_addr4
					, g.gen_mail_addr5
                    , g.gen_mail_city
                    , g.gen_mail_state
                    , g.gen_mail_zip_code
                    , g.generator_phone
					, g.emergency_phone_number
					, g.emergency_contract_number
                    ,l.epa_id, 
                    l.status, 
                    l.profit_ctr_name, 
                    l.show_prices, 
                    l.submitted_flag, 
                    l.invoice_code, 
                    l.invoice_date,
                    l.start_date, 
                    l.end_date, 
                    l.generator_site_code,
                    l.release_code,
                    l.purchase_order, 
                    l.is_billed,
                    l.trip_est_arrive,
                    l.trip_act_arrive,
                    l.confirmation_date,
                    l.schedule_contact,
                    l.schedule_contact_title,
                    l.pickup_contact_title,
                    l.pickup_contact,
                    CASE 
                        WHEN l.decline_id > 1 THEN 'Declined'
                        ELSE 'Not Declined'
                    END as decline_id,
                    CASE 
                        WHEN l.waste_flag = 'T' THEN 'Waste Picked Up'
                        WHEN l.waste_flag = 'F' THEN 'No Waste Picked Up'
                        ELSE l.waste_flag
                    END as waste_flag,
                    l.driver_name,
                    l.has_notes,
                    l.session_key, 
                    l.session_added, 
                    l.row_num - @start_of_results         AS row_number, 
                    @end_of_results - @start_of_results AS record_count 
            FROM     #work_workorderlistresult l
			INNER JOIN Generator g on l.generator_id = g.generator_id
             INNER JOIN WorkorderHeader woh
				on l.workorder_id = woh.workorder_id
					and l.company_id = woh.company_id
					and l.profit_ctr_id = woh.profit_ctr_id 
            WHERE    l.session_key = @session_key 
                     AND l.row_num >= @start_of_results + @row_from 
                     AND l.row_num <= CASE 
                                      WHEN @row_to = -1 THEN @end_of_results 
                                      ELSE @start_of_results + @row_to 
                                    END 
            ORDER BY l.row_num 

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After RS1 Select-out' as description

        if @report_type = 'D' begin
*/

       
            SELECT   -- DISTINCT 
				d.workorder_id as [Workorder #]
                ,l.status as [Workorder Status]
				,l.profit_ctr_name as [Facility]
                ,l.customer_id as [Customer #]
                ,l.cust_name as [Customer Name]
                ,l.generator_name as [Generator]
                ,l.generator_city as [Generator City]
                ,l.generator_state as [Generator State]
                ,l.epa_id as [Generator EPA ID]
                ,d.site_code as [Site Code]
                ,l.project_name as [Project Name]
                ,l.start_date as [Start Date]
                ,l.end_date as [End Date]
                ,l.confirmation_date as [Date Confirmed]
                ,l.schedule_contact as [Scheduled Contact]
                ,l.schedule_contact_title as [Scheduled Contact Title]
                ,l.driver_name as [Driver]
                ,d.purchase_order [Purchase Order]
                ,d.release_code [Release]
                ,l.pickup_contact [Pickup Contact]
                ,l.pickup_contact_title [Pickup Contact Title]
                ,CASE 
						WHEN decline_id > 1 THEN 'Declined'
						ELSE 'Not Declined'
					END as [Declined Status]
                ,l.trip_est_arrive as [Scheduled Date]
                ,l.trip_act_arrive as [Service Date]

                , isnull(l.comment_1 + ' ', '') +
					isnull(l.comment_2 + ' ', '') +
                	isnull(l.comment_3 + ' ', '') +
                	isnull(l.comment_4 + ' ', '') +
                	isnull(l.comment_5, '') as [Description]
                
                ,d.invoice_code as [Invoice Code]
                ,d.invoice_date as [Invoice Date]
                
                , replace(replace(isnull(d.service_desc_1 + ' ', ''), ',', ', '), '  ', ' ') +
					replace(replace(isnull(d.service_desc_2, ''), ',', ', '), '  ', ' ') as [Detail: Service Description]

                , d.tsdf_approval_code as [Detail: Approval]
                , d.manifest as [Detail: Manifest]
                , d.pounds as [Detail: Quantity]
                
                , case when d.query_type in ('Unbilled Workorder-Incomplete Trip', 'Billed Workorder - Unbilled Receipt')
					then 'Estimated' else '' end as [Detail: Quantity Estimated?]
				
				, d.bill_unit_desc as [Detail: Unit]
				                
				, case when d.show_prices = 'T' then d.price else null end [Detail: Price]
				, case when d.show_prices = 'T' then d.total_extended_amt else null end [Detail: Extended Total]

            FROM     #work_workorderdetailresult d 
             LEFT OUTER JOIN #work_workorderlistresult l 
               ON d.workorder_id = l.workorder_id 
                  AND d.company_id = l.company_id 
                  AND d.profit_ctr_id = l.profit_ctr_id
             -- INNER JOIN Generator g on l.generator_id = g.generator_id
             LEFT OUTER JOIN tsdf
				ON d.tsdf_code = tsdf.tsdf_code
            WHERE    1=1 -- d.session_key = @session_key 
			ORDER BY
				d.company_id,
				d.profit_ctr_id,
				d.workorder_id,
				d.resource_type,
				d.tsdf_code,
				d.manifest,
				d.manifest_line,
				d.sequence_id

/*
        end

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After RS2 Select-out' as description

        if @report_type = 'N' begin
            select notes.*, list.*, g.generator_region_code, g.generator_division, list.row_num - @start_of_results as list_row_num
            from Work_WorkOrderNoteListResult notes
            INNER JOIN #Work_WorkorderListResult list on notes.workorder_id = list.workorder_id 
                and notes.company_id = list.company_id 
                and notes.profit_ctr_id = list.profit_ctr_id
            LEFT JOIN generator g on list.generator_id = g.generator_id
            where notes.session_key = @session_key
            and list.row_num >= @start_of_results + @row_from
            and list.row_num <= case when @row_to = -1 then @end_of_results else @start_of_results + @row_to end
            order by list.workorder_id, notes.question_category_name, notes.question_sequence, list.row_num

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After RS3 Select-out' as description

        end
    
*/


        return

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_COR_reports_workorders] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_COR_reports_workorders] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_COR_reports_workorders] TO [EQAI]
    AS [dbo];

