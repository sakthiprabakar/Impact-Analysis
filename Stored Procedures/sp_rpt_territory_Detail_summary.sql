
CREATE PROCEDURE sp_rpt_territory_Detail_summary
	@date_from		datetime = '1/1/2014'
,	@date_to		datetime = '12/31/2014'
,	@copc_list		varchar(max) = 'ALL'	-- accepts list: '2|21,14|0,22|0'
,	@filter_field	varchar(20) = ''		-- one of: 'NAM_ID', 'REGION_ID', 'BILLING_PROJECT_ID', 'TERRITORY_CODE', '' ('' = No filter)
,	@filter_list	varchar(max) = ''
,	@debug			int
WITH RECOMPILE
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
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75
06/16/2023 Devops 65744--Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
-- all territories:  00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 41, 51

-- OLD:
	EXECUTE dbo.sp_rpt_territory_Detail_summary
	  @date_from = '1-1-2011',
	  @date_to = '1-31-2011',
	  @territory_list = 'ALL',
	  @copc_list='ALL',
	  @debug = 0

-- NEW:
	EXECUTE dbo.sp_rpt_territory_Detail_summary
	  @date_from = '4-1-2015',
	  @date_to = '5-1-2015',
	  @copc_list='ALL',
	  @filter_field	= '',
	  @filter_list = '',
	  @debug = 0
-- ntsql1 PRECHANGE:  01:07, 120790 rows.
--  add int vars   :  01:35, 120790
--  add recompile  :  01:16
--  remove recompile, add input defaults with masking
				   :  00:52, 121279
-- add sp_rpt_territory_calc_ai defaults, masking
				   :  01:01, 121279   

-- SSRS            :  03:40
--  remove page column headers
--                 :  03:28    Well that sucks.
-- refresh sql def :  03:20
--  Add recompile  :  still awful

-- Found ReportServer.ExecutionLogStorage - it shows the really awful part of SSRS is rendering.
	-- That's a function of the number of rows returned.
	
:38.  124736 rows - test. 5/13
*/
-----------------------------------------------------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

declare
	@int_date_from		datetime
,	@int_date_to		datetime
,	@int_copc_list		varchar(500)	-- accepts list: '2|21,14|0,22|0'
,	@int_filter_field	varchar(20)		-- one of: 'NAM_ID', 'REGION_ID', 'BILLING_PROJECT_ID', 'TERRITORY_CODE', '' ('' = No filter)
,	@int_filter_list	varchar(max)
,	@int_debug			int

select
@int_date_from		= @date_from		
, @int_date_to		= @date_to		
, @int_copc_list		= @copc_list		
, @int_filter_field	= @filter_field	
, @int_filter_list	= @filter_list	
, @int_debug			= @debug			
	


-- Get the copc list into tmp_Copc
CREATE TABLE #tmp_Copc ([company_ID] int, profit_Ctr_ID int)
IF @int_copc_list = 'ALL'
	INSERT #tmp_Copc
	SELECT ProfitCenter.company_ID,	ProfitCenter.profit_Ctr_ID FROM ProfitCenter WHERE status = 'A'
ELSE
	INSERT #tmp_Copc
	SELECT 
		RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) AS company_ID,
		RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) AS profit_Ctr_ID
	from dbo.fn_SplitXsvText(',', 0, @int_copc_list) WHERE isnull(row, '') <> ''
		
IF @int_debug = 1 print 'SELECT * FROM #tmp_Copc'
IF @int_debug = 1 SELECT * FROM #tmp_Copc

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
        ) 

/*
CREATE INDEX approval_Code ON #TerritoryWork (approval_Code)
CREATE INDEX trans_type ON #TerritoryWork (trans_type)
CREATE INDEX company_ID ON #TerritoryWork (company_ID)
CREATE INDEX line_ID ON #TerritoryWork (line_ID)
CREATE INDEX receipt_ID ON #TerritoryWork (receipt_ID)
CREATE INDEX woresitem ON #TerritoryWork (workorder_resource_item)
CREATE INDEX category ON #TerritoryWork (service_Category_Code)
CREATE INDEX nam_ID ON #TerritoryWork (nam_ID)
CREATE INDEX region_ID ON #TerritoryWork (region_ID)
*/
CREATE INDEX category ON #TerritoryWork (service_category_code)

--	The sp_rpt_territory_Calc_ai relies on the existence of #TerritoryWork, #tmp_Copc and #tmp_territory
EXEC sp_rpt_territory_Calc_ai @int_date_from, @int_date_to, @int_filter_field, @int_filter_list, @int_debug

-- Get Result Set
SELECT 
Dist_Company_ID                      
, Dist_Profit_Ctr_ID          
, PC.Profit_Ctr_Name          
, Customer_ID                           
, Cust_Name                             
, Billing_Project_ID                    
, Billing_Project_Name                  
, Territory_Code                        
, Territory_User_Name                   
, Territory_Desc                        
, NAM_ID                                
, NAM_User_Name                         
, Region_ID                             
, Region_Desc                           
, CASE Job_Type WHEN 'B' then 'Base' when 'E' then 'Event' else Job_Type end as Job_Type
, Businesssegment_UID                   
, Business_Segment_Code    
, CASE Trans_Source WHEN 'R' then 'Receipt' when 'W' then 'Work Order' when 'O' then 'Retail Order' else Trans_Source end as Trans_Source
, TW.Company_ID                              
, TW.Profit_Ctr_ID                         
, Receipt_ID                            
, Line_ID    
, Profile_ID       
, Approval_Code 
, Workorder_Sequence_ID                 
, Workorder_Resource_Type 
, Invoice_Date							                                  
,	SUM(CASE TW.service_category_code WHEN 'D' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END) AS total_Disposal
,	SUM(CASE TW.service_category_code WHEN 'T' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END) AS total_Trans
,	SUM(CASE TW.service_category_code WHEN 'S' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END) AS total_Services
,	SUM(CASE TW.service_category_code WHEN 'E' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END) AS total_EIR
,	SUM(CASE TW.service_category_code WHEN 'F' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END) AS total_fees
,	SUM(CASE TW.service_category_code WHEN 'O' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END) AS total_Other
,	SUM(IsNull(TW.extended_amt, 0.00)) AS total_amount               
FROM #TerritoryWork TW
JOIN ProfitCenter PC
	ON PC.company_id = TW.Dist_Company_ID
	AND PC.profit_ctr_id = TW.Dist_Profit_Ctr_ID
GROUP BY
  Dist_Company_ID                      
, Dist_Profit_Ctr_ID          
, PC.Profit_Ctr_Name          
, Customer_ID                           
, Cust_Name                             
, Billing_Project_ID                    
, Billing_Project_Name                  
, Territory_Code                        
, Territory_User_Name                   
, Territory_Desc                        
, NAM_ID                                
, NAM_User_Name                         
, Region_ID                             
, Region_Desc                           
, Job_Type
, Businesssegment_UID                   
, Business_Segment_Code    
, Trans_Source
, TW.Company_ID                              
, TW.Profit_Ctr_ID                         
, Receipt_ID                            
, Line_ID    
, Profile_ID       
, Approval_Code 
, Workorder_Sequence_ID                 
, Workorder_Resource_Type 
, Invoice_Date	
ORDER BY Dist_Company_ID, Dist_Profit_Ctr_ID, Territory_Code, Customer_ID, Billing_Project_ID, 
		TW.Company_ID, TW.Profit_Ctr_ID, trans_Source, receipt_ID, line_ID

IF @int_debug = 1 
BEGIN
	PRINT 'Total extended amt:'
	Select SUM(IsNull(extended_amt, 0.00)) FROM #TerritoryWork
END 

-- delete temp table
DROP TABLE #TerritoryWork


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_Detail_summary] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_Detail_summary] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_Detail_summary] TO [EQAI]
    AS [dbo];

