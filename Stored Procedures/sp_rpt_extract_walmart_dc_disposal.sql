
CREATE PROCEDURE sp_rpt_extract_walmart_dc_disposal (
	@start_date				datetime,
	@end_date				datetime,
	@output_mode			varchar(20)		-- one of: 'validation', 'generators', 'wm-extract', 'eq-extract', 'manifests'
)
AS
/* ***********************************************************




DON'T RUN THIS SP.  IT IS NOT CONSISTENT WITH THE CURRENT WM DISPOSAL EXTRACT.
7/13/2010 - JPB





Procedure    : sp_rpt_extract_walmart_dc_disposal
Database     : PLT_AI
Created      : Jan 13 2009 - Jonathan Broome
Description  : Creates a Wal-Mart Distribution Center Disposal Extract

Examples:
	sp_rpt_extract_walmart_dc_disposal '1/1/2008 00:00', '1/31/2008 23:59', 'validation'
	sp_rpt_extract_walmart_dc_disposal '10/1/2008 00:00', '10/31/2008 23:59', 'wm-extract'

Notes:
	IMPORTANT: This script is only valid from 2007/03 and later.
		2007-01 and 2007-02 need to exclude company-14, profit-ctr-4 data.
		2007-01 needs to INCLUDE 14/4 data from the state of TN.

History:
	2/22/2008 - JPB - converted [field names] to field_names
		converted table names to friendlier names
		added JDB validation to the SP

	3/12/2008 - JDB - Beautified comments.  Changed the select
		for site_type to be from Generator directly. Added
		validation for missing site_type, and validation list
		of generators not associated with customer 10673.

	3/14/2008 - JPB - Removed errant extra '' from select into #WMDisposal
		on transporter*_epa_id fields

	4/10/2008 - JPB - Added code to include workorder records for pickup stops where no waste was picked up.

	4/18/2008 - JPB - Changed receipt_workorder_id, workorder_company_id, workorder_profit_ctr_id, service_date calcuations
		to use receipt.source_id where possible, or fall back to stop 1 workorder... for same generator
		order by w.start_date desc like it used to.

	6/9/2008 - JPB -
		Changed dot_description: TSDF approvals use the dot_shipping_name from the approval
			(because it's been entered as they prefer to see it)
			Receipts (EQ approvals) use the new fn_manifest_dot_description function.
			And if a row is neither a TSDF nor has a profile, then the field is ''
		Added validation for missing DOT_description values (that aren't service fee records)
		Added validation for missing waste description values (that aren't service fee records)
		Tweaked validation to include counts before lists of id's that need attention.

	6/13/2008 - JPB -
		Changed Receipt/Transporter fix: No longer calculates or populates any other table:
		It only takes data from BillingLinkLookup, supplemented by data from old calculated info.

	6/17/2008 - JPB - (per Brie/LT/JPB conference call):
		Modified Generator selection logic: Include all of 10673 + any generator with a site type in:
		  ('Amigo', 'Neighborhood Market', 'Sams Club', 'Sams DC', 'Supercenter', 'Wal-Mart', 'Wal-Mart DC', 'Optical Lab')
		No more replacing 'NONE' wastecodes with empty/blank/null (oops, wasn't doing this anyway)
		Omit billing project 145 from all disposal/financial data

	6/20/2008 - JPB
		Modified Validation for missing waste codes: Only check disposal/approval records.

	6/23/2008 - JPB
		Modified Image extract to correct matching (receipt_id = workorder_id is wrong)
		Added validation to look for missing scans

	7/11/2008 - JPB
		Removed join requirement in Workorders <-> TSDFApproval that WO.customer_id = TA.customer_id

	7/14/2008 - JPB
		Added export to Excel code.  Needs work to make it copy to L: though.

	8/13/2008 - JPB
		Use Load_Generator_EPA_ID where populated.

	8/22/2008 - JPB
		Changed extract dir referenced in script below from plt_ai to eq_extract

	9/3/2008 - JPB
		Replaced approval_code with replace(r.approval_code, ''WM'' + right(''0000'' + r.generator_site_code, 4), ''WM'')
			to remove generator site codes from approval codes in the extract. - did not address TSDF approval codes.

	12/08/2008 - JPB
		per Brie (GEM:9650):
			Exclude any Wal-Mart Distribution Center data from the Waste Extract
				" AND ISNULL(g.site_type, '''') NOT IN (''Sams DC'', ''Wal-Mart DC'') "
				" AND ISNULL(g.site_type, '') NOT IN ('Sams DC', 'Wal-Mart DC') "
			The financial extract should only contain data for billing projects 24 & 99
			Please extract manifest images for all Wal-Marts except Distribution Centers...
				(accomplished by DC exclusion above)

	01/05/2009 - JPB
		Revised from sp_walmart_monthly_disposal_extract
		Only returns 1 output per run now (instead of several tables)
		Only returns recordset - no excel output
		Runs from central (plt_ai) locations - subst. plt_21_ai while plt_ai locations don't exist yet.

	01/13/2009 - JPB
		Revised from sp_rpt_extract_walmart_disposal
		Only returns Distribution Center records (which are excluded from the regular WM Disposal extract)
		Effectively, changes made here are just the OPPOSITE of the 12/08 change to the normal SP.
		Converted for use on plt_ai, and plt_ai only.

	02/03/2009 - JPB
		Fixed No Waste Pickup select - wasn't excluding site codes already found in #Extract, should have been.
		Fixed Validation checks that were looking for whole words for 'Approval', 'Disposal', 'No Waste Pickup',
			but should have been looking for 'A', 'D' or 'N'.
		Fixed join syntax to tsdfapproval - now uses tsdf_approval_id, company_id, profit_ctr_id.
		
	03/04/2009 - JPB
		Fixed join in Receipt query to WRT - was omitting line_id in matches which created duplicates.
		Fixed join in Receipt query to Container - was not specifying container type of 'R'
		Fixed Order By on Extract select
		Fixed calculation of workorderdetail.quantity to align with what RPT database uses.
		Updated No Waste Pickup query to insert workorder_id as receipt_id - was left NULL before, inconsistent with old RPT method.
		Moved Important Site_Type values to temp tables instead of copied lists all over the SP
			#SiteTypeToInclude	- the list that should be included
			Where the "normal" version of the extract SP has 2 types of tables (Include and Exclude),
			the DC only version only requires an Include, so the Exclude table is not present in this script.

	03/17/2009 - JPB
		Synchronizing Logic with Disposal Extract...
			Add Disposal Method to extract (comes from profile/tsdfapproval)
				ProfileQuoteApproval.disposal_service_id = DisposalService.disposal_service_id
				TSDFApproval.disposal_service_id = DisposalService.disposal_service_id
			Include Walmart approval WMNH018L or WMxxxxNH018L on extract (previously excluded)
				This is done by removing the omission of billing_project_id 145
				commented all instances of the 145 exclude.
			Added a fix for including Container records in the extract - container weights were being duplicated
				because ContainerDestination's percent_of_container was not being factored into the amounts
			Receipt select was selecting NULL as EPA_source_code.  Now selects Profile.EPA_source_code.
			Changed Receipt-Transporter logic per Brie's instructions:
				Always show transporter 1 as the first transporter to have moved the load
				Always show transporter 2 as the second transporter to have moved the load
				It does not matter if there were any other transporters: only the first 2 count.
				This replaces previously existing calculation logic.
	03/19/2009 - JPB
		Revised Fields and Queries for GEM:10459
		Removed the Manifest extract option for the DC Extract.
		Modified Extract Table Names specific to the DC Extract (separate from the normal extract now)

	04/03/2009 - JPB
		Modified validation tables to hold 7500 chars of problem ids, instead of 1000.
		Modified @list var to accomodate 7500.
		No other changes.

	04/22/2009 - JPB
		Added Extract Logging so we can see in the future what args we called an extract run with

	07/13/2010 - JPB
       Consistent with changes to sp_rpt_extract_walmart_disposal, excepting those changes not applicable in this extract.
        1. Manifest Line was returning 0 for No Waste Pickups.  Change to 1.
	    2. Per Brie, always use the current generator.epa_id, not the receipt.load_generator_epa_id
		3. Change NWP Record check - not for omission of disposal where there's a WO anymore,
		   but where there's a WO with a decline_id > 1
        4. For wm-extract runs, Don't include waste codes that aren't State or Federal
        

*********************************************************** */



RETURN
--   DON'T RUN THIS SP.  IT IS NOT CONSISTENT WITH THE CURRENT WM DISPOSAL EXTRACT.
--  7/13/2010 - JPB

-- Define Walmart specific extract values:
DECLARE
	@extract_datetime		datetime,
	@usr					nvarchar(256),
	@customer_id			int,
	@days_before_delete		int,
	@sp_name_args			varchar(1000)

SELECT
	@extract_datetime		= GETDATE(),
	@usr 					= UPPER(SUSER_SNAME()),
	@customer_id			= 10673,	-- Hard coded for this extract sp
	@days_before_delete		= 90,
	@sp_name_args			= object_name(@@PROCID) + ' ''' + convert(varchar(20), @start_date) + ''', ''' + convert(varchar(20), @end_date) + ''', ''' + @output_mode + ''''
	
-- Define other variables used internally:
DECLARE
	@list 					varchar(7500)

IF RIGHT(@usr, 3) = '(2)'
	SELECT @usr = LEFT(@usr,(LEN(@usr)-3))

-- Log Run information
	INSERT EQ_Extract..ExtractLog (
		extract,
		extract_command,
		start_date,
		end_date,
		extract_table,
		record_count,
		date_added,
		added_by
	) VALUES (
		'Walmart DC Disposal',
		@sp_name_args,
		GETDATE(),
		null,
		null,
		null,
		@extract_datetime,
		@usr
	)
	
-- Create #Extract for inserts later:
CREATE TABLE #Extract (
	-- Walmart Fields:
	site_code 					varchar(16) NULL,	-- DC Number
	generator_city 				varchar(40) NULL,	-- City
	generator_state 			varchar(2) NULL,	-- State
	service_date 				datetime NULL,		-- Service Date
	epa_id 						varchar(12) NULL,	-- EPA ID
	manifest 					varchar(15) NULL,	-- Manifest
	manifest_line 				int NULL,			-- Manifest Line
	haz_pounds 					float NULL,			-- Haz lbs
	nonhaz_pounds 				float NULL,			-- Non-Haz lbs
	bill_unit_desc 				varchar(40) NULL,	-- Container Type
	quantity 					float NULL,			-- Container Quantity
	waste_desc 					varchar(50) NULL,	-- Waste Descritpion
	approval_or_resource 		varchar(60) NULL,	-- Waste Profile Number
	dot_description				varchar(255) NULL,	-- DOT Description
	waste_code_1				varchar(10) NULL,	-- Waste Code 1
	waste_code_2				varchar(10) NULL,	-- Waste Code 2
	waste_code_3				varchar(10) NULL,	-- Waste Code 3
	waste_code_4				varchar(10) NULL,	-- Waste Code 4
	waste_code_5				varchar(10) NULL,	-- Waste Code 5
	state_waste_code_1			varchar(10) NULL,	-- State Waste Code 1
	management_code 			varchar(4) NULL,	-- Management Code
	receiving_facility 			varchar(50) NULL,	-- Receiving Facility
	receiving_facility_epa_id 	varchar(50) NULL,	-- Receiving Facility EPA ID Number
	receipt_id 					int NULL,			-- Workorder Number
	
	-- EQ Fields:
	company_id 					smallint NULL,
	profit_ctr_id	 			smallint NULL,
	line_sequence_id			int NULL,
	generator_id 				int NULL,
	generator_name 				varchar(40) NULL,
	site_type	 				varchar(40) NULL,
	manifest_page 				int NULL,
	item_type 					varchar(9) NULL,
	tsdf_approval_id 			int NULL,
	profile_id 					int NULL,
	container_count 			float NULL,
	waste_codes 				varchar(2000) NULL,
	state_waste_codes 			varchar(2000) NULL,
	transporter1_code			varchar(15) NULL,
	transporter2_code			varchar(15) NULL,
	date_delivered 				datetime NULL,
	source_table 				varchar(20) NULL,
	receipt_date				datetime NULL,
	receipt_workorder_id		int NULL,
	workorder_start_date		datetime NULL,
	workorder_company_id		int NULL,
	workorder_profit_ctr_id		int NULL,
	customer_id					int NULL,
	haz_flag					char(1) NULL
)

-- Create table to contain Not Invoiced info for Validation
SELECT * INTO #NotSubmitted from #Extract

-- Create table to store images for export
CREATE TABLE #ExtractImages (
	row_id			int NOT NULL IDENTITY,
	site_code		varchar(16) NULL,
	generator_id	int NULL,
	service_date	varchar(40) NULL,
	image_id		int NULL,
	document_name	varchar(50) NULL,
	document_type	varchar(30) NULL,
	page_number		int NULL,
	file_type		varchar(10) NULL,
	filename		varchar(250) NULL,
	process_flag	int NULL,
	newname			varchar(100) NULL
)

-- Create table to store validation info
CREATE TABLE #validation (
	v_id 			int,
	reason 			varchar(200),
	problem_ids 	varchar(7500) null,
	prod_value 		float null,
	extract_value 	float null
)

-- Create table to store missing generator info
CREATE TABLE #MissingGenerators (
	generator_id	int NULL,
	epa_id			varchar(12) NULL,
	generator_name	varchar(40) NULL,
	generator_city	varchar(40) NULL,
	generator_state	varchar(2) NULL,
	site_code		varchar(16) NULL,
	site_type		varchar(40) NULL,
	status			char(1) NULL
)

-- Create table to store important site types for this query (saves on update/retype issues)
CREATE TABLE #SiteTypeToInclude (
	site_type		varchar(40)
)
-- Load #SiteTypeToInclude table values:
	INSERT #SiteTypeToInclude (site_type) VALUES ('Sams DC')
	INSERT #SiteTypeToInclude (site_type) VALUES ('Wal-Mart DC')




/* *************************************************************

Build Phase...
	Insert records to #Extract from
	1. TSDF (3rd party) disposal
	2. Receipt (EQ) disposal
	3. No-Waste Pickup Workorders

	Each step also has a #NotSubmitted copy - to trap for records
	that would have been included, if only they were submitted for
	billing already.  This info is for validation purposes.

	Before Receipts can be inseted into #Extract, a separate
	pre-condition query has to be run to build #ReceiptTransporter
	with info needed by the Receipt insert.

************************************************************** */

-- Work Orders using TSDFApprovals (where customer = @customer_id or generator belongs to @customer_id)
INSERT #Extract
SELECT DISTINCT
	-- Walmart Fields:
	g.site_code AS site_code,
	g.generator_city AS generator_city,
	g.generator_state AS generator_state,
	w.start_date AS service_date,
	g.epa_id AS epa_id,
	d.manifest AS manifest,
	CASE WHEN isnull(d.manifest_line, '') <> '' THEN
		CASE WHEN IsNumeric(d.manifest_line) <> 1 THEN
			dbo.fn_convert_manifest_line(d.manifest_line, d.manifest_page_num)
		ELSE
			d.manifest_line
		END
	ELSE
		NULL
	END AS manifest_line,
	CASE WHEN isnull(t.hazmat, 'F') = 'T' THEN
		ISNULL(d.pounds, 0)
	ELSE
		0
	END AS haz_pounds,
	CASE WHEN isnull(t.hazmat, 'F') = 'F' THEN
		ISNULL(d.pounds, 0)
	ELSE
		0
	END AS nonhaz_pounds,
	b.bill_unit_desc AS bill_unit_desc,
	ISNULL(	
		CASE
				WHEN d.quantity_used IS NULL
				THEN IsNull(d.quantity,0)
				ELSE d.quantity_used
		END
	, 0) AS quantity,
	t.waste_desc AS waste_desc,
	CASE WHEN ISNULL(d.tsdf_approval_code, '') = '' THEN
		d.resource_class_code
	ELSE
		d.tsdf_approval_code
	END AS approval_or_resource,
	NULL as dot_description,		-- Populated later
	null as waste_code_1,			-- Populated later
	null as waste_code_2,			-- Populated later
	null as waste_code_3,			-- Populated later
	null as waste_code_4,			-- Populated later
	null as waste_code_5,			-- Populated later
	null as state_waste_code_1,		-- Populated later
	t.management_code AS management_code,
	t2.TSDF_name AS receiving_facility,
	t2.TSDF_epa_id AS receiving_facility_epa_id,
	d.workorder_id as receipt_id,

	-- EQ Fields:
	w.company_id,
	w.profit_ctr_id,
	d.sequence_id,
	g.generator_id,
	g.generator_name AS generator_name,
	g.site_type AS site_type,
	d.manifest_page_num AS manifest_page,
	d.resource_type AS item_type,
	t.tsdf_approval_id,
	NULL AS profile_id,
	ISNULL(d.container_count, 0) AS container_count,
	t.waste_code + ', ' + dbo.fn_approval_sec_waste_code_list(t.tsdf_approval_id, 'T') AS waste_codes,
	dbo.fn_sec_waste_code_list_state(t.tsdf_approval_id, 'T') AS state_waste_codes,
	wom.transporter_code_1 AS transporter1_code,
	wom.transporter_code_2 AS transporter2_code,
	wom.date_delivered AS date_delivered,
	'Workorder' AS source_table,
	NULL AS receipt_date,
	NULL AS receipt_workorder_id,
	w.start_date AS workorder_start_date,
	NULL AS workorder_company_id,
	NULL AS workorder_profit_ctr_id,
	w.customer_id AS customer_id,
	t.hazmat as haz_flag
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN Generator g  (nolock) ON w.generator_id = g.generator_id
INNER JOIN BillUnit b  (nolock) ON d.bill_unit_code = b.bill_unit_code
INNER JOIN Billing Billing  (nolock) ON
	d.workorder_id = Billing.receipt_id
	AND d.company_id = Billing.company_id
	AND d.profit_ctr_id = Billing.profit_ctr_id
	AND d.resource_type = Billing.workorder_resource_type
	AND d.sequence_id = Billing.workorder_sequence_id
	AND Billing.trans_source = 'W'
	AND Billing.status_code = 'I'
LEFT OUTER JOIN TSDFApproval t  (nolock) ON d.tsdf_approval_id = t.tsdf_approval_id
	AND d.company_id = t.company_id
	AND d.profit_ctr_id = t.profit_ctr_id
LEFT OUTER JOIN TSDF t2  (nolock) ON d.tsdf_code = t2.tsdf_code
LEFT OUTER JOIN WorkOrderManifest wom  (nolock) ON w.workorder_id = wom.workorder_id and w.company_id = wom.company_id and w.profit_ctr_id = wom.profit_ctr_id
WHERE 1=1
AND (w.customer_id = @customer_id
	OR w.generator_id IN (SELECT generator_id FROM customergenerator  (nolock) WHERE customer_id = @customer_id)
	OR w.generator_id IN (
		SELECT generator_id FROM generator  (nolock) where site_type IN (
			SELECT site_type from #SiteTypeToInclude
		)
	)
)
AND billing.invoice_date BETWEEN @start_date AND @end_date
AND ISNULL(t2.eq_flag, 'F') = 'F'
AND d.resource_type = 'D'
AND w.workorder_status IN ('A','C','D','N','P','X')
AND w.submitted_flag = 'T'
-- AND (isnull(w.billing_project_id, 0) <> 145 OR (isnull(w.billing_project_id, 0) = 145 and w.customer_id <> 10673))
AND ISNULL(g.site_type, '') IN (SELECT site_type from #SiteTypeToInclude)



--	PRINT 'Receipt/Transporter Fix'
/*
This query has 3 union'd components:
first component: workorder inner join to billinglinklookup and receipt
second component: receipt inner join to WMReceiptWorkorderTransporter and workorder
third component: receipt not linked to either BLL or WMRWT
*/
	select distinct
		r.receipt_id,
		r.line_id,
		r.company_id,
		r.profit_ctr_id,
		wo.workorder_id as receipt_workorder_id,
		wo.company_id as workorder_company_id,
		wo.profit_ctr_id as workorder_profit_ctr_id,
		isnull(rt1.transporter_sign_date, wo.start_date) as service_date,
		r.receipt_date,
		'F' as calc_recent_wo_flag,
/*		
		-- TX or LA and after 9/1/07 (9/1/07 according to Brie):
		CASE WHEN (g.generator_state in ('TX', 'LA') AND wo.start_date>= '2007-09-01 00:00:00.000') THEN
			'EQIS'
		ELSE
			-- AL, MS, GA, TN
			CASE WHEN (g.generator_state in ('AL', 'MS', 'GA', 'TN')) THEN
				'EQIS'
			ELSE
				r.hauler
			END
		END AS transporter1,
		r.hauler AS transporter2
*/	
		rt1.transporter_code as transporter1,
		rt2.transporter_code as transporter2
	into #WMReceiptTransporter
	from workorderheader wo (nolock) 
	inner join billinglinklookup bll  (nolock) on
		wo.company_id = bll.source_company_id
		and wo.profit_ctr_id = bll.source_profit_ctr_id
		and wo.workorder_id = bll.source_id
	inner join receipt r  (nolock) on bll.receipt_id = r.receipt_id
		and bll.profit_ctr_id = r.profit_ctr_id
		and bll.company_id = r.company_id
	left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id
		and rt1.profit_ctr_id = r.profit_ctr_id
		and rt1.company_id = r.company_id
		and rt1.transporter_sequence_id = 1
	left outer join receipttransporter rt2  (nolock) on rt2.receipt_id = r.receipt_id
		and rt2.profit_ctr_id = r.profit_ctr_id
		and rt2.company_id = r.company_id
		and rt2.transporter_sequence_id = 2
	inner join generator g  (nolock) on r.generator_id = g.generator_id
	where 1=1
--		wo.start_date between @start_date AND @end_date
		and (1=0
			or wo.customer_id = @customer_id
			or wo.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
			OR wo.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
			or r.customer_id = @customer_id
			or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
			OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
		)
		-- AND (isnull(wo.billing_project_id, 0) <> 145 OR (isnull(wo.billing_project_id, 0) = 145 and wo.customer_id <> 10673))
	union
	select distinct
		r.receipt_id,
		r.line_id,
		r.company_id,
		r.profit_ctr_id,
		rwt.workorder_id as receipt_workorder_id,
		rwt.workorder_company_id,
		rwt.workorder_profit_ctr_id,
		isnull(rt1.transporter_sign_date, wo.start_date) as service_date,
		r.receipt_date,
		rwt.calc_recent_wo_flag,
/*		
		-- TX or LA and after 9/1/07 (9/1/07 according to Brie):
		CASE WHEN (g.generator_state in ('TX', 'LA') AND wo.start_date>= '2007-09-01 00:00:00.000') THEN
			'EQIS'
		ELSE
			-- AL, MS, GA, TN
			CASE WHEN (g.generator_state in ('AL', 'MS', 'GA', 'TN')) THEN
				'EQIS'
			ELSE
				r.hauler
			END
		END AS transporter1,
		r.hauler AS transporter2
*/
		rt1.transporter_code as transporter1,
		rt2.transporter_code as transporter2
	from receipt r (nolock) 
	inner join WMReceiptWorkorderTransporter rwt  (nolock) on
		rwt.receipt_company_id = r.company_id
		and rwt.receipt_profit_ctr_id = r.profit_ctr_id
		and rwt.receipt_id = r.receipt_id
		and rwt.workorder_id is not null
	inner join workorderheader wo  (nolock) on
		rwt.workorder_id = wo.workorder_id
		and rwt.workorder_profit_ctr_id = wo.profit_ctr_id
		and rwt.workorder_company_id = wo.company_id
	inner join generator g  (nolock) on r.generator_id = g.generator_id
	left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id
		and rt1.profit_ctr_id = r.profit_ctr_id
		and rt1.company_id = r.company_id
		and rt1.transporter_sequence_id = 1
	left outer join receipttransporter rt2  (nolock) on rt2.receipt_id = r.receipt_id
		and rt2.profit_ctr_id = r.profit_ctr_id
		and rt2.company_id = r.company_id
		and rt2.transporter_sequence_id = 2
	where 1=1
--		wo.start_date between @start_date AND @end_date
		and (1=0
			or wo.customer_id = @customer_id
			or wo.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
			OR wo.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
			or r.customer_id = @customer_id
			or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
			OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
		)
		-- AND (isnull(r.billing_project_id, 0) <> 145 OR (isnull(r.billing_project_id, 0) = 145 and r.customer_id <> 10673))
		and not exists (
			select
			ri.receipt_id
			from workorderheader wo (nolock) 
			inner join billinglinklookup bll  (nolock) on
				wo.company_id = bll.source_company_id
				and wo.profit_ctr_id = bll.source_profit_ctr_id
				and wo.workorder_id = bll.source_id
			inner join receipt ri  (nolock) on bll.company_id = ri.company_id
				and bll.profit_ctr_id = ri.profit_ctr_id
				and bll.receipt_id = ri.receipt_id
			where 1=1
--			wo.start_date between @start_date AND @end_date
			and (1=0
				or wo.customer_id = @customer_id
				or wo.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
				OR wo.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
				or r.customer_id = @customer_id
				or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
				OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
			)
			-- AND (isnull(wo.billing_project_id, 0) <> 145 OR (isnull(wo.billing_project_id, 0) = 145 and wo.customer_id <> 10673))
			and ri.receipt_id = r.receipt_id and ri.company_id = r.company_id and ri.profit_ctr_id = r.profit_ctr_id
		)
	union
	select distinct
		r.receipt_id,
		r.line_id,
		r.company_id,
		r.profit_ctr_id,
		null as receipt_workorder_id,
		null as workorder_company_id,
		null as workorder_profit_ctr_id,
		rt1.transporter_sign_date as service_date,
		r.receipt_date,
		'F' as calc_recent_wo_flag,
/*		
		-- TX or LA and after 9/1/07 (9/1/07 according to Brie):
		CASE WHEN (g.generator_state in ('TX', 'LA') AND r.receipt_date>= '2007-09-01 00:00:00.000') THEN
			'EQIS'
		ELSE
			-- AL, MS, GA, TN
			CASE WHEN (g.generator_state in ('AL', 'MS', 'GA', 'TN')) THEN
				'EQIS'
			ELSE
				r.hauler
			END
		END AS transporter1,
		r.hauler AS transporter2
*/
		rt1.transporter_code as transporter1,
		rt2.transporter_code as transporter2		
	from receipt r (nolock) 
	inner join generator g  (nolock) on r.generator_id = g.generator_id
	left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id
		and rt1.profit_ctr_id = r.profit_ctr_id
		and rt1.company_id = r.company_id
		and rt1.transporter_sequence_id = 1
	left outer join receipttransporter rt2  (nolock) on rt2.receipt_id = r.receipt_id
		and rt2.profit_ctr_id = r.profit_ctr_id
		and rt2.company_id = r.company_id
		and rt2.transporter_sequence_id = 2
	where 1=1
--		r.receipt_date between @start_date AND @end_date
		and (r.customer_id = @customer_id
			or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
			OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
		)
		-- AND (isnull(r.billing_project_id, 0) <> 145 OR (isnull(r.billing_project_id, 0) = 145 and r.customer_id <> 10673))
		and not exists (
			select receipt_id from billinglinklookup bll (nolock) 
			where bll.company_id = r.company_id
			and bll.profit_ctr_id = r.profit_ctr_id
			and bll.receipt_id = r.receipt_id
			union all
			select receipt_id from WMReceiptWorkorderTransporter rwt (nolock) 
			where rwt.receipt_company_id = r.company_id
			and rwt.receipt_profit_ctr_id = r.profit_ctr_id
			and rwt.receipt_id = r.receipt_id
			and rwt.workorder_id is not null
		)


-- Fix #ReceiptTransporter records...

	--	PRINT 'Can''t allow null transporter1 and populated transporter2, so move the data to transporter1 field.'
		UPDATE #WMReceiptTransporter set transporter1 = transporter2
		WHERE ISNULL(transporter1, '') = '' and ISNULL(transporter2, '') <> ''

	--	PRINT 'Can''t have the same transporter for both fields.'
		UPDATE #WMReceiptTransporter set transporter2 = null
		WHERE transporter2 = transporter1


-- Receipts
INSERT #Extract
SELECT distinct
	-- Walmart Fields:
	g.site_code AS site_code,
	g.generator_city AS generator_city,
	g.generator_state AS generator_state,
	wrt.service_date,
	-- coalesce(r.Load_Generator_EPA_ID, g.epa_id, '') AS epa_id,
	g.epa_id,
	r.manifest AS manifest,
	CASE WHEN ISNULL(r.manifest_line, '') <> '' THEN
		CASE WHEN IsNumeric(r.manifest_line) <> 1 THEN
			dbo.fn_convert_manifest_line(r.manifest_line, r.manifest_page_num)
		ELSE
			r.manifest_line
		END
	ELSE
		NULL
	END AS manifest_line,
	CASE WHEN isnull(p.hazmat, 'F') = 'T' THEN
		round( 
		 ISNULL(
		  ISNULL((SELECT (isnull(rp.bill_quantity, 0) / isnull(r.quantity, 0)) * ISNULL( SUM(container_weight), 0) 
		   FROM container con (nolock)
		   WHERE con.company_id = R.company_id
			AND con.profit_ctr_id = R.profit_ctr_id
			AND con.receipt_id = R.receipt_id
			AND con.line_id = R.line_id
			AND con.container_type = 'R'
			AND con.status <> 'V')
		  , r.net_weight)
		 , 0)
		, 0)
	ELSE
		0
	END
	as haz_pounds,
	CASE WHEN isnull(p.hazmat, 'F') = 'F' THEN
		round( 
		 ISNULL(
		  ISNULL((SELECT (isnull(rp.bill_quantity, 0) / isnull(r.quantity, 0)) * ISNULL( SUM(container_weight), 0) 
		   FROM container con (nolock)
		   WHERE con.company_id = R.company_id
			AND con.profit_ctr_id = R.profit_ctr_id
			AND con.receipt_id = R.receipt_id
			AND con.line_id = R.line_id
			AND con.container_type = 'R'
			AND con.status <> 'V')
		  , r.net_weight)
		 , 0)
		, 0)
	ELSE
		0
	END
	as nonhaz_pounds,
	b.bill_unit_desc AS bill_unit_desc,
	ISNULL(RP.bill_quantity, 0) AS quantity,
	p.Approval_desc AS waste_desc,
	COALESCE(replace(r.approval_code, 'WM' + right('0000' + g.site_code, 4), 'WM'), r.service_desc) AS approval_or_resource,
	NULL as dot_description,		-- Populated later
	null as waste_code_1,			-- Populated later
	null as waste_code_2,			-- Populated later
	null as waste_code_3,			-- Populated later
	null as waste_code_4,			-- Populated later
	null as waste_code_5,			-- Populated later
	null as state_waste_code_1,		-- Populated later
	tr.management_code,
	pr.profit_ctr_name AS receiving_facility,
	(select epa_id from profitcenter (nolock) where company_id = r.company_id and profit_ctr_id = r.profit_ctr_id) AS receiving_facility_epa_id,
	wrt.receipt_id,
	
	-- EQ Fields:
	wrt.company_id,
	wrt.profit_ctr_id,
	r.line_id,
	r.generator_id,
	g.generator_name AS generator_name,
	g.site_type AS site_type,
	r.manifest_page_num AS manifest_page,
	r.trans_type AS item_type,
	NULL AS tsdf_approval_id,
	r.profile_id,
	ISNULL(r.container_count, 0) AS container_count,
	dbo.fn_receipt_waste_code_list(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id) AS waste_codes,
	dbo.fn_receipt_waste_code_list_state(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id) AS state_waste_codes,
	wrt.transporter1 as transporter1_code,
	wrt.transporter2 as transporter2_code,
	r.receipt_date as date_delivered,
	'Receipt' AS source_table,
	r.receipt_date AS receipt_date,
	wrt.receipt_workorder_id,
	wrt.service_date AS workorder_start_date,
	wrt.workorder_company_id,
	wrt.workorder_profit_ctr_id,
	r.customer_id AS customer_id,
	p.hazmat as haz_flag
	
FROM Receipt r (nolock) 
INNER JOIN ReceiptPrice rp  (nolock) ON
	/* r.link_Receipt_ReceiptPrice = rp.link_Receipt_ReceiptPrice */
	R.receipt_id = rp.receipt_id
	and r.company_id = rp.company_id
	and r.profit_ctr_id = rp.profit_ctr_id
	and r.line_id = rp.line_id
INNER JOIN Generator g  (nolock) ON r.generator_id = g.generator_id
INNER JOIN BillUnit b  (nolock) ON rp.bill_unit_code = b.bill_unit_code
INNER JOIN #WMReceiptTransporter wrt ON
	r.company_id = wrt.company_id
	and r.profit_ctr_id = wrt.profit_ctr_id
	and r.receipt_id = wrt.receipt_id
	and r.line_id = wrt.line_id
INNER JOIN ProfitCenter pr  (nolock) on r.company_id = pr.company_id and r.profit_ctr_id = pr.profit_ctr_id
INNER JOIN Billing Billing  (nolock) ON
	r.receipt_id = Billing.receipt_id
	AND r.company_id = Billing.company_id
	AND r.profit_ctr_id = Billing.profit_ctr_id
	AND r.line_id = Billing.line_id
	and rp.price_id = Billing.price_id
	AND Billing.trans_source = 'R'
	AND Billing.status_code = 'I'
LEFT OUTER JOIN Profile p  (nolock) ON r.profile_id = p.profile_id
LEFT OUTER JOIN Treatment tr  (nolock) ON r.treatment_id = tr.treatment_id
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
LEFT OUTER JOIN ProfileQuoteApproval pqa  (nolock)
	on r.profile_id = pqa.profile_id 
	and r.company_id = pqa.company_id 
	and r.profit_ctr_id = pqa.profit_ctr_id 
	and pqa.status = 'A'
LEFT OUTER JOIN DisposalService ds  (nolock)
	on pqa.disposal_service_id = ds.disposal_service_id
WHERE 
billing.invoice_date BETWEEN @start_date AND @end_date
AND r.submitted_flag = 'T'
and r.receipt_status = 'A'
AND ISNULL(r.trans_type, '') = 'D'
AND ISNULL(g.site_type, '') IN (SELECT site_type from #SiteTypeToInclude)
GROUP BY
	g.site_code,
	g.generator_city,
	g.generator_state,
	wrt.service_date,
	-- r.load_generator_EPA_ID,
	g.EPA_ID,
	r.manifest,
	r.manifest_page_num,
	r.manifest_line,
	p.hazmat,
	r.net_weight,
	b.bill_unit_desc,
	r.quantity,
	rp.bill_quantity,
	p.approval_desc,
	g.site_code,
	r.approval_code,
	g.site_code,
	r.approval_code,
	r.service_desc,
	tr.management_code,
	pr.profit_ctr_name,
	r.company_id,
	r.profit_ctr_id,
	wrt.receipt_id,
	wrt.company_id,
	wrt.profit_ctr_id,
	r.line_id,
	r.generator_id,
	g.generator_name,
	g.site_type,
	r.manifest_page_num,
	r.trans_type,
	r.profile_id,
	r.container_count,
	r.line_id,
	r.receipt_id,
	r.profit_ctr_id,
	r.company_id,
	r.line_id,
	r.receipt_id,
	r.profit_ctr_id,
	r.company_id,
	wrt.transporter1,
	wrt.transporter2,
	r.receipt_date,
	wrt.receipt_workorder_id,
	wrt.service_date,
	wrt.workorder_company_id,
	wrt.workorder_profit_ctr_id,
	r.customer_id,
	p.hazmat



-- No-Waste Pickup Records:
INSERT #Extract
SELECT DISTINCT
	-- Walmart Fields:
	g.site_code AS site_code,
	g.generator_city AS generator_city,
	g.generator_state AS generator_state,
	w.start_date AS service_date,
	g.epa_id AS epa_id,
	null AS manifest,
	1 AS manifest_line,
	0 AS haz_pounds,
	0 as nonhaz_pounds,
	null AS bill_unit_desc,
	0 AS quantity,
	'No waste picked up' AS waste_desc,
	null as approval_or_resource,
	null as dot_description,
	null as waste_code_1,
	null as waste_code_2,
	null as waste_code_3,
	null as waste_code_4,
	null as waste_code_5,
	null as state_waste_code_1,
	null AS management_code,
	null AS receiving_facility,
	null AS receiving_facility_epa_id,
	d.workorder_id as receipt_id,

	-- EQ Fields:
	w.company_id,
	w.profit_ctr_id,
	null as sequence_id,
	g.generator_id,
	g.generator_name AS generator_name,
	g.site_type AS site_type,
	null AS manifest_page,
	'N' AS item_type,
	null as tsdf_approval_id,
	NULL AS profile_id,
	0 AS container_count,
	'' AS waste_codes,
	'' AS state_waste_codes,
	null as transporter1_code,
	null as transporter2_code,
	null AS date_delivered,
	'Workorder' AS source_table,
	NULL AS receipt_date,
	NULL AS receipt_workorder_id,
	w.start_date AS workorder_start_date,
	NULL AS workorder_company_id,
	NULL AS workorder_profit_ctr_id,
	w.customer_id AS customer_id,
	null AS haz_flag
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN Generator g  (nolock) ON w.generator_id = g.generator_id
INNER JOIN Billing Billing  (nolock) ON
	d.workorder_id = Billing.receipt_id
	AND d.company_id = Billing.company_id
	AND d.profit_ctr_id = Billing.profit_ctr_id
	AND d.resource_type = Billing.workorder_resource_type
	AND d.sequence_id = Billing.workorder_sequence_id
	AND Billing.trans_source = 'W'
	AND Billing.status_code = 'I'
LEFT OUTER JOIN TSDFApproval t  (nolock) ON d.tsdf_approval_id = t.tsdf_approval_id
	AND d.company_id = t.company_id
	AND d.profit_ctr_id = t.profit_ctr_id
LEFT OUTER JOIN TSDF t2  (nolock) ON d.tsdf_code = t2.tsdf_code
WHERE 1=1
	AND (w.customer_id = @customer_id
		OR w.generator_id IN (SELECT generator_id FROM customergenerator  (nolock) WHERE customer_id = @customer_id)
		OR w.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
	)
	AND billing.invoice_date BETWEEN @start_date AND @end_date
	AND w.submitted_flag = 'T'
	AND w.workorder_status IN ('A','C','D','N','P','X')
	-- AND (isnull(w.billing_project_id, 0) <> 145 OR (isnull(w.billing_project_id, 0) = 145 and w.customer_id <> 10673))
	AND ISNULL(g.site_type, '') IN (SELECT site_type from #SiteTypeToInclude)
	AND d.resource_class_code = 'STOPFEE'
    AND w.decline_id > 1

-- per Brie, for wm-extracts, don't include waste_codes that aren't State or Federal...
IF @output_mode = 'wm-extract' BEGIN
	UPDATE #Extract set
	    waste_codes = dbo.fn_waste_code_filter (waste_codes, 'F'),
	    state_waste_codes = dbo.fn_waste_code_filter (state_waste_codes, 'S')
	WHERE submitted_flag = 'T'

	-- Now, if there's no waste codes, print NONE.
	UPDATE #Extract set
	    waste_codes = 'NONE'
	WHERE replace(isnull(waste_codes,''), ',', '') = ''
	UPDATE #Extract set
	    state_waste_codes = 'NONE'
	WHERE replace(isnull(state_waste_codes, ''), ',', '') = ''
END
 
-- Update fields left null in #Extract
UPDATE #Extract set
	dot_description =
		CASE WHEN #Extract.tsdf_approval_id IS NOT NULL THEN
			(SELECT DOT_shipping_name FROM tsdfapproval  (nolock) WHERE tsdf_approval_id = #Extract.tsdf_approval_id)
		ELSE
			CASE WHEN #Extract.profile_id IS NOT NULL THEN
				left(dbo.fn_manifest_dot_description('P', #Extract.profile_id), 255)
			ELSE
				''
			END
		END,
	waste_code_1  = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes,  1)), '.', 'none')),
	waste_code_2  = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes,  2)), '.', 'none')),
	waste_code_3  = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes,  3)), '.', 'none')),
	waste_code_4  = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes,  4)), '.', 'none')),
	waste_code_5  = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes,  5)), '.', 'none')),
	state_waste_code_1 = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, state_waste_codes, 1)), '.', 'none'))

/*
Texas waste codes are 8 digits, and wouldn't fit into the wastecode table's waste_code field.
BUT, the waste_code field on those records is unique, so EQ systems handle it correctly, but we
need to remember to update the extract to swap the waste_description (the TX 8 digit code) for
the waste_code for waste_codes that are from TX.
*/
UPDATE #Extract SET state_waste_code_1 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_1 = wc.waste_code


-- #Extract is finished now.



/* *************************************************************

Validate Phase...

	Run the Validation every time, but may not be exported below...

	Look for missing waste codes
	Look for 0 weight lines
	Look for blank service_date
	Look for blank Facility Number
	Look for missing dot descriptions
	Look for missing waste descriptions

************************************************************** */


-- Create list of Missing Waste Code
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	from #Extract (nolock) where
	replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes, 1)), '.', 'NONE') = ''
	AND
	replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, state_waste_codes, 1)), '.', 'NONE') = ''
	AND waste_desc <> 'No waste picked up'
	and manifest_line is not null
	and item_type in ('A', 'D', 'N')
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT #validation SELECT 2, 'Missing Waste Codes: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of missing Weights
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	from #Extract (nolock) where haz_pounds = 0
	AND nonhaz_pounds = 0
	AND waste_desc <> 'No waste picked up'
	AND item_type in ('A', 'D')
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT #validation SELECT 3, 'Missing Weights: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of missing Service Dates
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	from #Extract (nolock) where isnull(service_date, '') = ''
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT #validation SELECT 4, 'Missing Service Dates: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of receipts missing workorders
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + CONVERT(varchar(20), receipt_id)
	from #Extract (nolock) where source_table = 'Receipt' and isnull(receipt_workorder_id, '') = ''
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT #validation SELECT 5, 'Receipt missing Workorder: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of missing site codes
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	from #Extract (nolock) where site_code = ''
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT #validation SELECT 6, 'Missing Generator Site Code: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create count of receipt-based records in extract
	INSERT #validation SELECT 100, 'Count of Receipt-based records in Extract:',
	CONVERT(varchar(20), count(*)), null, null
	from #Extract (nolock) 
	WHERE source_table = 'Receipt'

-- Create count of workorder-based records in extract
	INSERT #validation SELECT 101, 'Count of Workorder-based records in Extract:',
	CONVERT(varchar(20), count(*)), null, null
	from #Extract (nolock) 
	WHERE source_table = 'Workorder'
	AND waste_desc <> 'No waste picked up'

-- Create count of no-waste-pickup records in extract
	INSERT #validation SELECT 102, 'Count of No-Waste Pickups in Extract:',
	CONVERT(varchar(20), count(*)), null, null
	from #Extract (nolock) 
	WHERE source_table = 'Workorder'
	AND waste_desc = 'No waste picked up'

-- Create list of unusually high number of manifest names
	INSERT #validation
	SELECT 10, 'Unusual number of manifests/lines named: ' + isnull(manifest, '') + ' line ' + isnull(CONVERT(varchar(10), Manifest_Line), ''),
	CONVERT(varchar(20), count(*)) + ' times', null, null from #Extract (nolock) 
	where waste_desc <> 'No waste picked up'
	GROUP BY manifest, Manifest_Line
	HAVING COUNT(*) > 2
	ORDER BY COUNT(*) DESC

-- Create list of missing dot descriptions
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' :' + CONVERT(varchar(20), receipt_id)
	FROM #Extract (nolock) where
		ISNULL(
			CASE WHEN #Extract.tsdf_approval_id IS NOT NULL THEN
				dbo.fn_manifest_dot_description('T', #Extract.tsdf_approval_id)
			ELSE
				CASE WHEN #Extract.profile_id IS NOT NULL THEN
					dbo.fn_manifest_dot_description('P', #Extract.profile_id)
				ELSE
					''
				END
			END
		, '') = ''
	and approval_or_resource not in ('STOPFEE', 'GASSUR%')
	and waste_desc <> 'No waste picked up'
	GROUP BY company_id, profit_ctr_id, receipt_id ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT #validation SELECT 12, 'Missing DOT Description: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of missing waste descriptions
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + CONVERT(varchar(20), receipt_id)
	FROM #Extract (nolock) where waste_desc = ''
	and approval_or_resource not in ('STOPFEE', 'GASSUR%')
	and waste_desc <> 'No waste picked up'
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT #validation SELECT 13, 'Missing Waste Description: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of look-alike generators not assigned to WM yet:
	INSERT #MissingGenerators
	SELECT generator_id, epa_id, generator_name, generator_city, generator_state, site_code, site_type, status
	FROM Generator (nolock) 
	WHERE (
		(generator_name LIKE '%wal%' AND generator_name LIKE '%mart%')
		OR
		(generator_name LIKE '%sam%' AND generator_name LIKE '%club%')
		OR
		(generator_name LIKE '%nei%' AND generator_name LIKE '%hood%' AND generator_name LIKE '%wal%')
		)
	AND generator_id NOT IN (SELECT generator_id FROM CustomerGenerator (nolock) WHERE customer_id = @customer_id)
	ORDER BY generator_state, generator_city, site_code



/* *************************************************************

Export Phase...

	Only export 1 kind of output per SP run

************************************************************** */

IF @output_mode = 'validation' BEGIN

		-----------------------------------------------------------
		-- Always keep at least 5 copies
		-----------------------------------------------------------
		SELECT DISTINCT TOP 5 added_by, date_added 
		INTO #extracts_to_keep1
		FROM EQ_Extract..WalmartDCDisposalValidation
		ORDER BY date_added DESC

		-----------------------------------------------------------
		-- Delete old extracts, but leave at least the last 5
		-----------------------------------------------------------
		DELETE FROM EQ_Extract..WalmartDCDisposalValidation
		WHERE date_added < @days_before_delete
		AND date_added NOT IN (
			SELECT date_added FROM #extracts_to_keep1
		)


		INSERT EQ_Extract.dbo.WalmartDCDisposalValidation
		SELECT
			v_id,
			reason,
			problem_ids,
			prod_value,
			extract_value,
			@usr,
			@extract_datetime
		FROM #validation

-- Update Run information
	UPDATE EQ_Extract..ExtractLog SET
		end_date = GETDATE(),
		extract_table = 'EQ_Extract.dbo.WalmartDCDisposalValidation',
		record_count = @@rowcount
	WHERE
		extract_command = @sp_name_args
		AND date_added = @extract_datetime
		AND added_by = @usr				

		SELECT
			v_id,
			reason,
			problem_ids,
			prod_value,
			extract_value
		FROM EQ_Extract.dbo.WalmartDCDisposalValidation
		WHERE
			added_by = @usr
			AND date_added = @extract_datetime
			AND (
				problem_ids is not null
				OR
				prod_value <> extract_value
			)
		ORDER BY
			v_id
END

IF @output_mode = 'generators' BEGIN

		-----------------------------------------------------------
		-- Always keep at least 5 copies
		-----------------------------------------------------------
		SELECT DISTINCT TOP 5 added_by, date_added 
		INTO #extracts_to_keep2
		FROM EQ_Extract..WalmartMissingGenerators
		ORDER BY date_added DESC

		-----------------------------------------------------------
		-- Delete old extracts, but leave at least the last 5
		-----------------------------------------------------------
		DELETE FROM EQ_Extract..WalmartMissingGenerators
		WHERE date_added < @days_before_delete
		AND date_added NOT IN (
			SELECT date_added FROM #extracts_to_keep2
		)

		INSERT EQ_Extract.dbo.WalmartMissingGenerators
		SELECT
			generator_id,
			epa_id,
			generator_name,
			generator_city,
			generator_state,
			site_code,
			site_type,
			status,
			@usr,
			@extract_datetime
		FROM #MissingGenerators

-- Update Run information
	UPDATE EQ_Extract..ExtractLog SET
		end_date = GETDATE(),
		extract_table = 'EQ_Extract.dbo.WalmartMissingGenerators',
		record_count = @@rowcount
	WHERE
		extract_command = @sp_name_args
		AND date_added = @extract_datetime
		AND added_by = @usr				

		SELECT
			generator_id,
			epa_id,
			generator_name,
			generator_city,
			generator_state,
			site_code,
			site_type,
			status
		FROM EQ_Extract.dbo.WalmartMissingGenerators
		WHERE
			added_by = @usr
			AND date_added = @extract_datetime
END

IF @output_mode = 'wm-extract' BEGIN

		-----------------------------------------------------------
		-- Always keep at least 5 copies
		-----------------------------------------------------------
		SELECT DISTINCT TOP 5 added_by, date_added 
		INTO #extracts_to_keep3
		FROM EQ_Extract..WalmartDCDisposalExtract
		ORDER BY date_added DESC

		-----------------------------------------------------------
		-- Delete old extracts, but leave at least the last 5
		-----------------------------------------------------------
		DELETE FROM EQ_Extract..WalmartDCDisposalExtract
		WHERE date_added < @days_before_delete
		AND date_added NOT IN (
			SELECT date_added FROM #extracts_to_keep3
		)
		
		INSERT EQ_Extract.dbo.WalmartDCDisposalExtract (
			site_code,
			generator_city,
			generator_state,
			service_date,
			epa_id,
			manifest,
			manifest_line,
			haz_pounds,
			nonhaz_pounds,
			bill_unit_desc,
			quantity,
			waste_desc,
			approval_or_resource,
			dot_description,
			waste_code_1,
			waste_code_2,
			waste_code_3,
			waste_code_4,
			waste_code_5,
			state_waste_code_1,
			management_code,
			receiving_facility,
			receiving_facility_epa_id,
			receipt_id,
			company_id,
			profit_ctr_id,
			line_sequence_id,
			generator_id,
			generator_name,
			site_type,
			manifest_page,
			item_type,
			tsdf_approval_id,
			profile_id,
			container_count,
			waste_codes,
			state_waste_codes,
			transporter1_code,
			transporter2_code,
			date_delivered,
			source_table,
			receipt_date,
			receipt_workorder_id,
			workorder_start_date,
			workorder_company_id,
			workorder_profit_ctr_id,
			customer_id,
			haz_flag,
			added_by,
			date_added		
		)
		SELECT
			-- Walmart Fields:
			site_code,
			generator_city,
			generator_state,
			service_date,
			epa_id,
			manifest,
			manifest_line,
			haz_pounds,
			nonhaz_pounds,
			bill_unit_desc,
			quantity,
			waste_desc,
			approval_or_resource,
			dot_description,
			waste_code_1,
			waste_code_2,
			waste_code_3,
			waste_code_4,
			waste_code_5,
			state_waste_code_1,
			management_code,
			receiving_facility,
			receiving_facility_epa_id,
			receipt_id,

			-- EQ Fields:
			company_id,
			profit_ctr_id,
			line_sequence_id,
			generator_id,
			generator_name,
			site_type,
			manifest_page,
			item_type,
			tsdf_approval_id,
			profile_id,
			container_count,
			waste_codes,
			state_waste_codes,
			transporter1_code,
			transporter2_code,
			date_delivered,
			source_table,
			receipt_date,
			receipt_workorder_id,
			workorder_start_date,
			workorder_company_id,
			workorder_profit_ctr_id,
			customer_id,
			haz_flag,
			@usr,
			@extract_datetime
		FROM #Extract (nolock) 
 			 
-- Update Run information
	UPDATE EQ_Extract..ExtractLog SET
		end_date = GETDATE(),
		extract_table = 'EQ_Extract.dbo.WalmartDCDisposalExtract',
		record_count = @@rowcount
	WHERE
		extract_command = @sp_name_args
		AND date_added = @extract_datetime
		AND added_by = @usr				

		SELECT
			ISNULL(site_code, '') AS 'DC Number',
			ISNULL(generator_city, '') AS 'City',
			ISNULL(generator_state, '') AS 'State',
			ISNULL(CONVERT(varchar(20), service_date, 101), '') AS 'Service Date',
			ISNULL(epa_id, '') AS 'EPA ID',
			ISNULL(manifest, '') AS 'Manifest',
			ISNULL(NULLIF(manifest_line, 0), '') AS 'Manifest Line',
			ISNULL(haz_pounds, '') AS 'Haz (lbs)',
			ISNULL(nonhaz_pounds, '') AS 'Non-Haz (lbs)',
			ISNULL(bill_unit_desc, '') AS 'Container Type',
			ISNULL(quantity, '') AS 'Container Quantity',
			ISNULL(waste_desc, '') AS 'Waste Description',
			ISNULL(approval_or_resource, '') AS 'Waste Profile Number',
			ISNULL(dot_description, '') AS 'DOT Description',
			ISNULL(waste_code_1, '') AS 'Waste Code 1',
			ISNULL(waste_code_2, '') AS 'Waste Code 2',
			ISNULL(waste_code_3, '') AS 'Waste Code 3',
			ISNULL(waste_code_4, '') AS 'Waste Code 4',
			ISNULL(waste_code_5, '') AS 'Waste Code 5',
			ISNULL(state_waste_code_1, '') AS 'State Waste Code 1',
			ISNULL(management_code, '') AS 'Management Code',
			ISNULL(receiving_facility, '') AS 'Receiving Facility',
			ISNULL(receiving_facility_epa_id, '') AS 'Receiving Facility EPA ID Number',
			receipt_id AS 'Receipt ID'
		FROM EQ_Extract.dbo.WalmartDCDisposalExtract
		WHERE
			added_by = @usr
			AND date_added = @extract_datetime
		ORDER BY
			generator_state,
			generator_city,
			site_code,
			service_date,
			receipt_id

END

IF @output_mode = 'eq-extract' BEGIN

		-----------------------------------------------------------
		-- Always keep at least 5 copies
		-----------------------------------------------------------
		SELECT DISTINCT TOP 5 added_by, date_added 
		INTO #extracts_to_keep4
		FROM EQ_Extract..WalmartDCDisposalExtract
		ORDER BY date_added DESC

		-----------------------------------------------------------
		-- Delete old extracts, but leave at least the last 5
		-----------------------------------------------------------
		DELETE FROM EQ_Extract..WalmartDCDisposalExtract
		WHERE date_added < @days_before_delete
		AND date_added NOT IN (
			SELECT date_added FROM #extracts_to_keep4
		)
		
		INSERT EQ_Extract.dbo.WalmartDCDisposalExtract (
			site_code,
			generator_city,
			generator_state,
			service_date,
			epa_id,
			manifest,
			manifest_line,
			haz_pounds,
			nonhaz_pounds,
			bill_unit_desc,
			quantity,
			waste_desc,
			approval_or_resource,
			dot_description,
			waste_code_1,
			waste_code_2,
			waste_code_3,
			waste_code_4,
			waste_code_5,
			state_waste_code_1,
			management_code,
			receiving_facility,
			receiving_facility_epa_id,
			receipt_id,
			company_id,
			profit_ctr_id,
			line_sequence_id,
			generator_id,
			generator_name,
			site_type,
			manifest_page,
			item_type,
			tsdf_approval_id,
			profile_id,
			container_count,
			waste_codes,
			state_waste_codes,
			transporter1_code,
			transporter2_code,
			date_delivered,
			source_table,
			receipt_date,
			receipt_workorder_id,
			workorder_start_date,
			workorder_company_id,
			workorder_profit_ctr_id,
			customer_id,
			haz_flag,
			added_by,
			date_added		
		)
		SELECT
			-- Walmart Fields:
			site_code,
			generator_city,
			generator_state,
			service_date,
			epa_id,
			manifest,
			manifest_line,
			haz_pounds,
			nonhaz_pounds,
			bill_unit_desc,
			quantity,
			waste_desc,
			approval_or_resource,
			dot_description,
			waste_code_1,
			waste_code_2,
			waste_code_3,
			waste_code_4,
			waste_code_5,
			state_waste_code_1,
			management_code,
			receiving_facility,
			receiving_facility_epa_id,
			receipt_id,

			-- EQ Fields:
			company_id,
			profit_ctr_id,
			line_sequence_id,
			generator_id,
			generator_name,
			site_type,
			manifest_page,
			item_type,
			tsdf_approval_id,
			profile_id,
			container_count,
			waste_codes,
			state_waste_codes,
			transporter1_code,
			transporter2_code,
			date_delivered,
			source_table,
			receipt_date,
			receipt_workorder_id,
			workorder_start_date,
			workorder_company_id,
			workorder_profit_ctr_id,
			customer_id,
			haz_flag,
			@usr,
			@extract_datetime
		FROM #Extract (nolock) 
		ORDER BY
			generator_state,
			generator_city,
			site_code,
			service_date,
			receipt_id,
			manifest_line
 			 
-- Update Run information
	UPDATE EQ_Extract..ExtractLog SET
		end_date = GETDATE(),
		extract_table = 'EQ_Extract.dbo.WalmartDCDisposalExtract',
		record_count = @@rowcount
	WHERE
		extract_command = @sp_name_args
		AND date_added = @extract_datetime
		AND added_by = @usr		
		
		SELECT
			*
		FROM EQ_Extract.dbo.WalmartDCDisposalExtract
		WHERE
			added_by = @usr
			AND date_added = @extract_datetime
		ORDER BY
			generator_state,
			generator_city,
			site_code,
			service_date,
			receipt_id,
			manifest_line

END



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_walmart_dc_disposal] TO [EQAI]
    AS [dbo];

