use plt_ai
go

drop proc if exists sp_report_eqip_flash_detail
go


CREATE PROCEDURE sp_report_eqip_flash_detail
 @date_from   datetime,
 @date_to   datetime,
 @user_code	varchar(20),
 @permission_id int,
 @copc_list  varchar(4000) =  'ALL',
--  @profit_center_region_list varchar(4000) = '', /* select region_name from ProfitCenterRegion */
 @cust_from  varchar(4000) = '0',
 @cust_to  varchar(4000) = '999999999',
 @cust_type_list varchar(4000) = '',
 @cust_category_list varchar(4000) = '',
 @retail_customer_flag char(1) = 'A',	-- 'A'ny, 'T'Retail Only or 'F'Non-Retail Only
 @msg_customer_flag char(1) = 'A',		-- 'A'ny, 'T'MSG Only or 'F'Non-MSG Only
 @d365_project_list varchar(4000) = '',
--@invoiced_included char(1) = 'F',
 @invoice_flag char(1),		/* 'I'nvoiced, 'N'ot invoiced,   or   special subsets of 'N': 'S'ubmitted, 'U'nsubmitted  */
 @source_list varchar(20), /* 'R'eceipt, 'W'orkorder, 'O'rder */
-- @copc_search_type		char(1) = 'T', /* 'T'ransaction facility (native, default) or 'D'istribution facility */
-- @transaction_type		char(1) = 'A' /* 'A'll, 'N'ative only (or Not split), 'S'plit between facilities only */
 @view_mode					char(1) = 'A' /* A, B, C, D, E */
 , @debug int = 0

AS

/*********************************************************************************************
sp_report_eqip_flash_detail_speedtest

	Run sp_rpt_flash_calc and display detailed information for EQIP Un/Invoiced Detail records.

IMPORTANT
	This SP is used downstream in an SSIS package.  Make sure
	that output changes are communicated to SSIS developers.

	For any change, run a sum(extended_amt) BEFORE vs AFTER the changes.
	There should be no change when just adding fields.  Joins will get you.

	sp_help sp_report_eqip_flash_detail

02/01/2012 JPB	Created (well, it was before this, but I don't remember when)
03/16/2012 JDB	Modified to return the link_flag field as the text instead of just the 1-character abbreviation.
07/26/2013 RWB	Added JDE_BU and JDE_object columns
11/13/2013 AM   Added new 2(jde_bu and jde_object) fields to return select.
03/31/2014 AM   GEM:28202 ( sponsored project 28005 ) Added station_id field
11/18/2014 JDB	Replaced station ID field with reference code.
08/04/2015 JPB	Added job_type (Base/Event) field.
09/16/2015 JPB	Added customer_naics_code, generator_naics_code to output
01/24/2017 JPB	GEM:38575  Flash report identifies billing adjustments
				GEM:41123  Flash Report - Add AX Dimension Fields
				GEM:41124  Flash for un-invoiced - filter by status on search criteria
02/01/2018 JPB	GEM:48139  Flash Reports - add Generator Site Type
07/03/2019 JPB	Revert for deploy
07/08/2019 JPB	Somehow Cust_Name and other field length changes got reverted!? cust_name: 40->75. generator_name: 40->75
10/16/2020 JPB	DO:17578 - Add D365 AX string, Truck Code, Manifest. Hiding JDE fields is on SSRS.
11/10/2020 MPM	DevOps 17889 - Added Manage Engine WorkOrderHeader.ticket_number to #FlashWork.
02/14/2022 JPB  Saved @customer table version to match sp_rpt_flash_calc (speedtest version + @customer table)
				Added @cust_category_list input
07/07/2022 JPB	This was the speedtest version.  Speedtest has been removed from naming. It's the new normal version.
02/15/2023 JPB	DO-61642 - add WorkorderDetail Date Of Service to output
02/15/2023 JPB	DO-41810 - add workordertracking fields (status, who, comment)
02/16/2023 JPB	DO-42174 - Add trip ID/status
02/16/2023 JPB	DO-61216 - Add WO.end_date, D365 Customer ID, Region ID, Region Description
02/16/2023 JPB	DO-61218 - Add NAM, NAS
02/16/2023 JPB	DO-62303 - Added input filter on D365 Project Codes, and output field of D365_Project_Code
02/16/2023 JPB	DO-61746 - Add filter on Profitcenter Region: then commented per PK.  Unresolved PC/Region assignments.
02/20/2023 JPB	DO-62353 - Add Resource Project Category and Prevailing Wage Code
04/03/2023 JPB	DO-62857 - Revision of PrevailingWageCode: no more table, just prevailing_wage_code
08/08/2023 JPB	DO-70497 - Column rename CustomerService to Internal_Contact
08/10/2023 JPB	ME-175913 - Add Generator address fields to output
08/11/2023 JPB	DO-70658 - Change to invoice_month
04/08/2024 JPB  DO-81968 - rename FRF fee to EEC in output
04/11/2024 JPB  DO-84570 - Add Retail & MSG Flag inputs
05/07/2024 JPB	DO-86704 - Add WorkorderHeader.project_code to output
07/15/2024 JPB	DO-92840 - Flash Report Bugs: WO Project Code output and *_Flag input
07/31/2024 AM	DevOps:94051 - Modified approval_desc datatype 60 to VARCHAR(100) for #Billing table.
11/27/2024 JPB  DevOps:99932 - Modified string_agg calls for varchar(max) conversions

Examples:

	exec sp_report_eqip_flash_detail '2/1/2020','2/15/2020', 'JONATHAN', 89, '2|0, 3|0, 21|0', 0,999999, '', 'N','R,W', 'A'
	--109999 rows, 7:05 using anitha's raw version.  Arrgh, so confusing.
	--109999 rows, 10:52 using JPB station_id version
	--109999 rows, 9:56 using prod + workstation_id version. WHAT??
	

	exec sp_report_eqip_flash_detail '12/1/2013','12/31/2013', 'JONATHAN', 89, 'ALL', 10673,10673,'I','R,W', 'E'
	--A rows, 13:08 using anitha's raw version.  Arrgh, so confusing.
	--211343 rows, 14:54 using prod + workstation_id version. WHAT??
	--211343 rows, 14:33 using JPB station_id version

	 
	exec sp_report_eqip_flash_detail '1/1/2020','1/12/2020', 'JONATHAN', 89, 'ALL', 0,999999,'','I','R,W', 'E'
	-- 2266 rows
	
select top 100 * from invoiceheader order by invoice_date desc

	exec sp_report_eqip_flash_detail '2/1/2018','2/28/2018', 'JONATHAN', 298, 'ALL', 0, 999999, '*Any*', 'I', 'R,W,O', 'E'

EXEC sp_rpt_flash_calc
	@copc_list			= 'ALL',
	@date_from			= '1/15/2020', --'12/31/2013',
	@date_to			= '1/30/2020', --'10/31/2011',
	@cust_id_from		= 0,
	@cust_id_to			= 999999,
	@cust_type_list		= '*Any*',
	@invoice_flag		= 'S',
	@source_list		= 'R,W,O',		--'R,W,O',
	@copc_search_type	= 'D', /* 'T'ransaction facility (native, default) or 'D'istribution facility */
	@transaction_type	= 'A', /* 'A'll, 'N'ative only (or Not split), 'S'plit between facilities only */
	@debug_flag			= 0


EXEC sp_rpt_flash_calc
	@copc_list			= 'ALL',
	@date_from			= '1/1/2018', --'12/31/2013',
	@date_to			= '1/31/2018 23:59:59', --'10/31/2011',
	@cust_id_from		= 0,
	@cust_id_to			= 999999,
	@cust_type_list		= '*Any*',
	@invoice_flag		= 'I',
	@source_list		= 'R,W,O',		--'R,W,O',
	@copc_search_type	= 'T', /* 'T'ransaction facility (native, default) or 'D'istribution facility */
	@transaction_type	= 'A', /* 'A'll, 'N'ative only (or Not split), 'S'plit between facilities only */
	@debug_flag			= 1


 -- Need some wo's with wod.ds
 -- SELECT  * FROM    workorderdetail where date_service is not null
 --select * from workorderheader where start_date is null
 --and workorder_status NOT IN ('V','X','T')
 --and submitted_flag = 'F' 

-- select * from workorderheader h where
-- h.start_date between '11/1/2022' and '3/30/2023'
-- and workorder_status NOT IN ('V','X','T')
-- and submitted_flag = 'F' 
-- and not exists (
--	select 1 from workorderdetail d
--	WHERE d.workorder_id = h.workorder_id
--	and d.company_id = h.company_id
--	and d.profit_ctr_ID = h.profit_ctr_ID
--)
---- 24505900 (14-0), 30916100 (14-6)


exec sp_report_eqip_flash_detail
 @date_from				= '3/1/2024',
 @date_to				= '5/30/2024',
 @user_code				= 'jonathan',
 @permission_id			= 363,
 @copc_list				= 'ALL',
 @cust_from				= '0',
 @cust_to				= 9999999,
 @cust_type_list		= '*Any*',
 @cust_category_list	= '',
 @retail_customer_flag  = 'A',
 @msg_customer_flag  = 'F',
 @d365_project_list		= '', -- comma works.  space no?
 @invoice_flag			= 'N', /* 'I'nvoiced, 'N'ot invoiced,   or   special subsets of 'N': 'S'ubmitted, 'U'nsubmitted  */
 @source_list			= 'R,W,O', /* 'R'eceipt, 'W'orkorder, 'O'rder */
 @view_mode				= 'A' /* A, B, C, D, E */
-- , @debug = 1

SELECT  TOP 10 *
FROM    ReportLog
ORDER BY report_log_id desc
SELECT  * FROM    ReportLog WHERE  report_log_id = 880701
SELECT  * FROM    ReportLogParameter WHERE report_log_id = 880701

SELECT  *
FROM    #FlashWork

*********************************************************************************************/
BEGIN

/*
declare 
 @date_from   datetime,
 @date_to   datetime,
 @user_code	varchar(20),
 @permission_id int,
 @copc_list  varchar(4000) =  'ALL',
--  @profit_center_region_list varchar(4000) = '', /* select region_name from ProfitCenterRegion */
 @cust_from  varchar(4000) = '0',
 @cust_to  varchar(4000) = '999999999',
 @cust_type_list varchar(4000) = '',
 @cust_category_list varchar(4000) = '',
 @retail_customer_flag char(1) = 'A',
 @msg_customer_flag char(1) = 'A',
 @d365_project_list varchar(4000) = '',
--@invoiced_included char(1) = 'F',
 @invoice_flag char(1),		/* 'I'nvoiced, 'N'ot invoiced,   or   special subsets of 'N': 'S'ubmitted, 'U'nsubmitted  */
 @source_list varchar(4000), /* 'R'eceipt, 'W'orkorder, 'O'rder */
-- @copc_search_type		char(1) = 'T', /* 'T'ransaction facility (native, default) or 'D'istribution facility */
-- @transaction_type		char(1) = 'A' /* 'A'll, 'N'ative only (or Not split), 'S'plit between facilities only */
 @view_mode					char(1) = 'A' /* A, B, C, D, E */
 , @debug int = 0

select  @date_from				= '10/1/2022',
 @date_to				= '3/31/2023',
 @user_code				= 'jonathan',
 @permission_id			= 362,
 @copc_list				= 'ALL',
 @cust_from				= '0',
 @cust_to				= 9999999,
 @cust_type_list		= '*Any*',
 @cust_category_list	= '',
 @d365_project_list		= '',
 @invoice_flag			= 'N', /* 'I'nvoiced, 'N'ot invoiced,   or   special subsets of 'N': 'S'ubmitted, 'U'nsubmitted  */
 @source_list			= 'R,W,O', /* 'R'eceipt, 'W'orkorder, 'O'rder */
 @view_mode				= 'A' /* A, B, C, D, E */
-- , @debug = 1
*/

-- set 	@debug_flag			= 1
drop table if exists #debuglog
create table #debuglog (
	time_now datetime
	, total_elapsed bigint
	, step_elapsed bigint
	, status varchar(4000)
)

declare @timestart datetime = getdate(), @lasttime datetime = getdate()

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Starting Proc' as status
set @lasttime = getdate()


SET NOCOUNT ON

Drop Table If Exists #FlashWork
Drop Table If Exists #FlashWorkBS
Drop Table If Exists #FlashworkTerritory
Drop Table If Exists #Secured_Customer
Drop Table If Exists #ExtendedFlashWork
Drop Table If Exists #output
Drop Table If Exists #tw
Drop Table If Exists #CustFlag


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
		customer_type				varchar(40)	NULL,	--  Customer Type
		cust_category				varchar(30)	NULL,	--	Customer Category

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
		JDE_BU						varchar(7)	NULL,	-- JDE Busines Unite
		JDE_object					varchar(5)	NULL,	-- JDE Object

		AX_MainAccount				varchar(20)	NULL,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
		AX_Dimension_1				varchar(20)	NULL,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
		AX_Dimension_2				varchar(20)	NULL,	-- AX_business_unit
		AX_Dimension_3				varchar(20) NULL,	-- AX_department
		AX_Dimension_4				varchar(20)	NULL,	-- AX_line_of_business
		AX_Dimension_5_Part_1		varchar(20) NULL,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
		AX_Dimension_5_Part_2		varchar(9)	NULL,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
		AX_Dimension_6				varchar(20)	NULL,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
		
		first_invoice_date			datetime	NULL,	-- Date of first invoice
		
		waste_code_uid				int			NULL,
		reference_code              varchar (32) NULL,
		job_type					char(1)		NULL,		-- Base or Event (B/E)
		purchase_order				varchar (20) NULL,
		release_code				varchar (20) NULL,
		ticket_number				int			NULL	-- WorkOrderHeader.ticket_number, for a work order, or for a receipt's linked work order
	)

CREATE TABLE #ExtendedFlashWork (

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
		customer_type				varchar(40)	NULL,	--  Customer Type
		cust_category				varchar(30) NULL,	--	Customer Category

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
		JDE_BU						varchar(7)	NULL,	-- JDE Busines Unite
		JDE_object					varchar(5)	NULL,	-- JDE Object

		AX_MainAccount				varchar(20)	NULL,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
		AX_Dimension_1				varchar(20)	NULL,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
		AX_Dimension_2				varchar(20)	NULL,	-- AX_business_unit
		AX_Dimension_3				varchar(20) NULL,	-- AX_department
		AX_Dimension_4				varchar(20)	NULL,	-- AX_line_of_business
		AX_Dimension_5_Part_1		varchar(20) NULL,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
		AX_Dimension_5_Part_2		varchar(9)	NULL,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
		AX_Dimension_6				varchar(20)	NULL,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
		
		first_invoice_date			datetime	NULL,	-- Date of first invoice
		
		waste_code_uid				int			NULL,
		reference_code              varchar (32) NULL,
		job_type					char(1)		NULL,		-- Base or Event (B/E)
		purchase_order				varchar (20) NULL,
		release_code				varchar (20) NULL,
		ticket_number				int			NULL	-- WorkOrderHeader.ticket_number, for a work order, or for a receipt's linked work order
		,billing_uid				bigint NULL
		,billing_date				datetime NULL
		,workorder_startdate		datetime NULL

	)

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'Temp Tables Created' as status
set @lasttime = getdate()

declare @i_cust_from varchar(max) -- rare case of valid varchar(max) for superlong customer_id lists
set @i_cust_from = @cust_from

if @cust_type_list = '' set @cust_type_list = '*Any*'
if ltrim(rtrim(isnull(@i_cust_from, ''))) = '' set @i_cust_from = '0'
if ltrim(rtrim(isnull(@cust_to, ''))) = '' set @cust_to = '99999999'

if ltrim(rtrim(isnull(@retail_customer_flag, ''))) not in ('A', 'T', 'F') set @retail_customer_flag = 'A'
if ltrim(rtrim(isnull(@msg_customer_flag, ''))) not in ('A', 'T', 'F') set @msg_customer_flag = 'A'

if ((@retail_customer_flag <> 'A' or @msg_customer_flag <> 'A')) and @i_cust_from = '0' begin
	-- If you didn't say 'Any' to the flags, AND if from is just '0' (not a range/specific id, etc)...

	-- Get the list of customer_ids that match the flag conditions specified

	select @i_cust_from = string_agg(convert(varchar(max), customer_id), ',') 
	from customer 
	WHERE  --customer_id between @i_cust_from and @i_cust_to -- can't filter on the from/to here because it could be a range.
	(
		( @retail_customer_flag = 'F' and isnull(retail_customer_flag, '') in ('F','') )
		or
		( @retail_customer_flag = 'T' and isnull(retail_customer_flag, '') in ('T') )
		or
		( @retail_customer_flag = 'A')
	)
	and
	(
		( @msg_customer_flag = 'F' and isnull(msg_customer_flag, '') in ('F','') )
		or
		( @msg_customer_flag = 'T' and isnull(msg_customer_flag, '') in ('T') )
		or
		( @msg_customer_flag = 'A')
	)
	

	-- What if retail flag and msg flag are used in combination?
	-- Does 1 override, do they combine?

end

--select @retail_customer_flag retail_customer_flag, @msg_customer_flag msg_customer_flag
--select datalength(@i_cust_from) as len_i_cust_from, @i_cust_from as i_cust_from


declare @transaction_type char(1), @copc_search_type char(1)
-- @copc_search_type		char(1) = 'T', /* 'T'ransaction facility (native, default) or 'D'istribution facility */
-- @transaction_type		char(1) = 'A' /* 'A'll, 'N'ative only (or Not split), 'S'plit between facilities only */

select @copc_search_type = case @view_mode
	WHEN 'A' then 'T'
	WHEN 'B' then 'T'
	WHEN 'C' then 'T'
	WHEN 'D' then 'D'
	WHEN 'E' then 'D'
	END
	,
	@transaction_type = case @view_mode
	WHEN 'A' then 'A'
	WHEN 'B' then 'S'
	WHEN 'C' then 'N'
	WHEN 'D' then 'S'
	WHEN 'E' then 'A'
	END

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'View Mode Interpreted to Search/Trans Type' as status
set @lasttime = getdate()

drop table if exists #tbl_profit_center_filter	
create table #tbl_profit_center_filter (
	[company_id] int, 
	profit_ctr_id int
)	


if @copc_list <> 'All'
begin
INSERT #tbl_profit_center_filter 
SELECT secured_copc.company_id, secured_copc.profit_ctr_id 
	FROM 
		SecuredProfitCenter secured_copc (nolock)
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

	INSERT #tbl_profit_center_filter
	SELECT secured_copc.company_id
		   ,secured_copc.profit_ctr_id
	FROM   SecuredProfitCenter secured_copc (nolock)
	WHERE  secured_copc.permission_id = @permission_id
		   AND secured_copc.user_code = @user_code 

end

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '@copc_list translated to @tbl_profit_ctr_filter' as status
set @lasttime = getdate()

/* 

2/17/2023 - per PK, commenting this because ProfitCenter/Region assignments are unresolved from stakeholders

-- If a ProfitCenter Region filter was passed, filter the #tbl_profit_center_filter contents with it
if isnull(@profit_center_region_list, '') not in ('', 'All') begin

	delete from #tbl_profit_center_filter
	from #tbl_profit_center_filter f
	join profitcenter p
	on f.company_id = p.company_ID
	and f.profit_ctr_id = p.profit_ctr_ID
	join ProfitCenterRegion r
	on p.profit_center_region_uid = r.profit_center_region_uid
	where r.region_name not in (
		select ltrim(rtrim(value))
		from string_split(@profit_center_region_list, ',')
	)

	insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '@profit_center_region_list filter applied to @tbl_profit_ctr_filter' as status
	set @lasttime = getdate()

end

*/

if @copc_search_type = 'T' begin
	/* If we're only searching where the transaction lives,
		then we can filter the copc list and maybe run for less
		data. But if we were searching for Distributed revenue
		we'd have to run for ALL copcs and filter the RESULTS
		not the input (because revenue could end up distributed
		from another profitcenter than is on the list and you
		couldn't know that until after getting the results)
	*/

	-- at this point, the @copc_list var has been broken into 
	-- #tbl_profit_center_filter rows allowed to the user
	-- so we can re-populate the varchar variable from the table
	-- and send it as input to sp_rpt_flash_calc, which may/should
	-- now be a smaller list than 'All'.

	select @copc_list = substring(
	( select
		', ' + convert(varchar(2),company_id ) + '|' + convert(varchar(2), profit_ctr_id)
		from #tbl_profit_center_filter
		for xml path ('')
	), 2, 20000
	)

	insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '@copc_list remade from #tbl_profit_center_filter' as status
	set @lasttime = getdate()

end

-- select @copc_list copc_list_filtered

/*
	
--CREATE PROCEDURE sp_rpt_flash_calc
-- @copc_list    VARCHAR(MAX),
-- @date_from    DATETIME,
-- @date_to    DATETIME,
-- @cust_id_from   INT,
-- @cust_id_to    INT,
-- @invoice_flag CHAR(1),  /* 'I'nvoiced, 'S'ubmitted, In 'P'rocess */
-- @source_list   VARCHAR(MAX),  /* 'R'eceipt, 'W'orkorder */
-- @debug_flag    INT = 0



select 'exec sp_rpt_flash_calc ' +
 ' @copc_list			= ''' + @copc_list + ''', ' +
'  @date_from			= ''' + convert(varchar(20), @date_from) + ''', ' +
'  @date_to			= ''' + convert(varchar(20), @date_to) + ''', ' +
 ' @cust_id_from		= ''' + convert(varchar(20), @i_cust_from) + ''', ' +
 ' @cust_id_to		= ''' + convert(varchar(20), @cust_to) + ''', ' +
 ' @cust_type_list	= ''' + @cust_type_list + ''', ' +
 ' @invoice_flag		= ''' + @invoice_flag + ''', ' +
 ' @source_list		= ''' + @source_list + ''', ' +
 ' @copc_search_type	= ''' + @copc_search_type + ''', ' +
 ' @transaction_type	= ''' + @transaction_type + ''', ' +
 ' @debug_flag		= 1 '
 
 */

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed
	, left('
exec sp_rpt_flash_calc
 @copc_list			= ''' + @copc_list + ''',
 @date_from			= ''' + convert(varchar(20), @date_from) + ''',
 @date_to			= ''' + convert(varchar(20), @date_to) + ''',
 @cust_id_from		= ''' + @i_cust_from + ''',
 @cust_id_to		= ''' + @cust_to + ''',
 @cust_type_list	= ''' + @cust_type_list + ''',
 -- @cust_category_list = ''' + @cust_category_list + ''',
 @invoice_flag		= ''' + @invoice_flag + ''',
 @source_list		= ''' + @source_list + ''',
 @copc_search_type	= ''' + @copc_search_type + ''',
 @transaction_type	= ''' + @transaction_type + ''',
 @debug_flag		= ''' + convert(varchar(1), @debug) + '''
	;
	', 4000) as status
set @lasttime = getdate()


--sp_helptext sp_rpt_flash_calc
-- insert into #FlashWork
exec sp_rpt_flash_calc
 @copc_list			= @copc_list,
 @date_from			= @date_from,
 @date_to			= @date_to,
 @cust_id_from		= @i_cust_from,
 @cust_id_to		= @cust_to,
 @cust_type_list	= @cust_type_list,
 -- @cust_category_list = @cust_category_list,
 @invoice_flag		= @invoice_flag,  /* 'I'nvoiced, 'S'ubmitted, In 'P'rocess */
 @source_list		= @source_list,  /* 'R'eceipt, 'W'orkorder */
 @copc_search_type	= @copc_search_type,
 @transaction_type	= @transaction_type,
 @debug_flag		= @debug

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'sp_rpt_flash_calc executed' as status
set @lasttime = getdate()

drop table if exists #status_type
create table #status_type
(
	code char(1),
	name varchar(50)
)

INSERT INTO #status_type VALUES ('A', 'Accepted')
INSERT INTO #status_type VALUES ('N', 'New')
INSERT INTO #status_type VALUES ('I', 'Invoiced')
INSERT INTO #status_type VALUES ('L', 'In the Lab')
INSERT INTO #status_type VALUES ('M', 'Manual')
INSERT INTO #status_type VALUES ('R', 'Rejected')
INSERT INTO #status_type VALUES ('T', 'In-Transit')
INSERT INTO #status_type VALUES ('U', 'Unloading')
INSERT INTO #status_type VALUES ('V', 'Void')

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#status_type table created' as status
set @lasttime = getdate()


SELECT DISTINCT customer_id, cust_name INTO #Secured_Customer
	FROM SecuredCustomer sc  (nolock) WHERE sc.user_code = @user_code
	and sc.permission_id = @permission_id		

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#Secured_Customer table created' as status
set @lasttime = getdate()
	

-- filter records that user does not have access to
DELETE FROM #flashwork 
	WHERE NOT EXISTS(SELECT 1 FROM #tbl_profit_center_filter copc
		WHERE #flashwork.company_id = copc.company_id
		AND #flashwork.profit_ctr_id = copc.profit_ctr_id
		union
		SELECT 1 FROM #tbl_profit_center_filter copc
		WHERE #flashwork.dist_company_id = copc.company_id
		AND #flashwork.dist_profit_ctr_id = copc.profit_ctr_id
		)

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#flashwork: removed profit centers not in #tbl_profit_center_filter' as status
set @lasttime = getdate()

		
DELETE FROM #flashwork 
	WHERE NOT EXISTS(SELECT 1 FROM #Secured_Customer sc
		where sc.customer_ID = #flashwork.customer_id )	

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'sp_rpt_flash_calc executed' as status
set @lasttime = getdate()

drop table if exists #d365_project_codes
create table #d365_project_codes (
	project_code	varchar(30)
)
insert #d365_project_codes
select ltrim(rtrim(value)) from string_split(replace(@d365_project_list, ' ', ','), ',')
where len(ltrim(rtrim(value))) > 10 -- in (10,13)

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#d365_project_codes table created/filled' as status
set @lasttime = getdate()



-- --------------------- Business Segment Addition

select *
,		servicecategory_uid			= convert(int, NULL)					-- 3/11/2015 - Adding service category & business segment.
,		service_category_description	= convert(varchar(50), NULL)
,		service_category_code		= convert(char(1), NULL)
,		businesssegment_uid			= convert(int, NULL)
,		business_segment_code		= convert(varchar(10), NULL)
,		customer_billing_territory_code	= convert(varchar(8), NULL)
into #FlashWorkBS
from #FlashWork

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, 'copy+added fields from #flashwork to #flashworkbs' as status
set @lasttime = getdate()


--SELECT  COUNT(*)  FROM    #FlashWork
--SELECT  COUNT(*)  FROM    #FlashWorkBS

		update #FlashWorkBS set
			servicecategory_uid = p.servicecategory_uid
			, service_category_description = s.service_category_description
			, service_category_code = s.service_category_code
			, businesssegment_uid = p.businesssegment_uid
			, business_segment_code = b.business_segment_code
		from #FlashWorkBS r
		inner join product p
			on r.product_id = p.product_id
			-- No company matching. That's deliberate.
			and p.servicecategory_uid is not null
		inner join servicecategory s
			on p.servicecategory_uid = s.servicecategory_uid
		inner join businesssegment b
			on p.businesssegment_uid = b.businesssegment_uid

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#FlashworkBS updated from products' as status
set @lasttime = getdate()
			
		-- Update the Service Categories from ResourceClasses
		update #FlashWorkBS set
			servicecategory_uid = rcd.servicecategory_uid
			, service_category_description = s.service_category_description
			, service_category_code = s.service_category_code
			, businesssegment_uid = rcd.businesssegment_uid
			, business_segment_code = b.business_segment_code
		from #FlashWorkBS r
		inner join ResourceClassDetail rcd
			on ltrim(rtrim(r.workorder_resource_item)) = ltrim(rtrim(rcd.resource_class_code))
			and r.company_id = rcd.company_id
			and r.profit_ctr_id = rcd.profit_ctr_id
			and rcd.servicecategory_uid is not null
		inner join servicecategory s
			on rcd.servicecategory_uid = s.servicecategory_uid
		inner join businesssegment b
			on rcd.businesssegment_uid = b.businesssegment_uid
		where 1=1
		and r.servicecategory_uid is null

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#FlashworkBS updated from resourceclassdetail' as status
set @lasttime = getdate()


		--SELECT  *
		--FROM    #FlashWorkBS -- 147813
		--where servicecategory_uid is null -- 50978

		-- Update the Service Categories from Workorder Disposal
		update #FlashWorkBS set 
			servicecategory_uid = dbo.fn_get_disposal_servicecategory_uid( trans_source, company_id, profit_ctr_id, receipt_id, workorder_resource_type, workorder_sequence_id, billing_type),
			businesssegment_uid = dbo.fn_get_disposal_businesssegment_uid( trans_source, company_id, profit_ctr_id, receipt_id, workorder_resource_type, workorder_sequence_id)
		where
			trans_source = 'W' 
			and trans_type = 'O' 
			and workorder_resource_type = 'D' 

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#FlashworkBS updated from workorder disposal' as status
set @lasttime = getdate()

		-- Update the Service Categories from Receipt Disposal
		update #FlashWorkBS set 
			servicecategory_uid = dbo.fn_get_disposal_servicecategory_uid( trans_source, company_id, profit_ctr_id, receipt_id, workorder_resource_type, line_id, billing_type),
			businesssegment_uid = dbo.fn_get_disposal_businesssegment_uid( trans_source, company_id, profit_ctr_id, receipt_id, workorder_resource_type, line_id)
		where
			trans_source = 'R' 
			and trans_type = 'D' 
			and product_id is null

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#FlashworkBS updated from receipt disposal' as status
set @lasttime = getdate()

		update #FlashWorkBS set
			service_category_description = s.service_category_description
			, service_category_code = s.service_category_code
		from #FlashWorkBS r
		inner join ServiceCategory s
			on r.servicecategory_uid = s.servicecategory_uid
		where r.service_category_description is null

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#FlashworkBS updated from servicecategory' as status
set @lasttime = getdate()

		update #FlashWorkBS set
			business_segment_code = b.business_segment_code
		from #FlashWorkBS r
		inner join BusinessSegment b
			on r.businesssegment_uid = b.businesssegment_uid
		where r.business_segment_code is null

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#FlashworkBS updated from BusinessSegment' as status
set @lasttime = getdate()
		
		update #FlashWorkBS set
			customer_billing_territory_code = cbt.customer_billing_territory_code
		from #FlashWorkBS b
		inner join CustomerBillingTerritory cbt
			on b.customer_id = cbt.customer_id
			and b.billing_project_id = cbt.billing_project_id
			and b.businesssegment_uid = cbt.businesssegment_uid
-- --------------------- Business Segment Addition

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#FlashworkBS updated from CustomerBillingTerritory' as status
set @lasttime = getdate()




SELECT 
	RIGHT('00' + CONVERT(VARCHAR, copc.company_id), 2) + '-' 
	+ RIGHT('00' + CONVERT(VARCHAR, copc.profit_ctr_ID), 2) + ' ' + copc.profit_ctr_name AS profit_ctr_name_with_key
	, copc.Profit_Center_Region_uid
	, pcr.Region_Name as Profit_Center_Region_Name
	,copc.company_id,
	copc.profit_ctr_id,
	case fw.trans_source 
		when 'R' then 'Receipt'
		when 'W' then 'Work Order'
		when 'O' then 'Retail Order'
		else fw.trans_source 
	end as trans_source,
	fw.receipt_id,
	isnull(fw.line_id, fw.workorder_sequence_id) as line_id,
	fw.price_id,
	/*
		case 
			WHEN billing_status_code = 'I' then 'Invoiced'
			WHEN status_type.code = 'A' and submitted_flag = 'T' then 'Accepted & Submitted'
			WHEN status_type.code = 'A' and submitted_flag = 'F' then 'Accepted & Not Submitted'
			ELSE status_type.name 
		end
		as trans_status,
	*/
		fw.status_description as trans_status,

	case fw.trans_type 
		when 'D' then 'Disposal'
		when 'S' then 'Service'
		when 'R' then 'Retail'
		when 'O' then 'Work Order'
		else fw.trans_type
	end as trans_type,
	fw.trans_date,
	fw.pickup_date,
	fw.customer_id,
	fw.cust_name,
	fw.customer_type,
	fw.cust_category,
	customer.cust_naics_code customer_naics_code,
	Customer.ax_customer_id as D365_Customer_ID,

	fw.generator_id,
	fw.generator_name,
	generator.naics_code as generator_naics_code,
	fw.billing_type,
	fw.billing_project_id,
	fw.billing_project_name,
	CustomerBilling.Region_ID as Customer_Region_ID,
	Region.region_desc as Customer_Region_Description,
	fw.territory_code,
	case when fw.submitted_flag = 'T' THEN 'Submitted'
		when fw.submitted_flag = 'F' then 'Not Submitted'
		else fw.submitted_flag
	end as submitted_flag,
	fw.date_submitted,
	fw.submitted_by,
	fw.invoice_code,
	fw.invoice_date,
	fw.invoice_month,
	fw.invoice_year,
	fw.dist_company_id,
	fw.dist_profit_ctr_id,
	fw.gl_account_code,
	fw.bill_unit_code,
	ISNULL(fw.extended_amt, 0) as extended_amt,
	fw.pricing_method,
	fw.workorder_type				, -- WorkOrderType.account_desc
	fw.status_description			, -- Billing/Transaction status description
	fw.ref_line_id					, -- Billing reference line_id (which line does this refer to?)
	fw.workorder_sequence_id		, -- Workorder sequence id
	fw.workorder_resource_item		, -- Workorder Resource Item
	case fw.workorder_resource_type		
		when 'D' then 'Disposal'
		when 'E' then 'Equipment'
		when 'L' then 'Labor'
		when 'O' then 'Other'
		when 'S' then 'Supplies'
		when 'G' then 'Group'
		else fw.workorder_resource_type
	end as workorder_resource_type, -- Workorder Resource Type
	fw.quantity					, -- Receipt/Workorder Quantity
	fw.epa_id						, -- Generator EPA ID
	fw.treatment_id				, -- Treatment ID
	fw.treatment_desc				, -- Treatment's treatment_desc
	td.facility_description		as treatment_facility_description,
	fw.treatment_process_id		, -- Treatment's treatment_process_id
	fw.treatment_process			, -- Treatment's treatment_process (desc)
	fw.disposal_service_id			, -- Treatment's disposal_service_id
	fw.disposal_service_desc		, -- Treatment's disposal_service_desc
	fw.wastetype_id				, -- Treatment's wastetype_id
	fw.wastetype_category			, -- Treatment's wastetype category
	fw.wastetype_description		, -- Treatment's wastetype description
	w.display_name as waste_code					, -- Waste Code
	fw.profile_id					, -- Profile_id
	fw.quote_id					, -- Quote ID
	fw.product_id					, -- BillingDetail product_id, for id'ing fees, etc.
	fw.product_code,
	fw.approval_code				, -- Approval Code
	fw.approval_desc,
	fw.TSDF_code					, -- TSDF Code
	fw.TSDF_EQ_FLAG				, -- TSDF: Is this an EQ tsdf?
	fw.fixed_price_flag			, -- Fixed Price Flag
	fw.quantity_flag		,			-- T = has quantities, F = no quantities, so 0 used.
	fw.invoice_flag,
	fw.dist_flag					,	--	'D', 'N' (Distributed/Not Distributed -- if the dist co/pc is diff from native co/pc, this is D)
	fw.gl_native_code				,	--	GL Native code (first 5 characters)
	fw.gl_dept_code,					--	GL Dept (last 3 characters)
	--fw.link_flag,
	CASE fw.link_flag 
		WHEN 'T' THEN 'Linked'
		WHEN 'F' THEN 'Not Linked'
		WHEN 'E' THEN 'Exempt'
	END AS link_flag,
	fw.linked_record,
	fw.jde_bu,
	fw.jde_object,

	fw.AX_MainAccount				,	-- AX_MainAccount	-- All these AX fields are usually not to allow NULLs
	fw.AX_Dimension_1				,	-- AX_legal_entity	-- But in un-billed work they're not populated yet.
	fw.AX_Dimension_2				,	-- AX_business_unit
	fw.AX_Dimension_3				,	-- AX_department
	fw.AX_Dimension_4				,	-- AX_line_of_business
	fw.AX_Dimension_5_Part_1		,	-- AX_project (technically, AX_Dimension_"6" is displayed before "5")
	fw.AX_Dimension_5_Part_2		,	-- AX_subproject (technically, AX_Dimension_"6" is displayed before "5")
	fw.AX_Dimension_6				,	-- AX_advanced_rule (technically, AX_Dimension_"6" is displayed before "5")
	
	fw.first_invoice_date,
	
	fw.reference_code,
	case fw.job_type when 'E' then 'Event' when 'B' then 'Base' else 'Unknown' end as job_type,
	fw.purchase_order,
	fw.release_code,
	Generator.site_type
	
	, ES_Territory_code = convert(varchar(8), null),
	ES_Salesperson  = convert(varchar(40),  null),
	FIS_Territory_code  = convert(varchar(8),  null),
	FIS_Salesperson  = convert(varchar(40),  null),
	Internal_Contact  = convert(varchar(40), null),
	nam_id = convert(int, null),
	nas_id = convert(int, null),
	NAM   = convert(varchar(40),  null),
	NAS   = convert(varchar(40),  null)
	, convert(varchar(15), null) as manifest
	, convert(varchar(10), null) as truck_code
	, convert(varchar(40), null) as d365_ax_string
	, fw.ticket_number
INTO #FlashworkTerritory
FROM #FlashWorkBS fw
       LEFT JOIN #status_type status_type
         ON fw.trans_status = status_type.code
	LEFT OUTER JOIN wastecode w ON w.waste_code_uid = fw.waste_code_uid
INNER JOIN ProfitCenter copc (nolock)
         ON fw.company_id = copc.company_ID
            AND fw.profit_ctr_id = copc.profit_ctr_ID
LEFT JOIN ProfitCenterRegion pcr
	on copc.profit_center_region_uid = pcr.profit_center_region_uid
LEFT JOIN Customer
	on fw.customer_id = Customer.customer_id
LEFT JOIN Generator
	on fw.generator_id = Generator.generator_id
LEFT JOIN TreatmentDetail td
	on fw.treatment_id = td.treatment_id
	and fw.company_id = td.company_id
	and fw.profit_ctr_id = td.profit_ctr_id
LEFT JOIN CustomerBilling
	on fw.customer_id = CustomerBilling.customer_id
	and fw.billing_project_id = CustomerBilling.billing_project_id
LEFT JOIN Region
	on CustomerBilling.region_id = Region.region_id

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#FlashworkTerritory copy+added from #FlashworkBS' as status
set @lasttime = getdate()


update #FlashworkTerritory set
ES_Territory_code = cbt_es.customer_billing_territory_code 
, ES_Salesperson = t_ue_ae.User_Name
	--, ES_CustomerService = t_ue_cs.User_Name
, FIS_Territory_code = cbt_fis.customer_billing_territory_code
, FIS_Salesperson= t_uf_ae.User_Name
	--, FIS_CustomerService = t_uf_cs.User_Name
, Internal_Contact = t_u_cs.User_Name -- Only one of these, not one per segment.
, nam_id = CBill.nam_id
, nas_id = CBill.nas_id
, NAM = nam_user.user_name
, NAS = nas_user.user_name
from #FlashworkTerritory fw
	LEFT OUTER JOIN CustomerBilling CBill (nolock)
		ON fw.customer_id = CBill.customer_id
		AND fw.billing_project_id = CBill.billing_project_id
	LEFT OUTER JOIN CustomerBillingTerritory cbt_es (nolock)
		ON cBill.customer_id = cbt_es.customer_id
		AND cbill.billing_project_id = cbt_es.billing_project_id
		AND cbt_es.businesssegment_uid = 1
		AND cbt_es.customer_billing_territory_primary_flag = 'T'
		left join UsersXEQContact t_uxe_ae	-- Territory instance of UsersXEQContact join
			on t_uxe_ae.territory_code = cbt_es.customer_billing_territory_code
			and t_uxe_ae.EQcontact_type = 'AE'
		left join Users t_ue_ae		-- Territory instance of Users
			on t_ue_ae.user_code = t_uxe_ae.user_code 
	LEFT OUTER JOIN CustomerBillingTerritory cbt_fis (nolock)
		ON cBill.customer_id = cbt_fis.customer_id
		AND cbill.billing_project_id = cbt_fis.billing_project_id
		AND cbt_fis.businesssegment_uid = 2
		AND cbt_fis.customer_billing_territory_primary_flag = 'T'
		left join UsersXEQContact t_uxf_ae	-- Territory instance of UsersXEQContact join
			on t_uxf_ae.territory_code = cbt_fis.customer_billing_territory_code
			and t_uxf_ae.EQcontact_type = 'AE'
		left join Users t_uf_ae		-- Territory instance of Users
			on t_uf_ae.user_code = t_uxf_ae.user_code 
		left outer join UsersXEQContact t_ux_cs
			on t_ux_cs.type_id = CBill.customer_service_id 
			and t_ux_cs.EQcontact_type = 'CSR'
		left outer join users t_u_cs 
			on t_u_cs.user_code = t_ux_cs.user_code
	left join UsersXEQContact nam_ux	
		on CBill.nam_id = nam_ux.type_id
		and nam_ux.EQcontact_type = 'NAM'
		LEFT JOIN users nam_user
			on nam_ux.user_code = nam_user.user_code
	left join UsersXEQContact nas_ux	
		on CBill.nas_id = nas_ux.type_id
		and nas_ux.EQcontact_type = 'NAS'
		LEFT JOIN users nas_user
			on nas_ux.user_code = nas_user.user_code

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#FlashworkTerritory pdated with territory/cs/nam/nas' as status
set @lasttime = getdate()


update #FlashworkTerritory set
	manifest= coalesce(r.manifest, wd.manifest)
	, truck_code = r.truck_code
	, d365_ax_string = dbo.fn_convert_AX_gl_account_to_D365(
	-- '60145-142-2350-172-5000-120-'
		isnull ( AX_MainAccount, '' ) + '-' 
		+ isnull( AX_Dimension_1,'') + '-' 
		+ isnull( AX_Dimension_2,'') + '-' 
		+ isnull( AX_Dimension_3,'') + '-' 
		+ isnull( AX_Dimension_4,'') + '-' 
		+ isnull( AX_Dimension_6,'') + '-' 
		+ isnull( AX_Dimension_5_part_1,'')
        + case when COALESCE( AX_Dimension_5_part_2,'') <> ''
         then '.' + isnull( AX_Dimension_5_part_2,'')
		 else ''
		 end
 	)
from #FlashworkTerritory f
LEFT JOIN receipt r
	on f.receipt_id = r.receipt_id
	and f.company_id = r.company_id
	and f.profit_ctr_id = r.profit_ctr_id
	and f.line_id = r.line_id
	and f.trans_source = 'Receipt'
LEFT JOIN workorderdetail wd	
	on f.receipt_id = wd.workorder_id
	and f.company_id = wd.company_id
	and f.profit_ctr_id = wd.profit_ctr_id
	and f.line_id = wd.sequence_id
	and f.trans_source = 'Work Order'
	and wd.resource_type = 'D'

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#flashworkterritory updated with manifest, truck code, d365 ax string' as status
set @lasttime = getdate()

drop table if exists #output

SELECT  *  
, convert(int, null) as Corporate_Revenue_Classification_uid
, convert(varchar(40), null) as Corporate_Revenue_Classification_Description
, convert(varchar(50), null) as WorkOrder_Tracking_Status
, convert(varchar(40), null) as WorkOrder_Tracked_To
, convert(varchar(255), null) as WorkOrder_Tracking_Comment
, convert(datetime, null) as WorkOrder_Detail_Service_Date
, convert(int, null) as Trip_ID
, convert(char(1), null) as Trip_Status
, convert(datetime, null) as WorkOrder_EndDate
, convert(varchar(30), null) as D365_Project_Code
, convert(varchar(40), null) as FinanceProjectCategory_Category_ID
, convert(varchar(40), null) as FinanceProjectCategory_Project_Name
, convert(varchar(20), null) as prevailing_wage_code
, convert(varchar(15), null) as WorkOrderProjectCode -- 2024-05-07 DO-86704
/*
the "Tracked To" column will map to WorkOrderTracking.tracking_contact, varchar(10), which will reference column Users.user_code.
the "Comment" column will map to WorkOrderTracking.comment, varchar(255).
sp_columns region
SELECT  * FROM    tripstatus
select o.name, c.name from sysobjects o join syscolumns c on o.id = c.id WHERE  o.xtype = 'u' and c.name like '%trip_status%'
*/
into #output
FROM    #FlashworkTerritory fw

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#output created from #FlashworkTerritory' as status
set @lasttime = getdate()

create index idx1 on #output (receipt_id, company_id, profit_ctr_id, trans_source)

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#output indexed' as status
set @lasttime = getdate()

-- update newly-added fields
Drop Table If Exists #wt

	-- but first, get the workordertracking data to speed the update
	select wt.workorder_id, wt.company_id, wt.profit_ctr_id, max(wt.tracking_id) max_tracking_id
	into #wt
	from workordertracking wt
	join #FlashworkTerritory ft
	on ft.receipt_id = wt.workorder_id
	and ft.company_id = wt.company_id
	and ft.profit_ctr_id = wt.profit_ctr_id
	WHERE ft.trans_source = 'Work Order'
	GROUP BY wt.workorder_id, wt.company_id, wt.profit_ctr_id

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#wt created to optmize workorder tracking updates' as status
set @lasttime = getdate()
	
update o set
	Corporate_Revenue_Classification_uid = h.Corporate_Revenue_Classification_uid
	, Corporate_Revenue_Classification_Description = crc.description
	, WorkOrder_Tracking_Status = wots.Description
	, WorkOrder_Tracked_To = wu.user_name
	, WorkOrder_Tracking_Comment = wt.comment
	, WorkOrder_Detail_Service_Date = wd.date_service
	, Trip_ID = h.trip_id
	, Trip_Status = th.trip_status
	, WorkOrder_EndDate = h.end_date
	, D365_Project_Code = case 
		when (o.AX_Dimension_5_Part_2 is not null and o.AX_Dimension_5_Part_2 <> '' and o.AX_Dimension_5_Part_1 is not null and o.AX_Dimension_5_Part_1 <> '')
			then concat(o.AX_Dimension_5_Part_1, '.', o.AX_Dimension_5_Part_2)
		when (o.AX_Dimension_5_Part_2 is null or o.AX_Dimension_5_Part_2 = '' and o.AX_Dimension_5_Part_1 is not null and o.AX_Dimension_5_Part_1 <> '')
			then o.AX_Dimension_5_Part_1
		when (o.AX_Dimension_5_Part_2 is null or o.AX_Dimension_5_Part_2 = '')
			then ''
	end
	, FinanceProjectCategory_Category_ID = fpc.category_id
	, FinanceProjectCategory_Project_Name = fpc.project_name
	, prevailing_wage_code = wd.prevailing_wage_code
	, WorkOrderProjectCode = h.project_code

from #output o
join WorkorderHeader h
	on o.trans_source = 'Work Order'
	and o.receipt_id = h.workorder_id
	and o.company_id = h.company_id
	and o.profit_ctr_id = h.profit_ctr_id
LEFT JOIN WorkorderDetail wd
	on o.trans_source = 'Work Order'
	and o.receipt_id = wd.workorder_id
	and o.company_id = wd.company_id
	and o.profit_ctr_id = wd.profit_ctr_id
	and left(o.workorder_resource_type,1) = wd.resource_type
	and o.workorder_sequence_id = wd.sequence_id
LEFT JOIN CorporateRevenueClassification crc
	on h.Corporate_Revenue_Classification_uid = crc.Corporate_Revenue_Classification_uid
LEFT JOIN #wt wtkeys
	on o.receipt_id = wtkeys.workorder_id
	and o.company_id = wtkeys.company_id
	and o.profit_ctr_id = wtkeys.profit_ctr_id
LEFT JOIN WorkorderTracking wt
	on wtkeys.workorder_id = wt.workorder_id
	and wtkeys.company_id = wt.company_id
	and wtkeys.profit_ctr_id = wt.profit_ctr_id
	and wtkeys.max_tracking_id = wt.tracking_id
LEFT JOIN WorkorderTrackingStatus wots (nolock)
	on wt.tracking_status = wots.tracking_status
LEFT JOIN users wu
	on wt.tracking_contact = wu.user_code
LEFT JOIN TripHeader th
	on h.trip_id = th.trip_id
	and h.company_id = th.company_id
	and h.profit_ctr_ID = th.profit_ctr_id
LEFT JOIN ResourceClassHeader rch
	on wd.resource_class_code = rch.resource_class_code
	and wd.resource_type = rch.resource_type
LEFT JOIN FinanceProjectCategory fpc
	on rch.finance_project_category_id = fpc.finance_project_category_id
	



insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#output updated with corp rev class, WO tracking, Trip ID, D365 Proj Code' as status
set @lasttime = getdate()
	
update o set
	Corporate_Revenue_Classification_uid = h.Corporate_Revenue_Classification_uid
	, Corporate_Revenue_Classification_Description = crc.description
from #output o
join OrderHeader h
	on o.trans_source = 'Retail Order'
	and o.receipt_id = h.order_id
LEFT JOIN CorporateRevenueClassification crc
	on h.Corporate_Revenue_Classification_uid = crc.Corporate_Revenue_Classification_uid

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#output updated w Retail corp rev class' as status
set @lasttime = getdate()

update o set
	Corporate_Revenue_Classification_uid = r.Corporate_Revenue_Classification_uid
	, Corporate_Revenue_Classification_Description = crc.description
from #output o
join Receipt r
	on o.trans_source = 'Receipt'
	and o.receipt_id = r.receipt_id
	and o.company_id = r.company_id
	and o.profit_ctr_id = r.profit_ctr_id
LEFT JOIN CorporateRevenueClassification crc
	on r.Corporate_Revenue_Classification_uid = crc.Corporate_Revenue_Classification_uid

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#output updated w Receipt corp rev class' as status
set @lasttime = getdate()


if exists (select * from #d365_project_codes where isnull(project_code, '') <> '')
begin

	Drop Table If Exists #OutputProjectFilter

	select * 
	into #OutputProjectFilter
	from #Output
	where D365_Project_Code in (select project_code from #d365_project_codes)

	insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#OutputProjectFilter created to apply d365 project code filter' as status
	set @lasttime = getdate()

	delete from #Output

	insert #Output
	Select * from #OutputProjectFilter

	drop table #OutputProjectFilter

	insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#output repopulated from #OutputProjectFilter' as status
	set @lasttime = getdate()

end

update #output set Billing_Type = 'EEC' where Billing_Type = 'FRF'

select
	o.Company_ID
	, o.Profit_Ctr_Id
	, o.Trans_Source
	, o.Receipt_ID
	, o.Workorder_Resource_Type
	, o.Line_ID
	, o.Price_ID
	, o.Trans_Type
	, o.Workorder_Type
	, o.Trip_ID
	, CASE o.Trip_Status
			WHEN 'N' then 'New'
			WHEN 'D' then 'Dispatched'
			WHEN 'H' then 'Hold'
			WHEN 'V' then 'Void'
			WHEN 'C' then 'Complete'
			WHEN 'A' then 'Arrived'
			WHEN 'U' then 'Unloading'
			ELSE case when o.Trip_ID is not null then 'Unknown' else '' end
		END as Trip_Status
	, o.Trans_Date
	, o.WorkOrder_EndDate
	, o.Pickup_Date
	, o.WorkOrder_Detail_Service_Date
	, o.Link_Flag
	, o.Linked_Record
	, o.Customer_ID
	, o.Cust_Name
	, o.Customer_Type
	, o.Customer_NAICS_Code
	, o.D365_Customer_ID
	, o.Generator_ID
	, o.Generator_Name

	, ltrim(rtrim(isnull(generator_address_1 + ' ', '') 
		+ isnull(generator_address_2 + ' ' , '')
		+ isnull(generator_address_3 + ' ' , '')
		+ isnull(generator_address_4 + ' ' , '')
		+ isnull(generator_address_5 + ' ' , ''))) as Generator_Address
	, g.Generator_State
	, g.Generator_City
	, g.Generator_Zip_Code
	, gc.county_name as Generator_County
	
	, o.EPA_ID
	, o.Generator_NAICS_Code
	, o.Site_Type
	, o.Job_Type
	, o.WorkOrderProjectCode  as  Work_Order_SF_Project  -- New field 5/7/2024
	, o.Billing_Project_ID
	, o.Billing_Project_Name
	, o.Customer_Region_ID			/* fyi, grouped here because it's determined by billing project */
	, o.Customer_Region_Description
	, o.ES_Territory_Code
	, o.ES_Salesperson
	, o.Internal_Contact
	, o.FIS_Territory_Code
	, o.FIS_Salesperson

	, o.NAM as National_Account_Manager
	, o.NAS as National_Account_Specialist

	, o.Trans_Status
	, o.Submitted_Flag
	, o.Date_Submitted
	, o.Submitted_By
	, case when o.invoice_flag = 'T' then 'Invoiced' else 'Not Invoiced' end as Invoice_Flag_Text
	, o.Invoice_Code
	, o.Invoice_Date
	, DateName(month, o.Invoice_Date) Invoice_Month_Name
	, o.Invoice_Year
	, o.First_Invoice_Date
	, case when o.dist_flag = 'd' then 'Distributed' else 'Not Distributed' end as Distribution_Flag
	, o.Dist_Company_ID
	, o.Dist_Profit_Ctr_ID
	, o.Billing_Type
	, o.Fixed_Price_Flag
	, case when o.pricing_method = 'C' then 'Calculated' else 'Actual' end as Pricing_Method_Text
	, case when isnull(o.quantity_flag, '') = 'T' then 'Yes' else 'No' end as Quantity_Flag_Text
	, o.Quantity
	, o.Bill_Unit_Code
	, o.Workorder_Resource_Item
	, o.Treatment_ID
	, o.Treatment_Facility_Description
	, o.Treatment_Desc
	, o.WasteType_Category
	, o.WasteType_Description
	, o.Treatment_Process
	, o.Disposal_Service_Desc
	, o.Approval_Code
	, o.Approval_Desc
	, o.Waste_Code
	, o.Manifest
	, o.Truck_Code
	, o.Product_ID
	, o.Product_Code
	, o.TSDF_Code
	, o.AX_MainAccount
	, o.AX_Dimension_1
	, o.AX_Dimension_2
	, o.AX_Dimension_3
	, o.AX_Dimension_4
	, o.AX_Dimension_6
	, o.AX_Dimension_5_Part_1
	, o.AX_Dimension_5_Part_2
	, o.D365_AX_String
	, o.D365_Project_Code
	, o.Purchase_Order
	, o.Release_Code
	, o.Extended_Amt
	, o.Reference_Code

	
	, o.Corporate_Revenue_Classification_uid
	, o.Corporate_Revenue_Classification_Description
	, o.WorkOrder_Tracking_Status
	, o.WorkOrder_Tracked_To
	, o.WorkOrder_Tracking_Comment

	, o.FinanceProjectCategory_Category_ID
	, o.FinanceProjectCategory_Project_Name
	, o.prevailing_wage_code
	
	, o.profit_ctr_name_with_key
	, o.profit_Center_Region_uid
	, o.Profit_Center_Region_Name

	, o.trans_status
	
	, o.cust_category
	, o.territory_code

	, o.invoice_month

	--, o.gl_account_code
	, o.pricing_method
	, o.status_description
	, o.ref_line_id
	, o.workorder_sequence_id

	, o.treatment_process_id
	, o.disposal_service_id
	, o.wastetype_id

	, o.profile_id
	, o.quote_id

	, o.TSDF_EQ_FLAG

	, o.quantity_flag
	, o.invoice_flag
	, o.dist_flag
	--, gl_native_code
	--, gl_dept_code

	, o.ticket_number
From #Output o
left join Generator g on o.generator_id = g.generator_id
LEFT JOIN County gc on g.generator_county = gc.county_code
ORDER BY 
o.company_id, o.profit_ctr_id, o.receipt_id, o.line_id, o.price_id, 
CASE o.billing_type WHEN 'Disposal' THEN 1
	WHEN 'Wash' THEN 2
	WHEN 'Product' THEN 3
	WHEN 'State-Haz' THEN 4
	WHEN 'State-Perp' THEN 5
	WHEN 'WorkOrder' THEN 6
	WHEN 'Insurance' THEN 7
	WHEN 'Energy' THEN 8
	WHEN 'SalesTax' THEN 9
	WHEN 'Retail' THEN 10
	ELSE 11 END

insert #debuglog select getdate() as time_now, datediff(ms, @timestart, getdate()) as total_elapsed, datediff(ms, @lasttime, getdate()) as step_elapsed, '#output ... output' as status
set @lasttime = getdate()

if @debug = 1 select * from #debuglog order by time_now

END



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_eqip_flash_detail] TO [EQWEB]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_eqip_flash_detail] TO [COR_USER]

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_report_eqip_flash_detail] TO [EQAI]

GO
GRANT EXECUTE ON dbo.sp_report_eqip_flash_detail TO DATATEAM_SVC 
GO

GRANT EXECUTE ON dbo.sp_report_eqip_flash_detail TO EDW_PROD
GO


