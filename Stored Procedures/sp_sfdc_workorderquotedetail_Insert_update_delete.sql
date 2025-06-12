USE [PLT_AI]
GO

/****** Object:  StoredProcedure [dbo].[sp_sfdc_workorderquotedetail_Insert_update_delete]    Script Date: 4/14/2023 9:54:11 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_sfdc_workorderquotedetail_Insert_update_delete] 
						 @project_code varchar(15),
						 @Company_id smallint,
						 @profit_ctr_id smallint,						 
						 @resource_type char(1),
						 @service_desc varchar(60),
						 @quantity_dt float,
						 @price_dt money,
						 @cost money,
						 @quantity_ot float,
						 @price_ot money,
						 @quantity_std float,
						 @group_code varchar(10),	 
						 @resource_item_code varchar(10),
						 @resource_item_type char(1),
						 @quantity float,
						 @bill_unit_code varchar(4),
						 @price float,
						 @salesforce_Contract_Line varchar(25), 
						 @salesforce_so_quote_line_id varchar(80),
						 @record_type char(1) = 'P',
						 @currency_code char(3) = 'USD',
						 @salesforce_cost_markup_type varchar(10),
						 @salesforce_cost_markup_amount money,
						 @salesforce_bundle_id varchar(10),
						 @salesforce_task_name varchar(80),
						 @salesforce_task_CSID varchar(18),
						 @FLAG CHAR(1),
						 @JSON_DATA NVARCHAR(MAX),
						 @source_system varchar(100)='Sales Force',
						 @Response varchar(200) OUT
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

*****Sample Execution************
Declare @result varchar(200);
EXEC dbo.sp_sfdc_workorderquotedetail_Insert_update_delete
@project_code ='NOV132023_001',
@company_id =21,
@profit_ctr_id =1,
@resource_type = 'L',
@service_desc='Bundle',
@quantity_dt =1,
@price_dt =1540.10,
@cost =1290.10,
@quantity_ot =2,
@price_ot=1740.10,
@quantity_std =1,
@group_code ='ROTRLROP',
@resource_item_code ='OPER',
@resource_item_type ='C',
@quantity=1,
@bill_unit_code='HOUR',
@price=0,
@salesforce_Contract_Line='Test',
@salesforce_so_quote_line_id='ID1-Test2',
@salesforce_cost_markup_type ='Test',
@salesforce_cost_markup_amount=189.90,
@salesforce_bundle_id='BL-101',
@salesforce_task_name ='NAGTEST',
@salesforce_task_CSID ='NAG001',
@FLAG ='I',  --I for Insert; U for Update; D for Delete
@JSON_data='N[ {"id": 2, "info": {"name": "John", "surname": "Smith"}, "age": 25}, {"id": 5, "info": {"name": "Jane", "surname": "Smith"}, "dob": "2005-11-04T12:00:00"} ]',
@source_system = 'Sales Force',
@response =@result output
print @result

*****End*******

*/			
AS 
SET NOCOUNT ON;
Declare 
		@key_value nvarchar(4000),
		@action varchar(100),
		@Quote_id_ret int,
		@company_id_ret smallint,
		@profit_ctr_id_ret smallint,
		@len_response int,
		@ll_count int,
		@newsequence_id int,
		@ll_count_rec int,
		@error_flag char(1) = 'N' ,
		@Notes_subject char(1)='D',
		@ls_config_value char(1) ='F'

BEGIN 
Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag'
IF @ls_config_value is null or @ls_config_value=''
    Select @ls_config_value='F'
End
Begin
If @ls_config_value='T'
BEGIN
BEGIN TRY	
        
				
        Select @source_system = 'sp_sfdc_workorderquotedetail_Insert_update_delete:: ' + @source_system  

		Create table #temp_workorderquoteheader (    
					  quote_id int,
					  company_id smallint,
					  profit_ctr_id smallint)
		
		Select @Response='Integration Successful'

		Select @bill_unit_code = upper(@bill_unit_code)
	
		Select @resource_item_type = 'C'

		select @ll_count_rec = count(*) from dbo.workorderquoteheader where  project_code=@project_code  --and company_id=@Company_id and profit_ctr_id=@profit_ctr_id

		if @ll_count_rec > 1 
		Begin
		   Insert Into #temp_workorderquoteheader Select quote_id,company_id,profit_ctr_id from dbo.workorderquoteheader where project_code=@project_code and company_id=@Company_id and profit_ctr_id=@profit_ctr_id
        End
		if @ll_count_rec = 1
		Begin
		   Insert Into #temp_workorderquoteheader Select quote_id,company_id,profit_ctr_id from dbo.workorderquoteheader where project_code=@project_code
        End
		
        
		Select @key_value = 'company id;' + cast((convert(int,isnull(@company_id,''))) as varchar(20)) + 
		                    ' profit_ctr_id;' + cast((convert(int,isnull(@profit_ctr_id,''))) as varchar(20))+		
		                    ' resource Type;' + isnull(@resource_type,'') + 
							' service Desc;' + isnull(@service_desc,'') +
		                    ' quantity Dt;' + cast((convert(int,isnull(@quantity_dt,''))) as varchar(20))+				 
					        ' price_dt;' + cast((convert(money,isnull(@price_dt,''))) as varchar(20))+ 
							' cost;' + cast((convert(money,isnull(@cost,''))) as varchar(20)) +
							' quantity ot;' +cast((convert(int,isnull(@quantity_ot,''))) as varchar(20))+ 
							' price Ot;' +cast((convert(int,isnull(@price_ot,''))) as varchar(20))+ 
							' quantity std; ' + cast((convert(int,isnull(@quantity_std,''))) as varchar(20)) + 
							' group_code; '+isnull(@group_code,'')+  
							' resource_item_code;' +isnull(@resource_item_code,'') + 
							' resource_item_type;'+isnull(@resource_item_type,'')+
							' quantity;' +cast((convert(int,isnull(@quantity,''))) as varchar(20))+
							' bill_unit_code;' +isnull(@bill_unit_code,'')+ 
							' Price;'+cast((convert(int,isnull(@price,''))) as varchar(20)) +
							' SF_contract_line;' + isnull(@salesforce_Contract_Line,'') +
							' SF_so_quote_line_id;' + isnull(@salesforce_so_quote_line_id,'') +
							' salesforce_cost_markup_type;' + isnull(@salesforce_cost_markup_type,'') +
                            ' salesforce_cost_markup_amount;' +cast((convert(int,isnull(@salesforce_cost_markup_amount,''))) as varchar(20)) +
							' SF_bundle_id;' + isnull(@salesforce_bundle_id,'') +							
							' SF_so_quote_line_id;'+ isnull(@salesforce_so_quote_line_id,'') + 
							' salesforce_task_name;' +isnull(@salesforce_task_name,'')+ 
							' salesforce_task_CSID;' +isnull(@salesforce_task_CSID,'')
   
		
		   IF @FLAG IS NULL OR @FLAG =''
 		   BEGIN
 			  SELECT @Response = 'Flag cannot be null, For more details please check source_error_log table in EQAI.'
   				INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   												SELECT
   												@key_value,
   												@source_system,
    												CASE @FLAG
         												WHEN 'I' THEN 'Insert'
         												WHEN 'U' THEN 'Update'
         												WHEN 'D' THEN 'Delete'
         												ELSE 'Other'
    												END,
    											@Response,
    											GETDATE(),
   												SUBSTRING(USER_NAME(), 1, 40)

   				SELECT @flag = 'E'
 			END

							 
        Select @ll_count = count(*) from  #temp_workorderquoteheader

		If @ll_count = 0 or @ll_count > 1 and @flag <> 'E'		
		Begin
		    Select @Response= 'No Records or More than one record available for the SO ID in workorderquoteheader table. For more details please check source_error_log table in EQAI'
										 
			INSERT INTO PLT_AI_AUDIT..Source_Error_Log (input_params,source_system_details,action,Error_description,log_date,Added_by)
											SELECT @key_value,@source_system,
											CASE @FLAG 
											When 'I' Then 'Insert'
											When 'U' Then 'Update'
											When 'D' Then 'Delete'
											Else
											'Other'
											End,
											@Response,
											GETDATE(),
											Substring(user_name(),1,40)
			 Select @flag='E' 
		End   

		

		If (@project_code IS NULL OR @project_code ='' OR @salesforce_so_quote_line_id IS NULL OR @salesforce_so_quote_line_id ='') AND @Response='Integration Successful'
		Begin
			SELECT @Response = 'Salesforce SO ID or Quote line ID cannot be null.For more details please check source_error_log table in EQAI.'
      
			INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
													SELECT
														@key_value,
														@source_system,
														CASE @FLAG 
														When 'I' Then 'Insert'
														When 'U' Then 'Update'
														When 'D' Then 'Delete'
														Else
														'Other'
														End,
														@response,
														GETDATE(),
														SUBSTRING(USER_NAME(), 1, 40)
			 Select @flag='E'   
		END
		--Newly
		If ((trim(@salesforce_bundle_id) IS NOT NULL OR trim(@salesforce_bundle_id) ='') AND @price > 0 AND @resource_type <> 'O'  AND @Response='Integration Successful') 
		Begin
			SELECT @Response = 'Salesforce child bundle Quote line price should not be grater than $0.For more details please check source_error_log table in EQAI.'
      
			INSERT INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
													SELECT
													@key_value,
													@source_system,
													CASE @FLAG 
													When 'I' Then 'Insert'
													When 'U' Then 'Update'
													When 'D' Then 'Delete'
													Else
													'Other'
													End,
													@response,
													GETDATE(),
													SUBSTRING(USER_NAME(), 1, 40)
			Select @flag='E'   
		END


		Begin		
			 Select  @Quote_id_ret = quote_id, 
					 @company_id_ret= company_id,
					 @profit_ctr_id_ret=profit_ctr_id
					 from #temp_workorderquoteheader 
			  
			  If @Flag ='I' AND NOT EXISTS (SELECT * FROM WorkOrderQuotedetail  WHERE quote_id = @Quote_id_ret and salesforce_so_quote_line_id=@salesforce_so_quote_line_id and 
			                                                                          company_id=@company_id and profit_ctr_id=@profit_ctr_id)
				  Begin
				   Select @newsequence_id =  COALESCE(max(sequence_id),0) + 1 from WorkOrderQuotedetail where quote_id = @Quote_id_ret and company_id=@company_id and profit_ctr_id=@profit_ctr_id and resource_type=@resource_type
				 
				  		     Insert into dbo.workorderquotedetail
										  (Quote_id,
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
										(@Quote_id_ret,
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
										 substring(user_name(),1,10),																				 
										 getdate(), 
										 substring(user_name(),1,10),
										 getdate(), 	
										 getdate(),
										 @salesforce_so_quote_line_id,
										 @salesforce_bundle_id,
										 @salesforce_task_name,
										 @salesforce_task_CSID)   					
						End	
			  Else
			  If @Flag ='I'
			  Begin
			   Select @Response= 'SO line ID already exists, so the insert is not valid.For more details please check the Error log table in EQAI.'
												 
						INSERT INTO PLT_AI_AUDIT..Source_Error_Log (input_params,source_system_details,action,Error_description,log_date,Added_by)
												SELECT @key_value,@source_system,
												CASE @FLAG 
												When 'I' Then 'Insert'
												When 'U' Then 'Update'
												When 'D' Then 'Delete'
												Else
												'Other'
												End,
												@Response,
												GETDATE(),
												Substring(user_name(),1,40)
                        SELECT @flag = 'E'
           End
		   End		 
		   If @Flag ='U' AND NOT EXISTS (Select * from dbo.workorderquotedetail Where 
																						 Quote_id=@Quote_id_ret AND 
																						 company_id=@company_id AND
																						 profit_ctr_id=@profit_ctr_id AND
																						 resource_type=@resource_type AND
																						 service_desc=@service_desc AND
																						 quantity_dt=@quantity_dt AND
																						 price_dt=@price_dt AND
																						 cost=@cost AND
																						 quantity_ot=@quantity_ot AND
																						 price_ot=@price_ot AND
																						 quantity_std=@quantity_std AND
																						 group_code=@group_code AND																				
																						 resource_item_code=@resource_item_code AND
																						 resource_item_type=@resource_item_type AND
																						 quantity=@quantity AND
																						 upper(bill_unit_code)=@bill_unit_code AND
																						 price=@price AND
																						 salesforce_Contract_Line=@salesforce_Contract_Line AND
																						 salesforce_so_quote_line_id=@salesforce_so_quote_line_id AND
																						 salesforce_cost_markup_type=@salesforce_cost_markup_type AND
																						 salesforce_cost_markup_amount= @salesforce_cost_markup_amount AND
																						 salesforce_bundle_id=@salesforce_bundle_id AND
																						 salesforce_task_name=@salesforce_task_name AND
																						 salesforce_task_CSID=@salesforce_task_CSID)  																				   
                           AND EXISTS (SELECT * FROM WorkOrderQuotedetail WHERE quote_id = @Quote_id_ret and company_id=@company_id 
						                                                       and profit_ctr_id=@profit_ctr_id 
																			   and salesforce_so_quote_line_id=@salesforce_so_quote_line_id)
              Begin   
				Update dbo.workorderquotedetail Set	
				                                      company_id=@company_id,
													  profit_ctr_id=@profit_ctr_id,
													  resource_type=@resource_type,
													  service_desc=@service_desc,
													  quantity_dt=@quantity_dt,
													  price_dt=@price_dt,
													  cost=@cost,
													  quantity_ot=@quantity_ot,
													  price_ot=@price_ot,
													  quantity_std=@quantity_std,
													  group_code=@group_code,											  
													  resource_item_code=@resource_item_code,
													  resource_item_type=@resource_item_type,
													  quantity=@quantity,
													  bill_unit_code=@bill_unit_code,
													  price=@price,
													  salesforce_Contract_Line=@salesforce_Contract_Line,
													  salesforce_cost_markup_type=@salesforce_cost_markup_type,
													  salesforce_cost_markup_amount= @salesforce_cost_markup_amount,
													  salesforce_bundle_id=@salesforce_bundle_id,
													  salesforce_task_name=@salesforce_task_name,
													  Salesforce_task_CSID=@salesforce_task_CSID,
													  modified_by=substring(user_name(),1,10),
  													  date_modified=getdate(),
													  salesforce_date_modified=getdate()
													  Where Quote_id=@Quote_id_ret and
													        salesforce_so_quote_line_id=@salesforce_so_quote_line_id
				
                End
				Else
				If @flag='U'
					Begin
						Select @Response= 'There are no changes in the data or SO ID not exists, so update is not required/valid.For more details please check source_error_log table in EQAI.'
												 
						INSERT INTO PLT_AI_AUDIT..Source_Error_Log (input_params,source_system_details,action,Error_description,log_date,Added_by)
												SELECT @key_value,@source_system,
												CASE @FLAG 
												When 'I' Then 'Insert'
												When 'U' Then 'Update'
												When 'D' Then 'Delete'
												Else
												'Other'
												End,
												@Response,
												GETDATE(),
												Substring(user_name(),1,40)
                        SELECT @flag = 'E' 
				End
				
				If @Flag ='D'  AND EXISTS (SELECT * FROM WorkOrderQuotedetail  WHERE quote_id = @Quote_id_ret and salesforce_so_quote_line_id=@salesforce_so_quote_line_id and company_id =@company_id and profit_ctr_id=@profit_ctr_id)	
					Begin
					   Delete from dbo.workorderquotedetail where Quote_id=@Quote_id_ret and salesforce_so_quote_line_id=@salesforce_so_quote_line_id and company_id =@company_id and profit_ctr_id=@profit_ctr_id           
					End
				Else
				 IF @Flag ='D'  
				 Begin
				 Select @Response= 'No Records found for Delete.For more details please check source_error_log table in EQAI'
				 INSERT INTO PLT_AI_AUDIT..Source_Error_Log (input_params,source_system_details,action,Error_description,log_date,Added_by)
												SELECT @key_value,@source_system,
												CASE @FLAG 
												When 'I' Then 'Insert'
												When 'U' Then 'Update'
												When 'D' Then 'Delete'
												Else
												'Other'
												End,
												@Response,
												GETDATE(),
												Substring(user_name(),1,40)
                 SELECT @flag = 'E' 
				 End 	  
				   
       
	End Try
	BEGIN CATCH
		     
			
			IF @FLAG ='I'
			Begin				
				Select @Response= 'SFDC Data Integration Failed for Insert operation. For more details please check source_error_log table in EQAI'
            End
			
            IF @FLAG ='U' 
			Begin				
				Select @Response= 'SFDC Data Integration Failed for Update operation. For more details please check source_erro_ log table in EQAI'
            End
			
			IF @FLAG ='D' 
			Begin				
				Select @Response= 'SFDC Data Integration Failed for Delete operation. For more details please check source_error_log table in EQAI'
			End
			
			INSERT INTO PLT_AI_AUDIT..Source_Error_Log (input_params,source_system_details,action,Error_description,log_date,Added_by)
										SELECT
										@key_value,
										@source_system,
										CASE @FLAG 
										When 'I' Then 'Insert'
										When 'U' Then 'Update'
										When 'D' Then 'Delete'
										Else
										'Other'
										End,
										ERROR_MESSAGE(),
										GETDATE(),
				  						Substring(user_name(),1,40)    			
		    Select @error_flag='Y'		
			SELECT @flag = 'E'
	END CATCH
	Begin
	IF @Response = 'Integration Successful' AND @error_flag = 'N' AND upper(@JSON_DATA) <> 'LIST' AND @JSON_DATA is not null	
	 EXECUTE sp_sfdc_quote_json_note_insert @Quote_id_ret,@company_id,@profit_ctr_id,@JSON_DATA,@Notes_subject,@source_system
	End
	Drop table #temp_workorderquoteheader
END
If @ls_config_value='F'
Begin
   Select @Response= 'SFDC Data Integration Failed,since CRM Go live flag off. Hence Store procedure will not execute.'
   Return -1
End
End

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sfdc_workorderquotedetail_Insert_update_delete] TO EQAI
    
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_sfdc_workorderquotedetail_Insert_update_delete] TO svc_CORAppUser