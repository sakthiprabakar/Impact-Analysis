
CREATE PROCEDURE sp_dash_linked_revenue (
	@StartDate 	datetime,
	@EndDate 	datetime,
	@user_code 	varchar(100) = NULL, -- for associates
	@contact_id	int = NULL, -- for customers
	@permission_id int
)
AS
/************************************************************
Procedure    : sp_dash_linked_revenue
Database     : PLT_AI
Created      : Oct 20, 2009 - Jonathan Broome
Description  : Returns data on Linked transactions
	between @StartDate AND @EndDate

10/20/2009 JPB	Created
04/08/2013 JDB	Modified to show the full amounts from BillingDetail lines
				instead of just the Billing.waste_extended_amt.
11/13/2013 AM   Added new 2(jde_bu and jde_object) fields to select for JDE Report.

sp_dash_linked_revenue 
	@StartDate='2013-01-01 00:00:00',
	@EndDate='2013-01-31 23:59:59',
	@user_code='JASON_B',
	@contact_id=-1,
	@permission_id = 0
	
************************************************************/

IF @user_code = ''
	set @user_code = NULL
	
IF @contact_id = -1
	set @contact_id = NULL

	
select  convert(varchar(2), b.company_id) 
		+ '-'
        + convert(varchar(2), b.profit_ctr_id) as 'Billed From',
		pr.profit_ctr_name as 'Billed From Name',
        convert(varchar(2), bl.source_company_id) 
		+ '-'
        + convert(varchar(2), bl.source_profit_ctr_id) as 'Linked To',
		prl.profit_ctr_name as 'Linked To Name',
        w.start_date,
        b.invoice_date,
        b.customer_id,
		c.cust_name,
        b.trans_source,
        b.billing_date,
        b.company_id,
        b.Profit_ctr_id,
        b.Receipt_id,
        bl.source_company_id,
        bl.source_Profit_ctr_id,
        bl.source_id,
        --b.gl_account_code,
        --b.waste_extended_amt,
        bd.gl_account_code,
        SUM(bd.extended_amt) AS waste_extended_amt,
        g.generator_state,
        bd.jde_bu,
        bd.jde_object
from    billing b
JOIN BillingDetail bd ON bd.billing_uid = b.billing_uid
join billinglinklookup bl 
	on b.receipt_id = bl.receipt_id
	and b.company_id = bl.company_id
	and b.profit_ctr_id = bl.profit_ctr_id
join workorderheader w 
	on bl.source_id = w.workorder_id
	and w.company_id = bl.source_company_id
	and w.profit_ctr_id = bl.source_profit_ctr_id
join generator g 
	on g.generator_id = b.generator_id
INNER JOIN customer c
	on b.customer_id = c.customer_id
INNER JOIN ProfitCenter copc
	ON b.company_id = copc.company_id 
	AND b.profit_ctr_id = copc.profit_ctr_id
	AND copc.status = 'A'
INNER JOIN ProfitCenter pr
	ON b.company_id = pr.company_id
	AND b.profit_ctr_id = pr.profit_ctr_id
INNER JOIN ProfitCenter prl
	ON bl.company_id = prl.company_id
	AND bl.profit_ctr_id = prl.profit_ctr_id
INNER JOIN Customer customer ON customer.customer_id = b.customer_id	
where   
	b.billing_date > '01-01-2008'
	and b.invoice_date BETWEEN @StartDate AND @EndDate
	and b.status_code = 'i'
GROUP BY b.company_id
	, b.profit_ctr_id
	, pr.profit_ctr_name
    , bl.source_company_id
	, bl.source_profit_ctr_id
	, prl.profit_ctr_name
    , w.start_date
    , b.invoice_date
    , b.customer_id
	, c.cust_name
    , b.trans_source
    , b.billing_date
    , b.company_id
    , b.Profit_ctr_id
    , b.Receipt_id
    , bl.source_company_id
    , bl.source_Profit_ctr_id
    , bl.source_id
    , bd.gl_account_code
    , g.generator_state
    , bd.jde_bu
    , bd.jde_object


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_linked_revenue] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_linked_revenue] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_dash_linked_revenue] TO [EQAI]
    AS [dbo];

