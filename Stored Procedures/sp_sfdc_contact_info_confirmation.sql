USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_contact_info_confirmation]    Script Date: 5/29/2025 4:39:45 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE OR ALTER Proc [dbo].[sp_sfdc_contact_info_confirmation] 
(                  
			@contact_id int,
			@response VARCHAR(500) OUTPUT
) 
AS /*************************************************************************************************************
Description: 

EQAI contact info for salesforce.

Revision History:

US#155121 -- Nagaraj M -- Initial Creation

use plt_ai
go
Declare @response varchar(100)
exec dbo.[sp_sfdc_contact_info_confirmation] 
@contact_id=12348989,
@response =@response output
print @response

use plt_ai
go
Declare @response varchar(100)
exec dbo.[sp_sfdc_contact_info_confirmation] 
@contact_id=12348989,
@response =@response output
print @response

***************************************************************************************************************/
DECLARE 
	@key_value varchar (200),
	@ll_count_rec int,
	@ls_config_value char(1)='F',
	@source_system varchar(100)='sp_sfdc_contact_info_confirmation'
Begin 
	Select @ls_config_value = config_value From configuration where config_key='CRM_Golive_flag_phase3'
	IF @ls_config_value is null or @ls_config_value=''
		Select @ls_config_value='F'
End
Begin
If @ls_config_value='T'
	Begin
	Begin Try

		Select @key_Value = ' Contact_id; ' + isnull(trim(str(@contact_id)),'')

		select @ll_count_rec=
		count(*) from contact where contact_id=@contact_id
     
		if @ll_count_rec > 0
			Begin 
				select 
				contact_id [Contact id],
				contact_status [Contact Status],
				isnull(first_name,'') + ' ' +isnull(middle_name,'') + ' ' + isnull(last_name,'') [Full Name],
				first_name [First Name],
				middle_name [Middle Name],
				last_name [Last Name],
				email [Email Address]
				from  contact 
				WHERE
				contact_status='A'
				and contact_id=@contact_id
			End 	

			
			if @ll_count_rec = 0 
			Begin
			set	@response ='No results exists for the contact_id: ' + isnull(trim(str(@contact_id)),'')

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
   set @response= 'SFDC Data Integration Failed,since CRM Go live flag - Phase3 is off. Hence Store procedure will not execute.'
   Return -1
End
End

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_contact_info_confirmation] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_contact_info_confirmation] TO COR_USER
 
GO
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_contact_info_confirmation] TO svc_CORAppUser
 
GO