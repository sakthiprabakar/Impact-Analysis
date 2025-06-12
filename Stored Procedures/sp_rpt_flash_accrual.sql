drop proc if exists sp_rpt_flash_accrual

go
CREATE PROCEDURE sp_rpt_flash_accrual
	@date_from				DATETIME = NULL,
	@date_to				DATETIME = NULL,
	@description				VARCHAR(80),
	@user_code				VARCHAR(10),
	@copc_list				VARCHAR(4096),
	@copc_list_with_jde			VARCHAR(4096),
	@customer_id				INT = NULL,
	@source_list				VARCHAR(5) = 'R,W,O',
	@gl_account_from			VARCHAR(13) = NULL,
	@gl_account_to				VARCHAR(13) = NULL,
	@include_only_related_gls		CHAR(1) = 'T',
	@debug_flag				INT = 0
AS
/***************************************************************
04/30/2013 rb Created
10/01/2013 rb Added waste_code_uid to #Flashwork table
03/31/2014 AM GEM:28202 ( sponsored project 28005 )  Added station_id field
11/18/2014 JDB	Replaced station ID field with reference code.
08/05/2015 JPB	Added job_type to #FlashWork table per sp_rpt_flash_calc update
01/08/2016 JPB	Added pickup_date
01/24/2017 JPB	Resized Customer_Type field and added AX Dimension fields and first_invoice_date field in #FlashWork
11/10/2020 MPM	DevOps 17889 - Added Manage Engine WorkOrderHeader.ticket_number to #FlashWork.
	
***************************************************************/
declare @id int,
	@i int,
	@initial_tran_count int,
	@error_msg varchar(255),
	@customer_id_from int,
	@customer_id_to int,
	@sql varchar(4096)

-- record initial tran count
set transaction isolation level read uncommitted
set @initial_tran_count = @@TRANCOUNT

-- create temp table for results
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
		cust_name					varchar(40)	NULL,	--	Customer	Name
		customer_type				varchar(40)	NULL,	--  Customer Type

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
		generator_name				varchar(40)	NULL,	--	Generator	Name
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


-- run the flash calc procedure
set @copc_list = replace(replace(replace(@copc_list,'-','|'),' ',''), '00', '0')
set @customer_id_from = ISNULL(@customer_id,0)
set @customer_id_to = ISNULL(@customer_id,999999)
exec sp_rpt_flash_calc
	@copc_list,
	@date_from,
	@date_to,
	@customer_id_from,
	@customer_id_to,
	NULL,				-- Customer Type List
	'N',				-- Not Invoiced
	@source_list,
	'D',				-- 'D' is passed when transaction_type='E'
	'A',				-- 'A' is passed when transaction_type='E'
	@debug_flag

if @@ERROR <> 0
begin
	set @error_msg = 'ERROR: Insert into temp table, generating result set'
	goto ON_ERROR
end	

begin transaction

-- create header record
insert EQ_Extract..FlashAccrualLog (date_from, date_to, description, copc_list, copc_list_with_jde, customer_id, source_list, gl_account_from, gl_account_to, added_by, date_added, modified_by, date_modified)
values (@date_from, @date_to, @description, @copc_list, @copc_list_with_jde, @customer_id, @source_list, @gl_account_from, @gl_account_to, @user_code, getdate(), @user_code, getdate())

if @@ERROR <> 0
begin
	set @error_msg = 'ERROR: Insert into EQ_Extract..FlashAccrualLog failed'
	goto ON_ERROR
end	

select @id = @@IDENTITY


-- save relevant fields and additional info to extract table
insert EQ_Extract..FlashAccrualReport
select @id,
	row_number() OVER (ORDER BY f.company_id),
	0,
	f.company_id,
	f.profit_ctr_id,
	f.trans_source,
	f.receipt_id,
	f.line_id,
	f.trans_date,
	f.workorder_type,
	f.trans_status,
	f.approval_code,
	f.treatment_id,
	f.treatment_process,
	f.wastetype_category,
	f.product_code,
	f.dist_flag,
	f.dist_company_id,
	f.dist_profit_ctr_id,
	f.customer_id,
	f.cust_name,
	f.invoice_date,
	f.billing_status_code,
	f.bill_unit_code,
	f.quantity,
	f.extended_amt,
	case f.trans_source when 'R' then r.manifest when 'W' then wd.manifest else '' end,
	f.JDE_BU + '-' + f.JDE_object,
	f.JDE_object,
	f.JDE_BU,
	case f.trans_source when 'R' then rp.price
				when 'W' then wd.price
				when 'O' then od.price end,
	@user_code,
	getdate(),
	@user_code,
	getdate()
from #FlashWork f
left outer join Receipt r (nolock)
	on f.company_id = r.company_id
	and f.profit_ctr_id = r.profit_ctr_id
	and f.receipt_id = r.receipt_id
	and f.line_id = r.line_id
	and f.trans_source = 'R'
left outer join ReceiptPrice rp (nolock)
	on f.company_id = rp.company_id
	and f.profit_ctr_id = rp.profit_ctr_id
	and f.receipt_id = rp.receipt_id
	and f.line_id = rp.line_id
	and f.price_id = rp.price_id
	and f.trans_source = 'R'
left outer join WorkOrderDetail wd (nolock)
	on f.company_id = wd.company_id
	and f.profit_ctr_id = wd.profit_ctr_id
	and f.receipt_id = wd.workorder_id
	and f.workorder_sequence_id = wd.sequence_id
	and f.workorder_resource_type = wd.resource_type
	and f.trans_source = 'W'
left outer join OrderDetail od (nolock)
	on f.company_id = od.company_id
	and f.profit_ctr_id = od.profit_ctr_id
	and f.receipt_id = od.order_id
	and f.line_id = od.line_id
	and f.trans_source = 'O'
left outer join Product p (nolock)
	on od.product_id = p.product_id

if @@ERROR <> 0
begin
	set @error_msg = 'ERROR: Insert into EQ_Extract..FlashAccrualReport failed'
	goto ON_ERROR
end	

-- filter gl account range if requested
if isnull(@gl_account_from,'') <> '' or isnull(@gl_account_to,'') <> ''
begin
	if isnull(@gl_account_from,'') = ''
		set @gl_account_from = '0000000-00000'

	if isnull(@gl_account_to,'') = ''
		set @gl_account_to = '9999999-99999'

	delete EQ_Extract..FlashAccrualReport
	where flash_accrual_id = @id
	and left(jde_gl_account_code,7) not between left(@gl_account_from,7) and left(@gl_account_to,7)

	delete EQ_Extract..FlashAccrualReport
	where flash_accrual_id = @id
	and right(jde_gl_account_code,5) not between right(@gl_account_from,5) and right(@gl_account_to,5)
end

-- filter only related GL accounts
if isnull(@include_only_related_gls,'F') = 'T'
begin
	select @i = charindex(char(9), @copc_list_with_jde, 1)
	while @i > 0
	begin
		if @sql is null or datalength(@sql) < 1
			set @sql = 'delete EQ_Extract..FlashAccrualReport where flash_accrual_id = ' + CONVERT(varchar(10),@id) + ' and left(jde_gl_account_code,2) not in ('
		else
			set @sql = @sql + ','

		set @sql = @sql + '''' + substring(@copc_list_with_jde,@i+1,2) + ''''

		select @i = charindex(char(9), @copc_list_with_jde, @i+1)
	end
	set @sql = @sql + ')'

	execute(@sql)
end


--
-- SUCCESS
--
if @@TRANCOUNT > @initial_tran_count
	commit transaction
drop table #FlashWork
return 0

--
-- ERROR
--
ON_ERROR:
if @@TRANCOUNT > @initial_tran_count
	rollback transaction
drop table #FlashWork
raiserror(@error_msg,16,1)
return -1

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_flash_accrual] TO [EQWEB]
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_flash_accrual] TO [COR_USER]



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_flash_accrual] TO [EQAI]

