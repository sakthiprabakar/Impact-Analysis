CREATE PROCEDURE sp_rpt_po_balance
	@date_from		datetime,
	@date_to		datetime,
	@customer_type	varchar(10),
	@customer_id	int,
	@purchase_order varchar(20),
	@release_code	varchar(20),
	@user_code		varchar(100) = NULL, -- for associates
	@copc_list		varchar(max) = NULL, -- ex: 21|1,14|0,14|1
    @permission_id	int = NULL
AS
/****************************************************************************************************
This SP captures the labor utilization in the plants for Monthly Contractor Activity Report

10/09/2012 DZ	Created

sp_rpt_po_balance 2012, 9, '', NULL, 'R102764', NULL, 'DANIEL_Z', '14|15', 1
06/16/2023 Devops 65744--Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
****************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

declare @tbl_profit_center_filter table (
    [company_id] int, 
    profit_ctr_id int
)

IF @user_code = ''
    set @user_code = NULL
    
INSERT @tbl_profit_center_filter
    SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
        FROM SecuredProfitCenter secured_copc
        INNER JOIN (
            SELECT 
                RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
                RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
            from dbo.fn_SplitXsvText(',', 0, @copc_list) 
            where isnull(row, '') <> '') selected_copc ON 
                secured_copc.company_id = selected_copc.company_id 
                AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
                AND secured_copc.permission_id = @permission_id
                AND secured_copc.user_code = @user_code

SELECT sc.customer_id, c.cust_name
INTO #SecuredCustomer
FROM SecuredCustomer sc
JOIN customer c
ON sc.customer_ID = c.customer_ID
WHERE sc.user_code = @user_code
AND sc.permission_id = @permission_id
AND (@customer_type = '' OR c.customer_type = @customer_type)
AND (@customer_id IS NULL OR @customer_id = 0 OR c.customer_id = @customer_id)

CREATE INDEX cui_secured_customer_tmp ON #SecuredCustomer(customer_id)

/*
CREATE TABLE #labor (
	labor_class				varchar(10)		null,
	labor					varchar(10)		null,
	labor_name				varchar(100)	null,
	quantity_used_billed	float			null,
	quantity_used_nc		float			null,
	quantity_hours			float			null,
	company_id				int				null,
	profit_ctr_id			int				null
)
*/

/* Store labor use amounts */
;WITH po_list AS
(
SELECT
	woh.customer_ID,
	secured_customer.cust_name,
	woh.company_id,
	woh.profit_ctr_ID,
	pc.profit_ctr_name,
	woh.purchase_order,
	isnull(woh.release_code, '') as release_code,
	IsNull(max(cbp.PO_amt), 0) as PO_amt
FROM WorkOrderHeader woh
INNER JOIN #SecuredCustomer secured_customer
    ON woh.customer_id = secured_customer.customer_id
JOIN @tbl_profit_center_filter secured_copc
    ON woh.company_id = secured_copc.company_id
    AND woh.profit_ctr_id = secured_copc.profit_ctr_id
JOIN ProfitCenter pc
	ON woh.company_id = pc.company_ID
	AND woh.profit_ctr_ID = pc.profit_ctr_ID
LEFT OUTER JOIN CustomerBillingPO cbp
	ON woh.customer_ID = cbp.customer_id
	AND woh.purchase_order = cbp.purchase_order
	AND IsNull(woh.release_code, '') = IsNull(cbp.release, '')
WHERE woh.workorder_status IN ('C', 'A')
	AND woh.start_date BETWEEN @date_from AND @date_to
	AND (@purchase_order IS NULL or woh.purchase_order = @purchase_order)
	AND (@release_code IS NULL or IsNull(woh.release_code, '') = @release_code)
	AND woh.purchase_order IS NOT NULL
	AND woh.purchase_order <> ''
GROUP BY woh.customer_ID,
		 secured_customer.cust_name,
		 woh.company_id,
		 woh.profit_ctr_ID,
		 pc.profit_ctr_name,
		 woh.purchase_order,
		 IsNull(woh.release_code, '')
/*
UNION
SELECT
	r.customer_id,
	r.company_id,
	r.profit_ctr_id,
	isNull(r.purchase_order, '') as purchase_order,
	isnull(r.release, '') as release_code
from Receipt r
INNER JOIN #SecuredCustomer secured_customer
    ON r.customer_id = secured_customer.customer_id
JOIN @tbl_profit_center_filter secured_copc
    ON r.company_id = secured_copc.company_id
    AND r.profit_ctr_id = secured_copc.profit_ctr_id
where r.receipt_date >= @StartDate
 AND r.receipt_date < @EndDate
*/
)
SELECT   --Work order not billed
	woh.customer_ID,
	po_list.cust_name,
	woh.workorder_ID,
	CONVERT(Varchar(6), woh.customer_ID) As customer_id,
	RTRIM(LTRIM((woh.purchase_order))) As purchase_order,
	IsNull(woh.release_code, '') As release_code,
	woh.total_price,
	--secured_customer.cust_name,
	woh.start_date,
	woh.project_location,
	woh.description as workorder_desc,
	woh.comments,
	'N' As invoiced_flag,
	'W' As source,
	woh.company_id,
	woh.profit_ctr_ID,
	po_list.profit_ctr_name,
	po_list.PO_amt
FROM WorkOrderHeader woh
JOIN po_list
	ON woh.customer_ID = po_list.customer_id
	AND woh.company_id = po_list.company_id
	AND woh.profit_ctr_ID = po_list.profit_ctr_id
	AND IsNull(woh.purchase_order, '') = po_list.purchase_order
	AND ISNULL(woh.release_code, '') = po_list.release_code
WHERE woh.workorder_status IN ('C', 'A')
	AND woh.start_date <= @date_to
	AND IsNull(woh.submitted_flag, 'F') = 'F'
UNION
SELECT  --receipt not invoiced
	r.customer_ID,
	po_list.cust_name,
	r.receipt_id,
	r.customer_ID,
	RTRIM(LTRIM(r.purchase_order)),
	IsNull(r.release, '') As release_code,
	SUM(rp.total_extended_amt),
	--secured_customer.cust_name,
	r.receipt_date,
	NULL,
	r.service_desc,
	NULL,
	'N' As invoiced_flag,
	'R',
	r.company_id,
	r.profit_ctr_ID,
	po_list.profit_ctr_name,
	po_list.PO_amt
	--pc.profit_ctr_name
FROM receipt r
JOIN ReceiptPrice rp
ON rp.company_id = r.company_id
AND rp.profit_ctr_id = r.profit_ctr_id
AND rp.receipt_id = r.receipt_id
AND rp.line_id = r.line_id
INNER JOIN po_list
    ON r.customer_id = CONVERT(Varchar(6), po_list.customer_id)
    AND r.company_id = po_list.company_id
    AND r.profit_ctr_id = po_list.profit_ctr_id
    AND r.purchase_order = po_list.purchase_order
WHERE r.receipt_status IN ('N','L','U','A','M') 
AND IsNull(r.submitted_flag,'F') = 'F'
GROUP BY 
	r.customer_ID,
	po_list.cust_name,
	r.receipt_id,
	r.customer_id, 
	r.purchase_order,
	IsNull(r.release, ''),
	r.receipt_date,
	r.service_desc,
	r.company_id,
	r.profit_ctr_id,
	po_list.profit_ctr_name,
	po_list.PO_amt
UNION
SELECT -- billed work order and receipt
	b.customer_ID,
	po_list.cust_name,
	b.receipt_id, 
	b.customer_id,
	RTRIM(LTRIM(b.purchase_order)),
	ISNULL(b.release_code, '') As release_code,
	SUM(bd.extended_amt),
	CASE b.trans_source
     WHEN 'W' THEN woh.start_date
     WHEN 'R' THEN r.receipt_date
     Else ''
	END,
	NULL,
	CASE b.trans_source
     WHEN 'W' THEN woh.description
     WHEN 'R' THEN r.service_desc
     Else ''
	END, 
	NULL,
	'Y' As invoiced_flag,
	'B',
	b.company_id,
	b.profit_ctr_ID,
	po_list.profit_ctr_name,
	po_list.PO_amt
FROM Billing b
JOIN BillingDetail bd
	ON bd.billing_uid = b.billing_uid
JOIN po_list
	ON b.customer_id = po_list.customer_ID
	AND b.purchase_order = po_list.purchase_order
	AND b.company_id = po_list.company_id
	AND b.profit_ctr_id = po_list.profit_ctr_ID
	AND IsNull(b.release_code, '') = po_list.release_code
	AND b.status_code in ('H','S','N','I')
LEFT OUTER JOIN WorkorderHeader woh
	ON b.receipt_id = woh.workorder_ID
	AND b.company_id = woh.company_id
	AND b.profit_ctr_id = woh.profit_ctr_id
	AND b.customer_id = woh.customer_id
	AND b.trans_source = 'W'
	AND woh.purchase_order = b.purchase_order
	AND ISNULL(woh.release_code, '') = IsNull(b.release_code, '')
	AND woh.submitted_flag = 'T'
LEFT OUTER JOIN Receipt r
	ON b.receipt_id = r.receipt_id
	AND b.company_id = r.company_id
	AND b.profit_ctr_id = r.profit_ctr_id
	AND b.customer_id = r.customer_id
	AND b.trans_source = 'R'
	AND r.submitted_flag = 'T'
	AND r.purchase_order = b.purchase_order
	AND ISNULL(r.release, '') = IsNull(b.release_code, '')
GROUP BY
	b.customer_ID,
	po_list.cust_name,
	b.receipt_id,
	b.customer_id,
	b.purchase_order,
	ISNULL(b.release_code, ''),
	Case b.trans_source
     WHEN 'W' THEN woh.start_date
     WHEN 'R' THEN r.receipt_date
     Else ''
	End,
	Case b.trans_source
     WHEN 'W' THEN woh.description
     WHEN 'R' THEN r.service_desc
     Else ''
	End, 
	b.billing_date,
	b.company_id,
	b.profit_ctr_id,
	po_list.profit_ctr_name,
	po_list.PO_amt
/* Return */
/*
SELECT 
	labor_class,
	labor,
	labor_name,
	sum(quantity_used_billed) as quantity_billed,
	sum(quantity_used_nc) as quantity_nc,
	sum(quantity_hours) as quantity_hours,
	#labor.company_id,
	#labor.profit_ctr_id,
	Company.company_name
FROM #labor
JOIN Company
	ON Company.company_id = #labor.company_id
GROUP BY labor_class, labor, labor_name, #labor.company_id, #labor.profit_ctr_id, company_name
*/

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_po_balance] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_po_balance] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_po_balance] TO [EQAI]
    AS [dbo];

