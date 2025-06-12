CREATE PROCEDURE sp_rpt_container_dump_log
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@customer_id_from	int
,	@customer_id_to		int
,	@location			varchar(15)
,	@staging_row_in		varchar(5)
AS
/***************************************************************************************
PB Objects: r_container_dump_log
10/29/2010 SK	created on Plt_AI
08/21/2013 SM	Added wastecode table and displaying Display name


sp_rpt_container_dump_log 14, 4, '2-01-04', '2-20-04', 1, 999999, 'WMLIVEOAK', 'ALL'
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED


 SELECT	
	Container.receipt_id
,	Container.line_id
,	Receipt.container_count
,	ContainerDestination.disposal_date
,	Receipt.manifest
,	Receipt.approval_code
,	w.display_name as waste_code
,	Container.company_id
,	Container.profit_ctr_id
,	Receipt.receipt_date
,	Receipt.bill_unit_code
,	ContainerDestination.location
,	Container.staging_row
,	Company.company_name
,	ProfitCenter.profit_ctr_name
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = Receipt.company_id
	AND ProfitCenter.profit_ctr_ID = Receipt.profit_ctr_id
JOIN Container
	ON Container.company_id = Receipt.company_id
	AND Container.profit_ctr_id = Receipt.profit_ctr_id
	AND Container.receipt_id = Receipt.receipt_id
	AND Container.line_id = Receipt.line_id
	AND Container.container_type = 'R'
	AND (@staging_row_in = 'ALL' OR Container.staging_row = @staging_row_in)
JOIN ContainerDestination
	ON ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.container_id = Container.container_id
	AND ContainerDestination.disposal_date > Receipt.receipt_date
	AND ContainerDestination.disposal_date BETWEEN @date_from AND @date_to
	AND (@location = 'ALL' OR ContainerDestination.location = @location)
LEFT OUTER JOIN WasteCode w
	ON w.waste_code_uid = receipt.waste_code_uid
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id )
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
 	AND Receipt.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND Receipt.bulk_flag = 'F'
	AND Receipt.receipt_status = 'A'
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_container_dump_log] TO [EQAI]
    AS [dbo];

