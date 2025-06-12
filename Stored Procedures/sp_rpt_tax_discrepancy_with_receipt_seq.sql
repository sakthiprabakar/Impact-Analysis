drop PROCEDURE dbo.sp_rpt_tax_discrepancy_with_receipt_seq 
go
CREATE PROCEDURE dbo.sp_rpt_tax_discrepancy_with_receipt_seq (
	@company_id		 int
,	@profit_ctr_id	 int
,	@date_from		datetime
,	@date_to		datetime
)
AS
/*************************************************************************************************
Loads to : PLT_AI

11/14/2017 RJB	Initial by Rich Bianco as one of first Eqai reports developed.
This is a redesigned report from Aesop based off the Tax Discrepancy with Receipt Sequence. 
Driver in Aesop was Inventory therefore source being used in EQAI is ContainerDestination. 
1/3/2018 RJB Fix to handle outbound which do not have container destination, profile or tax code
1/11/2018 RJB Fix add two sql statements against each of the temp tables removing duplicated
lines where receipt status is voided. The second updates the temp table clearing values for 
voided or rejected lines.
3/23/2018 RJB Fix overflow error due to temp table not having proper column width of 100
on the tax code description column.
4/16/2018 RJB Change to use high precision version of weight functions to meet requirement
of eight digits precision all the way from pounds, tons and amount.
08/23/2018 AM EQAI-53226 - modified report to add trip_id and container_count. also added group by to get line level data.
10/17/2018 - AM GEM:55883 - Report - Modified report code get correct data. Bill Unit table join changed from Inner to OUTER. 
5/10/2021 - MPM - DevOps 17797 - Modified logic for voided inbound/outbound receipts and added logic for 
					'Tax Paid in Previous Quarter'.
5/17/2021 - MPM - DevOps 19998 - Corrected Fee Rate calculation - there is no need to 
			multiply by the number of containers.
10/25/2021	MPM	DevOps 29485 - Corrected for skipped receipts.

PowerBuilder r_tax_with_discrepancy uses this procedure as a data source. 	

EXECUTE sp_rpt_tax_discrepancy_with_receipt_seq  45, 0, '2018-01-22', '2018-01-24'

EXECUTE sp_rpt_tax_discrepancy_with_receipt_seq  45, 0, '2018-01-24', '2018-01-25'

*************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DECLARE 
	@receipt_id_start int,
	@receipt_id_end int,
	@receipt_count int

-- Drop temporary table if they exist this one is the main driver
IF OBJECT_ID('tempdb.dbo.#tmp_taxrptdriver') IS NOT NULL
BEGIN
  DROP TABLE #tmp_taxrptdriver
END
	
IF OBJECT_ID('tempdb.dbo.#tmp_taxrptdata') IS NOT NULL
BEGIN
  DROP TABLE #tmp_taxrptdata
END

-- Create temporary table which will be the main driver for the report
CREATE TABLE #tmp_taxrptdriver (
	company_id 		INT NOT NULL,
	profit_ctr_id 	INT NOT NULL,
	receipt_id 		INT NOT NULL,
	line_id 		INT NOT NULL,
	rpt_status_cd 	CHAR(1) NULL,
	trans_mode		CHAR(1) NULL
)

-- Create temporary table which will be the receipts for the report and
-- will be joined with the main driver so that we have any missing
-- receipts (gaps in receipt numbers)
CREATE TABLE #tmp_taxrptdata (
	company_id 				INT NOT NULL,
	profit_ctr_id 			INT NOT NULL,
	receipt_id 				INT NOT NULL,
	line_id 				INT NOT NULL,
	receipt_date 			DATETIME NULL,
	manifest 				VARCHAR(15) NULL,
	manifest_page 			INT NULL,
	manifest_line 			INT NULL,
	profile_id 				INT NULL,
	approval_code 			VARCHAR(15) NULL,
	waste_stream_common_name CHAR(50) NULL,  -- force 50
	--container_id 			INT NULL,
	--sequence_id 			INT NULL,
	container_pct 			INT NULL,
	quantity 				FLOAT NULL,
	bill_unit 				VARCHAR(15) NULL,
	wt_tons 				FLOAT NULL,
	tax_rate 				FLOAT NULL,
	tax_amount				FLOAT NULL,
	tax_code 				VARCHAR(100) NULL,
	discrepancy_code 		CHAR(1) NULL,
	trans_mode				CHAR(1) NULL
)

-- Get the minimum and maximum receipt id for date range

SELECT 
	@receipt_id_start	= MIN(receipt_id), 
	@receipt_id_end		= MAX(receipt_id)
 FROM Receipt AS r
WHERE r.company_id		= @company_id
  AND r.profit_ctr_id	= @profit_ctr_id
  AND r.receipt_date	>= @date_from
  AND r.receipt_date	<= @date_to


-- Compute the number of receipts 
SET @receipt_count = (@receipt_id_end - @receipt_id_start) + 1

-- DEBUG
-- select @receipt_id_start, @receipt_id_end, @receipt_count

-- This essentially creates a driver table of all the receipt ids for the date range and
-- including receipt ids missing between the start and end in case there are some that are
-- not received or gaps. The tblToolsStringParserCounter serves the purpose of counter
INSERT INTO 
	#tmp_taxrptdriver
SELECT 
	@company_id,
	@profit_ctr_id,
	@receipt_id_start + ( cnt.ID - 1 ),
	IsNull( inner_r.line_id, 1 ),
	IsNull( inner_r.receipt_status, '-' ), --  means skipped receipt
	IsNull(inner_r.trans_mode, '')
FROM tblToolsStringParserCounter AS cnt
FULL OUTER JOIN 
	(SELECT Top 1
			r.receipt_id,
			r.line_id as line_id,
			r.receipt_status as receipt_status,
			r.trans_mode as trans_mode
		FROM Receipt r 
		WHERE 
			r.company_id = @company_id AND 
			r.profit_ctr_id = @profit_ctr_id AND 
			r.receipt_id between @receipt_id_start and @receipt_id_end AND
			(select COUNT(1) from Receipt as rr 
				where rr.company_id = @company_id and 
					  rr.profit_ctr_id = @profit_ctr_id and
					  rr.receipt_id = r.receipt_id and 
					 -- rr.trans_mode = 'I' and 
					  rr.trans_type = 'D' ) = 0
			UNION
				SELECT 
					r.receipt_id,
					r.line_id,
					r.receipt_status,
					r.trans_mode 
				FROM Receipt r 
				WHERE 
					r.company_id = @company_id AND 
					r.profit_ctr_id = @profit_ctr_id AND 
					r.receipt_id between @receipt_id_start and @receipt_id_end AND
				--	r.trans_mode = 'I' AND
					r.trans_type = 'D' 
	) As inner_r 
ON
	@receipt_id_start + ( cnt.ID - 1 ) = inner_r.receipt_id 
WHERE cnt.ID <= @receipt_count

-- debug:
--select '#tmp_taxrptdriver before deleting dups'
--select * from #tmp_taxrptdriver
--order by receipt_id, line_id

-- Remove any duplicated lines for voided  or outbound receipt leaving only one 
-- it does not matter (in this case) which one remains
IF OBJECT_ID('tempdb.dbo.#Dups') IS NOT NULL
BEGIN
  DROP TABLE #Dups
END

SELECT td.receipt_id, MAX(td.line_id) as line_id
INTO #Dups
FROM #tmp_taxrptdriver As td
WHERE (td.rpt_status_cd = 'V' -- voided receipt 
	OR td.trans_mode = 'O')
GROUP BY td.receipt_id
HAVING COUNT(1) > 1
	
-- debug:
--select '#dups'
--select * from #dups
--order by receipt_id, line_id

DELETE #tmp_taxrptdriver
FROM   #tmp_taxrptdriver a
       INNER JOIN #Dups b
               ON b.receipt_id = a.receipt_id
               AND a.line_id BETWEEN 2 AND b.line_id

-- debug:
--select '#tmp_taxrptdriver after deleting dups'
--select * from #tmp_taxrptdriver
--order by receipt_id, line_id

-- This is the receipt slash tax info that will be joined to the driver temp table
INSERT INTO #tmp_taxrptdata
SELECT 
	tmp_driver.company_id,
	tmp_driver.profit_ctr_id,
	tmp_driver.receipt_id,
	tmp_driver.line_id,
	r.receipt_date,
	r.manifest, 
	r.manifest_page_num,
	r.manifest_line,
	r.profile_id,
	r.approval_code, 
	p.approval_desc AS waste_stream_common_name,
	--cd.container_id,
	--cd.sequence_id,
	cd.container_percent,
	r.quantity, 
	IsNull(CONVERT(CHAR(6), r.bill_unit_code), 'VARIES') AS bill_unit,
	SUM(ROUND(dbo.fn_receipt_weight_container_hi_prec(
						cd.receipt_id, 
						cd.line_id, 
						cd.profit_ctr_id, 
						cd.company_id, 
						cd.container_id,
						cd.sequence_id
						 )/2000,8)) AS wt_tons, -- RJB switched to hi precision version 
	tc.tax_rate,
	ROUND(SUM(ROUND(ISNull(dbo.fn_receipt_weight_container_hi_prec(
						cd.receipt_id, 
						cd.line_id, 
						cd.profit_ctr_id, 
						cd.company_id,
						cd.container_id,
						cd.sequence_id
						),0.00),8)/2000)*IsNull(tc.tax_rate,0.00),8) AS tax_amount,
	CASE  tc.tax_desc
      WHEN 'N/A' THEN 'N/A'   
      ELSE LEFT(tax_desc,1) 
     END AS  tax_code,
	CASE 
		--WHEN r.trans_mode = 'O' THEN 'O' -- outbound discrep
		WHEN tmp_driver.rpt_status_cd = '-' THEN 'S'
		ELSE 
			IsNull(dbo.fn_get_tax_discrepancy_status_code(r.trans_mode, 
											r.trans_type, 
											r.receipt_status, 
											r.fingerpr_status,
											cd.tax_code_uid, 
											cd.container_percent),'U')
	END 
	AS discrepancy_code,
	r.trans_mode
FROM #tmp_taxrptdriver As tmp_driver 
LEFT OUTER JOIN Receipt r
    ON r.company_id = tmp_driver.company_id 
	AND r.profit_ctr_id = tmp_driver.profit_ctr_id
	AND r.receipt_id = tmp_driver.receipt_id
	AND r.line_id = tmp_driver.line_id
LEFT OUTER JOIN Profile As p
	ON r.profile_id = p.profile_id
LEFT OUTER JOIN ContainerDestination cd
	ON	r.receipt_id		= cd.receipt_id
	AND	r.line_id			= cd.line_id
	AND r.company_id		= cd.company_id 
	AND r.profit_ctr_id		= cd.profit_ctr_id 
LEFT OUTER JOIN TaxCode AS tc
	ON	r.company_id		= tc.company_id
	AND r.profit_ctr_id		= tc.profit_ctr_id
	AND cd.tax_code_uid		= tc.tax_code_uid
LEFT OUTER JOIN ProfileQuoteApproval As pqa
  ON r.profile_id = pqa.profile_id 
 AND r.company_id = pqa.company_id 
 AND r.profit_ctr_id = pqa.profit_ctr_id 
WHERE r.company_id			= @company_id
  AND r.profit_ctr_id		= @profit_ctr_id
  AND r.receipt_id			between @receipt_id_start and @receipt_id_end
  group by 
  tmp_driver.company_id,
	tmp_driver.profit_ctr_id,
	tmp_driver.receipt_id,
	tmp_driver.line_id,
	r.receipt_date,
	r.manifest, 
	r.manifest_page_num,
	r.manifest_line,
	r.profile_id,
	r.approval_code, 
	p.approval_desc,
	cd.container_percent,
	r.quantity, 
	r.bill_unit_code,
	tc.tax_rate,
	tc.tax_desc,
	cd.receipt_id, 
	cd.line_id,
	cd.profit_ctr_id,
	cd.company_id,
    r.trans_mode,
    r.trans_type, 
	r.receipt_status, 
	r.fingerpr_status,
	cd.tax_code_uid, 
	cd.container_percent,
	tmp_driver.rpt_status_cd

-- Clear out values for voided or rejected receipt lines char columns gets empty string
-- and numeric columns get null. Note: Discrepancy codes not intuitive, taken from Aesop
-- 'X' is Voided Receipt Line 
-- 'Z' is Voided Inbound Receipt 
-- 'J' is Rejected receipt status
-- 'K' is Lab Reject
-- 'Q' is Voided Outbound Receipt
UPDATE #tmp_taxrptdata
SET manifest = '',
	manifest_page = NULL,
	manifest_line = NULL,
	--container_id = NULL,
	--sequence_id = NULL,
	container_pct = NULL,
	quantity = NULL,
	wt_tons = NULL,
	tax_rate = NULL,
	tax_code = '',
	bill_unit = '',
	approval_code = '',
	waste_stream_common_name = ''
WHERE 
	discrepancy_code in ('X','Z','J','K', 'Q')

UPDATE #tmp_taxrptdata
	SET discrepancy_code = 'P', -- 'Tax Paid in Previous Quarter'
		wt_tons = NULL,
		tax_rate = NULL,
		tax_amount = NULL
	WHERE trans_mode = 'I'
	AND receipt_date < @date_from
	AND discrepancy_code NOT IN ('X','Z','J','K', 'Q')

-- Now the final query that builds the report we use distinct to eliminate 
SELECT DISTINCT 
	drv.company_id,
	drv.profit_ctr_id,
	dta.receipt_date,
	drv.receipt_id,
	drv.line_id,
	dta.manifest,
	dta.manifest_page,
	dta.manifest_line,
	dta.profile_id,
	dta.approval_code,
	dta.waste_stream_common_name,
	dta.quantity,
	dta.bill_unit,
	dta.wt_tons,
	dta.tax_rate,
	dta.tax_amount,
	--Round(IsNull( dta.wt_tons,0.00) * IsNull(dta.tax_rate,0.00),8) AS tax_amount,
	dta.tax_code,
	dta.discrepancy_code,
	ts.status_desc AS discrepancy_desc,
	--dta.container_id,
	--dta.sequence_id,
	dta.container_pct,
	pc.profit_ctr_name,
	rh.trip_id,
	r.container_count,
	(dta.quantity * b.pound_conv)as qty_pound_conv--,
--	r.trans_mode
FROM #tmp_taxrptdriver AS drv
INNER JOIN ProfitCenter AS pc
  ON drv.company_id = pc.company_id
 AND drv.profit_ctr_id = pc.profit_ctr_id
LEFT OUTER JOIN #tmp_taxrptdata AS dta
  ON drv.company_id			= dta.company_id
 AND drv.profit_ctr_id		= dta.profit_ctr_id
 AND drv.receipt_id			= dta.receipt_id
 AND drv.line_id			= dta.line_id
LEFT OUTER JOIN TaxDiscrepancyStatus AS ts
  ON IsNull(dta.discrepancy_code,'S') = ts.status_code
LEFT OUTER JOIn ReceiptHeader rh  ON drv.company_id	= rh.company_id
 AND drv.profit_ctr_id		= rh.profit_ctr_id
 AND drv.receipt_id			= rh.receipt_id
LEFT OUTER JOIN Receipt r ON r.company_id	= drv.company_id
  AND r.profit_ctr_id		= drv.profit_ctr_id
  AND r.receipt_id	= drv.receipt_id
  AND r.line_id = drv.line_id
LEFT OUTER JOIn BillUnit B ON dta.bill_unit = b.bill_unit_code
GO

GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_tax_discrepancy_with_receipt_seq] TO [EQAI]
    AS [dbo];
GO

