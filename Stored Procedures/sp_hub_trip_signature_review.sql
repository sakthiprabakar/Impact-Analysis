use plt_ai
go

drop proc if exists sp_hub_trip_signature_review
go

create proc sp_hub_trip_signature_review (
    @copc_list			varchar(max) = NULL, -- ex: 21|1,14|0,14|1)
    @customer_id_list   varchar(max) = NULL,           -- Comma Separated Customer ID List - what customers to include
    @service_date_from  datetime = NULL,    -- Beginning Start Date
    @service_date_to	datetime = NULL,    -- Ending Start Date
    @trip_id_list		varchar(max) = NULL,
    @manifest_list		varchar(max) = NULL,
	@user_code			varchar(20),
	@permission_id		int,
    @debug              int = 0            -- 0 or 1 for no debug/debug mode
)
as
/* *********************************************************************

Inputs
Company ID, Profit Center ID, Trip ID?  
Date of service / date of signature?  
Customer ID (so you could run the report for other customers?)
generator # and manifest/BOL # 
*/

/* only where wos.date_act_arrive is populated
3.	Do you only want work orders in a certain status?  
a.	Please use all statuses where a service start date has been entered. Which screens are you pulling this from? Just the work order?
b.	We noticed in the data set that there were records that were missing manifest/BOL numbers and dates or site codes. Do you know what that might have happened. 

4.	Do you only want hazardous manifests?  Do you care about non-haz / BOLs?
a.	Please pull both the manifest and non-haz BOL as well. 

Extra question: 
Is there a way for this report to show if an initial scan has been completed? If not that is fine, but if we can it might be useful. 


    08/09/2021  JPB DO:22019 - add generator_state, receipt_date

exec sp_hub_trip_signature_review 
    @copc_list			= 'ALL',
    @customer_id_list   = '15551',
    @service_date_from  = '1/1/2021',    -- Beginning Start Date
    @service_date_to	= '5/1/2021',    -- Ending Start Date
    @trip_id_list		= '',
    @manifest_list		= '',
	@user_code			= 'JONATHAN',
	@permission_id		=299,
    @debug              = 0            -- 0 or 1 for no debug/debug mode
    
********************************************************************* */

create table #profit_center_filter(
    company_id int,
    profit_ctr_id int
)
    
INSERT #profit_center_filter
-- declare @copc_list varchar(max) = 'ALL', @user_code varchar(20) = 'jonathan', @permission_id int = 299
	SELECT distinct secured_copc.company_id, secured_copc.profit_ctr_id
		FROM SecuredProfitCenter secured_copc
		JOIN (
			SELECT
				RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
				RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
			from dbo.fn_SplitXsvText(',', 0, @copc_list)
			where isnull(row, '') <> '' ) selected_copc 
			ON 	secured_copc.company_id = selected_copc.company_id 
				AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
			AND secured_copc.user_code = @user_code
			AND secured_copc.permission_id = @permission_id    
			and @copc_list <> 'ALL'			
	union
	SELECT distinct secured_copc.company_id, secured_copc.profit_ctr_id
		FROM SecuredProfitCenter secured_copc
		where secured_copc.user_code = @user_code
		AND secured_copc.permission_id = @permission_id    
		and @copc_list = 'ALL'			
	
	
	SELECT DISTINCT customer_id, cust_name INTO #Secured_Customer
		FROM SecuredCustomer sc WHERE sc.user_code = @user_code
		and sc.permission_id = @permission_id						

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

-- Manifests:
	-- set @trip_id_list = replace(@trip_id_list, ' ', ',')
    create table #manifest_list (manifest varchar(20))
    if datalength((isnull(@manifest_list, ''))) > 0 begin
        Insert #manifest_list
        select row
        from dbo.fn_SplitXsvText(',', 0, @manifest_list)
        where isnull(row, '') <> ''
    end

create table #access_filter (
    company_id int, 
    profit_ctr_id int, 
    workorder_id int, 
    manifest varchar(20)
)

declare @sql varchar(max) = '', @where varchar(max) = ''

set @sql = '
    insert #access_filter
        SELECT distinct w2.company_id, 
        w2.profit_ctr_id, 
        w2.workorder_id 
       ' + 
       case when datalength((isnull(@manifest_list, ''))) > 0 then '
        ,wod.manifest
       ' else ', null'
      end + '
    from workorderheader w2
    join #profit_center_filter pcf
		on w2.company_id = pcf.company_id
		and w2.profit_ctr_id = pcf.profit_ctr_id
    join #Secured_Customer sc
		on w2.customer_id = sc.customer_id ' + 
       case when datalength((isnull(@manifest_list, ''))) > 0 then '
	left join workorderdetail wod
		on w2.workorder_id = wod.workorder_id
		and w2.company_id = wod.company_id 
		and w2.profit_ctr_id = wod.profit_ctr_id
		and wod.resource_type = ''D''
		and wod.bill_rate > -2
		and wod.manifest not like ''%manifest%''
       ' else ''
      end + '
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

    if (select count(*) from #manifest_list) > 0
    begin
        set @sql = @sql + ' inner join #manifest_list ml on wod.manifest = ml.manifest '
    end

    -- These conditions apply to both versions (associate/non-associate) of the query:
    
    set @where = @where + '
        WHERE 1=1 /* where-slug */
        AND w2.workorder_status NOT IN  (''V'', ''T'', ''X'', ''C'')
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

exec('create index af_idx on #access_filter (workorder_id, company_id, profit_ctr_id)')

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After #accessfilter index' as description


declare @initial_manifest_types table (type_id int)
insert @initial_manifest_types
select type_id 
from plt_image.dbo.ScanDocumentType where document_type like '%initial%manifest%'

select --top 1000 
--(select count(*) from workorderdetail (nolock)  where bill_rate > -2 and workorder_id = woh.workorder_id and company_id = woh.company_id and profit_ctr_id = woh.profit_ctr_id and manifest = wom.manifest) as 'Count of Approvals',
Wos.Date_Act_Arrive,
wos.Date_Act_Depart,
woh.Workorder_Status,
woh.Submitted_Flag,
woh.Date_Submitted,
Isnull(g.Site_Code, '') As 'Site_Code', 
Isnull(wom.Generator_Sign_Name, '') As 'Generator_Sign_Name', 
Isnull(wom.Generator_Sign_Date, '') As 'Generator_Sign_Date', 
Isnull(wom.Manifest, '') As 'Manifest', 
Wom.Manifest_Flag,
Wom.Manifest_State,
G.EPA_Id, 
Gt.Generator_Type,
woh.Company_ID,
woh.Profit_Ctr_ID,
woh.Trip_Id,
woh.Trip_Sequence_ID,
woh.Workorder_ID,
woh.Customer_ID,
c.Cust_Name,
woh.Generator_ID,
g.Generator_Name,
g.generator_state,
(select Distinct Tsdf_Code From Workorderdetail Where Workorder_Id = Woh.Workorder_Id And Company_Id = Woh.Company_Id And Profit_Ctr_Id = Woh.Profit_Ctr_Id And Manifest = Wom.Manifest) As 'TSDF',
woh.Billing_Project_ID,
cb.Project_Name,
case when exists (
	select top 1 1 
	from plt_image.dbo.Scan s
	join plt_image.dbo.ScanImage si on s.image_id = si.image_id
		and si.image_blob is not null
	WHERE 
	s.type_id in (select type_id from @initial_manifest_types)
	and s.document_source = 'workorder'
		and s.workorder_id = woh.workorder_id
		and s.company_id = woh.company_id
		and s.profit_ctr_id = woh.profit_ctr_id
		and s.status = 'A'
) then 'Yes' else 'No' end as Initial_Scan_Exists
--doc Type Haz/nonhaz/bol

,(
    select min(r.receipt_date)
    from receipt r (nolock)
    join billinglinklookup bll (nolock)
    on r.receipt_id = bll.receipt_id
    and r.company_id = bll.company_id
    and r.profit_ctr_id = bll.profit_ctr_id
    where 
    bll.source_id  = woh.workorder_id
    and bll.source_company_id = woh.company_id
    and bll.source_profit_ctr_id = woh.profit_ctr_ID
    and r.receipt_status not in ('V', 'R')
) as receipt_date

--, *
FROM #access_filter f
INNER JOIN workorderheader woh (nolock)
        on woh.workorder_id = f.workorder_id 
        and woh.company_id = f.company_id 
        and woh.profit_ctr_id = f.profit_ctr_id
join generator g (nolock) 
	on woh.generator_id = g.generator_id
left outer join generatortype gt (nolock) 
	on g.generator_type_id = gt.generator_type_id
join workordermanifest wom (nolock) 
	on woh.company_id = wom.company_id 
	and woh.profit_ctr_id = wom.profit_ctr_id
	and woh.workorder_id = wom.workorder_id
	and isnull(wom.manifest, '') = case when datalength((isnull(@manifest_list, ''))) > 0 then f.manifest
        else isnull(wom.manifest, '')
	end
join workorderstop wos (nolock) 
	on woh.company_id = wos.company_id 
	and woh.profit_ctr_id = wos.profit_ctr_id
	and woh.workorder_id = wos.workorder_id
join customer c (nolock)  
	on woh.customer_id = c.customer_id
join customerbilling cb (nolock) 
	on woh.customer_id = cb.customer_id 
	and woh.billing_project_id = cb.billing_project_id
where 1=1 
-- and woh.customer_id = 15622
and woh.workorder_status not in ('v', 't', 'x', 'c')
and wos.date_act_arrive is not null
and 0 < (select count(*) from workorderdetail (nolock) where bill_rate > -2 and workorder_id = woh.workorder_id and company_id = woh.company_id and profit_ctr_id = woh.profit_ctr_id and manifest = wom.manifest)
order by wos.date_act_arrive desc


GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_trip_signature_review TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_trip_signature_review TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].sp_hub_trip_signature_review TO [EQAI]
    AS [dbo];

