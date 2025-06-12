USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_contact_Insert]    Script Date: 10/14/2024 3:13:32 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[sp_sfdc_contact_Insert] 
						@contact_company varchar(75) NULL,
						@salesforce_contact_csid VARCHAR(18) NULL,
						@d365customer_id varchar(20) NULL,
						@contact_type varchar(100) NULL,
						@employee_id varchar(20) NULL,						
						@first_name varchar(20) NULL,
						@last_name varchar(20) NULL,
						@title varchar(35) NULL,
						@contact_addr1 varchar(35) NULL,						
						@contact_city varchar(40) NULL,
						@contact_state char(2) NULL,
						@contact_zip_code varchar(15) NULL,
						@contact_country varchar(40) NULL,
						@phone varchar(255) NULL,
						@mobile varchar(10) NULL,
						@email varchar(40) NULL,
						@email_flag char(1) ='T',
						@web_access_flag char(1)='F',
						@contact_customer_status char(1) NULL,
						@contact_id_clone int=Null,
						@JSON_DATA nvarchar(max),		
						@response varchar(2000) OUTPUT

/*

Description: 

API call will be made from salesforce team to Insert the contact,contactxref,customercontatrole tables.

when a new contact is created in Salesforce (and associated attributes/fields) along with the customer relationship, are sent to EQAI. 

Revision History:

Rally# US116037 - 06/17/2024  Nagaraj M   Initial Creation
Rally# DE34428  - 07/02/2024  Nagaraj M	  Integration should not proceed, if email id is received null from salesforce. 
Rally# US116477 - 07/05//2024 Nagaraj M   Inserting into CustomerAudit record.
Rally# DE34519  - 07/10/2024  Nagaraj M	  Added Contact Id in response for the successful integration.
USE PLT_AI
GO
Declare @response nvarchar(max)
EXECUTE dbo.sp_sfdc_contact_Insert
@contact_company='DEVOPS US116477',
@salesforce_contact_csid='US116477_05jul_002',
@d365customer_id='C002788',
@contact_type='Billing;Quote',
@employee_id='864502',
@first_name='Nagaraj',
@last_name='Mallaiah',
@title='Developer',
@contact_addr1='RTC COLONY',
@contact_city='Hyderabad',
@contact_state='CA',
@contact_zip_code='92243',
@contact_country='INDIA',
@phone='9884947801',
@mobile='9884251514',
@email ='NAG@GMAIL.COM',
@contact_customer_status='A',
@JSON_DATA='123',
@response=@response output
print @response

SELECT TOP 50 * FROM CONTACT ORDER BY DATE_MODIFIED DESC
SELECT TOP 50 * FROM CONTACTxref ORDER BY DATE_MODIFIED DESC
SELECT TOP 50 * FROM ContactCustomerRole ORDER BY DATE_MODIFIED DESC

*/

AS
BEGIN
DECLARE 
@contact_id int,
@name varchar(100),
@XREF_contact_type char(1) ='C',
@web_access char(1)='I',
@contact_customer_role varchar(40),
@date_modified datetime,
@date_added datetime,				
@ls_config_value char(1),
@source_system varchar(200),
@validation_req_field varchar(100),
@validation_req_field_value varchar(500),
@validation_response varchar(1000), 
@ll_validation_ret int,
@customer_id int,
@primary_contact char(1)='F',
@user_code varchar(10),
@ll_ret int,
@ll_doc_len int,
@ll_doc_index int,
@sf_contact_role_ret varchar(80),
@sf_contact_role varchar(80),
@key_value varchar(2000),
@flag Char(1) ='I',
@contact_type_output varchar(20),
@cust_name varchar(75),
@ll_sf_role_cnt int,
@contact_xref_cnt int

set @date_added = getdate()
set @date_modified = getdate()



Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag_phase2'
		IF @ls_config_value is null or @ls_config_value=''
		Begin
				Select @ls_config_value='F'
		End

IF @ls_config_value='T'  
BEGIN

		Select @source_system = 'sp_sfdc_contact_Insert:: ' + 'Sales force'  
         	
			   		 	  	  	   	
		Create table #temp_salesforce_validation_fields (validation_req_field varchar(100),validation_req_field_value varchar(500))  /*To determine the validation requried field*/
		Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 		                                            
		                                            ('d365customer_id',@d365customer_id),      
	                                                ('salesforce_contact_csid',@salesforce_contact_csid),
		                                            ('employee_id',@employee_id),
													('email',@email)
		
		SELECT
		@key_value =	
						' contact_company ;'+isnull(@contact_company,'') + 
						' salesforce contact csid ;'+isnull(@salesforce_contact_csid,'') + 
						' d365customer_id ;' + isnull(@d365customer_id,'') + 
						' contact type ;'+isnull(@contact_type,'') + 
						' first Name ;'+isnull(@first_name,'') + 
						' Last Name ;'+isnull(@last_name,'') + 
						' Title ;'+isnull(@Title,'') + 
						' Employee id ;'+isnull(@employee_id,'') + 
						' contact_addr1 ; ' + isnull(@contact_addr1,'') +
						' contact city ; ' + isnull(@contact_city,'') +
						' contact state ; ' + isnull(@contact_state,'') +
						' contact zip_code ; ' + isnull(@contact_zip_code,'') +
						' contact state ; ' + isnull(@contact_state,'') +
						' contact country ; ' + isnull(@contact_country,'') +
						' Phone ; ' + isnull(@Phone,'') +
						' Mobile ; ' + isnull(@Mobile,'') +
						' email ; ' + isnull(@email,'') +
						' email flag ; ' + isnull(@email_flag,'') +
						' Web Access flag ; ' + isnull(@web_access_flag,'') +
						' contact_customer_status ;' + isnull(@contact_customer_status,'') +
						' salesforce_contact_csid ;' +isnull(@salesforce_contact_csid ,'') +
						' Contact_id_closne ;' +isnull(str(@contact_id_clone),'') 
						
						
	 Set @response = 'Integration Successful'
	
	 
	    If @JSON_DATA is null Or @JSON_DATA=''
		Begin
			Set @response = 'Error: Integration failed due to the following reason;Recevied JSON data string empty/null'
			Set @flag = 'E' 		
		End
		
		Declare sf_validation CURSOR fast_forward for
			select validation_req_field,validation_req_field_value from #temp_salesforce_validation_fields
			Open sf_validation
				fetch next from sf_validation into @validation_req_field,@validation_req_field_value		
				While @@fetch_status=0
				Begin				   
				   EXEC @ll_validation_ret=dbo.sp_sfdc_input_parm_validation 'sp_sfdc_contact_insert',@validation_req_field,@validation_req_field_value,0,0,@validation_response output

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
				    select @customer_id=customer_id,@cust_name=cust_name from Customer where ax_customer_id=@d365customer_id and cust_status='A'					
				   End 
				   
				fetch next from sf_validation into @validation_req_field,@validation_req_field_value   
			   End		
           Close sf_validation
		DEALLOCATE sf_validation 
		Drop table #temp_salesforce_validation_fields

		If @contact_id_clone is not null and @contact_id_clone <> ''  --Vr
		Begin
			Select @contact_xref_cnt = count(*) from contactxref where contact_id=@contact_id_clone and customer_id=@customer_id 
			 IF @contact_xref_cnt > 0 
			 Begin
			    
				If @Response = 'Integration Successful'
				Begin
					Set @Response =  'Error: Integration failed due to the following reason; The contact ID: ' +str(@contact_id_clone) + ' already linked with the customer: ' +str(@customer_id) +' in contactxref table.'  
					Set @flag='E' 
				End
				Else
				If  @Response <> 'Integration Successful'
				Begin
					Set @Response = @Response + 'The contact ID: ' +str(@contact_id_clone) + ' already linked with the customer: ' +str(@customer_id) +' in contactxref table.'  
					Set @flag='E' 
				End
				
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

	   IF @FLAG <>'E' 
		BEGIN
			BEGIN TRANSACTION

			Begin

			If @contact_id_clone is null or @contact_id_clone = ''  --Vr
			Begin
				Execute @contact_id = sp_sequence_next 'Contact.Contact_ID', 0 -- zero = silent
	        End

			If @contact_id_clone is not null and  @contact_id_clone <> ''  --Vr
			Begin
			   Set @contact_id=@contact_id_clone
			End


			Create table #temp_salesforce_contact_customer_role (sf_contact_role varchar(80))
			set @sf_contact_role=@contact_type
		
			Set @ll_doc_len=len(@sf_contact_role)
			If @ll_doc_len > 0 
			Begin
				WHILE @ll_doc_len > 0
				BEGIN
		  		Set @ll_doc_index=CharIndex(';',@sf_contact_role)
				If  @ll_doc_index > 0 
					Begin
						Set @sf_contact_role_ret=Substring(@sf_contact_role,1,@ll_doc_index-1)
			            
						Insert into #temp_salesforce_contact_customer_role (sf_contact_role ) Values
																			 ( @sf_contact_role_ret)

              
														
						Set @sf_contact_role=Substring(@sf_contact_role,@ll_doc_index+1,@ll_doc_len)
					End
               Else
			   If len(@sf_contact_role) > 0
			   Begin
				   Set @sf_contact_role_ret=Substring(@sf_contact_role,1,len(@sf_contact_role))
				   Set @ll_doc_len = -1
				   
				   Insert into #temp_salesforce_contact_customer_role (sf_contact_role ) Values
																				 ( @sf_contact_role_ret)
				                                
				End			   
			  End
		  	End

			 Select @ll_sf_role_cnt=count(*) from #temp_salesforce_contact_customer_role

			 If @contact_id_clone is null or @contact_id_clone = '' --Vr
			 Begin
			 Insert into contact
			 (
			 contact_id,
			 contact_company,    		 
			 contact_type,
			 modified_by,
			 first_name,
			 last_name,
			 name,
			 title,
			 date_modified,
			 date_added,
			 contact_addr1,
			 contact_city,
			 contact_state,
			 contact_zip_code,
			 contact_country,
			 phone,
			 mobile,
			 email,
			 email_flag,
			 web_access_flag,
			 contact_status
			 )
			 SELECT
			 @contact_id,
			 @contact_company,			 
			 Case when @ll_sf_role_cnt = 1 Then @contact_type
			      when @ll_sf_role_cnt = 0 Then Null
			      When @ll_sf_role_cnt > 1 Then Null
				  End,
			 @user_code,
			 @first_name,
			 @last_name,
			 @first_name +' '+ @last_name,
			 @title,
			 @date_modified,
			 @date_added,
			 @contact_addr1,
			 @contact_city,
			 @contact_state,
			 @contact_zip_code,
			 @contact_country,
			 @phone,
			 @mobile,
			 @email,
			 @email_flag,
			 @web_access_flag,
			 'A'
		
				if @@error <> 0
				Begin
					rollback transaction
					SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting contact table;'+ isnull(ERROR_MESSAGE(),' ')
   					INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   					SELECT
   					@key_value,
   					@source_system,
    					'Insert',
    					@Response,
    					GETDATE(),
   					@user_code
					return -1
				END
            End  
			
			If @contact_id_clone is not null and @contact_id_clone <> '' --Vr
			Begin			
			Update contact Set			 				
			     contact_company=@contact_company,
			     contact_type=Case when @ll_sf_role_cnt = 1 Then @contact_type
								   when @ll_sf_role_cnt = 0 Then Null
								   When @ll_sf_role_cnt > 1 Then Null
								   End,  
				 modified_by=@user_code,
				 first_name=@first_name,
				 last_name=@last_name,
				 name=@first_name +' '+ @last_name,
				 title=@title,
			 	 date_modified=getdate(),
			 	 contact_addr1=@contact_addr1,
				 contact_city=@contact_city,
				 contact_state=@contact_state,
				 contact_zip_code=@contact_zip_code,
				 contact_country=@contact_country,
				 phone=@phone,
				 mobile=@mobile,
			     email=@email,
				 email_flag=@email_flag,
				 web_access_flag=@web_access_flag where 
				 contact_id=@contact_id_clone	
				 
				 if @@error <> 0
				 Begin
					rollback transaction
					SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting contact table;'+ isnull(ERROR_MESSAGE(),' ')
   					INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   					SELECT
   					@key_value,
   					@source_system,
    					'Update',
    					@Response,
    					GETDATE(),
   					@user_code
					return -1
				END
			End
			
			
			INSERT INTO CONTACTXREF
			(
			salesforce_contact_csid, 
			contact_id,
			type,
			customer_id,
			web_access,
			status,
			date_added,
			added_by,
			modified_by,
			date_modified,
			primary_contact
			)
			select
			@salesforce_contact_csid,
			@contact_id,
			@XREF_contact_type,
			@customer_id,
			@web_access,				
			@contact_customer_status,
			@date_added,
			@user_code,
			@user_code,
			@date_modified,
			@primary_contact
			
			if @@error <> 0
			Begin
				rollback transaction
				SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting contactXref table;'+ isnull(ERROR_MESSAGE(),' ')
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
				return -1
			END
			

				Declare sf_contact_type CURSOR fast_forward for
				select distinct sf_contact_role from #temp_salesforce_contact_customer_role
				Open sf_contact_type
				fetch next from sf_contact_type into @contact_type_output
				While @@fetch_status=0
				Begin
					Insert into ContactCustomerRole 
					(
					contact_id,
					customer_id,
					contact_customer_role,
					status,
					added_by,
					date_added,
					modified_by,
					date_modified
					)
					select
					@contact_id,
					@customer_id,
					@contact_type_output,				
					@contact_customer_status,
					@user_code,
					@date_added,
					@user_code,
					@date_modified
			
					if @@error <> 0
					begin
						rollback transaction;
						Close sf_contact_type
						DEALLOCATE sf_contact_type 	 
						SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting ContactCustomerRole table;'+ isnull(ERROR_MESSAGE(),' ')
   						INSERT INTO PLT_AI_AUDIT..Source_Error_Log 
						(Input_Params,
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
					END
				fetch next from sf_contact_type into @contact_type_output
				End		
				Close sf_contact_type
				DEALLOCATE sf_contact_type 	 
				Drop table #temp_salesforce_contact_customer_role

				If @contact_id_clone is null or @contact_id_clone = '' --Vr
				Begin
				insert into ContactAudit
				(contact_id,table_name,column_name,before_value,after_value,audit_reference,modified_by,modified_from,date_modified)
				select @contact_id,'Contact','Contact_id','(created)',@contact_id,'Contact created for ACV import per ' +@USER_CODE,@user_code,'SALESFORCE',GETDATE()

				if @@error <> 0
				Begin
					rollback transaction
					SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting ContactAudit table;'+ isnull(ERROR_MESSAGE(),' ')
   					INSERT INTO PLT_AI_AUDIT..Source_Error_Log 
					(Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   					SELECT @key_value,
   						   @source_system,
    					   'Insert',
    					   @Response,
    					   GETDATE(),
   						   @user_code
					return -1
				END
				End

				Insert into ContactAudit
				(contact_id,table_name,column_name,before_value,after_value,audit_reference,modified_by,modified_from,date_modified)
				select @contact_id,'Account_detail',NULL,'(blank)','(inserted)','Customer_id: ' +trim(str(@customer_id)) +' - ' +@cust_name,@user_code,'SALESFORCE',GETDATE()
				if @@error <> 0
				Begin
					rollback transaction
					SELECT @Response = 'Error: Integration failed due to the following reason; Error inserting ContactAudit table;'+ isnull(ERROR_MESSAGE(),' ')
   					INSERT INTO PLT_AI_AUDIT..Source_Error_Log 
					(Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   						SELECT @key_value,
   							   @source_system,
    						   'Insert',
    						   @Response,
    						   GETDATE(),
   							   @user_code
					return -1
				END

End
if @response='Integration Successful'
BEGIN 
SET @response = @response +';Contact Id:'+trim(STR(@CONTACT_ID))
END

Commit Transaction;
End
End
If @ls_config_value='F'
	BEGIN
		select @response = 'SFDC Data Integration Failed,since CRM Go live flag - Phase2 is off. Hence Store procedure will not execute.'
		Return -1
	END
END





GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_contact_Insert] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_contact_Insert] TO svc_CORAppUser

GO