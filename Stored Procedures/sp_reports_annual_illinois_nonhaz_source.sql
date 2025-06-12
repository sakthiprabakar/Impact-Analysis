
CREATE PROC sp_reports_annual_illinois_nonhaz_source (
	@biennial_id	int = null, -- if not specified, will create a new run
	@Company	varchar(5),	-- '2|21, 25|00' etc.
	@start_date datetime,
	@end_date datetime,
	@user_code	varchar(10) -- 'JONATHAN' (or SYSTEM_USER)
)
AS
/* ***********************************************************
Procedure    : sp_reports_annual_illinois_nonhaz_source
Database     : PLT_AI
Created      : Feb 14 2011 - Jonathan Broome
Description  : Populates EQ_Extract source tables for biennial reports
Examples:
	sp_reports_annual_illinois_nonhaz_source NULL, '26|0', '1/1/2012','12/31/2012', 'JONATHAN'
	
	SELECT * FROM EQ_Extract..ILAnnualNonHazReport where biennial_id = 1731

Notes:
	This script was copied & modified from
		L:\Apps\SQL\Special Manual Requests\Biennial Reporting\
		\Biennial Report 2009 - EQFL\Queries\2009 Data.sql

	Overall process vision
		1. Create a new sequence_id for the current run
		2. Log the current run parameters, user
		3. Run
		4. Return current run sequence_id to user

History:
	2/14/2011 - JPB - Created
        2/23/2011 - JPB - Added Non-IL logic to get waste codes from different Receipt or Container, IL uses approvals
	2/10/2012 - JPB - Exchanged line_weight where net_weight was.
	2/15/2012 - JPB - Added max() to referenced receipts' lines for gals/yards
	2/17/2012 - SK After discussion with Lorraine & Jonathan decided to add TSDF.tsdf_status = 'A' into the JOIN to TSDF
	2/24/2012 - JDB - Updated to multiply by container_percent for all of the calculations, not just when the container_weight is populated.
						Modified to exclude BOLs from the inbound and outbound receipt selects.
						Modified to include 'YARD' in the same way that 'CYB' was being included.
						Modified to SUM the ReceiptPrice.bill_quantity when that is used in the weight calculations.
	2/24/2012 - JPB - Added fn for line_weight or net_weight if line_weight is null, and there's only 1 disposal line on the receipt
		as /* receipt.line_weight */ dbo.fn_line_weight_or_better(receipt.receipt_id, receipt.line_id, receipt.company_id, receipt.profit_ctr_id, receipt.line_weight)
		
	1/08/2013 - JPB - Copied from sp_reports_biennial_source, then modified to create a non-haz report source sp
						Don't care of the manifest_flag <> 'B'.  It might be anything.  Doesn't matter for non-haz waste
						Haz_flag checks on waste codes reversed. Looking for cases where NONE of the waste codes on the line are haz.
						Added report_log_id value (null) to Biennial Log insert.
						Converted from storing in EQ_Extract.. BiennialReportSourceData to ILAnnualNonHazReport

*********************************************************** */

-- Setup
	declare @starttime datetime = getdate()
	declare @debug int = 0
	
	DECLARE @is_new_run char(1) = 'F'
	if @biennial_id is null set @is_new_run = 'T'
	
	-- Waste Density
	DECLARE @waste_density varchar(6) = '8.3453'
	
	-- Data Source
	DECLARE @data_source varchar(10) = 'EQAI'

	set @end_date = DATEADD(DAY, 1, @end_date)
	set @end_date = DATEADD(s,-1,@end_date)
	
	
	-- Holder for the current run id, run_start
	DECLARE @date_added datetime = getdate()

	-- Log the current run
	insert EQ_Extract..BiennialLog
	select 
		COALESCE(@biennial_id, (select isnull(max(biennial_id), 0) + 1 from EQ_Extract..BiennialLog)) as biennial_id,
		@company,
		@start_date,
		@end_date,
		@user_code,
		@date_added,
		@date_added,
		null,
		null

	if @biennial_id is null
	begin
		-- Capture the current run id		
		select TOP 1
			@biennial_id = biennial_id 
		from EQ_Extract..BiennialLog
		where added_by = @user_code
			and date_added = @date_added
	end
	
	if @debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Biennial Log Run Config' as description

	-- Get run id's
	DECLARE @company_id int,
			@profit_ctr_id int,
			@profit_ctr_epa_id varchar(20)
		
	SELECT @company_id = convert(int, Rtrim(Ltrim(Substring(row, 1, Charindex('|', row) - 1)))),
		@profit_ctr_id = convert(int, Rtrim(Ltrim(Substring(row, Charindex('|', row) + 1, Len(row) - (Charindex('|', row) - 1)))))
	FROM dbo.fn_splitxsvtext(',', 1, @Company) WHERE Isnull(row, '') <> ''
	
	SELECT @profit_ctr_epa_id = epa_id from ProfitCenter (nolock) where company_id = @company_id and profit_ctr_id = @profit_ctr_id

------------------------
-- Inbound Receipts
------------------------

-- Get the weights on the Inbound containers
	select DISTINCT
		@biennial_id as biennial_id,
		Container.Company_id,
		Container.profit_ctr_id,
		Container.receipt_id,
		Container.line_id,
		Container.container_id,
		ContainerDestination.sequence_id,
		Treatment.treatment_id,

/*
Per Jim Conn (Tue 1/8/2013 10:56 AM) :

For the management code default to 07 treatment unless pre-location is populated in the profile.  
If pre-location is populated then management code should be 10 all others should be 7.

For the waste code use the profile area waste type  if liquid set to 18 if solid set to 19.

*/
		case when isnull(PQA.location, '') = '' THEN '07' ELSE '10' END as IL_management_code,
		case when (isnull(ProfileLab.consistency, '') LIKE '%liquid%' or ProfileLab.consistency LIKE '%gas/aerosol%') then '18' else '19' end as IL_waste_code,
		
		/* 
		the proper order for weights should go:
		1) manifested weight / container count
		2) container weight * container_percent / 100
		3) line_weight / container count
		4) if billed in LBS or TONS / container count
		5) ESTIMATED: the rest can be calculated by ReceiptPrice.bill_unit * quantity * conversion factor in bill unit
		
		
		-- NOTE:
			Order & Logic of weight handling...
			1. We set both actual & estimated to the SAME values (in this query)
			2. We create "lbs_per_container" fields in the "fill in est" query below this one.
			3. We round them all (doesn't matter, but it exists, so you see it here)
			4. We "Merge the weights": When lbs_haz_ESTIMATED = 0, we plug in the line's
				lbs_per_container figure * container_percentage.
			5. Lastly in this calculation, we have a catch:
				If the estimated figure = 0 and the actual figure > 0 (THIS SHOULD NOT HAPPEN)
				Then we plug the actual value in for the estimated one.
			6. In the output phase, we need to ask the user whehter we should only output ACTUAL
				weights (which may sometime be 0/null/missing) OR if we can fall back to ESTIMATED
				weights when that happens.  It's up to them... IT can't guess for them.
		
		*/
		lbs_haz_actual = COALESCE
		(
			CASE WHEN receipt.manifest_unit = 'P' THEN (receipt.manifest_quantity / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END,
			CASE WHEN ISNULL(Container.container_weight, 0) > 0 THEN
				 ISNULL(Container.container_weight, 0) * (IsNull(ContainerDestination.container_percent, 0) / 100.000)
			END,
			CASE WHEN ISNULL(
			/* receipt.line_weight */ dbo.fn_line_weight_or_better(receipt.receipt_id, receipt.line_id, receipt.company_id, receipt.profit_ctr_id, receipt.line_weight)
			, 0) > 0 THEN (/* receipt.line_weight */ dbo.fn_line_weight_or_better(receipt.receipt_id, receipt.line_id, receipt.company_id, receipt.profit_ctr_id, receipt.line_weight) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END,
			CASE WHEN EXISTS (SELECT 1 FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code IN('LBS','TONS')
			) THEN (SELECT 
						CASE 
							WHEN rp.bill_unit_code = 'LBS' THEN (SUM(rp.bill_quantity) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000)
							WHEN rp.bill_unit_code = 'TONS' THEN ((SUM(rp.bill_quantity) * 2000) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000)
						END 
				FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code IN('LBS','TONS')
				GROUP BY rp.bill_unit_code
			)
				END
		),
		lbs_haz_estimated = COALESCE
		(
			CASE WHEN receipt.manifest_unit = 'P' THEN (receipt.manifest_quantity / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END,
			CASE WHEN ISNULL(Container.container_weight, 0) > 0 THEN
				 ISNULL(Container.container_weight, 0) * (IsNull(ContainerDestination.container_percent, 0) / 100.000)
			END,
			CASE WHEN ISNULL(/* receipt.line_weight */ dbo.fn_line_weight_or_better(receipt.receipt_id, receipt.line_id, receipt.company_id, receipt.profit_ctr_id, receipt.line_weight), 0) > 0 THEN (/* receipt.line_weight */ dbo.fn_line_weight_or_better(receipt.receipt_id, receipt.line_id, receipt.company_id, receipt.profit_ctr_id, receipt.line_weight) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END,
			CASE WHEN EXISTS (SELECT 1 FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code IN('LBS','TONS')
			) THEN (SELECT 
						CASE 
							WHEN rp.bill_unit_code = 'LBS' THEN (SUM(rp.bill_quantity) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000)
							WHEN rp.bill_unit_code = 'TONS' THEN ((SUM(rp.bill_quantity) * 2000) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000)
						END 
				FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code IN('LBS','TONS')
				GROUP BY rp.bill_unit_code
			)
				END
		) /* calculated below if this ends up empty */,

		/* for GALLONS - the proper order for weights should go:
		G and Y are gallons and yards
		1) if manifested in gallons 'G', use manifested quantity
		2) if billed in GAL, then use receipt price quantity is the number of yards
		3) ESTIMATED the rest can be calculated by ReceiptPrice.bill_unit * quantity * conversion factor in bill unit
		*/		
		gal_haz_actual = COALESCE(
			CASE WHEN receipt.manifest_unit = 'G' THEN (receipt.manifest_quantity / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END,
			CASE WHEN EXISTS (SELECT 1 FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code = 'GAL'
			) THEN ((SELECT SUM(bill_quantity) FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code = 'GAL'
				GROUP BY rp.bill_unit_code
			) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END,
			CASE WHEN EXISTS (select 1 from Receipt r2 (nolock)
				WHERE r2.ref_receipt_id = receipt.receipt_id
				AND r2.ref_line_id = receipt.line_id
				AND r2.company_id = receipt.company_id
				AND r2.profit_ctr_id = receipt.profit_ctr_id
				AND r2.bill_unit_code = 'GAL'
			) THEN ((select max(r2.quantity) from Receipt r2 (nolock)
				WHERE r2.ref_receipt_id = receipt.receipt_id
				AND r2.ref_line_id = receipt.line_id
				AND r2.company_id = receipt.company_id
				AND r2.profit_ctr_id = receipt.profit_ctr_id
				AND r2.bill_unit_code = 'GAL'
			) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END
		),
		gal_haz_estimated = COALESCE(
			CASE WHEN receipt.manifest_unit = 'G' THEN (receipt.manifest_quantity / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END,
			CASE WHEN EXISTS (SELECT 1 FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code = 'GAL'
			) THEN ((SELECT SUM(bill_quantity) FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code = 'GAL'
				GROUP BY rp.bill_unit_code
			) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END,
			CASE WHEN EXISTS (select 1 from Receipt r2 (nolock)
				WHERE r2.ref_receipt_id = receipt.receipt_id
				AND r2.ref_line_id = receipt.line_id
				AND r2.company_id = receipt.company_id
				AND r2.profit_ctr_id = receipt.profit_ctr_id
				AND r2.bill_unit_code = 'GAL'
			) THEN ((select max(r2.quantity) from Receipt r2 (nolock)
				WHERE r2.ref_receipt_id = receipt.receipt_id
				AND r2.ref_line_id = receipt.line_id
				AND r2.company_id = receipt.company_id
				AND r2.profit_ctr_id = receipt.profit_ctr_id
				AND r2.bill_unit_code = 'GAL'
			) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END
		), /* calculated below if this is empty */
		
		/* for YARDS - the proper order for weights should go:
		1) if manifested in yards 'Y', use manifested quantity
		2) if billed in YARDS or CYB, then use receipt price quantity is the number of yards
		3) ESTIMATED the rest can be calculated by ReceiptPrice.bill_unit * quantity * conversion factor in bill unit
		*/				
		yard_haz_actual = COALESCE(
			CASE WHEN receipt.manifest_unit = 'Y' THEN (receipt.manifest_quantity  / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END,
			CASE WHEN EXISTS (SELECT 1 FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code IN ('CYB', 'YARD')
			) THEN ((SELECT SUM(bill_quantity) FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code IN ('CYB', 'YARD')
				GROUP BY rp.bill_unit_code
			) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END,
			CASE WHEN EXISTS (select 1 from Receipt r2 (nolock)
				WHERE r2.ref_receipt_id = receipt.receipt_id
				AND r2.ref_line_id = receipt.line_id
				AND r2.company_id = receipt.company_id
				AND r2.profit_ctr_id = receipt.profit_ctr_id
				AND r2.bill_unit_code IN ('CYB', 'YARD')
			) THEN ((select max(r2.quantity) from Receipt r2 (nolock)
				WHERE r2.ref_receipt_id = receipt.receipt_id
				AND r2.ref_line_id = receipt.line_id
				AND r2.company_id = receipt.company_id
				AND r2.profit_ctr_id = receipt.profit_ctr_id
				AND r2.bill_unit_code IN ('CYB', 'YARD')
			) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END
		),
		yard_haz_estimated = COALESCE(
			CASE WHEN receipt.manifest_unit = 'Y' THEN (receipt.manifest_quantity  / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END,
			CASE WHEN EXISTS (SELECT 1 FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code IN ('CYB', 'YARD')
			) THEN ((SELECT SUM(bill_quantity) FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code IN ('CYB', 'YARD')
				GROUP BY rp.bill_unit_code
			) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END,
			CASE WHEN EXISTS (select 1 from Receipt r2 (nolock)
				WHERE r2.ref_receipt_id = receipt.receipt_id
				AND r2.ref_line_id = receipt.line_id
				AND r2.company_id = receipt.company_id
				AND r2.profit_ctr_id = receipt.profit_ctr_id
				AND r2.bill_unit_code IN ('CYB', 'YARD')
			) THEN ((select max(r2.quantity) from Receipt r2 (nolock)
				WHERE r2.ref_receipt_id = receipt.receipt_id
				AND r2.ref_line_id = receipt.line_id
				AND r2.company_id = receipt.company_id
				AND r2.profit_ctr_id = receipt.profit_ctr_id
				AND r2.bill_unit_code IN ('CYB', 'YARD')
			) / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000) END
		),
		IsNull(ContainerDestination.container_percent,0) as container_percent,
		UPPER(CONVERT(VARCHAR(15), Receipt.approval_code)) AS approval_code,
		UPPER(CONVERT(VARCHAR(50), COALESCE(profileLab.density, @waste_density))) as waste_density,
		Generator.generator_id as generator_id,
		UPPER(CONVERT(VARCHAR(12), LTRIM(RTRIM(Generator.EPA_ID)))) as generator_epa_id,
		UPPER(CONVERT(VARCHAR(40), Generator.generator_name)) AS generator_name,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_1,''))) AS generator_address_1,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_2,''))) AS generator_address_2,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_3,''))) AS generator_address_3,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_4,''))) AS generator_address_4,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_5,''))) AS generator_address_5,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_city,''))) AS generator_city,
		UPPER(CONVERT(VARCHAR(2), IsNull(Generator.generator_state,''))) AS generator_state,
		UPPER(CONVERT(VARCHAR(15), IsNull(Generator.generator_zip_code,''))) AS generator_zip_code,
		UPPER(CONVERT(VARCHAR(20), IsNull(Generator.state_id,''))) AS generator_state_id --,
		--UPPER(CONVERT(VARCHAR(12), Transporter.transporter_EPA_ID)) AS transporter_EPA_ID,
		--UPPER(CONVERT(VARCHAR(40), Transporter.transporter_name)) AS transporter_name,
		--UPPER(CONVERT(VARCHAR(40), Transporter.transporter_addr1)) AS transporter_addr1,
		--UPPER(CONVERT(VARCHAR(40), Transporter.transporter_addr2)) AS transporter_addr2,
		--UPPER(CONVERT(VARCHAR(40), Transporter.transporter_addr3)) AS transporter_addr3,
		--UPPER(CONVERT(VARCHAR(40), IsNull(Transporter.transporter_city,''))) AS transporter_city,
		--UPPER(CONVERT(VARCHAR(2), IsNull(Transporter.transporter_state,''))) AS transporter_state,
		--UPPER(CONVERT(VARCHAR(15), IsNull(Transporter.transporter_zip_code,''))) AS transporter_zip_code,
		--UPPER(CONVERT(VARCHAR(12), TSDF.TSDF_EPA_ID)) AS TSDF_EPA_ID,
		--UPPER(CONVERT(VARCHAR(40), TSDF.TSDF_name)) AS TSDF_name,
		--UPPER(CONVERT(VARCHAR(40), TSDF.TSDF_addr1)) AS TSDF_addr1,
		--UPPER(CONVERT(VARCHAR(40), TSDF.TSDF_addr2)) AS TSDF_addr2,
		--UPPER(CONVERT(VARCHAR(40), TSDF.TSDF_addr3)) AS TSDF_addr3,
		--UPPER(CONVERT(VARCHAR(40), IsNull(TSDF.TSDF_city,''))) AS TSDF_city,
		--UPPER(CONVERT(VARCHAR(2), IsNull(TSDF.TSDF_state,''))) AS TSDF_state,
		--UPPER(CONVERT(VARCHAR(15), IsNull(TSDF.TSDF_zip_code,''))) AS TSDF_zip_code
	INTO #tmp_container_IB
	FROM Receipt (nolock)
		JOIN Container WITH(NOLOCK) ON (Receipt.company_id = Container.company_id 
			AND Receipt.profit_ctr_id = Container.profit_ctr_id 
			AND Receipt.receipt_id = Container.receipt_id 
			AND Receipt.line_id = Container.line_id
			AND Receipt.profit_ctr_id = Container.profit_ctr_id
			AND Receipt.company_id = Container.company_id)
		JOIN ContainerDestination WITH(NOLOCK)  ON (Container.company_id = ContainerDestination.company_id
			AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
			AND Container.receipt_id = ContainerDestination.receipt_id 
			AND Container.line_id = ContainerDestination.line_id
			AND Container.container_id = ContainerDestination.container_id)
		JOIN Profile  WITH(NOLOCK) ON (Receipt.profile_id = Profile.Profile_id)
		JOIN ProfileQuoteApproval PQA ON (Receipt.approval_code = PQA.approval_code
			AND Receipt.profit_ctr_id = PQA.profit_ctr_id
			AND Receipt.company_id = PQA.company_id)
		JOIN TreatmentHeader Treatment WITH(NOLOCK)  ON (
			CASE WHEN ISnull(ContainerDestination.treatment_id,0) <> 0 
				THEN ISnull(ContainerDestination.treatment_id,0)
				ELSE
					CASE WHEN ISnull(Receipt.treatment_id,0) <> 0 
						THEN ISnull(Receipt.treatment_id,0) 
						ELSE
							isnull(PQA.Treatment_ID, 0)
					END
			END = Treatment.treatment_id )
		JOIN WasteType WITH(NOLOCK)  ON (Profile.wastetype_id = WasteType.wastetype_id)
		JOIN Generator  WITH(NOLOCK) ON (Receipt.generator_id = Generator.generator_id)
		--JOIN Transporter WITH(NOLOCK)  ON (Receipt.hauler = Transporter.transporter_code)
		--JOIN ProfitCenter  WITH(NOLOCK) ON (Receipt.company_id = ProfitCenter.company_id
		--	AND Receipt.profit_ctr_id = ProfitCenter.profit_ctr_id)
		--JOIN TSDF With(NOLOCK) ON TSDF.eq_company = Receipt.company_id
		--	AND TSDF.eq_profit_ctr = Receipt.profit_ctr_id
		--	AND ISNULL(TSDF.eq_flag, 'F') = 'T'
		--	AND TSDF.tsdf_status = 'A'
		JOIN ProfileLab ON receipt.profile_id = ProfileLab.profile_id
			AND ProfileLab.type = 'A'
	WHERE 
		Container.company_id = @company_id
		AND Container.profit_ctr_id = @profit_ctr_id
		AND Container.status = 'C'
		AND ContainerDestination.status = 'C'
		AND Container.container_type = 'R'
		AND Receipt.trans_mode = 'I'
		AND Receipt.trans_type = 'D'
		AND Receipt.receipt_status = 'A'
		AND Receipt.fingerpr_status = 'A'
		-- AND Receipt.data_complete_flag = 'T'
		-- AND Receipt.manifest_flag <> 'B'
		AND (Receipt.receipt_date >= @start_date AND Receipt.receipt_date <= @end_date)
		AND (
			NOT EXISTS (
				SELECT CW.* FROM ContainerWasteCode CW WITH(NOLOCK) 
				Join WasteCode  WITH(NOLOCK) on CW.waste_code = WasteCode.waste_code
				WHERE ContainerDestination.company_id = CW.company_id 
				AND ContainerDestination.profit_ctr_id = CW.profit_ctr_id
				AND ContainerDestination.receipt_id = CW.receipt_id
				AND ContainerDestination.line_id = CW.line_id
				AND ContainerDestination.container_id = CW.container_id
				AND ContainerDestination.sequence_id = CW.sequence_id
				AND WasteCode.waste_code_origin = 'F'
				AND IsNull(WasteCode.haz_flag,'F') = 'T'
			)
			AND 
			NOT EXISTS (
				SELECT RWC.* FROM ReceiptWasteCode RWC WITH(NOLOCK) 
				Join WasteCode  WITH(NOLOCK) on RWC.waste_code = WasteCode.waste_code
				WHERE ContainerDestination.company_id = RWC.company_id 
				AND ContainerDestination.profit_ctr_id = RWC.profit_ctr_id
				AND ContainerDestination.receipt_id = RWC.receipt_id
				AND ContainerDestination.line_id = RWC.line_id
				AND WasteCode.waste_code_origin = 'F'
				AND IsNull(WasteCode.haz_flag,'F') = 'T'
				AND Not EXISTS (
					SELECT CW.* FROM ContainerWasteCode CW WITH(NOLOCK) 
					WHERE ContainerDestination.company_id = CW.company_id 
					AND ContainerDestination.profit_ctr_id = CW.profit_ctr_id
					AND ContainerDestination.receipt_id = CW.receipt_id
					AND ContainerDestination.line_id = CW.line_id
					AND ContainerDestination.container_id = CW.container_id
					AND ContainerDestination.sequence_id = CW.sequence_id
				)
			)
		)
	ORDER BY
		Container.company_id,
		Container.profit_ctr_id,
		Container.receipt_id,
		Container.line_id,
		Container.container_id,
		ContainerDestination.sequence_id

	if @debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Finished Inserting Inbound Receipts' as description

-- fill in the "estimated" values for lbs, gal, yards
	SELECT DISTINCT
		@biennial_id as biennial_id,
		Receipt.company_id,
		Receipt.profit_ctr_id,
		Receipt.receipt_id,
		Receipt.line_id,
		IsNull(ReceiptPrice.bill_quantity,0) * IsNull(BillUnit.pound_conv,0) / Receipt.container_count AS lbs_per_container,
		IsNull(ReceiptPrice.bill_quantity,0) * IsNull(BillUnit.gal_conv,0) / Receipt.container_count AS gal_per_container,
		IsNull(ReceiptPrice.bill_quantity,0) * IsNull(BillUnit.yard_conv,0) / Receipt.container_count AS yard_per_container
	INTO #tmp_calc_IB
	FROM Receipt (nolock)
		JOIN #tmp_container_IB WITH(NOLOCK)  ON (Receipt.company_id = #tmp_container_IB.company_id
			And Receipt.profit_ctr_id = #tmp_container_IB.profit_ctr_id
			AND Receipt.receipt_id = #tmp_container_IB.receipt_id
			AND Receipt.line_id = #tmp_container_IB.line_id
			AND Receipt.profit_ctr_id = #tmp_container_IB.profit_ctr_id
			AND Receipt.company_id = #tmp_container_IB.company_id)
		JOIN ReceiptPrice  WITH(NOLOCK) ON (Receipt.company_id = ReceiptPrice.company_id
			AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
			AND Receipt.receipt_id = ReceiptPrice.receipt_id
			AND Receipt.line_id = ReceiptPrice.line_id
			AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
			AND Receipt.company_id = ReceiptPrice.company_id)
		JOIN BillUnit WITH(NOLOCK)  ON (ReceiptPrice.bill_unit_code = BillUnit.bill_unit_code)

	/* round the values */
	UPDATE #tmp_container_IB SET lbs_haz_actual = ROUND(lbs_haz_actual, 2),
	lbs_haz_estimated = ROUND(lbs_haz_estimated, 2),
	gal_haz_estimated = ROUND(gal_haz_estimated, 2),
	gal_haz_actual = ROUND(gal_haz_actual, 2),
	yard_haz_actual = ROUND(yard_haz_actual, 2),
	yard_haz_estimated = ROUND(yard_haz_estimated, 2)

	-- Merge the weights
	UPDATE #tmp_container_IB SET
		lbs_haz_estimated = 
			CASE 
				WHEN ISNULL(lbs_haz_estimated, 0) = 0 then (#tmp_calc_IB.lbs_per_container * (#tmp_container_IB.container_percent / 100.000)) 
				ELSE lbs_haz_estimated
			end,
		gal_haz_estimated = 
			CASE 
				WHEN ISNULL(gal_haz_estimated, 0) = 0 THEN (#tmp_calc_IB.gal_per_container * (#tmp_container_IB.container_percent / 100.000)) 
				ELSE gal_haz_estimated
			END
		,
		yard_haz_estimated = 
			CASE 
				WHEN ISNULL(yard_haz_estimated, 0) = 0 THEN (#tmp_calc_IB.yard_per_container * (#tmp_container_IB.container_percent / 100.000)) 
				ELSE yard_haz_estimated
			END
	FROM #tmp_calc_IB
	WHERE 
		#tmp_container_IB.company_id = #tmp_calc_IB.company_id
		AND #tmp_container_IB.profit_ctr_id = #tmp_calc_IB.profit_ctr_id
		AND #tmp_container_IB.receipt_id = #tmp_calc_IB.receipt_id
		AND #tmp_container_IB.line_id = #tmp_calc_IB.line_id
		--AND #tmp_container_IB.lbs_haz_actual = 0

	-- BLANK OUT BAD EPA_IDs
		UPDATE #tmp_container_IB SET generator_epa_id = '' WHERE generator_epa_id IN ( 'N/A', '.', '....', 'NONE')
		-- UPDATE #tmp_container_IB SET transporter_epa_id = '' WHERE transporter_epa_id IN ( 'N/A', '.', '....', 'NONE')
		-- UPDATE #tmp_container_IB SET tsdf_epa_id = '' WHERE tsdf_epa_id IN ( 'N/A', '.', '....', 'NONE')
		

	if @debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Finished Weight Calculation' as description
	

	-- Results
	INSERT EQ_Extract..ILAnnualNonHazReport (
		biennial_id,
		Company_id,
		profit_ctr_id,
		receipt_id,
		line_id,
		container_id,
		sequence_id,
		treatment_id,
		IL_management_code,
		IL_waste_code,
		lbs_haz_actual,
		lbs_haz_estimated,
		gal_haz_actual,
		gal_haz_estimated,
		yard_haz_actual,
		yard_haz_estimated,
		container_percent,
		approval_code,
		waste_density,
		eq_generator_id,
		generator_epa_id,
		generator_name,
		generator_address_1,
		generator_address_2,
		generator_address_3,
		generator_address_4,
		generator_address_5,
		generator_city,
		generator_state,
		generator_zip_code,
		generator_state_id --,
		--transporter_EPA_ID,
		--transporter_name,
		--transporter_addr1,
		--transporter_addr2,
		--transporter_addr3,
		--transporter_city,
		--transporter_state,
		--transporter_zip_code,
		--TSDF_EPA_ID,
		--TSDF_name,
		--TSDF_addr1,
		--TSDF_addr2,
		--TSDF_addr3,
		--TSDF_city,
		--TSDF_state,
		--TSDF_zip_code
	)		
	SELECT DISTINCT
		@biennial_id as biennial_id,
		Company_id,
		profit_ctr_id,
		receipt_id,
		line_id,
		container_id,
		sequence_id,
		treatment_id,
		IL_management_code,
		IL_waste_code,
		lbs_haz_actual,
		lbs_haz_estimated,
		gal_haz_actual,
		gal_haz_estimated,
		yard_haz_actual,
		yard_haz_estimated,
		container_percent,
		approval_code,
		waste_density,
		generator_id,
		CASE WHEN LEFT(generator_epa_id, 5) = 'CESQG' 
			THEN LEFT(generator_state + generator_epa_id + space(12), 12)
			ELSE LEFT(generator_epa_id + space(12), 12) END as generator_epa_id,
		generator_name,
		generator_address_1,
		generator_address_2,
		generator_address_3,
		generator_address_4,
		generator_address_5,
		generator_city,
		generator_state,
		generator_zip_code,
		generator_state_id --,
		--transporter_EPA_ID,
		--transporter_name,
		--transporter_addr1,
		--transporter_addr2,
		--transporter_addr3,
		--transporter_city,
		--transporter_state,
		--transporter_zip_code,
		--TSDF_EPA_ID,
		--TSDF_name,
		--TSDF_addr1,
		--TSDF_addr2,
		--TSDF_addr3,
		--TSDF_city,
		--TSDF_state,
		--TSDF_zip_code		
	FROM #tmp_container_IB


	if @debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Finished EQAI Inserts to Source Table' as description

	UPDATE EQ_Extract..BiennialLog SET
		run_ended = getdate()
	where biennial_id = @biennial_id

	
	UPDATE EQ_Extract..ILAnnualNonHazReport
    SET    generator_state_id = state_id
    FROM   GeneratorStateId genstate  (nolock)
    WHERE  EQ_Extract..ILAnnualNonHazReport.eq_generator_id = genstate.generator_id
           AND EQ_Extract..ILAnnualNonHazReport.biennial_id = @biennial_id 
           -- AND generator_state_id is null -- ?
    
    
	/*
		fix the cesqg generator codes to be correct based on waste profile id
	*/
	if @debug > 1 print 'Fixing CESQG Generator Codes...'	
	UPDATE EQ_Extract..ILAnnualNonHazReport
	SET    generator_epa_id = EQ_Extract.dbo.fn_space_delimit('20', replace(tmp_g.generator_state + 'CESQG' + convert(VARCHAR(20), tmp_g.generator_id), ' ', ''))
	FROM   EQ_Extract..ILAnnualNonHazReport src  (nolock)
		   INNER JOIN ProfileQuoteApproval pqa
			 ON pqa.approval_code = src.approval_code
				AND pqa.company_id = src.Company_id
				AND pqa.profit_ctr_id = src.profit_ctr_id
		   INNER JOIN Profile p
			 ON pqa.profile_id = p.profile_id
		   INNER JOIN Generator tmp_g
			 ON tmp_g.generator_id = p.generator_id
	WHERE  src.biennial_id = @biennial_id
		   AND RTRIM(LTRIM(src.generator_epa_id)) LIKE '%CESQG' 

	if @debug > 1 print 'Verifying estimated weights are never empty when actuals are available...'
	/* make sure the estimated weights are correct */
	UPDATE EQ_Extract..ILAnnualNonHazReport
    SET    lbs_haz_estimated = lbs_haz_actual
    WHERE  ISNULL(lbs_haz_estimated, 0) = 0 AND ISNULL(lbs_haz_actual, 0) <> 0
    and biennial_id = @biennial_id
    
	UPDATE EQ_Extract..ILAnnualNonHazReport
    SET    gal_haz_estimated = gal_haz_actual
    WHERE  ISNULL(gal_haz_estimated, 0) = 0 AND ISNULL(gal_haz_actual, 0) <> 0
    and biennial_id = @biennial_id
    
	UPDATE EQ_Extract..ILAnnualNonHazReport
    SET    yard_haz_estimated = yard_haz_actual
    WHERE  ISNULL(yard_haz_estimated, 0) = 0 AND ISNULL(yard_haz_actual, 0) <> 0        
    and biennial_id = @biennial_id
    
				

	if @is_new_run = 'T'	
		SELECT @biennial_id	as biennial_id
		


GO
GRANT EXECUTE ON sp_reports_annual_illinois_nonhaz_source TO EQWEB
GO
GRANT EXECUTE ON sp_reports_annual_illinois_nonhaz_source TO EQAI
GO
GRANT EXECUTE ON sp_reports_annual_illinois_nonhaz_source TO COR_USER
GO
