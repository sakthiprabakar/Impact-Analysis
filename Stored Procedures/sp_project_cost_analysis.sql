create proc sp_project_cost_analysis
@cust_id_from int, 
@cust_id_to int, 
@project_id_from int, 
@project_id_to int,
@company_id int,
@profit_ctr_id int,
@debug_flag int = 0
as
/****************
This SP calculates the project cost per workorder and shows.

Test Cmd Line:  sp_project_cost_analysis 0, 999999, 1, 5 ,14, 9, 0

06/20/2003 LJT Created
09/22/2004 LJT replace voucher vh.amt_paid_to_date with vh.amt_net.
10/13/2004 LJT Modified teh AP actual amount select to have sub selects.  Was retrieving to many records.
10/18/2004 LJT Added join by profit center id
12/08/2004 MK  Replaced Ticket table with Billing table
07/18/2006 rg  revised for quoteheader, qoutedetail
10/03/2007 rg  replaced references of NTSQL5 to alias server
11/14/2007 rg  revised for workorder_status and submitted_flag
05/04/2010 JDB	Added databases 25 through 28.
06/24/2014 AM MOved to plt_ai
******************/
create table #project_summary (
project_id int null,
project_name varchar(100) null, 
total_billed  money null, 
percent_complete  money null, 
Rev_Recognized  money null, 
Billed_variance  money null, 
ap_cost  money null,
total_cost money null,
quote_est_rev money null,
quote_est_cost money null,
quote_grand_rev money null,
quote_grand_cost money null
)

create table #wo (
        project_id int null, 
        project_name varchar(100) null, 
        project_record_id int null,
	workorder_id int null,
	workorder_status char(1) null,
	invoice_code varchar(16) null,  
        total_price money null, 
        total_cost money null,
	customer_id int null,
	cust_discount float null,
	price_equipment money null,
	price_labor money null,
	price_supplies money null,
	price_disposal money null,
	price_group money null,
	price_other money null,
	cost_equipment money null,
	cost_labor money null,
	cost_supplies money null,
	cost_disposal money null,
	cost_other money null,
	gross_margin decimal(7,4) NULL,
        profit_ctr_name varchar(50)
	--quote_est_rev money null, 
	--quote_est_cost  money null,  
)

create table #quote (
project_id int null,
est_rev money null,
est_cost money null
)

/* Insert records */
insert #wo
select 
pd.project_id,
pd.name,
woh.project_record_id,
woh.workorder_id,
CASE WHEN ISNULL(woh.submitted_flag, 'F') = 'T' 
		THEN 'X'
		ELSE woh.workorder_status
		END AS workorder_status,
'',
Round(woh.total_price,2),
Round(woh.total_cost,2),
woh.customer_id,
woh.cust_discount, 
price_equipment = Round(ISNULL((select sum( quantity_used * price ) from workorderDetail wod 
 	where woh.workorder_id = wod.workorder_id 
	and woh.profit_ctr_id = wod.profit_ctr_id
	and woh.company_id = wod.company_id
 	and bill_rate > 0 
 	and wod.resource_type = 'E'), 0),2),
price_labor = Round(ISNULL((select sum( quantity_used * price ) from workorderDetail wod 
	where woh.workorder_id = wod.workorder_id 
	and woh.profit_ctr_id = wod.profit_ctr_id
	and woh.company_id = wod.company_id 
	and bill_rate > 0 
	and wod.resource_type = 'L'), 0),2),
price_supplies = Round(ISNULL((select sum( quantity_used * price ) from workorderDetail wod 
	where woh.workorder_id = wod.workorder_id 
	and woh.profit_ctr_id = wod.profit_ctr_id
	and woh.company_id = wod.company_id
	and bill_rate > 0 
	and wod.resource_type = 'S'), 0),2),
price_disposal = Round(ISNULL((select sum(quantity_used * price ) from workorderDetail wod 
	where woh.workorder_id = wod.workorder_id 
	and woh.profit_ctr_id = wod.profit_ctr_id
	and woh.company_id = wod.company_id
	and bill_rate > 0 
	and wod.resource_type = 'D'), 0),2),
price_group = 0,
price_other = Round(ISNULL((select sum(quantity_used * price ) from workorderDetail wod 
	where woh.workorder_id = wod.workorder_id 
	and woh.profit_ctr_id = wod.profit_ctr_id
	and woh.company_id = wod.company_id
	and bill_rate > 0
	and wod.resource_type = 'O'), 0),2),
 cost_equipment = Round(ISNULL((select sum( quantity_used * cost ) from workorderDetail wod 
 	where woh.workorder_id = wod.workorder_id 
	and woh.profit_ctr_id = wod.profit_ctr_id
	and woh.company_id = wod.company_id
 	and wod.resource_type = 'E'), 0),2),
cost_labor = Round(ISNULL((select sum( hours * cost ) from ResourcePayroll
	where woh.project_id = ResourcePayroll.project_id
	and woh.project_record_id = ResourcePayroll.project_record_id
	), 0),2),
cost_supplies = Round(ISNULL((select sum( quantity_used * cost ) from workorderDetail wod 
	where woh.workorder_id = wod.workorder_id 
	and woh.profit_ctr_id = wod.profit_ctr_id
	and woh.company_id = wod.company_id
 	and wod.resource_type = 'O'	and wod.resource_type = 'S'), 0),2),
cost_disposal = Round(ISNULL((select sum( quantity_used * cost ) from workorderDetail wod, TSDF  
	where woh.workorder_id = wod.workorder_id 
	and woh.profit_ctr_id = wod.profit_ctr_id
	and woh.company_id = wod.company_id
 	and wod.resource_type = 'O'	and wod.resource_type = 'D'
        and wod.tsdf_code = tsdf.tsdf_code
        and tsdf.eq_company is not null), 0),2),
cost_other = Round(ISNULL((select sum( quantity_used * wod.cost ) from workorderDetail wod, resourceclass rc 
	where woh.workorder_id = wod.workorder_id 
	and woh.profit_ctr_id = wod.profit_ctr_id
	and woh.company_id = wod.company_id
 	and wod.resource_type = 'O'
	and wod.resource_class_code = rc.resource_class_code
        and ( ISNULL(wod.requisition, '') = '')),0),2),
case Round(ISNULL(total_price, 0),2) when 0 then 0
	else round(((convert(float,total_price) -  convert(float,total_cost) ) /  convert(float,total_price) ) * 100, 2) end as gross_margin, '' 
--pd.orig_quoted_amt, 
--pd.orig_quoted_cost
from workorderheader woh, Customer, projectdetail pd
/* REMOVED BECAUSE FORECASTED PRICING NOT ASSIGNED where woh.workorder_status in ('X','A','P','C','D') */
where woh.workorder_status not in ('V','R','T')
--and woh.end_date between @date_from and @date_to
and woh.project_id between @project_id_from and @project_id_to
and woh.customer_id = Customer.customer_id
and pd.project_id = woh.project_id
and pd.record_id = woh.project_record_id
--and woh.profit_ctr_id = @profit_ctr_id


if @debug_flag = 1 print 'Selecting from #wo'
if @debug_flag = 1 select gross_margin, * from #wo order by customer_id

/* Result Set 
select #wo.*, billing.invoice_code, customer.cust_name from #wo, billing, customer 
where #wo.workorder_id *= billing.receipt_id and #wo.customer_id = customer.customer_id
*/

-- update billing information
update #wo set invoice_code = billing.invoice_code 
from #wo, billing
where  billing.profit_ctr_id = @profit_ctr_id
and billing.company_id = @company_id
and #wo.workorder_id = billing.receipt_id 
and billing.trans_source = 'W'

--Create Summary Table 
insert #project_summary
select distinct #wo.project_id,
project.name, 
0.00, 
0.00, 
0.00, 
0.00, 
0.00, 
0.00,
0.00,
0.00,
0.00,
0.00
from #wo , project
where #wo.project_id = project.project_id


if @company_id = 2
   update #project_summary set ap_cost = (select sum (vh.amt_net) 
   from NTSQLFINANCE.e02.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e02.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 3
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
  from NTSQLFINANCE.e03.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e03.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 12
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
  from NTSQLFINANCE.e12.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e12.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 14
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
     from NTSQLFINANCE.e14.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e14.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 15
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
  from NTSQLFINANCE.e15.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e15.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 17
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
  from NTSQLFINANCE.e17.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e17.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 18
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
  from NTSQLFINANCE.e18.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e18.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 20
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
  from NTSQLFINANCE.e20.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e20.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 21
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
  from NTSQLFINANCE.e21.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e21.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 22
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
  from NTSQLFINANCE.e22.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e22.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 23
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
  from NTSQLFINANCE.e23.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e23.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 24
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
  from NTSQLFINANCE.e24.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e24.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 25
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
  from NTSQLFINANCE.e25.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e25.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 26
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
  from NTSQLFINANCE.e26.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e26.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 27
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
  from NTSQLFINANCE.e27.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e27.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))

if @company_id = 28
   update #project_summary  set ap_cost = (select sum (vh.amt_net) 
  from NTSQLFINANCE.e28.dbo.apvohdr vh
   where vh.po_ctrl_num in (Select p.po_no from NTSQLFINANCE.e28.dbo.pur_list p
        where  p.reference_code in (select convert(varchar(10),pd.project_id)+'-'+convert(varchar(10),pd.record_id) from projectdetail pd 
	where  #project_summary.project_id = pd.project_id )))


-- This replaces the total cost that had estimates for AP in it.
update #project_summary set total_cost = isnull(ap_cost,0) + (select sum (isnull(cost_equipment,0) + isnull(cost_labor,0) + isnull(cost_supplies,0) + isnull(cost_disposal,0) + isnull(cost_other,0) ) from #wo where #wo.project_id = #project_summary.project_id)

-- update calculations
--case ISNULL(quote_est_costs, 0) when 0 then 0
--	else total_cost / quote_est_cost end as percent_complete

-- Update quote information  ( for project linked with an existing quote )

-- update #project_summary set quote_est_rev = q.total_price
-- from quoteheader q , projectdetail pd
-- where q.quote_id = pd.quote_id
-- and ( #project_summary.quote_est_rev is null or #project_summary.quote_est_cost = 0)

insert #quote
select pd.project_id, sum(Round(qh.total_price,2)), sum(Round(qh.total_cost,2))
from projectdetail pd, Workorderquoteheader qh, #project_summary
where pd.quote_id = qh.quote_id
and #project_summary.project_id = pd.project_id
--group by #project_summary.project_id
group by pd.project_id

update ps set quote_est_rev = Round(q.est_rev,2)
from #project_summary ps, #quote q
where ps.project_id = q.project_id
and ( ps.quote_est_rev is null or ps.quote_est_rev = 0)

update ps set quote_est_cost = Round(q.est_cost,2)
from #project_summary ps, #quote q
where ps.project_id = q.project_id
and ( ps.quote_est_cost is null or ps.quote_est_cost = 0)

update #project_summary set quote_grand_rev = ( select Round(sum(est_rev),2) from #quote )
update #project_summary set quote_grand_cost = ( select Round(sum(est_cost),2) from #quote )


update #project_summary 
set percent_complete = Round(#project_summary.total_cost / #project_summary.quote_est_cost,2)  
where #project_summary.quote_est_cost > 0


update #project_summary 
set rev_recognized = Round(quote_est_rev * percent_complete,2)


update #project_summary set total_billed = (select Round(sum(#wo.total_price),2) from #wo where #wo.project_id = #project_summary.project_id)

update #project_summary set billed_variance = Round(total_billed - rev_recognized,2)

update #wo
set #wo.profit_ctr_name = profitcenter.profit_ctr_name
from profitcenter
where profitcenter.profit_ctr_id = @profit_ctr_id
and profitcenter.company_id = @company_id
-- 
select distinct
wo.project_id,
ps.project_name, 
customer.cust_name,
wo.workorder_status,
wo.workorder_id,
wo.invoice_code,
wo.customer_id,
wo.cust_discount, 
price_equipment = Round(wo.price_equipment * ((100 - wo.cust_discount) / 100),2),
price_labor = Round(wo.price_labor * ((100 - wo.cust_discount) / 100),2),
price_disposal = Round(wo.price_disposal * ((100 - wo.cust_discount) / 100),2),
price_group = Round(wo.price_group * ((100 - wo.cust_discount) / 100),2),
price_other = Round(wo.price_other * ((100 - wo.cust_discount) / 100),2),
--ps.total_billed,
Round(wo.total_price,2),
Round(wo.cost_equipment,2),
Round(wo.cost_labor,2),
Round(wo.cost_supplies,2),
Round(wo.cost_disposal,2),
Round(wo.cost_other,2),
Round(ps.total_cost,2),
Round(ps.ap_cost,2), 
Round(ps.quote_est_rev,2), 
Round(ps.quote_est_cost,2), 
Round(ps.Percent_complete,2),
Round(ps.Rev_Recognized,2),
Round(ps.Billed_variance,2),
Round(wo.gross_margin,2),
wo.profit_ctr_name,
Round(ps.quote_grand_rev,2),
Round(ps.quote_grand_cost,2)
from #wo wo, customer, #project_summary ps
where wo.customer_id = customer.customer_id 
and wo.project_id = ps.project_id

--

drop table #wo
drop table #project_summary
drop table #quote



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_project_cost_analysis] TO [EQAI]
    AS [dbo];

