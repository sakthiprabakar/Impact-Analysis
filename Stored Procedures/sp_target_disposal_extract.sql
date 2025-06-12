
create proc sp_target_disposal_extract (
	@start_date		datetime
	,@end_date		datetime
	,@report_log_id int = NULL
) AS
/* ******************************************************************
sp_target_disposal_extract

	Created to satisfy Target (12113) requirements for monthly data
	formatted to their spec.
	
	Similar to (orig copied from, then modified)
	L:\IT Apps\SQL\Special Manual Requests\Target\Extract SC, 4-1 - 5-31-2012\
	
History:
	2012-10-10	JPB	Created
	
Samples:
	sp_target_disposal_extract  '11/28/2012', '12/18/2012 23:59'

select * from receipt where receipt_id = 886941 and company_id = 21 and line_id = 5

Old Notes (from orig code, copied here):

	Target 2012 (OK, SC) Disposal Extract
	According to Tracy we're not concerned at all with Workorder Disposal.
	Beware if copying... Duplicating Line_Weight if there's more than 1 Billing Record.
	Does not seem to happen in Targets dataset.
	
2012-12-21 JPB	Tracy Eckel "We run by invoice date, not pickup date".

2013-04-26 JPB	GEM-24866
	We would also like to request changes in the programming... 

	1)  The last column on the report (final_management_code) needs to be changed.  
		The spreadsheet for each service description and what the final code should be is attached. 
		
			The Final Management Code is supposedly the 3rd party disposal's management code, not EQ's
			and they gave a table of values to use per Target Service Description - which we keep in TargetServiceDescription
			Can just add a column for final_management_code and update it like I do the TSD's based on the approval_desc.

	2)  All "additional charge due to load minimum" lines are not getting combined on the extract correctly.  
		The container count (column I) and the total weight (column J) should theoretically be zero, so 
		they don't need to be combined.  However, the additional charge (column N - disposal cost) should 
		be added to the correct approval (to give us the "total disposal cost"), and this is currently not 
		happening.  An example spreadsheet is attached.  This needs to be corrected so the extract matches 
		the invoice.
			JPB: The invoice for receipt 908021 in 21-0 includes the LMIN line that this extract does not
				TE wants the extract line charges (not weights or counts) from LMIN lines combined with these disposal lines.
				
	3)  The vendor number and cost center need to be changed in the programing.  I have attached a 
		spreadsheet with the current value and what it needs to be changed to.
			JPB: 
				Spec says change vendor from 18374 -> 183741.  Code already defined it as 183741, but 
				in a varchar 8 field with too many leading 0's.
				Spec says change cost_center from 26020003 to 00000000. Code is currently 2602 + site_code.
					Changed to 00000000

	9/24/2013 - JPB
			TX Waste Code changes - added waste_code_uid and tsdf_state to the #Waste_Cdoes table so we can filter out
			state waste codes that  don't belong to the generator/tsdf states.  Converted joins to use _uid
	 2014-08-22 JPB	- GEM:-29706 - Modify Validations: ___ Not-Submitted only true if > $0
		

sp_target_disposal_extract  '12/1/2013', '12/24/2013 23:59'

select * from receipt where receipt_id = 908021 and company_id = 21 order by approval_code
		001 Aerosols					1	30
		002 Batteries, Dry				1	3
		004 Corrosive Liquids - Acidic	1	19
		005 Corrosive Liquids - Basic	1	22
		009 Flammable Liquids			1	10
		013 Hazardous Waste, Solid		1	3
		019 Oxidizing Liquid			1	25
		021 Oxidizing Solid				1	9
		026 State-Regulated Waste Only	1	435
		031 Pharmaceutical				1	7.9
		032 Pharmaceutical P-Listed		1	0.2
		032 Pharmaceutical P-Listed		1	0.9

select * from billing where receipt_id = 908021 and company_id = 21 order by approval_code


SELECT * FROM profile where profile_id = 333139


****************************************************************** */

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

declare @customer_id int = 12113
	,@vendor_number	varchar(8) = '00183741'
	,@account_number varchar(6) = '657070' -- pull by site type from spreadsheet

-- Fix/Set EndDate's time.
if isnull(@end_date,'') <> ''
	if datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999

-- Define extract values:
DECLARE
    @extract_datetime       datetime,
    @usr                    nvarchar(256),
    @sp_name_args           varchar(1000),
    @timer					    datetime = getdate(),
    @steptimer				    datetime = getdate(),
    @extract_id             int,
    @debug                  int
SELECT
    @extract_datetime       = GETDATE(),
    @usr                    = UPPER(SUSER_SNAME()),
    @sp_name_args           = object_name(@@PROCID) + ' ''' + convert(varchar(20), @start_date) + ''', ''' + convert(varchar(20), @end_date) + '''',
    @debug                  = 1
    
if @report_log_id is not null and len(@usr) > 10
   select @usr = user_code from reportlog where report_log_id = @report_log_id

if @debug > 0 begin
   Print 'Extract started at ' + convert(varchar(40), @timer)
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()


CREATE TABLE #Customer (
	customer_id 	int
)
INSERT #Customer values (@customer_id)


IF RIGHT(@usr, 3) = '(2)'
    SELECT @usr = LEFT(@usr,(LEN(@usr)-3))


if @debug > 0 begin
   print 'Log Run Information'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
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
        'Target Disposal',
        @sp_name_args,
        GETDATE(),
        null,
        null,
        null,
        @extract_datetime,
        @usr
    )
    select @extract_id = @@IDENTITY

-- EQ_Temp table housekeeping
-- Deletes temp data more than 2 days old, or by this user (past runs)
DELETE FROM EQ_TEMP.dbo.TargetDisposalExtract where added_by = @usr and date_added = @extract_datetime
DELETE FROM EQ_TEMP.dbo.TargetDisposalValidation where added_by = @usr and date_added = @extract_datetime

if @debug > 0 begin
   print 'Run Setup Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
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

-- Work Orders using TSDFApprovals

INSERT EQ_Temp..TargetDisposalExtract
SELECT DISTINCT
    @vendor_number	as vendor_number,
    g.site_code AS site_code,
    gst.generator_site_type_abbr AS site_type_abbr,
    g.generator_city AS generator_city,
    g.generator_state AS generator_state,
   	coalesce(wos.date_act_arrive, w.start_date) as service_date,
    g.epa_id AS epa_id,
   	w.purchase_order as purchase_order,
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
	case when g.site_type like '%Target DC%' then '7050290' else
		case when g.site_type like '%Target Store%' then '7050310' else
			'7050310' -- default to store when we can't tell, per Tracy En.
		end
	end as account_number,
	'00000000' as cost_center, -- '2602' + ISNULL(g.site_code, '----') as cost_center,
	
	coalesce(SDM.service_description, 'FAIL! No Service Description for this TSDF Approval desc: ' + isnull(t.waste_desc, '')),
	
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
    @extract_datetime,
    (
		select sum(isnull(bd.extended_amt, 0)) 
		+ isnull((
			select sum(isnull(bd2.extended_amt, 0)) 
			from billing b2
			inner join billingdetail bd2 on b2.billing_uid = bd2.billing_uid
			where b2.receipt_id = b.receipt_id
			and b2.company_id = b.company_id
			and b2.profit_ctr_id = b.profit_ctr_id
			and b2.trans_source = b.trans_source
			and b2.ref_line_id = b.line_id
			and b2.waste_code = 'LMIN'
			AND b2.trans_type = 'S'
		 ),0)
		from billing b 
		inner join billingdetail bd on b.billing_uid = bd.billing_uid
		where b.billing_uid = bi.billing_uid
			group by
			b.receipt_id,
			b.company_id,
			b.profit_ctr_id,
			b.trans_source,
			b.line_id
    ) as billing_amt
FROM WorkOrderHeader w (nolock) 
INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
INNER JOIN Generator g  (nolock) ON w.generator_id = g.generator_id
INNER JOIN billing bi (nolock)
	on w.workorder_id = bi.receipt_id
	and d.resource_type = bi.workorder_resource_type
	and d.sequence_id = bi.workorder_sequence_id
	and d.company_id = bi.company_id
	and d.profit_ctr_id = bi.profit_ctr_id
	and bi.status_code = 'I'
	and bi.trans_source = 'W'
LEFT OUTER JOIN workorderdetailunit u (nolock) on d.workorder_id = u.workorder_id and d.sequence_id = u.sequence_id and d.company_id = u.company_id and d.profit_ctr_id = u.profit_ctr_id and u.billing_flag = 'T'
LEFT OUTER JOIN BillUnit b  (nolock) ON isnull(u.bill_unit_code, d.bill_unit_code) = b.bill_unit_code
LEFT OUTER JOIN TSDFApproval t  (nolock) ON d.tsdf_approval_id = t.tsdf_approval_id
    AND d.company_id = t.company_id
    AND d.profit_ctr_id = t.profit_ctr_id
LEFT OUTER JOIN TSDF t2  (nolock) ON d.tsdf_code = t2.tsdf_code
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
LEFT OUTER JOIN WorkOrderTransporter wot1 (nolock) ON w.workorder_id = wot1.workorder_id and w.company_id = wot1.company_id and w.profit_ctr_id = wot1.profit_ctr_id and d.manifest = wot1.manifest and wot1.transporter_sequence_id = 1
LEFT OUTER JOIN WorkOrderTransporter wot2 (nolock) ON w.workorder_id = wot2.workorder_id and w.company_id = wot2.company_id and w.profit_ctr_id = wot2.profit_ctr_id and d.manifest = wot2.manifest and wot2.transporter_sequence_id = 2
LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = w.workorder_id
	and wos.company_id = w.company_id
	and wos.profit_ctr_id = w.profit_ctr_id
	and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
LEFT OUTER JOIN TargetServiceDescription SDM on t.waste_desc = SDM.approval_desc
WHERE 1=1
AND (w.customer_id IN (select customer_id from #Customer)
    OR w.generator_id IN (SELECT generator_id FROM customergenerator  (nolock) WHERE customer_id IN (select customer_id from #Customer))
)
AND bi.invoice_date BETWEEN @start_date AND @end_date
AND ISNULL(t2.eq_flag, 'F') = 'F'
AND d.resource_type = 'D'
AND w.workorder_status IN ('A','C','D','N','P' /*,'X' */)
AND d.bill_rate NOT IN (-2)

if @debug > 0 begin
   print '3rd party WOs Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()



--  PRINT 'Receipt/Transporter Fix'
/*

12/7/2010 - The primary source for EQ data is the Receipt table.
	It's out of order in the select logic below and needs to be reviewed/revised
	because it's misleading.
	
This query has 2 union'd components:
first component: workorder inner join to billinglinklookup and receipt
third component: receipt not linked to BLL

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
        CASE WHEN rt1.transporter_code IS NULL THEN
            r.hauler
        ELSE
            rt1.transporter_code 
        END as transporter1,
        rt2.transporter_code as transporter2,
        @usr as added_by,
        @extract_datetime as date_added
    INTO #ReceiptTransporter     
    from workorderheader wo (nolock) 
	INNER JOIN billing b (nolock)
		on wo.workorder_id = b.receipt_id
		and wo.company_id = b.company_id
		and wo.profit_ctr_id = b.profit_ctr_id
		and b.status_code = 'I'
		and b.trans_source = 'W'
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
        b.invoice_date between @start_date AND @end_date
        and (1=0
            or wo.customer_id IN (select customer_id from #Customer)
            or wo.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from #Customer))
            or r.customer_id IN (select customer_id from #Customer)
            or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from #Customer))
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
	INNER JOIN billing b (nolock)
		on r.receipt_id = b.receipt_id
		and r.company_id = b.company_id
		and r.profit_ctr_id = b.profit_ctr_id
		and r.line_id = b.line_id
		and b.status_code = 'I'
		and b.trans_source = 'W'
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
        coalesce(b.invoice_date, rt1.transporter_sign_date, r.receipt_date) between @start_date AND @end_date
        and (r.customer_id IN (select customer_id from #Customer)
            or r.generator_id in (select generator_id from customergenerator  (nolock) where customer_id IN (select customer_id from #Customer))
        )
        and not exists (
            select receipt_id from billinglinklookup bll (nolock) 
            where bll.company_id = r.company_id
            and bll.profit_ctr_id = r.profit_ctr_id
            and bll.receipt_id = r.receipt_id
        )

if @debug > 0 begin
   print 'Receipt/Transporter Population Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Fix #ReceiptTransporter records...
    --  PRINT 'Can''t allow null transporter1 and populated transporter2, so move the data to transporter1 field.'
        UPDATE #ReceiptTransporter set transporter1 = transporter2
        WHERE ISNULL(transporter1, '') = '' and ISNULL(transporter2, '') <> ''
        AND added_by = @usr and date_added = @extract_datetime

    --  PRINT 'Can''t have the same transporter for both fields.'
        UPDATE #ReceiptTransporter set transporter2 = null
        WHERE transporter2 = transporter1
        AND added_by = @usr and date_added = @extract_datetime

if @debug > 0 begin
   print 'Receipt/Transporter Transporter Updates Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Receipts
INSERT EQ_TEMP.dbo.TargetDisposalExtract
SELECT distinct
    -- Customer Fields:
    @vendor_number as vendor_number,
    g.site_code AS site_code,
    gst.generator_site_type_abbr AS site_type_abbr,
    g.generator_city AS generator_city,
    g.generator_state AS generator_state,
    wrt.service_date,
    g.epa_id,
    r.purchase_order,
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
	case when g.site_type like '%Target DC%' then '7050290' else
		case when g.site_type like '%Target Store%' then '7050310' else
			'7050310' -- default to store when we can't tell, per Tracy En.
		end
	end as account_number,
	'00000000' as cost_center, -- '2602' + ISNULL(g.site_code, '----') as cost_center,
	
	coalesce(SDM.service_description, 'FAIL! No Service Description for this EQ Approval desc: ' + isnull(p.approval_desc, '')),

	r.line_weight as pounds, 
    b.bill_unit_desc AS bill_unit_desc,
    (
		select ISNULL(max(rp2.bill_quantity), 0)
		FROM ReceiptPrice rp2  (nolock) WHERE
		R.receipt_id = rp2.receipt_id
		and r.line_id = rp2.line_id
		and r.company_id = rp2.company_id
		and r.profit_ctr_id = rp2.profit_ctr_id
    ) AS quantity,
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
	null, -- dbo.fn_receipt_waste_code_list_state(r.company_id, r.profit_ctr_id, r.receipt_id, r.line_id) AS state_waste_codes,
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
    @extract_datetime as date_added,
    (
		select sum(isnull(bd.extended_amt, 0)) 
		+ isnull((
			select sum(isnull(bd2.extended_amt, 0)) 
			from billing b2
			inner join billingdetail bd2 on b2.billing_uid = bd2.billing_uid
			where b2.receipt_id = b.receipt_id
			and b2.company_id = b.company_id
			and b2.profit_ctr_id = b.profit_ctr_id
			and b2.trans_source = b.trans_source
			and b2.ref_line_id = b.line_id
			and b2.waste_code = 'LMIN'
			AND b2.trans_type = 'S'
		 ),0)
		from billing b 
		inner join billingdetail bd on b.billing_uid = bd.billing_uid
		where b.billing_uid = bi.billing_uid
			group by
			b.receipt_id,
			b.company_id,
			b.profit_ctr_id,
			b.trans_source,
			b.line_id
    ) as billing_amt    
FROM Receipt r (nolock) 
INNER JOIN ReceiptPrice rp  (nolock) ON
    R.receipt_id = rp.receipt_id
    and r.line_id = rp.line_id
    and r.company_id = rp.company_id
    and r.profit_ctr_id = rp.profit_ctr_id
INNER JOIN Generator g  (nolock) ON r.generator_id = g.generator_id
INNER JOIN BillUnit b  (nolock) ON rp.bill_unit_code = b.bill_unit_code
INNER JOIN #ReceiptTransporter wrt ON
    r.company_id = wrt.company_id
    and r.profit_ctr_id = wrt.profit_ctr_id
    and r.receipt_id = wrt.receipt_id
    and r.line_id = wrt.line_id
	AND wrt.added_by = @usr
	AND wrt.date_added = @extract_datetime
INNER JOIN ProfitCenter pr (nolock) on r.company_id = pr.company_id and r.profit_ctr_id = pr.profit_ctr_id
LEFT OUTER JOIN Profile p  (nolock) ON r.profile_id = p.profile_id
LEFT OUTER JOIN Treatment tr  (nolock) ON r.treatment_id = tr.treatment_id
LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
LEFT OUTER JOIN ProfileQuoteApproval pqa  (nolock)
    on r.profile_id = pqa.profile_id 
    and r.company_id = pqa.company_id 
    and r.profit_ctr_id = pqa.profit_ctr_id 
LEFT OUTER JOIN TargetServiceDescription SDM on p.approval_desc = SDM.approval_desc
left outer join billing bi on
	bi.trans_source = 'R' and bi.receipt_id = r.receipt_id and bi.company_id = r.company_id
    and bi.profit_ctr_id = r.profit_ctr_id and bi.line_id = r.line_id and bi.price_id = rp.price_id and bi.status_code = 'I'

WHERE r.receipt_status = 'A'
AND r.fingerpr_status = 'A'
AND ISNULL(r.trans_type, '') = 'D'
AND r.trans_mode = 'I'


if @debug > 0 begin
   print 'Receipts Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

/*
-- set pricing on receipt records
update EQ_TEMP.dbo.TargetDisposalExtract
    set billing_amt = (select sum(extended_amt) from billingdetail bd where b.billing_uid = bd.billing_uid) 
FROM EQ_TEMP.dbo.TargetDisposalExtract t
INNER JOIN Receipt r (nolock) 
	ON t.source_table = 'Receipt'
	and t.receipt_id = r.receipt_id 
	and t.line_sequence_id = r.line_id
	and t.company_id = r.company_id
	and t.profit_ctr_id = r.profit_ctr_id
INNER JOIN ReceiptPrice rp  (nolock) ON
    R.receipt_id = rp.receipt_id
    and r.line_id = rp.line_id
    and r.company_id = rp.company_id
    and r.profit_ctr_id = rp.profit_ctr_id
inner join billing b on 
	b.trans_source = 'R' and b.status_code = 'I'
	and r.receipt_id = b.receipt_id
	and r.company_id = b.company_id
	and r.profit_ctr_id = b.profit_ctr_id
	and r.line_id = b.line_id
	and rp.price_id = b.price_id
where t.date_added = @extract_datetime
	and t.added_by = @usr
*/

-- No-Waste Pickup Records:
INSERT EQ_TEMP.dbo.TargetDisposalExtract
	SELECT DISTINCT
	@vendor_number as vendor_number,
	g.site_code AS site_code,
	gst.generator_site_type_abbr AS site_type_abbr,
	g.generator_city AS generator_city,
	g.generator_state AS generator_state,
	w.start_date AS service_date,
	g.epa_id AS epa_id,
	w.purchase_order,
	null AS manifest,
	1 AS manifest_line,
	case when g.site_type like '%Target DC%' then '7050290' else
		case when g.site_type like '%Target Store%' then '7050310' else
			'7050310' -- default to store when we can't tell, per Tracy En.
		end
	end as account_number,
	'00000000' as cost_center, -- '2602' + ISNULL(g.site_code, '----') as cost_center,
	
	-- Service Description
	--  Target gave a specific list of values to use here. That was translated to the table TargetServiceDescription.
	--  But there's other cases too: Stop Fee & Service Decline.  Therefore...
	CASE WHEN wos.decline_id = 1 then 'Stop Fee' else
		CASE WHEN wos.decline_id = 3 then 'Onsite Service Decline' else
			CASE WHEN wos.decline_id = 2 then 'Service Decline' else
				'?? Unknown stop fee condition ?? '
			END
		END
	END as service_description,

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
	@extract_datetime as date_added,
    (
		select sum(isnull(bd.extended_amt, 0)) 
		+ isnull((
			select sum(isnull(bd2.extended_amt, 0)) 
			from billing b2
			inner join billingdetail bd2 on b2.billing_uid = bd2.billing_uid
			where b2.receipt_id = b.receipt_id
			and b2.company_id = b.company_id
			and b2.profit_ctr_id = b.profit_ctr_id
			and b2.trans_source = b.trans_source
			and b2.ref_line_id = b.line_id
			and b2.waste_code = 'LMIN'
			AND b2.trans_type = 'S'
		 ),0)
		from billing b 
		inner join billingdetail bd on b.billing_uid = bd.billing_uid
		where b.billing_uid = bi.billing_uid
			group by
			b.receipt_id,
			b.company_id,
			b.profit_ctr_id,
			b.trans_source,
			b.line_id
    ) as billing_amt	 
	FROM WorkOrderHeader w (nolock) 
	INNER JOIN WorkOrderDetail d  (nolock) ON w.workorder_id = d.workorder_id and w.company_id = d.company_id and w.profit_ctr_id = d.profit_ctr_id
	INNER JOIN billing bi (nolock)
		on w.workorder_id = bi.receipt_id
		and d.resource_type = bi.workorder_resource_type
		and d.sequence_id = bi.workorder_sequence_id
		and d.company_id = bi.company_id
		and d.profit_ctr_id = bi.profit_ctr_id
		and bi.status_code = 'I'
		and bi.trans_source = 'W'
	INNER JOIN Generator g  (nolock) ON w.generator_id = g.generator_id
    LEFT OUTER JOIN GeneratorSiteType gst  (nolock) ON g.site_type = gst.generator_site_type
    LEFT OUTER JOIN WorkOrderStop wos (nolock) ON w.workorder_id = wos.workorder_id and w.company_id = wos.company_id and w.profit_ctr_id = wos.profit_ctr_id 
    	and wos.stop_sequence_id = 1
	WHERE 1=1
	AND (w.customer_id IN (select customer_id from #Customer)
	    OR w.generator_id IN (SELECT generator_id FROM customergenerator  (nolock) WHERE customer_id IN (select customer_id from #Customer))
	)
	AND bi.invoice_date BETWEEN @start_date AND @end_date
	AND w.submitted_flag = 'T'
	AND w.workorder_status IN ('A','C','D','N','P','X')
	AND d.bill_rate NOT IN (-2)
	AND d.resource_class_code = 'STOPFEE'
--	AND wos.decline_id > 1

if @debug > 0 begin
   print 'No Waste Pickup records finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()


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
		INNER JOIN EQ_TEMP.dbo.TargetDisposalExtract e (nolock)
			on e.tsdf_approval_id = xwc.tsdf_approval_id
	WHERE e.source_table = 'Workorder'
		and e.submitted_flag = 'T'
		AND xwc.primary_flag = 'T'
		AND wc.waste_code_origin in ('F', 'S')
		AND e.added_by = @usr
		AND e.date_added = @extract_datetime

if @debug > 0 begin
   print 'Workorder Waste Codes (1), Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

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
		INNER JOIN EQ_TEMP.dbo.TargetDisposalExtract e (nolock)
			on e.tsdf_approval_id = xwc.tsdf_approval_id
	WHERE e.source_table = 'Workorder'
		and e.submitted_flag = 'T'
		AND wc.waste_code_origin in ('F', 'S')
		and wc.display_name not in (select waste_code from #Waste_Codes
			where source = e.source_table 
			and tsdf_approval_id = xwc.tsdf_approval_id 
			)
		AND e.added_by = @usr
		AND e.date_added = @extract_datetime
	ORDER BY wc.display_name

if @debug > 0 begin
   print 'Workorder Waste Codes (2+), Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Receipt Waste Codes (1)
	insert #Waste_Codes (source, receipt_id, line_id, company_id, profit_ctr_id, sequence_id, origin, generator_state, waste_code_state, waste_code, waste_code_uid, tsdf_state)
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
	INNER JOIN EQ_TEMP.dbo.TargetDisposalExtract e (nolock)
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

if @debug > 0 begin
   print 'Receipt Waste Codes (1), Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end 
set @steptimer = getdate()

-- Receipt Waste Codes (2+)
	insert #Waste_Codes (source, receipt_id, line_id, company_id, profit_ctr_id, sequence_id, origin, generator_state, waste_code_state, waste_code, waste_code_uid, tsdf_state)
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
	INNER JOIN EQ_TEMP.dbo.TargetDisposalExtract e (nolock)
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
		AND e.added_by = @usr
		AND e.date_added = @extract_datetime
	ORDER BY wc.display_name

if @debug > 0 begin
   print 'Workorder Waste Codes (1), Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

/*
THESE WERE FROM WM, not sure Target needs them:

-- Don't include UNIV
delete from #Waste_Codes where waste_code = 'UNIV'

-- Don't include NONE
delete from #Waste_Codes where waste_code = 'NONE'

-- Don't include .
delete from #Waste_Codes where waste_code = '.'
*/

-- Omit state waste codes that don't belong to the generator state or tsdf state (9/10/2013)
delete from #Waste_Codes from #Waste_Codes w
inner join WasteCode wc on w.waste_code_uid = wc.waste_code_uid
where w.origin = 'S' and wc.state not in (w.generator_state, w.tsdf_state)


if @debug > 0 begin
   print 'Waste Code Cleanup, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

/* ********************************************
12/15/2011 modification - JPB per Brie, LT, WM: Waste codes should be listed alphabetically, with P codes first
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



-- Update fields left null in #Extract
UPDATE EQ_TEMP.dbo.TargetDisposalExtract set
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
	EQ_TEMP.dbo.TargetDisposalExtract e (nolock)
	left outer join Transporter t1 (nolock)
		on e.transporter1_code = t1.transporter_code
	left outer join Transporter t2 (nolock)
		on e.transporter2_code = t2.transporter_code
WHERE e.added_by = @usr AND e.date_added = @extract_datetime and e.submitted_flag = 'T'

if @debug > 0 begin
   print 'Update fields left null (dot, trans), Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

		
-- Update Waste Codes for WOs		
UPDATE EQ_TEMP.dbo.TargetDisposalExtract set
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
	EQ_TEMP.dbo.TargetDisposalExtract e (nolock)
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
and e.added_by = @usr AND e.date_added = @extract_datetime and e.submitted_flag = 'T'

if @debug > 0 begin
   print 'Update fields left null (WO waste codes), Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Update Waste Codes for Receipts
UPDATE EQ_TEMP.dbo.TargetDisposalExtract set
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
	EQ_TEMP.dbo.TargetDisposalExtract e (nolock)
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
WHERE e.source_table = 'Receipt' and e.added_by = @usr AND e.date_added = @extract_datetime and e.submitted_flag = 'T'

if @debug > 0 begin
   print 'Update fields left null (R waste codes), Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

/*
Texas waste codes are 8 digits, and wouldn't fit into the wastecode table's waste_code field.
BUT, the waste_code field on those records is unique, so EQ systems handle it correctly, but we
need to remember to update the extract to swap the waste_description (the TX 8 digit code) for
the waste_code for waste_codes that are from TX.
UPDATE EQ_TEMP.dbo.TargetDisposalExtract SET state_waste_code_1 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_1 = wc.waste_code AND EQ_TEMP.dbo.TargetDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.TargetDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.TargetDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.TargetDisposalExtract SET state_waste_code_2 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_2 = wc.waste_code AND EQ_TEMP.dbo.TargetDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.TargetDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.TargetDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.TargetDisposalExtract SET state_waste_code_3 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_3 = wc.waste_code AND EQ_TEMP.dbo.TargetDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.TargetDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.TargetDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.TargetDisposalExtract SET state_waste_code_4 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_4 = wc.waste_code AND EQ_TEMP.dbo.TargetDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.TargetDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.TargetDisposalExtract.submitted_flag = 'T'
UPDATE EQ_TEMP.dbo.TargetDisposalExtract SET state_waste_code_5 = left(wc.waste_code_desc, 8) from wastecode wc (nolock) where waste_code_origin = 'S' AND wc.state = 'TX' and state_waste_code_5 = wc.waste_code AND EQ_TEMP.dbo.TargetDisposalExtract.added_by = @usr AND EQ_TEMP.dbo.TargetDisposalExtract.date_added = @extract_datetime and EQ_TEMP.dbo.TargetDisposalExtract.submitted_flag = 'T'

if @debug > 0 begin
   print 'Texas Waste Code Updates, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()
*/


-- EQ_TEMP.dbo.TargetDisposalExtract is finished now.

if @debug > 0 begin
   print 'Copy current run to new instance summing quantity, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
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

-- Create list of missing transporter info
    INSERT EQ_Extract..TargetDisposalValidation
    SELECT  DISTINCT
    	'Missing Transporter Info' as Problem,
    	source_table,
    	Company_id,
    	Profit_ctr_id,
    	Receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    FROM EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    WHERE 
    	ISNULL((select transporter_name from transporter (nolock) where transporter_code = EQ_TEMP.dbo.TargetDisposalExtract.transporter1_code), '') = ''
	    AND waste_desc <> 'No waste picked up'
	    AND added_by = @usr 
	    AND date_added = @extract_datetime
	    AND submitted_flag = 'T'
    	
if @debug > 0 begin
   print 'Validation: Missing Transporter Info, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of Missing Waste Code
    INSERT EQ_Extract..TargetDisposalValidation
    SELECT DISTINCT
    	'Missing Waste Code',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract e (nolock) 
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
    from EQ_TEMP.dbo.TargetDisposalExtract e (nolock) 
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

if @debug > 0 begin
   print 'Validation: Missing Waste Codes, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of missing Weights
    INSERT EQ_Extract..TargetDisposalValidation
    SELECT DISTINCT
    	'Missing Weight',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line/seq: ' + convert(varchar(20), line_sequence_id),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
    	isnull(pounds,0) = 0
	    AND waste_desc <> 'No waste picked up'
	    and manifest_line is not null
	    and item_type in ('A', 'D')
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Missing Weights, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of missing Service Dates
    INSERT EQ_Extract..TargetDisposalValidation
    SELECT DISTINCT
    	'Missing Service Date',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
    	isnull(service_date, '') = ''
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Missing Service Dates, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of receipts missing workorders
    INSERT EQ_Extract..TargetDisposalValidation
    SELECT DISTINCT
    	'Receipt missing Workorder',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    WHERE
		source_table = 'receipt'
    	AND isnull(receipt_workorder_id, '') = ''
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Receipts Missing Workorders, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of missing site codes
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT DISTINCT
    	'Missing Generator Site Code',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
    	site_code = ''
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Missing Site Codes, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of missing site type
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT DISTINCT
    	'Missing Generator Site Type',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
    	isnull(site_type, '') = ''
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Missing Site Types, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of unsubmitted receipts
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT DISTINCT
    	'Receipt Not Submitted',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract t (nolock) 
    where
		source_table = 'Receipt'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'F'
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

if @debug > 0 begin
   print 'Validation: Unsubmitted Receipts, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of unsubmitted workorders
    INSERT EQ_Extract..TargetDisposalValidation
    SELECT DISTINCT
    	'Workorder Not Submitted',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract t (nolock) 
    where
		source_table like 'Workorder%'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'F'
	    and 0 < (
			select sum(isnull(wh.total_price, 0))
			from workorderheader wh (nolock)
			where wh.workorder_id = t.receipt_id
			and wh.company_id = t.company_id
			and wh.profit_ctr_id = t.profit_ctr_id
	    )

if @debug > 0 begin
   print 'Validation: Unsubmitted Workorders, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()


if @debug > 0 begin
   print 'Validation: Missing Scans, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create count of receipt-based records in extract
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT
    	' Count of Receipt-based records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*)),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
		source_table ='Receipt'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Receipt Record Count, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create count of workorder -based records in extract
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT 
    	' Count of Workorder-based records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*)),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
		source_table ='Workorder'
    	AND waste_desc <> 'No waste picked up'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Workorder Record Count, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create count of NWP -based records in extract
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT 
    	' Count of No Waste Pickup records',
    	null,
    	null,
    	null,
    	null,
    	convert(varchar(20), count(*)),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
		source_table ='Workorder'
    	AND waste_desc = 'No waste picked up'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: No Waste Pickup Record Count, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of unusually high number of manifest names
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT
    	'High Number of same manifest-line',
    	null,
    	null,
    	null,
    	null,
    	CONVERT(varchar(20), count(*)) + ' times: ' + isnull(manifest, '') + ' line ' + isnull(CONVERT(varchar(10), Manifest_Line), ''),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
    	waste_desc <> 'No waste picked up'
    	AND bill_unit_desc not like '%cylinder%'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
	group by manifest, manifest_line
	having count(*) > 2

if @debug > 0 begin
   print 'Validation: Count high # of Manifest-Line combo, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of missing dot descriptions
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT DISTINCT
    	'Missing DOT Description',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
	    added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'
        AND ISNULL(
            CASE WHEN EQ_TEMP.dbo.TargetDisposalExtract.tsdf_approval_id IS NOT NULL THEN
                dbo.fn_manifest_dot_description('T', EQ_TEMP.dbo.TargetDisposalExtract.tsdf_approval_id)
            ELSE
                CASE WHEN EQ_TEMP.dbo.TargetDisposalExtract.profile_id IS NOT NULL THEN
                    dbo.fn_manifest_dot_description('P', EQ_TEMP.dbo.TargetDisposalExtract.profile_id)
                ELSE
                    ''
                END
            END
        , '') = ''
	    and approval_or_resource not in ('STOPFEE', 'GASSUR%')
	    and waste_desc <> 'No waste picked up'


if @debug > 0 begin
   print 'Validation: Missing DOT Description, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()


-- Create list of missing bill units in extract
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT 
    	'Missing Bill Unit',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line ' + convert(varchar(10), line_sequence_id),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
		isnull(bill_unit_desc, '') = ''
		AND waste_desc <> 'No waste picked up'
	    AND added_by = @usr 
	    and date_added = @extract_datetime
	    AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Validation: Missing Bill Unit Description, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()


-- Create list of missing waste descriptions
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT DISTINCT
    	'Missing Waste Description',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	NULL,
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
    	waste_desc = ''
	    AND added_by = @usr 
	    AND date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    and approval_or_resource not in ('STOPFEE', 'GASSUR%')
	    and waste_desc <> 'No waste picked up'

if @debug > 0 begin
   print 'Validation: Missing Waste Description, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Create list of blank waste code 1's
    INSERT EQ_Extract..TargetDisposalValidation
     SELECT DISTINCT
    	'Blank Waste Code 1',
    	source_table,
    	company_id,
    	profit_ctr_id,
    	receipt_id,
    	'line/seq: ' + convert(varchar(20), line_sequence_id),
    	@usr,
    	@extract_datetime
    from EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
    where
    	ISNULL(waste_code_1, '') = ''
    	AND coalesce(waste_code_2, waste_code_3, waste_code_4, waste_code_5, waste_code_6, waste_code_7, waste_code_8, waste_code_9, waste_code_10, '') <> ''
	    AND added_by = @usr 
	    AND date_added = @extract_datetime
	    AND submitted_flag = 'T'
	    and waste_desc <> 'No waste picked up'

if @debug > 0 begin
   print 'Validation: Blank Waste Code 1, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- Catch generators serviced that aren't in the extracts
    INSERT EQ_Extract..TargetDisposalValidation
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
	INNER JOIN billing b (nolock)
		on woh.workorder_id = b.receipt_id
		and woh.company_id = b.company_id
		and woh.profit_ctr_id = b.profit_ctr_id
		and b.status_code = 'I'
		and b.trans_source = 'W'
	INNER join TripHeader th (nolock) ON woh.trip_id = th.trip_id
	INNER JOIN generator g (nolock) on woh.generator_id = g.generator_id
	LEFT OUTER JOIN WorkOrderStop wos (nolock) ON wos.workorder_id = woh.workorder_id
		and wos.company_id = woh.company_id
		and wos.profit_ctr_id = woh.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */
	WHERE th.trip_status IN ('D', 'C', 'A', 'U')
	AND woh.workorder_status <> 'V'
	AND (woh.customer_id IN (select customer_id from #Customer) OR woh.generator_id in (select generator_id from CustomerGenerator (nolock) where customer_id IN (select customer_id from #Customer)))
	AND coalesce(b.invoice_date, wos.date_act_arrive, woh.start_date) between @start_date and @end_date
	AND g.generator_id not in (
		select generator_id 
		from EQ_TEMP.dbo.TargetDisposalExtract  (nolock)
		where submitted_flag = 'T'
		AND added_by = @usr
		AND date_added = @extract_datetime
	)
    AND woh.billing_project_id not in (5486)


if @debug > 0 begin
   print 'Validation: Generators Serviced, but not in extracts, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()


/* *************************************************************
Populate Output tables from this run.
************************************************************* */


-- Disposal Information
if @debug > 0 begin
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

        INSERT EQ_Extract.dbo.TargetDisposalExtract (
			vendor_number ,						--	varchar(9) NULL,
			[target_location] ,					--	[varchar](4) NULL,
			[pickup_date] ,						--	[datetime] NULL,
			[workorder_id] ,					--	varchar(10) NULL,
			[manifest] ,						--	[varchar](12) NULL,
			[account_number] ,					--	varchar(7) NULL,
			[cost_center] ,						--	varchar(8) NULL,
			[service_description] ,				--	varchar(255) NULL,
			[number_of_containers] ,			--	[int] NULL,
			[total_weight] ,					--	[float] NULL,
			[federal_waste_code_1] ,			--	[varchar](4) NULL,
			[federal_waste_code_2] ,			--	[varchar](4) NULL,
			[state_waste_code_1] ,				--	[varchar](10) NULL,
			[disposal_cost]	,					--	money NULL,
			[delivery_date_at_disposal_site] ,	--	datetime NULL,
			[federal_waste_code_3] ,			--	[varchar](4) NULL,
			[federal_waste_code_4] ,			--	[varchar](4) NULL,
			[federal_waste_code_5] ,			--	[varchar](4) NULL,
			[federal_waste_code_6] ,			--	[varchar](4) NULL,
			[state_waste_code_2] ,				--	[varchar](10) NULL,
			[transporter_name_1] ,				--	[varchar](75) NULL,
			[transporter_epa_id_1] ,			--	[varchar](12) NULL,
			[transporter_name_2] ,				--	[varchar](100) NULL,
			[transporter_epa_id_2] ,			--	[varchar](12) NULL,
			[tsd_name] ,						--	[varchar](100) NULL,
			[tsd_epa_id] ,						--	[varchar](12) NULL,
			[management_code] ,					--	[varchar](4) NULL,
			[final_management_code] ,			--	[varchar](4) NULL,
			[added_by] ,						--	[varchar](10) NOT NULL,
			[date_added] 						--	[datetime] NOT NULL
        )
        SELECT
            vendor_number,
            site_code,
            service_date,
            purchase_order,
            manifest,
			account_number,
			cost_center,
			service_description,
			container_count,
			pounds,
			waste_code_1,
			waste_code_2,
			state_waste_code_1,
			billing_amt,
			date_delivered,
			waste_code_3,
			waste_code_4,
			waste_code_5,
			waste_code_6,
			state_waste_code_2,
			transporter1_name,     
			transporter1_epa_id,   
			transporter2_name,     
			transporter2_epa_id,   
			receiving_facility,
			receiving_facility_epa_id,
			management_code,
			management_code,
			@usr,
			@extract_datetime
        FROM EQ_TEMP.dbo.TargetDisposalExtract (nolock) 
        WHERE added_by = @usr and date_added = @extract_datetime
        AND submitted_flag = 'T'

if @debug > 0 begin
   print 'Output: Disposal, Finished'
   PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
   Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
end
set @steptimer = getdate()

-- 4/26/2013 - set final_management_code to values matching target service description settings.
UPDATE EQ_Extract.dbo.TargetDisposalExtract SET final_management_code = TSD.final_management_code
FROM EQ_Extract.dbo.TargetDisposalExtract e inner join TargetServiceDescription tsd
	on e.service_description = tsd.service_description
WHERE e.added_by = @usr AND e.date_added = @extract_datetime 


/*
-- Return Run information
    SELECT extract_id 
    FROM EQ_Extract..ExtractLog (nolock)
    WHERE date_added = @extract_datetime
    AND added_by = @usr
*/

declare @tmp_filename varchar(255), @tmp_desc varchar(255)



/* Early abort.  We'll build the full export sys when I have time. DOn't now.

*/

SELECT *
FROM EQ_Extract..TargetDisposalValidation
where 
	date_added = @extract_datetime 
	and added_by = @usr


SELECT
	vendor_number ,						
	[target_location] ,					
	[pickup_date] ,						
	[workorder_id] ,					
	[manifest] ,						
	[account_number] ,					
	[cost_center] ,						
	[service_description] ,				
	[number_of_containers] ,			
	[total_weight] ,					
	[federal_waste_code_1] ,			
	[federal_waste_code_2] ,			
	[state_waste_code_1] ,				
	[disposal_cost]	,					
	[delivery_date_at_disposal_site] ,	
	[federal_waste_code_3] ,			
	[federal_waste_code_4] ,			
	[federal_waste_code_5] ,			
	[federal_waste_code_6] ,			
	[state_waste_code_2] ,				
	[transporter_name_1] ,				
	[transporter_epa_id_1] ,			
	[transporter_name_2] ,				
	[transporter_epa_id_2] ,			
	[tsd_name] ,						
	[tsd_epa_id] ,						
	[management_code] ,					
	[final_management_code] 
from EQ_Extract.dbo.TargetDisposalExtract 
where 
	date_added = @extract_datetime 
	and added_by = @usr

RETURN

---------------------------------
-- Export Disposal Validation
---------------------------------

	truncate table eq_temp..sp_target_disposal_extract_1	

	insert eq_temp..sp_target_disposal_extract_1	
	SELECT
		problem,
		source,
		company_id,
		profit_ctr_id,
		receipt_id,
		extra
	FROM EQ_Extract.dbo.TargetDisposalValidation
	WHERE
		added_by = @usr
		AND date_added = @extract_datetime
	ORDER BY
		problem,
		source,
		company_id,
		profit_ctr_id,
		receipt_id,
		extra

   select @tmp_filename = 'Target Disposal Validation - ' +
   		convert(varchar(4), datepart(yyyy, @start_date)) 
   		+ '-'
   		+ right('00' + convert(varchar(2), datepart(mm, @start_date)),2)
   		+ '-'
   		+ right('00' + convert(varchar(2), datepart(dd, @start_date)),2)
   		+ '-to-'
   		+ convert(varchar(4), datepart(yyyy, @end_date)) 
   		+ '-'
   		+ right('00' + convert(varchar(2), datepart(mm, @end_date)),2)
   		+ '-'
   		+ right('00' + convert(varchar(2), datepart(dd, @end_date)),2)
   		+ ' - '
   		+ convert(varchar(10), @extract_id)
   		+ '.xls',
   	@tmp_desc = 'Target Disposal Validation Export: ' + convert(varchar(10), @start_date, 110) + ' - ' + convert(varchar(12), @end_date, 110)

   /*	Write to Excel: */
   exec plt_export.dbo.sp_export_to_excel
   	@table_name	     = 'eq_temp..sp_target_disposal_extract_!',
   	@template	     = 'sp_target_disposal_extract.DisposalValidation',
   	@filename	     = @tmp_filename,
   	@added_by	     = @usr,
   	@export_desc     = @tmp_desc,
   	@report_log_id   = @report_log_id,
   	@debug = 0


---------------------------------
-- WM format of data output
---------------------------------

--	TRUNCATE TABLE eq_temp..sp_target_disposal_extract_2

  --  INSERT eq_temp..sp_target_disposal_extract_2

print 'Return Run Information, Finished'
PRINT 'Elapsed time is ' + convert(varchar(40), datediff(ms, @timer, getdate())) + 'ms'
Print 'Current step elapsed time is ' + convert(varchar(40), datediff(ms, @steptimer, getdate())) + 'ms'
set @steptimer = getdate()




GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_target_disposal_extract] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_target_disposal_extract] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_target_disposal_extract] TO [EQAI]
    AS [dbo];

