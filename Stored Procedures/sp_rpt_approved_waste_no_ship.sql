CREATE PROCEDURE sp_rpt_approved_waste_no_ship 
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@approval_from	varchar(15)
,	@approval_to	varchar(15)
,	@customer_id_from	int
,	@customer_id_to		int
AS
/***********************************************************************************
Modifications:
11/21/2005 SCC	Created
07/18/2006 rg   revised for quoteheader quotedetail
05/07/2007 rg   changed for central invoicing 
11/05/2010 SK	Added company_id as input arg, added joins to company
				moved to Plt_AI

select * from approval where approval_code = 'SCTESTERLONGEST'

sp_rpt_approved_waste_no_ship 21, 0, '1/1/2005', '1/31/2005', '0', 'ZZ', 0, 999999
***********************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


SELECT DISTINCT
	pqa.approval_code
,	p.customer_id
,	c.cust_name
,	cb.territory_code
,	g.EPA_ID
,	g.generator_name
,	p.approval_desc
,	pqa.purchase_order
,	pqa.release
,	p.ap_start_date
,	pqa.company_id
,	pqa.profit_ctr_id
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM ProfileQuoteApproval pqa
JOIN Company
	ON Company.company_id = pqa.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = pqa.company_id
	AND ProfitCenter.profit_ctr_ID = pqa.profit_ctr_id
JOIN Profile p
	ON p.profile_id = pqa.profile_id
	AND p.curr_status_code = 'A'
	AND p.ap_expiration_date >= getdate()
	AND p.ap_start_date BETWEEN @date_from and @date_to
	AND p.customer_id BETWEEN @customer_id_from and @customer_id_to
JOIN Customer c
	ON c.customer_ID = p.customer_id
JOIN CustomerBilling cb
	ON cb.customer_id = p.customer_id
	AND cb.billing_project_id = IsNull(pqa.billing_project_id,0)
JOIN Generator g
	ON g.generator_id = p.generator_id
WHERE	(@company_id = 0 OR pqa.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR pqa.profit_ctr_id = @profit_ctr_id)
	AND pqa.confirm_update_date IS NOT NULL
	AND pqa.approval_code between @approval_from and @approval_to
	AND NOT EXISTS (SELECT Receipt.approval_code FROM Receipt
						WHERE pqa.approval_code = Receipt.approval_code
							AND pqa.profit_ctr_id = Receipt.profit_ctr_id
							AND pqa.company_id = Receipt.company_id
							AND Receipt.receipt_status NOT IN ('V', 'T')
							AND Receipt.trans_mode = 'I' )

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_approved_waste_no_ship] TO [EQAI]
    AS [dbo];

