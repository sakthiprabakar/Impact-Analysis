
create proc sp_EquipmentSet_UpdateURL (
	  @equipment_set_id	int
	, @url_snippet	varchar(max)
)
as
/* *******************************************************************
sp_EquipmentSet_UpdateURL

	Update the url_snippet field for a EquipmentSet record

History:
	2014-04-28	JPB	Created

Sample: 
	sp_EquipmentSet_UpdateURL 1000, 'http://blablalba'
	
******************************************************************* */

update EquipmentSet set 
	url_snippet = @url_snippet
where equipment_set_id = @equipment_set_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EquipmentSet_UpdateURL] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EquipmentSet_UpdateURL] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_EquipmentSet_UpdateURL] TO [EQAI]
    AS [dbo];

