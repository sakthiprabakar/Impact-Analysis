
CREATE PROCEDURE sp_report_opp_actual_revenue_vs_goal
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

06/16/2023 Devops 65744--Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)

	Usage: 
		exec sp_report_opp_actual_revenue_vs_goal 89, 'RICH_G', '1/1/2011', '12/31/2011', 'region_v_goal', 0
		exec sp_report_opp_actual_revenue_vs_goal 89, 'RICH_G', '1/1/2011', '12/31/2011', 'region_v_goal_per_company', 0
		exec sp_report_opp_actual_revenue_vs_goal 89, 'RICH_G', '1/1/2011', '12/31/2011', 'region_v_corporate_goal', 0
		exec sp_report_opp_actual_revenue_vs_goal 89, 'RICH_G', '1/1/2011', '12/31/2011', 'territory_v_goal', 0
		exec sp_report_opp_actual_revenue_vs_goal 89, 'RICH_G', '1/1/2011', '12/31/2011', 'territory_v_goal_per_company', 0
		exec sp_report_opp_actual_revenue_vs_goal 89, 'RICH_G', '1/1/2010', '12/31/2011', 'territory_v_corporate_goal', 0
	
	Report Types:
		Total Actual Revenue by Region v. Goal = region_v_goal
		Total Actual Revenue by Region v. Goal per Company = region_v_goal_per_company
		Total Actual Revenue by Region v. Total Corporate Goal = region_v_corporate_goal
		Total Actual Revenue by Region v. Total Commissionable Goal = region_v_commissionable_goal
				
		Total Actual Revenue by Territory v. Goal = territory_v_goal
		Total Actual Revenue by Territory v. Goal per Company  = territory_v_goal_per_company
		Total Actual Revenue by Territory v. Total Corporate Goal = territory_v_corporate_goal
		Total Actual Revenue by Territory v. Total Commissionable Goal = territory_v_commissionable_goal
		
		
		
*/
BEGIN


declare @tbl_profit_center_filter table (
	[company_id] int, 
	profit_ctr_id int
)

	
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
	
	
	
	
	--SELECT * FROM Region

	--exec sp_report_opp_actual_revenue_vs_goal 89, 'RICH_G', '1/1/2010', '12/31/2011', 'region_v_goal', 0
	if @report_type = 'region_v_goal' or @report_type = 'region_v_goal_per_company'
	begin
	
		INSERT INTO #data (
			group_row_number, 
			month_number, 
			year_number, 
			amount, 
			goal_amount, 
			region_id, 
			region_desc, 
			company_id, 
			profit_ctr_id)
		SELECT ROW_NUMBER()
				OVER(
					PARTITION BY region_id, [year], [month] 
					ORDER BY region_id, [year], [month]) as row_num
				, *
		FROM 
        ( 
        
		SELECT 
		MONTH(b.invoice_date) AS [month]
		,YEAR(b.invoice_date) AS [year]
		,SUM(IsNull(bd.extended_amt, 0.000)) AS [amount],		
		(SELECT goal_amount FROM OppRevenueGoal org WHERE region_id = ISNULL(cb.region_id,0) AND MONTH(org.goal_month) = MONTH(b.invoice_date)
			and YEAR(org.goal_month) = YEAR(b.invoice_date)
			AND org.goal_type = 'region'
			) as goal_amt
			,ISNULL(cb.region_id,0) as region_id,
			ISNULL((SELECT region_desc
						 FROM   Region
						 WHERE  region_id = ISNULL(cb.region_id,0)),'(empty region)') AS region_desc
		,b.company_id,
		b.profit_ctr_id
		FROM   Billing b WITH(NOLOCK)
				   INNER JOIN BillingDetail bd WITH(NOLOCK) ON bd.company_id = b.company_id
												 AND bd.profit_ctr_id = b.profit_ctr_id
												 AND bd.receipt_id = b.receipt_id
												 AND bd.line_id = b.line_id
												 AND bd.price_id = b.price_id
												 AND bd.trans_type = b.trans_type
												 AND bd.trans_source = b.trans_source
				    LEFT JOIN CustomerBilling cb WITH(NOLOCK) ON cb.billing_project_id = b.billing_project_id
																AND cb.customer_id = b.customer_id
					INNER JOIN @tbl_profit_center_filter secured_copc ON secured_copc.company_id = bd.company_id
						and secured_copc.profit_ctr_id = bd.profit_ctr_id
			WHERE  b.invoice_date BETWEEN @start_date AND @end_date
				   AND b.status_code = 'I'
			GROUP  BY MONTH(b.invoice_date)
					  ,YEAR(b.invoice_date)
					  ,ISNULL(cb.region_id,0)
					  ,b.company_id
					  ,b.profit_ctr_id
					  --,cb.territory_code
       ) tbl
        
    
	end -- /region_v_goal


	/*
		exec sp_report_opp_actual_revenue_vs_goal 89, 'RICH_G', '12/1/2010', '12/31/2011', 'region_v_corporate_goal', 0
	*/
	if @report_type = 'region_v_corporate_goal'
	begin
		
		INSERT INTO #data (
			group_row_number, 
			month_number, 
			year_number, 
			amount, 
			goal_amount, 
			region_id, 
			region_desc)
		SELECT ROW_NUMBER()
				OVER(
					PARTITION BY region_id, [year], [month] 
					ORDER BY region_id, [year], [month]) as row_num
				, *
		FROM 
        (
        
			SELECT 
			MONTH(b.invoice_date) AS [month]
			,YEAR(b.invoice_date) AS [year]
			,SUM(IsNull(bd.extended_amt, 0.000)) AS [amount],		
			(SELECT goal_amount FROM OppRevenueGoal org 
				WHERE 1=1
					--and region_id = cb.region_id 
					AND MONTH(org.goal_month) = MONTH(b.invoice_date)
					and YEAR(org.goal_month) = YEAR(b.invoice_date)
					AND org.goal_type = 'corporate'
				) as goal_amt
			,
			ISNULL(cb.region_id,0) as region_id,
			ISNULL((SELECT region_desc
						 FROM   Region
						 WHERE  region_id = ISNULL(cb.region_id,0)),'(empty region)') AS region_desc
			--,cb.territory_code
			FROM   Billing b WITH(NOLOCK)
					   INNER JOIN BillingDetail bd WITH(NOLOCK) ON bd.company_id = b.company_id
													 AND bd.profit_ctr_id = b.profit_ctr_id
													 AND bd.receipt_id = b.receipt_id
													 AND bd.line_id = b.line_id
													 AND bd.price_id = b.price_id
													 AND bd.trans_type = b.trans_type
													 AND bd.trans_source = b.trans_source
						LEFT JOIN CustomerBilling cb WITH(NOLOCK) ON cb.billing_project_id = b.billing_project_id
																	AND cb.customer_id = b.customer_id
						INNER JOIN @tbl_profit_center_filter secured_copc ON secured_copc.company_id = bd.company_id
							and secured_copc.profit_ctr_id = bd.profit_ctr_id
				WHERE  b.invoice_date BETWEEN @start_date AND @end_date
					   AND b.status_code = 'I'
				GROUP  BY MONTH(b.invoice_date)
						  ,YEAR(b.invoice_date),
						  ISNULL(cb.region_id,0)
		) tbl
				  
        		  

     
		
	end --/region_v_corporate_goal

	if @report_type = 'region_v_commissionable_goal'
	begin
		print 'todo -- not sure what this is'
	end -- /region_v_commissionable_goal

	/*
	exec sp_report_opp_actual_revenue_vs_goal 89, 'RICH_G', '12/1/2010', '12/31/2011', 'territory_v_goal_per_company', 0
	*/
	if @report_type = 'territory_v_goal' or @report_type = 'territory_v_goal_per_company'
	begin

		INSERT INTO #data (
			group_row_number, 
			month_number, 
			year_number, 
			amount, 
			goal_amount, 
			territory_code,
			territory_desc,
			company_id, 
			profit_ctr_id)
	   SELECT ROW_NUMBER()
				OVER(
					PARTITION BY territory_code, [year], [month] 
					ORDER BY territory_code, [year], [month]) as row_num
				, *
		FROM 
        (
        
			SELECT 
				MONTH(b.invoice_date) AS [month]
				,YEAR(b.invoice_date) AS [year]
				,SUM(IsNull(bd.extended_amt, 0.000)) AS [amount],		
				(SELECT goal_amount FROM OppRevenueGoal org 
					WHERE 1=1
						and cb.territory_code = org.territory_code
						AND MONTH(org.goal_month) = MONTH(b.invoice_date)
						and YEAR(org.goal_month) = YEAR(b.invoice_date)
						AND org.goal_type = 'territory'
					) as goal_amt
				,Territory.territory_code
				,Territory.territory_desc
				,b.company_id
				,b.profit_ctr_id
				FROM   Billing b WITH(NOLOCK)
						   INNER JOIN BillingDetail bd WITH(NOLOCK) ON bd.company_id = b.company_id
														 AND bd.profit_ctr_id = b.profit_ctr_id
														 AND bd.receipt_id = b.receipt_id
														 AND bd.line_id = b.line_id
														 AND bd.price_id = b.price_id
														 AND bd.trans_type = b.trans_type
														 AND bd.trans_source = b.trans_source
							LEFT JOIN CustomerBilling cb WITH(NOLOCK) ON cb.billing_project_id = b.billing_project_id
																		AND cb.customer_id = b.customer_id
							INNER JOIN @tbl_profit_center_filter secured_copc ON secured_copc.company_id = bd.company_id
								and secured_copc.profit_ctr_id = bd.profit_ctr_id
							LEFT JOIN Territory ON Territory.territory_code = cb.territory_code
					WHERE  b.invoice_date BETWEEN @start_date AND @end_date
						   AND b.status_code = 'I'
					GROUP  BY MONTH(b.invoice_date)
							  ,YEAR(b.invoice_date)
							  ,Territory.territory_code
								,Territory.territory_desc
								,b.company_id
								,b.profit_ctr_id
								,cb.territory_code
				 ) tbl

	end -- /territory_v_goal

	/*
		exec sp_report_opp_actual_revenue_vs_goal 89, 'RICH_G', '12/1/2010', '12/31/2011', 'territory_v_corporate_goal', 0
	*/
	--SELECT * FROM OppRevenueGoal
	if @report_type = 'territory_v_corporate_goal'
	begin
		INSERT INTO #data (
			group_row_number, 
			month_number, 
			year_number, 
			amount, 
			goal_amount, 
			territory_code,
			territory_desc)
		SELECT ROW_NUMBER()
				OVER(
					PARTITION BY territory_code, [year], [month] 
					ORDER BY territory_code, [year], [month]) as row_num
				, *
		FROM 
        (

				SELECT 
				MONTH(b.invoice_date) AS [month]
				,YEAR(b.invoice_date) AS [year]
				,SUM(IsNull(bd.extended_amt, 0.000)) AS [amount],		
				(SELECT goal_amount FROM OppRevenueGoal org 
					WHERE 1=1
						--and cb.territory_code = org.territory_code
						AND MONTH(org.goal_month) = MONTH(b.invoice_date)
						and YEAR(org.goal_month) = YEAR(b.invoice_date)
						AND org.goal_type = 'corporate'
					) as goal_amt
				,Territory.territory_code
				,Territory.territory_desc
				FROM   Billing b WITH(NOLOCK)
						   INNER JOIN BillingDetail bd WITH(NOLOCK) ON bd.company_id = b.company_id
														 AND bd.profit_ctr_id = b.profit_ctr_id
														 AND bd.receipt_id = b.receipt_id
														 AND bd.line_id = b.line_id
														 AND bd.price_id = b.price_id
														 AND bd.trans_type = b.trans_type
														 AND bd.trans_source = b.trans_source
							LEFT JOIN CustomerBilling cb WITH(NOLOCK) ON cb.billing_project_id = b.billing_project_id
																		AND cb.customer_id = b.customer_id
							INNER JOIN @tbl_profit_center_filter secured_copc ON secured_copc.company_id = bd.company_id
								and secured_copc.profit_ctr_id = bd.profit_ctr_id
							LEFT JOIN Territory ON Territory.territory_code = cb.territory_code
					WHERE  b.invoice_date BETWEEN @start_date AND @end_date
						   AND b.status_code = 'I'
					GROUP  BY MONTH(b.invoice_date)
							  ,YEAR(b.invoice_date)
							  ,Territory.territory_code
								,Territory.territory_desc
								,cb.territory_code
		 ) tbl

          
	      
	end -- /territory_v_corporate_goal

	if @report_type = 'territory_v_commissionable_goal'
	begin
		print 'todo -- not sure what this is'
	end -- /territory_v_commissionable_goal

	--update #data set region_desc = '(no region specified)', region_id = 0 where ISNULL(region_id,0) = 0

	update #data set territory_desc = territory_code + ' - ' + territory_desc
		where territory_code is not null and territory_desc is not null
		
	update #data set copc_display = RIGHT('00' + CONVERT(VARCHAR,company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR,profit_ctr_ID), 2)	
	
	SELECT * FROM #data
	order by year_number, month_number
	
END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_opp_actual_revenue_vs_goal] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_opp_actual_revenue_vs_goal] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_opp_actual_revenue_vs_goal] TO [EQAI]
    AS [dbo];

