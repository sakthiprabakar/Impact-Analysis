-- drop proc if exists sp_COR_Costco_Intelex_Waste_Supporting_Documentation_list

go
create proc sp_COR_Costco_Intelex_Waste_Supporting_Documentation_list
	@web_userid		varchar(100)
	, @start_date		datetime
	, @end_date		datetime
as

/*
sp_COR_Costco_Intelex_Waste_Supporting_Documentation_list


exec sp_COR_Costco_Intelex_Waste_Supporting_Documentation_list @web_userid = 'use@costco.com'
	, @start_date  = '10/1/2020' -- '2/1/2020'
	, @end_date	 = '10/1/2020' -- '2/8/2020'

SELECT  * FROM    plt_image..scan where image_id = 13583148
SELECT  * FROM    plt_image..scandocumenttype WHERE type_id = 32

Intelex
---------------

Some basic assumptions...
1. We only return information from work orders.
2. 



*/

/*
--- Debuggery
declare @web_userid varchar(100) = 'use@costco.com'
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
	values ('(' + convert(varchar(10), @@spid) + ') exec sp_COR_Costco_Intelex_Waste_Supporting_Documentation_list ''' + @i_web_userid + ''', ''' + convert(varchar(40), @start_date, 121) + ''', ''' + convert(varchar(40), @end_date, 121) + '''')

select top 1 @placeholder_url = config_value 
from plt_ai..Configuration 
WHERE config_key = 'sp_COR_Costco_Intelex Image URL'

	insert plt_export..work_Intelex_Costco_Log (log_message)
	values ('(' + convert(varchar(10), @@spid) + ') sp_COR_Costco_Intelex_Waste_Supporting_Documentation_list url target: ' + @placeholder_url)

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

truncate table plt_export.dbo.work_Intelex_Costco_Supporting_Documentation_list

insert plt_export.dbo.work_Intelex_Costco_Supporting_Documentation_list
(
	[Unique Service No.]			,
	[Unique Manifest Identifier]	,
	[Manifest]						,
	[Ref No]						,
	[Title]							,
	[Type]							,
	[Sub Type] 						,
	[Category]						,
	[Date Received]					,
	[Documentation File]			
)
select distinct 
	[Unique Service No.]
	, [Unique Manifest Identifier]
	, [Manifest]
	, [Ref No]
	, [Title]
	, [Type]
	, [Sub Type]
	, [Category]
	, [Date Received]
	, [Documentation File] = @placeholder_url + dbo.fn_cor2_image_id_encrypt(image_id)
from (

select
--	[Waste Location] = convert(varchar(20), b.generator_id)
	/*
	Short version of location code. Waste hauler to provide value. Intelex to import value into a text field. This is not the Intelex location code, it is the vendor’s location ID	
	8	
	Text	
	N
	Generator.generator_id
	*/
	[Unique Service No.] = 
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

	, [Unique Manifest Identifier] = 
		case when sdt.document_type like '%manifest%' or sdt.document_type like '%bol%' then
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
		else '' end
				
	, [Manifest] = '' --b.manifest
	
	, [Ref No] = s.image_id
	
	, [Title] = s.document_name
	
	, [Type] = sdt.document_type

	, [Sub Type] = case when sdt.document_type like '%initial%' then 'Initial' else 'Final' end
	
	, [Category] = ''
	
	, [Date Received] = convert(date, s.upload_date)

/*
-- no encrypted url:	
	, [Documentation File] = @placeholder_url + convert(varchar(20), s.image_id)

-- encrypted url:
*/
	-- , [Documentation File] = @placeholder_url + dbo.fn_cor2_image_id_encrypt( s.image_id)
	 , s.image_id
	

from #intelex_source b
join plt_image..scan s (nolock)
	on s.receipt_id = b.receipt_id
	and s.company_id = b.company_id
	and s.profit_ctr_id = b.profit_ctr_id
	and s.status = 'A'
	and s.document_source = 'receipt'
	and s.view_on_web = 'T'
join plt_image..Scandocumenttype sdt (nolock)
	on s.type_id = sdt.type_id
	and sdt.document_type not like '%manifest%' -- 8/10/21 - exclude manifests since they'll have direct urls
	and sdt.document_type not like '%bol%'
where b.trans_source = 'R'


union

select
	-- [Waste Location] = convert(varchar(20), b.generator_id)
	/*
	Short version of location code. Waste hauler to provide value. Intelex to import value into a text field. This is not the Intelex location code, it is the vendor’s location ID	
	8	
	Text	
	N
	Generator.generator_id
	*/
	[Unique Service No.] = 
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

	, [Unique Manifest Identifier] = 
		case when sdt.document_type like '%manifest%' or sdt.document_type like '%bol%' then
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
		else '' end

	, [Manifest] = '' --b.manifest
	
	, [Ref No] = s.image_id
	
	, [Title] = s.document_name
	
	, [Type] = sdt.document_type

	, [Sub Type] = case when sdt.document_type like '%initial%' then 'Initial' else 'Final' end
	
	, [Category] = ''
	
	, [Date Received] = convert(date, s.upload_date)

/*
-- no encrypted url:	
	, [Documentation File] = @placeholder_url + convert(varchar(20), s.image_id)

-- encrypted url:
*/
	--, [Documentation File] = @placeholder_url + dbo.fn_cor2_image_id_encrypt( s.image_id)
	, s.image_id

from #intelex_source b
join plt_image..scan s (nolock)
	on s.workorder_id = b.receipt_id
	and s.company_id = b.company_id
	and s.profit_ctr_id = b.profit_ctr_id
	and s.status = 'A'
	and s.document_source = 'workorder'
	and s.view_on_web = 'T'
join plt_image..Scandocumenttype sdt (nolock)
	on s.type_id = sdt.type_id
	and sdt.document_type not like '%manifest%' -- 8/10/21 - exclude manifests since they'll have direct urls
	and sdt.document_type not like '%BOL%'
where b.trans_source = 'W'
) x

ORDER BY [Unique Service No.], [Manifest], [Ref No]


	insert plt_export..work_Intelex_Costco_Log (log_message)
	values ('(' + convert(varchar(10), @@spid) + ') sp_COR_Costco_Intelex_Waste_Supporting_Documentation_list populated plt_export.dbo.work_Intelex_Costco_Supporting_Documentation_list with ' + convert(varchar(10), @@rowcount) + ' rows and finished')

go

grant execute on sp_COR_Costco_Intelex_Waste_Supporting_Documentation_list
to cor_user
go

grant execute on sp_COR_Costco_Intelex_Waste_Supporting_Documentation_list
to eqai
go

grant execute on sp_COR_Costco_Intelex_Waste_Supporting_Documentation_list
to eqweb
go

grant execute on sp_COR_Costco_Intelex_Waste_Supporting_Documentation_list
to CRM_Service
go

grant execute on sp_COR_Costco_Intelex_Waste_Supporting_Documentation_list
to DATATEAM_SVC
go

