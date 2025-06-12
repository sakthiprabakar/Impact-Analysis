
CREATE PROCEDURE sp_rpt_benzene_analysis_worksheet
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
This procedure runs for Benzene NESHAP TAB Worksheet Concentration > 0

PB Object(s):	r_benzene_analysis_worksheet

11/17/2010 SK	Created on Plt_AI
10/06/2011 SK	Added Join to Receipt to fetch receiptdate
02/03/2012 SK	Added left outer join to proces location
02/01/2013 RB   Added DISTINCT because join to ContainerDestination was retrieving duplicates
04/25/2013 SK	1)Changed to determine the value of tranship by using the check for Treatment process of Tranship
					rather than for the tranship flag on the profile.
				2)Changed to print both the inbound processing and outbound location from ContainerDestination
05/08/2013 SK	The treatment is taken from the Container. The report was changed to retrieve per container and then group by location and tranship flag
				As a result calcualtions for waste quantity were changed to be by container weight in pounds. This is then multiplied by kg_conv for pounds
				to obtain the final waste quantity.
				Also receipt_id, line_id fields were added to the output and 'DISTINCT' was removed from the base query as now 
				the join to container destination wont retrive duplicates
08/21/2013 SM	Added wastecode table and displaying Display name
02/20/2014 AM   Added fn_get_container_location to get correct container outbound receipt location. Changed where clause to get data from receipt not from 
				Billing. Changed billing date to disposal_date to get data from. Added profit_ctr_id to where clause
03/10/2014 AM   Removed wastecode and ReceiptWasteCode join. Added to where clause to check any one of the receipt waste code has haz_flag = 'T' instead of primary wastecode.		

sp_rpt_benzene_analysis_worksheet 21, '2012-01-01', '2012-12-31', 0, 'ZZZZZZZZ', '0', 'ZZZZZZZZZZZZ'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

declare @receipt_id int

SELECT 
	Receipt.company_id
,	Receipt.profit_ctr_id
,	Receipt.receipt_id
,	Receipt.line_id
,	ContainerDestination.container_id
,	ContainerDestination.sequence_id
,	Receipt.approval_code 
,	Generator.generator_name
--,	wastecode.display_name as waste_code
,	Generator.sic_code
,	ProfileLab.neshap_sic
,	ProfileLab.avg_h20_gr_10
,	ProfileLab.benzene_waste_type
,	isnull(ContainerDestination.container_percent,100) as container_percent
,	cont_weight = dbo.fn_receipt_weight_container (Receipt.receipt_id, Receipt.line_id, Receipt.profit_ctr_id, Receipt.company_id, ContainerDestination.container_id, ContainerDestination.sequence_id)
,	waste_quantity = CAST(((dbo.fn_receipt_weight_container (Receipt.receipt_id, Receipt.line_id, Receipt.profit_ctr_id, Receipt.company_id, ContainerDestination.container_id, ContainerDestination.sequence_id)) * BillUnit.kg_conv) AS DECIMAL(18,4))
--,	Billing.quantity
--,	Billing.bill_unit_code
--,	waste_quantity = Billing.quantity * BillUnit.kg_conv
,	ProfileLab.benzene
,	ProfileLab.neshap_exempt
--,	WasteCode.haz_flag
,	Generator.TAB
,	ProfitCenter.profit_ctr_name
--,	Profile.transship_flag
,	CASE TreatmentProcess.code WHEN 'Tranship' THEN 'T' ELSE 'F' END AS approval_transship_flag
,	Receipt.receipt_date
,	ContainerDestination.disposal_date
--,	ContainerDestination.location as location
,  location = ( select  dbo.fn_get_all_container_location ( Receipt.company_id, Receipt.profit_ctr_id, Receipt.receipt_id,  Receipt.line_id, ContainerDestination.container_id ) ) 
INTO #benzene_container
FROM Receipt
JOIN BillUnit
	ON BillUnit.bill_unit_code = 'LBS'
JOIN ProfitCenter 
	ON ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
	   AND ProfitCenter.company_ID = Receipt.company_id 
--JOIN ReceiptWasteCode
	--ON ReceiptWasteCode.company_id = Receipt.company_id
	--AND ReceiptWasteCode.profit_ctr_id = Receipt.profit_ctr_id
	--AND ReceiptWasteCode.receipt_id = Receipt.receipt_id
	--AND ReceiptWasteCode.line_id = Receipt.line_id
	--AND ReceiptWasteCode.primary_flag = 'T'
JOIN Profile
   ON Profile.profile_id = Receipt.profile_id
	--AND Profile.curr_status_code = 'A'
JOIN ProfileLab
	ON ProfileLab.profile_id = Profile.profile_id
	AND ProfileLab.type = 'A'
	AND ProfileLab.benzene > 0
JOIN Generator
	ON Generator.generator_id = Profile.generator_id
	AND Generator.generator_name BETWEEN @generator_from AND @generator_to
	AND Generator.epa_id BETWEEN @epa_id_from AND @epa_id_to
--JOIN WasteCode
	--ON WasteCode.waste_code_uid = Receipt.waste_code_uid
	--AND WasteCode.haz_flag = 'T'
JOIN ContainerDestination
	ON ContainerDestination.company_id = Receipt.company_id
	AND ContainerDestination.profit_ctr_id = Receipt.profit_ctr_id
	AND ContainerDestination.receipt_id = Receipt.receipt_id
	AND ContainerDestination.line_id = Receipt.line_id
--	AND ContainerDestination.location_type = 'P'
--LEFT OUTER JOIN ProcessLocation
--	ON ProcessLocation.company_id = ContainerDestination.company_id
--	AND ProcessLocation.profit_ctr_id = ContainerDestination.profit_ctr_id
--	AND ProcessLocation.location = ContainerDestination.location
LEFT OUTER JOIN Treatment
	ON Treatment.treatment_id = ContainerDestination.treatment_id
	AND Treatment.company_id = ContainerDestination.company_id
	AND Treatment.profit_ctr_id = ContainerDestination.profit_ctr_id
LEFT OUTER JOIN TreatmentProcess
	ON TreatmentProcess.treatment_process_id = Treatment.treatment_process_id
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
		--debug: AND Receipt.receipt_id = 841546
ORDER BY Receipt.receipt_id, Receipt.line_id

--Select * from #benzene_container 
-- Group and select results
SELECT company_id
,  profit_ctr_id 
,	receipt_id
,	line_id
,	approval_code
,	generator_name
--,	waste_code
,	sic_code
,	neshap_sic
,	avg_h20_gr_10
,	benzene_waste_type
,	COUNT(container_id) AS container_count
,	SUM(waste_quantity) AS c_waste_qty
,	benzene
,	neshap_exempt
--,	haz_flag
,	TAB
,	profit_ctr_name
,	approval_transship_flag
,	receipt_date
,   disposal_date 
,	location
FROM #benzene_container 
GROUP BY 
	company_id
, profit_ctr_id
,	receipt_id
,	line_id
,	approval_code
,	generator_name
--,	waste_code
,	sic_code
,	neshap_sic
,	avg_h20_gr_10
,	benzene_waste_type
,	benzene
,	neshap_exempt
--,	haz_flag
,	TAB
,	profit_ctr_name
,	approval_transship_flag
,	receipt_date
,   disposal_date 
,	location
Order By receipt_id, line_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_benzene_analysis_worksheet] TO [EQAI]
    AS [dbo];

