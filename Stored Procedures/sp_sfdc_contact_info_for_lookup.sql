USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_contact_info_for_lookup]    Script Date: 2/3/2025 2:43:10 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

ALTER   Proc [dbo].[sp_sfdc_contact_info_for_lookup] 
(                   @first_name varchar(20),
					@last_name varchar(20),
					@phone varchar(20),
					@email varchar(60),
					@contact_company varchar(75),
					@response VARCHAR(500) OUTPUT
) 
AS 
/*************************************************************************************************************
Description: 

EQAI contact info for salesforce.

Revision History:

US#116526 -- Nagaraj M -- Initial Creation
US#138789  -- Nagaraj M -- Added contact_id in the sql.


use plt_ai
go
Declare @response varchar(100)
exec dbo.sp_sfdc_contact_info_for_lookup 
@first_name = '',
@last_name = '',
@phone = '',
@email = '',
@contact_company ='BLUEPEARL SC-SUMMERVILLE',
@response =@response output
print @response

***************************************************************************************************************/
DECLARE 
	@key_value varchar (200),
	@ll_count_rec int,
	@ls_config_value char(1)='F',
	@source_system varchar(100)='sp_sfdc_contact_info_for_lookup'
Begin 
Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag_phase2'
IF @ls_config_value is null or @ls_config_value=''
    Select @ls_config_value='F'
End
Begin
If @ls_config_value='T'
Begin
Begin Try

    Select @key_Value = ' First name; ' + trim(ISNULL(@first_name,'')) +
						' Last name; ' + trim(ISNULL(@last_name,'')) +
						' Phone; ' + trim(ISNULL(@phone,'')) +
						' email; ' + trim(ISNULL(@email,'')) +
						' contact company; ' + trim(ISNULL(@contact_company,'')) 
     
	
	Begin 
	select contact_id,
		   first_name,
		   last_name,
		   phone,
		   email,
		   contact_company
		   from  contact 
		   WHERE
			contact_status='A'
			AND
			(first_name LIKE
 			CASE WHEN (@first_name) <>'' THEN '%' + (@first_name) + '%' 
			ELSE (first_name)
			END 
			AND
			last_name LIKE
 			CASE WHEN (@last_name) <>'' THEN '%' + (@last_name) + '%' 
			ELSE (last_name)
			END 
			AND
			phone LIKE
 			CASE WHEN (@phone) <>'' THEN '%' + (@phone) + '%' 
			ELSE (phone)
			END 
			AND
			email LIKE
 			CASE WHEN (@email) <>'' THEN '%' + (@email) + '%' 
			ELSE (email)
			END 
			AND
			contact_company LIKE
 			CASE WHEN (@contact_company) <>'' THEN '%' + (@contact_company) + '%' 
			ELSE (contact_company)
			END )
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
   Print 'SFDC Data Integration Failed,since CRM Go live flag - Phase2 is off. Hence Store procedure will not execute.'
   Return -1
End
End




GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_contact_info_for_lookup] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_contact_info_for_lookup] TO svc_CORAppUser

GO