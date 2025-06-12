CREATE PROCEDURE sp_rpt_reclaim 
	@company_id		int
,	@date_from		datetime
,	@date_to		datetime
,	@customer_from	int
,	@customer_to	int
AS
/***********************************************************************
Reclaim Report
PB Object(s):	r_reclaim
03/10/2004 JDB	Created
03/15/2004 JDB	Added receipt_date to select.
11/11/2004 MK	Changed generator_code to generator_id
12/29/2004 SCC	Changed to get pricing info from ReceiptPrice table
12/10/2010 SK	Added company_id as input arg and joins to company_id
				Moved to Plt_AI
				
select cust_category, * from customer where customer_id in (3743,3812,5844,2784,5856,2786)
update customer set cust_category = 'Reclaim' where customer_id in (3743,3812,5844,2784,5856,2786)

sp_rpt_reclaim 21, '1/1/10', '1/31/10', 1, 999999
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


DECLARE	@customer_list	varchar(200)

SELECT	@customer_list = COALESCE(@customer_list + ', ', '') + CAST(c.customer_id AS varchar(5))
FROM	Customer c
WHERE	c.cust_category = 'Reclaim'
	AND	c.customer_id BETWEEN @customer_from AND @customer_to
ORDER BY c.customer_id

SELECT	@customer_list = @customer_list + ' (Category = ''Reclaim'')'

SELECT	
	r.receipt_id
,	r.line_id
,	r.receipt_date
,	r.manifest
,	r.company_id
,	r.profit_ctr_id
,	r.customer_id
,	rp.bill_quantity
,	rp.bill_unit_code
,	rp.price
,	rp.total_extended_amt
,	r.approval_code
,	r.generator_id
,	r.product_id
,	r.product_code
,	p.description
,	b.gal_conv
,	r.receipt_status
,	r.trans_type
,	r.trans_mode
,	ISNULL(p.tran_flag, 'F') AS tran_flag
,	@customer_list AS customer_list
,	co.company_name
,	pc.profit_ctr_name
FROM Receipt r
JOIN Company co
	ON co.company_id = r.company_id
JOIN ProfitCenter pc
	ON pc.company_ID = r.company_id
	AND pc.profit_ctr_ID = r.profit_ctr_ID
INNER JOIN BillUnit b 
	ON r.bill_unit_code = b.bill_unit_code
INNER JOIN ReceiptPrice rp 
	ON r.receipt_id = rp.receipt_id
	AND r.line_id = rp.line_id
	AND r.company_id = rp.company_id
	AND r.profit_ctr_id = rp.profit_ctr_id
LEFT OUTER JOIN Product p 
	ON r.product_id = p.product_id
WHERE r.receipt_date BETWEEN @date_from AND @date_to
	AND r.customer_id BETWEEN @customer_from AND @customer_to
	AND r.customer_id IN (SELECT DISTINCT c.customer_id FROM Customer c WHERE c.cust_category = 'Reclaim')
	AND r.receipt_status = 'A'
	AND r.company_id = @company_id
	AND r.trans_type + r.trans_mode + ISNULL(p.tran_flag, 'F') <> 'SIF'	-- to exclude non-transportation services on inbound receipts
ORDER BY r.trans_mode, r.customer_id, r.receipt_id, ISNULL(p.tran_flag, 'F'), r.line_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_reclaim] TO [EQAI]
    AS [dbo];

