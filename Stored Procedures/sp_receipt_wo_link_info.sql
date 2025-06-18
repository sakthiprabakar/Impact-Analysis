CREATE PROCEDURE [dbo].[sp_receipt_wo_link_info]
	@debug			int,
	@receipt_company_id	int,
	@receipt_profit_ctr_id	int,
	@receipt_id		int,
	@trans_source   char(1) 
AS
/***************************************************************************************
Filename:	L:\Apps\SQL\EQAI\sp_receipt_wo_link_info.sql
Loads to:	PLT_AI

This stored procedure displays information about the receipt that is linked to a workorder. 
Called from the Workorder screen

07/30/2007 SCC	Created
10/16/2007 SCC	Removed db references
02/19/2008 WAC	Only return workorderdetail records where manifest <> ''.
06/19/2008 RG	removed manifest restriction on workorder and changed to outer join
12/23/2010 KAM	Also returned the PO Number
07/09/2014 AM   Removed plt_ai and added company join.
04/04/2025 Umesh US127218: Inbound Receipt > Add Column to the 'Related Work Order Information' Window.

sp_receipt_wo_link_info 1, 14, 0, 9128300,'W'
****************************************************************************************/
DECLARE	@receipt_company	varchar(2),
		@billing_status		char(1),
		@sql				varchar(2000)

CREATE TABLE #tmp (
	company_id	int NULL,
	profit_ctr_id	int NULL,
	receipt_id	int NULL,
	customer_id	int NULL,
	generator_id	int NULL,
	approval_code	varchar(50) NULL,
	receipt_date	datetime NULL,
	status		varchar(20) NULL,
	manifest	varchar(15) NULL,
	billing_link_id	int NULL,
	trans_mode	char(1) NULL,
	purchase_order varchar(20),
	billing_project_id int
)

-- Setup company database references
SET @receipt_company = CASE WHEN @receipt_company_id < 10 
	THEN '0' + CONVERT(varchar(1), @receipt_company_id) 
	ELSE CONVERT(varchar(2), @receipt_company_id) END
    if @trans_source = 'R'
BEGIN
	SET @sql = 'INSERT #tmp(company_id, '  
		+ ' profit_ctr_id,  '
		+ ' receipt_id,  '
		+ ' customer_id,  '
		+ ' generator_id,  '
		+ ' approval_code,  '
		+ ' receipt_date,  '
		+ ' status,  '
		+ ' manifest, ' 
		+ ' billing_link_id,  '
		+ ' trans_mode,  '
		+ ' purchase_order, '
		+ ' billing_project_id) ' 
	+ 'SELECT DISTINCT '  
		+ ' Receipt.company_id, '
		+ ' Receipt.profit_ctr_id, '
		+ ' Receipt.receipt_id, '
		+ ' Receipt.customer_id, '
		+ ' Receipt.generator_id, '
		+ ' CASE Receipt.trans_mode WHEN ''I'' THEN Receipt.approval_code ELSE Receipt.tsdf_approval_code END, '
		+ ' Receipt.receipt_date, '
		+ ' CASE Receipt.submitted_flag WHEN ''T'' THEN ''Submitted'' ELSE '
		+ '   CASE Receipt.receipt_status WHEN ''N'' THEN ''New'' WHEN ''L'' THEN ''In the Lab'' WHEN ''U'' THEN ''Unloading'' WHEN ''A'' THEN ''Accepted''  when ''H'' then ''HOLD'' END END, '
		+ ' Receipt.manifest, '
		+ ' Receipt.billing_link_id,  ' 
		+ ' Receipt.trans_mode,  ' 
		+ ' Receipt.purchase_order,  '  
		+ ' Receipt.billing_project_id ' 
	+ ' FROM Receipt '
	+ ' WHERE Receipt.company_id = ' + convert(varchar(2), @receipt_company_id)
		+ ' AND Receipt.profit_ctr_id = ' + convert(varchar(2), @receipt_profit_ctr_id)
		+ ' AND Receipt.receipt_id = ' + convert(varchar(15), @receipt_id)
END
    
    if @trans_source = 'W'
BEGIN
	SET @sql = 'INSERT #tmp(company_id, '  
		+ ' profit_ctr_id,  '
		+ ' receipt_id,  '
		+ ' customer_id,  '
		+ ' generator_id,  '
		+ ' approval_code,  '
		+ ' receipt_date,  '
		+ ' status,  '
		+ ' manifest, ' 
		+ ' billing_link_id,  '
		+ ' trans_mode,  '
		+ ' purchase_order, '
		+ ' billing_project_id) ' 
	+ 'SELECT DISTINCT '  
		+ ' WorkorderHeader.company_id, '
		+ ' WorkorderHeader.profit_ctr_id, '
		+ ' WorkorderHeader.workorder_id, '
		+ ' WorkorderHeader.customer_id, '
		+ ' WorkorderHeader.generator_id, '
		+ ' WorkorderDetail.tsdf_approval_code , '
		+ ' WorkorderHeader.start_date, '
		+ ' CASE WorkorderHeader.submitted_flag WHEN ''T'' THEN ''Submitted'' ELSE '
		+ '   CASE WorkorderHeader.workorder_status WHEN ''N'' THEN ''New'' WHEN ''C'' THEN ''Complete'' WHEN ''P'' THEN ''Pricedg'' WHEN ''A'' THEN ''Accepted'' when ''H'' then ''Hold'' when ''D'' then ''Dispatched'' END END, '
		+ ' WorkorderDetail.manifest, '
		+ ' WorkorderHeader.billing_link_id,  ' 
		+ ' ''W'' as trans_mode,  ' 
		+ ' WorkorderHeader.purchase_order,  '  
		+ ' WorkorderHeader.billing_project_id '		
	+ ' FROM WorkorderHeader '
    + ' LEFT OUTER JOIN WorkorderDetail '
        + ' ON WorkorderHeader.workorder_id = WorkorderDetail.workorder_id '
        + ' AND Workorderheader.company_id = WorkorderDetail.company_id ' 
        + ' AND Workorderheader.profit_ctr_id = WorkorderDetail.profit_ctr_id ' 
	+ ' WHERE WorkorderHeader.company_id = ' + convert(varchar(2), @receipt_company_id)
		+ ' AND WorkorderHeader.profit_ctr_id = ' + convert(varchar(2), @receipt_profit_ctr_id)
		+ ' AND WorkorderHeader.workorder_id = ' + convert(varchar(15), @receipt_id)
		+ ' '
END
IF @debug = 1 print @sql

EXECUTE (@sql)

    select @billing_status = isnull(max(billing.status_code),'') from Billing
    where Billing.receipt_id = @receipt_id
      and Billing.profit_ctr_id = @receipt_profit_ctr_id
      and Billing.company_id = @receipt_company_id
      and Billing.trans_source = @trans_source
      and Billing.status_code <> 'V'

select #tmp.company_id,  
		#tmp.profit_ctr_id,
		#tmp.receipt_id,
		#tmp.customer_id,
		#tmp.generator_id,
		#tmp.approval_code,
		#tmp.receipt_date,
		#tmp.status,
		#tmp.manifest,
		#tmp.billing_link_id,
		#tmp.trans_mode,
		#tmp.purchase_order,
		Customer.cust_name, 
		Generator.epa_id, 
		Generator.generator_name, 
		BillingLink.link_desc, 
		@billing_status as billing_status,
		#tmp.billing_project_id,
		CustomerBilling.project_name
FROM #tmp
JOIN Customer
	ON #tmp.customer_id = Customer.customer_id
Left OUTER JOIN Generator
	ON #tmp.generator_id = Generator.generator_id
LEFT OUTER JOIN BillingLink
	ON #tmp.billing_link_id = BillingLink.link_id
LEFT OUTER JOIN CustomerBilling WITH (NOLOCK)
 ON #tmp.customer_id = CustomerBilling.customer_id
 AND #tmp.billing_project_id = CustomerBilling.billing_project_id

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_receipt_wo_link_info] TO [EQAI]
    AS [dbo];

