
create procedure sp_opportunity_JobTypeSelect
/*
Usage: sp_opportunity_SalesTypeSelect
*/
as
SELECT code,
       DESCRIPTION
FROM   OppJobType
ORDER  BY code 



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_JobTypeSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_JobTypeSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_opportunity_JobTypeSelect] TO [EQAI]
    AS [dbo];

