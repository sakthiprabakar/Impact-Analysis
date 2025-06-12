USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_customer_info_for_lookup]    Script Date: 8/20/2024 6:27:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

ALTER Proc [dbo].[sp_sfdc_customer_info_for_lookup] 
(                   @ax_invoice_customer_id varchar(20),						
					@response VARCHAR(500) OUTPUT
) 
AS 
/*************************************************************************************************************
Description: 

EQAI Customer info for salesforce.

Revision History:

Devops 85893 -- Venu-- Initial Creation
Devops# 87468  fix deployment script review comments by Venu
US#122562  -- Venu added the new field in lookup sfdc_billing_package_flag
use plt_ai
go
Declare @response varchar(100)
exec dbo.sp_sfdc_customer_info_for_lookup 
@ax_invoice_customer_id = 'C021556',
@response=@response output
print @response

***************************************************************************************************************/
DECLARE 
	@key_value varchar (100), 
	@ll_count_rec int,
	@ls_config_value char(1)='F',
	@source_system varchar(100)='sp_sfdc_customer_info_for_lookup'
Begin 
Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag'
IF @ls_config_value is null or @ls_config_value=''
    Select @ls_config_value='F'
End
Begin
If @ls_config_value='T'
Begin
Begin Try

    Select @key_Value = 'ax_invoice_customer_id; ' + trim(ISNULL(@ax_invoice_customer_id,'')) 
     
	Select  @ll_count_rec = COUNT(*) FROM customer 
			WHERE ax_invoice_customer_id = @ax_invoice_customer_id
			AND cust_status='A'

     If @ll_count_rec=0
     Begin

		Select @response = 'Error: Lookup failed due to the following reason ax_invoice_customer_id:'+isnull(@ax_invoice_customer_id,'N/A')+ ' is not valid or not exists , provide any of the other parameters to search.'
		

		Insert Into Plt_AI_Audit..Source_Error_Log (input_params,
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

	If @ll_count_rec > 0
	Begin 
	select customer_id,cust_name,
		   eq_flag,
		   msg_customer_flag,
		   retail_customer_flag,
		   national_account_flag,
		   isnull(cust_addr1,' ')+' '+ isnull(cust_addr2,' ')+' '+ isnull(cust_addr3,' ')+' '+ isnull(cust_addr4,' ')+' '+ isnull(cust_addr5,' ') as "customer Address",
		   cust_city,
		   cust_state,
		   cust_zip_code,cust_country,sfdc_billing_package_flag
		   from  customer where ax_invoice_customer_id=@ax_invoice_customer_id and cust_status='A'
	End 	
END TRY 
BEGIN CATCH			
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
				ERROR_MESSAGE(), 
				GETDATE(), 
				SUBSTRING(USER_NAME(),1,40) 
END CATCH 
End
If @ls_config_value='F'
Begin
   Print 'SFDC Data Integration Failed,since CRM Go live flag off. Hence Store procedure will not execute.'
   Return -1
End
End

Go

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_customer_info_for_lookup] TO EQAI  

Go

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_customer_info_for_lookup] TO svc_CORAppUser

Go