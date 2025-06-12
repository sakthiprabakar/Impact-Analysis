
CREATE PROCEDURE sp_rpt_generic_waste_extract (
	@start_date				datetime,
	@end_date				datetime,
	@customer_id			int,
	@include_eq_fields		int = 0
)
AS
/* ************************************************************************************************
Procedure    : sp_rpt_generic_waste_extract
Database     : plt_ai
Description  : Creates a waste extract that runs on EQIP. Currently used for Meijer or Rite-Aid
	
04/03/2013 SK	Created
05/05/2015 AM   GEM:32522 - Added generator join to accommodate region_code,division_name and business_unit fields
				-
sp_rpt_generic_waste_extract '02/01/2014 00:00', '03/18/2014 23:59', 14231, 1

select * from EQ_Temp.dbo.Generic_Waste_Extract
select * from EQ_Extract.dbo.Generic_Waste_Extract

*********************************************************** ***********************************************/

SET NOCOUNT ON

-- Define specific extract values:
DECLARE
	@extract_datetime		datetime,
	@usr					nvarchar(256),
	@days_before_delete		smallint
	
SELECT
	@extract_datetime		= GETDATE(),
	@usr 					= UPPER(SUSER_SNAME()),
	@days_before_delete		= 90

DECLARE
	@int_start_date				datetime,
	@int_end_date				datetime,
	@int_customer_id			int,
	@int_include_eq_fields		int

SELECT
	@int_start_date				= @start_date				,
	@int_end_date				= @end_date				,
	@int_customer_id			= @customer_id			,
	@int_include_eq_fields		= @include_eq_fields		

IF RIGHT(@usr, 3) = '(2)'
	SELECT @usr = LEFT(@usr,(LEN(@usr)-3))

-- EQ_Temp table housekeeping
-- Deletes temp data more than 2 days old, or by this user (past runs)
DELETE FROM EQ_TEMP.dbo.Generic_Waste_Extract where date_added < dateadd(dd, -2, getdate())
DELETE FROM EQ_TEMP.dbo.Generic_Waste_Extract where added_by = @usr

-----------------------------------------------------------
-- Always keep at least 5 copies
-----------------------------------------------------------
SELECT DISTINCT TOP 5 added_by, date_added 
INTO #extracts_to_keep
FROM EQ_Extract..Generic_Waste_Extract 
ORDER BY date_added DESC

--SELECT * FROM #extracts_to_keep

-----------------------------------------------------------
-- Delete old extracts, but leave at least the last 5
-----------------------------------------------------------
DELETE FROM EQ_Extract..Generic_Waste_Extract 
WHERE date_added < @days_before_delete
AND date_added NOT IN (
	SELECT date_added FROM #extracts_to_keep
	)

------------------------------------------------------------------------------------------
-- Select Data
------------------------------------------------------------------------------------------
-- WorkOrders using TSDF Approvals
INSERT EQ_Temp.dbo.Generic_Waste_Extract (
		manifest
	,	pickup_date
	,	schedule_date
	,	waste_desc
	,	pounds
	,	fed_waste_codes
	,	state_waste_codes
	,	management_code
	,	form_code
	,	source_code
	,	cost
	,	receiving_facility
	,	receiving_facility_epa_id
	,	transporter_1_name
	,	transporter_1_epa_ID
	,	transporter_2_name
	,	transporter_2_epa_ID
	,	company_id
	,	profit_ctr_id
	,	receipt_id
	,	line_id
	,	trans_source
	,	added_by
	,	date_added
	,	region_code
	,	division_name
	,	business_unit
)
SELECT
	IsNull(WOD.manifest, '') AS manifest
,	Coalesce(WOT1.transporter_sign_date, WOS.date_act_depart, WOH.start_date) AS pickup_date
,	WOS.date_act_arrive AS schedule_date
,	IsNull(TA.waste_desc, '')AS waste_desc
,	convert(int, Round(ISNULL((SELECT WODU.quantity FROM WorkOrderDetailUnit WODU (nolock)
											WHERE WODU.workorder_id = WOD.workorder_id
											AND WODU.company_id = WOD.company_id
											AND WODU.profit_ctr_id = WOD.profit_ctr_id
											AND WODU.sequence_id = WOD.sequence_id
											AND WODU.bill_unit_code = 'LBS'
											), 0), 0)) AS pounds
,	ISNULL(TA.waste_code + ', ' + dbo.fn_approval_sec_waste_code_list(TA.tsdf_approval_id, 'T'), '') AS fed_waste_codes
,	ISNULL(dbo.fn_sec_waste_code_list_state(TA.tsdf_approval_id, 'T'), '') AS state_waste_codes
,	ISNULL(TA.management_code, '') AS management_code
,	ISNULL(TA.epa_form_code, '') AS form_code
,	ISNULL(TA.EPA_source_code, '') AS source_code
,	SUM(BD.extended_amt) AS cost
,	CONVERT(varchar(50), ISNULL(TSDF.TSDF_name, '')) AS receiving_facility
,	CONVERT(varchar(50), ISNULL(TSDF.TSDF_epa_id, '')) AS receiving_facility_epa_id
,	IsNull((SELECT T.transporter_name FROM Transporter T WHERE T.transporter_code = WOT1.transporter_code), '') AS transporter_1_name
,	IsNull((SELECT T.transporter_EPA_ID FROM Transporter T WHERE T.transporter_code = WOT1.transporter_code), '') AS transporter_1_epa_ID
,	IsNull((SELECT T.transporter_name FROM Transporter T WHERE T.transporter_code = WOT2.transporter_code), '') AS transporter_2_name
,	IsNull((SELECT T.transporter_EPA_ID FROM Transporter T WHERE T.transporter_code = WOT2.transporter_code), '') AS transporter_2_epa_ID
-- Extra EQ Fields:
,	B.company_id
,	B.profit_ctr_id
,	B.receipt_id
,	B.line_id
,	B.trans_source
,	@usr
,	@extract_datetime
,	g.generator_region_code as region_code
,	g.generator_division as division_name
,	g.generator_business_unit as business_unit
FROM Billing B (nolock) 
INNER JOIN BillingDetail BD
	ON B.billing_uid = BD.billing_uid
INNER JOIN Generator g  (nolock)
	ON b.generator_id = g.generator_id
INNER JOIN WorkOrderHeader WOH  (nolock) 
	ON B.receipt_id = WOH.workorder_id 
	AND B.company_id = WOH.company_id 
	AND B.profit_ctr_id = WOH.profit_ctr_id
	AND B.trans_source = 'W'
INNER JOIN WorkOrderDetail wod  (nolock) 
	ON B.receipt_id = wod.workorder_id 
	AND B.company_id = wod.company_id 
	AND B.profit_ctr_id = wod.profit_ctr_id 
	AND B.workorder_sequence_id = wod.sequence_id
	AND B.workorder_resource_type = wod.resource_type
	AND B.trans_source = 'W'
	AND WOD.bill_rate > -2
	AND WOD.resource_type = 'D'
INNER JOIN TSDFApproval TA  (nolock) 
	ON B.tsdf_approval_id = TA.tsdf_approval_id
	AND B.tsdf_approval_id IS NOT NULL
INNER JOIN TSDF (nolock) 
	ON TSDF.TSDF_code = WOD.TSDF_code
	AND ISNULL(TSDF.eq_flag, 'F') = 'F'
LEFT OUTER JOIN WorkOrderTransporter WOT1 (nolock) 
	ON WOT1.workorder_id = WOH.workorder_id  
	AND WOT1.company_id = WOH.company_id 
	AND WOT1.profit_ctr_id = WOH.profit_ctr_id
	AND WOT1.transporter_sequence_id = 1	
LEFT OUTER JOIN WorkOrderTransporter WOT2 (nolock) 
	ON WOT2.workorder_id = WOH.workorder_id  
	AND WOT2.company_id = WOH.company_id 
	AND WOT2.profit_ctr_id = WOH.profit_ctr_id
	AND WOT2.transporter_sequence_id = 2
LEFT OUTER JOIN WorkorderStop WOS (nolock) 
	ON WOS.workorder_id = WOH.workorder_ID
	AND WOS.company_id = WOH.company_id
	AND WOS.profit_ctr_id = WOH.profit_ctr_ID
	AND WOS.stop_sequence_id = 1
WHERE
	B.customer_id = @int_customer_id
	AND B.invoice_date BETWEEN @int_start_date AND @int_end_date
	AND B.status_code = 'I'
GROUP BY
	WOD.manifest,
	B.receipt_id,
	B.line_id,
	B.company_id,
	B.profit_ctr_id,
	B.workorder_sequence_id,
	B.trans_source,
	WOT1.transporter_sign_date,
	WOT1.transporter_code,
	WOT2.transporter_code,
	WOS.date_act_depart,
	WOH.start_date,
	WOD.workorder_ID,
	WOD.company_id,
	WOD.profit_ctr_ID,
	WOD.sequence_ID,
	WOD.resource_type,
	WOD.bill_rate,
	WOD.bill_unit_code,
	WOS.date_act_arrive,
	TA.waste_desc,
	TA.waste_code,
	TA.TSDF_approval_id,
	TA.management_code,
	TA.EPA_form_code,
	TA.EPA_source_code,
	TSDF.TSDF_name,
	TSDF.TSDF_EPA_ID,
	G.generator_region_code,
	G.generator_division,
	G.generator_business_unit 
-- Receipts
INSERT EQ_Temp.dbo.Generic_Waste_Extract (
		manifest
	,	pickup_date
	,	schedule_date
	,	waste_desc
	,	pounds
	,	fed_waste_codes
	,	state_waste_codes
	,	management_code
	,	form_code
	,	source_code
	,	cost
	,	receiving_facility
	,	receiving_facility_epa_id
	,	transporter_1_name
	,	transporter_1_epa_ID
	,	transporter_2_name
	,	transporter_2_epa_ID
	,	company_id
	,	profit_ctr_id
	,	receipt_id
	,	line_id
	,	trans_source
	,	added_by
	,	date_added
	,	region_code
	,	division_name
	,	business_unit
)
SELECT	
	IsNull(R.manifest, '') AS manifest
,	Coalesce(RT1.transporter_sign_date, R.receipt_date) AS pickup_date
,	CASE WHEN EXISTS ( 
					SELECT receipt_id 
					FROM BillingLinkLookup BLL  (nolock) 
					WHERE BLL.company_id = B.company_id
					AND BLL.profit_ctr_id = B.profit_ctr_id
					AND BLL.receipt_id = B.receipt_id ) 
		 THEN (	SELECT bllwos.date_act_arrive 
				FROM BillingLinkLookup bll (nolock) 
					INNER JOIN WorkOrderStop BLLWOS (nolock) 
						ON BLLWOS.company_id = BLL.source_company_id
						AND BLLWOS.profit_ctr_id = BLL.source_profit_ctr_id
						AND BLLWOS.workorder_id = BLL.source_id
						AND BLLWOS.stop_sequence_id = 1
				WHERE BLL.company_id = b.company_id
					AND BLL.profit_ctr_id = b.profit_ctr_id
					AND BLL.receipt_id = b.receipt_id
			)
		 ELSE NULL 
	END AS schedule_date
,	Coalesce(Profile.approval_desc, '') AS waste_desc
,	IsNull(dbo.fn_receipt_weight_line(B.receipt_id, B.line_id, B.profit_ctr_id, B.company_id), 0) AS pounds
,	ISNULL(dbo.fn_receipt_waste_code_list(B.company_id, B.profit_ctr_id, B.receipt_id, B.line_id), '') AS fed_waste_codes
,	ISNULL(dbo.fn_receipt_waste_code_list_state(B.company_id, B.profit_ctr_id, B.receipt_id, B.line_id), '') AS state_waste_codes
,	Coalesce(R.manifest_management_code, TR.management_code, '') AS management_code
,	Coalesce(Profile.epa_form_code, '')AS form_code
,	Coalesce(Profile.epa_source_code, '')AS source_code
,	SUM(BD.extended_amt) AS cost
,	CONVERT(varchar(50), ISNULL(PC.profit_ctr_name, '')) AS receiving_facility
,	CONVERT(varchar(50), ISNULL(PC.epa_id, ''))AS receiving_facility_epa_id
,	IsNull(RT1.transporter_name, '')AS transporter_1_name
,	IsNull(RT1.transporter_EPA_ID, '')AS transporter_1_epa_ID
,	IsNull(RT2.transporter_name, '')AS transporter_2_name
,	IsNull(RT2.transporter_EPA_ID, '')AS transporter_2_epa_ID
-- Extra EQ Fields:
,	B.company_id
,	B.profit_ctr_id
,	B.receipt_id
,	B.line_id
,	B.trans_source
,	@usr
,	@extract_datetime
,	g.generator_region_code as region_code
,	g.generator_division as division_name
,	g.generator_business_unit as business_unit
FROM Billing B (nolock) 
INNER JOIN BillingDetail BD
	ON B.billing_uid = BD.billing_uid
INNER JOIN Generator g  (nolock)
	ON b.generator_id = g.generator_id
INNER JOIN Receipt R  (nolock) 
	ON B.receipt_id = R.receipt_id 
	AND B.company_id = R.company_id 
	AND B.profit_ctr_id = R.profit_ctr_id 
	AND B.line_id = R.line_id
	AND B.trans_source = 'R'
	--AND R.trans_mode = 'I'
LEFT OUTER JOIN ReceiptTransporter RT1 (nolock) 
	ON RT1.receipt_id = R.receipt_id 
	AND RT1.company_id = R.company_id 
	AND RT1.profit_ctr_id = R.profit_ctr_id
	AND RT1.transporter_sequence_id = 1	
LEFT OUTER JOIN ReceiptTransporter RT2 (nolock) 
	ON RT2.receipt_id = R.receipt_id 
	AND RT2.company_id = R.company_id 
	AND RT2.profit_ctr_id = R.profit_ctr_id
	AND RT2.transporter_sequence_id = 2	
LEFT OUTER JOIN Profile
	ON Profile.profile_id = B.profile_id
	AND B.profile_id IS NOT NULL
LEFT OUTER JOIN ProfitCenter PC 
	ON PC.company_ID = R.company_id
	AND PC.profit_ctr_ID = R.profit_ctr_id
LEFT OUTER JOIN Treatment TR ON TR.treatment_id = R.treatment_id
WHERE
	B.customer_id = @int_customer_id
	AND B.invoice_date BETWEEN @int_start_date AND @int_end_date
	AND B.status_code = 'I'
GROUP BY
	R.manifest,
	B.receipt_id,
	B.line_id,
	B.company_id,
	B.profit_ctr_id,
	B.workorder_sequence_id,
	B.trans_source,
	RT1.transporter_sign_date,
	RT1.transporter_name,
	RT1.transporter_EPA_ID,
	RT2.transporter_name,
	RT2.transporter_EPA_ID,
	R.receipt_date,
	Profile.approval_desc,
	Profile.EPA_form_code,
	Profile.EPA_source_code,
	R.manifest_management_code,
	TR.management_code,
	PC.profit_ctr_name,
	PC.EPA_ID,
    G.generator_region_code,
	G.generator_division,
	G.generator_business_unit 
INSERT INTO EQ_Extract.dbo.Generic_Waste_Extract
(
		manifest
	,	pickup_date
	,	schedule_date
	,	waste_desc
	,	pounds
	,	fed_waste_codes
	,	state_waste_codes
	,	management_code
	,	form_code
	,	source_code
	,	cost
	,	receiving_facility
	,	receiving_facility_epa_id
	,	transporter_1_name
	,	transporter_1_epa_ID
	,	transporter_2_name
	,	transporter_2_epa_ID
	,	company_id
	,	profit_ctr_id
	,	receipt_id
	,	line_id
	,	trans_source
	,	added_by
	,	date_added
	,	region_code
	,	division_name
	,	business_unit
)
SELECT 
	Manifest
,	pickup_date
,	schedule_date
,	waste_desc
,	pounds
,	fed_waste_codes
,	state_waste_codes
,	management_code
,	form_code
,	source_code
,	cost
,	receiving_facility
,	receiving_facility_epa_id
,	transporter_1_name
,	transporter_1_epa_ID
,	transporter_2_name
,	transporter_2_epa_ID
,	company_id
,	profit_ctr_id
,	receipt_id
,	line_id
,	trans_source
,	LEFT(@Usr, 10)
,	@Extract_datetime 
,	region_code
,	division_name
,	business_unit
FROM EQ_TEMP.dbo.Generic_Waste_Extract (nolock) WHERE date_added = @extract_datetime and added_by = @usr

SET NOCOUNT OFF

-- Select out just the data wanted by Rite_Aid:
--select * from eq_extract.dbo.Generic_Waste_Extract where added_by = @Usr and date_added = @Extract_datetime
IF @int_include_eq_fields = 0
BEGIN
	SELECT
		Manifest
	,	pickup_date
	,	schedule_date
	,	waste_desc
	,	pounds
	,	fed_waste_codes
	,	state_waste_codes
	,	management_code
	,	form_code
	,	source_code
	,	cost
	,	receiving_facility
	,	receiving_facility_epa_id
	,	transporter_1_name
	,	transporter_1_epa_ID
	,	transporter_2_name
	,	transporter_2_epa_ID
	,	region_code
	,	division_name
	,	business_unit
	FROM EQ_Extract.dbo.Generic_Waste_Extract (nolock) 
	WHERE date_added = @extract_datetime 
	  AND added_by = @usr
	ORDER BY pickup_date, manifest
END
ELSE
BEGIN
	SELECT
		Manifest
	,	pickup_date
	,	schedule_date
	,	waste_desc
	,	pounds
	,	fed_waste_codes
	,	state_waste_codes
	,	management_code
	,	form_code
	,	source_code
	,	cost
	,	receiving_facility
	,	receiving_facility_epa_id
	,	transporter_1_name
	,	transporter_1_epa_ID
	,	transporter_2_name
	,	transporter_2_epa_ID
	,	company_id
	,	profit_ctr_id
	,	receipt_id
	,	line_id
	,	trans_source
	,	region_code
	,	division_name
	,	business_unit
	FROM EQ_Extract.dbo.Generic_Waste_Extract (nolock) 
	WHERE date_added = @extract_datetime 
	  AND added_by = @usr
	ORDER BY pickup_date, manifest
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generic_waste_extract] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generic_waste_extract] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generic_waste_extract] TO [EQAI]
    AS [dbo];

