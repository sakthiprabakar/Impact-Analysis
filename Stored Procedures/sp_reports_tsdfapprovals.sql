CREATE PROCEDURE sp_reports_tsdfapprovals 
 @debug    int,    -- 0 or 1 for no debug/debug mode  
 @tsdf_approval_id   int = NULL, -- the profile ot see details on.  only used when report_type = 'D'  
 @company_id  int = NULL, -- only used when report_type = 'D'  
 @profit_ctr_id int = NULL, -- only used when report_type = 'D'  
 @contact_id varchar(10) -- required, 0 for associates, -1 for vendors
AS  
/****************************************************************************************************  
Returns the data for TSDF Approvals - straight copy of sp_reports_profiles, then started adapting table sources and yanking pricing out.

sp_reports_tsdfapprovals 0, 77579 , 14 , 6 , 0
sp_reports_tsdfapprovals 0,'21983','21','0' ,0
sp_reports_tsdfapprovals 0,'21983','21','0' , 0

SELECT * FROM tsdfapproval
 where tsdf_approval_status = 'A'
 and company_id = 21 and profit_ctr_id = 0

select top 20 * from tsdfapprovalwastecode

sp_reports_tsdfapprovals 
 @debug    = 0,
 @profile_id    = '25756', -- 343472: ACIDS.   327176 = WMHW01  
 @company_id   = '2', 
 @profit_ctr_id  = '0'
  
SELECT  * FROM    ProfileQuoteDetail where profile_id is not null and hours_free_unloading is not null
  
LOAD TO PLT_AI*  

02/23/2017	JPB	Copied from sp_reports_profiles and modified  

****************************************************************************************************/  
SET NOCOUNT ON  
-- SET QUERY_GOVERNOR_COST_LIMIT 20  
  
SET NOCOUNT ON  
SET ANSI_WARNINGS OFF  
  
declare 
	@starttime 	datetime,
	@sql		varchar(8000)
	
set @starttime = getdate()  
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Start' as description  
  
-- Define Access Filter -- Associates can see everything.  Customers can only see records tied to their explicit (or related) customer_id and generator_id assignments  

create table #access_filter (  
	ID int IDENTITY,  
	company_id int,   
	profit_ctr_id int,   
	tsdf_approval_id int
)

create index idx_af on #access_filter (tsdf_approval_id, company_id, profit_ctr_id)

IF len(@contact_id) > 0 and @contact_id not in ('0', '-1') BEGIN
	-- Customer/Generator version
 
	set @sql = '
		-- 1: explicit customers
			select DISTINCT
				ta.company_id,
				ta.profit_ctr_id,
				ta.tsdf_approval_id
			from TSDFApproval ta (nolock)
				inner join ContactXRef CXR WITH (nolock) ON ta.customer_id = CXR.customer_id AND CXR.contact_id = ' + @contact_id  + ' AND CXR.type = ''C'' AND CXR.status = ''A'' AND CXR.web_access = ''A''
				/* JOIN SLUG */
				inner join profitcenter pfc (nolock) on ta.company_id = pfc.company_id and ta.profit_ctr_id = pfc.profit_ctr_id and pfc.status = ''A'' and isnull(pfc.view_on_web, ''F'') <> ''F'' and isnull(pfc.view_approvals_on_web, ''F'') = ''T''
				inner join company co (nolock) on ta.company_id = co.company_id and co.view_on_web = ''T''
			WHERE ta.tsdf_approval_status = ''A''
				/* WHERE SLUG */
			UNION
		-- 2: explicit generators
			select DISTINCT
				ta.company_id,
				ta.profit_ctr_id,
				ta.tsdf_approval_id
			from TSDFApproval ta (nolock)
				inner join ContactXRef CXR WITH (nolock) ON ta.generator_id = CXR.generator_id AND CXR.contact_id = ' + @contact_id  + ' AND CXR.type = ''G'' AND CXR.status = ''A'' AND CXR.web_access = ''A''
				/* JOIN SLUG */
				inner join profitcenter pfc (nolock) on ta.company_id = pfc.company_id and ta.profit_ctr_id = pfc.profit_ctr_id and pfc.status = ''A'' and isnull(pfc.view_on_web, ''F'') <> ''F'' and isnull(pfc.view_approvals_on_web, ''F'') = ''T''
				inner join company co (nolock) on ta.company_id = co.company_id and co.view_on_web = ''T''
			WHERE ta.tsdf_approval_status = ''A''
				/* WHERE SLUG */
			UNION
		-- 3: generators via customergenerator x explicit customers
			select DISTINCT
				ta.company_id,
				ta.profit_ctr_id,
				ta.tsdf_approval_id
			from TSDFApproval ta (nolock)
				inner join CustomerGenerator cg (nolock) on ta.generator_id = cg.generator_id
				inner join ContactXRef CXR WITH (nolock) ON cg.customer_id = CXR.customer_id AND CXR.contact_id = ' + @contact_id + ' and CXR.type = ''C'' AND CXR.status = ''A'' AND CXR.web_access = ''A''
				/* JOIN SLUG */
				inner join profitcenter pfc (nolock) on ta.company_id = pfc.company_id and ta.profit_ctr_id = pfc.profit_ctr_id and pfc.status = ''A'' and isnull(pfc.view_on_web, ''F'') <> ''F'' and isnull(pfc.view_approvals_on_web, ''F'') = ''T''
				inner join company co (nolock) on ta.company_id = co.company_id and co.view_on_web = ''T''
			WHERE ta.tsdf_approval_status = ''A''
				/* WHERE SLUG */
		'

END ELSE BEGIN
	-- Associate version
 
	set @sql = '
		SELECT ta.company_id, ta.profit_ctr_id, ta.tsdf_approval_id 
		FROM TSDFApproval ta (nolock)
		/* JOIN SLUG */
		inner join profitcenter pfc (nolock) on ta.company_id = pfc.company_id and ta.profit_ctr_id = pfc.profit_ctr_id and pfc.status = ''A'' and isnull(pfc.view_on_web, ''F'') <> ''F'' and isnull(pfc.view_approvals_on_web, ''F'') = ''T''
		inner join company co (nolock) on ta.company_id = co.company_id and co.view_on_web = ''T''
		WHERE ta.tsdf_approval_status = ''A''
		/* WHERE SLUG */
		'		
END

set @sql = 'Insert #Access_filter ' + @sql

if @debug > 3 print @sql
if @debug > 3 select @sql as AccessFilter_query

exec (@sql)

if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After #AccessFilter' as description

-- select * from #access_filter

/*
--RJG:  Jonathan (JPB) Moved calculated fields to the final select to increase performance
INSERT Work_ProfileListResult (  
	company_id,   
	approval_code,   
	profile_id,   
	customer_id,   
	approval_desc,   
	ots_flag,   
	ap_expiration_date,   
	generator_id,   
	cust_name,   
	generator_name,   
	epa_id,   
	reapproval_allowed,   
	broker_flag,   
	pqa_company_id,   
	pqa_profit_ctr_id,   
	confirm_update_date,   
	session_key,   
	session_added,
	orig_customer_id
)  
SELECT DISTINCT  
	af.company_id,  
	pqa.approval_code,  
	ta.profile_id,  
	ta.customer_id,  
	ta.approval_desc,  
	ta.ots_flag,  
	ta.ap_expiration_date,  
	ta.generator_id,  
	cust.cust_name,  
	gen.generator_name,  
	gen.epa_id,  
	ta.reapproval_allowed,  
	ta.broker_flag,  
	pqa.company_id as pqa_company_id,  
	pqa.profit_ctr_id as pqa_profit_ctr_id,   
	pqa.confirm_update_date,  
	@session_key as session_key,  
	GETDATE() as session_added,
	ta.orig_customer_id
FROM 
	#access_filter af   WITH(NOLOCK)  
	INNER JOIN Profile ta   WITH(NOLOCK) ON af.profile_id = ta.profile_id  
	INNER JOIN ProfileQuoteApproval pqa  WITH(NOLOCK)  on ta.profile_id = pqa.profile_id 
		and af.company_id = pqa.company_id AND pqa.status = 'A'   
	INNER JOIN ProfitCenter pfc  WITH(NOLOCK)  ON pqa.company_id = pfc.company_id  
		AND pqa.profit_ctr_id = pfc.profit_ctr_id  
		AND pfc.status = 'A' 
		AND isnull(pfc.view_on_web, 'F') <> 'F' 
		AND isnull(pfc.view_approvals_on_web, 'F') = 'T'  
	INNER JOIN Company c  WITH(NOLOCK) on c.company_id = pqa.company_id AND c.view_on_web = 'T'  
	INNER JOIN Customer cust  WITH(NOLOCK)  ON ta.customer_id = cust.customer_id  
	INNER JOIN Generator gen  WITH(NOLOCK)  ON ta.generator_id = gen.generator_id  
	INNER JOIN ProfileQuoteDetail pqd  WITH(NOLOCK)  on ta.profile_id = pqd.profile_id AND pqd.record_type = 'D'   
WHERE ta.curr_status_code = 'A'  
ORDER BY   
	pqa_company_id, 
	pqa_profit_ctr_id, 
	cust.cust_name, 
	gen.generator_name, 
	pqa.approval_code  


if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Work_ProfileListResult insert' as description  
*/

returnresults: -- Re-queries with an existing session_key that passes validation end up here.  So do 1st runs (with an empty, now brand-new session_key)  
  
	set nocount off  

/*  
	select  
		ta.company_id, 
		ta.profit_ctr_id,
		ta.tsdf_approval_code, 
		ta.tsdf_approval_id, 
		ta.customer_id, 
		ta.waste_desc, 
		ta.tsdf_approval_expire_date, 
		ta.generator_id, 
		customer.cust_name, 
		generator.generator_name, 
		generator.epa_id,   
		tsdf.tsdf_name, 
	FROM 
		#access_filter af   WITH(NOLOCK)  
		INNER JOIN TSDFApproval ta  WITH(NOLOCK) ON af.tsdf_approval_id = ta.tsdf_approval_id  
		INNER JOIN Customer (nolock) ON ta.customer_id = customer.customer_id    
		INNER JOIN Generator (nolock) ON ta.generator_id = Generator.generator_id    
	where 
		ta.session_key = @session_key  
		and ta.row_num >= @start_of_results + @row_from  
		and ta.row_num <= case when @row_to = -1 then @end_of_results else @start_of_results + @row_to end  
	order by 
		ta.row_num    
  
if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After RS1 Select-out' as description  
*/
  
     if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'Begin Detail Select' as description  

	-- Main Info Select    
	SELECT    
		ta.tsdf_approval_id,
		ta.tsdf_approval_expire_date,
        ta.waste_desc,
        ta.generating_process,
        ta.dot_shipping_name,
        ta.manifest_dot_sp_number,
        CONVERT(varchar(5), ta.erg_number) + ISNULL(ta.erg_suffix, '') AS erg_number,
        ta.hazmat,    
        ta.hazmat_class,    
        -- ta.ldr_subcategory,    
        ta.waste_water_flag,
        ta.package_group,    
        ta.un_na_flag,    
        ta.un_na_number,    
           
        ta.tsdf_approval_code,    
        ta.LDR_required,    
        ta.company_id,    
        ta.profit_ctr_id,    
           
        ta.consistency
        ,ta.pH_range

		, ta.waste_managed_id           
        ,ldrwm.waste_managed_flag     
         + '. - <u>'     
         + convert(varchar(8000), ldrwm.underlined_text)     
         + '</u> ' + convert(varchar(8000), ldrwm.regular_text)     
         as waste_managed_flag,    
        ldrwm.contains_listed,    
        ldrwm.exhibits_characteristic,    
        ldrwm.soil_treatment_standards,    
           
        cust.customer_id,    
        cust.cust_name,    
           
        gen.epa_id,    
        gen.gen_mail_addr1,    
        gen.gen_mail_addr2,    
        gen.gen_mail_addr3,    
        gen.gen_mail_addr4,    
        gen.gen_mail_city,    
        gen.gen_mail_name,    
        gen.gen_mail_state,    
        gen.gen_mail_zip_code,    
        gen.generator_address_1,    
        gen.generator_address_2,    
        gen.generator_address_3,    
        gen.generator_address_4,    
        gen.generator_city,    
        gen.generator_fax,    
        gen.generator_id,    
        gen.generator_name,    
        gen.generator_phone,    
        gen.generator_state,    
        gen.generator_zip_code,    
            
   		tsdf.tsdf_name

		,ta.subsidiary_haz_mat_class	--subsidiary_haz_mat_class
		,ta.reportable_quantity_flag	--reportable_quantity_flag
		,ta.rq_reason
             
	FROM
		#access_filter af
        JOIN TSDFApproval ta (nolock) on af.tsdf_approval_id = ta.tsdf_approval_id
        INNER JOIN TSDF tsdf (nolock) on ta.tsdf_code = tsdf.tsdf_code
        INNER JOIN Customer cust (nolock) ON ta.customer_id = cust.customer_id    
        INNER JOIN Generator gen  (nolock) ON ta.generator_id = gen.generator_id    
        LEFT OUTER JOIN LDRWasteManaged ldrwm (nolock) 	ON ta.waste_managed_id = ldrwm.waste_managed_id    
             
	WHERE 1=1    
        AND ta.tsdf_approval_id = @tsdf_approval_id    
        AND ta.company_id = @company_id
        AND ta.profit_ctr_id = @profit_ctr_id

   if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Main Info Select' as description  
      

	-- Constituents Info Select    
	SELECT    
		prco.uhc,    
		prco.concentration,    
		prco.unit,    
		    
		cons.const_desc,    
		cons.ldr_id    
	FROM    
		#access_filter af
        JOIN TSDFApprovalConstituent prco     (nolock) on af.tsdf_approval_id = prco.tsdf_approval_id
		INNER JOIN Constituents cons     (nolock) 
			ON prco.const_id = cons.const_id    
	WHERE    
		prco.tsdf_approval_id = @tsdf_approval_id    

	if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Constituents Info Select' as description  
	
	-- Waste Codes Select      
	SELECT    
		display_name as waste_code
	FROM    
		#access_filter af
        JOIN TSDFApprovalWasteCode pwc  (nolock) on af.tsdf_approval_id = pwc.tsdf_approval_id
		INNER JOIN Wastecode wc (nolock) on pwc.waste_code_uid = wc.waste_code_uid
	WHERE    
		pwc.tsdf_approval_id = @tsdf_approval_id    
    order by 
        case when wc.waste_code_origin = 'F' AND left(display_name, 1) = 'D' then 1 else
            case when wc.waste_code_origin = 'F' AND left(display_name, 1) = 'P' then 2 else
                case when wc.waste_code_origin = 'F' AND left(display_name, 1) = 'U' then 3 else
                    case when wc.waste_code_origin = 'F' AND left(display_name, 1) = 'K' then 4 else
                        case when wc.waste_code_origin = 'F' AND left(display_name, 1) = 'F' then 5 else
                            6
                        end
                    end
                end
            end
        end
        , wc.display_name

	
	if @debug > 3 select datediff(ms, @starttime, getdate()) as timer, 'After Waste Codes Select' as description  

        

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_tsdfapprovals] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_reports_tsdfapprovals] TO [COR_USER]
    AS [dbo];


