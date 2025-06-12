
Create Proc sp_Roadnet_Route_To_EQAI_Trip
as
/* ****************************************************************
sp_Roadnet_Route_To_EQAI_Trip

Creates EQAI Trip db components from an temp table filled with Roadnet Route info by EQAI.
Ends with a Select of the new Trip ID created.

Expected Temp Table:

Create Table #RoadnetRoute (
	Sequence_Number	int,		-- RN's Sequence_Number_ field.  Becomes Trip	Sequence (Stop Number)
	Location_ID		int,		-- RN's Location_ID_ field.	 Matches up to Generator_ID
	Location_Type	varchar(3),	-- RN's Location_Type_ field.  Matches up with Generator Sub Location, becomes WorkOrderHeader.generator_sublocation_id
	Arrival_Time	varchar(20), -- RN's Arrival_Time_ field.  Should convert to a datetime, becoming WorkOrderStop.date_est_arrival
	Service_Time	varchar(20), -- RN's Service_Time_ field.  Should convert to HH:MM (time), adds to Arrival_Time becoming WorkOrderStop.date_est_depart
	Company_ID		int,		-- Screen's current company_id.  Becomes company_id (duh)
	Profit_Ctr_ID	int,		-- Screen's current profit_ctr_id.  Becomes profit_ctr_id (duh)
	Trip_Name		varchar(60), -- Screen's Trip Name value.  Becomes... uh... Maybe TripHeader.template_name?
	Trip_Desc		varchar(255), -- Screen's Trip Description value.  Becomes TripHeader.trip_desc
	Driver			varchar(40), -- Screen's Driver value.  Becomes TripHeader.driver_name
	Customer_ID		int,		-- Screen's Per-Stop Customer ID value.  Becomes WorkOrderHeader.customer_id
	WorkOrder_Type	int,			-- Screen's Per-Stop Work Order Type value.  Becomes WorkOrderHeader.work_order_type_id
	Added_By		varchar(10) -- EQAI User calling this sp
)

exec sp_Roadnet_Route_To_EQAI_Trip 

**************************************************************** */

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

/*

6.	Stored Procedure will create the tripheader, workorderheader, workorderstop records
	a.	Trip ID comes from a sequence.
	b.	Customer ID comes from fields the user gets prompted for
	c.	Generator ID & SubLocation come from the roadnet excel
	d.	Start & End Dates for work orders come from the Arrival Date times in the roadnet excel
	e.	Trip Name & Description, and Driver come from fields the user gets prompted for.
	f.	Trip passcode can be system/random generated (Try to copy the screen logic)
	g.	Trip Type = Standard
	h.	Default NonHaz Manifest Form should = Non-Haz Manifest
	i.	Lab Pack Trip Flag = No


*/

	-- Verify #RoadnetRoute exists
	if object_id('tempdb..#RoadnetRoute') is null BEGIN
		RAISERROR (N'sp_Roadnet_Route_To_EQAI_Trip error: #RoadnetRoute table was expected, but not found.', 1, 1, 'sp_Roadnet_Route_To_EQAI_Trip')
		RETURN -1
	END

	-- Verify #RoadnetRoute has data for stops (not depots)
	if 0 = (select count(*) from #RoadnetRoute where isnull(Location_Type, '') not in ('', 'DPT')) BEGIN
		RAISERROR (N'sp_Roadnet_Route_To_EQAI_Trip error: #RoadnetRoute table contains no location types.', 1, 1, 'sp_Roadnet_Route_To_EQAI_Trip')
		RETURN -1
	END

	-- Now that #RoadnetRoute exists and has reasonable data to try, let's add a placeholder for workorder_id into a copy of the table.
	if object_id('tempdb..#RoadnetWork') is not null
		drop table #RoadnetWork

	select 
		convert(int, null) as workorder_id
		, * 
	into #RoadnetWork 
	from #RoadnetRoute
	where 
		isnull(Location_Type, '') not in ('', 'DPT')

	-- Declare vars we'll use later...
	declare @new_trip_id int
		, @company_id int
		, @profit_ctr_id int
		, @trip_start_date datetime
		, @trip_end_date datetime
		, @trip_name varchar(60)
		, @trip_desc varchar(255)
		, @driver varchar(40)
		, @added_by varchar(10)
		, @new_workorder_id int
		, @stop_count int

	-- Retrieve the next Trip ID
	exec @new_trip_id = sp_sequence_next 'TripHeader.trip_id'
		-- select @new_trip_id




	-- Debug only: Log input table data for testing/validating
	-- insert jpb_RoadnetRoute_ImportLog
	-- select @new_trip_id, *, getdate() from #RoadnetWork
	
	
	

	-- Set vars from the #RoadnetWork import table that should exist
	select top 1
		@company_id = company_id
		, @profit_ctr_id = profit_ctr_id
		, @trip_start_date = min(Arrival_Time)
		, @trip_end_date = max(Arrival_Time)
		, @trip_name = trip_name
		, @trip_desc = trip_desc
		, @driver = driver
		, @stop_count = count(*)
	from #RoadnetWork
	group by
		company_id
		, profit_ctr_id
		, trip_name
		, trip_desc
		, driver


	-- Insert TripHeader record			
	insert TripHeader 
		(
			trip_id
			, company_id
			, profit_ctr_id
			, trip_status
			, trip_pass_code
			, trip_start_date
			, trip_end_date
			, type_code
			, trip_desc
			, template_name
			, transporter_code
			, resource_code
			, driver_company
			, driver_name
			, drivers_license_CDL
			, truck_DOT_number
			, upload_merchandise_ind
			, added_by
			, date_added
			, modified_by
			, date_modified
			, field_initial_connect_date
			, use_manifest_haz_only_flag
			, third_party_complete_flag
			, lab_pack_flag
			, tractor_number
			, trailer_number		
		)
	SELECT
			@new_trip_id trip_id
			, @company_id company_id
			, @profit_ctr_id profit_ctr_id
			, 'N' trip_status
			, '' trip_pass_code
			, convert(date, @trip_start_date) trip_start_date
			, convert(date, @trip_end_date) trip_end_date
			, 'S' type_code /* Standard */
			, @trip_desc trip_desc
			, @trip_name template_name
			, NULL transporter_code
			, NULL resource_code
			, NULL driver_company
			, @driver driver_name
			, NULL drivers_license_CDL
			, NULL truck_DOT_number
			, NULL upload_merchandise_ind
			, @added_by added_by
			, getdate() date_added
			, @added_by modified_by
			, getdate() date_modified
			, NULL field_initial_connect_date
			, 'F' use_manifest_haz_only_flag
			, NULL third_party_complete_flag
			, 'F' lab_pack_flag
			, NULL tractor_number
			, NULL trailer_number		

	-- Get next Work Order ID, and simultaneously update table for next use
	update profitcenter set
		@new_workorder_id = next_workorder_id
		, next_workorder_id = next_workorder_id + @stop_count
	where
		company_id = @company_id
		and profit_ctr_id = @profit_ctr_id

	-- Store Workorder_id's in with the #RoadnetWork data. (So WorkorderHeader and WorkorderStop will match)
	update #RoadnetWork set
		workorder_id = x.workorder_id
	from #RoadnetWork rw
	join (
		select 
			((@new_workorder_id + row_number() over (order by sequence_number) -1) * 100) workorder_id
			, sequence_number
		from #RoadnetWork
	) x on rw.sequence_number = x.sequence_number


	-- Insert 1 WorkOrderHeader record per stop.
	insert WorkOrderHeader
		(
			workorder_ID
			, company_id
			, profit_ctr_ID
			, revision
			, workorder_status
			, workorder_type
			, submitted_flag
			, customer_ID
			, generator_id
			, billing_project_id
			, fixed_price_flag
			, priced_flag
			, total_price
			, total_cost
			, description
			, template_code
			, emp_arrive_time
			, cust_arrive_time
			, start_date
			, end_date
			, urgency_flag
			, project_code
			, project_name
			, project_location
			, contact_ID
			, quote_ID
			, purchase_order
			, release_code
			, milk_run
			, label_haz
			, label_nonhaz
			, label_class_3
			, label_class_4_1
			, label_class_5_1
			, label_class_6_1
			, label_class_8
			, label_class_9
			, void_date
			, void_operator
			, void_reason
			, comments
			, clean_tanker
			, confined_space
			, fresh_air
			, load_count
			, cust_discount
			, invoice_comment_1
			, invoice_comment_2
			, invoice_comment_3
			, invoice_comment_4
			, invoice_comment_5
			, ae_comments
			, site_directions
			, invoice_break_value
			, problem_id
			, project_id
			, project_record_id
			, include_cost_report_flag
			, po_sequence_id
			, billing_link_id
			, other_submit_required_flag
			, submit_on_hold_flag
			, submit_on_hold_reason
			, trip_id
			, trip_sequence_id
			, trip_eq_comment
			, submitted_by
			, date_submitted
			, consolidated_pickup_flag
			, field_download_date
			, field_upload_date
			, field_requested_action
			, tractor_trailer_number
			, ltl_title_comment
			, created_by
			, date_added
			, modified_by
			, date_modified
			, workorder_type_id
			, reference_code
			, trip_stop_rate_flag
			, generator_sublocation_ID
			, combined_service_flag
			, offschedule_service_flag
			, offschedule_service_reason_ID
		)
	SELECT
			rr.workorder_id workorder_id
			, @company_id company_id
			, @profit_ctr_ID profit_ctr_ID
			, 1 revision
			, 'N' workorder_status
			, NULL workorder_type
			, 'F' submitted_flag
			, rr.customer_ID
			, rr.location_id generator_id
			, NULL billing_project_id
			, 'F' fixed_price_flag
			, 0 priced_flag
			, 0 total_price
			, 0 total_cost
			, NULL description
			, NULL template_code
			, NULL emp_arrive_time
			, NULL cust_arrive_time
			, convert(date, rr.Arrival_Time) start_date
			, convert(date, convert(datetime, rr.Arrival_Time) + rr.Service_Time) end_date
			, 'R' urgency_flag
			, NULL project_code
			, NULL project_name
			, NULL project_location
			, 0 contact_ID
			, NULL quote_ID
			, NULL purchase_order
			, NULL release_code
			, NULL milk_run
			, NULL label_haz
			, NULL label_nonhaz
			, NULL label_class_3
			, NULL label_class_4_1
			, NULL label_class_5_1
			, NULL label_class_6_1
			, NULL label_class_8
			, NULL label_class_9
			, NULL void_date
			, NULL void_operator
			, NULL void_reason
			, NULL comments
			, NULL clean_tanker
			, NULL confined_space
			, NULL fresh_air
			, NULL load_count
			, 0 cust_discount
			, '' invoice_comment_1
			, '' invoice_comment_2
			, '' invoice_comment_3
			, '' invoice_comment_4
			, '' invoice_comment_5
			, NULL ae_comments
			, NULL site_directions
			, NULL invoice_break_value
			, NULL problem_id
			, NULL project_id
			, NULL project_record_id
			, NULL include_cost_report_flag
			, NULL po_sequence_id
			, NULL billing_link_id
			, 'F' other_submit_required_flag
			, 'F' submit_on_hold_flag
			, NULL submit_on_hold_reason
			, @new_trip_id trip_id
			, row_number() over (order by sequence_number) trip_sequence_id
			, NULL trip_eq_comment
			, NULL submitted_by
			, NULL date_submitted
			, NULL consolidated_pickup_flag
			, NULL field_download_date
			, NULL field_upload_date
			, NULL field_requested_action
			, NULL tractor_trailer_number
			, NULL ltl_title_comment
			, rr.Added_by created_by
			, getdate() date_added
			, rr.Added_by modified_by
			, getdate() date_modified
			, rr.workorder_type workorder_type_id
			, NULL reference_code
			, NULL trip_stop_rate_flag
			, (
					select top 1 gxgs.generator_sublocation_ID 
					from GeneratorXGeneratorSubLocation gxgs
					join GeneratorSubLocation gsl on gxgs.generator_sublocation_ID = gsl.generator_sublocation_ID
					where gxgs.generator_id = rr.Location_ID
					and gsl.code = rr.Location_Type
					and gsl.customer_id = rr.Customer_ID -- This shouldn't be necessary, probably won't hurt though.
			  ) generator_sublocation_ID
			, NULL combined_service_flag
			, NULL offschedule_service_flag
			, NULL offschedule_service_reason_ID
		from #RoadnetWork rr
		order by
			workorder_id

	-- Insert WorkOrderStop records.
	Insert WorkOrderStop
	(
		workorder_id
		, company_id
		, profit_ctr_id
		, stop_sequence_id
		, station_id
		, est_time_amt
		, est_time_unit
		, schedule_contact
		, schedule_contact_title
		, pickup_contact
		, pickup_contact_title
		, confirmation_date
		, waste_flag
		, decline_id
		, date_est_arrive
		, date_est_depart
		, date_act_arrive
		, date_act_depart
		, added_by
		, date_added
		, modified_by
		, date_modified
	)
	SELECT
			rr.workorder_id workorder_id
			, @company_id company_id
			, @profit_ctr_ID profit_ctr_ID
			, 1 stop_sequence_id
			, NULL station_id
			, 1 est_time_amt
			, 'D' est_time_unit
			, NULL schedule_contact
			, NULL schedule_contact_title
			, NULL pickup_contact
			, NULL pickup_contact_title
			, NULL confirmation_date
			, NULL waste_flag
			, NULL decline_id
			, rr.Arrival_Time date_est_arrive
			, convert(datetime, rr.Arrival_Time) + rr.Service_Time date_est_depart
			, NULL date_act_arrive
			, NULL date_act_depart
			, rr.Added_By added_by
			, getdate() date_added
			, rr.Added_By modified_by
			, getdate() date_modified		
		from #RoadnetWork rr
		order by
			workorder_id

	Select @new_trip_id as trip_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Roadnet_Route_To_EQAI_Trip] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Roadnet_Route_To_EQAI_Trip] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Roadnet_Route_To_EQAI_Trip] TO [EQAI]
    AS [dbo];

