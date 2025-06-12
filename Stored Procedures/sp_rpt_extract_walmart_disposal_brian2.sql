/* -- Commented 6/21/2019 -JPB: deprecated function

CREATE PROCEDURE sp_rpt_extract_walmart_disposal_brian2 (
	@start_date				datetime,
	@end_date				datetime,
	@output_mode			varchar(20)		-- one of: 'validation', 'generators', 'wm-extract', 'eq-extract', 'manifests'
)
AS
/* ***********************************************************

	sp_rpt_extract_walmart_disposal_brian2 '1/1/2009 00:00', '1/31/2009 23:59', 'validation'
	sp_rpt_extract_walmart_disposal_brian2 '1/1/2009 00:00', '1/31/2009 23:59', 'wm-extract'
	
	sp_rpt_extract_walmart_disposal_brian2 '10/1/2008 00:00', '9/30/2009 23:59', 'eq-extract'
	sp_rpt_extract_walmart_disposal_brian2 '1/1/2009 00:00', '1/31/2009 23:59', 'eq-extract'

*********************************************************** */

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
		'Walmart Disposal',
		@sp_name_args,
		GETDATE(),
		null,
		null,
		null,
		@extract_datetime,
		@usr
	)

-- EQ_Temp table housekeeping
-- Deletes temp data more than 2 days old, or by this user (past runs)
DELETE FROM EQ_TEMP.dbo.WalmartDisposalExtract where date_added < dateadd(dd, -2, getdate())
DELETE FROM EQ_TEMP.dbo.WalmartDisposalExtract where added_by = @usr

DELETE FROM EQ_TEMP.dbo.WalmartDisposalReceiptTransporter where date_added < dateadd(dd, -2, getdate())
DELETE FROM EQ_TEMP.dbo.WalmartDisposalReceiptTransporter where added_by = @usr

DELETE FROM EQ_TEMP.dbo.WalmartExtractImages where date_added < dateadd(dd, -2, getdate())
DELETE FROM EQ_TEMP.dbo.WalmartExtractImages where added_by = @usr

DELETE FROM EQ_TEMP.dbo.WalmartDisposalValidation where date_added < dateadd(dd, -2, getdate())
DELETE FROM EQ_TEMP.dbo.WalmartDisposalValidation where added_by = @usr

DELETE FROM EQ_TEMP.dbo.WalmartMissingGenerators where date_added < dateadd(dd, -2, getdate())
DELETE FROM EQ_TEMP.dbo.WalmartMissingGenerators where added_by = @usr


-- Create table to store important site types for this query (saves on update/retype issues)
CREATE TABLE #SiteTypeToInclude (
	site_type		varchar(40)
)
-- Load #SiteTypeToInclude table values:
	-- INSERT #SiteTypeToInclude (site_type) VALUES ('Amigo')
	INSERT #SiteTypeToInclude (site_type) VALUES ('Neighborhood Market')
	INSERT #SiteTypeToInclude (site_type) VALUES ('Sams Club')
	INSERT #SiteTypeToInclude (site_type) VALUES ('Supercenter')
	INSERT #SiteTypeToInclude (site_type) VALUES ('Wal-Mart')
	INSERT #SiteTypeToInclude (site_type) VALUES ('Optical Lab')
	INSERT #SiteTypeToInclude (site_type) VALUES ('Wal-Mart Return Center')
	INSERT #SiteTypeToInclude (site_type) VALUES ('Wal-Mart PMDC')


-- Create table to store important site types for this query (saves on update/retype issues)
-- May conflict with the table above, but it happens...
CREATE TABLE #SiteTypeToExclude (
	site_type		varchar(40)
)
-- Load #SiteTypeToExclude table values:
	INSERT #SiteTypeToExclude (site_type) VALUES ('Sams DC')
	INSERT #SiteTypeToExclude (site_type) VALUES ('Wal-Mart DC')
	

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
INSERT EQ_Temp..WalmartDisposalExtract
SELECT DISTINCT
	-- Walmart Fields:
	g.site_code AS site_code,
	gst.generator_site_type_abbr AS site_type_abbr,
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
	ISNULL(d.pounds, 0) AS pounds,
	b.bill_unit_desc AS bill_unit_desc,
	-- ISNULL(d.quantity, 0) AS quantity,
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
	null as waste_code_6,			-- Populated later
	null as waste_code_7,			-- Populated later
	null as waste_code_8,			-- Populated later
	null as waste_code_9,			-- Populated later
	null as waste_code_10,			-- Populated later
	null as waste_code_11,			-- Populated later
	null as waste_code_12,			-- Populated later
	null as state_waste_code_1,		-- Populated later
	null as state_waste_code_2,		-- Populated later
	null as state_waste_code_3,		-- Populated later
	null as state_waste_code_4,		-- Populated later
	null as state_waste_code_5,		-- Populated later
	t.management_code AS management_code,
	t.EPA_source_code AS EPA_source_code,
	t.EPA_form_code AS EPA_form_code,
	null AS transporter1_name,		-- Populated later
	null as transporter1_epa_id,	-- Populated later
	null as transporter2_name,		-- Populated later
	null as transporter2_epa_id,	-- Populated later
	t2.TSDF_name AS receiving_facility,
	t2.TSDF_epa_id AS receiving_facility_epa_id,
	d.workorder_id as receipt_id,
	CASE 
		WHEN t.disposal_service_id = (select disposal_service_id from DisposalService where disposal_service_desc = 'Other')	THEN 
			t.disposal_service_other_desc
		ELSE
			ds.disposal_service_desc
	END as disposal_service_desc,

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
	t.hazmat as haz_flag,
	
	'T' as submitted_flag,
	@usr,
	@extract_datetime
	
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN Generator g  (nolock) ON w.generator_id = g.generator_id
INNER JOIN BillUnit b  (nolock) ON d.bill_unit_code = b.bill_unit_code
LEFT OUTER JOIN TSDFApproval t  (nolock) ON d.tsdf_approval_id = t.tsdf_approval_id
	AND d.company_id = t.company_id
	AND d.profit_ctr_id = t.profit_ctr_id
LEFT OUTER JOIN TSDF t2  (nolock) ON d.tsdf_code = t2.tsdf_code
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
LEFT OUTER JOIN WorkOrderManifest wom  (nolock) ON w.workorder_id = wom.workorder_id and w.company_id = wom.company_id and w.profit_ctr_id = wom.profit_ctr_id
LEFT OUTER JOIN DisposalService ds  (nolock) ON t.disposal_service_id = ds.disposal_service_id
WHERE 1=1
AND (w.customer_id = @customer_id
	OR w.generator_id IN (SELECT generator_id FROM customergenerator  (nolock) WHERE customer_id = @customer_id)
	OR w.generator_id IN (
		SELECT generator_id FROM generator (nolock) where site_type IN (
			SELECT site_type from #SiteTypeToInclude
		)
	)
)
AND w.start_date BETWEEN @start_date AND @end_date
AND ISNULL(t2.eq_flag, 'F') = 'F'
AND d.resource_type = 'D'
AND w.workorder_status IN ('A','C','D','N','P','X')
AND w.submitted_flag = 'T'
AND isnull(w.billing_project_id, 0) = 24
AND ISNULL(g.site_type, '') NOT IN (SELECT site_type from #SiteTypeToExclude)


-- NotSubmitted WOs
INSERT EQ_Temp..WalmartDisposalExtract
SELECT DISTINCT
	-- Walmart Fields:
	g.site_code AS site_code,
	gst.generator_site_type_abbr AS site_type_abbr,
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
	ISNULL(d.pounds, 0) AS pounds,
	b.bill_unit_desc AS bill_unit_desc,
	ISNULL(d.quantity, 0) AS quantity,
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
	null as waste_code_6,			-- Populated later
	null as waste_code_7,			-- Populated later
	null as waste_code_8,			-- Populated later
	null as waste_code_9,			-- Populated later
	null as waste_code_10,			-- Populated later
	null as waste_code_11,			-- Populated later
	null as waste_code_12,			-- Populated later
	null as state_waste_code_1,		-- Populated later
	null as state_waste_code_2,		-- Populated later
	null as state_waste_code_3,		-- Populated later
	null as state_waste_code_4,		-- Populated later
	null as state_waste_code_5,		-- Populated later
	t.management_code AS management_code,
	t.EPA_source_code AS EPA_source_code,
	t.EPA_form_code AS EPA_form_code,
	null AS transporter1_name,		-- Populated later
	null as transporter1_epa_id,	-- Populated later
	null as transporter2_name,		-- Populated later
	null as transporter2_epa_id,	-- Populated later
	t2.TSDF_name AS receiving_facility,
	t2.TSDF_epa_id AS receiving_facility_epa_id,
	d.workorder_id as receipt_id,
	CASE 
		WHEN t.disposal_service_id = (select disposal_service_id from DisposalService where disposal_service_desc = 'Other')	THEN 
			t.disposal_service_other_desc
		ELSE
			ds.disposal_service_desc
	END as disposal_service_desc,
	

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
	t.hazmat as haz_flag,
	
	'F' as submitted_flag,
	@usr,
	@extract_datetime
	
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN Generator g (nolock) ON w.generator_id = g.generator_id
INNER JOIN BillUnit b  (nolock) ON d.bill_unit_code = b.bill_unit_code
LEFT OUTER JOIN TSDFApproval t  (nolock) ON d.tsdf_approval_id = t.tsdf_approval_id
	AND d.company_id = t.company_id
	AND d.profit_ctr_id = t.profit_ctr_id
LEFT OUTER JOIN TSDF t2  (nolock) ON d.tsdf_code = t2.tsdf_code
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
LEFT OUTER JOIN WorkOrderManifest wom  (nolock) ON w.workorder_id = wom.workorder_id and w.company_id = wom.company_id and w.profit_ctr_id = wom.profit_ctr_id
LEFT OUTER JOIN DisposalService ds  (nolock) ON t.disposal_service_id = ds.disposal_service_id
WHERE 1=1
AND (w.customer_id = @customer_id
	OR w.generator_id IN (SELECT generator_id FROM customergenerator (nolock) WHERE customer_id = @customer_id)
	OR w.generator_id IN (
		SELECT generator_id FROM generator (nolock) where site_type IN (
			SELECT site_type from #SiteTypeToInclude
		)
	)
)
AND w.start_date BETWEEN @start_date AND @end_date
AND ISNULL(t2.eq_flag, 'F') = 'F'
AND d.resource_type = 'D'
AND w.workorder_status IN ('A','C','D','N','P','X')
AND w.submitted_flag <> 'T'
AND isnull(w.billing_project_id, 0) = 24
AND ISNULL(g.site_type, '') NOT IN (SELECT site_type from #SiteTypeToExclude)



--	PRINT 'Receipt/Transporter Fix'
/*
This query has 3 union'd components:
first component: workorder inner join to billinglinklookup and receipt
second component: receipt inner join to WMReceiptWorkorderTransporter and workorder
third component: receipt not linked to either BLL or WMRWT
*/
	INSERT 	EQ_Temp..WalmartDisposalReceiptTransporter
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
		CASE WHEN rt1.transporter_code IS NULL THEN
			r.hauler
		ELSE
			rt1.transporter_code 
		END as transporter1,
		rt2.transporter_code as transporter2,
		
		@usr,
		@extract_datetime
		
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
	where
		wo.start_date between @start_date AND @end_date
		and (1=0
			or wo.customer_id = @customer_id
			or wo.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
			OR wo.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
			or r.customer_id = @customer_id
			or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
			OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
		)
		AND isnull(wo.billing_project_id, 0) = 24
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
		CASE WHEN rt1.transporter_code IS NULL THEN
			r.hauler
		ELSE
			rt1.transporter_code 
		END as transporter1,
		rt2.transporter_code as transporter2,
		
		@usr,
		@extract_datetime
		
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
	where
		wo.start_date between @start_date AND @end_date
		and (1=0
			or wo.customer_id = @customer_id
			or wo.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
			OR wo.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
			or r.customer_id = @customer_id
			or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
			OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
		)
		AND isnull(r.billing_project_id, 0) = 24
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
			where
			wo.start_date between @start_date AND @end_date
			and (1=0
				or wo.customer_id = @customer_id
				or wo.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
				OR wo.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
				or r.customer_id = @customer_id
				or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
				OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
			)
			AND isnull(wo.billing_project_id, 0) = 24
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
		CASE WHEN rt1.transporter_code IS NULL THEN
			r.hauler
		ELSE
			rt1.transporter_code 
		END as transporter1,
		rt2.transporter_code as transporter2,
		
		@usr,
		@extract_datetime
		
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
	where
		r.receipt_date between @start_date AND @end_date
		and (r.customer_id = @customer_id
			or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id = @customer_id)
			OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
		)
		AND isnull(r.billing_project_id, 0) = 24
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
		UPDATE EQ_Temp..WalmartDisposalReceiptTransporter set transporter1 = transporter2
		WHERE ISNULL(transporter1, '') = '' and ISNULL(transporter2, '') <> ''
		AND added_by = @usr and date_added = @extract_datetime

	--	PRINT 'Can''t have the same transporter for both fields.'
		UPDATE EQ_Temp..WalmartDisposalReceiptTransporter set transporter2 = null
		WHERE transporter2 = transporter1
		AND added_by = @usr and date_added = @extract_datetime


-- Receipts
INSERT EQ_TEMP.dbo.WalmartDisposalExtract
SELECT distinct
	-- Walmart Fields:
	g.site_code AS site_code,
	gst.generator_site_type_abbr AS site_type_abbr,
	g.generator_city AS generator_city,
	g.generator_state AS generator_state,
	wrt.service_date,
	coalesce(r.Load_Generator_EPA_ID, g.epa_id, '') AS epa_id,
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
	, 0) as pounds,

	b.bill_unit_desc AS bill_unit_desc,
	ISNULL(max(rp.bill_quantity), 0) AS quantity,
	p.Approval_desc AS waste_desc,
	COALESCE(replace(r.approval_code, 'WM' + right('0000' + g.site_code, 4), 'WM'), r.service_desc) AS approval_or_resource,
	NULL as dot_description,		-- Populated later
	null as waste_code_1,			-- Populated later
	null as waste_code_2,			-- Populated later
	null as waste_code_3,			-- Populated later
	null as waste_code_4,			-- Populated later
	null as waste_code_5,			-- Populated later
	null as waste_code_6,			-- Populated later
	null as waste_code_7,			-- Populated later
	null as waste_code_8,			-- Populated later
	null as waste_code_9,			-- Populated later
	null as waste_code_10,			-- Populated later
	null as waste_code_11,			-- Populated later
	null as waste_code_12,			-- Populated later
	null as state_waste_code_1,		-- Populated later
	null as state_waste_code_2,		-- Populated later
	null as state_waste_code_3,		-- Populated later
	null as state_waste_code_4,		-- Populated later
	null as state_waste_code_5,		-- Populated later
	tr.management_code,
	p.EPA_source_code,
	EPA_form_code,
	null AS transporter1_name,		-- Populated later
	null as transporter1_epa_id,	-- Populated later
	null as transporter2_name,		-- Populated later
	null as transporter2_epa_id,	-- Populated later
	pr.profit_ctr_name AS receiving_facility,
	(select epa_id from profitcenter  (nolock) where company_id = r.company_id and profit_ctr_id = r.profit_ctr_id) AS receiving_facility_epa_id,
	wrt.receipt_id,
	dbo.fn_wm_disposal_method(
		ds.disposal_service_desc,
		pqa.disposal_service_other_desc,
		pqa.ob_tsdf_approval_id,
		pqa.ob_eq_profile_id,
		pqa.ob_eq_company_id,
		pqa.ob_eq_profit_ctr_id) as disposal_service_desc,

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
	p.hazmat as haz_flag,

	'T' as submitted_flag,
	@usr as added_by,
	@extract_datetime as date_added
	
FROM Receipt r (nolock) 
INNER JOIN ReceiptPrice rp  (nolock) ON
	/* r.link_Receipt_ReceiptPrice = rp.link_Receipt_ReceiptPrice */
	R.receipt_id = rp.receipt_id
	and r.company_id = rp.company_id
	and r.profit_ctr_id = rp.profit_ctr_id
	and r.line_id = rp.line_id
INNER JOIN Generator g  (nolock) ON r.generator_id = g.generator_id
INNER JOIN BillUnit b  (nolock) ON rp.bill_unit_code = b.bill_unit_code
INNER JOIN EQ_Temp..WalmartDisposalReceiptTransporter wrt ON
	r.company_id = wrt.company_id
	and r.profit_ctr_id = wrt.profit_ctr_id
	and r.receipt_id = wrt.receipt_id
	and r.line_id = wrt.line_id
INNER JOIN ProfitCenter pr  (nolock) on r.company_id = pr.company_id and r.profit_ctr_id = pr.profit_ctr_id
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
WHERE r.submitted_flag = 'T'
and r.receipt_status = 'A'
AND r.fingerpr_status = 'A'
AND ISNULL(r.trans_type, '') = 'D'
AND ISNULL(g.site_type, '') NOT IN (SELECT site_type from #SiteTypeToExclude)
GROUP BY
	g.site_code,
	gst.generator_site_type_abbr,
	g.generator_city,
	g.generator_state,
	wrt.service_date,
	r.load_generator_EPA_ID,
	g.EPA_ID,
	r.manifest,
	r.manifest_page_num,
	r.manifest_line,
	r.net_weight,
	b.bill_unit_desc,
	r.quantity,
	rp.bill_quantity,
	p.approval_desc,
	r.approval_code,
	r.service_desc,
	tr.management_code,
	p.EPA_source_code,
	p.EPA_form_code,
	wrt.transporter1,
	wrt.transporter2,
	pr.profit_ctr_name,
	r.company_id,
	r.profit_ctr_id,
	wrt.receipt_id,
	pqa.OB_TSDF_Approval_id,
	pqa.ob_eq_profile_id,
	pqa.ob_eq_company_id,
	pqa.ob_eq_profit_ctr_id,
	pqa.disposal_service_id,
	pqa.disposal_service_other_desc,
	ds.disposal_service_desc,
	wrt.company_id,
	wrt.profit_ctr_id,
	r.line_id,
	r.generator_id,
	g.generator_name,
	g.site_type,
	r.trans_type,
	r.profile_id,
	r.container_count,
	r.receipt_id,
	r.receipt_date,
	wrt.receipt_workorder_id,
	wrt.workorder_company_id,
	wrt.workorder_profit_ctr_id,
	r.customer_id,
	p.hazmat



INSERT EQ_TEMP.dbo.WalmartDisposalExtract
SELECT distinct
	-- Walmart Fields:
	g.site_code AS site_code,
	gst.generator_site_type_abbr AS site_type_abbr,
	g.generator_city AS generator_city,
	g.generator_state AS generator_state,
	wrt.service_date,
	coalesce(r.Load_Generator_EPA_ID, g.epa_id, '') AS epa_id,
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
	, 0) as pounds,

	b.bill_unit_desc AS bill_unit_desc,
	ISNULL(max(rp.bill_quantity), 0) AS quantity,
	p.Approval_desc AS waste_desc,
	COALESCE(replace(r.approval_code, 'WM' + right('0000' + g.site_code, 4), 'WM'), r.service_desc) AS approval_or_resource,
	NULL as dot_description,		-- Populated later
	null as waste_code_1,			-- Populated later
	null as waste_code_2,			-- Populated later
	null as waste_code_3,			-- Populated later
	null as waste_code_4,			-- Populated later
	null as waste_code_5,			-- Populated later
	null as waste_code_6,			-- Populated later
	null as waste_code_7,			-- Populated later
	null as waste_code_8,			-- Populated later
	null as waste_code_9,			-- Populated later
	null as waste_code_10,			-- Populated later
	null as waste_code_11,			-- Populated later
	null as waste_code_12,			-- Populated later
	null as state_waste_code_1,		-- Populated later
	null as state_waste_code_2,		-- Populated later
	null as state_waste_code_3,		-- Populated later
	null as state_waste_code_4,		-- Populated later
	null as state_waste_code_5,		-- Populated later
	tr.management_code,
	p.EPA_source_code,
	EPA_form_code,
	null AS transporter1_name,		-- Populated later
	null as transporter1_epa_id,	-- Populated later
	null as transporter2_name,		-- Populated later
	null as transporter2_epa_id,	-- Populated later
	pr.profit_ctr_name AS receiving_facility,
	(select epa_id from profitcenter  (nolock) where company_id = r.company_id and profit_ctr_id = r.profit_ctr_id) AS receiving_facility_epa_id,
	wrt.receipt_id,
	dbo.fn_wm_disposal_method(
		ds.disposal_service_desc,
		pqa.disposal_service_other_desc,
		pqa.ob_tsdf_approval_id,
		pqa.ob_eq_profile_id,
		pqa.ob_eq_company_id,
		pqa.ob_eq_profit_ctr_id) as disposal_service_desc,

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
	p.hazmat as haz_flag,

	'F' as submitted_flag,
	@usr as added_by,
	@extract_datetime as date_added
	
FROM Receipt r (nolock) 
INNER JOIN ReceiptPrice rp  (nolock) ON
	/* r.link_Receipt_ReceiptPrice = rp.link_Receipt_ReceiptPrice */
	R.receipt_id = rp.receipt_id
	and r.company_id = rp.company_id
	and r.profit_ctr_id = rp.profit_ctr_id
	and r.line_id = rp.line_id
INNER JOIN Generator g  (nolock) ON r.generator_id = g.generator_id
INNER JOIN BillUnit b  (nolock) ON rp.bill_unit_code = b.bill_unit_code
INNER JOIN EQ_Temp..WalmartDisposalReceiptTransporter wrt ON
	r.company_id = wrt.company_id
	and r.profit_ctr_id = wrt.profit_ctr_id
	and r.receipt_id = wrt.receipt_id
	and r.line_id = wrt.line_id
INNER JOIN ProfitCenter pr  (nolock) on r.company_id = pr.company_id and r.profit_ctr_id = pr.profit_ctr_id
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
WHERE r.submitted_flag <> 'T'
and r.receipt_status = 'A'
AND r.fingerpr_status = 'A'
AND ISNULL(r.trans_type, '') = 'D'
AND ISNULL(g.site_type, '') NOT IN (SELECT site_type from #SiteTypeToExclude)
GROUP BY
	g.site_code,
	gst.generator_site_type_abbr,
	g.generator_city,
	g.generator_state,
	wrt.service_date,
	r.load_generator_EPA_ID,
	g.EPA_ID,
	r.manifest,
	r.manifest_page_num,
	r.manifest_line,
	r.net_weight,
	b.bill_unit_desc,
	r.quantity,
	rp.bill_quantity,
	p.approval_desc,
	r.approval_code,
	r.service_desc,
	tr.management_code,
	p.EPA_source_code,
	p.EPA_form_code,
	wrt.transporter1,
	wrt.transporter2,
	pr.profit_ctr_name,
	r.company_id,
	r.profit_ctr_id,
	wrt.receipt_id,
	pqa.OB_TSDF_Approval_id,
	pqa.ob_eq_profile_id,
	pqa.ob_eq_company_id,
	pqa.ob_eq_profit_ctr_id,
	pqa.disposal_service_id,
	pqa.disposal_service_other_desc,
	ds.disposal_service_desc,
	wrt.company_id,
	wrt.profit_ctr_id,
	r.line_id,
	r.generator_id,
	g.generator_name,
	g.site_type,
	r.trans_type,
	r.profile_id,
	r.container_count,
	r.receipt_id,
	r.receipt_date,
	wrt.receipt_workorder_id,
	wrt.workorder_company_id,
	wrt.workorder_profit_ctr_id,
	r.customer_id,
	p.hazmat


-- No-Waste Pickup Records:
INSERT EQ_TEMP.dbo.WalmartDisposalExtract
SELECT DISTINCT
	-- Walmart Fields:
	g.site_code AS site_code,
	gst.generator_site_type_abbr AS site_type_abbr,
	g.generator_city AS generator_city,
	g.generator_state AS generator_state,
	w.start_date AS service_date,
	g.epa_id AS epa_id,
	null AS manifest,
	1 AS manifest_line,
	0 AS pounds,
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
	null as waste_code_6,
	null as waste_code_7,
	null as waste_code_8,
	null as waste_code_9,
	null as waste_code_10,
	null as waste_code_11,
	null as waste_code_12,
	null as state_waste_code_1,
	null as state_waste_code_2,
	null as state_waste_code_3,
	null as state_waste_code_4,
	null as state_waste_code_5,
	null AS management_code,
	null AS EPA_source_code,
	null AS EPA_form_code,
	null AS transporter1_name,
	null as transporter1_epa_id,
	null AS transporter2_name,
	null as transporter2_epa_id,
	null AS receiving_facility,
	null AS receiving_facility_epa_id,
	d.workorder_id as receipt_id,
	null as disposal_service_desc,

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
	null AS haz_flag,

	'T' as submitted_flag,
	@usr as added_by,
	@extract_datetime as date_added
	
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN Generator g  (nolock) ON w.generator_id = g.generator_id
LEFT OUTER JOIN TSDFApproval t  (nolock) ON d.tsdf_approval_id = t.tsdf_approval_id
	AND d.company_id = t.company_id
	AND d.profit_ctr_id = t.profit_ctr_id
LEFT OUTER JOIN TSDF t2  (nolock) ON d.tsdf_code = t2.tsdf_code
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
WHERE 1=1
	AND (w.customer_id = @customer_id
		OR w.generator_id IN (SELECT generator_id FROM customergenerator  (nolock) WHERE customer_id = @customer_id)
		OR w.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
	)
	AND w.start_date BETWEEN @start_date AND @end_date
	AND w.submitted_flag = 'T'
	AND w.workorder_status IN ('A','C','D','N','P','X')
	AND isnull(w.billing_project_id, 0) = 24
	AND ISNULL(g.site_type, '') NOT IN (SELECT site_type from #SiteTypeToExclude)
	AND d.resource_class_code = 'STOPFEE'
	AND g.site_code not in (
		select isnull(site_code, '') from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) where added_by = @usr and date_added = @extract_datetime and submitted_flag = 'T'
	)
	AND (
		(isnull(w.billing_project_id, 0) = 24 and w.customer_id = 10673)
		OR
		(w.waste_flag = 'F')
	)

-- Update fields left null in #Extract
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract set
	dot_description =
		CASE WHEN EQ_TEMP.dbo.WalmartDisposalExtract.tsdf_approval_id IS NOT NULL THEN
			-- (SELECT DOT_shipping_name FROM tsdfapproval  (nolock) WHERE tsdf_approval_id = EQ_TEMP.dbo.WalmartDisposalExtract.tsdf_approval_id)
			left(dbo.fn_manifest_dot_description('T', EQ_TEMP.dbo.WalmartDisposalExtract.tsdf_approval_id), 255)
		ELSE
			CASE WHEN EQ_TEMP.dbo.WalmartDisposalExtract.profile_id IS NOT NULL THEN
				left(dbo.fn_manifest_dot_description('P', EQ_TEMP.dbo.WalmartDisposalExtract.profile_id), 255)
			ELSE
				''
			END
		END,
	waste_code_1  = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes,  1)), '.', 'none')),
	waste_code_2  = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes,  2)), '.', 'none')),
	waste_code_3  = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes,  3)), '.', 'none')),
	waste_code_4  = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes,  4)), '.', 'none')),
	waste_code_5  = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes,  5)), '.', 'none')),
	waste_code_6  = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes,  6)), '.', 'none')),
	waste_code_7  = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes,  7)), '.', 'none')),
	waste_code_8  = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes,  8)), '.', 'none')),
	waste_code_9  = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes,  9)), '.', 'none')),
	waste_code_10 = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes, 10)), '.', 'none')),
	waste_code_11 = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes, 11)), '.', 'none')),
	waste_code_12 = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes, 12)), '.', 'none')),
	state_waste_code_1 = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, state_waste_codes, 1)), '.', 'none')),
	state_waste_code_2 = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, state_waste_codes, 2)), '.', 'none')),
	state_waste_code_3 = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, state_waste_codes, 3)), '.', 'none')),
	state_waste_code_4 = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, state_waste_codes, 4)), '.', 'none')),
	state_waste_code_5 = CONVERT(varchar(10), replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, state_waste_codes, 5)), '.', 'none')),
	transporter1_name = (select transporter_name from transporter (nolock) where transporter_code = EQ_TEMP.dbo.WalmartDisposalExtract.transporter1_code),
	transporter1_epa_id = (select transporter_epa_id from transporter (nolock) where transporter_code = EQ_TEMP.dbo.WalmartDisposalExtract.transporter1_code),
	transporter2_name = (select transporter_name from transporter (nolock) where transporter_code = EQ_TEMP.dbo.WalmartDisposalExtract.transporter2_code),
	transporter2_epa_id = (select transporter_epa_id from transporter (nolock) where transporter_code = EQ_TEMP.dbo.WalmartDisposalExtract.transporter2_code)
WHERE added_by = @usr AND date_added = @extract_datetime and submitted_flag = 'T'

/*
Texas waste codes are 8 digits, and wouldn't fit into the wastecode table's waste_code field.
BUT, the waste_code field on those records is unique, so EQ systems handle it correctly, but we
need to remember to update the extract to swap the waste_description (the TX 8 digit code) for
the waste_code for waste_codes that are from TX.
*/
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_1 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_1 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_2 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_2 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_3 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_3 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_4 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_4 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_5 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_5 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'


-- EQ_TEMP.dbo.WalmartDisposalExtract is finished now.


-- Create Image Lists
INSERT EQ_TEMP..WalmartExtractImages
	(site_code, generator_id, service_date, image_id, document_name, document_type, page_number, file_type, filename, process_flag, newname, added_by, date_added)
SELECT DISTINCT
	site_code,
	t.generator_id,
	service_date,
	s.image_id, s.document_name, sdt.document_type, s.page_number, s.file_type,
	CONVERT(varchar(60), RIGHT('00000' + ltrim(rtrim(ISNULL(site_code,''))), 5) + 'D_' +
		case when service_date is null then '00000000' else
			RIGHT('00' + CONVERT(varchar(2), DATEPART(mm, service_date)),2) +
			RIGHT('00' + CONVERT(varchar(2), DATEPART(dd, service_date)),2) +
			RIGHT('0000' + CONVERT(varchar(4), DATEPART(yyyy, service_date)), 4) 
		end +
		'_' + replace(sdt.document_type, ' ', '_') +
		'_') AS filename,
	0 AS process_flag,
	NULL AS newname,
	
	@usr as added_by,
	@extract_datetime as date_added
	
FROM EQ_TEMP.dbo.WalmartDisposalExtract t (nolock) 
INNER JOIN plt_image..scan s  (nolock) on s.company_id = t.company_id
	and s.profit_ctr_id = t.profit_ctr_id
	and (
		(s.workorder_id = t.receipt_id and s.document_source = 'workorder')
	)
	and s.status = 'A'
INNER JOIN plt_image..scandocumenttype sdt  (nolock) on s.type_id = sdt.type_id and sdt.document_type in ('manifest', 'secondary manifest', 'bol')
WHERE item_type = 'D'
AND t.added_by = @usr 
AND t.date_added = @extract_datetime
AND t.submitted_flag = 'T'
UNION
SELECT DISTINCT
site_code,
t.generator_id,
service_date,
s.image_id, s.document_name, sdt.document_type, s.page_number, s.file_type,
CONVERT(varchar(60), RIGHT('00000' + ltrim(rtrim(ISNULL(site_code,''))), 5) + 'D_' +
	case when service_date is null then '00000000' else
		RIGHT('00' + CONVERT(varchar(2), DATEPART(mm, service_date)),2) +
		RIGHT('00' + CONVERT(varchar(2), DATEPART(dd, service_date)),2) +
		RIGHT('0000' + CONVERT(varchar(4), DATEPART(yyyy, service_date)), 4) 
	end +
	'_' + replace(sdt.document_type, ' ', '_') +
	'_') AS filename,
0 AS process_flag,
NULL AS newname,
	
	@usr as added_by,
	@extract_datetime as date_added

FROM EQ_TEMP.dbo.WalmartDisposalExtract t (nolock) 
inner join plt_image..scan s  (nolock) on s.company_id = t.company_id
and s.profit_ctr_id = t.profit_ctr_id
and (
	(s.workorder_id = t.receipt_workorder_id and s.document_source = 'workorder')
)
and s.status = 'A'
inner join plt_image..scandocumenttype sdt (nolock) on s.type_id = sdt.type_id and sdt.document_type in ('manifest', 'secondary manifest', 'bol')
WHERE item_type = 'D'
AND t.added_by = @usr 
AND t.date_added = @extract_datetime
AND t.submitted_flag = 'T'

UNION

SELECT DISTINCT
	site_code,
	t.generator_id,
	service_date,
	s.image_id, s.document_name, sdt.document_type, s.page_number, s.file_type,
	CONVERT(varchar(60), RIGHT('00000' + ltrim(rtrim(ISNULL(site_code,''))), 5) + 'D_' +
		case when service_date is null then '00000000' else
			RIGHT('00' + CONVERT(varchar(2), DATEPART(mm, service_date)),2) +
			RIGHT('00' + CONVERT(varchar(2), DATEPART(dd, service_date)),2) +
			RIGHT('0000' + CONVERT(varchar(4), DATEPART(yyyy, service_date)), 4)
		end +
		'_' + replace(sdt.document_type, ' ', '_') +
		'_') AS filename,
	0 AS process_flag,
	NULL AS newname,
	
	@usr as added_by,
	@extract_datetime as date_added

FROM EQ_TEMP.dbo.WalmartDisposalExtract t (nolock) 
inner join plt_image..scan s  (nolock) on s.company_id = t.company_id
	and s.profit_ctr_id = t.profit_ctr_id
	and (
		(s.receipt_id = t.receipt_id and s.document_source = 'receipt')
	)
	and s.status = 'A'
inner join plt_image..scandocumenttype sdt (nolock) on s.type_id = sdt.type_id and sdt.document_type in ('manifest', 'secondary manifest', 'bol')
WHERE item_type = 'D'
AND t.added_by = @usr 
AND t.date_added = @extract_datetime
AND t.submitted_flag = 'T'

ORDER BY site_code, service_date, page_number


-- Update the 'newname' column for calculating name changes.
UPDATE EQ_TEMP..WalmartExtractImages SET newname = filename
WHERE added_by = @usr 
AND date_added = @extract_datetime

-- remove duplicate flag from images that aren't duplicates (only 1 mention of the generator)
-- (duplicates are images from a 2 sites with the same site code, where one is active, one is inactive, on the same day)
-- Why the following query is correct:
-- 	  Newname includes the facility # and date of service.  count of distinct generators will tell you how many have the same site # & date.
UPDATE EQ_TEMP..WalmartExtractImages
	SET newname = replace(newname, 'D_', '_')
WHERE newname IN (
	SELECT newname FROM (
		SELECT newname, count(distinct generator_id) AS gen_count
		FROM EQ_TEMP..WalmartExtractImages (nolock) 
		WHERE added_by = @usr 
		AND date_added = @extract_datetime
		GROUP BY newname HAVING count(distinct generator_id) = 1
	) a
)
AND added_by = @usr 
AND date_added = @extract_datetime

-- remove duplicate flag from images that aren't duplicates
-- ('A'ctive generators are the original records, inactive are the duplicates)
UPDATE EQ_TEMP..WalmartExtractImages
	SET newname = replace(newname, 'D_', '_')
WHERE newname IN (
	SELECT newname FROM EQ_TEMP..WalmartExtractImages (nolock) WHERE newname LIKE '%D_%'
)
AND generator_id NOT IN (select generator_id FROM generator (nolock) where status <> 'A')
AND added_by = @usr 
AND date_added = @extract_datetime

-- Add a sequence'd id to the images to avoid overwriting images from multiple manifest pages.
UPDATE EQ_TEMP..WalmartExtractImages set
	newname = newname + CONVERT(varchar(5),
		(
			row_id -
			(select min(row_id) FROM EQ_TEMP..WalmartExtractImages i2 (nolock) WHERE i2.newname = EQ_TEMP..WalmartExtractImages.newname)
		) + 1
	) + '.' + file_type
WHERE added_by = @usr 
AND date_added = @extract_datetime

/* *************************************************************

Validate Phase...

	Run the Validation every time, but may not be exported below...

	Look for blank transporter info
	Look for missing waste codes
	Look for 0 weight lines
	Look for blank service_date
	Look for blank Facility Number
	Look for blank Facility Type
	Look for un-submitted records that would've been included if they were submitted
	Look for count of D_ images
	Look for duplicate manifest/line combinations
	Look for missing dot descriptions
	Look for missing waste descriptions

************************************************************** */


-- Create list of missing transporter info
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) where ISNULL((select transporter_name from transporter (nolock) where transporter_code = EQ_TEMP.dbo.WalmartDisposalExtract.transporter1_code), '') = ''
	AND waste_desc <> 'No waste picked up'
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 1, 'Missing Transporter Info: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null, @usr, @extract_datetime where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of Missing Waste Code
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) where
	replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, waste_codes, 1)), '.', 'NONE') = ''
	AND
	replace(CONVERT(varchar(8), dbo.fn_get_list_item(',', 1, state_waste_codes, 1)), '.', 'NONE') = ''
	AND waste_desc <> 'No waste picked up'
	and manifest_line is not null
	and item_type in ('A', 'D', 'N')
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 2, 'Missing Waste Codes: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null, @usr, @extract_datetime where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of missing Weights
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) where pounds = 0
	AND waste_desc <> 'No waste picked up'
	AND item_type in ('A', 'D')
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 3, 'Missing Weights: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null, @usr, @extract_datetime where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of missing Service Dates
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) where isnull(service_date, '') = ''
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 4, 'Missing Service Dates: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null, @usr, @extract_datetime where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of receipts missing workorders
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + CONVERT(varchar(20), receipt_id)
	from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) where source_table = 'Receipt' and isnull(receipt_workorder_id, '') = ''
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 5, 'Receipt missing Workorder: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null, @usr, @extract_datetime where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of missing site codes
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) where site_code = ''
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 6, 'Missing Generator Site Code: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null, @usr, @extract_datetime where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of missing site type
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) where isnull(site_type, '') = ''
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 7, 'Missing Generator Site Type: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null, @usr, @extract_datetime where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of unsubmitted receipts
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + CONVERT(varchar(20), receipt_id)
	from EQ_TEMP.dbo.WalmartDisposalExtract (nolock)
	WHERE source_table = 'Receipt'
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'F'
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 8, 'Receipts Not Submitted: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null, @usr, @extract_datetime where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of unsubmitted workorders
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + CONVERT(varchar(20), receipt_id)
	from EQ_TEMP.dbo.WalmartDisposalExtract (nolock)
	WHERE source_table like 'Workorder%'
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'F'
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 9, 'Workorders Not Submitted: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null, @usr, @extract_datetime where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of duplicated images
	set @list = null
	SELECT @list = CONVERT(varchar(3), count(*)) from EQ_TEMP..WalmartExtractImages (nolock) where newname like '%D[_]%'
	AND added_by = @usr and date_added = @extract_datetime
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 10, 'Images with Duplicate flag: ' + @list, ' ', null, null, @usr, @extract_datetime where convert(int, @list) > 0

-- Create list of records missing scans
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + CONVERT(varchar(20), receipt_id) + ' is missing ''' + isnull(manifest, '') + ''''
	FROM EQ_TEMP.dbo.WalmartDisposalExtract (nolock) WHERE source_table = 'Workorder'
	AND manifest not in (select document_name from EQ_TEMP..WalmartExtractImages (nolock) WHERE added_by = @usr and date_added = @extract_datetime AND submitted_flag = 'T' )
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'
	and item_type <> 'N'
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table, manifest ORDER BY company_id, profit_ctr_id, receipt_id

	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + CONVERT(varchar(20), receipt_id) + ' is missing ''' + isnull(manifest, '') + ''''
	FROM EQ_TEMP.dbo.WalmartDisposalExtract (nolock) WHERE source_table = 'Receipt'
	AND manifest not in (select document_name from EQ_TEMP..WalmartExtractImages (nolock) WHERE added_by = @usr and date_added = @extract_datetime AND submitted_flag = 'T' )
	AND item_type <> 'N'
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table, manifest ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 11, 'Missing Scans: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null, @usr, @extract_datetime where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create count of receipt-based records in extract
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 100, 'Count of Receipt-based records in Extract:',
	CONVERT(varchar(20), count(*)), null, null, @usr, @extract_datetime
	from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
	WHERE source_table = 'Receipt'
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'

-- Create count of workorder-based records in extract
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 101, 'Count of Workorder-based records in Extract:',
	CONVERT(varchar(20), count(*)), null, null, @usr, @extract_datetime
	from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
	WHERE source_table = 'Workorder'
	AND waste_desc <> 'No waste picked up'
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'

-- Create count of no-waste-pickup records in extract
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 102, 'Count of No-Waste Pickups in Extract:',
	CONVERT(varchar(20), count(*)), null, null, @usr, @extract_datetime
	from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
	WHERE source_table = 'Workorder'
	AND waste_desc = 'No waste picked up'
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'

-- Create list of unusually high number of manifest names
	INSERT EQ_Temp..WalmartDisposalValidation
	SELECT 10, 'Unusual number of manifests/lines named: ' + isnull(manifest, '') + ' line ' + isnull(CONVERT(varchar(10), Manifest_Line), ''),
	CONVERT(varchar(20), count(*)) + ' times', null, null, @usr, @extract_datetime from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
	where waste_desc <> 'No waste picked up'
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'
	GROUP BY manifest, Manifest_Line
	HAVING COUNT(*) > 2
	ORDER BY COUNT(*) DESC

-- Create list of missing dot descriptions
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' :' + CONVERT(varchar(20), receipt_id)
	FROM EQ_TEMP.dbo.WalmartDisposalExtract (nolock) where
		ISNULL(
			CASE WHEN EQ_TEMP.dbo.WalmartDisposalExtract.tsdf_approval_id IS NOT NULL THEN
				dbo.fn_manifest_dot_description('T', EQ_TEMP.dbo.WalmartDisposalExtract.tsdf_approval_id)
			ELSE
				CASE WHEN EQ_TEMP.dbo.WalmartDisposalExtract.profile_id IS NOT NULL THEN
					dbo.fn_manifest_dot_description('P', EQ_TEMP.dbo.WalmartDisposalExtract.profile_id)
				ELSE
					''
				END
			END
		, '') = ''
	and approval_or_resource not in ('STOPFEE', 'GASSUR%')
	and waste_desc <> 'No waste picked up'
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'
	GROUP BY company_id, profit_ctr_id, receipt_id ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 12, 'Missing DOT Description: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null, @usr, @extract_datetime where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of missing waste descriptions
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + CONVERT(varchar(20), receipt_id)
	FROM EQ_TEMP.dbo.WalmartDisposalExtract (nolock) where waste_desc = ''
	and approval_or_resource not in ('STOPFEE', 'GASSUR%')
	and waste_desc <> 'No waste picked up'
	AND added_by = @usr and date_added = @extract_datetime
	AND submitted_flag = 'T'
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 13, 'Missing Waste Description: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null, @usr, @extract_datetime where LEN(LTRIM(ISNULL(@list, '')))> 0

-- Create list of look-alike generators not assigned to WM yet:
	INSERT EQ_TEMP..WalmartMissingGenerators
	SELECT generator_id, epa_id, generator_name, generator_city, generator_state, site_code, site_type, status, @usr, @extract_datetime
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

-- Create list of blank waste code 1's
	SET @list = NULL
	SELECT @list = COALESCE(@list + ', ', '') + CONVERT(varchar(4), company_id) + '-' + CONVERT(varchar(4), profit_ctr_id) + ' ' + left(source_table, 1) + ':' + isnull(CONVERT(varchar(20), receipt_id), CONVERT(varchar(20), receipt_id))
	from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) where ISNULL(waste_code_1, '') = ''
	AND waste_desc <> 'No waste picked up'
	AND added_by = @usr and date_added = @extract_datetime
	GROUP BY company_id, profit_ctr_id, receipt_id, source_table ORDER BY company_id, profit_ctr_id, receipt_id
	INSERT EQ_Temp..WalmartDisposalValidation SELECT 14, 'Blank Waste Code 1: ' + (select convert(varchar(20), count(distinct row)) from dbo.fn_SplitXsvText(',', 1, @list) where isnull(row, '') <> ''), @list, null, null, @usr, @extract_datetime where LEN(LTRIM(ISNULL(@list, '')))> 0


/* *************************************************************

Export Phase...

	Only export 1 kind of output per SP run

************************************************************** */


IF @output_mode = 'wm-extract' BEGIN

		-----------------------------------------------------------
		-- Always keep at least 5 copies
		-----------------------------------------------------------
		SELECT DISTINCT TOP 5 added_by, date_added 
		INTO #extracts_to_keep3
		FROM EQ_Extract..WalmartDisposalExtract
		ORDER BY date_added DESC

		-----------------------------------------------------------
		-- Delete old extracts, but leave at least the last 5
		-----------------------------------------------------------
		DELETE FROM EQ_Extract..WalmartDisposalExtract
		WHERE date_added < @days_before_delete
		AND date_added NOT IN (
			SELECT date_added FROM #extracts_to_keep3
		)
		
		INSERT EQ_Extract.dbo.WalmartDisposalExtract (
			site_code,
			site_type_abbr,
			generator_city,
			generator_state,
			service_date,
			epa_id,
			manifest,
			manifest_line,
			pounds,
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
			waste_code_6,
			waste_code_7,
			waste_code_8,
			waste_code_9,
			waste_code_10,
			waste_code_11,
			waste_code_12,
			state_waste_code_1,
			state_waste_code_2,
			state_waste_code_3,
			state_waste_code_4,
			state_waste_code_5,
			management_code,
			EPA_source_code,
			EPA_form_code,
			transporter1_name,
			transporter1_epa_id,
			transporter2_name,
			transporter2_epa_id,
			receiving_facility,
			receiving_facility_epa_id,
			receipt_id,
			disposal_service_desc,
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
			site_type_abbr,
			generator_city,
			generator_state,
			service_date,
			epa_id,
			manifest,
			manifest_line,
			pounds,
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
			waste_code_6,
			waste_code_7,
			waste_code_8,
			waste_code_9,
			waste_code_10,
			waste_code_11,
			waste_code_12,
			state_waste_code_1,
			state_waste_code_2,
			state_waste_code_3,
			state_waste_code_4,
			state_waste_code_5,
			management_code,
			EPA_source_code,
			EPA_form_code,
			transporter1_name,
			transporter1_epa_id,
			transporter2_name,
			transporter2_epa_id,
			receiving_facility,
			receiving_facility_epa_id,
			receipt_id,
			disposal_service_desc,

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
		FROM EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
		WHERE added_by = @usr and date_added = @extract_datetime
		AND submitted_flag = 'T'
 			 
-- Update Run information
	UPDATE EQ_Extract..ExtractLog SET
		end_date = GETDATE(),
		extract_table = 'EQ_Extract.dbo.WalmartDisposalExtract',
		record_count = @@rowcount
	WHERE
		extract_command = @sp_name_args
		AND date_added = @extract_datetime
		AND added_by = @usr		

		SELECT
			ISNULL(site_code, '') AS 'Facility Number',
			ISNULL(site_type_abbr, '') AS 'Facility Type',
			ISNULL(generator_city, '') AS 'City',
			ISNULL(generator_state, '') AS 'State',
			ISNULL(CONVERT(varchar(20), service_date, 101), '') AS 'Shipment Date',
			ISNULL(epa_id, '') AS 'Haz Waste Generator EPA ID',
			CASE WHEN waste_desc = 'No waste picked up' THEN
				CONVERT(varchar(20), REPLACE(ISNULL(CONVERT(varchar(20), service_date, 101), ''), '/', ''))
			ELSE
				ISNULL(manifest, '') 
			END AS 'Manifest Number',
			ISNULL(NULLIF(manifest_line, 0), '') AS 'Manifest Line',
			SUM(ISNULL(pounds, 0)) AS 'Weight',
			CASE WHEN waste_desc = 'No waste picked up' THEN
				ISNULL(bill_unit_desc, '')
			ELSE
				dbo.fn_gallon_convert_wm_waste_desc(manifest, manifest_line, @usr, @extract_datetime)
			END AS 'Container Type',
			SUM(ISNULL(quantity, 0)) AS 'Container Quantity',
			ISNULL(waste_desc, '') AS 'Waste Description',
			ISNULL(approval_or_resource, '') AS 'Waste Profile Number',
			ISNULL(dot_description, '') AS 'DOT Description',
			ISNULL(waste_code_1, '') AS 'Waste Code 1',
			ISNULL(waste_code_2, '') AS 'Waste Code 2',
			ISNULL(waste_code_3, '') AS 'Waste Code 3',
			ISNULL(waste_code_4, '') AS 'Waste Code 4',
			ISNULL(waste_code_5, '') AS 'Waste Code 5',
			ISNULL(waste_code_6, '') AS 'Waste Code 6',
			ISNULL(waste_code_7, '') AS 'Waste Code 7',
			ISNULL(waste_code_8, '') AS 'Waste Code 8',
			ISNULL(waste_code_9, '') AS 'Waste Code 9',
			ISNULL(waste_code_10, '') AS 'Waste Code 10',
			ISNULL(waste_code_11, '') AS 'Waste Code 11',
			ISNULL(waste_code_12, '') AS 'Waste Code 12',
			ISNULL(state_waste_code_1, '') AS 'State Waste Code 1',
			ISNULL(state_waste_code_2, '') AS 'State Waste Code 2',
			ISNULL(state_waste_code_3, '') AS 'State Waste Code 3',
			ISNULL(state_waste_code_4, '') AS 'State Waste Code 4',
			ISNULL(state_waste_code_5, '') AS 'State Waste Code 5',
			ISNULL(management_code, '') AS 'Management Code',
			ISNULL(epa_source_code, '') AS 'EPA Source Code',
			ISNULL(epa_form_code, '') AS 'EPA Form Code',
			ISNULL(transporter1_name, '') AS 'Transporter Name 1',
			ISNULL(transporter1_epa_id, '') AS 'Transporter 1 EPA ID Number',
			ISNULL(transporter2_name, '') AS 'Transporter Name 2',
			ISNULL(transporter2_epa_id, '') AS 'Transporter 2 EPA ID Number',
			ISNULL(receiving_facility, '') AS 'Receiving Facility',
			ISNULL(receiving_facility_epa_id, '') AS 'Receiving Facility EPA ID Number',
			receipt_id AS 'WorkOrder Number',
			CASE ltrim(rtrim(ISNULL(disposal_service_desc, '')))
				WHEN 'Other'				THEN 'PROBLEM: ' + disposal_service_desc
				WHEN 'Canadian Landfill'	THEN 'Treatment/Landfill D'
				WHEN 'Cement Kiln'			THEN 'Fuel Blending/Energy Recovery'
				WHEN 'Deepwell'				THEN 'PROBLEM: ' + disposal_service_desc
				WHEN 'Fuel Blending'		THEN 'Fuel Blending/Energy Recovery'
				WHEN 'Incinerator'			THEN 'Incineration'
				WHEN 'Oil Marketer'			THEN 'Recycle'
				WHEN 'POTW'					THEN 'PROBLEM: ' + disposal_service_desc
				WHEN 'Recycle'				THEN 'Recycle'
				WHEN 'Subtitle C'			THEN 'Treatment/Landfill C'
				WHEN 'Subtitle D'			THEN 'Treatment/Landfill D'
				WHEN 'TSDF'					THEN 'PROBLEM: ' + disposal_service_desc
				ELSE CASE WHEN waste_desc = 'No waste picked up' THEN '' ELSE ISNULL(disposal_service_desc, '') END
			END AS 'Disposal Method'
			
		FROM EQ_Extract.dbo.WalmartDisposalExtract
		WHERE
			added_by = @usr
			AND date_added = @extract_datetime
		GROUP BY			
			site_code,
			site_type_abbr,
			generator_city,
			generator_state,
			service_date,
			epa_id,
			CASE WHEN waste_desc = 'No waste picked up' THEN
				CONVERT(varchar(20), REPLACE(ISNULL(CONVERT(varchar(20), service_date, 101), ''), '/', ''))
			ELSE
				ISNULL(manifest, '') 
			END,
			ISNULL(NULLIF(manifest_line, 0), ''),
			CASE WHEN waste_desc = 'No waste picked up' THEN
				ISNULL(bill_unit_desc, '')
			ELSE
				dbo.fn_gallon_convert_wm_waste_desc(manifest, manifest_line, @usr, @extract_datetime)
			END,
			waste_desc,
			approval_or_resource,
			dot_description,
			waste_code_1,
			waste_code_2,
			waste_code_3,
			waste_code_4,
			waste_code_5,
			waste_code_6,
			waste_code_7,
			waste_code_8,
			waste_code_9,
			waste_code_10,
			waste_code_11,
			waste_code_12,
			state_waste_code_1,
			state_waste_code_2,
			state_waste_code_3,
			state_waste_code_4,
			state_waste_code_5,
			management_code,
			epa_source_code,
			epa_form_code,
			transporter1_name,
			transporter1_epa_id,
			transporter2_name,
			transporter2_epa_id,
			receiving_facility,
			receiving_facility_epa_id,
			receipt_id,
			disposal_service_desc
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
		FROM EQ_Extract..WalmartDisposalExtract
		ORDER BY date_added DESC

		-----------------------------------------------------------
		-- Delete old extracts, but leave at least the last 5
		-----------------------------------------------------------
		DELETE FROM EQ_Extract..WalmartDisposalExtract
		WHERE date_added < @days_before_delete
		AND date_added NOT IN (
			SELECT date_added FROM #extracts_to_keep4
		)
		
		INSERT EQ_Extract.dbo.WalmartDisposalExtract (
			site_code,
			site_type_abbr,
			generator_city,
			generator_state,
			service_date,
			epa_id,
			manifest,
			manifest_line,
			pounds,
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
			waste_code_6,
			waste_code_7,
			waste_code_8,
			waste_code_9,
			waste_code_10,
			waste_code_11,
			waste_code_12,
			state_waste_code_1,
			state_waste_code_2,
			state_waste_code_3,
			state_waste_code_4,
			state_waste_code_5,
			management_code,
			EPA_source_code,
			EPA_form_code,
			transporter1_name,
			transporter1_epa_id,
			transporter2_name,
			transporter2_epa_id,
			receiving_facility,
			receiving_facility_epa_id,
			receipt_id,
			disposal_service_desc,
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
			site_type_abbr,
			generator_city,
			generator_state,
			service_date,
			epa_id,
			manifest,
			manifest_line,
			pounds,
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
			waste_code_6,
			waste_code_7,
			waste_code_8,
			waste_code_9,
			waste_code_10,
			waste_code_11,
			waste_code_12,
			state_waste_code_1,
			state_waste_code_2,
			state_waste_code_3,
			state_waste_code_4,
			state_waste_code_5,
			management_code,
			EPA_source_code,
			EPA_form_code,
			transporter1_name,
			transporter1_epa_id,
			transporter2_name,
			transporter2_epa_id,
			receiving_facility,
			receiving_facility_epa_id,
			receipt_id,
			disposal_service_desc,

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
		FROM EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
		WHERE added_by = @usr and date_added = @extract_datetime
		AND submitted_flag = 'T'
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
		extract_table = 'EQ_Extract.dbo.WalmartDisposalExtract',
		record_count = @@rowcount
	WHERE
		extract_command = @sp_name_args
		AND date_added = @extract_datetime
		AND added_by = @usr		
  
 -- This is the default select
		--SELECT
		--	*
		--FROM EQ_Extract.dbo.WalmartDisposalExtract
		--WHERE
		--	added_by = @usr
		--	AND date_added = @extract_datetime
		--ORDER BY
		--	generator_state,
		--	generator_city,
		--	site_code,
		--	service_date,
		--	receipt_id,
		--	manifest_line
		
		DROP TABLE #tmp

		SELECT	customer_id,
			site_code,
			site_type,
			site_type_abbr,
			generator_state,
			epa_id,
			generator_name,
			generator_id,
			RIGHT('00' + CONVERT(varchar(2), DATEPART(mm, service_date)), 2) + '-' + CONVERT(varchar(4), DATEPART(yyyy, service_date)) AS service_date,
			CASE haz_flag WHEN 'T' THEN 'Haz'
				WHEN 'F' THEN 'NonHaz'
				ELSE haz_flag
				END AS haz_flag,
			ISNULL((SELECT SUM(pounds) WHERE haz_flag = 'T'), 0) AS pounds_haz,
			ISNULL((SELECT SUM(pounds) WHERE haz_flag = 'F'), 0) AS pounds_nonhaz,
			SUM(ISNULL(pounds, 0)) AS pounds_total
		INTO #tmp
		FROM EQ_Extract.dbo.WalmartDisposalExtract
		WHERE
			added_by = @usr
			AND date_added = @extract_datetime
		--added_by = 'JASON_B'
		--AND date_added = '2009-11-25 12:53:24.693'
		GROUP BY 
			customer_id,
			site_code,
			site_type,
			site_type_abbr,
			generator_state,
			epa_id,
			generator_name,
			generator_id,
			RIGHT('00' + CONVERT(varchar(2), DATEPART(mm, service_date)), 2) + '-' + CONVERT(varchar(4), DATEPART(yyyy, service_date)),
			haz_flag
		ORDER BY
			generator_state,
			site_code,
			RIGHT('00' + CONVERT(varchar(2), DATEPART(mm, service_date)), 2) + '-' + CONVERT(varchar(4), DATEPART(yyyy, service_date)),
			haz_flag

		SELECT customer_id,
			site_code,
			site_type,
			site_type_abbr,
			generator_state,
			epa_id,
			generator_name,
			generator_id, 
			service_date,
			SUM(pounds_haz) AS pounds_haz,
			SUM(pounds_nonhaz) AS pounds_nonhaz,
			SUM(pounds_total) AS pounds_total
		FROM #tmp
		GROUP BY
			customer_id,
			site_code,
			site_type,
			site_type_abbr,
			generator_state,
			epa_id,
			generator_name,
			generator_id,
			service_date
		ORDER BY
			generator_state,
			site_code,
			RIGHT(service_date, 4), 
			LEFT(service_date, 2)

DROP TABLE #tmp
END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_walmart_disposal_brian2] TO [EQAI]
    AS [dbo];


	*/
