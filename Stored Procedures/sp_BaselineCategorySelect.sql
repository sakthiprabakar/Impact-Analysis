CREATE PROCEDURE [dbo].[sp_BaselineCategorySelect] 
    @baseline_category_id INT = NULL,
    @description varchar(100) = NULL,
    @customer_id_list varchar(max) = NULL,
    @record_type varchar(10) = NULL,
    @status varchar(20) = 'A'
AS 
	SET NOCOUNT ON 
	
	IF LEN(@customer_id_list) = 0
		set @customer_id_list = NULL
		
	create table #Customer_id_list (customer_id int)
	
	-- Customer IDs:
	if datalength((@customer_id_list)) > 0 begin
		Insert #Customer_id_list
		select convert(int, row)
		from dbo.fn_SplitXsvText(',', 0, @customer_id_list)
		where isnull(row, '') <> ''
	end	
	
	IF EXISTS(SELECT TOP 1 * FROM #Customer_id_list WHERE customer_id = -9999)
	BEGIN
		-- we want to include ALL customers (i.e. remove any customer filtering)
		DELETE FROM #Customer_id_list 
		SET @customer_id_list = NULL
	END

	SELECT * INTO #data FROM [BaselineCategory] WHERE 1=2
	SET IDENTITY_INSERT #data ON
	
	
		
	declare @search_string varchar(max)
	declare @where_clause varchar(max)
	
	set @search_string = 'SELECT BaselineCategory.*, Customer.cust_name FROM BaselineCategory '
	SET @search_string = @search_string + ' INNER JOIN Customer ON BaselineCategory.customer_id = Customer.customer_id '
	SET @where_clause = ' WHERE 1=1 '
	
	IF @description IS NOT NULL
	BEGIN
		SET @where_clause = @where_clause + ' AND description LIKE ''%' +  @description + '%'' '
	END		
	
	IF @baseline_category_id IS NOT NULL
		set @where_clause = @where_clause + ' AND baseline_category_id = ' + cast(@baseline_category_id as varchar(20)) + ' '
	
	IF @record_type IS NOT NULL
		set @where_clause = @where_clause + ' AND record_type = ''' + @record_type + ''' '
		
	IF @status IS NOT NULL
		set @where_clause = @where_clause + ' AND status = ''' + @status + ''' '
	
	IF @customer_id_list IS NOT NULL
	BEGIN
		SET @search_string = @search_string + ' INNER JOIN #customer_id_list ON Customer.customer_id = #customer_id_list.customer_id '
	END
	

		
	
	SET @search_string = @search_string + @where_clause + ' ORDER BY BaselineCategory.description, Customer.cust_name'
	
	--print @search_string 
	exec(@search_string)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineCategorySelect] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineCategorySelect] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_BaselineCategorySelect] TO [EQAI]
    AS [dbo];

