create procedure sp_rpt_opportunity_status
	@permission_id int,
	@user_id int,
	@user_code				varchar(20),
	@status_list			varchar(100) = NULL,
	@region_id_list			varchar(40) = NULL,
	@nam_id_list			varchar(40) = NULL,
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
	@mod_end_date			datetime = NULL,
	@add_start_date			datetime = NULL,
	@add_end_date			datetime = NULL
AS
BEGIN
/* **********************************************************************************
sp_rpt_opportunity_status - A copy of sp_rpt_opportunity_data
	but without all that extra row goofiness due to facility splits.

test?
test:
sp_rpt_opportunity_status 202, 637, 'jonathan', 'O'

********************************************************************************** */

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
SET @add_start_date			= cast(convert(varchar(10),@add_start_date,101) as datetime)
SET @add_end_date			= cast(convert(varchar(10),@add_end_date,101) + ' 23:59:59' as datetime)


declare @copc_list varchar(max) = null
	
if @status_list = '' or @status_list = 'All' or @status_list is null
	set @status_list = null
	
if @region_id_list = '' or @region_id_list = 'All' or @region_id_list is null or @region_id_list = '-1'
	set @region_id_list = null
	
if @nam_id_list = '' or @nam_id_list = 'All' or @nam_id_list is null or @nam_id_list = '-1'
	set @nam_id_list = null

if @territory_list = '' or @territory_list = 'All' or @territory_list is null
	set @territory_list = null
		
if @contact_id_list = '' or @contact_id_list = 'All' or @contact_id_list is null
	set @contact_id_list = NULL

create table #tbl_copc_list ( [company_id] int, profit_ctr_id int )
CREATE TABLE #tbl_status_list (id varchar(10))
CREATE TABLE #tbl_region_list (id int)
CREATE TABLE #tbl_nam_list (id int)
CREATE TABLE #tbl_territory_list (id varchar(10))
CREATE TABLE #tbl_contact_id_list (id int)

--declare @status_list varchar(100) = 'A,V,C,D,E,F'
INSERT INTO #tbl_status_list
	SELECT LTRIM(RTRIM(row)) as row from dbo.fn_SplitXsvText(',', 0, @status_list) WHERE  Isnull(row, '') <> ''
	
INSERT INTO #tbl_region_list
	SELECT LTRIM(RTRIM(row)) as row from dbo.fn_SplitXsvText(',', 0, @region_id_list) WHERE  Isnull(row, '') <> ''	
	
INSERT INTO #tbl_nam_list
	SELECT LTRIM(RTRIM(row)) as row from dbo.fn_SplitXsvText(',', 0, @nam_id_list) WHERE  Isnull(row, '') <> ''	
	
INSERT INTO #tbl_territory_list
	SELECT LTRIM(RTRIM(row)) as row from dbo.fn_SplitXsvText(',', 0, @territory_list) WHERE  Isnull(row, '') <> ''	
	
INSERT INTO #tbl_contact_id_list
	SELECT LTRIM(RTRIM(row)) as row from dbo.fn_SplitXsvText(',', 0, @contact_id_list) WHERE  Isnull(row, '') <> ''				

	
INSERT #tbl_copc_list
	SELECT secured_copc.company_id,
		   secured_copc.profit_ctr_id
	FROM   SecuredProfitCenter secured_copc
			WHERE secured_copc.permission_id = @permission_id
				AND secured_copc.user_code = @user_code 			

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
	o.description,
	o.service_type,
	dbo.fn_opp_company_name_list(o.Opp_id) as facility_list,
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
	contact.name,
	contact.phone,
	contact.email,
	contact.web_access_flag,
	isnull(omu.user_name, o.Opp_manager) as opp_manager,
	o.proposal_due_date,
	o.date_awarded,
	o.est_start_date,
	o.est_end_date,
	o.actual_start_date,
	o.actual_end_date,
	dbo.fn_customer_territory_list(o.customer_id),
	o.region_id,
	o.nam_id,
	nam.user_name as nam_user_name,
	o.contact_id,
	o.scale_job_size,
	o.scale_cust_size,
	o.scale_odds,
	o.scale_profitability,
	o.scale_bidders,
	o.scale_competency,
	o.scale_eq_pct,
	users_added_by.user_name as opp_added_by,
	uxeq_added_by.EQContact_Type as opp_added_by_EQContact_Type,
	o.date_added as opp_date_added,	
	users_mod_by.user_name as opp_modified_by,
	o.date_modified as opp_date_modified
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
	left outer join UsersXEQContact uxeq_added_by ON uxeq_added_by.user_code = o.added_by
	left outer join Users users_added_by ON users_added_by.user_code = o.added_by
	left outer join Users users_mod_by ON users_mod_by.user_code = o.modified_by
	   LEFT JOIN Customer c ON o.customer_id = c.customer_id
WHERE 1=1	
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
	
	if @status_list IS NOT NULL
		set @where = @where + 'and o.status in (SELECT id FROM #tbl_status_list) ' + @newline
	
	if @nam_id_list IS NOT NULL
		set @where = @where + 'and o.nam_id in (SELECT id FROM #tbl_nam_list) ' + @newline
	
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

	if @add_start_date is not null
		set @where = @where + 'and o.date_added >= ''' + CONVERT(varchar(20), @add_start_date, 120) + ''' ' + @newline
		
	if @add_end_date is not null
		set @where = @where + 'and o.date_added <= ''' + CONVERT(varchar(20), @add_end_date, 120) + ''' ' + @newline

declare @order_by varchar(100) = ' order by o.opp_id DESC'



--print @search_sql + @where + @order_by
exec(@search_sql + @where + @order_by)

                
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_opportunity_status] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_opportunity_status] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_opportunity_status] TO [EQAI]
    AS [dbo];

