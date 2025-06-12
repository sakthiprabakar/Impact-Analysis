if exists (select 1 from sysobjects where type = 'P' and name = 'sp_ss_get_trip_stops')
	drop procedure sp_ss_get_trip_stops
go

create procedure sp_ss_get_trip_stops
	@trip_id int,
	@trip_sequence_id int = 0
as
/****************************
 *
 * 12/12/2019 - rwb - Created
 * 11/30/2021 - rwb - Implemented CustomerBilling approved offerer override
 *
 ****************************/

set transaction isolation level read uncommitted

select th.trip_id,
		coalesce(th.trip_desc,'') trip_desc,
		coalesce(convert(varchar(10),th.trip_start_date,101),'') start_date,
		coalesce(convert(varchar(10),th.trip_end_date,101),'') end_date,
		coalesce(th.driver_name,'') driver_name,
		coalesce(th.lab_pack_flag,'F') lab_pack_flag,
		wh.trip_sequence_id,
		wh.workorder_ID,
		wh.company_id,
		wh.profit_ctr_ID,
		wh.customer_ID,
		c.cust_name,
		wh.generator_id,
		coalesce(g.generator_name,'') generator_name,
		dbo.fn_address_concatenated(g.generator_address_1, g.generator_address_2, g.generator_address_3, g.generator_address_4, g.generator_city, g.generator_state, g.generator_zip_code, g.generator_country) generator_site_address,
		coalesce(g.site_code,'') site_code,
		coalesce(g.EPA_ID,'') EPA_ID,
		coalesce(wh.trip_eq_comment,'') comments,
		coalesce(g.gen_directions,'') site_directions,
		coalesce(convert(varchar(10),ws.date_est_arrive,101),'') date_est_arrive,
		coalesce(convert(varchar(10),ws.date_est_depart,101),'') date_est_depart,
		coalesce(ws.schedule_contact,'') schedule_contact,
		coalesce(ws.schedule_contact_title,'') schedule_contact_title,
		pc.profit_ctr_name,
		coalesce(gsl.code,'') generator_sublocation_code,
		coalesce(gsl.description,'') generator_sublocation_description,
		coalesce(cb.pickup_report_flag,'F') pickup_report_flag,
		coalesce(wh.offschedule_service_flag,'F') offschedule_service_flag,
		coalesce(g.generator_state,'') generator_state,
		coalesce(g.site_type,'') generator_site_type,
		th.trip_pass_code,
		coalesce(g.emergency_phone_number,'') emergency_phone_number,
		coalesce(g.emergency_contract_number,'') emergency_contract,
		dbo.fn_address_concatenated(g.gen_mail_addr1, g.gen_mail_addr2, g.gen_mail_addr3, g.gen_mail_addr4, g.gen_mail_city, g.gen_mail_state, g.gen_mail_zip_code, g.gen_mail_country) generator_mail_address,
		case coalesce(cb.eq_offeror_bp_override_flag,'')
			when 'T' then coalesce(cb.eq_approved_offeror_flag,'F')
			else coalesce(c.eq_approved_offerer_flag,'F')
		end eq_approved_offerer_flag,
		case coalesce(cb.eq_offeror_bp_override_flag,'')
			when 'T' then coalesce(cb.eq_approved_offeror_desc,'')
			else coalesce(c.eq_approved_offerer_desc,'')
		end eq_approved_offerer_desc,
		case coalesce(cb.eq_offeror_bp_override_flag,'')
			when 'T' then coalesce(convert(varchar(10),cb.eq_offeror_effective_dt,101),'')
			else coalesce(convert(varchar(10),c.eq_offerer_effective_dt,101),'')
		end offerer_effective_dt,
		coalesce(g.generator_phone,'') generator_phone,
		case when (select count(*) from WorkOrderDetail wd join Profile p on p.profile_id = wd.profile_id and p.curr_status_code = 'A' and p.pharmaceutical_flag = 'T' where wd.workorder_ID = wh.workorder_ID and wd.company_id = wh.company_id and wd.profit_ctr_ID = wh.profit_ctr_ID) > 0 then 'T' else 'F' end rx_profile_flag,
		coalesce(g.manifest_waste_code_split_flag,'F') generator_manifest_waste_code_split_flag,
		coalesce(g.DEA_ID,'') generator_DEA_ID,
		coalesce(convert(varchar(20),th.field_initial_connect_date,120),'') initial_connect_date,
		case when wh.workorder_status = 'V' then 'T' else 'F' end stop_voided_flag,
		case when wh.field_upload_date is not null then 'T' else 'F' end stop_completed_flag
from TripHeader th
join WorkOrderHeader wh
	on wh.trip_id = th.trip_id
join Customer c
	on c.customer_ID = wh.customer_ID
join Generator g
	on g.generator_id = wh.generator_id
join WorkorderStop ws
	on ws.workorder_id = wh.workorder_ID
	and ws.company_id = wh.company_id
	and ws.profit_ctr_id = wh.profit_ctr_ID
	and ws.stop_sequence_id = 1
join ProfitCenter pc
	on pc.company_id = wh.company_id
	and pc.profit_ctr_id = wh.profit_ctr_id
join CustomerBilling cb
	on cb.customer_id = wh.customer_id
	and cb.billing_project_id = wh.billing_project_id
left outer join GeneratorSubLocation gsl
	on gsl.customer_ID = wh.customer_id
	and gsl.generator_sublocation_ID = wh.generator_sublocation_ID
where th.trip_id = @trip_id
and (@trip_sequence_id = 0 or wh.trip_sequence_id = @trip_sequence_id)
order by wh.trip_sequence_id
go

grant execute on sp_ss_get_trip_stops to EQAI, TRIPSERV
go
