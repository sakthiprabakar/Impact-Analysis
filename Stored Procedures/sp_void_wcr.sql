
CREATE PROCEDURE sp_void_wcr
	 @contact_id	INT
	,@user_name		VARCHAR(60)
	,@form_id		INT
	,@revision_id	INT
AS
/**********************************************************************************
sp_void_wcr

9/27/2012	TMO	Initial writing


Change status from active for a profile.  This way it does not appear on the web.

exec sp_void_wcr @contact_id = 10913, @user_name = 'Customer.Demo', @form_id = 194860, @revision_id = 1

SELECT * FROM FormWCR where form_id = 194860

*********************************************************************************/
-- IF CALLER CAN SEE THE REQUESTED FORM
IF EXISTS (SELECT TOP (1) 1 FROM dbo.FormWCR f INNER JOIN dbo.ContactXRef c
				ON f.customer_id = c.customer_id
					WHERE	contact_id		= @contact_id 
					AND		f.form_id		= @form_id 
					AND		f.revision_id	= @revision_id)
OR @contact_id = 0
	UPDATE dbo.FormWCR
	SET  status			= 'I'
		,date_modified	= GETDATE()
		,modified_by	= @user_name
	WHERE
		form_id		= @form_id AND
		revision_id	= @revision_id
		
--ELSE
	-- do nothing

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_void_wcr] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_void_wcr] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_void_wcr] TO [EQAI]
    AS [dbo];

