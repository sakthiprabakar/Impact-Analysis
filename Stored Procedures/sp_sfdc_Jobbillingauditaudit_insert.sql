
USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_Jobbillingauditaudit_insert]    Script Date: 2/19/2025 4:22:07 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER procedure [dbo].[sp_sfdc_Jobbillingauditaudit_insert]
						@break_code_1 char(1),
						@break_code_2 char(1),
						@break_code_3 char(1),
						@invoice_package_content char(1),
						@mail_to_bill_to_address_flag char(1),
						@PO_required_flag char(1) ,
						@terms_code varchar(8) NULL,                   
						@distribution_method char(1),
						@emanifest_fee_option char(1),
						@all_facilities_flag char(1),
						@print_wos_with_start_date_flag char(1),
						@ebilling_flag char(1),
						@insurance_surcharge_flag char(1),
						@region_id int,
						@custbillxcont_distribution_method char(1),
						@custbillxcont_Invoice_Package_Content CHAR(1),
						@customer_billing_territory_status char(1),
						@customer_billing_territory_type char(1),
						@businesssegment_uid_1 int,
						@businesssegment_uid_2 int,
						@invoice_flag CHAR(1),
						@date_added datetime,
						@date_modified datetime,
						@emanifest_flag char(1),
						@emanifest_fee money,
						@record_type char(1),
						@employee_id varchar(20),
						@salesforce_jobbillingproject_csid varchar(18),
						@project_name varchar(40),
						@customer_billing_territory_code varchar(8),
						@cusbilxcontact_email varchar(60),
						@invoice_comment_1 varchar(80),
						@invoice_comment_2 varchar(80),
						@invoice_comment_3 varchar(80),
						@invoice_comment_4 varchar(80),
						@invoice_comment_5 varchar(80),
						@RSG_EIN varchar(20),
						@sf_invoice_backup_document varchar(300) null,
						@salesforce_invoice_csid varchar(18) null,
						@consolidate_containers_flag CHAR(1),
						@distrubation_method_cbilling char(1),
						--@apply_fee_flag char(1), 	
						--@use_corporate_rate_EIRRATE char(1),
						@customer_id int,
						@status char(1),
						@date_effective datetime,
						@billing_project_id INT,
						@user_code varchar(10),
						@customer_billing_territory_primary_flag char(1),
						@customer_billing_territory_percent float,
						@eq_approved_offeror_desc varchar(255),
						@eq_approved_offeror_flag char(1) ,
						@eq_offeror_bp_override_flag char(1),
						@internal_review_flag char(1),
						@eq_offeror_effective_dt datetime ,
						@intervention_desc varchar(255),
						@invoice_print_attachment_flag CHAR(1),
						@release_required_flag char(1),
						@link_required_flag CHAR(1),
						@retail_flag char(1),
						@sort_code_1 char(1),
						@sort_code_2 char(1),
						@sort_code_3 char(1),
						@submit_on_hold_flag CHAR(1),
						@trip_stop_rate_default_flag char(1),
						@weight_ticket_required_flag char(1),
						@whca_exempt char(1),
						@pickup_report_flag char(1),
						@invoice_copy_flag char(1),
						@intervention_required_flag char(1),
						@print_wos_in_inv_attachment_flag char(1),
						@contact_id int,
						@CUST_service_user_code varchar(10),
						@Customer_service_ID int,
						@category char(1),
						@type_id int,
						@print_on_invoice_required_flag char(1),
						@print_toc_in_inv_attachment_flag char(1),
						@print_rws_in_inv_attachment_flag char(1),
						@cbilling_territory_code varchar(8),
						@salesforce_so_quote_id varchar(15),
						@release_validation char(1),
						@po_validation char(1),
						@link_required_validation char(1)
					
						

/*

Description: 

Job level audit records will be inserted whenever the insert happen in the customerbilling,customerbillingemanistfee,
CustomerBillingXContact,customerbillingdocument,
CustomerBillingEIRRate,CustomerBillingTerritory through storedprocedure sp_sfdc_customerbilling_Insert

Revision History:

DevOps# 88135 - 05/01/2024  Nagaraj M   Created
Devops# 88674 - 05/29/2024 Fix the multidocument ignore T&M or Invoice any one.
Devops# 89039  - 06/03/2024 salesforce so quote integaration .
[Please increase the value of @customer_billing_parameter_count,if any new parameter included.
For example, customer_billing_parameter_count =112, if one parameter newly added means then customer_billing_parameter_count =113,
if two parameter added then customer_billing_parameter_count =114]
Rally#US134134 -- Inserting audit records for the customerbillingeirrate into the customeraudit table.
Rally#US141970 -- Inserting audit records for the customerbillingFRFrate into the customeraudit table.

*/				
								
AS
BEGIN
Declare 
	@before_value varchar(100) ='(inserted)',
	@customer_billing_emanifest_fee_uid int,
	@customerbillingeirrate_uid int,
	@customerbillingterritory_uid int,
	@EIR_RATE money =null,
	@audit_reference varchar(100),
	@li_count int = 1,
	@column_value varchar(100),
	@COLUMN_NAME VARCHAR(100),
	@customer_billing_parameter_count int = 114,
	@Key_value varchar(4000),
	@table_name varchar(100),
	@source_system varchar(100),
	@date_modified_getdate datetime=getdate(),
	--@po_validation char(1),
	@trans_source_R char(1),
	@ERROR CHAR(1)='N',
	@ll_doc_len int,
    @ll_doc_index int,
	@sf_invoice_backup_document_ret varchar(80),		
	@ls_tm_doc_flag Char(1) = 'F',
	@ls_inv_doc_flag Char(1) = 'F',
	@ls_customerbillingdocument_audit_ins_req Char(1) = 'T',
	@sf_document_name_label varchar(50)= null,
	@eqai_scan_document_type varchar(50)= null,
	@validation char(1),
	@use_corporate_rate char(1), --nagaraj m
	@apply_fee_flag char(1),
	@customer_billing_frf_rate_uid int,
	@exemption_approved_by varchar(10),
	@date_exempted datetime


	BEGIN TRY
	BEGIN
		Select @source_system = 'sp_sfdc_Jobbillingauditaudit_insert'
		WHILE @li_count <=@customer_billing_parameter_count
		BEGIN
		Set @column_value=''
		if @li_count=1
			BEGIN
				SELECT @column_value=@mail_to_bill_to_address_flag 
				SELECT @column_name='mail_to_bill_to_address_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =2
			BEGIN
				SELECT @column_value=@customer_id 
				SELECT @column_name='customer_id'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			IF @li_count=3
			BEGIN
				SELECT @column_value=@billing_project_id 
				SELECT @column_name='billing_project_id'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
		
			if @li_count =4
			BEGIN
				SELECT @column_value=@project_name
				SELECT @column_name='project_name'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
				if @li_count =5
			BEGIN
				SELECT @column_value=@terms_code 
				SELECT @column_name='terms_code'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=6
				BEGIN
					SELECT @column_value=@custbillxcont_distribution_method
					SELECT @column_name='distribution_method'
					select @table_name='customerbillingxcontact'
					Select @audit_reference = 'customer_id: ' + 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' Contact_id: ' + trim(str(@contact_id)) 
				
				END
		
			if @li_count=7
			BEGIN
				SELECT @column_value=@release_required_flag 
				SELECT @column_name='release_required_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
		
			if @li_count=8
			BEGIN
				SELECT @column_value=@distrubation_method_cbilling
				SELECT @column_name='distrubation_method'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			
			if @li_count=9
			BEGIN
				SELECT @column_value=@break_code_1
				SELECT @column_name='break_code_1'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =10
				BEGIN
				SELECT @column_value=@break_code_2
				SELECT @column_name='break_code_2'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=11
			BEGIN
				SELECT @column_value=@break_code_3
				SELECT @column_name='break_code_3'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			
			if @li_count =12
			BEGIN
				SELECT @column_value=@consolidate_containers_flag
				SELECT @column_name='consolidate_containers_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=13
			BEGIN
				SELECT @column_value=@PO_required_flag
				SELECT @column_name='PO_required_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=14
			BEGIN
				SELECT @column_value=@status
				SELECT @column_name='status'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count =15
			BEGIN
				SELECT @column_value=@user_code
				SELECT @column_name='added_by'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=16
			BEGIN
				SELECT @column_value=CONVERT(varchar,@date_added,101)
				SELECT @column_name='date_added'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=17
			BEGIN
				SELECT @column_value=CONVERT(varchar,@date_modified,101)
				SELECT @column_name='date_modified'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END


				if @li_count=18
			BEGIN
				SELECT @column_value=@record_type
				SELECT @column_name='record_type'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=19
			BEGIN
				SELECT @column_value=@invoice_comment_1 
				SELECT @column_name='invoice_comment_1'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=20
			BEGIN
				SELECT @column_value=@invoice_comment_2 
				SELECT @column_name='invoice_comment_1'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

				if @li_count=21
			BEGIN
				SELECT @column_value=@invoice_comment_3 
				SELECT @column_name='invoice_comment_3'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

				if @li_count=22
			BEGIN
				SELECT @column_value=@invoice_comment_4 
				SELECT @column_name='invoice_comment_4'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

				if @li_count=23
			BEGIN
				SELECT @column_value=@invoice_comment_5 
				SELECT @column_name='invoice_comment_5'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END


			if @li_count =24
			BEGIN
				SELECT @column_value=@eq_approved_offeror_desc
				SELECT @column_name='eq_approved_offeror_desc'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=25
			BEGIN
				SELECT @column_value=@eq_approved_offeror_flag
				SELECT @column_name='eq_approved_offeror_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count =26
			BEGIN
				SELECT @column_value=@eq_offeror_bp_override_flag
				SELECT @column_name='eq_offeror_bp_override_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=27
			BEGIN
				SELECT @column_value=@internal_review_flag
				SELECT @column_name='internal_review_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

				if @li_count=28
			BEGIN
				SELECT @column_value=CONVERT(varchar,@eq_offeror_effective_dt,101)
				SELECT @column_name='eq_offeror_effective_dt'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

				if @li_count =29
			BEGIN
				SELECT @column_value=@intervention_desc
				SELECT @column_name='intervention_desc'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

				if @li_count =30
			BEGIN
				SELECT @column_value=@invoice_print_attachment_flag
				SELECT @column_name='invoice_print_attachment_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

				if @li_count=31
			BEGIN
				SELECT @column_value=@link_required_flag
				SELECT @column_name='link_required_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=32
			BEGIN
				SELECT @column_value=@retail_flag
				SELECT @column_name='retail_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count =33
			BEGIN
				SELECT @column_value=@sort_code_1
				SELECT @column_name='sort_code_1'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count=34
			BEGIN
				SELECT @column_value=@sort_code_2
				SELECT @column_name='sort_code_2'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			if @li_count =35
			BEGIN
				SELECT @column_value=@sort_code_3
				SELECT @column_name='sort_code_3'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count =36
			BEGIN
				SELECT @column_value=@submit_on_hold_flag
				SELECT @column_name='submit_on_hold_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=37
			BEGIN
				SELECT @column_value=@trip_stop_rate_default_flag
				SELECT @column_name='trip_stop_rate_default_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

				if @li_count =38
			BEGIN
				SELECT @column_value=@weight_ticket_required_flag
				SELECT @column_name='weight_ticket_required_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count =39
			BEGIN
				SELECT @column_value=@all_facilities_flag
				SELECT @column_name='all_facilities_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			
				if @li_count =40
			BEGIN
				SELECT @column_value=@print_wos_in_inv_attachment_flag
				SELECT @column_name='print_wos_in_inv_attachment_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			
				if @li_count =41
			BEGIN
				SELECT @column_value=@print_wos_with_start_date_flag 
				SELECT @column_name='print_wos_with_start_date_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count =42
			BEGIN
				SELECT @column_value=@insurance_surcharge_flag
				SELECT @column_name='insurance_surcharge_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

				if @li_count=43
			BEGIN
				SELECT @column_value=trim(str(@region_id))
				SELECT @column_name='region_id'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count =44
			BEGIN
				SELECT @column_value=@invoice_flag
				SELECT @column_name='invoice_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=45
			BEGIN
				SELECT @column_value=@whca_exempt
				SELECT @column_name='whca_exempt'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=46
			BEGIN
				SELECT @column_value=@invoice_package_content
				SELECT @column_name='invoice_package_content'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			If @li_count=47
			BEGIN
				SELECT @column_value=@ebilling_flag
				SELECT @column_name='ebilling_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			
			if @li_count=48
			BEGIN
				SELECT @column_value=@intervention_required_flag
				SELECT @column_name='intervention_required_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			
			if @li_count =49
			BEGIN
				SELECT @column_value=@pickup_report_flag 
				SELECT @column_name='pickup_report_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			
			if @li_count =50
			BEGIN
				SELECT @column_value=@salesforce_jobbillingproject_csid 
				SELECT @column_name='salesforce_jobbillingproject_csid'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			

			if @li_count =51
			BEGIN
				SELECT @column_value=@Customer_service_ID 
				SELECT @column_name='Customer_service_ID'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
			


			if @li_count =52
			BEGIN
				SELECT @column_value=@print_rws_in_inv_attachment_flag 
				SELECT @column_name='print_rws_in_inv_attachment_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count =53
			BEGIN
				SELECT @column_value=@print_toc_in_inv_attachment_flag 
				SELECT @column_name='print_toc_in_inv_attachment_flag'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count =54
			BEGIN
				SELECT @column_value=@cbilling_territory_code 
				SELECT @column_name='territory_code'
				select @table_name='customerbilling'
				Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=55
			BEGIN
				SELECT @column_value=str(@billing_project_id)
				SELECT @column_name='billing_project_id'
				select @table_name='customerbilling'
				Select @audit_reference = 'Billing Project created for ACV import per ' +@user_code
			END

			

			/*if @PO_required_flag ='T'
			BEGIN
			SELECT @po_validation='E'
			END
			IF @PO_required_flag ='F'
			BEGIN
			SELECT @po_validation='W'
			END
			*/
			if @li_count=56
			BEGIN
				SELECT @column_value=@po_validation 
				SELECT @column_name='po_validation'
				select @table_name='customerbilling'
					Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

					   		
			--CustomerBillingeManifestFee
			
			BEGIN
				select @customer_billing_emanifest_fee_uid=customer_billing_emanifest_fee_uid
				from CustomerBillingeManifestFee
				where billing_project_id=@billing_project_id
				and customer_id=@customer_id
				
			END
			if @li_count=57
			BEGIN
				SELECT @column_value=@emanifest_fee_option
				SELECT @column_name='emanifest_fee_option'
				select @table_name='CustomerBillingeManifestFee'
				Select @audit_reference = 'customer_billing_emanifest_fee_uid:' 
				+trim(str(@customer_billing_emanifest_fee_uid)) + ' customer_id: ' + 
				trim(str(@customer_id)) +' billing project id: '
				+ trim(str(@billing_project_id))
			END
			if @li_count=58
			BEGIN
				SELECT @column_value=@emanifest_flag
				SELECT @column_name='emanifest_flag'
				select @table_name='CustomerBillingeManifestFee'
				Select @audit_reference = 'customer_billing_emanifest_fee_uid:' 
				+trim(str(@customer_billing_emanifest_fee_uid)) + ' customer_id: ' + 
				trim(str(@customer_id)) +' billing project id: '
				+ trim(str(@billing_project_id))
			END
			if @li_count=59
			BEGIN
				SELECT @column_value=CONVERT(varchar,@date_effective,101)
				SELECT @column_name='date_effective'
				select @table_name='CustomerBillingeManifestFee'
				Select @audit_reference = 'customer_billing_emanifest_fee_uid:' 
				+trim(str(@customer_billing_emanifest_fee_uid)) + ' customer_id: ' + 
				trim(str(@customer_id)) +' billing project id: '
				+ trim(str(@billing_project_id))
			END

			if @li_count=60
			BEGIN
				SELECT @column_value=@emanifest_fee
				SELECT @column_name='emanifest_fee'
				select @table_name='CustomerBillingeManifestFee'
				Select @audit_reference = 'customer_billing_emanifest_fee_uid:' 
				+trim(str(@customer_billing_emanifest_fee_uid)) + ' customer_id: ' + 
				trim(str(@customer_id)) +' billing project id: '
				+ trim(str(@billing_project_id))
			END
	
			if @li_count=61
			BEGIN
				SELECT @column_value=@release_validation 
				SELECT @column_name='release_validation'
				select @table_name='customerbilling'
					Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END

			if @li_count=62
			BEGIN
				SELECT @column_value=@link_required_validation 
				SELECT @column_name='link_required_validation'
				select @table_name='customerbilling'
					Select @audit_reference = 'customer_id: '  
				+trim(str(@customer_id)) 
				+' billing project id: ' 
				+ trim(str(@billing_project_id))
			END
	
			

			/*select @customerbillingeirrate_uid=customerbillingeirrate_uid
			from CustomerBillingEIRRate
			where billing_project_id=@billing_project_id
			and customer_id=@customer_id
					
			if @li_count=61
			BEGIN
				SELECT @column_value=@use_corporate_rate_EIRRATE
				SELECT @column_name='use_corporate_rate'
				select @table_name='CustomerBillingEIRRate'
				Select @audit_reference = 'customerbillingeirrate_uid:' 
										+trim(str(@customer_billing_emanifest_fee_uid)) 
										+ ' customer_id: ' + 
										trim(str(@customer_id))
										+' billing project id: '
										+ trim(str(@billing_project_id))
			
			END
			if @li_count=62
			BEGIN
				SELECT @column_value=@EIR_RATE
				SELECT @column_name='EIR_RATE'
				select @table_name='CustomerBillingEIRRate'
				Select @audit_reference = 'customerbillingeirrate_uid:' 
										+trim(str(@customer_billing_emanifest_fee_uid)) 
										+ ' customer_id: ' + 
										trim(str(@customer_id))
										+' billing project id: '
										+ trim(str(@billing_project_id))
			
			END
			if @li_count=63
			BEGIN
				SELECT @column_value=CONVERT(varchar,getdate(),101)
				SELECT @column_name='date_effective'
				select @table_name='CustomerBillingEIRRate'
				Select @audit_reference = 'customerbillingeirrate_uid:' 
										+trim(str(@customer_billing_emanifest_fee_uid)) 
										+ ' customer_id: ' + 
										trim(str(@customer_id))
										+' billing project id: '
										+ trim(str(@billing_project_id))
			
			END
			if @li_count=64
			BEGIN
				SELECT @column_value=@apply_fee_flag
				SELECT @column_name='apply_fee_flag'
				select @table_name='CustomerBillingEIRRate'
				Select @audit_reference = 'customerbillingeirrate_uid:' 
										+trim(str(@customer_billing_emanifest_fee_uid)) 
										+ ' customer_id: ' + 
										trim(str(@customer_id))
										+' billing project id: '
										+ trim(str(@billing_project_id))
			
			END		
		*/
				---CustomerBillingXContact

				if @li_count=65
				BEGIN
					SELECT @column_value=@contact_id
					SELECT @column_name='contact_id'
					select @table_name='CustomerBillingXContact'
					Select @audit_reference = 'customer_id: ' + 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' Contact_id: ' + trim(str(@contact_id))
				
				END
				if @li_count=66
				BEGIN
					SELECT @column_value=@invoice_copy_flag
					SELECT @column_name='invoice_copy_flag'
					select @table_name='CustomerBillingXContact'
					Select @audit_reference = 'customer_id: ' + 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' Contact_id: ' + trim(str(@contact_id))
				
				END
				if @li_count=67
				BEGIN
					SELECT @column_value=@custbillxcont_distribution_method
					SELECT @column_name='distribution_method'
					select @table_name='CustomerBillingXContact'
					Select @audit_reference = 'customer_id: ' + 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' Contact_id: ' + trim(str(@contact_id)) 
				
				END
				if @li_count=68
				BEGIN
					SELECT @column_value=null
					SELECT @column_name='attn_name_flag'
					select @table_name='CustomerBillingXContact'
					Select @audit_reference = 'customer_id: ' + 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' Contact_id: ' + trim(str(@contact_id))
				
				END
				if @li_count=69
				BEGIN
					SELECT @column_value=@custbillxcont_Invoice_Package_Content
					SELECT @column_name='invoice_package_content'
					select @table_name='CustomerBillingXContact'
					Select @audit_reference = 'customer_id: ' + 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' Contact_id: ' + trim(str(@contact_id))
				
				END
			

				-- CustomerBillingTerritory

				BEGIN
					select @customerbillingterritory_uid=customerbillingterritory_uid
					from CustomerBillingTerritory
					where billing_project_id=@billing_project_id
					and customer_id=@customer_id
				END
				
				if @li_count=70
				BEGIN
					SELECT @column_value=cast((convert(int,isnull(@businesssegment_uid_1,''))) as varchar(20))
					SELECT @column_name='businesssegment_uid_1'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END
				
				if @li_count=71
				BEGIN
					SELECT @column_value=@customer_billing_territory_type
					SELECT @column_name='customer_billing_territory_type'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=72
				BEGIN
					SELECT @column_value=@customer_billing_territory_code
					SELECT @column_name='customer_billing_territory_code'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=73
				BEGIN
					SELECT @column_value=@customer_billing_territory_primary_flag
					SELECT @column_name='customer_billing_territory_primary_flag'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=74
				BEGIN
					SELECT @column_value=cast((convert(float,isnull(@customer_billing_territory_percent,''))) as varchar(20))
					SELECT @column_name='customer_billing_territory_percent'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=75
				BEGIN
					SELECT @column_value=@customer_billing_territory_status
					SELECT @column_name='customer_billing_territory_status'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=76
				BEGIN
					SELECT @column_value=cast((convert(int,isnull(@businesssegment_uid_2,''))) as varchar(20))
					SELECT @column_name='businesssegment_uid_2'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END
			
				if @li_count=77
				BEGIN
					SELECT @column_value=@customer_billing_territory_type
					SELECT @column_name='customer_billing_territory_type'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=78
				BEGIN
					SELECT @column_value=@customer_billing_territory_code
					SELECT @column_name='customer_billing_territory_code'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=79
				BEGIN
					SELECT @column_value=@customer_billing_territory_primary_flag
					SELECT @column_name='customer_billing_territory_primary_flag'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=80
				BEGIN
					SELECT @column_value=cast((convert(float,isnull(@customer_billing_territory_percent,''))) as varchar(20))
					SELECT @column_name='customer_billing_territory_percent'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=81
				BEGIN
					SELECT @column_value=@customer_billing_territory_status
					SELECT @column_name='customer_billing_territory_status'
					select @table_name='CustomerBillingBusinessSegment'
					Select @audit_reference = ' customerbillingterritory_uid: '
											+ trim(str(@customerbillingterritory_uid)) +' customer_id: ' + 
											+ trim(str(@customer_id)) 
				
				END

				if @li_count=82
				BEGIN
					SELECT @column_value=@sf_invoice_backup_document
					SELECT @column_name='sf_invoice_backup_document'
					select @table_name='NA'
					Select @audit_reference = ' customer_id: ' + 
											+ trim(str(@customer_id))  +' billing_project_id: ' + 
											+ trim(str(@billing_project_id))
				
				END

				if @li_count=83
				BEGIN
					SELECT @column_value=	@salesforce_so_quote_id
					SELECT @column_name='salesforce_so_quote_id'
					select @table_name='customerbilling'
					Select @audit_reference = ' customer_id: ' + 
											+ trim(str(@customer_id))  +' billing_project_id: ' + 
											+ trim(str(@billing_project_id))
				
				END

			
				
			IF @column_value <>'' 
			BEGIN
						INSERT INTO [dbo].CustomerAudit 
							(customer_id,table_name,column_name,before_value,after_value,audit_reference,modified_from,
							  modified_by,
							  date_modified
							 )
						SELECT
							  @customer_id,@table_name,@COLUMN_NAME,@before_value,@column_value,@audit_reference,
							  'Salesforce',
							  @user_code,
							  @date_modified_getdate
			
			END
		SET @li_count=@li_count+1
		
	END  --While loop end


	--CustomerbillingEIRRATE

	declare sf_CustomerbillingEIRRATE CURSOR fast_forward for select customerbillingeirrate_uid,customer_id,billing_project_id,use_corporate_rate,EIR_rate,date_effective,apply_fee_flag 
	from customerbillingeirrate where customer_id=@customer_id and billing_project_id=@billing_project_id

	open sf_CustomerbillingEIRRATE
	fetch next from sf_CustomerbillingEIRRATE into @customerbillingeirrate_uid,@customer_id,@billing_project_id,@use_corporate_rate,@eir_rate,@date_effective,@apply_fee_flag
	While @@fetch_status=0
	Begin	
		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingEIRRate','customerbillingeirrate_uid','inserted',trim(str(@customerbillingeirrate_uid)),
		'customerbillingeirrate_uid ' + trim(str(@customerbillingeirrate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingEIRRate','customer_id','inserted',trim(str(@customer_id)),
		'customerbillingeirrate_uid ' + trim(str(@customerbillingeirrate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingEIRRate','billing_project_id','inserted',trim(str(@billing_project_id)),
		'customerbillingeirrate_uid ' + trim(str(@customerbillingeirrate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingEIRRate','use_corporate_rate','inserted',(@use_corporate_rate),
		'customerbillingeirrate_uid ' + trim(str(@customerbillingeirrate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingEIRRate','eir_rate','inserted',trim(str(@eir_rate)),
		'customerbillingeirrate_uid ' + trim(str(@customerbillingeirrate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingEIRRate','date_effective','inserted',CONVERT(varchar,@date_effective,101),
		'customerbillingeirrate_uid ' + trim(str(@customerbillingeirrate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingEIRRate','apply_fee_flag','inserted',trim(@apply_fee_flag),
		'customerbillingeirrate_uid ' + trim(str(@customerbillingeirrate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		fetch next from sf_CustomerbillingEIRRATE into @customerbillingeirrate_uid,@customer_id,@billing_project_id,@use_corporate_rate,@eir_rate,@date_effective,@apply_fee_flag
		End
		Close sf_CustomerbillingEIRRATE
		DEALLOCATE sf_CustomerbillingEIRRATE 

		
		--CustomerbillingFRFRATE

		declare Sf_CustomerbillingFRFRATE CURSOR fast_forward for select customer_billing_frf_rate_uid,customer_id,billing_project_id,date_effective,apply_fee_flag,exemption_approved_by,date_exempted
		from CustomerBillingFRFRate where customer_id=@customer_id and billing_project_id=@billing_project_id

		--select @customer_billing_frf_rate_uid

	open Sf_CustomerbillingFRFRATE
	fetch next from Sf_CustomerbillingFRFRATE into @customer_billing_frf_rate_uid,@customer_id,@billing_project_id,@date_effective,@apply_fee_flag,@exemption_approved_by,@date_exempted
	While @@fetch_status=0
	Begin	
		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingFRFRate','customer_billing_frf_rate_uid','inserted',trim(str(@customer_billing_frf_rate_uid)),
		'customer_billing_frf_rate_uid: ' +trim(str(@customer_billing_frf_rate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingFRFRate','customer_id','inserted',trim(str(@customer_id)),
		'customer_billing_frf_rate_uid: ' +trim(str(@customer_billing_frf_rate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()
		

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingFRFRate','billing_project_id','inserted',trim(str(@billing_project_id)),
		'customer_billing_frf_rate_uid: ' +trim(str(@customer_billing_frf_rate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingFRFRate','date_effective','inserted',CONVERT(varchar,@date_effective,101),
		'customer_billing_frf_rate_uid: ' +trim(str(@customer_billing_frf_rate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingFRFRate','apply_fee_flag','inserted',trim(@apply_fee_flag),
		'customer_billing_frf_rate_uid: ' +trim(str(@customer_billing_frf_rate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingFRFRate','exemption_approved_by','inserted',trim(@exemption_approved_by),
		'customer_billing_frf_rate_uid: ' +trim(str(@customer_billing_frf_rate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingFRFRate','date_exempted','inserted',CONVERT(varchar,@date_exempted,101),
		'customer_billing_frf_rate_uid: ' +trim(str(@customer_billing_frf_rate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingFRFRate','added_by','inserted',@user_code,
		'customer_billing_frf_rate_uid: ' +trim(str(@customer_billing_frf_rate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingFRFRate','date_Added','inserted',getdate(),
		'customer_billing_frf_rate_uid: ' +trim(str(@customer_billing_frf_rate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

			insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingFRFRate','modified_by','inserted',@user_code,
		'customer_billing_frf_rate_uid: ' +trim(str(@customer_billing_frf_rate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()

		insert into customeraudit (customer_id,table_name,column_name,before_Value,after_Value,audit_reference,modified_by,modified_from,date_modified)
		select @customer_id,'CustomerBillingFRFRate','date_modified','inserted',getdate(),
		'customer_billing_frf_rate_uid: ' +trim(str(@customer_billing_frf_rate_uid)) +' customer_id: ' +trim(str(@customer_id)) +' billing_project_id: ' +trim(str(@billing_project_id)),
		@user_code,'Salesforce',getdate()
		
		fetch next from Sf_CustomerbillingFRFRATE into @customer_billing_frf_rate_uid,@customer_id,@billing_project_id,@date_effective,@apply_fee_flag,@exemption_approved_by,@date_exempted
		End
		Close Sf_CustomerbillingFRFRATE
		DEALLOCATE Sf_CustomerbillingFRFRATE 
	
		

	



--customerbillingdocument
 Begin
/*To handle multiple documents --Start*/
	Create table #temp_salesforce_invoice_backup_document (salesforce_invoice_backup_document varchar(80))
		        
	Set @ll_doc_len=len(@sf_invoice_backup_document)
	If @ll_doc_len > 0 
	Begin
		WHILE @ll_doc_len > 0
		BEGIN
			Set @ll_doc_index=CharIndex(';',@sf_invoice_backup_document)
			If  @ll_doc_index > 0 
				Begin
					Set @sf_invoice_backup_document_ret=Substring(@sf_invoice_backup_document,1,@ll_doc_index-1)
					Print  @sf_invoice_backup_document_ret
					Insert into #temp_salesforce_invoice_backup_document (salesforce_invoice_backup_document ) Values
																		 ( @sf_invoice_backup_document_ret)

					
											
					Set @sf_invoice_backup_document=Substring(@sf_invoice_backup_document,@ll_doc_index+1,@ll_doc_len)
				End
		   Else
		   If len(@sf_invoice_backup_document) > 0
		   Begin
			   Set @sf_invoice_backup_document_ret=Substring(@sf_invoice_backup_document,1,len(@sf_invoice_backup_document))
			   Set @ll_doc_len = -1
			   Print  @sf_invoice_backup_document_ret
			   Insert into #temp_salesforce_invoice_backup_document (salesforce_invoice_backup_document ) Values
																			 ( @sf_invoice_backup_document_ret)						  
			End			   
		  End		  
		End
	/*To handle multiple documents --End*/

	Declare sf_billingdocument CURSOR for
			Select eqai_scan_type_id_validate,validation,print_on_invoice_required_flag,category,sf_document_name_label,eqai_scan_document_type from sfdc_workorder_documenttype_translate  
			                                  Where trim(sf_document_name_label) in (Select trim(salesforce_invoice_backup_document) from 
																					 #temp_salesforce_invoice_backup_document )		
											  
			Open sf_billingdocument

	        fetch next from sf_billingdocument into @type_id,@validation,@print_on_invoice_required_flag,@category,@sf_document_name_label,@eqai_scan_document_type		
			While @@fetch_status=0
			Begin	
            
			

			If upper(@sf_document_name_label)='TM' and upper(@eqai_scan_document_type)='WORK ORDER DOCUMENT' --Do not modify the lable.doc type names
			Begin
			   Set @ls_tm_doc_flag='T'
			End

			If upper(@sf_document_name_label)='INVOICE' and upper(@eqai_scan_document_type)='WORKORDER DOCUMENT' --Do not modify the lable.doc type names
			Begin
			  Set @ls_inv_doc_flag='T'
			End

			If @ls_tm_doc_flag='T' and @ls_inv_doc_flag='T'
			Begin
			  Set @ls_customerbillingdocument_audit_ins_req='F'
			End
			
			If @ls_customerbillingdocument_audit_ins_req='T'
			Begin
				SELECT @column_value=@category 
				SELECT @column_name='trans_source'
				select @table_name='customerbillingdocument'
				Select @audit_reference = 'customer_id: ' 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' type_id: ' 
											+ TRIM(STR(@type_id ))
				INSERT INTO [dbo].CustomerAudit 
										(customer_id,table_name,column_name,before_value,after_value,audit_reference,modified_from,
											modified_by,
											date_modified
											)
									SELECT
											@customer_id,@table_name,@COLUMN_NAME,@before_value,@column_value,@audit_reference,
											'Salesforce',
											@user_code,
											@date_modified_getdate   									
										
		
				SELECT @column_value=@type_id 
				SELECT @column_name='type_id'
				select @table_name='customerbillingdocument'
				Select @audit_reference = 'customer_id: ' 
													+ trim(str(@customer_id)) +' billing project id: '
													+ trim(str(@billing_project_id)) + ' type_id: ' 
													+ TRIM(STR(@type_id ))
												
				INSERT INTO [dbo].CustomerAudit 
										(customer_id,table_name,column_name,before_value,after_value,audit_reference,modified_from,
											modified_by,
											date_modified
											)
									SELECT
											@customer_id,@table_name,@COLUMN_NAME,@before_value,@column_value,@audit_reference,
											'Salesforce',
											@user_code,
											@date_modified_getdate   

				SELECT @column_value=@validation 
				SELECT @column_name='validation'
				SELECT @table_name='customerbillingdocument'
				Select @audit_reference = 'customer_id: ' 
											+ trim(str(@customer_id)) +' billing project id: '
											+ trim(str(@billing_project_id)) + ' type_id: ' 
											+ TRIM(STR(@type_id))
										
				
				INSERT INTO [dbo].CustomerAudit 
										(customer_id,table_name,column_name,before_value,after_value,audit_reference,modified_from,
											modified_by,
											date_modified
											)
									SELECT
											@customer_id,@table_name,@COLUMN_NAME,@before_value,@column_value,@audit_reference,
											'Salesforce',
											@user_code,
											@date_modified_getdate 		
				
				SELECT @column_value=@print_on_invoice_required_flag 
				SELECT @column_name='print_on_invoice_required_flag'
				select @table_name='customerbillingdocument'
				Select @audit_reference = 'customer_id: ' 
													+ trim(str(@customer_id)) +' billing project id: '
													+ trim(str(@billing_project_id))  + ' type_id: ' 
													+ TRIM(STR(@type_id ))
												
				INSERT INTO [dbo].CustomerAudit 
										(customer_id,table_name,column_name,before_value,after_value,audit_reference,modified_from,
											modified_by,
											date_modified
											)
									SELECT
											@customer_id,@table_name,@COLUMN_NAME,@before_value,@column_value,@audit_reference,
											'Salesforce',
											@user_code,
											@date_modified_getdate 	
										
				SELECT @column_value=@status
				SELECT @column_name='status'
				select @table_name='customerbillingdocument'
				Select @audit_reference = 'customer_id: ' 
												+ trim(str(@customer_id)) +' billing project id: '
												+ trim(str(@billing_project_id)) + ' type_id: ' 
												+ TRIM(STR(@type_id ))
												
												
				INSERT INTO [dbo].CustomerAudit 
										(customer_id,table_name,column_name,before_value,after_value,audit_reference,modified_from,
											modified_by,
											date_modified
											)
									SELECT
											@customer_id,@table_name,@COLUMN_NAME,@before_value,@column_value,@audit_reference,
											'Salesforce',
											@user_code,
											@date_modified_getdate 
			End							
			fetch next from sf_billingdocument into @type_id,@validation,@print_on_invoice_required_flag,@category,@sf_document_name_label,@eqai_scan_document_type				
			End
			Close sf_billingdocument
			DEALLOCATE sf_billingdocument 
			Drop table #temp_salesforce_invoice_backup_document
															
			Set @ls_tm_doc_flag = 'F'
			Set @ls_inv_doc_flag = 'F'
			Set @ls_customerbillingdocument_audit_ins_req = 'T'		
End
END
END TRY
	BEGIN CATCH
		select @key_value = 'table_name; ' + isnull(@table_name,'') +
						'before_value; ' + isnull(@before_value,'') +
						'column_value;' + isnull(@column_value,'') +
						'COLUMN_NAME ;' + isnull(@COLUMN_NAME,'') +
						'parameter_count;' + isnull(str(@customer_billing_parameter_count),'')
						
						

		INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
										SELECT 
										@key_value, 
										@source_system, 
										'Insert', 
										ERROR_MESSAGE(), 
										GETDATE(), 
										@user_code 
										


	SELECT @ERROR ='Y'
	RETURN -1
	END CATCH 
BEGIN
IF @ERROR ='N'
	RETURN 0
	END
END


Go

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_Jobbillingauditaudit_insert] TO EQAI  
GO
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_Jobbillingauditaudit_insert] TO svc_CORAppUser
 
Go

