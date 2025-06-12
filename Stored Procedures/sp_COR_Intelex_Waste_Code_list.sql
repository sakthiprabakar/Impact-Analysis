-- drop proc if exists sp_COR_Intelex_Waste_Code_list
go
create proc sp_COR_Intelex_Waste_Code_list
	@web_userid		varchar(100)
	, @start_date		datetime
	, @end_date		datetime
as

/*
sp_COR_Intelex_Waste_Code_list
@web_userid = 'svc_cvs_intelex'
	, @start_date  = '11/2/2019'
	, @end_date	 = '11/2/2021'

sp_COR_Intelex_Waste_Code_list 
	@web_userid = 'dani_e'
	, @start_date = '1/1/2020'
	, @end_date	= '2/8/2020'

sp_COR_Intelex_Waste_Profile_list 
	@web_userid = 'dani_e'
	, @start_date = '1/1/2020'
	, @end_date	= '2/8/2020'

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

select top 1 @i_contact_id = contact_id from Contact WHERE web_userid = @i_web_userid

-- 4/21/2021 ReeeeeMiiiixxxx!
-- Re-wrote the Profile SP so you can call it from another sp and snag its output
-- for re-use here.
-- This gives us all the profiles & tsdf approvals we need to report waste-codes on.

create table #profiles (profile_type char(1), profile_id int, profile_number varchar(40), description varchar(max), pharmacy_exception varchar(5), nicotine_exception varchar(5))

set nocount on
exec sp_COR_Intelex_Waste_Profile_list	
	@web_userid = @i_web_userid
	, @start_date = @i_start_date
	,@end_date = @i_end_date

set nocount off

-- SELECT  * FROM    #profiles

select distinct [waste code], [profile number] as [Waste Profiles]
from (

select distinct
	
	--p.profile_id, 
	
	[Waste Code] = Ltrim(rtrim(isnull(WC.state+'-', '')))+Ltrim(rtrim(WC.display_name))
	
	, [Profile Number] = p.profile_number
	/*
	Number to uniquely identify the record	
	CVS to confirm	
	Text
	*/

from #profiles p
JOIN profilewastecode pwc (nolock)
	on p.profile_id = pwc.profile_id
JOIN wastecode wc (nolock)
	on pwc.waste_code_uid = wc.waste_code_uid
	and WC.display_name <> 'NONE'
WHERE
	p.profile_type = 'P'
	
UNION

select distinct
	
	[Waste Code] = Ltrim(rtrim(isnull(WC.state+'-', '')))+Ltrim(rtrim(WC.display_name))
	
	, [Profile Number] = p.profile_number
	/*
	Number to uniquely identify the record	
	CVS to confirm	
	Text
	*/


from #profiles p
JOIN tsdfapprovalwastecode twc (nolock) 
	on p.profile_id = twc.tsdf_approval_id
	--and t.company_id = twc.company_id
	--and t.profit_ctr_id = twc.profit_ctr_id
JOIN wastecode wc (nolock)
	on twc.waste_code_uid = wc.waste_code_uid
	and WC.display_name <> 'NONE'
WHERE 
p.profile_type = 'T'
and @include_tsdf_approvals = 1
) src
ORDER BY [waste code], [profile number]


go

grant execute on sp_COR_Intelex_Waste_Code_list
to cor_user
go

grant execute on sp_COR_Intelex_Waste_Code_list
to eqai
go

grant execute on sp_COR_Intelex_Waste_Code_list
to eqweb
go

grant execute on sp_COR_Intelex_Waste_Code_list
to CRM_Service
go

grant execute on sp_COR_Intelex_Waste_Code_list
to DATATEAM_SVC
go

