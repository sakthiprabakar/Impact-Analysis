/***************************************************************************************
E-waste manifest detail report
Filename:	F:\EQAI\SQL\EQAI\sp_rpt_ewaste_man_detail.sql
PB Object(s):	d_rpt_ewaste_man_detail

02/16/2006 JDB	Created
03/15/2006 RG	removed join to wastecode on profit ctr
06/30/2014 AM   Moved to plt_ai and added company_id
\
sp_rpt_ewaste_man_detail '12/1/05', '12/31/05', 21
****************************************************************************************/
CREATE PROCEDURE sp_rpt_ewaste_man_detail
	@date_from	datetime,
	@date_to	datetime,
	@profit_ctr_id	int,
	@company_id int
AS
SET NOCOUNT ON

DECLARE	@receipt_id	int,
	@receipt_id_max	int,
	@page_line_max	varchar(4),
	@manifest	varchar(15)

CREATE TABLE #tmp_pages (
	page		int,
	line		varchar(2),
	page_line	varchar(4))

INSERT INTO #tmp_pages VALUES(1, 'A', '1A')
INSERT INTO #tmp_pages VALUES(1, 'B', '1B')
INSERT INTO #tmp_pages VALUES(1, 'C', '1C')
INSERT INTO #tmp_pages VALUES(1, 'D', '1D')
INSERT INTO #tmp_pages VALUES(2, 'A', '2A')
INSERT INTO #tmp_pages VALUES(2, 'B', '2B')
INSERT INTO #tmp_pages VALUES(2, 'C', '2C')
INSERT INTO #tmp_pages VALUES(2, 'D', '2D')
INSERT INTO #tmp_pages VALUES(2, 'E', '2E')
INSERT INTO #tmp_pages VALUES(2, 'F', '2F')
INSERT INTO #tmp_pages VALUES(2, 'G', '2G')
INSERT INTO #tmp_pages VALUES(2, 'H', '2H')
INSERT INTO #tmp_pages VALUES(2, 'I', '2I')
INSERT INTO #tmp_pages VALUES(3, 'A', '3A')
INSERT INTO #tmp_pages VALUES(3, 'B', '3B')
INSERT INTO #tmp_pages VALUES(3, 'C', '3C')
INSERT INTO #tmp_pages VALUES(3, 'D', '3D')
INSERT INTO #tmp_pages VALUES(3, 'E', '3E')
INSERT INTO #tmp_pages VALUES(3, 'F', '3F')
INSERT INTO #tmp_pages VALUES(3, 'G', '3G')
INSERT INTO #tmp_pages VALUES(3, 'H', '3H')
INSERT INTO #tmp_pages VALUES(3, 'I', '3I')
INSERT INTO #tmp_pages VALUES(4, 'A', '4A')
INSERT INTO #tmp_pages VALUES(4, 'B', '4B')
INSERT INTO #tmp_pages VALUES(4, 'C', '4C')
INSERT INTO #tmp_pages VALUES(4, 'D', '4D')
INSERT INTO #tmp_pages VALUES(4, 'E', '4E')
INSERT INTO #tmp_pages VALUES(4, 'F', '4F')
INSERT INTO #tmp_pages VALUES(4, 'G', '4G')
INSERT INTO #tmp_pages VALUES(4, 'H', '4H')
INSERT INTO #tmp_pages VALUES(4, 'I', '4I')
INSERT INTO #tmp_pages VALUES(5, 'A', '5A')
INSERT INTO #tmp_pages VALUES(5, 'B', '5B')
INSERT INTO #tmp_pages VALUES(5, 'C', '5C')
INSERT INTO #tmp_pages VALUES(5, 'D', '5D')
INSERT INTO #tmp_pages VALUES(5, 'E', '5E')
INSERT INTO #tmp_pages VALUES(5, 'F', '5F')
INSERT INTO #tmp_pages VALUES(5, 'G', '5G')
INSERT INTO #tmp_pages VALUES(5, 'H', '5H')
INSERT INTO #tmp_pages VALUES(5, 'I', '5I')
INSERT INTO #tmp_pages VALUES(6, 'A', '6A')
INSERT INTO #tmp_pages VALUES(6, 'B', '6B')
INSERT INTO #tmp_pages VALUES(6, 'C', '6C')
INSERT INTO #tmp_pages VALUES(6, 'D', '6D')
INSERT INTO #tmp_pages VALUES(6, 'E', '6E')
INSERT INTO #tmp_pages VALUES(6, 'F', '6F')
INSERT INTO #tmp_pages VALUES(6, 'G', '6G')
INSERT INTO #tmp_pages VALUES(6, 'H', '6H')
INSERT INTO #tmp_pages VALUES(6, 'I', '6I')
INSERT INTO #tmp_pages VALUES(7, 'A', '7A')
INSERT INTO #tmp_pages VALUES(7, 'B', '7B')
INSERT INTO #tmp_pages VALUES(7, 'C', '7C')
INSERT INTO #tmp_pages VALUES(7, 'D', '7D')
INSERT INTO #tmp_pages VALUES(7, 'E', '7E')
INSERT INTO #tmp_pages VALUES(7, 'F', '7F')
INSERT INTO #tmp_pages VALUES(7, 'G', '7G')
INSERT INTO #tmp_pages VALUES(7, 'H', '7H')
INSERT INTO #tmp_pages VALUES(7, 'I', '7I')

SELECT	ISNULL(LTRIM(RTRIM(Receipt.manifest)), '') AS manifest,
	Receipt.manifest_quantity AS quantity,
	Receipt.manifest_unit AS MDEQ_uom,
	ISNULL(LTRIM(RTRIM(Treatment.management_code)), '') AS management_code,
	ISNULL(LTRIM(RTRIM(Receipt.waste_code)),'') AS waste_code,
	Receipt.bill_unit_code,
	Receipt.treatment_id,
	Receipt.receipt_id,
	Receipt.line_id,
	Receipt.manifest_flag,
	Receipt.manifest_quantity,
	Receipt.manifest_unit,
	Receipt.generator_id,
	Receipt.manifest_page_num,
	Receipt.manifest_line_id
INTO	#tmp
FROM	Receipt,
	Treatment,
	WasteCode,
	#tmp_pages
WHERE Receipt.Receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.receipt_status = 'A'
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'
	AND IsNull(Receipt.quantity, 0) <> 0
	AND Receipt.treatment_id = Treatment.treatment_id
	AND Receipt.profit_ctr_id = Treatment.profit_ctr_id
	AND Receipt.company_id = Treatment.company_id
	AND Receipt.waste_code = WasteCode.waste_code
	-- AND Receipt.profit_ctr_id = WasteCode.profit_ctr_id
	AND (WasteCode.haz_flag = 'T' 
		OR WasteCode.waste_code IN ('007L', '014L', '017L', '019L', '021L', '022L', '026L', '029L', 
		'030L', '031L', '032L', '033L', '034L', '035L', '036L'))
	AND Receipt.manifest_flag IN ( 'M', 'C' )
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.company_id = @company_id
	AND NOT ((Receipt.company_id = 2 AND Receipt.generator_id = 38214 AND Receipt.customer_id = 2226)
		OR (Receipt.company_id = 2 AND Receipt.generator_id = 37030 AND Receipt.customer_id IN (1347, 1620, 3166, 2655, 4176))
		OR (Receipt.company_id = 3 AND Receipt.generator_id = 38214 AND Receipt.customer_id = 2226)
		OR (Receipt.company_id = 3 AND Receipt.generator_id = 37030 AND Receipt.customer_id IN (1347, 1620, 3166, 2655, 4176))
		OR (Receipt.company_id = 12 AND Receipt.generator_id = 36494 AND Receipt.customer_id = 2244)
		OR (Receipt.company_id = 21 AND Receipt.generator_id = 35475 AND Receipt.customer_id IN (2366)))
	AND IsNull(LTrim(RTrim(Receipt.manifest)), '') <> ''
	AND Receipt.manifest_page_num = #tmp_pages.page
	AND Receipt.manifest_line_id = #tmp_pages.line

SELECT @receipt_id_max = MAX(receipt_id) FROM #tmp
SELECT @receipt_id = MIN(receipt_id) FROM #tmp

/************************************************************************************************/
Page_line:

SELECT	@page_line_max = MAX(CONVERT(varchar(2), manifest_page_num) + manifest_line_id)
FROM #tmp 
WHERE receipt_id = @receipt_id

SELECT	@manifest = manifest FROM #tmp WHERE receipt_id = @receipt_id

INSERT INTO #tmp
SELECT	@manifest,
	1 AS quantity,
	'X' AS MDEQ_uom,
	'' AS management_code,
	'0000' AS waste_code,
	'X' AS bill_unit_code,
	0 AS treatment_id,
	0 AS receipt_id,
	0 AS line_id,
	'' AS manifest_flag,
	0 AS manifest_quantity,
	'X' AS manifest_unit,
	0 AS generator_id,
	#tmp_pages.page,
	#tmp_pages.line
FROM	#tmp_pages
	WHERE page_line NOT IN (SELECT CONVERT(varchar(2), manifest_page_num) + manifest_line_id FROM #tmp WHERE receipt_id = @receipt_id)
	AND page_line <= @page_line_max

SELECT @receipt_id = MIN(receipt_id) FROM #tmp WHERE receipt_id > @receipt_id

IF @receipt_id <= @receipt_id_max GOTO Page_line
/************************************************************************************************/

SELECT	manifest,
	quantity,
	MDEQ_uom,
	management_code,
	waste_code,
	bill_unit_code,
	treatment_id,
	receipt_id,
	line_id,
	manifest_flag,
	manifest_quantity,
	manifest_unit,
	generator_id,
	manifest_page_num,
	manifest_line_id
FROM #tmp
ORDER BY manifest, manifest_page_num, manifest_line_id

DROP TABLE #tmp_pages
DROP TABLE #tmp

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_ewaste_man_detail] TO [EQAI]
    AS [dbo];

