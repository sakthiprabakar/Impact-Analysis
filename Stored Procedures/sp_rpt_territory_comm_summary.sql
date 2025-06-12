CREATE PROCEDURE   [dbo].[sp_rpt_territory_comm_summary]
	@date_from		datetime
,	@date_to		datetime
,	@copc_list		varchar(max)	
,	@filter_field	varchar(20)
,	@filter_list	varchar(max)
,	@debug			int
AS
/*********************************************************************************************************************
PB object(s):	r_customer_territory_summary (Commissionable Sales Summary by Customer and AE)
				r_customer_territory_summary (Commissionable Sales Summary by Customer and NAM)
				r_customer_territory_summary (Commissionable Sales Summary by Customer and Region)

03/06/2014 AM	Created  - This function returns summary of the territory sales information.
				It specifically excludes non-commissionable records.
08/21/2014 AM   Modified results to get dist_company_id instead of company_id. So that wat all commissions reports will be in sink.
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(500) to @copc_list varchar(max)

EXECUTE sp_rpt_territory_comm_summary
	  @date_from = '01-10-2014'
	  , @date_to = '01-15-2014'
	  , @copc_list='ALL'
	  , @filter_field = 'NAM_ID'
	  , @filter_list = '00, 01'
	  ,  @debug = 0
	  
EXECUTE sp_rpt_territory_comm_summary
	  @date_from = '01-10-2014'
	  , @date_to = '01-15-2014'
	  , @copc_list='ALL'
	  , @filter_field = 'REGION_ID'
	  , @filter_list = 'All'
	  ,  @debug = 0
*********************************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

CREATE TABLE #tmp_sales_detail (
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
CREATE TABLE #tmp_sales_detail_result (
	dist_company_id				int				NULL,
	customer_id					int				NULL,
	cust_name					varchar(75)		NULL,
	extended_amt				float 			NULL,	
	territory_code              varchar(20)		NULL,
	territory_desc				varchar(40)		NULL, 
	territory_user_name			varchar(40)		NULL,
	nam_user_name				varchar(40)		NULL,
	region_desc  				varchar(40)		NULL,
	base_amt					float 			NULL,
	event_amt					float 			NULL,
	total_amt					float 			NULL
) 
INSERT  #tmp_sales_detail
	EXECUTE dbo.sp_rpt_territory_detail @date_from, @date_to, @copc_list, @filter_field, @filter_list, @debug 
  
-- Delete non-commissionable records
DELETE FROM #tmp_sales_detail WHERE ISNULL(commissionable_flag, 'T') = 'F'
  
INSERT  #tmp_sales_detail_result
SELECT 
	t.dist_company_id,
	t.customer_id,
	t.cust_name,
	t.extended_amt,
	( CASE WHEN LOWER(@filter_field) = 'territory_code' THEN t.territory_code
		   WHEN LOWER(@filter_field) = 'nam_id' THEN  t.nam_user_name 
		   WHEN LOWER(@filter_field) = 'region_id' THEN  t.region_desc
		   ELSE  t.territory_code   
	  END) AS territory_code,
	t.territory_desc,
	t.territory_user_name, 
	t.nam_user_name,
	t.region_desc,
	( Case when t.job_type = 'B' then t.extended_amt
			else 0.00 
	 end ) AS base_amt,
	( Case when t.job_type = 'E' then t.extended_amt
			else 0.00 
	 end ) AS event_amt,
	 0.00  as total_amt
FROM #tmp_sales_detail t
  
   
SELECT dist_company_id,
	customer_id,
	cust_name, 
	ISNULL(territory_code, '(Unassigned)') AS territory_code,
	ISNULL(territory_desc, '(Unassigned)') AS territory_desc,
	ISNULL(territory_user_name, '(Unassigned)') AS territory_user_name,
	ISNULL(nam_user_name,'(Unassigned)') AS nam_user_name,
	ISNULL(region_desc, '(Unassigned)') AS region_desc,
	SUM(base_amt) AS base_amt,
	SUM(event_amt) AS event_amt,
	SUM(base_amt + event_amt) AS total_amt
FROM #tmp_sales_detail_result
GROUP BY 
	dist_company_id,
	customer_id,
	cust_name, 
	territory_code,
	territory_desc,
	territory_user_name,
	nam_user_name,
	region_desc

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_territory_comm_summary] TO [EQAI]
    AS [dbo];

