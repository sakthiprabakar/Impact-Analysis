
USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_contact_role_upd_email_notification]    Script Date: 7/18/2024 4:35:00 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[sp_sfdc_contact_role_upd_email_notification]                     
					    @salesforce_contact_csid varchar(18),
						@customer_id int,
						@contact_id int,
						@contact_type varchar(20),					
						@first_name varchar(20),	
						@last_name varchar(20),
						@email varchar(60),						
						@contact_customer_status char(1),												
						@user_code varchar(10),
						@ll_billing_role_cnt int,
						@ls_previous_role varchar(100),
						@ls_open_billing_projects varchar(200)



/*  
Description: 

Revision History:

USs#116041  Created by Venu - 06/18/2024

*/
As
DECLARE              
     @message_id int,
     @subject varchar(80),
     @body varchar(600),
     @from_user varchar(80),
     @from_email varchar(80),
     @to_email varchar(80),
     @name varchar(80),
	 @contact_status_desc varchar(10)
Begin
Begin Try
    If @contact_customer_status='A'
	Begin
	 Set @contact_status_desc='Active'
    End
	If @contact_customer_status='I'
	Begin
	Set @contact_status_desc='In-Active'
	End

	
	--Set @contact_type=REPLACE(@contact_type, ';', CHAR(13) + CHAR(10));

    set @subject = 'Contact Modification from Salesforce'    
	
	set @body =  'The contact role for contact: ' + str(@contact_id)+ ' has been updated. The billing role is now inactivated.' + CHAR(13) + CHAR(10) +
	             'Please review the following billing projects for billing contact update:' + CHAR(13) + CHAR(10) +
				  @ls_open_billing_projects + CHAR(13) + CHAR(10) +
	             'First Name: '+Isnull(@first_name,'N/A')+ CHAR(13) + CHAR(10) +
	             'Last Name: '+isnull(@last_name,'N/A')+ CHAR(13) + CHAR(10) +
	             'email address: '+isnull(@email,'N/A')+ CHAR(13) + CHAR(10) +
				 'Customer: '+str(@customer_id)+ CHAR(13) + CHAR(10) +
				 'Contact: '+str(@contact_id)+ CHAR(13) + CHAR(10) +
				 'Salesforce Contact CSID: '+isnull(@salesforce_contact_csid,'N/A')+ CHAR(13) + CHAR(10) +
				 'Role: '+isnull(@contact_type,'N/A')+CHAR(13) + CHAR(10)+
				 'Role-Previous Value: '+isnull(@ls_previous_role,'N/A')+CHAR(13) + CHAR(10)+
				 'Contact Customer Status: '+isnull(@contact_status_desc,'N/A')+CHAR(13) + CHAR(10)+
				 'Modified by: '+isnull(@user_code,'N/A') +CHAR(13) + CHAR(10)+
				 'Modified Date: '+cast((convert(datetime,getdate())) as varchar(20))   
    
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
                                                                   'Contact change Integaration-Email Notification',                                                                  
                                                                   'Insert',
                                                                   isnull(str(ERROR_LINE()),' ')+'Line Number failed'+ isnull(ERROR_MESSAGE(),' '),
                                                                   GETDATE(),
                                                                   User_Name()                                           
                                                     
                    Return -1
End CATCH
End
Return 0



Go

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_contact_role_upd_email_notification] TO EQAI  
 
Go
 
GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_contact_role_upd_email_notification] TO svc_CORAppUser

GO
