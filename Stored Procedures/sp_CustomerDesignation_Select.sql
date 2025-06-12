
create procedure sp_CustomerDesignation_Select
@designation_id int = null
/*
Usage: sp_CustomerDesignation_Select
*/

as
BEGIN

SELECT Designation_ID,
       Designation_Code,
       Designation,
       DESCRIPTION
FROM   CustomerDesignation
where designation_id = coalesce(@designation_id, designation_id)
ORDER  BY Designation_ID DESC

end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerDesignation_Select] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerDesignation_Select] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_CustomerDesignation_Select] TO [EQAI]
    AS [dbo];

