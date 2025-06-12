
create proc sp_merchandise_report (
	@search			varchar(60) = null,
	@merchandise_id	int = null,
	@customer_id	varchar(255) = null,
	@contact_id		int = null,
	@format			char(1) = 'W'
) as
/* ******************************************************************
sp_merchandise_report : returns header/detail info combined for web report display

2/24/2010 - JPB - Created.

select * from MerchandiseCode where merchandise_id = 169878

exec sp_merchandise_report 'mstr blossom 13', NULL, '', NULL, 'W'

sp_merchandise_report
sp_merchandise_report '2456'
sp_merchandise_report 'star wars figure', null, '', null, 'L'
sp_merchandise_report 'aveeno bdy', null, '', null, 'L'
sp_merchandise_report '01980040129'
sp_merchandise_report 'windex', null, '12493', null, 'W'
sp_merchandise_report '61205', null, '12493', null, 'W'
sp_merchandise_report '01980040129', null, '12493'
sp_merchandise_report '', null, '12493', null, 'E'
sp_merchandise_report '', null, '12493', NULL, 'E'

sp_merchandise_report null, 110020, '', null, 'D'

exec sp_merchandise_report 'aveeno', null, NULL, NULL, 'E'
exec sp_merchandise_report '', null, '', NULL, 'E'
exec sp_merchandise_report NULL, null, NULL, NULL, 'L'

sp_merchandise_report '', null, '12493', NULL, 'R'
sp_merchandise_report '', null, '888880', NULL, 'M'

****************************************************************** */

set nocount on

-- temp tables to split up input code & customer values:
create table #customer (customer_id int)

-- temp table to hold preliminary results for output
create table #prelim (customer_id int, merchandise_id int, merchandise_code varchar(60))

-- split customers into temp table
if isnull(@customer_id, '') <> '' and isnull(@contact_id, 0) = 0 -- You can only specify customers if you're not a contact
	insert #customer
	select convert(int, row)
	from dbo.fn_SplitXsvText(',', 1, @customer_id)
	where isnull(row, '') <> ''
else if isnull(@customer_id, '') <> '' and isnull(@contact_id, 0) > 0 -- if you tried anyway, you fail.
	insert #customer values (-1)

if isnull(@customer_id, '') = '' and isnull(@contact_id, 0) > 0 begin -- Contacts get all their own customers
	insert #customer 
	select distinct customer_id from contactxref where contact_id = @contact_id
	and web_access = 'A' and status = 'A' and type = 'C'
	union -- This also includes the merch for the actual customer of a generator you have access to.  Seems weird??
	select distinct cg.customer_id from customergenerator cg
	inner join contactxref x on x.generator_id = cg.generator_id
	where x.contact_id = @contact_id
	and x.web_access = 'A' and x.status = 'A' and x.type = 'G'
	if @@rowcount = 0 insert #customer values (-1)
end
	
-- Get prelim results.  Could've done this in dynamic sql.  
-- But this is how I first thought of it.  Dyn. SQL may still be better if the inputs grow.
-- But as ugly as this is, Dyn SQL would have to do the same thing,
--  and then have the performance penalty of being dynamic.
if isnull(@search, '') <> ''
	if exists (select 1 from #customer where customer_id is not null)
		-- Given a customer_id and given a description:
		insert #prelim
		select y.customer_id, y.merchandise_id, mc.merchandise_code
		from merchandisecode mc
		inner join (
			select mc.merchandise_id, mc.customer_id
			from merchandisecode mc
			inner join #customer c on mc.customer_id = c.customer_id
		) y on mc.merchandise_id = y.merchandise_id
		inner join merchandise m on mc.merchandise_id = m.merchandise_id
		where (merchandise_desc like '%' + replace(ltrim(rtrim(@search)), ' ', '%') + '%'
		or merchandise_code like '%' + replace(ltrim(rtrim(@search)), ' ', '%') + '%')
	else
		-- Given NO customer_id, and given a description:
		insert #prelim
		select null, mc.merchandise_id, mc.merchandise_code
		from merchandisecode mc
		inner join merchandise m on mc.merchandise_id = m.merchandise_id
		where (merchandise_desc like '%' + replace(ltrim(rtrim(@search)), ' ', '%') + '%'
		or merchandise_code like '%' + replace(ltrim(rtrim(@search)), ' ', '%') + '%')
else
	-- Given NO customer_id, Given NO code, and given NO description 
	if @format = 'D'
		if exists (select 1 from #customer where customer_id is not null)
			insert #prelim
			select customer_id, merchandise_id, merchandise_code
			from merchandisecode
			where merchandise_id = @merchandise_id
			and customer_id in (select customer_id from #customer where customer_id is not null)
		else
			insert #prelim
			select top 1 null, merchandise_id, merchandise_code
			from merchandisecode
			where merchandise_id = @merchandise_id
	else
		if @format IN ('E', 'M')
			if exists (select 1 from #customer where customer_id is not null)
				insert #prelim
				select customer_id, merchandise_id, merchandise_code
				from merchandisecode
				where customer_id in (select customer_id from #customer where customer_id is not null)
			else
				insert #prelim values (-1, -1, -1)
		else
			if @format='R'
				if exists (select 1 from #customer where customer_id is not null)
					insert #prelim
					select top 10000 customer_id, merchandise_id, merchandise_code
					from merchandisecode
					where customer_id in (select customer_id from #customer where customer_id is not null)
				else
					insert #prelim values (-1, -1, -1)
			else
				insert #prelim values (-1, -1, -1)
	/*
	But the query for it would be...
	insert #prelim
	select null, mc.merchandise_id
	from merchandisecode mc
	*/
-- end of prelim population
set nocount off

-- select distinct * from #prelim
-- return

if @format = 'L' begin -- List
-- If the requested format is 'W' (web):
	-- Crunches all lists of id's together instead of subqueries
	-- Combining the separate codes into lists reeeeally slows this down.
	-- Better to do it in the actual page display routine, but here's Proof of Concept...
	
	select distinct
		(select count(distinct merchandise_id) from #prelim) as merch_count,
		p.customer_id,
		cust.cust_name,
		m.merchandise_id,   
		m.merchandise_desc,   
		mcat.category_desc,   
		convert(varchar(300), m.dot_shipping_name) as dot_shipping_name,  
		man.manufacturer_name,
		d.disposition_desc,
		case mc.code_type
			when 'U' then 'UPC'
			when 'N' then 'NDC'
			when 'C' then 'SKU'
		end as code_type,
		mc.merchandise_code
		,case when exists (
			select 1 
			from plt_image.dbo.scan 
			where merchandise_id = m.merchandise_id
			and view_on_web = 'T'
			and status = 'A'
		) then 'T' else 'F' end as has_scans
	from 
		#prelim p
		inner join merchandise m on m.merchandise_id = p.merchandise_id
		inner join merchandisecategory mcat on m.category_id = mcat.category_id
		inner join merchandisecode mc on p.merchandise_id = mc.merchandise_id and p.merchandise_code = mc.merchandise_code
		left outer join MerchandiseCategoryCustomer mcc on m.category_id = mcc.category_id
			and mcc.customer_id = p.customer_id
		left outer join disposition d on isnull(mcc.disposition_id, mcat.default_disposition_id) = d.disposition_id
		left outer join manufacturer man on m.manufacturer_id = man.manufacturer_id
		left outer join customer cust on p.customer_id = cust.customer_id
	order by
		cust.cust_name,
		p.customer_id,
		m.merchandise_desc,
		mcat.category_desc
end

if @format = 'D' begin -- Detail
select distinct
		p.customer_id,
		cust.cust_name,
		m.merchandise_id,   
		m.merchandise_desc,   
		mcat.category_desc,   
		convert(varchar(300), m.dot_shipping_name) as dot_shipping_name,  
		man.manufacturer_name,
		d.disposition_desc
		,dbo.fn_merchandise_id_code_list(m.merchandise_id, 'U', p.customer_id) as upc_code_list
		,dbo.fn_merchandise_id_code_list(m.merchandise_id, 'N', p.customer_id) as ndc_code_list
		,dbo.fn_merchandise_id_code_list(m.merchandise_id, 'C', p.customer_id) as cust_code_list
		,case when exists (
			select 1 
			from plt_image.dbo.scan 
			where merchandise_id = m.merchandise_id
			and view_on_web = 'T'
			and status = 'A'
		) then 'T' else 'F' end as has_scans
	from 
		merchandise m
		inner join merchandisecategory mcat on m.category_id = mcat.category_id
		inner join merchandisecode mc on m.merchandise_id = mc.merchandise_id
		inner join #prelim p on m.merchandise_id = p.merchandise_id and mc.merchandise_code = p.merchandise_code
		left outer join MerchandiseCategoryCustomer mcc on m.category_id = mcc.category_id
			and mcc.customer_id = p.customer_id
		left outer join disposition d on isnull(mcc.disposition_id, mcat.default_disposition_id) = d.disposition_id
		left outer join manufacturer man on m.manufacturer_id = man.manufacturer_id
		left outer join customer cust on p.customer_id = cust.customer_id
	where
		m.merchandise_id = @merchandise_id
		and exists (select 1 from #prelim where merchandise_id = @merchandise_id)
	order by
		cust.cust_name,
		p.customer_id,
		m.merchandise_desc,
		mcat.category_desc
end

if @format = 'R' begin -- Report
select distinct top 10000 
		p.customer_id,
		cust.cust_name,
		m.merchandise_id,   
		m.merchandise_desc,   
		mcat.category_desc,   
		convert(varchar(300), m.dot_shipping_name) as dot_shipping_name,  
		man.manufacturer_name,
		d.disposition_desc
		,dbo.fn_merchandise_id_code_list(m.merchandise_id, 'U', p.customer_id) as upc_code_list
		,dbo.fn_merchandise_id_code_list(m.merchandise_id, 'N', p.customer_id) as ndc_code_list
		,dbo.fn_merchandise_id_code_list(m.merchandise_id, 'C', p.customer_id) as cust_code_list
	from 
		#prelim p
		inner join merchandise m on m.merchandise_id = p.merchandise_id
		inner join merchandisecategory mcat on m.category_id = mcat.category_id
		inner join merchandisecode mc on p.merchandise_id = mc.merchandise_id and p.merchandise_code = mc.merchandise_code
		left outer join MerchandiseCategoryCustomer mcc on m.category_id = mcc.category_id
			and mcc.customer_id = p.customer_id
		left outer join disposition d on isnull(mcc.disposition_id, mcat.default_disposition_id) = d.disposition_id
		left outer join manufacturer man on m.manufacturer_id = man.manufacturer_id
		left outer join customer cust on p.customer_id = cust.customer_id
	order by
		cust.cust_name,
		p.customer_id,
		m.merchandise_desc,
		mcat.category_desc
end

if @format = 'E' begin -- export
	-- Non-web format 
	-- Returns a row per combination
	select distinct
		p.customer_id,
		cust.cust_name,
		m.merchandise_id,   
		m.merchandise_desc,   
		mcat.category_desc,   
		convert(varchar(300), m.dot_shipping_name) as dot_shipping_name,  
		man.manufacturer_name,
		d.disposition_desc,
		mc.code_type,
		mc.merchandise_code
	from 
		#prelim p
		inner join merchandise m on m.merchandise_id = p.merchandise_id
		inner join merchandisecategory mcat on m.category_id = mcat.category_id
		left outer join MerchandiseCategoryCustomer mcc on m.category_id = mcc.category_id
			and mcc.customer_id = p.customer_id
		left outer join disposition d on isnull(mcc.disposition_id, mcat.default_disposition_id) = d.disposition_id
		left outer join manufacturer man on m.manufacturer_id = man.manufacturer_id
		left outer join merchandisecode mc on m.merchandise_id = mc.merchandise_id and (mc.customer_id is null or mc.customer_id in (select customer_id from #customer))
		left outer join customer cust on p.customer_id = cust.customer_id
	order by
		cust.cust_name,
		p.customer_id,
		m.merchandise_desc,
		mcat.category_desc
end

if @format = 'M' begin -- merge
	-- Returns a row per sku & code combination
	select distinct
		m.merchandise_id,   
		m.merchandise_desc,   
		man.manufacturer_name,
		d.disposition_desc,
		p.merchandise_code as SKU,
		mc.merchandise_code as UPC
	from 
		#prelim p
		inner join merchandise m on m.merchandise_id = p.merchandise_id
		inner join merchandisecategory mcat on m.category_id = mcat.category_id
		left outer join MerchandiseCategoryCustomer mcc on m.category_id = mcc.category_id
			and mcc.customer_id = p.customer_id
		left outer join disposition d on isnull(mcc.disposition_id, mcat.default_disposition_id) = d.disposition_id
		left outer join manufacturer man on m.manufacturer_id = man.manufacturer_id
		left outer join merchandisecode mc on m.merchandise_id = mc.merchandise_id and mc.code_type = 'U'
		left outer join customer cust on p.customer_id = cust.customer_id
	order by
		m.merchandise_desc,
		mc.merchandise_code
end

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_merchandise_report] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_merchandise_report] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_merchandise_report] TO [EQAI]
    AS [dbo];

