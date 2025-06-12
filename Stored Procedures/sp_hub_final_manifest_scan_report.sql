-- drop proc if exists sp_hub_final_manifest_scan_report
go

create proc sp_hub_final_manifest_scan_report (
	@customer_id int	
	, @start_date_start	datetime 
	, @start_date_end	datetime 
	, @days_past_service_date int = 0
)
as
/* *******************************************************************
sp_hub_final_manifest_scan_report

	Returns data on transactions where the scans for a manifest are not
	created/available X days after the transaction service date


	-- FL scan 71 days past service date:
	SELECT  *  FROM    billinglinklookup WHERE source_id = 10376100 and source_company_id = 15 and source_profit_ctr_id = 0

	SELECT  *  FROM    receipt WHERE receipt_id = 271481 and company_id = 22
	SELECT  *  FROM    receipt WHERE receipt_id = 153867 and company_id = 27

	SELECT  *  FROM    plt_image..scan WHERE receipt_id = 271481 and company_id = 22
	SELECT  *  FROM    plt_image..scan WHERE receipt_id = 153867 and company_id = 27


	-- IL scan not appearing:
	SELECT  *  FROM    billinglinklookup WHERE source_id = 10021900 and source_company_id = 15 and source_profit_ctr_id = 4

	SELECT  *  FROM    receipt WHERE receipt_id = 158338 and company_id = 27
	SELECT  *  FROM    receipt WHERE receipt_id = 102238 and company_id = 26

	SELECT  *  FROM    plt_image..scan WHERE receipt_id = 158338 and company_id = 27
	SELECT  *  FROM    plt_image..scan WHERE receipt_id = 102238 and company_id = 26


sp_hub_final_manifest_scan_report
	@customer_id  = 15622
	, @start_date_start	 = '7/1/2019'
	, @start_date_end	 = '12/31/2019 23:59'
	, @days_past_service_date  = 10
	
******************************************************************* */
if object_id('tempdb..#foo') is not null drop table #foo
if object_id('tempdb..#bar') is not null drop table #bar
if object_id('tempdb..#rex') is not null drop table #rex

/*
declare @customer_id int		= 15622
	, @start_date_start	datetime = '7/1/2019'
	, @start_date_end	datetime = '12/31/2019 23:59'
	, @days_past_service_date int = 10
*/

select distinct
	h.company_id
	, h.profit_ctr_id
	, h.workorder_id
	, h.trip_id
	, m.manifest
	, tsdf.tsdf_code
	, tsdf.tsdf_name
	, tsdf.tsdf_epa_id
	, g.generator_name
	, g.epa_id
	, g.site_code
	, g.site_type
	, coalesce(m.generator_sign_date, s.date_act_arrive, h.start_date) service_date
	, bll.receipt_id
	, bll.company_id receipt_company_id
	, bll.profit_ctr_id receipt_profit_ctr_id
into #foo
from workorderheader h
join workorderdetail d
	on h.workorder_id = d.workorder_id
	and h.company_id = d.company_id
	and h.profit_ctr_id = d.profit_ctr_id
	and d.resource_type = 'D'
	and d.bill_rate > -2
join tsdf
	on d.tsdf_code = tsdf.tsdf_code
join generator g
	on h.generator_id = g.generator_id
join workordermanifest m
	on h.workorder_id = m.workorder_id
	and h.company_id = m.company_id
	and h.profit_ctr_id = m.profit_ctr_id
	and d.manifest = m.manifest
	and m.manifest_flag = 'T'
	and m.manifest not like '%manifest%'
	and m.manifest_state like '%H%'
left join billinglinklookup bll
	on m.workorder_id = bll.source_id
	and m.company_id = bll.source_company_id
	and m.profit_ctr_id = bll.source_profit_ctr_id
	and tsdf.eq_company = bll.company_id
	and tsdf.eq_profit_ctr = bll.profit_ctr_id
left join receipt r
	on bll.receipt_id = r.receipt_id
	and bll.company_id = r.company_id
	and bll.profit_ctr_id = r.profit_ctr_id
	and m.manifest = r.manifest
	and r.receipt_status not in ('V', 'R')
--	and r.fingerpr_status = 'A'
	and r.trans_mode = 'I'
	and r.trans_type = 'D'
left join workorderstop s
	on h.workorder_id = s.workorder_id
	and h.company_id = s.company_id
	and h.profit_ctr_id = s.profit_ctr_id
WHERE h.customer_id = @customer_id
and h.start_date >= @start_date_start
and h.start_date <= @start_date_end
and h.workorder_status not in ('X', 'V')

-- SELECT  *  FROM    #foo
-- SELECT  *  FROM    #foo WHERE workorder_id = 9892200

select 
	f.company_id
	, f.profit_ctr_id
	, f.workorder_id
	, 'Receipt' as trans_source
	, f.manifest
	, f.receipt_id
	, f.receipt_company_id
	, f.receipt_profit_ctr_id
	, min(s.image_id) min_image_id
	, max(s.image_id) max_image_id
	, min(s.status) min_status
	, max(s.status) max_status
	, min(s.view_on_web) min_s_view_on_web
	, max(s.view_on_web) max_s_view_on_web
	, min(sdt.view_on_web) min_sdt_view_on_web
	, max(sdt.view_on_web) max_sdt_view_on_web
	, min(s.date_added) min_s_date_added
	, max(s.date_added) max_s_date_added
into #bar
from #foo f
join plt_image..scan s
	on f.receipt_id = s.receipt_id
	and f.receipt_company_id = s.company_id
	and f.receipt_profit_ctr_id = s.profit_ctr_id
	and s.document_source = 'receipt'
	and s.view_on_web in ('A', 'T')
join plt_image..scandocumenttype sdt
	on s.type_id = sdt.type_id
	and sdt.document_type like '%manifest%'
	and sdt.document_type not like '%initial%'
	and sdt.view_on_web in ('A', 'T')
join plt_image..scanimage si on s.image_id = si.image_id
WHERE 1=1
-- and s.status <> 'V'
GROUP BY 
	f.company_id
	, f.profit_ctr_id
	, f.workorder_id
	, f.manifest
	, f.receipt_id
	, f.receipt_company_id
	, f.receipt_profit_ctr_id
UNION
select 
	f.company_id
	, f.profit_ctr_id
	, f.workorder_id
	, 'Workorder' as trans_source
	, f.manifest
	, null receipt_id
	, null receipt_company_id
	, null receipt_profit_ctr_id
	, min(s.image_id) min_image_id
	, max(s.image_id) max_image_id
	, min(s.status) min_status
	, max(s.status) max_status
	, min(s.view_on_web) min_s_view_on_web
	, max(s.view_on_web) max_s_view_on_web
	, min(sdt.view_on_web) min_sdt_view_on_web
	, max(sdt.view_on_web) max_sdt_view_on_web
	, min(s.date_added) min_s_date_added
	, max(s.date_added) max_s_date_added
from #foo f
join plt_image..scan s
	on f.workorder_id = s.workorder_id
	and f.company_id = s.company_id
	and f.profit_ctr_id = s.profit_ctr_id
	and s.document_source = 'workorder'
	and s.view_on_web in ('A', 'T')
join plt_image..scandocumenttype sdt
	on s.type_id = sdt.type_id
	and sdt.document_type like '%manifest%'
	and sdt.document_type not like '%initial%'
	and sdt.view_on_web in ('A', 'T')
join plt_image..scanimage si on s.image_id = si.image_id
WHERE 
1=1 -- disable this section - "leave work orders out for now" - Mara
-- AND s.status <> 'V' -- per 
AND f.receipt_id is null
GROUP BY 
	f.company_id
	, f.profit_ctr_id
	, f.workorder_id
	, f.manifest
	
-- SELECT  *  FROM    #FOO WHERE workorder_id = 9892200
-- SELECT  *  FROM    #bar WHERE workorder_id = 9892200


select
	f.company_id
	, f.profit_ctr_id
	, f.workorder_id
	, f.trip_id
	, f.service_date
	, case when b.min_image_id is not null then 'T' else 'F' end scan_exists
	, b.min_s_date_added scan_added_date
	, case when b.max_s_view_on_web = b.max_sdt_view_on_web and b.max_sdt_view_on_web = 'T' then 'T' else 'F' end view_on_web
	, f.manifest
	, b.trans_source
	-- , f.tsdf_code
	, f.tsdf_name
	, f.tsdf_epa_id
	, f.generator_name
	, f.epa_id generator_epa_id
	, f.site_code
	, f.site_type
	, datediff(d, f.service_date, isnull(b.min_s_date_added, getdate())) days_past_service_date
	--, b.max_s_date_added
	--, f.service_date
	--Number of Days Past Service Date (Scan.date_added - Work Order / Manifest Service Date)  * If the scan is not added, it should be today's date - Service date.
into #rex
from #foo f
left join #bar b	
	on f.workorder_id = b.workorder_id
	and f.company_id = b.company_id
	and f.profit_ctr_id = b.profit_ctr_id
	and f.manifest = b.manifest
	and isnull(f.receipt_id, 0) = isnull(b.receipt_id, 0)
	and isnull(f.receipt_company_id, 0) = isnull(b.receipt_company_id, 0)
	and isnull(f.receipt_profit_ctr_id, 0) = isnull(b.receipt_profit_ctr_id, 0)


SELECT distinct * from #rex 
WHERE days_past_service_date > @days_past_service_date

GO

GRANT EXECUTE ON sp_hub_final_manifest_scan_report to eqweb
GO
