
create procedure sp_OppFacility_Select
	@opp_id int,
	@sequence_id int,
	@company_id int,
	@profit_ctr_id int
/*
Usage: sp_OppFacility_Select
*/

as
begin


	SELECT fm.* FROM OppFacility fm
	WHERE fm.opp_id = @opp_id
		AND fm.sequence_id = @sequence_id
		AND fm.company_id = @company_id
		AND fm.profit_ctr_id = @profit_ctr_id

	SELECT f.total_revenue, f.service_desc, fm.* FROM OppFacilityMonthSplit fm
		INNER JOIN OppFacility f ON 
		fm.opp_id = f.Opp_id
		AND fm.sequence_id = f.sequence_id
		AND fm.company_id = f.company_id
		AND fm.profit_ctr_id = f.profit_ctr_id
	WHERE fm.opp_id = @opp_id
		AND fm.sequence_id = @sequence_id
		AND fm.company_id = @company_id
		AND fm.profit_ctr_id = @profit_ctr_id
end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppFacility_Select] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppFacility_Select] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_OppFacility_Select] TO [EQAI]
    AS [dbo];

