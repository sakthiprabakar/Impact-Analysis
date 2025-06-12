CREATE PROCEDURE sp_qsi_tos_summary
	@company_id			int
,	@begin_date 		datetime
,	@end_date 			datetime
,	@customer_id_from 	int
,	@customer_id_to 	int
AS
/************************************************************************
This stored procedure is used for the "QSI Scores Report"
by the datawindow r_tos_qsi_summary

10-26-1999 JDB Added time_on_site calculations and problem cause
             calculations to be used with d_rpt_tos_qsi_summary.
12-16-1999 JDB Added logic to accomodate the truck_code.  This
	sets the qsi_flag to 'N' for all receipts that have
		the same truck_code and receipt_date where one of
		these receipts has a qsi_flag of 'N'
02-14-2000 JDB Added logic to properly calculate the number of
	trucks and/or loads using the truck_code.  The cal-
	culation for the time on site stayed the same.
03-06-2000 JDB Added logic to average the time on site for loads with
		the same truck code.
09-28-2000 LJT Changed = NULL to IS NULL AND <> NULL to IS NOT NULL
08-22-2001 JDB Modified standards for MDI and WDI:
	MDI Bulk:  120 min.	MDI Non-Bulk:  240 min.
	WDI Bulk:   90 min.	WDI Non-Bulk:  240 min.
02-21-2002 JDB Corrected UPDATE statements to not use the table alias
	(this change was required because the database
	compatibility level was set to 70.)
11-11-2004  MK  Changed generator_code to generator_id
10-22-2007  RG Modified standards for MDI and WDI and added DET:
	MDI Bulk:  120 min.	MDI Non-Bulk:  180 min.
	WDI Bulk:  120 min.	WDI Non-Bulk:  180 min.
    DET Bulk:  120 min.	DET Non-bulk:  180 min.
10-25-2007  LT Added Absolute value for scheduled time
10-29-2007  LT Added default measurment for all other companies
	Other Bulk:  120 min.	Other Non-Bulk:  180 min.
02-05-2008 JDB	Removed absolute value for scheduled time (in other words,
	a load will be counted if it arrives any time before 30 minutes after
	it's scheduled.)
11/16/2010 SK	added company_id as input arg.
				moved to Plt_AI

sp_qsi_tos_summary 14, '01/02/2008','01/02/2008',1,999999
************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

SET ansi_warnings OFF

DECLARE
	@truck_code 	varchar(10),
	@count 			int,
	@n_count 		int,
	@max_tc 		int,
	@receipt_date 	datetime,
	@receipt_id 	int,
	@profit_ctr_id 	int,
	@avg_tos 		numeric(10,3),
	@qsi_flag 		varchar(2),
	@problem_cause 	varchar(1),
	@prob_e_count 	int,
	@prob_i_count 	int,
	@msg 			varchar(30),
	@other_bulk		int,
	@other_nonbulk	int,
	@mdi_bulk		int,
	@mdi_nonbulk	int,
	@wdi_bulk		int,
	@wdi_nonbulk	int,
	@det_bulk 		int,
	@det_nonbulk	int

SET NOCOUNT ON

SELECT DISTINCT 
	a.company_id,
	a.receipt_id,
	a.profit_ctr_id,
	a.customer_id,
	c.cust_name,
	a.generator_id,
	b.generator_name,
	official_time_in = a.time_in,
	a.time_in,
	a.time_out,
	a.date_scheduled,
	a.bulk_flag,
	time_on_site = DATEDIFF(minute, time_in, time_out),
	qsi_flag = '  ',
	a.problem_id,
	d.problem_cause,
	a.truck_code,
	a.receipt_date,
	count_as_truck = 0
INTO 	#tos_report_fields
FROM receipt a
LEFT OUTER JOIN generator b
	ON b.generator_id = a.generator_id
LEFT OUTER JOIN customer c
	ON c.customer_id = a.customer_id
LEFT OUTER JOIN receipt_problem d
	ON d.problem_id = a.problem_id
	AND d.company_id = a.company_id
WHERE 	a.receipt_status = 'A' 
	AND a.trans_type = 'D'
	AND a.trans_mode = 'I'
	AND a.receipt_date BETWEEN @begin_date AND @end_date
	AND a.customer_id BETWEEN @customer_id_from AND @customer_id_to
	AND a.company_id = @company_id

SET @mdi_bulk = 120
SET @mdi_nonbulk = 180
SET @wdi_bulk = 120
SET @wdi_nonbulk = 180
SET @det_bulk = 120
SET @det_nonbulk = 180
-- Other undefined facility Defaults
SET @other_bulk = 120
SET @other_nonbulk = 180

UPDATE #tos_report_fields SET date_scheduled = time_in WHERE company_id = 3
--	AND date_scheduled IS NULL  rg102207 ignore scheduled time for wdi

UPDATE 	#tos_report_fields
SET 	official_time_in = b.date_scheduled
FROM 	#tos_report_fields a, receipt b
WHERE 	a.receipt_id = b.receipt_id
	AND a.company_id = b.company_id
	AND a.profit_ctr_id = b.profit_ctr_id
    AND b.time_in < b.date_scheduled

UPDATE #tos_report_fields SET time_on_site = DATEDIFF(minute, official_time_in, time_out) 

UPDATE #tos_report_fields SET time_on_site = 0 WHERE time_on_site < 0 

-- mdi
UPDATE #tos_report_fields 
SET qsi_flag = 'QS'
WHERE 	date_scheduled IS NOT NULL
	AND company_id = 2
	AND DATEDIFF(minute, date_scheduled, time_in) <= 30  --arrives earlier than 30 minutes after scheduled time
	AND ((official_time_in < date_scheduled AND time_out < date_scheduled)  --comes in and leaves before scheduled
	  OR (DATEDIFF(minute, official_time_in, time_out) <= @mdi_bulk AND bulk_flag = 'T')
	  OR (DATEDIFF(minute, official_time_in, time_out) <= @mdi_nonbulk AND bulk_flag = 'F'))

UPDATE 	#tos_report_fields
SET 	qsi_flag = 'QN'
WHERE 	date_scheduled IS NOT NULL
	AND company_id = 2
	AND DATEDIFF(minute, date_scheduled, time_in) <= 30  --arrives earlier than 30 minutes after scheduled time
	AND ((DATEDIFF(minute, official_time_in, time_out) > @mdi_bulk AND bulk_flag = 'T')
	  OR (DATEDIFF(minute, official_time_in, time_out) > @mdi_nonbulk AND bulk_flag = 'F'))
	  
-- det
UPDATE 	#tos_report_fields
SET 	qsi_flag = 'QS'
WHERE 	date_scheduled IS NOT NULL
	AND company_id = 21
	AND DATEDIFF(minute, date_scheduled, time_in) <= 30  --arrives earlier than 30 minutes after scheduled time
	AND ((official_time_in < date_scheduled AND time_out < date_scheduled)  --comes in and leaves before scheduled
	  OR (DATEDIFF(minute, official_time_in, time_out) <= @det_bulk AND bulk_flag = 'T')
	  OR (DATEDIFF(minute, official_time_in, time_out) <= @det_nonbulk AND bulk_flag = 'F'))

UPDATE 	#tos_report_fields
SET 	qsi_flag = 'QN'
WHERE 	date_scheduled IS NOT NULL
	AND company_id = 21
	AND DATEDIFF(minute, date_scheduled, time_in) <= 30  --arrives earlier than 30 minutes after scheduled time
	AND ((DATEDIFF(minute, official_time_in, time_out) > @det_bulk AND bulk_flag = 'T')
	  OR (DATEDIFF(minute, official_time_in, time_out) > @det_nonbulk AND bulk_flag = 'F'))
	  
--wdi	  
UPDATE 	#tos_report_fields
SET 	qsi_flag = 'QS'
WHERE 	company_id = 3
--	AND DATEDIFF(minute, date_scheduled, time_in) <= 30  --arrives earlier than 30 minutes after scheduled time ignore for wdi
	AND ((DATEDIFF(minute, official_time_in, time_out) <= @wdi_bulk AND bulk_flag = 'T')
	  OR (DATEDIFF(minute, official_time_in, time_out) <= @wdi_nonbulk AND bulk_flag = 'F'))

UPDATE 	#tos_report_fields
SET 	qsi_flag = 'QN'
WHERE 	company_id = 3
--	AND DATEDIFF(minute, date_scheduled, time_in) <= 30  --arrives earlier than 30 minutes after scheduled time ignore for wdi
	AND ((DATEDIFF(minute, official_time_in, time_out) > @wdi_bulk AND bulk_flag = 'T')
	  OR (DATEDIFF(minute, official_time_in, time_out) > @wdi_nonbulk AND bulk_flag = 'F'))

-- Other undefined facility Defaults
UPDATE 	#tos_report_fields
SET 	qsi_flag = 'QS'
WHERE 	date_scheduled IS NOT NULL
	AND company_id not in(2,3,21)
	AND DATEDIFF(minute, date_scheduled, time_in) <= 30  --arrives earlier than 30 minutes after scheduled time
	AND ((official_time_in < date_scheduled AND time_out < date_scheduled)  --comes in and leaves before scheduled
	  OR (DATEDIFF(minute, official_time_in, time_out) <= @other_bulk AND bulk_flag = 'T')
	  OR (DATEDIFF(minute, official_time_in, time_out) <= @other_nonbulk AND bulk_flag = 'F'))

UPDATE 	#tos_report_fields
SET 	qsi_flag = 'QN'
WHERE 	date_scheduled IS NOT NULL
	AND company_id not in(2,3,21)
	AND DATEDIFF(minute, date_scheduled, time_in) <= 30  --arrives earlier than 30 minutes after scheduled time
	AND ((DATEDIFF(minute, official_time_in, time_out) > @other_bulk AND bulk_flag = 'T')
	 OR (DATEDIFF(minute, official_time_in, time_out) > @other_nonbulk AND bulk_flag = 'F'))
	  
-- schedule time is not valid for wdi
UPDATE 	#tos_report_fields
SET 	qsi_flag = 'N'
WHERE company_id <> 3
AND ( date_scheduled IS NULL
	OR DATEDIFF(minute, date_scheduled, time_in) > 30)
	

UPDATE 	#tos_report_fields
SET 	truck_code = '', count_as_truck = 1
WHERE 	(truck_code IS NULL OR truck_code = ' ') 
	    OR bulk_flag = 'T'

SELECT * INTO #tos_report_fields_2 FROM #tos_report_fields WHERE truck_code = ''

delete from #tos_report_fields where truck_code = ''

SELECT @receipt_id = 1

Receipt_date:

SELECT @receipt_date = MIN(receipt_date) FROM #tos_report_fields
SELECT @max_tc = COUNT(DISTINCT truck_code) FROM #tos_report_fields WHERE receipt_date = @receipt_date
SELECT @count = 1

Truck_code:

SET @n_count = 0
SET @prob_e_count = 0
SET @prob_i_count = 0
SELECT @truck_code = MIN(truck_code) FROM #tos_report_fields WHERE receipt_date = @receipt_date
SELECT @n_count = COUNT(*) FROM #tos_report_fields WHERE qsi_flag = 'N' AND truck_code = @truck_code AND receipt_date = @receipt_date
SELECT @prob_e_count = COUNT(*) FROM #tos_report_fields WHERE problem_cause = 'E' AND truck_code = @truck_code AND receipt_date = @receipt_date
SELECT @prob_i_count = COUNT(*) FROM #tos_report_fields WHERE problem_cause = 'I' AND truck_code = @truck_code AND receipt_date = @receipt_date

IF @prob_e_count > 0
   Begin
    SET @problem_cause = 'E'
    Update #tos_report_fields set problem_cause = 'E' WHERE truck_code = @truck_code AND receipt_date = @receipt_date
   END
ELSE
	IF @prob_I_count > 0
	   Begin
	    SET @problem_cause = 'I'
	    Update #tos_report_fields set problem_cause = 'I' WHERE truck_code = @truck_code AND receipt_date = @receipt_date
	   END
	ELSE
	    SET @problem_cause = NULL

IF @n_count > 0 
BEGIN
	SELECT @avg_tos = AVG(time_on_site) FROM #tos_report_fields WHERE truck_code = @truck_code AND receipt_date = @receipt_date
        Update #tos_report_fields set qsi_flag = 'N' WHERE truck_code = @truck_code AND receipt_date = @receipt_date
	INSERT #tos_report_fields VALUES 
	    (@company_id, @receipt_id, 99, @count, 'CUST', 0, 'GEN_NAME', @receipt_date, @receipt_date, @receipt_date, @receipt_date, 'F', 
	    @avg_tos, 'N', NULL, @problem_cause, @truck_code, @receipt_date, 1)
END
ELSE
BEGIN
    SELECT @avg_tos = AVG(time_on_site) FROM #tos_report_fields WHERE truck_code = @truck_code AND receipt_date = @receipt_date
    IF @company_id = 2
    BEGIN
	IF @avg_tos > @mdi_nonbulk
	    SELECT @qsi_flag = 'QN'
	ELSE
	    SELECT @qsi_flag = 'QS'

	INSERT #tos_report_fields VALUES 
	    (@company_id, @receipt_id, 99, 0, 'CUST', 0, 'GEN_NAME', @receipt_date, @receipt_date, @receipt_date, @receipt_date, 'F', 
	    @avg_tos, @qsi_flag, NULL, @problem_cause, @truck_code, @receipt_date, 1)
    END
    IF @company_id = 3
    BEGIN
	IF @avg_tos > @wdi_nonbulk
	    SELECT @qsi_flag = 'QN'
	ELSE
	    SELECT @qsi_flag = 'QS'

	INSERT #tos_report_fields VALUES 
	    (@company_id, @receipt_id, 99, 0, 'CUST', 0, 'GEN_NAME', @receipt_date, @receipt_date, @receipt_date, @receipt_date, 'F', 
	    @avg_tos, @qsi_flag, NULL, @problem_cause, @truck_code, @receipt_date, 1)
    END
    IF @company_id = 21
    BEGIN
	IF @avg_tos > @det_nonbulk
	    SELECT @qsi_flag = 'QN'
	ELSE
	    SELECT @qsi_flag = 'QS'

	INSERT #tos_report_fields VALUES 
	    (@company_id, @receipt_id, 99, 0, 'CUST', 0, 'GEN_NAME', @receipt_date, @receipt_date, @receipt_date, @receipt_date, 'F', 
	    @avg_tos, @qsi_flag, NULL, @problem_cause, @truck_code, @receipt_date, 1)
    END
    IF @company_id not in (2,3,21)
    BEGIN
	IF @avg_tos > @other_nonbulk
	    SELECT @qsi_flag = 'QN'
	ELSE
	    SELECT @qsi_flag = 'QS'

	INSERT #tos_report_fields VALUES 
	    (@company_id, @receipt_id, 99, 0, 'CUST', 0, 'GEN_NAME', @receipt_date, @receipt_date, @receipt_date, @receipt_date, 'F', 
	    @avg_tos, @qsi_flag, NULL, @problem_cause, @truck_code, @receipt_date, 1)
    END

END


INSERT INTO #tos_report_fields_2 SELECT * FROM #tos_report_fields WHERE truck_code = @truck_code AND receipt_date = @receipt_date
DELETE FROM #tos_report_fields WHERE truck_code = @truck_code AND receipt_date = @receipt_date

SELECT @receipt_id = @receipt_id + 1
SELECT @count = @count + 1
-- print Convert(varchar(10),@receipt_id)
-- print 'Is ' + Convert(varchar(6),@count) + ' <= ' + Convert(varchar(6),@max_tc) + '?'

IF @count < @max_tc GOTO Truck_code

-- print 'Is ' + Convert(varchar(20),@receipt_date) + ' <= ' + Convert(varchar(20),@end_date) + '?'

IF @receipt_date <= @end_date GOTO Receipt_date

-- need to keep these here to make the detail report balance with the summary.
--update #tos_report_fields_2
--set qsi_flag = 'N'
--where (problem_cause = 'E' AND qsi_flag IN ('QS', 'QN'))

DROP TABLE #tos_report_fields

DELETE FROM #tos_report_fields_2 WHERE truck_code IS NULL OR count_as_truck = 0

CREATE TABLE #summary_fields	(
    company_id               int NULL,
    trucks                   int NULL,
    bulk_loads               int NULL,
    non_bulk_loads           int NULL,
    qsi_trucks               int NULL,
    qsi_bulk                 int NULL,
    qsi_non_bulk             int NULL,
    qsi_standard             int NULL,
    qsi_non_standard         int NULL,
    standard_bulk            int NULL,
    standard_non_bulk        int NULL,
    non_standard_bulk        int NULL,
    non_stand_non_bulk       int NULL,
    bulk_tos                 numeric(8,3) NULL,
    non_bulk_tos             numeric(8,3) NULL,
    qsi_trucks_ex_e          int NULL,
    qsi_bulk_ex_e            int NULL,
    qsi_non_bulk_ex_e        int NULL,
    bulk_ex_e_tos            numeric(8,3) NULL,
    non_bulk_ex_e_tos        numeric(8,3) NULL,
    qsi_standard_ex_e        int NULL,
    qsi_non_standard_ex_e    int NULL	)

INSERT INTO #summary_fields
       VALUES (NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
               NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL,
               NULL, NULL)

UPDATE #summary_fields
SET trucks = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2)
--SET trucks = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE count_as_truck = 1)
-- all records have a count_as_truck = 1 

UPDATE #summary_fields
SET company_id = @company_id

UPDATE #summary_fields
SET bulk_loads = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE bulk_flag = 'T')

UPDATE #summary_fields
SET non_bulk_loads = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE (bulk_flag <> 'T' OR bulk_flag IS NULL))

UPDATE #summary_fields
SET qsi_trucks = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE qsi_flag IN ('QS','QN'))

UPDATE #summary_fields
SET qsi_bulk = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE qsi_flag IN ('QS','QN') AND bulk_flag = 'T')

UPDATE #summary_fields
SET qsi_non_bulk = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE qsi_flag IN ('QS','QN') AND (bulk_flag <> 'T' OR bulk_flag IS NULL))

UPDATE #summary_fields
SET qsi_standard = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE qsi_flag = 'QS')

UPDATE #summary_fields
SET qsi_non_standard = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE qsi_flag = 'QN')

UPDATE #summary_fields
SET standard_bulk = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE qsi_flag = 'QS' AND bulk_flag = 'T')

UPDATE #summary_fields
SET standard_non_bulk = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE qsi_flag = 'QS' AND (bulk_flag <> 'T' OR bulk_flag IS NULL))

UPDATE #summary_fields
SET non_standard_bulk = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE qsi_flag = 'QN' AND bulk_flag = 'T')

UPDATE #summary_fields
SET non_stand_non_bulk = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE qsi_flag = 'QN' AND (bulk_flag <> 'T' OR bulk_flag IS NULL))

UPDATE #summary_fields
SET bulk_tos = (SELECT AVG(time_on_site) FROM #tos_report_fields_2 WHERE qsi_flag in ('QS','QN') AND bulk_flag = 'T') / 60.0

UPDATE #summary_fields
SET non_bulk_tos = (SELECT AVG(time_on_site) FROM #tos_report_fields_2 WHERE qsi_flag in ('QS','QN') AND (bulk_flag <> 'T' OR bulk_flag IS NULL)) / 60.0

UPDATE #summary_fields
SET qsi_trucks_ex_e = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE qsi_flag in ('QS','QN') 
	AND (problem_cause <> 'E' OR problem_cause IS NULL))

UPDATE #summary_fields
SET qsi_bulk_ex_e = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE qsi_flag IN ('QS','QN') AND bulk_flag = 'T' 
	AND (problem_cause <> 'E' OR problem_cause IS NULL))

UPDATE #summary_fields
SET qsi_non_bulk_ex_e = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE qsi_flag IN ('QS','QN') 
	AND (bulk_flag <> 'T' OR bulk_flag IS NULL) 
	AND (problem_cause <> 'E' OR problem_cause IS NULL))

UPDATE #summary_fields
SET bulk_ex_e_tos = (SELECT AVG(time_on_site) FROM #tos_report_fields_2 WHERE qsi_flag IN ('QS','QN') 
	AND bulk_flag = 'T'
	AND (problem_cause <> 'E' OR problem_cause IS NULL)) / 60.0

UPDATE #summary_fields
SET non_bulk_ex_e_tos = (SELECT AVG(time_on_site) FROM #tos_report_fields_2 WHERE qsi_flag IN ('QS','QN') 
	AND (bulk_flag <> 'T' OR bulk_flag IS NULL)
	AND (problem_cause <> 'E' OR problem_cause IS NULL)) / 60.0

UPDATE #summary_fields
SET qsi_standard_ex_e = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE qsi_flag = 'QS'
	AND (problem_cause <> 'E' OR problem_cause IS NULL))

UPDATE #summary_fields
SET qsi_non_standard_ex_e = (SELECT COUNT(DISTINCT receipt_id) FROM #tos_report_fields_2 WHERE qsi_flag = 'QN'
	AND (problem_cause <> 'E' OR problem_cause IS NULL))

SELECT * FROM #summary_fields

DROP TABLE #summary_fields
DROP TABLE #tos_report_fields_2
set ansi_warnings on

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_qsi_tos_summary] TO [EQWEB]
    AS [dbo];
GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_qsi_tos_summary] TO [COR_USER]
    AS [dbo];



GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_qsi_tos_summary] TO [EQAI]
    AS [dbo];

