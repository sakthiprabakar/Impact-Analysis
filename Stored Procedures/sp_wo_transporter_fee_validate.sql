CREATE PROCEDURE sp_wo_transporter_fee_validate
	@workorder_ID		int
,	@company_ID			int
,	@profit_ctr_ID		int
AS
/************************************************************************************************************************
Waste Transporter Fees Validation - Runs during WorkOrder Submit to verify the applicable transportation fees are included

Load to:		Plt_AI
PB Object(s):	w_workorder, d_workorder_trans_fee_errors

02/04/2016 SK	Created

sp_wo_transporter_fee_validate 9611200, 14, 06

************************************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

if object_id('tempdb..#TransportationFees') IS NOT NULL
	drop table #TransportationFees
	
CREATE TABLE #TransportationFees (
	workorder_ID	int
,	company_ID		int
,	profit_ctr_ID	int
,	manifest		varchar(15)
,	page			int
,	line			int
,	approval_code	varchar(15)
,	resource_class_code		varchar(30)
,	error_msg		varchar(255)
,	exempt_code		varchar(10)
)

DECLARE @checkfor	varchar(3)

SELECT @checkfor = CASE WHEN (TSDF.TSDF_state = 'ME' OR g.generator_state = 'ME') THEN 'ME'
					WHEN (TSDF.TSDF_state = 'MA' OR g.generator_state = 'MA') THEN 'MA'
					WHEN (TSDF.TSDF_state = 'NJ' OR g.generator_state = 'NJ') THEN 'NJ'
					WHEN (g.generator_state = 'RI') THEN 'RI'
					WHEN (TSDF.TSDF_state = 'PA' OR g.generator_state = 'PA') THEN 'PA'
					ELSE '' END				
FROM workorderheader woh
JOIN workorderdetail wod
	ON wod.company_id = woh.company_id
	AND wod.profit_ctr_ID = woh.profit_ctr_ID
	AND wod.workorder_ID = woh.workorder_ID
	AND wod.resource_type = 'D'
	AND wod.bill_rate >= -1
JOIN generator g
	ON g.generator_id = woh.generator_id
JOIN TSDF
	ON TSDF.TSDF_code = wod.tsdf_code
WHERE woh.workorder_ID = @workorder_ID
	AND woh.company_id = @company_ID
	AND woh.profit_ctr_ID = @profit_ctr_ID
	
SELECT @checkfor = 'CAN'
FROM workorderheader woh
JOIN Customer C
	ON C.customer_ID = woh.customer_ID
LEFT OUTER JOIN generator g
	ON g.generator_id = woh.generator_id
WHERE woh.workorder_ID = @workorder_ID
AND woh.company_id = @company_ID
AND woh.profit_ctr_ID = @profit_ctr_ID
AND ( g.generator_country = 'CAN' OR (g.generator_country IS NULL AND C.cust_country = 'CAN'))

	
IF @checkfor = 'ME'	
BEGIN
	-- Maine Hazardous Waste Transporter Fee - ôFEEMETRANSö----------------------------------------------------------------
	INSERT INTO #TransportationFees
	-- 1 eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEEMETRANS'
	--,	'FEEMETRANS not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'T'
	JOIN ProfileQuoteApproval pa
		ON wod.profile_id = pa.profile_id
		AND wod.profile_profit_ctr_id = pa.profit_ctr_id
		AND wod.profile_company_id = pa.company_id
	JOIN Profile p
		ON p.profile_id = pa.profile_id
		AND p.curr_status_code = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_id
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEEMETRANS'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND (TSDF.TSDF_state = 'ME' OR g.generator_state = 'ME')
		AND EXISTS ( SELECT 1 FROM ProfileWasteCode PWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = PWC.waste_code_UID
							AND ((WC.waste_code_origin = 'F' AND WC.haz_flag = 'T') OR
									(WC.haz_flag = 'T' AND WC.waste_code_origin = 'S' AND WC.state = 'ME'))
						WHERE PWC.profile_ID = p.profile_ID
					)
		AND NOT EXISTS ( SELECT 1 FROM ProfileQuoteDetail PQD
							WHERE PQD.company_id = pa.company_id
							AND PQD.profit_ctr_id = pa.profit_ctr_id
							AND PQD.profile_ID = p.profile_ID
							AND PQD.resource_class_code = 'FEEMETRANS'
							AND PQD.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEEMETRANS'
						)
	--1
	UNION
	-- 2 non eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEEMETRANS'
	--,	'FEEMETRANS not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'F'
	JOIN tsdfapproval ta
		ON ta.company_id = wod.company_id
		AND ta.profit_ctr_id = wod.profit_ctr_ID
		AND ta.TSDF_approval_id = wod.TSDF_approval_id
		AND ta.TSDF_approval_status = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_id
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEEMETRANS'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND (TSDF.TSDF_state = 'ME' OR g.generator_state = 'ME')
		AND EXISTS ( SELECT 1 FROM TSDFApprovalWasteCode TWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = TWC.waste_code_UID
							AND ((WC.waste_code_origin = 'F' AND WC.haz_flag = 'T') OR
									(WC.haz_flag = 'T' AND WC.waste_code_origin = 'S' AND WC.state = 'ME'))
						WHERE TWC.company_ID = ta.company_id
						AND TWC.profit_ctr_ID = ta.profit_ctr_id
						AND TWC.TSDF_approval_id = ta.TSDF_approval_id
					)
		AND NOT EXISTS ( SELECT 1 FROM TSDFApprovalPrice tap
							WHERE tap.company_id = ta.company_id
							AND tap.profit_ctr_id = ta.profit_ctr_id
							AND tap.TSDF_approval_id = ta.TSDF_approval_id
							AND tap.resource_class_code = 'FEEMETRANS'
							AND tap.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEEMETRANS'
						)
	--2

	-- Maine Non Hazardous Waste Transporter Category ôAö Waste Report - ôFEEMECATö-------------------------------------
	INSERT INTO #TransportationFees
	-- 1 eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEEMECAT'
	--,	'FEEMECAT not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'T'
	JOIN ProfileQuoteApproval pa
		ON wod.profile_id = pa.profile_id
		AND wod.profile_profit_ctr_id = pa.profit_ctr_id
		AND wod.profile_company_id = pa.company_id
	JOIN Profile p
		ON p.profile_id = pa.profile_id
		AND p.curr_status_code = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_id
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEEMECAT'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND (TSDF.TSDF_state = 'ME' OR g.generator_state = 'ME')
		AND NOT EXISTS ( SELECT 1 FROM ProfileWasteCode PWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = PWC.waste_code_UID
							AND WC.waste_code_origin = 'S' AND WC.state = 'ME'
						WHERE PWC.profile_ID = p.profile_ID
					)
		AND NOT EXISTS ( SELECT 1 FROM ProfileQuoteDetail PQD
							WHERE PQD.company_id = pa.company_id
							AND PQD.profit_ctr_id = pa.profit_ctr_id
							AND PQD.profile_ID = p.profile_ID
							AND PQD.resource_class_code = 'FEEMECAT'
							AND PQD.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEEMECAT'
						)
	--1
	UNION
	-- 2 non eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEEMECAT'
	--,	'FEEMECAT not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'F'
	JOIN tsdfapproval ta
		ON ta.company_id = wod.company_id
		AND ta.profit_ctr_id = wod.profit_ctr_ID
		AND ta.TSDF_approval_id = wod.TSDF_approval_id
		AND ta.TSDF_approval_status = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_id
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEEMECAT'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND (TSDF.TSDF_state = 'ME' OR g.generator_state = 'ME')
		AND NOT EXISTS ( SELECT 1 FROM TSDFApprovalWasteCode TWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = TWC.waste_code_UID
							AND WC.waste_code_origin = 'S' AND WC.state = 'ME'
						WHERE TWC.company_ID = ta.company_id
						AND TWC.profit_ctr_ID = ta.profit_ctr_id
						AND TWC.TSDF_approval_id = ta.TSDF_approval_id
					)
		AND NOT EXISTS ( SELECT 1 FROM TSDFApprovalPrice tap
							WHERE tap.company_id = ta.company_id
							AND tap.profit_ctr_id = ta.profit_ctr_id
							AND tap.TSDF_approval_id = ta.TSDF_approval_id
							AND tap.resource_class_code = 'FEEMECAT'
							AND tap.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEEMECAT'
						)
	--2
END


IF @checkfor = 'MA'	
BEGIN
	-- Massachusetts Hazardous Waste Transporter Fee - ôFEEMAHWö---------------------------------------------------------
	INSERT INTO #TransportationFees
	-- 1 eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEEMAHW'
	--,	'FEEMAHW not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'T'
	JOIN ProfileQuoteApproval pa
		ON wod.profile_id = pa.profile_id
		AND wod.profile_profit_ctr_id = pa.profit_ctr_id
		AND wod.profile_company_id = pa.company_id
	JOIN Profile p
		ON p.profile_id = pa.profile_id
		AND p.curr_status_code = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEEMAHW'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND (TSDF.TSDF_state = 'MA' OR g.generator_state = 'MA')
		AND EXISTS ( SELECT 1 FROM ProfileWasteCode PWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = PWC.waste_code_UID
							AND ((WC.waste_code_origin = 'F' AND WC.haz_flag = 'T') OR
									(WC.haz_flag = 'T' AND WC.waste_code_origin = 'S' AND WC.state = 'MA'))
						WHERE PWC.profile_ID = p.profile_ID
					)
		AND NOT EXISTS ( SELECT 1 FROM ProfileQuoteDetail PQD
							WHERE PQD.company_id = pa.company_id
							AND PQD.profit_ctr_id = pa.profit_ctr_id
							AND PQD.profile_ID = p.profile_ID
							AND PQD.resource_class_code = 'FEEMAHW'
							AND PQD.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEEMAHW'
						)
	--1
	UNION
	-- 2 non eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEEMAHW'
	--,	'FEEMAHW not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'F'
	JOIN tsdfapproval ta
		ON ta.company_id = wod.company_id
		AND ta.profit_ctr_id = wod.profit_ctr_ID
		AND ta.TSDF_approval_id = wod.TSDF_approval_id
		AND ta.TSDF_approval_status = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEEMAHW'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND (TSDF.TSDF_state = 'MA' OR g.generator_state = 'MA')
		AND EXISTS ( SELECT 1 FROM TSDFApprovalWasteCode TWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = TWC.waste_code_UID
							AND ((WC.waste_code_origin = 'F' AND WC.haz_flag = 'T') OR
									(WC.haz_flag = 'T' AND WC.waste_code_origin = 'S' AND WC.state = 'MA'))
						WHERE TWC.company_ID = ta.company_id
						AND TWC.profit_ctr_ID = ta.profit_ctr_id
						AND TWC.TSDF_approval_id = ta.TSDF_approval_id
					)
		AND NOT EXISTS ( SELECT 1 FROM TSDFApprovalPrice tap
							WHERE tap.company_id = ta.company_id
							AND tap.profit_ctr_id = ta.profit_ctr_id
							AND tap.TSDF_approval_id = ta.TSDF_approval_id
							AND tap.resource_class_code = 'FEEMAHW'
							AND tap.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEEMAHW'
						)
	--2
END


IF @checkfor = 'NJ'	
BEGIN
	-- New Jersey Hazardous Waste Transporter Fee - ôFEENJHWö------------------------------------------------------------
	INSERT INTO #TransportationFees
	-- 1 eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEENJHW'
	--,	'FEENJHW not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'T'
	JOIN ProfileQuoteApproval pa
		ON wod.profile_id = pa.profile_id
		AND wod.profile_profit_ctr_id = pa.profit_ctr_id
		AND wod.profile_company_id = pa.company_id
	JOIN Profile p
		ON p.profile_id = pa.profile_id
		AND p.curr_status_code = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEENJHW'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND (TSDF.TSDF_state = 'NJ' OR g.generator_state = 'NJ')
		AND EXISTS ( SELECT 1 FROM ProfileWasteCode PWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = PWC.waste_code_UID
							AND WC.waste_code_origin = 'F' AND WC.haz_flag = 'T'
						WHERE PWC.profile_ID = p.profile_ID
					)
		AND NOT EXISTS ( SELECT 1 FROM ProfileQuoteDetail PQD
							WHERE PQD.company_id = pa.company_id
							AND PQD.profit_ctr_id = pa.profit_ctr_id
							AND PQD.profile_ID = p.profile_ID
							AND PQD.resource_class_code = 'FEENJHW'
							AND PQD.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEENJHW'
						)
	--1
	UNION
	-- 2 non eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEENJHW'
	--,	'FEENJHW not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'F'
	JOIN tsdfapproval ta
		ON ta.company_id = wod.company_id
		AND ta.profit_ctr_id = wod.profit_ctr_ID
		AND ta.TSDF_approval_id = wod.TSDF_approval_id
		AND ta.TSDF_approval_status = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEENJHW'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND (TSDF.TSDF_state = 'NJ' OR g.generator_state = 'NJ')
		AND EXISTS ( SELECT 1 FROM TSDFApprovalWasteCode TWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = TWC.waste_code_UID
							AND WC.waste_code_origin = 'F' AND WC.haz_flag = 'T'
						WHERE TWC.company_ID = ta.company_id
						AND TWC.profit_ctr_ID = ta.profit_ctr_id
						AND TWC.TSDF_approval_id = ta.TSDF_approval_id
					)
		AND NOT EXISTS ( SELECT 1 FROM TSDFApprovalPrice tap
							WHERE tap.company_id = ta.company_id
							AND tap.profit_ctr_id = ta.profit_ctr_id
							AND tap.TSDF_approval_id = ta.TSDF_approval_id
							AND tap.resource_class_code = 'FEENJHW'
							AND tap.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEENJHW'
						)
	--2

	-- New Jersey Recycling Tax - ôFEENJRECö-------------------------------------------------------------------------------
	INSERT INTO #TransportationFees
	-- 1 eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEENJREC'
	--,	'FEENJREC not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'T'
	JOIN ProfileQuoteApproval pa
		ON wod.profile_id = pa.profile_id
		AND wod.profile_profit_ctr_id = pa.profit_ctr_id
		AND wod.profile_company_id = pa.company_id
	JOIN Profile p
		ON p.profile_id = pa.profile_id
		AND p.curr_status_code = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEENJREC'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND (TSDF.TSDF_state <> 'NJ' AND g.generator_state = 'NJ')
		AND NOT EXISTS ( SELECT 1 FROM WorkorderWasteCode WWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = WWC.waste_code_UID
							AND WC.display_name <> 'NONE'
						WHERE WWC.workorder_ID = WOD.workorder_ID
						AND WWC.company_ID = WOD.company_ID
						AND WWC.profit_ctr_ID = WOD.profit_ctr_ID
						AND WWC.workorder_sequence_ID = WOD.sequence_ID
					
					)
		AND NOT EXISTS ( SELECT 1 FROM ProfileQuoteDetail PQD
							WHERE PQD.company_id = pa.company_id
							AND PQD.profit_ctr_id = pa.profit_ctr_id
							AND PQD.profile_ID = p.profile_ID
							AND PQD.resource_class_code = 'FEENJREC'
							AND PQD.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEENJREC'
						)
	--1
	UNION
	-- 2 non eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEENJREC'
	--,	'FEENJREC not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'F'
	JOIN tsdfapproval ta
		ON ta.company_id = wod.company_id
		AND ta.profit_ctr_id = wod.profit_ctr_ID
		AND ta.TSDF_approval_id = wod.TSDF_approval_id
		AND ta.TSDF_approval_status = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEENJREC'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND (TSDF.TSDF_state <> 'NJ' AND g.generator_state = 'NJ')
		AND NOT EXISTS ( SELECT 1 FROM WorkorderWasteCode WWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = WWC.waste_code_UID
							AND WC.display_name <> 'NONE'
						WHERE WWC.workorder_ID = WOD.workorder_ID
						AND WWC.company_ID = WOD.company_ID
						AND WWC.profit_ctr_ID = WOD.profit_ctr_ID
						AND WWC.workorder_sequence_ID = WOD.sequence_ID
					
					)
		AND NOT EXISTS ( SELECT 1 FROM TSDFApprovalPrice tap
							WHERE tap.company_id = ta.company_id
							AND tap.profit_ctr_id = ta.profit_ctr_id
							AND tap.TSDF_approval_id = ta.TSDF_approval_id
							AND tap.resource_class_code = 'FEENJREC'
							AND tap.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEENJREC'
						)
	--2
END


IF @checkfor = 'RI'	
BEGIN
	-- Rhode Island Hazardous Waste Transporter Fee - ôFEERIHWö------------------------------------------------------------
	INSERT INTO #TransportationFees
	-- 1 eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEERIHW'
	--,	'FEERIHW not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	CASE WHEN EXISTS (SELECT 1 FROM WorkorderWasteCode WWC
							JOIN WasteCode WC
								ON WC.waste_code_UID = WWC.waste_code_UID
								AND WC.waste_code_origin = 'S' AND WC.state = 'RI'
								AND WC.display_name = 'R015'
							WHERE WWC.workorder_ID = WOD.workorder_ID
							AND WWC.company_ID = WOD.company_ID
							AND WWC.profit_ctr_ID = WOD.profit_ctr_ID
							AND WWC.workorder_sequence_ID = WOD.sequence_ID )
			THEN 5
			WHEN EXISTS (SELECT 1 FROM WorkorderWasteCode WWC
							JOIN WasteCode WC
								ON WC.waste_code_UID = WWC.waste_code_UID
								AND WC.waste_code_origin = 'S' AND WC.state = 'RI'
								AND WC.display_name = 'R016'
							WHERE WWC.workorder_ID = WOD.workorder_ID
							AND WWC.company_ID = WOD.company_ID
							AND WWC.profit_ctr_ID = WOD.profit_ctr_ID
							AND WWC.workorder_sequence_ID = WOD.sequence_ID )
			THEN 6
			ELSE NULL END
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'T'
	JOIN ProfileQuoteApproval pa
		ON wod.profile_id = pa.profile_id
		AND wod.profile_profit_ctr_id = pa.profit_ctr_id
		AND wod.profile_company_id = pa.company_id
	JOIN Profile p
		ON p.profile_id = pa.profile_id
		AND p.curr_status_code = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEERIHW'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND g.generator_state = 'RI'
		AND EXISTS ( SELECT 1 FROM WorkorderWasteCode WWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = WWC.waste_code_UID
							AND WC.waste_code_origin = 'S' AND WC.state = 'RI'
						WHERE WWC.workorder_ID = WOD.workorder_ID
						AND WWC.company_ID = WOD.company_ID
						AND WWC.profit_ctr_ID = WOD.profit_ctr_ID
						AND WWC.workorder_sequence_ID = WOD.sequence_ID
					)
		AND NOT EXISTS ( SELECT 1 FROM ProfileQuoteDetail PQD
							WHERE PQD.company_id = pa.company_id
							AND PQD.profit_ctr_id = pa.profit_ctr_id
							AND PQD.profile_ID = p.profile_ID
							AND PQD.resource_class_code = 'FEERIHW'
							AND PQD.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEERIHW'
						)
	--1
	UNION
	-- 2 non eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEERIHW'
	--,	'FEERIHW not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	CASE WHEN EXISTS (SELECT 1 FROM WorkorderWasteCode WWC
							JOIN WasteCode WC
								ON WC.waste_code_UID = WWC.waste_code_UID
								AND WC.waste_code_origin = 'S' AND WC.state = 'RI'
								AND WC.display_name = 'R015'
							WHERE WWC.workorder_ID = WOD.workorder_ID
							AND WWC.company_ID = WOD.company_ID
							AND WWC.profit_ctr_ID = WOD.profit_ctr_ID
							AND WWC.workorder_sequence_ID = WOD.sequence_ID )
			THEN 5
			WHEN EXISTS (SELECT 1 FROM WorkorderWasteCode WWC
							JOIN WasteCode WC
								ON WC.waste_code_UID = WWC.waste_code_UID
								AND WC.waste_code_origin = 'S' AND WC.state = 'RI'
								AND WC.display_name = 'R016'
							WHERE WWC.workorder_ID = WOD.workorder_ID
							AND WWC.company_ID = WOD.company_ID
							AND WWC.profit_ctr_ID = WOD.profit_ctr_ID
							AND WWC.workorder_sequence_ID = WOD.sequence_ID )
			THEN 6
			ELSE NULL END
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'F'
	JOIN tsdfapproval ta
		ON ta.company_id = wod.company_id
		AND ta.profit_ctr_id = wod.profit_ctr_ID
		AND ta.TSDF_approval_id = wod.TSDF_approval_id
		AND ta.TSDF_approval_status = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEERIHW'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND g.generator_state = 'RI'
		AND EXISTS ( SELECT 1 FROM WorkorderWasteCode WWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = WWC.waste_code_UID
							AND WC.waste_code_origin = 'S' AND WC.state = 'RI'
						WHERE WWC.workorder_ID = WOD.workorder_ID
						AND WWC.company_ID = WOD.company_ID
						AND WWC.profit_ctr_ID = WOD.profit_ctr_ID
						AND WWC.workorder_sequence_ID = WOD.sequence_ID
					)
		AND NOT EXISTS ( SELECT 1 FROM TSDFApprovalPrice tap
							WHERE tap.company_id = ta.company_id
							AND tap.profit_ctr_id = ta.profit_ctr_id
							AND tap.TSDF_approval_id = ta.TSDF_approval_id
							AND tap.resource_class_code = 'FEERIHW'
							AND tap.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEERIHW'
						)
	--2
END


IF @checkfor = 'PA'	
BEGIN
	-- Pennsylvania Hazardous Waste Transporter Fee - ôFEEPARECö------------------------------------------------------------
	INSERT INTO #TransportationFees
	-- 1 eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEEPAREC'
	,	CASE WHEN p.treatment_method IS NULL THEN 'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied. Please check the Treatment Method field on approval'
			 WHEN p.treatment_method = 'Recycle' THEN 'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
		ELSE NULL END
	,	NULL
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'T'
	JOIN ProfileQuoteApproval pa
		ON wod.profile_id = pa.profile_id
		AND wod.profile_profit_ctr_id = pa.profit_ctr_id
		AND wod.profile_company_id = pa.company_id
		--AND (pa.treatment_process_ID IS NULL OR pa.treatment_process_ID IN (SELECT treatment_process_ID FROM TreatmentProcess WHERE code LIKE 'Recycle%'))
	JOIN Profile p
		ON p.profile_id = pa.profile_id
		AND p.curr_status_code = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEEPAREC'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND (TSDF.TSDF_state = 'PA' OR g.generator_state = 'PA')
		AND (p.treatment_method IS NULL OR p.treatment_method = 'Recycle')
		AND EXISTS ( SELECT 1 FROM WorkorderWasteCode WWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = WWC.waste_code_UID
							AND WC.waste_code_origin = 'F' AND WC.haz_flag = 'T'
						WHERE WWC.workorder_ID = WOD.workorder_ID
						AND WWC.company_ID = WOD.company_ID
						AND WWC.profit_ctr_ID = WOD.profit_ctr_ID
						AND WWC.workorder_sequence_ID = WOD.sequence_ID
					)
		AND NOT EXISTS ( SELECT 1 FROM ProfileQuoteDetail PQD
							WHERE PQD.company_id = pa.company_id
							AND PQD.profit_ctr_id = pa.profit_ctr_id
							AND PQD.profile_ID = p.profile_ID
							AND PQD.resource_class_code = 'FEEPAREC'
							AND PQD.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEEPAREC'
						)
	--1
	UNION
	-- 2 non eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEEPAREC'
	--,	'FEEPAREC not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'F'
	JOIN tsdfapproval ta
		ON ta.company_id = wod.company_id
		AND ta.profit_ctr_id = wod.profit_ctr_ID
		AND ta.TSDF_approval_id = wod.TSDF_approval_id
		AND ta.TSDF_approval_status = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEEPAREC'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND (TSDF.TSDF_state = 'PA' OR g.generator_state = 'PA')
		AND EXISTS ( SELECT 1 FROM WorkorderWasteCode WWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = WWC.waste_code_UID
							AND WC.waste_code_origin = 'F' AND WC.haz_flag = 'T'
						WHERE WWC.workorder_ID = WOD.workorder_ID
						AND WWC.company_ID = WOD.company_ID
						AND WWC.profit_ctr_ID = WOD.profit_ctr_ID
						AND WWC.workorder_sequence_ID = WOD.sequence_ID
					)
		AND NOT EXISTS ( SELECT 1 FROM TSDFApprovalPrice tap
							WHERE tap.company_id = ta.company_id
							AND tap.profit_ctr_id = ta.profit_ctr_id
							AND tap.TSDF_approval_id = ta.TSDF_approval_id
							AND tap.resource_class_code = 'FEEPAREC'
							AND tap.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEEPAREC'
						)
	--2

	-- Pennsylvania Hazardous Waste Transporter Fee - ôFEEPATRTö------------------------------------------------------------
	INSERT INTO #TransportationFees
	-- 1 eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEEPATRT'
	,	CASE WHEN p.treatment_method IS NULL THEN 'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied. Please check the Treatment Method field on approval'
			 WHEN p.treatment_method = 'Treat/Disp' THEN 'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
		ELSE NULL END
	,	NULL
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'T'
	JOIN ProfileQuoteApproval pa
		ON wod.profile_id = pa.profile_id
		AND wod.profile_profit_ctr_id = pa.profit_ctr_id
		AND wod.profile_company_id = pa.company_id
		--AND (pa.treatment_process_ID IS NULL OR pa.treatment_process_ID IN (SELECT treatment_process_ID FROM TreatmentProcess WHERE code LIKE 'Recycle%'))
	JOIN Profile p
		ON p.profile_id = pa.profile_id
		AND p.curr_status_code = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEEPATRT'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND (TSDF.TSDF_state = 'PA' OR g.generator_state = 'PA')
		AND (p.treatment_method IS NULL OR p.treatment_method = 'Treat/Disp')
		AND EXISTS ( SELECT 1 FROM WorkorderWasteCode WWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = WWC.waste_code_UID
							AND WC.waste_code_origin = 'F' AND WC.haz_flag = 'T'
						WHERE WWC.workorder_ID = WOD.workorder_ID
						AND WWC.company_ID = WOD.company_ID
						AND WWC.profit_ctr_ID = WOD.profit_ctr_ID
						AND WWC.workorder_sequence_ID = WOD.sequence_ID
					)
		AND NOT EXISTS ( SELECT 1 FROM ProfileQuoteDetail PQD
							WHERE PQD.company_id = pa.company_id
							AND PQD.profit_ctr_id = pa.profit_ctr_id
							AND PQD.profile_ID = p.profile_ID
							AND PQD.resource_class_code = 'FEEPATRT'
							AND PQD.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEEPATRT'
						)
	--1
	UNION
	-- 2 non eq tsdf
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	wod.manifest
	,	wod.manifest_page_num
	,	wod.manifest_line
	,	wod.TSDF_approval_code
	,	'FEEPATRT'
	--,	'FEEPATRT not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN workorderdetail wod
		ON wod.company_id = woh.company_id
		AND wod.profit_ctr_ID = woh.profit_ctr_ID
		AND wod.workorder_ID = woh.workorder_ID
		AND wod.resource_type = 'D'
		AND wod.bill_rate >= -1
	JOIN WorkOrderTransporter wot1
		ON wot1.company_id = woh.company_id
		AND wot1.profit_ctr_id = woh.profit_ctr_ID
		AND wot1.workorder_id = woh.workorder_ID
		AND wot1.manifest = wod.manifest
		AND wot1.transporter_sequence_id = 1
	JOIN transporter t
		ON t.transporter_code = wot1.transporter_code
		AND t.eq_flag = 'T'
	JOIN TSDF
		ON TSDF.TSDF_code = wod.tsdf_code
		AND ISNULL(TSDF.eq_flag,'F') = 'F'
	JOIN tsdfapproval ta
		ON ta.company_id = wod.company_id
		AND ta.profit_ctr_id = wod.profit_ctr_ID
		AND ta.TSDF_approval_id = wod.TSDF_approval_id
		AND ta.TSDF_approval_status = 'A'
	JOIN generator g
		ON g.generator_id = woh.generator_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEEPATRT'
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND (TSDF.TSDF_state = 'PA' OR g.generator_state = 'PA')
		AND EXISTS ( SELECT 1 FROM WorkorderWasteCode WWC
						JOIN WasteCode WC
							ON WC.waste_code_UID = WWC.waste_code_UID
							AND WC.waste_code_origin = 'F' AND WC.haz_flag = 'T'
						WHERE WWC.workorder_ID = WOD.workorder_ID
						AND WWC.company_ID = WOD.company_ID
						AND WWC.profit_ctr_ID = WOD.profit_ctr_ID
						AND WWC.workorder_sequence_ID = WOD.sequence_ID
					)
		AND NOT EXISTS ( SELECT 1 FROM TSDFApprovalPrice tap
							WHERE tap.company_id = ta.company_id
							AND tap.profit_ctr_id = ta.profit_ctr_id
							AND tap.TSDF_approval_id = ta.TSDF_approval_id
							AND tap.resource_class_code = 'FEEPATRT'
							AND tap.bill_method = 'B'
						)
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEEPATRT'
						)
	--2
END


IF @checkfor = 'CAN'	
BEGIN
	-- FEECANGST Billed to Customers in CANADA------------------------------------------------------------------------------
	INSERT INTO #TransportationFees
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	''
	,	NULL
	,	NULL
	,	''
	,	'FEECANGST'
	--,	'FEECANGST not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN Customer C
		ON C.customer_ID = woh.customer_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEECANGST'
	LEFT OUTER JOIN generator g
		ON g.generator_id = woh.generator_id
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEECANGST'
						)
		AND (
				(g.generator_country = 'CAN' AND g.generator_state IN ('AB', 'BC', 'MB', 'NS', 'NU', 'QB', 'SK', 'YT' ))
			OR	(g.generator_country IS NULL AND C.cust_country = 'CAN' AND C.cust_state IN ('AB', 'BC', 'MB', 'NS', 'NU', 'QB', 'SK', 'YT' ))
			)
		

	-- FEECANHST Billed to Customers in CANADA------------------------------------------------------------------------------
	INSERT INTO #TransportationFees
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	''
	,	NULL
	,	NULL
	,	''
	,	'FEECANHST'
	--,	'FEECANHST not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN Customer C
		ON C.customer_ID = woh.customer_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEECANHST'
	LEFT OUTER JOIN generator g
		ON g.generator_id = woh.generator_id
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEECANHST'
						)
		AND (
				(g.generator_country = 'CAN' AND g.generator_state IN ('NB', 'NL', 'NT', 'ON', 'PE' ))
			OR	(g.generator_country IS NULL AND C.cust_country = 'CAN' AND C.cust_state IN ('NB', 'NL', 'NT', 'ON', 'PE' ))
			)
		
		
	-- FEECANPST Billed to Customers in CANADA------------------------------------------------------------------------------
	INSERT INTO #TransportationFees
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	''
	,	NULL
	,	NULL
	,	''
	,	'FEECANPST'
	--,	'FEECANPST not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN Customer C
		ON C.customer_ID = woh.customer_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEECANPST'
	LEFT OUTER JOIN generator g
		ON g.generator_id = woh.generator_id
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEECANPST'
						)
		AND (						
				(g.generator_country = 'CAN' AND g.generator_state IN ('BC', 'MB', 'SK'))
			OR	(g.generator_country IS NULL AND C.cust_country = 'CAN' AND C.cust_state IN ('BC', 'MB', 'SK'))
			)


	-- FEECANQST Billed to Customers in CANADA------------------------------------------------------------------------------
	INSERT INTO #TransportationFees
	SELECT DISTINCT
		woh.workorder_id
	,	woh.company_id
	,	woh.profit_ctr_id
	,	''
	,	NULL
	,	NULL
	,	''
	,	'FEECANQST'
	--,	'FEECANQST not applied'
	,	'This work order meets the validation to require the '+ Coalesce(RCH.description, '') + ' (Resource class: ' + RCH.resource_class_code + ') and it is not applied.'
	,	NULL
	FROM workorderheader woh
	JOIN Customer C
		ON C.customer_ID = woh.customer_ID
	JOIN ResourceClassHeader RCH
		ON RCH.resource_class_code = 'FEECANQST'
	LEFT OUTER JOIN generator g
		ON g.generator_id = woh.generator_id
	WHERE woh.workorder_ID = @workorder_ID
		AND woh.company_id = @company_ID
		AND woh.profit_ctr_ID = @profit_ctr_ID
		AND NOT EXISTS ( SELECT 1 FROM WorkOrderdetail wod
							WHERE wod.company_id = woh.company_id
							AND wod.profit_ctr_ID = woh.profit_ctr_ID
							AND wod.workorder_ID = woh.workorder_ID
							AND wod.resource_type = 'O'
							AND wod.resource_class_code = 'FEECANQST'
						)
		AND (
				(g.generator_country = 'CAN' AND g.generator_state = 'QB')
			OR	(g.generator_country IS NULL AND C.cust_country = 'CAN' AND C.cust_state = 'QB')
			)
	
END


-- Fetch Final results-------------------------------------------------------------------------------------------------------------------
SELECT workorder_id
,	company_id
,	profit_ctr_id
,	manifest
,	page
,	line
,	approval_code
,	resource_class_code
,	error_msg
,	exempt_code
FROM #TransportationFees

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wo_transporter_fee_validate] TO [EQAI]
    AS [dbo];

