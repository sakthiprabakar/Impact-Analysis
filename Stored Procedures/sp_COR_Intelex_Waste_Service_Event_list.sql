-- drop proc if exists sp_COR_Intelex_Waste_Service_Event_list

go
create proc sp_COR_Intelex_Waste_Service_Event_list
	@web_userid		varchar(100)
	, @start_date		datetime
	, @end_date		datetime
as

/*
sp_COR_Intelex_Waste_Service_Event_list


sp_COR_Intelex_Waste_Service_Event_list @web_userid = 'svc_cvs_intelex'
	, @start_date  = null -- '2/1/2020'
	, @end_date	 = null -- '2/8/2020'


Intelex
---------------

Some basic assumptions...
1. We only return information from work orders.
2. 


Waste Service Event

Outputs
Field Name
	Description	
	Length	
	Type	
	Mandatory
	USE Table.Field

Waste Location	
	Short version of location code. Waste hauler to provide value. Intelex to import value into a text field. This is not the Intelex location code, it is the vendor’s location ID	
	8	
	Text	
	N
	Generator.generator_id

Manifest EPA ID	
	Alpha-numeric field to capture the EPA ID of the facility	
	20	
	Text	
	N
	Generator.EPA_ID
	
Location	
	Used to identify the facility related to the pickup event. This is the Intelex location code as per location structure
	N/A	
	Relation
	Y
	Generator.Site_Code
	
Vendor	
	Fixed field specific to each vendor. E.g. Clean Earth would always send “Clean Earth”. Mandatory	
	N/A	
	Lookup	
	Y
	"US Ecology"

Service No.	
	Number field to uniquely identify the record across all vendors. Possible to have overlap, but would be unlikely. Mandatory	
	CVS to confirm	
	Text	
	Y
	WorkorderHeader.Company_ID + "-" + WorkorderHeader.profit_ctr_id + "-" + WorkorderHeader.workorder_id

Service Date	
	Date to specify when the pickup event took place. Mandatory	
	N/A	
	Date	
	Y
	WorkorderStop.date_act_arrive

Except	
	Flag to identify if there is an exception for this pickup event (only from Clean Earth, specific to retail)	
	N/A	
	Lookup	
	N
	""

Exception Type	
	One or more exception types tied to the event, i.e., “No Retail Accumulation,” etc. (only from Clean Earth, specific to retail)	
	N/A	
	Lookup (multi-select)	
	N
	""

Total Weight (lbs)	
	Total weight picked up (number with decimals only)	
	N/A	
	Float	
	N
	SUM(WorkorderDetailUnit.quantity) where bill_unit_code = 'LBS' and manifest_flag = 'T'

SELECT  * FROM    customer where cust_name like 'CVS%'
SELECT  * FROM    workorderheader where customer_id =13212
SELECT  * FROM    WorkorderDetail WHERE workorder_id = 869300 and company_id = 47 and profit_ctr_id = 0
SELECT  * FROM    WorkorderDetailUnit WHERE workorder_id = 869300 and company_id = 47 and profit_ctr_id = 0
SELECT  * FROM    tsdfapproval WHERE tsdf_approval_code = 'CV-19' and tsdf_code = 'BIOMEDWASTE' and company_id = 47

Hazardous Waste (lbs)	
	Total hazardous weight picked up (number with decimals only)	
	N/A	
	Float	
	N
	SUM(WorkorderDetailUnit.quantity) where bill_unit_code = 'LBS' and manifest_flag = 'T'
		matched to WorkorderDetail where hazardous waste code exists

EPA Acute Hazardous (lbs)	
	Total acute  weight picked up (number with decimals only)	
	N/A	
	Float	
	N
	SUM(WorkorderDetailUnit.quantity) where bill_unit_code = 'LBS' and manifest_flag = 'T'
		matched to WorkorderDetail where acute hazardous waste code exists

Purchase Order#	
	Alpha-numeric field to capture purchase order number if applicable	
	20	
	Text	
	N
	WorkorderHeader.purchase_order

Days Between Service	
	Number of days until next pickup	
	N/A	
	Number	
	N
	????

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
		--, manifest_line		int
		--, epa_id			varchar(20)
		--, [EPA Hazardous]	varchar(5)
		--, [EPA Acute Hazardous]	varchar(5)
		--, [State Coded]		varchar(5)
		--, [DOT Description] varchar(max)
		--, [Stream Name]		varchar(50)
		--, [Waste Codes]		varchar(max)
		--, [State Codes]		varchar(max)
		--, Quantity			int
		--, [Container Type]	varchar(10)
		--, [Weight (lbs)]	float
		--, [Waste Profile]	varchar(20)
		--, [Receiving Facility MM Code]	varchar(10)
		--, [Waste Stream Form Code]	varchar(10)
)

truncate table #source

insert #Source
Exec sp_COR_Intelex_Source
	@web_userid		= @i_web_userid
	, @start_date	= @i_start_date
	, @end_date		= @i_end_date

-- SELECT  * FROM    #Source

select
	[Waste Location] = convert(varchar(20), g.generator_id)
	/*
	Short version of location code. Waste hauler to provide value. Intelex to import value into a text field. This is not the Intelex location code, it is the vendor’s location ID	
	8	
	Text	
	N
	Generator.generator_id
	*/

	, [Manifest EPA ID] = g.epa_id
	/*
	Alpha-numeric field to capture the EPA ID of the facility	
	20	
	Text	
	N
	Generator.EPA_ID
	*/
	
	, [Location] = coalesce(g.generator_market_code, g.site_code, '')
	/*
	Used to identify the facility related to the pickup event. This is the Intelex location code as per location structure
	N/A	
	Relation
	Y
	Generator.Site_Code
	*/
	
	, [Vendor] = 'US Ecology'
	/*
	Fixed field specific to each vendor. E.g. Clean Earth would always send “Clean Earth”. Mandatory	
	N/A	
	Lookup	
	Y
	"US Ecology"
	*/

	, [Service No.] = 
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
	/*
	Number field to uniquely identify the record across all vendors. Possible to have overlap, but would be unlikely. Mandatory	
	CVS to confirm	
	Text	
	Y
	WorkorderHeader.Company_ID + "-" + WorkorderHeader.profit_ctr_id + "-" + WorkorderHeader.workorder_id
	*/

	, [Service Date] = convert(date, b.service_date)
	/*
	Date to specify when the pickup event took place. Mandatory	
	N/A	
	Date	
	Y
	WorkorderStop.date_act_arrive
	*/

	, [Except] = ''
	/*
	Flag to identify if there is an exception for this pickup event (only from Clean Earth, specific to retail)	
	N/A	
	Lookup	
	N
	""
	*/

	, [Exception Type] = ''
	/*
	One or more exception types tied to the event, i.e., “No Retail Accumulation,” etc. (only from Clean Earth, specific to retail)	
	N/A	
	Lookup (multi-select)	
	N
	""
	*/

	, [Total Weight (lbs)] = SUM(w.weight)
	/*
	Total weight picked up (number with decimals only)	
	N/A	
	Float	
	N
	SUM(WorkorderDetailUnit.quantity) where bill_unit_code = 'LBS' and manifest_flag = 'T'

		SELECT  * FROM    customer where cust_name like 'CVS%'
		SELECT  * FROM    workorderheader where customer_id =13212
		SELECT  * FROM    WorkorderDetail WHERE workorder_id = 869300 and company_id = 47 and profit_ctr_id = 0
		SELECT  * FROM    WorkorderDetailUnit WHERE workorder_id = 869300 and company_id = 47 and profit_ctr_id = 0
		SELECT  * FROM    tsdfapproval WHERE tsdf_approval_code = 'CV-19' and tsdf_code = 'BIOMEDWASTE' and company_id = 47
*/

	, [Hazardous Waste (lbs)] = SUM(case when w.hazardous > 0 then w.weight else 0 end)
	/*
	Total hazardous weight picked up (number with decimals only)	
	N/A	
	Float	
	N
	SUM(WorkorderDetailUnit.quantity) where bill_unit_code = 'LBS' and manifest_flag = 'T'
		matched to WorkorderDetail where hazardous waste code exists
	*/

	, [EPA Acute Hazardous (lbs)] = SUM(case when w.acute > 0 then w.weight else 0 end)
	/*
	Total acute  weight picked up (number with decimals only)	
	N/A	
	Float	
	N
	SUM(WorkorderDetailUnit.quantity) where bill_unit_code = 'LBS' and manifest_flag = 'T'
		matched to WorkorderDetail where acute hazardous waste code exists
	*/
	
	, [Purchase Order#] = isnull(r.purchase_order, '')
	/*
	Alpha-numeric field to capture purchase order number if applicable	
	20	
	Text	
	N
	WorkorderHeader.purchase_order
	*/

	, [Days Between Service] = ''
	/*
	Number of days until next pickup	
	N/A	
	Number	
	N
	????
	'' instead of 0 per Corbin on 7/20/20
	*/
from #Source b
join receipt r (nolock)
	on b.receipt_id = r.receipt_id
	and b.company_id = r.company_id
	and b.profit_ctr_id = r.profit_ctr_id
	and r.manifest not like '%manifest%'
	and b.trans_source = 'R'
join generator g (nolock)
	on b.generator_id = g.generator_id
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
		and (left(wc.display_name, 1) = 'P' or wc.display_name between 'F020' and 'F023' or wc.display_name between 'F026' and 'F028') 
	) then 1 else 0 end as acute
	from #Source b
	join receipt r (nolock)
		on b.receipt_id = r.receipt_id
		and b.company_id = r.company_id
		and b.profit_ctr_id = r.profit_ctr_id
		and r.manifest not like '%manifest%'
		and b.trans_source = 'R'
	WHERE r.receipt_id is not null and r.company_id is not null and r.profit_ctr_id is not null
	and r.receipt_status not in ('V', 'R')
	and r.trans_mode = 'I'
	and r.trans_type = 'D'
	and r.fingerpr_status = 'A'
	GROUP BY r.receipt_id, r.company_id, r.profit_ctr_id, r.line_id
) w
	on r.receipt_id = w.receipt_id
	and r.company_id = w.company_id
	and r.profit_ctr_id = w.profit_ctr_id
	and r.line_id = w.line_id
WHERE r.receipt_status not in ('V', 'R')
	and r.trans_mode = 'I'
	and r.trans_type = 'D'
	and r.fingerpr_status = 'A'
GROUP BY 
	convert(varchar(20), g.generator_id)
	, g.epa_id
	, coalesce(g.generator_market_code, g.site_code, '')
	, case when b.trans_source = 'R' and b.workorder_id is not null then
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
	, convert(date, b.service_date)
	, isnull(r.purchase_order,'')


union

select
	[Waste Location] = convert(varchar(20), g.generator_id)
	/*
	Short version of location code. Waste hauler to provide value. Intelex to import value into a text field. This is not the Intelex location code, it is the vendor’s location ID	
	8	
	Text	
	N
	Generator.generator_id
	*/

	, [Manifest EPA ID] = g.epa_id
	/*
	Alpha-numeric field to capture the EPA ID of the facility	
	20	
	Text	
	N
	Generator.EPA_ID
	*/
	
	, [Location] = coalesce(g.generator_market_code, g.site_code, '')
	/*
	Used to identify the facility related to the pickup event. This is the Intelex location code as per location structure
	N/A	
	Relation
	Y
	Generator.Site_Code
	*/
	
	, [Vendor] = 'US Ecology'
	/*
	Fixed field specific to each vendor. E.g. Clean Earth would always send “Clean Earth”. Mandatory	
	N/A	
	Lookup	
	Y
	"US Ecology"
	*/

	, [Service No.] = right('00' + convert(varchar(2), b.company_id), 2) 
		+ '-'
		+ right('00' + convert(varchar(2), b.profit_ctr_id), 2) 
		+ '-W-'
		+ convert(varchar(20), b.receipt_id)
	/*
	Number field to uniquely identify the record across all vendors. Possible to have overlap, but would be unlikely. Mandatory	
	CVS to confirm	
	Text	
	Y
	WorkorderHeader.Company_ID + "-" + WorkorderHeader.profit_ctr_id + "-" + WorkorderHeader.workorder_id
	*/

	, [Service Date] = convert(date, b.service_date)
	/*
	Date to specify when the pickup event took place. Mandatory	
	N/A	
	Date	
	Y
	WorkorderStop.date_act_arrive
	*/

	, [Except] = ''
	/*
	Flag to identify if there is an exception for this pickup event (only from Clean Earth, specific to retail)	
	N/A	
	Lookup	
	N
	""
	*/

	, [Exception Type] = ''
	/*
	One or more exception types tied to the event, i.e., “No Retail Accumulation,” etc. (only from Clean Earth, specific to retail)	
	N/A	
	Lookup (multi-select)	
	N
	""
	*/

	, [Total Weight (lbs)] = SUM(isnull(w.total_pounds,0))
	/*
	Total weight picked up (number with decimals only)	
	N/A	
	Float	
	N
	SUM(WorkorderDetailUnit.quantity) where bill_unit_code = 'LBS' and manifest_flag = 'T'

		SELECT  * FROM    customer where cust_name like 'CVS%'
		SELECT  * FROM    workorderheader where customer_id =13212
		SELECT  * FROM    WorkorderDetail WHERE workorder_id = 869300 and company_id = 47 and profit_ctr_id = 0
		SELECT  * FROM    WorkorderDetailUnit WHERE workorder_id = 869300 and company_id = 47 and profit_ctr_id = 0
		SELECT  * FROM    tsdfapproval WHERE tsdf_approval_code = 'CV-19' and tsdf_code = 'BIOMEDWASTE' and company_id = 47
*/

	, [Hazardous Waste (lbs)] = SUM(case when w.hazardous > 0 then w.total_pounds else 0 end)
	/*
	Total hazardous weight picked up (number with decimals only)	
	N/A	
	Float	
	N
	SUM(WorkorderDetailUnit.quantity) where bill_unit_code = 'LBS' and manifest_flag = 'T'
		matched to WorkorderDetail where hazardous waste code exists
	*/

	, [EPA Acute Hazardous (lbs)] = SUM(case when w.acute > 0 then w.total_pounds else 0 end)
	/*
	Total acute  weight picked up (number with decimals only)	
	N/A	
	Float	
	N
	SUM(WorkorderDetailUnit.quantity) where bill_unit_code = 'LBS' and manifest_flag = 'T'
		matched to WorkorderDetail where acute hazardous waste code exists
	*/
	
	, [Purchase Order#] = isnull(h.purchase_order, '')
	/*
	Alpha-numeric field to capture purchase order number if applicable	
	20	
	Text	
	N
	WorkorderHeader.purchase_order
	*/

	, [Days Between Service] = ''
	/*
	Number of days until next pickup	
	N/A	
	Number	
	N
	????
	'' instead of 0 per Corbin on 7/20/20
	*/
from #Source b
join workorderheader h (nolock)
	on b.receipt_id = h.workorder_id
	and b.company_id = h.company_id
	and b.profit_ctr_id = h.profit_ctr_id
	and b.trans_source = 'W'
join generator g (nolock)
	on b.generator_id = g.generator_id
LEFT JOIN (
	select d.workorder_id, d.company_id, d.profit_ctr_id, d.sequence_id, d.manifest
	, case when exists (
		select 1 from workorderwastecode wwc (nolock)
		join wastecode wc (nolock)
			on wwc.waste_code_uid = wc.waste_code_uid
		where
		wwc.workorder_id = d.workorder_id
		and wwc.workorder_sequence_id = d.sequence_id
		and wwc.company_id = d.company_id
		and wwc.profit_ctr_id = d.profit_ctr_id
		and wc.waste_code_origin = 'F' and wc.haz_flag = 'T'
	) then 1 else 0 end as hazardous
	, case when exists (
		select 1 from workorderwastecode wwc (nolock)
		join wastecode wc (nolock)
			on wwc.waste_code_uid = wc.waste_code_uid
		where
		wwc.workorder_id = d.workorder_id
		and wwc.workorder_sequence_id = d.sequence_id
		and wwc.company_id = d.company_id
		and wwc.profit_ctr_id = d.profit_ctr_id
		and wc.waste_code_origin = 'F' and wc.haz_flag = 'T'
		and (left(wc.display_name, 1) = 'P' or wc.display_name between 'F020' and 'F023' or wc.display_name between 'F026' and 'F028') 
	) then 1 else 0 end as acute
	, dbo.fn_workorder_weight_line (d.workorder_id, d.sequence_id, d.profit_ctr_id, d.company_id) as total_pounds
	from #Source s 
	join workorderheader h (nolock)
		on s.receipt_id = h.workorder_id
		and s.company_id = h.company_id
		and s.profit_ctr_id = h.profit_ctr_id
	join workorderdetail d (nolock)
		on s.receipt_id = d.workorder_id
		and s.company_id = d.company_id
		and s.profit_ctr_id = d.profit_ctr_id
		and d.resource_type = 'D'
		and d.bill_rate >= -1
		and d.manifest not like '%manifest%'
		and d.manifest = s.manifest
	--join workorderwastecode wwc (nolock)
	--	on b.workorder_id = wwc.workorder_id
	--	and b.company_id = wwc.company_id
	--	and b.profit_ctr_id = wwc.profit_ctr_id
	--	and d.sequence_id = wwc.workorder_sequence_id	
	--join wastecode wc (nolock)
	--	on wc.waste_code_uid = wwc.waste_code_uid
	WHERE h.workorder_id is not null and h.company_id is not null and h.profit_ctr_id is not null
	and h.workorder_status NOT IN ('V','X','T')
	GROUP BY d.workorder_id, d.company_id, d.profit_ctr_id, d.sequence_id, d.manifest
) w
	on b.receipt_id = w.workorder_id
	and b.company_id = w.company_id
	and b.profit_ctr_id = w.profit_ctr_id
	--and u.sequence_id = w.sequence_id
	and b.manifest = w.manifest
GROUP BY 
	convert(varchar(20), g.generator_id)
	, g.epa_id
	, coalesce(g.generator_market_code, g.site_code, '')
	, right('00' + convert(varchar(2), b.company_id), 2) 
		+ '-'
		+ right('00' + convert(varchar(2), b.profit_ctr_id), 2) 
		+ '-W-'
		+ convert(varchar(20), b.receipt_id)
	, convert(date, b.service_date)
	, isnull(h.purchase_order,'')

ORDER BY
	[Service No.]

go

grant execute on sp_COR_Intelex_Waste_Service_Event_list
to cor_user
go

grant execute on sp_COR_Intelex_Waste_Service_Event_list
to eqai
go


grant execute on sp_COR_Intelex_Waste_Service_Event_list
to eqweb
go

grant execute on sp_COR_Intelex_Waste_Service_Event_list
to CRM_Service
go

grant execute on sp_COR_Intelex_Waste_Service_Event_list
to DATATEAM_SVC
go
