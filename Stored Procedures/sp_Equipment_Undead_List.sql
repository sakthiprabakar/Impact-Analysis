/*
-- Commented 6/25/2019 - JPB - error deploying to misousqldev01, seems like deprecated code.

create proc sp_Equipment_Undead_List
as
/-* *******************************************************************
sp_Equipment_Undead_List

	List of terminated users who still have equipment assigned to them in AssetManager
	I shall call them Undead, because Nosferatu is too strange a word.

		Jonathan Harker: She's alive?
		Van Helsing: She's Nosferatu.
		Jonathan Harker: She's Italian?

History:
	2014-05-09	JPB	Created

sp_Equipment_Undead_List

******************************************************************* *-/

	select distinct
		u.user_name
		, AAALogin.NAME
		, CIType.TYPENAME -- Windows Workstation, Monitor, Printer, etc.
		, case CIType.Typename 
			when 'Windows Workstation' then
				isnull(SystemInfo.Manufacturer + ' ', '') + 
				case when (CIType.TYPENAME in ('Windows Workstation') and (CI.CIName like '%-LT.%' OR CI.CIName like '%-L.%')) then 'Laptop' else 'Desktop' end + ' ' + -- isnull('Model ' + SystemInfo.Model + ' ', '') + 
				isnull('Serial # ' + SystemInfo.ServiceTag, '') 
			else
				isnull(ComponentDefinition.MANUFACTURERNAME + ' ', '') + isnull(ComponentDefinition.PARTNO + ' - ', '') + isnull(CI.CINAME, 'UNKNOWN TYPE/DESCRIPTION!')
		end as description
	from
		assetexplorer.assetexplorer.dbo.CI CI
	LEFT JOIN assetexplorer.assetexplorer.dbo.CIRelationships CIRelationships 
		on (CI.CIID = CIRelationships.CIID OR CI.CIID = CIRelationships.CIID2)
	inner join assetexplorer.assetexplorer.dbo.SDUser SDUser
		on (CIRelationships.CIID = SDUser.CIID)
	inner join assetexplorer.assetexplorer.dbo.AAALogin AAALogin 
		on SDUser.USERID = AAALogin.USER_ID
	left outer join assetexplorer.assetexplorer.dbo.CIType CIType
		on CI.CITYPEID = CIType.TYPEID
	left outer join assetexplorer.assetexplorer.dbo.Resources Resources
		on (CIRelationships.CIID = Resources.CIID OR CIRelationships.CIID2 = Resources.CIID)
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
	INNER JOIN assetexplorer.assetexplorer.dbo.ResourceStateHistory History
		ON History.resourceid = Resources.ResourceID and History.resourcestateid = 2
	INNER join users u
		on AAALogin.name = u.user_code
		and u.group_id = 0
	where 1=1
		and ( 1=0
		--	LAPTOP
			or (CIType.TYPENAME in ('Windows Workstation') and (CI.CIName like '%-LT.%' OR CI.CIName like '%-L.%'))
		--	or CELLULAR DEVICE
			or CIType.TYPENAME in ('Cell Phone', 'Wireless AP')
		--	or HOME OFFICE CI.SITEID
			or SDOrganization.Name = 'Home office'
		)
		and CITYPE.TYPENAME <> 'Requester'
	order by
		u.user_name
		

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Undead_List] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Undead_List] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Equipment_Undead_List] TO [EQAI]
    AS [dbo];

*/
