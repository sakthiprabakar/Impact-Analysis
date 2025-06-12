CREATE PROCEDURE sp_reports_workorders_lear
    @debug              int,            -- 0 or 1 for no debug/debug mode
    @database_list      varchar(max),  -- Comma Separated Company List
    @customer_id_list   varchar(max),           -- Comma Separated Customer ID List - what customers to include
    @generator_id_list  varchar(max),           -- Comma Separated Generator ID List - what generators to include
    @receipt_id         varchar(max),           -- Receipt ID
    @project_code       varchar(max),           -- Project Code
    @start_date1        varchar(20),    -- Beginning Start Date
    @start_date2        varchar(20),    -- Ending Start Date
    @end_date1          varchar(20),    -- Beginning End Date
    @end_date2          varchar(20),    -- Ending End Date
    @generator_site_code_list   varchar(max),   -- Generator Site Code List
    @release_code       varchar(50),    -- Release code (NOT a list)
    @purchase_order     varchar(20),            -- Purchase Order list
    @report_type        char(1),        -- 'L'ist or 'D'etail (Detail returns a 2nd recordset with detail info)
    @contact_id         varchar(100),   -- User's Contact ID or 0
    @generator_site_type varchar(max),   -- Generator Site Type
    @status_criteria    varchar(200) = NULL,
    @session_key        varchar(100) = '',  -- unique identifier key to a previously run query's results
    @row_from           int = 1,            -- when accessing a previously run query's results, what row should the return set start at?
    @row_to             int = 20            -- when accessing a previously run query's results, what row should the return set end at (-1 = all)?
AS
/* ***************************************************************************************************
sp_reports_workorders_lear:

NOTE: DO NOT MAKE A COPY OF THIS PROC FOR ANY NEW REPORTS
    This computes estimated pounds using a method that should not be used

Info:
    Returns data for Work Orders with custom codes defined for Lear.
    Loads to Plt_ai

Examples:
    
History:
    12/26/2012 RWB  Created from copy of sp_reports_workorders_lear
    01/09/2013 RWB  Added generator_site_type arg, added generator_city and estimated_total_pounds to result set
    05/15/2013 JPB	Added start_date, end_date to output
					Added wod.pounds to output

select top 100 * from workorderheader where customer_id = 10700 order by end_date desc
SELECT * FROM workorderdetail where workorder_id in (2896200,2931000,2933500,2929900,2930300) and company_id = 14 and profit_ctr_id = 9
SELECT * FROM workorderdetailunit where workorder_id in (2896200,2931000,2933500,2929900,2930300) and company_id = 14 and profit_ctr_id = 9

SELECT * FROM WorkorderHeader woh Inner join workorderdetail wod on woh.workorder_id = wod.workorder_id and woh.company_id = wod.company_id and woh.profit_ctr_id = wod.profit_ctr_id
where woh.customer_id = 10700 and wod.tsdf_approval_code = 'A127236DET'
and woh.start_date > '1/1/2013'

SELECT * FROM workorderdetail where workorder_id = 2953700 and company_id = 14 and profit_ctr_id = 9
SELECT * FROM workorderdetailunit where workorder_id = 2953700 and company_id = 14 and profit_ctr_id = 9 and sequence_id = 1

SELECT * FROM WorkorderHeader woh Inner join workorderdetail wod on woh.workorder_id = wod.workorder_id and woh.company_id = wod.company_id and woh.profit_ctr_id = wod.profit_ctr_id
where woh.customer_id = 10700 and wod.tsdf_approval_code = '41-NH-R Pallets'
and woh.start_date > '1/1/2013'

SELECT * FROM workorderdetail where workorder_id = 2853300 and company_id = 14 and profit_ctr_id = 9 
SELECT * FROM workorderdetailunit where workorder_id = 2853300 and company_id = 14 and profit_ctr_id = 9

update workorderdetailunit set billing_flag = 'F' where workorder_id = 2844400 and company_id = 14 and profit_ctr_id = 9 and sequence_id = 5 and manifest_flag = 'T'
update workorderdetailunit set manifest_flag = 'T' where workorder_id = 2853300 and company_id = 14 and profit_ctr_id = 9 and sequence_id = 1 and bill_unit_code = 'LBS'

examples of problems in 14-9
2844400
2853300

sp_reports_workorders_lear
    @debug              = 0,
    @database_list      = '',
    @customer_id_list   = '10700',
    @generator_id_list  = '',
    @receipt_id         = '',
    @project_code       = '',
    @start_date1        = '1/1/2016',
    @start_date2        = '',
    @end_date1          = '',
    @end_date2          = '3/31/2017',
    @generator_site_code_list   = '',
    @release_code       = '', 
    @purchase_order     = '', 
    @report_type        = 'L', 
    @contact_id         = '0', 
    @generator_site_type = '', -- 'Lear - HQ Campus,Lear EPMS,Lear JV,Lear SSD-Foam,Lear SSD-JIT,Lear SSD-Metals,Lear Textiles', 
    @status_criteria    = '', 
    @session_key        = '', 
    @row_from           = 1,            -- when accessing a previously run query's results, what row should the return set start at?
    @row_to             = 20000            -- when accessing a previously run query's results, what row should the return set end at (-1 = all)?

-- was 1475 when Disposal only
--  3561 for all, without 'D' limitations in joins
--  3559 for all, with 'D' limitations in joins
--  3559 for all, removing wom join & result fields

*************************************************************************************************** */

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
-- rb 12/26/2012 Turn off locking
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

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

    --rb 01/10/2013 Generator Site Types
    create table #generator_site_type_list (site_type varchar(40))
    if datalength((@generator_site_type)) > 0 begin
        Insert #generator_site_type_list
        select rtrim(left(row, 40))
        from dbo.fn_SplitXsvText(',', 1, @generator_site_type)
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
        + (select count(*) from #generator_site_type_list)
        + case when @contact_id = 0 then 0 else datalength(ltrim(rtrim(isnull(@start_date1, '')))) end
        + case when @contact_id = 0 then 0 else datalength(ltrim(rtrim(isnull(@start_date2, '')))) end
        + case when @contact_id = 0 then 0 else datalength(ltrim(rtrim(isnull(@end_date1, '')))) end
        + case when @contact_id = 0 then 0 else datalength(ltrim(rtrim(isnull(@end_date2, '')))) end
        + case when @contact_id = 0 then 0 else datalength(ltrim(rtrim(isnull(@contact_id, '')))) end
    = 0 return

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Var setup/abort' as description

-- Define Access Filter -- Associates can see everything.  Customers can only see records tied to their explicit (or related) customer_id and generator_id assignments
-- PS, table-variables are the fastest way I've found to do this...
-- Unfortunately though, they get slowed down when you try to build straight sql, and find you have to loj every @table and build weird where clauses to enforce their effects.
-- At that point, it becomes faster to build @sql to execute, which then requires #tables, not @tables.
-- @sql is better/faster because only the involved #tables are in the query AND then not having weird where clauses doesn't cause fields with NULL values to be mistreated.
-- You don't want to know how long it took to learn that.

    set @session_key = newid()
    declare @sql varchar(max), @where varchar(max), @groupby varchar(max)
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

    -- rb 01/10/2013
    if (select count(*) from #generator_site_type_list) > 0
    begin
        if (select count(*) from #generator_site_code_list) = 0
            set @sql = @sql + ' INNER JOIN Generator g ON g.generator_id = w2.generator_id '

        set @sql = @sql + ' inner join #generator_site_type_list gst ON gst.site_type = g.site_type '
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


returnresults: -- Re-queries with an existing session_key that passes validation end up here.  So do 1st runs (with an empty, now brand-new session_key)

    if datalength(@session_key) > 0 begin

        declare @start_of_results int, @end_of_results int
        select @start_of_results = min(row_num)-1, @end_of_results = max(row_num) from Work_WorkorderListResult where session_key = @session_key
        set nocount off

		-- non-EQ TSDFs
        select 
        w.receipt_id as workorder_id,
        wd.tsdf_approval_code as 'TSDF_Approval',
        ta.waste_desc as 'ID_Waste_Description',
        g.generator_name as 'Generator_Name',
        wt.description as 'Waste_Type_Description',
        wt.category as 'Waste_Type_Category',
        wodu.quantity as 'Quantity',
        wodu.bill_unit_code as 'Unit',
        wodu.price as 'Cost',
        round(isnull(wodu.quantity,0) * isnull(wodu.price,0), 2) as 'Total_Cost',
        ct_p.alpha_value as 'By_Product_Waste_Index',
        ct_c.alpha_value as 'By_Product_Classification',
        ct_d.alpha_value as 'By_Product_Disposal_Method',
        g.site_type as 'Generator_Site_Type',
        g.generator_city as 'Generator_City',
        coalesce(nullif(wodu_lbs_m.quantity,0),nullif(wodu_lbs_t.quantity*2000,0),wodu.quantity * b.pound_conv) as 'Estimated_Total_Pounds'
        , w.start_date
        , w.end_date

		, 'Disposal' as resource_type
		
		, wd.description description_1
        , wd.description_2
        
        , case wom.manifest_flag when 'T' then 'Haz Manifest' else 'Other' end as manifest_flag
        
		, wd.manifest
		, wd.manifest_page_num
		, wd.manifest_line
		, wd.manifest_line_id
                
        , w.session_key as session_key, 
        w.session_added as session_added, 
        w.row_num - @start_of_results as row_number, 
        @end_of_results - @start_of_results as record_count 
        from Work_WorkorderListResult w
        join workorderheader wh on w.receipt_id = wh.workorder_id and w.company_id = wh.company_id and w.profit_ctr_id = wh.profit_ctr_id and wh.workorder_status = 'A' and wh.submitted_flag = 'T'
        join workorderdetail wd on wh.workorder_id = wd.workorder_id and wh.profit_ctr_id = wd.profit_ctr_id and wh.company_id = wd.company_id and wd.resource_type = 'D'
        join workorderdetailunit wodu on wd.company_id = wodu.company_id and wd.profit_ctr_ID = wodu.profit_ctr_id and wd.workorder_ID = wodu.workorder_id and wd.sequence_ID = wodu.sequence_id and wodu.billing_flag = 'T'
        join generator g on wh.generator_id = g.generator_id
        join tsdf t on wd.tsdf_code = t.tsdf_code and isnull(t.eq_flag,'F') = 'F'
        join tsdfapproval ta on wd.tsdf_approval_id = ta.tsdf_approval_id and wd.company_id = ta.company_id and wd.profit_ctr_id = ta.profit_ctr_id
        join billunit b on wodu.Bill_unit_code = b.bill_unit_code and wodu.billing_flag = 'T'
        left outer join wastetype wt on ta.wastetype_id = wt.wastetype_id
        left outer join CodeTransaction ct_p on ct_p.source_type = 'T' and wd.company_id = ct_p.source_company_id and wd.profit_ctr_id = ct_p.source_profit_ctr_id and ta.tsdf_approval_id = ct_p.source_transaction_id and ct_p.code_id = 1
        left outer join CodeTransaction ct_c on ct_c.source_type = 'T' and wd.company_id = ct_c.source_company_id and wd.profit_ctr_id = ct_c.source_profit_ctr_id and ta.tsdf_approval_id = ct_c.source_transaction_id and ct_c.code_id = 2
        left outer join CodeTransaction ct_d on ct_d.source_type = 'T' and wd.company_id = ct_d.source_company_id and wd.profit_ctr_id = ct_d.source_profit_ctr_id and ta.tsdf_approval_id = ct_d.source_transaction_id and ct_d.code_id = 3
        left outer join WorkOrderDetailUnit wodu_lbs_m on wd.company_id = wodu_lbs_m.company_id and wd.profit_ctr_ID = wodu_lbs_m.profit_ctr_id and wd.workorder_ID = wodu_lbs_m.workorder_id and wd.sequence_ID = wodu_lbs_m.sequence_id and wodu_lbs_m.size = 'LBS'
        left outer join WorkOrderDetailUnit wodu_lbs_t on wd.company_id = wodu_lbs_t.company_id and wd.profit_ctr_ID = wodu_lbs_t.profit_ctr_id and wd.workorder_ID = wodu_lbs_t.workorder_id and wd.sequence_ID = wodu_lbs_t.sequence_id and wodu_lbs_t.size = 'TONS' 
        left outer join WorkOrderManifest wom on wd.workorder_id = wom.workorder_id and wd.company_id = wom.company_id and wd.profit_ctr_id = wom.profit_ctr_id
        
        where w.session_key = @session_key
        and exists (
			select 1 from billing bi
			where bi.receipt_id = wh.workorder_id and bi.company_id = wh.company_id and bi.profit_ctr_id = wh.profit_ctr_id and bi.workorder_sequence_id = wd.sequence_id and bi.workorder_resource_type = wd.resource_type and bi.status_code = 'I'
		)
        

        union

		-- EQ TSDFs
        select 
        w.receipt_id as workorder_id,
        wd.tsdf_approval_code as 'TSDF Approval',
        p.approval_desc as 'ID Waste Description',
        g.generator_name as 'Generator Name',
        wt.description as 'Waste Type Description',
        wt.category as 'Waste Type Category',
        wodu.quantity as 'Quantity',
        wodu.bill_unit_code as 'Unit',
        wodu.price as 'Cost',
        round(isnull(wodu.quantity,0) * isnull(wodu.price,0), 2) as 'Total Cost',
        ct_p.alpha_value as 'By-Product Waste Index',
        ct_c.alpha_value as 'By-Product Classification',
        ct_d.alpha_value as 'By-Product Disposal Method',
        g.site_type as 'Generator Site Type',
        g.generator_city as 'Generator City',
        coalesce(nullif(wodu_lbs_m.quantity,0),nullif(wodu_lbs_t.quantity*2000,0),wodu.quantity * b.pound_conv) as 'Estimated Total Pounds',
        w.start_date
        , w.end_date

		, 'Disposal' as resource_type
        , wd.description description_1
        , wd.description_2
        
        , case wom.manifest_flag when 'T' then 'Haz Manifest' else 'Other' end as manifest_flag
        
		, wd.manifest
		, wd.manifest_page_num
		, wd.manifest_line
		, wd.manifest_line_id
                
        , w.session_key as session_key, 
        w.session_added as session_added, 
        w.row_num - @start_of_results as row_number, 
        @end_of_results - @start_of_results as record_count 
        from Work_WorkorderListResult w
        join workorderheader wh on w.receipt_id = wh.workorder_id and w.company_id = wh.company_id and w.profit_ctr_id = wh.profit_ctr_id and wh.workorder_status = 'A' and wh.submitted_flag = 'T'
        join workorderdetail wd on wh.workorder_id = wd.workorder_id and wh.profit_ctr_id = wd.profit_ctr_id and wh.company_id = wd.company_id and wd.resource_type = 'D'
        join workorderdetailunit wodu on wd.company_id = wodu.company_id and wd.profit_ctr_ID = wodu.profit_ctr_id and wd.workorder_ID = wodu.workorder_id and wd.sequence_ID = wodu.sequence_id and wodu.billing_flag = 'T'
        join generator g on wh.generator_id = g.generator_id
        join tsdf t on wd.tsdf_code = t.tsdf_code and isnull(t.eq_flag,'F') = 'T'
        join profile p on wd.profile_id = p.profile_id
        join billunit b on wodu.Bill_unit_code = b.bill_unit_code and wodu.billing_flag = 'T'
        left outer join wastetype wt on p.wastetype_id = wt.wastetype_id
        left outer join CodeTransaction ct_p on ct_p.source_type = 'P' and wd.profile_company_id = ct_p.source_company_id and wd.profile_profit_ctr_id = ct_p.source_profit_ctr_id and p.profile_id = ct_p.source_transaction_id and ct_p.code_id = 1
        left outer join CodeTransaction ct_c on ct_c.source_type = 'P' and wd.profile_company_id = ct_c.source_company_id and wd.profile_profit_ctr_id = ct_c.source_profit_ctr_id and p.profile_id = ct_c.source_transaction_id and ct_c.code_id = 2
        left outer join CodeTransaction ct_d on ct_d.source_type = 'P' and wd.profile_company_id = ct_d.source_company_id and wd.profile_profit_ctr_id = ct_d.source_profit_ctr_id and p.profile_id = ct_d.source_transaction_id and ct_d.code_id = 3
        left outer join WorkOrderDetailUnit wodu_lbs_m on wd.company_id = wodu_lbs_m.company_id and wd.profit_ctr_ID = wodu_lbs_m.profit_ctr_id and wd.workorder_ID = wodu_lbs_m.workorder_id and wd.sequence_ID = wodu_lbs_m.sequence_id and wodu_lbs_m.size = 'LBS'
        left outer join WorkOrderDetailUnit wodu_lbs_t on wd.company_id = wodu_lbs_t.company_id and wd.profit_ctr_ID = wodu_lbs_t.profit_ctr_id and wd.workorder_ID = wodu_lbs_t.workorder_id and wd.sequence_ID = wodu_lbs_t.sequence_id and wodu_lbs_t.size = 'TONS'
        left outer join WorkOrderManifest wom on wd.resource_type = 'D' and wd.workorder_id = wom.workorder_id and wd.company_id = wom.company_id and wd.profit_ctr_id = wom.profit_ctr_id and wd.manifest = wom.manifest
        where w.session_key = @session_key
        and exists (
			select 1 from billing bi
			where bi.receipt_id = wh.workorder_id and bi.company_id = wh.company_id and bi.profit_ctr_id = wh.profit_ctr_id and bi.workorder_sequence_id = wd.sequence_id and bi.workorder_resource_type = wd.resource_type and bi.status_code = 'I'
		)

		union

		-- Non Disposal Lines
        select 
        w.receipt_id as workorder_id,
        NULL as 'TSDF_Approval',
        NULL as 'ID_Waste_Description',
        g.generator_name as 'Generator_Name',
        NULL as 'Waste_Type_Description',
        NULL as 'Waste_Type_Category',
        wd.quantity_used as 'Quantity',
        wd.bill_unit_code as 'Unit',
        wd.price as 'Cost',
		round(isnull(wd.quantity_used,0) * isnull(wd.price,0), 2) as 'Total_Cost',
        NULL as 'By_Product_Waste_Index',
        NULL as 'By_Product_Classification',
        NULL as 'By_Product_Disposal_Method',
        g.site_type as 'Generator_Site_Type',
        g.generator_city as 'Generator_City',
        NULL as 'Estimated_Total_Pounds'
        , w.start_date
        , w.end_date

		, case wd.resource_type
			when 'D' then 'Disposal'
			when 'E' then 'Equipment'
			when 'G' then 'Group'
			when 'L' then 'Labor'
			when 'O' then 'Other'
			when 'S' then 'Supplies'
			else wd.resource_type
		end as resource_type
		
		, wd.description description_1
        , wd.description_2
        
        , NULL as manifest_flag
        
		, wd.manifest
		, wd.manifest_page_num
		, wd.manifest_line
		, wd.manifest_line_id
                
        , w.session_key as session_key, 
        w.session_added as session_added, 
        w.row_num - @start_of_results as row_number, 
        @end_of_results - @start_of_results as record_count 
        from Work_WorkorderListResult w
        join workorderheader wh on w.receipt_id = wh.workorder_id and w.company_id = wh.company_id and w.profit_ctr_id = wh.profit_ctr_id and wh.workorder_status = 'A' and wh.submitted_flag = 'T'
        join workorderdetail wd on wh.workorder_id = wd.workorder_id and wh.profit_ctr_id = wd.profit_ctr_id and wh.company_id = wd.company_id and wd.resource_type <> 'D'
        -- join workorderdetailunit wodu on wd.company_id = wodu.company_id and wd.profit_ctr_ID = wodu.profit_ctr_id and wd.workorder_ID = wodu.workorder_id and wd.sequence_ID = wodu.sequence_id and wodu.billing_flag = 'T'
        join generator g on wh.generator_id = g.generator_id
        -- join tsdf t on wd.tsdf_code = t.tsdf_code and isnull(t.eq_flag,'F') = 'T'
        -- join profile p on wd.profile_id = p.profile_id
        -- join billunit b on wodu.Bill_unit_code = b.bill_unit_code and wodu.billing_flag = 'T'
        -- left outer join wastetype wt on p.wastetype_id = wt.wastetype_id
        -- left outer join CodeTransaction ct_p on ct_p.source_type = 'P' and wd.profile_company_id = ct_p.source_company_id and wd.profile_profit_ctr_id = ct_p.source_profit_ctr_id and p.profile_id = ct_p.source_transaction_id and ct_p.code_id = 1
        -- left outer join CodeTransaction ct_c on ct_c.source_type = 'P' and wd.profile_company_id = ct_c.source_company_id and wd.profile_profit_ctr_id = ct_c.source_profit_ctr_id and p.profile_id = ct_c.source_transaction_id and ct_c.code_id = 2
        -- left outer join CodeTransaction ct_d on ct_d.source_type = 'P' and wd.profile_company_id = ct_d.source_company_id and wd.profile_profit_ctr_id = ct_d.source_profit_ctr_id and p.profile_id = ct_d.source_transaction_id and ct_d.code_id = 3
        -- left outer join WorkOrderDetailUnit wodu_lbs_m on wd.company_id = wodu_lbs_m.company_id and wd.profit_ctr_ID = wodu_lbs_m.profit_ctr_id and wd.workorder_ID = wodu_lbs_m.workorder_id and wd.sequence_ID = wodu_lbs_m.sequence_id and wodu_lbs_m.size = 'LBS'
        -- left outer join WorkOrderDetailUnit wodu_lbs_t on wd.company_id = wodu_lbs_t.company_id and wd.profit_ctr_ID = wodu_lbs_t.profit_ctr_id and wd.workorder_ID = wodu_lbs_t.workorder_id and wd.sequence_ID = wodu_lbs_t.sequence_id and wodu_lbs_t.size = 'TONS'
        -- left outer join WorkOrderManifest wom on wd.resource_type = 'D' and wd.workorder_id = wom.workorder_id and wd.company_id = wom.company_id and wd.profit_ctr_id = wom.profit_ctr_id and wd.manifest = wom.manifest
        where w.session_key = @session_key
        and exists (
			select 1 from billing bi
			where bi.receipt_id = wh.workorder_id and bi.company_id = wh.company_id and bi.profit_ctr_id = wh.profit_ctr_id and bi.workorder_sequence_id = wd.sequence_id and bi.workorder_resource_type = wd.resource_type and bi.status_code = 'I'
		) 

        order by row_number


        return
    end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_workorders_lear] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_workorders_lear] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_workorders_lear] TO [EQAI]
    AS [dbo];

