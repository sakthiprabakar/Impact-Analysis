--drop procedure sp_rpt_weight_rcvd_by_process_mgmt_group
--go
CREATE PROCEDURE sp_rpt_weight_rcvd_by_process_mgmt_group (
	@company_id		 int
,	@profit_ctr_id	 int
,	@date_from		datetime
,	@date_to		datetime
)
AS
/*************************************************************************************************
Loads to : PLT_AI

11.30.2017	Rich Bianco  NEW

Purpose: This is data source for new report Weight Rcvd. by Process, Management group, a report 
designed based off an existing inventory weight report in Aesop. The report was designed based 
on existing Aesop report for EQAI Lite. 

PowerBuilder objects using:
	r_weight_rcvd_by_process_mgmt_group_dtl  
	r_weight_rcvd_by_process_mgmt_group_sum

DevOps:37889 - AM - 03/23/2022 - Changed r.receipt_status = 'A'" TO r.receipt_status NOT IN ('R','V') -- Not (R)ejected, (V)oided"

exec sp_rpt_weight_rcvd_by_process_mgmt_group  45, 0, '1/1/2021', '12/31/2021' 
*************************************************************************************************/
SELECT 
	r.company_id,
	r.profit_ctr_id,
	convert(date, r.receipt_date) AS receipt_date,
	r.receipt_id,
	r.line_id,
	r.manifest,
	r.manifest_page_num, 
	r.manifest_line,
	r.bulk_flag,
	cd.container_id,
	cd.sequence_id,
	cd.container_percent,
	tp.treatment_process,
	pc.profit_ctr_name,
	tgrp.group_name AS management_group,
	r.manifest_unit AS manifest_container,
	round(dbo.fn_receipt_weight_container(
						cd.receipt_id, 
						cd.line_id, 
						cd.profit_ctr_id, 
						cd.company_id, 
						cd.container_id, 
						cd.sequence_id) / 2000, 8) AS container_wt
FROM dbo.ContainerDestination as cd with (nolock)
INNER JOIN Receipt as r with (nolock)
	ON	cd.receipt_id			= r.receipt_id
	AND	cd.line_id				= r.line_id
	AND cd.company_id			= r.company_id 
	AND cd.profit_ctr_id		= r.profit_ctr_id 
INNER JOIN TreatmentHeader as th with (nolock)
	ON cd.treatment_id			= th.treatment_id
INNER JOIN TreatmentProcess as tp with (nolock)
	ON th.treatment_process_id	= tp.treatment_process_id
INNER JOIN TreatmentProcessMgmtGroup as tgrp with (nolock)
    ON tp.treatmentprocessmgmtgroup_uid	= tgrp.treatmentprocessmgmtgroup_uid
INNER JOIN ProfitCenter pc with (nolock)
	ON	pc.company_id			= r.company_id
	AND pc.profit_ctr_id		= r.profit_ctr_id
WHERE cd.company_id				= @company_id
  AND cd.profit_ctr_id			= @profit_ctr_id
  AND cd.status 				NOT IN ('R','V')	-- Not (R)ejected, (V)oided
  AND cd.location_type			<> 'O'				-- Exclude (O)utbound
  AND r.receipt_date			>= @date_from
  AND r.receipt_date			<= @date_to
  AND r.trans_mode 				= 'I' 				-- (I)nbound 
  AND r.receipt_status			NOT IN ('R','V') --'A'
  AND r.fingerpr_status			= 'A'
  AND r.trans_type				= 'D' 

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_weight_rcvd_by_process_mgmt_group] TO [EQAI]
    AS [dbo];

