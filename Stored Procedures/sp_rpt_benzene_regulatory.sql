
CREATE PROCEDURE sp_rpt_benzene_regulatory
	@company_id			int
,   @profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@generator_from		varchar(40)
,	@generator_to		varchar(40)
,	@epa_id_from		varchar(12)
,	@epa_id_to			varchar(12)
AS
/***********************************************************************
This procedure runs for Benzene NESHAP TAB Report

PB Object(s):	r_benzene_regulatory

11/18/2010 SK	Created on Plt_AI
02/28/2014 AM   Added profit_ctr_id	to where clause
03/10/2014 AM   Removed wastecode and ReceiptWasteCode join. Added to where clause to check any one of the billing waste code has haz_flag = 'T' instead of primary wastecode.		
03/24/2014 AM   Modified code to get data from Receipt table than billing table. Aso calling function to get waste_quantity.

sp_rpt_benzene_regulatory 21, 0,'2008-01-01', '2008-12-31', '0', 'ZZZZZZZZ', '0', 'ZZZZZZZZZZZZ'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT Receipt.company_id
,	Receipt.profit_ctr_id
--,	ProfileQuoteApproval.approval_code 
,	Receipt.approval_code 
,	Generator.sic_code
,	ProfileLab.neshap_sic
,	ProfileLab.avg_h20_gr_10
,	ProfileLab.benzene_waste_type
--,	waste_quantity = Billing.quantity * BillUnit.kg_conv
,	waste_quantity = CAST(((dbo.fn_receipt_weight_container (Receipt.receipt_id, Receipt.line_id, Receipt.profit_ctr_id, Receipt.company_id, ContainerDestination.container_id, ContainerDestination.sequence_id)) * BillUnit.kg_conv) AS DECIMAL(18,4))
,	ProfileLab.benzene
--,	WasteCode.haz_flag
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN BillUnit
	ON BillUnit.bill_unit_code = 'LBS'
JOIN ProfitCenter 
	ON ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
	   AND ProfitCenter.company_ID = Receipt.company_id 
--JOIN ReceiptWasteCode
	--ON ReceiptWasteCode.company_id = Billing.company_id
	--AND ReceiptWasteCode.profit_ctr_id = Billing.profit_ctr_id
	--AND ReceiptWasteCode.receipt_id = Billing.receipt_id
	--AND ReceiptWasteCode.line_id = Billing.line_id
	--AND ReceiptWasteCode.primary_flag = 'T'
--JOIN ProfileQuoteApproval
--	ON ProfileQuoteApproval.company_id = Billing.company_id
--	AND ProfileQuoteApproval.profit_ctr_id = Billing.profit_ctr_id
--	AND ProfileQuoteApproval.approval_code = Billing.approval_code
JOIN Profile
	ON Profile.profile_id = Receipt.profile_id
	-- AND Profile.curr_status_code = 'A'
JOIN ProfileLab
	ON ProfileLab.profile_id = Profile.profile_id
	AND ProfileLab.type = 'A'
	AND ProfileLab.benzene > 0
	AND ProfileLab.avg_h20_gr_10 = 'T'
JOIN Generator
	ON Generator.generator_id = Profile.generator_id
	AND Generator.generator_name BETWEEN @generator_from AND @generator_to
	AND Generator.epa_id BETWEEN @epa_id_from AND @epa_id_to
--JOIN WasteCode
--	ON WasteCode.waste_code_uid = ReceiptWasteCode.waste_code_uid
	--AND WasteCode.haz_flag = 'T'
JOIN ContainerDestination
	ON ContainerDestination.company_id = Receipt.company_id
	AND ContainerDestination.profit_ctr_id = Receipt.profit_ctr_id
	AND ContainerDestination.receipt_id = Receipt.receipt_id
	AND ContainerDestination.line_id = Receipt.line_id
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
    AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
    AND ( Receipt.receipt_status = 'A' or Receipt.waste_accepted_flag = 'T')
	AND  Receipt.trans_type = 'D' 
	AND Exists ( select 1 from ReceiptWasteCode rwc 
                Join WasteCode on WasteCode.waste_code_uid = rwc.waste_code_uid
                 AND  WasteCode.haz_flag = 'T' 
			   Where Receipt.company_id = rwc.company_id 
			   AND  Receipt.profit_ctr_id = rwc.profit_ctr_id
			   and Receipt.receipt_id = rwc.receipt_id 
			   and Receipt.line_id = rwc.line_id )
	AND ContainerDestination.disposal_date  BETWEEN @date_from AND @date_to
	AND (Generator.sic_code IN ( 2812, 2813, 2816, 2819, 2821, 2822, 2823, 2824, 2833, 2834, 
								2835, 2836, 2841, 2842, 2843, 2844, 2851, 2861, 2865, 2869, 
								2873, 2874, 2875, 2879, 2891, 2892, 2893, 2895, 2899, 2911, 
								3312, 4953, 9511 )
		OR
		(ProfileLab.neshap_sic IN (2812, 2813, 2816, 2819, 2821, 2822, 2823, 2824, 2833, 2834, 
								2835, 2836, 2841, 2842, 2843, 2844, 2851, 2861, 2865, 2869, 
								2873, 2874, 2875, 2879, 2891, 2892, 2893, 2895, 2899, 2911, 
								3312, 4953, 9511 )
		))

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_benzene_regulatory] TO [EQAI]
    AS [dbo];

