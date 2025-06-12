
CREATE PROCEDURE [dbo].[Sp_GetContactId]  
	-- Add the parameters for the stored procedure here
	(
	@UserName varchar(200)
	)
AS 
/* ******************************************************************

	Updated By		: Arun kumar
	Updated On		: 24th Dec 2018
	Type			: Stored Procedure
	Object Name		: [Sp_GetContactId]


	Procedure used to get contact ID from web_userid

inputs 
	
	@UserName



Samples:
    EXEC Sp_GetContactId  @UserName
    EXEC Sp_GetContactId  'paul.kalinka' 

****************************************************************** */
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	Declare @contactId int
    -- Insert statements for procedure here
	SELECT top 1 * from [Plt_ai].[DBO].Contact as [User]
		OUTER APPLY(SELECT 
		CASE WHEN COUNT(*)>0 THEN 'Y' ELSE 'N' END AS IsAdminUser FROM [COR_DB]..RolesRef as Roles 
		WHERE  RoleName='Administration' AND IsActive=1 AND Roles.RoleId IN (SELECT CXR.RoleId FROM [Plt_ai].[DBO].ContactXRole CXR WHERE CXR.Contact_ID = [User].Contact_ID)) roles
		WHERE web_userid = @UserName
	--print @contactId
	return 
	-- @contactId
END
GO

GRANT EXEC ON [dbo].[Sp_GetContactId] TO COR_USER;
GO