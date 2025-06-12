CREATE PROCEDURE [dbo].[sp_BaselineCategoryInsert] 
    @record_type char(5),
    @customer_id int,
    @description varchar(50),
    @status char(1),
    @added_by varchar(50)
AS 

INSERT INTO [dbo].[BaselineCategory]
            ([record_type],
             [customer_id],
             [description],
             [status],
             [date_added],
             [added_by],
             [date_modified],
             [modified_by])
SELECT @record_type,
       @customer_id,
       @description,
       @status,
       GETDATE(),
       @added_by,
       GETDATE(),
       @added_by

	
	declare @newid int = scope_identity()
	exec sp_BaselineCategorySelect @newid

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineCategoryInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineCategoryInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineCategoryInsert] TO [EQAI]
    AS [dbo];

