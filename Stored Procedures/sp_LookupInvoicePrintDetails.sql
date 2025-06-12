use plt_ai 
go
DROP procedure sp_LookupInvoicePrintDetails
go
CREATE PROCEDURE sp_LookupInvoicePrintDetails
AS
/***********************************************************************
This SP is called from EQAI w_invoice_print_view.  It is called by a datastore to populate the 
treeview control on the window.  The retrieve can not happen with a simple SQL command due to 
the fact that the user has the ability to select multiple invoices for printing, which don't 
have to be in a neat range of invoice_codes.  As such a temporary table #InvoicePrintDetails 
will be populated with invoice_id and revision_id for all user selected invoices.  This procedure
will then use this temp table to return a result set that can be used by w_invoice_print_view.

This sp is loaded to Plt_AI.

04/23/2007 WAC	Created
10/11/2007 WAC	Changed invoice_date sort to descending.
11/02/2007 WAC	Removed distribution_method and mail_to_bill_to_address_flag from result set
11/06/2007 WAC	Result set now includes attention_name.
01/21/2016 SK	Added e-Billing
07/18/2016 SK	Added mail_to_bill_to_address_flag
02/09/2018 MPM	Added currency_code
03/22/2024 AM  DevOps:80655 -  Added invoicetemplate_email_subject_line and company_count fields.
05/24/2024 AM  DevOps:84932 - Added template logo related fields.
To test:
DROP Table #InvoicePrintDetails
CREATE TABLE #InvoicePrintDetails ( invoice_id int, revision_id int ) 

INSERT INTO #InvoicePrintDetails
VALUES ( 2049449, 1 )
-- select * from invoiceheader where invoice_code = '1032817'
EXEC sp_LookupInvoicePrintDetails
***********************************************************************/
BEGIN

SET NOCOUNT ON

--  Create a temporary table that we will populate fields
CREATE TABLE #InvWork (
	invoice_id int null,
	revision_id int null,
	customer_id int null,	-- need customer_id to get SQLServer to use CustomerBilling key properly for updates
	intervention_required_flag char(1) null,
	intervention_desc varchar(255) null,
	billing_project_id int null,
	ebilling_flag char(1) null, 
	mail_to_bill_to_addr_flag char(1) null)

--  populate with the appropriate invoice_id and revision_id from temp table created outside of
--  this procedure
INSERT INTO #InvWork (invoice_id, revision_id )
SELECT invoice_id, revision_id 
FROM #InvoicePrintDetails 

--  Add customer_id which is easy enough to get from InvoiceHeader
UPDATE #InvWork SET customer_id = IH.customer_id
FROM #InvWork IW
JOIN InvoiceHeader IH ON IH.invoice_id = IW.invoice_id AND IH.revision_id = IW.revision_id

--  stuff in a billing_project_ID.  Any billing_project from the InvoiceDetail
--  record will do because invoice creation will not allow billing projects to be combined
--  on the same invoice unless pertinent parameters of the projects are the same
UPDATE #InvWork SET billing_project_id = IDT.billing_project_id
FROM #InvWork IW
JOIN InvoiceDetail IDT ON IDT.invoice_id = IW.invoice_id AND IDT.revision_id = IW.revision_id

--  stuff in parameters from the CustomerBilling table for this customer,
UPDATE #InvWork 
SET intervention_required_flag = CB.intervention_required_flag,
    intervention_desc = CB.intervention_desc,
    ebilling_flag = CB.ebilling_flag,
    mail_to_bill_to_addr_flag = CB.mail_to_bill_to_address_flag
FROM #InvWork IW 
JOIN CustomerBilling CB ON CB.customer_id = IW.customer_id AND CB.billing_project_id = IW.billing_project_id

SELECT	IH.invoice_id,
	IH.revision_id,
	IH.invoice_code,
	IH.status,
	IH.invoice_date,
	IH.customer_id,
	IH.cust_name,
	IH.addr1,
	IH.addr2,
	IH.addr3,
	IH.addr4,
	IH.addr5,
	IH.city,
	IH.state,
	IH.zip_code,
	IH.attention_name,
	IH.total_amt_due,
	IH.due_date,
	IH.invoice_image_id,
	IH.attachment_image_id,
	IW.intervention_required_flag,
	IW.intervention_desc,
	IW.billing_project_id,
	IA.company_id,
	IA.profit_ctr_id,
	IA.trans_source,
	IA.receipt_id,
	IA.manifest,
	IA.approval_code,
	IA.generator_id,
	IA.scan_type,
	IA.document_type,
	IA.document_name,
	IA.file_type,
	IA.image_id,
	IW.ebilling_flag,
	IW.mail_to_bill_to_addr_flag,
	IH.currency_code,
    (  select COALESCE(
		(select t.email_subject_line 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = IH.invoice_id
						   AND h.revision_id = IH.revision_id 
					   )
		)
	     ,
		(select t.email_subject_line
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = IH.invoice_id
						   AND d.revision_id = IH.revision_id 
					   )
		)
	   ) ) as invoicetemplate_email_subject_line,
    dbo.fn_get_invoice_template ( IH.invoice_id,  IH.revision_id ) as company_count,
  (  select COALESCE(
		(select t.logo_to_use 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = IH.invoice_id
						   AND h.revision_id = IH.revision_id 
					   )
		)
	     ,
		(select t.logo_to_use
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = IH.invoice_id
						   AND d.revision_id = IH.revision_id 
					   )
		)
	   ) )  as invoicetemplate_logo_to_use,
  (  select COALESCE(
		(select t.logo_x_position 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = IH.invoice_id
						   AND h.revision_id = IH.revision_id 
					   )
		)
	     ,
		(select t.logo_x_position
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = IH.invoice_id
						   AND d.revision_id = IH.revision_id 
					   )
		)
	   ) ) as logo_x_position,
	(  select COALESCE(
		(select t.logo_y_position 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = IH.invoice_id
						   AND h.revision_id = IH.revision_id 
					   )
		)
	     ,
		(select t.logo_y_position
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = IH.invoice_id
						   AND d.revision_id = IH.revision_id 
					   )
		)
	   ) ) as logo_y_position,
    (  select COALESCE(
		(select t.logo_width 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = IH.invoice_id
						   AND h.revision_id = IH.revision_id 
					   )
		)
	     ,
		(select t.logo_width
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = IH.invoice_id
						   AND d.revision_id = IH.revision_id 
					   )
		)
	   ) )   as logo_width,
	(  select COALESCE(
		(select t.logo_height 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = IH.invoice_id
						   AND h.revision_id = IH.revision_id 
					   )
		)
	     ,
		(select t.logo_height
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = IH.invoice_id
						   AND d.revision_id = IH.revision_id 
					   )
		)
	   ) )  as logo_height,
	(  select IsNull (  COALESCE(
		(select t.thankyou_note 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = IH.invoice_id
						   AND h.revision_id = IH.revision_id 
					   )
		)
	     ,	
		(select t.thankyou_note
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = IH.invoice_id
						   AND d.revision_id = IH.revision_id 
					   )
		)
	   ) , 'Republic Services' ) )as thankyou_note
FROM InvoiceHeader IH
JOIN #InvWork IW ON IW.invoice_id = IH.invoice_id AND IW.revision_id = IH.revision_id
LEFT OUTER JOIN InvoiceAttachment IA ON IA.invoice_id = IW.invoice_id AND IA.revision_id = IW.revision_id
ORDER BY IH.cust_name, IH.customer_id, IH.invoice_date DESC, IH.invoice_code

--  drop the temp table that we created
DROP TABLE #InvWork

END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_LookupInvoicePrintDetails] TO [EQAI];
GO