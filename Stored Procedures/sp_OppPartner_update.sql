
/************************************************************
Procedure    : sp_OppPartner_update
Database     : PLT_AI*
Created      : Feb 4 2008 - Jonathan Broome
Description  : Inserts or Updates OppPartner Records - creating audits as needed.

delete from OppAudit where opp_id = 1247 and table_name = 'OppPartner'
delete from OppPartner where opp_id = 1247
select * from OppAudit where opp_id = 1247 and table_name = 'OppPartner' order by date_modified desc, sequence_id
select * from OppPartner where opp_id = 1247
sp_OppPartner_update 1247, '<Root><Partner vendor_name="Test Vendor" /><Partner vendor_name="Some Other Vendor" /></Root>', 'Jonathan'
select * from OppPartner where opp_id = 1247
sp_OppPartner_update 1247, '<Root><Partner vendor_name="Test Vendor" /></Root>', 'Jonathan'
select * from OppPartner where opp_id = 1247
************************************************************/
Create Procedure sp_OppPartner_update (
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
		sequence_id		int not null identity,
		vendor_code		varchar(12),
		vendor_name		varchar(40),
		record_type		varchar(1)
	)
	
	insert #tmp 
	select 
		@opp_id as opp_id,
		vendor_code,
		vendor_name, 
		null as record_type
	FROM OPENXML(@idoc, '/Root/Partner', 1)
	WITH (vendor_code varchar(12), vendor_name varchar(40)) AS a


	EXEC sp_xml_removedocument @idoc
	
	--	2. Compare existing to new - create audit info
	-- 2.1: deleted rows
	 	insert OppAudit select @opp_id as opp_id, null as opptrack_id, n.sequence_id, 'OppPartner' as table_name,
			'vendor_code' as column_name,
			convert(varchar(100), x.vendor_code) as before_value, '(deleted)' as after_value, @added_by as modified_by, getdate() as date_modified
		from OppPartner x left outer join #tmp n on  x.opp_id = n.opp_id and x.vendor_name = n.vendor_name where n.opp_id is null
		and x.opp_id = @opp_id

	 	insert OppAudit select @opp_id as opp_id, null as opptrack_id, n.sequence_id, 'OppPartner' as table_name,
			'vendor_name' as column_name,
			convert(varchar(100), x.vendor_name) as before_value, '(deleted)' as after_value, @added_by as modified_by, getdate() as date_modified
		from OppPartner x left outer join #tmp n on  x.opp_id = n.opp_id and x.vendor_name = n.vendor_name where n.opp_id is null
		and x.opp_id = @opp_id
			
		update #tmp
			set record_type = 'O'
		from OppPartner x left outer join #tmp n on  x.opp_id = n.opp_id where n.opp_id is not null and (x.vendor_name = n.vendor_name)
		and x.opp_id = @opp_id

	-- 2.3: new rows	

		insert OppAudit select @opp_id as opp_id, null as opptrack_id, sequence_id, 'OppPartner' as table_name,
			'vendor_code' as column_name, '(new)' as before_value, 
			convert(varchar(100), vendor_code) as after_value, @added_by as modified_by, getdate() as date_modified
		from #tmp where record_type is null

		insert OppAudit select @opp_id as opp_id, null as opptrack_id, sequence_id, 'OppPartner' as table_name,
			'vendor_name' as column_name, '(new)' as before_value, 
			convert(varchar(100), vendor_name) as after_value, @added_by as modified_by, getdate() as date_modified
		from #tmp where record_type is null
			
	--	3. Delete all existing
		delete from OppPartner where opp_id = @opp_id
		
	--	4. Insert all new
		insert OppPartner select opp_id, sequence_id, vendor_code, vendor_name from #tmp order by vendor_name
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppPartner_update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppPartner_update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppPartner_update] TO [EQAI]
    AS [dbo];

