
CREATE PROCEDURE sp_rpt_batch_missing_bulkload 
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@location			varchar(15)
AS

/***********************************************************************
Filename:	L:\Apps\SQL\EQAI\sp_rpt_batch_missing_bulkload.sql
PB Object(s):	r_batch_missing
	
10/18/2010 SK	Created on Plt_AI

sp_rpt_batch_missing_bulkload 21, 0, '08/01/10', '8/31/10', 'ALL'
***********************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

 
SELECT DISTINCT 
	Receipt.receipt_id
,	Receipt.line_id
,	Receipt.company_id
,	Receipt.profit_ctr_id
,	Receipt.receipt_status
,	Receipt.receipt_date
,	Generator.generator_name
,	Receipt.quantity
,	IsNull(Receipt.bill_unit_code, 'Various') as bill_unit_code
,	Receipt.manifest
,	Receipt.manifest_line_id
,	Receipt.approval_code
,	Receipt.treatment_id
,	Treatment.treatment_desc
,	Company.company_name
,	ProfitCenter.profit_ctr_name  
FROM Receipt
JOIN Company
	ON Company.company_id = Receipt.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = Receipt.company_id
	AND ProfitCenter.profit_ctr_id = Receipt.profit_ctr_id
JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
JOIN Container
	ON Container.receipt_id = Receipt.receipt_id
	AND Container.line_id = Receipt.line_id
	AND Container.company_id = Receipt.company_id
	AND Container.profit_ctr_id = Receipt.profit_ctr_id
	AND Container.status = 'N'
JOIN ContainerDestination
	ON ContainerDestination.receipt_id = Container.receipt_id
	AND ContainerDestination.line_id = Container.line_id
	AND ContainerDestination.container_id = Container.container_id
	AND ContainerDestination.container_type = Container.container_type
	AND ContainerDestination.company_id = Container.company_id
	AND ContainerDestination.profit_ctr_id = Container.profit_ctr_id
	AND ContainerDestination.status = 'N'
	AND IsNull(ContainerDestination.location_type,'U') IN ('O','P','U')
	AND (@location = 'ALL' OR ContainerDestination.location = @location)
LEFT OUTER JOIN Treatment
	ON Treatment.company_id = ContainerDestination.company_id
	AND Treatment.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
WHERE	(@company_id = 0 OR Receipt.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR Receipt.profit_ctr_id = @profit_ctr_id)
	AND Receipt.receipt_date between @date_from AND @date_to
	AND Receipt.bulk_flag = 'T'
	AND Receipt.trans_mode = 'I'
	AND Receipt.trans_type = 'D'
	AND Receipt.receipt_status IN ('N','L','U','A')

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_batch_missing_bulkload] TO [EQAI]
    AS [dbo];

