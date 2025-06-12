-- drop proc sp_rpt_waste_received_tx_inout_state
GO

CREATE  PROCEDURE [dbo].[sp_rpt_waste_received_tx_inout_state]
	@company_id			int
,	@profit_ctr_id      int
,	@date_from			datetime
,	@date_to			datetime
AS
/**************************************************************************************
This procedure runs for Waste Received from Generators Report
PB Object(s):	r_waste_rec

07/03/2019 OE	Created
07/19/2019 MPM	DevOps 12162 - Cast result of fn_receipt_weight_line to money to fix "decimal 
				conversion error".
07/22/2019 MPM	DevOps 12174 - Modifications.

[sp_rpt_waste_received_tx_inout_state] 55 ,0, '7/1/19', '7/30/19'  
**************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT 
		Company.company_name,
	ProfitCenter.profit_ctr_name,
	      r.receipt_date,
	CASE WHEN g.generator_state = 'TX' THEN cast(isnull(dbo.fn_receipt_weight_line (r.receipt_id, r.line_id, r.profit_ctr_id, r.company_id), 0) as money) ELSE 0 END as in_state_weight_recd_in_tons, 
	CASE WHEN g.generator_state <> 'TX' THEN cast(isnull(dbo.fn_receipt_weight_line (r.receipt_id, r.line_id, r.profit_ctr_id, r.company_id), 0) as money) ELSE 0 END as out_of_state_weight_recd_in_tons
from receipt r 
JOIN Company
	ON Company.company_id = @company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = @company_id
	AND ProfitCenter.profit_ctr_ID = @profit_ctr_id
	join generator g
		on r.generator_id = g.generator_id
	join tsdf t
		on t.eq_company = @company_id
		and t.eq_profit_ctr = @profit_ctr_id
		and t.tsdf_status = 'A'
		and t.eq_flag = 'T'
		and t.tsdf_state = 'TX' 
	left outer join transporter tr
		on r.hauler = tr.transporter_code
	left outer join TransporterXStateID trid
		on tr.transporter_code = trid.transporter_code
		and trid.transporter_state = 'TX'
		and trid.status = 'A' 
where 
	r.receipt_date between @date_from AND @date_to 
	and r.company_id = @company_id
	and r.profit_ctr_id = @profit_ctr_id
	and r.receipt_status not in ('V', 'R')  
	and r.fingerpr_status not in ('V', 'R')
	and r.trans_mode = 'I'  
	and r.trans_type = 'D' 
	order by Company.company_name, ProfitCenter.profit_ctr_name, r.receipt_date
GO

	grant execute on [sp_rpt_waste_received_tx_inout_state] to eqai;
GO
	--commit


