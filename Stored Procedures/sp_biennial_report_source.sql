-- if exists (select 1 from sysobjects where name = 'sp_biennial_report_source') drop PROC sp_biennial_report_source
go

CREATE PROC sp_biennial_report_source (
	@biennial_id	int = null, -- if not specified, will create a new run
	@Company	varchar(5),	-- '2|21, 25|00' etc.
	@start_date datetime,
	@end_date datetime,
	@user_code	varchar(10), -- 'JONATHAN' (or SYSTEM_USER)
	@debug	int = 0
)
AS
/* ***********************************************************
Procedure    : sp_biennial_report_source
Database     : PLT_AI
Created      : Feb 14 2011 - Jonathan Broome
Description  : Populates EQ_Extract source tables for biennial reports
Examples:
	-- OHIO, 2010
	sp_biennial_report_source NULL, '45|00', '6/1/2018', '6/30/2018', 'JONATHAN'
	SELECT management_code, * FROM EQ_Extract..BiennialReportSourceData where biennial_id = 2424
	-- 3933 rows in dev, id 2012 - jan 18
	-- 3933 rows in prod, id 2423 - jan 18
	-- 3507 rows in dev, id 2013 - jun 18
	-- 3508 rows in prod, id 2424 - jun 18
	 and yard_haz_estimated <> yard_haz_actual

SELECT management_code, * FROM EQ_Extract..BiennialReportSourceData where biennial_id = 2424 and receipt_id = 603390

SELECT  *  FROM    Receipt WHERE receipt_id = 603390 and line_id = 4 and company_id = 45
SELECT  *  FROM    Container WHERE receipt_id = 603390 and line_id = 4 and company_id = 45
SELECT * FROM EQ_Extract..BiennialReportSourceData where biennial_id = 2424 and receipt_id = 603389 

SELECT  *  FROM    Receipt WHERE receipt_id = 603389 and company_id = 45

SELECT  *  FROM    Treatment WHERE treatment_id in (1087,1428) and company_id = 45

SELECT  *  FROM    ContainerDestination
WHERE receipt_id = 603389 and company_id = 45 and line_id = 4

	SELECT top 100 gal_haz_estimated, gal_haz_actual, company_id, profit_ctr_id, receipt_id, line_id FROM EQ_Extract..BiennialReportSourceData where gal_haz_estimated <> gal_haz_actual
		and gal_haz_actual <> 0

SELECT * FROM receipt where receipt_id= 57684 and line_id=2 and company_id = 25
SELECT * FROM receiptprice where receipt_id= 57684 and line_id=2 and company_id = 25
-- ReceiptPrice: CYB: 6

-- YPC:  0.84775.  Manifest QTY 10173 (P).  Bill unit P to Y conv:  0.0005
-- select 0.0005 * 10173 -- 5.0865
-- Does seem like manifest qty * pound -> yard conversion would be more appropriate here
-- instead, we go with billing CYB qty of 6.


	-- ILLINOIS, 2010
	sp_biennial_report_source NULL, '26|00', '2010', 'JONATHAN'
	SELECT * FROM EQ_Extract..BiennialReportSourceData where biennial_id = 45
	
	sp_biennial_report_source NULL, '22|0', '1/1/2011','12/31/2011', 'JONATHAN'
	sp_biennial_report_source NULL, '25|0', '1/1/2011','1/31/2011', 'JONATHAN'
	sp_biennial_report_source NULL, '26|0', '1/1/2011','12/31/2011', 'JONATHAN'
	sp_biennial_report_source NULL, '27|0', '1/1/2011','12/31/2011', 'JONATHAN', 1
	-- 53.42
	
	sp_biennial_report_source NULL, '41|0', '1/1/2015','12/31/2015', 'JONATHAN', 0 -- 1820
	sp_biennial_report_source NULL, '21|0', '6/1/2013','12/31/2013', 'JONATHAN', 0 -- 1821

	sp_biennial_report_source NULL, '29|00', '1/1/2013', '12/31/2013', 'JONATHAN'
	SELECT * FROM EQ_Extract..BiennialReportSourceData where biennial_id = 1854
	SELECT * FROM EQ_Extract..BiennialReportSourceWasteCode where biennial_id = 1854

select max(biennial_id) from EQ_Extract..BiennialReportSourceData
use eq_extract
sp_help BiennialReportSourceData
select * from EQ_Extract..BiennialReportSourceData where biennial_id = 1820 and receipt_id = 929573
select * from EQ_Extract..BiennialReportSourceData where biennial_id = 1821 and receipt_id = 929573

create index idx_tmp2 on BiennialReportSourceData  (biennial_id, receipt_id, line_id, company_id, profit_ctr_id, lbs_haz_actual)

SELECT orig.lbs_haz_actual as orig_method_lbs, new.lbs_haz_actual as new_method_lbs, orig.* FROM EQ_Extract..BiennialReportSourceData orig (nolock) 
left outer join EQ_Extract..BiennialReportSourceData new (nolock) on 
orig.biennial_id = 1820 and new.biennial_id = 1821
and orig.receipt_id = new.receipt_id and orig.line_id = new.line_id 
and orig.container_id = new.container_id
-- and orig.sequence_id = new.sequence_id
and orig.company_id = new.company_id and orig.data_source = new.data_source
where
orig.lbs_haz_actual <> new.lbs_haz_actual
and orig.lbs_haz_actual >= 1 and new.lbs_haz_actual >= 1
and orig.lbs_haz_actual not between new.lbs_haz_actual * 0.9 and new.lbs_haz_actual * 1.1
and orig.receipt_id = 960481 and orig.company_id = 21 and orig.line_id = 1

-- nnn rows out of 264,365 total were now different.

-- So now let's run the data "fix" for weights.


SELECT line_weight, bill_unit_code, container_count, * FROM receipt where receipt_id = 960481 and company_id = 21 and line_id = 1
SELECT * FROM receiptprice where receipt_id = 960481 and company_id = 21 and line_id = 1 
SELECT * FROM container where receipt_id = 960481 and company_id = 21 and line_id = 1 

and container_id = 2
	
	sp_biennial_report_source NULL, '22|0', '1/1/2013','5/31/2013', 'JONATHAN', 0 -- 1846
	sp_biennial_report_source NULL, '22|0', '1/1/2013','5/31/2013', 'JONATHAN', 0 -- 1847
	
	
SELECT orig.lbs_haz_actual as orig_method_lbs, new.lbs_haz_actual as new_method_lbs, orig.* FROM EQ_Extract..BiennialReportSourceData orig
left outer join EQ_Extract..BiennialReportSourceData new on orig.receipt_id = new.receipt_id and orig.line_id = new.line_id and orig.company_id = new.company_id and orig.data_source = new.data_source
where
orig.biennial_id = 1846 
and new.biennial_id = 1847
and orig.lbs_haz_actual not between new.lbs_haz_actual - 1 and new.lbs_haz_actual + 1

select count(*) from EQ_Extract..BiennialReportSourceData where biennial_id = 1822
select count(*) from EQ_Extract..BiennialReportSourceData where biennial_id = 1823


SELECT TOP 10 * FROM EQ_Extract..BiennialReportSourceData a where a.biennial_id = 1844


SELECT count(*) FROM EQ_Extract..BiennialReportSourceWasteCode where biennial_id = 	1569 -- 20794772
	and source_rowid is null -- 594

SELECT * FROM  	EQ_Extract..BiennialReportSourceWasteCode where biennial_id = 	1569 -- 20794772
	and source_rowid is null -- 594

		
EXEC sp_biennial_report_source NULL, '27|0', '03/01/2011', '3/30/2011', 'JASON_B'
	SELECT * FROM EQ_Extract..BiennialReportSourceData where biennial_id = 1121 AND receipt_id = 43836

IL: 1452 - 2:44s (Jan only)
IL: 1453 - 8:44s (2011)
	
	-- just for grins... how long to validate that?
	sp_biennial_validate 1316
	
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
	2/26/2012 - JPB - Changed joins for Treatments to use Container then Receipt then PQA.
	2/27/2012 - JPB - Found where OB weights to non EQ TSDFs were not calculating est. weight like act. weight and it
		was throwing off calculations afterward.  Fixed.
	2/28/2012 - JPB - Changed selection of outbound management_codes to use receipt first, then approval if necessary.
	2/29/2012 - JPB - Changed OB receipts to EQ facilities' management code logic: Take it from the OB receipt first,
		fall back to EQ profile 2nd.  Was prefering EQ Profile (no OB receipt option on OB's to EQ facilities), but
		there seems to be bad data in the approval/treatment/management setup that some facilities (PA) have been fixing
		by updating the OB receipt with the correct management code after it's been sent.  That's what the OB receipt's
		manifest_management_code field is FOR, so it's ok, but we'd rather have good data on the approval/treatment side.
		At this point it's too late to fix the approval setup, so we offer this.
	3/16/2012 - JPB - Changed waste_desc source for Outbound Receipts to EQ Facilities - now uses the EQ Fac's profile's
		related wastetype descrption, instead of the less good profile.approval_desc.
		Also tied in new biennial_description column from wastetype to get clean versions of descriptions.
	01/09/2014	JPB		Modified weight formula to this:

						The new simplified weight logic would be:

						1.	Container weight (Inbound reporting only)
						2.	Line Weight
						3.	Manifested in LBS or TONS
						4.	Manifested Unit (not lbs/tons) Converted to pounds
						5.	Billed Unit (not lbs/tons) converted to pounds

						We found the currently requested methods below - #1, 2, 3 & 5 are all equivalent, so we can simplify them to just use line weight.

						Previously Requested Total Pounds & Weight Method (uses the following logic to assign)
						1.            If a line weight was recorded, report line weight.  
						2.            If a net weight was recorded and the receipt only had 1 line, report the net weight.  
						3.            If receipt was billed in pounds report pounds billed.  
						4.            If waste was manifested in pounds, report the manifest quantity.  
						5.            If the receipt was billed in tons, report the billed tons, converted to pounds.  
						6.            If receipt was manifested in a unit convertible to pounds (Gallons, Yards, etc.), report converted pounds.  
						7.            If the billing unit is convertible to pounds, report converted pounds

	02/20/2014	JPB		Waste Code Updates - joins on waste_code_uid now, retrieves WasteCode.display_name
						Only includes waste codes with WasteCode.status = 'A'
	08/08/2014	JPB		Converted weight & volume calculations to function calls for consistency with other reports
	01/21/2016	JPB		Added @int_* variables to avoid parameter sniffing slowness
	01/29/2016  JPB		The last idiot to modify this file replaced @end_date with @int_start_date.  Fixed it.  Yelled at him.					
	2/13/2019	JPB		Replaced TreatmentHeader joins with Treatment (view) joins, and added company_id/profit_ctr_id conditions to join clauses
						this was to get management_code values from the view which are correct, instead of the header, which are not.

*********************************************************** */
-- Avoid parameter sniffing.
	declare 
	@int_biennial_id	int = @biennial_id,
	@int_Company	varchar(5) = @company,
	@int_start_date datetime = @start_date,
	@int_end_date datetime = @end_date,
	@int_user_code	varchar(10) = @user_code,
	@int_debug	int = @debug

-- Setup
	declare @starttime datetime = getdate()


	
	DECLARE @is_new_run char(1) = 'F'
	if @int_biennial_id is null set @is_new_run = 'T'


	-- Holder for the current run id, run_start
	DECLARE @date_added datetime = getdate()

	-- Log the current run
	insert EQ_Extract..BiennialLog
	select 
		COALESCE(@int_biennial_id, (select isnull(max(biennial_id), 0) + 1 from EQ_Extract..BiennialLog (nolock))) as biennial_id,
		@int_company,
		@int_start_date,
		@int_end_date,
		@int_user_code,
		@date_added,
		@date_added,
		null,
		null

	if @int_biennial_id is null
	begin
		-- Capture the current run id		
		select TOP 1
			@int_biennial_id = biennial_id 
		from EQ_Extract..BiennialLog (nolock)
		where added_by = @int_user_code
			and date_added = @date_added
	end

	if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Start' as description
	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Starting sp_biennial_report_source: ' + @int_Company + ', ' + convert(varchar(20), @int_start_date) + ' - ' + convert(varchar(20), @int_end_date) + ', ' + @int_user_code)
		
	
	-- Waste Density
	DECLARE @waste_density varchar(6) = '8.3453'
		, @water_density float = 8.34543

	-- Data Source
	DECLARE @data_source varchar(10) = 'EQAI'

	set @int_end_date = DATEADD(DAY, 1, @int_end_date)
	set @int_end_date = DATEADD(s,-1,@int_end_date)
	
	-- Convert @Year int to a start_date and end_date
	--DECLARE @int_start_date datetime, @int_start_date datetime
	
	--if @year < 1900 or @year > convert(int, datepart(yyyy, getdate())) RETURN
	--select 
	--	@int_start_date = convert(datetime, '1/1/' + convert(varchar(4), @year)),
	--	@int_start_date = dateadd(ms, -3, dateadd(yyyy, 1, @int_start_date))
		
	
	if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Biennial Log Run Config' as description
	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Setup Finished')
	
-------------------------------------------------------------------------------------------------------
-- **  N E X T   T I M E  R E V I E W   T H E S E   N O T E S    F R O M   T H E   A U D I T
--
--    Use manifested quantity instead of billing conversion if available on Outbounds - our numbers were to high.
-- JPB Did this 2/14/2011.
--  ***Fix the loop for outbound weights - wasn't getting the weight of all of the products that went into the outbound consolidated container
-- JPB Did this 2/14/2011.
--
-------------------------------------------------------------------------------------------------------
-- Step 1 - Run this after you check for missing treatment methods and EPA form codes.
--
-- The purpose of this script is to generate the data required for the 2009 Biennial Report to the EPA
--
-- Remember to change the year globally on this  for each reporting year.
--
-- Notes:  Source code not needed for Inbound only needed for Outbound and all outbound source codes for Tampa are 'G61'
--         Form codes need populated on Inbound approvals
--         Management codes need populated on Treatment Header and Outbound Approvals.
-------------------------------------------------------------------------------------------------------

	-- Get run id's
	DECLARE @int_company_id int,
			@profit_ctr_id int,
			@profit_ctr_epa_id varchar(20)
		
	SELECT @int_company_id = convert(int, Rtrim(Ltrim(Substring(row, 1, Charindex('|', row) - 1)))),
		@profit_ctr_id = convert(int, Rtrim(Ltrim(Substring(row, Charindex('|', row) + 1, Len(row) - (Charindex('|', row) - 1)))))
	FROM dbo.fn_splitxsvtext(',', 1, @int_company) WHERE Isnull(row, '') <> ''
	
	SELECT @profit_ctr_epa_id = epa_id from ProfitCenter (nolock) where company_id = @int_company_id and profit_ctr_id = @profit_ctr_id

------------------------
-- Inbound Receipts
------------------------

-- Get the weights on the Inbound containers
	select DISTINCT
		@int_biennial_id as biennial_id, 
		Container.Company_id,
		Container.profit_ctr_id,
		Container.receipt_id,
		Container.line_id,
		Container.container_id,
		ContainerDestination.sequence_id,
		Treatment.treatment_id,
		UPPER(CONVERT(VARCHAR(4), Treatment.management_code)) AS management_code,

		lbs_haz_actual =  convert(float, dbo.fn_receipt_weight_container (
			Container.receipt_id
			,Container.line_id
			,Container.profit_ctr_id
			,Container.Company_id
			,Container.container_id
			,ContainerDestination.sequence_id
		)),
		lbs_haz_estimated = convert(float, 00.0000),

		gal_haz_actual =  convert(float, dbo.fn_receipt_volume_container (
			Container.receipt_id
			,Container.line_id
			,Container.profit_ctr_id
			,Container.Company_id
			,Container.container_id
			,ContainerDestination.sequence_id
			, 'G', 'GAL'
		)),
		gal_haz_estimated =convert(float, 00.0000), /* calculated below if this is empty */
		
		yard_haz_actual =  convert(float, dbo.fn_receipt_volume_container (
			Container.receipt_id
			,Container.line_id
			,Container.profit_ctr_id
			,Container.Company_id
			,Container.container_id
			,ContainerDestination.sequence_id
			, 'Y', 'CYB, YARD'
		)),
		yard_haz_estimated = convert(float, 00.0000),
		
		IsNull(ContainerDestination.container_percent,0) as container_percent,
		UPPER(CONVERT(VARCHAR(15), Receipt.manifest)) as manifest,
		UPPER(CONVERT(CHAR(1), Receipt.manifest_line_id)) AS manifest_line_id,
		UPPER(CONVERT(VARCHAR(15), Receipt.approval_code)) AS approval_code,
		UPPER(CONVERT(VARCHAR(4), profile.EPA_form_code)) as EPA_form_code, 
		-- 2/14/2011 - JPB commented the G61 stuff out.
		--Isnull(UPPER(CONVERT(VARCHAR(3), profile.EPA_Source_code)),CONVERT(VARCHAR(3), 'G61')) AS EPA_source_code,  --- Not sure if G61 should be here that is for outbound but inbound isn't used anyway - LT
		UPPER(CONVERT(VARCHAR(3), profile.EPA_Source_code)) AS EPA_source_code,
		UPPER(CONVERT(VARCHAR(50), IsNull(COALESCE(wastetype.category+' '+coalesce(wastetype.biennial_description, wastetype.description), profile.approval_desc),''))) AS waste_desc,
		UPPER(CONVERT(VARCHAR(50), COALESCE(
			case when isnull(profileLab.specific_gravity,0) <> 0 then profileLab.specific_gravity * @water_density else null end
			, case when isnull(profileLab.density, 0) <> 0 then profileLab.density else null end
			, @waste_density
			))) as waste_density,
		cast(NULL as varchar(20)) as consistency,
		Generator.generator_id as generator_id,
		UPPER(CONVERT(VARCHAR(12), LTRIM(RTRIM(coalesce(nullif(Generator.EPA_FC_ID, ''), nullif(Generator.EPA_ID,''), ''))))) as generator_epa_id,
		UPPER(CONVERT(VARCHAR(40), Generator.generator_name)) AS generator_name,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_1,''))) AS generator_address_1,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_2,''))) AS generator_address_2,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_3,''))) AS generator_address_3,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_4,''))) AS generator_address_4,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_5,''))) AS generator_address_5,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_city,''))) AS generator_city,
		UPPER(CONVERT(VARCHAR(2), IsNull(Generator.generator_state,''))) AS generator_state,
		UPPER(CONVERT(VARCHAR(15), IsNull(Generator.generator_zip_code,''))) AS generator_zip_code,
		UPPER(CONVERT(VARCHAR(3), IsNull(lfs_gen.epa_country_code,''))) AS generator_country,
		UPPER(CONVERT(VARCHAR(20), IsNull(Generator.state_id,''))) AS generator_state_id,
		UPPER(CONVERT(VARCHAR(12), Transporter.transporter_EPA_ID)) AS transporter_EPA_ID,
		UPPER(CONVERT(VARCHAR(40), Transporter.transporter_name)) AS transporter_name,
		UPPER(CONVERT(VARCHAR(40), Transporter.transporter_addr1)) AS transporter_addr1,
		UPPER(CONVERT(VARCHAR(40), Transporter.transporter_addr2)) AS transporter_addr2,
		UPPER(CONVERT(VARCHAR(40), Transporter.transporter_addr3)) AS transporter_addr3,
		UPPER(CONVERT(VARCHAR(40), IsNull(Transporter.transporter_city,''))) AS transporter_city,
		UPPER(CONVERT(VARCHAR(2), IsNull(Transporter.transporter_state,''))) AS transporter_state,
		UPPER(CONVERT(VARCHAR(15), IsNull(Transporter.transporter_zip_code,''))) AS transporter_zip_code,
		UPPER(CONVERT(VARCHAR(10), IsNull(lfs_tra.epa_country_code,''))) AS transporter_country,
		UPPER(CONVERT(VARCHAR(12), coalesce(nullif(TSDF.epa_fc_id,''), nullif(TSDF.TSDF_EPA_ID,'')))) AS TSDF_EPA_ID,
		UPPER(CONVERT(VARCHAR(40), TSDF.TSDF_name)) AS TSDF_name,
		UPPER(CONVERT(VARCHAR(40), TSDF.TSDF_addr1)) AS TSDF_addr1,
		UPPER(CONVERT(VARCHAR(40), TSDF.TSDF_addr2)) AS TSDF_addr2,
		UPPER(CONVERT(VARCHAR(40), TSDF.TSDF_addr3)) AS TSDF_addr3,
		UPPER(CONVERT(VARCHAR(40), IsNull(TSDF.TSDF_city,''))) AS TSDF_city,
		UPPER(CONVERT(VARCHAR(2), IsNull(TSDF.TSDF_state,''))) AS TSDF_state,
		UPPER(CONVERT(VARCHAR(15), IsNull(TSDF.TSDF_zip_code,''))) AS TSDF_zip_code,
		UPPER(CONVERT(VARCHAR(3), IsNull(lfs_tsd.epa_country_code,''))) AS TSDF_country
	INTO #tmp_container_IB
	FROM Receipt (nolock)
		JOIN Container (nolock) ON (Receipt.company_id = Container.company_id 
			AND Receipt.profit_ctr_id = Container.profit_ctr_id 
			AND Receipt.receipt_id = Container.receipt_id 
			AND Receipt.line_id = Container.line_id
			AND Receipt.profit_ctr_id = Container.profit_ctr_id
			AND Receipt.company_id = Container.company_id)
		JOIN ContainerDestination (nolock)  ON (Container.company_id = ContainerDestination.company_id
			AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
			AND Container.receipt_id = ContainerDestination.receipt_id 
			AND Container.line_id = ContainerDestination.line_id
			AND Container.container_id = ContainerDestination.container_id)
		JOIN Profile  (nolock) ON (Receipt.profile_id = Profile.Profile_id)
		JOIN ProfileQuoteApproval PQA (nolock) ON (Receipt.approval_code = PQA.approval_code
			AND Receipt.profit_ctr_id = PQA.profit_ctr_id
			AND Receipt.company_id = PQA.company_id)
		JOIN Treatment Treatment (nolock)  ON (
			CASE WHEN ISnull(ContainerDestination.treatment_id,0) <> 0 
				THEN ISnull(ContainerDestination.treatment_id,0)
				ELSE
					CASE WHEN ISnull(Receipt.treatment_id,0) <> 0 
						THEN ISnull(Receipt.treatment_id,0) 
						ELSE
							isnull(PQA.Treatment_ID, 0)
					END
			END = Treatment.treatment_id 
			AND CASE WHEN ISnull(ContainerDestination.treatment_id,0) <> 0 
				THEN ISnull(ContainerDestination.company_id,0)
				ELSE
					CASE WHEN ISnull(Receipt.treatment_id,0) <> 0 
						THEN ISnull(Receipt.company_id,0) 
						ELSE
							isnull(PQA.company_id, 0)
					END
			END = Treatment.company_id 
			AND CASE WHEN ISnull(ContainerDestination.treatment_id,0) <> 0 
				THEN ISnull(ContainerDestination.profit_ctr_id,0)
				ELSE
					CASE WHEN ISnull(Receipt.treatment_id,0) <> 0 
						THEN ISnull(Receipt.profit_ctr_id,0) 
						ELSE
							isnull(PQA.profit_ctr_id, 0)
					END
			END = Treatment.profit_ctr_id 
			)
		JOIN WasteType (nolock)  ON (Profile.wastetype_id = WasteType.wastetype_id)
		JOIN Generator  (nolock) ON (Receipt.generator_id = Generator.generator_id)
		JOIN Transporter (nolock)  ON (Receipt.hauler = Transporter.transporter_code)
		JOIN ProfitCenter  (nolock) ON (Receipt.company_id = ProfitCenter.company_id
			AND Receipt.profit_ctr_id = ProfitCenter.profit_ctr_id)
		JOIN TSDF (nolock) ON TSDF.eq_company = Receipt.company_id
			AND TSDF.eq_profit_ctr = Receipt.profit_ctr_id
			AND ISNULL(TSDF.eq_flag, 'F') = 'T'
			AND TSDF.tsdf_status = 'A'
		JOIN ProfileLab (nolock) ON receipt.profile_id = ProfileLab.profile_id
			AND ProfileLab.type = 'A'
		LEFT JOIN StateAbbreviation lfs_gen
			ON Generator.generator_country = lfs_gen.country_code 
			and Generator.generator_state = lfs_gen.abbr
		LEFT JOIN StateAbbreviation lfs_tra
			ON Transporter.transporter_country = lfs_tra.country_code 
			and Transporter.transporter_state = lfs_tra.abbr
		LEFT JOIN StateAbbreviation lfs_tsd
			ON TSDF.tsdf_country_code = lfs_tsd.country_code 
			and TSDF.tsdf_state = lfs_tsd.abbr
	WHERE 
		Container.company_id = @int_company_id
		AND Container.profit_ctr_id = @profit_ctr_id
		AND Container.status = 'C'
		AND ContainerDestination.status = 'C'
		AND Container.container_type = 'R'
		AND Receipt.trans_mode = 'I'
		AND Receipt.trans_type = 'D'
		AND Receipt.receipt_status = 'A'
		AND Receipt.fingerpr_status = 'A'
		-- AND Receipt.data_complete_flag = 'T' -- 2021/01/13 - This flag is causing problems.
		-- AND Receipt.manifest_flag <> 'B'
		AND Receipt.manifest_flag in ('M', 'B') -- 1/30/2020 
		AND (Receipt.receipt_date >= @int_start_date AND Receipt.receipt_date <= @int_end_date)
		AND (
			EXISTS (
				SELECT 1
				FROM ContainerWasteCode CW (NOLOCK) 
				Join WasteCode  (nolock) 
					on CW.waste_code_uid = WasteCode.waste_code_uid
					And WasteCode.status = 'A'
					AND WasteCode.waste_code_origin = 'F'
					AND IsNull(WasteCode.haz_flag,'F') = 'T'
				WHERE ContainerDestination.company_id = CW.company_id 
				AND ContainerDestination.profit_ctr_id = CW.profit_ctr_id
				AND ContainerDestination.receipt_id = CW.receipt_id
				AND ContainerDestination.line_id = CW.line_id
				AND ContainerDestination.container_id = CW.container_id
				AND ContainerDestination.sequence_id = CW.sequence_id
			)
			OR 
			EXISTS (
				SELECT 1 
				FROM ReceiptWasteCode RWC (NOLOCK) 
				Join WasteCode  (nolock) 
					on RWC.waste_code_uid = WasteCode.waste_code_uid
					AND WasteCode.waste_code_origin = 'F'
					AND IsNull(WasteCode.haz_flag,'F') = 'T'
					And WasteCode.status = 'A'
				WHERE ContainerDestination.company_id = RWC.company_id 
				AND ContainerDestination.profit_ctr_id = RWC.profit_ctr_id
				AND ContainerDestination.receipt_id = RWC.receipt_id
				AND ContainerDestination.line_id = RWC.line_id
				AND Not EXISTS (
					SELECT 1 
					FROM ContainerWasteCode CW (NOLOCK) 
					Join WasteCode  (nolock) 
						on CW.waste_code_uid = WasteCode.waste_code_uid
						And WasteCode.status = 'A'
					WHERE ContainerDestination.company_id = CW.company_id 
					AND ContainerDestination.profit_ctr_id = CW.profit_ctr_id
					AND ContainerDestination.receipt_id = CW.receipt_id
					AND ContainerDestination.line_id = CW.line_id
					AND ContainerDestination.container_id = CW.container_id
					AND ContainerDestination.sequence_id = CW.sequence_id
				)
			)
		)
/*
	ORDER BY
		Container.company_id,
		Container.profit_ctr_id,
		Container.receipt_id,
		Container.line_id,
		Container.container_id,
		ContainerDestination.sequence_id
*/

	if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Finished Inserting Inbound Receipts' as description
	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(),  'Finished Inserting Inbound Receipts')

-- Update lbs_haz_actual where it's 0 to a worse calculation of weight.
update #tmp_container_IB SET
	lbs_haz_actual =
		coalesce(
			CASE WHEN ISNULL(receipt.line_weight, 0) > 0 
				THEN (receipt.line_weight / receipt.container_count) * (IsNull(ContainerDestination.container_percent, 0) / 100.000)
			END,
			CASE WHEN EXISTS (SELECT 1 FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code IN('LBS','TONS')
				) 
			THEN (
				SELECT 
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
		)
from #tmp_container_IB ib
INNER JOIN Container container (nolock) 
	ON ib.company_id = Container.Company_id
	AND	ib.profit_ctr_id = Container.profit_ctr_id
	AND	ib.receipt_id = Container.receipt_id
	AND	ib.line_id = Container.line_id
	AND	ib.container_id = Container.container_id
JOIN Receipt (nolock) ON (Receipt.company_id = Container.company_id 
	AND Receipt.profit_ctr_id = Container.profit_ctr_id 
	AND Receipt.receipt_id = Container.receipt_id 
	AND Receipt.line_id = Container.line_id)
JOIN ContainerDestination (nolock)  ON (Container.company_id = ContainerDestination.company_id
	AND Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.receipt_id = ContainerDestination.receipt_id 
	AND Container.line_id = ContainerDestination.line_id
	AND Container.container_id = ContainerDestination.container_id
	AND ib.sequence_id = ContainerDestination.sequence_id)
where isnull(lbs_haz_actual, 0) = 0

	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Updated #tmp_container_IB lbs_haz_actual weights')

-- Since the goal of the select was to make these values the same, just calculate them each one time
-- and set the estimated value = actual value here, it should be faster.
update #tmp_container_IB SET
	lbs_haz_estimated = lbs_haz_actual,
	gal_haz_estimated = gal_haz_actual,
	yard_haz_estimated = yard_haz_actual

-- fill in the "estimated" values for lbs, gal, yards
	SELECT DISTINCT
		Receipt.company_id,
		Receipt.profit_ctr_id,
		Receipt.receipt_id,
		Receipt.line_id,
		CASE WHEN isnull(
			(
			select receipt.manifest_quantity * billunit.pound_conv
			from billunit (nolock) where manifest_unit = Receipt.manifest_unit
			), 0) > 0 then
			(
			select receipt.manifest_quantity * billunit.pound_conv
			from billunit (nolock) where manifest_unit = Receipt.manifest_unit
			) / Receipt.container_count 
			else		
			IsNull(ReceiptPrice.bill_quantity,0) * IsNull(BillUnit.pound_conv,0) / Receipt.container_count
		end AS lbs_per_container,
		CASE WHEN isnull(
			(
			select receipt.manifest_quantity * billunit.gal_conv
			from billunit (nolock) where manifest_unit = Receipt.manifest_unit
			), 0) > 0 then
			(
			select receipt.manifest_quantity * billunit.gal_conv
			from billunit (nolock) where manifest_unit = Receipt.manifest_unit
			) / Receipt.container_count 
			else		
			IsNull(ReceiptPrice.bill_quantity,0) * IsNull(BillUnit.gal_conv,0) / Receipt.container_count 
		end AS gal_per_container,
		CASE WHEN isnull(
			(
			select receipt.manifest_quantity * billunit.yard_conv
			from billunit (nolock) where manifest_unit = Receipt.manifest_unit
			), 0) > 0 then
			(
			select receipt.manifest_quantity * billunit.yard_conv
			from billunit (nolock) where manifest_unit = Receipt.manifest_unit
			) / Receipt.container_count 
			else		
			IsNull(ReceiptPrice.bill_quantity,0) * IsNull(BillUnit.yard_conv,0) / Receipt.container_count 
		end AS yard_per_container
	INTO #tmp_calc_IB
	FROM Receipt (nolock)
		JOIN #tmp_container_IB (nolock)  ON (Receipt.company_id = #tmp_container_IB.company_id
			And Receipt.profit_ctr_id = #tmp_container_IB.profit_ctr_id
			AND Receipt.receipt_id = #tmp_container_IB.receipt_id
			AND Receipt.line_id = #tmp_container_IB.line_id
			AND Receipt.profit_ctr_id = #tmp_container_IB.profit_ctr_id
			AND Receipt.company_id = #tmp_container_IB.company_id)
		JOIN ReceiptPrice  (nolock) ON (Receipt.company_id = ReceiptPrice.company_id
			AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
			AND Receipt.receipt_id = ReceiptPrice.receipt_id
			AND Receipt.line_id = ReceiptPrice.line_id
			AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
			AND Receipt.company_id = ReceiptPrice.company_id)
		JOIN BillUnit (nolock)  ON (ReceiptPrice.bill_unit_code = BillUnit.bill_unit_code)

	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Created #tmp_calc_IB for estimated amounts')


	/* round the values */
	UPDATE #tmp_container_IB SET lbs_haz_actual = ROUND(ROUND(lbs_haz_actual, 4), 2),
	lbs_haz_estimated = ROUND(ROUND(lbs_haz_estimated, 4), 2),
	gal_haz_estimated = ROUND(ROUND(gal_haz_estimated, 4), 2),
	gal_haz_actual = ROUND(ROUND(gal_haz_actual, 4), 2),
	yard_haz_actual = ROUND(ROUND(yard_haz_actual, 4), 2),
	yard_haz_estimated = ROUND(ROUND(yard_haz_estimated, 4), 2)


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

	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Updated #tmp_container_IB to merge estimated weights in')


	-- BLANK OUT BAD EPA_IDs
		UPDATE #tmp_container_IB SET generator_epa_id = '' WHERE generator_epa_id IN ( 'N/A', '.', '....', 'NONE')
		UPDATE #tmp_container_IB SET transporter_epa_id = '' WHERE transporter_epa_id IN ( 'N/A', '.', '....', 'NONE')
		UPDATE #tmp_container_IB SET tsdf_epa_id = '' WHERE tsdf_epa_id IN ( 'N/A', '.', '....', 'NONE')
		
	if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Finished Weight Calculation' as description
	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Finished Weight Calculation')
	
------------------------
-- Outbound Receipts
------------------------
	
	-- These are the outbound Receipts
	-- from non-eq facilities
	select DISTINCT 
		@int_biennial_id as biennial_id,
		isnull(Receipt.company_id,0) as company_id,
		isnull(Receipt.profit_ctr_id,0) as profit_ctr_id,
		isnull(Receipt.receipt_id,0) as receipt_id,
		isnull(Receipt.line_id,0) as line_id,
		--isnull(Receipt.container_count,0) as container_count,
		--SUM(IsNull(ReceiptPrice.bill_quantity,0) * Coalesce(line_weight,(IsNull(BillUnit.pound_conv,0))) / Receipt.container_count AS lbs_per_container,
		-- 2011 - JPB replaced...
		-- lbs_haz_waste = Coalesce(Receipt.line_weight,SUM(IsNull(ReceiptPrice.bill_quantity,0)*(IsNull(BillUnit.pound_conv,0)))), 
		-- with ...
		/* the proper order for weights for OUTBOUND should go:
		1) manifested weight / container count
		2) NOT APPLICABLE to Outbound container weight * contairne_percent / 100
		3) line_weight / container count
		4) if billed in LBS or TONS / container count
		5) the rest can be calculated by ReceiptPrice.bill_unit * quantity * conversion factor in bill unit

		lbs_haz_actual = COALESCE
		(
			CASE WHEN receipt.manifest_unit = 'P' THEN receipt.manifest_quantity END,
			CASE WHEN ISNULL(dbo.fn_line_weight_or_better(receipt.receipt_id, receipt.line_id, receipt.company_id, receipt.profit_ctr_id, receipt.line_weight), 0) > 0 THEN dbo.fn_line_weight_or_better(receipt.receipt_id, receipt.line_id, receipt.company_id, receipt.profit_ctr_id, receipt.line_weight)  END,
			CASE WHEN EXISTS (SELECT 1 FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code IN('LBS','TONS')
			) THEN (SELECT 
						CASE 
							WHEN rp.bill_unit_code = 'LBS' THEN rp.bill_quantity 
							WHEN rp.bill_unit_code = 'TONS' THEN (rp.bill_quantity * 2000) 
						END 
				FROM ReceiptPrice rp (nolock)
				WHERE receipt.receipt_id = rp.receipt_id
				AND receipt.company_id = rp.company_id
				AND receipt.profit_ctr_id = rp.profit_ctr_id
				AND receipt.line_id = rp.line_id
				AND rp.bill_unit_code IN('LBS','TONS')
			)
				END
		),

		*/		
		
		lbs_haz_actual =  convert(float, dbo.fn_receipt_weight_line (
			receipt.receipt_id
			,receipt.line_id
			,receipt.profit_ctr_id
			,receipt.Company_id
		)),
		lbs_haz_estimated = convert(float, 00.0000),

		gal_haz_actual =  convert(float, dbo.fn_receipt_volume_line (
			receipt.receipt_id
			,receipt.line_id
			,receipt.profit_ctr_id
			,receipt.Company_id
			, 'G', 'GAL'
		)),
		gal_haz_estimated =convert(float, 00.0000), /* calculated below if this is empty */
		
		yard_haz_actual =  convert(float, dbo.fn_receipt_volume_line (
			receipt.receipt_id
			,receipt.line_id
			,receipt.profit_ctr_id
			,receipt.Company_id
			, 'Y', 'CYB, YARD'
		)),
		yard_haz_estimated = convert(float, 00.0000),
		0 as treatment_id,
		UPPER(CONVERT(VARCHAR(4),
			CASE WHEN ltrim(rtrim(isnull(Receipt.Manifest_Management_Code, ''))) = ''
				THEN IsNull(TSDFApproval.management_code,'')
				ELSE ltrim(rtrim(isnull(Receipt.Manifest_Management_Code, '')))
			END
		)) AS management_code,
		UPPER(CONVERT(VARCHAR(15), IsNull(Receipt.manifest,''))) as manifest,
		UPPER(CONVERT(CHAR(1), IsNull(Receipt.manifest_line_id,''))) AS manifest_line_id,
		--- null before here
		UPPER(CONVERT(VARCHAR(15), IsNull(Receipt.tsdf_approval_code,''))) AS approval_code,
		UPPER(CONVERT(VARCHAR(4), IsNull(TSDFApproval.EPA_form_code,''))) as EPA_form_code, 
		UPPER(CONVERT(VARCHAR(3), IsNull(TSDFApproval.EPA_source_code,''))) AS EPA_source_code,
		UPPER(CONVERT(VARCHAR(50), IsNull(COALESCE(TSDFApproval.waste_desc, WasteCode.waste_code_desc),''))) AS waste_desc,
		UPPER(CONVERT(VARCHAR(50), @waste_density)) as waste_density,
		cast(NULL as varchar(20)) as consistency,
		Generator.generator_id as generator_id,
		UPPER(CONVERT(VARCHAR(12), LTRIM(RTRIM(Coalesce(nullif(Generator.EPA_FC_ID,''), nullif(Generator.EPA_ID,''),''))))) as generator_epa_id,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_name,''))) AS generator_name,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_1,''))) AS generator_address_1,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_2,''))) AS generator_address_2,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_3,''))) AS generator_address_3,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_4,''))) AS generator_address_4,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_5,''))) AS generator_address_5,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_city,''))) AS generator_city,
		UPPER(CONVERT(VARCHAR(2), IsNull(Generator.generator_state,''))) AS generator_state,
		UPPER(CONVERT(VARCHAR(15), IsNull(Generator.generator_zip_code,''))) AS generator_zip_code,
		UPPER(CONVERT(VARCHAR(3), IsNull(lfs_gen.epa_country_code,''))) AS generator_country,
		UPPER(CONVERT(VARCHAR(20), IsNull(Generator.state_id,''))) AS generator_state_id,
		UPPER(CONVERT(VARCHAR(12), IsNull(Transporter.transporter_EPA_ID,''))) AS transporter_EPA_ID,
		UPPER(CONVERT(VARCHAR(40), IsNull(Transporter.transporter_name,''))) AS transporter_name,
		UPPER(CONVERT(VARCHAR(40), IsNull(Transporter.transporter_addr1,''))) AS transporter_addr1,
		UPPER(CONVERT(VARCHAR(40), IsNull(Transporter.transporter_addr2,''))) AS transporter_addr2,
		UPPER(CONVERT(VARCHAR(40), IsNull(Transporter.transporter_addr3,''))) AS transporter_addr3,
		UPPER(CONVERT(VARCHAR(40), IsNull(Transporter.transporter_city,''))) AS transporter_city,
		UPPER(CONVERT(VARCHAR(2), IsNull(Transporter.transporter_state,''))) AS transporter_state,
		UPPER(CONVERT(VARCHAR(15), IsNull(Transporter.transporter_zip_code,''))) AS transporter_zip_code,
		UPPER(CONVERT(VARCHAR(10), IsNull(lfs_tra.epa_country_code,''))) AS Transporter_country,
		UPPER(CONVERT(VARCHAR(12), Coalesce(nullif(TSDF.epa_fc_id,''), nullif(TSDF.TSDF_EPA_ID,''),''))) AS TSDF_EPA_ID,
		UPPER(CONVERT(VARCHAR(40), IsNull(TSDF.TSDF_name,''))) AS TSDF_name,
		UPPER(CONVERT(VARCHAR(40), IsNull(TSDF.TSDF_addr1,''))) AS TSDF_addr1,
		UPPER(CONVERT(VARCHAR(40), IsNull(TSDF.TSDF_addr2,''))) AS TSDF_addr2,
		UPPER(CONVERT(VARCHAR(40), IsNull(TSDF.TSDF_addr3,''))) AS TSDF_addr3,
		UPPER(CONVERT(VARCHAR(40), IsNull(TSDF.TSDF_city,''))) AS TSDF_city,
		UPPER(CONVERT(VARCHAR(2), IsNull(TSDF.TSDF_state,''))) AS TSDF_state,
		UPPER(CONVERT(VARCHAR(15), IsNull(TSDF.TSDF_zip_code,''))) AS TSDF_zip_code,
		UPPER(CONVERT(VARCHAR(3), IsNull(lfs_tsd.epa_country_code,''))) AS TSDF_country
	INTO #tmp_OB_Non_EQ
	FROM Receipt (nolock) 
		inner join ReceiptPrice  (nolock) on 
			Receipt.company_id = ReceiptPrice.company_id
			AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
			AND Receipt.receipt_id = ReceiptPrice.receipt_id
			AND Receipt.line_id = ReceiptPrice.line_id
		inner join BillUnit  (nolock) on  
			ReceiptPrice.bill_unit_code = BillUnit.bill_unit_code
		inner join TSDFApproval (nolock)  on 
			Receipt.TSDF_code = TSDFApproval.TSDF_code
			AND Receipt.tsdf_approval_code = TSDFApproval.tsdf_approval_code
			AND Receipt.waste_stream = TSDFApproval.waste_stream
			AND Receipt.profit_ctr_id = TSDFApproval.profit_ctr_id
			AND Receipt.company_id = TSDFApproval.company_id
		inner join  Generator (nolock) on 
			Receipt.generator_id = Generator.generator_id
		inner join TSDF  (nolock) on 
			TSDFApproval.TSDF_code = TSDF.TSDF_code
			AND TSDF.tsdf_status = 'A'
		left join  WasteCode (nolock) on 
			receipt.waste_code_uid = WasteCode.waste_code_uid
			And WasteCode.status = 'A'
		Left outer join Transporter (nolock)  on 
			Receipt.hauler = Transporter.transporter_code
		/*
		INNER JOIN ProfileLab ON receipt.profile_id = ProfileLab.profile_id
			and ProfileLab.type = 'A'
		*/			
		LEFT JOIN StateAbbreviation lfs_gen
			ON Generator.generator_country = lfs_gen.country_code 
			and Generator.generator_state = lfs_gen.abbr
		LEFT JOIN StateAbbreviation lfs_tra
			ON Transporter.transporter_country = lfs_tra.country_code 
			and Transporter.transporter_state = lfs_tra.abbr
		LEFT JOIN StateAbbreviation lfs_tsd
			ON TSDF.tsdf_country_code = lfs_tsd.country_code 
			and TSDF.tsdf_state = lfs_tsd.abbr
	WHERE 
		Receipt.profit_ctr_id = @profit_ctr_id 
		AND Receipt.company_id = @int_company_id
		AND Receipt.receipt_status = 'A'
		AND Receipt.trans_mode = 'O'
		AND Receipt.trans_type = 'D'
		AND Receipt.manifest_flag <> 'B'
		AND (Receipt.receipt_date >= @int_start_date AND Receipt.receipt_date <= @int_end_date)
		AND EXISTS (
			SELECT 
				1
			FROM ReceiptWasteCode RWC (nolock)
			Join WasteCode (nolock) 
				on RWC.waste_code_uid = WasteCode.waste_code_uid
				AND WasteCode.waste_code_origin = 'F'
				AND IsNull(WasteCode.haz_flag,'F') = 'T'
				And WasteCode.status = 'A'
			WHERE 
				Receipt.company_id = RWC.company_id
				AND Receipt.profit_ctr_id = RWC.profit_ctr_id
				AND Receipt.receipt_id = RWC.receipt_id
				AND Receipt.line_id = RWC.line_id
		)
	GROUP BY
		Receipt.company_id,
		Receipt.profit_ctr_id,
		Receipt.receipt_id,
		Receipt.line_id,

		Receipt.manifest_unit,
		Receipt.manifest_quantity,
		Receipt.container_count,
--		dbo.fn_line_weight_or_better(receipt.receipt_id, receipt.line_id, receipt.company_id, receipt.profit_ctr_id, receipt.line_weight),
		
		receipt.line_weight,
		
		
		Receipt.treatment_id,
		UPPER(CONVERT(VARCHAR(4),
			CASE WHEN ltrim(rtrim(isnull(Receipt.Manifest_Management_Code, ''))) = ''
				THEN IsNull(TSDFApproval.management_code,'')
				ELSE ltrim(rtrim(isnull(Receipt.Manifest_Management_Code, '')))
			END
		)),
		Receipt.manifest,
		Receipt.manifest_line_id,
		Receipt.tsdf_approval_code,
		TSDFApproval.EPA_form_code, 
		TSDFApproval.EPA_source_code,
		TSDFApproval.waste_desc,
		/* ProfileLab.density, */
		Generator.generator_id,
		WasteCode.waste_code_desc,
		Coalesce(nullif(Generator.EPA_FC_ID,''), nullif(Generator.EPA_ID,''),''),
		Generator.generator_name,
		Generator.generator_address_1,
		Generator.generator_address_2,
		Generator.generator_address_3,
		Generator.generator_address_4,
		Generator.generator_address_5,
		Generator.generator_city,
		Generator.generator_state,
		Generator.generator_zip_code,
		lfs_gen.epa_country_code,
		Generator.state_id,
		Transporter.transporter_EPA_ID,
		Transporter.transporter_name,
		Transporter.transporter_addr1,
		Transporter.transporter_addr2,
		Transporter.transporter_addr3,
		Transporter.transporter_city,
		Transporter.transporter_state,
		Transporter.transporter_zip_code,
		lfs_tra.epa_country_code,
		TSDF.epa_fc_id, 
		TSDF.TSDF_EPA_ID,
		TSDF.TSDF_name,
		TSDF.TSDF_addr1,
		TSDF.TSDF_addr2,
		TSDF.TSDF_addr3,
		TSDF.TSDF_city,
		TSDF.TSDF_state,
		TSDF.TSDF_zip_code,
		lfs_tsd.epa_country_code


	if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Finished Outbound Receipts' as description
	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Finished Outbound Receipts into #tmp_OB_Non_EQ')
	
	--select outbounded to EQ facilities
	select DISTINCT 
		@int_biennial_id as biennial_id,
		isnull(Receipt.company_id,0) as company_id,
		isnull(Receipt.profit_ctr_id,0) as profit_ctr_id,
		isnull(Receipt.receipt_id,0) as receipt_id,
		isnull(Receipt.line_id,0) as line_id,
		-- 2011 - JPB replaced...
		-- lbs_haz_waste = Coalesce(Receipt.line_weight,SUM(IsNull(ReceiptPrice.bill_quantity,0)*(IsNull(BillUnit.pound_conv,0)))),
		-- with ...
		/* the proper order for weights for OUTBOUND should go:
		1) manifested weight / container count
		2) NOT APPLICABLE to Outbound container weight * contairne_percent / 100
		3) line_weight / container count
		4) if billed in LBS or TONS / container count
		5) the rest can be calculated by ReceiptPrice.bill_unit * quantity * conversion factor in bill unit
		*/			
		lbs_haz_actual =  convert(float, dbo.fn_receipt_weight_line (
			Receipt.receipt_id
			,Receipt.line_id
			,Receipt.profit_ctr_id
			,Receipt.Company_id
		)),
		lbs_haz_estimated = convert(float, 00.0000),

		gal_haz_actual =  convert(float, dbo.fn_receipt_volume_line (
			Receipt.receipt_id
			,Receipt.line_id
			,Receipt.profit_ctr_id
			,Receipt.Company_id
			, 'G', 'GAL'
		)),
		gal_haz_estimated =convert(float, 00.0000), /* calculated below if this is empty */
		
		yard_haz_actual =  convert(float, dbo.fn_receipt_volume_line (
			Receipt.receipt_id
			,Receipt.line_id
			,Receipt.profit_ctr_id
			,Receipt.Company_id
			, 'Y', 'CYB, YARD'
		)),
		yard_haz_estimated = convert(float, 00.0000),
		--isnull(Receipt.container_count,0) as container_count,
		--SUM(IsNull(ReceiptPrice.bill_quantity,0) * IsNull(BillUnit.pound_conv,0)) / Receipt.container_count AS lbs_per_container,
		--assigned_container_count = IsNull((SELECT COUNT(*) FROM #tmp_container_OB WHERE #tmp_container_OB.profit_ctr_id = Receipt.profit_ctr_id
		--	AND #tmp_container_OB.receipt_id = Receipt.receipt_id AND #tmp_container_OB.line_id = Receipt.line_id),0),
		--assigned_container_weight = IsNull((SELECT SUM(isnull(lbs_haz_waste,0)) FROM #tmp_container_OB WHERE #tmp_container_OB.profit_ctr_id = Receipt.profit_ctr_id
		--	AND #tmp_container_OB.receipt_id = Receipt.receipt_id AND #tmp_container_OB.line_id = Receipt.line_id),0),
		--Receipt.treatment_id, LT removed this doesn't make sense
		treatment.treatment_id,
-- 2/29/2012 - late change and cover for some bad data... take the OB management code for an eq facility from the OB receipt first, or EQ profile 2nd.
--		UPPER(CONVERT(VARCHAR(4),IsNull(treatment.management_code,''))) AS management_code,
		UPPER(CONVERT(VARCHAR(4),
			CASE WHEN ltrim(rtrim(isnull(Receipt.Manifest_Management_Code, ''))) = ''
				THEN IsNull(treatment.management_code,'')
				ELSE ltrim(rtrim(isnull(Receipt.Manifest_Management_Code, '')))
			END
		)) AS management_code,
		UPPER(CONVERT(VARCHAR(15), IsNull(Receipt.manifest,''))) as manifest,
		UPPER(CONVERT(CHAR(1), IsNull(Receipt.manifest_line_id,''))) AS manifest_line_id,
		UPPER(CONVERT(VARCHAR(15), IsNull(Receipt.tsdf_approval_code,''))) AS approval_code,
		-- May need to work through the following two fields.
		UPPER(CONVERT(VARCHAR(4), IsNull(profile.EPA_form_code,''))) as EPA_form_code, 
		UPPER(CONVERT(VARCHAR(3), IsNull(Profile.EPA_source_code,''))) AS EPA_source_code, 
		UPPER(CONVERT(VARCHAR(50), IsNull(COALESCE(wastetype.category+' '+coalesce(wastetype.biennial_description, wastetype.description), profile.approval_desc),''))) AS waste_desc,
		UPPER(CONVERT(VARCHAR(50), @waste_density)) as waste_density,
		cast(NULL as varchar(20)) as consistency,
		Generator.generator_id as generator_id,
		UPPER(CONVERT(VARCHAR(12), LTRIM(RTRIM(Coalesce(nullif(Generator.EPA_FC_ID,''), nullif(Generator.EPA_ID,''),''))))) as generator_epa_id,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_name,''))) AS generator_name,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_1,''))) AS generator_address_1,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_2,''))) AS generator_address_2,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_3,''))) AS generator_address_3,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_4,''))) AS generator_address_4,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_address_5,''))) AS generator_address_5,
		UPPER(CONVERT(VARCHAR(40), IsNull(Generator.generator_city,''))) AS generator_city,
		UPPER(CONVERT(VARCHAR(2), IsNull(Generator.generator_state,''))) AS generator_state,
		UPPER(CONVERT(VARCHAR(15), IsNull(Generator.generator_zip_code,''))) AS generator_zip_code,
		UPPER(CONVERT(VARCHAR(3), IsNull(lfs_gen.epa_country_code,''))) AS generator_country,	
		UPPER(CONVERT(VARCHAR(20), IsNull(Generator.state_id,''))) AS generator_state_id,
		UPPER(CONVERT(VARCHAR(12), IsNull(Transporter.transporter_EPA_ID,''))) AS transporter_EPA_ID,
		UPPER(CONVERT(VARCHAR(40), IsNull(Transporter.transporter_name,''))) AS transporter_name,
		UPPER(CONVERT(VARCHAR(40), IsNull(Transporter.transporter_addr1,''))) AS transporter_addr1,
		UPPER(CONVERT(VARCHAR(40), IsNull(Transporter.transporter_addr2,''))) AS transporter_addr2,
		UPPER(CONVERT(VARCHAR(40), IsNull(Transporter.transporter_addr3,''))) AS transporter_addr3,
		UPPER(CONVERT(VARCHAR(40), IsNull(Transporter.transporter_city,''))) AS transporter_city,
		UPPER(CONVERT(VARCHAR(2), IsNull(Transporter.transporter_state,''))) AS transporter_state,
		UPPER(CONVERT(VARCHAR(15), IsNull(Transporter.transporter_zip_code,''))) AS transporter_zip_code,
		UPPER(CONVERT(VARCHAR(10), IsNull(lfs_tra.epa_country_code,''))) AS transporter_country,		
		UPPER(CONVERT(VARCHAR(12), Coalesce(nullif(TSDF.epa_fc_id,''), nullif(TSDF.TSDF_EPA_ID,''),''))) AS TSDF_EPA_ID,
		UPPER(CONVERT(VARCHAR(40), IsNull(TSDF.TSDF_name,''))) AS TSDF_name,
		UPPER(CONVERT(VARCHAR(40), IsNull(TSDF.TSDF_addr1,''))) AS TSDF_addr1,
		UPPER(CONVERT(VARCHAR(40), IsNull(TSDF.TSDF_addr2,''))) AS TSDF_addr2,
		UPPER(CONVERT(VARCHAR(40), IsNull(TSDF.TSDF_addr3,''))) AS TSDF_addr3,
		UPPER(CONVERT(VARCHAR(40), IsNull(TSDF.TSDF_city,''))) AS TSDF_city,
		UPPER(CONVERT(VARCHAR(2), IsNull(TSDF.TSDF_state,''))) AS TSDF_state,
		UPPER(CONVERT(VARCHAR(15), IsNull(TSDF.TSDF_zip_code,''))) AS TSDF_zip_code,
		UPPER(CONVERT(VARCHAR(3), IsNull(lfs_tsd.epa_country_code,''))) AS TSDF_country
	INTO #tmp_OB_EQ
	FROM Receipt (nolock)
		inner join ReceiptPrice  (nolock) 
			on  Receipt.company_id = ReceiptPrice.company_id
			AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
			AND Receipt.receipt_id = ReceiptPrice.receipt_id
			AND Receipt.line_id = ReceiptPrice.line_id
		inner join BillUnit  (nolock) 
			on  ReceiptPrice.bill_unit_code = BillUnit.bill_unit_code
	inner join profile profile (nolock) 
		on  Receipt.ob_profile_id = profile.profile_id
	inner join profilequoteapproval profilequoteapproval (nolock) 
		on  Receipt.ob_profile_id = profilequoteapproval.profile_id
		AND Receipt.ob_profile_company_id = profilequoteapproval.company_id
		AND Receipt.ob_profile_profit_ctr_id = profilequoteapproval.profit_ctr_id
		AND Receipt.tsdf_approval_code = profilequoteapproval.approval_code
	JOIN WasteType (nolock)  ON (Profile.wastetype_id = WasteType.wastetype_id)
	inner join  Generator  (nolock) 
		on  Receipt.generator_id = Generator.generator_id
	inner join tsdf  (nolock) 
		on  receipt.tsdf_code = tsdf.tsdf_code
		AND TSDF.tsdf_status = 'A'
	-- Not needed tsdf code is populated in OB receipt for EQ receipts as well
	--   and  profilequoteapproval.company_id = tsdf.eq_company
	--   and  profilequoteapproval.profit_ctr_id = tsdf.eq_profit_ctr
	left join  WasteCode  (nolock) 
		on  receipt.waste_code_uid = WasteCode.waste_code_uid
		And WasteCode.status = 'A'
	inner join  Treatment treatment (nolock) 
		on  profilequoteapproval.treatment_id = treatment.treatment_id
		and profilequoteapproval.company_id = treatment.company_id
		and profilequoteapproval.profit_ctr_id = treatment.profit_ctr_id
	Left outer join Transporter  (nolock) 
		on  Receipt.hauler = Transporter.transporter_code
/*
	join ProfileLab ON Receipt.profile_id = profileLab.profile_id
		and profileLab.type = 'A'
*/		
		LEFT JOIN StateAbbreviation lfs_gen
			ON Generator.generator_country = lfs_gen.country_code 
			and Generator.generator_state = lfs_gen.abbr
		LEFT JOIN StateAbbreviation lfs_tra
			ON Transporter.transporter_country = lfs_tra.country_code 
			and Transporter.transporter_state = lfs_tra.abbr
		LEFT JOIN StateAbbreviation lfs_tsd
			ON TSDF.tsdf_country_code = lfs_tsd.country_code 
			and TSDF.tsdf_state = lfs_tsd.abbr
	WHERE 
		Receipt.profit_ctr_id = @profit_ctr_id
		AND Receipt.company_id = @int_company_id
		AND Receipt.receipt_status = 'A'
		AND Receipt.trans_mode = 'O'
		AND Receipt.trans_type = 'D'
		AND Receipt.manifest_flag <> 'B'
		AND (Receipt.receipt_date >= @int_start_date AND Receipt.receipt_date <= @int_end_date)
		AND EXISTS (
			SELECT 
				1
			FROM ReceiptWasteCode RWC (nolock)
			Join WasteCode (nolock)
				on RWC.waste_code_uid = WasteCode.waste_code_uid
				AND WasteCode.waste_code_origin = 'F'
				AND IsNull(WasteCode.haz_flag,'F') = 'T'
				And WasteCode.status = 'A'
			WHERE 
				Receipt.company_id = RWC.company_id
				AND Receipt.profit_ctr_id = RWC.profit_ctr_id
				AND Receipt.receipt_id = RWC.receipt_id
				AND Receipt.line_id = RWC.line_id
		)
	GROUP BY
		Receipt.company_id,
		Receipt.profit_ctr_id,
		Receipt.receipt_id,
		Receipt.line_id,
		Receipt.manifest_unit,
		Receipt.manifest_quantity,
		Receipt.container_count,
		receipt.line_weight,
		treatment.treatment_id,
		UPPER(CONVERT(VARCHAR(4),
			CASE WHEN ltrim(rtrim(isnull(Receipt.Manifest_Management_Code, ''))) = ''
				THEN IsNull(treatment.management_code,'')
				ELSE ltrim(rtrim(isnull(Receipt.Manifest_Management_Code, '')))
			END
		)),
		-- treatment.management_code,
		Receipt.manifest,
		Receipt.manifest_line_id,
		Receipt.tsdf_approval_code,
		EPA_form_code, 
		EPA_source_code,
		UPPER(CONVERT(VARCHAR(50), IsNull(COALESCE(wastetype.category+' '+coalesce(wastetype.biennial_description, wastetype.description), profile.approval_desc),''))),
		/* ProfileLab.density, */
		Generator.generator_id,
		WasteCode.waste_code_desc,
		Coalesce(nullif(Generator.EPA_FC_ID,''), nullif(Generator.EPA_ID,''),''),
		Generator.generator_name,
		Generator.generator_address_1,
		Generator.generator_address_2,
		Generator.generator_address_3,
		Generator.generator_address_4,
		Generator.generator_address_5,
		Generator.generator_city,
		Generator.generator_state,
		Generator.generator_zip_code,
		lfs_Gen.epa_country_code,
		Generator.state_id,
		Transporter.transporter_EPA_ID,
		Transporter.transporter_name,
		Transporter.transporter_addr1,
		Transporter.transporter_addr2,
		Transporter.transporter_addr3,
		Transporter.transporter_city,
		Transporter.transporter_state,
		Transporter.transporter_zip_code,
		lfs_tra.epa_country_code,
		TSDF.epa_fc_id,
		TSDF.TSDF_EPA_ID,
		TSDF.TSDF_name,
		TSDF.TSDF_addr1,
		TSDF.TSDF_addr2,
		TSDF.TSDF_addr3,
		TSDF.TSDF_city,
		TSDF.TSDF_state,
		TSDF.TSDF_zip_code,
		lfs_tsd.epa_country_code

	if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Finished Outbound EQ TSDF Receipts' as description
	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Finished Outbound EQ TSDF Receipts into #tmp_OB_EQ')

	-- Combine the two temp files
	Select 
		* 
	INTO #tmp_OB 
	from #tmp_OB_Non_EQ
	union all
	Select 
		* 
	from #tmp_OB_EQ

	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Merged OB data into #tmp_OB')
	
-- fill in the "estimated" values for lbs, gal, yards
	SELECT DISTINCT
		Receipt.company_id,
		Receipt.profit_ctr_id,
		Receipt.receipt_id,
		Receipt.line_id,
		CASE WHEN isnull(
			(
			select receipt.manifest_quantity * billunit.pound_conv
			from billunit (nolock) where manifest_unit = Receipt.manifest_unit
			), 0) > 0 then
			(
			select receipt.manifest_quantity * billunit.pound_conv
			from billunit (nolock) where manifest_unit = Receipt.manifest_unit
			)  
			else		
			IsNull(ReceiptPrice.bill_quantity,0) * IsNull(BillUnit.pound_conv,0) 
		end AS lbs_per_container,
		CASE WHEN isnull(
			(
			select receipt.manifest_quantity * billunit.gal_conv
			from billunit (nolock) where manifest_unit = Receipt.manifest_unit
			), 0) > 0 then
			(
			select receipt.manifest_quantity * billunit.gal_conv
			from billunit (nolock) where manifest_unit = Receipt.manifest_unit
			)  
			else		
			IsNull(ReceiptPrice.bill_quantity,0) * IsNull(BillUnit.gal_conv,0)  
		end AS gal_per_container,
		CASE WHEN isnull(
			(
			select receipt.manifest_quantity * billunit.yard_conv
			from billunit (nolock) where manifest_unit = Receipt.manifest_unit
			), 0) > 0 then
			(
			select receipt.manifest_quantity * billunit.yard_conv
			from billunit (nolock) where manifest_unit = Receipt.manifest_unit
			)  
			else		
			IsNull(ReceiptPrice.bill_quantity,0) * IsNull(BillUnit.yard_conv,0)  
		end AS yard_per_container
	INTO #tmp_calc_OB
	FROM Receipt (nolock)
		JOIN #tmp_OB (nolock)  ON (Receipt.company_id = #tmp_OB.company_id
			And Receipt.profit_ctr_id = #tmp_OB.profit_ctr_id
			AND Receipt.receipt_id = #tmp_OB.receipt_id
			AND Receipt.line_id = #tmp_OB.line_id
			AND Receipt.profit_ctr_id = #tmp_OB.profit_ctr_id
			AND Receipt.company_id = #tmp_OB.company_id)
		JOIN ReceiptPrice  (nolock) ON (Receipt.company_id = ReceiptPrice.company_id
			AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
			AND Receipt.receipt_id = ReceiptPrice.receipt_id
			AND Receipt.line_id = ReceiptPrice.line_id
			AND Receipt.profit_ctr_id = ReceiptPrice.profit_ctr_id
			AND Receipt.company_id = ReceiptPrice.company_id)
		JOIN BillUnit (nolock)  ON (ReceiptPrice.bill_unit_code = BillUnit.bill_unit_code)

	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Estimated OB weights into #tmp_calc_OB')

	/* round the values */
	UPDATE #tmp_OB SET lbs_haz_actual = ROUND(ROUND(lbs_haz_actual, 4), 2),
	lbs_haz_estimated = ROUND(ROUND(lbs_haz_estimated, 4), 2),
	gal_haz_estimated = ROUND(ROUND(gal_haz_estimated, 4), 2),
	gal_haz_actual = ROUND(ROUND(gal_haz_actual, 4), 2),
	yard_haz_actual = ROUND(ROUND(yard_haz_actual, 4), 2),
	yard_haz_estimated = ROUND(ROUND(yard_haz_estimated, 4), 2)

	
	-- Merge the weights
	UPDATE #tmp_OB SET
		lbs_haz_estimated = CASE WHEN ISNULL(lbs_haz_estimated,0) = 0 THEN (#tmp_calc_OB.lbs_per_container) 
			ELSE lbs_haz_estimated
		END,
		gal_haz_estimated = CASE WHEN ISNULL(gal_haz_estimated,0) = 0 THEN (#tmp_calc_OB.gal_per_container) 
			else gal_haz_estimated
		END,
		yard_haz_estimated = CASE WHEN ISNULL(yard_haz_estimated,0) = 0 THEN (#tmp_calc_OB.yard_per_container) 
			else yard_haz_estimated
		END
	FROM #tmp_calc_OB
	WHERE 
		#tmp_OB.company_id = #tmp_calc_OB.company_id
		AND #tmp_OB.profit_ctr_id = #tmp_calc_OB.profit_ctr_id
		AND #tmp_OB.receipt_id = #tmp_calc_OB.receipt_id
		AND #tmp_OB.line_id = #tmp_calc_OB.line_id
		--AND #tmp_container_IB.lbs_haz_actual = 0	

	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Merged OB estimates into #tmp_OB')

	if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'More Weight Calculations' as description
	-- The following finds tsdf approvals that are missing form codes
	--select distinct tsdf_epa_id, tsdf_name, approval_code from #tmp_ob where EPA_form_code = ''

	-- update consistency for profiles (solid or liquid)
	update #tmp_container_IB SET consistency = 'LIQUID'
		FROM #tmp_container_IB ib 
			INNER JOIN ProfileQuoteApproval pqa (nolock) ON pqa.approval_code = ib.approval_code
			and ib.company_id = pqa.company_id
			and ib.profit_ctr_id = pqa.profit_ctr_id
		inner join ProfileLab pl (nolock) on pqa.profile_id = pl.profile_id
		WHERE pl.consistency like '%liquid%'
		
	update #tmp_OB SET consistency = 'LIQUID'
		FROM #tmp_OB ib 
			INNER JOIN ProfileQuoteApproval pqa (nolock) ON pqa.approval_code = ib.approval_code
			and ib.company_id = pqa.company_id
			and ib.profit_ctr_id = pqa.profit_ctr_id
		inner join ProfileLab pl (nolock) on pqa.profile_id = pl.profile_id
		WHERE pl.consistency like '%liquid%'		
		
	update #tmp_container_IB set consistency = COALESCE(consistency, '')
	update #tmp_OB set consistency = COALESCE(consistency, '')

	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Set #tmp consistency values to liquid where applicable')
	
	if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Finished Consistency Updates' as description

	-- BLANK OUT BAD EPA_IDs
	UPDATE #tmp_OB SET generator_epa_id = '' WHERE generator_epa_id IN ( 'N/A', '.', '....', 'NONE')
	UPDATE #tmp_OB SET transporter_epa_id = '' WHERE transporter_epa_id IN ( 'N/A', '.', '....', 'NONE')
	UPDATE #tmp_OB SET tsdf_epa_id = '' WHERE tsdf_epa_id IN ( 'N/A', '.', '....', 'NONE')

	-- IF this is EQ Florida, remove any records for the EPA_ID 'RECYCLER'
	IF @int_company_id = 22
		DELETE FROM #tmp_OB WHERE tsdf_epa_id = 'RECYCLER'
		
	-- Results
	INSERT EQ_Extract..BiennialReportSourceData (
		biennial_id,
		data_source,
		TRANS_MODE,
		Company_id,
		profit_ctr_id,
		profit_ctr_epa_id,
		receipt_id,
		line_id,
		container_id,
		sequence_id,
		treatment_id,
		management_code,
		lbs_haz_actual,
		lbs_haz_estimated,
		gal_haz_actual,
		gal_haz_estimated,
		yard_haz_actual,
		yard_haz_estimated,
		container_percent,
		manifest,
		manifest_line_id,
		approval_code,
		EPA_form_code,
		EPA_source_code,
		waste_desc,
		waste_density,
		waste_consistency,
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
		generator_country,
		generator_state_id,
		transporter_EPA_ID,
		transporter_name,
		transporter_addr1,
		transporter_addr2,
		transporter_addr3,
		transporter_city,
		transporter_state,
		transporter_zip_code,
		transporter_country,
		TSDF_EPA_ID,
		TSDF_name,
		TSDF_addr1,
		TSDF_addr2,
		TSDF_addr3,
		TSDF_city,
		TSDF_state,
		TSDF_zip_code,
		TSDF_country
	)		
	SELECT DISTINCT
		@int_biennial_id as biennial_id,
		@data_Source,
		'I' AS TRANS_MODE, 
		Company_id,
		profit_ctr_id,
		UPPER(CONVERT(VARCHAR(12), LTRIM(RTRIM(IsNull(@profit_ctr_epa_id, SPACE(12)))))) as profit_ctr_epa_id,
		receipt_id,
		line_id,
		container_id,
		sequence_id,
		treatment_id,
		management_code,
		lbs_haz_actual,
		lbs_haz_estimated,
		gal_haz_actual,
		gal_haz_estimated,
		yard_haz_actual,
		yard_haz_estimated,
		container_percent,
		manifest,
		manifest_line_id,
		approval_code,
		EPA_form_code,
		EPA_source_code,
		waste_desc,
		left(case charindex('.', waste_density)
			when 6 then format(convert(float, waste_density), '000000')
			when 5 then format(convert(float, waste_density), '0000.0')
			when 4 then format(convert(float, waste_density), '000.00')
			when 3 then format(convert(float, waste_density), '00.000')
			when 2 then format(convert(float, waste_density), '0.0000')
			when 1 then format(convert(float, waste_density), '0.00000')
			when 0 then format(convert(float, waste_density), '.000000')
			else left(waste_density, 6) 
		end, 6) as waste_density,
		consistency,
		generator_id,
		-- generator_epa_id,
		--CASE WHEN LEFT(generator_epa_id, 5) = 'CESQG' 
		--	THEN (SELECT TOP 1 tmp_g.generator_state + 'CESQG' + convert(varchar(20), tmp_g.generator_id)
		--			FROM Generator tmp_g 
		--			INNER JOIN ProfileQuoteApproval pqa ON pqa.approval_code = #tmp_container_IB.approval_code
		--				and pqa.company_id = #tmp_container_IB.company_id
		--				AND pqa.profit_ctr_id = #tmp_container_IB.profit_ctr_id
		--			INNER JOIN Profile p ON tmp_g.generator_id = p.generator_id)
		--	ELSE LEFT(generator_epa_id + space(12), 12) 
		--END as generator_epa_id,
		
		CASE WHEN LEFT(generator_epa_id, 5) = 'CESQG' OR LEFT(generator_epa_id, 4) = 'VSQG' 
			THEN LEFT(generator_state + /* 01292020 generator_epa_id */ 'VSQG' + space(12), 12)
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
		generator_country,
		generator_state_id,
		transporter_EPA_ID,
		transporter_name,
		transporter_addr1,
		transporter_addr2,
		transporter_addr3,
		transporter_city,
		transporter_state,
		transporter_zip_code,
		transporter_country,
		TSDF_EPA_ID,
		TSDF_name,
		TSDF_addr1,
		TSDF_addr2,
		TSDF_addr3,
		TSDF_city,
		TSDF_state,
		TSDF_zip_code,
		TSDF_country		
	FROM #tmp_container_IB
	UNION
	SELECT DISTINCT 
		#tmp_OB.biennial_id,
		@data_Source,
		'O' AS TRANS_MODE, 
		#tmp_OB.company_id,
		#tmp_OB.profit_ctr_id,
		UPPER(CONVERT(VARCHAR(12), LTRIM(RTRIM(IsNull(@profit_ctr_epa_id, SPACE(12)))))) as profit_ctr_epa_id,
		#tmp_OB.receipt_id,
		#tmp_OB.line_id,
		0 as container_id,
		0 as sequence_id,
		0 as treatment_id,
		#tmp_OB.management_code,
		#tmp_OB.lbs_haz_actual,
		#tmp_OB.lbs_haz_estimated,
		#tmp_OB.gal_haz_actual,
		#tmp_OB.gal_haz_estimated,
		#tmp_OB.yard_haz_actual,
		#tmp_OB.yard_haz_estimated,		
		--#tmp_OB.assigned_container_weight + ((#tmp_OB.container_count - #tmp_OB.assigned_container_count) * #tmp_OB.lbs_per_container) as lbs_haz_waste,
		100.000 as container_percent,
		#tmp_OB.manifest,
		#tmp_OB.manifest_line_id,
		#tmp_OB.approval_code,
		#tmp_OB.EPA_form_code, 
		-- 2/14/2011 - JPB replaced below...
		-- CASE WHEN Isnull(UPPER(CONVERT(VARCHAR(3), #tmp_OB.EPA_source_code)),'') = '' THEN CONVERT(VARCHAR(3), 'G61') ELSE  UPPER(CONVERT(VARCHAR(3), #tmp_OB.EPA_source_code)) END as EPA_source_code,
		Isnull(UPPER(CONVERT(VARCHAR(3), #tmp_OB.EPA_source_code)),'') as EPA_source_code,
		--#tmp_OB.EPA_source_code,
		#tmp_OB.waste_desc,
		left(case charindex('.', #tmp_OB.waste_density)
			when 6 then format(convert(float, #tmp_OB.waste_density), '000000')
			when 5 then format(convert(float, #tmp_OB.waste_density), '0000.0')
			when 4 then format(convert(float, #tmp_OB.waste_density), '000.00')
			when 3 then format(convert(float, #tmp_OB.waste_density), '00.000')
			when 2 then format(convert(float, #tmp_OB.waste_density), '0.0000')
			when 1 then format(convert(float, #tmp_OB.waste_density), '0.00000')
			when 0 then format(convert(float, #tmp_OB.waste_density), '.000000')
			else left(#tmp_OB.waste_density, 6) 
		end, 6) as waste_density,
		#tmp_OB.consistency,
		#tmp_OB.generator_id,
		#tmp_OB.generator_epa_id, -- There's no funny handling here because we wouldn't outbound to a CESQG/VSQG.
		#tmp_OB.generator_name,
		#tmp_OB.generator_address_1,
		#tmp_OB.generator_address_2,
		#tmp_OB.generator_address_3,
		#tmp_OB.generator_address_4,
		#tmp_OB.generator_address_5,
		#tmp_OB.generator_city,
		#tmp_OB.generator_state,
		#tmp_OB.generator_zip_code,
		#tmp_OB.generator_country,
		#tmp_OB.generator_state_id,
		#tmp_OB.transporter_EPA_ID,
		#tmp_OB.transporter_name,
		#tmp_OB.transporter_addr1,
		#tmp_OB.transporter_addr2,
		#tmp_OB.transporter_addr3,
		#tmp_OB.transporter_city,
		#tmp_OB.transporter_state,
		#tmp_OB.transporter_zip_code,
		#tmp_OB.transporter_country,
		#tmp_OB.TSDF_EPA_ID,
		#tmp_OB.TSDF_name,
		#tmp_OB.TSDF_addr1,
		#tmp_OB.TSDF_addr2,
		#tmp_OB.TSDF_addr3,
		#tmp_OB.TSDF_city,
		#tmp_OB.TSDF_state,
		#tmp_OB.TSDF_zip_code,
		#tmp_OB.TSDF_country
	FROM #tmp_OB

	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Populated EQ_Extract..BiennialReportSourceData')

-- 2/12/2016: Rearranged this update from after waste codes to before, to be with other Generator/EPA ID updates
	UPDATE EQ_Extract..BiennialReportSourceData
    SET    generator_state_id = state_id
    FROM   GeneratorStateId genstate  (nolock)
    WHERE  EQ_Extract..BiennialReportSourceData.eq_generator_id = genstate.generator_id
           AND EQ_Extract..BiennialReportSourceData.biennial_id = @int_biennial_id 

	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Updated BRSD generator_state_id values')
    
	
-- 2/12/2016: Rearranged this update from after waste codes to before, to be with other Generator/EPA ID updates
-- 2/12/2016 - Noticed this code shouldn't ever have gotten hit, since no CESQG would end in '%CESQG' - they've already had numbers appended. Commented out.
-- 2/12/2016 - Also, it doesn't reference waste profile as stated in the comment anyway.  Weird.
/*
	/ *
		fix the cesqg generator codes to be correct based on waste profile id
		Revised 3/28/2012 - JPB - VARIOUS generators (gen_id = 0) don't work in this
		code, they get their EPA ID set to ''
		Changed to just use other data in the record to fix this (same as it used to)
	* /
	print 'Fixing CESQG Generator Codes...'	
	UPDATE EQ_Extract..BiennialReportSourceData
	SET    generator_epa_id = EQ_Extract.dbo.fn_space_delimit('20', 
		replace(generator_state	+ 'CESQG' + convert(VARCHAR(20), eq_generator_id), ' ', '')
	)
	WHERE  biennial_id = @int_biennial_id
	   AND RTRIM(LTRIM(generator_epa_id)) LIKE '%CESQG'
*/


	-- Step added 2/12/2016 to handle having CESQG/VSQG Generator EPA IDs that are too long and don't match the Generator table on EPA ID anymore after truncating to 12 chars
	--   We'll renumber them:
	
		select distinct SD.eq_generator_id -- the real id
		, convert(varchar(5), null) as CESQG_number -- a place-holder slug
		INTO #CESQG_Renumber
		FROM EQ_Extract..BiennialReportSourceData SD
		where SD.biennial_id = @int_biennial_id
		and (SD.generator_epa_id like '__CESQG%' OR SD.generator_epa_id like '__VSQG%')

		update #CESQG_Renumber
		set CESQG_number = RIGHT('000000' + convert(varchar(5), n.CESQG_number), 5)
		from #CESQG_Renumber a
		join (
			select distinct SD.eq_generator_id
			, row_number() over (order by eq_generator_id) as cesqg_number
			FROM #CESQG_Renumber SD
		) n
			on a.eq_generator_id = n.eq_generator_id

		update EQ_Extract..BiennialReportSourceData
		set generator_epa_id = LEFT(SD.generator_epa_id, 7) + cr.CESQG_number
		from EQ_Extract..BiennialReportSourceData SD
		join #CESQG_Renumber cr on SD.eq_generator_id = cr.eq_generator_id
		WHERE sd.biennial_id = @int_biennial_id
	-- End of Step added 2/12/2016 to handle having CESQG/VSQG Generator EPA IDs that are too long and don't match correctly

	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Updated BRSD generator_epa_id values with CESQG/VSQG renumbering')


	-- Create the waste codes

-- Per LT, IL info should be the same as anywhere else.
-- IF @int_company_id <> 26 BEGIN
	-- IL waste codes come from approvals, all others use receipt/container sources

	-- These are inbound waste codes
	-- Take waste codes from container first
	INSERT EQ_Extract..BiennialReportSourceWasteCode (
		source_rowid,
		biennial_id,
		data_source,
		company_id,
		profit_ctr_id,
		receipt_id,
		line_id,
		container_id,
		sequence_id,
		waste_code,
		waste_code_uid,
		origin
	)
	SELECT DISTINCT
		SD.rowid,
		@int_biennial_id,
		@data_Source,
		SD.Company_id,
		SD.profit_ctr_id,
		SD.receipt_id,
		SD.line_id,
		SD.container_id,
		SD.sequence_id,
		left(WasteCode.display_name,4), -- The BRSWC table only takes 4.  Works for fed.  State output routines
			-- switched to output from display_name instead.
		Wastecode.waste_code_uid,
		WasteCode.waste_code_origin
	FROM EQ_Extract..BiennialReportSourceData SD  (nolock)
	join ContainerWasteCode CW (nolock)
		on SD.company_id = CW.company_id 
		AND SD.profit_ctr_id = CW.profit_ctr_id
		AND SD.receipt_id = CW.receipt_id
		AND SD.line_id = CW.line_id
		AND SD.container_id = CW.container_id
		AND SD.sequence_id = CW.sequence_id
	Join WasteCode (nolock)
		on CW.waste_code_uid = WasteCode.waste_code_uid
		AND (
			WasteCode.waste_code_origin = 'F'
			OR
			(
				WasteCode.waste_code_origin = 'S'
				AND WasteCode.state in (SD.generator_state, SD.tsdf_state)
			)
		)
		AND IsNull(WasteCode.haz_flag,'F') = 'T'
		And WasteCode.status = 'A'
	WHERE SD.biennial_id = @int_biennial_id
		AND SD.trans_mode = 'I'
		AND EXISTS (
			SELECT 
				1
			FROM ContainerWasteCode CW2   (nolock)
			WHERE 
				SD.company_id = CW2.company_id 
				AND SD.profit_ctr_id = CW2.profit_ctr_id
				AND SD.receipt_id = CW2.receipt_id
				AND SD.line_id = CW2.line_id
				AND SD.container_id = CW2.container_id
				AND SD.sequence_id = CW2.sequence_id
			)
	UNION
	-- Take waste codes from receipt for those that did not have container waste codes
	SELECT DISTINCT
		SD.rowid,
		@int_biennial_id,
		@data_Source,
		SD.Company_id,
		SD.profit_ctr_id,
		SD.receipt_id,
		SD.line_id,
		SD.container_id,
		SD.sequence_id,
		left(WasteCode.display_name,4), -- The BRSWC table only takes 4.  Works for fed.  State output routines
			-- switched to output from display_name instead.
		Wastecode.waste_code_uid,
		WasteCode.waste_code_origin
	FROM EQ_Extract..BiennialReportSourceData SD  (nolock)
	join ReceiptWasteCode RW (nolock)
		on SD.company_id = RW.company_id 
		AND SD.profit_ctr_id = RW.profit_ctr_id
		AND SD.receipt_id = RW.receipt_id
		AND SD.line_id = RW.line_id
	Join WasteCode (nolock)
		on RW.waste_code_uid = WasteCode.waste_code_uid
		AND (
			WasteCode.waste_code_origin = 'F'
			OR
			(
				WasteCode.waste_code_origin = 'S'
				AND WasteCode.state in (SD.generator_state, SD.tsdf_state)
			)
		)
		AND IsNull(WasteCode.haz_flag,'F') = 'T'
		And WasteCode.status = 'A'
	WHERE SD.biennial_id = @int_biennial_id
		AND SD.trans_mode = 'I'
		AND NOT EXISTS (
			SELECT 
				1
			FROM ContainerWasteCode CW2  (nolock)
			WHERE 
				SD.company_id = CW2.company_id 
				AND SD.profit_ctr_id = CW2.profit_ctr_id
				AND SD.receipt_id = CW2.receipt_id
				AND SD.line_id = CW2.line_id
				AND SD.container_id = CW2.container_id
				AND SD.sequence_id = CW2.sequence_id
		)
	UNION
 	-- These are outbound assigned container waste codes
	/*   Removed the container ones for now because they weren't reporting the container in a container.  May need to add that back later.
	SELECT DISTINCT
		@int_biennial_id
		@data_Source,
		#tmp_OB.profit_ctr_id,
		#tmp_OB.receipt_id,
		#tmp_OB.line_id,
		0 as container_id,
		0 as sequence_id,
		WasteCode.display_name
	FROM #tmp_OB
		JOIN ContainerDestination ON (ContainerDestination.tracking_num = dbo.fn_container_receipt(#tmp_OB.receipt_id, #tmp_OB.line_id))
		JOIN ContainerWaste ON (ContainerDestination.profit_ctr_id = ContainerWaste.profit_ctr_id
			AND ContainerDestination.receipt_id = ContainerWaste.receipt_id
			AND ContainerDestination.line_id = ContainerWaste.line_id 
			AND ContainerDestination.container_id = ContainerWaste.container_id
			AND ContainerDestination.sequence_id = ContainerWaste.sequence_id)
		JOIN WasteCode ON (ContainerWaste.waste_code_uid = WasteCode.waste_code_uid
			And WasteCode.status = 'A'
			AND IsNull(WasteCode.haz_flag,'F') = 'T')
		WHERE #tmp_OB.container_count = #tmp_OB.assigned_container_count
	UNION 
	-- These are assigned Stock containers with no waste codes
	SELECT DISTINCT
		@int_biennial_id,
		@data_Source,
		#tmp_OB.profit_ctr_id,
		#tmp_OB.receipt_id,
		#tmp_OB.line_id,
		0 as container_id,
		0 as sequence_id,
		WasteCode.display_name
	FROM
	#tmp_OB
		JOIN ReceiptWasteCode ON (#tmp_OB.profit_ctr_id = ReceiptWasteCode.profit_ctr_id
			AND #tmp_OB.receipt_id = ReceiptWasteCode.receipt_id
			AND #tmp_OB.line_id = ReceiptWasteCode.line_id )
		JOIN WasteCode ON (ReceiptWasteCode.waste_code_uid = WasteCode.waste_code_uid
			And WasteCode.status = 'A'
			AND IsNull(WasteCode.haz_flag,'F') = 'T')
		WHERE #tmp_OB.container_count = #tmp_OB.assigned_container_count 
			AND NOT EXISTS (SELECT CW.* FROM ContainerWaste CW
			WHERE #tmp_OB.profit_ctr_id = CW.profit_ctr_id
			AND #tmp_OB.receipt_id = CW.receipt_id
			AND #tmp_OB.line_id = CW.line_id )

	UNION 
*/
	-- These are unassigned container receipt waste codes
	-- Right now these are all of the outbound waste codes.
	SELECT DISTINCT
		(
			select min (rowid) from EQ_Extract..BiennialReportSourceData SD (nolock)
			where biennial_id = @int_biennial_id
			and receipt_id = #tmp_OB.receipt_id
			and line_id = #tmp_OB.line_id
			and company_id = #tmp_OB.company_id
			and profit_ctr_id = #tmp_OB.profit_ctr_id
		),
		@int_biennial_id,
		@data_Source,
		#tmp_OB.company_id,
		#tmp_OB.profit_ctr_id,
		#tmp_OB.receipt_id,
		#tmp_OB.line_id,
		0 as container_id,
		0 as sequence_id,
		left(WasteCode.display_name,4), -- The BRSWC table only takes 4.  Works for fed.  State output routines
			-- switched to output from display_name instead.
		WasteCode.waste_code_uid,
		WasteCode.waste_code_origin
	FROM #tmp_OB
		JOIN ReceiptWasteCode (nolock) 
			ON #tmp_OB.company_id = ReceiptWasteCode.company_id
			AND #tmp_OB.profit_ctr_id = ReceiptWasteCode.profit_ctr_id
			AND #tmp_OB.receipt_id = ReceiptWasteCode.receipt_id
			AND #tmp_OB.line_id = ReceiptWasteCode.line_id
		JOIN WasteCode (nolock) 
			ON ReceiptWasteCode.waste_code_uid = WasteCode.waste_code_uid
			And WasteCode.status = 'A'
			AND (
				WasteCode.waste_code_origin = 'F'
				OR
				(
					WasteCode.waste_code_origin = 'S'
					AND WasteCode.state in (#tmp_OB.generator_state, #tmp_OB.tsdf_state)
				)
			)
			AND IsNull(WasteCode.haz_flag,'F') = 'T'
		
/*
-- Per LT, IL info should be the same as anywhere else.

END ELSE BEGIN
	-- IL Waste Codes come from approval, not Receipt -- 2/23/2011 - JPB (per Lorraine)
	INSERT EQ_Extract..BiennialReportSourceWasteCode (
		biennial_id,
		data_source,
		company_id,
		profit_ctr_id,
		receipt_id,
		line_id,
		container_id,
		sequence_id,
		waste_code
	)
	SELECT DISTINCT
		@int_biennial_id,
		@data_Source,
		SD.Company_id,
		SD.profit_ctr_id,
		SD.receipt_id,
		SD.line_id,
		SD.container_id,
		SD.sequence_id,
		WasteCode.display_name
	FROM EQ_Extract..BiennialReportSourceData SD (nolock)
	join Receipt R on 
		SD.company_id = R.company_id 
		AND SD.profit_ctr_id = R.profit_ctr_id
		AND SD.receipt_id = R.receipt_id
		AND SD.line_id = R.line_id
	join ProfileWasteCode PWC on
		R.profile_id = pwc.profile_id
	Join WasteCode on 
		PWC.waste_code_uid = WasteCode.waste_code_uid
		AND WasteCode.waste_code_origin = 'F'
		AND IsNull(WasteCode.haz_flag,'F') = 'T'
		And WasteCode.status = 'A'
	WHERE 
		SD.trans_mode = 'I'

END
*/

	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Populated BiennialReportSourceWasteCode')

	if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Finished EQAI Inserts to Source Table' as description
	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Finished EQAI Inserts to Source Table')


/*
	-- run for the enviroware data
	if (@int_company_id = 25 or @int_company_id = 26)
	begin
		if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Beginning EW data at ' + cast(getdate() as varchar(100)) as description
		exec sp_biennial_report_source_enviroware @int_biennial_id, @int_company, @int_start_date, @int_end_date, @int_user_code 
		if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Finishing EW data at ' + cast(getdate() as varchar(100)) as description
	end
*/
	
    
	--SELECT * FROM 
	--	EQ_Extract..BiennialReportSourceData src
	--	INNER JOIN GeneratorStateId genstate ON src.eq_generator_id =
	--		genstate.state_id
	--	and src.biennial_id = @int_biennial_id
	
/*

2/8/2012 JPB-
- This is the part where we fudge the data that wasn't accurate.
- There's no data in here form 2011 anyway...

	/* 
		overlay manual corrections from the Overlay table 
		this takes a long time
	*/
	print '--Beginning overlay at ' + cast(getdate() as varchar(100))
	if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Beginning overlay data at ' + cast(getdate() as varchar(100)) as description

	
	exec sp_biennial_report_source_overlay @int_biennial_id, 0

	
	-- this procedure does manual updates for data that is too difficult to do
	-- with the overlay table
	print 'Applying manual overlay: sp_biennial_report_source_overlay_manual'
	exec sp_biennial_report_source_overlay_manual @int_biennial_id
	
	sp_helptext sp_biennial_report_source_overlay_manual
	print '--Finished overlay at ' + cast(getdate() as varchar(100))
	if @int_debug > 0 select datediff(ms, @starttime, getdate()) as timer, 'Finished overlay data at ' + cast(getdate() as varchar(100)) as description
*/
	


	if @debug > 1 print 'Verifying estimated weights are never empty when actuals are available...'
	/* make sure the estimated weights are correct */
	UPDATE EQ_Extract..BiennialReportSourceData
    SET    lbs_haz_estimated = lbs_haz_actual
    WHERE  ISNULL(lbs_haz_estimated, 0) = 0 AND ISNULL(lbs_haz_actual, 0) <> 0
    and biennial_id = @int_biennial_id
    
	UPDATE EQ_Extract..BiennialReportSourceData
    SET    gal_haz_estimated = gal_haz_actual
    WHERE  ISNULL(gal_haz_estimated, 0) = 0 AND ISNULL(gal_haz_actual, 0) <> 0
    and biennial_id = @int_biennial_id
    
	UPDATE EQ_Extract..BiennialReportSourceData
    SET    yard_haz_estimated = yard_haz_actual
    WHERE  ISNULL(yard_haz_estimated, 0) = 0 AND ISNULL(yard_haz_actual, 0) <> 0        
    and biennial_id = @int_biennial_id
    
				
	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Updated BRSD estimate fields with actual data where estimate was zero but actual was > zero')


	-- Are there foreign handlers not converted to FCCOUNTRY ids?
	-- TSDF:
	
		insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Updating Foreign TSDF EPA IDs')
	
		update eq_extract..BiennialReportSourceData set 
			tsdf_epa_id = left('FC' 
			 + case tsdf_country when 'CA' then 'CANADA' when 'MX' then 'MEXICO' else '            ' end
			 + '            '
			 , 12)
		WHERE biennial_id = @int_biennial_id
		and tsdf_country not in ('US', 'USA')
		and tsdf_epa_id not like 'FC%'
		
		insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Updated Foreign TSDF EPA IDs')

	-- Generator:
		insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Updating Foreign Generator EPA IDs')

		update eq_extract..BiennialReportSourceData set 
			generator_epa_id = left('FC' 
			 + case generator_country when 'CA' then 'CANADA' when 'MX' then 'MEXICO' else '            ' end
			 + '            '
			 , 12)
		WHERE biennial_id = @int_biennial_id
		and generator_country not in ('US', 'USA')
		and generator_epa_id not like 'FC%'

		insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Updated Foreign Generator EPA IDs')
	
	/* 
		RJG: 2010 will not require outbound informatio - so we will remove it from the extract 
		future years will require this
	*/
	/*
	if @year = 2010
		DELETE FROM EQ_Extract..BiennialReportSourceData WHERE biennial_id = @int_biennial_id
			AND trans_mode ='O'
	*/
	UPDATE EQ_Extract..BiennialLog SET
		run_ended = getdate()
	where biennial_id = @int_biennial_id

	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Updated BiennialLog with run end time')

	insert EQ_Extract..BiennialDebugInfo (biennial_id, log_time, log_message) values (@int_biennial_id, getdate(), 'Ending sp_biennial_report_source: ' + @int_Company + ', ' + convert(varchar(20), @int_start_date) + ' - ' + convert(varchar(20), @int_end_date) + ', ' + @int_user_code)
	
	--if @is_new_run = 'T'	
	--	SELECT @int_biennial_id	as biennial_id
		

go
grant execute on sp_biennial_report_source to eqai, eqweb
go


