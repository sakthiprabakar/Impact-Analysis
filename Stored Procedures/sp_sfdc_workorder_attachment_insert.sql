USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_workorder_attachment_insert]    Script Date: 11/18/2024 5:21:06 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--Devops# 83361


ALTER procedure [dbo].[sp_sfdc_workorder_attachment_insert]
	@salesforce_invoice_csid varchar(18),
	@company_id int,
	@profit_ctr_id int,
	@document_type_id int,
	@file_name varchar(80),
	@user varchar(10),
	@attachment_hex varchar(max), 
	@source_system varchar(100)='Sales Force',
	@employee_id varchar(20)=Null,
    @Response varchar(200) OUT
as
/*
	12/05/2023	rb	Created - Support adding attachments to a work order
	Devops# 76453 01/04/2024 Venu Modified the Procedure - Implement the validation for all the required fields.
    Devops# 77331 01/19/2024 Venu Modified the Procedure - replaced the input salesforce invoice csid instead workorder id 
	Devops# 77458 --01/31/2024 Venu - Modified for the erorr handling messgae text change
    Devops# 77568 --02/7/2024 Rob - Modified to accept the file extension four charector. Changed the datatype from varchar(3) to varchar(4)
	Devops# 79669  --02/28/2024  Venu - Modified to change the default value
	Devops# 81419 -- 03/19/2024 Venu Populate the user_code to added_by and modified_by fields
    Devops# 83361 - 04/29/2024 Rob - Populate Salesforce staging tables instead of actual EQAI tables (for fully transactional integration)
	US#129733  - 11/13/2024 Venu Added the workorderheader validation during attachement call fi the billing pacakage submiited using single JSON
	/*Declare @response varchar(200);
	exec dbo.sp_sfdc_workorder_attachment_insert 
	@workorder_id=123456,
	@company_id=14,
	@profit_ctr_id=17,
	@document_type_id=20,
	@file_name='D365_Certificate.pdf',
	@user='ROB_B',
	@attachment_hex='0x12345678',
	@response=@response output
	print @response
	*/

	Declare @response varchar(200);
	exec dbo.sp_sfdc_workorder_attachment_insert 
	@salesforce_invoice_csid='FEB01_24_001',
	@company_id=21,
	@profit_ctr_id=0,
	@document_type_id=20,
	@file_name='D365_Certificate.pdf',
	@user='ROB_B',
	@attachment_hex='0x12345678',
	@employee_id='VENU',
	@response=@response output
	print @response

	--exec dbo.sp_sfdc_workorder_attachment_insert 123456, 14, 17, 20, 'D365_Certificate.pdf', 'ROB_B', '0x12345678','VENU'
*/
declare
	@current_db	varchar(60),
	@file_ext varchar(4),
	@doc_name varchar(50),
	@sql varchar(1000),
	@customer_id int,
	@generator_id int,
	@image_id int,
	@i int,
	@ls_config_value char,
	@key_value varchar(2000),
	@ll_cnt int,
	@flag char(1 )= 'S',
	@validation_req_field varchar(100),
    @validation_req_field_value varchar(500),
	@validation_resposne nvarchar(max),
	@ll_validation_ret int,
	@workorder_ID int=null,
	@user_code varchar(10)='N/A',
    @sfs_workorderheader_uid int,
	@count int

set transaction isolation level read uncommitted

select @ls_config_value = config_value
from configuration
where config_key='CRM_Golive_flag'

if coalesce(@ls_config_value,'') = ''
   set @ls_config_value='F'

select @count = count(*)
from dbo.SFSWorkorderHeader
where salesforce_invoice_CSID = @salesforce_invoice_csid

If @count > 0
Begin
	select @sfs_workorderheader_uid = max(sfs_workorderheader_uid)
	from dbo.SFSWorkorderHeader
	where salesforce_invoice_CSID = @salesforce_invoice_csid

	select @workorder_id = workorder_id,
		   @customer_id = customer_id,
		   @generator_id = generator_id
	from dbo.SFSWorkorderHeader
	where sfs_workorderheader_uid = @sfs_workorderheader_uid
End



--only allow addition of documents if go-live config value is True
if @ls_config_value = 'T'
begin
   
    Set @source_system = 'sp_sfdc_workorder_attachment_insert:: ' + @source_system  
	Set @Response='Integration Successful'
	
    Create table #temp_salesforce_validation_fields (validation_req_field varchar(100),validation_req_field_value varchar(500))  /*To determine the validation requried field*/
	Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
																 ('company_id',str(@company_id)),
																 ('profit_ctr_id',str(@profit_ctr_id)),
																 ('document_type_id',str(@document_type_id)),
																 ('salesforce_invoice_csid',@salesforce_invoice_csid),
																 ('employee_id',@employee_id)
																 

	Select @key_value = 'salesforce_invoice_csid; ' + isnull(@salesforce_invoice_csid ,'')+ 
	                    ' company_id;' + cast((convert(int,@company_id)) as varchar(20))+		
						' profit_ctr_id;' + cast((convert(int,@profit_ctr_id)) as varchar(20))+				                
						' document_type_id;' + cast((convert(int,isnull(@document_type_id,''))) as varchar(20))+				                					    
					    ' file_name;' +isnull(@file_name,'')+ 
						' user;' +isnull(@user,'')+ 
						' attachment_hex;' +isnull(@attachment_hex,'') +
						' employee_id;' +isnull(@employee_id,'')		

    						
    
    Declare sf_validation CURSOR fast_forward for
			select validation_req_field,validation_req_field_value from #temp_salesforce_validation_fields
			Open sf_validation
				fetch next from sf_validation into @validation_req_field,@validation_req_field_value		
				While @@fetch_status=0
				Begin				  
				   EXEC @ll_validation_ret=dbo.sp_sfdc_input_parm_validation 'sp_sfdc_workorder_attachment_insert',@validation_req_field,@validation_req_field_value,@company_id,@profit_ctr_id,@validation_resposne output

					/*If @validation_req_field='salesforce_invoice_csid' and @ll_validation_ret <> -1
					Begin
					Select @workorder_ID = workorder_id from dbo.workorderheader 
															where salesforce_invoice_csid=@salesforce_invoice_csid  
																and company_id=@Company_id 
																and profit_ctr_id=@profit_ctr_id
					End*/

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
	

	
	If @count = 0
	Begin
	    --Determine customer_id and generator_id
		select @workorder_id = workorder_id,
		       @customer_id = customer_id, 
			   @generator_id = generator_id
				from dbo.WorkorderHeader
				where salesforce_invoice_csid = @salesforce_invoice_csid
					  and company_id=@company_id
					  and profit_ctr_id=@profit_ctr_id
	End






	--Determine current image database
	select @current_db = current_database
	from Plt_image..ScanCurrentDB

	--Determine file extension
	set @i = len(@file_name)
	while @i > 0
	begin
		if substring(@file_name, @i, 1) = '.'
			break

		set @i = @i - 1
	end
	if @i > 0
		set @file_ext = substring(@file_name, @i + 1, 4)


	--------------------
	-- BEGIN TRANSACTION
	--------------------
	begin transaction

	--Generate a new image_id
	update Sequence
		set @image_id = next_value,
		next_value = next_value + 1
	where name = 'ScanImage.image_id'

	if @@error <> 0
	begin
	 rollback transaction
	 SELECT @Response = 'Error: Integration failed due to the following reason; could not allocate new image_id;' + isnull(ERROR_MESSAGE(),'Please check source_error_log table in EQAI')
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

	Begin

	    --Derive a <=50 character document name
	    set @doc_name = substring('DOC' + convert(varchar(10),@image_id) + '_' + replace(@file_name,'.' + @file_ext,''), 1, 46) + coalesce('.' + @file_ext,'')

		If @count > 0
		Begin
			--Insert into ScanImage table
			set @sql = N'insert dbo.SFSScanImage (sfs_workorderheader_uid, image_id, image_blob) values ('
					+ convert(varchar(10), @sfs_workorderheader_uid) + N', ' + convert(nvarchar(20),@image_id) + N', ' + @attachment_hex + N')'	
		
		
			exec (@sql)

			if @@error <> 0
			begin
			 rollback transaction
			 SELECT @Response = 'Error: Integration failed due to the following reason;could not insert SFSScanImage record; please check source_error_log table in EQAI.' + isnull(ERROR_MESSAGE(),' ')
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

			--Insert into Scan table
			insert dbo.SFSScan (sfs_workorderheader_uid, company_id, profit_ctr_id, image_id, document_source, type_id, status, document_name,
									   date_added, date_modified, added_by, modified_by, customer_id, manifest, manifest_flag, workorder_id, generator_id,
									   invoice_print_flag, image_resolution, scan_file, description, form_type, file_type, view_on_web, app_source, upload_date)
			values (@sfs_workorderheader_uid, @company_id, @profit_ctr_id, @image_id, 'workorder', @document_type_id, 'A', @doc_name,
					getdate(), getdate(), @user_code, @user_code, @customer_id, '', '', @workorder_id, @generator_id,
					'T', 100, @doc_name, replace(@doc_name, '_', ' '), 'ATTACH', @file_ext, 'T', 'SF', getdate())

			if @@error <> 0
			begin
			 rollback transaction
			 SELECT @Response = 'Error: Integration failed due to the following reason;could not insert SFSscan record; please check source_error_log table in EQAI.' + isnull(ERROR_MESSAGE(),' ')
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

		If @count = 0
		Begin
			--Insert into ScanImage table
			set @sql = N'insert ' + @current_db + N'.dbo.ScanImage (image_id, image_blob) values ('
				+ convert(nvarchar(20),@image_id) + N', ' + @attachment_hex + N')'
		
			execute(@sql)

			if @@ERROR <> 0
			begin
				rollback transaction
				SELECT @Response = 'Error: Integration failed due to the following reason;could not insert Scanimage record; please check source_error_log table in EQAI.' + isnull(ERROR_MESSAGE(),' ')
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
		
			--Insert into Scan table
			insert Plt_image.dbo.scan (company_id, profit_ctr_id, image_id, document_source, type_id, status, document_name,
									   date_added, date_modified, added_by, modified_by, customer_id, manifest, manifest_flag, workorder_id, generator_id,
									   invoice_print_flag, image_resolution, scan_file, description, form_type, file_type, view_on_web, app_source, upload_date)
			values (@company_id, @profit_ctr_id, @image_id, 'workorder', @document_type_id, 'A', @doc_name,
					getdate(), getdate(), @user_code, @user_code, @customer_id, '', '', @workorder_id, @generator_id,
					'T', 100, @doc_name, replace(@doc_name, '_', ' '), 'ATTACH', @file_ext, 'T', 'SF', getdate())

			if @@error <> 0
			begin
			 rollback transaction
			 SELECT @Response = 'Error: Integration failed due to the following reason;could not insert Scan record; please check source_error_log table in EQAI.' + isnull(ERROR_MESSAGE(),' ')
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
	     end
	End



--------------------
--COMMIT TRANSACTION
--------------------
commit transaction
	
end

if @ls_config_value='F'
begin
	Select @Response= 'SFDC Data Integration Failed,since CRM Go live flag off. Hence Store procedure will not execute.'
	return -1
end

return 0


Go





GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorder_attachment_insert] TO EQAI  

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_workorder_attachment_insert] TO svc_CORAppUser

