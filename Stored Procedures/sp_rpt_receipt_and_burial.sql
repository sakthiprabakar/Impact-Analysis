
CREATE PROCEDURE sp_rpt_receipt_and_burial (
	@company_id		 int
,	@profit_ctr_id	 int
,	@date_from		datetime
,	@date_to		datetime
)
AS
/*************************************************************************************************
Loads to : PLT_AI

11/02/2017 RB	Created Rich Bianco  - Receipt and Burial Report for EQAI Lite is a disposal 
report modelled after existing Aesop report. It should pull only disposed waste that has a trench. 
1/12/2018 RB Fixed join problem 
1/7/2018 RB Added functions provided by Jason and new cubic feet function
2/4/2020 AM DevOps:14033 - Added TreatmentDetail join to get TD.management_code instead TH.management_code
2/5/2020 AM DevOps:14039 - Modified to get cell desc and trench desc rather than number
2/4/2021 MM	DevOps 19085 - Modified the call to fn_get_container_final_destination_disposal_date so that
			a null date value is passed in instead of ContainerDestination.disposal_date.

	fn_get_container_final_destination_disposal_date
	fn_get_container_final_destination_trench
	fn_get_container_final_destination_cell

PowerBuilder Object:  r_receipt_and_burial 	

EXECUTE sp_rpt_receipt_and_burial  45, 0, '2019-01-01', '2020-01-01'
*************************************************************************************************/

SELECT 
	cd.company_id,
	cd.profit_ctr_id,
	cd.receipt_id,
	cd.line_id,
	cd.container_id,
	cd.sequence_id,
	IsNull((select trench_desc from ContainerDestinationTrench where container_destination_trench_uid = 
		(select dbo.fn_get_container_final_destination_trench( r.company_id,r.profit_ctr_id,r.receipt_id,r.line_id,cd.container_id,
		    cd.container_type,cd.sequence_id))),'') AS trench_desc,
	--dbo.fn_get_container_final_destination_trench(r.company_id,r.profit_ctr_id,r.receipt_id,r.line_id,cd.container_id,
								--cd.container_type,cd.sequence_id)AS trench_desc,
	--dbo.fn_get_container_final_destination_cell(r.company_id,r.profit_ctr_id,r.receipt_id,r.line_id,cd.container_id,
								   --cd.container_type,cd.sequence_id) AS cell,
    IsNull((select cell from ContainerDestinationCell where container_destination_cell_uid =
	           (select dbo.fn_get_container_final_destination_cell( r.company_id,r.profit_ctr_id,r.receipt_id,r.line_id,cd.container_id,
			      cd.container_type,cd.sequence_id))),'') AS cell,
	gen.EPA_ID,
	gen.generator_name,
	gen.generator_address_1,
	gen.generator_city,
	gen.generator_state,
	p.profile_id,
	pqa.approval_code AS approval_code,			
	p.approval_desc AS waste_common_name,	
	td.management_code,
	cd.container_percent,
	cd.disposal_vol,
	dbo.fn_get_receipt_container_volume_cuft(
			r.company_id,r.profit_ctr_id,r.receipt_id,r.line_id,
			cd.container_id,cd.sequence_id,
			dbo.fn_receipt_weight_container(r.receipt_id, r.line_id,cd.profit_ctr_id,cd.company_id,cd.container_id, cd.sequence_id),
			cd.disposal_vol_bill_unit_code) As disposal_cuft,
	dbo.fn_get_container_final_destination_disposal_date(r.company_id,r.profit_ctr_id,r.receipt_id,r.line_id,cd.container_id,
									cd.container_type,cd.sequence_id, NULL)  AS disposal_date,
	dbo.fn_receipt_weight_container(r.receipt_id,r.line_id,cd.profit_ctr_id,cd.company_id,cd.container_id,cd.sequence_id) AS container_wt,
	IsNull(lab.density, 1.3) AS density,
	pc.profit_ctr_name
FROM ContainerDestination AS cd
INNER JOIN Receipt AS r 
	ON  r.receipt_id = cd.receipt_id
	AND r.line_id = cd.line_id
	AND r.company_id = cd.company_id
	AND r.profit_ctr_id	= cd.profit_ctr_id
INNER JOIN Generator gen
	ON gen.generator_id	= r.generator_id
INNER JOIN Profile AS p
	ON p.profile_id = r.profile_id
INNER JOIN ProfileQuoteApproval AS pqa
	ON p.profile_id = pqa.profile_id
   AND cd.company_id = pqa.company_id
   AND cd.profit_ctr_id = pqa.profit_ctr_id
LEFT OUTER JOIN ProfileLab AS lab
	ON p.profile_id = lab.profile_id
   AND lab.type = 'A'
INNER JOIN TreatmentHeader AS th
	ON th.treatment_id = cd.treatment_id
INNER JOIN TreatmentDetail AS td 
    ON th.treatment_id = td.treatment_id
     AND td.company_id = r.company_id
     AND td.profit_ctr_id = r.profit_ctr_id
INNER JOIN ProfitCenter AS pc
	ON	pc.company_id = r.company_id
	AND pc.profit_ctr_id = r.profit_ctr_id
WHERE cd.company_id	= @company_id
  AND cd.profit_ctr_id = @profit_ctr_id
  AND r.receipt_date BETWEEN @date_from AND @date_to
  AND r.receipt_status = 'A'
  AND r.fingerpr_status	= 'A'
  AND r.submitted_flag = 'T' 
  AND r.trans_type = 'D' 
  AND r.trans_mode = 'I'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_receipt_and_burial] TO [EQAI]
    AS [dbo];
