
create proc sp_Equipment_Set_Void (
	@equipment_set_id		int
	, @modified_by			varchar(10)
)
as
/* *******************************************************************
sp_Equipment_Set_Void

	Changes the status on Equipment with a given set_id to 'V'

History:
	2014-04-25	JPB	Created

sp_Equipment_Set_Void 1074
******************************************************************* */

update EquipmentSet set status = 'V', modified_by = @modified_by, date_modified = GETDATE() where equipment_set_id = @equipment_set_id
update Equipment set status = 'V', modified_by = @modified_by, date_modified = GETDATE() where equipment_id in (
	select equipment_id from EquipmentXEquipmentSet where equipment_set_id = @equipment_set_id
)


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Set_Void] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Set_Void] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Set_Void] TO [EQAI]
    AS [dbo];

