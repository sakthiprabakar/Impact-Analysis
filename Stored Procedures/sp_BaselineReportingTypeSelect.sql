CREATE PROCEDURE [dbo].[sp_BaselineReportingTypeSelect] 
    @reporting_type_id INT = NULL
AS 
	SET NOCOUNT ON 

	SELECT [reporting_type_id],
           [status],
           [display_order],
           [reporting_type],
           [date_added],
           [added_by],
           [date_modified],
           [modified_by]
    FROM   [dbo].[BaselineReportingType]
    WHERE  ( [reporting_type_id] = @reporting_type_id
              OR @reporting_type_id IS NULL ) 
             AND status='A'
             order by display_order

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineReportingTypeSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineReportingTypeSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineReportingTypeSelect] TO [EQAI]
    AS [dbo];

