drop proc if exists sp_COR_Intelex_Source
go

create proc sp_COR_Intelex_Source
	@web_userid		varchar(100)
	, @start_date		datetime
	, @end_date		datetime
as

/*
sp_COR_Intelex_Source

Creates table of source data for reporting.  Standardizes conditions & logic

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
	@web_userid		= 'svc_cvs_intelex'
	, @start_date	= '1/1/2021'
	, @end_date		= '7/1/2021'
	
SELECT  * FROM    #source ORDER BY service_date
-- with wodu included, 1987 rows.
-- with wodu commented, 2016 rows.  
Not a big difference.

SELECT  distinct h.workorder_id, h.company_id, h.profit_ctr_id
FROM    workorderheader h
join workorderdetail d on h.workorder_id = d.workorder_id
and h.company_id = d.company_id and h.profit_ctr_id = d.profit_ctr_id
where h.customer_id = 13212
and h.start_date > '1/1/2021'
and d.manifest not like '%manifest%' and d.bill_rate >= -1
and d.tsdf_code not in (select tsdf_code from tsdf where eq_flag = 'T')
and d.workorder_id not in (select receipt_id from #source)


SELECT  * FROM    workorderdetail WHERE workorder_id = 2080500 and company_id = 47 and profit_ctr_id = 0
and sequence_id =1 and resource_type = 'D'	
SELECT  * FROM    workorderdetailunit WHERE workorder_id = 2080500 and company_id = 47 and profit_ctr_id = 0
 	and isnull(quantity, -1) > -1

SELECT  * FROM    workorderdetail WHERE workorder_id = 2080400 and company_id = 47 and profit_ctr_id = 0
and sequence_id =1 and resource_type = 'D'	
SELECT  * FROM    workorderdetailunit WHERE workorder_id = 2080400 and company_id = 47 and profit_ctr_id = 0
 	and isnull(quantity, -1) > -1


sp_COR_Intelex_Manifest_Line_list @web_userid = 'svc_cvs_intelex'
	, @start_date  = '1/1/2021'
	, @end_date	 = '7/1/2021'
-- wodu requirement in: 2113 rows
-- wodu requirement out: 2142 rows



truncate table #source

insert #Source
Exec sp_COR_Intelex_Source
	@web_userid		= 'use@costco.com'
	, @start_date	= '1/1/2022'
	, @end_date		= '12/31/2022'

SELECT  * FROM    #source
-- 8677 2:24 in SP
-- 8677 45s below.

6/30/2021 - 21868 CVS/Intelex WorkorderDetailUnit bugfix - quit inner-joining to workorderdetailunit.
2/02/2023 - 61399 Costco Intelex speed/inclusion fixes

*/

/*
--- Debuggery
declare
	@web_userid		varchar(100) = 'use@costco.com'
	, @start_date		datetime = '1/1/2022'
	, @end_date		datetime = '12/31/2022'

--drop table if exists #Source
*/
truncate table #Source

declare 
	@i_web_userid		varchar(100)	= isnull(@web_userid, '')
	, @i_start_date		datetime		= coalesce(@start_date, convert(date,getdate()-7))
	, @i_end_date		datetime		= coalesce(@end_date, @start_date+7, convert(date, getdate()))
	, @i_contact_id		int

select top 1 @i_contact_id = contact_id from Contact WHERE web_userid = @i_web_userid

declare @rbucketid table (ContactCORReceiptBucket_UID bigint)

insert @rbucketid
SELECT  rb.ContactCORReceiptBucket_UID FROM    ContactCORReceiptBucket rb
WHERE  rb.contact_id = @i_contact_id
and rb.receipt_date between @i_start_date and @i_end_date
union 
SELECT  rb.ContactCORReceiptBucket_UID FROM    ContactCORReceiptBucket rb
WHERE  rb.contact_id = @i_contact_id
and rb.pickup_date between @i_start_date and @i_end_date
union 
SELECT  rb.ContactCORReceiptBucket_UID FROM    ContactCORReceiptBucket rb
join Receipt r on rb.receipt_id = r.receipt_id and rb.company_id = r.company_id and rb.profit_ctr_id = r.profit_ctr_id
WHERE  rb.contact_id = @i_contact_id
and r.date_added between @i_start_date and @i_end_date
union 
SELECT  rb.ContactCORReceiptBucket_UID FROM    ContactCORReceiptBucket rb
join Receipt r on rb.receipt_id = r.receipt_id and rb.company_id = r.company_id and rb.profit_ctr_id = r.profit_ctr_id
WHERE  rb.contact_id = @i_contact_id
and r.date_modified between @i_start_date and @i_end_date
union 
SELECT  rb.ContactCORReceiptBucket_UID FROM    ContactCORReceiptBucket rb
join ReceiptDetailItem r on rb.receipt_id = r.receipt_id and rb.company_id = r.company_id and rb.profit_ctr_id = r.profit_ctr_id
WHERE  rb.contact_id = @i_contact_id
and r.date_added between @i_start_date and @i_end_date
union 
SELECT  rb.ContactCORReceiptBucket_UID FROM    ContactCORReceiptBucket rb
join ReceiptDetailItem r on rb.receipt_id = r.receipt_id and rb.company_id = r.company_id and rb.profit_ctr_id = r.profit_ctr_id
WHERE  rb.contact_id = @i_contact_id
and r.date_modified between @i_start_date and @i_end_date
union 
SELECT  rb.ContactCORReceiptBucket_UID FROM    ContactCORReceiptBucket rb
join ReceiptManifest r on rb.receipt_id = r.receipt_id and rb.company_id = r.company_id and rb.profit_ctr_id = r.profit_ctr_id
WHERE  rb.contact_id = @i_contact_id
and r.date_added between @i_start_date and @i_end_date
union 
SELECT  rb.ContactCORReceiptBucket_UID FROM    ContactCORReceiptBucket rb
join ReceiptManifest r on rb.receipt_id = r.receipt_id and rb.company_id = r.company_id and rb.profit_ctr_id = r.profit_ctr_id
WHERE  rb.contact_id = @i_contact_id
and r.date_modified between @i_start_date and @i_end_date
union 
SELECT  rb.ContactCORReceiptBucket_UID FROM    ContactCORReceiptBucket rb
join Plt_Image..Scan s on rb.receipt_id = s.receipt_id and rb.company_id = s.company_id and rb.profit_ctr_id = s.profit_ctr_id
and s.document_source = 'Receipt'
WHERE  rb.contact_id = @i_contact_id
and s.date_added between @i_start_date and @i_end_date
union 
SELECT  rb.ContactCORReceiptBucket_UID FROM    ContactCORReceiptBucket rb
join Plt_Image..Scan s on rb.receipt_id = s.receipt_id and rb.company_id = s.company_id and rb.profit_ctr_id = s.profit_ctr_id
and s.document_source = 'Receipt'
WHERE  rb.contact_id = @i_contact_id
and s.date_modified between @i_start_date and @i_end_date
union 
SELECT  rb.ContactCORReceiptBucket_UID FROM    ContactCORReceiptBucket rb
join Plt_Image..Scan s on rb.receipt_id = s.receipt_id and rb.company_id = s.company_id and rb.profit_ctr_id = s.profit_ctr_id
and s.document_source = 'Receipt'
WHERE  rb.contact_id = @i_contact_id
and s.upload_date between @i_start_date and @i_end_date

declare @wbucketid table (ContactCORWorkOrderHeaderBucket_uid bigint)

insert @wbucketid
SELECT  wb.ContactCORWorkOrderHeaderBucket_uid FROM    ContactCORWorkOrderHeaderBucket wb
WHERE  wb.contact_id = @i_contact_id
and wb.start_date between @i_start_date and @i_end_date
union 
SELECT  wb.ContactCORWorkOrderHeaderBucket_uid FROM    ContactCORWorkOrderHeaderBucket wb
WHERE  wb.contact_id = @i_contact_id
and wb.service_date between @i_start_date and @i_end_date
union 
SELECT  wb.ContactCORWorkOrderHeaderBucket_uid FROM    ContactCORWorkOrderHeaderBucket wb
join WorkorderHeader w on wb.workorder_id = w.workorder_id and wb.company_id = w.company_id and wb.profit_ctr_id = w.profit_ctr_id
WHERE  wb.contact_id = @i_contact_id
and w.end_date between @i_start_date and @i_end_date
union 
SELECT  wb.ContactCORWorkOrderHeaderBucket_uid FROM    ContactCORWorkOrderHeaderBucket wb
join WorkorderHeader w on wb.workorder_id = w.workorder_id and wb.company_id = w.company_id and wb.profit_ctr_id = w.profit_ctr_id
WHERE  wb.contact_id = @i_contact_id
and w.date_added between @i_start_date and @i_end_date
union 
SELECT  wb.ContactCORWorkOrderHeaderBucket_uid FROM    ContactCORWorkOrderHeaderBucket wb
join WorkorderHeader w on wb.workorder_id = w.workorder_id and wb.company_id = w.company_id and wb.profit_ctr_id = w.profit_ctr_id
WHERE  wb.contact_id = @i_contact_id
and w.date_modified between @i_start_date and @i_end_date
union 
SELECT  wb.ContactCORWorkOrderHeaderBucket_uid FROM    ContactCORWorkOrderHeaderBucket wb
join WorkorderDetail w on wb.workorder_id = w.workorder_id and wb.company_id = w.company_id and wb.profit_ctr_id = w.profit_ctr_id
WHERE  wb.contact_id = @i_contact_id
and w.date_added between @i_start_date and @i_end_date
union 
SELECT  wb.ContactCORWorkOrderHeaderBucket_uid FROM    ContactCORWorkOrderHeaderBucket wb
join WorkorderDetail w on wb.workorder_id = w.workorder_id and wb.company_id = w.company_id and wb.profit_ctr_id = w.profit_ctr_id
WHERE  wb.contact_id = @i_contact_id
and w.date_modified between @i_start_date and @i_end_date
union 
SELECT  wb.ContactCORWorkOrderHeaderBucket_uid FROM    ContactCORWorkOrderHeaderBucket wb
join WorkorderDetailUnit w on wb.workorder_id = w.workorder_id and wb.company_id = w.company_id and wb.profit_ctr_id = w.profit_ctr_id
WHERE  wb.contact_id = @i_contact_id
and w.date_added between @i_start_date and @i_end_date
union 
SELECT  wb.ContactCORWorkOrderHeaderBucket_uid FROM    ContactCORWorkOrderHeaderBucket wb
join WorkorderDetailUnit w on wb.workorder_id = w.workorder_id and wb.company_id = w.company_id and wb.profit_ctr_id = w.profit_ctr_id
WHERE  wb.contact_id = @i_contact_id
and w.date_modified between @i_start_date and @i_end_date
union 
SELECT  wb.ContactCORWorkOrderHeaderBucket_uid FROM    ContactCORWorkOrderHeaderBucket wb
join WorkorderManifest w on wb.workorder_id = w.workorder_id and wb.company_id = w.company_id and wb.profit_ctr_id = w.profit_ctr_id
WHERE  wb.contact_id = @i_contact_id
and w.date_added between @i_start_date and @i_end_date
union 
SELECT  wb.ContactCORWorkOrderHeaderBucket_uid FROM    ContactCORWorkOrderHeaderBucket wb
join WorkorderManifest w on wb.workorder_id = w.workorder_id and wb.company_id = w.company_id and wb.profit_ctr_id = w.profit_ctr_id
WHERE  wb.contact_id = @i_contact_id
and w.date_modified between @i_start_date and @i_end_date
union 
SELECT  wb.ContactCORWorkOrderHeaderBucket_uid FROM    ContactCORWorkOrderHeaderBucket wb
join Plt_Image..Scan s on wb.workorder_id = s.workorder_id and wb.company_id = s.company_id and wb.profit_ctr_id = s.profit_ctr_id
and s.document_source = 'Workorder'
WHERE  wb.contact_id = @i_contact_id
and s.date_added between @i_start_date and @i_end_date
union 
SELECT  wb.ContactCORWorkOrderHeaderBucket_uid FROM    ContactCORWorkOrderHeaderBucket wb
join Plt_Image..Scan s on wb.workorder_id = s.workorder_id and wb.company_id = s.company_id and wb.profit_ctr_id = s.profit_ctr_id
and s.document_source = 'Workorder'
WHERE  wb.contact_id = @i_contact_id
and s.date_modified between @i_start_date and @i_end_date
union 
SELECT  wb.ContactCORWorkOrderHeaderBucket_uid FROM    ContactCORWorkOrderHeaderBucket wb
join Plt_Image..Scan s on wb.workorder_id = s.workorder_id and wb.company_id = s.company_id and wb.profit_ctr_id = s.profit_ctr_id
and s.document_source = 'Workorder'
WHERE  wb.contact_id = @i_contact_id
and s.upload_date between @i_start_date and @i_end_date

declare @src table (
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
)
select distinct
	'R' as trans_source
	, r.receipt_id
	, r.company_id
	, r.profit_ctr_id
	, r.manifest
	, r.generator_id
	, coalesce(b.pickup_date, b.receipt_date) as service_date
	, convert(int, null) as workorder_id
	, convert(int, null) as workorder_company_id
	, convert(int, null) as workorder_profit_ctr_id
from Receipt r (nolock)
join ContactCORReceiptBucket b
	on b.receipt_id = r.receipt_id
	and b.company_id = r.company_id
	and b.profit_ctr_id = r.profit_ctr_id
WHERE b.ContactCORReceiptBucket_uid in (select ContactCORReceiptBucket_uid from @rbucketid)
and r.receipt_status NOT IN ('V', 'R') 
AND r.trans_mode = 'I' 
AND r.trans_type = 'D' 
AND r.fingerpr_status = 'A' 

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
)
select distinct
	'R' as trans_source
	, r.receipt_id
	, r.company_id
	, r.profit_ctr_id
	, r.manifest
	, r.generator_id
	, coalesce(rb.pickup_date, rb.receipt_date) as service_date
	, b.workorder_id
	, b.company_id as workorder_company_id
	, b.profit_ctr_id as workorder_profit_ctr_id
from ContactCORWorkorderHeaderBucket b (nolock)
join BillingLinkLookup bll (nolock)
	on b.workorder_id = bll.source_id
	and b.company_id = bll.source_company_id
	and b.profit_ctr_id = bll.source_profit_ctr_id
join ContactCORReceiptBucket rb (nolock)
	on bll.receipt_id = rb.receipt_id
	and bll.company_id = rb.company_id
	and bll.profit_ctr_id = rb.profit_ctr_id
join Receipt r (nolock)
	on bll.receipt_id = r.receipt_id
	and bll.company_id = r.company_id
	and bll.profit_ctr_id = r.profit_ctr_id
WHERE b.ContactCORWorkorderHeaderBucket_uid in (select ContactCORWorkorderHeaderBucket_uid from @wbucketid)
and r.receipt_status NOT IN ('V', 'R') 
AND r.trans_mode = 'I' 
AND r.trans_type = 'D' 
AND r.fingerpr_status = 'A' 

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
)
select distinct
	'W' as trans_source
	, h.workorder_id
	, h.company_id
	, h.profit_ctr_id
	, d.manifest
	, h.generator_id
	, b.service_date
	, null
	, null
	, null
from workorderheader h (nolock)
join ContactCORWorkorderHeaderBucket b (nolock)
	on b.workorder_id = h.workorder_id
	and b.company_id = h.company_id
	and b.profit_ctr_id = h.profit_ctr_id
join workorderdetail d (nolock)
	on b.workorder_id = d.workorder_id
	and b.company_id = d.company_id
	and b.profit_ctr_id = d.profit_ctr_id
	and d.resource_type = 'D'
	and d.bill_rate >= -1
	and d.manifest not like '%manifest%'
join workordermanifest m (nolock)
	on m.workorder_id = d.workorder_id
	and m.company_id = d.company_id
	and m.profit_ctr_id = d.profit_ctr_id
	and m.manifest = d.manifest
WHERE b.ContactCORWorkorderHeaderBucket_UID in (select ContactCORWorkorderHeaderBucket_UID from @wbucketid)
and d.manifest not in (select manifest from @src)
and h.workorder_id is not null and h.company_id is not null and h.profit_ctr_id is not null
and h.workorder_status NOT IN ('V','X','T')
--and m.manifest_flag = 'T'
--and m.manifest_state like '%H%'
and not exists (select 1 from @src where workorder_id = b.workorder_id
	and workorder_company_id = b.company_id
	and workorder_profit_ctr_id = b.profit_ctr_id)



-- Just Receipt, Work Order, only LJ to Scan: 

update s set
	workorder_id = b.source_id
	,workorder_company_id = b.source_company_id
	, workorder_profit_ctr_id = b.source_profit_ctr_id
from @src s
join billinglinklookup b
on s.receipt_id = b.receipt_id
and s.company_id = b.company_id
and s.profit_ctr_id= b.profit_ctr_id
WHERE s.trans_source = 'R'


insert #Source
(
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
)

select distinct
	b.*
from @src b

go

grant execute on sp_COR_Intelex_Source
to cor_user
go

grant execute on sp_COR_Intelex_Source
to eqai
go

grant execute on sp_COR_Intelex_Source
to eqweb
go

grant execute on sp_COR_Intelex_Source
to CRM_Service
go

grant execute on sp_COR_Intelex_Source
to DATATEAM_SVC
go
