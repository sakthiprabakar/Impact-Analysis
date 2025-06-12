DROP PROCEDURE IF EXISTS [dbo].[sp_rpt_territory_calc_ai]
GO

CREATE PROCEDURE [dbo].[sp_rpt_territory_calc_ai]
    @date_from		datetime
    , @date_to		datetime
    , @filter_field	varchar(20)
    , @filter_list	varchar(max)
    , @debug		int
AS
/*********************************************************************************************
sp_rpt_territory_calc_ai
SQL Object(s):   Called from sp_territory_detail, sp_territory_sum

-- History:
06/08/1999 LJT  This is a new stored procedure call by the other territory and commission reports to create the territory work table.
07/02/1999 JDB Replaced all instances of "ticket_date" with "invoice_date"
07/02/1999 LJT  Modified to process waste water and reclaim as category 3
01/13/2000 LJT  Modified to add Territory specifications for 2000
06/09/2000 LJT  Modified to assign Rail to category 3
07/12/2000 LJT  Added indexes for company, receipt_id, ticket workorder resourceitem, tsdf code
                                on Territory work and on receipt and ticket for TerritoryWorkSplit
09/28/2000 LJT  Changed = NULL to is NULL and <> null to is not null
10/30/2000 LJT  Corrected assignment of Workorder other with category of Disposal should be assigned category 3 was assigne category 1
10/30/2000 LJT  Corrected the category of WO - Other Disposal from cat 1 to cat 3
10/31/2000 LJT  Modified to refer to RAIL as trans type as 'S' as well as bill unit = 'RAIL'
11/08/2000 LJT  Removed MRS treatment 7 from category 4. It was in both catagories 3 and 4.
01/29/2001 LJT  Modified to refer to bill_unit_code for length of 4 instead of bill_unit_code - it was truncating
                                added profit center joins to 6 selects.
04/04/2001 JDB Modified to use the workorderdetail table rather than the workorderdisposal table.
06/07/2001 LJT  Added a second update on WO - T&D that do not have prices to assign the trans portion to category 2.
                                Also added company 14 into the drums to category 1 statement.
                                Also reassigned treatment ids for all companies per Debbie and Rob
09/23/2002 LJT  Modified to use new EQRR Treatment IDs
12/17/2002 LJT  Modified to use new Wayne Treatment IDs - 41, 42, 43 into category 2.
04/08/2003 LJT  Modified to add profit center to the query that sets the approval codes. Remove OTS from the end of the approval code
07/11/2003 LJT  Added treatments 44, 45 and 46 to company 2 category 1.
09/16/2003 LJT  Removed logic for running 14 separately so it could run for all companies.
10/02/2003 JDB Add logic for running for variable number of companies.
10/07/2003 LJT  Added missing Treamtents and changed Category 1 'DRUM' to be containers.
12/01/2004 LJT  Added the following to Category 2 for company 2 (49,50,80,81,82,83,84,85,86,87,89)
                                Also removed where trans_type = W or R from category 3 since these are now treatments.
12/07/2004 LJT  Setting non-bulk to category 1 was missing the check for disposal records only.
12/30/2004 SCC Changed ticket_id to line_id and used Billing table
03/04/2005 LJT  Added join by receipt id in a few places.
04/14/2005 JDB Added bill_unit_code for TSDFApproval
04/15/2005 LJT  Added the setting of Territory code to 99 for Workorder charges with a category containing FEE
04/29/2005 LJT  Correct mistake of ='%FEE%' to like "%FEE%'
06/01/2005 LJT  Added Company 21 Commission categories
06/03/2005 LJT  Revised Commission Category assignments - one set now for all of EQ
09/08/2005 LJT  Temporary Fix!! Remove Later! Added differentiation of EQ Detroit treatments for EQRR as separate report line (21-88)
10/04/2005 LJT  Added Resource Category of Rail to category 4
10/04/2005 LJT  Added Waste receipt logic to only select bundled Tran
11/12/2005 SCC Changed name from sp_territorywork_calc and removed month, year, territory code arguments. Now uses
                territory and profit center temp tables defined in calling SP
05/03/2006 LJT  Modified reprot to move all of company 24 to category 2.
07/21/2006 LJT  Modified to use profile and apply customer service centralization project changes.
02/26/2008 LJT  Added the ability to use the multiple territories from the billing project
03/05/2008 LJT  Added pulling the customer territory from the customer billing instead of customer to select report information
04/21/2008 LJT  Removed Temporary Fix!! differentiation of EQ Detroit treatments for EQRR as separate report line (21-88)
09/09/2008 LJT  Added the assignment of Retail Order to Base Category 3.
11/28/2008 LJT  Changed the assignment of Retail Order to from Base Category 3 to Base Category 2
12/09/2008 LJT  Workorder other t&d split was using Quantity instead of quantity_used,
                Also the records selected back into Territorywork from territory work split changed trans_type from 'D' to 'O' in the where
                Also replaced the equipment lookup in the 3rd party equipment to be the same as EQ equipment - it was returning none.
                Also updated sequence number to be the disposal line the approval came from on split lines.
09/18/2009 LJT  Added Energy Surcharge to the Commissionable Revenue as Category 2.
04/16/2010 RJG Added profit_ctr_id join to ResourceClass references because this table now points to a view that points to a table on PLT_AI 
05/07/2010 JDB Added bill_unit_code join from #TerritoryWork to ResourceClass.
02/01/2011 RJG Moved to PLT_AI, modified joins to add company_id - removed *= syntax,
                                                                Added insr_extended_amt and sr_extended_amt
04/01/2011 JPB  Modified "set trans Flag - for Tran Products" section to use new Product fields.
04/19/2011 JPB  Modified with Lorraine
11/01/2011 JPB Added NAM_ID, REGION_ID, BILLING_PROJECT_ID to #TerritoryWork table.
11/01/2011 JPB ... Also Added NAM_USER_NAME, REGION_DESC, BILLING_PROJECT_NAME, TERRITORY_USER_NAME, TERRITORY_DESC
03/05/2012 JPB Added isnull() handlers to the T&D split calculations to handle cases where the related receipt cannot be found.
                                                                ... Also removed  references.
03/13/2012 JPB Offshoot for 2012 Commission Changes.
                                                                ... I have named him: sp_rpt_territory_calc_ai  Catchy, no?
05/10/2012 JPB After researching a "Why is WO 4136901 in Cat 0, not Cat 1?" question, this change
                                                                ... is to move Cat 3 -> Cat 0, per Lorraine.
09/20/2013  SM  Changed waste_code to display_name and uid condition 
10/04/2013  SM  Changed display_name to  send space when null
01/22/2014 JPB	Talked with LT about why we update results so company_id = dist_company_id and profit_ctr_id = dist_profit_ctr_id
				Concluded we do that so we did not have to change the EQAI reports but could report which companies are getting
				The revenue.
				The current concern/problem is that we now cannot tell from the data returned by this SP where the original
				record came from because the dist_* info overlays it permanently.
				* So what we should do is: DO NOT update company_id & profit_ctr_id = dist_company_id & dist_profit_ctr_id - just
				* return them both and let the EQAI report determine which is displayed (format, order, etc).
03/06/2014 JPB	Following up from above (1/22): Changed this SP in 2 ways:
				1. It runs for ALL companies and profitcenters - no filter, until the very end and then deletes irrelevent records.
				2. Nevermind, there was only 1 net change.
03/20/2014 JPB	Final Probably Redundant Commissionable Flag handling... 
				UPDATE #TerritoryWork set commissionable_flag = 'F' where category = 5
				Because category 5 is not commissionable.
03/24/2015	JPB	Rewrite.  Logic comes from sp_rpt_recognized_revenue_calc/NAICS work because categories have been massively revised.
				Still taking the same inputs, returning the same outputs... just new math/internal process
04/01/2015	JPB	Rob Briggs made some massive speed tweaks in here, all good.
				Then I screwed up the filtering part at the end by filtering to #TerritoryWorkFilter.. but accidentally then wiping that 
				table out and returning the regular (unfiltered) #TerritoryWOrk table.  Oops. Fixed.
04/07/2015	JPB	Added after-the-fact update for 3rd party Work Order Disposal to categorize it separately than in-company Work Order Disposal
				Revised Filter logic sections- only run if filtering, index filtering field, don't show blanks when a specific item is filter-input.
05/08/2015	JPB	Another change to 3rd party Work Order Disposal: Only affect Disposal Billing_Types with category_reason 4.
				Receipt Disposal OR Wash get treated like Disposal.
				Work Order w Fixed Price = Service.
06/25/2015	SK	Added new field work order type, and new category/reason for 3rd party trans
06/25/2015	JPB	Copied SK's mods for added fields
					handled the WorkOrderType business segment override and split logic.
					handled the 3rd party Trans logic (category 8)
02/26/2016	SK	replaced to use use_flag instead of eq_flag. Also for third party WO without E, L or S added check to make sure its not a USE transporter
07/08/2019	JPB	cust_name size change 40->75
12/??/2021	JPB/DW	
12/27/2021  DW	Added 
07/08/2024 KS	Rally116985 - Modified service_desc_1 datatype to VARCHAR(100) for #InternalTW table.

Sample:	
sp_rpt_territory_calc 6, 2003, '1-01-2003', '6-30-2003', '', 12, 'DEV'


-- Create #TerritoryWork Table

-- DROP TABLE #territoryWork
-- GO
-- DROP TABLE #TerritoryWorkSplit
-- GO
--


CREATE TABLE #TerritoryWork 
		(
            company_id							int             NULL
            , profit_ctr_id						int             NULL
            , trans_source						char(1)         NULL
            , receipt_id						int             NULL
            , line_id							int             NULL
            , trans_type						char(1)         NULL
            , workorder_sequence_id				varchar(15)     NULL
            , workorder_resource_item			varchar(15)     NULL
            , workorder_resource_type			varchar(15)     NULL
            , invoice_date						datetime		NULL
            , billing_type						varchar(20)     NULL
            , dist_company_id					int             NULL
            , dist_profit_ctr_id				int             NULL
            , extended_amt						float           NULL    
            , territory_code					varchar(8)      NULL
            , job_type							char(1)         NULL
            , category_reason					int             NULL
            , category_reason_description		varchar(100)	NULL
            , customer_id						int             NULL
            , cust_name							varchar(75)     NULL
            , profile_id						int             NULL
            , quote_id							int             NULL
			, approval_code						varchar(40)     NULL
            , product_id						int				NULL
            , nam_id							int             NULL
            , nam_user_name						varchar(40)     NULL
            , region_id							int             NULL
            , region_desc						varchar(50)     NULL
            , billing_project_id				int             NULL
            , billing_project_name				varchar(40)     NULL
            , territory_user_name				varchar(40)     NULL
            , territory_desc					varchar(40)     NULL
			, servicecategory_uid				int				NULL
			, service_category_description		varchar(50)		NULL
			, service_category_code				char(1)			NULL
			, businesssegment_uid				int				NULL
			, business_segment_code				varchar(10)		NULL
			, workorder_type_id					int				NULL
			, workorder_type_desc				varchar(40)		NULL
        ) 

	CREATE TABLE #tmp_copc 
		(
				company_id							int				NULL
				, profit_ctr_id						int				NULL
		)
	insert #tmp_copc select company_id, profit_ctr_id from profitcenter where status = 'A' and company_id = 23



truncate table #TerritoryWork

sp_rpt_territory_calc_ai '1/01/2015', '1/31/2015', '', '', 1

SELECT * FROM #TerritoryWork 
where category_reason = 8

SELECT * FROM workorderdetail where workorder_id = 5700 and company_id = 23
SELECT * FROM workordertransporter where workorder_id = 5700 and company_id = 23
SELECT * FROM transporter where transporter_code = 'FCI'

Date range 11/1/2014 to 4/1/2015

Customer ID 3734, in company 14-15, showing columns of $0 but the total column shows $10253.66.
Customer ID 150037, in company 25-00, showing columns of $0 but the total column shows $300.00.

4017	MEIJER CORPORATION	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$1564.83	$0.00	DIFF	-1564.83
11223	US TANK ALLIANCE, INC.	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$8268.11	$0.00	DIFF	-8268.11
12048	ARCADIS US INC	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$19.66	$0.00	DIFF	-19.66
13457	SG SOLUTIONS LLC	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$75.00	$0.00	DIFF	-75
13638	CINTAS CORPORATION CPA #418	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$41.50	$0.00	DIFF	-41.5
13944	VECTREN CORPORATION	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$20.79	$0.00	DIFF	-20.79
14232	RITE AID DISTRIBUTION CENTER	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$47.50	$0.00	DIFF	-47.5
16165	MARCEGAGLIA USA INC	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$0.00	$760.00	$0.00	DIFF	-760
		$187886545.40	$0.00	$69747452.29	$18233152.03	$5573186.25	$9379242.53	$71634467.81	$0.00	$362464843.70	$362454046.31	DIFF	-10797.39

SELECT * FROM #TerritoryWork where customer_id = 3734 and company_id = 14 and profit_ctr_id = 15 -- Work Order Fixed Price
SELECT * FROM #TerritoryWork where customer_id = 150037 and company_id = 25 and profit_ctr_id = 0 -- Receipt Wash

SELECT * FROM #TerritoryWork where customer_id = 4017 and company_id = 14 and profit_ctr_id = 6 and category_reason is null compute sum(extended_amt) -- Work Order Resource MISC - no assignment
SELECT * FROM #TerritoryWork where customer_id = 11223 and company_id = 14 and profit_ctr_id = 6 and category_reason is null compute sum(extended_amt) -- Work Order Resource MISC - no assignment
SELECT * FROM #TerritoryWork where customer_id = 12048 and company_id = 14 and profit_ctr_id = 6 and category_reason is null compute sum(extended_amt) -- Work Order Resource MISC - no assignment
SELECT * FROM #TerritoryWork where customer_id = 13457 and company_id = 14 and profit_ctr_id = 6 and category_reason is null compute sum(extended_amt) -- Work Order Resource MISC - no assignment
SELECT * FROM #TerritoryWork where customer_id = 13638 and company_id = 14 and profit_ctr_id = 6 and category_reason is null compute sum(extended_amt) -- Work Order Resource MISC - no assignment
SELECT * FROM #TerritoryWork where customer_id = 13944 and company_id = 14 and profit_ctr_id = 6 and category_reason is null compute sum(extended_amt) -- Work Order Resource MISC - no assignment
SELECT * FROM #TerritoryWork where customer_id = 14232 and company_id = 14 and profit_ctr_id = 6 and category_reason is null compute sum(extended_amt) -- Work Order Resource MISC - no assignment
SELECT * FROM #TerritoryWork where customer_id = 16165 and company_id = 14 and profit_ctr_id = 6 and category_reason is null compute sum(extended_amt) -- Work Order Resource MISC - no assignment

SELECT * FROM ResourceClassDetail where resource_class_code = 'MISC'

SELECT DISTINCT
	TW.dist_company_id
,	TW.dist_profit_ctr_id
,	TW.customer_id
,	TW.cust_name
,	TW.territory_code
,	TW.territory_user_name
,	TW.territory_desc
,	Isnull(TW.job_type, '')
,	TW.businesssegment_uid
,	Isnull(TW.business_segment_code, '')
,	SUM(CASE WHEN TW.category_reason <> 4 THEN CASE TW.service_category_code WHEN 'D' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END ELSE 0 END) AS total_Disposal
,	SUM(CASE TW.category_reason WHEN 4 THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END) AS total_3rdparty_Disposal
,	SUM(CASE WHEN TW.category_reason <> 4 THEN CASE TW.service_category_code WHEN 'T' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END ELSE 0 END) AS total_Trans
,	SUM(CASE WHEN TW.category_reason <> 4 THEN CASE TW.service_category_code WHEN 'S' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END ELSE 0 END) AS total_Services
,	SUM(CASE WHEN TW.category_reason <> 4 THEN CASE TW.service_category_code WHEN 'E' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END ELSE 0 END) AS total_EIR
,	SUM(CASE WHEN TW.category_reason <> 4 THEN CASE TW.service_category_code WHEN 'F' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END ELSE 0 END) AS total_fees
,	SUM(CASE WHEN TW.category_reason <> 4 THEN CASE TW.service_category_code WHEN 'O' THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END ELSE 0 END) AS total_Other
,	SUM(CASE WHEN TW.category_reason <> 4 THEN CASE TW.service_category_code WHEN NULL THEN IsNull(TW.extended_amt, 0.00) ELSE 0 END ELSE 0 END) AS total_unassigned
,	SUM(IsNull(TW.extended_amt, 0.00)) AS total_amount
FROM #TerritoryWork TW
where customer_id = 3734 and company_id = 14 and profit_ctr_id = 15
-- where customer_id = 150037 and company_id = 25 and profit_ctr_id = 0
GROUP BY
	TW.dist_company_id
,	TW.dist_profit_ctr_id
,	TW.customer_id
,	TW.cust_name
,	TW.territory_code
,	TW.territory_user_name
,	TW.territory_desc
,	Isnull(TW.job_type, '')
,	TW.businesssegment_uid
,	Isnull(TW.business_segment_code, '')
ORDER BY 
	TW.dist_company_id
,	TW.dist_profit_ctr_id
,	TW.customer_id
,	TW.cust_name
,	TW.territory_code
,	Isnull(TW.job_type, '')
,	TW.businesssegment_uid
,	Isnull(TW.business_segment_code, '')

SELECT * FROM #TerritoryWork where customer_id = 150037 and company_id = 25 and profit_ctr_id = 0 and territory_code = ''

SELECT * FROM #TerritoryWork where receipt_id = 1061500
SELECT * FROM #TerritoryWork where receipt_id = 73958

SELECT * FROM #TerritoryWork where workorder_resource_type = 'H'

-- Fixed Price Work Order.
--	No territory code, no service category, no business segment.


select sum(bd.extended_amt)
from billing b
join billingdetail bd
	on b.billing_uid = bd.billing_uid
where b.invoice_date between '2/1/2014' and '2/28/2014'
and void_status = 'F'

SELECT sum(extended_amt) FROM #TerritoryWork
-- 23463008.4499977 -- just "ALL"
-- 23463008.4499979 -- "All, 1, 2, 3, 4, 5, 6, 7, 8"

-- tw:	39676745.51
-- bd:	39676745.610000

-- 10/2014
-- no filtering: 24s
-- region 1,2,3,4,5,6: 44s
-- territory 06,33,66: 23s

-- 11/2014
-- no filtering: 48
-- nam 1,7: 21

SELECT distinct nam_id FROM #TerritoryWork
SELECT servicecategory_uid, service_category_description, billing_type, category_reason_description, * FROM #TerritoryWork where trans_source = 'R' and trans_type = 'D' and category_reason_description = 'Service category set via receipt disposal'
order by servicecategory_uid
*********************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

if object_id('tempdb..#filter') IS NOT NULL
	drop table #filter
	
CREATE TABLE #filter (filter_id int)

-- Handle Filter Field & List
insert #filter select convert(int, row) from dbo.fn_SplitXsvText(',', 0, @filter_list) where isnull(row, '') <> '' and ISNUMERIC(row) = 1

declare @timestart datetime = getdate(), @lasttime datetime = getdate()

if @debug > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting Proc' as status
set @lasttime = getdate()

-- Setup

-- declare @date_from datetime = '10/1/2011', @date_to datetime = '10/31/2011', @debug int = 1

-- Fix/Set @date_to's time.
if @date_from is null BEGIN
	--RAISERROR 50001 '@date_from is required when running against Invoiced records.'
	RAISERROR (50001, 10, 1, '@date_from is required when running against Invoiced records.')
	RETURN
END
if @date_to is null BEGIN
	--RAISERROR 50001 '@date_to is required when running against Invoiced records.'
	RAISERROR (50001, 10, 1, '@date_to is required when running against Invoiced records.')
	RETURN
END

IF ISNULL(@date_to,'') <> ''
	IF DATEPART(hh, @date_to) = 0 SET @date_to = @date_to + 0.99999

if object_id('tempdb..#InternalTW') is not null
	drop table #InternalTW

-- create an internal working table:
CREATE TABLE #InternalTW
		(
			billing_uid							int				NULL
			, billingdetail_uid					int				NULL
			, invoice_id						int				NULL 
			, invoice_code						varchar(16)		NULL 
			, AcctExecID						int				NULL 
			, AcctExecCode						varchar(10)		NULL 
			, AcctExecName						varchar(40)		NULL 
			, generator_id						int				NULL
			, generator_name					varchar(75)		NULL
			, nam_user_code						varchar(10)		NULL 
			, service_desc_1					varchar(100)	NULL 
			------------------------------------------------------------
            , company_id						int             NULL
            , profit_ctr_id						int             NULL
            , trans_source						char(1)         NULL
            , receipt_id						int             NULL
            , line_id							int             NULL
            , trans_type						char(1)         NULL
            , workorder_sequence_id				varchar(15)     NULL
            , workorder_resource_item			varchar(15)     NULL
            , workorder_resource_type			varchar(15)     NULL
            , invoice_date						datetime		NULL
            , billing_type						varchar(20)     NULL
            , dist_company_id					int             NULL
            , dist_profit_ctr_id				int             NULL
            , extended_amt						float           NULL    
            , territory_code					varchar(8)      NULL
            , job_type							char(1)         NULL
            , category_reason					int             NULL
            , category_reason_description		varchar(100)	NULL
            , customer_id						int             NULL
            , cust_name							varchar(75)     NULL
            , profile_id						int             NULL
            , quote_id							int             NULL
			, approval_code						varchar(40)     NULL
            , product_id						int				NULL
            , nam_id							int             NULL
            , nam_user_name						varchar(40)     NULL
            , region_id							int             NULL
            , region_desc						varchar(50)     NULL
            , billing_project_id				int             NULL
            , billing_project_name				varchar(40)     NULL
            , territory_user_name				varchar(40)     NULL
            , territory_desc					varchar(40)     NULL
			, servicecategory_uid				int				NULL
			, service_category_description		varchar(50)		NULL
			, service_category_code				char(1)			NULL
			, businesssegment_uid				int				NULL
			, business_segment_code				varchar(10)		NULL
			, workorder_type_id					int				NULL
			, workorder_type_desc				varchar(40)		NULL
        ) 


if @debug > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '@date var setup finished' as status
set @lasttime = getdate()

-- Step 1. Select everything from Billing that is invoiced for this date range
Insert into #InternalTW
SELECT 
	Billing.billing_uid,
	BillingDetail.billingdetail_uid,
	Billing.invoice_id,
	Billing.invoice_code,
	NULL AS AcctExecID,
	NULL AS AcctExecCode,
	NULL AS AcctExecName,
	Billing.generator_id,
	Billing.generator_name,
	u_nam.user_code AS nam_user_code,
	Billing.service_desc_1,
	----------------------------------
    Billing.company_id,
    Billing.profit_ctr_id,
    Billing.trans_source,
    Billing.Receipt_id,
    Billing.line_id,
    Billing.trans_type,
    Billing.workorder_sequence_id,
    Billing.workorder_resource_item,
    Billing.workorder_resource_type,
    Billing.invoice_date,
    BillingDetail.billing_type,
    BillingDetail.dist_company_id,
    BillingDetail.dist_profit_ctr_id,
    BillingDetail.extended_amt,
	NULL as territory_code,
	'B' as job_type, -- updated later to 'E' for Events 
	NULL as category_reason,
	NULL as category_reason_description,
    Billing.customer_id,
    Customer.cust_name,
    Billing.profile_id,
	NULL AS quote_id,
    Billing.approval_code,
    BillingDetail.product_id
    , CustomerBilling.nam_id
	,u_nam.user_name as nam_user_name
    , CustomerBilling.region_id
	,region.region_desc as region_desc
    , CustomerBilling.billing_project_id
    , CustomerBilling.project_name as billing_project_name
	,null as territory_user_name
	,null as territory_desc
	, NULL servicecategory_uid
	, NULL service_category_description
	, NULL service_category_code
	, NULL businesssegment_uid
	, NULL business_segment_code
	, NULL as workorder_type_id
	, NULL AS workorder_type_desc
FROM Billing WITH (INDEX(idx_invoice_date_territory_rpt))
INNER JOIN BillingDetail WITH (INDEX(idx_billing_uid))
	ON Billing.billing_uid = BillingDetail.billing_uid
INNER JOIN Customer
	ON Billing.customer_id = Customer.customer_ID
INNER JOIN CustomerBilling
	ON Billing.customer_ID = CustomerBilling.customer_id
	AND Billing.billing_project_id = CustomerBilling.billing_project_id
INNER JOIN ProfitCenter
    ON BillingDetail.dist_company_id = ProfitCenter.company_ID
    AND BillingDetail.dist_profit_ctr_id = ProfitCenter.profit_ctr_ID
left outer join CustomerBilling cb2 on cb2.customer_id = Customer.customer_ID AND cb2.billing_project_id = 0
left outer join region on region.region_id = CustomerBilling.region_id
left outer join UsersXEQContact x_nam on x_nam.type_id = CustomerBilling.NAM_id and x_nam.EQcontact_type = 'NAM'
left outer join users u_nam on u_nam.user_code = x_nam.user_code
WHERE  1 = 1
   AND Billing.invoice_date >= @date_from
   AND Billing.invoice_date <= @date_to
   AND Billing.status_code = 'I' 
   AND Billing.void_status = 'F' 
   -- testing ???
   --and billing.billing_uid = 13494334


if @debug > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "In Billing (Workorder), Actual #InternalTW" Population' as status
set @lasttime = getdate()

-----------------------------------------------
-- Step 2. Get Quote ID from WorkOrderHeader for Workorders
UPDATE #InternalTW set
	quote_id = woh.quote_id
FROM #InternalTW b
INNER JOIN WorkOrderHeader woh (nolock)
	ON b.receipt_id = woh.workorder_id
	AND b.company_id = woh.company_id
	AND b.profit_ctr_id = woh.profit_ctr_id
WHERE 1=1
	AND b.quote_id IS NULL
	AND b.trans_source = 'W'
	--AND woh.workorder_status not in ('V', 'X', 'N')
	
--------------------------------------------------				
-- Step 3. Get Quote ID for Receipt records
if @debug > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "In Billing (Receipt), Actual #InternalTW" Population' as status
set @lasttime = getdate()
	
UPDATE #InternalTW set
	quote_id = pqa.quote_id
FROM #InternalTW b
LEFT OUTER JOIN profilequoteapproval pqa (nolock)
	ON b.profile_id = pqa.profile_id
	AND b.company_id = pqa.company_id
	AND b.profit_ctr_id = pqa.profit_ctr_id
WHERE 1=1
	AND b.quote_id IS NULL
	AND b.trans_source = 'R'

if @debug > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "In Billing (Receipt), Actual #InternalTW" Population' as status
set @lasttime = getdate()


/*	

-- In Billing: (Retail) Order Records
if @debug > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting "In Billing (Orders), Actual #InternalTW" Population' as status
set @lasttime = getdate()

-- These are all base anyway. Not updating them.

if @debug > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished "In Billing (Orders), Actual #InternalTW" Population' as status
set @lasttime = getdate()

*/	

----------------------------------------------
-- Step 4. Work Order Group Fix - Adding individual members in place of group summaries.
	-- GROUP FIX
	-- Solution to 'G'roup problem:
	-- Insert the component records of the group from workorderdetail, calculate their prices.  Then remove the group record.
	-- THEN do the surcharge/tax calc... so this actually gets inserted way above here.
	-- FYI there are no 'D'isposal wod records with a group_code, so this is a copy/mod of the E/S/L query above

Insert into #InternalTW
SELECT 
	b.billing_uid,
	b.billingdetail_uid,
	b.invoice_id,
	b.invoice_code,
	NULL AS AcctExecID,
	NULL AS AcctExecCode,
	NULL AS AcctExecName,
	b.generator_id,
	b.generator_name,
	b.nam_user_code,
	b.service_desc_1,
	---------------------------
    b.company_id,
    b.profit_ctr_id,
    b.trans_source,
    b.receipt_id,
	null AS line_id,
	'O' AS trans_type,
    wod.sequence_id workorder_sequence_id,
    wod.resource_class_code workorder_resource_item,
    wod.resource_type workorder_resource_type,
    b.invoice_date,
	'WorkOrder' billing_type,
	b.company_id dist_company_id,
	b.profit_ctr_id dist_profit_ctr_id,
	round(wod.price * coalesce( wodSource.quantity_used, 0),2) as extended_amt,
	NULL territory_code,
	'B' as job_type, -- updated later to 'E' for Events 
	NULL as category_reason,
	NULL as category_reason_description,
    b.customer_id,
    b.cust_name,
    NULL profile_id,
	woh.quote_ID quote_id,
    NULL approval_code,
    NULL product_id
    , b.nam_id
    , b.nam_user_name
    , b.region_id
    , b.region_desc
    , b.billing_project_id
    , b.billing_project_name
    , b.territory_user_name
    , b.territory_desc
	, b.servicecategory_uid
	, b.service_category_description
	, b.service_category_code
	, b.businesssegment_uid
	, b.business_segment_code
	, b.workorder_type_id	
	, b.workorder_type_desc	
FROM #InternalTW b
INNER JOIN WorkOrderHeader woh (nolock)
	on b.receipt_id = woh.workorder_id
	and b.company_id = woh.company_id
	and b.profit_ctr_id = woh.profit_ctr_id
INNER JOIN WorkorderDetail wodSource (nolock) -- Necessary since #InternalTW doesn't store group_code/instance.
	ON woh.workorder_id = wodSource.workorder_id
	AND woh.company_id = wodSource.company_id
	AND woh.profit_ctr_id = wodSource.profit_ctr_id
	AND wodSource.resource_type = 'G'
	AND wodSource.bill_rate > 0
	AND wodSource.extended_price > 0
	AND b.workorder_sequence_id = wodSource.sequence_id
INNER JOIN WorkOrderDetail wod (nolock)
	ON woh.workorder_id = wod.workorder_id
	AND woh.company_id = wod.company_id
	AND woh.profit_ctr_id = wod.profit_ctr_id
	and wod.group_code = wodSource.group_code
	and wod.group_instance_id = wodSource.group_instance_id
	AND wod.resource_type <> 'G'
	AND wod.bill_rate > 0
WHERE 1=1
	and EXISTS (
		SELECT 1
		FROM #InternalTW rw
			where rw.trans_source = 'W'
			and rw.receipt_id = woh.workorder_id
			and rw.company_id = woh.company_id
			and rw.profit_ctr_id = woh.profit_ctr_id
			and rw.workorder_resource_type = 'G'
			and rw.extended_amt > 0
	)
	AND isnull(woh.fixed_price_flag, 'F') = 'F'
	--AND woh.workorder_status not in ('V', 'X', 'N')
	AND b.workorder_resource_type = 'G'
	and b.billing_type = 'Workorder'
		

if @debug > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Work Order Group record components added' as status
set @lasttime = getdate()

-- The individual components of workorder groups have been added now.  Remove the actual group records
DELETE from #InternalTW where workorder_resource_type = 'G' and trans_source = 'W' and billing_type = 'Workorder'


if @debug > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Work Order Group records removed' as status
set @lasttime = getdate()

-------------------------------------------------
-- Step 5. Filtering on transaction type & co pc search logic
if @debug > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'filtering on split facilities after populating with all facilities.' as status
set @lasttime = getdate()

delete from #InternalTW where not exists (
	select 1 from #tmp_copc where company_id = #InternalTW.dist_company_id and profit_ctr_id = #InternalTW.dist_profit_ctr_id
)

if @debug > 0 select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Finished filtering on split facilities after populating with all facilities.' as status
set @lasttime = getdate()


---------------------------------------------------------
-- Step 6. Assign Job Type: Base/Event.
update #InternalTW set job_type = 'B' -- Default	

/* Update Job type to Event on event jobs.  defaulted to "B" since there were so many
null and blank values, retail stays Base */
update #InternalTW set
	job_type = 'E'
from #InternalTW
INNER JOIN profilequoteheader pqh
	ON #InternalTW.quote_id = pqh.quote_id
where pqh.job_type  = 'E' 
and #InternalTW.trans_source = 'R'

update #InternalTW set
	job_type = 'E'
from #InternalTW tw
inner join workorderquoteheader qh
	on tw.quote_id = qh.quote_id
	and tw.company_id = qh.company_id
	and qh.job_type  = 'E' 
where 1=1
And tw.trans_type = 'O'
and tw.trans_source = 'W'

---------------------------------------------------------
-- Step 7. Assign WorkOrder types
update #InternalTW set
	workorder_type_id = WOTH.workorder_type_id
	, workorder_type_desc = WOTH.account_desc
FROM #InternalTW TW
JOIN WorkOrderHeader WOH
	ON WOH.workorder_id = TW.receipt_id
	AND WOH.company_id = TW.company_id
	AND WOH.profit_ctr_id = TW.profit_ctr_id
JOIN WorkOrderTypeHeader WOTH
	ON WOTH.workorder_type_id = WOH.workorder_type_id
WHERE TW.trans_source = 'W'

---------------------------------------------------------
-- Step 8. Assign Service Category & Business Segment values from Products
update #InternalTW set
	servicecategory_uid = p.servicecategory_uid
	, service_category_description = s.service_category_description
	, service_category_code = s.service_category_code
	, category_reason = 1
	, category_reason_description = 'Service category set via product assignment'
from #InternalTW r
inner join product p
	on r.product_id = p.product_id
	-- No company matching. That's deliberate.
	and p.servicecategory_uid is not null
inner join servicecategory s
	on p.servicecategory_uid = s.servicecategory_uid
where 1=1
and r.servicecategory_uid is null
	
update #InternalTW set
	businesssegment_uid = p.businesssegment_uid
	, business_segment_code = b.business_segment_code
from #InternalTW r
inner join product p
	on r.product_id = p.product_id
	-- No company matching. That's deliberate.
	and p.businesssegment_uid is not null
inner join businesssegment b
	on p.businesssegment_uid = b.businesssegment_uid
where 1=1
and r.businesssegment_uid is null

---------------------------------------------------------
-- Step 9. Assign Service Category & Business Segment values from ResourceClasses
update #InternalTW set
	servicecategory_uid = rcd.servicecategory_uid
	, service_category_description = s.service_category_description
	, service_category_code = s.service_category_code
	, category_reason = 2
	, category_reason_description = 'Service category set via resource class assignment'
from #InternalTW r
inner join ResourceClassDetail rcd
	on ltrim(rtrim(r.workorder_resource_item)) = ltrim(rtrim(rcd.resource_class_code))
	and r.company_id = rcd.company_id
	and r.profit_ctr_id = rcd.profit_ctr_id
	and rcd.servicecategory_uid is not null
inner join servicecategory s
	on rcd.servicecategory_uid = s.servicecategory_uid
where 1=1
and r.servicecategory_uid is null

update #InternalTW set
	businesssegment_uid = rcd.businesssegment_uid
	, business_segment_code = b.business_segment_code
from #InternalTW r
inner join ResourceClassDetail rcd
	on ltrim(rtrim(r.workorder_resource_item)) = ltrim(rtrim(rcd.resource_class_code))
	and r.company_id = rcd.company_id
	and r.profit_ctr_id = rcd.profit_ctr_id
	and rcd.businesssegment_uid is not null
inner join businesssegment b
	on rcd.businesssegment_uid = b.businesssegment_uid
where 1=1
and r.businesssegment_uid is null

---------------------------------------------------------
-- Step 10. Update the Service Categories & BusinessSegment from Workorder Disposal
update #InternalTW set 
	servicecategory_uid = dbo.fn_get_disposal_servicecategory_uid( trans_source, company_id, profit_ctr_id, receipt_id, workorder_resource_type, workorder_sequence_id, billing_type)
	, businesssegment_uid = dbo.fn_get_disposal_businesssegment_uid( trans_source, company_id, profit_ctr_id, receipt_id, workorder_resource_type, workorder_sequence_id)
	, category_reason = 3
	, category_reason_description = 'Service category set via work order disposal'
where
	servicecategory_uid is null
	and trans_source = 'W' 
	and trans_type = 'O' 
	and workorder_resource_type = 'D' 

---------------------------------------------------------
-- Step 11. Use a separate reason/description for Third/3rd party waste (it got a businesssegment_uid = 2 (FIS), whereas USE/EQ disposal got a 1 (ES):
update #InternalTW set 
	category_reason = 4
	, category_reason_description = 'Service category set via 3rd party work order disposal'
FROM #InternalTW r
JOIN WorkOrderDetail WOD
	ON WOD.workorder_id = r.receipt_id
	AND WOD.company_id = r.company_id
	AND WOD.profit_ctr_id = r.profit_ctr_id
	AND WOD.resource_type = 'D'
JOIN TSDF T
	ON T.tsdf_code = WOD.tsdf_code
	AND T.use_flag = 'F'
where
	r.businesssegment_uid = 2
	and r.trans_source = 'W' 
	and r.trans_type = 'O' 
	and r.workorder_resource_type = 'D' 
	--and billing_type = 'Disposal' -- 5/8/2015 - per talk with Paul and Lorraine.  JPB.

---------------------------------------------------------
-- Step 12. Update the Service Categories from Receipt Disposal
update #InternalTW set 
	servicecategory_uid = dbo.fn_get_disposal_servicecategory_uid( trans_source, company_id, profit_ctr_id, receipt_id, workorder_resource_type, line_id, billing_type)
	, businesssegment_uid = dbo.fn_get_disposal_businesssegment_uid( trans_source, company_id, profit_ctr_id, receipt_id, workorder_resource_type, line_id)
	, category_reason = 5
	, category_reason_description = 'Service category set via receipt disposal'
where
	servicecategory_uid is null
	and trans_source = 'R' 
	and trans_type IN ('D', 'W') -- Disposal OR Wash - 5/8/2015.
	and product_id is null
	
---------------------------------------------------------
-- Step 13. Work Order w Fixed Price = Service, FIS.
	-- Update the Service Categories from ResourceClasses
	update #InternalTW set
		servicecategory_uid = s.servicecategory_uid
		, service_category_description = s.service_category_description
		, service_category_code = s.service_category_code
		, category_reason = 6
		, category_reason_description = 'Service category set for fixed-price work order'
	from #InternalTW r
	inner join servicecategory s
		on s.service_category_description = 'Services'
	where 1=1
	and r.trans_source = 'W'
	and r.workorder_resource_type = 'H'
	and r.servicecategory_uid is null

	-- Update null business segments on fixed-price work orders.
	update #InternalTW set
		businesssegment_uid = b.businesssegment_uid
		, business_segment_code = b.business_segment_code
	from #InternalTW r
	inner join businesssegment b
		on b.business_segment_code = 'FIS'
	where 1=1
	and r.trans_source = 'W'
	and r.workorder_resource_type = 'H'
	and r.businesssegment_uid is null


---------------------------------------------------------
-- Step 14. Get Business Segment & split % from WorkorderType Detail Split
	--- If the Work Order Type has a business segment assigned, update any rows it applies to, to its own business segment.
	--- If it has more than 1 business segment assigned, create 2 business segment rows & split revenue according to the split_percent.
	---	We will use a new table for this called #InternalTWSplitWOTD
if object_id('tempdb..#InternalTWSplitWOTD') IS NOT NULL
		drop table #InternalTWSplitWOTD

select distinct
	r.billing_uid,
	r.billingdetail_uid,
	r.invoice_id,
	r.invoice_code,
	NULL AS AcctExecID,
	NULL AS AcctExecCode,
	NULL AS AcctExecName,
	r.generator_id,
	r.generator_name,
	r.nam_user_code,
	r.service_desc_1,
	------------------------
	r.company_id							
	, r.profit_ctr_id						
	, r.trans_source						
	, r.receipt_id						
	, r.line_id							
	, r.trans_type						
	, r.workorder_sequence_id				
	, r.workorder_resource_item			
	, r.workorder_resource_type			
	, r.invoice_date						
	, r.billing_type						
	, r.dist_company_id					
	, r.dist_profit_ctr_id				
	--, extended_amt = (r.extended_amt * (isnull(wotd.split_percent, 100) / 100.00))
	, r.extended_amt
	, r.territory_code					
	, r.job_type							
	--,		category_reason	= 7	-- Technically this isn't a service category update like others, it's business segment.
	--,		category_reason_description	= 'Business Segment set via work order type business segment split'
	, r.category_reason
	, r.category_reason_description
	, r.customer_id						
	, r.cust_name							
	, r.profile_id						
	, r.quote_id							
	, r.approval_code						
	, r.product_id						
	, r.nam_id							
	, r.nam_user_name						
	, r.region_id							
	, r.region_desc						
	, r.billing_project_id				
	, r.billing_project_name				
	, r.territory_user_name				
	, r.territory_desc					
	, r.servicecategory_uid				
	, r.service_category_description		
	, r.service_category_code				
	, WOTD.businesssegment_uid
	, b.business_segment_code
	, r.workorder_type_id
	, r.workorder_type_desc				
into #InternalTWSplitWOTD
from #InternalTW r
JOIN WorkOrderTypeDetail WOTD
	ON WOTD.workorder_type_id = r.workorder_type_id
	AND WOTD.company_id = r.company_id
	AND WOTD.profit_ctr_id = r.profit_ctr_id
	AND (WOTD.customer_id IS NULL OR WOTD.customer_id = r.customer_id)
	AND WOTD.status = 'A'
JOIN businesssegment b
	on wotd.businesssegment_uid = b.businesssegment_uid
WHERE
	r.trans_source = 'W'
	and r.workorder_type_id is not null
		
-- Calculate and update split amounts per the WorkOrderTypeDetail on individual rows
UPDATE #InternalTWSplitWOTD
SET extended_amt = (r.extended_amt * (isnull(wotd.split_percent, 100) / 100.00))
FROM #InternalTWSplitWOTD r
JOIN WorkOrderTypeDetail wotd
	ON WOTD.workorder_type_id = r.workorder_type_id
	AND WOTD.company_id = r.company_id
	AND WOTD.profit_ctr_id = r.profit_ctr_id
	AND (WOTD.customer_id IS NULL OR WOTD.customer_id = r.customer_id)
	AND WOTD.businesssegment_uid = r.businesssegment_uid
	AND WOTD.status = 'A'

-- Now Remove lines that were created in #InternalTWSplitWOTD from the normal #InternalTW table.
DELETE from #InternalTW
from #InternalTW r
JOIN WorkOrderTypeDetail WOTD
	ON WOTD.workorder_type_id = r.workorder_type_id
	AND WOTD.company_id = r.company_id
	and WOTD.profit_ctr_id = r.profit_ctr_id
	AND (WOTD.customer_id IS NULL OR WOTD.customer_id = r.customer_id)
	AND WOTD.status = 'A'
	--AND WOTD.businesssegment_uid IS NOT NULL
JOIN businesssegment b
	on wotd.businesssegment_uid = b.businesssegment_uid
WHERE
	r.trans_source = 'W'
	and r.workorder_type_id is not null

-- Re-combine the splits data with the rest of the table
INSERT #InternalTW
SELECT * from #InternalTWSplitWOTD

if object_id('tempdb..#InternalTWSplitWOTD') IS NOT NULL
	drop table #InternalTWSplitWOTD
		

---------------------------------------------------------
-- Step 15. Third Party Trans is to be designated by a distinct category_reason & category_reason_description:
	-- Third Party Trans is where the service category is already Trans and:
	
	--		1a. There is a non-USE/EQ receipt transporter present (TODO: Should it be limited to the last transporter? first? any? Any for now)
UPDATE #InternalTW
SET
	category_reason	= 8	-- Technically this isn't a service category update like others, it's business segment.
	, category_reason_description	= 'Third Party Transportation Present on Receipt'
FROM #InternalTW TW  
inner join ServiceCategory sc
	on tw.servicecategory_uid = sc.servicecategory_uid
	and sc.service_category_description = 'Trans'
inner join ReceiptTransporter r
	on r.receipt_id = tw.receipt_id
	and r.company_id = tw.company_id
	and r.profit_ctr_id = tw.profit_ctr_id
	and tw.trans_source = 'R'
inner join Transporter t
	on r.transporter_code = t.transporter_code
	and isnull(t.use_flag, 'F') = 'F'
where
	isnull(category_reason, 0) <> 8
			
	--		1b. There is a non-USE/EQ workorder transporter present (TODO: Should it be limited to the last transporter? first? any? Any for now)
UPDATE #InternalTW
SET
	category_reason	= 8	-- Technically this isn't a service category update like others, it's business segment.
	, category_reason_description	= 'Third Party Transportation Present on Work Order'
FROM #InternalTW TW  
inner join ServiceCategory sc
	on tw.servicecategory_uid = sc.servicecategory_uid
	and sc.service_category_description = 'Trans'
inner join WorkOrderTransporter r
	on r.workorder_id = tw.receipt_id
	and r.company_id = tw.company_id
	and r.profit_ctr_id = tw.profit_ctr_id
	and tw.trans_source = 'W'
inner join Transporter t
	on r.transporter_code = t.transporter_code
	and isnull(t.use_flag, 'F') = 'F'
where
	isnull(category_reason, 0) <> 8

	--		2. The Work Order does not contain any EQ Equipment Or Labor or Supplies and does not have a USE transporter
UPDATE #InternalTW
SET
	category_reason	= 8	-- Technically this isn't a service category update like others, it's business segment.
	, category_reason_description	= 'Third Party Transportation when Work Order service category is Trans, but no USE Equipment used'
FROM #InternalTW TW  
inner join ServiceCategory sc
	on tw.servicecategory_uid = sc.servicecategory_uid
	and sc.service_category_description = 'Trans'
inner join WorkOrderTransporter r
	on r.workorder_id = tw.receipt_id
	and r.company_id = tw.company_id
	and r.profit_ctr_id = tw.profit_ctr_id
inner join Transporter t
	on r.transporter_code = t.transporter_code
	and isnull(t.use_flag, 'F') = 'F'
WHERE
	tw.trans_source = 'W'
	and not exists ( SELECT 1 FROM Workorderdetail wd
						WHERE tw.receipt_id = wd.workorder_id
						AND tw.profit_ctr_id = wd.profit_ctr_id
						AND tw.company_id = wd.company_id
						AND wd.resource_type in ('E' , 'L', 'S' )
					)
and
	isnull(category_reason, 0) <> 8

---------------------------------------------------------
-- Step 16.  Make Sure disposal servicecategory & businesssegment codes/descriptions are set. 
	update #InternalTW set
		service_category_description = s.service_category_description
		, service_category_code = s.service_category_code
	from #InternalTW r
	inner join ServiceCategory s
		on r.servicecategory_uid = s.servicecategory_uid
	where r.service_category_description is null

	update #InternalTW set
		business_segment_code = b.business_segment_code
	from #InternalTW r
	inner join BusinessSegment b
		on r.businesssegment_uid = b.businesssegment_uid
	where r.business_segment_code is null

---------------------------------------------------------
-- Step 17. Customer Billing Territory percent split over rides all
if object_id('tempdb..#NewTerritoryWork') is not null
	drop table #NewTerritoryWork

select 
	tw.billing_uid
	, tw.billingdetail_uid
	, tw.invoice_id
	, tw.invoice_code
	, AcctExecID = ISNULL(t_u.[user_id], 0) 
	, AcctExecCode = ISNULL(t_u.user_code, '')
	, AcctExecName = ISNULL(t_u.[user_name], '')
	, tw.generator_id
	, tw.generator_name
	, tw.nam_user_code
	, tw.service_desc_1
	-------------------------------------------
	, tw.company_id
	, tw.profit_ctr_id
	, tw.trans_source
	, tw.receipt_id
	, tw.line_id
	, tw.trans_type
	, tw.workorder_sequence_id
	, tw.workorder_resource_item
	, tw.workorder_resource_type
	, tw.invoice_date
	, tw.billing_type
	, tw.dist_company_id
	, tw.dist_profit_ctr_id
	, (tw.extended_amt * (isnull(cbt.customer_billing_territory_percent, 100) / 100.00)) extended_amt
	, isnull(cbt.customer_billing_territory_code, '') territory_code
	, tw.job_type
	, tw.category_reason
	, tw.category_reason_description
	, tw.customer_id
	, tw.cust_name
	, tw.profile_id
	, tw.quote_id
	, tw.approval_code
	, tw.product_id
	, tw.nam_id
	, tw.nam_user_name
	, tw.region_id
	, tw.region_desc
	, tw.billing_project_id
	, tw.billing_project_name
	, territory_user_name = isnull(t_u.user_name, 'No AE set for territory ' + isnull(cbt.customer_billing_territory_code, ''))
	, territory_desc = isnull(t.territory_desc, 'No description set for territory ' + isnull(cbt.customer_billing_territory_code, ''))
	, tw.servicecategory_uid
	, tw.service_category_description
	, tw.service_category_code
	, tw.businesssegment_uid
	, tw.business_segment_code
	, tw.workorder_type_id
	, tw.workorder_type_desc
into #NewTerritoryWork
from #InternalTW tw
left join CustomerBillingTerritory cbt
	on tw.customer_id = cbt.customer_id
	and tw.billing_project_id = cbt.billing_project_id
	and tw.businesssegment_uid = cbt.businesssegment_uid
	and cbt.customer_billing_territory_status = 'A'
	and cbt.customer_billing_territory_type = 'T'
left join UsersXEQContact t_uxe	-- Territory instance of UsersXEQContact join
	on t_uxe.territory_code = cbt.customer_billing_territory_code
	and t_uxe.EQcontact_type = 'AE'
left join Users t_u		-- Territory instance of Users
	on t_u.user_code = t_uxe.user_code 
left join Territory t
	on t.territory_code = cbt.customer_billing_territory_code
	--where tw.workorder_type_id is null
	
	
-- Toss the old TerritoryWork data
delete #InternalTW
	
-- Fill with new split data
insert #InternalTW
select * from #NewTerritoryWork
	
---------------------------------------------------------
-- Step 18.	 WE haven't yet filtered the data for Input parms and have everything for all territories, regions and NAMs
	---	So now filter the results for the user requested AE's, NAMs, regions etc
if isnull(@filter_field, '') not like '%ALL%' begin

	if isnull(@filter_list, '') not like '%ALL%' begin

		if object_id('tempdb..#FilterTerritoryWork') is not null
			drop table #FilterTerritoryWork

		-- Run without filter: 20s. With filter: 55-65s.
		-- Try adding an index on the filtered field first?
			
			declare @oid int
			select @oid = object_id('tempdb..#InternalTW')

			if isnull(@filter_field, '') = 'NAM_ID' and not exists (SELECT * from tempdb.sys.indexes where name = 'idx_NAM_ID' and object_id = @oid)
				create index idx_NAM_ID on #InternalTW (NAM_ID)

			if isnull(@filter_field, '') = 'REGION_ID' and not exists (SELECT * from tempdb.sys.indexes where name = 'idx_REGION_ID' and object_id = @oid)
				create index idx_REGION_ID on #InternalTW (REGION_ID)

			if isnull(@filter_field, '') = 'BILLING_PROJECT_ID' and not exists (SELECT * from tempdb.sys.indexes where name = 'idx_BILLING_PROJECT_ID' and object_id = @oid)
				create index idx_BILLING_PROJECT_ID on #InternalTW (BILLING_PROJECT_ID)
				
			if isnull(@filter_field, '') = 'TERRITORY_CODE' and not exists (SELECT * from tempdb.sys.indexes where name = 'idx_TERRITORY_CODE' and object_id = @oid)
				create index idx_TERRITORY_CODE on #InternalTW (TERRITORY_CODE)

		select
			*
		into #FilterTerritoryWork
		from #InternalTW
		WHERE 1 =
			CASE isnull(@filter_field, '')
				WHEN '' THEN 1
				WHEN 'none' THEN 1
				WHEN 'NAM_ID' THEN
						CASE WHEN isnull(NAM_id, -1) IN (select filter_id from #filter) THEN 1 ELSE 0 END
				WHEN 'REGION_ID' THEN
						CASE WHEN isnull(region_id, -1) IN (select filter_id from #filter) THEN 1 ELSE 0 END
				WHEN 'BILLING_PROJECT_ID' THEN
						CASE WHEN isnull(billing_project_id, -1) IN (select filter_id from #filter) THEN 1 ELSE 0 END
				WHEN 'TERRITORY_CODE' THEN
						CASE WHEN convert(int, IsNull(territory_code, -1)) IN (SELECT filter_id FROM #filter) THEN 1 ELSE 0 END
				ELSE 0
			END

		-- Toss the old TerritoryWork data
		truncate table #InternalTW
			
		-- Fill with new split data
		insert #InternalTW
		select * from #FilterTerritoryWork
	end
end

INSERT #TerritoryWork 
		(
            company_id							
            , profit_ctr_id						
            , trans_source						
            , receipt_id						
            , line_id							
            , trans_type						
            , workorder_sequence_id				
            , workorder_resource_item			
            , workorder_resource_type			
            , invoice_date						
            , billing_type						
            , dist_company_id					
            , dist_profit_ctr_id				
            , extended_amt						
            , territory_code					
            , job_type							
            , category_reason					
            , category_reason_description		
            , customer_id						
            , cust_name							
            , profile_id						
            , quote_id							
			, approval_code						
            , product_id						
            , nam_id							
            , nam_user_name						
            , region_id							
            , region_desc						
            , billing_project_id				
            , billing_project_name				
            , territory_user_name				
            , territory_desc					
			, servicecategory_uid				
			, service_category_description		
			, service_category_code				
			, businesssegment_uid				
			, business_segment_code				
			, workorder_type_id					
			, workorder_type_desc				
        )
SELECT
            company_id							
            , profit_ctr_id						
            , trans_source						
            , receipt_id						
            , line_id							
            , trans_type						
            , workorder_sequence_id				
            , workorder_resource_item			
            , workorder_resource_type			
            , invoice_date						
            , billing_type						
            , dist_company_id					
            , dist_profit_ctr_id				
            , extended_amt						
            , territory_code					
            , job_type							
            , category_reason					
            , category_reason_description		
            , customer_id						
            , cust_name							
            , profile_id						
            , quote_id							
			, approval_code						
            , product_id						
            , nam_id							
            , nam_user_name						
            , region_id							
            , region_desc						
            , billing_project_id				
            , billing_project_name				
            , territory_user_name				
            , territory_desc					
			, servicecategory_uid				
			, service_category_description		
			, service_category_code				
			, businesssegment_uid				
			, business_segment_code				
			, workorder_type_id					
			, workorder_type_desc				
FROM #InternalTW

-------------------------------------------------------------------------
IF object_id('tempdb..#RevenueDetail') is not null BEGIN
	INSERT #RevenueDetail
		(
			billing_uid							
			, billingdetail_uid		
			, invoice_id
			, invoice_code
			, AcctExecID
			, AcctExecCode
			, AcctExecName
			, generator_id
			, generator_name
			, nam_user_code
			, service_desc_1
			-------------------------------
            , company_id						
            , profit_ctr_id						
            , trans_source						
            , receipt_id						
            , line_id							
            , trans_type						
            , workorder_sequence_id				
            , workorder_resource_item			
            , workorder_resource_type			
            , invoice_date						
            , billing_type						
            , dist_company_id					
            , dist_profit_ctr_id				
            , extended_amt						
            , territory_code					
            , job_type							
            , category_reason					
            , category_reason_description		
            , customer_id						
            , cust_name							
            , profile_id						
            , quote_id							
			, approval_code						
            , product_id						
            , nam_id							
            , nam_user_name						
            , region_id							
            , region_desc						
            , billing_project_id				
            , billing_project_name				
            , territory_user_name				
            , territory_desc					
			, servicecategory_uid				
			, service_category_description		
			, service_category_code				
			, businesssegment_uid				
			, business_segment_code				
			, workorder_type_id					
			, workorder_type_desc				
        ) 
	SELECT 
			billing_uid							
			, billingdetail_uid		
			, invoice_id 
			, invoice_code
			, AcctExecID
			, AcctExecCode
			, AcctExecName
			, generator_id
			, generator_name
			, nam_user_code
			, service_desc_1
			-------------------------------
            , company_id						
            , profit_ctr_id						
            , trans_source						
            , receipt_id						
            , line_id							
            , trans_type						
            , workorder_sequence_id				
            , workorder_resource_item			
            , workorder_resource_type			
            , invoice_date						
            , billing_type						
            , dist_company_id					
            , dist_profit_ctr_id				
            , extended_amt						
            , territory_code					
            , job_type							
            , category_reason					
            , category_reason_description		
            , customer_id						
            , cust_name							
            , profile_id						
            , quote_id							
			, approval_code						
            , product_id						
            , nam_id							
            , nam_user_name						
            , region_id							
            , region_desc						
            , billing_project_id				
            , billing_project_name				
            , territory_user_name				
            , territory_desc					
			, servicecategory_uid				
			, service_category_description		
			, service_category_code				
			, businesssegment_uid				
			, business_segment_code				
			, workorder_type_id					
			, workorder_type_desc				
	FROM #InternalTW
END

GO

GRANT EXECUTE ON [dbo].[sp_rpt_territory_calc_ai] TO [COR_USER] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[sp_rpt_territory_calc_ai] TO [EQAI] AS [dbo]
GO

GRANT EXECUTE ON [dbo].[sp_rpt_territory_calc_ai] TO [EQWEB] AS [dbo]
GO


