
CREATE PROCEDURE [dbo].[sp_BaselineCategoryUpdate] 
    @baseline_category_id int,
    @record_type char(1),
    @customer_id int,
    @description varchar(50),
    @status char(1),
    @modified_by varchar(50)
AS 
	SET NOCOUNT ON 
	UPDATE [dbo].[BaselineCategory]
    SET    [record_type] = @record_type,
           [customer_id] = @customer_id,
           [description] = @description,
           [status] = @status,
           [date_modified] = GETDATE(),
           [modified_by] = @modified_by
    WHERE  [baseline_category_id] = @baseline_category_id 
    
	declare @newid int = scope_identity()
	exec sp_BaselineCategorySelect @newid

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineCategoryUpdate] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineCategoryUpdate] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineCategoryUpdate] TO [EQAI]
    AS [dbo];

