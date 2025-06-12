Create OR ALTER procedure sp_get_invoice_attachments ( 
	@invoice_id int, 
	@revision_id int) 
AS
/***************************************************************************************
Gets invoice attachments for an invoice

Filename:	L:\Apps\SQL\EQAI\Plt_AI\sp_get_invoice_attachments.sql
PB Object(s):	d_billing_validate

05/08/07 ???	Created
03/09/2010	KAM	Update the approval section to not update teh image desc if there was no profit center
05/10/2017 AM - 1.Remove deprecated SQL and replace with appropriate SQL syntax.(*= to LEFT OUTER JOIN etc.). 
03/13/2023 AGC DevOps 62472 add scan.page_number to the result set
09/23/2024 Subhrajyoti - Rally#DE35097 - [DEFECT] - EQAI Incorrect Logos on Backup Documentation

sp_get_invoice_attachments 451317,1
****************************************************************************************/
BEGIN

	CREATE table #invdata ( invoice_id int NULL ,
				revision_id int NULL ,
				invoice_code varchar(16) null,
				company_id int NULL ,
				profit_ctr_id int NULL ,
				trans_source char(1) NULL ,
				receipt_id int NULL ,
				manifest varchar(15)  NULL ,
				approval_code varchar(15) NULL ,
				generator_id int NULL ,
				scan_type varchar(30)  NULL ,
				document_type varchar(30)  NULL ,
				document_name varchar(50)  NULL ,
				file_type varchar(10)  NULL ,
				image_id int null,
				pagecount int null,
				title varchar(255) null,
				level int null,
				image_name varchar(255) null,
				generator_name varchar(60) null,
				customer_id int null,
				filename varchar(255) null,
				customer_name varchar(40) null,
				invoice_date datetime null,
				page_number int null,
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

	;WITH CustInvTemplate  AS
				(SELECT TOP 1 c.customer_id,t.invoice_template_id, t.template_code, t.logo_to_use, t.invoice_section, t.remit_to, t.address_1, t.address_2, t.address_3, t.email_subject_line, 
						t.logo_x_position, t.logo_y_position, t.logo_width, t.logo_height
				FROM InvoiceTemplate t
				JOIN CustomerInvoiceTemplate c ON t.invoice_template_id = c.invoice_template_id
				AND c.invoice_template_id > 0 
				AND c.customer_id = (SELECT MAX(customer_id) AS customer_id
									 FROM InvoiceHeader h
									 WHERE h.invoice_id = @invoice_id
									 AND h.revision_id = @revision_id)),

				CompInvTemplate AS
				(SELECT TOP 1 c.company_id,t.invoice_template_id, t.template_code, t.logo_to_use, t.invoice_section, t.remit_to, t.address_1, t.address_2, t.address_3, t.email_subject_line, 
							  t.logo_x_position, t.logo_y_position, t.logo_width, t.logo_height
				FROM InvoiceTemplate t
				JOIN Company c ON t.invoice_template_id = c.invoice_template_id
				AND c.company_id = (SELECT MAX(company_id) as company_id
									FROM InvoiceDetail d
									WHERE d.invoice_id = @invoice_id
									AND d.revision_id = @revision_id ))	
			
	insert #invdata			
	select 	a.invoice_id,
		a.revision_id,
		h.invoice_code,
		a.company_id,
		a.profit_ctr_id,
		a.trans_source,
		a.receipt_id,
		a.manifest,
		a.approval_code ,
		a.generator_id,
		a.scan_type,
		a.document_type,
		a.document_name,
		a.file_type,
		a.image_id,
		0 as pagecount,
		upper(left(a.document_type,1)) + lower(substring(a.document_type,2,30)) +  ' ' + upper(a.document_name) as title,
		0 as level,
		upper(left(a.scan_type,1)) + lower(substring(a.scan_type,2,30)) as image_name,
		g.generator_name,
		h.customer_id,
		null as filename,
		h.cust_name,
		h.invoice_date,
		s.page_number,
		COALESCE(cuit.invoice_template_id,coit.invoice_template_id) AS invoice_template_id,
		COALESCE(cuit.template_code,coit.template_code) AS invoicetemplate_template_code,
		COALESCE(cuit.logo_to_use, coit.logo_to_use) AS invoicetemplate_logo_to_use,
		COALESCE(cuit.invoice_section, coit.invoice_section) AS invoicetemplate_invoice_section,
		COALESCE(cuit.remit_to, coit.remit_to) AS invoicetemplate_remit_to,
		COALESCE(cuit.address_1, coit.address_1) AS invoicetemplate_address_1,
		COALESCE(cuit.address_2, coit.address_2) AS invoicetemplate_address_2,
		COALESCE(cuit.address_3, coit.address_3) AS invoicetemplate_address_3,
		COALESCE(cuit.email_subject_line, coit.email_subject_line) AS invoicetemplate_email_subject_line,
		dbo.fn_get_invoice_template ( @invoice_id,  @revision_id ) as company_count,
		COALESCE(cuit.logo_x_position, coit.logo_x_position) AS logo_x_position,
		COALESCE(cuit.logo_y_position, coit.logo_y_position) AS logo_y_position,
		COALESCE(cuit.logo_width, coit.logo_width) AS logo_width,
		COALESCE(cuit.logo_height, coit.logo_height) AS logo_height
	FROM InvoiceAttachment a     
	INNER JOIN InvoiceHeader h ON a.invoice_id = h.invoice_id
		 AND  a.revision_id = h.revision_id
	LEFT OUTER JOIN Generator g ON a.generator_id = g.generator_id
	LEFT OUTER JOIN plt_image.dbo.scan s ON a.image_id = s.image_id
	LEFT OUTER JOIN CustInvTemplate cuit ON h.customer_id = cuit.customer_id
	LEFT OUTER JOIN CompInvTemplate coit ON a.company_id = coit.company_id
	where  a.invoice_id = @invoice_id
	and   a.revision_id = @revision_id



	-- now update the key info 
	-- receipt documents

	update #invdata
	set image_name = image_name + ' '
					 + right(replicate('0',2) + cast(company_id as varchar(2)),2)  + '-'
					 + right(replicate('0',2) + cast(profit_ctr_id as varchar(2)),2)  + ' '
					 + convert(varchar(12), receipt_id) 
	where upper(scan_type) = 'RECEIPT'


	-- workorder docuemnts

	update #invdata
	set image_name = image_name + ' ' +
					 + right(replicate('0',2) + cast(company_id as varchar(2)),2)  + '-'
					 + right(replicate('0',2) + cast(profit_ctr_id as varchar(2)),2)  + ' '
					 + convert(varchar(12), receipt_id) 
	where upper(scan_type) = 'WORKORDER'

	-- generator documents

	update #invdata
	set image_name = image_name  + ' '
					 + isnull(generator_name,'') + ' (' + convert(varchar(12), generator_id) + ')'
	where upper(scan_type) = 'GENERATOR'

	-- approval documents

	update #invdata
	set image_name = image_name  + ' '
					 + right(replicate('0',2) + cast(company_id as varchar(2)),2)  + '-'
					 + right(replicate('0',2) + cast(profit_ctr_id as varchar(2)),2)  + ' '
					 + approval_code 
	where upper(scan_type) = 'APPROVAL'
	and (profit_ctr_id is not NULL or profit_ctr_id <> 99)

	 select invoice_id,
		revision_id ,
			invoice_code, 
		scan_type, 
		document_type, 
		image_id, 
		company_id, 
		profit_ctr_id, 
		customer_id, 
		receipt_id, 
		manifest, 
		approval_code, 
		generator_id,
		file_type,
		pagecount,
		title,
		level,
		image_name,
		generator_name, 
		filename,
		customer_name,
		invoice_date,
		isnull(page_number,999999),
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
	from #invdata
	order by scan_type, document_type,company_id , profit_ctr_id, trans_source, receipt_id 
END
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_get_invoice_attachments] TO [EQAI]
    AS [dbo];

