Create Procedure SP_Opp_Search2 (
	@Debug					int = 0,
	@user_code				varchar(20) = '',
	@Opp_id					int = -1,	-- Opp ID
	@facility_list			varchar(8000) = '',	-- Comma Separated Facility List
	@Opp_name				varchar(50) = '',
	@StatusList				varchar(8000) = '',
	@CustIdList				varchar(8000) = '',
	@cust_name				varchar(40) = '',
	@TerritoryList			varchar(8000) = '',
	@ContactIdList			varchar(80) = '',
	@generator_name			varchar(40) = '',
	@EstStartDate1			varchar(30) = '',
	@EstStartDate2			varchar(30) = '',
	@EstEndDate1			varchar(30) = '',
	@EstEndDate2			varchar(30) = '',
	@ActualStartDate1		varchar(30) = '',
	@ActualStartDate2		varchar(30) = '',
	@ActualEndDate1			varchar(30) = '',
	@ActualEndDate2			varchar(30) = '',
	@ModStartDate			varchar(30) = '',
	@ModEndDate				varchar(30) = '',
	@Description			varchar(40) = '',
	@ModifiedByList			varchar(8000) = '',
	@RegionIdList			varchar(40) = '', --CMA Added 07/25/08 Can be a comma separated list of int
	@NamIdList				varchar(40) = '', --CMA Added 07/25/08 Can be a comma separated list of int
	@responsible_user_code  varchar(20) = '', 
	@userkey				varchar(255) = '',	-- userkey, rowfrom and rowto aren't "where clause" inputs - they're select specifications for resultsets.  They should come last in the input list.
	@rowfrom				int = -1,
	@rowto					int = -1
)
AS
/************************************************************
	Procedure    : SP_Opp_Search
	Database     : PLT_AI*
	Created      : Tue May 02 12:30:00 EST 2006 - Jonathan Broome
	Description  : Searches for Opp entries
 ************************************************************
	12/27/2007 JPB Created from copy of sp_funnel_search
									-----------------------------------------------
									--BEG test section
									-----------------------------------------------
									declare @Debug					int,
										@opp_id				int,	-- Opp ID
										@facility_list			varchar(8000),	-- Comma Separated Facility List
										@Opp_name		varchar(50),
										@StatusList				varchar(8000),
										@CustIdList				varchar(8000),
										@cust_name				varchar(40),
										@TerritoryList			varchar(8000),
										@ContactIdList			varchar(80),
										@generator_name			varchar(40),
										@EstStartDate1			varchar(30),
										@EstStartDate2			varchar(30),
										@EstEndDate1			varchar(30),
										@EstEndDate2			varchar(30),
										@ActualStartDate1		varchar(30),
										@ActualStartDate2		varchar(30),
										@ActualEndDate1			varchar(30),
										@ActualEndDate2			varchar(30),
										@ModStartDate			varchar(30),
										@ModEndDate				varchar(30),
										@Description			varchar(40),
										@ModifiedByList			varchar(8000),
										@RegionIdList			varchar(10), --CMA Added 07/25/08 
										@NamIdList				varchar(10) --CMA Added 07/25/08 
										@userkey				varchar(255),
										@rowfrom				int,
										@rowto					int,

									select @Debug = 0, @userkey = '', @rowfrom = -1, @rowto = 40 
									-- select @opp_id = 4294
									-- select @modifiedbyList = 'ryan_h'
									-- select @facility_list = '03-01'
									-- select @statuslist = 'O, C'
									-- select @custidlist = '888888'
									-- select @cust-name = 'test'
								  -- select @RegionIdList = '0,1,2,3,4,5'
								  -- select @NamIdList = '4,5,6'

									exec SP_Opp_Search @Debug, @opp_id, @facility_list, @Opp_name, @StatusList, @CustIdList, @cust_name, @TerritoryList, @ContactIdList, @generator_name, @EstStartDate1, @EstStartDate2, @EstEndDate1, @EstEndDate2, @ActualStartDate1, @ActualStartDate2, @ActualEndDate1, @ActualEndDate2, @ModStartDate, @ModEndDate, @Description, @ModifiedByList, @RegionIdList, @NamIdList, @userkey, @rowfrom, @rowto
									-----------------------------------------------
									--END Test section
									-----------------------------------------------

	12/27/2007 Chris Allen  - Added region_id and nam_id as sp input arguments
													- Filters by region_id and nam_id
													- Left Joins 
	4/19/2011	RJG	- Added new search criteria (responsible_user)
	08/08/2011	RJG	- Made it a left join because customer_id is no longer required initially

************************************************************/
set nocount on
declare	@insert	varchar(8000),
		@sql varchar(8000),
		@where varchar(8000),
		@sqlfinal varchar(8000),
		@intcount int,
		@order varchar(8000)

if @ActualStartDate1 <> '' set @ActualStartDate1 = @ActualStartDate1 + ' 00:00:00.000'
if @ActualStartDate2 <> '' set @ActualStartDate2 = @ActualStartDate2 + ' 23:59:59.998'
if @ActualEndDate1 <> '' set @ActualEndDate1 = @ActualEndDate1 + ' 00:00:00.000'
if @ActualEndDate2 <> '' set @ActualEndDate2 = @ActualEndDate2 + ' 23:59:59.998'

if @EstStartDate1 <> '' set @EstStartDate1 = @EstStartDate1 + ' 00:00:00.000'
if @EstStartDate2 <> '' set @EstStartDate2 = @EstStartDate2 + ' 23:59:59.998'
if @EstEndDate1 <> '' set @EstEndDate1 = @EstEndDate1 + ' 00:00:00.000'
if @EstEndDate2 <> '' set @EstEndDate2 = @EstEndDate2 + ' 23:59:59.998'

if @ModStartDate <> '' set @ModStartDate = @ModStartDate + ' 00:00:00.000'
if @ModEndDate <> '' set @ModEndDate = @ModEndDate + ' 23:59:59.998'

-- Check for a userkey. If it exists, we're re-accessing existing rows. If not, this is new.
if @userkey <> ''
begin
	select @userkey = case when exists (select userkey from work_OppSearch where userkey = @userkey) then @userkey else '' end
end

if @userkey = ''
begin
	set @userkey = newid()
	if @rowfrom = -1 set @rowfrom = 1
	if @rowto = -1 set @rowto = 20
	
	-- Create a temp table to hold the database list to query
		CREATE TABLE #tmp_database (
			company_id	int,
			profit_ctr_id	int)
			
	-- Populate the #tmp_database table
		DECLARE	@pos		int,
			@pcpos			int,
			@database		varchar(30),
			@company		varchar(30),
			@profitcenter	varchar(30),
			@tmp_list		varchar(8000)
	
		SELECT @tmp_list = REPLACE(@facility_list, ' ', '') 
		 
		IF @debug = 1 PRINT 'facility List: ' + @facility_list
		SELECT @pos = 0
		WHILE DATALENGTH(@tmp_list) > 0
		BEGIN
			-- Look for a comma
			SELECT @pos = CHARINDEX(',', @tmp_list)
			IF @debug = 1 PRINT 'Pos: ' + CONVERT(varchar(10), @pos)
		
			-- If we found a comma, there is a list of databases
			IF @pos > 0
			BEGIN
				SELECT @database = SUBSTRING(@tmp_list, 1, @pos - 1)
				SELECT @tmp_list = SUBSTRING(@tmp_list, @pos + 1, DATALENGTH(@tmp_list) - @pos)
				IF @debug = 1 PRINT 'facility: ' + CONVERT(varchar(30), @database) 
		 
			END
		
			-- If we did not find a comma, there is only one database or we are at the end of the list
			IF @pos = 0
			BEGIN
				SELECT @database = @tmp_list
				SELECT @tmp_list = NULL
				IF @debug = 1 PRINT 'facility: ' + CONVERT(varchar(30), @database)
			END
		
			-- Check for ProfitCenter attachment
			SELECT @pcpos = CHARINDEX('-', @database)
			IF @pcpos > 0
			BEGIN
				SELECT @company = LEFT(@database, @pcpos -1)
				SELECT @profitcenter = REPLACE(@database, @company+'-', '')
			END
			ELSE
			BEGIN
				SELECT @company = @database 
		 
				SELECT @profitcenter = null
			END
		
			-- Insert into table
			INSERT #tmp_database
			SELECT
				p.company_id,
				p.profit_ctr_id
			FROM
				profitcenter p
			WHERE
				p.company_id = CONVERT(int, @company)
				AND p.profit_ctr_id = CONVERT(int, @profitcenter)
		END
		SELECT @tmp_list = REPLACE(@facility_list, ' ', '') 
	IF @debug >= 1 SELECT * FROM #tmp_database
	
	set @insert = 'insert work_OppSearch (Opp_id, ins_date, userkey, territory_list, date_added, mod_date, cust_name, Opp_name) ' 
	set @sql = ' SELECT DISTINCT
		f.Opp_id,
		getdate(),
		''' + @userkey + ''' as userkey,
		dbo.fn_customer_territory_list(f.customer_id) as territory_list,
		f.date_added,
		f.date_modified,
		c.cust_name,
		f.Opp_name '
	set @sql = @sql + ' from Opp f
		left join customer c on f.customer_id = c.customer_id and c.cust_status = ''A''
		left outer join OppFacility x on f.Opp_id = x.Opp_id '

	IF DATALENGTH(@tmp_list) > 0
		set @sql = @sql + ' inner join #tmp_database t on x.company_id = t.company_id and x.profit_ctr_id = t.profit_ctr_id ' 

   if DATALENGTH(@ModifiedByList) > 0
		set @sql = @sql + ' inner join users u on f.modified_by = u.user_code 
      inner join (select row from dbo.fn_SplitXsvText('','', 1, ''' + @ModifiedByList + ''') where isnull(row, '''') <> '''') ModifiedBy on (u.user_code like ''%'' + ModifiedBy.row + ''%'' or u.user_name like ''%'' + ModifiedBy.row + ''%'') 
      '

	set @sql = @sql + '	where 1=1 '
	set @where = ''
	set @order = ' order by f.date_modified desc, f.date_added desc, territory_list, c.cust_name, f.Opp_name'

	if @Opp_id <> -1
		set @where = @where + 'and f.Opp_id = ' + convert(varchar(15), @opp_id) 
	
	--if len(@user_code) > 0
	--	set @where = @where + 'and f.added_by = ''' + @user_code + ''' '
		
	if len(@Opp_name) > 0
		set @where = @where + 'and f.Opp_name like ''%' + replace(replace(@Opp_name, ' ', '%'), '''', '''''') + '%'' '
	
	if len(@StatusList) > 0
		set @where = @where + 'and f.status in (select row from dbo.fn_SplitXsvText('','', 1, ''' + @StatusList + ''') where isnull(row, '''') <> '''') '
	
	if len(@CustIdList) > 0
		set @where = @where + 'and f.customer_id in (select row from dbo.fn_SplitXsvText('','', 1, ''' + @CustIdList + ''') where isnull(row, '''') <> '''') '
	
	if len(@cust_name) > 0
		set @where = @where + 'and c.cust_name like ''%' + replace(replace(@cust_name, ' ', '%'), '''', '''''') + '%'' '
	
	if len(@TerritoryList) > 0
		set @where = @where + 'and exists (select customer_id from customerbilling where customer_id = c.customer_id and billing_project_id = 0 and territory_code is not null and convert(int, territory_code) in (select convert(int, row) from dbo.fn_SplitXsvText('','', 1, ''' + @TerritoryList + ''') where isnull(row, '''') <> '''')) '
	
	if len(@ContactIdList) > 0
		set @where = @where + 'and f.contact_id in (select row from dbo.fn_SplitXsvText('','', 1, ''' + @ContactIdList + ''') where isnull(row, '''') <> '''') '
	
	if len(@generator_name) > 0
		set @where = @where + 'and f.generator_name like ''%' + replace(replace(@generator_name, ' ', '%'), '''', '''''') + '%'' '

	if len(@EstStartDate1) > 0
		set @where = @where + 'and f.Est_start_date >= ''' + @EstStartDate1 + ''' '
		
	if len(@EstStartDate2) > 0
		set @where = @where + 'and f.Est_start_date <= ''' + @EstStartDate2 + ''' '

	if len(@EstEndDate1) > 0
		set @where = @where + 'and f.Est_End_date >= ''' + @EstEndDate1 + ''' '
		
	if len(@EstEndDate2) > 0
		set @where = @where + 'and f.Est_End_date <= ''' + @EstEndDate2 + ''' '

	if len(@ActualStartDate1) > 0
		set @where = @where + 'and f.actual_start_date >= ''' + @ActualStartDate1 + ''' '
		
	if len(@ActualStartDate2) > 0
		set @where = @where + 'and f.actual_start_date <= ''' + @ActualStartDate2 + ''' '

	if len(@ActualEndDate1) > 0
		set @where = @where + 'and f.actual_End_date >= ''' + @ActualEndDate1 + ''' '
		
	if len(@ActualEndDate2) > 0
		set @where = @where + 'and f.actual_End_date <= ''' + @ActualEndDate2 + ''' '

	if len(@ModStartDate) > 0
		set @where = @where + 'and f.date_modified >= ''' + @ModStartDate + ''' '
		
	if len(@ModEndDate) > 0
		set @where = @where + 'and f.date_modified <= ''' + @ModEndDate + ''' '

	if len(@Description) > 0
		set @where = @where + 'and f.description like ''%' + replace(replace(@Description, ' ', '%'), '''', '''''') + '%'' '

	--BEG CMA 07/25/08 Added lines (below)
	if len(@RegionIdList) > 0
		set @where = @where + 'and f.region_id in (select row from dbo.fn_SplitXsvText('','', 1, ''' + @RegionIdList + ''') where isnull(row, '''') <> '''') '

	if len(@NamIdList) > 0
		set @where = @where + 'and f.nam_id in (select row from dbo.fn_SplitXsvText('','', 1, ''' + @NamIdList + ''') where isnull(row, '''') <> '''') '
	--END CMA 07/25/08 Added lines (above)
	
	-- if we're searching for the responsible person,
	-- check if they are set as the responsible_user, user_code, 
	-- have a customer in a territory that is assigned to them and/or nam
	if len(@responsible_user_code) > 0
	begin
		set @where = @where + 'and (	
			f.responsible_user_code = ''' + @responsible_user_code + ''' 
			or f.added_by = ''' + @responsible_user_code + ''' 
			or f.modified_by = ''' + @responsible_user_code + ''' 
		)'
	end
	
	---- if the user is an AE, then filter out results by their territories
	--if @user_code is not null and LEN(@user_code) > 0
	--begin
	--	if (SELECT COUNT(*) FROM UsersXEQContact uxe WHERE user_code = @user_code
	--		and EQcontact_type = 'AE') > 0
	--	begin
	--		set @where = @where + ' and exists (SELECT 1 from 
	--			CustomerBilling tmp_cb 
	--			JOIN UsersXEQContact tmp_uc ON tmp_cb.territory_code = tmp_uc.territory_code
	--				AND tmp_uc.user_code = ''' + @user_code + ''' 
	--				AND tmp_uc.EQContact_Type IN (''AE'')
	--				WHERE c.customer_id = tmp_cb.customer_id
	--				AND f.customer_id = c.customer_id
	--				and tmp_cb.billing_project_id = 0
	--			)'
	--	end
	--end
	
	--SELECT * FROM UsersXEQContact

	set @sqlfinal = @insert + @sql + @where + @order
		
	if @debug >= 1
		begin
			print @sqlfinal
			select @sqlfinal
		end

	-- Load the work_OppSearch table with ids's
	exec (@sqlfinal)

    declare @mindummy int
    select @mindummy = min(dummy) from work_OppSearch  where userkey = @userkey
    update work_OppSearch set ins_row = (dummy - @mindummy + 1) where userkey = @userkey

end

select @intcount = count(*) from work_OppSearch where userkey = @userkey

set nocount off

-- Select out the info for the rows requested.

SELECT DISTINCT
	f.Opp_id,
	f.customer_id,
	x.cust_name,
	f.territory_code,
	t.territory_desc,
	r.region_desc,
	f.Opp_name,
	cast(f.description as varchar(max)) as description,
	dbo.fn_opp_company_name_list(f.Opp_id) as facility_list,
	jobtype.description as job_type,
	salestype.description as salestype,
	servicetype.description as servicetype,
	f.status,
	s.description as status_text,
	f.generator_name,
	f.est_revenue,
	f.probability,
	isnull(actual_start_date, est_start_date) as start_date,
	isnull(actual_end_date, est_end_date) as end_date,
	f.date_modified,
	mu.user_name as modified_by,
	contact.name,
	contact.phone,
	contact.email,
	contact.web_access_flag,
	isnull(omu.user_name, f.Opp_manager) as opp_manager,
	f.proposal_due_date,
	f.date_awarded,
	f.est_start_date,
	f.est_end_date,
	f.actual_start_date,
	f.actual_end_date,
	x.territory_list,
	f.territory_code as customer_territory_code,
	f.region_id,
	f.nam_id,
	nam_user_name = (SELECT TOP 1 tmp_u.user_name FROM CustomerBilling x 
			JOIN UsersXEQContact ux ON 
				x.billing_project_id = 0
				AND x.NAM_id = f.nam_id
				AND x.NAM_id = ux.type_id
				and ux.EQcontact_type = 'NAM'
				JOIN users tmp_u ON ux.user_code = tmp_u.user_code
			),
   ae_user_code = (SELECT TOP 1 ux.user_code FROM CustomerBilling x 
			JOIN UsersXEQContact ux ON ux.territory_code = x.territory_code
				and x.billing_project_id = 0
				and ux.EQcontact_type = 'AE'
			where x.customer_id = f.customer_id
			)
   ,ae_user_name = (SELECT TOP 1 u.user_name FROM CustomerBilling x 
		JOIN UsersXEQContact ux ON ux.territory_code = x.territory_code
			and x.billing_project_id = 0
			and ux.EQcontact_type = 'AE'
		JOIN Users u ON ux.user_code = u.user_code
		where x.customer_id = f.customer_id
		)			,
	f.contact_id,
	f.scale_job_size,
	f.scale_cust_size,
	f.scale_odds,
	f.scale_profitability,
	f.scale_bidders,
	f.scale_competency,
	f.scale_eq_pct,
	f.responsible_user_code,
	x.userkey,
	x.ins_row,
	@intcount as record_count,
	f.date_added,
	f.date_modified,
	f.added_by,
	f.modified_by
	
from 
	Opp f
	inner join work_OppSearch  x on f.Opp_id = x.Opp_id
	left JOIN CustomerBilling cb ON f.customer_id = cb.customer_id
		and cb.billing_project_id = 0	
	left outer join OppJobType jobtype on f.job_type = jobtype.code
	left outer join OppStatusLookup s on f.status = s.code and s.type = 'Opp'
	left outer join contact on f.contact_id = contact.contact_id
	left outer join OppSalesType salestype on f.sales_type = salestype.code
	left outer join OppServiceType servicetype on f.service_type = servicetype.code
	left outer join Users mu on f.modified_by = mu.user_code
	left outer join Users omu on f.opp_manager = omu.user_code
	--left outer join UsersXEQContact uxeq on f.nam_id = uxeq.type_id and uxeq.eqcontact_type = 'nam'
	--left outer join Users nam on uxeq.user_code = nam.user_code
	left outer join Region r on COALESCE(f.region_id, cb.region_id) = r.region_id
	left outer join territory t on cb.territory_code = t.territory_code
	--left outer join UsersXEQContact uxeq_ae ON cb.territory_code = uxeq_ae.territory_code
	--	and cb.billing_project_id = 0
	--LEFT JOIN Users ae ON uxeq_ae.user_code = ae.user_code
	--	and uxeq_ae.EQcontact_type = 'ae'
where	
	x.userkey = @userkey
	and ins_row between 
			case when @rowfrom <> 0 then @rowfrom else 0 end
		and
			case when @rowto <> 0 then @rowto else 999999999 end
order by
	ins_row

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_Opp_Search2] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_Opp_Search2] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_Opp_Search2] TO [EQAI]
    AS [dbo];

