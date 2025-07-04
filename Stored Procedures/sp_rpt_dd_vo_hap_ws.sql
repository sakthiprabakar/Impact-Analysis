﻿DROP PROCEDURE IF EXISTS sp_rpt_dd_vo_hap_ws
GO

CREATE PROCEDURE sp_rpt_dd_vo_hap_ws
	@company_id		int
,	@profit_ctr_id	int
,	@date_from		datetime
,	@date_to		datetime
,	@cust_id_from	int
,	@cust_id_to		int
AS

/***************************************************************************************
PB Object(s):	r_dd_vo_hap_worksheet

VOC(e) = SUM{ V(i) x W(i) x D(i) }   x   Er   x   [1 - A(e)]

Where	VOC(e) = Cumulative VOC/HAP emissions from the unit during the period
	i = Each iteration of waste stream treated during the period
	V(i) = Volume of waste stream i processed
	W(i) = Weight fraction of VOC/HAP present in waste streatm i processed
	D(i) = Density of waste stream i processed in appropriate unit; assumed to average 8.5 lbs/gal
	Er = Emission factor for VOC/HAP released from waste during treatment process (based on site specific data and testing)
		0.30 for Site 2 (East Side)
		0.30 for Site 2 (West Side)
		0.15 for EQ Detroit
	A(e) = Control efficiency
		0.05 for Site 2 (East Side)
		0 for Site 2 (West Side)
		0 for EQ Detroit

01/27/1999 SCC	Changed bill_unit_desc result var to bill_unit_code
08/13/1999 JDB/LT Using bulk_flag for bulk and non-bulk calcs
		The druminfo table began being populated on Aug. 1st, 1999
09/22/1999 JDB	Added disposal_date in order to display both Date Rec'd and Date
		Dis'd on the WCVOC Worksheet
09/28/2000 LJT	Changed = NULL to is NULL and <> null to is not null
08/05/2002 SCC	Added trans_mode to receipt join
09/26/2002 JDB	Changed to use new drum tables
03/12/2003 JDB	Changed to use receipt.wcvoc instead of approval.wcvoc
03/19/2003 JDB	Corrected join from receipt and generator tables
03/20/2003 JDB	Modified to use receipt.DDVOC field.  This must be divided by 1,000,000
		to produce the correct values.
03/21/2003 JDB	Added calculation of emissions_east and emissions_west.  Changed
		calculation of rolling 12-month to use 365 days prior to end date.
06/11/2003 SCC	Changed references to location table to ProcessLocation table
10/07/2003 JDB	Changed sp name from sp_rpt_wcvoc to sp_rpt_voc.
11/11/2004 MK	Changed generator_code to generator_id
11/23/2004 JDB	Changed ticket_id to line_id, drumdetail to container table
01/06/2005 SCC	Changed for Container Tracking
02/24/2006 JDB	Added company and profit center to parameters, updated to run for EQ Detroit
12/23/2010 SK	Added Emissions factor & Control efficiency for EQ Oklahama company:29
				Added logic for counting consolidated containers
01/03/2011 SK	Fixed the perfomance issue by removing cursor, removing table #tmp_containers			
05/19/2011 RWB	Fixed bug by removing join Receipt.bill_unit_code = BillUnit.bill_unit_code
				(had been used to reference pounds_conv in order to calculate pounds, it now
				 references Container.container_weight, ContainerDestination.container_percent,
				 and new function fn_receipt_line_pounds to determine pounds).
				Removed pound_conv and bill_unit_code from result set.
				Added treatment to the result set.
				Removed r.ccvoc > 0 from where clause.
				Removed outdated bulk_flag/receipt_date reference from where clauses.
				Removed where clause from join to fn_container_source().
07/08/2011 SK	report ddvoc = 0 values only for company 29 (EQ Oklahama), for others enforce r.ddvoc > 0 in Where clause
				this can be converted to an input parm later	
07/13/2011 SK	remove the above enforced r.ddvoc > 0							
12/20/2012 RB	Added ContainerDestination.container_percent to #tmp_receipts and #tmp tables for final line weight
08/21/2013 SM	Added wastecode table and displaying Display name
01/02/2013 RB	treatment_id was null for some old stock container records (2009) and report was crashing...changed to
		allow nulls in temp table
07/14/2014 AM	Added code for more company's and created table to get data insted of hard coded in sp.
08/14/2014 SM	Added function call to return all the waste codes with order and state. Added haz flag
06/28/2022 GDE DevOps 42738 - DD VO HAP Worksheet - Report update
04/20/2023 MPM	DevOps 27258 - Modified the calcuation of pounds_emission so that it's done in the same way as was done to the 
				HAP Report under DevOps 17354.
08/01/2023 Dipankar - DevOps 50330 - Implemented DBA Observation comments

sp_rpt_dd_vo_hap_ws 2, 0,'6-1-2013', '06-30-2014', 1, 999999
sp_rpt_dd_vo_hap_ws 22, 0,'1-1-2013', '1-3-2013', 1, 999999
sp_rpt_dd_vo_hap_ws  21, 0, '10-01-2010', '10-03-2010', 0, 200000
****************************************************************************************/
CREATE TABLE #tmp_receipts (
	company_id		int
,	profit_ctr_id	int
,	receipt_id		int
,	line_id			int
,	line_weight		decimal(18,6) --rb
,	treatment_id	int null --rb
,	location		varchar(15)
,	location_report_flag	char(1)
,	disposal_date	datetime
,	container_percent	int --rb 12/20/2012
,	emission_factor				float		null
,	control_efficiency_value	float		null
)

--rb DECLARE @tmp_consolidated TABLE(
CREATE TABLE #tmp_consolidated (
	record_id		int	 identity
,	receipt_id		int
,	line_id			int
,	container_id	int
,	sequence_id		int
,	treatment_id	int null --rb
,	final_location	varchar(15)
,	location_report_flag	char(1)
,	disposal_date	datetime
,	processed_flag	tinyint
)

DECLARE	
	@date_from_12			datetime,
	@date_from_total		datetime,
	@rolling_tons_voc		float,
	@rolling_emissions_east	float,
	@rolling_emissions_west	float,
	@rolling_emissions_reportable	float,
	@rolling_emissions_nr	float,
	--@Er_detroit				float,
	--@Er_site2_east			float,
	--@Er_site2_west			float,
	--@Er_EQOK				float,
	--@Ae_detroit				float,
	--@Ae_site2_east			float,
	--@Ae_site2_west			float,
	--@Ae_EQOK				float,
	@pound_ton_conversion	float,
	--@receipt_id				int,
	--@line_id				int,
	--@container_id			int,
	--@sequence_id			int,
	--@location				varchar(15),
	--@location_rpt_flag		char(1),
	--@disposal_date			datetime,
	@debug					int
	--@record_id				int,
	--@treatment_id			int, -- rb 05/19/2011
	--@rpt_zero_flag			char(1)	
	
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
SET @debug = 0
-- do not report 0's by default
--SET @rpt_zero_flag = 'F'

-- Set date range we want to check for rolling 12 month
SET @date_from_12 = DATEADD(day, -365, @date_to)


-- Set @date_from_total to the earlier of
-- a. One year before @date_to input parameter
-- b. @date_from input paramter
SET @date_from_total = @date_from_12
IF @date_from < @date_from_12 SET @date_from_total = @date_from

IF @debug = 0
BEGIN
	PRINT 'Rolling 12 month date range:  ' + CONVERT(varchar(11), @date_from_12) + ' to ' + CONVERT(varchar(11), @date_to)
END

-- Emissions Factor
-- SET @Er_detroit = 0.15
-- SET @Er_site2_east = 0.30
-- SET @Er_site2_west = 0.30
-- SET @Er_EQOK	= 1.0

-- Control Efficiency
-- SET @Ae_detroit = 0.00
-- SET @Ae_site2_east = 0.95
-- SET @Ae_site2_west = 0.00
-- SET @Ae_EQOK	= 0.95

---- FOR EQOK allow reporting 0's
--IF @company_id = 29 SET @rpt_zero_flag = 'T'

SET @pound_ton_conversion = 0.0005	--  1 / 2000 = 0.0005

------------------------------------------------------------------------------------------------------------------
-- Get all receipts that directly went into process location within the date range
-- This version of the VOC report is valid only after the June 5, 1997 date hard-coded into this procedure.
------------------------------------------------------------------------------------------------------------------
INSERT #tmp_receipts
SELECT
	cd.company_id
,	cd.profit_ctr_id
,	cd.receipt_id
,	cd.line_id
,	isnull(c.container_weight * cd.container_percent * 0.01,0) as line_weight --rb
,	cd.treatment_id --rb
,	pl.location AS location
,	pl.location_report_flag AS location_report_flag
,	cd.disposal_date AS disposal_date
,	isnull(cd.container_percent,100) as container_percent --rb 12/20/2012
,	COALESCE(pl.emission_factor, pccc.emissions_factor_value, 1) as emission_factor
,	COALESCE(pccc.control_efficiency_value, 0) as control_efficiency_value
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
JOIN Receipt r
	ON r.company_id = cd.company_id
	AND r.profit_ctr_id = cd.profit_ctr_id
	AND r.receipt_id = cd.receipt_id
	AND r.line_id = cd.line_id
	AND r.fingerpr_status = 'A'  
	AND r.receipt_status not in ('R', 'V')
	AND r.trans_type = 'D'
	AND r.trans_mode = 'I'
LEFT OUTER JOIN ProfitCenterCCVOCDDVOHAP pccc
	ON pccc.company_id = pl.company_id
	AND pccc.profit_ctr_id = pl.profit_ctr_id
	AND pccc.location_report_flag =  pl.location_report_flag 
--rb	AND ((r.bulk_flag = 'T' OR (r.bulk_flag = 'F' AND r.receipt_date < '08-01-1999')) OR
--		(r.bulk_flag = 'F' AND r.receipt_date > '07-31-1999'))
--	AND (r.ddvoc IS NOT NULL AND r.ddvoc > 0)
	--AND ((r.ddvoc > 0 AND r.ddvoc IS NOT NULL) OR @rpt_zero_flag = 'T')
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
END;

-----------------------------------------------------------------------------------------------
-- Get all containers that have something consolidated for the given date range
-----------------------------------------------------------------------------------------------
/* -- #50330 - Commented
INSERT #tmp_consolidated
SELECT
		cd.receipt_id
	,	cd.line_id
	,	cd.container_id
	,	cd.sequence_id
	,	cd.treatment_id --rb
	,	pl.location AS final_location
	,	pl.location_report_flag
	,	cd.disposal_date
	,	0 AS processed_flag
	FROM ContainerDestination cd
	JOIN ProcessLocation pl
		ON pl.company_id = cd.company_id
		AND pl.profit_ctr_id = cd.profit_ctr_id
		AND pl.location = cd.location
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
	,	cd.treatment_id --rb
	,	pl.location AS final_location
	,	pl.location_report_flag
	,	cd.disposal_date
	,	0 AS processed_flag
	FROM ContainerDestination cd
	JOIN ProcessLocation pl
		ON pl.company_id = cd.company_id
		AND pl.profit_ctr_id = cd.profit_ctr_id
		AND pl.location = cd.location
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
*/

-- #50330 - Added
WITH CDest AS (
	SELECT
		cd.receipt_id,	
		cd.line_id,	
		cd.container_id,	
		cd.sequence_id,	
		cd.treatment_id,	
		pl.location AS final_location,	
		pl.location_report_flag,	
		cd.disposal_date,	
		0 AS processed_flag, 
		container_type,
		CASE WHEN container_type = 'S' THEN 
			'DL-' + RIGHT('00' + CONVERT(varchar(2), cd.company_id), 2) 
					+ RIGHT('00' + CONVERT(varchar(2), cd.profit_ctr_id), 2) + '-'
					+ RIGHT('000000' + CONVERT(varchar(6), cd.container_id), 6) 
			WHEN container_type = 'R' THEN 
				CONVERT(varchar(10), cd.receipt_id) + '-' + CONVERT(varchar(10), cd.line_id) 
			ELSE tracking_num END AS c_tracking_num
	FROM ContainerDestination cd
	JOIN ProcessLocation pl
		ON pl.company_id = cd.company_id
		AND pl.profit_ctr_id = cd.profit_ctr_id
		AND pl.location = cd.location
	WHERE cd.company_id = @company_id	
		AND cd.profit_ctr_id = @profit_ctr_id
		AND cd.disposal_date  > '06-05-1997'
		AND cd.disposal_date BETWEEN @date_from_total AND @date_to
		AND cd.location_type = 'P'
		AND cd.container_type in ('R','S'))
INSERT  #tmp_consolidated
SELECT  CDest.receipt_id,	
		CDest.line_id,	
		CDest.container_id,	
		CDest.sequence_id,	
		CDest.treatment_id,	
		CDest.final_location,	
		CDest.location_report_flag,	
		CDest.disposal_date,	
		CDest.processed_flag
FROM CDest
WHERE EXISTS (  SELECT 1 FROM ContainerDestination CDInner
				WHERE CDInner.base_container_id = CDest.container_id
				AND   CDInner.base_sequence_id  = CDest.sequence_id
				AND   CDInner.base_tracking_num = CDest.c_tracking_num)
					
IF @debug = 1
BEGIN
	PRINT 'total in #tmp_consolidated' 
	Select count(1) from #tmp_consolidated
END;

/* -- #50330 - Commented
SELECT @record_id = Isnull(MIN(record_id), 0) FROM #tmp_consolidated WHERE processed_flag = 0
WHILE @record_id > 0
BEGIN
	SELECT
		@receipt_id = receipt_id
	,	@line_id = line_id
	,	@container_id = container_id
	,	@sequence_id = sequence_id
	,	@treatment_id = treatment_id --rb
	,	@location = final_location
	,	@location_rpt_flag = location_report_flag
	,	@disposal_date = disposal_date
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
	,	isnull(c.container_weight * cd.container_percent * 0.01,0) as line_weight --rb
	,	@treatment_id AS treatment_id --rb
	,	@location AS location
	,	@location_rpt_flag AS location_report_flag
	,	@disposal_date AS disposal_date
	,	isnull(cd.container_percent,100) as container_percent --rb 12/20/2012
	,	COALESCE(pl.emission_factor, pccc.emissions_factor_value, 1) as emission_factor
	,	COALESCE(pccc.control_efficiency_value, 0) as control_efficiency_value
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
	JOIN ProcessLocation pl
		ON pl.company_id = cd.company_id
		AND pl.profit_ctr_id = cd.profit_ctr_id
		AND pl.location = cd.location
	LEFT OUTER JOIN ProfitCenterCCVOCDDVOHAP pccc
		ON pccc.company_id = pl.company_id
		AND pccc.profit_ctr_id = pl.profit_ctr_id
		AND pccc.location_report_flag =  pl.location_report_flag 
/*** rb - was restricting nested receipts
	WHERE source_containers.destination_profit_ctr_id = @profit_ctr_id
		AND source_containers.destination_company_id = @company_id
		AND source_containers.destination_receipt_id = @receipt_id
		AND source_containers.destination_line_id = @line_id
		AND source_containers.destination_container_id = @container_id
		AND source_containers.destination_sequence_id = @sequence_id
***/	
	-- Update this row as processed
	Update #tmp_consolidated SET processed_flag = 1 WHERE record_id = @record_id
	-- Move to the next row
	SELECT @record_id = Isnull(MIN(record_id), 0) FROM #tmp_consolidated WHERE processed_flag = 0
END
*/
-- #50330 - Added
WITH source_containers AS
	(SELECT fcs.*, tmp.treatment_id, tmp.final_location as location, tmp.location_report_flag as location_rpt_flag, tmp.disposal_date as disposal_dt
	 FROM #tmp_consolidated tmp 
	 CROSS APPLY dbo.fn_container_source(@company_id, @profit_ctr_id, tmp.receipt_id, tmp.line_id, tmp.container_id, tmp.sequence_id, 1) fcs)
INSERT #tmp_receipts
SELECT
	source_containers.company_id
,	source_containers.profit_ctr_id
,	source_containers.receipt_id
,	source_containers.line_id
,	ISNULL(c.container_weight * cd.container_percent * 0.01,0) as line_weight --rb
,	source_containers.treatment_id AS treatment_id --rb
,	source_containers.location AS location
,	source_containers.location_rpt_flag AS location_report_flag
,	source_containers.disposal_dt AS disposal_date
,	ISNULL(cd.container_percent,100) as container_percent
,	COALESCE(pl.emission_factor, pccc.emissions_factor_value, 1) as emission_factor
,	COALESCE(pccc.control_efficiency_value, 0) as control_efficiency_value
FROM source_containers 
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
JOIN ProcessLocation pl
	ON pl.company_id = cd.company_id
	AND pl.profit_ctr_id = cd.profit_ctr_id
	AND pl.location = cd.location
LEFT OUTER JOIN ProfitCenterCCVOCDDVOHAP pccc
	ON pccc.company_id = pl.company_id
	AND pccc.profit_ctr_id = pl.profit_ctr_id
	AND pccc.location_report_flag =  pl.location_report_flag 

IF @debug = 1
BEGIN
	PRINT 'total in #tmp_receipts' 
	Select count(1) from #tmp_receipts
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
,	tr.disposal_date
,	r.approval_code
,	dbo.fn_receipt_waste_code_list_all_long(r.company_id,r.profit_ctr_id,r.receipt_id,r.line_id ) as waste_code
,	g.generator_name
,	r.quantity
,	1 AS container_count
,	ISNULL(r.net_weight, 0) AS net_weight
,	ROUND((r.ddvoc/1000000), 8) AS VOC
--rb,	ISNULL(b.pound_conv, 0) AS pound_conv
--rb,	r.bill_unit_code
,	r.location
,	tr.location AS container_location
,	tr.location_report_flag
,	CASE WHEN tr.location_report_flag = 'E' THEN 'East'
		 WHEN tr.location_report_flag = 'W' THEN 'West'
		 WHEN tr.location_report_flag = 'R' THEN 'Reportable'
		 WHEN tr.location_report_flag = 'N' THEN 'N/R'
	END AS location_description
--rb,	CONVERT(int, 0) AS pounds
,	case when tr.line_weight > 0 then tr.line_weight
		else dbo.fn_receipt_line_pounds (tr.company_id, tr.profit_ctr_id, tr.receipt_id, tr.line_id) * tr.container_percent * 0.01 end AS pounds --rb 12/20/2012
,	CONVERT(float, 0) AS tons_voc
,	CONVERT(float, 0) AS emissions
,	tr.treatment_id as treatment_id --rb
,	tr.emission_factor
,	tr.control_efficiency_value
INTO #tmp
FROM Receipt r
--rbJOIN BillUnit b
--	ON b.bill_unit_code = r.bill_unit_code
JOIN Generator g
	ON g.generator_id = r.generator_id
LEFT OUTER JOIN wastecode  w on w.waste_code_uid = r.waste_code_uid
JOIN #tmp_receipts tr
	ON tr.company_id = r.company_id
	AND tr.profit_ctr_id = r.profit_ctr_id
	AND tr.receipt_id = r.receipt_id
	AND tr.line_id = r.line_id
WHERE r.customer_id BETWEEN @cust_id_from AND @cust_id_to
	AND r.company_id = @company_id
	AND r.profit_ctr_id = @profit_ctr_id
	AND r.fingerpr_status = 'A'  
	AND r.receipt_status not in ('R', 'V')
	AND r.trans_type = 'D'
	AND r.trans_mode = 'I'
--rb	AND ((r.bulk_flag = 'T' OR (r.bulk_flag = 'F' AND r.receipt_date < '08-01-1999')) OR
--		(r.bulk_flag = 'F' AND r.receipt_date > '07-31-1999'))
--	AND (r.ddvoc IS NOT NULL AND r.ddvoc > 0)
	--AND ((r.ddvoc > 0 AND r.ddvoc IS NOT NULL) OR @rpt_zero_flag = 'T')
	
IF @debug = 1 PRINT 'Selecting from #tmp'
IF @debug = 1 Select * from #tmp
/*** rb 05/19/2011
UPDATE #tmp SET pounds = ISNULL(ROUND((quantity * pound_conv), 0), 0)
WHERE bulk_flag = 'T' AND net_weight IS NULL AND pounds = 0

UPDATE #tmp SET pounds = net_weight
WHERE bulk_flag = 'T' AND net_weight > 10 AND pounds = 0

UPDATE #tmp SET pounds = ISNULL(ROUND((quantity * pound_conv), 0), 0)
WHERE bulk_flag = 'T' AND pounds = 0

UPDATE #tmp SET pounds = net_weight
WHERE bulk_flag = 'F' AND container_count IS NULL AND net_weight > 10 AND pounds = 0

UPDATE #tmp SET pounds = ISNULL(ROUND((container_count * pound_conv), 0), 0)
WHERE bulk_flag = 'F' AND net_weight IS NULL AND pounds = 0

UPDATE #tmp SET pounds = net_weight
WHERE bulk_flag = 'F' AND net_weight > 10 AND pounds = 0

UPDATE #tmp SET pounds = ISNULL(ROUND((container_count * pound_conv), 0), 0)
WHERE bulk_flag = 'F' AND (net_weight IS NULL OR net_weight <= 10) AND pounds = 0
***/

UPDATE #tmp SET tons_voc = ROUND((pounds * VOC * @pound_ton_conversion), 8)

-- Get values from new ProfitCenterCCVOCDDVOHAP 
	--BEGIN		
	--	  UPDATE #tmp 
	--	 SET emissions = ROUND((tons_voc * ISNULL ( pccc.emissions_factor_value , 0 ) * (1 - ISNULL ( pccc.control_efficiency_value, 0 ))), 8)
	--	  FROM #tmp
	--		JOIN ProfitCenterCCVOCDDVOHAP pccc
	--		ON #tmp.company_id = pccc.company_id
	--		AND #tmp.profit_ctr_id = pccc.profit_ctr_id
	--		AND #tmp.location_report_flag =  pccc.location_report_flag 
	--		  WHERE  #tmp.company_id = @company_id
 --		      AND #tmp.profit_ctr_id = @profit_ctr_id 	 
 --     END
	
/*	MPM - 4/14/2022 - DevOps 27258 - Corrected the calculation of emissions.  

	The formula is: emissions = tons_voc * emission_factor * (1 - control_efficiency_value)

	emission_factor determination:

		1. If the emission factor is set on the process location for where the waste was managed (ProcessLocation.emission_factor), 
			use that.
		2. Else, if the emission factor is not set on the process location but exists in the site emission factor table 
			(ProfitCenterCCVOCDDVOHAP) for the company_id, profit_ctr_id and location_report_flag values in the corresponding 
			ProcessLocation row, use that.
		3. Else, if there is no row in the site emission factor table for the company_id, profit_ctr_id and location_report_flag 
			values in the corresponding ProcessLocation row, then use a value of 1.

	control_efficiency_value determination:

		1. If the control efficiency value exists in the site emission factor table (ProfitCenterCCVOCDDVOHAP) for the company_id, 
			profit_ctr_id and location_report_flag values in the corresponding ProcessLocation row, use that.
		2. Else, if there is no row in the emission factor table for the company_id, profit_ctr_id and location_report_flag 
			values in the corresponding ProcessLocation row, then use a value of 0.

 */

UPDATE #tmp SET emissions = ROUND(tons_voc * emission_factor * (1 - control_efficiency_value), 8)

SELECT @rolling_tons_voc				= SUM(isnull(tons_voc,0)) FROM #tmp WHERE disposal_date BETWEEN @date_from_12 AND @date_to
SELECT @rolling_emissions_east			= SUM(isnull(emissions,0)) FROM #tmp WHERE location_report_flag = 'E' AND disposal_date BETWEEN @date_from_12 AND @date_to
SELECT @rolling_emissions_west			= SUM(isnull(emissions,0)) FROM #tmp WHERE location_report_flag = 'W' AND disposal_date BETWEEN @date_from_12 AND @date_to
SELECT @rolling_emissions_reportable	= SUM(isnull(emissions,0)) FROM #tmp WHERE location_report_flag = 'R' AND disposal_date BETWEEN @date_from_12 AND @date_to
SELECT @rolling_emissions_nr			= SUM(isnull(emissions,0)) FROM #tmp WHERE location_report_flag = 'N' AND disposal_date BETWEEN @date_from_12 AND @date_to

IF @debug = 1
BEGIN
	PRINT '@rolling_tons_voc = ' + CONVERT(varchar(20), @rolling_tons_voc)
	PRINT '@rolling_emissions_east = ' + CONVERT(varchar(20), @rolling_emissions_east)
	PRINT '@rolling_emissions_west = ' + CONVERT(varchar(20), @rolling_emissions_west)
	PRINT '@rolling_emissions_reportable = ' + CONVERT(varchar(20), @rolling_emissions_reportable)
END

SELECT	
	#tmp.company_id,
	#tmp.profit_ctr_id,
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
--rb	pound_conv, 
--rb	bill_unit_code, 
	location, 
	container_location, 
	location_report_flag,
	location_description,
	CONVERT(int,ROUND(pounds, 0)) as pounds, --rb
	ROUND(tons_voc, 4) as tons_voc,
	ROUND(emissions, 4) as emissions ,
	ROUND(@rolling_tons_voc, 4) AS rolling_tons_voc, 
	ROUND(@rolling_emissions_east, 4) AS rolling_emissions_east,
	ROUND(@rolling_emissions_west, 4) AS rolling_emissions_west,
	ROUND(@rolling_emissions_reportable, 4) AS rolling_emissions_reportable,
	ROUND(@rolling_emissions_nr, 4) AS rolling_emissions_nr,
	Company.company_name,
	ProfitCenter.profit_ctr_name,
	Treatment.Treatment_process_process, --rb,
	COALESCE ((SELECT  distinct 'Haz'
		FROM    ReceiptwasteCode RWC
        JOIN Wastecode W ON RWC.waste_code_uid = W.waste_code_uid
        JOIN TSDF t ON t.eq_company = rwc.company_id
                       AND t.eq_profit_ctr = rwc.profit_ctr_id
                       AND ISNULL(t.eq_flag, 'F') = 'T'
                       AND t.tsdf_status = 'A'
		WHERE   RWC.company_id = #tmp.company_id
        AND RWC.profit_ctr_id = #tmp.profit_ctr_id
        AND RWC.receipt_id = #tmp.receipt_id
        AND RWC.line_id = #tmp.line_id
        AND W.haz_flag = 'T'
        AND ( W.waste_code_origin = 'F'
              OR ( W.waste_code_origin = 'S'
                   AND W.state = t.tsdf_state
                 )
            )),'Non-Haz' ) as haz_flag
FROM #tmp
JOIN Company
	ON Company.company_id = #tmp.company_id
JOIN ProfitCenter
	ON ProfitCenter.company_id = #tmp.company_id
	AND ProfitCenter.profit_ctr_ID = #tmp.profit_ctr_id
JOIN Treatment
	ON Treatment.treatment_id = #tmp.treatment_id
	AND Treatment.company_id = #tmp.company_id
	AND Treatment.profit_ctr_id = #tmp.profit_ctr_id
WHERE disposal_date BETWEEN @date_from AND @date_to
ORDER BY disposal_date, receipt_date, approval_code

DROP TABLE #tmp
DROP TABLE #tmp_consolidated
DROP TABLE #tmp_receipts

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_dd_vo_hap_ws] TO [EQAI];


