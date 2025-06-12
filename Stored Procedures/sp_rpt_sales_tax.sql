
CREATE PROCEDURE sp_rpt_sales_tax (
	  @date_from			datetime
	, @date_to				datetime
	, @sales_tax_state		varchar(2)
	, @customer_id			int
	, @detail_level			tinyint
	, @result_type			tinyint	= NULL
	)
WITH RECOMPILE
AS
/*************************************************************************************************
Loads to : PLT_AI

@detail_level = 1:	Detail Level (summarized by company_id, profit_ctr_id, billing date, invoice_code, receipt_id)
				2:	Summary Level (summarized by company_id, profit_ctr_id, billing month, invoice_code, customer and generator)
						Note:  This is an inner join to the BillingDetail records with sales tax on them,
								so it shows only those transactions that had sales tax applied.
								
@result_type = 1:	Return only those transactions that were actually charged sales tax. (Applies to Detail Level only)
			   2:	Return only those transactions that were exempt from sales tax.  (Applies to Detail Level only)
			   3:	Return those transactions that weren't charged sales tax, but perhaps should have been charged.  (Applies to Detail Level only)
  NULL (default):	Return all transactions with a customer or generator in the state that is specified by the user,
					regardless of whether they were charged sales tax or not.  (Applies to Detail Level only)

03/21/2013 JDB	Created.  This SP returns detail and summarized data for sales tax that EQ has
				billed on receipts and work orders.  Currently it runs for CT and NY, since
				those are the only states that we collect sales tax for.
04/02/2013 JDB	Added invoice date to the report.
04/05/2013 JDB	Added customer ID as a parameter.  Leave as NULL to retrieve for all customers.
11/04/2013 AM   GEM:26726 (26619) - Report should run by invoice date instead of billing date
12/06/2016 RWB	Started going to lunch in production, added WITH RECOMPILE to create statement, and set transaction isolation level
12/06/2016 JPB	Slow performance, reviewed sql... AW COME ON JDB.  Inner joins to composite tables WITH NO WHERE CLAUSE?
				Copied the where clause logic from outside the composite table to inside it and improved performance a ton.
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

EXECUTE sp_rpt_sales_tax '1/1/13', '1/31/13', 'NY', 1, 1
EXECUTE sp_rpt_sales_tax '1/1/13', '1/31/13', 'NY', 1, 2
EXECUTE sp_rpt_sales_tax '1/1/13', '1/31/13', 'NY', 1, 3
EXECUTE sp_rpt_sales_tax '1/1/13', '1/31/13', 'NY', 1, 4
EXECUTE sp_rpt_sales_tax '1/1/15', '1/31/15', 'CT', 1, 1
EXECUTE sp_rpt_sales_tax '1/1/13', '1/31/13', 'CT', 1, 2
EXECUTE sp_rpt_sales_tax '1/1/13', '1/31/13', 'CT', 1, 3
EXECUTE sp_rpt_sales_tax '1/1/13', '1/31/13', 'CT', 1, 4

-- For Peggy 3/21/2013 11:00 a.m.
EXECUTE sp_rpt_sales_tax '1/1/10', '12/31/11', 'NY', 1			-- 3:48		17396 records
EXECUTE sp_rpt_sales_tax '1/1/10', '12/31/11', 'NY', 2			-- 0:06		27 records

-- For Peggy 3/21/2013 12:30 p.m. (summary includes invoice_code)
EXECUTE sp_rpt_sales_tax '1/1/10', '12/31/11', 'NY', 1			-- 6:27		27047 records
EXECUTE sp_rpt_sales_tax '1/1/10', '12/31/11', 'NY', 2			-- 0:01		57 records

-- For Peggy 3/29/2013 10:00 a.m. (summary includes invoice_code)
EXECUTE sp_rpt_sales_tax '1/1/12', '12/31/12', 'NY', 2			-- 0:14		2413 records
EXECUTE sp_rpt_sales_tax '1/1/12', '12/31/12', 'NY', 1, NULL	-- 3:12		16323 records

-- For Peggy 4/2/2013 4:45 p.m. (summary includes invoice_code and invoice date)
EXECUTE sp_rpt_sales_tax '1/1/12', '12/31/12', 'NY', 2			-- 0:04		2413 records
EXECUTE sp_rpt_sales_tax '1/1/12', '12/31/12', 'NY', 1, NULL	-- 1:55		16325 records

EXECUTE sp_rpt_sales_tax '1/1/12', '12/31/12', 'NY', NULL, 2, NULL			-- 0:04		2413 records
EXECUTE sp_rpt_sales_tax '1/1/12', '12/31/12', 'NY', NULL, 1, NULL			-- 1:55		16325 records

-- For Lorraine 3/29/2013
EXECUTE sp_rpt_sales_tax '1/1/12', '12/31/12', 'CT', 1, 1, 10673
EXECUTE sp_rpt_sales_tax '1/1/12', '12/31/12', 'NY', 1, 1, 10673
*************************************************************************************************/
CREATE TABLE #tmp_sales_tax (
	company_id				int				NULL
	, profit_ctr_id			int				NULL
	, trans_source			char(1)			NULL
	, receipt_id			int				NULL
	, billing_date			datetime		NULL
	, billing_year			int				NULL
	, billing_month			tinyint			NULL
	, invoice_code			varchar(16)		NULL
	, invoice_date			datetime		NULL
	, customer_id			int				NULL
	, cust_name				varchar(75)		NULL
	, cust_addr1			varchar(75)		NULL
	, cust_addr2			varchar(75)		NULL
	, cust_addr3			varchar(75)		NULL
	, cust_city				varchar(40)		NULL
	, cust_state			varchar(2)		NULL
	, cust_zip_code			varchar(15)		NULL
	, generator_id			int				NULL
	, EPA_ID				varchar(12)		NULL
	, generator_name		varchar(75)		NULL
	, generator_address_1	varchar(75)		NULL
	, generator_address_2	varchar(75)		NULL
	, generator_address_3	varchar(75)		NULL
	, generator_city		varchar(40)		NULL
	, generator_state		varchar(2)		NULL
	, generator_zip_code	varchar(15)		NULL
	, generator_county		varchar(30)		NULL
	, dist_company_id		int				NULL
	, dist_profit_ctr_id	int				NULL
	, sort_order			tinyint			NULL
	, extended_amt			money			NULL
	, sales_tax_amt			money			NULL
	, sales_tax_percent		decimal(18,6)	NULL
	, sales_tax_state		varchar(2)		NULL
	, sales_tax_description	varchar(100)	NULL
	, sales_tax_list		varchar(255)	NULL
	, sales_tax_explanation	varchar(100)	NULL
	)
	
set transaction isolation level read uncommitted

IF @detail_level = 1
BEGIN
	INSERT INTO #tmp_sales_tax
	SELECT b.company_id
		, b.profit_ctr_id
		, b.trans_source
		, b.receipt_id
		, b.billing_date
		, CONVERT(int, DATEPART(year, b.billing_date)) AS billing_year
		, CONVERT(int, DATEPART(month, b.billing_date)) AS billing_month
		, b.invoice_code
		, b.invoice_date
		, b.customer_id
		, c.cust_name
		, ISNULL(c.cust_addr1, '') AS cust_addr1
		, ISNULL(c.cust_addr2, '') AS cust_addr2
		, ISNULL(c.cust_addr3, '') AS cust_addr3
		, ISNULL(c.cust_city, '') AS cust_city
		, ISNULL(c.cust_state, '') AS cust_state
		, ISNULL(c.cust_zip_code, '') AS cust_zip_code
		, b.generator_id
		, g.EPA_ID
		, g.generator_name
		, ISNULL(g.generator_address_1, '') AS generator_address_1
		, ISNULL(g.generator_address_2, '') AS generator_address_2
		, ISNULL(g.generator_address_3, '') AS generator_address_3
		, ISNULL(g.generator_city, '') AS generator_city
		, ISNULL(g.generator_state, '') AS generator_state
		, ISNULL(g.generator_zip_code, '') AS generator_zip_code
		, ISNULL(co.county_name, '') AS generator_county
		, bdcharges.dist_company_id
		, bdcharges.dist_profit_ctr_id
		, sort_order = CASE WHEN b.company_id = bdcharges.dist_company_id AND b.profit_ctr_id = bdcharges.dist_profit_ctr_id THEN 0 ELSE 1 END
		, SUM(ISNULL(bdcharges.extended_amt_charges, 0.00)) AS extended_amt
		, SUM(ISNULL(bdsalestax.extended_amt_salestax, 0.00)) AS sales_tax_amt
		, ISNULL(bdsalestax.sales_tax_percent, 0.00) AS sales_tax_percent
		, ISNULL(bdsalestax.sales_tax_state, '') AS sales_tax_state
		, ISNULL(bdsalestax.tax_description, '') AS sales_tax_description
		, sales_tax_list = dbo.fn_check_sales_tax(b.customer_id, b.generator_id, b.trans_source, b.company_id, b.profit_ctr_id, b.receipt_id)
		, NULL AS sales_tax_explanation
	FROM Billing b
	JOIN Customer c ON c.customer_ID = b.customer_id
		AND (@customer_id IS NULL OR c.customer_ID = @customer_id)
	JOIN (SELECT bd1.billing_uid, bd1.dist_company_id, bd1.dist_profit_ctr_id, SUM(bd1.extended_amt) AS extended_amt_charges
			FROM Billing b_inside
			JOIN Customer c_inside ON c_inside.customer_ID = b_inside.customer_id
				AND (@customer_id IS NULL OR c_inside.customer_ID = @customer_id)
			JOIN BillingDetail bd1 on b_inside.billing_uid = bd1.billing_uid
			LEFT OUTER JOIN Generator g_inside ON g_inside.generator_id = b_inside.generator_id
			LEFT OUTER JOIN County co_inside ON co_inside.county_code = g_inside.generator_county
			WHERE bd1.billingtype_uid NOT IN ( 10 )
				AND b_inside.invoice_date BETWEEN @date_from AND @date_to 
				AND (EXISTS (SELECT 1 FROM SalesTax WHERE sales_tax_state = @sales_tax_state AND sales_tax_state = g_inside.generator_state)
					OR
					 EXISTS (SELECT 1 FROM SalesTax WHERE sales_tax_state = @sales_tax_state AND sales_tax_state = c_inside.cust_state)
					 )
				AND b_inside.status_code = 'I'
			GROUP BY bd1.billing_uid, bd1.dist_company_id, bd1.dist_profit_ctr_id
		) bdcharges 
			ON bdcharges.billing_uid = b.billing_uid
	LEFT OUTER JOIN (SELECT bd2.billing_uid, bd2.dist_company_id, bd2.dist_profit_ctr_id, bd2.sales_tax_id, bd2.applied_percent, st.sales_tax_state, st.tax_description, st.sales_tax_percent, SUM(bd2.extended_amt) AS extended_amt_salestax
			FROM Billing b_inside
			JOIN Customer c_inside ON c_inside.customer_ID = b_inside.customer_id
				AND (@customer_id IS NULL OR c_inside.customer_ID = @customer_id)
			JOIN BillingDetail bd2 ON b_inside.billing_uid = bd2.billing_uid
			JOIN Product p ON p.product_ID = bd2.product_id
			JOIN SalesTax st ON st.sales_tax_system_product_code = p.product_code
				AND st.sales_tax_id = bd2.sales_tax_id
			LEFT OUTER JOIN Generator g_inside ON g_inside.generator_id = b_inside.generator_id
			LEFT OUTER JOIN County co_inside ON co_inside.county_code = g_inside.generator_county
			WHERE bd2.billingtype_uid IN ( 10 )
				AND b_inside.invoice_date BETWEEN @date_from AND @date_to 
				AND (EXISTS (SELECT 1 FROM SalesTax WHERE sales_tax_state = @sales_tax_state AND sales_tax_state = g_inside.generator_state)
					OR
					 EXISTS (SELECT 1 FROM SalesTax WHERE sales_tax_state = @sales_tax_state AND sales_tax_state = c_inside.cust_state)
					 )
				AND b_inside.status_code = 'I'
			GROUP BY bd2.billing_uid, bd2.dist_company_id, bd2.dist_profit_ctr_id, bd2.sales_tax_id, bd2.applied_percent, st.sales_tax_state, st.tax_description, st.sales_tax_percent
		) bdsalestax 
			ON bdsalestax.billing_uid = b.billing_uid
			AND bdsalestax.dist_company_id = bdcharges.dist_company_id
			AND bdsalestax.dist_profit_ctr_id = bdcharges.dist_profit_ctr_id
			AND bdsalestax.sales_tax_state = @sales_tax_state
	LEFT OUTER JOIN Generator g ON g.generator_id = b.generator_id
	LEFT OUTER JOIN County co ON co.county_code = g.generator_county
	WHERE 1=1
	-- Anitha 11/04/2013 - GEM:26619 - Report should run by invoice date instead of billing date
	--AND b.billing_date BETWEEN @billing_date_from AND @billing_date_to
	AND b.invoice_date BETWEEN @date_from AND @date_to 
	AND (EXISTS (SELECT 1 FROM SalesTax WHERE sales_tax_state = @sales_tax_state AND sales_tax_state = g.generator_state)
		OR
		 EXISTS (SELECT 1 FROM SalesTax WHERE sales_tax_state = @sales_tax_state AND sales_tax_state = c.cust_state)
		 )
	AND b.status_code = 'I'
	GROUP BY b.company_id
		, b.profit_ctr_id
		, b.trans_source
		, b.receipt_id
		, b.billing_date
		, b.invoice_code
		, b.invoice_date
		, b.customer_id
		, c.cust_name
		, c.cust_addr1
		, c.cust_addr2
		, c.cust_addr3
		, c.cust_city
		, c.cust_state
		, c.cust_zip_code
		, b.generator_id
		, g.EPA_ID
		, g.generator_name
		, g.generator_address_1
		, g.generator_address_2
		, g.generator_address_3
		, g.generator_city
		, g.generator_state
		, g.generator_zip_code
		, co.county_name
		, bdcharges.dist_company_id
		, bdcharges.dist_profit_ctr_id
		, bdsalestax.sales_tax_percent
		, bdsalestax.sales_tax_state
		, bdsalestax.tax_description
	ORDER BY billing_year
		, billing_month
		, b.billing_date
		, sales_tax_state
		, sales_tax_description
		, b.company_id
		, b.profit_ctr_id
		, b.trans_source
		, b.receipt_id
		, sort_order
		, bdcharges.dist_company_id
		, bdcharges.dist_profit_ctr_id
	
	UPDATE #tmp_sales_tax SET sales_tax_explanation = sales_tax_list
	WHERE sales_tax_list = 'Exempt'
	
	UPDATE #tmp_sales_tax SET sales_tax_explanation = 'Sales Tax Not Configured Properly'
	WHERE sales_tax_list = 'Warning'
	
	UPDATE #tmp_sales_tax SET sales_tax_explanation = 'Various Sales Taxes May Apply'
	WHERE sales_tax_list LIKE '%,%'
		
	UPDATE #tmp_sales_tax SET sales_tax_explanation = (SELECT ISNULL(tax_description, 'Unknown')
		FROM SalesTax st
		WHERE st.sales_tax_id = CONVERT(int, RTRIM(LTRIM(#tmp_sales_tax.sales_tax_list)))
		)
	WHERE sales_tax_list IS NOT NULL
	AND sales_tax_explanation IS NULL
	
	IF @result_type = 1
	-- Only include those transactions that were actually charged sales tax.
	BEGIN
		DELETE #tmp_sales_tax WHERE sales_tax_percent = 0
	END
	
	IF @result_type = 2
	-- Only include those transactions that were exempt from sales tax.
	BEGIN
		DELETE #tmp_sales_tax WHERE sales_tax_explanation <> 'Exempt'
	END
	
	IF @result_type = 3
	-- Only include those transactions that weren't charged sales tax, but perhaps should have been charged. 
	BEGIN
		DELETE #tmp_sales_tax WHERE NOT (sales_tax_percent = 0 AND sales_tax_explanation <> 'Exempt')
	END
	
	SELECT
		company_id				
		, profit_ctr_id			
		, trans_source			
		, receipt_id			
		, billing_date			
		, billing_year			
		, billing_month			
		, invoice_code		
		, invoice_date	
		, customer_id			
		, cust_name				
		, cust_addr1			
		, cust_addr2			
		, cust_addr3			
		, cust_city				
		, cust_state			
		, cust_zip_code			
		, generator_id			
		, EPA_ID				
		, generator_name		
		, generator_address_1	
		, generator_address_2	
		, generator_address_3	
		, generator_city		
		, generator_state		
		, generator_zip_code	
		, generator_county		
		, dist_company_id		
		, dist_profit_ctr_id	
		--, sort_order			
		, extended_amt			
		, sales_tax_amt			
		, sales_tax_percent		
		, sales_tax_state		
		, sales_tax_description
		--, sales_tax_list		
		, sales_tax_explanation
	FROM #tmp_sales_tax

END



IF @detail_level = 2 
BEGIN
	INSERT INTO #tmp_sales_tax (
		company_id				
		, profit_ctr_id		
		, billing_year			
		, billing_month			
		, invoice_code	
		, invoice_date		
		, customer_id			
		, cust_name				
		, cust_addr1			
		, cust_addr2			
		, cust_addr3			
		, cust_city				
		, cust_state			
		, cust_zip_code			
		, generator_id			
		, EPA_ID				
		, generator_name		
		, generator_address_1	
		, generator_address_2	
		, generator_address_3	
		, generator_city		
		, generator_state		
		, generator_zip_code	
		, generator_county		
		, dist_company_id		
		, dist_profit_ctr_id	
		, sort_order			
		, extended_amt			
		, sales_tax_amt			
		, sales_tax_percent		
		, sales_tax_state		
		, sales_tax_description
		)
	SELECT b.company_id
		, b.profit_ctr_id
		, CONVERT(int, DATEPART(year, b.billing_date)) AS billing_year
		, CONVERT(int, DATEPART(month, b.billing_date)) AS billing_month
		, b.invoice_code
		, b.invoice_date
		, b.customer_id
		, c.cust_name
		, ISNULL(c.cust_addr1, '') AS cust_addr1
		, ISNULL(c.cust_addr2, '') AS cust_addr2
		, ISNULL(c.cust_addr3, '') AS cust_addr3
		, ISNULL(c.cust_city, '') AS cust_city
		, ISNULL(c.cust_state, '') AS cust_state
		, ISNULL(c.cust_zip_code, '') AS cust_zip_code
		, b.generator_id
		, g.EPA_ID
		, g.generator_name
		, ISNULL(g.generator_address_1, '') AS generator_address_1
		, ISNULL(g.generator_address_2, '') AS generator_address_2
		, ISNULL(g.generator_address_3, '') AS generator_address_3
		, ISNULL(g.generator_city, '') AS generator_city
		, ISNULL(g.generator_state, '') AS generator_state
		, ISNULL(g.generator_zip_code, '') AS generator_zip_code
		, ISNULL(co.county_name, '') AS generator_county
		, bdcharges.dist_company_id
		, bdcharges.dist_profit_ctr_id
		, sort_order = CASE WHEN b.company_id = bdcharges.dist_company_id AND b.profit_ctr_id = bdcharges.dist_profit_ctr_id THEN 0 ELSE 1 END
		, SUM(ISNULL(bdcharges.extended_amt_charges, 0.00)) AS extended_amt
		, SUM(ISNULL(bdsalestax.extended_amt_salestax, 0.00)) AS sales_tax_amt
		, ISNULL(bdsalestax.sales_tax_percent, 0.00) AS sales_tax_percent
		, ISNULL(bdsalestax.sales_tax_state, '') AS sales_tax_state
		, ISNULL(bdsalestax.tax_description, '') AS sales_tax_description
	FROM Billing b
	JOIN Customer c ON c.customer_ID = b.customer_id
		AND (@customer_id IS NULL OR c.customer_ID = @customer_id)
	JOIN (SELECT bd1.billing_uid, bd1.dist_company_id, bd1.dist_profit_ctr_id, SUM(bd1.extended_amt) AS extended_amt_charges
			FROM Billing b_inside
			JOIN Customer c_inside ON c_inside.customer_ID = b_inside.customer_id
				AND (@customer_id IS NULL OR c_inside.customer_ID = @customer_id)
			JOIN BillingDetail bd1 ON b_inside.billing_uid = bd1.billing_uid
			WHERE bd1.billingtype_uid NOT IN ( 10 )
			 AND b_inside.invoice_date BETWEEN @date_from AND @date_to 
			 AND b_inside.status_code = 'I'
			GROUP BY bd1.billing_uid, bd1.dist_company_id, bd1.dist_profit_ctr_id
		) bdcharges 
			ON bdcharges.billing_uid = b.billing_uid
	JOIN (SELECT bd2.billing_uid, bd2.dist_company_id, bd2.dist_profit_ctr_id, bd2.sales_tax_id, bd2.applied_percent, st.sales_tax_state, st.tax_description, st.sales_tax_percent, SUM(bd2.extended_amt) AS extended_amt_salestax
			FROM Billing b_inside
			JOIN Customer c_inside ON c_inside.customer_ID = b_inside.customer_id
				AND (@customer_id IS NULL OR c_inside.customer_ID = @customer_id)
			JOIN BillingDetail bd2 on b_inside.billing_uid = bd2.billing_uid
			JOIN Product p ON p.product_ID = bd2.product_id
			JOIN SalesTax st ON st.sales_tax_system_product_code = p.product_code
				AND st.sales_tax_id = bd2.sales_tax_id
			WHERE bd2.billingtype_uid IN ( 10 )
			 AND b_inside.invoice_date BETWEEN @date_from AND @date_to 
			 AND b_inside.status_code = 'I'
			GROUP BY bd2.billing_uid, bd2.dist_company_id, bd2.dist_profit_ctr_id, bd2.sales_tax_id, bd2.applied_percent, st.sales_tax_state, st.tax_description, st.sales_tax_percent
		) bdsalestax 
			ON bdsalestax.billing_uid = b.billing_uid
			AND bdsalestax.dist_company_id = bdcharges.dist_company_id
			AND bdsalestax.dist_profit_ctr_id = bdcharges.dist_profit_ctr_id
			AND bdsalestax.sales_tax_state = @sales_tax_state
	LEFT OUTER JOIN Generator g ON g.generator_id = b.generator_id
	LEFT OUTER JOIN County co ON co.county_code = g.generator_county
	WHERE 1=1
	-- Anitha 11/04/2013 - GEM:26619 - Report should run by invoice date instead of billing date
	--AND b.billing_date BETWEEN @billing_date_from AND @billing_date_to
	 AND b.invoice_date BETWEEN @date_from AND @date_to 
	--AND (EXISTS (SELECT 1 FROM SalesTax WHERE sales_tax_state = g.generator_state)
	--	OR
	--	 EXISTS (SELECT 1 FROM SalesTax WHERE sales_tax_state = c.cust_state)
	--	)
	--AND ((@sales_tax_state = 'ALL' 
	--	AND (EXISTS (SELECT 1 FROM SalesTax WHERE sales_tax_state = g.generator_state)
	--		OR
	--		 EXISTS (SELECT 1 FROM SalesTax WHERE sales_tax_state = c.cust_state)
	--		)
	--	)
	--	OR (@sales_tax_state <> 'ALL' AND (g.generator_state = @sales_tax_state OR c.cust_state = @sales_tax_state))
	--	)

	-- Since this is a summary report showing only those transactions with sales tax applied,
	-- we can just pick up sales tax for the state that the user specified.
	AND b.status_code = 'I'
	GROUP BY b.company_id
		, b.profit_ctr_id
		, DATEPART(year, b.billing_date)
		, DATEPART(month, b.billing_date)
		, b.invoice_code
		, b.invoice_date
		, b.customer_id
		, c.cust_name
		, c.cust_addr1
		, c.cust_addr2
		, c.cust_addr3
		, c.cust_city
		, c.cust_state
		, c.cust_zip_code
		, b.generator_id
		, g.EPA_ID
		, g.generator_name
		, g.generator_address_1
		, g.generator_address_2
		, g.generator_address_3
		, g.generator_city
		, g.generator_state
		, g.generator_zip_code
		, co.county_name
		, bdcharges.dist_company_id
		, bdcharges.dist_profit_ctr_id
		, bdsalestax.sales_tax_percent
		, bdsalestax.sales_tax_state
		, bdsalestax.tax_description
	ORDER BY billing_year
		, billing_month
		, sales_tax_state
		, sales_tax_description
		, b.company_id
		, b.profit_ctr_id
		, c.cust_name
		, g.generator_name
		, sort_order
		, bdcharges.dist_company_id
		, bdcharges.dist_profit_ctr_id
		
		

	SELECT
		company_id
		, profit_ctr_id	
		, billing_year	
		, billing_month
		, invoice_code
		, invoice_date
		, customer_id
		, cust_name	
		, cust_addr1
		, cust_addr2
		, cust_addr3
		, cust_city	
		, cust_state
		, cust_zip_code
		, generator_id
		, EPA_ID
		, generator_name
		, generator_address_1
		, generator_address_2
		, generator_address_3
		, generator_city
		, generator_state
		, generator_zip_code
		, generator_county
		, dist_company_id
		, dist_profit_ctr_id	
		, extended_amt
		, sales_tax_amt
		, sales_tax_percent
		, sales_tax_state
		, sales_tax_description
	FROM #tmp_sales_tax

END

DROP TABLE #tmp_sales_tax

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_sales_tax] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_sales_tax] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_sales_tax] TO [EQAI]
    AS [dbo];

