
-- 
drop proc if exists sp_rpt_territory_Detail
go

CREATE PROCEDURE [dbo].[sp_rpt_territory_Detail]
	@date_from		datetime
,	@date_to		datetime
,	@copc_list		varchar(500)	-- accepts list: '2|21,14|0,22|0'
,	@filter_field	varchar(20)		-- one of: 'NAM_ID', 'REGION_ID', 'BILLING_PROJECT_ID', 'TERRITORY_CODE', '' ('' = No filter)
,	@filter_list	varchar(max)
,	@debug			int
AS
----------------------------------------------------------------------------------------------------------------------
/* 
Created new Detail Territory Report to show all the data from Territory Work Calculation
3/7/2011   SK	Created
3/10/2011  SK	Appended ProductID to #TerritoryWork, interpret defaults for territorylist & copc list
11/01/2011 JPB	Added NAM_ID, REGION_ID, BILLING_PROJECT_ID to #TerritoryWork table.
11/01/2011 JPB	... Also Added NAM_USER_NAME, REGION_DESC, BILLING_PROJECT_NAME, TERRITORY_USER_NAME, TERRITORY_DESC
03/24/2015 SK	Detail report modified to show service category and business segment UID
04/06/2015	JPB	Commented out Index declarations for the #TerritoryWork table - it's a speed thing.
07/06/2015 SK	Added Workorder type
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75
02/27/2021 JPB	DO:19018 - add CorporateRevenueClassification to output

-- all territories:  00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 41, 51

-- OLD:
	EXECUTE dbo.sp_rpt_territory_Detail
	  @date_from = '1-1-2011',
	  @date_to = '1-31-2011',
	  @territory_list = 'ALL',
	  @copc_list='ALL',
	  @debug = 0

-- NEW:
	EXECUTE dbo.sp_rpt_territory_Detail
	  @date_from = '01-1-2021',
	  @date_to = '05-31-2021',
	  @copc_list='ALL',
	  @filter_field	= NULL,
	  @filter_list = NULL,
	  @debug = 0

-- 221914 rows

*/
-----------------------------------------------------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

-- Get the copc list into tmp_Copc
CREATE TABLE #tmp_Copc ([company_ID] int, profit_Ctr_ID int)
IF @copc_list = 'ALL'
	INSERT #tmp_Copc
	SELECT ProfitCenter.company_ID,	ProfitCenter.profit_Ctr_ID FROM ProfitCenter WHERE status = 'A'
ELSE
	INSERT #tmp_Copc
	SELECT 
		RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) AS company_ID,
		RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) AS profit_Ctr_ID
	from dbo.fn_SplitXsvText(',', 0, @copc_list) WHERE isnull(row, '') <> ''
		
IF @debug = 1 print 'SELECT * FROM #tmp_Copc'
IF @debug = 1 SELECT * FROM #tmp_Copc

CREATE TABLE #TerritoryWork 
            (
            company_ID                                int             NULL
            , Profit_Ctr_ID                           int             NULL
            , Trans_Source                            char(1)         NULL
            , Receipt_ID                              int             NULL
            , Line_ID                                 int             NULL
            , Trans_type                              char(1)         NULL
            , Workorder_Sequence_ID                   varchar(15)     NULL
            , Workorder_resource_item                 varchar(15)     NULL
            , Workorder_resource_type                 varchar(15)     NULL
            , Invoice_Date							  datetime		  NULL
            , Billing_type                            varchar(20)     NULL
            , Dist_Company_ID                         int             NULL
            , Dist_profit_Ctr_ID                      int             NULL
            , Extended_amt                            float           NULL    
            , Territory_Code                          varchar(8)      NULL
            , Job_type                                char(1)         NULL
            , Category_reason                         int             NULL
            , Category_reason_Description             varchar(100)    NULL
            , Customer_ID                             int             NULL
            , Cust_Name                               varchar(75)     NULL
            , Profile_ID                              int             NULL
            , Quote_ID                                int             NULL
            , Approval_Code                           varchar(40)     NULL
            , Product_ID                              int             NULL
            , Nam_ID                                  int             NULL
            , Nam_user_Name                           varchar(40)     NULL
            , Region_ID                               int             NULL
            , Region_Desc                             varchar(50)     NULL
            , Billing_project_ID                      int             NULL
            , Billing_project_Name                    varchar(40)     NULL
            , Territory_user_Name                     varchar(40)     NULL
            , Territory_Desc                          varchar(40)     NULL
            , Servicecategory_UID                     int             NULL
            , Service_Category_Description            varchar(50)     NULL
            , Service_Category_Code                   char(1)         NULL
            , Businesssegment_UID                     int             NULL
            , Business_Segment_Code                   varchar(10)     NULL
            , workorder_type_id						  int			  NULL
			, workorder_type_desc				      varchar(40)	  NULL
        ) 


--CREATE INDEX approval_Code ON #TerritoryWork (approval_Code)
--CREATE INDEX trans_type ON #TerritoryWork (trans_type)
--CREATE INDEX company_ID ON #TerritoryWork (company_ID)
--CREATE INDEX line_ID ON #TerritoryWork (line_ID)
--CREATE INDEX receipt_ID ON #TerritoryWork (receipt_ID)
--CREATE INDEX woresitem ON #TerritoryWork (workorder_resource_item)
--CREATE INDEX category ON #TerritoryWork (service_Category_Code)
--CREATE INDEX nam_ID ON #TerritoryWork (nam_ID)
--CREATE INDEX region_ID ON #TerritoryWork (region_ID)

--	The sp_rpt_territory_Calc_ai relies on the existence of #TerritoryWork, #tmp_Copc and #tmp_territory
EXEC sp_rpt_territory_Calc_ai @date_from, @date_to, @filter_field, @filter_list, @debug

-- Get Result Set
SELECT TW.*, PC.Profit_Ctr_Name
, crc.description as Corporate_Revenue_Classification_Description
FROM #TerritoryWork TW
JOIN ProfitCenter PC (nolock)
	ON PC.company_id = TW.Dist_Company_ID
	AND PC.profit_ctr_id = TW.Dist_Profit_Ctr_ID
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

ORDER BY Dist_Company_ID, Dist_Profit_Ctr_ID, Territory_Code, Customer_ID, Billing_Project_ID, 
		TW.Company_ID, TW.Profit_Ctr_ID, trans_Source, receipt_ID, line_ID


IF @debug = 1 
BEGIN
	PRINT 'Total extended amt:'
	Select SUM(IsNull(extended_amt, 0.00)) FROM #TerritoryWork
END 

-- delete temp table
DROP TABLE #TerritoryWork


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_Detail] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_Detail] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_Detail] TO [EQAI]
    AS [dbo];


