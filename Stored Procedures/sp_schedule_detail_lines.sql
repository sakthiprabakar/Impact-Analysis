CREATE PROCEDURE sp_schedule_detail_lines
	@debug int,
	@confirmation_id int,
	@company_id int,
	@profit_ctr_id int, 
	@print_various int,
	@user_code varchar(50)
AS 
/***********************************************************************
Bulk or Non-Bulk Daily Schedule (from Schedule screen)

Filename:	F:\EQAI\SQL\EQAI\sp_schedule_detail_lines.sql
PB Object(s):	d_rpt_schedule_daily_detail_lines
		d_rpt_schedule_daily_lab_detail_lines

02/10/2004 SCC	Created
10/04/2004 JDB	Replaced "DRUM" with "DM55" as a result of bill unit conversion.
11/11/2004 MK  Changed generator_code to generator_id
08/02/2006 SCC	Modified to use Profile tables
11/04/2006 SCC  Removed material_type column reference
11/28/2012 DZ   Added company_id, moved from plt_xx_ai to plt_ai
11/19/2013 AM	Modified to use wastecode.display_name
03/16/2017 MPM	Added ProfileQuoteApproval.fingerprint_type to result set.
03/27/2017 MPM	Added TreatmentDetail.facility_desciption and ProfitCenter.print_facility_treatment_desc_on_container_labels_flag to result set.
03/29/2017 MPM	Added CWT Category and cwt_category_required_flag to result set.
09/19/2018 MPM	Added fields for sampling frequency tracking for bulk waste shipments to result set.

sp_schedule_detail_lines 0, 124251, 21, 0, 1, 'SHEILA_C'
***********************************************************************/

-- Get the info where there is a specific approval code
SELECT DISTINCT 
Schedule.confirmation_ID,   
Schedule.time_scheduled,   
Schedule.approval_code,   
Schedule.material,   
Schedule.quantity,   
Schedule.sched_quantity,   
Schedule.special_instructions,   
Schedule.end_block_time,   
Schedule.status,   
Profile.customer_id,   
Profile.generator_id,   
Schedule.bill_unit_code,   
wastecode.display_name,  --Profile.waste_code,     
Customer.cust_name,   
Generator.generator_name,   
Treatment.treatment_desc,   
ProfitCenter.profit_ctr_name,
billunit.gal_conv,
Profile.OTS_flag,
ProfileLab.DDVOC,
ProfileQuoteApproval.location_control,
Schedule.load_type,
ProfileQuoteApproval.fingerprint_type,
TreatmentDetail.facility_description,
isnull(ProfitCenter.print_facility_treatment_desc_on_container_labels_flag, 'F') as print_facility_desc_flag,
isnull(CWTCategory.cwt_category,'') as cwt_category,
DisposalService.cwt_category_required_flag,
ProfileQuoteApproval.bulk_load_sampling_frequency_required_flag,
ProfileQuoteApproval.loads_until_sample_required
INTO #tmp
FROM Schedule
	JOIN ProfitCenter ON Schedule.profit_ctr_id = ProfitCenter.profit_ctr_id
	    AND Schedule.company_id = ProfitCenter.company_id
	JOIN ProfileQuoteApproval ON (Schedule.approval_code = ProfileQuoteApproval.approval_code )
		AND ( Schedule.company_id = ProfileQuoteApproval.company_id  )
		AND ( Schedule.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id  )
	JOIN Profile ON (ProfileQuoteApproval.profile_id = Profile.profile_id)
		AND ( Profile.curr_status_code = 'A' )
	JOIN ProfileLab ON (ProfileQuoteApproval.profile_id = ProfileLab.profile_id)
		AND ( ProfileLab.type = 'A' )
	JOIN Generator ON ( Profile.generator_id = Generator.generator_id )
	JOIN Customer ON ( Profile.customer_id = Customer.customer_id )
	LEFT OUTER JOIN profileWasteCode ON ( profileWasteCode.profile_id = Profile.profile_id AND profileWasteCode.primary_flag = 'T')
    LEFT OUTER JOIN Wastecode ON ( Wastecode.waste_code_uid = profileWasteCode.waste_code_uid )
	JOIN Treatment ON (ProfileQuoteApproval.treatment_id = Treatment.treatment_id )
		AND ( ProfileQuoteApproval.company_id = Treatment.company_id )
		AND ( ProfileQuoteApproval.profit_ctr_id = Treatment.profit_ctr_id )
	JOIN TreatmentDetail ON TreatmentDetail.treatment_id = Treatment.treatment_id
		AND TreatmentDetail.company_id = @company_id
		AND TreatmentDetail.profit_ctr_id = @profit_ctr_id
	LEFT OUTER JOIN BillUnit ON ( Schedule.bill_unit_code = billunit.bill_unit_code)
	LEFT OUTER JOIN CWTCategory ON ProfileQuoteApproval.cwt_category_uid = CWTCategory.cwt_category_uid
	JOIN DisposalService ON Treatment.disposal_service_id = DisposalService.disposal_service_id
WHERE ( Schedule.confirmation_id = @confirmation_id ) AND 
( Schedule.company_id = @company_id ) AND 
( Schedule.profit_ctr_id = @profit_ctr_id ) AND 
( Schedule.end_block_time IS NULL ) and Schedule.status in ('A','P') and
Schedule.material in (SELECT material from ScheduleReport where user_code = @user_code) 

if @debug = 1 print 'Selecting from #tmp'
if @debug = 1 select * from #tmp

-- Store the specified quantities for the VARIOUS approvals
SELECT DISTINCT Schedule.confirmation_ID,   
Schedule.time_scheduled,   
Schedule.approval_code,   
Schedule.material,   
SUM(ScheduleApproval.quantity) as quantity,
SUM(ScheduleApproval.sched_quantity) as sched_quantity,
Schedule.special_instructions,   
Schedule.end_block_time,   
Schedule.status,   
CONVERT(int, NULL) as customer_id,   
CONVERT(int, NULL) as generator_id,   
ScheduleApproval.bill_unit_code,   
CONVERT(varchar(10), NULL) as waste_code,   
Schedule.contact_company as cust_name,   
CONVERT(varchar(40), NULL) as generator_name,   
CONVERT(varchar(50), NULL) as treatment_desc,   
ProfitCenter.profit_ctr_name,
BillUnit.gal_conv,   
CONVERT(varchar(1), NULL) as OTS_flag,
CONVERT(float, NULL) as DDVOC,
CONVERT(varchar(1), NULL) as location_control,
Schedule.load_type,
CONVERT(varchar(15), NULL) as fingerprint_type,
CONVERT(varchar(20), NULL) as facility_description,
isnull(ProfitCenter.print_facility_treatment_desc_on_container_labels_flag, 'F') as print_facility_desc_flag,
CONVERT(varchar(10), NULL) as cwt_category,
CONVERT(char(1), NULL) as cwt_category_required_flag,
CONVERT(char(1), NULL) as bulk_load_sampling_frequency_required_flag,
CONVERT(int, NULL) as loads_until_sample_required   
INTO #various
FROM Schedule
	JOIN ProfitCenter ON Schedule.profit_ctr_id = ProfitCenter.profit_ctr_id
	    AND Schedule.company_id = ProfitCenter.company_id
	JOIN ScheduleApproval ON (Schedule.confirmation_id = ScheduleApproval.confirmation_id)
	    AND Schedule.company_id = ScheduleApproval.company_id
		AND Schedule.profit_ctr_id = ScheduleApproval.profit_ctr_id
	JOIN ProfileQuoteApproval ON (ScheduleApproval.approval_code = ProfileQuoteApproval.approval_code )  
		AND ( ScheduleApproval.company_id = ProfileQuoteApproval.company_id  )  
		AND ( ScheduleApproval.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id  )
	JOIN Profile ON (ProfileQuoteApproval.profile_id = Profile.profile_id)
		AND ( Profile.curr_status_code = 'A' )
	LEFT OUTER JOIN BillUnit ON ( Schedule.bill_unit_code = billunit.bill_unit_code)
WHERE ( Schedule.approval_code = 'VARIOUS' ) and 
( Schedule.confirmation_id = @confirmation_id ) AND 
( Schedule.company_id = @company_id ) AND 
( Schedule.profit_ctr_id = @profit_ctr_id ) AND 
( Schedule.end_block_time IS NULL ) and Schedule.status in ('A','P') 
AND Schedule.material in (SELECT material from ScheduleReport where user_code = @user_code) 
GROUP BY
Schedule.confirmation_ID,   
Schedule.time_scheduled,   
Schedule.approval_code,   
Schedule.material,   
Schedule.special_instructions,   
Schedule.end_block_time,   
Schedule.status,   
ScheduleApproval.bill_unit_code,   
Schedule.contact_company,   
ProfitCenter.profit_ctr_name,
BillUnit.gal_conv,
Schedule.load_type,
ProfitCenter.print_facility_treatment_desc_on_container_labels_flag


if @debug = 1 print 'Selecting from #various'
if @debug = 1 select * from #various

-- Store the non-specified quantity for VARIOUS approvals as DM55s
SELECT DISTINCT Schedule.confirmation_ID,   
Schedule.time_scheduled,   
Schedule.approval_code,   
Schedule.material,   
Schedule.quantity,   
Schedule.sched_quantity,   
Schedule.special_instructions,   
Schedule.end_block_time,   
Schedule.status,   
CONVERT(int, NULL) as customer_id,   
CONVERT(int, NULL) as generator_id,   
'DM55' as bill_unit_code,   
CONVERT(varchar(10), NULL) as waste_code,   
Schedule.contact_company as cust_name,   
CONVERT(varchar(40), NULL) as generator_name,   
CONVERT(varchar(50), NULL) as treatment_desc,   
ProfitCenter.profit_ctr_name,
55 as gal_conv,   
CONVERT(varchar(1), NULL) as OTS_flag,
CONVERT(float, NULL) as DDVOC,
CONVERT(varchar(1), NULL) as location_control,
Schedule.load_type,
CONVERT(varchar(15), NULL) as fingerprint_type,
CONVERT(varchar(20), NULL) as facility_description,
isnull(ProfitCenter.print_facility_treatment_desc_on_container_labels_flag, 'F') as print_facility_desc_flag,
CONVERT(varchar(10), NULL) as cwt_category,
CONVERT(char(1), NULL) as cwt_category_required_flag,
CONVERT(char(1), NULL) as bulk_load_sampling_frequency_required_flag,
CONVERT(int, NULL) as loads_until_sample_required   
INTO #various_drum
FROM Schedule
	JOIN ProfitCenter ON Schedule.profit_ctr_id = ProfitCenter.profit_ctr_id
	     AND Schedule.company_id = ProfitCenter.company_id
WHERE ( Schedule.approval_code = 'VARIOUS' ) and 
( Schedule.confirmation_id = @confirmation_id ) AND 
( Schedule.company_id = @company_id ) AND 
( Schedule.profit_ctr_id = @profit_ctr_id ) AND 
( Schedule.end_block_time IS NULL ) and Schedule.status in ('A','P') 
AND Schedule.material in (SELECT material from ScheduleReport where user_code = @user_code) 

if @debug = 1 print 'Selecting from #various_drum'
if @debug = 1 select * from #various_drum

-- Subtract the quantity of specified containers from the default quantity of non-specified containers
UPDATE #various_drum SET 
quantity = quantity - 
IsNull((select SUM(#various.quantity)
FROM #various
WHERE #various_drum.confirmation_id = #various.confirmation_id
GROUP BY
#various.confirmation_id), 0),
sched_quantity = sched_quantity - 
IsNull((select SUM(#various.sched_quantity)
FROM #various
WHERE #various_drum.confirmation_id = #various.confirmation_id
GROUP BY
#various.confirmation_id), 0)

if @debug = 1 print 'Selecting from #various_drum'
if @debug = 1 select * from #various_drum

-- Combine the like containers for the same confirmation ID
UPDATE #various SET
#various.quantity = #various.quantity + #various_drum.quantity,
#various.sched_quantity = #various.sched_quantity + #various_drum.sched_quantity
FROM #various_drum
WHERE #various.confirmation_id = #various_drum.confirmation_ID
AND #various.bill_unit_code = #various_drum.bill_unit_code

-- Remove the combined quantity records to report the non-specified drums
DELETE FROM #various_drum
FROM #various
WHERE #various.confirmation_id = #various_drum.confirmation_ID
AND #various.bill_unit_code = #various_drum.bill_unit_code

-- Return the results
SELECT * FROM #tmp
UNION ALL
SELECT * FROM #various 
UNION ALL
SELECT * FROM #various_drum WHERE quantity > 0
ORDER BY confirmation_ID

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_schedule_detail_lines] TO [EQAI]
    AS [dbo];

