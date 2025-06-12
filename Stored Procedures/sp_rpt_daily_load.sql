-- DROP PROCEDURE dbo.sp_rpt_daily_load
GO

CREATE PROCEDURE [dbo].[sp_rpt_daily_load] (
	@company_id		 int
,	@profit_ctr_id	 int
,	@date_from		datetime
,	@date_to		datetime
)
AS
/*************************************************************************************************
Filename:	L:\IT Apps\SourceCode\Development\SQL\Jacqueline\-
               DevOps task 11274 - Report Create Daily Load Report\sp_rpt_daily_load.aql
PB Object(s):	r_daily_load_report
Loads to:		PlT_AI
	
06/04/219	JXM  Created
06/05/2019	JXM	 Add case to receipt_status, add receipt_id, line_id, case for container_type
				 switch function use, case for container wash water.
06/19/2019  JXM  Add 2 parameters to function call to get total gallons due to function changes.	
07/16/2019	MPM	DevOps task 12139 - Modified so that calculated gallons is not calculated for 
				a washout line and net_weight isn't shown for a washout line.
					   
Purpose:  Generate a list of all inbound loads received for each day. 
		  Report should be able to be run for a single day or a range.  
		  If the user selects to run this for ALL Deep Well Batches over a month, 
		  it should generate a separate page for every date of processing and for 
		  every destination Batch Location.
sp_rpt_daily_load 22, 0, '2019/05/01', '2019/05/02'	  
*************************************************************************************************/
SELECT DISTINCT 
       r.receipt_date
,      CASE
         WHEN r.submitted_flag = 'T' THEN 'Submitted'
              WHEN ( r.receipt_status is NULL OR r.receipt_status = 'N') THEN 'New'
              WHEN r.receipt_status = 'M' THEN 'Manual'
              WHEN r.receipt_status = 'H' THEN 'Hold'
              WHEN r.receipt_status = 'L' THEN 'In the Lab'
              WHEN r.receipt_status = 'U' THEN ( CASE  
                                                                           WHEN r.waste_accepted_flag = 'T' THEN 'Waste Accepted' 
                                                                           ELSE 'Unloading' 
                                                                           END )
              WHEN r.receipt_status = 'V' THEN 'Void'
              WHEN r.receipt_status = 'T' THEN 'In-Transit'
              WHEN r.receipt_status = 'R' THEN 'Rejected'
              WHEN r.receipt_status = 'A' THEN 'Accepted' 
               END AS 'receipt_status'
,      CAST(r.receipt_id as varchar)+'-'+CAST(r.line_id as varchar) as receipt_line_ids
,      r.manifest
,      r.generator_id
,      g.generator_name
,      t.transporter_code
,      t.transporter_name
,      r.approval_code
,         r.manifest_container_code as container_type
,      r.container_count
,      CASE WHEN r.fingerpr_status = 'A' AND r.trans_type = 'D' THEN CAST( ( dbo.fn_calculated_gallons(r.company_id,r.profit_ctr_id,r.receipt_id,r.line_id,null,null  )) AS NUMERIC(18,2)) ELSE NULL END as total_gallons
,      CASE WHEN r.trans_type = 'D' THEN r.net_weight ELSE NULL END as net_weight
,      cd.location as receiving_area
,      CASE
         WHEN cd.location = 'PIT'
         THEN 'X' END as pit_area
,      CASE
         WHEN cd.location <> 'PIT'
         THEN 'X' END as injection_area
,      CASE
         WHEN r.trans_type = 'W' THEN r.quantity END as container_wash_water 
,      company.company_name
,      ProfitCenter.profit_ctr_name
,      company.company_id
,      ProfitCenter.profit_ctr_id
FROM Receipt r
JOIN Company ON Company.company_id = r.company_id
JOIN ProfitCenter ON ProfitCenter.company_id = r.company_id
       AND ProfitCenter.profit_ctr_id = r.profit_ctr_id
JOIN Generator G ON  g.generator_id = r.generator_id 
Left Outer join Transporter t ON r.hauler = t.transporter_code
   and transporter_status = 'A'
Left outer join Container c ON r.receipt_id = c.receipt_id 
        AND r.company_id = c.company_id
        AND r.profit_ctr_id = c.profit_ctr_id
        AND r.line_id = c.line_id 
Left outer join ContainerDestination cd ON r.receipt_id = cd.receipt_id 
        AND r.company_id = cd.company_id
        AND r.profit_ctr_id = cd.profit_ctr_id
        AND r.line_id = cd.line_id 
        and cd.container_percent = 100
WHERE r.receipt_status <> 'R'
      AND r.receipt_date BETWEEN @date_from AND @date_to  
      AND r.company_id = @company_id 
      AND r.profit_ctr_id = @profit_ctr_id
         AND r.receipt_status not in('R','V')  
         AND r.trans_mode = 'I'  
         AND r.trans_type in('D','W')
order by r.receipt_date, CAST(r.receipt_id as varchar)+'-'+CAST(r.line_id as varchar), cd.location


GO
GRANT EXECUTE
	ON [dbo].[sp_rpt_daily_load]
	TO [EQAI]
GO

