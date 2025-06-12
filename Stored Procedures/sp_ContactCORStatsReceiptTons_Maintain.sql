-- drop proc sp_ContactCORStatsReceiptTons_Maintain
go

create proc sp_ContactCORStatsReceiptTons_Maintain

as

begin

SET Transaction isolation level read uncommitted  

declare @last_ran datetime
if exists (select 1 from sysobjects where name = 'ContactCORStatsReceiptTons')
	select @last_ran = max(last_modified) from ContactCORStatsReceiptTons WHERE last_modified <= getdate()
	select @last_ran
	
--declare @last_ran datetime = '2019-07-17 16:27:37.920'

if object_id('tempdb..#rstats') is not null drop table #rstats;
create table #rstats (
	receipt_id	int,
	line_id	int,
	company_id	int,
	profit_ctr_id	int,
	profile_id	int,
	customer_id int,
	generator_id	int,
	receipt_date	datetime,
	pickup_date	datetime,
	approval_code	varchar(15),
	manifest	varchar(15),
	manifest_page_num	int,
	manifest_line	int,
	manifest_quantity	float,
	manifest_unit	char(1),
	quantity	float,
	manifest_container_code	varchar(15),
	haz_flag	char(1),
	tons	float,
	last_modified	datetime
)

--declare @last_ran datetime = '2019-07-17 16:27:37.920'

-- 3am? Refresh all. Otherwise, only latest.
if datepart(hh, getdate()) <> 3 and exists (select 1 from sysobjects where name = 'ContactCORStatsReceiptTons') and @last_ran is not null begin

	insert #rstats (
	receipt_id,
	line_id	,
	company_id	,
	profit_ctr_id	,
	profile_id	,
	customer_id ,
	generator_id	,
	receipt_date	,
	pickup_date	,
	approval_code	,
	manifest	,
	manifest_page_num	,
	manifest_line	,
	manifest_quantity	,
	manifest_unit	,
	quantity	,
	manifest_container_code	,
	haz_flag	,
	tons	,
	last_modified	
	)
	select -- h.*
	h.receipt_id,
	h.line_id	,
	h.company_id	,
	h.profit_ctr_id	,
	h.profile_id	,
	h.customer_id ,
	h.generator_id	,
	h.receipt_date	,
	h.pickup_date	,
	h.approval_code	,
	h.manifest	,
	h.manifest_page_num	,
	h.manifest_line	,
	h.manifest_quantity	,
	h.manifest_unit	,
	h.quantity	,
	h.manifest_container_code	,
	h.haz_flag	,
	h.tons	,
	h.last_modified	
	
	from ContactCORStatsReceiptTons h
	join receipt r
		on h.receipt_id = r.receipt_id
		and h.line_id = r.line_id
		and h.company_id = r.company_id
		and h.profit_ctr_id = r.profit_ctr_id
		and isnull(r.date_modified, r.date_added) <= h.last_modified
	WHERE h.last_modified <= @last_ran
	-- and h.contact_id not in (select contact_id from CORContact WHERE web_userid = 'all_customers')

end
else
	set @last_ran = '1/1/2000'

-- delete from #rstats
	
-- Now we have an empty or pre-fab #rstats.  Time to add to it.

-- declare @last_ran datetime = '2019-07-17 16:27:37.920'

if @last_ran is null set @last_ran = '1/1/2000'

insert #rstats
select distinct
	h.receipt_id, r.line_id, h.company_id, h.profit_ctr_id
	, r.profile_id, h.customer_id, h.generator_id
	,h.receipt_date, h.pickup_date, r.approval_code
	,r.manifest, r.manifest_page_num, r.manifest_line
	,r.manifest_quantity, r.manifest_unit, r.quantity
	,r.manifest_container_code
	, haz_flag = 
		case when exists (
			select top 1 1
			from receiptwastecode rwc join wastecode wc 
				on rwc.waste_code_uid = wc.waste_code_uid
				and wc.haz_flag = 'T' and wc.waste_code_origin = 'F'
			WHERE rwc.receipt_id = r.receipt_id
			and rwc.line_id = r.line_id
			and rwc.company_id = r.company_id
			and rwc.profit_ctr_id = r.profit_ctr_id
		) then 'T' else 'F' end
	, convert(float, null) as tons
	-- ,(dbo.fn_receipt_weight_line(r.receipt_id, r.line_id, r.profit_ctr_id, r.company_id) / 2000.00) as tons
	, r.date_modified as last_modified
from ContactCORReceiptBucket h
join Receipt r (nolock)
	on h.receipt_id = r.receipt_id
		and h.company_id = r.company_id
		and h.profit_ctr_id = r.profit_ctr_id
WHERE 	h.receipt_date >= '1/1/' + convert(varchar(4),year(getdate())-2)
		and isnull(r.date_modified, r.date_added) > @last_ran
		and r.receipt_status not in ('V')
		and r.fingerpr_status not in ('V', 'R')
		and r.waste_accepted_flag = 'T'
		and r.trans_type = 'D'
		and r.trans_mode = 'I'

-- Biggest weight update, faster as set than 1-by-1 function call:
update #rstats
set	tons = x.tons
from #rstats f
join (
	-- 1.	Container weight (Inbound reporting only) -- Reported
	select
	#rstats.receipt_id, #rstats.line_id, #rstats.company_id, #rstats.profit_ctr_id
	,tons = (
	sum( isnull(c.container_weight, 0) * (IsNull(cd.container_percent, 0) / 100.000) )
	) / 2000.00
	from #rstats
	join container c (nolock)
		on c.receipt_id = #rstats.receipt_id
		and c.line_id = #rstats.line_id
		and c.company_id = #rstats.company_id
		and c.profit_ctr_id = #rstats.profit_ctr_id
	inner join containerdestination cd (nolock)
		on c.receipt_id = cd.receipt_id
		and c.line_id = cd.line_id
		and c.container_id = cd.container_id
		and c.company_id = cd.company_id
		and c.profit_ctr_id = cd.profit_ctr_id
	where 
		NOT EXISTS (
			-- You MUST make sure there's no containers for this line 
			--- with an unrecorded/zero weight, or this section returns bad data
			select top 1 1 
			from container c1 (nolock)
			where 
				c1.receipt_id = c.receipt_id
				and c1.line_id = c.line_id
				and c1.company_id = c.company_id
				and c1.profit_ctr_id = c.profit_ctr_id
				and isnull(c1.container_weight, 0) = 0
		)
		GROUP BY #rstats.receipt_id, #rstats.line_id, #rstats.company_id, #rstats.profit_ctr_id
		having sum( isnull(c.container_weight, 0) * (IsNull(cd.container_percent, 0) / 100.000) ) > 0
) x
	on f.receipt_id = x.receipt_id
	and f.line_id = x.line_id
	and f.company_id = x.company_id
	and f.profit_ctr_id = x.profit_ctr_id
where f.tons is null


-- Next biggest weight update possible:
update #rstats set tons = isnull(r.line_weight, 0)/2000.00
	from #rstats f
	join receipt r (nolock) 
		on f.receipt_id = r.receipt_id
		and f.line_id = r.line_id
		and f.company_id = r.company_id
		and r.profit_ctr_id = r.profit_ctr_id
	where
		f.tons is null
		and isnull(r.line_weight, 0) > 0
	
-- Remaining updates...	
while exists (select 1 from #rstats where tons is null) begin
	set rowcount 1000
	update #rstats set 
		tons = isnull((dbo.fn_receipt_weight_line(receipt_id, line_id, profit_ctr_id, company_id) / 2000.00), 0)
	from #rstats r
		WHERE tons is null
	set rowcount 0
end
	
update #rstats set 
	pickup_date = (
		select min(pickup_date)
		from ContactCORReceiptBucket h
		WHERE h.receipt_id = r.receipt_id
		and h.company_id = r.company_id
		and h.profit_ctr_id = r.profit_ctr_id
		and pickup_date is not null
		)
from #rstats r
join ContactCORReceiptBucket h
		on h.receipt_id = r.receipt_id
		and h.company_id = r.company_id
		and h.profit_ctr_id = r.profit_ctr_id
		and h.pickup_date is not null
WHERE r.pickup_date is null

-- SELECT  count(*)  FROM    #rstats
-- SELECT  TOP 10 * FROM    #rstats WHERE receipt_id = 2085977
-- SELECT  count(*)  FROM    ContactCORStatsReceiptTons


if (select count(*) from #rstats) > 0
	if exists (select 1 from sysobjects where name = 'ContactCORStatsReceiptTons')	begin
		drop table ContactCORStatsReceiptTons;
		select * into ContactCORStatsReceiptTons from #rstats ;
		grant select, insert, update, delete on ContactCORStatsReceiptTons to eqai, cor_user, eqweb;
		create index idx_ContactCORStatsReceiptTons_key on ContactCORStatsReceiptTons (receipt_id, company_id, profit_ctr_id);
		create index idx_ContactCORStatsReceiptTons_lastran on ContactCORStatsReceiptTons (last_modified);
	end


-- SELECT  *  FROM    ContactCORStatsReceiptTons

return 0

end

go

grant execute on sp_ContactCORStatsReceiptTons_Maintain to eqweb
go
grant execute on sp_ContactCORStatsReceiptTons_Maintain to eqai
go
grant execute on sp_ContactCORStatsReceiptTons_Maintain to cor_user
go
