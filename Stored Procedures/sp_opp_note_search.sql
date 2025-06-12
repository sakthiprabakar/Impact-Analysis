
/************************************************************
Procedure    : sp_opp_note_search (copied from sp_note_search)

   7/25/2011 - Changed how the delete of tmp records works to save time/blocking
      Added if exists(...) before delete.
      Added nolock hints to every from/join.
	7/28/2011 - Moved table creation and clean-up to separate script. Clean up is done via
		sp_opportunity_clean_work_tables now
	
************************************************************/
Create Procedure sp_opp_note_search (
	@Debug			int = 0,
	@NoteIdList		varchar(8000) = '',
	@CustIdList		varchar(8000) = '',
	@CustName		varchar(40) = '',
	@Territory		varchar(8000) = '',
	@ContactIdList	varchar(8000) = '',
	@ContactName	varchar(40) = '',
	@NoteSource		varchar(8000) = '',		-- Comma separated list (Customer,Profile,etc)
	@NoteType		varchar(100) = '',		-- CSV list (Sales Call, Note)
	@NoteContactType	varchar(8000) = '',		-- Comma separated list (Sales Call,Meeting, Phone Calletc)
	@opp_id			int = NULL,
	@ModifiedBy		varchar(10) = '',
	@StartDate		varchar(20) = '',
	@EndDate		varchar(20) = '',
	@SortBy			varchar(8000) = '',
	@userkey		varchar(255) = '',
	@rowfrom		int = -1,
	@rowto			int = -1
)

---- exec sp_opp_note_search @ModifiedBy='RICH_G'

AS

set nocount on

declare	@insert	varchar(8000),
		@sql varchar(8000),
		@where varchar(8000),
		@sqlfinal varchar(8000),
		@this	varchar(8000),
		@intcount int



-- Check for a userkey. If it exists, we're re-accessing existing rows. If not, this is new.
if @userkey <> ''
begin
	select @userkey = case when exists (select userkey from work_OppNoteSearch (nolock) where userkey = @userkey) then @userkey else '' end
end



if @userkey = ''
begin
	set @userkey = newid()
	if @rowfrom = -1 set @rowfrom = 1
	if @rowto = -1 set @rowto = 20
	
	CREATE TABLE #1 ( contact_type varchar(15) )
	CREATE TABLE #2 ( note_source varchar(30) )
	CREATE TABLE #3 ( note_type varchar(30) )
	
	If Len(@NoteContactType) > 0 OR Len(@NoteSource) > 0 OR Len(@NoteType) > 0
	Begin
		/* Check To See If The Number Parser Table Exists, Create If Necessary */
		Select @intcount = Count(*) From Syscolumns C Inner Join Sysobjects O On O.id = C.id And O.name = 'TblToolsStringParserCounter' And C.name = 'id'
		If @intcount = 0
		Begin
			Create Table TblToolsStringParserCounter (
				Id	Int	)
	
			Declare @i Int
			Select  @i = 1
	
			While (@i <= 8000)
			Begin
				Insert Into TblToolsStringParserCounter Select @i
				Select @i = @i + 1
			End
		End
	
		/* Insert The ContactType Data Into A Temp Table For Use Later */
		Insert Into #1
		Select  Nullif(substring(',' + @NoteContactType + ',' , Id ,
			Charindex(',' , ',' + @NoteContactType + ',' , Id) - Id) , '') As contact_type
		From Tbltoolsstringparsercounter
		Where Id <= Len(',' + @NoteContactType + ',') And Substring(',' + @NoteContactType + ',' , Id - 1, 1) = ','
		And Charindex(',' , ',' + @NoteContactType + ',' , Id) - Id > 0
		
		/* Insert The NoteSource Data Into A Temp Table For Use Later */
		Insert Into #2
		Select  Nullif(substring(',' + @NoteSource + ',' , Id ,
			Charindex(',' , ',' + @NoteSource + ',' , Id) - Id) , '') As note_source
		From Tbltoolsstringparsercounter
		Where Id <= Len(',' + @NoteSource + ',') And Substring(',' + @NoteSource + ',' , Id - 1, 1) = ','
		And Charindex(',' , ',' + @NoteSource + ',' , Id) - Id > 0
		
		/* Insert The NoteType Data Into A Temp Table For Use Later */
		Insert Into #3
		Select  Nullif(substring(',' + @NoteType + ',' , Id ,
			Charindex(',' , ',' + @NoteType + ',' , Id) - Id) , '') As note_type
		From Tbltoolsstringparsercounter
		Where Id <= Len(',' + @NoteType + ',') And Substring(',' + @NoteType + ',' , Id - 1, 1) = ','
		And Charindex(',' , ',' + @NoteType + ',' , Id) - Id > 0		
		
		IF @Debug >= 1
		BEGIN
			select * FROM #1
			select * FROM #2
			select * from #3
		END
		
	End
	
	
	
	declare @search_mode varchar(10) = 'full'
	declare @from_statement_note varchar(max)
	declare @from_statement_oppnote varchar(max)
	
	set @insert = 'insert work_OppNoteSearch (
		note_id, 
		ins_date, 
		userkey, 
		note_date, 
		cust_name, 
		last_name, 
		first_name, 
		territory_list, 
		date_modified
	) ' 
	set @sql = 'select n.note_id, getdate(), ''' + @userkey + ''' as userkey, n.note_date, cu.cust_name, co.last_name, co.first_name, dbo.fn_customer_territory_list(n.customer_id) as territory_list,  n.date_modified'
	set @from_statement_note = ' from note n (nolock) left outer join customer cu (nolock) on n.customer_id = cu.customer_id left outer join contact co (nolock) on n.contact_id = co.contact_id left outer join users u (nolock) on n.added_by = u.user_code /*NoteContactType*/ /*NoteSource*/  /*NoteType*/ where 1=1 '
	set @from_statement_oppnote = ' from OppNote n (nolock) left outer join customer cu (nolock) on n.customer_id = cu.customer_id left outer join contact co (nolock) on n.contact_id = co.contact_id left outer join users u (nolock) on n.added_by = u.user_code /*NoteContactType*/ /*NoteSource*/ /*NoteType*/  where 1=1 '
	set @where = ''
	
		
	
	if len(@SortBy) > 0
		set @SortBy = ' order by ' + @SortBy
	else
		set @SortBy = ' order by n.note_date desc, n.date_modified desc '
	
	if len(@NoteIdList) > 0
		set @where = @where + 'and n.note_id in (' + @NoteIdList + ') '
	
	if len(@ContactIdList) > 0
		set @where = @where + 'and n.contact_id in (' + @ContactIdList + ') '
	
	if len(@ContactName) > 0
		set @where = @where + 'and co.name like ''%' + Replace(@ContactName, '''', '''''') + '%'' '
	
	if len(@NoteSource) > 0
	BEGIN
		set @from_statement_note = replace(@from_statement_note, '/*NoteSource*/', 'inner join #2 on n.note_source = #2.note_source and #2.note_source is not null')
		set @from_statement_oppnote = replace(@from_statement_oppnote, '/*NoteSource*/', 'inner join #2 on n.note_source = #2.note_source and #2.note_source is not null')
	END

	if len(@NoteContactType) > 0
	BEGIN 
		set @from_statement_note = replace(@from_statement_note, '/*NoteContactType*/', 'inner join #1 on n.contact_type = #1.contact_type and #1.contact_type is not null')
		set @from_statement_oppnote = replace(@from_statement_oppnote, '/*NoteContactType*/', 'inner join #1 on n.contact_type = #1.contact_type and #1.contact_type is not null')
	END
	
	
	
	if len(@NoteType) > 0
	BEGIN
		set @from_statement_note = replace(@from_statement_note, '/*NoteType*/', 'inner join #3 on n.note_type = #3.note_type and #3.note_type is not null')
		set @from_statement_oppnote = replace(@from_statement_oppnote, '/*NoteType*/', 'inner join #3 on n.note_type = #3.note_type and #3.note_type is not null')
	END	
	
	if len(@ModifiedBy) > 0
		set @where = @where + 'and ((n.modified_by like ''%' + Replace(@ModifiedBy, '''', '''''') + '%'') OR (n.added_by like ''%' + Replace(@ModifiedBy, '''', '''''') + '%'')) '
	
	if len(@CustIdList) > 0
		set @where = @where + 'and ((n.customer_id in (' + @custIDList + ')) OR (n.contact_id in ( select contact_id from contactxref (nolock) where customer_id in (' + @custIDList + ')))) '
	
	
	
	if len(@CustName) > 0
		set @where = @where + 'and ((cu.cust_name like ''%' + Replace(@custName, '''', '''''') + '%'') OR (n.contact_id in (select contact_id from contactxref (nolock) inner join customer (nolock) on contactxref.customer_id = customer.customer_id where cust_name like ''%' + Replace(@custName, '''', '''''') + '%''))) '
	
	if len(@Territory) > 0
		set @where = @where + 'and ((n.customer_id in (select customer_id from customerbilling (nolock) where billing_project_id = 0 and territory_code in (' + Replace(@Territory, '''', '''''') + '))) OR (n.contact_id in (select contact_id from contactxref (nolock) inner join customerbilling (nolock) on contactxref.customer_id = customerbilling.customer_id where billing_project_id = 0 and territory_code in (' + Replace(@Territory, '''', '''''') + '))))'
	
	if len(@StartDate) > 0 and len(@EndDate) > 0
		set @where = @where + 'and n.note_date between coalesce(''' + @StartDate + ' 00:00:00.000'', n.note_date) and coalesce(''' + @EndDate + ' 23:59:59.998'', n.note_date) '
	
	
	declare @opp_where varchar(100) = ''	
	
	if @opp_id is not null and @opp_id <> ''
	begin
		set @opp_where = @opp_where + ' and n.opp_id = ' + CAST(ISNULL(@opp_id,0) as varchar(20))
		
		-- if we are ONLY searching for opportunity notes, then execute that OppNote sql
		if @where = ''
		begin
			SET @search_mode = 'opp'
		end
	end
	
	set @where = @where + ' and n.note_type <> ''AUDIT'' '	


	-- if we are possibly searching for something OTHER than ONLY opportunity notes,
	-- we have to do the FULL check between both tables :-/
	if (@search_mode = 'full')
		set @sqlfinal = @insert + @sql + @from_statement_note + @where + ' UNION ' + @sql +@from_statement_oppnote + @where + @opp_where + @sortby
	else
		set @sqlfinal = @insert + @sql + @from_statement_oppnote + @where + @opp_where + @sortby
	
	
	
	if @debug >= 1
		begin
			print @sqlfinal
		end
	
	-- Load the work_OppNoteSearch table with note_id's
	exec (@sqlfinal)		
	

	
		
	--set @sqlfinal = @insert + @sql +@from_statement_oppnote + @where + @sortby

	--	if @debug >= 1
	--	begin
	--		print @sqlfinal
	--		select @sqlfinal
	--	end
		
	--exec (@sqlfinal)	
	
	

end

declare @mindummy int
select @mindummy = min(dummy) from work_OppNoteSearch (nolock) where userkey = @userkey
update work_OppNoteSearch set ins_row = (dummy - @mindummy + 1) where userkey = @userkey

select @intcount = count(*) from work_OppNoteSearch (nolock) where userkey = @userkey
set NOCOUNT ON

IF @Debug >= 1 
BEGIN
	print 'from: ' + cast(@rowfrom as varchar(10))
	print 'to: ' + cast(@rowto as varchar(10))
	
END

-- Select out the info for the rows requested.
SELECT * into #tmp_results FROM (
	select DISTINCT
		n.note_id, 
		n.note_source, 
		n.company_id, 
		n.profit_ctr_id, 
		n.note_date, 
		cast(n.note as varchar(max)) as note,
		n.subject, 
		n.status, 
		n.note_type, 
		n.customer_id, 
		n.contact_id, 
		null as opp_id,
		n.generator_id, 
		n.approval_code, 
		n.profile_id, 
		n.receipt_id, 
		n.workorder_id, 
		n.project_id, 
		n.contact_type, 
		n.added_by, 
		n.date_added, 
		n.modified_by, 
		n.date_modified, 
		n.app_source, 
		co.name, 
		cu.cust_name, 
		x.territory_list as territory,
		t.territory_desc,
		dbo.fn_territory_ae(x.territory_list) as territory_user,
		u.user_name,
		(
			select top 1 case
				   when p.view_on_web = 'P' then p.profit_ctr_name
				   when p.view_on_web = 'C' then c.company_name
			end
			from
			profitcenter P (nolock) 
			inner join company C (nolock) on p.company_id = c.company_id
			where p.status = 'A'
			and p.view_on_web in ('P', 'C')
			and c.view_on_web = 'T'
			and p.company_id = n.company_id
			and (
				(P.Profit_ctr_id = n.profit_ctr_id
				and n.profit_ctr_id is not null)
				or n.profit_ctr_id is null
				)
		) as profit_ctr_name,
		x.userkey,
		@intcount as record_count,
		ins_row
	from 
		note n (nolock) 
		inner join work_OppNoteSearch x (nolock) on n.note_id = x.note_id
		left outer join customer cu (nolock) on n.customer_id = cu.customer_id 
		left outer join contact co (nolock) on n.contact_id = co.contact_id 
		left outer join users u (nolock) on n.added_by = u.user_code
		left outer join territory t (nolock) on t.territory_code = x.territory_list
	where
		x.userkey = @userkey
		and ins_row between 
				case when @rowfrom <> 0 then @rowfrom else 0 end
			and
				case when @rowto <> 0 then @rowto else 999999999 end

		
	UNION

	-- Select out the info for the rows requested.
	select 
		n.note_id, 
		n.note_source, 
		n.company_id, 
		n.profit_ctr_id, 
		n.note_date, 
		cast(n.note as varchar(max)) as note,
		n.subject, 
		n.status, 
		n.note_type, 
		n.customer_id, 
		n.contact_id, 
		n.opp_id,
		n.generator_id, 
		n.approval_code, 
		n.profile_id, 
		n.receipt_id, 
		n.workorder_id, 
		n.project_id, 
		n.contact_type, 
		n.added_by, 
		n.date_added, 
		n.modified_by, 
		n.date_modified, 
		n.app_source, 
		co.name, 
		cu.cust_name, 
		x.territory_list as territory,
		t.territory_desc,
		dbo.fn_territory_ae(x.territory_list) as territory_user,
		u.user_name,
		(
			select top 1 case
				   when p.view_on_web = 'P' then p.profit_ctr_name
				   when p.view_on_web = 'C' then c.company_name
			end
			from
			profitcenter P
			inner join company C (nolock) on p.company_id = c.company_id
			where p.status = 'A'
			and p.view_on_web in ('P', 'C')
			and c.view_on_web = 'T'
			and p.company_id = n.company_id
			and (
				(P.Profit_ctr_id = n.profit_ctr_id
				and n.profit_ctr_id is not null)
				or n.profit_ctr_id is null
				)
		) as profit_ctr_name,
		x.userkey,
		@intcount as record_count,
		ins_row
	from 
		OppNote n
		inner join work_OppNoteSearch x (nolock) on n.note_id = x.note_id
		left outer join customer cu (nolock) on n.customer_id = cu.customer_id 
		left outer join contact co (nolock) on n.contact_id = co.contact_id 
		left outer join users u (nolock) on n.added_by = u.user_code
		left outer join territory t (nolock) on t.territory_code = x.territory_list
	where
		x.userkey = @userkey
		and ins_row between 
				case when @rowfrom <> 0 then @rowfrom else 0 end
			and
				case when @rowto <> 0 then @rowto else 999999999 end) tmp_results

SELECT * FROM #tmp_results 	
	order by n.note_date desc, n.date_modified desc

-- select the EQ Contacts that may have been a part of this call
SELECT ox.* FROM OppNoteXEQContact ox
	JOIN #tmp_results tr ON ox.note_id = tr.note_id

set nocount off


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opp_note_search] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opp_note_search] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opp_note_search] TO [EQAI]
    AS [dbo];

