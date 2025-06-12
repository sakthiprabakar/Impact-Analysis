
create proc sp_Equipment_UnSigned_List
as
/* *******************************************************************
sp_Equipment_UnSigned_List

	List of who has AssetManager equipment but not an EquipmentSet
	(Only counts as an EquipmentSet if it got an email.  Unmailed = Isn't real)

History:
	2014-05-09	JPB	Created

sp_Equipment_UnSigned_List

******************************************************************* */

	select u.user_name, u.user_code, min(exm.date_added) as date_first_emailed
	, case when max(exm.date_added) = min(exm.date_added) then null else max(exm.date_added) end as date_last_emailed
	from EquipmentSetXMessage exm
	join EquipmentSet e on exm.equipment_set_id = e.equipment_set_id and e.status <> 'V'
	join users u on e.user_code = u.user_code
	where exm.message_type = 'Signature Required'
	and not exists (
		select 1 from EquipmentSetXMessage exm2
		join EquipmentSet e2 on exm2.equipment_set_id = e2.equipment_set_id and e2.status <> 'V'
		join users u2 on e2.user_code = u2.user_code
		where u2.user_code = u.user_code
		and exm2.message_type = 'Signature Received'
		and exm2.date_added > exm.date_added
		and exm2.equipment_set_id = exm.equipment_set_id
	)	
	group by u.user_name, u.user_code
	order by u.user_name


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_UnSigned_List] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_UnSigned_List] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_UnSigned_List] TO [EQAI]
    AS [dbo];

