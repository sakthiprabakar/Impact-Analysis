-- 
drop proc if exists sp_COR_Intelex_Manifest_Line_list
go
create proc sp_COR_Intelex_Manifest_Line_list
	@web_userid		varchar(100)
	, @start_date		datetime
	, @end_date		datetime
as

/*
sp_COR_Intelex_Manifest_Line_list

sp_COR_Intelex_Manifest_Line_list @web_userid = 'svc_cvs_intelex'
	, @start_date  = '1/1/2021'
	, @end_date	 = '3/8/2021'



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

Unique Identifier	
	Number to uniquely identify the record. Could use the Manifest No. and Line concatenated			

Waste Location	
	Short version of location code. Waste hauler to provide value. Intelex to import value into a text field	
	CVS to confirm	
	Text	
	N

EPA ID	
	Alpha-numeric field to capture the EPA ID of the facility	
	CVS to confirm	
	Text	
	N

Line	
	Numeric value for the line	
	N/A	
	Number	
	Y

EPA Hazardous	
	Flag to identify if the line is for EPA hazardous waste	
	N/A	Lookup	
	N

EPA Acute Hazardous	
	Flag to identify if the line is for EPA acute hazardous waste	
	N/A	
	Lookup	
	Y

State Coded	
	Flag to identify if the line is associated with a state code	
	N/A	
	Lookup	
	N

DOT Description	
	Text field to provide DOT description as related to the profile 	
	100 (CVS to confirm)	
	Text	
	N

Stream Name	
	Text field to provide Stream Name as related to the profile	
	CVS to confirm	
	Text	
	N

Waste Codes	
	Associated Federal Waste Codes from the Waste Code object. Commas to be used as delimiters between multiple waste codes being sent.	
	N/A	
	Relation	
	N

State Codes	
	Associated State Waste Codes from the Waste Code object. Commas to be used as delimiters between multiple waste codes being sent.	
	N/A	
	Relation	
	N

Quantity	
	Numeric value of quantity (may be defined as containers, etc.)	
	N/A	
	Float	
	N

Container Type	
	Text field to indicate the container type of quantity identified in above field	CVS to confirm length	Text	N

Weight (lbs)	
	Weight of line item picked up (number with decimals only)	
	N/A	
	Float	
	Y

Waste Profile	
	Associated waste profile from the Waste Profile object. Would be the profile number	
	N/A	
	Relation	
	Y

-- Receiving Facility Profile ID	
--	Text field to indicate the profile ID of the receiving facility for the waste (only Clean Earth)	
--	CVS to confirm length	
--	Text	
--  N

-- Receiving Facility Stream ID	
--	Text field to indicate the stream ID of the receiving facility for the waste (only Clean Earth)	
--	CVS to confirm length	
--	Text	
--	N

Receiving Facility IM Code	
	Text field to indicate the IM code of the receiving facility for the waste 	
	CVS to confirm length	
	Text	
	N

Receiving Facility FM Code	
	Text field to indicate the FM code of the receiving facility for the waste	
	CVS to confirm length	
	Text	
	N

Manifest	
	Associated Manifest record from the Manifest object this line item relates to	
	N/A	
	Relation	
	Y




2024-03-20 - UR0232345    5 additional fields added per cust request

Transporter 1
Transporter 1 EPA ID
Transporter 2
Transporter 2 EPA ID
Source Code

-- Those are not manifest-line specific fields but they asked for them in this file anyway.

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

select top 1 @i_contact_id = contact_id from Contact WHERE web_userid = @i_web_userid

Drop Table If Exists #Source

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

insert #Source
Exec sp_COR_Intelex_Source
	@web_userid		= @i_web_userid
	, @start_date	= @i_start_date
	, @end_date		= @i_end_date

-- SELECT  * FROM    #Source

select * from (
select distinct
	[Unique Identifier] = 
		case when b.trans_source = 'R' and b.workorder_id is not null then
			right('00' + convert(varchar(2), b.workorder_company_id), 2) 
			+ '-'
			+ right('00' + convert(varchar(2), b.workorder_profit_ctr_id), 2) 
			+ '-W-'
			+ convert(varchar(20), b.workorder_id)
		else
			right('00' + convert(varchar(2), b.company_id), 2) 
			+ '-'
			+ right('00' + convert(varchar(2), b.profit_ctr_id), 2) 
			+ '-'
			+ b.trans_source
			+ '-'
			+ convert(varchar(20), b.receipt_id)
		end
		+ '-'
		+ b.manifest
		+ '-'
		+ convert(varchar(4), isnull(r.manifest_line, 1))
	/*
	Number to uniquely identify the record. Could use the Manifest No. and Line concatenated			
	*/

	, [Waste Location] = convert(varchar(20), g.generator_id)
	/*
	Short version of location code. Waste hauler to provide value. Intelex to import value into a text field	
	CVS to confirm	
	Text	
	N
	*/

	, [EPA ID] = g.epa_id
	/*
	Alpha-numeric field to capture the EPA ID of the facility	
	CVS to confirm	
	Text	
	N
	*/

	, [Line] = r.manifest_line
	/*
	Numeric value for the line	
	N/A	
	Number	
	Y
	*/

	, [EPA Hazardous] = case when w.hazardous > 0 then 'Yes' else 'No' end
	/*
	Flag to identify if the line is for EPA hazardous waste	
	N/A	Lookup	
	N
	*/

	, [EPA Acute Hazardous] = case when w.acute > 0 then 'Yes' else 'No' end
	/*
	Flag to identify if the line is for EPA acute hazardous waste	
	N/A	
	Lookup	
	Y
	*/
	
	, [State Coded] = case when w.state_coded > 0 then 'Yes' else 'No' end
	/*
	Flag to identify if the line is associated with a state code	
	N/A	
	Lookup	
	N
	*/

	, [DOT Description] = dbo.fn_manifest_dot_description('P', r.profile_id) 
		--case when d.tsdf_approval_id is not null then 
		--	dbo.fn_manifest_dot_description('T', d.tsdf_approval_id) 
		--else 
		--	dbo.fn_manifest_dot_description('P', d.profile_id) 
		--end
	/*
	Text field to provide DOT description as related to the profile 	
	100 (CVS to confirm)	
	Text	
	N
	*/
	
	, [Stream Name] = p.approval_desc
		-- coalesce(ta.waste_desc, p.approval_desc) -- d.description
	/*
	Text field to provide Stream Name as related to the profile	
	CVS to confirm	
	Text	
	N
	*/
	
	, [Waste Codes] = ltrim(rtrim((
		select substring((
		SELECT ', ' + CASE WHEN wc.waste_code_origin = 'S' then wc.state + '-' else '' end + ltrim(rtrim(wc.display_name))
		FROM ReceiptWasteCode xwc 
		INNER JOIN wastecode wc on xwc.waste_code_uid = wc.waste_code_uid
		and ltrim(rtrim(wc.display_name)) <> 'NONE'
		WHERE xwc.receipt_id = r.receipt_id
		and xwc.line_id = r.line_id
		and xwc.company_id = r.company_id
		and xwc.profit_ctr_id = r.profit_ctr_id
		-- AND xwc.primary_flag = 'T'
		AND wc.waste_code_origin <> 'S'
		ORDER BY isnull(xwc.primary_flag, 'F') desc, ltrim(rtrim(wc.display_name))
		for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
		)))  
	-- dbo.fn_receipt_waste_code_list(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id)
		
	/*
	Associated Federal Waste Codes from the Waste Code object. Commas to be used as delimiters between multiple waste codes being sent.	
	N/A	
	Relation	
	N
	*/
	
	, [State Codes] = ltrim(rtrim((
		select substring((
		SELECT ', ' + CASE WHEN wc.waste_code_origin = 'S' then wc.state + '-' else '' end + ltrim(rtrim(wc.display_name))
		FROM ReceiptWasteCode xwc 
		INNER JOIN wastecode wc on xwc.waste_code_uid = wc.waste_code_uid
		and ltrim(rtrim(wc.display_name)) <> 'NONE'
		WHERE xwc.receipt_id = r.receipt_id
		and xwc.line_id = r.line_id
		and xwc.company_id = r.company_id
		and xwc.profit_ctr_id = r.profit_ctr_id
		-- AND xwc.primary_flag = 'T'
		AND wc.waste_code_origin = 'S'
		ORDER BY isnull(xwc.primary_flag, 'F') desc, ltrim(rtrim(wc.display_name))
		for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
		)))  
	-- dbo.fn_receipt_waste_code_list_state(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id)

	/*
	Associated State Waste Codes from the Waste Code object. Commas to be used as delimiters between multiple waste codes being sent.	
	N/A	
	Relation	
	N
	*/
	, [Quantity] = r.manifest_quantity
		-- coalesce(wm.quantity, wnm.quantity, d.quantity)
	/*
	Numeric value of quantity (may be defined as containers, etc.)	
	N/A	
	Float	
	N
	*/
	, [Container Type] = r.manifest_container_code 
		-- wmb.manifest_unit
	/*
	Text field to indicate the container type of quantity identified in above field	
	CVS to confirm length	
	Text	
	N
	*/

	, [Weight (lbs)] = w.weight
	/*
	Weight of line item picked up (number with decimals only)	
	N/A	
	Float	
	Y
	*/

	, [Waste Profile] = pqa.approval_code 
		--case when d.tsdf_approval_id is not null then 
		--	d.tsdf_approval_code 
		--else 
		--	pqa.approval_code 
		--end
	/*
	Associated waste profile from the Waste Profile object. Would be the profile number	
	N/A	
	Relation	
	Y
	*/

-- Receiving Facility Profile ID	
--	Text field to indicate the profile ID of the receiving facility for the waste (only Clean Earth)	
--	CVS to confirm length	
--	Text	
--  N

-- Receiving Facility Stream ID	
--	Text field to indicate the stream ID of the receiving facility for the waste (only Clean Earth)	
--	CVS to confirm length	
--	Text	
--	N

	, [Receiving Facility MM Code] = tr.management_code
		-- coalesce(ta.management_code, tr.management_code) --, p.management_code)
	/*
	Text field to indicate the IM code of the receiving facility for the waste 	
	CVS to confirm length	
	Text	
	N
	*/
	
	, [Waste Stream Form Code] = p.epa_form_code
		--coalesce(ta.epa_form_code, p.epa_form_code)
	/*
	Text field to indicate the FM code of the receiving facility for the waste	
	CVS to confirm length	
	Text	
	N
	*/

	, [Manifest] = b.manifest
	/*
	Associated Manifest record from the Manifest object this line item relates to	
	N/A	
	Relation	
	Y
	*/

/*
2024-03-20 - 5 additional fields added per cust request
Transporter 1
Transporter 1 EPA ID
Transporter 2
Transporter 2 EPA ID
Source Code
*/

	, [Transporter 1] = rt1t.transporter_name
	, [Transporter 1 EPA ID] = rt1t.transporter_EPA_ID
	, [Transporter 2] = rt2t.transporter_name
	, [Transporter 2 EPA ID] = rt2t.transporter_EPA_ID

	, [Source Code] = p.EPA_source_code

-- select b.*
from #Source b
join receipt r (nolock)
	on b.receipt_id = r.receipt_id
	and b.company_id = r.company_id
	and b.profit_ctr_id = r.profit_ctr_id
	and r.manifest not like '%manifest%'
	and r.manifest = b.manifest
	and b.trans_source = 'R'
join generator g (nolock)
	on b.generator_id = g.generator_id
join profile p (nolock)
	on r.profile_id = p.profile_id
join profilequoteapproval pqa (nolock)
	on r.profile_id = pqa.profile_id
	and r.company_id = pqa.company_id
	and r.profit_ctr_id = pqa.profit_ctr_id
JOIN treatment tr 
	on pqa.treatment_id = tr.treatment_id 
	and r.company_id = tr.company_id 
	and r.profit_ctr_id = tr.profit_ctr_id
join tsdf tsdf (nolock)
	on r.company_id = tsdf.eq_company
	and r.profit_ctr_id = tsdf.eq_profit_ctr
	and tsdf.eq_flag = 'T'
	and tsdf.tsdf_status = 'A'
LEFT JOIN (
	select r.receipt_id, r.company_id, r.profit_ctr_id, r.line_id
	, sum( dbo.fn_receipt_weight_line(r.receipt_id, r.line_id, r.profit_ctr_id, r.company_id)) as weight
	, case when exists (
		select 1 from receiptwastecode wwc (nolock)
		join wastecode wc (nolock)
			on wwc.waste_code_uid = wc.waste_code_uid
		where
		wwc.receipt_id = r.receipt_id
		and wwc.line_id = r.line_id
		and wwc.company_id = r.company_id
		and wwc.profit_ctr_id = r.profit_ctr_id
		and wc.waste_code_origin = 'F' and wc.haz_flag = 'T'
	) then 1 else 0 end as hazardous
	, case when exists (
		select 1 from receiptwastecode wwc (nolock)
		join wastecode wc (nolock)
			on wwc.waste_code_uid = wc.waste_code_uid
		where
		wwc.receipt_id = r.receipt_id
		and wwc.line_id = r.line_id
		and wwc.company_id = r.company_id
		and wwc.profit_ctr_id = r.profit_ctr_id
		and wc.waste_code_origin = 'F' and wc.haz_flag = 'T'
		and (left(ltrim(rtrim(wc.display_name)), 1) = 'P' or ltrim(rtrim(wc.display_name)) between 'F020' and 'F023' or ltrim(rtrim(wc.display_name)) between 'F026' and 'F028') 
	) then 1 else 0 end as acute
	, case when exists (
		select 1 from receiptwastecode wwc (nolock)
		join wastecode wc (nolock)
			on wwc.waste_code_uid = wc.waste_code_uid
		where
		wwc.receipt_id = r.receipt_id
		and wwc.line_id = r.line_id
		and wwc.company_id = r.company_id
		and wwc.profit_ctr_id = r.profit_ctr_id
		and wc.waste_code_origin = 'S' -- and wc.haz_flag = 'T'
		and wc.state in (g.generator_state, tsdf.tsdf_state)
	) then 1 else 0 end as state_coded
	from #Source b 
	join receipt r (nolock)
		on b.receipt_id = r.receipt_id
		and b.company_id = r.company_id
		and b.profit_ctr_id = r.profit_ctr_id
		and r.manifest not like '%manifest%'
		and b.trans_source = 'R'
	join generator g (nolock)
		on b.generator_id = g.generator_id
	join tsdf tsdf (nolock)
		on r.company_id = tsdf.eq_company
		and r.profit_ctr_id = tsdf.eq_profit_ctr
		and tsdf.eq_flag = 'T'
		and tsdf.tsdf_status = 'A'
	WHERE r.receipt_id is not null and r.company_id is not null and r.profit_ctr_id is not null
	and r.receipt_status not in ('V', 'R')
	and r.trans_mode = 'I'
	and r.trans_type = 'D'
	and r.fingerpr_status = 'A'
	GROUP BY r.receipt_id, r.company_id, r.profit_ctr_id, r.line_id, tsdf.tsdf_state, g.generator_state
) w
	on r.receipt_id = w.receipt_id
	and r.company_id = w.company_id
	and r.profit_ctr_id = w.profit_ctr_id
	and r.line_id = w.line_id
LEFT JOIN ReceiptTransporter rt1
	on r.receipt_id = rt1.receipt_id
	and r.company_id = rt1.company_id
	and r.profit_ctr_id = rt1.profit_ctr_id
	and rt1.transporter_sequence_id = 1
LEFT JOIN Transporter rt1t
	on rt1.transporter_code = rt1t.transporter_code
LEFT JOIN ReceiptTransporter rt2
	on r.receipt_id = rt2.receipt_id
	and r.company_id = rt2.company_id
	and r.profit_ctr_id = rt2.profit_ctr_id
	and rt2.transporter_sequence_id = 2
LEFT JOIN Transporter rt2t
	on rt2.transporter_code = rt2t.transporter_code

WHERE r.receipt_status not in ('V', 'R')
	and r.trans_mode = 'I'
	and r.trans_type = 'D'
	and r.fingerpr_status = 'A'

union


select distinct
	[Unique Identifier] = 
		case when b.trans_source = 'R' and b.workorder_id is not null then
			right('00' + convert(varchar(2), b.workorder_company_id), 2) 
			+ '-'
			+ right('00' + convert(varchar(2), b.workorder_profit_ctr_id), 2) 
			+ '-W-'
			+ convert(varchar(20), b.workorder_id)
		else
			right('00' + convert(varchar(2), b.company_id), 2) 
			+ '-'
			+ right('00' + convert(varchar(2), b.profit_ctr_id), 2) 
			+ '-'
			+ b.trans_source
			+ '-'
			+ convert(varchar(20), b.receipt_id)
		end
		+ '-'
		+ b.manifest
		+ '-'
		+ convert(varchar(4), isnull(d.manifest_line, 1))
	/*
	Number to uniquely identify the record. Could use the Manifest No. and Line concatenated			
	*/

	, [Waste Location] = convert(varchar(20), g.generator_id)
	/*
	Short version of location code. Waste hauler to provide value. Intelex to import value into a text field	
	CVS to confirm	
	Text	
	N
	*/

	, [EPA ID] = g.epa_id
	/*
	Alpha-numeric field to capture the EPA ID of the facility	
	CVS to confirm	
	Text	
	N
	*/

	, [Line] = d.manifest_line
	/*
	Numeric value for the line	
	N/A	
	Number	
	Y
	*/

	, [EPA Hazardous] = case when w.hazardous > 0 then 'Yes' else 'No' end
	/*
	Flag to identify if the line is for EPA hazardous waste	
	N/A	Lookup	
	N
	*/

	, [EPA Acute Hazardous] = case when w.acute > 0 then 'Yes' else 'No' end
	/*
	Flag to identify if the line is for EPA acute hazardous waste	
	N/A	
	Lookup	
	Y
	*/
	
	, [State Coded] = case when w.state_coded > 0 then 'Yes' else 'No' end
	/*
	Flag to identify if the line is associated with a state code	
	N/A	
	Lookup	
	N
	*/

	, [DOT Description] = 
		case when d.tsdf_approval_id is not null then 
			dbo.fn_manifest_dot_description('T', d.tsdf_approval_id) 
		else 
			dbo.fn_manifest_dot_description('P', d.profile_id) 
		end
	/*
	Text field to provide DOT description as related to the profile 	
	100 (CVS to confirm)	
	Text	
	N
	*/
	
	, [Stream Name] = coalesce(ta.waste_desc, p.approval_desc) -- d.description
	/*
	Text field to provide Stream Name as related to the profile	
	CVS to confirm	
	Text	
	N
	*/
	
	, [Waste Codes] = (
		select ltrim(rtrim(substring(
		(
			SELECT ', ' + CASE WHEN wc.waste_code_origin = 'S' then wc.state + '-' else '' end + ltrim(rtrim(wc.display_name))
			FROM WorkOrderWasteCode wwc (nolock)
			JOIN WorkOrderDetail wd (nolock)
				ON wwc.workorder_id = wd.workorder_id
				AND wwc.company_id = wd.company_id
				AND wwc.profit_ctr_id = wd.profit_ctr_id
				AND wwc.workorder_sequence_id = wd.sequence_id
				and wd.resource_type = 'D'
			JOIN TSDF t (nolock)
				ON wd.tsdf_code = t.tsdf_code
			JOIN WorkOrderHeader wh (nolock)
				ON wd.workorder_id = wh.workorder_id
				AND wd.company_id = wh.company_id
				AND wd.profit_ctr_id = wh.profit_ctr_id
			JOIN Generator g (nolock)
				ON wh.generator_id = g.generator_id
			JOIN WasteCode wc (nolock)
				ON wwc.waste_code_uid = wc.waste_code_uid
				AND ltrim(rtrim(wc.display_name)) <> 'NONE'
			WHERE wwc.workorder_id = b.receipt_id
			AND wwc.company_id = b.company_id
			AND wwc.profit_ctr_id = b.profit_ctr_id
			AND wwc.workorder_sequence_id = d.sequence_id
			AND isnull(wwc.sequence_id,0) > 0
			AND wc.waste_code_origin = 'F'
			ORDER BY wwc.sequence_id
			for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
		))	
	)
	--dbo.fn_workorder_waste_code_list_origin_filtered (b.receipt_id, b.company_id, b.profit_ctr_id, d.sequence_id, 'F')
		
	/*
	Associated Federal Waste Codes from the Waste Code object. Commas to be used as delimiters between multiple waste codes being sent.	
	N/A	
	Relation	
	N
	*/
	
	, [State Codes] = (
		select ltrim(rtrim(substring(
		(
			SELECT ', ' + CASE WHEN wc.waste_code_origin = 'S' then wc.state + '-' else '' end + ltrim(rtrim(wc.display_name))
			FROM WorkOrderWasteCode wwc (nolock)
			JOIN WorkOrderDetail wd (nolock)
				ON wwc.workorder_id = wd.workorder_id
				AND wwc.company_id = wd.company_id
				AND wwc.profit_ctr_id = wd.profit_ctr_id
				AND wwc.workorder_sequence_id = wd.sequence_id
				and wd.resource_type = 'D'
			JOIN TSDF t (nolock)
				ON wd.tsdf_code = t.tsdf_code
			JOIN WorkOrderHeader wh (nolock)
				ON wd.workorder_id = wh.workorder_id
				AND wd.company_id = wh.company_id
				AND wd.profit_ctr_id = wh.profit_ctr_id
			JOIN Generator g (nolock)
				ON wh.generator_id = g.generator_id
			JOIN WasteCode wc (nolock)
				ON wwc.waste_code_uid = wc.waste_code_uid
				AND ltrim(rtrim(wc.display_name)) <> 'NONE'
			WHERE wwc.workorder_id = b.receipt_id
			AND wwc.company_id = b.company_id
			AND wwc.profit_ctr_id = b.profit_ctr_id
			AND wwc.workorder_sequence_id = d.sequence_id
			AND isnull(wwc.sequence_id,0) > 0
			AND wc.state in (g.generator_state, t.TSDF_state)
			AND wc.waste_code_origin = 'S'
			ORDER BY wwc.sequence_id
			for xml path, TYPE).value('.[1]','nvarchar(max)'),2,20000)
		))	
	)
		--dbo.fn_workorder_waste_code_list_origin_filtered (b.workorder_id, b.company_id, b.profit_ctr_id, d.sequence_id, 'S')
	/*
	Associated State Waste Codes from the Waste Code object. Commas to be used as delimiters between multiple waste codes being sent.	
	N/A	
	Relation	
	N
	*/
	, [Quantity] = d.container_count
	/*
	Numeric value of quantity (may be defined as containers, etc.)	
	N/A	
	Float	
	N
	*/
	, [Container Type] = d.container_code
	/*
	Text field to indicate the container type of quantity identified in above field	
	CVS to confirm length	
	Text	
	N
	*/

	-- , [Weight (lbs)] = ww.quantity
	, [Weight (lbs)] = dbo.fn_workorder_weight_line(d.workorder_id, d.sequence_id, d.profit_ctr_id, d.company_id)
	/*
	Weight of line item picked up (number with decimals only)	
	N/A	
	Float	
	Y
	*/

	, [Waste Profile] = 
		case when d.tsdf_approval_id is not null then 
			d.tsdf_approval_code + '~' + convert(varchar(20), d.tsdf_approval_id)
		else 
			pqa.approval_code 
		end
	/*
	Associated waste profile from the Waste Profile object. Would be the profile number	
	N/A	
	Relation	
	Y
	*/

-- Receiving Facility Profile ID	
--	Text field to indicate the profile ID of the receiving facility for the waste (only Clean Earth)	
--	CVS to confirm length	
--	Text	
--  N

-- Receiving Facility Stream ID	
--	Text field to indicate the stream ID of the receiving facility for the waste (only Clean Earth)	
--	CVS to confirm length	
--	Text	
--	N

	, [Receiving Facility MM Code] = coalesce(ta.management_code, tr.management_code) --, p.management_code)
	/*
	Text field to indicate the IM code of the receiving facility for the waste 	
	CVS to confirm length	
	Text	
	N
	*/
	
	, [Waste Stream Form Code] = coalesce(ta.epa_form_code, p.epa_form_code)
	/*
	Text field to indicate the FM code of the receiving facility for the waste	
	CVS to confirm length	
	Text	
	N
	*/

	, [Manifest] = b.manifest
	/*
	Associated Manifest record from the Manifest object this line item relates to	
	N/A	
	Relation	
	Y
	*/

/*
2024-03-20 - 5 additional fields added per cust request
Transporter 1
Transporter 1 EPA ID
Transporter 2
Transporter 2 EPA ID
Source Code
*/

	, [Transporter 1] = rt1t.transporter_name
	, [Transporter 1 EPA ID] = rt1t.transporter_EPA_ID
	, [Transporter 2] = rt2t.transporter_name
	, [Transporter 2 EPA ID] = rt2t.transporter_EPA_ID

	, [Source Code] = coalesce(p.epa_source_code, ta.EPA_source_code)

-- select b.*
from #Source b
join workorderheader h (nolock)
	on b.receipt_id = h.workorder_id
	and b.company_id = h.company_id
	and b.profit_ctr_id = h.profit_ctr_id
	and b.trans_source = 'W'
join generator g (nolock)
	on b.generator_id = g.generator_id
join workorderdetail d (nolock)
	on b.receipt_id = d.workorder_id
	and b.company_id = d.company_id
	and b.profit_ctr_id = d.profit_ctr_id
	and d.resource_type = 'D'
	and isnull(d.bill_rate, 0) in (-1, 1, 1.5, 2)
	and b.manifest = d.manifest
join tsdf t (nolock) 
	on d.tsdf_code = t.tsdf_code
LEFT JOIN (
	select d.workorder_id, d.company_id, d.profit_ctr_id, d.sequence_id
	, sum(case when wc.waste_code_origin = 'F' and wc.haz_flag = 'T' then 1 else 0 end) as hazardous
	, sum(case when wc.waste_code_origin = 'F' and wc.haz_flag = 'T' and (left(ltrim(rtrim(wc.display_name)), 1) = 'P' or ltrim(rtrim(wc.display_name)) between 'F020' and 'F023' or ltrim(rtrim(wc.display_name)) between 'F026' and 'F028') then 1 else 0 end) as acute
	, sum(case when wc.waste_code_origin = 'S' and wc.state in (g.generator_state, t.tsdf_state) then 1 else 0 end) as state_coded
	from ContactCORWorkorderHeaderBucket b (nolock)
	join workorderheader h (nolock)
		on b.workorder_id = h.workorder_id
		and b.company_id = h.company_id
		and b.profit_ctr_id = h.profit_ctr_id
	join workorderdetail d (nolock)
		on b.workorder_id = d.workorder_id
		and b.company_id = d.company_id
		and b.profit_ctr_id = d.profit_ctr_id
		and d.resource_type = 'D'
		and isnull(d.bill_rate, 0) in (-1, 1, 1.5, 2)
	join workorderwastecode wwc (nolock)
		on b.workorder_id = wwc.workorder_id
		and b.company_id = wwc.company_id
		and b.profit_ctr_id = wwc.profit_ctr_id
		and d.sequence_id = wwc.workorder_sequence_id	
	join wastecode wc (nolock)
		on wc.waste_code_uid = wwc.waste_code_uid
		AND ltrim(rtrim(wc.display_name)) <> 'NONE'
	join generator g (nolock)
		on b.generator_id = g.generator_id
	join tsdf t (nolock) 
		on d.tsdf_code = t.tsdf_code
	WHERE h.workorder_id is not null and h.company_id is not null and h.profit_ctr_id is not null
	and h.workorder_status NOT IN ('V','X','T')
	GROUP BY d.workorder_id, d.company_id, d.profit_ctr_id, d.sequence_id
) w
	on b.receipt_id = w.workorder_id
	and b.company_id = w.company_id
	and b.profit_ctr_id = w.profit_ctr_id
	and d.sequence_id = w.sequence_id

left join tsdfapproval ta (nolock) on d.tsdf_approval_id = ta.tsdf_approval_id and d.company_id = ta.company_id and d.profit_ctr_id = ta.profit_ctr_id
left join profile p (nolock) on d.profile_id = p.profile_id
LEFT JOIN profilequoteapproval pqa (nolock) on p.profile_id = pqa.profile_id and d.profile_company_id = pqa.company_id and d.profile_profit_ctr_id = pqa.profit_ctr_id
LEFT JOIN treatment tr on pqa.treatment_id = tr.treatment_id and d.profile_company_id = tr.company_id and d.profile_profit_ctr_id = tr.profit_ctr_id
LEFT JOIN WorkorderTransporter rt1
	on b.receipt_id = rt1.workorder_id
	and b.company_id = rt1.company_id
	and b.profit_ctr_id = rt1.profit_ctr_id
	and rt1.manifest = d.manifest
	and rt1.transporter_sequence_id = 1
LEFT JOIN Transporter rt1t
	on rt1.transporter_code = rt1t.transporter_code
LEFT JOIN WorkorderTransporter rt2
	on b.receipt_id = rt2.workorder_id
	and b.company_id = rt2.company_id
	and b.profit_ctr_id = rt2.profit_ctr_id
	and rt2.manifest = d.manifest
	and rt2.transporter_sequence_id = 2
LEFT JOIN Transporter rt2t
	on rt2.transporter_code = rt2t.transporter_code

WHERE h.workorder_id is not null and h.company_id is not null and h.profit_ctr_id is not null
and h.workorder_status NOT IN ('V','X','T')
) a
order by left([Unique Identifier], len([unique identifier]) - charindex('-', reverse([unique identifier])))
,  convert(int, [Line] )
go

grant execute on sp_COR_Intelex_Manifest_Line_list
to cor_user
go

grant execute on sp_COR_Intelex_Manifest_Line_list
to eqai
go

grant execute on sp_COR_Intelex_Manifest_Line_list
to eqweb
go

grant execute on sp_COR_Intelex_Manifest_Line_list
to CRM_Service
go

grant execute on sp_COR_Intelex_Manifest_Line_list
to DATATEAM_SVC
go

