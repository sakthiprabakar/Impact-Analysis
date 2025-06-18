--DE37952,US141452

USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_Jobbillingproject_Insert]    Script Date: 3/21/2025 4:39:07 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER     PROCEDURE [dbo].[sp_sfdc_Jobbillingproject_Insert] 
						@break_code_1 char(1),
						@break_code_2 char(1),
						@break_code_3 char(1),
						@d365customer_id varchar(20) null,
						@invoice_package_content char(1)=Null,
						@mail_to_bill_to_address_flag char(1) null,
						@PO_required_flag char(1) =Null,
						@terms_code varchar(8) NULL,                   
						@distribution_method char(1) ='M',
						@emanifest_fee_option char(1) =Null,
						@all_facilities_flag char(1) = Null,
						@print_wos_with_start_date_flag char(1) =Null,
						@ebilling_flag char(1)=Null,
						@insurance_surcharge_flag char(1) = Null,
						@region_id int =Null,
						@custbillxcont_distribution_method char(1)='A',
						@custbillxcont_Invoice_Package_Content CHAR(1) ='C',
						@customer_billing_territory_status char(1) ='A',
						@customer_billing_territory_type char(1) ='T',
						@businesssegment_uid_1 int,
						@businesssegment_uid_2 int,
						@invoice_flag CHAR(1) =Null,
						@date_added datetime,
						@date_modified datetime,
						@emanifest_flag char(1)=Null,
						@emanifest_fee money NULL,
						@record_type char(1)='B',
						@employee_id varchar(20)=Null,
						@salesforce_jobbillingproject_csid varchar(18),
						@salesforce_salesorder_close_date datetime,
						@project_name varchar(40),
						@customer_billing_territory_code varchar(8),
						@cusbilxcontact_email varchar(60) null,						
						@invoice_comment_1 varchar(80)=Null,
						@invoice_comment_2 varchar(80)=Null,
						@invoice_comment_3 varchar(80)=Null,
						@invoice_comment_4 varchar(80)=Null,
						@invoice_comment_5 varchar(80)=Null,
						@RSG_EIN varchar(20),
						@sf_invoice_backup_document varchar(300) null,
						@reopen_flag char(1) ='F',
						@salesforce_invoice_csid varchar(18) null,
						@company_id int= Null,	
						@profit_ctr_id int= Null,
						@role varchar(80)=Null,
						@salesforce_so_quote_id varchar(15)=Null,
						@salesforce_contact_CSID varchar(18)=NULL,
						@response varchar(4000) OUTPUT

/*

Description: 

API call will be made from salesforce team to Insert the customer billing table.

Upon the Salesforce user creating and saving a new contract for a customer, 
the Salesforce contract information and all the mandatory fields will be sent to EQAI via JSON message 
and create a new billing project within EQAI JOB Billing Project Object.

Revision History:

DevOps# 79114 - 04/01/2024  Nagaraj M   Initial Creation
Devops# 80456 - 04/02/2024 Venu added @salesforce_salesorder_close_date in the customerbilling table and input parameter as well..
Devops# 80451 - 04/02/2024 Venu added @salesforce_salesorder_close_date as input parameter to recieve the value from salesforce to EQAI.
Devops# 80460 - 04/02/2024 Venu added @reopen_flag logic based on the value 'T/F' to re-open/activate the billing project.
Devops# 86560 - 05/02/2024 Nagaraj M Added more input parameters and default values.
Devops# 86019 - 05/14/2024 Venu R & Nagaraj M Added comparision logic for creating joblevel billing project.
Devops# 87468  fix deployment script review comments by Venu
Devops# 88092 - Added default values to the some of the  input parameters.
Devops# 88063 - 05/20/2024 Modified the response text for the exisiting billing projects Nagaraj.
Devops# 88062 - 05/20/2024 Modified and added addtional integaration fields Nagaraj
Devops# 88090 - 05/20/2024 Added the terriory_code valdiation parameter, not to accept null or invalid territory code.
Devops# 88136 - 05/21/2024 Removed the name field in where clause and validating the contact with only @cusbilxcontact_email and status ='A'.
Devops# 88161  - 05/21/2024 billing project id update to the workorderheader table.
Devops# 88135  - 05/22/2024 Created audit procedure to insert the values into customeraudittable. Nagaraj
Devops# 88421  - 05/24/2024 Receive More than One "Invoice_Backup_Document" implementation. Venu
Devops# 88372  - 05/24/2024 Added getdate() for date added and modified.Venu
Devops# 88641  - 05/28/2024 fix contact id 
Devops# 88674  - 05/29/2024 Fix the multidocument ignore T&M or Invoice any one.
Devops# 89039  - 06/03/2024 salesforce so quote integaration and add the criteria to check the billing project exists or not.
Devops# 89637  - 06/06/2024 EQAI - Add Original Logic to Job Level Billing Project Creation
US#116697 Override billing project ID to respective workorder
US#120475  -- 07/24/2024 Handled the empty string during comparision
[Note, If any parameter newly added, please add the parameter in the sp_sfdc_Jobbillingauditaudit_insert procedure as well]
US#124941 EQAI - Venu & Nagaraj M Job Level Billing Project - Use Values FROM EQAI Standard Billing Project
US#US131008  Added by Venu Update Job Level Billing Project evaluation criteria - remove break code logic
Rally#US134134  -- Defaulting to zero billing project id for the customerbillingeirrate.
Rally#US141970 -- Defaulting to zero billing project id for the customerbillingfrrate, and PO_validation,customer_service_id,release_required_flag,release_validation,link_required_validation
DE37952 -- Added default_po_required_flag in where clause condition for checking the billing projects already exists or not.
US141452 -- Added salesforce_contact_Csid as primary contact for searching contact id.

USE PLT_AI
GO
Declare @response nvarchar(max)
EXECUTE dbo.sp_sfdc_Jobbillingproject_Insert
@break_code_1='C',
@break_code_2='B',
@break_code_3='I',
@d365customer_id='C002788',
@invoice_package_content='C',
@mail_to_bill_to_address_flag='F',
@PO_required_flag ='T',
@terms_code ='',                   
@distribution_method='M',				
@emanifest_fee_option ='C',
@all_facilities_flag ='T',
@print_wos_with_start_date_flag ='T',
@ebilling_flag ='T',
@insurance_surcharge_flag='T',
@region_id =2,
@custbillxcont_distribution_method ='A',
@custbillxcont_Invoice_Package_Content ='C',
@customer_billing_territory_status  ='A',
@customer_billing_territory_type ='T',
@businesssegment_uid_1 =1,
@businesssegment_uid_2 =2,
@invoice_flag  ='S',
@date_added='02/05/2024',
@date_modified='02/05/2024',
@emanifest_flag='T',
@emanifest_fee=123.56,
@record_type='B',
@employee_id = '864502',
@salesforce_jobbillingproject_csid='JUN_JOBBILL_001',
@salesforce_salesorder_close_date ='08/01/2025',
@project_name ='Invoice Devops job billing 88092',	
@customer_billing_territory_code='99',
@cusbilxcontact_email ='jill.albert@usecology.com',
@invoice_comment_1='Invoice Devops job billing 88092',
@invoice_comment_2='Invoice Devops job billing 88092',
@invoice_comment_3='Invoice Devops job billing 88092',
@invoice_comment_4='Invoice Devops job billing 88092',
@invoice_comment_5='Invoice Devops job billing 88092',
@RSG_EIN='EE00132',
@reopen_flag='F',
@SF_Invoice_Backup_Document='Invoice',
@salesforce_invoice_csid='MAY20_005',
@company_id=21,
@profit_ctr_id=0,
@role='Materials Manager 3',
@salesforce_so_quote_id='NAG_WQHEA_001',
@response=@response output
print @response


/*
SELECT * FROM CUSTOMERBILLING WHERE BILLING_PROJECT_ID=51864
SELECT * FROM CustomerBillingeManifestFee WHERE BILLING_PROJECT_ID=51864
SELECT * FROM CustomerBillingEIRRate WHERE BILLING_PROJECT_ID=51864
SELECT * FROM CustomerBillingERFRate WHERE BILLING_PROJECT_ID=51864
SELECT * FROM CustomerBillingFRFRate WHERE BILLING_PROJECT_ID=51864
SELECT * FROM customerbillingdocument WHERE BILLING_PROJECT_ID=51864
SELECT * FROM CustomerBillingXContact WHERE BILLING_PROJECT_ID=51864
Select * from sfdc_workorder_documenttype_translate  ;

SELECT * FROM WORKORDERQUOTEHEADER WHERE COMPANY_ID=21 AND PROFIT_CTR_ID=0 AND salesforce_so_quote_id <>'001'
ORDER BY DATE_ADDED DESC
*/

*/



AS
BEGIN
  DECLARE 
	 @consolidate_containers_flag CHAR(1) ='T',
	 --@distrubation_method_cbilling char(1)= 'M',
	-- @apply_fee_flag char(1) ='T', 	
	 --@use_corporate_rate_EIRRATE char(1) = 'T',
	 @customer_id int,
	 @apply_fee_flag_ERF char(1)='F',
	 @apply_fee_flag_FRF char(1)='F',
	 @flag char(1) ='I',
	 @status char(1) ='A',
	 @date_effective datetime,
	 @billing_project_id INT,
	 @validation_req_field varchar(100),
     @validation_req_field_value varchar(500),
	 @validation_response varchar(1000), 
	 @ls_config_value char(1),
	 @ll_validation_ret int,	 
	 @key_value varchar(2000),
	 @user_code varchar(10)='N/A',
	 @source_system varchar(200),
	 @customer_billing_territory_primary_flag char(1) ='T',
	 @customer_billing_territory_percent float =100,
	 @eq_approved_offeror_desc varchar(255),
	 @eq_approved_offeror_flag char(1) ,
	 @eq_offeror_bp_override_flag char(1),
	 @internal_review_flag char(1) ='F',
	 @eq_offeror_effective_dt datetime ,
	 @intervention_desc varchar(255) ,
	 @invoice_print_attachment_flag CHAR(1) ='T',
	 @release_required_flag char(1) ='F',
	 --@link_required_flag CHAR(1) ='F',
	 @retail_flag char(1)='F',
	 @sort_code_1 char(1)='N', 
	 @sort_code_2 char(1)='N',
	 @sort_code_3 char(1)='N',
	 @submit_on_hold_flag CHAR(1) ='F',
	 @trip_stop_rate_default_flag CHAR(1) ='F',
	 @weight_ticket_required_flag CHAR(1) = 'F',
	 --@whca_exempt char(1) ='F',
	 --@pickup_report_flag char(1) ='F',
	 @invoice_copy_flag char(1)='T',
	 @intervention_required_flag char(1) ='F',
	 @print_wos_in_inv_attachment_flag char(1)='T',
	 @contact_id int,
	 @CUST_service_user_code varchar(10),
	 @Customer_service_ID int,
	 @ll_cnt_billing int,
	 @ll_count_rec int,
	 @ll_standard_billing_cnt int,
	 @category char(1),
	 @type_id int,
	 @validation char(1),
	 @print_on_invoice_required_flag char(1),
	 @print_toc_in_inv_attachment_flag char(1) ='T',
	 @print_rws_in_inv_attachment_flag char(1) ='T',
	 @cbilling_territory_code varchar(8)='99',
	 @ll_ret int,
	 @ll_doc_len int,
	 @ll_doc_index int,
	 @sf_invoice_backup_document_ret varchar(80),
	 @ls_tm_doc_flag Char(1) = 'F',
	 @ls_inv_doc_flag Char(1) = 'F',
	 @ls_customerbillingdocument_ins_req Char(1) = 'T',
	 @sf_document_name_label varchar(50)= null,
	 @eqai_scan_document_type varchar(50)= null,
	 @sf_invoice_backup_document_audit varchar(300),
	 @ll_cnt int,
	 @ll_type_id_cnt int,
	 @ll_standard_billing_cnt_doc int,
	 @ls_config_value_phase3 char(1),
	 --Copying standard billing project values -- Start
	@default_region_id int=Null,
	@default_invoice_package_content char(1)=Null,
	@default_invoice_flag char(1)=Null,
	@default_invoice_comment_1 varchar(80)=Null,
	@default_invoice_comment_2 varchar(80)=Null,
	@default_invoice_comment_3 varchar(80)=Null,
	@default_invoice_comment_4 varchar(80)=Null,
	@default_invoice_comment_5 varchar(80)=Null,	
	@default_PO_required_flag char(1)=Null,	
	@default_all_facilities_flag char(1)=Null,
	@default_print_wos_with_start_date_flag char(1)=Null,
	@default_insurance_surcharge_flag char(1)=Null,	
	@default_ebilling_flag char(1)=Null,
	@default_emanifest_fee money=Null,
	@default_emanifest_fee_option char(1)=Null,
	@default_emanifest_flag char(1)=Null,
	@default_collections_id int=Null, 
	@default_distrubation_method_cbilling char(1)=Null,
	@default_link_required_flag char(1)=Null, 
	@default_pickup_report_flag char(1)=Null, 
	@default_whca_exempt char(1)=Null,  
	@default_NAM_ID int=Null, 
	@default_NAS_ID int=Null,
	@po_validation char(1)=NULL,
	@release_validation char(1)=NULL,
	@link_required_validation char(1)=NULL

	--Copying standard billing project values -- End




set transaction isolation level read uncommitted

set @date_added = getdate()
set @date_modified = getdate()
set @sf_invoice_backup_document_audit=@sf_invoice_backup_document


Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag'
		IF @ls_config_value is null or @ls_config_value=''
		Begin
				Select @ls_config_value='F'
		End
IF @reopen_flag is null or @reopen_flag=''
		Begin
				Select @reopen_flag='F'
		End


Select @ls_config_value_phase3 = config_value From configuration where config_key='CRM_Golive_flag_phase3'
		IF @ls_config_value_phase3 is null or @ls_config_value_phase3=''
		Begin
				Select @ls_config_value_phase3='F'
		End

IF @ls_config_value='T'  
BEGIN

		Select @source_system = 'sp_sfdc_Jobbillingproject_Insert:: ' + 'Sales force'  
         	
			   		 	  	  	   	
		Create table #temp_salesforce_validation_fields (validation_req_field varchar(100),validation_req_field_value varchar(500))  /*To determine the validation requried field*/
		
		Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
		                                                ('d365customer_id',@d365customer_id),
														('employee_id',@employee_id),
														--('sf_invoice_backup_document',trim(@sf_Invoice_Backup_Document)),
														('customer_billing_territory_code',@customer_billing_territory_code)
														
												    
	
		If @reopen_flag='F'
        Begin  
		Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
		                                                ('salesforce_jobbillingproject_csid',@salesforce_jobbillingproject_csid),
														('salesforce_invoice_csid',@salesforce_invoice_csid),
														('company_id' , str(@company_id)),	
														('profit_ctr_id',str(@profit_ctr_id)),
														('salesforce_so_quote_id',@salesforce_so_quote_id)
        End    
				
		If @ls_config_value_phase3='F'
		Begin
		   Set @default_distrubation_method_cbilling = 'M'
		   Set @default_link_required_flag ='F'
		   Set @default_whca_exempt ='F'
		   Set @default_pickup_report_flag ='F'
		End

		If @ls_config_value_phase3='T'
		Begin
		   Set @default_distrubation_method_cbilling = Null
		   Set @default_link_required_flag = Null
		   Set @default_whca_exempt = Null
		   Set @default_pickup_report_flag = Null
		End

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
			            --Print  @sf_invoice_backup_document_ret
						Insert into #temp_salesforce_invoice_backup_document (salesforce_invoice_backup_document ) Values
																			 ( @sf_invoice_backup_document_ret)

                        Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
		                                                ('sf_invoice_backup_document',@sf_invoice_backup_document_ret)
														
						Set @sf_invoice_backup_document=Substring(@sf_invoice_backup_document,@ll_doc_index+1,@ll_doc_len)
					End
               Else
			   If len(@sf_invoice_backup_document) > 0
			   Begin
				   Set @sf_invoice_backup_document_ret=Substring(@sf_invoice_backup_document,1,len(@sf_invoice_backup_document))
				   Set @ll_doc_len = -1
				   --Print  @sf_invoice_backup_document_ret
				   Insert into #temp_salesforce_invoice_backup_document (salesforce_invoice_backup_document ) Values
																				 ( @sf_invoice_backup_document_ret)

                   Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
		                                                ('sf_invoice_backup_document',@sf_invoice_backup_document_ret)
				End			   
			  End
		  	End
          /*To handle multiple documents --End*/



		SELECT
		@key_value =	'd365customer_id ;' + isnull(@d365customer_id,'') + 
						' Emanifest fee option ;'+isnull(@emanifest_fee_option,'') + 
						' Break code1 ;'+isnull(@break_code_1,'') + 
						' Break code2 ;'+isnull(@break_code_2,'') + 
						' Break code3 ;'+isnull(@break_code_3,'') + 
						' Invoice package content ;'+isnull(@invoice_package_content,'') + 
						' Mail to bill to address flag;'+isnull(@mail_to_bill_to_address_flag,'') + 
						' PO_required_flag ;'+isnull(@PO_required_flag ,'') +
						' Terms code ;'+isnull(@terms_code,'') + 
						' Distribution method ;'+isnull(@distribution_method,'') + 
						' emanifest_fee_option ;'+isnull(@emanifest_fee_option ,'') + 
						' all_facilities_flag ;'+isnull(@all_facilities_flag  ,'') +
						' print_wos_with_start_date_flag    ;'+isnull(@print_wos_with_start_date_flag   ,'') +
						' ebilling_flag ;'+isnull(@ebilling_flag,'') +
						' insurance_surcharge_flag  ;'+isnull(@insurance_surcharge_flag,'') +
						' custbillxcont_distribution_method ;'+isnull(@custbillxcont_distribution_method ,'') +
						' custbillxcont_Invoice_Package_Content ;'+isnull(@custbillxcont_Invoice_Package_Content,'') +
						' customer_billing_territory_status ;'+isnull(@customer_billing_territory_status,'') +
						' customer_billing_territory_type  ;'+isnull(@customer_billing_territory_type,'') +
						' invoice_flag ;'+isnull(@invoice_flag,'') +
						' project_name  ;'+isnull(@project_name,'') +
						' customer_billing_territory_code  ;'+isnull(@customer_billing_territory_code ,'') +
						' cusbilxcontact_email ;'+isnull(@cusbilxcontact_email,'') +						
						' customer_billing_territory_code  ;'+isnull(@customer_billing_territory_code ,'') +
						' invoice_comment_1 ;'+isnull(@invoice_comment_1  ,'') +
						' invoice_comment_2 ;'+isnull(@invoice_comment_2 ,'') +
						' invoice_comment_3 ;'+isnull(@invoice_comment_3 ,'') +
						' invoice_comment_4 ;'+isnull(@invoice_comment_4 ,'') +
						' invoice_comment_5 ;'+isnull(@invoice_comment_5 ,'') +
						' RSG_EIN ;'+isnull(@RSG_EIN ,'') +
						' region_id  ;' + cast((convert(int,isnull(@region_id ,''))) as varchar(20))+
						' businesssegment_uid_1  ;' + cast((convert(int,isnull(@businesssegment_uid_1 ,''))) as varchar(20))+
						' businesssegment_uid_2  ;' + cast((convert(int,isnull(@businesssegment_uid_2 ,''))) as varchar(20))+
						' emanifest_fee  ;' + cast((convert(int,isnull(@emanifest_fee ,''))) as varchar(20))+
						' Date modified ;' + cast((convert(datetime,isnull(@date_modified,''))) as varchar(20))+
						' Date added ;' + cast((convert(datetime,isnull(@date_added,''))) as varchar(20))+
						' Emanifest flag ; ' + isnull(@emanifest_flag,'') +
						' Record type ;' + isnull(@record_type,'') +
						' employee_id ;' +isnull(@employee_id,'') +
						' salesforce_jobbillingproject_csid ;' +isnull(@salesforce_jobbillingproject_csid,'') +
						' salesforce_salesorder_close_date ;'+ cast((convert(datetime,isnull(@salesforce_salesorder_close_date,''))) as varchar(20)) +
						' SF_Invoice_Backup_Document ;'+isnull(@SF_Invoice_Backup_Document ,'') +
						' reopen_flag ;' +isnull(@reopen_flag ,'') +
						' salesforce_invoice_csid ;' +isnull(@salesforce_invoice_csid ,'') +
						' company_id;' + isnull(STR(@company_id  ), '') + 
						' profit_ctr_id;' + isnull(STR(@profit_ctr_id),'') +
						' Role;' +isnull(@role,'')  +
						' salesforce_so_quote_id;' +isnull(@salesforce_so_quote_id,'') +
						' salesforce_contact_CSID;' +isnull(@salesforce_contact_CSID,'')

	 Set @response = 'Integration Successful'
	
	 
	 Declare sf_validation CURSOR for
			select validation_req_field,validation_req_field_value from #temp_salesforce_validation_fields
			Open sf_validation
				fetch next from sf_validation into @validation_req_field,@validation_req_field_value		
				While @@fetch_status=0
				Begin				 
				   EXEC @ll_validation_ret=dbo.sp_sfdc_input_parm_validation 'sp_sfdc_Jobbillingproject_Insert',@validation_req_field,@validation_req_field_value,@company_id,@profit_ctr_id,@validation_response output
                   If @validation_req_field='d365customer_id' and @ll_validation_ret <> -1
								   Begin
								   select @customer_id=customer_id from Customer where ax_customer_id=@d365customer_id and cust_status='A'
								   End  

					If @validation_req_field='employee_id' and @ll_validation_ret <> -1
					Begin
					EXEC dbo.sp_sfdc_get_usercode @employee_id,@user_code output     
					End
					

				   If @ll_validation_ret = -1
				   Begin 
						 If @response = 'Integration Successful'
						 Begin
							Set @response ='Error: Integration failed due to the following reason;'
						 End
					 Set @response = @response + @validation_response+ ';'
					 Set @flag = 'E'
				   End	
					fetch next from sf_validation into @validation_req_field,@validation_req_field_value   
			   End		
           Close sf_validation
		   DEALLOCATE sf_validation 
	
		
		 Drop table #temp_salesforce_validation_fields


		 select @ll_count_rec=count(*) from ContactXRef where salesforce_contact_CSID=@salesforce_contact_CSID and customer_id=@customer_id and status ='A'
		 

		 IF @ll_count_rec=1
		 BEGIN
		 SELECT @contact_id=contact_id from ContactXRef 
										where salesforce_contact_CSID=@salesforce_contact_CSID 
										AND customer_id =@customer_id
										AND status ='A'
		
		 END

			
		 

		 IF @ll_count_rec =0
	 BEGIN
		 
		 select @ll_count_rec=count(*) from contact where email=@cusbilxcontact_email and contact_status='A'

		if @ll_count_rec = 0  
		begin		
			If @Response = 'Integration Successful'
			Begin
				Set @Response =  'Error: Integration failed due to the following reason; No contact id exists for the cusbilxcontact_email: ' +isnull(@cusbilxcontact_email,'N/A') + ' contact table.'
				Set @flag='E' 
			End
			Else
			If  @Response <> 'Integration Successful'
			Begin
				Set @Response = @Response + 'No contact id exists for the cusbilxcontact_email: ' +isnull(@cusbilxcontact_email,'N/A') +' contact table.'	
				Set @flag='E' 
			End
		end

		if @ll_count_rec = 1
			Begin
			SELECT @contact_id=contact_id from contact 
										where email=@cusbilxcontact_email and contact_status='A'

			END
		If @ll_count_rec > 1  
		BEGIN
		
			SELECT @ll_count_rec=
			COUNT(*) from contact
			INNER JOIN CONTACTXREF ON CONTACT.contact_ID=CONTACTXREF.contact_ID
										AND CONTACTXREF.customer_id=@customer_id
										AND email=@cusbilxcontact_email and contact_status='A'
										AND ContactXRef.type = 'C' 

			if @ll_count_rec = 0  
		begin		
			If @Response = 'Integration Successful'
			Begin
				Set @Response =  'Error: Integration failed due to the following reason; No contact id exists for the cusbilxcontact_email: ' +isnull(@cusbilxcontact_email,'N/A') + ' customer_id: '+ trim(str(@customer_id))
				Set @flag='E'
			End
			Else
			If  @Response <> 'Integration Successful'
			Begin
				Set @Response = @Response + 'No contact id exists for the cusbilxcontact_email: ' +isnull(@cusbilxcontact_email,'N/A') + ' customer_id: ' +  trim(str(@customer_id))	
				Set @flag='E' 
			End
		end
		
			if @ll_count_rec = 1
			BEGIN
			
			SELECT @contact_id=contact.contact_id from contact
			INNER JOIN CONTACTXREF ON CONTACT.contact_ID=CONTACTXREF.contact_ID
										AND CONTACTXREF.customer_id=@customer_id
										AND email=@cusbilxcontact_email and contact_status='A'
										AND ContactXRef.type = 'C' 
			END
		END
		
		if @ll_count_rec > 1 or @ll_count_rec = 0 
		
		BEGIN
			SELECT @ll_count_rec=
			COUNT(*) from contact 
			INNER JOIN CONTACTXREF ON CONTACT.contact_ID=CONTACTXREF.contact_ID
										AND CONTACTXREF.customer_id=@customer_id
										AND email=@cusbilxcontact_email and contact_status='A'
										AND ContactXRef.type = 'C' 
										--AND Coalesce(contact.title,'NA')=Coalesce(@role,'NA')
										AND ISNULL(NULLIF(contact.title, 'NA'), '') = ISNULL(NULLIF(@role, 'NA'), '')
			if @ll_count_rec = 0  
		begin		
			If @Response = 'Integration Successful'
			Begin
			
			    
				Set @Response =  'Error: Integration failed due to the following reason; No contact id exists for the cusbilxcontact_email: ' +isnull(@cusbilxcontact_email,'N/A') + ' customer_id: ' +trim(str(@customer_id)) + ' role: '+ isnull(@role,'N/A')
                				
				Set @flag='E' 
			End
			Else
			If  @Response <> 'Integration Successful'
			Begin
				Set @Response = @Response + 'No contact id exists for the cusbilxcontact_email: ' +isnull(@cusbilxcontact_email,'N/A') + ' customer_id: ' +trim(str(@customer_id)) + ' role: ' + isnull(@role,'N/A')
				Set @flag='E' 
			End
		end
	END

		
			if @ll_count_rec = 1
			BEGIN
			SELECT @contact_id=contact.contact_id from contact	INNER JOIN CONTACTXREF ON CONTACT.contact_ID=CONTACTXREF.contact_ID
										AND CONTACTXREF.customer_id=@customer_id
										AND email=@cusbilxcontact_email and contact_status='A'
										AND ContactXRef.type = 'C' 
										--AND Coalesce(contact.title,'NA')=Coalesce(@role,'NA')
										AND ISNULL(NULLIF(contact.title, 'NA'), '') = ISNULL(NULLIF(@role, 'NA'), '')
			END
		

			if @ll_count_rec > 1 and @flag <> 'E'
			BEGIN
			SELECT top 1 @contact_id=CONTACT.contact_ID from CONTACT
			INNER JOIN CONTACTXREF ON CONTACT.contact_ID=CONTACTXREF.contact_ID
			AND	contactxref.customer_id=@customer_id
			AND email=@cusbilxcontact_email and contact_status='A'
			AND ContactXRef.type = 'C'
		--	AND Coalesce(contact.title,'NA')=Coalesce(@role,'NA')
			AND ISNULL(NULLIF(contact.title, 'NA'), '') = ISNULL(NULLIF(@role, 'NA'), '')
			order by CONTACT.date_added,CONTACTXREF.date_added asc
			END
		END

		/*Comparison of Standard billing project validation starts*/
		Begin

		if @PO_required_flag ='' or @PO_required_flag is null and @ls_config_value_phase3='T'
		BEGIN
			select @default_PO_required_flag=PO_required_flag from customerbilling where customer_id=@customer_id and billing_project_id=0
		END
		
		select @ll_standard_billing_cnt=count(*) from customerbilling
									  INNER JOIN CustomerBillingXContact ON CustomerBillingXContact.contact_id=@contact_id and
																			CustomerBillingXContact.customer_id=customerbilling.customer_id 
                                      /*INNER JOIN CustomerBillingDocument ON CustomerBillingDocument.customer_id=customerbilling.customer_id and
									                                        CustomerBillingDocument.status='A' and                                      
																			type_id in (Select eqai_scan_type_id_validate 
																				              from sfdc_workorder_documenttype_translate 
																							  Where --trim(sf_document_name_label)=trim(@sf_invoice_backup_document))	                                                                        
																							  trim(sf_document_name_label) in (Select trim(salesforce_invoice_backup_document) from #temp_salesforce_invoice_backup_document ))	*/
                                      Where customerbilling.customer_id=@customer_id 
									  and customerbilling.status='A'
									  and isnull(terms_code,'')=isnull(@terms_code,'')
									  --and Coalesce(break_code_1,'')=Coalesce(@break_code_1,'')
									 -- and Coalesce(break_code_2,'')=Coalesce(@break_code_2,'')
									  --and Coalesce(break_code_3,'')=Coalesce(@break_code_3,'')
									  --and isnull(PO_required_flag,'')=isnull(@PO_required_flag,'')
									  and isnull(PO_required_flag,'')=isnull(@PO_required_flag,@default_PO_required_flag)
									  and (customerbilling.salesforce_so_quote_id=@salesforce_so_quote_id or isnull(customerbilling.salesforce_so_quote_id,'')='')

        
		Create table #temp_salesforce_invoice_backup_document_type (eqai_scan_type_id_validate int)

		Insert into #temp_salesforce_invoice_backup_document_type (eqai_scan_type_id_validate) 
																			Select distinct eqai_scan_type_id_validate from sfdc_workorder_documenttype_translate
		                                                                           Where trim(sf_document_name_label) in 
																						     (Select trim(salesforce_invoice_backup_document) from #temp_salesforce_invoice_backup_document)
			
          
         select @ll_type_id_cnt= count(*) from #temp_salesforce_invoice_backup_document_type

		

	     select @ll_standard_billing_cnt_doc= count(*) from CustomerBillingDocument Where  CustomerBillingDocument.customer_id=@customer_id  and
									                                        CustomerBillingDocument.status='A' and                                      
																			type_id in (Select eqai_scan_type_id_validate from #temp_salesforce_invoice_backup_document_type)	
         
          
		  If  @ll_type_id_cnt > @ll_standard_billing_cnt_doc
			Begin
			Set @ll_standard_billing_cnt_doc = 0
			End
		 		
		  End

			if @ll_standard_billing_cnt >= 1 and @ll_standard_billing_cnt_doc >=1
			begin			
			
			select Top 1 @billing_project_id= customerbilling.billing_project_id from customerbilling
									  INNER JOIN CustomerBillingXContact ON CustomerBillingXContact.contact_id=@contact_id and
																			CustomerBillingXContact.customer_id=customerbilling.customer_id                                      
                                      Where customerbilling.customer_id=@customer_id 
									  and customerbilling.status='A'
									  and isnull(terms_code,'')=isnull(@terms_code,'')
									  --and Coalesce(break_code_1,'')=Coalesce(@break_code_1,'')
									  --and Coalesce(break_code_2,'')=Coalesce(@break_code_2,'')
									 --and Coalesce(break_code_3,'')=Coalesce(@break_code_3,'')
									  --and isnull(PO_required_flag,'')=isnull(@PO_required_flag,'')
									  and isnull(PO_required_flag,'')=isnull(@PO_required_flag,@default_PO_required_flag)
									  and (customerbilling.salesforce_so_quote_id=@salesforce_so_quote_id or isnull(customerbilling.salesforce_so_quote_id,'')='')

             Update WorkorderHeader set billing_project_id=@billing_project_id Where workorder_id in
			   															 (Select workorder_id from workorderheader where 
																		   company_id=@company_id and 
						                                                   profit_ctr_ID=@profit_ctr_id and 
																		   salesforce_invoice_csid=@salesforce_invoice_csid) 
			If @Response = 'Integration Successful'
				Begin
					Set @Response =  'Error: Integration failed due to the following reason;  billing project already exists for this customer:'+ trim(str(@customer_id)) +' with same criteria'
					Set @flag='E' 
				End
				Else
				If  @Response <> 'Integration Successful'
				Begin
					Set @Response = @Response + 'billing project already exists for this customer:'+ trim(str(@customer_id)) +' with same criteria'
					Set @flag='E' 
				End
			End

			Drop table #temp_salesforce_invoice_backup_document_type
			 

		/*Comparison of Standard billing project validation ends*/

		If @reopen_flag='T' 
		BEGIN
		Select @ll_cnt_billing= count(*) from CustomerBilling where salesforce_jobbillingproject_csid=@salesforce_jobbillingproject_csid
			if @ll_cnt_billing =0 
			BEGIN
				Set @response ='Error: salesforce_jobbillingproject_csid does not exists in customerbilling table'
				SET @flag='E'
			END
			if @ll_cnt_billing > 1
			BEGIN
				Set @response ='Error: More than one salesforce_jobbillingproject_csid exists in customerbilling table'
				SET @flag='E'
			END
		END 


	
		If @flag = 'E'
		Begin		
		INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
										SELECT
										@key_value,
										@source_system,
										'Insert',
										@Response,
										GETDATE(),
										@user_code
		Return -1		
		End	
 Begin Transaction  
	If @reopen_flag='F'
	Begin
	IF @FLAG <>'E'	
	BEGIN
			SELECT top 1 @date_effective=date_effective FROM eManifestUserFee 
					WHERE emanifest_submission_type_uid = 2 AND 
						  date_effective <= GETDATE()
					ORDER BY date_effective DESC

			EXECUTE @billing_project_id = sp_sequence_next 'CustomerBilling.Billing_Project_ID'	

			Select @CUST_service_user_code=user_code--,@Customer_service_ID=type_id
			from UsersXEQContact
			where user_code in (select user_code from users where employee_id = @RSG_EIN)
			
				If @ls_config_value_phase3='T'
				Begin
					select @default_region_id=region_id,
					@default_invoice_package_content=invoice_package_content,
					@default_invoice_flag=invoice_flag,
					@default_invoice_comment_1=invoice_comment_1,
					@default_invoice_comment_2=invoice_comment_2,
					@default_invoice_comment_3=invoice_comment_3,
					@default_invoice_comment_4=invoice_comment_4,
					@default_invoice_comment_5=invoice_comment_5,
					@default_distrubation_method_cbilling=distribution_method,
					@default_link_required_flag=link_required_flag,
					@default_pickup_report_flag=pickup_report_flag,
					@default_whca_exempt=whca_exempt,
					--@default_PO_required_flag=PO_required_flag,
					@default_collections_id=collections_id,
					@default_NAM_ID=NAM_ID,
					@default_NAS_ID=NAS_ID,
					@default_all_facilities_flag=all_facilities_flag,
					@default_print_wos_with_start_date_flag=print_wos_with_start_date_flag,
					@default_insurance_surcharge_flag=insurance_surcharge_flag,
					@po_validation=po_validation,
					@customer_service_id=customer_service_id,
					@release_required_flag=release_required_flag,
					@release_validation=release_validation,
					@link_required_validation=link_required_validation 
					from CustomerBilling
					where customer_id=@customer_id
					and billing_project_id=0

					create table #temp_CustomerBillingeManifestFee (date_effective datetime,emanifest_fee money,emanifest_flag char(1),emanifest_fee_option char(1))
					insert into #temp_CustomerBillingeManifestFee
					(date_effective,emanifest_fee,emanifest_flag,emanifest_fee_option)
					SELECT  top 1 max (DATE_EFFECTIVE),emanifest_fee,
					emanifest_flag,
					emanifest_fee_option 
					FROM CustomerBillingeManifestFee WHERE CUSTOMER_ID=@customer_id
					AND billing_project_id=0
					group by emanifest_fee,emanifest_flag,emanifest_fee_option
			
			
					select @default_emanifest_fee=emanifest_fee,@default_emanifest_flag=emanifest_flag,@default_emanifest_fee_option=emanifest_fee_option
					from  #temp_CustomerBillingeManifestFee

					drop table #temp_CustomerBillingeManifestFee
				End

				

				Insert into customerbilling
					(mail_to_bill_to_address_flag,
					customer_id,
					billing_project_id,
					project_name,
					terms_code,
					distribution_method,
					break_code_1,
					break_code_2,
					break_code_3,
					consolidate_containers_flag,
					PO_required_flag,
					status,
					added_by,
					date_added,
					modified_by,
					date_modified,
					record_type,
					salesforce_jobbillingproject_csid,
					salesforce_salesorder_close_date,
					invoice_comment_1,
					invoice_comment_2,
					invoice_comment_3,
					invoice_comment_4,
					invoice_comment_5,
					Customer_service_ID,
					PO_validation,
					eq_approved_offeror_desc,
					eq_approved_offeror_flag,
					eq_offeror_bp_override_flag,
					internal_review_flag,
					eq_offeror_effective_dt,
					intervention_desc,
					invoice_print_attachment_flag,
					link_required_flag,
					retail_flag,
					sort_code_1,
					sort_code_2,
					sort_code_3,
					submit_on_hold_flag,
					trip_stop_rate_default_flag,
					weight_ticket_required_flag,
					all_facilities_flag,
					print_wos_in_inv_attachment_flag,
					print_wos_with_start_date_flag,
					insurance_surcharge_flag,
					region_id,
					invoice_flag,
					whca_exempt,
					print_toc_in_inv_attachment_flag,
					print_rws_in_inv_attachment_flag,
					invoice_package_content,
					ebilling_flag,
					territory_code,
					pickup_report_flag,
					intervention_required_flag,
					salesforce_so_quote_id,
					NAM_ID,
					NAS_id,
					collections_id,
					release_required_flag,
					release_validation,
					link_required_validation
					)
					select
					@mail_to_bill_to_address_flag,
					@customer_id,
					@billing_project_id,
					@project_name,
					@terms_code,
					@default_distrubation_method_cbilling,					
					@break_code_1,
					@break_code_2,
					@break_code_3,
					@consolidate_containers_flag,
					case when (@PO_required_flag is null or @PO_required_flag='') then @default_PO_required_flag
					else @PO_required_flag end,
					@status,
					@user_code,
					@date_added,
					@user_code,
					@date_modified,
					@record_type,
					@salesforce_jobbillingproject_csid,
					@salesforce_salesorder_close_date,
					case when (@invoice_comment_1 is null or @invoice_comment_1='') then @default_invoice_comment_1
					else @invoice_comment_1 end,
					case when (@invoice_comment_2 is null or @invoice_comment_2='') then @default_invoice_comment_2
					else @invoice_comment_2 end,
					case when (@invoice_comment_3 is null or @invoice_comment_3='') then @default_invoice_comment_3
					else @invoice_comment_3 end,
					case when (@invoice_comment_4 is null or @invoice_comment_4='') then @default_invoice_comment_4
					else @invoice_comment_4 end,
					case when (@invoice_comment_5 is null or @invoice_comment_5='') then @default_invoice_comment_5
					else @invoice_comment_5 end,
					@Customer_service_ID,
					/*case when @PO_required_flag='T' THEN 'E'
					WHEN @PO_required_flag='F' THEN 'W'
					ELSE NULL 
					END,*/
					@po_validation,
					@eq_approved_offeror_desc,
					@eq_approved_offeror_flag,
					@eq_offeror_bp_override_flag,
					@internal_review_flag,
					@eq_offeror_effective_dt,
					@intervention_desc,
					@invoice_print_attachment_flag,					
					@default_link_required_flag,
					@retail_flag,
					@sort_code_1,
					@sort_code_2,
					@sort_code_3,
					@submit_on_hold_flag,
					@trip_stop_rate_default_flag,
					@weight_ticket_required_flag,
					case when (@all_facilities_flag is null or @all_facilities_flag ='') then @default_all_facilities_flag
					else @all_facilities_flag end,
					@print_wos_in_inv_attachment_flag,
					case when (@print_wos_with_start_date_flag is null or @print_wos_with_start_date_flag='') then @default_print_wos_with_start_date_flag
					else @print_wos_with_start_date_flag end,
					case when (@insurance_surcharge_flag is null or @insurance_surcharge_flag='') then @default_insurance_surcharge_flag
					else @insurance_surcharge_flag end,
					case when (@region_id is null or @region_id='')  then @default_region_id
					else @region_id end,
					case when (@invoice_flag is null or @invoice_flag='') then @default_invoice_flag
					else @invoice_flag end,
					@default_whca_exempt,					
					@print_toc_in_inv_attachment_flag,
					@print_rws_in_inv_attachment_flag,
					case when (@invoice_package_content is null or @invoice_package_content='') then @default_invoice_package_content
					else @invoice_package_content end,
					case when (@ebilling_flag is null or @ebilling_flag='') then @default_ebilling_flag
					else @ebilling_flag end,
					@cbilling_territory_code,
					@default_pickup_report_flag,					
					@intervention_required_flag,
					@salesforce_so_quote_id,
					@default_NAM_ID,
					@default_NAS_ID,
					@default_collections_id,
					@release_required_flag,
					@release_validation,
					@link_required_validation
					
					
			
			        
					if @@error <> 0
					begin
						rollback transaction
						SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting customerbilling table;'+ isnull(ERROR_MESSAGE(),' ')
   						INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   														SELECT
   														@key_value,
   														@source_system,
    														'Insert',
    														@Response,
    														GETDATE(),
   														@user_code
						return -1
					End

				insert into CustomerBillingeManifestFee
					(customer_id,
					billing_project_id,
					emanifest_fee_option,
					emanifest_fee,
					emanifest_flag,
					date_effective,
					added_by,
					date_added,
					modified_by,
					date_modified)
					select
					@customer_id,
					@billing_project_id,
					case when (@emanifest_fee_option is null or @emanifest_fee_option='') then @default_emanifest_fee_option
					else @emanifest_fee_option end,
					case when (@emanifest_fee is null or @emanifest_fee='') then @default_emanifest_fee
					else @emanifest_fee end,
					case when (@emanifest_flag is null or @emanifest_flag='') then @default_emanifest_flag
					else @emanifest_flag end,
					@date_effective,
					@user_code,
					@date_added,
					@user_code,
					@date_modified		

				if @@error <> 0  				
				Begin
					Rollback transaction
					SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting CustomerBillingeManifestFee table; '+ isnull(ERROR_MESSAGE(),' ')
   					INSERT INTO PLT_AI_AUDIT..Source_Error_Log
					(Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   														SELECT
   														@key_value,
   														@source_system,
    														'Insert',
    														@Response,
    														GETDATE(),
   														@user_code
					Return -1
				End

				/*insert into CustomerBillingEIRRate
				(
				customer_id,
				billing_project_id,
				use_corporate_rate,
				EIR_RATE,
				DATE_EFFECTIVE,
				added_by,
				date_added,
				modified_by,
				date_modified,
				apply_fee_flag
				)
				select
				@customer_id,
				@billing_project_id,
				@use_corporate_rate_EIRRATE,  
				NULL,
				GETDATE(),
				@user_code,
				@date_added,
				@user_code,
				@date_modified,
				@apply_fee_flag
				*/


				insert into customerbillingeirrate (customer_id,billing_project_id,use_corporate_Rate,eir_rate,date_effective,added_by,date_added,modified_by,date_modified,apply_fee_flag)
				select @customer_id,@billing_project_id,use_corporate_Rate,eir_Rate,date_effective,	@user_code,GETDATE(),@user_code,GETDATE(),apply_fee_flag
				FROM customerbillingeirrate
				WHERE CUSTOMER_ID=@CUSTOMER_ID
				AND BILLING_PROJECT_ID=0

				if @@error <> 0
				Begin
					Rollback transaction
					SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting CustomerBillingEIRRate table; '+ isnull(ERROR_MESSAGE(),' ')
					INSERT INTO PLT_AI_AUDIT..Source_Error_Log
					(Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   					SELECT
   					@key_value,
   					@source_system,
    					'Insert',
    					@Response,
    					GETDATE(),
   					@user_code
					return -1
				End




				
				INSERT INTO CUSTOMERbillingFRFRATE
				(customer_id,billing_project_id,date_effective,apply_fee_flag,exemption_approved_by,exemption_reason_uid,date_exempted,added_by,date_added,modified_by,date_modified)
				select @customer_id,@billing_project_id,date_effective,apply_fee_flag,exemption_approved_by,exemption_reason_uid,date_exempted,@user_code,GETDATE(),@user_code,GETDATE()
				FROM CUSTOMERbillingFRFRATE
				WHERE CUSTOMER_ID=@CUSTOMER_ID
				AND BILLING_PROJECT_ID=0


				if @@error <> 0
				Begin
					Rollback transaction
					SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting CustomerBillingFRFRRate table; '+ isnull(ERROR_MESSAGE(),' ')
					INSERT INTO PLT_AI_AUDIT..Source_Error_Log
					(Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   					SELECT
   					@key_value,
   					@source_system,
    					'Insert',
    					@Response,
    					GETDATE(),
   					@user_code
					return -1
				End

			
			Declare sf_billingdocument CURSOR fast_forward for
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
			  Set @ls_customerbillingdocument_ins_req='F'
			End

			If @ls_customerbillingdocument_ins_req='T'
			Begin
		       Insert into customerbillingdocument(customer_id,
												   billing_project_id,
												   status,
												   trans_source,
												   type_id,
												   validation,
												   added_by,
												   date_added,
												   modified_by,
												   date_modified,
												   print_on_invoice_required_flag)
													select
													@customer_id,
													@billing_project_id,
													@status,
													@category,
													@type_id,				
							                        @validation,
													@user_code,
													@date_added,
													@user_code,
													@date_modified,
													@print_on_invoice_required_flag

                 Set @ls_customerbillingdocument_ins_req='T'

					if @@error <> 0
					Begin
					    Drop table #temp_salesforce_invoice_backup_document
						Rollback transaction
						SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting customerbillingdocument table; '+ isnull(ERROR_MESSAGE(),' ')
   						INSERT INTO PLT_AI_AUDIT..Source_Error_Log 
						(Input_Params,
							source_system_details,
							action,
							Error_description,
							log_date,
							Added_by)
							SELECT
   							@key_value,
   							@source_system,
    							'Insert',
    							@Response,
    							GETDATE(),
   							@user_code
					Return -1
					end
					End

					fetch next from sf_billingdocument into @type_id,@validation,@print_on_invoice_required_flag,@category,@sf_document_name_label,@eqai_scan_document_type				
					End
					Close sf_billingdocument
					DEALLOCATE sf_billingdocument 
			        Drop table #temp_salesforce_invoice_backup_document
															
					Set @ls_tm_doc_flag = 'F'
					Set @ls_inv_doc_flag = 'F'
					Set @ls_customerbillingdocument_ins_req = 'T'
			

										
				Insert into CustomerBillingXContact
				(
				customer_id,
				billing_project_id,
				contact_id,
				invoice_copy_flag,
				distribution_method,
				added_by,
				date_added,
				modified_by,
				date_modified,
				attn_name_flag,
				invoice_package_content
				)
				select
				@customer_id,
				@billing_project_id,
				@contact_id,	
				@invoice_copy_flag,
				@custbillxcont_distribution_method,
				@user_code,
				@date_added,
				@user_code,
				@date_modified,
				NULL,
				@custbillxcont_Invoice_Package_Content
			
				if @@error <> 0
				Begin
				 Rollback transaction
				 SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting CustomerBillingXContact table; '+ isnull(ERROR_MESSAGE(),' ')
				 INSERT INTO PLT_AI_AUDIT..Source_Error_Log 
				 (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   				 SELECT
   				 @key_value,
   				 @source_system,
    				 'Insert',
    				 @Response,
				 GETDATE(),
   				 @user_code
	  			 return -1
			   End		

			INSERT INTO CustomerBillingTerritory
				(
				customer_id,
				billing_project_id,
				businesssegment_uid,
				customer_billing_territory_type,
				customer_billing_territory_code,
				customer_billing_territory_primary_flag,
				customer_billing_territory_percent,
				customer_billing_territory_status,
				added_by,
				date_added,
				modified_by,
				date_modified
				)
				select
				@customer_id,
				@billing_project_id,
				@businesssegment_uid_1,
				@customer_billing_territory_type,
				@customer_billing_territory_code,
				@customer_billing_territory_primary_flag,
				@customer_billing_territory_percent,
				@customer_billing_territory_status,
				@USER_CODE,
				GETDATE(),
				@USER_CODE,
				GETDATE()

				if @@error <> 0
				Begin
				 Rollback transaction
				 SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting CustomerBillingTerritory table; '+ isnull(ERROR_MESSAGE(),' ')
				 INSERT INTO PLT_AI_AUDIT..Source_Error_Log 
				 (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   				 SELECT
   				 @key_value,
   				 @source_system,
    				 'Insert',
    				 @Response,
				 GETDATE(),
   				 @user_code
	  			 return -1
			   End


				INSERT INTO CustomerBillingTerritory
				(
				customer_id,
				billing_project_id,
				businesssegment_uid,
				customer_billing_territory_type,
				customer_billing_territory_code,
				customer_billing_territory_primary_flag,
				customer_billing_territory_percent,
				customer_billing_territory_status,
				added_by,
				date_added,
				modified_by,
				date_modified
				)
				select
				@customer_id,
				@billing_project_id,
				@businesssegment_uid_2,
				@customer_billing_territory_type,
				@customer_billing_territory_code,
				@customer_billing_territory_primary_flag,
				@customer_billing_territory_percent,
				@customer_billing_territory_status,
				@USER_CODE,
				GETDATE(),
				@USER_CODE,
				GETDATE()

				if @@error <> 0
				Begin
				 Rollback transaction
				 SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting CustomerBillingTerritory table; '+ isnull(ERROR_MESSAGE(),' ')
				 INSERT INTO PLT_AI_AUDIT..Source_Error_Log 
				 (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   				 SELECT
   				 @key_value,
   				 @source_system,
    				 'Insert',
    				 @Response,
				 GETDATE(),
   				 @user_code
	  			 return -1
			   End

               Update WorkorderHeader set billing_project_id=@billing_project_id Where workorder_id in
			   															 (Select workorder_id from workorderheader where 
																		   company_id=@company_id and 
						                                                   profit_ctr_ID=@profit_ctr_id and 
																		   salesforce_invoice_csid=@salesforce_invoice_csid)

              if @@error <> 0
				Begin
				 Rollback transaction
				 SELECT @Response = 'Error: Integration failed due to the following reason; Error updating workorderheader table; '+ isnull(ERROR_MESSAGE(),' ')
				 INSERT INTO PLT_AI_AUDIT..Source_Error_Log 
				 (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   				 SELECT
   				 @key_value,
   				 @source_system,
    				 'Update',
    				 @Response,
				 GETDATE(),
   				 @user_code
	  			 return -1
			   End  


		END
	END 
    If @reopen_flag='T' AND @FLAG <>'E'
	Begin
		Select @ll_cnt_billing= count(*)
		from
		CustomerBilling where salesforce_jobbillingproject_csid=@salesforce_jobbillingproject_csid
		If @ll_cnt_billing = 1 
		begin
			Update CustomerBilling set status='A', 
			salesforce_salesorder_close_date=Null,
			modified_by=@user_code,
			date_modified=@date_modified
			where salesforce_jobbillingproject_csid=@salesforce_jobbillingproject_csid
		end
		
End

			EXEC @ll_ret=dbo.sp_sfdc_Jobbillingauditaudit_insert
			@break_code_1,@break_code_2,@break_code_3,@invoice_package_content,@mail_to_bill_to_address_flag,@PO_required_flag,@terms_code,@distribution_method ,
			@emanifest_fee_option,@all_facilities_flag ,@print_wos_with_start_date_flag ,@ebilling_flag ,@insurance_surcharge_flag ,@region_id,
			@custbillxcont_distribution_method,@custbillxcont_Invoice_Package_Content,@customer_billing_territory_status,@customer_billing_territory_type ,
			@businesssegment_uid_1,@businesssegment_uid_2,@invoice_flag ,@date_added,@date_modified,
			@emanifest_flag ,@emanifest_fee,@record_type ,@employee_id,@salesforce_jobbillingproject_csid,@project_name,@customer_billing_territory_code,@cusbilxcontact_email,
			@invoice_comment_1,@invoice_comment_2,@invoice_comment_3,@invoice_comment_4,@invoice_comment_5,@RSG_EIN,@sf_invoice_backup_document_audit,
			@salesforce_invoice_csid,@consolidate_containers_flag ,@default_distrubation_method_cbilling ,/*@apply_fee_flag ,@use_corporate_rate_EIRRATE ,*/
			@customer_id,@status ,@date_effective,@billing_project_id,@user_code,@customer_billing_territory_primary_flag ,@customer_billing_territory_percent,@eq_approved_offeror_desc,
			@eq_approved_offeror_flag,@eq_offeror_bp_override_flag ,@internal_review_flag ,@eq_offeror_effective_dt,@intervention_desc,@invoice_print_attachment_flag ,@release_required_flag ,
			@default_link_required_flag ,@retail_flag ,@sort_code_1 ,@sort_code_2 ,@sort_code_3 ,@submit_on_hold_flag ,@trip_stop_rate_default_flag ,@weight_ticket_required_flag ,
			@default_whca_exempt ,@default_pickup_report_flag ,@invoice_copy_flag ,@intervention_required_flag ,@print_wos_in_inv_attachment_flag ,@contact_id,
			@CUST_service_user_code,@Customer_service_ID,@category ,@type_id,@print_on_invoice_required_flag ,@print_toc_in_inv_attachment_flag ,@print_rws_in_inv_attachment_flag ,
			@cbilling_territory_code,@salesforce_so_quote_id,@release_validation,@link_required_validation,@po_validation
		
			
			IF @ll_ret <> 0
			BEGIN
			ROLLBACK TRANSACTION;
				 SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting customeraudit table; '+ isnull(ERROR_MESSAGE(),' ')
				 INSERT INTO PLT_AI_AUDIT..Source_Error_Log 
				 (
				 Input_Params,
				 source_system_details,
				 action,
				 Error_description,
				 log_date,
				 Added_by
				 )
   				 SELECT
   				 @key_value,
   				 @source_system,
    			'Insert',
    			 @Response,
				 GETDATE(),
   				 @user_code
	  			return -1
			   End
			   
Commit Transaction;

End
If @ls_config_value='F'
	BEGIN
		select @response = 'SFDC Data Integration Failed,since CRM Go live flag off. Hence Store procedure will not execute.'
		Return -1
	END
END



GO



GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_Jobbillingproject_Insert] TO EQAI  

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_Jobbillingproject_Insert] TO svc_CORAppUser

GO