-- drop proc sp_cor_dashboard_on_time_initial_manifest 
go

create proc sp_cor_dashboard_on_time_initial_manifest (
	@web_userid	varchar(100)
	, @start_date	datetime = null
	, @end_date		datetime = null
	, @period			varchar(2) = null /* WW, MM, QQ or YY: Forces @date fields to be ignored for current period dates */
	, @customer_id_list varchar(max)=''  /* Added 2019-07-12 by AA */
    , @generator_id_list varchar(max)=''  /* Added 2019-07-12 by AA */
)
as
/* ***********************************************************
sp_cor_dashboard_on_time_initial_manifest 

10/04/2019 MPM  DevOps 11555: Added logic to filter the result set
				using optional input parameters @customer_id_list and
				@generator_id_list.

sp_cor_dashboard_on_time_initial_manifest 'nyswyn100'

sp_cor_dashboard_on_time_initial_manifest 
	@web_userid = 'zachery.wright'
	, @start_date = '10/1/2018'
	, @end_date = '12/31/2018'

sp_cor_dashboard_on_time_initial_manifest 
	@web_userid = 'thames'
	, @start_date = '1/1/2018'
	, @end_date = '10/04/2019'
	, @period = null
	, @customer_id_list = '14164'
	, @generator_id_list = '137729'
	
sp_cor_dashboard_on_time_initial_manifest 
	@web_userid = 'thames'
	, @start_date = '1/1/2018'
	, @end_date = '10/04/2019'
	, @period = null
	, @customer_id_list = '14164'
	, @generator_id_list = ''

sp_cor_dashboard_on_time_initial_manifest 
	@web_userid = 'thames'
	, @start_date = '1/1/2018'
	, @end_date = '10/04/2019'
	, @period = null
	, @customer_id_list = ''
	, @generator_id_list = '137729'

sp_cor_dashboard_on_time_initial_manifest 
	@web_userid = 'thames'
	, @start_date = '1/1/2018'
	, @end_date = '10/04/2019'
	, @period = null
	, @customer_id_list = ''
	, @generator_id_list = ''

*********************************************************** */

/*
declare
	@web_userid varchar(100) = 'zachery.wright'
	, @start_date datetime = '1/1/2017'
	, @end_date datetime = '12/31/2018'
*/

declare
	@i_web_userid	varchar(100) = @web_userid
	, @i_start_date	datetime = convert(date, @start_date)
	, @i_end_date	datetime = convert(date, @end_date)
	, @i_period					varchar(2)		= @period
	, @contact_id	int
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')

	declare @customer table (
	customer_id	bigint
)

if @i_customer_id_list <> ''
insert @customer select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_customer_id_list)
where row is not null

declare @generator table (
	generator_id	bigint
)

if @i_generator_id_list <> ''
insert @generator select convert(bigint, row)
from dbo.fn_SplitXsvText(',', 1, @i_generator_id_list)
where row is not null

select top 1 @contact_id = contact_id from CORcontact where web_userid = @i_web_userid

if @i_end_date is null begin
	set @i_end_date = convert(date, getdate())
	set @i_start_date = convert(date, @i_end_date-365)
end
else 
	if @i_start_date is null 
		set @i_start_date = convert(date, @i_end_date-365)

if datepart(hh, @i_end_date) = 0
	set @i_end_date = @i_end_date + 0.99999
	

if @i_period is not null
	select @i_start_date = dbo.fn_FirstOrLastDateOfPeriod(0, @period, 'on_time_initial_manifest')
		, @i_end_date = dbo.fn_FirstOrLastDateOfPeriod(1, @period, 'on_time_initial_manifest')

declare @types table (
	type_id int
)
insert @types
select type_id from plt_image..ScanDocumentType 
where document_type = 'Generator Initial Manifest'

declare @time table (
	m_yr int,
	m_mo int
);

	
WITH CTE AS
(
    SELECT @i_start_date AS cte_start_date
    UNION ALL
    SELECT DATEADD(MONTH, 1, cte_start_date)
    FROM CTE
    WHERE DATEADD(MONTH, 1, cte_start_date) <= @i_end_date   
)
insert @time
SELECT year(cte_start_date), month(cte_start_date)
FROM CTE


declare @foo table (
	trans_source char(1)
	,receipt_id	 int
	,company_id	int
	,profit_ctr_id	int
	, service_date datetime
	, generator_id int
	, manifest varchar(15)
)

insert @foo
select 'W'
, b.workorder_id
, b.company_id
, b.profit_ctr_id
, b.service_date
, b.generator_id
, wom.manifest
from contactcorworkorderheaderbucket b
	join generator g 
		on b.generator_id = g.generator_id 
		and g.generator_state in ('CA', 'ME', 'MI', 'NY', 'NH', 'ND' )
	join workordermanifest wom 
		on b.workorder_id = wom.workorder_id 
		and b.company_id = wom.company_id 
		and b.profit_ctr_id = wom.profit_ctr_id
		and wom.manifest not like '%manifest%' 
		and wom.manifest_flag = 'T' 
		and wom.manifest_state = ' H'
WHERE b.contact_id = @contact_id
and b.service_date between @i_start_date and @i_end_date
and 
(
	@i_customer_id_list = ''
	or
	(
		@i_customer_id_list <> ''
		and
		b.customer_id in (select customer_id from @customer)
	)
)
and
(
	@i_generator_id_list = ''
	or
	(
		@i_generator_id_list <> ''
		and
		b.generator_id in (select generator_id from @generator)
	)
)
union
select 'R'
, b.receipt_id
, b.company_id
, b.profit_ctr_id
, b.pickup_date
, b.generator_id
, r.manifest
from contactcorreceiptbucket b
	join receipt r
		on b.receipt_id = r.receipt_id 
		and b.company_id = r.company_id 
		and b.profit_ctr_id = r.profit_ctr_id
		and r.manifest_flag = 'M' 
		and r.manifest_form_type = 'H'
	join generator g 
		on r.generator_id = g.generator_id 
		and g.generator_state in ('CA', 'ME', 'MI', 'NY', 'NH', 'ND' )
WHERE b.contact_id = @contact_id
and b.pickup_date between @i_start_date and @i_end_date
and 
(
	@i_customer_id_list = ''
	or
	(
		@i_customer_id_list <> ''
		and
		b.customer_id in (select customer_id from @customer)
	)
)
and
(
	@i_generator_id_list = ''
	or
	(
		@i_generator_id_list <> ''
		and
		b.generator_id in (select generator_id from @generator)
	)
)
-- select @i_start_date, @i_end_date
--SELECT  *  FROM    @foo

select 
	t.m_yr manifest_year,
	t.m_mo manifest_month
, count(y.date_mailed) total_manifests, isnull(sum(y.mailed_on_time),0) on_time_manifests, 
convert(decimal(5,2),
	isnull(
		(convert(decimal(5,2),sum(y.mailed_on_time)) / count(*)) * 100
	, 0)
) as pct_on_time
from
@time t
left outer join
(
	select b.*	,rml.date_mailed
	, case when datediff(d, b.service_date, isnull(rml.date_mailed, getdate() + 365)) <= 7 then 1 else 0 end as mailed_on_time
	-- ,  wom.*
	-- , s.image_id,s.manifest, s.document_name
	from @foo b
	inner join plt_image..scan s 
		on b.receipt_id = s.workorder_id 
		and b.profit_ctr_id = s.profit_ctr_id 
		and b.company_id = s.company_id 
		and s.status = 'A'
		and s.type_id in (select type_id from @types )
		and isnull(s.manifest, '') + isnull(s.document_name, '') like '%' + b.manifest + '%'
		and s.view_on_web = 'T'
	left join ReturnedManifestLog rml
		on b.receipt_id = rml.receipt_id
		and b.company_id = rml.company_id
		and b.profit_ctr_id = rml.profit_ctr_id
		and b.trans_source = rml.trans_source
		and b.manifest = rml.manifest
	where b.trans_source = 'W'
	UNION
	select b.*, rml.date_mailed
	, case when datediff(d, b.service_date, isnull(rml.date_mailed, getdate() + 365)) <= 7 then 1 else 0 end as mailed_on_time
	-- select r.manifest, s.*
	from @foo b
	inner join plt_image..scan s 
		on b.receipt_id = s.receipt_id 
		and b.profit_ctr_id = s.profit_ctr_id 
		and b.company_id = s.company_id 
		and s.status = 'A'
		and s.type_id in ( select type_id from @types )
		and b.manifest = s.manifest 
		and s.view_on_web = 'T'
	left join ReturnedManifestLog rml
		on b.receipt_id = rml.receipt_id 
		and b.company_id = rml.company_id
		and b.profit_ctr_id = rml.profit_ctr_id
		and b.trans_source = rml.trans_source
 		and b.manifest = rml.manifest
	WHERE b.trans_source = 'R'

) y
on t.m_yr = year(y.service_date)
and t.m_mo = month(y.service_date)
GROUP BY 
t.m_yr
, t.m_mo
ORDER BY t.m_yr, t.m_mo

return 0

go

grant execute on sp_cor_dashboard_on_time_initial_manifest to eqai, eqweb, cor_user
go
