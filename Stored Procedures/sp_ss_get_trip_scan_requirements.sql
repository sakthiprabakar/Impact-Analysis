use Plt_ai
go

if exists (select 1 from sysobjects where type = 'P' and name = 'sp_ss_get_trip_scan_requirements')
	drop procedure sp_ss_get_trip_scan_requirements
go

create procedure sp_ss_get_trip_scan_requirements
	@trip_id int,
	@trip_sequence_id int = 0
as
/*
  05/26/2023 rwb Created ADO 63176
  07/13/2023 rwb DO 68300 Transform newly created type_IDs to the values TruckSiS has been using

  exec sp_ss_get_trip_scan_requirements 102117, 1
  exec sp_ss_get_trip_scan_requirements 122316, 1
*/

set transaction isolation level read uncommitted

select wh.workorder_ID,
		wh.company_id,
		wh.profit_ctr_ID,
		case sr.type_id
			when 185 then 24
			when 186 then 35
			when 187 then 45
			when 188 then 46
			when 189 then 76
			when 190 then 77
			when 191 then 78
			when 192 then 79
			when 193 then 80
			when 194 then 81
			when 195 then 108
			when 196 then 109
			when 197 then 184
			else sr.type_id
		end type_id,
		trim(sr.state_required) state_required
from TripHeader th
join WorkOrderHeader wh
	on wh.trip_id = th.trip_id
join CustomerBillingTruckSiSDocuments sr
	on sr.customer_id = wh.customer_id
	and sr.billing_project_id = wh.billing_project_id
	and sr.status = 'A'
where th.trip_id = @trip_id
and (@trip_sequence_id = 0 or wh.trip_sequence_id = @trip_sequence_id)
order by wh.trip_sequence_id, sr.type_id
go

grant execute on sp_ss_get_trip_scan_requirements to EQAI, TRIPSERV
go
