
create proc sp_Equipment_AssetManger_Import (
	  @user_code		varchar(10)
	, @added_by			varchar(10)
)
as
/* *******************************************************************
sp_Equipment_AssetManger_Import

	Insert a record into EquipmentSurvey

History:
	2014-02-28	JPB	Created
	2014-05-09	JPB	Revised order of operations - set comes after import,
		and only creates set if import had records found.

Sample: 
	sp_Equipment_AssetManger_Import 'jonathan', 'Jonathan'	
	
	SELECT top 10 * FROM Equipment order by equipment_id desc
	SELECT * FROM EquipmentSet
	SELECT * FROM EquipmentXEquipmentSet
******************************************************************* */

-- Create a new set (we want the ID):
declare @equipment_set_id int, @insert_date datetime = getdate()

-- Clear out old, unsigned records before adding new ones.
	-- Remove any sets for this user that are not signed.
	delete from EquipmentSet 
	where user_code = @user_code 
	and not exists (
		select 1 from EquipmentSetXEquipmentSignature s 
		where s.equipment_set_id = EquipmentSet.equipment_set_id
	)

	-- Remove any equipment-equipmentset links for sets that don't exist.
	delete from EquipmentXEquipmentSet
	where equipment_set_id not in (select equipment_set_id from EquipmentSet)

	-- Remove any equipment that's not linked to a set.
	delete from Equipment
	where equipment_id not in (select equipment_id from EquipmentXEquipmentSet)

-- Oh what a tangled web we weave, when first we practice to ... make everything relational.
-- We could use triggers for this, but that makes things less visible.


-- declare @user_code varchar(10) = 'jonathan', @added_by varchar(10) = 'jonathan'
insert Equipment (
	equipment_type	
	, equipment_desc	
	, user_code		
	, status
	, date_added		
	, added_by		
	, date_modified	
	, modified_by		
)
-- declare @user_code varchar(10) = 'jonathan', @added_by varchar(10) = 'jonathan'
select distinct
  CIType.TYPENAME -- Windows Workstation, Monitor, Printer, etc.
  , case CIType.Typename 
		when 'Windows Workstation' then
			isnull(SystemInfo.Manufacturer + ' ', '') + 
			case when (CIType.TYPENAME in ('Windows Workstation') and (CI.CIName like '%-LT.%' OR CI.CIName like '%-L.%')) then 'Laptop' else 'Desktop' end + ' ' + -- isnull('Model ' + SystemInfo.Model + ' ', '') + 
			isnull('Serial # ' + SystemInfo.ServiceTag, '') 
		else
			isnull(ComponentDefinition.MANUFACTURERNAME + ' ', '') + isnull(ComponentDefinition.PARTNO + ' - ', '') + isnull(CI.CINAME, 'UNKNOWN TYPE/DESCRIPTION!')
	end as description
  , @user_code
  , 'A'
  , @insert_date
  , @added_by
  , @insert_date
  , @added_by
from
	assetexplorer.assetexplorer.dbo.CI CI
LEFT JOIN assetexplorer.assetexplorer.dbo.CIRelationships CIRelationships 
	on (CI.CIID = CIRelationships.CIID OR CI.CIID = CIRelationships.CIID2)
inner join assetexplorer.assetexplorer.dbo.SDUser SDUser
	on (CIRelationships.CIID = SDUser.CIID)
inner join assetexplorer.assetexplorer.dbo.AAALogin AAALogin 
	on SDUser.USERID = AAALogin.USER_ID
left outer join assetexplorer.assetexplorer.dbo.Resources Resources
	on (CIRelationships.CIID = Resources.CIID OR CIRelationships.CIID2 = Resources.CIID)
left outer join assetexplorer.assetexplorer.dbo.CIType CIType
	on CI.CITYPEID = CIType.TYPEID
left join assetexplorer.assetexplorer.dbo.SystemInfo SystemInfo
	on Resources.RESOURCEID = SystemInfo.WORKSTATIONID
left join assetexplorer.assetexplorer.dbo.OsInfo OsInfo
	on Resources.RESOURCEID = OsInfo.WORKSTATIONID
left join assetexplorer.assetexplorer.dbo.MemoryInfo MemoryInfo
	on Resources.RESOURCEID = MemoryInfo.WORKSTATIONID
left join assetexplorer.assetexplorer.dbo.ResourceOwner ResourceOwner
	on Resources.RESOURCEID = ResourceOwner.RESOURCEID
left join assetexplorer.assetexplorer.dbo.ComponentDefinitionLaptop ComponentDefinitionLaptop
	on Resources.COMPONENTID = ComponentDefinitionLaptop.COMPONENTID
left join assetexplorer.assetexplorer.dbo.ResourceAssociation ResourceAssociation
	on ResourceOwner.RESOURCEOWNERID = ResourceAssociation.RESOURCEOWNERID
left join assetexplorer.assetexplorer.dbo.Resources OwnerResource
	on ResourceAssociation.ASSTTORESOURCEID = OwnerResource.RESOURCEID
left join assetexplorer.assetexplorer.dbo.AaaUser AaaUser
	on ResourceOwner.USERID = AaaUser.USER_ID
left join assetexplorer.assetexplorer.dbo.ResourceLocation ResourceLocation
	on Resources.RESOURCEID = ResourceLocation.RESOURCEID
left join assetexplorer.assetexplorer.dbo.SiteDefinition SiteDefinition
	on ResourceLocation.SITEID = SiteDefinition.SITEID
left join assetexplorer.assetexplorer.dbo.SDOrganization SDOrganization
	on SiteDefinition.SITEID = SDOrganization.ORG_ID
left join assetexplorer.assetexplorer.dbo.ResourceState ResourceState
	on Resources.RESOURCESTATEID = ResourceState.RESOURCESTATEID
LEFT JOIN assetexplorer.assetexplorer.dbo.ComponentDefinition ComponentDefinition 
	ON Resources.COMPONENTID=ComponentDefinition.COMPONENTID 
where 1=1
	and AAALogin.NAME = @user_code
	and ( 1=0
	--	LAPTOP
		or (CIType.TYPENAME in ('Windows Workstation') and (CI.CIName like '%-LT.%' OR CI.CIName like '%-L.%'))
	--	or CELLULAR DEVICE
		or CIType.TYPENAME in ('Cell Phone', 'Wireless AP')
	--	or HOME OFFICE CI.SITEID
		or SDOrganization.Name = 'Home office'
	)
	and CITYPE.TYPENAME <> 'Requester'

if @@ROWCOUNT > 0 begin

	insert EquipmentSet (user_code, status, date_added, added_by, date_modified, modified_by)
		values (@user_code, 'A', @insert_date, @added_by, @insert_date, @added_by)

	set @equipment_set_id = @@IDENTITY

	-- We'll update the url_snippet from ASP later. Can't generate the encoded string reasonably in SQL.

	Insert EquipmentXEquipmentSet (equipment_id, equipment_set_id)
	select equipment_id, @equipment_set_id
	from Equipment
	where date_added = @insert_date
	and added_by = @added_by
	
	select @equipment_set_id as set_id

end


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_AssetManger_Import] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_AssetManger_Import] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_AssetManger_Import] TO [EQAI]
    AS [dbo];

