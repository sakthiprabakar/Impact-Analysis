
CREATE PROCEDURE sp_RegionSelect
	@region_id int = NULL
/*
Usage: sp_RegionSelect
*/
AS
	SELECT * FROM (
		SELECT 0 as region_id,
		'(other)' as region_desc
		UNION
		SELECT
			*
		FROM   Region
	) tbl 
	where region_id = coalesce(@region_id, region_id)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RegionSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RegionSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_RegionSelect] TO [EQAI]
    AS [dbo];

