DROP PROCEDURE IF EXISTS [dbo].[sp_rpt_batch_ccvoc]
GO

CREATE PROCEDURE sp_rpt_batch_ccvoc
	@date_from		datetime,
	@date_to		datetime,
	@location		varchar(15),
	@tracking_num	varchar(15),
	@company_id		int,
	@profit_ctr_id	int
AS
/***************************************************************************************
Filename:		L:\Apps\SQL-Deploy\Prod\NTSQL1\PLT_XX_AI\Procedures\sp_rpt_batch_ccvoc.sql
PB Object(s):	d_rpt_batch_ccvoc

VOC(e) = SUM{ V(i) x W(i) x D(i) }   x   Er   x   [1 - A(e)]

Where	VOC(e) = Cumulative VOC/HAP emissions from the unit during the period
	i = Each iteration of waste stream treated during the period
	V(i) = Volume of waste stream i processed
	W(i) = Weight fraction of VOC/HAP present in waste stream i processed
	D(i) = Density of waste stream i processed in appropriate unit; assumed to average 8.5 lbs/gal
	Er = Emission factor for VOC/HAP released from waste during treatment process (based on site specific data and testing)
		0.30 for Site 2 (East Side)
		0.30 for Site 2 (West Side)
	A(e) = Control efficiency
		0.05 for Site 2 (East Side)
		0 for Site 2 (West Side)

11/23/2009 JDB	Created; copied from sp_rpt_ccvoc
06/24/2014 AM Moved to plt_ai
01/26/2022 MPM	DevOps 27249 - Modified the calculation of emissions to be the same as in the HAP Report (DevOps 17534).

SELECT * FROM BatchTransferReceipt
sp_rpt_batch_ccvoc '11-1-2009', '11-27-2009', 'TDU', '100', 2, 21
sp_rpt_batch_ccvoc '11-1-2009', '11-27-2009', 'TDU', '200', 2, 21
sp_rpt_batch_ccvoc '1-1-2021', '12-31-2021', 'F', '51153', 2, 0
****************************************************************************************/
DECLARE	@date_from_12			datetime,
	@date_from_total			datetime,
	@rolling_tons_voc			float,
	@rolling_emissions_east		float,
	@rolling_emissions_west		float,
	@rolling_emissions_reportable	float,
	--@Er_site2_east				float,
	--@Er_site2_west				float,
	--@Ae_site2_east				float,
	--@Ae_site2_west				float,
	@pound_ton_conversion		float,
	@debug						int

SET NOCOUNT ON
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
	PRINT ''
END

---- Emissions Factor
--SET @Er_site2_east = 0.30
--SET @Er_site2_west = 0.30

---- Control Efficiency
--SET @Ae_site2_east = 0.95
--SET @Ae_site2_west = 0.00

SET @pound_ton_conversion = 0.0005	--  1 / 2000 = 0.0005

------------------------------------------------------------------------------------------------
-- First part of the union selects containers that went directly into the specified location
------------------------------------------------------------------------------------------------
SELECT	1 AS report_union_part,
	r.company_id, 
	r.profit_ctr_id,
	r.receipt_id,
	r.line_id,
	r.manifest, 
	r.bulk_flag, 
	r.receipt_date,
	d.disposal_date,
	r.approval_code, 
	r.waste_code, 
	g.generator_name, 
	r.quantity AS quantity, 
	ISNULL(r.bill_unit_code, 'VAR') AS bill_unit_code,
	r.container_count, 
	c.container_id,
	c.container_weight,
	d.container_percent,
	ISNULL(r.net_weight, 0) AS net_weight,
	ROUND((r.ccvoc/1000000), 8) AS VOC, 
	r.location, 
	d.location AS container_location, 
	pl.location_report_flag,
	CASE WHEN pl.location_report_flag = 'E' THEN 'East'
		WHEN pl.location_report_flag = 'W' THEN 'West'
		WHEN pl.location_report_flag = 'R' THEN 'Reportable'
		WHEN pl.location_report_flag = 'N' THEN 'N/R'
	END AS location_description,
	CASE WHEN ISNULL(c.container_weight, 0.00) * (d.container_percent / 100.0) > 0 
			THEN c.container_weight * (d.container_percent / 100.0)
		WHEN ((ISNULL(r.net_weight, 0) / r.container_count) * (d.container_percent / 100.0)) > 0
			THEN ((ISNULL(r.net_weight, 0) / r.container_count) * (d.container_percent / 100.0))
		ELSE (SELECT (SUM(ISNULL((ISNULL(rp.bill_quantity, 0) * ISNULL(b.pound_conv, 0)), 0)) / r.container_count) * (d.container_percent / 100.0)
				FROM Receipt r1
				INNER JOIN ReceiptPrice rp ON r1.company_id = rp.company_id
					AND r1.profit_ctr_id = rp.profit_ctr_id
					AND r1.receipt_id = rp.receipt_id
					AND r1.line_id = rp.line_id
				INNER JOIN BillUnit b ON rp.bill_unit_code = b.bill_unit_code
				WHERE r.company_id = r1.company_id
					AND r.profit_ctr_id = r1.profit_ctr_id
					AND r.receipt_id = r1.receipt_id
					AND r.line_id = r1.line_id
				)
	END AS pounds,
	CONVERT(float, 0) AS tons_voc,
	CONVERT(float, 0) AS emissions,
	COALESCE(pl.emission_factor, pccc.emissions_factor_value, 1) as emission_factor,
	COALESCE(pccc.control_efficiency_value, 0) as control_efficiency_value
INTO #tmp
FROM Receipt r
INNER JOIN Generator g 
	ON r.generator_id = g.generator_id
INNER JOIN Container c 
	ON r.company_id = c.company_id
	AND r.profit_ctr_id = c.profit_ctr_id
	AND r.receipt_id = c.receipt_id
	AND r.line_id = c.line_id
INNER JOIN ContainerDestination d 
	ON r.company_id = d.company_id
	AND r.profit_ctr_id = d.profit_ctr_id
	AND r.receipt_id = d.receipt_id
	AND r.line_id = d.line_id
	AND c.container_id = d.container_id
INNER JOIN ProcessLocation pl 
	ON pl.company_id = d.company_id
	AND pl.profit_ctr_id = d.profit_ctr_id
	AND pl.location = d.location
	AND pl.location_report_flag <> 'N'
LEFT OUTER JOIN ProfitCenterCCVOCDDVOHAP pccc
	ON pccc.company_id = pl.company_id
	AND pccc.profit_ctr_id = pl.profit_ctr_id
	AND pccc.location_report_flag = pl.location_report_flag 
WHERE 1=1
AND r.receipt_status = 'A'
AND r.trans_type = 'D'
AND r.trans_mode = 'I'
AND (r.ccvoc IS NOT NULL AND r.ccvoc > 0)
AND pl.location_report_flag <> 'N'
AND r.company_id = @company_id
AND r.profit_ctr_id = @profit_ctr_id
AND d.disposal_date BETWEEN @date_from_total AND @date_to
AND d.location = @location
AND d.tracking_num = @tracking_num

UNION ALL

------------------------------------------------------------------------------------------------------
-- Second part of the union selects receipts that were transferred into the specified batch location
-- NOTE:  If the same receipt has containers in both selects, this will over-report the pounds value.
--			This is OK per our discussion on 11/23/09.
------------------------------------------------------------------------------------------------------
SELECT	2 AS report_union_part,
	r.company_id, 
	r.profit_ctr_id,
	r.receipt_id,
	r.line_id,
	r.manifest, 
	r.bulk_flag, 
	r.receipt_date,
	btr.date_added AS disposal_date,
	r.approval_code, 
	r.waste_code, 
	g.generator_name, 
	r.quantity, 
	ISNULL(r.bill_unit_code, 'VAR') AS bill_unit_code,
	r.container_count, 
	c.container_id,
	c.container_weight,
	d.container_percent,
	ISNULL(r.net_weight, 0) AS net_weight,
	ROUND((r.ccvoc/1000000), 8) AS VOC, 
	r.location, 
	btr.to_location AS container_location, 
	pl.location_report_flag,
	CASE WHEN pl.location_report_flag = 'E' THEN 'East'
		WHEN pl.location_report_flag = 'W' THEN 'West'
		WHEN pl.location_report_flag = 'R' THEN 'Reportable'
		WHEN pl.location_report_flag = 'N' THEN 'N/R'
	END AS location_description,
	CASE WHEN ISNULL(c.container_weight, 0.00) * (d.container_percent / 100.0) > 0 
			THEN c.container_weight * (d.container_percent / 100.0)
		WHEN ((ISNULL(r.net_weight, 0) / r.container_count) * (d.container_percent / 100.0)) > 0
			THEN ((ISNULL(r.net_weight, 0) / r.container_count) * (d.container_percent / 100.0))
		ELSE (SELECT (SUM(ISNULL((ISNULL(rp.bill_quantity, 0) * ISNULL(b.pound_conv, 0)), 0)) / r.container_count) * (d.container_percent / 100.0)
				FROM Receipt r1
				INNER JOIN ReceiptPrice rp ON r1.company_id = rp.company_id
					AND r1.profit_ctr_id = rp.profit_ctr_id
					AND r1.receipt_id = rp.receipt_id
					AND r1.line_id = rp.line_id
				INNER JOIN BillUnit b ON rp.bill_unit_code = b.bill_unit_code
				WHERE r.company_id = r1.company_id
					AND r.profit_ctr_id = r1.profit_ctr_id
					AND r.receipt_id = r1.receipt_id
					AND r.line_id = r1.line_id
				)
	END AS pounds,
	CONVERT(float, 0) AS tons_voc,
	CONVERT(float, 0) AS emissions,
	COALESCE(pl.emission_factor, pccc.emissions_factor_value, 1) as emission_factor,
	COALESCE(pccc.control_efficiency_value, 0) as control_efficiency_value
FROM Receipt r
INNER JOIN Generator g 
	ON r.generator_id = g.generator_id
INNER JOIN Container c 
	ON r.company_id = c.company_id
	AND r.profit_ctr_id = c.profit_ctr_id
	AND r.receipt_id = c.receipt_id
	AND r.line_id = c.line_id
INNER JOIN ContainerDestination d 
	ON r.company_id = d.company_id
	AND r.profit_ctr_id = d.profit_ctr_id
	AND r.receipt_id = d.receipt_id
	AND r.line_id = d.line_id
	AND c.container_id = d.container_id
INNER JOIN BatchTransferReceipt btr 
	ON r.company_id = btr.company_id
	AND r.profit_ctr_id = btr.profit_ctr_id
	AND r.receipt_id = btr.receipt_id
	AND r.line_id = btr.line_id
INNER JOIN ProcessLocation pl 
	ON pl.company_id = btr.company_id
	AND pl.profit_ctr_id = btr.profit_ctr_id
	AND pl.location = btr.to_location
	AND pl.location_report_flag <> 'N'
LEFT OUTER JOIN ProfitCenterCCVOCDDVOHAP pccc
	ON pccc.company_id = pl.company_id
	AND pccc.profit_ctr_id = pl.profit_ctr_id
	AND pccc.location_report_flag = pl.location_report_flag 
WHERE 1=1
AND r.receipt_status = 'A'
AND r.trans_type = 'D'
AND r.trans_mode = 'I'
AND (r.ccvoc IS NOT NULL AND r.ccvoc > 0)
AND pl.location_report_flag <> 'N'
AND r.company_id = @company_id
AND r.profit_ctr_id = @profit_ctr_id
AND btr.date_added BETWEEN @date_from_total AND @date_to
AND btr.to_location = @location
AND btr.to_tracking_num = @tracking_num

IF @debug = 1 SELECT * FROM #tmp


UPDATE #tmp SET tons_voc = ROUND((pounds * VOC * @pound_ton_conversion), 8)

--IF @company_id = 2
--BEGIN
--	UPDATE #tmp 
--	SET emissions = ROUND((tons_voc * @Er_site2_east * (1 - @Ae_site2_east)), 8)
--	WHERE location_report_flag = 'E'

--	UPDATE #tmp 
--	SET emissions = ROUND((tons_voc * @Er_site2_west * (1 - @Ae_site2_west)), 8)
--	WHERE location_report_flag = 'W'
--END

/*	MPM - 5/13/2022 - DevOps 27249 - Modified the calculation of emissions to be the same as in the HAP Report (DevOps 17534).  

	The formula is:

	emissions = tons_voc   x   Er   x   [1 - A(e)]

	Where:	
		Er = Emission factor for VOC/HAP released from waste during treatment process 
		A(e) = Control efficiency

	Er (emission_factor) determination:

		1. If the emission factor is set on the process location for where the waste was managed (ProcessLocation.emission_factor), 
			use that.
		2. Else, if the emission factor is not set on the process location but exists in the site emission factor table 
			(ProfitCenterCCVOCDDVOHAP) for the company_id, profit_ctr_id and location_report_flag values in the corresponding 
			ProcessLocation row, use that.
		3. Else, if there is no row in the site emission factor table for the company_id, profit_ctr_id and location_report_flag 
			values in the corresponding ProcessLocation row, then use a value of 1.

	A(e) (control_efficiency_value) determination:
		1. If the control efficiency value exists in the site emission factor table (ProfitCenterCCVOCDDVOHAP) for the company_id, 
			profit_ctr_id and location_report_flag values in the corresponding ProcessLocation row, use that.
		2. Else, if there is no row in the emission factor table for the company_id, profit_ctr_id and location_report_flag 
			values in the corresponding ProcessLocation row, then use a value of 0.

*/

UPDATE #tmp SET emissions = ROUND(tons_voc * emission_factor * (1 - control_efficiency_value), 8)

SELECT @rolling_tons_voc = SUM(tons_voc) FROM #tmp WHERE disposal_date BETWEEN @date_from_12 AND @date_to
SELECT @rolling_emissions_east = SUM(emissions) FROM #tmp WHERE location_report_flag = 'E' AND disposal_date BETWEEN @date_from_12 AND @date_to
SELECT @rolling_emissions_west = SUM(emissions) FROM #tmp WHERE location_report_flag = 'W' AND disposal_date BETWEEN @date_from_12 AND @date_to
SELECT @rolling_emissions_reportable = SUM(emissions) FROM #tmp WHERE location_report_flag = 'R' AND disposal_date BETWEEN @date_from_12 AND @date_to

IF @debug = 1
BEGIN
	PRINT '@rolling_tons_voc = ' + CONVERT(varchar(20), @rolling_tons_voc)
	PRINT '@rolling_emissions_east = ' + CONVERT(varchar(20), @rolling_emissions_east)
	PRINT '@rolling_emissions_west = ' + CONVERT(varchar(20), @rolling_emissions_west)
	PRINT '@rolling_emissions_reportable = ' + CONVERT(varchar(20), @rolling_emissions_reportable)
END

SELECT	company_id,
	profit_ctr_id,
	receipt_id,
	line_id,
	manifest, 
	bulk_flag, 
	receipt_date,
	disposal_date,
	approval_code, 
	waste_code, 
	generator_name, 
	quantity, 
	container_count, 
	net_weight, 
	VOC, 
	--NULL AS pound_conv, 
	bill_unit_code, 
	location, 
	container_location, 
	location_report_flag,
	location_description,
	ROUND(SUM(pounds), 0) AS pounds,
	ROUND(SUM(tons_voc), 4) AS tons_voc,
	ROUND(SUM(emissions), 4) AS emissions,
	ROUND(@rolling_tons_voc, 4) AS rolling_tons_voc, 
	ROUND(@rolling_emissions_east, 4) AS rolling_emissions_east,
	ROUND(@rolling_emissions_west, 4) AS rolling_emissions_west,
	ROUND(@rolling_emissions_reportable, 4) AS rolling_emissions_reportable
FROM #tmp
WHERE disposal_date BETWEEN @date_from AND @date_to
GROUP BY company_id,
	profit_ctr_id,
	receipt_id,
	line_id,
	manifest, 
	bulk_flag, 
	receipt_date,
	disposal_date,
	approval_code, 
	waste_code, 
	generator_name, 
	quantity, 
	container_count, 
	net_weight, 
	VOC,
	bill_unit_code, 
	location, 
	container_location, 
	location_report_flag,
	location_description
ORDER BY disposal_date,
	receipt_date,
	approval_code

DROP TABLE #tmp

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_batch_ccvoc] TO [EQAI]
    AS [dbo];

