-- drop proc if exists sp_eqip_incomplete_workorder_disposal_report
go

CREATE PROC sp_eqip_incomplete_workorder_disposal_report (
	@customer_id	varchar(max) -- required list of customer_id's
	, @generator_id	varchar(max) = null -- optional list of generator_id's or null
	, @workorder_id	varchar(max) = null -- list of workorder_id's
	, @invoice_code	varchar(max) = null -- list of invoice_code
	, @date_option			char(1) = 'S' -- 'S'ervice or 'I'nvoice
	, @start_date	datetime = null-- Trip Arrive or else Start date begin
	, @end_date		datetime = null -- Trip Arrive or else Start date end
	, @resource_type_list	varchar(100) = NULL -- Distinct set of WorkOrderDetail.Resource_Type
	, @billing_status_list	varchar(100) = NULL -- Unsubmitted, Submitted, Invoiced
) AS
/* ******************************************************************
sp_eqip_incomplete_workorder_disposal_report

Amazon Work Order Information Report.  Generic for any customer.

History

	2014-07-29	JPB	Created
	2015-10-08	JPB	GEM-33271
					Work Order Type column now populates
					Added sort by co, pc, trip id
					Added manifest #
					Total billed per line is added
					Unit Price & Billed Total are money types in ssrs report
	2015-11-05	JPB	Notes:
					Add Param for submitted/not
					Add resource type option filter 
	2016-03-01	JPB	Changed how pricing is pulled. Comes from WorkOrderDetailUnit (Billing record) now
					This is because the Profile/TSDFApproval Pricing definitely DOES NOT include surcharges etc and is wrong.
	2016-03-30	JPB	A change to the last change: Pricing can come from WODU(B) IF it exists, but on Manifest-Only lines,
					it doesn't.  And if those lines aren't billed (the common use case for Amazon) the profile is the only
					place to go for pricing. AND there's not a function that grabs a complete profile price.		Crazy.
					So now we check for WODU_B price, or else go back to Profile/TSDFApproval price. Not great, but acceptable.
					To indicate we KNOW it's not great, we're returning a new column: price_source to show a line on the SSRS
					output when it's not a great price source.
	2016-04-14	JPB	GEM-37088 - Allow running for multiple customer id's.
					GEM-37138 - Added waste code columns.
	2016-06-03	JPB	GEM-37624 - Add date_act_depart to output.
	2016-07-05	JPB	GEM-38289 - Add generator fields (region, division)
	2016-07-26	JPB	GEM-38751 - Service date changes
						Service Date column:  Adjust to use the following hierarchy:
							Use the work order date actual arrival date / time (if populated)
							Use the transporter 1 pick up / sign date (if populated)
								Join on work order company, profit center, work order ID and transporter sequence id = 1
							Else leave the field service date blank
						Add a column to display the transporter pick up / sign date
	2016-08-30 JPB	GEM-39139 - Add profile fields to Work Order Extract
						Hub:  WO Extract Report

						Add the following fields to the work order extract report:
							For Work Order Other charge lines, display the manifest and manifest line in the extract
							WO Disposal Lines û pull from either TSDFApproval or Profile depending on the approval type used

							Profile.Cust_prod_ID
							Profile.Cust_prod_type_ID
							Profile.Cust_disp_method_ID

							TSDFApproval.Cust_prod_ID
							TSDFApproval.Cust_prod_type_ID
							TSDFApproval.Cust_disp_method_ID
	2016-10-21 JPB	GEM-39941 - Add CustomerDisposalMethod.disp_method_abbr and rearrange SSRS columns.
	2017-01-06 JPB	GEM-40688 - Add sub-location and off-schedule-identifier from Trip info.
					GEM-40426 - Add generator_id filter (optional)
								Only return non-null value for Weight_Source when the line is actually a Disposal line.
	2017-02-28 JPB	GEM-42050 - Adjust service date logic
	2017-03-03 JPB	GEM-42011 - Added search criteria options for invoice date and workorder id list
	2017-03-03 JPB	GEM-42051 - Add additional fields for linked (Other) charges
	2017-03-07 JPB	GEM-40688 (again) - Also need to add OffScheduleReason
	2017-04-20 JPB  GEM-43226 - Bug where waste codes are returned for all resource types not just 'D'isposal.
	2018-01-05 JPB	GEM-47426 - Bug in join between BillingDetail & WorkOrderDetail - 1 wod line with multiple billing units
								was not getting the correct billingdetail sum (all lines, not just the bill unit match)
	
sp_helptext sp_eqip_incomplete_workorder_disposal_report

select top 100 workorder_id, company_id, profit_ctr_id, count(distinct manifest), count(distinct (transporter_sign_date))
from workordertransporter
where manifest not like 'manifest%'
group by 
workorder_id, company_id, profit_ctr_id
having count(distinct manifest) > 1
and count(distinct (transporter_sign_date)) > 1
order by count(distinct (transporter_sign_date)) desc

SELECT  *
FROM    workorderheader where workorder_id =4900700
 and profit_ctr_id = 9
SELECT  *
FROM    workordertransporter where workorder_id =4900700
 and profit_ctr_id = 9

Sample
sp_eqip_incomplete_workorder_disposal_report
	@customer_id	= '12263'
	, @generator_id = ''
	, @workorder_id = '5055329'
	, @invoice_code = ''
	, @date_option = 'S'
	, @resource_type_list	= 'L, E, S, O, D'
	, @billing_status_list	= 'USI'


	sp_eqip_incomplete_workorder_disposal_report
		@customer_id	= '14231'
		, @start_date	= '9/18/2016'
		, @end_date		= '9/24/2016'
		, @resource_type_list	= ''
		, @billing_status_list	= 'USI'
	-- 2106

	sp_eqip_incomplete_workorder_disposal_report --_jpb
		@customer_id	= '14231'
		, @start_date	= '9/18/2016'
		, @end_date		= '9/24/2016'
		, @resource_type_list	= 'L,E,S,O,D'
		, @billing_status_list	= 'USI'
	-- 1664

	sp_eqip_incomplete_workorder_disposal_report --_jpb
		@customer_id	= '150050'
		, @start_date	= '1/01/2017'
		, @end_date		= '3/24/2017'
		, @resource_type_list	= 'L,E,S,O,D'
		, @billing_status_list	= 'USI'
	-- 8441

select * from workorderdetail d
join workorderheader h on d.workorder_id = h.workorder_id and d.company_id = h.company_id and d.profit_ctr_id = h.profit_ctr_id
 where d.company_id = 15 and d.profit_ctr_id = 0 and d.resource_type = 'O' and d.manifest like '%jjk' and d.disposal_sequence_id is not null
and h.workorder_status <> 'V'
 
SELECT  *
FROM    workorderheader where workorder_id = 8633600 and company_id = 15

SELECT  *
FROM    billing
WHERE customer_id = 14231
and invoice_date between '9/18/2016' and '9/24/2016'

	
	sp_eqip_incomplete_workorder_disposal_report
		@customer_id	= '888880 '
		, @start_date	= '5/1/2000'
		, @end_date		= '6/5/2016'
		, @resource_type_list	= 'O, D, R, E, S'
		, @billing_status_list	= 'S,I'
		
	sp_eqip_incomplete_workorder_disposal_report
		@customer_id	= '15622,17762'
		, @start_date	= '11/1/2015'
		, @end_date		= '11/30/2015'
		, @resource_type_list	= 'D'
		, @billing_status_list	= 'USI'
		

select * from ResourceType
select distinct Resource_Type from WOrkOrderDetail

SELECT distinct TOP 10 h.* FROM WorkOrderDetail d 
join WorkorderHeader h on d.workorder_id = h.workorder_id and d.company_id = h.company_id and d.profit_ctr_id = h.profit_ctr_id
join Workorderdetail d2 on d.workorder_id = d2.workorder_id and d.company_id = d2.company_id and d.profit_ctr_id = d2.profit_ctr_id and d.disposal_sequence_id = d2.sequence_id and d2.resource_type = 'D'
join tsdfapproval t on d2.tsdf_approval_id = t.tsdf_approval_id and t.cust_prod_id is not null
where d.disposal_sequence_id is not null and h.workorder_id > 100 and h.submitted_flag = 'T' order by h.date_added desc

select * from tsdfapproval where cust_prod_id is not null

SELECT distinct TOP 10 h.* FROM WorkOrderDetail d 
join WorkorderHeader h on d.workorder_id = h.workorder_id and d.company_id = h.company_id and d.profit_ctr_id = h.profit_ctr_id
join Workorderdetail d2 on d.workorder_id = d2.workorder_id and d.company_id = d2.company_id and d.profit_ctr_id = d2.profit_ctr_id and d.disposal_sequence_id = d2.sequence_id and d2.resource_type = 'D'
join profile p on d2.profile_id = p.profile_id and p.cust_prod_id is not null
where d.disposal_sequence_id is not null and h.workorder_id > 100 and h.submitted_flag = 'T' order by h.date_added desc

select * from profile where cust_prod_id is not null
SELECT * FROM profilequoteapproval where approval_code = '12516200'

SELECT * FROM workorderdetail where profile_id in (343474, 539375)
and workorder_id = 12516200 

SELECT * FROM workorderheader WHERE workorder_id = 12516200 
		
SELECT  TOP 10 *
FROM    workorderheader wh
join workorderdetail wd on wh.workorder_id = wd.workorder_id
and wh.company_id  = wd.company_id
and wh.profit_ctr_id = wd.profit_ctr_id
where wd.resource_type = 'D'
and wh.submitted_flag = 'T'
and wd.bill_rate > 0
order by wh.date_added desc

5834, 6403, 10729, 13022

SELECT  *
FROM    workorderdetail
where workorder_id = 12517900
and company_id = 14
and profit_ctr_id = 0

SELECT  workorder_resource_Type, *
FROM    billing
where receipt_id in (12516100, 12516200, 12516300, 12516400, 12516500, 12516600, 12516700, 12516800, 12516900, 12517000, 12517100, 12517200, 12517300, 12517400, 12517500, 12517600, 12517700, 12517800, 12517900, 12518000, 12518100, 12518200, 12518300, 12518600, 12518700, 12518800, 12518900, 12519000, 12519100, 12519200, 12519400, 12519500, 12519600, 12519700, 12519800)
and company_id = 14
and profit_ctr_id = 0




				MIN(billing.invoice_code) as invoice_code
				, SUM( billingdetail.extended_amt ) extended_amt
				, MIN(billing.invoice_date) as invoice_date
			FROM   billing (nolock)
			JOIN	billingdetail
				on billing.billing_uid = billingdetail.billing_uid
			WHERE  12516100 = billing.receipt_id
				AND 0 = billing.profit_ctr_id
				AND 14 = billing.company_id
				and 'D' = billing.workorder_resource_type
				and d.sequence_id = billing.workorder_sequence_id
				AND billing.trans_source = 'W'


****************************************************************** */

set nocount on

-- drop table #src
-- declare 		@customer_id	varchar(max) = '13022, 888880'		, @start_date datetime	= '6/1/2015'		, @end_date	datetime	= '8/1/2015'

if @date_option not in ('S', 'I') set @date_option = 'S'

if @end_date is not null	
	if DATEPART(hh, @end_date) = 0
		set @end_date = @end_date + 0.99999

if object_id('tempdb..#customer') is not null
	drop table #customer
	
create table #customer (customer_id int)

insert #customer
select distinct convert(int, row)
from dbo.fn_splitxsvtext(',', 1, @customer_id)
where row is not null

if object_id('tempdb..#generator') is not null
	drop table #generator

create table #generator (generator_id int)

insert #generator
select distinct convert(int, row)
from dbo.fn_splitxsvtext(',', 1, @generator_id)
where row is not null

if object_id('tempdb..#workorderid') is not null
	drop table #workorderid
	
create table #workorderid (workorder_id int)

insert #workorderid
select distinct convert(int, row)
from dbo.fn_splitxsvtext(',', 1, @workorder_id)
where row is not null

create table #invoice (invoice_code varchar(16))

insert #invoice
select distinct row
from dbo.fn_splitxsvtext(',', 1, @invoice_code)
where row is not null


if object_id('tempdb..#ResourceTypeFilter') is not null
	drop table #ResourceTypeFilter

create table #ResourceTypeFilter (
	resource_type char(1)
)

insert #ResourceTypeFilter values ('H'), ('G') -- Fixed price and Group values always count.

insert #ResourceTypeFilter
select row from dbo.fn_SplitXsvText(',', 1, @resource_type_list)
where isnull(row, '') <> ''


if (select count(*) from #ResourceTypeFilter where resource_type not in ('H', 'G')) = 0
	insert #ResourceTypeFilter
	select resource_type from ResourceType
	where resource_type not in ('H', 'G')

if isnull(@billing_status_list, '') = '' set @billing_status_list = 'USI'

-- Billing Status handling
--	, @resource_type_list	varchar(100) -- Distinct set of WorkOrderDetail.Resource_Type
--	, @billing_status_list	varchar(100) -- 'U'nsubmitted, 'S'ubmitted, 'I'nvoiced
	

select distinct 
	h.workorder_id, h.company_id, h.profit_ctr_id, h.workorder_status, h.start_date, 
	h.customer_id, 
	h.generator_id, 
	h.invoice_date, 
	h.invoice_code,
	wos.date_act_arrive, 
	wos.date_act_depart, 
	wot.transporter_sign_date, 
	h.submitted_flag, 
	h.status_code as billing_status_code
into #src
from (
	select wh.workorder_id, wh.company_id, wh.profit_ctr_id, wh.workorder_status, wh.start_date, wh.customer_id, wh.generator_id, wh.submitted_flag, b.status_code, b.invoice_code, b.invoice_date
	from workorderheader wh (nolock)
	left join billing b (nolock)
		on wh.workorder_id = b.receipt_id
		and wh.company_id = b.company_id
		and wh.profit_ctr_id = b.profit_ctr_id
		-- and b.status_code = 'I'
		and b.invoice_code in (select invoice_code from #invoice union select b.invoice_code where 1 > (select count(invoice_code) from #invoice where invoice_code is not null))
	where wh.customer_id in (select customer_id from #customer)
	and wh.workorder_id in (select workorder_id from #workorderid union select wh.workorder_id where 1 > (select count(workorder_id) from #workorderid))
	and workorder_status in ( 'A', 'C', 'D', 'N', 'P', 'X' )
) h
left join 
(		
	-- This returns workorderstop date_act_depart, if any.
	select wh.workorder_id, wh.company_id, wh.profit_ctr_id, s.date_act_arrive, s.date_act_depart
	from 
	workorderheader wh
	join workorderstop s
		on wh.workorder_id = s.workorder_id
		and wh.company_id = s.company_id
		and wh.profit_ctr_id = s.profit_ctr_id
		where wh.customer_id in (select customer_id from #customer)
		and wh.workorder_id in (select workorder_id from #workorderid union select wh.workorder_id where 1 > (select count(workorder_id) from #workorderid))
		and wh.workorder_status in ( 'A', 'C', 'D', 'N', 'P', 'X' )
		and @date_option = 'S'
		and (
		(@start_date is null and @end_date is null and 1=0)
		or
		(@start_date is not null and @end_date is not null 
		and s.date_act_arrive between @start_date and @end_date)
	)
) wos
on h.workorder_id = wos.workorder_id
	and h.company_id = wos.company_id
	and h.profit_ctr_id = wos.profit_ctr_id
left join
(
	-- This returns transporter_sign_date PER MANIFEST, if any.
	select t.workorder_id, t.company_id, t.profit_ctr_id, min(t.transporter_sign_date) transporter_sign_date
	from workorderheader wh
	inner join workordertransporter t
		on wh.workorder_id = t.workorder_id
		and wh.company_id = t.company_id
		and wh.profit_ctr_id = t.profit_ctr_id
	inner join workorderdetail d
		on d.workorder_id = t.workorder_id
		and d.company_id = t.company_id
		and d.profit_ctr_id = t.profit_ctr_id
		and d.manifest = t.manifest
		and d.bill_rate > -2
	where wh.customer_id in (select customer_id from #customer)
	and wh.workorder_id in (select workorder_id from #workorderid union select wh.workorder_id where 1 > (select count(workorder_id) from #workorderid))
	and wh.workorder_status in ( 'A', 'C', 'D', 'N', 'P', 'X' )
	and (
		@date_option = 'S'
		and (@start_date is  null and @end_date is  null and 1=0)
		or
		(@start_date is not null and @end_date is not null 
		and t.transporter_sign_date between @start_date and @end_date)
	)
	and t.transporter_sequence_id = 1
	group by t.workorder_id, t.company_id, t.profit_ctr_id
) wot
on h.workorder_id = wot.workorder_id
	and h.company_id = wot.company_id
	and h.profit_ctr_id = wot.profit_ctr_id
where
	-- reinforce #customer limit
	h.customer_id in (select customer_id from #customer)
	-- reinforce #workorderid limit
	and h.workorder_id in (select workorder_id from #workorderid union select h.workorder_id where 1 > (select count(workorder_id) from #workorderid))
	-- reinforce #invoice limit
	and (
		(0 = (select count(invoice_code) from #invoice))
		or
		(0 < (select count(invoice_code) from #invoice) and h.invoice_code in (select invoice_code from #invoice))
	)
	and (
		(
			-- IF @service dates were given, limit by workorderstop.date_act_arrive, or else workordertransporter.transporter_sign_date (per manifest) or else header.start_date
			@date_option = 'S'
			and (
				@start_date is not null and @end_date is not null 
				and coalesce(wos.date_act_arrive, wot.transporter_sign_date, h.start_date) between @start_date and @end_date
			) or (
				@start_date is null and @end_date is null and 1=1
			)
		)
		or
		(
			-- ELSE IF @invoice dates were given, limit by header invoice_date
			@date_option = 'I'
			and (
				@start_date is not null and @end_date is not null 
				and h.invoice_date between @start_date and @end_date
			) or (
				@start_date is null and @end_date is null and 1=1
			)
		)
		-- if no dates were given, you get nothing. you lose. good day sir.
	)
	--AND generator.site_code = '1'
	and h.workorder_status IN ( 'A', 'C', 'D', 'N', 'P', 'X' )


-- Filter out rows that don't match the #generator filter
if 0 < (select count(*) from #generator)
	delete from #src where isnull(generator_id, -1) not in (select isnull(generator_id, -1) from #generator)

set nocount off

SELECT DISTINCT
    s.company_id,
    s.profit_ctr_id, -- AS profit_center_id,
    profitcenter.profit_ctr_name, -- AS profit_center_name,
    profitcenter.EPA_ID as profit_ctr_epa_id,

    s.customer_id,
    customer.cust_name AS customer_name, -- AS customer_name,
    customer.cust_city as customer_city,
    customer.cust_state as customer_state,
    
    cb.project_name,

	workorderheader.trip_id,
	workorderheader.trip_sequence_id,
	case tripheader.trip_status
		when 'A' then 'Arrived'
		when 'C' then 'Complete'
		when 'D' then 'Dispatched'
		when 'H' then 'Hold'
		when 'N' then 'New'
		when 'U' then 'Unloading'
		when 'V' then 'Void'
		else tripheader.trip_status
	end AS trip_status,

    s.workorder_id,
    workorderheader.start_date,
    workorderheader.end_date,
	coalesce(s.date_act_arrive, wot.transporter_sign_date, workorderheader.start_date) as service_date,
	s.date_act_arrive as arrive_date,
	s.date_act_depart as depart_date,
	wot.transporter_sign_date,
	case workorderheader.offschedule_service_flag
		WHEN 'T' then 'Off Schedule'
		ELSE ''
	end as Off_Schedule_Service,
	osr.reason_desc as Off_Schedule_Reason,

    CASE s.workorder_status
        WHEN 'N' THEN 'New'
        WHEN 'H' THEN 'On Hold'
        WHEN 'D' THEN 'Dispatched'
        WHEN 'C' THEN 'Complete'
        WHEN 'P' THEN 'Priced'
        WHEN 'A' THEN 'Accepted'
        WHEN 'X' THEN 'Submitted'
        ELSE ''
    END AS workorder_status,

    woth.account_desc as workorder_type,
    
    generator.generator_id,
    generator.epa_id, -- AS generator_epa_id,
    generator.generator_name,
    generator.site_code AS generator_site_code,
    generator.site_type AS generator_site_type,
    
    GeneratorSubLocation.code as Generator_Sublocation_Code,
    GeneratorSubLocation.description as Generator_Sublocation_Description,
    
	generator.generator_address_1 as 'Generator Address 1',
	generator.generator_address_2 as 'Generator Address 2',
	generator.generator_address_3 as 'Generator Address 3',
	generator.generator_zip_code as 'Generator Zip Code',
    generator.generator_city,
    county.county_name as generator_county,
    generator.generator_state,
    generator.generator_country,
    
    generator.generator_division,
    generator.generator_region_code,
    
    
    workorderheader.purchase_order,
    workorderheader.release_code,
    
    nullif( b.invoice_code, '' ) AS invoice_code,
    b.invoice_date,

	submitted_flag = CASE
			 WHEN workorderheader.submitted_flag = 'T' THEN 'Submitted'
			 ELSE 'Not Submitted'
		 END,

	case d.resource_type
		when 'd' then 'Disposal'
		when 'e' then 'Equipment'
		when 'l' then 'Labor'
		when 's' then 'Supplies'
		when 'o' then 'Other'
		else d.resource_type
	end as resource_type,

	d.sequence_id,
	d.manifest,
	d.manifest_line,
	d.quantity_used,
	d.resource_class_code,
	
/*
	reftsdf.tsdf_code ref_tsdf_code, -- referral line's tsdf_code
	reftsdf.tsdf_name ref_tsdf_name,
	reftsdf.tsdf_epa_id ref_tsdf_epa_id,
	reftsdf.tsdf_addr1 ref_tsdf_addr1,
	reftsdf.tsdf_addr2 ref_tsdf_addr2,
	reftsdf.tsdf_city ref_tsdf_city,
	reftsdf.tsdf_state ref_tsdf_state,
	reftsdf.tsdf_zip_code ref_tsdf_zip_code,
	coalesce(refTsdfApproval.tsdf_approval_id, refProfile.profile_id) as ref_tsdf_approval_id,
	refwd.tsdf_approval_code ref_tsdf_approval_code,
*/	
	
	coalesce(reftsdf.tsdf_code, d.tsdf_code) tsdf_code,
	coalesce(reftsdf.tsdf_name, t.tsdf_name) tsdf_name,
	coalesce(reftsdf.TSDF_EPA_ID, t.TSDF_EPA_ID) TSDF_EPA_ID,
	coalesce(reftsdf.tsdf_addr1, t.tsdf_addr1) tsdf_addr1,
	coalesce(reftsdf.tsdf_addr2, t.tsdf_addr2) tsdf_addr2,
	coalesce(reftsdf.tsdf_addr3, t.tsdf_addr3) tsdf_addr3,
	coalesce(reftsdf.tsdf_city, t.tsdf_city) tsdf_city,
	coalesce(reftsdf.tsdf_state, t.tsdf_state) tsdf_state,
	coalesce(reftsdf.tsdf_zip_code, t.tsdf_zip_code) tsdf_zip_code,
		
	coalesce(refTsdfApproval.tsdf_approval_id, refProfile.profile_id, d.tsdf_approval_id, d.profile_id) as tsdf_approval_id,
	coalesce(refwd.tsdf_approval_code, d.TSDF_approval_code) TSDF_approval_code,
	d.DESCRIPTION, -- as service_desc_1,
	d.description_2, -- as service_desc_2,

	(select cust_prod_desc from CustomerByProductIndex where cust_prod_id = 
		coalesce(p.Cust_prod_ID, ta.Cust_prod_ID, refProfile.Cust_prod_ID, refTsdfApproval.Cust_prod_ID)) as Cust_Prod_ID,
	(select type_Desc from CustomerByProductIndexType where type_id = 
		coalesce(p.Cust_prod_type_ID, ta.Cust_prod_type_id, refProfile.Cust_prod_type_ID, refTsdfApproval.Cust_prod_type_id)) as Cust_Prod_Type_ID,
	(select disp_method_abbr from CustomerDisposalMethod where disp_method_id = 
		coalesce(p.Cust_disp_method_ID, ta.Cust_disp_method_ID, refProfile.Cust_disp_method_ID, refTsdfApproval.Cust_disp_method_ID)) as Cust_Disp_Method_Abbr,
	(select disp_method_desc from CustomerDisposalMethod where disp_method_id = 
		coalesce(p.Cust_disp_method_ID, ta.Cust_disp_method_ID, refProfile.Cust_disp_method_ID, refTsdfApproval.Cust_disp_method_ID)) as Cust_Disp_Method_ID,
/*
	reftsdf.tsdf_code ref_tsdf_code, -- referral line's tsdf_code
	reftsdf.tsdf_name ref_tsdf_name,
	reftsdf.tsdf_epa_id ref_tsdf_epa_id,
	reftsdf.tsdf_addr1 ref_tsdf_addr1,
	reftsdf.tsdf_addr2 ref_tsdf_addr2,
	reftsdf.tsdf_city ref_tsdf_city,
	reftsdf.tsdf_state ref_tsdf_state,
	reftsdf.tsdf_zip_code ref_tsdf_zip_code,
	coalesce(refTsdfApproval.tsdf_approval_id, refProfile.profile_id) as ref_tsdf_approval_id,
	refwd.tsdf_approval_code ref_tsdf_approval_code,
*/	
	
	case when d.resource_type = 'D' then dbo.fn_workorder_waste_code_list_origin_filtered (d.workorder_id, d.company_id, d.profit_ctr_id, d.sequence_id, 'F') else null end as federal_waste_codes,
	case when d.resource_type = 'D' then dbo.fn_workorder_waste_code_list_origin_filtered (d.workorder_id, d.company_id, d.profit_ctr_id, d.sequence_id, 'S') else null end  as state_waste_codes,
	
	(
		select count(distinct bill_unit_code)
		from workorderdetailunit wodu_count
		where wodu_count.workorder_id = d.workorder_id
		and wodu_count.company_id = d.company_id
		and wodu_count.profit_ctr_id = d.profit_ctr_id
		and wodu_count.sequence_id = d.sequence_id
		and d.resource_type = 'D'
		
	) as Container_Type_Count,
	
	case d.resource_type
		when 'D' then wodu_bu.bill_unit_desc 
		else dbu.bill_unit_desc 
	end as billing_unit,
	
	coalesce(ds.disposal_service_desc, treat.disposal_service_Desc) as 'Disposal Method',
	wt.description as 'Waste Type Description',
	wt.category as 'Waste Type Category',
	coalesce(ta.RCRA_Haz_flag, p.RCRA_Haz_flag) as 'RCRA Haz Flag',
	case when d.resource_type = 'D' then
		isnull(convert(varchar(20), wodu_b.quantity), 'Unknown') 
	else isnull(convert(varchar(20), coalesce(d.quantity_used, d.quantity)), 'Unknown')  end as billing_quantity,
	wodu_mu.bill_unit_desc as manifest_unit,
	case when d.resource_type = 'D' then
		isnull(convert(varchar(20), wodu_m.quantity), 'Unknown') 
	else NULL end as manifest_quantity,
	
	case when d.resource_type = 'D' then
	case when (wodu_m.quantity * wodu_mu.pound_conv) is not null then
		'Manifested Unit'
		else 
		'Billed Unit'
		end
	else NULL
	end as 'Weight Source',

	case when (wodu_m.quantity * wodu_mu.pound_conv) is not null then
		wodu_mu.pound_conv
		else 
		wodu_bu.pound_conv 
	end as 'Pound Conversion',
	
	coalesce(wodu_m.quantity * wodu_mu.pound_conv, wodu_b.quantity * wodu_bu.pound_conv) as weight
	
	, case when d.resource_type = 'D' then
		case when isnull(wodu_b.price, 0) <> 0 then 
			wodu_b.price
		else

			case when d.profile_id is not null then
				( select sum(isnull(price, 0))
					from ProfileQuoteDetail pqd (nolock)
					where pqd.profile_id = d.profile_id
					AND pqd.company_id = d.profile_company_id
					AND pqd.profit_ctr_id = d.profile_profit_ctr_id
					AND pqd.bill_unit_code = wodu_b.bill_unit_code
					AND pqd.status = 'A'
				)
				else
				( select sum(isnull(price, 0))
					from TSDFApprovalPrice tap (nolock)
					where tap.TSDF_approval_id = d.TSDF_approval_id
					AND tap.company_id = d.company_id
					AND tap.profit_ctr_id = d.profit_ctr_ID
					AND tap.bill_unit_code = wodu_b.bill_unit_code
					AND tap.status = 'A'
				)
			end
		end
	else
		d.price 
	end as unit_price
	, case when d.resource_type = 'D' then
		case when isnull(wodu_b.price, 0) <> 0 then 
			'' -- Workorder prices are the most accurate (they get sent to billing)
		else

			case when d.profile_id is not null then
				'Profile Unit Price (may not include surcharges)'
				else
				'TSDF Approval Unit Price (may not include surcharges)'
			end
		end
	else
		'Work Order Detail Price' 
	end as unit_price_source,
	
    billed_total = b.extended_amt
FROM   #src s
		join workorderheader (nolock)
			on s.workorder_id = workorderheader.workorder_id
			and s.company_id = workorderheader.company_id
			and s.profit_ctr_id = workorderheader.profit_ctr_id
       INNER JOIN profitcenter (nolock)
           ON profitcenter.company_id = s.company_id
              AND profitcenter.profit_ctr_id = s.profit_ctr_id
       INNER JOIN workorderdetail d (nolock)
			ON s.workorder_id = d.workorder_id
				AND s.profit_ctr_id = d.profit_ctr_id
				AND s.company_id = d.company_id
				AND d.bill_rate > -2
		left join BillUnit dbu (nolock)
			on d.bill_unit_code = dbu.bill_unit_code
		LEFT JOIN customerbilling cb (nolock) 
			on workorderheader.customer_id = cb.customer_id 
				and workorderheader.billing_project_id = cb.billing_project_id
		LEFT JOIN WorkOrderDetailUnit wodu_b (nolock)
			ON d.workorder_id = wodu_b.workorder_id
				AND d.profit_ctr_id = wodu_b.profit_ctr_id
				AND d.company_id = wodu_b.company_id
				and d.sequence_ID = wodu_b.sequence_id
				and d.resource_type = 'D'
				and wodu_b.billing_flag = 'T'
		LEFT JOIN WorkOrderDetailUnit wodu_m (nolock)
			ON d.workorder_id = wodu_m.workorder_id
				AND d.profit_ctr_id = wodu_m.profit_ctr_id
				AND d.company_id = wodu_m.company_id
				and d.sequence_ID = wodu_m.sequence_id
				and d.resource_type = 'D'
				and wodu_m.manifest_flag = 'T'
		left join BillUnit wodu_bu (nolock)
			on wodu_b.bill_unit_code = wodu_bu.bill_unit_code
		left join BillUnit wodu_mu (nolock)
			on wodu_m.bill_unit_code = wodu_mu.bill_unit_code
       --LEFT OUTER JOIN workorderproblem
       --    ON workorderheader.problem_id = workorderproblem.problem_id
       
       -- referenced disposal line, and its approval information:
		   LEFT JOIN WorkOrderDetail refwd (nolock)
				ON refwd.workorder_id = d.workorder_id
				and refwd.company_id = d.company_id
				and refwd.profit_ctr_id = d.profit_ctr_id
				and refwd.sequence_id = d.disposal_sequence_id
				and refwd.resource_type = 'D' 
			LEFT JOIN Profile refprofile (nolock)
				ON refwd.profile_id = refprofile.profile_id
				-- AND refwd.profile_company_id = refprofile.company_id
				-- and refwd.profile_profit_ctr_id = refprofile.profit_ctr_id
				and refwd.profile_id is not null
			LEFT JOIN tsdfapproval refTsdfApproval (nolock)
				ON refwd.tsdf_approval_id = refTsdfApproval.tsdf_approval_id
				and refwd.tsdf_approval_id is not null
			LEFT JOIN tsdf reftsdf
				ON refwd.tsdf_code = reftsdf.tsdf_code
				
       LEFT OUTER JOIN customer (nolock)
           ON s.customer_id = customer.customer_id
       LEFT OUTER JOIN generator (nolock)
           ON workorderheader.generator_id = generator.generator_id
       LEFT OUTER JOIN County (nolock)
			ON generator.generator_county = county.county_code
/*
	-- WorkorderHeader contains generator_sublocation_id.  And the field is unique values across the whole GSL table.  Why do the extra query?
       LEFT OUTER JOIN GeneratorXGeneratorSubLocation gxgsl (nolock)
           ON generator.generator_id = gxgsl.generator_id
           AND workorderheader.generator_sublocation_id = gxgsl.generator_sublocation_id
*/
       LEFT OUTER JOIN GeneratorSubLocation (nolock)
           ON workorderheader.generator_sublocation_id = GeneratorSubLocation.generator_sublocation_id

       LEFT JOIN TripHeader (nolock)
			on workorderheader.trip_id = TripHeader.trip_id
			AND workorderheader.company_id = TripHeader.company_id
			AND workorderheader.profit_ctr_id = TripHeader.profit_ctr_id
		LEFT JOIN WorkOrderTypeHeader woth (nolock)
			on workorderheader.workorder_type_id = woth.workorder_type_id
		LEFT JOIN profile p (nolock) 
			on d.resource_type = 'D'
				and d.profile_id = p.profile_id
		LEFT JOIN tsdfapproval ta (nolock) 
			on d.resource_type = 'D'
				and d.tsdf_approval_id = ta.tsdf_approval_id 
		LEFT JOIN ProfilequoteApproval pqa (nolock) 
			on d.resource_type = 'D'
				and d.profile_id = pqa.profile_id
				and d.profile_company_id = pqa.company_id
				and d.profile_profit_ctr_id = pqa.profit_ctr_id
		left join Treatment	treat (nolock)
			on d.resource_type = 'D'
				and pqa.treatment_id = treat.treatment_id
				and pqa.company_id = treat.company_id
				and pqa.profit_ctr_id = treat.profit_ctr_id
		LEFT JOIN disposalservice ds (nolock) 
			on ta.disposal_service_id = ds.disposal_service_id
		LEFT JOIN wastetype wt (nolock) 
			on p.wastetype_id = wt.wastetype_id
		LEFT JOIN TSDF t (nolock)
			on d.tsdf_code = t.tsdf_code
		LEFT JOIN (
			select workorder_id, company_id, profit_ctr_id, manifest, min(transporter_sequence_id) _min
			from WorkOrderTransporter
			group by workorder_id, company_id, profit_ctr_id, manifest
		) wotmin
			ON wotmin.workorder_id = d.workorder_id
			and wotmin.company_id = d.company_id
			and wotmin.profit_ctr_id = d.profit_ctr_id
			and wotmin.manifest = d.manifest
		LEFT JOIN WorkOrderTransporter wot
			ON wot.workorder_id = d.workorder_id
			and wot.company_id = d.company_id
			and wot.profit_ctr_id = d.profit_ctr_id
			and wot.manifest = d.manifest
			and wot.transporter_sequence_id = wotmin._min
		LEFT JOIN OffScheduleServiceReason osr (nolock)
			ON workorderheader.offschedule_service_reason_ID = osr.reason_id
		CROSS APPLY (
			select 
				MIN(billing.invoice_code) as invoice_code
				, SUM( billingdetail.extended_amt ) extended_amt
				, MIN(billing.invoice_date) as invoice_date
			FROM   billing (nolock)
			JOIN	billingdetail
				on billing.billing_uid = billingdetail.billing_uid
			WHERE  d.workorder_id = billing.receipt_id
				AND d.profit_ctr_id = billing.profit_ctr_id
				AND d.company_id = billing.company_id
				and d.resource_type = billing.workorder_resource_type
				and d.sequence_id = billing.workorder_sequence_id
				and billing.bill_unit_code = case when wodu_b.bill_unit_code is not null then wodu_b.bill_unit_code else billing.bill_unit_code end
				AND billing.trans_source = 'W'
		) b
WHERE
	s.workorder_status IN ( 'A', 'C', 'D', 'N', 'P', 'X' )
	--AND generator.site_code = '1'
	AND d.resource_type in (select resource_type from #ResourceTypeFilter)
	-- and s.customer_ID in (select customer_id from #customer)
	-- and coalesce(wos.date_act_arrive, workorderheader.start_date) between @start_date AND @end_date
	AND 1 = case when @billing_status_list like '%U%'
		and isnull(s.submitted_flag, 'F') = 'F'
		and isnull(s.billing_status_code, 'N') <> 'I'
		then 1
		else
			case when @billing_status_list like '%S%'
			and isnull(s.submitted_flag, 'F') = 'T'
			and isnull(s.billing_status_code, 'N') <> 'I'
			then 1
			else 
				case when @billing_status_list like '%I%'
				and isnull(s.submitted_flag, 'F') = 'T'
				and isnull(s.billing_status_code, 'N') = 'I'
				then 1
				else 0
				end
			end
		end
-- guarantee 0-price, non "print on invoice" lines are omitted.
	and (
		d.resource_type	in ('D')
		OR
		d.price > 0
		OR
		isnull(d.print_on_invoice_flag, 'F') = 'T'
	)
-- don't show no-charge unless print-on-invoice-flag is T
	and (
		d.bill_rate not in (0)
		OR
		isnull(d.print_on_invoice_flag, 'F') = 'T'
	)
ORDER BY 
    s.company_id,
    s.profit_ctr_id, -- AS profit_center_id,
    s.customer_id,
	workorderheader.trip_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_incomplete_workorder_disposal_report] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_incomplete_workorder_disposal_report] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_eqip_incomplete_workorder_disposal_report] TO [EQAI]
    AS [dbo];

