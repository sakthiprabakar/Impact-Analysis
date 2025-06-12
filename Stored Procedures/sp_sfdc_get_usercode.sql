USE [PLT_AI]
GO
/****** Object:  StoredProcedure [dbo].[sp_sfdc_get_usercode]    Script Date: 4/4/2024 3:03:07 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_sfdc_get_usercode] 
						@employee_id varchar(20),
						@user_code varchar(10) OUTPUT
											   					


/*  
Description: 

DevOps# 81419  Created by Venu - 03/19/2024
To get the user_code based on the employee id which are passed from salesforce.

USE PLT_AI
GO
Declare @user_code varchar(10);
EXEC dbo.sp_sfdc_get_usercode
@employee_id='123',
@user_code=@user_code output
print @user_code

*/

AS
DECLARE 	 	
	 @ll_ret int 
Begin
	Begin TRY			
		
    Select @ll_ret= count(*) from dbo.users where employee_id=@employee_id

	If @ll_ret = 1 
	Begin
		Select @user_code= user_code from dbo.users where employee_id=@employee_id
		Return 1
	End
	Else
	Set @user_code='N/A'

	End Try		

	Begin Catch
	  INSERT INTO PLT_AI_AUDIT..Source_Error_Log (input_params,source_system_details,action,Error_description,log_date,Added_by)
											SELECT
											@employee_id,
											'Salesforce- Get User Code',											
											'Select',
											isnull(str(ERROR_LINE()),' ')+'Line Number failed'+ isnull(ERROR_MESSAGE(),' '),
											GETDATE(),
											@user_code
										
		Set @user_code='N/A'							
		Return -1
	End CATCH
End
Return 0

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_get_usercode] TO EQAI  

GO

GRANT EXECUTE ON OBJECT::[dbo].[sp_sfdc_get_usercode] TO svc_CORAppUser

Go
