drop PROCEDURE if exists sp_rpt_haz_waste_aging_fee
go


CREATE PROCEDURE dbo.sp_rpt_haz_waste_aging_fee (
	@company_id		 int
,	@profit_ctr_id	 int
)
AS
/*************************************************************************************************
Loads to : PLT_AI

Purpose:

Runs for one company profit center, listing all hazardous waste having been received ninety
days prior to report date and not yet disposed. The report displays un-processed un-disposed
hazardous waste tonnage received at least ninety days from report run date. Report displays
an aging fee per ton times the tonnage giving amount collected in fees but not yet paid to
receiving agent.

History:

03/29/2018 Created Rich Bianco - Used by r_haz_waste_aging_fee
04/03/2018 Rich Bianco - Fixed remove check looking for lines having fees assigned
05/02/2018 Rich Bianco - Modify report to use the final disposal date column Jason created.
05/03/2018 Rich Bianco - Use Profit Center column for rate amount.
08/09/2018 AM EQAI-52778 - Added days_on_site field. 
04/12/2023 Uday Gattu - DevOps58060 - Added the Inner Join for Container table and two extra conditions in where clause for ContainerDestination table's status column and > 90 days


EXECUTE dbo.sp_rpt_haz_waste_aging_fee  21, 0 
dbo.sp_rpt_haz_waste_aging_fee  14, 6
*************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@as_of_date datetime
	
-- Set the date
SELECT @as_of_date = GETDATE()

SELECT 
	r.company_id,
	r.profit_ctr_id,
	r.receipt_id,
	r.line_id,
	r.receipt_date,
	r.approval_code AS profile_number,
	cd.container_id,
	cd.sequence_id,
	pc.profit_ctr_name,
	r.manifest,
	r.manifest_page_num, 
	r.manifest_line,
	dbo.fn_receipt_waste_code_list_state(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id) as state_waste_codes,
	ROUND(dbo.fn_receipt_weight_container(
						cd.receipt_id, 
						cd.line_id, 
						cd.profit_ctr_id, 
						cd.company_id, 
						cd.container_id, 
						cd.sequence_id) / 2000, 8) AS wt_tons,	
	cd.container_percent,
	IsNull(pc.haz_waste_aging_fee_rate, 0.00) AS haz_waste_aging_fee_rate,
	DATEDIFF(dd, cd.date_added, @as_of_date) AS days_on_site,
	--DATEDIFF(dd, receipt.receipt_date, @as_of_date) AS days_on_site
	cd.date_added
FROM ContainerDestination cd
INNER JOIN Receipt AS r 
	ON	cd.receipt_id		= r.receipt_id
	AND	cd.line_id			= r.line_id
	AND cd.company_id		= r.company_id 
	AND cd.profit_ctr_id	= r.profit_ctr_id 
INNER JOIN Container AS c
	on cd.company_id = c.company_id
	and cd.profit_ctr_id = c.profit_ctr_id
	and cd.receipt_id = c.receipt_id
	and cd.line_id = c.line_id
	and cd.container_id = c.container_id
	and cd.container_type = c.container_type
	and c.status not in ('V', 'R', 'C', 'X')
INNER JOIN Profile AS p
	ON	r.profile_id		= p.profile_id
INNER JOIN ProfitCenter pc
	ON	pc.company_id		= r.company_id
	AND pc.profit_ctr_id	= r.profit_ctr_id
WHERE cd.company_id			= @company_id
  AND cd.profit_ctr_id		= @profit_ctr_id
  AND cd.status not in ('V', 'R', 'C', 'X')
  AND DATEDIFF(dd, cd.date_added, @as_of_date) > 90
  AND ISNULL(dbo.fn_get_container_final_destination_disposal_date(cd.company_id, cd.profit_ctr_id, cd.receipt_id, cd.line_id, cd.container_id, cd.container_type, cd.sequence_id, NULL),GETDATE() - 91) 
		<  GETDATE() - 90
  AND EXISTS 
	(SELECT 1 FROM ReceiptWasteCode rwc		-- Hazardous waste only
	 JOIN WasteCode wc ON wc.waste_code = rwc.waste_code AND wc.haz_flag = 'T'  
	 WHERE rwc.receipt_id = r.receipt_id  
	 AND rwc.company_id = r.company_id   
	 AND rwc.profit_ctr_id = r.profit_ctr_id) 
  AND r.receipt_status		= 'A'
  AND r.fingerpr_status		= 'A'
  AND r.submitted_flag		= 'T' 
  AND r.trans_type			= 'D' 


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_haz_waste_aging_fee] TO [EQAI];

GO

