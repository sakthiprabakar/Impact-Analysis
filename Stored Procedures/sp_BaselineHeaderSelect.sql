CREATE PROCEDURE [dbo].[sp_BaselineHeaderSelect] 
    @baseline_id INT = NULL,
    @customer varchar(100) = NULL,
    @baseline_description varchar(100) = NULL,
    @start_date datetime = NULL,
    @end_date datetime = NULL,
    @custom_defined_name_1 varchar(100) = NULL,
    @custom_defined_name_2 varchar(100) = NULL,
    @custom_defined_name_3 varchar(100) = NULL,
    @status char(1) = NULL,
    @view_on_web char(1) = NULL
AS 
	SET NOCOUNT ON 

SELECT [baseline_id],
       [status],
       [view_on_web],
       BaselineHeader.[customer_id],
       Customer.cust_name,
       [baseline_description],
       [start_date],
       [end_date],
       [custom_defined_name_1],
       [custom_defined_name_2],
       [custom_defined_name_3],
       BaselineHeader.[modified_by],
       BaselineHeader.[date_modified],
       BaselineHeader.[added_by],
       BaselineHeader.[date_added]
FROM   [dbo].[BaselineHeader]
INNER JOIN Customer ON BaselineHeader.customer_id = Customer.customer_id
WHERE  
	[baseline_id] = ISNULL(@baseline_id, [baseline_id])
    AND [status] = ISNULL(@status, [status])
    AND [view_on_web]=ISNULL(@view_on_web, view_on_web)
    AND start_date = ISNULL(@start_date, start_date)
    AND end_date = ISNULL(@end_date, end_date)
    AND 1 = 
		CASE 
			WHEN @custom_defined_name_1 IS NOT NULL AND custom_defined_name_1 LIKE '%' +@custom_defined_name_1 +'%' THEN 1
			WHEN @custom_defined_name_1 IS NULL THEN 1
		END
    AND 1 = 
		CASE 
			WHEN @custom_defined_name_2 IS NOT NULL AND custom_defined_name_2 LIKE '%' +@custom_defined_name_2 +'%' THEN 1
			WHEN @custom_defined_name_2 IS NULL THEN 1
		END		
    AND 1 = 
		CASE 
			WHEN @custom_defined_name_3 IS NOT NULL AND custom_defined_name_3 LIKE '%' +@custom_defined_name_3 +'%' THEN 1
			WHEN @custom_defined_name_3 IS NULL THEN 1
		END		
		
	AND 1 = 
		CASE WHEN @customer IS NOT NULL AND Customer.cust_name LIKE '%' +@customer +'%' THEN 1 
		WHEN @customer IS NULL THEN 1
		END
		
	AND 1 =
		CASE WHEN @baseline_description IS NOT NULL AND baseline_description LIKE '%' + @baseline_description + '%' THEN 1
		WHEN @baseline_description IS NULL THEN 1
		END

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineHeaderSelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineHeaderSelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineHeaderSelect] TO [EQAI]
    AS [dbo];

