USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_resource_Insert]    Script Date: 6/12/2024 9:55:21 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_sfdc_resource_Insert] 
                        @resource_code varchar(10) null,
						@company_id int,
						@default_profit_ctr_id int,												
						@resource_type char(1),
						@salesforce_resource_CSID varchar(18) null,
						@resource_class_code varchar(10) null,
						@bill_unit_code varchar(4) null, 
						@description varchar(100) null,
						@employee_id varchar(20)=Null,							
						@response varchar(max) OUTPUT
						


/*  
Description: 

API call will be made from salesforce team to Insert the Resource or resourcexresourceclass table.

Revision History:

DevOps# 81146  Created by Venu - 03/18/2024
Devops# 84925 -- 04/26/2024 Venu  new resource creation logic build.
Devops# 87468  fix deployment script review comments by Venu
dEVOPS# 89006 Revoke email notifications during the new resource creation.
Based on the Salesforce system input, if resource is not exist for the resource type equepment then 
EQAI should create the new resource in the approperiate table

USE PLT_AI
GO
Declare @response nvarchar(max);
EXEC dbo.sp_sfdc_resource_Insert
@company_id=21,
@default_profit_ctr_id=0,
@resource_type='E',
@salesforce_resource_CSID='DEVOPS74421-1',
@resource_class_code='JAN5TEST01',
@bill_unit_code='2Y',
@employee_id='VENU',
@response=@response output
print @response

*/

AS
DECLARE 	 	
	 @ll_ret int,	 
	 @key_value varchar(400), --VR
	 @user_id int,
	 @next_id int,
	 @source_system varchar(100),	 
	 @ll_validation_ret int,
	 @validation_req_field varchar(100),
     @validation_req_field_value varchar(500),
	 @validation_response varchar(1000), --Venu Modified for review comments
	 @flag char(1 )= 'S',
	 @user_code varchar(10)='N/A',
	 @ll_cnt int,
	 @ls_config_value char(1),
	 @ll_resource_cnt int =0

set transaction isolation level read uncommitted

select @ls_config_value = config_value
from configuration
where config_key='CRM_Golive_flag'

if coalesce(@ls_config_value,'') = ''
   set @ls_config_value='F'

--only allow addition of documents if go-live config value is True
if @ls_config_value = 'T'
begin


If @resource_type='E'
Begin
	Begin TRY			

		Set @source_system = 'sp_sfdc_resource_Insert: ' + 'Sales Force'  	
		Set @Response='Integration Successful'
		
		Create table #temp_salesforce_validation_fields (validation_req_field varchar(100),validation_req_field_value varchar(500))  /*To determine the validation requried field*/
		Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
		                                                 ('company_id',str(@company_id)),
														 ('profit_ctr_id',str(@default_profit_ctr_id)),
														 ('resource_type',@resource_type),		                                                
		                                                 ('resource_class_code',@resource_class_code),														 
														 ('bill_unit_code',@bill_unit_code),														 														 
														 ('employee_id',@employee_id)

       if @resource_type in ('E')  		
		Begin
			Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value)
			values ('salesforce_resource_csid',@salesforce_resource_CSID)
		End

		

		Set @key_value ='company id;' + cast((convert(int,isnull(@company_id,''))) as varchar(20)) + 
						' profit_ctr_id;' + cast((convert(int,isnull(@default_profit_ctr_id,''))) as varchar(20))+																				
						' resource_type;'+ isnull(@resource_type,'') +
						' salesforce_resource_CSID;' + isnull(@salesforce_resource_CSID,'')+ 						
						' resource_class_code;' + isnull(@resource_class_code ,'')+ 						
						' bill_unit_code;' + isnull(@bill_unit_code ,'') + 
						' employee_id;'+ isnull(@employee_id,'')	
          
       
	   Declare sf_validation CURSOR for
			select validation_req_field,validation_req_field_value from #temp_salesforce_validation_fields
			Open sf_validation
				fetch next from sf_validation into @validation_req_field,@validation_req_field_value		
				While @@fetch_status=0
				Begin				  
				   EXEC @ll_validation_ret=dbo.sp_sfdc_input_parm_validation 'sp_sfdc_resource_Insert',@validation_req_field,@validation_req_field_value,@company_id,@default_profit_ctr_id,@validation_response output
				   If @validation_req_field='employee_id' and @ll_validation_ret <> -1
				   Begin
					EXEC dbo.sp_sfdc_get_usercode @employee_id,@user_code output     
				   End

				   If @ll_validation_ret = -1
				   Begin 
						 If @Response = 'Integration Successful'
						 Begin
							Set @Response ='Error: Integration failed for the salesforce resource csid:'+isnull(@salesforce_resource_CSID,'N/A')+ ' due to the following reason;'
						 End
					 Set @Response = @Response + @validation_response+ ';'
					 Set @flag = 'E'
				   End	
				fetch next from sf_validation into @validation_req_field,@validation_req_field_value   
			   End		
		   Close sf_validation
		DEALLOCATE sf_validation 	
		Drop table #temp_salesforce_validation_fields	
		
		If @resource_code is null or @resource_code=''
		Begin
			If @Response = 'Integration Successful'
			Begin
				Set @Response ='Error: Integration failed due to the following reason; resource code:'+isnull(@resource_code,'N/A')+ 'can not be null;'
				Set @flag='E' 
			End
			Else
			If @Response <> 'Integration Successful'
			Begin
				Set @Response = @Response +'Error: Integration failed due to the following reason; resource code:'+isnull(@resource_code,'N/A')+ 'can not be null;'
				Set @flag='E'   
			End	
		End
		
		If @resource_code is not null and @resource_code <> ''
		
		Begin
			Select @ll_resource_cnt=count(*) from resource where resource_code=@resource_code and company_id=@company_id and default_profit_ctr_id=@default_profit_ctr_id and resource_type=@resource_type
						
			If @ll_resource_cnt > 0
			Begin
				If @Response = 'Integration Successful'
				Begin
					Set @Response ='Error: Integration failed due to the following reason; resource code:'+isnull(@resource_code,'N/A')+ ' already exists for the company id,profit center id and resource type ' +isnull(str(@company_id),'N/A')+','+isnull(str(@default_profit_ctr_id),'N/A')+','+isnull(@resource_type,'N/A')+';'
					Set @flag='E' 
				End
				Else
				If @Response <> 'Integration Successful'
				Begin
					Set @Response = @Response +'Error: Integration failed due to the following reason; resource code:'+isnull(@resource_code,'N/A')+ ' already exists for the company id,profit center id and resource type ' +isnull(str(@company_id),'N/A')+','+isnull(str(@default_profit_ctr_id),'N/A')+','+isnull(@resource_type,'N/A')+';'
					Set @flag='E'   
				End	
			End
		End
	  
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

--------------------
-- BEGIN TRANSACTION
--------------------
begin transaction	

	   If @flag <> 'E'

	   Begin
				   
	   	
	   Insert into dbo.resource
								(company_id,
								 default_profit_ctr_id,
								 resource_code,
								 resource_type,
								 resource_status,								 
								 salesforce_resource_CSID,
								 description,
								 added_by,
								 date_added,
								 modified_by,
								 date_modified,
								 user_id)
								 VALUES
								 (@company_id,
								  @default_profit_ctr_id,
								  @resource_code,
								  @resource_type,
								  'A',								  
								  @salesforce_resource_CSID,
								  @description,
								  @user_code,
								  getdate(),
								  @user_code,
								  getdate(),
								  @user_id)
			
			if @@error <> 0
			begin
			rollback transaction
			SELECT @Response = 'Error: Integration failed due to the following reason; could not insert into resource table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
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

			 Insert into dbo.resourcexresourceclass
							(resource_code,
							 resource_company_id,
							 resource_class_code,
							 resource_class_company_id,
							 resource_class_profit_ctr_id,
							 bill_unit_code)
							 Values
							 (@resource_code,
							  @company_id,
							  @resource_class_code,							  
							  @company_id,
							  @default_profit_ctr_id,
							  @bill_unit_code)  

            if @@error <> 0
			begin
			rollback transaction
			SELECT @Response = 'Error: Integration failed due to the following reason; could not insert into resourcexresourceclass table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
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

			
			--EXEC dbo.sp_sfdc_new_resource_email_notification @resource_code,@salesforce_resource_CSID
            
		end  

	--------------------
	--COMMIT TRANSACTION
	--------------------
	commit transaction
				
	End Try		

	

	Begin Catch
	            SELECT @Response = 'Error: New resource Integration failed.Please check source_error_log table in EQAI.'
				INSERT INTO PLT_AI_AUDIT..Source_Error_Log (input_params,source_system_details,action,Error_description,log_date,Added_by)
											SELECT
											@key_value,
											@source_system,										
											'Insert',
											isnull(str(ERROR_LINE()),' ')+'Line Number failed'+ isnull(ERROR_MESSAGE(),' '),
											GETDATE(),
											@user_code
										
										
				Return -1
	End CATCH
	
End
End
if @ls_config_value='F'
begin
	Select @Response= 'SFDC Data Integration Failed,since CRM Go live flag off. Hence Store procedure will not execute.'
	return -1
end

return 0




GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_resource_Insert] TO EQAI  

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_resource_Insert] TO svc_CORAppUser

go