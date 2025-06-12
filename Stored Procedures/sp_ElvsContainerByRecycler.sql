-- drop proc if exists sp_ElvsContainerByRecycler
go
	
CREATE PROCEDURE sp_ElvsContainerByRecycler (@id int)						
AS						
/* ======================================================
-- Description: Returns container information for display on the website in detail format
-- Parameters :
-- Returns    : 
-- Requires   : *.PLT_AI.*
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 03/23/2006  Jonathan Broome   Initial Development
-- 07/18/2006  JPB 			         Removed DISTINCT FROM query to avoid skipping similar buckets						
-- 08/20/2008  Chris Allen       - return AirbagSensor 
--                               - return sums that include total of switches accepted. (AirbagSensor, quantity_ineligible 
	06/29/2022 JPB				 - added total_weight_of_mercury output
	
	SELECT  TOP 10 *
	FROM    ElvsContainer 
	WHERE abs_count > 0
	ORDER BY date_added desc
	
	sp_ElvsContainerByRecycler 11937
======================================================
*/
BEGIN
	SELECT 					
    container_id, 
		container_label	,		/* Container's Unique ID FROM it's label */	
		date_received		,		/* Date Container was Received */
		Isnull(abs_assembly_count, 0) as abs_assembly_count,
		IsNull(abs_count,0) AS abs_count,				
		IsNull(light_count,0) AS light_count,				
		IsNull(misc_count,0) AS misc_count,				
		IsNull(AirbagSensor,0) AS AirbagSensor,		--08/22/08 CMA Added 
		quantity_ineligible,		/* Number of items in bucket that are rejected */		
		--BEG 08/25/08 CMA Removed and Added (below) to make consistent with other sp IsNull(abs_count,0) +	IsNull(light_count,0) + IsNull(misc_count,0) AS quantity_received,				
    /*
		IsNull(				
			(	SELECT Sum(IsNull(c.abs_count,0)) + Sum(IsNull(c.light_count,0)) + Sum(IsNull(c.misc_count,0)) + Sum(IsNull(c.AirbagSensor,0)) + Sum(IsNull(c.quantity_ineligible,0))		
				FROM ElvsContainer c		
				WHERE c.recycler_id = @id	
				AND c.status = 'A'		
        GROUP BY c.date_received --container_id
			)			
			,0) AS total_switches_accepted			
    */
		Sum(IsNull(c.abs_count,0)) + Sum(IsNull(c.light_count,0)) + Sum(IsNull(c.misc_count,0)) + Sum(IsNull(c.AirbagSensor,0)) + Sum(IsNull(c.quantity_ineligible,0)) AS total_switches_accepted
		,isnull(c.quantity_received,0) * 0.0022 as total_weight_of_mercury
		
    --END 08/25/08 CMA Added (above)
	FROM					
		ElvsContainer	c			
	WHERE					
		recycler_id = @id				
		AND status = 'A'				
		AND (IsNull(abs_count,0) +				
			IsNull(light_count,0) +			
			IsNull(misc_count,0)) > 0			

	--08/25/08 CMA Added (line below)
  GROUP BY container_id, container_label, date_received, abs_assembly_count,abs_count, light_count, misc_count, AirbagSensor, quantity_ineligible, quantity_received --container_id

						
	ORDER BY date_received desc					
END -- CREATE PROCEDURE sp_ElvsContainerByRecycler

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerByRecycler] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerByRecycler] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerByRecycler] TO [EQAI]
    AS [dbo];

