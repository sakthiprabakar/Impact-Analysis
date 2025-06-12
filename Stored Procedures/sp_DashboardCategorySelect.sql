CREATE PROCEDURE [dbo].[sp_DashboardCategorySelect] 
    @category_id INT = NULL,
    @description varchar(500) = NULL
/*	
	Description: 
	Searches categories (or selects single one given the category_id)

	Revision History:
	??/01/2009	RJG 	Created
*/			
AS 
	
	
	IF (@category_id IS NULL AND @description IS NULL) OR @category_id IS NOT NULL
	BEGIN
		SELECT [category_id], [added_by], [date_added], [date_modified], [description], [modified_by], [status] 
		FROM   [dbo].[DashboardCategory] 
		WHERE  ([category_id] = @category_id OR @category_id IS NULL) 
		AND status='A'
		ORDER BY [description] asc
	END
	
	IF @description IS NOT NULL
	BEGIN
		SELECT [category_id], [added_by], [date_added], [date_modified], [description], [modified_by], [status] 
		FROM   [dbo].[DashboardCategory] 
		WHERE  [description] LIKE '%' + @description + '%'
		AND status='A'
		ORDER BY [description] asc
	END

	

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardCategorySelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardCategorySelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_DashboardCategorySelect] TO [EQAI]
    AS [dbo];

