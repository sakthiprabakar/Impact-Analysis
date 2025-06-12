USE [PLT_AI]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_ss_get_trip_profiles] 
(
	@trip_id INT,
	@trip_sequence_id INT = 0
)
AS
/**************

 01/10/2020 rwb Created
 04/23/2021 rwb All of a sudden this morning the optimizer started going to lunch on a query. Restructured the query.
 04/29/2021 rwb ADO 17520 - query needs to reference ProfileConstituent.UHC instead of Constituents.UHC_flag
 05/19/2021 rwb ADO 20860 - the call to dbo.fn_get_label_default_type needs to pass WO info instead of Profile
 11/07/2022 rwb ADO 20864 - add Profile Transporter comments to result set (Profile.comments_3)
 05/01/2023 rwb ADO 63176 - add DEA_flag to the result set
 03/18/2024 KS - DevOps 76901- Performance only updated both the c_const and c_subs CURSORs to FAST_FORWARD as both are used in the forward direction only 
						example: DECLARE c_subs CURSOR FAST_FORWARD
 exec sp_ss_get_trip_profiles 102117, 1
 exec sp_ss_get_trip_profiles 113238, 1

 **************/
DECLARE @id INT,
	@last_id INT,
	@const_id INT,
	@sub VARCHAR(100),
	@subcategory VARCHAR(4096)

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON

DROP TABLE IF exists #profile_ldr_sub
CREATE TABLE #profile_ldr_sub (
	profile_id INT,
	ldr_subcategory VARCHAR(4096)
	)

DROP TABLE IF exists #profile_uhc_const
CREATE TABLE #profile_uhc_const (
	profile_id INT,
	uhc_const VARCHAR(4096)
	)

DROP TABLE IF exists #m
CREATE TABLE #m (
	workorder_id INT NOT NULL,
	company_id INT NOT NULL,
	profit_ctr_id INT NOT NULL,
	sequence_id INT NOT NULL,
	bill_unit_code VARCHAR(4) NOT NULL,
	manifest_flag CHAR(1) NULL,
	billing_flag CHAR(1) NULL,
	added_by VARCHAR(10) NULL,
	date_added DATETIME NULL,
	modified_by VARCHAR(10) NULL,
	date_modified DATETIME NULL
	)

-- codes defined in WorkOrderDetailUnit
INSERT #m
SELECT DISTINCT wodu.workorder_id,
	wodu.company_id,
	wodu.profit_ctr_id,
	wodu.sequence_id,
	wodu.size,
	isnull(wodu.manifest_flag, 'F'),
	isnull(wodu.billing_flag, 'F'),
	wod.added_by,
	wod.date_added,
	wod.modified_by,
	wod.date_modified
FROM dbo.WorkOrderDetailUnit AS wodu
INNER JOIN dbo.WorkOrderDetail AS wod
	ON wodu.workorder_id = wod.workorder_ID 
	AND wodu.company_id = wod.company_id 
	AND wodu.profit_ctr_id = wod.profit_ctr_id 
	AND wodu.sequence_id = wod.sequence_id 
	AND wod.resource_type = 'D'
INNER JOIN dbo.WorkOrderHeader AS woh
	ON wod.workorder_id = woh.workorder_id 
	AND wod.company_id = woh.company_id 
	AND wod.profit_ctr_id = woh.profit_ctr_id
	--	AND woh.workorder_status <> 'V'
	AND woh.trip_id = @trip_id

-- codes not defined in WorkOrderDetailUnit (Profile)
INSERT #m
SELECT DISTINCT wod.workorder_id,
	wod.company_id,
	wod.profit_ctr_id,
	wod.sequence_id,
	pqd.bill_unit_code,
	'F',
	'T',
	'SA',
	GETDATE(),
	'SA',
	GETDATE()
FROM dbo.WorkOrderDetail AS wod
INNER JOIN dbo.TSDF AS t
	ON t.TSDF_code = wod.TSDF_code 
	AND ISNULL(t.eq_flag, 'F') = 'T'
INNER JOIN dbo.ProfileQuoteDetail AS pqd
	ON pqd.profile_id = wod.profile_id 
	AND pqd.company_id = wod.profile_company_id 
	AND pqd.profit_ctr_id = wod.profile_profit_ctr_id 
	AND pqd.record_type = 'D' 
	AND pqd.STATUS = 'A'
WHERE wod.workorder_id IN (
		SELECT workorder_id
		FROM dbo.WorkOrderHeader
		WHERE trip_id = @trip_id /*and workorder_status <> 'V'*/
		) 
		AND wod.company_id = 
		(
			SELECT company_id
			FROM dbo.TripHeader
			WHERE trip_id = @trip_id
		) 
		AND wod.profit_ctr_id = 
		(
			SELECT profit_ctr_id
			FROM dbo.TripHeader
			WHERE trip_id = @trip_id
		) 
		AND wod.resource_type = 'D' 
		AND NOT EXISTS (
			SELECT 1
			FROM #m
			WHERE workorder_id = wod.workorder_ID 
				AND company_id = wod.company_id 
				AND profit_ctr_id = wod.profit_ctr_id 
				AND sequence_id = wod.sequence_ID 
				AND bill_unit_code = pqd.bill_unit_code
			)

-- Fix for GEM 48441
UPDATE #m
SET manifest_flag = 'T'
FROM #m AS m
WHERE bill_unit_code = 'LBS'
	AND NOT EXISTS (
		SELECT 1
		FROM #m
		WHERE workorder_id = m.workorder_id 
			AND company_id = m.company_id 
			AND profit_ctr_id = m.profit_ctr_id 
			AND sequence_id = m.sequence_id 
			AND manifest_flag = 'T'
		)

DECLARE c_subs CURSOR FAST_FORWARD
FOR
SELECT 
DISTINCT 
	wod.profile_id,
	l.short_desc
FROM dbo.WorkOrderDetail AS wod
INNER JOIN dbo.WorkOrderHeader AS woh
	ON woh.workorder_id = wod.workorder_id 
	AND woh.company_id = wod.company_id 
	AND woh.profit_ctr_id = wod.profit_ctr_id 
	AND woh.trip_id = @trip_id 
	AND (@trip_sequence_id = 0 OR woh.trip_sequence_id = @trip_sequence_id)
LEFT JOIN dbo.WorkOrderDetailUnit AS wodu
	ON wod.workorder_id = wodu.workorder_id 
	AND wod.company_id = wodu.company_id 
	AND wod.profit_ctr_id = wodu.profit_ctr_id 
	AND wod.sequence_id = wodu.sequence_id 
	AND isnull(wodu.manifest_flag, 'F') = 'T'
INNER JOIN dbo.ProfileQuoteApproval AS pqa
	ON wod.profile_id = pqa.profile_id 
	AND wod.profile_company_id = pqa.company_id 
	AND wod.profile_profit_ctr_id = pqa.profit_ctr_id 
	AND pqa.STATUS = 'A' 
	AND isnull(pqa.LDR_req_flag, '') = 'T'
INNER JOIN dbo.ProfileLDRSubcategory AS p
	ON wod.profile_id = p.profile_id
INNER JOIN dbo.LDRSubcategory AS l
	ON p.ldr_subcategory_id = l.subcategory_id
WHERE wod.resource_type = 'D'
ORDER BY wod.profile_id,
	l.short_desc

OPEN c_subs

FETCH c_subs
INTO @id,
	@sub

WHILE @@fetch_status = 0
BEGIN
	IF @id = isnull(@last_id, 0)
		SET @subcategory = @subcategory + CHAR(13) + CHAR(10) + @sub
	ELSE
	BEGIN
		IF isnull(@last_id, 0) > 0
			INSERT #profile_ldr_sub
			VALUES (
				@last_id,
				isnull(@subcategory, '')
				)

		SET @subcategory = @sub
		SET @last_id = @id
	END

	FETCH c_subs
	INTO @id,
		@sub
END

CLOSE c_subs

DEALLOCATE c_subs

IF coalesce(@last_id, 0) > 0
	INSERT #profile_ldr_sub
	VALUES (
		@last_id,
		isnull(@subcategory, '')
		)

------
SET @last_id = 0

DECLARE c_const CURSOR FAST_FORWARD
FOR
SELECT
DISTINCT 
	wod.profile_id,
	pc.const_id,
	c.const_desc
FROM dbo.WorkOrderDetail AS wod
INNER JOIN dbo.WorkOrderHeader AS woh
	ON woh.workorder_id = wod.workorder_id 
	AND woh.company_id = wod.company_id 
	AND woh.profit_ctr_id = wod.profit_ctr_id 
	AND woh.trip_id = @trip_id 
	AND (@trip_sequence_id = 0 OR woh.trip_sequence_id = @trip_sequence_id)
INNER JOIN dbo.ProfileQuoteApproval AS pqa
	ON wod.profile_id = pqa.profile_id 
	AND wod.profile_company_id = pqa.company_id 
	AND wod.profile_profit_ctr_id = pqa.profit_ctr_id 
	AND pqa.STATUS = 'A' 
	AND isnull(pqa.LDR_req_flag, '') = 'T'
INNER JOIN dbo.ProfileConstituent AS pc
	ON pc.profile_id = wod.profile_id 
	AND pc.UHC = 'T'
INNER JOIN dbo.Constituents AS c
	ON c.const_id = pc.const_id
WHERE wod.resource_type = 'D'
ORDER BY wod.profile_id,
	pc.const_id

OPEN c_const

FETCH c_const
INTO @id,
	@const_id,
	@sub

WHILE @@fetch_status = 0
BEGIN
	IF @id = isnull(@last_id, 0)
		SET @subcategory = @subcategory + ', ' + convert(VARCHAR(10), @const_id) + ' - ' + @sub
	ELSE
	BEGIN
		IF isnull(@last_id, 0) > 0
			INSERT #profile_uhc_const
			VALUES (
				@last_id,
				isnull(@subcategory, '')
				)

		SET @subcategory = convert(VARCHAR(10), @const_id) + ' - ' + @sub
		SET @last_id = @id
	END

	FETCH c_const
	INTO @id,
		@const_id,
		@sub
END

CLOSE c_const

DEALLOCATE c_const

IF coalesce(@last_id, 0) > 0
	INSERT #profile_uhc_const
	VALUES (
		@last_id,
		isnull(@subcategory, '')
		)

SET NOCOUNT OFF

------
SELECT
	wh.workorder_id,
	wh.company_id,
	wh.profit_ctr_ID,
	wd.sequence_ID,
	wd.profile_id,
	coalesce(wd.TSDF_code, '') AS TSDF_code,
	coalesce(wd.manifest, '') AS manifest,
	CASE ltrim(wm.manifest_state)
		WHEN 'H'
			THEN 'HAZ'
		ELSE CASE 
				WHEN th.use_manifest_haz_only_flag = 'B'
					THEN 'BOL'
				ELSE 'NONHAZ'
				END
		END AS manifest_type,
	coalesce(wd.TSDF_approval_code, '') AS TSDF_approval_code,
	coalesce(wd.description, '') AS description,
	coalesce(wd.reportable_quantity_flag, '') AS reportable_quantity_flag,
	coalesce(wd.RQ_reason, '') AS RQ_reason,
	coalesce(wd.UN_NA_flag, '') AS UN_NA_FLAG,
	wd.UN_NA_number,
	coalesce(wd.DOT_shipping_name, '') AS DOT_shipping_name,
	coalesce(wd.hazmat_class, '') AS hazmat_class,
	coalesce(wd.subsidiary_haz_mat_class, '') AS subsidiary_haz_mat_class,
	coalesce(p.DOT_sp_permit_flag, '') AS DOT_sp_permit_flag,
	coalesce(p.dot_sp_permit_text, '') AS dot_sp_permit_text,
	wd.ERG_number,
	coalesce(wd.ERG_suffix, '') AS ERG_suffix,
	coalesce(wdu.bill_unit_code, '') AS bill_unit_code,
	coalesce(pmc.category_id, 0) AS merchandise_category_id,
	coalesce(pqa.LDR_req_flag, 'F') AS ldr_required_flag,
	coalesce(p.mim_customer_label_flag, 'F') AS customer_label_flag,
	coalesce(p.hazmat, 'F') AS hazmat_flag,
	coalesce(p.package_group, '') AS package_group,
	coalesce(p.manifest_dot_sp_number, '') AS manifest_dot_sp_number,
	coalesce(p.pharmaceutical_flag, 'F'),
	dbo.fn_get_label_default_type('W', wd.workorder_id, wd.company_id, wd.profit_ctr_id, wd.sequence_id, wh.generator_id) AS label_type,
	coalesce(pqa.location, '') AS [location],
	pqa.treatment_id,
	--Can this be converted to a JOIN?
	dbo.fn_build_consolidation_compare_string(
		pqa.consolidate_containers_flag,
		c.consolidate_containers_flag, 
		p.profile_id, 
		p.approval_desc, 
		p.un_na_flag, 
		p.un_na_number, 
		p.dot_shipping_name, 
		p.hazmat, 
		p.hazmat_class, 
		p.subsidiary_haz_mat_class, 
		p.package_group, 
		p.reportable_quantity_flag, 
		p.erg_number, p.erg_suffix, 
		pqa.print_dot_sp_flag, 
		p.manifest_dot_sp_number, 
		pqa.treatment_id, 
		pqa.[location], 
		pqa.OB_eq_profile_id, 
		pqa.OB_eq_company_id, 
		pqa.OB_eq_profit_ctr_id, 
		pqa.OB_tsdf_approval_id, 
		pqa.consolidation_group_uid, 
		pc.air_permit_flag, 
		pqa.air_permit_status_uid, 
			(
				SELECT count(*)
				FROM dbo.ProfileWasteCode AS pwc
				INNER JOIN dbo.WasteCode AS wc
					ON wc.waste_code_uid = pwc.waste_code_uid 
					AND wc.waste_code_origin = 'F'
				WHERE pwc.profile_id = p.profile_id
			) 
	) AS consolidate_compare,
	t.TSDF_name,
	t.TSDF_EPA_ID,
	--03/27/2023 In TEST starting this morning, the following function call ends up generating the following error:
	--Internal error: An expression services limit has been reached. Please look for potentially complex expressions in your query, and try to simplify them.
	--Note that the error only happens when executed in this stored procedure... pulling the SQL out and executing in MSSMS works fine
	--dbo.fn_address_concatenated(t.TSDF_addr1, t.TSDF_addr2, t.TSDF_addr3, '', t.TSDF_city, t.TSDF_state, t.TSDF_zip_code, t.TSDF_country_code) TSDF_address,
	CASE coalesce(ltrim(rtrim(t.TSDF_addr1)), '')
		WHEN ''
			THEN ''
		ELSE coalesce(ltrim(rtrim(t.TSDF_addr1)), '') + CHAR(10)
		END + CASE coalesce(ltrim(rtrim(t.TSDF_addr2)), '')
		WHEN ''
			THEN ''
		ELSE coalesce(ltrim(rtrim(t.TSDF_addr2)), '') + CHAR(10)
		END + CASE coalesce(ltrim(rtrim(t.TSDF_addr3)), '')
		WHEN ''
			THEN ''
		ELSE coalesce(ltrim(rtrim(t.TSDF_addr3)), '') + CHAR(10)
		END + CASE coalesce(ltrim(rtrim(t.TSDF_city)), '')
		WHEN ''
			THEN ''
		ELSE coalesce(ltrim(rtrim(t.TSDF_city)), '')
		END + CASE coalesce(ltrim(rtrim(t.TSDF_state)), '')
		WHEN ''
			THEN ''
		ELSE ', ' + coalesce(ltrim(rtrim(t.TSDF_state)), '')
		END + CASE coalesce(ltrim(rtrim(t.TSDF_zip_code)), '')
		WHEN ''
			THEN ''
		ELSE ' ' + coalesce(ltrim(rtrim(t.TSDF_zip_code)), '')
		END + CASE coalesce(ltrim(rtrim(t.TSDF_country_code)), '')
		WHEN ''
			THEN ''
		WHEN 'US'
			THEN ' USA'
		WHEN 'Canada'
			THEN ' CAN'
		WHEN 'CA'
			THEN ' CAN'
		WHEN 'IN'
			THEN ' IND'
		WHEN 'CH'
			THEN ' CHE'
		ELSE ' ' + coalesce(ltrim(rtrim(t.TSDF_country_code)), '')
		END AS TSDF_address,
	coalesce(t.TSDF_phone, '') AS TSDF_phone,
	coalesce(wd.management_code, '') AS management_code,
	coalesce(wdu.manifest_flag, 'F') AS manifest_flag,
	coalesce(wdu.billing_flag, 'F') AS billing_flag,
	CASE 
		WHEN charindex('SOLID', isnull(pl.consistency, '')) > 0 AND isnull(pl.free_liquid, '') = 'T'
			THEN 'Solid, Liquid'
		WHEN charindex('SOLID', isnull(pl.consistency, '')) > 0
			THEN 'Solid'
		WHEN isnull(pl.free_liquid, '') = 'T'
			THEN 'Liquid'
		ELSE ''
		END AS physical_state,
	coalesce(nullif(substring(CASE 
					WHEN isnull(pl.ignitability_lt_90, '') = 'T' OR isnull(pl.ignitability_90_139, '') = 'T'
						THEN ', Flammable'
					ELSE ''
					END + CASE 
					WHEN EXISTS (
							SELECT 1
							FROM dbo.WorkOrderWasteCode AS wwc
							INNER JOIN dbo.WasteCode AS wc
								ON wwc.waste_code_uid = wc.waste_code_uid 
								AND 
								(
									wc.display_name BETWEEN 'D004' AND 'D043' 
									OR wc.display_name LIKE 'F%' 
									OR wc.display_name LIKE 'K%'
								)
							WHERE wwc.workorder_id = wd.workorder_id 
								AND wwc.company_id = wd.company_id 
								AND wwc.profit_ctr_id = wd.profit_ctr_id 
								AND wwc.workorder_sequence_id = wd.sequence_id
							)
						THEN ', Toxic'
					ELSE ''
					END + CASE 
					WHEN EXISTS (
							SELECT 1
							FROM dbo.WorkOrderWasteCode AS wwc
							INNER JOIN dbo.WasteCode AS wc
								ON wwc.waste_code_uid = wc.waste_code_uid 
								AND wc.display_name = 'D002'
							WHERE wwc.workorder_id = wd.workorder_id 
								AND wwc.company_id = wd.company_id 
								AND wwc.profit_ctr_id = wd.profit_ctr_id 
								AND wwc.workorder_sequence_id = wd.sequence_id
							)
						THEN ', Corrosive'
					ELSE ''
					END + CASE 
					WHEN EXISTS (
							SELECT 1
							FROM dbo.WorkOrderWasteCode AS wwc
							INNER JOIN dbo.WasteCode AS wc
								ON wwc.waste_code_uid = wc.waste_code_uid 
								AND wc.display_name = 'D003'
							WHERE wwc.workorder_id = wd.workorder_id 
								AND wwc.company_id = wd.company_id 
								AND wwc.profit_ctr_id = wd.profit_ctr_id 
								AND wwc.workorder_sequence_id = wd.sequence_id
							)
						THEN ', Reactive'
					ELSE ''
					END + CASE 
					WHEN EXISTS (
							SELECT 1
							FROM dbo.WorkOrderWasteCode AS wwc
							INNER JOIN dbo.WasteCode AS wc
								ON wwc.waste_code_uid = wc.waste_code_uid 
								AND (wc.display_name LIKE 'P%' OR wc.display_name LIKE 'U%')
							WHERE wwc.workorder_id = wd.workorder_id 
								AND wwc.company_id = wd.company_id 
								AND wwc.profit_ctr_id = wd.profit_ctr_id 
								AND wwc.workorder_sequence_id = wd.sequence_id
							)
						THEN ', Other: Accutely Hazardous'
					ELSE ''
					END + CASE isnull(wd.hazmat_class, '')
					WHEN '5.1'
						THEN ', Other: Oxidizer'
					ELSE ''
					END + CASE isnull(wd.hazmat_class, '')
					WHEN '5.2'
						THEN ', Other: Organic Peroxide'
					ELSE ''
					END, 3, 255), ''), 'Other') AS hazardous_properties,
	CASE 
		WHEN P.waste_water_flag = 'W'
			THEN 'WW'
		ELSE 'NWW'
		END AS ww_flag,
	coalesce(pldr.ldr_subcategory, '') AS ldr_subcategory,
	coalesce(CASE ldr.waste_managed_flag
			WHEN 'S'
				THEN REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(2000), ldr.underlined_text), '|contains_listed:DOES:DOES NOT|', ldr.contains_listed), '|exhibits_characteristic:DOES:DOES NOT|', ldr.exhibits_characteristic), '|soil_treatment_standards:IS SUBJECT TO:COMPLIES WITH|', ldr.soil_treatment_standards)
			ELSE ldr.underlined_text
			END, '') AS underlined_text,
	coalesce(ldr.regular_text, '') AS regular_text,
	coalesce(puc.uhc_const, '') AS uhc_constituents,
	coalesce(t.TSDF_state, '') AS TSDF_state,
	coalesce(p.RQ_threshold, 0.0) RQ_threshold,
	coalesce(tdr_1.permit_license_registration, '') AS TSDF_dea_permit_line_1,
	coalesce(tdr_2.permit_license_registration, '') AS TSDF_dea_permit_line_2,
	coalesce(p.empty_bottle_flag, 'F') AS empty_bottle_flag,
	coalesce(convert(NUMERIC(10, 10), p.residue_pounds_factor), 0.0) AS empty_bottle_residue_factor,
	coalesce(p.empty_bottle_count_manifest_print_flag, 'F') AS empty_bottle_manifest_print_flag,
	coalesce(p.residue_manifest_print_flag, 'F') AS empty_bottle_residue_manifest_print_flag,
	coalesce(p.manifest_hand_instruct, '') AS manifest_hand_instruct,
	coalesce(p.manifest_message, '') AS manifest_message,
	coalesce(t.DEA_ID, '') AS tsdf_DEA_ID,
	coalesce(wd.container_code, p.manifest_container_code, '') AS container_code,
	CASE 
		WHEN wd.TSDF_code = 'USETPA'
			THEN 'US Ecology Tampa, Inc. Restricted Prescription Drug Distribution - Destruction License Number: 53-16'
		ELSE ''
		END tsdf_restricted_drug_license_line_1,
	CASE 
		WHEN wd.TSDF_code = 'USETPA'
			THEN 'US Ecology Tampa, Inc., 2002 NORTH ORIENT ROAD, TAMPA, FL 33619'
		ELSE ''
		END tsdf_restricted_drug_license_line_2,
	CASE 
		WHEN wd.bill_rate = - 2
			THEN 'F'
		ELSE 'T'
		END AS shipped_status,
	coalesce(wd.DOT_shipping_desc_additional, p.DOT_shipping_desc_additional, '') AS DOT_shipping_desc_additional,
	coalesce(p.comments_3, '') AS transporter_comments,
	coalesce(p.DEA_flag, 'F') AS DEA_flag
FROM dbo.TripHeader AS th
INNER JOIN dbo.WorkOrderHeader AS wh
	ON wh.trip_id = th.trip_id
--	and wh.workorder_status <> 'V'
INNER JOIN dbo.WorkOrderDetail AS wd
	ON wd.workorder_id = wh.workorder_ID 
	AND wd.company_id = wh.company_id 
	AND wd.profit_ctr_id = wh.profit_ctr_ID 
	AND wd.resource_type = 'D'
INNER JOIN dbo.WorkorderManifest AS wm
	ON wm.workorder_id = wd.workorder_ID 
	AND wm.company_id = wd.company_id 
	AND wm.profit_ctr_id = wd.profit_ctr_ID 
	AND wm.manifest = wd.manifest
INNER JOIN dbo.TSDF AS t
	ON t.TSDF_code = wd.TSDF_code 
	AND coalesce(t.eq_flag, '') = 'T'
INNER JOIN dbo.[Profile] AS p
	ON p.profile_id = wd.profile_id
INNER JOIN dbo.ProfileLab pl
	ON pl.profile_id = p.profile_id 
	AND pl.type = 'A'
INNER JOIN dbo.Customer AS c
	ON c.customer_id = p.customer_id
INNER JOIN dbo.Generator AS g
	ON g.generator_id = wh.generator_id
INNER JOIN dbo.ProfileQuoteApproval AS pqa
	ON pqa.profile_id = wd.profile_id 
	AND pqa.company_id = wd.profile_company_id 
	AND pqa.profit_ctr_id = wd.profile_profit_ctr_id
INNER JOIN dbo.ProfitCenter AS pc
	ON pc.company_id = pqa.company_id 
	AND pc.profit_ctr_ID = pqa.profit_ctr_id
INNER JOIN #m AS wdu
	ON wdu.workorder_id = wd.workorder_ID 
	AND wdu.company_id = wd.company_id 
	AND wdu.profit_ctr_id = wd.profit_ctr_ID 
	AND wdu.sequence_id = wd.sequence_ID
LEFT JOIN dbo.ProfileXMerchandiseCategory AS pmc
	ON pmc.profile_id = p.profile_id
LEFT JOIN dbo.LDRWasteManaged AS ldr
	ON ldr.waste_managed_id = p.waste_managed_id AND ldr.version = (
			SELECT max(version)
			FROM dbo.LDRWasteManaged
			WHERE waste_managed_id = p.waste_managed_id
			)
LEFT JOIN #profile_ldr_sub AS pldr
	ON pldr.profile_id = p.profile_id
LEFT JOIN #profile_uhc_const AS puc
	ON puc.profile_id = p.profile_id
LEFT JOIN dbo.TSDFDEARegistration AS tdr_1
	ON tdr_1.TSDF_code = wd.TSDF_code 
	AND tdr_1.state_abbr = g.generator_state 
	AND tdr_1.sequence_id = 1
LEFT JOIN dbo.TSDFDEARegistration AS tdr_2
	ON tdr_2.TSDF_code = wd.TSDF_code 
	AND tdr_2.state_abbr = g.generator_state 
	AND tdr_2.sequence_id = 2
WHERE th.trip_id = @trip_id 
	AND (@trip_sequence_id = 0 
	OR wh.trip_sequence_id = @trip_sequence_id)
ORDER BY wh.trip_sequence_id,
	wd.TSDF_code,
	wd.manifest,
	wd.sequence_id

DROP TABLE IF exists #m
GO

GRANT EXECUTE ON sp_ss_get_trip_profiles to EQAI, TRIPSERV
GO
