CREATE PROCEDURE sp_reports_workorders2
    @debug              int,            -- 0 or 1 for no debug/debug mode
    @database_list      varchar(8000),  -- Comma Separated Company List
    @customer_id_list   Text,           -- Comma Separated Customer ID List - what customers to include
    @generator_id_list  Text,           -- Comma Separated Generator ID List - what generators to include
    @receipt_id         Text,           -- Receipt ID
    @project_code       Text,           -- Project Code
    @start_date1        varchar(20),    -- Beginning Start Date
    @start_date2        varchar(20),    -- Ending Start Date
    @end_date1          varchar(20),    -- Beginning End Date
    @end_date2          varchar(20),    -- Ending End Date
    @generator_site_code_list   Text,   -- Generator Site Code List
    @release_code       varchar(50),    -- Release code (NOT a list)
    @purchase_order     varchar(20),            -- Purchase Order list
    @report_type        char(1),        -- 'L'ist or 'D'etail (Detail returns a 2nd recordset with detail info)
    @contact_id         varchar(100),   -- User's Contact ID or 0
    @status_criteria    varchar(200) = NULL,
    @session_key        varchar(100) = '',  -- unique identifier key to a previously run query's results
    @row_from           int = 1,            -- when accessing a previously run query's results, what row should the return set start at?
    @row_to             int = 20            -- when accessing a previously run query's results, what row should the return set end at (-1 = all)?
AS
/* ***************************************************************************************************
sp_reports_workorders2:

Info:
    Returns the data for Work Orders.  The same SP is used for the list and details, just different params
    LOAD TO PLT_AI

Examples:
    
History:
    05/24/2005 JPB  Created
    01/04/2006 JDB  Modified to use plt_rpt database
    05/22/2006 SCC  Removed check where Workorder.customer_id = -1; never happens
    05/22/2006 JPB  Modified "w.customer_id in..." logic to also include generator logons
    05/22/2006 JPB  Modified to use ContactXRef not B2BXContact
    04/04/2007 JPB  Modified location of invoicedetail, joined to invoiceheader - Central Invoicing
    05/24/2007 JPB  Modified inputs to use Text fields and split them internally for Walmart Sized Lists
    09/12/2007 JPB  Verified for Central Invoicing, optimized for speed an standard validation routine
    10/03/2007 JPB  Modified to remove NTSQL* references
    10/23/2007 JPB  Speed_Me_Up improvements
    Central Invoicing:
        Changed customer requirement for invoiced workorders so it checks the submitted_flag field
        and an inner join to InvoiceDetail to verify the workorder is invoiced
    03/10/2008 JPB  Modified to handle profit_ctr_id and profit_ctr_name according to profitcenter.view_on_web rules
        Addresses bad behavior from sp_reports_list_database: Doesn't use srld anymore
        Properly renders the "display as" names for profitcenters that report as their parent company
    5/6/2008    JPB Modified to abort when there's in-specific criteria entered, and return start/end date
    9/3/2008    JPB Added "SET ANSI_WARNINGS OFF" and "SET ANSI_WARNINGS ON" at top and bottom of SP
    10/21/2008  JPB Removed dbo.fn_web_profitctr_display_id handling of profit_ctr_id
    12/04/2008  JPB Added proper paging handling
    12/08/2008  JPB Modified per Lorraine: Never show records whose status is Void.
    12/09/2008  JPB Per Paul & Lorraine: Never show un-invoiced records to anyone, even Associates.
    01/20/2009  JPB Modified to use plt_ai not eqweb/plt_web.
        Modified to avoid reading Workorders with status of 'X' (as well as 'V')
    03.02.2009  RJG Removed invoice code from the List details because it is not used (and returns extra rows when there are multiple invoices)
    03.20.2009 RJG Removed dependency on InvoiceDetail and replaced with Billing Joins
    03.30.2009 RJG Began adding generator site code, release code, and po number as search criteria
    03.31.2009 RJG Began modifying to view both uninvoiced and invoiced records (merging "work order status" procedure with this one)
    04.03.2009 RJG Added filter by status
    04.06.2009 RJG Added Notes export
    04.10.2009 RJG Modified to remove duplicate lines for uninvoiced items in the detail output
    07/28/2009 JPB Converted d.quantity -> d.quantity_used.  quantity_used is the correct field to report.
    11/16/2009 JPB Added Unbilled Workorder-Trip inclusion
                    Added billed Workorder-Receipt inclusion
                    Added unbilled Workorder-Receipt inclusion

    09/16/2010 JPB Fixed a bug where inner joins to generator would omit workorder records that had no generator specified.
    02/28/2019	JPB	Converting Receipt.manifest_dot_shipping_name instances to varchar(max)
						with convert(varchar(max), r.manifest_dot_shipping_name)
						to avoid sql 2016 compatibility problems.


*************************************************************************************************** */

SET NOCOUNT ON
SET ANSI_WARNINGS OFF

--DECLARE @status_criteria varchar(500)
--set @status_criteria = 'Invoiced,Declined,Complete,In Process,Scheduled/Confirmed,Scheduled,Unavailable'

-- default the search to everything
-- print @status_criteria

IF LEN(@status_criteria) = 0 Or @status_criteria IS NULL 
BEGIN
    set @status_criteria = 'Invoiced,Declined,Complete,In Process,Scheduled/Confirmed,Scheduled,Unavailable'
END

--set @status_criteria = 'Invoiced,Declined,Complete,In Process,Scheduled/Confirmed,Scheduled,Unavailable'


declare @starttime datetime
set @starttime = getdate()
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Start' as description

-- Housekeeping.  Gets rid of old paging records.
delete from Work_WorkorderListResult where dateadd(hh, 2, session_added) < getdate()
delete from Work_WorkorderDetailResult where dateadd(hh, 2, session_added) < getdate()

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Housekeeping' as description

-- Check to see if there's a @session_key provided with this query, and if that key is valid.
if datalength(@session_key) > 0 begin
    if not exists(select distinct session_key from Work_WorkorderListResult where session_key = @session_key) begin
        set @session_key = ''
        set @row_from = 1
        set @row_to = 20
    end
end

-- If there's still a populated @session key, skip the query - just get the results.
if datalength(@session_key) > 0 goto returnresults -- Yeah, yeah, goto is evil.  sue me.

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Before Var setup' as description

-- Insert text-list values into table variables.  This validates that each element in the list is a valid data type (no sneaking in bad data/commands)
-- Later learned: Can't use table variables here - have to use #tables because the most efficient filter query below only involves joins/where
-- clauses that explicitly have values (which means building the string as @sql to execute) and you can't import a table-variable into an exec statement.
-- Oh the twisted web we weave, when first we learn to optimize for speed.

-- Database List: (expects x|y, x1|y1 format list)
    create table #database_list (company_id int, profit_ctr_id int)
    if datalength((@database_list)) > 0 begin
        declare @scrub table (dbname varchar(10), company_id int, profit_ctr_id int)

        -- Split the input list into the scub table's dbname column
        insert @scrub select row as dbname, null, null from dbo.fn_SplitXsvText(',', 1, @database_list) where isnull(row, '') <> ''

        -- Split the CO|PC values in dbname into company_id, profit_ctr_id: company_id first.
        update @scrub set company_id = convert(int, case when charindex('|', dbname) > 0 then left(dbname, charindex('|', dbname)-1) else dbname end) where dbname like '%|%'

        -- Split the CO|PC values in dbname into company_id, profit_ctr_id: profit_ctr_id's turn
        update @scrub set profit_ctr_id = convert(int, replace(dbname, convert(varchar(10), company_id) + '|', '')) where dbname like '%|%'

        -- Put the remaining, valid (process_flag = 0) scrub table results into #profitcenter_list
        insert #database_list
        select distinct company_id, profit_ctr_id from @scrub where company_id is not null and profit_ctr_id is not null
    end

-- Customer IDs:
    create table #Customer_id_list (customer_id int)
    if datalength((@customer_id_list)) > 0 begin
        Insert #Customer_id_list
        select convert(int, row)
        from dbo.fn_SplitXsvText(',', 0, @customer_id_list)
        where isnull(row, '') <> ''
    end

    

-- Generator IDs:
    create table #generator_id_list (generator_id int)
    if datalength((@generator_id_list)) > 0 begin
        Insert #generator_id_list
        select convert(int, row)
        from dbo.fn_SplitXsvText(',', 0, @generator_id_list)
        where isnull(row, '') <> ''
    end

-- Workorder IDs:
    create table #workorder_id_list (workorder_id int)
    if datalength((@receipt_id)) > 0 begin
        Insert #workorder_id_list
        select convert(int, row)
        from dbo.fn_SplitXsvText(',', 0, @receipt_id)
        where isnull(row, '') <> ''
    end

-- Project Codes:
    create table #Project_Code_list (project_code varchar(15))
    if datalength((@Project_Code)) > 0 begin
        Insert #Project_Code_list
        select rtrim(left(row, 15))
        from dbo.fn_SplitXsvText(',', 1, @Project_Code)
        where isnull(row, '') <> ''
    end

    -- Generator Site Codes
    create table #generator_site_code_list (site_code varchar(16))
    if datalength((@generator_site_code_list)) > 0 begin
        Insert #generator_site_code_list
        select rtrim(left(row, 16))
        from dbo.fn_SplitXsvText(',', 1, @generator_site_code_list)
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

IF @debug = 1
begin
    SELECT '#status_filter', * from #status_filter
end


-- Abort early if there's just nothing to do here (no criteria given.  Criteria is required)
-- May need to revise this list, if some of them are always given, but meaningless.
    if datalength(ltrim(rtrim(isnull(@contact_id, '')))) = 0 return

    if 0 -- just for nicer formatting below...
        + (select count(*) from #customer_id_list)
        + (select count(*) from #generator_id_list)
        + (select count(*) from #workorder_id_list)
        + (select count(*) from #Project_Code_list)
        + datalength(ltrim(rtrim(isnull(@start_date1, ''))))
        + datalength(ltrim(rtrim(isnull(@start_date2, ''))))
        + datalength(ltrim(rtrim(isnull(@end_date1, ''))))
        + datalength(ltrim(rtrim(isnull(@end_date2, ''))))
        + datalength(ltrim(rtrim(isnull(@contact_id, ''))))
    = 0 return

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Var setup/abort' as description

-- Define Access Filter -- Associates can see everything.  Customers can only see records tied to their explicit (or related) customer_id and generator_id assignments
-- PS, table-variables are the fastest way I've found to do this...
-- Unfortunately though, they get slowed down when you try to build straight sql, and find you have to loj every @table and build weird where clauses to enforce their effects.
-- At that point, it becomes faster to build @sql to execute, which then requires #tables, not @tables.
-- @sql is better/faster because only the involved #tables are in the query AND then not having weird where clauses doesn't cause fields with NULL values to be mistreated.
-- You don't want to know how long it took to learn that.

    set @session_key = newid()
    declare @sql varchar(8000), @where varchar(8000), @groupby varchar(1000)
    set @where = ''

    create table #access_filter (
        company_id int, 
        profit_ctr_id int, 
        workorder_id int, 
        invoice_code varchar(16), 
        contact_link char(1), 
        is_billed char(1),
        billing_status_info varchar(20)
    )


    if @contact_id <> '0' begin -- non-associate version:
        set @sql = 'insert #access_filter
            select 
                w.company_id, 
                w.profit_ctr_id, 
                w.workorder_id, 
                ih.invoice_code, 
                min(w.contact_link),
                case 
                    when b.receipt_id IS NOT NULL AND b.status_code = ''I'' then ''T''
                    else ''F''
                end as is_billed,
                NULL
            /* taking the fields from invoice guarantees theyre.. uh, invoiced. */
            from (
            /* Directly Assigned customers via contactxref: */
            select w.company_id, w.profit_ctr_id, w.workorder_id, ''C'' as contact_link
            from workorderheader w
            inner join contactxref x on w.customer_id = x.customer_id
            where x.contact_id = ' + @contact_id + ' and x.status = ''A'' and x.web_access = ''A'' and x.type = ''C''
            union
            /* Directly Assigned generators via contactxref: */
            select w.company_id, w.profit_ctr_id, w.workorder_id, ''G'' as contact_link
            from workorderheader w
            inner join contactxref x on w.generator_id = x.generator_id
            where x.contact_id = ' + @contact_id + ' and x.status = ''A'' and x.web_access = ''A'' and x.type = ''G''
            union
            /* Indirectly Assigned generators via customergenerator related generators to contactxref related customers: */
            select w.company_id, w.profit_ctr_id, w.workorder_id, ''G'' as contact_link
            from workorderheader w
            inner join customergenerator cg on w.generator_id = cg.generator_id
            inner join contactxref x on cg.customer_id = x.customer_id
            where x.contact_id = ' + @contact_id+ ' and x.status = ''A'' and x.web_access = ''A'' and x.type = ''C''
            ) w
            inner join workorderheader w2 on w2.workorder_id = w.workorder_id and w2.company_id = w.company_id and w2.profit_ctr_id = w.profit_ctr_id
            LEFT OUTER JOIN billing b on b.receipt_id = w.workorder_id and b.company_id = w.company_id and b.profit_ctr_id = w.profit_ctr_id and b.trans_source = ''W''
            LEFT OUTER join invoiceheader ih on b.invoice_id = ih.invoice_id
            inner join company co on w2.company_id = co.company_id
            inner join profitcenter p on w2.company_id = p.company_id and w2.profit_ctr_id = p.profit_ctr_id
            '

        set @groupby = ' GROUP BY w.company_id, 
                w.profit_ctr_id, 
                w.workorder_id, 
                ih.invoice_code, 
                b.receipt_id, b.status_code'

    end else begin  -- Associates version (associates don't have the "only see invoiced" requirement that non-associates do, so this query is much simpler)

        set @sql = '
            insert #access_filter
                SELECT w2.company_id, 
                w2.profit_ctr_id, 
                w2.workorder_id, 
                ih.invoice_code, 
                ''A'' as contact_link,
                case 
                    when b.receipt_id IS NOT NULL AND b.status_code = ''I'' then ''T''
                    else ''F''
                end as is_billed,
                NULL
            from workorderheader w2
            inner join profitcenter p on w2.company_id = p.company_id and w2.profit_ctr_id = p.profit_ctr_id
            inner join company co on w2.company_id = co.company_id 
            LEFT OUTER join billing b on b.receipt_id = w2.workorder_id and b.company_id = w2.company_id and b.profit_ctr_id = w2.profit_ctr_id and b.trans_source = ''W''
            LEFT OUTER join invoiceheader ih on b.invoice_id = ih.invoice_id
            '

        set @groupby = ' GROUP BY w2.company_id, w2.profit_ctr_id, w2.workorder_id, ih.invoice_code, b.receipt_id, b.status_code'

    end

    -- Only include inner joins to these tables if they have data (= a restriction) to add to the query...
    if (select count(*) from #workorder_id_list) > 0
        set @sql = @sql + ' inner join #workorder_id_list wil on w2.workorder_id = wil.workorder_id '

    if (select count(*) from #customer_id_list) > 0
    begin
        set @sql = @sql + ' inner join #customer_id_list cil on w2.customer_id = cil.customer_id '
    end

    if (select count(*) from #generator_id_list) > 0
        set @sql = @sql + ' inner join #generator_id_list gil on w2.generator_id = gil.generator_id '

    if (select count(*) from #Project_Code_list) > 0
        set @sql = @sql + ' inner join #Project_Code_list pcl on w2.project_code = pcl.project_code '

    if (select count(*) from #database_list) > 0
        set @sql = @sql + ' inner join #database_list dl on w2.company_id = dl.company_id and w2.profit_ctr_id = dl.profit_ctr_id '

    if (select count(*) from #generator_site_code_list) > 0
    begin
        set @sql = @sql + ' INNER JOIN Generator g ON g.generator_id = w2.generator_id '
        set @sql = @sql + ' inner join #generator_site_code_list gsc ON gsc.site_code = g.site_code '
    end


    -- These conditions apply to both versions (associate/non-associate) of the query:
    
    set @where = @where + '
        WHERE 1=1 /* where-slug */
        AND co.view_on_web = ''T'' 
        AND p.status = ''A'' 
        AND p.view_on_web IN (''C'', ''P'') 
        AND p.view_workorders_on_web = ''T'' 
        AND w2.workorder_status NOT IN (''V'')
    '
    
    if (LEN(@release_code) > 0)
        set @where = replace(@where, '/* where-slug */', ' AND w2.release_code LIKE ''%' + @release_code + '%'' /* where-slug */')

    if (LEN(@purchase_order) > 0)
        set @where = replace(@where, '/* where-slug */', ' AND w2.purchase_order LIKE ''%' + @purchase_order + '%'' /* where-slug */')

    if datalength(ltrim(@start_date1)) > 0
        set @where = replace(@where, '/* where-slug */', ' AND w2.start_date >= ''' + @start_date1 + ''' /* where-slug */')

    if datalength(ltrim(@start_date2)) > 0
        set @where = replace(@where, '/* where-slug */', ' AND w2.start_date <= ''' + @start_date2 + ''' /* where-slug */')

    if datalength(ltrim(@end_date1)) > 0
        set @where = replace(@where, '/* where-slug */', ' AND w2.end_date >= ''' + @end_date1 + ''' /* where-slug */')

    if datalength(ltrim(@end_date2)) > 0
        set @where = replace(@where, '/* where-slug */', ' AND w2.end_date <= ''' + @end_date2 + ''' /* where-slug */')
        

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Before filling #accessfilter' as description

    -- Execute the sql that popoulates the #access_filter table.
    if @debug > 0 select @sql + @where + @groupby

    exec(@sql + @where + @groupby)
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



-- Query (gets real WorkroderHeader data, inner joined to #access_filter to limit the rows the user is allowed to see):
    INSERT Work_WorkorderListResult (
        customer_id,
        cust_name,
        receipt_id,
        company_id,
        profit_ctr_id,
        project_code,
        project_name,
        comment_1,
        comment_2,
        comment_3,
        comment_4,
        comment_5,
        generator_name,
        epa_id,
        status,
        profit_ctr_name,
        show_prices,
        submitted_flag,
        invoice_code,
        invoice_date,
        start_date,
        end_date,
        generator_site_code,
        generator_state,
        generator_city,
        release_code,
        purchase_order,
        is_billed,
        trip_est_arrive,
        trip_act_arrive,
        confirmation_date,
        schedule_contact,
        schedule_contact_title,
        pickup_contact_title,
        pickup_contact,
        decline_id,
        waste_flag,
        driver_name,
        session_key,
        session_added,
        has_notes
    )
    SELECT DISTINCT
        h.customer_id,
        c.cust_name,
        h.workorder_id as receipt_id,
        h.company_id,
        h.profit_ctr_id,
        h.project_code,
        h.project_name,
        h.invoice_comment_1 as comment_1,
        h.invoice_comment_2 as comment_2,
        h.invoice_comment_3 as comment_3,
        h.invoice_comment_4 as comment_4,
        h.invoice_comment_5 as comment_5,
        g.generator_name,
        g.epa_id,
        af.billing_status_info as status,
        dbo.fn_web_profitctr_display_name(h.company_id, h.profit_ctr_id) as profit_ctr_name,
        case when @contact_id = '0' then
            'T'
        else
            case when h.customer_id in (
                select customer_id
                from contactxref
                where contact_id = convert(int, @contact_id )
                and type = 'C'
                and web_access = 'A'
                and status = 'A') then
                'T'
            else
                'F'
            end
        end as show_prices,
        h.submitted_flag,
        af.invoice_code,
        b.invoice_date,
        h.start_date,
        h.end_date,
        g.site_code,
        g.generator_state,
        g.generator_city,
        h.release_code,
        h.purchase_order,
        af.is_billed,
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
        @session_key as session_key,
        getdate() as session_added,
        has_notes = CASE   
            WHEN h.workorder_ID = tq.workorder_id AND h.company_id = tq.company_id AND h.profit_ctr_id = tq.profit_ctr_id THEN 'T'  
            ELSE 'F'  
        END  
    FROM
        #access_filter af
        inner join #status_filter sf ON af.billing_status_info = sf.status_filter -- this is ok, it always has values.
        inner join workorderheader h on h.workorder_id = af.workorder_id and h.company_id = af.company_id and h.profit_ctr_id = af.profit_ctr_id
        INNER JOIN WorkOrderStop wos ON h.workorder_ID = wos.workorder_id
			AND h.company_id = wos.company_id
			AND h.profit_ctr_ID = wos.profit_ctr_id
        inner join customer c on h.customer_id = c.customer_id
        LEFT OUTER JOIN generator g on h.generator_id = g.generator_id
        inner join profitcenter p on h.company_id = p.company_id and h.profit_ctr_id = p.profit_ctr_id
        inner join company co on h.company_id = co.company_id
        LEFT OUTER join billing b on b.receipt_id = h.workorder_id and b.company_id = h.company_id and b.profit_ctr_id = h.profit_ctr_id and b.trans_source = 'W'
        LEFT OUTER JOIN TripHeader th ON th.trip_id = h.trip_id and h.company_id = th.company_id AND h.profit_ctr_id = th.profit_ctr_id
        LEFT OUTER JOIN TripQuestion tq ON tq.workorder_id = h.workorder_ID
        AND tq.company_id = h.company_id
        AND tq.profit_ctr_id = h.profit_ctr_ID
        AND tq.view_on_web_flag = 'T'
    WHERE 
        h.workorder_status NOT IN ('V')
        AND co.view_on_web = 'T'
        AND p.view_on_web in ('P', 'C')
        AND p.status = 'A'
        AND p.view_workorders_on_web = 'T'
    ORDER BY h.company_id, h.profit_ctr_id, h.customer_id, h.workorder_id desc



if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Work_WorkorderListResult insert' as description

        INSERT Work_WorkorderDetailResult (
            company_id,
            profit_ctr_id,
            receipt_id,
            sequence_id,
            bill_unit_code,
            bill_unit_desc,
            invoice_code,
            invoice_date,
            quantity,
            price,
            total_extended_amt,
            workorder_resource_item,
            purchase_order,
            is_billed,
            release_code,
            service_desc_1,
            service_desc_2,
            show_prices,
            generator_site_code,
            session_key,
            session_added,
            query_type
        )
        /* 
            Incomplete Trip Info:
        */
        SELECT DISTINCT
            af.company_id,
            af.profit_ctr_id,
            af.receipt_id,
            d.sequence_id,
            null as bill_unit_code,
            'Pounds' as bill_unit_desc,
            null as invoice_code,
            null as invoice_date,
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
					AND a.billing_flag = 'F'
					AND a.bill_unit_code = 'LBS'
			) as pounds, -- workorder detail pounds
            null as price,
            null as total_extended_amt,
            d.resource_class_code,
            af.purchase_order,
            af.is_billed,
            af.release_code,
            d.description as service_desc_1,
            d.description_2 as service_desc_2,
            'F' as show_prices,
            af.generator_site_code,
            @session_key as session_key,
            GETDATE() as session_added,
            'Unbilled Workorder-Incomplete Trip' as query_type
        from
            Work_WorkorderListResult af
            INNER JOIN WorkorderHeader h on h.workorder_id = af.receipt_id and h.company_id = af.company_id and h.profit_ctr_id = af.profit_ctr_id
            INNER JOIN workorderdetail d on d.workorder_id = af.receipt_id and d.company_id = af.company_id and d.profit_ctr_id = af.profit_ctr_id
			INNER JOIN WorkOrderDetailUnit wodu ON d.workorder_id = wodu.workorder_id AND d.company_id = wodu.company_id AND d.profit_ctr_id = wodu.profit_ctr_id AND d.sequence_id = wodu.sequence_id AND wodu.billing_flag = 'T'		                
            INNER JOIN TripHeader th on h.trip_id = th.trip_id
            INNER JOIN TSDF tsdf on d.TSDF_code = tsdf.TSDF_code and tsdf.TSDF_status = 'A' and tsdf.eq_flag = 'T'
            INNER JOIN  billunit u on wodu.bill_unit_code = u.bill_unit_code
        WHERE af.session_key = @session_key
            AND ISNULL(h.trip_id, 0) > 0
            AND ISNULL(h.trip_sequence_id, 0) > 0
            AND th.trip_status NOT IN ('C', 'V')
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
            af.receipt_id,
            NULL as sequence_id, 
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
            af.generator_site_code as site_code,
            @session_key as session_key,
            GETDATE() as session_added,
            'Unbilled Workorder-Non Trip' as query_type
        from
            Work_WorkorderListResult af
            WHERE af.session_key = @session_key
                AND af.is_billed = 'F'
                AND Not exists (
                    select af.receipt_id
                    from
                        Work_WorkorderListResult af2
                        INNER JOIN WorkorderHeader h2 on h2.workorder_id = af2.receipt_id and h2.company_id = af2.company_id and h2.profit_ctr_id = af2.profit_ctr_id
                        INNER JOIN workorderdetail d2 on d2.workorder_id = af2.receipt_id and d2.company_id = af2.company_id and d2.profit_ctr_id = af2.profit_ctr_id
						INNER JOIN WorkOrderDetailUnit wodu2 ON	d2.workorder_id = wodu2.workorder_id AND d2.company_id = wodu2.company_id AND d2.profit_ctr_id = wodu2.profit_ctr_id AND d2.sequence_id = wodu2.sequence_id AND wodu2.billing_flag = 'T'		                
                        INNER JOIN TripHeader th2 on h2.trip_id = th2.trip_id
                        INNER JOIN TSDF tsdf2 on d2.TSDF_code = tsdf2.TSDF_code and tsdf2.TSDF_status = 'A' and tsdf2.eq_flag = 'T'
                        INNER JOIN  billunit u2 on wodu2.bill_unit_code = u2.bill_unit_code
                    WHERE af.session_key = @session_key
                        AND ISNULL(h2.trip_id, 0) > 0
                        AND ISNULL(h2.trip_sequence_id, 0) > 0
                        AND th2.trip_status NOT IN ('C', 'V')
                        AND d2.bill_rate = -1
                        AND ISNULL(wodu2.quantity, 0) > 0
                        AND af2.receipt_id = af.receipt_id
                        and af2.company_id = af.company_id
                        and af2.profit_ctr_id = af.profit_ctr_id
                )
        UNION 
        /* 
            EQ BillingLink-ed (Billed Receipt) records: 
        */
        SELECT DISTINCT
            af.company_id,
            af.profit_ctr_id,
            af.receipt_id,
            null,
            br.bill_unit_code,
            u.bill_unit_desc,
            iw.invoice_code,
            iw.invoice_date,
            br.quantity,
            case when af.show_prices = 'T' then br.price else null end as price,
            case when af.show_prices = 'T' then br.total_extended_amt else null end as total_extended_amt,
            NULL as workorder_resource_item,
            af.purchase_order,
            af.is_billed,
            af.release_code,
            isnull(br.service_desc_1, convert(varchar(max), r.manifest_dot_shipping_name)) as service_desc_1,
            isnull(br.service_desc_2, '') as service_desc_2,
            af.show_prices,
            g.site_code,
            @session_key as session_key,
            GETDATE() as session_added,
            'Billed Workorder - Billed Receipt' as query_type
        from
            Work_WorkorderListResult af
            INNER JOIN BillingLinkLookup bl on bl.source_id = af.receipt_id and bl.source_company_id = af.company_id and bl.source_profit_ctr_id = af.profit_ctr_ID
            INNER JOIN Receipt r on bl.receipt_id = r.receipt_id and bl.company_id = r.company_id and bl.profit_ctr_id = r.profit_ctr_id and r.receipt_status <> 'V'
            INNER JOIN  billing bw on bw.receipt_id = af.receipt_id and bw.company_id = af.company_id and bw.profit_ctr_id = af.profit_ctr_id and bw.trans_source = 'W'
            INNER JOIN  invoiceheader iw on iw.invoice_code = bw.invoice_code and iw.status = 'I'
            LEFT OUTER JOIN  generator g ON g.generator_id = r.generator_id
            INNER JOIN  billing br on br.receipt_id = r.receipt_id and br.company_id = r.company_id and br.profit_ctr_id = r.profit_ctr_id and br.line_id = r.line_id
            INNER JOIN  invoiceheader ir on ir.invoice_code = br.invoice_code and ir.status = 'I'
            INNER JOIN  billunit u on br.bill_unit_code = u.bill_unit_code
        WHERE af.session_key = @session_key
        UNION 
        /* 
            EQ BillingLink-ed (UnBilled Receipt) records: 
        */
        SELECT
            af.company_id,
            af.profit_ctr_id,
            af.receipt_id,
            null,
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
            @session_key as session_key,
            GETDATE() as session_added,
            'Billed Workorder - Unbilled Receipt' as query_type
        from
            Work_WorkorderListResult af
            INNER JOIN BillingLinkLookup bl on bl.source_id = af.receipt_id and bl.source_company_id = af.company_id and bl.source_profit_ctr_id = af.profit_ctr_ID
            INNER JOIN Receipt r on bl.receipt_id = r.receipt_id and bl.company_id = r.company_id and bl.profit_ctr_id = r.profit_ctr_id and r.receipt_status <> 'V'
            INNER JOIN Profile p on r.profile_id = p.profile_id
            INNER JOIN  billing bw on bw.receipt_id = af.receipt_id and bw.company_id = af.company_id and bw.profit_ctr_id = af.profit_ctr_id and bw.trans_source = 'W'
            INNER JOIN  invoiceheader iw on iw.invoice_code = bw.invoice_code and iw.status = 'I'
            LEFT OUTER JOIN  generator g ON g.generator_id = r.generator_id
            INNER JOIN  billunit u on r.bill_unit_code = u.bill_unit_code
        WHERE af.session_key = @session_key
            AND NOT EXISTS(select receipt_id from Billing where receipt_id = r.receipt_id and company_id = r.company_id and profit_ctr_id = r.profit_ctr_id and line_id = r.line_id)
        UNION
        /*
            Inserts all WorkOrderDetail items for an INVOICED work order in the list -- DISPOSAL LINES
        */ 
        SELECT
            af.company_id,
            af.profit_ctr_id,
            af.receipt_id,
            d.sequence_id,
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
            @session_key as session_key,
            GETDATE() as session_added,
            'Billed Workorder' as query_type
        from
            Work_WorkorderListResult af
            INNER JOIN workorderdetail d on d.workorder_id = af.receipt_id and d.company_id = af.company_id and d.profit_ctr_id = af.profit_ctr_id
            INNER JOIN WorkOrderDetailUnit wodu ON
			d.workorder_id = wodu.workorder_id
			AND d.company_id = wodu.company_id
			AND d.profit_ctr_id = wodu.profit_ctr_id
			AND d.sequence_id = wodu.sequence_id
			AND wodu.billing_flag = 'T'		    
			AND d.resource_type = 'D'
            INNER JOIN  billunit u on wodu.bill_unit_code = u.bill_unit_code
            INNER JOIN  billing b on b.receipt_id = af.receipt_id and b.company_id = af.company_id and b.profit_ctr_id = af.profit_ctr_id and b.workorder_resource_type = d.resource_type and b.workorder_sequence_id = d.sequence_id and b.bill_unit_code = wodu.bill_unit_code
            INNER JOIN  invoiceheader i on i.invoice_code = b.invoice_code and i.status = 'I'
            LEFT OUTER JOIN  generator g ON g.generator_id = b.generator_id
        WHERE af.session_key = @session_key
            AND af.receipt_id = CASE 
                WHEN af.submitted_flag = 'T' THEN b.receipt_id 
                ELSE af.receipt_id 
            END
        AND af.is_billed = 'T'
        
        
UNION
        /*
            Inserts all WorkOrderDetail items for an INVOICED work order in the list -- SERVICE LINES
        */
        SELECT
            af.company_id,
            af.profit_ctr_id,
            af.receipt_id,
            d.sequence_id,
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
            @session_key as session_key,
            GETDATE() as session_added,
            'Billed Workorder' as query_type
        from
            Work_WorkorderListResult af
            INNER JOIN workorderdetail d on d.workorder_id = af.receipt_id and d.company_id = af.company_id and d.profit_ctr_id = af.profit_ctr_id
				--AND d.resource_type <> 'D'
			INNER JOIN WorkOrderDetailUnit wodu ON d.workorder_id = wodu.workorder_id AND d.company_id = wodu.company_id AND d.profit_ctr_id = wodu.profit_ctr_id AND d.sequence_id = wodu.sequence_id AND wodu.billing_flag = 'T'
            INNER JOIN  billunit u on wodu.bill_unit_code = u.bill_unit_code
            INNER JOIN  billing b on b.receipt_id = af.receipt_id and b.company_id = af.company_id and b.profit_ctr_id = af.profit_ctr_id and b.workorder_resource_type = d.resource_type and b.workorder_sequence_id = d.sequence_id and b.bill_unit_code = wodu.bill_unit_code
            INNER JOIN  invoiceheader i on i.invoice_code = b.invoice_code and i.status = 'I'
            LEFT OUTER JOIN  generator g ON g.generator_id = b.generator_id
        WHERE af.session_key = @session_key
            AND af.receipt_id = CASE 
                WHEN af.submitted_flag = 'T' THEN b.receipt_id 
                ELSE af.receipt_id 
            END
        AND af.is_billed = 'T'        

        
        /* insert notes (if applicable) */
        /* insert notes (if applicable) */
        /* insert notes (if applicable) */

        INSERT Work_WorkOrderNoteListResult
            (   
                receipt_id, 
                company_id, 
                profit_ctr_id, 
                question_category_name, 
                question_text, 
                answer_text, 
                question_sequence,
                session_key, 
                session_added
            )
        SELECT 
            af.receipt_id,
            af.company_id,
            af.profit_ctr_id,
            CASE 
                WHEN qc.category_desc IS NULL THEN 'Uncategorized'
                ELSE qc.category_desc
            END AS category_name,
            tq.question_text,
            tq.answer_text,
            tq.question_sequence_id,
            @session_key as session_key,
            GETDATE() as session_added
        FROM
            Work_WorkorderListResult af
            INNER JOIN workorderheader h on h.workorder_id = af.receipt_id 
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
        WHERE af.session_key = @session_key


if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Work_WorkorderDetailResult insert' as description


returnresults: -- Re-queries with an existing session_key that passes validation end up here.  So do 1st runs (with an empty, now brand-new session_key)

    if datalength(@session_key) > 0 begin
        declare @start_of_results int, @end_of_results int
        select @start_of_results = min(row_num)-1, @end_of_results = max(row_num) from Work_WorkorderListResult where session_key = @session_key
        set nocount off

            SELECT   customer_id, 
                    cust_name, 
                    receipt_id, 
                    company_id, 
                    profit_ctr_id, 
                    project_code, 
                    project_name, 
                    comment_1, 
                    comment_2, 
                    comment_3, 
                    comment_4, 
                    comment_5, 
                    generator_name, 
                    generator_state,
                    generator_city,
                    epa_id, 
                    status, 
                    profit_ctr_name, 
                    show_prices, 
                    submitted_flag, 
                    invoice_code, 
                    invoice_date,
                    start_date, 
                    end_date, 
                    generator_site_code,
                    release_code,
                    purchase_order, 
                    is_billed,
                    trip_est_arrive,
                    trip_act_arrive,
                    confirmation_date,
                    schedule_contact,
                    schedule_contact_title,
                    pickup_contact_title,
                    pickup_contact,
                    CASE 
                        WHEN decline_id > 1 THEN 'Declined'
                        ELSE 'Not Declined'
                    END as decline_id,
                    CASE 
                        WHEN waste_flag = 'T' THEN 'Waste Picked Up'
                        WHEN waste_flag = 'F' THEN 'No Waste Picked Up'
                        ELSE waste_flag
                    END as waste_flag,
                    driver_name,
                    has_notes,
                    session_key, 
                    session_added, 
                    row_num - @start_of_results         AS row_number, 
                    @end_of_results - @start_of_results AS record_count 
            FROM     work_workorderlistresult 
            WHERE    session_key = @session_key 
                     AND row_num >= @start_of_results + @row_from 
                     AND row_num <= CASE 
                                      WHEN @row_to = -1 THEN @end_of_results 
                                      ELSE @start_of_results + @row_to 
                                    END 
            ORDER BY row_num 

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After RS1 Select-out' as description

        if @report_type = 'D' begin
            SELECT   DISTINCT 
                d.company_id,
                d.profit_ctr_id,
                d.receipt_id,
                d.customer_id,
                d.sequence_id,
                d.bill_unit_code,
                d.bill_unit_desc,
                d.invoice_code,
                d.invoice_date,
                d.quantity,
                d.price,
                d.total_extended_amt,
                d.workorder_resource_item,
                d.purchase_order,
                d.is_billed,
                d.release_code,
                d.service_desc_1,
                d.service_desc_2,
                d.show_prices,
                d.generator_site_code,
                d.session_key,
                d.session_added,
                l.customer_id,
                l.cust_name,
                l.receipt_id,
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
                l.epa_id,
                l.status,
                l.profit_ctr_name,
                -- l.show_prices,
                l.submitted_flag,
                l.invoice_code,
                l.start_date,
                l.end_date,
                l.session_key,
                l.session_added,
                l.row_num,
                l.invoice_date,
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
                l.driver_name,
                CASE 
                    WHEN decline_id > 1 THEN 'Declined'
                    ELSE 'Not Declined'
                END as decline_id,
                CASE 
                    WHEN waste_flag = 'T' THEN 'Waste Picked Up'
                    WHEN waste_flag = 'F' THEN 'No Waste Picked Up'
                    ELSE waste_flag
                END as waste_flag,
                l.has_notes,
                l.generator_state,
                l.generator_city,
                d.query_type,
                l.row_num - @start_of_results AS list_row_num 
            FROM     work_workorderdetailresult d 
             LEFT OUTER JOIN work_workorderlistresult l 
               ON d.receipt_id = l.receipt_id 
                  AND d.company_id = l.company_id 
                  AND d.profit_ctr_id = l.profit_ctr_id 
            WHERE    d.session_key = @session_key 
             AND l.row_num >= @start_of_results + @row_from 
             AND l.row_num <= CASE 
                                WHEN @row_to = -1 THEN @end_of_results 
                                ELSE @start_of_results + @row_to 
                              END 
        end


        if @report_type = 'N' begin
            select notes.*, list.*, list.row_num - @start_of_results as list_row_num
            from Work_WorkOrderNoteListResult notes
            INNER JOIN Work_WorkorderListResult list on notes.receipt_id = list.receipt_id 
                and notes.company_id = list.company_id 
                and notes.profit_ctr_id = list.profit_ctr_id
            where notes.session_key = @session_key
            and list.row_num >= @start_of_results + @row_from
            and list.row_num <= case when @row_to = -1 then @end_of_results else @start_of_results + @row_to end
            order by list.receipt_id, notes.question_category_name, notes.question_sequence, list.row_num
        end
    


if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After RS2 Select-out' as description

        return
    end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_workorders2] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_workorders2] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_workorders2] TO [EQAI]
    AS [dbo];

