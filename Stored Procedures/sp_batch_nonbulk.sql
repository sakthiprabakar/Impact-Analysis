CREATE OR ALTER PROCEDURE sp_batch_nonbulk 
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
02/18/2025 Kamendra Rally DE34898 - Fixed the join to pull the correct staging_row from Container table.
				
select * from receipt where receipt_id = 624659
select * from receiptprice where receipt_id = 624659
select * from container where receipt_id = 624659
select * from containerdestination where receipt_id = 624659

sp_batch_nonbulk 21, 0, 'OB', '3564512 SK27', 1
sp_batch_nonbulk 42, 0, 'Inorganics', '201701', 1
*****************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SELECT DISTINCT
	cd.receipt_id, 
	cd.line_id, 
	cd.container_id,
	cd.container_type,
	ISNULL(r.bill_unit_code, dbo.fn_receipt_bill_unit(r.receipt_id, r.line_id, r.profit_ctr_id, r.company_id)) AS bill_unit_code,
	r.receipt_date,   
	cd.treatment_id,
	r.receipt_status,
	t.treatment_desc,
	r.approval_code,
	ISNULL(g.EPA_ID,'') AS EPA_ID,
	ISNULL(g.generator_name,'') AS generator_name,
	r.manifest,
	dbo.fn_container_receipt(cd.receipt_id, cd.line_id) AS Container,
	c.staging_row
FROM Receipt r
JOIN Container c (NOLOCK)  
       ON c.company_id = r.company_id  
       AND c.profit_ctr_id = r.profit_ctr_id  
       AND c.receipt_id = r.receipt_id  
       AND c.line_id = r.line_id  
       AND c.container_id is not null
JOIN ContainerDestination cd
	ON cd.receipt_id = r.receipt_id
	AND cd.line_id = r.line_id
	AND cd.profit_ctr_id = r.profit_ctr_id
	AND cd.company_id = r.company_id
	AND cd.location = @location
	AND cd.tracking_num = @tracking_num
	AND ISNULL(cd.cycle, 0) = @cycle
	AND cd.treatment_id IS NOT NULL
	AND cd.container_type = 'R'
	AND cd.container_id = c.container_id
LEFT OUTER JOIN Treatment t
	ON t.company_id = cd.company_id
	AND t.profit_ctr_id = cd.profit_ctr_id
	AND t.treatment_id = cd.treatment_id
LEFT OUTER JOIN Generator g
	ON g.generator_id = r.generator_id
WHERE r.profit_ctr_id = @profit_ctr_id
	AND r.company_id = @company_id
	AND r.trans_type = 'D'
	AND r.trans_mode = 'I'
	AND r.fingerpr_status = 'A'
	AND r.bulk_flag = 'F'

UNION ALL

SELECT 
	cd.receipt_id, 
	cd.line_id, 
	cd.container_id,
	cd.container_type,
	r.bill_unit_code,
	r.receipt_date,   
	r.treatment_id,
	r.receipt_status,
	t.treatment_desc,
	r.approval_code,
	ISNULL(g.EPA_ID,'') AS EPA_ID,
	ISNULL(g.generator_name,'') AS generator_name,
	r.manifest,
	dbo.fn_container_receipt(cd.receipt_id, cd.line_id) AS Container ,
	c.staging_row
FROM Receipt r
JOIN Container c (NOLOCK)  
       ON c.company_id = r.company_id  
       AND c.profit_ctr_id = r.profit_ctr_id  
       AND c.receipt_id = r.receipt_id  
       AND c.line_id = r.line_id  
       AND c.container_id is not null 
JOIN ContainerDestination cd
	ON cd.receipt_id = r.receipt_id
	AND cd.line_id = r.line_id
	AND cd.profit_ctr_id = r.profit_ctr_id
	AND cd.company_id = r.company_id
	AND cd.location = @location
	AND cd.tracking_num = @tracking_num
	AND ISNULL(cd.cycle, 0) = @cycle
	AND cd.treatment_id IS NULL
	AND cd.container_type = 'R'
	AND cd.container_id = c.container_id
LEFT OUTER JOIN Treatment t
	ON t.company_id = r.company_id
	AND t.profit_ctr_id = r.profit_ctr_id
	AND t.treatment_id = r.treatment_id
LEFT OUTER JOIN Generator g
	ON g.generator_id = r.generator_id
WHERE r.profit_ctr_id = @profit_ctr_id
	AND r.company_id = @company_id
	AND r.trans_type = 'D'
	AND r.trans_mode = 'I'
	AND r.fingerpr_status = 'A'
	AND r.bulk_flag = 'F'

UNION ALL

SELECT cd.receipt_id, 
	cd.line_id, 
	cd.container_id,
	cd.container_type,
--	'DM55' AS bill_unit_code,
	CASE c.container_size WHEN NULL THEN 'DM55' WHEN '' THEN 'DM55' ELSE c.container_size END as bill_unit_code,
	cd.date_added,   
	cd.treatment_id,
	cd.status,
	t.treatment_desc,
	'' AS approval_code,
	'' AS EPA_ID,
	'' AS generator_name,
	'' AS manifest,
	dbo.fn_container_stock(cd.line_id, cd.company_id, cd.profit_ctr_id),
	c.staging_row
FROM ContainerDestination cd
JOIN Container c
	ON c.profit_ctr_id = cd.profit_ctr_id
	AND c.company_id = cd.company_id
	AND c.receipt_id = cd.receipt_id
	AND c.container_type = cd.container_type
	AND c.line_id = cd.line_id
	AND c.container_id = cd.container_id
LEFT OUTER JOIN Treatment t
	ON t.treatment_id = cd.treatment_id
	AND t.profit_ctr_id = cd.profit_ctr_id
	AND t.company_id = cd.company_id
WHERE cd.location = @location
	AND cd.tracking_num = @tracking_num
	AND cd.profit_ctr_id = @profit_ctr_id
	AND cd.company_id = @company_id
	AND ISNULL(cd.cycle, 0) = @cycle
	AND cd.container_type = 'S'

GO

GRANT EXECUTE
    ON [dbo].[sp_batch_nonbulk] TO [EQAI];

