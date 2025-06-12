USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_tsdf_info_for_lookup]    Script Date: 2/1/2024 4:28:35 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO


CREATE PROC [dbo].[sp_sfdc_tsdf_info_for_lookup] 
AS 
  /*************************************************************************************************************
 Devops# 67716-- Venu --To pull the active TSDF info and CRM go live flag added in cofigration tbale 
 Devops 77458 --01/31/2024 Venu - Modified for the erorr handling message text change
 exec dbo.[sp_sfdc_tsdf_info_for_lookup]  
 *************************************************************************************************************/
DECLARE 
@ll_count_rec int, 
@ls_config_value char(1)='F'
BEGIN 
Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag'
IF @ls_config_value is null or @ls_config_value=''
    Select @ls_config_value='F'
End
Begin
If @ls_config_value='T'
Begin
	SELECT  @ll_count_rec = COUNT(*) FROM   TSDF WHERE tsdf_status = 'A'
IF @ll_count_rec = 0
	BEGIN   
	   INSERT INTO PLT_AI_AUDIT..Source_Error_Log (input_params,
								  source_system_details, 
								  action,
								  Error_description,
								  log_date, 
								  Added_by) 
						SELECT  'TSDF Lookup', 
								'sp_sfdc_tsdf_info_for_lookup', 
								'Select', 
								'There is no active TSDF information', 
								GETDATE(), 
								SUBSTRING(USER_NAME(),1,40) 
	END
IF @ll_count_rec > 0
	Begin
	select TSDF_Code,TSDF_EPA_ID,TSDF_name,TSDF_addr1,TSDF_city,TSDF_state,TSDF_zip_code FROM dbo.TSDF where tsdf_status='A' 
	Return 0
	END
End
If @ls_config_value='F'
Begin
	 Print 'SFDC Data Integration Failed,since CRM Go live flag off. Hence Store procedure will not execute.'	
   Return -1
End
End

Go

GO
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_tsdf_info_for_lookup] TO EQAI  
GO
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_tsdf_info_for_lookup] TO svc_CORAppUser   
GO
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_tsdf_info_for_lookup] TO COR_USER
GO
		