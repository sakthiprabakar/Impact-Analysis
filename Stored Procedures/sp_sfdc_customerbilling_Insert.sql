USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_customerbilling_Insert]    Script Date: 4/29/2024 3:04:38 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sp_sfdc_customerbilling_Insert] 
						@emanifest_fee_option char(1) ='C',
						@all_facilities_flag char(1)='T',
						@break_code_1 char(1) null,
						@break_code_2 char(1) null,
						@break_code_3 char(1) null,
						@d365customer_id varchar(20) null,
						@insurance_surcharge_flag char(1)='T',
						@invoice_flag char(1) ='S',
						@invoice_package_content_Cbilling char(1)='C',
						@invoice_package_content char(1)='A',
						@mail_to_bill_to_address_flag char(1) null,
						@PO_required_flag char(1) NULL,
						@region_id int =2,
						@print_wos_with_start_date_flag char(1)='T',
						@terms_code varchar(8) null,                   
						@distribution_method char(1) ='E',				
						@emanifest_fee money null,					
						@date_added datetime,
						@date_modified datetime,
						@Salesforce_Contract_Number varchar(80) null,
						@Invoice_copy_flag char(1) null,
						@emanifest_flag char(1)='T' ,
						@project_name varchar(40) null,
						@record_type char(1)='B',
						@employee_id varchar(20)=Null,
						@cusbilxcontact_email varchar(60) null,
						@cusbilxcontact_name varchar(40) null,
						@ebilling_flag char(1) null,
						@customer_billing_territory_code varchar(8),
						@invoice_comment_1 varchar(80),
						@invoice_comment_2 varchar(80),
						@invoice_comment_3 varchar(80),
						@invoice_comment_4 varchar(80),
						@invoice_comment_5 varchar(80),
						@customer_billing_territory_status char(1) ='A',
						@customer_billing_territory_type char(1) ='T',
						@businesssegment_uid_1 INT =1,
						@businesssegment_uid_2 INT =2,
						@RSG_EIN varchar(20),
						@response nvarchar(max) OUTPUT

/*

Description: 

API call will be made from salesforce team to Insert the customer billing table.

Upon the Salesforce user creating and saving a new contract for a customer, 
the Salesforce contract information and all the mandatory fields will be sent to EQAI via JSON message 
and create a new billing project within EQAI Customer Billing Project Object.

Revision History:

DevOps# 76418 - 12/26/2023  Nagaraj M   Created
Devops# 77621 - 02/08/2024 Venu / Nagaraj Addtional field integration.
Devops# 81419 -- 03/19/2024 Venu Populate the user_code to added_by and modified_by fields
Devops# 80462 -- 04/01/2024 Nagaraj Added customerbillingterritory table data values and 
						    modified few input parameters default values as well.
Devops# 80454 -- 04/01/2024 Added the sp_sfdc_customeraudit_insert to insert the customeraudit records.
Devops# 85363 -- 04/23/2024  Nagaraj M   Added the input parameters and modified the default values as per the latest mapping sheet.
Devops# 84649  -- 04/24/2024 Nagaraj M Added prefix 'SF Contract - ' to the @project_name

USE PLT_AI
GO
Declare @response nvarchar(max)
EXECUTE dbo.sp_sfdc_customerbilling_Insert
@emanifest_fee_option ='C',
@all_facilities_flag ='T',
@break_code_1 ='C',
@break_code_2 ='B',
@break_code_3 ='I',
@d365customer_id ='C306290',
@insurance_surcharge_flag ='T',
@invoice_flag  ='S',
@invoice_package_content_cbilling ='C',
@invoice_package_content ='A',
@mail_to_bill_to_address_flag='F',
@PO_required_flag='T',
@region_id=8,
@print_wos_with_start_date_flag ='T',
@terms_code ='',               
@distribution_method ='E',				
@emanifest_fee =123.45,
@date_added ='02/08/2024',
@date_modified = '02/08/2024',
@Salesforce_Contract_Number='MAY02_CUSBIL_003',
@Invoice_copy_flag = null,
@emanifest_flag ='T',
@project_name='Devops testing 85353',
@record_type ='B',
@employee_id='864502',
@cusbilxcontact_email ='itcommunications@usecology.com',
@cusbilxcontact_name  ='MIKE DORMAN',
@ebilling_flag='T',
@customer_billing_territory_code =99,
@invoice_comment_1 ='Devops testing 85353',
@invoice_comment_2 ='Devops testing 85353',
@invoice_comment_3 ='Devops testing 85353',
@invoice_comment_4 ='Devops testing 85353',
@invoice_comment_5 ='Devops testing 85353',
@customer_billing_territory_status ='A',
@customer_billing_territory_type ='T',
@businesssegment_uid_1 =1,
@businesssegment_uid_2 =2,
@RSG_EIN='EE00132',
@response=@response output
print @response

SELECT * FROM CUSTOMERBILLING WHERE BILLING_PROJECT_ID=51834
SELECT * FROM CustomerBillingeManifestFee WHERE BILLING_PROJECT_ID=51834
SELECT * FROM CustomerBillingEIRRate WHERE BILLING_PROJECT_ID=51834
SELECT * FROM CustomerBillingERFRate WHERE BILLING_PROJECT_ID=51834
SELECT * FROM CustomerBillingFRFRate WHERE BILLING_PROJECT_ID=51834
SELECT * FROM customerbillingdocument WHERE BILLING_PROJECT_ID=51834
SELECT * FROM CustomerBillingXContact WHERE BILLING_PROJECT_ID=51834

*/

AS
BEGIN
  DECLARE 
	 @consolidate_containers_flag CHAR(1) ='T',
	 @distrubation_method_cbilling char(1)= 'M',
	 @eq_approved_offeror_desc varchar(20)=NULL,
	 @eq_approved_offeror_flag char(1) =NULL,
	 @eq_offeror_bp_override_flag char(1) =NULL,
	 @eq_offeror_effective_dt datetime =NULL,
	 @internal_review_flag char(1) = 'F',
	 @intervention_desc varchar(255) =NULL,
	 @intervention_required_flag char(1)='F',
	 @invoice_print_attachment_flag char(1) ='T',
	 @link_required_flag char(1) ='F',
	 @pickup_report_flag char(1) ='F',
	 @release_required_flag char(1) ='F',
	 @print_wos_in_inv_attachment_flag char(1) ='T',
	 @retail_flag char(1) ='F',
	 @sort_code_1 char(1) ='N',
	 @sort_code_2 char(1) ='N',
	 @sort_code_3 char(1) ='N',
	 @status char(1) ='A',
	 @submit_on_hold_flag char(1)='F',
	 @trip_stop_rate_default_flag char(1) ='F',
	 @weight_ticket_required_flag char(1) ='F',
	 @whca_exempt char(1) ='F',
	 @validation_error char(1) ='E', 
	 @validation_warning char(1) ='W', 
	 @print_on_invoice_required_flag_T char(1) ='T', 
	 @print_on_invoice_required_flag_F char(1) ='F', 	
	 @apply_fee_flag char(1) ='T', 	
	 @source_system varchar(200),
	 @ls_config_value char(1),
	 @key_value nvarchar(max),
	 @FLAG CHAR(1)='I',
	 @customer_id int,
	 @billing_project_id int,
	 @use_corporate_rate_EIRRATE char(1)='T',
	 @EIR_RATE money =NULL,
	 @apply_fee_flag_ERF char(1)='F',
	 @apply_fee_flag_FRF char(1)='F',
	 @trans_source_R char(1)='R',
	 @customer_billing_territory_primary_flag char(1) ='T',
	 @customer_billing_territory_percent float =100,
	 @po_validation char(1),
	 @customer_count INT,
	 @date_effective datetime,
	 @validation_req_field varchar(100),
     @validation_req_field_value varchar(500),
	 @validation_resposne nvarchar(max),
	 @error1 int,
	 @ll_validation_ret int,
	 @ll_ret int,
	 @user_code varchar(10)='N/A',
	 @contact_id int,
	 @CUST_service_user_code VARCHAR(10),
	 @Customer_service_ID int,
	 @ll_count_rec int
	 
	
Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag'
		IF @ls_config_value is null or @ls_config_value=''
		Begin
				Select @ls_config_value='F'
		End
IF @ls_config_value='T'
BEGIN
Begin Transaction
	
		Select @source_system = 'sp_sfdc_customerbilling_Insert:: ' + 'Sales force'  
	
		Create table #temp_salesforce_validation_fields (validation_req_field varchar(100),validation_req_field_value varchar(500))  /*To determine the validation requried field*/
		Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
		                                                 ('d365customer_id',(@d365customer_id)),
														 ('salesforce_contract_number',(@Salesforce_Contract_Number)),
														 ('region_id',str(@region_id)),
														 ('employee_id',(@employee_id))
													


														
														
		SELECT
		@key_value =	 
						
						' Emanifest fee option;'+isnull(@emanifest_fee_option,'') + 
						' All facilities flag;'+isnull(@all_facilities_flag,'') + 
						' Break code1;'+isnull(@break_code_1,'') + 
						' Break code2;'+isnull(@break_code_2,'') + 
						' Break code3;'+isnull(@break_code_3,'') + 
						' d365customer_id;' + isnull(@d365customer_id,'') +
						' Insurance surcharge flag;'+isnull(@insurance_surcharge_flag,'') + 
						' Invoice flag;'+isnull(@invoice_flag,'') + 
						' Invoice package content cbilling;'+isnull(@invoice_package_content_Cbilling,'') +
						' Invoice package content;'+isnull(@invoice_package_content,'') + 
						' Mail to bill to address flag;'+isnull(@mail_to_bill_to_address_flag,'') + 
						' PO_required_flag ;'+isnull(@PO_required_flag ,'') + 
						' Region id;' + cast((convert(int,@region_id)) as varchar(20))+ 
						' Print wos with start date flag;'+isnull(@print_wos_with_start_date_flag,'') + 
						' Terms code;'+isnull(@terms_code,'') + 
						' Distribution method;'+isnull(@distribution_method,'') + 
						' Emanifest fee;' + cast((convert(money,@emanifest_fee)) as varchar(20))+ 						
						' Date added;' + cast((convert(datetime,@date_added)) as varchar(20))+	
						' Date modified;' + cast((convert(datetime,@date_modified)) as varchar(20)) +	
						' Salesforce contract number;' + isnull(@Salesforce_Contract_Number,'') + 
						' Invoice copy flag ;' + isnull(@Invoice_copy_flag,''	) +						
						' Emanifest flag ; ' + isnull(@emanifest_flag,'') +
						' Project name ; ' + isnull(@project_name,'') +
						' Record type ;' + isnull(@record_type,'') +
						' employee_id;' +isnull(@employee_id,'') +
						' cusbilxcontact_email  ; ' + isnull(@cusbilxcontact_email ,'') +
						' cusbilxcontact_name ; ' + isnull(@cusbilxcontact_name,'') +
						' ebilling_flag  ; ' + isnull(@ebilling_flag ,'') +
						' customer_billing_territory_code  ; ' + isnull(@customer_billing_territory_code ,'') +
						' invoice_comment_1  ; ' + isnull(@invoice_comment_1 ,'') +
						' invoice_comment_2 ; '  + isnull(@invoice_comment_2,'') +
						' invoice_comment_3  ; ' + isnull(@invoice_comment_3,'') +
						' invoice_comment_4  ; ' + isnull(@invoice_comment_4,'') +
						' invoice_comment_5  ; ' + isnull(@invoice_comment_5,'') +
						' customer_billing_territory_status ; ' + isnull(@customer_billing_territory_status ,'') +
						' customer_billing_territory_type ; ' + isnull(@customer_billing_territory_type ,'') +
						' businesssegment_uid_1 ;' + cast((convert(int,@businesssegment_uid_1 )) as varchar(20))+
						' businesssegment_uid_2 ;' + cast((convert(int,@businesssegment_uid_2)) as varchar(20))+
						' RSG_EIN ; ' + isnull(@RSG_EIN ,'') 

	 SELECT @response = 'Integration Successful'
	
	 
	 Declare sf_validation CURSOR for
			select validation_req_field,validation_req_field_value from #temp_salesforce_validation_fields
			Open sf_validation
				fetch next from sf_validation into @validation_req_field,@validation_req_field_value		
				While @@fetch_status=0
				Begin				 
				   EXEC @ll_validation_ret=dbo.sp_sfdc_input_parm_validation 'sp_sfdc_customerbilling_Insert',@validation_req_field,@validation_req_field_value,21,0,@validation_resposne output

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
					 Set @response = @response + @validation_resposne+ ';'
					 Set @flag = 'E'
				   End	
					fetch next from sf_validation into @validation_req_field,@validation_req_field_value   
			   End		
           Close sf_validation
		   DEALLOCATE sf_validation 
	
		
		 Drop table #temp_salesforce_validation_fields

		If @flag = 'E'
		Begin
		Rollback transaction
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

		select @ll_count_rec=count(*) from contact where email=@cusbilxcontact_email and name=@cusbilxcontact_name

		if @ll_count_rec = 0  
		begin
		rollback transaction
		SELECT @Response = 'Error: Integration failed due to the following reason; No contact id exists for the @cusbilxcontact_email: ' +@cusbilxcontact_email +' and cusbilxcontact_name: ' +@cusbilxcontact_name
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

		if @ll_count_rec > 1
		begin
		rollback transaction
		SELECT @Response = 'Error: Integration failed due to the following reason; more than one contact id exists for the @cusbilxcontact_email: ' +@cusbilxcontact_email +' and cusbilxcontact_name: ' +@cusbilxcontact_name
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

	
	IF @FLAG <>'E'	
	BEGIN

		   	 SELECT top 1 @date_effective=date_effective FROM eManifestUserFee 
				WHERE emanifest_submission_type_uid = 2 AND 
				      date_effective <= GETDATE()
				ORDER BY date_effective DESC

		EXECUTE @billing_project_id = sp_sequence_next 'CustomerBilling.Billing_Project_ID'	

		Select @project_name='SF Contract - ' + @project_name

		Select @CUST_service_user_code=user_code,
		@Customer_service_ID=type_id
		from UsersXEQContact
		where user_code in (select user_code from users where employee_id = @RSG_EIN)
		

			Insert into customerbilling
				(mail_to_bill_to_address_flag,
				print_wos_with_start_date_flag,
				customer_id,
				billing_project_id,
				region_id,
				release_required_flag,
				terms_code,
				distribution_method,
				all_facilities_flag,
				break_code_1,
				break_code_2,
				break_code_3,
				consolidate_containers_flag,
				ebilling_flag,
				eq_approved_offeror_desc,
				eq_approved_offeror_flag,
				eq_offeror_bp_override_flag,
				eq_offeror_effective_dt,
				insurance_surcharge_flag,
				internal_review_flag,
				intervention_desc,
				intervention_required_flag,
				invoice_flag,
				invoice_package_content,
				invoice_print_attachment_flag,
				link_required_flag,
				pickup_report_flag,
				PO_required_flag,
				print_wos_in_inv_attachment_flag,
				retail_flag,
				sort_code_1,
				sort_code_2,
				sort_code_3,
				status,
				submit_on_hold_flag,
				trip_stop_rate_default_flag,
				weight_ticket_required_flag,
				whca_exempt,
				added_by,
				date_added,
				modified_by,
				date_modified,
				record_type,
				project_name,
				salesforce_contract_number,
				PO_validation,
				invoice_comment_1,
				invoice_comment_2,
				invoice_comment_3,
				invoice_comment_4,
				invoice_comment_5,
				Customer_service_ID
				)
				select
				@mail_to_bill_to_address_flag,
				@print_wos_with_start_date_flag,
				@customer_id,
				@billing_project_id,
				@region_id,
				@release_required_flag,
				@terms_code,
				@distrubation_method_cbilling,
				@all_facilities_flag,
				@break_code_1,
				@break_code_2,
				@break_code_3,
				@consolidate_containers_flag,
				@ebilling_flag,
				@eq_approved_offeror_desc,
				@eq_approved_offeror_flag,
				@eq_offeror_bp_override_flag,
				@eq_offeror_effective_dt,
				@insurance_surcharge_flag,
				@internal_review_flag,
				@intervention_desc,
				@intervention_required_flag,
				@invoice_flag,
				@invoice_package_content_Cbilling,
				@invoice_print_attachment_flag,
				@link_required_flag,
				@pickup_report_flag,
				@PO_required_flag,
				@print_wos_in_inv_attachment_flag,
				@retail_flag,
				@sort_code_1,
				@sort_code_2,
				@sort_code_3,
				@status,
				@submit_on_hold_flag,
				@trip_stop_rate_default_flag,
				@weight_ticket_required_flag,
				@whca_exempt,
				@user_code,
				@date_added,
				@user_code,
				@date_modified,
				@record_type,
				@project_name,
				@salesforce_contract_number,
				case when @PO_required_flag='T' THEN 'E'
				WHEN @PO_required_flag='F' THEN 'W'
				ELSE NULL 
				END,
				@invoice_comment_1,
				@invoice_comment_2,
				@invoice_comment_3,
				@invoice_comment_4,
				@invoice_comment_5,
				@Customer_service_ID

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
				@emanifest_fee_option,
				@emanifest_fee,
				@emanifest_flag,
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

			insert into CustomerBillingEIRRate
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

			insert into CustomerBillingERFRate
			(
			customer_id,
			billing_project_id,
			date_effective,
			apply_fee_flag,
			added_by,
			date_added,
			modified_by,
			date_modified
			)
			select
			@customer_id,
			@billing_project_id,
			getdate(),
			@apply_fee_flag_ERF,
			@user_code,
			@date_added,
			@user_code,
			@date_modified


			if @@error <> 0
			Begin
				Rollback transaction
				SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting CustomerBillingERFRate table; '+ isnull(ERROR_MESSAGE(),' ')
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

			Insert into CustomerBillingFRFRate
			(
			customer_id,
			billing_project_id,
			date_effective,
			apply_fee_flag,
			added_by,
			date_added,
			modified_by,
			date_modified
			)
			select
			@customer_id,
			@billing_project_id,
			getdate(),
			@apply_fee_flag_FRF,
			@user_code,
			@date_added,
			@user_code,
			@date_modified


			if @@error <> 0
			begin
				rollback transaction
				SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting CustomerBillingFRFRate table; '+ isnull(ERROR_MESSAGE(),' ')
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

			Insert into customerbillingdocument
			(
			customer_id,
			billing_project_id,
			status,
			trans_source,
			type_id,
			validation,
			added_by,
			date_added,
			modified_by,
			date_modified,
			print_on_invoice_required_flag
			)
			select
			@customer_id,
			@billing_project_id,
			@status,
			@trans_source_R,
			1,
			@validation_error,
			@user_code,
			@date_added,
			@user_code,
			@date_modified,
			@print_on_invoice_required_flag_T

			if @@error <> 0
			Begin
				Rollback transaction
				SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting customerbillingdocument table; '+ isnull(ERROR_MESSAGE(),' ')
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
			end


			insert into customerbillingdocument
			(
			customer_id,
			billing_project_id,
			status,
			trans_source,
			type_id,
			validation,
			added_by,
			date_added,
			modified_by,
			date_modified,
			print_on_invoice_required_flag
			)
			select
			@customer_id,
			@billing_project_id,
			@status,
			@validation_warning,
			20,
			@validation_warning,
			@user_code,
			@date_added,
			@user_code,
			@date_modified,
			@print_on_invoice_required_flag_F
	
			if @@error <> 0
			Begin
				Rollback transaction
				SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting customerbillingdocument table; '+ isnull(ERROR_MESSAGE(),' ')
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


			insert into customerbillingdocument
			(
			customer_id,
			billing_project_id,
			status,
			trans_source,
			type_id,
			validation,
			added_by,
			date_added,
			modified_by,
			date_modified,
			print_on_invoice_required_flag
			)
			select
			@customer_id,
			@billing_project_id,
			@status,
			@validation_warning,
			28,
			@validation_warning,
			@user_code,
			@date_added,
			@user_code,
			@date_modified,
			@print_on_invoice_required_flag_F
			
			If @@error <> 0
			Begin
				 Rollback transaction
				 SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting customerbillingdocument table; '+ isnull(ERROR_MESSAGE(),' ')
   				 INSERT INTO PLT_AI_AUDIT..Source_Error_Log
				 (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   				 SELECT
   				 @key_value,
   				 @source_system,
    				'Insert',
	    			 @Response,
    				 GETDATE(),
   				 SUBSTRING(USER_NAME(), 1, 40)
				Return -1
			End
			
			SELECT @contact_id=contact_id from contact where email=@cusbilxcontact_email and name=@cusbilxcontact_name
			
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
			@Invoice_copy_flag,
			@distribution_method,
			@user_code,
			@date_added,
			@user_code,
			@date_modified,
			NULL,
			@invoice_package_content

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

		-- Inserting the values into CustomerAudit table.
	
		EXEC @ll_ret = dbo.sp_sfdc_customeraudit_insert
				@mail_to_bill_to_address_flag,@print_wos_with_start_date_flag,@customer_id,@billing_project_id,@region_id,@release_required_flag,@terms_code,@distrubation_method_cbilling,
				@all_facilities_flag,@break_code_1,@break_code_2,@break_code_3,@consolidate_containers_flag,@ebilling_flag,
				@eq_approved_offeror_desc,@eq_approved_offeror_flag,@eq_offeror_bp_override_flag,@eq_offeror_effective_dt,
				@insurance_surcharge_flag,@internal_review_flag,@intervention_desc,@intervention_required_flag,
				@invoice_flag,@invoice_package_content,@invoice_package_content_cbilling,@invoice_print_attachment_flag,@link_required_flag,
				@pickup_report_flag,@PO_required_flag,@print_wos_in_inv_attachment_flag,@retail_flag,@sort_code_1,
				@sort_code_2,@sort_code_3,@status,@submit_on_hold_flag,@trip_stop_rate_default_flag,@weight_ticket_required_flag,
				@whca_exempt,@user_code,@date_added,@date_modified,@record_type,@project_name,@salesforce_contract_number,
				@emanifest_fee_option,@emanifest_fee,@emanifest_flag,@date_effective,@use_corporate_rate_EIRRATE,  
				@apply_fee_flag,@apply_fee_flag_ERF,@apply_fee_flag_FRF,@trans_source_R,
				@validation_error,@print_on_invoice_required_flag_T,@Invoice_copy_flag,@distribution_method,
				@businesssegment_uid_1,@businesssegment_uid_2,@customer_billing_territory_type,
				@customer_billing_territory_code,@customer_billing_territory_primary_flag,
				@customer_billing_territory_percent,@customer_billing_territory_status,@po_validation,@invoice_comment_1,@invoice_comment_2,@invoice_comment_3,
				@invoice_comment_4,@invoice_comment_5,@contact_id
				
		END
			if @ll_ret = 0
			COMMIT TRANSACTION;
			IF @ll_ret = -1
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
	END
If @ls_config_value='F'
	BEGIN
		select @response = 'SFDC Data Integration Failed,since CRM Go live flag off. Hence Store procedure will not execute.'
		Return -1
	END
END

Go



GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_customerbilling_Insert] TO EQAI

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_customerbilling_Insert] TO svc_CORAppUser  