
CREATE PROCEDURE [dbo].[Sp_GetContactId]  
	-- Add the parameters for the stored procedure here
	(
	@UserName varchar(200)
	)
AS 
/* ******************************************************************

	 Updated By  : Divya Bharathi R      
	 Updated On  : 09th Apr 2025      
	 Type		 : Stored Procedure      
	 Object Name : [Sp_GetContactId]      
	 Purpose     : Procedure used to get contact information of the user      
	 Change		 : Fetch only the needed columns
	 Ticket		 : DE38588 - Fetch needed columns from Contact Table
      
	 Inputs    
		@UserName      
      
	Samples:      
		EXEC Sp_GetContactId  @UserName      
		EXEC Sp_GetContactId  'paul.kalinka' 

****************************************************************** */
BEGIN
	SELECT  
	   TOP 1   
	   Ct.contact_id,  
	   Ct.contact_status,  
	   Ct.contact_company,  
	   Ct.name,  
	   Ct.title,  
	   Ct.phone,  
	   Ct.email,  
	   Ct.email_flag,  
	   Ct.modified_by,  
	   Ct.date_added,  
	   Ct.date_modified,  
	   Ct.contact_addr1,  
	   Ct.contact_city,  
	   Ct.contact_state,  
	   Ct.contact_zip_code,  
	   Ct.web_access_flag,  
	   Ct.first_name,  
	   Ct.last_name,  
	   Ct.web_userid,  
	   Ct.cc_email,  
	   CASE  
		  WHEN  
			 Roles.RoleId IS NOT NULL   
		  THEN  
			 'Y'   
		  ELSE  
			 'N'   
	   END  
	   AS IsAdminUser   
	FROM  
	   [Plt_ai].[DBO].Contact AS Ct   
	   LEFT JOIN  
		  [Plt_ai].[DBO].ContactXRole CXR   
		  ON CXR.Contact_ID = Ct.Contact_ID   
	   LEFT JOIN  
		  [COR_DB].[DBO].RolesRef AS Roles   
		  ON Roles.RoleId = CXR.RoleId   
		  AND Roles.RoleName = 'Administration'   
		  AND Roles.IsActive = 1   
	WHERE  
	   Ct.web_userid = @UserName 
END
GO

GRANT EXEC ON [dbo].[Sp_GetContactId] TO COR_USER;
GO