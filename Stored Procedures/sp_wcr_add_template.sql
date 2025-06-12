
CREATE PROCEDURE sp_wcr_add_template(
	 @form_id			int,
	 @user				varchar(100)	= NULL,
	 @name				varchar(255)	= NULL,
	 @description		varchar(800)	= NULL
)
AS
/****************
11/23/2011 CRG Created
sp_wcr_add_template
Creates a new template from given wcr form id and revision id
--exec sp_wcr_add_template @form_id = 216381 , @user = 'corey_go', @name = 'Test Template', @description = 'Test of the wcr template system.'
*****************/

INSERT INTO [dbo].[FormWCRTemplate]
           ([template_form_id]
           ,[name]
           ,[description]
           ,[created_by]
           ,[date_created]
           ,[modified_by]
           ,[date_modified])
     VALUES
           (@form_id
           ,@name
           ,@description
           ,@user
           ,GETDATE()
           ,@user
           ,GETDATE())


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wcr_add_template] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wcr_add_template] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_wcr_add_template] TO [EQAI]
    AS [dbo];

