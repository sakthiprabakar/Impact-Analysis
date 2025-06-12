CREATE PROCEDURE sp_batch_bulk 
	@company_id		int
,	@profit_ctr_id	int
,	@location		varchar(15)
,	@tracking_num	varchar(15)
,	@cycle			int
AS

/*****************************************************************************

PB Object(s):	r_batch_bulk_sp

09/30/2005 JDB	Created
05/05/2006 MK	Modified quantity - multiply by containerdestination container_percentage
12/06/2010 SK	Added company_id as input arg, fixed *= joins, added joins to company_id
				Moved to Plt_AI


sp_batch_bulk 21, 0, '702', '12575', 1
*****************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT DISTINCT
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id, 
	ContainerDestination.container_id,
	ContainerDestination.container_type,
	ISNULL(Receipt.bill_unit_code, dbo.fn_receipt_bill_unit(Receipt.receipt_id, Receipt.line_id, Receipt.profit_ctr_id, Receipt.company_id)) AS bill_unit_code,
	Receipt.receipt_date,
	Receipt.quantity * ContainerDestination.container_percent / 100 as quantity,
	ContainerDestination.treatment_id,
	Receipt.receipt_status,
	Treatment.treatment_desc,
	Receipt.approval_code,
	IsNull(Generator.EPA_ID,'') AS EPA_ID,
	IsNull(Generator.generator_name,'') AS generator_name,
	Receipt.manifest,
	dbo.fn_container_receipt(ContainerDestination.receipt_id, ContainerDestination.line_id) as Container  
FROM Receipt
JOIN ContainerDestination
	ON ContainerDestination.receipt_id = Receipt.receipt_id
	AND ContainerDestination.line_id = Receipt.line_id
	AND ContainerDestination.profit_ctr_id = Receipt.profit_ctr_id
	AND ContainerDestination.company_id = Receipt.company_id
	AND ContainerDestination.location = @location
	AND ContainerDestination.tracking_num = @tracking_num
	AND ISNULL(ContainerDestination.cycle, 0) = @cycle
	AND ContainerDestination.treatment_id IS NOT NULL
	AND ContainerDestination.container_type = 'R'
LEFT OUTER JOIN Treatment
	ON Treatment.company_id = ContainerDestination.company_id
	AND Treatment.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
WHERE Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.company_id = @company_id
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status = 'A'
	AND Receipt.bulk_flag = 'T'

UNION ALL

SELECT	ContainerDestination.receipt_id, 
	ContainerDestination.line_id, 
	ContainerDestination.container_id,
	ContainerDestination.container_type,
	ISNULL(Receipt.bill_unit_code, dbo.fn_receipt_bill_unit(Receipt.receipt_id, Receipt.line_id, Receipt.profit_ctr_id, Receipt.company_id)) AS bill_unit_code,
	Receipt.receipt_date,
	Receipt.quantity * ContainerDestination.container_percent / 100,
	Receipt.treatment_id,
	Receipt.receipt_status,
	Treatment.treatment_desc,
	Receipt.approval_code,
	IsNull(Generator.EPA_ID,'') AS EPA_ID,
	IsNull(Generator.generator_name,'') AS generator_name,
	Receipt.manifest,
	dbo.fn_container_receipt(ContainerDestination.receipt_id, ContainerDestination.line_id) as Container  
FROM Receipt
JOIN ContainerDestination
	ON ContainerDestination.receipt_id = Receipt.receipt_id
	AND ContainerDestination.line_id = Receipt.line_id
	AND ContainerDestination.profit_ctr_id = Receipt.profit_ctr_id
	AND ContainerDestination.company_id = Receipt.company_id
	AND ContainerDestination.location = @location
	AND ContainerDestination.tracking_num = @tracking_num
	AND ISNULL(ContainerDestination.cycle, 0) = @cycle
	AND ContainerDestination.treatment_id IS NULL
	AND ContainerDestination.container_type = 'R'
LEFT OUTER JOIN Treatment
	ON Treatment.company_id = ContainerDestination.company_id
	AND Treatment.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Treatment.treatment_id = ContainerDestination.treatment_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
WHERE Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.company_id = @company_id
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status = 'A'
	AND Receipt.bulk_flag = 'T'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_batch_bulk] TO [EQAI]
    AS [dbo];

