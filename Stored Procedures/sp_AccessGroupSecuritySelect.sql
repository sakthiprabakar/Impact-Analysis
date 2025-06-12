CREATE PROCEDURE [dbo].[sp_AccessGroupSecuritySelect] 
    @group_id INT = NULL,
    @user_id int,
    @permission_id int = NULL,
    @return_copc_access char(1) = 'F',
    @return_customer_access char(1) = 'F',
    @return_generator_access char(1) = 'F',
    @return_territory_access char(1) = 'F',
    @return_linked_access char(1) = 'F'
    
	
	/*
	Description: 
	Given a group_id, will return the requested security information.  This will always
	return 3 result sets but will be empty if it is not requested.
	#1 -- Company  / Profit Center access
	#2 -- Customer access
	#3 -- Generator access
	
	IMPORTANT: The -9999 code is used in AccessGroupSecurity to denote "all access"

	Revision History:
	??/01/2009	RJG 	Created
	12/08/2009	RJG		Added Status=A filter
	
	
	*/
	
AS 
	SET NOCOUNT ON 
	SET XACT_ABORT ON  
	


	IF @return_copc_access = 'T'
	BEGIN
		SELECT * FROM dbo.fn_GetAccess_CompanyProfitCenter(null, @user_id, null, @group_id, @permission_id)
	END
	ELSE
	BEGIN
		SELECT * FROM dbo.fn_GetAccess_CompanyProfitCenter(0, 0, 0, 0, 0)
	END

	
	
	
	IF @return_customer_access = 'T'
	BEGIN
		SELECT * FROM dbo.fn_GetAccess_Customer(null, @user_id, null, @group_id, @permission_id)
	END
	ELSE
	BEGIN
		SELECT * FROM dbo.fn_GetAccess_Customer(0, 0, 0, 0, 0)
	END




	IF @return_generator_access = 'T'
	BEGIN
		SELECT * FROM dbo.fn_GetAccess_Generator(null, @user_id, null, @group_id, @permission_id)
	END 
	ELSE
	BEGIN
		SELECT * FROM dbo.fn_GetAccess_Generator(0, 0, 0, 0, 0)
	END



	IF @return_territory_access = 'T'
	BEGIN
		SELECT * FROM dbo.fn_GetAccess_Territory(null, @user_id, null, @group_id, @permission_id)
	END 
	ELSE
	BEGIN
		SELECT * FROM dbo.fn_GetAccess_Territory(0, 0, 0, 0, 0)
	END 
	
	
	
	IF @return_linked_access = 'T'
	BEGIN
		SELECT * FROM dbo.fn_GetAccess_Linked(null, @user_id, null, @group_id, @permission_id)
	END 
	ELSE
	BEGIN
		SELECT * FROM dbo.fn_GetAccess_Linked(0, 0, 0, 0, 0)
	END 




GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecuritySelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecuritySelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_AccessGroupSecuritySelect] TO [EQAI]
    AS [dbo];

