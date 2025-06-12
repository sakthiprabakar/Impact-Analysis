-- drop proc if exists sp_COR_Costco_Intelex_Waste_Code_list
go
create proc sp_COR_Costco_Intelex_Waste_Code_list
	@web_userid		varchar(100)
	, @start_date		datetime
	, @end_date		datetime
as

/*
exec sp_COR_Costco_Intelex_Waste_Code_list @web_userid = 'use@costco.com'
	, @start_date  = '10/1/2020' -- '2/1/2020'
	, @end_date	 = '10/1/2020' -- '2/8/2020'


SELECT  * FROM    profilequoteapproval where approval_code like '%~%'
SELECT  * FROM    tsdfapproval where tsdf_approval_code like '%~%'

Intelex
---------------

Some basic assumptions...
1. We only return information from work orders.
2. 


Manifest

Outputs
Field Name
	Description	
	Length	
	Type	
	Mandatory
	USE Table.Field

Profile Number	
	Number to uniquely identify the record	
	CVS to confirm	
	Text
	
Description	
	Text field to identify a description if applicable	
	CVS to confirm	
	Text
	
Pharmacy Exception	
	Determines if the waste profile should be excluded for acute hazardous waste in applicable states	
	N/A	
	Yes/No
	-- from Mara Poe 7/9/20: Pharmacy Exception – items meeting the exception will have a PHRM waste code
	
Nicotine Exception	
	Determines if the waste profile should be excluded for acute hazardous wastes in applicable states	
	N/A	
	Yes/No
	-- from Mara Poe 7/9/20: Nicotine Exception – items that may meet the exception will have a P075 waste code on the profile

*/

/*
--- Debuggery
declare @web_userid varchar(100) = 'svc_cvs_intelex'
	, @start_date datetime = null -- '2/1/2020'
	, @end_date	datetime = null -- '2/8/2020'
*/
	
declare 
	@i_web_userid		varchar(100)	= isnull(@web_userid, '')
	, @i_start_date		datetime		= coalesce(@start_date, convert(date,getdate()-7))
	, @i_end_date		datetime		= coalesce(@end_date, @start_date+7, convert(date, getdate()))
	, @i_contact_id		int
	, @include_tsdf_approvals bit = 1

	insert plt_export..work_Intelex_Costco_Log (log_message)
	values ('(' + convert(varchar(10), @@spid) + ') exec sp_COR_Costco_Intelex_Waste_Code_list ''' + @i_web_userid + ''', ''' + convert(varchar(40), @start_date, 121) + ''', ''' + convert(varchar(40), @end_date, 121) + '''')

select top 1 @i_contact_id = contact_id from Contact WHERE web_userid = @i_web_userid

create table #profiles (
	profile_type char(1)
	, profile_id int
	, profile_number varchar(40)
	, name varchar(255)
	, description varchar(max)
	, dot_description varchar(max)
	, pharmacy_exception varchar(5)
	, nicotine_exception varchar(5)
)

set nocount on
exec sp_COR_Costco_Intelex_Waste_Profile_list	
	@web_userid = @i_web_userid
	, @start_date = @i_start_date
	,@end_date = @i_end_date

set nocount off

truncate table plt_export.dbo.work_Intelex_Costco_Waste_Code_list

insert plt_export.dbo.work_Intelex_Costco_Waste_Code_list
(
	[Waste Code]	,
	[Description]	,
	[Profile Number]
)
select distinct [waste code], [Description], [profile number] as [Waste Profiles]
from (

select distinct
	
	--p.profile_id, 
	
	[Waste Code] = Ltrim(rtrim(isnull(WC.state+'-', '')))+Ltrim(rtrim(WC.display_name))
	
	, [Description] = wc.waste_code_desc
	
	, [Profile Number] = p.profile_number


from #profiles p
JOIN profilewastecode pwc (nolock)
	on p.profile_id = pwc.profile_id
JOIN wastecode wc (nolock)
	on pwc.waste_code_uid = wc.waste_code_uid
	and WC.display_name <> 'NONE'
WHERE p.profile_type = 'P'

UNION

select distinct
	
	[Waste Code] = Ltrim(rtrim(isnull(WC.state+'-', '')))+Ltrim(rtrim(WC.display_name))
	
	, [Description] = wc.waste_code_desc

	, [Profile Number] = p.profile_number



from #profiles p
JOIN tsdfapprovalwastecode twc (nolock) 
	on p.profile_id = twc.tsdf_approval_id
	--and t.company_id = twc.company_id
	--and t.profit_ctr_id = twc.profit_ctr_id
JOIN wastecode wc (nolock)
	on twc.waste_code_uid = wc.waste_code_uid
	and WC.display_name <> 'NONE'
WHERE p.profile_type = 'T'
and @include_tsdf_approvals = 1
) src
ORDER BY [waste code], [profile number]

	insert plt_export..work_Intelex_Costco_Log (log_message)
	values ('(' + convert(varchar(10), @@spid) + ') sp_COR_Costco_Intelex_Waste_Code_list populated plt_export.dbo.work_Intelex_Costco_Waste_Code_list with ' + convert(varchar(10), @@rowcount) + ' rows and finished')

go

grant execute on sp_COR_Costco_Intelex_Waste_Code_list
to cor_user
go

grant execute on sp_COR_Costco_Intelex_Waste_Code_list
to eqai
go

grant execute on sp_COR_Costco_Intelex_Waste_Code_list
to eqweb
go

grant execute on sp_COR_Costco_Intelex_Waste_Code_list
to CRM_Service
go

grant execute on sp_COR_Costco_Intelex_Waste_Code_list
to DATATEAM_SVC
go

