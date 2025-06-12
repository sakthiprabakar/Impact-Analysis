CREATE PROCEDURE sp_rpt_territory_ytd_sum 
	@date_from	datetime 
,	@date_to	datetime 
,	@copc_list varchar(max) -- accepts list: '2|21,14|0,22|0'
,	@filter_field	varchar(20)		-- one of: 'NAM_ID', 'REGION_ID', 'BILLING_PROJECT_ID', 'TERRITORY_CODE', '' ('' = No filter)
,	@filter_list	varchar(max)
,	@debug			int
AS
----------------------------------------------------------------------------------------------------------------------
/*
Modifications:
06/03/1999 NPW	Outer join on Ticket.customer_id and Customer.customer_id is changed 
                to normal join in the main select
06/08/1999 LJT	Added discount percent to the calculation
07/06/199  LJT	Changed ticket date to invoice date
01/13/2000 LJT	Modified to add Territory specifications for 2000
10/01/2003 JDB	Modified to work with new Commission Report setup and call to sp_territorywork_calc
10/07/2003 LJT	Added bulk flag
12/30/2004 SCC	Changed ticket_id to line_id
11/21/2005 SCC	Changed name from sp_territory_sum and removed month, year arguments
12/02/2005 SCC	Changed to put back the dates so the YTD is for the dates selected by the used, not today!
10/09/2007 rg   modified for prodtestdev
03/07/2011 SK	Modified to match the new #territorywork layout on calc_ai proc
03/08/2011 SK	Modified to get revenue from extended_amt 
3/10/2011  SK	Appended ProductID to #TerritoryWork, interpret defaults for territorylist & copc list
3/11/2011  SK	Missing YTD calculation fixed (start date needed to reset to Jan 1)
11/01/2011 JPB	Added NAM_ID, REGION_ID, BILLING_PROJECT_ID to #TerritoryWork table.
11/01/2011 JPB	... Also Added NAM_USER_NAME, REGION_DESC, BILLING_PROJECT_NAME, TERRITORY_USER_NAME, TERRITORY_DESC
03/21/2014 JDB	Fixed the JOIN between #YTDSum and #MonSum to account for the NULL values that will be present for customers that don't have a NAM or Region.
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75
06/16/2023 Devops 65744--Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
-- all territories:  00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 41, 51


-- OLD:
		EXECUTE dbo.sp_rpt_territory_ytd_sum
		  @date_from = '1-1-2011',
		  @date_to = '1-31-2011',
		  @territory_list = 'ALL',
		  @copc_list='ALL',
		  @debug = 0
		  
-- NEW:
	sp_rpt_territory_ytd_sum 
		@date_from= '1-1-2011' 
	,	@date_to = '1-31-2011'
	,	@copc_list='ALL'
	,	@filter_field = 'territory_code'
	,	@filter_list = 'ALL'
	,	@debug = 0	  


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
	@filter_value		varchar(8)

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

IF @debug = 1 print 'SELECT * FROM #tmp_copc '
IF @debug = 1 SELECT * FROM #tmp_copc
	
-- Dates	
IF @debug = 1 print 'dates: ' + convert(varchar(30), @date_from) + ' to ' + convert(varchar(30), @date_to) 

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

CREATE TABLE #YTDSum (
	field_value	varchar(8)	null,
	field_description varchar(100) null,
	job_type	char(1)		null,
	category	int			null,
	jan_rev		float		null,
	feb_rev		float		null,
	mar_rev		float		null,
	apr_rev		float		null,
	may_rev		float		null,
	jun_rev		float		null,
	jul_rev		float		null,
	aug_rev		float		null,
	sep_rev		float		null,
	oct_rev		float		null,
	nov_rev		float		null,
	dec_rev		float		null,
	ytd_rev		float		null,
	company		int			null,
	dist_company int		null
		)
-- Reset the start date to the current year to compute YTD calc
SET @date_from = '01-01-' + CONVERT(varchar(4), Year(@date_from))

--	The sp_rpt_territory_calc_ai relies on the existence of #TerritoryWork, #tmp_copc and #tmp_territory
EXEC sp_rpt_territory_calc_ai @date_from, @date_to, @filter_field, @filter_list, @debug

-- Need to delete not commissionable ?
DELETE FROM #TerritoryWork where commissionable_flag = 'F'

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


-- Compute and insert YTD total
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
	job_type ,
	category,
	jan_rev = 0.00,
	feb_rev = 0.00,
	mar_rev = 0.00,
	apr_rev = 0.00,
	may_rev = 0.00,
	jun_rev = 0.00,
	jul_rev = 0.00,
	aug_rev = 0.00,
	sep_rev = 0.00,
	oct_rev = 0.00,
	nov_rev = 0.00,
	dec_rev = 0.00,
	ytd_rev = SUM(IsNull(extended_amt, 0.00)),
	--ytd_rev = SUM(ROUND((billing_price) * ((100 - discount_percent) / 100), 2)),
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
	job_type, category, company_id, dist_company_id
IF @debug = 1 
BEGIN
	PRINT 'SELECT * FROM #YTDSum after inserting YTD_rev only'
	SELECT * FROM #YTDSum
END

-- Create Index for easy updates
CREATE INDEX ix_YTDSum ON #YTDSum ( field_value, job_type, category, company ) 

-- SET JAN_REV
UPDATE #YTDSum 
--SET jan_rev = (SELECT SUM(ROUND((billing_price) * ((100 - discount_percent) / 100), 2)) FROM #TerritoryWork m
SET jan_rev = (SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork m
				WHERE m.company_id = y.company
				AND m.dist_company_id = y.dist_company
				AND ISNULL(convert(varchar(8), 
						CASE @filter_field
							WHEN '' then NULL
							WHEN 'NAM_ID' THEN nam_id
							WHEN 'REGION_ID' THEN region_id
							WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
							WHEN 'TERRITORY_CODE' THEN territory_code
						END
					), '-9999') = ISNULL(y.field_value, '-9999')
				AND m.job_type = y.job_type
				AND m.category = y.category
				AND m.month = 1)
FROM #YTDSum Y

-- SET FEB_REV
UPDATE #YTDSum 
SET feb_rev = (SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork m
				WHERE m.company_id = y.company
				AND m.dist_company_id = y.dist_company
				AND ISNULL(convert(varchar(8), 
						CASE @filter_field
							WHEN '' then NULL
							WHEN 'NAM_ID' THEN nam_id
							WHEN 'REGION_ID' THEN region_id
							WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
							WHEN 'TERRITORY_CODE' THEN territory_code
						END
					), '-9999') = ISNULL(y.field_value, '-9999')
				AND m.job_type = y.job_type
				AND m.category = y.category
				AND m.month = 2)
FROM #YTDSum Y

-- SET MAR_REV
UPDATE #YTDSum 
SET mar_rev = (SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork m
				WHERE m.company_id = y.company
				AND m.dist_company_id = y.dist_company
				AND ISNULL(convert(varchar(8), 
						CASE @filter_field
							WHEN '' then NULL
							WHEN 'NAM_ID' THEN nam_id
							WHEN 'REGION_ID' THEN region_id
							WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
							WHEN 'TERRITORY_CODE' THEN territory_code
						END
					), '-9999') = ISNULL(y.field_value, '-9999')
				AND m.job_type = y.job_type
				AND m.category = y.category
				AND m.month = 3)
FROM #YTDSum Y

-- SET APR_REV
UPDATE #YTDSum 
SET apr_rev = (SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork m
				WHERE m.company_id = y.company
				AND m.dist_company_id = y.dist_company
				AND ISNULL(convert(varchar(8), 
						CASE @filter_field
							WHEN '' then NULL
							WHEN 'NAM_ID' THEN nam_id
							WHEN 'REGION_ID' THEN region_id
							WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
							WHEN 'TERRITORY_CODE' THEN territory_code
						END
					), '-9999') = ISNULL(y.field_value, '-9999')
				AND m.job_type = y.job_type
				AND m.category = y.category
				AND m.month = 4)
FROM #YTDSum Y

-- SET MAY_REV
UPDATE #YTDSum 
SET may_rev = (SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork m
				WHERE m.company_id = y.company
				AND m.dist_company_id = y.dist_company
				AND ISNULL(convert(varchar(8), 
						CASE @filter_field
							WHEN '' then NULL
							WHEN 'NAM_ID' THEN nam_id
							WHEN 'REGION_ID' THEN region_id
							WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
							WHEN 'TERRITORY_CODE' THEN territory_code
						END
					), '-9999') = ISNULL(y.field_value, '-9999')
				AND m.job_type = y.job_type
				AND m.category = y.category
				AND m.month = 5)
FROM #YTDSum Y

-- SET JUN_REV
UPDATE #YTDSum 
SET jun_rev = (SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork m
				WHERE m.company_id = y.company
				AND m.dist_company_id = y.dist_company
				AND ISNULL(convert(varchar(8), 
						CASE @filter_field
							WHEN '' then NULL
							WHEN 'NAM_ID' THEN nam_id
							WHEN 'REGION_ID' THEN region_id
							WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
							WHEN 'TERRITORY_CODE' THEN territory_code
						END
					), '-9999') = ISNULL(y.field_value, '-9999')
				AND m.job_type = y.job_type
				AND m.category = y.category
				AND m.month = 6)
FROM #YTDSum Y

-- SET JUL_REV
UPDATE #YTDSum 
SET jul_rev = (SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork m
				WHERE m.company_id = y.company
				AND m.dist_company_id = y.dist_company
				AND ISNULL(convert(varchar(8), 
						CASE @filter_field
							WHEN '' then NULL
							WHEN 'NAM_ID' THEN nam_id
							WHEN 'REGION_ID' THEN region_id
							WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
							WHEN 'TERRITORY_CODE' THEN territory_code
						END
					), '-9999') = ISNULL(y.field_value, '-9999')
				AND m.job_type = y.job_type
				AND m.category = y.category
				AND m.month = 7)
FROM #YTDSum Y

-- SET AUG_REV
UPDATE #YTDSum 
SET aug_rev = (SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork m
				WHERE m.company_id = y.company
				AND m.dist_company_id = y.dist_company
				AND ISNULL(convert(varchar(8), 
						CASE @filter_field
							WHEN '' then NULL
							WHEN 'NAM_ID' THEN nam_id
							WHEN 'REGION_ID' THEN region_id
							WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
							WHEN 'TERRITORY_CODE' THEN territory_code
						END
					), '-9999') = ISNULL(y.field_value, '-9999')
				AND m.job_type = y.job_type
				AND m.category = y.category
				AND m.month = 8)
FROM #YTDSum Y

-- SET SEP_REV
UPDATE #YTDSum 
SET sep_rev = (SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork m
				WHERE m.company_id = y.company
				AND m.dist_company_id = y.dist_company
				AND ISNULL(convert(varchar(8), 
						CASE @filter_field
							WHEN '' then NULL
							WHEN 'NAM_ID' THEN nam_id
							WHEN 'REGION_ID' THEN region_id
							WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
							WHEN 'TERRITORY_CODE' THEN territory_code
						END
					), '-9999') = ISNULL(y.field_value, '-9999')
				AND m.job_type = y.job_type
				AND m.category = y.category
				AND m.month = 9)
FROM #YTDSum Y

-- SET OCT_REV
UPDATE #YTDSum 
SET oct_rev = (SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork m
				WHERE m.company_id = y.company
				AND m.dist_company_id = y.dist_company
				AND ISNULL(convert(varchar(8), 
						CASE @filter_field
							WHEN '' then NULL
							WHEN 'NAM_ID' THEN nam_id
							WHEN 'REGION_ID' THEN region_id
							WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
							WHEN 'TERRITORY_CODE' THEN territory_code
						END
					), '-9999') = ISNULL(y.field_value, '-9999')
				AND m.job_type = y.job_type
				AND m.category = y.category
				AND m.month = 10)
FROM #YTDSum Y

-- SET NOV_REV
UPDATE #YTDSum 
SET nov_rev = (SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork m
				WHERE m.company_id = y.company
				AND m.dist_company_id = y.dist_company
				AND ISNULL(convert(varchar(8), 
						CASE @filter_field
							WHEN '' then NULL
							WHEN 'NAM_ID' THEN nam_id
							WHEN 'REGION_ID' THEN region_id
							WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
							WHEN 'TERRITORY_CODE' THEN territory_code
						END
					), '-9999') = ISNULL(y.field_value, '-9999')
				AND m.job_type = y.job_type
				AND m.category = y.category
				AND m.month = 11)
FROM #YTDSum Y

-- SET DEC_REV
UPDATE #YTDSum 
SET dec_rev = (SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork m
				WHERE m.company_id = y.company
				AND m.dist_company_id = y.dist_company
				AND ISNULL(convert(varchar(8), 
						CASE @filter_field
							WHEN '' then NULL
							WHEN 'NAM_ID' THEN nam_id
							WHEN 'REGION_ID' THEN region_id
							WHEN 'BILLING_PROJECT_ID' THEN billing_project_id
							WHEN 'TERRITORY_CODE' THEN territory_code
						END
					), '-9999') = ISNULL(y.field_value, '-9999')
				AND m.job_type = y.job_type
				AND m.category = y.category
				AND m.month = 12)
FROM #YTDSum Y

IF @debug = 1 
BEGIN
	PRINT 'SELECT * FROM #YTDSum after updating monthly totals'
	SELECT * FROM #YTDSum
END

-- Insert into #tmp
SELECT DISTINCT
	field_value,
	field_description,
	job_type,
	category,
	ISNULL(jan_rev, 0.00) AS jan_rev,
	ISNULL(feb_rev, 0.00) AS feb_rev,
	ISNULL(mar_rev, 0.00) AS mar_rev,
	ISNULL(apr_rev, 0.00) AS apr_rev,
	ISNULL(may_rev, 0.00) AS may_rev,
	ISNULL(jun_rev, 0.00) AS jun_rev,
	ISNULL(jul_rev, 0.00) AS jul_rev,
	ISNULL(aug_rev, 0.00) AS aug_rev,
	ISNULL(sep_rev, 0.00) AS sep_rev,
	ISNULL(oct_rev, 0.00) AS oct_rev,
	ISNULL(nov_rev, 0.00) AS nov_rev,
	ISNULL(dec_rev, 0.00) AS dec_rev,
	ISNULL(ytd_rev, 0.00) AS ytd_rev,
	company,
	dist_company
INTO #tmp
FROM #YTDSum
ORDER BY field_value, job_type, category, company

CREATE TABLE #Output (
	record_type	int			NULL,
	field_value	varchar(8)	NULL,
	field_description varchar(100) NULL,
	job_type	char(1)		NULL,
	category	int			NULL,
	jan_rev		float		NULL,
	feb_rev		float		NULL,
	mar_rev		float		NULL,
	apr_rev		float		NULL,
	may_rev		float		NULL,
	jun_rev		float		NULL,
	jul_rev		float		NULL,
	aug_rev		float		NULL,
	sep_rev		float		NULL,
	oct_rev		float		NULL,
	nov_rev		float		NULL,
	dec_rev		float		NULL,
	ytd_rev		float		NULL,
	company		int			NULL,
	dist_company	int		NULL) 

INSERT INTO #Output SELECT 1, * FROM #tmp
IF @debug = 1 
BEGIN
	PRINT 'SELECT * FROM #Output totals by company(recordtype=1)'
	SELECT * FROM #Output
END

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

	UPDATE #tmp_filter_values SET process_flag = 0
	/************************************************************/
	-- Process each field_value in the list
	SELECT @filter_item_count = COUNT(*) FROM #tmp_filter_values
	WHILE @filter_item_count > 0
	BEGIN
		-- Get the field_value
		SET ROWCOUNT 1
		SELECT @filter_value = filter_field FROM #tmp_filter_values WHERE process_flag = 0
		SET ROWCOUNT 0

		-- Subtotals get record_type = 2
		INSERT INTO #Output
		SELECT	2,
			field_value,
			field_description,
			job_type,
			category,
			SUM(jan_rev),
			SUM(feb_rev),
			SUM(mar_rev),
			SUM(apr_rev),
			SUM(may_rev),
			SUM(jun_rev),
			SUM(jul_rev),
			SUM(aug_rev),
			SUM(sep_rev),
			SUM(oct_rev),
			SUM(nov_rev),
			SUM(dec_rev),
			SUM(ytd_rev),
			99,
			dist_company
		FROM #tmp
		WHERE job_type = @job_type AND category = @category AND convert(int, field_value) = convert(int, @filter_value)
		GROUP BY dist_company, field_value, field_description, job_type, category

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
	
-- Set category to 99 so that Unassigned sorts to the bottom.
UPDATE #Output SET category = 99 WHERE category = 0

-- SELECT Results
SELECT record_type,
	@filter_field as filter_field,
	ISNULL(field_value, '{Unassigned)') AS field_value,
	ISNULL(field_description, '{Unassigned)') AS field_description,
	job_type,
	category,
	jan_rev,
	feb_rev,
	mar_rev,
	apr_rev,
	may_rev,
	jun_rev,
	jul_rev,
	aug_rev,
	sep_rev,
	oct_rev,
	nov_rev,
	dec_rev,
	ytd_rev,
	company,
	dist_company
FROM #Output 
ORDER BY ISNULL(field_value, '{Unassigned)'), company, job_type, category

DROP TABLE #Output
DROP TABLE #tmp
DROP TABLE #tmp_category
DROP TABLE #tmp_filter_values
DROP TABLE #TerritoryWork
DROP TABLE #YTDSum


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_ytd_sum] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_ytd_sum] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_ytd_sum] TO [EQAI]
    AS [dbo];

