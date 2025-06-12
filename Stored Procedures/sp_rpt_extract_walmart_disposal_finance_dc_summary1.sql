

CREATE PROCEDURE sp_rpt_extract_walmart_disposal_finance_dc_summary1 (
    @start_date             datetime,
    @end_date               datetime
)
AS
/* ***********************************************************
Procedure    : sp_rpt_extract_walmart_disposal_finance_dc_summary1
Database     : PLT_AI
Created      : Jan 25 2008 - Jonathan Broome
Description  : Creates a Wal-Mart Disposal Extract

Examples:
    sp_rpt_extract_walmart_disposal_finance_dc_summary1 '1/1/2009 00:00', '1/31/2009 23:59'
    sp_rpt_extract_walmart_disposal_finance_dc_summary1 '3/1/2009 00:00', '3/30/2009 23:59'
    sp_rpt_extract_walmart_disposal_finance_dc_summary1 '1/1/2010 00:00', '1/31/2010 23:59'
    sp_rpt_extract_walmart_disposal_finance_dc_summary1 '8/1/2010', '8/31/2010'
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
		1. sp_rpt_extract_walmart_disposal_finance_dc_summary1 created from sp_rpt_extract_walmart_disposal
		2. Logic: Use the existing disposal extract logic to get weights
			Then create a separate temp table of financials
			Mash them together in a non-duplicative sum way.
		3. Will have to remove some limits from the disposal extract (only certain waste codes/approvals/bill projects etc)
		
	6/1/2011 - JPB
		1. per brie, change avg_invoice formula from average of grand total by invoice count to grand total divided by store count.
			OLD:	avg_invoice = round( grand_total_amt / invoice_count, 2)
			NEW:	avg_invoice = round( grand_total_amt / store_count, 2)

	8/10/2011 - JPB
		1. Copied from sp_rpt_extract_walmart_disposal_finance
		2. Removed @output_mode variable, not used.
		3. Revised output to match these WM-requested fields (Summary1):
			Store #	
			Store Type	
			State	
			Frequency	
			Service Date	
			Invoice #	
			Stop Fee	
			Disposal	
			Labor	
			Supply	
			Tax	
			Total Invoice
			
	8/31/2011 - JPB
	  one-off copy for DC Finance Extracts

		
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
    @sp_name_args           = object_name(@@PROCID) + ' ''' + convert(varchar(20), @start_date) + ''', ''' + convert(varchar(20), @end_date) + ''''


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
INSERT #Customer select convert(int, row) from dbo.fn_SplitXsvText(',', 1, '12650')

CREATE TABLE #BillingProject (
	customer_id			int,
	billing_project_id	int
)
INSERT #BillingProject
SELECT cb.customer_id, cb.billing_project_id
FROM CustomerBilling cb (nolock)
INNER JOIN #Customer c
	ON cb.customer_id = c.customer_id
/*	
WHERE cb.billing_project_id IN (
--	SELECT convert(int, row) from dbo.fn_SplitXsvText(' ', 1, '688 714 725 736 748 758 768 778 788 801 3231 742 689 715 726 737 749 759 769 779 789 811 1635 24 690 716 727 739 750 760 770 780 790 813 1650 3996 691 717 728 740 751 761 771 781 793 818 1684 3997 698 718 729 741 752 762 772 782 794 824 1772  701 719 730 743 753 763 773 783 795 835 1823  704 720 731 744 754 764 774 784 796 840 1826  706 721 732 745 755 765 775 785 797 1050 1834  707 723 733 746 756 766 776 786 798 1053 1858  710 724 734 747 757 767 777 787 799 1622 1893')
	SELECT convert(int, row) from dbo.fn_SplitXsvText(' ', 1, '24') where @start_date between '1/1/2010' and '12/31/2010 23:59' and len(ltrim(isnull(row, ''))) > 0 -- Bucket Program 2010
	union all
	SELECT convert(int, row) from dbo.fn_SplitXsvText(' ', 1, '3996 3997') where @start_date between '1/1/2011' and '12/31/2011 23:59' and len(ltrim(isnull(row, ''))) > 0 -- Bucket Program 2011
-- / *
--	union all
	SELECT convert(int, row) from dbo.fn_SplitXsvText(' ', 1, '3636') where @start_date between '1/1/2010' and '12/31/2010 23:59' and len(ltrim(isnull(row, ''))) > 0 -- Pharmacy Program 2010
	union all
	SELECT convert(int, row) from dbo.fn_SplitXsvText(' ', 1, '3998 3999') where @start_date between '1/1/2011' and '12/31/2011 23:59' and len(ltrim(isnull(row, ''))) > 0 -- Pharmacy Program 2011
-- * /
)
*/

-- Create table to store important site types for this query (saves on update/retype issues)
CREATE TABLE #SiteTypeToInclude (
    site_type       varchar(40)
)
-- Load #SiteTypeToInclude table values:
	INSERT #SiteTypeToInclude
/*	
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
*/		
 		SELECT 'Wal-Mart PMDC'
		UNION SELECT 'Sams DC'
		UNION SELECT 'Wal-Mart DC'


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
		and added_by = @usr
		and date_added = @extract_datetime
	)


print 'WO non-disposal records finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()



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
	and e.added_by = @usr
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
				convert(numeric(6,1),
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
				convert(numeric(6,1),
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
				convert(numeric(6,1),
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
				convert(numeric(6,1),
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
					convert(numeric(6,1),
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
					convert(numeric(6,1),
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
		convert(numeric(6,1),
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
  inner join profilequoteapproval pro  (nolock)
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

--
-- Deleted from this space:
--  a lot of validation/output routines that were commented out in this version anyway.
--

-- Finance version DOES care about FINANCE output(ahem)

create table #FinanceInfo (
	company_id		int,
	profit_ctr_id	int,
	receipt_id		int,
	trans_source	char(1),
	generator_id	int,
	site_code		varchar(16),
	site_type		varchar(40),
	generator_state	varchar(2),
	frequency		int,
	shipment_date	datetime,
	invoice_code	varchar(40),
	stop_amt		money,
	disposal_amt	money,
	labor_amt		money,
	supply_amt		money,
	tax_amt			money,
	total_amt		money
)

insert #FinanceInfo
select
	b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.trans_source
	, b.generator_id
	, g.site_code
	, g.site_type
	, g.generator_state
	, 30 -- hard coded frequency per Brie
	, null as shipment_date
	, b.invoice_code
	
	, SUM(
		CASE WHEN b.trans_source = 'W' and b.workorder_resource_item = 'STOPFEE'
			THEN case when bd.billing_type like '%tax%' then 0 else bd.extended_amt end
			ELSE 0
		END
	 ) as stop_amt
	
	, SUM(
		CASE WHEN (b.trans_source = 'R' OR (b.trans_source = 'W' and b.workorder_resource_type = 'D') OR rcd.category = 'Disposal') 
			THEN case when bd.billing_type like '%tax%' then 0 else bd.extended_amt end
			ELSE 0
		END
	 ) as disposal_amt

	, SUM(
		CASE WHEN b.trans_source = 'W' and b.workorder_resource_type = 'L' 
			THEN case when bd.billing_type like '%tax%' then 0 else bd.extended_amt end
			ELSE 0
		END
	 ) as labor_amt

	, SUM(
		CASE WHEN b.trans_source = 'W' and b.workorder_resource_type = 'S' 
			THEN case when bd.billing_type like '%tax%' then 0 else bd.extended_amt end
			ELSE 0
		END
	 ) as supply_amt
	 
	, SUM(
		case when bd.billing_type like '%tax%' then bd.extended_amt else 0 end 
	 ) as tax_amt
	 
	, sum(bd.extended_amt) as total_amt
	
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
		and t.added_by = @usr
		and t.date_added = @extract_datetime
	) 
GROUP BY
	b.company_id
	, b.profit_ctr_id
	, b.receipt_id
	, b.trans_source
	, b.generator_id
	, g.site_code
	, g.site_type
	, g.generator_state
--	, 30 -- hard coded frequency per Brie
--	, null as shipment_date
	, b.invoice_code


UPDATE #FinanceInfo SET
	shipment_date = t.service_date
--	period_year = datepart(yyyy, t.service_date),
--	period_month = datepart(m, t.service_date)
FROM #FinanceInfo f
INNER JOIN EQ_Temp..WalmartDisposalExtract t (nolock)
	ON f.receipt_id = t.receipt_id
	and f.company_id = t.company_id
	and F.profit_ctr_id = t.profit_ctr_id
	and f.trans_source = left(t.source_table, 1)
	and t.date_added=@extract_datetime
	and t.added_by=@usr

--
-- Disposal+Finance extract had a #CombineInfo table section here that summed by store type
-- and calculated averages, sums, etc.... Not what this extract is for, so out it goes.
--

-- Data complete:

--
-- Disposal+Finance extract had an output manipulator section here that turned #CombineInfo rows
-- into output columns... Not what this extract is for, so out it goes.
--

-- Output:

select
	site_code		
	, site_type		
	, generator_state	
	, frequency		
	, convert(varchar(10), shipment_date, 121) as shipment_date
	, invoice_code	
	, sum(stop_amt) as stop_amt
	, sum(disposal_amt) as disposal_amt
	, sum(labor_amt)	as labor_amt
	, sum(supply_amt)		as supply_amt
	, sum(tax_amt)			as tax_amt			
	, sum(total_amt)		as total_amt		
from #FinanceInfo
group by
	site_code		
	, site_type		
	, generator_state	
	, frequency		
	, convert(varchar(10), shipment_date, 121)	
	, invoice_code	
order by 
	generator_state, 
	site_code


print 'Return Run Information, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()


