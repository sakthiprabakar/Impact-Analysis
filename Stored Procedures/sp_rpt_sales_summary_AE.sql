﻿drop proc if exists sp_rpt_sales_summary_AE
go

CREATE PROCEDURE [dbo].[sp_rpt_sales_summary_AE]
	@date_from		datetime
,	@date_to		datetime
,	@copc_list		varchar(max)	-- accepts list: '2|21,14|0,22|0'
,	@filter_field	varchar(20)		-- one of: 'NAM_ID', 'REGION_ID', 'TERRITORY_CODE', '' ('' = No filter)
,	@filter_list	varchar(max)
,	@debug			int
AS
----------------------------------------------------------------------------------------------------------------------
/* 
Created new Summary Report by territory and service category. This pulls all the data from Territory Work Calculation and then
joins to service category to identify the revenue type
Gemini: 

12/15/2014   SK	Created
03/24/2015   SK Modified for Sales report rewrite for 2015, 
				Added business segment code
				Changed logic for totals by service category as this information is 
				now populated on resource classes and products
04/06/2015	JPB	Commented out Index declarations for the #TerritoryWork table - it's a speed thing.
04/27/2015	SK Added total for "unassigned" and third party disposal
06/25/2015  SK Added work order type and 3rdparty trans
07/16/2015	SK Added sort order per Steve's request - Gem 33308
04/28/2017	JPB	Add fields per GEM 43339
07/08/2018	JPB	Cust_name: 40->75
02/27/2021 JPB	DO:19018 - add CorporateRevenueClassification to output
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)				
-- all territories:  00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 41, 51

-- NEW:
	EXECUTE dbo.sp_rpt_sales_summary_AE
	  @date_from = '01-1-2021',
	  @date_to = '03-31-2021',
	  @copc_list='ALL',
	  @filter_field	= '',
	  @filter_list = '',
	  @debug = 1

-- before changes:
-- 4284 rows
-- Total extended amt #TerritoryWork:				50272443.7200028
-- Total extended amt #AEServiceCategorySummary:	50272443.72

-- after changes:
-- 4389 rows
-- Total extended amt #TerritoryWork:				50272443.7200028
-- Total extended amt #AEServiceCategorySummary:	50272443.72

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


CREATE TABLE #TerritoryWork 
            (
            company_id                                int             NULL
            , profit_ctr_id                           int             NULL
            , trans_source                            char(1)         NULL
            , receipt_id                              int             NULL
            , line_id                                 int             NULL
            , trans_type                              char(1)         NULL
            , workorder_sequence_id                   varchar(15)     NULL
            , workorder_resource_item                 varchar(15)     NULL
            , workorder_resource_type                 varchar(15)     NULL
            , invoice_date							  datetime		  NULL
            , billing_type                            varchar(20)     NULL
            , dist_company_id                         int             NULL
            , dist_profit_ctr_id                      int             NULL
            , extended_amt                            float           NULL    
            , territory_code                          varchar(8)      NULL
            , job_type                                char(1)         NULL
            , category_reason                         int             NULL
            , category_reason_description             varchar(100)    NULL
            , customer_id                             int             NULL
            , cust_name                               varchar(75)     NULL
            , profile_id                              int             NULL
            , quote_id                                int             NULL
            , approval_code                           varchar(40)     NULL
            , product_id                              int             NULL
            , nam_id                                  int             NULL
            , nam_user_name                           varchar(40)     NULL
            , region_id                               int             NULL
            , region_desc                             varchar(50)     NULL
            , billing_project_id                      int             NULL
            , billing_project_name                    varchar(40)     NULL
            , territory_user_name                     varchar(40)     NULL
            , territory_desc                          varchar(40)     NULL
            , servicecategory_uid                     int             NULL
            , service_category_description            varchar(50)     NULL
            , service_category_code                   char(1)         NULL
            , businesssegment_uid                     int             NULL
            , business_segment_code                   varchar(10)     NULL
            , workorder_type_id						  int			  NULL
			, workorder_type_desc					  varchar(40)	  NULL
        ) 

/*
CREATE INDEX approval_code ON #TerritoryWork (approval_code)
CREATE INDEX trans_type ON #TerritoryWork (trans_type)
CREATE INDEX company_id ON #TerritoryWork (company_id)
CREATE INDEX line_id ON #TerritoryWork (line_id)
CREATE INDEX receipt_id ON #TerritoryWork (receipt_id)
CREATE INDEX woresitem ON #TerritoryWork (workorder_resource_item)
CREATE INDEX category ON #TerritoryWork (service_category_code)
CREATE INDEX nam_id ON #TerritoryWork (nam_id)
CREATE INDEX region_id ON #TerritoryWork (region_id)
*/
CREATE INDEX category ON #TerritoryWork (service_category_code)

CREATE TABLE #AEServiceCategorySummary (
	Dist_Company_ID 		int			NULL
,	Dist_Profit_Ctr_ID		int			NULL
,	Customer_ID				int			NULL
,	Cust_Name				varchar(75) NULL
,	Territory_Code			varchar(8)	NULL
,	Territory_User_Name		varchar(40)	NULL
,	Territory_Desc			varchar(40)	NULL
,	NAM_User_Name			varchar(40)	NULL
,	Job_Type				char(1)		NULL
,	WorkOrder_type			varchar(40)	NULL
,	BusinessSegment_UID		int			NULL
,	Business_Segment_Code	varchar(10)	NULL
,	Corporate_Revenue_Classification_Description	varchar(40)		NULL
,	Total_Disposal			float		NULL
,	Total_3rdparty_Disposal	float		NULL
,	Total_Trans				float		NULL
,	Total_3rdparty_Trans	float		NULL
,	Total_Services			float		NULL
,	Total_EIR				float		NULL
,	Total_Fees				float		NULL
,	Total_Other				float		NULL
,	Total_Unassigned		float		NULL	
,	Total_Amount			float		NULL		
)
--	The sp_rpt_territory_calc_ai relies on the existence of #TerritoryWork, #tmp_copc and #tmp_territory
EXEC sp_rpt_territory_calc_ai @date_from, @date_to, @filter_field, @filter_list, @debug

--IF @debug = 1 
--BEGIN
--	PRINT 'Select Count(*)from #TerritoryWork:'
--	Select Count(*) from #TerritoryWork
--	PRINT 'Total extended amt from #TerritoryWork:'
--	Select SUM(IsNull(extended_amt, 0.00)) FROM #TerritoryWork
--END

INSERT INTO #AEServiceCategorySummary
-- Get Distinct Result Set
SELECT DISTINCT
	TW.dist_company_id
,	TW.dist_profit_ctr_id
,	TW.customer_id
,	TW.cust_name
,	TW.territory_code
,	TW.territory_user_name
,	TW.territory_desc
,	TW.nam_user_name
,	Isnull(TW.job_type, '')
,	Isnull(TW.workorder_type_desc, '')
,	TW.businesssegment_uid
,	Isnull(TW.business_segment_code, '')
,	Isnull(CRC.description, '')
,	SUM(CASE TW.service_category_code WHEN 'D' THEN CASE TW.category_reason WHEN 4 THEN 0 ELSE IsNull(TW.extended_amt, 0.00) END ELSE 0 END) AS total_Disposal
,	SUM(CASE TW.category_reason WHEN 4 THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END) AS total_3rdparty_Disposal
,	SUM(CASE TW.service_category_code WHEN 'T' THEN CASE TW.category_reason WHEN 8 THEN 0 ELSE IsNull(TW.extended_amt, 0.00) END ELSE 0 END) AS total_Trans
,   SUM(CASE TW.category_reason WHEN 8 THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END) AS Total_3rdparty_Trans
,	SUM(CASE TW.service_category_code WHEN 'S' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END) AS total_Services
,	SUM(CASE TW.service_category_code WHEN 'E' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END) AS total_EIR
,	SUM(CASE TW.service_category_code WHEN 'F' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END) AS total_fees
,	SUM(CASE TW.service_category_code WHEN 'O' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END) AS total_Other
,	SUM(CASE TW.service_category_code WHEN NULL THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END) AS total_unassigned
,	SUM(IsNull(TW.extended_amt, 0.00)) AS total_amount
FROM #TerritoryWork TW
LEFT JOIN WorkOrderHeader woh (nolock)
	on tw.company_ID = woh.company_ID
    and tw.Profit_Ctr_ID = woh.Profit_Ctr_ID
    and tw.Trans_Source = 'W'
    and tw.Receipt_ID = woh.workorder_id
LEFT JOIN Receipt r (nolock)
	on tw.company_ID = r.company_ID
    and tw.Profit_Ctr_ID = r.Profit_Ctr_ID
    and tw.Trans_Source = 'R'
    and tw.Receipt_ID = r.Receipt_ID
    and tw.Line_ID = r.line_id
LEFT JOIN OrderHeader o (nolock)
    on tw.Trans_Source = 'O'
    and tw.Receipt_ID = o.order_id
LEFT JOIN CorporateRevenueClassification crc (nolock)
	on coalesce(woh.corporate_revenue_classification_uid , r.corporate_revenue_classification_uid , o.corporate_revenue_classification_uid) = crc.corporate_revenue_classification_uid
GROUP BY
	TW.dist_company_id
,	TW.dist_profit_ctr_id
,	TW.customer_id
,	TW.cust_name
,	TW.territory_code
,	TW.territory_user_name
,	TW.territory_desc
,	TW.nam_user_name
,	Isnull(TW.job_type, '')
,	Isnull(TW.workorder_type_desc, '')
,	TW.businesssegment_uid
,	Isnull(TW.business_segment_code, '')
,	Isnull(CRC.description, '')
ORDER BY 
	TW.dist_company_id
,	TW.dist_profit_ctr_id
,	TW.customer_id
,	TW.cust_name
,	TW.territory_code
,	Isnull(TW.job_type, '')
,	Isnull(TW.workorder_type_desc, '')
,	TW.businesssegment_uid
,	Isnull(TW.business_segment_code, '')
,	Isnull(CRC.description, '')




-- select the resultset
Select
	AES.Dist_Company_ID 		
,	AES.Dist_Profit_Ctr_ID	
,	PC.Profit_Ctr_Name	
,	AES.Customer_ID			
,	AES.Cust_Name			
,	C.customer_type as Cust_Type
,	C.cust_category as Cust_Cat
,	AES.Territory_Code			
,	AES.Territory_User_Name		
,	AES.Territory_Desc			
,	AES.NAM_User_Name
,	CASE AES.Job_Type WHEN 'B' then 'Base' WHEN 'E' then 'Event' else AES.Job_Type end as Job_Type
,	AES.WorkOrder_type
,	AES.BusinessSegment_UID		
,	AES.Business_Segment_Code	
,   AES.Corporate_Revenue_Classification_Description
,	AES.Total_Disposal			
,	AES.Total_3rdparty_Disposal		
,	AES.Total_Trans			
,	AES.Total_3rdparty_Trans	
,	AES.Total_Services			
,	AES.Total_EIR				
,	AES.Total_Fees				
,	AES.Total_Other			
,	AES.Total_Unassigned				
,	AES.Total_Amount			
From #AEServiceCategorySummary AES
JOIN ProfitCenter PC
	ON PC.company_id = AES.Dist_Company_ID
	AND PC.profit_ctr_id = AES.Dist_Profit_Ctr_ID
JOIN Customer c
	ON AES.customer_id = c.customer_id
ORDER BY 
	AES.Territory_User_Name, AES.business_segment_code
	, AES.dist_company_id, AES.dist_profit_ctr_id
	, AES.customer_id
	, AES.job_type
	, AES.Total_Amount

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
    ON OBJECT::[dbo].[sp_rpt_sales_summary_AE] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_sales_summary_AE] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_sales_summary_AE] TO [EQAI]
    AS [dbo];

