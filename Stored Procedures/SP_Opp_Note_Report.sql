Create Procedure SP_Opp_Note_Report (
	@Debug					int = 0,
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
	@userkey				varchar(255) = '',	-- userkey, rowfrom and rowto aren't "where clause" inputs - they're select specifications for resultsets.  They should come last in the input list.
	@rowfrom				int = -1,
	@rowto					int = -1
)
AS
/************************************************************
	Procedure    : SP_Opp_Note_Report
	Database     : PLT_AI*
	Created      : Mon Jul 28 14:20:00 EST 2008 - Jonathan Broome
	Description  : Returns Opp Entries AND related (by customer_id) notes in a single SP
 ************************************************************
	7/28/2008 JPB Created from copy of sp_opp_search
	08/24/2011	RJG	Converted temporary table to the OppWorkSearch table
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
					@ModifiedByList      varchar(8000),
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

				exec SP_Opp_Note_Report @Debug, @opp_id, @facility_list, @Opp_name, @StatusList, @CustIdList, @cust_name, @TerritoryList, @ContactIdList, @generator_name, @EstStartDate1, @EstStartDate2, @EstEndDate1, @EstEndDate2, @ActualStartDate1, @ActualStartDate2, @ActualEndDate1, @ActualEndDate2, @ModStartDate, @ModEndDate, @Description, @ModifiedByList, @RegionIdList, @NamIdList, @userkey, @rowfrom, @rowto
				-----------------------------------------------
				--END Test section
				-----------------------------------------------

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
		getdate(),		
		c.cust_name,
		f.Opp_name '
	set @sql = @sql + ' from Opp f
		inner join customer c on f.customer_id = c.customer_id
		left outer join OppFacility x on f.Opp_id = x.Opp_id '

	IF DATALENGTH(@tmp_list) > 0
		set @sql = @sql + ' inner join #tmp_database t on x.company_id = t.company_id and x.profit_ctr_id = t.profit_ctr_id ' 

   if DATALENGTH(@ModifiedByList) > 0
		set @sql = @sql + ' inner join users u on f.modified_by = u.user_code 
      inner join (select row from dbo.fn_SplitXsvText('','', 1, ''' + @ModifiedByList + ''') where isnull(row, '''') <> '''') ModifiedBy on (u.user_code like ''%'' + ModifiedBy.row + ''%'' or u.user_name like ''%'' + ModifiedBy.row + ''%'') 
      '

	set @sql = @sql + '	where 1=1 '
	set @where = ''
	set @order = ' order by territory_list, f.date_added, c.cust_name, f.Opp_name '

	if @Opp_id <> -1
		set @where = @where + 'and f.Opp_id = ' + convert(varchar(15), @opp_id) 
	
	if len(@Opp_name) > 0
		set @where = @where + 'and f.Opp_name like ''%' + replace(replace(@Opp_name, ' ', '%'), '''', '''''') + '%'' '
	
	if len(@StatusList) > 0
		set @where = @where + 'and f.status in (select row from dbo.fn_SplitXsvText('','', 1, ''' + @StatusList + ''') where isnull(row, '''') <> '''') '
	
	if len(@CustIdList) > 0
		set @where = @where + 'and f.customer_id in (select row from dbo.fn_SplitXsvText('','', 1, ''' + @CustIdList + ''') where isnull(row, '''') <> '''') '
	
	if len(@cust_name) > 0
		set @where = @where + 'and c.cust_name like ''%' + replace(replace(@cust_name, ' ', '%'), '''', '''''') + '%'' '
	
	if len(@TerritoryList) > 0
		set @where = @where + 'and exists (select customer_id from customerbilling where customer_id = c.customer_id and billing_project_id = 0 and territory_code in (select row from dbo.fn_SplitXsvText('','', 1, ''' + @TerritoryList + ''') where isnull(row, '''') <> '''')) '
	
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


	set @sqlfinal = @insert + @sql + @where + @order
		
	if @debug >= 1
		begin
			print @sqlfinal
			select @sqlfinal
		end

	-- Load the work_OppSearch table with note_id's
	exec (@sqlfinal)

    declare @mindummy int
    select @mindummy = min(dummy) from work_OppSearch where userkey = @userkey
    update work_OppSearch set ins_row = (dummy - @mindummy + 1) where userkey = @userkey

end

select @intcount = count(*) from work_OppSearch where userkey = @userkey





set nocount off

-- Select out the info for the rows requested.

SELECT 
	f.Opp_id,
	f.customer_id,
	x.cust_name,
	f.territory_code,
	t.territory_desc,
	r.region_desc,
	f.Opp_name,
	f.description,
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
	f.region_id,
	f.nam_id,
	nam.user_name as nam_user_name,
	f.contact_id,
	f.scale_job_size,
	f.scale_cust_size,
	f.scale_odds,
	f.scale_profitability,
	f.scale_bidders,
	f.scale_competency,
	f.scale_eq_pct,
	
	x.userkey,
	x.ins_row,
	@intcount as record_count
from 
	Opp f
	inner join work_OppSearch x on f.Opp_id = x.Opp_id
	left outer join OppJobType jobtype on f.job_type = jobtype.code
	left outer join OppStatusLookup s on f.status = s.code and s.type = 'Opp'
	left outer join contact on f.contact_id = contact.contact_id
	left outer join OppSalesType salestype on f.sales_type = salestype.code
	left outer join OppServiceType servicetype on f.service_type = servicetype.code
	left outer join Users mu on f.modified_by = mu.user_code
	left outer join Users omu on f.opp_manager = omu.user_code
	left outer join UsersXEQContact uxeq on f.nam_id = uxeq.type_id and uxeq.eqcontact_type = 'nam'
	left outer join Users nam on uxeq.user_code = nam.user_code
	left outer join Region r on f.region_id = r.region_id
	left outer join territory t on f.territory_code = t.territory_code
	
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
    ON OBJECT::[dbo].[SP_Opp_Note_Report] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_Opp_Note_Report] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[SP_Opp_Note_Report] TO [EQAI]
    AS [dbo];

