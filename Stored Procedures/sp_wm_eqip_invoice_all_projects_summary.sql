
CREATE PROCEDURE sp_wm_eqip_invoice_all_projects_summary (
	@invoice_code varchar(16)
)
AS
/* *************************************
sp_wm_eqip_invoice_all_projects_summary
  WM-formatted export of invoice summary data.
  Accepts input: 
      invoice_code to view

10/27/2010 - JPB - Created
01/31/2010 - JPB - Rewrote the min/max service date field selects as more efficient sub-selects
	- instead of an inefficient join, because for 40283596 it was verrrry slow. (20+mins)
09/23/2011 - JPB - Branch of sp_wm_invoice_summary for listing just WM Billing Projects
   - when invoices may now have more than 1 BP per invoice
10/14/2013 - JPB - Fix for Receipt select pulling receipt_dates, not receipttransporter sign dates.

sp_wm_eqip_invoice_all_projects_summary '40488370'

************************************* */

CREATE TABLE #dates (
	service_date	datetime
)

DECLARE @invoice_id int, @revision_id int

SELECT @invoice_id = invoice_id, @revision_id = revision_id
FROM invoiceheader WHERE invoice_code = @invoice_code AND status = 'I'

INSERT #dates
	SELECT 
		coalesce(rt1.transporter_sign_date, receipt_date) as service_date
	FROM receipt r 
	inner join (
		select 
			receipt_id, 
			company_id, 
			profit_ctr_id, 
			invoice_id, 
			revision_id 
		FROM invoicedetail 
		WHERE invoice_id = @invoice_id
		and revision_id = @revision_id
		and trans_source='R') idr
	ON r.receipt_id = idr.receipt_id and r.company_id = idr.company_id and r.profit_ctr_id = idr.profit_ctr_id
	LEFT JOIN ReceiptTransporter rt1 on r.receipt_id = rt1.receipt_id and r.company_id = rt1.company_id and r.profit_ctr_id = rt1.profit_ctr_id
		and rt1.transporter_sequence_id = 1
	WHERE NOT EXISTS (
		select 1 
		FROM billinglinklookup bll 
		inner join (
			select 
				receipt_id, 
				company_id, 
				profit_ctr_id, 
				invoice_id, 
				revision_id 
			FROM invoicedetail 
			WHERE invoice_id = @invoice_id
			and revision_id = @revision_id
			and trans_source='W') idw
		ON bll.source_id = idw.receipt_id 
		and bll.source_company_id = idw.company_id 
		and bll.source_profit_ctr_id = idw.profit_ctr_id
		WHERE bll.receipt_id = r.receipt_id 
		and bll.company_id = r.company_id 
		and bll.profit_ctr_id = r.profit_ctr_id 
	)
	
INSERT #dates
	SELECT 
	coalesce(wos.date_act_arrive, wos.date_est_arrive, woh.start_date) as service_date
	FROM workorderheader woh
	inner join (
		select 
			receipt_id, 
			company_id, 
			profit_ctr_id, 
			invoice_id, 
			revision_id 
		FROM invoicedetail 
		WHERE invoice_id = @invoice_id
		and revision_id = @revision_id
		and trans_source='W') idw
	ON woh.workorder_id = idw.receipt_id 
	and woh.company_id = idw.company_id 
	and woh.profit_ctr_id = idw.profit_ctr_id
	LEFT JOIN WorkOrderStop wos ON wos.workorder_id = woh.workorder_id
		and wos.company_id = woh.company_id
		and wos.profit_ctr_id = woh.profit_ctr_id
		and wos.stop_sequence_id = 1 /* this will change in the future when there is more than 1 stop per workorder */

DELETE FROM #dates WHERE service_date IS null

SELECT DISTINCT
	ih.invoice_code
	, ih.invoice_id
	, ih.invoice_date
	, 257170 AS Vendor_Number
	, ih.total_amt_disposal AS Material
	, ih.total_amt_project AS Labor
	, 0 AS Shipping
	, ih.total_amt_disposal + ih.total_amt_project AS Invoice_SubTotal
	, ih.total_amt_srcharge_h + ih.total_amt_srcharge_p + ih.total_amt_insurance+ ih.total_amt_energy AS Tax
	, ih.total_amt_due AS Total_Invoice_Cost
	, t.terms_desc
	, ih.days_due
	, (select min(service_date) from #dates) AS min_service_date
	, (select max(service_date) from #dates) AS max_service_date
	, 'Walmart/Sams Club' as invoice_type
FROM InvoiceHeader ih
INNER JOIN arterms t on ih.terms_code = t.terms_code
WHERE ih.invoice_id = @invoice_id AND ih.revision_id = @revision_id
AND ih.status = 'I'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_eqip_invoice_all_projects_summary] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_eqip_invoice_all_projects_summary] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_eqip_invoice_all_projects_summary] TO [EQAI]
    AS [dbo];

