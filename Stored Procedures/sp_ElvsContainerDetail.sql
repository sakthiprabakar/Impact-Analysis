			
CREATE PROCEDURE sp_ElvsContainerDetail (			
	@container_id		int
)			
AS			
--======================================================
-- Description: Returns detail data for a container_id	
-- Parameters :
-- Returns    :
-- Requires   : *.PLT_AI.*
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 05/04/2006  Jonathan Broome   Initial Development
-- 08/25/2008  Chris Allen       Formatted
--
--======================================================
BEGIN
	SELECT		
		detail_id,	
		container_id,	
		vin,	
		valid_vin_flag,	
		vin_test_result,	
		valid_vin_date,	
		make,	
		year,	
		bounty_paid_date,	
		abs_assemblies,	
		abs_switches,	
		light_switches,	
		date_removed,	
		passed_validation,	
		added_by,	
		date_added,	
		modified_by,	
		date_modified	
	FROM elvsContainerDetail		
	WHERE container_id = @container_id		
	ORDER BY detail_id		
END -- CREATE PROCEDURE sp_ElvsContainerDetail			

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerDetail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerDetail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerDetail] TO [EQAI]
    AS [dbo];

