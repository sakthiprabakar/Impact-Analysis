-- drop proc if exists sp_rpt_timely_invoicing_SSRS
go

Create Procedure sp_rpt_timely_invoicing_SSRS (
	@start_date				datetime,
	@end_date				datetime,
	@invoice_flag			char(1) = 'S',
	@return_detail_level	varchar(20) = 'all', -- either 'summary', 'detail', 'all'
	@facility_list 			varchar(max) 		= null,
	@customer_id_list 		varchar(max) 		= null,
	@customer_type_list		varchar(max)		= null,
	@review_flag			char(1) = 'T'	-- How to treat CustomerBilling.internal_review_flag (T/F/U)
)
/************************************************************
Procedure    : sp_rpt_timely_invoicing_SSRS
Database     : plt_ai* 
Created      : 7:05 PM Wednesday, May 06, 2009 - Jonathan Broome
Filename     : Moved from, L:\Apps\SQL\Special Manual Requests\Timely Invoicing\sp_rpt_timely_invoicing.sql
Description  : Returns pending profile (WCR) information

sp_rpt_timely_invoicing_SSRS '1/1/2015', '1/15/2015 23:59', 'S', 'summary'
sp_rpt_timely_invoicing_SSRS '1/1/2015', '1/15/2015 23:59', 'S', 'detail'
sp_rpt_timely_invoicing_SSRS '1/1/2015', '1/15/2015 23:59', 'S', 'all'
sp_rpt_timely_invoicing_SSRS '1/1/2015', '1/15/2015 23:59', 'M'
sp_rpt_timely_invoicing_SSRS '1/1/2015', '1/15/2015 23:59', 'S', '2,21'
sp_rpt_timely_invoicing_SSRS '1/1/2015', '1/15/2015 23:59', 'S', '2|21,21|0'
sp_rpt_timely_invoicing_SSRS '1/1/2015', '1/15/2015 23:59', 'S', null, '10673'
sp_rpt_timely_invoicing_SSRS '1/1/2015', '1/15/2015 23:59', 'S', '2|21,21|0', '10673, 6243'
sp_rpt_timely_invoicing_SSRS '1/1/2015', '3/31/2015 23:59', 'M', 'detail', NULL, '10877', 'T'
sp_rpt_timely_invoicing_SSRS '11/1/2020', '11/30/2020 23:59', 'S', 'all', null, null, 'univar', 'u'
sp_rpt_timely_invoicing_SSRS '11/1/2020', '11/30/2020 23:59', 'S', 'summary', null, null, 'univar', 'u'
sp_rpt_timely_invoicing_SSRS '11/1/2020', '11/30/2020 23:59', 'S', 'detail', null, null, 'univar', 'u'

05/06/2009 JPB  Created
05/12/2009 JPB  Modified output - days... fields now -1 so that they're not counting the start date.
				Join to InvoiceHeader changed so we're only including the first date_added, or the max date_added within a week of the 1st date_added.
				Modified join to InvoiceHeader to simplify and restrict output to only invoices that have status 'I'
					(instead of any invoice revision where *any* revision is 'I', not necessarily the reported one)
				Removed Joins -
					Include linked_workorder_id, linked_company_id, linked_profit_ctr_id, linked_flag on all rows
					Then they can be re-ordered by these fields correctly and order of records doesn't matter.
					(Workorder records should just use their own values, Receipt records should use the linked workorder, if any, or self)
05/13/2009 JPB 	Modified days data: -1 on all occurences EXCEPT output.
				Modified output column names & order of selection & order of output
05/19/2009 JPB	Modified Exceptions query: Aligned with standard query syntax
10/21/2009 RJG  Modified to use in SQL Reporting services.  It will only return one flavor of report (summary or detail) at a time now.
		Modified to make sure that the @end_date passed in is ALWAYS inclusive
01/27/2016 JPB	GEM-35821: New math, new fields, in summary version.
02/05/2016 JBP	GEM-35996: Exclude source material with billing projec that has internal_review_flag = 'T' (same deploy as 1/27 work)
04/19/2016 JPB	GEM-37222: Belay that ^^^ order.  Make it a user-choice, not hard-coded.  Added @review_flag T/F/nUll options
04/28/2017 JPB	GEM-43227: Avoid records that have adjustment data.  They're not legit timings anymore.
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75
02/08/2021 JPB	DO-17828: Add customer_type as input

select distinct customer_type from customer

************************************************************/

AS

/*
-- debug:
declare
	@start_date				datetime	= '11/1/2020',
	@end_date				datetime	= '11/30/2020',
	@invoice_flag			char(1) = 'S',
	@return_detail_level	varchar(20) = 'all', -- either 'summary', 'detail', 'all'
	@facility_list 			varchar(max) 		= null,
	@customer_id_list 		varchar(max) 		= null,
	@customer_type_list		varchar(max)		= 'UNIVAR',
	@review_flag			char(1) = 'U'	-- How to treat CustomerBilling.internal_review_flag (T/F/U)
*/


SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

drop table if exists #facility_tmp2
drop table if exists #facility_list 
drop table if exists #customer 
drop table if exists #full
drop table if exists #reportdata 



if @start_date is null or @end_date is null return
/*
	select @start_date			= '1/1/2015',
	@end_date					= '1/15/2015 23:59',
	@invoice_flag				= 'S',
	@return_detail_level		= 'detail', -- either 'summary', 'detail', 'all'
	@facility_list 				= '21|0',
	@customer_id_list 			= ''
*/

-- make sure @end_date is inclusive
set @end_date = cast(CONVERT(varchar(20), @end_date, 101) + ' 23:59:59' as datetime)

Create Table #full (
	Source						varchar(40),
	Source_ID					int,
	Company_ID					int,
	Profit_Ctr_ID				int,
	Link_Source_ID				int,
	Link_Company_ID				int,
	Link_Profit_Ctr_ID			int,
	Link_Flag					varchar(3),
	Source_Receipt_Or_End_Date	datetime,
	Source_Submitted_Date		datetime,
	Invoice_Date_Added			datetime,
	Days_From_End_To_Submit		float,
	Days_From_Submit_To_Invoice	float,
	Days_From_End_To_Invoice	float,
	Invoice_Date				datetime,
	Invoice_Code				varchar(16),
	Customer_ID					int,
	Cust_Name					varchar(75),
	Customer_Type				varchar(20),		
	Generator_ID				int,
	Generator_Name				varchar(75),
	Invoice_Flag				varchar(40),
	Intervention_Desc			varchar(255),
	PO_Required_Flag			char(1),
	Qry							int
)

create table #facility_tmp2 (company_id int, profit_ctr_id int)
create table #facility_list (company_id int, profit_ctr_id int)
create index idx1 on #facility_list (company_id, profit_ctr_id)

create table #customer (customer_id int)
create index idx2 on #customer (customer_id)

set @end_date = cast(CONVERT(varchar(20), @end_date, 101) + ' 23:59:59' as datetime)


if @facility_list is not null begin
	insert #facility_tmp2 (company_id, profit_ctr_id)
	select 
			case when charindex('|', row) > 0 then
				convert(int, left(row, charindex('|', row)-1))
			else
				convert(int, row)
			end,
			case when charindex('|', row) > 0 then
				convert(int, right(row, len(row) - charindex('|', row)))
			else
				null
			end
	from dbo.fn_SplitXsvText(',', 1, @facility_list)   
	where isnull(row, '') <> ''

	insert #facility_list select * from #facility_tmp2 where profit_ctr_id is not null
	insert #facility_list select p.company_id, p.profit_ctr_id
		from profitcenter p where company_id in (select company_id from #facility_tmp2 where profit_ctr_id is null)
end else begin
	insert #facility_list (company_id, profit_ctr_id)
	select company_id, profit_ctr_id from profitcenter where status = 'A'
end

if @customer_id_list is not null begin
	insert #customer
		select convert(int, row)   
		from dbo.fn_SplitXsvText(',', 0, @customer_id_list)   
		where isnull(row, '') <> ''
end else if @customer_type_list is not null begin
	insert #customer
	select distinct customer_id
	from customer where replace(customer_type, ',', '') in (
		select row   
		from dbo.fn_SplitXsvText(',', 0, @customer_type_list)   
		where isnull(row, '') <> ''
	)
	and customer_id not in (select customer_id from #customer)
end else begin
	insert #customer select customer_id from customer
end






IF @invoice_flag = 'S' begin
	-- STANDARD
	-- Source or non-linked billing records that aren't special handling cases.
	insert #full
	select distinct
	
		case b.trans_source
			when 'W' then 'Work Order'
			when 'R' then 'Receipt'
			when 'O' then 'Retail Order'
			else b.trans_source
		end as source,
		
		b.receipt_id as source_id,
		b.company_id,
		b.profit_ctr_id,
		
		case b.trans_source
			when 'W' then bllw.source_id
			when 'R' then bllr.source_id
			else null
		end as link_source_id,
		
		case b.trans_source
			when 'W' then bllw.source_company_id
			when 'R' then bllr.source_company_id
			else null
		end as link_company_id,
		
		case b.trans_source
			when 'W' then bllw.source_profit_ctr_id
			when 'R' then bllr.source_profit_ctr_id
			else null
		end as link_profit_ctr_id,
		
		case b.trans_source
			when 'W' then
				case when bllw.source_id is not null then 'Yes' else 'No' end 
			when 'R' then
				case when bllr.source_id is not null then 'Yes' else 'No' end 
			else 'No'
		end as link_flag,
		
		case b.trans_source
			when 'W' then wh.end_date
			when 'R' then r.receipt_date
			when 'O' then retail.date_added
		end as source_receipt_or_end_date,
		
		case b.trans_source
			when 'W' then wh.date_submitted
			when 'R' then r.date_submitted
			when 'O' then retail.date_added
		end as source_submitted_date,
		
		ih.date_added as invoice_date_added, -- use for calculations: DEFINITELY duplicating receipts due to being on separate invoices
		
		case b.trans_source
			when 'W' then dbo.fn_business_days(wh.end_date, wh.date_submitted) -1
			when 'R' then dbo.fn_business_days(r.receipt_date, r.date_submitted) -1
			when 'O' then dbo.fn_business_days(retail.order_date, retail.date_submitted) -1
		end as days_from_end_to_submit,
		
		case b.trans_source
			when 'W' then dbo.fn_business_days(wh.date_submitted, ih.date_added) -1
			when 'R' then dbo.fn_business_days(r.date_submitted, ih.date_added) -1
			when 'O' then dbo.fn_business_days(retail.date_submitted, ih.date_added) -1
		end as days_from_submit_to_invoice,
		
		case b.trans_source
			when 'W' then dbo.fn_business_days(wh.end_date, ih.date_added) -1
			when 'R' then dbo.fn_business_days(r.receipt_date, ih.date_added) -1
			when 'O' then dbo.fn_business_days(retail.order_date, ih.date_added) -1
		end as days_from_end_to_invoice,	
		
		ih.invoice_date, -- Informational only
		ih.invoice_code,
		b.customer_id,
		c.cust_name,
		c.customer_type,
		
		case when (select count(distinct generator_id) from billing where invoice_id = b.invoice_id and company_id = b.company_id and profit_ctr_id = b.profit_ctr_id) > 1 then
			NULL
		else
			g.generator_id
		end as generator_id,
		
		case when (select count(distinct generator_id) from billing where invoice_id = b.invoice_id and company_id = b.company_id and profit_ctr_id = b.profit_ctr_id) > 1 then
			'Various'
		else
			g.generator_name
		end as generator_id ,
		
		case cb.invoice_flag
			when 'M' then 'Manual'
			when 'S' then 'Standard'
			else invoice_flag
		end as invoice_flag,
		
		cb.intervention_desc,
		cb.po_required_flag,
		1 as qry
		
	from billing b
		inner join #facility_list fl on (b.company_id = fl.company_id and b.profit_ctr_id = fl.profit_ctr_id)
		inner join #customer cl on (b.customer_id = cl.customer_id)
		left outer join workorderheader wh 
			on b.receipt_id = wh.workorder_id 
			and b.company_id = wh.company_id
			and b.profit_ctr_id = wh.profit_ctr_id 
			and b.trans_source = 'W'
		left outer join (
			select r1.receipt_id, r1.company_id, r1.profit_ctr_id, r1.receipt_date, max(r1.date_submitted) as date_submitted
			from receipt r1
			inner join #facility_list fl on (r1.company_id = fl.company_id and r1.profit_ctr_id = fl.profit_ctr_id)
			inner join #customer cl on (r1.customer_id = cl.customer_id)
			group by r1.receipt_id, r1.company_id, r1.profit_ctr_id, r1.receipt_date
			) r 
				on b.receipt_id = r.receipt_id 
				and b.company_id = r.company_id
				and b.profit_ctr_id = r.profit_ctr_id 
				and b.trans_source = 'R'
		left outer join orderheader retail
			on b.receipt_id = retail.order_id
			and b.trans_source = 'O'
		inner join customerbilling cb 
			on b.customer_id = cb.customer_id 
			and b.billing_project_id = cb.billing_project_id
			-- and isnull(cb.internal_review_flag, 'F') = 'F'
			and (@review_flag = 'U' OR (isnull(cb.internal_review_flag, 'F') = @review_flag))
		inner join invoiceheader ih 
			on b.invoice_id = ih.invoice_id and ih.status = 'I' 
			and ih.revision_id = (select max(revision_id) from invoiceheader ih1 where ih1.invoice_id = b.invoice_id)
			and ih.date_added <= (
				/* This is to eliminate credits from the select...
				   Only include the highest revision_id for this invoice when it IS invoiced and 
				   it is <= 7 days from the first revision_id for the same invoice number.
				   We generalized that after a week from initial invoice, a revision is PROBABLY a credit
				*/
				select min(date_added) + 7
				from invoiceheader ih1
				where ih1.invoice_id = b.invoice_id
			)
		inner join customer c 
			on b.customer_id = c.customer_id
			and c.eq_flag <> 'T'
		left outer join generator g 
			on b.generator_id = g.generator_id
		left outer join billinglinklookup bllw
			on bllw.source_id = b.receipt_id
			and bllw.source_company_id = b.company_id
			and bllw.source_profit_ctr_id = b.profit_ctr_id
			and b.trans_source = 'W'
			and isnull(bllw.link_required_flag, 'F') = 'T'
			and exists (select 1 from receipt lr 
				join billing lrb on lr.receipt_id = lrb.receipt_id and lr.company_id = lrb.company_id and lr.profit_ctr_id = lrb.profit_ctr_id and lrb.trans_source = 'R' and lrb.invoice_id = b.invoice_id 
				where bllw.receipt_id = lr.receipt_id and bllw.company_id = lr.company_id and bllw.profit_ctr_id = lr.profit_ctr_id and lr.receipt_status not in ('V'))
		left outer join billinglinklookup bllr
			on bllr.receipt_id = b.receipt_id
			and bllr.company_id = b.company_id
			and bllr.profit_ctr_id = b.profit_ctr_id
			and b.trans_source = 'R'
			and isnull(bllr.link_required_flag, 'F') = 'T'
			and exists (select 1 from workorderheader lwh 
				join billing lwb on lwh.workorder_id = lwb.receipt_id and lwh.company_id = lwb.company_id and lwh.profit_ctr_id = lwb.profit_ctr_id and lwb.trans_source = 'W' and lwb.invoice_id = b.invoice_id 
				where bllr.source_id = lwh.workorder_id and bllr.source_company_id = lwh.company_id and bllr.source_profit_ctr_id = lwh.profit_ctr_id and lwh.workorder_status not in ('V'))
	where b.invoice_date between @start_date and @end_date
	and b.status_code = 'I'
	and (cb.intervention_required_flag <> 'T' AND cb.invoice_flag <> 'M')
	and not exists (
		-- Exclude records that are part of adjustments.
		select 1 from AdjustmentDetail ad
		WHERE b.receipt_id = ad.receipt_id
		and b.company_id = ad.company_id
		and b.profit_ctr_id = ad.profit_ctr_id
		and b.line_id = ad.line_id
		and b.trans_source = ad.trans_source
		and 1=1
	)

end	else begin

	insert #full
	select distinct
	
		case b.trans_source
			when 'W' then 'Work Order'
			when 'R' then 'Receipt'
			when 'O' then 'Retail Order'
			else b.trans_source
		end as source,
		
		b.receipt_id as source_id,
		b.company_id,
		b.profit_ctr_id,

		case b.trans_source
			when 'W' then bllw.source_id
			when 'R' then bllr.source_id
			else null
		end as link_source_id,
		
		case b.trans_source
			when 'W' then bllw.source_company_id
			when 'R' then bllr.source_company_id
			else null
		end as link_company_id,
		
		case b.trans_source
			when 'W' then bllw.source_profit_ctr_id
			when 'R' then bllr.source_profit_ctr_id
			else null
		end as link_profit_ctr_id,
		
		case b.trans_source
			when 'W' then
				case when bllw.source_id is not null then 'Yes' else 'No' end 
			when 'R' then
				case when bllr.source_id is not null then 'Yes' else 'No' end 
			else 'No'
		end as link_flag,
	
		case b.trans_source
			when 'W' then wh.end_date
			when 'R' then r.receipt_date
			when 'O' then retail.date_added
		end as source_receipt_or_end_date,
		
		case b.trans_source
			when 'W' then wh.date_submitted
			when 'R' then r.date_submitted
			when 'O' then retail.date_added
		end as source_submitted_date,
		
		ih.date_added as invoice_date_added, -- use for calculations: DEFINITELY duplicating receipts due to being on separate invoices
		
		case b.trans_source
			when 'W' then dbo.fn_business_days(wh.end_date, wh.date_submitted) -1
			when 'R' then dbo.fn_business_days(r.receipt_date, r.date_submitted) -1
			when 'O' then dbo.fn_business_days(retail.order_date, retail.date_submitted) -1
		end as days_from_end_to_submit,
		
		case b.trans_source
			when 'W' then dbo.fn_business_days(wh.date_submitted, ih.date_added) -1
			when 'R' then dbo.fn_business_days(r.date_submitted, ih.date_added) -1
			when 'O' then dbo.fn_business_days(retail.date_submitted, ih.date_added) -1
		end as days_from_submit_to_invoice,
		
		case b.trans_source
			when 'W' then dbo.fn_business_days(wh.end_date, ih.date_added) -1
			when 'R' then dbo.fn_business_days(r.receipt_date, ih.date_added) -1 
			when 'O' then dbo.fn_business_days(retail.order_date, ih.date_added) -1
		end as days_from_end_to_invoice,
		
		ih.invoice_date, -- Informational only
		ih.invoice_code,
		b.customer_id,
		c.cust_name,
		c.customer_type,
		
		case when (select count(distinct generator_id) from billing where invoice_id = b.invoice_id and company_id = b.company_id and profit_ctr_id = b.profit_ctr_id) > 1 then
			NULL
		else
			g.generator_id
		end as generator_id,
		
		case when (select count(distinct generator_id) from billing where invoice_id = b.invoice_id and company_id = b.company_id and profit_ctr_id = b.profit_ctr_id) > 1 then
			'Various'
		else
			g.generator_name
		end as generator_name,
		
		case cb.invoice_flag
			when 'M' then 'Manual'
			when 'S' then 'Standard'
			else invoice_flag
		end as invoice_flag,
		
		cb.intervention_desc,
		cb.po_required_flag,
		1 as qry
		
	from billing b
		inner join #facility_list fl on (b.company_id = fl.company_id and b.profit_ctr_id = fl.profit_ctr_id)
		inner join #customer cl on (b.customer_id = cl.customer_id)
		left outer join workorderheader wh 
			on b.receipt_id = wh.workorder_id 
			and b.company_id = wh.company_id
			and b.profit_ctr_id = wh.profit_ctr_id 
			and b.trans_source = 'W'
		left outer join (
			select r1.receipt_id, r1.company_id, r1.profit_ctr_id, r1.receipt_date, max(r1.date_submitted) as date_submitted
			from receipt r1
			group by r1.receipt_id, r1.company_id, r1.profit_ctr_id, r1.receipt_date
			) r 
				on b.receipt_id = r.receipt_id 
				and b.company_id = r.company_id
				and b.profit_ctr_id = r.profit_ctr_id 
				and b.trans_source = 'R'
		left outer join orderheader retail
			on b.receipt_id = retail.order_id
			and b.trans_source = 'O'
		inner join customerbilling cb 
			on b.customer_id = cb.customer_id 
			and b.billing_project_id = cb.billing_project_id
			-- and isnull(cb.internal_review_flag, 'F') = 'F'
			and (@review_flag = 'U' OR (isnull(cb.internal_review_flag, 'F') = @review_flag))
		inner join invoiceheader ih 
			on b.invoice_id = ih.invoice_id and ih.status = 'I' 
			and ih.revision_id = (select max(revision_id) from invoiceheader ih1 where ih1.invoice_id = b.invoice_id)
			and ih.date_added <= (
				/* This is to eliminate credits from the select...
				   Only include the highest revision_id for this invoice when it IS invoiced and 
				   it is <= 7 days from the first revision_id for the same invoice number.
				   We generalized that after a week from initial invoice, a revision is PROBABLY a credit
				*/
				select min(date_added) + 7
				from invoiceheader ih1
				where ih1.invoice_id = b.invoice_id
			)
		inner join customer c 
			on b.customer_id = c.customer_id
			and c.eq_flag <> 'T'
		left outer join generator g 
			on b.generator_id = g.generator_id
		left outer join billinglinklookup bllw
			on bllw.source_id = b.receipt_id
			and bllw.source_company_id = b.company_id
			and bllw.source_profit_ctr_id = b.profit_ctr_id
			and b.trans_source = 'W'
			and isnull(bllw.link_required_flag, 'F') = 'T'
			and exists (select 1 from receipt lr 
				join billing lrb on lr.receipt_id = lrb.receipt_id and lr.company_id = lrb.company_id and lr.profit_ctr_id = lrb.profit_ctr_id and lrb.trans_source = 'R' and lrb.invoice_id = b.invoice_id 
				where bllw.receipt_id = lr.receipt_id and bllw.company_id = lr.company_id and bllw.profit_ctr_id = lr.profit_ctr_id and lr.receipt_status not in ('V'))
		left outer join billinglinklookup bllr
			on bllr.receipt_id = b.receipt_id
			and bllr.company_id = b.company_id
			and bllr.profit_ctr_id = b.profit_ctr_id
			and b.trans_source = 'R'
			and isnull(bllr.link_required_flag, 'F') = 'T'
			and exists (select 1 from workorderheader lwh 
				join billing lwb on lwh.workorder_id = lwb.receipt_id and lwh.company_id = lwb.company_id and lwh.profit_ctr_id = lwb.profit_ctr_id and lwb.trans_source = 'W' and lwb.invoice_id = b.invoice_id 
				where bllr.source_id = lwh.workorder_id and bllr.source_company_id = lwh.company_id and bllr.source_profit_ctr_id = lwh.profit_ctr_id and lwh.workorder_status not in ('V'))
	where b.invoice_date between @start_date and @end_date
	and b.status_code = 'I'
	and (cb.intervention_required_flag = 'T' OR cb.invoice_flag = 'M')
	and not exists (
		-- Exclude records that are part of adjustments.
		select 1 from AdjustmentDetail ad
		WHERE b.receipt_id = ad.receipt_id
		and b.company_id = ad.company_id
		and b.profit_ctr_id = ad.profit_ctr_id
		and b.line_id = ad.line_id
		and b.trans_source = ad.trans_source
		and 1=1
	)

end


--SELECT  * FROM    #full


select * into #reportdata from #full where link_flag = 'No'
union
select 
	/*
	case when datediff(dd, a.source_receipt_or_end_date, a.invoice_date_added) > datediff(dd, b.source_receipt_or_end_date, b.invoice_date_added)
		then a.source + ' (a)'
		else b.source + ' (b)'
		end as source,
	*/
	'Linked' as source,
	case when datediff(dd, a.source_receipt_or_end_date, a.invoice_date_added) > datediff(dd, b.source_receipt_or_end_date, b.invoice_date_added)
		then a.source_id
		else b.source_id
		end as source_id,
	case when datediff(dd, a.source_receipt_or_end_date, a.invoice_date_added) > datediff(dd, b.source_receipt_or_end_date, b.invoice_date_added)
		then a.company_id
		else b.company_id
		end as company_id,
	case when datediff(dd, a.source_receipt_or_end_date, a.invoice_date_added) > datediff(dd, b.source_receipt_or_end_date, b.invoice_date_added)
		then a.profit_ctr_id
		else b.profit_ctr_id
		end as profit_ctr_id,
	a.link_source_id			,	
	a.link_company_id			,	
	a.link_profit_ctr_id		,	
	a.link_flag					,
	case when a.source_receipt_or_end_date < b.source_receipt_or_end_date
		then a.source_receipt_or_end_date
		else b.source_receipt_or_end_date
		end as source_receipt_or_end_date,	
	case when a.source_submitted_date < b.source_submitted_date
		then b.source_submitted_date
		else a.source_submitted_date
		end as source_submitted_date,	
	a.invoice_date_added		,	
	dbo.fn_business_days(
		case when a.source_receipt_or_end_date < b.source_receipt_or_end_date
		then a.source_receipt_or_end_date
		else b.source_receipt_or_end_date
		end,
		case when a.source_submitted_date < b.source_submitted_date
		then b.source_submitted_date
		else a.source_submitted_date
		end ) -1 as days_from_end_to_submit,
	dbo.fn_business_days(
		case when a.source_submitted_date < b.source_submitted_date
		then b.source_submitted_date
		else a.source_submitted_date
		end, 
		/*
		case when a.invoice_date_added < b.invoice_date_added
		then b.invoice_date_added
		else a.invoice_date_added
		end 
		*/
		a.invoice_date_added /* should be the same for both, because they're linked */
		) -1 as days_from_submit_to_invoice,
	dbo.fn_business_days(
		case when a.source_receipt_or_end_date < b.source_receipt_or_end_date
		then a.source_receipt_or_end_date
		else b.source_receipt_or_end_date
		end,
		/*
		case when a.invoice_date_added < b.invoice_date_added
		then b.invoice_date_added
		else a.invoice_date_added
		end 
		*/
		a.invoice_date_added /* should be the same for both, because they're linked */
		) -1 as days_from_end_to_invoice,
		a.invoice_date_added, /* should be the same for both, because they're linked */
	a.invoice_code				,
	a.customer_id				,	
	a.cust_name					,
	a.Customer_Type				,
	a.generator_id				,
	a.generator_name			,	
	a.invoice_flag				,
	a.intervention_desc			,
	a.po_required_flag			,
	a.qry							
from #full a
join #full b on a.link_source_id = b.source_id
	and a.link_company_id = b.company_id
	and a.link_profit_ctr_id = b.profit_ctr_id
	and a.link_flag = 'Yes'
	and b.link_flag = 'Yes'


SET NOCOUNT OFF

if @return_detail_level = 'summary' or @return_detail_level = 'all'
BEGIN
	select Distinct
		d.Company_ID
		, D.Profit_Ctr_ID
		, Pc.Profit_Ctr_Name
		, Receipt._Count As Receipt_Count
		, Round(receipt.Avg_Days_From_End_To_Submit, 2) As Receipt_Avg_Days_From_End_To_Submit
		, Round(receipt.Avg_Days_From_Submit_To_Invoice, 2) As Receipt_Avg_Days_From_Submit_To_Invoice
		, Round(receipt.Avg_Days_From_End_To_Invoice, 2) As Receipt_Avg_Days_From_End_To_Invoice
		, Workorder._Count As Workorder_Count
		, Round(workorder.Avg_Days_From_End_To_Submit, 2) As Workorder_Avg_Days_From_End_To_Submit
		, Round(workorder.Avg_Days_From_Submit_To_Invoice, 2) As Workorder_Avg_Days_From_Submit_To_Invoice
		, Round(workorder.Avg_Days_From_End_To_Invoice, 2) As Workorder_Avg_Days_From_End_To_Invoice
		, Linked._Count As Linked_Count
		, Round(linked.Avg_Days_From_End_To_Submit, 2) As Linked_Avg_Days_From_End_To_Submit
		, Round(linked.Avg_Days_From_Submit_To_Invoice, 2) As Linked_Avg_Days_From_Submit_To_Invoice
		, Round(linked.Avg_Days_From_End_To_Invoice, 2) As Linked_Days_From_End_To_Invoice
		, Average._Count As Total_Count
		, Round(average.Avg_Days_From_End_To_Submit, 2) As Average_Days_From_End_To_Submit
		, Round(average.Avg_Days_From_Submit_To_Invoice, 2) As Average_Days_From_Submit_To_Invoice
		, Round(average.Avg_Days_From_End_To_Invoice, 2) As Average_Days_From_End_To_Invoice
	from #reportdata D
	join profitcenter pc
		on d.company_id = pc.company_id
		and d.profit_ctr_id = pc.profit_ctr_id
	outer apply (
		select 
		company_id
		, profit_ctr_id
		, count(source_id) as _count
		, avg(days_from_end_to_submit) as avg_days_from_end_to_submit
		, avg(days_from_submit_to_invoice) as avg_days_from_submit_to_invoice
		, avg(days_from_end_to_invoice) as avg_days_from_end_to_invoice
		from #reportdata
		where source = 'Receipt' and link_flag = 'No'
		and d.company_id = company_id
		and d.profit_ctr_id = profit_ctr_id
		group by company_id, profit_ctr_id
	) receipt
	outer apply (
		select 
		company_id
		, profit_ctr_id
		, count(source_id) as _count
		, avg(days_from_end_to_submit) as avg_days_from_end_to_submit
		, avg(days_from_submit_to_invoice) as avg_days_from_submit_to_invoice
		, avg(days_from_end_to_invoice) as avg_days_from_end_to_invoice
		from #reportdata
		where source = 'Work Order' and link_flag = 'No'
		and d.company_id = company_id
		and d.profit_ctr_id = profit_ctr_id
		group by company_id, profit_ctr_id
	) workorder
	outer apply (
		select 
		company_id
		, profit_ctr_id
		, count(source_id) as _count
		, avg(days_from_end_to_submit) as avg_days_from_end_to_submit
		, avg(days_from_submit_to_invoice) as avg_days_from_submit_to_invoice
		, avg(days_from_end_to_invoice) as avg_days_from_end_to_invoice
		from #reportdata
		where link_flag = 'Yes'
		and d.company_id = company_id
		and d.profit_ctr_id = profit_ctr_id
		group by company_id, profit_ctr_id
	) linked
	outer apply (
		select 
		company_id
		, profit_ctr_id
		, count(source_id) as _count
		, avg(days_from_end_to_submit) as avg_days_from_end_to_submit
		, avg(days_from_submit_to_invoice) as avg_days_from_submit_to_invoice
		, avg(days_from_end_to_invoice) as avg_days_from_end_to_invoice
		from #reportdata
		where 
		d.company_id = company_id
		and d.profit_ctr_id = profit_ctr_id
		group by company_id, profit_ctr_id
	) average
	order by d.company_id, d.profit_ctr_id
END
--set nocount off

-- select the results out to the user in a useful order.


IF @return_detail_level = 'detail' or @return_detail_level = 'all'
BEGIN

	select * 
	from #reportdata
	order by 
 		qry, 
		company_id, 
		profit_ctr_id

END	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_timely_invoicing_SSRS] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_timely_invoicing_SSRS] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_timely_invoicing_SSRS] TO [EQAI]
    AS [dbo];

GO
grant select 
	on customer to eqai
GO

grant select 
	on customer to eqweb
GO

grant select 
	on customer to cor_user
GO

