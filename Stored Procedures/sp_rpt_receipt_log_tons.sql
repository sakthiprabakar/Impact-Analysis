CREATE PROCEDURE [dbo].[sp_rpt_receipt_log_tons] 
	@company_id				int
,	@profit_ctr_id			int
,	@receipt_date_from		datetime
,	@receipt_date_to		datetime
,	@customer_id_from		int
,	@customer_id_to			int
AS
/*****************************************************************************
Filename:		L:\IT Apps\SQL-Deploy\Prod\NTSQL1\PLT_AI\Procedures\sp_rpt_receipt_log_tons
PB Object(s):	r_receiving_log_tons

07/29/2014 JDB	Created. Copied and adjusted from queries that we used to provide
				tons received into WDI to Kerry Durnen (for Jeff Feeler and Simon Bell)
				for 2008 through 2013.

sp_rpt_receipt_log_tons 3, 0, '1/1/13', '1/31/13', 1, 999999
sp_rpt_receipt_log_tons 3, 0, '1/1/13', '12/31/13', 1, 999999
sp_rpt_receipt_log_tons 3, 0, '2/1/13', '2/28/13', 1, 999999
sp_rpt_receipt_log_tons 3, 0, '1/1/14', '1/31/14', 1, 999999
*****************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT 
	Receipt.company_id
	, Receipt.profit_ctr_id
	, ProfitCenter.profit_ctr_name
	, Receipt.receipt_date
	, DATEPART(mm, receipt.receipt_date) AS receipt_date_month
	, DATEPART(yyyy, receipt.receipt_date) AS receipt_date_year
	, Receipt.manifest_flag
	, Receipt.manifest
	, Receipt.time_in
	, Receipt.time_out
	, Receipt.customer_id
	, Customer.cust_name
	, Receipt.generator_id AS generator_id
	, Generator.EPA_ID
	, Generator.generator_name
	, Receipt.hauler AS transporter_code
	, Transporter.transporter_name
	, Receipt.receipt_id
	, Receipt.line_id
	, Receipt.profile_id
	, Receipt.approval_code
	, Profile.approval_desc
	, Receipt.bulk_flag
	, ISNULL(Profile.waste_water_flag, 'N') AS waste_water_flag
	, COALESCE(Receipt.treatment_id, ProfileQuoteApproval.treatment_id, 0) AS treatment_id
	, haz_flag = CASE WHEN (
		EXISTS (
			SELECT 1
			FROM ContainerWasteCode CW (NOLOCK) 
			JOIN WasteCode (NOLOCK) ON CW.waste_code_uid = WasteCode.waste_code_uid
				AND WasteCode.status = 'A'
				AND WasteCode.waste_code_origin = 'F'
				AND ISNULL(WasteCode.haz_flag,'F') = 'T'
			WHERE Receipt.company_id = CW.company_id 
			AND Receipt.profit_ctr_id = CW.profit_ctr_id
			AND Receipt.receipt_id = CW.receipt_id
			AND Receipt.line_id = CW.line_id
			)
		OR 
		EXISTS (
			SELECT 1 
			FROM ReceiptWasteCode RWC (NOLOCK) 
			JOIN WasteCode (NOLOCK) ON RWC.waste_code_uid = WasteCode.waste_code_uid
				AND WasteCode.waste_code_origin = 'F'
				AND ISNULL(WasteCode.haz_flag,'F') = 'T'
				AND WasteCode.status = 'A'
			WHERE Receipt.company_id = RWC.company_id 
			AND Receipt.profit_ctr_id = RWC.profit_ctr_id
			AND Receipt.receipt_id = RWC.receipt_id
			AND Receipt.line_id = RWC.line_id
			AND NOT EXISTS (
				SELECT 1 
				FROM ContainerWasteCode CW (NOLOCK) 
				JOIN WasteCode (NOLOCK) ON CW.waste_code_uid = WasteCode.waste_code_uid
					AND WasteCode.status = 'A'
				WHERE Receipt.company_id = CW.company_id 
				AND Receipt.profit_ctr_id = CW.profit_ctr_id
				AND Receipt.receipt_id = CW.receipt_id
				AND Receipt.line_id = CW.line_id
				)
			)
		) THEN 'T' ELSE 'F' END
	, Receipt.location
	, ProfileQuoteHeader.job_type
	, from_MDI = CASE WHEN Generator.EPA_ID = (SELECT EPA_ID FROM ProfitCenter pcMDI (NOLOCK) WHERE pcMDI.company_ID = 2 AND pcMDI.profit_ctr_ID = 0) AND Generator.generator_country = 'USA' THEN 'T' ELSE 'F' END
	, tons_received = CONVERT(money, (dbo.fn_receipt_weight_line(Receipt.receipt_id, Receipt.line_id, Receipt.profit_ctr_id, Receipt.company_id))/2000)
	--, generic_weight_method = dbo.fn_receipt_weight_line_description(Receipt.receipt_id, Receipt.line_id, Receipt.profit_ctr_id, Receipt.company_id, 0)
	--, specific_weight_method = dbo.fn_receipt_weight_line_description(Receipt.receipt_id, Receipt.line_id, Receipt.profit_ctr_id, Receipt.company_id, 1)
INTO #tmp_container_IB
FROM Receipt (NOLOCK)
JOIN ProfitCenter (NOLOCK) ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
JOIN Customer (NOLOCK) ON Customer.customer_ID = Receipt.customer_ID
JOIN Generator (NOLOCK) ON Generator.generator_id = Receipt.generator_id
JOIN Profile (NOLOCK) ON Receipt.profile_id = Profile.Profile_id
JOIN ProfileQuoteApproval (NOLOCK) ON Profile.profile_id = ProfileQuoteApproval.profile_id
	AND Receipt.profit_ctr_id = ProfileQuoteApproval.profit_ctr_id
	AND Receipt.company_id = ProfileQuoteApproval.company_id
JOIN ProfileQuoteHeader (NOLOCK) ON Profile.profile_id = ProfileQuoteHeader.profile_id
	AND Profile.quote_id = ProfileQuoteHeader.quote_id
LEFT OUTER JOIN Transporter (NOLOCK) ON Transporter.transporter_code = Receipt.hauler
WHERE 
	Receipt.company_id = @company_id
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.trans_mode = 'I'
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status NOT IN ('T', 'V', 'R')
	AND Receipt.fingerpr_status NOT IN ('V', 'R')
	--AND Receipt.manifest_flag <> 'B'			-- Jonathan's initial report excluded BOLs, but that would exclude all waste from MDI
	AND Receipt.receipt_date BETWEEN @receipt_date_from AND @receipt_date_to
	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
ORDER BY
	Receipt.company_id
	, Receipt.profit_ctr_id
	, Receipt.receipt_id
	, Receipt.line_id


SELECT #tmp_container_IB.company_id
	, #tmp_container_IB.profit_ctr_id
	, #tmp_container_IB.profit_ctr_name
	, #tmp_container_IB.receipt_date
	, #tmp_container_IB.receipt_date_month
	, #tmp_container_IB.receipt_date_year
	, #tmp_container_IB.manifest_flag
	, #tmp_container_IB.manifest
	, #tmp_container_IB.time_in
	, #tmp_container_IB.time_out
	, #tmp_container_IB.customer_id
	, #tmp_container_IB.cust_name
	, #tmp_container_IB.generator_id
	, #tmp_container_IB.EPA_ID
	, #tmp_container_IB.generator_name
	, #tmp_container_IB.transporter_code
	, #tmp_container_IB.transporter_name
	, #tmp_container_IB.receipt_id
	, #tmp_container_IB.line_id
	, #tmp_container_IB.profile_id
	, #tmp_container_IB.approval_code
	, #tmp_container_IB.approval_desc
	, #tmp_container_IB.bulk_flag
	, #tmp_container_IB.waste_water_flag
	, #tmp_container_IB.treatment_id
	, #tmp_container_IB.haz_flag
	, #tmp_container_IB.location
	, #tmp_container_IB.job_type
	, #tmp_container_IB.from_MDI
	, #tmp_container_IB.tons_received
	--, #tmp_container_IB.generic_weight_method
	--, #tmp_container_IB.specific_weight_method 
FROM #tmp_container_IB 
WHERE 1=1
--AND haz_flag = 'T'
--AND job_type = 'B'
--AND from_MDI = 'T'
ORDER BY
	#tmp_container_IB.company_id
	, #tmp_container_IB.profit_ctr_id
	, #tmp_container_IB.receipt_id
	, #tmp_container_IB.line_id

---------------------------------------------------
-- Summary information
---------------------------------------------------
---- All (combined)
--SELECT i.company_id
--	, i.profit_ctr_id
--	--, i.receipt_date_month
--	, i.receipt_date_year
--	, i.haz_flag AS haz_flag
--	, CASE job_type WHEN 'E' THEN 'Event' WHEN 'B' THEN 'Base' END AS job_type
--	, CASE from_MDI WHEN 'T' THEN 'MDI' WHEN 'F' THEN 'Direct' END AS from_MDI
--	, CONVERT(money, SUM(i.tons_received)) AS tons_received
--FROM #tmp_container_IB i
--GROUP BY 
--	i.company_id
--	, i.profit_ctr_id
--	--, i.receipt_date_month
--	, i.receipt_date_year
--	, i.haz_flag
--	, CASE job_type WHEN 'E' THEN 'Event' WHEN 'B' THEN 'Base' END 
--	, CASE from_MDI WHEN 'T' THEN 'MDI' WHEN 'F' THEN 'Direct' END
--ORDER BY i.company_id
--	, i.profit_ctr_id
--	, i.receipt_date_year
--	--, i.receipt_date_month
--	, i.haz_flag DESC
--	, job_type
--	, from_MDI

DROP TABLE #tmp_container_IB

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_receipt_log_tons] TO [EQAI]
    AS [dbo];

