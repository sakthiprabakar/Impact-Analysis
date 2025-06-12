
CREATE PROCEDURE sp_rpt_territory_and_service_category_summary
	@date_from		datetime
,	@date_to		datetime
,	@copc_list		varchar(max)	-- accepts list: '2|21,14|0,22|0'
,	@filter_field	varchar(20)		-- one of: 'NAM_ID', 'REGION_ID', 'BILLING_PROJECT_ID', 'TERRITORY_CODE', '' ('' = No filter)
,	@filter_list	varchar(max)
,	@debug			int
AS
----------------------------------------------------------------------------------------------------------------------
/* 
Created new Summary Report by territory and service category. This pulls all the data from Territory Work Calculation and then
joins to service category to identify the revenue type
Gemini: 

12/15/2014   SK	Created
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)

-- all territories:  00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 41, 51

-- NEW:
	EXECUTE dbo.sp_rpt_territory_and_service_category_summary
	  @date_from = '1-1-2014',
	  @date_to = '1-31-2014',
	  @copc_list='ALL',
	  @filter_field	= 'TERRITORY_CODE',
	  @filter_list = 'UN, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 51, 71, 76',
	  @debug = 1

Select * From #AEServiceCategorySummary
*/
-----------------------------------------------------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- Get the copc list into tmp_copc
CREATE TABLE #tmp_copc ([company_id] int, profit_ctr_id int)
IF @copc_list = 'ALL'
	INSERT #tmp_copc
	SELECT ProfitCenter.company_ID,	ProfitCenter.profit_ctr_ID FROM ProfitCenter WHERE status = 'A'
ELSE
	INSERT #tmp_copc
	SELECT 
		RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) ASEcompany_id,
		RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) ASEprofit_ctr_id
	from dbo.fn_SplitXsvText(',', 0, @copc_list) WHERE isnull(row, '') <> ''
		
IF @debug = 1 print 'SELECT * FROM #tmp_copc'
IF @debug = 1 SELECT * FROM #tmp_copc


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

CREATE TABLE #AEServiceCategorySummary (
	dist_company_id 		int			NULL
,	territory_code			varchar(8)	NULL
,	territory_user_name		varchar(40)	NULL
,	territory_desc			varchar(40)	NULL
,	record_type				char(1)		NULL
,	job_type				char(1)		NULL
,	category				int			NULL
,	total_disposal			float		NULL
,	total_trans				float		NULL
,	total_services			float		NULL
,	total_EIR				float		NULL
,	total_fees				float		NULL
,	total_other				float		NULL
,	total_amount			float		NULL		
)
--	The sp_rpt_territory_calc_ai relies on the existence of #TerritoryWork, #tmp_copc and #tmp_territory
EXEC sp_rpt_territory_calc_ai @date_from, @date_to, @filter_field, @filter_list, @debug

INSERT INTO #AEServiceCategorySummary
-- Get Distinct Result Set
SELECT DISTINCT
	TW.dist_company_id
,	TW.territory_code
,	TW.territory_user_name
,	TW.territory_desc
,	TW.trans_source
,	TW.job_type
,	TW.category
,	0
,	0
,	0
,	0
,	0
,	0
,	0
FROM #TerritoryWork TW
ORDER BY TW.dist_company_id, TW.territory_code, TW.trans_source, TW.job_type, TW.category 

/****Fetch all Disposal totals****/
UPDATE #AEServiceCategorySummary 
SET total_disposal = IsNull((SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork TW
						WHERE TW.dist_company_id = ASE.dist_company_id
						AND TW.territory_code = ASE.territory_code
						AND TW.trans_source = ASE.record_type
						AND TW.job_type = ASE.job_type
						AND TW.category = ASE.category
						AND (TW.category_reason IN (8, 16, 17, 18) 
								OR TW.Product_ID IN (Select P.product_id FROM Product P JOIN ServiceCategory SC 
														ON SC.servicecategory_uid = P.servicecategory_uid
														AND SC.service_category_code = 'D')
							)), 0.0)								
FROM #AEServiceCategorySummary ASE

/****Fetch all Service totals****/
UPDATE #AEServiceCategorySummary 
SET total_services = IsNull((SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork TW
						WHERE TW.dist_company_id = ASE.dist_company_id
						AND TW.territory_code = ASE.territory_code
						AND TW.trans_source = ASE.record_type
						AND TW.job_type = ASE.job_type
						AND TW.category = ASE.category
						AND (TW.category_reason IN (3, 10, 11, 13, 19, 20) 
								OR TW.Product_ID IN (Select P.product_id FROM Product P JOIN ServiceCategory SC 
														ON SC.servicecategory_uid = P.servicecategory_uid
														AND SC.service_category_code = 'S')
							)), 0.0)						
FROM #AEServiceCategorySummary ASE


/****Fetch all Trans totals****/
UPDATE #AEServiceCategorySummary 
SET total_trans = IsNull((SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork TW
						WHERE TW.dist_company_id = ASE.dist_company_id
						AND TW.territory_code = ASE.territory_code
						AND TW.trans_source = ASE.record_type
						AND TW.job_type = ASE.job_type
						AND TW.category = ASE.category
						AND (TW.category_reason IN (14, 15) 
								OR TW.Product_ID IN (Select P.product_id FROM Product P JOIN ServiceCategory SC 
														ON SC.servicecategory_uid = P.servicecategory_uid
														AND SC.service_category_code = 'T')
							)), 0.0)							
FROM #AEServiceCategorySummary ASE

/****Fetch all Taxes, surcharges and Fee totals****/
UPDATE #AEServiceCategorySummary 
SET total_fees = IsNull((SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork TW
						WHERE TW.dist_company_id = ASE.dist_company_id
						AND TW.territory_code = ASE.territory_code
						AND TW.trans_source = ASE.record_type
						AND TW.job_type = ASE.job_type
						AND TW.category = ASE.category
						AND (TW.category_reason IN (5, 12) 
								OR TW.Product_ID IN (Select P.product_id FROM Product P JOIN ServiceCategory SC 
														ON SC.servicecategory_uid = P.servicecategory_uid
														AND SC.service_category_code = 'F')
							)), 0.0)							
FROM #AEServiceCategorySummary ASE

/****Fetch all EIR totals****/
UPDATE #AEServiceCategorySummary 
SET total_EIR = IsNull((SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork TW
						WHERE TW.dist_company_id = ASE.dist_company_id
						AND TW.territory_code = ASE.territory_code
						AND TW.trans_source = ASE.record_type
						AND TW.job_type = ASE.job_type
						AND TW.category = ASE.category
						AND (TW.category_reason IN (1, 2) 
								OR TW.Product_ID IN (Select P.product_id FROM Product P JOIN ServiceCategory SC 
														ON SC.servicecategory_uid = P.servicecategory_uid
														AND SC.service_category_code = 'E')
							)), 0.0)								
FROM #AEServiceCategorySummary ASE

/****Fetch all Other totals****/
UPDATE #AEServiceCategorySummary 
SET total_other = IsNull((SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork TW
						WHERE TW.dist_company_id = ASE.dist_company_id
						AND TW.territory_code = ASE.territory_code
						AND TW.trans_source = ASE.record_type
						AND TW.job_type = ASE.job_type
						AND TW.category = ASE.category
						AND TW.Product_ID IN (Select P.product_id FROM Product P JOIN ServiceCategory SC 
														ON SC.servicecategory_uid = P.servicecategory_uid
														AND SC.service_category_code = 'O')
							), 0.0)					
FROM #AEServiceCategorySummary ASE

-- Update total amount
UPDATE #AEServiceCategorySummary 
SET total_amount = IsNull((SELECT SUM(ISNULL(extended_amt, 0.00)) FROM #TerritoryWork TW
						WHERE TW.dist_company_id = ASE.dist_company_id
						AND TW.territory_code = ASE.territory_code
						AND TW.trans_source = ASE.record_type
						AND TW.job_type = ASE.job_type
						AND TW.category = ASE.category
						), 0.0)
FROM #AEServiceCategorySummary ASE

-- select the resultset
Select * From #AEServiceCategorySummary
order by dist_company_id, territory_code, record_type, job_type, category


IF @debug = 1 
BEGIN
	PRINT 'Total extended amt #TerritoryWork:'
	Select SUM(IsNull(extended_amt, 0.00)) FROM #TerritoryWork
	PRINT 'Total extended amt #AEServiceCategorySummary:'
	Select SUM(IsNull(total_amount, 0.00)) FROM #AEServiceCategorySummary
END 

-- delete temp table
DROP TABLE #TerritoryWork
DROP TABLE #AEServiceCategorySummary

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_and_service_category_summary] TO [EQAI]
    AS [dbo];

