USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_jobbilling_closedate_upd]    Script Date: 6/12/2024 9:55:17 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create PROCEDURE [dbo].[sp_sfdc_jobbilling_closedate_upd] 
				@salesforce_jobbillingproject_csid varchar(18),
				@salesforce_salesorder_close_date datetime,
				@employee_id varchar(20),
				@response nvarchar(max) output

/*
Description: 

API call will be made from salesforce team to update the "salesforce_salesorder_close_date" in the customer billing table.


Revision History:

DevOps# 85439 - 04/26/2024  Nagaraj M   Created
Devops# 87468  fix deployment script review comments by Venu

USE PLT_AI
GO
Declare @response nvarchar(max)
EXECUTE dbo.SP_SFDC_jobbilling_closedate_upd
@salesforce_jobbillingproject_csid='APR012_010',
@salesforce_salesorder_close_date = '04/24/2024',
@employee_id='864502',
@response=@response output
print @response

*/
AS
BEGIN
declare @source_system varchar(500),
@LL_COUNT int,
@key_value varchar(200), --VR
@user_code varchar(20),
@flag char(1) = 'U',
@salesforce_salesorder_close_date_upd datetime,
@validation_req_field varchar(100),
@validation_req_field_value varchar(500),
@validation_response varchar(1000), --Venu Modified for review comments
@ll_validation_ret int,
@ls_config_value char(1)


	select @ls_config_value = config_value
	from configuration
	where config_key='CRM_Golive_flag'

	if coalesce(@ls_config_value,'') = ''
	set @ls_config_value='F'

--only allow addition of documents if go-live config value is True
	if @ls_config_value = 'T'
	begin
	Select @source_system = 'SP_SFDC_jobbilling_closedate_upd:: ' + 'Sales force' 

	Create table #temp_salesforce_validation_fields (validation_req_field varchar(100),validation_req_field_value varchar(500))  /*To determine the validation requried field*/
		Insert into  #temp_salesforce_validation_fields (validation_req_field,validation_req_field_value) values 
		                                                 ('salesforce_jobbillingproject_csid',(@salesforce_jobbillingproject_csid)),
														 ('employee_id',(@employee_id))


	SELECT
		@key_value =	' salesforce_jobbillingproject_csid;'+ isnull(@salesforce_jobbillingproject_csid,'') + 
						' salesforce_salesorder_close_date;'+ cast((convert(datetime,@salesforce_salesorder_close_date)) as varchar(20))

	SELECT @response = 'Integration Successful'

		Declare sf_validation CURSOR for
					select validation_req_field,validation_req_field_value from #temp_salesforce_validation_fields
					Open sf_validation
						fetch next from sf_validation into @validation_req_field,@validation_req_field_value		
						While @@fetch_status=0
						Begin						   
						   EXEC @ll_validation_ret=dbo.sp_sfdc_input_parm_validation 'SP_SFDC_jobbilling_closedate_upd',@validation_req_field,@validation_req_field_value,21,0,@validation_response output

						    If @validation_req_field='employee_id' and @ll_validation_ret <> -1
								Begin
								EXEC dbo.sp_sfdc_get_usercode @employee_id,@user_code output     
								End
								if @ll_validation_ret = -1
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



	If @flag <> 'E'	
	Begin
		update customerbilling set 
		salesforce_salesorder_close_date=@salesforce_salesorder_close_date,
		date_modified=getdate(),
		modified_by=@user_code
		where salesforce_jobbillingproject_csid =@salesforce_jobbillingproject_csid
		and status = 'A'

		SELECT @salesforce_salesorder_close_date_upd= salesforce_salesorder_close_date
		FROM customerbilling
		where salesforce_jobbillingproject_csid =@salesforce_jobbillingproject_csid
		
		

		if @salesforce_salesorder_close_date_upd=@salesforce_salesorder_close_date
		begin
		select @response='Update Succesful for the salesforce_jobbillingproject_csid ' + @salesforce_jobbillingproject_csid
		end
	end	
		if @salesforce_salesorder_close_date_upd <> @salesforce_salesorder_close_date
		Begin
			SELECT @Response = 'Error: Update failed, ' + isnull(ERROR_MESSAGE(),' ')
   			INSERT INTO PLT_AI_AUDIT..Source_Error_Log
			(Input_Params,source_system_details,action,Error_description,log_date,Added_by)
   												SELECT
   												@key_value,
   												@source_system,
    												'Update',
    												@Response,
    												GETDATE(),
												@user_code
				Return -1
				End
	END
END

if @ls_config_value='F'
begin
	Select @Response= 'SFDC Data Integration Failed,since CRM Go live flag off. Hence Store procedure will not execute.'
	return -1
end
return 0


GO


Go

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_jobbilling_closedate_upd] TO EQAI  

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_jobbilling_closedate_upd] TO svc_CORAppUser

Go
