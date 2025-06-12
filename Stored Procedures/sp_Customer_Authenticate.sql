

CREATE PROCEDURE [dbo].[sp_Customer_Authenticate]
	@UserName varchar(100) = NULL,
	@Password varchar(100) = NULL,
	@contact_id int = NULL
/*	
	Location DB: PLT_AI
	
	Description: 
	Checks to see if a CONTACT has access to log into the site.  This returns all the relevant information about the contact
	This logic was copied from the existing eqonline site

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS

IF @contact_id IS NOT NULL
BEGIN
		-- now that we have username & password, get the data
		SELECT co.*, 
			   bxc.TYPE, 
			   'N' AS rail, 
			   'N' AS rail_upload
			   ,bxc.customer_id
		FROM   contact co 
			   INNER JOIN contactxref bxc 
				 ON co.contact_id = bxc.contact_id 
					AND bxc.status = 'A' 
					AND co.contact_status = 'A' 
					AND bxc.web_access = 'A' 
		WHERE  co.contact_id = @contact_id
			   AND ((bxc.TYPE = 'C' 
					 AND EXISTS (SELECT cu.customer_id 
								 FROM   customer cu 
								 WHERE  bxc.customer_id = cu.customer_id 
										AND cu.terms_code <> 'NOADMIT')) 
					 OR (bxc.TYPE = 'G' 
						 AND EXISTS (SELECT g.generator_id 
									 FROM   generator g 
									 WHERE  bxc.generator_id = g.generator_id 
											AND g.status = 'A'))) 
END                                     
ELSE
BEGIN -- check by username/password 
SELECT co.*, 
       bxc.TYPE, 
       'N' AS rail, 
       'N' AS rail_upload 
		,bxc.customer_id       
FROM   contact co 
       INNER JOIN contactxref bxc 
         ON co.contact_id = bxc.contact_id 
            AND bxc.status = 'A' 
            AND co.contact_status = 'A' 
            AND bxc.web_access = 'A' 
WHERE  co.email = @UserName 
       AND co.web_password = @Password 
       AND ((bxc.TYPE = 'C' 
             AND EXISTS (SELECT cu.customer_id 
                         FROM   customer cu 
                         WHERE  bxc.customer_id = cu.customer_id 
                                AND cu.terms_code <> 'NOADMIT')) 
             OR (bxc.TYPE = 'G' 
                 AND EXISTS (SELECT g.generator_id 
                             FROM   generator g 
                             WHERE  bxc.generator_id = g.generator_id 
                                    AND g.status = 'A'))) 
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Customer_Authenticate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Customer_Authenticate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_Customer_Authenticate] TO [EQAI]
    AS [dbo];

