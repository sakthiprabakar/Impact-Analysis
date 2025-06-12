CREATE PROCEDURE sp_batch_nonbulk 
	@company_id		int
,	@profit_ctr_id	int
,	@location		varchar(15)
,	@tracking_num	varchar(15)
,	@cycle			int
AS

/*****************************************************************************
Filename:	L:\Apps\SQL\EQAI\sp_batch_nonbulk.sql
PB Object(s):	r_batch_nonbulk_sp


09/30/2005 JDB	Created
12/06/2010 SK	Added company_id as input arg, fixed *= joins, added joins to company_id
				Moved to Plt_AI
11/10/2017 MPM	Updated the bill unit for stock containers
04/10/2024 Subhrajyoti Devops# 74737 - added container joining for bringing staging_row location
				
select * from receipt where receipt_id = 624659
select * from receiptprice where receipt_id = 624659
select * from container where receipt_id = 624659
select * from containerdestination where receipt_id = 624659

sp_batch_nonbulk 21, 0, 'OB', '3564512 SK27', 1
sp_batch_nonbulk 42, 0, 'Inorganics', '201701', 1
*****************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT DISTINCT
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id, 
	ContainerDestination.container_id,
	ContainerDestination.container_type,
	ISNULL(Receipt.bill_unit_code, dbo.fn_receipt_bill_unit(Receipt.receipt_id, Receipt.line_id, Receipt.profit_ctr_id, Receipt.company_id)) AS bill_unit_code,
	Receipt.receipt_date,   
	ContainerDestination.treatment_id,
	Receipt.receipt_status,
	Treatment.treatment_desc,
	Receipt.approval_code,
	ISNULL(Generator.EPA_ID,'') AS EPA_ID,
	ISNULL(Generator.generator_name,'') AS generator_name,
	Receipt.manifest,
	dbo.fn_container_receipt(ContainerDestination.receipt_id, ContainerDestination.line_id) AS Container,
	Container.staging_row
FROM Receipt
JOIN Container (NOLOCK)  
       ON Container.company_id = Receipt.company_id  
       AND Container.profit_ctr_id = Receipt.profit_ctr_id  
       AND Container.receipt_id = Receipt.receipt_id  
       AND Container.line_id = Receipt.line_id  
       AND Container.container_id is not null 
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
	AND Receipt.bulk_flag = 'F'

UNION ALL

SELECT 
	ContainerDestination.receipt_id, 
	ContainerDestination.line_id, 
	ContainerDestination.container_id,
	ContainerDestination.container_type,
	Receipt.bill_unit_code,
	Receipt.receipt_date,   
	Receipt.treatment_id,
	Receipt.receipt_status,
	Treatment.treatment_desc,
	Receipt.approval_code,
	ISNULL(Generator.EPA_ID,'') AS EPA_ID,
	ISNULL(Generator.generator_name,'') AS generator_name,
	Receipt.manifest,
	dbo.fn_container_receipt(ContainerDestination.receipt_id, ContainerDestination.line_id) AS Container ,
	Container.staging_row
FROM Receipt
JOIN Container (NOLOCK)  
       ON Container.company_id = Receipt.company_id  
       AND Container.profit_ctr_id = Receipt.profit_ctr_id  
       AND Container.receipt_id = Receipt.receipt_id  
       AND Container.line_id = Receipt.line_id  
       AND Container.container_id is not null 
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
	ON Treatment.company_id = Receipt.company_id
	AND Treatment.profit_ctr_id = Receipt.profit_ctr_id
	AND Treatment.treatment_id = Receipt.treatment_id
LEFT OUTER JOIN Generator
	ON Generator.generator_id = Receipt.generator_id
WHERE Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.company_id = @company_id
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'
	AND Receipt.fingerpr_status = 'A'
	AND Receipt.bulk_flag = 'F'	

UNION ALL

SELECT ContainerDestination.receipt_id, 
	ContainerDestination.line_id, 
	ContainerDestination.container_id,
	ContainerDestination.container_type,
--	'DM55' AS bill_unit_code,
	CASE Container.container_size WHEN NULL THEN 'DM55' WHEN '' THEN 'DM55' ELSE Container.container_size END as bill_unit_code,
	ContainerDestination.date_added,   
	ContainerDestination.treatment_id,
	ContainerDestination.status,
	Treatment.treatment_desc,
	'' AS approval_code,
	'' AS EPA_ID,
	'' AS generator_name,
	'' AS manifest,
	dbo.fn_container_stock(ContainerDestination.line_id, ContainerDestination.company_id, ContainerDestination.profit_ctr_id),
	Container.staging_row
FROM ContainerDestination
JOIN Container
	ON Container.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Container.company_id = ContainerDestination.company_id
	AND Container.receipt_id = ContainerDestination.receipt_id
	AND Container.container_type = ContainerDestination.container_type
	AND Container.line_id = ContainerDestination.line_id
LEFT OUTER JOIN Treatment
	ON Treatment.treatment_id = ContainerDestination.treatment_id
	AND Treatment.profit_ctr_id = ContainerDestination.profit_ctr_id
	AND Treatment.company_id = ContainerDestination.company_id
WHERE ContainerDestination.location = @location
	AND ContainerDestination.tracking_num = @tracking_num
	AND ContainerDestination.profit_ctr_id = @profit_ctr_id
	AND ContainerDestination.company_id = @company_id
	AND ISNULL(ContainerDestination.cycle, 0) = @cycle
	AND ContainerDestination.container_type = 'S'


GO



GRANT EXECUTE
    ON [dbo].[sp_batch_nonbulk] TO [EQAI];

