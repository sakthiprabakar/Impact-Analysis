
CREATE PROCEDURE sp_rpt_territory_commission 
	@date_from			datetime
,	@date_to			datetime
,	@report_type		int
,	@user_id			varchar(8)
,	@filter_field	varchar(20)		-- one of: 'NAM_ID', 'REGION_ID', 'BILLING_PROJECT_ID', 'TERRITORY_CODE', '' ('' = No filter)
,	@filter_list	varchar(max)
,	@debug				int
AS
--------------------------------------------------------------------------------------------------------------------
/* Territory Commission Report Assumptions:
      -  the per load budle charges are left with the disposal because we can't keep the 
         disposal as a quantity price relationship
      -  use the current quote trans prices or else they cannot be corrected 
Modifications:
01/13/2000 LJT Modified to add Territory specifications for 2000
01/28/2000 LJT Added the originating company field
09/28/2000 LJT Changed = NULL to is NULL and <> null to is not null
09/18/2003 JDB	Added report type to call a specific report:
		1 - Commission Report (Actual Revenue)
		2 - AE Commission Report
		3 - ISA Commission Report
		Added tables for the commission values
		Added intercompanyapprovals as a view on PLT_AI, PLT_AI_TEST, PLT_AI_DEV
10/07/2003 LJT	Added Bulk_flag
12/30/2004 SCC	Changed ticket_id to line_id
11/08/2005 SCC	Added IsNull to preclude NULL values being eliminated from aggregate - caused commission reports to fail
02/15/2011 SK	Moved from PLT_XX_AI to PLT_AI
				is no longer called from sp_territory_commission_master report, since this sp itself is now on Plt_AI
				changed the calculation query to use the sp_rpt_territory_calc_ai
				added BillingDetail joins
03/08/2011 SK	Changed the TerritoryWork layout, used extended_amt
3/10/2011  SK	Appended ProductID to #TerritoryWork, interpret defaults for territory list
11/01/2011 JPB	Added NAM_ID, REGION_ID, BILLING_PROJECT_ID to #TerritoryWork table.
11/01/2011 JPB	... Also Added NAM_USER_NAME, REGION_DESC, BILLING_PROJECT_NAME, TERRITORY_USER_NAME, TERRITORY_DESC
03/29/2012	JPB	Commented out deleting of commissionable_flag = 'F' records, and added dummy records for each co/pc/terr.
04/11/2014	AM - Modified #Output temp table to remove company since we use only dist_company_id to commission reports. 
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75

-- OLD:
	EXECUTE dbo.sp_rpt_territory_commission
	  @date_from = '01-01-2011',
	  @date_to = '01-31-2011',
	  @territory_list = 'ALL',
	  @report_type = 1,
	  @user_id = 'SMITA_K',
	  @debug = 1

-- NEW:
	EXEC sp_rpt_territory_commission 
	  @date_from = '01-01-2011',
	  @date_to = '01-31-2011',
	  @report_type = 1,
	  @user_id = 'SMITA_K',
	  @filter_field	= 'TERRITORY_CODE', -- varchar(20)		-- one of: 'NAM_ID', 'REGION_ID', 'BILLING_PROJECT_ID', 'TERRITORY_CODE', '' ('' = No filter)
	  @filter_list = 'UN, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 51, 71, 76',
	  @debug = 0

	  
	  -- @territory_list = 'UN, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 51, 71, 76',

*/
--------------------------------------------------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@execute_sql	varchar(1000),
	@b_rate_0		decimal(6,5),
	@b_rate_1		decimal(6,5),
	@b_rate_2		decimal(6,5),
	@b_rate_3		decimal(6,5),
	@b_rate_4		decimal(6,5),
	@b_rate_5		decimal(6,5),
	@e_rate_0		decimal(6,5),
	@e_rate_1		decimal(6,5),
	@e_rate_2		decimal(6,5),
	@e_rate_3		decimal(6,5),
	@e_rate_4		decimal(6,5),
	@e_rate_5		decimal(6,5),
	@company_id		smallint,
	@db_count		int,
	@unassigned_territory varchar(8) 

CREATE TABLE #Output (
	record_type		int			NULL,
	--company			int			NULL,
	territory		varchar(8)	NULL,
	dist_company	int			NULL,
	ae_name			varchar(30)	NULL,
	isa_name		varchar(30)	NULL,
	goal			float		NULL,
	month			int			NULL,
	year			int			NULL,
	base0			float		NULL,
	base1			float		NULL,
	base2			float		NULL,
	base3			float		NULL,
	base4			float 		NULL,
	base5			float		NULL,
	event0			float		NULL,
	event1			float		NULL,
	event2			float		NULL,
	event3			float		NULL,
	event4			float		NULL,
	event5			float		NULL )

CREATE TABLE #tmp_company (
	company_id		int	NULL,
	process_flag	int	NULL	)

-- create #TerritoryWork
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

-- Create temp territory commision tables
CREATE TABLE #TerritoryCommBase (
	company			int			NULL,
	territory		varchar(8)	NULL,
	dist_company	int			NULL,
	month			int			NULL,
	year			int			NULL,
	job_type		char(1)		NULL,
	category		int			NULL,
	rev				float		NULL ) 
	
CREATE TABLE #TerritoryCommBase2 (
	company			int			NULL,
	territory		varchar(8)	NULL,
	dist_company	int			NULL,
	month			int			NULL,
	year			int			NULL,
	job_type		char(1)		NULL,
	category		int			NULL,
	b0rev			float		NULL,
	b1rev			float		NULL,
	b2rev			float		NULL,
	b3rev			float		NULL,
	b4rev			float 		NULL,
	b5rev			float		NULL,
	e0rev			float		NULL,
	e1rev			float		NULL,
	e2rev			float		NULL,
	e3rev			float		NULL,
	e4rev			float		NULL,
	e5rev			float		NULL ) 
	
CREATE TABLE #TerritoryCommBase3 (
	company			int			NULL,
	territory		varchar(8)	NULL,
	dist_company	int			NULL,
	month			int			NULL,
	year			int			NULL,
	jbtyp			char(1)		NULL,
	ctgry			int			NULL,
	rev			float		NULL
) 

-- create #tmp_copc with all active companies/profitcenters
CREATE TABLE #tmp_copc ([company_id] int, profit_ctr_id int)
INSERT #tmp_copc
SELECT
	ProfitCenter.company_ID
,	ProfitCenter.profit_ctr_ID
FROM ProfitCenter
WHERE status = 'A'
IF @debug = 1 print 'SELECT * FROM #tmp_copc'
IF @debug = 1 SELECT * FROM #tmp_copc

/*
-- create #tmp_territory	
CREATE TABLE #tmp_territory ( territory_code varchar(8) NULL)
IF @territory_list = 'ALL'
	INSERT INTO #tmp_territory SELECT territory_code FROM Territory UNION SELECT 'UN'
ELSE
	EXEC sp_list @debug, @territory_list, 'STRING', '#tmp_territory'
*/



	
-- Delete any prev results for this user
DELETE FROM TerritoryCommissionReport WHERE user_id = @user_id

--The sp_rpt_territory_calc_ai relies on the existence of #TerritoryWork, #tmp_copc and #tmp_territory 
EXEC sp_rpt_territory_calc_ai @date_from, @date_to, @filter_field, @filter_list, @debug


-- Insert dummy records for #TerritoryWork so there's a line for every co/pc/territory in the report output
	select distinct territory_code into #Terr from #TerritoryWork
	select distinct company_id, profit_ctr_id into #CoPC2 from #TerritoryWork
	select distinct year, month into #tYear from #TerritoryWork
	select distinct company_id, profit_ctr_id, territory_code into #limiter from #TerritoryWork

	-- Create at least 1 empty slug per co/pc + territory, if none exists yet,
	-- so the report as an entry for every possibility.
	insert #TerritoryWork 
		(company_id, territory_code, dist_company_id, year, month, extended_amt, job_type, category)
	select distinct
		t1.company_id, t2.territory_code, t1.company_id, t3.year, t3.month, 0, 'B', 0
	from
		#CoPC2 t1, #Terr t2, #tYear t3
	where not exists (
		select 1 from #limiter l
		where l.company_id = t1.company_id
		and l.territory_code = t2.territory_code
	)

	insert #TerritoryWork 
		(company_id, territory_code, dist_company_id, year, month, extended_amt, job_type, category)
	select distinct
		93, t2.territory_code, 93, t3.year, t3.month, 0, 'B', 0
	from
		#CoPC2 t1, #Terr t2, #tYear t3
	where 
		t1.company_id = 3
	and not exists (
		select 1 from #limiter l
		where l.company_id = 93
		and l.territory_code = t2.territory_code
	)
	


IF @debug = 1 
BEGIN
	print 'Total extended amt:'
	Select SUM(IsNull(extended_amt, 0.00)) FROM #TerritoryWork
END
 
/*
-- temp measure to get numbers to balance out, required ?
DELETE FROM #TerritoryWork where commissionable_flag = 'F'
IF @debug = 1 
BEGIN
	print 'Total extended amt(after deleting commissionable F):'
	Select SUM(IsNull(extended_amt, 0.00)) FROM #TerritoryWork
END 
*/

IF @debug = 1 PRINT 'INSERT INTO #TerritoryCommBase 1'
INSERT INTO #TerritoryCommBase
SELECT DISTINCT
	company_id,
	territory_code,
	dist_company_id,
	month,
	year,
	job_type,
	category,
	--price = SUM(ROUND((IsNull(quantity,0) * IsNull(billing_price,0)) * ((100 - IsNull(discount_percent,0)) / 100), 2)),
	SUM(ISNULL(extended_amt, 0.00)) AS rev
FROM #TerritoryWork
GROUP BY territory_code, company_id, dist_company_id, year, month, job_type, category
IF @debug = 1 SELECT * FROM #TerritoryCommBase

IF @debug = 1 PRINT 'INSERT INTO #TerritoryCommBase2 1'
INSERT INTO #TerritoryCommBase2
SELECT	DISTINCT
	company = t.company,
	territory = t.territory,
	dist_company = t.dist_company,
	month = t.month,
	year = t.year,
	job_type = t.job_type,
	category = t.category,
	b0rev = 0,
	b1rev = 0,
	b2rev = 0,
	b3rev = 0,
	b4rev = 0,
	b5rev = 0,
	e0rev = 0,
	e1rev = 0,
	e2rev = 0,
	e3rev = 0,
	e4rev = 0,
	e5rev = 0
FROM #TerritoryCommBase t
GROUP BY t.territory, t.company, t.dist_company, t.year, t.month, t.job_type, t.category
IF @debug = 1 SELECT * FROM #TerritoryCommBase2

IF @debug = 1 print 'INSERT INTO #TerritoryCommBase3 1'
INSERT INTO #TerritoryCommBase3
SELECT	DISTINCT
	company = company,
	territory = territory, 
	dist_company = dist_company, 
	month = month, 
	year = year, 
	jbtyp = job_type, 
	ctgry = category,
	rev = SUM(rev)
FROM #TerritoryCommBase
GROUP BY territory, company, dist_company, year, month, job_type, category
IF @debug = 1 SELECT * FROM #TerritoryCommBase3

IF @debug = 1 PRINT 'Update #TerritoryCommBase2 1 b0'
UPDATE #TerritoryCommBase2
SET	b0rev = t3.rev
FROM 	#TerritoryCommBase3 t3
WHERE	#TerritoryCommBase2.territory = t3.territory
	AND #TerritoryCommBase2.company = t3.company
	AND #TerritoryCommBase2.dist_company = t3.dist_company
	AND #TerritoryCommBase2.month = t3.month
	AND #TerritoryCommBase2.year = t3.year
	AND job_type = t3.jbtyp
	AND category = t3.ctgry
	AND t3.jbtyp = 'B'
	AND t3.ctgry = 0
IF @debug = 1 SELECT * FROM #TerritoryCommBase2

IF @debug = 1 PRINT 'Update #TerritoryCommBase2 2 b1'
UPDATE #TerritoryCommBase2
SET	b1rev = t3.rev
FROM 	#TerritoryCommBase3 t3
WHERE	#TerritoryCommBase2.territory = t3.territory
	AND #TerritoryCommBase2.company = t3.company
	AND #TerritoryCommBase2.dist_company = t3.dist_company
	AND #TerritoryCommBase2.month = t3.month
	AND #TerritoryCommBase2.year = t3.year
	AND job_type = t3.jbtyp
	AND category = t3.ctgry
	AND t3.jbtyp = 'B'
	AND t3.ctgry = 1
IF @debug = 1 SELECT * FROM #TerritoryCommBase2

IF @debug = 1 PRINT 'Update #TerritoryCommBase2 3 b2'
UPDATE #TerritoryCommBase2
SET	b2rev = t3.rev
FROM 	#TerritoryCommBase3 t3
WHERE	#TerritoryCommBase2.territory = t3.territory
	AND #TerritoryCommBase2.company = t3.company
	AND #TerritoryCommBase2.dist_company = t3.dist_company
	AND #TerritoryCommBase2.month = t3.month
	AND #TerritoryCommBase2.year = t3.year
	AND job_type = t3.jbtyp
	AND category = t3.ctgry
	AND t3.jbtyp = 'B'
	AND t3.ctgry = 2
IF @debug = 1 SELECT * FROM #TerritoryCommBase2

IF @debug = 1 PRINT 'Update #TerritoryCommBase2 4 b3'
UPDATE #TerritoryCommBase2
SET	b3rev = t3.rev
FROM 	#TerritoryCommBase3 t3
WHERE	#TerritoryCommBase2.territory = t3.territory
	AND #TerritoryCommBase2.company = t3.company
	AND #TerritoryCommBase2.dist_company = t3.dist_company
	AND #TerritoryCommBase2.month = t3.month
	AND #TerritoryCommBase2.year = t3.year
	AND job_type = t3.jbtyp
	AND category = t3.ctgry
	AND t3.jbtyp = 'B'
	AND t3.ctgry = 3
IF @debug = 1 SELECT * FROM #TerritoryCommBase2

IF @debug = 1 PRINT 'Update #TerritoryCommBase2 5 b4'
UPDATE #TerritoryCommBase2
SET	b4rev = t3.rev
FROM 	#TerritoryCommBase3 t3
WHERE	#TerritoryCommBase2.territory = t3.territory
	AND #TerritoryCommBase2.company = t3.company
	AND #TerritoryCommBase2.dist_company = t3.dist_company
	AND #TerritoryCommBase2.month = t3.month
	AND #TerritoryCommBase2.year = t3.year
	AND job_type = t3.jbtyp
	AND category = t3.ctgry
	AND t3.jbtyp = 'B'
	AND t3.ctgry = 4
IF @debug = 1 SELECT * FROM #TerritoryCommBase2

IF @debug = 1 PRINT 'Update #TerritoryCommBase2 6 b5'
UPDATE #TerritoryCommBase2
SET	b5rev = t3.rev
FROM 	#TerritoryCommBase3 t3
WHERE	#TerritoryCommBase2.territory = t3.territory
	AND #TerritoryCommBase2.company = t3.company
	AND #TerritoryCommBase2.dist_company = t3.dist_company
	AND #TerritoryCommBase2.month = t3.month
	AND #TerritoryCommBase2.year = t3.year
	AND job_type = t3.jbtyp
	AND category = t3.ctgry
	AND t3.jbtyp = 'B'
	AND t3.ctgry = 5
IF @debug = 1 SELECT * FROM #TerritoryCommBase2

IF @debug = 1 PRINT 'Update #TerritoryCommBase2 7 e0'
UPDATE #TerritoryCommBase2
SET	e0rev = t3.rev
FROM 	#TerritoryCommBase3 t3
WHERE	#TerritoryCommBase2.territory = t3.territory
	AND #TerritoryCommBase2.company = t3.company
	AND #TerritoryCommBase2.dist_company = t3.dist_company
	AND #TerritoryCommBase2.month = t3.month
	AND #TerritoryCommBase2.year = t3.year
	AND job_type = t3.jbtyp
	AND category = t3.ctgry
	AND t3.jbtyp = 'E'
	AND t3.ctgry = 0
IF @debug = 1 SELECT * FROM #TerritoryCommBase2

IF @debug = 1 PRINT 'Update #TerritoryCommBase2 8 e1'
UPDATE #TerritoryCommBase2
SET	e1rev = t3.rev
FROM 	#TerritoryCommBase3 t3
WHERE	#TerritoryCommBase2.territory = t3.territory
	AND #TerritoryCommBase2.company = t3.company
	AND #TerritoryCommBase2.dist_company = t3.dist_company
	AND #TerritoryCommBase2.month = t3.month
	AND #TerritoryCommBase2.year = t3.year
	AND job_type = t3.jbtyp
	AND category = t3.ctgry
	AND t3.jbtyp = 'E'
	AND t3.ctgry = 1
IF @debug = 1 SELECT * FROM #TerritoryCommBase2

IF @debug = 1 PRINT 'Update #TerritoryCommBase2 9 e2'
UPDATE #TerritoryCommBase2
SET	e2rev = t3.rev
FROM 	#TerritoryCommBase3 t3
WHERE	#TerritoryCommBase2.territory = t3.territory
	AND #TerritoryCommBase2.company = t3.company
	AND #TerritoryCommBase2.dist_company = t3.dist_company
	AND #TerritoryCommBase2.month = t3.month
	AND #TerritoryCommBase2.year = t3.year
	AND job_type = t3.jbtyp
	AND category = t3.ctgry
	AND t3.jbtyp = 'E'
	AND t3.ctgry = 2
IF @debug = 1 SELECT * FROM #TerritoryCommBase2

IF @debug = 1 PRINT 'Update #TerritoryCommBase2 10 e3'
UPDATE #TerritoryCommBase2
SET	e3rev = t3.rev
FROM 	#TerritoryCommBase3 t3
WHERE	#TerritoryCommBase2.territory = t3.territory
	AND #TerritoryCommBase2.company = t3.company
	AND #TerritoryCommBase2.dist_company = t3.dist_company
	AND #TerritoryCommBase2.month = t3.month
	AND #TerritoryCommBase2.year = t3.year
	AND job_type = t3.jbtyp
	AND category = t3.ctgry
	AND t3.jbtyp = 'E'
	AND t3.ctgry = 3
IF @debug = 1 SELECT * FROM #TerritoryCommBase2

IF @debug = 1 PRINT 'Update #TerritoryCommBase2 11 e4'
UPDATE #TerritoryCommBase2
SET	e4rev = t3.rev
FROM 	#TerritoryCommBase3 t3
WHERE	#TerritoryCommBase2.territory = t3.territory
	AND #TerritoryCommBase2.company = t3.company
	AND #TerritoryCommBase2.dist_company = t3.dist_company
	AND #TerritoryCommBase2.month = t3.month
	AND #TerritoryCommBase2.year = t3.year
	AND job_type = t3.jbtyp
	AND category = t3.ctgry
	AND t3.jbtyp = 'E'
	AND t3.ctgry = 4
IF @debug = 1 SELECT * FROM #TerritoryCommBase2

IF @debug = 1 PRINT 'Update #TerritoryCommBase2 12 e5'
UPDATE #TerritoryCommBase2
SET	e5rev = t3.rev
FROM 	#TerritoryCommBase3 t3
WHERE	#TerritoryCommBase2.territory = t3.territory
	AND #TerritoryCommBase2.company = t3.company
	AND #TerritoryCommBase2.dist_company = t3.dist_company
	AND #TerritoryCommBase2.month = t3.month
	AND #TerritoryCommBase2.year = t3.year
	AND job_type = t3.jbtyp
	AND category = t3.ctgry
	AND t3.jbtyp = 'E'
	AND t3.ctgry = 5
IF @debug = 1 SELECT * FROM #TerritoryCommBase2

-- Calc AE commision
IF @report_type = 2
BEGIN
	IF @debug = 1 PRINT 'Update #TerritoryCommBase2 - report type is 2 AE Commision'
	SELECT @b_rate_0 = rate FROM Commission WHERE position = 'AE' AND job_type = 'B' AND category = 0
	SELECT @b_rate_1 = rate FROM Commission WHERE position = 'AE' AND job_type = 'B' AND category = 1
	SELECT @b_rate_2 = rate FROM Commission WHERE position = 'AE' AND job_type = 'B' AND category = 2
	SELECT @b_rate_3 = rate FROM Commission WHERE position = 'AE' AND job_type = 'B' AND category = 3
	SELECT @b_rate_4 = rate FROM Commission WHERE position = 'AE' AND job_type = 'B' AND category = 4
	SELECT @b_rate_5 = rate FROM Commission WHERE position = 'AE' AND job_type = 'B' AND category = 5
	SELECT @e_rate_0 = rate FROM Commission WHERE position = 'AE' AND job_type = 'E' AND category = 0
	SELECT @e_rate_1 = rate FROM Commission WHERE position = 'AE' AND job_type = 'E' AND category = 1
	SELECT @e_rate_2 = rate FROM Commission WHERE position = 'AE' AND job_type = 'E' AND category = 2
	SELECT @e_rate_3 = rate FROM Commission WHERE position = 'AE' AND job_type = 'E' AND category = 3
	SELECT @e_rate_4 = rate FROM Commission WHERE position = 'AE' AND job_type = 'E' AND category = 4
	SELECT @e_rate_5 = rate FROM Commission WHERE position = 'AE' AND job_type = 'E' AND category = 5
	UPDATE #TerritoryCommBase2 SET b0rev = b0rev * @b_rate_0
	UPDATE #TerritoryCommBase2 SET b1rev = b1rev * @b_rate_1
	UPDATE #TerritoryCommBase2 SET b2rev = b2rev * @b_rate_2
	UPDATE #TerritoryCommBase2 SET b3rev = b3rev * @b_rate_3
	UPDATE #TerritoryCommBase2 SET b4rev = b4rev * @b_rate_4
	UPDATE #TerritoryCommBase2 SET b5rev = b5rev * @b_rate_5
	UPDATE #TerritoryCommBase2 SET e0rev = e0rev * @e_rate_0
	UPDATE #TerritoryCommBase2 SET e1rev = e1rev * @e_rate_1
	UPDATE #TerritoryCommBase2 SET e2rev = e2rev * @e_rate_2
	UPDATE #TerritoryCommBase2 SET e3rev = e3rev * @e_rate_3
	UPDATE #TerritoryCommBase2 SET e4rev = e4rev * @e_rate_4
	UPDATE #TerritoryCommBase2 SET e5rev = e5rev * @e_rate_5
	IF @debug = 1 SELECT * FROM #TerritoryCommBase2
END

-- Calc ISA commission
IF @report_type = 3
BEGIN
	IF @debug = 1 PRINT 'Update #TerritoryCommBase2 - report type is 3 ISA Commision'
	SELECT @b_rate_0 = rate FROM Commission WHERE position = 'ISA' AND job_type = 'B' AND category = 0
	SELECT @b_rate_1 = rate FROM Commission WHERE position = 'ISA' AND job_type = 'B' AND category = 1
	SELECT @b_rate_2 = rate FROM Commission WHERE position = 'ISA' AND job_type = 'B' AND category = 2
	SELECT @b_rate_3 = rate FROM Commission WHERE position = 'ISA' AND job_type = 'B' AND category = 3
	SELECT @b_rate_4 = rate FROM Commission WHERE position = 'ISA' AND job_type = 'B' AND category = 4
	SELECT @b_rate_5 = rate FROM Commission WHERE position = 'ISA' AND job_type = 'B' AND category = 5
	SELECT @e_rate_0 = rate FROM Commission WHERE position = 'ISA' AND job_type = 'E' AND category = 0
	SELECT @e_rate_1 = rate FROM Commission WHERE position = 'ISA' AND job_type = 'E' AND category = 1
	SELECT @e_rate_2 = rate FROM Commission WHERE position = 'ISA' AND job_type = 'E' AND category = 2
	SELECT @e_rate_3 = rate FROM Commission WHERE position = 'ISA' AND job_type = 'E' AND category = 3
	SELECT @e_rate_4 = rate FROM Commission WHERE position = 'ISA' AND job_type = 'E' AND category = 4
	SELECT @e_rate_5 = rate FROM Commission WHERE position = 'ISA' AND job_type = 'E' AND category = 5
	UPDATE #TerritoryCommBase2 SET b0rev = b0rev * @b_rate_0
	UPDATE #TerritoryCommBase2 SET b1rev = b1rev * @b_rate_1
	UPDATE #TerritoryCommBase2 SET b2rev = b2rev * @b_rate_2
	UPDATE #TerritoryCommBase2 SET b3rev = b3rev * @b_rate_3
	UPDATE #TerritoryCommBase2 SET b4rev = b4rev * @b_rate_4
	UPDATE #TerritoryCommBase2 SET b5rev = b5rev * @b_rate_5
	UPDATE #TerritoryCommBase2 SET e0rev = e0rev * @e_rate_0
	UPDATE #TerritoryCommBase2 SET e1rev = e1rev * @e_rate_1
	UPDATE #TerritoryCommBase2 SET e2rev = e2rev * @e_rate_2
	UPDATE #TerritoryCommBase2 SET e3rev = e3rev * @e_rate_3
	UPDATE #TerritoryCommBase2 SET e4rev = e4rev * @e_rate_4
	UPDATE #TerritoryCommBase2 SET e5rev = e5rev * @e_rate_5
	IF @debug = 1 SELECT * FROM #TerritoryCommBase2
END

--Insert into TerritoryCommissionReport
SET @execute_sql = 'INSERT INTO TerritoryCommissionReport'
	+ ' SELECT DISTINCT ' 
		+ 'company, '
		+ 'territory, '
		+ 'dist_company, '
		+ 'ae_name = '''', '
		+ 'isa_name = '''', '
		+ 'goal = 0, '
		+ 'month, '
		+ 'year, '
		+ 'base0 = SUM(b0rev), '
		+ 'base1 = SUM(b1rev), '
		+ 'base2 = SUM(b2rev), '
		+ 'base3 = SUM(b3rev), '
		+ 'base4 = SUM(b4rev), '
		+ 'base5 = SUM(b5rev), '
		+ 'event0 = SUM(e0rev), '
		+ 'event1 = SUM(e1rev), '
		+ 'event2 = SUM(e2rev), '
		+ 'event3 = SUM(e3rev), '
		+ 'event4 = SUM(e4rev), '
		+ 'event5 = SUM(e5rev), '
		+ 'user_id = ''' + @user_id + ''' '
	+ 'FROM #TerritoryCommBase2 '
	+ 'GROUP BY territory, company, dist_company, year, month'
IF @debug = 1 PRINT @execute_sql
EXECUTE (@execute_sql)
IF @debug = 1 SELECT * FROM TerritoryCommissionReport WHERE user_id = @user_id

--Build #Output results table
/************************************************************/
INSERT INTO #Output
SELECT	DISTINCT
	1,
	--orig_company,
	territory, 
	company, 
	ae_name,
	isa_name,
	goal,
	month,
	year,
	ISNULL(SUM(base0), 0),
	ISNULL(SUM(base1), 0),
	ISNULL(SUM(base2), 0),
	ISNULL(SUM(base3), 0),
	ISNULL(SUM(base4), 0),
	ISNULL(SUM(base5), 0),
	ISNULL(SUM(event0), 0),
	ISNULL(SUM(event1), 0),
	ISNULL(SUM(event2), 0),
	ISNULL(SUM(event3), 0),
	ISNULL(SUM(event4), 0),
	ISNULL(SUM(event5), 0)
FROM TerritoryCommissionReport
WHERE user_id = @user_id
group by territory, company ,ae_name, isa_name, goal, month, year
UNION 
SELECT DISTINCT
	1,
	-- 0,
	territory = territory_code,
	0,
	ae_name,
	isa_name,
	goal,
	month,
	year,
	0.0, 
	0.0, 
	0.0, 
	0.0, 
	0.0, 
	0.0, 
	0.0,
	0.0, 
	0.0, 
	0.0,
	0.0, 
	0.0 
FROM territory_goals
WHERE	CONVERT(varchar(4), year) + CASE WHEN month < 10 THEN '0' +CONVERT(varchar(1), month) ELSE CONVERT(varchar(2), month) END
	IN (SELECT DISTINCT CONVERT(varchar(4), year) + CASE WHEN month < 10 THEN '0' +CONVERT(varchar(1), month) ELSE CONVERT(varchar(2), month) END
		FROM TerritoryCommissionReport WHERE user_id = @user_id)
--	AND (IsNull(territory_code,'') = @unassigned_territory 
--		 OR territory_code IN (SELECT territory_code FROM #tmp_territory))

ORDER BY territory, company  -- orig_company

/************************************************************/
-- Process each company in the list
INSERT INTO #tmp_company SELECT DISTINCT dist_company, 0 FROM #Output -- company to dist_company
SELECT @db_count = COUNT(*) FROM #tmp_company
WHILE @db_count > 0
BEGIN
	-- Get the company
	SET ROWCOUNT 1
	SELECT @company_id = company_id FROM #tmp_company WHERE process_flag = 0
	SET ROWCOUNT 0

	-- Subtotals get record_type = 2
	INSERT INTO #Output
	SELECT	2, 
		--@company_id, 
		'', 
		@company_id, 
		'', 
		'', 
		0.0, 
		month, 
		year,
		ISNULL(SUM(base0), 0.0),
		ISNULL(SUM(base1), 0.0),
		ISNULL(SUM(base2), 0.0),
		ISNULL(SUM(base3), 0.0),
		ISNULL(SUM(base4), 0.0),
		ISNULL(SUM(base5), 0.0),
		ISNULL(SUM(event0), 0.0),
		ISNULL(SUM(event1), 0.0),
		ISNULL(SUM(event2), 0.0),
		ISNULL(SUM(event3), 0.0),
		ISNULL(SUM(event4), 0.0),
		ISNULL(SUM(event5), 0.0)
	FROM #Output 
	WHERE dist_company = @company_id AND record_type = 1 --company
	GROUP BY year, month

	-- Update to process the next company
	SET ROWCOUNT 1
	UPDATE #tmp_company SET process_flag = 1 WHERE company_id = @company_id AND process_flag = 0
	SET ROWCOUNT 0
	SELECT @db_count = @db_count - 1
END

/************************************************************/
-- Totals get record_type = 3
INSERT INTO #Output
SELECT	3, 
	--0, 
	'', 
	0, 
	'', 
	'', 
	ISNULL(SUM(goal), 0.0), 
	month, 
	year,
	ISNULL(SUM(base0), 0.0), 
	ISNULL(SUM(base1), 0.0), 
	ISNULL(SUM(base2), 0.0), 
	ISNULL(SUM(base3), 0.0), 
	ISNULL(SUM(base4), 0.0), 
	ISNULL(SUM(base5), 0.0),
	ISNULL(SUM(event0), 0.0), 
	ISNULL(SUM(event1), 0.0), 
	ISNULL(SUM(event2), 0.0), 
	ISNULL(SUM(event3), 0.0), 
	ISNULL(SUM(event4), 0.0), 
	ISNULL(SUM(event5), 0.0)
FROM #Output
WHERE record_type = 1
GROUP BY year, month

-- Fetch the ResultSet
SELECT * FROM #Output

DROP TABLE #TerritoryWork
DROP TABLE #TerritoryCommBase
DROP TABLE #TerritoryCommBase2
DROP TABLE #TerritoryCommBase3
DROP TABLE #tmp_company
DROP TABLE #Output

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_commission] TO [EQAI]
    AS [dbo];

