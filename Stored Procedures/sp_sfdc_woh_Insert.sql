USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_woh_Insert]    Script Date: 1/9/2025 9:10:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER Procedure [dbo].[sp_sfdc_woh_Insert] @response varchar(4000) OUTPUT,@workorder_id int Output
AS
DECLARE 
/*  
Description: 

Workorder header  insert (This procedure called from sp_sfdc_workorder_insert)
Created By Venu -- 18/Oct/2024
Rally # US129733  - New Design To handle the workorder in Single JSON
Rally # DE36112   - Update the AX_Dimension_5_Part_1 (D365 Project code) to EQAI
US#131404  - 01/09/2025 Venu added logic to create new generator when request came from salesforce
*/
@d365customer_id  Varchar(20),
@salesforce_invoice_CSID  Varchar(18),
@Purchase_Order  Varchar(20),
@project_code  Varchar(15),
@AX_Dimension_5_Part_1  Varchar(20),
@company_id  int,
@end_date  datetime ,
@generator_id  int,
@salesforce_site_csid  varchar(18),
@profit_ctr_id  int,
@start_date  datetime ,
@workorder_type_id  int,
@description  varchar(255),
@project_name  varchar(40),
@contact_id  int,
@employee_id  varchar(20),
@invoice_comment_1  varchar(80),
@generator_name  varchar(75),
@generator_address_1  varchar(85),
@generator_address_2  varchar(40),
@generator_address_3  varchar(40),
@generator_address_4  varchar(40),
@generator_address_5  varchar(40),
@generator_city  varchar(40),
@generator_state  varchar(2),
@generator_zip_code  varchar(15),
@generator_country  varchar(3),
@generator_phone  varchar(10),
@generator_fax  varchar(10),
@gen_mail_name  varchar(75),
@gen_mail_addr1  varchar(85),
@gen_mail_addr2  varchar(40),
@gen_mail_addr3  varchar(40),
@gen_mail_addr4  varchar(40),
@gen_mail_addr5  varchar(40),
@gen_mail_city  varchar(40),
@gen_mail_state  varchar(2),
@gen_mail_zip_code  varchar(15),
@gen_mail_country  varchar(3),
@NAICS_code  int,
@gen_status  char(1),
@as_site_changed  char(1),
@as_so_disposal_flag  char(1),
@billing_project_id  int=Null,
@new_design_flag char(1),
@quote_id int,	 
@revision int = 0,
@customer_id int,
@ll_ret int,
@customer_count int,	 
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
@next_workorder_id INT,
@TEMP_ID INT,
@generator_county int,
@user_code varchar(10)='N/A',
@Generator_result varchar(200),
@as_gen_insert CHAR(1)='F',
@as_gen_update CHAR(1)='F',
@ll_gen_cnt int,
@sfdc_billing_package_flag char(1)='F',
@source_system varchar(100)='Sales Force',
@salesforce_so_csid varchar(18),
@ll_wo_cnt int,
@as_woh_created char(1) ='F' ,
@ll_quote_cnt int=0
	 	 	
Begin
           
Set @response = 'WorkorderHeader Integration Successful'


Select 
@d365customer_id=D365CustomerId,
@salesforce_invoice_CSID=SalesforceInvoiceCSID,
@Purchase_Order=PurchaseOrder,
@project_code=ProjectCode,
@AX_Dimension_5_Part_1=AXDimension5Part1,
@company_id=CompanyId,
@end_date=EndDate,
@generator_id=GeneratorId,
@salesforce_site_csid=SalesforceSiteCSID,
@profit_ctr_id=ProfitCenterId,
@start_date=StartDate,
@workorder_type_id=WorkOrderTypeId,
@description=Description,
@project_name=ProjectName,
@contact_id=ContactId,
@employee_id=Employee_Id,
@invoice_comment_1=InvoiceComment_1,
@generator_name=GeneratorName,
@generator_address_1=GeneratorAddress1,
@generator_address_2=GeneratorAddress2,
@generator_address_3=GeneratorAddress3,
@generator_address_4=GeneratorAddress4,
@generator_address_5=GeneratorAddress5,
@generator_city=GeneratorCity,
@generator_state=GeneratorState,
@generator_zip_code=GeneratorZipCode,
@generator_country=GeneratorCountry,
@generator_phone=GeneratorPhone,
@generator_fax=GeneratorFax,
@gen_mail_name=GenMailName,
@gen_mail_addr1=GenMailAddress1,
@gen_mail_addr2=GenMailAddress2,
@gen_mail_addr3=GenMailAddress3,
@gen_mail_addr4=GenMailAddress4,
@gen_mail_addr5=GenMailAddress5,
@gen_mail_city=GenMailCity,
@gen_mail_state=GenMailState,
@gen_mail_zip_code=GenMailZipCode,
@gen_mail_country=GenMailCountry,
@NAICS_code=NAICScode,
@gen_status=GeneratorStatus,
@as_site_changed=AsSiteChanged,
@as_so_disposal_flag=AsSoDisposalFlag,
@billing_project_id=BillingProjectId,
@salesforce_so_csid=SalesforceSoCsid
From #sf_header


If @as_so_disposal_flag='T' and @salesforce_so_csid is not null
Begin

Select @ll_wo_cnt = count(*) from WorkorderHeader where company_id=@company_id
                                                        and profit_ctr_ID=@profit_ctr_id
														and salesforce_invoice_CSID=@salesforce_so_csid
														and salesforce_so_CSID=@salesforce_so_csid
If @ll_wo_cnt > 0
Begin

--Set @response = 'Information:WorkorderHeader Integration not required, since workorder already integrated during sales order creation, since sales order having disposal line'


--Generator Creation logic added by Venu --Start

		If (@salesforce_site_csid IS NOT NULL and @salesforce_site_csid <> '' and (@generator_id is null or @generator_id = '' or @generator_id=0 ))
		Begin	
			
			select @ll_gen_cnt = count(*) from generator Where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS=@salesforce_site_csid and status='A'
          		
			If @ll_gen_cnt = 1 
			Begin
			  select  @generator_id= generator_id from generator where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS=@salesforce_site_csid and status='A'  
			End						              
		End 

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


		--Generator creation / update based on the SF request
			  IF @as_site_changed ='T' AND @as_gen_update ='T'
			  Begin
			       begin try
				   EXEC @ll_ret= dbo.sp_Sfdc_sitechange_generatoraudit 
							@generator_id,@salesforce_site_csid,@gen_status,@generator_name,@generator_address_1,@generator_address_2,@generator_address_3,
							@generator_address_4,@generator_address_5,@generator_city,@generator_state,@generator_zip_code,@generator_county,
							@generator_country,@generator_phone,@generator_fax,@gen_mail_name,@gen_mail_addr1,@gen_mail_addr2,@gen_mail_addr3,
							@gen_mail_addr4,@gen_mail_addr5,@gen_mail_city,@gen_mail_state,@gen_mail_zip_code,@gen_mail_country,@NAICS_code,@user_code  
                   end try
				   begin catch
				    Print @@ERROR
				   end catch
					 If @ll_ret < 0 or  @@ERROR <> 0						
						begin							
							Set @Response = 'Error: Integration failed due to the following reason; could not update Generator/ Insert Generator Audit table;' + isnull(ERROR_MESSAGE(),'')
   							return -1
						End  
			   End

				 IF @as_site_changed ='T' AND  @as_gen_insert ='T' 			
				 Begin 	

						EXEC @ll_ret= dbo.sp_sfdc_generator_insert @salesforce_site_csid,'N/A',@generator_id,@gen_status,@generator_name ,@generator_address_1,@generator_address_2,@generator_address_3,
						@generator_address_4,@generator_address_5,@generator_city,@generator_state,@generator_zip_code,@generator_county,@generator_country,@generator_phone,@generator_fax,
						@gen_mail_name,@gen_mail_addr1,@gen_mail_addr2,@gen_mail_addr3,@gen_mail_addr4,@gen_mail_addr5,@gen_mail_city,@gen_mail_state,@gen_mail_zip_code,
						@gen_mail_country,@NAICS_code,@user_code,@Generator_result output    
			
			
						If @ll_ret = 0 or  @@ERROR <> 0
						Begin
						EXEC @ll_ret=dbo.sp_sfdc_generatoraudit_insert 'N/A',@generator_id,@gen_status,@generator_name,@generator_address_1,@generator_address_2,@generator_address_3,
										@generator_address_4,@generator_address_5,@generator_city,@generator_state,@generator_zip_code,@generator_county,@generator_country,@generator_phone,@generator_fax,
										@gen_mail_name,@gen_mail_addr1,@gen_mail_addr2,@gen_mail_addr3,@gen_mail_addr4,@gen_mail_addr5,@gen_mail_city,@gen_mail_state,@gen_mail_zip_code,
										@gen_mail_country,@NAICS_code,@user_code
						End
		
	        
					If @ll_ret < 0 or @@ERROR <> 0
						Begin						
						  Set @response = 'Error: Integration failed due to the following reason; New Generator creation failed due to' + isnull(@Generator_result,' ') 			
						  return -1
						End			 
					End
--Generator Creation logic added by Venu --End

Update WorkorderHeader set salesforce_invoice_CSID=@salesforce_invoice_CSID,AX_Dimension_5_Part_1=@AX_Dimension_5_Part_1,date_modified=getdate(),generator_id=@generator_id
                                                                                  where company_id=@company_id
                                                                                  and profit_ctr_ID=@profit_ctr_id
																				  and salesforce_invoice_CSID=@salesforce_so_csid
																				  and salesforce_so_CSID=@salesforce_so_csid

	  

		   
Set @response = 'WorkorderHeader Integration Successful (SO CSID updated with actual invoice CSID)' 

Select @workorder_id = workorder_id from WorkorderHeader where company_id=@company_id
															   and profit_ctr_ID=@profit_ctr_id
															   and salesforce_invoice_CSID=@salesforce_invoice_CSID
															   and salesforce_so_CSID=@salesforce_so_csid


Return 1
End
End

select @ll_quote_cnt=count(*) from WorkOrderQuoteHeader where project_code=@project_code AND company_id=@company_id AND profit_ctr_id = @profit_ctr_id	
If @ll_quote_cnt=0
Begin
	select @quote_id=quote_id from sfsWorkOrderQuoteHeader where project_code=@project_code AND company_id=@company_id AND profit_ctr_id = @profit_ctr_id	
End
If @ll_quote_cnt > 0
Begin
	select @quote_id=quote_id from WorkOrderQuoteHeader where project_code=@project_code AND company_id=@company_id AND profit_ctr_id = @profit_ctr_id	
End



select @customer_id=customer_id,@sfdc_billing_package_flag=sfdc_billing_package_flag  from Customer where ax_customer_id=@d365customer_id and cust_status='A'

	If @sfdc_billing_package_flag is null or @sfdc_billing_package_flag=''
	  Set @sfdc_billing_package_flag ='F'

	If len (@employee_id) > 0 
	Begin
		EXEC dbo.sp_sfdc_get_usercode @employee_id,@user_code output 
	End


-- Workorder id generation starts	
		   
select @next_workorder_id=next_workorder_id from ProfitCenter where profit_ctr_id = @profit_ctr_id and company_id = @company_id
				
IF @next_workorder_id ='' OR  @next_workorder_id IS NULL 
Begin
	Set @next_workorder_id = 2
	Set @TEMP_ID = 1 * 100
End
Else
Begin
	Set @TEMP_ID=@next_workorder_id +1
	Set @next_workorder_id = @next_workorder_id * 100
End

Set @workorder_id=@next_workorder_id

If (@billing_project_id is null or @billing_project_id='') and @sfdc_billing_package_flag='F' and @as_so_disposal_flag='F'
	Begin
		select top 1 @billing_project_id = billing_project_id from customerbilling where customer_id=@customer_id and salesforce_jobbillingproject_csid='0' -- To get the SF standard
	End

If (@billing_project_id is null or @billing_project_id='') and @sfdc_billing_package_flag='F' and @as_so_disposal_flag='F'
	Begin
		Set @billing_project_id=0
	End




If (@salesforce_site_csid IS NOT NULL and @salesforce_site_csid <> '') and @as_site_changed='T'
	Begin

		Select @ll_gen_cnt = count(*) from generator where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS=@salesforce_site_csid and status='A' 
		Select  @generator_county=county_code from zipcodes where  zipcode=@generator_zip_code 

		If @ll_gen_cnt = 0
		Begin
			EXECUTE @generator_id = dbo.sp_sequence_next 'Generator.generator_id'
			SET @as_gen_insert='T'
		End

		If @ll_gen_cnt > 0
		Begin
			Select @generator_id =generator_id from  generator where salesforce_site_csid collate SQL_Latin1_General_CP1_CS_AS=@salesforce_site_csid and status='A'			
			SET @as_gen_update='T'
		End
	End

	If (@salesforce_site_csid IS NULL Or  @salesforce_site_csid = '') and @as_site_changed='T' and (@generator_id is not null and @generator_id <> '' and @generator_id <> 0 )  --Added venu generator condition
	Begin
		SET @as_gen_update='T'
    End
		
	If NOT EXISTS (SELECT * FROM WorkOrderHeader with(nolock) WHERE company_id = @company_id
															AND profit_ctr_id = @profit_ctr_id
															AND salesforce_invoice_CSID = @salesforce_invoice_CSID) 				
		Begin	
		    Set @as_woh_created='T'

			Insert Into WorkorderHeader    (workorder_ID,
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
											@salesforce_so_csid

											if @@error <> 0 						
											begin											
												Set @Response = 'Error: Integration failed due to the following reason; could not insert into SFSWorkorderHeader table;' + isnull(ERROR_MESSAGE(),'')
   												return -1
											end             
              
                insert WorkOrderStop (workorder_id,
									company_id,
									profit_ctr_id,
									stop_sequence_id,
									est_time_amt,
									est_time_unit,
									decline_id,
									added_by,
									date_added,
									modified_by,
									date_modified)
									Select 
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
									

									if @@error <> 0 						
									begin
									  Set @Response = 'Error: Integration failed due to the following reason; could not update SFSWorkOrderStop table;' + isnull(ERROR_MESSAGE(),'')
   									   return -1
									end  
				 			 

					INSERT INTO WorkOrderTracking  (COMPANY_ID,
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
											Select
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
									

											if @@error <> 0 						
											begin									
											SELECT @Response = 'Error: Integration failed due to the following reason; could not update SFSWorkOrderTracking table;' + isnull(ERROR_MESSAGE(),'')
   												return -1
											end 


							 insert into workorderaudit (
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
											        Select 
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
													getdate()


									if @@error <> 0 						
									begin									
										Set @Response = 'Error: Integration failed due to the following reason; could not update SFSworkorderaudit table;' + isnull(ERROR_MESSAGE(),'')
   										return -1
									end 

					     

						 insert into workorderaudit(
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
											       Select
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
													getdate()


								if @@error <> 0 						
								begin								
								 Set @Response = 'Error: Integration failed due to the following reason; could not update SFSworkorderaudit table;' + isnull(ERROR_MESSAGE(),'')
   								 return -1
								end


						UPDATE ProfitCenter SET next_workorder_id = @TEMP_ID WHERE profit_ctr_id = @profit_ctr_id AND company_id = @company_id

						if @@error <> 0 						
						begin						
						Set @Response = 'Error: Integration failed due to the following reason; could not update ProfitCenter table;' + isnull(ERROR_MESSAGE(),'')   								
							return -1
						end  									
		
			 
			 --Generator creation / update based on the SF request
			  IF @as_site_changed ='T' AND @as_gen_update ='T'
			  Begin
			       begin try
				   EXEC @ll_ret= dbo.sp_Sfdc_sitechange_generatoraudit 
							@generator_id,@salesforce_site_csid,@gen_status,@generator_name,@generator_address_1,@generator_address_2,@generator_address_3,
							@generator_address_4,@generator_address_5,@generator_city,@generator_state,@generator_zip_code,@generator_county,
							@generator_country,@generator_phone,@generator_fax,@gen_mail_name,@gen_mail_addr1,@gen_mail_addr2,@gen_mail_addr3,
							@gen_mail_addr4,@gen_mail_addr5,@gen_mail_city,@gen_mail_state,@gen_mail_zip_code,@gen_mail_country,@NAICS_code,@user_code  
                   end try
				   begin catch
				    Print @@ERROR
				   end catch
					 If @ll_ret < 0 or  @@ERROR <> 0						
						begin							
							Set @Response = 'Error: Integration failed due to the following reason; could not update Generator/ Insert Generator Audit table;' + isnull(ERROR_MESSAGE(),'')
   							return -1
						End  
			   End

				 IF @as_site_changed ='T' AND  @as_gen_insert ='T' 			
				 Begin 	

						EXEC @ll_ret= dbo.sp_sfdc_generator_insert @salesforce_site_csid,'N/A',@generator_id,@gen_status,@generator_name ,@generator_address_1,@generator_address_2,@generator_address_3,
						@generator_address_4,@generator_address_5,@generator_city,@generator_state,@generator_zip_code,@generator_county,@generator_country,@generator_phone,@generator_fax,
						@gen_mail_name,@gen_mail_addr1,@gen_mail_addr2,@gen_mail_addr3,@gen_mail_addr4,@gen_mail_addr5,@gen_mail_city,@gen_mail_state,@gen_mail_zip_code,
						@gen_mail_country,@NAICS_code,@user_code,@Generator_result output    
			
			
						If @ll_ret = 0 or  @@ERROR <> 0
						Begin
						EXEC @ll_ret=dbo.sp_sfdc_generatoraudit_insert 'N/A',@generator_id,@gen_status,@generator_name,@generator_address_1,@generator_address_2,@generator_address_3,
										@generator_address_4,@generator_address_5,@generator_city,@generator_state,@generator_zip_code,@generator_county,@generator_country,@generator_phone,@generator_fax,
										@gen_mail_name,@gen_mail_addr1,@gen_mail_addr2,@gen_mail_addr3,@gen_mail_addr4,@gen_mail_addr5,@gen_mail_city,@gen_mail_state,@gen_mail_zip_code,
										@gen_mail_country,@NAICS_code,@user_code
						End
		
	        
					If @ll_ret < 0 or @@ERROR <> 0
						Begin						
						  Set @response = 'Error: Integration failed due to the following reason; New Generator creation failed due to' + isnull(@Generator_result,' ') 			
						  return -1
						End			 
					End
      End
	  If @as_woh_created <> 'T'
	  Begin
	     Set @response = 'Information:WorkorderHeader Integration not required, since workorder already integrated'
      End
 End

Return 0

Go


GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_woh_Insert] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_woh_Insert] TO svc_CORAppUser

GO

