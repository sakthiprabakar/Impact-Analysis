
create procedure sp_get_profile_merchandise_cat
	@profile_id int
as
set nocount on
-- 04/19/2010	KAM		Updated the procedure to remove the bug where the
--						profile_id was hardcoded to 351077
-- 05/10/2017 AM - 1.Remove deprecated SQL and replace with appropriate SQL syntax.(*= to LEFT OUTER JOIN etc.). 


declare @customer_id int

-- get customer id
select @customer_id = customer_id
from Profile
where profile_id = @profile_id

-- create results table
create table #tmpresults (
profile_id int not null,
category_id int not null,
date_added datetime null,
added_by varchar(10) null,
date_modified datetime null,
modified_by varchar(10) null,
category_desc varchar(255) null,
base_disposition_desc varchar(255) null,
cust_disposition_desc varchar(255) null
)

-- query base cateogories with default dispositions
insert #tmpresults
select pxmc.profile_id,   
	pxmc.category_id,   
	pxmc.date_added,   
	pxmc.added_by,   
	pxmc.date_modified,   
	pxmc.modified_by,   
	mc.category_desc,
	d.disposition_desc as base_disposition_desc,
	convert(varchar(255),null) as cust_disposition_desc
from ProfileXMerchandiseCategory pxmc
INNER JOIN MerchandiseCategory mc ON pxmc.category_id = mc.category_id
LEFT OUTER JOIN Disposition d ON mc.default_disposition_id = d.disposition_id
where pxmc.profile_id = @profile_id

-- update with any customer-specific dispositions
update #tmpresults
set cust_disposition_desc = d.disposition_desc
from #tmpresults t,
	MerchandiseCategoryCustomer mcc,
	Disposition d
where t.category_id = mcc.category_id
and mcc.customer_id = @customer_id
and mcc.disposition_id = d.disposition_id

-- return results
set nocount off

select profile_id, category_id, date_added, added_by, date_modified, modified_by,
	category_desc, base_disposition_desc, cust_disposition_desc
from #tmpresults

drop table #tmpresults

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_profile_merchandise_cat] TO [EQAI]
    AS [dbo];

