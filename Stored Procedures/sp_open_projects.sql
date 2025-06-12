create proc sp_open_projects
@company_id int,
@profit_ctr_id int,
@project_id_from int, 
@project_id_to int,
@debug_flag int = 0
as
/****************
This SP lists open projects and calculates the project cost per workorder and shows.

Test Cmd Line:  sp_open_projects 14, 9, 0

09/05/2003 PD Created
07/18/2006 rg revised for quoteheader quote detail
10/03/2007 rg revised to remove references to ntsql to repalce to alias server name
05/04/2010 JDB	Added databases 25 through 28.
06/24/2014 AM MOved to plt_ai

******************/
create table #project_summary (
project_id int null,
project_name varchar(100) null, 
ap_cost  money null, 
total_cost  money null
)

create table #wo (
        project_id int null,   
        record_id int null,
        project_name varchar(100) null, 
	total_price money null,
	total_cost money null,
	price_labor money null,
	cost_labor money null,
        profit_ctr_name varchar(50),
    expected_start_date datetime null,
    expected_end_date datetime null,
    quote_est_rev money null,
    total_billed  money null  )

/* Insert records */
insert #wo
select distinct 
pd.project_id,
pd.record_id,
pd.name,
total_price = woh.total_price,
total_cost = woh.total_cost,
null,
null,
'',
expected_start_date = pd.estimated_start_date,
expected_end_date = pd.estimated_end_date   ,
pd.orig_quoted_amt,null
from workorderheader woh, projectdetail pd
where woh.workorder_status not in ('V', 'R','T')
and woh.project_id = pd.project_id
and woh.company_id = pd.company_id
and pd.status  = 'O'
and pd.project_id >= @project_id_from and pd.project_id <= @project_id_to 
and pd.company_id = @company_id


--Create Summary Table 
insert #project_summary
select distinct project_id,
project_name, 
0.00, 
0.00
from #wo 



--update ap information

if @company_id = 2
   update #project_summary set ap_cost = (select sum (vh.amt_paid_to_date)         
     from NTSQLFINANCE.e02.dbo.apvohdr vh, NTSQLFINANCE.e02.dbo.pur_list p , projectdetail pd
   where vh.po_ctrl_num = p.po_no 
	and p.reference_code = pd.po_glratyp
        and #project_summary.project_id = pd.project_id )

if @company_id = 3
   update #project_summary  set ap_cost = (select sum (vh.amt_paid_to_date) 
     from NTSQLFINANCE.e03.dbo.apvohdr vh, NTSQLFINANCE.e03.dbo.pur_list p, projectdetail pd 
   where vh.po_ctrl_num = p.po_no 
        and p.reference_code = pd.po_glratyp
	and  #project_summary.project_id = pd.project_id )

if @company_id = 12
   update #project_summary  set ap_cost = (select sum (vh.amt_paid_to_date) 
     from NTSQLFINANCE.e12.dbo.apvohdr vh, NTSQLFINANCE.e12.dbo.pur_list p, projectdetail pd 
   where vh.po_ctrl_num = p.po_no 
        and p.reference_code = pd.po_glratyp
	and  #project_summary.project_id = pd.project_id )

if @company_id = 14
   update #project_summary  set ap_cost = (select sum (vh.amt_paid_to_date) 
     from NTSQLFINANCE.e14.dbo.apvohdr vh, NTSQLFINANCE.e14.dbo.pur_list p, projectdetail pd 
   where vh.po_ctrl_num = p.po_no 
        and p.reference_code = pd.po_glratyp
	and  #project_summary.project_id = pd.project_id )

if @company_id = 15
   update #project_summary  set ap_cost = (select sum (vh.amt_paid_to_date) 
     from NTSQLFINANCE.e15.dbo.apvohdr vh, NTSQLFINANCE.e15.dbo.pur_list p , projectdetail pd
where vh.po_ctrl_num = p.po_no 
        and p.reference_code = pd.po_glratyp
	and  #project_summary.project_id = pd.project_id )

if @company_id = 17
   update #project_summary  set ap_cost = (select sum (vh.amt_paid_to_date) 
     from NTSQLFINANCE.e17.dbo.apvohdr vh, NTSQLFINANCE.e17.dbo.pur_list p , projectdetail pd
where vh.po_ctrl_num = p.po_no 
        and p.reference_code = pd.po_glratyp
	and  #project_summary.project_id = pd.project_id )

if @company_id = 18
   update #project_summary  set ap_cost = (select sum (vh.amt_paid_to_date) 
     from NTSQLFINANCE.e18.dbo.apvohdr vh, NTSQLFINANCE.e18.dbo.pur_list p , projectdetail pd
where vh.po_ctrl_num = p.po_no 
        and p.reference_code = pd.po_glratyp
	and  #project_summary.project_id = pd.project_id )
	
if @company_id = 21
   update #project_summary  set ap_cost = (select sum (vh.amt_paid_to_date) 
     from NTSQLFINANCE.e21.dbo.apvohdr vh, NTSQLFINANCE.e21.dbo.pur_list p , projectdetail pd
where vh.po_ctrl_num = p.po_no 
        and p.reference_code = pd.po_glratyp
	and  #project_summary.project_id = pd.project_id )
	
if @company_id = 22
   update #project_summary  set ap_cost = (select sum (vh.amt_paid_to_date) 
     from NTSQLFINANCE.e22.dbo.apvohdr vh, NTSQLFINANCE.e22.dbo.pur_list p , projectdetail pd
where vh.po_ctrl_num = p.po_no 
        and p.reference_code = pd.po_glratyp
	and  #project_summary.project_id = pd.project_id )
	
if @company_id = 23
   update #project_summary  set ap_cost = (select sum (vh.amt_paid_to_date) 
     from NTSQLFINANCE.e23.dbo.apvohdr vh, NTSQLFINANCE.e23.dbo.pur_list p , projectdetail pd
where vh.po_ctrl_num = p.po_no 
        and p.reference_code = pd.po_glratyp
	and  #project_summary.project_id = pd.project_id )
	
if @company_id = 24
   update #project_summary  set ap_cost = (select sum (vh.amt_paid_to_date) 
     from NTSQLFINANCE.e24.dbo.apvohdr vh, NTSQLFINANCE.e24.dbo.pur_list p , projectdetail pd
where vh.po_ctrl_num = p.po_no 
        and p.reference_code = pd.po_glratyp
	and  #project_summary.project_id = pd.project_id )
	
if @company_id = 25
   update #project_summary  set ap_cost = (select sum (vh.amt_paid_to_date) 
     from NTSQLFINANCE.e25.dbo.apvohdr vh, NTSQLFINANCE.e25.dbo.pur_list p , projectdetail pd
where vh.po_ctrl_num = p.po_no 
        and p.reference_code = pd.po_glratyp
	and  #project_summary.project_id = pd.project_id )
	
if @company_id = 26
   update #project_summary  set ap_cost = (select sum (vh.amt_paid_to_date) 
     from NTSQLFINANCE.e26.dbo.apvohdr vh, NTSQLFINANCE.e26.dbo.pur_list p , projectdetail pd
where vh.po_ctrl_num = p.po_no 
        and p.reference_code = pd.po_glratyp
	and  #project_summary.project_id = pd.project_id )
	
if @company_id = 27
   update #project_summary  set ap_cost = (select sum (vh.amt_paid_to_date) 
     from NTSQLFINANCE.e27.dbo.apvohdr vh, NTSQLFINANCE.e27.dbo.pur_list p , projectdetail pd
where vh.po_ctrl_num = p.po_no 
        and p.reference_code = pd.po_glratyp
	and  #project_summary.project_id = pd.project_id )
	
if @company_id = 28
   update #project_summary  set ap_cost = (select sum (vh.amt_paid_to_date) 
     from NTSQLFINANCE.e28.dbo.apvohdr vh, NTSQLFINANCE.e28.dbo.pur_list p , projectdetail pd
where vh.po_ctrl_num = p.po_no 
        and p.reference_code = pd.po_glratyp
	and  #project_summary.project_id = pd.project_id )






-- This replaces the total cost that had estimates for AP in it.
update #project_summary set total_cost = ap_cost + (select sum ( cost_labor ) from #wo where #wo.project_id = #project_summary.project_id)

-- Update project information
update #project_summary set project_id = p.project_id, project_name = p.name 
from #project_summary ps, project p
where ps.project_id = p.project_id 

-- Update quote information
update #wo set quote_est_rev = q.total_price
from #wo, workorderquoteheader q , project p, projectdetail pd
where quote_type = 'p' 
and pd.project_id = p.project_id 
and #wo.project_id = pd.project_id
and #wo.record_id = pd.record_id
and q.quote_id = pd.quote_id
and ( #wo.quote_est_rev is null)

update #wo set total_billed = woh.total_price
from #wo, workorderheader woh
where #wo.project_id = woh.project_id
and #wo.record_id = woh.project_record_id

update wo set cost_labor =  ( select sum( hours * cost ) from ResourcePayroll rp
where wo.project_id = rp.project_id
  and wo.record_id = rp.project_record_id 
group by rp.project_id, rp.project_record_id)
from projectdetail pd, #wo wo
where pd.project_id = wo.project_id
and pd.record_id = wo.record_id


select distinct
wo.project_id,
ps.project_name, 
price_labor = wo.price_labor ,
wo.total_billed,
wo.cost_labor,
ps.total_cost,
ps.ap_cost, 
wo.quote_est_rev, 
wo.profit_ctr_name,
wo.expected_start_date,
wo.expected_end_date,
wo.project_name,
wo.record_id
from #wo wo, #project_summary ps 
where wo.project_id = ps.project_id

drop table #wo
drop table #project_summary



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_open_projects] TO [EQAI]
    AS [dbo];

