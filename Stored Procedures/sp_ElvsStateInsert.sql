CREATE PROCEDURE sp_ElvsStateInsert (								
	@state							char(2),
	@bounty_flag					char(1),		
	@bounty_rate					float,		
	@number_contacted				int,			
	@vin_required					char(1),		/* T/ F */
	@vin_based_switch_count			char(1),		/* T/ F */		
	@switches_per_abs_assembly		float,					
	@show_detail_or_total			char(1),		/* D/ T */		
	@modified_by					char(10)		
)								
AS								
--======================================================
-- Description: Inserts an ElvsState row
-- Parameters :
-- Returns    :
-- Requires   : *.PLT_AI.*
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 03/23/2006  Jonathan Broome   Initial Development
-- 08/25/2008  Chris Allen       Formatted
--======================================================
BEGIN
	IF Len(@bounty_flag) = 0 SET @bounty_flag = 'F'								
		IF NOT EXISTS (SELECT state FROM elvsState WHERE state = @state)								
			INSERT ElvsState (							
				state						,
				bounty_flag					,	
				bounty_rate					,	
				number_contacted			,			
				vin_required				,		
				vin_based_switch_count		,				
				switches_per_abs_assembly	,					
				show_detail_or_total		,				
				added_by					,	
				date_added					,	
				modified_by					,	
				date_modified						
			) VALUES (							
				@state						,
				@bounty_flag				,		
				@bounty_rate				,		
				@number_contacted			,			
				@vin_required				,		
				@vin_based_switch_count		,				
				@switches_per_abs_assembly	,					
				@show_detail_or_total		,				
				@modified_by,						
				GetDate(),						
				@modified_by,						
				GetDate()						
			)							

END -- CREATE PROCEDURE sp_ElvsStateInsert

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsStateInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsStateInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsStateInsert] TO [EQAI]
    AS [dbo];

