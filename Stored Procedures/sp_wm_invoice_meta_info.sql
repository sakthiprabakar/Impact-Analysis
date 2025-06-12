
CREATE PROCEDURE sp_wm_invoice_meta_info (
	@invoice_code varchar(16)
)
AS
/* *************************************
sp_wm_invoice_meta_info
  Retrieves information about a WM Invoice for header rows.
  Accepts input: 
      invoice_code to view

06/01/2012 - JPB - Created
10/14/2013 - JPB - Fix for Receipt select pulling receipt_dates, not receipttransporter sign dates.

sp_wm_invoice_meta_info '40488370'


select top 1 wba.* 
, 'EQ_' +
	CASE wba.wm_account_id 
		WHEN 4490 THEN 'Routine'
		WHEN 6015 THEN 'Off-Schedule'
		ELSE 'Other'
	END +
	' ' +
	CASE wba.wm_division_id
		WHEN 1 THEN 'Walmart'
		WHEN 18 THEN 'Sams Club'
		ELSE 'Other'
	END + 
	'_Invoice#' +
	b.invoice_code +
	'_' +
	right('00' + convert(varchar(2), DATEPART(mm, getdate())), 2) + 
	right('00' + convert(varchar(2), DATEPART(dd, getdate())), 2) + 
	right(convert(varchar(4), DATEPART(yyyy, getdate())), 2)
as filename
FROM Billing b
INNER JOIN WalmartBillingAccount wba
	ON b.billing_project_id = wba.billing_project_id
WHERE b.invoice_code = '40283596'

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

declare @mindate date, @maxdate date
select @mindate = min(service_date), @maxdate = max(service_date) from #dates

select top 1 
/*
	'EQ_' +
	CASE wba.wm_account_id 
		WHEN 4490 THEN 'Routine'
		WHEN 6015 THEN 'Off-Schedule'
		ELSE 'Other'
	END +
	' ' +
	CASE wba.wm_division_id
		WHEN 1 THEN 'Walmart'
		WHEN 18 THEN 'Sams Club'
		ELSE 'Other'
	END + 
	'_Invoice#' +
	b.invoice_code +
	'_' +
	right('00' + convert(varchar(2), DATEPART(mm, getdate())), 2) + 
	right('00' + convert(varchar(2), DATEPART(dd, getdate())), 2) + 
	right(convert(varchar(4), DATEPART(yyyy, getdate())), 2)
	as filename
*/	
	257170 AS Vendor_Number
	, ih.invoice_code as Invoice_Code
	, ih.invoice_date
	, convert(varchar(20), @mindate, 101) +
		' - ' +
		convert(varchar(20), @maxdate, 101)
	AS service_dates
	, t.terms_desc
FROM InvoiceDetail id
INNER JOIN InvoiceHeader ih ON id.invoice_id = ih.invoice_id AND id.revision_id = ih.revision_id
INNER JOIN arterms t on ih.terms_code = t.terms_code
LEFT OUTER JOIN CustomerBilling bp ON id.billing_project_id = bp.billing_project_id AND ih.customer_id = bp.customer_id
WHERE ih.invoice_id = @invoice_id AND ih.revision_id = @revision_id
AND ih.status = 'I'


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_invoice_meta_info] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_invoice_meta_info] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wm_invoice_meta_info] TO [EQAI]
    AS [dbo];

