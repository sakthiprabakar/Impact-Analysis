CREATE PROCEDURE sp_rpt_margin_nonbulk
	@company_id		int
,	@profit_ctr_id 	int
,	@date_from 		datetime
,	@date_to 		datetime
AS
/***************************************************************************************
Filename:	L:\Apps\SQL\EQAI\sp_rpt_margin_nonbulk.sql
PB Object(s):	d_rpt_margin_nonbulk

01/15/2003 JDB	Created
06/20/2003 LJT	Modified
07/08/2003 JDB	Finished creating stored procedure.
08/07/2003 JDB	Modified to only write the invoice amount and total cost to one record
		per ticket so that the sum on the report works correctly.
04/06/2004 JDB	Modified to match receipt table addition of TSDF_code field.
12/09/2004 MK	Modified ticket_id, drum references, DrumHeader, and DrumDetail
05/05/2005 MK	Added epa_id and generator_name to final select
11/23/2010 SK	Added company_id as input arg(always pass non-zero), modified to run on Plt_AI, replaced TSDFApproval.TSDF_price
				with TSDFApprovalPrice.price. Report only runs for a valid facility(eg: 21-0)
				Will not run for all companies or all profitcenters.
				moved to Plt_AI
01/18/2011 SK	Data Conversion - Fetched total invoice_amt from BillingDetail in query 1
01/19/2011 SK	Changed to include Insurance & Energy amts in total invoice_amt from BillingDetail

sp_rpt_margin_nonbulk 14, 04, '11/10/2008', '11/15/2008'

sp_helptext sp_rpt_margin_nonbulk
****************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@debug					int =0,
	@line_id				int,
	@container_id			int,
	@receipt_id				int,
	@max_receipt_id			int,
	@max_line_id			int,
	@max_container_id		int,
	@min_line_id			int,
	@min_container_id		int,
	@invoice_amt			money,
	@treatment				int,
	@cost_lab_per			money,
	@cost_process_per		money,
	@cost_disposal_processed_per_lean	money,
	@cost_disposal_processed_per_rich	money,
	@cost_disposal_processed_per_DES	money,
	@cost_disposal_outbound_per			money,
	@TSDF_price							money,
	@cost_disposal_outbound				money,
	@cost_processed			money,
	@cost_outbound			money,
	@total_samples			int,
	@approval_code			varchar(15),
	@tsdf_approval_code		varchar(40),
	@waste_stream			varchar(10),
	@TSDF_code				varchar(15),
	@cost_total_processed	money,
	@cost_total_outbound	money,
	@location				varchar(15),
	@location_type			char(1),
	@tracking_num			varchar(15),
	@total_extended_amount	money,
	@container_count_outbound	int,
	@quantity_outbound		float,
	@seq					int,
	@lineseq				int


CREATE TABLE #tmp (
	receipt_date				datetime	NULL,
	generator_id				int			NULL,
	manifest					varchar(15)	NULL,
	total_containers_received	int 		NULL, 
	fuel						varchar(10) NULL, 
	total_containers_processed	int 		NULL, 
	cost_disposal_processed		money 		NULL, 
	cost_total_processed		money 		NULL, 
	location					varchar(15) NULL,
	total_containers_outbound	int 		NULL,
	cost_disposal_outbound		money 		NULL, 
	cost_total_outbound			money 		NULL, 
	total_samples				int 		NULL,
	cost_lab					money 		NULL,
	process_time				float 		NULL,
	cost_process 				money 		NULL,
	cost_total 					money 		NULL,
	invoice_amount 				money 		NULL,
	total_margin 				money 		NULL,
	percent_margin 				float 		NULL,
	comments 					varchar(255) NULL,
	receipt_id 					int 		NULL,
	line_id 					int 		NULL,
	company_id					int			NULL,
	profit_ctr_id				int			NULL,
	container_id 				int 		NULL,
	approval_code 				varchar(15) NULL,
	bill_unit_code 				varchar(4) 	NULL,
	bulk_flag 					char(1) 	NULL,
	treatment_id 				int 		NULL,
	receipt_status				char(1)		NULL,
	location_type				char(1)		NULL,
	tracking_num				varchar(15)	NULL,
	min_line_id					int			NULL,
	min_container_id			int			NULL
)

SET @cost_lab_per = 17.00
SET @cost_process_per = 78.00
SET @cost_disposal_processed_per_lean = 31.00
SET @cost_disposal_processed_per_rich = 26.00
SET @cost_disposal_processed_per_DES = 75.00
SET @cost_disposal_outbound_per = 0.00
SET @cost_disposal_outbound = 0.00

/* Insert records */
INSERT #tmp
SELECT DISTINCT 
	r.receipt_date,
	ISNULL(r.generator_id, 0) AS generator_id,
	r.manifest,
	total_containers_received = ISNULL((SELECT COUNT(C2.container_ID) FROM Container C2
										WHERE c.receipt_id = C2.receipt_id
										AND c.line_id = C2.line_id
										AND c.profit_ctr_id = C2.profit_ctr_id
										AND c.company_id = C2.company_id
										AND c.container_type = C2.container_type), 0),
	fuel = (CASE WHEN r.treatment_id IN (2,30,44,48,53)	THEN 'Rich'
				 WHEN r.treatment_id IN (6,10,24,38,40,46,50)THEN 'Lean'
				 ELSE ' ' END),
	total_containers_processed = (CASE WHEN cd.location_type = 'P' THEN 
												ISNULL((SELECT COUNT(C2.container_ID) FROM Container C2
														WHERE c.receipt_id = C2.receipt_id
														AND c.line_id = C2.line_id
														AND c.profit_ctr_id = C2.profit_ctr_id
														AND c.company_id = C2.company_id
														AND c.container_type = C2.container_type), 0)
									   ELSE 0 END),
	cost_disposal_processed = (CASE WHEN r.treatment_id IN (2,30,44,48,53) THEN @cost_disposal_processed_per_rich
									WHEN r.treatment_id IN (6,10,24,38,40,46,50) THEN @cost_disposal_processed_per_lean
									WHEN r.treatment_id IN (8) THEN @cost_disposal_processed_per_DES
									ELSE @cost_disposal_processed_per_rich END),
	0.00 AS cost_total_processed,
	cd.location AS location,
	total_containers_outbound = (CASE WHEN cd.location_type = 'O' THEN 
												ISNULL((SELECT COUNT(C2.container_ID) FROM Container C2
														WHERE c.receipt_id = C2.receipt_id
														AND c.line_id = C2.line_id
														AND c.profit_ctr_id = C2.profit_ctr_id
														AND c.company_id = C2.company_id
														AND c.container_id = C2.container_id
														AND c.container_type = C2.container_type), 0)
									  ELSE 0 END),
	0.00 AS cost_disposal_outbound, 
	0.00 AS cost_total_outbound,
	1.00 AS total_samples,
	0.00 AS cost_lab,
	process_time = (ISNULL((SELECT COUNT(C2.container_ID) FROM Container C2
							WHERE c.receipt_id = C2.receipt_id
							AND c.line_id = C2.line_id
							AND c.profit_ctr_id = C2.profit_ctr_id
							AND c.company_id = C2.company_id
							AND c.container_type = C2.container_type), 0.0000) * 4.0000) / 60.0000,
	0.00 AS cost_process,
	0.00 AS cost_total,
	--ISNULL(t.total_extended_amt, 0.00) AS invoice_amount,
	invoice_amount = ISNULL((SELECT SUM(ISNULL(bd.extended_amt, 0)) FROM BillingDetail bd
						WHERE bd.company_id = t.company_id 
							AND bd.profit_ctr_id = t.profit_ctr_id
							AND bd.receipt_id = t.receipt_id
							AND bd.line_id = t.line_id
							AND bd.price_id = t.price_id
							AND bd.trans_type = t.trans_type
							AND bd.trans_source = t.trans_source), 0.000),
							--AND bd.billing_type NOT IN ('Insurance', 'Energy')),
	0.00 AS total_margin,
	0.00 AS percent_margin,
	r.manifest_comment AS comments,
	r.receipt_id, 
	r.line_id, 
	r.company_id,
	r.profit_ctr_id,
	cd.container_id,
	r.approval_code,
	r.bill_unit_code,
	r.bulk_flag,
	r.treatment_id,
	r.receipt_status,
	cd.location_type,
	cd.tracking_num,
	0 AS min_line_id,
	0 AS min_container_id
FROM receipt r 
LEFT OUTER JOIN billing t 
	ON r.receipt_id = t.receipt_id 
	AND r.line_id = t.line_id 
	AND r.profit_ctr_id = t.profit_ctr_id
	AND r.company_id = t.company_id
INNER JOIN Container c 
	ON r.receipt_id = c.receipt_id 
	AND r.line_id = c.line_id 
	AND r.profit_ctr_id = c.profit_ctr_id
	AND r.company_id = c.company_id
INNER JOIN ContainerDestination cd 
	ON c.receipt_id = cd.receipt_id 
	AND c.line_id = cd.line_id 
	AND c.container_id = cd.container_id 
	AND c.profit_ctr_id = cd.profit_ctr_id
	AND c.company_id = cd.company_id
WHERE	(@company_id = 0 OR r.company_id = @company_id)	
	AND (@company_id = 0 OR @profit_ctr_id = -1 OR r.profit_ctr_id = @profit_ctr_id)
	AND r.trans_mode = 'I'
	AND r.trans_type = 'D'
	AND r.bulk_flag = 'F'
	AND r.receipt_date BETWEEN @date_from AND @date_to
ORDER BY receipt_date

IF @debug = 2 Select * from #tmp

SET NOCOUNT ON
SELECT @max_receipt_id = MAX(receipt_id) FROM #tmp
SET @receipt_id = 0
/************************************************************************************************************/
Receipt:
SELECT @receipt_id = MIN(receipt_id) FROM #tmp WHERE receipt_id > @receipt_id

If @debug = 1 Print 'Processing Receipt ' + str(@receipt_id)

SET @line_id = 0
SET @lineseq = 0
SET @min_line_id = 0
SELECT @max_line_id = MAX(line_id) FROM #tmp WHERE receipt_id = @max_receipt_id
/************************************************************************************************************/
Line:
SELECT @line_id = MIN(line_id) FROM #tmp WHERE receipt_id = @receipt_id and line_id > @line_id

SELECT @lineseq = @lineseq + 1
IF @lineseq = 1 
BEGIN
	SET @min_line_id = @line_id
	UPDATE #tmp SET min_line_id = 1 WHERE receipt_id = @receipt_id AND line_id = @line_id
END

SELECT	@treatment = treatment_id,
	@approval_code = approval_code
FROM #tmp WHERE receipt_id = @receipt_id and line_id = @line_id

SET @container_id = 0
SET @seq = 0
SET @min_container_id = 0
SELECT @max_container_id = MAX(container_id) FROM #tmp WHERE receipt_id = @receipt_id AND line_id = @line_id
/*****************************************************************************************************************************************/
Container:
SELECT @container_id = MIN(container_id) FROM #tmp WHERE receipt_id = @receipt_id AND line_id = @line_id AND container_id > @container_id

SELECT @seq = @seq + 1
IF @seq = 1 
BEGIN
	SET @min_container_id = @container_id
	UPDATE #tmp SET min_container_id = 1 WHERE receipt_id = @receipt_id AND line_id = @line_id AND container_id = @container_id
END


SELECT	@location = location,
	@location_type = location_type,
	@tracking_num = tracking_num
FROM #tmp WHERE receipt_id = @receipt_id AND line_id = @line_id AND container_id = @container_id

-- Get Process Cost
IF @location = 'DES'
BEGIN
	UPDATE #tmp SET cost_disposal_processed = @cost_disposal_processed_per_DES WHERE receipt_id = @receipt_id AND line_id = @line_id AND container_id = @container_id
END

-- Get Outbound Cost
IF @location_type = 'O'
BEGIN
	-- Get TSDF Price if tracking number is an outbound ticket ID
	IF EXISTS(SELECT * FROM receipt WHERE CONVERT(varchar(15),receipt_id) + '-' + CONVERT(varchar(5),line_id) = @tracking_num
				AND profit_ctr_id = @profit_ctr_id AND company_id = @company_id AND trans_mode = 'O')
	BEGIN

		SELECT	
			@tsdf_approval_code = TSDF_approval_code,
			@TSDF_code = TSDF_code,
			@quantity_outbound = ISNULL(quantity, 0),
			@container_count_outbound = ISNULL(container_count, 0)
		FROM receipt
		WHERE CONVERT(varchar(15),receipt_id) + '-' + CONVERT(varchar(5),line_id) = @tracking_num
		AND profit_ctr_id = @profit_ctr_id
		AND company_id = @company_id
		AND trans_mode = 'O'

		SELECT @TSDF_price = ISNULL(Price, 0.00)
		FROM TSDFapproval
		JOIN TSDFApprovalPrice
			ON TSDFApprovalPrice.company_id = TSDFApproval.company_id
			AND TSDFApprovalPrice.profit_ctr_id = TSDFApproval.profit_ctr_id
			AND TSDFApprovalPrice.TSDF_approval_id = TSDFApproval.TSDF_approval_id
		WHERE TSDF_approval_code = @tsdf_approval_code
			AND TSDF_code = @TSDF_code
			AND TSDFapproval.profit_ctr_id = @profit_ctr_id
			AND TSDFapproval.company_id = @company_id

		SET @cost_disposal_outbound_per = (@TSDF_price * @quantity_outbound) / @container_count_outbound

		UPDATE #tmp SET cost_disposal_outbound = @cost_disposal_outbound_per WHERE receipt_id = @receipt_id AND line_id = @line_id AND container_id = @container_id
	END
END

SELECT @cost_total_processed	= SUM(total_containers_processed * cost_disposal_processed) FROM #tmp WHERE receipt_id = @receipt_id AND line_id = @line_id AND container_id = @container_id
SELECT @cost_total_outbound		= SUM(total_containers_outbound * cost_disposal_outbound)	FROM #tmp WHERE receipt_id = @receipt_id AND line_id = @line_id AND container_id = @container_id
UPDATE #tmp SET cost_total_processed	= @cost_total_processed WHERE receipt_id = @receipt_id AND line_id = @line_id AND container_id = @container_id
UPDATE #tmp SET cost_total_outbound		= @cost_total_outbound	WHERE receipt_id = @receipt_id AND line_id = @line_id AND container_id = @container_id

IF @container_id < @max_container_id GOTO Container
/*****************************************************************************************************************************************/

if @debug = 1 Select * from #tmp

SELECT @cost_processed	= SUM(cost_total_processed) FROM #tmp WHERE receipt_id = @receipt_id AND line_id = @line_id
SELECT @cost_outbound	= SUM(cost_total_outbound)	FROM #tmp WHERE receipt_id = @receipt_id AND line_id = @line_id
UPDATE #tmp SET cost_lab		= total_samples * @cost_lab_per		WHERE receipt_id = @receipt_id AND line_id = @line_id
UPDATE #tmp SET cost_process	= process_time * @cost_process_per	WHERE receipt_id = @receipt_id AND line_id = @line_id

UPDATE #tmp SET cost_total = @cost_processed
				+ @cost_outbound
				+ cost_lab
				+ cost_process
WHERE receipt_id = @receipt_id AND line_id = @line_id

SELECT @invoice_amt = SUM(ISNULL(total_extended_amt, 0.00)) FROM receiptprice WHERE receipt_id = @receipt_id AND line_id = @line_id
UPDATE #tmp SET invoice_amount = @invoice_amt WHERE receipt_id = @receipt_id AND line_id = @line_id
UPDATE #tmp SET total_margin = invoice_amount - cost_total WHERE receipt_id = @receipt_id AND line_id = @line_id
IF @invoice_amt > 0.00
BEGIN
    UPDATE #tmp SET percent_margin = total_margin / invoice_amount WHERE receipt_id = @receipt_id AND line_id = @line_id
END

IF @line_id < @max_line_id GOTO Line

IF @receipt_id < @max_receipt_id GOTO Receipt
/************************************************************************************************************/
UPDATE #tmp SET invoice_amount = 0.00, cost_total = 0.00 WHERE min_container_id = 0

SELECT	
	receipt_date,
	#tmp.generator_id,
	manifest,
	total_containers_received,
	fuel,
	total_containers_processed,
	cost_disposal_processed,
	cost_total_processed,
	location,
	total_containers_outbound,
	cost_disposal_outbound, 
	cost_total_outbound, 
	total_samples,
	cost_lab,
	process_time,
	cost_process,
	cost_total,
	invoice_amount,
	total_margin,
	percent_margin,
	comments,
	receipt_id, 
	line_id,
	#tmp.company_id,
	#tmp.profit_ctr_id,
	container_id,
	approval_code,
	bill_unit_code,
	bulk_flag,
	treatment_id,
	receipt_status,
	location_type,
	g.epa_id,
	g.generator_name,
	c.company_name,
	pc.profit_ctr_name
FROM #tmp
JOIN Company c
	ON c.company_id = #tmp.company_id
JOIN ProfitCenter pc
	ON pc.company_ID = #tmp.company_id
	AND pc.profit_ctr_ID = #tmp.profit_ctr_id
JOIN generator g
	ON #tmp.generator_id = g.generator_id
ORDER BY receipt_date, receipt_id, line_id, container_id

DROP TABLE #tmp

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_margin_nonbulk] TO [EQAI]
    AS [dbo];

