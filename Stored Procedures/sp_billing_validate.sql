
DROP PROCEDURE [dbo].[sp_billing_validate]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[sp_billing_validate]
	@debug			int,
	@validate_date	datetime,
	@user_code		varchar(10)
AS
/***************************************************************************************
Validates Billing Records for Invoicing

Filename:	L:\IT Apps\SQL-Deploy\Prod\NTSQL1\Plt_AI\Procedures\sp_billing_validate.sql
PB Object(s):	d_billing_validate

LOAD TO PLT_AI

This stored procedure inserts billing records with validation results into the 
work_BillingValidate table which is used to communicate between the screen and the 
validation SPs.  The work_BillingValidate table contains control variables used to
populate the Results Treeview on the w_invoice_processing screen. 

The treeview needs to be controlled to prevent the user from selecting
billing lines with errors to be accepted for invoicing.  Since the treeview is a structure
of levels, it's a lot easier to set the ability to check/uncheck a level in this SP
than when building the structure.  These control variables are:
	treeview_customer_check		controls checking/unchecking at the customer level
	treeview_facility_check		controls checking/unchecking at the facility level
	treeview_billing_line_check	controls checking/unchecking at the detail level
and the values can be:	
	0 - can never be checked
	1 = OK to check
	2 = Initialize as checked

Because a single billing line may have multiple errors or warnings, there are variables to
control a group of result lines.  Those variables are:
	record_id		identifies a group of validation errors/warnings per line
	sort_order		always sort errors first, then warnings, then accepted
	validate_date		a whole session for loading, selecting, and validating 
				is controlled by this date
	validate_status		E=Error, W=Warning, A=Accepted
	item_checked		Identifies billing records with warnings and/or 
				A=Accepted status that have been selected to Accept for Invoicing
	billing_line_count	The actual number of billing lines, used on the report for 
				summarizing, count = 1 for this first validation line only
	validate_message	What the problem is.

The min_line column lets us report on the workorder as a whole instead of line-by-many-many-lines

03/13/2007 SCC	Created
05/03/2007 SCC	PO/Scan Requirement for scanned documents removed
05/07/2007 SCC	Removed COD_sent check
05/14/2007 SCC	Separated checks for PO and Release
06/28/2007 SCC	Changes to support Additions to Spec
11/21/2007 SCC	Increment billing_line_count ONLY when a SELECT from real db tables inserts a record
11/21/2007 SCC	Had validation error for contact with valid address because the logic was reversed on
				what caused an error but the check was still looking for a zero result
02/18/2008 WAC	If billing_link_id IS NOT NULL for a transaction then we always need to 
				execute sp_billing_validate_receipt_wo regardless of the values of the 
				source fields.  In addition, more parameters were added to 
				sp_billing_validate_receipt_wo so that the procedure is able to
				properly handle workorder billing links which have NULLs in the source*
				fields of the billing record.
04/24/2008 RG	Changed the default value for db_type from '' to 'PROD' to fix a problem 
                with calling sp_billing_validate_receipt_wo
05/01/2008 WAC	Changed to accomodate Retail orders
05/05/2008 KAM	Updated to skip parts of validation for retail orders
05/08/2008 RG	Modified for changed in the way this procedure calls sp_billing_validate_receipt_wo
05/30/2008 JDB	Added call to new procedure eqsp_billing_validate_walmart
07/09/2008 RG	Removed verbage in fron tof link errors to make them less wordy
07/17/2008 JDB	Removed source fields from Billing table
08/01/2008 JDB	Moved the call to eqsp_billing_validate_walmart nearer the bottom so it's
				only called once.
08/12/2008 JDB	Removed call to eqsp_billing_validate_walmart
12/30/2008 JDB	Removed requirement of having a contact with distribution method of UPS or mail.
03/13/2009 KAM	Updated the load into work_Billing to only load the extended price onto the first
 					row for each billing row.
11/02/2010 JDB	Reversed previous change on 3/13/09 so that total_extended_amt is loaded on each line.
				Also updated d_billing_validate_report so that it only counts the amount once per line.
06/03/2013 JDB	Added billing_uid to #billing table.
				Modified to check for invalid JDE GL Accounts.
02/24/2014 RWB	Validation of JDE GL Accounts was joining on JDE.EQFinance.dbo.JDEGLAccountMaster_F0901
				with a COLLATE, which took exponentially more time. Populated data into a temp table at
				the beginning of procedure and modified validation to check against it instead.
06/17/2016 SK	Added check for CustomerBilling ebilling flag
02/23/2017 AM   commented AX_Project_Required_Flag logic since we are not using anymore. commented WorkOrderTypeDetail and workorderheader join to.
02/23/2017 RB   Modified #axacct logic to add not exists in sub select when calling fnValidateFinancialDimension service call.
01/31/2018 MPM	Modified to populate work_BillingValidate.currency_code.
06/06/2018 RWB	GEM:51147 - Move population of temp table from JDE, but actually comment out references to JDE since JDE Test was deleted
01/15/2019 RWB	GEM-57612 Add ability to connect to new MSS 2016 servers (removed ORDER BYs when inserting into temp tables)
12/04/2019 MPM	DevOps 12690 - Added "SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED" to the top of the sp in an attempt to avoid blocking.
12/11/2019 AM   DevOPs:12961 - Modified code not to call fnValidateFinancialDimension.
04/06/2021 MPM	DevOps 19273 - Removed the "internal review required" validation warning.
05/10/2021 AM   DevOPs:19274 - Added #all_linked and #final_linked tables. Created #final_linked to create group for powerbuilder report. 
						per devops tickets user's wants to see the entire data in xlsx. In PB if i create sub report for links then data don't save in xlsx. 
						so created temp table and grp it in sp to get need data to save in xlsx	
08/28/2021 AM  DevOps:21203 - Uncommented TRUNCATE TABLE #link_errors.
01/25/2022 MPM	DevOps 21208 - Corrected billing link validation date issues and added debugging statements.
07/26/2022 AGC DevOps 19274 - comment out join to #link_errors in final Select statement since #link_errors is truncated before every call 
                              to sp_billing_validate_links, add work order type desc for the transaction itself, not linked transaction
09/13/2022 AGC DevOps 39048 - only call sp_billing_validate_links if @receipt_id is in BillingLinkLookup table
09/27/2022 AGC DevOps 39048 - commented out if logic to only call sp_billing_validate_links if record exists in BillingLinkLookup table.
                              this prevented the the link_required flag from being checked.
02/27/2023 AM  DevOps:49556 - Added new validation messages based on Contact and ContactXRef status.
10/27/2023 Kamendra Devops:42742 - Created Primary key on #billing(record_id).
								   Created idx_tmp_billing_process_flag, idx_tmp_validate_record_id and idx_tmp_axacct_ci on #billing,
								   #validate and #axacct temp tables respectively.Changed MIN(record_id) to be TOP 1 record_id from #billing
								   as now we have a clustered index created on this.
12/1/2023 AM DevOps:75088 - Modified code from TOP 1 record_id MIN(record_id) record id. This is causing an issue to validate bulk records since we are not using order.
		  OE DevOps 75088  - changed the datatype of record id column to bigint

12/27/2023 - Kamendra - CHG0067766 - Increased width for contact_fax from 10 to 20
01/22/2024 - Kamendra - DevOps #76511 - Commented declaration and poplation of @source_company_id, @source_profit_ctr_id and @source_id variables as
				we don't use these variables anymore.
01/03/2025 - Prakash - Rally # DE34310 - Corrected BillingDetail UNION join to get correct billing records.

sp_billing_validate 1, '2017-01-04', 'ANITHA_M'
sp_billing_validate 1, '2017-01-17', 'ANITHA_M'
exec sp_billing_validate 1, '2014-11-06 11:24:58.997', 'SARAH_F'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET NOCOUNT ON

DECLARE	
	@all_facilities_flag			char (1)  ,
	@billing_project_id			int  ,
	@billing_link_id			int  ,
	@customer_id				int  ,
	@distribution_method			char (1)  ,
	@internal_review_flag			char (1)  ,
	@intervention_desc			varchar(255) ,
	@intervention_required_flag		char (1)  ,
	@mail_to_bill_to_address_flag		char (1)  ,
	@ebilling_flag				char(1),
	@PO_required_flag			char (1)  ,
	@PO_validation				char (1)  ,
	@release_required_flag			char (1)  ,
	@release_validation			char (1)  ,
	@status					char (1)  ,
	@weight_ticket_required_flag		char (1)  ,

	@accumulate_flag			char (1)  ,
	@accumulate_validation			char (1)  ,
	@dollar_match_flag			char (1)  ,
	@dollar_match_validation		char (1)  ,
	@expiration_date			datetime  ,
	@PO_amt					money  ,
	@PO_approval_code			varchar (15)  ,
	@PO_billing_project_id			int  ,
	@PO_company_id				int  ,
	@PO_customer_id				int  ,
	@PO_generator_id			int  ,
	@PO_manifest				varchar (15)  ,
	@PO_profit_ctr_id			int  ,
	@po_sequence_id				int  ,
	@po_status				char (1)  ,
	@PO_type				char (1)  ,
	@purchase_order				varchar (20)  ,
	@release				varchar (20)  ,
	@retail_order_type	Char(1),
	@start_date				datetime  ,
	@warning_percent			float ,

	@count_contact				int  ,
	@count_facility				int  ,
	@count_document				int  ,
	@count_pending				int  ,

	@billing_count 				int,
	@billing_date				datetime,
	@billing_line_count			int,
	@check_count				int,
	@check_init				int,
	@check_never				int,
	@check_ok				int,
	@company_id				int,
	@contact_address			varchar(250),
	@contact_email				varchar(60),
	@contact_fax				varchar(20),
	@contact_id 				int,
	@db_type				varchar(4),
	@doc_source				char(1),
	@doc_type				varchar(30),
	@doc_type_id				int,
	@doc_validation				char(1),
	@gross_weight				float,
	@line_id				int,
	@link_status				char(1),
	@link_desc				varchar(60),
	@manifest				varchar(15),
	@price_id				int,
	@profit_ctr_id				int,
	@project_count				int,
	@receipt_id				int,
	@record_id				bigint,
	@scan_count				int,
	@scan_receipt_id			int,
	@scan_workorder_id			int,
	--@source_company_id			int,
	--@source_profit_ctr_id			int,
	--@source_id				int,
	@source_ref				varchar(100),
	@source_type				varchar(15),
	@status_error				char(1),
	@status_good 				char(1),
	@status_warning 			char(1),
	@sum_amount				money,
	@tare_weight				float,
	@this_amount				money,
	@trans_source				char(1),
	@trans_type					char(1),
	@validate_count				int,
	@workorder_ref				varchar(20),
	@workorder_resource_type 	varchar(15),
    @receipt_wo_link_status		char(1),
    @billing_uid				int,
	@sync_invoice_jde			tinyint,
	@d365_flag					char(1),
    @sync_invoice_ax			tinyint,
    @sync_ax_Service	int,
	--@AX_Project_Required_Flag char(1),
	--@AX_Project_Required_Flag_count int,
	@invalid_ax_count	int,
	@error_value		int,
	@error_msg			varchar(8000),
	@ax_web_service		varchar(max),
	@linked_count_pending int,
	@count_links				int,
	@count_ContactXRef_inactive int,
	@count_Contact_inactive  int,
	@cust_country			varchar(40),
	@cust_city				varchar(40),
	@cust_state				varchar(2),
	@cust_zip_code			varchar(15),
	@bill_to_country		varchar(40),
	@bill_to_city			varchar(40),
	@bill_to_state			varchar(2),
	@bill_to_zip_code		varchar(15)
---------------------------------------------------------------
-- Do we export invoices/adjustments to JDE?
---------------------------------------------------------------
SELECT  @sync_invoice_jde = sync
FROM FinanceSyncControl
WHERE module = 'Invoice'
AND financial_system = 'JDE'

SELECT @sync_invoice_ax = sync
FROM FinanceSyncControl
WHERE module = 'Invoice'
AND financial_system = 'AX'

SELECT  @sync_ax_Service = sync
FROM FinanceSyncControl
WHERE module = 'Dimension Service Validation'
AND financial_system = 'AX'

SELECT @d365_flag = dbo.fn_get_D365_live()

SELECT @ax_web_service = config_value
FROM Configuration
where config_key =  'ax_web_service'

SET @status_good	= 'A'
SET @status_warning	= 'W'
SET @status_error	= 'E'

SET @check_never	= 0
SET @check_OK		= 1
SET @check_init		= 2

SET @billing_line_count	= 1
--IF SUBSTRING(@@servername, LEN(@@servername) - 3, 4) = 'TEST'
--	SET @db_type = 'TEST'
--ELSE IF SUBSTRING(@@servername, LEN(@@servername) - 2, 3) = 'DEV'
--	SET @db_type = 'DEV'
--ELSE	SET @db_type = ''

-- always set to prod.
SET @db_type = 'PROD'

-- Prepare the Validation Results
CREATE TABLE #validate (
	record_id		bigint NOT NULL,
	billing_line_count	int NULL,
	validate_date		datetime NULL ,
	validate_status		char (1) NULL ,
	validate_message	varchar (max) NULL 
)

-- Captures output when checking receipt/work order linked records
CREATE TABLE #link_errors (
	company_id	int NULL,
	profit_ctr_id	int NULL,
	trans_source	char(1) NULL,
	process_flag	int null,
    validate_flag   char(1) null,
   validate_message varchar(max) null,
   receipt_id int null,
   source_id int null
)
CREATE TABLE #axacct (
    AX_MainAccount varchar (20),
    AX_Dimension_1 varchar (20),
    AX_Dimension_2 varchar (20),
    AX_Dimension_3 varchar (20),
    AX_Dimension_4 varchar (20),
    AX_Dimension_6 varchar (20),
	AX_Dimension_5_part_1 varchar (20),
	AX_Dimension_5_part_2 varchar (9),
	status varchar (max) )
-- Get the minimum line per receipt/workorder
CREATE TABLE #minline (
	company_id	int NULL,
	profit_ctr_id	int NULL,
	receipt_id	int NULL,
	min_line 	int NULL
)

-- Create a temporary table to hold billing project information
CREATE TABLE #project (
	all_facilities_flag	char (1) NULL ,
	billing_project_id	int NULL ,
	customer_id		int NULL ,
	distribution_method	char (1) NULL ,
	internal_review_flag	char (1) NULL ,
	intervention_desc	varchar(255) NULL,
	intervention_required_flag	char (1) NULL ,
	mail_to_bill_to_address_flag	char (1) NULL ,
	ebilling_flag		char(1)	NULL,
	PO_required_flag	char (1) NULL ,
	PO_validation		char (1) NULL ,
	release_required_flag	char (1) NULL ,
	release_validation	char (1) NULL ,
	status			char (1) NULL ,
	weight_ticket_required_flag	char (1) NULL ,
	accumulate_flag		char (1) NULL ,
	accumulate_validation	char (1) NULL ,
	dollar_match_flag	char (1) NULL ,
	dollar_match_validation	char (1) NULL ,
	expiration_date		datetime NULL ,
	PO_amt			money NULL ,
	PO_approval_code	varchar (15) NULL ,
	PO_billing_project_id	int NULL ,
	PO_company_id		int NULL ,
	PO_customer_id		int NULL ,
	PO_generator_id		int NULL ,
	PO_manifest		varchar (15) NULL ,
	PO_profit_ctr_id	int NULL ,
	po_sequence_id		int NULL ,
	po_status		char (1) NULL ,
	PO_type			char (1) NULL ,
	purchase_order		varchar (20) NULL ,
	release			varchar (20) NULL ,
	start_date		datetime NULL ,
	warning_percent		float NULL,
	count_contact		int NULL ,
	count_facility		int NULL ,
	count_document		int NULL ,
	process_flag		int NULL
)

-- These are the documents required per project
-- CREATE TABLE #project_doc (
-- 	customer_id			int NULL ,
-- 	billing_project_id	int NULL ,
-- 	trans_source		char (1) NULL ,
-- 	type_id				int NULL,
-- 	scan_type			varchar(30) NULL,	
-- 	document_type		varchar(30) NULL,	
-- 	validation			char (1) NULL,
-- 	process_flag		int NULL
-- )
-- 
-- -- These are the documents that have been scanned
-- CREATE TABLE #scan_doc (
-- 	company_id		int NULL ,
-- 	profit_ctr_id	int NULL ,
-- 	source_id		int NULL ,
-- 	source_type		char (1) NULL ,
-- 	type_id			int NULL,
-- 	image_id		int NULL
-- )

-- Used to validate distribution method for contacts
CREATE TABLE #contact (
	contact_id		int NULL,
	contact_address 	varchar(250) NULL,
	contact_fax		varchar(20) NULL,
	contact_email		varchar(60) NULL,
	distribution_method	char(1) NULL,	
	billing_status		char(1) NULL
)

create table #all_linked ( 
    trans_source varchar(1) NULL,
	company_id int NULL,
	profit_ctr_id int NULL,
	receipt_id int NULL,
	customer_id int null,
    billing_project_id int null,
   	billing_link_id int NULL,
	source_type char(1) null,
	source_company_id int NULL,
	source_profit_ctr_id int NULL,
	source_id int NULL,
    link_invoice_id int null,
    link_void_flag char(1) null,
	link_billing_date datetime null,
    link_status char(1) null,
    link_print_on_invoice char(1) null,
    link_in_batch char(1) null,
	workorder_type_desc varchar(40) NULL,
	source_submitted_name varchar(40) null,
	source_submitted_date datetime null
)

create table #final_linked ( 
	company_id int NULL,
	profit_ctr_id int NULL,
	receipt_id int NULL,
	customer_id int null,
	source_type char(1) null,
	source_company_id int NULL,
	source_profit_ctr_id int NULL,
	source_id int NULL,
	link_billing_date datetime null,
    link_status char(1) null,
	workorder_type_desc varchar(40) NULL,
	source_submitted_name varchar(40) null,
	source_submitted_date datetime null
)
	
-- Used to hold back whole receipt when one line is not valid
CREATE TABLE #receipt (
	company_id	int NULL,
	profit_ctr_id	int NULL,
	trans_source	char(1) NULL,
	receipt_id	int NULL
)

-- Used to set check/uncheck value for treeview
CREATE TABLE #treeview_check (
	customer_id	int NULL,
	company_id	int NULL,
	profit_ctr_id	int NULL,
	error_count	int NULL,
	warning_count	int NULL,
	good_count	int NULL
)

-- Used to validate the billing records
CREATE TABLE #billing (
	record_id		bigint IDENTITY(1,1) NOT NULL PRIMARY KEY,
	billing_uid		int NOT NULL,
	customer_id		int NOT NULL,
	company_id		smallint NOT NULL,
	profit_ctr_id		smallint NOT NULL,
	trans_source		char(1) NOT NULL,
	receipt_id		int NOT NULL,
	line_id			int NOT NULL,
	price_id		int NOT NULL,
	status_code		char(1) NULL,   
	billing_date		datetime NULL,
	approval_code		varchar(50) NULL,
	manifest		varchar(15) NULL,
	waste_code		varchar(4) NULL,
	bill_unit_code		varchar(4) NULL,
	sr_type_code		char(1) NULL,
	quantity		float NULL,   
	sr_price		money NULL,   
	price			money NULL,   
	total_extended_amt	money NULL,   
	trans_type		char(1) NULL,
	workorder_resource_type	varchar(15) NULL,
	workorder_sequence_id	int NULL,
	billing_date_added	datetime NULL,
	billing_added_by	varchar(40) NULL,
	billing_project_id	int NULL, 
	po_sequence_id		int NULL,
	purchase_order		varchar(20) NULL,
	release_code		varchar(20) NULL,
	billing_link_id 	int NULL,
	source_company_id	int NULL,
	source_profit_ctr_id	int NULL,
	source_id		int NULL,
	generator_id		int NULL,
	gross_weight		float NULL,
	tare_weight		float NULL,
	void_status		char(1) NULL,
	treeview_customer_check	int NULL,
	treeview_facility_check	int NULL,
	treeview_billing_line_check int NULL,
	item_checked		int NULL,
	sort_order		int NULL,
	process_flag		int NULL,
	currency_code	char(3) NULL,
	customer_service_rep varchar(40) NULL,
	trans_workorder_type_desc varchar(40) NULL
)
TRUNCATE TABLE #all_linked
/***
-- rb 02/21/2014 experimental
select (business_unit_GMMCU COLLATE SQL_Latin1_General_CP1_CI_AS) as business_unit_GMMCU,
		(object_account_GMOBJ COLLATE SQL_Latin1_General_CP1_CI_AS) as object_account_GMOBJ,
		(subsidiary_GMSUB COLLATE SQL_Latin1_General_CP1_CI_AS) as subsidiary_GMSUB,
		(posting_edit_GMPEC COLLATE SQL_Latin1_General_CP1_CI_AS) as posting_edit_GMPEC
into #jdeacctmaster
from JDE.EQFinance.dbo.JDEGLAccountMaster_F0901
where subsidiary_GMSUB = ''
and posting_edit_GMPEC IN (' ','M')

create index idx_jdeacctmaster on #jdeacctmaster (business_unit_GMMCU, object_account_GMOBJ)
***/

-- Get the Billing records
-- Note that with this selection of Billing records, it tries to match to an Active
-- Billing Project by the billing project ID stored in the Billing line.  If it 
-- cannot match to an Active billing project, it sets the billing project ID as
-- the Standard Billing project.
INSERT #billing (billing_uid, customer_id, company_id, profit_ctr_id, trans_source, receipt_id, line_id, price_id,
	status_code, billing_date, approval_code, manifest, waste_code, bill_unit_code, sr_type_code,
	quantity, sr_price, price, total_extended_amt, trans_type, workorder_resource_type, workorder_sequence_id,
	billing_date_added, billing_added_by,
	billing_project_id, po_sequence_id, purchase_order, release_code, billing_link_id, 
	generator_id, gross_weight, tare_weight, void_status,
	treeview_customer_check, treeview_facility_check, treeview_billing_line_check,
	item_checked, sort_order, process_flag, currency_code,customer_service_rep)
SELECT DISTINCT 
	Billing.billing_uid,
	Billing.customer_id,
	Billing.company_id,
	Billing.profit_ctr_id,
	Billing.trans_source,
	Billing.receipt_id,
	Billing.line_id,
	Billing.price_id,
	Billing.status_code,   
	Billing.billing_date,
	Billing.approval_code,
	Billing.manifest,
	Billing.waste_code,
	Billing.bill_unit_code,
	Billing.sr_type_code,
	Billing.quantity,
	Billing.sr_price,
	Billing.price,
	Billing.total_extended_amt,
	Billing.trans_type,
	'' as workorder_resource_type,
	Billing.workorder_sequence_id,  
	Billing.date_added,
	Billing.added_by,
	ISNULL(CustomerBilling.billing_project_id,0) as billing_project_id,
	Billing.po_sequence_id,
	Billing.purchase_order,
	Billing.release_code,
	Billing.billing_link_id,
	Billing.generator_id,
	Billing.gross_weight,
	Billing.tare_weight,
	Billing.void_status,
	CONVERT(int, NULL) as treeview_customer_check,
	CONVERT(int, NULL)  as treeview_facility_check,
	CONVERT(int, NULL)  as treeview_billing_line_check,
	1 as item_checked,
	0 as sort_order,
	0 as process_flag,
	-- '' as AX_Project_Required_Flag,
	Billing.currency_code,
	users.user_name
FROM Billing
JOIN work_BillingValidate W
	ON Billing.customer_id = W.customer_id
	AND Billing.company_id = W.company_id
	AND Billing.profit_ctr_id = W.profit_ctr_id
	AND Billing.trans_source = W.trans_source
	AND Billing.receipt_id = W.receipt_id
	AND Billing.line_id = W.line_id
	AND Billing.price_id = W.price_id
	AND Billing.status_code = W.status_code
	AND W.validate_date = @validate_date
	and W.user_code = @user_code
LEFT OUTER JOIN CustomerBilling
	ON Billing.customer_id = CustomerBilling.customer_id
	AND ISNULL(Billing.billing_project_id,0) = CustomerBilling.billing_project_id
	AND CustomerBilling.status = 'A'
LEFT OUTER JOIN usersxeqcontact csrx on customerbilling.customer_service_id = csrx.type_id
       and csrx.eqcontact_type = 'CSR'
LEFT OUTER JOIN users on users.user_code = csrx.user_code  
WHERE Billing.trans_source IN ('R','O')
UNION ALL
SELECT DISTINCT 
	Billing.billing_uid,
	Billing.customer_id,
	Billing.company_id,
	Billing.profit_ctr_id,
	Billing.trans_source,
	Billing.receipt_id,
	COUNT(Billing.line_id) AS line_id,
	1 as price_id,
	Billing.status_code,   
	Billing.billing_date,
	'' AS approval_code,
	'' AS manifest,
	Billing.waste_code,
	'' AS bill_unit_code,
	Billing.sr_type_code,
	1 AS quantity,
	Billing.sr_price,
	SUM(Billing.total_extended_amt) AS price,
	SUM(Billing.total_extended_amt) AS total_extended_amt,
	Billing.trans_type,
	'' as workorder_resource_type,
	1 AS workorder_sequence_id,  
	Billing.date_added,
	Billing.added_by,
	ISNULL(CustomerBilling.billing_project_id,0) as billing_project_id,
	Billing.po_sequence_id,
	Billing.purchase_order,
	Billing.release_code,
	Billing.billing_link_id,
	Billing.generator_id,
	Billing.gross_weight,
	Billing.tare_weight,
	Billing.void_status,
	CONVERT(int, NULL) as treeview_customer_check,
	CONVERT(int, NULL)  as treeview_facility_check,
	CONVERT(int, NULL)  as treeview_billing_line_check,
	1 as item_checked,
	0 as sort_order,
	0 as process_flag,
	--WorkOrderTypeDetail.AX_Project_Required_Flag as AX_Project_Required_Flag,
	Billing.currency_code,
	users.user_name  
FROM Billing
JOIN work_BillingValidate W
	ON Billing.customer_id = W.customer_id
	AND Billing.company_id = W.company_id
	AND Billing.profit_ctr_id = W.profit_ctr_id
	AND Billing.trans_source = W.trans_source
	AND Billing.receipt_id = W.receipt_id
	AND Billing.status_code = W.status_code
	AND W.validate_date = @validate_date
	and W.user_code = @user_code
JOIN BillingDetail bd ON Billing.billing_uid = bd.billing_uid	
    AND Billing.company_id = bd.company_id
	AND Billing.profit_ctr_id = bd.profit_ctr_id
	AND Billing.trans_source = bd.trans_source
	AND Billing.receipt_id = bd.receipt_id
	AND Billing.line_id = bd.line_id
	AND Billing.price_id = bd.price_id
	AND bd.billing_type = 'WorkOrder'  -- Rally # DE34310
--JOIN WorkorderHeader 
--    ON ISNULL(WorkorderHeader.total_price, 0) > 0
--	 AND WorkorderHeader.company_id = Billing.company_id
--	 AND WorkorderHeader.profit_ctr_id = Billing.profit_ctr_id
--	 AND WorkorderHeader.workorder_id = Billing.receipt_id
--	 AND WorkorderHeader.customer_id = Billing.customer_id
--	 AND WorkorderHeader.workorder_status = 'A'
--	 AND ISNULL(WorkorderHeader.submitted_flag, 'F') = 'T'
LEFT OUTER JOIN CustomerBilling
	ON Billing.customer_id = CustomerBilling.customer_id
	AND ISNULL(Billing.billing_project_id,0) = CustomerBilling.billing_project_id
	AND CustomerBilling.status = 'A'
LEFT OUTER JOIN usersxeqcontact csrx on customerbilling.customer_service_id = csrx.type_id
       and csrx.eqcontact_type = 'CSR'
LEFT OUTER JOIN users on users.user_code = csrx.user_code  
--LEFT OUTER JOIN ( SELECT DISTINCT 
--                              workorder_type_id
--                              , company_id
--                              , profit_ctr_id
--                              , customer_id
--                              , AX_MainAccount_Part_1 AS AX_MainAccount_Part_1
--                              , AX_Dimension_3 AS AX_Dimension_3
--                              , AX_Dimension_4_Base AS AX_Dimension_4_Base
--                              , AX_Dimension_4_Event AS AX_Dimension_4_Event
--                              , AX_Dimension_5_Part_1 AS AX_Dimension_5_Part_1
--                              , AX_Dimension_5_Part_2 AS AX_Dimension_5_Part_2
--                              , AX_Dimension_6 AS AX_Dimension_6
--                              , AX_Project_Required_Flag
--                           FROM WorkOrderTypeDetail
--                           WHERE 1=1
--              ) WorkOrderTypeDetail ON WorkOrderTypeDetail.workorder_type_id = WorkOrderHeader.workorder_type_id 
--                     AND WorkOrderTypeDetail.company_id = WorkOrderHeader.company_id
--                     AND WorkOrderTypeDetail.profit_ctr_id = WorkOrderHeader.profit_ctr_id
--                     AND (WorkOrderTypeDetail.customer_id IS NULL OR WorkorderHeader.customer_id = WorkOrderTypeDetail.customer_id )
WHERE Billing.trans_source = 'W'
GROUP BY
	Billing.billing_uid,
	Billing.customer_id,
	Billing.company_id,
	Billing.profit_ctr_id,
	Billing.trans_source,
	Billing.receipt_id,
	Billing.status_code,   
	Billing.billing_date,
	Billing.waste_code,
	Billing.sr_type_code,
	Billing.sr_price,
	Billing.trans_type,
	Billing.date_added,
	Billing.added_by,
	ISNULL(CustomerBilling.billing_project_id,0),
	Billing.po_sequence_id,
	Billing.purchase_order,
	Billing.release_code,
	Billing.billing_link_id,
	Billing.generator_id,
	Billing.gross_weight,
	Billing.tare_weight,
	Billing.void_status,
	Billing.currency_code,
	users.user_name
	--WorkOrderTypeDetail.AX_Project_Required_Flag,

IF @debug = 1 
BEGIN
	print 'selecting from #billing - retrieved billing records'
	select 'selecting from #billing - retrieved billing records'
	select * from #billing
END

-- get the Minimum line for the reports - manages reporting for workorder
INSERT #minline (company_id, profit_ctr_id, receipt_id, min_line)
SELECT company_id,
	profit_ctr_id,
	receipt_id,
	Min(line_id)
FROM #billing
GROUP BY
	company_id,
	profit_ctr_id,
	receipt_id

IF @debug = 1 
BEGIN
	print 'selecting from #minline'
	select 'selecting from #minline'
	select * from #minline
END

-- Check for Void lines
INSERT #validate SELECT #billing.record_id, @billing_line_count, @validate_date, @status_error, 'Billing line is Void'
FROM #billing WHERE ISNULL(void_status,'F') = 'T'
UPDATE #billing SET process_flag = -1 WHERE ISNULL(void_status,'F') = 'T'

-----------------------------------------------------------
-- Check Billing Lines
-----------------------------------------------------------
-- These are the assigned billing projects
INSERT #project
SELECT DISTINCT
	ISNULL(CustomerBilling.all_facilities_flag,'T'),
	CustomerBilling.billing_project_id,
	CustomerBilling.customer_id,
	ISNULL(CustomerBilling.distribution_method,'M'),
	ISNULL(CustomerBilling.internal_review_flag,'F'),
	CustomerBilling.intervention_desc,
	ISNULL(CustomerBilling.intervention_required_flag,'F'),
	ISNULL(CustomerBilling.mail_to_bill_to_address_flag,'T'),
	ISNULL(CustomerBilling.ebilling_flag, 'F'),
	ISNULL(CustomerBilling.PO_required_flag,'F'),
	CustomerBilling.PO_validation,
	ISNULL(CustomerBilling.release_required_flag,'F'),
	CustomerBilling.release_validation,
	CustomerBilling.status,
	ISNULL(CustomerBilling.weight_ticket_required_flag,'F'),
	ISNULL(CustomerBillingPO.accumulate_flag,'F'),
	CustomerBillingPO.accumulate_validation,
	ISNULL(CustomerBillingPO.dollar_match_flag,'F'),
	CustomerBillingPO.dollar_match_validation,
	CustomerBillingPO.expiration_date,
	CustomerBillingPO.PO_amt,
	CustomerBillingPO.PO_approval_code,
	CustomerBillingPO.PO_billing_project_id,
	CustomerBillingPO.PO_company_id,
	CustomerBillingPO.PO_customer_id,
	CustomerBillingPO.PO_generator_id,
	CustomerBillingPO.PO_manifest,
	CustomerBillingPO.PO_profit_ctr_id,
	CustomerBillingPO.sequence_id,
	CustomerBillingPO.status,
	CustomerBillingPO.PO_type,
	CustomerBillingPO.purchase_order,
	CustomerBillingPO.release,
	CustomerBillingPO.start_date,
	ISNULL(CustomerBillingPO.warning_percent, 100),
	count_contact = ISNULL((SELECT COUNT(*) FROM CustomerBillingXContact CBC
			WHERE CBC.customer_id = CustomerBilling.customer_id
			AND CBC.billing_project_id = CustomerBilling.billing_project_id
			AND CBC.invoice_copy_flag = 'T'),0),
	count_facility = ISNULL((SELECT COUNT(*) FROM CustomerBillingXProfitCenter CBPC
			WHERE CBPC.customer_id = CustomerBilling.customer_id
			AND CBPC.billing_project_id = CustomerBilling.billing_project_id
			AND CBPC.company_id = #billing.company_id
			AND CBPC.profit_ctr_id = #billing.profit_ctr_id),0),
	count_document  = ISNULL((SELECT COUNT(*) FROM CustomerBillingDocument CBD
			WHERE CBD.customer_id = CustomerBilling.customer_id
			AND CBD.billing_project_id = CustomerBilling.billing_project_id
			AND CBD.status = 'A'),0),
	process_flag = 0
FROM CustomerBilling 
JOIN #billing
	ON CustomerBilling.customer_id = #billing.customer_id
	AND CustomerBilling.billing_project_id = ISNULL(#billing.billing_project_id,0)
LEFT OUTER JOIN CustomerBillingPO 
	ON CustomerBilling.customer_id = CustomerBillingPO.customer_id
	AND CustomerBilling.billing_project_id = CustomerBillingPO.billing_project_id
	AND CustomerBillingPO.status = 'A'
	AND CustomerBillingPO.purchase_order = #billing.purchase_order
	AND CustomerBillingPO.release = #billing.release_code
SELECT @project_count = @@rowcount

IF @debug = 1 
BEGIN
	print 'selecting from #project -- check specific requirements'
	select 'selecting from #project -- check specific requirements'
	select * from #project
END

-- These are the documents required per project
-- INSERT #project_doc
-- SELECT DISTINCT
-- 	CustomerBillingDocument.customer_id,
-- 	CustomerBillingDocument.billing_project_id,
-- 	CustomerBillingDocument.trans_source,
-- 	CustomerBillingDocument.type_id,
-- 	CustomerBillingScanDocumentType.scan_type,
-- 	CustomerBillingScanDocumentType.document_type,
-- 	CustomerBillingDocument.validation,
-- 	0 as process_flag
-- FROM CustomerBillingDocument 
-- JOIN #billing
-- 	ON CustomerBillingDocument.customer_id = #billing.customer_id
-- 	AND CustomerBillingDocument.billing_project_id = ISNULL(#billing.billing_project_id,0)
-- JOIN CustomerBillingScanDocumentType
-- 	ON 	CustomerBillingScanDocumentType.type_id = CustomerBillingDocument.type_id
-- WHERE CustomerBillingDocument.status = 'A'
-- 	AND CustomerBillingDocument.validation <> 'N'
-- 
-- IF @debug = 1 print 'Selecting the required documents'
-- IF @debug = 1 select * from #project_doc
-- 
-- -- These are the documents that have been scanned
-- INSERT #scan_doc SELECT Scan.company_id, Scan.profit_ctr_id, 
-- 	CASE WHEN #billing.trans_source = 'R' THEN Scan.receipt_id ELSE Scan.workorder_id END, 
-- 	#billing.trans_source, Scan.type_id, Scan.image_id
-- FROM PLT_IMAGE..Scan Scan
-- JOIN #Billing
-- 	ON #Billing.company_id = Scan.company_id
-- 	AND #billing.profit_ctr_id = Scan.profit_ctr_id
-- 	AND ((#billing.receipt_id = Scan.receipt_id AND #billing.trans_source = 'R') 
-- 		OR (#billing.receipt_id = Scan.workorder_id AND #billing.trans_source = 'W'))
-- 
-- IF @debug = 1 print 'Selecting the scanned documents'
-- IF @debug = 1 select * from #scan_doc

-- For Receipts, check Each Billing Line; Check the first line for a Workorder
CREATE NONCLUSTERED INDEX idx_tmp_billing_process_flag ON #billing(process_flag)
CREATE CLUSTERED INDEX idx_tmp_validate_record_id ON #validate(record_id)
CREATE CLUSTERED INDEX idx_tmp_axacct_ci ON #axacct(AX_MainAccount,
												AX_Dimension_1,
												AX_Dimension_2,
												AX_Dimension_3,
												AX_Dimension_4,
												AX_Dimension_6,
												AX_Dimension_5_Part_1,
												AX_Dimension_5_Part_2)
SELECT @billing_count = COUNT(*) FROM #billing WHERE process_flag = 0
WHILE @project_count > 0 AND @billing_count > 0
BEGIN
	-- Because each billing line can have different projects, process one at a time
	SELECT @record_id = (SELECT Min (record_id)  FROM #billing where process_flag = 0)

	-- Re-init the billing line count
	SELECT @billing_line_count = CASE ISNULL(SUM(billing_line_count),0) WHEN 0 THEN 1 ELSE 0 END
	FROM #validate WHERE record_id = @record_id

	IF @debug = 1 print '@record_id: ' + CONVERT(varchar(20), @record_id) + ' AND @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)

	SELECT @billing_uid = billing_uid,
		@company_id = company_id,
		@profit_ctr_id = profit_ctr_id,
		@customer_id = customer_id,
		@trans_source = trans_source,
		@receipt_id = receipt_id,
		@line_id = line_id,
		@price_id = price_id,
		@scan_receipt_id = CASE WHEN trans_source = 'R' THEN receipt_id ELSE 0 END,
		@scan_workorder_id = CASE WHEN trans_source = 'W' THEN receipt_id ELSE 0 END,
		@manifest = manifest,
		@purchase_order = purchase_order,
		@release = release_code,
		@this_amount = total_extended_amt,
		@billing_date = billing_date,
		@billing_project_id = billing_project_id,
		@billing_link_id = billing_link_id,
		--@source_company_id = source_company_id,
		--@source_profit_ctr_id	= source_profit_ctr_id,
		--@source_id = source_id,
		@source_type = CASE WHEN trans_source = 'R' THEN 'Receipt ' ELSE 'Work Order ' END,
		@trans_type = trans_type,
		@workorder_resource_type = workorder_resource_type,
		@gross_weight = gross_weight,
		@tare_weight = tare_weight
	FROM #billing WHERE record_id = @record_id
	SET @validate_count = 0

	IF @debug = 1 
	BEGIN
		print 'billing line: '	
		select 'billing line: '
		SELECT * FROM #billing WHERE record_id = @record_id
	END

	-- Get info for this project
	SELECT 	@all_facilities_flag	= all_facilities_flag,
		@distribution_method	= distribution_method,
		@internal_review_flag	= internal_review_flag,
		@intervention_desc	= intervention_desc,
		@intervention_required_flag = intervention_required_flag,
		@mail_to_bill_to_address_flag = mail_to_bill_to_address_flag,
		@ebilling_flag = ebilling_flag,
		@PO_required_flag	= PO_required_flag,
		@PO_validation		= PO_validation,
		@release_required_flag	= release_required_flag,
		@release_validation	= release_validation,
		@status			= status,
		@weight_ticket_required_flag = weight_ticket_required_flag,
		@accumulate_flag	= accumulate_flag,
		@accumulate_validation	= accumulate_validation,
		@dollar_match_flag	= dollar_match_flag,
		@dollar_match_validation = dollar_match_validation,
		@expiration_date	= expiration_date,
		@PO_amt			= PO_amt,
		@PO_approval_code	= PO_approval_code,
		@PO_billing_project_id	= PO_billing_project_id,
		@PO_company_id		= PO_company_id,
		@PO_customer_id		= PO_customer_id,
		@PO_generator_id	= PO_generator_id,
		@PO_manifest		= PO_manifest,
		@PO_profit_ctr_id	= PO_profit_ctr_id,
		@po_sequence_id		= po_sequence_id,
		@po_status		= po_status,
		@PO_type		= PO_type,
		@start_date		= start_date,
		@warning_percent	= warning_percent,
		@count_contact		= count_contact,
		@count_facility		= count_facility,
		@count_document		= count_document
	FROM #project
	WHERE #project.customer_id = @customer_id
	AND #project.billing_project_id = @billing_project_id
	AND (#project.purchase_order IS NULL OR #project.purchase_order = @purchase_order)
	AND (#project.release IS NULL OR #project.release = @release)
	
	-- No project, this is a serious error
	IF @@rowcount = 0
	BEGIN
		IF @debug = 1 print '1 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)

		INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @status_error, 
			'No Billing Project is available for validation.')
		SET @billing_line_count = 0
		GOTO CONTINUE_PROCESSING
	END
--  New changes for Retail Validation  KAM
	If @trans_source = 'O' 
		Begin
			Select @retail_order_type = order_type from OrderHeader where order_id = @receipt_id
			If @retail_order_type = 'C'
				GOTO CONTINUE_PROCESSING
		End
---  End of Changes KAM


	-- Is this billing project valid for the billing line company and profit center?
	IF @all_facilities_flag = 'F' 
	BEGIN
		IF @debug = 1 print '2 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)

		INSERT #validate 
		SELECT #billing.record_id, @billing_line_count, @validate_date, @status_error, 
			'The assigned billing project is not valid for this facility.'
		FROM #billing
		WHERE #billing.record_id = @record_id
		AND NOT EXISTS (SELECT 1 FROM CustomerBillingXProfitCenter CBXPC
			WHERE CBXPC.customer_id = #billing.customer_id
			AND CBXPC.billing_project_id = #billing.billing_project_id
			AND CBXPC.company_id = #billing.company_id
			AND CBXPC.profit_ctr_id = #billing.profit_ctr_id)
		-- Reset the billing_line_count ONLY if this validation record was written
		IF @@rowcount > 0
			SET @billing_line_count = 0
	END

	-- Mail to bill to address
	IF @mail_to_bill_to_address_flag = 'T' 
		SELECT @contact_address = ISNULL(Customer.bill_to_addr1,'') + ISNULL(Customer.bill_to_addr2,'')+ ISNULL(Customer.bill_to_addr3,'')+ ISNULL(Customer.bill_to_addr4,'')+ ISNULL(Customer.bill_to_city,'')+ ISNULL(Customer.bill_to_state,'')+ ISNULL(Customer.bill_to_zip_code,''),
			@contact_fax = ISNULL(Customer.cust_fax, ''),
			@contact_email = ''
		FROM Customer
		WHERE Customer.customer_id = @customer_id
		
		-- Must have an address
		IF @contact_address = ''
		BEGIN
			IF @debug = 1 print '3 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)

			INSERT #validate VALUES(@record_id, @billing_line_count, @validate_date, @status_error, 
				'Billing Project distribution method is Mail but Bill To address is not valid.')
			SET @billing_line_count = 0
		END

	-- Send to Contact
	ELSE IF @mail_to_bill_to_address_flag = 'F' 
	BEGIN
		-- Are there any contacts?
		IF @count_contact = 0
		BEGIN
			-- IF e-billing is checked it is not required to have contact
			IF @ebilling_flag = 'F'
			BEGIN
				IF @debug = 1 print '4 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)

				INSERT #validate VALUES(@record_id, @billing_line_count, @validate_date, @status_error, 
					'Bill To Mail To Address is turned off but there are no active contacts to receive the invoice.')
				SET @billing_line_count = 0
			END
		END
		ELSE
		BEGIN
			-- Check specific contacts assigned to this billing project
			TRUNCATE TABLE #contact
			INSERT #contact
			SELECT ISNULL(CustomerBillingXContact.contact_id,0),
				SUBSTRING(ISNULL(Contact.contact_addr1,'') + ISNULL(Contact.contact_addr2,'')+ ISNULL(Contact.contact_addr3,'')+ ISNULL(Contact.contact_addr4,'')+ ISNULL(Contact.contact_city,'')+ ISNULL(Contact.contact_state,'')+ ISNULL(Contact.contact_zip_code,''), 1, 250),
				ISNULL(Contact.fax, ''),
				ISNULL(Contact.email,''),
				ISNULL(CustomerBillingXContact.distribution_method, 'M'),
				@status_error as billing_status
			FROM CustomerBillingXContact
			JOIN ContactXRef  
				ON CustomerBillingXContact.customer_id = ContactXRef.customer_id 
				AND CustomerBillingXContact.contact_id = ContactXRef.contact_id
				AND ContactXRef.status = 'A'
			JOIN Contact
				ON ContactXRef.contact_id = Contact.contact_id
				AND Contact.contact_status = 'A'
			WHERE ISNULL(CustomerBillingXContact.invoice_copy_flag,'F') = 'T'
				AND CustomerBillingXContact.customer_id = @customer_id
				AND CustomerBillingXContact.billing_project_id = @billing_project_id
			SELECT @count_contact = @@rowcount

			IF @debug = 1 print 'selecting from #contact: '
			IF @debug = 1 select * from #contact

------------------------------------------------------------------------------------------
-- Old Requirement (before e-mailing and faxing was programmed into EQAI)
-- This was replaced with the select just below on 12/30/08 JDB
------------------------------------------------------------------------------------------
--			-- There must be at least one contact with Mail or UPS with a valid address
--			SELECT @count_contact = COUNT(*) FROM #contact 
--			WHERE distribution_method IN ('M','U')
--				AND contact_address <> ''
------------------------------------------------------------------------------------------
         IF  @count_contact >  0
		 BEGIN
			SELECT @count_contact = COUNT(*) FROM #contact 
			WHERE (distribution_method IN ('M','U') AND contact_address <> '')
				OR (distribution_method = 'F' AND contact_fax <> '')
				OR ((distribution_method = 'E' OR distribution_method = 'A') AND contact_email <> '')
				
			IF @count_contact = 0
			BEGIN
				IF @debug = 1 print '5 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
				INSERT #validate VALUES(@record_id, @billing_line_count, @validate_date, @status_error, 
					'There is no contact with a valid mailing / fax / e-mail address.')
				SET @billing_line_count = 0
			END
		 END
			/*DevOps:49556 AM - 02/27/2023 - If the ContactXRef status is Inactive, display below message */
			SELECT @count_ContactXRef_inactive = Count(*)
			FROM CustomerBillingXContact
			JOIN ContactXRef  
				ON CustomerBillingXContact.customer_id = ContactXRef.customer_id 
				AND CustomerBillingXContact.contact_id = ContactXRef.contact_id
				AND ContactXRef.status = 'I'
			WHERE ISNULL(CustomerBillingXContact.invoice_copy_flag,'F') = 'T'
				AND CustomerBillingXContact.customer_id = @customer_id
				AND CustomerBillingXContact.billing_project_id = @billing_project_id

			IF @count_ContactXRef_inactive > 0
			BEGIN
				IF @debug = 1 print '23 @billing_line_count: ' + CONVERT(varchar(10),@billing_line_count)
				INSERT #validate VALUES(@record_id, @billing_line_count, @validate_date, @status_error, 
					'This invoice is set to distribute to an contact that is inactive in the relationship to the customer.')
				SET @billing_line_count = 0
			END

			/* If the Contact status is Inactive, display below message */
			SELECT @count_Contact_inactive = Count(*)
			FROM CustomerBillingXContact
			JOIN Contact 
				ON CustomerBillingXContact.customer_id = @customer_id
				AND CustomerBillingXContact.contact_id = Contact.contact_id
				AND Contact.contact_status = 'I'
			WHERE ISNULL(CustomerBillingXContact.invoice_copy_flag,'F') = 'T'
				AND CustomerBillingXContact.customer_id = @customer_id
				AND CustomerBillingXContact.billing_project_id = @billing_project_id

			IF @count_Contact_inactive > 0
			BEGIN
				IF @debug = 1 print '24 @billing_line_count: ' + CONVERT(varchar(10),@billing_line_count)
				INSERT #validate VALUES(@record_id, @billing_line_count, @validate_date, @status_error, 
					'This invoice is set to distribute to an inactive contact.')
				SET @billing_line_count = 0
			END
					
			-- Update the status column
			UPDATE #contact SET billing_status = @status_good
			WHERE (distribution_method IN ('M','U') AND contact_address <> '')
				OR (distribution_method = 'F' AND contact_fax <> '')
				OR ((distribution_method = 'E' OR distribution_method = 'A') AND contact_email <> '')
			
			SELECT @count_contact = COUNT(*) FROM #contact WHERE billing_status = @status_error
			IF @count_contact <> 0
			BEGIN
				IF @debug = 1 print '6 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
				INSERT #validate VALUES(@record_id, @billing_line_count, @validate_date, @status_error, 
					'There are ' + CONVERT(varchar(10), @count_contact) + ' contact(s) without a valid distribution method.')
				SET @billing_line_count = 0
			END
		END
	END

--	-- Internal review required?
--	IF @internal_review_flag = 'T'
--	BEGIN
--IF @debug = 1 print '7 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
--		INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @status_warning, 
--			'Internal Review is required.')
--		SET @billing_line_count = 0
--	END
	/* Rally: US115917 - Sailaja - Validation for Missing Address Fields (Validate tab) - 06/21/2024 */
	SELECT 	@cust_country = ISNULL(TRIM(cust_country),''),
			@cust_city = ISNULL(TRIM(cust_city),''),
			@cust_state = ISNULL(TRIM(cust_state),''),
			@cust_zip_code = ISNULL(TRIM(cust_zip_code),''),
			@bill_to_country = ISNULL(TRIM(bill_to_country),''),
			@bill_to_city = ISNULL(TRIM(bill_to_city),''),
			@bill_to_state = ISNULL(TRIM(bill_to_state),''),
			@bill_to_zip_code =  ISNULL(TRIM(bill_to_zip_code),'')
	FROM	Customer 
	WHERE	Customer.customer_id = @customer_id
	AND		(Customer.cust_country in ('USA','CAN','MEX') OR Customer.bill_to_country in ('USA','CAN','MEX'))

	IF (@cust_country in ('USA','CAN','MEX') AND (@cust_city = '' OR @cust_state ='' OR @cust_zip_code = '')) OR
		(@bill_to_country in ('USA','CAN','MEX') AND (@bill_to_city = '' OR @bill_to_state ='' OR @bill_to_zip_code = ''))
	BEGIN
		IF @debug = 1 print '25 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)

		INSERT #validate VALUES(@record_id, @billing_line_count, @validate_date, @status_error, 
			'The customer address is missing the City, State or Zip Code. Please correct the customer in D365.')
		SET @billing_line_count = 0
	END
		
	-- Intervention required?
	IF @intervention_required_flag = 'T'
	BEGIN
		IF @debug = 1 print '8 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
		INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @status_warning, 
			'Intervention REQ: ' + SUBSTRING(@intervention_desc, 1,(254 - LEN('Intervention REQ: '))))
		SET @billing_line_count = 0
	END

	-- Is a purchase order required?
	IF @po_required_flag = 'T' AND (@purchase_order IS NULL OR @purchase_order = '') 
	BEGIN
		IF @debug = 9 print '9 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
		INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @po_validation, 
			'PO is required.')
		SET @billing_line_count = 0
	END
	
	-- Is a release required?
	IF @release_required_flag = 'T' AND (@release IS NULL OR @release = '')
	BEGIN
		IF @debug = 1 print '10 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
		INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @release_validation, 
			'Release is required.')
		SET @billing_line_count = 0
	END

	-- Must have weights
	IF (@weight_ticket_required_flag = 'T' AND (@gross_weight - @tare_weight) <= 0 AND @trans_type = 'D' and @trans_source <> 'O')
	BEGIN
		IF @debug = 1 print '11 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
		INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @status_warning, 
			'Weight Ticket is required and weights are not valid.')
		SET @billing_line_count = 0
	END 

	-- Is this a dollar match project?
	IF @dollar_match_flag = 'T' 
	BEGIN
		-- Amounts must match
		IF @this_amount <> @PO_amt
		BEGIN
			IF @debug = 1 print '12 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
			INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @dollar_match_validation, 
				'Dollar amount does not match dollar amount requirement.')
			SET @billing_line_count = 0
		END

		-- Must have a scanned PO
--  Added @trans_source into If since we cannot scan in retail orders  KAM
		IF ((@purchase_order IS NULL OR @purchase_order = '') AND
		   (@release IS NULL OR @release = '')) and (@trans_source <> 'O')
		BEGIN
			IF @debug = 1 print '13 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
			INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @status_error, 
				'PO or Release is required for dollar match.')
			SET @billing_line_count = 0
		END
	END
			
	-- Is this an amount for accumulation?
	IF @accumulate_flag = 'T'
	BEGIN
		SELECT @sum_amount = ISNULL(SUM(total_extended_amt) ,0)
		FROM Billing 
		WHERE Billing.customer_id = @customer_id
			AND Billing.billing_project_id = @billing_project_id
			AND Billing.purchase_order = @purchase_order
			AND Billing.status_code <> 'V'
		-- Give a warning?
		IF @sum_amount < @PO_amt AND @sum_amount >= ((@warning_percent/100) * @PO_amt)
		BEGIN
			IF @debug = 1 print '14 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
			INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @accumulate_validation, 
				'Accumulated PO amount is within ' + CONVERT(varchar(10), @warning_percent) + '% of the PO amount specified (' + CONVERT(varchar(10), @PO_amt) + ').')
			SET @billing_line_count = 0
		END
		ELSE IF @sum_amount > @PO_amt
		BEGIN
			IF @debug = 1 print '15 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
			INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @accumulate_validation, 
				'Accumulated PO amount exceeds the PO amount specified (' + CONVERT(varchar(10), @PO_amt) + ').')
			SET @billing_line_count = 0
		END
	END

	-- Check dates
	IF @billing_date < @start_date
	BEGIN
		IF @debug = 1 print '16 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
		INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @status_warning, 
			'Transaction date is before PO start date.')
		SET @billing_line_count = 0
	END
	IF @billing_date > @expiration_date
	BEGIN
		IF @debug = 1 print '17 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
		INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @status_warning, 
			'Transaction date is after PO expiration date.')
		SET @billing_line_count = 0
	END

/***
	IF @sync_invoice_jde = 1		
	-- Are the JDE GL Accounts valid?
	BEGIN  
	 IF @debug = 1 print '@sync_invoice_jde: ' + CONVERT(varchar(10), @billing_line_count)      
		INSERT #validate 
		SELECT @record_id, @billing_line_count, @validate_date, @status_error, 'Invalid or missing JDE GL account:  ' + bd.JDE_BU + '-' + bd..JDE_object + ' (' + bd.billing_type + ').'
		FROM #billing 
		JOIN BillingDetail bd ON bd.billing_uid = #billing.billing_uid	
		WHERE #billing.record_id = @record_id
		AND NOT 
			EXISTS (SELECT 1 FROM #jdeacctmaster
			WHERE business_unit_GMMCU = RIGHT('            ' + bd.JDE_BU, 12)
			AND object_account_GMOBJ = bd.JDE_object
			AND subsidiary_GMSUB = ''
			AND posting_edit_GMPEC IN (' ','M')
			)
		--SET @billing_line_count = 0
		---- Reset the billing_line_count ONLY if this validation record was written
		IF @@rowcount > 0
			SET @billing_line_count = 0
	END
***/
	
-- -- Are the AX GL Accounts valid?

 IF  @sync_invoice_ax = 1 
 BEGIN
     IF @debug = 1 print '@sync_invoice_ax: ' + CONVERT(varchar(10), @billing_line_count)
      insert #axacct
     select distinct bd.AX_MainAccount,bd.AX_Dimension_1,bd.AX_Dimension_2,bd.AX_Dimension_3,bd.AX_Dimension_4,bd.AX_Dimension_6,
                                             bd.AX_Dimension_5_part_1,bd.AX_Dimension_5_part_2, convert(varchar(max),null) as status
		FROM #billing 
		JOIN BillingDetail bd ON bd.billing_uid = #billing.billing_uid	
		WHERE #billing.record_id = @record_id
		and not exists (select 1 from #axacct
						where AX_MainAccount = bd.AX_MainAccount
						and AX_Dimension_1 = bd.AX_Dimension_1
						and AX_Dimension_2 = bd.AX_Dimension_2
						and AX_Dimension_3 = bd.AX_Dimension_3
						and AX_Dimension_4 = bd.AX_Dimension_4
						and AX_Dimension_6 = bd.AX_Dimension_6
						and AX_Dimension_5_Part_1 = bd.AX_Dimension_5_Part_1
						and AX_Dimension_5_Part_2 = bd.AX_Dimension_5_Part_2)
       
		update #axacct
		set status = 'Valid' /*dbo.fnValidateFinancialDimension (@ax_web_service,AX_MainAccount,AX_Dimension_1,AX_Dimension_2,AX_Dimension_3,AX_Dimension_4,AX_Dimension_6,
											AX_Dimension_5_part_1,AX_Dimension_5_part_2 )*/                  
		where status is null

   INSERT #validate 
	SELECT DISTINCT @record_id, @billing_line_count, @validate_date, @status_error,  'Invalid or missing AX GL account:  ' +
		bd.AX_MainAccount + '-' + bd.AX_Dimension_1 + '-' + bd.AX_Dimension_2 + '-' + bd.AX_Dimension_3 + '-' + bd.AX_Dimension_4 + '-' + ISNULL(bd.AX_Dimension_6, '') + '-' + 
	   ISNULL(bd.AX_Dimension_5_part_1, '') + CASE WHEN ISNULL(bd.AX_Dimension_5_part_2, '') <> '' THEN '.' + bd.AX_Dimension_5_part_2 ELSE '' END + ' (' + bd.billing_type + ').'
	FROM #billing 
	JOIN BillingDetail bd ON bd.billing_uid = #billing.billing_uid	
	JOIN #axacct a on bd.AX_MainAccount = a.AX_MainAccount and bd.AX_Dimension_1 = a.AX_Dimension_1 and bd.AX_Dimension_2 = a.AX_Dimension_2
        AND bd.AX_Dimension_3 = a.AX_Dimension_3 and  bd.AX_Dimension_4 = a.AX_Dimension_4
		AND bd.AX_Dimension_6 = a.AX_Dimension_6 and  bd.AX_Dimension_5_Part_1 = a.AX_Dimension_5_Part_1 and bd.AX_Dimension_5_Part_2 = a.AX_Dimension_5_Part_2
	WHERE #billing.record_id = @record_id
	  AND UPPER (a.status ) <> 'VALID'
   		IF @@rowcount > 0
			SET @billing_line_count = 0
 END  
 
 -- END of Receipt AX - 07/13/2016

  
	---------------------------------------
	-- Billing Links	
	---------------------------------------

--  all billing link validation is perfomed in sp_billing_validae_links rg 050809

--	IF @billing_link_id IS NOT NULL AND @billing_link_id > 0
--	BEGIN
--		SELECT @link_status = status, @link_desc = ISNULL(link_desc,'') FROM BillingLink 
--		WHERE link_id = @billing_link_id AND customer_id = @customer_id
--		IF @link_status IS NULL
--		BEGIN
--		IF @debug = 1 print '18 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
--			INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @status_warning, 
--				'Billing Link (' + CONVERT(varchar(10), @billing_link_id) + ' ' + @link_desc + ') does not exist for Customer ' + CONVERT(varchar(10), @customer_id) + '.')
--			SET @billing_line_count = 0
--
--		END
--		ELSE IF @link_status = 'O'
--		BEGIN
--		IF @debug = 1 print '19 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
--			INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @status_error, 
--				'Billing Link is still Open and there may be linked Receipts and Work Orders that have not yet been submitted to Billing. (' + CONVERT(varchar(10), @billing_link_id) + ' ' + @link_desc + ')' )
--			SET @billing_line_count = 0
--		END
--
--	END

	---------------------------------------
	-- Receipt/Work Order Links	
	---------------------------------------
--	IF @billing_link_id IS NOT NULL AND @billing_link_id = 0 AND @source_company_id IS NOT NULL 
--	IF @billing_link_id IS NOT NULL AND @source_company_id IS NOT NULL 
--	   AND @source_profit_ctr_id IS NOT NULL AND @source_id IS NOT NULL
--	IF @billing_link_id IS NOT NULL OR @trans_source = 'W'
--	BEGIN
		--  This transaction has some kind of billing link, either transaction (=0)
		--  or a real billing link ID (>0) *OR* this is a workorder transaction, which at
		--  present always has a NULL billing_link_id

--		  @workorder_ref is redundant information for the error message
--		SET @workorder_ref = CASE WHEN @source_company_id < 10 
--			  THEN '0' + CONVERT(varchar(10), @source_company_id)
--			  ELSE  CONVERT(varchar(10), @source_company_id)
--			  END
--			+ '-' 
--			+ CASE WHEN @source_profit_ctr_id < 10 
--			  THEN '0' + CONVERT(varchar(10), @source_profit_ctr_id)
--			  ELSE  CONVERT(varchar(10), @source_profit_ctr_id)
--			  END
--			+ '-' 
--			+ CONVERT(varchar(10), @source_id)

		--DevOps 39048 only call sp_billing_validate_links if @receipt_id is in BillingLinkLookup table
		--set @count_links = 0

		--select @count_links = count(1)
		--from billinglinklookup
		--where (company_id = @company_id
		--and profit_ctr_id = @profit_ctr_id
		--and receipt_id = @receipt_id)
		--or (source_company_id = @company_id
		--and source_profit_ctr_id = @profit_ctr_id
		--and source_id = @receipt_id)

		--if isnull(@count_links,0) > 0
		--begin

			-- clear out any contents in this temporary table
			TRUNCATE TABLE #link_errors
		
			-- execute the stored procedure that will lookup the appropriate
			-- transactions for this billing record to see if all of the related
			-- records are in the appropriate state (status)
			EXEC sp_billing_validate_links @debug, @company_id, @profit_ctr_id, @receipt_id, 
						@trans_source, @validate_date, @user_code
			if @debug = 1 
			begin
				 select 'calling link proc' ,@debug, @company_id, @profit_ctr_id, @receipt_id, 
						@trans_source, @validate_date, @user_code
			end
			-- if there are any records in #receipt_wo_link then those are the records
			-- that we need to show the user as validation errors
			SELECT @count_pending = COUNT(*) FROM #link_errors
	
		    IF @debug = 1 
	        BEGIN
			    PRINT '20 @count_pending: ' + CONVERT(varchar(10), @count_pending)
		        IF @count_pending > 0 
				BEGIN
					SELECT 'SELECT * FROM #link_errors'
					SELECT * FROM #link_errors
				END
		    END
			WHILE @count_pending > 0
			BEGIN
				SET ROWCOUNT 1
				SELECT 	@receipt_wo_link_status = validate_flag,
				   @source_ref = validate_message
				FROM #link_errors
				WHERE process_flag = 0
				UPDATE #link_errors SET process_flag = 1 WHERE process_flag = 0
				SET @count_pending = @count_pending - 1
				SET ROWCOUNT 0
				IF @debug = 1 print '20 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
				INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @receipt_wo_link_status, 
						                 @source_ref + '.')
--					'There are issues with Receipts/Work Orders linked for invoicing ' +
--					' (' + @source_ref + ').')
--					+ @workorder_ref + ' (' + @source_ref + ').')
				SET @billing_line_count = 1
			END
		--end
--	END
      
	---------------------------------------
	-- Required documents - 11/8/07 Lorraine, Jason, and Sheila decided that all checking
	-- 	for scanned documents happens only at the operations stage, required for
	-- 	for submitting.  No scan documents validation is done at this stage.	
	---------------------------------------
	-- Reinitialize
-- 	UPDATE #project_doc SET process_flag = 0
-- 	WHILE @count_document > 0
-- 	BEGIN
-- 		SET ROWCOUNT 1
-- 		SELECT @doc_type_id = type_id, @doc_validation = validation, @doc_type = document_type, @doc_source = trans_source
-- 		FROM #project_doc
-- 		WHERE #project_doc.customer_id = @customer_id
-- 			AND #project_doc.billing_project_id = @billing_project_id
-- 			AND #project_doc.process_flag = 0
-- 		UPDATE #project_doc SET process_flag = 1
-- 		WHERE #project_doc.customer_id = @customer_id
-- 			AND #project_doc.billing_project_id = @billing_project_id
-- 			AND #project_doc.process_flag = 0
-- 		SET @count_document = @count_document - 1
-- 		SET ROWCOUNT 0
-- 
-- 		IF @doc_source <> @trans_source
-- 			SET @scan_count = 1
-- 		ELSE
-- 			SELECT @scan_count = COUNT(*) FROM #scan_doc 
-- 			WHERE #scan_doc.company_id = @company_id
-- 			AND #scan_doc.profit_ctr_id = @profit_ctr_id
-- 			AND #scan_doc.source_type = @trans_source
-- 			AND #scan_doc.source_id = @receipt_id
-- 			AND #scan_doc.type_id = @doc_type_id
-- 		
-- 		IF @debug = 1 print 'Checking doc_type: ' + convert(varchar(10), @doc_type_id) + ' scan_count: ' + convert(varchar(10), @scan_count)
-- 
-- 		IF @scan_count = 0
-- 		BEGIN
-- 			INSERT #validate VALUES (@record_id, @billing_line_count, @validate_date, @doc_validation, 
-- 				@source_type + ' ' + @doc_type + ' has not been scanned.')
-- 			SET @billing_line_count = 0
-- 		END
-- 	END 

CONTINUE_PROCESSING:

	-- Special handling for workorders
	IF @trans_source = 'W'
	BEGIN
		-- Make a complete set of any errors and warnings for each line of the workorder
		IF @debug = 1 print '22 @billing_line_count: ' + CONVERT(varchar(10), @billing_line_count)
		INSERT #validate SELECT #billing.record_id, V2.billing_line_count, V2.validate_date, 
			V2.validate_status, V2.validate_message
		FROM #billing, #validate V2
		WHERE #billing.company_id = @company_id
		AND #billing.profit_ctr_id = @profit_ctr_id
		AND #billing.receipt_id = @receipt_id
		AND #billing.record_id <> @record_id
		AND V2.record_id = @record_id

		-- Show all lines as processed
		UPDATE #billing SET process_flag = 1
		WHERE #billing.company_id = @company_id
		AND #billing.profit_ctr_id = @profit_ctr_id
		AND #billing.receipt_id = @receipt_id
	END

	-- Mark this receipt line as processed
	ELSE
		UPDATE #billing SET process_flag = 1 WHERE record_id = @record_id

	-- Reset the number of lines to process
	SELECT @billing_count = COUNT(*) FROM #billing WHERE process_flag = 0
END


-- done looping through records so now process the erros and return results


------------------------------------------------------------------
-- Run this for Wal-Mart to set pricing correctly for receipts
-- before and after 6-1-08.
------------------------------------------------------------------
--EXEC eqsp_billing_validate_walmart 0
------------------------------------------------------------------
-- Removed 8/12/08 per Brie McDoniel since all billing is complete
-- for transactions < 6-1-08.
------------------------------------------------------------------


-- Insert a validation record for success if nothing has been entered so far
INSERT #validate 
SELECT #billing.record_id, 1, @validate_date, @status_good, ''
FROM #billing 
WHERE #billing.record_id NOT IN (SELECT DISTINCT record_id FROM #validate)

IF @debug = 1 
BEGIN
	print 'selecting all validate records'
	select 'select * from #validate order by record_id'
	select * from #validate order by record_id
END

-- Set the treeview check/uncheck status for billing lines
-- Set errors, warnings, and then good validation lines
UPDATE #billing SET 
	treeview_billing_line_check = @check_never
WHERE EXISTS (SELECT 1 FROM #validate
	WHERE #validate.record_id = #billing.record_id
	AND #validate.validate_status = @status_error)
AND #billing.treeview_billing_line_check IS NULL

IF @debug = 1 
BEGIN
	print 'selecting from #billing - set billing line check never'
	select 'select * from #billing'
	select * from #billing
END

-- From the billing lines that have errors, hold back a whole
-- receipt, all receipt lines that are being currently being processed.
INSERT #receipt
SELECT DISTINCT
#billing.company_id,
#billing.profit_ctr_id,
#billing.trans_source,
#billing.receipt_id
FROM #billing
WHERE #billing.treeview_billing_line_check = @check_never

IF @debug = 1 
BEGIN
	print 'selecting from #receipt'
	select 'select * from #receipt'
	select * from #receipt
END

UPDATE #billing SET
	treeview_billing_line_check = @check_never
FROM #receipt
WHERE #receipt.company_id = #billing.company_id
	AND #receipt.profit_ctr_id = #billing.profit_ctr_id
	AND #receipt.trans_source = #billing.trans_source
	AND #receipt.receipt_id = #billing.receipt_id
	AND #billing.treeview_billing_line_check IS NULL

IF @debug = 1 
BEGIN
	print 'selecting from #billing - set billing line check never on receipt level'
	select 'select * from #billing'
	select * from #billing
END 

-- Set billing lines that can be checked with warnings
UPDATE #billing SET 
	treeview_billing_line_check = @check_OK
WHERE EXISTS (SELECT 1 FROM #validate
	WHERE #validate.record_id = #billing.record_id
	AND #validate.validate_status = @status_warning)
AND #billing.treeview_billing_line_check IS NULL

-- Set billing lines that should be initialized for acceptance
UPDATE #billing SET 
	treeview_billing_line_check = @check_init
WHERE EXISTS (SELECT 1 FROM #validate
	WHERE #validate.record_id = #billing.record_id
	AND #validate.validate_status = @status_good)
AND #billing.treeview_billing_line_check IS NULL

-- Set the treeview check/uncheck status at the facility level
TRUNCATE TABLE #treeview_check
INSERT #treeview_check (customer_id, company_id, profit_ctr_id, error_count, warning_count, good_count)
SELECT 	#billing.customer_id,
	#billing.company_id,
	#billing.profit_ctr_id,
	ISNULL(SUM(CASE treeview_billing_line_check WHEN @check_never THEN 1 ELSE 0 END),0) as error_count,
	ISNULL(SUM(CASE treeview_billing_line_check WHEN @check_ok THEN 1 ELSE 0 END),0) as warning_count,
	ISNULL(SUM(CASE treeview_billing_line_check WHEN @check_init THEN 1 ELSE 0 END),0) as good_count
FROM #billing
GROUP BY
	#billing.customer_id,
	#billing.company_id,
	#billing.profit_ctr_id

-- If all lines are good, Initialize the facility to be checked ON
UPDATE #billing SET 
	treeview_facility_check = @check_init
FROM #treeview_check
WHERE 	#billing.customer_id = #treeview_check.customer_id
	AND #billing.company_id = #treeview_check.company_id
	AND #billing.profit_ctr_id = #treeview_check.profit_ctr_id
	AND #treeview_check.good_count > 0
	AND #treeview_check.error_count = 0
	AND #treeview_check.warning_count = 0
	AND #billing.treeview_facility_check IS NULL

-- If any lines are errors, prevent the facility to be checked
UPDATE #billing SET 
	treeview_facility_check = @check_never
FROM #treeview_check
WHERE #billing.customer_id = #treeview_check.customer_id
	AND #billing.company_id = #treeview_check.company_id
	AND #billing.profit_ctr_id = #treeview_check.profit_ctr_id
	AND #treeview_check.good_count = 0
	AND #treeview_check.error_count > 0
	AND #treeview_check.warning_count = 0
	AND #billing.treeview_facility_check IS NULL

-- For all others, allow the facility to be checked
UPDATE #billing SET 
	treeview_facility_check = @check_ok
FROM #treeview_check
WHERE #billing.treeview_facility_check IS NULL

-- Set the treeview check/uncheck status at the customer level
TRUNCATE TABLE #treeview_check
INSERT #treeview_check (customer_id, error_count, warning_count, good_count)
SELECT #billing.customer_id,
	ISNULL(SUM(CASE treeview_facility_check WHEN @check_never THEN 1 ELSE 0 END),0) as error_count,
	ISNULL(SUM(CASE treeview_facility_check WHEN @check_ok THEN 1 ELSE 0 END),0) as warning_count,
	ISNULL(SUM(CASE treeview_facility_check WHEN @check_init THEN 1 ELSE 0 END),0) as good_count
FROM #billing
GROUP BY #billing.customer_id

-- If all lines are good, Initialize the customer to be checked ON
UPDATE #billing SET 
	treeview_customer_check = @check_init
FROM #treeview_check
WHERE #billing.customer_id = #treeview_check.customer_id
	AND #treeview_check.good_count > 0
	AND #treeview_check.error_count = 0
	AND #treeview_check.warning_count = 0
	AND #billing.treeview_customer_check IS NULL

-- If all lines are errors, prevent the customer to be checked
UPDATE #billing SET 
	treeview_customer_check = @check_never
FROM #treeview_check
WHERE  #billing.customer_id = #treeview_check.customer_id
	AND #treeview_check.good_count = 0
	AND #treeview_check.error_count > 0
	AND #treeview_check.warning_count = 0
	AND #billing.treeview_customer_check IS NULL

-- For all others, allow the facility to be checked
UPDATE #billing SET 
	treeview_customer_check = @check_ok
FROM #treeview_check
WHERE #billing.treeview_customer_check IS NULL

IF @debug = 1 
BEGIN
	print 'selecting from #billing - all levels set for check/uncheck'	
	select 'select * from #billing'
	select * from #billing
	print 'selecting from #all_linked'
	select 'select * from #all_linked'
	select * from #all_linked
END

insert #final_linked
select distinct 
	b.company_id,
	b.profit_ctr_id,
	b.receipt_id,
	b.customer_id,
	al.source_type,
	al.source_company_id,
	al.source_profit_ctr_id,
	al.source_id,
	al.link_billing_date,
	al.link_status,
	al.workorder_type_desc,
	al.source_submitted_name,
	al.source_submitted_date
from #all_linked al 
join #billing b on b.receipt_id = al.receipt_id 
where al.trans_source <> al.source_type
group by
	b.company_id,
	b.profit_ctr_id,
	al.source_id,
	al.source_type,
	b.customer_id,
	al.source_company_id,
	al.source_profit_ctr_id,
	al.receipt_id,
	b.receipt_id,
	al.workorder_type_desc,
	al.source_submitted_name,
	al.link_status,
	al.link_billing_date,
	al.source_submitted_date
 
IF @debug = 1 
begin
	print 'selecting from #final_linked'
	select 'select * from #final_linked'
	select * from #final_linked
	select 'select * from #link_errors'
	select * from #link_errors
end

--DevOps 19274
UPDATE #billing SET #billing.trans_workorder_type_desc = woth.account_desc
FROM #billing l
INNER JOIN WorkorderHeader woh ON woh.workorder_id = l.receipt_id  
	AND woh.profit_ctr_id = l.profit_ctr_id 
	AND woh.company_id = l.company_id 
	--AND woh.workorder_status = 'A'
	--AND woh.submitted_flag = 'T'
INNER JOIN WorkOrderTypeHeader woth ON woth.workorder_type_id = woh.workorder_type_id
WHERE  l.trans_source = 'W'

-- Return Results into the work table 
INSERT work_BillingValidate (
	customer_id,   
	company_id,   
	profit_ctr_id,   
	trans_source,   
	receipt_id,   
	line_id,   
	price_id,   
	status_code,   
	billing_date,
	approval_code,
	manifest,
	waste_code,
	bill_unit_code,
	sr_type_code,
	quantity,   
	sr_price,   
	price,   
	total_extended_amt,   
	trans_type,
	workorder_resource_type,
	workorder_sequence_id,  
	profit_ctr_name, 
	generator_epa_id,
	generator_name,  
	cust_name,
	bill_to_cust_name,
	bill_to_addr1,
	bill_to_addr2,
	bill_to_addr3,
	bill_to_addr4,
	bill_to_addr5,
	bill_to_city,
	bill_to_state,
	bill_to_zip_code,
	bill_to_country,
	billing_date_added, 
	billing_added_by,
	billing_project_id, 
	project_name,
	record_id,
	sort_order,
	validate_status,
	treeview_customer_check,
	treeview_facility_check,
	treeview_billing_line_check,
	item_checked,
	billing_line_count,
	validate_message,
	min_line,
	validate_date,
	user_code,
	currency_code,	
	source_id,
	source_type,
	source_company_id,
	source_profit_ctr_id,
	workorder_type_desc,
	source_billing_date,
    source_submitted_flag,
    source_date_submitted,
	source_submitted_name,
	customer_service_rep,
	generator_id,
	trans_workorder_type_desc
)
SELECT DISTINCT
	#billing.customer_id,   
	#billing.company_id,   
	#billing.profit_ctr_id,   
	#billing.trans_source,   
	#billing.receipt_id,   
	#billing.line_id,   
	#billing.price_id,   
	#billing.status_code,   
	#billing.billing_date,
	#billing.approval_code,
	#billing.manifest,
	#billing.waste_code,
	#billing.bill_unit_code,
	#billing.sr_type_code,
	#billing.quantity,   
	#billing.sr_price,   
	#billing.price,   
	--CASE WHEN #validate.billing_line_count = 1 THEN #billing.total_extended_amt ELSE 0 END,   
	#billing.total_extended_amt,   
	#billing.trans_type,
	#billing.workorder_resource_type,
	#billing.workorder_sequence_id,  
	Profitcenter.profit_ctr_name,
	Generator.epa_id,
	Generator.generator_name,   
	Customer.cust_name,
	ISNULL(Customer.bill_to_cust_name,''),
	ISNULL(Customer.bill_to_addr1,''),
	ISNULL(Customer.bill_to_addr2,''),
	ISNULL(Customer.bill_to_addr3,''),
	ISNULL(Customer.bill_to_addr4,''),
	ISNULL(Customer.bill_to_addr5,''),
	ISNULL(Customer.bill_to_city,''),
	ISNULL(Customer.bill_to_state,''),
	ISNULL(Customer.bill_to_zip_code,''),
	ISNULL(Customer.bill_to_country,''),
	#billing.billing_date_added, 
	billing_added_by = (select u.user_name from users u where u.user_code = #billing.billing_added_by), --#billing.billing_added_by,
	#billing.billing_project_id, 
	ISNULL(CustomerBilling.project_name,''),
	#validate.record_id,
	CASE #validate.validate_status WHEN 'E' THEN 1 WHEN 'W' THEN 2 ELSE 3 END as sort_order,
	#validate.validate_status,
	#billing.treeview_customer_check,
	#billing.treeview_facility_check,
	#billing.treeview_billing_line_check,
	#billing.item_checked,
	#validate.billing_line_count,
	#validate.validate_message,
	CASE WHEN #billing.trans_source = 'W' THEN #minline.min_line ELSE #billing.line_id END,
	#validate.validate_date,
	@user_code,
	isnull(#billing.currency_code,''),
	#final_linked.source_id,
	ISNULL (#final_linked.source_type,''),
	#final_linked.source_company_id, 
	#final_linked.source_profit_ctr_id, 
	ISNULL (#final_linked.workorder_type_desc,''),
	#final_linked.link_billing_date,
    ISNULL (#final_linked.link_status,''),
    #final_linked.source_submitted_date,
	source_submitted_name = ( select u.user_name from users u where u.user_code = #final_linked.source_submitted_name), --#final_linked.source_submitted_name , 
	ISNULL (#billing.customer_service_rep,''),
	generator.generator_id,
	isnull(#billing.trans_workorder_type_desc,'')
FROM #billing
JOIN ProfitCenter 
	ON #billing.company_id = ProfitCenter.company_id
	AND #billing.profit_ctr_id = ProfitCenter.profit_ctr_id
JOIN Customer
	ON #billing.customer_id = Customer.customer_id
JOIN CustomerBilling
	ON #billing.customer_id = CustomerBilling.customer_id
	AND #billing.billing_project_id = CustomerBilling.billing_project_id
JOIN #validate
	ON #billing.record_id = #validate.record_id
JOIN #minline
	ON #billing.company_id = #minline.company_id
	AND #billing.profit_ctr_id = #minline.profit_ctr_id
	AND #billing.receipt_id = #minline.receipt_id
--DevOps 19274 AGC 07/26/2022 comment out join to #link_errors
--LEFT OUTER JOIN #link_errors
--	ON  #billing.receipt_id = #link_errors.receipt_id
LEFT OUTER JOIN #final_linked on
	 --#link_errors.receipt_id = #final_linked.receipt_id
	 #billing.receipt_id = #final_linked.receipt_id
LEFT OUTER JOIN Generator
	ON #billing.generator_id = Generator.generator_id
GO


GRANT EXECUTE
    ON OBJECT::[dbo].[sp_billing_validate] TO [EQAI]

GO