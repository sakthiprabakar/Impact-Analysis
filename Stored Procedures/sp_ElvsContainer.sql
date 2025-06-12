			
CREATE PROCEDURE sp_ElvsContainer (			
	@container_id		int
)			
AS			
--======================================================
-- Description:	Retrieves ElvsContainer Info for a specific container id
-- Parameters :
-- Returns    :
-- Requires   : *.PLT_AI.*
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 05/03/2006  Jonathan Broome   Initial Development
-- 08/21/2008  Chris Allen       - formatted
--                               - Add AirbagSensor 
--======================================================
BEGIN
	SELECT			
		c.container_id,		
		c.recycler_id,		
		c.container_label,		
		c.date_received,		
		c.quantity_received,		
		c.quantity_ineligible,		
		c.abs_assembly_count,		
		c.abs_count,		
		c.light_count,		
		c.misc_count,		
		c.steel_count,		
		c.mercury_count,		
		c.container_weight,		
		c.switch_weight,		
		c.AirbagSensor,	--08/21/08 CMA Added	
		c.status,		
		c.return_date,		
		c.added_by,		
		c.date_added,		
		c.modified_by,		
		c.date_modified,		
		r.recycler_name,		
		s.vin_required,		
		s.vin_based_switch_count,		
		s.switches_per_abs_assembly,		
		s.show_detail_or_total		
	FROM ElvsContainer c			
		INNER JOIN elvsRecycler r on c.recycler_id = r.recycler_id AND r.status = 'A'		
		INNER JOIN elvsState s on r.shipping_state = s.state		
	WHERE c.container_id = @container_id			

END --  CREATE PROCEDURE sp_ElvsContainer

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainer] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainer] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainer] TO [EQAI]
    AS [dbo];

