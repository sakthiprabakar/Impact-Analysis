
CREATE PROCEDURE sp_rpt_extract_meijer (
	@start_date				datetime,
	@end_date				datetime,
	@include_eq_fields		int = 0
)
AS
/* ***********************************************************
Procedure    : sp_rpt_extract_meijer
Database     : plt_ai
Description  : Creates a Meijer Extract
PB Object(s):	
				

12/31/2008 JPB	Created.
01/02/2008 KAM	Added select by Billing project. 
01/03/2009 LJT  Changed lowercase waste code none to upper case
		reversed the wastecodes being extracted because I think the data window is reversed.
		Release code missing in billing table for receipt_id = 83174 and company_id = 22 and profit_ctr_id = 0
		need to find out why
		Removed 'WO#' and 'WO# ' and 'WO #' from release code
		Upper cased service description
01/05/2009 JPB	Modified to select from centralized Receipt, Container tables
		instead of using PLT_RPT.
03/19/2008 JPB	Fixed Container/ContainerDestination calculation of weights
03/20/2008 JPB  Commented out Billing_project_id limitation per Tracy.
06/08/2009 JPB  Added additional generator fields from GeneratorExtractInfo
		Also converted from #temp tables to eq_temp tables.
09/28/2009 JPB  Modified release_code logic per Tracy_E:
		-If the release field is blank, use the PO field.
		-If the release field is not blank, use the release field.
02/28/2011 JPB	Modified SP to use WorkOrderDetailUnit for pounds instead of WorkOrderDetail		
10/20/2011 JPB	Modified so total per invoice comes from billingdetail, not billing.total_extended_amt

07/09/2012 JPB	One-off copy & change to run for Meijer customer_id 4017, 1/1/2012 - 5/31/2012
				- Reviewed by JDB

12/23/2013 JPB	Notes:
				GEM: 26792 - Report MEJRX004DEA and MEJRX004 approval weights to tenths of pounds.
						- Uh, it already does that.
				GEM: 26795 - Add Categories to report output (consider using Baseline for this)
						- We can store the cateogries & approval codes in the baseline system
							but not use it for workorder selecting. Then they have a way to get admin
							changes done, and all we have to do (heh, ALL) is cross-link to it in
							this extract to get the right categories to show up per approval code.
						- Inserted all the category info into BaselineHeader.

03/10/2014 JPB	I need to add a column to the Meijer Data Extract  
				-The customer is requesting a column for associated EPA ID numbers 
				-Also a column that lists the "Residue print on manifest" weight of P-Listed waste 
				 (much like the Rite Aid report would have). It should be categorized just as "Net Weight" 
				 on the report. This is currently calculated and printed in section 14 of the manifest of 
				 approval MEJRX004E and will be in approval MEJ027A shortly. 
08/21/2014 JPB	Noticed a bug in the calculation for residue weight.  Fixed

				 
		Alter table MeijerExtract add epa_id varchar(20), net_weight float		

sp_rpt_extract_meijer '09/01/2013', '10/20/2013', 1
*********************************************************** */

SET NOCOUNT ON

-- Define Meijer specific extract values:
DECLARE
	@vendor_number			varchar(20),
	@account_number			varchar(20),
	@expense_center			varchar(20),
	-- @DC_account_number		varchar(20),
	-- @DC_expense_center		varchar(20),
	@extract_datetime		datetime,
	@usr					nvarchar(256),
	@days_before_delete		smallint,
	@customer_id				int

SELECT
	@vendor_number			= '00000',
	@account_number			= '000000',
	@expense_center			= '00000',
	-- @DC_account_number		= '650150',
	-- @DC_expense_center		= '5435',
	@extract_datetime		= GETDATE(),
	@usr 					= UPPER(SUSER_SNAME()),
	@days_before_delete		= 90,
	@customer_id			= 4017

IF datepart(hh, @end_date) = 0 set @end_date = @end_date + 0.99999
	
IF RIGHT(@usr, 3) = '(2)'
	SELECT @usr = LEFT(@usr,(LEN(@usr)-3))
-----------------------------------------------------------
-- Always keep at least 5 copies
-----------------------------------------------------------
SELECT DISTINCT TOP 5 added_by, date_added 
INTO #extracts_to_keep
FROM EQ_Extract..MeijerExtract 
ORDER BY date_added DESC

--SELECT * FROM #extracts_to_keep

-----------------------------------------------------------
-- Delete old extracts, but leave at least the last 5
-----------------------------------------------------------
DELETE FROM EQ_Extract..MeijerExtract 
WHERE date_added < @days_before_delete
AND date_added NOT IN (
	SELECT date_added FROM #extracts_to_keep
	)

-- Select data
SELECT
	@vendor_number as vendor_number,
	ISNULL(g.site_code, '') as location_number,
	isnull(g.epa_id, '') as epa_id, -- 3/10/14
	
	CASE WHEN b.trans_source = 'R' THEN
		CASE WHEN 
			RT.transporter_sign_date /* PLT_RPT..Receipt.pickup_date */ IS NOT NULL 
		THEN
			RT.transporter_sign_date
		ELSE 
			CASE WHEN EXISTS (
					SELECT receipt_id 
					FROM BillingLinkLookup bll  (nolock) 
					WHERE bll.company_id = b.company_id
					AND bll.profit_ctr_id = b.profit_ctr_id
					AND bll.receipt_id = b.receipt_id
				) THEN (
					SELECT bllwoh.start_date 
					FROM BillingLinkLookup bll (nolock) 
						INNER JOIN WorkOrderHeader bllwoh (nolock) 
							ON bllwoh.company_id = bll.source_company_id
							AND bllwoh.profit_ctr_id = bll.source_profit_ctr_id
							AND bllwoh.workorder_id = bll.source_id
					WHERE bll.company_id = b.company_id
						AND bll.profit_ctr_id = b.profit_ctr_id
						AND bll.receipt_id = b.receipt_id
				)
			ELSE
				r.receipt_date
			END
		END
	ELSE
		woh.start_date
	END as service_date,

---	b.release_code,
	CASE WHEN b.trans_source = 'R' THEN
		CASE WHEN isnull(r.release,'') = '' THEN isnull(r.purchase_order, '') ELSE isnull(r.release, '') END
		-- was: isnull(r.release,'')
	ELSE
		CASE WHEN isnull(b.release_code, '') = '' THEN isnull(b.purchase_order, '') ELSE isnull(b.purchase_order, '') END
		-- was: b.release_code
	END as release_code,
	
	b.manifest,

/*
	CASE WHEN b.generator_id = 78835 THEN 
		@DC_account_number 
	ELSE 
		@account_number 
	END as account_number,
	
	Code above replaced with below on 6/8/2009:
*/	
	CASE WHEN gei.generator_id is not null THEN
		gei.account_number
	ELSE
		@account_number
	END as account_number,
/*	End of new Code 6/8/2009 */	

/*
	CASE WHEN b.generator_id = 78835 THEN 
		@DC_expense_center 
	ELSE 
		@expense_center 
	END as expense_center,
	
	Code above replaced with below on 6/8/2009:
*/	
	CASE WHEN gei.generator_id is not null THEN
		gei.expense_center
	ELSE
		@expense_center
	END as expense_center,
/*	End of new Code 6/8/2009 */	
	
	UPPER(RTRIM(LTRIM(ISNULL(b.service_desc_1,'') + ' ' + ISNULL(b.service_desc_2, '')))) AS service_description,
	
	ISNULL(CASE WHEN b.trans_source = 'R' THEN
		r.container_count
	ELSE
		wod.container_count
	END, 0) as container_count,
	
/*
	ISNULL(CASE WHEN b.trans_source = 'R' THEN
		CASE WHEN ISNULL(
				(
				select 
					sum((con.container_weight * cd.container_percent * 0.01))
				from Container con  (nolock) 
				INNER JOIN ContainerDestination cd (nolock)
					ON con.company_id = cd.company_id
					AND con.profit_ctr_id = cd.profit_ctr_id
					AND con.receipt_id = cd.receipt_id
					AND con.line_id = cd.line_id
					AND con.container_id = cd.container_id
				WHERE
					con.company_id = b.company_id
					and con.profit_ctr_id = b.profit_ctr_id
					and con.receipt_id = b.receipt_id
					and con.line_id = b.line_id
				)
		, 0) = 0 THEN
			ISNULL(r.net_weight, 0)
		ELSE
			ISNULL(
				(
				select 
					sum((con.container_weight * cd.container_percent * 0.01))
				from Container con  (nolock) 
				INNER JOIN ContainerDestination cd (nolock)
					ON con.company_id = cd.company_id
					AND con.profit_ctr_id = cd.profit_ctr_id
					AND con.receipt_id = cd.receipt_id
					AND con.line_id = cd.line_id
					AND con.container_id = cd.container_id
				WHERE
					con.company_id = b.company_id
					and con.profit_ctr_id = b.profit_ctr_id
					and con.receipt_id = b.receipt_id
					and con.line_id = b.line_id
				)
			,0)
		END
	ELSE
		-- wod.pounds
		(select quantity from WorkOrderDetailUnit where workorder_id = b.receipt_id and sequence_id = b.workorder_sequence_id and company_id = b.company_id and profit_ctr_id = b.profit_ctr_id and bill_unit_code = 'lbs')
	END, 0) 
*/
	isnull(dbo.fn_receipt_weight_line(b.receipt_id, b.line_id, b.profit_ctr_id, b.company_id), 0)
	as pounds,
	
/*	
	
	sum(ISNULL(CASE WHEN b.trans_source = 'R' THEN
		isnull(p.residue_pounds_factor, 0) * isnull(rdi.merchandise_quantity, 0)
	ELSE
		0
	END, 0)) as net_weight, -- 3/10/14

*/

-- 12/13/2019
	ISNULL(CASE WHEN b.trans_source = 'R' THEN
		isnull(p.residue_pounds_factor, 0) * (
		select sum(rdi.merchandise_quantity)
		FROM ReceiptDetailItem rdi  (nolock) 
		WHERE b.receipt_id = rdi.receipt_id 
		and b.company_id = rdi.company_id 
		and b.profit_ctr_id = rdi.profit_ctr_id 
		and b.line_id = rdi.line_id
		and b.trans_source = 'R'
		)
	ELSE
		0
	END, 0) as net_weight, -- 3/10/14

	
	CASE WHEN b.trans_source = 'R' THEN
		LTRIM(RTRIM(REPLACE(dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 1), '.', 'NONE')))
	ELSE
		LTRIM(RTRIM(REPLACE(dbo.fn_get_list_item(',', 1, t.waste_code + ', ' + dbo.fn_approval_sec_waste_code_list(t.tsdf_approval_id, 'T'), 1), '.', 'NONE')))
	END as waste_code_1,

	
	CASE WHEN b.trans_source = 'R' THEN
		LTRIM(RTRIM(REPLACE(dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 2), '.', 'NONE')))
	ELSE
		LTRIM(RTRIM(REPLACE(dbo.fn_get_list_item(',', 1, t.waste_code + ', ' + dbo.fn_approval_sec_waste_code_list(t.tsdf_approval_id, 'T'), 2), '.', 'NONE')))
	END as waste_code_2,
	

	CASE WHEN b.trans_source = 'R' THEN
		LTRIM(RTRIM(REPLACE(dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_state(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 1), '.', 'NONE')))
	ELSE
		LTRIM(RTRIM(REPLACE(dbo.fn_get_list_item( ',',1, dbo.fn_sec_waste_code_list_state(t.tsdf_approval_id, 'T'), 1), '.', 'NONE')))
	END as state_waste_code,
	
	SUM(bd.extended_amt) as cost,
	
	-- Extra EQ Fields:
	b.company_id,
	b.profit_ctr_id,
	b.receipt_id,
	b.line_id,
	b.trans_source
INTO #MeijerExtract
FROM Billing b (nolock) 
inner join BillingDetail bd
	on b.billing_uid = bd.billing_uid
	LEFT OUTER JOIN Generator g  (nolock) 
		ON b.generator_id = g.generator_id
	LEFT OUTER JOIN Receipt r  (nolock) 
		ON b.receipt_id = r.receipt_id 
		and b.company_id = r.company_id 
		and b.profit_ctr_id = r.profit_ctr_id 
		and b.line_id = r.line_id
		and b.trans_source = 'R'
/*
	LEFT OUTER JOIN ReceiptDetailItem rdi  (nolock) 
		ON b.receipt_id = rdi.receipt_id 
		and b.company_id = rdi.company_id 
		and b.profit_ctr_id = rdi.profit_ctr_id 
		and b.line_id = rdi.line_id
		and b.trans_source = 'R'
*/
	LEFT OUTER JOIN Profile p (nolock)
		ON r.profile_id = p.profile_id
	LEFT OUTER JOIN WorkOrderHeader woh  (nolock) 
		ON b.receipt_id = woh.workorder_id 
		and b.company_id = woh.company_id 
		and b.profit_ctr_id = woh.profit_ctr_id
		and b.trans_source = 'W'
	LEFT OUTER JOIN WorkOrderDetail wod  (nolock) 
		ON b.receipt_id = wod.workorder_id 
		and b.company_id = wod.company_id 
		and b.profit_ctr_id = wod.profit_ctr_id 
		and b.workorder_sequence_id = wod.sequence_id
		and b.workorder_resource_type = wod.resource_type
		and b.trans_source = 'W'
	LEFT OUTER JOIN TSDFApproval t  (nolock) 
		ON b.tsdf_approval_id = t.tsdf_approval_id
	LEFT OUTER JOIN ReceiptTransporter RT (nolock) 
		ON RT.receipt_id = R.receipt_id 
		and RT.company_id = R.company_id 
		and RT.profit_ctr_id = R.profit_ctr_id
		and RT.transporter_sequence_id = 1
	LEFT OUTER JOIN GeneratorExtractInfo gei
		ON g.generator_id = gei.generator_id
		AND b.customer_id = gei.customer_id
WHERE
	b.customer_id = @customer_id
	AND b.invoice_date BETWEEN @start_date AND @end_date
	AND b.status_code = 'I'
	-- AND (b.billing_project_id IN (450,485,490,513) OR (b.billing_project_id = 0 and billing_date > '12/31/2008 23:59:59'))
GROUP BY
	g.site_code,
	g.epa_id,
	rt.transporter_sign_date,
	r.receipt_date,
	woh.start_date,
	b.manifest,
	b.generator_id,
	b.service_desc_1,
	b.service_desc_2,
	r.container_count,
	wod.container_count,
	r.net_weight,
	-- r.link_Container_Receipt,
	-- wod.pounds,
	t.waste_code,
	t.TSDF_approval_id,
	r.release,
	r.purchase_order,
	b.release_code,
	b.purchase_order,
	b.company_id,
	b.profit_ctr_id,
	b.receipt_id,
	b.line_id,
	b.workorder_sequence_id,
	b.trans_source,
	gei.generator_id,
	gei.account_number,
	gei.expense_center

/*
Texas waste codes are 8 digits, and wouldn't fit into the wastecode table's waste_code field.
BUT, the waste_code field on those records is unique, so EQ systems handle it correctly, but we
need to remember to update the extract to swap the waste_description (the TX 8 digit code) for
the waste_code for waste_codes that are from TX.
*/
UPDATE #MeijerExtract SET 
	state_waste_code = (
		SELECT left(wc.waste_code_desc, 8) 
		FROM wastecode wc 
		WHERE waste_code_origin = 'S' 
		AND wc.state = 'TX' 
		AND state_waste_code = wc.waste_code
	)

-- temporary fix to remove 'WO#' from Release_code.
update #MeijerExtract set release_code =substring (release_code, 5,16) where release_code like 'WO# %' 
update #MeijerExtract set release_code =substring (release_code, 4,17) where release_code like 'WO#%' 
update #MeijerExtract set release_code =substring (release_code, 5,16) where release_code like 'WO #%' 


INSERT INTO EQ_Extract.dbo.MeijerExtract
SELECT vendor_number,
	location_number,
	service_date,
	release_code,
	manifest,
	account_number,
	expense_center,
	service_description,
	container_count,
	pounds,
	waste_code_1,
	waste_code_2,
	state_waste_code,
	cost,
	company_id,
	profit_ctr_id,
	receipt_id,
	line_id,
	trans_source, 
	LEFT(@Usr, 10), 
	@Extract_datetime 
	, epa_id		-- 3/10/14
	, net_weight
FROM #MeijerExtract

SET NOCOUNT OFF

-- Select out just the data wanted by Meijer:
--select * from eq_extract.dbo.MeijerExtract where added_by = @Usr and date_added = @Extract_datetime
IF @include_eq_fields = 0
BEGIN
	SELECT
		e.vendor_number,
		e.site_code as location_number,
		e.epa_id, -- 3/10/14
		CONVERT(varchar(40), e.service_date, 1) as service_date,
		e.release_code as work_order_number,
		e.manifest,
		e.account_number,
		e.expense_center,
		blh.custom_defined_name_1 as category,
		e.service_description,
		e.container_count as number_of_containers,
		case r.approval_code 
			when 'MEJRX004' then round(e.pounds, 2)
			when 'MEJRX004DEA' then round(e.pounds, 2)
			else e.pounds
			end as total_weight_lbs,
		e.net_weight,
		ISNULL(e.waste_code_1, '') as federal_waste_code_1,
		ISNULL(e.waste_code_2, '') as federal_waste_code_2,
		ISNULL(e.state_waste_code, '') AS state_waste_code,
		e.total_extended_amt as cost
	FROM EQ_Extract.dbo.MeijerExtract e (nolock) 
	LEFT JOIN Receipt r (nolock) on e.receipt_id = r.receipt_id and e.line_id = r.line_id and e.company_id = r.company_id and e.profit_ctr_id = r.profit_ctr_id
	LEFT JOIN BaselineHeader blh (nolock) on e.service_description = blh.baseline_description
	WHERE e.date_added = @extract_datetime 
	  AND e.added_by = @usr
	ORDER BY e.site_code, e.service_date, e.manifest
END
ELSE
BEGIN
	SELECT
		e.vendor_number,
		e.site_code as location_number,
		e.epa_id,
		CONVERT(varchar(40), e.service_date, 1) as service_date,
		e.release_code as work_order_number,
		e.manifest,
		e.account_number,
		e.expense_center,
		blh.custom_defined_name_1 as category,
		e.service_description,
		e.container_count as number_of_containers,
		case r.approval_code 
			when 'MEJRX004' then round(e.pounds, 2)
			when 'MEJRX004DEA' then round(e.pounds, 2)
			else e.pounds
			end as total_weight_lbs,
		e.net_weight,
		ISNULL(e.waste_code_1, '') as federal_waste_code_1,
		ISNULL(e.waste_code_2, '') as federal_waste_code_2,
		ISNULL(e.state_waste_code, '') AS state_waste_code,
		e.total_extended_amt as cost,
		e.company_id,
		e.profit_ctr_id,
		e.receipt_id,
		e.line_id,	
		e.trans_source,
		r.approval_code
	FROM EQ_Extract.dbo.MeijerExtract e (nolock) 
	LEFT JOIN Receipt r (nolock) on e.receipt_id = r.receipt_id and e.line_id = r.line_id and e.company_id = r.company_id and e.profit_ctr_id = r.profit_ctr_id
	LEFT JOIN BaselineHeader blh (nolock) on e.service_description = blh.baseline_description
	WHERE e.date_added = @extract_datetime 
	  AND e.added_by = @usr
	ORDER BY e.site_code, e.service_date, e.manifest
END

-- DROP TABLE #Extract


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_meijer] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_meijer] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_meijer] TO [EQAI]
    AS [dbo];

