CREATE OR ALTER PROCEDURE sp_invoice_print_waste_summary
	@invoice_id int,
    @revision_id int
AS
/***********************************************************************
Disposal Invoices
Filename:	F:\EQAI\SQL\EQAI\sp_print_invoices.sql
PB Object(s):	d_print_waste_receipt_invoice
		d_print_waste_receipt_invoice_summary

03/28/2007  rg  created for new invocie process
08/13/2007 SCC	Changed to use line_desc_1
06/18/2015 RB   set transaction isolation level read uncommitted
11/08/2016 MPM	GEM 39485 - Receipt Waste Summary - Corrected invoice document rounding issue 
06/04/2018 - AM - GEM:47960 - Invoice Print - Added currency code to printed document.
07/05/2024 KS	Rally117980 - Modified datatype for #invoice_tmp.line_desc to VARCHAR(100)
09/23/2024 Subhrajyoti - Rally#DE35097 - [DEFECT] - EQAI Incorrect Logos on Backup Documentation

exec sp_invoice_Print_waste_summary 364772,1
exec sp_invoice_print_waste_summary 75821,1
***********************************************************************/

set transaction isolation level read uncommitted

SET NOCOUNT ON

DECLARE @inv_count int

CREATE TABLE #invoice_tmp (
	address_name 		varchar(40) null, 
	addr1 			varchar(40) null, 
	addr2 			varchar(40) null, 
	addr3 			varchar(40) null, 
	addr4 			varchar(40) null, 
	addr5 			varchar(40) null, 
	invoice_code 		varchar(16) null, 
	company_id		int null, 
	profit_ctr_id 		int null, 
	customer_id 		int null, 
	date_doc 		datetime null, 
	approval_code 		varchar(15) null, 
	bill_unit_code 		char(4) null, 
	unit_code 		varchar(8) null,  
	qty_ordered 		float null, 
	unit_price 		float null, 
	line_desc 		varchar(100) null,
	sr_type_code 		char(1) null,
	location_code 		varchar(8) null,
	invoice_id		int null,
    revision_id		int null,
    sequence_id             int null,
	generator_id  int null,
	generator_name varchar(40) null,
	profit_ctr_name varchar(50) null,
	pc_addr_1 varchar(40) null,
	pc_addr_2 varchar(40) null, 
	pc_phone varchar(14) null,
	pc_fax varchar(14) null,
	ext_price float null,
	currency_code varchar (3),
	invoice_template_id INT NULL,
	invoicetemplate_template_code Varchar(60) NULL,
	invoicetemplate_logo_to_use Varchar(200) NULL,
	invoicetemplate_invoice_section Varchar(50) NULL,
	invoicetemplate_remit_to Varchar(100) NULL,
	invoicetemplate_address_1 Varchar(40) NULL,
	invoicetemplate_address_2 Varchar(40) NULL,
	invoicetemplate_address_3 Varchar(40) NULL,
	invoicetemplate_email_subject_line Varchar(60) NULL,
	company_count Int NULL,
	logo_x_position INT NULL,
	logo_y_position INT NULL,
	logo_width INT NULL,
	logo_height INT NULL)


INSERT INTO #invoice_tmp (
	address_name, 
	addr1, 
	addr2, 
	addr3, 
	addr4, 
	addr5, 
	invoice_code, 
	company_id, 
	profit_ctr_id, 
	customer_id, 
	date_doc, 
	approval_code, 
	bill_unit_code, 
	unit_code,  
	qty_ordered, 
	unit_price, 
	line_desc,
	sr_type_code,
	location_code,
	invoice_id,
        revision_id,
        sequence_id,
	generator_id,
	generator_name,
	profit_ctr_name,
	pc_addr_1,
	pc_addr_2, 
	pc_phone,
	pc_fax,
	ext_price,
	currency_code,
	invoice_template_id,
	invoicetemplate_template_code,
	invoicetemplate_logo_to_use,
	invoicetemplate_invoice_section,
	invoicetemplate_remit_to,
	invoicetemplate_address_1,
	invoicetemplate_address_2,
	invoicetemplate_address_3,
	invoicetemplate_email_subject_line,
	company_count,
	logo_x_position,
	logo_y_position,
	logo_width,
	logo_height)

SELECT DISTINCT
	MAX(InvoiceHeader.cust_name), 
	MAX(InvoiceHeader.addr1), 
	MAX(InvoiceHeader.addr2), 
	MAX(InvoiceHeader.addr3), 
	MAX(InvoiceHeader.addr4), 
	MAX(InvoiceHeader.addr5),  
	MAX(InvoiceHeader.invoice_code),
        InvoiceDetail.company_id,
        InvoiceDetail.profit_ctr_id,  
	max(InvoiceHeader.customer_id), 
	max(InvoiceHeader.invoice_date), 
	InvoiceDetail.approval_code, 
	InvoiceDetail.bill_unit_code, 
	InvoiceDetail.unit_code, 
	SUM(InvoiceDetail.qty_ordered), 
	InvoiceDetail.unit_price, 
	InvoiceDetail.line_desc_1,
	InvoiceDetail.sr_type_code,
	InvoiceDetail.location_code,
	InvoiceDetail.invoice_id,
        InvoiceDetail.revision_id,
        Max(InvoiceDetail.sequence_id),
	max(invoicedetail.generator_id),
	max(invoicedetail.generator_name),
	max(profitcenter.profit_ctr_name),
	max(profitcenter.address_1),
	max(profitcenter.address_2), 
	max(profitcenter.phone),
	max(profitcenter.fax),
	SUM(round((InvoiceDetail.qty_ordered * InvoiceDetail.unit_price) + 0.005,2,1)),
	InvoiceHeader.currency_code,
	(select COALESCE(
		(select t.invoice_template_id 
			from InvoiceTemplate t
				join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
					and c.invoice_template_id > 0 
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
							FROM InvoiceHeader h
							WHERE h.invoice_id = @invoice_id
							AND h.revision_id = @revision_id 
						)
		)
	     ,
		(select t.invoice_template_id
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = @invoice_id
						   AND d.revision_id = @revision_id 
					   )
		)
	   ) ) as invoice_template_id,
	(  select COALESCE(
		(select t.template_code 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
				 and c.invoice_template_id > 0 
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = @invoice_id
						   AND h.revision_id = @revision_id 
					   )
		)
	     ,
		(select t.template_code
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = @invoice_id
						   AND d.revision_id = @revision_id 
					   )
		)
	   ) )  as invoicetemplate_template_code,
	(  select COALESCE(
		(select t.logo_to_use 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
				 and c.invoice_template_id > 0 
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = @invoice_id
						   AND h.revision_id = @revision_id 
					   )
		)
	     ,
		(select t.logo_to_use
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = @invoice_id
						   AND d.revision_id = @revision_id 
					   )
		)
	   ) )  as invoicetemplate_logo_to_use,
	(  select COALESCE(
		(select t.invoice_section 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
				 and c.invoice_template_id > 0 
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = @invoice_id
						   AND h.revision_id = @revision_id 
					   )
		)
	     ,
		(select t.invoice_section
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = @invoice_id
						   AND d.revision_id = @revision_id 
					   )
		)
	   ) )  as invoicetemplate_invoice_section,
    (  select COALESCE(
		(select t.remit_to 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
				 and c.invoice_template_id > 0 
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = @invoice_id
						   AND h.revision_id = @revision_id 
					   )
		)
	     ,
		(select t.remit_to
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = @invoice_id
						   AND d.revision_id = @revision_id 
					   )
		)
	   ) )  as invoicetemplate_remit_to,
     (  select COALESCE(
		(select t.address_1 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
				 and c.invoice_template_id > 0 
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = @invoice_id
						   AND h.revision_id = @revision_id 
					   )
		)
	     ,
		(select t.address_1
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = @invoice_id
						   AND d.revision_id = @revision_id 
					   )
		)
	   ) )as invoicetemplate_address_1,
     (  select COALESCE(
		(select t.address_2 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
				 and c.invoice_template_id > 0 
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = @invoice_id
						   AND h.revision_id = @revision_id 
					   )
		)
	     ,
		(select t.address_2
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = @invoice_id
						   AND d.revision_id = @revision_id 
					   )
		)
	   ) ) as invoicetemplate_address_2,
     (  select COALESCE(
		(select t.address_3 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
				 and c.invoice_template_id > 0 
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = @invoice_id
						   AND h.revision_id = @revision_id 
					   )
		)
	     ,
		(select t.address_3
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = @invoice_id
						   AND d.revision_id = @revision_id 
					   )
		)
	   ) ) as invoicetemplate_address_3,
    (  select COALESCE(
		(select t.email_subject_line 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
				 and c.invoice_template_id > 0 
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = @invoice_id
						   AND h.revision_id = @revision_id 
					   )
		)
	     ,
		(select t.email_subject_line
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = @invoice_id
						   AND d.revision_id = @revision_id 
					   )
		)
	   ) ) as invoicetemplate_email_subject_line,
     dbo.fn_get_invoice_template ( @invoice_id,  @revision_id ) as company_count,
  (  select COALESCE(
		(select t.logo_x_position 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
				 and c.invoice_template_id > 0 
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = @invoice_id
						   AND h.revision_id = @revision_id 
					   )
		)
	     ,
		(select t.logo_x_position
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = @invoice_id
						   AND d.revision_id = @revision_id 
					   )
		)
	   ) ) as logo_x_position,
	(  select COALESCE(
		(select t.logo_y_position 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
				 and c.invoice_template_id > 0 
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = @invoice_id
						   AND h.revision_id = @revision_id 
					   )
		)
	     ,
		(select t.logo_y_position
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = @invoice_id
						   AND d.revision_id = @revision_id 
					   )
		)
	   ) ) as logo_y_position,
    (  select COALESCE(
		(select t.logo_width 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
				 and c.invoice_template_id > 0 
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = @invoice_id
						   AND h.revision_id = @revision_id 
					   )
		)
	     ,
		(select t.logo_width
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = @invoice_id
						   AND d.revision_id = @revision_id 
					   )
		)
	   ) )   as logo_width,
	(  select COALESCE(
		(select t.logo_height 
		  from InvoiceTemplate t
			   join CustomerInvoiceTemplate c on t.invoice_template_id = c.invoice_template_id
				 and c.invoice_template_id > 0 
					and c.customer_id = (
						SELECT MAX(customer_id) as customer_id
						  FROM InvoiceHeader h
						 WHERE h.invoice_id = @invoice_id
						   AND h.revision_id = @revision_id 
					   )
		)
	     ,
		(select t.logo_height
		  from InvoiceTemplate t
			   join Company c on t.invoice_template_id = c.invoice_template_id
					and c.company_id = (
						SELECT MAX(company_id) as company_id
						  FROM InvoiceDetail d
						 WHERE d.invoice_id = @invoice_id
						   AND d.revision_id = @revision_id 
					   )
		)
	   ) )  AS logo_height
 FROM 	InvoiceDetail
	JOIN InvoiceHeader ON InvoiceDetail.invoice_id = InvoiceHeader.invoice_id
		and InvoiceDetail.revision_id = InvoiceHeader.revision_id 
        join profitcenter on invoicedetail.company_id = profitcenter.company_id
		and invoicedetail.profit_ctr_id = profitcenter.profit_ctr_id
 WHERE  (InvoiceDetail.location_code = 'EQAI-LR' OR InvoiceDetail.location_code = 'EQAI-ST')
	and InvoiceDetail.invoice_id = @invoice_id
	and InvoiceDetail.revision_id = @revision_id
	AND InvoiceDetail.invoice_type = 'D'
GROUP BY InvoiceDetail.invoice_id,
         InvoiceDetail.revision_id,
         InvoiceDetail.company_id,
         InvoiceDetail.profit_ctr_id,
	InvoiceDetail.approval_code, 
	InvoiceDetail.bill_unit_code, 
	InvoiceDetail.unit_code,
	InvoiceDetail.unit_price, 
	InvoiceDetail.line_desc_1,
	InvoiceDetail.sr_type_code,
	InvoiceDetail.location_code,
	InvoiceHeader.currency_code
	
SELECT 	address_name, 
	addr1, 
	addr2, 
	addr3, 
	addr4, 
	addr5, 
	invoice_code, 
	company_id, 
	profit_ctr_id , 
	customer_id, 
	date_doc, 
	approval_code, 
	bill_unit_code, 
	unit_code,  
	qty_ordered, 
	unit_price, 
	line_desc,
	sr_type_code,
	location_code,
	invoice_id,
        revision_id,
        sequence_id,
		generator_id,
	generator_name,
	profit_ctr_name,
	pc_addr_1,
	pc_addr_2, 
	pc_phone,
	pc_fax,
	ext_price,
	currency_code,
	invoice_template_id,
	invoicetemplate_template_code,
	invoicetemplate_logo_to_use,
	invoicetemplate_invoice_section,
	invoicetemplate_remit_to,
	invoicetemplate_address_1,
	invoicetemplate_address_2,
	invoicetemplate_address_3,
	invoicetemplate_email_subject_line,
	company_count,
	logo_x_position,
	logo_y_position,
	logo_width,
	logo_height
FROM #invoice_tmp
order by company_id, 
         profit_ctr_id, 
		 generator_id,
         approval_code,
         location_code,
	 bill_unit_code

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_invoice_print_waste_summary] TO [EQAI]
    AS [dbo];

