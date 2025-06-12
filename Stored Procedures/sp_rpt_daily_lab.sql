CREATE PROCEDURE sp_rpt_daily_lab
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
AS
/***************************************************************************************
PB Object: r_daily_lab

11/12/2010 SK Created on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name

sp_rpt_daily_lab 14, 4, '9/1/2005','9/21/2005', 1, 999999
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT 
	Receipt.manifest
,	Receipt.location
,	Receipt.approval_code
,	w.display_name as waste_code
,	Receipt.quantity
,	Receipt.bill_unit_code
,	Receipt.pH_value
,	Receipt.cyanide_spot
,	Receipt.sulfide_gr100
,	Receipt.react_NaOH
,	Receipt.react_HCL
,	Receipt.odor
,	ProfileLab.color
,	Profilelab.consistency
,	Receipt.modified_by
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Receipt.water_react
,	Receipt.ignitability
,	Receipt.color_match
,	Receipt.consist_match
,	Receipt.reacts_box
,	Receipt.sludge_quantity
,	Receipt.lab_comments
,	Receipt.fingerpr_status
,	Receipt.chemist
,	Receipt.receipt_date
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
LEFT OUTER JOIN Profile
	ON Profile.profile_id = Receipt.profile_id
	AND Profile.curr_status_code = 'A'
INNER JOIN Profilelab
	ON ProfileLab.profile_id = Profile.profile_id
	AND Profilelab.type = 'A'
LEFT OUTER JOIN WasteCode w
	ON w.waste_code_uid = receipt.waste_code_uid
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Receipt.trans_type = 'D' 
	AND Receipt.trans_mode = 'I' 
	AND Receipt.receipt_status <> 'V'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_daily_lab] TO [EQAI]
    AS [dbo];

