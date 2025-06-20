USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_manifest_info_for_lookup]    Script Date: 8/20/2024 5:52:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
Create Proc [dbo].[sp_sfdc_manifest_info_for_lookup] 
				    @tsdf_approval_code varchar(40) null,
					@company_id int null,
					@profit_ctr_id int,
					@quote_project varchar(15),
					@response varchar(8000) OUTPUT
					
 
AS 
/*************************************************************************************************************
Description: 

EQAI manifest info for salesforce.

Revision History:

US#118780 -- Nagaraj M -- Initial Creation
US#128527 -- Nagaraj M -- Added Quote_Project parameter as input parameter and retrieval argument.


use plt_ai
go
Declare @response varchar(200)
exec dbo.sp_sfdc_manifest_info_for_lookup
@tsdf_approval_code='102004ECF',
@company_id=21,
@profit_ctr_id=0,
@quote_project='01052005adb5627',
@response =@response output
print @response

***************************************************************************************************************/
DECLARE 
	@key_value varchar (200),
	@ls_config_value char(1),
	@ll_cnt int,
	@source_system varchar(100)='sp_sfdc_manifest_info_for_lookup'

Begin 
	Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag_phase3'
	IF @ls_config_value is null or @ls_config_value=''
	Select @ls_config_value='F'
End
Begin
If @ls_config_value='T'
Begin
    Select @key_Value =  ' company id;' + isnull(TRIM(STR(@company_id)), '') +
						 ' profit_ctr_id;' + isnull(TRIM(STR(@profit_ctr_id)), '') +
						 ' tsdf_approval_code ' + trim(ISNULL(@tsdf_approval_code,'')) +
						 ' quote project ' + trim(ISNULL(@quote_project,'')) 

		select @ll_cnt=count(*) from workorderdetail,workorderheader 
			where workorderheader.company_id=workorderdetail.company_id
			and workorderheader.profit_ctr_id=workorderdetail.profit_ctr_id
			and workorderheader.workorder_id=workorderdetail.workorder_id
			and workorderdetail.tsdf_approval_code=@tsdf_approval_code
			and workorderdetail.company_id=@company_id 
			and workorderdetail.profit_ctr_id=@profit_ctr_id
			and workorderheader.project_code=@quote_project
			and workorderheader.submitted_flag='F'

		if @ll_cnt > 0
		Begin

			create table #manifest_lookup( manifest varchar(15),generator_id int,generator_name varchar(75),workorder_id int)
			insert into 
			#manifest_lookup
			(manifest,generator_id,generator_name,workorder_id)
			select distinct workorderdetail.manifest,
			workorderheader.generator_id,
			'',
			workorderdetail.workorder_id
			from workorderdetail,workorderheader 
			where workorderheader.company_id=workorderdetail.company_id
			and workorderheader.profit_ctr_id=workorderdetail.profit_ctr_id
			and workorderheader.workorder_id=workorderdetail.workorder_id
			and workorderdetail.tsdf_approval_code=@tsdf_approval_code
			and workorderdetail.company_id=@company_id 
			and workorderdetail.profit_ctr_id=@profit_ctr_id
			and workorderheader.project_code=@quote_project
			and workorderheader.submitted_flag='F'

			update #manifest_lookup set generator_name=Generator.generator_name
			from Generator
			where #manifest_lookup.generator_id=Generator.generator_id

			select manifest as "Manifest",generator_name as "Generator / Site Location",workorder_id as "Workorder id"
			from #manifest_lookup

			drop table #manifest_lookup
		End

		if @ll_cnt = 0
		Begin
			set @response= 'No manifest exists for the respective tsdf_approval_code: ' + @tsdf_approval_code +' ,Company id: ' + isnull(TRIM(STR(@company_id)), '') +', Profit ctr id: '+isnull(TRIM(STR(@profit_ctr_id)), '') 
							+ ' and quote project: '+isnull(TRIM(@quote_project), '')

			INSERT INTO Plt_AI_Audit..
			Source_Error_Log 
			(input_params,
			source_system_details, 
			action,
			Error_description,
			log_date, 
			Added_by) 
			SELECT 
			@key_value, 
			@source_system, 
			'Select', 
			 @response, 
			GETDATE(), 
			SUBSTRING(USER_NAME(),1,40) 
			End

end		
If @ls_config_value='F'
Begin
   Print 'SFDC Data Integration Failed,since CRM Go live flag - Phase3 is off. Hence Store procedure will not execute.'
   Return -1
End
End


GO


GO



GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_manifest_info_for_lookup] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_manifest_info_for_lookup] TO svc_CORAppUser

GO

