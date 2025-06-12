CREATE PROCEDURE sp_rpt_vp_density
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
AS

/***************************************************************************************
Filename:	L:\IT Apps\SourceCode\Control\SQL\Prod\NTSQL1\PLT_AI\Procedures

PB Object(s):	d_receipt_vp_density

Initial creation - AM
05/12/2015 - AM - Modified code to get quantity from fn_receipt_weight_line.
06/22/2015 - AM - Modified vapor_pressure_psia calculation.

sp_rpt_vp_density 21, 0, '1-1-2014', '1-31-2014', 1, 999999 -- 6694
sp_rpt_vp_density 21, 0, '1-01-2014', '12-31-2014', 1, 999999
sp_rpt_vp_density 21, 0, '03-25-2015', '03-25-2015', 888880, 888880
****************************************************************************************/

CREATE TABLE #tmp_receipts (
	company_id		int
,	profit_ctr_id	int
,	receipt_id		int
,	line_id			int
,	disposal_date	datetime
,	container_count int
,	process_location varchar(15)
,	density			float
,	vapor_pressure_mmgh float
,	vapor_pressure_psia float
)

CREATE TABLE #tmp_consolidated (
	record_id		int	 identity
,	receipt_id		int
,	line_id			int
,	container_id	int
,	sequence_id		int
,	final_location	varchar(15)
,	disposal_date	datetime
,	processed_flag	tinyint
,   container_count int
,	density			float
,	vapor_pressure_mmgh float
,	vapor_pressure_psia float
)

DECLARE	
	@date_from_12			datetime,
	@date_from_total		datetime,
	@receipt_id				int,
	@line_id				int,
	@container_id			int,
	@sequence_id			int,
	@location				varchar(15),
	@disposal_date			datetime,
	@debug					int,
	@record_id				int,
	@container_count	    int
	
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET @debug = 0

-- Set date range we want to check for rolling 12 month
SET @date_from_12 = DATEADD(day, -365, @date_to)

-- Set @date_from_total to the earlier of
-- a. One year before @date_to input parameter
-- b. @date_from input paramter
SET @date_from_total = @date_from_12
IF @date_from < @date_from_12 SET @date_from_total = @date_from

IF @debug = 1
BEGIN
	PRINT 'Rolling 12 month date range:  ' + CONVERT(varchar(11), @date_from_12) + ' to ' + CONVERT(varchar(11), @date_to)
END

------------------------------------------------------------------------------------------------------------------
-- Get all receipts that directly went into process location within the date range
-- This version of the VOC report is valid only after the June 5, 1997 date hard-coded into this procedure.
------------------------------------------------------------------------------------------------------------------
INSERT #tmp_receipts
SELECT
	r.company_id
,	r.profit_ctr_id
,	r.receipt_id
,	r.line_id
,   cd.disposal_date
,	dbo.fn_container_count ( r.receipt_id, r.line_id, cd.container_type, r.profit_ctr_id, r.company_id ) as container_count
,	pl.location AS process_location
,   0  as density
,   0  as vapor_pressure_mmgh 
,   0  as vapor_pressure_psia 
FROM ContainerDestination cd
JOIN Container c on cd.container_id = c.container_id
		AND cd.company_id = c.company_id
		AND cd.profit_ctr_id = c.profit_ctr_id
		AND cd.receipt_id = c.receipt_id
		AND cd.line_id = c.line_id
JOIN ProcessLocation pl
	ON pl.company_id = cd.company_id
	AND pl.profit_ctr_id = cd.profit_ctr_id
	AND pl.location = cd.location
	AND pl.location_report_flag <> 'N'
JOIN Receipt r
	ON r.company_id = cd.company_id
	AND r.profit_ctr_id = cd.profit_ctr_id
	AND r.receipt_id = cd.receipt_id
	AND r.line_id = cd.line_id
	AND r.receipt_status = 'A' 
	AND r.submitted_flag = 'T'
	AND r.fingerpr_status not in ( 'V', 'R' )
	AND r.trans_type = 'D'
	AND r.trans_mode = 'I'
JOIN Generator g
	ON g.generator_id = r.generator_id
WHERE cd.company_id = @company_id
	AND cd.profit_ctr_id = @profit_ctr_id
	AND cd.disposal_date  > '06-05-1997'
	AND cd.disposal_date BETWEEN @date_from_total AND @date_to
	AND cd.location_type = 'P'
	AND cd.container_type = 'R'
		
IF @debug = 1
BEGIN
	PRINT 'total in #tmp_receipts' 
	Select count(1) from #tmp_receipts
	PRINT 'selecting from #tmp_receipts' 
	Select * from #tmp_receipts
END

-----------------------------------------------------------------------------------------------
-- Get all containers that have something consolidated for the given date range
-----------------------------------------------------------------------------------------------
INSERT #tmp_consolidated
SELECT
		cd.receipt_id
	,	cd.line_id
	,	cd.container_id
	,	cd.sequence_id
	,	pl.location AS final_location
	,	cd.disposal_date
	,	0 AS processed_flag
	,	dbo.fn_container_count ( cd.receipt_id, cd.line_id, cd.container_type, @profit_ctr_id, @company_id ) as container_count
	,   0  as density
	,   0  as vapor_pressure_mmgh 
	,   0  as vapor_pressure_psia 
	FROM ContainerDestination cd
	JOIN ProcessLocation pl
		ON pl.company_id = cd.company_id
		AND pl.profit_ctr_id = cd.profit_ctr_id
		AND pl.location = cd.location
		AND pl.location_report_flag <> 'N'
	WHERE cd.company_id = @company_id
		AND cd.profit_ctr_id = @profit_ctr_id
		AND cd.disposal_date  > '06-05-1997'
		AND cd.disposal_date BETWEEN @date_from_total AND @date_to
		AND cd.location_type = 'P'
		AND cd.container_type = 'S'
		AND EXISTS (SELECT 1 FROM ContainerDestination
						WHERE ContainerDestination.base_tracking_num = 'DL-' +
							RIGHT('00' + CONVERT(varchar(2), @company_id), 2) +
							RIGHT('00' + CONVERT(varchar(2), @profit_ctr_id), 2) +
							'-'+ RIGHT('000000' + CONVERT(varchar(6), cd.container_id), 6)
						AND ContainerDestination.base_container_id = cd.container_id
						AND ContainerDestination.base_sequence_id = cd.sequence_id
					)
	UNION
	SELECT
		cd.receipt_id
	,	cd.line_id
	,	cd.container_id
	,	cd.sequence_id
	,	pl.location AS final_location
	,	cd.disposal_date
	,	0 AS processed_flag
	,	dbo.fn_container_count ( cd.receipt_id, cd.line_id, cd.container_type, @profit_ctr_id, @company_id ) as container_count
	,   0  as density
	,   0  as vapor_pressure_mmgh 
	,   0  as vapor_pressure_psia 
	FROM ContainerDestination cd
	JOIN ProcessLocation pl
		ON pl.company_id = cd.company_id
		AND pl.profit_ctr_id = cd.profit_ctr_id
		AND pl.location = cd.location
		AND pl.location_report_flag <> 'N'
	WHERE cd.company_id = @company_id
		AND cd.profit_ctr_id = @profit_ctr_id
		AND cd.disposal_date  > '06-05-1997'
		AND cd.disposal_date BETWEEN @date_from_total AND @date_to
		AND cd.location_type = 'P'
		AND cd.container_type = 'R'
		AND EXISTS (SELECT 1 FROM ContainerDestination
						WHERE ContainerDestination.base_tracking_num = CONVERT(Varchar(10), cd.receipt_id) +
							'-' + CONVERT(Varchar(10), cd.line_id) 
						AND ContainerDestination.base_container_id = cd.container_id
						AND ContainerDestination.base_sequence_id = cd.sequence_id
					)
IF @debug = 1
BEGIN
	PRINT 'total in #tmp_consolidated' 
	Select count(1) from #tmp_consolidated
	select * from #tmp_consolidated
END

SELECT @record_id = Isnull(MIN(record_id), 0) FROM #tmp_consolidated WHERE processed_flag = 0
WHILE @record_id > 0
BEGIN
	SELECT
		@receipt_id = receipt_id
	,	@line_id = line_id
	,	@container_id = container_id
	,	@sequence_id = sequence_id
	,	@location = final_location
	,	@disposal_date = disposal_date
	,   @container_count = container_count
	FROM #tmp_consolidated
	WHERE record_id = @record_id
	
	IF @debug = 1 PRINT 'Container: ' + CONVERT(VARCHAR,@receipt_id) + '-' + CONVERT(VARCHAR,@line_id) 
									  + '-' + CONVERT(VARCHAR,@container_id) + '-' + CONVERT(VARCHAR,@sequence_id) 
	
	------------------------------------------------------------
	-- Get source containers or receipts for this row
	------------------------------------------------------------				  
	INSERT #tmp_receipts
	SELECT
		source_containers.company_id
	,	source_containers.profit_ctr_id
	,	source_containers.receipt_id
	,	source_containers.line_id
	,	@disposal_date AS disposal_date
	,	@container_count AS container_count 
	,	@location 
	,   0  as density
	,   0  as vapor_pressure_mmgh 
	,   0  as vapor_pressure_psia  
	FROM dbo.fn_container_source(@company_id, @profit_ctr_id, @receipt_id, @line_id, @container_id, @sequence_id, 1) source_containers 
	JOIN Container c ON source_containers.container_id = c.container_id
		AND source_containers.company_id = c.company_id
		AND source_containers.profit_ctr_id = c.profit_ctr_id
		AND source_containers.receipt_id = c.receipt_id
		AND source_containers.line_id = c.line_id
	JOIN ContainerDestination cd ON source_containers.container_id = cd.container_id
		AND source_containers.company_id = cd.company_id
		AND source_containers.profit_ctr_id = cd.profit_ctr_id
		AND source_containers.receipt_id = cd.receipt_id
		AND source_containers.line_id = cd.line_id
		AND source_containers.sequence_id = cd.sequence_id
		AND source_containers.container_type = cd.container_type

	-- Update this row as processed
	Update #tmp_consolidated SET processed_flag = 1 WHERE record_id = @record_id
	-- Move to the next row
	SELECT @record_id = Isnull(MIN(record_id), 0) FROM #tmp_consolidated WHERE processed_flag = 0
END

IF @debug = 1
BEGIN
	PRINT 'total in #tmp_receipts' 
	Select count(1) from #tmp_receipts
	select * from #tmp_receipts
END

-------------------------------------------------------------------------------------
-- build #tmp
-------------------------------------------------------------------------------------
SELECT	
	r.company_id
,	r.profit_ctr_id
,	r.receipt_id
,	r.line_id
,	r.manifest
,	r.bulk_flag
,	r.receipt_date
,   tr.disposal_date
,	r.profile_id
,	r.approval_code
,	p.approval_desc
,	g.generator_name
,   dbo.fn_receipt_weight_line (r.receipt_id, r.line_id,@profit_ctr_id,@company_id)as quantity
--,   r.quantity
,	tr.container_count
,	tr.process_location
,	dbo.fn_get_receipt_density (@company_id, @profit_ctr_id, r.receipt_id, r.line_id) as density
,	dbo.fn_get_receipt_vapor_pressure  (@company_id,@profit_ctr_id,r.receipt_id, r.line_id) as vapor_pressure_mmgh
--,   dbo.fn_get_receipt_vapor_pressure_psia (@company_id, @profit_ctr_id, r.receipt_id, r.line_id ) as vapor_pressure_psia
,  ((dbo.fn_get_receipt_vapor_pressure  ( @company_id,@profit_ctr_id,r.receipt_id, r.line_id) / 760 )* 14.7 ) as vapor_pressure_psia
INTO #tmp
FROM Receipt r
JOIN Generator g
	ON g.generator_id = r.generator_id
JOIN profile p 
	ON r.profile_id = p.profile_id
JOIN #tmp_receipts tr
	ON tr.company_id = r.company_id
	AND tr.profit_ctr_id = r.profit_ctr_id
	AND tr.receipt_id = r.receipt_id
	AND tr.line_id = r.line_id
WHERE r.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND r.company_id = @company_id
	AND r.profit_ctr_id = @profit_ctr_id
	AND r.receipt_status = 'A' 
	AND r.submitted_flag = 'T'
	AND r.fingerpr_status not in ( 'V', 'R' )
	AND r.trans_type = 'D'
	AND r.trans_mode = 'I'
		
IF @debug = 1 PRINT 'Selecting from #tmp'
IF @debug = 1 Select * from #tmp

SELECT #tmp.company_id,
	#tmp.profit_ctr_id,
	receipt_id as receipt_id, 
	line_id as line_id, 
	manifest, 
	bulk_flag as bulk_flag, 
	receipt_date, 
	disposal_date,
	profile_id,
	approval_code,
    approval_desc,
	generator_name, 
	quantity,
	container_count,
	process_location,
	density,
	vapor_pressure_mmgh,
	vapor_pressure_psia,
	Company.company_name,
	ProfitCenter.profit_ctr_name
FROM #tmp
JOIN Company
	ON Company.company_id = #tmp.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_ID = #tmp.company_id
	AND ProfitCenter.profit_ctr_ID = #tmp.profit_ctr_id
WHERE disposal_date BETWEEN @date_from AND @date_to
GROUP BY #tmp.company_id,
	#tmp.profit_ctr_id,
	receipt_id,
	line_id,
	manifest,
	bulk_flag,
	receipt_date,
	disposal_date,
	profile_id,
	approval_code,
	approval_desc, 
	generator_name, 
	quantity,
	container_count,
	process_location, 
	density,
	vapor_pressure_mmgh,
	vapor_pressure_psia,
	Company.company_name,
	ProfitCenter.profit_ctr_name
ORDER BY disposal_date, approval_code

DROP TABLE #tmp
DROP TABLE #tmp_consolidated
DROP TABLE #tmp_receipts


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_vp_density] TO [EQAI]
    AS [dbo];

