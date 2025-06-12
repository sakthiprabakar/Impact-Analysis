CREATE PROCEDURE sp_rpt_territory_ytd_detail
	@date_from		datetime
,	@date_to		datetime
,	@copc_list		varchar(max)  -- accepts list: '2|21,14|0,22|0'
,	@filter_field	varchar(20)		-- one of: 'NAM_ID', 'REGION_ID', 'BILLING_PROJECT_ID'
,	@filter_list	varchar(max)
,	@debug			int
AS
----------------------------------------------------------------------------------------------------------------------
/* Territory Report Assumptions:
      -  the per load bundle charges are left with the disposal because we can't keep the
         disposal as a quantity price relationship
      -  use the current quote trans prices or else they cannot be corrected

Modifications:
06/03/1999 NPW	Outer join on Ticket.customer_id and Customer.customer_id is changed
		to normal join in the main select
06/08/1999 LJT	added discount percent to the calculation
07/06/1999 LJT	changed ticket date to invoice date
01/13/2000 LJT	Modified to add Territory specifications for 2000
01/29/2001 LJT	Added joins on Cust_name and company to the final monthly and ytd select.
10/01/2003 JDB	Modified to work with new Commission Report setup and call to sp_territorywork_calc
10/07/2003 LJT	Added Bulk Flag
12/30/2004 SCC	Changed ticket_id to line_id
11/13/2005 SCC	Changed name from sp_territory_detail and removed month, year arguments
11/29/2005 SCC  Net monthly amounts were including all YTD amounts; fixed
12/02/2005 SCC	Changed to put back the dates so the YTD is for the dates selected by the used, not today!
10/09/2007 rg   modified code for ai_db fro prodtestdev
2/9/2011   rjg	Moved from PLT_XX_AI and changed the calculation query to use the sp_rpt_territory_calc_ai, added BillingDetail joins -- majority of changes were done t
03/07/2011 SK	Modified to match the new #territorywork layout on calc_ai proc
03/09/2011 SK	Modified to get revenue from extended_amt 
3/10/2011  SK	Appended ProductID to #TerritoryWork, interpret defaults for territorylist & copc list
3/11/2011  SK	Missing YTD calculation fixed (start date needed to reset to Jan 1)
11/01/2011 JPB	Added NAM_ID, REGION_ID, BILLING_PROJECT_ID to #TerritoryWork table.
11/01/2011 JPB	... Also Added NAM_USER_NAME, REGION_DESC, BILLING_PROJECT_NAME, TERRITORY_USER_NAME, TERRITORY_DESC
03/21/2014 JDB	Fixed the JOIN between #YTDSum and #MonSum to account for the NULL values that will be present for customers that don't have a NAM or Region.
07/08/2019 JPB	Cust_name size changed 40->75
06/16/2023 Devops 65744--Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
-- all territories:  00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 41, 51

-- OLD:
		EXECUTE dbo.sp_rpt_territory_ytd_detail
		  @date_from = '2-1-2011',
		  @date_to = '2-28-2011',
		  @territory_list = '05',
		  @copc_list='14|0, 14|1, 15|0, 15|01',
		  @debug = 1

-- NEW:  
sp_rpt_territory_ytd_detail
	@date_from = '2-1-2011'
,	@date_to = '2-28-2011'
,	@copc_list = '14|0, 14|1, 15|0, 15|01'
,	@filter_field	= 'territory_code'
,	@filter_list	= '05, 06'
,	@debug			= 0

sp_rpt_territory_ytd_detail
	@date_from = '2-1-2011'
,	@date_to = '2-28-2011'
,	@copc_list = '14|0, 14|1, 15|0, 15|01'
,	@filter_field	= 'nam_id'
,	@filter_list	= '1'
,	@debug			= 0

sp_rpt_territory_ytd_detail
	@date_from = '2-1-2011'
,	@date_to = '2-28-2011'
,	@copc_list = '14|0, 14|1, 15|0, 15|01'
,	@filter_field	= 'region_id'
,	@filter_list	= '1'
,	@debug			= 0
  
*/
----------------------------------------------------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@company_count		int,
	@category_count		int,
	@filter_item_count	int,
	@company_id			int,
	@job_type			char(1),
	@category			int,
	@filter_value		varchar(8),
	@month				int


-- Get the copc list into tmp_copc
CREATE TABLE #tmp_copc ([company_id] int, profit_ctr_id int)
IF @copc_list = 'ALL'
	INSERT #tmp_copc
	SELECT ProfitCenter.company_ID,	ProfitCenter.profit_ctr_ID FROM ProfitCenter WHERE status = 'A'
ELSE
	INSERT #tmp_copc
	SELECT 
		RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) AS company_id,
		RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) AS profit_ctr_id
	from dbo.fn_SplitXsvText(',', 0, @copc_list) WHERE isnull(row, '') <> ''

IF @debug = 1 print 'SELECT * FROM #tmp_copc'
IF @debug = 1 SELECT * FROM #tmp_copc
      
-- Get the MONTH for which to run the report
SET @month = DATEPART(mm, @date_to)
IF @debug = 1 print 'month: ' + convert(varchar(2), @month) + ' dates: ' + convert(varchar(30), @date_from) + ' to ' + convert(varchar(30), @date_to) 

-- Create TerritoryWork
CREATE TABLE #TerritoryWork (
	company_id					int				NULL,
	profit_ctr_id				int				NULL,
	trans_source				char(1)			NULL,
	receipt_id					int				NULL,
	line_id						int				NULL,
	price_id					int				NULL,
	trans_type					char(1)			NULL,
	ref_line_id					int				NULL,
	workorder_sequence_id		varchar(15)		NULL,
	workorder_resource_item		varchar(15)		NULL,
	workorder_resource_type		varchar(15)		NULL,
	Workorder_resource_category Varchar(40)		NULL,
	billing_type 				varchar(20)		NULL,
	dist_company_id 			int 			NULL,
	dist_profit_ctr_id 			int 			NULL,
	extended_amt				float 			NULL,	
	territory_code				varchar(8)		NULL,
	job_type					char(1)			NULL,
	category					int				NULL,
	category_reason				int				NULL,
	commissionable_flag 		char(1) 		NULL,
	invoice_date				datetime		NULL,
	month						int				NULL,
	year						int				NULL,
	customer_id					int				NULL,
	cust_name					varchar(75)		NULL,
	treatment_id				int				NULL,
	bill_unit_code				varchar(4)		NULL,
	waste_code					varchar(10)		NULL,
	profile_id					int				NULL,
	quote_id					int				NULL,
	approval_code				varchar(40)		NULL,
	TSDF_code					Varchar(15)     NULL,
	TSDF_EQ_FLAG				Char(1)			NULL,
	date_added					datetime		NULL,
	tran_flag					char(1)			NULL,
	bulk_flag					Char(1)			NULL,
	Orig_extended_amt			float			NULL, 
	split_flag					Char(1)			NULL,
	Split_extended_amt			float			NULL,
	WOD_Manifest				Varchar(15)		NULL,
	WOD_Line					int				NULL,
	EQ_Equip_Flag				Char(1)			NULL,
	product_id					int				NULL
	, nam_id					int				NULL
	, nam_user_name				varchar(40)		NULL
	, region_id					int				NULL
	, region_desc				varchar(50)		NULL
	, billing_project_id		int				NULL
	, billing_project_name		varchar(40)		NULL
	, territory_user_name		varchar(40)		NULL
	, territory_desc			varchar(40)		NULL
) 

CREATE INDEX approval_code ON #TerritoryWork (approval_code)
CREATE INDEX trans_type ON #TerritoryWork (trans_type)
CREATE INDEX waste_code ON #TerritoryWork (waste_code)
CREATE INDEX company_id ON #TerritoryWork (company_id)
CREATE INDEX line_id ON #TerritoryWork (line_id)
CREATE INDEX receipt_id ON #TerritoryWork (receipt_id)
CREATE INDEX woresitem ON #TerritoryWork (workorder_resource_item)
CREATE INDEX tsdfcode ON #TerritoryWork (tsdf_code)
CREATE INDEX category ON #TerritoryWork (category)
CREATE INDEX treatment_id ON #TerritoryWork (treatment_id)
CREATE INDEX ix_tw07 ON #TerritoryWork (customer_id, category, job_type, bill_unit_code, waste_code)
CREATE INDEX nam_id ON #TerritoryWork (nam_id)
CREATE INDEX region_id ON #TerritoryWork (region_id)
CREATE INDEX billing_project_id ON #TerritoryWork (billing_project_id)

-- Create #MonSum
CREATE TABLE #MonSum (
	filter_value	varchar(8)		NULL,
	filter_description varchar(100) NULL,
	customer_id		int				NULL,
	cust_name		varchar(75)		NULL,
	category		int				NULL,
	job_type		char(1)			NULL,
	bill_unit_code	varchar(4)		NULL,
	waste_code		varchar(10)		NULL,
	extended_amt	float 			NULL,
	company_id		int				NULL,
	dist_company_id int 			NULL )

-- Create #YTDSum
CREATE TABLE #YTDSum (
	filter_value	varchar(8)		NULL,
	filter_description varchar(100) NULL,
	customer_id		int				NULL,
	cust_name		varchar(75)		NULL,
	category		int				NULL,
	job_type		char(1)			NULL,
	bill_unit_code	varchar(4)		NULL,
	waste_code		varchar(10)		NULL,
	extended_amt	float 			NULL,
	company_id		int				NULL,
	dist_company_id int 			NULL )

-- Reset the start date to the current year to compute YTD calc
SET @date_from = '01-01-' + CONVERT(varchar(4), Year(@date_from))
	
--	The sp_rpt_territory_calc_ai relies on the existence of #TerritoryWork, #tmp_copc and #tmp_territory
EXEC sp_rpt_territory_calc_ai @date_from, @date_to, @filter_field, @filter_list, @debug

-- delete non-commissionable records ?
DELETE FROM #TerritoryWork where commissionable_flag = 'F'

-- Create a temp table to hold the companies
SELECT DISTINCT 
	company_id,
	0 AS process_flag
INTO #tmp_company
FROM #TerritoryWork ORDER BY company_id
IF @debug = 1 print 'SELECT * FROM #tmp_company'
IF @debug = 1 SELECT * FROM #tmp_company

-- Create a temp table to hold the categories
SELECT DISTINCT 
	job_type,
	category,
	0 AS process_flag
INTO #tmp_category 
FROM commission ORDER BY job_type, category
IF @debug = 1 print 'SELECT * FROM #tmp_category'
IF @debug = 1 SELECT * FROM #tmp_category

-- Create a temp table to hold the filter values
SELECT DISTINCT 
	CASE @filter_field
		WHEN '' then NULL
		WHEN 'NAM_ID' THEN convert(varchar(8), nam_id)
		WHEN 'REGION_ID' THEN convert(varchar(8), region_id)
		WHEN 'BILLING_PROJECT_ID' THEN convert(varchar(8), billing_project_id)
		WHEN 'TERRITORY_CODE' THEN convert(varchar(8), territory_code)
	END as filter_field
	, 0 AS process_flag
INTO #tmp_filter_values
FROM #TerritoryWork 
ORDER BY
	CASE @filter_field
		WHEN '' then NULL
		WHEN 'NAM_ID' THEN convert(varchar(8), nam_id)
		WHEN 'REGION_ID' THEN convert(varchar(8), region_id)
		WHEN 'BILLING_PROJECT_ID' THEN convert(varchar(8), billing_project_id)
		WHEN 'TERRITORY_CODE' THEN convert(varchar(8), territory_code)
	END 
	
IF @debug = 1 print 'SELECT * FROM #tmp_filter_values'
IF @debug = 1 SELECT * FROM #tmp_filter_values


-- INSERT Monthly total
INSERT INTO #MonSum
SELECT DISTINCT
	convert(varchar(8), 
		CASE @filter_field
			WHEN '' then NULL
			WHEN 'NAM_ID' THEN nam_id
			WHEN 'REGION_ID' THEN region_id
			WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
			WHEN 'TERRITORY_CODE' THEN territory_code
		END
	),
	CASE @filter_field
		WHEN '' then NULL
		WHEN 'NAM_ID' THEN nam_user_name
		WHEN 'REGION_ID' THEN region_desc
		WHEN 'BILLING_PROJECT_ID' THEN billing_project_name
		WHEN 'TERRITORY_CODE' THEN isnull(territory_user_name + ' - ', '') + isnull(territory_desc, '')
	END as filter_description,
	customer_id,
	cust_name,
	category,
	job_type,
	bill_unit_code,
	waste_code,
	SUM(IsNull(extended_amt, 0.00)),
	--quantity = SUM(quantity),
	--price = SUM(ROUND((IsNull(billing_price,0)) * ((100 - IsNull(discount_percent,0)) / 100), 2)),
	company_id,
	dist_company_id
FROM #TerritoryWork
WHERE month = @month
GROUP BY 
	convert(varchar(8), 
		CASE @filter_field
			WHEN '' then NULL
			WHEN 'NAM_ID' THEN nam_id
			WHEN 'REGION_ID' THEN region_id
			WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
			WHEN 'TERRITORY_CODE' THEN territory_code
		END
	),
	CASE @filter_field
		WHEN '' then NULL
		WHEN 'NAM_ID' THEN nam_user_name
		WHEN 'REGION_ID' THEN region_desc
		WHEN 'BILLING_PROJECT_ID' THEN billing_project_name
		WHEN 'TERRITORY_CODE' THEN isnull(territory_user_name + ' - ', '') + isnull(territory_desc, '')
	END,
	customer_id, cust_name, category, job_type, bill_unit_code, waste_code, company_id, dist_company_id
IF @debug = 1 PRINT 'SELECT * FROM #MonSum (MON total)'
IF @debug = 1 SELECT * FROM #MonSum

-- INSERT YTD total
INSERT INTO #YTDSum
SELECT DISTINCT
	convert(varchar(8), 
		CASE @filter_field
			WHEN '' then NULL
			WHEN 'NAM_ID' THEN nam_id
			WHEN 'REGION_ID' THEN region_id
			WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
			WHEN 'TERRITORY_CODE' THEN territory_code
		END
	),
	CASE @filter_field
		WHEN '' then NULL
		WHEN 'NAM_ID' THEN nam_user_name
		WHEN 'REGION_ID' THEN region_desc
		WHEN 'BILLING_PROJECT_ID' THEN billing_project_name
		WHEN 'TERRITORY_CODE' THEN isnull(territory_user_name + ' - ', '') + isnull(territory_desc, '')
	END as filter_description,
	customer_id,
	cust_name,
	category,
	job_type,
	bill_unit_code,
	waste_code,
	SUM(IsNull(extended_amt, 0.00)),
	--quantity = SUM(quantity),
	--price = SUM(ROUND((IsNull(billing_price,0)) * ((100 - IsNull(discount_percent,0)) / 100), 2)),
	company_id,
	dist_company_id
FROM #TerritoryWork
GROUP BY 
	convert(varchar(8), 
		CASE @filter_field
			WHEN '' then NULL
			WHEN 'NAM_ID' THEN nam_id
			WHEN 'REGION_ID' THEN region_id
			WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
			WHEN 'TERRITORY_CODE' THEN territory_code
		END
	),
	CASE @filter_field
		WHEN '' then NULL
		WHEN 'NAM_ID' THEN nam_user_name
		WHEN 'REGION_ID' THEN region_desc
		WHEN 'BILLING_PROJECT_ID' THEN billing_project_name
		WHEN 'TERRITORY_CODE' THEN isnull(territory_user_name + ' - ', '') + isnull(territory_desc, '')
	END,
	customer_id, cust_name, category, job_type, bill_unit_code, waste_code, company_id, dist_company_id
IF @debug = 1 PRINT 'SELECT * FROM #YTDSum (YTD total)'
IF @debug = 1 SELECT * FROM #YTDSum


-- Insert into #tmp
SELECT DISTINCT
	y.filter_value,
	y.filter_description,
	y.customer_id,
	y.cust_name AS customer_name,
	y.category,
	y.job_type,
	y.bill_unit_code,
	y.waste_code,
	IsNull(m.extended_amt, 0.00) AS net_monthly,
	IsNull(y.extended_amt, 0.00) AS net_ytd,
	--m.quantity AS qty_monthly,
	--y.quantity AS qty_ytd,
	--m.price AS net_monthly,
	--y.price AS net_ytd,
	--y.commission_company_id,
	y.company_id,
	y.dist_company_id
INTO #tmp
FROM #YTDSum y
LEFT OUTER JOIN #MonSum m
	--ON m.filter_value = y.filter_value
	ON ISNULL(m.filter_value, -9999) = ISNULL(y.filter_value, -9999)
	AND m.customer_id = y.customer_id
	AND m.cust_name = y.cust_name
	AND m.category = y.category
	AND m.job_type = y.job_type
	AND m.bill_unit_code = y.bill_unit_code
	AND m.waste_code = y.waste_code
	AND m.company_id = y.company_id
	AND m.dist_company_id = y.dist_company_id
ORDER BY y.filter_value, y.customer_id

CREATE TABLE #Output (
	record_type			int			NULL,
	filter_value		varchar(8)	NULL,
	filter_description	varchar(100) NULL,
	customer_ID			int			NULL,
	customer_name		varchar(40)	NULL,
	category			int			NULL,
	job_type			char(1)		NULL,
	bill_unit_code		varchar(4)	NULL,
	waste_code			varchar(10)	NULL,
	net_monthly			float		NULL,
	net_ytd				float		NULL,
	company				int			NULL,
	dist_company_id		int			NULL ) 

INSERT INTO #Output SELECT 1, * FROM #tmp

IF @debug = 1 PRINT 'SELECT * FROM #Output (After record_type 1)'
IF @debug = 1 SELECT * FROM #output

/************************************************************/
-- Process each company in the list
UPDATE #tmp_company SET process_flag = 0
UPDATE #tmp_category SET process_flag = 0
UPDATE #tmp_filter_values SET process_flag = 0
SELECT @company_count = COUNT(*) FROM #tmp_company
WHILE @company_count > 0
BEGIN
	-- Get the company
	SET ROWCOUNT 1
	SELECT @company_id = company_id FROM #tmp_company WHERE process_flag = 0
	SET ROWCOUNT 0

	IF @debug = 1 PRINT 'Looping over companies: ' + convert(varchar(10), @company_id)

	UPDATE #tmp_category SET process_flag = 0
	UPDATE #tmp_filter_values SET process_flag = 0
	/************************************************************/
	-- Process each category in the list
	SELECT @category_count = COUNT(*) FROM #tmp_category
	WHILE @category_count > 0
	BEGIN
		-- Get the category
		SET ROWCOUNT 1
		SELECT @job_type = job_type, @category = category FROM #tmp_category WHERE process_flag = 0
		SET ROWCOUNT 0

		IF @debug = 1 PRINT 'Looping over categories: ' + @job_type + ', ' + convert(varchar(10), @category)

		UPDATE #tmp_filter_values SET process_flag = 0
		/************************************************************/
		-- Process each filter value in the list
		SELECT @filter_item_count = COUNT(*) FROM #tmp_filter_values
		WHILE @filter_item_count > 0
		BEGIN
			-- Get the filter value
			SET ROWCOUNT 1
			SELECT @filter_value = filter_field FROM #tmp_filter_values WHERE process_flag = 0
			SET ROWCOUNT 0

			IF @debug = 1 PRINT 'Looping over filter values: ' + @filter_value

			-- Compute Subtotals insert with record_type = 2
			INSERT INTO #Output
			SELECT	
				2,
				filter_value, 
				filter_description,
				1000000, 
				'ZZZZZZZZZ', 
				category, 
				job_type, 
				'', 
				'', 
				SUM(IsNull(net_monthly, 0.00)),
				SUM(IsNull(net_ytd, 0.00)),
				company_id,
				dist_company_id
			FROM #tmp
			WHERE company_id = @company_id AND job_type = @job_type AND category = @category AND convert(int, filter_value) = convert(int, @filter_value)
			GROUP BY company_id, dist_company_id, job_type, category, filter_value, filter_description

			IF @debug = 1 PRINT 'After subtotal (2) insert'
	
			-- Update to process the next filter value
			SET ROWCOUNT 1
			UPDATE #tmp_filter_values SET process_flag = 1 WHERE convert(int, filter_field) = convert(int, @filter_value) AND process_flag = 0
			SET ROWCOUNT 0
			SELECT @filter_item_count = @filter_item_count - 1
		END
		/************************************************************/

		-- Update to process the next category
		SET ROWCOUNT 1
		UPDATE #tmp_category SET process_flag = 1 WHERE job_type = @job_type AND category = @category AND process_flag = 0
		SET ROWCOUNT 0
		SELECT @category_count = @category_count - 1
	END
	/************************************************************/

	-- Update to process the next company
	SET ROWCOUNT 1
	UPDATE #tmp_company SET process_flag = 1 WHERE company_id = @company_id AND process_flag = 0
	SET ROWCOUNT 0
	SELECT @company_count = @company_count - 1
END
/************************************************************/

------------------------------------------------------------------------
-- Repeat loop to get totals per category for each filter value
------------------------------------------------------------------------
UPDATE #tmp_category SET process_flag = 0
UPDATE #tmp_filter_values SET process_flag = 0
/************************************************************/
--Process each category in the list
SELECT @category_count = COUNT(*) FROM #tmp_category
WHILE @category_count > 0
BEGIN
	-- Get the category
	SET ROWCOUNT 1
	SELECT @job_type = job_type, @category = category FROM #tmp_category WHERE process_flag = 0
	SET ROWCOUNT 0

	UPDATE #tmp_filter_values SET process_flag = 0
	/************************************************************/
	-- Process each filter value in the list
	SELECT @filter_item_count = COUNT(*) FROM #tmp_filter_values
	WHILE @filter_item_count > 0
	BEGIN
		-- Get the filter value
		SET ROWCOUNT 1
		SELECT @filter_value = filter_field FROM #tmp_filter_values WHERE process_flag = 0
		SET ROWCOUNT 0

		-- -- Compute Subtotals insert with record_type = 3
		INSERT INTO #Output
		SELECT	
			3 as record_type,
			filter_value, 
			filter_description,
			1000000 as customer_id, 
			'ZZZZZZZZZ' as customer_name, 
			category as category, 
			job_type as job_type, 
			'' as bill_unit_code, 
			'' as waste_code, 
			SUM(ISNULL(net_monthly, 0.0)) as net_monthly,
			SUM(ISNULL(net_ytd, 0.0)) as net_ytd,
			99 as company,	-- this is set to 99 so that the PB object sorts it at the bottom of each category
			dist_company_id
		FROM #tmp
		WHERE job_type = @job_type AND category = @category AND convert(int, filter_value) = convert(int, @filter_value)
		GROUP BY dist_company_id, job_type, category, filter_value, filter_description

		-- Update to process the next filter_value
		SET ROWCOUNT 1
		UPDATE #tmp_filter_values SET process_flag = 1 WHERE convert(int, filter_field) = convert(int, @filter_value) AND process_flag = 0
		SET ROWCOUNT 0
		SELECT @filter_item_count = @filter_item_count - 1
	END
	/************************************************************/

	-- Update to process the next category
	SET ROWCOUNT 1
	UPDATE #tmp_category SET process_flag = 1 WHERE job_type = @job_type AND category = @category AND process_flag = 0
	SET ROWCOUNT 0
	SELECT @category_count = @category_count - 1
END
/************************************************************/

-- Set category to 99 so that Unassigned sorts to the bottom.
UPDATE #Output SET category = 99 WHERE category = 0

-- Fetch Results
SELECT DISTINCT
	record_type,
	@filter_field as filter_field,
	filter_value,
	filter_description,
	customer_id,
	customer_name,
	category,
	job_type,
	bill_unit_code,
	waste_code,
	net_monthly,
	net_ytd,
	company,
	dist_company_id
FROM #Output
ORDER BY record_type, filter_value, customer_id

DROP TABLE #Output
DROP TABLE #tmp
DROP TABLE #tmp_company
DROP TABLE #tmp_category
DROP TABLE #tmp_filter_values
DROP TABLE #TerritoryWork
DROP TABLE #MonSum
DROP TABLE #YTDSum


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_ytd_detail] TO [EQAI]
    AS [dbo];

