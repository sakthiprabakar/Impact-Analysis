
/************************************************************
Procedure    : Sp_note_search
Database     : PLT_AI*
Created      : Thu Jun 05 12:05:02 EST 2006 - Jonathan Broome
Description  : Searches for Notes, returns all Note fields plus useful Contact/Customer fields

05/10/2007	JPB	Modified for Central Invoicing: CustomerXCompany -> CustomerBilling, etc.

Sp_note_search 0, '', '', 'Enviro', '', '', '', '', '', '', '', 'n.note_date desc', '598F8A81-6695-4CFA-9A7D-DBE4CAB5F3D3', 1, 40

, '92142044-A984-4737-8649-2686069A3E18', 101, 120

select count(*) from web_sp_notes_search_temp
select * from web_sp_notes_search_temp
delete from web_sp_notes_search_temp

Sp_note_search 0, '301', 			'', 			'', 		'', 	'', 			'', 	'', 						'', 						'', 		'', 			'',			'';
Sp_note_search 0, '301,298,266', 	'', 			'', 		'', 	'', 			'', 	'', 						'', 						'', 		'', 			'', 		'';
Sp_note_search 0, '', 				'888888', 		'', 		'', 	'', 			'', 	'', 						'', 						'', 		'', 			'', 		'', '52D67891-2BEB-4CB7-9F4A-1CFA45874D9C', 0, 0
Sp_note_search 0, '', 				'905297', 		'', 		'', 	'', 			'', 	'', 						'', 						'', 		'', 			'', 		'';
                                                                                                                            
Sp_note_search 0, '', 				'888888, 2222', '', 		'', 	'', 			'', 	'', 						'', 						'', 		'', 			'', 		'n.note_date desc'
Sp_note_search 0, '', 				'888888, 2222', '', 		'', 	'', 			'', 	'', 						'', 						'', 		'', 			'', 		'n.note_date desc'
                                                                                                                            
                                                                                                                            
Sp_note_search 0, '', 				'2222', 		'', 		'', 	'', 			'', 	'', 						'', 						'', 		'', 			'', 		'n.note_date desc';
                                                                                                                            
Sp_note_search 0, '', 				'', 			'Training', '', 	'', 			'', 	'', 						'', 						'', 		'', 			'', 		'n.note_date desc', '46898952-134C-4CA0-82D1-5BC7D6D05357', 0, 0
Sp_note_search  0, '', 				'', 			'Training', '', 	'', 			'', 	'', 						'', 						'', 		'', 			'', 		'n.note_date desc'
                                                                                                                            
Sp_note_search 0, '', 				'', 			'', 		'1', 	'', 			'', 	'', 						'', 						'', 		'', 			'', 		'n.note_date desc';
Sp_note_search 0, '', 				'', 			'', 		'', 	'10001, 96243', '', 	'', 						'', 						'', 		'', 			'', 		'n.note_date desc';
Sp_note_search 0, '', 				'', 			'', 		'', 	'', 			'john', '', 						'', 						'', 		'', 			'', 		'n.note_date desc';
Sp_note_search 0, '', 				'', 			'', 		'', 	'', 			'', 	'customer, profile',	 	'',						 	'', 		'', 			'', 		'n.note_date desc';
Sp_note_search 0, '', 				'', 			'', 		'', 	'', 			'', 	'', 						'sales call,action item', 	'', 		'', 			'', 		'n.note_date desc';
                                                                                                                            
Sp_note_search 0, '', 				'', 			'', 		'', 	'', 			'', 	'', 						'', 						'glenn_t', 	'', 			'', 		'n.note_date desc'
Sp_note_search 0, '', 				'', 			'', 		'', 	'', 			'', 	'', 						'', 						'glenn_t', 	'', 			'', 		'n.note_date desc', 'CBE05644-0D8A-4D0C-9E8E-2130AEB65F21', 21, 40
                                                                                                                            
Sp_note_search 0, '', 				'', 			'', 		'', 	'', 			'', 	'', 						'', 						'', 		'1/1/2006', 	'6/1/2006', 'n.note_date desc';

************************************************************/
Create Procedure Sp_note_search (
	@Debug			int,
	@NoteIdList		varchar(8000),
	@CustIdList		varchar(8000),
	@CustName		varchar(40),
	@Territory		varchar(8000),
	@ContactIdList	varchar(8000),
	@ContactName	varchar(40),
	@NoteSource		varchar(8000),		-- Comma separated list (Customer,Profile,etc)
	@ContactType	varchar(8000),		-- Comma separated list (Sales Call,Meeting,etc)
	@ModifiedBy		varchar(10),
	@StartDate		varchar(20),
	@EndDate		varchar(20),
	@SortBy			varchar(8000),
	@userkey		varchar(255) = '',
	@rowfrom		int = -1,
	@rowto			int = -1
)
AS

set nocount on

declare	@insert	varchar(8000),
		@sql varchar(8000),
		@where varchar(8000),
		@sqlfinal varchar(8000),
		@this	varchar(8000),
		@intcount int

		
-- If it doesn't exist, create the table needed
Select @intcount = Count(*) From Syscolumns C Inner Join Sysobjects O On O.id = C.id And O.name = 'web_sp_notes_search_temp' And C.name = 'note_id'
If @intcount = 0
begin
    --drop table web_sp_notes_search_temp
	Create Table web_sp_notes_search_temp (
        dummy int not null identity, -- identity row, used only to number ins_row.  Silly.
		ins_row		int null, 	-- row number, starts at 1 for each userkey
		note_id		int not null,			-- note_id for join
		ins_date	datetime not null,		-- when it was inserted to this table
		userkey		varchar(255) not null,	-- userkey to re-access a set.
        note_date   datetime null,
        cust_name   varchar(75) null,
        last_name   varchar(20) null,
        first_name  varchar(20) null,
        territory_list  varchar(255) null
	)
    create index idx_web_sp_notes_search_temp_ins_date on web_sp_notes_search_temp (ins_date)
	grant all on web_sp_notes_search_temp to eqai
end
Else -- it exists, so clean it.
	Delete from web_sp_notes_search_temp where datediff( mi, ins_date, getdate()) > 60

if @debug >= 1 print 'past table housekeeping'
	
-- Check for a userkey. If it exists, we're re-accessing existing rows. If not, this is new.
if @userkey <> ''
begin
	select @userkey = case when exists (select userkey from web_sp_notes_search_temp where userkey = @userkey) then @userkey else '' end
end

if @userkey = ''
begin
	set @userkey = newid()
	if @rowfrom = -1 set @rowfrom = 1
	if @rowto = -1 set @rowto = 20
	
	CREATE TABLE #1 ( contact_type varchar(15) )
	CREATE TABLE #2 ( note_source varchar(30) )
	
	If Len(@ContactType) > 0 OR Len(@NoteSource) > 0
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
		Select  Nullif(substring(',' + @ContactType + ',' , Id ,
			Charindex(',' , ',' + @ContactType + ',' , Id) - Id) , '') As contact_type
		From Tbltoolsstringparsercounter
		Where Id <= Len(',' + @ContactType + ',') And Substring(',' + @ContactType + ',' , Id - 1, 1) = ','
		And Charindex(',' , ',' + @ContactType + ',' , Id) - Id > 0
		
		/* Insert The NoteSource Data Into A Temp Table For Use Later */
		Insert Into #2
		Select  Nullif(substring(',' + @NoteSource + ',' , Id ,
			Charindex(',' , ',' + @NoteSource + ',' , Id) - Id) , '') As note_source
		From Tbltoolsstringparsercounter
		Where Id <= Len(',' + @NoteSource + ',') And Substring(',' + @NoteSource + ',' , Id - 1, 1) = ','
		And Charindex(',' , ',' + @NoteSource + ',' , Id) - Id > 0
		
	End
	
	set @insert = 'insert web_sp_notes_search_temp (note_id, ins_date, userkey, note_date, cust_name, last_name, first_name, territory_list) ' 
	set @sql = 'select n.note_id, getdate(), ''' + @userkey + ''' as userkey, n.note_date, cu.cust_name, co.last_name, co.first_name, dbo.fn_customer_territory_list(n.customer_id) as territory_list '
	-- set @sql = 'select n.note_id, n.note_source, n.company_id, n.profit_ctr_id, n.note_date, n.note, n.subject, n.status, n.note_type, n.customer_id, n.contact_id, n.generator_id, n.approval_code, n.profile_id, n.receipt_id, n.workorder_id, n.project_id, n.contact_type, n.added_by, n.date_added, n.modified_by, n.date_modified, n.app_source, co.name, cu.cust_name, dbo.fn_customer_territory_list(n.customer_id) as territory, u.user_name '
	set @sql = @sql + 'from note n left outer join customer cu on n.customer_id = cu.customer_id left outer join contact co on n.contact_id = co.contact_id left outer join users u on n.added_by = u.user_code /*ContactType*/ /*NoteSource*/  where 1=1 '
	set @where = ''
	
	if len(@SortBy) > 0
		set @SortBy = ' order by ' + @SortBy
	else
		set @SortBy = ' order by n.note_date desc '
	
	if len(@NoteIdList) > 0
		set @where = @where + 'and n.note_id in (' + @NoteIdList + ') '
	
	if len(@ContactIdList) > 0
		set @where = @where + 'and n.contact_id in (' + @ContactIdList + ') '
	
	if len(@ContactName) > 0
		set @where = @where + 'and co.name like ''%' + Replace(@ContactName, '''', '''''') + '%'' '
	
	if len(@NoteSource) > 0
		set @sql = replace(@sql, '/*NoteSource*/', 'inner join #2 on n.note_source = #2.note_source and #2.note_source is not null')

	if len(@ContactType) > 0
		set @sql = replace(@sql, '/*ContactType*/', 'inner join #1 on n.contact_type = #1.contact_type and #1.contact_type is not null')
	
	if len(@ModifiedBy) > 0
		set @where = @where + 'and ((n.modified_by like ''%' + Replace(@ModifiedBy, '''', '''''') + '%'') OR (n.added_by like ''%' + Replace(@ModifiedBy, '''', '''''') + '%'')) '
	
	if len(@CustIdList) > 0
		set @where = @where + 'and ((n.customer_id in (' + @custIDList + ')) OR (n.contact_id in ( select contact_id from contactxref where customer_id in (' + @custIDList + ')))) '
	
	if len(@CustName) > 0
		set @where = @where + 'and ((cu.cust_name like ''%' + Replace(@custName, '''', '''''') + '%'') OR (n.contact_id in (select contact_id from contactxref inner join customer on contactxref.customer_id = customer.customer_id where cust_name like ''%' + Replace(@custName, '''', '''''') + '%''))) '
	
	if len(@Territory) > 0
		set @where = @where + 'and ((n.customer_id in (select customer_id from customerbilling where billing_project_id = 0 and territory_code in (' + Replace(@Territory, '''', '''''') + '))) OR (n.contact_id in (select contact_id from contactxref inner join customerbilling on contactxref.customer_id = customerbilling.customer_id where billing_project_id = 0 and territory_code in (' + Replace(@Territory, '''', '''''') + '))))'
	
	if len(@StartDate) > 0 and len(@EndDate) > 0
		set @where = @where + 'and n.note_date between coalesce(''' + @StartDate + ' 00:00:00.000'', n.note_date) and coalesce(''' + @EndDate + ' 23:59:59.998'', n.note_date) '
	
	set @where = @where + 'and n.note_type <> ''AUDIT'' '

	set @sqlfinal = @insert + @sql + @where + @sortby
	
	if @debug >= 1
		begin
			print @sqlfinal
			select @sqlfinal
		end
	
	-- Load the web_sp_notes_search_temp table with note_id's
	exec (@sqlfinal)

    declare @mindummy int
    select @mindummy = min(dummy) from web_sp_notes_search_temp where userkey = @userkey
    update web_sp_notes_search_temp set ins_row = (dummy - @mindummy + 1) where userkey = @userkey
	
end

select @intcount = count(*) from web_sp_notes_search_temp where userkey = @userkey

set nocount off

-- Select out the info for the rows requested.
select 
	n.note_id, 
	n.note_source, 
	n.company_id, 
	n.profit_ctr_id, 
	n.note_date, 
	n.note,
	n.subject, 
	n.status, 
	n.note_type, 
	n.customer_id, 
	n.contact_id, 
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
		inner join company C on p.company_id = c.company_id
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
	@intcount as record_count
from 
	note n
	inner join web_sp_notes_search_temp x on n.note_id = x.note_id
	left outer join customer cu on n.customer_id = cu.customer_id 
	left outer join contact co on n.contact_id = co.contact_id 
	left outer join users u on n.added_by = u.user_code
	left outer join territory t on t.territory_code = x.territory_list
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
    ON OBJECT::[dbo].[Sp_note_search] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[Sp_note_search] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[Sp_note_search] TO [EQAI]
    AS [dbo];

