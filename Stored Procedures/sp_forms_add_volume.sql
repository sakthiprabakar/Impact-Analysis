
CREATE PROCEDURE sp_forms_add_volume(
 @form_id			int,
 @revision_id		int,
 @quantity			varchar(255)	= NULL,
 @bill_unit_code	nvarchar(15)	= NULL
)
AS
/****************
11/23/2011 CRG Created
sp_forms_add_volume
Changed to generic form_id's

--SELECT * FROM formXUnit where form_id = -378160
*****************/
DECLARE @form_type varchar(10) = (SELECT type from formheader WHERE form_id = @form_id AND revision_id = @revision_id)

INSERT INTO [dbo].[FormXUnit]
           ([form_id]
           ,[revision_id]
           ,[bill_unit_code]
           ,[quantity]
           ,[form_type])
     VALUES
           (@form_id
           ,@revision_id 
           ,@bill_unit_code
           ,@quantity
           ,@form_type)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_add_volume] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_add_volume] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_forms_add_volume] TO [EQAI]
    AS [dbo];

