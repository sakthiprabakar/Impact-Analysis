
CREATE PROCEDURE sp_rpt_invoice_audit 
AS
/***********************************************************************
This SP reports the workorders that show they have been submitted but there are no corresponding
billing lines and the successfully submitted workorders that have not yet been invoiced

Filename:	L:\Apps\SQL\EQAI\sp_rpt_invoice_audit.sql
PB Object(s):	d_rpt_invoice_audit

11/17/1999 SCC	Created
12/06/2004 JDB	Changed to sp_rpt_invoice_audit, Ticket to Billing
05/02/2007 rg   changed for central invoicing
01/18/2008 rg   changed for status flag
06/23/2014 AM   Moved to plt_ai

sp_rpt_invoice_audit
***********************************************************************/


SELECT DISTINCT
	COALESCE(cbw.invoice_flag,cbc.invoice_flag)as invoice_flag,
	woh.profit_ctr_id,
	woh.workorder_id,
	woh.customer_id, 
	CONVERT(varchar(40), Customer.cust_name) AS cust_name, 
	(SELECT territory_code
      FROM CustomerBilling AS CustomerBilling
      WHERE  (customer_id = Customer.customer_ID) 
      AND (billing_project_id = 0) AND (status = 'A')) AS territory_code, 
	woh.end_date,
	woh.date_modified, 
	woh.modified_by,
	CONVERT(varchar(30), 'Error-Not Transferred') AS reason,
	Company.company_name
FROM WorkOrderHeader woh
inner join Customer on woh.customer_id = customer.customer_id
left outer join CustomerBilling cbw on cbw.billing_project_id = woh.billing_project_id 
                      and cbw.customer_id = woh.customer_id
inner join CustomerBilling cbc on  cbc.customer_id = woh.customer_id
	and cbc.billing_project_id = 0,
     company
--WHERE woh.workorder_status = 'X'
WHERE ( woh.workorder_status = 'A' and isnull(woh.submitted_flag, 'F') = 'T' )
	AND woh.total_price > 0
        and not exists ( select 1 from billing b where b.receipt_id = woh.workorder_id
                         and b.profit_ctr_id = woh.profit_ctr_id
                         and b.company_id = woh.company_id
                         and b.trans_source = 'W' )
-- 	AND CONVERT(varchar(2), woh.profit_ctr_id) + '-' + CONVERT(varchar(30), woh.workorder_ID)
-- 	NOT IN (SELECT DISTINCT CONVERT(varchar(2), profit_ctr_id) + '-' + CONVERT(varchar(30), receipt_ID) FROM Billing WHERE waste_code = 'EQWO')
UNION ALL
-- 
--         S- submitted
--         H - hold
--         N- new
--         V- void 
--         I invocied
SELECT DISTINCT
	COALESCE(cbw.invoice_flag,cbc.invoice_flag) as invoice_flag,
	woh.profit_ctr_id,
	woh.workorder_id,
	woh.customer_id, 
	CONVERT(varchar(40), Customer.cust_name) AS cust_name, 
     (SELECT territory_code
      FROM CustomerBilling AS CustomerBilling
      WHERE  (customer_id = Customer.customer_ID) 
      AND (billing_project_id = 0) AND (status = 'A')) AS territory_code,
	woh.end_date,
	woh.date_modified, 
	woh.modified_by, 
	CASE b.status_code WHEN 'S' THEN CONVERT(varchar(30), 'Not Invoiced-Submitted') 
		WHEN 'N' THEN CONVERT(varchar(30), 'Not Invoiced-Validated')
         	WHEN 'H' THEN CONVERT(varchar(30), 'Not Invoiced-Hold')
		ELSE CONVERT(varchar(30), 'Not Invoiced-') + b.status_code END AS reason,
	Company.company_name 
FROM WorkOrderHeader woh 
inner join Billing b on woh.workorder_id = b.receipt_id
	AND woh.profit_ctr_id = b.profit_ctr_id
	AND woh.company_id = b.company_id
inner join Customer on woh.customer_id = customer.customer_id
left outer join CustomerBilling cbw on cbw.billing_project_id = woh.billing_project_id 
                and cbw.customer_id = woh.customer_id
inner join CustomerBilling cbc on cbc.customer_id = woh.customer_id
	and cbc.billing_project_id = 0,
     company
WHERE  ( woh.workorder_status = 'A' and isnull(woh.submitted_flag, 'F') = 'T' ) 
--woh.workorder_status = 'X'
	AND b.status_code NOT IN ('I','V')
	AND woh.total_price > 0
ORDER BY invoice_flag DESC,
woh.profit_ctr_id,
woh.workorder_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_invoice_audit] TO [EQAI]
    AS [dbo];

