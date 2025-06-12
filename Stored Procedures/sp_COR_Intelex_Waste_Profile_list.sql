-- 
drop proc if exists sp_COR_Intelex_Waste_Profile_list
go
create proc sp_COR_Intelex_Waste_Profile_list
	@web_userid		varchar(100)
	, @start_date		datetime
	, @end_date		datetime
as

/*
sp_COR_Intelex_Waste_Profile_list

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



-optional:
create table #profiles (profile_type char(1), profile_id int, profile_number varchar(40), description varchar(max), pharmacy_exception varchar(5), nicotine_exception varchar(5))

exec sp_COR_Intelex_Waste_Profile_list	@web_userid = 'svc_cvs_intelex'
	, @start_date = '11/1/2020'
	,@end_date = '4/4/2021'

SELECT  * FROM    #profiles

drop table #profiles	
*/

/*
--- Debuggery
declare @web_userid varchar(100) = 'svc_cvs_intelex'
	, @start_date datetime = '11/1/2020'
	, @end_date	datetime = '4/4/2021'

*/
	
declare 
	@i_web_userid		varchar(100)	= isnull(@web_userid, '')
	, @i_start_date		datetime		= coalesce(@start_date, convert(date,getdate()-7))
	, @i_end_date		datetime		= coalesce(@end_date, @start_date+7, convert(date, getdate()))
	, @i_contact_id		int
	, @include_tsdf_approvals bit = 1

select top 1 @i_contact_id = contact_id from Contact WHERE web_userid = @i_web_userid

drop table if exists #output
drop table if exists #source

select distinct *
into #Output
from (

select distinct
	
	'P' as profile_type,
	
	p.profile_id, 
	
	[Profile Number] = pqa.approval_code
	/*
	Number to uniquely identify the record	
	CVS to confirm	
	Text
	*/
	
	, [Description] = p.approval_desc -- d.description
	/*
	Text field to identify a description if applicable	
	CVS to confirm	
	Text
	*/
	
	, [Pharmacy Exception] = case when exists (
		select 1 from 
		profilewastecode pwc (nolock) 
		JOIN wastecode wc (nolock) 
			on pwc.waste_code_uid = wc.waste_code_uid 
			and wc.display_name = 'PHRM'
		WHERE 
			pwc.profile_id = p.profile_id
	) then 'Yes' else 'No' end
	/*
	Determines if the waste profile should be excluded for acute hazardous waste in applicable states	
	N/A	
	Yes/No
	-- from Mara Poe 7/9/20: Pharmacy Exception – items meeting the exception will have a PHRM waste code
	*/
	
	, [Nicotine Exception] = case when exists (
		select 1 from 
		profilewastecode pwc (nolock) 
		JOIN wastecode wc (nolock) 
			on pwc.waste_code_uid = wc.waste_code_uid 
			and wc.display_name = 'P075'
		WHERE 
			pwc.profile_id = p.profile_id
	) then 'Yes' else 'No' end
	/*
	Determines if the waste profile should be excluded for acute hazardous wastes in applicable states	
	N/A	
	Yes/No
	-- from Mara Poe 7/9/20: Nicotine Exception – items that may meet the exception will have a P075 waste code on the profile
	*/


from ContactCORProfileBucket b (nolock)
INNER JOIN profile p (nolock)
	on b.profile_id = p.profile_id
INNER JOIN profilequoteapproval pqa (nolock) 
	on p.profile_id = pqa.profile_id 
	and pqa.status = 'A'
WHERE b.contact_id = @i_contact_id
and p.curr_status_code = 'A'
and p.ap_expiration_date > dateadd(yyyy, -2, @i_end_date)

UNION

select distinct
	
	'T' as profile_type,
	
	t.tsdf_approval_id as profile_id, 
	
	[Profile Number] = t.tsdf_approval_code + '~' + convert(varchar(20), t.tsdf_approval_id)
	/*
	Number to uniquely identify the record	
	CVS to confirm	
	Text
	*/
	
	, [Description] = t.waste_desc -- d.description
	/*
	Text field to identify a description if applicable	
	CVS to confirm	
	Text
	*/
	
	/*
	, [Pharmacy Exception] = case when exists (
		select 1 from 
		tsdfapprovalwastecode pwc (nolock) 
		JOIN wastecode wc (nolock) 
			on pwc.waste_code_uid = wc.waste_code_uid 
			and wc.display_name = 'PHRM'
		WHERE 
			pwc.tsdf_approval_id = t.tsdf_approval_id
	) then 'Yes' else 'No' end
	*/

	, [Pharmacy Exception] = case when exists (
		select 1 from 
		tsdfapprovalwastecode pwc (nolock) 
		JOIN wastecode wc (nolock) 
			on pwc.waste_code_uid = wc.waste_code_uid 
			and wc.waste_code_origin = 'F'
		WHERE 
			pwc.tsdf_approval_id = t.tsdf_approval_id
	) 
		AND t.waste_desc like '%pharm%'
		AND t.waste_desc not like '%otc pharm%'
		--AND t.waste_desc not like '%Empty%'
	then 'Yes' else 'No' end

	/*
	Determines if the waste profile should be excluded for acute hazardous waste in applicable states	
	N/A	
	Yes/No
	-- from Mara Poe 7/9/20: Pharmacy Exception – items meeting the exception will have a PHRM waste code
	*/
	
	, [Nicotine Exception] = case when exists (
		select 1 from 
		tsdfapprovalwastecode pwc (nolock) 
		JOIN wastecode wc (nolock) 
			on pwc.waste_code_uid = wc.waste_code_uid 
			and wc.display_name = 'P075'
		WHERE 
			pwc.tsdf_approval_id = t.tsdf_approval_id
	) then 'Yes' else 'No' end
	/*
	Determines if the waste profile should be excluded for acute hazardous wastes in applicable states	
	N/A	
	Yes/No
	-- from Mara Poe 7/9/20: Nicotine Exception – items that may meet the exception will have a P075 waste code on the profile
	*/


from ContactCORCustomerBucket b (nolock)
INNER JOIN tsdfapproval t (nolock)
	on b.customer_id = t.customer_id
	and t.tsdf_approval_status = 'A'
INNER JOIN tsdf (nolock)
	on t.tsdf_code = tsdf.tsdf_code
	and isnull(tsdf.eq_flag, 'F') = 'F'
WHERE b.contact_id = @i_contact_id
and t.tsdf_code <> 'UNDEFINED'
and t.tsdf_approval_expire_date > dateadd(yyyy, -2, @i_end_date)
and @include_tsdf_approvals = 1
) src


/* -- Found that users were including tsdfapprovals
that DO NOT BELONG to the appropriate customer
because EQAI allows it.
So in addition to the profiles/tsdfapprovals above
that DO belong to the right customer
we actually have to also include what APPEARS ON THEIR DATA
even if it's not theirs.
This means a customer name that is part of an approval name
can appear here, which is bad, but so is not reporting
the data
*/

create table #Source (
	trans_source		char(1)
	, receipt_id		int
	, company_id		int
	, profit_ctr_id		int
	, manifest			varchar(15)
	, generator_id		int
	, service_date		datetime
	, workorder_id		int
	, workorder_company_id	int
	, workorder_profit_ctr_id	int
)

truncate table #source

/*
insert #Source
Exec sp_COR_Intelex_Source
	@web_userid		= 'svc_cvs_intelex'
	, @start_date	= '11/1/2020'
	, @end_date		= '4/4/2021'


*/

insert #Source
Exec sp_COR_Intelex_Source
	@web_userid		= @i_web_userid
	, @start_date	= @i_start_date
	, @end_date		= @i_end_date



insert #output
select distinct
	
	'P' as profile_type,
	
	p.profile_id, 
	
	[Profile Number] = pqa.approval_code
	/*
	Number to uniquely identify the record	
	CVS to confirm	
	Text
	*/
	
	, [Description] = p.approval_desc -- d.description
	/*
	Text field to identify a description if applicable	
	CVS to confirm	
	Text
	*/
	
	, [Pharmacy Exception] = case when exists (
		select 1 from 
		profilewastecode pwc (nolock) 
		JOIN wastecode wc (nolock) 
			on pwc.waste_code_uid = wc.waste_code_uid 
			and wc.display_name = 'PHRM'
		WHERE 
			pwc.profile_id = p.profile_id
	) then 'Yes' else 'No' end
	/*
	Determines if the waste profile should be excluded for acute hazardous waste in applicable states	
	N/A	
	Yes/No
	-- from Mara Poe 7/9/20: Pharmacy Exception – items meeting the exception will have a PHRM waste code
	*/
	
	, [Nicotine Exception] = case when exists (
		select 1 from 
		profilewastecode pwc (nolock) 
		JOIN wastecode wc (nolock) 
			on pwc.waste_code_uid = wc.waste_code_uid 
			and wc.display_name = 'P075'
		WHERE 
			pwc.profile_id = p.profile_id
	) then 'Yes' else 'No' end
	/*
	Determines if the waste profile should be excluded for acute hazardous wastes in applicable states	
	N/A	
	Yes/No
	-- from Mara Poe 7/9/20: Nicotine Exception – items that may meet the exception will have a P075 waste code on the profile
	*/

--select b.*,p.*
from #Source b
join receipt r (nolock)
	on b.receipt_id = r.receipt_id
	and b.company_id = r.company_id
	and b.profit_ctr_id = r.profit_ctr_id
	and r.manifest not like '%manifest%'
	and r.manifest = b.manifest
	and b.trans_source = 'R'
INNER JOIN profile p (nolock)
	on r.profile_id = p.profile_id
INNER JOIN profilequoteapproval pqa (nolock) 
	on p.profile_id = pqa.profile_id 
	and r.company_id = pqa.company_id
	and r.profit_ctr_id = pqa.profit_ctr_id
	and pqa.status = 'A'
WHERE p.curr_status_code = 'A'
and p.ap_expiration_date > dateadd(yyyy, -2, @i_end_date)
and not exists (
	select 1 from #output where profile_id = r.profile_id
)

UNION

select distinct
	
	'T' as profile_type,
	
	t.tsdf_approval_id as profile_id, 
	
	[Profile Number] = t.tsdf_approval_code + '~' + convert(varchar(20), t.tsdf_approval_id)
	/*
	Number to uniquely identify the record	
	CVS to confirm	
	Text
	*/
	
	, [Description] = t.waste_desc -- d.description
	/*
	Text field to identify a description if applicable	
	CVS to confirm	
	Text
	*/
	
	/*
	, [Pharmacy Exception] = case when exists (
		select 1 from 
		tsdfapprovalwastecode pwc (nolock) 
		JOIN wastecode wc (nolock) 
			on pwc.waste_code_uid = wc.waste_code_uid 
			and wc.display_name = 'PHRM'
		WHERE 
			pwc.tsdf_approval_id = t.tsdf_approval_id
	) then 'Yes' else 'No' end
	*/

	, [Pharmacy Exception] = case when exists (
		select 1 from 
		tsdfapprovalwastecode pwc (nolock) 
		JOIN wastecode wc (nolock) 
			on pwc.waste_code_uid = wc.waste_code_uid 
			and wc.waste_code_origin = 'F'
		WHERE 
			pwc.tsdf_approval_id = t.tsdf_approval_id
	) 
		AND t.waste_desc like '%pharm%'
		AND t.waste_desc not like '%otc pharm%'
		--AND t.waste_desc not like '%Empty%'
	then 'Yes' else 'No' end

	/*
	Determines if the waste profile should be excluded for acute hazardous waste in applicable states	
	N/A	
	Yes/No
	-- from Mara Poe 7/9/20: Pharmacy Exception – items meeting the exception will have a PHRM waste code
	*/
	
	, [Nicotine Exception] = case when exists (
		select 1 from 
		tsdfapprovalwastecode pwc (nolock) 
		JOIN wastecode wc (nolock) 
			on pwc.waste_code_uid = wc.waste_code_uid 
			and wc.display_name = 'P075'
		WHERE 
			pwc.tsdf_approval_id = t.tsdf_approval_id
	) then 'Yes' else 'No' end
	/*
	Determines if the waste profile should be excluded for acute hazardous wastes in applicable states	
	N/A	
	Yes/No
	-- from Mara Poe 7/9/20: Nicotine Exception – items that may meet the exception will have a P075 waste code on the profile
	*/


from #Source b
join workorderheader h (nolock)
	on b.receipt_id = h.workorder_id
	and b.company_id = h.company_id
	and b.profit_ctr_id = h.profit_ctr_id
	and b.trans_source = 'W'
join workorderdetail d (nolock)
	on b.receipt_id = d.workorder_id
	and b.company_id = d.company_id
	and b.profit_ctr_id = d.profit_ctr_id
	and d.resource_type = 'D'
	and isnull(d.bill_rate, 0) in (-1, 1, 1.5, 2)
	and b.manifest = d.manifest
INNER JOIN tsdfapproval t (nolock)
	on d.tsdf_approval_id = t.tsdf_approval_id
	and d.company_id = t.company_id
	and d.profit_ctr_id = t.profit_ctr_id
	and t.tsdf_approval_status = 'A'
INNER JOIN tsdf (nolock)
	on t.tsdf_code = tsdf.tsdf_code
	and isnull(tsdf.eq_flag, 'F') = 'F'
WHERE t.tsdf_code <> 'UNDEFINED'
and t.tsdf_approval_expire_date > dateadd(yyyy, -2, @i_end_date)
and @include_tsdf_approvals = 1
and not exists (
	select 1 from #output where profile_id = t.tsdf_approval_id
)

-- SELECT  * FROM    #Source

/*
Allow this work to be used by other SPs. They just
have to define the #profiles table before calling this,
and afterward that table will contain this SP's 
internal #output table

create table #profiles (
	profile_type char(1)
	, profile_id int
	, profile_number varchar(40)
	, description varchar(max)
	, pharmacy_exception varchar(5)
	, nicotine_exception varchar(5)
)

*/
BEGIN TRY
	if object_id('tempdb..#profiles') is not null
	insert #Profiles
	select * from #output
END TRY
BEGIN CATCH
	-- Nothing
END CATCH

/*

Now if you defined a #profiles table before calling this, it's got this data in it.
That's pretty freakin cool.

*/

SELECT  DISTINCT
[Profile Number],
[Description],
[Pharmacy Exception],
[Nicotine Exception]
FROM    #output
ORDER BY [Profile Number], [Description]


go

grant execute on sp_COR_Intelex_Waste_Profile_list
to cor_user
go

grant execute on sp_COR_Intelex_Waste_Profile_list
to eqai
go

grant execute on sp_COR_Intelex_Waste_Profile_list
to eqweb
go

grant execute on sp_COR_Intelex_Waste_Profile_list
to CRM_Service
go

grant execute on sp_COR_Intelex_Waste_Profile_list
to DATATEAM_SVC
go


