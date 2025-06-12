-- drop proc sp_ContactCorStatsOnTimeService_Maintain
go
create proc sp_ContactCorStatsOnTimeService_Maintain

as

begin

SET Transaction isolation level read uncommitted  

-- contact+generator year+mo scheduled time vs actual time
select -- top 1000
	h.contact_id
	, h.customer_id
	, h.generator_id
	-- , year(h.scheduled_date) _year
	-- , month(h.scheduled_date) _mo
	, convert(date, h.scheduled_date) as _date
	, count(*) scheduled_count
	, sum(
		case when s.date_act_arrive is not null and convert(date, h.scheduled_date) = convert(date, s.date_act_arrive) then 
			1 
		else 
			case when w.trip_id is not null and  convert(date, s.date_act_arrive) <= convert(date, t.trip_end_date) then
				1
			else
				0
			end
		end
	) on_time_count
into #def
from ContactCORWorkorderHeaderBucket h (nolock)
join workorderheader w (nolock) on h.workorder_id = w.workorder_id and h.company_id = w.company_id and h.profit_ctr_id = w.profit_ctr_id
left join workorderstop s (nolock) on h.workorder_id = s.workorder_id and h.company_id = s.company_id and h.profit_ctr_id = s.profit_ctr_id
left join tripheader t (nolock) on w.trip_id = t.trip_id and w.company_id = t.company_id and w.profit_ctr_id = t.profit_ctr_id
WHERE h.scheduled_date is not null
and h.report_status in ('Completed', 'Invoiced')
and isnull(w.offschedule_service_flag, 'F') = 'F'
and 1 =	case when s.date_act_arrive is not null then 
			1 
		else 
			case when w.trip_id is not null and t.trip_end_date is not null then
				1
			else
				0
			end
		end
and h.contact_id not in (select contact_id from CORContact WHERE web_userid = 'all_customers')
GROUP BY h.contact_id, h.customer_id, h.generator_id
-- , year(h.scheduled_date), month(h.scheduled_date)
, convert(date, h.scheduled_date)


if exists (select 1 from sysobjects where xtype = 'u' and name = 'ContactCorStatsOnTimeService')
	drop table ContactCorStatsOnTimeService

select
contact_id, customer_id, generator_id, year(_date) as _year, month(_date) as _mo
, sum(scheduled_count) scheduled_count, sum(on_time_count) on_time_count
, convert(decimal(5,2), (((sum(on_time_count) * 1.00) / sum(scheduled_count)) * 100.00)) as on_time_scheduled_pct
into ContactCorStatsOnTimeService
FROM    #def
group by contact_id, customer_id, generator_id, year(_date), month(_date)

CREATE INDEX [IX_ContactCorStatsOnTimeService_contact_id] ON [dbo].ContactCorStatsOnTimeService (contact_id, customer_id, generator_id, _year, _mo) INCLUDE (scheduled_count, on_time_count, on_time_scheduled_pct)
grant select on ContactCorStatsOnTimeService to COR_USER
grant select, insert, update, delete on ContactCorStatsOnTimeService to EQAI



return 0

end

go

grant execute on sp_ContactCorStatsOnTimeService_Maintain to eqweb
go
grant execute on sp_ContactCorStatsOnTimeService_Maintain to eqai
go
grant execute on sp_ContactCorStatsOnTimeService_Maintain to cor_user
go
