USE [PLT_AI]
GO

/****** Object:  StoredProcedure [dbo].[sp_sfdc_new_resource_email_notification]    Script Date: 4/4/2024 3:13:13 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sp_sfdc_new_resource_email_notification] 
                      @resource_code varchar(10),
					  @salsforce_resource_csid varchar(18)


/*  
Description: 

Revision History:

DevOps# 81146  Created by Venu - 03/19/2024
Based on the Salesforce system input, if resource is not exist for the resource type equepment then 
EQAI should create the new resource in the approperiate table and will let know the EQAI distribution list

USE PLT_AI
GO
Declare @response nvarchar(max);
EXEC dbo.sp_sfdc_new_resource_email_notification
@response=@email_response output
print @response

*/

AS
DECLARE 	 	
	 @message_id int,
     @subject varchar(80),
     @body varchar(255),
     @from_user varchar(80),
     @from_email varchar(80),
     @to_email varchar(80),
     @name varchar(80)
Begin
Begin Try

	set @subject = 'New Equipment Resource created from Salesforce'
    set @body = 'A new Equipment resource:' + @resource_code +' has been created from Salesforce for the CSID:' +@salsforce_resource_csid
    set @from_user = 'SF/EQAI Integration'
    set @from_email = 'sfeqai@republicservices.com'
    Select @to_email = email_address from EmailDistributionList where group_name='DL-EQAI-SFDC Notification'
    set @name = 'SF/EQAI Integration'

	Begin

	exec @message_id = dbo.sp_message_insert  @subject, @body, '', @from_user, 'SF', NULL, NULL, NULL

    exec dbo.sp_messageAddress_insert @message_id, 'FROM', @from_email, @name, NULL, NULL, NULL, NULL

    exec dbo.sp_messageAddress_insert @message_id, 'TO', @to_email, @name, NULL, NULL, NULL, NULL

	End
End Try
Begin Catch
			INSERT INTO PLT_AI_AUDIT..Source_Error_Log (input_params,source_system_details,action,Error_description,log_date,Added_by)
										SELECT
										'Mail Notification',
										'New Resource Integaration-Email Notification',										
										'Insert',
										isnull(str(ERROR_LINE()),' ')+'Line Number failed'+ isnull(ERROR_MESSAGE(),' '),
										GETDATE(),
										User_Name()							
								
			Return -1
End CATCH
End
Return 0

GO


GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_new_resource_email_notification] TO EQAI  

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_new_resource_email_notification] TO svc_CORAppUser

GO
