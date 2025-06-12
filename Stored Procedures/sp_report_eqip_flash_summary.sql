drop proc if exists sp_report_eqip_flash_summary
go
CREATE PROCEDURE sp_report_eqip_flash_summary
 @date_from   datetime,
 @date_to   datetime,
 @user_code varchar(20),
 @permission_id int,
 @copc_list  varchar(max) =  '2|21, 3|1, 12|0, 12|1, 12|2, 12|3, 12|4, 12|5, 12|7, 14|0, 14|1, 14|2, 14|3, 14|4, 14|5, 14|6, 14|9, 14|10, 14|11, 15|1, 15|2, 15|3, 15|4, 16|0, 17|0, 18|0, 21|0, 21|1, 21|2, 21|3, 22|0, 22|1, 23|0, 24|0, 25|0, 25|2, 25|4, 26|0, 26|2, 27|0, 27|2, 28|0, 29|0',
 @cust_from  int = 0,
 @cust_to  int = 999999999,
 @cust_type_list varchar(max) = '',
 --@invoiced_included char(1) = 'F',
  @status_list varchar(max), /* 'I'nvoiced, 'S'ubmitted, In 'P'rocess */
  @source_list varchar(max) /* 'R'eceipt, 'W'orkorder */
AS

/**********************************************************************************************************************

03/31/2014 AM  GEM:28202 ( sponsored project 28005 )  Added station_id field
11/18/2014 JDB	Replaced station ID field with reference code.
08/05/2015 JPB	Added job_type to #FlashWork table per sp_rpt_flash_calc update
01/08/2016 JPB	Added pickup_date
07/08/2019	JPB	Cust_name: 40->75 / Generator_Name: 40->75
06/16/2023 Devops 65744 -- Nagaraj M Modified the input parameter @copc_list varchar(100) to @copc_list varchar(max)
Usage:
exec sp_report_eqip_flash_summary '1/1/2011','01/31/2011', 'RICH_G', 89, '14|0', 0,99999,'I,S,P','R,W'
**********************************************************************************************************************/
BEGIN

if object_id('tempdb..#FlashWork') is not null drop table #FlashWork

CREATE TABLE #FlashWork (

	--	Header info:
		company_id					int			NULL,
		profit_ctr_id				int			NULL,
		trans_source				char(2)		NULL,	--	Receipt,	Workorder,	Workorder-Receipt,	etc
		receipt_id					int			NULL,	--	Receipt/Workorder	ID
		trans_type					char(1)		NULL,	--	Receipt	trans	type	(O/I)
		link_flag					char(1)		NULL,	--  if R/WO, is this linked to a WO/R? T/F
		linked_record				varchar(255)	NULL,	-- if R, list of WO's linked to (prob. just 1, but multiple poss.)
		workorder_type				varchar(40)	NULL,	--	WorkOrderType.account_desc
		trans_status				char(1)		NULL,	--	Receipt	or	Workorder	Status
		status_description			varchar(40) NULL,	--  Billing/Transaction Status (Invoiced, Billing Validated, Accepted, etc)
		trans_date					datetime	NULL,	--	Receipt	Date	or	Workorder	End	Date
		pickup_date					datetime	NULL,	--  Receipt Pickup Date or Workorder Pickup Date (transporter 1 sign date either way)
		submitted_flag				char(1)		NULL,	--	Submitted	Flag
		date_submitted				datetime	NULL,	--  Submitted Date
		submitted_by				varchar(10)	NULL,	--  Submitted By
		billing_status_code			char(1)		NULL,	--  Billing Status Code
		territory_code				varchar(8)	NULL,	--	Billing	Project	Territory	code
		billing_project_id			int			NULL,	--	Billing	project	ID
		billing_project_name		varchar(40)	NULL,	--	Billing	Project	Name
		invoice_flag				char(1)		NULL,	--  'T'/'F' (Invoiced/Not Invoiced)
		invoice_code				varchar(16)	NULL,	--	Invoice	Code	(if	invoiced)
		invoice_date				datetime	NULL,	--	Invoice	Date	(if	invoiced)
		invoice_month				int			NULL,	--	Invoice	Date	month
		invoice_year				int			NULL,	--	Invoice	Date	year
		customer_id					int			NULL,	--	Customer	ID	on	Receipt/Workorder
		cust_name					varchar(75)	NULL,	--	Customer	Name
		customer_type				varchar(10)	NULL,	--  Customer Type

	--	Detail info:
		line_id						int			NULL,	--	Receipt	line	id
		price_id					int			NULL,	--	Receipt	line	price	id
		ref_line_id					int			NULL,	--	Billing	reference	line_id	(which	line	does	this	refer	to?)
		workorder_sequence_id		varchar(15)	NULL,	--	Workorder	sequence	id
		workorder_resource_item		varchar(15)	NULL,	--	Workorder	Resource	Item
		workorder_resource_type		varchar(15)	NULL,	--	Workorder	Resource	Type
		Workorder_resource_category	Varchar(40)	NULL,	--	Workorder	Resource	Category
		quantity					float		NULL,	--	Receipt/Workorder	Quantity
		billing_type				varchar(20)	NULL,	--	'Energy',	'Insurance',	'Salestax'	etc.
		dist_flag					char(1)		NULL,	--	'D', 'N' (Distributed/Not Distributed -- if the dist co/pc is diff from native co/pc, this is D)
		dist_company_id				int			NULL,	--	Distribution	Company	ID	(which	company	receives	the	revenue)
		dist_profit_ctr_id			int			NULL,	--	Distribution	Profit	Ctr	ID	(which	profitcenter	receives	the	revenue)
		gl_account_code				varchar(12)	NULL,	--	GL	Account	for	the	revenue
		gl_native_code				varchar(5)	NULL,	--	GL Native code (first 5 characters)
		gl_dept_code				varchar(3)	NULL,	--	GL Dept (last 3 characters)
		extended_amt				float			NULL,	--	Revenue	amt
		generator_id				int			NULL,	--	Generator	ID
		generator_name				varchar(75)	NULL,	--	Generator	Name
		epa_id						varchar(12)	NULL,	--	Generator	EPA	ID
		treatment_id				int			NULL,	--	Treatment	ID
		treatment_desc				varchar(32)	NULL,	--	Treatment's	treatment_desc
		treatment_process_id		int			NULL,	--	Treatment's	treatment_process_id
		treatment_process			varchar(30)	NULL,	--	Treatment's	treatment_process	(desc)
		disposal_service_id			int			NULL,	--	Treatment's	disposal_service_id
		disposal_service_desc		varchar(20)	NULL,	--	Treatment's	disposal_service_desc
		wastetype_id				int			NULL,	--	Treatment's	wastetype_id
		wastetype_category			varchar(40)	NULL,	--	Treatment's	wastetype	category
		wastetype_description		varchar(60)	NULL,	--	Treatment's	wastetype	description
		bill_unit_code				varchar(4)	NULL,	--	Unit
		waste_code					varchar(4)	NULL,	--	Waste	Code
		profile_id					int			NULL,	--	Profile_id
		quote_id					int			NULL,	--	Quote	ID
		product_id					int			NULL,	--	BillingDetail	product_id,	for	id'ing	fees,	etc.
		product_code				varchar(15)	NULL,	-- Product Code
		approval_code				varchar(40)	NULL,	--	Approval	Code
		approval_desc				varchar(100) NULL,
		TSDF_code					Varchar(15)	NULL,	--	TSDF	Code
		TSDF_EQ_FLAG				Char(1)		NULL,	--	TSDF:	Is	this	an	EQ	tsdf?
		fixed_price_flag			char(1)		NULL,	--	Fixed	Price	Flag
		pricing_method				char(1)		NULL,	--	Calculated,	Actual,	etc.
		quantity_flag				char(1)		NULL,	--	T	=	has	quantities,	F	=	no	quantities,	so	0	used.
		JDE_BU						varchar(7)	NULL,
		JDE_object					varchar(5),
		waste_code_uid				int	NULL,
		reference_code              varchar(32) NULL,
		job_type					char(1) NULL,		-- Base or Event (B/E)
		purchase_order				varchar (20) NULL,
		release_code				varchar (20) NULL
	)

--CREATE PROCEDURE sp_rpt_flash_calc
-- @copc_list    VARCHAR(MAX),
-- @date_from    DATETIME,
-- @date_to    DATETIME,
-- @cust_id_from   INT,
-- @cust_id_to    INT,
-- @status_list   VARCHAR(MAX),  /* 'I'nvoiced, 'S'ubmitted, In 'P'rocess */
-- @source_list   VARCHAR(MAX),  /* 'R'eceipt, 'W'orkorder */
-- @debug_flag    INT = 0

--sp_helptext sp_rpt_flash_calc_test
insert into #FlashWork
exec sp_rpt_flash_calc
 @copc_list   = @copc_list,
 @date_from   = @date_from,
 @date_to   = @date_to,
 @cust_id_from   = @cust_from,
 @cust_id_to   = @cust_to,
 @cust_type_list = @cust_type_list,
 --@invoiced_included = @invoiced_included,
 @status_list   = @status_list,  /* 'I'nvoiced, 'S'ubmitted, In 'P'rocess */
 @source_list   = @source_list,  /* 'R'eceipt, 'W'orkorder */
 @debug_flag = 0
 
 
-- SELECT * FROM #FlashWork

declare @status_type table
(
	code char(1),
	name varchar(50)
)

INSERT INTO @status_type VALUES ('A', 'Accepted')
INSERT INTO @status_type VALUES ('N', 'New')
INSERT INTO @status_type VALUES ('I', 'Invoiced')
INSERT INTO @status_type VALUES ('L', 'In the Lab')
INSERT INTO @status_type VALUES ('M', 'Manual')
INSERT INTO @status_type VALUES ('R', 'Rejected')
INSERT INTO @status_type VALUES ('T', 'In-Transit')
INSERT INTO @status_type VALUES ('U', 'Unloading')
INSERT INTO @status_type VALUES ('V', 'Void')



SELECT DISTINCT customer_id, cust_name INTO #Secured_Customer
	FROM SecuredCustomer sc WHERE sc.user_code = @user_code
	and sc.permission_id = @permission_id		
	
declare @tbl_profit_center_filter table (
	[company_id] int, 
	profit_ctr_id int
)	


if @copc_list <> 'All'
begin
INSERT @tbl_profit_center_filter 
SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
	FROM 
		SecuredProfitCenter secured_copc
	INNER JOIN (
		SELECT 
			RTRIM(LTRIM(SUBSTRING(row, 1, CHARINDEX('|',row) - 1))) company_id,
			RTRIM(LTRIM(SUBSTRING(row, CHARINDEX('|',row) + 1, LEN(row) - (CHARINDEX('|',row)-1)))) profit_ctr_id
		from dbo.fn_SplitXsvText(',', 0, @copc_list) 
		where isnull(row, '') <> '') selected_copc ON secured_copc.company_id = selected_copc.company_id AND secured_copc.profit_ctr_id = selected_copc.profit_ctr_id
		and secured_copc.permission_id = @permission_id
		and secured_copc.user_code = @user_code
end		
else
begin

INSERT @tbl_profit_center_filter
SELECT secured_copc.company_id
       ,secured_copc.profit_ctr_id
FROM   SecuredProfitCenter secured_copc
WHERE  secured_copc.permission_id = @permission_id
       AND secured_copc.user_code = @user_code 
end

-- filter records that user does not have access to
DELETE FROM #flashwork 
	WHERE NOT EXISTS(SELECT 1 FROM @tbl_profit_center_filter copc
		WHERE #flashwork.company_id = copc.company_id
		AND #flashwork.profit_ctr_id = copc.profit_ctr_id)
		
DELETE FROM #flashwork 
	WHERE NOT EXISTS(SELECT 1 FROM #Secured_Customer sc
		where sc.customer_ID = #flashwork.customer_id )		




SELECT 
RIGHT('00' + CONVERT(VARCHAR, copc.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR, copc.profit_ctr_ID), 2) + ' ' + copc.profit_ctr_name AS profit_ctr_name_with_key,
copc.company_id,
copc.profit_ctr_id,
case when trans_source = 'R' then 'Receipt'
when trans_source = 'W' then 'Work Order'
else trans_source
end as trans_source,
	case 
		WHEN billing_status_code = 'I' then 'Invoiced'
		WHEN status_type.code = 'A' and submitted_flag = 'T' then 'Accepted & Submitted'
		WHEN status_type.code = 'A' and submitted_flag = 'F' then 'Accepted & Not Submitted'
		ELSE status_type.name 
	end	as trans_status,
customer_id,
cust_name,
customer_type,
generator_id,
generator_name,
billing_type,
billing_project_id,
billing_project_name,
bill_unit_code,
fw.gl_account_code,
SUM(ISNULL(extended_amt,0)) as extended_amt,
fw.reference_code,
case fw.job_type when 'E' then 'Event' when 'B' then 'Base' else 'Unknown' end as job_type
FROM #FlashWork fw
       LEFT JOIN @status_type status_type
         ON trans_status = status_type.code
INNER JOIN ProfitCenter copc
         ON fw.company_id = copc.company_ID
            AND fw.profit_ctr_id = copc.profit_ctr_ID
GROUP BY
copc.profit_ctr_name,
gl_account_code,
copc.company_id,
copc.profit_ctr_id,
trans_source,
trans_status,
customer_id,
cust_name,
customer_type,
generator_id,
generator_name,
billing_type,
billing_project_id,
billing_project_name,
bill_unit_code,
reference_code,
status_type.name,
	case 
		WHEN billing_status_code = 'I' then 'Invoiced'
		WHEN status_type.code = 'A' and submitted_flag = 'T' then 'Accepted & Submitted'
		WHEN status_type.code = 'A' and submitted_flag = 'F' then 'Accepted & Not Submitted'
		ELSE status_type.name 
	end
order by 		case 
		WHEN billing_status_code = 'I' then 'Invoiced'
		WHEN status_type.code = 'A' and submitted_flag = 'T' then 'Accepted & Submitted'
		WHEN status_type.code = 'A' and submitted_flag = 'F' then 'Accepted & Not Submitted'
		ELSE status_type.name 
	end	
	, copc.company_id, copc.profit_ctr_id   
/*
SELECT
  fw.company_id
  ,fw.profit_ctr_id
  ,RIGHT('00' + CONVERT(VARCHAR, copc.company_id), 2) + '-' + RIGHT('00' + CONVERT(VARCHAR, copc.profit_ctr_ID), 2) + ' ' + copc.profit_ctr_name AS profit_ctr_name_with_key
  ,fw.customer_id
  ,fw.cust_name
  ,fw.gl_account_code
  ,status_type.name AS trans_status
  ,fw.product_id
  ,p.DESCRIPTION AS product_description
  ,CASE
     WHEN fw.trans_type = 'S' THEN 'Service'
     WHEN fw.trans_type = 'D' THEN 'Disposal'
   END AS trans_type
  --,fw.trans_status
  ,CASE
     WHEN fw.submitted_flag = 'T' THEN 'Submitted'
     WHEN fw.submitted_flag = 'F' THEN 'Not Submitted'
   END AS submitted_flag
  ,fw.billing_project_id
  ,fw.billing_project_name
  ,fw.territory_code
  ,fw.generator_id
  ,fw.generator_name
  ,fw.invoice_code
  ,fw.invoice_date
  ,sum(fw.extended_amt) AS extended_amt
FROM   #flashwork fw
       --LEFT JOIN Receipt r ON fw.receipt_id = r.receipt_id
       --	and fw.company_id = r.company_id
       --	and fw.profit_ctr_id = r.profit_ctr_id
       --	and fw.line_id = r.line_id
       LEFT JOIN @status_type status_type
         ON fw.trans_status = status_type.code
       LEFT JOIN Product p
         ON fw.product_id = p.product_id
       INNER JOIN ProfitCenter copc
         ON fw.company_id = copc.company_ID
            AND fw.profit_ctr_id = copc.profit_ctr_ID
GROUP  BY
  fw.customer_id
  ,fw.cust_name
  ,fw.gl_account_code
  ,status_type.name
  ,fw.product_id
  ,p.DESCRIPTION
  ,fw.trans_type
  ,fw.submitted_flag
  ,fw.billing_project_id
  ,fw.billing_project_name
  ,fw.territory_code
  ,fw.generator_id
  ,fw.generator_name
  ,fw.invoice_code
  ,fw.invoice_date
  ,copc.company_id
  ,copc.profit_ctr_id
  ,copc.profit_ctr_name
  ,fw.company_id
  ,fw.profit_ctr_id 
--SELECT * FROM #FlashWork
*/

END


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_eqip_flash_summary] TO [EQWEB]
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_eqip_flash_summary] TO [COR_USER]



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_eqip_flash_summary] TO [EQAI]

