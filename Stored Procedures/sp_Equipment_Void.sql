
create proc sp_Equipment_Void (
	  @equipment_set_id		int
)
as
/* *******************************************************************
sp_Equipment_Void

	Void the equipment for a specific set

History:
	2014-04-28	JPB	Created

Sample: 
	sp_Equipment_Void 3
	
******************************************************************* */

-- Clear out old, unsigned records before adding new ones.
	-- Remove any sets for this user that are not signed.
	update EquipmentSet set status = 'V' where equipment_set_id = @equipment_set_id

	update Equipment set status = 'V' where equipment_id in (
		select equipment_id from EquipmentXEquipmentSet where equipment_set_id = @equipment_set_id
	)	


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Void] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Void] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Void] TO [EQAI]
    AS [dbo];

