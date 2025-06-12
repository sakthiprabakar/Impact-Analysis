-- drop proc sp_cor_off_Schedule_retail_stop_count
go

create proc sp_cor_off_Schedule_retail_stop_count (
	@web_userid					varchar(100)
	, @customer_id_list			varchar(max)=''
    , @generator_name	varchar(max) = null
    , @epa_id			varchar(max) = null -- can take CSV list
    , @store_number		varchar(max) = null -- can take CSV list
    , @site_type		varchar(max) = null -- can take CSV list
	, @generator_district varchar(max) = null -- can take CSV list
    , @generator_region	varchar(max) = null -- can take CSV list
	, @start_date				datetime
	, @end_date					datetime
    , @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
) as
/* *************************************************************************
sp_cor_off_Schedule_retail_stop_count

Lists Generator, Status & Question/Answer information for workorders within a certain service date range
and that belong to a customer.  Billing project list is optional, but intended.

History:

	9/16/2013	JPB	Created
	10/15/2019	MPM	DevOps 11577: Added logic to filter the result set
					using optional input parameter @generator_id_list.
Sample:

SELECT * FROM customerbilling where customer_id = 14231
SELECT * FROM workorderheader where customer_id = 14231 and billing_project_id = 5775

sp_cor_off_Schedule_retail_stop_count 
	@web_userid				= 'amber'
	, @customer_id_list		= '15622'
    , @generator_name		= null
    , @epa_id				= null 
	, @store_number			= null
    , @site_type			= null 
	, @generator_district	= null 
    , @generator_region		= null 
	, @start_date			= '1/1/2018'
	, @end_date				= '12/31/2019'
    , @generator_id_list	= '155581, 155586'  

	
************************************************************************* */

declare
	@i_web_userid			varchar(100)	= isnull(@web_userid, '')
	, @i_customer_id_list	varchar(max)	= isnull(@customer_id_list, '')
    , @i_generator_name		varchar(max) = isnull(@generator_name, '')
	, @i_epa_id				varchar(max) = isnull(@epa_id, '')
    , @i_store_number		varchar(max) = isnull(@store_number, '')
	, @i_site_type			varchar(max) = isnull(@site_type, '')
	, @i_generator_district varchar(max) = isnull(@generator_district, '')
    , @i_generator_region	varchar(max) = isnull(@generator_region, '')
	, @i_date_start			datetime		= convert(date, @start_date)
	, @i_date_end			datetime		= convert(date, @end_date)
	, @i_contact_id			int
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
	
select top 1 @i_contact_id = contact_id from CORcontact where web_userid = @i_web_userid

if isnull(@i_date_start, '1/1/1999') = '1/1/1999' set @i_date_start = dateadd(m, -3, getdate())
if isnull(@i_date_end, '1/1/1999') = '1/1/1999' set @i_date_end = getdate()
if datepart(hh, @i_date_end) = 0 set @i_date_end = @i_date_end + 0.99999

-- Input Handling:
---------------------
create table #customer ( customer_id	int )

insert #customer ( customer_id ) 
select 
	convert(int, row) 
from 
	dbo.fn_SplitXSVText(',', 1, @i_customer_id_list) 
where 
	row is not null

	declare @epaids table (
	epa_id	varchar(20)
)
if @i_epa_id <> ''
insert @epaids (epa_id)
select left(row, 20) from dbo.fn_SplitXsvText(',', 1, @i_epa_id)
where row is not null

declare @tdistrict table (
	generator_district	varchar(50)
)
if @i_generator_district <> ''
insert @tdistrict
select row from dbo.fn_SplitXsvText(',', 1, @i_generator_district)

declare @tstorenumber table (
	site_code	varchar(16),
	idx	int not null
)
if @i_store_number <> ''
insert @tstorenumber (site_code, idx)
select row, idx from dbo.fn_SplitXsvText(',', 1, @i_store_number) where row is not null

declare @tsitetype table (
	site_type	varchar(40)
)
if @i_site_type <> ''
insert @tsitetype (site_type)
select row from dbo.fn_SplitXsvText(',', 1, @i_site_type) where row is not null

declare @tgeneratorregion table (
	generator_region_code	varchar(40)
)
if @i_generator_region <> ''
insert @tgeneratorregion
select row from dbo.fn_SplitXsvText(',', 1, @i_generator_region)

declare @generator table (
	generator_id	bigint
)

if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

-- Access Filtering:
-----------------------

/* Generator IDs from Search parameters 
declare @generators table (Generator_id int)

if @i_generator_name + @i_epa_id + @i_store_number + @i_generator_district + @i_generator_region + @i_site_type <> ''
	insert @generators
	SELECT  
			x.Generator_id
	FROM    ContactCORGeneratorBucket x (nolock)
	join Contact c (nolock) on x.contact_id = c.contact_id and c.web_userid = @i_web_userid
	join Generator d (nolock) on x.Generator_id = d.Generator_id
	left join @tstorenumber s on d.site_code like '%' + s.site_code + '%'
	where 
	(
		@i_generator_name = ''
		or
		(
			@i_generator_name <> ''
			and
			d.generator_name like '%' + replace(@i_generator_name, ' ', '%') + '%'
		)
	)
	and 
	(
		@i_epa_id = ''
		or
		(
			@i_epa_id <> ''
			and
			d.epa_id in (select epa_id from @epaids)
		)
	)
	and 
	(
		@i_generator_region = ''
		or
		(
			@i_generator_region <> ''
			and
			d.generator_region_code in (select generator_region_code from @tgeneratorregion)
		)
	)
	and 
	(
		@i_generator_district = ''
		or
		(
			@i_generator_district <> ''
			and
			d.generator_district in (select generator_district from @tdistrict)
		)
	)
	and 
	(
		@i_store_number = ''
		or
		(
			@i_store_number <> ''
			and
			s.idx is not null
		)
	)
	and 
	(
		@i_site_type = ''
		or
		(
			@i_site_type <> ''
			and
			d.site_type in (select site_type from @tsitetype)
		)
	)
*/

declare @foo table (
		workorder_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		start_date	datetime NULL,
		prices		bit NOT NULL
	)
	
insert @foo
SELECT  
		x.workorder_id,
		x.company_id,
		x.profit_ctr_id,
		x.start_date,
		x.prices
FROM    ContactCORWorkorderHeaderBucket x (nolock) 
left outer join WorkOrderStop wos (nolock)
	on x.workorder_id = wos.workorder_id
	and x.company_id = wos.company_id
	and x.profit_ctr_id = wos.profit_ctr_id
	left join Generator d (nolock) on x.Generator_id = d.Generator_id
	left join @tstorenumber s on d.site_code like '%' + s.site_code + '%'

WHERE x.contact_id = @i_contact_id
	and coalesce(wos.date_act_arrive, x.service_date, x.start_date) between @i_date_start and @i_date_end
	and x.prices = 1
	and
	(
		@i_generator_id_list = ''
		or
		(
			@i_generator_id_list <> ''
			and
			x.generator_id in (select generator_id from @generator)
		)
	)
	and
	(
		@i_generator_name = ''
		or
		(
			@i_generator_name <> ''
			and
			isnull(d.generator_name, '') like '%' + replace(@i_generator_name, ' ', '%') + '%'
		)
	)
	and 
	(
		@i_epa_id = ''
		or
		(
			@i_epa_id <> ''
			and
			isnull(d.epa_id, '') in (select epa_id from @epaids)
		)
	)
	and 
	(
		@i_generator_region = ''
		or
		(
			@i_generator_region <> ''
			and
			isnull(d.generator_region_code, '') in (select generator_region_code from @tgeneratorregion)
		)
	)
	and 
	(
		@i_generator_district = ''
		or
		(
			@i_generator_district <> ''
			and
			isnull(d.generator_district, '') in (select generator_district from @tdistrict)
		)
	)
	and 
	(
		@i_store_number = ''
		or
		(
			@i_store_number <> ''
			and
			s.idx is not null
		)
	)
	and 
	(
		@i_site_type = ''
		or
		(
			@i_site_type <> ''
			and
			isnull(d.site_type, '') in (select site_type from @tsitetype)
		)
	)

select count(*) from (
select distinct
	g.site_code
	, g.generator_city
	, g.generator_state
	, isnull(wos.date_act_arrive, w.start_date) as service_date
	, case when w.start_date > getdate() then 'Scheduled' else  
	   case when w.end_date < getdate() then 'Complete' else  
		case when w.start_date <= getdate() and w.end_date >= getdate() then 'In Progress' else 'Unknown' end  
	   end  
	  end as status
	, tq.answer_text as notes
from @foo x
inner join workorderheader w (nolock)
	on x.workorder_id = w.workorder_id
	and x.company_id = w.company_id
	and x.profit_ctr_id = w.profit_ctr_id
inner join generator g (nolock)
	on w.generator_id = g.generator_id
left outer join WorkOrderStop wos (nolock)
	on w.workorder_id = wos.workorder_id
	and w.company_id = wos.company_id
	and w.profit_ctr_id = wos.profit_ctr_id
left outer join TripQuestion tq (nolock)
	on tq.workorder_id = w.workorder_id
	and tq.company_id = w.company_id
	and tq.profit_ctr_id = w.profit_ctr_id
	and tq.answer_type_id = 1
left join #customer ic on w.customer_id = ic.customer_id
where 1=1
and	w.workorder_status NOT IN ('V', 'X', 'T')  
	and (
	-- require a field value from the right-side of the @generator join if there was any generator search criteria
		@i_customer_id_list = ''
		or 
		(
			@i_customer_id_list <> ''
			and ic.customer_id is not null
		)
	)
	/*
order by
 	g.site_code
	, isnull(wos.date_act_arrive, w.start_date)
	*/
	) y

RETURN 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_cor_off_Schedule_retail_stop_count] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_cor_off_Schedule_retail_stop_count] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_cor_off_Schedule_retail_stop_count] TO [EQAI]
    AS [dbo];

