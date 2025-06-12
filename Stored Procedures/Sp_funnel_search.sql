Create Procedure Sp_funnel_search (
	@Debug			int,
	@funnel_id_list	varchar(8000),	-- Comma Separated Funnel ID List
	@database_list	varchar(8000),	-- Comma Separated Company List
	@Project_name	varchar(50),
	@StatusList		varchar(8000),
	@CustIdList		varchar(8000),
	@cust_name		varchar(75),
	@TerritoryList	varchar(8000),
	@ContactIdList	varchar(80),
	@ContactName	varchar(40),
	@GenIdList		varchar(8000),
	@StartDate		varchar(30),
	@EndDate		varchar(30),
	@DateMStart		varchar(30),
	@DateMEnd		varchar(30),
	@userkey		varchar(255) = '',
	@rowfrom		int = -1,
	@rowto			int = -1
)
AS
/************************************************************
Procedure    : Sp_funnel_search
Database     : PLT_AI*
Created      : Tue May 02 12:30:00 EST 2006 - Jonathan Broome
Description  : Searches for Funnel entries

05/10/2007	JPB	Modified for Central Invoicing Changes -> territory ae comes from fn representing new table source
08/09/2007 JPB Modified to fix the database_list criteria being ignored.
11/12/2007  JPB Fix: Missing 'and' between customer_id = customer_id AND billing_project_id = 0 in territory where clause
12/10/2007 JPB Modified to reset the @tmp_list variable after working on it, to fix selects by company/profitctr
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

sp_funnel_search 0, '', '', '', '', '', '', '', '', '', '', '', '', '', ''
Sp_funnel_search 0, '', '2|21', '', 'O', '', '', '', '', '', '', '01/01/2006', '07/29/2006', '', -1, -1;
Sp_funnel_search 0, '', '14|3', '', 'O', '', '', '', '', '', '', '01/01/2006', '07/29/2006', '', -1, -1; 
Sp_funnel_search 0, '2229', '', '', '', '', '', '', '', '', '', '', '', '', '';
Sp_funnel_search 0, '', '2|21, 3|1, 12|0, 14|0, 14|1, 14|2, 14|3, 14|4, 14|5, 14|6, 14|7, 14|9, 14|10, 14|11, 14|12, 15|1, 15|2, 15|3, 15|4, 17|0, 18|0, 21|0, 21|1, 21|2, 21|3, 22|0, 23|0, 24|0', '', 'O', '', '', '08', '', '', '', '', '', '', '', '', -1, -1

************************************************************/
BEGIN
	set nocount on
	declare	@insert	varchar(8000),
			@sql varchar(8000),
			@where varchar(8000),
			@sqlfinal varchar(8000),
			@intcount int,
			@order varchar(8000)

	if @StartDate <> '' set @StartDate = @StartDate + ' 00:00:00.000'
	if @EndDate <> '' set @EndDate = @EndDate + ' 23:59:59.998'

	if @DateMStart <> '' set @DateMStart = @DateMStart + ' 00:00:00.000'
	if @DateMEnd <> '' set @DateMEnd = @DateMEnd + ' 23:59:59.998'

	-- If it doesn't exist, create the table needed
	Select @intcount = Count(*) From Syscolumns C Inner Join Sysobjects O On O.id = C.id And O.name = 'web_sp_funnel_search_temp' And C.name = 'funnel_id'
	If @intcount = 0
	begin
		--drop table web_sp_funnel_search_temp
		Create Table web_sp_funnel_search_temp (
			dummy int not null identity, -- identity row, used only to number ins_row.  Silly.
			ins_row			int null, 	-- row number, starts at 1 for each userkey
			funnel_id		int not null,			-- note_id for join
			ins_date		datetime not null,		-- when it was inserted to this table
			userkey			varchar(255) not null,	-- userkey to re-access a set.
			territory_list	varchar(255), 
			date_new		datetime,
			cust_name		varchar(75),
			project_name	varchar(50)
		)
		create index idx_web_sp_funnel_search_temp_ins_date on web_sp_funnel_search_temp (ins_date)
		grant all on web_sp_funnel_search_temp to eqai

	end
	Else -- it exists, so clean it.
		Delete from web_sp_funnel_search_temp where datediff( mi, ins_date, getdate()) > 60

	if @debug >= 1 print 'past table housekeeping'
	
	-- Check for a userkey. If it exists, we're re-accessing existing rows. If not, this is new.
	if @userkey <> ''
	begin
		select @userkey = case when exists (select userkey from web_sp_funnel_search_temp where userkey = @userkey) then @userkey else '' end
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
				@pcpos		int,
				@database	varchar(30),
				@company	varchar(30),
				@profitcenter	varchar(30),
				@tmp_list	varchar(8000)
	
			SELECT @tmp_list = REPLACE(@database_list, ' ', '') 
		 
			IF @debug = 1 PRINT 'database List: ' + @database_list
			SELECT @pos = 0
			WHILE DATALENGTH(@tmp_list) > 0
			BEGIN
				-- Look for a comma
				SELECT @pos = CHARINDEX(',', @tmp_list)
				IF @debug = 1 PRINT 'Pos: ' + CONVERT(varchar(10), @pos)
		
				-- If we found a comma,there is a list of databases
				IF @pos > 0
				BEGIN
					SELECT @database = SUBSTRING(@tmp_list, 1, @pos - 1)
					SELECT @tmp_list = SUBSTRING(@tmp_list, @pos + 1, DATALENGTH(@tmp_list) - @pos)
					IF @debug = 1 PRINT 'database: ' + CONVERT(varchar(30), @database) 
		 
				END
		
				-- If we did not find a comma, there is only one database or we are at the end of the list
				IF @pos = 0
				BEGIN
					SELECT @database = @tmp_list
					SELECT @tmp_list = NULL
					IF @debug = 1 PRINT 'database: ' + CONVERT(varchar(30), @database)
				END
		
				-- Check for ProfitCenter attachment
				SELECT @pcpos = CHARINDEX('|', @database)
				IF @pcpos > 0
				BEGIN
					SELECT @company = LEFT(@database, @pcpos -1)
					SELECT @profitcenter = REPLACE(@database, @company+'|', '')
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
			SELECT @tmp_list = REPLACE(@database_list, ' ', '') 
		IF @debug >= 1 SELECT * FROM #tmp_database
	
		set @insert = 'insert web_sp_funnel_search_temp (funnel_id, ins_date, userkey, territory_list, date_new, cust_name, project_name) ' 
		set @sql = ' SELECT DISTINCT
			f.funnel_id,
			getdate(),
			''' + @userkey + ''' as userkey,
			dbo.fn_customer_territory_list(f.customer_id) as territory_list,
			(select top 1 status_date from funneldates d where d.funnel_id = f.funnel_id and d.status=''N'' order by status_date desc) as date_new,
			c.cust_name,
			f.project_name '
		set @sql = @sql + ' from CustomerFunnel f
			inner join customer c on f.customer_id = c.customer_id
			left outer join FunnelXCompany x on f.funnel_id = x.funnel_id '
		
		IF DATALENGTH(@tmp_list) > 0
			set @sql = @sql + ' inner join #tmp_database t on x.company_id = t.company_id and x.profit_ctr_id = t.profit_ctr_id ' 
		set @sql = @sql + '	where 1=1 '
		set @where = ''
		set @order = ' order by territory_list, date_new, c.cust_name, f.project_name '

		if len(@funnel_id_list) > 0
			set @where = @where + 'and f.funnel_id in (' + @funnel_id_list + ') '
	
		if len(@project_name) > 0
			set @where = @where + 'and f.project_name like ''%' + @project_name + '%'' '
	
		if len(@StatusList) > 0
			begin
				set @StatusList = '*' + replace(replace(ltrim(rtrim(@StatusList)), ' ', ''), ',', '*,*') + '*'
				set @StatusList = replace(@StatusList, '*L*', '''L'', ''X''')
				set @StatusList = replace(@StatusList, '*W*', '''W'', ''C''')
				set @StatusList = replace(@StatusList, '*O*', '''N'', ''P'', ''T''')
				set @StatusList = replace(@StatusList, '*C*', '''C'', ''L'', ''X'', ''V'', ''O'', ''W''')
				set @where = @where + 'and f.status in (' + @StatusList + ') '
			end
	
		if len(@CustIdList) > 0
			set @where = @where + 'and c.customer_id in (' + @CustIdList + ') '
	
		if len(@cust_name) > 0
			set @where = @where + 'and c.cust_name like ''%' + @cust_name + '%'' '
	
		if len(@TerritoryList) > 0
			set @where = @where + 'and exists (select customer_id from customerbilling where customer_id = c.customer_id and billing_project_id = 0 and territory_code in (' + @TerritoryList + ')) '
	
		if len(@ContactIdList) > 0
			set @where = @where + 'and f.contact_id in (' + @ContactIdList + ') '
	
		if len(@ContactName) > 0
			set @where = @where + 'and exists (select contact_id from contact where contact_id = f.contact_id and name like ''%' + @ContactName + '%'') '
	
		if len(@GenIdList) > 0
			set @where = @where + 'and f.generator_id in (' + @GenIdList + ') '

		if len(@StartDate) > 0 and len(@EndDate) > 0
			set @where = @where + 'and (((''' + @StartDate + ''' >= f.est_start_date) and (''' + @EndDate + ''' <= f.est_end_date)) or ((''' + @EndDate + ''' >= f.est_start_date) and (''' + @StartDate + ''' <= f.est_end_date))) '

		if len(@DateMStart) > 0 and len(@DateMEnd) > 0
			set @where = @where + 'and ( isnull((select top 1 status_date from funneldates d where d.funnel_id = f.funnel_id and d.status=f.status order by status_date desc), isnull(f.date_modified, f.date_added)) between ''' + @DateMStart + ''' and ''' + @DateMEnd + ''') '
		
		set @sqlfinal = @insert + @sql + @where + @order
		
		if @debug >= 1
			begin
				print @sqlfinal
				select @sqlfinal
			end

		-- Load the web_sp_funnel_search_temp table with note_id's
		exec (@sqlfinal)

		declare @mindummy int
		select @mindummy = min(dummy) from web_sp_funnel_search_temp where userkey = @userkey
		update web_sp_funnel_search_temp set ins_row = (dummy - @mindummy + 1) where userkey = @userkey

	end

	select @intcount = count(*) from web_sp_funnel_search_temp where userkey = @userkey

	set nocount off

	-- Select out the info for the rows requested.

	SELECT 
		f.funnel_id,
		f.customer_id,
		x.cust_name,
		x.territory_list,
		t.territory_desc,
		dbo.fn_territory_ae(x.territory_list) as user_name,
		f.contact_id,
		cn.first_name,
		cn.last_name,
		f.project_name,
		f.status,
		s.status_text,
		x.date_new,
		(select top 1 status_date from funneldates d where d.funnel_id = f.funnel_id and d.status=f.status order by status_date desc) as status_date,
		f.direct_flag,
		case f.job_type when 'E' then 'Event' when 'B' then 'Base' else f.job_type END as job_type,
		f.project_type,
		f.generator_name,
		f.generator_id,
		f.price,
		f.bill_unit_code,
		b.bill_unit_desc,
		f.quantity,
		f.project_interval,
		f.number_of_intervals,
		f.calc_revenue_flag,
		f.est_revenue,
		f.probability,
		p.description as probability_desc,
		((f.probability * 0.01) * f.est_revenue) as projected_income,
		f.est_start_date,
		f.est_end_date,
		f.description,
		dbo.fn_funnel_company_name_list(f.funnel_id) as eq_company_profit_ctr_name,
		case when f.direct_flag = 'T' then 'Customer Generator Direct' else 'Non - Direct' END as customer_type,
		f.added_by,
		f.date_added,
		x.userkey,
		x.ins_row,
		@intcount as record_count
	from 
		CustomerFunnel f
		inner join web_sp_funnel_search_temp x on f.funnel_id = x.funnel_id
		left outer join FunnelStatus s on f.status = s.status_code
		left outer join funnelprobability p on f.probability = p.probability
		left outer join contact cn on f.contact_id = cn.contact_id
		left outer join billunit b on f.bill_unit_code = b.bill_unit_code
		left outer join territory t on t.territory_code = x.territory_list
	where	
		x.userkey = @userkey
		and ins_row between 
				case when @rowfrom <> 0 then @rowfrom else 0 end
			and
				case when @rowto <> 0 then @rowto else 999999999 end
	order by
		ins_row
END
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[Sp_funnel_search] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[Sp_funnel_search] TO [COR_USER]
    AS [dbo];
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[Sp_funnel_search] TO [EQAI]
    AS [dbo];

GO