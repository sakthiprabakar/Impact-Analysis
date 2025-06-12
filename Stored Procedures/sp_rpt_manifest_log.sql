CREATE PROCEDURE sp_rpt_manifest_log 
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@haz_flag			char(1)
AS
/***********************************************************************
This procedure runs for all the Manifest Log reports.

PB Object(s):	r_manifest_log_gal
			Nest - r_manifest_log_gal_detail
			Nest - r_manifest_log_gal_summ
		r_manifest_log_gal_treat
		r_manifest_log_gal_treat_summ
		r_manifest_log_yard
			Nest - r_manifest_log_yard_detail
			Nest - r_manifest_log_yard_summ

Note:	Send @haz_flag = 'U' for ALL of the Gallon reports.
	Send @haz_flag = 'T' for the Hazardous (Yards) report.
	Send @haz_flag = 'F' for the Non-Hazardous (Yards) report.

07/01/2004 JDB	Created
07/19/2004 JDB	Added join from Receipt to Treatment by profit_ctr_id.
08/05/2004 JDB	Added profit_ctr_id join to WasteCode table.
08/31/2004 JPB 	Added profit_ctr_id parameter and clause per LT.
11/11/2004 MK  	Changed generator_code to generator_id
11/26/2004 MK	Fixed ticket references
03/15/2006 RG   removed join to wastecode on profit ctr
03/22/2006 SCC  Changed to exclude In-Transit receipts
10/15/2010 SK	Added company_id as input argument, joined to company_id whereever necessary
				replaced *= joins with standard ANSI joins
				moved to Plt_AI
08/21/2013 SM	Joined wastecode table using uid and display name 
07/29/2014 JDB	Updated the procedure for the following reasons:
				1. Check for haz/non-haz was only checking the receipt's primary waste code, 
					and didn't specify only Federal codes.  Now, it checks all of the receipt
					line's waste codes, and counts it has hazardous if there are any federal
					hazardous waste codes.
					a. Because of this change to use a subquery for haz_flag instead of a 
						straight join, I changed the initial select to insert into a #tmp table.
				2. Added the join to ReceiptPrice table, because multi-unit receipt lines are
					populated with a NULL in the Receipt.bill_unit_code table, which previously
					made the join to BillUnit not return any data.
				3. Added NOLOCK hints to all tables in the query.
08/13/2014 JDB	To coincide with the last modification to this report on 7/29/14, this change
				also updates the query to return the bill_unit_code from the ReceiptPrice table,
				to go along with the bill_quantity field.

02/01/2024 - Dipankar - Instead of Reportable Category, Reportable Category Description to be there in the resultset

sp_rpt_manifest_log 12, 0, '7/16/04', '7/16/04', 1, 999999, 'T'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT	
	r.receipt_id
,	r.line_id
,	g.generator_name
,	r.approval_code
,	w.display_name AS waste_code
-- Get quantity from the ReceiptPrice table, not Receipt
--,	r.quantity
,	rp.bill_quantity AS quantity
,	rp.bill_unit_code
,	r.hauler
,	r.manifest
,	r.location
,	r.receipt_date
,	r.company_id
,	r.profit_ctr_id
,	r.container_count
,	b.gal_conv
,	b.yard_conv
-- Use a sub-select to determine haz/non-haz, so that we can check all federal waste codes on the receipt line,
-- not just the primary.
--,	w.haz_flag
, haz_flag = CASE WHEN (
	EXISTS (
		SELECT 1 
		FROM ReceiptWasteCode rwc (NOLOCK) 
		JOIN WasteCode (NOLOCK) ON rwc.waste_code_uid = WasteCode.waste_code_uid
			AND WasteCode.waste_code_origin = 'F'
			AND ISNULL(WasteCode.haz_flag,'F') = 'T'
			AND WasteCode.status = 'A'
		WHERE r.company_id = rwc.company_id 
		AND r.profit_ctr_id = rwc.profit_ctr_id
		AND r.receipt_id = rwc.receipt_id
		AND r.line_id = rwc.line_id
		)
	) THEN 'T' ELSE 'F' END
,	r.treatment_id
,	r.truck_code
,	r.bulk_flag
,	IsNull(tc.reportable_category_desc,'') AS reportable_category
,	b.container_flag
,	c.company_name
,	pc.profit_ctr_name
INTO #tmp
FROM Receipt r (NOLOCK)
JOIN Company c (NOLOCK)
	ON c.company_id = r.company_id
JOIN ProfitCenter pc (NOLOCK)
	ON pc.company_id = r.company_id
	AND pc.profit_ctr_id = r.profit_ctr_id
JOIN ReceiptPrice rp (NOLOCK)
	ON rp.company_id = r.company_id
	AND rp.profit_ctr_id = r.profit_ctr_id
	AND rp.receipt_id = r.receipt_id
	AND rp.line_id = r.line_id
JOIN BillUnit b (NOLOCK)
	ON b.bill_unit_code = rp.bill_unit_code
JOIN Treatment t (NOLOCK)
	ON t.company_id = r.company_id
	AND t.profit_ctr_id = r.profit_ctr_id
	AND t.treatment_id = r.treatment_id
LEFT OUTER JOIN TreatmentCategory tc (NOLOCK)
    ON t.reportable_category = tc.reportable_category
-- We'll leave this join to the WasteCode table, but only so that the display name can be returned in the select list.
-- It's only showing the "primary" waste code.
LEFT OUTER JOIN WasteCode w (NOLOCK)
	ON w.waste_code_uid = r.waste_code_uid
LEFT OUTER JOIN Generator g (NOLOCK)
	ON g.generator_id = r.generator_id
WHERE	(@company_id = 0 OR r.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id)
	AND r.trans_type = 'D'
	AND r.trans_mode = 'I'
	AND r.receipt_status NOT IN ('T', 'V', 'R')
	AND r.fingerpr_status NOT IN ('V', 'R')
	AND r.receipt_date BETWEEN @date_from AND @date_to
	AND r.customer_id BETWEEN @customer_id_from AND @customer_id_to
-- Since the determination of haz_flag moved to a subselect, and the join to WasteCode only gets the primary,
-- this part needed to be commented out, and moved to the final select below (from the #tmp table).
	--AND (@haz_flag = 'U' OR w.haz_flag = @haz_flag)


SELECT 	#tmp.receipt_id
,	#tmp.line_id
,	#tmp.generator_name
,	#tmp.approval_code
,	#tmp.waste_code
,	#tmp.quantity
,	#tmp.bill_unit_code
,	#tmp.hauler
,	#tmp.manifest
,	#tmp.location
,	#tmp.receipt_date
,	#tmp.company_id
,	#tmp.profit_ctr_id
,	#tmp.container_count
,	#tmp.gal_conv
,	#tmp.yard_conv
,	#tmp.haz_flag
,	#tmp.treatment_id
,	#tmp.truck_code
,	#tmp.bulk_flag
,	#tmp.reportable_category
,	#tmp.container_flag
,	#tmp.company_name
,	#tmp.profit_ctr_name
FROM #tmp
WHERE 1=1
AND (@haz_flag = 'U' OR #tmp.haz_flag = @haz_flag)

DROP TABLE #tmp

GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_manifest_log] TO [EQAI]
    AS [dbo];

