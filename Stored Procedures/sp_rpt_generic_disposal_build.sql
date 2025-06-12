--drop proc sp_rpt_generic_disposal_build
--go

CREATE PROCEDURE sp_rpt_generic_disposal_build (
	@customer_id_list		varchar(max)='',
    @start_date             datetime,
    @end_date               datetime,
    @generator_id_list varchar(max)=''  /* Added 2019-07-17 by AA */
)
AS
/* ***********************************************************
Procedure    : sp_rpt_generic_disposal_build
Database     : PLT_AI
Created      : Aug 13 2014 - Jonathan Broome
Description  : Stolen from Wal-Mart, modified for anyone.

SELECT * FROM customer where cust_name like 'harbor%'
 
Examples:
    sp_rpt_generic_disposal_build '14231', '12/1/2013 00:00', '12/31/2013 23:59'

    sp_rpt_generic_disposal_build '14164', '6/1/2019', '10/7/2019', '117083, 122207, 117406'

    sp_rpt_generic_disposal_build '14164', '6/1/2019', '10/7/2019', ''

	SELECT * FROM #DisposalExtract where calculated_pounds <> 0
	truncate table #DisposalExtract

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
	10/7/2019 - MPM	- DevOps 11620: Added logic to filter the result set
						using optional input parameter @generator_id_list.

Assumes this table exists:
	-- drop table #DisposalExtract
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

*********************************************************** */
SET NOCOUNT ON
SET ANSI_WARNINGS OFF
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

--- declare @customer_id_list		varchar(max) = '12113', @start_date             datetime = '5/1/2013 00:00', @end_date               datetime = '05/31/2013 23:59'

-- Define extract values:
DECLARE
    @extract_id             int,
    @debug                  int

-- Declare internal variables for the input parameters to prevent query caching
DECLARE	
	@i_start_date	datetime = @start_date
	, @i_end_date	datetime = @end_date
    , @i_customer_id_list	varchar(max) = isnull(@customer_id_list, '')
    , @i_generator_id_list	varchar(max) = isnull(@generator_id_list, '')

-- Fix/Set EndDate's time.
	if isnull(@i_end_date,'') <> ''
		if datepart(hh, @i_end_date) = 0 set @i_end_date = @i_end_date + 0.99999

SELECT
    @debug                  = 0
    
CREATE TABLE #Customer (
	customer_id 	bigint
)

INSERT #Customer 
SELECT convert(bigint, row)
from dbo.fn_SplitXSVText(',', 1, @i_customer_id_list)
where row is not null

CREATE TABLE #Generator (
	generator_id 	bigint
)

INSERT #Generator 
SELECT convert(bigint, row)
from dbo.fn_SplitXSVText(',', 1, @i_generator_id_list)
where row is not null

	CREATE TABLE #ReceiptTransporter(
		[receipt_id] [int] NULL,
		[line_id] [int] NULL,
		[company_id] [int] NULL,
		[profit_ctr_id] [int] NULL,
		[receipt_workorder_id] [int] NULL,
		[workorder_company_id] [int] NULL,
		[workorder_profit_ctr_id] [int] NULL,
		[service_date] [datetime] NULL,
		[receipt_date] [datetime] NULL,
		[calc_recent_wo_flag] [char](1) NULL,
		[transporter1] [varchar](15) NULL,
		[transporter2] [varchar](15) NULL
	)

	
/* *************************************************************

Build Phase...
    Insert records to #Extract from
    1. TSDF (3rd party) disposal
    2. Receipt (EQ) disposal
    3. No-Waste Pickup Workorders


************************************************************** */


-- Work Orders using TSDFApprovals
insert #DisposalExtract
SELECT DISTINCT
    g.site_code AS site_code,
    gst.generator_site_type_abbr AS site_type_abbr,
    g.generator_city AS generator_city,
    g.generator_state AS generator_state,
   	coalesce(wos.date_act_arrive, w.start_date) as service_date,
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
	convert(int, Round(ISNULL(
		(
			SELECT 
				quantity
				FROM WorkOrderDetailUnit a (nolock)
				WHERE a.workorder_id = d.workorder_id
				AND a.company_id = d.company_id
				AND a.profit_ctr_id = d.profit_ctr_id
				AND a.sequence_id = d.sequence_id
				AND a.bill_unit_code = 'LBS'
		) 
	, 0), 0)) as pounds, -- workorder detail pounds

	(
		SELECT 
			sum( 
				isnull(wodi.merchandise_quantity, 0) * isnull(p.residue_pounds_factor, 0)
			)
		FROM WorkOrderDetail d2 (nolock)
		INNER JOIN WorkOrderDetailItem wodi (nolock)
			on d2.workorder_id = wodi.workorder_id
			and d2.sequence_id = wodi.sequence_id
			and d2.company_id = wodi.company_id
			and d2.profit_ctr_id = wodi.profit_ctr_id
		LEFT JOIN Profile p
			on d2.profile_id = p.profile_id
			and isnull(p.residue_manifest_print_flag, 'F') = 'T'
		WHERE d.workorder_id = d2.workorder_id
			and d.sequence_id = d2.sequence_id
			and d.company_id = d2.company_id
			and d.profit_ctr_id = d2.profit_ctr_id
			
	) as calculated_pounds,
	
	(
		SELECT 
			sum( 
				isnull(wodi.merchandise_quantity, 0)
			)
		FROM WorkOrderDetail d2 (nolock)
		INNER JOIN WorkOrderDetailItem wodi (nolock)
			on d2.workorder_id = wodi.workorder_id
			and d2.sequence_id = wodi.sequence_id
			and d2.company_id = wodi.company_id
			and d2.profit_ctr_id = wodi.profit_ctr_id
		LEFT JOIN Profile p
			on d2.profile_id = p.profile_id
			and isnull(p.empty_bottle_flag, 'F') = 'T'
		WHERE d.workorder_id = d2.workorder_id
			and d.sequence_id = d2.sequence_id
			and d.company_id = d2.company_id
			and d.profit_ctr_id = d2.profit_ctr_id
			
	) as empty_bottle_count,
	
    b.bill_unit_desc AS bill_unit_desc,
    ISNULL( 
        CASE
                WHEN u.quantity IS NULL
                THEN IsNull(d.quantity,0)
                ELSE u.quantity
        END
    , 0) AS quantity,
    t.waste_desc AS waste_desc,
    CASE WHEN ISNULL(d.tsdf_approval_code, '') = '' THEN
        d.resource_class_code
    ELSE
        d.tsdf_approval_code
    END AS approval_or_resource,
    NULL as dot_description,        -- Populated later
    null as waste_code_1,           -- Populated later
    null as waste_code_2,           -- Populated later
    null as waste_code_3,           -- Populated later
    null as waste_code_4,           -- Populated later
    null as waste_code_5,           -- Populated later
    null as waste_code_6,           -- Populated later
    null as waste_code_7,           -- Populated later
    null as waste_code_8,           -- Populated later
    null as waste_code_9,           -- Populated later
    null as waste_code_10,          -- Populated later
    null as waste_code_11,          -- Populated later
    null as waste_code_12,          -- Populated later
    null as state_waste_code_1,     -- Populated later
    null as state_waste_code_2,     -- Populated later
    null as state_waste_code_3,     -- Populated later
	null as state_waste_code_4,     -- Populated later
    null as state_waste_code_5,     -- Populated later
    t.management_code AS management_code,
    t.EPA_source_code AS EPA_source_code,
    t.EPA_form_code AS EPA_form_code,
    null AS transporter1_name,      -- Populated later
    null as transporter1_epa_id,    -- Populated later
    null as transporter2_name,      -- Populated later
    null as transporter2_epa_id,    -- Populated later
    t2.TSDF_name AS receiving_facility,
    t2.TSDF_epa_id AS receiving_facility_epa_id,
    d.workorder_id as receipt_id,
	CASE 
	  WHEN t.disposal_service_id = (select disposal_service_id from DisposalService (nolock) where disposal_service_desc = 'Other') THEN 
		  t.disposal_service_other_desc
	  ELSE
		  ds.disposal_service_desc
	END as disposal_service_desc,
    w.company_id,
    w.profit_ctr_id,
    d.sequence_id,
    g.generator_id,
    g.generator_name AS generator_name,
    g.site_type AS site_type,
    d.manifest_page_num AS manifest_page,
    d.resource_type AS item_type,
    t.tsdf_approval_id,
    d.profile_id AS profile_id,
    ISNULL(d.container_count, 0) AS container_count,
    null, -- AS waste_codes,
    null, -- AS state_waste_codes,
    wot1.transporter_code AS transporter1_code,
    wot2.transporter_code AS transporter2_code,
    wot1.transporter_sign_date AS date_delivered,
    'Workorder' AS source_table,
    NULL AS receipt_date,
    NULL AS receipt_workorder_id,
    w.start_date AS workorder_start_date,
    NULL AS workorder_company_id,
    NULL AS workorder_profit_ctr_id,
    w.customer_id AS customer_id,
    cust.cust_name,
    w.billing_project_id,
    cb.project_name,
	w.purchase_order,
    t.hazmat as haz_flag,
    w.submitted_flag,
    g.generator_address_1,
    g.generator_address_2,
	c.county_name as generator_county,
	g.generator_zip_code,
	g.generator_region_code,
	g.generator_division,
	g.generator_business_unit,
	bu.bill_unit_desc,
	wodu.quantity as manifest_quantity
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN Generator g  (nolock) ON w.generator_id = g.generator_id
INNER JOIN Customer cust (nolock) ON w.customer_id = cust.customer_id
LEFT OUTER JOIN workorderdetailunit u (nolock) on d.workorder_id = u.workorder_id and d.sequence_id = u.sequence_id and d.company_id = u.company_id and d.profit_ctr_id = u.profit_ctr_id and u.billing_flag = 'T'
LEFT OUTER JOIN BillUnit b  (nolock) ON isnull(u.bill_unit_code, d.bill_unit_code) = b.bill_unit_code
LEFT OUTER JOIN workorderdetailunit wodu (nolock) on d.workorder_id = wodu.workorder_id and d.sequence_id = wodu.sequence_id and d.company_id = wodu.company_id and d.profit_ctr_id = wodu.profit_ctr_id and wodu.manifest_flag = 'T'
LEFT OUTER JOIN BillUnit bu  (nolock) ON isnull(wodu.bill_unit_code, d.bill_unit_code) = bu.bill_unit_code
LEFT OUTER JOIN TSDFApproval t  (nolock) ON d.tsdf_approval_id = t.tsdf_approval_id
    AND d.company_id = t.company_id
    AND d.profit_ctr_id = t.profit_ctr_id
LEFT OUTER JOIN TSDF t2  (nolock) ON d.tsdf_code = t2.tsdf_code
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
LEFT OUTER JOIN WorkOrderTransporter wot1 (nolock) ON w.workorder_id = wot1.workorder_id and w.company_id = wot1.company_id and w.profit_ctr_id = wot1.profit_ctr_id and d.manifest = wot1.manifest and wot1.transporter_sequence_id = 1
LEFT OUTER JOIN WorkOrderTransporter wot2 (nolock) ON w.workorder_id = wot2.workorder_id and w.company_id = wot2.company_id and w.profit_ctr_id = wot2.profit_ctr_id and d.manifest = wot2.manifest and wot2.transporter_sequence_id = 2
LEFT OUTER JOIN DisposalService ds  (nolock) ON t.disposal_service_id = ds.disposal_service_id
LEFT OUTER JOIN County c (nolock) ON g.generator_county = c.county_code
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
	and wos.company_id = w.company_id
	and wos.profit_ctr_id = w.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
LEFT JOIN CustomerBilling cb (nolock) on w.customer_id = cb.customer_id and w.billing_project_id = cb.billing_project_id
WHERE 1=1
AND (w.customer_id IN (select customer_id from #Customer)
    OR w.generator_id IN (SELECT generator_id FROM customergenerator  (nolock) WHERE customer_id IN (select customer_id from #Customer))
)
AND w.start_date BETWEEN @i_start_date AND @i_end_date
AND ISNULL(t2.eq_flag, 'F') = 'F'
AND d.resource_type = 'D'
AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
AND d.bill_rate NOT IN (-2)
and
(
	@i_generator_id_list = ''
	or
	(
		@i_generator_id_list <> ''
		and
		w.generator_id in (select generator_id from #generator)
	)
)

--  PRINT 'Receipt/Transporter Fix'
/*

12/7/2010 - The primary source for EQ data is the Receipt table.
	It's out of order in the select logic below and needs to be reviewed/revised
	because it's misleading.
	
This query has 2 union'd components:
first component: workorder inner join to billinglinklookup and receipt
third component: receipt not linked to either BLL or 
*/
    INSERT #ReceiptTransporter
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
        CASE WHEN rt1.transporter_code IS NULL THEN
            r.hauler
        ELSE
            rt1.transporter_code 
        END as transporter1,
        rt2.transporter_code as transporter2
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
        wo.start_date between @i_start_date AND @i_end_date
        and (1=0
            or wo.customer_id IN (select customer_id from #Customer)
            or wo.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from #Customer))
            or r.customer_id IN (select customer_id from #Customer)
            or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from #Customer))
        )
		and
		(
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
				wo.generator_id in (select generator_id from #generator)
			)
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
        CASE WHEN rt1.transporter_code IS NULL THEN
            r.hauler
        ELSE
            rt1.transporter_code 
        END as transporter1,
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
    where
        coalesce(rt1.transporter_sign_date, r.receipt_date) between @i_start_date AND @i_end_date
        and (r.customer_id IN (select customer_id from #Customer)
            or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from #Customer))
        )
        and not exists (
            select receipt_id from billinglinklookup bll (nolock) 
            where bll.company_id = r.company_id
            and bll.profit_ctr_id = r.profit_ctr_id
            and bll.receipt_id = r.receipt_id
        )
		and
		(
			@i_generator_id_list = ''
			or
			(
				@i_generator_id_list <> ''
				and
				r.generator_id in (select generator_id from #generator)
			)
		)

-- Fix #ReceiptTransporter records...
    --  PRINT 'Can''t allow null transporter1 and populated transporter2, so move the data to transporter1 field.'
        UPDATE #ReceiptTransporter set transporter1 = transporter2
        WHERE ISNULL(transporter1, '') = '' and ISNULL(transporter2, '') <> ''

    --  PRINT 'Can''t have the same transporter for both fields.'
        UPDATE #ReceiptTransporter set transporter2 = null
        WHERE transporter2 = transporter1


-- Receipts
INSERT #DisposalExtract
SELECT distinct

    g.site_code AS site_code,
    gst.generator_site_type_abbr AS site_type_abbr,
    g.generator_city AS generator_city,
    g.generator_state AS generator_state,
    wrt.service_date,
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
    dbo.fn_receipt_weight_line ( r.receipt_id,	r.line_id,  r.profit_ctr_id,    r.company_id) as pounds,
	-- NULL as pounds, -- pull in NULL for now, we'll update it from Receipt.Net_weight later - 12/20/2010
	isnull(p.residue_pounds_factor, 0) * sum(isnull(rdi.merchandise_quantity, 0)) as calculated_pounds,
	sum(case when isnull(p.empty_bottle_flag, 'F') = 'T' then isnull(rdi.merchandise_quantity, 0) else 0 end) as empty_bottle_count,
    b.bill_unit_desc AS bill_unit_desc,
    ISNULL(max(rp.bill_quantity), 0) AS quantity,
    p.Approval_desc AS waste_desc,
    COALESCE(r.approval_code, r.service_desc) AS approval_or_resource,
    NULL as dot_description,        -- Populated later
    null as waste_code_1,           -- Populated later
    null as waste_code_2,           -- Populated later
    null as waste_code_3,           -- Populated later
    null as waste_code_4,           -- Populated later
    null as waste_code_5,           -- Populated later
    null as waste_code_6,           -- Populated later
    null as waste_code_7,           -- Populated later
    null as waste_code_8,           -- Populated later
    null as waste_code_9,           -- Populated later
    null as waste_code_10,          -- Populated later
    null as waste_code_11,          -- Populated later
    null as waste_code_12,          -- Populated later
    null as state_waste_code_1,     -- Populated later
    null as state_waste_code_2,     -- Populated later
    null as state_waste_code_3,     -- Populated later
    null as state_waste_code_4,     -- Populated later
    null as state_waste_code_5,     -- Populated later
    tr.management_code,
    p.EPA_source_code,
    EPA_form_code,
    null AS transporter1_name,      -- Populated later
    null as transporter1_epa_id,    -- Populated later
    null as transporter2_name,      -- Populated later
    null as transporter2_epa_id,    -- Populated later
    pr.profit_ctr_name AS receiving_facility,
    (select epa_id from profitcenter  (nolock) where company_id = r.company_id and profit_ctr_id = r.profit_ctr_id) AS receiving_facility_epa_id,
    wrt.receipt_id,
    ds.disposal_service_desc,

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
    null, -- AS waste_codes,
	null, -- AS state_waste_codes,
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
    cust.cust_name,
    r.billing_project_id,
    cb.project_name,
	r.purchase_order,
    p.hazmat as haz_flag,
    r.submitted_flag,
    g.generator_address_1,
    g.generator_address_2,
	c.county_name as generator_county,
	g.generator_zip_code,
	g.generator_region_code,
	g.generator_division,
	g.generator_business_unit,
	bu.bill_unit_desc,
	r.manifest_quantity 
FROM Receipt r (nolock) 
INNER JOIN ReceiptPrice rp  (nolock) ON
    R.receipt_id = rp.receipt_id
    and r.line_id = rp.line_id
    and r.company_id = rp.company_id
    and r.profit_ctr_id = rp.profit_ctr_id
INNER JOIN Generator g  (nolock) ON r.generator_id = g.generator_id
INNER JOIN Customer cust (nolock) ON r.customer_id = cust.customer_id
INNER JOIN BillUnit b  (nolock) ON rp.bill_unit_code = b.bill_unit_code 
INNER JOIN #ReceiptTransporter wrt ON
    r.company_id = wrt.company_id
    and r.profit_ctr_id = wrt.profit_ctr_id
    and r.receipt_id = wrt.receipt_id
    and r.line_id = wrt.line_id
INNER JOIN ProfitCenter pr (nolock) on r.company_id = pr.company_id and r.profit_ctr_id = pr.profit_ctr_id
LEFT OUTER JOIN Profile p  (nolock) ON r.profile_id = p.profile_id
LEFT OUTER JOIN BillUnit bu  (nolock) ON r.manifest_unit = bu.manifest_unit 
LEFT OUTER JOIN Treatment tr  (nolock) ON 
	r.treatment_id = tr.treatment_id 
	and r.company_id = tr.company_id 
	and r.profit_ctr_id = tr.profit_ctr_id
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
LEFT OUTER JOIN County c (nolock) ON g.generator_county = c.county_code
LEFT OUTER JOIN ProfileQuoteApproval pqa  (nolock)
    on r.profile_id = pqa.profile_id 
    and r.company_id = pqa.company_id 
    and r.profit_ctr_id = pqa.profit_ctr_id 
LEFT OUTER JOIN ReceiptDetailItem rdi (nolock)
    on r.company_id = rdi.company_id
    and r.profit_ctr_id = rdi.profit_ctr_id
    and r.receipt_id = rdi.receipt_id
    and r.line_id = rdi.line_id
LEFT OUTER JOIN DisposalService ds  (nolock)
    on pqa.disposal_service_id = ds.disposal_service_id
left join CustomerBilling cb (nolock) on r.customer_id = cb.customer_id and r.billing_project_id = cb.billing_project_id
WHERE r.receipt_status = 'A'
AND r.fingerpr_status = 'A'
AND ISNULL(r.trans_type, '') = 'D'
AND r.trans_mode = 'I'
GROUP BY
    g.site_code,
    gst.generator_site_type_abbr,
    g.generator_city,
    g.generator_state,
    wrt.service_date,
    g.EPA_ID,
    r.manifest,
    r.manifest_page_num,
    r.manifest_line,
    r.line_weight,
    p.residue_pounds_factor,
    b.bill_unit_desc,
    r.quantity,
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
    cust.cust_name,
    r.billing_project_id,
    cb.project_name,
	r.purchase_order,
    p.hazmat,
    r.submitted_flag,
    g.generator_address_1,
    g.generator_address_2,
	c.county_name,
	g.generator_zip_code,
	g.generator_region_code,
	g.generator_division,
	g.generator_business_unit,
    bu.bill_unit_desc,
    r.manifest_quantity 

-- No-Waste Pickup Records:
INSERT #DisposalExtract
	SELECT DISTINCT
	g.site_code AS site_code,
	gst.generator_site_type_abbr AS site_type_abbr,
	g.generator_city AS generator_city,
	g.generator_state AS generator_state,
	w.start_date AS service_date,
	g.epa_id AS epa_id,
	null AS manifest,
	1 AS manifest_line,
	0 AS pounds,
	0 as calculated_pounds,
	0 as empty_bottle_count,
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
	cust.cust_name,
	w.billing_project_id,
	cb.project_name,
	w.purchase_order,
	null AS haz_flag,
	'T' as submitted_flag,
	g.generator_address_1,
    g.generator_address_2,
	c.county_name as generator_county,
	g.generator_zip_code,
	g.generator_region_code,
	g.generator_division,
	g.generator_business_unit,
	'' as bill_unit_desc,
	'' as manifest_quantity 
	FROM WorkOrderHeader w (nolock) 
	INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
	INNER JOIN Generator g  (nolock) ON w.generator_id = g.generator_id
	INNER JOIN Customer cust (nolock) on w.customer_id = cust.customer_id
    LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
    LEFT OUTER JOIN County c (nolock) ON g.generator_county = c.county_code
    LEFT OUTER JOIN WorkOrderStop wos (nolock) ON w.workorder_id = wos.workorder_id and w.company_id = wos.company_id and w.profit_ctr_id = wos.profit_ctr_id 
    	and wos.stop_sequence_id = 1
    left join CustomerBilling cb (nolock) on w.customer_id = cb.customer_id and w.billing_project_id = cb.billing_project_id
	WHERE 1=1
	AND (w.customer_id IN (select customer_id from #Customer)
	    OR w.generator_id IN (SELECT generator_id FROM customergenerator  (nolock) WHERE customer_id IN (select customer_id from #Customer))
	)
	AND w.start_date BETWEEN @i_start_date AND @i_end_date
	AND w.submitted_flag = 'T'
	AND w.workorder_status IN ('A','C','D','N','P','X')
	AND d.bill_rate NOT IN (-2)
	AND d.resource_class_code = 'STOPFEE'
	AND wos.decline_id > 1
	AND (
	    (wos.waste_flag = 'F')
	)    
	and
	(
		@i_generator_id_list = ''
		or
		(
			@i_generator_id_list <> ''
			and
			w.generator_id in (select generator_id from #generator)
		)
	)

-- Update fields left null in #Extract
UPDATE #DisposalExtract set
    dot_description =
        CASE WHEN e.tsdf_approval_id IS NOT NULL THEN
            left(dbo.fn_manifest_dot_description('T', e.tsdf_approval_id), 255)
        ELSE
            CASE WHEN e.profile_id IS NOT NULL THEN
                left(dbo.fn_manifest_dot_description('P', e.profile_id), 255)
            ELSE
                ''
            END
        END,
    transporter1_name = t1.transporter_name,
    transporter1_epa_id = t1.transporter_epa_id,
    transporter2_name = t2.transporter_name,
    transporter2_epa_id = t2.transporter_epa_id
FROM 
	#DisposalExtract e (nolock)
	left outer join Transporter t1 (nolock)
		on e.transporter1_code = t1.transporter_code
	left outer join Transporter t2 (nolock)
		on e.transporter2_code = t2.transporter_code
WHERE e.submitted_flag = 'T'

	-- don't print un-needed commas
	update #DisposalExtract set dot_description = replace(dot_description, ',,', ',') where dot_description like '%,,%' 
	update #DisposalExtract set dot_description = replace(dot_description, ', ,', ',') where dot_description like '%, ,%' 
	update #DisposalExtract set dot_description = replace(dot_description, ',  ,', ',') where dot_description like '%,  ,%' 

	-- Trim trailing/leading blanks
	update #DisposalExtract set dot_description = ltrim(rtrim(dot_description)) 

	-- Don't print leading or trailing commas
	update #DisposalExtract set dot_description = ltrim(rtrim(left(dot_description, len(dot_description)-1))) where dot_description like '%,' 
	update #DisposalExtract set dot_description = ltrim(rtrim(right(dot_description, len(dot_description)-1))) where dot_description like ',%' 

-- 11/01/2012 - JPB
-- Format Management Description per Brie:
	-- Change management codes that list LIW to NONE
	update #DisposalExtract set management_code = 'NONE' where management_code = 'LIW' 
			



-- Create a table for waste codes
	create table #Waste_Codes (
		source				varchar(20),
		tsdf_approval_id	int,
		receipt_id			int,
		line_id				int,
		company_id			int,
		profit_ctr_id		int,
		sequence_id			int,
		origin				char(1),
		generator_state		char(2),
		waste_code_state	char(2),
		waste_code			varchar(10),
		waste_code_uid		int,
		tsdf_state			char(2)
		
	)
	create index idx_1 on #Waste_Codes (source, tsdf_approval_id, origin, sequence_id, waste_code)
	create index idx_2 on #Waste_Codes (source, receipt_id, line_id, company_id, profit_ctr_id, origin, sequence_id, waste_code)
	create index idx_3 on #Waste_Codes (waste_code_uid)

-- Workorder Waste Codes --(1)
	insert #Waste_Codes (source, tsdf_approval_id, sequence_id, origin, generator_state, waste_code_state, waste_code, waste_code_uid, tsdf_state)
	select distinct
		e.source_table,
		xwc.tsdf_approval_id,
		1 as sequence_id,
		wc.waste_code_origin,
		e.generator_state,
		wc.state as waste_code_state,
		wc.display_name
		, wc.waste_code_uid
		, left(isnull(receiving_facility_epa_id, ''), 2)
	FROM TSDFApprovalWasteCode xwc (nolock)
		INNER JOIN WasteCode wc (nolock) ON xwc.waste_code_uid = wc.waste_code_uid
		INNER JOIN #DisposalExtract e (nolock)
			on e.tsdf_approval_id = xwc.tsdf_approval_id
	WHERE e.source_table = 'Workorder'
		and e.submitted_flag = 'T'
		AND xwc.primary_flag = 'T'
		AND wc.waste_code_origin in ('F', 'S')



-- Workorder Waste Codes (2+)
	insert #Waste_Codes (source, tsdf_approval_id, sequence_id, origin, generator_state, waste_code_state, waste_code, waste_code_uid, tsdf_state)
	select distinct
		e.source_table,
		xwc.tsdf_approval_id,
		2,
		wc.waste_code_origin,
		e.generator_state,
		wc.state as waste_code_state,
		wc.display_name
		, wc.waste_code_uid
		, left(isnull(receiving_facility_epa_id, ''), 2)
	FROM TSDFApprovalWasteCode xwc (nolock)
		INNER JOIN WasteCode wc (nolock) ON xwc.waste_code_uid = wc.waste_code_uid
		INNER JOIN #DisposalExtract e (nolock)
			on e.tsdf_approval_id = xwc.tsdf_approval_id
	WHERE e.source_table = 'Workorder'
		and e.submitted_flag = 'T'
		AND wc.waste_code_origin in ('F', 'S')
		and wc.display_name not in (select waste_code from #Waste_Codes
			where source = e.source_table 
			and tsdf_approval_id = xwc.tsdf_approval_id 
			)
	ORDER BY wc.display_name


-- Receipt Waste Codes (1)
	insert #Waste_codes (source, receipt_id, line_id, company_id, profit_ctr_id, sequence_id, origin, generator_state, waste_code_state, waste_code, waste_code_uid, tsdf_state)
	select distinct
		e.source_table,
		xwc.receipt_id,
		xwc.line_id,
		xwc.company_id,
		xwc.profit_ctr_id,
		1 as sequence_id,
		wc.waste_code_origin,
		e.generator_state,
		wc.state as waste_code_state,
		wc.display_name
		, wc.waste_code_uid
		, left(isnull(receiving_facility_epa_id, ''), 2)
	FROM ReceiptWasteCode xwc (nolock)
	INNER JOIN wastecode wc (nolock) on xwc.waste_code_uid = wc.waste_code_uid
	INNER JOIN #DisposalExtract e (nolock)
		on e.receipt_id = xwc.receipt_id
		and e.line_sequence_id = xwc.line_id
		and e.company_id = xwc.company_id
		and e.profit_ctr_id = xwc.profit_ctr_id
	WHERE e.source_table = 'Receipt'
		and e.submitted_flag = 'T'
		AND xwc.primary_flag = 'T'
		AND wc.waste_code_origin in ('F', 'S')


-- Receipt Waste Codes (2+)
	insert #Waste_codes (source, receipt_id, line_id, company_id, profit_ctr_id, sequence_id, origin, generator_state, waste_code_state, waste_code, waste_code_uid, tsdf_state)
	select distinct
		e.source_table,
		xwc.receipt_id,
		xwc.line_id,
		xwc.company_id,
		xwc.profit_ctr_id,
		2 as sequence_id,
		wc.waste_code_origin,
		e.generator_state,
		wc.state as waste_code_state,
		wc.display_name
		, wc.waste_code_uid
		, left(isnull(receiving_facility_epa_id, ''), 2)
	FROM ReceiptWasteCode xwc (nolock)
	INNER JOIN wastecode wc (nolock) on xwc.waste_code_uid = wc.waste_code_uid
	INNER JOIN #DisposalExtract e (nolock)
		on e.receipt_id = xwc.receipt_id
		and e.line_sequence_id = xwc.line_id
		and e.company_id = xwc.company_id
		and e.profit_ctr_id = xwc.profit_ctr_id
	WHERE e.source_table = 'Receipt'
		and e.submitted_flag = 'T'
		AND wc.waste_code_origin in ('F', 'S')
		and wc.display_name not in (select waste_code from #Waste_Codes
			where source = e.source_table 
			and receipt_id = xwc.receipt_id
			and line_id = xwc.line_id
			and company_id = xwc.company_id
			and profit_ctr_id = xwc.profit_ctr_id
			)
	ORDER BY wc.display_name


-- Don't include UNIV
delete from #Waste_Codes where waste_code = 'UNIV'

-- Don't include NONE
delete from #Waste_Codes where waste_code = 'NONE'

-- Don't include .
delete from #Waste_Codes where waste_code = '.'

-- Omit state waste codes that don't belong to the generator state or tsdf state (9/10/2013)
delete from #Waste_Codes from #Waste_Codes w
inner join WasteCode wc on w.waste_code_uid = wc.waste_code_uid
where w.origin = 'S' and wc.state not in (w.generator_state, w.tsdf_state)

/* ********************************************
12/15/2011 modification - JPB per Brie, LT, : Waste codes should be listed alphabetically, with P codes first
**********************************************/
update #Waste_codes SET 
	sequence_id = w.new_order
FROM
	#Waste_codes x INNER JOIN
	(
	SELECT 
		row_number() OVER (PARTITION BY source, receipt_id, line_id, origin ORDER by CASE WHEN left(waste_code, 1) = 'P' then 1 else 2 end, waste_code) as new_order,
		source			,
		tsdf_approval_id,
		receipt_id		,
		line_id			,
		company_id		,
		profit_ctr_id	,
		origin			,
		waste_code		
	FROM #Waste_codes
	) w
	ON x.source = w.source
	and x.receipt_id = w.receipt_id
	and x.line_id = w.line_id
	and x.company_id = w.company_id
	and x.profit_ctr_id = w.profit_ctr_id
	and x.waste_code = w.waste_code
	WHERE x.origin = 'F'

/*
* 7/5/2013: State Waste Codes should be ordered with the codes that belong to the generator's state first
* 9/10/2013: TSDF State codes are placed after generator state codes, all others come 3rd
*/
update #Waste_codes SET 
	sequence_id = w.new_order
FROM
	#Waste_codes x INNER JOIN
	(
	SELECT 
		row_number() OVER (PARTITION BY source, receipt_id, line_id, origin ORDER by CASE WHEN isnull(generator_state, '') = isnull(waste_code_state, '') then 1 else case when isnull(tsdf_state, '') = isnull(waste_code_state, '') then 2 else 3 end end, waste_code) as new_order,
		source			,
		tsdf_approval_id,
		receipt_id		,
		line_id			,
		company_id		,
		profit_ctr_id	,
		origin			,
		waste_code		
	FROM #Waste_codes
	) w
	ON x.source = w.source
	and x.receipt_id = w.receipt_id
	and x.line_id = w.line_id
	and x.company_id = w.company_id
	and x.profit_ctr_id = w.profit_ctr_id
	and x.waste_code = w.waste_code
	WHERE x.origin = 'S'

	
-- Update Waste Codes for WOs		
UPDATE #DisposalExtract set
    waste_code_1  = coalesce(ft1.waste_code, 'NONE'),
    waste_code_2  = coalesce(ft2.waste_code, ''),
    waste_code_3  = coalesce(ft3.waste_code, ''),
    waste_code_4  = coalesce(ft4.waste_code, ''),
    waste_code_5  = coalesce(ft5.waste_code, ''),
    waste_code_6  = coalesce(ft6.waste_code, ''),
    waste_code_7  = coalesce(ft7.waste_code, ''),
    waste_code_8  = coalesce(ft8.waste_code, ''),
    waste_code_9  = coalesce(ft9.waste_code, ''),
    waste_code_10 = coalesce(ft10.waste_code, ''),
    waste_code_11 = coalesce(ft11.waste_code, ''),
    waste_code_12 = coalesce(ft12.waste_code, ''),
    state_waste_code_1 = coalesce(st1.waste_code, 'NONE'),
    state_waste_code_2 = coalesce(st2.waste_code, ''),
    state_waste_code_3 = coalesce(st3.waste_code, ''),
    state_waste_code_4 = coalesce(st4.waste_code, ''),
    state_waste_code_5 = coalesce(st5.waste_code, '')
FROM 
	#DisposalExtract e (nolock)
	left outer join #Waste_codes ft1 on  ft1.source = e.source_table and ft1.tsdf_approval_id = e.tsdf_approval_id and ft1.origin = 'F' and ft1.sequence_id = 1
	left outer join #Waste_codes ft2 on  ft2.source = e.source_table and ft2.tsdf_approval_id = e.tsdf_approval_id and ft2.origin = 'F' and ft2.sequence_id = 2		
	left outer join #Waste_codes ft3 on  ft3.source = e.source_table and ft3.tsdf_approval_id = e.tsdf_approval_id and ft3.origin = 'F' and ft3.sequence_id = 3		
	left outer join #Waste_codes ft4 on  ft4.source = e.source_table and ft4.tsdf_approval_id = e.tsdf_approval_id and ft4.origin = 'F' and ft4.sequence_id = 4		
	left outer join #Waste_codes ft5 on  ft5.source = e.source_table and ft5.tsdf_approval_id = e.tsdf_approval_id and ft5.origin = 'F' and ft5.sequence_id = 5		
	left outer join #Waste_codes ft6 on  ft6.source = e.source_table and ft6.tsdf_approval_id = e.tsdf_approval_id and ft6.origin = 'F' and ft6.sequence_id = 6		
	left outer join #Waste_codes ft7 on  ft7.source = e.source_table and ft7.tsdf_approval_id = e.tsdf_approval_id and ft7.origin = 'F' and ft7.sequence_id = 7		
	left outer join #Waste_codes ft8 on  ft8.source = e.source_table and ft8.tsdf_approval_id = e.tsdf_approval_id and ft8.origin = 'F' and ft8.sequence_id = 8
	left outer join #Waste_codes ft9 on  ft9.source = e.source_table and ft9.tsdf_approval_id = e.tsdf_approval_id and ft9.origin = 'F' and ft9.sequence_id = 9
	left outer join #Waste_codes ft10 on ft10.source = e.source_table and ft10.tsdf_approval_id = e.tsdf_approval_id and ft10.origin = 'F' and ft10.sequence_id = 10
	left outer join #Waste_codes ft11 on ft11.source = e.source_table and ft11.tsdf_approval_id = e.tsdf_approval_id and ft11.origin = 'F' and ft11.sequence_id = 11
	left outer join #Waste_codes ft12 on ft12.source = e.source_table and ft12.tsdf_approval_id = e.tsdf_approval_id and ft12.origin = 'F' and ft12.sequence_id = 12
	left outer join #Waste_codes st1 on st1.source = e.source_table and st1.tsdf_approval_id = e.tsdf_approval_id and st1.origin = 'S' and st1.sequence_id = 1
	left outer join #Waste_codes st2 on st2.source = e.source_table and st2.tsdf_approval_id = e.tsdf_approval_id and st2.origin = 'S' and st2.sequence_id = 2
	left outer join #Waste_codes st3 on st3.source = e.source_table and st3.tsdf_approval_id = e.tsdf_approval_id and st3.origin = 'S' and st3.sequence_id = 3
	left outer join #Waste_codes st4 on st4.source = e.source_table and st4.tsdf_approval_id = e.tsdf_approval_id and st4.origin = 'S' and st4.sequence_id = 4
	left outer join #Waste_codes st5 on st5.source = e.source_table and st5.tsdf_approval_id = e.tsdf_approval_id and st5.origin = 'S' and st5.sequence_id = 5
WHERE e.source_table = 'Workorder'
and e.submitted_flag = 'T'


-- Update Waste Codes for Receipts
UPDATE #DisposalExtract set
    waste_code_1  = coalesce(fr1.waste_code, 'NONE'),
    waste_code_2  = coalesce(fr2.waste_code, ''),
    waste_code_3  = coalesce(fr3.waste_code, ''),
    waste_code_4  = coalesce(fr4.waste_code, ''),
    waste_code_5  = coalesce(fr5.waste_code, ''),
    waste_code_6  = coalesce(fr6.waste_code, ''),
    waste_code_7  = coalesce(fr7.waste_code, ''),
    waste_code_8  = coalesce(fr8.waste_code, ''),
    waste_code_9  = coalesce(fr9.waste_code, ''),
    waste_code_10 = coalesce(fr10.waste_code, ''),
    waste_code_11 = coalesce(fr11.waste_code, ''),
    waste_code_12 = coalesce(fr12.waste_code, ''),
    state_waste_code_1 = coalesce(sr1.waste_code, 'NONE'),
    state_waste_code_2 = coalesce(sr2.waste_code, ''),
    state_waste_code_3 = coalesce(sr3.waste_code, ''),
    state_waste_code_4 = coalesce(sr4.waste_code, ''),
    state_waste_code_5 = coalesce(sr5.waste_code, '')
FROM 
	#DisposalExtract e (nolock)
	left outer join #Waste_Codes fr1 on fr1.source = e.source_table and fr1.receipt_id = e.receipt_id and fr1.line_id = e.line_sequence_id and fr1.company_id = e.company_id and fr1.profit_ctr_id = e.profit_ctr_id and fr1.origin = 'F' and fr1.sequence_id = 1
	left outer join #Waste_Codes fr2 on fr2.source = e.source_table and fr2.receipt_id = e.receipt_id and fr2.line_id = e.line_sequence_id and fr2.company_id = e.company_id and fr2.profit_ctr_id = e.profit_ctr_id and fr2.origin = 'F' and fr2.sequence_id = 2
	left outer join #Waste_Codes fr3 on fr3.source = e.source_table and fr3.receipt_id = e.receipt_id and fr3.line_id = e.line_sequence_id and fr3.company_id = e.company_id and fr3.profit_ctr_id = e.profit_ctr_id and fr3.origin = 'F' and fr3.sequence_id = 3
	left outer join #Waste_Codes fr4 on fr4.source = e.source_table and fr4.receipt_id = e.receipt_id and fr4.line_id = e.line_sequence_id and fr4.company_id = e.company_id and fr4.profit_ctr_id = e.profit_ctr_id and fr4.origin = 'F' and fr4.sequence_id = 4
	left outer join #Waste_Codes fr5 on fr5.source = e.source_table and fr5.receipt_id = e.receipt_id and fr5.line_id = e.line_sequence_id and fr5.company_id = e.company_id and fr5.profit_ctr_id = e.profit_ctr_id and fr5.origin = 'F' and fr5.sequence_id = 5
	left outer join #Waste_Codes fr6 on fr6.source = e.source_table and fr6.receipt_id = e.receipt_id and fr6.line_id = e.line_sequence_id and fr6.company_id = e.company_id and fr6.profit_ctr_id = e.profit_ctr_id and fr6.origin = 'F' and fr6.sequence_id = 6
	left outer join #Waste_Codes fr7 on fr7.source = e.source_table and fr7.receipt_id = e.receipt_id and fr7.line_id = e.line_sequence_id and fr7.company_id = e.company_id and fr7.profit_ctr_id = e.profit_ctr_id and fr7.origin = 'F' and fr7.sequence_id = 7
	left outer join #Waste_Codes fr8 on fr8.source = e.source_table and fr8.receipt_id = e.receipt_id and fr8.line_id = e.line_sequence_id and fr8.company_id = e.company_id and fr8.profit_ctr_id = e.profit_ctr_id and fr8.origin = 'F' and fr8.sequence_id = 8
	left outer join #Waste_Codes fr9 on fr9.source = e.source_table and fr9.receipt_id = e.receipt_id and fr9.line_id = e.line_sequence_id and fr9.company_id = e.company_id and fr9.profit_ctr_id = e.profit_ctr_id and fr9.origin = 'F' and fr9.sequence_id = 9
	left outer join #Waste_Codes fr10 on fr10.source = e.source_table and fr10.receipt_id = e.receipt_id and fr10.line_id = e.line_sequence_id and fr10.company_id = e.company_id and fr10.profit_ctr_id = e.profit_ctr_id and fr10.origin = 'F' and fr10.sequence_id = 10
	left outer join #Waste_Codes fr11 on fr11.source = e.source_table and fr11.receipt_id = e.receipt_id and fr11.line_id = e.line_sequence_id and fr11.company_id = e.company_id and fr11.profit_ctr_id = e.profit_ctr_id and fr11.origin = 'F' and fr11.sequence_id = 11 
	left outer join #Waste_Codes fr12 on fr12.source = e.source_table and fr12.receipt_id = e.receipt_id and fr12.line_id = e.line_sequence_id and fr12.company_id = e.company_id and fr12.profit_ctr_id = e.profit_ctr_id and fr12.origin = 'F' and fr12.sequence_id = 12
	left outer join #Waste_Codes sr1 on sr1.source = e.source_table and sr1.receipt_id = e.receipt_id  and sr1.line_id = e.line_sequence_id and sr1.company_id = e.company_id and sr1.profit_ctr_id = e.profit_ctr_id and sr1.origin = 'S' and sr1.sequence_id = 1 
	left outer join #Waste_Codes sr2 on sr2.source = e.source_table and sr2.receipt_id = e.receipt_id and sr2.line_id = e.line_sequence_id and sr2.company_id = e.company_id and sr2.profit_ctr_id = e.profit_ctr_id and sr2.origin = 'S' and sr2.sequence_id = 2
	left outer join #Waste_Codes sr3 on sr3.source = e.source_table and sr3.receipt_id = e.receipt_id and sr3.line_id = e.line_sequence_id and sr3.company_id = e.company_id and sr3.profit_ctr_id = e.profit_ctr_id and sr3.origin = 'S' and sr3.sequence_id = 3
	left outer join #Waste_Codes sr4 on sr4.source = e.source_table and sr4.receipt_id = e.receipt_id and sr4.line_id = e.line_sequence_id and sr4.company_id = e.company_id and sr4.profit_ctr_id = e.profit_ctr_id and sr4.origin = 'S' and sr4.sequence_id = 4
	left outer join #Waste_Codes sr5 on sr5.source = e.source_table and sr5.receipt_id = e.receipt_id and sr5.line_id = e.line_sequence_id and sr5.company_id = e.company_id and sr5.profit_ctr_id = e.profit_ctr_id and sr5.origin = 'S' and sr5.sequence_id = 5
WHERE e.source_table = 'Receipt' and e.submitted_flag = 'T'



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generic_disposal_build] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generic_disposal_build] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_generic_disposal_build] TO [EQAI]
    AS [dbo];

