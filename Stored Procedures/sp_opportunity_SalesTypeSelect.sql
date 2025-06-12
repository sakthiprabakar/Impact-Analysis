
create procedure sp_opportunity_SalesTypeSelect
/*
Usage: sp_opportunity_SalesTypeSelect
*/
as

	select code, description from OppSalesType order by code


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_SalesTypeSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_SalesTypeSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_SalesTypeSelect] TO [EQAI]
    AS [dbo];

