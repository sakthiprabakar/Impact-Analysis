
-- drop proc if exists sp_COR_Costco_Intelex_Manifest_Line_list
go
create proc sp_COR_Costco_Intelex_Manifest_Line_list
	@web_userid		varchar(100)
	, @start_date		datetime
	, @end_date		datetime
as

/*
sp_COR_Costco_Intelex_Manifest_Line_list


exec sp_COR_Costco_Intelex_Waste_Service_Event_list @web_userid = 'use@costco.com'
	, @start_date  = '10/1/2020' -- '2/1/2020'
	, @end_date	 = '10/1/2020' -- '2/8/2020'

exec sp_COR_Costco_Intelex_Manifest_list @web_userid = 'use@costco.com'
	, @start_date  = '10/1/2020' -- '2/1/2020'
	, @end_date	 = '10/1/2020' -- '2/8/2020'

exec sp_COR_Costco_Intelex_Manifest_Line_list @web_userid = 'use@costco.com'
	, @start_date  = '10/1/2020' -- '2/1/2020'
	, @end_date	 = '10/1/2020' -- '2/8/2020'

A good user to test with: contact_id 213383  ( use@costco.com )

SELECT  * FROM    customer where cust_name like '%costco%'
SELECT  * FROM    contactcorcustomerbucket WHERE customer_id = 601113
SELECT  * FROM    contact WHERE contact_id in (175531, 208264, 213383, 214666, 215010, 215237)
SELECT  * FROM    contactcorreceiptbucket WHERE contact_id = 213383
SELECT  * FROM    contactcorworkorderheaderbucket WHERE contact_id = 213383


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


	insert plt_export..work_Intelex_Costco_Log (log_message)
	values ('(' + convert(varchar(10), @@spid) + ') exec sp_COR_Costco_Intelex_Manifest_Line_list ''' + @i_web_userid + ''', ''' + convert(varchar(40), @start_date, 121) + ''', ''' + convert(varchar(40), @end_date, 121) + '''')


create table #intelex_source (
	trans_source		char(1)
	, receipt_id		int
	, company_id		int
	, profit_ctr_id		int
	, manifest			varchar(15)
	, manifest_flag		char(1)
	, generator_id		int
	, service_date		datetime
	, workorder_id		int
	, workorder_company_id	int
	, workorder_profit_ctr_id	int
	, site_code			varchar(20)
	, generator_sublocation_id int
	, site_type			varchar(100)	
)

truncate table #intelex_source

exec sp_COR_Costco_Intelex_Waste_Service_Event_list @web_userid = @i_web_userid
	, @start_date  = @i_start_date
	, @end_date	 = @i_end_date

truncate table plt_export.dbo.work_Intelex_Costco_Waste_Manifest_Line_list

insert plt_export.dbo.work_Intelex_Costco_Waste_Manifest_Line_list
(
	[Unique Manifest Identifier]		,
	[Unique Manifest Line Identifier]	,
	[Line]								,
	[EPA Hazardous]						,
	[State Coded]						,
	[DOT Description]					,
	[Stream Name]						,
	[Waste Codes]						,
	[State Codes]						,
	[Container No]						,
	[Container Type]					,
	[Total Quantity]					,
	[Manifest Unit]						,
	[Weight (lbs)]						,
	[Waste Profile]						,
	[Receiving Facility MM Code]		,
	[Waste Stream Form Code]			,
	[Waste Stream Source Code]			,
	[Waste Stream Disposal Method]		,
	[Manifest]							
)
select distinct
	[Unique Manifest Identifier] = 
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
		--+ isnull('-'
		--+ convert(varchar(10), b.generator_sublocation_id)
		--, '')
		+ '-'
		+ b.manifest	

	, [Unique Manifest Line Identifier] = 
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
		--+ isnull('-'
		--+ convert(varchar(10), b.generator_sublocation_id)
		--, '')
		+ '-'
		+ b.manifest
		+ '-'
		+ convert(varchar(4), coalesce(r.manifest_line, r.line_id, 1))

	-- , [Waste Location] = convert(varchar(20), g.generator_id)

	-- , [EPA ID] = g.epa_id

	, [Line] = coalesce(r.manifest_line, r.line_id, 1)

	, [EPA Hazardous] = case when w.hazardous > 0 then 'Yes' else 'No' end

--	, [EPA Acute Hazardous] = case when w.acute > 0 then 'Yes' else 'No' end
	
	, [State Coded] = case when w.state_coded > 0 then 'Yes' else 'No' end

	, [DOT Description] = dbo.fn_manifest_dot_description('P', r.profile_id) 
		--case when d.tsdf_approval_id is not null then 
		--	dbo.fn_manifest_dot_description('T', d.tsdf_approval_id) 
		--else 
		--	dbo.fn_manifest_dot_description('P', d.profile_id) 
		--end
	
	, [Stream Name] = p.approval_desc
		-- coalesce(ta.waste_desc, p.approval_desc) -- d.description
	
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

	, [Container No] = r.container_count
		-- coalesce(wm.quantity, wnm.quantity, d.quantity)
	, [Container Type] = r.manifest_container_code 
	, [Total Quantity] = r.manifest_quantity
	, [Manifest Unit] = r.manifest_unit
		-- wmb.manifest_unit

	, [Weight (lbs)] = w.weight

	, [Waste Profile] = pqa.approval_code 
		--case when d.tsdf_approval_id is not null then 
		--	d.tsdf_approval_code 
		--else 
		--	pqa.approval_code 
		--end


	, [Receiving Facility MM Code] = tr.management_code
		-- coalesce(ta.management_code, tr.management_code) --, p.management_code)
	
	, [Waste Stream Form Code] = p.epa_form_code
		--coalesce(ta.epa_form_code, p.epa_form_code)
	, [Waste Stream Source Code] = p.epa_source_code
	, [Waste Stream Disposal Method] = tr.disposal_service_desc
	

	, [Manifest] = b.manifest

-- select b.*
from #intelex_source b
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
JOIN treatment tr (nolock)
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
	from #intelex_source b 
	join receipt r (nolock)
		on b.receipt_id = r.receipt_id
		and b.company_id = r.company_id
		and b.profit_ctr_id = r.profit_ctr_id
		and r.manifest not like '%manifest%'
		and b.trans_source = 'R'
	join generator g (nolock)
		on b.generator_id = g.generator_id
	join profile p (nolock)
		on r.profile_id = p.profile_id
	join profilequoteapproval pqa (nolock)
		on r.profile_id = pqa.profile_id
		and r.company_id = pqa.company_id
		and r.profit_ctr_id = pqa.profit_ctr_id
	JOIN treatment tr (nolock)
		on pqa.treatment_id = tr.treatment_id 
		and r.company_id = tr.company_id 
		and r.profit_ctr_id = tr.profit_ctr_id
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
WHERE r.receipt_status not in ('V', 'R')
	and r.trans_mode = 'I'
	and r.trans_type = 'D'
	and r.fingerpr_status = 'A'

union


select distinct
	[Unique Manifest Identifier] = 
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
		--+ isnull('-'
		--+ convert(varchar(10), b.generator_sublocation_id)
		--, '')
		+ '-'
		+ b.manifest	

	, [Unique Manifest Line Identifier] = 
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
		--+ isnull('-'
		--+ convert(varchar(10), b.generator_sublocation_id)
		--, '')
		+ '-'
		+ b.manifest
		+ '-'
		+ convert(varchar(4), coalesce(d.manifest_line, d.sequence_id, 1))

	--, [Waste Location] = convert(varchar(20), g.generator_id)

	-- , [EPA ID] = g.epa_id

	, [Line] = coalesce(d.manifest_line, d.sequence_id, 1)

	, [EPA Hazardous] = case when w.hazardous > 0 then 'Yes' else 'No' end

	-- , [EPA Acute Hazardous] = case when w.acute > 0 then 'Yes' else 'No' end
	
	, [State Coded] = case when w.state_coded > 0 then 'Yes' else 'No' end

	, [DOT Description] = 
		case when d.tsdf_approval_id is not null then 
			dbo.fn_manifest_dot_description('T', d.tsdf_approval_id) 
		else 
			dbo.fn_manifest_dot_description('P', d.profile_id) 
		end
	
	, [Stream Name] = coalesce(ta.waste_desc, p.approval_desc) -- d.description
	
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

	, [Container No] = d.container_count
	, [Container Type] = d.container_code 
	, [Total Quantity] = coalesce(wm.quantity, wnm.quantity)
	, [Manifest Unit] = coalesce(wmbu.manifest_unit, wnmbu.manifest_unit)

	, [Weight (lbs)] = ww.quantity

	, [Waste Profile] = 
		case when d.tsdf_approval_id is not null then 
			d.tsdf_approval_code + '~' + convert(varchar(20), d.tsdf_approval_id)
		else 
			pqa.approval_code 
		end

	, [Receiving Facility MM Code] = coalesce(ta.management_code, tr.management_code) --, p.management_code)
	
	, [Waste Stream Form Code] = coalesce(ta.epa_form_code, p.epa_form_code)
	, [Waste Stream Source Code] = coalesce(ta.epa_source_code, p.epa_source_code)
	, [Waste Stream Disposal Method] = coalesce(tad.disposal_service_desc, ta.disposal_service_other_desc, tr.disposal_service_desc)


	, [Manifest] = b.manifest
-- select b.*
from #intelex_source b
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
join workordermanifest m (nolock)
	on b.receipt_id = m.workorder_id
	and b.company_id = m.company_id
	and b.profit_ctr_id = m.profit_ctr_id
	and d.manifest = m.manifest
	and m.manifest_flag = 'T'
--	and m.manifest_state = 'H'
	and m.manifest not like '%manifest%'
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
JOIN workorderdetailunit wm (nolock)
	on b.receipt_id = wm.workorder_id
	and b.company_id = wm.company_id
	and b.profit_ctr_id = wm.profit_ctr_id
	and d.sequence_id = wm.sequence_id
	and wm.manifest_flag = 'T'
left join workorderdetailunit wnm (nolock) 
	on b.receipt_id = wnm.workorder_id 
	and b.company_id = wnm.company_id 
	and b.profit_ctr_id = wnm.profit_ctr_id 
	and wnm.sequence_id = d.sequence_id
	and isnull(wm.manifest_flag, 'X') = 'X'
	-- The wodu_not_manifestd version is identical to wodu except doens't require the manifested flag, because
	-- apparently sometimes they don't check it.  But we should prefer the data they did check it, if they did.
	-- Sigh.
LEFT JOIN billunit wmbu (nolock)
	on wm.bill_unit_code = wmbu.bill_unit_code
LEFT JOIN billunit wnmbu (nolock)
	on wnm.bill_unit_code = wnmbu.bill_unit_code
		
left join workorderdetailunit ww (nolock) 
	on b.receipt_id = ww.workorder_id 
	and b.company_id = ww.company_id 
	and b.profit_ctr_id = ww.profit_ctr_id 
	and ww.sequence_id = d.sequence_id
	and ww.bill_unit_code = 'LBS'
left join tsdfapproval ta (nolock) on d.tsdf_approval_id = ta.tsdf_approval_id and d.company_id = ta.company_id and d.profit_ctr_id = ta.profit_ctr_id
LEFT JOIN disposalservice tad (nolock) on ta.disposal_service_id = tad.disposal_service_id
left join profile p (nolock) on d.profile_id = p.profile_id
LEFT JOIN profilequoteapproval pqa (nolock) on p.profile_id = pqa.profile_id and d.profile_company_id = pqa.company_id and d.profile_profit_ctr_id = pqa.profit_ctr_id
LEFT JOIN treatment tr (nolock) on pqa.treatment_id = tr.treatment_id and d.profile_company_id = tr.company_id and d.profile_profit_ctr_id = tr.profit_ctr_id
WHERE h.workorder_id is not null and h.company_id is not null and h.profit_ctr_id is not null
and h.workorder_status NOT IN ('V','X','T')
ORDER BY [Unique Manifest Identifier], Line

	insert plt_export..work_Intelex_Costco_Log (log_message)
	values ('(' + convert(varchar(10), @@spid) + ') sp_COR_Costco_Intelex_Manifest_Line_list populated plt_export.dbo.work_Intelex_Costco_Waste_Manifest_Line_list with ' + convert(varchar(10), @@rowcount) + ' rows and finished')

go

grant execute on sp_COR_Costco_Intelex_Manifest_Line_list
to cor_user
go

grant execute on sp_COR_Costco_Intelex_Manifest_Line_list
to eqai
go

grant execute on sp_COR_Costco_Intelex_Manifest_Line_list
to eqweb
go

grant execute on sp_COR_Costco_Intelex_Manifest_Line_list
to CRM_Service
go

grant execute on sp_COR_Costco_Intelex_Manifest_Line_list
to DATATEAM_SVC
go

