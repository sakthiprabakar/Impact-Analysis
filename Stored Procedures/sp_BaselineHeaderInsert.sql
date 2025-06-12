CREATE PROCEDURE [dbo].[sp_BaselineHeaderInsert] 
    @status char(1),
    @view_on_web char(1),
    @customer_id int,
    @baseline_description varchar(50),
    @start_date datetime,
    @end_date datetime,
    @custom_defined_name_1 varchar(50),
    @custom_defined_name_2 varchar(50),
    @custom_defined_name_3 varchar(50),
    @added_by varchar(20)
AS 

	INSERT INTO [dbo].[BaselineHeader]
                ([status],
                 [view_on_web],
                 [customer_id],
                 [baseline_description],
                 [start_date],
                 [end_date],
                 [custom_defined_name_1],
                 [custom_defined_name_2],
                 [custom_defined_name_3],
                 [modified_by],
                 [date_modified],
                 [added_by],
                 [date_added])
    SELECT @status,
           @view_on_web,
           @customer_id,
           @baseline_description,
           @start_date,
           @end_date,
           @custom_defined_name_1,
           @custom_defined_name_2,
           @custom_defined_name_3,
           @added_by,
           GETDATE(),
           @added_by,
           GETDATE()
    
    declare @newid int = SCOPE_IDENTITY()
    exec sp_BaselineHeaderSelect @newid

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineHeaderInsert] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineHeaderInsert] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineHeaderInsert] TO [EQAI]
    AS [dbo];

