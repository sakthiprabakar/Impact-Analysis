Use PLT_AI
GO

DROP PROCEDURE IF EXISTS [dbo].[sp_COR_FormWCR_List] 
GO 


CREATE PROCEDURE [dbo].[sp_COR_FormWCR_List]  
 @web_userid  varchar(100),  
 @status_list varchar(4000) = 'all',  
 @search   varchar(100) = '',  
 @adv_search  varchar(4000) = '',  
 @generator_size  varchar(75) = '',  
 @generator_name  varchar(75) = '',  
 @generator_site_type varchar(4000) = '',  
 @form_id   varchar(4000) = '', -- Can take a CSV list  
 @waste_common_name varchar(50) = '',  
 @epa_waste_code  varchar(4000) = '', -- Can take a CSV list  
 @copy_status varchar(10) = '',  
 @sort   varchar(20) = 'Modified Date',  
 @page   int = 1,  
 @perpage  int = 20,  
 @excel_output int = 0,  
 @customer_id_list varchar(4000) ='',  /* Added 2019-07-19 by AA */  
 @generator_id_list varchar(4000)='',  /* Added 2019-07-19 by AA */  
 @owner   varchar(5) = 'all', /* 'mine' or 'all' */  
 @period    varchar(4) = '', /* WW, MM, QQ, YY, 30 or 60 days */  
 @tsdf_type   varchar(10) = 'All',  /* 'USE' or 'Non-USE' or 'ALL' */  
 @haz_filter   varchar(20) = 'All'  /* 'All', 'RCRA', 'Non-RCRA', 'State', 'Non-Reg' */  
AS  

BEGIN  
declare  
    @i_web_userid   varchar(100) = isnull(@web_userid, ''),  
    @i_status_list  varchar(4000) = isnull(@status_list, ''),  
    @i_search    varchar(100) = isnull(@search, ''),  
    @i_adv_search   varchar(4000) = isnull(@adv_search, ''),  
 @i_generator_size  varchar(75) = isnull(@generator_size, ''),  
 @i_generator_name  varchar(75) = isnull(@generator_name, ''),  
 @i_generator_site_type  varchar(4000) = isnull(@generator_site_type, ''),  
 @i_form_id   varchar(4000) = isnull(@form_id, ''), -- Can take a CSV list  
 @i_waste_common_name varchar(50) = case when isnull(@waste_common_name, '') = '' then '' else '%' + replace(isnull(@waste_common_name, ''), ' ', '%') + '%' end,  
 @i_epa_waste_code  varchar(4000) = isnull(@epa_waste_code, ''), -- Can take a CSV list  
    @i_copy_status  varchar(10) = isnull(@copy_status, ''),  
    @i_sort    varchar(20) = isnull(@sort, ''),  
    @i_page    int = isnull(@page, 1),  
    @i_perpage   int = isnull(@perpage, 20),  
 @i_totalcount  int,  
    @i_owner    varchar(5) = isnull(@owner, 'all'),  
 @i_contact_id  int,  
    @i_customer_id_list varchar(4000) = isnull(@customer_id_list, ''),  
    @i_generator_id_list varchar(4000) = isnull(@generator_id_list, ''),  
 @i_email varchar(100),  
    @i_period    varchar(4) = isnull(@period, ''),  
    @i_period_int   int = 0,  
    @i_period_date  datetime,  
    @i_excel_output  int = isnull(@excel_output, 0),  
    @i_tsdf_type  varchar(10) = isnull(@tsdf_type, 'USE'),  
    @i_haz_filter  varchar(20) = isnull(@haz_filter, 'All')  
   
-- Temporary re: DO-21083: force @tsdf_type = 'USE'  
--select @tsdf_type = 'USE', @i_tsdf_type = 'USE'  
  
  
  
-- setup defaults, internals, etc.  
select top 1 @i_contact_id = isnull(contact_id, -1)  
, @i_email = email  
from CORcontact (nolock) WHERE web_userid = @i_web_userid  
  
select @i_period_int =  
 case @i_period  
  when 'WW' then datediff(dd, dateadd(ww, -1, getdate()) , getdate())  
  when 'QQ' then datediff(dd, dateadd(qq, -1, getdate()) , getdate())  
  when 'MM' then datediff(dd, dateadd(mm, -1, getdate()) , getdate())  
  when 'YY' then datediff(dd, dateadd(yyyy, -1, getdate()) , getdate())  
  when '30' then 30  
  when '60' then 60  
  else ''  
 end  
  
select @i_period_date =   
 case @i_period   
  when 'WW' then dateadd(ww, -1, getdate())   
  when 'MM' then dateadd(m, -1, getdate())   
  when 'QQ' then dateadd(qq, -1, getdate())   
  when 'YY' then dateadd(yyyy, -1, getdate())   
  when '30' then dateadd(dd, (-1 * @i_period_int), getdate())  
  when '60' then dateadd(dd, (-1 * @i_period_int), getdate())  
  else '1/1/1801'  
 end  
  
  
if isnumeric(@i_period) = 1  
 set @i_period_int = convert(int, @i_period)  
  
  
 IF @i_status_list = 'all'  
  SET @i_status_list = 'Draft,Ready For Submission,Submitted,Pending Customer Response,Pending Signature,CS Created,Accepted,Approved'  
   
  
if @i_sort not in ('Generator Name', 'Profile Number', 'Waste Common Name', 'RCRA Status', 'Modified Date') set @i_sort = ''  
  
  
CREATE TABLE #statusSet (
    display_status VARCHAR(60)
)
INSERT INTO #statusSet
select row from dbo.fn_SplitXsvText(',', 1, @i_status_list) where row is not null  
union select display_status from FormDisplayStatus (nolock) WHERE @i_status_list in ('', 'all')  
  
-- Special case of addition.  When we're looking at submitted, approved profiles can be snuck in later  
-- so let's also sneak 'Approved' into the list  
if exists (select 1 from #statusSet where display_status = 'Submitted')  
 insert into #statusSet values ('Approved')  
  
-- parse inputs into @tables if they were csv  
Create table #generatorsize (  
 generator_type varchar(20)  
)  
if @i_generator_size <> ''  
insert into #generatorsize  
select left(row, 20)  
from dbo.fn_SplitXsvText(',', 1, @i_generator_size)  
-- test output: select * from @generatorsize  
  
-- test values: declare @i_form_id varchar(50) = '1324,abc,1.001,9999999999999'  
Create table #form_ids (  
 form_id bigint  
)  
if @i_form_id <> ''  
insert Into #form_ids  
select convert(bigint, row)  
from dbo.fn_SplitXsvText(',', 1, @i_form_id)  
where isnumeric(row) = 1  
and row not like '%.%'  
-- test output: select * from @profile_ids  
  
-- test values: declare @i_form_id varchar(50) = '1324,abc,1.001,9999999999999'  
CREATE table #wastecodes (  
 waste_code varchar(10)  
)  
if @i_epa_waste_code <> ''  
insert into #wastecodes  
select left(row, 10)  
from dbo.fn_SplitXsvText(',', 1, @i_epa_waste_code)  
-- test output: select * from @profile_ids  
  
Create table #customer (  
 customer_id int  
)  
if @i_customer_id_list <> '' 
insert into #customer select convert(bigint, row)  
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)  
where row is not null  
  
CREATE TABLE #generator (  
 generator_id int  
)  
if @i_generator_id_list <> ''  
insert into #generator select convert(bigint, row)  
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)  
where row is not null  
  
CREATE TABLE #generatorsitetype (  
 site_type varchar(40)  
)  
if @i_generator_site_type <> ''  
insert into #generatorsitetype select left(row, 40)  
from dbo.fn_SplitXsvText(',', 1, @i_generator_site_type)  
where row is not null  
  
-- dealing with form status at a point in time (most recent) here...  
CREATE TABLE #period_data (  
 form_id int  
 , revision_id int  
 , date_added datetime  
 , display_status_uid int  
)  
if @i_period <> '' begin  
 insert into #period_data  
 select y.form_id, y.revision_id, y.date_added, y.display_status_uid  
 from FormWCRStatusAudit y  
 join (  
  select fa.form_id, fa.revision_id, max(fa.FormWCRStatusAudit_uid) max_uid  
  FROM ContactCORFormWCRBucket b (nolock)  
  join FormWCRStatusAudit fa (nolock) on b.form_id = fa.form_id and b.revision_id = fa.revision_id  
  where b.contact_id = @i_contact_id  
  --and fa.display_status_uid = f.display_status_uid  
  GROUP BY fa.form_id, fa.revision_id  
 ) x on x.form_id = y.form_id and x.revision_id = y.revision_id and x.max_uid = y.FormWCRStatusAudit_uid  
 where y.date_added >= @i_period_date  
end  
  
--if @i_form_id = '521954' begin  
-- select @i_period, @i_period_int, @i_period_date  
-- SELECT  * FROM    @period_data WHERE form_id = @i_form_id  
-- SELECT  display_status_uid, * FROM    formwcr WHERE form_id = @i_form_id  
-- SELECT  * FROM    FormDisplayStatus where display_status_uid in (2,8)  
--end  
  
-- baby steps toward identifying keys & easily stored info to speed queries coming after...  
if OBJECT_ID('tempdb..#tempFormKeys') is not null drop table #tempFormKeys  
create table #tempFormkeys (  
 form_id int  
 , revision_id int  
 , display_status_uid int  
 , customer_id int  
 , generator_id int  
 , profile_id int  
 , waste_common_name varchar(50)  
 , generator_name varchar(75)  
 , generator_type varchar(20)  
 , epa_id varchar(12)  
 , cust_name varchar(75)  
 , signing_date datetime  
 , tsdf_type varchar(10)  
)  


;WITH MaxRevisions AS (
    SELECT 
        contact_id, 
        form_id, 
        MAX(revision_id) AS max_revision_id
    FROM ContactCORFormWCRBucket (nolock)
    WHERE contact_id = @i_contact_id
    GROUP BY contact_id, form_id
),
FilteredForms AS (
    SELECT 
        f.form_id,
        f.revision_id,
        f.display_status_uid,
        f.customer_id,
        f.generator_id,
        f.profile_id,
        f.waste_common_name,
        f.generator_name,
        gt.generator_type,
        f.epa_id,
        f.cust_name,
        f.signing_date,
        'USE' AS tsdf_type
    FROM ContactCORFormWCRBucket b (nolock)
    JOIN MaxRevisions maxes 
        ON b.contact_id = maxes.contact_id
        AND b.form_id = maxes.form_id
        AND b.revision_id = maxes.max_revision_id
    JOIN FormWCR f (nolock)
        ON b.form_id = f.form_id
        AND b.revision_id = f.revision_id
    LEFT JOIN GeneratorType gt 
        ON f.generator_type_id = gt.generator_type_id
    JOIN FormDisplayStatus pds (nolock)
        ON f.display_status_uid = pds.display_status_uid
        AND pds.display_status IN (SELECT display_status FROM #statusSet)
    WHERE b.contact_id = @i_contact_id
        AND (
            (@i_owner = 'mine' AND 
                (@i_email IN (f.created_by) OR @i_web_userid IN (f.created_by)))
            OR @i_owner = 'all'
        )
        AND (
            @i_copy_status = '' 
            OR (f.copy_source = @i_copy_status)
        )
        AND (
            @i_form_id = '' 
            OR f.form_id IN (SELECT form_id FROM #form_ids)
        )
        AND (
            @i_waste_common_name = '' 
            OR f.waste_common_name LIKE @i_waste_common_name
        )
        AND (
            @i_customer_id_list = '' 
            OR f.customer_id IN (SELECT customer_id FROM #customer)
        )
        AND (
            @i_generator_id_list = '' 
            OR f.generator_id IN (SELECT generator_id FROM #generator)
        )
        AND (
            (f.display_status_uid = 1 AND 
                f.signing_date IS NULL AND 
                (
                    f.profile_id IS NULL 
                    OR (f.profile_id IS NOT NULL AND f.copy_source IN ('Amendment', 'Renewal', 'csnew', 'resubmited'))
                )
            )
            OR f.display_status_uid <> 1
        )
        AND f.form_id > 0
)
INSERT INTO #tempFormKeys (
    form_id, 
    revision_id, 
    display_status_uid, 
    customer_id, 
    generator_id, 
    profile_id, 
    waste_common_name, 
    generator_name, 
    generator_type, 
    epa_id, 
    cust_name, 
    signing_date, 
    tsdf_type
)
SELECT 
    form_id, 
    revision_id, 
    display_status_uid, 
    customer_id, 
    generator_id, 
    profile_id, 
    waste_common_name, 
    generator_name, 
    generator_type, 
    epa_id, 
    cust_name, 
    signing_date, 
    tsdf_type
FROM FilteredForms;

  
  
--if @i_form_id = '521954' begin  
-- SELECT  *  FROM    #tempFormKeys  
--end  
  
-- SELECT  *  FROM    #tempFormKeys  
  
-- baby step 2: start with the first reduced set of possibles, reduce further on more complex criteria...  
if OBJECT_ID('tempdb..#tempFormKeys2') is not null drop table #tempFormKeys2  
create table #tempFormkeys2 (  
 form_id int  
 , revision_id int  
 , display_status_uid int  
 , customer_id int  
 , generator_id int  
 , profile_id int  
 , waste_common_name varchar(50)  
 , generator_name varchar(75)  
 , epa_id varchar(12)  
 , cust_name varchar(75)  
 , signing_date datetime  
 , status char(1)  
 , date_modified datetime  
 , created_by varchar(60)  
 , modified_by varchar(60)  
 , copy_source varchar(10)  
 , display_status nvarchar(60)  
 , site_type varchar(40)  
 , generator_type varchar(20)  
 , tsdf_type varchar(10)  
  
)  
  
;WITH CTE_SearchResults AS (
    SELECT 
        f.form_id,  
        f.revision_id,  
        f.display_status_uid,  
        f.customer_id,  
        f.generator_id,  
        f.profile_id,  
        f.waste_common_name,  
        COALESCE(gn.generator_name, f.generator_name) AS generator_name,  
        f.epa_id,  
        f.cust_name,  
        f.signing_date,  
        w.status,  
        w.date_modified,  
        w.created_by,  
        w.modified_by,  
        ISNULL(w.copy_source, 'new') AS copy_source,  
        pds.display_status,  
        gn.site_type,  
        ISNULL(gt.generator_type, 'N/A') AS generator_type,  
        f.tsdf_type,
        -- Applying the @i_search condition here
        CONVERT(VARCHAR(20), f.form_id) + ' ' + 
        CONVERT(VARCHAR(20), f.form_id) + '-' + CONVERT(VARCHAR(20), f.revision_id) + ' ' + 
        ISNULL(CONVERT(VARCHAR(20), f.profile_id), '') + ' ' + 
        ISNULL(f.waste_common_name, '') + ' ' +  
        COALESCE(gn.generator_name, f.generator_name, '') + ' ' +  
        COALESCE(gn.epa_id, f.epa_id, '') + ' ' +  
        COALESCE(cn.cust_name, f.cust_name, '') + ' ' +  
        ISNULL((
            SELECT SUBSTRING(
                (
                    SELECT ', ' + ISNULL(pqa.approval_code, '')  
                    FROM profilequoteapproval pqa (NOLOCK)  
                    WHERE pqa.profile_id = f.profile_id  
                    AND f.profile_id IS NOT NULL  
                    AND pqa.status = 'A'  
                    FOR XML PATH('')
                ), 2, 20000)
        ), '') AS full_text
    FROM 
        #tempFormKeys f (NOLOCK)
    JOIN 
        formwcr w ON f.form_id = w.form_id AND f.revision_id = w.revision_id
    JOIN 
        FormDisplayStatus pds (NOLOCK) ON f.display_status_uid = pds.display_status_uid
    LEFT JOIN 
        Customer cn (NOLOCK) ON f.customer_id = cn.customer_id
    LEFT JOIN 
        Generator gn (NOLOCK) ON f.generator_id = gn.generator_id
    LEFT JOIN 
        generatortype gt (NOLOCK) ON COALESCE(gn.generator_type_id, NULLIF(w.generator_type_id, 0)) = gt.generator_type_id
    LEFT JOIN 
        #period_data pd ON f.form_id = pd.form_id AND f.revision_id = pd.revision_id AND f.display_status_uid = pd.display_status_uid
    WHERE
        -- Exclude Templates
        NOT EXISTS (SELECT TOP 1 template_form_id FROM FormWCRTemplate WHERE template_form_id = f.form_id)
)
-- Insert into #tempFormKeys2
INSERT INTO #tempFormKeys2 (
    form_id,  
    revision_id,  
    display_status_uid,  
    customer_id,  
    generator_id,  
    profile_id,  
    waste_common_name,  
    generator_name,  
    epa_id,  
    cust_name,  
    signing_date,  
    status,  
    date_modified,  
    created_by,  
    modified_by,  
    copy_source,  
    display_status,  
    site_type,  
    generator_type,  
    tsdf_type
)
SELECT 
    sr.form_id,  
    sr.revision_id,  
    sr.display_status_uid,  
    sr.customer_id,  
    sr.generator_id,  
    sr.profile_id,  
    sr.waste_common_name,  
    sr.generator_name,  
    sr.epa_id,  
    sr.cust_name,  
    sr.signing_date,  
    sr.status,  
    sr.date_modified,  
    sr.created_by,  
    sr.modified_by,  
    sr.copy_source,  
    sr.display_status,  
    sr.site_type,  
    sr.generator_type,  
    sr.tsdf_type
FROM 
    CTE_SearchResults sr
WHERE
    -- Apply the @i_search condition here as well
    (@i_search = '' OR sr.full_text LIKE '%' + @i_search + '%')

    -- Generator Size Filter
    AND (
        @i_generator_size = '' 
        OR (
            @i_generator_size <> '' 
            AND sr.generator_type IN (SELECT generator_type FROM #generatorsize)
        )
    )

    -- Generator Name Filter
    AND (
        @i_generator_name = '' 
        OR (
            @i_generator_name <> '' 
            AND sr.generator_name LIKE '%' + REPLACE(@i_generator_name, ' ', '%') + '%'
        )
    )

    -- EPA Waste Code Filter
    AND (
        @i_epa_waste_code = '' 
        OR (
            @i_epa_waste_code <> '' 
            AND EXISTS (
                SELECT TOP 1 1 
                FROM formxwastecode pwc (NOLOCK)
                JOIN wastecode wc (NOLOCK) ON pwc.waste_code_uid = wc.waste_code_uid 
                AND wc.display_name IN (SELECT waste_code FROM #wastecodes)
                WHERE pwc.form_id = sr.form_id  
                AND pwc.revision_id = sr.revision_id
            )
        )
    )

    -- Hazard Filter
    AND (
        @i_haz_filter IN ('All', '') 
        OR (
            @i_haz_filter IN ('rcra') 
            AND EXISTS (
                SELECT TOP 1 1 
                FROM formxwastecode pwc (NOLOCK)
                JOIN wastecode wc (NOLOCK) ON pwc.waste_code_uid = wc.waste_code_uid
                AND wc.waste_code_origin = 'F'  
                AND LEFT(wc.display_name, 1) IN ('D', 'F', 'K', 'P', 'U')
                WHERE pwc.form_id = sr.form_id  
                AND pwc.revision_id = sr.revision_id
            )
        )
        OR (
            @i_haz_filter IN ('non-rcra') 
            AND NOT EXISTS (
                SELECT TOP 1 1 
                FROM formxwastecode pwc (NOLOCK)
                JOIN wastecode wc (NOLOCK) ON pwc.waste_code_uid = wc.waste_code_uid
                AND wc.waste_code_origin = 'F'
                AND LEFT(wc.display_name, 1) IN ('D', 'F', 'K', 'P', 'U')
                WHERE pwc.form_id = sr.form_id  
                AND pwc.revision_id = sr.revision_id
            )
        )
        OR (
            @i_haz_filter IN ('state') 
            AND EXISTS (
                SELECT TOP 1 1 
                FROM formxwastecode pwc (NOLOCK)
                JOIN wastecode wc (NOLOCK) ON pwc.waste_code_uid = wc.waste_code_uid
                AND wc.waste_code_origin = 'S'  
                WHERE pwc.form_id = sr.form_id  
                AND pwc.revision_id = sr.revision_id
            )
            AND NOT EXISTS (
                SELECT TOP 1 1 
                FROM formxwastecode pwc (NOLOCK)
                JOIN wastecode wc (NOLOCK) ON pwc.waste_code_uid = wc.waste_code_uid
                AND wc.waste_code_origin = 'F'  
                AND LEFT(wc.display_name, 1) IN ('D', 'F', 'K', 'P', 'U')
                WHERE pwc.form_id = sr.form_id  
                AND pwc.revision_id = sr.revision_id
            )
        )
        OR (
            @i_haz_filter IN ('non-regulated', 'non', 'Non-Reg') 
            AND NOT EXISTS (
                SELECT TOP 1 1 
                FROM formxwastecode pwc (NOLOCK)
                JOIN wastecode wc (NOLOCK) ON pwc.waste_code_uid = wc.waste_code_uid
                AND wc.waste_code_origin IN ('S', 'F')  
                WHERE pwc.form_id = sr.form_id  
                AND pwc.revision_id = sr.revision_id
            )
        )
    )

    -- Generator Site Type Filter
    AND (
        @i_generator_site_type = '' 
        OR (
            @i_generator_site_type <> '' 
            AND sr.site_type IN (SELECT site_type FROM #generatorsitetype)
        )
    )

    -- Period Data Filter
    AND (
        @i_period = '' 
        OR (
            @i_period <> '' AND EXISTS (SELECT 1 FROM #period_data  WHERE form_id = sr.form_id)
        )
    )
  
  
-- SELECT  *  FROM    #tempFormKeys2  
  
  
if OBJECT_ID('tempdb..#tempPendingList') is not null drop table #tempPendingList  
  
create table #tempPendingList (  
 _id    int not null identity(1,1),  
 form_id   int,  
 revision_id  int,  
 profile_id  int,  
 approval_code varchar(max),  
 status   char(1),  
 display_status nvarchar(30),  
 waste_common_name varchar(50),  
 generator_id int,  
 generator_name varchar(75),  
 generator_type varchar(20),  
 epa_id   varchar(12),  
 site_type  varchar(40),  
 customer_id  int,  
 cust_name  varchar(75),  
 date_modified datetime,  
 created_by  varchar(100),  
 modified_by  varchar(100),   
 copy_source  varchar(10),  
 tsdf_type  varchar(10),  
 edit_allowed char(1),  
 _row   int,  
 totalcount  int  
)  
  
-- building on the baby steps, fill the actual table we'll output...  
insert #tempPendingList  
(  
form_id     
,revision_id    
,profile_id    
, approval_code  
,status     
,display_status   
,waste_common_name  
,generator_id   
,generator_name   
,generator_type   
,epa_id     
,site_type    
,customer_id    
,cust_name    
,date_modified   
,created_by    
,modified_by    
,copy_source   
,tsdf_type  
,edit_allowed   
,_row     
,totalcount    
)  
select   
 form_id,  
 revision_id,  
 profile_id,  
 approval_code,  
 status,  
 case when display_status = 'Approved'   
  and profile_id is not null   
  /* -- 6/13/2022, DO-41782  and signing_date between dateadd(mm, -2, getdate()) and getdate()  */  
  and profile_id is not null   
  and ap_expiration_date < getdate()   
  then 'Accepted'   
  else display_status   
  end as display_status,   
 waste_common_name,  
 generator_id,  
 generator_name,  
 generator_type,  
 epa_id,  
 site_type,  
 customer_id,  
 cust_name,  
 date_modified,  
 created_by,  
 modified_by,   
 copy_source,  
 tsdf_type,  
 edit_allowed,  
 _row,  
 0 AS totalcount   
from (  
 select   
  tf.form_id,  
  tf.revision_id,  
  tf.profile_id,  
  case when tf.profile_id is null then null else ( select substring(  
   (  
    select '<br/>' +   
    isnull(pqa.approval_code, '')  
    + ' : ' +  
    isnull(convert(varchar(2),use_pc.company_id), '') + '|' + isnull(convert(varchar(2), use_pc.profit_ctr_id), '')  
    + ' : ' +  
    isnull(use_pc.name, '')  
   FROM profilequoteapproval pqa (nolock)  
   join USE_ProfitCenter use_pc (nolock)  
    on pqa.company_id = use_pc.company_id  
    and pqa.profit_ctr_id = use_pc.profit_ctr_id  
   where pqa.profile_id = tf.profile_id  
   and pqa.status = 'A'  
   order by use_pc.name  
   for xml path, TYPE).value('.[1]','nvarchar(max)'),6,20000)  
  ) end as approval_code,  
  tf.waste_common_name,  
  tf.generator_id,  
  --coalesce(gn.generator_name, tf.generator_name) generator_name,  
  tf.generator_name as generator_name,  
  tf.epa_id,  
  tf.site_type,  
  tf.generator_type,  
  tf.customer_id,  
  tf.cust_name,  
  tf.signing_date,  
  tf.status,  
  p.ap_expiration_date,  
  tf.date_modified,  
  tf.display_status,  
  tf.created_by,  
  (select Top 1 concat(first_name,' ',last_name) from contact where web_userid=tf.modified_by)as modified_by,    
  tf.copy_source,  
  tf.tsdf_type,  
  'T' as edit_allowed,  
  _row = row_number() over (order by   
   case when @i_sort = 'Generator Name' then tf.generator_name end asc,  
   case when @i_sort = 'Profile Number' then tf.form_id end asc,  
   case when @i_sort = 'Waste Common Name' then tf.waste_common_name end asc,  
   case when @i_sort = 'RCRA Status' then tf.generator_type end asc,  
   case when @i_sort in ('', 'Modified Date') then tf.date_modified end desc  
  )   
 from #tempFormKeys2 tf  
 left join profile p on tf.profile_id = p.profile_id and tf.profile_id is not null  
 where 1 = case   
  when p.profile_id is not null   
   and p.curr_status_code not in ('R', 'C', 'H', 'V') then 1  
  when p.profile_id is null then 1  
  else 0  
 end  
) y  
 WHERE case when display_status = 'Approved'   
  and profile_id is not null   
  
  and ap_expiration_date < getdate()   
 then 'Accepted'   
 else display_status   
 end not in ('Approved')  
 and @i_tsdf_type in ('USE', 'ALL')  
  
  
-- Now add results from TSDF Approvals  
  
;WITH HazFilter AS (
    SELECT ta.TSDF_approval_id
    FROM tsdfapproval ta (NOLOCK)
    JOIN tsdf (NOLOCK) ON ta.tsdf_code = tsdf.tsdf_code
    LEFT JOIN tsdfapprovalwastecode pwc (NOLOCK) ON ta.TSDF_approval_id = pwc.TSDF_approval_id
    LEFT JOIN wastecode wc (NOLOCK) ON pwc.waste_code_uid = wc.waste_code_uid
    WHERE 
        @i_haz_filter IN ('All', '')
        OR
        (
            @i_haz_filter IN ('rcra') 
            AND wc.waste_code_origin = 'F' AND LEFT(wc.display_name, 1) IN ('D', 'F', 'K', 'P', 'U')
        )
        OR
        (
            @i_haz_filter IN ('non-rcra') 
            AND (wc.waste_code_origin != 'F' OR LEFT(wc.display_name, 1) NOT IN ('D', 'F', 'K', 'P', 'U'))
        )
),
EpaWasteCodeFilter AS (
    SELECT pwc.TSDF_approval_id
    FROM tsdfapprovalwastecode pwc (NOLOCK)
    JOIN wastecode wc (NOLOCK) ON pwc.waste_code_uid = wc.waste_code_uid
    WHERE wc.display_name IN (SELECT waste_code FROM #wastecodes)
)
INSERT INTO #tempPendingList
(
    form_id, 
    revision_id, 
    profile_id, 
    approval_code, 
    status, 
    display_status, 
    waste_common_name, 
    generator_id, 
    generator_name, 
    generator_type, 
    epa_id, 
    site_type, 
    customer_id, 
    cust_name, 
    date_modified, 
    created_by, 
    modified_by, 
    copy_source, 
    tsdf_type, 
    edit_allowed, 
    _row, 
    totalcount
)
SELECT
    NULL AS form_id,
    NULL AS revision_id,
    ta.tsdf_approval_id AS profile_id,
    ISNULL(ta.tsdf_approval_code, '') + ' : ' + ISNULL(tsdf.tsdf_name, '') AS approval_code,
    ta.TSDF_approval_status AS status,
    'Pending' AS display_status,
    ta.waste_desc AS waste_common_name,
    ta.generator_id,
    gn.generator_name,
    gt.generator_type,
    gn.epa_id,
    gn.site_type,
    ta.customer_id,
    cn.cust_name,
    ta.date_modified,
    ta.added_by,
    ta.modified_by,
    NULL AS copy_source,
    'Non-USE' AS tsdf_type,
    'F' AS edit_allowed,
    ROW_NUMBER() OVER (
        ORDER BY
            CASE WHEN @i_sort = 'Generator Name' THEN gn.generator_name END ASC,
            CASE WHEN @i_sort = 'Profile Number' THEN ta.tsdf_approval_id END ASC,
            CASE WHEN @i_sort = 'Waste Common Name' THEN ta.waste_desc END ASC,
            CASE WHEN @i_sort = 'RCRA Status' THEN gt.generator_type END ASC,
            CASE WHEN @i_sort IN ('', 'Modified Date') THEN ta.date_modified END DESC
    ) AS _row,
    0 AS total_count
FROM tsdfapproval ta (NOLOCK)
JOIN tsdf (NOLOCK) ON ta.tsdf_code = tsdf.tsdf_code
    AND tsdf.tsdf_status = 'A'
    AND ISNULL(tsdf.eq_flag, 'F') = 'F'
JOIN Customer cn (NOLOCK) ON ta.customer_id = cn.customer_id
JOIN Generator gn (NOLOCK) ON ta.generator_id = gn.generator_id
LEFT JOIN generatortype gt (NOLOCK) ON gn.generator_type_id = gt.generator_type_id
WHERE
    (
        ta.customer_id IN (SELECT customer_id FROM ContactCORCustomerBucket WHERE contact_id = @i_contact_id)
        OR
        ta.generator_id IN (SELECT generator_id FROM ContactCORGeneratorBucket WHERE contact_id = @i_contact_id AND direct_flag = 'D')
    )
    AND @i_tsdf_type IN ('Non-USE', 'ALL')
    AND ta.current_approval_status <> 'COMP'
    AND ta.TSDF_approval_status = 'A'
    AND ta.TSDF_approval_expire_date > DATEADD(yyyy, -2, GETDATE())
    AND
    (
        @i_search = ''
        OR
        (
            @i_search <> ''
            AND
            CONVERT(VARCHAR(20), ta.tsdf_approval_id) + ' ' +
            ta.waste_desc + ' ' +
            gn.generator_name + ' ' +
            gn.epa_id + ' ' +
            cn.cust_name + ' ' +
            ISNULL(ta.tsdf_approval_code, '') LIKE '%' + REPLACE(@i_search, ' ', '%') + '%'
        )
    )
    AND
    (
        @i_generator_size = ''
        OR
        (
            @i_generator_size <> ''
            AND gt.generator_type IN (SELECT generator_type FROM #generatorsize)
        )
    )
    AND
    (
        @i_generator_name = ''
        OR
        (
            @i_generator_name <> ''
            AND gn.generator_name LIKE '%' + REPLACE(@i_generator_name, ' ', '%') + '%'
        )
    )
    AND
    (
        @i_waste_common_name = ''
        OR
        (
            @i_waste_common_name <> ''
            AND ta.waste_desc LIKE '%' + REPLACE(@i_waste_common_name, ' ', '%') + '%'
        )
    )
    AND
    (
        @i_epa_waste_code = ''
        OR
        (
            @i_epa_waste_code <> ''
            AND EXISTS (SELECT 1 FROM EpaWasteCodeFilter ef WHERE ef.TSDF_approval_id = ta.TSDF_approval_id)
        )
    )
    AND
    (
        @i_haz_filter IN ('All', '')
        OR
        (
            @i_haz_filter <> ''
            AND EXISTS (SELECT 1 FROM HazFilter hf WHERE hf.TSDF_approval_id = ta.TSDF_approval_id)
        )
    )
    AND
    (
        @i_customer_id_list = ''
        OR
        (
            @i_customer_id_list <> ''
            AND ta.customer_id IN (SELECT customer_id FROM #customer)
        )
    )
    AND
    (
        @i_generator_id_list = ''
        OR
        (
            @i_generator_id_list <> ''
            AND ta.generator_id IN (SELECT generator_id FROM #generator)
        )
    )
    AND
    (
        @i_generator_site_type = ''
        OR
        (
            @i_generator_site_type <> ''
            AND gn.site_type IN (SELECT site_type FROM #generatorsitetype)
        )
    )

-- _row is now incorrectly numbered from multiple inserts.  Fix it.  
update #tempPendingList set _row = n._row  
from #tempPendingList o   
join (  
select _id,  
  _row = row_number() over (order by   
   case when @i_sort = 'Generator Name' then generator_name end asc,  
   case when @i_sort = 'Profile Number' then case when profile_id is not null then profile_id else form_id end end asc,  
   case when @i_sort = 'Waste Common Name' then waste_common_name end asc,  
   case when @i_sort = 'RCRA Status' then generator_type end asc,  
   case when @i_sort in ('', 'Modified Date') then date_modified end desc  
  )   
 from #tempPendingList  
) n  
on o._id = n._id  
  
-- offshore wants the total count as a field in the results.  okay.  
UPDATE #tempPendingList SET totalcount=  ( Select COUNT(totalcount) FROM #tempPendingList )  
  
-- output.  Not excel (w/paging) first, then excel version later.  
if @excel_output = 0  
BEGIN  
 SELECT   
 form_id     
 ,revision_id    
 ,profile_id    
 , approval_code  
 ,status     
 ,display_status   
 ,waste_common_name  
 ,generator_id   
 ,generator_name   
 ,generator_type   
 ,epa_id     
 ,site_type    
 ,customer_id    
 ,cust_name    
 ,date_modified   
 ,created_by    
 ,modified_by    
 ,copy_source   
 ,tsdf_type  
 ,edit_allowed   
 ,_row     
 ,totalcount    
 FROM #tempPendingList  
 where _row between ((@i_page-1) * @i_perpage ) + 1 and (@i_page * @i_perpage)  
 order by _row  
END  
else  
 -- Export to Excel  
  
 select  
  form_id,  
  revision_id,  
  profile_id,   
  approval_code,  
  status,  
  display_status,  
  waste_common_name,  
  generator_id,  
  generator_name,  
  generator_type,  
  epa_id,  
  site_type,  
  customer_id,  
  cust_name,  
  date_modified,  
  created_by,  
  modified_by,   
  copy_source,  
  tsdf_type,  
  _row,  
  totalcount  
  FROM #tempPendingList  
  order by _row  
  
  
DROP TABLE #tempPendingList  
RETURN 0  
  
END;
GO 

GRANT EXEC ON [dbo].[sp_COR_FormWCR_List] TO COR_USER
GO 

GRANT EXECUTE ON [dbo].[sp_COR_FormWCR_List]  TO EQWEB 
GO 

GRANT EXECUTE ON [dbo].[sp_COR_FormWCR_List]  TO EQAI 
GO 