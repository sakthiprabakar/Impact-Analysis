﻿
create procedure sp_rpt_opportunity_loss
	@permission_id int,
	@user_id int,
	@user_code				varchar(20),
	@copc_list				varchar(max) = NULL,
	--@status_list			varchar(100) = NULL,
	@region_id_list			varchar(40) = NULL,
	--@nam_id_list			varchar(40) = NULL,
	@territory_list			varchar(200) = NULL,
	@contact_id_list		varchar(80) = NULL,
	@est_start_date_1		datetime = NULL,
	@est_start_date_2		datetime = NULL,
	@est_end_date_1			datetime = NULL,
	@est_end_date_2			datetime = NULL,
	@act_start_date_1		datetime = NULL,
	@act_start_date_2		datetime = NULL,
	@act_end_date_1			datetime = NULL,
	@act_end_date_2			datetime = NULL,
	@mod_start_date			datetime = NULL,
	@mod_end_date			datetime = NULL

/*-------------------------------------------------------------------------------------------------

06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)

*/
AS
BEGIN

SET @est_start_date_1		= cast(convert(varchar(10),@est_start_date_1,101) as datetime)
SET @est_start_date_2		= cast(convert(varchar(10),@est_start_date_2,101) + ' 23:59:59' as datetime)
SET @est_end_date_1			= cast(convert(varchar(10),@est_end_date_1,101) as datetime)
SET @est_end_date_2			= cast(convert(varchar(10),@est_end_date_2,101)  + ' 23:59:59' as datetime)
SET @act_start_date_1		= cast(convert(varchar(10),@act_start_date_1,101) as datetime)
SET @act_start_date_2		= cast(convert(varchar(10),@act_start_date_2,101) + ' 23:59:59' as datetime)
SET @act_end_date_1			= cast(convert(varchar(10),@act_end_date_1,101) as datetime)
SET @act_end_date_2			= cast(convert(varchar(10),@act_end_date_2,101) + ' 23:59:59' as datetime)
SET @mod_start_date			= cast(convert(varchar(10),@mod_start_date,101) as datetime)
SET @mod_end_date			= cast(convert(varchar(10),@mod_end_date,101) + ' 23:59:59' as datetime)


if @copc_list = '' or @copc_list = 'All'
	set @copc_list = null
	
--if @status_list = '' or @status_list = 'All'
--	set @status_list = null
	
if @region_id_list = '' or @region_id_list = 'All'
	set @region_id_list = null
	
--if @nam_id_list = '' or @nam_id_list = 'All'
--	set @nam_id_list = null

if @territory_list = '' or @territory_list = 'All'
	set @territory_list = null
		
if @contact_id_list = '' or @contact_id_list = 'All'
	set @contact_id_list = NULL

create table #tbl_copc_list ( [company_id] int, profit_ctr_id int )
CREATE TABLE #tbl_status_list (id varchar(10))
CREATE TABLE #tbl_region_list (id int)
CREATE TABLE #tbl_nam_list (id int)
CREATE TABLE #tbl_territory_list (id varchar(10))
CREATE TABLE #tbl_contact_id_list (id int)

--declare @status_list varchar(100) = 'A,V,C,D,E,F'
--INSERT INTO #tbl_status_list
--	SELECT LTRIM(RTRIM(row)) as row from dbo.fn_SplitXsvText(',', 0, @status_list) WHERE  Isnull(row, '') <> ''
	
INSERT INTO #tbl_region_list
	SELECT LTRIM(RTRIM(row)) as row from dbo.fn_SplitXsvText(',', 0, @region_id_list) WHERE  Isnull(row, '') <> ''	
	
--INSERT INTO #tbl_nam_list
--	SELECT LTRIM(RTRIM(row)) as row from dbo.fn_SplitXsvText(',', 0, @nam_id_list) WHERE  Isnull(row, '') <> ''	
	
INSERT INTO #tbl_territory_list
	SELECT LTRIM(RTRIM(row)) as row from dbo.fn_SplitXsvText(',', 0, @territory_list) WHERE  Isnull(row, '') <> ''	
	
INSERT INTO #tbl_contact_id_list
	SELECT LTRIM(RTRIM(row)) as row from dbo.fn_SplitXsvText(',', 0, @contact_id_list) WHERE  Isnull(row, '') <> ''				
	

	
INSERT #tbl_copc_list
SELECT secured_copc.company_id,
       secured_copc.profit_ctr_id
FROM   SecuredProfitCenter secured_copc
       INNER JOIN (SELECT Rtrim(Ltrim(Substring(row, 1, Charindex('|', row) - 1)))                                      company_id,
                          Rtrim(Ltrim(Substring(row, Charindex('|', row) + 1, Len(row) - ( Charindex('|', row) - 1 )))) profit_ctr_id
                   from dbo.fn_SplitXsvText(',', 0, @copc_list)
                   WHERE  Isnull(row, '') <> '') selected_copc
         ON secured_copc.company_id = selected_copc.company_id
            AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
            AND secured_copc.permission_id = @permission_id
            AND secured_copc.user_code = @user_code 

if (SELECT COUNT(*) FROM #tbl_copc_list) = 0 AND LEN(@copc_list) = 0
BEGIN
	INSERT #tbl_copc_list
	SELECT secured_copc.company_id,
		   secured_copc.profit_ctr_id
	FROM   SecuredProfitCenter secured_copc
			WHERE secured_copc.permission_id = @permission_id
				AND secured_copc.user_code = @user_code 			
END

create table #tbl_opp_ids (opp_id int)

INSERT INTO #tbl_opp_ids
SELECT DISTINCT opp_id FROM OppFacility a
	INNER JOIN #tbl_copc_list b ON a.company_id = b.company_id
	AND a.profit_ctr_id = b.profit_ctr_id


declare @search_sql varchar(max) = ''
declare @where varchar(max) = ''


set @search_sql = '
SELECT 
	o.Opp_id,
	o.customer_id,
	c.cust_name,
	o.territory_code,
	t.territory_desc,
	r.region_desc,
	o.Opp_name,
	o.opp_city,
	o.opp_state,
	o.opp_county,
	o.opp_country,
	o.loss_comments,
	o.loss_reason,
	o.description,
	o.service_type,
	jobtype.description as job_type,
	salestype.description as salestype,
	servicetype.description as servicetype,
	o.status,
	s.description as status_text,
	o.generator_name,
	o.est_revenue,
	o.probability,
	isnull(actual_start_date, est_start_date) as start_date,
	isnull(actual_end_date, est_end_date) as end_date,
	o.date_modified,
	mu.user_name as modified_by,
	o.region_id,
	o.nam_id,
	nam.user_name as nam_user_name
from 
	Opp o
	inner join #tbl_opp_ids x on o.Opp_id = x.Opp_id
	left outer join OppJobType jobtype on o.job_type = jobtype.code
	left outer join OppStatusLookup s on o.status = s.code and s.type = ''Opp''
	left outer join contact on o.contact_id = contact.contact_id
	left outer join OppSalesType salestype on o.sales_type = salestype.code
	left outer join OppServiceType servicetype on o.service_type = servicetype.code
	left outer join Users mu on o.modified_by = mu.user_code
	left outer join Users omu on o.opp_manager = omu.user_code
	left outer join UsersXEQContact uxeq on o.nam_id = uxeq.type_id and uxeq.eqcontact_type = ''nam''
	left outer join Users nam on uxeq.user_code = nam.user_code
	left outer join Region r on o.region_id = r.region_id
	left outer join territory t on o.territory_code = t.territory_code
	LEFT JOIN Customer c ON o.customer_id = c.customer_id
	--LEFT JOIN OppFacility opf ON opf.opp_id = o.opp_id
WHERE 1=1	
AND status = ''L''

'

	if @territory_list IS NOT NULL
	BEGIN
		set @where = @where + ' and exists (select customer_id 
			from customerbilling 
			where customer_id = c.customer_id 
			and billing_project_id = 0 
			and territory_code is not null 
			and convert(int, territory_code) in (SELECT id FROM #tbl_territory_list))'
	END
	
	
	
	declare @newline varchar(10) = CHAR(13) + CHAR(10)
	if @region_id_list IS NOT NULL
		set @where = @where + 'and o.region_id in (SELECT Id from #tbl_region_list) ' + @newline
	
	--if @status_list IS NOT NULL
	--	set @where = @where + 'and o.status in (SELECT id FROM #tbl_status_list) ' + @newline
	
	--if @nam_id_list IS NOT NULL
	--	set @where = @where + 'and o.nam_id in (SELECT id FROM #tbl_nam_list) ' + @newline
	
	if @contact_id_list IS NOT NULL
		set @where = @where + 'and o.contact_id in (SELECT id FROM #tbl_contact_id_list) ' + @newline
	
	if @est_start_date_1 IS NOT NULL
		set @where = @where + 'and o.Est_start_date >= ''' + CONVERT(varchar(20), @est_start_date_1, 120) + ''' ' + @newline
		
	if @est_start_date_2 IS NOT NULL
		set @where = @where + 'and o.Est_start_date <= ''' + CONVERT(varchar(20), @est_start_date_2, 120) + ''' ' + @newline

	IF @est_end_date_1 is not null
		set @where = @where + 'and o.Est_End_date >= ''' + CONVERT(varchar(20), @est_end_date_1, 120) + ''' ' + @newline
		
	IF @est_end_date_2 is not null
		set @where = @where + 'and o.Est_End_date <= ''' + CONVERT(varchar(20), @est_end_date_2, 120) + ''' ' + @newline

	IF @act_start_date_1 is not null
		set @where = @where + 'and o.actual_start_date >= ''' + CONVERT(varchar(20), @act_start_date_1, 120) + ''' ' + @newline
		
	IF @act_start_date_2 is not null
		set @where = @where + 'and o.actual_start_date <= ''' + CONVERT(varchar(20), @act_start_date_2, 120) + ''' ' + @newline

	IF @act_end_date_1 is not null
		set @where = @where + 'and o.actual_end_date >= ''' + CONVERT(varchar(20), @act_end_date_1, 120) + ''' ' + @newline
		
	IF @act_end_date_2 is not null
		set @where = @where + 'and o.actual_end_date <= ''' + CONVERT(varchar(20), @act_end_date_2, 120) + ''' ' + @newline

	if @mod_start_date is not null
		set @where = @where + 'and o.date_modified >= ''' + CONVERT(varchar(20), @mod_start_date, 120) + ''' ' + @newline
		
	if @mod_end_date is not null
		set @where = @where + 'and o.date_modified <= ''' + CONVERT(varchar(20), @mod_end_date, 120) + ''' ' + @newline

declare @order_by varchar(100) = ' order by o.opp_id'


exec(@search_sql + @where + @order_by)

                
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_opportunity_loss] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_opportunity_loss] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_opportunity_loss] TO [EQAI]
    AS [dbo];

