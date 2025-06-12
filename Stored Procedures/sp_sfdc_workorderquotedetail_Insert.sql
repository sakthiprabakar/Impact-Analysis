USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_workorderquotedetail_Insert]    Script Date: 6/12/2024 9:55:25 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE  PROCEDURE [dbo].[sp_sfdc_workorderquotedetail_Insert] 
						 @project_code varchar(15)=Null,
						 @Company_id smallint,
						 @profit_ctr_id smallint,						 
						 @resource_type char(1)=Null,
						 @service_desc varchar(100)=Null,
						 @quantity_dt float,
						 @price_dt money,
						 @cost money,
						 @quantity_ot float,
						 @price_ot money,
						 @quantity_std float,
						 @group_code varchar(10)=Null,	 
						 @resource_item_code varchar(10)=Null,
						 @resource_item_type char(1)=Null,
						 @quantity float,
						 @bill_unit_code varchar(4)=Null,
						 @price float,
						 @salesforce_Contract_Line varchar(25)=Null, 
						 @salesforce_so_quote_line_id varchar(80)=Null,
						 @record_type char(1) = 'P',
						 @currency_code char(3) = 'USD',
						 @salesforce_cost_markup_type varchar(10)=Null,
						 @salesforce_cost_markup_amount money,
						 @salesforce_bundle_id varchar(10)=Null,
						 @salesforce_task_name varchar(80)=Null,
						 @salesforce_task_CSID varchar(18)=Null,						 
						 @salesforce_resourceclass_CSID varchar(18) null,
						 @FLAG CHAR(1) = 'I',
						 @JSON_DATA NVARCHAR(MAX),
						 @source_system varchar(100)='Sales Force',
						 @employee_id varchar(20)=Null,
						 @Response nvarchar(max) OUT
/*	
	Description: Data Integarattion between SFDC and EQAI for the table  workorderquotedetail
	Action - Insert/Updates/Delte If any of these action performed in the SFDC for the Quote lines then 
	         respective data should pushed to workorderquotedetail table in EQAI

03/30/2023	Venu  R  Created  Devops# 63173
04/13/2023  Venu  R  Modified Devops #64257  JSON raw data flag added
05/08/2023  Venu  R  Modified Devops #65188  Quote line ID added
05/18/2023  Venu  R  Modfied for Devops #65533 Additional Integration fields 
07/10/2023  Venu  R  Modified for Devops# 67064 Addtional Integration fields and CRM go live flag added in configration table.
08/04/2023  Venu  R Modified for Devops# 70127 bundle ID number added 
10/06/2023  Nagaraj M Modified Stored procedure for Devops#73735 to add the "@salesforce_task_name", "@salesforce_task_CSID"
Devops# 74469 - 11/14/2023 Nagaraj Replaced the @salseforce_so_quote_id input parm to @project_code, salseforce_so_quote_id input is no longer required in this stored procedure, 
however we need to store it into table
Devops# 76450 and 76452 - 01/03/2024 Venu Modified the Procedure - Implement the validation for all the required fields,resource class check and modified the procedure name.
Devops# 77454 --01/31/2024 Venu - Modified for the erorr handling messgae text change
Devops# 81419 --03/19/2024 Venu - Populate the user_code to added_by and modified_by fields
Devops# 87468  fix deployment script review comments by Venu
Devops# 83361 - 04/29/2024 Rob - Populate Salesforce staging tables instead of actual EQAI tables (for fully transactional integration)
Devops# 87927 -- 05/20/2024 Venu Modified the error handling.
Devops# 89317 -- 06/04/2024 Nagaraj M Modified the service_desc varchar(60) field length to varchar(100)

*****Sample Execution************
Use plt_ai
Declare @result nvarchar(max);
EXEC dbo.sp_sfdc_workorderquotedetail_Insert
@project_code ='T-V224',
@company_id =21,
@profit_ctr_id =0,
@resource_type = 'L',
@service_desc='Bundle',
@quantity_dt =1,
@price_dt =1540.10,
@cost =1290.10,
@quantity_ot =2,
@price_ot=1740.10,
@quantity_std =1,
@group_code ='ROTRLROP',
@resource_item_code ='JAN5TEST01',
@resource_item_type ='C',
@quantity=1,
@bill_unit_code='2Y',
@price=10,
@salesforce_Contract_Line='Test',
@salesforce_so_quote_line_id='ID1-Test2',
@record_type='P',
@currency_code='USD',
@salesforce_cost_markup_type ='Test',
@salesforce_cost_markup_amount=189.90,
@salesforce_bundle_id='BL-101',
@salesforce_task_name ='NAGTEST',
@salesforce_task_CSID ='NAG001',
@salesforce_resourceclass_CSID='a1S8H0000003pU6UAI',
@FLAG ='I',  
@JSON_data='N[ {"id": 2, "info": {"name": "John", "surname": "Smith"}, "age": 25}, {"id": 5, "info": {"name": "Jane", "surname": "Smith"}, "dob": "2005-11-04T12:00:00"} ]',
@source_system = 'Sales Force',
@employee_id='VENU',
@response =@result output
print @result

*****End*******

*/			
AS 
SET NOCOUNT ON;
Declare 
		@key_value nvarchar(2000),
		@action varchar(100),
		@Quote_id_ret int,		
		@len_response int,
		@ll_count int,
		@newsequence_id int,
		@ll_count_rec int,
		@resource_class_cnt_hdr int,
		@resource_class_cnt_dtl int,
		@error_flag char(1) = 'N' ,
		@Notes_subject char(1)='D',
		@ls_config_value char(1) ='F',
		@validation_req_field varchar(100),
        @validation_req_field_value varchar(500),	    
		@validation_response varchar(1000),
	    @ll_validation_ret int,
		@ll_parent_bundle_cnt int,
		@so_quote_line_id_cnt int,
		@ll_ret int,
		@user_code varchar(10)='N/A',
		@sfs_workorderquoteheader_uid int

Set transaction isolation level read uncommitted

Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag'
    	
	IF @ls_config_value is null or @ls_config_value=''
	Begin
		Set @ls_config_value='F'
	End
    
If @ls_config_value='T'
BEGIN
Begin transaction			
        Set @source_system = 'sp_sfdc_workorderquotedetail_Insert:: ' + @source_system
		Set @Response='Integration Successful'
		Set @bill_unit_code = upper(@bill_unit_code)
		Set @resource_item_type = 'C'
		Set @FLAG = 'I'

		Create table #temp_salesforce_validation_fields (validation_req_field varchar(100),validation_req_field_value varchar(500))  /*To determine the validation requried field*/
		Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
		                                                 ('company_id',str(@company_id)),
														 ('profit_ctr_id',str(@profit_ctr_id)),
														 ('project_code',@project_code),
		                                                 ('resource_type',@resource_type),
		                                                 ('resource_item_code',@resource_item_code),
														 ('bill_unit_code',@bill_unit_code),
														 ('salesforce_so_quote_line_id',@salesforce_so_quote_line_id),
														 ('currency_code',@currency_code),
														 ('salesforce_resourceclass_CSID',@salesforce_resourceclass_CSID),
														 ('employee_id',@employee_id)

        
		Set @key_value = 'company id;' + cast((convert(int,@company_id)) as varchar(20)) + 
							' profit_ctr_id;' + cast((convert(int,@profit_ctr_id)) as varchar(20))+		
							' Project code;' + isnull(@project_code,'') +
							' resource Type;' + isnull(@resource_type,'') + 
							' service Desc;' + isnull(@service_desc,'') +
							' quantity Dt;' + cast((convert(int,@quantity_dt)) as varchar(20))+				 
							' price_dt;' + cast((convert(money,@price_dt)) as varchar(20))+ 
							' cost;' + cast((convert(money,@cost)) as varchar(20)) +
							' quantity ot;' +cast((convert(int,@quantity_ot)) as varchar(20))+ 
							' price Ot;' +cast((convert(int,@price_ot)) as varchar(20))+ 
							' quantity std; ' + cast((convert(int,@quantity_std)) as varchar(20)) + 
							' group_code; '+isnull(@group_code,'')+  
							' resource_item_code;' +isnull(@resource_item_code,'') + 
							' resource_item_type;'+isnull(@resource_item_type,'')+
							' quantity;' +cast((convert(int,@quantity)) as varchar(20))+
							' bill_unit_code;' +isnull(@bill_unit_code,'')+ 
							' Price;'+cast((convert(int,@price)) as varchar(20)) +
							' SF_contract_line;' + isnull(@salesforce_Contract_Line,'') +
							' SF_so_quote_line_id;' + isnull(@salesforce_so_quote_line_id,'') +
							' salesforce_cost_markup_type;' + isnull(@salesforce_cost_markup_type,'') +
                            ' salesforce_cost_markup_amount;' +cast((convert(int,@salesforce_cost_markup_amount)) as varchar(20)) +
							' SF_bundle_id;' + isnull(@salesforce_bundle_id,'') +							
							' SF_so_quote_line_id;'+ isnull(@salesforce_so_quote_line_id,'') + 
							' salesforce_task_name;' +isnull(@salesforce_task_name,'')+ 
							' salesforce_task_CSID;' +isnull(@salesforce_task_CSID,'')+
							' salesforce_resourceclass_CSID;' +isnull(@salesforce_resourceclass_CSID,'')+
							' employee_id;' +isnull(@employee_id,'')		
   		
		If @JSON_DATA is null Or @JSON_DATA=''
		Begin
			Set @response = 'Error: Integration failed due to the following reason;Received JSON data string empty/null'		         
			Set @flag = 'E'		
		End

		Declare sf_validation CURSOR for
			select validation_req_field,validation_req_field_value from #temp_salesforce_validation_fields
			Open sf_validation
				fetch next from sf_validation into @validation_req_field,@validation_req_field_value		
				While @@fetch_status=0
				Begin
				  
				   EXEC @ll_validation_ret=dbo.sp_sfdc_input_parm_validation 'sp_sfdc_workorderquotedetail_insert',@validation_req_field,@validation_req_field_value,@company_id,@profit_ctr_id,@validation_response output
				   
				   If @validation_req_field='employee_id' and @ll_validation_ret <> -1
					Begin
					EXEC dbo.sp_sfdc_get_usercode @employee_id,@user_code output     
					End

				   If @ll_validation_ret = -1
				   Begin 
						 If @Response = 'Integration Successful'
						 Begin
							Set @Response ='Error: Integration failed for the quote SO line ID:' + isnull(@salesforce_so_quote_line_id,'N/A') + ' due to the following reason;'							
						 End
						 Set @Response = @Response + @validation_response+ ';'
						 Set @flag = 'E'
									 
				   End
				fetch next from sf_validation into @validation_req_field,@validation_req_field_value   
			   End		
		   Close sf_validation
		DEALLOCATE sf_validation 	      
		Drop table #temp_salesforce_validation_fields
		
        select @sfs_workorderquoteheader_uid = max(sfs_workorderquoteheader_uid)
        from SFSWorkOrderQuoteHeader
        where salesforce_so_quote_id = @project_code

		Select @Quote_id_ret = quote_id from dbo.SFSworkorderquoteheader where sfs_workorderquoteheader_uid = @sfs_workorderquoteheader_uid
		
		If @salesforce_so_quote_line_id is not null and @salesforce_so_quote_line_id <> ''
		Begin
			Select @so_quote_line_id_cnt =count(*) from SFSWorkOrderQuotedetail  where sfs_workorderquoteheader_uid = @sfs_workorderquoteheader_uid and 
																					salesforce_so_quote_line_id=@salesforce_so_quote_line_id and 
																					company_id=@company_id and 
																					profit_ctr_id=@profit_ctr_id
			Begin 
				If @so_quote_line_id_cnt > 0 and @Response = 'Integration Successful'
				Begin
					    
					Set @Response ='Error: Integration failed due to the following reason; SO line ID:'+isnull(@salesforce_so_quote_line_id,'N/A')+ 'already exists in workorderquotedetail table for the received quote id,company id and profit ctr id.' + isnull(str(@Quote_id_ret),'N/A') +','+ isnull(str(@company_id),'N/A') +','+ isnull(str(@profit_ctr_id),'N/A')+';'
					Set @flag='E' 
				End
				Else 
				If @so_quote_line_id_cnt > 0 and @Response <> 'Integration Successful'
				Begin
					Set @Response = @Response +'SO line ID:'+isnull(@salesforce_so_quote_line_id,'N/A')+ 'already exists in workorderquotedetail table for the received quote id,company id and profit ctr id.' + isnull(str(@Quote_id_ret),'N/A') +','+ isnull(str(@company_id),'N/A') +','+ isnull(str(@profit_ctr_id),'N/A')+';' 
					Set @flag='E'   
				End	
		   End
        End  
		
		
		If ((trim(@salesforce_bundle_id) IS NOT NULL and trim(@salesforce_bundle_id) <> '')  AND @resource_type <> 'O') 
		Begin
			Select @ll_parent_bundle_cnt= count(*) from SFSWorkOrderQuoteDetail Where  sfs_workorderquoteheader_uid = @sfs_workorderquoteheader_uid and 
			                                                                        company_id=@Company_id and 
																					profit_ctr_id=@profit_ctr_id and 
																					salesforce_bundle_id=@salesforce_bundle_id and
																					resource_type ='O'
                Begin 
					If @ll_parent_bundle_cnt=0 and @Response = 'Integration Successful'
					Begin
					    
						Set @Response ='Error: Integration failed for the quote SO line ID:' + isnull(@salesforce_so_quote_line_id,'N/A') + ' due to the following reason; Bundle ID received as ' +isnull(@salesforce_bundle_id,'N/A')+ ' So before submitting a child bundle line, the parent bundle line must be in the workorderquotedetail table for the resource type OTHER;'
						Set @flag='E' 
					End
					Else 
					If @ll_parent_bundle_cnt=0 and @Response <> 'Integration Successful'
					Begin
						Set @Response = @Response +'Bundle ID received as ' +isnull(@salesforce_bundle_id,'N/A')+ ' So before submitting a child bundle line, the parent bundle line must be in the workorderquotedetail table for the resource type OTHER;'
						Set @flag='E'   
					End	
               End
           End

		If ((trim(@salesforce_bundle_id) IS NOT NULL and trim(@salesforce_bundle_id) <> '') AND @price > 0 AND @resource_type <> 'O') 
		Begin		
		        Begin
					If @Response = 'Integration Successful'
					Begin
						 Set @Response ='Error: Integration failed for the quote SO line ID:' + isnull(@salesforce_so_quote_line_id,'N/A') + ' due to the following reason; Bundle ID received as ' +isnull(@salesforce_bundle_id,'N/A')+ ' child bundle Quote line price should not be grater than $0;'
						 Set @flag='E' 
					End
					Else
					Begin
						Set @Response = @Response  +'Bundle ID received as ' +isnull(@salesforce_bundle_id,'N/A')+ ' child bundle Quote line price should not be grater than $0;'
						Set @flag='E'   
					End	
				End
		 End
				
		If ((trim(@salesforce_resourceclass_CSID) IS NOT NULL and trim(@salesforce_resourceclass_CSID) <> '') and (trim(@resource_item_code) IS NOT NULL and trim(@resource_item_code) <> ''))
		Begin				
			select  @resource_class_cnt_hdr= count(*) from resourceclassheader where resource_class_code=@resource_item_code and 
																					 resource_type=@resource_type and 
																					 status='A' and 
																					 salesforce_resourceclass_csid=@salesforce_resourceclass_csid
			select  @resource_class_cnt_dtl= count(*) from resourceclassdetail where resource_class_code=@resource_item_code and 
																					 company_id=@company_id and 
																					 profit_ctr_id = @profit_ctr_id and
																					 bill_unit_code=@bill_unit_code and
																					 status='A'
			If 	@resource_class_cnt_hdr = 0 Or @resource_class_cnt_dtl=0 
			Begin 				
				If @Response = 'Integration Successful'
				Begin
					Set @Response ='Error: Integration failed for the quote SO line ID:' + isnull(@salesforce_so_quote_line_id,'N/A') + '  due to the following reason; Resource class code:' + isnull(@resource_item_code,'N/A') + ' is not exist in EQAI resourceclassheader or resourceclassdetail table for the respective company,profit center,bill unit and resource type;'
					Set @flag='E' 
				End
				Else
				Begin
					Set @Response = @Response +'Resource class code:' + isnull(@resource_item_code,'N/A') + ' is not exist in EQAI resourceclassheader or resourceclassdetail table for the respective company,profit center,bill unit and resource type;'
					Set @flag='E'   
				End 				
			End
		End

        /*Resourcexresourceclass table validation pending, since Rob yet to recevie the response from SF team
		Also, in quote level we don't want to validate the resource and not to map as well, However we need to confirm with BAs*/
		
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
        commit transaction      
		Return -1								
		End

	
		Begin		
		If @Flag ='I' AND NOT EXISTS (SELECT * FROM WorkOrderQuotedetail  WHERE quote_id = @Quote_id_ret and salesforce_so_quote_line_id=@salesforce_so_quote_line_id and 
			                                                                          company_id=@company_id and profit_ctr_id=@profit_ctr_id)
				  Begin
				   Select @newsequence_id =  COALESCE(max(sequence_id),0) + 1 from SFSWorkOrderQuotedetail where sfs_workorderquoteheader_uid = @sfs_workorderquoteheader_uid and company_id=@company_id and profit_ctr_id=@profit_ctr_id and resource_type=@resource_type
				 
				  		     Insert into dbo.SFSworkorderquotedetail
										  (sfs_workorderquoteheader_uid,
                                          Quote_id,
										   sequence_id,
										   resource_type,							 
										   service_desc,
										   quantity_dt,
										   price_dt,
										   cost,
										   quantity_ot,
										   price_ot,
										   quantity_std,
										   group_code,							 
										   resource_item_code,
										   resource_item_type,
										   quantity,
										   bill_unit_code,
										   price,
										   salesforce_Contract_Line,
										   company_id,
										   profit_ctr_id,	
										   record_type,
										   currency_code,
										   salesforce_cost_markup_type ,
										   salesforce_cost_markup_amount,										  
										   added_by,
										   date_added, 
										   modified_by,
										   date_modified, 	
										   salesforce_date_modified,
										   salesforce_so_quote_line_id,
										   salesforce_bundle_id,
										   salesforce_task_name,
										   salesforce_task_CSID)
								   Values 
										(@sfs_workorderquoteheader_uid,
                                        @Quote_id_ret,
										 @newsequence_id,
										 @resource_type,							 
										 @service_desc,
										 @quantity_dt,
										 @price_dt,
										 @cost,
										 @quantity_ot,
										 @price_ot,
										 @quantity_std,
										 @group_code,							 
										 @resource_item_code,
										 @resource_item_type,
										 @quantity,
										 @bill_unit_code,
										 @price,
										 @salesforce_Contract_Line,
										 @company_id,
										 @profit_ctr_id,
										 @record_type,
										 @currency_code,
										 @salesforce_cost_markup_type,
										 @salesforce_cost_markup_amount,										 
										 @user_code,																				 
										 getdate(), 
										 @user_code,
										 getdate(), 	
										 getdate(),
										 @salesforce_so_quote_line_id,
										 @salesforce_bundle_id,
										 @salesforce_task_name,
										 @salesforce_task_CSID)   
										 
							   if @@error <> 0 						
							   begin
								rollback transaction						
								Set @flag = 'E'	
								SELECT @Response = 'Error: Integration failed due to the following reason; could not insert into SFSworkorderquotedetail table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
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
			  If @Flag ='I'
			   Begin
				   Set @flag = 'E'
				   Set @Response= 'Error: Integration failed due to the following reason; SO line ID:'+isnull(@salesforce_so_quote_line_id,'N/A')+ 'already exists in workorderquotedetail table for the received quote id,company id and profit ctr id' + isnull(str(@Quote_id_ret),'N/A') +','+ isnull(str(@company_id),'N/A') +','+ isnull(str(@profit_ctr_id),'N/A') +';'
												 
					INSERT INTO PLT_AI_AUDIT..Source_Error_Log (input_params,source_system_details,action,Error_description,log_date,Added_by)
											SELECT @key_value,@source_system,
											'Insert',
											@Response,
											GETDATE(),
											@user_code
					commit transaction
					Return -1		
				End
		   End			   
				   
   	
	IF @Response = 'Integration Successful' AND @Flag <> 'E' AND @error_flag = 'N' AND upper(@JSON_DATA) <> 'LIST' AND @JSON_DATA is not null	
		Begin
		 EXEC @ll_ret =  sp_sfdc_quote_json_note_insert @Quote_id_ret,@company_id,@profit_ctr_id,@JSON_DATA,@Notes_subject,@source_system,@user_code

					If @ll_ret < 0 
					Begin
						Rollback Transaction
						Set @response = 'Error: Integration failed due to the following reason; Note Insert failed for workorderquotedetail. For more details please check Source_Error_Log table in EQAI for NOTE insert action.'			
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
   Select @Response= 'SFDC Data Integration Failed,since CRM Go live flag off. Hence Store procedure will not execute.'
   Return -1
End

Return 0

GO


GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorderquotedetail_Insert] TO EQAI  

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorderquotedetail_Insert] TO svc_CORAppUser