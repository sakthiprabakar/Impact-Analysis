
CREATE PROCEDURE sp_report_opp_projected_revenue_vs_goal
	@permission_id int,
	@user_code varchar(20),
	@copc_list varchar(max),
	@start_date datetime,
	@end_date datetime,
	@report_type varchar(50) = NULL
		/*
			region_v_goal
			region_v_goal_per_company
			region_v_corporate_goal
			region_v_commissionable_goal
			territory_v_goal
			territory_v_goal_per_company
			territory_v_corporate_goal
			territory_v_commissionable_goal
		*/
	, @debug int = 0
AS

/*
06/16/2023 Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
	Usage: 
		exec sp_report_opp_projected_revenue_vs_goal 89, 'RICH_G', NULL, '1/1/2011', '12/31/2011', 'region_v_goal', 0
		exec sp_report_opp_projected_revenue_vs_goal 89, 'RICH_G', NULL, '1/1/2011', '12/31/2011', 'region_v_goal_per_company', 0
		exec sp_report_opp_projected_revenue_vs_goal 89, 'RICH_G', NULL, '1/1/2011', '12/31/2011', 'region_v_corporate_goal', 0
		exec sp_report_opp_projected_revenue_vs_goal 89, 'RICH_G', NULL, '1/1/2011', '12/31/2011', 'territory_v_goal', 0
		exec sp_report_opp_projected_revenue_vs_goal 89, 'RICH_G', NULL, '1/1/2011', '12/31/2011', 'territory_v_goal_per_company', 0
		exec sp_report_opp_projected_revenue_vs_goal 89, 'RICH_G', NULL, '1/1/2010', '12/31/2011', 'territory_v_corporate_goal', 0
	
	Report Types:
		Total Projected Revenue by Region v. Goal = region_v_goal
		Total Projected Revenue by Region v. Goal per Company = region_v_goal_per_company
		Total Projected Revenue by Region v. Total Corporate Goal = region_v_corporate_goal
		Total Projected Revenue by Region v. Total Commissionable Goal = region_v_commissionable_goal
				
		Total Projected Revenue by Territory v. Goal = territory_v_goal
		Total Projected Revenue by Territory v. Goal per Company  = territory_v_goal_per_company
		Total Projected Revenue by Territory v. Total Corporate Goal = territory_v_corporate_goal
		Total Projected Revenue by Territory v. Total Commissionable Goal = territory_v_commissionable_goal
		
		
		
*/
BEGIN


declare @tbl_profit_center_filter table (
	[company_id] int, 
	profit_ctr_id int
)


declare @month_list table
(
	month_start datetime
)

declare @territory_list table
(
	territory_code varchar(5)
)

INSERT INTO @territory_list
	SELECT territory_code FROM Territory

INSERT INTO @month_list 
SELECT * FROM dbo.fn_GetMonthList(@start_date,@end_date)


	--SELECT DISTINCT customer_id, cust_name INTO #Secured_Customer
	--	FROM SecuredCustomer sc WHERE sc.user_code = @user_code
	--	and sc.permission_id = @permission_id		
	
	if @copc_list is not null
	begin

	INSERT @tbl_profit_center_filter 
		SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
			FROM 
				SecuredProfitCenter secured_copc
			INNER JOIN (
				SELECT 
					RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
					RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
				from dbo.fn_SplitXsvText(',', 0, @copc_list) 
				where isnull(row, '') <> '') selected_copc ON secured_copc.company_id = selected_copc.company_id AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
				and secured_copc.permission_id = @permission_id
				and secured_copc.user_code = @user_code
	end
	else 
	begin
	
	INSERT @tbl_profit_center_filter 
		SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
			FROM 
				SecuredProfitCenter secured_copc
				where secured_copc.permission_id = @permission_id
				and secured_copc.user_code = @user_code	
	
	end				
	
	create table #data 
	(
		month_number int,
		year_number int,
		amount float,
		goal_amount float,
		region_id int,
		region_desc varchar(50),
		territory_code varchar(8),
		territory_desc varchar(50),
		company_id int,
		profit_ctr_id int,
		copc_display varchar(20),
		group_row_number int
	)
	
	create table #data_result
	(
		month_number int,
		year_number int,
		amount float,
		goal_amount float,
		region_id int,
		region_desc varchar(50),
		territory_code varchar(8),
		territory_desc varchar(50),
		company_id int,
		profit_ctr_id int,
		copc_display varchar(20),
		group_row_number int
	)	
	
	create table #territory_placeholder
	(
		month_start datetime,
		company_id int,
		profit_ctr_id int,
		territory_code varchar(50),
		goal_amount decimal,
		amount decimal
	)
	
	create table #region_placeholder
	(
		month_start datetime,
		company_id int,
		profit_ctr_id int,
		region_id varchar(50),
		goal_amount decimal,
		amount decimal
	)

	if @report_type = 'region_v_goal' or @report_type = 'region_v_goal_per_company'
	begin
	
	INSERT INTO #region_placeholder ( month_start, company_id, profit_ctr_id, region_id, amount, goal_amount )
			SELECT months.month_start, copc.company_id, copc.profit_ctr_id, Region.region_id,0.00,0.00
			FROM @month_list months
			JOIN ProfitCenter copc ON 1=1 and status='A'
			JOIN Region ON 1=1
			
	INSERT INTO #region_placeholder ( month_start, company_id, profit_ctr_id, region_id, amount, goal_amount )
			SELECT months.month_start, copc.company_id, copc.profit_ctr_id, -1,0.00,0.00
			FROM @month_list months
			JOIN ProfitCenter copc ON 1=1 and status='A'
			
	

		INSERT INTO #data (month_number, year_number, amount, goal_amount, region_id, region_desc, company_id, profit_ctr_id)
				SELECT MONTH(COALESCE(o.actual_start_date, o.est_start_date)) AS [month],
				  YEAR(COALESCE(o.actual_start_date, o.est_start_date)) AS [year],
				  ISNULL(SUM(COALESCE(opf.total_revenue, opfsplit.amount, o.est_revenue)),0) AS [amount],
				  ISNULL(org.goal_amount,0) as goal_amount,
				  coalesce(o.region_id, cb.region_id, -1) as region_id,
				  NULL as region_desc, /* filled in later */
				  COALESCE(opfsplit.company_id, opf.company_id) AS company_id,
				  COALESCE(opfsplit.profit_ctr_id, opf.profit_ctr_id) AS profit_ctr_id
		   FROM   Opp o
		           LEFT JOIN CustomerBilling cb ON o.customer_id = cb.customer_id
				  JOIN OppRevenueGoal org ON org.region_id = coalesce(o.region_id, cb.region_id)
											 AND org.goal_type = 'region'
				  JOIN Region r ON r.region_id = coalesce(o.region_id, cb.region_id)
				  LEFT JOIN OppFacility opf ON opf.Opp_id = o.Opp_id
				  LEFT JOIN OppFacilityMonthSplit opfsplit ON opf.Opp_id = opfsplit.opp_id
															  AND opf.company_id = opfsplit.company_id
															  AND opf.profit_ctr_id = opfsplit.profit_ctr_id
															  AND MONTH(opfsplit.revenue_distribution_month) = MONTH(org.goal_month)
															  AND year(opfsplit.revenue_distribution_month) = YEAR(org.goal_month)
				  JOIN @tbl_profit_center_filter secured_copc ON 
					(secured_copc.company_id = opf.company_id  
					and secured_copc.profit_ctr_id = opf.profit_ctr_id) or opf.company_id is null
		  		LEFT JOIN @month_list months ON MONTH(COALESCE(opfsplit.revenue_distribution_month, o.actual_start_date, o.est_start_date)) = month(months.month_start)
				 AND YEAR(COALESCE(opfsplit.revenue_distribution_month, o.actual_start_date, o.est_start_date)) = YEAR(months.month_start)
			
		   WHERE  COALESCE(o.actual_start_date, o.est_start_date) BETWEEN @start_date AND @end_date
				  AND o.status <> 'L' -- ignore 'Lost' items
				  and coalesce(o.primary_opp_id, o.opp_id) = o.Opp_id
		   GROUP  BY MONTH(COALESCE(o.actual_start_date, o.est_start_date)),
					 YEAR(COALESCE(o.actual_start_date, o.est_start_date)),
					 org.goal_amount,
					 coalesce(o.region_id, cb.region_id, -1) ,
					 r.region_desc,
					 opfsplit.company_id,
					 opf.company_id,
					 opfsplit.profit_ctr_id,
					 opf.profit_ctr_id 
		 
	update #data set region_desc = ISNULL((SELECT region.region_desc from Region where #data.region_id = region.region_id), 'N/A')
	
	
	
	UPDATE #region_placeholder SET amount = d.amount
		FROM #data d WHERE
		MONTH(#region_placeholder.month_start) = d.month_number
		AND YEAR(#region_placeholder.month_start) = d.year_number
		AND #region_placeholder.region_id = d.region_id
		AND #region_placeholder.company_id = d.company_id
		and #region_placeholder.profit_ctr_id = d.profit_ctr_id

	
	update #region_placeholder SET goal_amount = org.goal_amount
		FROM OppRevenueGoal org
		WHERE #region_placeholder.region_id = org.region_id
		AND #region_placeholder.month_start = org.goal_month
				
	-- 4) Insert the data (all month / copc / territory combination + goals + expected revenue)
	INSERT #data_result (group_row_number, month_number, year_number, amount, goal_amount, region_id, region_desc, territory_code, territory_desc, company_id, profit_ctr_id, copc_display)

		SELECT ROW_NUMBER()
				OVER(
					PARTITION BY region_id, [year], [month] 
					ORDER BY region_id, [year], [month]) as row_num
				, *
		FROM 
        (		
			SELECT
				MONTH(month_start) as month,
				YEAR(month_start) as year,
				amount,
				goal_amount,
				region_id,
				(SELECT TOP 1 region_desc FROM Region WHERE region_id = #region_placeholder.region_id) as region_desc,
				NULL as territory_code,
				NULL as territory_desc, 
				company_id,
				profit_ctr_id,
				NULL as copc_display
			FROM #region_placeholder 
			where #region_placeholder.region_id <>-1
			
			UNION
			
			SELECT distinct
				MONTH(month_start) as month,
				YEAR(month_start) as year,
				amount,
				goal_amount,
				region_id,
				ISNULL((SELECT TOP 1 region_desc FROM Region WHERE region_id = #region_placeholder.region_id), 'N/A') as region_desc,
				NULL as territory_code,
				NULL as territory_desc, 
				company_id,
				profit_ctr_id,
				NULL as copc_display
			FROM #region_placeholder 
			where #region_placeholder.region_id = -1			
			
			
			
		) tbl
	
	-- since the goal_amount is for the REGION and we are reporting at the COPC level, wipe out all goals for that region except 1 so our sums come out correctly
	update #data_result SET goal_amount = 0 WHERE group_row_number <> 1
	update #data_result set copc_display = RIGHT('00' + CONVERT(VARCHAR,company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,profit_ctr_ID), 2)	
	
	--delete from #data_result where region_desc <> 'Southeast' and month_number <> 3
	
	SELECT @report_type as [report_type], * FROM #data_result -- WHERE region_desc = 'Southeast' and month_number = 3
	
	end -- /region_v_goal

	if @report_type = 'region_v_corporate_goal'
	begin
		
		INSERT INTO #region_placeholder ( month_start, company_id, profit_ctr_id, region_id, amount, goal_amount )
			SELECT months.month_start, NULL, NULL, Region.region_id,0.00,0.00
			FROM @month_list months
			JOIN Region ON 1=1
		
		INSERT INTO #data ( month_number, year_number, amount, goal_amount, region_id, region_desc)
			
			SELECT MONTH(COALESCE(o.actual_start_date, o.est_start_date)) AS [month]
				   ,YEAR(COALESCE(o.actual_start_date, o.est_start_date)) AS [year]
				   ,SUM(o.est_revenue) AS [amount]
				   ,org.goal_amount
				   ,r.region_id
				   ,r.region_desc
			FROM   Opp o
				   JOIN OppRevenueGoal org ON org.goal_type = 'corporate'
				   JOIN Region r ON r.region_id = o.region_id
				   
			WHERE  COALESCE(o.actual_start_date, o.est_start_date) BETWEEN @start_date AND @end_date
				   AND status <> 'L' -- ignore 'Lost' items
				  AND MONTH(COALESCE(o.actual_start_date, o.est_start_date)) = MONTH(goal_month)
				  AND YEAR(COALESCE(o.actual_start_date, o.est_start_date)) = YEAR(goal_month)
				   AND coalesce(o.primary_opp_id, o.opp_id) = o.Opp_id
			GROUP  BY MONTH(COALESCE(o.actual_start_date, o.est_start_date))
					  ,YEAR(COALESCE(o.actual_start_date, o.est_start_date))
					  ,org.goal_amount
					  ,r.region_id
					  ,r.region_desc
				  	

		UPDATE #region_placeholder SET amount = d.amount
		FROM #data d WHERE
		MONTH(#region_placeholder.month_start) = d.month_number
		AND YEAR(#region_placeholder.month_start) = d.year_number
		AND d.region_id = #region_placeholder.region_id
		
		update #region_placeholder SET goal_amount = org.goal_amount
		FROM OppRevenueGoal org
		WHERE 1=1
		AND #region_placeholder.month_start = org.goal_month	
		AND org.goal_type = 'corporate'
		
		
    
    INSERT #data_result (group_row_number, month_number, year_number, amount, goal_amount, region_id, region_desc, territory_code, territory_desc, company_id, profit_ctr_id, copc_display)
    SELECT ROW_NUMBER()
					OVER(
						PARTITION BY region_id, [year], [month] 
						ORDER BY region_id, [year], [month]) as row_num
					, *
			FROM 
			(
				SELECT
					MONTH(month_start) as month,
					YEAR(month_start) as year,
					amount,
					goal_amount,
					region_id,
					(SELECT TOP 1 region_desc FROM Region WHERE region_id = #region_placeholder.region_id) as region_desc,
					NULL as territory_code,
					NULL as territory_desc, --(SELECT TOP 1 territory_desc FROM Territory WHERE territory_code = territory_code),
					NULL as company_id,--company_id,
					NULL as profit_ctr_id,--profit_ctr_id,
					NULL as copc_display
	FROM #region_placeholder) tbl
	
		
	
		
	update #data_result SET goal_amount = 0 WHERE group_row_number <> 1
			
	SELECT @report_type as [report_type], * FROM #data_result	
	
     
		
	end --/region_v_corporate_goal

	if @report_type = 'territory_v_goal' or @report_type = 'territory_v_goal_per_company'
	begin
	
		-- 1) Create the placeholder that will store all Co/Pc/Territory/Month combinations
		INSERT INTO #territory_placeholder ( month_start, company_id, profit_ctr_id, territory_code, amount, goal_amount )
			SELECT months.month_start, copc.company_id, copc.profit_ctr_id, territory.territory_code,0.00,0.00
			FROM @month_list months
			JOIN ProfitCenter copc ON 1=1 and status='A'
			JOIN Territory ON 1=1
			--and month_start = '9/1/2011'
		
		
		INSERT INTO #territory_placeholder ( month_start, company_id, profit_ctr_id, territory_code, amount, goal_amount )
			SELECT months.month_start, copc.company_id, copc.profit_ctr_id, 'N/A',0.00,0.00
			FROM @month_list months
			JOIN ProfitCenter copc ON 1=1 and status='A'
			
			--and month_start = '9/1/2011'		
		
	   -- 2) Sum up the appropriate goal data --  only data that exists will come in here
	   INSERT INTO #data (month_number, year_number, amount, goal_amount, territory_code, territory_desc, company_id, profit_ctr_id)
       SELECT MONTH(COALESCE(opfsplit.revenue_distribution_month, o.actual_start_date, o.est_start_date)) AS [month],
              YEAR(COALESCE(opfsplit.revenue_distribution_month, o.actual_start_date, o.est_start_date)) AS [year],
              SUM(COALESCE(opf.total_revenue, opfsplit.amount, o.est_revenue)) AS [amount],
              ISNULL(org.goal_amount,0) as goal_amount,
   			  COALESCE(org.territory_code, o.territory_code, cb.territory_code, 'N/A') as territory_code,
			  NULL as territory_desc, /* updated later */
              COALESCE(opfsplit.company_id, opf.company_id) AS company_id,
              COALESCE(opfsplit.profit_ctr_id, opf.profit_ctr_id) AS profit_ctr_id
       FROM   Opp o
              LEFT JOIN CustomerBilling cb ON o.customer_id = cb.customer_id
              LEFT JOIN OppRevenueGoal org ON org.goal_type = 'territory'
                                         AND org.territory_code = COALESCE(o.territory_code, cb.territory_code)
              JOIN Territory t ON t.territory_code = COALESCE(org.territory_code, o.territory_code, cb.territory_code, t.territory_code)
              LEFT JOIN OppFacility opf ON opf.Opp_id = o.Opp_id
              LEFT JOIN OppFacilityMonthSplit opfsplit ON opf.Opp_id = opfsplit.opp_id
                                                          AND opf.company_id = opfsplit.company_id
                                                          AND opf.profit_ctr_id = opfsplit.profit_ctr_id
                                                          AND MONTH(opfsplit.revenue_distribution_month) = MONTH(org.goal_month)
                                                          AND year(opfsplit.revenue_distribution_month) = YEAR(org.goal_month)
                                                          
			   JOIN @tbl_profit_center_filter secured_copc ON 
				(secured_copc.company_id = opf.company_id  and secured_copc.profit_ctr_id = opf.profit_ctr_id) or opf.company_id is null
			 JOIN @month_list months ON MONTH(COALESCE(opfsplit.revenue_distribution_month, o.actual_start_date, o.est_start_date)) = month(months.month_start)
			 AND YEAR(COALESCE(opfsplit.revenue_distribution_month, o.actual_start_date, o.est_start_date)) = YEAR(months.month_start)
			
       WHERE  COALESCE(o.actual_start_date, o.est_start_date) BETWEEN @start_date AND @end_date
              AND o.status <> 'L' -- ignore 'Lost' items
              and coalesce(o.primary_opp_id, o.opp_id) = o.Opp_id -- only want the primary opportunity to be counted
              --and t.territory_desc IN('MI REG MGR','OPEN')
              --and months.month_start = '9/1/2011'
       GROUP  BY MONTH(COALESCE(opfsplit.revenue_distribution_month, o.actual_start_date, o.est_start_date)),
                 YEAR(COALESCE(opfsplit.revenue_distribution_month, o.actual_start_date, o.est_start_date)),
                 org.goal_amount,
                  t.territory_code,
			  t.territory_desc,
                 COALESCE(opfsplit.company_id, opf.company_id),
                 COALESCE(opfsplit.profit_ctr_id, opf.profit_ctr_id) 
				 ,COALESCE(t.territory_desc, o.territory_code, cb.territory_code) ,
				 COALESCE(org.territory_code, o.territory_code, cb.territory_code, 'N/A')
				 

	
	update #data set territory_desc = ISNULL((SELECT t.territory_desc
		FROM Territory t WHERE #data.territory_code = t.territory_code), 'N/A')
		
	--SELECT * FROM #data
	
		
	--SELECT * FROM #territory_placeholder
	
		-- 3) Update the placeholder with the summed up values
	UPDATE #territory_placeholder SET amount = d.amount
		FROM #data d WHERE
		MONTH(#territory_placeholder.month_start) = d.month_number
		AND YEAR(#territory_placeholder.month_start) = d.year_number
		AND #territory_placeholder.territory_code = d.territory_code
		AND #territory_placeholder.company_id =d.company_id
		and #territory_placeholder.profit_ctr_id = d.profit_ctr_id
		
		update #territory_placeholder SET goal_amount = org.goal_amount
		FROM OppRevenueGoal org
		WHERE #territory_placeholder.territory_code = org.territory_code
		AND #territory_placeholder.month_start = org.goal_month
				
	--SELECT * FROM #territory_placeholder where territory_code = 'N/A'
				
	-- 4) Insert the data (all month / copc / territory combination + goals + expected revenue)
	INSERT #data_result (group_row_number, month_number, year_number, amount, goal_amount, region_id, region_desc, territory_code, territory_desc, company_id, profit_ctr_id, copc_display)
	 SELECT ROW_NUMBER()
			OVER(
				PARTITION BY territory_code, [year], [month] 
				ORDER BY territory_code, [year], [month]) as row_num
			, *
	FROM 
    (
		SELECT  MONTH(month_start) as month,
		YEAR(month_start) as year,
		amount,
		goal_amount,
		NULL as region_id,
		NULL as region_desc,
		territory_code,
		(SELECT TOP 1 territory_desc FROM Territory WHERE territory_code = #territory_placeholder.territory_code) as territory_desc,
		company_id,
		profit_ctr_id,
		NULL as copc_display
		FROM #territory_placeholder
		WHERE #territory_placeholder.territory_code <> 'N/A'

		UNION
		
		SELECT  DISTINCT MONTH(month_start) as month,
		YEAR(month_start) as year,
		amount,
		goal_amount,
		NULL as region_id,
		NULL as region_desc,
		territory_code,
		ISNULL((SELECT TOP 1 territory_desc FROM Territory WHERE territory_code = #territory_placeholder.territory_code), 'N/A') as territory_desc,
		company_id,
		profit_ctr_id,
		NULL as copc_display
		FROM #territory_placeholder
		WHERE #territory_placeholder.territory_code = 'N/A'	
	
	) tbl
	
	
	-- since the goal_amount is for the TERRITORY and we are reporting at the COPC level, wipe out all goals for that TERRITORY except 1 so our sums come out correctly
	update #data_result SET goal_amount = 0 WHERE group_row_number <> 1	
	update #data_result set copc_display = RIGHT('00' + CONVERT(VARCHAR,company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,profit_ctr_ID), 2)	
	
	SELECT @report_type as [report_type], * FROM #data_result --where territory_code = 'N/A' and amount>0
		

	end -- /territory_v_goal

	if @report_type = 'territory_v_corporate_goal'
	begin
	
		-- 1) Create the placeholder that will store all Territory/Month combinations
		INSERT INTO #territory_placeholder ( month_start, company_id, profit_ctr_id, territory_code, amount, goal_amount )
			SELECT months.month_start, NULL, NULL, territory.territory_code, 0.00, 0.00
			FROM @month_list months
			--JOIN ProfitCenter copc ON 1=1 and status='A'
			JOIN Territory ON 1=1
			--and month_start = '1/1/2011'
				
		INSERT INTO #data (group_row_number, month_number, year_number, amount, goal_amount, territory_code, territory_desc)
		SELECT ROW_NUMBER()
				OVER(
					PARTITION BY territory_code, [year], [month] 
					ORDER BY territory_code, [year], [month]) as row_num
				, *
		FROM 
        (
		SELECT MONTH(COALESCE(o.actual_start_date, o.est_start_date)) AS [month]
			   ,YEAR(COALESCE(o.actual_start_date, o.est_start_date)) AS [year]
			   ,SUM(ISNULL(o.est_revenue,0)) AS [amount]
			   ,SUM(org.goal_amount) as goal_amount
			   ,COALESCE(o.territory_code, cb.territory_code) AS territory_code
			   ,ISNULL((SELECT t.territory_desc
						FROM   Territory t
						WHERE  t.territory_code = COALESCE(o.territory_code, cb.territory_code)), COALESCE(o.territory_code, cb.territory_code)) AS territory_desc
		FROM   Opp o
			   LEFT JOIN CustomerBilling cb ON o.customer_id = cb.customer_id
			   LEFT JOIN OppRevenueGoal org ON org.goal_type = 'corporate'
		WHERE  COALESCE(o.actual_start_date, o.est_start_date) BETWEEN @start_date AND @end_date
			   AND o.status <> 'L' -- ignore 'Lost' items
			   --AND MONTH(COALESCE(o.actual_start_date, o.est_start_date)) = MONTH(goal_month)
			   --AND YEAR(COALESCE(o.actual_start_date, o.est_start_date)) = YEAR(goal_month)
			   AND coalesce(o.primary_opp_id, o.opp_id) = o.Opp_id
		GROUP  BY MONTH(COALESCE(o.actual_start_date, o.est_start_date))
				  ,YEAR(COALESCE(o.actual_start_date, o.est_start_date))
				  ,org.goal_amount
				  ,COALESCE(o.territory_code, cb.territory_code) ) tbl

--	SELECT * FROM #territory_placeholder
	
		-- 3) Update the placeholder with the summed up values
	UPDATE #territory_placeholder SET amount = d.amount
		FROM #data d WHERE
		MONTH(#territory_placeholder.month_start) = d.month_number
		AND YEAR(#territory_placeholder.month_start) = d.year_number
		AND #territory_placeholder.territory_code = d.territory_code
		
--SELECT * FROM #territory_placeholder		
		
		update #territory_placeholder SET goal_amount = org.goal_amount
		FROM OppRevenueGoal org
		WHERE 1=1
		--AND #territory_placeholder.territory_code = org.territory_code
		AND #territory_placeholder.month_start = org.goal_month	
		AND org.goal_type = 'corporate'
		
--SELECT * FROM #territory_placeholder				
	
				
	-- 4) Insert the data (all month / copc / territory combination + goals + expected revenue)
	INSERT #data_result (group_row_number, month_number, year_number, amount, goal_amount, region_id, region_desc, territory_code, territory_desc, company_id, profit_ctr_id, copc_display)
	
			SELECT ROW_NUMBER()
					OVER(
						PARTITION BY region_id, [year], [month] 
						ORDER BY region_id, [year], [month]) as row_num
					, *
			FROM 
			(	
				SELECT
					MONTH(month_start) as month,
					YEAR(month_start) as year,
					amount,
					goal_amount,
					NULL as region_id,
					NULL as region_desc,
					territory_code,
					(SELECT TOP 1 territory_desc FROM Territory WHERE territory_code = #territory_placeholder.territory_code) as territory_desc,
					NULL as company_id,
					NULL as profit_ctr_id,
					NULL as copc_display
	FROM #territory_placeholder) tbl
	
	
	
	--update #data_result set copc_display = RIGHT('00' + CONVERT(VARCHAR,company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,profit_ctr_ID), 2)	
	--update #data_result SET goal_amount = 0 WHERE group_row_number <> 1
	SELECT @report_type as [report_type], * FROM #data_result
	--where territory_desc LIKE '%CT%'
		order by territory_desc, year_number, month_number
	  --      where goal_amount > 0  
	      
	end -- /territory_v_corporate_goal

END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_opp_projected_revenue_vs_goal] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_opp_projected_revenue_vs_goal] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_opp_projected_revenue_vs_goal] TO [EQAI]
    AS [dbo];

