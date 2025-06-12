CREATE OR ALTER PROCEDURE [dbo].[sp_invoice_print_work_order_summary]
	@invoice_id int,
	@revision_id int
AS
/***********************************************************************
PB Object(s):	d_invoice_print_work_order_summary

01/27/2023 MPM	DevOps 58164 - Created by copying sp_invoice_print_waste_summary.
07/24/2023 MPM	DevOps 69357 - Added missing join on price_id between Billing and 
				InvoiceDetail tables.
09/26/2023 Subhrajyoti Devops #69180 - Customer - Add options to Work Order Summary Report to billing project
10/26/2023 Subhrajyoti Devops #73624 - Customer - Add options to Work Order Summary Report to billing project (conuation of Devops #69180)
07/05/2024 KS	RallyUS116980 - Modified datatype for #invoice_tmp.line_desc to VARCHAR(100)
09/23/2024 Subhrajyoti - Rally#DE35097 - [DEFECT] - EQAI Incorrect Logos on Backup Documentation

exec sp_invoice_print_work_order_summary 1630731, 1
exec sp_invoice_print_work_order_summary 1566374, 1
***********************************************************************/

set transaction isolation level read uncommitted

SET NOCOUNT ON

CREATE TABLE #invoice_tmp (
	address_name					varchar(40)	null, 
	addr1							varchar(40) null, 
	addr2							varchar(40) null, 
	addr3							varchar(40) null, 
	addr4							varchar(40) null, 
	addr5							varchar(40) null, 
	invoice_code					varchar(16) null, 
	customer_id						int			null, 
	ax_customer_id					varchar(20)	null,
	invoice_date					datetime	null, 
	approval_code					varchar(15)	null, 
	unit_code						varchar(8)	null,  
	qty_ordered						float		null, 
	unit_price						float		null, 
	line_desc						varchar(100)	null,
	location_code					varchar(8)	null,
	invoice_id						int			null,
	revision_id						int			null,
	ext_price						float		null,
	currency_code					varchar(3)	null,
	billing_project_id				int			null,
	print_wos_with_start_date_flag	CHAR(1)		NULL,
	resource_type					char(1)		null,
	workorder_start_date			datetime	null,
	wos_include_nc_items_flag       Char(1)     null,  --Devops #69180
	wos_include_resource_el_names_flag Char(1)  null,   --Devops #69180
	resource_class_code varchar(10) null, --Devops #69180
	resource_assigned varchar(10) null, --Devops #69180
	resource_description varchar(100) null, --Devops #69180
	bill_rate float null, --Devops #69180
	workorder_id int null,  -- Devops#73624
	company_id int null, -- Devops#73624
	profit_ctr_id int null, -- Devops#73624
	sequence_id int null,  -- Devops#73624
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
	customer_id, 
	ax_customer_id,
	invoice_date, 
	approval_code, 
	unit_code,  
	qty_ordered, 
	unit_price, 
	line_desc,
	location_code,
	invoice_id,
    revision_id,
	ext_price,
	currency_code,
	billing_project_id,
	print_wos_with_start_date_flag,
	resource_type,
	workorder_start_date,
	wos_include_nc_items_flag,  -- Devops #69180
	wos_include_resource_el_names_flag, --Devops #69180
	resource_class_code, -- Devops #69180
	resource_assigned, -- Devops #69180
	resource_description, -- Devops #69180
	bill_rate, -- Devops #69180 
	workorder_id, --Devops#73624
	company_id, -- Devops#73624
	profit_ctr_id, -- Devops#73624
	sequence_id, -- Devops#73624
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
	MAX(InvoiceHeader.customer_id), 
	MAX(Customer.ax_customer_id), 
	MAX(InvoiceHeader.invoice_date), 
	ISNULL(InvoiceDetail.approval_code, ''), 
	MAX(InvoiceDetail.unit_code), 
	SUM(InvoiceDetail.qty_ordered), 
	InvoiceDetail.unit_price, 
	InvoiceDetail.line_desc_1,
	InvoiceDetail.location_code,
	MAX(InvoiceHeader.invoice_id),
    MAX(InvoiceHeader.revision_id),
	SUM(ROUND((InvoiceDetail.qty_ordered * InvoiceDetail.unit_price) + 0.005,2,1)),
	MAX(InvoiceHeader.currency_code),
	InvoiceDetail.billing_project_id,
	CustomerBilling.print_wos_with_start_date_flag,
	Billing.workorder_resource_type,
	WorkOrderHeader.start_date,
	CustomerBilling.wos_include_nc_items_flag, --Devops #69180
	CustomerBilling.wos_include_resource_el_names_flag,  --Devops #69180
	WorkOrderDetail.resource_class_code, --Devops #69180
	WorkOrderDetail.resource_assigned, --Devops #69180
	WorkOrderDetail.description, --Devops #69180
	WorkOrderDetail.bill_rate, --Devops #69180
	WorkOrderDetail.workorder_id, --Devops#73624
	WorkOrderDetail.company_id, --Devops#73624
	WorkOrderDetail.profit_ctr_id, --Devops#73624
	WorkOrderDetail.sequence_id, --Devops#73624
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
FROM InvoiceDetail
JOIN InvoiceHeader 
	ON InvoiceDetail.invoice_id = InvoiceHeader.invoice_id
	AND InvoiceDetail.revision_id = InvoiceHeader.revision_id 
JOIN Customer
	ON Customer.customer_id = InvoiceHeader.customer_id
JOIN CustomerBilling
	ON CustomerBilling.customer_id = InvoiceHeader.customer_id
	AND CustomerBilling.billing_project_id = InvoiceDetail.billing_project_id
JOIN Billing
	ON  Billing.company_id = InvoiceDetail.company_id
	AND Billing.profit_ctr_id = InvoiceDetail.profit_ctr_id
	AND Billing.receipt_id = InvoiceDetail.receipt_id
	AND Billing.line_id = InvoiceDetail.line_id
	AND Billing.invoice_id = InvoiceDetail.invoice_id
	AND Billing.trans_source = 'W'
JOIN WorkOrderHeader 
	ON WorkOrderHeader.company_id = InvoiceDetail.company_id
	AND WorkOrderHeader.profit_ctr_id = InvoiceDetail.profit_ctr_id
	AND WorkOrderHeader.workorder_id = InvoiceDetail.receipt_id
JOIN WorkOrderDetail --Devops #69180
    ON WorkOrderDetail.company_id = Billing.company_id
	AND WorkOrderDetail.profit_ctr_id = Billing.profit_ctr_id
	AND WorkOrderDetail.workorder_id = Billing.receipt_id
	AND WorkOrderDetail.sequence_id = Billing.workorder_sequence_id
	AND WorkOrderDetail.resource_type = Billing.workorder_resource_type 
 WHERE InvoiceDetail.invoice_id = @invoice_id
	AND InvoiceDetail.revision_id = @revision_id
	AND WorkOrderDetail.resource_class_code IS NOT NULL --Devops #69180
	AND LEN(WorkOrderDetail.resource_class_code) > 0 --Devops #69180
--	AND InvoiceDetail.invoice_type = 'D'
--	AND (InvoiceDetail.location_code = 'EQAI-LR' OR InvoiceDetail.location_code = 'EQAI-ST')
GROUP BY
	Billing.workorder_resource_type,
	CASE 
		WHEN CustomerBilling.print_wos_with_start_date_flag = 'T' 
		THEN CONVERT(CHAR(8), WorkOrderHeader.start_date, 112)  
		ELSE ISNULL(InvoiceDetail.approval_code, '') + InvoiceDetail.line_desc_1 
	END,
	CASE 
		WHEN ISNULL(CustomerBilling.print_wos_with_start_date_flag, 'F') = 'F' 
		THEN ISNULL(InvoiceDetail.approval_code, '') + InvoiceDetail.line_desc_1 
		ELSE ''
	END,
	InvoiceDetail.billing_project_id,
	CustomerBilling.print_wos_with_start_date_flag,
	InvoiceDetail.approval_code,
	InvoiceDetail.line_desc_1,
	InvoiceDetail.unit_code,
	InvoiceDetail.unit_price, 
	InvoiceDetail.location_code,
	WorkOrderHeader.start_date,
	CustomerBilling.wos_include_nc_items_flag, --Devops #69180
	CustomerBilling.wos_include_resource_el_names_flag,  --Devops #69180
	WorkOrderDetail.resource_class_code, --Devops #69180
	WorkOrderDetail.resource_assigned, --Devops #69180
	WorkOrderDetail.description, --Devops #69180
	WorkOrderDetail.bill_rate, --Devops #69180
	WorkOrderDetail.workorder_id, --Devops#73624
	WorkOrderDetail.company_id, --Devops#73624
	WorkOrderDetail.profit_ctr_id, --Devops#73624
	WorkOrderDetail.sequence_id --Devops#73624


--Devops#73624 - Inserting N/C line items where invoice print flag is False but include N/C line item is True at customer billing level.

INSERT INTO #invoice_tmp(address_name, 
						addr1, 
						addr2, 
						addr3, 
						addr4, 
						addr5, 
						invoice_code, 
						customer_id, 
						ax_customer_id,
						invoice_date, 
						approval_code, 
						unit_code,  
						qty_ordered, 
						unit_price, 
						line_desc,
						location_code,
						invoice_id,
						revision_id,
						ext_price,
						currency_code,
						billing_project_id,
						print_wos_with_start_date_flag,
						resource_type,
						workorder_start_date,
						wos_include_nc_items_flag,  
						wos_include_resource_el_names_flag, 
						resource_class_code, 
						resource_assigned, 
						resource_description, 
						bill_rate, 
						workorder_id,
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

					SELECT 
						#invoice_tmp.address_name, 
						#invoice_tmp.addr1, 
						#invoice_tmp.addr2, 
						#invoice_tmp.addr3, 
						#invoice_tmp.addr4, 
						#invoice_tmp.addr5, 
						#invoice_tmp.invoice_code, 
						#invoice_tmp.customer_id, 
						#invoice_tmp.ax_customer_id,
						#invoice_tmp.invoice_date, 
						#invoice_tmp.approval_code,
						WorkOrderDetail.bill_unit_code, 
						WorkOrderDetail.quantity_used, 
						WorkOrderDetail.price, 
						WorkOrderDetail.description,
						#invoice_tmp.location_code,
						#invoice_tmp.invoice_id,
						#invoice_tmp.revision_id,
						ROUND((WorkOrderDetail.quantity_used * WorkOrderDetail.price) + 0.005,2,1),
						#invoice_tmp.currency_code,
						#invoice_tmp.billing_project_id,
						#invoice_tmp.print_wos_with_start_date_flag,
						WorkOrderDetail.resource_type,
						#invoice_tmp.workorder_start_date,
						#invoice_tmp.wos_include_nc_items_flag, 
						#invoice_tmp.wos_include_resource_el_names_flag,
						WorkOrderDetail.resource_class_code, 
						WorkOrderDetail.resource_assigned,
						WorkOrderDetail.description,
						WorkOrderDetail.bill_rate,
						#invoice_tmp.workorder_id,
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
						FROM WorkOrderDetail
						JOIN #invoice_tmp ON WorkOrderDetail.workorder_id = #invoice_tmp.workorder_id 
						AND WorkOrderDetail.company_id = #invoice_tmp.company_id
						AND	WorkOrderDetail.profit_ctr_id = #invoice_tmp.profit_ctr_id
						AND	WorkOrderDetail.sequence_id <> #invoice_tmp.sequence_id
						AND ISNULL(#invoice_tmp.wos_include_nc_items_flag,'F') = 'T'
						AND WorkOrderDetail.bill_rate = 0 
						AND ISNULL(print_on_invoice_flag,'F') = 'F' 
						AND WorkOrderDetail.resource_type IN ('E','L','S')

						-- Deleting the N/C billed items which were invoiced but n/c flag in customer billing is false
						DELETE FROM #invoice_tmp
						FROM #invoice_tmp
						JOIN WorkOrderDetail ON  WorkOrderDetail.workorder_id = #invoice_tmp.workorder_id 
						AND WorkOrderDetail.company_id = #invoice_tmp.company_id
						AND	WorkOrderDetail.profit_ctr_id = #invoice_tmp.profit_ctr_id
						AND	WorkOrderDetail.sequence_id = #invoice_tmp.sequence_id
						AND ISNULL(#invoice_tmp.wos_include_nc_items_flag,'F') = 'F'
						AND WorkOrderDetail.bill_rate = 0 
						AND ISNULL(print_on_invoice_flag,'F') = 'T' 
						AND WorkOrderDetail.resource_type IN ('E','L','S')


--Devops#73624 Aggregate functions and group by added in Final resultset

SELECT
	MAX(address_name) AS address_name, 
	MAX(addr1) AS addr1, 
	MAX(addr2) AS addr2, 
	MAX(addr3) AS addr3, 
	MAX(addr4) AS addr4, 
	MAX(addr5) AS addr5, 
	MAX(invoice_code) AS invoice_code, 
	MAX(customer_id) AS customer_id, 
	MAX(ax_customer_id) AS ax_customer_id,
	MAX(invoice_date) AS invoice_date, 
	ISNULL(approval_code,'') AS approval_code, 
	MAX(unit_code) AS unit_code,  
	SUM(qty_ordered) AS qty_ordered, 
	unit_price, 
	line_desc,
	location_code,
	MAX(invoice_id) AS invoice_id ,
    MAX(revision_id) AS revision_id,
	SUM(ext_price) AS ext_price,
	MAX(currency_code) AS currency_code,
	billing_project_id,
	print_wos_with_start_date_flag,
	resource_type,
	workorder_start_date,
	wos_include_nc_items_flag,  
	wos_include_resource_el_names_flag, 
	resource_class_code, 
	resource_assigned, 
	resource_description, 
	bill_rate,
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
GROUP BY
	resource_type,
	CASE 
		WHEN print_wos_with_start_date_flag = 'T' 
		THEN CONVERT(CHAR(8), workorder_start_date, 112)  
		ELSE ISNULL(approval_code, '') + line_desc 
	END,
	CASE 
		WHEN ISNULL(print_wos_with_start_date_flag, 'F') = 'F' 
		THEN ISNULL(approval_code, '') + line_desc 
		ELSE ''
	END,
	billing_project_id,
	print_wos_with_start_date_flag,
	approval_code,
	line_desc,
	unit_code,
	unit_price, 
	location_code,
	workorder_start_date,
	wos_include_nc_items_flag, 
	wos_include_resource_el_names_flag,  
	resource_class_code, 
	resource_assigned, 
	resource_description, 
	bill_rate,
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
ORDER BY
	resource_type,
	CASE 
		WHEN print_wos_with_start_date_flag = 'T' 
		THEN CONVERT(CHAR(8), workorder_start_date, 112) + approval_code + line_desc
		ELSE approval_code + line_desc
	END
GO


GRANT EXECUTE
    ON OBJECT::[dbo].[sp_invoice_print_work_order_summary] TO [EQAI];
GO
