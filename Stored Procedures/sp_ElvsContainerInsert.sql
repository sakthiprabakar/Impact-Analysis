CREATE PROCEDURE sp_ElvsContainerInsert (						
	@container_id			int,		
	@recycler_id			int,		
	@container_label		varchar(30),			
	@date_received			datetime,		
	@quantity_received		int,			
	@quantity_ineligible	int,				
	@abs_assembly_count		int,			
	@abs_count				int,	
	@light_count			int,		
	@misc_count				int,	
	@steel_count			int,		
	@mercury_count			int,		
	@container_weight		float,			
	@switch_weight			float,		
	@iAirbagSensor			int,	 --08/21/08 CMA Added		
	@status					char(1),
	@return_date			datetime = null,		
	@added_by				char(10)	
)						
AS						
--======================================================
-- Description: Inserts a record in ElvsContainer,	selects/returns back the container_id.
-- Parameters :
-- Returns    :
-- Requires   : *.PLT_AI.*
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 03/29/2006  Jonathan Broome   Initial Development
-- 08/21/2008  Chris Allen       - formatted
--                               - Add AirbagSensor 
-- 09/04/2008  CMA               - per JPB; rearranged order (steel_count with misc_count) to match INSERT order
--======================================================
BEGIN
	SET nocount on					
						
	IF @container_id is NULL OR @container_id='' OR @container_id = 0				
		BEGIN 				
			EXEC @container_id = sp_sequence_next 'ElvsContainer.container_id'			
			INSERT INTO ElvsContainer (			
				container_id,		
				recycler_id,		
				container_label,		
				date_received,		
				quantity_received,		
				quantity_ineligible,		
				abs_assembly_count,		
				abs_count,		
				light_count,		
				steel_count,		
				misc_count,		
				mercury_count,		
				container_weight,		
				switch_weight,
        AirbagSensor,		--08/21/08 CMA Added
				status,		
				return_date,		
				added_by,		
				date_added,		
				modified_by,		
				date_modified		
			) VALUES (			
				@container_id,		
				@recycler_id,		
				@container_label,		
				@date_received,		
				@quantity_received,		
				@quantity_ineligible,		
				@abs_assembly_count,		
				@abs_count,		
				@light_count,		
				@steel_count,		--09/04/08 CMA changed per JPB; rearranged order (steel_count with misc_count) to match INSERT order
				@misc_count,		--09/04/08 CMA changed per JPB; rearranged order (steel_count with misc_count) to match INSERT order
				@mercury_count,		
				@container_weight,		
				@switch_weight,	
        @iAirbagSensor,	  --08/21/08 CMA Added
				@status,		
				@return_date,		
				@added_by,		
				GetDate(),		
				@added_by,		
				GetDate()		
			)			
		END				
	ELSE					
		UPDATE ElvsContainer SET				
			recycler_id         = @recycler_id,			
			container_label     = @container_label,			
			date_received       = @date_received,			
			quantity_received   = @quantity_received,			
			quantity_ineligible = @quantity_ineligible,			
			abs_assembly_count  = @abs_assembly_count,			
			abs_count           = @abs_count,			
			light_count         = @light_count,			
			misc_count          = @misc_count,			
			steel_count         = @steel_count,			
			mercury_count       = @mercury_count,			
			container_weight    = @container_weight,			
			switch_weight       = @switch_weight,			
			AirbagSensor        = @iAirbagSensor,	 --08/21/08 CMA Added		
			status              = @status,			
			return_date         = @return_date,			
			modified_by         = @added_by,			
			date_modified       = GetDate()			
		WHERE container_id = @container_id				
						
	SET nocount OFF					


  -- BEG 08/20/08 CMA Added (below) Update ElvsRecycler.participation flag depending on whether the recycler exists in Elvs.Container table. Note: The user changes this value but occasionally the data gets out of whack. This check enforces the business rule. 
  --/* CMA removed. I put it here then decided to use the trigger. It probably doesn't need to be here anymore
  UPDATE ElvsRecycler
  SET participation_flag = 'A'
  WHERE ElvsRecycler.recycler_id IN 
  (SELECT DISTINCT(ElvsRecycler.recycler_id)
  FROM ElvsContainer LEFT OUTER JOIN ElvsRecycler ON ElvsContainer.recycler_id = ElvsRecycler.recycler_id)  
  --*/
  -- END 08/20/08 CMA Added (above)

						
	SELECT @container_id AS container_id					
	RETURN @container_id					
END -- CREATE PROCEDURE sp_ElvsContainerInsert

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsContainerInsert] TO [EQAI]
    AS [dbo];

