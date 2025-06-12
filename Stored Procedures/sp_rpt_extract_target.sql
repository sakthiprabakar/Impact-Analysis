
CREATE PROCEDURE sp_rpt_extract_target (
	@start_date				datetime,
	@end_date				datetime,
	@include_eq_fields		bit = 0
)
AS
/* ***********************************************************
Procedure    : sp_rpt_extract_target
Database     : plt_ai
Description  : Creates a Target Extract
PB Object(s):	d_rpt_extract_target
				d_rpt_extract_target_details

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

09/24/2013 JPB	Modified per TX Waste Code Project

select * from sysobjects where name like '%target%' and xtype = 'u'
select added_by, date_added, * from EQ_Extract..TargetExtract where date_added > '1/4/09' order by date_added desc, site_code, service_date, manifest
select added_by, date_added, * from EQ_Extract..TargetExtract where date_added= '2009-01-05 08:39:52.200' 
-- delete from EQ_Extract..targetextract where added_by = 'jason_b'
-- delete from EQ_Extract..targetextract where date_added > '1/3/09'
sp_rpt_extract_target '1/1/2011 00:00', '1/31/2011 23:59', 1
*********************************************************** */

SET NOCOUNT ON

-- Define Target specific extract values:
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
	@vendor_number			= '000183741',
	@account_number			= '657070',
	@expense_center			= '2610',
	-- @DC_account_number		= '650150',
	-- @DC_expense_center		= '5435',
	@extract_datetime		= GETDATE(),
	@usr 					= UPPER(SUSER_SNAME()),
	@days_before_delete		= 90,
	@customer_id			= 12113

	
IF RIGHT(@usr, 3) = '(2)'
	SELECT @usr = LEFT(@usr,(LEN(@usr)-3))

-- EQ_Temp table housekeeping
-- Deletes temp data more than 2 days old, or by this user (past runs)
DELETE FROM EQ_TEMP.dbo.TargetExtract where date_added < dateadd(dd, -2, getdate())
DELETE FROM EQ_TEMP.dbo.TargetExtract where added_by = @usr

-----------------------------------------------------------
-- Always keep at least 5 copies
-----------------------------------------------------------
SELECT DISTINCT TOP 5 added_by, date_added 
INTO #extracts_to_keep
FROM EQ_Extract..TargetExtract 
ORDER BY date_added DESC

--SELECT * FROM #extracts_to_keep

-----------------------------------------------------------
-- Delete old extracts, but leave at least the last 5
-----------------------------------------------------------
DELETE FROM EQ_Extract..TargetExtract 
WHERE date_added < @days_before_delete
AND date_added NOT IN (
	SELECT date_added FROM #extracts_to_keep
	)

-- Select Work Order data using TSDFApprovals (Non EQ Facilities)
INSERT EQ_Temp.dbo.TargetExtract
SELECT
	@vendor_number as vendor_number,
	ISNULL(g.site_code, '') as location_number,
	
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
	END, 0) as pounds,

	CASE WHEN b.trans_source = 'R' THEN
		LTRIM(RTRIM(REPLACE(dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 1), '.', 'NONE')))
	ELSE
		LTRIM(RTRIM(REPLACE(dbo.fn_get_list_item(',', 1, twc.display_name + ', ' + dbo.fn_approval_sec_waste_code_list(t.tsdf_approval_id, 'T'), 1), '.', 'NONE')))
	END as waste_code_1,

	
	CASE WHEN b.trans_source = 'R' THEN
		LTRIM(RTRIM(REPLACE(dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 2), '.', 'NONE')))
	ELSE
		LTRIM(RTRIM(REPLACE(dbo.fn_get_list_item(',', 1, twc.display_name + ', ' + dbo.fn_approval_sec_waste_code_list(t.tsdf_approval_id, 'T'), 2), '.', 'NONE')))
	END as waste_code_2,

	CASE WHEN b.trans_source = 'R' THEN
		LTRIM(RTRIM(REPLACE(dbo.fn_get_list_item(',', 1, dbo.fn_receipt_waste_code_list_state_no_state_prefix(b.company_id, b.profit_ctr_id, b.receipt_id, b.line_id), 1), '.', 'NONE')))
	ELSE
		LTRIM(RTRIM(REPLACE(dbo.fn_get_list_item( ',',1, dbo.fn_sec_waste_code_list_state_no_state_prefix(t.tsdf_approval_id, 'T'), 1), '.', 'NONE')))
	END as state_waste_code,
	
	SUM(bd.extended_amt) as cost,

	-- Extra EQ Fields:
	b.company_id,
	b.profit_ctr_id,
	b.receipt_id,
	b.line_id,
	b.trans_source,
	@usr,
	@extract_datetime

FROM Billing b (nolock) 
inner join BillingDetail bd
	on b.receipt_id = bd.receipt_id
	and b.line_id = bd.line_id
	and b.price_id = bd.price_id
	and b.company_id = bd.company_id
	and b.profit_ctr_id = bd.profit_ctr_id
	and b.trans_source = bd.trans_source
	LEFT OUTER JOIN Generator g  (nolock) 
		ON b.generator_id = g.generator_id
	LEFT OUTER JOIN Receipt r  (nolock) 
		ON b.receipt_id = r.receipt_id 
		and b.company_id = r.company_id 
		and b.profit_ctr_id = r.profit_ctr_id 
		and b.line_id = r.line_id
		and b.trans_source = 'R'
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
	LEFT OUTER JOIN WasteCode twc (nolock) on t.waste_code_uid = twc.waste_code_uid
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
	twc.display_name,
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
UPDATE EQ_TEMP.dbo.TargetExtract SET 
	state_waste_code = (
		SELECT left(wc.waste_code_desc, 8) 
		FROM wastecode wc 
		WHERE waste_code_origin = 'S' 
		AND wc.state = 'TX' 
		AND state_waste_code = wc.waste_code
	)
WHERE date_added = @extract_datetime 
AND added_by = @usr
*/

-- temporary fix to remove 'WO#' from Release_code.
update EQ_TEMP.dbo.TargetExtract set release_code =substring (release_code, 5,16) where release_code like 'WO# %' AND date_added = @extract_datetime and added_by = @usr
update EQ_TEMP.dbo.TargetExtract set release_code =substring (release_code, 4,17) where release_code like 'WO#%' AND date_added = @extract_datetime and added_by = @usr
update EQ_TEMP.dbo.TargetExtract set release_code =substring (release_code, 5,16) where release_code like 'WO #%' AND date_added = @extract_datetime and added_by = @usr


-- JDB Comment
--PRINT 'SELECT * FROM EQ_TEMP.dbo.TargetExtract WHERE date_added = @extract_datetime and added_by = @usr'
--SELECT * FROM EQ_TEMP.dbo.TargetExtract WHERE date_added = @extract_datetime and added_by = @usr

INSERT INTO EQ_Extract.dbo.TargetExtract
SELECT vendor_number,
	site_code,
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
	total_extended_amt,
	company_id,
	profit_ctr_id,
	receipt_id,
	line_id,
	trans_source, 
	LEFT(@Usr, 10), 
	@Extract_datetime 
FROM EQ_TEMP.dbo.TargetExtract (nolock) WHERE date_added = @extract_datetime and added_by = @usr

SET NOCOUNT OFF

-- Select out just the data wanted by Target:
--select * from eq_extract.dbo.TargetExtract where added_by = @Usr and date_added = @Extract_datetime
IF @include_eq_fields = 0
BEGIN
	SELECT
		vendor_number,
		site_code as location_number,
		CONVERT(varchar(40), service_date, 1) as service_date,
		release_code as work_order_number,
		manifest,
		account_number,
		expense_center,
		service_description,
		container_count as number_of_containers,
		pounds as total_weight_lbs,
		ISNULL(waste_code_1, '') as federal_waste_code_1,
		ISNULL(waste_code_2, '') as federal_waste_code_2,
		ISNULL(state_waste_code, '') AS state_waste_code,
		total_extended_amt as cost
	FROM EQ_Extract.dbo.TargetExtract (nolock) 
	WHERE date_added = @extract_datetime 
	  AND added_by = @usr
	ORDER BY site_code, service_date, manifest
END
ELSE
BEGIN
	SELECT
		vendor_number,
		site_code as location_number,
		CONVERT(varchar(40), service_date, 1) as service_date,
		release_code as work_order_number,
		manifest,
		account_number,
		expense_center,
		service_description,
		container_count as number_of_containers,
		pounds as total_weight_lbs,
		ISNULL(waste_code_1, '') as federal_waste_code_1,
		ISNULL(waste_code_2, '') as federal_waste_code_2,
		ISNULL(state_waste_code, '') AS state_waste_code,
		total_extended_amt as cost,
		company_id,
		profit_ctr_id,
		receipt_id,
		line_id,	
		trans_source
	FROM EQ_Extract.dbo.TargetExtract (nolock) 
	WHERE date_added = @extract_datetime 
	  AND added_by = @usr
	ORDER BY site_code, service_date, manifest
END

-- DROP TABLE #Extract


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_extract_target] TO [EQAI]
    AS [dbo];

