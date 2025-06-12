
CREATE PROCEDURE sp_wm_eqip_invoice_wm_projects_description (
	@invoice_code varchar(16)
)
AS
/* *************************************
sp_wm_eqip_invoice_wm_projects_description
  WM-formatted export of invoice summary data.
  Accepts input: 
      invoice_code to view

10/27/2010 - JPB - Created
01/31/2010 - JPB - Rewrote the min/max service date field selects as more efficient sub-selects
	- instead of an inefficient join, because for 40283596 it was verrrry slow. (20+mins)
09/23/2011 - JPB - Branch of sp_wm_invoice_summary for listing just WM Billing Projects
   - when invoices may now have more than 1 BP per invoice
10/14/2013 - JPB - Fix for Receipt select pulling receipt_dates, not receipttransporter sign dates.

sp_wm_eqip_invoice_wm_projects_description '40488370'

************************************* */

DECLARE @invoice_id int, @revision_id int

SELECT @invoice_id = invoice_id, @revision_id = revision_id
FROM invoiceheader WHERE invoice_code = @invoice_code AND status = 'I'

CREATE TABLE #dates (
	service_date	datetime
)

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


SELECT ih.invoice_code
	, ih.invoice_id
	, ih.invoice_date
	, id.billing_project_id
	, bp.billing_project_comment
	, bp.project_name
	, (select min(service_date) from #dates) AS min_service_date
	, (select max(service_date) from #dates) AS max_service_date
	, sum( case when bd.billing_type = 'Disposal' then bd.extended_amt else 0 end) as disposal_amt
	, sum( case when bd.billing_type = 'Energy' then bd.extended_amt else 0 end) as energy_amt
	, sum( case when bd.billing_type = 'Insurance' then bd.extended_amt else 0 end) as insurance_amt
	, sum( case when bd.billing_type = 'Product' then bd.extended_amt else 0 end) as product_amt
	, sum( case when bd.billing_type = 'Retail' then bd.extended_amt else 0 end) as retail_amt
	, sum( case when bd.billing_type = 'SalesTax' then bd.extended_amt else 0 end) as salestax_amt
	, sum( case when bd.billing_type = 'State-Haz' then bd.extended_amt else 0 end) as state_haz_amt
	, sum( case when bd.billing_type = 'State-Perp' then bd.extended_amt else 0 end) as state_perp_amt
	, sum( case when bd.billing_type = 'Wash' then bd.extended_amt else 0 end) as wash_amt
	, sum( case when bd.billing_type = 'Workorder' then bd.extended_amt else 0 end) as workorder_amt
FROM InvoiceDetail id
INNER JOIN InvoiceHeader ih ON id.invoice_id = ih.invoice_id AND id.revision_id = ih.revision_id
INNER JOIN Billing b on id.invoice_id = b.invoice_id AND b.status_code = 'I'
	AND id.company_id = b.company_id and id.profit_ctr_id = b.profit_ctr_id and id.trans_source = b.trans_source
	and id.receipt_id = b.receipt_id and id.line_id = b.line_id and id.price_id = b.price_id
INNER JOIN BillingDetail bd on b.receipt_id = bd.receipt_id and b.line_id = bd.line_id and b.price_id = bd.price_id and b.trans_source = bd.trans_source and b.profit_ctr_id = bd.profit_ctr_id and b.company_id = bd.company_id
LEFT OUTER JOIN CustomerBilling bp ON id.billing_project_id = bp.billing_project_id AND ih.customer_id = bp.customer_id
WHERE ih.invoice_id = @invoice_id AND ih.revision_id = @revision_id
AND ih.status = 'I'
and bp.project_name like 'Walmart%'
group by 
	ih.invoice_code
	, ih.invoice_id
	, ih.invoice_date
	, id.billing_project_id
	, bp.billing_project_comment
	, bp.project_name
order by id.billing_project_id


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_eqip_invoice_wm_projects_description] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_eqip_invoice_wm_projects_description] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_eqip_invoice_wm_projects_description] TO [EQAI]
    AS [dbo];

