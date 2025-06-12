CREATE PROCEDURE sp_ElvsStateUpdate (								
	@state							char(2),
	@bounty_flag					char(1),		
	@bounty_rate					float = NULL,		
	@number_contacted				int = NULL,			
	@vin_required					char(1),		/* T/ F */
	@vin_based_switch_count			char(1),		/* T/ F */		
	@switches_per_abs_assembly		float,					
	@show_detail_or_total			char(1),		/* D/ T */		
	@modified_by					char(10)		
)								
AS								
--======================================================
-- Description: Updates an ElvsState row
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
	UPDATE ElvsState SET	
		bounty_flag = @bounty_flag,
		bounty_rate = @bounty_rate,
		number_contacted = @number_contacted,
		vin_required = @vin_required,
		vin_based_switch_count = @vin_based_switch_count,
		switches_per_abs_assembly = @switches_per_abs_assembly,
		show_detail_or_total = @show_detail_or_total,
		modified_by = @modified_by,
		date_modified = GetDate()
	WHERE state = @state	
END -- CREATE PROCEDURE sp_ElvsStateUpdate

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsStateUpdate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsStateUpdate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_ElvsStateUpdate] TO [EQAI]
    AS [dbo];

