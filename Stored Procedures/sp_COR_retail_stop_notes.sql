--	drop proc sp_COR_retail_stop_notes

go

CREATE PROCEDURE sp_COR_retail_stop_notes
	@web_userid			varchar(100) = '',
    @service_date_from  datetime = '1/1/1900',    -- Beginning Start Date
    @service_date_to	datetime = '1/1/1900',    -- Ending Start Date
    @store_number		varchar(max) = '',
    @generator_name		varchar(max) = '',
    @generator_city		varchar(max) = '',
    @generator_state	varchar(max) = '',
    @generator_region	varchar(max) = '',
    @generator_district	varchar(max) = '',
	@customer_id_list varchar(max)='',  /* Added 2019-07-17 by AA */
    @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */

AS
/* ***************************************************************************************************
sp_COR_retail_stop_notes:

Info:
    Returns the data for Trip Question Notes.  Copied & Modified from sp_eqip_retail_stop_notes.
    LOAD TO PLT_AI

Examples:

	sp_eqip_retail_stop_notes
		@customer_id_list	   = '12113',
		@service_date_from  = '1/1/2010',    -- Beginning Start Date
		@service_date_to	= '5/1/2013',    -- Ending Start Date
		@trip_id_list		= '5604, asdf',
		@status_criteria    = NULL,
		@user_code			= 'JONATHAN',
		@permission_id		= 189,
		@debug              = 0 ,          -- 0 or 1 for no debug/debug mode

select top 100 con.web_userid, h.customer_id, cust.cust_name, wos.date_act_arrive, wos.decline_id, wos.waste_flag
from workorderheader h join workorderstop wos on wos.workorder_id = h.workorder_id
and wos.company_id = h.company_id and wos.profit_ctr_id = h.profit_ctr_id
join contactcorworkorderheaderbucket b on b.workorder_id = h.workorder_id
and b.company_id = h.company_id and b.profit_ctr_id = h.profit_ctr_id
join contact con on b.contact_id = con.contact_id
join customer cust on h.customer_id = cust.customer_id
    INNER JOIN TripHeader th (nolock) ON th.trip_id = h.trip_id and h.company_id = th.company_id AND h.profit_ctr_id = th.profit_ctr_id
    INNER JOIN TripQuestion tq (nolock) ON tq.workorder_id = h.workorder_ID
        AND tq.company_id = h.company_id
        AND tq.profit_ctr_id = h.profit_ctr_id
        AND tq.view_on_web_flag = 'T'
    LEFT OUTER JOIN QuestionCategory qc (nolock) ON tq.question_category_id = qc.question_category_id
LEFT JOIN billing bi on bi.receipt_id = h.workorder_id
and bi.company_id = h.company_id and bi.profit_ctr_id = h.profit_ctr_id
WHERE 1=1
and h.workorder_status NOT IN ('V', 'X', 'T')
and h.submitted_flag = 'F'
and wos.decline_id in (1)
and bi.billing_uid is null
ORDER BY wos.date_act_arrive desc


	sp_COR_retail_stop_notes
	@web_userid			= 'jeff.scott@usecology.com',
    @service_date_from  = '1/1/2021',
    @service_date_to	= '5/1/2021',
    @store_number		= '',
    @generator_name		= '',
    @generator_city		= '',
    @generator_state	= '',
    @generator_region	= '',
    @generator_district	= '',
    @customer_id_list  = '18462',
	@generator_id_list = ''

select * from workorderstop WHERE workorder_id = 23501100 and company_id = 14 and profit_ctr_id = 4	
select distinct waste_flag from workorderstop
    
History:
    08/14/2015 JPB  Created
	09/03/2015 JPB	Added Generator columns
	12/18/2018	JPB	Modified from sp_eqip_retail_stop_notes for COR2 dev
	10/14/2019  DevOps:11600 - AM - Added customer_id and generator_id temp tables and added receipt join.

*************************************************************************************************** */

declare   
 @status_criteria    varchar(200) = 'Invoiced,Declined,Complete,No Waste Picked Up,Complete - Waste Removed,In Process,Scheduled/Confirmed,Scheduled,Unavailable'  
 ,@debug              int = 0  
,@i_contact_id		int
	,@i_customer_id_list	varchar(4000) = isnull(@customer_id_list, '')
    ,@i_generator_id_list	varchar(4000) = isnull(@generator_id_list, '')
	,@i_service_date_from  datetime = convert(date, @service_date_from)  
    ,@i_service_date_to	datetime = convert(date, @service_date_to)  
  
select @i_contact_id = contact_id from CORcontact (nolock) where web_userid = @web_userid  
  
CREATE TABLE #customer (  
 customer_id	bigint
)  
  
if @i_customer_id_list <> ''  
insert #customer select convert(bigint, row)  
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)  
where row is not null  
  
CREATE TABLE #generator_list  (  
 generator_id	bigint 
)  
  
if @i_generator_id_list <> ''  
insert #generator_list select convert(bigint, row)  
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)  
where row is not null  
  
declare @starttime datetime  
set @starttime = getdate()  
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Start' as description  
  
if @i_service_date_to >  '1/1/1900' set @i_service_date_to = @i_service_date_to + 0.99999  
  
-- Status Criteria Filter  
    create table #status_filter (status_filter varchar(50))  
    if datalength((@status_criteria)) > 0 begin  
        Insert #status_filter  
        select rtrim(left(row, 50))  
        from dbo.fn_SplitXsvText(',', 1, @status_criteria)  
        where isnull(row, '') <> ''  
    end  
  
 create table #store_number (generator_id int)  
 create table #city (generator_id int)  
 create table #state (generator_state varchar(2), country varchar(3))  
 create table #region (generator_id int)  
 create table #district (generator_id int)  
   
    if isnull(@store_number, '') <> ''  
    insert #store_number select generator_id from generator (nolock) where site_code in (select row from dbo.fn_SplitXsvText(',', 1, @store_number) where row is not null)  
  
 if isnull(@generator_name, '') <> ''  
 insert #city select generator_id from generator (nolock) join (select row from dbo.fn_SplitXsvText(',', 1, @generator_name) where row is not null) c on generator.generator_name like '%' + replace(c.row, ' ', '%') + '%'  
  
 if isnull(@generator_city, '') <> ''  
 insert #city select generator_id from generator (nolock) join (select row from dbo.fn_SplitXsvText(',', 1, @generator_city) where row is not null) c on generator.generator_city like '%' + replace(c.row, ' ', '%') + '%'  
  
 if isnull(@generator_state, '') <> ''  
 /*  
    insert #state select row from dbo.fn_SplitXsvText(',', 1, @generator_state) where row is not null  
    */  
    insert #state (generator_state, country)  
select sa.abbr, sa.country_code  
from dbo.fn_SplitXsvText(',', 1, @generator_state) x  
join stateabbreviation sa  
on (  
 sa.state_name = x.row and x.row not like '%-%'  
 or  
 sa.abbr = x.row and x.row not like '%-%'  
 or  
 sa.abbr + '-' + sa.country_code = x.row and x.row like '%-%'  
 or  
 sa.country_code  + '-' + sa.abbr= x.row and x.row like '%-%'  
)  
where row is not null  
  
   
    if isnull(@generator_region, '') <> ''  
    insert #region select generator_id from generator where generator_region_code in (select row from dbo.fn_SplitXsvText(',', 1, @generator_region) where row is not null)  
  
    if isnull(@generator_district, '') <> ''  
    insert #district select generator_id from generator where generator_district in (select row from dbo.fn_SplitXsvText(',', 1, @generator_district) where row is not null)  
      
create table #access_filter (  
    company_id int,   
    profit_ctr_id int,   
    workorder_id int,   
    billing_status_info varchar(40)  
)  
  
declare @sql varchar(max) = '', @where varchar(max) = ''  
  
set @sql = '  
    insert #access_filter  
        SELECT w2.company_id,   
        w2.profit_ctr_id,   
        w2.workorder_id,   
        NULL  
    from workorderheader w2 (nolock)   
    join ContactCORWorkorderHeaderBucket sc (nolock)   
  on w2.workorder_id = sc.workorder_id  
  and w2.company_id = sc.company_id  
  and w2.profit_ctr_id = sc.profit_ctr_id  
  and sc.contact_id = ' + convert(Varchar(20), @i_contact_id) + '   
    left join WorkOrderStop wos (nolock)   
  on w2.workorder_id = wos.workorder_id  
  and w2.company_id = wos.company_id   
  and w2.profit_ctr_id = wos.profit_ctr_id  
  and wos.stop_sequence_id = 1  
    '  
  
  
    -- These conditions apply to both versions (associate/non-associate) of the query:  
      
set @where = @where + '  
        WHERE 1=1 /* where-slug */  
        AND w2.workorder_status NOT IN (''V'', ''X'', ''T'')  
    '  
      
    if @i_service_date_from >  '1/1/1900'  
        set @where = replace(@where, '/* where-slug */', ' AND coalesce(wos.date_act_arrive, wos.date_act_depart, w2.start_date) >= ''' + convert(varchar(20), @i_service_date_from) + ''' /* where-slug */')  
  
    if @i_service_date_to >  '1/1/1900'  
        set @where = replace(@where, '/* where-slug */', ' AND coalesce(wos.date_act_arrive, wos.date_act_depart, w2.start_date) <= ''' + convert(varchar(20), @i_service_date_to) + ''' /* where-slug */')  
  
    if @store_number <> ''  
        set @where = replace(@where, '/* where-slug */', ' AND EXISTS (select 1 from generator (nolock) where generator.generator_id = w2.generator_id and generator.site_code in (select row from dbo.fn_SplitXsvText('','', 1, ''' + @store_number+ ''') wher
e row is not null)) /* where-slug */')  
  
 if 0 < (select count(*) from #store_number)  
        set @where = replace(@where, '/* where-slug */', ' AND EXISTS (select 1 from #store_number where generator_id = w2.generator_id) /* where-slug */')  
  
 if 0 < (select count(*) from #city)  
        set @where = replace(@where, '/* where-slug */', ' AND EXISTS (select 1 from #city where generator_id = w2.generator_id) /* where-slug */')  
  
 if 0 < (select count(*) from #state)  
        set @where = replace(@where, '/* where-slug */', ' AND EXISTS (select 1 from generator gs (nolock) join #state s on isnull(nullif(gs.generator_country,''''),''USA'')=s.country and gs.generator_state = s.generator_state where gs.generator_id = w2.
generator_id) /* where-slug */')  
  
 if 0 < (select count(*) from #region)  
        set @where = replace(@where, '/* where-slug */', ' AND EXISTS (select 1 from #region where generator_id = w2.generator_id) /* where-slug */')  
  
 if 0 < (select count(*) from #district)  
        set @where = replace(@where, '/* where-slug */', ' AND EXISTS (select 1 from #district where generator_id = w2.generator_id) /* where-slug */')  
  
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Before filling #accessfilter' as description  
  
    -- Execute the sql that popoulates the #access_filter table.  
    if @debug > 0 select @sql + @where  
  
    exec(@sql + @where)  
      
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After filling #accessfilter' as description  
  
/*  
wos.decline_id:  
-- 4: No waste picked up  
-- 3: service declined at pickup  
-- 2: Service declined ahead of pickup  
-- 1: Not Declined  
*/  
  
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Before Updating #accessfilter' as description  
    -- set the workorder status for the selected items  
    UPDATE f SET f.billing_status_info = CASE   
        WHEN b.status_code = 'I' THEN 'Invoiced'  
        WHEN wos.decline_id IN (2,3) THEN 'Declined'  
        WHEN wos.decline_id in (4) then 'No Waste Picked Up'  
        WHEN (getdate() > wos.date_act_arrive) or (getdate() > h.end_date) THEN 'Complete' +   
   case isnull(wos.waste_flag, '') when 'T' then ' - Waste Removed' else '' end  
        WHEN getdate() BETWEEN h.start_date and h.end_date THEN 'In Process'  
        WHEN getdate() < h.start_date AND wos.confirmation_date IS NOT NULL THEN 'Scheduled/Confirmed'  
        WHEN getdate() < h.start_date THEN 'Scheduled'  
        ELSE 'Unavailable'  
    END    
        FROM #access_filter f  
        INNER JOIN workorderheader h (nolock)   
                on h.workorder_id = f.workorder_id   
                and h.company_id = f.company_id   
                and h.profit_ctr_id = f.profit_ctr_id  
        INNER JOIN WorkOrderStop wos (nolock) ON   
   h.company_id = wos.company_id  
   AND h.profit_ctr_id = wos.profit_ctr_id  
   AND h.workorder_id = wos.workorder_id  
   --AND wos.stop_sequence_id = 1  
        LEFT OUTER join billing b (nolock)   
            on b.receipt_id = h.workorder_id   
            and b.company_id = h.company_id   
            and b.profit_ctr_id = h.profit_ctr_id   
            and b.trans_source = 'W'  
  
  
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Updating #accessfilter' as description  
      
exec('create index af_idx on #access_filter (workorder_id, company_id, profit_ctr_id)')  
  
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After #accessfilter index' as description  
  
if datalength((@status_criteria)) = 0 begin  
 insert #status_filter  
 select distinct billing_status_info from #access_filter  
end  
  
  
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
 gs.code,
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
    inner join workorderheader h (nolock) on h.workorder_id = af.workorder_id and h.company_id = af.company_id and h.profit_ctr_id = af.profit_ctr_id  
    INNER JOIN WorkOrderStop wos (nolock) ON h.workorder_ID = wos.workorder_id  
  AND h.company_id = wos.company_id  
  AND h.profit_ctr_ID = wos.profit_ctr_id  
    INNER JOIN TripHeader th (nolock) ON th.trip_id = h.trip_id and h.company_id = th.company_id AND h.profit_ctr_id = th.profit_ctr_id  
    INNER JOIN TripQuestion tq (nolock) ON tq.workorder_id = h.workorder_ID  
        AND tq.company_id = h.company_id  
        AND tq.profit_ctr_id = h.profit_ctr_id  
        AND tq.view_on_web_flag = 'T'  
    LEFT OUTER JOIN QuestionCategory qc (nolock) ON tq.question_category_id = qc.question_category_id  
    inner join customer c (nolock) on h.customer_id = c.customer_id  
    LEFT OUTER JOIN generator g (nolock) on h.generator_id = g.generator_id  
	LEFT JOIN  GeneratorSubLocation gs (nolock) on h.generator_sublocation_id = gs.generator_sublocation_id
WHERE   
    h.workorder_status NOT IN ('V', 'X', 'T')  
 and   
    (  
   @i_customer_id_list = ''  
   or  
    (  
    @i_customer_id_list <> ''  
    and  
    h.customer_id in (select customer_id from #customer)  
    )  
     )  
   and  
   (  
   @i_generator_id_list = ''  
   or  
   (  
    @i_generator_id_list <> ''  
    and  
    h.generator_id in (select generator_id from #generator_list)  
   )  
    )  
ORDER BY h.company_id, h.profit_ctr_id, h.customer_id, h.workorder_id desc  

END

GO

GRANT EXECUTE ON sp_COR_retail_stop_notes TO EQWEB, COR_USER, EQAI
GO

   