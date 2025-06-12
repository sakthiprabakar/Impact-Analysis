create procedure [dbo].[sp_labpack_sync_get_customer]
   @trip_connect_log_id int
as
/***************************************************************************************
 this procedure retrieves the Generator details

 loads to Plt_ai
 
 11/04/2019 - rb created
 11/30/2021 - rwb - Implemented CustomerBilling approved offerer override

****************************************************************************************/

set transaction isolation level read uncommitted

select distinct
		c.customer_ID,
		c.cust_name,
		c.customer_type,
		c.cust_addr1,
		c.cust_addr2,
		c.cust_addr3,
		c.cust_addr4,
		c.cust_addr5,
		c.cust_city,
		c.cust_state,
		c.cust_zip_code,
		c.cust_country,
		c.cust_sic_code,
		c.cust_phone,
		c.cust_fax,
		c.cust_category,
		c.eq_flag,
		c.eq_company,
		c.eq_profit_ctr, 
		c.cust_naics_code,
		c.cust_status,
		c.bill_to_cust_name,
		c.bill_to_addr1,
		c.bill_to_addr2,
		c.bill_to_addr3,
		c.bill_to_addr4,
		c.bill_to_addr5,
		c.bill_to_city,
		c.bill_to_state,
		c.bill_to_zip_code,
		c.bill_to_country,
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
		end eq_offerer_effective_dt,
		c.date_added,
		c.date_modified
from TripConnectLog tcl
join WorkOrderHeader wh
	on wh.trip_id = tcl.trip_id
	and isnull(wh.field_requested_action,'') <> 'D'
join Customer c
	on c.customer_id = wh.customer_id
join CustomerBilling cb
	on cb.customer_id = wh.customer_id
	and cb.billing_project_id = wh.billing_project_id

where tcl.trip_connect_log_id = @trip_connect_log_id
