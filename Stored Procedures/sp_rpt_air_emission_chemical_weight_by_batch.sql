CREATE PROCEDURE sp_rpt_air_emission_chemical_weight_by_batch
	@company_id			int
,	@profit_ctr_id		int
,	@date_from			datetime
,	@date_to			datetime
,	@location			varchar(15)
,	@tracking_num		varchar(15)

AS
/************************************************************************************************************  
 This SP displays the constituents that are in batches that are created and processed over time.
 
 PB object : r_air_emission_chemical_weight_by_batch
 
 Loaded to Plt_AI

 05/08/2018 MPM	Created.
 03/11/2022 AM DevOps:17098 - Added 'ug/kg', 'ppb' and 'ug/L' calculation
 05/27/2022 AM DevOPs:42195 - Corrected #tri_work_table name to #dhs_work_table
 07/06/2023 Nagaraj M Devops #67290 - Modified the ug/kg,ppb calculation from /0.0001 to * 0.000000001, and ug/L calculation from "0.001" to "* 8.3453 * 0.000000001"
 03/18/2024 KS - DevOps 78200 - Updated the logic to fetch the ReceiptConstituent.concentration as following.
				If the 'Typical' value is stored (not null), then use the 'Typical' value for reporting purposes.
				If the 'Typical' value is null and the 'Min' value is null and 'Max' is not null, then use the 'Max' value for reporting purposes.
				If the 'Typical' value is null, and the 'Min' is not null and the 'Max' is not null, then use mid-point of 'Min' and 'Max' values for reporting purposes.
				If the 'Typical' value is null, and the 'Max' value is null, but the 'Min' value is not null, then use the 'Min' value for reporting purposes.
sp_rpt_air_emission_chemical_weight_by_batch 21, 0, '01/01/2018', '05/17/2018', '702', '23366'
sp_rpt_air_emission_chemical_weight_by_batch 21, 0, '01/01/2018', '05/17/2018', '702', 'ALL'
sp_rpt_air_emission_chemical_weight_by_batch 21, 0, '02/01/2018', '05/18/2018', 'ALL', 'ALL'
sp_rpt_air_emission_chemical_weight_by_batch 21, 0, '01/01/2018', '05/17/2018', '702', '23212'
sp_rpt_air_emission_chemical_weight_by_batch 21, 0, '01/01/2018', '05/01/2018', '701', 'ALL'
sp_rpt_air_emission_chemical_weight_by_batch 21, 0, '01/01/2018', '04/30/2018', '705', '23232'

************************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE @c_company_id int
,		@c_profit_ctr_id int
,		@c_receipt_id int
,		@c_line_id int
,		@c_container_id int
,		@c_location	varchar(15)
,		@c_tracking_num	varchar(15)
,		@c_cycle int
,		@c_start_time varchar(8)
,		@c_end_time varchar(8)
,		@c_treatment_time_hours int
,		@c_batch_date date

CREATE TABLE #tmp ( 
	company_id				int			null
,	profit_ctr_id			int			null
,	location				varchar(15) null
,	tracking_num			varchar(15)	null
,	cycle					int			null
,	start_time				varchar(8)	null
,	end_time				varchar(8)	null
,	treatment_time_hours	int			null
,	receipt_id				int			null
,	line_id					int			null
,	container_id			int			null
,	container_type			char(1)		null
,	sequence_id				int			null
,	approval_code			varchar(15) null
,	hap_flag				char(1)		null
,	caavoc_flag				char(1)		null
,	air_permit_restricted_flag	char(1)	null
,	chemical				varchar(50)	null
,	const_id				int			null
,	unit					varchar(10) null
--,	quantity				float		null
--,	bill_unit_code			varchar(4)	null
--,	container_size			varchar(15) null
--,	pound_conv				float		null
,	pounds_received			float		null
,	consistency				varchar(20) null
,	c_density				float		null
--,	bulk_flag				char(1)		null
,	concentration			float		null
,	pounds_constituent		float		null
,	ppm_concentration		float		null
,	mg_constituent			float		null
,	batch_date				date		null
)
 
-- Get inbound containers that were processed into the batch(es):
INSERT INTO #tmp (
	company_id
,	profit_ctr_id
,	location
,	tracking_num
,	cycle
,	start_time
,	end_time
,	treatment_time_hours
,	receipt_id
,	line_id
,	container_id
,	container_type
,	sequence_id
,	approval_code
,	hap_flag
,	caavoc_flag
,	chemical
,	const_id
,	consistency
,	c_density
--,	bulk_flag
--,	pound_conv
,	concentration
--,	quantity
,	ppm_concentration
--,	pounds_received
,	pounds_constituent
--,	bill_unit_code
--,	container_size
,	unit
,	batch_date
,	air_permit_restricted_flag
)
-- Get receipt containers in the batch(es)
SELECT  
	b.company_id
,	b.profit_ctr_id
,	b.location
,	b.tracking_num
,	b.cycle
,	b.start_time
,	b.end_time
,	null --DATEDIFF(hour, b.start_time, b.end_time)
,	ib.receipt_id
,	ib.line_id
,	cd.container_id
,	cd.container_type
,	cd.sequence_id
,	ib.approval_code
,	isnull(c.hap, 'F') 
,	isnull(c.CAAVOC, 'F') 
,	c.const_desc 
,	c.const_id
,	pl.consistency
,	pl.density as c_density
--,	isnull(ib.bulk_flag, 'F')
--,	1000000000000 AS pound_conv
,	CASE
	WHEN rc.typical_concentration IS NOT NULL 
		THEN rc.typical_concentration  
	WHEN rc.typical_concentration IS NULL AND rc.min_concentration IS NULL AND rc.concentration IS NOT NULL 
		THEN rc.concentration
	WHEN rc.typical_concentration IS NULL AND rc.concentration IS NULL AND rc.min_concentration IS NOT NULL 
		THEN rc.min_concentration 				 
	WHEN rc.typical_concentration IS NULL AND rc.min_concentration IS NOT NULL AND rc.concentration IS NOT NULL 
		THEN (rc.min_concentration + rc.concentration)/2
	END AS concentration
--,	CASE WHEN ib.bulk_flag = 'T' THEN (ib.quantity * CONVERT(money, cd.container_percent)) / 100 
--		  ELSE (1 * CONVERT(money, cd.container_percent)) / 100 
--	END AS quantity
,	1000000000000 AS ppm_concentration
--,	1000000000000 AS pounds_received
,	1000000000000 AS pounds_constituent
--,	ib.bill_unit_code
--,	c2.container_size AS container_size
,	rc.unit
,	CONVERT(DATE, b.date_opened)
,	isnull(c.air_permit_restricted, 'F') 
FROM Batch b (NOLOCK) 
JOIN ContainerDestination cd (NOLOCK) 
	ON cd.company_id = b.company_id
	AND cd.profit_ctr_id = b.profit_ctr_id
	AND cd.location = b.location
	AND cd.tracking_num = b.tracking_num
	AND cd.cycle = b.cycle
	AND cd.container_type = 'R'
JOIN Container c2 (NOLOCK)
	ON c2.company_id = cd.company_id
	AND c2.profit_ctr_id = cd.profit_ctr_id
	AND c2.receipt_id = cd.receipt_id
	AND c2.line_id = cd.line_id
	AND c2.container_id = cd.container_id
	AND c2.container_type = cd.container_type
JOIN Receipt ib (NOLOCK) 
	ON ib.company_id = cd.company_id
	AND ib.profit_ctr_id = cd.profit_ctr_id
	AND ib.receipt_id = cd.receipt_id
	AND ib.line_id = cd.line_id
	AND ib.trans_mode = 'I'
	AND ib.trans_type = 'D'
	AND ib.receipt_status <> 'V'
JOIN ReceiptConstituent rc (NOLOCK) 
	ON ib.company_id = rc.company_id
	AND ib.profit_ctr_id = rc.profit_ctr_id
	AND ib.receipt_id = rc.receipt_id
	AND ib.line_id = rc.line_id
JOIN Constituents c (NOLOCK) 
	ON c.const_id = rc.const_id 
	AND (c.HAP = 'T' OR c.CAAVOC = 'T' OR c.air_permit_restricted = 'T' OR c.CAS_code = '7664417')
JOIN Profile p (NOLOCK)
	ON p.profile_id = ib.profile_id
	AND p.curr_status_code = 'A'
JOIN ProfileLab pl (NOLOCK)
	ON pl.profile_id = p.profile_id
	AND pl.type = 'A'
WHERE	(b.company_id = @company_id)	
	AND (b.profit_ctr_id = @profit_ctr_id)
	AND (@location = 'ALL' OR b.location = @location)
	AND (@tracking_num = 'ALL' OR b.tracking_num = @tracking_num)
	AND (b.date_opened BETWEEN @date_from AND @date_to)
	AND b.status <> 'V'
	AND NOT EXISTS (SELECT 1 FROM ContainerConstituent CC (NOLOCK)
					WHERE c2.receipt_id = CC.receipt_id 
						AND c2.line_id = CC.line_id 
						AND c2.profit_ctr_id = CC.profit_ctr_id
						AND c2.company_id = CC.company_id
						AND c2.container_id = cc.container_id
						AND c2.container_type = cc.container_type)
UNION
-- Get stock containers in the batch(es)
SELECT  
	b.company_id
,	b.profit_ctr_id
,	b.location
,	b.tracking_num
,	b.cycle
,	b.start_time
,	b.end_time
,	null --DATEDIFF(hour, b.start_time, b.end_time)
,	cd.receipt_id
,	cd.line_id
,	cd.container_id
,	cd.container_type
,	cd.sequence_id
,	'' AS approval_code
,	isnull(c.hap, 'F') 
,	isnull(c.CAAVOC, 'F') 
,	c.const_desc 
,	c.const_id
,	'' as consistency
,	0 as c_density
--,	'F' AS bulk_flag
--,	1000000000000 AS pound_conv
,	0 AS concentration
--,	(1 * CONVERT(money, cd.container_percent)) / 100 AS quantity
,	1000000000000 AS ppm_concentration
--,	1000000000000 AS pounds_received
,	1000000000000 AS pounds_constituent
--,	'' AS bill_unit_code
--,	c2.container_size AS container_size
,	'' as unit
,	CONVERT(DATE, b.date_opened)
,	isnull(c.air_permit_restricted, 'F') 
FROM Batch b (NOLOCK) 
JOIN ContainerDestination cd (NOLOCK) 
	ON cd.company_id = b.company_id
	AND cd.profit_ctr_id = b.profit_ctr_id
	AND cd.location = b.location
	AND cd.tracking_num = b.tracking_num
	AND cd.cycle = b.cycle
	AND cd.container_type = 'S'
JOIN Container c2 (NOLOCK)
	ON c2.company_id = cd.company_id
	AND c2.profit_ctr_id = cd.profit_ctr_id
	AND c2.receipt_id = cd.receipt_id
	AND c2.line_id = cd.line_id
	AND c2.container_id = cd.container_id
	AND c2.container_type = cd.container_type
JOIN ContainerConstituent cc (NOLOCK) 
	ON cc.company_id = cd.company_id
	AND cc.profit_ctr_id = cd.profit_ctr_id
	AND cc.receipt_id = cd.receipt_id
	AND cc.line_id = cd.line_id
	AND cc.container_id = cd.container_id
	AND cc.container_type = cd.container_type
JOIN Constituents c (NOLOCK) 
	ON c.const_id = cc.const_id 
	AND (c.HAP = 'T' OR c.CAAVOC = 'T' OR c.air_permit_restricted = 'T' OR c.CAS_code = '7664417')
WHERE	(b.company_id = @company_id)	
	AND (b.profit_ctr_id = @profit_ctr_id)
	AND (@location = 'ALL' OR b.location = @location)
	AND (@tracking_num = 'ALL' OR b.tracking_num = @tracking_num)
	AND (b.date_opened BETWEEN @date_from AND @date_to)
	AND b.status <> 'V'

-- debug
--print 'after first insert'
--select * from #tmp

SELECT DISTINCT 
	company_id
,	profit_ctr_id
,	receipt_id
,	line_id
,	container_id
,	location
,	tracking_num
,	cycle
,	start_time
,	end_time
,	treatment_time_hours
,	batch_date
INTO #tmp2
FROM #tmp

-- debug
--print 'after insert into #tmp2'
--select * from #tmp2

-- Get any containers that were consolidated into the containers that are already in the temp table:
declare c_tmp cursor forward_only read_only for
select company_id, profit_ctr_id, receipt_id, line_id, container_id, location,	tracking_num, cycle, start_time, end_time, treatment_time_hours, batch_date
from #tmp2 

open c_tmp
fetch c_tmp into @c_company_id, @c_profit_ctr_id, @c_receipt_id, @c_line_id, @c_container_id, @c_location, @c_tracking_num, @c_cycle, @c_start_time, @c_end_time, @c_treatment_time_hours, @c_batch_date

-- debug
--select @c_company_id, @c_profit_ctr_id, @c_receipt_id, @c_line_id, @c_container_id, @c_location, @c_tracking_num, @c_cycle, @c_start_time, @c_end_time, @c_treatment_time_hours, @c_batch_date

while @@FETCH_STATUS = 0
begin
	INSERT INTO #tmp (
		company_id
	,	profit_ctr_id
	,	location
	,	tracking_num
	,	cycle
	,	start_time
	,	end_time
	,	treatment_time_hours
	,	receipt_id
	,	line_id
	,	container_id
	,	container_type
	,	sequence_id
	,	approval_code
	,	hap_flag
	,	caavoc_flag
	,	chemical
	,	const_id
	,	consistency
	,	c_density
--	,	bulk_flag
--	,	pound_conv
	,	concentration
--	,	quantity
	,	ppm_concentration
--	,	pounds_received
	,	pounds_constituent
--	,	bill_unit_code
--	,	container_size
	,	unit
	,	batch_date
	,	air_permit_restricted_flag
	)
	SELECT  
		@c_company_id
	,	@c_profit_ctr_id
	,	@c_location
	,	@c_tracking_num
	,	@c_cycle
	,	@c_start_time
	,	@c_end_time
	,	@c_treatment_time_hours
	,	containers.receipt_id
	,	containers.line_id
	,	containers.container_id
	,	containers.container_type
	,	cd.sequence_id
	,	ib.approval_code
	,	isnull(c.hap, 'F') as hap_flag
	,	isnull(c.CAAVOC, 'F') as voc_flag
	,	c.const_desc as chemical
	,	c.const_id
	,	pl.consistency
	,	pl.density as c_density
--	,	ib.bulk_flag
--	,	1000000000000 AS pound_conv
	,	CASE
		WHEN rc.typical_concentration IS NOT NULL 
			THEN rc.typical_concentration  
		WHEN rc.typical_concentration IS NULL AND rc.min_concentration IS NULL AND rc.concentration IS NOT NULL 
			THEN rc.concentration
		WHEN rc.typical_concentration IS NULL AND rc.concentration IS NULL AND rc.min_concentration IS NOT NULL 
			THEN rc.min_concentration			 
		WHEN rc.typical_concentration IS NULL AND rc.min_concentration IS NOT NULL AND rc.concentration IS NOT NULL 
			THEN (rc.min_concentration + rc.concentration)/2
		END AS concentration
--	,	CASE WHEN ib.bulk_flag = 'T' THEN (ib.quantity * CONVERT(money, cd.container_percent)) / 100 
--			  ELSE (1 * CONVERT(money, cd.container_percent)) / 100 
--		END AS quantity
	,	1000000000000 AS ppm_concentration
--	,	1000000000000 AS pounds_received
	,	1000000000000 AS pounds_constituent
--	,	ib.bill_unit_code
--	,	c2.container_size AS container_size
	,	rc.unit
	,	@c_batch_date
	,	isnull(c.air_permit_restricted, 'F') 
	FROM dbo.fn_container_source_receipt(@c_company_id, @c_profit_ctr_id, @c_receipt_id, @c_line_id, @c_container_id) containers 
	JOIN ContainerDestination cd (NOLOCK)
		ON cd.company_id = containers.company_id
		AND cd.profit_ctr_id = containers.profit_ctr_id
		AND cd.receipt_id = containers.receipt_id
		AND cd.line_id = containers.line_id
		AND cd.container_id = containers.container_id
		AND cd.container_type = 'R'
	JOIN Container c2 (NOLOCK)
		ON c2.company_id = cd.company_id
		AND c2.profit_ctr_id = cd.profit_ctr_id
		AND c2.receipt_id = cd.receipt_id
		AND c2.line_id = cd.line_id
		AND c2.container_id = cd.container_id
		AND c2.container_type = cd.container_type
	JOIN Receipt ib (NOLOCK) 
		ON ib.company_id = cd.company_id
		AND ib.profit_ctr_id = cd.profit_ctr_id
		AND ib.receipt_id = cd.receipt_id
		AND ib.line_id = cd.line_id
		AND ib.trans_mode = 'I'
		AND ib.trans_type = 'D'
		AND ib.receipt_status <> 'V'
	JOIN ReceiptConstituent rc (NOLOCK) 
		ON ib.company_id = rc.company_id
		AND ib.profit_ctr_id = rc.profit_ctr_id
		AND ib.receipt_id = rc.receipt_id
		AND ib.line_id = rc.line_id
	JOIN Constituents c (NOLOCK) 
		ON c.const_id = rc.const_id 
		AND (c.HAP = 'T' OR c.CAAVOC = 'T' OR c.air_permit_restricted = 'T' OR c.CAS_code = '7664417')
	JOIN Profile p (NOLOCK)
		ON p.profile_id = ib.profile_id
		AND p.curr_status_code = 'A'
	JOIN ProfileLab pl (NOLOCK)
		ON pl.profile_id = p.profile_id
		AND pl.type = 'A'
	WHERE containers.container_type = 'R'
	AND NOT EXISTS (SELECT 1 FROM #tmp t2
						WHERE t2.company_id = containers.company_id
							AND t2.profit_ctr_id = containers.profit_ctr_id
							AND t2.receipt_id = containers.receipt_id
							AND t2.line_id = containers.line_id
							AND t2.container_id = containers.container_id
							AND t2.container_type = containers.container_type
)
	AND NOT EXISTS (SELECT 1 FROM ContainerConstituent CC (NOLOCK)
						WHERE c2.receipt_id = CC.receipt_id 
							AND c2.line_id = CC.line_id 
							AND c2.profit_ctr_id = CC.profit_ctr_id
							AND c2.company_id = CC.company_id
							AND c2.container_id = CC.container_id
							AND c2.container_type = cc.container_type) 

	fetch c_tmp into @c_company_id, @c_profit_ctr_id, @c_receipt_id, @c_line_id, @c_container_id, @c_location,	@c_tracking_num, @c_cycle, @c_start_time, @c_end_time, @c_treatment_time_hours, @c_batch_date
	
	-- debug
	--select @c_company_id, @c_profit_ctr_id, @c_receipt_id, @c_line_id, @c_container_id, @c_location,	@c_tracking_num, @c_cycle, @c_start_time, @c_end_time, @c_treatment_time_hours, @c_batch_date

end
close c_tmp
deallocate c_tmp

-- debug
--print 'after cursor loop'
--select * from #tmp

-- UPDATE Container Size
/*
UPDATE #tmp SET container_size = bill_unit_code WHERE container_size = '' 
UPDATE #tmp SET container_size = bill_unit_code WHERE bulk_flag = 'T'
UPDATE #tmp 
SET container_size = rp.bill_unit_code
FROM ReceiptPrice rp
WHERE #tmp.bulk_flag = 'F'
	AND #tmp.receipt_id = rp.receipt_id
	AND #tmp.line_id = rp.line_id
	AND #tmp.profit_ctr_id = rp.profit_ctr_id
	AND #tmp.company_id = rp.company_id
	AND #tmp.container_size IS NULL
	AND rp.price_id = (SELECT MIN(price_id) FROM ReceiptPrice rp2 
						WHERE rp2.receipt_id = rp.receipt_id 
							AND rp2.line_id = rp.line_id
							AND rp2.profit_ctr_id = rp.profit_ctr_id
							AND rp2.company_id = rp.company_id)
*/
-- UPDATE POUNDS RECEIVED
UPDATE #tmp 
SET pounds_received = dbo.fn_receipt_weight_container(#tmp.receipt_id, #tmp.line_id, #tmp.profit_ctr_id, #tmp.company_id, #tmp.container_id, #tmp.sequence_id) 
FROM #tmp

--Remove items from #tmp that have no valid pound_conv
--DELETE FROM #tmp where pound_conv = 1000000000000

CREATE INDEX trans_type ON #tmp (consistency)

-- UPDATE c_density on #tmp
UPDATE  #tmp SET c_density = 12.5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'solid%'
UPDATE  #tmp SET c_density = 10 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'sludge%'
UPDATE  #tmp SET c_density = 10 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'semi-solid%'
UPDATE  #tmp SET c_density = 8.3453 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'liquid%'
UPDATE  #tmp SET c_density = 7.5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'dust%'
UPDATE  #tmp SET c_density = 5 WHERE (c_density IS NULL OR c_density = 0) AND consistency LIKE 'debris%'

/* default catch-all */
UPDATE  #tmp SET c_density = 12.5 WHERE c_density IS NULL OR c_density = 0 

UPDATE #tmp SET pounds_constituent = Round (  (ROUND(pounds_received, 5) * ( ROUND(concentration, 5) / 1000000) ) , 5 )
WHERE unit IN ('ppm','ppmw','mg/kg') AND concentration IS NOT NULL AND pounds_received IS NOT NULL

UPDATE #tmp SET pounds_constituent = ROund (  (ROUND(pounds_received, 5) * (ROUND(concentration, 5) / 100) ) ,5 )
WHERE unit = '%' AND concentration IS NOT NULL AND pounds_received IS NOT NULL

UPDATE #tmp SET pounds_constituent = Round ( ((ROUND(pounds_received, 5) / ROUND(c_density, 5)) * (ROUND(concentration, 5) * 0.000008345)) , 5 )
WHERE unit = 'mg/L' AND concentration IS NOT NULL AND c_density IS NOT NULL AND pounds_received IS NOT NULL

--DevOps:17098 - AM - Added 'ug/kg', 'ppb' and 'ug/L' calculation

UPDATE #tmp SET pounds_constituent = Round ( (ROUND(pounds_received, 5) * ( ROUND(concentration, 5) * 0.000000001) ) , 5 )
WHERE unit IN ('ppb','ug/kg') AND concentration IS NOT NULL AND pounds_received IS NOT NULL

UPDATE #tmp SET pounds_constituent = Round ( ((ROUND(pounds_received, 5) / ROUND(c_density, 5)) * (ROUND(concentration, 5) * 8.3453 * 0.000000001)) , 5 )
WHERE unit = 'ug/L' AND concentration IS NOT NULL AND c_density IS NOT NULL AND pounds_received IS NOT NULL

UPDATE #tmp SET pounds_constituent = 0 WHERE pounds_constituent =  1000000000000

UPDATE #tmp SET ppm_concentration = ROUND(((pounds_constituent * 1000000)/pounds_received),5)
WHERE pounds_received IS NOT NULL AND pounds_received > 0 AND pounds_constituent IS NOT NULL

UPDATE #tmp SET ppm_concentration = 0 WHERE ppm_concentration =  1000000000000

UPDATE #tmp SET mg_constituent = pounds_constituent * 453592.37

-- Final select
SELECT 
	company_id
,	profit_ctr_id
,	location
,	tracking_num
,	start_time
,	end_time
,	treatment_time_hours 
,	container_id
,	approval_code
,	const_id
,	chemical
,	ppm_concentration
,	pounds_received
,	mg_constituent
,	receipt_id
,	line_id
,	sequence_id
,	batch_date
,	hap_flag
,	caavoc_flag
,	cycle
,	unit as orig_conc_unit
,	c_density
,	consistency
,	concentration as orig_conc
,	pounds_constituent
,	air_permit_restricted_flag
FROM #tmp
WHERE pounds_constituent > 0.000005
AND container_type = 'R'

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_air_emission_chemical_weight_by_batch] TO [EQAI]
    AS [dbo];

