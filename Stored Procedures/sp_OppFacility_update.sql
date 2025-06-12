
/************************************************************
Procedure    : sp_OppFacility_update
Database     : PLT_AI*
Created      : Feb 4 2008 - Jonathan Broome
Description  : Inserts or Updates OppFacility Records - creating audits as needed.

select * from OppAudit where opp_id = 1247
select * from OppFacility where opp_id = 1247
sp_OppFacility_update 1247, '<Root><Facility copd="03-01" service="test service description" total_revenue="1123.00" /><Facility copd="21-00" service="21 test service desc" total_revenue="0" /></Root>', 'Jonathan'
select * from OppFacility where opp_id = 1247
sp_OppFacility_update 1247, '<Root><Facility copd="03-01" service="" total_revenue="" /></Root>', 'Jonathan'
select * from OppFacility where opp_id = 1247
************************************************************/
Create Procedure sp_OppFacility_update (
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
		opp_id		int,
		sequence_id	int not null identity,
		company_id 	int,
		profit_ctr_id 	int,
		service_desc 	varchar(100),
		total_revenue		money,
		record_type	varchar(1)
	)
	
	insert #tmp 
	select 
		@opp_id as opp_id,
		convert(int, left(copd, 2)) as company_id, 
		convert(int, right(copd, 2)) as profit_ctr_id,
		service as service_desc, 
		total_revenue,
		null as record_type
	FROM OPENXML(@idoc, '/Root/Facility', 1)
	WITH (copd varchar(5), service varchar(100), total_revenue money) AS a	
	
	--	2. Compare existing to new - create audit info
	-- 2.1: deleted rows
	 	insert OppAudit select @opp_id as opp_id, null as opptrack_id, x.sequence_id as sequence_id, 'OppFacility' as table_name, 
			'company_id' as column_name,
			convert(varchar(100), x.company_id) as before_value, '(deleted)' as after_value, @added_by as modified_by, getdate() as date_modified
		from OppFacility x left outer join #tmp n on  x.opp_id = n.opp_id and x.company_id = n.company_id and x.profit_ctr_id = n.profit_ctr_id where n.opp_id is null
		and x.opp_id = @opp_id
			
		insert OppAudit select @opp_id as opp_id, null as opptracK_id, x.sequence_id as sequence_id, 'OppFacility' as table_name,
			'profit_ctr_id' as column_name,
			convert(varchar(100), x.profit_ctr_id) as before_value, '(deleted)' as after_value, @added_by as modified_by, getdate() as date_modified
		from OppFacility x left outer join #tmp n on  x.opp_id = n.opp_id and x.company_id = n.company_id and x.profit_ctr_id = n.profit_ctr_id where n.opp_id is null
		and x.opp_id = @opp_id

		insert OppAudit select @opp_id as opp_id, null as opptracK_id, x.sequence_id as sequence_id, 'OppFacility' as table_name,
			'service_desc' as column_name,
			convert(varchar(100), x.service_desc) as before_value, '(deleted)' as after_value, @added_by as modified_by, getdate() as date_modified
		from OppFacility x left outer join #tmp n on  x.opp_id = n.opp_id and x.company_id = n.company_id and x.profit_ctr_id = n.profit_ctr_id where n.opp_id is null
		and x.opp_id = @opp_id

		insert OppAudit select @opp_id as opp_id, null as opptracK_id, x.sequence_id as sequence_id, 'OppFacility' as table_name,
			'total_revenue' as column_name,
			convert(varchar(100), x.total_revenue) as before_value, '(deleted)' as after_value, @added_by as modified_by, getdate() as date_modified
		from OppFacility x left outer join #tmp n on  x.opp_id = n.opp_id and x.company_id = n.company_id and x.profit_ctr_id = n.profit_ctr_id where n.opp_id is null
		and x.opp_id = @opp_id

	-- 2.2: updated rows

		insert OppAudit select @opp_id, null as opptracK_id, n.sequence_id as sequence_id, 'OppFacility' as table_name,
			'service_desc' as column_name,
			convert(varchar(100), x.service_desc) as before_value, 
			convert(varchar(100), n.service_desc) as after_value, @added_by as modified_by, getdate() as date_modified
		from OppFacility x left outer join #tmp n on  x.opp_id = n.opp_id and x.company_id = n.company_id and x.profit_ctr_id = n.profit_ctr_id where n.opp_id is not null and x.service_desc <> n.service_desc
		and x.opp_id = @opp_id
			
		insert OppAudit select @opp_id, null as opptracK_id, n.sequence_id as sequence_id, 'OppFacility' as table_name,
			'total_revenue' as column_name,
			convert(varchar(100), x.total_revenue) as before_value, 
			convert(varchar(100), n.total_revenue) as after_value, @added_by as modified_by, getdate() as date_modified
		from OppFacility x left outer join #tmp n on  x.opp_id = n.opp_id and x.company_id = n.company_id and x.profit_ctr_id = n.profit_ctr_id where n.opp_id is not null and x.total_revenue <> n.total_revenue
		and x.opp_id = @opp_id

		update #tmp
			set record_type = 'C'
		from OppFacility x left outer join #tmp n on  x.opp_id = n.opp_id and x.company_id = n.company_id and x.profit_ctr_id = n.profit_ctr_id where n.opp_id is not null and (x.service_desc <> n.service_desc or x.total_revenue <> n.total_revenue)
		and x.opp_id = @opp_id

		update #tmp
			set record_type = 'O'
		from OppFacility x left outer join #tmp n on  x.opp_id = n.opp_id and x.company_id = n.company_id and x.profit_ctr_id = n.profit_ctr_id where n.opp_id is not null and (x.service_desc = n.service_desc and x.total_revenue = n.total_revenue)
		and x.opp_id = @opp_id

	-- 2.3: new rows	

		insert OppAudit select @opp_id as opp_id, null as opptracK_id, #tmp.sequence_id as sequence_id, 'OppFacility' as table_name,
			'company_id' as column_name, '(new)' as before_value, 
			convert(varchar(100), company_id) as after_value, @added_by as modified_by, getdate() as date_modified
		from #tmp where record_type is null
			
		insert OppAudit select @opp_id as opp_id, null as opptracK_id, #tmp.sequence_id as sequence_id, 'OppFacility' as table_name,
			'profit_ctr_id' as column_name, '(new)' as before_value, 
			convert(varchar(100), profit_ctr_id) as after_value, @added_by as modified_by, getdate() as date_modified
		from #tmp where record_type is null

		insert OppAudit select @opp_id as opp_id, null as opptracK_id, #tmp.sequence_id as sequence_id, 'OppFacility' as table_name,
			'service_desc' as column_name, '(new)' as before_value, 
			convert(varchar(100), service_desc) as after_value, @added_by as modified_by, getdate() as date_modified
		from #tmp where record_type is null

		insert OppAudit select @opp_id as opp_id, null as opptracK_id, #tmp.sequence_id as sequence_id, 'OppFacility' as table_name,
			'total_revenue' as column_name, '(new)' as before_value, 
			convert(varchar(100), total_revenue) as after_value, @added_by as modified_by, getdate() as date_modified
		from #tmp where record_type is null


	--	3. Delete all existing
		if exists (select * from OppFacility where opp_id = @opp_id)
			delete from OppFacility where opp_id = @opp_id

	--	4. Insert all new
		insert OppFacility select opp_id, sequence_id, company_id, profit_ctr_id, service_desc, total_revenue from #tmp order by company_id, profit_ctr_id
		
		SELECT * FROM OppFacility where Opp_id = @Opp_id
		SELECT * FROM OppFacilityMonthSplit where opp_id = @Opp_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppFacility_update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppFacility_update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppFacility_update] TO [EQAI]
    AS [dbo];

