CREATE PROCEDURE sp_rpt_receipt_log_rolling_12_month
	@company_id			int
,	@profit_ctr_id		int
,	@receipt_date_from	datetime
,	@receipt_date_to	datetime
,	@cust_id_from		int
,	@cust_id_to		int
AS

/***************************************************************************************
PB Object(s):	r_receipt_log_rolling_12_month

10/07/2003 JDB	Created
11/11/2004 MK	Changed generator_code to generator_id
11/29/2004 JDB	Changed ticket_id to line_id, DrumDetail to Container
01/06/2005 SCC	Modified for Container Tracking
12/03/2007 LJT  Removed receipt quantity since the quantity should always be 1. 
                Added the grouping per receipt line 
                Removed the limitation of selecting only non-bulk
11/05/2010 SK	Added Company_id and profit_ctr_id as input args
				moved to Plt_AI, report runs for a specific company, profit center
01/10/2011 JDB	Added ISNULL statements around the rolling 12-month sums.
01/11/2011 SK	Added rolling 12-month sum for location report flag = R
01/11/2011 SK	Added logic to include source containers for consolidated ones
				Corrected the logic for calculating date_from when users date range is > 1 year
				Corrected the quantity calc in final result set to account for container percent when a
				container is split into different stock containers.
08/21/2013 SM	Added wastecode table and displaying Display name
09/10/2019 JCB  inc 14732: Changed 2 pulls from r.receipt_status = 'A'  
                to fingerpr_status=A and receipt_status not in ('R','V')

sp_rpt_receipt_log_rolling_12_month 21, 0, '10-01-2006', '11-01-2007', 1, 999999
sp_rpt_receipt_log_rolling_12_month 21, 0, '06-01-2006', '10-01-2006', 1, 999999
sp_rpt_receipt_log_rolling_12_month 2, 21, '11-01-2007', '11-01-2007', 0, 999999
sp_rpt_receipt_log_rolling_12_month 29, 0, '01-01-2010', '12-24-2010', 0, 999999

****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

CREATE TABLE #tmp_containers (
	company_id		int
,	profit_ctr_id	int
,	receipt_id		int
,	line_id			int
,	container_id	int
,	sequence_id		int
,	container_type	char(1)
,	location		varchar(15)
,	location_report_flag	char(1)
,	disposal_date	datetime
)

DECLARE	
	@container_id	int,
	@container_type	char(1),
	@date_from 		datetime,
	@date_from_12	datetime,
	@date_to 		datetime,
	@disposal_date	datetime,
	@debug			tinyint,
	@line_id		int,
	@location		varchar(15),
	@location_rpt_flag	char(1),
	@record_id		int,
	@receipt_id		int,
	@rolling_12_month_gallons_east	float,
	@rolling_12_month_gallons_west	float,
	@rolling_12_month_gallons_reportable float,
	@sequence_id	int
	
DECLARE @tmp_consolidated TABLE(
	record_id		int	 identity
,	receipt_id		int
,	line_id			int
,	container_id	int
,	sequence_id		int
,	container_type	char(1)
,	location		varchar(15)
,	location_report_flag	char(1)
,	disposal_date	datetime
,	processed_flag	tinyint
)	

-- Set debug mode
SET @debug = 0

-- Set date range we want to check for rolling 12 month
--SET @date_from = DATEADD(day, -365, @receipt_date_to)
SET @date_from_12 = DATEADD(day, -365, @receipt_date_to)
IF @date_from_12 <= @receipt_date_from SET @date_from = @date_from_12 ELSE SET @date_from = @receipt_date_from
SET @date_to = @receipt_date_to

IF @debug = 1
BEGIN
	PRINT '@date_from_12 = ' + CONVERT(varchar(20), @date_from_12)
	PRINT '@date_from = ' + CONVERT(varchar(20), @date_from)
	PRINT '@date_to = ' + CONVERT(varchar(20), @date_to)
END

-- Get all receipt/stock containers that directly went into process location within the date range
INSERT #tmp_containers
SELECT 
	cd.company_id
,	cd.profit_ctr_id
,	cd.receipt_id
,	cd.line_id
,	cd.container_id
,	cd.sequence_id
,	cd.container_type
,	pl.location AS location
,	pl.location_report_flag AS location_report_flag
,	cd.disposal_date AS disposal_date
FROM ContainerDestination cd
JOIN ProcessLocation pl
	ON pl.company_id = cd.company_id
	AND pl.profit_ctr_id = cd.profit_ctr_id
	AND pl.location = cd.location
	AND pl.location_report_flag <> 'N'
WHERE cd.company_id = @company_id
	AND cd.profit_ctr_id = @profit_ctr_id
	AND cd.disposal_date BETWEEN @date_from AND @date_to
	AND cd.location_type = 'P'
		
IF @debug = 1
BEGIN
	PRINT 'total in #tmp_containers' 
	Select count(1) from #tmp_containers
	--Select * from #tmp_containers
END

-----------------------------------------------------------------------------------------------
-- Get from #tmp_containers only those that have something consolidated in them
-----------------------------------------------------------------------------------------------
INSERT @tmp_consolidated
SELECT
	#tmp_containers.receipt_id
,	#tmp_containers.line_id
,	#tmp_containers.container_id
,	#tmp_containers.sequence_id
,	#tmp_containers.container_type
,	#tmp_containers.location
,	#tmp_containers.location_report_flag
,	#tmp_containers.disposal_date
,	0 AS processed_flag
FROM #tmp_containers
WHERE container_type = 'S'
	AND EXISTS (SELECT 1 FROM ContainerDestination
						WHERE ContainerDestination.base_tracking_num = 'DL-' +
							RIGHT('00' + CONVERT(varchar(2), @company_id), 2) +
							RIGHT('00' + CONVERT(varchar(2), @profit_ctr_id), 2) +
							'-'+ RIGHT('000000' + CONVERT(varchar(6), #tmp_containers.container_id), 6)
						AND ContainerDestination.base_container_id = #tmp_containers.container_id
						AND ContainerDestination.base_sequence_id = #tmp_containers.sequence_id
					)
UNION
SELECT
	#tmp_containers.receipt_id
,	#tmp_containers.line_id
,	#tmp_containers.container_id
,	#tmp_containers.sequence_id
,	#tmp_containers.container_type
,	#tmp_containers.location
,	#tmp_containers.location_report_flag
,	#tmp_containers.disposal_date
,	0 AS processed_flag
FROM #tmp_containers
WHERE container_type = 'R'
AND EXISTS (SELECT 1 FROM ContainerDestination
				WHERE ContainerDestination.base_tracking_num = CONVERT(Varchar(10), #tmp_containers.receipt_id) +
					'-' + CONVERT(Varchar(10), #tmp_containers.line_id) 
				AND ContainerDestination.base_container_id = #tmp_containers.container_id
				AND ContainerDestination.base_sequence_id = #tmp_containers.sequence_id
			)

IF @debug = 1
BEGIN
	PRINT 'total in @tmp_consolidated' 
	Select count(1) from @tmp_consolidated
END

-----------------------------------------------------------------------------------------------
-- For above consolidated find the source receipt containers
-----------------------------------------------------------------------------------------------
SELECT @record_id = Isnull(MIN(record_id), 0) FROM @tmp_consolidated WHERE processed_flag = 0
WHILE @record_id > 0
BEGIN
	SELECT
		@receipt_id = receipt_id
	,	@line_id = line_id
	,	@container_id = container_id
	,	@sequence_id = sequence_id
	,	@container_type = container_type
	,	@location = location
	,	@location_rpt_flag = location_report_flag
	,	@disposal_date = disposal_date
	FROM @tmp_consolidated
	WHERE record_id = @record_id
	
	IF @debug = 1 PRINT 'Container: ' + CONVERT(VARCHAR,@receipt_id) + '-' + CONVERT(VARCHAR,@line_id) 
									  + '-' + CONVERT(VARCHAR,@container_id) + '-' + CONVERT(VARCHAR,@sequence_id) 
	
	--IF @debug = 1
	--BEGIN
	--	SELECT 
	--		source_containers.company_id
	--	,	source_containers.profit_ctr_id
	--	,	source_containers.receipt_id
	--	,	source_containers.line_id
	--	,	source_containers.container_id
	--	,	source_containers.sequence_id
	--	,	@container_type AS container_type
	--	,	@location AS location
	--	,	@location_rpt_flag AS location_report_flag
	--	,	@disposal_date AS disposal_date
	--	FROM dbo.fn_container_source(@company_id, @profit_ctr_id, @receipt_id, @line_id, @container_id, @sequence_id, 0) source_containers 
	--	WHERE source_containers.destination_profit_ctr_id = @profit_ctr_id
	--		AND source_containers.destination_company_id = @company_id
	--		AND source_containers.destination_receipt_id = @receipt_id
	--		AND source_containers.destination_line_id = @line_id
	--		AND source_containers.destination_container_id = @container_id
	--		AND source_containers.destination_sequence_id = @sequence_id
	--END
	
	----------------------------------------------------------
	 --Get source containers or receipts for this row
	----------------------------------------------------------				  
	
	INSERT #tmp_containers
	SELECT 
		source_containers.company_id
	,	source_containers.profit_ctr_id
	,	source_containers.receipt_id
	,	source_containers.line_id
	,	source_containers.container_id
	,	source_containers.sequence_id
	,	@container_type AS container_type
	,	@location AS location
	,	@location_rpt_flag AS location_report_flag
	,	@disposal_date AS disposal_date
	FROM dbo.fn_container_source(@company_id, @profit_ctr_id, @receipt_id, @line_id, @container_id, @sequence_id, 0) source_containers 
	WHERE source_containers.destination_profit_ctr_id = @profit_ctr_id
		AND source_containers.destination_company_id = @company_id
		AND source_containers.destination_receipt_id = @receipt_id
		AND source_containers.destination_line_id = @line_id
		AND source_containers.destination_container_id = @container_id
		AND source_containers.destination_sequence_id = @sequence_id
	
	-- Update this row as processed
	Update @tmp_consolidated SET processed_flag = 1 WHERE record_id = @record_id
	-- Move to the next row
	SELECT @record_id = Isnull(MIN(record_id), 0) FROM @tmp_consolidated WHERE processed_flag = 0
END

IF @debug = 1
BEGIN
	PRINT 'total in #tmp_containers after including consolidated sources' 
	Select count(1) from #tmp_containers
	--select * from #tmp_containers
END

------------------------------------------------------------
-- get the rolling 12 month total from above
------------------------------------------------------------
SELECT 
	tc.location_report_flag,
	ISNULL((CASE WHEN r.Bulk_flag = 'F' THEN 1 ELSE r.quantity END ), 0) * ISNULL(b.gal_conv, 0) AS cf_gallons
INTO #Rolling_12_month
FROM Receipt r
JOIN #tmp_containers tc
	ON tc.company_id = r.company_id
	AND tc.profit_ctr_id = r.profit_ctr_id
	AND tc.receipt_id = r.receipt_id
	AND tc.line_id = r.line_id
	AND tc.disposal_date BETWEEN @date_from_12 AND @date_to
JOIN BillUnit b
	ON b.bill_unit_code = r.bill_unit_code
WHERE r.company_id = @company_id
	AND r.profit_ctr_id = @profit_ctr_id
	AND r.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND r.receipt_status = 'A'
	AND r.trans_type = 'D'
	AND r.trans_mode = 'I'

SELECT @rolling_12_month_gallons_east = ISNULL(ROUND(SUM(cf_gallons), 0), 0) FROM #Rolling_12_month WHERE location_report_flag = 'E'
SELECT @rolling_12_month_gallons_west = ISNULL(ROUND(SUM(cf_gallons), 0), 0) FROM #Rolling_12_month WHERE location_report_flag = 'W'
SELECT @rolling_12_month_gallons_reportable = ISNULL(ROUND(SUM(cf_gallons), 0), 0) FROM #Rolling_12_month WHERE location_report_flag = 'R'

IF @debug = 1
BEGIN
	PRINT '@rolling_12_month_gallons_east = ' + CONVERT(varchar(20), @rolling_12_month_gallons_east)
	PRINT '@rolling_12_month_gallons_west = ' + CONVERT(varchar(20), @rolling_12_month_gallons_west)
	PRINT '@rolling_12_month_gallons_reportable = ' + CONVERT(varchar(20), @rolling_12_month_gallons_reportable)
END

------------------------------------------------------------
-- build the final result set
------------------------------------------------------------
SELECT	
	r.receipt_id, 
	r.line_id,
	r.approval_code, 
	w.display_name as waste_code, 
	g.generator_name, 
	Sum(CASE WHEN r.Bulk_flag = 'F' THEN 1 ELSE (r.quantity * cd.container_percent/100) END) AS quantity,
	r.receipt_date,
	b.gal_conv, 
	r.bill_unit_code, 
	r.location, 
	tc.location, 
	sum(1) as container_count, 
	r.manifest, 
	r.bulk_flag, 
	tc.location_report_flag, 
	tc.disposal_date,
	@rolling_12_month_gallons_east AS rolling_12_month_gallons_east,
	@rolling_12_month_gallons_west AS rolling_12_month_gallons_west,
	@rolling_12_month_gallons_reportable AS rolling_12_month_gallons_reportable,
	r.company_id,
	r.profit_ctr_id,
	Company.company_name,
	ProfitCenter.profit_ctr_name
FROM Receipt r
LEFT OUTER JOIN wastecode w
	ON w.waste_code_uid = r.waste_code_uid
JOIN Company
	ON Company.company_id = r.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = r.company_id
	AND ProfitCenter.profit_ctr_id = r.profit_ctr_id
JOIN BillUnit b
	ON b.bill_unit_code = r.bill_unit_code
JOIN Generator g	
	ON g.generator_id = r.generator_id
JOIN #tmp_containers tc
	ON tc.company_id = r.company_id
	AND tc.profit_ctr_id = r.profit_ctr_id
	AND tc.receipt_id = r.receipt_id
	AND tc.line_id = r.line_id
	AND tc.disposal_date BETWEEN @receipt_date_from AND @receipt_date_to
JOIN ContainerDestination cd
	ON cd.company_id = tc.company_id
	AND cd.profit_ctr_id = tc.profit_ctr_id
	AND cd.receipt_id = tc.receipt_id
	AND cd.line_id = tc.line_id
	AND cd.container_id = tc.container_id
	AND cd.sequence_id = tc.sequence_id
WHERE r.company_id = @company_id
	AND r.profit_ctr_id = @profit_ctr_id
	AND r.customer_id BETWEEN @cust_id_from AND @cust_id_to
	-- jcb 20190910 inc14732 REPL 	AND r.receipt_status = 'A'   
	AND r.fingerpr_status = 'A'	and receipt_status not in ('R','V') -- jcb 20190910 
	AND r.trans_type = 'D'
	AND r.trans_mode = 'I'
GROUP BY r.receipt_id, 	r.line_id, r.approval_code, w.display_name, g.generator_name, 
	r.receipt_date,	b.gal_conv,r.bill_unit_code, r.location, tc.location, r.manifest, r.bulk_flag, tc.location_report_flag, 
	tc.disposal_date, r.company_id, r.profit_ctr_id, Company.company_name, ProfitCenter.profit_ctr_name

DROP TABLE #Rolling_12_month
DROP TABLE #tmp_containers


GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_receipt_log_rolling_12_month] TO [EQAI]
    AS [dbo];

