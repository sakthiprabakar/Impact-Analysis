
CREATE PROCEDURE sp_rpt_extract_walmart_disposal_finance (
    @start_date             datetime,
    @end_date               datetime,
    @output_mode            varchar(20) = ''     -- one of: 'validation', 'generators', 'wm-extract', 'eq-extract', 'manifests'
)
AS
/* ***********************************************************
Procedure    : sp_rpt_extract_walmart_disposal_finance
Database     : PLT_AI
Created      : Jan 25 2008 - Jonathan Broome
Description  : Creates a Wal-Mart Disposal Extract

Examples:
    sp_rpt_extract_walmart_disposal_finance '1/1/2009 00:00', '1/31/2009 23:59', 'validation'
    sp_rpt_extract_walmart_disposal_finance '3/1/2009 00:00', '3/30/2009 23:59', 'eq-extract'
    sp_rpt_extract_walmart_disposal_finance '1/1/2010 00:00', '1/31/2010 23:59', 'wm-extract'
    sp_rpt_extract_walmart_disposal_finance '8/1/2010', '8/31/2010', 'eq-extract'
    select disposal_service_id, * from tsdfapproval where tsdf_approval_id = 42785

Notes:
    IMPORTANT: This script is only valid from 2007/03 and later.
        2007-01 and 2007-02 need to exclude company-14, profit-ctr-4 data.
        2007-01 needs to INCLUDE 14/4 data from the state of TN.

Puts data in these tables:
	EQ_Extract.dbo.WalmartDisposalValidation
	EQ_Extract.dbo.WalmartMissingGenerators
	EQ_Extract.dbo.WalmartDisposalExtract
	EQ_Extract.dbo.WalmartDisposalImages
	
History:

	5/6/2011 - JPB
		1. sp_rpt_extract_walmart_disposal_finance created from sp_rpt_extract_walmart_disposal
		2. Logic: Use the existing disposal extract logic to get weights
			Then create a separate temp table of financials
			Mash them together in a non-duplicative sum way.
		3. Will have to remove some limits from the disposal extract (only certain waste codes/approvals/bill projects etc)
		
	6/1/2011 - JPB
		1. per brie, change avg_invoice formula from average of grand total by invoice count to grand total divided by store count.
			OLD:	avg_invoice = round( grand_total_amt / invoice_count, 2)
			NEW:	avg_invoice = round( grand_total_amt / store_count, 2)
			
*********************************************************** */

-- Define Walmart specific extract values:
DECLARE
    @extract_datetime       datetime,
    @usr                    nvarchar(256),
    @sp_name_args           varchar(1000),
    @timer					datetime = getdate(),
    @steptimer				datetime = getdate()
SELECT
    @extract_datetime       = GETDATE(),
    @usr                    = UPPER(SUSER_SNAME()),
    @sp_name_args           = object_name(@@PROCID) + ' ''' + convert(varchar(20), @start_date) + ''', ''' + convert(varchar(20), @end_date) + ''', ''' + @output_mode + ''''


-- Fix/Set EndDate's time.
	if isnull(@end_date,'') <> ''
		if datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

IF RIGHT(@usr, 3) = '(2)'
    SELECT @usr = LEFT(@usr,(LEN(@usr)-3))


Print 'Extract started at ' + convert(varchar(40), @timer)
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

print 'Log Run Information'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

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
        'WM Disposal+Finance',
        @sp_name_args,
        GETDATE(),
        null,
        null,
        null,
        @extract_datetime,
        @usr
    )


CREATE TABLE #ApprovalNoWorkorder (
	-- These approval_codes should never have a workorder related to them
	-- So use this table during validation so we do not complain about
	-- receipts missing workorders for these.
	approval_code	varchar(20)
)
insert #ApprovalNoWorkorder values ('WMNHW10')

Create Table #Customer (
	customer_id	int
)
--INSERT #Customer select convert(int, row) from dbo.fn_SplitXsvText(',', 1, '10673, 13031, 12650')
INSERT #Customer select convert(int, row) from dbo.fn_SplitXsvText(',', 1, '10673')

CREATE TABLE #BillingProject (
	customer_id			int,
	billing_project_id	int
)
INSERT #BillingProject
SELECT cb.customer_id, cb.billing_project_id
FROM CustomerBilling cb
INNER JOIN #Customer c
	ON cb.customer_id = c.customer_id
WHERE cb.billing_project_id IN (
--	SELECT convert(int, row) from dbo.fn_SplitXsvText(' ', 1, '688 714 725 736 748 758 768 778 788 801 3231 742 689 715 726 737 749 759 769 779 789 811 1635 24 690 716 727 739 750 760 770 780 790 813 1650 3996 691 717 728 740 751 761 771 781 793 818 1684 3997 698 718 729 741 752 762 772 782 794 824 1772  701 719 730 743 753 763 773 783 795 835 1823  704 720 731 744 754 764 774 784 796 840 1826  706 721 732 745 755 765 775 785 797 1050 1834  707 723 733 746 756 766 776 786 798 1053 1858  710 724 734 747 757 767 777 787 799 1622 1893')
	SELECT convert(int, row) from dbo.fn_SplitXsvText(' ', 1, '24') where @start_date between '1/1/2010' and '12/31/2010 23:59' and len(ltrim(isnull(row, ''))) > 0 -- Bucket Program 2010
	union all
	SELECT convert(int, row) from dbo.fn_SplitXsvText(' ', 1, '3996 3997') where @start_date between '1/1/2011' and '12/31/2011 23:59' and len(ltrim(isnull(row, ''))) > 0 -- Bucket Program 2011
--	union all
--	SELECT convert(int, row) from dbo.fn_SplitXsvText(' ', 1, '3636') where @start_date between '1/1/2010' and '12/31/2010 23:59' and len(ltrim(isnull(row, ''))) > 0 -- Pharmacy Program 2010
--	union all
--	SELECT convert(int, row) from dbo.fn_SplitXsvText(' ', 1, '3998 3999') where @start_date between '1/1/2011' and '12/31/2011 23:59' and len(ltrim(isnull(row, ''))) > 0 -- Bucket Program 2011
)

-- Create table to store important site types for this query (saves on update/retype issues)
CREATE TABLE #SiteTypeToInclude (
    site_type       varchar(40)
)
-- Load #SiteTypeToInclude table values:
	INSERT #SiteTypeToInclude
		SELECT 'Neighborhood Market' 
		UNION SELECT 'Sams Club'
		UNION SELECT 'Supercenter'
		UNION SELECT 'Wal-Mart'
		UNION SELECT 'Optical Lab'
		UNION SELECT 'Wal-Mart Return Center'
 		UNION SELECT 'Wal-Mart PMDC'
		UNION SELECT 'Sams DC'
		UNION SELECT 'Wal-Mart DC'
		-- UNION SELECT 'Amigo'


-- EQ_Temp table housekeeping
-- Deletes temp data more than 2 days old, or by this user (past runs)
DELETE FROM EQ_TEMP.dbo.WalmartDisposalExtract where added_by = @usr and date_added = @extract_datetime
DELETE FROM EQ_TEMP.dbo.WalmartDisposalReceiptTransporter where added_by = @usr and date_added = @extract_datetime
DELETE FROM EQ_TEMP.dbo.WalmartExtractImages where added_by = @usr and date_added = @extract_datetime
DELETE FROM EQ_TEMP.dbo.WalmartDisposalValidation where added_by = @usr and date_added = @extract_datetime
DELETE FROM EQ_TEMP.dbo.WalmartMissingGenerators where added_by = @usr and date_added = @extract_datetime

print 'Run Setup Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()
    

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


-- Work Orders (Disposal lines only) using TSDFApprovals 
INSERT EQ_Temp..WalmartDisposalExtract
SELECT DISTINCT
    -- Walmart Fields:
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
    replace(
    CASE 
          WHEN t.disposal_service_id = (select disposal_service_id from DisposalService (nolock) where disposal_service_desc = 'Other') THEN 
            t.disposal_service_other_desc
        ELSE
            ds.disposal_service_desc
      END 
    , 'Incineration/Witness', 'Incineration') as disposal_service_desc,

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
    d.profile_id AS profile_id,
    ISNULL(d.container_count, 0) AS container_count,
    null, -- t.waste_code + ', ' + dbo.fn_approval_sec_waste_code_list(t.tsdf_approval_id, 'T') AS waste_codes,
    null, -- dbo.fn_sec_waste_code_list_state(t.tsdf_approval_id, 'T') AS state_waste_codes,
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
    t.hazmat as haz_flag,
    w.submitted_flag,
    @usr,
    @extract_datetime
    
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN Generator g  (nolock) ON w.generator_id = g.generator_id

-- Specific to finance version:
INNER JOIN #BillingProject bp ON w.customer_id = bp.customer_id and w.billing_project_id = bp.billing_project_id

LEFT OUTER JOIN workorderdetailunit u (nolock) on d.workorder_id = u.workorder_id and d.sequence_id = u.sequence_id and d.company_id = u.company_id and d.profit_ctr_id = u.profit_ctr_id and u.billing_flag = 'T'
LEFT OUTER JOIN BillUnit b  (nolock) ON isnull(u.bill_unit_code, d.bill_unit_code) = b.bill_unit_code
LEFT OUTER JOIN TSDFApproval t  (nolock) ON d.tsdf_approval_id = t.tsdf_approval_id
    AND d.company_id = t.company_id
    AND d.profit_ctr_id = t.profit_ctr_id
LEFT OUTER JOIN TSDF t2  (nolock) ON d.tsdf_code = t2.tsdf_code
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
LEFT OUTER JOIN WorkOrderTransporter wot1 (nolock) ON w.workorder_id = wot1.workorder_id and w.company_id = wot1.company_id and w.profit_ctr_id = wot1.profit_ctr_id and d.manifest = wot1.manifest and wot1.transporter_sequence_id = 1
LEFT OUTER JOIN WorkOrderTransporter wot2 (nolock) ON w.workorder_id = wot2.workorder_id and w.company_id = wot2.company_id and w.profit_ctr_id = wot2.profit_ctr_id and d.manifest = wot2.manifest and wot2.transporter_sequence_id = 2
LEFT OUTER JOIN DisposalService ds  (nolock) ON t.disposal_service_id = ds.disposal_service_id
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
	and wos.company_id = w.company_id
	and wos.profit_ctr_id = w.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
WHERE 1=1
AND (w.customer_id IN (select customer_id from #Customer)
    OR w.generator_id IN (SELECT generator_id FROM customergenerator  (nolock) WHERE customer_id IN (select customer_id from #Customer))
    OR w.generator_id IN (
        SELECT generator_id FROM generator (nolock) where site_type IN (
            SELECT site_type from #SiteTypeToInclude
        )
    )
)
AND w.start_date BETWEEN @start_date AND @end_date
AND ISNULL(t2.eq_flag, 'F') = 'F'
AND d.resource_type = 'D'
AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
AND d.bill_rate NOT IN (-2)

print '3rd party Disposal WOs Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()



--  PRINT 'Receipt/Transporter Fix'
/*

12/7/2010 - The primary source for EQ data is the Receipt table.
	It's out of order in the select logic below and needs to be reviewed/revised
	because it's misleading.
	
This query has 2 union'd components:
first component: workorder inner join to billinglinklookup and receipt
second component: receipt not linked to either BLL or WMRWT
*/
    INSERT  EQ_Temp..WalmartDisposalReceiptTransporter
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

	-- Specific to finance version:
	INNER JOIN #BillingProject bp ON wo.customer_id = bp.customer_id and wo.billing_project_id = bp.billing_project_id

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
            or wo.customer_id IN (select customer_id from #Customer)
            or wo.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from #Customer))
            OR wo.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
            or r.customer_id IN (select customer_id from #Customer)
            or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from #Customer))
            OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
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
        rt2.transporter_code as transporter2,
        @usr,
        @extract_datetime
    from receipt r (nolock) 
    inner join generator g  (nolock) on r.generator_id = g.generator_id

	-- Specific to finance version:
	INNER JOIN #BillingProject bp ON r.customer_id = bp.customer_id and r.billing_project_id = bp.billing_project_id

    left outer join receipttransporter rt1  (nolock) on rt1.receipt_id = r.receipt_id
        and rt1.profit_ctr_id = r.profit_ctr_id
        and rt1.company_id = r.company_id
        and rt1.transporter_sequence_id = 1
    left outer join receipttransporter rt2  (nolock) on rt2.receipt_id = r.receipt_id
        and rt2.profit_ctr_id = r.profit_ctr_id
        and rt2.company_id = r.company_id
        and rt2.transporter_sequence_id = 2
    where
        coalesce(rt1.transporter_sign_date, r.receipt_date) between @start_date AND @end_date
        and (r.customer_id IN (select customer_id from #Customer)
            or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from #Customer))
            OR r.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
        )
        and not exists (
            select receipt_id from billinglinklookup bll (nolock) 
            where bll.company_id = r.company_id
            and bll.profit_ctr_id = r.profit_ctr_id
            and bll.receipt_id = r.receipt_id
        )


print 'Receipt/Transporter Population Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Fix #ReceiptTransporter records...
    --  PRINT 'Can''t allow null transporter1 and populated transporter2, so move the data to transporter1 field.'
        UPDATE EQ_Temp..WalmartDisposalReceiptTransporter set transporter1 = transporter2
        WHERE ISNULL(transporter1, '') = '' and ISNULL(transporter2, '') <> ''
        AND added_by = @usr and date_added = @extract_datetime

    --  PRINT 'Can''t have the same transporter for both fields.'
        UPDATE EQ_Temp..WalmartDisposalReceiptTransporter set transporter2 = null
        WHERE transporter2 = transporter1
        AND added_by = @usr and date_added = @extract_datetime

print 'Receipt/Transporter Transporter Updates Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Receipts
INSERT EQ_TEMP.dbo.WalmartDisposalExtract
SELECT distinct
    -- Walmart Fields:
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
	NULL as pounds, -- pull in NULL for now, we'll update it from Receipt.Net_weight later - 12/20/2010
    b.bill_unit_desc AS bill_unit_desc,
    ISNULL(max(rp.bill_quantity), 0) AS quantity,
    p.Approval_desc AS waste_desc,
    COALESCE(replace(r.approval_code, 'WM' + right('0000' + g.site_code, 4), 'WM'), r.service_desc) AS approval_or_resource,
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
    replace(
    dbo.fn_wm_disposal_method(
        ds.disposal_service_desc,
        pqa.disposal_service_other_desc,
        pqa.ob_tsdf_approval_id,
        pqa.ob_eq_profile_id,
        pqa.ob_eq_company_id,
        pqa.ob_eq_profit_ctr_id)
       , 'Incineration/Witness', 'Incineration') as disposal_service_desc,

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
    null, -- dbo.fn_receipt_waste_code_list(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id) AS waste_codes,
	null, --     dbo.fn_receipt_waste_code_list_state(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id) AS state_waste_codes,
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

    r.submitted_flag,
    @usr as added_by,
    @extract_datetime as date_added
    
FROM Receipt r (nolock) 
INNER JOIN ReceiptPrice rp  (nolock) ON
    R.receipt_id = rp.receipt_id
    and r.line_id = rp.line_id
    and r.company_id = rp.company_id
    and r.profit_ctr_id = rp.profit_ctr_id
INNER JOIN Generator g  (nolock) ON r.generator_id = g.generator_id
INNER JOIN BillUnit b  (nolock) ON rp.bill_unit_code = b.bill_unit_code
INNER JOIN EQ_Temp..WalmartDisposalReceiptTransporter wrt ON
    r.company_id = wrt.company_id
    and r.profit_ctr_id = wrt.profit_ctr_id
    and r.receipt_id = wrt.receipt_id
    and r.line_id = wrt.line_id
	AND wrt.added_by = @usr
	AND wrt.date_added = @extract_datetime
INNER JOIN ProfitCenter pr (nolock) on r.company_id = pr.company_id and r.profit_ctr_id = pr.profit_ctr_id

-- Specific to finance version:
INNER JOIN #BillingProject bp ON r.customer_id = bp.customer_id and r.billing_project_id = bp.billing_project_id

LEFT OUTER JOIN Profile p  (nolock) ON r.profile_id = p.profile_id
LEFT OUTER JOIN Treatment tr  (nolock) ON r.treatment_id = tr.treatment_id
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
LEFT OUTER JOIN ProfileQuoteApproval pqa  (nolock)
    on r.profile_id = pqa.profile_id 
    and r.company_id = pqa.company_id 
    and r.profit_ctr_id = pqa.profit_ctr_id 
    -- and pqa.status = 'A'
LEFT OUTER JOIN DisposalService ds  (nolock)
    on pqa.disposal_service_id = ds.disposal_service_id
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
    r.line_weight, -- was r.net_weight, 2/25/2011,
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
    p.hazmat,
    r.submitted_flag

print 'Receipts Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


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

	-- Specific to finance version:
	INNER JOIN #BillingProject bp ON w.customer_id = bp.customer_id and w.billing_project_id = bp.billing_project_id

    LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
    LEFT OUTER JOIN WorkOrderStop wos (nolock) ON w.workorder_id = wos.workorder_id and w.company_id = wos.company_id and w.profit_ctr_id = wos.profit_ctr_id 
    	and wos.stop_sequence_id = 1
	WHERE 1=1
	AND (w.customer_id IN (select customer_id from #Customer)
	    OR w.generator_id IN (SELECT generator_id FROM customergenerator  (nolock) WHERE customer_id IN (select customer_id from #Customer))
	    OR w.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
	)
	AND w.start_date BETWEEN @start_date AND @end_date
	AND w.submitted_flag = 'T'
	AND w.workorder_status IN ('A','C','D','N','P','X')
	AND d.bill_rate NOT IN (-2)
	AND d.resource_class_code = 'STOPFEE'
	AND wos.decline_id > 1
	AND (
--	    (isnull(w.billing_project_id, 0) = 24 and w.customer_id = 10673)
       (isnull(w.billing_project_id, 0) IN (select billing_project_id from #BillingProject) and w.customer_id IN (select customer_id from #BillingProject))
	    OR
	    (wos.waste_flag = 'F')
	)    

print 'No Waste Pickup records finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Finance Version -- The Missing Link: WO lines that aren't disposal.
-- No-Waste Pickup Records:
INSERT EQ_TEMP.dbo.WalmartDisposalExtract
	SELECT DISTINCT
	-- Walmart Fields:
	g.site_code AS site_code,
	gst.generator_site_type_abbr AS site_type_abbr,
	g.generator_city AS generator_city,
	g.generator_state AS generator_state,
   	coalesce(wos.date_act_arrive, w.start_date) as service_date,
	g.epa_id AS epa_id,
	null AS manifest,
	1 AS manifest_line,
	0 AS pounds,
	null AS bill_unit_desc,
	0 AS quantity,
	'Non-Disposal Charge' AS waste_desc,
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
	d.sequence_id,
	g.generator_id,
	g.generator_name AS generator_name,
	g.site_type AS site_type,
	null AS manifest_page,
	d.resource_type AS item_type,
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

	-- Specific to finance version:
	INNER JOIN #BillingProject bp ON w.customer_id = bp.customer_id and w.billing_project_id = bp.billing_project_id

    LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
    LEFT OUTER JOIN WorkOrderStop wos (nolock) ON w.workorder_id = wos.workorder_id and w.company_id = wos.company_id and w.profit_ctr_id = wos.profit_ctr_id 
    	and wos.stop_sequence_id = 1
	WHERE 1=1
	AND (w.customer_id IN (select customer_id from #Customer)
	    OR w.generator_id IN (SELECT generator_id FROM customergenerator  (nolock) WHERE customer_id IN (select customer_id from #Customer))
	    OR w.generator_id IN (SELECT generator_id FROM generator  (nolock) where site_type IN (SELECT site_type from #SiteTypeToInclude))
	)
   	AND coalesce(wos.date_act_arrive, w.start_date) BETWEEN @start_date AND @end_date
	AND w.submitted_flag = 'T'
	AND w.workorder_status IN ('A','C','D','N','P','X')
	AND d.bill_rate > 0
	AND d.resource_type <> 'D' -- Key to finding missing Finance version info
	-- AND d.resource_class_code = 'STOPFEE'
	AND not EXISTS (
		SELECT 1 FROM EQ_TEMP.dbo.WalmartDisposalExtract
		WHERE company_id = 	w.company_id
		AND profit_ctr_id = w.profit_ctr_id
		AND receipt_id = d.workorder_id
		and item_type = d.resource_type
		and sequence_id = d.sequence_id
		and added_by =	@usr
	   and date_added = @extract_datetime
	)


print 'WO non-disposal records finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()




/*
-- Finance version doesn't care about waste codes

-- Create a table for waste codes
	create table #WM_Waste_Codes (
		source	varchar(20),
		tsdf_approval_id	int,
		receipt_id			int,
		line_id				int,
		company_id			int,
		profit_ctr_id		int,
		sequence_id			int,
		origin				char(1),
		waste_code			varchar(10)
	)
	create index idx_1 on #WM_Waste_Codes (source, tsdf_approval_id, origin, sequence_id, waste_code)
	create index idx_2 on #WM_Waste_Codes (source, receipt_id, line_id, company_id, profit_ctr_id, origin, sequence_id, waste_code)

-- Workorder Waste Codes (1)
	insert #WM_Waste_Codes (source, tsdf_approval_id, sequence_id, origin, waste_code)
	select distinct
		e.source_table,
		xwc.tsdf_approval_id,
		1 as sequence_id,
		wc.waste_code_origin,
		xwc.waste_code
	FROM TSDFApprovalWasteCode xwc (nolock)
		INNER JOIN WasteCode wc (nolock) ON xwc.waste_code = wc.waste_code
		INNER JOIN EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
			on e.tsdf_approval_id = xwc.tsdf_approval_id
	WHERE e.source_table = 'Workorder'
		and e.submitted_flag = 'T'
		AND xwc.primary_flag = 'T'
		AND wc.waste_code_origin in ('F', 'S')
		AND e.added_by = @usr
		AND e.date_added = @extract_datetime


print 'Workorder Waste Codes (1), Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Workorder Waste Codes (2+)
	insert #WM_Waste_Codes (source, tsdf_approval_id, sequence_id, origin, waste_code)
	select distinct
		e.source_table,
		xwc.tsdf_approval_id,
		2, --1 + row_number() over (order by xwc.waste_code) as sequence_id,
		wc.waste_code_origin,
		xwc.waste_code
	FROM TSDFApprovalWasteCode xwc (nolock)
		INNER JOIN WasteCode wc (nolock) ON xwc.waste_code = wc.waste_code
		INNER JOIN EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
			on e.tsdf_approval_id = xwc.tsdf_approval_id
	WHERE e.source_table = 'Workorder'
		and e.submitted_flag = 'T'
		AND wc.waste_code_origin in ('F', 'S')
		and xwc.waste_code not in (select waste_code from #WM_Waste_Codes
			where source = e.source_table 
			and tsdf_approval_id = xwc.tsdf_approval_id 
			)
		AND e.added_by = @usr
		AND e.date_added = @extract_datetime
	ORDER BY xwc.waste_code

print 'Workorder Waste Codes (2+), Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Receipt Waste Codes (1)
	insert #WM_Waste_codes (source, receipt_id, line_id, company_id, profit_ctr_id, sequence_id, origin, waste_code)
	select distinct
		e.source_table,
		xwc.receipt_id,
		xwc.line_id,
		xwc.company_id,
		xwc.profit_ctr_id,
		1 as sequence_id,
		wc.waste_code_origin,
		xwc.waste_code
	FROM ReceiptWasteCode xwc (nolock)
	INNER JOIN wastecode wc (nolock) on xwc.waste_code = wc.waste_code
	INNER JOIN EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
		on e.receipt_id = xwc.receipt_id
		and e.line_sequence_id = xwc.line_id
		and e.company_id = xwc.company_id
		and e.profit_ctr_id = xwc.profit_ctr_id
	WHERE e.source_table = 'Receipt'
		and e.submitted_flag = 'T'
		AND xwc.primary_flag = 'T'
		AND wc.waste_code_origin in ('F', 'S')
		AND e.added_by = @usr
		AND e.date_added = @extract_datetime

print 'Receipt Waste Codes (1), Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Receipt Waste Codes (2+)
	insert #WM_Waste_codes (source, receipt_id, line_id, company_id, profit_ctr_id, sequence_id, origin, waste_code)
	select distinct
		e.source_table,
		xwc.receipt_id,
		xwc.line_id,
		xwc.company_id,
		xwc.profit_ctr_id,
		2 as sequence_id,
		wc.waste_code_origin,
		xwc.waste_code
	FROM ReceiptWasteCode xwc (nolock)
	INNER JOIN wastecode wc (nolock) on xwc.waste_code = wc.waste_code
	INNER JOIN EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
		on e.receipt_id = xwc.receipt_id
		and e.line_sequence_id = xwc.line_id
		and e.company_id = xwc.company_id
		and e.profit_ctr_id = xwc.profit_ctr_id
	WHERE e.source_table = 'Receipt'
		and e.submitted_flag = 'T'
		AND wc.waste_code_origin in ('F', 'S')
		and xwc.waste_code not in (select waste_code from #WM_Waste_Codes
			where source = e.source_table 
			and receipt_id = xwc.receipt_id
			and line_id = xwc.line_id
			and company_id = xwc.company_id
			and profit_ctr_id = xwc.profit_ctr_id
			)
		AND e.added_by = @usr
		AND e.date_added = @extract_datetime
	ORDER BY xwc.waste_code

print 'Workorder Waste Codes (1), Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Don't include UNIV
delete from #WM_Waste_Codes where waste_code = 'UNIV'

-- Don't include NONE
delete from #WM_Waste_Codes where waste_code = 'NONE'

-- Don't include .
delete from #WM_Waste_Codes where waste_code = '.'

print 'Waste Code Cleanup, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Number the sequence 2+ rows
declare @incrementer int = 2
update #WM_Waste_Codes 
set @incrementer = sequence_id = @incrementer + 1
where sequence_id > 1

print 'Waste Codes (2+) Numbering, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Fix gaps: Workorder
UPDATE #WM_Waste_Codes
  SET sequence_id
      = (SELECT COUNT(sequence_id)
           FROM #WM_Waste_Codes AS G1
          WHERE G1.sequence_id < #WM_Waste_Codes.sequence_id
          and G1.source = 'Workorder'
          and G1.tsdf_approval_id = #WM_Waste_Codes.tsdf_approval_id
          and G1.origin = #WM_Waste_codes.origin
          ) + 1
WHERE source = 'Workorder'

print 'Waste Code (Workorder) Gap Fix, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

         
-- Fix gaps: Receipt
UPDATE #WM_Waste_Codes
  SET sequence_id
      = (SELECT COUNT(sequence_id)
           FROM #WM_Waste_Codes AS G1
          WHERE G1.sequence_id < #WM_Waste_Codes.sequence_id
          and G1.source = 'Receipt'
          and G1.receipt_id = #WM_Waste_Codes.receipt_id
          and G1.line_id = #WM_Waste_Codes.line_id
          and G1.company_id = #WM_Waste_Codes.company_id
          and G1.profit_ctr_id = #WM_Waste_Codes.profit_ctr_id
          and G1.origin = #WM_Waste_Codes.origin
          ) + 1
WHERE source = 'Receipt'

print 'Waste Codes (Receipt) Gap Fix, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Update Waste Codes for WOs		
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract set
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
	EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
	left outer join #WM_Waste_codes ft1 on  ft1.source = e.source_table and ft1.tsdf_approval_id = e.tsdf_approval_id and ft1.origin = 'F' and ft1.sequence_id = 1
	left outer join #WM_Waste_codes ft2 on  ft2.source = e.source_table and ft2.tsdf_approval_id = e.tsdf_approval_id and ft2.origin = 'F' and ft2.sequence_id = 2		
	left outer join #WM_Waste_codes ft3 on  ft3.source = e.source_table and ft3.tsdf_approval_id = e.tsdf_approval_id and ft3.origin = 'F' and ft3.sequence_id = 3		
	left outer join #WM_Waste_codes ft4 on  ft4.source = e.source_table and ft4.tsdf_approval_id = e.tsdf_approval_id and ft4.origin = 'F' and ft4.sequence_id = 4		
	left outer join #WM_Waste_codes ft5 on  ft5.source = e.source_table and ft5.tsdf_approval_id = e.tsdf_approval_id and ft5.origin = 'F' and ft5.sequence_id = 5		
	left outer join #WM_Waste_codes ft6 on  ft6.source = e.source_table and ft6.tsdf_approval_id = e.tsdf_approval_id and ft6.origin = 'F' and ft6.sequence_id = 6		
	left outer join #WM_Waste_codes ft7 on  ft7.source = e.source_table and ft7.tsdf_approval_id = e.tsdf_approval_id and ft7.origin = 'F' and ft7.sequence_id = 7		
	left outer join #WM_Waste_codes ft8 on  ft8.source = e.source_table and ft8.tsdf_approval_id = e.tsdf_approval_id and ft8.origin = 'F' and ft8.sequence_id = 8
	left outer join #WM_Waste_codes ft9 on  ft9.source = e.source_table and ft9.tsdf_approval_id = e.tsdf_approval_id and ft9.origin = 'F' and ft9.sequence_id = 9
	left outer join #WM_Waste_codes ft10 on ft10.source = e.source_table and ft10.tsdf_approval_id = e.tsdf_approval_id and ft10.origin = 'F' and ft10.sequence_id = 10
	left outer join #WM_Waste_codes ft11 on ft11.source = e.source_table and ft11.tsdf_approval_id = e.tsdf_approval_id and ft11.origin = 'F' and ft11.sequence_id = 11
	left outer join #WM_Waste_codes ft12 on ft12.source = e.source_table and ft12.tsdf_approval_id = e.tsdf_approval_id and ft12.origin = 'F' and ft12.sequence_id = 12
	left outer join #WM_Waste_codes st1 on st1.source = e.source_table and st1.tsdf_approval_id = e.tsdf_approval_id and st1.origin = 'S' and st1.sequence_id = 1
	left outer join #WM_Waste_codes st2 on st2.source = e.source_table and st2.tsdf_approval_id = e.tsdf_approval_id and st2.origin = 'S' and st2.sequence_id = 2
	left outer join #WM_Waste_codes st3 on st3.source = e.source_table and st3.tsdf_approval_id = e.tsdf_approval_id and st3.origin = 'S' and st3.sequence_id = 3
	left outer join #WM_Waste_codes st4 on st4.source = e.source_table and st4.tsdf_approval_id = e.tsdf_approval_id and st4.origin = 'S' and st4.sequence_id = 4
	left outer join #WM_Waste_codes st5 on st5.source = e.source_table and st5.tsdf_approval_id = e.tsdf_approval_id and st5.origin = 'S' and st5.sequence_id = 5
WHERE e.source_table = 'Workorder'
and e.added_by = @usr AND e.date_added = @extract_datetime and e.submitted_flag = 'T'

print 'Update fields left null (WO waste codes), Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Update Waste Codes for Receipts
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract set
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
	EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
	left outer join #WM_Waste_Codes fr1 on fr1.source = e.source_table and fr1.receipt_id = e.receipt_id and fr1.line_id = e.line_sequence_id and fr1.company_id = e.company_id and fr1.profit_ctr_id = e.profit_ctr_id and fr1.origin = 'F' and fr1.sequence_id = 1
	left outer join #WM_Waste_Codes fr2 on fr2.source = e.source_table and fr2.receipt_id = e.receipt_id and fr2.line_id = e.line_sequence_id and fr2.company_id = e.company_id and fr2.profit_ctr_id = e.profit_ctr_id and fr2.origin = 'F' and fr2.sequence_id = 2
	left outer join #WM_Waste_Codes fr3 on fr3.source = e.source_table and fr3.receipt_id = e.receipt_id and fr3.line_id = e.line_sequence_id and fr3.company_id = e.company_id and fr3.profit_ctr_id = e.profit_ctr_id and fr3.origin = 'F' and fr3.sequence_id = 3
	left outer join #WM_Waste_Codes fr4 on fr4.source = e.source_table and fr4.receipt_id = e.receipt_id and fr4.line_id = e.line_sequence_id and fr4.company_id = e.company_id and fr4.profit_ctr_id = e.profit_ctr_id and fr4.origin = 'F' and fr4.sequence_id = 4
	left outer join #WM_Waste_Codes fr5 on fr5.source = e.source_table and fr5.receipt_id = e.receipt_id and fr5.line_id = e.line_sequence_id and fr5.company_id = e.company_id and fr5.profit_ctr_id = e.profit_ctr_id and fr5.origin = 'F' and fr5.sequence_id = 5
	left outer join #WM_Waste_Codes fr6 on fr6.source = e.source_table and fr6.receipt_id = e.receipt_id and fr6.line_id = e.line_sequence_id and fr6.company_id = e.company_id and fr6.profit_ctr_id = e.profit_ctr_id and fr6.origin = 'F' and fr6.sequence_id = 6
	left outer join #WM_Waste_Codes fr7 on fr7.source = e.source_table and fr7.receipt_id = e.receipt_id and fr7.line_id = e.line_sequence_id and fr7.company_id = e.company_id and fr7.profit_ctr_id = e.profit_ctr_id and fr7.origin = 'F' and fr7.sequence_id = 7
	left outer join #WM_Waste_Codes fr8 on fr8.source = e.source_table and fr8.receipt_id = e.receipt_id and fr8.line_id = e.line_sequence_id and fr8.company_id = e.company_id and fr8.profit_ctr_id = e.profit_ctr_id and fr8.origin = 'F' and fr8.sequence_id = 8
	left outer join #WM_Waste_Codes fr9 on fr9.source = e.source_table and fr9.receipt_id = e.receipt_id and fr9.line_id = e.line_sequence_id and fr9.company_id = e.company_id and fr9.profit_ctr_id = e.profit_ctr_id and fr9.origin = 'F' and fr9.sequence_id = 9
	left outer join #WM_Waste_Codes fr10 on fr10.source = e.source_table and fr10.receipt_id = e.receipt_id and fr10.line_id = e.line_sequence_id and fr10.company_id = e.company_id and fr10.profit_ctr_id = e.profit_ctr_id and fr10.origin = 'F' and fr10.sequence_id = 10
	left outer join #WM_Waste_Codes fr11 on fr11.source = e.source_table and fr11.receipt_id = e.receipt_id and fr11.line_id = e.line_sequence_id and fr11.company_id = e.company_id and fr11.profit_ctr_id = e.profit_ctr_id and fr11.origin = 'F' and fr11.sequence_id = 11 
	left outer join #WM_Waste_Codes fr12 on fr12.source = e.source_table and fr12.receipt_id = e.receipt_id and fr12.line_id = e.line_sequence_id and fr12.company_id = e.company_id and fr12.profit_ctr_id = e.profit_ctr_id and fr12.origin = 'F' and fr12.sequence_id = 12
	left outer join #WM_Waste_Codes sr1 on sr1.source = e.source_table and sr1.receipt_id = e.receipt_id  and sr1.line_id = e.line_sequence_id and sr1.company_id = e.company_id and sr1.profit_ctr_id = e.profit_ctr_id and sr1.origin = 'S' and sr1.sequence_id = 1 
	left outer join #WM_Waste_Codes sr2 on sr2.source = e.source_table and sr2.receipt_id = e.receipt_id and sr2.line_id = e.line_sequence_id and sr2.company_id = e.company_id and sr2.profit_ctr_id = e.profit_ctr_id and sr2.origin = 'S' and sr2.sequence_id = 2
	left outer join #WM_Waste_Codes sr3 on sr3.source = e.source_table and sr3.receipt_id = e.receipt_id and sr3.line_id = e.line_sequence_id and sr3.company_id = e.company_id and sr3.profit_ctr_id = e.profit_ctr_id and sr3.origin = 'S' and sr3.sequence_id = 3
	left outer join #WM_Waste_Codes sr4 on sr4.source = e.source_table and sr4.receipt_id = e.receipt_id and sr4.line_id = e.line_sequence_id and sr4.company_id = e.company_id and sr4.profit_ctr_id = e.profit_ctr_id and sr4.origin = 'S' and sr4.sequence_id = 4
	left outer join #WM_Waste_Codes sr5 on sr5.source = e.source_table and sr5.receipt_id = e.receipt_id and sr5.line_id = e.line_sequence_id and sr5.company_id = e.company_id and sr5.profit_ctr_id = e.profit_ctr_id and sr5.origin = 'S' and sr5.sequence_id = 5
WHERE e.source_table = 'Receipt' and e.added_by = @usr AND e.date_added = @extract_datetime and e.submitted_flag = 'T'

print 'Update fields left null (R waste codes), Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Texas waste codes are 8 digits, and wouldn't fit into the wastecode table's waste_code field.
-- BUT, the waste_code field on those records is unique, so EQ systems handle it correctly, but we
-- need to remember to update the extract to swap the waste_description (the TX 8 digit code) for
-- the waste_code for waste_codes that are from TX.

UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_1 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_1 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_2 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_2 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_3 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_3 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_4 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_4 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET state_waste_code_5 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_5 = wc.waste_code AND EQ_TEMP.dbo.WalmartDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.WalmartDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.WalmartDisposalExtract.submitted_flag = 'T'

print 'Texas Waste Code Updates, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

*/

/*
-- Finance version doesn't care about dot description or transporters

-- Update fields left null in #Extract
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract set
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
	EQ_TEMP.dbo.WalmartDisposalExtract e
	left outer join Transporter t1
		on e.transporter1_code = t1.transporter_code
	left outer join Transporter t2
		on e.transporter2_code = t2.transporter_code
WHERE e.added_by = @usr AND e.date_added = @extract_datetime and e.submitted_flag = 'T'

print 'Update fields left null (dot, trans), Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()
*/


/*
12/20/2010 - Weight mismatch handling (notice I don't call it "fix")
	12/20/2010 - JPB
		1. Complaint received that Disposal != Generation log weights (and != receipt.net_weight).
			This is because receipt net_weight is divided across the number of lines on the extract
			and means a DM05 and DM55 are shown as each 1/2 of the total.  Silly, but WM.
			Fix: After the extract is completely populated, go back over it for each mismatch
			between sum(disposal extract weights) != receipt.net_weight and set the FIRST record
			for each set in the extract +/- whatever required to make the sum of them match the
			receipt.net_weight.
			
			
1. Set the timestamp on the EQ_TEMP records back by 3.  Then select insert them into EQ_Temp again, at the right timestamp?
	-- 40 chars avail, longest ever is 18, should be fine.
			
*/
UPDATE EQ_TEMP.dbo.WalmartDisposalExtract SET date_added = dateadd(s, -3, @extract_datetime) where date_added = @extract_datetime AND source_table = 'Receipt'

print 'Move current run back 3 seconds, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

INSERT EQ_TEMP.dbo.WalmartDisposalExtract
SELECT
	e.site_code,
	e.site_type_abbr,
	e.generator_city,
	e.generator_state,
	e.service_date,
	e.epa_id,
	e.manifest,
	e.manifest_line,
    convert(int, round((case when isnull(R.line_weight, 0) between 0.0001 and 1 then 1 else isnull(R.line_weight, 0) end), 0)) as pounds,
	dbo.fn_wm_extract_line_convert_eq_temp(e.manifest, e.manifest_line, @usr, dateadd(s, -3, @extract_datetime)) as bill_unit_desc,
    SUM(ISNULL(e.quantity, 0)) as quantity,
	e.waste_desc,
	e.approval_or_resource,
	e.dot_description,
	e.waste_code_1,
	e.waste_code_2,
	e.waste_code_3,
	e.waste_code_4,
	e.waste_code_5,
	e.waste_code_6,
	e.waste_code_7,
	e.waste_code_8,
	e.waste_code_9,
	e.waste_code_10,
	e.waste_code_11,
	e.waste_code_12,
	e.state_waste_code_1,
	e.state_waste_code_2,
	e.state_waste_code_3,
	e.state_waste_code_4,
	e.state_waste_code_5,
	e.management_code,
	e.EPA_source_code,
	e.EPA_form_code,
	e.transporter1_name,
	e.transporter1_epa_id,
	e.transporter2_name,
	e.transporter2_epa_id,
	e.receiving_facility,
	e.receiving_facility_epa_id,
	e.receipt_id,
	e.disposal_service_desc,
	e.company_id,
	e.profit_ctr_id,
	e.line_sequence_id,
	e.generator_id,
	e.generator_name,
	e.site_type,
	e.manifest_page,
	e.item_type,
	e.tsdf_approval_id,
	e.profile_id,
	e.container_count,
	e.waste_codes,
	e.state_waste_codes,
	e.transporter1_code,
	e.transporter2_code,
	e.date_delivered,
	e.source_table,
	e.receipt_date,
	e.receipt_workorder_id,
	e.workorder_start_date,
	e.workorder_company_id,
	e.workorder_profit_ctr_id,
	e.customer_id,
	e.haz_flag,
	e.submitted_flag,
	@usr as added_by,
	@extract_datetime as date_added
FROM EQ_TEMP.dbo.WalmartDisposalExtract e (nolock)
INNER JOIN Receipt r (nolock)
	ON e.receipt_id = r.receipt_id
	and e.line_sequence_id = r.line_id
	AND e.company_id = r.company_id
	and e.profit_ctr_id = r.profit_ctr_id
WHERE e.date_added = dateadd(s, -3, @extract_datetime)
GROUP BY	
	e.site_code,
	e.site_type_abbr,
	e.generator_city,
	e.generator_state,
	e.service_date,
	e.epa_id,
	e.manifest,
	e.manifest_line,
	r.line_weight,
	e.waste_desc,
	e.approval_or_resource,
	e.dot_description,
	e.waste_code_1,
	e.waste_code_2,
	e.waste_code_3,
	e.waste_code_4,
	e.waste_code_5,
	e.waste_code_6,
	e.waste_code_7,
	e.waste_code_8,
	e.waste_code_9,
	e.waste_code_10,
	e.waste_code_11,
	e.waste_code_12,
	e.state_waste_code_1,
	e.state_waste_code_2,
	e.state_waste_code_3,
	e.state_waste_code_4,
	e.state_waste_code_5,
	e.management_code,
	e.EPA_source_code,
	e.EPA_form_code,
	e.transporter1_name,
	e.transporter1_epa_id,
	e.transporter2_name,
	e.transporter2_epa_id,
	e.receiving_facility,
	e.receiving_facility_epa_id,
	e.receipt_id,
	e.disposal_service_desc,
	e.company_id,
	e.profit_ctr_id,
	e.line_sequence_id,
	e.generator_id,
	e.generator_name,
	e.site_type,
	e.manifest_page,
	e.item_type,
	e.tsdf_approval_id,
	e.profile_id,
	e.container_count,
	e.waste_codes,
	e.state_waste_codes,
	e.transporter1_code,
	e.transporter2_code,
	e.date_delivered,
	e.source_table,
	e.receipt_date,
	e.receipt_workorder_id,
	e.workorder_start_date,
	e.workorder_company_id,
	e.workorder_profit_ctr_id,
	e.customer_id,
	e.haz_flag,
	e.submitted_flag


-- EQ_TEMP.dbo.WalmartDisposalExtract is finished now.

print 'Copy current run to new instance summing quantity, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

/*

-- Finance version REALLY doesn't care about images

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

print 'Create List of Images, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Update the 'newname' column for calculating name changes.
UPDATE EQ_TEMP..WalmartExtractImages SET newname = filename
WHERE added_by = @usr 
AND date_added = @extract_datetime


-- remove duplicate flag from images that aren't duplicates (only 1 mention of the generator)
-- (duplicates are images from a 2 sites with the same site code, where one is active, one is inactive, on the same day)
-- Why the following query is correct:
--    Newname includes the facility # and date of service.  count of distinct generators will tell you how many have the same site # & date.
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

print 'Setting Image FileNames, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

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

print 'Clearing Image Filename Duplicate Flags, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

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

print 'Adding sequence ids to duplicate filenames, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

*/

 -- Trip Export Information (where the data actually comes from workorder info that exists for disposal manifest info)
INSERT EQ_Extract..WMDisposalGeneration
  SELECT distinct
      f.site_code, 
      f.generator_city, 
      f.generator_state,
      f.service_date as shipment_date,
      case when wodi.month is null or wodi.year is null then
		convert(datetime, 
			convert(varchar(2), datepart(m, f.service_date)) + '/01/' + convert(varchar(4), datepart(yyyy, f.service_date))
		)
		else
			convert(datetime, convert(varchar(2), wodi.month) + '/01/' + CONVERT(varchar(4), wodi.year)) 
	  end as generation_date,
      f.epa_id,
      CASE WHEN 
				convert(numeric(5,1),
					round(sum(
							(
								(isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0)
							) 
							* isnull(wodi.merchandise_quantity,1)
						),1)
				) BETWEEN 0.0001 AND 1.0 THEN 
		1.0
	  ELSE
			round(
				convert(numeric(5,1),
					round(sum(
							(
								(isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0)
							) 
							* isnull(wodi.merchandise_quantity,1)
						),1)
				) 	  
			, 1)
	  END as Weight,
      f.approval_or_resource,
      f.manifest,
      f.manifest_line,
      f.company_id,
      f.profit_ctr_id,
      f.receipt_id,
      f.item_type,
      f.line_sequence_id,
      NULL, 
      'F' as calculated_flag,
      
      /*
      
      -- Finance version *shouldnt* care about exclusions? Since it was to include DCs etc.
      
	  exclude_flag = 
		  CASE WHEN (1=0
		  	-- exclude any generator that has a site type of Optical Lab, DC, Return Center, PMDC 
		  	OR f.site_type LIKE '%Optical Lab%'
		  	OR f.site_type LIKE '%DC%'
		  	OR f.site_type LIKE '%Return Center%'
		  	OR f.site_type LIKE '%PMDC%'
		  ) THEN 
			  'T'
		  ELSE
		  	-- exclude any non-hazardous or universal waste approvals: 
			-- 	approval numbers WMNHW01-WMNHW16, WMUW01-WMUW03 
			-- 	approvals that do not contain a RCRA hazardous waste code (D, F, K, P, U)
			  CASE WHEN (1=0
			  	OR f.approval_or_resource IN ('WMNHW01','WMNHW02','WMNHW03','WMNHW04','WMNHW05','WMNHW06','WMNHW07','WMNHW08','WMNHW09','WMNHW10','WMNHW11','WMNHW12','WMNHW13','WMNHW14','WMNHW15','WMNHW16')
				OR f.approval_or_resource IN ('WMUW01', 'WMUW02', 'WMUW03')
			  ) THEN
			  	'T'
			  ELSE
			  	CASE WHEN NOT EXISTS (
			  		SELECT tawc.waste_code
			  		FROM TSDFApprovalWasteCode tawc  (nolock)
			  		INNER JOIN WasteCode wc (nolock) on tawc.waste_code = wc.waste_code
			  		WHERE tawc.tsdf_approval_id = f.tsdf_approval_id
			  		AND tawc.company_id = f.company_id
			  		AND tawc.profit_ctr_id = f.profit_ctr_id
			  		AND f.tsdf_approval_id is not null
			  		AND wc.waste_code_origin = 'F'
			  		AND left(wc.waste_code, 1) in ('D', 'F', 'P', 'K', 'U')
			  		AND wc.haz_flag = 'T'
			  	) THEN
			  		'T'
			  	ELSE
			  		'F'
			  	END
			  END
			END,
*/
      exclude_flag = 'F',
      
	  @usr as added_by,
	  @extract_datetime as date_added
      , CASE WHEN CHARINDEX(',P', ',' + waste_code_1 + ',' +waste_code_2 + ',' +waste_code_3 + ',' +waste_code_4 + ',' +waste_code_5 + ',' +waste_code_6 + ',' +waste_code_7 + ',' +waste_code_8 + ',' +waste_code_9 + ',' +waste_code_10 + ',' +waste_code_11 + ',' +waste_code_12) <= 0 THEN
				''
			ELSE
			'P'
		END AS plisted
  from EQ_TEMP.dbo.WalmartDisposalExtract f (nolock)
  -- new on 12/14:
  inner join tsdfapproval tsdfa (nolock) on f.tsdf_approval_id = tsdfa.tsdf_approval_id
  inner join tsdf (nolock) on tsdfa.tsdf_code = tsdf.tsdf_code and tsdf.eq_flag = 'F'
  inner join workorderheader woh (nolock) on f.receipt_id = woh.workorder_id
      and f.company_id = woh.company_id
      and f.profit_ctr_id = woh.profit_ctr_id
      and woh.trip_id is not null
  left outer join workorderdetailitem wodi (nolock)
      on f.receipt_id = wodi.workorder_id
      and f.line_sequence_id = wodi.sequence_id
      and f.company_id = wodi.company_id
      and f.profit_ctr_id = wodi.profit_ctr_id
      -- 12/17/2010 - Trying to remove extra data...
      AND wodi.added_by <> 'sa-extract'
  WHERE 1=1
  and f.added_by = @usr
  and f.date_added = @extract_datetime
  AND f.submitted_flag = 'T'
GROUP BY
      f.site_code, 
      f.generator_city, 
      f.generator_state,
      f.service_date,
      wodi.month,
      wodi.year,
      f.epa_id,
      f.approval_or_resource,
      f.manifest,
      f.manifest_line,
      f.company_id,
      f.profit_ctr_id,
      f.receipt_id,
      f.item_type,
      f.line_sequence_id,
	  f.site_type,
	  f.tsdf_approval_id,
	  f.added_by,
      f.date_added,
	  f.submitted_flag
	  , ',' + waste_code_1 + ',' +waste_code_2 + ',' +waste_code_3 + ',' +waste_code_4 + ',' +waste_code_5 + ',' +waste_code_6 + ',' +waste_code_7 + ',' +waste_code_8 + ',' +waste_code_9 + ',' +waste_code_10 + ',' +waste_code_11 + ',' +waste_code_12
HAVING -- 12/17/2010 - per Brie
	 CASE WHEN 
				convert(numeric(5,1),
					round(sum(
							(
								(isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0)
							) 
							* isnull(wodi.merchandise_quantity,1)
						),1)
				) BETWEEN 0.0001 AND 1.0 THEN 
		1.0
	  ELSE
			round(
				convert(numeric(5,1),
					round(sum(
							(
								(isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0)
							) 
							* isnull(wodi.merchandise_quantity,1)
						),1)
				) 	  
			, 1) 
	  END > 0
	  
  -- Above is 3rd party disposal
  UNION
  -- Below is EQ disposal
  SELECT distinct
      f.site_code, 
      f.generator_city, 
      f.generator_state,
      f.service_date as shipment_date,
      case when rdi.month is null or rdi.year is null then
		convert(datetime, 
			convert(varchar(2), datepart(m, f.service_date)) + '/01/' + convert(varchar(4), datepart(yyyy, f.service_date))
		)
		else
			convert(datetime, convert(varchar(2), rdi.month) + '/01/' + CONVERT(varchar(4), rdi.year)) 
	  end as generation_date,
      f.epa_id,
      CASE WHEN (
		  CASE WHEN 
					convert(numeric(5,1),
						round(sum(
								(
									(isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0)
								) 
								* isnull(rdi.merchandise_quantity,1)
							),1)
					) BETWEEN 0.0001 AND 1.0 THEN 
			1.0
		  ELSE
				round(
					convert(numeric(5,1),
						round(sum(
								(
									(isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0)
								) 
								* isnull(rdi.merchandise_quantity,1.0)
							),1)
					) 	  
				, 1)
		  END ) > 0 
	   THEN
	round(
		convert(numeric(5,1),
			round(sum(
					(
						(isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0)
					) 
					* isnull(rdi.merchandise_quantity,1.0)
				),1)
		) 	  
			, 1)
		ELSE
			(
				select line_weight 
				FROM receipt 
				WHERE receipt_id = f.receipt_id 
				and line_id = f.line_sequence_id 
				AND company_id = f.company_id 
				and profit_ctr_id = f.profit_ctr_id
			)
		END	AS Weight,
      f.approval_or_resource,
      f.manifest,
      f.manifest_line,
      f.company_id,
      f.profit_ctr_id,
      f.receipt_id,
      f.item_type,
      f.line_sequence_id,
      NULL,
      'F' as calculated_flag,
      
      /*
      
      -- Finance version shouldn't care about exclusions
      
	  exclude_flag = 
		  CASE WHEN (1=0
		  	-- exclude any generator that has a site type of Optical Lab, DC, Return Center, PMDC 
		  	OR f.site_type LIKE '%Optical Lab%'
		  	OR f.site_type LIKE '%DC%'
		  	OR f.site_type LIKE '%Return Center%'
		  	OR f.site_type LIKE '%PMDC%'
		  ) THEN 
			  'T'
		  ELSE
		  
		  	-- exclude any non-hazardous or universal waste approvals: 
			-- 	approval numbers WMNHW01-WMNHW16, WMUW01-WMUW03 
			-- 	approvals that do not contain a RCRA hazardous waste code (D, F, K, P, U)
			
			  CASE WHEN (1=0
			  	OR f.approval_or_resource IN ('WMNHW01','WMNHW02','WMNHW03','WMNHW04','WMNHW05','WMNHW06','WMNHW07','WMNHW08','WMNHW09','WMNHW10','WMNHW11','WMNHW12','WMNHW13','WMNHW14','WMNHW15','WMNHW16')
				OR f.approval_or_resource IN ('WMUW01', 'WMUW02', 'WMUW03')
			  ) THEN
			  	'T'
			  ELSE
			  	CASE WHEN NOT EXISTS (
			  		SELECT wc.waste_code
			  		FROM ProfileWasteCode pwc  (nolock)
			  		INNER JOIN WasteCode wc (nolock) on pwc.waste_code = wc.waste_code
			  		WHERE pwc.profile_id = f.profile_id
			  		AND f.profile_id is not null
			  		AND wc.waste_code_origin = 'F'
			  		AND left(wc.waste_code, 1) in ('D', 'F', 'P', 'K', 'U')
			  		AND wc.haz_flag = 'T'
			  	) THEN
			  		'T'
			  	ELSE
			  		'F'
			  	END
			  END
			END,
*/
	  exclude_flag = 'F',
	  
	  @usr as added_by,
	  @extract_datetime as date_added
       , CASE WHEN CHARINDEX(',P', f.waste_codes) <= 0 THEN
				''
			ELSE
			'P'
		END AS plisted
  from 
  (
	SELECT DISTINCT 
      site_code, 
      generator_city, 
      generator_state,
      service_date,
	  epa_id,
      approval_or_resource,
      manifest,
      manifest_line,
      company_id,
      profit_ctr_id,
      receipt_id,
      item_type,
      line_sequence_id,
	  site_type,
	  profile_id,
      added_by,
      date_added
     , ',' + waste_code_1 + ',' +waste_code_2 + ',' +waste_code_3 + ',' +waste_code_4 + ',' +waste_code_5 + ',' +waste_code_6 + ',' +waste_code_7 + ',' +waste_code_8 + ',' +waste_code_9 + ',' +waste_code_10 + ',' +waste_code_11 + ',' +waste_code_12 AS waste_codes
	FROM EQ_TEMP.dbo.WalmartDisposalExtract   (nolock)
	  WHERE 1=1
	  and added_by = @usr
	  and date_added = @extract_datetime
	  AND submitted_flag = 'T'
) f
  -- new on 12/14:
  inner join profilequoteapproval pro 
		on f.profile_id = pro.profile_id 
		and f.company_id = pro.company_id 
		and f.profit_ctr_id = pro.profit_ctr_id
  left outer join ReceiptDetailItem rdi (nolock)
		on f.receipt_id = rdi.receipt_id
		and f.line_sequence_id = rdi.line_id
		and f.company_id = rdi.company_id
		and f.profit_ctr_id = rdi.profit_ctr_id
  WHERE 1=1
  and f.added_by = @usr
  and f.date_added = @extract_datetime
GROUP BY
      f.site_code, 
      f.generator_city, 
      f.generator_state,
      f.service_date,
      rdi.month,
      rdi.year,
      f.epa_id,
      f.approval_or_resource,
      f.manifest,
      f.manifest_line,
      f.company_id,
      f.profit_ctr_id,
      f.receipt_id,
      f.item_type,
      f.line_sequence_id,
	  f.site_type,
	  f.profile_id,
      f.added_by,
      f.date_added
    , f.waste_codes
/*      
HAVING -- 12/17/2010 - per Brie
      CASE WHEN 
				convert(numeric(5,1),
					round(sum(
							(
								(isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0)
							) 
							* isnull(rdi.merchandise_quantity,1)
						),1)
				) BETWEEN 0.0001 AND 1.0 THEN 
		1.0
	  ELSE
			round(
				convert(numeric(5,1),
					round(sum(
							(
								(isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0)
							) 
							* isnull(rdi.merchandise_quantity,1.0)
						),1)
				) 	  
			, 1)
	  END > 0  
*/


-- since calculating 2 versions of every weight was horrid for CPU/performance, we just stored whether each line was plisted or not.
-- Time to go back and take care of the rounding.

UPDATE EQ_Extract..WMDisposalGeneration
SET weight = round(weight,0)
WHERE
	date_added = @extract_datetime
	  AND added_by = @usr
	  and plisted = '' 
	  and weight > 1

print 'Updating EQ_Extract..WMDisposalGeneration weights rounded to whole numbers where > 1 and not plisted, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


UPDATE EQ_Extract..WMDisposalGeneration
SET weight = round(weight,1)
WHERE
	date_added = @extract_datetime
	  AND added_by = @usr
	  and plisted = 'P' 

print 'Updating EQ_Extract..WMDisposalGeneration weights rounded to 1/10th where plisted, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

UPDATE EQ_Extract..WMDisposalGeneration
SET weight = 1
WHERE
	date_added = @extract_datetime
	  AND added_by = @usr
	  and plisted = '' 
	  and weight between 0.0001 AND 1
	  
print 'Updating EQ_Extract..WMDisposalGeneration weights to 1 where between 0 & 1 and not plisted, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

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

/*
-- Finance version should come *after* disposal version, right? Skip validations that disposal did.

-- Create list of missing transporter info
    INSERT EQ_Extract..WMDisposalValidation
    SELECT  DISTINCT
    	'Missing Transporter Info' as Problem,
    	source_table,
    	Company_id,
    	Profit_ctr_id,
    	Receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    FROM EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    WHERE 
    	ISNULL((select transporter_name from transporter (nolock) where transporter_code = EQ_TEMP.dbo.WalmartDisposalExtract.transporter1_code), '') = ''
	    AND waste_desc <> 'No waste picked up'
	    AND added_by = @usr 
	    AND date_added = @extract_datetime
	    AND submitted_flag = 'T'
    	
print 'Validation: Missing Transporter Info, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of Missing Waste Code
    INSERT EQ_Extract..WMDisposalValidation
    SELECT DISTINCT
    	'Missing Waste Code',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract e (nolock) 
    where
	    waste_desc <> 'No waste picked up'
	    and manifest_line is not null
	    and item_type in ('A', 'D', 'N')
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    and source_table = 'Workorder'
	    and coalesce(waste_code_1, waste_code_2, waste_code_3, waste_code_4, waste_code_5, waste_code_6, waste_code_7, waste_code_8, waste_code_9, waste_code_10, waste_code_11, waste_code_12, '') = ''
	    and coalesce(state_waste_code_1, state_waste_code_2, state_waste_code_3, state_waste_code_4, state_waste_code_5, '') = ''
	UNION ALL
    SELECT DISTINCT
    	'Missing Waste Code',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract e (nolock) 
    where
	    waste_desc <> 'No waste picked up'
	    and manifest_line is not null
	    and item_type in ('A', 'D', 'N')
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    and source_table = 'Receipt'
	    and coalesce(waste_code_1, waste_code_2, waste_code_3, waste_code_4, waste_code_5, waste_code_6, waste_code_7, waste_code_8, waste_code_9, waste_code_10, waste_code_11, waste_code_12, '') = ''
	    and coalesce(state_waste_code_1, state_waste_code_2, state_waste_code_3, state_waste_code_4, state_waste_code_5, '') = ''

print 'Validation: Missing Waste Codes, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of missing Weights
    INSERT EQ_Extract..WMDisposalValidation
    SELECT DISTINCT
    	'Missing Weight',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line/seq: ' + convert(varchar(20), line_sequence_id),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	isnull(pounds,0) = 0
	    AND waste_desc <> 'No waste picked up'
	    and manifest_line is not null
	    and item_type in ('A', 'D')
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: Missing Weights, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of missing Service Dates
    INSERT EQ_Extract..WMDisposalValidation
    SELECT DISTINCT
    	'Missing Service Date',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	isnull(service_date, '') = ''
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    AND approval_or_resource not in (
	    	select approval_code from #ApprovalNoWorkorder
	    )

print 'Validation: Missing Service Dates, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of receipts missing workorders
    INSERT EQ_Extract..WMDisposalValidation
    SELECT DISTINCT
    	'Receipt missing Workorder',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    WHERE
		source_table = 'receipt'
    	AND isnull(receipt_workorder_id, '') = ''
    	AND approval_or_resource not in (select approval_code from #ApprovalNoWorkorder)
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: Receipts Missing Workorders, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of missing site codes
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Missing Generator Site Code',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	site_code = ''
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: Missing Site Codes, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of missing site type
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Missing Generator Site Type',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	isnull(site_type, '') = ''
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: Missing Site Types, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of unsubmitted receipts
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Receipt Not Submitted',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		source_table = 'Receipt'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'F'

print 'Validation: Unsubmitted Receipts, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of unsubmitted workorders
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Workorder Not Submitted',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		source_table like 'Workorder%'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'F'
	    
print 'Validation: Unsubmitted Workorders, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of records missing scans
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Missing Scan',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'missing ' + isnull(manifest, ''),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		source_table in ('Receipt', 'Workorder')
    	AND approval_or_resource not in (select approval_code from #ApprovalNoWorkorder)
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
		AND manifest not in (
			select document_name 
			from EQ_TEMP..WalmartExtractImages (nolock) 
			WHERE added_by = @usr 
				and date_added = @extract_datetime 
				AND submitted_flag = 'T' 
		)
    	and item_type <> 'N'

print 'Validation: Missing Scans, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create count of receipt-based records in extract
    INSERT EQ_Extract..WMDisposalValidation
     SELECT
    	' Count of Receipt-based records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*)),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		source_table ='Receipt'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: Receipt Record Count, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create count of workorder -based records in extract
    INSERT EQ_Extract..WMDisposalValidation
     SELECT 
    	' Count of Workorder-based records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*)),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		source_table ='Workorder'
    	AND waste_desc <> 'No waste picked up'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: Workorder Record Count, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create count of NWP -based records in extract
    INSERT EQ_Extract..WMDisposalValidation
     SELECT 
    	' Count of No Waste Pickup records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*)),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		source_table ='Workorder'
    	AND waste_desc = 'No waste picked up'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: No Waste Pickup Record Count, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of unusually high number of manifest names
    INSERT EQ_Extract..WMDisposalValidation
     SELECT
    	'High Number of same manifest-line',
    	null,
    	null,
    	null,
    	null,
    	CONVERT(varchar(20), count(*)) + ' times: ' + isnull(manifest, '') + ' line ' + isnull(CONVERT(varchar(10), Manifest_Line), ''),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	waste_desc <> 'No waste picked up'
    	AND bill_unit_desc not like '%cylinder%'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
	group by manifest, manifest_line
	having count(*) > 2

print 'Validation: Count high # of Manifest-Line combo, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of missing dot descriptions
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Missing DOT Description',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
	    added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
        AND ISNULL(
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


print 'Validation: Missing DOT Description, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Create list of missing bill units in extract
    INSERT EQ_Extract..WMDisposalValidation
     SELECT 
    	'Missing Bill Unit',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line ' + convert(varchar(10), line_sequence_id),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
		isnull(bill_unit_desc, '') = ''
		AND waste_desc <> 'No waste picked up'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

print 'Validation: Missing Bill Unit Description, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Create list of missing waste descriptions
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Missing Waste Description',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	waste_desc = ''
	    AND added_by = @usr 
	    AND date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    and approval_or_resource not in ('STOPFEE', 'GASSUR%')
	    and waste_desc <> 'No waste picked up'

print 'Validation: Missing Waste Description, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Create list of blank waste code 1's
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Blank Waste Code 1',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line/seq: ' + convert(varchar(20), line_sequence_id),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.WalmartDisposalExtract (nolock) 
    where
    	ISNULL(waste_code_1, '') = ''
    	AND coalesce(waste_code_2, waste_code_3, waste_code_4, waste_code_5, waste_code_6, waste_code_7, waste_code_8, waste_code_9, waste_code_10, '') <> ''
	    AND added_by = @usr 
	    AND date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    and waste_desc <> 'No waste picked up'

print 'Validation: Blank Waste Code 1, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Catch generators serviced that aren't in the extracts
    INSERT EQ_Extract..WMDisposalValidation
     SELECT DISTINCT
    	'Site serviced, NOT in extract',
    	'Workorder',
    	woh.company_id,
    	woh.profit_ctr_id,
    	woh.workorder_id,
    	left(convert(varchar(20), woh.generator_id) + ' (' + isnull(g.site_code, 'Code?') + ' - ' + isnull(g.generator_city, 'city?') + ', ' + isnull(g.generator_state, 'ST?') + ')', 40),
    	@usr,
    	@extract_datetime
	FROM workorderheader woh (nolock)
	INNER join TripHeader th (nolock) ON woh.trip_id = th.trip_id
	INNER JOIN generator g (nolock) on woh.generator_id = g.generator_id
	LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = woh.workorder_id
		and wos.company_id = woh.company_id
		and wos.profit_ctr_id = woh.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
	WHERE th.trip_status IN ('D', 'C', 'A', 'U')
	AND woh.workorder_status <> 'V'
	AND (woh.customer_id IN (select customer_id from #Customer) OR woh.generator_id in (select generator_id from CustomerGenerator (nolock) where customer_id IN (select customer_id from #Customer)))
	AND coalesce(wos.date_act_arrive, woh.start_date) between @start_date and @end_date
	AND g.generator_id not in (
		select generator_id 
		from EQ_TEMP.dbo.WalmartDisposalExtract  (nolock)
		where submitted_flag = 'T'
		AND added_by = @usr
		AND date_added = @extract_datetime
	)

print 'Validation: Generators Serviced, but not in extracts, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

*/

/*

-- Finance version shouldn't care about missing generators (a kind of validation)

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
    AND generator_id NOT IN (SELECT generator_id FROM CustomerGenerator (nolock) WHERE customer_id IN (select customer_id from #Customer))
    ORDER BY generator_state, generator_city, site_code

print 'Validation: Generators that look like WM, but not in WM related set, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()
*/

/*

-- Finance version shouldn't have to compare disposal vs generation, if the Disposal extract did that, right?

 -- Disposal vs Trip info: Approvals or Weights don't match.
 -- Step 1: Create a temp table that contains totals per line to compare against each other.
		 SELECT
			receipt_weight = (
				SELECT sum(pounds) FROM EQ_TEMP.dbo.WalmartDisposalExtract d2 (nolock)
				WHERE d2.receipt_id = d.receipt_id
				AND d2.company_id = d.company_id
				AND d2.profit_ctr_id = d.profit_ctr_id
				AND d2.line_sequence_id = d.line_sequence_id
				and d2.added_by = d.added_by
				and d2.date_added = d.date_added
				AND d2.submitted_flag = d.submitted_flag
			),
			wodi_weight = (
				CASE WHEN d.source_table = 'Workorder' THEN (
                    SELECT 
                        CASE WHEN convert(numeric(5,1), round(sum( ( (isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0) )  * isnull(wodi.merchandise_quantity,1) ),1) ) BETWEEN 0.0001 AND 1.0 THEN 
                            1.0 
                        ELSE
                            round( convert(numeric(5,1), round(sum( ( (isnull(wodi.pounds,0) * 1.0) + (isnull(wodi.ounces,0)/16.0) )  * isnull(wodi.merchandise_quantity,1) ),1) )  , 1)
                        END
                    FROM
                        [dbo].[WorkOrderDetailItem] wodi
                    WHERE [wodi].[workorder_id] = t.workorder_id
                        AND [wodi].[sequence_id] = t.sequence_id
                        AND [wodi].[company_id] = t.company_id
                        AND [wodi].[profit_ctr_id] = t.profit_ctr_id
                    )
				ELSE -- source_table = 'Receipt'...
                    CASE WHEN 
                        (
                            CASE WHEN 
                                (
                                    SELECT 
                                        CONVERT(numeric(5,1), ROUND(SUM( ( (isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0) )  * ISNULL(rdi.merchandise_quantity,1) ),1))
                                    FROM
                                        [dbo].[ReceiptDetailItem] rdi
                                    WHERE [rdi].[receipt_id] = d.receipt_id
                                        AND [rdi].[line_id] = d.line_sequence_id
                                        AND [rdi].[company_id] = d.company_id
                                        AND [rdi].[profit_ctr_id] = d.profit_ctr_id
                                ) BETWEEN 0.0001 AND 1.0 
                            THEN 
                                1.0
                            ELSE
                                (
                                    SELECT 
                                        ROUND( CONVERT(numeric(5,1), round(SUM( ( (isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0) )  * ISNULL(rdi.merchandise_quantity,1.0) ),1) ), 1)
                                    FROM
                                        [dbo].[ReceiptDetailItem] rdi
                                    WHERE [rdi].[receipt_id] = d.receipt_id
                                        AND [rdi].[line_id] = d.line_sequence_id
                                        AND [rdi].[company_id] = d.company_id
                                        AND [rdi].[profit_ctr_id] = d.profit_ctr_id
                                )
                            END 
                        ) > 0 
                    THEN
                        (
                            SELECT 
                                ROUND( CONVERT(numeric(5,1), round(SUM( ( (isnull(rdi.pounds,0) * 1.0) + (isnull(rdi.ounces,0)/16.0) )  * ISNULL(rdi.merchandise_quantity,1.0) ),1) ), 1)
                            FROM
                                [dbo].[ReceiptDetailItem] rdi
                            WHERE [rdi].[receipt_id] = d.receipt_id
                                AND [rdi].[line_id] = d.line_sequence_id
                                AND [rdi].[company_id] = d.company_id
                                AND [rdi].[profit_ctr_id] = d.profit_ctr_id
                        )
                    ELSE
                        (
                            select line_weight 
                            FROM receipt 
                            WHERE receipt_id = d.receipt_id 
                            and line_id = d.line_sequence_id 
                            AND company_id = d.company_id 
                            and profit_ctr_id = d.profit_ctr_id
                        )
                    END	
                END
            ),

			d.company_id AS receipt_company_id,
			d.profit_ctr_id AS receipt_profit_ctr_id,
			d.receipt_id,
			d.line_sequence_id as receipt_line_id,
			d.approval_or_resource AS receipt_approval,
			d.manifest,
			d.manifest_line,
			t.company_id as wo_company_id,
			t.profit_ctr_id as wo_profit_ctr_id,
			t.workorder_id as workorder_id,
			t.resource_type AS wo_resource_type,
			t.sequence_id as wo_sequence_id,
			t.tsdf_approval_code as wo_tsdf_approval,
			t.calculated_flag,
			0 as exported_flag,
			d.date_added,
			d.added_by
		INTO #DisposalVsTripValidation	
		FROM EQ_TEMP.dbo.WalmartDisposalExtract d (nolock)
		INNER JOIN EQ_Extract.dbo.WMDisposalGeneration T (nolock)
			on d.manifest = t.manifest
			and d.manifest_line = t.manifest_line
		    and t.added_by = d.added_by
		    and t.date_added = d.date_added
			AND t.weight >= 1
		WHERE d.source_table = 'Receipt'
		and d.added_by = @usr
		and d.date_added = @extract_datetime
		AND d.submitted_flag = 'T'
		AND isnull(t.exclude_flag, 'F') = 'F'
		AND EXISTS (
			-- Don't bother comparing records using approvals that are non-haz. They won't be in the trip stuff, intentionally.
			SELECT wc.waste_code
			FROM profilequoteapproval pqa (nolock)
			inner join profilewastecode pwc (nolock) ON pqa.profile_id = pwc.profile_id
			inner join wastecode wc (nolock) on pwc.waste_code = wc.waste_code
			WHERE 
			pqa.approval_code = d.approval_or_resource
			AND wc.haz_flag = 'T' 
			AND wc.waste_code_origin = 'F'
		)

print 'Validation: Disposal vs Trip info, #tmp table, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

	-- Step 2: Export lines where both approval and weight don't match.
	UPDATE #DisposalVsTripValidation SET
		exported_flag = 2 
	WHERE 1=1
	AND abs(round(isnull(receipt_weight, -1111),1) - round(isnull(wodi_weight, -2222),1)) > 1
	AND isnull(receipt_approval, '-1111') <> isnull(wo_tsdf_approval, '-2222')
	AND isnull(wodi_weight, -2222) <> -2222
	AND exported_flag = 0
	
print 'Validation: Disposal vs Trip info - Approval and Weight do not match, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()
		
	-- Step 3: Export lines where approval doesn't match, but weight does.

--	UPDATE #DisposalVsTripValidation SET
--		exported_flag = 3 -- step 3
--	WHERE 1=1
--	AND isnull(receipt_weight, -1111) = isnull(wodi_weight, -2222)
--	AND isnull(receipt_approval, '-1111') <> isnull(wo_tsdf_approval, '-2222')
--	AND isnull(wodi_weight, -2222) <> -2222
--	AND exported_flag = 0


--print 'Validation: Disposal vs Trip info - Approval matches, Weight does not'
--PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
--Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
--set @steptimer = getdate()

	
	-- Step 4: Export lines where approval matches, but weight does not.
	UPDATE #DisposalVsTripValidation SET
		exported_flag = 4 -- step 4
	WHERE 1=1
	AND abs(isnull(receipt_weight, -1111) - isnull(wodi_weight, -2222)) > 1
	AND isnull(receipt_approval, '-1111') = isnull(wo_tsdf_approval, '-2222')
	AND isnull(wodi_weight, -2222) <> -2222
	AND exported_flag = 0

print 'Validation: Disposal vs Trip info, Approval Matches, Weight not so much, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

	-- Step 5: Export lines Generation record was created from Disposal info.
	UPDATE #DisposalVsTripValidation SET
		exported_flag = 5 -- step 5
	WHERE 1=1
	AND calculated_flag = 'T'
	AND isnull(wodi_weight, -2222) <> -2222
	AND exported_flag = 0

print 'Validation: Disposal vs Trip info - Generation record was created from Disposal info only, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

	-- Step Last: Export to WMDisposalGenerationValidation
	INSERT EQ_Extract.dbo.WMDisposalGenerationValidation
	SELECT DISTINCT
		CASE dvtv.exported_flag 
			WHEN 2 THEN 'Appovals and Weights do not match'
			WHEN 3 THEN 'Approvals do not match. Weights do'
			WHEN 4 THEN 'Approvals match. Weights do not'
			WHEN 5 THEN 'Calculated Generation record, no WO found'
			ELSE 'No problem'
		END AS problem,
		dvtv.receipt_company_id,
		dvtv.receipt_profit_ctr_id,
		dvtv.receipt_id,
		dvtv.receipt_line_id,
		dvtv.manifest,
		dvtv.manifest_line,
		dvtv.wo_company_id,
		dvtv.wo_profit_ctr_id,
		dvtv.workorder_id,
		dvtv.wo_resource_type,
		dvtv.wo_sequence_id,
		NULL , --t.sub_sequence_id AS wodi_sub_sequence_id,
		NULL, -- datepart(m, t.generation_date) as wodi_month,
		NULL, -- datepart(yyyy, t.generation_date) as wodi_year,
		dvtv.wo_tsdf_approval,
		dvtv.wodi_weight,
		dvtv.receipt_approval,
		dvtv.receipt_weight,
		null as corrected_wodi_weight,
		@usr as added_by,
		@extract_datetime as date_added
	FROM #DisposalVsTripValidation dvtv
	INNER JOIN EQ_Extract.dbo.WMDisposalGeneration T (nolock)
		on dvtv.workorder_id = t.workorder_id
		AND dvtv.wo_sequence_id = t.sequence_id
		AND dvtv.wo_company_id = t.company_id
	    AND dvtv.wo_resource_type = t.resource_type
		AND dvtv.wo_profit_ctr_id = t.profit_ctr_id
		AND dvtv.manifest = t.manifest
		and dvtv.manifest_line = t.manifest_line
	    and dvtv.added_by = t.added_by
	    and dvtv.date_added = t.date_added
	WHERE dvtv.exported_flag > 0
/*
	SELECT
		CASE dvtv.exported_flag 
			WHEN 2 THEN 'Appovals and Weights do not match'
			WHEN 3 THEN 'Approvals do not match. Weights do'
			WHEN 4 THEN 'Approvals match. Weights do not'
			WHEN 5 THEN 'Calculated Generation record, no WO found'
			ELSE 'No problem'
		END AS problem,
		d.company_id AS receipt_company_id,
		d.profit_ctr_id AS receipt_profit_ctr_id,
		d.receipt_id,
		d.line_sequence_id as receipt_line_id,
		d.manifest,
		d.manifest_line,
		t.company_id as wo_company_id,
		t.profit_ctr_id as wo_profit_ctr_id,
		t.workorder_id as workorder_id,
		t.resource_type AS wo_resource_type,
		t.sequence_id as wo_sequence_id,
		NULL , --t.sub_sequence_id AS wodi_sub_sequence_id,
		datepart(m, t.generation_date) as wodi_month,
		datepart(yyyy, t.generation_date) as wodi_year,
		t.tsdf_approval_code as wo_tsdf_approval,
		sum(t.weight) as wodi_weight,
		d.approval_or_resource AS receipt_approval,
		d.pounds AS receipt_weight,
		null as corrected_wodi_weight,
		@usr as added_by,
		@extract_datetime as date_added
	FROM #DisposalVsTripValidation dvtv
	INNER JOIN EQ_TEMP.dbo.WalmartDisposalExtract d
		ON dvtv.receipt_company_id = d.company_id
		AND dvtv.receipt_profit_ctr_id = d.profit_ctr_id
		AND dvtv.receipt_id = d.receipt_id
		AND dvtv.receipt_line_id = d.line_sequence_id
	LEFT OUTER JOIN EQ_Extract.dbo.WMDisposalGeneration T (nolock)
		on d.manifest = t.manifest
		and d.manifest_line = t.manifest_line
	    and t.added_by = d.added_by
	    and t.date_added = d.date_added
	    and t.company_id = dvtv.wo_company_id
	    AND t.profit_ctr_id = dvtv.wo_profit_ctr_id
	    AND t.workorder_id = dvtv.workorder_id
	    AND t.resource_type = dvtv.wo_resource_type
	    AND t.sequence_id = dvtv.wo_sequence_id
	WHERE d.source_table = 'Receipt'
	and d.added_by = @usr
	and d.date_added = @extract_datetime
	AND d.submitted_flag = 'T'
	AND isnull(t.exclude_flag, 'F') = 'F'
	AND dvtv.exported_flag > 0
	GROUP by
		dvtv.exported_flag,
		d.company_id,
		d.profit_ctr_id,
		d.receipt_id,
		d.line_sequence_id,
		d.manifest,
		d.manifest_line,
		t.company_id,
		t.profit_ctr_id,
		t.workorder_id,
		t.resource_type,
		t.sequence_id,
		datepart(m, t.generation_date),
		datepart(yyyy, t.generation_date),
		t.tsdf_approval_code,
		d.approval_or_resource,
		d.pounds
*/

print 'Validation: Disposal vs Trip info - Results to WMDisposalGenerationValidation, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

*/

/* *************************************************************
Populate Output tables from this run.
************************************************************* */

/*

-- Finance version skips validation output, because it skipped validation

-- Validation Information
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

        INSERT EQ_Extract.dbo.WalmartDisposalValidation
        SELECT
            v_id,
            reason,
            problem_ids,
            prod_value,
            extract_value,
            @usr,
            @extract_datetime
        FROM EQ_Temp..WalmartDisposalValidation
        WHERE added_by = @usr
        AND date_added = @extract_datetime

print 'Output: Validation, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


-- Finance version skips Generator output

-- Generators Information
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


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
        FROM EQ_TEMP..WalmartMissingGenerators
        WHERE added_by = @usr and date_added = @extract_datetime

        
print 'Output: Generators, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Finance version skips Disposal Information output

-- Disposal Information
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

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

print 'Output: Disposal, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

-- Finance version skips image output

-- Manifest Information

PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()
        
        INSERT EQ_Extract.dbo.WalmartDisposalImages
        SELECT
            row_id,
            site_code,
            generator_id,
            service_date,
            image_id,
            document_name,
            page_number,
            file_type,
            filename,
            process_flag,
            newname,
            @usr,
            @extract_datetime
        FROM EQ_TEMP..WalmartExtractImages (nolock) WHERE added_by = @usr and date_added = @extract_datetime

print 'Output: Images, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()

*/

-- Finance version DOES care about FINANCE (ahem)

create table #FinanceInfo (
	company_id		int,
	profit_ctr_id	int,
	receipt_id		int,
	trans_source	char(1),
	generator_id	int,
	site_type		varchar(40),
	period_year		int,
	period_month	int,
	total_amt		money,
	disposal_amt	money,
	trans_amt		money,
	other_amt		money,
	invoice_code	varchar(40)
)

insert #FinanceInfo
select
	b.company_id,
	b.profit_ctr_id,
	b.receipt_id,
	b.trans_source,
	b.generator_id,
	g.site_type,
	null, null,
	sum(bd.extended_amt) as total_amt
	,SUM(
		CASE WHEN (b.trans_source = 'R' OR (b.trans_source = 'W' and b.workorder_resource_type = 'D') OR rcd.category = 'Disposal') 
			THEN bd.extended_amt
			ELSE 0
		END
	) as disposal_amt
	,SUM(
		CASE WHEN rcd.category = 'Transportation'
		THEN bd.extended_amt
		ELSE 0
		END
	) as trans_amt
	,SUM(
		CASE WHEN (b.trans_source = 'R' OR (b.trans_source = 'W' and b.workorder_resource_type = 'D') OR rcd.category = 'Disposal') 
			THEN 0
			WHEN rcd.category = 'Transportation'
			THEN 0
			ELSE bd.extended_amt
		END
	) as other_amt
	, b.invoice_code
from Billing b (nolock)
	INNER JOIN BillingDetail bd (nolock)
		on 	bd.receipt_id = b.receipt_id
		and bd.line_id = b.line_id
		and bd.price_id = b.price_id
		and bd.trans_source = b.trans_source
		AND bd.company_id = b.company_id
		and bd.profit_ctr_id = b.profit_ctr_id
	LEFT OUTER JOIN ResourceClassDetail rcd (nolock)
		ON b.workorder_resource_item = rcd.resource_class_code
		AND b.company_id = rcd.company_id
		AND b.profit_ctr_id = rcd.profit_ctr_id
		AND b.bill_unit_code = rcd.bill_unit_code
	LEFT OUTER JOIN Generator g (nolock) on b.generator_id = g.generator_id
WHERE 
	b.status_code = 'I'
	AND EXISTS (
		SELECT 1 FROM EQ_TEMP.dbo.WalmartDisposalExtract t (nolock)
		WHERE t.receipt_id = b.receipt_id
		and t.company_id = b.company_id
		and t.profit_ctr_id = b.profit_ctr_id
		and left(t.source_table, 1) = b.trans_source
		and t.added_by =	@usr
	   and t.date_added = @extract_datetime
	) 
GROUP BY
	b.company_id,
	b.profit_ctr_id,
	b.receipt_id,
	b.trans_source,
	b.generator_id,
	g.site_type,
	b.invoice_code

UPDATE #FinanceInfo SET
	period_year = datepart(yyyy, t.service_date),
	period_month = datepart(m, t.service_date)
FROM
#FinanceInfo f
INNER JOIN EQ_Temp..WalmartDisposalExtract t (nolock)
	ON f.receipt_id = t.receipt_id
	and f.company_id = t.company_id
	and F.profit_ctr_id = t.profit_ctr_id
	and f.trans_source = left(t.source_table, 1)
	and t.added_by =	@usr
   and t.date_added = @extract_datetime

IF EXISTS (select 1 FROM sysobjects WHERE name = 'jpb_fi') DROP TABLE jpb_fi
SELECT * INTO jpb_FI from #FinanceInfo

-- Combine Disposal/Generation & Finance info.
-- First, sum the finance info by site_type
-- drop table #CombineInfo
SELECT
	f.period_year
	, f.period_month
	, f.site_type
	, convert(float, null) as grand_total_amt
	, convert(float, null) as total_disposal_amt
	, convert(float, null) as total_transportation_amt
	, convert(float, null) as total_other_amt
	, convert(float, null) as total_generation_pounds
	, convert(float, null) as avg_generation_pounds
	, convert(float, null) as avg_disposal_amt
	, convert(float, null) as avg_transportation_amt
	, convert(float, null) as avg_other_amt
	, convert(float, null) as avg_invoice 
	, count(distinct t.generator_id) AS store_count
	, count(distinct f.invoice_code) as invoice_count
INTO #CombineInfo
FROM #FinanceInfo f
INNER JOIN EQ_Temp..WalmartDisposalExtract t (nolock)
	ON f.receipt_id = t.receipt_id
	and f.company_id = t.company_id
	and F.profit_ctr_id = t.profit_ctr_id
	and f.trans_source = left(t.source_table, 1)
	and t.added_by =	@usr
   and t.date_added = @extract_datetime
GROUP BY 
	f.period_year
	, f.period_month
	, f.site_type

DECLARE @year int, @month int, @site_type varchar(40)
WHILE EXISTS (select 1 FROM #CombineInfo WHERE avg_invoice IS null) BEGIN
	SELECT TOP 1 @year = period_year,
		@month = period_month,
		@site_type = site_type
	FROM #CombineInfo
	WHERE avg_invoice IS null
	AND isnull(invoice_count, 0) > 0
	
	UPDATE #CombineInfo SET
		grand_total_amt = (
			select sum(f.total_amt)
			from #FinanceInfo f
			where site_type = @site_type
			and period_year = @year
			and period_month = @month
		)
		, total_disposal_amt = (
			select sum(f.disposal_amt)
			from #FinanceInfo f
			where site_type = @site_type
			and period_year = @year
			and period_month = @month
		)
		, total_transportation_amt = (
			select sum(f.trans_amt)
			from #FinanceInfo f
			where site_type = @site_type
			and period_year = @year
			and period_month = @month
		)
		, total_other_amt = (
			select sum(f.other_amt)
			from #FinanceInfo f
			where site_type = @site_type
			and period_year = @year
			and period_month = @month
		)
		, total_generation_pounds = (
			SELECT sum(pounds)
			FROM EQ_Temp..WalmartDisposalExtract
			WHERE site_type = @site_type
			and datepart(yyyy, service_date) = @year
			and datepart(m, service_date) = @month
   		and added_by =	@usr
   	   and date_added = @extract_datetime
		)
		where site_type = @site_type
		and period_year = @year
		and period_month = @month

	
/* Bah, this is wrong, because now WM invoices combine many disparate generators to the same invoice code	
	UPDATE #CombineInfo SET
		avg_invoice = (select sum(ih.total_amt_due) / count(ih.invoice_code)
		from invoiceheader ih
		where invoice_code in (
			select invoice_code from #FinanceInfo 
			where site_type = @site_type
			and period_year = @year
			and period_month = @month
		)
		)
		where site_type = @site_type
		and period_year = @year
		and period_month = @month
*/

	-- Just to get out of the loop...
	UPDATE #CombineInfo SET
		avg_invoice = 0
		where site_type = @site_type
		and period_year = @year
		and period_month = @month
		
END

	-- Set Averages
	UPDATE #CombineInfo SET
		avg_generation_pounds = 
		  CASE WHEN round(total_generation_pounds / store_count,1) BETWEEN 0.0001 AND 1.0 THEN 1.0 ELSE round(total_generation_pounds / store_count,1) END,
		avg_disposal_amt = 
		  CASE WHEN round(total_disposal_amt / store_count,1) BETWEEN 0.0001 AND 1.0 THEN 1.0 ELSE round(total_disposal_amt / store_count,1) END,
		avg_transportation_amt = 
		  CASE WHEN round(total_transportation_amt / store_count,1) BETWEEN 0.0001 AND 1.0 THEN 1.0 ELSE round(total_transportation_amt / store_count,1) END,
		avg_other_amt = 
		  CASE WHEN round(total_other_amt / store_count,1) BETWEEN 0.0001 AND 1.0 THEN 1.0 ELSE round(total_other_amt / store_count,1) END,
		avg_invoice = round( grand_total_amt / store_count, 2)

	-- add a total row per period:
	INSERT #CombineInfo 
	SELECT period_year, period_month, 'Total',
		sum(grand_total_amt),
		sum(total_disposal_amt),
		sum(total_transportation_amt),
		sum(total_other_amt),
		sum(total_generation_pounds),
		sum(avg_generation_pounds),
		sum(avg_disposal_amt),
		sum(avg_transportation_amt),
		sum(avg_other_amt),
		sum(avg_invoice),
		sum(store_count),
		sum(invoice_count)
	FROM #CombineInfo
	GROUP BY period_year, period_month	

-- Data complete:
-- SELECT * from #CombineInfo

-- Now rotate #CombineInfo
CREATE TABLE #outRows (
	row_name	varchar(40),
	row_order	int,
	process_flag	int
)
	INSERT #outRows
		SELECT 'grand_total_amt',1, 0 union
		SELECT 'total_disposal_amt',2, 0 union
		SELECT 'total_transportation_amt',3, 0 union
		SELECT 'total_other_amt',4, 0 union
		SELECT 'total_generation_pounds',5, 0 union
		SELECT 'avg_generation_pounds',6, 0 union
		SELECT 'avg_disposal_amt',7, 0 union
		SELECT 'avg_transportation_amt',8, 0 union
		SELECT 'avg_other_amt',9, 0 union
		SELECT 'avg_invoice',10, 0 union
		SELECT 'store_count',11, 0 union
		SELECT 'invoice_count', 12, 0

-- SELECT * from #outRows ORDER BY row_order

-- drop table #outCols
CREATE TABLE #outCols (
	column_name	varchar(40),
	site_type	varchar(40),
	column_order	int,
	process_flag	int
)
-- SELECT DISTINCT site_type FROM #CombineInfo
	INSERT #outCols
		SELECT 'Campus', NULL, 1, 0 union
		SELECT 'XPS', NULL, 2, 0 union
		SELECT 'MKS', NULL, 3, 0 union
		SELECT 'WNM', 'Wal-Mart Neighborhood Market', 4, 0 union
		SELECT 'SAMS', 'Sams Club', 5, 0 union
		SELECT 'WM', 'Wal-Mart', 6, 0 union
		SELECT 'SUP', 'Wal-Mart Supercenter', 7, 0 union
		SELECT 'DC_OL', '% DC', 7, 0 union
		SELECT 'Grand_Total', 'Total', 8, 0
		

-- DROP TABLE #output

CREATE TABLE #output (
	period_year	int,
	period_month	int,
	row_name	varchar(40),
	row_order	int
)

UPDATE #outCols SET process_Flag = 0
UPDATE #outRows SET process_flag = 0

DECLARE @sql varchar(8000), @column_name varchar(40), @row_Name varchar(40), @row_order int
WHILE EXISTS (select 1 FROM #outCols WHERE process_flag = 0) BEGIN
	SELECT TOP 1 @column_name = column_name, @site_type = site_type
	FROM #outCols WHERE process_flag = 0
	ORDER BY column_order
	SET @sql = 'ALTER TABLE #output ADD ' + @column_name + ' float'
	EXEC (@sql)
	UPDATE #outCols SET process_flag = 1 WHERE column_name = @column_name
END

UPDATE #outCols SET process_flag = 0

WHILE EXISTS (select 1 FROM #outRows WHERE process_Flag = 0) BEGIN

	SELECT TOP 1 @row_name = row_name, @row_order = row_order
	FROM #outRows WHERE process_flag = 0
	ORDER BY row_order
	
	WHILE EXISTS (select 1 FROM #outCols WHERE process_flag = 0 AND site_type IS NOT null) BEGIN
	
		SELECT TOP 1 @column_name = column_name, @site_type = site_type
		FROM #outCols WHERE process_flag = 0
		AND site_type IS NOT null
		ORDER BY column_order
		IF NOT EXISTS (select * FROM #output WHERE row_name = @row_name)
			SET @sql = '
				INSERT #output (period_year, period_month, row_name, row_order, ' + @column_name + ')
				select distinct t.period_year, t.period_month, ''' + @row_name + ''', ' + convert(varchar(10), @row_order) + ', 
				t2.amt
				from #CombineInfo t
				inner join (
					select period_year, period_month, ' + @row_name + ' as amt from #CombineInfo 
					where site_type LIKE ''' + @site_type + '''
				) t2 on t.period_year = t2.period_year and t.period_month = t2.period_month
				'
		ELSE
			SET @sql = '
				UPDATE #output set ' + @column_name + ' = t2.amt
				FROM #output t
				inner join (
					select period_year, period_month, site_type, ' + @row_name + ' as amt from #CombineInfo
					where site_type LIKE ''' + @site_type + '''
				) t2 on t.period_year = t2.period_year and t.period_month = t2.period_month
				where row_name = ''' + @row_name + ''' 
				'
		-- SELECT @SQL AS SQL
		EXEC(@sql)
		
		UPDATE #outCols SET process_flag = 1 WHERE column_name = @column_name
	END	
	UPDATE #outCols SET process_flag = 0

	UPDATE #outRows SET process_flag = 1 WHERE row_name = @row_name
END		

	-- Output:
	SELECT * FROM #CombineInfo
	
	SELECT * from #Output

-- Return Run information
    SELECT extract_id 
    FROM EQ_Extract..ExtractLog (nolock)
    WHERE date_added = @extract_datetime
    AND added_by = @usr

print 'Return Run Information, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


