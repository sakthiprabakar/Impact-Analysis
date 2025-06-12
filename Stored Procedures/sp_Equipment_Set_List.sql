
create proc sp_Equipment_Set_List (
	  @equipment_set_id int
)
as
/* *******************************************************************
sp_Equipment_Set_List

	Select Equipment records for a user that are not signed yet.

History:
	2014-03-05	JPB	Created

sp_Equipment_Set_List 1010	
******************************************************************* */

select distinct
	u.user_code
	, u.user_name
	, u.email
	, e.equipment_type
	, e.equipment_desc
	, es.*
from EquipmentXEquipmentSet exes
INNER JOIN Equipment e on exes.equipment_id = e.equipment_id
inner join EquipmentSet eset on exes.equipment_set_id = eset.equipment_set_id and eset.status <> 'V'
inner join users u on e.user_code = u.user_code
left join EquipmentSetXEquipmentSignature esxes on esxes.equipment_set_id = exes.equipment_set_id
left join EquipmentSignature es on esxes.signature_id = es.signature_id
where exes.equipment_set_id = @equipment_set_id
/*
and e.status = 'A'
and not exists (
	select 1 
	from EquipmentSetXEquipmentSignature s
	where s.equipment_set_id = exes.equipment_set_id
)
*/


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Set_List] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Set_List] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Set_List] TO [EQAI]
    AS [dbo];

