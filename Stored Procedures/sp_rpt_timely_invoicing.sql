
Create Procedure sp_rpt_timely_invoicing (
	@start_date			datetime,
	@end_date			datetime,
	@invoice_flag		char(1) = 'S',
	@facility_list 		text 		= null,
	@customer_id_list 	text 		= null
)
/************************************************************
Procedure    : sp_rpt_timely_invoicing
Database     : plt_ai* 
Created      : 7:05 PM Wednesday, May 06, 2009 - Jonathan Broome
Filename     : L:\Apps\SQL\Develop\Jonathan\Reports\sp_rpt_timely_invoicing.sql
Description  : Returns pending profile (WCR) information

sp_rpt_timely_invoicing '4/1/2009', '4/30/2009 23:59', 'S'
sp_rpt_timely_invoicing '4/1/2009', '4/30/2009 23:59', 'M'
sp_rpt_timely_invoicing '4/1/2009', '4/30/2009 23:59', 'S', '2,21'
sp_rpt_timely_invoicing '4/1/2009', '4/30/2009 23:59', 'S', '2|21,21|0'
sp_rpt_timely_invoicing '4/1/2009', '4/30/2009 23:59', 'S', null, '10673'
sp_rpt_timely_invoicing '4/1/2009', '4/30/2009 23:59', 'S', '2|21,21|0', '10673, 6243'

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
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

************************************************************/

AS

SET NOCOUNT ON

if @start_date is null or @end_date is null return

create table #full (
	source						varchar(40),
	source_id					int,
	company_id					int,
	profit_ctr_id				int,
	link_source_id				int,
	link_company_id				int,
	link_profit_ctr_id			int,
	link_flag					varchar(3),
	source_receipt_or_end_date	datetime,
	source_submitted_date		datetime,
	invoice_date_added			datetime,
	days_from_end_to_submit		float,
	days_from_submit_to_invoice	float,
	days_from_end_to_invoice	float,
	invoice_date				datetime,
	invoice_code				varchar(16),
	customer_id					int,
	cust_name					varchar(75),
	generator_id				int,
	generator_name				varchar(75),
	invoice_flag				varchar(40),
	intervention_desc			varchar(255),
	po_required_flag			char(1),
	qry							int
)

create table #facility_tmp (tmp varchar(6))
create table #facility_tmp2 (company_id int, profit_ctr_id int)
create table #facility_list (company_id int, profit_ctr_id int)
create index idx1 on #facility_list (company_id, profit_ctr_id)

create table #customer (customer_id int)
create index idx2 on #customer (customer_id)


if @facility_list is not null begin
	insert #facility_tmp (tmp)
		select row 
		from dbo.fn_SplitXsvText(',', 1, @facility_list)   
		where isnull(row, '') <> ''

	insert #facility_tmp2 (company_id, profit_ctr_id)
	select
		case when charindex('|', tmp) > 0 then
			convert(int, left(tmp, charindex('|', tmp)-1))
		else
			convert(int, tmp)
		end,
		case when charindex('|', tmp) > 0 then
			convert(int, right(tmp, len(tmp) - charindex('|', tmp)))
		else
			null
		end
	from #facility_tmp

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
end else begin
	insert #customer select customer_id from customer
end

IF @invoice_flag = 'S' begin
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
		left outer join 
			(select r1.receipt_id, r1.company_id, r1.profit_ctr_id, r1.receipt_date, max(r1.date_submitted) as date_submitted
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
		inner join invoiceheader ih 
			on b.invoice_id = ih.invoice_id and ih.status = 'I' 
			and ih.revision_id = (select max(revision_id) from invoiceheader ih1 where ih1.invoice_id = b.invoice_id)
-- This is to eliminate credits from the select:
			and ih.revision_id = (
				select max(ih1.revision_id)
				from invoiceheader ih1, invoiceheader ih2
				where ih1.invoice_id = b.invoice_id and ih1.status = 'I'
				and ih2.invoice_id = b.invoice_id and ih2.revision_id = 1
				and 7 >= (
					select abs(
						datediff(
							dd, 
							convert(datetime, datediff(dd, 0, ih1.date_added)), 
							convert(datetime, datediff(
								dd,	0, (
										select min(id.date_added)
										from invoicedetail id 
										where b.receipt_id = id.receipt_id 
										and b.company_id = id.company_id 
										and b.profit_ctr_id = id.profit_ctr_id 
										and b.trans_source = id.trans_source
			)	)	)	)	)	)	)		
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
		left outer join billinglinklookup bllr
			on bllr.receipt_id = b.receipt_id
			and bllr.company_id = b.company_id
			and bllr.profit_ctr_id = b.profit_ctr_id
			and b.trans_source = 'R'
	where b.invoice_date between @start_date and @end_date
	and b.status_code = 'I'
	and (cb.intervention_required_flag <> 'T' AND cb.invoice_flag <> 'M')

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
		left outer join 
			(select r1.receipt_id, r1.company_id, r1.profit_ctr_id, r1.receipt_date, max(r1.date_submitted) as date_submitted
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
		inner join invoiceheader ih 
			on b.invoice_id = ih.invoice_id and ih.status = 'I' 
			and ih.revision_id = (select max(revision_id) from invoiceheader ih1 where ih1.invoice_id = b.invoice_id)
-- This is to eliminate credits from the select:
			and ih.revision_id = (
				select max(ih1.revision_id)
				from invoiceheader ih1, invoiceheader ih2  			
				where ih1.invoice_id = b.invoice_id and ih1.status = 'I'
				and ih2.invoice_id = b.invoice_id and ih2.revision_id = 1
				and 7 >= (
					select abs(
						datediff(
							dd, 
							convert(datetime, datediff(dd, 0, ih1.date_added)), 
							convert(datetime, datediff(
								dd,	0, (
										select min(id.date_added)
										from invoicedetail id 
										where b.receipt_id = id.receipt_id 
										and b.company_id = id.company_id 
										and b.profit_ctr_id = id.profit_ctr_id 
										and b.trans_source = id.trans_source
			)	)	)	)	)	)	)		
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
		left outer join billinglinklookup bllr
			on bllr.receipt_id = b.receipt_id
			and bllr.company_id = b.company_id
			and bllr.profit_ctr_id = b.profit_ctr_id
			and b.trans_source = 'R'
	where b.invoice_date between @start_date and @end_date
	and b.status_code = 'I'
	and (cb.intervention_required_flag = 'T' OR cb.invoice_flag = 'M')

end

insert #full
select 
	'Division Average' as source,
	null as source_id,
	company_id,
	profit_ctr_id,
	null as link_source_id,
	null as link_company_id,
	null as link_profit_ctr_id,
	null as link_flag,
	null as source_receipt_or_end_date,
	null as source_submitted_date,
	null as invoice_date_added, -- use for calculations
	avg(days_from_end_to_submit),
	avg(days_from_submit_to_invoice),
	avg(days_from_end_to_invoice),
	null as invoice_date, -- Informational only
	null as invoice_code,
	null as customer_id,
	null as cust_name,
	null as generator_id,
	null as generator_name,
	null as invoice_flag,
	null as intervention_desc,
	null as po_required_flag,
	2 as qry
from #full
	group by company_id, profit_ctr_id
UNION
select 
	'Total Average' as source,
	null as source_id,
	null as company_id,
	null as profit_ctr_id,
	null as link_source_id,
	null as link_company_id,
	null as link_profit_ctr_id,
	null as link_flag,
	null as source_receipt_or_end_date,
	null as source_submitted_date,
	null as invoice_date_added, -- use for calculations
	avg(days_from_end_to_submit),
	avg(days_from_submit_to_invoice),
	avg(days_from_end_to_invoice),
	null as invoice_date, -- Informational only
	null as invoice_code,
	null as customer_id,
	null as cust_name,
	null as generator_id,
	null as generator_name,
	null as invoice_flag,
	null as intervention_desc,
	null as po_required_flag,
	3 as qry
from #full

set nocount off

-- select the results out to the user in a useful order.
select
	'' as [Average Per Facility],
	company_id as [Company],
	profit_ctr_id as [Profit Center],
	isnull(convert(varchar(40), days_from_end_to_submit), '') as [Days from WO end or Receipt Date to Submit Date],
	isnull(convert(varchar(40), days_from_submit_to_invoice), '') as [Days from Submit Date to Invoice Create Date],
	isnull(convert(varchar(40), days_from_end_to_invoice), '') as [Days from WO End or Receipt Date to Invoice Create Date]
from #full
	where qry in (2)
union
select
	'EQ Average',
	'',
	'',
	isnull(convert(varchar(40), days_from_end_to_submit), '') as [Days from WO end or Receipt Date to Submit Date],
	isnull(convert(varchar(40), days_from_submit_to_invoice), '') as [Days from Submit Date to Invoice Create Date],
	isnull(convert(varchar(40), days_from_end_to_invoice), '') as [Days from WO End or Receipt Date to Invoice Create Date]
from #full
	where qry in (3)
order by
	[Average Per Facility],
	company_id,
	profit_ctr_id

	
	select
	source as [Source],
	isnull(convert(varchar(40), source_id), '') as [Receipt or Workorder],
	isnull(convert(varchar(40), company_id), '') as [Company],
	isnull(convert(varchar(40), profit_ctr_id), '') as [Profit Center],
	isnull(convert(varchar(40), source_receipt_or_end_date, 101), '') as [WO end or Receipt Date],
	isnull(convert(varchar(40), source_submitted_date, 101), '') as [Submit Date],
	isnull(convert(varchar(40), invoice_date_added, 101), '') as [Invoice Create Date], -- use for calculations
	isnull(convert(varchar(40), days_from_end_to_submit), '') as [Days from WO end or Receipt Date to Submit Date],
	isnull(convert(varchar(40), days_from_submit_to_invoice), '') as [Days from Submit Date to Invoice Create Date],
	isnull(convert(varchar(40), days_from_end_to_invoice), '') as [Days from WO End or Receipt Date to Invoice Create Date],
	isnull(convert(varchar(40), invoice_date, 101), '') as [Invoice Date], -- Informational only
	isnull(invoice_code, '') as [Invoice],
	isnull(convert(varchar(40), customer_id), '') as [Customer Id],
	isnull(cust_name, '') as [Customer Name],
	isnull(convert(varchar(40), generator_id), '') as [Generator Id],
	isnull(generator_name, '') as [Generator Name],
	isnull(invoice_flag, '') as [Invoice Flag],
	isnull(intervention_desc, '') as [Intervention Description],
	isnull(po_required_flag, '') as [PO Required Flag],
	isnull(convert(varchar(3), link_flag), '') as [Link Flag],
	isnull(convert(varchar(40), link_source_id), '') as [Link Source Id],
	isnull(convert(varchar(40), link_company_id), '') as [Link Company Id],
	isnull(convert(varchar(40), link_profit_ctr_id), '') as [Link Profit Center]
from #full
	where qry in (1,3)
order by 
 	qry, 
	company_id, 
	profit_ctr_id
	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_timely_invoicing] TO [EQAI]
    AS [dbo];

