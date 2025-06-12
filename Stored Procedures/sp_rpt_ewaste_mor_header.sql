/***************************************************************************************
E-waste Monthly Operating Report (MOR) header report
Filename:	F:\EQAI\SQL\EQAI\sp_rpt_ewaste_mor_header.sql
PB Object(s):	d_rpt_ewaste_mor_header

02/16/2006 JDB	Created
03/15/2006 RG   removed join to wastecode on profit ctr
06/30/2014 AM   Moved to plt_ai and added company_id

sp_rpt_ewaste_mor_header '1/1/05', '3/31/05', 21
****************************************************************************************/
CREATE PROCEDURE sp_rpt_ewaste_mor_header
	@date_from	datetime,
	@date_to	datetime,
	@profit_ctr_id	int,
    @company_id int
AS
SET NOCOUNT ON

SELECT 	ISNULL(LTRIM(RTRIM(ProfitCenter.EPA_ID)), '') AS EQ_Site_ID,   
	DATEPART(month, Receipt.Receipt_date) AS reporting_month,   
	DATEPART(yyyy, Receipt.Receipt_date) AS reporting_year
FROM	Receipt,
	ProfitCenter,
	WasteCode,
	Customer,
	Generator
WHERE Receipt.Receipt_date BETWEEN @date_from AND @date_to
	AND Receipt.receipt_status = 'A'
	AND Receipt.trans_type = 'D'
	AND Receipt.trans_mode = 'I'
	AND IsNull(Receipt.quantity, 0) <> 0
	AND IsNull(LTrim(RTrim(Receipt.manifest)), '') <> ''
	AND Receipt.profit_ctr_id = ProfitCenter.profit_ctr_id
	AND Receipt.waste_code = WasteCode.waste_code
	-- AND Receipt.profit_ctr_id = WasteCode.profit_ctr_id
	AND (WasteCode.haz_flag = 'T' OR WasteCode.waste_code IN ('007L', '014L', '017L', '019L', '021L', '022L', '026L', '029L', '030L', '031L', '032L', '033L', '034L', '035L', '036L'))
	AND Receipt.company_id = ProfitCenter.company_id
	AND Receipt.generator_id = Generator.generator_id
-- 	AND Generator.EPA_ID = ProfitCenter.EPA_ID
	AND Receipt.customer_id = Customer.customer_id 
	AND Customer.customer_type = 'IC'
	AND Receipt.profit_ctr_id = @profit_ctr_id
	AND Receipt.company_id = @company_id
	AND ((Receipt.company_id = 2 AND Receipt.generator_id = 38214 AND Receipt.customer_id = 2226)
		OR (Receipt.company_id = 2 AND Receipt.generator_id = 37030 AND Receipt.customer_id IN (1347, 1620, 3166, 2655, 4176))
		OR (Receipt.company_id = 3 AND Receipt.generator_id = 38214 AND Receipt.customer_id = 2226)
		OR (Receipt.company_id = 3 AND Receipt.generator_id = 37030 AND Receipt.customer_id IN (1347, 1620, 3166, 2655, 4176))
		OR (Receipt.company_id = 12 AND Receipt.generator_id = 36494 AND Receipt.customer_id = 2244)
		OR (Receipt.company_id = 21 AND Receipt.generator_id = 35475 AND Receipt.customer_id IN (2366)))
GROUP BY ProfitCenter.EPA_ID,
	DATEPART(yyyy, Receipt.Receipt_date),
	DATEPART(month, Receipt.Receipt_date)
ORDER BY ProfitCenter.EPA_ID,
	DATEPART(yyyy, Receipt.Receipt_date),
	DATEPART(month, Receipt.Receipt_date)

GO
GRANT EXECUTE
    ON OBJECT::[dbo].[sp_rpt_ewaste_mor_header] TO [EQAI]
    AS [dbo];

