
-- drop proc if exists sp_COR_Costco_Intelex_Waste_Service_Event_list

go
create proc sp_COR_Costco_Intelex_Waste_Service_Event_list
	@web_userid		varchar(100)
	, @start_date		datetime
	, @end_date		datetime
as

/*
sp_COR_Costco_Intelex_Waste_Service_Event_list


sp_COR_Costco_Intelex_Waste_Service_Event_list @web_userid = 'use@costco.com'
	, @start_date  = '1/1/2021' -- '2/1/2020'
	, @end_date	 = '10/31/2021' -- '2/8/2020'

SELECT  * FROM    generator WHERE site_code = '1216FS'
SELECT  * FROM    generatorsitetype WHERE generator_site_type = 'Costco FS'

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

Generator EPA ID	
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
declare @web_userid varchar(100) = 'use@costco.com'
	, @start_date datetime = null -- '1/1/2021'
	, @end_date	datetime = null -- '12/18/2021'

set fmtonly on
select convert(varchar(12), null) as [Generator EPA ID]
	, convert(varchar(16), null) as [Location] 
	, convert(varchar(100), null) as [Site Type] 
	, convert(varchar(20), null) as [Vendor] 
	, convert(varchar(40) , null) as [Unique Service No.] 
	, convert(datetime, null) as [Service Date] 
set fmtonly off
*/	

set nocount on
	
declare 
	@i_web_userid		varchar(100)	= isnull(@web_userid, '')
	, @i_start_date		datetime		= coalesce(@start_date, convert(date,getdate()-7))
	, @i_end_date		datetime		= coalesce(@end_date, @start_date+7, convert(date, getdate()))
	, @i_contact_id		int

	if object_id('tempdb..#intelex_source') is null
		insert plt_export..work_Intelex_Costco_Log (log_message)
		values ('(' + convert(varchar(10), @@spid) + ') exec sp_COR_Costco_Intelex_Waste_Service_Event_list ''' + @i_web_userid + ''', ''' + convert(varchar(40), @start_date, 121) + ''', ''' + convert(varchar(40), @end_date, 121) + '''')

select top 1 @i_contact_id = contact_id from Contact WHERE web_userid = @i_web_userid

--select @i_start_date, @i_end_date

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

--SELECT  * FROM    #source

-- standardizing dates, relying on the work order's service date.
update #source set service_date = x.service_date
-- SELECT  x.service_date, s.* 
FROM  #Source s
join ContactCORWorkorderHeaderBucket x 
on s.workorder_id = x.workorder_id
and s.workorder_company_id = x.company_id
and s.workorder_profit_ctr_id = x.profit_ctr_id
and x.contact_id = @i_contact_id
WHERE trans_source = 'R'
AND s.service_date <> x.service_date


declare @src table (
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

insert @src (
	trans_source		
	, receipt_id		
	, company_id		
	, profit_ctr_id		
	, manifest			
	, generator_id		
	, service_date		
	, workorder_id		
	, workorder_company_id	
	, workorder_profit_ctr_id
	, site_code
	, generator_sublocation_id
	, site_type
)
select distinct
	src.*
	, g.site_code
	, null
	, g.site_type
from #Source src
join generator g (nolock) on src.generator_id = g.generator_id

update s set
	generator_sublocation_id = w.generator_sublocation_id
from @src s
join workorderheader w (nolock)
on s.workorder_id = w.workorder_id
and s.workorder_company_id = w.company_id
and s.workorder_profit_ctr_id= w.profit_ctr_id
WHERE s.trans_source = 'R'

update s set
	generator_sublocation_id = w.generator_sublocation_id
from @src s
join workorderheader w (nolock)
on s.receipt_id = w.workorder_id
and s.company_id = w.company_id
and s.profit_ctr_id= w.profit_ctr_id
WHERE s.trans_source = 'W'

insert @src (
	trans_source		
	, receipt_id		
	, company_id		
	, profit_ctr_id		
	, manifest			
	, generator_id		
	, service_date		
	, workorder_id		
	, workorder_company_id	
	, workorder_profit_ctr_id
	, site_code
	, generator_sublocation_id
	, site_type
)
select distinct
	src.*
	, g.site_code
	, h.generator_sublocation_id
	, g.site_type
from #Source src
join workorderheader h (nolock)
	on src.trans_source = 'W'
	and src.receipt_id = h.workorder_id
	and src.company_id = h.company_id
	and src.profit_ctr_id = h.profit_ctr_id
join generator g (nolock) on src.generator_id = g.generator_id
and not exists (
	select 1 from @src where workorder_id = h.workorder_id
	and workorder_company_id = h.company_id
	and workorder_profit_ctr_id = h.profit_ctr_id
	union
	select 1 from @src where receipt_id = h.workorder_id
	and company_id = h.company_id
	and profit_ctr_id = h.profit_ctr_id
	and trans_source = src.trans_source
)


update s set
	site_code = left(site_code, len(site_code) - len(gsl.code))
from @src s
join generatorsublocation gsl (nolock) on s.generator_sublocation_id = gsl.generator_sublocation_id
where site_code like '%' + gsl.code

while exists (select 1 from @src where site_code like '0%')
begin
	update s set
		site_code = right(site_code, len(site_code) -1)
	from @src s
	where site_code like '0%'
end

update s set
	site_type = coalesce(gsl.description, s.site_type, '')
from @src s
left join generatorsublocation gsl (nolock) on s.generator_sublocation_id = gsl.generator_sublocation_id

update @src set
	site_type = case site_type 
		when 'Costco' then 'Store' 
		when 'Costco FS' then 'Fuel Station'
		else site_type
		end
	where site_type like 'Costco%'

update s set manifest_flag = case h.manifest_flag when 'T' then 'M' else 'B' end
from @src s
join workordermanifest h (nolock)
	on s.trans_source = 'W'
	and s.receipt_id = h.workorder_id
	and s.company_id = h.company_id
	and s.profit_ctr_id = h.profit_ctr_id
	and s.manifest = h.manifest
	
update s set manifest_flag = r.manifest_flag
from @src s
join receipt r (nolock)
	on s.trans_source = 'R'
	and s.receipt_id = r.receipt_id
	and s.company_id = r.company_id
	and s.profit_ctr_id = r.profit_ctr_id
	and s.manifest = r.manifest

BEGIN TRY
	if object_id('tempdb..#intelex_source') is not null begin
		insert #intelex_source
		select * from @src
		
		insert plt_export..work_Intelex_Costco_Log (log_message)
		values ('  (' + convert(varchar(10), @@spid) + ') sp_COR_Costco_Intelex_Waste_Service_Event_list was called to fill #intelex_source with ' + convert(varchar(10), @@rowcount) + ' rows and ended')
		
		return
	end
END TRY
BEGIN CATCH
	-- Nothing
END CATCH

/*

Now if you defined a #intelex_source table before calling this, it's got this data in it.

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


*/

set nocount off

truncate table plt_export.dbo.work_Intelex_Costco_Waste_Service_Event_list

insert plt_export.dbo.work_Intelex_Costco_Waste_Service_Event_list
(
	[Generator EPA ID]		,
	[Location]				,
	[Site Type]				,
	[Vendor]				,
	[Unique Service No.]	,
	[Service Date]			

)
select
	-- [Waste Location] = convert(varchar(20), g.generator_id)

	[Generator EPA ID] = g.epa_id

	, [Location] = isnull(b.site_code, '')
	, [Site Type] = b.site_type
	
	, [Vendor] = 'US Ecology'

	, [Unique Service No.] = 
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

	, [Service Date] = convert(date, b.service_date)

from @src b
join generator g (nolock)
	on b.generator_id = g.generator_id

WHERE b.trans_source = 'R'
GROUP BY 
	convert(varchar(20), g.generator_id)
	, g.epa_id
	, isnull(b.site_code, '')
	, b.site_type
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
		--+ isnull('-'
		--+ convert(varchar(10), b.generator_sublocation_id)
		--,'')
	, convert(date, b.service_date)
	--, isnull(r.purchase_order,'')


union

select
	-- [Waste Location] = convert(varchar(20), g.generator_id)

	[Generator EPA ID] = g.epa_id
	
	, [Location] = isnull(b.site_code, '')
	, [Site Type] = b.site_type
	
	, [Vendor] = 'US Ecology'

	, [Unique Service No.] = right('00' + convert(varchar(2), b.company_id), 2) 
		+ '-'
		+ right('00' + convert(varchar(2), b.profit_ctr_id), 2) 
		+ '-W-'
		+ convert(varchar(20), b.receipt_id)
		--+ isnull('-'
		--+ convert(varchar(10), b.generator_sublocation_id)
		--, '')

	, [Service Date] = convert(date, b.service_date)

from @src b
join generator g (nolock)
	on b.generator_id = g.generator_id
WHERE b.trans_source = 'W'
GROUP BY 
	convert(varchar(20), g.generator_id)
	, g.epa_id
	, isnull(b.site_code, '')
	, b.site_type
	, right('00' + convert(varchar(2), b.company_id), 2) 
		+ '-'
		+ right('00' + convert(varchar(2), b.profit_ctr_id), 2) 
		+ '-W-'
		+ convert(varchar(20), b.receipt_id)
		--+ isnull('-'
		--+ convert(varchar(10), b.generator_sublocation_id)
		--, '')
	, convert(date, b.service_date)
--	, isnull(h.purchase_order,'')
ORDER BY [Unique Service No.], [Service Date]

	insert plt_export..work_Intelex_Costco_Log (log_message)
	values ('(' + convert(varchar(10), @@spid) + ') sp_COR_Costco_Intelex_Waste_Service_Event_list populated plt_export.dbo.work_Intelex_Costco_Waste_Service_Event_list with ' + convert(varchar(10), @@rowcount) + ' rows and finished')

go

grant execute on sp_COR_Costco_Intelex_Waste_Service_Event_list
to cor_user
go

grant execute on sp_COR_Costco_Intelex_Waste_Service_Event_list
to eqai
go

grant execute on sp_COR_Costco_Intelex_Waste_Service_Event_list
to eqweb
go

grant execute on sp_COR_Costco_Intelex_Waste_Service_Event_list
to CRM_Service
go

grant execute on sp_COR_Costco_Intelex_Waste_Service_Event_list
to DATATEAM_SVC
go


