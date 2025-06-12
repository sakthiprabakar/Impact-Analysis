
CREATE PROCEDURE sp_rpt_generic_disposal_validate (
	@customer_id_list		varchar(max),
    @start_date             datetime,
    @end_date               datetime
)
AS
/* ***********************************************************
Procedure    : sp_rpt_generic_disposal_validate
Database     : PLT_AI
Created      : Aug 13 2014 - Jonathan Broome
Description  : Stolen from Wal-Mart, modified for anyone.

SELECT * FROM customer where cust_name like 'harbor%'
 
Examples:
     sp_rpt_generic_disposal_validate '6178', '1/1/2015 00:00', '3/1/2015 23:59'

Output Routines:
    declare @extract_id int = 837 -- (returned above)
			-- Disposal Validation output
			sp_rpt_extract_walmart_disposal_output_validation1_jpb 850
			


Notes:
    IMPORTANT: This script is only valid from 2007/03 and later.
        2007-01 and 2007-02 need to exclude company-14, profit-ctr-4 data.
        2007-01 needs to INCLUDE 14/4 data from the state of TN.


History:
    8/14/2014 - JPB - Created from sp_rpt_extract_walmart_disposal
	8/22/2014 - JPB - GEM:-29706 - Modify Validations: ___ Not-Submitted only true if > $0


*********************************************************** */

SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

--- declare @customer_id_list		varchar(max) = '12113', @start_date             datetime = '7/1/2013 00:00', @end_date               datetime = '07/31/2013 23:59'
    

-- Fix/Set EndDate's time.
	if isnull(@end_date,'') <> ''
		if datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

-- Define extract values:
DECLARE
    @extract_id             int,
    @debug                  int
SELECT
    @debug                  = 0
    
CREATE TABLE #Customer (
	customer_id 	int
)
INSERT #Customer 
SELECT convert(int, row)
from dbo.fn_SplitXSVText(',', 1, @customer_id_list)
where row is not null

	CREATE TABLE #DisposalExtract(
		[site_code] [varchar](16) NULL,
		[site_type_abbr] [varchar](10) NULL,
		[generator_city] [varchar](40) NULL,
		[generator_state] [varchar](2) NULL,
		[service_date] [datetime] NULL,
		[epa_id] [varchar](12) NULL,
		[manifest] [varchar](15) NULL,
		[manifest_line] [int] NULL,
		[pounds] [float] NULL,							-- regular weight calculation
		[calculated_pounds] [float] NULL,				-- residue_pounds_factor weight calculation
		[empty_bottle_count] [int] NULL,
		[bill_unit_desc] [varchar](40) NULL,
		[quantity] [float] NULL,
		[waste_desc] [varchar](50) NULL,
		[approval_or_resource] [varchar](60) NULL,
		[dot_description] [varchar](255) NULL,
		[waste_code_1] [varchar](10) NULL,
		[waste_code_2] [varchar](10) NULL,
		[waste_code_3] [varchar](10) NULL,
		[waste_code_4] [varchar](10) NULL,
		[waste_code_5] [varchar](10) NULL,
		[waste_code_6] [varchar](10) NULL,
		[waste_code_7] [varchar](10) NULL,
		[waste_code_8] [varchar](10) NULL,
		[waste_code_9] [varchar](10) NULL,
		[waste_code_10] [varchar](10) NULL,
		[waste_code_11] [varchar](10) NULL,
		[waste_code_12] [varchar](10) NULL,
		[state_waste_code_1] [varchar](10) NULL,
		[state_waste_code_2] [varchar](10) NULL,
		[state_waste_code_3] [varchar](10) NULL,
		[state_waste_code_4] [varchar](10) NULL,
		[state_waste_code_5] [varchar](10) NULL,
		[management_code] [varchar](4) NULL,
		[EPA_source_code] [varchar](10) NULL,
		[EPA_form_code] [varchar](10) NULL,
		[transporter1_name] [varchar](40) NULL,
		[transporter1_epa_id] [varchar](15) NULL,
		[transporter2_name] [varchar](40) NULL,
		[transporter2_epa_id] [varchar](15) NULL,
		[receiving_facility] [varchar](50) NULL,
		[receiving_facility_epa_id] [varchar](50) NULL,
		[receipt_id] [int] NULL,
		[disposal_service_desc] [varchar](20) NULL,
		[company_id] [smallint] NULL,
		[profit_ctr_id] [smallint] NULL,
		[line_sequence_id] [int] NULL,
		[generator_id] [int] NULL,
		[generator_name] [varchar](40) NULL,
		[site_type] [varchar](40) NULL,
		[manifest_page] [int] NULL,
		[item_type] [varchar](9) NULL,
		[tsdf_approval_id] [int] NULL,
		[profile_id] [int] NULL,
		[container_count] [float] NULL,
		[waste_codes] [varchar](2000) NULL,
		[state_waste_codes] [varchar](2000) NULL,
		[transporter1_code] [varchar](15) NULL,
		[transporter2_code] [varchar](15) NULL,
		[date_delivered] [datetime] NULL,
		[source_table] [varchar](20) NULL,
		[receipt_date] [datetime] NULL,
		[receipt_workorder_id] [int] NULL,
		[workorder_start_date] [datetime] NULL,
		[workorder_company_id] [int] NULL,
		[workorder_profit_ctr_id] [int] NULL,
		[customer_id] [int] NULL,
		[cust_name]	[varchar](40) NULL,
		[billing_project_id] int NULL,
		[billing_project_name]	[varchar](40) NULL,
		[purchase_order] 	[varchar](20) NULL,
		[haz_flag] [char](1) NULL,
		[submitted_flag] [char](1) NULL,
		[generator_address_1] [varchar](40) NULL,
		[generator_address_2] [varchar](40) NULL,
		[generator_county] [varchar](40) NULL,
		[generator_zip_code] [varchar](15) NULL,
		[generator_region_code][varchar](40) NULL,
		[generator_division] [varchar](40) NULL,
		[generator_business_unit][varchar](40) NULL,
		[manifest_unit][varchar](15) NULL,
		[manifest_quantity] [float] NULL
)

exec sp_rpt_generic_disposal_build @customer_id_list, @start_date, @end_date

	CREATE TABLE #DisposalValidation (
		problem [varchar](200) NULL,
		source [varchar](20) NULL,
		company_id int,
		profit_ctr_id int,
		receipt_id int,
		extra varchar(max)
	) 
	
	
/* *************************************************************webdev

Validate Phase...

    Run the Validation every time, but may not be exported below...

    Look for blank transporter info
    Look for missing waste codes
    Look for 0 weight lines
    Look for blank service_date
    Look for blank Facility Number
    Look for blank Facility Type
    Look for un-submitted records that would've been included if they were submitted
    Look for duplicate manifest/line combinations
    Look for missing dot descriptions
    Look for missing waste descriptions

************************************************************** */

-- Create list of missing transporter info
    INSERT #DisposalValidation
    SELECT  DISTINCT
    	'Missing Transporter Info' as Problem,
    	source_table,
    	Company_id,
    	Profit_ctr_id,
    	Receipt_id,
    	NULL
    FROM #DisposalExtract (nolock) 
    WHERE 
    	ISNULL((select transporter_name from transporter (nolock) where transporter_code = transporter1_code), '') = ''
	    AND waste_desc <> 'No waste picked up'
	    AND submitted_flag = 'T'
    	

-- Create list of Missing Waste Code
    INSERT #DisposalValidation
    SELECT DISTINCT
    	'Missing Waste Code',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL
    from #DisposalExtract e (nolock) 
    where
	    waste_desc <> 'No waste picked up'
	    and manifest_line is not null
	    and item_type in ('A', 'D', 'N')
	    AND submitted_flag = 'T'
	    and coalesce(waste_code_1, waste_code_2, waste_code_3, waste_code_4, waste_code_5, waste_code_6, waste_code_7, waste_code_8, waste_code_9, waste_code_10, waste_code_11, waste_code_12, '') = ''
	    and coalesce(state_waste_code_1, state_waste_code_2, state_waste_code_3, state_waste_code_4, state_waste_code_5, '') = ''


-- Create list of missing Weights
    INSERT #DisposalValidation
    SELECT DISTINCT
    	'Missing Weight',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line/seq: ' + convert(varchar(20), line_sequence_id)
    from #DisposalExtract (nolock) 
    where
    	isnull(pounds,0) = 0
	    AND waste_desc <> 'No waste picked up'
	    and manifest_line is not null
	    and item_type in ('A', 'D')
	    AND submitted_flag = 'T'


-- Create list of missing Service Dates
    INSERT #DisposalValidation
    SELECT DISTINCT
    	'Missing Service Date',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL
    from #DisposalExtract (nolock) 
    where
    	isnull(service_date, '') = ''
	    AND submitted_flag = 'T'


-- Create list of missing site codes
    INSERT #DisposalValidation
     SELECT DISTINCT
    	'Missing Generator Site Code',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL
    from #DisposalExtract (nolock) 
    where
    	site_code = ''
	    AND submitted_flag = 'T'


-- Create list of missing site type
    INSERT #DisposalValidation
     SELECT DISTINCT
    	'Missing Generator Site Type',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL
    from #DisposalExtract (nolock) 
    where
    	isnull(site_type, '') = ''
	    AND submitted_flag = 'T'


-- Create list of unsubmitted receipts
    INSERT #DisposalValidation
     SELECT DISTINCT
    	source_table + ' Not Submitted',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL
    from #DisposalExtract t (nolock) 
    where
		submitted_flag = 'F'
		and source_table ='Receipt'
	    and 0 < (
			select sum(
				case when isnull(rp.total_extended_amt, 0) > 0 
					then isnull(rp.total_extended_amt, 0)
					else 
						case when isnull(rp.total_extended_amt, 0) = 0 and rp.print_on_invoice_flag = 'T' 
							then 1 
							else isnull(rp.total_extended_amt, 0)
						end 
				end
			)
			from receiptprice rp (nolock)
			where rp.receipt_id = t.receipt_id
			and rp.company_id = t.company_id
			and rp.profit_ctr_id = t.profit_ctr_id
	    )


-- Create list of unsubmitted workorders
    INSERT #DisposalValidation
     SELECT DISTINCT
    	source_table + ' Not Submitted',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL
    from #DisposalExtract t (nolock) 
    where
		submitted_flag = 'F'
		and source_table ='Workorder'
	    and 0 < (
			select sum(isnull(wh.total_price, 0))
			from workorderheader wh (nolock)
			where wh.workorder_id = t.receipt_id
			and wh.company_id = t.company_id
			and wh.profit_ctr_id = t.profit_ctr_id
	    )


-- Create count of receipt-based records in extract
    INSERT #DisposalValidation
     SELECT
    	' Count of Receipt-based records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*))
    from #DisposalExtract (nolock) 
    where
		source_table ='Receipt'
	    AND submitted_flag = 'T'


-- Create count of workorder -based records in extract
    INSERT #DisposalValidation
     SELECT 
    	' Count of Workorder-based records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*))
    from #DisposalExtract (nolock) 
    where
		source_table ='Workorder'
    	AND waste_desc <> 'No waste picked up'
	    AND submitted_flag = 'T'


-- Create count of NWP -based records in extract
    INSERT #DisposalValidation
     SELECT 
    	' Count of No Waste Pickup records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*))
    from #DisposalExtract (nolock) 
    where
		source_table ='Workorder'
    	AND waste_desc = 'No waste picked up'
	    AND submitted_flag = 'T'

-- Create list of unusually high number of manifest names
    INSERT #DisposalValidation
     SELECT
    	'High Number of same manifest-line',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	CONVERT(varchar(20), count(*)) + ' times: ' + isnull(manifest, '') + ' line ' + isnull(CONVERT(varchar(10), Manifest_Line), '')
    from #DisposalExtract (nolock) 
    where
    	waste_desc <> 'No waste picked up'
    	AND bill_unit_desc not like '%cylinder%'
	    AND submitted_flag = 'T'
	group by source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	manifest, manifest_line
	having count(*) > 1


-- Create list of missing dot descriptions
    INSERT #DisposalValidation
     SELECT DISTINCT
    	'Missing DOT Description',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL
    from #DisposalExtract (nolock) 
    where
		submitted_flag = 'T'
        AND ISNULL(
            CASE WHEN tsdf_approval_id IS NOT NULL THEN
                dbo.fn_manifest_dot_description('T', tsdf_approval_id)
            ELSE
                CASE WHEN profile_id IS NOT NULL THEN
                    dbo.fn_manifest_dot_description('P', profile_id)
                ELSE
                    ''
                END
            END
        , '') = ''
	    and approval_or_resource not in ('STOPFEE', 'GASSUR%')
	    and waste_desc <> 'No waste picked up'


-- Create list of missing bill units in extract
    INSERT #DisposalValidation
     SELECT 
    	'Missing Bill Unit',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line ' + convert(varchar(10), line_sequence_id)
    from #DisposalExtract (nolock) 
    where
		isnull(bill_unit_desc, '') = ''
		AND waste_desc <> 'No waste picked up'
	    AND submitted_flag = 'T'


-- Create list of missing waste descriptions
    INSERT #DisposalValidation
     SELECT DISTINCT
    	'Missing Waste Description',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL
    from #DisposalExtract (nolock) 
    where
    	waste_desc = ''
	    AND submitted_flag = 'T'
	    and approval_or_resource not in ('STOPFEE', 'GASSUR%')
	    and waste_desc <> 'No waste picked up'

-- Create list of blank waste code 1's
    INSERT #DisposalValidation
     SELECT DISTINCT
    	'Blank Waste Code 1',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line/seq: ' + convert(varchar(20), line_sequence_id)
    from #DisposalExtract (nolock) 
    where
    	ISNULL(waste_code_1, '') = ''
    	AND coalesce(waste_code_2, waste_code_3, waste_code_4, waste_code_5, waste_code_6, waste_code_7, waste_code_8, waste_code_9, waste_code_10, '') <> ''
	    AND submitted_flag = 'T'
	    and waste_desc <> 'No waste picked up'

-- Create list of receipts missing workorders
    INSERT #DisposalValidation
    SELECT DISTINCT
    	'Receipt missing Workorder',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL
    from #DisposalExtract  (nolock) 
    WHERE
		source_table = 'receipt'
    	AND isnull(receipt_workorder_id, '') = ''
	    AND submitted_flag = 'T'


-- Catch generators serviced that aren't in the extracts
    INSERT #DisposalValidation
     SELECT DISTINCT
    	'Site serviced, NOT in extract',
    	'Workorder',
    	woh.company_id,
    	woh.profit_ctr_id,
    	woh.workorder_id,
    	left(convert(varchar(20), woh.generator_id) + ' (' + isnull(g.site_code, 'Code?') + ' - ' + isnull(g.generator_city, 'city?') + ', ' + isnull(g.generator_state, 'ST?') + ')', 40)
	FROM workorderheader woh (nolock)
	INNER join TripHeader th (nolock) ON woh.trip_id = th.trip_id
	INNER JOIN generator g (nolock) on woh.generator_id = g.generator_id
	LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = woh.workorder_id
		and wos.company_id = woh.company_id
		and wos.profit_ctr_id = woh.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
	WHERE th.trip_status IN ('D', 'C', 'A', 'U')
	AND woh.workorder_status <> 'V'
	AND (woh.customer_id IN (select customer_id from #Customer) 
		OR woh.generator_id in (select generator_id from CustomerGenerator (nolock) where customer_id IN (select customer_id from #Customer))
	)
	AND coalesce(wos.date_act_arrive, woh.start_date) between @start_date and @end_date
	AND g.generator_id not in (
		select generator_id 
		from #DisposalExtract   (nolock)
		where submitted_flag = 'T'
	)


-- Catch missing manifest scans
    INSERT #DisposalValidation
     SELECT 
    	'Missing Manifest Scan',
    	de.source_table,
    	de.company_id,
    	de.profit_ctr_id,
    	de.receipt_id,
    	'manifest: ' + de.manifest
    from #DisposalExtract de (nolock) 
    inner join receipt r (nolock)
		on de.receipt_id = r.receipt_id
		and de.line_sequence_id = r.line_id
		and de.company_id = r.company_id
		and de.profit_ctr_id = r.profit_ctr_id
		and r.manifest_flag = 'M'
    left join plt_image..scan s (nolock)
		on de.receipt_id = s.receipt_id
		and de.company_id = s.company_id
		and de.profit_ctr_id = s.profit_ctr_id
		and de.source_table = s.document_source
		and s.status = 'A'
		and s.type_id in (
			select type_id
			from plt_image..scandocumenttype
			where document_type like '%manifest%'
		)
    where 1=1
		and de.source_table = 'receipt'
	    and de.waste_desc <> 'No waste picked up'
	    and s.image_id is null
union
     SELECT 
    	'Missing Manifest Scan',
    	de.source_table,
    	de.company_id,
    	de.profit_ctr_id,
    	de.receipt_id,
    	'manifest: ' + de.manifest
    from #DisposalExtract de (nolock) 
    left join plt_image..scan s
		on de.receipt_id = s.workorder_id
		and de.company_id = s.company_id
		and de.profit_ctr_id = s.profit_ctr_id
		and de.source_table = s.document_source
		and s.status = 'A'
		and s.type_id in (
			select type_id
			from plt_image..scandocumenttype
			where document_type like '%manifest%'
		)
    where 1=1
		and de.source_table = 'workorder'
	    and de.waste_desc <> 'No waste picked up'
	    and s.image_id is null

-- Catch missing bol scans
    INSERT #DisposalValidation
     SELECT 
    	'Missing BOL Scan',
    	de.source_table,
    	de.company_id,
    	de.profit_ctr_id,
    	de.receipt_id,
    	'BOL: ' + de.manifest
    from #DisposalExtract de (nolock) 
    inner join receipt r (nolock)
		on de.receipt_id = r.receipt_id
		and de.line_sequence_id = r.line_id
		and de.company_id = r.company_id
		and de.profit_ctr_id = r.profit_ctr_id
		and r.manifest_flag = 'B'
    left join plt_image..scan s (nolock)
		on de.receipt_id = s.receipt_id
		and de.company_id = s.company_id
		and de.profit_ctr_id = s.profit_ctr_id
		and de.source_table = s.document_source
		and de.manifest = s.document_name
		and s.status = 'A'
		and s.type_id in (
			select type_id
			from plt_image..scandocumenttype
			where document_type like '%BOL%'
		)
    where 1=1
		and de.source_table = 'receipt'
	    and de.waste_desc <> 'No waste picked up'
	    and s.image_id is null
union
     SELECT 
    	'Missing BOL Scan',
    	de.source_table,
    	de.company_id,
    	de.profit_ctr_id,
    	de.receipt_id,
    	'BOL: ' + de.manifest
    from #DisposalExtract de (nolock) 
    left join plt_image..scan s
		on de.receipt_id = s.workorder_id
		and de.company_id = s.company_id
		and de.profit_ctr_id = s.profit_ctr_id
		and de.source_table = s.document_source
		and s.status = 'A'
		and s.type_id in (
			select type_id
			from plt_image..scandocumenttype
			where document_type like '%BOL%'
		)
    where 1=1
		and de.source_table = 'workorder'
	    and de.waste_desc <> 'No waste picked up'
	    and s.image_id is null


---------------------------------
-- Export Disposal Validation
---------------------------------

	SELECT
   	problem,
   	source,
   	company_id,
   	profit_ctr_id,
   	receipt_id,
   	extra
   FROM #DisposalValidation
   ORDER BY
      problem,
      source,
      company_id,
      profit_ctr_id,
      receipt_id,
      extra



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generic_disposal_validate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generic_disposal_validate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generic_disposal_validate] TO [EQAI]
    AS [dbo];

