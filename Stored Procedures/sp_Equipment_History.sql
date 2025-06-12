
create proc sp_Equipment_History (
	  @user_code varchar(10)
)
as
/* *******************************************************************
sp_Equipment_History

	Select Equipment records for a user

History:
	2014-03-05	JPB	Created

sp_Equipment_History 'jonathan'	
******************************************************************* */

select distinct 
	eset.equipment_set_id
	, eset.url_snippet		
	, eset.user_code		
	, eset.status as set_status
	, eset.date_added as set_date_added
	, eset.added_by as set_added_by
	, eset.date_modified as set_date_modified
	, eset.modified_by as set_modified_by
	, esig.*
from
	EquipmentSet eset
	LEFT JOIN EquipmentSetXEquipmentSignature x
		on eset.equipment_set_id = x.equipment_set_id
	LEFT JOIN EquipmentSignature esig
		on x.signature_id = esig.signature_id
where
	eset.user_code = @user_code
	and eset.status <> 'V'
order by
	eset.date_added desc


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_History] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_History] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_History] TO [EQAI]
    AS [dbo];

