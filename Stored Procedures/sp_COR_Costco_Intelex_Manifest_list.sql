-- drop proc if exists sp_COR_Costco_Intelex_Manifest_list
go
create proc sp_COR_Costco_Intelex_Manifest_list
	@web_userid		varchar(100)
	, @start_date		datetime
	, @end_date		datetime
as

/*
sp_COR_Costco_Intelex_Manifest_list


exec sp_COR_Costco_Intelex_Waste_Service_Event_list @web_userid = 'use@costco.com'
	, @start_date  = '10/1/2020' -- '2/1/2020'
	, @end_date	 = '10/1/2020' -- '2/8/2020'

exec sp_COR_Costco_Intelex_Manifest_list @web_userid = 'use@costco.com'
	, @start_date  = '1/1/2022' -- '2/1/2022'
	, @end_date	 = '12/31/2022' -- '2/8/2022'

SELECT  * FROM    plt_export.dbo.work_Intelex_Costco_Waste_Manifest_list
-- 7417 new way


2023-01-30 - Revised logic to avoid duplicates and collect better data.


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
	, @placeholder_url  varchar(200)

	insert plt_export..work_Intelex_Costco_Log (log_message)
	values ('(' + convert(varchar(10), @@spid) + ') exec sp_COR_Costco_Intelex_Manifest_list ''' + @i_web_userid + ''', ''' + convert(varchar(40), @start_date, 121) + ''', ''' + convert(varchar(40), @end_date, 121) + '''')


select top 1 @placeholder_url = config_value 
from plt_ai..Configuration 
WHERE config_key = 'sp_COR_Costco_Intelex Image URL'

	insert plt_export..work_Intelex_Costco_Log (log_message)
	values ('(' + convert(varchar(10), @@spid) + ') sp_COR_Costco_Intelex_Manifest_list url target: ' + @placeholder_url)


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



select distinct

	--- b.service_date, h.date_added, h.date_modified, h.company_id, h.profit_ctr_id, h.workorder_id,

	[Manifest No.] = b.manifest

	-- , [Waste Location] = convert(varchar(20), g.generator_id)

	-- , [EPA ID] = g.epa_id

--	, [Receiving Facility Name] = pc.profit_ctr_name

--	, [Receiving Facility EPA ID] = pc.epa_id

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

	, [Unique Manifest Identifier] = 
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

/*
-- no encrypted  :	
	,  @placeholder_url + convert(varchar(20), (
		select min(s.image_id)
		from plt_image..scan s
		where s.workorder_id = b.workorder_id
		and s.company_id = b.workorder_company_id
		and s.profit_ctr_id = b.workorder_profit_ctr_id
		and s.document_source = 'workorder'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'workorder'
			and document_type like '%initial%manifest%'
			and status = 'A'
		)
		and s.status = 'A'
		)) as initial_manifest_url

-- encrypted url:

	,  @placeholder_url + dbo.fn_cor2_image_id_encrypt( (
		select min(s.image_id)
		from plt_image..scan s
		where s.workorder_id = b.workorder_id
		and s.company_id = b.workorder_company_id
		and s.profit_ctr_id = b.workorder_profit_ctr_id
		and s.document_source = 'workorder'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'workorder'
			and document_type like case b.manifest_flag when 'M' then '%initial%manifest%' else '%bol%' end
			and status = 'A'
		)
		and	isnull(s.document_name, '') + isnull(s.manifest, '') + isnull(s.scan_file, '') + isnull(s.description, '') like '%' + b.manifest + '%'
		and s.status = 'A'
		)) 
*/
, NULL		as initial_manifest_url
		
	, (
		select min(isnull(upload_date, date_modified))
		from plt_image..scan s
		where s.workorder_id = b.workorder_id
		and s.company_id = b.workorder_company_id
		and s.profit_ctr_id = b.workorder_profit_ctr_id
		and s.document_source = 'workorder'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'workorder'
			and document_type like case b.manifest_flag when 'M' then '%initial%manifest%' else '%bol%' end
			and status = 'A'
		)
		and isnull(s.document_name, '') + isnull(s.manifest, '') + isnull(s.scan_file, '') + isnull(s.description, '') like '%' + b.manifest + '%'
		and s.status = 'A'
		) as date_initial_manifest


, (
		select min(s.image_id)
		from plt_image..scan s
		where s.workorder_id = b.workorder_id
		and s.company_id = b.workorder_company_id
		and s.profit_ctr_id = b.workorder_profit_ctr_id
		and s.document_source = 'workorder'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'workorder'
			and document_type like case b.manifest_flag when 'M' then '%initial%manifest%' else '%bol%' end
			and status = 'A'
		)
		and	isnull(s.document_name, '') + isnull(s.manifest, '') + isnull(s.scan_file, '') + isnull(s.description, '') like '%' + b.manifest + '%'
		and s.status = 'A'
		)
		as initial_min_image_id
		
, (
		select min(s.image_id)
		from plt_image..scan s
		where s.receipt_id = b.receipt_id
		and s.company_id = b.company_id
		and s.profit_ctr_id = b.profit_ctr_id
		and s.document_source = 'receipt'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'receipt'
			and document_type like case b.manifest_flag when 'M' then '%manifest%' else '%bol%' end
			and document_type not like case b.manifest_flag when 'M' then '%initial%' else 'zzzzzzz' end
			and status = 'A'
		)
		--and isnull(s.document_name, '') + isnull(s.manifest, '') + isnull(s.scan_file, '') + isnull(s.description, '') like '%' + b.manifest + '%'
		and s.status = 'A'
		)
		as final_min_image_id
		
/*
-- no encrypted url:
	,  @placeholder_url + convert(varchar(20), (
		select min(s.image_id)
		from plt_image..scan s
		where s.receipt_id = b.receipt_id
		and s.company_id = b.company_id
		and s.profit_ctr_id = b.profit_ctr_id
		and s.document_source = 'receipt'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'receipt'
			and document_type like '%manifest%'
			and document_type not like '%initial%'
			and status = 'A'
		)
		and s.status = 'A'
		)) as final_manifest_url


-- encrypted url:
	,  @placeholder_url + dbo.fn_cor2_image_id_encrypt( (
		select min(s.image_id)
		from plt_image..scan s
		where s.receipt_id = b.receipt_id
		and s.company_id = b.company_id
		and s.profit_ctr_id = b.profit_ctr_id
		and s.document_source = 'receipt'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'receipt'
			and document_type like case b.manifest_flag when 'M' then '%manifest%' else '%bol%' end
			and document_type not like case b.manifest_flag when 'M' then '%initial%' else 'zzzzzzz' end
			and status = 'A'
		)
		and isnull(s.document_name, '') + isnull(s.manifest, '') + isnull(s.scan_file, '') + isnull(s.description, '') like '%' + b.manifest + '%'
		and s.status = 'A'
		)) 
*/
, NULL		as final_manifest_url
	
	
	, (
		select min(isnull(upload_date, date_modified))
		from plt_image..scan s
		where s.receipt_id = b.receipt_id
		and s.company_id = b.company_id
		and s.profit_ctr_id = b.profit_ctr_id
		and s.document_source = 'receipt'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'receipt'
			and document_type like case b.manifest_flag when 'M' then '%manifest%' else '%bol%' end
			and document_type not like case b.manifest_flag when 'M' then '%initial%' else 'zzzzzzz' end
			and status = 'A'
		)
		and isnull(s.document_name, '') + isnull(s.manifest, '') + isnull(s.scan_file, '') + isnull(s.description, '') like '%' + b.manifest + '%'
		and s.status = 'A'
		) as date_final_manifest
	
into #intelex_manifest_list	
from #intelex_source b 
join generator g (nolock)
	on b.generator_id = g.generator_id
join profitcenter pc (nolock)
	on b.company_id = pc.company_id
	and b.profit_ctr_id = pc.profit_ctr_id
where b.trans_source = 'R'

union

select distinct

	--- b.service_date, h.date_added, h.date_modified, h.company_id, h.profit_ctr_id, h.workorder_id,

	[Manifest No.] = b.manifest

	-- , [Waste Location] = convert(varchar(20), g.generator_id)

	-- , [Generator EPA ID] = g.epa_id

--	, [Receiving Facility Name] = t.tsdf_name

--	, [Receiving Facility EPA ID] = t.tsdf_epa_id

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

	, [Unique Manifest Identifier] = 
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

/*
-- no encrypted url:
	,  @placeholder_url + convert(varchar(20), (
		select min(s.image_id)
		from plt_image..scan s
		where s.workorder_id = b.receipt_id
		and s.company_id = b.company_id
		and s.profit_ctr_id = b.profit_ctr_id
		and s.document_source = 'workorder'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'workorder'
			and document_type like '%initial%manifest%'
			and status = 'A'
		)
		and s.status = 'A'
		)) as initial_manifest_url


-- encrypted url:
	,  @placeholder_url + dbo.fn_cor2_image_id_encrypt( (
		select min(s.image_id)
		from plt_image..scan s
		where s.workorder_id = b.receipt_id
		and s.company_id = b.company_id
		and s.profit_ctr_id = b.profit_ctr_id
		and s.document_source = 'workorder'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'workorder'
			and document_type like case b.manifest_flag when 'M' then '%initial%manifest%' else '%bol%' end
			and status = 'A'
		)
		and isnull(s.document_name, '') + isnull(s.manifest, '') + isnull(s.scan_file, '') + isnull(s.description, '') like '%' + b.manifest + '%'
		and s.status = 'A'
		)) 
*/
, NULL		as initial_manifest_url
		
	, (
		select min(isnull(upload_date, date_modified))
		from plt_image..scan s
		where s.workorder_id = b.receipt_id
		and s.company_id = b.company_id
		and s.profit_ctr_id = b.profit_ctr_id
		and s.document_source = 'workorder'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'workorder'
			and document_type like case b.manifest_flag when 'M' then '%initial%manifest%' else '%bol%' end
			and status = 'A'
		)
		and isnull(s.document_name, '') + isnull(s.manifest, '') + isnull(s.scan_file, '') + isnull(s.description, '') like '%' + b.manifest + '%'
		and s.status = 'A'
		) as date_initial_manifest


, (
		select min(s.image_id)
		from plt_image..scan s
		where s.workorder_id = b.receipt_id
		and s.company_id = b.company_id
		and s.profit_ctr_id = b.profit_ctr_id
		and s.document_source = 'workorder'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'workorder'
			and document_type like case b.manifest_flag when 'M' then '%initial%manifest%' else '%bol%' end
			and status = 'A'
		)
		and	isnull(s.document_name, '') + isnull(s.manifest, '') + isnull(s.scan_file, '') + isnull(s.description, '') like '%' + b.manifest + '%'
		and s.status = 'A'
		)
		as initial_min_image_id
		
, (
		select min(s.image_id)
		from plt_image..scan s
		where s.receipt_id = b.receipt_id
		and s.company_id = b.company_id
		and s.profit_ctr_id = b.profit_ctr_id
		and s.document_source = 'receipt'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'receipt'
			and document_type like case b.manifest_flag when 'M' then '%manifest%' else '%bol%' end
			and document_type not like case b.manifest_flag when 'M' then '%initial%' else 'zzzzzzz' end
			and status = 'A'
		)
		and isnull(s.document_name, '') + isnull(s.manifest, '') + isnull(s.scan_file, '') + isnull(s.description, '') like '%' + b.manifest + '%'
		and s.status = 'A'
		)
		as final_min_image_id



/*
-- no encrypted url:
	,  @placeholder_url + convert(varchar(20), (
		select min(s.image_id)
		from plt_image..scan s
		where s.workorder_id = b.receipt_id
		and s.company_id = b.company_id
		and s.profit_ctr_id = b.profit_ctr_id
		and s.document_source = 'workorder'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'workorder'
			and document_type like '%manifest%'
			and document_type not like '%initial%'
			and status = 'A'
		)
		and s.status = 'A'
		)) as final_manifest_url
	
-- encrypted url:
	,  @placeholder_url + dbo.fn_cor2_image_id_encrypt( (
		select min(s.image_id)
		from plt_image..scan s
		where s.workorder_id = b.receipt_id
		and s.company_id = b.company_id
		and s.profit_ctr_id = b.profit_ctr_id
		and s.document_source = 'workorder'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'workorder'
			and document_type like case b.manifest_flag when 'M' then '%manifest%' else '%bol%' end
			and document_type not like case b.manifest_flag when 'M' then '%initial%' else 'zzzzzzz' end
			and status = 'A'
		)
		and isnull(s.document_name, '') + isnull(s.manifest, '') + isnull(s.scan_file, '') + isnull(s.description, '') like '%' + b.manifest + '%'
		and s.status = 'A'
		)) 
*/
, NULL		as final_manifest_url
	
	, (
		select min(isnull(upload_date, date_modified))
		from plt_image..scan s
		where s.workorder_id = b.receipt_id
		and s.company_id = b.company_id
		and s.profit_ctr_id = b.profit_ctr_id
		and s.document_source = 'workorder'
		and s.type_id in (select type_id 
			from plt_image..ScanDocumentType
			where scan_type = 'receipt'
			and document_type like case b.manifest_flag when 'M' then '%manifest%' else '%bol%' end
			and document_type not like case b.manifest_flag when 'M' then '%initial%' else 'zzzzzzz' end
			and status = 'A'
		)
		and isnull(s.document_name, '') + isnull(s.manifest, '') + isnull(s.scan_file, '') + isnull(s.description, '') like '%' + b.manifest + '%'
		and s.status = 'A'
		) as date_final_manifest
		

from #intelex_source b 
join generator g (nolock)
	on b.generator_id = g.generator_id
join workorderdetail d (nolock)
	on b.receipt_id = d.workorder_id
	and b.company_id = d.company_id
	and b.profit_ctr_id = d.profit_ctr_id
	and d.resource_type = 'D'
	and d.bill_rate >= -1
	and d.manifest = b.manifest
	and d.manifest not like '%manifest%'
join workordermanifest m (nolock)
	on b.receipt_id = m.workorder_id
	and b.company_id = m.company_id
	and b.profit_ctr_id = m.profit_ctr_id
	and d.manifest = m.manifest
--	and m.manifest_flag = 'T' -- 12/30/2022 - This was commented. Why were we requiring 'T'?  Receipts don't require that.
--	and m.manifest_state = 'H'
	and m.manifest not like '%manifest%'
join tsdf t (nolock) 
	on d.tsdf_code = t.tsdf_code
where b.trans_source = 'W'
-- ORDER BY [Unique Service No.], [unique manifest identifier]

truncate table plt_export.dbo.work_Intelex_Costco_Waste_Manifest_list

insert plt_export.dbo.work_Intelex_Costco_Waste_Manifest_list
(
	[Manifest No.]					,
	[Unique Service No.]			,
	[Unique Manifest Identifier]	,
	[initial_manifest_url]			,
	[date_initial_manifest]			,
	[final_manifest_url]			,
	[date_final_manifest]			

)

select 
	[Manifest No.]
	, [Unique Service No.]
	, [Unique Manifest Identifier]
	, @placeholder_url + dbo.fn_cor2_image_id_encrypt(initial_min_image_id) as initial_manifest_url
	, [date_initial_manifest]
	, @placeholder_url + dbo.fn_cor2_image_id_encrypt(final_min_image_id)	as final_manifest_url
	, date_final_manifest
from #intelex_manifest_list	



insert plt_export..work_Intelex_Costco_Log (log_message)
values ('(' + convert(varchar(10), @@spid) + ') sp_COR_Costco_Intelex_Manifest_list populated plt_export.dbo.work_Intelex_Costco_Waste_Manifest_list with ' + convert(varchar(10), @@rowcount) + ' rows and finished')


go

grant execute on sp_COR_Costco_Intelex_Manifest_list
to cor_user
go

grant execute on sp_COR_Costco_Intelex_Manifest_list
to eqai
go

grant execute on sp_COR_Costco_Intelex_Manifest_list
to eqweb
go

grant execute on sp_COR_Costco_Intelex_Manifest_list
to CRM_Service
go

grant execute on sp_COR_Costco_Intelex_Manifest_list
to DATATEAM_SVC
go

