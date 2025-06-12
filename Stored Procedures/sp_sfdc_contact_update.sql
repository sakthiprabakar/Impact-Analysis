USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_contact_update]    Script Date: 10/14/2024 3:16:48 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_sfdc_contact_update] 
                    	@salesforce_contact_csid varchar(18)=Null,
						@contact_company varchar(75) =Null,
						@d365customer_id varchar(20)=Null,
						@contact_type	varchar(100)=Null,					
						@first_name varchar(20)=Null,	
						@last_name varchar(20)=Null,	
					    @name varchar(40)=Null,	
						@title  varchar(35)=Null,	
						@contact_addr1 varchar(40)=Null,	
						@contact_city varchar(40)=Null,	
						@contact_state varchar(2)=Null,	
						@contact_zip_code varchar(15)=Null,	
						@contact_country varchar(40)=Null,	
						@phone  nvarchar(20)=Null,
						@mobile varchar(10)=Null,
						@email varchar(60)=Null,
						@email_flag char(1) = Null,
						@web_access_flag char(1) = Null,
						@contact_customer_status char(1) = Null,					
						@JSON_DATA nvarchar(max),							
						@employee_id varchar(20)=Null,
						@fax varchar(255)=Null, 
						@salutation varchar(10)=Null, 
						@middle_name varchar(20)=Null, 
						@suffix varchar(25)=Null, 
						@response varchar(2000) OUTPUT
						

/*  
Description: 

API call will be made from salesforce team to Insert the Salesforce record.

Revision History:

US# 116038 - 6/17/2024  Venu R   Created
US#116477 - 07/05//2024 Nagaraj M   Inserting into CustomerAudit record.
US#119668  -07/18/2024 Venu R inactivate contact customer details (During this scenario no need to send auto mail)
US#126253  - 09/16/2024 Venu R email functionlity enabled for inactive account
US#125733  - 09/20/2024 Venu R added addtional integaration fields fax,salutation,middle_name and suffix

USE PLT_AI
GO
Declare @response nvarchar(max)
EXECUTE dbo.sp_sfdc_contact_update
@salesforce_contact_csid='Test-Venu',
@contact_company='qewqe',
@d365customer_id='C305702',
@contact_type='Quote',--'Quote;billing;purchase', --'Quote',
@first_name='Venu',
@last_name='R',
@name='Venu R',
@title='sddfwe',
@contact_addr1='ewrf',
@contact_city='US',
@contact_state='GJ',
@contact_zip_code='213333',
@contact_country='INDIA',
@phone='9884947801',
@mobile='9884251514',
@email ='test@GMAIL.COM',
@email_flag ='T',
@web_access_flag ='F',
@contact_customer_status='A',
@employee_id='VENU',
@JSON_DATA='111',
@response=@response output
print @response
*/

AS
DECLARE 
     @contact_id int = -1,
	 @customer_id int,	 
	 @salesforce_contact_csid_old varchar(18)=Null,
	 @contact_company_old varchar(75) =Null,
	 @d365customer_id_old varchar(20)=Null,
	 @contact_type_old	varchar(100)=Null,					
	 @first_name_old varchar(20)=Null,	
	 @last_name_old varchar(20)=Null,	
	 @name_old varchar(40)=Null,	
	 @title_old  varchar(35)=Null,	
	 @contact_addr1_old varchar(40)=Null,	
	 @contact_city_old varchar(40)=Null,	
	 @contact_state_old varchar(2)=Null,	
	 @contact_zip_code_old varchar(15)=Null,	
	 @contact_country_old varchar(40)=Null,	
	 @phone_old  nvarchar(20)=Null,
	 @mobile_old varchar(10)=Null,
	 @email_old varchar(60)=Null,
	 @email_flag_old char(1) = Null,
	 @web_access_flag_old char(1) = Null,	
	 @source_system varchar(100)='Sales Force',     
	 @key_value nvarchar(2000),	 
	 @error_flag char(1) = 'N',	 
	 @ll_ret int,	 	 
	 @user_code varchar(10)='N/A',
	 @ls_config_value char(1)='F',
	 @FLAG  char(1) = 'I',
	 @ll_validation_ret int,
	 @validation_req_field varchar(100),
     @validation_req_field_value varchar(500),
	 @validation_response varchar(1000),
     @ll_cnt int,	 
	 @generator_id_cnt int,
	 @contact_rec_cnt int,
	 @ll_ret_email int,
	 @contact_type_ret varchar(20),
	 @ll_active_contact_cnt int,
	 @ll_doc_len int,
	 @ll_doc_index int,
	 @salesforce_contact_role_cnt int,
     @ll_cont_role_cnt int,
	 @contact_role_output varchar(20),	 
	 @eqai_contact_role_cnt int,
	 @contact_type_org varchar(100),
	 @ll_billing_role_cnt int,
	 @email_notification_req char(1)='F',
	 @ll_jobbilling_project_linked int,
	 @ls_previous_role varchar(100),
	 @ls_linked_billing_project varchar(200),
	 @contact_old_value varchar(100),
	 @contact_new_value varchar(100),
	 @column_name varchar(100),
	 @audit_reference varchar(100) =null,
	 @contact_audit_date_modified datetime,
	 @contact_type_audit varchar(20),
	 @contact_customer_status_old char(1),
	 @fax_old varchar(255),
	 @salutation_old varchar(10),
	 @middle_name_old varchar(20),
	 @suffix_old varchar(25)

set transaction isolation level read uncommitted

Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag_phase2'
	IF @ls_config_value is null or @ls_config_value=''
	Begin
	  Set @ls_config_value='F'
	End
	IF @ls_config_value='T'
	Begin
	
    Create table #temp_salesforce_validation_fields (validation_req_field varchar(100),validation_req_field_value varchar(500))  /*To determine the validation requried field*/
    Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 	
													('d365customer_id',@d365customer_id), 
	                                                ('salesforce_contact_csid',@salesforce_contact_csid), 		                                                                                    
													('employee_id',@employee_id)
													

	    Set @source_system = 'sp_sfdc_contact_update:: ' + @source_system 

		Set @response = 'Integration Successful'
		
		Set @FLAG = 'I'

		Set @contact_type_org=@contact_type

		Set	@key_value = 'salesforce_contact_csid;' +isnull(@salesforce_contact_csid, '') +		          
					 ' d365customer id;' + isnull(@d365customer_id, '') + 					
					 ' contact_type;' + isnull(@contact_type, '') +  
					 ' first_name;' + isnull(@first_name, '') + 					
					 ' last_name;' + isnull(@last_name, '') +
					 --' name;' + isnull(@name, '') + 
					 ' title;' + isnull(@title, '') + 
					 ' contact_addr1;' + isnull(@contact_addr1,'') + 
					 ' contact_city;' +  isnull(@contact_city,'') + 
					 ' contact_state;' + isnull(@contact_state,'') + 
					 ' contact_zip_code;' + isnull(@contact_zip_code,'') + 
					 ' contact_country;' + isnull(@contact_country,'') + 
					 ' phone;' + isnull(@phone,'') + 
					 ' mobile;' + isnull(@mobile,'') + 
					 ' email;' + isnull(@email,'') + 
					 ' email_flag;' + isnull(@email_flag,'') + 
					 ' web_access_flag;' + isnull(@web_access_flag,'') +  
					 ' @contact_customer_status;' + isnull(@contact_customer_status, '') + 							
					 ' employee_id;' +isnull(@employee_id,'') +
					 ' Fax;' +isnull(@fax,'') +
					 ' Salutation;' +isnull(@salutation,'') +
					 ' Middle_name;' +isnull(@middle_name,'') +
					 ' Suffix;' +isnull(@suffix,'') 
						
						
	    	    
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
				   EXEC @ll_validation_ret=dbo.sp_sfdc_input_parm_validation 'sp_sfdc_contact_update',@validation_req_field,@validation_req_field_value,0,0,@validation_response output

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
				    
					If @validation_req_field='d365customer_id' and @ll_validation_ret <> -1
					Begin
					 select @customer_id=customer_id from Customer where ax_customer_id=@d365customer_id and cust_status='A'					
					End  								   
				   
					If @validation_req_field='salesforce_contact_csid' and @ll_validation_ret <> -1 and @customer_id is not null and @customer_id <> ''
					Begin
						Select @contact_id = contact_id from contactxref where salesforce_contact_csid=@salesforce_contact_csid and customer_id=@customer_id
					  
						If Coalesce(@contact_id,-1) =-1
						Begin
							Set @response ='Error: Integration failed due to the following reason; The contact ID: ' +str(@contact_id) +  'not exists in contactxref table for the customer: ' + str(@customer_id) 
							Set @flag = 'E'	
						End										  					   
					End				   
				   
				fetch next from sf_validation into @validation_req_field,@validation_req_field_value   
			   End		
           Close sf_validation
		DEALLOCATE sf_validation 
		Drop table #temp_salesforce_validation_fields
		
		If @contact_id=-1
		Begin
		 If @response = 'Integration Successful'
		 Begin
			 Set @response ='Error: Integration failed due to the following reason; customer id: ' + str(@customer_id) + 'and salesforce contact csid: ' + @salesforce_contact_csid + 'not linked in contactxref table for none of the contact.'
			 Set @flag = 'E'		
         End
		 If @response <> 'Integration Successful'
		 Begin
			 Set @response =@response + 'customer id: ' + Coalesce(str(@customer_id),'N/A') + 'and salesforce contact csid: ' + Coalesce(@salesforce_contact_csid,'N/A') + 'not linked in contactxref table for none of the contact.'
			 Set @flag = 'E'		
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
			Return -1
		End
						
		If  @FLAG <> 'E' 		
		Begin   

		   Select @ll_active_contact_cnt = count(*) from contact where contact_id=@contact_id and contact_status='A'
		
		   If @ll_active_contact_cnt = 0 
		   Begin		 
			   Set @response ='Error: Integration failed due to the following reason; The contact ID: ' +str(@contact_id) + ' not exists in contact table or not an active status.Hence update is not an vaild'
			   Set @flag = 'E'		
			   INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
												SELECT
												@key_value,
												@source_system,
												'Insert',
												@response,
												GETDATE(),
												@user_code				
				Return -1		   
			 End
			
			 Select @generator_id_cnt = count(*) from contactxref where contact_id=@contact_id and customer_id=@customer_id and generator_id is not null and generator_id <> '' and status='A' and type='G'
		   
			
			IF @generator_id_cnt > 0 
			Begin				
				Set @response ='Error: Integration failed due to the following reason; The contact ID: ' +str(@contact_id) + ' already linked with the generator so chanegs wont integarate.'
				Set @flag = 'E'	
				INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
												SELECT
												@key_value,
												@source_system,
												'Insert',
												@response,
												GETDATE(),
												@user_code
			 
				Return -1		 
			End		 		    
			
			/*inactivate contact customer details - Start*/
			If @contact_customer_status='I' and @flag <> 'E'
			Begin
			
		    Select @contact_customer_status_old = Status from contactxref where contact_id= @contact_id and customer_id=@customer_id

			Update contactxref set status='I',date_modified=getdate(),modified_by=@user_code 
			                   where contact_id=@contact_id and customer_id=@customer_id and salesforce_contact_csid=@salesforce_contact_csid
            
			--During Contactxref inactiveate mail need to trigger -- Start
			Select @ll_billing_role_cnt=count(*) from ContactCustomerRole
												 Where contact_id=@contact_id and 
													   customer_id=@customer_id and 													   
													   upper(contact_customer_role)='BILLING' and Status='A'
            

			select @ll_jobbilling_project_linked= count(*) from CustomerBillingXContact 
												 INNER JOIN customerbilling ON customerbilling.customer_id=CustomerBillingXContact.customer_id
																			AND customerbilling.billing_project_id=CustomerBillingXContact.billing_project_id   
																			AND customerbilling.status='A'
												 INNER Join  ContactCustomerRole ON ContactCustomerRole.customer_id=CustomerBillingXContact.customer_id			 
																			AND ContactCustomerRole.contact_id=CustomerBillingXContact.contact_id			 
																			AND ContactCustomerRole.status='A' and upper(contact_customer_role)='BILLING'
												INNER JOIN contact ON contact.contact_id=CustomerBillingXContact.contact_id
                                                Where  CustomerBillingXContact.contact_id=@contact_id and 
													   CustomerBillingXContact.customer_id=@customer_id 

            
			If 	@ll_billing_role_cnt > 0 and @ll_jobbilling_project_linked > 0 
			Begin			  
			 Set @email_notification_req='T'

			 SELECT Distinct @ls_previous_role= STUFF((SELECT '; ' + US.contact_customer_role
						  FROM ContactCustomerRole US
						  WHERE US.customer_id = @customer_id AND
								US.contact_id = @contact_id AND
						        US.customer_id = SS.customer_id AND
								US.contact_id = SS.contact_id
						  FOR XML PATH('')), 1, 1, '') 
				FROM ContactCustomerRole SS
				Where SS.customer_id=@customer_id AND
				      SS.contact_id=@contact_id 			
					  
			
			
              SELECT Distinct @ls_linked_billing_project= STUFF((SELECT '; ' + str(US.billing_project_id)
						  FROM customerbilling US
						  WHERE US.billing_project_id in (select CustomerBillingXContact.billing_project_id from CustomerBillingXContact 
												 INNER JOIN customerbilling ON customerbilling.customer_id=CustomerBillingXContact.customer_id
																			AND customerbilling.billing_project_id=CustomerBillingXContact.billing_project_id  
																			AND customerbilling.status='A'
												 INNER Join  ContactCustomerRole ON ContactCustomerRole.customer_id=CustomerBillingXContact.customer_id			 
																			AND ContactCustomerRole.contact_id=CustomerBillingXContact.contact_id			 
																			AND ContactCustomerRole.status='A' and upper(contact_customer_role)='BILLING'
												INNER JOIN contact ON contact.contact_id=CustomerBillingXContact.contact_id
                                                Where  CustomerBillingXContact.contact_id=@contact_id and 
													   CustomerBillingXContact.customer_id=@customer_id )
						  FOR XML PATH('')), 1, 1, '') 
				FROM customerbilling SS
				/*Where SS.customer_id=US.customer_id AND
				      SS.billing_project_id=US.billing_project_id    */    			  

			End
			--During Contactxref inactiveate mail need to trigger -- End

					   			 
			Update ContactCustomerRole set status='I',date_modified=getdate(),modified_by=@user_code 
			                   where contact_id=@contact_id and customer_id=@customer_id 
             
			 
			 INSERT INTO [dbo].ContactAudit(contact_id,table_name,column_name,before_value,after_value,audit_reference,modified_from,
							  modified_by,
							  date_modified
							  )
					SELECT
							  @contact_id,'Account_detail','contactxref_status',@contact_customer_status_old,
							  @contact_customer_status,'contact_id: ' + TRIM(STR(@contact_id)),--@audit_reference,
							  'Salesforce',
							  @user_code,
							  getdate()
             
			
				If @email_notification_req='T'
				Begin  			  
					exec @ll_ret_email=dbo.sp_sfdc_contact_role_upd_email_notification @salesforce_contact_csid, @customer_id, @contact_id, @contact_type_org, @first_name, @last_name, @email, @contact_customer_status,@user_code,@ll_billing_role_cnt,@ls_previous_role,@ls_linked_billing_project
				End

            Set @response ='Integration Successful. Contact customer and respective roles are inactivated for the customer id: ' + Coalesce(str(@customer_id),'N/A')+ ',contact id: ' + Coalesce(str(@contact_id),'N/A') + 'and salesforce contact csid: ' + Coalesce(@salesforce_contact_csid,'N/A') 
			Set @flag = 'E'	 
			Return 0            
			End

			

			/*inactivate contact customer details - End*/



			/*To handle multiple contact role --Start*/
			Create table #temp_salesforce_contact_role (salesforce_contact_role varchar(20))	
			Set @ll_doc_len=len(@contact_type)
			If @ll_doc_len > 0 
			Begin
				WHILE @ll_doc_len > 0
				BEGIN
		  			Set @ll_doc_index=CharIndex(';',@contact_type)
					If  @ll_doc_index > 0 
						Begin
							Set @contact_type_ret=Substring(@contact_type,1,@ll_doc_index-1)
			            
							Insert into #temp_salesforce_contact_role (salesforce_contact_role ) Values
																				 ( @contact_type_ret)                        
														
							Set @contact_type=Substring(@contact_type,@ll_doc_index+1,@ll_doc_len)
						End
				   Else
				   If len(@contact_type) > 0
				   Begin
					   Set @contact_type_ret=Substring(@contact_type,1,len(@contact_type))
					   Set @ll_doc_len = -1				   
					   Insert into #temp_salesforce_contact_role (salesforce_contact_role ) Values
																					 ( @contact_type_ret)
					End			   
				  End
		  	  End
			  /*To handle multiple contact role --End*/
		  		   		   		  			 	 		  		   		   		  			 	 	   
          Select @salesforce_contact_role_cnt = count(*) from #temp_salesforce_contact_role

		  Begin Transaction	

		  SELECT 
					@contact_company_old=contact_company,
					@contact_type_old=contact_type,
					@first_name_old=first_name,
					@last_name_old=last_name,
					@name_old=name,
					@title_old=title,
					@contact_addr1_old=contact_addr1,
					@contact_city_old=contact_city,
					@contact_state_old=contact_state,
					@contact_zip_code_old=contact_zip_code,
					@contact_country_old=contact_country,
					@phone_old=phone,
					@mobile_old=mobile,
					@email_old=email,
					@email_flag_old=email_flag,
					@web_access_flag_old=web_access_flag,
					@fax_old =fax, 
					@salutation_old=salutation, 
					@middle_name_old=@middle_name,
					@suffix_old=@suffix 
					from contact
					where contact_id=@contact_id
  
   	
		          Select @contact_customer_status_old = Status from contactxref where contact_id= @contact_id and customer_id=@customer_id
					
					
					
					
		  If @salesforce_contact_role_cnt = 1 OR  @salesforce_contact_role_cnt = 0
		  Begin
			Select @contact_rec_cnt = count(*) from contact where contact_id=@contact_id and																																		
																	contact_company = @contact_company and
																	contact_type=@contact_type and
																	first_name=@first_name and
																	last_name =@last_name and
																	--name=@name and
																	title=@title and
																	contact_addr1=@contact_addr1 and
																	contact_city=@contact_city and
																	contact_state=@contact_state and
																	contact_zip_code=@contact_zip_code and
																	contact_country = @contact_country and
																	phone=@phone and 
																	mobile=@mobile and
																	email=@email and
																	email_flag=@email_flag and
																	web_access_flag=@web_access_flag and
																	fax =@fax and 
																	salutation=@salutation and
																	middle_name=@middle_name and ---Venu
																	suffix=@suffix 

            If @contact_rec_cnt=0
		    Begin
			Update contact set contact_company = @contact_company,
									   contact_type=Case When Coalesce(@contact_type,'N/A') <> 'N/A' Then @contact_type End,
									   first_name=@first_name,
									   last_name =@last_name,								   
									   name=isnull(@first_name,' ') +' '+ isnull(@last_name,' '),
									   title=@title,
									   contact_addr1=@contact_addr1,
									   contact_city=@contact_city,
									   contact_state=@contact_state,
									   contact_zip_code=@contact_zip_code,
									   contact_country = @contact_country,
									   phone=@phone,
									   mobile=@mobile,
									   email=@email,
									   email_flag=@email_flag,
									   web_access_flag=@web_access_flag,
									   fax =@fax, 
									   salutation=@salutation,
									   middle_name=@middle_name,
									   suffix=@suffix, 
									   date_modified=getdate(),
									   modified_by=@user_code
								Where contact_id=@contact_id
									  

			 if @@error <> 0 or @@ROWCOUNT=0
			 Begin
				Rollback Transaction
				Set @Response = 'Error: Integration failed due to the following reason; Error updating contact table;'+ isnull(ERROR_MESSAGE(),' ')
				Set @flag = 'E'		
   				INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   							SELECT
							@key_value,
   							@source_system,
    						'Update',
    						@Response,
    						GETDATE(),
   							@user_code			
							return -1
			 End
			 
			 Update ContactXRef set status=@contact_customer_status where contact_id=@contact_id and customer_id=@customer_id

			 Set @contact_type_audit=@contact_type
		   End
		End
		If @salesforce_contact_role_cnt > 1
		Begin
		Select @contact_rec_cnt = count(*) from contact where contact_id=@contact_id and			                                                    
			                                                    contact_company = @contact_company and			                                                    
																first_name=@first_name and
																last_name =@last_name and
																--name=@name and
																title=@title and
																contact_addr1=@contact_addr1 and
																contact_city=@contact_city and
																contact_state=@contact_state and
																contact_zip_code=@contact_zip_code and
																contact_country = @contact_country and
																phone=@phone and 
																mobile=@mobile and
																email=@email and
																email_flag=@email_flag and
																web_access_flag=@web_access_flag and
																fax =@fax and 
																salutation=@salutation and
																middle_name=@middle_name and
																suffix=@suffix
	   															
         
        If @contact_rec_cnt > 0
		Begin		   
		   Select @eqai_contact_role_cnt = count(*) from ContactCustomerRole where contact_id=@contact_id and customer_id=@customer_id and status='A' and
		                                                                           Contact_Customer_Role in (Select salesforce_contact_role from #temp_salesforce_contact_role)
		      If  @eqai_contact_role_cnt <> @salesforce_contact_role_cnt
			  Begin			   
				Set @contact_rec_cnt=0
			  End
		End
		
        If @contact_rec_cnt=0
		Begin
			Update contact set contact_company = @contact_company,
									   contact_type=Null,  --BA review is in-progress
									    first_name=@first_name,
									   last_name =@last_name,								   
									   name=isnull(@first_name,' ') +' '+ isnull(@last_name,' '),
									   title=@title,
									   contact_addr1=@contact_addr1,
									   contact_city=@contact_city,
									   contact_state=@contact_state,
									   contact_zip_code=@contact_zip_code,
									   contact_country = @contact_country,
									   phone=@phone,
									   mobile=@mobile,
									   email=@email,
									   email_flag=@email_flag,
									   web_access_flag=@web_access_flag,
									   fax =@fax, 
									   salutation=@salutation,
									   middle_name=@middle_name,
									   suffix=@suffix, 
									   date_modified=getdate(),
									   modified_by=@user_code
								Where contact_id=@contact_id
									  

			 if @@error <> 0 or @@ROWCOUNT=0
			 Begin
				Rollback Transaction
				Set @Response = 'Error: Integration failed due to the following reason; Error updating contact table;'+ isnull(ERROR_MESSAGE(),' ')
				Set @flag = 'E'		
   				INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   							SELECT
							@key_value,
   							@source_system,
    						'Update',
    						@Response,
    						GETDATE(),
   							@user_code			
							return -1
			 End	

			 Update ContactXRef set status=@contact_customer_status where contact_id=@contact_id and customer_id=@customer_id

			 Set @contact_type_audit=''
		   End  															 
		End
				
		If  @contact_rec_cnt > 0 
		Begin
		    Set @response ='Error: Integration failed due to the following reason; The contact ID: ' +str(@contact_id) + ' There is no modifications, hence update is not required.'
			Set @flag = 'E'					
			INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
											SELECT
											@key_value,
											@source_system,
											'Insert',
											@response,
											GETDATE(),
											@user_code		
			Commit Transaction								
			Return -1	
		End
		
        
			  
		Declare sf_contact CURSOR fast_forward for
		Select salesforce_contact_role from #temp_salesforce_contact_role 											  
		Open sf_contact
		fetch next from sf_contact into @contact_role_output		
		While @@fetch_status=0
		Begin			
		    
			

			Select @ll_billing_role_cnt=count(*) from ContactCustomerRole
												 Where contact_id=@contact_id and 
													   customer_id=@customer_id and 
													   upper(contact_customer_role) not in (Select salesforce_contact_role from #temp_salesforce_contact_role) and
													   upper(contact_customer_role)='BILLING' and Status='A'
            

			select @ll_jobbilling_project_linked= count(*) from CustomerBillingXContact 
												 INNER JOIN customerbilling ON customerbilling.customer_id=CustomerBillingXContact.customer_id
																			AND customerbilling.billing_project_id=CustomerBillingXContact.billing_project_id   
																			AND customerbilling.status='A'
												 INNER Join  ContactCustomerRole ON ContactCustomerRole.customer_id=CustomerBillingXContact.customer_id			 
																			AND ContactCustomerRole.contact_id=CustomerBillingXContact.contact_id			 
																			AND ContactCustomerRole.status='A' and upper(contact_customer_role)='BILLING'
												INNER JOIN contact ON contact.contact_id=CustomerBillingXContact.contact_id
                                                Where  CustomerBillingXContact.contact_id=@contact_id and 
													   CustomerBillingXContact.customer_id=@customer_id 

            
			If 	@ll_billing_role_cnt > 0 and @ll_jobbilling_project_linked > 0 
			Begin			  
			 Set @email_notification_req='T'

			 SELECT Distinct @ls_previous_role= STUFF((SELECT '; ' + US.contact_customer_role
						  FROM ContactCustomerRole US
						  WHERE US.customer_id = @customer_id AND
								US.contact_id = @contact_id AND
						        US.customer_id = SS.customer_id AND
								US.contact_id = SS.contact_id
						  FOR XML PATH('')), 1, 1, '') 
				FROM ContactCustomerRole SS
				Where SS.customer_id=@customer_id AND
				      SS.contact_id=@contact_id 			
					  
			
			
              SELECT Distinct @ls_linked_billing_project= STUFF((SELECT '; ' + str(US.billing_project_id)
						  FROM customerbilling US
						  WHERE US.billing_project_id in (select CustomerBillingXContact.billing_project_id from CustomerBillingXContact 
												 INNER JOIN customerbilling ON customerbilling.customer_id=CustomerBillingXContact.customer_id
																			AND customerbilling.billing_project_id=CustomerBillingXContact.billing_project_id  
																			AND customerbilling.status='A'
												 INNER Join  ContactCustomerRole ON ContactCustomerRole.customer_id=CustomerBillingXContact.customer_id			 
																			AND ContactCustomerRole.contact_id=CustomerBillingXContact.contact_id			 
																			AND ContactCustomerRole.status='A' and upper(contact_customer_role)='BILLING'
												INNER JOIN contact ON contact.contact_id=CustomerBillingXContact.contact_id
                                                Where  CustomerBillingXContact.contact_id=@contact_id and 
													   CustomerBillingXContact.customer_id=@customer_id )
						  FOR XML PATH('')), 1, 1, '') 
				FROM customerbilling SS
				/*Where SS.customer_id=US.customer_id AND
				      SS.billing_project_id=US.billing_project_id    */       
					  
			  

			End
			

			Update ContactCustomerRole set status='I',modified_by=@user_code,date_modified=getdate() 
					                   Where contact_id=@contact_id and 
									         customer_id=@customer_id and 
											 upper(contact_customer_role) not in (Select salesforce_contact_role from #temp_salesforce_contact_role) 
			
			Select @ll_cont_role_cnt = count (*) from ContactCustomerRole 
			                                     where contact_id=@contact_id and 
												       customer_id=@customer_id and 
													   upper(contact_customer_role)=upper(@contact_role_output) and 
													   (status='I' or Coalesce(status,'I')='I')

			If @ll_cont_role_cnt > 0
			Begin
			 Update ContactCustomerRole set status='A',modified_by=@user_code,date_modified=getdate() 
					                           Where contact_id=@contact_id and 
											         customer_id=@customer_id and 
													 upper(contact_customer_role)=upper(@contact_role_output) and 
													 (status='I' or Coalesce(status,'I')='I')
			End

			Select @ll_cont_role_cnt = count (*) from ContactCustomerRole 
			                                     where contact_id=@contact_id and 
												       customer_id=@customer_id and 
													   upper(contact_customer_role)=upper(@contact_role_output) and 
													   status='A'

			If @ll_cont_role_cnt=0
			Begin		     
			 Insert into ContactCustomerRole (contact_id,customer_id,contact_customer_role,status,added_by,date_added,modified_by,date_modified)
				                              select @contact_id,@customer_id,@contact_role_output,'A',@user_code,getdate(),@user_code,getdate()  
              
			  if @@error <> 0
			  Begin
			   Drop table #temp_salesforce_contact_role
			   Rollback transaction
			   SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting ContactCustomerRole table; '+ isnull(ERROR_MESSAGE(),' ')
   			   INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
																SELECT
																@key_value,
																@source_system,
																'Insert',
																@response,
																GETDATE(),
																@user_code		
				 Return -1
				 End                
			   End
			fetch next from sf_contact into @contact_role_output			
			End
			Close sf_contact
			DEALLOCATE sf_contact 
			Drop table #temp_salesforce_contact_role
		
		 	BEGIN		
			Create table #temp_salesforce_contact_fields (column_name varchar(100),contact_old_value varchar(100),contact_new_value varchar(100))  /*To determine the validation requried field*/
			Insert into  #temp_salesforce_contact_fields (column_name,contact_old_value,contact_new_value) values 
																 ('contact_company',@contact_company_old,@contact_company),
																 ('contact_type',@contact_type_old,@contact_type_audit),
																 ('first_name',@first_name_old,@first_name),
																 ('last_name',@last_name_old,@last_name),
																 ('name',@name_old,isnull(@first_name,' ') +' '+ isnull(@last_name,' ')),
																 ('title',@title_old,@title),
																 ('contact_addr1',@contact_addr1_old,@contact_addr1),
																 ('contact_city',@contact_city_old,@contact_city),
																 ('contact_state',@contact_state_old,@contact_state),
																 ('contact_zip_code',@contact_zip_code_old,@contact_zip_code),
																 ('contact_country',@contact_country_old,@contact_country),
																 ('phone',@phone_old,@phone),
																 ('mobile',@mobile_old,@mobile),
																 ('email',@email_old,@email),
																 ('email_flag',@email_flag,@email_flag),
																 ('web_access_flag',@web_access_flag_old,@web_access_flag),
																 ('contactxref_status',@contact_customer_status_old,@contact_customer_status),
																 ('fax',@fax_old,@fax),
																 ('salutation',@salutation_old,@salutation),
																 ('middle_name',@middle_name_old,@middle_name),
																 ('suffix',@suffix_old,@suffix)
																 
				
				--SELECT @audit_reference='contact_id: ' + STR(@contact_id)
				set @contact_audit_date_modified=GETDATE()
	 			Declare sf_contactaudit_update cursor fast_forward for select column_name,contact_old_value,contact_new_value  from #temp_salesforce_contact_fields
				open sf_contactaudit_update
				fetch next from sf_contactaudit_update into @column_name,@contact_old_value,@contact_new_value
				While @@fetch_status=0
				Begin	
				if (ISNULL(@contact_old_value,'NA') <> ISNULL(@contact_new_value,'NA'))
					begin
					INSERT INTO [dbo].ContactAudit(contact_id,table_name,column_name,before_value,after_value,audit_reference,modified_from,
							  modified_by,
							  date_modified
							  )
					SELECT
							  @contact_id,case when @column_name='contactxref_status' Then 'Account_detail' else 'Contact' End,@column_name,@contact_old_value,
							  @contact_new_value,'contact_id: ' + TRIM(STR(@contact_id)),--@audit_reference,
							  'Salesforce',
							  @user_code,
							  @contact_audit_date_modified
					if @@error <> 0 						
								begin
								rollback transaction
								Close sf_contactaudit_update
								DEALLOCATE sf_contactaudit_update 
								Drop table #temp_salesforce_contact_fields
   								INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   																			SELECT
   																			@key_value,
   																			@source_system,
    																			'Insert',
    																			ERROR_MESSAGE(),
    																			GETDATE(),
   																			@user_code
								return -1
								end
					End
					
				Fetch next from sf_contactaudit_update into @column_name,@contact_old_value,@contact_new_value
				End
				Close sf_contactaudit_update
				DEALLOCATE sf_contactaudit_update 
			    Drop table #temp_salesforce_contact_fields
			End
		


			--------------------
			--COMMIT TRANSACTION
			--------------------
			commit transaction
			  
				If @email_notification_req='T'
				Begin  			  
				  exec @ll_ret_email=dbo.sp_sfdc_contact_role_upd_email_notification @salesforce_contact_csid, @customer_id, @contact_id, @contact_type_org, @first_name, @last_name, @email, @contact_customer_status,@user_code,@ll_billing_role_cnt,@ls_previous_role,@ls_linked_billing_project
				End
			End	
End

  If @ls_config_value='F'
	Begin
	   Set @response = 'SFDC Data Integration Failed,since CRM Go live flag - Phase2 is off. Hence Store procedure will not execute.'
	   Return -1
	End
Return 0

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_contact_update] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_contact_update] TO svc_CORAppUser

Go