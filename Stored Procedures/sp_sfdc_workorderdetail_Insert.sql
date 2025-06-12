USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_workorderdetail_Insert]    Script Date: 12/18/2024 5:01:39 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_sfdc_workorderdetail_Insert] 
						@manifest varchar(15) null,
						@salesforce_bundle_id varchar(10) null,
						@resource_type char(1) null,						
						@description varchar(100) null,
						@TSDF_code varchar(15) null,						
						@extended_price money null,
						@extended_cost money null,
						@salesforce_invoice_line_id varchar(25) null,
						@salesforce_task_name varchar(80) null,
						@bill_rate float null,  
						@price_source varchar(40) null,
						@print_on_invoice_flag char(1) null,
						@quantity_used float null,
						@quantity float null,
						@resource_class_code varchar(20) null,
						@salesforce_resource_CSID varchar(18) null,
						@salesforce_resourceclass_CSID varchar(18) null,
						@cost money null,
						@bill_unit_code varchar(4) null, 
						@billing_sequence_id decimal(10,3),
						@company_id int,						
						@date_service datetime null, 						
						@prevailing_wage_code varchar(20) null, 
						@price money null,
						@price_class varchar(10) null,						
						@profit_ctr_ID int, 												
						@salesforce_invoice_csid varchar(18) null,					
						@JSON_DATA nvarchar(max),
						@source_system varchar(100)='Sales Force',
						@employee_id varchar(20)=Null,
						@sales_tax_line_flag char(1)='F',
						@description_2 varchar(100) = Null,
                        @resource_company_id int = Null,
						@generator_sign_date datetime = Null,
						@generator_sign_name VARCHAR(255) = Null,
						@TSDF_approval_code varchar(40)= Null,
						@as_map_disposal_line char(1)='I',
						@salesforce_so_csid varchar(18) null,
						@as_woh_disposal_flag char(1)='F',  
						@start_date datetime = Null,
						@end_date datetime = Null,
						@response varchar(4000) OUTPUT

/*  
Description: 

API call will be made from salesforce team to Insert the workorderdetail table.

Revision History:

DevOps# 74079  Created by Venu
Once the Pro Forma Invoice has been created, the necessary 
Salesforce fields need to be sent from Salesforce (Sales Invoice object & Sales Invoice Line object) 
to EQAI (Work Order Header, Work Order Detail, & Note object). This procedure is for workorderdetail Integration
Devops # 75374, Added salesforce_resource_CSID parameter, and resource_code should be retrieved and shown in the resource_assigned field.
Devops# 76451 and 76453 - 01/04/2024 Venu Modified the Procedure - Implement the validation for all the required fields,resource class check.
Devops# 77458 --01/31/2024 Venu - Modified for the erorr handling messgae text change
Devops# 79234  --02/22/2024 Venu - Modified for adding addtional integarted fields and default values.
Devops# 79585  --02/28/2024 Venu - Modified to handle the manifest null to aviod the validation
DevOps# 81146  Created by Venu - 03/19/2024 Based on the Salesforce system input, if resource is not exist for the resource type equepment then 
EQAI should create the new resource in the approperiate table and will let know the EQAI distribution list
Devops# 81419 -- 03/19/2024 Venu Populate the user_code to added_by and modified_by fields
Devops# 84925 -- 04/26/2024 Venu moved the new resource creation logic from billingpackage to at the time of SF resource creation.
Devops# 83650 --04/30/2024 Venu Implemeted the sales invoice tax line for OTHER resource 
Devops# 86616 --02/22/2024 Venu - Modified for adding addtional integarted fields and default values.
Devops# 87468  fix deployment script review comments by Venu
Devops# 83361 - 04/29/2024 Rob - Populate Salesforce staging tables instead of actual EQAI tables (for fully transactional integration)
Devops# 83361 - 05/16/2024 Rob - For MVP, don't validate TSDF code, and don't populate it for the Other tab Disposal. This will get re-worked when Disposal tab gets populated
Devops# 87927 -- 05/20/2024 Venu Modified the error handling.
Rally DE34339 - 06/12/2024 Rob - Added @resource_company_id argument, need to populate new resource_uid column
Devops# 89645 - Define cost_quantity field value for both Labor and Equipment
Task#437121 - Added resouce company in validation required field list. 
US#118337 -- Added insert data values for the workordermanifest,workorderdetailunit for the resource type Disposal 'D', and added tsdf_code,tsdf_code_approval for the workorderdetail.
DE35070 - Added validation for the SF SO ID for the disposal line
DE35502 Added TSDF validation 
US126358 & 126371 -- Modified by Venu & Nagaraj to implement the disposal line re-design
DE35855 -- Modified by Venu to fix the error out line remove for the previous instance
DE35882 -- Modified by Venu to additional attribute for start & end date
US#131973  - 12/18/2024 Venu - Added validation if SF invoke this proceudre for Disposal record
USE PLT_AI
GO
Declare @response nvarchar(max);
EXEC dbo.sp_sfdc_workorderdetail_Insert
@manifest='TEST1234',
@salesforce_bundle_id='02AUG_001',
@resource_type ='O',
@description='TEST',
@extEnded_price=0,
@extEnded_cost=0,
@salesforce_invoice_line_id='US117391_02AUG_102',
@salesforce_task_name='DEC13_TEST_OO1',
@bill_rate= 0,  
@price_source='TEST',
@print_on_invoice_flag='Y',
@quantity_used=0,
@quantity=0,
@resource_class_code='TRAN',
@salesforce_resource_CSID='',--'TEST1234',
@salesforce_resourceclass_CSID = 'a0rf4000002vLLjAAM', 
@cost=0,
@bill_unit_code='T350',
@billing_sequence_id=0,
@company_id=21,
@date_service='07-Nov-2023',
@prevailing_wage_code='test',
@price=0,
@price_class='test',
@profit_ctr_ID=0,
@salesforce_invoice_csid='US117391_02AUG_101',
@JSON_DATA ='{
"Account_Executive__c": "John Jacobsen",
"Billing_Instructions__c": "T&D Bilge Water USNS Watkins",
"Approved__c": "a0uDR000001rpYaYAI",
"Phone_No__c": "781-771-0354"}',
@source_system ='Sales Force',
@employee_id='864502',
@resource_company_id=21,
@generator_sign_date ='02/AUG/2024',
@generator_sign_name ='NAGARAJM',
@TSDF_approval_code ='AEROSOLSCOR',
@TSDF_CODE='EQDET',
@as_map_disposal_line='I',
@response=@response output
print @response



*/

AS
DECLARE 	 
	 @workorder_ID_ret int,
	 @newsequence_id int,
	 @key_value varchar(2000),	 
	 @ll_ret int,
	 @currency_code char(3) = 'USD',
	 @group_instance_id int =0,	
	 @ls_config_value char(1)='F',
	 @resource_assigned varchar(10),
	 @ll_count_rec int,	
	 @flag char(1 )= 'S',
	 @Notes_subject char(1)='D',
	 @validation_req_field varchar(100),
     @validation_req_field_value varchar(500),
	 @validation_response varchar(1000),
	 @ll_validation_ret int,
	 @resource_class_cnt_hdr int,
	 @resource_class_cnt_dtl int,
	 @ll_parent_bundle_cnt int,
	 @priced_flag smallint = 1,
	 @cost_class varchar(10)=Null,	 
	 @user_code varchar(10)='N/A',
	 @sfs_workorderheader_uid int,
     @resource_uid int,
	 @cost_quantity float,
	 @manifest_state char(1)='H',
	 @manifest_flag char(1)='T',
	 @EQ_FLAG char(1),
	 @profile_id int,
	 @profile_company_id int,
	 @profile_prft_ctr_id int,
	 @tsdf_approval_id int,
	 @ls_config_value_phase3 char(1)='F',
	 @workorder_id_ret_disposal int,
	 @ll_salesforce_so_csid_cnt int,
     @ll_resource_cnt int,
	 @ll_wo_staging_cnt int,
	 @ll_manifest_cnt int,
	 @ll_tsdf_approval_cnt int,
	 @eq_profit_ctr int,
	 @eq_company int,
	 @customer_id int,
	 @ll_ret_disposal int,
	 @manifest_check_first int,
	 @manifest_check_last int,
	 @Profile_DOT_shipping_name varchar(255), 
	 @Profile_manifest_hand_instruct Varchar(1000),
	 @TreatmentDetail_management_code char(4), 
	 @Profile_reportable_quantity_flag char(1), 
	 @Profile_RQ_reason varchar(50),
	 @Profile_hazmat char(1), 
	 @Profile_subsidiary_haz_mat_class varchar(15), 
	 @Profile_UN_NA_flag char(2),
	 @Profile_package_group varchar(3), 
	 @Profile_manifest_handling_code varchar(15), 
	 @Profile_manifest_wt_vol_unit varchar(15), 
	 @Profile_UN_NA_number int, 
	 @Profile_ERG_number int, 
	 @Profile_ERG_suffix char(2),
	 @profile_manifest_dot_sp_number varchar(20),
	 @Generator_EPA_ID varchar(15),
	 @Profile_manifest_container_code varchar(15),
	 @Profile_hazmat_class VARCHAR(15),
	 @TSDFApproval_waste_stream varchar(10),
	 @TSDFApprovalPrice_bill_rate float,
	 @Profile_manifest_waste_desc varchar(50),
	 @ll_man_line_cnt int,
	 @manifest_line int,
	 @newsequence_id_disposal int=0,
	 @billing_sequence_id_disposal int=0
	--@Profile_reportable_quantity_flag CHAR(1)

set transaction isolation level read uncommitted

Begin 
	Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag'
	IF @ls_config_value is null or @ls_config_value=''
	Set @ls_config_value='F'
End

Begin 
	Select @ls_config_value_phase3 = config_value From configuration where config_key='CRM_Golive_flag_phase3'
	IF @ls_config_value_phase3 is null or @ls_config_value_phase3=''
	Select @ls_config_value_phase3='F'
End


If @as_woh_disposal_flag is null or @as_woh_disposal_flag=''
Begin
Set @as_woh_disposal_flag='F'  
End


If @ls_config_value_phase3='F' and (@resource_type='D' or @as_woh_disposal_flag='T')
Begin
	Print 'SFDC Data Integration Failed,since CRM Go live flag - Phase3 is off but EQAI received disposal line. Hence Store procedure will not execute.'
	Return -1
End

If (@salesforce_so_csid is not null and @salesforce_so_csid <> '') and @ls_config_value_phase3='F'
Begin
	Print 'SFDC Data Integration Failed,since CRM Go live flag - Phase3 is off but EQAI received SO CSID value to consider disaposal record. Hence Store procedure will not execute.'
	Return -1
End

IF  @as_woh_disposal_flag='T' and @salesforce_so_csid is not null and @salesforce_so_csid <> ''
Begin
	Select  @ll_wo_staging_cnt = count(*) from dbo.SFSWorkorderHeader
	where company_id=@company_id and profit_ctr_ID=@profit_ctr_ID and salesforce_invoice_CSID = @salesforce_so_csid 
	If @ll_wo_staging_cnt > 0
	Begin
		select @sfs_workorderheader_uid = max(sfs_workorderheader_uid)
		from dbo.SFSWorkorderHeader
		where company_id=@company_id and profit_ctr_ID=@profit_ctr_ID and salesforce_invoice_CSID = @salesforce_so_csid 

		select @workorder_id_ret_disposal = workorder_id,@customer_id=customer_id 
		from dbo.SFSWorkorderHeader
		where company_id=@company_id and profit_ctr_ID=@profit_ctr_ID and salesforce_invoice_CSID = @salesforce_so_csid  and
		sfs_workorderheader_uid=@sfs_workorderheader_uid

		Set @workorder_ID_ret=@workorder_id_ret_disposal

	End

	If @ll_wo_staging_cnt=0
	Begin
	Set @Response ='Error: Integration failed due to the following reason for the Salesforce SO line id:' + isnull(@salesforce_invoice_line_id,'N/A') + '  header record not exist in sfsworkorderheader;'
	Set @flag='E'  
	Return -1
	End	
End

IF  @as_woh_disposal_flag='F' 
Begin
select @sfs_workorderheader_uid = max(sfs_workorderheader_uid)
		from dbo.SFSWorkorderHeader
		where company_id=@company_id and profit_ctr_ID=@profit_ctr_ID and
		salesforce_invoice_CSID = @salesforce_invoice_CSID 
End


If @ls_config_value='T'
Begin
Begin transaction				

		Set @source_system = 'sp_sfdc_workorderdetail_Insert: ' + @source_system  	
		Set @Response='Integration Successful'
		
		Create table #temp_salesforce_validation_fields (validation_req_field varchar(100),validation_req_field_value varchar(500))  /*To determine the validation requried field*/
		Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
		                                                 ('company_id',str(@company_id)),
														 ('profit_ctr_id',str(@profit_ctr_id)),
														 ('resource_type',@resource_type),
-- 05/16/2024 rb temporary for MVP		                                                 ('tsdf_code',@tsdf_code),
														 ('salesforce_invoice_line_id',@salesforce_invoice_line_id),
		                                                 ('resource_class_code',@resource_class_code),
														 ('salesforce_resourceclass_csid',@salesforce_resourceclass_CSID),
														 ('bill_unit_code',@bill_unit_code),														 
														 --('salesforce_invoice_csid',@salesforce_invoice_csid),	
														 ('employee_id',@employee_id)


		if @resource_type in ('E', 'L')  
		--if @resource_type in ('L') modified by venu
		Begin
			--Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value)
			--values ('salesforce_resource_csid',@salesforce_resource_CSID)
			Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value)
			values ('resource_company_id',@resource_company_id)
		End

		IF @resource_type ='D'  --AND @as_woh_disposal_flag='T'
		Begin
		  Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value)
		  values ('tsdf_code',@tsdf_code)
		End 

		IF @as_woh_disposal_flag='F'
		Begin
		  Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value)
		  values ('salesforce_invoice_csid',@salesforce_invoice_csid)
		End


		If @as_woh_disposal_flag='T'			
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

				
		If @sales_tax_line_flag = 'T'
		Begin
		 Delete from #temp_salesforce_validation_fields where validation_req_field in ('salesforce_invoice_line_id','tsdf_code','salesforce_resourceclass_csid')
		End
		
		
		Set @key_value = 'manifest;' + isnull(@manifest,'') +
							' salesforce_bundle_id;' + isnull(@salesforce_bundle_id,'') +
							' resource_type;'+ isnull(@resource_type,'') +							
							' description;' + isnull(@description , '') + 
							' tsdf_code;' + isnull(@TSDF_code,'')+ 							
							' extended_price;' + cast((convert(int,@extEnded_price)) as varchar(20))+ 
							' extended_cost;' + cast((convert(int,@extEnded_cost)) as varchar(20))+ 
							' salesforce_invoice_csid; ' + isnull(@salesforce_invoice_csid ,'')+ 
							' salesforce_invoice_line_id;' + isnull(@salesforce_invoice_line_id,'')+ 
							' bill_rate;' + cast((convert(int,@bill_rate)) as varchar(20))+ 
							' price_source;' + isnull(@price_source,'') + 
							' print_on_invoice_flag;' + isnull(@print_on_invoice_flag,'') + 
							' quantity_used;' + cast((convert(float,@quantity_used)) as varchar(20))+ 
							' quantity;' + cast((convert(float,@quantity)) as varchar(20))+ 	
							' salesforce_resource_CSID;' + isnull(@salesforce_resource_CSID,'')+ 
							' salesforce_resourceclass_CSID;' + isnull(@salesforce_resourceclass_CSID,'')+ 
							' resource_class_code;' + isnull(@resource_class_code ,'')+ 
							' cost;' + cast((convert(int,@cost)) as varchar(20))+ 
							' bill_unit_code;' + isnull(@bill_unit_code ,'') + 
							' billing_sequence_id;' + cast((convert(int,@billing_sequence_id)) as varchar(20))+ 
							' company id;' + cast((convert(int,@company_id)) as varchar(20)) + 
							' date_service;' + cast((convert(datetime,@date_service)) as varchar(20))+	
							' prevailing_wage_code;' + isnull(@prevailing_wage_code ,'')+ 	
							' price;' + cast((convert(int,@price)) as varchar(20)) + 
							' price class;' + isnull(@price_class ,'')+ 								
							' profit_ctr_id;' + cast((convert(int,@profit_ctr_id)) as varchar(20))+								
							' salesforce_task_name; ' + isnull(@salesforce_task_name ,'')+							
							' employee_id;' +isnull(@employee_id,'') +		
							' sales_tax_line_flag;' +isnull(@sales_tax_line_flag,'') +
							' description_2;' + isnull(@description_2,'') +
							' generator_sign_date;' + cast((convert(datetime,@generator_sign_date)) as varchar(20)) +	
							' generator_sign_name;' + isnull(@generator_sign_name,'') +
							' TSDF_approval_code;' + isnull(@TSDF_approval_code,'') +
							' as_map_disposal_line;' + isnull(@as_map_disposal_line,'') +
							' resource_company_id;' + cast((convert(int,@resource_company_id)) as varchar(20)) +
							' as_woh_disposal_flag; ' + isnull(@as_woh_disposal_flag ,'') +
							' salesforce_so_csid; ' + isnull(@salesforce_so_csid ,'') +
							' Start_date;' + cast((convert(datetime,@start_date)) as varchar(20))+	
							' End_date;' + cast((convert(datetime,@end_date)) as varchar(20))

							 
		    If @JSON_DATA is null Or @JSON_DATA=''
			Begin
				Set @response = 'Error: Integration failed due to the following reason;received JSON data string empty/null'			
				Set @flag = 'E'			
			End  
				
        
			If @sales_tax_line_flag = 'T' and  @resource_type <> 'O'
			Begin
			  Set @response = 'Error: Integration failed due to the following reason;Sales tax invoice line is not applicable for the resource type: '+@resource_type
			  Set @flag = 'E' 			
			End
		  
			If @sales_tax_line_flag = 'T' and @salesforce_bundle_id is not null and @salesforce_bundle_id <> ''
			Begin
			  If  @Response <> 'Integration Successful'
			  Begin
				Set @response = @Response +'Error: Integration failed due to the following reason;Sales tax invoice line can not set as a parent bundle: '+@salesforce_bundle_id		
		      End
			  If  @Response = 'Integration Successful'
			  Begin
				Set @response = 'Error: Integration failed due to the following reason;Sales tax invoice line can not set as a parent bundle: '+@salesforce_bundle_id		
			  End
			  Set @flag = 'E' 	
			End

			If @sales_tax_line_flag = 'T' and @resource_class_code <> 'FEESLSTX'
			Begin
				If  @Response <> 'Integration Successful'
				Begin
					Set @response = @Response + 'Error: Integration failed due to the following reason;Sales tax invoice line resource class code should:FEESLSTX but received as: '+@resource_class_code
				End

				If  @Response = 'Integration Successful'
				Begin
					Set @response = 'Error: Integration failed due to the following reason;Sales tax invoice line resource class code should:FEESLSTX but received as: '+@resource_class_code
				End

				Set @flag = 'E'
			End
		
		If @sales_tax_line_flag = 'T'
		Begin
			Set @salesforce_invoice_line_id =@salesforce_invoice_csid 
		End
									
		Declare sf_validation CURSOR fast_forward for
			select validation_req_field,validation_req_field_value from #temp_salesforce_validation_fields
			Open sf_validation
				fetch next from sf_validation into @validation_req_field,@validation_req_field_value		
				While @@fetch_status=0
				Begin				  
				   EXEC @ll_validation_ret=dbo.sp_sfdc_input_parm_validation 'sp_sfdc_workorderdetail_insert',@validation_req_field,@validation_req_field_value,@company_id,@profit_ctr_id,@validation_response output
						
						If @validation_req_field='salesforce_invoice_csid' and @ll_validation_ret <> -1
						Begin
						Select @workorder_ID_ret = workorder_id from dbo.SFSworkorderheader 
																where sfs_workorderheader_uid=@sfs_workorderheader_uid 
						End

						If @validation_req_field='employee_id' and @ll_validation_ret <> -1
						Begin
						EXEC dbo.sp_sfdc_get_usercode @employee_id,@user_code output     
						End

				   If @ll_validation_ret = -1
				   Begin 
						 If @Response = 'Integration Successful'
						 Begin
							Set @Response ='Error: Integration failed for the salesforce invoice line id:'+isnull(@salesforce_invoice_line_id,'N/A')+ ' due to the following reason;'
						 End
						 Set @Response = @Response + @validation_response+ ';'						 
						 Set @flag = 'E'
				   End	
				fetch next from sf_validation into @validation_req_field,@validation_req_field_value   
			   End		
		   Close sf_validation
		DEALLOCATE sf_validation 	
		Drop table #temp_salesforce_validation_fields	       
	   
	   /*Disposal Line Validation --Start*/
	   IF  @as_woh_disposal_flag='T' and @salesforce_so_csid is not null and @salesforce_so_csid <> ''
	   Begin
		  select @ll_salesforce_so_csid_cnt=count(*) from sfsworkorderheader where salesforce_invoice_csid=@salesforce_so_csid  and company_id=@company_id and profit_ctr_id=@profit_ctr_id
		    if @ll_salesforce_so_csid_cnt = 0 and @response <> 'Integration Successful'
		   	Begin
			Set @Response = @Response +'salesforce SO csid:'+ isnull(@salesforce_so_csid,'N/A') + ' not exists in sfsworkorderheader;'
			Set @flag='E' 
			End
			if @ll_salesforce_so_csid_cnt = 0 and @response = 'Integration Successful'
			Begin
				Set @Response ='Error: Integration failed due to the following reason; Salesforce SO csid:' + isnull(@salesforce_so_csid,'N/A') + '  not exists in sfsworkorderheader;'
				Set @flag='E'   
			End
		End
		
		
		IF  @as_woh_disposal_flag='T' and (@salesforce_so_csid is null OR @salesforce_so_csid = '')
		Begin
		  
		  if @response <> 'Integration Successful'
		   	Begin
				Set @Response = @Response + ' Salesforce SO csid can not be empty,since disposal flag received as True;'
				Set @flag='E' 
			End
			if  @response = 'Integration Successful'
			Begin
				Set @Response ='Error: Integration failed due to the following reason; Salesforce so csid can not be empty,since disposal flag received as True;'
				Set @flag='E'   
			End
		End

		IF  @as_woh_disposal_flag='F' and (@salesforce_so_csid is not null and @salesforce_so_csid <> '')
		Begin
		  
		  if @response <> 'Integration Successful'
		   	Begin
				Set @Response = @Response + ' Salesforce SO csid Should empty ,since disposal flag received as False;'
				Set @flag='E' 
			End
			if  @response = 'Integration Successful'
			Begin
				Set @Response =' Salesforce SO csid Should empty ,since disposal flag received as False;'
				Set @flag='E'   
			End
		End


		IF @resource_type='D'
		Begin
			If @manifest is null or @manifest=''  
			Begin
				 if @response <> 'Integration Successful'
				 Begin
						Set @Response = @Response + ' for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' Manifest field cannot be null for the resource type Disposal;'
						Set @flag='E' 
				 End
				if @response = 'Integration Successful'
				Begin
					Set @Response ='Error: Integration failed for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' Manifest field cannot be null for the resource type Disposal;'
					Set @flag='E'   
				End
			 End

			 If @manifest is not null and @manifest <> ''  -- To check the format
			 Begin			      
                 If len(trim(@manifest)) < 10 or len(trim(@manifest)) > 12
				 Begin
				  if @response <> 'Integration Successful'
					 Begin
							Set @Response = @Response + ' for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' As per the EQAI standard manifest length should be 10 to 12 for the resource type Disposal;'
							Set @flag='E' 
					 End
					if @response = 'Integration Successful'
					Begin
						Set @Response ='Error: Integration failed for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' As per the EQAI standard manifest length should be 10 to 12 for the resource type Disposal;'
						Set @flag='E'   
					End
				 End		
				 

				 If SUBSTRING(trim(@MANIFEST),1,9) = 'MANIFEST_' and  (len(trim(@manifest)) < 10 or	len(trim(@manifest)) >12 )
				 Begin
					 if @response <> 'Integration Successful'
					 Begin
							Set @Response = @Response + ' for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' Recevied Manifest:' +@manifest+ ' Invalid format for the resource type Disposal;'
							Set @flag='E' 
					 End
					if @response = 'Integration Successful'
					Begin
						Set @Response ='Error: Integration failed for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' Recevied Manifest:' +@manifest+ ' Invalid format for the resource type Disposal;'
						Set @flag='E'   
					End
				 End
			
			 
				 If SUBSTRING(@MANIFEST,1,9) <> 'MANIFEST_' and len(@manifest) =12	
				 Begin
				 SELECT @manifest_check_first = isnumeric(substring(@manifest,1,9))
				 SELECT @manifest_check_last = isnumeric(substring(@manifest,10,12))
				 if @manifest_check_first = 0 or @manifest_check_last = 1
				 Begin
				 if @response <> 'Integration Successful'
					 Begin
							Set @Response = @Response + ' for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' Recevied Manifest:' +@manifest+ ' Invalid format for the resource type Disposal;'
							Set @flag='E' 
					 End
					if @response = 'Integration Successful'
					Begin
						Set @Response ='Error: Integration failed for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' Recevied Manifest:' +@manifest+ ' Invalid format for the resource type Disposal;'
						Set @flag='E'   
					End
				  End
				 End

				 Select @manifest_line =  COALESCE(max(MANIFEST_line),0) + 1 from SFSWorkOrderdetail where sfs_workorderheader_uid = @sfs_workorderheader_uid 
				 and resource_type=@resource_type
			     and manifest=@manifest
			   End			
				 
			 If @TSDF_approval_code is null or @TSDF_approval_code=''
			 Begin
			 if @response <> 'Integration Successful'
		   		Begin
					Set @Response = @Response + ' for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' TSDF approval code value is required,since this is disposal line;'
					Set @flag='E' 
				End
				if @response = 'Integration Successful'
				Begin
					Set @Response ='Error: Integration failed for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' TSDF approval code value is required,since this is disposal line;'
					Set @flag='E'   
				End
			 End

			 If @TSDF_approval_code is not null and @TSDF_approval_code <> '' and @TSDF_code is not null and @TSDF_code <> ''
			 Begin
				Select @EQ_FLAG=EQ_FLAG,@eq_company=eq_company,@eq_profit_ctr=eq_profit_ctr FROM TSDF WHERE TSDF_CODE=@TSDF_CODE AND TSDF_STATUS='A'
					 If @EQ_FLAG is null or @EQ_FLAG=''
					 Begin
						Set @EQ_FLAG='F'
					 End

					If @EQ_FLAG='T'
					Begin
						select @ll_tsdf_approval_cnt = count(*) from profilequoteapproval  where approval_code=@TSDF_approval_code
																			and company_id=@eq_company and profit_ctr_id=@eq_profit_ctr and status='A'

						select @profile_id = profile_id,@profile_company_id=company_id,@profile_prft_ctr_id=profit_ctr_id,@price_source=@TSDF_approval_code
						from profilequoteapproval  where approval_code=@TSDF_approval_code
						and company_id=@EQ_COMPANY and profit_ctr_id=@EQ_PROFIT_CTR and status='A' 					


						SELECT @profile_dot_shipping_name=Profile.DOT_shipping_name, 
						@Profile_manifest_hand_instruct=Profile.manifest_hand_instruct, 
						@Profile_manifest_waste_desc=CASE WHEN Profile.manifest_waste_desc IS NULL THEN Profile.approval_desc 
						ELSE Profile.manifest_waste_desc END,
						@TreatmentDetail_management_code=TreatmentDetail.management_code, 
						@Profile_reportable_quantity_flag=Profile.reportable_quantity_flag,
						@Profile_RQ_reason=Profile.RQ_reason,
						@Profile_hazmat=Profile.hazmat, 
						@Profile_hazmat_class=Profile.hazmat_class, 
						@Profile_subsidiary_haz_mat_class=Profile.subsidiary_haz_mat_class, 
						@Profile_UN_NA_flag=Profile.UN_NA_flag,
						@Profile_package_group=Profile.package_group, 
						@Profile_manifest_handling_code=Profile.manifest_handling_code, 
						@Profile_manifest_wt_vol_unit=Profile.manifest_wt_vol_unit,
						@Profile_UN_NA_number=Profile.UN_NA_number, 
						@Profile_ERG_number=Profile.ERG_number, 
						@Profile_ERG_suffix=Profile.ERG_suffix,
						@profile_manifest_dot_sp_number=profile.manifest_dot_sp_number,
						@description=Profile.approval_desc,
						@Profile_manifest_container_code=Profile.manifest_container_code
						FROM Profile (nolock)
						JOIN ProfileQuoteApproval (nolock) ON Profile.profile_id = ProfileQuoteApproval.profile_id
						JOIN TreatmentDetail (nolock) ON ProfileQuoteApproval.treatment_id = TreatmentDetail.treatment_id
						AND ProfileQuoteApproval.company_id = TreatmentDetail.company_id
						AND ProfileQuoteApproval.profit_ctr_id = TreatmentDetail.profit_ctr_id
						Join Generator (nolock) on profile.generator_id = generator.generator_id
						WHERE Profile.profile_id = @PROFILE_ID
						AND ProfileQuoteApproval.approval_code = @TSDF_approval_code
						AND ProfileQuoteApproval.company_id = @eq_company
						AND ProfileQuoteApproval.profit_ctr_id = @eq_profit_ctr
						AND ProfileQuoteApproval.status='A'
					End

					If @EQ_FLAG='F'
					Begin
					select @ll_tsdf_approval_cnt=count(*) from tsdfapproval where tsdf_code=@tsdf_code and TSDF_approval_code=@TSDF_approval_code
																and company_id=@company_id and profit_ctr_id=@profit_ctr_ID and TSDF_approval_status='A'

					select @tsdf_approval_id=tsdf_approval_id,@price_source='TDA - ' + TRIM(STR(@tsdf_approval_id)) from tsdfapproval where tsdf_code=@tsdf_code
					and TSDF_approval_code=@TSDF_approval_code
					and company_id=@company_id and profit_ctr_id=@profit_ctr_ID and TSDF_approval_status='A'


					SELECT @profile_dot_shipping_name=TSDFApproval.DOT_shipping_name, 
					@Profile_manifest_hand_instruct=TSDFApproval.hand_instruct, 
					@Profile_manifest_waste_desc=TSDFApproval.waste_desc,
					@TreatmentDetail_management_code=TSDFApproval.management_code,
					@Profile_reportable_quantity_flag=TSDFApproval.reportable_quantity_flag, 
					@Profile_RQ_reason=TSDFApproval.RQ_reason,
					@Profile_hazmat=TSDFApproval.hazmat, 
					@Profile_hazmat_class=TSDFApproval.hazmat_class, 
					@Profile_subsidiary_haz_mat_class=TSDFApproval.subsidiary_haz_mat_class, 
					@Profile_UN_NA_flag=TSDFApproval.UN_NA_flag,
					@Profile_package_group=TSDFApproval.package_group, 
					@Profile_manifest_handling_code=TSDFApproval.manifest_handling_code, 
					@Profile_manifest_wt_vol_unit=TSDFApproval.manifest_wt_vol_unit,
					@Profile_UN_NA_number=TSDFApproval.UN_NA_number, 
					@Profile_ERG_number=TSDFApproval.ERG_number, 
					@Profile_ERG_suffix=TSDFApproval.ERG_suffix, 
					@profile_manifest_dot_sp_number=TSDFApproval.manifest_dot_sp_number,
					@TSDFApproval_waste_stream=TSDFApproval.waste_stream,
					@description=TSDFApproval.waste_desc,
					@TSDFApprovalPrice_bill_rate=TSDFApprovalPrice.bill_rate,
					@Profile_manifest_container_code=TSDFApproval.manifest_container_code					
					FROM TSDFApproval (nolock)
					INNER JOIN TSDFApprovalPrice (nolock) ON TSDFApproval.TSDF_approval_id = TSDFApprovalPrice.TSDF_approval_id
					AND TSDFApproval.bill_unit_code = TSDFApprovalPrice.bill_unit_code
					WHERE TSDFApproval.tsdf_approval_id = @tsdf_approval_id
					and TSDF_approval_code=@TSDF_approval_code
					and TSDFApproval.TSDF_approval_status='A'
					End  
				End

			   If @ll_tsdf_approval_cnt = 0 and @EQ_FLAG='T'
		       Begin
			   if @response <> 'Integration Successful'
				BEGIN
					Set @Response = @Response + ' for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + '  received TSDF approval code:'+@TSDF_approval_code +' not exists in tsdfapproval for the tsdf code,eq company id and eq profit center id:'+@tsdf_code+', '+str(@eq_company) +' and'+str(@eq_profit_ctr)+ ';'
					Set @flag='E' 
				End
				if  @response = 'Integration Successful'
				Begin
					Set @Response ='Error: Integration failed for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' due to the following reason; received TSDF approval code:'+@TSDF_approval_code +' not exists in tsdfapproval for the tsdf code, eq company id and eq profit centre id:'+@tsdf_code+', '+str(@eq_company) +' and'+str(@eq_profit_ctr)+ ';'
					Set @flag='E'   
				End
				End

				If @ll_tsdf_approval_cnt = 0 and @EQ_FLAG='F'
		       Begin
			   	if @response <> 'Integration Successful'
				BEGIN
					Set @Response = @Response + ' for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + '  received TSDF approval code:'+@TSDF_approval_code +' not exists in tsdfapproval for the tsdf code,company id and profit center id:'+@tsdf_code+', '+str(@company_id) +' and'+str(@profit_ctr_id)+ ';'
					Set @flag='E' 
				End
				if  @response = 'Integration Successful'
				Begin
					Set @Response ='Error: Integration failed for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' due to the following reason; received TSDF approval code:'+@TSDF_approval_code +' not exists in tsdfapproval for the tsdf code, company id and profit centre id:'+@tsdf_code+', '+str(@company_id) +' and'+str(@profit_ctr_id)+ ';'
					Set @flag='E'   
				End
			End		  

			Select @newsequence_id_disposal =  COALESCE(max(sequence_id),0)  from WorkOrderdetail where workorder_id = @workorder_ID_ret and resource_type=@resource_type and company_id=@company_id and profit_ctr_ID=@profit_ctr_ID
				
			Select @billing_sequence_id_disposal =  COALESCE(max(billing_sequence_id),0) from WorkOrderdetail where workorder_id = @workorder_ID_ret and resource_type=@resource_type and company_id=@company_id and profit_ctr_ID=@profit_ctr_ID


		End
		
		/*Disposal Line Validation --End*/

        If (@salesforce_resource_csid is null or @salesforce_resource_csid='') and @resource_type in ('E', 'L')  
		Begin
		   If @Response = 'Integration Successful'
			Begin
			Set @Response ='Error: Integration failed for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' due to the following reason; salesforce resource csid can not be null;'
			Set @flag='E' 
			End
			Else
			If @Response <> 'Integration Successful'
			Begin
				Set @Response = @Response +'Salesforce resource csid can not be null;'
				Set @flag='E'   
			End
		End

		If (@resource_company_id  is not null and @resource_company_id  <> '') and (@salesforce_resource_csid is not null and  @salesforce_resource_csid<>'') and @resource_type in ('E', 'L')

		Begin

			Select @ll_resource_cnt=count(*) from dbo.resource where salesforce_resource_csid=@salesforce_resource_csid
																 and company_id=@resource_company_id 
				If @ll_resource_cnt=1
				Begin
				  Select @resource_assigned = resource_code,@resource_uid = resource_uid from dbo.resource 
																						 where salesforce_resource_csid=@salesforce_resource_csid
																							    and	company_id=@resource_company_id 
			    End

				If @ll_resource_cnt=0 or  @ll_resource_cnt > 1 
				Begin
				  If @Response = 'Integration Successful'
				  Begin
					Set @Response ='Error: Integration failed for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' due to the following reason; resource not exists for the salesforce resource csid '+isnull(@salesforce_resource_csid,'N/A')+ ' and resource company id' +isnull(str(@resource_company_id),'N/A')
					Set @flag='E' 
				  End
				  Else
				  If @Response <> 'Integration Successful'
				  Begin
					 Set @Response = @Response +' Resource not exists for the salesforce resource csid '+isnull(@salesforce_resource_csid,'N/A')+ ' and resource company id' +isnull(str(@resource_company_id),'N/A')
					 Set @flag='E'   
				  End	
				End
		End
		
	    If @sales_tax_line_flag <> 'T' and @as_woh_disposal_flag <> 'T' 
		Begin
			
			If ((trim(@salesforce_invoice_line_id) IS NOT NULL  and trim(@salesforce_invoice_line_id) <> '') AND (@workorder_ID_ret is not null and @workorder_ID_ret <>'' and @workorder_ID_ret <> 0 )) 
			  Begin			  
				Select @ll_count_rec=count(*) FROM SFSWorkOrderdetail  WHERE sfs_workorderheader_uid = @sfs_workorderheader_uid and salesforce_invoice_line_id=@salesforce_invoice_line_id 
				If @ll_count_rec > 0 
				Begin
					If @Response = 'Integration Successful'
					Begin
					 Set @Response ='Error: Integration failed due to the following reason; Salesforce invoice line ID:'+isnull(@salesforce_invoice_line_id,'N/A')+ ' already exists for the received workorder id,company id and profit center id '+isnull(str(@workorder_ID_ret),'N/A')+','+isnull(str(@company_id),'N/A')+','+isnull(str(@profit_ctr_id),'N/A')+';'
					 Set @flag='E' 
					End
					Else
					If @Response <> 'Integration Successful'
					Begin
						Set @Response = @Response +'Salesforce invoice line ID:'+isnull(@salesforce_invoice_line_id,'N/A')+ ' already exists for the received workorder id,company id and profit center id '+isnull(str(@workorder_ID_ret),'N/A')+','+isnull(str(@company_id),'N/A')+','+isnull(str(@profit_ctr_id),'N/A')+';'
						Set @flag='E'   
					End	
				 End
			  End 
        End  
				 
		
		If ((trim(@salesforce_bundle_id) IS NOT NULL and trim(@salesforce_bundle_id) <> '')  AND @resource_type not in('O','D')) 
		Begin
			Select @ll_parent_bundle_cnt= count(*) from SFSWorkOrderDetail Where  sfs_workorderheader_uid = @sfs_workorderheader_uid and 
																			   salesforce_bundle_id=@salesforce_bundle_id and
																			   resource_type ='O'
                Begin 
					If @ll_parent_bundle_cnt=0 and @Response = 'Integration Successful'
					Begin
					    
						Set @Response ='Error: Integration failed for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' due to the following reason; Bundle ID received as '+isnull(@salesforce_bundle_id,'N/A')+ 'So before submitting a child bundle line, the parent bundle line must be in the workorderdetail table for the resource type OTHER;'
						Set @flag='E' 
					End
					Else 
					If @ll_parent_bundle_cnt=0 and @Response <> 'Integration Successful'
					Begin
						Set @Response = @Response +'Bundle ID received as '+isnull(@salesforce_bundle_id,'N/A')+ ' So before submitting a child bundle line, the parent bundle line must be in the workorderdetail table for the resource type OTHER;'
						Set @flag='E'   
					End	
               End
           End

		If ((trim(@salesforce_bundle_id) IS NOT NULL and trim(@salesforce_bundle_id) <> '') AND @price > 0 AND @resource_type NOT IN ('O','D'))
		
		Begin		

		        Begin
					If @Response = 'Integration Successful'
					Begin
						 Set @Response ='Error: Integration failed for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + ' due to the following reason; Bundle ID received as ' +isnull(@salesforce_bundle_id,'N/A')+ ' child bundle line price should not be grater than $0;'
						 Set @flag='E' 
					End
					Else
					Begin
						Set @Response = @Response +'Bundle ID received as ' +isnull(@salesforce_bundle_id,'N/A')+ ' child bundle Quote line price should not be grater than $0;'
						Set @flag='E'   
					End	
				End
		 End
			
			
		
		  If ((trim(@salesforce_resourceclass_CSID) IS NOT NULL and trim(@salesforce_resourceclass_CSID) <> '') and (trim(@resource_class_code) IS NOT NULL and trim(@resource_class_code) <> ''
			and @resource_type <>'D'))
		  Begin				
			select  @resource_class_cnt_hdr= count(*) from resourceclassheader where resource_class_code=@resource_class_code and 
																					 resource_type=@resource_type and 
																					 status='A' and 
																					 salesforce_resourceclass_csid=@salesforce_resourceclass_csid
			select  @resource_class_cnt_dtl= count(*) from resourceclassdetail where resource_class_code=@resource_class_code and 
																					 company_id=@company_id and 
																					 profit_ctr_id = @profit_ctr_id and
																					 bill_unit_code=@bill_unit_code and
																					 status='A'
			If 	@resource_class_cnt_hdr = 0 Or @resource_class_cnt_dtl=0 
			Begin 				
				If @Response = 'Integration Successful'
				Begin
					Set @Response ='Error: Integration failed for the Salesforce invoice line ID:' + isnull(@salesforce_invoice_line_id,'N/A') + '  due to the following reason; Resource class code:' + isnull(@resource_class_code,'N/A') + ' is not exist in EQAI resourceclassheader or resourceclassdetail table for the respective company,profit center and resource type;'
					Set @flag='E' 
				End
				Else
				Begin
					Set @Response = @Response +'Resource class code:' + isnull(@resource_class_code,'N/A') + ' is not exist in EQAI resourceclassheader or resourceclassdetail table for the respective company,profit center and resource type;'
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


            Commit Transaction
			Return -1								
		End

		If @resource_type = 'S' OR @resource_type = 'O'  OR @resource_type = 'D'
		Begin
			set @cost_class = @resource_class_code
		End

		If @resource_type = 'E' OR @resource_type = 'L'
		Begin
			select @cost_class = resource_class_code from ResourceXResourceClass
  													 where resource_code = @resource_assigned
  													 and resource_company_id = @resource_company_id
  													 and resource_class_company_id = @resource_company_id  													 
  													 and bill_unit_code = @bill_unit_code
		End
	
	 
Begin

			
			If @flag <> 'E' and NOT EXISTS (SELECT * FROM SFSWorkOrderdetail  WHERE sfs_workorderheader_uid = @sfs_workorderheader_uid and salesforce_invoice_line_id=@salesforce_invoice_line_id) 			
			Begin
			    
				
				
				Select @newsequence_id =  COALESCE(max(sequence_id),0) + 1 + @newsequence_id_disposal from SFSWorkOrderdetail where sfs_workorderheader_uid = @sfs_workorderheader_uid and resource_type=@resource_type
				
				Select @billing_sequence_id =  COALESCE(max(billing_sequence_id),0) + 1 + @billing_sequence_id_disposal from SFSWorkOrderdetail where sfs_workorderheader_uid = @sfs_workorderheader_uid and resource_type=@resource_type
				
				--Devops#89645  --Start
				IF (@resource_type ='L' OR @resource_type ='E') and (@company_id=72 or @company_id=71 or @company_id=63 or @company_id=64)
				Begin
				Set @cost_quantity= cast(@extEnded_cost as float) / cast (@cost as float)
				End
				--Devops#89645  --End					
				

				Insert into dbo.SFSworkorderdetail
						(sfs_workorderheader_uid,
                        manifest,
						salesforce_bundle_id,
						resource_type,
						added_by,
						description,
--05/16/2024 rb temporary						TSDF_code,
						TSDF_code,
						TSDF_approval_code,
						modified_by,
						extEnded_price,
						extEnded_cost,
						resource_assigned,
						salesforce_task_name,
						bill_rate,
						price_source,
						print_on_invoice_flag,
						quantity_used,
						quantity,					
						resource_class_code,
						cost,
						bill_unit_code,
						billing_sequence_id,
						company_id,
						currency_code,
						date_added,
						date_modified,
						date_service,
						prevailing_wage_code,					
						price, 
						price_class,
						profit_ctr_ID,
						sequence_id,
						group_instance_id,
						priced_flag,
						workorder_id,
						salesforce_invoice_line_id,
						cost_class,
						description_2,
                        resource_uid,
						cost_quantity,
						profile_id,
						profile_company_id,
						profile_profit_ctr_id,
						tsdf_approval_id,
						dot_shipping_name,
						manifest_hand_instruct,
						manifest_waste_desc,
						management_code,
						reportable_quantity_flag,
						RQ_reason,
						hazmat,
						hazmat_class,
						subsidiary_haz_mat_class,
						UN_NA_flag,
						package_group,
						ERG_NUMBER,
						ERG_SUFFIX,
						manifest_handling_code,
						manifest_wt_vol_unit,
						UN_NA_number,
						manifest_dot_sp_number,
						container_code,
						waste_stream,
						manifest_page_num,
						manifest_line						
						)
						VALUES
						(
                        @sfs_workorderheader_uid,
						CASE WHEN @resource_type='D' THEN NULLIF(TRIM(@manifest),'')
						ELSE NULL
						END,
						@salesforce_bundle_id,
						@resource_type,
						@user_code,
						@description,
--05/16/2024 rb temporary						@TSDF_code,
						CASE WHEN @RESOURCE_TYPE='D' THEN @TSDF_code
						ELSE NULL
						END,
						CASE WHEN @RESOURCE_TYPE='D' THEN @TSDF_approval_code
						ELSE NULL
						END,
						@user_code,
						CASE WHEN @RESOURCE_TYPE <> 'D'THEN @extEnded_price
						ELSE NULL 
						END,
						CASE WHEN @RESOURCE_TYPE <> 'D'THEN @extEnded_cost
						ELSE NULL 
						END,
						CASE WHEN @resource_type <>'D' then @resource_assigned
						ELSE NULL
						END,
						@salesforce_task_name,
						case when @resource_type ='D' and @eq_flag='T' then -1
						when @resource_type ='D' and @eq_flag='F' then 1
						ELSE @bill_rate
						END,
						CASE WHEN @RESOURCE_TYPE <> 'D'then @price_source
						ELSE NULL 
						END,				
						@print_on_invoice_flag,
						CASE WHEN @RESOURCE_TYPE <> 'D'then @quantity_used
						ELSE NULL 
						END,
						CASE WHEN @RESOURCE_TYPE <> 'D'then @quantity
						ELSE NULL 
						END,
						case when @resource_type ='D' then null
						else @resource_class_code
						end,
						case when @resource_type <> 'D' then @cost
						else NULL
						end,
						case when @resource_type <>'D' then @bill_unit_code
						else NULL
						end,
						@billing_sequence_id,
						@company_id,
						@currency_code,
						getdate(),
						getdate(),
						@date_service,					
						@prevailing_wage_code,					
						case when @resource_type <>'D' then @price
						else NULL
						end,
						case when @resource_type <>'D' then @price_class
						else NULL
						end,
						@profit_ctr_ID,
						@newsequence_id,
						case when @resource_type ='D' then NULL ELSE @group_instance_id END,					
						@priced_flag,
						@workorder_id_ret,
						@salesforce_invoice_line_id,						
						case when @resource_type ='D' then NULL  ELSE @cost_class end,
						@description_2,
                        @resource_uid,
						case when @resource_type <>'D' then @cost_quantity
						else NULL
						end,
						@profile_id,
						@profile_company_id,
						@profile_prft_ctr_id,
						@tsdf_approval_id,
						@profile_dot_shipping_name,
						@Profile_manifest_hand_instruct,
						@Profile_manifest_waste_desc,
						@TreatmentDetail_management_code,
						@Profile_reportable_quantity_flag,
						@Profile_RQ_reason,
						@Profile_hazmat,
						@Profile_hazmat_class,
						@Profile_subsidiary_haz_mat_class,
						@Profile_UN_NA_flag,
						@Profile_package_group,
						@Profile_manifest_handling_code,
						@Profile_manifest_wt_vol_unit,
						@Profile_UN_NA_number,
						@Profile_ERG_number,
						@Profile_ERG_suffix,
						@profile_manifest_dot_sp_number,
						@Profile_manifest_container_code,
						@TSDFApproval_waste_stream,
						case when @resource_type ='D' then 1
						else NULL
						end,
						case when @resource_type ='D' then @manifest_line
						else NULL
						end)
						
						
						if @@error <> 0 						
						begin
						rollback transaction						
						Set @flag = 'E'	
						SELECT @Response = 'Error: Integration failed due to the following reason; could not insert into SFSworkorderdetail table;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
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
					
					
					if @flag <> 'E' AND @RESOURCE_TYPE='D'
					BEGIN
						Exec @ll_ret_disposal=sp_sfdc_workorderdetail_Insert_disposal @workorder_id_ret,@newsequence_id,@sfs_workorderheader_uid,@manifest,@manifest_flag,@manifest_state,@eq_flag,@tsdf_approval_id,@profile_id,@customer_id,
						@extended_price,@extended_cost,@quantity,@cost,@price,@bill_unit_code,@company_id,@profit_ctr_ID, @eq_company,@eq_profit_ctr,
						@as_map_disposal_line,@as_woh_disposal_flag,@user_code,@price_source,@response
					END 
					
					If @ll_ret_disposal < 0 
				    Begin					
					Set @FLAG ='E'				
					Insert INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
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
			IF @Response = 'Integration Successful' AND @flag <> 'E' AND upper(@JSON_DATA) <> 'LIST' AND @JSON_DATA is not null	
			Begin
				EXEC @ll_ret =  sp_sfdc_workorder_json_note_insert @workorder_id_ret,
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
					Insert INTO PLT_AI_AUDIT..Source_Error_Log (Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   										SELECT
   										@key_value,
   										@source_system,
    									'Insert',
    									@Response,
    									GETDATE(),
   										@user_code
					return -1
				End	

				If @salesforce_so_csid is not null and  @salesforce_so_csid <> '' and @as_woh_disposal_flag='T'
				BEGIN

			
			    update sfsworkorderheader set salesforce_invoice_csid=@salesforce_invoice_csid,start_date=@start_date,end_date=@end_date,
				                              date_modified=getdate(),modified_by=@user_code
										where salesforce_invoice_csid=@salesforce_so_csid
										and sfs_workorderheader_uid=@sfs_workorderheader_uid
										and company_id=@company_id
										and profit_ctr_ID=@profit_ctr_ID   --During waste Disposal if SF send mutiple lines then this update will trigger at last line

				update  workorderheader set salesforce_invoice_csid=@salesforce_invoice_csid,start_date=@start_date,end_date=@end_date,
				                            date_modified=getdate(),modified_by=@user_code
											where salesforce_invoice_csid=@salesforce_so_csid 
											     and workorder_id=@workorder_id_ret_disposal   											      
												 and company_id=@company_id
												 and profit_ctr_ID=@profit_ctr_ID	--During waste Disposal if SF send mutiple lines then this update will trigger at last line	   								
							
						
				END	

			  End
			 -- commit transaction
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


Go
GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorderdetail_Insert] TO EQAI  

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorderdetail_Insert] TO svc_CORAppUser

GO
