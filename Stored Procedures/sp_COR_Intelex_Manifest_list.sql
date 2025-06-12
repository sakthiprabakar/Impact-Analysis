-- drop proc if exists sp_COR_Intelex_Manifest_list
go
create proc sp_COR_Intelex_Manifest_list
	@web_userid		varchar(100)
	, @start_date		datetime
	, @end_date		datetime
as

/*
sp_COR_Intelex_Manifest_list


sp_COR_Intelex_Manifest_list @web_userid = 'svc_cvs_intelex'
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

Manifest No.	
	Number of manifest document	
	20 (to be confirmed based on BOLs)	
	Text	
	Y

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

Receiving Facility Name	
	Text field to indicate the name of the facility receiving the waste	
	50 (CVS to confirm)	
	Text	
	N

Receiving Facility EPA ID	
	Alpha-numeric field to capture the EPA ID of the facility receiving the waste	
	20 (CVS to confirm)	
	Text	
	N

Waste Service Event	
	The related Waste Service Event this manifest belongs to. Would be the Service No. The service numbers will not be identical across different vendors	
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

-- SELECT  * FROM    #Source

select distinct

	--- b.service_date, h.date_added, h.date_modified, h.company_id, h.profit_ctr_id, h.workorder_id,

	[Manifest No.] = b.manifest
	/*
	Number of manifest document	
	20 (to be confirmed based on BOLs)	
	Text	
	Y
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

	, [Receiving Facility Name] = 
		case trans_source when 'R' then pc.profit_ctr_name
			when 'W' then t.tsdf_name
		end
	/*
	Text field to indicate the name of the facility receiving the waste	
	50 (CVS to confirm)	
	Text	
	N
	*/

	, [Receiving Facility EPA ID] =
		case trans_source when 'R' then pc.epa_id
			when 'W' then t.tsdf_epa_id
		end
	
	/*
	Alpha-numeric field to capture the EPA ID of the facility receiving the waste	
	20 (CVS to confirm)	
	Text	
	N
	*/

	, [Waste Service Event] = 
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
	The related Waste Service Event this manifest belongs to. Would be the Service No. The service numbers will not be identical across different vendors	
	N/A	
	Relation	
	Y
	*/

from #Source b 
join generator g (nolock)
	on b.generator_id = g.generator_id
left join profitcenter pc (nolock)
	on b.company_id = pc.company_id
	and b.profit_ctr_id = pc.profit_ctr_id
	and b.trans_source = 'R'

left join workorderdetail d (nolock)
	on b.receipt_id = d.workorder_id
	and b.company_id = d.company_id
	and b.profit_ctr_id = d.profit_ctr_id
	and d.resource_type = 'D'
	and d.bill_rate >= -1
	and d.manifest = b.manifest
	and b.trans_source = 'W'
left join tsdf t (nolock) 
	on d.tsdf_code = t.tsdf_code
	and b.trans_source = 'W'
order by [Waste Service Event], [Manifest No.]

go

grant execute on sp_COR_Intelex_Manifest_list
to cor_user
go

grant execute on sp_COR_Intelex_Manifest_list
to eqai
go

grant execute on sp_COR_Intelex_Manifest_list
to eqweb
go

grant execute on sp_COR_Intelex_Manifest_list
to CRM_Service
go

grant execute on sp_COR_Intelex_Manifest_list
to DATATEAM_SVC
go
