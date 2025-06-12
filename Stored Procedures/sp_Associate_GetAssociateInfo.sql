CREATE PROCEDURE [dbo].[sp_Associate_GetAssociateInfo]
	@UserName varchar(100) = NULL,
	@user_id int = NULL
/*	
	Description: 
	Gets all the relevant information about a user based on the user_id or the user_code

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS

	--SELECT group_id, change_password, email, b2b_access, b2b_remote_access FROM users WHERE user_code = @UserName

	IF(@UserName IS NOT NULL)
	BEGIN
	
		select 
		users.user_id as [user_id],
		users.user_code as [user_code],
		null as contact_id,
		group_id, 
		change_password, 
		email, 
		b2b_access, 
		b2b_remote_access,
		user_name + case when group_id = 0 then ' (Terminated)' else '' end as name, 
		user_name as contact_name, 
		email as email_address, 
		phone, 
		'A' as associate, 
		'F' as rail, 
		'F' as rail_upload, 
		left(user_name,charindex(' ',user_name)) as first_name, 
		right(user_name,len(user_name) - charindex(' ',user_name)) as last_name 
		from users where user_code = @UserName 
		-- 
		and group_id <> 0	
		
	END
	
	IF @user_id IS NOT NULL
	BEGIN
		select 
		users.user_id as [user_id],
		users.user_code as [user_code],
		null as contact_id,
		group_id, 
		change_password, 
		email, 
		b2b_access, 
		b2b_remote_access,
		user_name + case when group_id = 0 then ' (Terminated)' else '' end as name, 
		user_name as contact_name, 
		email as email_address, 
		phone, 
		'A' as associate, 
		'F' as rail, 
		'F' as rail_upload, 
		left(user_name,charindex(' ',user_name)) as first_name, 
		right(user_name,len(user_name) - charindex(' ',user_name)) as last_name 
		from users where user_id = @user_id 
		-- 
		and group_id <> 0		
	END
	


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Associate_GetAssociateInfo] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Associate_GetAssociateInfo] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Associate_GetAssociateInfo] TO [EQAI]
    AS [dbo];

