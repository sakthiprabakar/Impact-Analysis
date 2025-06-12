
create procedure sp_opportunity_StatusSelect
	@status_type varchar(20) /*Opp, OppTracking*/
as

SELECT code,
       DESCRIPTION
FROM   OppStatusLookup
WHERE  TYPE = @status_type




GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_StatusSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_StatusSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_StatusSelect] TO [EQAI]
    AS [dbo];

