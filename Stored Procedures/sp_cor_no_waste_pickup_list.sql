-- drop proc if exists [sp_cor_no_waste_pickup_list]
go

create proc [sp_cor_no_waste_pickup_list] (
	@web_userid					varchar(100)
	, @customer_id_list			varchar(max)= null
    , @generator_name	varchar(max) = null
    , @epa_id			varchar(max) = null -- can take CSV list
    , @store_number		varchar(max) = null -- can take CSV list
    , @site_type		varchar(max) = null -- can take CSV list
	, @generator_district varchar(max) = null -- can take CSV list
    , @generator_region	varchar(max) = null -- can take CSV list
	, @service_start_date				datetime
	, @service_end_date					datetime
	, @generator_id_list varchar(max)= null  /* Added 2019-07-17 by AA */
	, @off_schedule_flag char(1) = 'A' -- 'S'cheduled/'R'outine  OR  'O'ff-Schedule  OR  'A'ny
) as
/* *************************************************************************
[sp_cor_no_waste_pickup_list]

copy of sp_cor_off_schedule_retail_stop_list, but with the wos.decline_id fixed at 4.

Lists Generator, Status & Question/Answer information for workorders within a certain service date range
and that belong to a customer.  Billing project list is optional, but intended.

History:

	9/16/2013	JPB	Created
	10/15/2019	MPM	DevOps 11578: Added logic to filter the result set
					using optional input parameter @generator_id_list.
	02/22/2021	JPB	DO-16076: Added workorder_type, workorder_sub_type and billing_project_name to output
	12/15/2021  JPB DO-29401: created as [sp_cor_no_waste_pickup_list]

Sample:

SELECT * FROM customerbilling where customer_id = 14231
SELECT * FROM workorderheader where customer_id = 14231 and billing_project_id = 5775

[sp_cor_no_waste_pickup_list] 
	@web_userid				= 'court_c'
	, @customer_id_list		= '18433'
    , @generator_name		= null
    , @epa_id				= null 
	, @store_number			= null
    , @site_type			= null 
	, @generator_district	= null 
    , @generator_region		= null 
	, @service_start_date			= '1/1/2018'
	, @service_end_date				= '12/31/2019'
	, @off_schedule_flag = 'A'
	
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
	, @i_date_start			datetime		= convert(date, @service_start_date)
	, @i_date_end			datetime		= convert(date, @service_end_date)
	, @i_contact_id			int
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')
	, @i_off_schedule_flag	char(1) = isnull(@off_schedule_flag, 'A') -- 'S'cheduled  vs 'O'ff-Schedule vs 'A'ny

if @i_off_schedule_flag = 'R' set @i_off_schedule_flag = 'S'
	
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


declare @foo table (
		workorder_id	int NOT NULL,
		company_id	int NOT NULL,
		profit_ctr_id  int NOT NULL,
		start_date	datetime NULL,
		service_date	datetime NULL,
		prices		bit NOT NULL,
		offschedule_service_flag char(1) NOT NULL
	)
	
insert @foo
SELECT  
		x.workorder_id,
		x.company_id,
		x.profit_ctr_id,
		x.start_date,
		x.service_date,
		x.prices,
		isnull(h.offschedule_service_flag, 'F')
FROM    ContactCORWorkorderHeaderBucket x (nolock) 
join workorderheader h
	on x.workorder_id = h.workorder_id
	and x.company_id = h.company_id
	and x.profit_ctr_id = h.profit_ctr_id
left outer join WorkOrderStop wos (nolock)
	on x.workorder_id = wos.workorder_id
	and x.company_id = wos.company_id
	and x.profit_ctr_id = wos.profit_ctr_id
	left join Generator d (nolock) on x.Generator_id = d.Generator_id
	left join @tstorenumber s on d.site_code like '%' + s.site_code + '%'
WHERE x.contact_id = @i_contact_id
	and coalesce(x.service_date, x.start_date, wos.date_act_arrive, h.start_date) between @i_date_start and @i_date_end
	and x.prices = 1
	and isnull(h.offschedule_service_flag, 'F') =
		case @i_off_schedule_flag
			when 'S' then 'F'		-- 'S'cheduled (offschedule_service_flag = F)
			when 'O' then 'T'		-- 'O'ff-Schedule (offschedule_service_flag = T)
			else isnull(h.offschedule_service_flag, 'F')	-- 'A'ny (itself)
			end
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

select distinct
	g.generator_name
	, g.epa_id
	, g.site_code
	, g.site_type
	, ltrim(rtrim(isnull(g.generator_address_1 + ' ', '') 
		+ isnull(g.generator_address_2 + ' ', '')
		+ isnull(g.generator_address_3 + ' ', '')
		+ isnull(g.generator_address_4 + ' ', '')
		+ isnull(g.generator_address_5 + ' ', ''))) as generator_address
	, g.generator_city
	, g.generator_state
	, g.generator_zip_code
	, g.generator_country
	, g.generator_region_code
	, g.generator_division
	, g.generator_district
	, case when wth.account_desc = 'National Emergency Response' then 'Emergency Response' else wth.account_desc end as workorder_type
	, wtd.description as workorder_sub_type
	, cb.project_name as billing_project_name
	, isnull(convert(varchar(10), trip_start_date, 101) + ' - ', '') +  isnull(convert(varchar(10), trip_end_date, 101), '') as trip_date_range
	, coalesce(x.service_date, x.start_date, wos.date_act_arrive, w.start_date) as service_date
	, case when 
			coalesce(x.service_date, x.start_date, wos.date_act_arrive, w.start_date, getdate()+1) > getdate() then 'Scheduled' 
		else  
			'Complete' 
	  end as status
	, case isnull(x.offschedule_service_flag, 'F')
			when 'T' then 'Off Schedule'
			when 'F' then 'Routine'
		end as Schedule_Type

	, CASE wos.decline_id 
		WHEN 1 then 'Not Declined'
		WHEN 2 then 'Service Decline ahead of Pick-up'
		when 3 then 'Service declined at Pick-up'
		when 4 then 'No Waste Picked up'
	END as pickup_status
	, 0 as lbs
	, x.company_id
	, x.profit_ctr_id
	, x.workorder_id
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
left outer join TripHeader th (nolock)
	on w.trip_id = th.trip_id
	and w.company_id = th.company_id
	and w.profit_ctr_ID = th.profit_ctr_id
left join #customer ic on w.customer_id = ic.customer_id
LEFT JOIN WorkorderTypeHeader wth (nolock) 
	on w.workorder_type_id = wth.workorder_type_id
LEFT JOIN WorkorderTypeDescription wtd (nolock) 
	on wtd.workorder_type_desc_uid = w.workorder_type_desc_uid
LEFT JOIN CustomerBilling cb (nolock) 
	on w.customer_id = cb.customer_id 
	and w.billing_project_id = cb.billing_project_id
where 1=1
and	w.workorder_status NOT IN ('V', 'X', 'T')  
and wos.decline_id = 4
	and (
	-- require a field value from the right-side of the @generator join if there was any generator search criteria
		@i_customer_id_list = ''
		or 
		(
			@i_customer_id_list <> ''
			and ic.customer_id is not null
		)
	)

order by
 	g.site_code
	, coalesce(x.service_date, x.start_date, wos.date_act_arrive, w.start_date)

RETURN 0

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_cor_no_waste_pickup_list] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_cor_no_waste_pickup_list] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_cor_no_waste_pickup_list] TO [EQAI]
    AS [dbo];

