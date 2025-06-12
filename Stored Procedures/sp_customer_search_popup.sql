
CREATE Procedure [dbo].[sp_customer_search_popup] (
	@cust_name		varchar(75) = '',
	@territory_list	varchar(40) = '',
	@customer_type	varchar(20) = '', --Added CMA 06-18-08
	@prospect_flag	char(1) = '',
	@status_list varchar(10) = 'A,I'
)
AS

--======================================================
-- Description: Handles the customer list that appears in website popups
--							sp_customer_search_popup
-- Parameters :
-- Returns    :
-- Requires   : database plt_ai (+Test, +Dev)
--
-- Modified    Author            Notes
-- ----------  ----------------  -----------------------
-- 08/02/2006  Jonathon Broome   Initial Development
--																--sp_customer_search_popup 'first energy', '23'
--																--sp_customer_search_popup 'louisville', '23'
--																--sp_customer_search_popup 'young''s', '17'
-- 05/09/2007	 JPB							 Central Invoicing Changes. CustomerXCompany->CustomerBilling, etc.
-- 06/17/2008  Chris Allen			 Customer_Type filter added; all lines removed, changed or added noted below
-- 06/19/2008  Chris Allen			 terms_code field returned; 
-- 09/02/2008 JPB			Added:  SET @cust_name = replace(@cust_name, ' ', '%') so spaces in a customer name are insignificant.
-- 07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

-- Test line:
-- sp_customer_search_popup 'ford eqo', null, null, null

--======================================================

	SET nocount on
	
	DECLARE  @strSQL varchar(8000)
	DECLARE  @outSQL varchar(8000)
	SET @cust_name = replace(@cust_name, ' ', '%')

	CREATE TABLE #tmpResults (
		customer_id		int,
		sort			int
	)	
	
	CREATE TABLE #status_list (
		[status] varchar(10)
	)
	
	INSERT INTO #status_list
	SELECT row
	from dbo.fn_SplitXsvText(',', 0, @status_list) 
	where isnull(row, '') <> ''
	
  ------------------------------------------------------
	-- insert #1: Name begins with, and territory match (if territory given)
  ------------------------------------------------------
	SET @strSQL = ' INSERT #tmpResults
	SELECT  
		c.customer_id, 
		1 as sort 
	FROM 
		customer c 
		LEFT OUTER JOIN customerbilling x on c.customer_id = x.customer_id AND x.billing_project_id = 0
	WHERE 1=1 and c.cust_status IN (SELECT status FROM #status_list)'

	IF @cust_name = '#''s'
		SET @strSQL = @strSQL + ' AND ( 
			cust_name LIKE ''0%'' 
			OR c.cust_name like ''1%'' 
			OR c.cust_name like ''2%'' 
			OR c.cust_name like ''3%'' 
			OR c.cust_name like ''4%'' 
			OR c.cust_name like ''5%'' 
			OR c.cust_name like ''6%'' 
			OR c.cust_name like ''7%'' 
			OR c.cust_name like ''8%'' 
			OR c.cust_name like ''9%''
			) '
	ELSE 
	BEGIN 
		SET @strSQL = @strSQL + ' AND (
			cust_name LIKE ''' + REPLACE(@cust_name, '''', '''''') + '%'' 
			'
		IF isNumeric(@cust_name) = 1
			SET @strSQL = @strSQL + ' or
				c.customer_id = ' + REPLACE(@cust_name, '''', '''''') + '
				'
		SET @strSQL = @strSQL + ' ) '
	END 
				
	IF @territory_list <> ''
		SET @strSQL = @strSQL + ' AND convert(int, x.territory_code) in (' + @territory_list + ') '
		
	IF @customer_type <> '' --Added CMA 06-18-08
		SET @strSQL = @strSQL + ' AND customer_type LIKE ''' + REPLACE(@customer_type, '''', '''''') + '%''' --Added CMA 06-18-08

	IF @prospect_flag = 'C'
		SET @strSQL = @strSQL + ' AND c.customer_id < 90000000 '

    SET @outSQL = @strSQL + ' ; '
	--select @strSQL
	execute(@strSQL)
  ------------------------------------------------------
	
  ------------------------------------------------------
	-- insert #2 name found anywhere in name string, and territory matches if given
  ------------------------------------------------------
	IF len(@cust_name) > 1 AND @cust_name <> '#''s'
	BEGIN 
		SET @strSQL = ' INSERT #tmpResults
		SELECT  
			c.customer_id, 
			2 as sort 
		FROM 
			customer c 
			LEFT OUTER JOIN customerbilling x on c.customer_id = x.customer_id AND x.billing_project_id = 0
		WHERE 1=1 and c.cust_status IN (SELECT status FROM #status_list) '
	
		SET @strSQL = @strSQL + ' AND (
			cust_name LIKE ''%' + REPLACE(@cust_name, '''', '''''') + '%'' 
			'
		IF isNumeric(@cust_name) = 1
			SET @strSQL = @strSQL + ' or
				c.customer_id = ' + REPLACE(@cust_name, '''', '''''') + '
				'
		SET @strSQL = @strSQL + ' ) '
					
		IF @territory_list <> ''
			SET @strSQL = @strSQL + ' AND convert(int, x.territory_code) in (' + @territory_list + ') '
			
		IF @customer_type <> '' --Added CMA 06-18-08
			SET @strSQL = @strSQL + ' AND customer_type LIKE ''' + REPLACE(@customer_type, '''', '''''') + '%''' --Added CMA 06-18-08

		IF @prospect_flag = 'C'
			SET @strSQL = @strSQL + ' AND c.customer_id < 90000000 '
			
		SET @strSQL = @strSQL + ' AND c.customer_id not in (select customer_id from #tmpResults) '
		
        SET @outSQL = @outSQL + @strSQL + ' ; '
		execute(@strSQL)
	END 
  ------------------------------------------------------
	
  ------------------------------------------------------
	-- insert #3, territory list given but customer found in non-territory
  ------------------------------------------------------
	IF len(@territory_list) <> ''
	BEGIN 
		SET @strSQL = ' INSERT #tmpResults
		SELECT  
			c.customer_id, 
			3 as sort 
		FROM 
			customer c 
		WHERE 1=1 and c.cust_status IN (SELECT status FROM #status_list) '
	
		IF @cust_name = '#''s'
			SET @strSQL = @strSQL + ' AND ( 
				cust_name LIKE ''0%'' 
				OR c.cust_name like ''1%'' 
				OR c.cust_name like ''2%'' 
				OR c.cust_name like ''3%'' 
				OR c.cust_name like ''4%'' 
				OR c.cust_name like ''5%'' 
				OR c.cust_name like ''6%'' 
				OR c.cust_name like ''7%'' 
				OR c.cust_name like ''8%'' 
				OR c.cust_name like ''9%''
				) '
		ELSE 
		BEGIN 
			SET @strSQL = @strSQL + ' AND (
				cust_name LIKE ''' + REPLACE(@cust_name, '''', '''''') + '%'' 
				'
			IF isNumeric(@cust_name) = 1
				SET @strSQL = @strSQL + ' or
					c.customer_id = ' + REPLACE(@cust_name, '''', '''''') + '
					'
			SET @strSQL = @strSQL + ' ) '
		END 
	
		SET @strSQL = @strSQL + ' AND not exists (select customer_id from customerbilling cb inner join territory t on cb.territory_code = t.territory_code AND cb.billing_project_id = 0) '
		
		IF @customer_type <> '' --Added CMA 06-18-08
			SET @strSQL = @strSQL + ' AND customer_type LIKE ''' + REPLACE(@customer_type, '''', '''''') + '%''' --Added CMA 06-18-08

		IF @prospect_flag = 'C'
			SET @strSQL = @strSQL + ' AND c.customer_id < 90000000 '
			
		SET @strSQL = @strSQL + ' AND c.customer_id not in (select customer_id from #tmpResults) '
		
        SET @outSQL = @outSQL + @strSQL + ' ; '
		execute(@strSQL)

	END 
  ------------------------------------------------------
	
	SET nocount off
	
  ------------------------------------------------------
	-- Prepare returned result set 
  ------------------------------------------------------
	SELECT DISTINCT
      c.cust_name
      ,c.customer_type
      ,-- Added CMA 06-18-08
      c.customer_id
      ,c.cust_city
      ,c.cust_state
      ,c.cust_zip_code
      ,dbo.fn_customer_territory_list(c.customer_id) AS territory
      ,c.terms_code
      ,x.sort
      ,u_ae.user_code AS ae_user_code
      ,u_ae.user_name AS ae_user_name
      ,u_nam.user_name AS nam_user_name
      ,u_nam.user_code AS nam_user_code
      ,ux_nam.type_id AS nam_id
      ,r.region_id
      ,r.region_desc,
      c.cust_status
    FROM   customer c
           INNER JOIN #tmpResults x
             ON c.customer_id = x.customer_id
           LEFT JOIN CustomerBilling cb
             ON c.customer_ID = cb.customer_id
                AND cb.billing_project_id = 0
           LEFT JOIN UsersXEQContact ux_nam
             ON ux_nam.type_id = cb.NAM_id
                AND ux_nam.EQcontact_type IN ( 'NAM' )
                AND cb.billing_project_id = 0
           LEFT JOIN Users u_nam
             ON ux_nam.user_code = u_nam.user_code
           LEFT JOIN UsersXEQContact ux_ae
             ON cb.territory_code = ux_ae.territory_code
                AND ux_ae.EQcontact_type IN ( 'AE' )
                AND cb.billing_project_id = 0
           LEFT JOIN Users u_ae
             ON ux_ae.user_code = u_ae.user_code
           LEFT JOIN Region r
             ON cb.region_id = r.region_id
           LEFT JOIN Territory t
             ON cb.territory_code = t.territory_code
                AND cb.billing_project_id = 0
    WHERE  1=1 
			AND c.cust_status IN (SELECT status FROM #status_list)
           AND cb.billing_project_id = 0
    ORDER  BY
      x.sort
      ,c.cust_name 
    
    
    -- select @outSQL
  ------------------------------------------------------


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_search_popup] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_search_popup] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_customer_search_popup] TO [EQAI]
    AS [dbo];

