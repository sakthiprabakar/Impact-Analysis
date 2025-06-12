
CREATE PROCEDURE sp_rpt_territory_validation
	@date_from		datetime
,	@date_to		datetime
,	@copc_list		varchar(max)	-- accepts list: '2|21,14|0,22|0'
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
04/14/2015	JPB	Created as copy of sp_rpt_territory_Detail to show only validation issues.
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75
06/16/2023 Devops 65744--Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)
-- all territories:  00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 41, 51

-- OLD:
	EXECUTE dbo.sp_rpt_territory_validation
	  @date_from = '1-1-2011',
	  @date_to = '1-31-2011',
	  @territory_list = 'ALL',
	  @copc_list='ALL',
	  @debug = 0

-- NEW:
	EXECUTE dbo.sp_rpt_territory_validation
	-- EXECUTE dbo.sp_rpt_territory_detail
	  @date_from = '12-1-2014',
	  @date_to = '12-31-2014',
	  @copc_list='ALL',
	  @filter_field	= '',
	  @filter_list = '',
	  @debug = 0


SELECT * FROM billing where receipt_id = 539892 and line_id = 1 and company_id = 2
SELECT * FROM billingdetail where billing_uid = 7036416
SELECT * FROM product where product_id = 89
update product set servicecategory_uid = 4 where product_id = 89
update product set businesssegment_uid = 1 where product_id = 89


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
            , workorder_type_id                             int                     NULL
            , workorder_type_desc                     varchar(40)       NULL
        ) 


--	The sp_rpt_territory_Calc_ai relies on the existence of #TerritoryWork, #tmp_Copc and #tmp_territory
EXEC sp_rpt_territory_Calc_ai @date_from, @date_to, @filter_field, @filter_list, @debug

CREATE TABLE #TerritoryValidation
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
            , Product_id							  int			  NULL
            , validation_issue						  varchar(max)	  NULL
)

insert #TerritoryValidation
select company_ID, Profit_Ctr_ID, Trans_Source, Receipt_ID, Line_ID, Trans_type, Workorder_Sequence_ID, Workorder_resource_item, Workorder_resource_type, Product_id
, 'Billing Project Territory Code Missing' as validation_issue
from #TerritoryWork
where len(ltrim(rtrim(isnull(territory_code, '')))) = 0

insert #TerritoryValidation
select company_ID, Profit_Ctr_ID, Trans_Source, Receipt_ID, Line_ID, Trans_type, Workorder_Sequence_ID, Workorder_resource_item, Workorder_resource_type, Product_id
, 'Territory Description Missing' as validation_issue
from #TerritoryWork
where len(ltrim(rtrim(isnull(Territory_Desc, '')))) = 0

insert #TerritoryValidation
select company_ID, Profit_Ctr_ID, Trans_Source, Receipt_ID, Line_ID, Trans_type, Workorder_Sequence_ID, Workorder_resource_item, Workorder_resource_type, Product_id
, 'Billing Project Territory AE Name Missing' as validation_issue
from #TerritoryWork
where len(ltrim(rtrim(isnull(Territory_user_Name, '')))) = 0

insert #TerritoryValidation
select w.company_ID, w.Profit_Ctr_ID, w.Trans_Source, w.Receipt_ID, w.Line_ID, w.Trans_type, w.Workorder_Sequence_ID, w.Workorder_resource_item, w.Workorder_resource_type, Product_id
, 'Billing Project Territory AE is Inactive' as validation_issue
from #TerritoryWork w
inner join Users u on w.territory_user_name = u.user_name and u.group_id in (0)

/*
insert #TerritoryValidation
select company_ID, Profit_Ctr_ID, Trans_Source, Receipt_ID, Line_ID, Trans_type, Workorder_Sequence_ID, Workorder_resource_item, Workorder_resource_type, Product_id
, 'Billing Project Region Missing' as validation_issue
from #TerritoryWork
where len(ltrim(rtrim(isnull(Region_Desc, '')))) = 0
*/

insert #TerritoryValidation
select company_ID, Profit_Ctr_ID, Trans_Source, Receipt_ID, Line_ID, Trans_type, Workorder_Sequence_ID, Workorder_resource_item, Workorder_resource_type, Product_id
, 'Service Category Missing' as validation_issue
from #TerritoryWork
where len(ltrim(rtrim(isnull(Service_Category_Description, '')))) = 0

insert #TerritoryValidation
select company_ID, Profit_Ctr_ID, Trans_Source, Receipt_ID, Line_ID, Trans_type, Workorder_Sequence_ID, Workorder_resource_item, Workorder_resource_type, Product_id
, 'Business Segment Missing' as validation_issue
from #TerritoryWork
where len(ltrim(rtrim(isnull(Business_Segment_Code, '')))) = 0


-- Get Result Set
SELECT 
v.validation_issue
, w.Dist_Company_ID                      
, w.Dist_Profit_Ctr_ID          
, PC.Profit_Ctr_Name          
, w.Customer_ID                           
, w.Cust_Name                             
, w.Billing_Project_ID                    
, w.Billing_Project_Name                  
, w.Territory_Code                        
, w.Territory_User_Name                   
, w.Territory_Desc                        
, w.NAM_ID                                
, w.NAM_User_Name                         
, w.Region_ID                             
, w.Region_Desc                           
, CASE w.Job_Type WHEN 'B' then 'Base' when 'E' then 'Event' else w.Job_Type end as Job_Type
, w.Businesssegment_UID                   
, w.Business_Segment_Code    
, CASE w.Trans_Source WHEN 'R' then 'Receipt' when 'W' then 'Work Order' when 'O' then 'Retail Order' else w.Trans_Source end as Trans_Source
, W.Company_ID                              
, W.Profit_Ctr_ID                         
, w.Receipt_ID                            
, w.Line_ID    
, w.Profile_ID       
, w.Approval_Code 
, w.Workorder_Sequence_ID                 
, w.Workorder_Resource_Type 
, w.Product_ID
, w.Invoice_Date
, w.Service_Category_Description
, w.Service_Category_Code
, w.Trans_Type
, w.Workorder_Resource_Item
, w.Quote_ID
, w.Billing_Type
, w.Category_Reason
, w.Category_Reason_Description
, w.Extended_amt
FROM #TerritoryWork w
JOIN #TerritoryValidation v
	ON  v.company_ID                 = w.company_ID                   
	and v.Profit_Ctr_ID              = w.Profit_Ctr_ID              
	and v.Trans_Source               = w.Trans_Source               
	and v.Receipt_ID                 = w.Receipt_ID                 
	and v.Line_ID                    = w.Line_ID                    
	and v.Trans_type                 = w.Trans_type                 
	and v.Workorder_Sequence_ID      = w.Workorder_Sequence_ID      
	and v.Workorder_resource_item    = w.Workorder_resource_item    
	and v.Workorder_resource_type    = w.Workorder_resource_type    
	and v.Product_id			     = w.Product_id
JOIN ProfitCenter PC
	ON PC.company_id = w.Dist_Company_ID
	AND PC.profit_ctr_id = w.Dist_Profit_Ctr_ID
ORDER BY w.Dist_Company_ID, w.Dist_Profit_Ctr_ID, v.validation_issue, w.Territory_Code, w.Customer_ID, w.Billing_Project_ID, 
		w.Company_ID, w.Profit_Ctr_ID, w.trans_Source, w.receipt_ID, w.line_ID


-- delete temp table
DROP TABLE #TerritoryWork


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_validation] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_validation] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_validation] TO [EQAI]
    AS [dbo];

