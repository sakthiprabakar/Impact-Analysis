
create procedure sp_opportunity_ServiceTypeSelect
/*
Usage: sp_opportunity_SalesTypeSelect
*/
as

	SELECT code,
		   DESCRIPTION
	FROM   OppServiceType
	ORDER  BY description, code 


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_ServiceTypeSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_ServiceTypeSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_ServiceTypeSelect] TO [EQAI]
    AS [dbo];

