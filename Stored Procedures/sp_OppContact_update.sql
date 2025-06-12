
/************************************************************
Procedure    : sp_OppContact_update
Database     : PLT_AI*
Created      : Feb 4 2008 - Jonathan Broome
Description  : Inserts or Updates OppContact Records - creating audits as needed.

select * from OppAudit where opp_id = 1247
select * from OppContact where opp_id = 1247
sp_OppContact_update 1247, '<Root><Contact user_code="jonathan" /><Contact user_code="jason_b" /></Root>', 'Jonathan'
select * from OppContact where opp_id = 1247
sp_OppContact_update 1247, '<Root><Contact user_code="jonathan" /></Root>', 'Jonathan'
select * from OppContact where opp_id = 1247
************************************************************/
Create Procedure sp_OppContact_update (
	@Opp_id		int,		-- Opp_id 
	@inputxml	text,		-- <Root><Facility copd="02-21" service="my service desc" total_revenue="1234.56" /><Facility...></Root>
	@added_by	varchar(10)	-- Audit trail author
)
AS
	set nocount on

	DECLARE @idoc  int, @err   int

	EXEC @err = sp_xml_preparedocument @idoc OUTPUT, @inputxml
	SELECT @err = @@error + coalesce(@err, 4711)
	IF @err <> 0 RETURN @err

	-- Process:
	--	1. Create/Populate #tmp table to hold input (easier than always citing xml)
	--	2. Compare existing to new - create audit info
	--	3. Delete all existing
	--	4. Insert all new
	
	--	1. Create/Populate #tmp table to hold input (easier than always citing xml)
	create table #tmp (
		opp_id			int,
		opptrack_id 	int,
		sequence_id		int not null identity,
		user_code		varchar(10),
		record_type		varchar(1)
	)
	
	insert #tmp 
	select 
		@opp_id as opp_id,
		null as opptrack_id,
		user_code, 
		null as record_type
	FROM OPENXML(@idoc, '/Root/Contact', 1)
	WITH (user_code varchar(10)) AS a

	EXEC sp_xml_removedocument @idoc
	
	--	2. Compare existing to new - create audit info
	-- 2.1: deleted rows
	 	insert OppAudit select @opp_id as opp_id, x.oppTrack_id, x.sequence_id, 'OppContact' as table_name,
			'user_code' as column_name,
			convert(varchar(100), x.user_code) as before_value, '(deleted)' as after_value, @added_by as modified_by, getdate() as date_modified
		from OppContact x left outer join #tmp n on  x.opp_id = n.opp_id and x.user_code = n.user_code where n.opp_id is null
		and x.opp_id = @opp_id
	
		update #tmp
			set record_type = 'O'
		from OppContact x left outer join #tmp n on  x.opp_id = n.opp_id where n.opp_id is not null and (x.user_code = n.user_code)
		and x.opp_id = @opp_id

	-- 2.3: new rows	

		insert OppAudit select @opp_id as opp_id, oppTrack_id, sequence_id, 'OppContact' as table_name,
			'user_code' as column_name, '(new)' as before_value, 
			convert(varchar(100), user_code) as after_value, @added_by as modified_by, getdate() as date_modified
		from #tmp where record_type is null
			
	--	3. Delete all existing
		delete from OppContact where opp_id = @opp_id
		
	--	4. Insert all new
		insert OppContact select opp_id, opptrack_id, sequence_id, user_code from #tmp order by user_code
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppContact_update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppContact_update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppContact_update] TO [EQAI]
    AS [dbo];

