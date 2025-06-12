
create procedure sp_rpt_workorder_extract (
    @customer_id_list   varchar(max),
    @start_date     datetime,
    @end_date       datetime
) as
/* *************************************
sp_rpt_workorder_extract
    WM-formatted export of trip data.
    Accepts input: 
        list of customer_ids (required)
        start_date (required) compares to workorder start_date
        end_date (required) compares to workorder start_date

sp_rpt_workorder_extract '13022', '4/1/2010', '6/30/2010'

    -- COPIED FROM NISOURCE EXTRACT FOR IAC (13022)
    --  This is the nisource extract
    --  The original was lost and this was re-created on 7-28-2008

    --  7-28-2008 LJT - extracted '01-01-2007' and '12-31-2007'
    --              - extracted '01-01-2008' and '03-31-2008'
    -- 10-06-2008 LJT - added approval description
    --              - extracted '04-01-2008' and '06-30-2008'
    -- 12-12-2008 LJT - added defined column labels
    --              - extracted '07-01-2008' and '09-30-2008'
    -- 12-22-2008 LJT - reran
    --              - extracted '07-01-2008' and '09-30-2008'
    -- 12-24-2008 LJT - reran after adding tsdf_approval_id as the key to tsdfapproval
    --              - extracted '07-01-2008' and '09-30-2008'
    -- 03-05-2009 LJT - extracted '10-01-2008' and '12-31-2008'
    -- 03-10-2009 LJT - re-extracted '10-01-2008' and '12-31-2008'
    -- 04-02-2009 LJT - extracted '01-01-2006' and '12-31-2006'
    -- 04-02-2009 LJT - extracted '01-01-2007' and '12-31-2007'
    -- 04-10-2009 LJT - Run the report for account numbers 10973 - 10984 for the dates 2006 through present
    -- 05-08-2009 LJT - extracted '01-01-2009' and '03-31-2009'
    -- 08-11-2009 LJT - extracted '04-01-2009' and '06-30-2009'
    -- 09-17-2009 LJT - extracted '07-01-2009' and '07-31-2009' Timken account for the month of July?  Customer number is 12263
    -- 01/29/2010 JPB - extracted '01-01-2009' through '12/31/2009' for Nisource.
    -- 02/03/2010 JPB - Added TSDF Name, Address, City, State, Zip, Ran for 2009 again.
	-- 11/08/2010 RJG - Replaced soon-to-be obsolete columns on WorkOrderDetail with WorkOrderDetailUnit
	-- 05/09/2011 RJG - Fixed error in query incorrectly using WorkOrderDetail.bill_unit instead of WorkOrderDetailUnit.bill_unit
	02/28/2013 - JPB - Added (nolock) hints
	
    --select wod.* from workorderheader woh
    --join workorderdetail wod on woh.workorder_id = wod.workorder_id
    --and woh.company_id = wod.company_id
    --and woh.profit_ctr_id = wod.profit_ctr_id
    -- where woh.customer_id between 10973 and 10984 and woh.workorder_status <> 'v' and woh.start_date > '01-01-2006' and woh.submitted_flag = 't'

************************************* */

-- Create tmp table to store the customer id's to report on
create table #customer (
    customer_id int
)

-- Convert input trip id list to #tmpTripID table
if isnull(@customer_id_list, '') <> '' begin
    Insert #customer
    select convert(int, row)
    from dbo.fn_SplitXsvText(',', 1, @customer_id_list)
    where isnull(row, '') <> ''
end

set @end_date = @end_date + 0.9999

select 
1 AS row_num,
wh.company_id as 'Company',
wh.profit_ctr_ID as 'Profit Center',
wh.workorder_ID as 'Work Order ID',
wd.tsdf_code as 'TSDF',
wd.tsdf_approval_code as 'TSDF Approval',
ta.waste_desc as ' Waste Desription',
cb.project_name as 'Project Name',
g.generator_name as 'Generator Name',
g.generator_address_1 as 'Generator Address 1',
g.generator_address_2 as 'Generator Address 2',
g.generator_address_3 as 'Generator Address 3',
g.generator_city as 'Generator City',
g.generator_state as 'Generator State',
g.generator_zip_code as 'Generator Zip Code',
wh.start_date as 'Workorder Start Date',
ds.disposal_service_desc as 'Disposal Method',
wt.description as 'Waste Type Description',
wt.category as 'Waste Type Category',
ta.RCRA_Haz_flag as 'RCRA Haz Flag',
wodu.quantity as 'Quantity',
wodu.bill_unit_code as 'Unit',
b.pound_conv as 'Pound Conversion',
isnull(wodu.quantity,0) * isnull(b.pound_conv,0) as 'total_pounds',
wodu.price as 'cost',
t.tsdf_name,
t.tsdf_addr1,
t.tsdf_addr2,
t.tsdf_addr3,
t.tsdf_city,
t.tsdf_state,
t.tsdf_zip_code
INTO #results
from workorderheader wh (nolock)
join workorderdetail wd (nolock) on wh.workorder_id = wd.workorder_id and wh.profit_ctr_id = wd.profit_ctr_id and wh.company_id = wd.company_id
join workorderdetailunit wodu (nolock) on wd.company_id = wodu.company_id and wd.profit_ctr_ID = wodu.profit_ctr_id and wd.workorder_ID = wodu.workorder_id and wd.sequence_ID = wodu.sequence_id and wodu.billing_flag = 'T'
----join customer c on wh.customer_id = c.customer_id
join customerbilling cb (nolock) on wh.customer_id = cb.customer_id and wh.billing_project_id = cb.billing_project_id
join generator g (nolock) on wh.generator_id = g.generator_id
join tsdf t (nolock) on wd.tsdf_code = t.tsdf_code and t.eq_flag = 'F'
join tsdfapproval ta (nolock) on wd.tsdf_approval_id = ta.tsdf_approval_id 
join billunit b (nolock) on wodu.Bill_unit_code = b.bill_unit_code and wodu.billing_flag = 'T'
left outer join disposalservice ds (nolock) on ta.disposal_service_id = ds.disposal_service_id
left outer join wastetype wt (nolock) on ta.wastetype_id = wt.wastetype_id

-- Normal Nisource customer
where wh.customer_id in (select customer_id from #customer)
--where wh.customer_id between 10973 and 10984
-- Special Timken customer
--  where wh.customer_id = 10877

and wd.resource_type = 'D'
and workorder_status = 'A' 
and submitted_flag = 'T'
--and wh.start_date between '05-28-2007' and '06-02-2007'
--and wh.start_date between '01-01-2008' and '03-31-2008'
--and wh.start_date between '01-01-2007' and '12-31-2007'
--and wh.start_date between '04-01-2008' and '06-30-2008'
--and wh.start_date between '07-01-2008' and '09-30-2008'
--and wh.start_date between  '01-01-2007' and '12-31-2007'
--and wh.start_date >  '01-01-2006'
-- and wh.start_date between  '07-01-2009' and '07-31-2009'
and wh.start_date between @start_date and @end_date

union

select 
2,
wh.company_id,
wh.profit_ctr_ID,
wh.workorder_ID,
wd.tsdf_code,
wd.tsdf_approval_code,
p.approval_desc,
cb.project_name,
g.generator_name,
g.generator_address_1,
g.generator_address_2,
g.generator_address_3,
g.generator_city,
g.generator_state,
g.generator_zip_code,
wh.start_date,
ds.disposal_service_desc as 'disposal_method',
wt.description as 'wastetype_description',
wt.category as 'wastetype_category',
p.RCRA_Haz_flag,
wodu.quantity,
wodu.bill_unit_code,
b.pound_conv,
isnull(wodu.quantity,0) * isnull(b.pound_conv,0) as 'total_pounds',
wodu.price as 'cost',
t.tsdf_name,
t.tsdf_addr1,
t.tsdf_addr2,
t.tsdf_addr3,
t.tsdf_city,
t.tsdf_state,
t.tsdf_zip_code

from workorderheader wh (nolock)
join workorderdetail wd (nolock) on wh.workorder_id = wd.workorder_id and wh.profit_ctr_id = wd.profit_ctr_id and wh.company_id = wd.company_id
join workorderdetailunit wodu (nolock) on wd.company_id = wodu.company_id and wd.profit_ctr_ID = wodu.profit_ctr_id and wd.workorder_ID = wodu.workorder_id and wd.sequence_ID = wodu.sequence_id and wodu.billing_flag = 'T'
--join customer c on wh.customer_id = c.customer_id
join customerbilling cb (nolock) on wh.customer_id = cb.customer_id and wh.billing_project_id = cb.billing_project_id
join generator g (nolock) on wh.generator_id = g.generator_id
join tsdf t (nolock) on wd.tsdf_code = t.tsdf_code
join profile p (nolock) on wd.profile_id = p.profile_id
join profilequoteapproval pqa (nolock) on pqa.profile_id = p.profile_id and t.eq_company = pqa.company_id and t.eq_profit_ctr = pqa.profit_ctr_id
join billunit b (nolock) on wodu.Bill_unit_code = b.bill_unit_code and wodu.billing_flag = 'T'
left outer join disposalservice ds (nolock) on pqa.disposal_service_id = ds.disposal_service_id
left outer join wastetype wt (nolock) on p.wastetype_id = wt.wastetype_id


--where wh.customer_id between 10973 and 10984
-- Nisource
where wh.customer_id in (select customer_id from #customer)
--where wh.customer_id between 10973 and 10984
-- Timken
-- where wh.customer_id = 12263

and wd.resource_type = 'D'
and workorder_status = 'A' 
and submitted_flag = 'T'
--and wh.start_date between '05-28-2007' and '06-02-2007'
--and wh.start_date between '01-01-2008' and '01-31-2008'
--and wh.start_date between '01-01-2008' and '03-31-2008'
--and wh.start_date between '01-01-2007' and '12-31-2007'
--and wh.start_date between '04-01-2008' and '06-30-2008'
--and wh.start_date between '07-01-2008' and '09-30-2008'
--and wh.start_date between  '01-01-2007' and '12-31-2007'
--and wh.start_date >  '01-01-2006'
-- and wh.start_date between  '07-01-2009' and '07-31-2009'
and wh.start_date between @start_date and @end_date
and t.eq_flag = 'T'

ORDER BY wh.start_date

DECLARE @n int = 0
UPDATE #results SET @n = row_num = @n + 1

SELECT * from #results 
--AND where [Work Order ID] = 1556600
ORDER BY [Workorder Start Date]


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_workorder_extract] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_workorder_extract] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_workorder_extract] TO [EQAI]
    AS [dbo];

