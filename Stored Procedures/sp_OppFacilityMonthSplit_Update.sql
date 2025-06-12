
create procedure sp_OppFacilityMonthSplit_Update
	@opp_id int,
	@sequence_id int,
	@company_id int,
	@profit_ctr_id int,
	@inputxml varchar(max),
	@added_by varchar(10)
as
begin


	declare @idoc int
	declare @foo int

	exec sp_xml_preparedocument @idoc OUTPUT, @inputxml

	select 
		@opp_id as opp_id,
		@company_id as company_id, 
		@profit_ctr_id as profit_ctr_id,
		amount,
		distribution_date
	INTO #tmp_splits
	FROM OPENXML(@idoc, '/Root/FacilitySplit', 1)
	WITH (
		amount money, 
		distribution_date datetime) AS a	
		

	EXEC sp_xml_removedocument @idoc
	
	delete from OppFacilityMonthSplit where
		opp_id = @opp_id
		AND sequence_id = @sequence_id
		AND company_id = @company_id
		AND profit_ctr_id = @profit_ctr_id
		
	INSERT INTO OppFacilityMonthSplit (opp_id, company_id, profit_ctr_id, sequence_id, amount,revenue_distribution_month)			
	SELECT @opp_id, @company_id, @profit_ctr_id, @sequence_id, amount, distribution_date
		FROM #tmp_splits



end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppFacilityMonthSplit_Update] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppFacilityMonthSplit_Update] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppFacilityMonthSplit_Update] TO [EQAI]
    AS [dbo];

