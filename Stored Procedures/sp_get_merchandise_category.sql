
create procedure sp_get_merchandise_category
	@merchandise_id int
as
/***************************************************************************************
 this procedure lists a Merchandise Category with Disposition, as well as all customer
 overriden dispositions

 loads to Plt_ai
 
 11/26/2008 - rb created
 12/02/2008 - removed MerchandiseCategoryXMerchandise table
 12/15/2008 - altered to display only customer dispositions (taking state overrides into  account)

****************************************************************************************/
set nocount on

create table #tmp (
category_id int null,
customer_id int null,
source varchar(20) null,
disposition_id int null
)

-- insert Customer overrides from MerchandiseCategoryCustomer table
insert #tmp
select m.category_id,
	mcc.customer_id,
	'Primary',
	mcc.disposition_id
from	Merchandise m,
	MerchandiseCategoryCustomer mcc
where	m.merchandise_id = @merchandise_id
and	m.category_id = mcc.category_id

-- update State mandated overrides of disposition
insert #tmp
select msc.category_id,
	t.customer_id,
	'State ' + msc.state,
	mc.default_disposition_id
from	#tmp t,
	MerchandiseStateCategory msc,
	MerchandiseCategory mc
where	msc.merchandise_id = @merchandise_id
and	msc.category_id = mc.category_id

update #tmp
set disposition_id = mcc.disposition_id
from #tmp t, MerchandiseCategoryCustomer mcc
where t.category_id = mcc.category_id
and t.customer_id = mcc.customer_id

select t.customer_id,
	c.cust_name,
	d.disposition_desc as cust_disposition_desc,
	t.source
from #tmp t, Customer c, Disposition d
where t.customer_id = c.customer_id
and t.disposition_id = d.disposition_id
order by c.cust_name, t.source

drop table #tmp

set nocount off

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_merchandise_category] TO [EQAI]
    AS [dbo];

