USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_workorderquoteheader_Insert]    Script Date: 6/12/2024 9:55:26 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_sfdc_workorderquoteheader_Insert] 
                    	@project_code varchar(15)= Null,  
						@curr_status_code char(1) = 'A',
						@customer_fax varchar(20)= Null,
						@project_name varchar(40)= Null,
						@customer_contact varchar(40)= Null,
						@customer_phone varchar(20)= Null,
						@total_price money,
						@total_cost money,
						@use_contact_id int,
						@company_id smallint,
						@profit_ctr_id int,
						@d365customer_id varchar(20)= Null,
						@start_date datetime= Null,												
						@FLAG char(1) = 'I',
						@JSON_DATA nvarchar(max),
						@source_system varchar(100)='Sales Force',
						@salesforce_site_csid varchar(18)=Null,
						@EPA_ID varchar(12)= Null,	
						@generator_id int= Null,						
						@generator_name varchar(75)= Null,	
						@generator_address_1 varchar(85)= Null,
						@generator_address_2 varchar(40)=Null,
						@generator_address_3 varchar(40)=Null,
						@generator_address_4 varchar(40)=Null,
						@generator_address_5 varchar(40)=Null,
						@generator_city varchar(40)= Null,	
						@generator_state varchar(2)= Null,	
						@generator_zip_code varchar(15)= Null,	
						@generator_country varchar(3)= Null,	
						@generator_phone varchar(10)= Null,	
						@generator_fax varchar(10)=Null,
						@gen_mail_name varchar(75)= Null,
						@gen_mail_addr1 varchar(85)= Null,	
						@gen_mail_addr2 varchar(40)=Null,
						@gen_mail_addr3 varchar(40)=Null,
						@gen_mail_addr4 varchar(40)=Null,
						@gen_mail_addr5 varchar(40)=Null,
						@gen_mail_city varchar(40)=Null,
						@gen_mail_state char(2)=Null,
						@gen_mail_zip_code varchar(15)=Null,	
						@gen_mail_country varchar(3)=Null,	
						@NAICS_code int,
						@confirm_author varchar(40)=Null,	
						@employee_id varchar(20)=Null,
						@response nvarchar(max) OUTPUT
						

/*  
Description: 

API call will be made from salesforce team to Insert the Salesforce record.

Revision History:

DevOps# 61551 - 3/14/2023  Nagaraj M   Created
DevOps# 64256 - 4/13/2023  Nagaraj M   Modified to add input JSON_DATA parameter.
Devops# 65532 - 5/18/2023  Nagaraj M    Added the Default flag values,Retrieving the customer and company id details,Added Input parameters also.
Devops# 70054 - 8/9/2023   Venu Modified for generator Integration and handled transaction object and CRM golive flag implementation
DevOps# 71686 - 8/22/2023  Nagaraj M Modified to insert generator audit record details
Devops# 73735 - 10/09/2023 Nagaraj M Included return value change for the execution sp_sfdc_generatoraudit_insert
Devops #74353 - 11/10/2023 Nagaraj M Added @as_generator_insert to check the new generator id.
Devops# 74469 - 11/14/2023 Venu Replaced the @salseforce_so_quote_id input parm to @project_code, salseforce_so_quote_id input is no longer required in this stored procedure, 
however we need to store it into table
Devops# 76452 - 01/03/2024 Venu Modified the Procedure - Implement the validation for all the required fields and modified the procedure name.
Devops# 76705 -01/09/2024 Venu Modified the procedire - implement the salesforce site csid field as parameter
Devops# 77454 --01/31/2024 Venu - Modified for the erorr handling messgae text change
Devops# 79234  --02/22/2024 Venu - Modified for adding addtional integarted fields and default values.
Devops# 79827 -- 03/05/2024 Venu - Modified - change the logic for Generator site csid logic implementation
Devops# 81419 -- 03/19/2024 Venu - Populate the user_code to added_by and modified_by fields
Devops# 83356 -- 04/15/2024 Nagaraj M Added @generator_county field value to insert into the generator,generatoraudit tables.
Devops# 87468  fix deployment script review comments by Venu
Devops# 83361 - 04/29/2024 Rob - Populate Salesforce staging tables instead of actual EQAI tables (for fully transactional integration)
Devops# 87927 -- 05/20/2024 Venu Modified the error handling.
Devops#89138  -- 06/01/2024 Venu modified for Update Case Sensitivity for CSID on Generator Lookup
Execution of Insert sample record
USE PLT_AI
GO
Declare @result varchar(max);
EXEC dbo.sp_sfdc_workorderquoteheader_Insert
@project_code='NAG_DEVOPS_83356',
@curr_status_code = 'A',
@customer_fax='1234567890',
@project_name='T&D Bilge Water USNS Watkins',
@customer_contact='Venu-Test',
@customer_phone='781-771-0354',
@total_price=52826.91,
@total_cost=35868.73,
@use_contact_id=1,
@company_id=21,
@profit_ctr_id=0,
@d365customer_id='C022410',
@start_date='20/APR/2024',
@JSON_DATA ='{
"Project_Coordinator__c": "John Jacobsen",
"CMR_Description__c": "T&D Bilge Water USNS Watkins",
"Salesforce_so_quote_id": "a0uDR000001rpYaYAI",
"Phone_No__c": "781-771-0354",
"Fax_No__c": "1234567890",
"Total_Cost__c": 35868.73,
"Site_Contact_2__c": "Nils Djusberg",
"Order_Total_Amount__c": 52826.91,
"Document_Status__c": "Open",
"company_id": 21,
"profit_ctr_id": 1
}',
@salesforce_site_csid='APR15_001',
@EPA_ID='CRMAPR15001',
@generator_id='', 
@FLAG='I',
@generator_name = 'TEST ZIPCODE COUNTY DEVOPS83356',
@generator_address_1 = '123 MAIN ST',
@generator_address_2= '123',
@generator_address_3='123',
@generator_address_4='123',
@generator_address_5='123',
@generator_city = 'ATLANTA',
@generator_state='GA',    
@generator_zip_code='30354',    
@generator_country='USA',
@generator_phone= '2485551212',    
@generator_FAX= '12345', 
@gen_mail_name = 'GENERATOR NAME',
@gen_mail_addr1 = '123 MAIN ST',
@gen_mail_addr2 = 'Test',
@gen_mail_addr3 = '123',
@gen_mail_addr4 = '123',
@gen_mail_addr5 = '123',
@gen_mail_city = 'ROCHESTER',
@gen_mail_state = 'MI',
@gen_mail_zip_code = '48307',
@gen_mail_country = 'USA',
@NAICS_code = 111110,
@confirm_author='NAG_DEVOPS83356',
@employee_id='864502',
@response =@result output
print @result
*/

AS
DECLARE 
     @salesforce_so_quote_id varchar(80),
	 @newquote_id int,
	 @key_value nvarchar(2000),
	 @Quote_revision int = 1,
	 @error_flag char(1) = 'N',
	 @Notes_subject char(1)='H',
	 @as_generator_insert char(1)='F',
	 @ll_count_rec int,
	 @company_name varchar(40),
	 @company_addr1 varchar(40),
	 @company_addr2 varchar(40),
	 @company_addr3 varchar(40),
	 @company_phone varchar(20),
	 @company_fax varchar(20),
	 @customer_id int,
	 @customer_name varchar(75),
	 @customer_addr1 varchar(40),
	 @customer_addr2 varchar(40),
	 @customer_addr3 varchar(40),
	 @customer_addr4 varchar(40),
	 @customer_addr5 varchar(40),  
	 @customer_count int,
	 @generator_contact varchar(100),
	 @Generator_result varchar(200),
	 @generator_county int, 
	 @ll_ret int,	 
	 @ls_config_value char(1)='F',
	 @validation_req_field varchar(100),
     @validation_req_field_value varchar(500),
	 @validation_response varchar(1000),
	 @ll_validation_ret int,
	 @Print_confirm_flag char(1) ='F',
	 @Print_gen_flag char(1)= 'F',						
	 @fax_flag char(1) ='F',
	 @fixed_price_flag char(1) ='F',
	 @labpack_quote_flag char(1) ='F',
	 @status char(1)= 'A',
	 @Job_Type char(1) ='B',
	 @ll_gen_cnt int,
	 @user_code varchar(10)='N/A'
	
set transaction isolation level read uncommitted

Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag'
	IF @ls_config_value is null or @ls_config_value=''
	Begin
	  Set @ls_config_value='F'
	End
	IF @ls_config_value='T'
	BEGIN
	Begin transaction
    Create table #temp_salesforce_validation_fields (validation_req_field varchar(100),validation_req_field_value varchar(500))  /*To determine the validation requried field*/
    Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
		                                            ('company_id',str(@company_id)),
													('profit_ctr_id',str(@profit_ctr_id)),
		                                            ('d365customer_id',@d365customer_id),
		                                            ('project_code',@project_code),
													('generator_id',str(@generator_id)),
													('salesforce_site_csid',@salesforce_site_csid),
													('employee_id',@employee_id)
													

	    Set @source_system = 'sp_sfdc_workorderquoteheader_insert:: ' + @source_system 

		Set @response = 'Integration Successful'

		Set @salesforce_so_quote_id=@project_code

		Set @FLAG = 'I'


		Set	@key_value = 'project_code;' +isnull(@project_code, '') +
		             ' curr_status_code;' + isnull(@curr_status_code, '') +
					 ' customer_fax;' + isnull(@customer_fax,'') +
					 ' project_name;' + isnull(@project_name, '') +
					 ' customer_phone;' + isnull(@customer_phone, '') +
					 ' customer_contact;' + isnull(@customer_contact, '') +
					 ' use_contact_id;' + isnull(STR(@use_contact_id),'') +
					 ' profit_ctr_id;' + isnull(STR(@profit_ctr_id),'') +
				   	 ' company_id;' + isnull(STR(@company_id), '') +
    				 ' total_cost;' + cast((convert(money,@total_cost)) as varchar(20)) +
					 ' total_price;' + cast((convert(money,@total_price)) as varchar(20)) +
					 ' d365customer id;' + isnull(@d365customer_id, '') + 
					 ' start_date;' + cast((convert(datetime,@start_date)) as varchar(20))+	
					 ' salesforce site csid;' + isnull(@salesforce_site_csid, '') +  
					 ' EPA_ID;' + isnull(@EPA_ID, '') + 
					 ' generator_id;' + isnull(STR(@generator_id), '') + 
					 ' status;' + isnull(@status, '') +
					 ' generator_name;' + isnull(@generator_name, '') + 
					 ' generator_address_1;' + isnull(@generator_address_1, '') + 
					 ' generator_address_2;' + isnull(@generator_address_2,'') + 
					 ' generator_address_3;' +  isnull(@generator_address_3,'') + 
					 ' generator_address_4;' + isnull(@generator_address_4,'') + 
					 ' generator_address_5;' + isnull(@generator_address_5,'') + 
					 ' generator_phone;' + isnull(@generator_phone,'') + 
					 ' generator_city;' + isnull(@generator_city,'') + 
					 ' generator_state;' + isnull(@generator_state,'') + 
					 ' generator_zip_code;' + isnull(@generator_zip_code,'') + 
					 ' generator_country;' + isnull(@generator_country,'') + 
					 ' generator_fax;' + isnull(@generator_fax,'') +  
					 ' gen_mail_name;' + isnull(@gen_mail_name, '') + 
					 ' gen_mail_addr1;' + isnull(@gen_mail_addr1, '') + 
					 ' gen_mail_addr2;' + isnull(@gen_mail_addr2,'') + 
					 ' gen_mail_addr3;' +  isnull(@gen_mail_addr3,'') + 
					 ' gen_mail_addr4;' + isnull(@gen_mail_addr4,'') + 
					 ' gen_mail_addr5;' + isnull(@gen_mail_addr5,'') + 
					 ' gen_mail_city;' + isnull(@gen_mail_city,'') + 
					 ' gen_mail_state;' + isnull(@gen_mail_state,'') + 
					 ' gen_mail_zip_code;' + isnull(@gen_mail_zip_code,'') + 
					 ' gen_mail_country;' + isnull(@gen_mail_country,'') + 					 
					 ' NAICS_code;' + isnull(STR(@NAICS_code), '') + 		 					 					 
					 ' confirm_author;' + isnull(@confirm_author, '') +
					 ' employee_id;' +isnull(@employee_id,'')		
						
	    	    
		If @JSON_DATA is null Or @JSON_DATA=''
		Begin
			Set @response = 'Error: Integration failed due to the following reason;Recevied JSON data string empty/null'
			Set @flag = 'E' 		
		End
		 
	    Declare sf_validation CURSOR for
			select validation_req_field,validation_req_field_value from #temp_salesforce_validation_fields
			Open sf_validation
				fetch next from sf_validation into @validation_req_field,@validation_req_field_value		
				While @@fetch_status=0
				Begin				   
				   EXEC @ll_validation_ret=dbo.sp_sfdc_input_parm_validation 'sp_sfdc_workorderquoteheader_insert',@validation_req_field,@validation_req_field_value,@company_id,@profit_ctr_id,@validation_response output

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
						 Set @response = @response + isnull(@validation_response,'') +';'
						 Set @flag = 'E'
                        				 
					 
				   End	
				fetch next from sf_validation into @validation_req_field,@validation_req_field_value   
			   End		
           Close sf_validation
		DEALLOCATE sf_validation 
		Drop table #temp_salesforce_validation_fields


		If (@generator_id IS NULL OR @generator_id = '') and (@salesforce_site_csid is null or @salesforce_site_csid ='')
		 Begin	
			If @Response = 'Integration Successful'
			Begin
				Set @Response ='Error: Integration failed due to the following reason;Site csid can not be empty/null,since sales force sending new site address to create the new generator in EQAI;'
				Set @flag='E' 
			End 
			Else
			If @Response <> 'Integration Successful'
			Begin
				Set @Response = @Response +'Site csid can not be empty/null,since sales force sending new site address to create the new generator in EQAI;'
				Set @flag='E'   
			End 	
		 End
		 		 
		If @flag = 'E'
		Begin
			INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
											SELECT
											@key_value,
											@source_system,
											'Insert',
											@response,
											GETDATE(),
											@user_code
            commit transaction 
			Return -1
		End

		

		
--Begin transaction

		IF @flag <> 'E'
		Begin
			select @company_name=company_name,@company_addr1=address_1,
			       @company_addr2=address_2,@company_addr3=EPA_ID,
				   @company_phone=phone,@company_fax=fax from company
														 where company_id=@company_id

			select @customer_id=customer_id,@customer_name=cust_name,@customer_addr1=cust_addr1,@customer_addr2=cust_addr2,
			@customer_addr3=cust_addr3,@customer_addr4=cust_addr4,
			@customer_addr5=trim(cust_city)+' ' +trim(cust_state)+' ' +trim(cust_zip_code) from Customer
																						   where ax_customer_id=@d365customer_id AND CUST_STATUS='A'
		  	

			IF (@generator_id IS NULL OR @generator_id = '') and (@salesforce_site_csid IS NOT NULL and @salesforce_site_csid <> '')
				Begin
					select @ll_gen_cnt = count(*) from generator Where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS=@salesforce_site_csid
					If @ll_gen_cnt=1 
						Begin
						select @generator_id=generator_id,@EPA_ID=EPA_ID,@generator_name=generator_name,@generator_address_1=generator_address_1,
							   @generator_address_2=generator_address_2,@generator_address_3=generator_address_3,@generator_address_4=generator_address_4,@generator_address_5=generator_address_5,
							   @generator_phone=generator_phone,@generator_fax=generator_fax
							   from generator Where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS=@salesforce_site_csid
						End
				End 

			IF  (@generator_id IS NOT NULL and @generator_id <> '' and @generator_id = 0) and @flag <> 'E'
				Begin
				
					select @generator_contact=name from Contact where contact_id in (select min(contact_id) from ContactXref 
																					where generator_id = @generator_id and primary_contact = 'T' and type = 'G' )
				End

			IF (@generator_id IS NULL OR @generator_id = '') and (@salesforce_site_csid IS NOT NULL and @salesforce_site_csid <> '') and @ll_gen_cnt=0
				Begin
					Set @as_generator_insert ='T'
				End
	
			IF @as_generator_insert ='T' and @flag <> 'E' 
				Begin			   
					EXECUTE @generator_id = dbo.sp_sequence_next 'Generator.generator_id'				
				End 
		  End		
        
		Begin		   
			IF NOT EXISTS (SELECT * FROM WorkOrderQuoteHeader
					   WHERE company_id = @company_id
					   AND profit_ctr_id = @profit_ctr_id
					   AND project_code = @project_code)
					   AND @FLAG = 'I'            

			Begin
					EXECUTE @newquote_id = sp_sequence_next 'QuoteHeader.quote_id'				 
		  
					INSERT INTO [dbo].[SFSworkorderquoteheader] 
						  (Quote_id,
						  Salesforce_so_quote_id,
						  curr_status_code,
						  customer_fax,
						  project_name,
						  total_price,
						  customer_phone,
						  use_contact_id,
						  profit_ctr_id,
						  customer_contact,
						  company_id,
						  total_cost,
						  added_by,
						  date_added,
						  modified_by,
						  date_modified,
						  AX_Dimension_5_Part_1,
						  AX_Dimension_5_Part_2,
						  quote_revision,
						  quote_type,
						  customer_id,
						  project_code,
						  start_date,
						  job_type,
						  Print_confirm_flag,
						  Print_gen_flag,
						  fax_flag,
						  fixed_price_flag,
						  labpack_quote_flag,
						  company_name,
						  company_addr1,
						  company_addr2,
						  company_addr3,
						  company_phone,
						  company_fax,
						  customer_name,
						  customer_addr1,
						  customer_addr2,
						  customer_addr3,
						  customer_addr4,
						  customer_addr5,
						  generator_id,
						  generator_EPA_ID,
						  generator_name,
						  generator_addr1,
						  generator_addr2,
						  generator_addr3,
						  generator_addr4,
						  generator_addr5,
						  generator_phone,
						  generator_fax,
						  generator_contact,
						  confirm_author,
						  confirm_update_date)
						  SELECT
						  @newquote_id,
						  @Salesforce_so_quote_id,
						  @curr_status_code,
						  @customer_fax,
						  @project_name,
						  @total_price,
						  @customer_phone,
						  @use_contact_id,
						  @profit_ctr_id,
						  @customer_contact,
						  @company_id,
						  @total_cost,
						  @user_code,
						  GETDATE(),
						  @user_code,
						  GETDATE(),
						  '',
						  '',
						  1,
						  'P',
						  @customer_id,
						  @project_code,
						  @start_date,
						  @Job_Type,
						  @Print_confirm_flag,
						  @Print_gen_flag,
						  @fax_flag,
						  @fixed_price_flag,
						  @labpack_quote_flag,
						  @company_name,
						  @company_addr1,
						  @company_addr2,
						  @company_addr3,
						  @company_phone,
						  @company_fax,
						  @customer_name,
						  @customer_addr1,
						  @customer_addr2,
						  @customer_addr3,
						  @customer_addr4,
						  @customer_addr5,
						  @generator_id,
						  @EPA_ID,
						  @generator_name,
						  @generator_address_1,
						  @generator_address_2,
						  @generator_address_3,
						  @generator_address_4,
						  @generator_address_5,
						  @generator_phone,
						  @generator_fax,
						  @generator_contact,
						  @confirm_author,
						  GETDATE()

						                      
					    if @@error <> 0 							
						begin
						rollback transaction
						Set @error_flag = 'Y'
						Set @flag = 'E'	
						SELECT @Response = 'Error: Integration failed due to the following reason; could not insert into SFSworkorderquoteheader table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
   								INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   																	SELECT
   																	@key_value,
   																	@source_system,
    																'Insert',																	
    																@Response,
    																GETDATE(),
   																	@user_code  
                            
							return -1
						end 
			End
		 Else 
			Begin
				Set @flag = 'E'	
				Select @response = 'Error: Integration failed due to the following reason; Project code already exists in WorkOrderQuoteHeader table'	
				INSERT INTO PLT_AI_AUDIT..Source_Error_Log (input_params,source_system_details,action,Error_description,log_date,Added_by)
									  SELECT
									   @key_value,
									   @source_system,
									   'Insert',
									   @response,
									   GETDATE(),
									   @user_code								
									   commit transaction 
				 Return -1
			End	
		End
 

	select  @generator_county=county_code from zipcodes where  zipcode=@generator_zip_code
		     
	IF @response = 'Integration Successful' AND @error_flag = 'N' AND @FLAG <> 'E' AND (@generator_id is not null and @generator_id <> '') and @as_generator_insert='T' and (@salesforce_site_csid IS NOT NULL and @salesforce_site_csid <> '')
		Begin
			EXEC @ll_ret= dbo.sp_sfdc_generator_insert @salesforce_site_csid,@EPA_ID,@generator_id,@status,@generator_name ,@generator_address_1,@generator_address_2,@generator_address_3,
						 @generator_address_4,@generator_address_5,@generator_city,@generator_state,@generator_zip_code,@generator_county,@generator_country,@generator_phone,@generator_fax,
						 @gen_mail_name,@gen_mail_addr1,@gen_mail_addr2,@gen_mail_addr3,@gen_mail_addr4,@gen_mail_addr5,@gen_mail_city,@gen_mail_state,@gen_mail_zip_code,
						 @gen_mail_country,@NAICS_code,@user_code,@Generator_result output    
			
			
            If @ll_ret = 0
			Begin
				EXEC @ll_ret=dbo.sp_sfdc_generatoraudit_insert @EPA_ID,@generator_id,@status,@generator_name,@generator_address_1,@generator_address_2,@generator_address_3,
								 @generator_address_4,@generator_address_5,@generator_city,@generator_state,@generator_zip_code,@generator_county,@generator_country,@generator_phone,@generator_fax,
								 @gen_mail_name,@gen_mail_addr1,@gen_mail_addr2,@gen_mail_addr3,@gen_mail_addr4,@gen_mail_addr5,@gen_mail_city,@gen_mail_state,@gen_mail_zip_code,
								 @gen_mail_country,@NAICS_code,@user_code
			End
		
	        
			If @ll_ret < 0 
			Begin
			    Rollback Transaction
				Set @response = 'Error: Integration failed due to the following reason; New Generator creation failed due to' + isnull(@Generator_result,'For more details please check Source_Error_Log table in EQAI;') 			
				Set @error_flag = 'Y'
				Set @FLAG ='E'				
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
        End

   
	IF @response = 'Integration Successful' AND @error_flag = 'N' AND @FLAG <> 'E' AND upper(@JSON_DATA) <> 'LIST' AND @JSON_DATA is not null
		Begin
			EXEC @ll_ret = sp_sfdc_quote_json_note_insert @newquote_id,
												   @company_id,
												   @profit_ctr_id,
												   @JSON_DATA,
												   @Notes_subject,
												   @source_system,
												   @user_code           
						
					If @ll_ret < 0 
					Begin
						Rollback Transaction
						Set @response = 'Error: Integration failed due to the following reason; Note Insert failed for workorderquoteheader. For more details please check Source_Error_Log table in EQAI for NOTE insert action.'			
						Set @error_flag = 'Y'
						Set @FLAG ='E'				
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
		 End

--------------------
--COMMIT TRANSACTION
--------------------
commit transaction
	
End

  If @ls_config_value='F'
	Begin
	   Set @response = 'SFDC Data Integration Failed,since CRM Go live flag off. Hence Store procedure will not execute.'
	   Return -1
	End
Return 0


GO


GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorderquoteheader_Insert] TO EQAI  

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorderquoteheader_Insert] TO svc_CORAppUser

GO