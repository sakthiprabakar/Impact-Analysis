USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_workorderheader_Insert]    Script Date: 2/3/2025 2:45:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER   PROCEDURE [dbo].[sp_sfdc_workorderheader_Insert] 
						@d365customer_id varchar(20)= Null,						
						@salesforce_invoice_CSID varchar(18) = Null,
						@Purchase_Order varchar(20)= Null,
						@project_code varchar(15) = Null,
						@AX_Dimension_5_Part_1 varchar(20)= Null,
						@company_id int= Null,				
						@end_date datetime = Null,
						@generator_id int= Null,	
						@salesforce_site_csid varchar(18)=Null,
						@profit_ctr_id int= Null,
						@start_date datetime= Null,
						@workorder_type_id int= Null,
						@description varchar(255) = NULL,
						@project_name varchar(40) =Null,
						@contact_id int =Null,
						@JSON_DATA nvarchar(max),
						@employee_id varchar(20)=Null,
						@invoice_comment_1 varchar(80)=Null,
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
						@NAICS_code int=Null,
						@gen_status char(1)=Null,
						@as_site_changed char(1) ='F',
						@as_so_disposal_flag char(1)='F',
						@billing_project_id int =Null,
						@response varchar(4000) OUTPUT

/*  
Description: 

API call will be made from salesforce team to Insert the workorderheader table.

Revision History:

DevOps# 74012 - 10/20/2023  Nagaraj M   Created
Once the Pro Forma Invoice has been created, the necessary 
Salesforce fields need to be sent to Salesforce (Sales Invoice object & Sales Invoice Line object) 
to EQAI (Work Order Header, Work Order Detail, & Note object).
Devops# 76453 01/04/2024 Venu Modified the Procedure - Implement the validation for all the required fields.
Devops# 77458 01/31/2024 Venu Modified for the erorr handling messgae text change
Devops# 78208 02/08/2024 Venu Modified to split the validation
Devops# 79234 02/22/2024 Venu - Modified for adding addtional integarted fields and default values.
Devops#79208  02/22/2024 Venu - Modified - added the insert data into  WorkOrderStop table
Devops#79194  02/22/2024 Venu - Modified - added the audit table insert for workorderaudit table
Devops#79231  02/27/2024 Nagaraj M - Modified - Added the insert data values for the workordertracking table.
Devops#79428  02/27/2024 Nagaraj M - Modified - Added the input parameter "description"
Devops#81407  03/18/2024  Venu Map Salesforce Sales Order "Job Description" to EQAI Work Order "Name"
Devops#81151  03/18/2024 Venu add mapping for Contact ID to the Work Order Header
Devops# 81419 03/19/2024 Venu Populate the user_code to added_by and modified_by fields
Devops# 81974 03/27/2024 Apended project_code for audit_reference text for the workorderaudit
Devops# 83071 03/28/2024 Venu implemenmted the generator lookup logic
Devops# 84556 04/24/2024 Venu added the new integration filed invoice_comment_1
Devops# 83361 - 04/29/2024 Rob - Populate Salesforce staging tables instead of actual EQAI tables (for fully transactional integration)
Devops# 87465 05/15/2024 Nagaraj removed/commented the "salesforce_contract_number" as part of decommision of contractbillingproject,sp_sfdc_customerbilling_insert.
Devops# 87468  fix deployment script review comments by Venu
Devops# 87927 -- 05/20/2024 Venu Modified the error handling.
Devops#89138  -- 06/01/2024 Venu modified for Update Case Sensitivity for CSID on Generator Lookup
US#117391 --07/02/2024 Nagaraj, Added logic for updating generator address for the respective salesforce_site_CSID and @as_site_changed='T'.
US#DE34626  -- 07/18/2024 Venu & Nagaraj added logic to insert new generator
US#117945  --07/18/2024 Nagaraj added the logic for disposal SO flag (To handle WOH creation during WOQ header)
US#118337 --07/29/2024 Rob - It is now possible that an insert into WorkOrderHeader is part of the transaction
US#123118 --08/28/2024 Venu - EQAI - Update job level billing project automation 
US#129733  -- 11/07/2024 Venu - Added salesforce so csid in workorderheader table
US#131973  - 12/18/2024 Venu - Added validation if SF invoke this proceudre for Disposal record
US#131404  - 01/09/2025 Venu added logic to create new generator when request came from salesforce

USE PLT_AI
GO
Declare @response nvarchar(max);
EXEC dbo.sp_sfdc_workorderheader_Insert
@d365customer_id='C022410',
@salesforce_invoice_csid='US117391_18JUL_104',
@Purchase_Order='12345',
@project_code='T-V224',
@AX_Dimension_5_Part_1='test2',
@company_id=21,
@end_date='06/Nov/2023',
--@generator_id =358423,
@generator_id ='',
@salesforce_site_csid='US117391_18JUL_102',
@profit_ctr_id=0,
@start_date='06/Nov/2023',
@workorder_type_id=6,
@description='EQAI - Updates to Site Address',
@project_name='Test',
@contact_id=121,
@JSON_DATA ='{
"Account_Executive__c": "John Jacobsen",
"Billing_Instructions__c": "T&D Bilge Water USNS Watkins",
"Approved__c": "a0uDR000001rpYaYAI",
"Phone_No__c": "781-771-0354"}',
@employee_id='864502',
@invoice_comment_1='test',
@generator_name = 'workorder header testing generators',
@generator_address_1 = '25000 CLUBHOUSE DR7',
@generator_address_2= 'test1234',
@generator_address_3='22',
@generator_address_4='123',
@generator_address_5='3333',
@generator_city = 'MIDDLETOWN',
@generator_state='GA',     
@generator_zip_code='30354', 
@generator_country='USA',
@generator_phone= '7327708020',    
@generator_FAX= '1233', 
@gen_mail_name = 'workorder header',
@gen_mail_addr1 = '25000 CLUBHOUSE DR363',
@gen_mail_addr2 = '123',
@gen_mail_addr3 = '32',
@gen_mail_addr4 = '2323',
@gen_mail_addr5 = '232',
@gen_mail_city = 'ROCHESTER',
@gen_mail_state = 'MI',
@gen_mail_zip_code = '48307',
@gen_mail_country = 'USA',
@NAICS_code = 12345,
@gen_status='A',
@as_site_changed='T',
@response=@response output
print @response
EXECUTE  sp_sfdc_process_staging_workorder 'US117391_1' --salesforce_invoice_csid

Select top 50 * from SFSworkorderheADER 
WHERE salesforce_invoice_csid='US117391_2'
ORDER BY DATE_ADDED DESC

Select top 50 * from generator where salesforce_site_csid is not null
order by date_added desc
*/


AS
DECLARE 
	 @quote_id int,
	 @workorder_ID int,
	 @key_value nvarchar(4000),
	 @revision int = 0,
	 @customer_id int,
	 @ll_ret int,
	 @customer_count int,
	 @source_system varchar(100)='Sales Force',
	 @workrder_status char(1)='N',
	 @submitted_flag char(1) ='F',
	 @other_submit_required_flag char (1) ='F',
	 @tracking_id int=1,
	 @urgency_flag char(1) ='R',
	 @currency_code char(3) ='USD',
	 @priced_flag smallint =1,
	 @cust_discount float =0,
	 @tracking_contact varchar(10) = 'SFINTEGRAT',
	 @AX_Dimension_5_Part_2 varchar(9) ='',
	 @Notes_subject char(1)='H',
	 @ls_config_value char(1)='F',
	 @Flag CHAR(1) ='S',
	 @ll_count_rec int,
	 @next_workorder_id INT,
	 @TEMP_ID INT,
	 @validation_req_field varchar(100),
     @validation_req_field_value varchar(500),
	 @validation_response varchar(1000),	 
	 @ll_validation_ret int,	 
	 --@billing_project_id int =0,
	 @generator_county int,
	 @ll_count_billing_rec int,
	 @user_code varchar(10)='N/A',
	 @Generator_result varchar(200),
	 @as_gen_insert CHAR(1)='F',
	 @as_gen_update CHAR(1)='F',
	 @ll_gen_cnt int,
	 @sfs_workorderheader_uid int,
	 @ll_billing_project_cnt int,
	 @ls_config_value_phase3 char(1),
	 @sfdc_billing_package_flag char(1)='F'

Set transaction isolation level read uncommitted

Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag'
		IF @ls_config_value is null or @ls_config_value=''
		Begin
				Set @ls_config_value='F'
		End
Select @ls_config_value_phase3 = config_value From configuration where config_key='CRM_Golive_flag_phase3'
		IF @ls_config_value_phase3 is null or @ls_config_value_phase3=''
		Begin
				Set @ls_config_value_phase3='F'
		End		

		If @as_so_disposal_flag is null or @as_so_disposal_flag=''
		Begin
			Set @as_so_disposal_flag='F'
		End 
		
		IF @ls_config_value_phase3='F'
		Begin
		Set @billing_project_id=Null
		End

IF @ls_config_value='T'
Begin
Begin transaction			
			Select @source_system = 'sp_sfdc_workorderheader_insert: ' + @source_system  

			Set @key_value =	'salesforce_invoice_CSID;' + isnull((@salesforce_invoice_CSID ), '') +
			                    ' d365customer_id;' + isnull(@d365customer_id, '') + 								
								' Purchase_Order;' + isnull(@Purchase_Order,'') + 
								' project_code;' + isnull(@project_code,'') + 
								' AX_Dimension_5_Part_1;' + isnull(@AX_Dimension_5_Part_1,'') +
								' company_id;' + isnull(STR(@company_id  ), '') + 
								' end_date;' + cast((convert(datetime,@end_date)) as varchar(20))+	
								' generator_id;' + isnull(STR(@generator_id), '') +								
								' salesforce_site_csid;' + isnull(@salesforce_site_csid, '') +								
								' profit_ctr_id;' + isnull(STR(@profit_ctr_id),'') +
								' start_date;' + cast((convert(datetime,@start_date)) as varchar(20))+	
								' workorder_type_id;' + isnull(STR(@workorder_type_id), '') +
								' description;' + isnull(@description,'') + 
								' project_name;' + isnull(@project_name,'') + 
								' contact_id;' + isnull(STR(@contact_id), '') +
								' employee_id;' +isnull(@employee_id,'') +		
								' invoice_comment_1;' +isnull(@invoice_comment_1,'') +		
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
								' gen_status;' + isnull(@gen_status,'') + 					 
								' NAICS_code;' + isnull(STR(@NAICS_code), '') +
								' as_site_changed;' + isnull(@as_site_changed,'') + 
								' as_so_disposal_flag;' + isnull(@as_so_disposal_flag,'') 
								
								
								
			Select @as_site_changed = COALESCE (@as_site_changed,'F')
			
			Set @response = 'Integration Successful'

			If @JSON_DATA is null Or @JSON_DATA=''
			Begin
				Set @response = 'Error: Integration failed due to the following reason;Received JSON data string empty/null'			
				Set @flag = 'E'			
			End
		    
			If @as_so_disposal_flag='T'			
			Begin
			    Set @response = 'Error: Integration failed due to the following reason; Waste Disposal Integration should use via Single JSON'			
				Set @flag = 'E'	
				   INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
													SELECT
													@key_value,
													@source_system,
													'Insert',
													@Response,
													GETDATE(),
													@user_code
                    commit transaction
					Return -1								
				End

			If @as_so_disposal_flag='T' and @ls_config_value_phase3='F'
			Begin
			   Set @response = 'Error: Integration failed due to the following reason; disposal flag passed as True but CRM golive phase3 flag is off mode'			
			   Set @flag = 'E'			
			End

			

			
			Create table #temp_salesforce_validation_fields (validation_req_field varchar(100),validation_req_field_value varchar(500))  /*To determine the validation requried field*/
			Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
																 ('company_id',str(@company_id)),
																 ('profit_ctr_id',str(@profit_ctr_id)),
																 ('project_code',@project_code),
																 ('d365customer_id',@d365customer_id),
																 ('salesforce_invoice_CSID',@salesforce_invoice_CSID),	
																 ('salesforce_site_csid',isnull(@salesforce_site_csid,'N/A')),
																 ('workorder_type_id',str(@workorder_type_id)),
																 ('employee_id',@employee_id)
			
            If  (@salesforce_site_csid is null or @salesforce_site_csid='') and @generator_id is not null and @generator_id <> '' and @generator_id <> 0
			Begin
			Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
			                                                ('generator_id',str(@generator_id)) 
			End
																

			Declare sf_validation CURSOR fast_forward for
					select validation_req_field,validation_req_field_value from #temp_salesforce_validation_fields
					Open sf_validation
						fetch next from sf_validation into @validation_req_field,@validation_req_field_value		
						While @@fetch_status=0
						Begin						   
						   EXEC @ll_validation_ret=dbo.sp_sfdc_input_parm_validation 'sp_sfdc_workorderheader_insert',@validation_req_field,@validation_req_field_value,@company_id,@profit_ctr_id,@validation_response output,@as_so_disposal_flag
								If @validation_req_field='d365customer_id' and @ll_validation_ret <> -1
								   Begin
								   select @customer_id=customer_id,@sfdc_billing_package_flag=sfdc_billing_package_flag from Customer where 
								          ax_customer_id=@d365customer_id and cust_status='A'
                                    If @sfdc_billing_package_flag is null or @sfdc_billing_package_flag=''
									Begin
									 Set @sfdc_billing_package_flag='F'
									End
									If @sfdc_billing_package_flag ='T' and @ls_config_value_phase3='F'
									Begin
									 Set @sfdc_billing_package_flag='F'
									End
								   End
                               If @validation_req_field='employee_id' and @ll_validation_ret <> -1
									Begin
									EXEC dbo.sp_sfdc_get_usercode @employee_id,@user_code output     
									End

						   If @ll_validation_ret = -1
						   Begin 
								 If @Response = 'Integration Successful'
								 Begin
									Set @Response ='Error: Integration failed due to the following reason;'
								 End
							 Set @Response = @Response + @validation_response+ ';'
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
					Set @Response ='Error: Integration failed due to the following reason;Site csid and generator ID both can not be empty/null;'
					Set @flag='E' 
				End 
				Else
				If @Response <> 'Integration Successful'
				Begin
					Set @Response = @Response +'Site csid and generator ID both can not be empty/null;'
					Set @flag='E'   
				End 	
			End
					
			/*If (@as_site_changed='T') and (@salesforce_site_csid is null or @salesforce_site_csid ='')
			Begin	
				If @Response = 'Integration Successful'
				Begin
					Set @Response ='Error: Integration failed due to the following reason;Site CSID cannot be null, since site csid is required to update/insert the generator;'
					Set @flag='E' 
				End 
				Else
				If @Response <> 'Integration Successful'
				Begin
					Set @Response = @Response +'Site CSID cannot be null, since site csid is required to update/insert the generator;'
					Set @flag='E'   
				End 	
			End */
									
			If (@salesforce_site_csid IS NOT NULL and @salesforce_site_csid <> '' and @generator_id is not null and @generator_id <> '' and @generator_id <> 0) 
			Begin
			select @ll_gen_cnt = count(*) from generator Where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS=@salesforce_site_csid and generator_id=@generator_id and status='A'
                    
			If 	@ll_gen_cnt = 0 
				Begin 				
					If @Response = 'Integration Successful'
					Begin
						Set @Response ='Error: Integration failed due to the following reason; received generator id:' +isnull(str(@generator_id),'N/A')+ ' and salesforce site csid:' +isnull(@salesforce_site_csid,'N/A')+' not exists in EQAI generator table;'
						Set @flag='E' 
					End 
					Else
					If @Response <> 'Integration Successful'
					Begin
						Set @Response = @Response +'received generator id:' +isnull(str(@generator_id),'N/A')+ ' and salesforce site csid:' +isnull(@salesforce_site_csid,'N/A')+' not exists in EQAI generator table;'
						Set @flag='E'   
					End 				
				End						              
			End
				
			If (@salesforce_site_csid IS NOT NULL and @salesforce_site_csid <> '' and (@generator_id is null or @generator_id = '' or @generator_id=0 ))
			Begin	
			
			select @ll_gen_cnt = count(*) from generator Where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS=@salesforce_site_csid and status='A'
                    
			/*If 	@ll_gen_cnt = 0 
			Begin 				
					If @Response = 'Integration Successful'
					Begin
						Set @Response ='Error: Integration failed due to the following reason; received salesforce site csid:' +isnull(@salesforce_site_csid,'N/A')+' not exists in EQAI generator table;'
						Set @flag='E' 
					End 
				Else
				If @Response <> 'Integration Successful'
				Begin
					Set @Response = @Response +'received salesforce site csid:' +isnull(@salesforce_site_csid,'N/A')+' not exists in EQAI generator table;'
					Set @flag='E'   
				End 				
			End */
						
				If @ll_gen_cnt = 1 and @flag <> 'E'
				Begin
					select  @generator_id= generator_id from generator where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS=@salesforce_site_csid and status='A'  
				End						              
			End 
				
			  /* If @flag = 'E'
			   Begin
				   INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
													SELECT
													@key_value,
													@source_system,
													'Insert',
													@Response,
													GETDATE(),
													@user_code
                    commit transaction
					Return -1								
				End */

	     
		 If (@billing_project_id IS NOT NULL and @billing_project_id <> '') 
		 Begin
		 
		 Select @ll_billing_project_cnt = count(*) from customerbilling where customer_id=@customer_id and billing_project_id=@billing_project_id and status='A'
                    
		 If @ll_billing_project_cnt = 0 
		 Begin 				
			If @Response = 'Integration Successful'
			Begin
				Set @Response ='Error: Integration failed due to the following reason; received Billing project id:' +isnull(str(@billing_project_id),'N/A')+ '  not exists or not an active status in EQAI customerbilling table for the customer ' + isnull(str(@customer_id),'N/A')
				Set @flag='E' 
			End 
		    Else
			If @Response <> 'Integration Successful'
			Begin
				Set @Response = @Response +'received Billing project id:' +isnull(str(@billing_project_id),'N/A')+ '  not exists or not an active status in EQAI customerbilling tablefor the customer ' + isnull(str(@customer_id),'N/A')
				Set @flag='E'   
			End 				
		   End						              
		 End



 IF @FLAG  <> 'E'
	Begin
        if coalesce(@as_so_disposal_flag,'F') = 'T'
            select @quote_id=max(quote_id) from SFSWorkOrderQuoteHeader where project_code=@project_code
                                                                    AND company_id=@company_id
                                                                    AND profit_ctr_id = @profit_ctr_id
        else
            select @quote_id=quote_id from WorkOrderQuoteHeader where project_code=@project_code
                                                                    AND company_id=@company_id
                                                                    AND profit_ctr_id = @profit_ctr_id
	

		select @customer_id=customer_id  from Customer where ax_customer_id=@d365customer_id and cust_status='A'
	-- Workorder id generation starts	
		select @next_workorder_id=next_workorder_id from ProfitCenter where profit_ctr_id = @profit_ctr_id
																			and company_id = @company_id
        Begin
		IF @next_workorder_id ='' OR  @next_workorder_id IS NULL 
			Begin
				select @next_workorder_id = 2
				select @TEMP_ID = 1 * 100
			End
		Else
			Begin
				SELECT @TEMP_ID=@next_workorder_id +1
				select @next_workorder_id = @next_workorder_id * 100
			End
	    End


		If (@billing_project_id is null or @billing_project_id='') and @sfdc_billing_package_flag='F'
		Begin
		 select top 1 @billing_project_id = billing_project_id from customerbilling where customer_id=@customer_id and salesforce_jobbillingproject_csid='0' -- To get the SF standard
		End
		If @billing_project_id is null or @billing_project_id='' and @sfdc_billing_package_flag='F'
		Begin
		Set @billing_project_id=0
		End
		

		/*select @ll_billing_project_cnt = count(*) from customerbilling where customer_id=@customer_id and salesforce_so_quote_id=@project_code
		 If @ll_billing_project_cnt > 0 
		 Begin
		  select top 1 @billing_project_id = billing_project_id from customerbilling where customer_id=@customer_id and salesforce_so_quote_id=@project_code
		 End */
	-- Workorder id generation ends


		If (@salesforce_site_csid IS NOT NULL and @salesforce_site_csid <> '') and @as_site_changed='T' and (@generator_id is not null and @generator_id <> '' and @generator_id <> 0 )  --Added venu generator condition
		Begin
		  SET @as_gen_update='T'
        End 

		If (@salesforce_site_csid IS NULL Or  @salesforce_site_csid = '') and @as_site_changed='T' and (@generator_id is not null and @generator_id <> '' and @generator_id <> 0 )  --Added venu generator condition
		Begin
		  SET @as_gen_update='T'
        End 

		If (@salesforce_site_csid IS NOT NULL and @salesforce_site_csid <> '') and (@generator_id is null Or @generator_id = '')
        Begin
			EXECUTE @generator_id = dbo.sp_sequence_next 'Generator.generator_id'
			SET @as_gen_insert='T'
		End
		  
		

		If NOT EXISTS (SELECT *
					   FROM WorkOrderHeader
					   WHERE company_id = @company_id
					   AND profit_ctr_id = @profit_ctr_id
					   AND salesforce_invoice_CSID = @salesforce_invoice_CSID) AND @FLAG <> 'E'
				
		Begin			
			Insert Into SFSWorkorderHeader
					(
					workorder_ID,
					description,
					revision,
					company_id,
					profit_ctr_ID,
					currency_code,
					cust_discount,
					salesforce_invoice_CSID,
					project_code,
					customer_id,
					billing_project_id,
					purchase_order,
					quote_ID,
					workorder_status,
					workorder_type_id,
					submitted_flag,
					generator_id,
					AX_Dimension_5_Part_1,
					AX_Dimension_5_Part_2,
					other_submit_required_flag,
					priced_flag,
					start_date,
					end_date,
					tracking_contact,
					tracking_id,
					urgency_flag,
					created_by,
					date_added,
					modified_by,
					date_modified,
					project_name,
					contact_id,
					invoice_comment_1,
					salesforce_so_csid)
					select
					@next_workorder_id,
					@description,
					@revision,
					@company_id,
					@profit_ctr_id,
					@currency_code,
					@cust_discount,
					@salesforce_invoice_CSID,
					@project_code,
					@customer_id,
					@billing_project_id,
					@Purchase_Order,
					@quote_id,
					@workrder_status,
					@workorder_type_id,
					@submitted_flag,
					@generator_id,
					@AX_Dimension_5_Part_1,
					@AX_Dimension_5_Part_2,
					@other_submit_required_flag,
					@priced_flag,
					@start_date,
					@end_date,
					@tracking_contact,
					@tracking_id,
					@urgency_flag,
					@user_code,
					GETDATE(),
					@user_code,
					GETDATE(),
					@project_name,
					@contact_id,
					@invoice_comment_1,
					case when @as_so_disposal_flag='T' Then @salesforce_invoice_CSID
					Else 
					Null
					End

					if @@error <> 0 						
					begin
					rollback transaction						
					Set @flag = 'E'	
					SELECT @Response = 'Error: Integration failed due to the following reason; could not insert into SFSWorkorderHeader table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
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


                    select @sfs_workorderheader_uid = @@IDENTITY

					SELECT @ll_count_rec = count(*) from SFSworkorderheader 
													WHERE sfs_workorderheader_uid = @sfs_workorderheader_uid
													AND salesforce_invoice_CSID=@salesforce_invoice_CSID

					IF @ll_count_rec = 1 
					Begin
						UPDATE ProfitCenter 
						SET next_workorder_id = @TEMP_ID 
						WHERE profit_ctr_id = @profit_ctr_id
						AND company_id = @company_id

						if @@error <> 0 						
						begin
						rollback transaction						
						Set @flag = 'E'	
						SELECT @Response = 'Error: Integration failed due to the following reason; could not update ProfitCenter table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
   								INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   																	SELECT
   																	@key_value,
   																	@source_system,
    																'Update',
    																@Response,
    																GETDATE(),
   																	@user_code
							return -1
						end  

						insert SFSWorkOrderStop (sfs_workorderheader_uid,
                                    workorder_id,
									company_id,
									profit_ctr_id,
									stop_sequence_id,
									est_time_amt,
									est_time_unit,
									decline_id,
									added_by,
									date_added,
									modified_by,
									date_modified
									)
									values (@sfs_workorderheader_uid,
									@next_workorder_id,
									@company_id,
									@profit_ctr_id,
									1,
									1,
									'D',
									1,
									@user_code,
									GETDATE(),
									@user_code,
									GETDATE()
									)

									if @@error <> 0 						
									begin
									rollback transaction						
									Set @flag = 'E'	
									SELECT @Response = 'Error: Integration failed due to the following reason; could not update SFSWorkOrderStop table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
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




									INSERT INTO SFSWorkOrderTracking
									(sfs_workorderheader_uid,
                                    COMPANY_ID,
									profit_ctr_id,
									workorder_id,
									tracking_id,
									tracking_status,
									tracking_contact,
									department_id,
									time_in,
									time_out,
									comment,
									business_minutes,
									added_by,
									date_added,
									modified_by,
									date_modified)
									values
									(@sfs_workorderheader_uid,
                                    @company_id,
									@profit_ctr_id,
									@next_workorder_id,
									1,
									'NEW',
									@user_code,
									15,
									GETDATE(),
									GETDATE(),
									NULL,
									NULL,
									@user_code,
									GETDATE(),
									@user_code,
									GETDATE()
									)

									if @@error <> 0 						
									begin
									rollback transaction						
									Set @flag = 'E'	
									SELECT @Response = 'Error: Integration failed due to the following reason; could not update SFSWorkOrderTracking table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
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

									insert into SFSworkorderaudit (sfs_workorderheader_uid,
                                                    company_id,
													profit_ctr_id,
													workorder_id,
													resource_type,
													sequence_id,table_name,
													column_name,
													before_value,
													after_value,
													audit_reference,
													modified_by,
													date_modified)
											values (@sfs_workorderheader_uid,
                                                    @company_id,
													@profit_ctr_id,
													@next_workorder_id,
													'',
													0,
													'WorkorderHeader',
													'ALL',
													'(no record)',
													'(new record added)',
													'',
													@user_code,
													getdate())


									if @@error <> 0 						
									begin
									rollback transaction						
									Set @flag = 'E'	
									SELECT @Response = 'Error: Integration failed due to the following reason; could not update SFSworkorderaudit table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
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

                    
								insert into SFSworkorderaudit(sfs_workorderheader_uid,
                                                    company_id,
												   profit_ctr_id,
												   workorder_id,
												   resource_type,
												   sequence_id,
												   table_name,
												   column_name,
												   before_value,
												   after_value,
												   audit_reference,
												   modified_by,
												   date_modified)
											values (@sfs_workorderheader_uid,
                                                    @company_id,
													@profit_ctr_id,
													@next_workorder_id,
													'',
													0,
													'WorkorderHeader',
													'ALL',
													'(no record)',
													'(new record added)',
													'This record was created from Salesforce Integration.Salesforce Sales Order: ' +isnull(@project_code,''),
													@user_code,
													getdate())


								if @@error <> 0 						
								begin
								rollback transaction						
								Set @flag = 'E'	
								SELECT @Response = 'Error: Integration failed due to the following reason; could not update SFSworkorderaudit table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
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
                End				
		
			 
			 --Generator creation / update based on the SF request
			  IF @as_site_changed ='T' AND @Flag <> 'E' and @as_gen_update ='T'
			  Begin
			  
				   EXEC @ll_ret= dbo.sp_Sfdc_sitechange_generatoraudit 
							@generator_id,@salesforce_site_csid,@gen_status,@generator_name,@generator_address_1,@generator_address_2,@generator_address_3,
							@generator_address_4,@generator_address_5,@generator_city,@generator_state,@generator_zip_code,@generator_county,
							@generator_country,@generator_phone,@generator_fax,@gen_mail_name,@gen_mail_addr1,@gen_mail_addr2,@gen_mail_addr3,
							@gen_mail_addr4,@gen_mail_addr5,@gen_mail_city,@gen_mail_state,@gen_mail_zip_code,@gen_mail_country,@NAICS_code,@user_code  
					 If @ll_ret < 0 						
						begin
							rollback transaction						
							Set @flag = 'E'	
							SELECT @Response = 'Error: Integration failed due to the following reason; could not update Generator/ Insert Generator Audit table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
   									INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   																				SELECT 
																				@key_value,
																				@source_system,
    																				Case when @ll_ret=-1 Then 'Generator-Update'
																					 When @ll_ret=-2 Then 'Generator Audit-Insert'
																				End,
    																				@Response,
    																				GETDATE(),
   																				@user_code
							return -1
						End  
				 END

				 IF @as_site_changed ='T' AND @Flag <> 'E' and @as_gen_insert ='T' 			
				 Begin 	

						EXEC @ll_ret= dbo.sp_sfdc_generator_insert @salesforce_site_csid,'N/A',@generator_id,@gen_status,@generator_name ,@generator_address_1,@generator_address_2,@generator_address_3,
						@generator_address_4,@generator_address_5,@generator_city,@generator_state,@generator_zip_code,@generator_county,@generator_country,@generator_phone,@generator_fax,
						@gen_mail_name,@gen_mail_addr1,@gen_mail_addr2,@gen_mail_addr3,@gen_mail_addr4,@gen_mail_addr5,@gen_mail_city,@gen_mail_state,@gen_mail_zip_code,
						@gen_mail_country,@NAICS_code,@user_code,@Generator_result output    
			
			
						If @ll_ret = 0
						Begin
						EXEC @ll_ret=dbo.sp_sfdc_generatoraudit_insert 'N/A',@generator_id,@gen_status,@generator_name,@generator_address_1,@generator_address_2,@generator_address_3,
										@generator_address_4,@generator_address_5,@generator_city,@generator_state,@generator_zip_code,@generator_county,@generator_country,@generator_phone,@generator_fax,
										@gen_mail_name,@gen_mail_addr1,@gen_mail_addr2,@gen_mail_addr3,@gen_mail_addr4,@gen_mail_addr5,@gen_mail_city,@gen_mail_state,@gen_mail_zip_code,
										@gen_mail_country,@NAICS_code,@user_code
						End
		
	        
					If @ll_ret < 0 
						Begin
						Rollback Transaction
						Set @response = 'Error: Integration failed due to the following reason; New Generator creation failed due to' + isnull(@Generator_result,'For more details please check Source_Error_Log table in EQAI;') 			
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
			
	  IF @response = 'Integration Successful' AND @FLAG <> 'E' AND upper(@JSON_DATA) <> 'LIST' AND @JSON_DATA is not null
		Begin
			EXEC @ll_ret = sp_sfdc_workorder_json_note_insert @next_workorder_id,
												   @company_id,
												   @profit_ctr_id,
												   @JSON_DATA,
												   @Notes_subject,
												   @source_system,
												   @user_code

			If @ll_ret < 0 
			Begin
				Rollback Transaction
				Set @response = 'Error: Integration failed due to the following reason; Note Insert failed for workorderdetail. For more details please check Source_Error_Log table in EQAI for NOTE insert action.'							
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
 End
 --------------------
--COMMIT TRANSACTION
--------------------
commit transaction	
End
If @ls_config_value='F'
	Begin
		select @response = 'SFDC Data Integration Failed,since CRM Go live flag off. Hence Store procedure will not execute.'
		Return -1
	End

Return 0




GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorderheader_Insert] TO EQAI  

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorderheader_Insert] TO svc_CORAppUser
